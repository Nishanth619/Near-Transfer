import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utility functions for transfer resume functionality
class TransferResumeUtils {
  /// Generate a unique transfer ID
  static String generateTransferId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'tx_$timestamp';
  }

  /// Generate a batch ID for multi-file transfers
  static String generateBatchId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'batch_$timestamp';
  }

  /// Calculate SHA256 hash of a file (for verification)
  /// Returns null if file doesn't exist or error occurs
  static Future<String?> calculateFileHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('⚠️ File not found for hash calculation: $filePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('❌ Error calculating file hash: $e');
      return null;
    }
  }

  /// Calculate SHA256 hash of file in chunks (for large files)
  /// More memory-efficient for large files
  static Future<String?> calculateFileHashChunked(
    String filePath, {
    int chunkSize = 1024 * 1024, // 1 MB chunks
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('⚠️ File not found for hash calculation: $filePath');
        return null;
      }

      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString();
    } catch (e) {
      print('❌ Error calculating file hash: $e');
      return null;
    }
  }

  /// Verify if a file hash matches the expected hash
  static Future<bool> verifyFileHash(String filePath, String expectedHash) async {
    final actualHash = await calculateFileHashChunked(filePath);
    if (actualHash == null) return false;
    final matches = actualHash == expectedHash;
    if (!matches) {
      print('⚠️ Hash mismatch! Expected: $expectedHash, Got: $actualHash');
    }
    return matches;
  }

  /// Format bytes to human-readable size
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format duration to human-readable time
  static String formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    }
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }

  /// Calculate estimated time remaining
  static Duration? estimateTimeRemaining({
    required int bytesTransferred,
    required int totalBytes,
    required Duration elapsedTime,
  }) {
    if (bytesTransferred == 0 || elapsedTime.inSeconds == 0) {
      return null;
    }

    final bytesPerSecond = bytesTransferred / elapsedTime.inSeconds;
    final remainingBytes = totalBytes - bytesTransferred;
    final secondsRemaining = (remainingBytes / bytesPerSecond).ceil();

    return Duration(seconds: secondsRemaining);
  }

  /// Calculate transfer speed in bytes/second
  static double calculateSpeed({
    required int bytesTransferred,
    required Duration elapsedTime,
  }) {
    if (elapsedTime.inSeconds == 0) return 0.0;
    return bytesTransferred / elapsedTime.inSeconds;
  }

  /// Format speed to human-readable format
  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    }
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// Check if transfer can be resumed based on time elapsed
  static bool canResumeAfterTime(DateTime lastUpdated, {int maxDays = 7}) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);
    return difference.inDays < maxDays;
  }

  /// Check if partial file exists and is valid
  static Future<bool> isPartialFileValid({
    required String filePath,
    required int expectedSize,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final actualSize = await file.length();
      // Partial file should be less than or equal to expected size
      return actualSize <= expectedSize && actualSize > 0;
    } catch (e) {
      print('❌ Error checking partial file: $e');
      return false;
    }
  }
}
