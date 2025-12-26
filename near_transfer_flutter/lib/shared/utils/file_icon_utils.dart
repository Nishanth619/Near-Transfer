import 'package:flutter/material.dart';

/// Utility class for consistent file type icons and colors across the app
class FileIconUtils {
  /// Get icon for file based on extension
  static IconData getIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    
    // Images
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'heic'].contains(ext)) {
      return Icons.image_rounded;
    }
    
    // Videos
    if (['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', '3gp', 'webm'].contains(ext)) {
      return Icons.video_file_rounded;
    }
    
    // Audio
    if (['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma'].contains(ext)) {
      return Icons.audio_file_rounded;
    }
    
    // Documents
    if (['pdf'].contains(ext)) {
      return Icons.picture_as_pdf_rounded;
    }
    if (['doc', 'docx'].contains(ext)) {
      return Icons.description_rounded;
    }
    if (['xls', 'xlsx', 'csv'].contains(ext)) {
      return Icons.table_chart_rounded;
    }
    if (['ppt', 'pptx'].contains(ext)) {
      return Icons.slideshow_rounded;
    }
    if (['txt'].contains(ext)) {
      return Icons.text_snippet_rounded;
    }
    
    // Archives
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return Icons.folder_zip_rounded;
    }
    
    // APK
    if (['apk'].contains(ext)) {
      return Icons.android_rounded;
    }
    
    // Default
    return Icons.insert_drive_file_rounded;
  }
  
  /// Get color for file type
  static Color getColor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    
    // Images - Purple
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'heic'].contains(ext)) {
      return const Color(0xFF9C27B0);
    }
    
    // Videos - Orange
    if (['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', '3gp', 'webm'].contains(ext)) {
      return const Color(0xFFFF5722);
    }
    
    // Audio - Teal
    if (['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma'].contains(ext)) {
      return const Color(0xFF009688);
    }
    
    // PDF - Red
    if (['pdf'].contains(ext)) {
      return const Color(0xFFE53935);
    }
    
    // Word docs - Blue
    if (['doc', 'docx'].contains(ext)) {
      return const Color(0xFF2196F3);
    }
    
    // Excel - Green
    if (['xls', 'xlsx', 'csv'].contains(ext)) {
      return const Color(0xFF4CAF50);
    }
    
    // PowerPoint - Orange
    if (['ppt', 'pptx'].contains(ext)) {
      return const Color(0xFFFF9800);
    }
    
    // Text - Blue Grey
    if (['txt'].contains(ext)) {
      return const Color(0xFF607D8B);
    }
    
    // Archives - Amber
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return const Color(0xFFFFB300);
    }
    
    // APK - Green
    if (['apk'].contains(ext)) {
      return const Color(0xFF4CAF50);
    }
    
    // Default - Grey
    return const Color(0xFF78909C);
  }
  
  /// Build a file icon widget with background
  static Widget buildFileIcon(String fileName, {double size = 40}) {
    final icon = getIcon(fileName);
    final color = getColor(fileName);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: color,
        size: size * 0.55,
      ),
    );
  }
}
