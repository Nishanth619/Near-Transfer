import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../core/constants.dart';
import '../services/shake_detector_service.dart';
import '../widgets/shake_animation_widget.dart';
import '../../../shared/services/discovery_service.dart';
import '../../../shared/models/discovered_device.dart';

class ShakeConnectScreen extends StatefulWidget {
  const ShakeConnectScreen({super.key});

  @override
  State<ShakeConnectScreen> createState() => _ShakeConnectScreenState();
}

class _ShakeConnectScreenState extends State<ShakeConnectScreen> {
  final ShakeDetectorService _shakeDetector = ShakeDetectorService();
  final DiscoveryService _discoveryService = DiscoveryService();
  
  bool _isShaking = false;
  int? _shakeTimestamp;
  int _countdown = 5;
  Timer? _countdownTimer;
  List<DiscoveredDevice> _matchedDevices = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _startShakeDetection();
  }

  @override
  void dispose() {
    _shakeDetector.stopListening();
    _countdownTimer?.cancel();
    _discoveryService.disableShakeMode();
    _discoveryService.stopDiscovery();
    super.dispose();
  }

  void _startShakeDetection() {
    _shakeDetector.onShakeDetected = _onShakeDetected;
    _shakeDetector.startListening();
  }

  void _onShakeDetected() {
    if (_isShaking) return;
    
    final timestamp = _shakeDetector.getShakeTimestamp();
    
    setState(() {
      _isShaking = true;
      _shakeTimestamp = timestamp;
      _countdown = 5;
      _isSearching = true;
    });

    // Enable shake mode in discovery service
    _discoveryService.enableShakeMode(timestamp);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
          // Get devices that are shaking and within time window
          _matchedDevices = _discoveryService.shakingDevices;
        });
      } else {
        timer.cancel();
        _stopSearching();
      }
    });

    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    await _discoveryService.startDiscovery('My Device');
  }

  void _stopSearching() {
    setState(() => _isSearching = false);
    _discoveryService.disableShakeMode();
  }

  void _connectToDevice(DiscoveredDevice device) {
    // Stop discovery and navigate to file picker
    _discoveryService.disableShakeMode();
    _discoveryService.stopDiscovery();
    context.push('/discovery');
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
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
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
                  Expanded(
                    child: Container(
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
                          Expanded(
                            child: ListView.builder(
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
                  ),
                const Spacer(),
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
    );
  }
}
