import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../utils/notification_helper.dart';

class DaftarAkunPage extends StatefulWidget {
  final bool isEmbedded;
  final Function(int)? onNavigate;
  const DaftarAkunPage({super.key, this.isEmbedded = false, this.onNavigate});

  @override
  State<DaftarAkunPage> createState() => _DaftarAkunPageState();
}

class _DaftarAkunPageState extends State<DaftarAkunPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _profilesSubscription;
  StreamSubscription? _studentsSubscription;

  @override
  void initState() {
    super.initState();
    _checkIsAdmin();
  }

  Future<void> _checkIsAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final data = await supabase.from('profiles').select('role').eq('id', user.id).single();
      final role = data['role']?.toString() ?? '';
      final isAdmin = role == 'Admin' || role == 'Super Admin';
      if (!isAdmin) {
        if (mounted) {
          NotificationHelper.show(context, 'Hanya Admin yang dapat mengakses halaman ini.', isError: true);
          Navigator.pop(context);
        }
        return;
      }
      _setupRealtimeStreams();
    } catch (e) {
      debugPrint('Error checking role: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _profilesSubscription?.cancel();
    _studentsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setupRealtimeStreams() {
    // 1. Stream untuk Profiles (Admin & Guru)
    _profilesSubscription = supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen((data) {
      if (mounted) {
        setState(() {
          _profiles = data.where((u) => u['is_verified'] == true).toList();
          _combineAndFilter();
          _isLoading = false;
        });
      }
    });

    // 2. Stream untuk Students (Siswa)
    _studentsSubscription = supabase
        .from('students')
        .stream(primaryKey: ['nis'])
        .order('created_at', ascending: false)
        .listen((data) {
      if (mounted) {
        setState(() {
          _students = data.map((s) => {
            'id': s['nis'],
            'full_name': s['name'],
            'email': '${s['nis']}@siswa.id',
            'role': 'Siswa',
            'is_verified': true,
            'created_at': s['created_at'],
          }).toList();
          _combineAndFilter();
          _isLoading = false;
        });
      }
    });
  }

  void _combineAndFilter() {
    final List<Map<String, dynamic>> all = [..._profiles, ..._students];
    
    // Urutkan berdasarkan tanggal terbaru
    all.sort((a, b) {
      String dateA = a['created_at'] ?? '';
      String dateB = b['created_at'] ?? '';
      return dateB.compareTo(dateA);
    });

    _users = all;
    _filterUsers(_searchController.text);
  }

  Future<void> _fetchUsers() async {
    // Fungsi ini sekarang hanya untuk manual refresh jika stream macet
    _setupRealtimeStreams();
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          final name = user['full_name']?.toString().toLowerCase() ?? '';
          final email = user['email']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) || email.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await supabase.rpc('delete_user_by_admin', params: {'target_user_id': userId});
      
      if (mounted) {
        NotificationHelper.show(context, 'Akun berhasil dihapus sepenuhnya!');
        _fetchUsers();
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        String errorMessage = 'Gagal menghapus: ${e.message}';
        if (e.message.contains('foreign key constraint')) {
          errorMessage = 'Gagal: Akun ini masih terikat dengan data lain (Guru/Siswa).';
        }
        NotificationHelper.show(context, errorMessage, isError: true);
      }
    } catch (e) {
      try {
        await supabase.from('profiles').delete().eq('id', userId);
        if (mounted) {
          NotificationHelper.show(context, 'Profil berhasil dihapus.');
          _fetchUsers();
        }
      } catch (e2) {
        if (mounted) {
          NotificationHelper.show(context, 'Gagal menghapus. Pastikan SQL Function sudah ada.', isError: true);
        }
      }
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> userData) {
    final currentUserId = supabase.auth.currentUser?.id;
    if (userData['id'] == currentUserId) {
      NotificationHelper.show(context, 'Anda tidak dapat menghapus akun Anda sendiri', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Hapus Akun'),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus akun ${userData['full_name']}?\n\nSemua data login dan profil akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(userData['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          // Header Judul Custom (Bukan AppBar)
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
                const Text(
                  'Daftar Akun',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          _buildHeaderStats(),
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          return _buildUserCard(_filteredUsers[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStats() {
    int total = _users.length;
    int admins = _users.where((u) => u['role']?.toString().toLowerCase() == 'admin').length;
    int gurus = _users.where((u) => u['role']?.toString().toLowerCase() == 'guru').length;
    int siswas = _users.where((u) => u['role']?.toString().toLowerCase() == 'siswa').length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatItem('Total', total.toString(), Icons.group_rounded, Colors.blue),
            const SizedBox(width: 24),
            _buildStatItem('Admin', admins.toString(), Icons.admin_panel_settings_rounded, Colors.red),
            const SizedBox(width: 24),
            _buildStatItem('Guru', gurus.toString(), Icons.person_pin_rounded, Colors.orange),
            const SizedBox(width: 24),
            _buildStatItem('Siswa', siswas.toString(), Icons.school_rounded, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color.withValues(alpha: 0.9),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: _filterUsers,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Cari nama atau email...',
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Akun tidak ditemukan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> userData) {
    bool isVerified = userData['is_verified'] ?? false;
    String role = userData['role'] ?? 'User';
    String fullName = userData['full_name'] ?? 'Nama tidak diketahui';
    String email = userData['email'] ?? '-';
    String date = userData['created_at'] != null 
        ? DateTime.parse(userData['created_at']).toLocal().toString().split(' ')[0] 
        : '-';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: _getRoleColor(role).withValues(alpha: 0.1),
              child: Text(
                fullName[0].toUpperCase(),
                style: TextStyle(
                  color: _getRoleColor(role),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blue, size: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildRoleBadge(role),
                      const SizedBox(width: 8),
                      Text(
                        'Daftar: $date',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
              onPressed: () => _showDeleteConfirmation(userData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color = _getRoleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'guru':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }
}
