import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../shared/widgets/help_button.dart';
import '../../../shared/widgets/banner_ad_widget.dart';
import '../../../core/constants.dart';
import '../models/file_item.dart';
import '../services/file_system_service.dart';
import '../widgets/file_list_item.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final FileSystemService _fileService = FileSystemService();
  
  List<FileItem> _currentFiles = [];
  List<FileItem> _selectedFiles = [];
  String _currentPath = '';
  List<String> _pathHistory = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _isSelectionMode = false;
  
  late TabController _tabController;
  int _currentTab = 0;
  
  final List<String> _categories = ['All', 'Images', 'Videos', 'Audio', 'Documents'];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTab = _tabController.index;
          _selectedFiles.clear();
          _isSelectionMode = false;
        });
        _loadFiles();
      }
    });
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check permissions when app resumes (e.g. returning from settings)
      _initialize();
    }
  }

  Future<void> _initialize() async {
    // Only show loading if we don't have permission yet or are doing a fresh load
    if (!_hasPermission) {
      setState(() => _isLoading = true);
    }

    // Check permissions
    final hasPermission = await _fileService.hasPermissions();
    
    if (!hasPermission) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasPermission = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _hasPermission = true);
    }

    // Get initial path if not already set
    if (_currentPath.isEmpty) {
      final paths = await _fileService.getStoragePaths();
      if (paths.isNotEmpty) {
        _currentPath = paths['Internal Storage'] ?? '';
      }
    }

    // Load files
    if (_currentPath.isNotEmpty) {
      await _loadFiles();
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestPermission() async {
    // Try to request permission first
    final granted = await _fileService.requestPermissions();
    
    if (granted) {
      // Permission granted, reload
      await _initialize();
    } else {
      // Permission denied, show dialog to open settings
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'File Manager needs storage permission to access your files. Please enable it in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Open app settings
                  await _fileService.openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);

    try {
      List<FileItem> files;

      if (_currentTab == 0) {
        // All files - browse current directory
        files = await _fileService.listDirectory(_currentPath);
      } else {
        // Category view
        final category = _getCategoryType(_currentTab);
        files = await _fileService.getFilesByCategory(category, _currentPath);
      }

      setState(() {
        _currentFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading files: $e')),
        );
      }
    }
  }

  FileCategory _getCategoryType(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return FileCategory.image;
      case 2:
        return FileCategory.video;
      case 3:
        return FileCategory.audio;
      case 4:
        return FileCategory.document;
      default:
        return FileCategory.other;
    }
  }

  void _onFileTap(FileItem file) {
    if (_isSelectionMode) {
      _toggleSelection(file);
    } else if (file.isDirectory) {
      _navigateToFolder(file.path);
    } else {
      _toggleSelection(file);
      setState(() => _isSelectionMode = true);
    }
  }

  void _toggleSelection(FileItem file) {
    setState(() {
      if (_selectedFiles.any((f) => f.path == file.path)) {
        _selectedFiles.removeWhere((f) => f.path == file.path);
        if (_selectedFiles.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        if (!file.isDirectory) {
          _selectedFiles.add(file);
        }
      }
    });
  }

  void _navigateToFolder(String path) {
    _pathHistory.add(_currentPath);
    setState(() {
      _currentPath = path;
    });
    _loadFiles();
  }

  void _navigateBack() {
    if (_pathHistory.isNotEmpty) {
      setState(() {
        _currentPath = _pathHistory.removeLast();
      });
      _loadFiles();
    } else {
      // Go back to Home screen (MainScreen index 0)
      context.go('/');
    }
  }

  void _sendSelectedFiles() {
    if (_selectedFiles.isEmpty) return;

    // Convert FileItem to PlatformFile
    final platformFiles = _selectedFiles.map((file) {
      return PlatformFile(
        name: file.name,
        path: file.path,
        size: file.size,
      );
    }).toList();

    // Navigate to device discovery screen with selected files
    context.push('/discovery', extra: {'files': platformFiles});
  }

  void _selectAll() {
    setState(() {
      _selectedFiles = _currentFiles.where((f) => !f.isDirectory).toList();
      _isSelectionMode = true;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFiles.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSelectionMode && _pathHistory.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_isSelectionMode) {
            _clearSelection();
          } else if (_pathHistory.isNotEmpty) {
            _navigateBack();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          title: Text(
            _isSelectionMode
                ? '${_selectedFiles.length} selected'
                : 'File Manager',
            style: const TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _navigateBack,
          ),
          actions: _isSelectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.select_all, color: Colors.white),
                    onPressed: _selectAll,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _clearSelection,
                  ),
                ]
              : [
                  const HelpButton(
                    featureName: 'File Manager',
                    helpText: 'Browse and select files to share.\n\n• Navigate folders by tapping\n• Tap files to select for sharing\n• Use categories to filter by type\n• Long press to start multi-select',
                  ),
                ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: _categories.map((cat) => Tab(text: cat)).toList(),
          ),
        ),
        body: Container(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppColors.darkSurface 
              : AppColors.surfaceAlt,
          child: _buildBody(),
        ),
        floatingActionButton: _selectedFiles.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _sendSelectedFiles,
                icon: const Icon(Icons.send),
                label: Text('Send ${_selectedFiles.length}'),
                backgroundColor: AppColors.primary,
              )
            : null,
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Storage permission required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please grant storage permission to browse files',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _requestPermission,
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No files found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Path breadcrumb (only for "All" tab)
        if (_currentTab == 0 && _currentPath.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentPath.split('/').last,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        
        // File list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: _currentFiles.length,
            itemBuilder: (context, index) {
              final file = _currentFiles[index];
              final isSelected = _selectedFiles.any((f) => f.path == file.path);

              return FileListItem(
                file: file,
                isSelected: isSelected,
                onTap: () => _onFileTap(file),
                onLongPress: () {
                  if (!file.isDirectory) {
                    _toggleSelection(file);
                    setState(() => _isSelectionMode = true);
                  }
                },
              );
            },
          ),
        ),
        
        // Banner Ad at bottom
        SafeArea(
          top: false,
          child: const BannerAdWidget(),
        ),
      ],
    );
  }
}
