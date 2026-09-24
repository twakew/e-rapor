import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laporsekolaherapor/services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../utils/notification_helper.dart';
import '../utils/push_notification_service.dart';

class VerifikasiAkunPage extends StatefulWidget {
  final bool isEmbedded;
  final Function(int)? onNavigate;
  const VerifikasiAkunPage({super.key, this.isEmbedded = false, this.onNavigate});

  @override
  State<VerifikasiAkunPage> createState() => _VerifikasiAkunPageState();
}

class _VerifikasiAkunPageState extends State<VerifikasiAkunPage> {
  final apiService = ApiService();
  List<Map<String, dynamic>> _pendingUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkIsAdmin();
  }

  Future<void> _checkIsAdmin() async {
    if (!apiService.isLoggedIn) {
      _finishLoad();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('jwt_token') ?? '';
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      String userId = decodedToken['id'];

      final data = await apiService.getRow('profiles', userId);
      final role = data['role']?.toString() ?? '';
      final isAdmin = role == 'Admin' || role == 'Super Admin';
      if (!isAdmin) {
        if (mounted) {
          NotificationHelper.show(context, 'Hanya Admin yang dapat mengakses halaman ini.', isError: true);
          Navigator.pop(context);
        }
        return;
      }
      _fetchPendingUsers();
    } catch (e) {
      debugPrint('Error checking role: $e');
      _finishLoad();
    }
  }

  void _finishLoad() {
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchPendingUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await apiService.getTable('profiles');
      final pendingData = data.where((u) => u['is_verified'] == false).toList();
      pendingData.sort((a, b) {
        String dateA = a['created_at'] ?? '';
        String dateB = b['created_at'] ?? '';
        return dateB.compareTo(dateA);
      });
      
      setState(() {
        _pendingUsers = List<Map<String, dynamic>>.from(pendingData);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(context, 'Gagal mengambil data: $e', isError: true);
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyUser(Map<String, dynamic> userData, String role) async {
    final userId = userData['id'];
    final fullName = userData['full_name'] ?? 'Guru';

    debugPrint('[VERIFY] Starting verification...');
    debugPrint('[VERIFY] userId: $userId');
    debugPrint('[VERIFY] role: $role');
    debugPrint('[VERIFY] userData: $userData');

    try {
      // Verifikasi via RPC admin (bypass RLS butuh guard is_admin di DB).
      // Update langsung tak jalan: policy profiles_update_own hanya kolom
      // non-sensitif, role/is_verified dikunci.
      final result = await apiService.callRpc('verify_user_by_admin',
          params: {'p_user_id': userId, 'p_role': role});

      debugPrint('[VERIFY] Result: $result');

      // --- KIRIM NOTIFIKASI KE USER BAHWA SUDAH AKTIF ---
      try {
        await PushNotificationService.sendNotification(
          userId: userId,
          title: 'AKUN AKTIF',
          message: 'Telah diverifikasi sebagai $role $fullName, silakan login.',
          data: {'include_staff': false},
        );
      } catch (e) {
        debugPrint('Gagal kirim notif verifikasi: $e');
      }

      if (mounted) {
        NotificationHelper.show(context, 'Akun berhasil diverifikasi sebagai $role!');
        _fetchPendingUsers();
      }
    } catch (e) {
      debugPrint('[VERIFY] Error: $e');
      if (mounted) {
        NotificationHelper.show(context, 'Gagal verifikasi: $e', isError: true);
      }
    }
  }

  void _showVerifyDialog(Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verifikasi Akun'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nama: ${userData['full_name']}'),
            Text('Email: ${userData['email']}'),
            const SizedBox(height: 20),
            const Text('Tentukan akses untuk akun ini:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildRoleButton(userData, 'Guru', Colors.blue.shade800, 'GURU'),
            const SizedBox(height: 8),
            _buildRoleButton(userData, 'Admin', Colors.indigo.shade800, 'ADMIN'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton(Map<String, dynamic> userData, String role, Color color, String label) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          _verifyUser(userData, role);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text('Konfirmasi sebagai $label', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          // Header Judul Custom (Bukan AppBar) biar sidebar tetep ada
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 24),
            child: Row(
              children: [
                if (widget.isEmbedded)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
                    onPressed: () {
                      if (widget.onNavigate != null) widget.onNavigate!(8);
                    },
                  ),
                const SizedBox(width: 8),
                Text(
                  'Verifikasi Pendaftaran',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                : _pendingUsers.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _pendingUsers.length,
                        itemBuilder: (context, index) {
                          final user = _pendingUsers[index];
                          return _buildUserCard(user);
                        },
                      ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Amplop dengan Checkmark (mirip gambar)
          Opacity(
            opacity: 0.2,
            child: Icon(Icons.mail_outline_rounded, size: 100, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tidak ada antrean verifikasi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Semua akun pendaftar telah diverifikasi.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 80), // Offset biar gak terlalu ke tengah banget
        ],
      ),
    );
  }


  Widget _buildUserCard(Map<String, dynamic> userData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: Text(
              (userData['full_name'] ?? 'U')[0].toUpperCase(),
              style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            userData['full_name'] ?? 'Nama tidak diketahui',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(userData['email'] ?? '-'),
              const SizedBox(height: 4),
              Text(
                'Mendaftar: ${userData['created_at'] != null ? DateTime.parse(userData['created_at']).toLocal().toString().split(' ')[0] : '-'}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                onPressed: () => _showRejectDialog(userData),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: () => _showVerifyDialog(userData),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Verifikasi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak & Hapus Pendaftaran?'),
        content: Text('Apakah Anda yakin ingin menolak pendaftaran ${userData['full_name']}? Akun ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectUser(userData['id']);
            },
            child: const Text('Ya, Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectUser(String userId) async {
    try {
      // Hapus menggunakan RPC agar auth.users juga terhapus
      await apiService.callRpc('delete_user_by_admin', params: {'target_user_id': userId});
      
      if (mounted) {
        NotificationHelper.show(context, 'Pendaftaran berhasil ditolak dan dihapus.');
        _fetchPendingUsers();
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(context, 'Gagal menghapus pendaftaran: $e', isError: true);
      }
    }
  }
}
