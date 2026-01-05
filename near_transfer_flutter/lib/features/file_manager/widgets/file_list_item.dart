import 'package:flutter/material.dart';
import '../models/file_item.dart';

class FileListItem extends StatelessWidget {
  final FileItem file;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const FileListItem({
    super.key,
    required this.file,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      leading: _buildLeading(),
      title: Text(
        file.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: file.isDirectory
          ? null
          : Text(
              file.formattedSize,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
      trailing: file.isDirectory
          ? Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.grey)
          : null,
      selected: isSelected,
      selectedTileColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _buildLeading() {
    if (isSelected) {
      return const CircleAvatar(
        backgroundColor: Colors.blue,
        child: Icon(Icons.check, color: Colors.white, size: 18),
      );
    }

    return CircleAvatar(
      backgroundColor: _getIconColor().withValues(alpha: 0.1),
      child: Icon(
        _getIcon(),
        color: _getIconColor(),
        size: 24,
      ),
    );
  }

  IconData _getIcon() {
    switch (file.type) {
      case FileCategory.image:
        return Icons.image;
      case FileCategory.video:
        return Icons.videocam;
      case FileCategory.audio:
        return Icons.music_note;
      case FileCategory.document:
        return Icons.description;
      case FileCategory.apk:
        return Icons.android;
      case FileCategory.folder:
        return Icons.folder;
      case FileCategory.other:
        return Icons.insert_drive_file;
    }
  }

  Color _getIconColor() {
    switch (file.type) {
      case FileCategory.image:
        return Colors.blue;
      case FileCategory.video:
        return Colors.red;
      case FileCategory.audio:
        return Colors.purple;
      case FileCategory.document:
        return Colors.orange;
      case FileCategory.apk:
        return Colors.green;
      case FileCategory.folder:
        return Colors.amber;
      case FileCategory.other:
        return Colors.grey;
    }
  }
}
