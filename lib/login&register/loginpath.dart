import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'dart:async';
import '../utils/notification_helper.dart';
import '../utils/push_notification_service.dart';
import '../dasbhor/dasbhor.dart';
import 'register.dart';
// OneSignal calls are now handled via PushNotificationService

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

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
    final TextEditingController emailResetController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Lupa Kata Sandi', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan alamat email Anda. Kami akan mengirimkan tautan untuk mengatur ulang kata sandi.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailResetController,
              decoration: InputDecoration(
                hintText: 'Email Anda',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailResetController.text.trim();
              if (email.isEmpty) {
                NotificationHelper.show(context, 'Email tidak boleh kosong', isError: true);
                return;
              }
              
              try {
                // Konfigurasi redirect URL sesuai dengan deep link aplikasi Anda
                await Supabase.instance.client.auth.resetPasswordForEmail(email);
                if (context.mounted) {
                  Navigator.pop(context);
                  NotificationHelper.show(context, 'Tautan reset kata sandi telah dikirim ke email Anda');
                }
              } catch (e) {
                if (context.mounted) {
                  NotificationHelper.show(context, 'Gagal mengirim email: $e', isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Kirim Tautan'),
          ),
        ],
      ),
    );
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
          final isBlocked = await Supabase.instance.client.rpc('check_auth_blocked', params: {'p_identifier': identifier}).timeout(const Duration(seconds: 3));
          if (isBlocked) {
            if (mounted) {
              _showCountdownDialog(60);
              setState(() => _isLoading = false);
            }
            return;
          }
        } catch (_) {}

        final result = await Supabase.instance.client.rpc('get_student_auth', params: {'p_nis': identifier});
        final studentData = result.isNotEmpty ? result.first : null;

        if (studentData != null && password == identifier) {
          // JALUR CEPAT: Jalankan urusan background tanpa menunggu (Parallel)
          unawaited(Supabase.instance.client.rpc('reset_login_attempts', params: {'p_identifier': identifier}));
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
          // Tunggu catatan gagal selesai agar dialog blokir muncul tepat waktu
          await Supabase.instance.client.rpc('record_login_failure', params: {'p_identifier': identifier});
          
          // Cek apakah sudah terblokir setelah kegagalan ini (untuk langsung menampilkan dialog jika sudah limit)
          try {
            final isBlocked = await Supabase.instance.client.rpc('check_auth_blocked', params: {'p_identifier': identifier}).timeout(const Duration(seconds: 3));
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

      // Jalankan cek blokir dengan timeout singkat agar tidak nunggu lama kalau internet jelek
      try {
        final isBlocked = await Supabase.instance.client.rpc('check_auth_blocked', params: {'p_identifier': emailFinal}).timeout(const Duration(seconds: 3));
        if (isBlocked) {
          if (mounted) _showCountdownDialog(60);
          setState(() => _isLoading = false);
          return;
        }
      } catch (_) {}

      final response = await Supabase.instance.client.auth.signInWithPassword(email: emailFinal, password: password);

      if (response.user != null) {
        // Reset attempt di background
        unawaited(Supabase.instance.client.rpc('reset_login_attempts', params: {'p_identifier': emailFinal}));

        if (response.user!.email == 'triandre980@gmail.com') {
          PushNotificationService.setTag('role', 'admin');
          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DasbhorPage(initialRole: 'Admin')));
          }
          return;
        }

        // Ambil profil
        final profileData = await Supabase.instance.client.from('profiles').select('is_verified, role').eq('id', response.user!.id).maybeSingle();

        if (profileData == null || profileData['is_verified'] == false) {
          await Supabase.instance.client.auth.signOut();
          if (mounted) NotificationHelper.show(context, 'Akun belum diverifikasi Admin.', isError: true);
          setState(() => _isLoading = false);
          return;
        }

        PushNotificationService.login(response.user!.id);
        PushNotificationService.setTag('role', profileData['role'].toString().toLowerCase());
        
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DasbhorPage(initialRole: profileData['role'])));
        }
      }
    } catch (error) {
      String errorMessage = error.toString();
      final String emailFinal = identifier.contains('@') ? identifier : '$identifier@alhanif.id';
      
      // CATAT KEGAGALAN LOGIN EMAIL (Tunggu prosesnya selesai agar blokir akurat)
      if (!errorMessage.contains('Terlalu banyak percobaan')) {
        try {
          await Supabase.instance.client.rpc('record_login_failure', params: {'p_identifier': emailFinal});
          
          // Cek apakah sudah terblokir setelah kegagalan ini
          final isBlocked = await Supabase.instance.client.rpc('check_auth_blocked', params: {'p_identifier': emailFinal}).timeout(const Duration(seconds: 3));
          if (isBlocked) {
            if (mounted) _showCountdownDialog(60);
            return;
          }
        } catch (_) {}
      }

      if (errorMessage.contains('Terlalu banyak percobaan')) {
        if (mounted) _showCountdownDialog(60);
      } else if (errorMessage.contains('Invalid login credentials')) {
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Gradient Decor
          Positioned(
            top: -100,
            right: -100,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: Colors.blue.shade50.withValues(alpha: 0.5),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.blue.shade50.withValues(alpha: 0.3),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo and Title Section
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: Hero(
                          tag: 'app_logo',
                          child: Icon(
                            Icons.school_rounded,
                            size: 70,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Selamat Datang',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Silakan masuk ke akun e-Rapor Anda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Input Fields
                    _buildTextField(
                      controller: _emailController,
                      label: 'NIS atau Alamat Email',
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Kata Sandi',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      isObscured: !_isPasswordVisible,
                      onToggleVisibility: () {
                        setState(() => _isPasswordVisible = !_isPasswordVisible);
                      },
                    ),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                        ),
                        child: const Text(
                          'Lupa Kata Sandi?',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Login Button
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'MASUK KE SISTEM',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Register Link
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Guru belum punya akun?',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            TextButton(
                              onPressed: _goToRegister,
                              child: Text(
                                'Daftar Di Sini',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Orang Tua/Siswa silakan masuk menggunakan NIS',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isObscured,
          keyboardType: keyboardType,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.blue.shade800, size: 22),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
            filled: true,
            fillColor: Colors.blue.shade50.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.blue.shade200, width: 1.5),
            ),
            hintText: 'Masukkan ${label.toLowerCase()}',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal, fontSize: 14),
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
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_off_outlined, size: 60, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'Akses Ditangguhkan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text(
              'Terlalu banyak percobaan login. Silakan tunggu sebentar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$_remaining',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.red.shade800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'DETIK',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
