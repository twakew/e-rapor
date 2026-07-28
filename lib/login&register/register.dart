import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../utils/notification_helper.dart';
import '../utils/push_notification_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _register() async {
    if (_emailController.text.isEmpty || 
        _passwordController.text.isEmpty || 
        _nameController.text.isEmpty) {
      NotificationHelper.show(context, 'Semua field harus diisi!', isError: true);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      NotificationHelper.show(context, 'Kata sandi tidak cocok!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {'full_name': _nameController.text.trim()},
      );

      if (response.user != null) {
        final userId = response.user!.id;
        final fullName = _nameController.text.trim();

        // 1. Simpan ke tabel profiles dengan status is_verified = false
        await Supabase.instance.client.from('profiles').insert({
          'id': userId,
          'full_name': fullName,
          'email': _emailController.text.trim(),
          'role': 'Guru', // Default awal
          'is_verified': false,
        });

        // 2. DAFTARKAN KE ONESIGNAL (Wajib agar bisa dapet notif personal)
        await PushNotificationService.requestPermission();
        PushNotificationService.login(userId);
        
        // Beri jeda 1 detik agar proses login OneSignal selesai
        await Future.delayed(const Duration(seconds: 1));

        // 3. KIRIM NOTIFIKASI (Hanya ke Admin)
        try {
          // A. Notif ke Admin (Wajib di-await agar JWT masih valid)
          await PushNotificationService.sendNotification(
            userId: null, 
            title: 'PENDAFTARAN BARU 👤',
            message: 'Guru baru $fullName telah mendaftar, silakan verifikasi.',
            data: {
              'only_admin': true,
              'include_staff': false,
              'screen': 'verifikasi',
            },
          );
        } catch (e) {
          debugPrint('Gagal kirim notif registrasi: $e');
        }

        // 4. PAKSA SIGN OUT (Sangat Penting!)
        // Supabase otomatis login setelah signUp, kita harus keluarkan 
        // supaya dia tidak bisa masuk dashboard sebelum diverifikasi.
        await Supabase.instance.client.auth.signOut();
      }

      if (mounted) {
        NotificationHelper.show(context, 'Registrasi Berhasil! Akun Anda sedang menunggu verifikasi admin.');
        Navigator.pop(context);
      }
    } on AuthException catch (error) {
      if (mounted) {
        NotificationHelper.show(context, error.message, isError: true);
      }
    } catch (error) {
      if (mounted) {
        NotificationHelper.show(context, 'Terjadi kesalahan tidak terduga', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Decor
          Positioned(
            top: -50,
            left: -50,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: Colors.blue.shade50.withValues(alpha: 0.5),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: Hero(
                        tag: 'app_logo',
                        child: Icon(
                          Icons.school_rounded,
                          size: 50,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Buat Akun Baru',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bergabunglah dengan sistem e-Rapor\nuntuk kemudahan administrasi sekolah',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Fields
                  _buildTextField(
                    controller: _nameController,
                    label: 'Nama Lengkap',
                    icon: Icons.person_outline_rounded,
                    hint: 'Masukkan nama lengkap Anda',
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Alamat Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    hint: 'Contoh: nama@sekolah.id',
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Kata Sandi',
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                    isObscured: !_isPasswordVisible,
                    hint: 'Minimal 6 karakter',
                    onToggleVisibility: () {
                      setState(() => _isPasswordVisible = !_isPasswordVisible);
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _confirmPasswordController,
                    label: 'Konfirmasi Kata Sandi',
                    icon: Icons.lock_reset_rounded,
                    isPassword: true,
                    isObscured: !_isConfirmPasswordVisible,
                    hint: 'Ulangi kata sandi Anda',
                    onToggleVisibility: () {
                      setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                    },
                  ),
                  const SizedBox(height: 40),

                  // Register Button
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
                      onPressed: _isLoading ? null : _register,
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
                              'DAFTAR SEKARANG',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sudah memiliki akun?',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Masuk di sini',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
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
    required String hint,
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
            fillColor: Colors.blue.shade50.withValues(alpha: 0.2),
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
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400, 
              fontWeight: FontWeight.normal, 
              fontSize: 14
            ),
          ),
        ),
      ],
    );
  }
}
