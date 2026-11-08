import 'package:beresin_app/utils/app_log.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../config/api_config.dart';
import 'api_client.dart';

class PickupService {
  static const String _keyPengambilan = 'pengambilan_terakhir';
  static final Dio _dio = ApiClient.instance.dio;

  // Simpan data pengambilan baru
  static Future<void> savePickupData({
    required String userName,
    required String address,
    required String idPengambilan,
    required List<Map<String, dynamic>> selectedItems,
    required double totalPrice,
    required String imagePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Get existing data
    List<Map<String, dynamic>> existingData = await getPickupHistory();

    // Create new pickup entry
    final newPickup = {
      'name': userName,
      'address': address,
      'idPengambilan': idPengambilan,
      'items': selectedItems,
      'totalPrice': totalPrice,
      'image': imagePath,
      'timestamp': DateTime.now().toIso8601String(),
      'date': _formatDate(DateTime.now()),
    };

    // Add to beginning of list (most recent first)
    existingData.insert(0, newPickup);

    // Keep only last 10 entries
    if (existingData.length > 10) {
      existingData = existingData.sublist(0, 10);
    }

    // Save to SharedPreferences
    final String jsonData = json.encode(existingData);
    await prefs.setString(_keyPengambilan, jsonData);
  }

  // Ambil semua data pengambilan
  static Future<List<Map<String, dynamic>>> getPickupHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonData = prefs.getString(_keyPengambilan);

    if (jsonData != null) {
      final List<dynamic> decoded = json.decode(jsonData);
      return decoded.cast<Map<String, dynamic>>();
    }

    return [];
  }

  // Format tanggal ke string yang readable
  static String _formatDate(DateTime date) {
    const List<String> days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const List<String> months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    String dayName = days[date.weekday - 1];
    String monthName = months[date.month - 1];

    return '$dayName, ${date.day} $monthName ${date.year} ${date.hour.toString().padLeft(2, '0')}.${date.minute.toString().padLeft(2, '0')}';
  }

  // ========== API Methods ==========

  /// Ambil daftar waste items dengan pricing dari API
  static Future<
    (bool success, String? message, List<Map<String, dynamic>>? data)
  >
  getWasteItems() async {
    try {
      appLog('[NET] [PickupService] Calling API: ${ApiConfig.collectorWasteItems}');
      final response = await _dio.get(ApiConfig.collectorWasteItems);

      appLog('[NET] [PickupService] Response status: ${response.statusCode}');

      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        final data = body['data'] as List<dynamic>?;
        appLog('[DATA] [PickupService] Data received: ${data?.length} items');

        if (data != null) {
          final items = data.map((e) => e as Map<String, dynamic>).toList();
          appLog(
            '[OK] [PickupService] Successfully parsed ${items.length} waste items',
          );
          return (true, null, items);
        }
        return (true, null, <Map<String, dynamic>>[]);
      } else {
        final msg =
            body['errors']?['message']?.toString() ??
            'Gagal mengambil data waste items';
        appLog('[ERROR] [PickupService] API returned success=false: $msg');
        return (false, msg, null);
      }
    } on DioException catch (e) {
      appLog('[CRASH] [PickupService] DioException: ${e.type}, ${e.message}');
      appLog(
        '[CRASH] [PickupService] Response: ${e.response?.statusCode} - ${e.response?.data}',
      );

      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg, null);
    } catch (e) {
      appLog('[CRASH] [PickupService] Exception: $e');
      return (false, 'Error: $e', null);
    }
  }

  /// Ambil daftar pickup hari ini dari API (untuk Collector)
  static Future<
    (bool success, String? message, List<Map<String, dynamic>>? data)
  >
  getTodayPickups() async {
    try {
      appLog('[SEARCH] [PickupService] ===== FETCHING TODAY PICKUPS =====');
      appLog(
        '[NET] [PickupService] Calling API: ${ApiConfig.collectorPickupsToday}',
      );
      appLog(
        '[TIME] [PickupService] Current time: ${DateTime.now().toIso8601String()}',
      );

      // Get logged in collector info - handle both int and string
      final prefs = await SharedPreferences.getInstance();
      final userIdRaw = prefs.get('user_id');
      final userId = userIdRaw?.toString();
      final userName = prefs.getString('user_name');
      final userRole = prefs.getString('user_role');

      appLog('[TAG] [PickupService] Logged in user:');
      appLog('   - ID: $userId (type: ${userIdRaw.runtimeType})');
      appLog('   - Name: $userName');
      appLog('   - Role: $userRole');

      final response = await _dio.get(ApiConfig.collectorPickupsToday);

      appLog('[NET] [PickupService] Response status: ${response.statusCode}');

      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        // API menggunakan key 'items' bukan 'data'
        final items = body['items'] as List<dynamic>?;
        appLog('[DATA] [PickupService] Received ${items?.length ?? 0} pickup items');

        if (items != null && items.isNotEmpty) {
          // Debug: Print first item structure
          appLog('[LIST] [PickupService] Sample pickup structure:');
          final firstItem = items.first as Map<String, dynamic>;
          appLog('   - Keys: ${firstItem.keys.toList()}');
          appLog('   - Pickup ID: ${firstItem['id']}');
          appLog('   - Collector ID: ${firstItem['collector_id']}');
          appLog('   - Status: ${firstItem['status']}');
          appLog('   - Date: ${firstItem['pickup_date']}');

          if (firstItem.containsKey('service_account')) {
            final sa = firstItem['service_account'] as Map<String, dynamic>?;
            appLog(
              '   - service_account: ${sa != null ? sa.keys.toList() : "null"}',
            );
            if (sa != null) {
              appLog('     • name: ${sa['name']}');
              appLog('     • contact_phone: ${sa['contact_phone']}');
            }
          } else {
            appLog('   - [WARN] No service_account key found!');
          }
          if (firstItem.containsKey('house_info')) {
            final houseInfo = firstItem['house_info'] as Map<String, dynamic>?;
            appLog('   - house_info keys: ${houseInfo?.keys.toList()}');
            if (houseInfo != null) {
              appLog('     • account_number: ${houseInfo['account_number']}');
              appLog('     • resident_name: ${houseInfo['resident_name']}');
              appLog('     • address: ${houseInfo['address']}');
            }
          }

          final pickups = items.map((e) => e as Map<String, dynamic>).toList();
          appLog(
            '[OK] [PickupService] Successfully parsed ${pickups.length} pickups',
          );
          appLog('═══════════════════════════════════════════════════════');
          return (true, null, pickups);
        }
        appLog('[WARN] [PickupService] No pickups found for today');
        appLog('═══════════════════════════════════════════════════════');
        return (true, null, <Map<String, dynamic>>[]);
      } else {
        final msg =
            body['errors']?['message']?.toString() ??
            'Gagal mengambil data pickup';
        appLog('[ERROR] [PickupService] API returned success=false: $msg');
        appLog('═══════════════════════════════════════════════════════');
        return (false, msg, null);
      }
    } on DioException catch (e) {
      appLog('[CRASH] [PickupService] DioException: ${e.type}, ${e.message}');
      appLog(
        '[CRASH] [PickupService] Response: ${e.response?.statusCode} - ${e.response?.data}',
      );
      appLog('═══════════════════════════════════════════════════════');
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg, null);
    } catch (e, stackTrace) {
      appLog('[CRASH] [PickupService] Exception: $e');
      appLog('Stack trace: $stackTrace');
      appLog('═══════════════════════════════════════════════════════');
      return (false, 'Error: $e', null);
    }
  }

  /// Ambil riwayat pickup yang sudah completed dari API (untuk Collector)
  static Future<
    (bool success, String? message, List<Map<String, dynamic>>? data)
  >
  getPickupHistoryFromAPI({int? limit}) async {
    try {
      appLog(
        '[NET] [PickupService] Calling API: ${ApiConfig.collectorPickupsHistory}',
      );

      final queryParams = limit != null ? {'limit': limit} : null;
      final response = await _dio.get(
        ApiConfig.collectorPickupsHistory,
        queryParameters: queryParams,
      );

      appLog('[NET] [PickupService] Response status: ${response.statusCode}');

      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        final data = body['data'] as List<dynamic>?;
        appLog(
          '[DATA] [PickupService] History data received: ${data?.length} items',
        );

        if (data != null) {
          final history = data.map((e) {
            final item = e as Map<String, dynamic>;

            // Transform data untuk UI
            final houseInfo = item['house_info'] as Map<String, dynamic>?;
            final wasteItems = item['waste_items'] as List<dynamic>?;

            // Transform waste items to match UI expectations
            final transformedItems =
                wasteItems?.map((wasteItem) {
                  final wi = wasteItem as Map<String, dynamic>;
                  return {
                    'category': wi['waste_category'] ?? 'Unknown',
                    'name':
                        '${wi['waste_category'] ?? 'Unknown'} ${wi['pocket_size'] ?? ''}',
                    'quantity': wi['quantity'] ?? 0,
                    'price': wi['unit_price'] ?? 0,
                    'totalPrice': wi['total_price'] ?? 0,
                  };
                }).toList() ??
                [];

            return {
              'id': item['id'],
              'idPengambilan': 'no ${item['id']}',
              'pickup_type': item['pickup_type'] ?? 'regular',
              'name':
                  houseInfo?['resident_name'] ??
                  houseInfo?['account_number'] ??
                  'N/A',
              'address': houseInfo?['address'] ?? 'N/A',
              'totalPrice': item['total_amount'] ?? 0,
              'image': item['photo_url'] ?? 'assets/images/dummy.jpg',
              'date': item['pickup_date'] ?? '',
              'dayName': item['day_name'] ?? '',
              'status': item['status'] ?? '',
              'items': transformedItems, // Use 'items' key for compatibility
              'notes': item['collector_notes'] ?? '',
              'resident_note': item['resident_note'] ?? '',
            };
          }).toList();

          appLog(
            '[OK] [PickupService] Successfully parsed ${history.length} history items',
          );
          return (true, null, history);
        }
return (true, null, <Map<String, dynamic>>[]);
      } else {
        final msg =
            body['errors']?['message']?.toString() ??
            'Gagal mengambil riwayat pickup';
        appLog('[ERROR] [PickupService] API returned success=false: $msg');
        return (false, msg, null);
      }
    } on DioException catch (e) {
      appLog('[CRASH] [PickupService] DioException: ${e.type}, ${e.message}');
      appLog(
        '[CRASH] [PickupService] Response: ${e.response?.statusCode} - ${e.response?.data}',
      );

      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg, null);
    } catch (e) {
      appLog('[CRASH] [PickupService] Exception: $e');
      return (false, 'Error: $e', null);
    }
  }

  /// Ambil detail pickup berdasarkan ID
  static Future<(bool success, String? message, Map<String, dynamic>? data)>
  getPickupDetail(int id) async {
    try {
      final response = await _dio.get('${ApiConfig.collectorPickupDetail}/$id');

      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>?;
        return (true, null, data);
      } else {
        final msg =
            body['errors']?['message']?.toString() ??
            'Gagal mengambil detail pickup';
        return (false, msg, null);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg, null);
    } catch (e) {
      return (false, 'Error: $e', null);
    }
  }

  /// Start pickup (ubah status ke on_progress)
  static Future<(bool success, String? message)> startPickup(int id) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.collectorPickupDetail}/$id/start',
      );

      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        return (true, null);
      } else {
        final msg =
            body['errors']?['message']?.toString() ?? 'Gagal memulai pickup';
        return (false, msg);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg);
    } catch (e) {
      return (false, 'Error: $e');
    }
  }

  /// Complete pickup dengan waste items
  static Future<(bool success, String? message, Map<String, dynamic>? data)>
  completePickup({
    required int id,
    required String photo,
    required List<Map<String, dynamic>> wasteItems,
    String? collectorNotes,
  }) async {
    try {
      final url = '${ApiConfig.collectorPickupDetail}/$id/complete';
      appLog('[NET] [PickupService] Calling PUT $url');
      appLog('[DATA] [PickupService] Photo length: ${photo.length} chars');
      appLog('[DATA] [PickupService] Waste items: ${wasteItems.length} items');

      final response = await _dio.put(
        url,
        data: {
          'photo': photo,
          'waste_items': wasteItems,
          'collector_notes': collectorNotes,
        },
      );

      appLog('[NET] [PickupService] Response status: ${response.statusCode}');

      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>?;
        appLog('[OK] [PickupService] Complete pickup SUCCESS');
        return (true, null, data);
      } else {
        final msg =
            body['errors']?['message']?.toString() ??
            'Gagal menyelesaikan pickup';
        appLog('[ERROR] [PickupService] API returned success=false: $msg');
        return (false, msg, null);
      }
    } on DioException catch (e) {
      appLog('[CRASH] [PickupService] DioException Type: ${e.type}');
      appLog('[CRASH] [PickupService] DioException Message: ${e.message}');
      appLog('[CRASH] [PickupService] Response Status: ${e.response?.statusCode}');
      appLog('[CRASH] [PickupService] Response Data: ${e.response?.data}');
      appLog('[CRASH] [PickupService] Request Data: ${e.requestOptions.data}');

      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg =
            body['errors']?['message']?.toString() ??
            body['message']?.toString() ??
            msg;
      }
      return (false, msg, null);
    } catch (e) {
      appLog('[CRASH] [PickupService] General Exception: $e');
      return (false, 'Error: $e', null);
    }
  }

  /// Skip pickup dengan reason
  static Future<(bool success, String? message)> skipPickup({
    required int id,
    required String reason,
  }) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.collectorPickupDetail}/$id/skip',
        data: {'reason': reason},
      );

      final body = response.data as Map<String, dynamic>;

      if (body['success'] == true) {
        return (true, null);
      } else {
        final msg =
            body['errors']?['message']?.toString() ?? 'Gagal melewati pickup';
        return (false, msg);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg);
    } catch (e) {
      return (false, 'Error: $e');
    }
  }
}
