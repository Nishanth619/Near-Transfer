import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../shared/widgets/help_button.dart';
import '../../../core/constants.dart';
import '../models/clipboard_item.dart';
import '../services/clipboard_service.dart';
import '../widgets/clipboard_list_item.dart';

class ClipboardScreen extends StatefulWidget {
  const ClipboardScreen({super.key});

  @override
  State<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends State<ClipboardScreen> {
  final ClipboardService _clipboardService = ClipboardService();
  
  List<ClipboardItem> _history = [];
  ClipboardItem? _currentClipboard;
  bool _isLoading = true;
  bool _autoSync = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final history = await _clipboardService.getHistory();
      final current = await _clipboardService.getCurrentClipboardItem();
      final autoSync = _clipboardService.isAutoSyncEnabled;

      if (mounted) {
        setState(() {
          _history = history;
          _currentClipboard = current;
          _autoSync = autoSync;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _history = [];
          _currentClipboard = null;
        });
      }
    }
  }

  Future<void> _saveCurrentToHistory() async {
    final text = await _clipboardService.getClipboardText();
    if (text != null && text.trim().isNotEmpty) {
      await _clipboardService.saveToHistory(text);
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to history')),
        );
      }
    }
  }

  Future<void> _copyToClipboard(ClipboardItem item) async {
    await _clipboardService.setClipboardText(item.content);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _deleteItem(ClipboardItem item) async {
    await _clipboardService.deleteItem(item.id);
    await _loadData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted')),
      );
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all clipboard history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _clipboardService.clearHistory();
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History cleared')),
        );
      }
    }
  }

  Future<void> _toggleAutoSync() async {
    final newValue = !_autoSync;
    await _clipboardService.setAutoSync(newValue);
    setState(() {
      _autoSync = newValue;
    });
  }

  void _sendClipboard() {
    if (_currentClipboard == null || _currentClipboard!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
      return;
    }

    // Navigate to device discovery with clipboard content
    // Pass the text content as extra data
    context.push('/discovery', extra: {
      'type': 'clipboard',
      'content': _currentClipboard!.content,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Clipboard Sync',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          const HelpButton(
            featureName: 'Clipboard Sync',
            helpText: 'Sync and share text between devices.\n\n• View your current clipboard content\n• Save items to history for later\n• Tap the send button to share text\n• Enable auto-sync to automatically sync clipboard',
          ),
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: _clearHistory,
              tooltip: 'Clear History',
            ),
        ],
      ),
      body: AnimatedBackground(
        child: Container(
          margin: const EdgeInsets.only(top: kToolbarHeight + 60),
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingMd,
            AppConstants.spacingMd,
            AppConstants.spacingMd,
            0,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // Auto-sync toggle
          _buildAutoSyncToggle(),

          const SizedBox(height: 16),

          // Current clipboard card
          if (_currentClipboard != null) ...[
            _buildCurrentClipboard(),
            const SizedBox(height: 24),
          ],

          // History header
          if (_history.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'History (${_history.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: _saveCurrentToHistory,
                  child: const Text('Save Current'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // History list
          if (_history.isEmpty)
            _buildEmptyState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];
                return ClipboardListItem(
                  item: item,
                  onCopy: () => _copyToClipboard(item),
                  onDelete: () => _deleteItem(item),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAutoSyncToggle() {
    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.sync, size: 20),
                SizedBox(width: 8),
                Text(
                  'Auto-Sync',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Switch(
              value: _autoSync,
              onChanged: (_) => _toggleAutoSync(),
              activeColor: const Color(0xFF6C63FF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentClipboard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF6C63FF), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.content_paste,
                  color: Color(0xFF6C63FF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Current Clipboard',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6C63FF),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.send, size: 20),
                  onPressed: _sendClipboard,
                  tooltip: 'Send',
                  color: const Color(0xFF6C63FF),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              _currentClipboard!.content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.text_fields, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${_currentClipboard!.charCount} chars',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.article, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${_currentClipboard!.wordCount} words',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.content_paste_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No clipboard history',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Copy some text to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveCurrentToHistory,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text('Save Current Clipboard'),
          ),
        ],
      ),
    );
  }
}
