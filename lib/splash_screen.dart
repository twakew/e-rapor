import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:laporsekolaherapor/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'login&register/loginpath.dart';
import 'dasbhor/dasbhor.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Controller untuk animasi muncul (Fade & Scale)
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Controller untuk animasi berdenyut (Pulse) pada logo
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mainController.forward();
    _startNavigation();
  }

  Future<void> _startNavigation() async {
    // Jalankan logika navigasi paralel dengan animasi
    await Future.delayed(const Duration(milliseconds: 2500));
    await _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    final apiService = ApiService();
    final prefs = await SharedPreferences.getInstance();
    
    String? detectedRole;
    String? studentName = prefs.getString('student_name');
    String? studentNis = prefs.getString('student_nis');
    String? studentClass = prefs.getString('student_class');

    // JIKA ADA SESI LOGIN VIA API (GURU/ADMIN)
    if (apiService.isLoggedIn) {
      try {
        // Ambil ID dari JWT Token
        String token = prefs.getString('jwt_token') ?? '';
        if (token.isNotEmpty) {
           Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
           String userId = decodedToken['id'];

           final data = await apiService.getRow('profiles', userId);
           if (data['is_verified'] == true) {
             // Normalisasi Super Admin -> Admin supaya UI konsisten
             detectedRole = data['role'].toString() == 'Super Admin'
                 ? 'Admin'
                 : data['role'].toString();
           } else {
             // Jika akun belum diverifikasi, paksa sign out agar balik ke login
             await apiService.logout();
           }
        }
      } catch (e) {
        debugPrint('Error pre-fetching role: $e');
        await apiService.logout();
      }
    } 
    // JIKA TIDAK ADA SESI TAPI ADA DATA SISWA (USER)
    else if (studentNis != null) {
      detectedRole = 'User';
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            (apiService.isLoggedIn || studentNis != null)
              ? DasbhorPage(
                  initialRole: detectedRole,
                  studentName: studentName,
                  studentNis: studentNis,
                  studentClass: studentClass,
                )
              : const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Deep Indigo matching AppColors
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E1B4B), // Deep Indigo 950
                  Color(0xFF312E81), // Indigo 900
                  AppColors.primary, // Indigo 600 (#4F46E5)
                ],
              ),
            ),
          ),

          // Glowing Ambient Orbs
          Positioned(
            top: -size.width * 0.3,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -size.width * 0.25,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 0.7,
              height: size.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Main Center Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App Category Pill Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.school_outlined, color: Colors.amberAccent, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Aplikasi e-Rapor Digital',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Logo Container with Pulse Animation & Glassmorphic Glow
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.3),
                                    Colors.white.withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 36,
                                      offset: const Offset(0, 12),
                                    ),
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Hero(
                                    tag: 'app_logo',
                                    child: Icon(
                                      Icons.school_rounded,
                                      size: 64,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // App Title & Subtitle
                          const Text(
                            'LAPOR SEKOLAH',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 3.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sistem Informasi Hasil Belajar Digital',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.8),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Loading Dots Indicator
                          const _ThreeDotsLoader(),
                          const SizedBox(height: 28),

                          // Version Footer
                          Text(
                            'v1.0.0 • e-Rapor Mobile System',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.5),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeDotsLoader extends StatefulWidget {
  const _ThreeDotsLoader();

  @override
  State<_ThreeDotsLoader> createState() => _ThreeDotsLoaderState();
}

class _ThreeDotsLoaderState extends State<_ThreeDotsLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            double opacity = 0.3;
            double scale = 0.8;
            
            // Logika untuk membuat animasi berurutan (sequenced)
            final double progress = (_controller.value - (index * 0.2)).clamp(0.0, 1.0);
            if (progress > 0 && progress < 0.5) {
              opacity = 0.3 + (progress * 1.4); // Naik ke 1.0
              scale = 0.8 + (progress * 0.4); // Naik ke 1.0
            } else if (progress >= 0.5 && progress < 1.0) {
              opacity = 1.0 - ((progress - 0.5) * 1.4); // Turun ke 0.3
              scale = 1.0 - ((progress - 0.5) * 0.4); // Turun ke 0.8
            }

            return Transform.scale(
              scale: scale,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 10,
                width: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (opacity > 0.7)
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
