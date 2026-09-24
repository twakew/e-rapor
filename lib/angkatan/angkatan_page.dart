import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../datasiwa/detail_siswa.dart';
import '../utils/notification_helper.dart';

class AngkatanPage extends StatefulWidget {
  final String? studentNis;
  final Function(int, {Map<String, dynamic>? student, Map<String, dynamic>? batchData})? onNavigate;

  const AngkatanPage({super.key, this.studentNis, this.onNavigate});

  @override
  State<AngkatanPage> createState() => _AngkatanPageState();
}

class _AngkatanPageState extends State<AngkatanPage> {
  final apiService = ApiService();
  bool _isLoading = true;

  bool get _isMobile => MediaQuery.of(context).size.width < 900;

  List<Map<String, dynamic>> _angkatanList = [];
  List<Map<String, dynamic>> _filteredAngkatan = [];
  String _searchQuery = '';
  String _userRole = 'User';

  // Project Palette
  final Color primaryTeal = AppColors.primary;
  final Color primaryBlue = AppColors.secondary;
  final Color darkNavy = AppColors.textDark;
  final Color backgroundColor = AppColors.backgroundColor;
  final Color bgLight = AppColors.backgroundColor;
  final Color textDark = AppColors.textDark;
  final Color textSecondary = AppColors.textSecondary;
  final Color textMuted = AppColors.textMuted;
  final Color borderColor = AppColors.borderColor;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _fetchUserRole();
    await _fetchAngkatanData();
  }

  Future<void> _fetchUserRole() async {
    try {
      // Role already passed or fetched from login session, read from prefs
      // If not available, default to 'User'
      if (mounted) setState(() => _userRole = 'Admin'); // default for now, should come from session
    } catch (e) {
      debugPrint('Error fetching role: $e');
      if (mounted) setState(() => _userRole = 'User');
    }
  }

  Future<void> _fetchAngkatanData() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      
      // Use API to get stats; build batch summary from students table
      final allStudents = await apiService.getTable('students');
      Map<String, Map<String, dynamic>> batchMap = {};

      for (var s in allStudents) {
        String batch = s['batch']?.toString().trim() ?? 'Lainnya';
        if (!batchMap.containsKey(batch)) {
          batchMap[batch] = {
            'batch': batch, 'total': 0, 'lulus': 0, 'aktif': 0, 'tkA': 0, 'tkB': 0,
            'students': [],
          };
        }
        batchMap[batch]!['students'].add(s);
        batchMap[batch]!['total'] = (batchMap[batch]!['total'] as int) + 1;
        bool isLulus = s['status']?.toString().toLowerCase() == 'lulus';
        if (isLulus) {
          batchMap[batch]!['lulus'] = (batchMap[batch]!['lulus'] as int) + 1;
        } else {
          batchMap[batch]!['aktif'] = (batchMap[batch]!['aktif'] as int) + 1;
        }
        String className = s['class']?.toString().toUpperCase().trim() ?? '';
        if (className == 'TK A') batchMap[batch]!['tkA'] = (batchMap[batch]!['tkA'] as int) + 1;
        if (className == 'TK B') batchMap[batch]!['tkB'] = (batchMap[batch]!['tkB'] as int) + 1;
      }

      List<Map<String, dynamic>> result = batchMap.values.toList();
      result.sort((a, b) => b['batch'].compareTo(a['batch']));

      if (mounted) {
        setState(() {
          _angkatanList = result;
          _filterAngkatan();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error total di Angkatan: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        NotificationHelper.show(context, 'Gagal memuat data: $e', isError: true);
      }
    }
  }

  void _filterAngkatan() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredAngkatan = _angkatanList;
      } else {
        _filteredAngkatan = _angkatanList
            .where((a) => a['batch'].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryTeal))
        : Column(
            children: [
              _buildHeaderBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: _isMobile ? 16 : 40, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFilterRow(),
                      const SizedBox(height: 32),
                      _buildGridSection(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(_isMobile ? 16 : 40, _isMobile ? 12 : 48, _isMobile ? 16 : 40, _isMobile ? 16 : 24),
      color: Colors.transparent,
      alignment: Alignment.centerLeft,
      child: Text('Data Angkatan', style: TextStyle(fontSize: _isMobile ? 20 : 26, fontWeight: FontWeight.bold, color: textDark)),
    );
  }

  Widget _buildFilterRow() {
    if (_isMobile) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardWhite, 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: borderColor)
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: primaryTeal),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (v) {
                      _searchQuery = v;
                      _filterAngkatan();
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari angkatan...',
                      hintStyle: TextStyle(fontSize: 14, color: textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _statusBadge('Total Angkatan: ${_angkatanList.length}', primaryTeal),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardWhite, 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: borderColor)
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: primaryTeal),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (v) {
                      _searchQuery = v;
                      _filterAngkatan();
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari tahun angkatan (contoh: 2025)',
                      hintStyle: TextStyle(fontSize: 14, color: textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        _statusBadge('Total Angkatan: ${_angkatanList.length}', primaryTeal),
      ],
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildGridSection() {
    if (!_isMobile && _filteredAngkatan.isNotEmpty) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: [
            _buildTableHeader(),
            for (final data in _filteredAngkatan) _buildAngkatanRow(data),
          ],
        ),
      );
    }
    if (_filteredAngkatan.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 100),
            Icon(Icons.school_outlined, size: 80, color: textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Data angkatan tidak ditemukan', style: TextStyle(color: textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1200 ? 4 : (screenWidth > 800 ? 3 : 2);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _isMobile ? 2 : crossAxisCount,
        mainAxisSpacing: _isMobile ? 12 : 24,
        crossAxisSpacing: _isMobile ? 12 : 24,
        mainAxisExtent: _isMobile ? 220 : null,
        childAspectRatio: screenWidth > 600 ? 0.75 : 0.8,
      ),
      itemCount: _filteredAngkatan.length,
      itemBuilder: (context, index) => _buildAngkatanCard(_filteredAngkatan[index]),
    );
  }

  Widget _tableCell(String text, int flex, {bool bold = false, Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color ?? textSecondary,
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: backgroundColor,
      child: Row(
        children: [
          _tableCell('ANGKATAN', 4, bold: true, color: textMuted),
          _tableCell('TOTAL SISWA', 2, bold: true, color: textMuted),
          _tableCell('SISWA AKTIF', 2, bold: true, color: textMuted),
          _tableCell('ALUMNI', 2, bold: true, color: textMuted),
          Expanded(
            flex: 2,
            child: Text(
              '',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textMuted, letterSpacing: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAngkatanRow(Map<String, dynamic> data) {
    final String batch = data['batch'];
    return Material(
      color: AppColors.cardWhite,
      child: InkWell(
        onTap: () => _showAngkatanDetails(data),
        hoverColor: AppColors.brandSoft.withValues(alpha: 0.6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.school_rounded, color: primaryTeal, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Angkatan $batch',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textDark),
                          ),
                          Text(
                            'TK A: ${data['tkA']} • TK B: ${data['tkB']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _tableCell('${data['total']}', 2),
              _tableCell('${data['aktif']}', 2, bold: true, color: primaryTeal),
              _tableCell('${data['lulus']}', 2, bold: true, color: const Color(0xFF059669)),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAngkatanCard(Map<String, dynamic> data) {
    String batch = data['batch'];
    int total = data['total'];
    int lulus = data['lulus'];
    int aktif = data['aktif'];

    return InkWell(
      onTap: () => _showAngkatanDetails(data),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(_isMobile ? 12 : 20), 
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8), 
                  decoration: BoxDecoration(color: primaryTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.school_rounded, color: primaryTeal, size: 18), 
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(batch, style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12), 
            Text('Angkatan $batch', style: TextStyle(fontSize: _isMobile ? 14 : 16, fontWeight: FontWeight.bold, color: textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4), 
            Text('Ringkasan statistik', style: TextStyle(fontSize: 10, color: textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const Spacer(),
            const Divider(height: 16), 
            _statMiniRow('Total Siswa', total.toString(), textDark),
            const SizedBox(height: 4),
            _statMiniRow('Siswa Aktif', aktif.toString(), primaryTeal),
            const SizedBox(height: 4),
            _statMiniRow('Alumni', lulus.toString(), const Color(0xFF059669)),
          ],
        ),
      ),
    );
  }

  Widget _statMiniRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  void _showAngkatanDetails(Map<String, dynamic> data) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(27, batchData: data);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _AngkatanDetailSheet(
          data: data,
          userRole: _userRole,
          studentNis: widget.studentNis,
          onRefresh: _fetchAngkatanData,
          primaryBlue: primaryBlue,
          darkNavy: darkNavy,
          textSecondary: textSecondary,
          borderColor: borderColor,
          bgLight: bgLight,
          onNavigate: widget.onNavigate,
        ),
      );
    }
  }
}

class _AngkatanDetailSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final String userRole;
  final String? studentNis;
  final VoidCallback onRefresh;
  final Color primaryBlue;
  final Color darkNavy;
  final Color textSecondary;
  final Color borderColor;
  final Color bgLight;
  final Function(int, {Map<String, dynamic>? student, Map<String, dynamic>? batchData})? onNavigate;

  const _AngkatanDetailSheet({
    required this.data,
    required this.userRole,
    this.studentNis,
    required this.onRefresh,
    required this.primaryBlue,
    required this.darkNavy,
    required this.textSecondary,
    required this.borderColor,
    required this.bgLight,
    this.onNavigate,
  });

  @override
  State<_AngkatanDetailSheet> createState() => _AngkatanDetailSheetState();
}

class _AngkatanDetailSheetState extends State<_AngkatanDetailSheet> {
  String _selectedFilter = 'Semua';

  @override
  Widget build(BuildContext context) {
    List<dynamic> allStudents = widget.data['students'];
    String batch = widget.data['batch'];

    List<dynamic> filteredStudents = allStudents.where((s) {
      if (_selectedFilter == 'Semua') return true;
      return s['class']?.toString().toUpperCase() == _selectedFilter;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 48, height: 6, decoration: BoxDecoration(color: widget.borderColor, borderRadius: BorderRadius.circular(3))),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: widget.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.groups_rounded, color: widget.primaryBlue),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Daftar Siswa Angkatan $batch', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.darkNavy)),
                          Text('${allStudents.length} Siswa Terdaftar', style: TextStyle(color: widget.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _filterTab('Semua'),
                    const SizedBox(width: 8),
                    _filterTab('TK A'),
                    const SizedBox(width: 8),
                    _filterTab('TK B'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Container(
              color: widget.bgLight,
              child: filteredStudents.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    itemCount: filteredStudents.length,
                    itemBuilder: (context, index) => _buildStudentItem(filteredStudents[index]),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterTab(String label) {
    bool sel = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? const Color(0xFF2563EB) : widget.borderColor),
          boxShadow: sel ? [BoxShadow(color: Color(0xFF2563EB).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: sel ? Colors.white : widget.textSecondary, 
            fontWeight: sel ? FontWeight.bold : FontWeight.w500, 
            fontSize: 13
          )
        ),
      ),
    );
  }

  Widget _buildStudentItem(dynamic student) {
    String name = student['name'] ?? '-';
    String nis = student['nis']?.toString() ?? '-';
    String cls = student['class'] ?? '-';
    String status = student['status'] ?? 'Aktif';

    final bool isAdmin = widget.userRole == 'Admin' || widget.userRole == 'Guru' || widget.userRole == 'Super Admin';
    final bool isOwnProfile = widget.studentNis == nis;
    final bool canSeeNis = isAdmin || isOwnProfile;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (!isAdmin && !isOwnProfile) {
              NotificationHelper.show(context, 'Hanya bisa melihat profil Anda sendiri', isError: true);
              return;
            }
            if (widget.onNavigate != null) {
              Navigator.pop(context);
              widget.onNavigate!(15, student: student);
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (context) => DetailSiswaPage(student: student, userRole: widget.userRole, studentNis: widget.studentNis)));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name[0].toUpperCase(), 
                      style: TextStyle(color: widget.primaryBlue, fontWeight: FontWeight.bold, fontSize: 18)
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toUpperCase(), 
                        style: TextStyle(fontWeight: FontWeight.bold, color: widget.darkNavy, fontSize: 14, letterSpacing: 0.3)
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(cls, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.textSecondary)),
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(fontSize: 10, color: widget.textSecondary)),
                          const SizedBox(width: 8),
                          Text(canSeeNis ? nis : '••••••••', style: TextStyle(fontSize: 12, color: widget.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                _statusChip(status),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: widget.textSecondary.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    bool isLulus = status.toLowerCase() == 'lulus';
    bool isAktif = status.toLowerCase() == 'aktif';
    
    Color textColor = isLulus ? const Color(0xFF3B82F6) : (isAktif ? const Color(0xFF22C55E) : Colors.orange);
    Color bgColor = isLulus ? const Color(0xFFEFF6FF) : (isAktif ? const Color(0xFFF0FDF4) : Colors.orange.withValues(alpha: 0.1));
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor, 
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.1))
      ),
      child: Text(
        status.toUpperCase(), 
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 9)
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 48, color: widget.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('Tidak ada siswa ditemukan', style: TextStyle(color: widget.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
