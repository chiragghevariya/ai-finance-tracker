/// Central place for all backend/API configuration.
///
/// This class only holds constants, so it has a private constructor and is
/// never instantiated — you use it like `ApiConfig.baseUrl`.
class ApiConfig {
  ApiConfig._();

  /// Base URL of the Laravel API.
  ///
  /// ⚠️ Pick the right host for WHERE the app runs (because "localhost" on a
  /// phone/emulator is NOT your computer):
  ///   • Android emulator : http://10.0.2.2:8000   (10.0.2.2 = your PC's localhost)
  ///   • iOS simulator    : http://127.0.0.1:8000
  ///   • Real device      : http://<your-PC-LAN-IP>:8000   (e.g. 192.168.1.50)
  ///
  /// Start the backend first with:  php artisan serve   (defaults to port 8000)
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // --- Endpoint paths (defined once so we never mistype them) ---
  static const String register = '/register';
  static const String login = '/login';
  static const String logout = '/logout';
  static const String me = '/me';

  static const String transactions = '/transactions';
  static const String summary = '/transactions/summary';
  static const String autoCategorize = '/transactions/auto-categorize';

  static const String categories = '/categories';
  static const String budgets = '/budgets';

  // AI features (wired up in Phase 4)
  static const String receiptScan = '/receipt/scan';
  static const String aiChat = '/ai/chat';
}
