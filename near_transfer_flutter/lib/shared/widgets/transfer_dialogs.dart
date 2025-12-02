import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class TransferDialogs {
  // Accept/Decline dialog for receiver
  static Future<void> showConnectionRequest({
    required BuildContext context,
    required String senderName,
    required String fileName,
    required int fileSize,
    List<Map<String, dynamic>>? files,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
  }) async {
    final filesList = files ?? [{'name': fileName, 'size': fileSize}];
    final totalSize = filesList.fold<int>(0, (sum, f) => sum + (f['size'] as int));
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ZoomIn(
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.file_download, color: Colors.blue.shade600, size: 28),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  filesList.length > 1 
                    ? 'Incoming ${filesList.length} files' 
                    : 'Incoming file',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$senderName wants to send',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              
              // Scrollable file list
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filesList.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.blue.shade100,
                  ),
                  itemBuilder: (context, index) {
                    final file = filesList[index];
                    return Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file, color: Colors.blue.shade600, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file['name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _formatBytes(file['size'] as int),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 12),
              Text(
                'Total: ${_formatBytes(totalSize)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Accept?',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onDecline();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Decline'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onAccept();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Accept'),
            ),
          ],
        ),
      ),
    );
  }

  // WebRTC timeout fallback dialog
  static Future<bool> showWebRTCTimeoutDialog({
    required BuildContext context,
    required String deviceName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ZoomIn(
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange.shade600, size: 28),
              const SizedBox(width: 12),
              const Text('Direct transfer failed'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Couldn\'t connect directly to $deviceName.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                'Use cloud fallback — upload now and send them a private download link? This will use your data.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Use fallback (Upload & Send)'),
            ),
          ],
        ),
      ),
    );
    
    return result ?? false;
  }

  // Transfer complete dialog
  static Future<void> showTransferComplete({
    required BuildContext context,
    required String fileName,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => ZoomIn(
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'Transfer complete!',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Successfully transferred "$fileName"',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
