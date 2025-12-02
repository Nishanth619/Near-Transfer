class NetworkConfig {
  // Discovery
  static const String multicastGroup = '239.255.255.250';
  static const int multicastPort = 45454;
  static const int tcpPort = 45455;
  static const Duration beaconInterval = Duration(seconds: 3);
  static const Duration deviceTimeout = Duration(seconds: 10);
  
  // Timeouts
  static const Duration sessionConnectTimeout = Duration(seconds: 5);
  static const Duration webrtcTimeout = Duration(seconds: 10);
  static const int maxConnectRetries = 2;
  
  // Transfer
  static const int chunkSize = 65536; // 64 KB
  static const int maxBufferedAmount = 1048576; // 1 MB
  
  // STUN
  static const String stunServer = 'stun:stun.l.google.com:19302';
}
