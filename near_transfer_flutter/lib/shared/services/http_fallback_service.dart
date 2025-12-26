import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/transfer_state.dart';
import '../services/transfer_state_database.dart';
import '../utils/transfer_resume_utils.dart';

/// HTTP fallback service with resume support for when WebRTC fails
class HttpFallbackService {
  final TransferStateDatabase _db = TransferStateDatabase.instance;
  
  // Progress callback
  Function(double)? onProgress;
  Function(String filePath)? onFileReceived;
  Function(String error)? onError;
  
  // Current transfer
  String? _currentTransferId;
  http.Client? _client;
  
  /// Upload file with resume support
  Future<String?> uploadFile({
    required String filePath,
    required String fileName,
    required String uploadUrl,
    required String partnerDeviceId,
    required String partnerDeviceName,
    String? resumeTransferId,
  }) async {
    _currentTransferId = resumeTransferId ?? TransferResumeUtils.generateTransferId();
    _client = http.Client();
    
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }
      
      final fileSize = await file.length();
      final fileHash = await TransferResumeUtils.calculateFileHashChunked(filePath);
      
      print('📤 HTTP Upload: $fileName ($fileSize bytes)');
      if (resumeTransferId != null) {
        print('🔄 Resuming upload: $resumeTransferId');
      }
      
      // Check for existing transfer state
      TransferState? existingState;
      int startByteIndex = 0;
      
      if (resumeTransferId != null) {
        existingState = await _db.getTransferState(resumeTransferId);
        if (existingState != null) {
          startByteIndex = existingState.bytesTransferred;
          print('🔄 Resuming from byte: $startByteIndex');
        }
      }
      
      // Create or update transfer state
      if (existingState == null) {
        final state = TransferState(
          id: _currentTransferId!,
          type: 'send',
          partnerDeviceId: partnerDeviceId,
          partnerDeviceName: partnerDeviceName,
          partnerIp: uploadUrl,
          fileName: fileName,
          filePath: filePath,
          fileSize: fileSize,
          fileHash: fileHash,
          totalChunks: 1, // HTTP is one big chunk or resumable
          completedChunks: 0,
          bytesTransferred: startByteIndex,
          status: 'in_progress',
          startedAt: DateTime.now(),
          lastUpdated: DateTime.now(),
          chunkSize: fileSize, // Entire file or resumable chunks
          lastChunkSeq: 0,
        );
        await _db.insertTransferState(state);
      } else {
        await _db.updateTransferState(
          existingState.copyWith(
            status: 'in_progress',
            lastUpdated: DateTime.now(),
          ),
        );
      }
      
      // Upload with resume support
      final request = http.StreamedRequest('POST', Uri.parse(uploadUrl));
      request.headers['Content-Type'] = 'application/octet-stream';
      request.headers['X-File-Name'] = fileName;
      request.headers['X-File-Size'] = fileSize.toString();
      request.headers ['X-Transfer-Id'] = _currentTransferId!;
      
      if (startByteIndex > 0) {
        // Resume upload from specific byte
        request.headers['Content-Range'] = 'bytes $startByteIndex-${fileSize - 1}/$fileSize';
      }
      
      // Stream file data
      final stream = file.openRead(startByteIndex);
      int uploadedBytes = startByteIndex;
      
      stream.listen(
        (chunk) {
          request.sink.add(chunk);
          uploadedBytes += chunk.length;
          
          final progress = uploadedBytes / fileSize;
          onProgress?.call(progress);
          
          // Update database every 100KB
          if (uploadedBytes % (100 * 1024) < chunk.length) {
            _db.updateProgress(
              id: _currentTransferId!,
              completedChunks: 0,
              bytesTransferred: uploadedBytes,
              lastChunkSeq: 0,
            );
          }
        },
        onDone: () {
          request.sink.close();
        },
        onError: (error) {
          request.sink.addError(error);
        },
      );
      
      // Send request
      final response = await _client!.send(request);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success
        final responseBody = await response.stream.bytesToString();
        await _db.completeTransfer(_currentTransferId!);
        print('✅ HTTP Upload completed: $_currentTransferId');
        return responseBody; // Download URL or success message
      } else if (response.statusCode == 308) {
        // Resume response - partial upload accepted
        print('⏸️ Partial upload saved, can resume later');
        await _db.pauseTransfer(_currentTransferId!);
        return null;
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ HTTP Upload error: $e');
      if (e.toString().contains('SocketException') || e.toString().contains('timeout')) {
        await _db.pauseTransfer(_currentTransferId!);
      } else {
        await _db.failTransfer(_currentTransferId!);
      }
      onError?.call(e.toString());
      return null;
    } finally {
      _client?.close();
      _client = null;
    }
  }
  
  /// Download file with resume support
  Future<String?> downloadFile({
    required String downloadUrl,
    required String fileName,
    required int fileSize,
    required String partnerDeviceId,
    required String partnerDeviceName,
    String? resumeTransferId,
  }) async {
    _currentTransferId = resumeTransferId ?? TransferResumeUtils.generateTransferId();
    _client = http.Client();
    
    try {
      print('📥 HTTP Download: $fileName ($fileSize bytes)');
      
      // Get download directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      // Check for partial file
      int startByteIndex = 0;
      if (await file.exists()) {
        startByteIndex = await file.length();
        if (startByteIndex >= fileSize) {
          print('✅ File already complete');
          return filePath;
        }
        print('🔄 Resuming from byte: $startByteIndex');
      }
      
      // Create transfer state
      final state = TransferState(
        id: _currentTransferId!,
        type: 'receive',
        partnerDeviceId: partnerDeviceId,
        partnerDeviceName: partnerDeviceName,
        partnerIp: downloadUrl,
        fileName: fileName,
        filePath: filePath,
        fileSize: fileSize,
        fileHash: null,
        totalChunks: 1,
        completedChunks: 0,
        bytesTransferred: startByteIndex,
        status: 'in_progress',
        startedAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        chunkSize: fileSize,
        lastChunkSeq: 0,
      );
      await _db.insertTransferState(state);
      
      // Download with resume support
      final request = http.Request('GET', Uri.parse(downloadUrl));
      if (startByteIndex > 0) {
        request.headers['Range'] = 'bytes=$startByteIndex-';
      }
      
      final response = await _client!.send(request);
      
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Download failed: ${response.statusCode}');
      }
      
      // Write to file (append mode if resuming)
      final sink = file.openWrite(mode: startByteIndex > 0 ? FileMode.append : FileMode.write);
      int downloadedBytes = startByteIndex;
      
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        
        final progress = downloadedBytes / fileSize;
        onProgress?.call(progress);
        
        // Update database every 100KB
        if (downloadedBytes % (100 * 1024) < chunk.length) {
          _db.updateProgress(
            id: _currentTransferId!,
            completedChunks: 0,
            bytesTransferred: downloadedBytes,
            lastChunkSeq: 0,
          );
        }
      }
      
      await sink.flush();
      await sink.close();
      
      await _db.completeTransfer(_currentTransferId!);
      print('✅ HTTP Download completed: $filePath');
      onFileReceived?.call(filePath);
      return filePath;
      
    } catch (e) {
      print('❌ HTTP Download error: $e');
      if (e.toString().contains('SocketException') || e.toString().contains('timeout')) {
        await _db.pauseTransfer(_currentTransferId!);
      } else {
        await _db.failTransfer(_currentTransferId!);
      }
      onError?.call(e.toString());
      return null;
    } finally {
      _client?.close();
      _client = null;
    }
  }
  
  /// Cancel current transfer
  void cancel() {
    _client?.close();
    _client = null;
    if (_currentTransferId != null) {
      _db.pauseTransfer(_currentTransferId!);
    }
  }
}
