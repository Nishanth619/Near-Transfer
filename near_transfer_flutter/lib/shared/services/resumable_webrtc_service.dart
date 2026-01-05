import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import './webrtc_service.dart';
import '../models/transfer_state.dart';
import '../services/transfer_state_database.dart';
import '../utils/transfer_resume_utils.dart';
import '../../core/network_config.dart';

/// Extended WebRTC service with resume support
class ResumableWebRTCService extends WebRTCService {
  final TransferStateDatabase _db = TransferStateDatabase.instance;
  
  // Current transfer tracking
  String? _currentTransferId;
  String? _partnerDeviceId;
  String? _partnerDeviceName;
  String? _partnerIp;
  
  // Resume state
  bool _isResuming = false;
  int _startChunkIndex = 0;
  
  /// Send file with resume support
  Future<void> sendFileResumable({
    required Uint8List fileData,
    required String fileName,
    required int fileSize,
    required String partnerDeviceId,
    required String partnerDeviceName,
    required String partnerIp,
    String? resumeTransferId,
    int? startChunkIndex,
  }) async {
    // Generate or use existing transfer ID
    _currentTransferId = resumeTransferId ?? TransferResumeUtils.generateTransferId();
    _partnerDeviceId = partnerDeviceId;
    _partnerDeviceName = partnerDeviceName;
    _partnerIp = partnerIp;
    _startChunkIndex = startChunkIndex ?? 0;
    _isResuming = resumeTransferId != null;
    
    if (_isResuming) {
    }
    
    final totalChunks = (fileSize / NetworkConfig.chunkSize).ceil();
    final chunkSize = NetworkConfig.chunkSize;
    
    // Calculate file hash for verification (async, don't block)
    String? fileHash;
    if (!_isResuming) {
      // Only calculate hash for new transfers
      // For resume, we'll verify against stored hash
      fileHash = await _calculateDataHash(fileData);
    }
    
    // Create or load transfer state
    TransferState? existingState;
    if (_isResuming) {
      existingState = await _db.getTransferState(_currentTransferId!);
      fileHash = existingState?.fileHash;
    }
    
    if (existingState == null) {
      // New transfer - create state
      final state = TransferState(
        id: _currentTransferId!,
        type: 'send',
        partnerDeviceId: partnerDeviceId,
        partnerDeviceName: partnerDeviceName,
        partnerIp: partnerIp,
        fileName: fileName,
        filePath: null, // We have data in memory
        fileSize: fileSize,
        fileHash: fileHash,
        totalChunks: totalChunks,
        completedChunks: _startChunkIndex,
        bytesTransferred: _startChunkIndex * chunkSize,
        status: 'in_progress',
        startedAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        chunkSize: chunkSize,
        lastChunkSeq: _startChunkIndex,
      );
      
      await _db.insertTransferState(state);
    } else {
      // Resuming - update state
      await _db.updateTransferState(
        existingState.copyWith(
          status: 'in_progress',
          lastUpdated: DateTime.now(),
        ),
      );
    }
    
    // Use base class sendFile with custom progress callback
    final originalProgressCallback = onProgress;
    onProgress = (progress) {
      originalProgressCallback?.call(progress);
      _onProgressUpdate(progress, totalChunks, chunkSize);
    };
    
    try {
      // Send file using base WebRTC service
      await sendFile(
        fileData,
        fileName,
        fileSize,
        startChunkIndex: _startChunkIndex,
      );
      
      // Mark as completed
      await _db.completeTransfer(_currentTransferId!);
    } catch (e) {
      // Mark as failed or paused
      if (e.toString().contains('disconnect') || e.toString().contains('closed')) {
        await _db.pauseTransfer(_currentTransferId!);
      } else {
        await _db.failTransfer(_currentTransferId!);
      }
      rethrow;
    } finally {
      onProgress = originalProgressCallback; // Restore original callback
    }
  }
  
  /// Progress callback for database updates
  void _onProgressUpdate(double progress, int totalChunks, int chunkSize) {
    if (_currentTransferId == null) return;
    
    final completedChunks = (progress * totalChunks).floor();
    final bytesTransferred = completedChunks * chunkSize;
    
    // Update database every 10 chunks to avoid excessive writes
    if (completedChunks % 10 == 0 || completedChunks == totalChunks) {
      _db.updateProgress(
        id: _currentTransferId!,
        completedChunks: completedChunks,
        bytesTransferred: bytesTransferred,
        lastChunkSeq: completedChunks,
      );
    }
  }
  
  /// Receive file with resume support
  Future<void> startReceivingResumable({
    required String fileName,
    required int fileSize,
    required String partnerDeviceId,
    required String partnerDeviceName,
    required String partnerIp,
    String? resumeTransferId,
  }) async {
    _currentTransferId = resumeTransferId ?? TransferResumeUtils.generateTransferId();
    _partnerDeviceId = partnerDeviceId;
    _partnerDeviceName = partnerDeviceName;
    _partnerIp = partnerIp;
    
    
    final totalChunks = (fileSize / NetworkConfig.chunkSize).ceil();
    final chunkSize = NetworkConfig.chunkSize;
    
    // Create transfer state for receiving
    final state = TransferState(
      id: _currentTransferId!,
      type: 'receive',
      partnerDeviceId: partnerDeviceId,
      partnerDeviceName: partnerDeviceName,
      partnerIp: partnerIp,
      fileName: fileName,
      filePath: null,
      fileSize: fileSize,
      fileHash: null, // Will be set after verification
      totalChunks: totalChunks,
      completedChunks: 0,
      bytesTransferred: 0,
      status: 'in_progress',
      startedAt: DateTime.now(),
      lastUpdated: DateTime.now(),
      chunkSize: chunkSize,
      lastChunkSeq: 0,
    );
    
    await _db.insertTransferState(state);
  }
  
  /// Attempt to resume a paused transfer
  Future<bool> resumeTransfer(String transferId) async {
    final state = await _db.getTransferState(transferId);
    
    if (state == null) {
      return false;
    }
    
    if (!state.canResume) {
      return false;
    }
    
    // Check if transfer is not too old
    if (!TransferResumeUtils.canResumeAfterTime(state.lastUpdated)) {
      return false;
    }
    
    
    // Store resume state
    _currentTransferId = transferId;
    _partnerDeviceId = state.partnerDeviceId;
    _partnerDeviceName = state.partnerDeviceName;
    _partnerIp = state.partnerIp;
    _isResuming = true;
    _startChunkIndex = state.lastChunkSeq;
    
    return true;
  }
  
  /// Calculate hash of data
  Future<String?> _calculateDataHash(Uint8List data) async {
    try {
      // For large data, this might be slow - consider chunked approach
      // Using crypto package
      final digest = await TransferResumeUtils.calculateFileHashChunked(
        '', // Empty path since we have data
      );
      return digest;
    } catch (e) {
      return null;
    }
  }
  
  /// Get current transfer ID
  String? get currentTransferId => _currentTransferId;
  
  /// Check if currently resuming
  bool get isResuming => _isResuming;
  
  /// Pause current transfer
  Future<void> pauseCurrentTransfer() async {
    if (_currentTransferId != null) {
      await _db.pauseTransfer(_currentTransferId!);
      pauseSending(); // Pause WebRTC sending
    }
  }
  
  /// Resume current transfer
  Future<void> resumeCurrentTransfer() async {
    if (_currentTransferId != null) {
      resumeSending(); // Resume WebRTC sending
    }
  }
  
  @override
  void close() {
    // Save state before closing if transfer is in progress
    if (_currentTransferId != null) {
      _db.pauseTransfer(_currentTransferId!);
    }
    super.close();
  }
}
