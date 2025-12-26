import 'package:flutter/material.dart';
import '../../../shared/providers/transfer_orchestrator.dart';
import '../../../shared/models/transfer_state.dart' as ts;
import '../../../shared/utils/transfer_resume_utils.dart';

class ResumeTransferScreen extends StatefulWidget {
  final TransferOrchestrator orchestrator;

  const ResumeTransferScreen({
    super.key,
    required this.orchestrator,
  });

  @override
  State<ResumeTransferScreen> createState() => _ResumeTransferScreenState();
}

class _ResumeTransferScreenState extends State<ResumeTransferScreen> {
  List<ts.TransferState> _resumableTransfers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResumableTransfers();
  }

  Future<void> _loadResumableTransfers() async {
    setState(() => _isLoading = true);
    
    final transfers = await widget.orchestrator.getResumableTransfers();
    
    setState(() {
      _resumableTransfers = transfers;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume Transfers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Cleanup Old',
            onPressed: _showCleanupDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _resumableTransfers.isEmpty
              ? _buildEmptyState()
              : _buildTransferList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No interrupted transfers',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All your transfers are complete!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _resumableTransfers.length,
      itemBuilder: (context, index) {
        final transfer = _resumableTransfers[index];
        return _buildTransferCard(transfer);
      },
    );
  }

  Widget _buildTransferCard(ts.TransferState transfer) {
    final progress = transfer.progress;
    final canResume = TransferResumeUtils.canResumeAfterTime(transfer.lastUpdated);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File info
            Row(
              children: [
                Icon(
                  Icons.insert_drive_file,
                  color: Colors.blue[600],
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transfer.fileName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${transfer.type == 'send' ? 'To' : 'From'}: ${transfer.partnerDeviceName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Progress
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                canResume ? Colors.blue : Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            
            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(1)}% complete',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${TransferResumeUtils.formatBytes(transfer.bytesTransferred)} / ${TransferResumeUtils.formatBytes(transfer.fileSize)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Timestamp
            Text(
              'Last updated: ${_formatTimestamp(transfer.lastUpdated)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
            
            if (!canResume)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '⚠️ Transfer too old to resume automatically',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange[700],
                  ),
                ),
              ),
            
            const SizedBox(height: 12),
            
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _deleteTransfer(transfer),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: canResume ? () => _resumeTransfer(transfer) : null,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Resume'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Future<void> _resumeTransfer(ts.TransferState transfer) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final success = await widget.orchestrator.resumeTransfer(transfer.id);
    
    if (mounted) {
      Navigator.pop(context); // Close loading
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer resumed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to previous screen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resume transfer.  Try connecting manually.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTransfer(ts.TransferState transfer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transfer'),
        content: Text('Delete "${transfer.fileName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await widget.orchestrator.deleteTransferState(transfer.id);
      _loadResumableTransfers(); // Refresh list
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer deleted'),
          ),
        );
      }
    }
  }

  Future<void> _showCleanupDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cleanup'),
        content: const Text('What would you like to clean up?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'completed'),
            child: const Text('Completed'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'old'),
            child: const Text('Old (>7 days)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (choice != null) {
      int count = 0;
      if (choice == 'completed') {
        count = await widget.orchestrator.cleanupCompletedTransfers();
      } else if (choice == 'old') {
        count = await widget.orchestrator.cleanupOldTransfers();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cleaned up $count transfers')),
        );
        _loadResumableTransfers();
      }
    }
  }
}
