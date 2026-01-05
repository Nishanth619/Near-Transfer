import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../../shared/widgets/animated_background.dart';
import '../../../core/constants.dart';
import '../../../shared/providers/transfer_queue_provider.dart';

class TransferQueueScreen extends StatelessWidget {
  const TransferQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Transfer Queue', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<TransferQueueProvider>(
            builder: (context, queue, _) {
              if (queue.queue.isNotEmpty) {
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'clear_completed') {
                      queue.clearCompleted();
                    } else if (value == 'clear_all') {
                      _showClearAllDialog(context, queue);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'clear_completed',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline),
                          SizedBox(width: 8),
                          Text('Clear Completed'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Clear All', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: AnimatedBackground(
        child: Container(
          margin: const EdgeInsets.only(top: kToolbarHeight + 20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Consumer<TransferQueueProvider>(
            builder: (context, queue, _) {
              if (queue.queue.isEmpty) {
                return _buildEmptyState();
              }
              return _buildQueueList(context, queue);
            },
          ),
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
            Icons.queue_rounded,
            size: 80,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Transfers',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transfer queue is empty',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(BuildContext context, TransferQueueProvider queue) {
    return Column(
      children: [
        // Stats bar
        _buildStatsBar(queue),
        
        // Queue list with reordering
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: queue.queue.length,
            onReorder: (oldIndex, newIndex) {
              queue.reorderQueue(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final item = queue.queue[index];
              return _buildQueueItem(context, item, queue, key: ValueKey(item.id));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar(TransferQueueProvider queue) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.8),
            AppColors.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.pending_actions,
            label: 'Pending',
            value: '${queue.pendingCount}',
          ),
          _buildStatItem(
            icon: Icons.speed,
            label: 'Speed',
            value: queue.formattedSpeed,
          ),
          _buildStatItem(
            icon: Icons.check_circle,
            label: 'Done',
            value: '${queue.completedCount}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildQueueItem(
    BuildContext context,
    TransferQueueItem item,
    TransferQueueProvider queue, {
    Key? key,
  }) {
    final statusColor = _getStatusColor(item.status);
    final statusIcon = _getStatusIcon(item.status);
    
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showItemOptions(context, item, queue),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Drag handle
                  const Icon(Icons.drag_handle, color: Colors.grey),
                  const SizedBox(width: 12),
                  
                  // File icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getFileIcon(item.fileName),
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // File info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.fileName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              item.formattedSize,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.targetDevice.deviceName,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Status
                  Column(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 20),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusText(item.status),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Progress bar (if transferring)
              if (item.status == TransferStatus.transferring ||
                  item.status == TransferStatus.connecting) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.status == TransferStatus.connecting ? null : item.progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.formattedProgress,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    Text(
                      queue.getEstimatedTime(item),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
              
              // Error message (if failed)
              if (item.status == TransferStatus.failed && item.errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.errorMessage!,
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showItemOptions(
    BuildContext context,
    TransferQueueItem item,
    TransferQueueProvider queue,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              item.fileName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            if (item.status == TransferStatus.queued ||
                item.status == TransferStatus.transferring)
              _buildOptionTile(
                icon: Icons.pause,
                label: 'Pause',
                onTap: () {
                  queue.pauseTransfer(item.id);
                  Navigator.pop(context);
                },
              ),
            
            if (item.status == TransferStatus.paused)
              _buildOptionTile(
                icon: Icons.play_arrow,
                label: 'Resume',
                onTap: () {
                  queue.resumeTransfer(item.id);
                  Navigator.pop(context);
                },
              ),
            
            if (item.status != TransferStatus.completed &&
                item.status != TransferStatus.cancelled)
              _buildOptionTile(
                icon: Icons.cancel,
                label: 'Cancel',
                color: Colors.orange,
                onTap: () {
                  queue.cancelTransfer(item.id);
                  Navigator.pop(context);
                },
              ),
            
            _buildOptionTile(
              icon: Icons.delete,
              label: 'Remove from queue',
              color: Colors.red,
              onTap: () {
                queue.removeFromQueue(item.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  void _showClearAllDialog(BuildContext context, TransferQueueProvider queue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All?'),
        content: const Text('This will remove all transfers from the queue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              queue.clearAll();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(TransferStatus status) {
    switch (status) {
      case TransferStatus.queued: return Colors.blue;
      case TransferStatus.connecting: return Colors.orange;
      case TransferStatus.transferring: return Colors.green;
      case TransferStatus.paused: return Colors.orange;
      case TransferStatus.completed: return Colors.green;
      case TransferStatus.failed: return Colors.red;
      case TransferStatus.cancelled: return Colors.grey;
    }
  }

  IconData _getStatusIcon(TransferStatus status) {
    switch (status) {
      case TransferStatus.queued: return Icons.schedule;
      case TransferStatus.connecting: return Icons.sync;
      case TransferStatus.transferring: return Icons.upload;
      case TransferStatus.paused: return Icons.pause;
      case TransferStatus.completed: return Icons.check_circle;
      case TransferStatus.failed: return Icons.error;
      case TransferStatus.cancelled: return Icons.cancel;
    }
  }

  String _getStatusText(TransferStatus status) {
    switch (status) {
      case TransferStatus.queued: return 'Queued';
      case TransferStatus.connecting: return 'Connecting';
      case TransferStatus.transferring: return 'Sending';
      case TransferStatus.paused: return 'Paused';
      case TransferStatus.completed: return 'Done';
      case TransferStatus.failed: return 'Failed';
      case TransferStatus.cancelled: return 'Cancelled';
    }
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return Icons.image;
    if (['mp4', 'mkv', 'avi', 'mov'].contains(ext)) return Icons.video_file;
    if (['mp3', 'wav', 'aac', 'flac'].contains(ext)) return Icons.audio_file;
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf;
    if (['doc', 'docx'].contains(ext)) return Icons.description;
    if (['apk'].contains(ext)) return Icons.android;
    return Icons.insert_drive_file;
  }
}
