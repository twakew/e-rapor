import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'package:laporsekolaherapor/datasiwa/data_siswa.dart';
import 'package:laporsekolaherapor/datasiwa/tambah_siswa.dart';
import 'package:laporsekolaherapor/datasiwa/detail_siswa.dart';
import 'package:laporsekolaherapor/dataguru/tambah_guru.dart';
import 'package:laporsekolaherapor/dataguru/detail_guru.dart';
import '../angkatan/angkatan_page.dart';
import '../dataguru/data_guru.dart';
import '../dokumentasi/dokumentasi_page.dart';
import '../absensi/absensi_page.dart';
import '../penilaian/penilaian_page.dart';
import '../penilaian/input_nilai_page.dart';
import '../erapor/download_pdf_page.dart';
import '../pengaturan/pengaturan_page.dart';
import '../pengaturan/verifikasi_akun_page.dart';
import '../pengaturan/daftar_akun_page.dart';
import '../pengaturan/ganti_password_page.dart';
import '../datasekolah/data_sekolah.dart';
import '../datasekolah/edit_sekolah.dart';
import '../datakelas/data_kelas_page.dart';
import '../datakelas/detail_kelas_page.dart';
import '../angkatan/detail_angkatan_page.dart';
import '../dokumentasi/tambah_dokumentasi.dart';
import '../dokumentasi/edit_dokumentasi.dart';
import '../dokumentasi/detail_dokumentasi.dart';
import 'profil_page.dart';

class DasbhorPage extends StatefulWidget {
  final String? initialRole;
  final String? studentName;
  final String? studentNis;
  final String? studentClass;
  const DasbhorPage({super.key, this.initialRole, this.studentName, this.studentNis, this.studentClass});

  @override
  State<DasbhorPage> createState() => _DasbhorPageState();
}

class _DasbhorPageState extends State<DasbhorPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // --- Color Palette (Now using central AppColors) ---
  final Color primaryTeal = AppColors.primary; 
  final Color secondaryTeal = AppColors.secondary;
  final Color accentGreen = AppColors.accent;
  final Color backgroundColor = AppColors.backgroundColor;
  final Color sidebarBg = Colors.white;
  final Color textDark = AppColors.textDark;
  final Color textSecondary = AppColors.textSecondary;
  final Color textMuted = AppColors.textMuted;
  
  final user = Supabase.instance.client.auth.currentUser;
  final supabase = Supabase.instance.client;
  
  int _totalSiswa = 0;
  int _totalGuru = 0;
  int _totalKelas = 0;
  int _totalDokumentasi = 0;
  String _schoolName = 'LAPOR SEKOLAH';
  String _academicYear = DateTime.now().year.toString();
  final String _schoolSub = 'Sistem Informasi & E-Rapor';
  late String _userRole;
  int _selectedIndex = 0;
  int _profileReturnIndex = 0;
  int _detailSiswaReturnIndex = 1;
  String _detailSiswaReturnLabel = 'Data Siswa';
  Map<String, dynamic>? _activeStudentData;
  Map<String, dynamic>? _activeTeacherData;
  Map<String, dynamic>? _activeClassData;
  Map<String, dynamic>? _activeBatchData;
  Map<String, dynamic>? _activeDocumentationData;
  Map<String, dynamic>? _activeSchoolData;
  List<dynamic>? _activeAssessments;
  int? _activeSemester;
  bool _isSidebarCollapsed = false;
  
  DateTime? _lastQuitTime;
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  final List<StreamSubscription> _statsSubscriptions = [];
  StreamSubscription? _schoolSubscription;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _userRole = widget.initialRole ?? (user?.email == 'triandre980@gmail.com' ? 'Admin' : 'User');
    _fetchStats();
    _fetchSchoolInfo(); 
    _setupRealtimeStats();
    _setupSchoolRealtime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _schoolSubscription?.cancel();
    for (var sub in _statsSubscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _fetchSchoolInfo() async {
    try {
      final data = await supabase.from('school_data').select('name, curriculum').maybeSingle();
      if (mounted && data != null) {
        setState(() {
          _schoolName = data['name'] ?? 'LAPOR SEKOLAH';
          String curr = data['curriculum']?.toString() ?? '';
          if (curr.isNotEmpty) {
            final match = RegExp(r'\d{4}').firstMatch(curr);
            if (match != null) {
              _academicYear = match.group(0)!;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching school info: $e');
    }
  }

  void _setupSchoolRealtime() {
    _schoolSubscription = supabase
        .from('school_data')
        .stream(primaryKey: ['id'])
        .listen((data) {
      if (mounted && data.isNotEmpty) {
        setState(() {
          _schoolName = data.first['name'] ?? 'LAPOR SEKOLAH';
          String curr = data.first['curriculum']?.toString() ?? '';
          if (curr.isNotEmpty) {
            final match = RegExp(r'\d{4}').firstMatch(curr);
            if (match != null) {
              _academicYear = match.group(0)!;
            }
          }
        });
      }
    });
  }

  void _setupRealtimeStats() {
    final tables = ['students', 'teachers', 'documentation'];
    for (var table in tables) {
      try {
        final sub = supabase.from(table).stream(primaryKey: ['id']).listen((_) {
          _fetchStats();
        }, onError: (e) => debugPrint('Stream error on $table: $e'));
        _statsSubscriptions.add(sub);
      } catch (e) {
        debugPrint('Realtime not available for $table');
      }
    }
  }

  Future<void> _fetchStats() async {
    try {
      final siswa = await supabase.from('students').select('name').eq('status', 'Aktif');
      if (mounted) setState(() => _totalSiswa = (siswa as List).length);
    } catch (e) { debugPrint('Siswa fetch error: $e'); }

    try {
      final guru = await supabase.from('teachers').select('name');
      if (mounted) setState(() => _totalGuru = (guru as List).length);
    } catch (e) { debugPrint('Guru fetch error: $e'); }

    try {
      _fetchKelasFromStudents(); 
    } catch (e) { 
      debugPrint('Kelas fetch error: $e');
    }

    try {
      final dok = await supabase.from('documentation').select('id');
      if (mounted) setState(() => _totalDokumentasi = (dok as List).length);
    } catch (e) { debugPrint('Dokumentasi fetch error: $e'); }
  }

  Future<void> _fetchKelasFromStudents() async {
    try {
      final students = await supabase.from('students').select('class');
      final uniqueClasses = (students as List)
          .map((s) => s['class'])
          .where((c) => c != null && c.toString().isNotEmpty)
          .toSet();
      if (mounted && uniqueClasses.isNotEmpty) {
        setState(() => _totalKelas = uniqueClasses.length);
      }
    } catch (e) {
      debugPrint('Fallback fetch kelas error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    String displayName = widget.studentName ?? (_userRole == 'Admin' ? 'Admin' : 'User');
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 1100;

    bool isGalleryMode = _selectedIndex == 21;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final nextIndex = _getBackIndex();
        
        if (nextIndex >= 0) {
          setState(() => _selectedIndex = nextIndex);
        } else {
          // Logic "double tap to exit" for Dashboard (index 0)
          final now = DateTime.now();
          if (_lastQuitTime == null || now.difference(_lastQuitTime!) > const Duration(seconds: 2)) {
            _lastQuitTime = now;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text('Tekan sekali lagi untuk keluar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                backgroundColor: AppColors.primary.withValues(alpha: 0.9),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 2),
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              ),
            );
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: isGalleryMode ? Colors.black : backgroundColor,
        drawer: (isDesktop || isGalleryMode) ? null : null, // Disable drawer for mobile
        bottomNavigationBar: (!isDesktop && !isGalleryMode) ? _buildBottomNav() : null,
        body: Row(
          children: [
            if (isDesktop && !isGalleryMode) _buildSidebar(displayName),
            Expanded(
              child: Column(
                children: [
                  if (!isGalleryMode)
                    _buildTopBar(displayName, isDesktop),
                  Expanded(
                    child: _buildCurrentPage(screenWidth, isDesktop, displayName),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getBackIndex() {
    switch (_selectedIndex) {
      case 0: return -1; // Exit
      case 10: return 1; // Tambah Siswa -> Data Siswa
      case 15: return _detailSiswaReturnIndex; // Detail Siswa -> Back to caller
      case 11: return 28; // Tambah Guru -> Data Guru
      case 16: return 28; // Detail Guru -> Data Guru
      case 17: return 12; // Detail Kelas -> Data Kelas
      case 27: return 6; // Detail Angkatan -> Data Angkatan
      case 18: return 3; // Input Nilai -> Penilaian
      case 19: 
      case 20: 
      case 21: return 4; // Dokumentasi subs -> Dokumentasi
      case 26: return 7; // Edit Sekolah -> Profil Sekolah
      case 22: 
      case 23: 
      case 24: return 8; // Pengaturan subs -> Pengaturan
      case 9: return _profileReturnIndex; // Profil -> Back to caller
      default: return 0; // Everything else back to Home
    }
  }

  Widget _buildTopBar(String name, bool isDesktop) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;
    return Container(
      margin: EdgeInsets.fromLTRB(isMobile ? 12 : 24, isMobile ? 12 : 16, isMobile ? 12 : 24, 0),
      height: isMobile ? 60 : 70,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          if (isDesktop)
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: Color(0xFF64748B)),
              onPressed: () {
                setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
              },
            )
          else
            // Logo & School Branding for Mobile TopBar
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: primaryTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Image.asset('assets/logo_sekolah.png', fit: BoxFit.contain),
                ),
                const SizedBox(width: 10),
                Text(
                  _schoolName.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: 0.3),
                ),
              ],
            ),
          const Spacer(),
          _topBarNotificationIcon(),
          const SizedBox(width: 16),
          Container(
            height: 24,
            width: 1,
            color: Colors.grey.shade200,
          ),
          const SizedBox(width: 16),
          _buildUserSection(name),
        ],
      ),
    );
  }

  Widget _topBarNotificationIcon() {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return Icon(Icons.notifications_none_rounded, color: const Color(0xFF64748B), size: isMobile ? 22 : 26);
  }

  Widget _buildUserSection(String name) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;
    return InkWell(
      onTap: () => setState(() {
        _profileReturnIndex = 0; // Return to Dashboard
        _selectedIndex = 9;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFF1F5F9),
            child: Icon(Icons.person_rounded, size: 20, color: const Color(0xFF64748B)),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
          ],
        ],
      ),
    );
  }


  Widget _buildSidebar(String name) {
    bool isDesktop = MediaQuery.of(context).size.width > 1100;
    bool effectivelyCollapsed = isDesktop ? _isSidebarCollapsed : false; 
    double width = effectivelyCollapsed ? 80 : 280;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(4, 0))],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: effectivelyCollapsed ? 8 : 20, vertical: 24),
            child: Row(
              mainAxisAlignment: effectivelyCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40, 
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: primaryTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Image.asset('assets/logo_sekolah.png', fit: BoxFit.contain),
                ),
                if (!effectivelyCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _schoolName.toUpperCase(), 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: 0.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(_schoolSub, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _sidebarItem(Icons.home_outlined, 'Dashboard', 0, isCollapsedOverride: effectivelyCollapsed),
                  _sidebarItem(Icons.fact_check_outlined, 'Absensi', 5, isCollapsedOverride: effectivelyCollapsed),
                  
                  _sidebarItem(Icons.group_outlined, 'Data Siswa', 1, isOtherActive: (_selectedIndex == 15 && _detailSiswaReturnIndex == 1) || _selectedIndex == 10, isCollapsedOverride: effectivelyCollapsed),
                  _sidebarItem(Icons.person_outline, 'Data Guru', 28, isOtherActive: _selectedIndex == 16 || _selectedIndex == 11, isCollapsedOverride: effectivelyCollapsed),
                  _sidebarItem(Icons.business_outlined, 'Data Kelas', 12, isOtherActive: _selectedIndex == 17 || (_selectedIndex == 15 && _detailSiswaReturnIndex == 17), isCollapsedOverride: effectivelyCollapsed),
                  _sidebarItem(Icons.edit_note_outlined, 'Penilaian', 3, isCollapsedOverride: effectivelyCollapsed),
                  _sidebarItem(Icons.picture_as_pdf_outlined, 'E-Rapor PDF', 13, isCollapsedOverride: effectivelyCollapsed),

                  _sidebarItem(Icons.school_outlined, 'Data Angkatan', 6, isCollapsedOverride: effectivelyCollapsed),
                  _sidebarItem(Icons.image_outlined, 'Dokumentasi', 4, isCollapsedOverride: effectivelyCollapsed),
                  _sidebarItem(Icons.account_balance_outlined, 'Profil Sekolah', 7, isCollapsedOverride: effectivelyCollapsed),
                  _sidebarItem(Icons.settings_outlined, 'Pengaturan', 8, isCollapsedOverride: effectivelyCollapsed),
                ],
              ),
            ),
          ),
          if (!effectivelyCollapsed)
            Transform.translate(
              offset: const Offset(0, 25), // Geser lebih bawah agar menempel/duduk di garis
              child: Opacity(
                opacity: 0.9,
                child: Image.asset(
                  'assets/tk-it.png',
                  width: width,
                  height: 140, // Ukuran dikembalikan agak besar tapi pas
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            ),
          _buildSidebarFooter(isCollapsedOverride: effectivelyCollapsed),
        ],
      ),
    );
  }

  void _handleRestrictedAccess(String label, int index) {
    setState(() {
      if (index == 9) _profileReturnIndex = _selectedIndex;
      _selectedIndex = index;
    });
  }

  Widget _sidebarItem(IconData icon, String label, int index, {bool hasDropdown = false, bool isExpanded = false, VoidCallback? onExpand, List<Widget>? subItems, bool isOtherActive = false, bool? isCollapsedOverride}) {
    bool active = _selectedIndex == index || isOtherActive;
    bool isParentActive = active || (subItems != null && isExpanded);
    bool collapsed = isCollapsedOverride ?? _isSidebarCollapsed;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Stack(
            children: [
              if (isParentActive && !collapsed)
                Positioned(
                  left: -12,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: primaryTeal,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                    ),
                  ),
                ),
              Material(
                color: isParentActive ? primaryTeal.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    if (hasDropdown && onExpand != null) {
                      onExpand();
                    } else {
                      _handleRestrictedAccess(label, index);
                      if (MediaQuery.of(context).size.width < 1100) {
                        Navigator.pop(context); 
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 8, vertical: 12),
                    child: Row(
                      mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                      children: [
                        Icon(
                          icon, 
                          color: isParentActive ? primaryTeal : const Color(0xFF64748B), 
                          size: 22
                        ),
                        if (!collapsed) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isParentActive ? primaryTeal : const Color(0xFF64748B),
                                fontWeight: isParentActive ? FontWeight.bold : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (hasDropdown)
                            Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, 
                                 color: isParentActive ? primaryTeal : const Color(0xFF64748B), size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasDropdown && isExpanded && subItems != null && !collapsed)
          ...subItems,
      ],
    );
  }

  Widget _buildSidebarFooter({bool? isCollapsedOverride}) {
    bool collapsed = isCollapsedOverride ?? _isSidebarCollapsed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!collapsed)
            Expanded(
              child: Text(
                '© $_academicYear TK IT AL-HANIF LEDENG',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9, 
                  color: const Color(0xFF94A3B8), 
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          if (MediaQuery.of(context).size.width > 1100) 
            InkWell(
              onTap: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Icon(
                  collapsed ? Icons.chevron_right : Icons.chevron_left,
                  size: 18,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage(double screenWidth, bool isDesktop, String displayName) {
    switch (_selectedIndex) {
      case 1:
        return DataSiswaPage(
          studentNis: widget.studentNis,
          studentClass: widget.studentClass,
          isEmbedded: true,
          userName: displayName,
          onNavigate: (index, {student}) {
            setState(() {
              _selectedIndex = index;
              _activeStudentData = student;
              if (index == 15) {
                _detailSiswaReturnIndex = 1;
                _detailSiswaReturnLabel = 'Data Siswa';
              }
            });
          },
        );
      case 2:
        return _buildMenuPage();
      case 28:
        return DataGuruPage(
          isEmbedded: true,
          onNavigate: (index, {teacher}) {
            setState(() {
              _selectedIndex = index;
              _activeTeacherData = teacher;
            });
          },
        );
      case 3:
        return PenilaianPage(
          userRole: _userRole, 
          studentNis: widget.studentNis,
          isEmbedded: true,
          onNavigate: (index, {student, assessments, semester}) {
            setState(() {
              _selectedIndex = index;
              _activeStudentData = student;
              _activeAssessments = assessments;
              _activeSemester = semester;
            });
          },
        );
      case 4:
        return DokumentasiPage(
          onNavigate: (index, {documentation}) {
            setState(() {
              _selectedIndex = index;
              _activeDocumentationData = documentation;
            });
          },
        );
      case 19:
        return TambahDokumentasiPage(
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );
      case 20:
        return EditDokumentasiPage(
          dokumentasi: _activeDocumentationData,
          onNavigate: (index) {
            debugPrint('Navigating from Edit to index: $index');
            setState(() => _selectedIndex = index);
          },
        );
      case 21:
        return DetailDokumentasiPage(
          dokumentasi: _activeDocumentationData,
          onBack: () => setState(() => _selectedIndex = 4),
        );
      case 5:
        return AbsensiPage(userRole: _userRole, studentNis: widget.studentNis, studentClass: widget.studentClass);
      case 6:
        return AngkatanPage(
          studentNis: widget.studentNis,
          onNavigate: (index, {student, batchData}) {
            setState(() {
              _selectedIndex = index;
              if (student != null) _activeStudentData = student;
              if (batchData != null) _activeBatchData = batchData;
            });
          },
        );
      case 27:
        return DetailAngkatanPage(
          data: _activeBatchData ?? {},
          userRole: _userRole,
          studentNis: widget.studentNis,
          onNavigate: (index, {student}) {
            setState(() {
              _selectedIndex = index;
              if (student != null) {
                _activeStudentData = student;
                _detailSiswaReturnIndex = 27; 
                _detailSiswaReturnLabel = 'Detail Angkatan';
              }
            });
          },
        );
      case 7:
        return DataSekolahPage(
          isEmbedded: true,
          onNavigate: (index, {schoolData}) {
            setState(() {
              _selectedIndex = index;
              _activeSchoolData = schoolData;
            });
          },
        );
      case 26:
        return EditSekolahPage(
          schoolData: _activeSchoolData ?? {},
          isEmbedded: true,
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );
      case 8:
        return PengaturanPage(
          isEmbedded: true,
          onNavigate: (index) => setState(() {
            if (index == 9) _profileReturnIndex = 8;
            _selectedIndex = index;
          }),
        );
      case 22:
        return VerifikasiAkunPage(
          isEmbedded: true,
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );
      case 23:
        return DaftarAkunPage(
          isEmbedded: true,
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );
      case 24:
        return GantiPasswordPage(
          isEmbedded: true,
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );
      case 9:
        return ProfilPage(
          isEmbedded: true,
          userRole: _userRole,
          studentNis: widget.studentNis,
          studentName: widget.studentName,
          studentClass: widget.studentClass,
          returnIndex: _profileReturnIndex,
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );
      case 18:
        return InputNilaiPage(
          student: _activeStudentData,
          existingAssessments: _activeAssessments,
          initialSemester: _activeSemester,
          userRole: _userRole,
          isEmbedded: true,
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );
      case 12:
        return DataKelasPage(
          isEmbedded: true,
          onNavigate: (index, {classData}) {
            setState(() {
              _selectedIndex = index;
              _activeClassData = classData;
              _detailSiswaReturnIndex = 12; 
              _detailSiswaReturnLabel = 'Data Kelas';
            });
          },
        );
      case 17:
        return DetailKelasPage(
          classData: _activeClassData ?? {},
          isEmbedded: true,
          onNavigate: (index, {student}) {
            setState(() {
              _selectedIndex = index;
              if (student != null) {
                _activeStudentData = student;
                _detailSiswaReturnIndex = 17; 
                _detailSiswaReturnLabel = 'Detail Kelas';
              }
            });
          },
        );
      case 10:
        return TambahSiswaPage(
          isEmbedded: true,
          student: _activeStudentData,
          onBack: () {
            setState(() {
              _selectedIndex = 1;
              _activeStudentData = null;
            });
          },
        );
      case 13:
        return const DownloadPdfPage();
      case 15:
        return DetailSiswaPage(
          student: _activeStudentData,
          userRole: _userRole,
          studentNis: widget.studentNis,
          isEmbedded: true,
          returnIndex: _detailSiswaReturnIndex,
          returnLabel: _detailSiswaReturnLabel,
          onNavigate: (index, {student}) {
            setState(() {
              _selectedIndex = index;
              _activeStudentData = student;
            });
          },
        );
      case 11:
        return TambahGuruPage(
          isEmbedded: true,
          teacher: _activeTeacherData,
          onBack: () {
            setState(() {
              _selectedIndex = 28;
              _activeTeacherData = null;
            });
          },
        );
      case 16:
        return DetailGuruPage(
          teacher: _activeTeacherData,
          userRole: _userRole,
          isEmbedded: true,
          onNavigate: (index, {teacher}) {
            setState(() {
              _selectedIndex = index;
              _activeTeacherData = teacher;
            });
          },
        );
      default:
        return _buildHomeContent(screenWidth, isDesktop, displayName);
    }
  }

  Widget _buildMenuPage() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;
    
    final List<Map<String, dynamic>> menuItems = [
      {'icon': Icons.fact_check_rounded, 'label': 'Absensi', 'index': 5, 'color': const Color(0xFF6366F1)},
      {'icon': Icons.people_rounded, 'label': 'Data Siswa', 'index': 1, 'color': const Color(0xFF10B981)},
      {'icon': Icons.person_rounded, 'label': 'Data Guru', 'index': 28, 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.business_rounded, 'label': 'Data Kelas', 'index': 12, 'color': const Color(0xFF8B5CF6)},
      {'icon': Icons.edit_note_rounded, 'label': 'Penilaian', 'index': 3, 'color': const Color(0xFFEC4899)},
      {'icon': Icons.picture_as_pdf_rounded, 'label': 'E-Rapor PDF', 'index': 13, 'color': const Color(0xFFF43F5E)},
      {'icon': Icons.school_rounded, 'label': 'Data Angkatan', 'index': 6, 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.collections_rounded, 'label': 'Dokumentasi', 'index': 4, 'color': const Color(0xFF06B6D4)},
      {'icon': Icons.account_balance_rounded, 'label': 'Profil Sekolah', 'index': 7, 'color': const Color(0xFF64748B)},
      {'icon': Icons.settings_rounded, 'label': 'Pengaturan', 'index': 8, 'color': const Color(0xFF475569)},
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Menu Aplikasi",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "Akses cepat ke semua modul sistem",
                  style: TextStyle(fontSize: 14, color: textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 3 : 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return _buildMenuCard(
                  item['icon'],
                  item['label'],
                  item['index'],
                  item['color'],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(IconData icon, String label, int index, Color color) {
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent(double screenWidth, bool isDesktop, String name) {
    bool isMobile = screenWidth < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroSection(name, isDesktop),
          const SizedBox(height: 32),
          _buildChartSection(isMobile),
          const SizedBox(height: 24),
          _buildStatisticsSection(isDesktop),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(bool isDesktop) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primaryTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.campaign_rounded, color: primaryTeal, size: 18),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _RunningTextTicker(
              text: "✨ Selamat Datang di Sistem E-Rapor Digital TK-IT AL-HANIF LEDENG ✨ Mewujudkan Generasi Cerdas, Kreatif, dan Berakhlak Mulia",
              style: TextStyle(
                fontSize: isMobile ? 13 : 14, 
                fontWeight: FontWeight.bold, 
                color: textDark,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildChartSection(bool isMobile) {
    double maxVal = [
      _totalSiswa.toDouble(), 
      _totalGuru.toDouble(), 
      _totalKelas.toDouble(), 
      _totalDokumentasi.toDouble()
    ].reduce((a, b) => a > b ? a : b);
    
    if (maxVal < 10) maxVal = 10;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: Colors.white, // Ganti ke putih agar shadow menonjol
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 25,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Visualisasi Data", 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -0.5)
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Perbandingan ringkasan statistik",
                    style: TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_graph_rounded, color: primaryTeal, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal + (maxVal * 0.25), 
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary,
                    tooltipRoundedRadius: 10,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        rod.toY.round().toString(),
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w800, fontSize: 11);
                        String label = '';
                        switch (value.toInt()) {
                          case 0: label = 'Siswa'; break;
                          case 1: label = 'Guru'; break;
                          case 2: label = 'Kelas'; break;
                          case 3: label = 'Dok'; break;
                        }
                        return SideTitleWidget(meta: meta, space: 12, child: Text(label, style: style));
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBarGroup(0, _totalSiswa.toDouble(), const Color(0xFF10B981), const Color(0xFF34D399), maxVal),
                  _makeBarGroup(1, _totalGuru.toDouble(), const Color(0xFF3B82F6), const Color(0xFF60A5FA), maxVal),
                  _makeBarGroup(2, _totalKelas.toDouble(), const Color(0xFFA855F7), const Color(0xFFC084FC), maxVal),
                  _makeBarGroup(3, _totalDokumentasi.toDouble(), const Color(0xFFF59E0B), const Color(0xFFFBBF24), maxVal),
                ],
              ),
              duration: const Duration(milliseconds: 800), // Animasi mantul
              curve: Curves.elasticOut,
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color1, Color color2, double maxVal) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 20,
          borderRadius: BorderRadius.circular(10), // Bentuk kapsul sempurna
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: maxVal + (maxVal * 0.2), 
            color: const Color(0xFFE0E7FF), // Jalur Indigo Soft yang serasi
          ),
        ),
      ],
    );
  }


  Widget _buildHeroSection(String name, bool isDesktop) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
          stops: const [0.0, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF10B981).withValues(alpha: 0.1),
              ),
            ),
          ),
          
          Positioned(
            bottom: isDesktop ? -48 : (isMobile ? -36 : -42),
            right: isDesktop ? -30 : (isMobile ? -50 : -40),
            child: Opacity(
              opacity: 0.9,
              child: Image.asset(
                'assets/tk-it.png',
                height: isDesktop ? 280 : (isMobile ? 180 : 240),
                fit: BoxFit.contain,
              ),
            ),
          ),
          
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24, 
              vertical: isMobile ? 16 : 28
            ),
            child: Row(
              children: [
                Expanded(
                  flex: isDesktop ? 3 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Assalamu\'alaikum, $name',
                              style: const TextStyle(
                                fontSize: 10, 
                                fontWeight: FontWeight.w800, 
                                color: AppColors.heroText,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('👋', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isMobile ? 'E-Rapor Digital' : 'E-Rapor $_schoolName',
                        style: TextStyle(
                          fontSize: isDesktop ? 22 : 18, 
                          fontWeight: FontWeight.w900, 
                          color: AppColors.heroText, 
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kelola data akademik dengan efisien.',
                        style: TextStyle(
                          fontSize: 12, 
                          color: AppColors.heroText.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _heroInfoCard(
                            Icons.access_time_filled_rounded, 
                            DateFormat('HH:mm', 'id_ID').format(_currentTime), 
                            'Waktu', 
                            const Color(0xFF0EA5E9)
                          ),
                          const SizedBox(width: 12),
                          _heroInfoCard(
                            Icons.calendar_month_rounded, 
                            isMobile ? DateFormat('d MMM yy', 'id_ID').format(_currentTime) : DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_currentTime), 
                            'Tanggal', 
                            const Color(0xFF10B981)
                          ),
                        ],
                      ),
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

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomNavItem(Icons.home_rounded, 'Home', 0),
              _bottomNavItem(Icons.people_rounded, 'Siswa', 1),
              const SizedBox(width: 60), // Space for the standout Menu button
              _bottomNavItem(Icons.edit_note_rounded, 'Nilai', 3),
              _bottomNavItem(Icons.camera_alt_rounded, 'Dok', 4),
            ],
          ),
          Positioned(
            top: -20,
            child: _buildStandoutNavItem(Icons.grid_view_rounded, 'Menu', 2),
          ),
        ],
      ),
    );
  }

  Widget _buildStandoutNavItem(IconData icon, String label, int index) {
    bool active = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _handleRestrictedAccess(label, index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: active ? primaryTeal : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryTeal.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(
                color: active ? Colors.white : primaryTeal.withValues(alpha: 0.1),
                width: 3,
              ),
            ),
            child: Icon(
              icon,
              color: active ? Colors.white : primaryTeal,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? primaryTeal : textSecondary,
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, String label, int index) {
    bool active = _selectedIndex == index;
    return InkWell(
      onTap: () => _handleRestrictedAccess(label, index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? primaryTeal : textSecondary, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: active ? primaryTeal : textSecondary, fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _heroInfoCard(IconData icon, String value, String label, Color color) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: isMobile ? 16 : 20),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: isMobile ? 12 : 14, color: textDark),
              ),
              Text(
                label,
                style: TextStyle(fontSize: isMobile ? 9 : 10, color: textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RunningTextTicker extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _RunningTextTicker({required this.text, required this.style});

  @override
  State<_RunningTextTicker> createState() => _RunningTextTickerState();
}

class _RunningTextTickerState extends State<_RunningTextTicker> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    // Loop terus selama widget masih nampil
    while (mounted) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.offset;
        
        if (maxScroll > 0) {
          // Hitung durasi berdasarkan jarak sisa agar kecepatan stabil (sekitar 50px/detik)
          double remainingDistance = maxScroll - currentScroll;
          int durationInMs = (remainingDistance / 50 * 1000).toInt();

          if (durationInMs > 0) {
            await _scrollController.animateTo(
              maxScroll,
              duration: Duration(milliseconds: durationInMs),
              curve: Curves.linear, // Gerakan datar tanpa guncangan
            );
          }
        }
        
        // Balik ke awal tanpa animasi (instant) lalu ulang lagi
        if (mounted) {
          _scrollController.jumpTo(0);
        }
      }
      // Kasih nafas dikit sebelum loop selanjutnya
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style),
          Text(widget.text, style: widget.style),
        ],
      ),
    );
  }
}
