import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../utils/notification_helper.dart';
import 'tambah_guru.dart';

class DetailGuruPage extends StatefulWidget {
  final dynamic teacher;
  final String? userRole;
  final bool isEmbedded;
  final Function(int, {Map<String, dynamic>? teacher})? onNavigate;

  const DetailGuruPage({
    super.key, 
    required this.teacher, 
    this.userRole, 
    this.isEmbedded = false, 
    this.onNavigate
  });

  @override
  State<DetailGuruPage> createState() => _DetailGuruPageState();
}

class _DetailGuruPageState extends State<DetailGuruPage> with SingleTickerProviderStateMixin {
  late dynamic _teacher;
  late TabController _tabController;

  // --- Color Palette ---
  final Color primaryTeal = AppColors.primary; 
  final Color backgroundColor = AppColors.backgroundColor;
  final Color textDark = AppColors.textDark;
  final Color textSecondary = AppColors.textSecondary;
  final Color textMuted = AppColors.textMuted;
  final Color borderColor = AppColors.borderColor;

  @override
  void initState() {
    super.initState();
    _teacher = widget.teacher;
    bool isAdmin = (widget.userRole == 'Admin' || widget.userRole == 'Super Admin');
    bool isGuru = (widget.userRole == 'Guru');
    // Admin & Guru: 5 tabs
    _tabController = TabController(length: (isAdmin || isGuru) ? 5 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatFullName() {
    String name = _teacher['name'] ?? '-';
    String front = _teacher['title_front'] ?? '';
    String back = _teacher['title_back'] ?? '';

    String full = name;
    if (front.isNotEmpty) full = "$front $full";
    if (back.isNotEmpty) full = "$full, $back";
    return full;
  }

  Future<void> _launchWhatsApp(String phone) async {
    if (phone.isEmpty) {
      if (mounted) NotificationHelper.show(context, 'Nomor HP tidak ditemukan', isError: true);
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    String formattedPhone = cleanPhone;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '62${formattedPhone.substring(1)}';
    }
    final url = Uri.parse("https://wa.me/$formattedPhone");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) NotificationHelper.show(context, 'Gagal membuka WhatsApp', isError: true);
    }
  }

  Future<void> _launchEmail(String email) async {
    if (email.isEmpty || email == '-') {
      if (mounted) NotificationHelper.show(context, 'Email tidak ditemukan', isError: true);
      return;
    }
    final url = Uri.parse("mailto:$email");
    if (!await launchUrl(url)) {
      if (mounted) NotificationHelper.show(context, 'Gagal membuka aplikasi Email', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _buildBody();

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: content,
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 24),
          _buildProfileHeaderCard(),
          const SizedBox(height: 24),
          _buildTabsSection(),
          const SizedBox(height: 24),
          _buildActiveTabContent(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detail Guru', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark)),
          ],
        ),
        _headerBackButton(),
      ],
    );
  }

  Widget _headerBackButton() {
    return OutlinedButton.icon(
      onPressed: () {
        if (widget.onNavigate != null) {
          widget.onNavigate!(28); // Back to Data Guru
        } else {
          Navigator.pop(context);
        }
      },
      icon: Icon(Icons.arrow_back, size: 16, color: textDark),
      label: Text('Kembali', style: TextStyle(color: textDark, fontWeight: FontWeight.w500, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: borderColor),
        backgroundColor: Colors.white,
      ),
    );
  }




  Widget _buildProfileHeaderCard() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 900;

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Icon(Icons.person, size: 40, color: textMuted),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            _formatFullName(),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _iconLabel(Icons.person_outline, _teacher['role'] ?? 'Guru Kelas'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _launchEmail(_teacher['email'] ?? ''),
                        child: _iconLabel(Icons.email_outlined, _teacher['email'] ?? '-'),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _launchWhatsApp(_teacher['phone'] ?? ''),
                        child: _iconLabel(Icons.phone_outlined, _teacher['phone'] ?? '-'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            _infoRowItem('NIP / NUPTK', _teacher['nip']),
            _infoRowItem('NIK', _teacher['nik']),
            _infoRowItem('TTL', '${_teacher['birth_place'] ?? '-'}, ${_teacher['birth_date'] ?? '-'}'),
            _infoRowItem('Pendidikan', _teacher['last_education']),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Photo & Basic Info
          SizedBox(
            width: 280,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 90,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Icon(Icons.person, size: 48, color: textMuted),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _formatFullName(),
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _iconLabel(Icons.person_outline, _teacher['role'] ?? 'Guru Kelas'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _launchEmail(_teacher['email'] ?? ''),
                        borderRadius: BorderRadius.circular(4),
                        child: _iconLabel(Icons.email_outlined, _teacher['email'] ?? '-'),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _launchWhatsApp(_teacher['phone'] ?? ''),
                        borderRadius: BorderRadius.circular(4),
                        child: _iconLabel(Icons.phone_outlined, _teacher['phone'] ?? '-'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Vertical Divider
          Container(width: 1, height: 120, color: borderColor),
          const SizedBox(width: 24),
          // Detailed Info Grid
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _infoRowItem('NIP / NUPTK', _teacher['nip']),
                      _infoRowItem('NIK', _teacher['nik']),
                      _infoRowItem('Tempat, Tgl Lahir', '${_teacher['birth_place'] ?? '-'}, ${_teacher['birth_date'] ?? '-'}'),
                      _infoRowItem('Agama', _teacher['religion']),
                      _infoRowItem('Jenis Kelamin', _teacher['gender'] == 'L' ? 'Laki-laki' : 'Perempuan'),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      _infoRowItem('Pendidikan Terakhir', _teacher['last_education']),
                      _infoRowItem('Jurusan', _teacher['major']),
                      _infoRowItem('Universitas / Instansi', _teacher['university']),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: primaryTeal),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label, 
            style: TextStyle(fontSize: 12, color: textDark, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _infoRowItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 12, color: textDark, fontWeight: FontWeight.bold)),
          ),
          Text(':', style: TextStyle(fontSize: 12, color: textDark)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              (value == null || value.toString().isEmpty) ? '-' : value.toString(), 
              style: TextStyle(fontSize: 12, color: textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsSection() {
    bool isAdmin = (widget.userRole == 'Admin' || widget.userRole == 'Super Admin');
    bool isGuru = (widget.userRole == 'Guru');
    bool showAllTabs = isAdmin || isGuru;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: primaryTeal,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryTeal,
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 24),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        onTap: (index) => setState(() {}),
        tabs: [
          if (showAllTabs) const Tab(height: 45, text: 'Profil'),
          const Tab(height: 45, text: 'Pekerjaan'),
          const Tab(height: 45, text: 'Kontak'),
          if (showAllTabs) ...[
            const Tab(height: 45, text: 'Riwayat Pendidikan'),
            const Tab(height: 45, text: 'Aktivitas'),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    bool isAdmin = (widget.userRole == 'Admin' || widget.userRole == 'Super Admin');
    bool isGuru = (widget.userRole == 'Guru');
    bool showAllTabs = isAdmin || isGuru;
    
    if (showAllTabs) {
      switch (_tabController.index) {
        case 0: return _buildProfilTab();
        case 1: return _buildPekerjaanTab();
        case 2: return _buildKontakTab();
        case 3: return _buildRiwayatPendidikanTab();
        case 4: return _buildAktivitasTab();
        default: return _buildProfilTab();
      }
    } else {
      // Role non-staff lainnya jika ada
      switch (_tabController.index) {
        case 0: return _buildPekerjaanTab();
        case 1: return _buildKontakTab();
        default: return _buildPekerjaanTab();
      }
    }
  }

  Widget _buildProfilTab() {
    bool showExtra = (widget.userRole == 'Admin' || widget.userRole == 'Guru' || widget.userRole == 'Super Admin');
    return Column(
      children: [
        _buildSectionCard(
          title: 'Data Pribadi',
          icon: Icons.person_outline,
          children: [
            _dataFieldRow('Nama Lengkap', _teacher['name']),
            _dataFieldRow('NIP / NUPTK', _teacher['nip']),
            _dataFieldRow('NIK', _teacher['nik']),
            _dataFieldRow('Jenis Kelamin', _teacher['gender'] == 'L' ? 'Laki-laki' : 'Perempuan'),
            _dataFieldRow('Tempat, Tgl Lahir', '${_teacher['birth_place'] ?? '-'}, ${_teacher['birth_date'] ?? '-'}'),
            _dataFieldRow('Agama', _teacher['religion']),
          ],
        ),
        if (showExtra) ...[
          const SizedBox(height: 24),
          _buildSectionCard(
            title: 'Administrasi Tambahan',
            icon: Icons.folder_shared_outlined,
            children: [
              _dataFieldRow('NPWP', _teacher['npwp']),
              _dataFieldRow('Status Nikah', _teacher['marital_status']),
              _dataFieldRow('Jml Tanggungan', _teacher['number_of_dependents']),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPekerjaanTab() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'Data Kepegawaian',
          icon: Icons.work_outline,
          showEdit: (widget.userRole == 'Admin' || widget.userRole == 'Super Admin'),
          onEdit: () => _handleEdit(),
          children: [
            _dataFieldRow('Jabatan', _teacher['role']),
            _dataFieldRow('Mata Pelajaran', _teacher['subject'] ?? '-'),
            _dataFieldRow('Tanggal Mulai Mengajar', _teacher['start_date']),
            _dataFieldRow('Status Utama', _teacher['employment_status']),
            _dataFieldRow('Golongan', _teacher['rank_grade']),
            _dataFieldRow('Wali Kelas', _teacher['wali_kelas'] ?? 'Bukan Wali Kelas'),
            _dataFieldRow('Rombel Wali', _teacher['rombel_wali'] ?? '-'),
            _dataFieldRow('Angkatan Wali', _teacher['angkatan_wali'] ?? '-'),
          ],
        ),
      ],
    );
  }

  Widget _buildKontakTab() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'Kontak & Alamat',
          icon: Icons.contact_page_outlined,
          showEdit: (widget.userRole == 'Admin' || widget.userRole == 'Super Admin'),
          onEdit: () => _handleEdit(),
          children: [
            InkWell(
              onTap: () => _launchWhatsApp(_teacher['phone'] ?? ''),
              child: _dataFieldRow('No HP / WhatsApp', _teacher['phone']),
            ),
            InkWell(
              onTap: () => _launchEmail(_teacher['email'] ?? ''),
              child: _dataFieldRow('Email Aktif', _teacher['email']),
            ),
            _dataFieldRow('Alamat Lengkap', _teacher['address']),
          ],
        ),
      ],
    );
  }

  Widget _buildRiwayatPendidikanTab() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'Pendidikan Terakhir',
          icon: Icons.school_outlined,
          children: [
            _buildEducationTable(),
          ],
        ),
      ],
    );
  }

  Widget _buildAktivitasTab() {
    return _buildAktivitasTerakhir();
  }

  void _handleEdit() async {
    if (widget.onNavigate != null) {
      widget.onNavigate!(11, teacher: _teacher);
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TambahGuruPage(teacher: _teacher),
        ),
      );
      if (result == true && mounted) {
        // In a real app, you'd fetch updated data from Supabase here
        Navigator.pop(context, true);
      }
    }
  }

  Widget _buildSectionCard({
    required String title, 
    required IconData icon, 
    bool showEdit = false, 
    VoidCallback? onEdit,
    required List<Widget> children
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: primaryTeal),
                  const SizedBox(width: 12),
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                ],
              ),
              if (showEdit)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, size: 14, color: textSecondary),
                  label: Text('Edit', style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: borderColor)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _dataFieldRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: TextStyle(fontSize: 13, color: textSecondary)),
          ),
          Text(':', style: TextStyle(fontSize: 13, color: textMuted)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              (value == null || value.toString().isEmpty) ? '-' : value.toString(),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationTable() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    if (isMobile) {
      return Column(
        children: [
          _mobileEducationItem('Pendidikan', _teacher['last_education']),
          _mobileEducationItem('Jurusan', _teacher['major']),
          _mobileEducationItem('Institusi', _teacher['university']),
        ],
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(8)),
          children: [
            _tableHeader('Pendidikan'),
            _tableHeader('Jurusan'),
            _tableHeader('Institusi'),
          ],
        ),
        TableRow(
          children: [
            _tableCell(_teacher['last_education'] ?? '-'),
            _tableCell(_teacher['major'] ?? '-'),
            _tableCell(_teacher['university'] ?? '-'),
          ],
        ),
      ],
    );
  }

  Widget _mobileEducationItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
          ),
          const Text(': ', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Text(
              (value == null || value.toString().isEmpty) ? '-' : value.toString(),
              style: TextStyle(fontSize: 12, color: textDark, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(text, style: TextStyle(fontSize: 12, color: textDark)),
    );
  }

  Widget _buildAktivitasTerakhir() {
    return _buildSectionCard(
      title: 'Aktivitas Terakhir',
      icon: Icons.history,
      children: [
        _aktivitasItem('10 Mei 2025', '14:32', 'Menginput nilai siswa pada kelas A'),
        const Divider(height: 24),
        _aktivitasItem('08 Mei 2025', '09:15', 'Mengunggah dokumentasi kegiatan belajar'),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {},
            label: const Text('Lihat Semua Aktivitas'),
            icon: const Icon(Icons.arrow_forward, size: 14),
            style: TextButton.styleFrom(foregroundColor: primaryTeal, textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _aktivitasItem(String date, String time, String desc) {
    return Row(
      children: [
        Column(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: textMuted, shape: BoxShape.circle)),
            Container(width: 2, height: 20, color: borderColor),
          ],
        ),
        const SizedBox(width: 16),
        Text(date, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(width: 8),
        Text(time, style: TextStyle(fontSize: 12, color: textSecondary)),
        const SizedBox(width: 16),
        Expanded(child: Text(desc, style: TextStyle(fontSize: 12, color: textSecondary))),
      ],
    );
  }
}
