import 'dart:typed_data';

/// Represents an installed application on the device
class AppItem {
  final String appName;
  final String packageName;
  final String versionName;
  final int versionCode;
  final String apkFilePath;
  final int size;
  final Uint8List? icon;
  final bool isSystemApp;
  final DateTime installedTime;
  final DateTime lastUpdateTime;

  AppItem({
    required this.appName,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.apkFilePath,
    required this.size,
    this.icon,
    required this.isSystemApp,
    required this.installedTime,
    required this.lastUpdateTime,
  });

  /// Get formatted file size (e.g., "42.5 MB")
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Get short package name (last part)
  String get shortPackageName {
    final parts = packageName.split('.');
    return parts.length > 2 
        ? '...${parts.sublist(parts.length - 2).join('.')}'
        : packageName;
  }

  /// Get file name for APK
  String get apkFileName => '$appName.apk';

  /// Check if app is large (> 100MB)
  bool get isLargeApp => size > 100 * 1024 * 1024;

  /// Convert to JSON for transfer metadata
  Map<String, dynamic> toJson() {
    return {
      'appName': appName,
      'packageName': packageName,
      'versionName': versionName,
      'versionCode': versionCode,
      'size': size,
      'isSystemApp': isSystemApp,
    };
  }

  /// Create from JSON
  factory AppItem.fromJson(Map<String, dynamic> json) {
    return AppItem(
      appName: json['appName'] as String,
      packageName: json['packageName'] as String,
      versionName: json['versionName'] as String,
      versionCode: json['versionCode'] as int,
      apkFilePath: '', // Not included in transfer
      size: json['size'] as int,
      isSystemApp: json['isSystemApp'] as bool,
      installedTime: DateTime.now(),
      lastUpdateTime: DateTime.now(),
    );
  }

  @override
  String toString() => 'AppItem($appName, $packageName, $formattedSize)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppItem &&
          runtimeType == other.runtimeType &&
          packageName == other.packageName;

  @override
  int get hashCode => packageName.hashCode;
}
