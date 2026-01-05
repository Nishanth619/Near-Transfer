import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

class SignalingService {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  // Generate a simple 6-digit connection code for display
  String generateConnectionCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Create compact connection data with base64 encoding
  String createConnectionData(String code, webrtc.RTCSessionDescription sdp, String type) {
    final data = {
      'code': code,
      'type': type,
      'sdp': sdp.sdp,
    };
    final jsonStr = jsonEncode(data);
    // Use base64 to make it more compact
    return base64Encode(utf8.encode(jsonStr));
  }

  // Parse connection data
  Map<String, dynamic> parseConnectionData(String encodedData) {
    try {
      final jsonStr = utf8.decode(base64Decode(encodedData));
      return jsonDecode(jsonStr);
    } catch (e) {
      // If it's just a 6-digit code, return it as is
      if (encodedData.length == 6 && int.tryParse(encodedData) != null) {
        return {'code': encodedData, 'type': 'code-only'};
      }
      rethrow;
    }
  }

  // Create offer data (compact)
  String createOfferData(webrtc.RTCSessionDescription offer) {
    final data = {
      'type': 'offer',
      'sdp': offer.sdp,
    };
    return jsonEncode(data);
  }

  // Create answer data (compact)
  String createAnswerData(webrtc.RTCSessionDescription answer) {
    final data = {
      'type': 'answer',
      'sdp': answer.sdp,
    };
    return jsonEncode(data);
  }

  Map<String, dynamic> parseSignalingData(String data) {
    return jsonDecode(data);
  }
}
