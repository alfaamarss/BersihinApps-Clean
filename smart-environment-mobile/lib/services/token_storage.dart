import 'package:beresin_app/utils/app_log.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _key = 'auth_token';
  static const _loginTimeKey = 'login_time';
  static const _tokenExpiryDays = 30; // Token expired setelah 30 hari (1 bulan)
  static const _storage = FlutterSecureStorage();

  /// Simpan token dan waktu login
  static Future<void> saveToken(String token) async {
    final loginTime = DateTime.now().toIso8601String();

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, token);
      await prefs.setString(_loginTimeKey, loginTime);
    } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await _storage.write(key: _key, value: token);
      await _storage.write(key: _loginTimeKey, value: loginTime);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, token);
      await prefs.setString(_loginTimeKey, loginTime);
    }
    appLog('[TOKEN] Token saved at: $loginTime');
  }

  /// Ambil token tanpa cek expiry (untuk internal check)
  static Future<String?> getTokenWithoutExpiryCheck() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_key);
      } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        return await _storage.read(key: _key);
      } else {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_key);
      }
    } catch (e) {
      appLog('[ERROR] [TokenStorage] Error getting token: $e');
      return null;
    }
  }

  /// Ambil token (return null jika expired)
  static Future<String?> getToken() async {
    try {
      // Check apakah token sudah expired
      if (await isTokenExpired()) {
        appLog('[TOKEN] Token expired, clearing...');
        await clearToken();
        return null;
      }

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_key);
      } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        return await _storage.read(key: _key);
      } else {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_key);
      }
    } catch (e) {
      appLog('[ERROR] [TokenStorage] Error getting token: $e');
      return null;
    }
  }

  /// Ambil waktu login
  static Future<DateTime?> getLoginTime() async {
    try {
      String? loginTimeStr;

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        loginTimeStr = prefs.getString(_loginTimeKey);
      } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        loginTimeStr = await _storage.read(key: _loginTimeKey);
      } else {
        final prefs = await SharedPreferences.getInstance();
        loginTimeStr = prefs.getString(_loginTimeKey);
      }

      if (loginTimeStr != null) {
        return DateTime.tryParse(loginTimeStr);
      }
      return null;
    } catch (e) {
      appLog('[ERROR] [TokenStorage] Error getting login time: $e');
      return null;
    }
  }

  /// Check apakah token sudah expired (lebih dari 30 hari)
  static Future<bool> isTokenExpired() async {
    try {
      // Cek apakah ada token dulu
      final token = await getTokenWithoutExpiryCheck();
      if (token == null || token.isEmpty) {
        // Tidak ada token, bukan expired tapi memang belum login
        return false;
      }

      final loginTime = await getLoginTime();
      if (loginTime == null) {
        // Ada token tapi tidak ada waktu login (legacy), anggap tidak expired
        // Ini untuk backward compatibility dengan user yang sudah login sebelumnya
        return false;
      }

      final now = DateTime.now();
      final difference = now.difference(loginTime);
      final isExpired = difference.inDays >= _tokenExpiryDays;

      if (isExpired) {
        appLog(
          '[TOKEN] Token expired! Login time: $loginTime, Days passed: ${difference.inDays}',
        );
      }

      return isExpired;
    } catch (e) {
      appLog('[ERROR] [TokenStorage] Error checking expiry: $e');
      return false;
    }
  }

  /// Hitung sisa hari sebelum token expired
  static Future<int> getDaysUntilExpiry() async {
    try {
      final loginTime = await getLoginTime();
      if (loginTime == null) return 0;

      final now = DateTime.now();
      final difference = now.difference(loginTime);
      final daysRemaining = _tokenExpiryDays - difference.inDays;

      return daysRemaining > 0 ? daysRemaining : 0;
    } catch (e) {
      return 0;
    }
  }

  /// Hapus token dan waktu login
  static Future<void> clearToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_loginTimeKey);
    } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await _storage.delete(key: _key);
      await _storage.delete(key: _loginTimeKey);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_loginTimeKey);
    }
    appLog('[TOKEN] Token cleared');
  }
}
