import 'package:flutter/material.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../shared/widgets/circular_progress.dart';
import '../../../core/constants.dart';
import '../../../shared/providers/transfer_orchestrator.dart';
import '../../../shared/utils/file_icon_utils.dart';

class SendingProgressScreen extends StatefulWidget {
  final TransferOrchestrator orchestrator;
  final String fileName;

  const SendingProgressScreen({
    super.key,
    required this.orchestrator,
    required this.fileName,
  });

  @override
  State<SendingProgressScreen> createState() => _SendingProgressScreenState();
}

class _SendingProgressScreenState extends State<SendingProgressScreen> {
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
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.orchestrator.state;
    final progress = widget.orchestrator.progress;
    
    // Desktop responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final maxContentWidth = isDesktop ? 800.0 : double.infinity;
    final horizontalPadding = isDesktop ? 40.0 : 24.0;
    final progressSize = isDesktop ? 180.0 : 140.0;
    final titleFontSize = isDesktop ? 26.0 : 22.0;
    final statusIconSize = isDesktop ? 80.0 : 60.0;
    final statusIconIconSize = isDesktop ? 44.0 : 32.0;

    return PopScope(
      canPop: state == TransferState.completed || state == TransferState.failed || state == TransferState.paused,
      child: Scaffold(
        body: AnimatedBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Padding(
                  padding: EdgeInsets.all(horizontalPadding),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      
                      // Compact status icon
                      Container(
                        width: statusIconSize,
                        height: statusIconSize,
                        decoration: BoxDecoration(
                          color: _getStatusColor(state).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getStatusIcon(state),
                          size: statusIconIconSize,
                          color: Colors.white,
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Status text
                      Text(
                        _getStatusText(state),
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // File counter
                      if (widget.orchestrator.totalFiles > 0)
                        Text(
                          'File ${widget.orchestrator.currentFileIndex + 1} of ${widget.orchestrator.totalFiles}',
                          style: TextStyle(
                            fontSize: isDesktop ? 15.0 : 13.0,
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
                              size: progressSize,
                              progressColor: state == TransferState.paused 
                                  ? Colors.orange 
                                  : Colors.green,
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
                  
                  // File list
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
                    ],  // Column children
                  ),  // Column
                ),  // Padding child
              ),  // ConstrainedBox child
            ),  // Center child
          ),  // SafeArea child
        ),  // AnimatedBackground child
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
      icon = Icons.upload;
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
    bool showSpinner = false; // Only show spinner when actively transferring
    
    if (index < currentIndex || (index == currentIndex && state == TransferState.completed)) {
      status = 'completed';
    } else if (index == currentIndex && state == TransferState.paused) {
      status = 'paused';
    } else if (index == currentIndex && state == TransferState.transferring) {
      status = 'transferring';
      showSpinner = true;
    } else {
      status = 'pending';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status == 'transferring' || status == 'paused'
            ? Colors.white.withValues(alpha: 0.15) 
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: status == 'paused' 
            ? Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1)
            : null,
      ),
      child: Row(
        children: [
          // File type icon or status icon
          if (showSpinner)
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
          
          // Show pause indicator for current file when paused
          if (status == 'paused')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PAUSED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
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
    final progress = widget.orchestrator.progress;
    
    switch (state) {
      case TransferState.connecting:
        return 'Connecting...';
      case TransferState.connected:
        return 'Connected!';
      case TransferState.transferring:
        if (progress == 0.0) {
          return 'Loading File...';
        }
        return 'Sending Files';
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
  
  Color _getStatusColor(TransferState state) {
    if (state == TransferState.completed) {
      return Colors.green;
    } else if (state == TransferState.failed) {
      return Colors.red;
    } else {
      return AppColors.primary;
    }
  }
  
  IconData _getStatusIcon(TransferState state) {
    if (state == TransferState.completed) {
      return Icons.check_circle;
    } else if (state == TransferState.failed) {
      return Icons.error;
    } else {
      return Icons.upload;
    }
  }
}
