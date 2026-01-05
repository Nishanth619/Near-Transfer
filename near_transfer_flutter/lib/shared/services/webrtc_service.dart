import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:path_provider/path_provider.dart';
import '../../core/network_config.dart';

class WebRTCService {
  webrtc.RTCPeerConnection? _peerConnection;
  webrtc.RTCDataChannel? _dataChannel;
  
  // Callbacks
  Function(webrtc.RTCIceCandidate)? onIceCandidate;
  Function(webrtc.RTCSessionDescription)? onLocalDescription;
  Function(String)? onConnectionStateChange;
  Function(double)? onProgress;
  Function()? onDataChannelOpen;
  Function()? onDataChannelClosed;
  Function(String filePath)? onFileReceived;
  Function(String fileName, int fileSize)? onFileStart;
  Function()? onBatchComplete;
  
  // File transfer state
  Map<String, dynamic>? _currentFileMetadata;
  List<Uint8List> _receivedChunks = [];
  int _totalChunks = 0;
  int _receivedChunkCount = 0;
  String? _receivedFileName;
  int? _receivedFileSize;
  
  // Sending state
  int _currentChunkSeq = 0;
  bool _isPaused = false;
  Timer? _dataChannelOpenTimer;
  Completer<void>? _fileAckCompleter;
  
  bool get isDataChannelOpen => _dataChannel?.state == webrtc.RTCDataChannelState.RTCDataChannelOpen;
  bool get isPaused => _isPaused; // Public getter to check pause state
  
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': NetworkConfig.stunServer},
    ],
    'iceTransportPolicy': 'all',
    'iceCandidatePoolSize': 10,
  };

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
  }

  Future<void> initConnection({bool isOfferer = false}) async {
    
    _peerConnection = await webrtc.createPeerConnection(_configuration);

    _peerConnection!.onIceCandidate = (candidate) {
      onIceCandidate?.call(candidate);
    };

    _peerConnection!.onConnectionState = (state) {
      onConnectionStateChange?.call(state.toString());
    };

    _peerConnection!.onIceConnectionState = (state) {
    };

    if (isOfferer) {
      // Create data channel
      final dataChannelInit = webrtc.RTCDataChannelInit()
        ..ordered = true
        ..maxRetransmits = 30;
      
      _dataChannel = await _peerConnection!.createDataChannel(
        'fileTransfer',
        dataChannelInit,
      );
      _setupDataChannel(_dataChannel!);
      
      // Start timeout timer
      _dataChannelOpenTimer = Timer(NetworkConfig.webrtcTimeout, () {
        if (!isDataChannelOpen) {
        }
      });
    } else {
      // Wait for data channel
      _peerConnection!.onDataChannel = (channel) {
        _dataChannel = channel;
        _setupDataChannel(channel);
      };
    }
  }

  void _setupDataChannel(webrtc.RTCDataChannel channel) {
    
    channel.onMessage = (message) {
      _handleDataChannelMessage(message);
    };

    channel.onDataChannelState = (state) {
      if (state == webrtc.RTCDataChannelState.RTCDataChannelOpen) {
        _dataChannelOpenTimer?.cancel();
        onDataChannelOpen?.call();
      } else if (state == webrtc.RTCDataChannelState.RTCDataChannelClosed) {
        onDataChannelClosed?.call();
      }
    };
  }

  void _handleDataChannelMessage(webrtc.RTCDataChannelMessage message) {
    if (message.isBinary) {
      // Binary chunk
      _receivedChunks.add(message.binary);
      _receivedChunkCount++;
      
      if (_totalChunks > 0) {
        final progress = _receivedChunkCount / _totalChunks;
        onProgress?.call(progress);
        if (_receivedChunkCount % 10 == 0 || _receivedChunkCount == _totalChunks) {
           _log('Receive chunk $_receivedChunkCount/$_totalChunks');
        }
      }
    } else {
      // JSON message
      try {
        final json = jsonDecode(message.text) as Map<String, dynamic>;
        final type = json['type'] as String;
        
        if (type == 'meta') {
          // File metadata
          _receivedFileName = json['name'] as String;
          _receivedFileSize = json['size'] as int;
          final chunkSize = json['chunkSize'] as int;
          _totalChunks = (_receivedFileSize! / chunkSize).ceil();
          _receivedChunks.clear();
          _receivedChunkCount = 0;
          
          _log('Receive metadata: $_receivedFileName ($_receivedFileSize bytes)');
          onFileStart?.call(_receivedFileName!, _receivedFileSize!);
        } else if (type == 'end') {
          // Transfer complete
          _log('Receive EOF for file: $_receivedFileName');
          // Capture data for assembly and clear state immediately to prepare for next file
          final chunks = List<Uint8List>.from(_receivedChunks);
          final fileName = _receivedFileName!;
          
          _receivedChunks.clear();
          _receivedChunkCount = 0;
          _totalChunks = 0;
          _receivedFileName = null;
          _receivedFileSize = null;
          
          _assembleReceivedFile(chunks, fileName);
        } else if (type == 'batch_complete') {
          // All files transferred
          onBatchComplete?.call();
        } else if (type == 'ack') {
          // ACK received (optional)
          final seq = json['seq'] as int;
          // print('ACK received for chunk $seq');
        } else if (type == 'file_ack') {
          // File received ACK
          final fileName = json['fileName'] as String;
          _log('ACK received (sender) for file: $fileName');
          if (_fileAckCompleter != null && !_fileAckCompleter!.isCompleted) {
            _fileAckCompleter!.complete();
          }
        }
      } catch (e) {
      }
    }
  }

  Future<void> _assembleReceivedFile(List<Uint8List> chunks, String fileName) async {
    try {
      // Combine all chunks
      int totalSize = 0;
      for (final chunk in chunks) {
        totalSize += chunk.length;
      }
      
      final fileData = Uint8List(totalSize);
      int offset = 0;
      for (final chunk in chunks) {
        fileData.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      
      
      // Save file to app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileData);
      
      await file.writeAsBytes(fileData);
      
      _log('File saved to disk: $filePath');
      
      // Notify completion
      onFileReceived?.call(filePath);
      
      // Send ACK
      if (_dataChannel != null && isDataChannelOpen) {
        final ackMsg = {
          'type': 'file_ack',
          'fileName': fileName,
        };
        _dataChannel!.send(webrtc.RTCDataChannelMessage(jsonEncode(ackMsg)));
        _log('Send ACK for file: $fileName');
      }
    } catch (e) {
    }
  }

  Future<webrtc.RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<webrtc.RTCSessionDescription> createAnswer(webrtc.RTCSessionDescription offer) async {
    await _peerConnection!.setRemoteDescription(offer);
    
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(webrtc.RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
  }

  Future<void> addCandidate(webrtc.RTCIceCandidate candidate) async {
    try {
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
    }
  }

  Future<void> sendFile(Uint8List fileData, String fileName, int fileSize, {int startChunkIndex = 0}) async {
    if (_dataChannel == null || !isDataChannelOpen) {
      throw Exception('Data channel not open');
    }

    if (startChunkIndex > 0) {
    }
    
    // Send metadata
    final meta = {
      'type': 'meta',
      'name': fileName,
      'size': fileSize,
      'chunkSize': NetworkConfig.chunkSize,
      if (startChunkIndex > 0) 'startChunk': startChunkIndex, // For resume
    };
    _dataChannel!.send(webrtc.RTCDataChannelMessage(jsonEncode(meta)));
    _log('Send metadata: $fileName');
    
    // Calculate starting position for resume
    final startByteIndex = startChunkIndex * NetworkConfig.chunkSize;
    _currentChunkSeq = startChunkIndex;
    final totalChunks = (fileSize / NetworkConfig.chunkSize).ceil();
    
    for (int i = startByteIndex; i < fileSize; i += NetworkConfig.chunkSize) {
      // Check if paused - this happens BEFORE sending each chunk
      if (_isPaused) {
        
        int pauseCounter = 0;
        while (_isPaused) {
          await Future.delayed(const Duration(milliseconds: 500));
          pauseCounter++;
          if (pauseCounter % 2 == 0) {  // Log every second
          }
        }
        
      }
      
      // Flow control: wait if buffer is full
      while ((_dataChannel!.bufferedAmount ?? 0) > NetworkConfig.maxBufferedAmount) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      final end = (i + NetworkConfig.chunkSize < fileSize) 
          ? i + NetworkConfig.chunkSize 
          : fileSize;
      
      final chunk = fileData.sublist(i, end);
      _dataChannel!.send(webrtc.RTCDataChannelMessage.fromBinary(chunk));
      
      _currentChunkSeq++;
      final progress = _currentChunkSeq / totalChunks;
      onProgress?.call(progress);
      
      if (_currentChunkSeq % 10 == 0 || _currentChunkSeq == totalChunks) {
        _log('Send chunk $_currentChunkSeq/$totalChunks');
      }
    }
    
    // Send end message
    final endMsg = {
      'type': 'end',
      'checksum': '', // TODO: Calculate SHA256
    };
    _dataChannel!.send(webrtc.RTCDataChannelMessage(jsonEncode(endMsg)));
    _log('Send EOF for file: $fileName');
    
    
    // Wait for ACK
    _fileAckCompleter = Completer<void>();
    try {
      await _fileAckCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          // Don't throw, just proceed (might be legacy receiver)
        },
      );
    } catch (e) {
    }
    _log('sendFile() returned (sender)');
  }

  Future<void> sendBatchComplete() async {
    if (_dataChannel == null || !isDataChannelOpen) return;
    
    final msg = {
      'type': 'batch_complete',
    };
    _dataChannel!.send(webrtc.RTCDataChannelMessage(jsonEncode(msg)));
  }

  void pauseSending() {
    _isPaused = true;
  }

  void resumeSending() {
    _isPaused = false;
  }

  void close() {
    _dataChannelOpenTimer?.cancel();
    _dataChannel?.close();
    _peerConnection?.close();
    _dataChannel = null;
    _peerConnection = null;
    _receivedChunks.clear();
  }
}
