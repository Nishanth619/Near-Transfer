import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../shared/models/discovered_device.dart';
import '../../../shared/services/group_session_service.dart';
import '../../../shared/services/group_http_coordinator.dart';
import '../../../shared/helpers/group_transfer_orchestrator.dart';
import '../../../core/constants.dart';

class DeviceSelectionScreen extends StatefulWidget {
  final List<DiscoveredDevice> devices;
  final List<PlatformFile> files;
  final int maxDevices;

  const DeviceSelectionScreen({
    super.key,
    required this.devices,
    required this.files,
    this.maxDevices = 5,
  });

  @override
  State<DeviceSelectionScreen> createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends State<DeviceSelectionScreen> {
  final Set<String> _selectedDeviceIds = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canSelectMore = _selectedDeviceIds.length < widget.maxDevices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Devices'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        actions: [
          if (_selectedDeviceIds.isNotEmpty)
            TextButton(
              onPressed: _selectedDeviceIds.isEmpty ? null : _startGroupTransfer,
              child: Text(
                'Send (${_selectedDeviceIds.length})',
                style: TextStyle(
                  color: _selectedDeviceIds.isEmpty 
                      ? Colors.grey 
                      : Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark 
                ? const Color(0xFF2C2C2C) 
                : AppColors.surfaceAlt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select up to ${widget.maxDevices} devices to send ${widget.files.length} file(s) simultaneously',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _selectedDeviceIds.length / widget.maxDevices,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation(
                    _selectedDeviceIds.length >= widget.maxDevices
                        ? Colors.orange
                        : Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_selectedDeviceIds.length} / ${widget.maxDevices} selected',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Device list
          Expanded(
            child: widget.devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.devices_other,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No devices found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Make sure devices are on the same network',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.devices.length,
                    itemBuilder: (context, index) {
                      final device = widget.devices[index];
                      final isSelected = _selectedDeviceIds.contains(device.deviceId);
                      final canSelect = canSelectMore || isSelected;

                      return _buildDeviceCard(
                        device,
                        isSelected,
                        canSelect,
                        isDark,
                      );
                    },
                  ),
          ),

          // Bottom action bar
          if (_selectedDeviceIds.isNotEmpty)
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
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedDeviceIds.clear()),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _startGroupTransfer,
                    icon: const Icon(Icons.send),
                    label: Text('Send to ${_selectedDeviceIds.length} devices'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(
    DiscoveredDevice device,
    bool isSelected,
    bool canSelect,
    bool isDark,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      color: isSelected
          ? (isDark ? const Color(0xFF2C2C2C) : AppColors.primary.withOpacity(0.1))
          : null,
      child: CheckboxListTile(
        value: isSelected,
        onChanged: canSelect
            ? (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedDeviceIds.add(device.deviceId);
                  } else {
                    _selectedDeviceIds.remove(device.deviceId);
                  }
                });
              }
            : null,
        title: Text(
          device.deviceName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          device.ip,
          style: const TextStyle(fontSize: 12),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor
                : (isDark ? const Color(0xFF2C2C2C) : AppColors.surfaceAlt),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.phone_android,
            color: isSelected ? Colors.white : Theme.of(context).primaryColor,
          ),
        ),
        controlAffinity: ListTileControlAffinity.trailing,
        enabled: canSelect,
      ),
    );
  }

  Future<void> _startGroupTransfer() async {
    if (_selectedDeviceIds.isEmpty) return;

    // Get selected devices
    final selectedDevices = widget.devices
        .where((d) => _selectedDeviceIds.contains(d.deviceId))
        .toList();

    if (!mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Get services
      final groupService = context.read<GroupSessionService>();
      final httpCoordinator = GroupHttpCoordinator();

      // Create orchestrator
      final orchestrator = GroupTransferOrchestrator(
        groupService: groupService,
        httpCoordinator: httpCoordinator,
      );

      // Start transfer
      await orchestrator.startGroupTransfer(selectedDevices, widget.files);

      // Close loading
      if (mounted) Navigator.pop(context);

      // Navigate to progress screen
      if (mounted) {
        context.push(
          '/group-progress',
          extra: groupService.currentSession!.groupId,
        );
      }
    } catch (e) {
      // Close loading
      if (mounted) Navigator.pop(context);

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start group transfer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
