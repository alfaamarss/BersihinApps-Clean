import 'package:beresin_app/utils/app_log.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/tps.dart';
import '../models/tps_deposit.dart';
import 'token_storage.dart';

/// Service untuk mengelola TPS dan TPS Deposits
class TPSDepositService {
  static final String _baseUrl = '${ApiConfig.baseUrl}/mobile/collector';

  /// Get auth headers
  static Future<Map<String, String>> _getHeaders() async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// 1. Daftar TPS yang di-assign ke kolektor
  /// GET /api/v1/mobile/collector/tps
  static Future<List<TPS>> getAssignedTPS() async {
    try {
      appLog('[LOC] [TPSDepositService] Fetching assigned TPS list...');
      
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/tps'),
        headers: headers,
      );

      appLog('[DATA] [TPSDepositService] Response status: ${response.statusCode}');
      appLog('[DATA] [TPSDepositService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final tpsList = jsonResponse['data']['tps_list'] as List<dynamic>? ?? [];
          
          final result = tpsList.map((item) => TPS.fromJson(item)).toList();
          appLog('[OK] [TPSDepositService] Loaded ${result.length} TPS');
          return result;
        }
      }
      
      appLog('[WARN] [TPSDepositService] No TPS data found');
      return [];
    } catch (e, stackTrace) {
      appLog('[ERROR] [TPSDepositService] Error fetching TPS: $e');
      appLog('Stack trace: $stackTrace');
      return [];
    }
  }

  /// 2. Submit setor ke TPS
  /// POST /api/v1/mobile/collector/tps-deposits
  static Future<(bool success, String? message, TPSDeposit? data)> submitDeposit({
    required int garbageDumpId,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    try {
      appLog('📤 [TPSDepositService] Submitting deposit to TPS #$garbageDumpId...');
      appLog('   - Latitude: $latitude');
      appLog('   - Longitude: $longitude');
      appLog('   - Notes: $notes');

      final headers = await _getHeaders();
      final body = json.encode({
        'garbage_dump_id': garbageDumpId,
        'latitude': latitude,
        'longitude': longitude,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/tps-deposits'),
        headers: headers,
        body: body,
      );

      appLog('[DATA] [TPSDepositService] Response status: ${response.statusCode}');
      appLog('[DATA] [TPSDepositService] Response body: ${response.body}');

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 201) {
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final deposit = TPSDeposit.fromJson(jsonResponse['data']);
          appLog('[OK] [TPSDepositService] Deposit submitted successfully');
          return (true, jsonResponse['message']?.toString(), deposit);
        }
      }

      // Handle errors
      String errorMessage = jsonResponse['message']?.toString() ?? 'Gagal menyimpan data setor';
      
      if (jsonResponse['errors'] != null) {
        final errors = jsonResponse['errors'] as Map<String, dynamic>;
        final errorMessages = <String>[];
        errors.forEach((key, value) {
          if (value is List) {
            errorMessages.addAll(value.map((e) => e.toString()));
          } else {
            errorMessages.add(value.toString());
          }
        });
        if (errorMessages.isNotEmpty) {
          errorMessage = errorMessages.join(', ');
        }
      }

      appLog('[ERROR] [TPSDepositService] Submit failed: $errorMessage');
      return (false, errorMessage, null);
    } catch (e, stackTrace) {
      appLog('[ERROR] [TPSDepositService] Error submitting deposit: $e');
      appLog('Stack trace: $stackTrace');
      return (false, 'Terjadi kesalahan: $e', null);
    }
  }

  /// 3. Riwayat setor kolektor
  /// GET /api/v1/mobile/collector/tps-deposits
  static Future<(bool success, String? message, List<TPSDeposit> data, Map<String, dynamic>? meta)> getDepositHistory({
    int? garbageDumpId,
    String? startDate,
    String? endDate,
    int perPage = 15,
    int page = 1,
  }) async {
    try {
      appLog('📋 [TPSDepositService] Fetching deposit history...');
      
      final queryParams = <String, String>{
        'per_page': perPage.toString(),
        'page': page.toString(),
      };
      
      if (garbageDumpId != null) {
        queryParams['garbage_dump_id'] = garbageDumpId.toString();
      }
      if (startDate != null) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate;
      }

      final uri = Uri.parse('$_baseUrl/tps-deposits').replace(queryParameters: queryParams);
      final headers = await _getHeaders();
      
      final response = await http.get(uri, headers: headers);

      appLog('📥 [TPSDepositService] Response status: ${response.statusCode}');
      appLog('📥 [TPSDepositService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final depositsJson = jsonResponse['data']['deposits'] as List<dynamic>? ?? [];
          final deposits = depositsJson.map((item) => TPSDeposit.fromJson(item)).toList();
          final meta = jsonResponse['data']['meta'] as Map<String, dynamic>?;
          
          appLog('[OK] [TPSDepositService] Loaded ${deposits.length} deposits');
          return (true, null, deposits, meta);
        }
      }

      return (false, 'Gagal mengambil riwayat setor', <TPSDeposit>[], null);
    } catch (e, stackTrace) {
      appLog('[ERROR] [TPSDepositService] Error fetching history: $e');
      appLog('Stack trace: $stackTrace');
      return (false, 'Terjadi kesalahan: $e', <TPSDeposit>[], null);
    }
  }

  /// 4. Detail setor
  /// GET /api/v1/mobile/collector/tps-deposits/{id}
  static Future<(bool success, String? message, TPSDeposit? data)> getDepositDetail(int id) async {
    try {
      appLog('[SEARCH] [TPSDepositService] Fetching deposit detail #$id...');
      
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/tps-deposits/$id'),
        headers: headers,
      );

      appLog('[DATA] [TPSDepositService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final deposit = TPSDeposit.fromJson(jsonResponse['data']);
          appLog('[OK] [TPSDepositService] Loaded deposit detail');
          return (true, null, deposit);
        }
      }

      if (response.statusCode == 404) {
        return (false, 'Data setor tidak ditemukan', null);
      }

      return (false, 'Gagal mengambil detail setor', null);
    } catch (e, stackTrace) {
      appLog('[ERROR] [TPSDepositService] Error fetching detail: $e');
      appLog('Stack trace: $stackTrace');
      return (false, 'Terjadi kesalahan: $e', null);
    }
  }
}
