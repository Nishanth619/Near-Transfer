import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background Transfer Service
/// Handles file transfers in the background using a foreground service
class BackgroundTransferService {
  static final BackgroundTransferService _instance = BackgroundTransferService._internal();
  factory BackgroundTransferService() => _instance;
  BackgroundTransferService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _isInitialized = false;

  // Transfer state
  bool _isTransferring = false;
  double _progress = 0.0;
  String? _currentFileName;
  String? _targetDeviceName;

  bool get isTransferring => _isTransferring;
  double get progress => _progress;
  String? get currentFileName => _currentFileName;

  /// Initialize the background service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: false,
        onStart: _onStart,
        isForegroundMode: true,
        autoStartOnBoot: false,
        notificationChannelId: 'near_transfer_bg',
        initialNotificationTitle: 'NearTransfer',
        initialNotificationContent: 'Ready to transfer files',
        foregroundServiceNotificationId: 888,
      ),
    );

    _isInitialized = true;
  }

  /// Start a background transfer
  Future<void> startTransfer({
    required String fileName,
    required String targetDeviceName,
    required String targetIp,
    required int targetPort,
    required String filePath,
    required int fileSize,
  }) async {
    await initialize();
    
    _isTransferring = true;
    _currentFileName = fileName;
    _targetDeviceName = targetDeviceName;
    _progress = 0.0;

    // Start the background service
    await _service.startService();

    // Send transfer info to background isolate
    _service.invoke('startTransfer', {
      'fileName': fileName,
      'targetDeviceName': targetDeviceName,
      'targetIp': targetIp,
      'targetPort': targetPort,
      'filePath': filePath,
      'fileSize': fileSize,
    });
  }

  /// Update progress from the background service
  void updateProgress(double progress, String? fileName) {
    _progress = progress;
    if (fileName != null) _currentFileName = fileName;
  }

  /// Stop the transfer and background service
  Future<void> stopTransfer() async {
    _isTransferring = false;
    _progress = 0.0;
    _currentFileName = null;
    _targetDeviceName = null;
    
    _service.invoke('stopTransfer');
    
    // Give time for cleanup
    await Future.delayed(const Duration(milliseconds: 500));
    
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stopService');
    }
  }

  /// Check if the background service is running
  Future<bool> isRunning() async {
    return await _service.isRunning();
  }

  /// Listen to updates from the background service
  Stream<Map<String, dynamic>?> get onUpdate => _service.on('update');
}

/// Entry point for the background service (runs in separate isolate)
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Notification plugin for updating progress
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Handle stop command
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Handle transfer start
  service.on('startTransfer').listen((event) async {
    if (event == null) return;

    final fileName = event['fileName'] as String;
    final targetDeviceName = event['targetDeviceName'] as String;
    final targetIp = event['targetIp'] as String;
    final targetPort = event['targetPort'] as int;
    final filePath = event['filePath'] as String;
    final fileSize = event['fileSize'] as int;

    // Update notification
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Sending to $targetDeviceName',
        content: 'Preparing $fileName...',
      );
    }

    try {
      // Perform the actual transfer
      await _performTransfer(
        service: service,
        fileName: fileName,
        targetDeviceName: targetDeviceName,
        targetIp: targetIp,
        targetPort: targetPort,
        filePath: filePath,
        fileSize: fileSize,
      );
    } catch (e) {
      // Send error to main isolate
      service.invoke('update', {
        'status': 'error',
        'error': e.toString(),
      });
    }
  });

  // Handle stop transfer
  service.on('stopTransfer').listen((event) {
    // Cancel current transfer if any
    service.invoke('update', {'status': 'cancelled'});
  });
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  return true;
}

/// Perform the actual file transfer in background
Future<void> _performTransfer({
  required ServiceInstance service,
  required String fileName,
  required String targetDeviceName,
  required String targetIp,
  required int targetPort,
  required String filePath,
  required int fileSize,
}) async {
  Socket? socket;
  
  try {
    // Connect to target device
    service.invoke('update', {
      'status': 'connecting',
      'fileName': fileName,
    });

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Connecting to $targetDeviceName',
        content: fileName,
      );
    }

    socket = await Socket.connect(targetIp, targetPort, timeout: const Duration(seconds: 10));

    // Read file
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final fileStream = file.openRead();
    int bytesSent = 0;
    
    // Send file data with progress updates
    await for (final chunk in fileStream) {
      socket.add(chunk);
      await socket.flush();
      
      bytesSent += chunk.length;
      final progress = (bytesSent / fileSize).clamp(0.0, 1.0);
      
      // Update progress
      service.invoke('update', {
        'status': 'transferring',
        'progress': progress,
        'bytesSent': bytesSent,
        'totalBytes': fileSize,
        'fileName': fileName,
      });

      // Update notification (every 5%)
      if ((progress * 100).toInt() % 5 == 0) {
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Sending to $targetDeviceName',
            content: '${(progress * 100).toInt()}% - $fileName',
          );
        }
      }
    }

    // Transfer complete
    service.invoke('update', {
      'status': 'completed',
      'fileName': fileName,
    });

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Transfer Complete',
        content: '$fileName sent successfully',
      );
    }

    // Keep notification for a bit then stop
    await Future.delayed(const Duration(seconds: 3));
    
  } catch (e) {
    service.invoke('update', {
      'status': 'error',
      'error': e.toString(),
      'fileName': fileName,
    });

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Transfer Failed',
        content: e.toString(),
      );
    }
  } finally {
    socket?.destroy();
  }
}
