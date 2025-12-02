enum FileCategory {
  image,
  video,
  audio,
  document,
  apk,
  folder,
  other,
}

class FileItem {
  final String name;
  final String path;
  final int size;
  final DateTime modified;
  final bool isDirectory;
  final FileCategory type;
  final String? extension;

  FileItem({
    required this.name,
    required this.path,
    required this.size,
    required this.modified,
    required this.isDirectory,
    required this.type,
    this.extension,
  });

  /// Get formatted file size (e.g., "1.5 MB")
  String get formattedSize {
    if (isDirectory) return '';
    
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get file type from extension
  static FileCategory getFileType(String path, bool isDirectory) {
    if (isDirectory) return FileCategory.folder;

    final ext = path.split('.').last.toLowerCase();

    // Images
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext)) {
      return FileCategory.image;
    }

    // Videos
    if (['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', '3gp', 'webm'].contains(ext)) {
      return FileCategory.video;
    }

    // Audio
    if (['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma'].contains(ext)) {
      return FileCategory.audio;
    }

    // Documents
    if (['pdf', 'doc', 'docx', 'txt', 'xlsx', 'xls', 'ppt', 'pptx', 'csv'].contains(ext)) {
      return FileCategory.document;
    }

    // APK
    if (ext == 'apk') {
      return FileCategory.apk;
    }

    return FileCategory.other;
  }

  /// Get icon name for file type
  String get iconName {
    switch (type) {
      case FileCategory.image:
        return 'image';
      case FileCategory.video:
        return 'videocam';
      case FileCategory.audio:
        return 'music_note';
      case FileCategory.document:
        return 'description';
      case FileCategory.apk:
        return 'android';
      case FileCategory.folder:
        return 'folder';
      case FileCategory.other:
        return 'insert_drive_file';
    }
  }
}
