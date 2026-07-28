import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'detail_kelas_page.dart';
import '../dataguru/detail_guru.dart';

class DataKelasPage extends StatefulWidget {
  final String? studentNis;
  final String? studentClass;
  final bool isEmbedded;
  final Function(int, {Map<String, dynamic>? classData})? onNavigate;

  const DataKelasPage({super.key, this.studentNis, this.studentClass, this.isEmbedded = false, this.onNavigate});

  @override
  State<DataKelasPage> createState() => _DataKelasPageState();
}

class _DataKelasPageState extends State<DataKelasPage> {
  // Colors
  final Color primaryTeal = AppColors.primary;
  final Color backgroundColor = AppColors.backgroundColor;
  final Color textDark = AppColors.textDark;
  final Color textSecondary = AppColors.textSecondary;
  final Color textMuted = AppColors.textMuted;

  final supabase = Supabase.instance.client;
  final List<StreamSubscription> _subscriptions = [];
  bool _loading = true;

  bool get _isMobile => MediaQuery.of(context).size.width < 900;

  // Filter States
  final TextEditingController _searchController = TextEditingController();
  String _selectedBatch = 'Angkatan';
  String _selectedClass = 'Kelas';
  String _selectedRombel = 'Rombel';
  String _selectedStatus = 'Semua Status';

  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];

  List<String> _batches = ['Angkatan'];
  List<String> _classesList = ['Kelas'];
  List<String> _rombelList = ['Rombel'];
  final List<String> _statusList = ['Semua Status', 'Aktif', 'Tidak Aktif'];

  @override
  void initState() {
    super.initState();
    _initRealtime();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _searchController.dispose();
    super.dispose();
  }

  void _initRealtime() {
    _fetchData();
    
    // Gunakan Channel global untuk dengerin SEMUA perubahan data
    final channel = supabase.channel('public:data_kelas_global');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'students',
      callback: (payload) {
        debugPrint('New Class/Student detected: ${payload.eventType}');
        _fetchData(); // Trigger refresh total buat generate kartu baru
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'teachers',
      callback: (payload) {
        debugPrint('Wali Kelas change detected: ${payload.eventType}');
        _fetchData(); // Update nama wali di semua kartu
      },
    ).subscribe();
  }

  Future<void> _fetchData() async {
    try {
      if (!mounted) return;

      // 1. Ambil semua data siswa
      final studentsResponse = await supabase.from('students').select('class, rombel, batch, status, gender');
      final List<dynamic> studentsData = studentsResponse as List;
      
      // 2. Ambil data guru (Wali Kelas)
      List<dynamic> teachersData = [];
      try {
        final res = await supabase.from('teachers').select();
        teachersData = res as List;
      } catch (e) {
        debugPrint('Teachers table fetch failed: $e');
      }

      if (!mounted) return;

      // Grouping siswa berdasarkan kombinasi Kelas, Rombel, dan Angkatan
      Map<String, List<Map<String, dynamic>>> groupedClasses = {};
      for (var s in studentsData) {
        if (s['class'] == null || s['class'].toString().trim().isEmpty) continue;
        
        String className = s['class'].toString().trim();
        String rombelName = (s['rombel'] == null || s['rombel'].toString().trim().isEmpty) ? '-' : s['rombel'].toString().trim();
        String batchName = (s['batch'] == null || s['batch'].toString().trim().isEmpty) ? '-' : s['batch'].toString().trim();
        
        String key = "$className|$rombelName|$batchName";
        groupedClasses.putIfAbsent(key, () => []).add(s);
      }

      List<Map<String, dynamic>> processedData = [];
      int idx = 1;

      for (var key in groupedClasses.keys) {
        final students = groupedClasses[key]!;
        final parts = key.split('|');
        String className = parts[0];
        String rombelName = parts[1];
        String batchName = parts[2];

        // Normalisasi super bersih buat perbandingan
        String superClean(dynamic val) {
          if (val == null || val.toString().isEmpty || val.toString() == '-') return '';
          return val.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
        }

        String scClass = superClean(className);
        String scRombel = superClean(rombelName);
        String scBatch = superClean(batchName);

        // Cari Wali Kelas yang cocok (Pencarian Ketat: Harus Cocok Kelas, Rombel, dan Angkatan)
        dynamic waliGuru;
        final List allT = teachersData;
        
        // TIER 1: Exact Match (Raw)
        var matches = allT.where((t) {
          return t['wali_kelas']?.toString() == className && 
                 t['rombel_wali']?.toString() == rombelName && 
                 t['angkatan_wali']?.toString() == batchName;
        }).toList();

        // TIER 2: Match Everything (Cleaned)
        if (matches.isEmpty) {
          matches = allT.where((t) {
            if (t['wali_kelas'] == null) return false;
            String tw = superClean(t['wali_kelas']);
            String tr = superClean(t['rombel_wali']);
            String tb = superClean(t['angkatan_wali']);
            return tw == scClass && tr == scRombel && tb == scBatch;
          }).toList();
        }

        if (matches.isNotEmpty) {
          waliGuru = matches.first;
        }

        // Hitung status kelas
        bool allLulus = students.isNotEmpty && students.every((s) => s['status']?.toString().toLowerCase() == 'lulus');
        String displayStatus = allLulus ? 'Lulus' : 'Aktif';

        processedData.add({
          'no': idx++,
          'tingkat': _deriveTingkat(className),
          'kelas': className,
          'rombel': rombelName,
          'angkatan': batchName,
          'wali': waliGuru?['name'] ?? '-', 
          'wali_data': waliGuru, // Simpan data lengkap wali untuk navigasi
          'role': waliGuru?['role'] ?? 'Guru Kelas',
          'siswa': students.length,
          'laki': students.where((s) => s['gender'] == 'L').length,
          'perempuan': students.where((s) => s['gender'] == 'P').length,
          'status': displayStatus,
        });
      }

      // Urutkan biar rapi
      processedData.sort((a, b) => a['kelas'].compareTo(b['kelas']));

      setState(() {
        _allData = processedData;
        _batches = ['Angkatan', ...processedData.map((e) => e['angkatan'].toString()).toSet().toList()..sort()];
        _classesList = ['Kelas', ...processedData.map((e) => e['kelas'].toString()).toSet().toList()..sort()];
        _rombelList = ['Rombel', ...processedData.map((e) => e['rombel'].toString()).toSet().toList()..sort()];
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching class data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _deriveTingkat(String className) {
    if (className.toUpperCase().contains('TK A') || className.toUpperCase().contains('KELOMPOK A')) {
      return 'A (4-5 Th)';
    } else if (className.toUpperCase().contains('TK B') || className.toUpperCase().contains('KELOMPOK B')) {
      return 'B (5-6 Th)';
    }
    return 'TK (3-4 Th)';
  }

  void _applyFilters() {
    setState(() {
      _filteredData = _allData.where((item) {
        final matchesSearch = item['kelas'].toLowerCase().contains(_searchController.text.toLowerCase()) || 
                             item['rombel'].toLowerCase().contains(_searchController.text.toLowerCase()) ||
                             item['angkatan'].toLowerCase().contains(_searchController.text.toLowerCase()) ||
                             item['wali'].toLowerCase().contains(_searchController.text.toLowerCase());
        final matchesBatch = _selectedBatch == 'Angkatan' || item['angkatan'] == _selectedBatch;
        final matchesClass = _selectedClass == 'Kelas' || item['kelas'] == _selectedClass;
        final matchesRombel = _selectedRombel == 'Rombel' || item['rombel'] == _selectedRombel;
        final matchesStatus = _selectedStatus == 'Semua Status' || item['status'] == _selectedStatus;

        return matchesSearch && matchesBatch && matchesClass && matchesRombel && matchesStatus;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedBatch = 'Angkatan';
      _selectedClass = 'Kelas';
      _selectedRombel = 'Rombel';
      _selectedStatus = 'Semua Status';
      _applyFilters();
    });
  }

  void _showClassDetails(Map<String, dynamic> item) {
    if (widget.isEmbedded && widget.onNavigate != null) {
      widget.onNavigate!(17, classData: item);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailKelasPage(classData: item),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
        onRefresh: _fetchData,
        color: primaryTeal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Data Kelas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark)),
                  ElevatedButton.icon(
                    onPressed: () => _fetchData(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryTeal,
                      side: BorderSide(color: primaryTeal.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildFilterBar(),
              const SizedBox(height: 24),
              _buildClassGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari kelas, rombel, angkatan atau wali...',
                    hintStyle: TextStyle(fontSize: 13, color: textMuted),
                    prefixIcon: Icon(Icons.search_rounded, color: textMuted, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
                    isDense: true,
                  ),
                ),
              ),
              if (!_isMobile) ...[
                const SizedBox(width: 12),
                _outlinedIconBtn(Icons.refresh_rounded, 'Reset', onTap: _resetFilters),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _isMobile 
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _filterDropdown(_selectedBatch, _batches, (val) => setState(() { _selectedBatch = val!; _applyFilters(); }))),
                    const SizedBox(width: 12),
                    Expanded(child: _filterDropdown(_selectedClass, _classesList, (val) => setState(() { _selectedClass = val!; _applyFilters(); }))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _filterDropdown(_selectedRombel, _rombelList, (val) => setState(() { _selectedRombel = val!; _applyFilters(); }))),
                    const SizedBox(width: 12),
                    Expanded(child: _filterDropdown(_selectedStatus, _statusList, (val) => setState(() { _selectedStatus = val!; _applyFilters(); }))),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _outlinedIconBtn(Icons.refresh_rounded, 'Reset', onTap: _resetFilters),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _filterDropdown(_selectedBatch, _batches, (val) => setState(() { _selectedBatch = val!; _applyFilters(); }))),
                const SizedBox(width: 12),
                Expanded(child: _filterDropdown(_selectedClass, _classesList, (val) => setState(() { _selectedClass = val!; _applyFilters(); }))),
                const SizedBox(width: 12),
                Expanded(child: _filterDropdown(_selectedRombel, _rombelList, (val) => setState(() { _selectedRombel = val!; _applyFilters(); }))),
                const SizedBox(width: 12),
                Expanded(child: _filterDropdown(_selectedStatus, _statusList, (val) => setState(() { _selectedStatus = val!; _applyFilters(); }))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _filterDropdown(String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down_rounded, color: textMuted),
          style: TextStyle(fontSize: 12, color: textDark, fontWeight: FontWeight.w500),
          items: items.map((String item) {
            return DropdownMenuItem<String>(value: item, child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _outlinedIconBtn(IconData icon, String label, {VoidCallback? onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: textDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }

  Widget _buildClassGrid() {
    if (_filteredData.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.groups_rounded, size: 64, color: textMuted),
            const SizedBox(height: 16),
            Text('Belum ada data kelas', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Data akan muncul otomatis setelah Anda\nmenambahkan data siswa.', 
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _isMobile ? 1 : 3,
        mainAxisExtent: _isMobile ? 220 : 220,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: _filteredData.length,
      itemBuilder: (context, index) => _buildClassCard(_filteredData[index]),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> item) {
    bool isLulus = item['status'].toString().toLowerCase() == 'lulus';
    Color cardAccent = isLulus ? Colors.green : primaryTeal;

    return InkWell(
      onTap: () => _showClassDetails(item),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16), // Reduced from 20
        decoration: BoxDecoration(
          color: isLulus ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isLulus ? Border.all(color: Colors.green.withValues(alpha: 0.2), width: 1) : null,
          boxShadow: [
            BoxShadow(
              color: isLulus ? Colors.green.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), 
              blurRadius: 10, 
              offset: const Offset(0, 4)
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8), // Reduced padding
                  decoration: BoxDecoration(
                    color: cardAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.meeting_room_rounded, color: cardAccent, size: 20), // Reduced icon size
                ),
                _statusBadge(item['status']),
              ],
            ),
            const SizedBox(height: 12), // Reduced spacing
            Text(
              item['kelas'],
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark), // Reduced font size
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8), // Reduced spacing
            // Detail Info with Icons
            _cardInfoRow(Icons.groups_3_rounded, 'Rombel', item['rombel'], const Color(0xFF0EA5E9)),
            const SizedBox(height: 6),
            _cardInfoRow(Icons.calendar_today_rounded, 'Angkatan', item['angkatan'], const Color(0xFFF59E0B)),
            const SizedBox(height: 6),
            InkWell(
              onTap: item['wali_data'] != null ? () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => DetailGuruPage(teacher: item['wali_data'], userRole: 'Admin')));
              } : null,
              borderRadius: BorderRadius.circular(4),
              child: _cardInfoRow(Icons.person_rounded, 'Wali', item['wali'], primaryTeal),
            ),
            const Spacer(),
            Divider(color: Colors.grey.shade50, height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.people_rounded, size: 14, color: cardAccent),
                const SizedBox(width: 6),
                Text('${item['siswa']} Siswa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cardAccent)),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded, size: 14, color: textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 11, color: textSecondary)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textDark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    bool isActive = status.toLowerCase() == 'aktif';
    bool isLulus = status.toLowerCase() == 'lulus';
    
    Color bgColor = const Color(0xFFF1F5F9);
    Color textColor = textSecondary;

    if (isActive) {
      bgColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF15803D);
    } else if (isLulus) {
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor, 
        borderRadius: BorderRadius.circular(8)
      ),
      child: Text(
        status, 
        style: TextStyle(
          color: textColor,
          fontSize: 10, 
          fontWeight: FontWeight.bold
        )
      ),
    );
  }
}
