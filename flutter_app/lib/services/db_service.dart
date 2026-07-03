import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/transaction.dart';

/// Handles all local SQLite database operations for offline caching.
class DbService {
  DbService._();
  static final DbService instance = DbService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'finance_tracker.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create Categories Table
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            color TEXT NOT NULL,
            icon TEXT NOT NULL,
            is_default INTEGER NOT NULL,
            user_id INTEGER
          )
        ''');

        // Create Transactions Table
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            description TEXT NOT NULL,
            note TEXT,
            date TEXT NOT NULL,
            receipt_image TEXT,
            is_synced INTEGER NOT NULL DEFAULT 1,
            sync_action TEXT NOT NULL DEFAULT 'none'
          )
        ''');
      },
    );
  }

  // ===================== CATEGORIES =====================

  /// Caches the category list locally by clearing the table and inserting new items.
  Future<void> saveCategories(List<Category> categories) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('categories');
      for (final c in categories) {
        await txn.insert('categories', {
          'id': c.id,
          'name': c.name,
          'color': c.color,
          'icon': c.icon,
          'is_default': c.isDefault ? 1 : 0,
          'user_id': null, // category has no user_id if default
        });
      }
    });
  }

  /// Fetches cached categories.
  Future<List<Category>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories', orderBy: 'is_default DESC, name ASC');

    return List.generate(maps.length, (i) {
      return Category(
        id: maps[i]['id'] as int,
        name: maps[i]['name'] as String,
        color: maps[i]['color'] as String,
        icon: maps[i]['icon'] as String,
        isDefault: maps[i]['is_default'] == 1,
      );
    });
  }

  // ===================== TRANSACTIONS =====================

  /// Saves freshly fetched server transactions.
  /// Overwrites only the synced rows in local database (preserving any local offline pending ones).
  Future<void> saveSyncedTransactions(List<TransactionModel> transactions) async {
    final db = await database;
    await db.transaction((txn) async {
      // Clear old synced transactions (preserving unsynced / offline modifications)
      await txn.delete('transactions', where: 'is_synced = ?', whereArgs: [1]);

      for (final t in transactions) {
        await txn.insert('transactions', {
          'id': t.id,
          'category_id': t.categoryId,
          'type': t.type,
          'amount': t.amount,
          'description': t.description,
          'note': t.note,
          'date': t.date.toIso8601String(),
          'receipt_image': t.receiptImage,
          'is_synced': 1,
          'sync_action': 'none',
        });
      }
    });
  }

  /// Fetches all transactions (both synced and offline-pending).
  /// Excludes deleted tombstones (`sync_action = 'delete'`).
  Future<List<TransactionModel>> getTransactions() async {
    final db = await database;
    
    // Join transactions with categories to populate nested Category object in TransactionModel
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT t.*, c.name as cat_name, c.color as cat_color, c.icon as cat_icon, c.is_default as cat_is_default
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.sync_action != 'delete'
      ORDER BY t.date DESC, t.id DESC
    ''');

    return List.generate(maps.length, (i) {
      final hasCategory = maps[i]['category_id'] != null && maps[i]['cat_name'] != null;
      return TransactionModel(
        id: maps[i]['id'] as int,
        categoryId: maps[i]['category_id'] as int?,
        type: maps[i]['type'] as String,
        amount: maps[i]['amount'] as double,
        description: maps[i]['description'] as String,
        note: maps[i]['note'] as String?,
        date: DateTime.tryParse(maps[i]['date'] as String) ?? DateTime.now(),
        receiptImage: maps[i]['receipt_image'] as String?,
        category: hasCategory
            ? Category(
                id: maps[i]['category_id'] as int,
                name: maps[i]['cat_name'] as String,
                color: maps[i]['cat_color'] as String,
                icon: maps[i]['cat_icon'] as String,
                isDefault: maps[i]['cat_is_default'] == 1,
              )
            : null,
      );
    });
  }

  /// Inserts a transaction record locally.
  /// Returns the auto-generated or specified ID.
  Future<int> insertTransaction(Map<String, dynamic> row, {int isSynced = 1, String syncAction = 'none'}) async {
    final db = await database;
    return await db.insert('transactions', {
      ...row,
      'is_synced': isSynced,
      'sync_action': syncAction,
    });
  }

  /// Updates a transaction's sync status (used when offline items are uploaded).
  Future<void> updateTransactionSyncStatus(int localId, int serverId) async {
    final db = await database;
    await db.update(
      'transactions',
      {
        'id': serverId, // overwrite the temporary local ID with the real server ID
        'is_synced': 1,
        'sync_action': 'none',
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Handles transaction deletion.
  /// If it was already synced on the server, we mark it as 'delete' (tombstone).
  /// If it was an unsynced local transaction, we delete it directly from SQLite.
  Future<void> markDeleted(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.query('transactions', columns: ['is_synced'], where: 'id = ?', whereArgs: [id]);
    
    if (res.isNotEmpty && res.first['is_synced'] == 0) {
      // Unsynced offline transaction: delete completely from local DB
      await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    } else {
      // Synced transaction: keep as tombstone so we can notify server once net returns
      await db.update(
        'transactions',
        {'sync_action': 'delete'},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Permanently deletes a transaction from SQLite (called after server confirmation).
  Future<void> deletePermanently(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Gets all transactions created offline that are pending upload.
  Future<List<Map<String, dynamic>>> getPendingCreates() async {
    final db = await database;
    return await db.query('transactions', where: 'is_synced = 0 AND sync_action = ?', whereArgs: ['create']);
  }

  /// Gets all transaction IDs that were deleted offline.
  Future<List<int>> getPendingDeletes() async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.query('transactions', columns: ['id'], where: "sync_action = ?", whereArgs: ['delete']);
    return res.map((row) => row['id'] as int).toList();
  }

  /// Clears all local data (used on logout).
  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('categories');
    });
  }
}
