import 'package:flutter/material.dart';
import 'package:laporsekolaherapor/services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../login&register/loginpath.dart';
import '../utils/notification_helper.dart';

class GantiPasswordPage extends StatefulWidget {
  final bool isEmbedded;
  final Function(int)? onNavigate;
  const GantiPasswordPage({super.key, this.isEmbedded = false, this.onNavigate});

  @override
  State<GantiPasswordPage> createState() => _GantiPasswordPageState();
}

class _GantiPasswordPageState extends State<GantiPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (!ApiService().isLoggedIn) {
      NotificationHelper.show(context, 'Sesi tidak valid. Silakan masuk kembali.', isError: true);
      return;
    }

    final password = _passwordController.text.trim();
    setState(() => _isLoading = true);

    try {
      await ApiService().updatePassword(password);
      await ApiService().logout();

      if (mounted) {
        NotificationHelper.show(context, 'Kata sandi berhasil diperbarui. Silakan masuk kembali.');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        NotificationHelper.show(context, 'Gagal memperbarui kata sandi. Cek koneksi Anda.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Judul Custom (Bukan AppBar)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 24),
                child: Row(
                  children: [
                    if (widget.isEmbedded)
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
                        onPressed: () {
                          if (widget.onNavigate != null) widget.onNavigate!(8);
                        },
                      ),
                    const SizedBox(width: 8),
                    Text(
                      'Ganti Kata Sandi',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Masukkan kata sandi baru Anda di bawah ini.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              _buildPasswordField(
                controller: _passwordController,
                label: 'Kata Sandi Baru',
                hint: 'Minimal 6 karakter',
              ),
              const SizedBox(height: 20),
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Konfirmasi Kata Sandi Baru',
                hint: 'Ulangi kata sandi baru',
                isConfirm: true,
              ),
              SizedBox(height: 40),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isConfirm = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: _obscureText,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.backgroundColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade200)),
            suffixIcon: IconButton(
              icon: Icon(_obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Bagian ini harus diisi';
            if (value.length < 6) return 'Kata sandi minimal 6 karakter';
            if (isConfirm && value != _passwordController.text) return 'Kata sandi tidak cocok';
            return null;
          },
        ),
      ],
    );
  }
}
