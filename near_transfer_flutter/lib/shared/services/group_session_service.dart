import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../shared/models/discovered_device.dart';
import '../models/group_session.dart';
import '../../shared/services/signaling_socket_service.dart';

class GroupSessionService extends ChangeNotifier {
  GroupSession? _currentSession;
  bool _isHost = false;
  
  GroupSession? get currentSession => _currentSession;
  bool get isHost => _isHost;
  bool get hasActiveSession => _currentSession != null;
  
  /// Create a new group session and become host
  Future<String> createGroup() async {
    final groupId = const Uuid().v4();
    
    _currentSession = GroupSession(
      groupId: groupId,
      hostDeviceId: 'host_${DateTime.now().millisecondsSinceEpoch}',
      members: {},
    );
    
    _isHost = true;
    notifyListeners();
    
    return groupId;
  }
  
  /// Add a device to the current group
  void addMember(DiscoveredDevice device) {
    if (_currentSession == null) {
      throw StateError('No active group session');
    }
    
    final connection = DeviceConnection.fromDevice(device);
    _currentSession!.addMember(connection);
    
    notifyListeners();
  }
  
  /// Remove a device from the current group
  void removeMember(String deviceId) {
    if (_currentSession == null) return;
    
    _currentSession!.removeMember(deviceId);
    
    notifyListeners();
  }
  
  /// Get a specific device connection
  DeviceConnection? getMember(String deviceId) {
    return _currentSession?.members[deviceId];
  }
  
  /// Get all group members
  List<DeviceConnection> getMembers() {
    return _currentSession?.members.values.toList() ?? [];
  }
  
  /// Get active members count
  int get activeMembersCount => 
      _currentSession?.activeMembers.length ?? 0;
  
  /// Update device progress
  void updateDeviceProgress(String deviceId, double progress) {
    final device = getMember(deviceId);
    if (device != null) {
      device.updateProgress(progress);
      notifyListeners();
    }
  }
  
  /// Update device connection state
  void updateDeviceState(
    String deviceId, {
    ConnectionState? connectionState,
    TransferState? transferState,
  }) {
    final device = getMember(deviceId);
    if (device == null) return;
    
    if (connectionState != null) {
      device.connectionState = connectionState;
    }
    if (transferState != null) {
      device.transferState = transferState;
    }
    
    notifyListeners();
  }
  
  /// Mark device as failed
  void markDeviceAsFailed(String deviceId, String error) {
    final device = getMember(deviceId);
    if (device != null) {
      device.markAsFailed(error);
      notifyListeners();
    }
  }
  
  /// Broadcast signaling message to all group members
  Future<void> broadcastToGroup(
    SignalingMessage message,
    {List<String>? excludeDevices}
  ) async {
    final members = getMembers();
    final exclude = excludeDevices ?? [];
    
    for (var member in members) {
      if (exclude.contains(member.deviceId)) continue;
      
      try {
        await member.signalingService?.sendMessage(message);
      } catch (e) {
      }
    }
  }
  
  /// Get overall group progress
  double get groupProgress => _currentSession?.overallProgress ?? 0.0;
  
  /// Check if all transfers are complete
  bool get isGroupTransferComplete => 
      _currentSession?.isComplete ?? false;
  
  /// Get transfer statistics
  Map<String, int> getTransferStats() {
    final session = _currentSession;
    if (session == null) {
      return {
        'total': 0,
        'completed': 0,
        'failed': 0,
        'active': 0,
      };
    }
    
    return {
      'total': session.members.length,
      'completed': session.completedMembers.length,
      'failed': session.failedMembers.length,
      'active': session.transferringMembers.length,
    };
  }
  
  /// End the current group session
  void endSession() {
    if (_currentSession == null) return;
    
    
    _currentSession!.dispose();
    _currentSession = null;
    _isHost = false;
    
    notifyListeners();
  }
  
  @override
  void dispose() {
    endSession();
    super.dispose();
  }
}
