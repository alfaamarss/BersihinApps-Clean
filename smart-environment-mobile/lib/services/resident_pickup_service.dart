import 'package:beresin_app/utils/app_log.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'api_client.dart';

/// Service untuk mengelola pickup sampah dari sisi Resident/Warga
class ResidentPickupService {
  ResidentPickupService() : _dio = ApiClient.instance.dio;

  final Dio _dio;

  /// Mengambil daftar pickup yang akan datang untuk service account tertentu
  /// 
  /// [serviceAccountId] - Optional: Filter by specific service account
  /// 
  /// Response API:
  /// - id: ID pickup
  /// - pickup_date: Tanggal pickup (format: Y-m-d)
  /// - day_name: Nama hari dalam bahasa Indonesia
  /// - status: scheduled | in_progress | completed | cancelled
  /// - confirmation_status: pending | confirmed | no_waste | skipped
  /// - schedule_info: Informasi jadwal (day_of_week, time_start, time_end)
  /// - collector_info: Informasi kolektor (name, phone_number)
  /// - can_confirm: boolean, apakah bisa dikonfirmasi
  /// - resident_note: Catatan dari warga
  Future<(bool success, String? message, List<Map<String, dynamic>>? pickups)> 
      getUpcomingPickups({String? serviceAccountId}) async {
    try {
      final response = await _dio.get(
        ApiConfig.residentPickupsUpcoming,
        queryParameters: serviceAccountId != null 
            ? {'service_account_id': serviceAccountId}
            : null,
      );
      
      final body = response.data as Map<String, dynamic>;
      
      if (body['success'] == true) {
        final data = body['data'] as List<dynamic>?;
        
        if (data != null) {
          final pickups = data
              .whereType<Map<String, dynamic>>()
              .toList();
          return (true, null, pickups);
        }
        
        return (true, null, <Map<String, dynamic>>[]);
      } else {
        final msg = body['errors']?['message']?.toString() ?? 
            'Gagal mengambil data pickup';
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

  /// Mengambil detail pickup berdasarkan ID
  /// 
  /// Response API akan berisi informasi lengkap tentang pickup tertentu
  Future<(bool success, String? message, Map<String, dynamic>? pickup)> 
      getPickupDetail(String pickupId) async {
    try {
      final response = await _dio.get(
        '${ApiConfig.residentPickupDetail}/$pickupId'
      );
      
      final body = response.data as Map<String, dynamic>;
      
      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>?;
        return (true, null, data);
      } else {
        final msg = body['errors']?['message']?.toString() ?? 
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

  /// Mengambil riwayat pickup yang sudah selesai
  /// 
  /// [serviceAccountId] - Optional: Filter by specific service account
  Future<(bool success, String? message, List<Map<String, dynamic>>? pickups)> 
      getPickupHistory({String? serviceAccountId}) async {
    try {
      appLog('[NET] [ResidentPickupService] Calling GET ${ApiConfig.residentPickupsHistory}');
      if (serviceAccountId != null) {
        appLog('[SEARCH] [ResidentPickupService] Filtering by service_account_id: $serviceAccountId');
      }
      
      final response = await _dio.get(
        ApiConfig.residentPickupsHistory,
        queryParameters: serviceAccountId != null 
            ? {'service_account_id': serviceAccountId}
            : null,
      );
      
      appLog('[NET] [ResidentPickupService] Response status: ${response.statusCode}');
      
      final body = response.data as Map<String, dynamic>;
      appLog('[DATA] [ResidentPickupService] Response body: $body');
      
      if (body['success'] == true) {
        final data = body['data'];
        appLog('[STATS] [ResidentPickupService] Data type: ${data.runtimeType}');
        
        // API mengembalikan array langsung di body['data']
        if (data is List) {
          appLog('[OK] [ResidentPickupService] Data is List with ${data.length} items');
          final pickups = data
              .whereType<Map<String, dynamic>>()
              .toList();
          appLog('[OK] [ResidentPickupService] Returning ${pickups.length} pickups');
          return (true, null, pickups);
        }
        
        // Fallback: cek apakah ada pagination object
        if (data is Map<String, dynamic>) {
          appLog('[STATS] [ResidentPickupService] Data is Map, keys: ${data.keys}');
          
          // Cek apakah ada key 'data' (paginated response)
          if (data.containsKey('data')) {
            final items = data['data'] as List<dynamic>?;
            if (items != null) {
              appLog('[OK] [ResidentPickupService] Found paginated data with ${items.length} items');
              final pickups = items
                  .whereType<Map<String, dynamic>>()
                  .toList();
              return (true, null, pickups);
            }
          }
          
          // Mungkin data langsung adalah single item
          appLog('[WARN] [ResidentPickupService] Data is single object, wrapping in array');
          return (true, null, [data]);
        }
        
        appLog('[WARN] [ResidentPickupService] No data found, returning empty list');
        return (true, null, <Map<String, dynamic>>[]);
      } else {
        final msg = body['errors']?['message']?.toString() ?? 
            'Gagal mengambil riwayat pickup';
        appLog('[ERROR] [ResidentPickupService] API returned success=false: $msg');
        return (false, msg, null);
      }
    } on DioException catch (e) {
      appLog('[CRASH] [ResidentPickupService] DioException: ${e.type}');
      appLog('[CRASH] [ResidentPickupService] Response: ${e.response?.statusCode} - ${e.response?.data}');
      
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg, null);
    } catch (e) {
      appLog('[CRASH] [ResidentPickupService] Exception: $e');
      return (false, 'Error: $e', null);
    }
  }

  /// Konfirmasi pickup (warga mengkonfirmasi ada sampah atau tidak)
  /// 
  /// OLD API: PUT /resident/pickups/{id}/confirm
  Future<(bool success, String? message)> confirmPickup({
    required String pickupId,
    required String confirmationStatus, // 'confirmed' atau 'no_waste'
    String? residentNote,
  }) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.residentPickupDetail}/$pickupId/confirm',
        data: {
          'confirmation_status': confirmationStatus,
          if (residentNote != null && residentNote.isNotEmpty)
            'resident_note': residentNote,
        },
      );
      
      final body = response.data as Map<String, dynamic>;
      
      if (body['success'] == true) {
        return (true, 'Pickup berhasil dikonfirmasi');
      } else {
        final msg = body['errors']?['message']?.toString() ?? 
            'Gagal mengkonfirmasi pickup';
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

  /// ⭐ NEW API: Konfirmasi Waste Delivery
  /// POST /resident/waste-deliveries/{id}/confirm
  /// 
  /// Hanya bisa dikonfirmasi jika:
  /// - status = 'collected' 
  /// - confirmation_status = 'pending'
  Future<(bool success, String message, Map<String, dynamic>? data)> 
      confirmWasteDelivery(String deliveryId) async {
    try {
      appLog('[NET] [ResidentPickupService] POST ${ApiConfig.residentWasteDeliveries}/$deliveryId/confirm');
      
      final response = await _dio.post(
        '${ApiConfig.residentWasteDeliveries}/$deliveryId/confirm',
      );
      
      final body = response.data as Map<String, dynamic>;
      appLog('[DATA] [ResidentPickupService] Confirm Response: $body');
      
      if (body['success'] == true) {
        final msg = body['message']?.toString() ?? 
            'Terima kasih! Pengambilan sampah telah dikonfirmasi.';
        final data = body['data'] as Map<String, dynamic>?;
        
        appLog('[OK] [ResidentPickupService] Confirmation successful');
        return (true, msg, data);
      } else {
        final msg = body['message']?.toString() ?? 
            'Gagal mengkonfirmasi pengambilan';
        return (false, msg, null);
      }
    } on DioException catch (e) {
      appLog('[CRASH] [ResidentPickupService] DioException on confirm: ${e.type}');
      appLog('[CRASH] [ResidentPickupService] Response: ${e.response?.statusCode} - ${e.response?.data}');
      
      String msg = 'Terjadi kesalahan jaringan';
      
      if (e.response?.statusCode == 400) {
        // Handle specific error messages from API
        if (e.response?.data is Map) {
          final body = e.response!.data as Map;
          msg = body['message']?.toString() ?? msg;
          
          // Specific error messages
          if (msg.contains('belum dilakukan')) {
            msg = 'Pengambilan belum dilakukan oleh petugas.';
          } else if (msg.contains('sudah dikonfirmasi')) {
            msg = 'Pengambilan sudah dikonfirmasi sebelumnya.';
          }
        }
      } else if (e.response?.statusCode == 404) {
        msg = 'Pengambilan tidak ditemukan.';
      } else if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['message']?.toString() ?? msg;
      }
      
      return (false, msg, null);
    } catch (e) {
      appLog('[CRASH] [ResidentPickupService] Exception on confirm: $e');
      return (false, 'Error: $e', null);
    }
  }

  /// Update catatan resident untuk pickup tertentu
  Future<(bool success, String? message)> updatePickupNote({
    required String pickupId,
    required String note,
  }) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.residentPickupDetail}/$pickupId/note',
        data: {
          'resident_note': note,
        },
      );
      
      final body = response.data as Map<String, dynamic>;
      
      if (body['success'] == true) {
        return (true, 'Catatan berhasil diperbarui');
      } else {
        final msg = body['errors']?['message']?.toString() ?? 
            'Gagal memperbarui catatan';
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
