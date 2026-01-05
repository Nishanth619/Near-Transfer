import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../shared/widgets/animated_background.dart';
import '../../../shared/widgets/help_button.dart';
import '../../../shared/widgets/banner_ad_widget.dart';
import '../../../core/constants.dart';
import '../../../shared/services/network_speed_service.dart';
import '../../../shared/services/discovery_service.dart';
import '../../../shared/models/discovered_device.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen>
    with SingleTickerProviderStateMixin {
  final NetworkSpeedService _speedService = NetworkSpeedService();
  final DiscoveryService _discoveryService = DiscoveryService();
  
  late AnimationController _gaugeController;
  bool _isTesting = false;
  double _progress = 0.0;
  String _status = 'Ready';
  SpeedTestResult? _result;
  DiscoveredDevice? _selectedDevice;
  List<DiscoveredDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _gaugeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _discoverDevices();
  }

  @override
  void dispose() {
    _gaugeController.dispose();
    _discoveryService.stopDiscovery();
    super.dispose();
  }

  Future<void> _discoverDevices() async {
    try {
      await _discoveryService.startDiscovery('Speed Test');
      _discoveryService.addListener(_updateDevices);
    } catch (e) {
      // Ignore discovery errors
    }
  }

  void _updateDevices() {
    final newDevices = _discoveryService.discoveredDevices;
    setState(() {
      _devices = newDevices;
      // Ensure selected device is in the list, otherwise reset
      if (_selectedDevice != null) {
        final found = _devices.any((d) => d.deviceId == _selectedDevice!.deviceId);
        if (!found) {
          _selectedDevice = _devices.isNotEmpty ? _devices.first : null;
        }
      } else if (_devices.isNotEmpty) {
        _selectedDevice = _devices.first;
      }
    });
  }

  Future<void> _startSpeedTest() async {
    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a device first')),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _progress = 0.0;
      _status = 'Starting...';
      _result = null;
    });

    _gaugeController.repeat();

    try {
      final result = await _speedService.runSpeedTest(
        targetIp: _selectedDevice!.ip,
        port: _selectedDevice!.port,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _status = status;
            });
          }
        },
      );

      setState(() {
        _result = result;
        _isTesting = false;
      });
      
      _gaugeController.stop();
    } catch (e) {
      setState(() {
        _isTesting = false;
        _status = 'Test failed: $e';
      });
      _gaugeController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text('Speed Test', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          HelpButton(
            featureName: 'Speed Test',
            helpText: 'Test transfer speed with nearby devices.\n\n• Measures download and upload speeds\n• Shows network latency\n• Helps optimize file transfers\n• Requires another device running the app',
          ),
        ],
      ),
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Device selector
                  _buildDeviceSelector(),
                  const SizedBox(height: 24),
                  
                  // Speed gauge
                  _buildSpeedGauge(),
                  const SizedBox(height: 24),
                  
                  // Status text
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Results (if available)
                  if (_result != null) _buildResults(),
                  
                  const SizedBox(height: 32),
                  
                  // Start button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isTesting ? null : _startSpeedTest,
                      icon: Icon(_isTesting ? Icons.hourglass_empty : Icons.speed),
                      label: Text(_isTesting ? 'Testing...' : 'Start Test'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: const BannerAdWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSelector() {
    // Find the selected device from the current list (by deviceId)
    DiscoveredDevice? currentSelection;
    if (_selectedDevice != null && _devices.isNotEmpty) {
      currentSelection = _devices.cast<DiscoveredDevice?>().firstWhere(
        (d) => d?.deviceId == _selectedDevice!.deviceId,
        orElse: () => null,
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Connection To',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          if (_devices.isEmpty)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Searching for nearby devices...',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            )
          else
            DropdownButtonFormField<DiscoveredDevice>(
              value: currentSelection,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _devices.map((device) {
                return DropdownMenuItem<DiscoveredDevice>(
                  value: device,
                  child: Row(
                    children: [
                      const Icon(Icons.phone_android, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          device.deviceName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (device) {
                setState(() => _selectedDevice = device);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedGauge() {
    return SizedBox(
      height: 200,
      width: 200,
      child: AnimatedBuilder(
        animation: _gaugeController,
        builder: (context, child) {
          return CustomPaint(
            painter: SpeedGaugePainter(
              progress: _result != null ? 1.0 : _progress,
              speed: _result?.downloadSpeed ?? 0,
              isAnimating: _isTesting,
              animationValue: _gaugeController.value,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _result != null
                        ? _result!.downloadSpeed.toStringAsFixed(1)
                        : '--',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Text(
                    'Mbps',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    if (_result == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Quality indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _getQualityColor(_result!.quality).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _result!.quality.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Text(
                  _result!.quality.label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getQualityColor(_result!.quality),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Speed metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric(
                icon: Icons.download,
                label: 'Download',
                value: '${_result!.downloadSpeed.toStringAsFixed(1)} Mbps',
                color: Colors.green,
              ),
              _buildMetric(
                icon: Icons.upload,
                label: 'Upload',
                value: '${_result!.uploadSpeed.toStringAsFixed(1)} Mbps',
                color: Colors.blue,
              ),
              _buildMetric(
                icon: Icons.timer,
                label: 'Latency',
                value: '${_result!.latency.toStringAsFixed(0)} ms',
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Color _getQualityColor(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent: return Colors.green;
      case NetworkQuality.good: return Colors.lightGreen;
      case NetworkQuality.fair: return Colors.orange;
      case NetworkQuality.poor: return Colors.red;
      case NetworkQuality.unknown: return Colors.grey;
    }
  }
}

class SpeedGaugePainter extends CustomPainter {
  final double progress;
  final double speed;
  final bool isAnimating;
  final double animationValue;

  SpeedGaugePainter({
    required this.progress,
    required this.speed,
    required this.isAnimating,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    
    // Background arc
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );
    
    // Progress arc
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    
    final sweepAngle = isAnimating
        ? math.pi * 1.5 * animationValue
        : math.pi * 1.5 * (speed / 100).clamp(0.0, 1.0);
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      sweepAngle,
      false,
      progressPaint,
    );
    
    // Tick marks
    final tickPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2;
    
    for (int i = 0; i <= 10; i++) {
      final angle = math.pi * 0.75 + (math.pi * 1.5 * i / 10);
      final start = Offset(
        center.dx + (radius - 25) * math.cos(angle),
        center.dy + (radius - 25) * math.sin(angle),
      );
      final end = Offset(
        center.dx + (radius - 35) * math.cos(angle),
        center.dy + (radius - 35) * math.sin(angle),
      );
      canvas.drawLine(start, end, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SpeedGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.speed != speed ||
        oldDelegate.isAnimating != isAnimating ||
        oldDelegate.animationValue != animationValue;
  }
}
