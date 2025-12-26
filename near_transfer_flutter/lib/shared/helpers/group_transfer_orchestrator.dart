import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import '../../shared/models/group_session.dart' as group_models;
import '../models/discovered_device.dart';
import '../services/group_session_service.dart';
import '../services/webrtc_service.dart';
import '../services/signaling_socket_service.dart';
import '../services/group_http_coordinator.dart';

/// Complete group transfer orchestrator with full multi-peer support
class GroupTransferOrchestrator {
  final GroupSessionService groupService;
  final GroupHttpCoordinator httpCoordinator;
  
  // Per-device connections
  final Map<String, WebRTCService> _webrtcServices = {};
  final Map<String, SignalingSocketService> _signalingServices = {};
  final Map<String, Completer<bool>> _connectionCompleters = {};
  
  // State tracking
  List<PlatformFile> _files = [];
  
  GroupTransferOrchestrator({
    required this.groupService,
    required this.httpCoordinator,
  });

  /// Start group transfer with full orchestration
  Future<void> startGroupTransfer(
    List<DiscoveredDevice> devices,
    List<PlatformFile> files,
  ) async {
    if (devices.isEmpty) throw ArgumentError('No devices selected');
    if (files.isEmpty) throw ArgumentError('No files selected');

    debugPrint('🎯 Starting FULL group transfer to ${devices.length} devices');
    
    _files = files;

    try {
      // Step 1: Create group session
      await groupService.createGroup();
      for (var device in devices) {
        groupService.addMember(device);
      }

      // Step 2: Connect to all devices
      await _connectToAllDevices(devices);

      // Step 3: Send all files
      for (int i = 0; i < files.length; i++) {
        debugPrint('📤 Broadcasting file ${i + 1}/${files.length}: ${files[i].name}');
        await _broadcastFile(files[i], i);
      }

      debugPrint('✅ Group transfer completed successfully');
      
    } catch (e) {
      debugPrint('❌ Group transfer failed: $e');
      rethrow;
    }
  }

  /// Connect to all devices with proper WebRTC setup
  Future<void> _connectToAllDevices(List<DiscoveredDevice> devices) async {
    debugPrint('📡 Connecting to ${devices.length} devices...');

    final connectionTasks = devices.map((device) => _connectToDevice(device));
    final results = await Future.wait(
      connectionTasks,
      eagerError: false, // Don't stop on first error
    );

    final successCount = results.where((r) => r).length;
    debugPrint('📊 Connected: $successCount/${devices.length} devices');

    if (successCount == 0) {
      throw Exception('Failed to connect to any device');
    }
  }

  /// Connect to a single device with full WebRTC flow
  Future<bool> _connectToDevice(DiscoveredDevice device) async {
    try {
      debugPrint('📱 Connecting to ${device.deviceName} (${device.ip})...');

      // Create services for this device
      final webrtc = WebRTCService();
      final signaling = SignalingSocketService();
      
      _webrtcServices[device.deviceId] = webrtc;
      _signalingServices[device.deviceId] =signaling;
      _connectionCompleters[device.deviceId] = Completer<bool>();

      // Setup WebRTC callbacks
      _setupWebRTCCallbacks(device.deviceId, webrtc);

      // Initialize WebRTC
      await webrtc.initConnection(isOfferer: true);

      // Setup signaling
      await signaling.startServer(
        deviceId: 'group_sender_${DateTime.now().millisecondsSinceEpoch}',
        deviceName: 'GroupSender',
        deviceIp: device.ip,
      );

      // Connect to device's signaling server
      await signaling.connectToDevice(device.ip);

      // Setup signaling message handler
      _setupSignalingHandler(device.deviceId, device, signaling, webrtc);

      // Send connection request
      await _sendConnectionRequest(device, signaling);

      // Wait for connection with timeout
      final connected = await _connectionCompleters[device.deviceId]!.future
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => false,
          );

      if (connected) {
        debugPrint('✅ Connected to ${device.deviceName}');
        groupService.updateDeviceState(
          device.deviceId,
          connectionState: group_models.ConnectionState.connected,
        );
        return true;
      } else {
        throw Exception('Connection timeout');
      }

    } catch (e) {
      debugPrint('❌ Failed to connect to ${device.deviceName}: $e');
      groupService.markDeviceAsFailed(device.deviceId, e.toString());
      
      // Try HTTP fallback
      await _setupHttpFallback(device.deviceId);
      return false;
    }
  }

  /// Setup WebRTC callbacks for progress and state
  void _setupWebRTCCallbacks(String deviceId, WebRTCService webrtc) {
    webrtc.onProgress = (progress) {
      groupService.updateDeviceProgress(deviceId, progress);
    };

    webrtc.onDataChannelOpen = () {
      debugPrint('📡 Data channel open for device $deviceId');
      if (!_connectionCompleters[deviceId]!.isCompleted) {
        _connectionCompleters[deviceId]!.complete(true);
      }
    };
  }

  /// Setup signaling message handler
  void _setupSignalingHandler(
    String deviceId,
    DiscoveredDevice device,
    SignalingSocketService signaling,
    WebRTCService webrtcService,
  ) {
    signaling.onMessageReceived = (message) async {
      try {
        switch (message.type) {
          case SignalingMessageType.accept:
            debugPrint('✅ Device $deviceId accepted connection');
            await _handleAccept(deviceId, device, webrtcService, signaling);
            break;

          case SignalingMessageType.answer:
            debugPrint('📥 Received answer from $deviceId');
            final sdp = message.data['sdp'] as String;
            final answer = webrtc.RTCSessionDescription(sdp, 'answer');
            await webrtcService.setRemoteDescription(answer);
            break;

          case SignalingMessageType.iceCandidate:
            debugPrint('❄️ Received ICE candidate from $deviceId');
            final candidateData = message.data;
            final candidate = webrtc.RTCIceCandidate(
              candidateData['candidate'] as String?,
              candidateData['sdpMid'] as String?,
              candidateData['sdpMLineIndex'] as int?,
            );
            await webrtcService.addCandidate(candidate);
            break;

          case SignalingMessageType.decline:
            debugPrint('❌ Device $deviceId declined connection');
            if (!_connectionCompleters[deviceId]!.isCompleted) {
              _connectionCompleters[deviceId]!.complete(false);
            }
            break;

          default:
            break;
        }
      } catch (e) {
        debugPrint('⚠️ Error handling message for $deviceId: $e');
      }
    };
  }

  /// Send connection request to device
  Future<void> _sendConnectionRequest(
    DiscoveredDevice device,
    SignalingSocketService signaling,
  ) async {
    final message = SignalingMessage.connectRequest(
      sessionId: groupService.currentSession!.groupId,
      senderName: 'GroupSender',
      fileName: _files.first.name,
      fileSize: _files.first.size,
      files: _files.map((f) => {
        'name': f.name,
        'size': f.size,
      }).toList(),
    );

    await signaling.sendMessage(message);
    debugPrint('📤 Sent connection request to ${device.deviceName}');
  }

  /// Handle acceptance and create offer
  Future<void> _handleAccept(
    String deviceId,
    DiscoveredDevice device,
    WebRTCService webrtcService,
    SignalingSocketService signaling,
  ) async {
    // Create and send offer
    final offer = await webrtcService.createOffer();
    
    final offerMessage = SignalingMessage.offer(
      sessionId: groupService.currentSession!.groupId,
      sdp: offer.sdp!,
    );
    
    await signaling.sendMessage(offerMessage);
    debugPrint('📤 Sent offer to ${device.deviceName}');
  }

  /// Setup HTTP fallback for a device
  Future<void> _setupHttpFallback(String deviceId) async {
    debugPrint('🔄 Setting up HTTP fallback for device $deviceId');
    
    final member = groupService.getMember(deviceId);
    if (member != null) {
      member.useHttpFallback = true;
      groupService.updateDeviceState(
        deviceId,
        connectionState: group_models.ConnectionState.connected,
      );
    }
  }

  /// Broadcast file to all connected devices
  Future<void> _broadcastFile(PlatformFile file, int fileIndex) async {
    final fileData = file.bytes ?? await File(file.path!).readAsBytes();
    
    // Separate devices by connection type
    final webrtcDevices = <String>[];
    final httpDevices = <String>[];

    for (var entry in groupService.getMembers()) {
      if (entry.useHttpFallback) {
        httpDevices.add(entry.deviceId);
      } else if (_webrtcServices.containsKey(entry.deviceId)) {
        webrtcDevices.add(entry.deviceId);
      }
    }

    // Send via WebRTC
    final webrtcTasks = webrtcDevices.map((deviceId) async {
      try {
        final webrtc = _webrtcServices[deviceId]!;
        await webrtc.sendFile(fileData, file.name, file.size);
        debugPrint('✅ Sent ${file.name} to $deviceId via WebRTC');
      } catch (e) {
        debugPrint('❌ WebRTC send failed for $deviceId: $e');
        groupService.markDeviceAsFailed(deviceId, e.toString());
      }
    });

    // Send via HTTP
    if (httpDevices.isNotEmpty) {
      await httpCoordinator.startGroupServer([file]);
      
      final httpTasks = httpDevices.map((deviceId) async {
        try {
          final url = httpCoordinator.getDownloadUrl(file.name, deviceId);
          debugPrint('📤 HTTP URL for $deviceId: $url');
          
          // Notify device of URL via signaling
          final signaling = _signalingServices[deviceId];
          if (signaling != null) {
            await signaling.sendMessage(
              SignalingMessage.fallbackUpload(
                sessionId: groupService.currentSession!.groupId,
                downloadUrl: url,
                fileName: file.name,
                fileSize: file.size,
              ),
            );
          }
          
          // Wait for download complete
          await httpCoordinator.waitForDeviceDownload(deviceId);
          debugPrint('✅ Sent ${file.name} to $deviceId via HTTP');
          
        } catch (e) {
          debugPrint('❌ HTTP send failed for $deviceId: $e');
          groupService.markDeviceAsFailed(deviceId, e.toString());
        }
      });

      await Future.wait([...webrtcTasks, ...httpTasks]);
    } else {
      await Future.wait(webrtcTasks);
    }
  }

  /// Cleanup all connections
  void dispose() {
    for (var webrtc in _webrtcServices.values) {
      webrtc.close();
    }
    for (var signaling in _signalingServices.values) {
      signaling.close();
    }
    
    _webrtcServices.clear();
    _signalingServices.clear();
    _connectionCompleters.clear();
    
    httpCoordinator.stopServer();
  }
}
