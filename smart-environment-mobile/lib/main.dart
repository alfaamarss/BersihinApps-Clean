import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:device_wrapper/device_wrapper.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/user/home_screen.dart';
import 'screens/user/layanan_sampah_screen.dart';
import 'screens/user/profile_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/user/artikel_screen.dart';
import 'screens/user/artikel_detail_screen.dart';
import 'screens/user/pelaporan_screen.dart';
import 'screens/user/riwayat_pembayaran_screen.dart';
import 'screens/user/express_request_screen.dart';
import 'screens/kolektor/home_screens_kolektor.dart';

/// Global navigator key untuk akses navigation dari mana saja (termasuk ApiClient)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Toggle device wrapper - hanya aktif di web
const bool _enableDeviceWrapper = true;

void main() {
  runApp(const BeresinApp());
}

class BeresinApp extends StatelessWidget {
  const BeresinApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Build MaterialApp
    final app = MaterialApp(
      title: 'Bersihin',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
        },
      ),
      initialRoute: '/',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/layanan-sampah': (context) => const LayananSampahScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/artikel': (context) => const ArtikelScreen(),
        '/pelaporan': (context) => const PelaporanScreen(),
        '/riwayat-pembayaran': (context) => const RiwayatPembayaranScreen(),
        '/express-request': (context) => const ExpressRequestScreen(),
        '/home-kolektor': (context) => const HomeScreensKolektor(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          final args = settings.arguments;
          bool sessionExpired = false;
          if (args is Map<String, dynamic>) {
            sessionExpired = args['sessionExpired'] ?? false;
          }
          return MaterialPageRoute(
            builder: (context) => SplashScreen(sessionExpired: sessionExpired),
          );
        }
        if (settings.name == '/artikel-detail') {
          final artikelId = settings.arguments as int?;
          if (artikelId != null) {
            return MaterialPageRoute(
              builder: (context) => ArtikelDetailScreen(articleId: artikelId),
            );
          }
        }
        return null;
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text(
                "404 - Halaman tidak ditemukan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );

    // Wrap dengan DeviceWrapper HANYA jika di web dan diaktifkan
    if (kIsWeb && _enableDeviceWrapper) {
      return DeviceWrapper(child: app);
    }

    return app;
  }
}
