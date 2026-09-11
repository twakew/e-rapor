import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../datasiwa/detail_siswa.dart';
import '../dataguru/detail_guru.dart';
import '../utils/notification_helper.dart';

class DetailKelasPage extends StatefulWidget {
  final Map<String, dynamic> classData;
  final String? userRole;
  final String? studentNis;
  final bool isEmbedded;
  final Function(int, {Map<String, dynamic>? student})? onNavigate;

  const DetailKelasPage({super.key, required this.classData, this.userRole, this.studentNis, this.isEmbedded = false, this.onNavigate});

  @override
  State<DetailKelasPage> createState() => _DetailKelasPageState();
}

class _DetailKelasPageState extends State<DetailKelasPage> {
  final supabase = Supabase.instance.client;
  bool _loading = true;

  bool get _isMobile => MediaQuery.of(context).size.width < 900;

  List<dynamic> _students = [];
  List<dynamic> _filteredStudents = [];
  Map<String, dynamic>? _teacherData;
  final TextEditingController _searchController = TextEditingController();

  // Stats
  // Realtime Data from Student DB
  double _rataKehadiran = 0;

  final Color primaryBlue = const Color(0xFF1D4ED8);
  final Color darkNavy = const Color(0xFF1E1B4B);
  final Color backgroundColor = AppColors.backgroundColor;
  final Color textDark = const Color(0xFF0F172A);
  final Color textSecondary = const Color(0xFF64748B);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color borderColor = const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      String superClean(dynamic val) {
        if (val == null || val.toString().isEmpty || val.toString() == '-') return '';
        return val.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
      }

      final scClass = superClean(widget.classData['kelas']);
      final scRombel = superClean(widget.classData['rombel']);
      final scBatch = superClean(widget.classData['angkatan']);

      // 1. Fetch Students
      List<dynamic> students = [];
      try {
        if (widget.userRole == 'User') {
          final res = await supabase.rpc('get_my_classmates', params: {'p_nis': widget.studentNis ?? ''});
          List allS = res is List ? res : [];

          // Filter manual dengan toleransi tinggi
          students = allS.where((s) {
            final sClass = superClean(s['class'] ?? s['class_name']);
            final sRombel = superClean(s['rombel'] ?? s['rombel_name']);
            final sBatch = superClean(s['batch'] ?? s['angkatan'] ?? s['batch_name']);
            
            // Cocokkan setidaknya Kelas dan Angkatan (Rombel seringkali null/berbeda format)
            bool match = sClass == scClass && sBatch == scBatch;
            if (scRombel.isNotEmpty) {
              match = match && sRombel == scRombel;
            }
            return match;
          }).toList();
        } else {
          students = await supabase
              .from('students')
              .select()
              .eq('class', widget.classData['kelas'])
              .eq('rombel', widget.classData['rombel'])
              .eq('batch', widget.classData['angkatan'])
              .order('name');
        }
      } catch (e) {
        debugPrint('Students fetch error: $e');
      }

      // 2. Fetch Teacher Data (Wali Kelas)
      Map<String, dynamic>? teacher;
      try {
        List<dynamic> teachersData = [];
        if (widget.userRole == 'User') {
          teachersData = await supabase.rpc('get_public_teachers');
        } else {
          teachersData = await supabase.from('teachers').select();
        }
        
        final List allTeachers = teachersData;
        final scTClass = superClean(widget.classData['kelas']);
        final scTRombel = superClean(widget.classData['rombel']);
        final scTBatch = superClean(widget.classData['angkatan']);

        // TIER 1: Match Everything (Cleaned)
        var matches = allTeachers.where((t) => 
          superClean(t['wali_kelas']) == scTClass && 
          superClean(t['rombel_wali']) == scTRombel && 
          superClean(t['angkatan_wali']) == scTBatch
        ).toList();

        // TIER 2: Match Kelas & Angkatan
        if (matches.isEmpty) {
          matches = allTeachers.where((t) => 
            superClean(t['wali_kelas']) == scTClass && 
            superClean(t['angkatan_wali']) == scTBatch
          ).toList();
        }

        if (matches.isNotEmpty) {
          teacher = matches.first;
        }
      } catch (e) {
        debugPrint('Error fetching teacher: $e');
      }

      // 3. Fetch Realtime Attendance
      List<dynamic> attendance = [];
      try {
        final studentIds = students.map((s) => s['id']).where((id) => id != null).toList();
        if (studentIds.isNotEmpty) {
          final now = DateTime.now();
          final firstDay = DateTime(now.year, now.month, 1).toIso8601String();
          final lastDay = DateTime(now.year, now.month + 1, 0).toIso8601String();
          
          attendance = await supabase
              .from('attendance')
              .select('status')
              .filter('student_id', 'in', studentIds)
              .gte('date', firstDay)
              .lte('date', lastDay);
        }
      } catch (e) {
        debugPrint('Attendance fetch error: $e');
      }

      if (mounted) {
        setState(() {
          _students = students;
          _filteredStudents = students;
          _teacherData = teacher;
          
          if (attendance is List && attendance.isNotEmpty) {
            int totalAtt = attendance.length;
            int hadir = attendance.where((a) => a['status'] == 'Hadir').length;
            _rataKehadiran = (hadir / totalAtt) * 100;
          } else {
            _rataKehadiran = 0.0;
          }

          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching class data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _students.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final nis = (s['nis'] ?? '').toString().toLowerCase();
        final parent = (s['father_name'] ?? s['mother_name'] ?? '').toString().toLowerCase();
        
        return name.contains(query) || nis.contains(query) || parent.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.isEmbedded
          ? const Center(child: CircularProgressIndicator())
          : Scaffold(
              backgroundColor: backgroundColor,
              body: const Center(child: CircularProgressIndicator()),
            );
    }

    Widget content = Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(_isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainInfoCard(),
                if (!_isMobile) ...[
                  const SizedBox(height: 24),
                  _buildStatsRow(),
                ],
                const SizedBox(height: 24),
                _buildStudentListCard(),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return Container(
        color: backgroundColor,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(child: content),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(_isMobile ? 16 : 40, _isMobile ? 48 : 60, _isMobile ? 16 : 40, 24),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Detail Kelas',
            style: TextStyle(
              fontSize: _isMobile ? 24 : 32,
              fontWeight: FontWeight.bold,
              color: darkNavy,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              if (widget.onNavigate != null) {
                widget.onNavigate!(12); // Kembali ke Data Kelas
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
      ),
    );
  }

  Widget _buildMainInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.meeting_room_rounded, color: primaryBlue, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.classData['kelas'], 
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: darkNavy)
                    ),
                    Text(
                      'Angkatan ${widget.classData['angkatan']}', 
                      style: TextStyle(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w500)
                    ),
                  ],
                ),
              ),
              _statusBadge(widget.classData['status']),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _teacherData != null ? () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => DetailGuruPage(
                teacher: _teacherData!, 
                userRole: widget.userRole ?? 'Admin',
              )));
            } : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: primaryBlue.withValues(alpha: 0.1),
                    child: Icon(Icons.person, size: 20, color: primaryBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _teacherData?['name'] ?? widget.classData['wali'] ?? '-', 
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: darkNavy)
                        ),
                        Text(
                          _teacherData != null ? 'Wali Kelas • Klik untuk profil' : 'Wali Kelas belum ditentukan', 
                          style: TextStyle(fontSize: 11, color: textSecondary)
                        ),
                      ],
                    ),
                  ),
                  if (_teacherData != null)
                    Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    if (_isMobile) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: [
          _statCard('Total Siswa', _students.length.toString(), 'Siswa', Icons.groups_rounded, const Color(0xFF0D9488)),
          _statCard('Kehadiran', '${_rataKehadiran.toInt()}%', 'Avg', Icons.calendar_month_rounded, const Color(0xFFF59E0B)),
        ],
      );
    }
    return Row(
      children: [
        _statCard('Total Siswa', _students.length.toString(), 'Siswa', Icons.groups_rounded, const Color(0xFF0D9488)),
        const SizedBox(width: 16),
        _statCard('Kehadiran Bulan Ini', '${_rataKehadiran.toInt()}%', 'Rata-rata', Icons.calendar_month_rounded, const Color(0xFFF59E0B)),
      ],
    );
  }

  Widget _statCard(String label, String value, String unit, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
                    const SizedBox(width: 4),
                    Text(unit, style: TextStyle(fontSize: 12, color: textMuted)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentListCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: _isMobile 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daftar Siswa ${widget.classData['kelas']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari siswa...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      isDense: true,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Daftar Siswa ${widget.classData['kelas']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                  Row(
                    children: [
                      Container(
                        width: 200,
                        height: 40,
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Cari siswa...',
                                  hintStyle: TextStyle(fontSize: 12),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            Icon(Icons.search_rounded, size: 18, color: textMuted),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ),
          _buildStudentMobileList(),
          _buildTablePagination(),
        ],
      ),
    );
  }

  Widget _buildStudentMobileList() {
    if (_filteredStudents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_rounded, size: 48, color: textMuted.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'Tidak ada siswa ditemukan di kelas ini',
                style: TextStyle(color: textSecondary, fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _filteredStudents.map((s) {
          bool isLulus = s['status']?.toString().toLowerCase() == 'lulus';
          
          final bool isAdmin = widget.userRole == 'Admin' || widget.userRole == 'Guru' || widget.userRole == 'Super Admin';
          final bool isOwnProfile = widget.studentNis == s['nis']?.toString();
          final bool canAccess = isAdmin || isOwnProfile;

          return InkWell(
            onTap: () {
              if (!canAccess) {
                NotificationHelper.show(context, 'Hanya bisa melihat profil Anda sendiri', isError: true);
                return;
              }
              
              if (widget.isEmbedded && widget.onNavigate != null) {
                widget.onNavigate!(15, student: s as Map<String, dynamic>);
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => DetailSiswaPage(
                  student: s, 
                  userRole: widget.userRole ?? 'Admin',
                  studentNis: widget.studentNis,
                )));
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLulus ? const Color(0xFFDCFCE7) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                ],
                border: Border.all(color: isLulus ? const Color(0xFFBBF7D0) : Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: primaryBlue.withValues(alpha: 0.1),
                    child: Text(
                      (s['name'] ?? '?').toString().isNotEmpty 
                          ? s['name'].toString()[0].toUpperCase() 
                          : '?',
                      style: TextStyle(
                        color: primaryBlue, 
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['name'] ?? '-',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s['class'] ?? '-'} • ${s['batch'] ?? '-'}',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (canAccess) ...[
                    _actionBtn(Icons.visibility_outlined, const Color(0xFF3B82F6), onTap: () {
                      if (widget.isEmbedded && widget.onNavigate != null) {
                        widget.onNavigate!(15, student: s as Map<String, dynamic>);
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => DetailSiswaPage(
                          student: s, 
                          userRole: widget.userRole ?? 'Admin',
                          studentNis: widget.studentNis,
                        )));
                      }
                    }),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
                  ] else
                    Icon(Icons.lock_outline_rounded, color: textMuted.withValues(alpha: 0.5), size: 18),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTablePagination() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Text('Menampilkan 1 - ${_filteredStudents.length} dari ${_filteredStudents.length} siswa', style: TextStyle(fontSize: 12, color: textSecondary)),
          const Spacer(),
          _pageBtn('<', false, () {}),
          const SizedBox(width: 4),
          _pageBtn('1', true, () {}),
          const SizedBox(width: 4),
          _pageBtn('>', false, () {}),
        ],
      ),
    );
  }

  Widget _pageBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: active ? primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? primaryBlue : Colors.grey.shade200),
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.white : darkNavy)),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    bool isActive = status.toLowerCase() == 'aktif';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isActive ? const Color(0xFF15803D) : textSecondary, 
          fontSize: 10, 
          fontWeight: FontWeight.w600
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

}
