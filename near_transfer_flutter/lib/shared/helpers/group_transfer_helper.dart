import 'package:file_picker/file_picker.dart';
import '../models/discovered_device.dart';
import '../providers/transfer_orchestrator.dart';
import '../services/group_session_service.dart';
import '../services/webrtc_service.dart';
import '../services/signaling_socket_service.dart';

/// Group transfer helper to coordinate multiple device transfers
class GroupTransferHelper {
  final GroupSessionService groupService;
  final List<TransferOrchestrator> orchestrators = [];

  GroupTransferHelper({required this.groupService});

  /// Start group transfer to multiple devices
  Future<void> startGroupTransfer(
    List<DiscoveredDevice> devices,
    List<PlatformFile> files,
  ) async {
    if (devices.isEmpty) throw ArgumentError('No devices provided');
    if (files.isEmpty) throw ArgumentError('No files provided');

    print('🎯 Starting group transfer to ${devices.length} devices');

    // Create group session
    await groupService.createGroup();

    // Add all devices to session
    for (var device in devices) {
      groupService.addMember(device);
    }

    // Create orchestrator for each device
    for (var device in devices) {
      try {
        final orchestrator = TransferOrchestrator(
          discoveryService: ServiceLocator.discoveryService,
          signalingService: SignalingSocketService(),
          webrtcService: WebRTCService(),
        );

        // Setup progress callback
        orchestrator.onProgress = () {
          groupService.updateDeviceProgress(
            device.id,
            orchestrator.progress,
          );
        };

        // Setup error callback
        orchestrator.onError = (error) {
          groupService.markDeviceAsFailed(device.id, error);
        };

        // Connect and send
        await orchestrator.connectToDevice(device, files);

        orchestrators.add(orchestrator);
        
        groupService.updateDeviceState(
          device.id,
          connectionState: ConnectionState.connected,
        );
        
      } catch (e) {
        print('❌ Failed to send to ${device.name}: $e');
        groupService.markDeviceAsFailed(device.id, e.toString());
      }
    }

    print('✅ Group transfer initiated');
  }

  /// Cleanup all orchestrators
  void dispose() {
    for (var orchestrator in orchestrators) {
      orchestrator.dispose();
    }
    orchestrators.clear();
  }
}

/// Service locator (temporary - replace with proper DI)
class ServiceLocator {
  static late DiscoveryService discoveryService;
}
