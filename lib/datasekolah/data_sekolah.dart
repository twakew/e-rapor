import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'edit_sekolah.dart';
import '../utils/notification_helper.dart';

class DataSekolahPage extends StatefulWidget {
  final bool isEmbedded;
  final String? userRole;
  final Function(int, {Map<String, dynamic>? schoolData})? onNavigate;
  const DataSekolahPage({super.key, this.isEmbedded = false, this.userRole, this.onNavigate});

  @override
  State<DataSekolahPage> createState() => _DataSekolahPageState();
}

class _DataSekolahPageState extends State<DataSekolahPage> {
  final apiService = ApiService();
  Timer? _refreshTimer;
  Map<String, dynamic>? _schoolData;
  bool _isLoading = true;
  String _userRole = 'User';

  // --- Color Palette ---
  final Color primaryTeal = AppColors.primary;
  final Color surfaceColor = Colors.white;
  final Color scaffoldBg = AppColors.backgroundColor;
  final Color textHighlight = AppColors.textDark;
  final Color textDim = AppColors.textSecondary;
  final Color accentBorder = const Color(0xFFE2E8F0);

  bool get _isMobile => MediaQuery.of(context).size.width < 600;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _fetchData(); // Gabungan Initial & Setup Realtime
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserRole() async {
    if (widget.userRole != null) {
      if (mounted) setState(() => _userRole = widget.userRole!);
      return;
    }
    if (mounted) setState(() => _userRole = 'Admin');
  }

  Future<void> _fetchData() async {
    if (mounted) setState(() => _isLoading = true);
    
    try {
      final data = await apiService.getFirstRow('school_data');
      
      if (mounted) {
        setState(() {
          _schoolData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch School Data Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    // Setup polling instead of realtime
    _setupRealtime();
  }

  void _setupRealtime() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchData());
  }

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url)) {
        if (mounted) NotificationHelper.show(context, 'Tidak dapat membuka tautan', isError: true);
      }
    } catch (e) {
      if (mounted) NotificationHelper.show(context, 'Tautan tidak valid', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canEdit = (_userRole == 'Admin' || _userRole == 'Super Admin');

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: primaryTeal))
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: primaryTeal,
              child: _buildElegantDetail(),
            ),
      floatingActionButton: (canEdit && _schoolData != null)
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (widget.isEmbedded && widget.onNavigate != null) {
                  widget.onNavigate!(26, schoolData: _schoolData);
                } else {
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EditSekolahPage(schoolData: _schoolData!)),
                  );
                  if (res == true) _fetchData();
                }
              },
              backgroundColor: primaryTeal,
              elevation: 4,
              icon: const Icon(Icons.edit_document, color: Colors.white),
              label: const Text('Edit Profil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildElegantDetail() {
    if (_schoolData == null) return _buildEmptyPlaceholder();

    return ListView( // Gunakan ListView supaya RefreshIndicator bekerja
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: _isMobile ? 12 : 8),
      children: [
        _buildPageHeader('Profil Sekolah'),
        
        // Hero School Profile Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: textHighlight.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: primaryTeal.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.school_rounded, color: primaryTeal, size: 36),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _schoolData!['name']?.toString().toUpperCase() ?? '-',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: textHighlight,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: scaffoldBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'NPSN: ${_schoolData!['npsn'] ?? '-'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textDim,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        _buildSectionLabel('ADMINISTRASI & AKADEMIK'),
        _buildModernCard([
          _buildModernRow(Icons.verified_outlined, 'Akreditasi Institusi', _schoolData!['accreditation'], isBadge: true),
          _buildModernRow(Icons.auto_stories_outlined, 'Kurikulum Utama', _schoolData!['curriculum'], isLast: true),
        ]),
        
        const SizedBox(height: 24),
        _buildSectionLabel('KEPEMIMPINAN'),
        _buildModernCard([
          _buildModernRow(Icons.person_pin_outlined, 'Kepala Sekolah', _schoolData!['headmaster_name']),
          _buildModernRow(Icons.badge_outlined, 'NIP / NIY', _schoolData!['headmaster_nip'], isLast: true),
        ]),
        
        const SizedBox(height: 24),
        _buildSectionLabel('KONTAK RESMI'),
        _buildModernCard([
          _buildModernRow(Icons.alternate_email_rounded, 'Email Sekolah', _schoolData!['email'], onTap: () => _launchUrl('mailto:${_schoolData!['email']}')),
          _buildModernRow(Icons.phone_iphone_rounded, 'Nomor Telepon', _schoolData!['phone'], onTap: () => _launchUrl('tel:${_schoolData!['phone']}')),
          _buildModernRow(Icons.public_rounded, 'Situs Web', _schoolData!['website'], isLast: true, onTap: () => _launchUrl(_schoolData!['website'])),
        ]),
        
        const SizedBox(height: 24),
        _buildSectionLabel('LOKASI OPERASIONAL'),
        _buildModernCard([
          _buildModernRow(Icons.location_on_outlined, 'Alamat Lengkap', _schoolData!['address'], isLast: true),
        ]),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildPageHeader(String title) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return Padding(
      padding: EdgeInsets.fromLTRB(4, isMobile ? 4 : 16, 4, isMobile ? 16 : 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 20 : 26,
              fontWeight: FontWeight.bold,
              color: primaryTeal,
            ),
          ),
          IconButton(
            onPressed: _fetchData,
            icon: Icon(Icons.refresh_rounded, color: primaryTeal, size: 20),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: textDim,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildModernCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentBorder.withValues(alpha: 0.5)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildModernRow(IconData icon, String label, String? value, {bool isBadge = false, bool isLast = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: accentBorder.withValues(alpha: 0.3))),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryTeal.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: primaryTeal),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: textDim, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  if (isBadge)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        value ?? '-',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.successGreen),
                      ),
                    )
                  else
                    Text(
                      value ?? '-',
                      style: TextStyle(
                        fontSize: 14,
                        color: textHighlight,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.open_in_new_rounded, size: 16, color: primaryTeal.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 80, color: textDim.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('Data sekolah belum diatur', style: TextStyle(color: textDim, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Muat Ulang'),
              style: ElevatedButton.styleFrom(backgroundColor: primaryTeal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            if (_userRole == 'Admin' || _userRole == 'Super Admin') ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  if (widget.isEmbedded && widget.onNavigate != null) {
                    widget.onNavigate!(26, schoolData: {});
                  } else {
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditSekolahPage(schoolData: {})),
                    );
                    if (res == true) _fetchData();
                  }
                },
                child: const Text('Atur Profil Sekarang'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
