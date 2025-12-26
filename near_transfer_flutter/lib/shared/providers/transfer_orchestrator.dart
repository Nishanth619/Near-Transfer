import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:http/http.dart' as http;
import '../services/discovery_service.dart';
import '../services/signaling_socket_service.dart';
import '../services/signaling_server.dart';
import '../services/webrtc_service.dart';
import '../services/resumable_webrtc_service.dart';
import '../services/http_fallback_service.dart';
import '../services/transfer_state_database.dart';
import '../services/database_service.dart';
import '../models/discovered_device.dart';
import '../models/transfer_state.dart' as ts; // Alias to avoid conflict
import '../utils/transfer_resume_utils.dart';
import '../../core/network_config.dart';

enum TransferState {
  idle,
  connecting,
  connected,
  transferring,
  paused,
  completed,
  failed,
}

class TransferOrchestrator extends ChangeNotifier {
  final DiscoveryService _discoveryService;
  final SignalingSocketService _signalingService;
  final WebRTCService _webrtcService;
  
  SignalingServer? _httpServer; // For HTTP fallback
  Timer? _webrtcTimeoutTimer;
  
  // State
  TransferState _state = TransferState.idle;
  TransferState get state => _state;
  
  String? _sessionId;
  String? _currentFileName;
  double _progress = 0.0;
  bool _useHttpFallback = false;
  bool _isDisposed = false;
  
  // Speed tracking
  int _bytesTransferred = 0;
  int _lastBytesTransferred = 0;
  DateTime _lastSpeedUpdate = DateTime.now();
  DateTime _transferStartTime = DateTime.now();
  double _currentSpeedBytesPerSecond = 0.0;
  final List<double> _speedHistory = []; // For smoothing
  
  // ICE Candidate Queue
  final List<SignalingMessage> _pendingIceCandidates = [];
  bool _isRemoteDescriptionSet = false;
  
  String? get currentFileName => _currentFileName;
  double get progress => _progress;
  bool get useHttpFallback => _useHttpFallback;
  int get currentFileIndex => _currentFileIndex;
  int get totalFiles => _filesToSend.length;
  List<PlatformFile> get files => _filesToSend;
  
  // Speed getters
  double get speedMBps => _currentSpeedBytesPerSecond / (1024 * 1024);
  String get speedString {
    final speed = speedMBps;
    if (speed >= 1.0) {
      return '${speed.toStringAsFixed(1)} MB/s';
    } else {
      return '${(speed * 1024).toStringAsFixed(0)} KB/s';
    }
  }
  
  Duration get estimatedTimeRemaining {
    if (_currentSpeedBytesPerSecond <= 0 || _selectedFile == null) {
      return Duration.zero;
    }
    final remainingBytes = _selectedFile!.size - _bytesTransferred;
    final secondsRemaining = remainingBytes / _currentSpeedBytesPerSecond;
    return Duration(seconds: secondsRemaining.ceil());
  }
  
  String get etaString {
    final eta = estimatedTimeRemaining;
    if (eta == Duration.zero || _progress >= 1.0) {
      return '--:--';
    }
    if (eta.inHours > 0) {
      return '${eta.inHours}h ${eta.inMinutes.remainder(60)}m';
    } else if (eta.inMinutes > 0) {
      return '${eta.inMinutes}m ${eta.inSeconds.remainder(60)}s';
    } else {
      return '${eta.inSeconds}s';
    }
  }
  
  // Track received files for HTTP fallback
  int _expectedFilesCount = 0;
  int _receivedFilesCount = 0;
  
  // Callbacks for UI
  Function(String senderName, String fileName, int fileSize, List<Map<String, dynamic>>? files, Function() onAccept, Function() onDecline)? onConnectionRequest;
  Function(String senderName)? onBusy; // New callback for pre-connection busy state
  Function()? onTransferComplete;
  Function(String error)? onError;
  Function()? onWebRTCTimeout;
  
  List<PlatformFile> _filesToSend = [];
  int _currentFileIndex = 0;
  PlatformFile? _selectedFile;
  
  // Resume support
  final TransferStateDatabase _transferStateDb = TransferStateDatabase.instance;
  HttpFallbackService? _httpFallbackService;
  String? _currentTransferId;
  String? _partnerDeviceId;
  String? _partnerDeviceName;
  String? _partnerIp;
  bool _isResuming = false;
  
  // Group transfer support
  bool _isGroupTransfer = false;
  String? _groupId;
  final Map<String, WebRTCService> _webrtcConnections = {};
  final Map<String, SignalingSocketService> _signalingConnections = {};
  final Map<String, double> _deviceProgress = {};
  Function(String deviceId, double progress)? onGroupDeviceProgress;
  Function(String deviceId, String error)? onGroupDeviceError;
  
  // Getters for resume
  String? get currentTransferId => _currentTransferId;
  bool get isResuming => _isResuming;
  bool get isGroupTransfer => _isGroupTransfer;
  
  TransferOrchestrator({
    required DiscoveryService discoveryService,
    required SignalingSocketService signalingService,
    required WebRTCService webrtcService,
  })  : _discoveryService = discoveryService,
        _signalingService = signalingService,
        _webrtcService = webrtcService {
    _setupCallbacks();
  }

  void _setupCallbacks() {
    // Signaling callbacks
    _signalingService.onMessageReceived = _handleSignalingMessage;
    _signalingService.onConnectionClosed = _handleConnectionClosed;
    
    // WebRTC callbacks
    _webrtcService.onIceCandidate = _handleIceCandidate;
    _webrtcService.onProgress = (progress) {
      // Don't update progress if paused - this stops the progress bar animation
      if (_state == TransferState.paused) {
        return;
      }
      
      _progress = progress;
      
      // Calculate speed and ETA
      if (_selectedFile != null) {
        _bytesTransferred = (progress * _selectedFile!.size).floor();
        
        final now = DateTime.now();
        final elapsed = now.difference(_lastSpeedUpdate).inMilliseconds;
        
        // Update speed every 500ms to avoid too frequent updates
        if (elapsed >= 500) {
          final bytesInInterval = _bytesTransferred - _lastBytesTransferred;
          final speedBps = bytesInInterval / (elapsed / 1000.0);
          
          // Add to speed history for smoothing (keep last 5 samples)
          _speedHistory.add(speedBps);
          if (_speedHistory.length > 5) {
            _speedHistory.removeAt(0);
          }
          
          // Calculate smoothed speed (moving average)
          _currentSpeedBytesPerSecond = _speedHistory.reduce((a, b) => a + b) / _speedHistory.length;
          
          _lastBytesTransferred = _bytesTransferred;
          _lastSpeedUpdate = now;
        }
      }
      
      notifyListeners();
      
      // Save progress to database for resume functionality
      if (_currentTransferId != null && _selectedFile != null) {
        final totalChunks = (_selectedFile!.size / NetworkConfig.chunkSize).ceil();
        final completedChunks = (progress * totalChunks).floor();
        final bytesTransferred = (progress * _selectedFile!.size).floor();
        
        // Update database every 10 chunks to avoid excessive writes
        if (completedChunks % 10 == 0 || progress == 1.0) {
          _transferStateDb.updateProgress(
            id: _currentTransferId!,
            completedChunks: completedChunks,
            bytesTransferred: bytesTransferred,
            lastChunkSeq: completedChunks,
          );
        }
      }
    };
    _webrtcService.onDataChannelOpen = _handleDataChannelOpen;
    _webrtcService.onDataChannelClosed = _handleDataChannelClosed;
    _webrtcService.onFileReceived = _handleFileReceived;
    _webrtcService.onFileStart = _handleFileStart;
    _webrtcService.onBatchComplete = _handleBatchComplete;
  }

  // Sender: Connect and lock receiver immediately
  Future<void> prepareConnection(DiscoveredDevice device) async {
    _sessionId = const Uuid().v4();
    _state = TransferState.connecting;
    notifyListeners();
    
    try {
      // Connect via TCP
      final connected = await _signalingService.connectToDevice(device.ip);
      if (!connected) {
        throw Exception('Failed to connect to device');
      }
      
      // Send pre-connect message to lock receiver
      final preConnect = SignalingMessage.preConnect(
        sessionId: _sessionId!,
        senderName: 'My Device', // TODO: Get from settings
      );
      
      await _signalingService.sendMessage(preConnect);
      print('🔒 Pre-connect message sent to lock receiver');
    } catch (e) {
      _state = TransferState.failed;
      onError?.call('Connection failed: $e');
      notifyListeners();
      rethrow;
    }
  }

  // Sender: Initiate transfer (after files selected)
  Future<void> connectToDevice(DiscoveredDevice device, List<PlatformFile> files) async {
    // If not already connected (via prepareConnection), connect now
    if (_sessionId == null) {
      _sessionId = const Uuid().v4();
    }
    
    // Generate transfer ID for resume functionality
    _currentTransferId = TransferResumeUtils.generateTransferId();
    _partnerDeviceId = device.deviceId;
    _partnerDeviceName = device.deviceName;
    _partnerIp = device.ip;
    
    print('📤 Starting transfer: $_currentTransferId');
    
    _state = TransferState.connecting;
    _filesToSend = files;
    _currentFileIndex = 0;
    _selectedFile = files.first;
    _currentFileName = files.first.name;
    notifyListeners();
    
    try {
      // Initialize WebRTC
      await _webrtcService.initConnection(isOfferer: true);
      
      // Create initial transfer state in database
      final totalChunks = (_selectedFile!.size / NetworkConfig.chunkSize).ceil();
      final state = ts.TransferState(
        id: _currentTransferId!,
        type: 'send',
        partnerDeviceId: _partnerDeviceId!,
        partnerDeviceName: _partnerDeviceName!,
        partnerIp: _partnerIp!,
        fileName: _selectedFile!.name,
        filePath: _selectedFile!.path,
        fileSize: _selectedFile!.size,
        fileHash: null, // Will be calculated if needed
        totalChunks: totalChunks,
        completedChunks: 0,
        bytesTransferred: 0,
        status: 'in_progress',
        startedAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        chunkSize: NetworkConfig.chunkSize,
        lastChunkSeq: 0,
      );
      
      await _transferStateDb.insertTransferState(state);
      print('💾 Created transfer state: $_currentTransferId');
      
      // Check if we need to connect (if prepareConnection wasn't called or failed)
      // We can check if signaling service is connected, but for now let's assume
      // if we are here, we might need to reconnect if the socket was closed.
      // However, connectToDevice in service handles duplicate connection attempts gracefully.
      final connected = await _signalingService.connectToDevice(device.ip);
      if (!connected) {
        // If it returns false, it might mean already connected OR failed.
        // But since we want to ensure connection, let's assume it's fine if we sent preConnect.
        // A better check would be exposed in SignalingService.
      }
      
      // Send connection request with all files info
      final filesInfo = files.map((f) => {
        'name': f.name,
        'size': f.size,
      }).toList();
      
      final request = SignalingMessage.connectRequest(
        sessionId: _sessionId!,
        senderName: 'My Device', // TODO: Get from settings
        fileName: files.first.name,
        fileSize: files.first.size,
        files: filesInfo,
      );
      
      await _signalingService.sendMessage(request);
      print('Connection request sent for file 1 of ${files.length}');
    } catch (e) {
      _state = TransferState.failed;
      onError?.call('Connection failed: $e');
      notifyListeners();
    }
  }

  // Receiver: Start server and wait for connections
  Future<void> startReceiving({
    required String deviceId,
    required String deviceName,
    required String deviceIp,
  }) async {
    try {
      await _signalingService.startServer(
        deviceId: deviceId,
        deviceName: deviceName,
        deviceIp: deviceIp,
      );
      print('Ready to receive files');
    } catch (e) {
      onError?.call('Failed to start receiver: $e');
    }
  }

  void _handleSignalingMessage(SignalingMessage message) {
    print('Handling signaling message: ${message.type}');
    
    switch (message.type) {
      case SignalingMessageType.connectRequest:
        _handleConnectRequest(message);
        break;
      case SignalingMessageType.accept:
        _handleAccept(message);
        break;
      case SignalingMessageType.decline:
        _handleDecline(message);
        break;
      case SignalingMessageType.offer:
        _handleOffer(message);
        break;
      case SignalingMessageType.answer:
        _handleAnswer(message);
        break;
      case SignalingMessageType.iceCandidate:
        _handleRemoteIceCandidate(message);
        break;
      case SignalingMessageType.fallbackUpload:
        _handleFallbackUpload(message);
        break;
      case SignalingMessageType.preConnect:
        _handlePreConnect(message);
        break;
      case SignalingMessageType.resumeRequest:
        _handleResumeRequest(message);
        break;
      case SignalingMessageType.resumeAck:
        _handleResumeAck(message);
        break;
      case SignalingMessageType.resumeReject:
        // Handle resume rejected
        print('Resume request rejected');
        break;
      case SignalingMessageType.pause:
        _handlePauseSignal(message);
        break;
      case SignalingMessageType.resume:
        _handleResumeSignal(message);
        break;
      
      // Group transfer messages (not handled in single device transfer)
      case SignalingMessageType.groupCreate:
      case SignalingMessageType.groupJoin:
      case SignalingMessageType.groupLeave:
      case SignalingMessageType.groupBroadcast:
      case SignalingMessageType.groupMemberUpdate:
        // These are handled by GroupTransferOrchestrator, ignore in single transfer
        break;
        
      default:
        print('⚠️ Unhandled signaling message type: ${message.type}');
        break;
    }
  }

  void _handlePreConnect(SignalingMessage message) {
    final senderName = message.data['senderName'] as String;
    print('🔒 Received pre-connect from $senderName');
    _sessionId = message.sessionId;
    onBusy?.call(senderName);
  }

  void _handleConnectRequest(SignalingMessage message) {
    final senderName = message.data['senderName'] as String;
    final fileName = message.data['fileName'] as String;
    final fileSize = message.data['fileSize'] as int;
    
    final files = message.data['files'] as List<dynamic>?;
    final filesList = files?.map((f) => Map<String, dynamic>.from(f as Map)).toList();
    
    _sessionId = message.sessionId;
    _currentFileName = fileName;
    
    // Store files list for receiver UI (create PlatformFile objects from metadata)
    if (filesList != null && filesList.isNotEmpty) {
      _filesToSend = filesList.map((f) => PlatformFile(
        name: f['name'] as String,
        size: f['size'] as int,
        path: null, // Receiver doesn't have path yet
      )).toList();
      _currentFileIndex = 0;
    }
    
    // Show accept/decline dialog
    onConnectionRequest?.call(
      senderName,
      fileName,
      fileSize,
      filesList,
      () => _acceptConnection(),
      () => _declineConnection(),
    );
  }

  Future<void> _acceptConnection() async {
    _state = TransferState.connecting;
    notifyListeners();
    
    // Send accept message
    final accept = SignalingMessage.accept(_sessionId!);
    await _signalingService.sendMessage(accept);
    
    // Initialize WebRTC as answerer
    await _webrtcService.initConnection(isOfferer: false);
  }

  Future<void> _declineConnection() async {
    final decline = SignalingMessage.decline(_sessionId!);
    await _signalingService.sendMessage(decline);
    _signalingService.close();
    _state = TransferState.idle;
    notifyListeners();
  }

  void _handleAccept(SignalingMessage message) async {
    print('Connection accepted');
    _state = TransferState.connecting;
    notifyListeners();
    
    // Initialize WebRTC as offerer
    await _webrtcService.initConnection(isOfferer: true);
    
    // Start WebRTC timeout timer
    _startWebRTCTimeout();
    
    // Wait for ICE gathering to complete
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Create and send offer
    final offer = await _webrtcService.createOffer();
    final offerMsg = SignalingMessage.offer(
      sessionId: _sessionId!,
      sdp: offer.sdp!,
    );
    await _signalingService.sendMessage(offerMsg);
  }

  void _startWebRTCTimeout() {
    _webrtcTimeoutTimer?.cancel();
    _webrtcTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (_state == TransferState.connecting) {
        print('⏱️ WebRTC timeout! Switching to HTTP fallback...');
        _triggerHttpFallback();
      }
    });
  }

  void _handleDecline(SignalingMessage message) {
    print('Connection declined');
    _state = TransferState.failed;
    onError?.call('Connection declined by receiver');
    notifyListeners();
  }

  void _handleOffer(SignalingMessage message) async {
    final sdp = message.data['sdp'] as String;
    final offer = webrtc.RTCSessionDescription(sdp, 'offer');
    
    await _webrtcService.setRemoteDescription(offer);
    _isRemoteDescriptionSet = true;
    _processPendingIceCandidates();
    
    // Create and send answer
    final answer = await _webrtcService.createAnswer(offer);
    final answerMsg = SignalingMessage.answer(
      sessionId: _sessionId!,
      sdp: answer.sdp!,
    );
    await _signalingService.sendMessage(answerMsg);
  }

  void _handleAnswer(SignalingMessage message) async {
    final sdp = message.data['sdp'] as String;
    final answer = webrtc.RTCSessionDescription(sdp, 'answer');
    await _webrtcService.setRemoteDescription(answer);
    _isRemoteDescriptionSet = true;
    _processPendingIceCandidates();
  }

  void _handleRemoteIceCandidate(SignalingMessage message) async {
    final candidateStr = message.data['candidate'] as String;
    final sdpMid = message.data['sdpMid'] as String?;
    final sdpMLineIndex = message.data['sdpMLineIndex'] as int?;
    
    final candidate = webrtc.RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);
    
    if (_isRemoteDescriptionSet) {
      await _webrtcService.addCandidate(candidate);
    } else {
      print('🧊 Queuing ICE candidate (remote description not set)');
      _pendingIceCandidates.add(message);
    }
  }
  
  void _processPendingIceCandidates() async {
    if (_pendingIceCandidates.isEmpty) return;
    
    print('🧊 Processing ${_pendingIceCandidates.length} queued ICE candidates');
    for (final message in _pendingIceCandidates) {
      final candidateStr = message.data['candidate'] as String;
      final sdpMid = message.data['sdpMid'] as String?;
      final sdpMLineIndex = message.data['sdpMLineIndex'] as int?;
      
      final candidate = webrtc.RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);
      await _webrtcService.addCandidate(candidate);
    }
    _pendingIceCandidates.clear();
  }

  void _handleIceCandidate(webrtc.RTCIceCandidate candidate) async {
    // Send ICE candidate to remote peer
    final msg = SignalingMessage.iceCandidate(
      sessionId: _sessionId!,
      candidate: candidate.candidate!,
      sdpMid: candidate.sdpMid,
      sdpMLineIndex: candidate.sdpMLineIndex,
    );
    await _signalingService.sendMessage(msg);
  }

  void _handleDataChannelOpen() {
    print('Data channel opened - starting transfer');
    _webrtcTimeoutTimer?.cancel(); // Cancel timeout
    _state = TransferState.transferring; // Set to transferring immediately
    _progress = 0.0; // Show loading state
    notifyListeners();
    
    // Start file transfer if we're the sender
    if (_selectedFile != null) {
      _startFileTransfer();
    }
  }

  void _handleDataChannelClosed() {
    print('Data channel closed');
  }

  Future<void> _startFileTransfer() async {
    if (_selectedFile == null) return;
    
    _state = TransferState.transferring;
    _progress = 0.0;
    
    // Reset speed tracking for new file
    _bytesTransferred = 0;
    _lastBytesTransferred = 0;
    _lastSpeedUpdate = DateTime.now();
    _transferStartTime = DateTime.now();
    _currentSpeedBytesPerSecond = 0.0;
    _speedHistory.clear();
    
    notifyListeners();
    
    try {
      print('📂 Loading file: ${_selectedFile!.name} (${_selectedFile!.size} bytes)');
      
      // Load file data - either from bytes (clipboard/virtual files) or from file path
      final Uint8List fileData;
      if (_selectedFile!.bytes != null) {
        // Virtual file with bytes (e.g., clipboard content)
        fileData = _selectedFile!.bytes!;
        print('✅ Using file bytes directly (virtual file)');
      } else if (_selectedFile!.path != null) {
        // Real file with path
        final file = File(_selectedFile!.path!);
        fileData = await file.readAsBytes();
        print('✅ File loaded from path');
      } else {
        throw Exception('File has neither bytes nor path');
      }
      
      print('✅ File ready, starting transfer...');
      
      await _webrtcService.sendFile(
        fileData,
        _selectedFile!.name,
        _selectedFile!.size,
      );
      
      print('✅ File ${_currentFileIndex + 1}/${_filesToSend.length} sent');
      
      // Check if there are more files to send
      _currentFileIndex++;
      if (_currentFileIndex < _filesToSend.length) {
        // Transfer next file
        _selectedFile = _filesToSend[_currentFileIndex];
        _currentFileName = _selectedFile!.name;
        _progress = 0.0;
        notifyListeners();
        
        print('📤 Starting file ${_currentFileIndex + 1}/${_filesToSend.length}: ${_selectedFile!.name}');
        await _startFileTransfer(); // Recursive call for next file
      } else {
        // All files transferred
        await _webrtcService.sendBatchComplete();
        _state = TransferState.completed;
        onTransferComplete?.call();
        notifyListeners();
      }
    } catch (e) {
      _state = TransferState.failed;
      onError?.call('File transfer failed: $e');
      notifyListeners();
    }
  }

  void _handleProgress(double progress) {
    // Don't update progress if paused
    if (_state == TransferState.paused) {
      return;
    }
    _progress = progress;
    notifyListeners();
  }

  void _handleFileReceived(String filePath) {
    print('File received and saved to: $filePath');
    notifyListeners();
  }

  void _handleFileStart(String fileName, int fileSize) {
    print('Started receiving file: $fileName');
    
    // Find the index of this file in the list
    for (int i = 0; i < _filesToSend.length; i++) {
      if (_filesToSend[i].name == fileName) {
        _currentFileIndex = i;
        break;
      }
    }
    
    _currentFileName = fileName;
    _progress = 0.0;
    notifyListeners();
  }

  void _handleBatchComplete() {
    print('Batch transfer complete');
    _state = TransferState.completed;
    onTransferComplete?.call();
    notifyListeners();
  }

  void _handleConnectionClosed() {
    print('Signaling connection closed');
    if (_state != TransferState.completed) {
      _state = TransferState.failed;
      onError?.call('Connection lost');
      notifyListeners();
    }
  }

  void _handleFallbackUpload(SignalingMessage message) {
    print('📥 HTTP Fallback: Received download URL');
    final downloadUrl = message.data['downloadUrl'] as String;
    final fileName = message.data['fileName'] as String;
    final fileSize = message.data['fileSize'] as int;
    
    // Increment expected files count
    _expectedFilesCount++;
    
    // Start HTTP download
    _downloadViaHttp(downloadUrl, fileName, fileSize);
  }

  Future<void> _triggerHttpFallback() async {
    if (_selectedFile == null && _filesToSend.isEmpty) return;
    
    _useHttpFallback = true;
    _state = TransferState.transferring;
    notifyListeners();
    
    try {
      print('🌐 Starting HTTP fallback server...');
      
      final files = _filesToSend.isNotEmpty ? _filesToSend : [_selectedFile!];
      
      // Start HTTP server
      _httpServer = SignalingServer();
      final serverUrl = await _httpServer!.startServer(
        {},
        files: files,
      );
      
      print('✅ HTTP server started at: $serverUrl');
      
      // Send fallback message for each file
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        _currentFileName = file.name;
        _currentFileIndex = i;
        _progress = 0.0;
        notifyListeners();
        
        final fallbackMsg = SignalingMessage.fallbackUpload(
          sessionId: _sessionId!,
          downloadUrl: '$serverUrl/file/${Uri.encodeComponent(file.name)}',
          fileName: file.name,
          fileSize: file.size,
        );
        
        await _signalingService.sendMessage(fallbackMsg);
        print('✅ Sent HTTP fallback URL for ${file.name}');
        
        // Set up progress callback for real-time upload tracking
        _httpServer!.setProgressCallback(file.name, (progress) {
          _progress = progress;
          notifyListeners();
        });
        
        // Wait for receiver to download
        print('⏳ Waiting for download of ${file.name}...');
        
        try {
          final success = await _httpServer!.waitForTransfer(file.name).timeout(
            const Duration(minutes: 10),
            onTimeout: () {
              print('⚠️ Timeout waiting for HTTP download of ${file.name}');
              return false;
            },
          );
          
          if (success) {
            _progress = 1.0;
          }
        } catch (e) {
          print('⚠️ Error waiting for transfer: $e');
        }
        
        notifyListeners();
      }
      
      _state = TransferState.completed;
      print('✅ HTTP fallback transfer complete');
      onTransferComplete?.call();
      notifyListeners();
    } catch (e) {
      print('❌ HTTP Fallback error: $e');
      _state = TransferState.failed;
      onError?.call('HTTP fallback failed: $e');
      notifyListeners();
    }
  }

  Future<void> _downloadViaHttp(String url, String fileName, int fileSize) async {
    try {
      print('📥 Downloading file via HTTP: $url');
      
      // Find the index of this file in the list
      for (int i = 0; i < _filesToSend.length; i++) {
        if (_filesToSend[i].name == fileName) {
          _currentFileIndex = i;
          break;
        }
      }
      
      _currentFileName = fileName;
      _state = TransferState.transferring;
      _progress = 0.0;
      notifyListeners();
      
      // Use HttpClient for streaming with progress
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        final sink = file.openWrite();
        
        int downloadedBytes = 0;
        
        // Stream file with progress tracking
        await for (var chunk in response) {
          // Check if paused (for HTTP fallback)
          while (_state == TransferState.paused) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
          
          sink.add(chunk);
          downloadedBytes += chunk.length;
          
          // Update progress only if not paused
          if (_state != TransferState.paused) {
            _progress = downloadedBytes / fileSize;
            notifyListeners();
          }
          
          // Log progress every 10%
          if ((_progress * 100).toInt() % 10 == 0) {
            print('📥 Download progress: ${(_progress * 100).toStringAsFixed(0)}%');
          }
        }
        
        await sink.flush();
        await sink.close();
        httpClient.close();
        
        print('✅ File downloaded: $downloadedBytes bytes');
        print('✅ File saved to: $filePath');
        
        // Save to history database
        try {
          final db = DatabaseService();
          await db.insertReceivedFile(
            fileName: fileName,
            filePath: filePath,
            fileSize: fileSize,
            senderName: 'My Device', // TODO: Get actual sender name
          );
          print('✅ File added to history');
        } catch (e) {
          print('⚠️ Failed to save to history: $e');
        }
        
        _progress = 1.0;
        _receivedFilesCount++;
        
        print('✅ Received file $_receivedFilesCount/$_expectedFilesCount');
        
        // Only complete if all files received
        if (_receivedFilesCount >= _expectedFilesCount) {
          _state = TransferState.completed;
          onTransferComplete?.call();
          print('✅ All files received via HTTP fallback');
        }
        notifyListeners();
      } else {
        httpClient.close();
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ HTTP download failed: $e');
      _state = TransferState.failed;
      onError?.call('Download failed: $e');
      notifyListeners();
    }
  }

  void reset() {
    _webrtcTimeoutTimer?.cancel();
    _httpServer?.close();
    _webrtcService.close();
    _signalingService.close();
    _state = TransferState.idle;
    _sessionId = null;
    _currentFileName = null;
    _progress = 0.0;
    _selectedFile = null;
    _useHttpFallback = false;
    _pendingIceCandidates.clear();
    _isRemoteDescriptionSet = false;
    _expectedFilesCount = 0;
    _receivedFilesCount = 0;
    _currentTransferId = null;
    _isResuming = false;
    
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // ========== RESUME MESSAGE HANDLERS ==========
  
  void _handleResumeRequest(SignalingMessage message) {
    final transferId = message.data['transferId'] as String;
    final fileName = message.data['fileName'] as String;
    final lastChunkSeq = message.data['lastChunkSeq'] as int;
    
    print('🔄 Received resume request: $fileName @ chunk $lastChunkSeq');
    
    // Validate resume request
    _transferStateDb.getTransferState(transferId).then((state) {
      if (state == null || state.lastChunkSeq != lastChunkSeq) {
        // State mismatch - reject
        final rejectMsg = SignalingMessage.resumeReject(
          sessionId: message.sessionId,
          transferId: transferId,
          reason: state == null ? 'not_found' : 'state_mismatch',
        );
        _signalingService.sendMessage(rejectMsg);
        return;
      }
      
      // State matches - send ACK
      final ackMsg = SignalingMessage.resumeAck(
        sessionId: message.sessionId,
        transferId: transferId,
        ok: true,
        receiverLastChunk: state.lastChunkSeq,
      );
      _signalingService.sendMessage(ackMsg);
      
      // Ready to resume receiving
      print('✅ Resume ACK sent, ready to continue');
    });
  }
  
  void _handleResumeAck(SignalingMessage message) {
    final transferId = message.data['transferId'] as String;
    final ok = message.data['ok'] as bool;
    
    if (ok) {
      print('✅ Resume ACK received, continuing transfer');
      // Resume transfer will be handled by resumeTransfer method
    } else {
      final reason = message.data['reason'] as String?;
      print('❌ Resume rejected: $reason');
      onError?.call('Resume rejected: $reason');
    }
  }
  
  void _handleResumeReject(SignalingMessage message) {
    final transferId = message.data['transferId'] as String;
    final reason = message.data['reason'] as String;
    
    print('❌ Resume rejected: $reason');
    onError?.call('Cannot resume: $reason');
    
    // Mark transfer as failed
    _transferStateDb.failTransfer(transferId);
  }

  // ========== RESUME METHODS ==========
  
  /// Pause current transfer
  Future<void> pauseCurrentTransfer() async {
    print('⏸️⏸️⏸️ PAUSE BUTTON CLICKED');
    print('   Current state: $_state');
    print('   Transfer ID: $_currentTransferId');
    print('   HTTP Fallback: $_useHttpFallback');
    print('   Session ID: $_sessionId');
    
    if (_state == TransferState.transferring) {
      print('   ✅ Pausing transfer...');
      _state = TransferState.paused;
      
      // Save to database if we have a transfer ID
      if (_currentTransferId != null) {
        await _transferStateDb.pauseTransfer(_currentTransferId!);
      }
      
      // Pause WebRTC service
      _webrtcService.pauseSending();
      
      // Send pause signal to other device
      print('🔍 [PAUSE] Checking signaling connection...');
      print('🔍 [PAUSE] Signaling connected: ${_signalingService.isConnected}');
      
      if (_sessionId != null) {
        if (!_signalingService.isConnected) {
          print('⚠️ [PAUSE] WARNING: Signaling not connected, pause signal may not reach other device');
          print('⚠️ [PAUSE] Other device will not pause automatically');
        }
        
        try {
          print('📤 Attempting to send PAUSE signal...');
          final pauseMsg = SignalingMessage.pause(sessionId: _sessionId!);
          await _signalingService.sendMessage(pauseMsg);
          print('📤 ✅ PAUSE signal sent successfully to other device');
        } catch (e) {
          print('⚠️ ❌ Failed to send pause signal: $e');
          print('⚠️ Other device may continue transferring');
          // Still pause locally even if signal fails
        }
      } else {
        print('⚠️ Cannot send pause signal - no session ID');
      }
      
      // VERIFY that pause was actually set
      await Future.delayed(const Duration(milliseconds: 50));
      final actuallyPaused = _webrtcService.isPaused;
      print('   🔍 WebRTC Service isPaused: $actuallyPaused');
      
      if (actuallyPaused) {
        print('✅✅✅ PAUSE CONFIRMED - Transfer is paused');
      } else {
        print('❌❌❌ PAUSE FAILED - WebRTC service is NOT paused!');
      }
      
      print('⏸️ Paused transfer');
      notifyListeners();
    } else {
      print('   ❌ Cannot pause - state is $_state');
    }
  }
  
  /// Resume current paused transfer
  Future<void> resumeCurrentTransfer() async {
    print('▶️▶️▶️ RESUME BUTTON CLICKED');
    print('   Current state: $_state');
    print('   Transfer ID: $_currentTransferId');
    print('   Session ID: $_sessionId');
    
    if (_state == TransferState.paused) {
      print('   ✅ Resuming transfer...');
      _state = TransferState.transferring;
      _webrtcService.resumeSending();
      
      // Send resume signal to other device
      print('🔍 [RESUME] Checking signaling connection...');
      print('🔍 [RESUME] Signaling connected: ${_signalingService.isConnected}');
      
      if (_sessionId != null) {
        if (!_signalingService.isConnected) {
          print('⚠️ [RESUME] WARNING: Signaling not connected, resume signal may not reach other device');
        }
        
        try {
          print('📤 Attempting to send RESUME signal...');
          final resumeMsg = SignalingMessage.resume(sessionId: _sessionId!);
          await _signalingService.sendMessage(resumeMsg);
          print('📤 ✅ RESUME signal sent successfully to other device');
        } catch (e) {
          print('⚠️ ❌ Failed to send resume signal: $e');
          // Still resume locally even if signal fails
        }
      } else {
        print('⚠️ Cannot send resume signal - no session ID');
      }
      
      print('▶️ Resumed transfer');
      notifyListeners();
    } else {
      print('   ❌ Cannot resume - state is $_state');
    }
  }
  
  /// Handle pause signal from other device
  void _handlePauseSignal(SignalingMessage message) {
    print('📥 RECEIVED PAUSE SIGNAL from other device');
    if (_state == TransferState.transferring) {
      _state = TransferState.paused;
      _webrtcService.pauseSending();
      print('⏸️ Paused by remote device');
      notifyListeners();
    }
  }
  
  /// Handle resume signal from other device  
  void _handleResumeSignal(SignalingMessage message) {
    print('📥 RECEIVED RESUME SIGNAL from other device');
    if (_state == TransferState.paused) {
      _state = TransferState.transferring;
      _webrtcService.resumeSending();
      print('▶️ Resumed by remote device');
      notifyListeners();
    }
  }
  
  /// Resume a paused transfer
  Future<bool> resumeTransfer(String transferId) async {
    final state = await _transferStateDb.getTransferState(transferId);
    
    if (state == null || !state.canResume) {
      print('❌ Cannot resume transfer: $transferId');
      return false;
    }
    
    print('🔄 Resuming transfer: $transferId');
    _currentTransferId = transferId;
    _partnerDeviceId = state.partnerDeviceId;
    _partnerDeviceName = state.partnerDeviceName;
    _partnerIp = state.partnerIp;
    _isResuming = true;
    
    try {
      // 1. Connect to partner device IP
      print('📡 Connecting to partner: $_partnerIp');
      final connected = await _signalingService.connectToDevice(_partnerIp!);
      
      if (!connected) {
        print('❌ Failed to connect to partner device');
        onError?.call('Could not connect to partner device');
        return false;
      }
      
      // 2. Generate new session ID for resume
      _sessionId = const Uuid().v4();
      
      // 3. Send resume request
      final resumeMsg = SignalingMessage.resumeRequest(
        sessionId: _sessionId!,
        transferId: transferId,
        fileName: state.fileName,
        fileSize: state.fileSize,
        lastChunkSeq: state.lastChunkSeq,
        totalChunks: state.totalChunks,
        chunkSize: state.chunkSize,
        fileHash: state.fileHash,
      );
      
      _signalingService.sendMessage(resumeMsg);
      print('📤 Resume request sent');
      
      // 4. Wait for resumeAck (handled by _handleResumeAck)
      // The actual resume will proceed once ACK is received
      // For now, mark as attempting to resume
      await _transferStateDb.updateTransferState(
        state.copyWith(
          status: 'in_progress',
          lastUpdated: DateTime.now(),
        ),
      );
      
      _state = TransferState.connecting;
      notifyListeners();
      
      return true;
    } catch (e) {
      print('❌ Error resuming transfer: $e');
      onError?.call('Resume failed: $e');
      _isResuming = false;
      return false;
    }
  }
  
  /// Get all resumable transfers
  Future<List<ts.TransferState>> getResumableTransfers() async {
    return await _transferStateDb.getResumableTransfers();
  }
  
  /// Get resumable transfers for a specific device
  Future<List<ts.TransferState>> getPartnerTransfers(String deviceId) async {
    return await _transferStateDb.getPartnerTransfers(deviceId, status: 'paused');
  }
  
  /// Delete a transfer state
  Future<void> deleteTransferState(String transferId) async {
    await _transferStateDb.deleteTransferState(transferId);
  }
  
  /// Clean up old completed transfers
  Future<int> cleanupCompletedTransfers() async {
    return await _transferStateDb.deleteCompletedTransfers();
  }
  
  /// Clean up old transfers (>7 days)
  Future<int> cleanupOldTransfers({int days = 7}) async {
    return await _transferStateDb.deleteOldTransfers(days: days);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _webrtcTimeoutTimer?.cancel();
    _httpServer?.close();
    _webrtcService.close();
    _signalingService.close();
    super.dispose();
  }
}
