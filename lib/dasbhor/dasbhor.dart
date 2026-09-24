import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laporsekolaherapor/services/api_service.dart';
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
  
  // --- Color Palette (Warm Monochrome) ---
  final Color primaryDark = AppColors.primary;
  final Color secondaryGray = AppColors.secondary;
  final Color accentWarm = AppColors.accent;
  final Color backgroundColor = AppColors.backgroundColor;
  final Color sidebarBg = AppColors.cardWhite;
  final Color textDark = AppColors.textDark;
  final Color textSecondary = AppColors.textSecondary;
  final Color textMuted = AppColors.textMuted;
  
  final apiService = ApiService();
  
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
  String _userDisplayName = '';
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    // Role selalu ditentukan dari hasil login/splash (role DB), bukan dari email.
    _userRole = widget.initialRole ?? 'User';
    _fetchStats();
    _fetchSchoolInfo(); 
    _setupProfileListener();
    
    // Poll data every 30 seconds instead of realtime streams
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _fetchStats();
        _fetchSchoolInfo();
      }
    });
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
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSchoolInfo() async {
    try {
      final List<dynamic> dataList = await apiService.getTable('school_data');
      final data = dataList.isNotEmpty ? dataList.first : null;
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

  Future<void> _setupProfileListener() async {
    // Initial value
    setState(() {
      _userDisplayName = widget.studentName ?? (_userRole == 'Admin' ? 'Admin' : 'User');
    });

    final prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('jwt_token') ?? '';
    
    if (token.isNotEmpty && (_userRole == 'Admin' || _userRole == 'Guru')) {
      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['id'];
      
      try {
        final profileData = await apiService.getRow('profiles', userId);
        if (mounted && profileData.isNotEmpty) {
          setState(() {
            _userDisplayName = profileData['full_name'] ?? (_userRole == 'Admin' ? 'Admin' : 'Guru');
          });
        }
      } catch (e) {
        debugPrint('Profile error: $e');
      }
    } else if (widget.studentNis != null) {
      try {
        final List<dynamic> studentDataList = await apiService.getTable('students');
        final studentData = studentDataList.firstWhere((s) => s['nis'] == widget.studentNis, orElse: () => null);
        if (mounted && studentData != null) {
          setState(() {
            _userDisplayName = studentData['name'] ?? 'Siswa';
          });
        }
      } catch (e) {
        debugPrint('Student error: $e');
      }
    }
  }

  Future<void> _fetchStats() async {
    // Stat siswa/kelas: agregat RPC (staff) — tak ada dump baris siswa ke User.
    try {
      final List<dynamic> stats = await apiService.callRpc('get_student_stats_summary');
      int totalAktif = 0;
      Set<String> uniqueClasses = {};

      for (var item in stats) {
        int total = int.tryParse(item['total_count']?.toString() ?? '0') ?? 0;
        int lulus = int.tryParse(item['lulus_count']?.toString() ?? '0') ?? 0;
        totalAktif += (total - lulus);

        String className = item['class_name']?.toString() ?? '';
        if (className.isNotEmpty) uniqueClasses.add(className);
      }

      if (mounted) {
        setState(() {
          _totalSiswa = totalAktif;
          _totalKelas = uniqueClasses.length;
        });
      }
    } catch (e) {
      debugPrint('Student stats RPC error: $e');
    }

    // 2. Fetch Teachers from Public RPC (kolom non-sensitif saja)
    try {
      final response = await apiService.callRpc('get_public_teachers');
      if (mounted && response != null) {
        setState(() => _totalGuru = (response as List).length);
      }
    } catch (e) {
      debugPrint('Teacher RPC error: $e');
    }

    // 3. Fetch Documentation (RLS: baca publik)
    try {
      final dok = await apiService.getTable('documentation');
      if (mounted) setState(() => _totalDokumentasi = dok.length);
    } catch (e) {
      debugPrint('Documentation fetch error: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
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
                content: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.cardWhite, size: 18),
                    const SizedBox(width: 12),
                    const Text(
                      'Tekan sekali lagi untuk keluar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
            if (isDesktop && !isGalleryMode) _buildSidebar(_userDisplayName),
            Expanded(
              child: Column(
                children: [
                  if (!isGalleryMode)
                    _buildTopBar(_userDisplayName, isDesktop),
                  Expanded(
                    child: _buildCurrentPage(screenWidth, isDesktop, _userDisplayName),
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
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: AppColors.subtleShadow,
      ),
      child: Row(
        children: [
          if (isDesktop)
            IconButton(
              icon: Icon(Icons.menu_rounded, color: textSecondary),
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
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Image.asset('assets/logo_sekolah.png', fit: BoxFit.contain),
                ),
                const SizedBox(width: 10),
                Text(
                  _schoolName.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: textDark,
                    letterSpacing: 0.8,
                  ),
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
    return Icon(Icons.notifications_none_rounded, color: textSecondary, size: isMobile ? 22 : 24);
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
            backgroundColor: AppColors.accent,
            child: Icon(Icons.person_rounded, size: 20, color: textSecondary),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: textSecondary),
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
      curve: Curves.fastOutSlowIn,
      width: width,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: AppColors.borderColor)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: effectivelyCollapsed ? 8 : 20, vertical: 20),
            child: Row(
              mainAxisAlignment: effectivelyCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.brandSofter),
                  ),
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
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: textDark,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _schoolSub,
                          style: TextStyle(
                            fontSize: 9,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  if (_userRole != 'User') _sidebarItem(Icons.edit_note_outlined, 'Penilaian', 3, isCollapsedOverride: effectivelyCollapsed),
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
            Opacity(
              opacity: 0.9,
              child: Image.asset(
                'assets/tk-it.png',
                height: 100,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
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
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Material(
            color: isParentActive ? AppColors.brandSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
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
              hoverColor: AppColors.brandSofter.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12, vertical: 12),
                child: Row(
                  mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    Icon(
                      icon,
                      color: isParentActive ? AppColors.brand : textSecondary,
                      size: 20
                    ),
                    if (!collapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isParentActive ? AppColors.brand : textSecondary,
                            fontWeight: isParentActive ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (hasDropdown)
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: isParentActive ? AppColors.brand : textSecondary,
                          size: 16
                        ),
                    ],
                  ],
                ),
              ),
            ),
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
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!collapsed)
            Expanded(
              child: Text(
                '© $_academicYear $_schoolName',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8,
                  color: textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          if (MediaQuery.of(context).size.width > 1100) 
            InkWell(
              onTap: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Icon(
                  collapsed ? Icons.chevron_right : Icons.chevron_left,
                  size: 16,
                  color: textSecondary,
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
          userRole: _userRole,
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
          userRole: _userRole,
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
          userRole: _userRole,
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
          studentNis: widget.studentNis,
          studentClass: widget.studentClass,
          userRole: _userRole,
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
          userRole: _userRole,
          studentNis: widget.studentNis,
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
        return DownloadPdfPage(
          studentNis: widget.studentNis,
          userRole: _userRole,
        );
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
      {'icon': Icons.fact_check_rounded, 'label': 'Absensi', 'index': 5, 'color': AppColors.paleBlue},
      {'icon': Icons.people_rounded, 'label': 'Data Siswa', 'index': 1, 'color': AppColors.paleGreen},
      {'icon': Icons.person_rounded, 'label': 'Data Guru', 'index': 28, 'color': AppColors.paleYellow},
      {'icon': Icons.business_rounded, 'label': 'Data Kelas', 'index': 12, 'color': AppColors.paleRed},
      if (_userRole != 'User') {'icon': Icons.edit_note_rounded, 'label': 'Penilaian', 'index': 3, 'color': AppColors.paleBlue},
      {'icon': Icons.picture_as_pdf_rounded, 'label': 'E-Rapor PDF', 'index': 13, 'color': AppColors.paleGreen},
      {'icon': Icons.school_rounded, 'label': 'Data Angkatan', 'index': 6, 'color': AppColors.paleYellow},
      {'icon': Icons.collections_rounded, 'label': 'Dokumentasi', 'index': 4, 'color': AppColors.paleRed},
      {'icon': Icons.account_balance_rounded, 'label': 'Profil Sekolah', 'index': 7, 'color': AppColors.accent},
      {'icon': Icons.settings_rounded, 'label': 'Pengaturan', 'index': 8, 'color': AppColors.accent},
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

  Widget _buildMenuCard(IconData icon, String label, int index, Color accentBg) {
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: textSecondary, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textDark,
                letterSpacing: 0.1,
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
          const SizedBox(height: 24),
          _buildStatisticsSection(isDesktop),
          const SizedBox(height: 24),
          _buildChartSection(isMobile),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(bool isDesktop) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    // Baris kartu statistik ala reference: angka besar + tile ikon semantic.
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isMobile ? 1.7 : 2.4,
      ),
      children: [
        _buildStatCard(Icons.groups_2_outlined, 'Total Siswa', _totalSiswa, AppColors.paleBlue, AppColors.paleBlueText,
            onTap: () => _handleRestrictedAccess('Data Siswa', 1)),
        _buildStatCard(Icons.badge_outlined, 'Total Guru', _totalGuru, AppColors.paleGreen, AppColors.paleGreenText,
            onTap: () => _handleRestrictedAccess('Data Guru', 28)),
        _buildStatCard(Icons.meeting_room_outlined, 'Total Kelas', _totalKelas, AppColors.paleYellow, AppColors.paleYellowText,
            onTap: () => _handleRestrictedAccess('Data Kelas', 12)),
        _buildStatCard(Icons.collections_outlined, 'Dokumentasi', _totalDokumentasi, AppColors.paleRed, AppColors.paleRedText,
            onTap: () => _handleRestrictedAccess('Dokumentasi', 4)),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, int value, Color bg, Color fg, {required VoidCallback onTap}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: bg.withValues(alpha: 0.5),
        child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: fg, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$value',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                    letterSpacing: -0.5,
                  ),
                ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
  );
  }

  bool get isSmallScreen => MediaQuery.of(context).size.width < 600;


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
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                      letterSpacing: -0.3,
                    )
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Perbandingan ringkasan statistik",
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_graph_rounded, color: AppColors.brand, size: 16),
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
                    tooltipRoundedRadius: 4,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        rod.toY.round().toString(),
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
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
                        final style = TextStyle(
                          color: textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          letterSpacing: 0.3,
                        );
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
                  _makeBarGroup(0, _totalSiswa.toDouble(), AppColors.chartGreen, maxVal),
                  _makeBarGroup(1, _totalGuru.toDouble(), AppColors.chartBlue, maxVal),
                  _makeBarGroup(2, _totalKelas.toDouble(), AppColors.chartGray, maxVal),
                  _makeBarGroup(3, _totalDokumentasi.toDouble(), AppColors.chartAmber, maxVal),
                ],
              ),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color, double maxVal) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 24,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: maxVal + (maxVal * 0.2),
            color: AppColors.accent,
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
        color: AppColors.heroBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: isDesktop ? -48 : (isMobile ? -36 : -42),
            right: isDesktop ? -30 : (isMobile ? -50 : -40),
            child: Opacity(
              opacity: 0.15,
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: Text(
                          'Assalamu\'alaikum, $name',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.heroText,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isMobile ? 'E-Rapor Digital' : 'E-Rapor $_schoolName',
                        style: TextStyle(
                          fontSize: isDesktop ? 20 : 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heroText,
                          height: 1.2,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Kelola data akademik dengan efisien',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.heroText.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
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
                            AppColors.paleBlue
                          ),
                          const SizedBox(width: 12),
                          _heroInfoCard(
                            Icons.calendar_month_rounded,
                            isMobile ? DateFormat('d MMM yy', 'id_ID').format(_currentTime) : DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_currentTime),
                            'Tanggal',
                            AppColors.paleGreen
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isMobile && _userRole != 'User')
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleRestrictedAccess('Tambah Siswa', 10),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                        label: const Text('Tambah Siswa'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
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
        color: AppColors.cardWhite,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
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
              if (_userRole == 'User') _bottomNavItem(Icons.fact_check_rounded, 'Absen', 5),
              if (_userRole != 'User') _bottomNavItem(Icons.edit_note_rounded, 'Nilai', 3),
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
              color: active ? primaryDark : AppColors.cardWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? primaryDark : AppColors.borderColor,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: active ? AppColors.cardWhite : textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? primaryDark : textSecondary,
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
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
          Icon(icon, color: active ? primaryDark : textSecondary, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? primaryDark : textSecondary,
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroInfoCard(IconData icon, String value, String label, Color bgColor) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, color: textSecondary, size: isMobile ? 14 : 16),
          ),
          SizedBox(width: isMobile ? 8 : 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isMobile ? 11 : 13,
                  color: textDark,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 9 : 10,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Teks berjalan (running text) dihapus — diganti baris kartu statistik.
