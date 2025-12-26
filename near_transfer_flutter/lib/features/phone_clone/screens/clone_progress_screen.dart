import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../core/constants.dart';
import '../../../shared/services/phone_data_service.dart';
import '../../../shared/services/discovery_service.dart';
import '../../../shared/models/discovered_device.dart';

class CloneProgressScreen extends StatefulWidget {
  final List<CloneCategory> categories;
  final List<CategoryStats> stats;

  const CloneProgressScreen({
    super.key,
    required this.categories,
    required this.stats,
  });

  @override
  State<CloneProgressScreen> createState() => _CloneProgressScreenState();
}

class _CloneProgressScreenState extends State<CloneProgressScreen> {
  final PhoneDataService _dataService = PhoneDataService();
  final DiscoveryService _discoveryService = DiscoveryService();
  
  final Map<CloneCategory, double> _categoryProgress = {};
  CloneCategory? _currentCategory;
  String _status = 'Preparing...';
  bool _isCollecting = false;
  bool _isComplete = false;
  bool _hasError = false;
  String? _errorMessage;
  CloneDataPackage? _collectedData;
  List<DiscoveredDevice> _devices = [];
  DiscoveredDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    for (final cat in widget.categories) {
      _categoryProgress[cat] = 0.0;
    }
    _startDataCollection();
    _startDiscovery();
  }

  @override
  void dispose() {
    _discoveryService.stopDiscovery();
    super.dispose();
  }

  Future<void> _startDiscovery() async {
    try {
      await _discoveryService.startDiscovery('Phone Clone');
      _discoveryService.addListener(() {
        if (mounted) {
          setState(() {
            _devices = _discoveryService.discoveredDevices;
          });
        }
      });
    } catch (e) {
      // Ignore discovery errors
    }
  }

  Future<void> _startDataCollection() async {
    setState(() {
      _isCollecting = true;
      _status = 'Collecting data...';
    });

    try {
      final data = await _dataService.collectData(
        widget.categories.toSet(),
        onProgress: (category, progress) {
          if (mounted) {
            setState(() {
              _categoryProgress[category] = progress;
              _currentCategory = category;
              _status = 'Collecting ${category.displayName}...';
            });
          }
        },
      );

      setState(() {
        _collectedData = data;
        _isCollecting = false;
        _status = 'Ready to transfer';
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isCollecting = false;
      });
    }
  }

  double get _overallProgress {
    if (_categoryProgress.isEmpty) return 0;
    return _categoryProgress.values.reduce((a, b) => a + b) / _categoryProgress.length;
  }

  Future<void> _startTransfer() async {
    if (_collectedData == null || _selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a device to transfer to')),
      );
      return;
    }

    setState(() {
      _status = 'Preparing transfer...';
    });

    try {
      // Create a temporary JSON file with the collected data
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cloneFile = File('${tempDir.path}/phone_clone_$timestamp.json');
      
      final jsonData = jsonEncode(_collectedData!.toJson());
      await cloneFile.writeAsString(jsonData);

      // Create PlatformFile for transfer
      final platformFile = PlatformFile(
        name: 'phone_clone_$timestamp.json',
        path: cloneFile.path,
        size: await cloneFile.length(),
      );

      // Add media files if any
      final allFiles = <PlatformFile>[platformFile];
      for (final mediaPath in _collectedData!.mediaPaths) {
        final file = File(mediaPath);
        if (await file.exists()) {
          allFiles.add(PlatformFile(
            name: mediaPath.split('/').last,
            path: mediaPath,
            size: await file.length(),
          ));
        }
      }

      // Navigate to device discovery with files
      if (!mounted) return;
      context.push('/discovery', extra: {'files': allFiles});
      
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Clone Progress', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Overall progress
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      // Progress circle
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: _overallProgress,
                              strokeWidth: 10,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _hasError ? Colors.red : AppColors.primary,
                              ),
                            ),
                            Center(
                              child: Text(
                                '${(_overallProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_hasError) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage ?? 'An error occurred',
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Category progress list
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.categories.length,
                    itemBuilder: (context, index) {
                      final category = widget.categories[index];
                      final progress = _categoryProgress[category] ?? 0;
                      final stat = widget.stats.firstWhere((s) => s.category == category);
                      final isCurrent = _currentCategory == category && _isCollecting;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Colors.white.withOpacity(0.15)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrent
                              ? Border.all(color: AppColors.primary, width: 2)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  category.icon,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        category.displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${stat.count} items',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (progress >= 1.0)
                                  const Icon(Icons.check_circle, color: Colors.green, size: 24)
                                else if (isCurrent)
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                else
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white24,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progress >= 1.0 ? Colors.green : AppColors.primary,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Device selection & transfer button
                if (!_isCollecting && _collectedData != null && !_hasError) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Device',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_devices.isEmpty)
                          Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.6)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Searching for devices...',
                                style: TextStyle(color: Colors.white.withOpacity(0.6)),
                              ),
                            ],
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _devices.map((device) {
                              final isSelected = _selectedDevice == device;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedDevice = device),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : Colors.white24,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.phone_android,
                                        size: 18,
                                        color: isSelected ? Colors.white : Colors.white70,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        device.deviceName,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white70,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startTransfer,
                      icon: const Icon(Icons.send),
                      label: const Text('Start Transfer'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
