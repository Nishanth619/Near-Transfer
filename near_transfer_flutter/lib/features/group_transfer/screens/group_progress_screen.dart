import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/services/group_session_service.dart';
import '../widgets/device_progress_card.dart';
import '../../../core/constants.dart';
import '../../../shared/models/group_session.dart' as group_models;

class GroupProgressScreen extends StatefulWidget {
  final String groupId;

  const GroupProgressScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupProgressScreen> createState() => _GroupProgressScreenState();
}

class _GroupProgressScreenState extends State<GroupProgressScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<GroupSessionService>(
      builder: (context, groupService, child) {
        final session = groupService.currentSession;
        if (session == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Group Transfer'),
            ),
            body: const Center(
              child: Text('No active group session'),
            ),
          );
        }

        final members = groupService.getMembers();
        final stats = groupService.getTransferStats();
        final overallProgress = groupService.groupProgress;
        final isComplete = groupService.isGroupTransferComplete;

        return PopScope(
          canPop: isComplete,
          onPopInvokedWithResult: (didPop, result) async {
            if (!didPop && !isComplete) {
              _showCancelDialog(context);
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Group Transfer'),
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              actions: [
                if (!isComplete)
                  IconButton(
                    onPressed: () => _showCancelDialog(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel Transfer',
                  ),
              ],
            ),
            body: Column(
              children: [
                // Overall progress header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isComplete
                          ? [Colors.green.shade400, Colors.green.shade600]
                          : [AppColors.primary, AppColors.accentStart],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Total',
                            stats['total'].toString(),
                            Icons.devices,
                          ),
                          _buildStatItem(
                            'Completed',
                            stats['completed'].toString(),
                            Icons.check_circle,
                          ),
                          _buildStatItem(
                            'Failed',
                            stats['failed'].toString(),
                            Icons.error,
                          ),
                          _buildStatItem(
                            'Active',
                            stats['active'].toString(),
                            Icons.sync,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Overall progress bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Overall Progress',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: overallProgress,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${(overallProgress * 100).toStringAsFixed(1)}% Complete',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Device list
                Expanded(
                  child: members.isEmpty
                      ? const Center(child: Text('No devices in group'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final device = members[index];
                            return DeviceProgressCard(
                              deviceName: device.deviceName,
                              deviceIp: device.deviceIp,
                              progress: device.transferProgress,
                              status: _getStatusText(device),
                              isCompleted: device.isCompleted,
                              isFailed: device.isFailed,
                              isPaused: device.transferState == group_models.TransferState.paused,
                              onPause: device.isTransferring && !device.isFailed
                                  ? () => _pauseDevice(groupService, device.deviceId)
                                  : null,
                              onResume: device.transferState == group_models.TransferState.paused
                                  ? () => _resumeDevice(groupService, device.deviceId)
                                  : null,
                              onRetry: device.isFailed
                                  ? () => _retryDevice(groupService, device.deviceId)
                                  : null,
                            );
                          },
                        ),
                ),

                // Bottom action bar
                if (isComplete)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          groupService.endSession();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _getStatusText(group_models.DeviceConnection device) {
    if (device.isCompleted) return 'Transfer complete';
    if (device.isFailed) return device.lastError ?? 'Transfer failed';
    if (device.transferState == group_models.TransferState.paused) return 'Paused';
    if (device.connectionState == group_models.ConnectionState.connecting) {
      return 'Connecting...';
    }
    if (device.isTransferring) {
      if (device.useHttpFallback) {
        return 'Transferring via HTTP...';
      }
      return 'Transferring...';
    }
    return 'Waiting...';
  }

  void _pauseDevice(GroupSessionService service, String deviceId) {
    // TODO: Implement pause for specific device
    print('Pausing device: $deviceId');
  }

  void _resumeDevice(GroupSessionService service, String deviceId) {
    // TODO: Implement resume for specific device
    print('Resuming device: $deviceId');
  }

  void _retryDevice(GroupSessionService service, String deviceId) {
    // TODO: Implement retry for specific device
    print('Retrying device: $deviceId');
  }

  Future<bool?> _showCancelDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Group Transfer?'),
        content: const Text(
          'This will stop the transfer to all devices. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Transfer'),
          ),
          TextButton(
            onPressed: () {
              final service = context.read<GroupSessionService>();
              service.endSession();
              Navigator.pop(context, true);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Transfer'),
          ),
        ],
      ),
    );
  }
}
