import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'input_nilai_page.dart';

class PenilaianPage extends StatefulWidget {
  final String? userRole;
  final String? studentNis;
  final bool isEmbedded;
  final Function(int, {dynamic student, List<dynamic>? assessments, int? semester})? onNavigate;

  const PenilaianPage({
    super.key, 
    this.userRole, 
    this.studentNis, 
    this.isEmbedded = false,
    this.onNavigate,
  });

  @override
  State<PenilaianPage> createState() => _PenilaianPageState();
}

class _PenilaianPageState extends State<PenilaianPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _students = [];
  List<dynamic> _filteredStudents = [];
  String _selectedAngkatan = 'Semua';
  String _selectedClass = 'Semua';
  String _selectedRombel = 'Semua';
  bool _showFilters = true;
  final TextEditingController _searchController = TextEditingController();

  bool get _isMobile => MediaQuery.of(context).size.width < 900;

  // --- Clean Palette based on Image ---
  final Color primaryGreen = const Color(0xFF0D9488);
  final Color darkNavy = const Color(0xFF1E1B4B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color bgLight = AppColors.backgroundColor;
  
  final Color colorBSB = const Color(0xFF10B981); // Emerald
  final Color colorBSH = const Color(0xFF3B82F6); // Blue
  final Color colorMB = const Color(0xFFF59E0B);  // Amber

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      List<dynamic> response;
      List<dynamic> assessmentsResponse;
      if (widget.userRole == 'User' && widget.studentNis != null) {
        // Siswa: data sendiri via RPC (direct select ditolak RLS).
        response = await supabase.rpc('get_my_profile', params: {'p_nis': widget.studentNis!});
        assessmentsResponse = await supabase.rpc('get_my_rapor', params: {'p_nis': widget.studentNis!});
      } else {
        response = await supabase.from('students').select().order('name', ascending: true);

        // Fetch assessment counts to determine completion status
        assessmentsResponse = await supabase
            .from('assessments')
            .select('student_id, semester');
      }
      
      Map<String, Map<int, int>> completionMap = {};
      for (var a in assessmentsResponse) {
        String sid = a['student_id'].toString();
        int sem = a['semester'] is int ? a['semester'] : int.tryParse(a['semester'].toString()) ?? 1;
        completionMap.putIfAbsent(sid, () => {});
        completionMap[sid]![sem] = (completionMap[sid]![sem] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _students = response.map((s) {
            String sid = s['id'].toString();
            // Total categories is 19 based on InputNilaiPage
            s['sem1_count'] = completionMap[sid]?[1] ?? 0;
            s['sem2_count'] = completionMap[sid]?[2] ?? 0;
            return s;
          }).toList();
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _students.where((s) {
        final name = (s['name'] ?? '').toLowerCase();
        final nis = (s['nis'] ?? '').toString();
        final angkatan = (s['batch'] ?? s['angkatan'] ?? '').toString();
        final studentClass = (s['class'] ?? '').toString().toLowerCase();
        
        bool matchesSearch = name.contains(query) || 
                            nis.contains(query) || 
                            angkatan.contains(query) ||
                            studentClass.contains(query);
                            
        bool matchesAngkatan = _selectedAngkatan == 'Semua' || angkatan == _selectedAngkatan;
        bool matchesClass = _selectedClass == 'Semua' || (s['class'] ?? '') == _selectedClass;
        bool matchesRombel = _selectedRombel == 'Semua' || (s['rombel'] ?? '') == _selectedRombel;
        
        return matchesSearch && matchesAngkatan && matchesClass && matchesRombel;
      }).toList();
    });
  }

  void _filterSearch(String query) {
    _applyFilters();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                _isMobile ? 16 : 40, 
                _isMobile ? 12 : 24, 
                _isMobile ? 16 : 40, 
                40
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  _buildFilterSection(),
                  const SizedBox(height: 24),
                  _buildFlatTable(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.only(
        top: _isMobile ? 0 : 24, 
        bottom: _isMobile ? 12 : 24
      ),
      child: Row(
        children: [
          Text(
            'Penilaian Rapor',
            style: TextStyle(
              fontSize: _isMobile ? 20 : 26,
              fontWeight: FontWeight.bold,
              color: darkNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    // 1. Dapatkan daftar unik untuk Angkatan (selalu dari semua data)
    final angkatanList = ['Semua', ..._students.map((s) => (s['batch'] ?? s['angkatan'] ?? '').toString()).where((a) => a.isNotEmpty).toSet().toList()..sort()];
    
    // 2. Filter data sementara berdasarkan Angkatan untuk mendapatkan list Kelas yang tersedia
    final tempForClass = _students.where((s) {
      final angkatan = (s['batch'] ?? s['angkatan'] ?? '').toString();
      return _selectedAngkatan == 'Semua' || angkatan == _selectedAngkatan;
    }).toList();
    final classList = ['Semua', ...tempForClass.map((s) => (s['class'] ?? '').toString()).where((c) => c.isNotEmpty).toSet().toList()..sort()];

    // Validasi: Jika kelas terpilih tidak ada di list baru, reset ke Semua
    if (!classList.contains(_selectedClass)) {
      _selectedClass = 'Semua';
    }

    // 3. Filter data sementara berdasarkan Angkatan & Kelas untuk mendapatkan list Rombel yang tersedia
    final tempForRombel = tempForClass.where((s) {
      return _selectedClass == 'Semua' || (s['class'] ?? '') == _selectedClass;
    }).toList();
    final rombelList = ['Semua', ...tempForRombel.map((s) => (s['rombel'] ?? '').toString()).where((r) => r.isNotEmpty).toSet().toList()..sort()];

    // Validasi: Jika rombel terpilih tidak ada di list baru, reset ke Semua
    if (!rombelList.contains(_selectedRombel)) {
      _selectedRombel = 'Semua';
    }

    return Container(
      padding: EdgeInsets.all(_isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _filterSearch,
                          decoration: InputDecoration(
                            hintText: _isMobile ? 'Cari...' : 'Cari nama siswa atau NIS...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _outlinedIconBtn(
                _showFilters ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, 
                _isMobile ? '' : (_showFilters ? 'Tutup Filter' : 'Buka Filter'),
                onTap: () => setState(() => _showFilters = !_showFilters),
              ),
            ],
          ),
          if (_showFilters) ...[
            const SizedBox(height: 16),
            if (_isMobile)
              Column(
                children: [
                  Row(
                    children: [
                      _dropdownFilter(angkatanList, _selectedAngkatan, 'Angkatan', (v) {
                        setState(() => _selectedAngkatan = v!);
                        _applyFilters();
                      }),
                      const SizedBox(width: 8),
                      _dropdownFilter(classList, _selectedClass, 'Kelas', (v) {
                        setState(() => _selectedClass = v!);
                        _applyFilters();
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _dropdownFilter(rombelList, _selectedRombel, 'Rombel', (v) {
                        setState(() => _selectedRombel = v!);
                        _applyFilters();
                      }),
                      const Spacer(),
                    ],
                  ),
                ],
              )
            else
              Row(
                children: [
                  _dropdownFilter(angkatanList, _selectedAngkatan, 'Angkatan', (v) {
                    setState(() => _selectedAngkatan = v!);
                    _applyFilters();
                  }),
                  const SizedBox(width: 12),
                  _dropdownFilter(classList, _selectedClass, 'Kelas', (v) {
                    setState(() => _selectedClass = v!);
                    _applyFilters();
                  }),
                  const SizedBox(width: 12),
                  _dropdownFilter(rombelList, _selectedRombel, 'Rombel', (v) {
                    setState(() => _selectedRombel = v!);
                    _applyFilters();
                  }),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _outlinedIconBtn(IconData icon, String label, {VoidCallback? onTap}) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: Colors.grey.shade100),
        backgroundColor: AppColors.backgroundColor,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: darkNavy),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: darkNavy, fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }

  Widget _dropdownFilter(List<String> items, String selectedValue, String type, ValueChanged<String?> onChanged) {
    return Expanded(
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedValue,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF94A3B8)),
            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
            items: items.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value == 'Semua' ? 'Semua $type' : (type == 'Angkatan' ? 'Angkatan $value' : (type == 'Rombel' ? 'Rombel $value' : 'Kelas $value'))),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }


  Widget _buildFlatTable() {
    if (_filteredStudents.isEmpty) return _buildEmptyState();

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredStudents.length,
          itemBuilder: (context, index) {
            return _flatStudentRow(_filteredStudents[index]);
          },
        ),
      ],
    );
  }

  Widget _flatStudentRow(dynamic student) {
    const int totalCategories = 19;
    int s1 = student['sem1_count'] ?? 0;
    int s2 = student['sem2_count'] ?? 0;
    
    // Student is "Done" if either semester 1 OR semester 2 is fully filled
    bool isDone = s1 >= totalCategories || s2 >= totalCategories;
    double prog = (s1 > s2 ? s1 : s2) / totalCategories;
    if (prog > 1.0) prog = 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
        border: Border.all(color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {}, 
            child: Padding(
              padding: EdgeInsets.all(_isMobile ? 16 : 14),
              child: Row(
                children: [
                  // --- AVATAR & NAME (Primary Info) ---
                  Expanded(
                    child: PopupMenuButton<int>(
                      tooltip: 'Pilih Semester',
                      offset: const Offset(0, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onSelected: (semester) => _handleSemesterSelection(student, semester),
                      itemBuilder: (context) => [
                        _buildSemesterItem(1, Icons.looks_one_rounded, 'Semester 1', isFilled: s1 > 0),
                        _buildSemesterItem(2, Icons.looks_two_rounded, 'Semester 2', isFilled: s2 > 0),
                      ],
                      child: Row(
                        children: [
                          Container(
                            width: _isMobile ? 48 : 50,
                            height: _isMobile ? 48 : 50,
                            decoration: BoxDecoration(
                              color: primaryGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                student['name']?[0]?.toUpperCase() ?? 'S',
                                style: TextStyle(color: primaryGreen, fontWeight: FontWeight.w900, fontSize: _isMobile ? 18 : 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student['name'] ?? '-',
                                  style: TextStyle(
                                    fontSize: _isMobile ? 15 : 16, 
                                    fontWeight: FontWeight.w800, 
                                    color: darkNavy,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: bgLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${student['class'] ?? '-'}',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: Container(width: 3, height: 3, decoration: BoxDecoration(color: textMuted, shape: BoxShape.circle)),
                                    ),
                                    Text(
                                      '${student['batch'] ?? student['angkatan'] ?? '-'}',
                                      style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                if (_isMobile) ...[
                                  const SizedBox(height: 8),
                                  _statusBadge(isDone),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- STATUS & ACTIONS ---
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isMobile) ...[
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 150,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${(prog * 100).toInt()}% Selesai', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textSecondary)),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: prog, 
                                  backgroundColor: const Color(0xFFF1F5F9), 
                                  color: isDone ? colorBSB : primaryGreen, 
                                  minHeight: 4
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        _statusBadge(isDone),
                      ],
                      const SizedBox(width: 12),
                      // Edit Button
                      _actionIcon(
                        icon: Icons.edit_note_rounded,
                        color: primaryGreen,
                        onTap: () {}, // Handled by PopupMenu wrapper or custom logic
                        isMenu: true,
                        student: student,
                        s1: s1 > 0,
                        s2: s2 > 0,
                      ),
                      const SizedBox(width: 4),
                      // More Button
                      IconButton(
                        onPressed: () => _showActionSheet(student), 
                        icon: Icon(Icons.more_vert_rounded, color: textMuted, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionIcon({required IconData icon, required Color color, required VoidCallback onTap, bool isMenu = false, dynamic student, bool s1 = false, bool s2 = false}) {
    if (isMenu) {
      return PopupMenuButton<int>(
        tooltip: 'Pilih Semester',
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (semester) => _handleSemesterSelection(student, semester),
        itemBuilder: (context) => [
          _buildSemesterItem(1, Icons.looks_one_rounded, 'Semester 1', isFilled: s1),
          _buildSemesterItem(2, Icons.looks_two_rounded, 'Semester 2', isFilled: s2),
        ],
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _statusBadge(bool isDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDone ? colorBSB.withValues(alpha: 0.1) : colorMB.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isDone ? 'LENGKAP' : 'PROSES',
        style: TextStyle(
          fontSize: 9, 
          fontWeight: FontWeight.w900, 
          color: isDone ? colorBSB : colorMB.withValues(alpha: 0.9),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showActionSheet(dynamic student) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
              title: const Text('Hapus Seluruh Rapor Siswa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              subtitle: const Text('Menghapus semua penilaian (Smtr 1 & 2)'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(student, null);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.orange),
              title: const Text('Hapus Semester 1'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(student, 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.blue),
              title: const Text('Hapus Semester 2'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(student, 2);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(dynamic student, int? semester) async {
    final name = student['name'] ?? 'Siswa';
    final title = semester == null ? 'Hapus Semua Rapor' : 'Hapus Rapor Semester $semester';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text('Apakah Anda yakin ingin menghapus data penilaian $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);
        var query = supabase.from('assessments').delete().eq('student_id', student['id']);
        if (semester != null) query = query.eq('semester', semester);
        
        await query;
        await _fetchData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil dihapus')));
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
        }
      }
    }
  }

  PopupMenuItem<int> _buildSemesterItem(int value, IconData icon, String label, {bool isFilled = false}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: isFilled ? primaryGreen : textMuted, size: 18),
          const SizedBox(width: 12),
          Text(
            label, 
            style: TextStyle(
              fontSize: 13, 
              fontWeight: FontWeight.bold,
              color: isFilled ? primaryGreen : darkNavy,
            )
          ),
          if (isFilled) ...[
            const Spacer(),
            Icon(Icons.check_circle_rounded, color: primaryGreen, size: 14),
          ],
        ],
      ),
    );
  }

  Future<void> _handleSemesterSelection(dynamic student, int semester) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final assessments = await supabase
          .from('assessments')
          .select()
          .eq('student_id', student['id'])
          .eq('semester', semester);

      if (mounted) {
        Navigator.pop(context); // Tutup loading
        
        if (widget.isEmbedded && widget.onNavigate != null) {
          widget.onNavigate!(18, student: student, assessments: assessments, semester: semester);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InputNilaiPage(
                student: student,
                existingAssessments: assessments,
                initialSemester: semester,
                userRole: widget.userRole,
              ),
            ),
          ).then((_) => _fetchData());
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Error: $e');
    }
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(80),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: textMuted),
          const SizedBox(height: 16),
          Text('Siswa tidak ditemukan', style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
