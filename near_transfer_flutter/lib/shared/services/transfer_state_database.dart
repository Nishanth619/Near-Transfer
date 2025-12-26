import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transfer_state.dart';

/// Database service for managing resumable transfer states
class TransferStateDatabase {
  static final TransferStateDatabase instance = TransferStateDatabase._();
  static Database? _database;

  TransferStateDatabase._();

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'transfer_states.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  /// Create database tables
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transfer_states (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        partner_device_id TEXT NOT NULL,
        partner_device_name TEXT NOT NULL,
        partner_ip TEXT NOT NULL,
        
        file_name TEXT NOT NULL,
        file_path TEXT,
        file_size INTEGER NOT NULL,
        file_hash TEXT,
        
        total_chunks INTEGER NOT NULL,
        completed_chunks INTEGER NOT NULL,
        bytes_transferred INTEGER NOT NULL,
        
        status TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        last_updated INTEGER NOT NULL,
        completed_at INTEGER,
        
        chunk_size INTEGER NOT NULL,
        last_chunk_seq INTEGER NOT NULL,
        
        batch_id TEXT,
        file_index INTEGER,
        total_files_in_batch INTEGER
      )
    ''');

    // Create indexes for faster queries
    await db.execute('''
      CREATE INDEX idx_transfer_status ON transfer_states(status)
    ''');

    await db.execute('''
      CREATE INDEX idx_transfer_partner ON transfer_states(partner_device_id, status)
    ''');

    await db.execute('''
      CREATE INDEX idx_transfer_batch ON transfer_states(batch_id)
    ''');

    print('✅ Transfer state database created');
  }

  /// Insert a new transfer state
  Future<void> insertTransferState(TransferState state) async {
    final db = await database;
    await db.insert(
      'transfer_states',
      state.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('💾 Saved transfer state: ${state.id}');
  }

  /// Update an existing transfer state
  Future<void> updateTransferState(TransferState state) async {
    final db = await database;
    await db.update(
      'transfer_states',
      state.toMap(),
      where: 'id = ?',
      whereArgs: [state.id],
    );
  }

  /// Get a transfer state by ID
  Future<TransferState?> getTransferState(String id) async {
    final db = await database;
    final maps = await db.query(
      'transfer_states',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return TransferState.fromMap(maps.first);
  }

  /// Get all resumable transfers (paused or in_progress)
  Future<List<TransferState>> getResumableTransfers() async {
    final db = await database;
    final maps = await db.query(
      'transfer_states',
      where: 'status IN (?, ?)',
      whereArgs: ['paused', 'in_progress'],
      orderBy: 'last_updated DESC',
    );

    return maps.map((map) => TransferState.fromMap(map)).toList();
  }

  /// Get transfers for a specific partner device
  Future<List<TransferState>> getPartnerTransfers(String deviceId,
      {String? status}) async {
    final db = await database;

    final maps = status != null
        ? await db.query(
            'transfer_states',
            where: 'partner_device_id = ? AND status = ?',
            whereArgs: [deviceId, status],
            orderBy: 'last_updated DESC',
          )
        : await db.query(
            'transfer_states',
            where: 'partner_device_id = ?',
            whereArgs: [deviceId],
            orderBy: 'last_updated DESC',
          );

    return maps.map((map) => TransferState.fromMap(map)).toList();
  }

  /// Get all transfers in a batch
  Future<List<TransferState>> getBatchTransfers(String batchId) async {
    final db = await database;
    final maps = await db.query(
      'transfer_states',
      where: 'batch_id = ?',
      whereArgs: [batchId],
      orderBy: 'file_index ASC',
    );

    return maps.map((map) => TransferState.fromMap(map)).toList();
  }

  /// Delete a transfer state
  Future<void> deleteTransferState(String id) async {
    final db = await database;
    await db.delete(
      'transfer_states',
      where: 'id = ?',
      whereArgs: [id],
    );
    print('🗑️ Deleted transfer state: $id');
  }

  /// Delete all completed transfers
  Future<int> deleteCompletedTransfers() async {
    final db = await database;
    final count = await db.delete(
      'transfer_states',
      where: 'status = ?',
      whereArgs: ['completed'],
    );
    print('🗑️ Deleted $count completed transfers');
    return count;
  }

  /// Delete transfers older than specified days
  Future<int> deleteOldTransfers({int days = 7}) async {
    final db = await database;
    final cutoffTime =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

    final count = await db.delete(
      'transfer_states',
      where: 'last_updated < ? AND status IN (?, ?)',
      whereArgs: [cutoffTime, 'completed', 'failed'],
    );
    print('🗑️ Deleted $count old transfers (>$days days)');
    return count;
  }

  /// Get total number of transfers by status
  Future<Map<String, int>> getTransferStats() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT status, COUNT(*) as count
      FROM transfer_states
      GROUP BY status
    ''');

    final stats = <String, int>{};
    for (final row in result) {
      stats[row['status'] as String] = row['count'] as int;
    }
    return stats;
  }

  /// Update transfer progress (optimized for frequent updates)
  Future<void> updateProgress({
    required String id,
    required int completedChunks,
    required int bytesTransferred,
    required int lastChunkSeq,
  }) async {
    final db = await database;
    await db.update(
      'transfer_states',
      {
        'completed_chunks': completedChunks,
        'bytes_transferred': bytesTransferred,
        'last_chunk_seq': lastChunkSeq,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark transfer as paused
  Future<void> pauseTransfer(String id) async {
    final db = await database;
    await db.update(
      'transfer_states',
      {
        'status': 'paused',
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    print('⏸️ Transfer paused: $id');
  }

  /// Mark transfer as completed
  Future<void> completeTransfer(String id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'transfer_states',
      {
        'status': 'completed',
        'completed_at': now,
        'last_updated': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    print('✅ Transfer completed: $id');
  }

  /// Mark transfer as failed
  Future<void> failTransfer(String id) async {
    final db = await database;
    await db.update(
      'transfer_states',
      {
        'status': 'failed',
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    print('❌ Transfer failed: $id');
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
