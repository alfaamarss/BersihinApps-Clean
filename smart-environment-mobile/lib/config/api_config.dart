import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class ApiConfig {
  static const String _localHostUrl = 'http://127.0.0.1:8000/api/v1';
  // Android emulators use 10.0.2.2 to reach the host machine.


  // Resolve base URL with priority: dart-define > local backend.
  static String get baseUrl {
    const defined = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (defined.isNotEmpty) {
      final uri = Uri.tryParse(defined);
      if (uri != null && _isLocalHost(uri.host)) {
        return defined;
      }
      return defined.replaceFirst('http://', 'https://');
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Gunakan 127.0.0.1 agar HP fisik via USB (adb reverse) langsung terhubung
      return _localHostUrl;
    }

    return _localHostUrl;
  }

  static String get serverUrl => Uri.parse(baseUrl).origin;

  /// Helper untuk memformat path foto dari API menjadi full URL yang valid
  static String? formatImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    var trimmed = path.trim();

    // Jika URL mengarah ke localhost atau 10.0.2.2, ganti dengan origin server yang aktif
    if (trimmed.startsWith('http://localhost') ||
        trimmed.startsWith('http://10.0.2.2') ||
        trimmed.startsWith('https://localhost')) {
      final origin = serverUrl;
      trimmed = trimmed.replaceFirst(
          RegExp(r'^https?://(localhost|10\.0\.2\.2)(:\d+)?'), origin);
      return trimmed;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // Bersihkan leading slash
    if (trimmed.startsWith('/')) {
      trimmed = trimmed.substring(1);
    }

    // Jika path mengarah ke pickups/ atau uploads/ tapi belum diawali storage/
    if (!trimmed.startsWith('storage/')) {
      trimmed = 'storage/$trimmed';
    }

    return '$serverUrl/$trimmed';
  }

  static bool _isLocalHost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '10.0.2.2' ||
        host.startsWith('10.') ||
        host.startsWith('192.168.') ||
        RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(host);
  }

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/mobile/auth/password/forgot';

  // Mobile endpoints
  static const String mobileDashboard = '/mobile/dashboard';
  static const String mobileAreas = '/mobile/areas';
  static const String mobileSettings = '/mobile/settings';
  static const String mobileServiceAccounts = '/mobile/service-accounts';

  // Collector endpoints
  static const String collectorDashboard = '/mobile/collector/dashboard';
  static const String collectorPickupsToday = '/mobile/collector/pickups/today';
  static const String collectorPickupsHistory =
      '/mobile/collector/pickups/history';
  static const String collectorPickupDetail =
      '/mobile/collector/pickups'; // /{id}
  static const String collectorSchedules = '/mobile/collector/schedules';
  static const String collectorWasteItems = '/mobile/collector/waste-items';
  static const String collectorProfile = '/mobile/collector/profile';
  static const String collectorChangePassword =
      '/mobile/collector/profile/change-password';
  static const String collectorOffSchedulePickupsToday =
      '/mobile/collector/off-schedule-pickups/today';

  // Resident/User endpoints
  static const String residentPickupsUpcoming =
      '/mobile/resident/pickups/upcoming';
  static const String residentPickupsHistory =
      '/mobile/resident/pickups/history';
  static const String residentPickupDetail =
      '/mobile/resident/pickups'; // /{id}
  static const String residentProfile = '/mobile/resident/profile';
  static const String residentChangePassword =
      '/mobile/resident/profile/change-password';

  // Waste Delivery endpoints (NEW API)
  static const String residentWasteDeliveries =
      '/mobile/resident/waste-deliveries';
  static const String residentWasteDeliveriesNextPickup =
      '/mobile/resident/waste-deliveries/next/pickup';
  static const String residentWasteDeliveriesStatistics =
      '/mobile/resident/waste-deliveries/statistics';

  // Article endpoints
  static const String articles = '/mobile/resident/articles';
  static const String articleDetail = '/mobile/resident/articles'; // /{id}
  static const String articlesFeatured = '/mobile/resident/articles/featured';

  // Notification endpoints
  static const String notifications = '/mobile/notifications';
  static const String notificationsUnread = '/mobile/notifications/unread';
  static const String notificationsUnreadCount =
      '/mobile/notifications/unread-count';
  static const String notificationsReadAll = '/mobile/notifications/read-all';
  static const String notificationsClearAll = '/mobile/notifications/clear-all';
}
