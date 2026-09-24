import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laporsekolaherapor/services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'package:intl/intl.dart';

class ProfilPage extends StatefulWidget {
  final String? userRole;
  final String? studentNis;
  final String? studentName;
  final String? studentClass;
  final bool isEmbedded;
  final int returnIndex;
  final Function(int)? onNavigate;

  const ProfilPage({
    super.key,
    this.userRole,
    this.studentNis,
    this.studentName,
    this.studentClass,
    this.isEmbedded = false,
    this.returnIndex = 0,
    this.onNavigate,
  });

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final apiService = ApiService();
  bool _isLoading = true;
  dynamic _userData;
  Map<String, dynamic>? _schoolData;
  String? _role;

  // --- Color Palette ---
  final Color primaryTeal = AppColors.primary;
  final Color secondaryTeal = AppColors.secondary;
  final Color accentGreen = AppColors.accent;
  final Color backgroundColor = AppColors.backgroundColor;
  final Color textDark = AppColors.textDark;
  final Color textSecondary = AppColors.textSecondary;
  final Color textMuted = AppColors.textMuted;

  String get _initials {
    final name = _userData?['name']?.toString() ?? '';
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _role = widget.userRole;
    _fetchProfileData();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  DATA FETCHING
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('jwt_token') ?? '';
    Map<String, dynamic>? decodedToken;
    if (token.isNotEmpty) {
      decodedToken = JwtDecoder.decode(token);
    }
    
    // Jalankan fetch profile dan school data secara paralel
    await Future.wait([
      _getProfileInfo(decodedToken),
      _getSchoolInfo(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _getProfileInfo(Map<String, dynamic>? userToken) async {
    try {
      if (_role == null && userToken != null) {
        final profileRes = await apiService.getRow('profiles', userToken['id']);
        _role = profileRes['role'] ?? 'User';
      }

      if (userToken != null && (_role == 'Admin' || _role == 'Guru')) {
        final data = await apiService.getRow('profiles', userToken['id']);
        if (data.isNotEmpty) {
          _userData = {
            ...data,
            'name': data['full_name'] ?? (_role == 'Admin' ? 'Admin' : 'Guru'),
            'email': data['email'] ?? userToken['email'],
            'phone': data['phone'] ?? '-',
            'address': data['address'] ?? '-',
            'username': data['username'] ?? data['email']?.split('@')[0] ?? '-',
            'status': data['is_verified'] == true ? 'Aktif' : 'Menunggu Verifikasi',
            'joined': data['created_at'] != null 
                ? DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.parse(data['created_at']))
                : '-',
            'last_login': '-'
          };
        }
      } else {
        String? nis = widget.studentNis;
        if (nis != null) {
          // Siswa tanpa sesi: direct select students ditolak RLS (staff-only).
          final rows = await apiService.callRpc('get_my_profile', params: {'p_nis': nis});
          final data = (rows is List && rows.isNotEmpty) ? rows.first : (rows is Map ? rows : null);
          if (data != null) {
            _userData = {
              ...data,
              'name': data['name'] ?? widget.studentName ?? 'Siswa',
              'email': '-',
              'phone': '-',
              'address': '-',
              'username': data['nis'] ?? '-',
              'status': 'Aktif',
              'joined': data['created_at'] != null 
                  ? DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.parse(data['created_at']))
                  : '-',
              'last_login': '-'
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Error get profile info: $e');
    }
  }

  Future<void> _getSchoolInfo() async {
    try {
      final List<dynamic> dataList = await apiService.getTable('school_data');
      final data = dataList.isNotEmpty ? dataList.first : null;
      if (mounted && data != null) {
        setState(() {
          _schoolData = data;
        });
      }
    } catch (e) {
      debugPrint('Error get school info: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 12 : 8),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4, isMobile ? 4 : 16, 4, isMobile ? 16 : 24),
              child: Row(
                children: [
                  if (widget.isEmbedded)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
                      onPressed: () {
                        if (widget.onNavigate != null) widget.onNavigate!(widget.returnIndex);
                      },
                    ),
                  const SizedBox(width: 8),
                  Text(
                    'Profil Saya',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),

            _buildCoverHeader(),
            const SizedBox(height: 20),
            _buildStatsRow(),
            const SizedBox(height: 24),
            _buildInfoCard(),
            _buildSchoolInfoCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [AppColors.brand, AppColors.brandDark, AppColors.brand.withValues(alpha: 0.8)],
                  ),
                ),
                child: Stack(
                  children: [
                    ..._buildOrbs(),
                  ],
                ),
              ),
              Positioned(
                bottom: -45,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.brand, AppColors.brandDark],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 55),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                Text(
                  (_userData?['name'] ?? '-').toString().toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF22C55E)),
                      const SizedBox(width: 6),
                      Text(
                        _role ?? 'User',
                        style: const TextStyle(
                          color: Color(0xFF15803D),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _chip(Icons.mail_outline_rounded, _userData?['email'] ?? '-'),
                    _chip(Icons.phone_iphone_rounded, _userData?['phone'] ?? '-'),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOrbs() {
    return [
      Positioned(
        right: -40,
        top: -40,
        child: Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      Positioned(
        left: -24,
        bottom: -24,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
    ];
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _miniStat(Icons.person_rounded, 'Bergabung', _userData?['joined'] ?? '-', AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: _miniStat(Icons.access_time_rounded, 'Terakhir Masuk', _userData?['last_login'] ?? '-', AppColors.secondary)),
        const SizedBox(width: 12),
        Expanded(child: _miniStat(Icons.shield_outlined, 'Status', _userData?['status'] ?? 'Aktif', const Color(0xFF22C55E))),
      ],
    );
  }

  Widget _miniStat(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informasi Akun', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
          const SizedBox(height: 20),
          _infoTile(Icons.person_outline_rounded, 'Nama Lengkap', _userData?['name'] ?? '-'),
          const _DividerLight(),
          _infoTile(Icons.alternate_email_rounded, 'Username', _userData?['username'] ?? '-'),
          const _DividerLight(),
          _infoTile(Icons.email_outlined, 'Email', _userData?['email'] ?? '-'),
          const _DividerLight(),
          _infoTile(Icons.phone_outlined, 'No. Telepon', _userData?['phone'] ?? '-'),
          const _DividerLight(),
          _infoTile(Icons.badge_outlined, 'Peran / Role', _role ?? '-', isBadge: true),
          const _DividerLight(),
          _infoTile(Icons.location_on_outlined, 'Alamat', _userData?['address'] ?? '-', isLast: true),
        ],
      ),
    );
  }

  Widget _buildSchoolInfoCard() {
    if (_schoolData == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informasi Sekolah', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
          const SizedBox(height: 20),
          _infoTile(Icons.school_outlined, 'Nama Sekolah', _schoolData!['name'] ?? '-'),
          const _DividerLight(),
          _infoTile(Icons.tag_rounded, 'NPSN', _schoolData!['npsn'] ?? '-'),
          const _DividerLight(),
          _infoTile(Icons.verified_outlined, 'Akreditasi', _schoolData!['accreditation'] ?? '-', isBadge: true),
          const _DividerLight(),
          _infoTile(Icons.person_pin_outlined, 'Kepala Sekolah', _schoolData!['headmaster_name'] ?? '-'),
          const _DividerLight(),
          _infoTile(Icons.location_on_outlined, 'Alamat Sekolah', _schoolData!['address'] ?? '-', isLast: true),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, {bool isBadge = false, bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(top: 14, bottom: isLast ? 0 : 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: primaryTeal.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: primaryTeal),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8))),
                const SizedBox(height: 3),
                isBadge
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: accentGreen, borderRadius: BorderRadius.circular(8)),
                        child: Text(value, style: const TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    : Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DividerLight extends StatelessWidget {
  const _DividerLight();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFFF1F5F9));
  }
}
