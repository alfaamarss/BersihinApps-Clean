import 'package:beresin_app/utils/app_log.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../main.dart' show navigatorKey;
import 'token_storage.dart';
import 'user_storage.dart';

class ApiClient {
  // ✅ Flag untuk mencegah multiple token expired handling
  static bool _isHandlingTokenExpired = false;

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: false,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
      logPrint: (obj) => appLog('[API-DEBUG] $obj'),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Skip token check untuk endpoint yang tidak memerlukan auth
        final isAuthEndpoint = options.path.contains('/login') || 
                               options.path.contains('/register') ||
                               options.path.contains('/forgot-password') ||
                               options.path.contains('/reset-password');
        
        if (!isAuthEndpoint) {
          // Cek apakah ada token dulu
          final token = await TokenStorage.getTokenWithoutExpiryCheck();
          
          if (token != null && token.isNotEmpty) {
            // Ada token, cek apakah expired
            if (await TokenStorage.isTokenExpired()) {
              appLog('[API] Token expired, redirecting to splash...');
              await _handleTokenExpired();
              return handler.reject(
                DioException(
                  requestOptions: options,
                  error: 'Token expired',
                  type: DioExceptionType.cancel,
                ),
              );
            }
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        
        handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 Unauthorized - token invalid/expired dari server
        // ✅ PERBAIKAN: Jangan handle 401 untuk endpoint auth (login, register, dll)
        // karena 401 di login berarti password salah, bukan token expired
        final isAuthEndpoint = error.requestOptions.path.contains('/login') || 
                               error.requestOptions.path.contains('/register') ||
                               error.requestOptions.path.contains('/forgot-password') ||
                               error.requestOptions.path.contains('/reset-password');
        
        if (error.response?.statusCode == 401 && !isAuthEndpoint) {
          appLog('[API] Received 401 Unauthorized, token invalid');
          await _handleTokenExpired();
        }
        handler.next(error);
      },
    ));
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  Dio get dio => _dio;

  /// Handle token expired - clear data dan redirect ke splash
  /// ✅ Menggunakan flag untuk mencegah multiple handling
  static Future<void> _handleTokenExpired() async {
    // Cegah multiple handling
    if (_isHandlingTokenExpired) {
      appLog('[API] Already handling token expired, skipping...');
      return;
    }
    
    _isHandlingTokenExpired = true;
    
    try {
      // Clear token dan user data
      await TokenStorage.clearToken();
      await UserStorage.clearUser();
      
      // Redirect ke splash screen dengan parameter sessionExpired
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        // Clear semua route dan ke splash dengan sessionExpired = true
        navigator.pushNamedAndRemoveUntil(
          '/', 
          (route) => false,
          arguments: {'sessionExpired': true},
        );
      }
    } catch (e) {
      appLog('[API] Error handling token expired: $e');
    } finally {
      // Reset flag setelah beberapa waktu untuk allow future logouts
      Future.delayed(const Duration(seconds: 5), () {
        _isHandlingTokenExpired = false;
      });
    }
  }

  /// Public method untuk force logout (bisa dipanggil dari mana saja)
  static Future<void> forceLogout({String? message}) async {
    await _handleTokenExpired();
  }
}
