import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'dart:typed_data';
import '../utils/notification_helper.dart';

class DetailSiswaPage extends StatefulWidget {
  final dynamic student;
  final String userRole;
  final String? studentNis;
  final bool isEmbedded;
  final Function(int, {Map<String, dynamic>? student})? onNavigate;
  final int returnIndex;
  final String returnLabel;

  const DetailSiswaPage({
    super.key, 
    this.student, 
    required this.userRole, 
    this.studentNis,
    this.isEmbedded = false,
    this.onNavigate,
    this.returnIndex = 1,
    this.returnLabel = 'Data Siswa',
  });

  @override
  State<DetailSiswaPage> createState() => _DetailSiswaPageState();
}

class _DetailSiswaPageState extends State<DetailSiswaPage> with SingleTickerProviderStateMixin {
  // --- Color Palette ---
  final Color primaryTeal = AppColors.primary; 
  final Color backgroundColor = AppColors.backgroundColor;
  final Color textDark = AppColors.textDark;
  final Color textSecondary = AppColors.textSecondary;
  final Color textMuted = AppColors.textMuted;
  final Color borderColor = AppColors.borderColor;

  late dynamic _student;
  final ScreenshotController _screenshotController = ScreenshotController();
  late TabController _tabController;
  
  // Attendance Stats
  int _hadir = 0;
  int _izin = 0;
  int _sakit = 0;
  bool _loadingAttendance = false;

  @override
  void initState() {
    super.initState();
    _student = widget.student;
    _tabController = TabController(length: 2, vsync: this);
    _refreshStudentData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshStudentData() async {
    if (_student == null && widget.studentNis == null) return;
    
    try {
      final apiService = ApiService();
      final studentId = _student?['id'];

      if (widget.userRole == 'Admin' || widget.userRole == 'Guru' || widget.userRole == 'Super Admin') {
        if (studentId != null) {
          final response = await apiService.getRow('students', studentId.toString());
          setState(() {
            _student = response;
          });
          _fetchAttendance(studentId);
        }
      } else if (widget.studentNis != null) {
        final response = await apiService.callRpc('get_my_profile', params: {'p_nis': widget.studentNis});
        if (response != null && (response as List).isNotEmpty) {
          setState(() {
            _student = response.first;
          });
          if (_student['id'] != null) {
            _fetchAttendance(_student['id']);
          }
        }
      }
    } catch (e) {
      debugPrint('Error refreshing student data: $e');
    }
  }

  Future<void> _fetchAttendance(dynamic studentId) async {
    setState(() => _loadingAttendance = true);
    try {
      final response = await ApiService().getTable('attendance', queryParameters: {'student_id': studentId.toString()});

      int h = 0, i = 0, s = 0;
      for (var row in response) {
        final status = row['status'];
        if (status == 'Hadir') {
          h++;
        } else if (status == 'Izin') {
          i++;
        } else if (status == 'Sakit') {
          s++;
        }
      }

      if (mounted) {
        setState(() {
          _hadir = h;
          _izin = i;
          _sakit = s;
          _loadingAttendance = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching attendance: $e');
      if (mounted) setState(() => _loadingAttendance = false);
    }
  }

  String _calculateAge(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return '-';
    try {
      DateTime birthDate = DateTime.parse(birthDateStr);
      DateTime today = DateTime.now();
      int years = today.year - birthDate.year;
      int months = today.month - birthDate.month;
      if (today.day < birthDate.day) {
        months--;
      }
      if (months < 0) {
        years--;
        months += 12;
      }
      return '$years Tahun $months Bulan';
    } catch (e) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_student == null) {
      return const Center(child: Text('Data siswa tidak ditemukan'));
    }

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
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 700;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 24),
          _buildProfileHeaderCard(),
          const SizedBox(height: 24),
          _buildTabsSection(),
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
            Text('Detail Siswa', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark)),
          ],
        ),
        OutlinedButton.icon(
          onPressed: () {
            if (widget.onNavigate != null) {
              widget.onNavigate!(widget.returnIndex); 
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
        ),
      ],
    );
  }

  Widget _buildProfileHeaderCard() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                        color: const Color(0xFFF1F5F9),
                      ),
                      child: Center(
                        child: Text(
                          (_student['name'] ?? '?')[0].toUpperCase(),
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryTeal),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _statusBadge(_student['status']),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_student['name'] ?? '-', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 4),
                      Text('NIS: ${_student['nis'] ?? '-'}', style: TextStyle(fontSize: 13, color: textSecondary)),
                      const SizedBox(height: 6),
                      _genderBadge(_student['gender']),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _headerInfoItemCompact(Icons.book_outlined, _student['class'] ?? '-'),
                  const SizedBox(width: 12),
                  _headerInfoItemCompact(Icons.calendar_today_outlined, _student['batch'] ?? '-'),
                  const SizedBox(width: 12),
                  _headerInfoItemCompact(Icons.access_time, _calculateAge(_student['birth_date'])),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.userRole != 'User')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (widget.onNavigate != null) {
                          widget.onNavigate!(10, student: _student);
                        }
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTeal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (widget.userRole != 'User') const SizedBox(width: 8),
                _iconActionBtn(Icons.message_outlined, onTap: () => _launchWhatsApp(_student['parent_phone'] ?? '')),
                const SizedBox(width: 8),
                _iconActionBtn(Icons.qr_code_scanner_outlined, onTap: () => _showQRCode()),
                if (widget.userRole != 'User') ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTapDown: (details) => _showMoreMenu(details.globalPosition),
                    child: _iconActionBtn(Icons.more_vert),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                  color: const Color(0xFFF1F5F9),
                ),
                child: Center(
                  child: Text(
                    (_student['name'] ?? '?')[0].toUpperCase(),
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: primaryTeal),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _statusBadge(_student['status']),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(_student['name'] ?? '-', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark)),
                    const SizedBox(width: 12),
                    Text('NIS: ${_student['nis'] ?? '-'}', style: TextStyle(fontSize: 13, color: textSecondary)),
                    const SizedBox(width: 12),
                    _genderBadge(_student['gender']),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _headerInfoItem(Icons.book_outlined, 'Kelas', _student['class'] ?? '-'),
                    _headerInfoItem(Icons.category_outlined, 'Rombel', _student['rombel'] ?? '-'),
                    _headerInfoItem(Icons.calendar_today_outlined, 'Angkatan', _student['batch'] ?? '-'),
                    _headerInfoItem(Icons.location_on_outlined, 'Tempat, Tgl Lahir', '${_student['birth_place'] ?? '-'}, ${_student['birth_date'] ?? '-'}'),
                    _headerInfoItem(Icons.access_time, 'Usia', _calculateAge(_student['birth_date'])),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (widget.userRole != 'User') ...[
                OutlinedButton.icon(
                  onPressed: () {
                    if (widget.onNavigate != null) {
                      widget.onNavigate!(10, student: _student);
                    }
                  },
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: borderColor),
                    foregroundColor: textDark,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _iconActionBtn(Icons.message_outlined, onTap: () => _launchWhatsApp(_student['parent_phone'] ?? '')),
              const SizedBox(width: 8),
              _iconActionBtn(Icons.qr_code_scanner_outlined, onTap: () => _showQRCode()),
              if (widget.userRole != 'User') ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTapDown: (details) => _showMoreMenu(details.globalPosition),
                  child: _iconActionBtn(Icons.more_vert),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerInfoItemCompact(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primaryTeal),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textDark)),
        ],
      ),
    );
  }

  Widget _statusBadge(String? status) {
    bool isActive = status == 'Aktif';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status ?? 'Aktif',
        style: TextStyle(
          color: isActive ? const Color(0xFF166534) : const Color(0xFF64748B),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _genderBadge(String? gender) {
    bool isMale = gender == 'L';
    Color color = isMale ? const Color(0xFF3B82F6) : const Color(0xFFEC4899);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isMale ? Icons.male : Icons.female, size: 14, color: color),
          const SizedBox(width: 4),
          Text(isMale ? 'Laki-laki' : 'Perempuan', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _headerInfoItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textMuted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark)),
        ),
      ],
    );
  }

  Widget _iconActionBtn(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 20, color: textSecondary),
      ),
    );
  }

  Future<void> _launchWhatsApp(String phone) async {
    if (phone.isEmpty) {
      NotificationHelper.show(context, 'Nomor HP tidak ditemukan', isError: true);
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    String formattedPhone = cleanPhone;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '62${formattedPhone.substring(1)}';
    }
    final url = Uri.parse("https://wa.me/$formattedPhone");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      NotificationHelper.show(context, 'Gagal membuka WhatsApp', isError: true);
    }
  }

  void _showMoreMenu(Offset offset) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        offset & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          onTap: () => _deleteStudent(),
          child: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text('Hapus Siswa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _deleteStudent() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data'),
        content: Text('Apakah Anda yakin ingin menghapus data siswa ${_student['name']}? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService().delete('students', _student['id'].toString());
        
        if (!mounted) return;
        NotificationHelper.show(context, 'Data siswa berhasil dihapus');
        if (widget.onNavigate != null) {
          widget.onNavigate!(1); // Back to list
        } else {
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('Error deleting student: $e');
        if (!mounted) return;
        NotificationHelper.show(context, 'Gagal menghapus data siswa', isError: true);
      }
    }
  }

  void _showQRCode() {
    final String nisData = _student['nis']?.toString() ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('QR Code Siswa', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Screenshot(
              controller: _screenshotController,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // QR Code dengan wrapper ukuran pasti
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: QrImageView(
                        data: nisData.isEmpty ? 'Data Kosong' : nisData,
                        version: QrVersions.auto,
                        size: 200.0,
                        gapless: false,
                        backgroundColor: Colors.white,
                        // Gunakan warna hitam default dulu agar pasti muncul
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(_student['name'] ?? 'Siswa', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('NIS: $nisData', style: TextStyle(color: textSecondary, fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _downloadQRCode,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Simpan ke Galeri', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadQRCode() async {
    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image != null) {
        await Gal.putImageBytes(image, name: "QR_${_student['name']}");
        if (!mounted) return;
        NotificationHelper.show(context, 'QR Code berhasil disimpan ke galeri');
      }
    } catch (e) {
      debugPrint('Error saving QR Code: $e');
      if (!mounted) return;
      NotificationHelper.show(context, 'Gagal menyimpan QR Code', isError: true);
    }
  }

  Widget _buildTabsSection() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 700;

    return Column(
      children: [
        Container(
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
            labelPadding: const EdgeInsets.symmetric(horizontal: 20),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(height: 45, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.person_outline, size: 18), SizedBox(width: 8), Text('Data Pribadi')])),
              Tab(height: 45, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.group_outlined, size: 18), SizedBox(width: 8), Text('Orang Tua / Wali')])),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Lepas batasan tinggi kaku, gunakan Column di HP agar bisa scroll alami
        if (isMobile)
          Column(
            children: [
              if (_tabController.index == 0) _buildDataPribadiTab(),
              if (_tabController.index == 1) _buildOrangTuaTab(),
            ],
          )
        else
          SizedBox(
            height: 500,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDataPribadiTab(),
                _buildOrangTuaTab(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOrangTuaTab() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 700; // Disamakan ke 700

    if (isMobile) {
      return Column(
        children: [
          _buildInfoSection('Data Ayah & Ibu', [
            _dataRow('Nama Ayah', _student['father_name']),
            _dataRow('Pekerjaan Ayah', _student['father_job'] ?? '-'),
            const Divider(height: 32),
            _dataRow('Nama Ibu', _student['mother_name']),
            _dataRow('Pekerjaan Ibu', _student['mother_job'] ?? '-'),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('Kontak & Alamat', [
            _dataRow('No. HP Orang Tua', _student['parent_phone']),
            _dataRow('Alamat Orang Tua', _student['parent_address'] ?? '-'),
            _dataRow('Kecamatan', _student['parent_district'] ?? '-'),
            _dataRow('Kabupaten / Kota', _student['parent_city'] ?? '-'),
            _dataRow('Provinsi', _student['parent_province'] ?? '-'),
          ]),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: _buildInfoSection('Data Ayah & Ibu', [
            _dataRow('Nama Ayah', _student['father_name']),
            _dataRow('Pekerjaan Ayah', _student['father_job'] ?? '-'),
            const Divider(height: 32),
            _dataRow('Nama Ibu', _student['mother_name']),
            _dataRow('Pekerjaan Ibu', _student['mother_job'] ?? '-'),
          ]),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 4,
          child: _buildInfoSection('Kontak & Alamat', [
            _dataRow('No. HP Orang Tua', _student['parent_phone']),
            _dataRow('Alamat Orang Tua', _student['parent_address'] ?? '-'),
            _dataRow('Kecamatan', _student['parent_district'] ?? '-'),
            _dataRow('Kabupaten / Kota', _student['parent_city'] ?? '-'),
            _dataRow('Provinsi', _student['parent_province'] ?? '-'),
          ]),
        ),
      ],
    );
  }

  Widget _buildDataPribadiTab() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 700; // Disamakan ke 700

    if (isMobile) {
      return Column(
        children: [
          _buildInfoSection('Informasi Pribadi', [
            _dataRow('Nama Lengkap', _student['name']),
            _dataRow('Nama Panggilan', _student['nickname'] ?? '-'),
            _dataRow('NIS', _student['nis']),
            _dataRow('Jenis Kelamin', _student['gender'] == 'L' ? 'Laki-laki' : 'Perempuan'),
            _dataRow('Tempat, Tgl Lahir', '${_student['birth_place'] ?? '-'}, ${_student['birth_date'] ?? '-'}'),
            _dataRow('Agama', _student['religion']),
            _dataRow('Kewarganegaraan', _student['citizenship'] ?? 'Indonesia'),
            _dataRow('Anak Ke', '${_student['child_number'] ?? '-'}'),
            _dataRow('Bahasa Sehari-hari', _student['language'] ?? 'Indonesia'),
            _dataRow('Asal Sekolah', _student['school_of_origin'] ?? '-'),
            _dataRow('Alamat', '${_student['address'] ?? '-'}, RT ${_student['rt'] ?? '-'}/RW ${_student['rw'] ?? '-'}, Kel. ${_student['village'] ?? '-'}'),
            _dataRow('Status', _student['status'], isBadge: true),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('Informasi Kelas', [
            _dataRow('Angkatan', _student['batch']),
            _dataRow('Kelas', _student['class']),
            _dataRow('Rombel', _student['rombel']),
            _dataRow('Wali Kelas', 'Ibu Siti Nur Aisyah, S.Pd.', isTeacher: true),
          ]),
          const SizedBox(height: 24),
          _buildKehadiranSection(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: _buildInfoSection('Informasi Pribadi', [
            _dataRow('Nama Lengkap', _student['name']),
            _dataRow('Nama Panggilan', _student['nickname'] ?? '-'),
            _dataRow('NIS', _student['nis']),
            _dataRow('Jenis Kelamin', _student['gender'] == 'L' ? 'Laki-laki' : 'Perempuan'),
            _dataRow('Tempat, Tgl Lahir', '${_student['birth_place'] ?? '-'}, ${_student['birth_date'] ?? '-'}'),
            _dataRow('Agama', _student['religion']),
            _dataRow('Kewarganegaraan', _student['citizenship'] ?? 'Indonesia'),
            _dataRow('Anak Ke', '${_student['child_number'] ?? '-'}'),
            _dataRow('Bahasa Sehari-hari', _student['language'] ?? 'Indonesia'),
            _dataRow('Asal Sekolah', _student['school_of_origin'] ?? '-'),
            _dataRow('Alamat', '${_student['address'] ?? '-'}, RT ${_student['rt'] ?? '-'}/RW ${_student['rw'] ?? '-'}, Kel. ${_student['village'] ?? '-'}'),
            _dataRow('Status', _student['status'], isBadge: true),
          ]),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection('Informasi Kelas', [
                _dataRow('Angkatan', _student['batch']),
                _dataRow('Kelas', _student['class']),
                _dataRow('Rombel', _student['rombel']),
                _dataRow('Wali Kelas', 'Ibu Siti Nur Aisyah, S.Pd.', isTeacher: true),
              ]),
              const SizedBox(height: 24), 
              _buildKehadiranSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16), // Further reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
          const SizedBox(height: 12), // Reduced spacing
          ...children,
        ],
      ),
    );
  }

  Widget _dataRow(String label, dynamic value, {bool isBadge = false, bool isTeacher = false}) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 700; // Disamakan ke 700

    if (isMobile) {
      IconData getIcon() {
        switch (label.toLowerCase()) {
          case 'nama lengkap': return Icons.person_outline_rounded;
          case 'nama panggilan': return Icons.face_outlined;
          case 'nis': return Icons.badge_outlined;
          case 'jenis kelamin': return Icons.wc_rounded;
          case 'tempat, tgl lahir': return Icons.cake_outlined;
          case 'agama': return Icons.auto_awesome_outlined;
          case 'kewarganegaraan': return Icons.flag_outlined;
          case 'anak ke': return Icons.format_list_numbered_rounded;
          case 'bahasa sehari-hari': return Icons.translate_rounded;
          case 'alamat': return Icons.location_on_outlined;
          case 'angkatan': return Icons.calendar_today_outlined;
          case 'kelas': return Icons.school_outlined;
          case 'rombel': return Icons.category_outlined;
          case 'wali kelas': return Icons.supervisor_account_outlined;
          case 'nama ayah': return Icons.person_pin_rounded;
          case 'nama ibu': return Icons.person_pin_rounded;
          case 'pekerjaan ayah': return Icons.work_outline_rounded;
          case 'pekerjaan ibu': return Icons.work_outline_rounded;
          case 'no. hp orang tua': return Icons.phone_android_rounded;
          case 'alamat orang tua': return Icons.home_outlined;
          default: return Icons.info_outline_rounded;
        }
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryTeal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(getIcon(), size: 18, color: primaryTeal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w500, letterSpacing: 0.2)),
                  const SizedBox(height: 4),
                  if (isBadge) 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
                      child: Text(value?.toString() ?? '-', style: const TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  else if (isTeacher)
                    Row(
                      children: [
                        const CircleAvatar(radius: 10, backgroundImage: AssetImage('assets/tk-it.png')),
                        const SizedBox(width: 8),
                        Expanded(child: Text(value?.toString() ?? '-', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark))),
                      ],
                    )
                  else
                    Text(value?.toString() ?? '-', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Tampilan Desktop (Kembali ke format Row semula)
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(fontSize: 13, color: textSecondary)),
          ),
          const Text(':', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          const SizedBox(width: 16),
          Expanded(
            child: isBadge 
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
                      child: Text(value?.toString() ?? '-', style: const TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  )
                : isTeacher 
                    ? Row(
                        children: [
                          const CircleAvatar(radius: 10, backgroundImage: AssetImage('assets/tk-it.png')),
                          const SizedBox(width: 8),
                          Text(value?.toString() ?? '-', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                        ],
                      )
                    : Text(value?.toString() ?? '-', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildKehadiranSection() {
    int total = _hadir + _izin + _sakit;
    String getPercent(int count) {
      if (total == 0) return '0%';
      return '${((count / total) * 100).toStringAsFixed(0)}%';
    }

    return Container(
      padding: const EdgeInsets.all(16), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kehadiran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
          const SizedBox(height: 16), // Reduced spacing
          if (_loadingAttendance)
            const Center(child: LinearProgressIndicator())
          else
            Row(
              children: [
                _kehadiranCard(_hadir.toString(), 'Hadir', getPercent(_hadir), const Color(0xFF22C55E), Icons.event_available_outlined),
                const SizedBox(width: 12),
                _kehadiranCard(_izin.toString(), 'Izin', getPercent(_izin), const Color(0xFFF59E0B), Icons.assignment_outlined),
                const SizedBox(width: 12),
                _kehadiranCard(_sakit.toString(), 'Sakit', getPercent(_sakit), const Color(0xFFEF4444), Icons.calendar_today_outlined),
              ],
            ),
        ],
      ),
    );
  }

  Widget _kehadiranCard(String count, String label, String percent, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(count, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark)),
                        const SizedBox(width: 4),
                        Text(label, style: TextStyle(fontSize: 10, color: textSecondary)),
                      ],
                    ),
                  ),
                  Text(percent, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
