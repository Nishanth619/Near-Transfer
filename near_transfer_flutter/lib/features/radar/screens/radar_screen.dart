import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../../shared/widgets/animated_background.dart';
import '../../../core/constants.dart';
import '../../../shared/services/discovery_service.dart';
import '../../../shared/models/discovered_device.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen>
    with TickerProviderStateMixin {
  final DiscoveryService _discoveryService = DiscoveryService();
  late AnimationController _sweepController;
  late AnimationController _pulseController;
  List<DiscoveredDevice> _devices = [];
  final Map<String, Offset> _devicePositions = {};
  final Map<String, AnimationController> _devicePulseControllers = {};
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _startDiscovery();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    for (final controller in _devicePulseControllers.values) {
      controller.dispose();
    }
    _discoveryService.stopDiscovery();
    super.dispose();
  }

  Future<void> _startDiscovery() async {
    setState(() => _isScanning = true);
    
    try {
      await _discoveryService.startDiscovery('Radar');
      _discoveryService.addListener(_updateDevices);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Discovery error: $e')),
        );
      }
    }
  }

  void _updateDevices() {
    final newDevices = _discoveryService.discoveredDevices;
    
    // Add new devices with random positions
    for (final device in newDevices) {
      if (!_devicePositions.containsKey(device.deviceId)) {
        // Generate random position on radar
        final random = math.Random();
        final angle = random.nextDouble() * 2 * math.pi;
        final distance = 0.3 + random.nextDouble() * 0.5; // 30-80% from center
        _devicePositions[device.deviceId] = Offset(
          math.cos(angle) * distance,
          math.sin(angle) * distance,
        );
        
        // Create pulse animation for new device
        final pulseController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1000),
        )..repeat(reverse: true);
        _devicePulseControllers[device.deviceId] = pulseController;
      }
    }
    
    setState(() {
      _devices = newDevices;
    });
  }

  void _onDeviceTap(DiscoveredDevice device) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Device icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_android,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              device.deviceName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              device.ip,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              device.timeSinceLastSeen,
              style: TextStyle(
                color: Colors.green.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/discovery', extra: device);
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Send Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Nearby Radar', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _devicePositions.clear();
              _startDiscovery();
            },
          ),
        ],
      ),
      body: AnimatedBackground(
        child: Container(
          margin: const EdgeInsets.only(top: kToolbarHeight + 20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              // Device count
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isScanning ? Icons.radar : Icons.devices,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isScanning
                                ? 'Scanning... ${_devices.length} found'
                                : '${_devices.length} devices',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Radar view
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final centerX = constraints.maxWidth / 2;
                          final centerY = constraints.maxHeight / 2;
                          final maxRadius = math.min(centerX, centerY) - 30;
                          
                          return AnimatedBuilder(
                            animation: Listenable.merge([_sweepController, _pulseController]),
                            builder: (context, child) {
                              return CustomPaint(
                                painter: RadarPainter(
                                  sweepAngle: _sweepController.value * 2 * math.pi,
                                  pulseValue: _pulseController.value,
                                ),
                                child: Stack(
                                  children: [
                                    // Center point (this device)
                                    Center(
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary.withValues(alpha: 0.5),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.phone_android,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    
                                    // Discovered devices
                                    ..._devices.where((d) => _devicePositions.containsKey(d.deviceId)).map((device) {
                                      final position = _devicePositions[device.deviceId]!;
                                      
                                      return Positioned(
                                        left: centerX + position.dx * maxRadius - 20,
                                        top: centerY + position.dy * maxRadius - 20,
                                        child: GestureDetector(
                                          onTap: () => _onDeviceTap(device),
                                          child: _buildDeviceMarker(device),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              
              // Device list
              if (_devices.isNotEmpty)
                Container(
                  height: 120,
                  margin: const EdgeInsets.only(bottom: 100),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return _buildDeviceCard(device);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceMarker(DiscoveredDevice device) {
    final pulseController = _devicePulseControllers[device.deviceId];
    
    return AnimatedBuilder(
      animation: pulseController ?? _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (pulseController?.value ?? 0) * 0.2;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.phone_android,
              color: Colors.white,
              size: 20,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceCard(DiscoveredDevice device) {
    return GestureDetector(
      onTap: () => _onDeviceTap(device),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_android,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              device.deviceName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              device.timeSinceLastSeen,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final double sweepAngle;
  final double pulseValue;

  RadarPainter({
    required this.sweepAngle,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 10;
    
    // Draw concentric circles
    final circlePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * i / 4, circlePaint);
    }
    
    // Draw cross lines
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      circlePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      circlePaint,
    );
    
    // Draw sweep gradient
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle - math.pi / 4,
        endAngle: sweepAngle,
        colors: [
          Colors.green.withValues(alpha: 0.0),
          Colors.green.withValues(alpha: 0.3),
          Colors.green.withValues(alpha: 0.6),
        ],
        stops: const [0.0, 0.7, 1.0],
        transform: GradientRotation(sweepAngle - math.pi / 4),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    
    canvas.drawCircle(center, maxRadius, sweepPaint);
    
    // Draw sweep line
    final linePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2;
    
    final lineEnd = Offset(
      center.dx + maxRadius * math.cos(sweepAngle),
      center.dy + maxRadius * math.sin(sweepAngle),
    );
    canvas.drawLine(center, lineEnd, linePaint);
    
    // Draw pulse circles
    final pulsePaint = Paint()
      ..color = Colors.green.withOpacity(0.3 * (1 - pulseValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, maxRadius * 0.3 + maxRadius * 0.7 * pulseValue, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.pulseValue != pulseValue;
  }
}
