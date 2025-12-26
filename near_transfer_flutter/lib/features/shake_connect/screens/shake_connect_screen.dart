import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../shared/widgets/help_button.dart';
import '../../../core/constants.dart';
import '../services/shake_detector_service.dart';
import '../widgets/shake_animation_widget.dart';
import '../../../shared/services/discovery_service.dart';
import '../../../shared/services/signaling_socket_service.dart';
import '../../../shared/services/webrtc_service.dart';
import '../../../shared/providers/transfer_orchestrator.dart';
import '../../../shared/models/discovered_device.dart';
import '../../receive/screens/receiving_progress_screen.dart';
import '../../receive/screens/receive_screen.dart';
import '../../../shared/widgets/transfer_dialogs.dart';

class ShakeConnectScreen extends StatefulWidget {
  const ShakeConnectScreen({super.key});

  @override
  State<ShakeConnectScreen> createState() => _ShakeConnectScreenState();
}

class _ShakeConnectScreenState extends State<ShakeConnectScreen> {
  final ShakeDetectorService _shakeDetector = ShakeDetectorService();
  final DiscoveryService _discoveryService = DiscoveryService();
  final SignalingSocketService _signalingService = SignalingSocketService();
  late TransferOrchestrator _orchestrator;
  
  bool _isShaking = false;
  int? _shakeTimestamp;
  int _countdown = 5;
  Timer? _countdownTimer;
  List<DiscoveredDevice> _matchedDevices = [];
  bool _isSearching = false;
  bool _isInitialized = false;
  bool _hasConnected = false; // Track if already connected to prevent double-tap
  bool _isSender = false; // Track if we are the sender

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _startShakeDetection();
  }
  
  // ... (initState and _initializeServices unchanged)


  Future<void> _initializeServices() async {
    try {
      // Get local IP
      final localIp = await _getLocalIp();
      if (localIp == null) {
        throw Exception('Could not determine local IP');
      }

      // Generate device ID and name
      final deviceId = 'shake_${DateTime.now().millisecondsSinceEpoch}';
      final deviceName = 'My Device'; // TODO: Get from settings

      // Initialize orchestrator for receiving (it will start the signaling server)
      final webrtcService = WebRTCService();
      _orchestrator = TransferOrchestrator(
        discoveryService: _discoveryService,
        signalingService: _signalingService,
        webrtcService: webrtcService,
      );

      // Setup callback for incoming connection requests BEFORE starting
      _orchestrator.onConnectionRequest = _handleIncomingConnection;
      _orchestrator.onBusy = _handleBusy;

      // Start orchestrator in receiving mode (this starts the signaling server)
      await _orchestrator.startReceiving(
        deviceId: deviceId,
        deviceName: deviceName,
        deviceIp: localIp,
      );
      
      print('✅ Shake screen ready to receive connections on $localIp');

      // Link signaling service to discovery service for shake mode
      _discoveryService.setSignalingService(_signalingService);

      // Start discovery service IMMEDIATELY so devices can find each other
      await _discoveryService.startDiscovery(deviceName);
      print('✅ Discovery service started, ready to detect shaking devices');

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('❌ Error initializing shake connect: $e');
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
    _shakeDetector.stopListening();
    _countdownTimer?.cancel();
    _discoveryService.disableShakeMode();
    _discoveryService.stopDiscovery();
    _signalingService.close();
    _orchestrator.dispose();
    super.dispose();
  }

  void _handleIncomingConnection(
    String senderName,
    String fileName,
    int fileSize,
    List<Map<String, dynamic>>? files,
    Function() onAccept,
    Function() onDecline,
  ) {
    if (!mounted) return;
    
    // Ignore if we are acting as SENDER
    if (_hasConnected && _isSender) return;
    
    print('🔔 INCOMING CONNECTION from $senderName - File: $fileName');
    
    // Stop shake detection and discovery
    _shakeDetector.stopListening();
    _discoveryService.disableShakeMode();
    _discoveryService.stopDiscovery();
    _countdownTimer?.cancel();
    
    // Mark as connected
    _hasConnected = true;
    _isSender = false;
    
    // Show the connection request dialog using TransferDialogs
    TransferDialogs.showConnectionRequest(
      context: context,
      senderName: senderName,
      fileName: fileName,
      fileSize: fileSize,
      files: files,
      onAccept: () {
        // Accept connection
        onAccept();
        
        // Navigate to progress screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReceivingProgressScreen(
              orchestrator: _orchestrator,
              senderName: senderName,
            ),
          ),
        );
      },
      onDecline: () {
        // Decline connection
        onDecline();
        
        // Go back
        Navigator.pop(context);
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _startShakeDetection() {
    _shakeDetector.onShakeDetected = _onShakeDetected;
    _shakeDetector.startListening();
  }

  void _onShakeDetected() {
    if (_isShaking) return;
    
    final timestamp = _shakeDetector.getShakeTimestamp();
    
    print('🔔 SHAKE DETECTED! Timestamp: $timestamp');
    
    setState(() {
      _isShaking = true;
      _shakeTimestamp = timestamp;
      _countdown = 5;
      _isSearching = true;
    });

    // Enable shake mode in discovery service
    _discoveryService.enableShakeMode(timestamp);
    print('🔍 Searching for shaking devices...');

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
          // Get devices that are shaking and within time window
          _matchedDevices = _discoveryService.shakingDevices;
          
          if (_matchedDevices.isNotEmpty) {
            print('🎯 FOUND ${_matchedDevices.length} SHAKING DEVICE(S):');
            for (var device in _matchedDevices) {
              print('   - ${device.deviceName} @ ${device.ip} (timestamp: ${device.shakeTimestamp})');
            }
          } else {
            print('⏳ Countdown: $_countdown seconds, no matches yet...');
          }
        });
      } else {
        timer.cancel();
        if (_matchedDevices.isEmpty) {
          print('❌ No shaking devices found after 5 seconds');
        }
        _stopSearching();
      }
    });
  }

  Future<void> _startDiscovery() async {
    await _discoveryService.startDiscovery('My Device');
  }

  void _stopSearching() {
    setState(() => _isSearching = false);
    _discoveryService.disableShakeMode();
  }

  void _handleBusy(String senderName) {
    print('🔒 Busy signal received from $senderName');
    if (!mounted || _hasConnected) return;
    
    setState(() {
      _hasConnected = true;
    });

    // Stop shake detection and discovery
    _shakeDetector.stopListening();
    _discoveryService.disableShakeMode();
    _discoveryService.stopDiscovery();
    _countdownTimer?.cancel();
    
    // Show blocking dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Incoming Connection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('$senderName is selecting files...'),
              const SizedBox(height: 8),
              const Text('Please wait.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  void _connectToDevice(DiscoveredDevice device) async {
    if (_hasConnected) return; // Prevent double-tap
    
    setState(() {
      _hasConnected = true;
      _isSender = true;
    });

    // Stop discovery and shake mode
    _discoveryService.disableShakeMode();
    _discoveryService.stopDiscovery();
    _countdownTimer?.cancel();
    
    // Close signaling server since we're acting as sender
    // _signalingService.close(); // Don't close yet, we need it for prepareConnection!
    // Actually, prepareConnection uses _signalingService to connect.
    // If we close it, we can't connect? 
    // SignalingSocketService.close() closes both server and client sockets.
    // We want to keep client capability but stop server?
    // But connectToDevice creates a NEW client socket.
    // So closing server is fine, BUT we need the service instance to be valid.
    
    try {
      // 1. Lock the receiver immediately
      await _orchestrator.prepareConnection(device);
      
      // 2. Close server now that we are connected as client
      // _signalingService.close(); // orchestrator needs it!
      // The orchestrator manages the service. We shouldn't close it manually if orchestrator uses it.
      
      // 3. Navigate to discovery/send screen
      if (mounted) {
        context.push('/discovery', extra: {
          'device': device,
          'orchestrator': _orchestrator,
        });
      }
    } catch (e) {
      print('Failed to prepare connection: $e');
      setState(() {
        _hasConnected = false;
      });
      // Resume discovery?
      _startDiscovery();
    }
  }

  void _reset() {
    setState(() {
      _isShaking = false;
      _shakeTimestamp = null;
      _countdown = 5;
      _matchedDevices.clear();
      _isSearching = false;
    });
    _countdownTimer?.cancel();
    _discoveryService.disableShakeMode();
    _discoveryService.stopDiscovery();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Shake to Connect',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: const [
          HelpButton(
            featureName: 'Shake to Connect',
            helpText: 'Quickly connect with nearby devices by shaking.\n\n• Both devices must shake at the same time\n• After shaking, matching devices appear\n• Tap a device to start sending files\n• 5 second window to find matches',
          ),
        ],
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                           MediaQuery.of(context).padding.top - 
                           kToolbarHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 40),
                    ShakeAnimationWidget(
                      isShaking: _isShaking,
                      size: 150,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _isShaking ? 'Searching for devices...' : 'Shake your phone!',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_isSearching)
                      Text(
                        '$_countdown seconds left',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      )
                    else
                      const Text(
                        'Shake to find nearby devices',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 40),
                    if (_matchedDevices.isNotEmpty)
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Found ${_matchedDevices.length} shaking device${_matchedDevices.length > 1 ? 's' : ''}!',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Flexible(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _matchedDevices.length,
                                itemBuilder: (context, index) {
                                  final device = _matchedDevices[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.phone_android,
                                        color: Color(0xFF6C63FF),
                                      ),
                                      title: Text(device.deviceName),
                                      subtitle: Text(device.ip),
                                      trailing: const Icon(Icons.arrow_forward),
                                      onTap: () => _connectToDevice(device),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 40),
                    if (_isShaking || _matchedDevices.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _reset,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Try Again',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
