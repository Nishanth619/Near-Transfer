import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/network_config.dart';

/// Direct TCP socket transfer service for fast local file transfers.
/// Works like Xender/SHAREit - direct connection without WebRTC overhead.
class TcpTransferService {
  ServerSocket? _server;
  Socket? _socket;
  bool _isServer = false;
  bool _isCancelled = false;
  bool _isPaused = false;
  
  bool get isPaused => _isPaused;
  
  // Callbacks
  Function(double)? onProgress;
  Function(String filePath)? onFileReceived;
  Function(String fileName, int fileSize)? onFileStart;
  Function()? onBatchComplete;
  Function()? onConnected;
  Function(String error)? onError;
  
  // Transfer state
  int _currentFileIndex = 0;
  int _totalFiles = 0;
  
  bool get isConnected => _socket != null;
  
  /// Start TCP server (receiver side)
  Future<int> startServer() async {
    _isServer = true;
    _isCancelled = false;
    _isPaused = false;
    
    try {
      // Bind to any available port
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        NetworkConfig.tcpTransferPort,
        shared: true,
      );
      
      
      // Wait for connection
      _server!.listen((socket) {
        _socket = socket;
        
        // Optimize socket for bulk data transfer
        _socket!.setOption(SocketOption.tcpNoDelay, true);  // Disable Nagle algorithm
        
        onConnected?.call();
        _receiveFiles();
      });
      
      return _server!.port;
    } catch (e) {
      onError?.call('Failed to start server: $e');
      rethrow;
    }
  }
  
  /// Connect to receiver's TCP server (sender side)
  Future<bool> connect(String ip, int port) async {
    _isServer = false;
    _isCancelled = false;
    _isPaused = false;
    
    try {
      
      _socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );
      
      
      // Optimize socket for bulk data transfer
      _socket!.setOption(SocketOption.tcpNoDelay, true);  // Disable Nagle algorithm
      
      onConnected?.call();
      return true;
    } catch (e) {
      onError?.call('Connection failed: $e');
      return false;
    }
  }
  
  /// Send files over TCP (sender side)
  Future<void> sendFiles(List<PlatformFile> files) async {
    if (_socket == null) {
      throw Exception('Not connected');
    }
    
    _totalFiles = files.length;
    
    // Set up ACK listener
    Completer<String>? ackCompleter;
    
    _socket!.listen((data) {
      try {
        final message = utf8.decode(data);
        final lines = message.split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          final json = jsonDecode(line.trim());
          final type = json['type'] as String?;
          if (type == 'file_ack' || type == 'batch_ack') {
            if (ackCompleter != null && !ackCompleter!.isCompleted) {
              ackCompleter!.complete(type);
            }
          }
        }
      } catch (e) {
        // Not JSON, ignore
      }
    }, onError: (e) {
      if (ackCompleter != null && !ackCompleter!.isCompleted) {
        ackCompleter!.completeError(e);
      }
    });
    
    try {
      for (int i = 0; i < files.length; i++) {
        if (_isCancelled) {
          break;
        }
        
        final file = files[i];
        _currentFileIndex = i;
        
        // Create completer for this file's ACK
        ackCompleter = Completer<String>();
        
        await _sendFile(file, i, files.length);
        
        // Wait for ACK with timeout
        try {
          await ackCompleter!.future.timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return 'timeout';
            },
          );
        } catch (e) {
        }
      }
      
      if (!_isCancelled) {
        // Send batch complete signal
        final completeMsg = jsonEncode({
          'type': 'batch_complete',
        });
        _socket!.write('$completeMsg\n');
        await _socket!.flush();
        
        // Wait a bit for the receiver to process everything
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      onError?.call('Transfer failed: $e');
      rethrow;
    }
  }
  
  Future<void> _sendFile(PlatformFile file, int index, int total) async {
    
    // Get file size without loading into memory
    final int fileSize;
    final bool useStream;
    
    if (file.bytes != null) {
      // Small file already in memory (from file picker with bytes)
      fileSize = file.bytes!.length;
      useStream = false;
    } else if (file.path != null) {
      // Large file - get size and use streaming
      final fileObj = File(file.path!);
      fileSize = await fileObj.length();
      useStream = true;
    } else {
      throw Exception('File has no data');
    }
    
    // Send metadata header
    final metadata = jsonEncode({
      'type': 'file_start',
      'name': file.name,
      'size': fileSize,
      'index': index,
      'total': total,
    });
    _socket!.write('$metadata\n');
    await _socket!.flush();
    
    // Notify sender UI about file start (for progress tracking)
    onFileStart?.call(file.name, fileSize);
    
    // Stream file data in chunks - 256KB chunks
    const chunkSize = 262144; // 256KB
    int bytesSent = 0;
    
    if (useStream && file.path != null) {
      // STREAM FROM DISK - direct pipe without buffering
      final fileStream = File(file.path!).openRead();
      
      await for (final chunk in fileStream) {
        if (_isCancelled) break;
        
        // Wait while paused
        while (_isPaused && !_isCancelled) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (_isCancelled) break;
        
        // Send chunk directly - no buffering overhead!
        _socket!.add(chunk);
        bytesSent += chunk.length;
        
        // Report progress
        final progress = bytesSent / fileSize;
        onProgress?.call(progress);
        
        // Flush periodically for large files (every ~8MB for better throughput)
        if (bytesSent % 8388608 < chunk.length) {
          await _socket!.flush();
        }
      }
    } else if (file.bytes != null) {
      // SMALL FILE IN MEMORY - original approach for small files
      final fileData = file.bytes!;
      for (int i = 0; i < fileData.length; i += chunkSize) {
        if (_isCancelled) break;
        
        // Wait while paused
        while (_isPaused && !_isCancelled) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (_isCancelled) break;
        
        final end = (i + chunkSize < fileData.length) ? i + chunkSize : fileData.length;
        final chunk = fileData.sublist(i, end);
        
        _socket!.add(chunk);
        bytesSent += chunk.length;
        
        final progress = bytesSent / fileData.length;
        onProgress?.call(progress);
        
        if (bytesSent % (chunkSize * 10) == 0) {
          await _socket!.flush();
        }
      }
    }
    
    await _socket!.flush();
    
    // ACK waiting is handled in sendFiles() after this method returns
  }
  
  /// Receive files over TCP (receiver side) - STREAMING TO DISK
  Future<void> _receiveFiles() async {
    if (_socket == null) return;
    
    
    String? currentFileName;
    int? currentFileSize;
    int bytesReceived = 0;
    bool receivingFile = false;
    bool batchCompleted = false;
    
    // For streaming to disk
    IOSink? fileSink;
    String? currentFilePath;
    
    // Buffer for holding pending data between files
    List<int> pendingData = [];
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      
      await for (final data in _socket!) {
        if (_isCancelled) break;
        
        // CRITICAL: Handle file data FIRST - write directly to disk WITHOUT buffering
        if (receivingFile && currentFileSize != null) {
          final bytesRemaining = currentFileSize! - bytesReceived;
          
          if (data.length <= bytesRemaining) {
            // All data belongs to current file - write directly
            fileSink?.add(data);
            bytesReceived += data.length;
          } else {
            // Data contains file end + next file's header
            // Write file portion directly
            final dataBytes = data is Uint8List ? data : Uint8List.fromList(data);
            fileSink?.add(Uint8List.sublistView(dataBytes, 0, bytesRemaining));
            bytesReceived += bytesRemaining;
            
            // Save overflow for next file's JSON header
            pendingData = data.sublist(bytesRemaining);
          }
          
          // Report progress
          final progress = bytesReceived / currentFileSize!;
          onProgress?.call(progress.clamp(0.0, 1.0));
          
          // Check if file is complete
          if (bytesReceived >= currentFileSize!) {
            await _completeFileReceive(
              fileSink!, currentFilePath!, currentFileName!, currentFileSize!,
              bytesReceived,
            );
            fileSink = null;
            receivingFile = false;
            currentFileName = null;
            currentFileSize = null;
          } else {
            // File not complete, get next chunk
            continue;
          }
        } else {
          // Not receiving file - add to buffer for JSON parsing
          pendingData.addAll(data);
        }
        
        while (pendingData.isNotEmpty) {
          if (!receivingFile) {
            // Looking for JSON file_start message
            final content = utf8.decode(pendingData, allowMalformed: true);
            final newlineIndex = content.indexOf('\n');
            
            if (newlineIndex == -1) {
              // No complete JSON message yet, wait for more data
              break;
            }
            
            final jsonLine = content.substring(0, newlineIndex).trim();
            
            // Remove the JSON line from pending data (including newline)
            final jsonLineBytes = utf8.encode(content.substring(0, newlineIndex + 1)).length;
            pendingData = pendingData.sublist(jsonLineBytes);
            
            if (jsonLine.isEmpty) continue;
            
            try {
              final json = jsonDecode(jsonLine) as Map<String, dynamic>;
              final type = json['type'] as String;
              
              if (type == 'file_start') {
                currentFileName = json['name'] as String;
                currentFileSize = json['size'] as int;
                _currentFileIndex = json['index'] as int;
                _totalFiles = json['total'] as int;
                
                onFileStart?.call(currentFileName!, currentFileSize!);
                
                // Open file for streaming write
                currentFilePath = '${directory.path}/$currentFileName';
                final file = File(currentFilePath!);
                fileSink = file.openWrite();
                
                receivingFile = true;
                bytesReceived = 0;
                
                // Process any remaining data in pendingData as file content
                if (pendingData.isNotEmpty && currentFileSize! > 0) {
                  final bytesToWrite = pendingData.length > currentFileSize! 
                      ? currentFileSize! 
                      : pendingData.length;
                  
                  fileSink!.add(Uint8List.fromList(pendingData.sublist(0, bytesToWrite)));
                  bytesReceived += bytesToWrite;
                  
                  // Save overflow for next file's JSON header
                  if (pendingData.length > bytesToWrite) {
                    pendingData = pendingData.sublist(bytesToWrite);
                  } else {
                    pendingData = []; // Clear buffer - no more buffering during file transfer
                  }
                  
                  // Report progress
                  final progress = bytesReceived / currentFileSize!;
                  onProgress?.call(progress.clamp(0.0, 1.0));
                  
                  // Check if file is already complete
                  if (bytesReceived >= currentFileSize!) {
                    await _completeFileReceive(
                      fileSink!, currentFilePath!, currentFileName!, currentFileSize!,
                      bytesReceived,
                    );
                    fileSink = null;
                    receivingFile = false;
                    currentFileName = null;
                    currentFileSize = null;
                  }
                }
              } else if (type == 'batch_complete') {
                batchCompleted = true;
                onBatchComplete?.call();
                return;
              }
            } catch (e) {
              // Not valid JSON, skip this line
            }
          } else {
            // Receiving binary file data - WRITE DIRECTLY TO DISK (no buffering!)
            final bytesRemaining = currentFileSize! - bytesReceived;
            
            if (pendingData.isNotEmpty) {
              // Process any leftover pendingData first
              final bytesToWrite = pendingData.length > bytesRemaining 
                  ? bytesRemaining 
                  : pendingData.length;
              
              if (bytesToWrite > 0) {
                fileSink?.add(Uint8List.fromList(pendingData.sublist(0, bytesToWrite)));
                bytesReceived += bytesToWrite;
                
                // Save overflow for next file's JSON header
                if (pendingData.length > bytesToWrite) {
                  pendingData = pendingData.sublist(bytesToWrite);
                } else {
                  pendingData = [];
                }
                
                // Report progress
                final progress = bytesReceived / currentFileSize!;
                onProgress?.call(progress.clamp(0.0, 1.0));
              }
            }
            
            // Check if file is complete
            if (bytesReceived >= currentFileSize!) {
              await _completeFileReceive(
                fileSink!, currentFilePath!, currentFileName!, currentFileSize!,
                bytesReceived,
              );
              fileSink = null;
              receivingFile = false;
              currentFileName = null;
              currentFileSize = null;
              // Continue loop to process any remaining pendingData as next file's JSON
            } else {
              // Need more data, break inner loop
              break;
            }
          }
        }
        
        // CRITICAL: During file transfer, DON'T buffer - write directly to disk!
        if (receivingFile && pendingData.isEmpty) {
          // This is the fast path for file data - no intermediate buffering
          // The next socket read will come from the 'await for' loop above
          // and we need to handle it directly here
          continue; // Go get next socket data
        }
      }
    } catch (e) {
      // Clean up file sink if open
      await fileSink?.flush();
      await fileSink?.close();
      
      if (!batchCompleted) {
        onError?.call('Receive failed: $e');
      } else {
      }
    }
  }
  
  /// Helper to complete file receive, send ACK, and cleanup
  Future<void> _completeFileReceive(
    IOSink fileSink, 
    String filePath, 
    String fileName,
    int fileSize,
    int bytesReceived,
  ) async {
    await fileSink.flush();
    await fileSink.close();
    
    onFileReceived?.call(filePath);
    
    // Report 100% progress
    onProgress?.call(1.0);
    
    // Send ACK
    final ack = jsonEncode({
      'type': 'file_ack',
      'name': fileName,
    });
    _socket!.write('$ack\n');
    await _socket!.flush();
  }
  
  /// Pause ongoing transfer
  void pause() {
    _isPaused = true;
  }
  
  /// Resume paused transfer
  void resume() {
    _isPaused = false;
  }
  
  /// Cancel ongoing transfer
  void cancel() {
    _isCancelled = true;
    _isPaused = false;
    close();
  }
  
  /// Close connection and cleanup
  void close() {
    _socket?.close();
    _socket = null;
    _server?.close();
    _server = null;
  }
}
