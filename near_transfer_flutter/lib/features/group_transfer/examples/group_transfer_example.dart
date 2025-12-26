import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/discovered_device.dart';
import '../../../shared/services/group_session_service.dart';
import '../../../shared/services/group_http_coordinator.dart';
import '../../../shared/helpers/group_transfer_orchestrator.dart';
import '../screens/device_selection_screen.dart';

/// Example integration showing how to use group transfer
class GroupTransferIntegrationExample extends StatefulWidget {
  final List<DiscoveredDevice> discoveredDevices;
  final List<PlatformFile> filesToSend;

  const GroupTransferIntegrationExample({
    super.key,
    required this.discoveredDevices,
    required this.filesToSend,
  });

  @override
  State<GroupTransferIntegrationExample> createState() =>
      _GroupTransferIntegrationExampleState();
}

class _GroupTransferIntegrationExampleState
    extends State<GroupTransferIntegrationExample> {
  GroupTransferOrchestrator? _orchestrator;

  Future<void> _startGroupTransfer() async {
    // Step 1: Show device selection screen
    final selectedDevices = await Navigator.push<List<DiscoveredDevice>>(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceSelectionScreen(
          devices: widget.discoveredDevices,
          files: widget.filesToSend,
          maxDevices: 5,
        ),
      ),
    );

    if (selectedDevices == null || selectedDevices.isEmpty) {
      return; // User cancelled
    }

    // Step 2: Get services from provider
    final groupService = context.read<GroupSessionService>();
    final httpCoordinator = GroupHttpCoordinator();

    // Step 3: Create orchestrator
    _orchestrator = GroupTransferOrchestrator(
      groupService: groupService,
      httpCoordinator: httpCoordinator,
    );

    try {
      // Step 4: Start transfer
      await _orchestrator!.startGroupTransfer(
        selectedDevices,
        widget.filesToSend,
      );

      // Step 5: Navigate to progress screen
      if (mounted) {
        context.push(
          '/group-progress',
          extra: groupService.currentSession!.groupId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group transfer failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _orchestrator?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group Transfer Example')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _startGroupTransfer,
          icon: const Icon(Icons.send),
          label: const Text('Start Group Transfer'),
        ),
      ),
    );
  }
}

/// Simplified usage function for integration into existing screens
Future<void> startGroupTransferFlow(
  BuildContext context,
  List<DiscoveredDevice> devices,
  List<PlatformFile> files,
) async {
  // 1. Select devices
  final selectedDevices = await Navigator.push<List<DiscoveredDevice>>(
    context,
    MaterialPageRoute(
      builder: (context) => DeviceSelectionScreen(
        devices: devices,
        files: files,
        maxDevices: 5,
      ),
    ),
  );

  if (selectedDevices == null || selectedDevices.isEmpty) return;

  // 2. Setup services
  final groupService = context.read<GroupSessionService>();
  final httpCoordinator = GroupHttpCoordinator();
  final orchestrator = GroupTransferOrchestrator(
    groupService: groupService,
    httpCoordinator: httpCoordinator,
  );

  // 3. Start transfer
  try {
    await orchestrator.startGroupTransfer(selectedDevices, files);

    // 4. Navigate to progress
    if (context.mounted) {
      context.push(
        '/group-progress',
        extra: groupService.currentSession!.groupId,
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transfer failed: $e')),
      );
    }
  }
}
