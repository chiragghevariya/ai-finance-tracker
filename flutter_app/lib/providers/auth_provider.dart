import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';

/// Whether we know if the user is logged in yet.
enum AuthStatus { unknown, authenticated, unauthenticated }

/// Holds the logged-in user and handles login / register / logout.
///
/// Screens listen to this with Provider and rebuild when it changes.
class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  AuthProvider(this._api);

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthStatus get status => _status;
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Called on app start. If we have a saved token, fetch the user with it.
  Future<void> tryAutoLogin() async {
    await _api.loadToken();
    if (!_api.hasToken) {
      _setStatus(AuthStatus.unauthenticated);
      return;
    }
    try {
      _user = User.fromJson(await _api.me());
      await _applyLocalBudget();
      _setStatus(AuthStatus.authenticated);
    } catch (_) {
      // Token was invalid/expired — start fresh at the login screen.
      await _api.clearToken();
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) {
    return _run(() async {
      final data = await _api.login(email: email, password: password);
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
      await _applyLocalBudget();
      _setStatus(AuthStatus.authenticated);
    });
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    double? monthlyBudget,
  }) {
    return _run(() async {
      final data = await _api.register(
        name: name,
        email: email,
        password: password,
        monthlyBudget: monthlyBudget,
      );
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
      await _applyLocalBudget();
      _setStatus(AuthStatus.authenticated);
    });
  }

  Future<void> logout() async {
    await _api.logout();
    await DbService.instance.clearAll();
    _user = null;
    _setStatus(AuthStatus.unauthenticated);
  }

  /// Update the monthly budget.
  Future<bool> updateMonthlyBudget(double budget) {
    return _run(() async {
      final data = await _api.updateProfile(monthlyBudget: budget);
      _user = User.fromJson(data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('monthly_budget', budget);
    });
  }

  /// If the user previously set a budget locally, apply it over the API value.
  Future<void> _applyLocalBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getDouble('monthly_budget');
    if (local != null && _user != null) {
      _user = _user!.copyWith(monthlyBudget: local);
    }
  }

  // ---- small helpers ----

  /// Runs an async auth action with loading + error handling.
  /// Returns true on success, false on failure (error message is set).
  Future<bool> _run(Future<void> Function() action) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Unexpected error. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
