import 'package:flutter_test/flutter_test.dart';

// Unit tests for utility classes and services

void main() {
  group('File Size Formatting Tests', () {
    String formatBytes(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    
    test('Formats bytes correctly', () {
      expect(formatBytes(500), '500 B');
    });
    
    test('Formats kilobytes correctly', () {
      expect(formatBytes(2048), '2.0 KB');
    });
    
    test('Formats megabytes correctly', () {
      expect(formatBytes(1048576), '1.0 MB');
    });
    
    test('Formats gigabytes correctly', () {
      expect(formatBytes(1073741824), '1.0 GB');
    });
  });
  
  group('File Extension Tests', () {
    String getFileExtension(String filename) {
      if (!filename.contains('.')) return '';
      return filename.split('.').last.toLowerCase();
    }
    
    test('Extracts extension from simple filename', () {
      expect(getFileExtension('test.pdf'), 'pdf');
    });
    
    test('Extracts extension from complex filename', () {
      expect(getFileExtension('my.file.name.txt'), 'txt');
    });
    
    test('Returns empty for no extension', () {
      expect(getFileExtension('noextension'), '');
    });
    
    test('Handles uppercase extensions', () {
      expect(getFileExtension('document.PDF'), 'pdf');
    });
  });
  
  group('Device Name Validation Tests', () {
    bool isValidDeviceName(String name) {
      return name.isNotEmpty && name.length <= 50;
    }
    
    test('Valid device name', () {
      expect(isValidDeviceName('MyPhone'), true);
    });
    
    test('Empty device name is invalid', () {
      expect(isValidDeviceName(''), false);
    });
    
    test('Long device name is invalid', () {
      expect(isValidDeviceName('A' * 51), false);
    });
  });
  
  group('IP Address Validation Tests', () {
    bool isValidIP(String ip) {
      final parts = ip.split('.');
      if (parts.length != 4) return false;
      for (var part in parts) {
        final num = int.tryParse(part);
        if (num == null || num < 0 || num > 255) return false;
      }
      return true;
    }
    
    test('Valid IP address', () {
      expect(isValidIP('192.168.1.1'), true);
    });
    
    test('Invalid IP with too few octets', () {
      expect(isValidIP('192.168.1'), false);
    });
    
    test('Invalid IP with out of range octet', () {
      expect(isValidIP('192.168.1.256'), false);
    });
    
    test('Invalid IP with non-numeric values', () {
      expect(isValidIP('192.168.1.abc'), false);
    });
  });
  
  group('Transfer Progress Calculation Tests', () {
    double calculateProgress(int bytesTransferred, int totalBytes) {
      if (totalBytes == 0) return 0.0;
      return bytesTransferred / totalBytes;
    }
    
    test('Zero progress when no bytes transferred', () {
      expect(calculateProgress(0, 1000), 0.0);
    });
    
    test('50% progress at halfway', () {
      expect(calculateProgress(500, 1000), 0.5);
    });
    
    test('100% progress when complete', () {
      expect(calculateProgress(1000, 1000), 1.0);
    });
    
    test('Zero total bytes returns 0 progress', () {
      expect(calculateProgress(0, 0), 0.0);
    });
  });
  
  group('Speed Calculation Tests', () {
    String formatSpeed(double bytesPerSecond) {
      if (bytesPerSecond < 1024) {
        return '${bytesPerSecond.toStringAsFixed(1)} B/s';
      } else if (bytesPerSecond < 1024 * 1024) {
        return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
      } else {
        return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
      }
    }
    
    test('Formats slow speed in B/s', () {
      expect(formatSpeed(500), '500.0 B/s');
    });
    
    test('Formats medium speed in KB/s', () {
      expect(formatSpeed(2048), '2.0 KB/s');
    });
    
    test('Formats fast speed in MB/s', () {
      expect(formatSpeed(1048576), '1.0 MB/s');
    });
  });
  
  group('ETA Calculation Tests', () {
    String formatETA(int seconds) {
      if (seconds < 60) return '${seconds}s';
      if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
      return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
    }
    
    test('Formats seconds', () {
      expect(formatETA(45), '45s');
    });
    
    test('Formats minutes and seconds', () {
      expect(formatETA(125), '2m 5s');
    });
    
    test('Formats hours and minutes', () {
      expect(formatETA(3725), '1h 2m');
    });
  });
}
