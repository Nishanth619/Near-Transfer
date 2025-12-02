import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/network_config.dart';
import '../models/discovered_device.dart';

class DiscoveryService extends ChangeNotifier {
  RawDatagramSocket? _socket;
  Timer? _beaconTimer;
  Timer? _cleanupTimer;
  Timer? _tcpScanTimer;
  
  final String _deviceId = const Uuid().v4();
  String _deviceName = '';
  String? _localIp;
  
  final Map<String, DiscoveredDevice> _discoveredDevices = {};
  
  bool _isRunning = false;
  bool get isRunning => _isRunning;
  
  String? get localIp => _localIp;
  
  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices.values.toList()
    ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

  // Shake mode state
  bool _isShakeMode = false;
  int? _shakeTimestamp;
  
  bool get isShakeMode => _isShakeMode;
  int? get shakeTimestamp => _shakeTimestamp;

  /// Enable shake mode with timestamp
  void enableShakeMode(int timestamp) {
    _isShakeMode = true;
    _shakeTimestamp = timestamp;
    print('🤝 Shake mode enabled with timestamp: $timestamp');
    notifyListeners();
  }

  /// Disable shake mode
  void disableShakeMode() {
    _isShakeMode = false;
    _shakeTimestamp = null;
    print('🤝 Shake mode disabled');
    notifyListeners();
  }

  /// Get devices that are in shake mode and match time window
  List<DiscoveredDevice> get shakingDevices {
    if (!_isShakeMode || _shakeTimestamp == null) return [];
    
    const matchWindow = 3000; // 3 seconds
    return _discoveredDevices.values.where((device) {
        if (!device.isShaking || device.shakeTimestamp == null) return false;
        final timeDiff = (_shakeTimestamp! - device.shakeTimestamp!).abs();
        return timeDiff < matchWindow;
      }).toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
  }



  Future<void> startDiscovery(String deviceName) async {
    if (_isRunning) return;
    
    _deviceName = deviceName;
    
    try {
      // Get local IP
      _localIp = await _getLocalIp();
      if (_localIp == null) {
        throw Exception('Could not determine local IP address');
      }
      
      print('Starting discovery on $_localIp');
      
      // Try UDP multicast first
      try {
        await _startUdpDiscovery();
      } catch (e) {
        print('UDP multicast failed (hotspot?): $e');
      }
      
      // Also start TCP broadcast discovery (works on hotspots)
      _startTcpBroadcastDiscovery();
      
      // Start cleanup timer
      _startCleanupTimer();
      
      _isRunning = true;
      notifyListeners();
      
      print('Discovery service started');
    } catch (e) {
      print('Error starting discovery: $e');
      rethrow;
    }
  }

  Future<void> _startUdpDiscovery() async {
    // Create UDP socket for multicast
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      NetworkConfig.multicastPort,
    );
    
    // Join multicast group
    _socket!.joinMulticast(
      InternetAddress(NetworkConfig.multicastGroup),
    );
    
    // Enable broadcast
    _socket!.broadcastEnabled = true;
    
    // Listen for incoming beacons
    _socket!.listen(_handleIncomingBeacon);
    
    // Start broadcasting beacons
    _startBeaconBroadcast();
  }

  void _startTcpBroadcastDiscovery() {
    // Scan local subnet every 5 seconds
    _tcpScanTimer?.cancel();
    _tcpScanTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _scanLocalSubnet();
    });
    
    // Initial scan
    _scanLocalSubnet();
  }

  Future<void> _scanLocalSubnet() async {
    if (_localIp == null) return;
    
    // Get subnet (e.g., 192.168.43.x for hotspot)
    final parts = _localIp!.split('.');
    if (parts.length != 4) return;
    
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
    
    print('📡 Scanning subnet: $subnet.1-254');
    
    // Scan entire subnet (1-254) to find all devices
    for (int i = 1; i <= 254; i++) {
      final ip = '$subnet.$i';
      if (ip == _localIp) continue; // Skip self
      
      _probeTcpDevice(ip);
    }
  }

  Future<void> _probeTcpDevice(String ip) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        ip,
        NetworkConfig.tcpPort,
        timeout: const Duration(milliseconds: 500),
      );
      
      print('🔗 Connected to $ip! Sending probe...');
      
      // Send discovery probe
      final probe = {
        'type': 'discovery_probe',
        'deviceId': _deviceId,
        'deviceName': _deviceName,
        'ip': _localIp,
        'port': NetworkConfig.tcpPort,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      socket.add(utf8.encode(jsonEncode(probe) + '\n'));
      await socket.flush();
      
      print('📤 Probe sent to $ip, waiting for response...');
      
      bool responseReceived = false;
      String buffer = '';
      
      // Listen for response with timeout
      final responseTimeout = Timer(const Duration(seconds: 1), () {
        if (!responseReceived) {
          print('⏱️ Response timeout for $ip');
          socket?.destroy();
        }
      });
      
      socket.listen(
        (data) {
          if (responseReceived) return;
          
          try {
            buffer += utf8.decode(data);
            
            // Process complete messages (delimited by newlines)
            if (buffer.contains('\n')) {
              final newlineIndex = buffer.indexOf('\n');
              final message = buffer.substring(0, newlineIndex);
              
              final json = jsonDecode(message) as Map<String, dynamic>;
            
              print('📥 Response from $ip: ${json['type']}');
              
              if (json['type'] == 'discovery_response') {
                responseReceived = true;
                responseTimeout.cancel();
                
                final device = DiscoveredDevice.fromJson(json);
                
                // Add discovered device
                final existingDevice = _discoveredDevices[device.deviceId];
                if (existingDevice != null) {
                  _discoveredDevices[device.deviceId] = existingDevice.copyWith(
                    lastSeen: device.lastSeen,
                  );
                } else {
                  _discoveredDevices[device.deviceId] = device;
                  print('✅ DISCOVERED: ${device.deviceName} @ ${device.ip}');
                }
                
                notifyListeners();
                
                // Close connection after receiving response
                socket?.destroy();
              }
            }
          } catch (e) {
            print('❌ Error parsing response from $ip: $e');
          }
        },
        onDone: () {
          responseTimeout.cancel();
        },
        onError: (e) {
          responseTimeout.cancel();
          socket?.destroy();
        },
      );
    } catch (e) {
      // Device not reachable, ignore (don't log to avoid spam)
      socket?.destroy();
    }
  }

  void stopDiscovery() {
    _beaconTimer?.cancel();
    _cleanupTimer?.cancel();
    _tcpScanTimer?.cancel();
    _socket?.close();
    _discoveredDevices.clear();
    _isRunning = false;
    notifyListeners();
    print('Discovery service stopped');
  }

  void _startBeaconBroadcast() {
    _beaconTimer?.cancel();
    
    // Send initial beacon immediately
    _sendBeacon();
    
    // Then send periodically
    _beaconTimer = Timer.periodic(NetworkConfig.beaconInterval, (_) {
      _sendBeacon();
    });
  }

  void _sendBeacon() {
    if (_socket == null || _localIp == null) return;
    
    final beacon = DiscoveredDevice(
      deviceId: _deviceId,
      deviceName: _deviceName,
      ip: _localIp!,
      port: NetworkConfig.tcpPort,
      lastSeen: DateTime.now(),
      isShaking: _isShakeMode,
      shakeTimestamp: _shakeTimestamp,
    );
    
    final message = jsonEncode(beacon.toJson());
    final data = utf8.encode(message);
    
    try {
      _socket!.send(
        data,
        InternetAddress(NetworkConfig.multicastGroup),
        NetworkConfig.multicastPort,
      );
      print('Sent beacon: $_deviceName @ $_localIp ${_isShakeMode ? "🤝 SHAKING" : ""}');
    } catch (e) {
      print('Error sending beacon: $e');
    }
  }

  void _handleIncomingBeacon(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket!.receive();
      if (datagram == null) return;
      
      try {
        final message = utf8.decode(datagram.data);
        final json = jsonDecode(message) as Map<String, dynamic>;
        
        // Ignore our own beacons
        if (json['deviceId'] == _deviceId) return;
        
        final device = DiscoveredDevice.fromJson(json);
        
        // Update or add device with shake info
        final existingDevice = _discoveredDevices[device.deviceId];
        if (existingDevice != null) {
          _discoveredDevices[device.deviceId] = existingDevice.copyWith(
            lastSeen: device.lastSeen,
            isShaking: device.isShaking,
            shakeTimestamp: device.shakeTimestamp,
          );
        } else {
          _discoveredDevices[device.deviceId] = device;
          print('Discovered new device: ${device.deviceName} @ ${device.ip} ${device.isShaking ? "🤝" : ""}');
        }
        
        notifyListeners();
      } catch (e) {
        print('Error parsing beacon: $e');
      }
    }
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _cleanupStaleDevices();
    });
  }

  void _cleanupStaleDevices() {
    final now = DateTime.now();
    final staleDevices = <String>[];
    
    _discoveredDevices.forEach((id, device) {
      if (now.difference(device.lastSeen) > NetworkConfig.deviceTimeout) {
        staleDevices.add(id);
      }
    });
    
    if (staleDevices.isNotEmpty) {
      for (final id in staleDevices) {
        final device = _discoveredDevices.remove(id);
        print('Removed stale device: ${device?.deviceName}');
      }
      notifyListeners();
    }
  }

  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          // Look for private IP addresses
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            return ip;
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting local IP: $e');
      return null;
    }
  }

  @override
  void dispose() {
    stopDiscovery();
    super.dispose();
  }
}
