import 'dart:io';
import 'dart:typed_data';
import 'package:device_apps/device_apps.dart';
import '../models/app_item.dart';

/// Service for managing installed applications
class AppService {
  /// Get all installed applications
  Future<List<AppItem>> getAllApps() async {
    try {
      final apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: true,
        onlyAppsWithLaunchIntent: false,
      );

      final appItems = <AppItem>[];
      
      for (final app in apps) {
        try {
          final appItem = await _convertToAppItem(app);
          if (appItem != null) {
            appItems.add(appItem);
          }
        } catch (e) {
          // Skip apps that can't be converted
          continue;
        }
      }

      return appItems;
    } catch (e) {
      return [];
    }
  }

  /// Get only user-installed applications
  Future<List<AppItem>> getUserApps() async {
    final allApps = await getAllApps();
    return allApps.where((app) => !app.isSystemApp).toList();
  }

  /// Get only system applications
  Future<List<AppItem>> getSystemApps() async {
    final allApps = await getAllApps();
    return allApps.where((app) => app.isSystemApp).toList();
  }

  /// Get specific app by package name
  Future<AppItem?> getAppByPackage(String packageName) async {
    try {
      final app = await DeviceApps.getApp(packageName, true);
      if (app != null) {
        return await _convertToAppItem(app);
      }
      return null;
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

  /// Convert device_apps Application to AppItem
  Future<AppItem?> _convertToAppItem(Application app) async {
    try {
      Uint8List? icon;
      if (app is ApplicationWithIcon) {
        icon = app.icon;
      }

      // Get APK path and size
      String apkPath = '';
      int size = 0;

      if (app is ApplicationWithIcon) {
        apkPath = app.apkFilePath;
        
        // Try to get file size
        try {
          final file = File(apkPath);
          if (await file.exists()) {
            size = await file.length();
          }
        } catch (e) {
          // If we can't get size, estimate based on data directory size
          size = app.dataDir?.split('/').length ?? 0;
        }
      }

      return AppItem(
        appName: app.appName,
        packageName: app.packageName,
        versionName: app.versionName ?? 'Unknown',
        versionCode: app.versionCode ?? 0,
        apkFilePath: apkPath,
        size: size,
        icon: icon,
        isSystemApp: app.systemApp,
        installedTime: DateTime.fromMillisecondsSinceEpoch(
          app.installTimeMillis ?? 0,
        ),
        lastUpdateTime: DateTime.fromMillisecondsSinceEpoch(
          app.updateTimeMillis ?? 0,
        ),
      );
    } catch (e) {
      return null;
    }
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
