import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../features/clipboard_sync/models/clipboard_item.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    // SQLite is not supported on web
    if (kIsWeb) {
      throw UnsupportedError('Database not supported on web platform');
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'near_transfer.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Old history table
    await db.execute('''
      CREATE TABLE history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        size INTEGER,
        path TEXT,
        timestamp INTEGER,
        type TEXT
      )
    ''');
    
    // New received_files table
    await db.execute('''
      CREATE TABLE received_files(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fileName TEXT,
        filePath TEXT,
        fileSize INTEGER,
        senderName TEXT,
        receivedAt INTEGER
      )
    ''');
    
    // Clipboard history table
    await db.execute('''
      CREATE TABLE clipboard_history(
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        device_name TEXT,
        is_sent INTEGER DEFAULT 0,
        is_received INTEGER DEFAULT 0
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_clipboard_timestamp ON clipboard_history(timestamp DESC)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE received_files(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fileName TEXT,
          filePath TEXT,
          fileSize INTEGER,
          senderName TEXT,
          receivedAt INTEGER
        )
      ''');
    }
    
    if (oldVersion < 3) {
      // Add clipboard_history table
      await db.execute('''
        CREATE TABLE clipboard_history(
          id TEXT PRIMARY KEY,
          content TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          device_name TEXT,
          is_sent INTEGER DEFAULT 0,
          is_received INTEGER DEFAULT 0
        )
      ''');
      
      await db.execute('''
        CREATE INDEX idx_clipboard_timestamp ON clipboard_history(timestamp DESC)
      ''');
    }
  }

  Future<int> insertFile(PlatformFile file, String type) async {
    final db = await database;
    return await db.insert('history', {
      'name': file.name,
      'size': file.size,
      'path': file.path ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': type, // 'sent' or 'received'
    });
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    // Return empty list on web since SQLite is not supported
    if (kIsWeb) return [];
    final db = await database;
    return await db.query('history', orderBy: 'timestamp DESC');
  }

  Future<void> insertReceivedFile({
    required String fileName,
    required String filePath,
    required int fileSize,
    String? senderName,
  }) async {
    final db = await database;
    await db.insert(
      'received_files',
      {
        'fileName': fileName,
        'filePath': filePath,
        'fileSize': fileSize,
        'senderName': senderName ?? 'Unknown',
        'receivedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getReceivedFiles() async {
    final db = await database;
    return await db.query(
      'received_files',
      orderBy: 'receivedAt DESC',
    );
  }

  Future<void> deleteReceivedFile(int id) async {
    final db = await database;
    await db.delete(
      'received_files',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Clipboard methods
  Future<void> insertClipboardItem(ClipboardItem item) async {
    final db = await database;
    await db.insert(
      'clipboard_history',
      item.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ClipboardItem>> getClipboardHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clipboard_history',
      orderBy: 'timestamp DESC',
      limit: 10,
    );

    return maps.map((map) => ClipboardItem.fromJson(map)).toList();
  }

  Future<void> deleteClipboardItem(String id) async {
    final db = await database;
    await db.delete(
      'clipboard_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearClipboardHistory() async {
    final db = await database;
    await db.delete('clipboard_history');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
