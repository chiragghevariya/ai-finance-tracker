import 'package:flutter/foundation.dart';

import '../models/category.dart';
import '../models/summary.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

/// The type filter on the Transactions tab.
enum TypeFilter { all, income, expense }

/// Loads and holds transactions, the monthly summary, and categories.
/// The Dashboard and Transactions tabs both listen to this.
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
    await loadCategories();
    await refresh();
  }

  /// Load the category list (used by the add-transaction form & charts).
  Future<void> loadCategories() async {
    try {
      final list = await _api.getCategories();
      _categories = list
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {
      // Non-fatal: the app still works without the category list.
    }
  }

  /// Re-fetch transactions + summary for the current filters.
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Run both requests at once for speed.
      await Future.wait([_fetchTransactions(), _fetchSummary()]);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load data.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchTransactions() async {
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

  Future<void> _fetchSummary() async {
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
  }) async {
    try {
      await _api.createTransaction({
        'type': type,
        'amount': amount,
        'description': description,
        if (note != null && note.isNotEmpty) 'note': note,
        'date': _apiDate(date),
        if (categoryId != null) 'category_id': categoryId,
      });
      await refresh(); // reload so the new item + totals show up
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      await _api.deleteTransaction(id);
      await refresh();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  /// Pass-through to the AI "suggest a category" endpoint (Phase 2).
  Future<int?> suggestCategory(String description) => _api.autoCategorize(description);

  /// Pass-through to the AI receipt-scanning endpoint (Phase 4).
  /// Takes a base64-encoded image and returns the parsed receipt fields.
  Future<Map<String, dynamic>> scanReceipt(String base64Image) =>
      _api.scanReceipt(base64Image);

  /// True if the given category id is one the user can pick (defaults + own).
  /// Used to keep the dropdown safe when the AI suggests a category.
  bool categoryExists(int id) => _categories.any((c) => c.id == id);

  /// Format a DateTime as "YYYY-MM-DD" for the API.
  String _apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
