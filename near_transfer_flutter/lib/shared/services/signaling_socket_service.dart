import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/network_config.dart';

enum SignalingMessageType {
  connectRequest,
  accept,
  decline,
  offer,
  answer,
  iceCandidate,
  fallbackUpload,
  preConnect, // New message type for locking receiver
  resumeRequest, // Request to resume interrupted transfer
  resumeAck, // Acknowledge resume request
  resumeReject, // Reject resume request
  pause, // Pause current transfer
  resume, // Resume current transfer
  groupCreate, // Create group transfer session
  groupJoin, // Join group transfer session
  groupLeave, // Leave group transfer session
  groupBroadcast, // Broadcast message to group
  groupMemberUpdate, // Member list changed
}

class SignalingMessage {
  final SignalingMessageType type;
  final String sessionId;
  final Map<String, dynamic> data;

  SignalingMessage({
    required this.type,
    required this.sessionId,
    required this.data,
  });

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = SignalingMessageType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
    );

    return SignalingMessage(
      type: type,
      sessionId: json['sessionId'] as String,
      data: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'sessionId': sessionId,
      ...data,
    };
  }
  
  static SignalingMessage preConnect({
    required String sessionId,
    required String senderName,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.preConnect,
      sessionId: sessionId,
      data: {
        'senderName': senderName,
      },
    );
  }

  static SignalingMessage connectRequest({
    required String sessionId,
    required String senderName,
    required String fileName,
    required int fileSize,
    List<Map<String, dynamic>>? files,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.connectRequest,
      sessionId: sessionId,
      data: {
        'senderName': senderName,
        'fileName': fileName,
        'fileSize': fileSize,
        if (files != null) 'files': files,
      },
    );
  }

  static SignalingMessage accept(String sessionId) {
    return SignalingMessage(
      type: SignalingMessageType.accept,
      sessionId: sessionId,
      data: {},
    );
  }

  static SignalingMessage decline(String sessionId) {
    return SignalingMessage(
      type: SignalingMessageType.decline,
      sessionId: sessionId,
      data: {},
    );
  }

  static SignalingMessage offer({
    required String sessionId,
    required String sdp,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.offer,
      sessionId: sessionId,
      data: {'sdp': sdp},
    );
  }

  static SignalingMessage answer({
    required String sessionId,
    required String sdp,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.answer,
      sessionId: sessionId,
      data: {'sdp': sdp},
    );
  }

  static SignalingMessage iceCandidate({
    required String sessionId,
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.iceCandidate,
      sessionId: sessionId,
      data: {
        'candidate': candidate,
        'sdpMid': sdpMid,
        'sdpMLineIndex': sdpMLineIndex,
      },
    );
  }

  static SignalingMessage fallbackUpload({
    required String sessionId,
    required String downloadUrl,
    required String fileName,
    required int fileSize,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.fallbackUpload,
      sessionId: sessionId,
      data: {
        'downloadUrl': downloadUrl,
        'fileName': fileName,
        'fileSize': fileSize,
      },
    );
  }

  static SignalingMessage resumeRequest({
    required String sessionId,
    required String transferId,
    required String fileName,
    required int fileSize,
    required int lastChunkSeq,
    required int totalChunks,
    required int chunkSize,
    String? fileHash,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.resumeRequest,
      sessionId: sessionId,
      data: {
        'transferId': transferId,
        'fileName': fileName,
        'fileSize': fileSize,
        'lastChunkSeq': lastChunkSeq,
        'totalChunks': totalChunks,
        'chunkSize': chunkSize,
        if (fileHash != null) 'fileHash': fileHash,
      },
    );
  }

  static SignalingMessage resumeAck({
    required String sessionId,
    required String transferId,
    required bool ok,
    required int receiverLastChunk,
    String? reason,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.resumeAck,
      sessionId: sessionId,
      data: {
        'transferId': transferId,
        'ok': ok,
        'receiverLastChunk': receiverLastChunk,
        if (reason != null) 'reason': reason,
      },
    );
  }

  static SignalingMessage resumeReject({
    required String sessionId,
    required String transferId,
    required String reason,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.resumeReject,
      sessionId: sessionId,
      data: {
        'transferId': transferId,
        'reason': reason,
      },
    );
  }
  
  static SignalingMessage pause({required String sessionId}) {
    return SignalingMessage(
      type: SignalingMessageType.pause,
      sessionId: sessionId,
      data: {},
    );
  }
  
  static SignalingMessage resume({required String sessionId}) {
    return SignalingMessage(
      type: SignalingMessageType.resume,
      sessionId: sessionId,
      data: {},
    );
  }
  
  // Group transfer messages
  static SignalingMessage groupCreate({
    required String sessionId,
    required String groupId,
    required String hostDeviceId,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.groupCreate,
      sessionId: sessionId,
      data: {
        'groupId': groupId,
        'hostDeviceId': hostDeviceId,
      },
    );
  }
  
  static SignalingMessage groupJoin({
    required String sessionId,
    required String groupId,
    required String deviceId,
    required String deviceName,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.groupJoin,
      sessionId: sessionId,
      data: {
        'groupId': groupId,
        'deviceId': deviceId,
        'deviceName': deviceName,
      },
    );
  }
  
  static SignalingMessage groupLeave({
    required String sessionId,
    required String groupId,
    required String deviceId,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.groupLeave,
      sessionId: sessionId,
      data: {
        'groupId': groupId,
        'deviceId': deviceId,
      },
    );
  }
  
  static SignalingMessage groupBroadcast({
    required String sessionId,
    required String groupId,
    required Map<String, dynamic> payload,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.groupBroadcast,
      sessionId: sessionId,
      data: {
        'groupId': groupId,
        'payload': payload,
      },
    );
  }
  
  static SignalingMessage groupMemberUpdate({
    required String sessionId,
    required String groupId,
    required List<Map<String, String>> members,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.groupMemberUpdate,
      sessionId: sessionId,
      data: {
        'groupId': groupId,
        'members': members,
      },
    );
  }
}

class SignalingSocketService extends ChangeNotifier {
  ServerSocket? _serverSocket;
  Socket? _clientSocket;
  
  // Receiver's device info for discovery responses
  String? _deviceId;
  String? _deviceName;
  String? _deviceIp;
  int? _devicePort;
  
  
  // Shake mode state
  bool _isShakeMode = false;
  int? _shakeTimestamp;
  
  bool _isServerMode = false;
  bool get isServerMode => _isServerMode;
  
  /// Check if signaling connection is active
  bool get isConnected => _clientSocket != null;
  
  Function(SignalingMessage)? onMessageReceived;
  Function()? onConnectionClosed;
  
  /// Enable shake mode with timestamp
  void enableShakeMode(int timestamp) {
    _isShakeMode = true;
    _shakeTimestamp = timestamp;
    print('🤝 SignalingSocket: Shake mode enabled with timestamp: $timestamp');
  }

  /// Disable shake mode
  void disableShakeMode() {
    _isShakeMode = false;
    _shakeTimestamp = null;
    print('🤝 SignalingSocket: Shake mode disabled');
  }
  
  // Start server mode (receiver) - with device info for discovery
  Future<void> startServer({
    required String deviceId,
    required String deviceName,
    required String deviceIp,
  }) async {
    if (_serverSocket != null) return;
    
    // Store device info for discovery responses
    _deviceId = deviceId;
    _deviceName = deviceName;
    _deviceIp = deviceIp;
    _devicePort = NetworkConfig.tcpPort;
    
    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        NetworkConfig.tcpPort,
      );
      
      _isServerMode = true;
      
      print('✅ Signaling server started on $deviceIp:${NetworkConfig.tcpPort}');
      
      _serverSocket!.listen((socket) {
        print('Client connected: ${socket.remoteAddress.address}');
        _handleClientConnection(socket);
      });
      
      notifyListeners();
    } catch (e) {
      print('Error starting signaling server: $e');
      rethrow;
    }
  }

  void _handleClientConnection(Socket socket) {
    bool isDiscoveryProbe = false;
    String buffer = '';
    
    socket.listen(
      (data) {
        try {
          buffer += utf8.decode(data);
          
          // Process all complete messages (delimited by newlines)
          while (buffer.contains('\n')) {
            final newlineIndex = buffer.indexOf('\n');
            final message = buffer.substring(0, newlineIndex);
            buffer = buffer.substring(newlineIndex + 1);
            
            if (message.trim().isEmpty) continue;
            
            final json = jsonDecode(message) as Map<String, dynamic>;
          
            print('📨 Received message type: ${json['type']} from ${socket.remoteAddress.address}');
            
            // Handle discovery probe - TEMPORARY CONNECTION
            if (json['type'] == 'discovery_probe') {
              isDiscoveryProbe = true;
              print('🔍 Discovery probe from ${socket.remoteAddress.address}');
              
              // Respond with OUR device info (receiver's info)
              final response = {
                'type': 'discovery_response',
                'deviceId': _deviceId,
                'deviceName': _deviceName,
                'ip': _deviceIp,
                'port': _devicePort,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'isShaking': _isShakeMode,
                if (_shakeTimestamp != null) 'shakeTimestamp': _shakeTimestamp,
              };
              
              final responseJson = jsonEncode(response) + '\n';
              print('✅ Sending discovery response: $_deviceName @ $_deviceIp');
              print('📤 Response size: ${responseJson.length} bytes');
              
              socket.add(utf8.encode(responseJson));
              socket.flush().then((_) {
                print('✅ Discovery response sent successfully');
                // Sender will close the connection after receiving response
              });
              return;
            }
            
            // This is a REAL signaling connection - set it as the client socket
            if (_clientSocket == null && !isDiscoveryProbe) {
              _clientSocket = socket;
              print('✅ Signaling client connected from ${socket.remoteAddress.address}');
            }
            
            // Handle regular signaling messages
            final signalingMessage = SignalingMessage.fromJson(json);
            
            print('📥 [RECV] Received signaling message: ${signalingMessage.type}');
            print('📥 [RECV] Calling onMessageReceived callback...');
            onMessageReceived?.call(signalingMessage);
            print('📥 [RECV] Callback completed');
          }
        } catch (e) {
          print('❌ Error parsing message: $e');
        }
      },
      onDone: () {
        // Only notify if this was the actual signaling socket
        if (socket == _clientSocket) {
          print('🔌 Signaling client disconnected');
          _clientSocket = null;
          onConnectionClosed?.call();
        } else {
          print('🔌 Discovery probe connection closed');
        }
      },
      onError: (error) {
        print('❌ Socket error: $error');
        // Only notify if this was the actual signaling socket
        if (socket == _clientSocket) {
          _clientSocket?.destroy();
          _clientSocket = null;
          onConnectionClosed?.call();
        } else {
          socket.destroy();
        }
      },
    );
  }

  // Connect to remote device (sender)
  Future<bool> connectToDevice(String ip) async {
    if (_clientSocket != null) {
      print('Already connected');
      return false;
    }
    
    try {
      print('Connecting to $ip:${NetworkConfig.tcpPort}...');
      
      _clientSocket = await Socket.connect(
        ip,
        NetworkConfig.tcpPort,
        timeout: NetworkConfig.sessionConnectTimeout,
      );
      
      print('Connected to $ip');
      
      String buffer = '';
      _clientSocket!.listen(
        (data) {
          try {
            buffer += utf8.decode(data);
            
            // Process all complete messages (delimited by newlines)
            while (buffer.contains('\n')) {
              final newlineIndex = buffer.indexOf('\n');
              final message = buffer.substring(0, newlineIndex);
              buffer = buffer.substring(newlineIndex + 1);
              
              if (message.trim().isEmpty) continue;
              
              final json = jsonDecode(message) as Map<String, dynamic>;
              final signalingMessage = SignalingMessage.fromJson(json);
              
              print('Received message: ${signalingMessage.type}');
              onMessageReceived?.call(signalingMessage);
            }
          } catch (e) {
            print('Error parsing message: $e');
          }
        },
        onDone: () {
          print('Connection closed');
          _clientSocket = null;
          onConnectionClosed?.call();
        },
        onError: (error) {
          print('Socket error: $error');
          _clientSocket?.destroy();
          _clientSocket = null;
          onConnectionClosed?.call();
        },
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error connecting to device: $e');
      _clientSocket = null;
      return false;
    }
  }

  // Send message
  Future<void> sendMessage(SignalingMessage message) async {
    print('📤 [SEND] Attempting to send ${message.type}');
    print('📤 [SEND] Client socket status: ${_clientSocket != null ? "CONNECTED" : "NULL"}');
    
    if (_clientSocket == null) {
      print('❌ [SEND] Cannot send message: not connected');
      return;
    }
    
    try {
      final json = jsonEncode(message.toJson()) + '\n';
      _clientSocket!.add(utf8.encode(json));
      await _clientSocket!.flush();
      
      print('✅ [SEND] Sent message: ${message.type}');
    } catch (e) {
      print('❌ [SEND] Error sending message: $e');
      print('❌ [SEND] Socket may be closed, attempting to report error');
      rethrow;
    }
  }

  // Close connection
  void close() {
    _clientSocket?.destroy();
    _clientSocket = null;
    _serverSocket?.close();
    _serverSocket = null;
    _isServerMode = false;
    notifyListeners();
    print('Signaling socket closed');
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}
