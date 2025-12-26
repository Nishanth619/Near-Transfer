import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  // Settings keys
  static const String _notificationsEnabledKey = 'show_notifications';
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _vibrationEnabledKey = 'vibration_enabled';

  // Platform channel for vibration
  static const MethodChannel _vibrationChannel = MethodChannel('near_transfer/vibration');

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    
    // Request notification permission (Android 13+)
    await _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  // Get settings from SharedPreferences
  Future<bool> _isNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  Future<bool> _isSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundEnabledKey) ?? true;
  }

  Future<bool> _isVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vibrationEnabledKey) ?? true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    // Check if notifications are enabled
    if (!await _isNotificationsEnabled()) {
      return;
    }

    // Check sound and vibration settings
    final enableSound = await _isSoundEnabled();
    final enableVibration = await _isVibrationEnabled();

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'near_transfer_channel',
      'Near Transfer Notifications',
      channelDescription: 'Notifications for file transfers',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: enableSound,
      enableVibration: enableVibration,
      // Use default sound if sound enabled
      sound: enableSound ? const RawResourceAndroidNotificationSound('notification') : null,
      // Vibration pattern: wait 0ms, vibrate 250ms, wait 250ms, vibrate 250ms
      vibrationPattern: enableVibration ? Int64List.fromList([0, 250, 250, 250]) : null,
    );
    
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  /// Show transfer complete notification with sound and vibration
  Future<void> showTransferCompleteNotification({
    required String title,
    required String body,
  }) async {
    // Show notification
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
    );

    // Also trigger device vibration separately if enabled
    if (await _isVibrationEnabled()) {
      await _vibrate();
    }
  }

  Future<void> _vibrate() async {
    try {
      // Try multiple vibration methods
      // Method 1: HapticFeedback
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Fallback: try medium impact
      try {
        await HapticFeedback.mediumImpact();
      } catch (e2) {
        // Ignore if vibration not supported
      }
    }
  }

  /// Show progress notification for ongoing transfer
  Future<void> showProgressNotification({
    required int id,
    required String title,
    required int progress,
    required int maxProgress,
  }) async {
    if (!await _isNotificationsEnabled()) {
      return;
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'near_transfer_progress_channel',
      'Transfer Progress',
      channelDescription: 'Shows file transfer progress',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
    );
    
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      '${(progress / maxProgress * 100).toInt()}% complete',
      platformChannelSpecifics,
    );
  }

  /// Cancel a notification
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Test notification - useful for debugging
  Future<void> testNotification() async {
    await showTransferCompleteNotification(
      title: 'Test Notification',
      body: 'Notification and vibration are working!',
    );
  }
}
