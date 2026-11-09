import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/token_storage.dart';

class CollectorOffSchedulePickupService {
  final String baseUrl = ApiConfig.baseUrl;

  /// List assigned off-schedule pickups for collector
  Future<List<Map<String, dynamic>>> listAssignedPickups({
    String? status,
    String? date,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      var url = '$baseUrl/mobile/collector/off-schedule-pickups';
      final queryParams = <String, String>{};
      
      if (status != null) queryParams['status'] = status;
      if (date != null) queryParams['date'] = date;
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> pickupsJson = data['data'];
        return pickupsJson.map((json) => Map<String, dynamic>.from(json)).toList();
      } else {
        throw Exception('Failed to load assigned pickups: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get off-schedule pickup detail with waste pricing
  Future<Map<String, dynamic>> getPickupDetail(int id) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('$baseUrl/mobile/collector/off-schedule-pickups/$id');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['data']);
      } else {
        throw Exception('Failed to load pickup detail: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Complete off-schedule pickup with waste items and photo
  Future<Map<String, dynamic>> completePickup({
    required int id,
    required String photoBase64,
    required List<Map<String, dynamic>> wasteItems,
    String? collectorNotes,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('$baseUrl/mobile/collector/off-schedule-pickups/$id/complete');
      
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'photo': photoBase64,
          'waste_items': wasteItems,
          if (collectorNotes != null) 'collector_notes': collectorNotes,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['data']);
      } else if (response.statusCode == 413) {
        throw Exception('Ukuran foto terlalu besar untuk server. Silakan gunakan foto yang lebih kecil.');
      } else if (response.statusCode == 422) {
        final error = jsonDecode(response.body);
        final errors = error['errors'] as Map<String, dynamic>?;
        if (errors != null) {
          final firstError = errors.values.first;
          final errorMessage = firstError is List ? firstError.first : firstError.toString();
          throw Exception(errorMessage);
        }
        throw Exception(error['message'] ?? 'Validation error');
      } else {
        throw Exception('Failed to complete pickup: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Koneksi ke server terputus (${e.message}). Pastikan jaringan stabil dan ukuran foto tidak terlalu besar.');
    } catch (e) {
      rethrow;
    }
  }

  /// Skip/reject off-schedule pickup
  Future<Map<String, dynamic>> skipPickup({
    required int id,
    required String reason,
    String? notes,
  }) async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('$baseUrl/mobile/collector/off-schedule-pickups/$id/skip');
      
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'reason': reason,
          if (notes != null) 'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['data']);
      } else {
        throw Exception('Failed to skip pickup: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
