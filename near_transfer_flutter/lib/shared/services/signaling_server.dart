import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class SignalingServer {
  HttpServer? _server;
  String? _serverUrl;
  
  final Completer<Map<String, dynamic>> _answerCompleter = Completer();
  Map<String, dynamic>? _offerData;
  
  // HTTP fallback support
  List<PlatformFile>? _filesToServe;
  final Map<String, Completer<bool>> _transferCompleters = {};
  final Map<String, Function(double)> _progressCallbacks = {};

  Future<String> startServer(Map<String, dynamic> offerData, {List<PlatformFile>? files}) async {
    _offerData = offerData;
    _filesToServe = files;
    
    // Get local IP
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    
    String? localIp;
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        // Skip loopback
        if (addr.isLoopback) continue;
        
        // Accept common private IP ranges
        if (addr.address.startsWith('192.168.') ||  // Standard WiFi
            addr.address.startsWith('10.') ||        // Some WiFi/VPN
            addr.address.startsWith('172.')) {       // Some WiFi
          localIp = addr.address;
          break;
        }
      }
      if (localIp != null) break;
    }

    if (localIp == null) {
      throw Exception('No WiFi connection found. Please connect both devices to the same WiFi network or create a mobile hotspot.');
    }

    // Close existing server if any
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }

    // Start server with shared flag to allow port reuse
    _server = await HttpServer.bind(
      localIp, 
      8765,
      shared: true,
    );
    _serverUrl = 'http://$localIp:8765';
    
    
    // Handle requests
    _server!.listen((HttpRequest request) async {
      // Enable CORS
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');
      
      if (request.method == 'OPTIONS') {
        request.response.close();
        return;
      }
      
      if (request.uri.path == '/offer' && request.method == 'GET') {
        // Send offer to receiver
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(_offerData))
          ..close();
          
      } else if (request.uri.path == '/answer' && request.method == 'POST') {
        // Receive answer from receiver
        final body = await utf8.decoder.bind(request).join();
        final answerData = jsonDecode(body);
        
        if (!_answerCompleter.isCompleted) {
          _answerCompleter.complete(answerData);
        }
        
        request.response
          ..statusCode = 200
          ..write('OK')
          ..close();
          
      } else if (request.uri.path == '/files' && request.method == 'GET') {
        // HTTP Fallback: Send file list
        if (_filesToServe == null || _filesToServe!.isEmpty) {
          request.response
            ..statusCode = 404
            ..write('No files available')
            ..close();
          return;
        }
        
        final fileList = _filesToServe!.map((f) => {
          'name': f.name,
          'size': f.size,
        }).toList();
        
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'files': fileList}))
          ..close();
          
      } else if (request.uri.path.startsWith('/file/') && request.method == 'GET') {
        // HTTP Fallback: Send individual file
        final fileName = Uri.decodeComponent(request.uri.path.substring(6));
        final file = _filesToServe?.firstWhere(
          (f) => f.name == fileName,
          orElse: () => throw Exception('File not found'),
        );
        
        if (file == null) {
          request.response
            ..statusCode = 404
            ..write('File not found')
            ..close();
          return;
        }
        
        // Check if file has either bytes or path
        if (file.bytes == null && file.path == null) {
          request.response
            ..statusCode = 404
            ..write('File data not available')
            ..close();
          return;
        }
        
        // Create completer for this file if not exists
        if (!_transferCompleters.containsKey(fileName)) {
          _transferCompleters[fileName] = Completer<bool>();
        }

        try {
          // Handle virtual files (with bytes) vs real files (with path)
          if (file.bytes != null) {
            // Virtual file - send bytes directly
            request.response
              ..headers.contentType = ContentType.binary
              ..headers.add('Content-Disposition', 'attachment; filename="${file.name}"')
              ..headers.contentLength = file.bytes!.length;
            
            request.response.add(file.bytes!);
            await request.response.close();
            
            
            // Mark as complete
            if (!_transferCompleters[fileName]!.isCompleted) {
              _transferCompleters[fileName]!.complete(true);
            }
          } else {
            // Real file - stream from path
            final fileHandle = File(file.path!);
            final fileSize = await fileHandle.length();
            
            request.response
              ..headers.contentType = ContentType.binary
              ..headers.add('Content-Disposition', 'attachment; filename="${file.name}"')
              ..headers.contentLength = fileSize;
            
            // Stream file in chunks to avoid loading entire file into memory
            final fileStream = fileHandle.openRead();
            int sentBytes = 0;
            
            await for (var chunk in fileStream) {
              request.response.add(chunk);
              sentBytes += chunk.length;
              
              // Report progress
              if (_progressCallbacks.containsKey(fileName)) {
                final progress = sentBytes / fileSize;
                _progressCallbacks[fileName]?.call(progress);
              }
            }
              
            await request.response.close();
            await request.response.done;
            
            
            // Mark as complete
            if (!_transferCompleters[fileName]!.isCompleted) {
              _transferCompleters[fileName]!.complete(true);
            }
          }
        } catch (e) {
          request.response
            ..statusCode = 500
            ..write('Error reading file: $e')
            ..close();
            
          if (!_transferCompleters[fileName]!.isCompleted) {
            _transferCompleters[fileName]!.complete(false);
          }
        }
      }
    });
    
    return _serverUrl!;
  }

  Future<Map<String, dynamic>> waitForAnswer() async {
    return await _answerCompleter.future;
  }
  
  Future<bool> waitForTransfer(String fileName) async {
    if (!_transferCompleters.containsKey(fileName)) {
      _transferCompleters[fileName] = Completer<bool>();
    }
    return await _transferCompleters[fileName]!.future;
  }
  
  void setProgressCallback(String fileName, Function(double) callback) {
    _progressCallbacks[fileName] = callback;
  }

  void close() {
    _server?.close();
  }
}
