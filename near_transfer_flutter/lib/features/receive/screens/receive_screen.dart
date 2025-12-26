import 'dart:io';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../shared/widgets/help_button.dart';
import '../../../core/constants.dart';
import '../../../shared/services/discovery_service.dart';
import '../../../shared/services/signaling_socket_service.dart';
import '../../../shared/services/webrtc_service.dart';
import '../../../shared/providers/transfer_orchestrator.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/widgets/transfer_dialogs.dart';
import './receiving_progress_screen.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  late DiscoveryService _discoveryService;
  late TransferOrchestrator _orchestrator;
  bool _isInitialized = false;
  bool _isReceiving = false;
  String? _currentFileName;
  double _progress = 0.0;
  String? _localIp; // Store local IP for debug display
  bool _autoAccept = false;

  @override
  void initState() {
    super.initState();
    _initializeReceiver();
  }

  Future<void> _initializeReceiver() async {
    _discoveryService = DiscoveryService();
    
    final signalingService = SignalingSocketService();
    final webrtcService = WebRTCService();
    
    _orchestrator = TransferOrchestrator(
      discoveryService: _discoveryService,
      signalingService: signalingService,
      webrtcService: webrtcService,
    );
    
    // Setup callbacks
    _orchestrator.onConnectionRequest = _handleConnectionRequest;
    _orchestrator.onTransferComplete = _handleTransferComplete;
    _orchestrator.onError = _handleError;
    
    // Listen to orchestrator for progress updates
    _orchestrator.addListener(_updateProgress);
    
    // Get settings
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final deviceName = settingsProvider.deviceName;
    _autoAccept = settingsProvider.autoAccept;
    
    // Enable keep screen on if setting is enabled
    if (settingsProvider.keepScreenOn) {
      WakelockPlus.enable();
    }
    
    try {
      // Get local IP first
      final localIp = await _getLocalIp();
      if (localIp == null) {
        throw Exception('Could not determine local IP');
      }
      
      // Store for debug display
      setState(() {
        _localIp = localIp;
      });
      
      print('🌐 Receiver Local IP: $localIp');
      
      // Generate device ID
      final deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      
      // IMPORTANT: Start signaling server FIRST (before discovery)
      // This ensures TCP port is open when sender scans
      print('Starting TCP signaling server...');
      await _orchestrator.startReceiving(
        deviceId: deviceId,
        deviceName: deviceName,
        deviceIp: localIp,
      );
      print('TCP server started on $localIp:45455');
      
      // Link signaling service to discovery service for shake mode sync
      _discoveryService.setSignalingService(signalingService);
      
      // Then start discovery (advertise presence)
      print('Starting discovery service...');
      await _discoveryService.startDiscovery(deviceName);
      print('Discovery started');
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing receiver: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start receiver: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  void _updateProgress() {
    if (mounted) {
      setState(() {
        _progress = _orchestrator.progress;
      });
    }
  }

  @override
  void dispose() {
    _orchestrator.removeListener(_updateProgress);
    _discoveryService.stopDiscovery();
    // Disable wakelock when leaving
    WakelockPlus.disable();
    super.dispose();
  }

  void _handleConnectionRequest(
    String senderName,
    String fileName,
    int fileSize,
    List<Map<String, dynamic>>? files,
    Function() onAccept,
    Function() onDecline,
  ) {
    if (!mounted) return;
    
    // If auto-accept is enabled, automatically accept the transfer
    if (_autoAccept) {
      _acceptAndNavigate(senderName, onAccept);
      return;
    }
    
    TransferDialogs.showConnectionRequest(
      context: context,
      senderName: senderName,
      fileName: fileName,
      fileSize: fileSize,
      files: files,
      onAccept: () {
        _acceptAndNavigate(senderName, onAccept);
      },
      onDecline: onDecline,
    );
  }

  void _acceptAndNavigate(String senderName, Function() onAccept) {
    // Accept connection
    onAccept();
    
    // Navigate to progress screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceivingProgressScreen(
          orchestrator: _orchestrator,
          senderName: senderName,
        ),
      ),
    ).then((success) {
      // Reset after completion
      if (mounted) {
        _orchestrator.reset();
        setState(() {
          _isReceiving = false;
          _currentFileName = null;
          _progress = 0.0;
        });
      }
    });
  }

  void _handleTransferComplete() {
    // Progress screen handles completion
  }

  void _handleError(String error) {
    if (!mounted) return;
    
    setState(() {
      _isReceiving = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
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
        title: const Text('Receive Files', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          HelpButton(
            featureName: 'Receive Files',
            helpText: 'Wait for nearby devices to send you files.\n\n• Your device is now visible to others on the same WiFi network\n• When someone sends files, you\'ll get a notification to accept\n• Files are saved to your Downloads folder',
          ),
        ],
      ),
      body: AnimatedBackground(
        child: Container(
          margin: const EdgeInsets.only(top: kToolbarHeight + 20),
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isReceiving) {
      return _buildReceivingState();
    }
    
    return _buildWaitingState();
  }

  Widget _buildWaitingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeIn(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_tethering,
                size: 60,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ready to receive',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Waiting for incoming files...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.muted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600),
                const SizedBox(height: 8),
                const Text(
                  'Make sure you\'re on the same WiFi network as the sender',
                  style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          const Text(
            'Receiving file...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_currentFileName != null)
            Text(
              _currentFileName!,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
