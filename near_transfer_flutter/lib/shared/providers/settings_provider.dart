import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  // Storage Keys
  static const String _deviceNameKey = 'device_name';
  static const String _downloadPathKey = 'download_path';
  static const String _autoAcceptKey = 'auto_accept';
  static const String _showNotificationsKey = 'show_notifications';
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _vibrationEnabledKey = 'vibration_enabled';
  static const String _wifiOnlyKey = 'wifi_only';
  static const String _keepScreenOnKey = 'keep_screen_on';
  static const String _compressionEnabledKey = 'compression_enabled';
  static const String _encryptionEnabledKey = 'encryption_enabled';
  static const String _autoConnectKey = 'auto_connect';
  static const String _discoveryVisibleKey = 'discovery_visible';
  static const String _maxConcurrentTransfersKey = 'max_concurrent_transfers';
  static const String _chunkSizeKey = 'chunk_size';
  static const String _deleteAfterSendKey = 'delete_after_send';
  static const String _autoOpenFilesKey = 'auto_open_files';
  static const String _showPreviewKey = 'show_preview';
  static const String _saveToGalleryKey = 'save_to_gallery';

  // Default values
  String _deviceName = 'My Device';
  String _downloadPath = '/storage/emulated/0/Download/NearTransfer';
  bool _autoAccept = false;
  bool _showNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _wifiOnly = true;
  bool _keepScreenOn = true;
  bool _compressionEnabled = false;
  bool _encryptionEnabled = true;
  bool _autoConnect = false;
  bool _discoveryVisible = true;
  int _maxConcurrentTransfers = 3;
  int _chunkSize = 1024; // KB
  bool _deleteAfterSend = false;
  bool _autoOpenFiles = false;
  bool _showPreview = true;
  bool _saveToGallery = true;

  // Getters
  String get deviceName => _deviceName;
  String get downloadPath => _downloadPath;
  bool get autoAccept => _autoAccept;
  bool get showNotifications => _showNotifications;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get wifiOnly => _wifiOnly;
  bool get keepScreenOn => _keepScreenOn;
  bool get compressionEnabled => _compressionEnabled;
  bool get encryptionEnabled => _encryptionEnabled;
  bool get autoConnect => _autoConnect;
  bool get discoveryVisible => _discoveryVisible;
  int get maxConcurrentTransfers => _maxConcurrentTransfers;
  int get chunkSize => _chunkSize;
  bool get deleteAfterSend => _deleteAfterSend;
  bool get autoOpenFiles => _autoOpenFiles;
  bool get showPreview => _showPreview;
  bool get saveToGallery => _saveToGallery;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _deviceName = prefs.getString(_deviceNameKey) ?? 'My Device';
      _downloadPath = prefs.getString(_downloadPathKey) ?? '/storage/emulated/0/Download/NearTransfer';
      _autoAccept = prefs.getBool(_autoAcceptKey) ?? false;
      _showNotifications = prefs.getBool(_showNotificationsKey) ?? true;
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      _vibrationEnabled = prefs.getBool(_vibrationEnabledKey) ?? true;
      _wifiOnly = prefs.getBool(_wifiOnlyKey) ?? true;
      _keepScreenOn = prefs.getBool(_keepScreenOnKey) ?? true;
      _compressionEnabled = prefs.getBool(_compressionEnabledKey) ?? false;
      _encryptionEnabled = prefs.getBool(_encryptionEnabledKey) ?? true;
      _autoConnect = prefs.getBool(_autoConnectKey) ?? false;
      _discoveryVisible = prefs.getBool(_discoveryVisibleKey) ?? true;
      _maxConcurrentTransfers = prefs.getInt(_maxConcurrentTransfersKey) ?? 3;
      _chunkSize = prefs.getInt(_chunkSizeKey) ?? 1024;
      _deleteAfterSend = prefs.getBool(_deleteAfterSendKey) ?? false;
      _autoOpenFiles = prefs.getBool(_autoOpenFilesKey) ?? false;
      _showPreview = prefs.getBool(_showPreviewKey) ?? true;
      _saveToGallery = prefs.getBool(_saveToGalleryKey) ?? true;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  // Setters with persistence
  Future<void> setDeviceName(String name) async {
    _deviceName = name;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceNameKey, name);
  }

  Future<void> setDownloadPath(String path) async {
    _downloadPath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_downloadPathKey, path);
  }

  Future<void> setAutoAccept(bool value) async {
    _autoAccept = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoAcceptKey, value);
  }

  Future<void> setShowNotifications(bool value) async {
    _showNotifications = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showNotificationsKey, value);
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationEnabledKey, value);
  }

  Future<void> setWifiOnly(bool value) async {
    _wifiOnly = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiOnlyKey, value);
  }

  Future<void> setKeepScreenOn(bool value) async {
    _keepScreenOn = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepScreenOnKey, value);
  }

  Future<void> setCompressionEnabled(bool value) async {
    _compressionEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_compressionEnabledKey, value);
  }

  Future<void> setEncryptionEnabled(bool value) async {
    _encryptionEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_encryptionEnabledKey, value);
  }

  Future<void> setAutoConnect(bool value) async {
    _autoConnect = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoConnectKey, value);
  }

  Future<void> setDiscoveryVisible(bool value) async {
    _discoveryVisible = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_discoveryVisibleKey, value);
  }

  Future<void> setMaxConcurrentTransfers(int value) async {
    _maxConcurrentTransfers = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxConcurrentTransfersKey, value);
  }

  Future<void> setChunkSize(int value) async {
    _chunkSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_chunkSizeKey, value);
  }

  Future<void> setDeleteAfterSend(bool value) async {
    _deleteAfterSend = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deleteAfterSendKey, value);
  }

  Future<void> setAutoOpenFiles(bool value) async {
    _autoOpenFiles = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoOpenFilesKey, value);
  }

  Future<void> setShowPreview(bool value) async {
    _showPreview = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showPreviewKey, value);
  }

  Future<void> setSaveToGallery(bool value) async {
    _saveToGallery = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_saveToGalleryKey, value);
  }

  // Reset all settings to defaults
  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    
    _deviceName = 'My Device';
    _downloadPath = '/storage/emulated/0/Download/NearTransfer';
    _autoAccept = false;
    _showNotifications = true;
    _soundEnabled = true;
    _vibrationEnabled = true;
    _wifiOnly = true;
    _keepScreenOn = true;
    _compressionEnabled = false;
    _encryptionEnabled = true;
    _autoConnect = false;
    _discoveryVisible = true;
    _maxConcurrentTransfers = 3;
    _chunkSize = 1024;
    _deleteAfterSend = false;
    _autoOpenFiles = false;
    _showPreview = true;
    _saveToGallery = true;

    // Clear all saved settings
    await prefs.remove(_deviceNameKey);
    await prefs.remove(_downloadPathKey);
    await prefs.remove(_autoAcceptKey);
    await prefs.remove(_showNotificationsKey);
    await prefs.remove(_soundEnabledKey);
    await prefs.remove(_vibrationEnabledKey);
    await prefs.remove(_wifiOnlyKey);
    await prefs.remove(_keepScreenOnKey);
    await prefs.remove(_compressionEnabledKey);
    await prefs.remove(_encryptionEnabledKey);
    await prefs.remove(_autoConnectKey);
    await prefs.remove(_discoveryVisibleKey);
    await prefs.remove(_maxConcurrentTransfersKey);
    await prefs.remove(_chunkSizeKey);
    await prefs.remove(_deleteAfterSendKey);
    await prefs.remove(_autoOpenFilesKey);
    await prefs.remove(_showPreviewKey);
    await prefs.remove(_saveToGalleryKey);

    notifyListeners();
  }
}
