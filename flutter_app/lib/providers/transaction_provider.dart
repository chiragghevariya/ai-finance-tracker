import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/summary.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';

/// The type filter on the Transactions tab.
enum TypeFilter { all, income, expense }

/// Loads and holds transactions, the monthly summary, and categories.
/// Seamlessly switches between local SQLite database and online API for offline support.
class TransactionProvider extends ChangeNotifier {
  final ApiService _api;
  TransactionProvider(this._api);

  List<TransactionModel> _transactions = [];
  List<Category> _categories = [];
  MonthlySummary? _summary;
  bool _isLoading = false;
  String? _error;

  // Filters (default to the current month, "all" types).
  TypeFilter _typeFilter = TypeFilter.all;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  // ---- getters the UI reads ----
  List<TransactionModel> get transactions => _transactions;
  List<TransactionModel> get recentTransactions => _transactions.take(5).toList();
  List<Category> get categories => _categories;
  MonthlySummary get summary => _summary ?? MonthlySummary.empty(_month, _year);
  bool get isLoading => _isLoading;
  String? get error => _error;
  TypeFilter get typeFilter => _typeFilter;
  int get month => _month;
  int get year => _year;

  /// Load everything (call once when the home screen opens).
  Future<void> init() async {
    await _loadFromLocal();
    await loadCategories();
    await refresh();
  }

  /// Loads categories and transactions from the local SQLite cache.
  Future<void> _loadFromLocal() async {
    _categories = await DbService.instance.getCategories();
    
    final localList = await DbService.instance.getTransactions();
    // Filter transactions in memory by the currently active type filter
    _transactions = localList.where((t) {
      if (_typeFilter == TypeFilter.income) return t.isIncome;
      if (_typeFilter == TypeFilter.expense) return t.isExpense;
      return true;
    }).toList();

    _calculateLocalSummary();
    notifyListeners();
  }

  /// Calculates the monthly summary locally to ensure charts and balance cards match local SQLite state.
  void _calculateLocalSummary() {
    final filtered = _transactions.where((t) => t.date.month == _month && t.date.year == _year).toList();
    double totalIncome = 0;
    double totalExpense = 0;
    final Map<int, List<TransactionModel>> expByCat = {};
    List<TransactionModel> uncategorizedExp = [];

    for (final t in filtered) {
      if (t.isIncome) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
        if (t.categoryId != null) {
          expByCat.putIfAbsent(t.categoryId!, () => []).add(t);
        } else {
          uncategorizedExp.add(t);
        }
      }
    }

    final List<CategorySummary> catSummaries = [];
    expByCat.forEach((catId, list) {
      final cat = list.first.category;
      final double sum = list.fold(0.0, (val, item) => val + item.amount);
      final double percent = totalExpense > 0 ? (sum / totalExpense) * 100 : 0;
      catSummaries.add(CategorySummary(
        categoryId: catId,
        name: cat?.name ?? 'Uncategorized',
        color: cat?.color,
        icon: cat?.icon,
        total: sum,
        count: list.length,
        percentage: double.parse(percent.toStringAsFixed(1)),
      ));
    });

    if (uncategorizedExp.isNotEmpty) {
      final double sum = uncategorizedExp.fold(0.0, (val, item) => val + item.amount);
      final double percent = totalExpense > 0 ? (sum / totalExpense) * 100 : 0;
      catSummaries.add(CategorySummary(
        categoryId: null,
        name: 'Uncategorized',
        total: sum,
        count: uncategorizedExp.length,
        percentage: double.parse(percent.toStringAsFixed(1)),
      ));
    }

    catSummaries.sort((a, b) => b.total.compareTo(a.total));

    _summary = MonthlySummary(
      month: _month,
      year: _year,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: totalIncome - totalExpense,
      byCategory: catSummaries,
    );
  }

  /// Pushes any pending offline updates to the Laravel server.
  Future<void> syncPendingData() async {
    try {
      // 1. Handle pending deletes
      final pendingDeletes = await DbService.instance.getPendingDeletes();
      for (final id in pendingDeletes) {
        try {
          await _api.deleteTransaction(id);
          await DbService.instance.deletePermanently(id);
        } catch (_) {}
      }

      // 2. Handle pending creates
      final pendingCreates = await DbService.instance.getPendingCreates();
      for (final row in pendingCreates) {
        try {
          final Map<String, dynamic> body = {
            'type': row['type'],
            'amount': row['amount'],
            'description': row['description'],
            if (row['note'] != null && row['note'].toString().isNotEmpty) 'note': row['note'],
            'date': row['date'].toString().substring(0, 10), // YYYY-MM-DD format
            if (row['category_id'] != null) 'category_id': row['category_id'],
          };

          List<int>? imageBytes;
          if (row['receipt_image'] != null && row['receipt_image'].toString().isNotEmpty) {
            final file = File(row['receipt_image'].toString());
            if (await file.exists()) {
              imageBytes = await file.readAsBytes();
            }
          }

          final serverResponse = await _api.createTransaction(body, imageBytes: imageBytes);
          final serverId = serverResponse['id'] as int;

          // Replace temp local SQLite row with real server ID and sync status
          await DbService.instance.updateTransactionSyncStatus(row['id'] as int, serverId);
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Load the category list (used by the add-transaction form & charts).
  Future<void> loadCategories() async {
    _categories = await DbService.instance.getCategories();
    notifyListeners();

    try {
      final list = await _api.getCategories();
      final fetchedCategories = list
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
      
      await DbService.instance.saveCategories(fetchedCategories);
      _categories = fetchedCategories;
      notifyListeners();
    } catch (_) {
      // Non-fatal offline fail: continue using cached categories
    }
  }

  /// Re-fetch transactions + summary for the current filters.
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Render local DB data first to ensure responsiveness
    await _loadFromLocal();

    try {
      // Try to push local offline creations/deletions
      await syncPendingData();

      // Fetch latest synced data
      await Future.wait([_fetchTransactionsOnline(), _fetchSummaryOnline()]);

      // Cache the fresh transactions
      await DbService.instance.saveSyncedTransactions(_transactions);
      
      _isLoading = false;
      notifyListeners();
      return;
    } on ApiException catch (e) {
      _error = 'Offline Mode: ${e.message}';
    } catch (_) {
      _error = 'Offline Mode: Server unreachable.';
    }

    // Refresh display from SQLite database in offline fallback
    await _loadFromLocal();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchTransactionsOnline() async {
    final type = switch (_typeFilter) {
      TypeFilter.all => null,
      TypeFilter.income => 'income',
      TypeFilter.expense => 'expense',
    };
    final list = await _api.getTransactions(type: type, month: _month, year: _year);
    _transactions = list
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _fetchSummaryOnline() async {
    final data = await _api.getSummary(month: _month, year: _year);
    _summary = MonthlySummary.fromJson(data);
  }

  // ---- filter changes (each one reloads) ----

  void setTypeFilter(TypeFilter filter) {
    _typeFilter = filter;
    refresh();
  }

  void setMonth(int month, int year) {
    _month = month;
    _year = year;
    refresh();
  }

  /// Move one month back/forward (used by the arrows on the Transactions tab).
  void changeMonth(int delta) {
    final next = DateTime(_year, _month + delta);
    setMonth(next.month, next.year);
  }

  // ---- create / delete ----

  /// Create a transaction. Returns true on success; sets [error] on failure.
  Future<bool> addTransaction({
    required String type,
    required double amount,
    required String description,
    String? note,
    required DateTime date,
    int? categoryId,
    List<int>? imageBytes,
  }) async {
    _error = null;
    notifyListeners();

    final dateStr = date.toIso8601String();
    
    // Save image to local documents directory for offline persistence
    String? localImagePath;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      try {
        final appDir = await getDatabasesPath();
        final filename = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(join(appDir, filename));
        await file.writeAsBytes(imageBytes);
        localImagePath = file.path;
      } catch (_) {}
    }

    final localRow = {
      'category_id': categoryId,
      'type': type,
      'amount': amount,
      'description': description,
      'note': note,
      'date': dateStr,
      'receipt_image': localImagePath,
    };

    try {
      final response = await _api.createTransaction({
        'type': type,
        'amount': amount,
        'description': description,
        if (note != null && note.isNotEmpty) 'note': note,
        'date': _apiDate(date),
        if (categoryId != null) 'category_id': categoryId,
      }, imageBytes: imageBytes);

      final serverId = response['id'] as int;

      await DbService.instance.insertTransaction({
        'id': serverId,
        ...localRow,
        'receipt_image': response['receipt_image'] ?? localImagePath,
      }, isSynced: 1, syncAction: 'none');

      await refresh();
      return true;
    } catch (_) {
      // Save offline record in local SQLite database
      await DbService.instance.insertTransaction(
        localRow,
        isSynced: 0,
        syncAction: 'create',
      );
      _error = 'Offline Mode: Saved locally. Will sync when online.';
      await _loadFromLocal();
      notifyListeners();
      return true; // Succeeded locally
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      await _api.deleteTransaction(id);
      await DbService.instance.deletePermanently(id);
      await refresh();
    } catch (_) {
      await DbService.instance.markDeleted(id);
      _error = 'Offline Mode: Deleted locally. Will sync when online.';
      await _loadFromLocal();
      notifyListeners();
    }
  }

  /// Pass-through to the AI "suggest a category" endpoint (Phase 2).
  Future<int?> suggestCategory(String description) => _api.autoCategorize(description);

  /// Pass-through to the AI receipt-scanning endpoint (Phase 4).
  Future<Map<String, dynamic>> scanReceipt(String base64Image) =>
      _api.scanReceipt(base64Image);

  /// True if the given category id is one the user can pick (defaults + own).
  bool categoryExists(int id) => _categories.any((c) => c.id == id);

  /// Format a DateTime as "YYYY-MM-DD" for the API.
  String _apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
