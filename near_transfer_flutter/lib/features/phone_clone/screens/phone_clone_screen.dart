import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../../shared/widgets/animated_background.dart';
import '../../../shared/widgets/help_button.dart';
import '../../../core/constants.dart';
import '../../../shared/services/phone_data_service.dart';

class PhoneCloneScreen extends StatefulWidget {
  const PhoneCloneScreen({super.key});

  @override
  State<PhoneCloneScreen> createState() => _PhoneCloneScreenState();
}

class _PhoneCloneScreenState extends State<PhoneCloneScreen> {
  final PhoneDataService _dataService = PhoneDataService();
  List<CategoryStats> _stats = [];
  Set<CloneCategory> _selectedCategories = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await _dataService.getCategoryStats();
      setState(() {
        _stats = stats;
        // Auto-select categories with data
        _selectedCategories = stats
            .where((s) => s.hasPermission && s.count > 0)
            .map((s) => s.category)
            .toSet();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int get _totalSelectedCount {
    return _stats
        .where((s) => _selectedCategories.contains(s.category))
        .fold(0, (sum, s) => sum + s.count);
  }

  int get _totalSelectedSize {
    return _stats
        .where((s) => _selectedCategories.contains(s.category))
        .fold(0, (sum, s) => sum + s.sizeBytes);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _startClone() {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }

    context.push('/clone-progress', extra: {
      'categories': _selectedCategories.toList(),
      'stats': _stats,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Phone Clone', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          const HelpButton(
            featureName: 'Phone Clone',
            helpText: 'Transfer all your data to a new phone.\n\n• Select data categories to transfer\n• Contacts, call logs, SMS, photos, videos\n• Apps can also be transferred\n• Other device must be in Receive mode',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Scanning your device...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadStats,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Header info
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.phone_android,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Clone Your Data',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Select what to transfer to new device',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Category list
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _stats.length,
                            itemBuilder: (context, index) {
                              final stat = _stats[index];
                              return _buildCategoryCard(stat);
                            },
                          ),
                        ),

                        // Bottom summary & button
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: SafeArea(
                            top: false,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$_totalSelectedCount items selected',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Estimated size: ${_formatSize(_totalSelectedSize)}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          if (_selectedCategories.length == _stats.length) {
                                            _selectedCategories.clear();
                                          } else {
                                            _selectedCategories = _stats.map((s) => s.category).toSet();
                                          }
                                        });
                                      },
                                      child: Text(
                                        _selectedCategories.length == _stats.length
                                            ? 'Deselect All'
                                            : 'Select All',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _selectedCategories.isEmpty ? null : _startClone,
                                    icon: const Icon(Icons.send_rounded),
                                    label: const Text('Start Clone'),
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
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(CategoryStats stat) {
    final isSelected = _selectedCategories.contains(stat.category);
    final hasData = stat.count > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.white24,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: hasData && stat.hasPermission
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedCategories.remove(stat.category);
                  } else {
                    _selectedCategories.add(stat.category);
                  }
                });
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getCategoryColor(stat.category).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    stat.category.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.category.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (!stat.hasPermission)
                      const Text(
                        'Permission required',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      )
                    else if (stat.count == 0)
                      Text(
                        'No data found',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      )
                    else
                      Row(
                        children: [
                          Text(
                            '${stat.count} items',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                          if (stat.sizeBytes > 0) ...[
                            Text(
                              ' • ${stat.formattedSize}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),

              // Checkbox
              if (hasData && stat.hasPermission)
                Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedCategories.add(stat.category);
                      } else {
                        _selectedCategories.remove(stat.category);
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                  checkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              else if (!stat.hasPermission)
                TextButton(
                  onPressed: () async {
                    await _dataService.requestPermissions();
                    _loadStats();
                  },
                  child: const Text('Grant', style: TextStyle(color: AppColors.primary)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(CloneCategory category) {
    switch (category) {
      case CloneCategory.contacts: return Colors.blue;
      case CloneCategory.callLogs: return Colors.green;
      case CloneCategory.sms: return Colors.purple;
      case CloneCategory.photos: return Colors.orange;
      case CloneCategory.videos: return Colors.red;
      case CloneCategory.apps: return Colors.teal;
    }
  }
}
