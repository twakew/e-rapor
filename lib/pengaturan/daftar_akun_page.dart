import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laporsekolaherapor/services/api_service.dart';
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
  final apiService = ApiService();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkIsAdmin();
  }

  Future<void> _checkIsAdmin() async {
    if (!apiService.isLoggedIn) {
      setState(() => _isLoading = false);
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
      _fetchUsers();
    } catch (e) {
      debugPrint('Error checking role: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final profilesData = await apiService.getTable('profiles');
      final studentsData = await apiService.getTable('students');

      if (mounted) {
        setState(() {
          _profiles = profilesData.where((u) => u['is_verified'] == true).toList().cast<Map<String, dynamic>>();
          
          _students = studentsData.map((s) => {
            'id': s['nis'],
            'full_name': s['name'],
            'email': '${s['nis']}@siswa.id',
            'role': 'Siswa',
            'is_verified': true,
            'created_at': s['created_at'],
          }).toList().cast<Map<String, dynamic>>();

          _combineAndFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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
      await apiService.callRpc('delete_user_by_admin', params: {'target_user_id': userId});
      
      if (mounted) {
        NotificationHelper.show(context, 'Akun berhasil dihapus sepenuhnya!');
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Gagal menghapus: $e';
        if (e.toString().contains('foreign key constraint')) {
          errorMessage = 'Gagal: Akun ini masih terikat dengan data lain (Guru/Siswa).';
        }
        NotificationHelper.show(context, errorMessage, isError: true);
      }
      // Fallback try delete from profiles table directly
      try {
        await apiService.delete('profiles', userId);
        if (mounted) {
          NotificationHelper.show(context, 'Profil berhasil dihapus.');
          _fetchUsers();
        }
      } catch (e2) {
        if (mounted) {
          NotificationHelper.show(context, 'Gagal menghapus profil.', isError: true);
        }
      }
    }
  }

  Future<void> _showDeleteConfirmation(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('jwt_token') ?? '';
    String? currentUserId;
    if (token.isNotEmpty) {
      currentUserId = JwtDecoder.decode(token)['id'];
    }

    if (userData['id'] == currentUserId) {
      if (mounted) NotificationHelper.show(context, 'Anda tidak dapat menghapus akun Anda sendiri', isError: true);
      return;
    }

    if (!mounted) return;
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
            child: Text('Batal', style: TextStyle(color: AppColors.textMuted)),
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
            child: Text('Ya, Hapus'),
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
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
                    onPressed: () {
                      if (widget.onNavigate != null) widget.onNavigate!(8);
                    },
                  ),
                const SizedBox(width: 8),
                Text(
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
                    : RefreshIndicator(
                        onRefresh: _fetchUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            return _buildUserCard(_filteredUsers[index]);
                          },
                        ),
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
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.borderColor),
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
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
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
          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
          filled: true,
          fillColor: AppColors.backgroundColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primary, width: 1),
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
          Icon(Icons.person_search_rounded, size: 80, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'Akun tidak ditemukan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMuted),
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
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppColors.cardShadow,
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textDark,
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
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildRoleBadge(role),
                      const SizedBox(width: 8),
                      Text(
                        'Daftar: $date',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
