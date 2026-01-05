import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;
import '../models/file_item.dart';

/// Check if running on desktop (Windows/macOS/Linux)
bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

class FileSystemService {
  /// Get common storage directories
  Future<Map<String, String>> getStoragePaths() async {
    final paths = <String, String>{};

    try {
      if (_isDesktop) {
        // Desktop: Use standard user directories
        final homeDir = Platform.environment['USERPROFILE'] ?? 
                        Platform.environment['HOME'] ?? 
                        '';
        
        if (homeDir.isNotEmpty) {
          paths['Home'] = homeDir;
          paths['Documents'] = '$homeDir${Platform.pathSeparator}Documents';
          paths['Downloads'] = '$homeDir${Platform.pathSeparator}Downloads';
          paths['Pictures'] = '$homeDir${Platform.pathSeparator}Pictures';
          paths['Music'] = '$homeDir${Platform.pathSeparator}Music';
          paths['Videos'] = '$homeDir${Platform.pathSeparator}Videos';
          paths['Desktop'] = '$homeDir${Platform.pathSeparator}Desktop';
        }
      } else {
        // Mobile: Use external storage directory (Android)
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final basePath = externalDir.path.split('/Android')[0];
          
          paths['Internal Storage'] = basePath;
          paths['Documents'] = '$basePath/Documents';
          paths['Downloads'] = '$basePath/Download';
          paths['Pictures'] = '$basePath/Pictures';
          paths['DCIM'] = '$basePath/DCIM';
          paths['Music'] = '$basePath/Music';
          paths['Movies'] = '$basePath/Movies';
        }
      }
    } catch (e) {
      // Error getting storage paths
    }

    return paths;
  }

  /// List files and folders in a directory
  Future<List<FileItem>> listDirectory(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        return [];
      }

      final entities = await dir.list().toList();
      final items = <FileItem>[];

      for (final entity in entities) {
        try {
          final stat = await entity.stat();
          final isDirectory = entity is Directory;
          final name = entity.path.split('/').last;

          // Skip hidden files (starting with .)
          if (name.startsWith('.')) continue;

          items.add(FileItem(
            name: name,
            path: entity.path,
            size: stat.size,
            modified: stat.modified,
            isDirectory: isDirectory,
            type: FileItem.getFileType(entity.path, isDirectory),
            extension: isDirectory ? null : name.split('.').last,
          ));
        } catch (e) {
          // Skip files we can't access
          continue;
        }
      }

      // Sort: folders first, then by name
      items.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return items;
    } catch (e) {
      // Error listing directory
      return [];
    }
  }

  /// Get files by category
  Future<List<FileItem>> getFilesByCategory(FileCategory category, String basePath) async {
    final allFiles = <FileItem>[];

    try {
      await _scanDirectoryRecursive(basePath, allFiles, category);
    } catch (e) {
      // Error getting files by category
    }

    return allFiles;
  }

  /// Recursively scan directory for specific file type
  Future<void> _scanDirectoryRecursive(
    String path,
    List<FileItem> results,
    FileCategory targetType,
  ) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return;

      final entities = await dir.list().toList();

      for (final entity in entities) {
        try {
          final name = entity.path.split('/').last;
          
          // Skip hidden files and Android system folders
          if (name.startsWith('.') || name == 'Android') continue;

          if (entity is Directory) {
            // Recursively scan subdirectories
            await _scanDirectoryRecursive(entity.path, results, targetType);
          } else {
            final stat = await entity.stat();
            final fileType = FileItem.getFileType(entity.path, false);

            if (fileType == targetType) {
              results.add(FileItem(
                name: name,
                path: entity.path,
                size: stat.size,
                modified: stat.modified,
                isDirectory: false,
                type: fileType,
                extension: name.split('.').last,
              ));
            }
          }
        } catch (e) {
          // Skip files we can't access
          continue;
        }
      }
    } catch (e) {
      // Skip directories we can't access
    }
  }

  /// Search files by name
  Future<List<FileItem>> searchFiles(String query, String basePath) async {
    final results = <FileItem>[];
    final lowerQuery = query.toLowerCase();

    try {
      await _searchRecursive(basePath, lowerQuery, results);
    } catch (e) {
      // Error searching files
    }

    return results;
  }

  /// Recursively search for files
  Future<void> _searchRecursive(
    String path,
    String query,
    List<FileItem> results,
  ) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return;

      final entities = await dir.list().toList();

      for (final entity in entities) {
        try {
          final name = entity.path.split('/').last;
          
          // Skip hidden files and Android folder
          if (name.startsWith('.') || name == 'Android') continue;

          if (name.toLowerCase().contains(query)) {
            final stat = await entity.stat();
            final isDirectory = entity is Directory;

            results.add(FileItem(
              name: name,
              path: entity.path,
              size: stat.size,
              modified: stat.modified,
              isDirectory: isDirectory,
              type: FileItem.getFileType(entity.path, isDirectory),
              extension: isDirectory ? null : name.split('.').last,
            ));
          }

          if (entity is Directory) {
            await _searchRecursive(entity.path, query, results);
          }
        } catch (e) {
          continue;
        }
      }
    } catch (e) {
      // Skip directories we can't access
    }
  }

  /// Request storage permissions
  Future<bool> requestPermissions() async {
    // Only Android needs permission requests
    // Desktop and iOS don't need storage permissions
    if (!Platform.isAndroid) {
      return true;
    }

    // Request manage external storage for Android 11+
    final status = await permission_handler.Permission.manageExternalStorage.request();
    if (status.isGranted) return true;
    
    // Fallback to storage permission for older Android
    final storageStatus = await permission_handler.Permission.storage.request();
    return storageStatus.isGranted;
  }

  /// Check if we have storage permissions
  Future<bool> hasPermissions() async {
    // Only Android needs permission checks
    // Desktop and iOS have full file access
    if (!Platform.isAndroid) {
      return true;
    }

    // Check manage external storage first
    if (await permission_handler.Permission.manageExternalStorage.isGranted) return true;
    
    // Fallback to storage permission
    return await permission_handler.Permission.storage.isGranted;
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    // Only works on mobile
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }
    
    // Use permission_handler's built-in function to open app settings
    return await permission_handler.openAppSettings();
  }
}
