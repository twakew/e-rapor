import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
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
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    final prefs = await SharedPreferences.getInstance();
    
    String? detectedRole;
    String? studentName = prefs.getString('student_name');
    String? studentNis = prefs.getString('student_nis');
    String? studentClass = prefs.getString('student_class');

    // JIKA ADA SESI SUPABASE (ADMIN/GURU)
    if (session != null) {
      final user = session.user;
      if (user.email == 'triandre980@gmail.com') {
        detectedRole = 'Admin';
      } else {
        try {
          final data = await supabase
              .from('profiles')
              .select('role, is_verified')
              .eq('id', user.id)
              .maybeSingle();
          if (data != null && data['is_verified'] == true) {
            detectedRole = data['role'];
          } else {
            // Jika akun belum diverifikasi, paksa sign out agar balik ke login
            await supabase.auth.signOut();
          }
        } catch (e) {
          debugPrint('Error pre-fetching role: $e');
        }
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
            (session != null || studentNis != null)
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
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient yang Mewah
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade900,
                  Colors.blue.shade800,
                  Colors.blue.shade600,
                ],
              ),
            ),
          ),
          
          // Dekorasi Lingkaran Abstrak
          Positioned(
            top: -100,
            right: -100,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),

          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo dengan Efek Denyut (Pulse)
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          size: 80,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Teks Judul
                    const Text(
                      'LAPOR SEKOLAH',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    Text(
                      'e-Rapor Digital',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 60),
                    // Loading Indicator Modern - Tiga Titik Berdenyut
                    const _ThreeDotsLoader(),
                  ],
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
                        color: Colors.white.withValues(alpha: 0.2),
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
