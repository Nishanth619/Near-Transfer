class DiscoveredDevice {
  final String deviceId;
  final String deviceName;
  final String ip;
  final int port;
  final DateTime lastSeen;
  final bool isShaking;
  final int? shakeTimestamp;

  DiscoveredDevice({
    required this.deviceId,
    required this.deviceName,
    required this.ip,
    required this.port,
    required this.lastSeen,
    this.isShaking = false,
    this.shakeTimestamp,
  });

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return DiscoveredDevice(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      isShaking: json['isShaking'] as bool? ?? false,
      shakeTimestamp: json['shakeTimestamp'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'beacon',
      'deviceId': deviceId,
      'deviceName': deviceName,
      'ip': ip,
      'port': port,
      'timestamp': lastSeen.millisecondsSinceEpoch,
      'isShaking': isShaking,
      if (shakeTimestamp != null) 'shakeTimestamp': shakeTimestamp,
    };
  }

  DiscoveredDevice copyWith({
    DateTime? lastSeen,
    bool? isShaking,
    int? shakeTimestamp,
  }) {
    return DiscoveredDevice(
      deviceId: deviceId,
      deviceName: deviceName,
      ip: ip,
      port: port,
      lastSeen: lastSeen ?? this.lastSeen,
      isShaking: isShaking ?? this.isShaking,
      shakeTimestamp: shakeTimestamp ?? this.shakeTimestamp,
    );
  }

  String get timeSinceLastSeen {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }
}
