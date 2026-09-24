import 'package:flutter/material.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../datasiwa/detail_siswa.dart';
import '../utils/notification_helper.dart';

class DetailAngkatanPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final String userRole;
  final String? studentNis;
  final Function(int, {Map<String, dynamic>? student})? onNavigate;

  const DetailAngkatanPage({
    super.key,
    required this.data,
    required this.userRole,
    this.studentNis,
    this.onNavigate,
  });

  @override
  State<DetailAngkatanPage> createState() => _DetailAngkatanPageState();
}

class _DetailAngkatanPageState extends State<DetailAngkatanPage> {
  String _selectedFilter = 'Semua';
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _allStudents = [];
  List<dynamic> _filteredStudents = [];

  Color get primaryTeal => AppColors.isDark ? AppColors.brand : AppColors.primary;
  final Color primaryBlue = AppColors.secondary;
  final Color darkNavy = AppColors.textDark;
  final Color backgroundColor = AppColors.backgroundColor;
  final Color textDark = AppColors.textDark;
  final Color textSecondary = AppColors.textSecondary;
  final Color textMuted = AppColors.textMuted;
  final Color borderColor = AppColors.borderColor;

  @override
  void initState() {
    super.initState();
    _allStudents = widget.data['students'] ?? [];
    _filteredStudents = _allStudents;
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((s) {
        final matchesFilter = _selectedFilter == 'Semua' || s['class']?.toString().toUpperCase() == _selectedFilter;
        final name = (s['name'] ?? '').toString().toLowerCase();
        final matchesSearch = name.contains(query);
        return matchesFilter && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 900;
    String batch = widget.data['batch'];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isMobile, batch),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow(isMobile),
                    const SizedBox(height: 24),
                    _buildStudentListCard(isMobile, batch),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile, String batch) {
    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 40, isMobile ? 24 : 40, isMobile ? 16 : 40, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Detail Angkatan $batch',
              style: TextStyle(
                fontSize: isMobile ? 22 : 32,
                fontWeight: FontWeight.bold,
                color: darkNavy,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              if (widget.onNavigate != null) {
                widget.onNavigate!(6); // Kembali ke Data Angkatan
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
              backgroundColor: AppColors.cardWhite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    int total = _allStudents.length;
    int aktif = _allStudents.where((s) => s['status']?.toString().toLowerCase() == 'aktif').length;
    int lulus = _allStudents.where((s) => s['status']?.toString().toLowerCase() == 'lulus').length;

    if (isMobile) {
      return Column(
        children: [
          SizedBox(width: double.infinity, child: _statCard('Total Siswa', total.toString(), 'Siswa', Icons.groups_rounded, primaryBlue, isMobile)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard('Aktif', aktif.toString(), 'Siswa', Icons.person_outline, primaryTeal, isMobile)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Lulus', lulus.toString(), 'Alumni', Icons.school_outlined, Colors.green, isMobile)),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: _statCard('Total Siswa', total.toString(), 'Siswa', Icons.groups_rounded, primaryBlue, isMobile)),
        const SizedBox(width: 16),
        Expanded(child: _statCard('Siswa Aktif', aktif.toString(), 'Siswa', Icons.person_outline, primaryTeal, isMobile)),
        const SizedBox(width: 16),
        Expanded(child: _statCard('Alumni Lulus', lulus.toString(), 'Siswa', Icons.school_outlined, Colors.green, isMobile)),
      ],
    );
  }

  Widget _statCard(String label, String value, String unit, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: isMobile ? 18 : 24),
          ),
          SizedBox(width: isMobile ? 8 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label, 
                  style: TextStyle(fontSize: isMobile ? 10 : 12, color: textSecondary, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value, 
                        style: TextStyle(fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.bold, color: textDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit, 
                      style: TextStyle(fontSize: isMobile ? 10 : 12, color: textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentListCard(bool isMobile, String batch) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Daftar Siswa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
                    _statusBadge('${_filteredStudents.length} Siswa'),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari nama siswa...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          filled: true,
                          fillColor: backgroundColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterTab('Semua'),
                      const SizedBox(width: 8),
                      _filterTab('TK A'),
                      const SizedBox(width: 8),
                      _filterTab('TK B'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildStudentList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _filterTab(String label) {
    bool sel = _selectedFilter == label;
    return InkWell(
      onTap: () {
        setState(() => _selectedFilter = label);
        _applyFilters();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? primaryBlue : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? primaryBlue : borderColor),
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: sel ? Colors.white : textSecondary, 
            fontWeight: sel ? FontWeight.bold : FontWeight.w500, 
            fontSize: 13
          )
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    if (_filteredStudents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.person_off_outlined, size: 48, color: textMuted),
              const SizedBox(height: 12),
              Text('Tidak ada siswa ditemukan', style: TextStyle(color: textSecondary)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) => _buildStudentItem(_filteredStudents[index]),
    );
  }

  Widget _buildStudentItem(dynamic student) {
    String name = student['name'] ?? '-';
    String nis = student['nis']?.toString() ?? '-';
    String cls = student['class'] ?? '-';
    String status = student['status'] ?? 'Aktif';
    bool isLulus = status.toLowerCase() == 'lulus';

    final bool isAdmin = widget.userRole == 'Admin' || widget.userRole == 'Guru' || widget.userRole == 'Super Admin';
    final bool isOwnProfile = widget.studentNis == nis;
    final bool canAccess = isAdmin || isOwnProfile;

    return InkWell(
      onTap: () {
        if (!canAccess) {
          NotificationHelper.show(context, 'Hanya bisa melihat profil Anda sendiri', isError: true);
          return;
        }
        if (widget.onNavigate != null) {
          widget.onNavigate!(15, student: student);
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => DetailSiswaPage(student: student, userRole: widget.userRole, studentNis: widget.studentNis)));
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isLulus ? AppColors.paleGreen : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isLulus ? const Color(0xFFBBF7D0) : borderColor.withValues(alpha: 0.5)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: primaryBlue.withValues(alpha: 0.1),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$cls • ${canAccess ? nis : '••••••••'}',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            if (canAccess) ...[
              _actionBtn(Icons.visibility_outlined, const Color(0xFF3B82F6), onTap: () {
                if (widget.onNavigate != null) {
                  widget.onNavigate!(15, student: student);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => DetailSiswaPage(student: student, userRole: widget.userRole, studentNis: widget.studentNis)));
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



  Widget _statusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: primaryTeal, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
