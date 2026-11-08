import 'package:beresin_app/utils/app_log.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/token_storage.dart';
import '../services/user_storage.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool sessionExpired;

  const SplashScreen({super.key, this.sessionExpired = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _logoController;
  late AnimationController _exitController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _logoScaleExitAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _backgroundFadeAnimation;

  @override
  void initState() {
    super.initState();

    // Controller animasi background wave
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Controller animasi pulse logo
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Controller animasi exit (zoom out + fade)
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // Animasi logo zoom out saat exit
    _logoScaleExitAnimation = Tween<double>(begin: 1.0, end: 3.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOutCubic),
      ),
    );

    // Animasi fade out logo
    _logoFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    // Animasi fade out background
    _backgroundFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // Cek jika sesi berakhir
    if (widget.sessionExpired) {
      // Tampilkan snackbar sesi berakhir lalu redirect ke login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // ✅ Clear snackbar sebelumnya untuk mencegah duplikasi
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesi Anda telah berakhir. Silakan login kembali.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
      // Redirect ke login setelah 3 detik
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _navigateToLogin();
        }
      });
    } else {
      // Check auto-login
      _checkAutoLogin();
    }
  }

  Future<void> _checkAutoLogin() async {
    try {
      appLog(' [Splash] Starting auto-login check...');

      // Tunggu 5 detik untuk splash screen
      await Future.delayed(const Duration(seconds: 5));

      if (!mounted) {
        appLog(' [Splash] Widget not mounted, aborting');
        return;
      }

      final token = await TokenStorage.getToken();
      appLog(
        ' [Splash] Token: ${token != null ? "Found (${token.substring(0, 20)}...)" : "Not found"}',
      );

      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        // User sudah login, check role untuk redirect
        appLog(' [Splash] Checking user role...');
        final isCollector = await UserStorage.isCollector();
        appLog(' [Splash] Is collector: $isCollector');

        if (!mounted) return;

        if (isCollector) {
          appLog(' [Splash] Redirecting to collector home...');
          _navigateToHome('/home-kolektor');
        } else {
          appLog(' [Splash] Redirecting to user home...');
          _navigateToHome('/home');
        }
      } else {
        // Belum login, redirect ke login dengan animasi
        appLog(' [Splash] No token found, redirecting to login...');
        _navigateToLogin();
      }
    } catch (e, stackTrace) {
      appLog(' [Splash] Error during auto-login check: $e');
      appLog('Stack trace: $stackTrace');

      // Jika error, redirect ke login
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  /// Navigasi ke login dengan animasi zoom + fade
  void _navigateToLogin() async {
    // Stop logo pulse animation
    _logoController.stop();

    // Jalankan animasi exit
    await _exitController.forward();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const LoginScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Kombinasi fade + scale + slide untuk login screen
          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
            ),
          );

          final scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
            ),
          );

          final slideAnimation =
              Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
                ),
              );

          return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: SlideTransition(position: slideAnimation, child: child),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
        reverseTransitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  /// Navigasi ke home dengan animasi
  void _navigateToHome(String route) async {
    // Stop logo pulse animation
    _logoController.stop();

    // Jalankan animasi exit
    await _exitController.forward();

    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  void dispose() {
    _waveController.dispose();
    _logoController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitController,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              // ===== Wave Background dengan fade =====
              Opacity(
                opacity: _backgroundFadeAnimation.value,
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return ClipPath(
                          clipper: WaveClipper1(_waveController.value),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.55,
                            color: const Color(0xFF2A8D7C),
                          ),
                        );
                      },
                    ),
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return ClipPath(
                          clipper: WaveClipper2(_waveController.value),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.50,
                            color: const Color(0xFF36B8A6).withAlpha(179),
                          ),
                        );
                      },
                    ),
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return ClipPath(
                          clipper: WaveClipper3(_waveController.value),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.45,
                            color: const Color(0xFF4ECDC4).withAlpha(128),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ===== Konten Utama dengan animasi exit =====
              Center(
                child: Opacity(
                  opacity: _logoFadeAnimation.value,
                  child: Transform.scale(
                    scale:
                        _logoScaleExitAnimation.value * _scaleAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo PNG
                        Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 20,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Image.asset(
                              'assets/images/beresin.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Judul
                        Text(
                          "BERESIN",
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4CAF50),
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Subjudul
                        Text(
                          "Waste Management App",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ===== Versi Aplikasi =====
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _backgroundFadeAnimation.value,
                  child: Center(
                    child: Text(
                      "V. 1.0.0",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ====================
/// Wave Clippers
/// ====================
class WaveClipper1 extends CustomClipper<Path> {
  final double animationValue;
  WaveClipper1(this.animationValue);

  @override
  Path getClip(Size size) {
    Path path = Path();
    double waveHeight = 40;
    double waveLength = size.width / 1.0;

    path.lineTo(0, size.height - waveHeight);
    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        size.height -
            waveHeight -
            math.sin(
                  (i / waveLength * 2 * math.pi) +
                      (animationValue * 2 * math.pi),
                ) *
                20,
      );
    }
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WaveClipper1 oldClipper) => true;
}

class WaveClipper2 extends CustomClipper<Path> {
  final double animationValue;
  WaveClipper2(this.animationValue);

  @override
  Path getClip(Size size) {
    Path path = Path();
    double waveHeight = 30;
    double waveLength = size.width / 1.2;

    path.lineTo(0, size.height - waveHeight);
    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        size.height -
            waveHeight -
            math.sin(
                  (i / waveLength * 2 * math.pi) +
                      (animationValue * 2 * math.pi),
                ) *
                15,
      );
    }
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WaveClipper2 oldClipper) => true;
}

class WaveClipper3 extends CustomClipper<Path> {
  final double animationValue;
  WaveClipper3(this.animationValue);

  @override
  Path getClip(Size size) {
    Path path = Path();
    double waveHeight = 20;
    double waveLength = size.width / 1.5;

    path.lineTo(0, size.height - waveHeight);
    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        size.height -
            waveHeight -
            math.sin(
                  (i / waveLength * 2 * math.pi) +
                      (animationValue * 2 * math.pi),
                ) *
                10,
      );
    }
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WaveClipper3 oldClipper) => true;
}
