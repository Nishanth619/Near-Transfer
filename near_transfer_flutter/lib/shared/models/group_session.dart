import '../../shared/services/webrtc_service.dart';
import '../../shared/services/signaling_socket_service.dart';
import '../../shared/models/discovered_device.dart';

enum ConnectionState {
  idle,
  connecting,
  connected,
  transferring,
  paused,
  completed,
  failed,
  disconnected,
}

enum TransferState {
  idle,
  preparing,
  transferring,
  paused,
  completed,
  failed,
}

class DeviceConnection {
  final String deviceId;
  final String deviceName;
  final String deviceIp;
  
  ConnectionState connectionState;
  TransferState transferState;
  double transferProgress;
  
  // HTTP fallback support
  bool useHttpFallback;
  String? httpDownloadUrl;
  
  // Connection instances
  WebRTCService? webrtcService;
  SignalingSocketService? signalingService;
  
  // Error tracking
  String? lastError;
  DateTime? lastErrorTime;
  
  DeviceConnection({
    required this.deviceId,
    required this.deviceName,
    required this.deviceIp,
    this.connectionState = ConnectionState.idle,
    this.transferState = TransferState.idle,
    this.transferProgress = 0.0,
    this.useHttpFallback = false,
    this.httpDownloadUrl,
    this.webrtcService,
    this.signalingService,
    this.lastError,
    this.lastErrorTime,
  });
  
  /// Create from discovered device
  factory DeviceConnection.fromDevice(DiscoveredDevice device) {
    return DeviceConnection(
      deviceId: device.deviceId,
      deviceName: device.deviceName,
      deviceIp: device.ip,
    );
  }
  
  /// Check if connection is active
  bool get isActive => 
      connectionState == ConnectionState.connected ||
      connectionState == ConnectionState.transferring;
  
  /// Check if transfer is in progress
  bool get isTransferring => 
      transferState == TransferState.transferring ||
      transferState == TransferState.paused;
  
  /// Check if transfer is complete
  bool get isCompleted => transferState == TransferState.completed;
  
  /// Check if transfer failed
  bool get isFailed => 
      transferState == TransferState.failed ||
      connectionState == ConnectionState.failed;
  
  /// Update progress
  void updateProgress(double progress) {
    transferProgress = progress.clamp(0.0, 1.0);
    if (transferProgress >= 1.0) {
      transferState = TransferState.completed;
    }
  }
  
  /// Mark as failed
  void markAsFailed(String error) {
    transferState = TransferState.failed;
    connectionState = ConnectionState.failed;
    lastError = error;
    lastErrorTime = DateTime.now();
  }
  
  /// Cleanup connections
  void dispose() {
    webrtcService?.close();
    signalingService?.close();
  }
  
  @override
  String toString() {
    return 'DeviceConnection($deviceName: $connectionState, $transferState, ${(transferProgress * 100).toStringAsFixed(1)}%)';
  }
}

class GroupSession {
  final String groupId;
  final String hostDeviceId;
  final DateTime createdAt;
  
  final Map<String, DeviceConnection> members;
  
  GroupSession({
    required this.groupId,
    required this.hostDeviceId,
    required this.members,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  
  /// Get active members
  List<DeviceConnection> get activeMembers => 
      members.values.where((m) => m.isActive).toList();
  
  /// Get transferring members
  List<DeviceConnection> get transferringMembers =>
      members.values.where((m) => m.isTransferring).toList();
  
  /// Get completed members
  List<DeviceConnection> get completedMembers =>
      members.values.where((m) => m.isCompleted).toList();
  
  /// Get failed members
  List<DeviceConnection> get failedMembers =>
      members.values.where((m) => m.isFailed).toList();
  
  /// Get overall progress (average of all devices)
  double get overallProgress {
    if (members.isEmpty) return 0.0;
    final totalProgress = members.values
        .map((m) => m.transferProgress)
        .reduce((a, b) => a + b);
    return totalProgress / members.length;
  }
  
  /// Check if all transfers are complete
  bool get isComplete => 
      members.values.every((m) => m.isCompleted || m.isFailed);
  
  /// Get success rate
  double get successRate {
    if (members.isEmpty) return 0.0;
    final completed = completedMembers.length;
    return completed / members.length;
  }
  
  /// Add member to group
  void addMember(DeviceConnection device) {
    members[device.deviceId] = device;
  }
  
  /// Remove member from group
  void removeMember(String deviceId) {
    members[deviceId]?.dispose();
    members.remove(deviceId);
  }
  
  /// Cleanup all connections
  void dispose() {
    for (var member in members.values) {
      member.dispose();
    }
    members.clear();
  }
}
