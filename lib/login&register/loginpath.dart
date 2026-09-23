import 'package:flutter/material.dart';
import 'package:laporsekolaherapor/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'dart:async';
import '../utils/notification_helper.dart';
import '../utils/push_notification_service.dart';
import '../dasbhor/dasbhor.dart';
import 'register.dart';

class LoginPage extends StatefulWidget {
  final String? initialEmail;

  const LoginPage({super.key, this.initialEmail});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail ?? '';
    // Cek apakah ada blokir yang masih aktif dari sesi sebelumnya
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPersistedBlock();
    });
  }

  Future<void> _checkPersistedBlock() async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = prefs.getInt('login_block_expiry') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (expiry > now) {
      final remaining = ((expiry - now) / 1000).round();
      if (mounted && remaining > 0) {
        _showCountdownDialog(remaining);
      }
    }
  }

  void _showCountdownDialog(int initialSeconds) {
    // Simpan waktu kadaluarsa ke SharedPreferences agar tetap ada saat aplikasi dibuka ulang
    SharedPreferences.getInstance().then((prefs) {
      final expiry = DateTime.now().add(Duration(seconds: initialSeconds)).millisecondsSinceEpoch;
      prefs.setInt('login_block_expiry', expiry);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CountdownDialog(initialSeconds: initialSeconds),
    );
  }

  Future<void> _forgotPassword() async {
    // Tidak ada alur reset-email di backend (endpoint reset tanpa verifikasi
    // pernah dihapus karena celah keamanan takeover akun). Arahkan ke admin.
    final pageContext = context;

    final sent = await showDialog<bool>(
      context: pageContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 10,
            backgroundColor: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lupa Kata Sandi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Untuk keamanan akun, kata sandi hanya dapat diatur ulang oleh admin sekolah. Silakan hubungi admin sekolah untuk mereset kata sandi Anda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey.shade300),
                            foregroundColor: AppColors.textSecondary,
                          ),
                          child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (sent == true && mounted) {
      NotificationHelper.show(context, 'Silakan hubungi admin sekolah untuk reset kata sandi');
    }
  }

  Future<void> _login() async {
    String identifier = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      NotificationHelper.show(context, 'NIS/Email dan password harus diisi', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // --- JALUR LOGIN KHUSUS SISWA (NIS) ---
      if (RegExp(r'^[0-9]+$').hasMatch(identifier)) {
        // Cek blokir untuk NIS sebelum lanjut
        try {
          final isBlockedResp = await ApiService().callRpc('check_auth_blocked', params: {'p_identifier': identifier});
          final isBlocked = isBlockedResp is bool ? isBlockedResp : false;
          if (isBlocked) {
            if (mounted) {
              _showCountdownDialog(60);
              setState(() => _isLoading = false);
            }
            return;
          }
        } catch (_) {}

        final result = await ApiService().callRpc('get_student_auth', params: {'p_nis': identifier});
        final studentData = (result is List && result.isNotEmpty) ? result.first : null;

        if (studentData != null && password == identifier) {
          unawaited(ApiService().callRpc('reset_login_attempts', params: {'p_identifier': identifier}));
          unawaited(SharedPreferences.getInstance().then((prefs) {
            prefs.setString('student_name', studentData['name']);
            prefs.setString('student_nis', studentData['nis']);
            prefs.setString('student_class', studentData['class'] ?? '');
            prefs.setString('user_role', 'User');
          }));

          PushNotificationService.login(studentData['nis'].toString());
          // Hapus semua tag role lama sebersih mungkin Melalui Service
          PushNotificationService.removeTag('role');
          PushNotificationService.setTag('role', 'user');
          debugPrint('OneSignal: Role Admin/Guru dibersihkan, di-set ke User');

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DasbhorPage(
                  initialRole: 'User',
                  studentName: studentData['name'],
                  studentNis: studentData['nis'],
                  studentClass: studentData['class'],
                ),
              ),
            );
          }
          return;
        } else if (studentData != null) {
          await ApiService().callRpc('record_login_failure', params: {'p_identifier': identifier});

          try {
            final isBlockedResp = await ApiService().callRpc('check_auth_blocked', params: {'p_identifier': identifier});
            final isBlocked = isBlockedResp is bool ? isBlockedResp : false;
            if (isBlocked) {
              if (mounted) {
                _showCountdownDialog(60);
                setState(() => _isLoading = false);
              }
              return;
            }
          } catch (_) {}

          if (mounted) {
            NotificationHelper.show(context, 'Kata sandi NIS salah!', isError: true);
            setState(() => _isLoading = false);
          }
          return;
        }
      }

      // --- JALUR LOGIN GURU / ADMIN (EMAIL) ---
      final String emailFinal = identifier.contains('@') ? identifier : '$identifier@alhanif.id';

      try {
        final isBlockedResp = await ApiService().callRpc('check_auth_blocked', params: {'p_identifier': emailFinal});
        final isBlocked = isBlockedResp is bool ? isBlockedResp : false;
        if (isBlocked) {
          if (mounted) _showCountdownDialog(60);
          setState(() => _isLoading = false);
          return;
        }
      } catch (_) {}

      final response = await ApiService().login(emailFinal, password);

      if (response['token'] != null) {
        unawaited(ApiService().callRpc('reset_login_attempts', params: {'p_identifier': emailFinal}));

        final user = response['user'];
        final profileData = await ApiService().getRow('profiles', user['id'].toString());

        if (profileData['is_verified'] != true) {
          await ApiService().logout();
          if (mounted) NotificationHelper.show(context, 'Akun belum diverifikasi Admin.', isError: true);
          setState(() => _isLoading = false);
          return;
        }

        final role = profileData['role'].toString() == 'Super Admin' ? 'Admin' : profileData['role'].toString();

        PushNotificationService.login(user['id'].toString());
        PushNotificationService.setTag('role', role.toLowerCase());

        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DasbhorPage(initialRole: role)));
        }
      }
    } catch (error) {
      String errorMessage = error.toString();
      final String emailFinal = identifier.contains('@') ? identifier : '$identifier@alhanif.id';

      if (!errorMessage.contains('Terlalu banyak percobaan')) {
        try {
          await ApiService().callRpc('record_login_failure', params: {'p_identifier': emailFinal});

          final isBlockedResp = await ApiService().callRpc('check_auth_blocked', params: {'p_identifier': emailFinal});
          final isBlocked = isBlockedResp is bool ? isBlockedResp : false;
          if (isBlocked) {
            if (mounted) _showCountdownDialog(60);
            return;
          }
        } catch (_) {}
      }

      if (errorMessage.contains('Terlalu banyak percobaan')) {
        if (mounted) _showCountdownDialog(900); // jendela rate limit backend: 15 menit
      } else if (errorMessage.contains('belum diverifikasi')) {
        if (mounted) NotificationHelper.show(context, 'Akun belum diverifikasi Admin.', isError: true);
      } else if (errorMessage.contains('minimal 8 karakter')) {
        if (mounted) NotificationHelper.show(context, 'Password minimal 8 karakter.', isError: true);
      } else if (errorMessage.contains('Invalid email or password') ||
          errorMessage.contains('Invalid login credentials') ||
          errorMessage.contains('Login gagal')) {
        if (mounted) NotificationHelper.show(context, 'Kata sandi Email salah!', isError: true);
      } else {
        if (mounted) NotificationHelper.show(context, 'Gagal masuk. Cek koneksi & akun Anda.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToRegister() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const RegisterPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;
          var border = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(border), child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return _buildDesktopLayout(context);
          } else {
            return _buildMobileLayout(context);
          }
        },
      ),
    );
  }

  // --- DESKTOP LAYOUT (2-COLUMN SPLIT SCREEN) ---
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Left Branding Showcase Panel
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF312E81), // Deep Indigo 900
                  AppColors.brand,
                  AppColors.brandDark,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Background Ambient Glow Circles
                Positioned(
                  top: -80,
                  left: -80,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -100,
                  right: -50,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),

                // Main Content Showcase with Scroll & Flex Protection
                LayoutBuilder(
                  builder: (context, leftConstraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: leftConstraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 28.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Header Badge
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                      ),
                                      child: const Hero(
                                        tag: 'app_logo',
                                        child: Icon(Icons.school_rounded, color: Colors.white, size: 24),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'e-Rapor Mobile',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        Text(
                                          'Sistem Informasi Akademik',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.75),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Middle Feature Highlights
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.star_rounded, color: Colors.amberAccent, size: 14),
                                          SizedBox(width: 6),
                                          Text(
                                            'Portal Digital Terpadu Sekolah',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'Kelola & Pantau Rapor\nSiswa Lebih Mudah',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        height: 1.2,
                                        letterSpacing: -0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Platform digital modern untuk transparansi laporan hasil belajar, absensi, dan administrasi sekolah secara realtime.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 12.5,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Feature Cards List
                                    _buildDesktopFeatureCard(
                                      icon: Icons.analytics_rounded,
                                      title: 'Manajemen Rapor Terpadu',
                                      subtitle: 'Perhitungan nilai otomatis dan pembuatan dokumen PDF resmi.',
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDesktopFeatureCard(
                                      icon: Icons.shield_outlined,
                                      title: 'Keamanan Akses Terjamin',
                                      subtitle: 'Otentikasi terpisah untuk NIS Siswa/Ortu dan Email Guru.',
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDesktopFeatureCard(
                                      icon: Icons.bolt_rounded,
                                      title: 'Akses Cepat & Realtime',
                                      subtitle: 'Notifikasi langsung dan sinkronisasi data seketika.',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Footer Copyright
                                Text(
                                  '© ${DateTime.now().year} e-Rapor Mobile System. All rights reserved.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Right Form Card Panel
        Expanded(
          flex: 4,
          child: Container(
            color: AppColors.backgroundColor,
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFormCardHeader(),
                      const SizedBox(height: 24),
                      _buildFormCardContent(),
                      const SizedBox(height: 20),
                      _buildRegisterFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- MOBILE LAYOUT (SINGLE COLUMN SCROLL) ---
  Widget _buildMobileLayout(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Background Ambient Decor
        Positioned(
          top: -size.width * 0.35,
          right: -size.width * 0.25,
          child: Container(
            width: size.width * 0.85,
            height: size.width * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.secondary.withValues(alpha: 0.22),
                  AppColors.primary.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -size.width * 0.3,
          left: -size.width * 0.3,
          child: Container(
            width: size.width * 0.75,
            height: size.width * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  AppColors.accent.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFormCardHeader(),
                    const SizedBox(height: 24),
                    _buildFormCardContent(),
                    const SizedBox(height: 20),
                    _buildRegisterFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- HELPER COMPONENTS ---
  Widget _buildDesktopFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCardHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.2),
                AppColors.secondary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.school_rounded,
                size: 38,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_rounded, size: 14, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'Aplikasi e-Rapor Digital',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Selamat Datang',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Silakan masuk ke akun e-Rapor Anda',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCardContent() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ultra-modern Dual Role Quick-Guide Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent,
                  AppColors.backgroundColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded, color: AppColors.primary, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'PANDUAN MASUK AKUN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Siswa / Ortu Badge Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.face_rounded, color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Siswa / Ortu',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    'Gunakan NIS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Guru / Admin Badge Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.school_rounded, color: AppColors.secondary, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Guru / Admin',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    'Gunakan Email',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Input Fields
          _buildTextField(
            controller: _emailController,
            label: 'NIS atau Alamat Email',
            hint: 'Masukkan NIS atau Email Anda',
            icon: Icons.badge_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            label: 'Kata Sandi',
            hint: 'Masukkan kata sandi',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            isObscured: !_isPasswordVisible,
            onToggleVisibility: () {
              setState(() => _isPasswordVisible = !_isPasswordVisible);
            },
          ),

          // Forgot Password Button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              ),
              child: const Text(
                'Lupa Kata Sandi?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Login Button
          Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  AppColors.brand,
                  AppColors.brandDark,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'MASUK KE SISTEM',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Guru belum punya akun?',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: _goToRegister,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Daftar Di Sini',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Orang Tua/Siswa silakan masuk menggunakan NIS',
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isObscured = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isObscured,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            prefixIcon: Container(
              margin: const EdgeInsets.only(left: 8, right: 8, top: 6, bottom: 6),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
            filled: true,
            fillColor: AppColors.backgroundColor,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
            ),
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.normal,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountdownDialog extends StatefulWidget {
  final int initialSeconds;
  const _CountdownDialog({required this.initialSeconds});

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.initialSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining > 0) {
        if (mounted) {
          setState(() => _remaining--);
        }
      } else {
        _timer?.cancel();
        // Hapus status blokir jika waktu sudah habis
        SharedPreferences.getInstance().then((prefs) => prefs.remove('login_block_expiry'));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Mencegah user keluar menggunakan tombol back
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 12,
        backgroundColor: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(28.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.timer_off_rounded,
                    size: 52,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Akses Ditangguhkan',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Terlalu banyak percobaan login yang gagal.\nSilakan tunggu hingga waktu hitung mundur selesai.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.shade500,
                        Colors.red.shade700,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_remaining',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'DETIK',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
