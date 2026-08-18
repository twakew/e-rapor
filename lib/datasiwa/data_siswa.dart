import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'tambah_siswa.dart';
import 'detail_siswa.dart';
import '../utils/excel_helper.dart';
import '../utils/notification_helper.dart';

class DataSiswaPage extends StatefulWidget {
  final String? studentNis;
  final String? studentClass;
  final bool isEmbedded;
  final String? userName;
  final String? userRole;
  final Function(int, {Map<String, dynamic>? student})? onNavigate;
  const DataSiswaPage({super.key, this.studentNis, this.studentClass, this.isEmbedded = false, this.userName, this.userRole, this.onNavigate});

  @override
  State<DataSiswaPage> createState() => _DataSiswaPageState();
}

class _DataSiswaPageState extends State<DataSiswaPage> {
  // --- Color Palette ---
  final Color primaryTeal = AppColors.primary;
  final Color backgroundColor = AppColors.backgroundColor;
  final Color textDark = AppColors.textDark;
  final Color textSecondary = AppColors.textSecondary;
  final Color textMuted = AppColors.textMuted;

  final supabase = Supabase.instance.client;
  StreamSubscription? _subscription;
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  bool _loading = true;

  // Filter States
  bool _showFilters = true;
  final TextEditingController _searchController = TextEditingController();
  String _selectedBatch = 'Angkatan';
  String _selectedClass = 'Kelas';
  String _selectedRombel = 'Rombel';
  String _selectedStatus = 'Semua Status';

  final List<String> _statuses = ['Semua Status', 'Aktif', 'Lulus', 'Keluar'];

  @override
  void initState() {
    super.initState();
    if (widget.userRole == 'User') {
      _fetchSingleStudentData();
    } else {
      _initRealtime();
    }
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSingleStudentData() async {
    if (widget.studentNis == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final response = await supabase.rpc('get_my_profile', params: {'p_nis': widget.studentNis});
      if (mounted && response != null) {
        setState(() {
          _all = response as List<dynamic>;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching student profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _initRealtime() {
    setState(() => _loading = true);
    // Menggunakan stream untuk mendapatkan data secara realtime
    _subscription = supabase
        .from('students')
        .stream(primaryKey: ['id'])
        .order('name')
        .listen((data) {
      if (mounted) {
        setState(() {
          _all = data;
          _applyFilters(); // Otomatis terapkan filter saat ada data baru
          _loading = false;
        });
      }
    }, onError: (e) {
      debugPrint('Realtime error: $e');
      if (mounted) setState(() => _loading = false);
    });
  }

  void _applyFilters() {
    setState(() {
      _filtered = _all.where((s) {
        final query = _searchController.text.toLowerCase();
        final name = (s['name'] ?? '').toString().toLowerCase();
        final nis = (s['nis'] ?? '').toString().toLowerCase();
        final parent = (s['father_name'] ?? s['mother_name'] ?? '').toString().toLowerCase();
        
        final matchesSearch = name.contains(query) || nis.contains(query) || parent.contains(query);
        final matchesBatch = _selectedBatch == 'Angkatan' || s['batch'] == _selectedBatch;
        final matchesClass = _selectedClass == 'Kelas' || s['class'] == _selectedClass;
        final matchesRombel = _selectedRombel == 'Rombel' || s['rombel'] == _selectedRombel;
        final matchesStatus = _selectedStatus == 'Semua Status' || s['status'] == _selectedStatus;

        return matchesSearch && matchesBatch && matchesClass && matchesRombel && matchesStatus;
      }).toList();
    });
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data'),
        content: Text('Apakah Anda yakin ingin menghapus data siswa ${student['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
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
        await supabase.from('students').delete().eq('id', student['id']);
        if (mounted) NotificationHelper.show(context, 'Data siswa berhasil dihapus');
      } catch (e) {
        if (mounted) NotificationHelper.show(context, 'Gagal menghapus data: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    return Container(
      color: backgroundColor,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, isMobile ? 12 : 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 24),
                  if (widget.userRole != 'User') _buildFilterSection(),
                  if (widget.userRole != 'User') const SizedBox(height: 24),
                  _buildDataTableCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderSection() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Siswa',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.userRole != 'User')
                Expanded(
                  child: _headerButtonMobile(Icons.add_rounded, 'Tambah', onTap: () {
                    if (widget.onNavigate != null) {
                      widget.onNavigate!(10);
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TambahSiswaPage()));
                    }
                  }, isPrimary: true),
                ),
              if (widget.userRole != 'User') const SizedBox(width: 8),
              if (widget.userRole != 'User')
                Expanded(
                  child: _headerButtonMobile(Icons.download_rounded, 'Template', onTap: () async {
                    try {
                      await ExcelHelper.downloadStudentTemplate();
                      if (mounted) NotificationHelper.show(context, 'Template berhasil didownload');
                    } catch (e) {
                      if (mounted) NotificationHelper.show(context, 'Gagal download template: $e', isError: true);
                    }
                  }),
                ),
              if (widget.userRole != 'User') const SizedBox(width: 8),
              if (widget.userRole != 'User')
                Expanded(
                  child: _headerButtonMobile(Icons.upload_rounded, 'Import', onTap: () async {
                    try {
                      int count = await ExcelHelper.importStudentsFromExcel();
                      if (count > 0) {
                        if (mounted) NotificationHelper.show(context, 'Berhasil mengimpor $count data siswa');
                      }
                    } catch (e) {
                      if (mounted) NotificationHelper.show(context, 'Gagal impor data: $e', isError: true);
                    }
                  }),
                ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Data Siswa', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (widget.userRole != 'User')
              _headerButton(Icons.download_outlined, 'Download Template', onTap: () async {
                try {
                  await ExcelHelper.downloadStudentTemplate();
                  if (mounted) NotificationHelper.show(context, 'Template berhasil didownload');
                } catch (e) {
                  if (mounted) NotificationHelper.show(context, 'Gagal download template: $e', isError: true);
                }
              }),
            if (widget.userRole != 'User') const SizedBox(width: 12),
            if (widget.userRole != 'User')
              _headerButton(Icons.upload_outlined, 'Import Excel', onTap: () async {
                try {
                  int count = await ExcelHelper.importStudentsFromExcel();
                  if (count > 0) {
                    if (mounted) NotificationHelper.show(context, 'Berhasil mengimpor $count data siswa');
                  }
                } catch (e) {
                  if (mounted) NotificationHelper.show(context, 'Gagal impor data: $e', isError: true);
                }
              }),
            if (widget.userRole != 'User') const SizedBox(width: 12),
            if (widget.userRole != 'User')
              ElevatedButton.icon(
                onPressed: () {
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(10); // Index for TambahSiswaPage
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TambahSiswaPage()));
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah Siswa', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _headerButton(IconData icon, String label, {VoidCallback? onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: textDark),
      label: Text(label, style: TextStyle(color: textDark, fontWeight: FontWeight.w500)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }

  Widget _headerButtonMobile(IconData icon, String label, {VoidCallback? onTap, bool isPrimary = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isPrimary ? primaryTeal : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isPrimary ? null : Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: isPrimary 
                  ? primaryTeal.withValues(alpha: 0.2) 
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isPrimary ? Colors.white : primaryTeal),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: isPrimary ? Colors.white : textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    // 1. Dapatkan daftar Angkatan (selalu dari semua data)
    final batchesList = ['Angkatan', ..._all.map((s) => s['batch']?.toString()).whereType<String>().toSet().toList()..sort()];
    
    // 2. Filter data sementara berdasarkan Angkatan untuk mendapatkan list Kelas yang tersedia
    final tempForClass = _all.where((s) {
      return _selectedBatch == 'Angkatan' || s['batch'] == _selectedBatch;
    }).toList();
    final classesList = ['Kelas', ...tempForClass.map((s) => s['class']?.toString()).whereType<String>().toSet().toList()..sort()];

    // Validasi: Jika kelas terpilih tidak ada di list baru, reset
    if (!classesList.contains(_selectedClass)) {
      _selectedClass = 'Kelas';
    }

    // 3. Filter data sementara berdasarkan Angkatan & Kelas untuk mendapatkan list Rombel yang tersedia
    final tempForRombel = tempForClass.where((s) {
      return _selectedClass == 'Kelas' || s['class'] == _selectedClass;
    }).toList();
    final rombelList = ['Rombel', ...tempForRombel.map((s) => s['rombel']?.toString()).whereType<String>().toSet().toList()..sort()];

    // Validasi: Jika rombel terpilih tidak ada di list baru, reset
    if (!rombelList.contains(_selectedRombel)) {
      _selectedRombel = 'Rombel';
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
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
                          decoration: InputDecoration(
                            hintText: isMobile ? 'Cari...' : 'Cari nama siswa, NIS, atau nama orang tua...',
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
                isMobile ? '' : (_showFilters ? 'Tutup Filter' : 'Buka Filter'),
                onTap: () => setState(() => _showFilters = !_showFilters),
              ),
            ],
          ),
          if (_showFilters) ...[
            const SizedBox(height: 16),
            if (isMobile)
              Column(
                children: [
                  Row(
                    children: [
                      _dropdownFilter(batchesList, _selectedBatch, (v) {
                        setState(() => _selectedBatch = v!);
                        _applyFilters();
                      }),
                      const SizedBox(width: 8),
                      _dropdownFilter(classesList, _selectedClass, (v) {
                        setState(() => _selectedClass = v!);
                        _applyFilters();
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _dropdownFilter(rombelList, _selectedRombel, (v) {
                        setState(() => _selectedRombel = v!);
                        _applyFilters();
                      }),
                      const SizedBox(width: 8),
                      _dropdownFilter(_statuses, _selectedStatus, (v) {
                        setState(() => _selectedStatus = v!);
                        _applyFilters();
                      }),
                    ],
                  ),
                ],
              )
            else
              Row(
                children: [
                  _dropdownFilter(batchesList, _selectedBatch, (v) {
                    setState(() => _selectedBatch = v!);
                    _applyFilters();
                  }),
                  const SizedBox(width: 12),
                  _dropdownFilter(classesList, _selectedClass, (v) {
                    setState(() => _selectedClass = v!);
                    _applyFilters();
                  }),
                  const SizedBox(width: 12),
                  _dropdownFilter(rombelList, _selectedRombel, (v) {
                    setState(() => _selectedRombel = v!);
                    _applyFilters();
                  }),
                  const SizedBox(width: 12),
                  _dropdownFilter(_statuses, _selectedStatus, (v) {
                    setState(() => _selectedStatus = v!);
                    _applyFilters();
                  }),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _outlinedIconBtn(IconData icon, String label, {bool hasChevron = false, VoidCallback? onTap}) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: Colors.grey.shade100),
        backgroundColor: AppColors.backgroundColor,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textDark),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: textDark, fontWeight: FontWeight.w500)),
          if (hasChevron) ...[
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF94A3B8)),
          ],
        ],
      ),
    );
  }

  Widget _dropdownFilter(List<String> items, String selectedValue, ValueChanged<String?> onChanged) {
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
                child: Text(value),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildDataTableCard() {
    return Column(
      children: [
        ..._filtered.map((s) => _buildStudentMobileCard(s)),
      ],
    );
  }

  Widget _buildStudentMobileCard(Map<String, dynamic> s) {
    bool isLulus = s['status'] == 'Lulus';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isLulus ? const Color(0xFFDCFCE7) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: isLulus ? const Color(0xFFBBF7D0) : Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (widget.onNavigate != null) {
              widget.onNavigate!(15, student: s);
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => DetailSiswaPage(student: s, userRole: widget.userRole ?? 'User')));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: primaryTeal.withValues(alpha: 0.1),
                  child: Text(
                    (s['name'] ?? '?').toString().isNotEmpty 
                        ? s['name'].toString()[0].toUpperCase() 
                        : '?',
                    style: TextStyle(
                      color: primaryTeal, 
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
                if (widget.userRole != 'User')
                  _actionBtn(Icons.edit_outlined, Colors.blue, onTap: () {
                    if (widget.onNavigate != null) {
                      widget.onNavigate!(10, student: s);
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TambahSiswaPage(student: s)));
                    }
                  }),
                if (widget.userRole != 'User') const SizedBox(width: 8),
                if (widget.userRole != 'User')
                  _actionBtn(Icons.delete_outline, Colors.red, onTap: () => _deleteStudent(s)),
                if (widget.userRole != 'User') const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
