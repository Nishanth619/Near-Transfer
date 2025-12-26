import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../shared/widgets/help_button.dart';
import '../../../shared/widgets/connection_strength_indicator.dart';
import '../../../core/constants.dart';
import '../../../shared/services/discovery_service.dart';
import '../../../shared/services/signaling_socket_service.dart';
import '../../../shared/services/webrtc_service.dart';
import '../../../shared/providers/transfer_orchestrator.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/models/discovered_device.dart';
import '../../sending/screens/sending_progress_screen.dart';

class DeviceDiscoveryScreen extends StatefulWidget {
  final List<PlatformFile>? preSelectedFiles;
  final String? clipboardContent;
  final String? fileName;
  final DiscoveredDevice? preSelectedDevice;
  final TransferOrchestrator? preConfiguredOrchestrator;
  
  const DeviceDiscoveryScreen({
    super.key,
    this.preSelectedFiles,
    this.clipboardContent,
    this.fileName,
    this.preSelectedDevice,
    this.preConfiguredOrchestrator,
  });

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen>
    with TickerProviderStateMixin {
  late DiscoveryService _discoveryService;
  late TransferOrchestrator _orchestrator;
  late AnimationController _sweepController;
  late AnimationController _pulseController;
  
  bool _isInitialized = false;
  List<PlatformFile> _selectedFiles = [];
  bool _isRadarView = true; // Default to radar view
  
  // Device positions for radar
  final Map<String, Offset> _devicePositions = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Use pre-selected files if provided
    if (widget.preSelectedFiles != null && widget.preSelectedFiles!.isNotEmpty) {
      _selectedFiles = widget.preSelectedFiles!;
    }
    // Handle clipboard content
    else if (widget.clipboardContent != null && widget.clipboardContent!.isNotEmpty) {
      final fileName = widget.fileName ?? 'clipboard_${DateTime.now().millisecondsSinceEpoch}.txt';
      _selectedFiles = [
        PlatformFile(
          name: fileName,
          size: widget.clipboardContent!.length,
          bytes: Uint8List.fromList(widget.clipboardContent!.codeUnits),
        ),
      ];
    }
    
    if (widget.preSelectedDevice != null) {
      _initializeForDirectConnection();
    } else {
      _initializeDiscovery();
    }
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    _orchestrator.removeListener(_updateProgress);
    _discoveryService.stopDiscovery();
    _orchestrator.dispose();
    super.dispose();
  }

  Future<void> _initializeForDirectConnection() async {
    if (widget.preConfiguredOrchestrator != null) {
      _orchestrator = widget.preConfiguredOrchestrator!;
      _discoveryService = DiscoveryService();
    } else {
      final signalingService = SignalingSocketService();
      final webrtcService = WebRTCService();
      
      _discoveryService = DiscoveryService();
      
      _orchestrator = TransferOrchestrator(
        discoveryService: _discoveryService,
        signalingService: signalingService,
        webrtcService: webrtcService,
      );
    }
    
    _orchestrator.onTransferComplete = _handleTransferComplete;
    _orchestrator.onError = _handleError;
    _orchestrator.addListener(_updateProgress);
    
    setState(() => _isInitialized = true);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onDeviceTap(widget.preSelectedDevice!);
      }
    });
  }

  Future<void> _initializeDiscovery() async {
    _discoveryService = DiscoveryService();
    
    final signalingService = SignalingSocketService();
    final webrtcService = WebRTCService();
    
    _orchestrator = TransferOrchestrator(
      discoveryService: _discoveryService,
      signalingService: signalingService,
      webrtcService: webrtcService,
    );
    
    _orchestrator.onTransferComplete = _handleTransferComplete;
    _orchestrator.onError = _handleError;
    _orchestrator.addListener(_updateProgress);
    
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final deviceName = settingsProvider.deviceName;
    
    try {
      await _discoveryService.startDiscovery(deviceName);
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start discovery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateProgress() {
    if (mounted) {
      setState(() {
        // Progress updates handled by orchestrator listener
      });
    }
  }

  Future<void> _onRefresh() async {
    _devicePositions.clear();
    _discoveryService.stopDiscovery();
    await _initializeDiscovery();
  }

  void _updateDevicePositions(List<DiscoveredDevice> devices) {
    final random = math.Random();
    for (final device in devices) {
      if (!_devicePositions.containsKey(device.deviceId)) {
        final angle = random.nextDouble() * 2 * math.pi;
        final distance = 0.3 + random.nextDouble() * 0.5;
        _devicePositions[device.deviceId] = Offset(
          math.cos(angle) * distance,
          math.sin(angle) * distance,
        );
      }
    }
  }

  Future<void> _onDeviceTap(DiscoveredDevice device) async {
    if (_selectedFiles.isEmpty) {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      _selectedFiles = result.files;
    }
    
    void acceptListener() {
      if (_orchestrator.state == TransferState.connected || 
          _orchestrator.state == TransferState.transferring) {
        _orchestrator.removeListener(acceptListener);
        
        if (mounted) Navigator.pop(context);
        
        Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => SendingProgressScreen(
              orchestrator: _orchestrator,
              fileName: _selectedFiles.first.name,
            ),
          ),
        ).then((success) {
          if (mounted) {
            _orchestrator.reset();
          }
        });
      }
    }
    
    _orchestrator.addListener(acceptListener);
    
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Connecting to ${device.deviceName}...'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _orchestrator.removeListener(acceptListener);
                _orchestrator.reset();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    
    _orchestrator.connectToDevice(device, _selectedFiles);
  }

  void _handleTransferComplete() {}

  void _handleError(String error) {
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Nearby Devices', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          const HelpButton(
            featureName: 'Send Files',
            helpText: 'Find nearby devices and send files to them.\n\n• Select files first, or tap a device to pick files\n• Tap on a discovered device to start sending\n• Both devices must be on the same WiFi\n• Use radar or list view to see devices',
          ),
          // Toggle view button
          IconButton(
            icon: Icon(
              _isRadarView ? Icons.list_rounded : Icons.radar_rounded,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _isRadarView = !_isRadarView),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _onRefresh,
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
          child: !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : ListenableBuilder(
                  listenable: _discoveryService,
                  builder: (context, child) {
                    final devices = _discoveryService.discoveredDevices;
                    _updateDevicePositions(devices);
                    
                    return Column(
                      children: [
                        // Device count indicator
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.radar,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Scanning... ${devices.length} found',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Main content - Radar or List view
                        Expanded(
                          child: _isRadarView
                              ? _buildRadarView(devices)
                              : _buildListView(devices),
                        ),
                        
                        // Device cards at bottom
                        if (devices.isNotEmpty)
                          Container(
                            height: 110,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: devices.length,
                              itemBuilder: (context, index) {
                                return _buildDeviceCard(devices[index]);
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: _selectedFiles.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _onGroupTransferTap(),
              icon: const Icon(Icons.group),
              label: Text('Send ${_selectedFiles.length} files'),
              backgroundColor: AppColors.primary,
            )
          : null,
    );
  }

  Widget _buildRadarView(List<DiscoveredDevice> devices) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AnimatedBuilder(
            animation: Listenable.merge([_sweepController, _pulseController]),
            builder: (context, child) {
              return CustomPaint(
                painter: RadarPainter(
                  sweepAngle: _sweepController.value * 2 * math.pi,
                  pulseValue: _pulseController.value,
                ),
                child: Stack(
                  children: [
                    // Center - this device
                    Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.phone_android,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    
                    // Discovered devices
                    ...devices.map((device) {
                      final position = _devicePositions[device.deviceId];
                      if (position == null) return const SizedBox.shrink();
                      
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final centerX = constraints.maxWidth / 2;
                          final centerY = constraints.maxHeight / 2;
                          final maxRadius = math.min(centerX, centerY) - 30;
                          
                          return Positioned(
                            left: centerX + position.dx * maxRadius - 22,
                            top: centerY + position.dy * maxRadius - 22,
                            child: GestureDetector(
                              onTap: () => _onDeviceTap(device),
                              child: _buildDeviceMarker(device),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceMarker(DiscoveredDevice device) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + _pulseController.value * 0.1;
        final glowOpacity = 0.3 + _pulseController.value * 0.4;
        final ringScale = 1.0 + _pulseController.value * 0.5;
        
        return SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing glow ring
              Transform.scale(
                scale: ringScale,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF22C55E).withOpacity(1 - _pulseController.value * 0.7),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Main device circle with pulse
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22C55E).withOpacity(glowOpacity),
                        blurRadius: 12 + _pulseController.value * 8,
                        spreadRadius: 2 + _pulseController.value * 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.phone_android,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListView(List<DiscoveredDevice> devices) {
    if (devices.isEmpty) {
      return _buildEmptyState();
    }
    
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return FadeInUp(
            delay: Duration(milliseconds: index * 100),
            child: _buildDeviceListItem(device),
          );
        },
      ),
    );
  }

  Widget _buildDeviceListItem(DiscoveredDevice device) {
    // Calculate signal strength based on time since last seen
    // More recently seen = stronger signal
    final timeDiff = DateTime.now().difference(device.lastSeen).inSeconds;
    final strength = (1.0 - (timeDiff / 30.0)).clamp(0.2, 1.0);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _onDeviceTap(device),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.phone_android, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.deviceName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConnectionStrengthBadge(strength: strength, showLabel: false),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.ip,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    Text(
                      device.timeSinceLastSeen,
                      style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(DiscoveredDevice device) {
    return GestureDetector(
      onTap: () => _onDeviceTap(device),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
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
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_android, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              device.deviceName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              device.timeSinceLastSeen,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            'Scanning for devices...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure both devices are on the same WiFi',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Future<void> _onGroupTransferTap() async {
    if (_selectedFiles.isEmpty) {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      setState(() => _selectedFiles = result.files);
    }

    final devices = _discoveryService.discoveredDevices;
    
    if (devices.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No devices found. Please wait for discovery.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    context.push('/device-selection', extra: {
      'devices': devices,
      'files': _selectedFiles,
    });
  }
}

class RadarPainter extends CustomPainter {
  final double sweepAngle;
  final double pulseValue;

  RadarPainter({required this.sweepAngle, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 10;
    
    // Concentric circles
    final circlePaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * i / 4, circlePaint);
    }
    
    // Cross lines
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
    
    // Sweep gradient
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle - math.pi / 4,
        endAngle: sweepAngle,
        colors: [
          const Color(0xFF22C55E).withOpacity(0.0),
          const Color(0xFF22C55E).withOpacity(0.2),
          const Color(0xFF22C55E).withOpacity(0.5),
        ],
        stops: const [0.0, 0.7, 1.0],
        transform: GradientRotation(sweepAngle - math.pi / 4),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    
    canvas.drawCircle(center, maxRadius, sweepPaint);
    
    // Sweep line
    final linePaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..strokeWidth = 2;
    
    final lineEnd = Offset(
      center.dx + maxRadius * math.cos(sweepAngle),
      center.dy + maxRadius * math.sin(sweepAngle),
    );
    canvas.drawLine(center, lineEnd, linePaint);
    
    // Pulse effect
    final pulsePaint = Paint()
      ..color = const Color(0xFF22C55E).withOpacity(0.2 * (1 - pulseValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, maxRadius * 0.3 + maxRadius * 0.7 * pulseValue, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle || oldDelegate.pulseValue != pulseValue;
  }
}
