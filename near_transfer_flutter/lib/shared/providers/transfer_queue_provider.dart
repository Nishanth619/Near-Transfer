import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/discovered_device.dart';

/// Represents a single transfer in the queue
class TransferQueueItem {
  final String id;
  final String fileName;
  final String filePath;
  final int fileSize;
  final DiscoveredDevice targetDevice;
  final DateTime createdAt;
  TransferStatus status;
  double progress;
  int bytesTransferred;
  String? errorMessage;
  int priority; // Lower = higher priority

  TransferQueueItem({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.targetDevice,
    required this.createdAt,
    this.status = TransferStatus.queued,
    this.progress = 0.0,
    this.bytesTransferred = 0,
    this.errorMessage,
    this.priority = 0,
  });

  TransferQueueItem copyWith({
    TransferStatus? status,
    double? progress,
    int? bytesTransferred,
    String? errorMessage,
    int? priority,
  }) {
    return TransferQueueItem(
      id: id,
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      targetDevice: targetDevice,
      createdAt: createdAt,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      errorMessage: errorMessage ?? this.errorMessage,
      priority: priority ?? this.priority,
    );
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedProgress => '${(progress * 100).toStringAsFixed(0)}%';
}

enum TransferStatus {
  queued,
  connecting,
  transferring,
  paused,
  completed,
  failed,
  cancelled,
}

/// Manages the transfer queue with pause/resume/cancel/reorder
class TransferQueueProvider extends ChangeNotifier {
  final List<TransferQueueItem> _queue = [];
  TransferQueueItem? _currentTransfer;
  bool _isProcessing = false;
  double _overallProgress = 0.0;
  
  // Speed tracking
  double _currentSpeed = 0.0; // bytes per second
  DateTime? _lastSpeedUpdate;
  int _lastBytesTransferred = 0;

  List<TransferQueueItem> get queue => List.unmodifiable(_queue);
  TransferQueueItem? get currentTransfer => _currentTransfer;
  bool get isProcessing => _isProcessing;
  double get overallProgress => _overallProgress;
  double get currentSpeed => _currentSpeed;
  int get queueLength => _queue.length;
  int get pendingCount => _queue.where((t) => t.status == TransferStatus.queued).length;
  int get completedCount => _queue.where((t) => t.status == TransferStatus.completed).length;

  String get formattedSpeed {
    if (_currentSpeed < 1024) return '${_currentSpeed.toStringAsFixed(0)} B/s';
    if (_currentSpeed < 1024 * 1024) return '${(_currentSpeed / 1024).toStringAsFixed(1)} KB/s';
    return '${(_currentSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// Add files to the transfer queue
  void addToQueue({
    required List<PlatformFile> files,
    required DiscoveredDevice targetDevice,
  }) {
    for (final file in files) {
      final item = TransferQueueItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_${file.name}',
        fileName: file.name,
        filePath: file.path ?? '',
        fileSize: file.size,
        targetDevice: targetDevice,
        createdAt: DateTime.now(),
        priority: _queue.length,
      );
      _queue.add(item);
    }
    notifyListeners();
    
    // Start processing if not already
    if (!_isProcessing) {
      _processQueue();
    }
  }

  /// Pause a transfer
  void pauseTransfer(String id) {
    final index = _queue.indexWhere((t) => t.id == id);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(status: TransferStatus.paused);
      notifyListeners();
    }
  }

  /// Resume a paused transfer
  void resumeTransfer(String id) {
    final index = _queue.indexWhere((t) => t.id == id);
    if (index != -1 && _queue[index].status == TransferStatus.paused) {
      _queue[index] = _queue[index].copyWith(status: TransferStatus.queued);
      notifyListeners();
      
      if (!_isProcessing) {
        _processQueue();
      }
    }
  }

  /// Cancel a transfer
  void cancelTransfer(String id) {
    final index = _queue.indexWhere((t) => t.id == id);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(status: TransferStatus.cancelled);
      notifyListeners();
    }
  }

  /// Remove a transfer from queue
  void removeFromQueue(String id) {
    _queue.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// Reorder transfer in queue
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);
    
    // Update priorities
    for (int i = 0; i < _queue.length; i++) {
      _queue[i] = _queue[i].copyWith(priority: i);
    }
    notifyListeners();
  }

  /// Clear completed/cancelled/failed transfers
  void clearCompleted() {
    _queue.removeWhere((t) => 
      t.status == TransferStatus.completed ||
      t.status == TransferStatus.cancelled ||
      t.status == TransferStatus.failed
    );
    notifyListeners();
  }

  /// Clear entire queue
  void clearAll() {
    _queue.clear();
    _currentTransfer = null;
    _isProcessing = false;
    notifyListeners();
  }

  /// Update transfer progress (called by transfer orchestrator)
  void updateProgress(String id, double progress, int bytesTransferred) {
    final index = _queue.indexWhere((t) => t.id == id);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(
        progress: progress,
        bytesTransferred: bytesTransferred,
        status: TransferStatus.transferring,
      );
      
      // Calculate speed
      _updateSpeed(bytesTransferred);
      
      // Calculate overall progress
      _calculateOverallProgress();
      
      notifyListeners();
    }
  }

  /// Mark transfer as complete
  void markComplete(String id) {
    final index = _queue.indexWhere((t) => t.id == id);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(
        status: TransferStatus.completed,
        progress: 1.0,
      );
      _currentTransfer = null;
      notifyListeners();
      
      // Process next in queue
      _processQueue();
    }
  }

  /// Mark transfer as failed
  void markFailed(String id, String error) {
    final index = _queue.indexWhere((t) => t.id == id);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(
        status: TransferStatus.failed,
        errorMessage: error,
      );
      _currentTransfer = null;
      notifyListeners();
      
      // Process next in queue
      _processQueue();
    }
  }

  void _updateSpeed(int currentBytes) {
    final now = DateTime.now();
    if (_lastSpeedUpdate != null) {
      final elapsed = now.difference(_lastSpeedUpdate!).inMilliseconds;
      if (elapsed > 500) { // Update every 500ms
        final bytesDiff = currentBytes - _lastBytesTransferred;
        _currentSpeed = (bytesDiff / elapsed) * 1000;
        _lastSpeedUpdate = now;
        _lastBytesTransferred = currentBytes;
      }
    } else {
      _lastSpeedUpdate = now;
      _lastBytesTransferred = currentBytes;
    }
  }

  void _calculateOverallProgress() {
    if (_queue.isEmpty) {
      _overallProgress = 0.0;
      return;
    }
    
    int totalBytes = 0;
    int transferredBytes = 0;
    
    for (final item in _queue) {
      totalBytes += item.fileSize;
      transferredBytes += item.bytesTransferred;
    }
    
    _overallProgress = totalBytes > 0 ? transferredBytes / totalBytes : 0.0;
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    
    // Find next queued item
    final nextItem = _queue.firstWhere(
      (t) => t.status == TransferStatus.queued,
      orElse: () => TransferQueueItem(
        id: '',
        fileName: '',
        filePath: '',
        fileSize: 0,
        targetDevice: DiscoveredDevice(
          deviceId: '',
          deviceName: '',
          ip: '',
          port: 0,
          lastSeen: DateTime.now(),
        ),
        createdAt: DateTime.now(),
      ),
    );
    
    if (nextItem.id.isEmpty) {
      _isProcessing = false;
      return;
    }
    
    _isProcessing = true;
    _currentTransfer = nextItem;
    
    // Update status to connecting
    final index = _queue.indexWhere((t) => t.id == nextItem.id);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(status: TransferStatus.connecting);
      notifyListeners();
    }
    
    // Note: Actual transfer will be triggered by UI connecting to TransferOrchestrator
    // This provider just manages the queue state
  }

  /// Get estimated time remaining for current transfer
  String getEstimatedTime(TransferQueueItem item) {
    if (_currentSpeed <= 0 || item.status != TransferStatus.transferring) {
      return '--:--';
    }
    
    final remaining = item.fileSize - item.bytesTransferred;
    final seconds = (remaining / _currentSpeed).round();
    
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).round()}m ${seconds % 60}s';
    return '${(seconds / 3600).round()}h ${((seconds % 3600) / 60).round()}m';
  }
}
