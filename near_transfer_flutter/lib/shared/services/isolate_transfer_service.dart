import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Multi-threaded file transfer using Isolates
/// This offloads heavy file operations to a separate thread
class IsolateTransferService {
  static final IsolateTransferService _instance = IsolateTransferService._internal();
  factory IsolateTransferService() => _instance;
  IsolateTransferService._internal();

  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;
  bool _isInitialized = false;

  // Callbacks
  Function(double progress, int bytesSent)? onProgress;
  Function(String message)? onError;
  Function()? onComplete;

  /// Initialize the transfer isolate
  Future<void> initialize() async {
    if (_isInitialized) return;

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _receivePort!.sendPort,
    );

    // Wait for SendPort from isolate
    final completer = Completer<SendPort>();
    _receivePort!.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        completer.complete(message);
      } else if (message is Map<String, dynamic>) {
        _handleMessage(message);
      }
    });

    await completer.future;
    _isInitialized = true;
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String;

    switch (type) {
      case 'progress':
        onProgress?.call(
          message['progress'] as double,
          message['bytesSent'] as int,
        );
        break;
      case 'error':
        onError?.call(message['error'] as String);
        break;
      case 'complete':
        onComplete?.call();
        break;
    }
  }

  /// Send a file using the isolate
  Future<void> sendFile({
    required String filePath,
    required String targetIp,
    required int targetPort,
    required int fileSize,
  }) async {
    await initialize();

    _sendPort?.send({
      'action': 'send',
      'filePath': filePath,
      'targetIp': targetIp,
      'targetPort': targetPort,
      'fileSize': fileSize,
    });
  }

  /// Receive a file using the isolate
  Future<void> receiveFile({
    required String savePath,
    required int expectedSize,
    required Socket socket,
  }) async {
    // For receiving, we use compute for heavy operations
    // Socket handling stays on main thread but file writing is offloaded
  }

  /// Cancel current transfer
  void cancelTransfer() {
    _sendPort?.send({'action': 'cancel'});
  }

  /// Dispose the isolate
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    _isolate = null;
    _receivePort = null;
    _sendPort = null;
    _isInitialized = false;
  }
}

/// Isolate entry point - runs on a separate thread
@pragma('vm:entry-point')
void _isolateEntryPoint(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  bool isCancelled = false;
  Socket? currentSocket;

  receivePort.listen((message) async {
    if (message is! Map<String, dynamic>) return;

    final action = message['action'] as String;

    if (action == 'cancel') {
      isCancelled = true;
      currentSocket?.destroy();
      return;
    }

    if (action == 'send') {
      isCancelled = false;
      
      final filePath = message['filePath'] as String;
      final targetIp = message['targetIp'] as String;
      final targetPort = message['targetPort'] as int;
      final fileSize = message['fileSize'] as int;

      try {
        // Connect to target
        currentSocket = await Socket.connect(
          targetIp,
          targetPort,
          timeout: const Duration(seconds: 15),
        );

        // Read and send file
        final file = File(filePath);
        final fileStream = file.openRead();
        int bytesSent = 0;

        await for (final chunk in fileStream) {
          if (isCancelled) {
            mainSendPort.send({
              'type': 'error',
              'error': 'Transfer cancelled',
            });
            break;
          }

          currentSocket!.add(chunk);
          await currentSocket!.flush();

          bytesSent += chunk.length;
          final progress = (bytesSent / fileSize).clamp(0.0, 1.0);

          mainSendPort.send({
            'type': 'progress',
            'progress': progress,
            'bytesSent': bytesSent,
          });
        }

        if (!isCancelled) {
          mainSendPort.send({'type': 'complete'});
        }

      } catch (e) {
        mainSendPort.send({
          'type': 'error',
          'error': e.toString(),
        });
      } finally {
        currentSocket?.destroy();
        currentSocket = null;
      }
    }
  });
}

/// Utility for offloading heavy file operations to compute
class FileOperationHelper {
  /// Read file bytes in chunks (for large files)
  static Future<Uint8List> readFileAsync(String path) async {
    return await compute(_readFileBytes, path);
  }

  /// Write file bytes asynchronously
  static Future<void> writeFileAsync(String path, Uint8List bytes) async {
    await compute(_writeFileBytes, {'path': path, 'bytes': bytes});
  }

  /// Calculate file checksum for verification
  static Future<String> calculateChecksumAsync(String path) async {
    return await compute(_calculateChecksum, path);
  }

  /// Compress file data
  static Future<Uint8List> compressAsync(Uint8List data) async {
    return await compute(_compressData, data);
  }

  /// Decompress file data
  static Future<Uint8List> decompressAsync(Uint8List data) async {
    return await compute(_decompressData, data);
  }
}

// Compute function implementations (run in isolate)
Uint8List _readFileBytes(String path) {
  return File(path).readAsBytesSync();
}

void _writeFileBytes(Map<String, dynamic> params) {
  final path = params['path'] as String;
  final bytes = params['bytes'] as Uint8List;
  File(path).writeAsBytesSync(bytes);
}

String _calculateChecksum(String path) {
  final bytes = File(path).readAsBytesSync();
  // Simple checksum calculation
  int sum = 0;
  for (final byte in bytes) {
    sum = (sum + byte) & 0xFFFFFFFF;
  }
  return sum.toRadixString(16);
}

Uint8List _compressData(Uint8List data) {
  // Use ZLib compression
  return Uint8List.fromList(ZLibCodec().encode(data));
}

Uint8List _decompressData(Uint8List data) {
  return Uint8List.fromList(ZLibCodec().decode(data));
}
