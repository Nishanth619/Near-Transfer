import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:call_log/call_log.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:device_apps/device_apps.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

/// Data category for phone clone
enum CloneCategory {
  contacts,
  callLogs,
  sms,
  photos,
  videos,
  apps,
}

extension CloneCategoryExtension on CloneCategory {
  String get displayName {
    switch (this) {
      case CloneCategory.contacts: return 'Contacts';
      case CloneCategory.callLogs: return 'Call Logs';
      case CloneCategory.sms: return 'Messages';
      case CloneCategory.photos: return 'Photos';
      case CloneCategory.videos: return 'Videos';
      case CloneCategory.apps: return 'Apps';
    }
  }

  String get icon {
    switch (this) {
      case CloneCategory.contacts: return '👤';
      case CloneCategory.callLogs: return '📞';
      case CloneCategory.sms: return '💬';
      case CloneCategory.photos: return '📷';
      case CloneCategory.videos: return '🎥';
      case CloneCategory.apps: return '📱';
    }
  }
}

/// Data stats for a category
class CategoryStats {
  final CloneCategory category;
  final int count;
  final int sizeBytes;
  final bool hasPermission;
  final String? error;

  CategoryStats({
    required this.category,
    required this.count,
    required this.sizeBytes,
    required this.hasPermission,
    this.error,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Clone data package for transfer
class CloneDataPackage {
  final List<Map<String, dynamic>> contacts;
  final List<Map<String, dynamic>> callLogs;
  final List<Map<String, dynamic>> smsMessages;
  final List<String> mediaPaths; // Paths to media files
  final List<Map<String, dynamic>> apps;
  final Map<CloneCategory, int> counts;

  CloneDataPackage({
    this.contacts = const [],
    this.callLogs = const [],
    this.smsMessages = const [],
    this.mediaPaths = const [],
    this.apps = const [],
    this.counts = const {},
  });

  Map<String, dynamic> toJson() => {
    'contacts': contacts,
    'callLogs': callLogs,
    'smsMessages': smsMessages,
    'mediaPaths': mediaPaths,
    'apps': apps,
    'counts': counts.map((k, v) => MapEntry(k.name, v)),
  };
}

/// Service for collecting and managing phone data for cloning
class PhoneDataService {
  static final PhoneDataService _instance = PhoneDataService._internal();
  factory PhoneDataService() => _instance;
  PhoneDataService._internal();

  // Cached data
  List<Contact>? _contacts;
  Iterable<CallLogEntry>? _callLogs;
  List<SmsMessage>? _smsMessages;
  List<AssetEntity>? _photos;
  List<AssetEntity>? _videos;
  List<Application>? _apps;

  /// Request all needed permissions
  Future<Map<CloneCategory, bool>> requestPermissions() async {
    final results = <CloneCategory, bool>{};
    
    // Contacts
    results[CloneCategory.contacts] = await FlutterContacts.requestPermission();
    
    // Call logs
    results[CloneCategory.callLogs] = await Permission.phone.request().isGranted;
    
    // SMS
    results[CloneCategory.sms] = await Permission.sms.request().isGranted;
    
    // Photos & Videos
    final photoPermission = await PhotoManager.requestPermissionExtend();
    results[CloneCategory.photos] = photoPermission.isAuth;
    results[CloneCategory.videos] = photoPermission.isAuth;
    
    // Apps (no permission needed for listing)
    results[CloneCategory.apps] = true;
    
    return results;
  }

  /// Get stats for all categories
  Future<List<CategoryStats>> getCategoryStats() async {
    final stats = <CategoryStats>[];
    
    // Contacts
    try {
      if (await FlutterContacts.requestPermission()) {
        final contacts = await FlutterContacts.getContacts(withProperties: true);
        _contacts = contacts;
        stats.add(CategoryStats(
          category: CloneCategory.contacts,
          count: contacts.length,
          sizeBytes: _estimateContactsSize(contacts),
          hasPermission: true,
        ));
      } else {
        stats.add(CategoryStats(
          category: CloneCategory.contacts,
          count: 0,
          sizeBytes: 0,
          hasPermission: false,
        ));
      }
    } catch (e) {
      stats.add(CategoryStats(
        category: CloneCategory.contacts,
        count: 0,
        sizeBytes: 0,
        hasPermission: false,
        error: e.toString(),
      ));
    }
    
    // Call Logs
    try {
      if (await Permission.phone.isGranted) {
        final calls = await CallLog.get();
        _callLogs = calls;
        stats.add(CategoryStats(
          category: CloneCategory.callLogs,
          count: calls.length,
          sizeBytes: calls.length * 200, // Estimate ~200 bytes per entry
          hasPermission: true,
        ));
      } else {
        stats.add(CategoryStats(
          category: CloneCategory.callLogs,
          count: 0,
          sizeBytes: 0,
          hasPermission: false,
        ));
      }
    } catch (e) {
      stats.add(CategoryStats(
        category: CloneCategory.callLogs,
        count: 0,
        sizeBytes: 0,
        hasPermission: false,
        error: e.toString(),
      ));
    }
    
    // SMS
    try {
      if (await Permission.sms.isGranted) {
        final query = SmsQuery();
        final messages = await query.getAllSms;
        _smsMessages = messages;
        stats.add(CategoryStats(
          category: CloneCategory.sms,
          count: messages.length,
          sizeBytes: _estimateSmsSize(messages),
          hasPermission: true,
        ));
      } else {
        stats.add(CategoryStats(
          category: CloneCategory.sms,
          count: 0,
          sizeBytes: 0,
          hasPermission: false,
        ));
      }
    } catch (e) {
      stats.add(CategoryStats(
        category: CloneCategory.sms,
        count: 0,
        sizeBytes: 0,
        hasPermission: false,
        error: e.toString(),
      ));
    }
    
    // Photos
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (permission.isAuth) {
        final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
        int photoCount = 0;
        int photoSize = 0;
        final allPhotos = <AssetEntity>[];
        
        for (final album in albums) {
          final assets = await album.getAssetListRange(start: 0, end: await album.assetCountAsync);
          for (final asset in assets) {
            photoCount++;
            photoSize += asset.size.width.toInt() * asset.size.height.toInt() ~/ 4; // Rough estimate
            allPhotos.add(asset);
          }
        }
        _photos = allPhotos;
        
        stats.add(CategoryStats(
          category: CloneCategory.photos,
          count: photoCount,
          sizeBytes: photoSize,
          hasPermission: true,
        ));
      } else {
        stats.add(CategoryStats(
          category: CloneCategory.photos,
          count: 0,
          sizeBytes: 0,
          hasPermission: false,
        ));
      }
    } catch (e) {
      stats.add(CategoryStats(
        category: CloneCategory.photos,
        count: 0,
        sizeBytes: 0,
        hasPermission: false,
        error: e.toString(),
      ));
    }
    
    // Videos
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (permission.isAuth) {
        final albums = await PhotoManager.getAssetPathList(type: RequestType.video);
        int videoCount = 0;
        int videoSize = 0;
        final allVideos = <AssetEntity>[];
        
        for (final album in albums) {
          final assets = await album.getAssetListRange(start: 0, end: await album.assetCountAsync);
          for (final asset in assets) {
            videoCount++;
            final file = await asset.file;
            if (file != null) {
              videoSize += await file.length();
            }
            allVideos.add(asset);
          }
        }
        _videos = allVideos;
        
        stats.add(CategoryStats(
          category: CloneCategory.videos,
          count: videoCount,
          sizeBytes: videoSize,
          hasPermission: true,
        ));
      } else {
        stats.add(CategoryStats(
          category: CloneCategory.videos,
          count: 0,
          sizeBytes: 0,
          hasPermission: false,
        ));
      }
    } catch (e) {
      stats.add(CategoryStats(
        category: CloneCategory.videos,
        count: 0,
        sizeBytes: 0,
        hasPermission: false,
        error: e.toString(),
      ));
    }
    
    // Apps
    try {
      final apps = await DeviceApps.getInstalledApplications(
        includeSystemApps: false,
        includeAppIcons: false,
      );
      _apps = apps;
      stats.add(CategoryStats(
        category: CloneCategory.apps,
        count: apps.length,
        sizeBytes: 0, // Apps list is just metadata
        hasPermission: true,
      ));
    } catch (e) {
      stats.add(CategoryStats(
        category: CloneCategory.apps,
        count: 0,
        sizeBytes: 0,
        hasPermission: true,
        error: e.toString(),
      ));
    }
    
    return stats;
  }

  /// Collect data for selected categories
  Future<CloneDataPackage> collectData(
    Set<CloneCategory> categories, {
    Function(CloneCategory, double)? onProgress,
  }) async {
    final contactsList = <Map<String, dynamic>>[];
    final callLogsList = <Map<String, dynamic>>[];
    final smsList = <Map<String, dynamic>>[];
    final mediaPaths = <String>[];
    final appsList = <Map<String, dynamic>>[];
    final counts = <CloneCategory, int>{};
    
    // Contacts
    if (categories.contains(CloneCategory.contacts)) {
      onProgress?.call(CloneCategory.contacts, 0.0);
      final contacts = _contacts ?? await FlutterContacts.getContacts(withProperties: true);
      for (int i = 0; i < contacts.length; i++) {
        final c = contacts[i];
        contactsList.add({
          'displayName': c.displayName,
          'phones': c.phones.map((p) => {'number': p.number, 'label': p.label.name}).toList(),
          'emails': c.emails.map((e) => {'address': e.address, 'label': e.label.name}).toList(),
          'organizations': c.organizations.map((o) => {'company': o.company, 'title': o.title}).toList(),
        });
        if (i % 50 == 0) {
          onProgress?.call(CloneCategory.contacts, i / contacts.length);
        }
      }
      counts[CloneCategory.contacts] = contacts.length;
      onProgress?.call(CloneCategory.contacts, 1.0);
    }
    
    // Call Logs
    if (categories.contains(CloneCategory.callLogs)) {
      onProgress?.call(CloneCategory.callLogs, 0.0);
      final calls = _callLogs ?? await CallLog.get();
      final callsList = calls.toList();
      for (int i = 0; i < callsList.length; i++) {
        final c = callsList[i];
        callLogsList.add({
          'name': c.name,
          'number': c.number,
          'type': c.callType?.name,
          'duration': c.duration,
          'timestamp': c.timestamp,
        });
        if (i % 100 == 0) {
          onProgress?.call(CloneCategory.callLogs, i / callsList.length);
        }
      }
      counts[CloneCategory.callLogs] = callsList.length;
      onProgress?.call(CloneCategory.callLogs, 1.0);
    }
    
    // SMS
    if (categories.contains(CloneCategory.sms)) {
      onProgress?.call(CloneCategory.sms, 0.0);
      final messages = _smsMessages ?? await SmsQuery().getAllSms;
      for (int i = 0; i < messages.length; i++) {
        final m = messages[i];
        smsList.add({
          'address': m.address,
          'body': m.body,
          'date': m.date?.millisecondsSinceEpoch,
          'kind': m.kind?.name,
        });
        if (i % 100 == 0) {
          onProgress?.call(CloneCategory.sms, i / messages.length);
        }
      }
      counts[CloneCategory.sms] = messages.length;
      onProgress?.call(CloneCategory.sms, 1.0);
    }
    
    // Photos
    if (categories.contains(CloneCategory.photos)) {
      onProgress?.call(CloneCategory.photos, 0.0);
      final photos = _photos ?? [];
      for (int i = 0; i < photos.length; i++) {
        final file = await photos[i].file;
        if (file != null) {
          mediaPaths.add(file.path);
        }
        if (i % 20 == 0) {
          onProgress?.call(CloneCategory.photos, i / photos.length);
        }
      }
      counts[CloneCategory.photos] = photos.length;
      onProgress?.call(CloneCategory.photos, 1.0);
    }
    
    // Videos
    if (categories.contains(CloneCategory.videos)) {
      onProgress?.call(CloneCategory.videos, 0.0);
      final videos = _videos ?? [];
      for (int i = 0; i < videos.length; i++) {
        final file = await videos[i].file;
        if (file != null) {
          mediaPaths.add(file.path);
        }
        if (i % 10 == 0) {
          onProgress?.call(CloneCategory.videos, i / videos.length);
        }
      }
      counts[CloneCategory.videos] = videos.length;
      onProgress?.call(CloneCategory.videos, 1.0);
    }
    
    // Apps
    if (categories.contains(CloneCategory.apps)) {
      onProgress?.call(CloneCategory.apps, 0.0);
      final apps = _apps ?? await DeviceApps.getInstalledApplications(
        includeSystemApps: false,
        includeAppIcons: false,
      );
      for (final app in apps) {
        appsList.add({
          'appName': app.appName,
          'packageName': app.packageName,
          'versionName': app.versionName,
        });
      }
      counts[CloneCategory.apps] = apps.length;
      onProgress?.call(CloneCategory.apps, 1.0);
    }
    
    return CloneDataPackage(
      contacts: contactsList,
      callLogs: callLogsList,
      smsMessages: smsList,
      mediaPaths: mediaPaths,
      apps: appsList,
      counts: counts,
    );
  }

  /// Restore contacts from cloned data
  Future<int> restoreContacts(List<Map<String, dynamic>> contacts) async {
    int restored = 0;
    for (final c in contacts) {
      try {
        final contact = Contact(
          displayName: c['displayName'] ?? '',
          phones: (c['phones'] as List?)?.map((p) => Phone(p['number'] ?? '')).toList() ?? [],
          emails: (c['emails'] as List?)?.map((e) => Email(e['address'] ?? '')).toList() ?? [],
        );
        await FlutterContacts.insertContact(contact);
        restored++;
      } catch (e) {
        // Skip failed contacts
      }
    }
    return restored;
  }

  int _estimateContactsSize(List<Contact> contacts) {
    int size = 0;
    for (final c in contacts) {
      size += c.displayName.length * 2;
      for (final p in c.phones) {
        size += p.number.length * 2;
      }
      for (final e in c.emails) {
        size += e.address.length * 2;
      }
    }
    return size;
  }

  int _estimateSmsSize(List<SmsMessage> messages) {
    int size = 0;
    for (final m in messages) {
      size += (m.body?.length ?? 0) * 2;
      size += (m.address?.length ?? 0) * 2;
      size += 50; // Metadata
    }
    return size;
  }

  void clearCache() {
    _contacts = null;
    _callLogs = null;
    _smsMessages = null;
    _photos = null;
    _videos = null;
    _apps = null;
  }
}
