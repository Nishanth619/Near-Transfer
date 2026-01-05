import 'dart:io';

class NetworkUtils {
  static Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          
          // Skip loopback
          if (addr.isLoopback) continue;
          
          // Accept common private IP ranges (WiFi/hotspot)
          if (addr.address.startsWith('192.168.') ||
              addr.address.startsWith('10.') ||
              addr.address.startsWith('172.')) {
            return addr.address;
          }
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  static String createHostCandidate(String ipAddress, int port, int component) {
    // Create a host candidate string in the format WebRTC expects
    // Example: candidate:1234567890 1 udp 2122260223 192.168.1.100 54321 typ host generation 0
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final priority = 2122260223; // High priority for host candidates
    
    return 'candidate:$timestamp $component udp $priority $ipAddress $port typ host generation 0';
  }
}
