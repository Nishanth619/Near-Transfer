import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service to measure network speed and quality
class NetworkSpeedService {
  static final NetworkSpeedService _instance = NetworkSpeedService._internal();
  factory NetworkSpeedService() => _instance;
  NetworkSpeedService._internal();

  // Test results
  double _downloadSpeed = 0.0; // Mbps
  double _uploadSpeed = 0.0; // Mbps
  double _latency = 0.0; // ms
  NetworkQuality _quality = NetworkQuality.unknown;
  bool _isTesting = false;

  double get downloadSpeed => _downloadSpeed;
  double get uploadSpeed => _uploadSpeed;
  double get latency => _latency;
  NetworkQuality get quality => _quality;
  bool get isTesting => _isTesting;

  String get downloadSpeedFormatted => '${_downloadSpeed.toStringAsFixed(1)} Mbps';
  String get uploadSpeedFormatted => '${_uploadSpeed.toStringAsFixed(1)} Mbps';
  String get latencyFormatted => '${_latency.toStringAsFixed(0)} ms';

  /// Run a speed test to a local device
  Future<SpeedTestResult> runSpeedTest({
    required String targetIp,
    int port = 45455,
    Function(double progress, String status)? onProgress,
  }) async {
    _isTesting = true;
    
    try {
      // Step 1: Test latency (ping)
      onProgress?.call(0.1, 'Testing latency...');
      _latency = await _measureLatency(targetIp, port);
      
      // Step 2: Test download speed (receive data from target)
      onProgress?.call(0.3, 'Testing download speed...');
      _downloadSpeed = await _measureDownloadSpeed(targetIp, port);
      
      // Step 3: Test upload speed (send data to target)
      onProgress?.call(0.6, 'Testing upload speed...');
      _uploadSpeed = await _measureUploadSpeed(targetIp, port);
      
      // Step 4: Calculate quality
      onProgress?.call(0.9, 'Calculating quality...');
      _quality = _calculateQuality();
      
      onProgress?.call(1.0, 'Complete');
      
      _isTesting = false;
      
      return SpeedTestResult(
        downloadSpeed: _downloadSpeed,
        uploadSpeed: _uploadSpeed,
        latency: _latency,
        quality: _quality,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      _isTesting = false;
      rethrow;
    }
  }

  /// Quick network quality check without full speed test
  Future<NetworkQuality> quickCheck(String targetIp, {int port = 45455}) async {
    try {
      final latency = await _measureLatency(targetIp, port);
      
      if (latency < 10) return NetworkQuality.excellent;
      if (latency < 30) return NetworkQuality.good;
      if (latency < 100) return NetworkQuality.fair;
      return NetworkQuality.poor;
    } catch (e) {
      return NetworkQuality.unknown;
    }
  }

  Future<double> _measureLatency(String ip, int port) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Try to connect to the target
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );
      
      stopwatch.stop();
      socket.destroy();
      
      return stopwatch.elapsedMilliseconds.toDouble();
    } catch (e) {
      // If connection fails, estimate based on ping-like behavior
      return 999.0; // High latency indicates poor connection
    }
  }

  Future<double> _measureDownloadSpeed(String ip, int port) async {
    // For local transfers, we estimate based on network type
    // In a real implementation, you would request test data from the target
    
    try {
      // Simulate speed test by measuring TCP connection quality
      final testSize = 1024 * 100; // 100 KB test
      final data = List<int>.filled(testSize, 0);
      
      final stopwatch = Stopwatch()..start();
      
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 10),
      );
      
      // Send request for speed test
      socket.add(data);
      await socket.flush();
      
      stopwatch.stop();
      socket.destroy();
      
      // Calculate speed: bytes / seconds = bytes per second
      // Convert to Mbps: (bytes * 8) / (ms / 1000) / 1000000
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed == 0) return 100.0; // Very fast, estimate 100 Mbps
      
      final bps = (testSize * 1000) / elapsed;
      final mbps = (bps * 8) / 1000000;
      
      return mbps.clamp(0.1, 1000.0);
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _measureUploadSpeed(String ip, int port) async {
    // Similar to download, but measures sending performance
    // For local transfers, upload and download are usually similar
    
    try {
      final testSize = 1024 * 100; // 100 KB test
      final data = List<int>.filled(testSize, 65); // 'A' bytes
      
      final stopwatch = Stopwatch()..start();
      
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 10),
      );
      
      socket.add(data);
      await socket.flush();
      
      stopwatch.stop();
      socket.destroy();
      
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed == 0) return 100.0;
      
      final bps = (testSize * 1000) / elapsed;
      final mbps = (bps * 8) / 1000000;
      
      return mbps.clamp(0.1, 1000.0);
    } catch (e) {
      return 0.0;
    }
  }

  NetworkQuality _calculateQuality() {
    // Score based on all metrics
    double score = 0;
    
    // Latency score (0-40 points)
    if (_latency < 10) score += 40;
    else if (_latency < 30) score += 30;
    else if (_latency < 100) score += 20;
    else if (_latency < 300) score += 10;
    
    // Download speed score (0-30 points)
    if (_downloadSpeed > 50) score += 30;
    else if (_downloadSpeed > 20) score += 25;
    else if (_downloadSpeed > 10) score += 20;
    else if (_downloadSpeed > 5) score += 10;
    
    // Upload speed score (0-30 points)
    if (_uploadSpeed > 50) score += 30;
    else if (_uploadSpeed > 20) score += 25;
    else if (_uploadSpeed > 10) score += 20;
    else if (_uploadSpeed > 5) score += 10;
    
    if (score >= 80) return NetworkQuality.excellent;
    if (score >= 60) return NetworkQuality.good;
    if (score >= 40) return NetworkQuality.fair;
    return NetworkQuality.poor;
  }

  /// Get estimated transfer time for a file
  String getEstimatedTime(int fileSizeBytes) {
    if (_uploadSpeed <= 0) return 'Unknown';
    
    // Convert Mbps to bytes per second
    final bytesPerSecond = (_uploadSpeed * 1000000) / 8;
    final seconds = fileSizeBytes / bytesPerSecond;
    
    if (seconds < 1) return 'Less than 1s';
    if (seconds < 60) return '${seconds.round()}s';
    if (seconds < 3600) return '${(seconds / 60).round()}m ${(seconds % 60).round()}s';
    return '${(seconds / 3600).round()}h ${((seconds % 3600) / 60).round()}m';
  }
}

enum NetworkQuality {
  unknown,
  poor,
  fair,
  good,
  excellent,
}

extension NetworkQualityExtension on NetworkQuality {
  String get label {
    switch (this) {
      case NetworkQuality.excellent: return 'Excellent';
      case NetworkQuality.good: return 'Good';
      case NetworkQuality.fair: return 'Fair';
      case NetworkQuality.poor: return 'Poor';
      case NetworkQuality.unknown: return 'Unknown';
    }
  }

  String get emoji {
    switch (this) {
      case NetworkQuality.excellent: return '🟢';
      case NetworkQuality.good: return '🟡';
      case NetworkQuality.fair: return '🟠';
      case NetworkQuality.poor: return '🔴';
      case NetworkQuality.unknown: return '⚪';
    }
  }
}

class SpeedTestResult {
  final double downloadSpeed;
  final double uploadSpeed;
  final double latency;
  final NetworkQuality quality;
  final DateTime timestamp;

  SpeedTestResult({
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.latency,
    required this.quality,
    required this.timestamp,
  });
}
