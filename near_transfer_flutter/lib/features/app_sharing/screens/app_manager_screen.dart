import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../shared/widgets/animated_background.dart';
import '../../../core/constants.dart';
import '../models/app_item.dart';
import '../services/app_service.dart';
import '../widgets/app_list_item.dart';

class AppManagerScreen extends StatefulWidget {
  const AppManagerScreen({super.key});

  @override
  State<AppManagerScreen> createState() => _AppManagerScreenState();
}

class _AppManagerScreenState extends State<AppManagerScreen>
    with SingleTickerProviderStateMixin {
  final AppService _appService = AppService();

  List<AppItem> _allApps = [];
  List<AppItem> _displayedApps = [];
  List<AppItem> _selectedApps = [];

  bool _isLoading = true;
  String _searchQuery = '';
  late TabController _tabController;
  int _currentTab = 0;

  final List<String> _tabs = ['All Apps', 'User Apps', 'System Apps'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTab = _tabController.index;
          _selectedApps.clear();
        });
        _filterApps();
      }
    });
    _loadApps();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);

    try {
      final apps = await _appService.getAllApps();
      if (mounted) {
        setState(() {
          _allApps = _appService.sortByName(apps);
          _isLoading = false;
        });
        _filterApps();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading apps: $e')),
        );
      }
    }
  }

  void _filterApps() {
    List<AppItem> filtered = _allApps;

    // Filter by tab
    if (_currentTab == 1) {
      // User apps only
      filtered = filtered.where((app) => !app.isSystemApp).toList();
    } else if (_currentTab == 2) {
      // System apps only
      filtered = filtered.where((app) => app.isSystemApp).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = _appService.filterByQuery(_searchQuery, filtered);
    }

    setState(() {
      _displayedApps = filtered;
    });
  }

  void _onAppTap(AppItem app) {
    setState(() {
      if (_selectedApps.contains(app)) {
        _selectedApps.remove(app);
      } else {
        _selectedApps.add(app);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedApps = List.from(_displayedApps);
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedApps.clear();
    });
  }

  void _shareSelectedApps() {
    if (_selectedApps.isEmpty) return;

    // Convert selected apps to PlatformFile format
    final platformFiles = _selectedApps.map((app) {
      return PlatformFile(
        name: app.apkFileName,
        path: app.apkFilePath,
        size: app.size,
      );
    }).toList();

    // Navigate to device discovery with selected files
    context.push('/discovery', extra: platformFiles);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _selectedApps.isEmpty
              ? 'Apps'
              : '${_selectedApps.length} selected',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: _selectedApps.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all, color: Colors.white),
                  onPressed: _selectAll,
                  tooltip: 'Select All',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _deselectAll,
                  tooltip: 'Deselect All',
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: AnimatedBackground(
        child: Container(
          margin: const EdgeInsets.only(top: kToolbarHeight + 100),
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingMd,
            AppConstants.spacingMd,
            AppConstants.spacingMd,
            0,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: _buildBody(),
        ),
      ),
      floatingActionButton: _selectedApps.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _shareSelectedApps,
              icon: const Icon(Icons.share),
              label: Text('Share ${_selectedApps.length}'),
              backgroundColor: AppColors.primary,
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading apps...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _filterApps();
            },
            decoration: InputDecoration(
              hintText: 'Search apps...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() => _searchQuery = '');
                        _filterApps();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),

        // App Count Info
        if (_displayedApps.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_displayedApps.length} apps',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_selectedApps.isNotEmpty)
                  Text(
                    'Total: ${_appService.formatTotalSize(_selectedApps)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),

        // Apps List
        Expanded(
          child: _displayedApps.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: _displayedApps.length,
                  itemBuilder: (context, index) {
                    final app = _displayedApps[index];
                    final isSelected = _selectedApps.contains(app);

                    return AppListItem(
                      app: app,
                      isSelected: isSelected,
                      onTap: () => _onAppTap(app),
                      onLongPress: () => _onAppTap(app),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.apps_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No apps found'
                : 'No apps available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
