import 'package:flutter/material.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../core/constants.dart';
import '../../../shared/providers/transfer_orchestrator.dart';

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

    return WillPopScope(
      onWillPop: () async => state == TransferState.completed || state == TransferState.failed,
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
                  
                  // File counter
                  if (widget.orchestrator.totalFiles > 0)
                    Text(
                      'File ${widget.orchestrator.currentFileIndex + 1} of ${widget.orchestrator.totalFiles}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Linear progress bar
                  if (state == TransferState.transferring)
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // File list
                  if (widget.orchestrator.totalFiles > 0)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
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
                ],
              ),
            ),
          ),
        ),
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
        color: color.withOpacity(0.2),
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
    IconData statusIcon;
    Color statusColor;
    
    if (index < currentIndex || (index == currentIndex && state == TransferState.completed)) {
      status = 'completed';
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
    } else if (index == currentIndex && state == TransferState.transferring) {
      status = 'transferring';
      statusIcon = Icons.sync;
      statusColor = Colors.blue;
    } else {
      status = 'pending';
      statusIcon = Icons.schedule;
      statusColor = Colors.white54;
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status == 'transferring' 
            ? Colors.white.withOpacity(0.15) 
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Status icon
          status == 'transferring'
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                )
              : Icon(
                  statusIcon,
                  size: 20,
                  color: statusColor,
                ),
          
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
                    color: Colors.white.withOpacity(0.6),
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
      case TransferState.completed:
        return 'Transfer Complete!';
      case TransferState.failed:
        return 'Transfer Failed';
      default:
        return 'Preparing...';
    }
  }
}
