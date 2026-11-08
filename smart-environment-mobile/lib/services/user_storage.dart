import 'package:beresin_app/utils/app_log.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserStorage {
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRoles = 'user_roles';
  static const String _keyUserData = 'user_data'; // ✅ TAMBAHAN: Full user data
  static const String _keyToken = 'auth_token'; // Token autentikasi

  /// Simpan token autentikasi
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  /// Ambil token autentikasi
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  /// Simpan data user ke SharedPreferences
  static Future<void> saveUser({
    required int id,
    required String name,
    required String email,
    List<String>? roles,
    Map<String, dynamic>? fullData, // ✅ TAMBAHAN: Simpan full data
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, id);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);

    if (roles != null && roles.isNotEmpty) {
      await prefs.setString(_keyUserRoles, jsonEncode(roles));
    } else {
      await prefs.remove(_keyUserRoles);
    }

    // ✅ TAMBAHAN: Simpan full user data untuk akses RW dan field lainnya
    if (fullData != null) {
      await prefs.setString(_keyUserData, jsonEncode(fullData));
    }
  }

  /// Ambil ID user
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  /// Ambil nama user
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  /// Ambil email user
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  /// Ambil roles user
  static Future<List<String>> getUserRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final rolesJson = prefs.getString(_keyUserRoles);

    if (rolesJson == null || rolesJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(rolesJson);
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Check apakah user memiliki role tertentu
  static Future<bool> hasRole(String roleName) async {
    final roles = await getUserRoles();
    return roles.contains(roleName);
  }

  /// Check apakah user adalah collector
  static Future<bool> isCollector() async {
    try {
      return await hasRole('collector') || await hasRole('kolektor');
    } catch (e) {
      appLog('[ERROR] [UserStorage] Error checking isCollector: $e');
      return false; // Default to false jika error
    }
  }

  /// Check apakah user adalah warga
  static Future<bool> isWarga() async {
    return await hasRole('warga') || await hasRole('user');
  }

  /// Ambil semua data user
  static Future<Map<String, dynamic>?> getUser() async {
    final id = await getUserId();
    final name = await getUserName();
    final email = await getUserEmail();
    final roles = await getUserRoles();

    if (id == null || name == null || email == null) {
      return null;
    }

    return {'id': id, 'name': name, 'email': email, 'roles': roles};
  }

  /// ✅ TAMBAHAN: Ambil full user data dari SharedPreferences
  static Future<Map<String, dynamic>?> getFullUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataJson = prefs.getString(_keyUserData);

    if (userDataJson == null || userDataJson.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(userDataJson) as Map<String, dynamic>;
    } catch (e) {
      appLog('[ERROR] [UserStorage] Error parsing full user data: $e');
      return null;
    }
  }

  /// ✅ TAMBAHAN: Ambil RW kolektor
  static Future<String?> getKolektorRW() async {
    final userData = await getFullUserData();
    if (userData == null) return null;

    // Cari RW di berbagai kemungkinan field
    return userData['rw']?.toString() ??
        userData['assigned_rw']?.toString() ??
        userData['collector_rw']?.toString();
  }

  /// Hapus semua data user
  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserRoles);
    await prefs.remove(_keyUserData); // ✅ TAMBAHAN: Hapus full user data
    await prefs.remove(_keyToken); // Hapus token
  }
}
