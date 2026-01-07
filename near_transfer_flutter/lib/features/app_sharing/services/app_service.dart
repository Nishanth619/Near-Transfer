import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import '../models/app_item.dart';

/// Service for managing installed applications
class AppService {
  static const _channel = MethodChannel('com.neartransfer.app/apk_info');

  /// Check if running on mobile (Android/iOS)
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Get APK info (path and size) for a package
  Future<Map<String, dynamic>?> _getApkInfo(String packageName) async {
    if (!Platform.isAndroid) return null;
    
    try {
      final result = await _channel.invokeMethod('getApkInfo', {
        'packageName': packageName,
      });
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting APK info for $packageName: $e');
      return null;
    }
  }

  /// Get all installed applications
  Future<List<AppItem>> getAllApps() async {
    // Only works on mobile platforms
    if (!_isMobile) {
      return [];
    }

    try {
      final List<AppInfo> apps = await InstalledApps.getInstalledApps(
        true, // includeSystemApps
        true, // withIcon
        '', // packageNamePrefix (empty = all apps)
      );

      final List<AppItem> appItems = [];
      
      for (final app in apps) {
        try {
          String apkPath = '';
          int size = 0;
          
          if (app.packageName != null) {
            // Get actual APK path and size from platform channel
            final apkInfo = await _getApkInfo(app.packageName!);
            if (apkInfo != null) {
              apkPath = apkInfo['path'] as String? ?? '';
              size = (apkInfo['size'] as int?) ?? 0;
            }
          }

          appItems.add(AppItem(
            appName: app.name ?? 'Unknown App',
            packageName: app.packageName ?? '',
            versionName: app.versionName ?? '1.0.0',
            versionCode: int.tryParse(app.versionCode?.toString() ?? '1') ?? 1,
            apkFilePath: apkPath,
            size: size,
            icon: app.icon,
            isSystemApp: app.packageName?.startsWith('com.android') == true ||
                         app.packageName?.startsWith('com.google') == true ||
                         app.packageName?.startsWith('com.samsung') == true,
            installedTime: DateTime.now(),
            lastUpdateTime: DateTime.now(),
          ));
        } catch (e) {
          // Skip apps that cause errors
          continue;
        }
      }

      return appItems;
    } catch (e) {
      debugPrint('Error loading apps: $e');
      return [];
    }
  }

  /// Get only user-installed applications
  Future<List<AppItem>> getUserApps() async {
    final all = await getAllApps();
    return all.where((app) => !app.isSystemApp).toList();
  }

  /// Get only system applications
  Future<List<AppItem>> getSystemApps() async {
    final all = await getAllApps();
    return all.where((app) => app.isSystemApp).toList();
  }

  /// Get specific app by package name
  Future<AppItem?> getAppByPackage(String packageName) async {
    final all = await getAllApps();
    try {
      return all.firstWhere((app) => app.packageName == packageName);
    } catch (e) {
      return null;
    }
  }

  /// Get APK file from path
  Future<File?> getApkFile(String apkPath) async {
    try {
      final file = File(apkPath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Filter apps by name or package
  List<AppItem> filterByQuery(String query, List<AppItem> apps) {
    if (query.isEmpty) return apps;
    
    final lowerQuery = query.toLowerCase();
    return apps.where((app) {
      return app.appName.toLowerCase().contains(lowerQuery) ||
             app.packageName.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Sort apps by name (A-Z)
  List<AppItem> sortByName(List<AppItem> apps, {bool ascending = true}) {
    final sorted = List<AppItem>.from(apps);
    sorted.sort((a, b) {
      final comparison = a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
      return ascending ? comparison : -comparison;
    });
    return sorted;
  }

  /// Sort apps by size
  List<AppItem> sortBySize(List<AppItem> apps, {bool ascending = true}) {
    final sorted = List<AppItem>.from(apps);
    sorted.sort((a, b) {
      final comparison = a.size.compareTo(b.size);
      return ascending ? comparison : -comparison;
    });
    return sorted;
  }

  /// Sort apps by install date
  List<AppItem> sortByInstallDate(List<AppItem> apps, {bool ascending = true}) {
    final sorted = List<AppItem>.from(apps);
    sorted.sort((a, b) {
      final comparison = a.installedTime.compareTo(b.installedTime);
      return ascending ? comparison : -comparison;
    });
    return sorted;
  }

  /// Check if APK can be installed
  Future<bool> canInstallApk(String path) async {
    try {
      final file = File(path);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get total size of selected apps
  int getTotalSize(List<AppItem> apps) {
    return apps.fold(0, (sum, app) => sum + app.size);
  }

  /// Format total size
  String formatTotalSize(List<AppItem> apps) {
    final total = getTotalSize(apps);
    if (total < 1024 * 1024) {
      return '${(total / 1024).toStringAsFixed(1)} KB';
    } else if (total < 1024 * 1024 * 1024) {
      return '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(total / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
