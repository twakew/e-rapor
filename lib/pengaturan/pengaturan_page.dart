import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../utils/notification_helper.dart';
import '../utils/push_notification_service.dart';
import '../dasbhor/profil_page.dart';
import '../login&register/loginpath.dart';
import 'verifikasi_akun_page.dart';
import 'daftar_akun_page.dart';
import 'ganti_password_page.dart';

class PengaturanPage extends StatefulWidget {
  final bool isEmbedded;
  final Function(int)? onNavigate;
  const PengaturanPage({super.key, this.isEmbedded = false, this.onNavigate});

  @override
  State<PengaturanPage> createState() => _PengaturanPageState();
}

class _PengaturanPageState extends State<PengaturanPage> {
  final supabase = Supabase.instance.client;
  String _userRole = 'User';

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (user.email == 'triandre980@gmail.com') {
      if (mounted) setState(() => _userRole = 'Admin');
      return;
    }
    try {
      final data = await supabase.from('profiles').select('role').eq('id', user.id).single();
      if (mounted) setState(() => _userRole = data['role'] ?? 'User');
    } catch (e) {
      debugPrint('Error fetching role: $e');
    }
  }

  Future<void> _signOut() async {
    PushNotificationService.logout();
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor, // Background abu-abu muda khas dashboard
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 12 : 8),
        children: [
          // Header Judul Custom (Bukan AppBar)
          Padding(
            padding: EdgeInsets.fromLTRB(4, isMobile ? 4 : 16, 4, isMobile ? 16 : 24),
            child: Row(
              children: [
                if (!widget.isEmbedded) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  'Pengaturan',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          
          _buildSectionTitle('Akun'),
          const SizedBox(height: 12),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.person_outline_rounded,
              title: 'Profil Saya',
              subtitle: 'Kelola informasi profil Anda',
              onTap: () {
                if (widget.isEmbedded && widget.onNavigate != null) {
                  widget.onNavigate!(9); // Index untuk Profil Saya
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfilPage()),
                  );
                }
              },
            ),
            if (_userRole == 'Admin') ...[
              _buildDivider(),
              _buildSettingsTile(
                icon: Icons.verified_user_outlined,
                title: 'Verifikasi Pendaftaran',
                subtitle: 'Setujui akun pendaftar baru',
                onTap: () {
                  if (widget.isEmbedded && widget.onNavigate != null) {
                    widget.onNavigate!(22);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const VerifikasiAkunPage()),
                    );
                  }
                },
              ),
              _buildDivider(),
              _buildSettingsTile(
                icon: Icons.people_outline_rounded,
                title: 'Daftar Akun Terdaftar',
                subtitle: 'Lihat semua pengguna aplikasi',
                onTap: () {
                  if (widget.isEmbedded && widget.onNavigate != null) {
                    widget.onNavigate!(23);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DaftarAkunPage()),
                    );
                  }
                },
              ),
            ],
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.lock_outline_rounded,
              title: 'Keamanan',
              subtitle: 'Ganti kata sandi',
              onTap: () {
                if (_userRole == 'User') {
                  NotificationHelper.show(context, 'Siswa/Orang Tua masuk menggunakan NIS. Silakan hubungi admin jika ingin mengubah data.', isError: true);
                } else {
                  if (widget.isEmbedded && widget.onNavigate != null) {
                    widget.onNavigate!(24); // Index baru untuk Keamanan
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const GantiPasswordPage()),
                    );
                  }
                }
              },
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionTitle('Aplikasi'),
          const SizedBox(height: 12),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifikasi',
              subtitle: 'Atur pemberitahuan aplikasi',
              onTap: () {},
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.language_rounded,
              title: 'Bahasa',
              subtitle: 'Bahasa Indonesia',
              onTap: () {},
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'Tentang Aplikasi',
              subtitle: 'Versi 1.0.0',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Lapor Sekolah E-Rapor',
                  applicationVersion: '1.0.0',
                  applicationIcon: Image.asset('assets/logo.png', width: 50, height: 50, errorBuilder: (c, e, s) => const Icon(Icons.school, size: 50)),
                  children: [
                    const Text('Aplikasi pengelolaan administrasi sekolah TK-IT AL-HANIF.'),
                  ],
                );
              },
            ),
          ]),
          const SizedBox(height: 32),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.logout_rounded,
              title: 'Keluar',
              titleColor: Colors.redAccent,
              iconColor: Colors.redAccent,
              showTrailing: false,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Keluar'),
                    content: const Text('Apakah Anda yakin ingin keluar dari akun?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _signOut();
                        },
                        child: const Text('Keluar', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }




  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
    bool showTrailing = true,
  }) {
    final Color effectiveColor = iconColor ?? AppColors.primary;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: effectiveColor, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: titleColor ?? const Color(0xFF0F172A),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: const Color(0xFF64748B)),
            )
          : null,
      trailing: showTrailing
          ? Icon(Icons.arrow_forward_ios_rounded, size: 14, color: const Color(0xFF94A3B8))
          : null,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 68,
      endIndent: 16,
      color: Colors.grey.shade100,
    );
  }

}
