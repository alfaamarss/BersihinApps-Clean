import 'package:beresin_app/utils/app_log.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'api_client.dart';

/// Model untuk Waste Delivery Item
class WasteDeliveryItem {
  final int id;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final WasteInfo waste;
  final PocketSizeInfo? pocketSize;

  WasteDeliveryItem({
    required this.id,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.waste,
    this.pocketSize,
  });

  factory WasteDeliveryItem.fromJson(Map<String, dynamic> json) {
    return WasteDeliveryItem(
      id: json['id'] ?? 0,
      quantity: json['quantity'] ?? 0,
      unitPrice: _parseDouble(json['unit_price']),
      totalPrice: _parseDouble(json['total_price']),
      waste: WasteInfo.fromJson(json['waste'] ?? {}),
      pocketSize: json['pocket_size'] != null 
          ? PocketSizeInfo.fromJson(json['pocket_size'])
          : null,
    );
  }
}

class WasteInfo {
  final int id;
  final String category;
  final String code;

  WasteInfo({
    required this.id,
    required this.category,
    required this.code,
  });

  factory WasteInfo.fromJson(Map<String, dynamic> json) {
    return WasteInfo(
      id: json['id'] ?? 0,
      category: json['category'] ?? '',
      code: json['code'] ?? '',
    );
  }
}

class PocketSizeInfo {
  final int id;
  final String name;
  final int capacity;

  PocketSizeInfo({
    required this.id,
    required this.name,
    required this.capacity,
  });

  factory PocketSizeInfo.fromJson(Map<String, dynamic> json) {
    return PocketSizeInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      capacity: json['capacity'] ?? 0,
    );
  }
}

/// Model untuk Service Account Area
class ServiceAccountArea {
  final int id;
  final String name;
  final String? level;
  final ServiceAccountArea? parent;

  ServiceAccountArea({
    required this.id,
    required this.name,
    this.level,
    this.parent,
  });

  factory ServiceAccountArea.fromJson(Map<String, dynamic> json) {
    return ServiceAccountArea(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      level: json['level'],
      parent: json['parent'] != null 
          ? ServiceAccountArea.fromJson(json['parent'])
          : null,
    );
  }
}

/// Model untuk Service Account
class DeliveryServiceAccount {
  final int id;
  final String name;
  final String address;
  final String? contactPhone;
  final ServiceAccountArea? area;

  DeliveryServiceAccount({
    required this.id,
    required this.name,
    required this.address,
    this.contactPhone,
    this.area,
  });

  factory DeliveryServiceAccount.fromJson(Map<String, dynamic> json) {
    return DeliveryServiceAccount(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      contactPhone: json['contact_phone'],
      area: json['area'] != null 
          ? ServiceAccountArea.fromJson(json['area'])
          : null,
    );
  }
}

/// Model untuk Invoice
class DeliveryInvoice {
  final int id;
  final String invoiceNumber;
  final double totalAmount;
  final String status;
  final String? issuedAt;

  DeliveryInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.status,
    this.issuedAt,
  });

  factory DeliveryInvoice.fromJson(Map<String, dynamic> json) {
    return DeliveryInvoice(
      id: json['id'] ?? 0,
      invoiceNumber: json['invoice_number'] ?? '',
      totalAmount: _parseDouble(json['total_amount']),
      status: json['status'] ?? '',
      issuedAt: json['issued_at'],
    );
  }
}

/// Model utama untuk Waste Delivery
class WasteDelivery {
  final int id;
  final String status;
  final String? scheduledAt;
  final double totalAmount;
  final String? note;
  final DeliveryServiceAccount serviceAccount;
  final String confirmationStatus;
  final String? collectedAt;
  final String? confirmedAt;
  final String? completedAt;
  final String? createdAt;
  final String? updatedAt;
  final List<WasteDeliveryItem> items;
  final DeliveryInvoice? invoice;

  WasteDelivery({
    required this.id,
    required this.status,
    this.scheduledAt,
    required this.totalAmount,
    this.note,
    required this.serviceAccount,
    required this.confirmationStatus,
    this.collectedAt,
    this.confirmedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
    this.invoice,
  });

  factory WasteDelivery.fromJson(Map<String, dynamic> json) {
    List<WasteDeliveryItem> items = [];
    if (json['items'] != null && json['items'] is List) {
      items = (json['items'] as List)
          .map((e) => WasteDeliveryItem.fromJson(e))
          .toList();
    }

    return WasteDelivery(
      id: json['id'] ?? 0,
      status: json['status'] ?? 'scheduled',
      scheduledAt: json['scheduled_at'],
      totalAmount: _parseDouble(json['total_amount']),
      note: json['note'],
      serviceAccount: DeliveryServiceAccount.fromJson(
        json['service_account'] ?? {},
      ),
      confirmationStatus: json['confirmation_status'] ?? 'pending',
      collectedAt: json['collected_at'],
      confirmedAt: json['confirmed_at'],
      completedAt: json['completed_at'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      items: items,
      invoice: json['invoice'] != null 
          ? DeliveryInvoice.fromJson(json['invoice'])
          : null,
    );
  }

  /// Cek apakah delivery bisa dikonfirmasi
  bool get canConfirm => 
      status == 'collected' && confirmationStatus == 'pending';

  /// Get label status dalam bahasa Indonesia
  String get statusLabel {
    switch (status) {
      case 'scheduled':
        return 'Terjadwal';
      case 'on_progress':
        return 'Dalam Perjalanan';
      case 'collected':
        return 'Sudah Diambil';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'skipped':
        return 'Dilewati';
      default:
        return status;
    }
  }

  /// Get label confirmation status dalam bahasa Indonesia
  String get confirmationStatusLabel {
    switch (confirmationStatus) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'skipped':
        return 'Dilewati';
      case 'no_waste':
        return 'Tidak Ada Sampah';
      default:
        return confirmationStatus;
    }
  }
}

/// Model untuk statistik
class WasteDeliveryStatistics {
  final int totalDeliveries;
  final int completed;
  final int scheduled;
  final int cancelled;
  final double totalEarned;

  WasteDeliveryStatistics({
    required this.totalDeliveries,
    required this.completed,
    required this.scheduled,
    required this.cancelled,
    required this.totalEarned,
  });

  factory WasteDeliveryStatistics.fromJson(Map<String, dynamic> json) {
    return WasteDeliveryStatistics(
      totalDeliveries: json['total_deliveries'] ?? 0,
      completed: json['completed'] ?? 0,
      scheduled: json['scheduled'] ?? 0,
      cancelled: json['cancelled'] ?? 0,
      totalEarned: _parseDouble(json['total_earned']),
    );
  }
}

/// Helper untuk parse double dari berbagai tipe
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

/// Service untuk mengelola Waste Delivery dari sisi Resident/Warga
class WasteDeliveryService {
  WasteDeliveryService() : _dio = ApiClient.instance.dio;

  final Dio _dio;

  /// 1. Daftar Pengambilan Sampah
  /// GET /resident/waste-deliveries
  Future<(bool success, String? message, List<WasteDelivery>? deliveries, Map<String, dynamic>? meta)> 
      getDeliveries({
    String? status,
    int? serviceAccountId,
    String? startDate,
    String? endDate,
    int? perPage,
  }) async {
    try {
      appLog('[NET] [WasteDeliveryService] GET ${ApiConfig.residentWasteDeliveries}');
      
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (serviceAccountId != null) queryParams['service_account_id'] = serviceAccountId;
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (perPage != null) queryParams['per_page'] = perPage;
      
      final response = await _dio.get(
        ApiConfig.residentWasteDeliveries,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      
      final body = response.data as Map<String, dynamic>;
      appLog('[DATA] [WasteDeliveryService] Response: $body');
      
      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>?;
        
        if (data != null) {
          final deliveriesJson = data['deliveries'] as List<dynamic>? ?? [];
          final deliveries = deliveriesJson
              .map((e) => WasteDelivery.fromJson(e as Map<String, dynamic>))
              .toList();
          
          final meta = data['meta'] as Map<String, dynamic>?;
          
          appLog('[OK] [WasteDeliveryService] Loaded ${deliveries.length} deliveries');
          return (true, null, deliveries, meta);
        }
        
        return (true, null, <WasteDelivery>[], null);
      } else {
        final msg = body['message']?.toString() ?? 
            body['errors']?['message']?.toString() ?? 
            'Gagal mengambil data pengambilan sampah';
        return (false, msg, null, null);
      }
    } on DioException catch (e) {
      appLog('[CRASH] [WasteDeliveryService] DioException: ${e.type}');
      appLog('[CRASH] [WasteDeliveryService] Response: ${e.response?.statusCode} - ${e.response?.data}');
      
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['message']?.toString() ?? 
            body['errors']?['message']?.toString() ?? msg;
      }
      return (false, msg, null, null);
    } catch (e) {
      appLog('[CRASH] [WasteDeliveryService] Exception: $e');
      return (false, 'Error: $e', null, null);
    }
  }

  /// 2. Detail Pengambilan Sampah
  /// GET /resident/waste-deliveries/{id}
  Future<(bool success, String? message, WasteDelivery? delivery)> 
      getDeliveryDetail(int id) async {
    try {
      appLog('[NET] [WasteDeliveryService] GET ${ApiConfig.residentWasteDeliveries}/$id');
      
      final response = await _dio.get(
        '${ApiConfig.residentWasteDeliveries}/$id',
      );
      
      final body = response.data as Map<String, dynamic>;
      
      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>?;
        
        if (data != null) {
          final delivery = WasteDelivery.fromJson(data);
          return (true, null, delivery);
        }
        
        return (false, 'Data tidak ditemukan', null);
      } else {
        final msg = body['message']?.toString() ?? 
            'Gagal mengambil detail pengambilan';
        return (false, msg, null);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.statusCode == 404) {
        msg = 'Pengambilan tidak ditemukan';
      } else if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['message']?.toString() ?? msg;
      }
      return (false, msg, null);
    } catch (e) {
      return (false, 'Error: $e', null);
    }
  }

  /// 3. Jadwal Pengambilan Berikutnya
  /// GET /resident/waste-deliveries/next/pickup
  Future<(bool success, String? message, WasteDelivery? nextPickup)> 
      getNextPickup({int? serviceAccountId}) async {
    try {
      appLog('[NET] [WasteDeliveryService] GET ${ApiConfig.residentWasteDeliveriesNextPickup}');
      
      final response = await _dio.get(
        ApiConfig.residentWasteDeliveriesNextPickup,
        queryParameters: serviceAccountId != null 
            ? {'service_account_id': serviceAccountId}
            : null,
      );
      
      final body = response.data as Map<String, dynamic>;
      
      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>?;
        
        if (data != null && data['next_pickup'] != null) {
          final delivery = WasteDelivery.fromJson(
            data['next_pickup'] as Map<String, dynamic>,
          );
          return (true, null, delivery);
        }
        
        // Tidak ada jadwal pengambilan
        final msg = data?['message']?.toString() ?? 'Tidak ada jadwal pengambilan';
        return (true, msg, null);
      } else {
        final msg = body['message']?.toString() ?? 
            'Gagal mengambil jadwal berikutnya';
        return (false, msg, null);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['message']?.toString() ?? msg;
      }
      return (false, msg, null);
    } catch (e) {
      return (false, 'Error: $e', null);
    }
  }

  /// 4. Statistik Pengambilan
  /// GET /resident/waste-deliveries/statistics
  Future<(bool success, String? message, WasteDeliveryStatistics? statistics)> 
      getStatistics({int? serviceAccountId}) async {
    try {
      appLog('[NET] [WasteDeliveryService] GET ${ApiConfig.residentWasteDeliveriesStatistics}');
      
      final response = await _dio.get(
        ApiConfig.residentWasteDeliveriesStatistics,
        queryParameters: serviceAccountId != null 
            ? {'service_account_id': serviceAccountId}
            : null,
      );
      
      final body = response.data as Map<String, dynamic>;
      
      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>?;
        
        if (data != null && data['statistics'] != null) {
          final stats = WasteDeliveryStatistics.fromJson(
            data['statistics'] as Map<String, dynamic>,
          );
          return (true, null, stats);
        }
        
        return (true, null, null);
      } else {
        final msg = body['message']?.toString() ?? 
            'Gagal mengambil statistik';
        return (false, msg, null);
      }
    } on DioException catch (e) {
      String msg = 'Terjadi kesalahan jaringan';
      if (e.response?.data is Map) {
        final body = e.response!.data as Map;
        msg = body['message']?.toString() ?? msg;
      }
      return (false, msg, null);
    } catch (e) {
      return (false, 'Error: $e', null);
    }
  }

  /// 5. Konfirmasi Pengambilan ⭐ (NEW API)
  /// POST /resident/waste-deliveries/{id}/confirm
  /// 
  /// Hanya bisa dikonfirmasi jika:
  /// - status = 'collected' 
  /// - confirmation_status = 'pending'
  Future<(bool success, String message, Map<String, dynamic>? data)> 
      confirmDelivery(int id) async {
    try {
      appLog('[NET] [WasteDeliveryService] POST ${ApiConfig.residentWasteDeliveries}/$id/confirm');
      
      final response = await _dio.post(
        '${ApiConfig.residentWasteDeliveries}/$id/confirm',
      );
      
      final body = response.data as Map<String, dynamic>;
      appLog('[DATA] [WasteDeliveryService] Confirm Response: $body');
      
      if (body['success'] == true) {
        final msg = body['message']?.toString() ?? 
            'Terima kasih! Pengambilan sampah telah dikonfirmasi.';
        final data = body['data'] as Map<String, dynamic>?;
        
        appLog('[OK] [WasteDeliveryService] Confirmation successful');
        return (true, msg, data);
      } else {
        final msg = body['message']?.toString() ?? 
            'Gagal mengkonfirmasi pengambilan';
        return (false, msg, null);
      }
    } on DioException catch (e) {
      appLog('[CRASH] [WasteDeliveryService] DioException on confirm: ${e.type}');
      appLog('[CRASH] [WasteDeliveryService] Response: ${e.response?.statusCode} - ${e.response?.data}');
      
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
      appLog('[CRASH] [WasteDeliveryService] Exception on confirm: $e');
      return (false, 'Error: $e', null);
    }
  }
}
