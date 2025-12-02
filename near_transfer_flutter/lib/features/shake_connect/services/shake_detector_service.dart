import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/services.dart';

/// Service to detect phone shake gestures
class ShakeDetectorService {
  static final ShakeDetectorService _instance = ShakeDetectorService._internal();
  factory ShakeDetectorService() => _instance;
  ShakeDetectorService._internal();

  // Shake detection parameters
  static const double _shakeThreshold = 15.0; // m/s²
  static const int _shakeCooldown = 500; // milliseconds
  
  StreamSubscription<AccelerometerEvent>? _subscription;
  DateTime? _lastShakeTime;
  bool _isListening = false;
  
  // Callbacks
  Function()? onShakeDetected;
  Function(double intensity)? onShakeIntensity;

  /// Start listening for shake gestures
  void startListening() {
    if (_isListening) return;
    
    _isListening = true;
    _subscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      _checkForShake(event);
    });
  }

  /// Stop listening for shake gestures
  void stopListening() {
    _isListening = false;
    _subscription?.cancel();
    _subscription = null;
    _lastShakeTime = null;
  }

  /// Check if accelerometer data indicates a shake
  void _checkForShake(AccelerometerEvent event) {
    // Calculate total acceleration (magnitude of vector)
    final double acceleration = sqrt(
      event.x * event.x + 
      event.y * event.y + 
      event.z * event.z
    );

    // Check if acceleration exceeds threshold
    if (acceleration > _shakeThreshold) {
      final now = DateTime.now();
      
      // Check cooldown to avoid multiple triggers
      if (_lastShakeTime == null || 
          now.difference(_lastShakeTime!).inMilliseconds > _shakeCooldown) {
        _lastShakeTime = now;
        
        // Trigger callbacks
        onShakeDetected?.call();
        onShakeIntensity?.call(acceleration);
        
        // Haptic feedback
        _triggerHaptic();
      }
    }
  }

  /// Trigger haptic feedback
  void _triggerHaptic() {
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Haptic not supported on this device
    }
  }

  /// Get shake timestamp for matching
  int getShakeTimestamp() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  /// Check if two shake timestamps are within matching window (3 seconds)
  bool isShakeMatch(int timestamp1, int timestamp2) {
    const int matchWindow = 3000; // 3 seconds
    return (timestamp1 - timestamp2).abs() < matchWindow;
  }

  /// Dispose resources
  void dispose() {
    stopListening();
  }

  bool get isListening => _isListening;
}
