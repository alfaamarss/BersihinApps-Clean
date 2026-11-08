import 'package:beresin_app/utils/app_log.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'api_client.dart';

/// Model untuk data notifikasi dari API
class AppNotification {
  final String id;
  final String type;
  final NotificationData data;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.data,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    // Handle case where 'data' might be a String (JSON encoded) instead of Map
    dynamic rawData = json['data'];
    Map<String, dynamic> dataMap = {};
    
    if (rawData is Map<String, dynamic>) {
      dataMap = rawData;
    } else if (rawData is String) {
      // Try to parse JSON string
      try {
        final decoded = Uri.decodeFull(rawData);
        // If it's still just a string, create a simple map
        dataMap = {'message': decoded, 'title': '', 'type': ''};
      } catch (e) {
        dataMap = {'message': rawData, 'title': '', 'type': ''};
      }
    } else if (rawData == null) {
      dataMap = {};
    }

    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      data: NotificationData.fromJson(dataMap),
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'data': data.toJson(),
        'read_at': readAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}

class NotificationData {
  final String title;
  final String message;
  final String type;
  final String? icon;
  final String? actionUrl;
  final Map<String, dynamic> extra;

  NotificationData({
    required this.title,
    required this.message,
    required this.type,
    this.icon,
    this.actionUrl,
    this.extra = const {},
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    // Create a copy for extra data
    final extra = <String, dynamic>{};
    json.forEach((key, value) {
      if (!['title', 'message', 'type', 'icon', 'action_url'].contains(key)) {
        extra[key] = value;
      }
    });

    return NotificationData(
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      icon: json['icon']?.toString(),
      actionUrl: json['action_url']?.toString(),
      extra: extra,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'message': message,
        'type': type,
        'icon': icon,
        'action_url': actionUrl,
        ...extra,
      };
}

class NotificationResponse {
  final List<AppNotification> notifications;
  final int currentPage;
  final int lastPage;
  final int total;
  final int unreadCount;

  NotificationResponse({
    required this.notifications,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.unreadCount,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse int from dynamic value
    int safeParseInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      if (value is double) return value.toInt();
      return defaultValue;
    }

    // Cek apakah json['data'] adalah Map atau langsung List
    // API mungkin mengembalikan format berbeda
    dynamic rawData = json['data'];
    List<dynamic> items = [];
    int currentPage = 1;
    int lastPage = 1;
    int total = 0;

    if (rawData is Map<String, dynamic>) {
      // Format: { "data": { "data": [...], "current_page": 1, ... } }
      items = rawData['data'] is List ? rawData['data'] : [];
      currentPage = safeParseInt(rawData['current_page'], 1);
      lastPage = safeParseInt(rawData['last_page'], 1);
      total = safeParseInt(rawData['total'], 0);
    } else if (rawData is List) {
      // Format: { "data": [...] }
      items = rawData;
      total = rawData.length;
    }

    // Parse notifications dengan error handling per item
    List<AppNotification> notifications = [];
    for (var item in items) {
      try {
        if (item is Map<String, dynamic>) {
          notifications.add(AppNotification.fromJson(item));
        }
      } catch (e) {
        appLog('[NotificationResponse] Error parsing notification item: $e');
        appLog('[NotificationResponse] Item data: $item');
      }
    }

    // ✅ Count unread from parsed notifications if unread_count not provided by API
    int unreadCount = safeParseInt(json['unread_count'], -1);
    if (unreadCount < 0) {
      // API didn't provide unread_count, calculate from notifications
      unreadCount = notifications.where((n) => !n.isRead).length;
      appLog('[NotificationResponse] Calculated unread count from data: $unreadCount');
    }

    return NotificationResponse(
      notifications: notifications,
      currentPage: currentPage,
      lastPage: lastPage,
      total: total,
      unreadCount: unreadCount,
    );
  }
}

/// Service untuk mengakses API notifikasi
class NotificationApiService {
  static final Dio _dio = ApiClient.instance.dio;

  /// Get all notifications with pagination
  static Future<NotificationResponse> getNotifications({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      appLog('[NotificationApiService] Fetching notifications - page: $page, perPage: $perPage');
      
      final response = await _dio.get(
        ApiConfig.notifications,
        queryParameters: {
          'page': page,
          'per_page': perPage,
        },
      );

      appLog('[NotificationApiService] Response status: ${response.statusCode}');
      appLog('[NotificationApiService] Response data type: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        try {
          final result = NotificationResponse.fromJson(response.data);
          appLog('[NotificationApiService] Successfully parsed ${result.notifications.length} notifications');
          return result;
        } catch (parseError, stackTrace) {
          appLog('[NotificationApiService] Parse error: $parseError');
          appLog('[NotificationApiService] Stack trace: $stackTrace');
          appLog('[NotificationApiService] Raw data: ${response.data}');
          throw Exception('Failed to parse notifications: $parseError');
        }
      } else {
        throw Exception('Failed to load notifications: Status ${response.statusCode}');
      }
    } on DioException catch (e) {
      appLog('[NotificationApiService] DioException getNotifications: ${e.message}');
      appLog('[NotificationApiService] Response: ${e.response?.data}');
      throw Exception('Failed to load notifications: ${e.message}');
    } catch (e, stackTrace) {
      appLog('[NotificationApiService] Unexpected error getNotifications: $e');
      appLog('[NotificationApiService] Stack trace: $stackTrace');
      throw Exception('Failed to load notifications: $e');
    }
  }

  /// Get unread notifications only
  static Future<List<AppNotification>> getUnreadNotifications() async {
    try {
      final response = await _dio.get(ApiConfig.notificationsUnread);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((item) => AppNotification.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load unread notifications');
      }
    } on DioException catch (e) {
      appLog(
          '[NotificationApiService] Error getUnreadNotifications: ${e.message}');
      throw Exception('Failed to load unread notifications: ${e.message}');
    }
  }

  /// Get unread count - tries dedicated endpoint first, falls back to counting from notifications
  static Future<int> getUnreadCount() async {
    try {
      // First try dedicated unread count endpoint
      final response = await _dio.get(ApiConfig.notificationsUnreadCount);

      if (response.statusCode == 200) {
        // Try to get count from various possible response formats
        final data = response.data;
        
        // Format 1: { "count": 5 }
        if (data is Map && data['count'] != null) {
          final count = data['count'];
          if (count is int) return count;
          if (count is String) return int.tryParse(count) ?? 0;
        }
        
        // Format 2: { "data": { "count": 5 } }
        if (data is Map && data['data'] is Map && data['data']['count'] != null) {
          final count = data['data']['count'];
          if (count is int) return count;
          if (count is String) return int.tryParse(count) ?? 0;
        }
        
        // Format 3: { "unread_count": 5 }
        if (data is Map && data['unread_count'] != null) {
          final count = data['unread_count'];
          if (count is int) return count;
          if (count is String) return int.tryParse(count) ?? 0;
        }
        
        // Format 4: Just a number
        if (data is int) return data;
        if (data is String) return int.tryParse(data) ?? 0;
      }
      
      // If dedicated endpoint fails or returns invalid format, 
      // fall back to counting from notifications list
      return await _countUnreadFromNotifications();
    } on DioException catch (e) {
      appLog('[NotificationApiService] Error getUnreadCount: ${e.message}');
      // Try fallback method
      return await _countUnreadFromNotifications();
    }
  }

  /// Fallback: Count unread from notifications list
  static Future<int> _countUnreadFromNotifications() async {
    try {
      final response = await getNotifications(page: 1, perPage: 100);
      // Count notifications where readAt is null (unread)
      final unreadCount = response.notifications.where((n) => !n.isRead).length;
      appLog('[NotificationApiService] Counted $unreadCount unread notifications from list');
      return unreadCount;
    } catch (e) {
      appLog('[NotificationApiService] Error counting unread: $e');
      return 0;
    }
  }

  /// Mark single notification as read
  static Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await _dio.post('${ApiConfig.notifications}/$notificationId/read');
      return response.statusCode == 200;
    } on DioException catch (e) {
      appLog('[NotificationApiService] Error markAsRead: ${e.message}');
      return false;
    }
  }

  /// Mark all notifications as read
  static Future<bool> markAllAsRead() async {
    try {
      final response = await _dio.post(ApiConfig.notificationsReadAll);
      return response.statusCode == 200;
    } on DioException catch (e) {
      appLog('[NotificationApiService] Error markAllAsRead: ${e.message}');
      return false;
    }
  }

  /// Delete a notification
  static Future<bool> deleteNotification(String notificationId) async {
    try {
      final response = await _dio.delete('${ApiConfig.notifications}/$notificationId');
      return response.statusCode == 200;
    } on DioException catch (e) {
      appLog('[NotificationApiService] Error deleteNotification: ${e.message}');
      return false;
    }
  }

  /// Clear all notifications
  static Future<bool> clearAllNotifications() async {
    try {
      final response = await _dio.delete(ApiConfig.notificationsClearAll);
      return response.statusCode == 200;
    } on DioException catch (e) {
      appLog(
          '[NotificationApiService] Error clearAllNotifications: ${e.message}');
      return false;
    }
  }
}
