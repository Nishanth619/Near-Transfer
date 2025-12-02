import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../core/constants.dart';
import '../../../shared/services/discovery_service.dart';
import '../../../shared/services/signaling_socket_service.dart';
import '../../../shared/services/webrtc_service.dart';
import '../../../shared/providers/transfer_orchestrator.dart';
import '../../../shared/models/discovered_device.dart';
import '../../../shared/widgets/transfer_dialogs.dart';
import '../../sending/screens/sending_progress_screen.dart';

class DeviceDiscoveryScreen extends StatefulWidget {
  final List<PlatformFile>? preSelectedFiles;
  final String? clipboardContent;
  final String? fileName;  // Custom file name for virtual files
  
  const DeviceDiscoveryScreen({
    super.key,
    this.preSelectedFiles,
    this.clipboardContent,
    this.fileName,
  });

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen> {
  late DiscoveryService _discoveryService;
  late TransferOrchestrator _orchestrator;
  bool _isInitialized = false;
  List<PlatformFile> _selectedFiles = [];
  String? _localIp;
  bool _isTransferring = false;
  double _progress = 0.0;
  String? _currentFileName;

  @override
  void initState() {
    super.initState();
    // Use pre-selected files if provided (e.g., from App Manager)
    if (widget.preSelectedFiles != null && widget.preSelectedFiles!.isNotEmpty) {
      _selectedFiles = widget.preSelectedFiles!;
    }
    // Handle clipboard content
    else if (widget.clipboardContent != null && widget.clipboardContent!.isNotEmpty) {
      // Create a virtual file for clipboard/contact text
      final fileName = widget.fileName ?? 'clipboard_${DateTime.now().millisecondsSinceEpoch}.txt';
      _selectedFiles = [
        PlatformFile(
          name: fileName,
          size: widget.clipboardContent!.length,
          bytes: Uint8List.fromList(widget.clipboardContent!.codeUnits),
        ),
      ];
    }
    _initializeDiscovery();
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
    
    // Setup callbacks
    _orchestrator.onTransferComplete = _handleTransferComplete;
    _orchestrator.onError = _handleError;
    
    // Listen to progress updates
    _orchestrator.addListener(_updateProgress);
    
    // Get device name
    final deviceName = 'My Device'; // TODO: Get from settings
    
    try {
      await _discoveryService.startDiscovery(deviceName);
      
      // Get and store local IP for debug display
      final localIp = _discoveryService.localIp;
      setState(() {
        _isInitialized = true;
        _localIp = localIp;
      });
      
      print('🌐Sender Local IP: $localIp');
      
      if (localIp != null) {
        final parts = localIp.split('.');
        if (parts.length == 4) {
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
          print('📡 Scanning subnet: $subnet.1-254');
        }
      }
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

  @override
  void dispose() {
    _orchestrator.removeListener(_updateProgress);
    _discoveryService.stopDiscovery();
    _orchestrator.dispose();
    super.dispose();
  }

  void _updateProgress() {
    if (mounted) {
      setState(() {
        _progress = _orchestrator.progress;
        _currentFileName = _orchestrator.currentFileName;
        _isTransferring = _orchestrator.state == TransferState.transferring;
      });
    }
  }

  Future<void> _onRefresh() async {
    _discoveryService.stopDiscovery();
    await _initializeDiscovery();
  }

  Future<void> _onDeviceTap(DiscoveredDevice device) async {
    // If files or clipboard already selected (from App Manager or Clipboard Sync), use them
    if (_selectedFiles.isEmpty) {
      // Pick files (multiple)
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      _selectedFiles = result.files;
    }
    
    // Setup listener for acceptance
    void acceptListener() {
      if (_orchestrator.state == TransferState.connected || 
          _orchestrator.state == TransferState.transferring) {
        // Remove listener
        _orchestrator.removeListener(acceptListener);
        
        // Close waiting dialog
        if (mounted) Navigator.pop(context);
        
        // Navigate to progress screen
        Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => SendingProgressScreen(
              orchestrator: _orchestrator,
              fileName: _selectedFiles.first.name,
            ),
          ),
        ).then((success) {
          // Just reset orchestrator, don't auto-navigate
          if (mounted) {
            _orchestrator.reset();
          }
        });
      }
    }
    
    _orchestrator.addListener(acceptListener);
    
    // Show waiting for acceptance dialog
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
            const Text('Waiting for receiver to accept...'),
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
    
    // Start connection
    _orchestrator.connectToDevice(device, _selectedFiles);
  }

  void _handleTransferComplete() {
    if (!mounted) return;
    
    // Do nothing here, let the progress screen handle the UI
    // The user will manually click "Done" to navigate back
  }

  void _handleError(String error) {
    if (!mounted) return;
    
    // Close any open dialogs
    Navigator.pop(context);
    
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
        title: const Text('Nearby Devices', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
              : ListenableBuilder(
                  listenable: _discoveryService,
                  builder: (context, child) {
                    final devices = _discoveryService.discoveredDevices;
                    
                    if (devices.isEmpty) {
                      return _buildEmptyState();
                    }
                    
                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return FadeInUp(
                            delay: Duration(milliseconds: index * 100),
                            child: _buildDeviceCard(device),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices,
            size: 80,
            color: AppColors.primary.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'No devices found',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Make sure both devices are on the same WiFi network',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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

  Widget _buildDeviceCard(DiscoveredDevice device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.phone_android,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.ip,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.timeSinceLastSeen,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
