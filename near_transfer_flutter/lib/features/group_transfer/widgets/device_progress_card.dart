import 'package:flutter/material.dart';

class DeviceProgressCard extends StatelessWidget {
  final String deviceName;
  final String deviceIp;
  final double progress;
  final String status;
  final bool isCompleted;
  final bool isFailed;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onRetry;
  final bool isPaused;

  const DeviceProgressCard({
    super.key,
    required this.deviceName,
    required this.deviceIp,
    required this.progress,
    required this.status,
    this.isCompleted = false,
    this.isFailed = false,
    this.onPause,
    this.onResume,
    this.onRetry,
    this.isPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device info row
            Row(
              children: [
                // Status icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Device name & IP
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        deviceIp,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Action button
                if (isFailed && onRetry != null)
                  IconButton(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Retry',
                    color: Colors.orange,
                  )
                else if (isPaused && onResume != null)
                  IconButton(
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Resume',
                    color: Colors.green,
                  )
                else if (!isCompleted && !isFailed && onPause != null)
                  IconButton(
                    onPressed: onPause,
                    icon: const Icon(Icons.pause),
                    tooltip: 'Pause',
                    color: Colors.orange,
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Progress bar
            if (!isFailed)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation(_getStatusColor()),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              // Error message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    if (isCompleted) return Icons.check_circle;
    if (isFailed) return Icons.error;
    if (isPaused) return Icons.pause_circle;
    return Icons.sync;
  }

  Color _getStatusColor() {
    if (isCompleted) return Colors.green;
    if (isFailed) return Colors.red;
    if (isPaused) return Colors.orange;
    return Colors.blue;
  }
}
