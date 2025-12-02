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
import '../services/database_service.dart';
import '../models/discovered_device.dart';

enum TransferState {
  idle,
  connecting,
  connected,
  transferring,
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
  
  // ICE Candidate Queue
  final List<SignalingMessage> _pendingIceCandidates = [];
  bool _isRemoteDescriptionSet = false;
  
  String? get currentFileName => _currentFileName;
  double get progress => _progress;
  bool get useHttpFallback => _useHttpFallback;
  int get currentFileIndex => _currentFileIndex;
  int get totalFiles => _filesToSend.length;
  List<PlatformFile> get files => _filesToSend;
  
  // Track received files for HTTP fallback
  int _expectedFilesCount = 0;
  int _receivedFilesCount = 0;
  
  // Callbacks for UI
  Function(String senderName, String fileName, int fileSize, List<Map<String, dynamic>>? files, Function() onAccept, Function() onDecline)? onConnectionRequest;
  Function()? onTransferComplete;
  Function(String error)? onError;
  Function()? onWebRTCTimeout;
  
  List<PlatformFile> _filesToSend = [];
  int _currentFileIndex = 0;
  PlatformFile? _selectedFile;
  
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
    _webrtcService.onProgress = _handleProgress;
    _webrtcService.onDataChannelOpen = _handleDataChannelOpen;
    _webrtcService.onDataChannelClosed = _handleDataChannelClosed;
    _webrtcService.onFileReceived = _handleFileReceived;
    _webrtcService.onFileStart = _handleFileStart;
    _webrtcService.onBatchComplete = _handleBatchComplete;
  }

  // Sender: Connect to receiver and initiate transfer
  Future<void> connectToDevice(DiscoveredDevice device, List<PlatformFile> files) async {
    _sessionId = const Uuid().v4();
    _state = TransferState.connecting;
    _filesToSend = files;
    _currentFileIndex = 0;
    _selectedFile = files.first;
    _currentFileName = files.first.name;
    notifyListeners();
    
    try {
      // Initialize WebRTC
      await _webrtcService.initConnection(isOfferer: true);
      
      // Connect via TCP
      final connected = await _signalingService.connectToDevice(device.ip);
      if (!connected) {
        throw Exception('Failed to connect to device');
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
    }
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
          sink.add(chunk);
          downloadedBytes += chunk.length;
          
          // Update progress
          _progress = downloadedBytes / fileSize;
          notifyListeners();
          
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
    
    if (!_isDisposed) {
      notifyListeners();
    }
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
