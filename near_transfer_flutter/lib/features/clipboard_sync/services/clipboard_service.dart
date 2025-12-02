import 'package:flutter/services.dart';
import '../../../shared/services/database_service.dart';
import '../models/clipboard_item.dart';

/// Service for managing clipboard operations and history
class ClipboardService {
  static final ClipboardService _instance = ClipboardService._internal();
  factory ClipboardService() => _instance;
  ClipboardService._internal();

  final DatabaseService _dbService =DatabaseService();
  bool _autoSyncEnabled = true;

  /// Get current clipboard text
  Future<String?> getClipboardText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (e) {
      return null;
    }
  }

  /// Set clipboard text
  Future<void> setClipboardText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      // Fail silently
    }
  }

  /// Save clipboard content to history
  Future<void> saveToHistory(String content, {String? deviceName, bool? isSent, bool? isReceived}) async {
    if (content.trim().isEmpty) return;

    try {
      final item = ClipboardItem(
        content: content,
        deviceName: deviceName,
        isSent: isSent ?? false,
        isReceived: isReceived ?? false,
      );

      await _dbService.insertClipboardItem(item);

      // Keep only last 10 items
      await _cleanupOldItems();
    } catch (e) {
      // Fail silently if database not ready
    }
  }

  /// Get clipboard history
  Future<List<ClipboardItem>> getHistory() async {
    try {
      return await _dbService.getClipboardHistory();
    } catch (e) {
      // Return empty list if database not ready
      return [];
    }
  }

  /// Clear clipboard history
  Future<void> clearHistory() async {
    await _dbService.clearClipboardHistory();
  }

  /// Delete specific item from history
  Future<void> deleteItem(String id) async {
    await _dbService.deleteClipboardItem(id);
  }

  /// Cleanup old items (keep only last 10)
  Future<void> _cleanupOldItems() async {
    final items = await getHistory();
    if (items.length > 10) {
      // Sort by timestamp descending
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // Delete items beyond the 10 most recent
      for (int i = 10; i < items.length; i++) {
        await deleteItem(items[i].id);
      }
    }
  }

  /// Get auto-sync status
  bool get isAutoSyncEnabled => _autoSyncEnabled;

  /// Set auto-sync status
  Future<void> setAutoSync(bool enabled) async {
    _autoSyncEnabled = enabled;
    // TODO: Save to shared preferences
  }

  /// Copy clipboard item content to clipboard
  Future<void> copyToClipboard(ClipboardItem item) async {
    await setClipboardText(item.content);
  }

  /// Get clipboard item count
  Future<int> getItemCount() async {
    final items = await getHistory();
    return items.length;
  }

  /// Check if clipboard has content
  Future<bool> hasClipboardContent() async {
    final text = await getClipboardText();
    return text != null && text.trim().isNotEmpty;
  }

  /// Get current clipboard as ClipboardItem
  Future<ClipboardItem?> getCurrentClipboardItem() async {
    final text = await getClipboardText();
    if (text == null || text.trim().isEmpty) return null;

    return ClipboardItem(
      content: text,
      timestamp: DateTime.now(),
    );
  }
}
