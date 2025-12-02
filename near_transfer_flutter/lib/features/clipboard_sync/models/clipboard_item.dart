import 'package:uuid/uuid.dart';

/// Represents a clipboard item in history
class ClipboardItem {
  final String id;
  final String content;
  final DateTime timestamp;
  final String? deviceName;
  final bool isSent;
  final bool isReceived;

  ClipboardItem({
    String? id,
    required this.content,
    DateTime? timestamp,
    this.deviceName,
    this.isSent = false,
    this.isReceived = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  /// Get preview text (first 100 characters)
  String get preview {
    if (content.length <= 100) return content;
    return '${content.substring(0, 100)}...';
  }

  /// Get formatted time ago
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'min' : 'mins'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else {
      return '${difference.inDays ~/ 7} ${difference.inDays ~/ 7 == 1 ? 'week' : 'weeks'} ago';
    }
  }

  /// Get word count
  int get wordCount {
    return content.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  /// Get character count
  int get charCount {
    return content.length;
  }

  /// Check if content is empty
  bool get isEmpty {
    return content.trim().isEmpty;
  }

  /// Convert to JSON for database
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'device_name': deviceName,
      'is_sent': isSent ? 1 : 0,
      'is_received': isReceived ? 1 : 0,
    };
  }

  /// Create from JSON
  factory ClipboardItem.fromJson(Map<String, dynamic> json) {
    return ClipboardItem(
      id: json['id'] as String,
      content: json['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      deviceName: json['device_name'] as String?,
      isSent: (json['is_sent'] as int) == 1,
      isReceived: (json['is_received'] as int) == 1,
    );
  }

  /// Create copy with modified fields
  ClipboardItem copyWith({
    String? id,
    String? content,
    DateTime? timestamp,
    String? deviceName,
    bool? isSent,
    bool? isReceived,
  }) {
    return ClipboardItem(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      deviceName: deviceName ?? this.deviceName,
      isSent: isSent ?? this.isSent,
      isReceived: isReceived ?? this.isReceived,
    );
  }

  @override
  String toString() => 'ClipboardItem($id, ${preview.substring(0, 20)}...)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipboardItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
