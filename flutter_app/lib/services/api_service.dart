import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// A simple error type so the UI can show a friendly message.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Talks to the Laravel backend using Dio.
///
/// Key job: the JWT token. After login/register we store the token, and an
/// interceptor automatically adds `Authorization: Bearer <token>` to every
/// request — so the rest of the app never has to think about it.
class ApiService {
  late final Dio _dio;

  /// The JWT, kept in memory for speed and mirrored to device storage.
  String? _token;
  static const String _tokenKey = 'auth_token';

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        // Tell Laravel we want JSON (so validation errors come back as JSON 422).
        headers: {'Accept': 'application/json'},
      ),
    );

    // ---- The JWT interceptor ----
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          // If the server says our token is no longer valid, drop it so the
          // app can send the user back to the login screen.
          if (error.response?.statusCode == 401) {
            _token = null;
          }
          handler.next(error);
        },
      ),
    );
  }

  bool get hasToken => _token != null;

  /// Load any saved token from device storage. Call this once on app start.
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> _setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ===================== AUTH =====================

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    double? monthlyBudget,
  }) async {
    final res = await _send(() => _dio.post(ApiConfig.register, data: {
          'name': name,
          'email': email,
          'password': password,
          // Laravel uses "confirmed", so it needs a matching confirmation field.
          'password_confirmation': password,
          if (monthlyBudget != null) 'monthly_budget': monthlyBudget,
        }));
    final data = res.data as Map<String, dynamic>;
    await _setToken(data['access_token'] as String);
    return data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _send(() => _dio.post(ApiConfig.login, data: {
          'email': email,
          'password': password,
        }));
    final data = res.data as Map<String, dynamic>;
    await _setToken(data['access_token'] as String);
    return data;
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _send(() => _dio.get(ApiConfig.me));
    return res.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    // Best-effort: tell the server, but always clear locally even if offline.
    try {
      await _dio.post(ApiConfig.logout);
    } catch (_) {
      // ignore network errors during logout
    }
    await clearToken();
  }

  // ===================== TRANSACTIONS =====================

  /// Returns the list of transactions (the rows only — the endpoint is paginated).
  Future<List<dynamic>> getTransactions({String? type, int? month, int? year}) async {
    final res = await _send(() => _dio.get(ApiConfig.transactions, queryParameters: {
          if (type != null) 'type': type,
          if (month != null) 'month': month,
          if (year != null) 'year': year,
        }));
    final body = res.data as Map<String, dynamic>;
    return (body['data'] as List<dynamic>?) ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> body) async {
    final res = await _send(() => _dio.post(ApiConfig.transactions, data: body));
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTransaction(int id, Map<String, dynamic> body) async {
    final res = await _send(() => _dio.put('${ApiConfig.transactions}/$id', data: body));
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteTransaction(int id) async {
    await _send(() => _dio.delete('${ApiConfig.transactions}/$id'));
  }

  /// Monthly summary: totals + spending-by-category.
  Future<Map<String, dynamic>> getSummary({required int month, required int year}) async {
    final res = await _send(() => _dio.get(ApiConfig.summary, queryParameters: {
          'month': month,
          'year': year,
        }));
    return res.data as Map<String, dynamic>;
  }

  // ===================== CATEGORIES =====================

  /// Returns the JSON array of categories (defaults + the user's own).
  Future<List<dynamic>> getCategories() async {
    final res = await _send(() => _dio.get(ApiConfig.categories));
    return res.data as List<dynamic>;
  }

  // ===================== AI (Phase 2 endpoint, used here for "suggest category") =====================

  /// Ask the backend to suggest a category id for a description.
  /// Returns null if the AI service isn't configured or no match was found.
  Future<int?> autoCategorize(String description) async {
    final res = await _send(() => _dio.post(ApiConfig.autoCategorize, data: {
          'description': description,
        }));
    final data = res.data as Map<String, dynamic>;
    return data['suggested_category_id'] as int?;
  }

  // ===================== AI CHAT + RECEIPT (Phase 4) =====================

  /// Send a message to the finance assistant and return its reply text.
  /// POST /api/ai/chat  ->  { "reply": "..." }
  Future<String> chat(String message) async {
    final res = await _send(() => _dio.post(ApiConfig.aiChat, data: {
          'message': message,
        }));
    final data = res.data as Map<String, dynamic>;
    return (data['reply'] as String?) ?? '';
  }

  /// Send a receipt image (base64 encoded) to be read by AI.
  /// POST /api/receipt/scan  ->  { merchant_name, total_amount, date,
  ///                              category, suggested_category_id, ... }
  Future<Map<String, dynamic>> scanReceipt(String base64Image) async {
    final res = await _send(() => _dio.post(ApiConfig.receiptScan, data: {
          'image_base64': base64Image,
        }));
    return res.data as Map<String, dynamic>;
  }

  // ===================== internals =====================

  /// Runs a Dio call and converts any Dio error into a friendly [ApiException].
  Future<Response> _send(Future<Response> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException(_messageFromError(e), statusCode: e.response?.statusCode);
    }
  }

  /// Pulls the best human-readable message out of a Dio error.
  String _messageFromError(DioException e) {
    final data = e.response?.data;

    // Laravel returns { "message": "...", "errors": { field: [..] } }.
    if (data is Map) {
      // Prefer the first specific validation error if there is one.
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
      if (data['message'] is String) return data['message'] as String;
    }

    // Network-level problems (server not running, no wifi, etc.).
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Cannot reach the server. Is the Laravel API running?';
    }

    return 'Something went wrong. Please try again.';
  }
}
