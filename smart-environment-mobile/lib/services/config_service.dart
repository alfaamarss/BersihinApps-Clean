import 'package:beresin_app/utils/app_log.dart';
import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/app_settings.dart';
import 'api_client.dart';

class ConfigService {
  ConfigService() : _dio = ApiClient.instance.dio;

  final Dio _dio;

  Future<AppSettingsData?> fetchAppSettings() async {
    appLog('🌐 [ConfigService] Fetching settings from: ${ApiConfig.mobileSettings}');
    final response = await _dio.get(ApiConfig.mobileSettings);
    final Map<String, dynamic> body = response.data as Map<String, dynamic>;
    
    appLog('📦 [ConfigService] Raw response: $body');

    if (body['success'] != true) {
      throw Exception(body['errors']?['message'] ?? 'Gagal memuat pengaturan');
    }

    final data = body['data'];
    appLog('📊 [ConfigService] Data from response: $data');
    
    if (data is Map<String, dynamic>) {
      final settings = AppSettingsData.fromJson(data);
      appLog('✅ [ConfigService] Parsed settings:');
      appLog('   - Province: ${settings.province?.name} (ID: ${settings.province?.id})');
      appLog('   - City: ${settings.city?.name} (ID: ${settings.city?.id})');
      return settings;
    }

    return null;
  }
}
