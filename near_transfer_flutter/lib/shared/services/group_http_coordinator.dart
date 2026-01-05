import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class GroupHttpCoordinator {
  HttpServer? _server;
  List<PlatformFile>? _filesToServe;
  
  // Track downloads per device
  final Map<String, double> _deviceProgress = {};
  final Map<String, StreamController<double>> _progressControllers = {};
  final Map<String, Completer<bool>> _downloadCompleters = {};
  
  String? _serverUrl;
  
  /// Start HTTP server for group transfers
  Future<String> startGroupServer(List<PlatformFile> files) async {
    _filesToServe = files;
    
    // Get local IP
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    
    String? localIp;
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (addr.isLoopback) continue;
        
        if (addr.address.startsWith('192.168.') ||
            addr.address.startsWith('10.') ||
            addr.address.startsWith('172.')) {
          localIp = addr.address;
          break;
        }
      }
      if (localIp != null) break;
    }
    
    if (localIp == null) {
      throw Exception('Could not determine local IP');
    }
    
    // Start HTTP server
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
    _serverUrl = 'http://$localIp:8080';
    
    
    // Handle requests
    _server!.listen(_handleRequest);
    
    return _serverUrl!;
  }
  
  void _handleRequest(HttpRequest request) async {
    
    try {
      // Parse device ID from headers or query params
      final deviceId = request.uri.queryParameters['deviceId'] ?? 
                      request.headers.value('X-Device-ID') ?? 
                      'unknown';
      
      if (request.uri.path == '/health') {
        // Health check
        request.response
          ..statusCode = 200
          ..write('OK')
          ..close();
        return;
      }
      
      if (request.uri.path.startsWith('/download/')) {
        // Extract file name
        final fileName = Uri.decodeComponent(
          request.uri.path.replaceFirst('/download/', '')
        );
        
        await _serveFile(request, fileName, deviceId);
      } else {
        request.response
          ..statusCode = 404
          ..write('Not Found')
          ..close();
      }
    } catch (e) {
      request.response
        ..statusCode = 500
        ..write('Internal Server Error')
        ..close();
    }
  }
  
  Future<void> _serveFile(
    HttpRequest request,
    String fileName,
    String deviceId,
  ) async {
    final file = _filesToServe?.firstWhere(
      (f) => f.name == fileName,
      orElse: () => throw Exception('File not found: $fileName'),
    );
    
    if (file == null) {
      request.response
        ..statusCode = 404
        ..write('File not found')
        ..close();
      return;
    }
    
    
    // Create completer for this download if not exists
    _downloadCompleters[deviceId] ??= Completer<bool>();
    _progressControllers[deviceId] ??= StreamController<double>.broadcast();
    
    try {
      // Get file size without loading into memory
      final int totalSize;
      final bool useStream;
      
      if (file.bytes != null) {
        totalSize = file.bytes!.length;
        useStream = false;
      } else if (file.path != null) {
        totalSize = await File(file.path!).length();
        useStream = true;
      } else {
        throw Exception('File has no bytes or path');
      }
      
      request.response
        ..headers.contentType = ContentType.binary
        ..headers.contentLength = totalSize
        ..headers.set('Accept-Ranges', 'bytes')
        ..headers.set('X-File-Name', fileName);
      
      // Stream file data with progress tracking
      int sentBytes = 0;
      
      if (useStream && file.path != null) {
        // STREAM FROM DISK - handles large files
        final fileStream = File(file.path!).openRead();
        
        await for (final chunk in fileStream) {
          request.response.add(chunk);
          sentBytes += chunk.length;
          
          // Update progress
          final progress = sentBytes / totalSize;
          _deviceProgress[deviceId] = progress;
          _progressControllers[deviceId]?.add(progress);
        }
      } else if (file.bytes != null) {
        // SMALL FILE IN MEMORY
        const chunkSize = 65536; // 64KB chunks
        final fileData = file.bytes!;
        
        for (int i = 0; i < totalSize; i += chunkSize) {
          final end = (i + chunkSize < totalSize) ? i + chunkSize : totalSize;
          final chunk = fileData.sublist(i, end);
          
          request.response.add(chunk);
          sentBytes += chunk.length;
          
          // Update progress
          final progress = sentBytes / totalSize;
          _deviceProgress[deviceId] = progress;
          _progressControllers[deviceId]?.add(progress);
          
          // Yield to event loop
          await Future.delayed(Duration.zero);
        }
      }
      
      await request.response.close();
      
      
      // Mark as complete
      _deviceProgress[deviceId] = 1.0;
      _progressControllers[deviceId]?.add(1.0);
      
      if (!_downloadCompleters[deviceId]!.isCompleted) {
        _downloadCompleters[deviceId]!.complete(true);
      }
      
    } catch (e) {
      
      if (!_downloadCompleters[deviceId]!.isCompleted) {
        _downloadCompleters[deviceId]!.completeError(e);
      }
      
      rethrow;
    }
  }
  
  /// Get download URL for a file
  String getDownloadUrl(String fileName, String deviceId) {
    if (_serverUrl == null) {
      throw StateError('Server not started');
    }
    
    final encodedFileName = Uri.encodeComponent(fileName);
    return '$_serverUrl/download/$encodedFileName?deviceId=$deviceId';
  }
  
  /// Get progress stream for a device
  Stream<double> getDeviceProgress(String deviceId) {
    _progressControllers[deviceId] ??= StreamController<double>.broadcast();
    return _progressControllers[deviceId]!.stream;
  }
  
  /// Get current progress for a device
  double getCurrentProgress(String deviceId) {
    return _deviceProgress[deviceId] ?? 0.0;
  }
  
  /// Wait for device download to complete
  Future<bool> waitForDeviceDownload(String deviceId) async {
    _downloadCompleters[deviceId] ??= Completer<bool>();
    return _downloadCompleters[deviceId]!.future;
  }
  
  /// Stop the HTTP server
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      _serverUrl = null;
      
      // Close all progress controllers
      for (var controller in _progressControllers.values) {
        await controller.close();
      }
      
      _progressControllers.clear();
      _downloadCompleters.clear();
      _deviceProgress.clear();
      
    }
  }
  
  /// Get transfer statistics
  Map<String, dynamic> getStats() {
    return {
      'totalDevices': _deviceProgress.length,
      'averageProgress': _deviceProgress.values.isEmpty 
          ? 0.0 
          : _deviceProgress.values.reduce((a, b) => a + b) / _deviceProgress.length,
      'completedDevices': _deviceProgress.values.where((p) => p >= 1.0).length,
    };
  }
}
