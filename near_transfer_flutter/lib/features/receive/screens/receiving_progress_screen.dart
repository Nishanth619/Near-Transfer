import 'package:flutter/material.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../shared/widgets/circular_progress.dart';
import '../../../core/constants.dart';
import '../../../shared/providers/transfer_orchestrator.dart';
import '../../../shared/utils/file_icon_utils.dart';

class ReceivingProgressScreen extends StatefulWidget {
  final TransferOrchestrator orchestrator;
  final String senderName;

  const ReceivingProgressScreen({
    super.key,
    required this.orchestrator,
    required this.senderName,
  });

  @override
  State<ReceivingProgressScreen> createState() => _ReceivingProgressScreenState();
}

class _ReceivingProgressScreenState extends State<ReceivingProgressScreen> {
  @override
  void initState() {
    super.initState();
    widget.orchestrator.addListener(_onOrchestratorUpdate);
  }

  @override
  void dispose() {
    widget.orchestrator.removeListener(_onOrchestratorUpdate);
    super.dispose();
  }

  void _onOrchestratorUpdate() {
    debugPrint('[PROGRESS SCREEN] Listener called - progress: ${widget.orchestrator.progress}, state: ${widget.orchestrator.state}');
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.orchestrator.state;
    final progress = widget.orchestrator.progress;
    final currentFileName = widget.orchestrator.currentFileName ?? 'file';

    return PopScope(
      canPop: state == TransferState.completed || state == TransferState.failed || state == TransferState.paused,
      child: Scaffold(
        body: AnimatedBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  
                  // Compact status icon
                  _buildCompactStatusIcon(state),
                  
                  const SizedBox(height: 12),
                  
                  // Status text
                  Text(
                    _getStatusText(state),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Sender name
                  Text(
                    'from ${widget.senderName}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Circular progress indicator
                  if (state == TransferState.transferring || state == TransferState.paused)
                    Column(
                      children: [
                        AnimatedCircularProgress(
                          progress: progress,
                          size: 140,
                          progressColor: state == TransferState.paused 
                              ? Colors.orange 
                              : Colors.blue,
                          speedText: state == TransferState.transferring 
                              ? widget.orchestrator.speedString 
                              : 'Paused',
                          etaText: state == TransferState.transferring 
                              ? 'ETA: ${widget.orchestrator.etaString}' 
                              : null,
                          isPaused: state == TransferState.paused,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  
                  // Paused indicator
                  if (state == TransferState.paused)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange, width: 2),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause_circle, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Transfer Paused',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // File list (if we have files info)
                  if (widget.orchestrator.totalFiles > 0)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Files',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView.separated(
                                itemCount: widget.orchestrator.totalFiles,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  return _buildFileItem(index);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // Single file display (fallback)
                    Expanded(
                      child: Center(
                        child: Text(
                          currentFileName,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  if (state == TransferState.completed)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  
                  if (state == TransferState.failed)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: (state == TransferState.transferring || state == TransferState.paused)
            ? FloatingActionButton(
                onPressed: () async {
                  if (state == TransferState.transferring) {
                    // Pause the transfer
                    await widget.orchestrator.pauseCurrentTransfer();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transfer paused'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } else if (state == TransferState.paused) {
                    // Resume the transfer
                    await widget.orchestrator.resumeCurrentTransfer();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transfer resumed'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                backgroundColor: state == TransferState.paused ? Colors.green : Colors.orange,
                child: Icon(state == TransferState.paused ? Icons.play_arrow : Icons.pause),
                tooltip: state == TransferState.paused ? 'Resume Transfer' : 'Pause Transfer',
              )
            : null,
      ),
    );
  }

  Widget _buildCompactStatusIcon(TransferState state) {
    IconData icon;
    Color color;
    
    if (state == TransferState.completed) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (state == TransferState.failed) {
      icon = Icons.error;
      color = Colors.red;
    } else {
      icon = Icons.download;
      color = AppColors.primary;
    }
    
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 32,
        color: Colors.white,
      ),
    );
  }

  Widget _buildFileItem(int index) {
    final file = widget.orchestrator.files[index];
    final currentIndex = widget.orchestrator.currentFileIndex;
    final state = widget.orchestrator.state;
    
    // Determine file status
    String status;
    
    if (index < currentIndex || (index == currentIndex && state == TransferState.completed)) {
      status = 'completed';
    } else if (index == currentIndex && state == TransferState.paused) {
      status = 'paused';
    } else if (index == currentIndex && state == TransferState.transferring) {
      status = 'transferring';
    } else {
      status = 'pending';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status == 'transferring' 
            ? Colors.white.withValues(alpha: 0.15) 
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // File type icon or status icon
          if (status == 'transferring')
            SizedBox(
              width: 32,
              height: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FileIconUtils.buildFileIcon(file.name, size: 32),
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(FileIconUtils.getColor(file.name)),
                    ),
                  ),
                ],
              ),
            )
          else if (status == 'completed')
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, size: 20, color: Colors.green),
            )
          else if (status == 'paused')
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pause_circle, size: 20, color: Colors.orange),
            )
          else
            // Pending - show file type icon
            FileIconUtils.buildFileIcon(file.name, size: 32),
          
          const SizedBox(width: 12),
          
          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatBytes(file.size),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _getStatusText(TransferState state) {
    switch (state) {
      case TransferState.connecting:
        return 'Connecting...';
      case TransferState.connected:
        return 'Connected!';
      case TransferState.transferring:
        return 'Receiving Files';
      case TransferState.paused:
        return 'Transfer Paused';
      case TransferState.completed:
        return 'Transfer Complete!';
      case TransferState.failed:
        return 'Transfer Failed';
      default:
        return 'Preparing...';
    }
  }
}
