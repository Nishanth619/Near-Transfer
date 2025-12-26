/// Model representing the state of a transfer that can be resumed
class TransferState {
  final String id; // Unique transfer ID
  final String type; // 'send' or 'receive'
  final String partnerDeviceId;
  final String partnerDeviceName;
  final String partnerIp;

  // File information
  final String fileName;
  final String? filePath; // Local file path (sender only)
  final int fileSize;
  final String? fileHash; // SHA256 hash for verification

  // Progress tracking
  final int totalChunks;
  final int completedChunks;
  final int bytesTransferred;

  // State management
  final String status; // 'in_progress', 'paused', 'completed', 'failed'
  final DateTime startedAt;
  final DateTime lastUpdated;
  final DateTime? completedAt;

  // Resume data
  final int chunkSize;
  final int lastChunkSeq;

  // Multi-file batch support
  final String? batchId;
  final int? fileIndex;
  final int? totalFilesInBatch;

  TransferState({
    required this.id,
    required this.type,
    required this.partnerDeviceId,
    required this.partnerDeviceName,
    required this.partnerIp,
    required this.fileName,
    this.filePath,
    required this.fileSize,
    this.fileHash,
    required this.totalChunks,
    required this.completedChunks,
    required this.bytesTransferred,
    required this.status,
    required this.startedAt,
    required this.lastUpdated,
    this.completedAt,
    required this.chunkSize,
    required this.lastChunkSeq,
    this.batchId,
    this.fileIndex,
    this.totalFilesInBatch,
  });

  // Helper getters
  double get progress => totalChunks > 0 ? completedChunks / totalChunks : 0.0;
  bool get canResume => status == 'paused' || status == 'in_progress';
  bool get isComplete => status == 'completed';
  bool get isFailed => status == 'failed';
  int get remainingBytes => fileSize - bytesTransferred;
  int get remainingChunks => totalChunks - completedChunks;

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'partner_device_id': partnerDeviceId,
      'partner_device_name': partnerDeviceName,
      'partner_ip': partnerIp,
      'file_name': fileName,
      'file_path': filePath,
      'file_size': fileSize,
      'file_hash': fileHash,
      'total_chunks': totalChunks,
      'completed_chunks': completedChunks,
      'bytes_transferred': bytesTransferred,
      'status': status,
      'started_at': startedAt.millisecondsSinceEpoch,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      'chunk_size': chunkSize,
      'last_chunk_seq': lastChunkSeq,
      'batch_id': batchId,
      'file_index': fileIndex,
      'total_files_in_batch': totalFilesInBatch,
    };
  }

  // Create from Map
  factory TransferState.fromMap(Map<String, dynamic> map) {
    return TransferState(
      id: map['id'] as String,
      type: map['type'] as String,
      partnerDeviceId: map['partner_device_id'] as String,
      partnerDeviceName: map['partner_device_name'] as String,
      partnerIp: map['partner_ip'] as String,
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String?,
      fileSize: map['file_size'] as int,
      fileHash: map['file_hash'] as String?,
      totalChunks: map['total_chunks'] as int,
      completedChunks: map['completed_chunks'] as int,
      bytesTransferred: map['bytes_transferred'] as int,
      status: map['status'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['last_updated'] as int),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
      chunkSize: map['chunk_size'] as int,
      lastChunkSeq: map['last_chunk_seq'] as int,
      batchId: map['batch_id'] as String?,
      fileIndex: map['file_index'] as int?,
      totalFilesInBatch: map['total_files_in_batch'] as int?,
    );
  }

  // Create a copy with updated fields
  TransferState copyWith({
    String? id,
    String? type,
    String? partnerDeviceId,
    String? partnerDeviceName,
    String? partnerIp,
    String? fileName,
    String? filePath,
    int? fileSize,
    String? fileHash,
    int? totalChunks,
    int? completedChunks,
    int? bytesTransferred,
    String? status,
    DateTime? startedAt,
    DateTime? lastUpdated,
    DateTime? completedAt,
    int? chunkSize,
    int? lastChunkSeq,
    String? batchId,
    int? fileIndex,
    int? totalFilesInBatch,
  }) {
    return TransferState(
      id: id ?? this.id,
      type: type ?? this.type,
      partnerDeviceId: partnerDeviceId ?? this.partnerDeviceId,
      partnerDeviceName: partnerDeviceName ?? this.partnerDeviceName,
      partnerIp: partnerIp ?? this.partnerIp,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      fileHash: fileHash ?? this.fileHash,
      totalChunks: totalChunks ?? this.totalChunks,
      completedChunks: completedChunks ?? this.completedChunks,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      completedAt: completedAt ?? this.completedAt,
      chunkSize: chunkSize ?? this.chunkSize,
      lastChunkSeq: lastChunkSeq ?? this.lastChunkSeq,
      batchId: batchId ?? this.batchId,
      fileIndex: fileIndex ?? this.fileIndex,
      totalFilesInBatch: totalFilesInBatch ?? this.totalFilesInBatch,
    );
  }

  @override
  String toString() {
    return 'TransferState(id: $id, type: $type, fileName: $fileName, '
        'progress: ${(progress * 100).toStringAsFixed(1)}%, status: $status)';
  }
}
