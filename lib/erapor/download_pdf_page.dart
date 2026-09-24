import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'detail_rapor_page.dart';
import '../utils/rapor_pdf_generator.dart';

class DownloadPdfPage extends StatefulWidget {
  final String? studentNis;
  final String? userRole;
  const DownloadPdfPage({super.key, this.studentNis, this.userRole});

  @override
  State<DownloadPdfPage> createState() => _DownloadPdfPageState();
}

class _DownloadPdfPageState extends State<DownloadPdfPage> {
  final apiService = ApiService();
  Timer? _refreshTimer;
  bool _isLoading = true;
  int _selectedSemester = 1;
  Map<String, dynamic> _groupedHistory = {};
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  // Filter for Batch Download
  String _dlBatch = 'Semua';
  String _dlClass = 'Semua';
  String _dlRombel = 'Semua';

  // Filter for Publishing
  String _pbBatch = 'Semua';
  String _pbClass = 'Semua';
  String _pbRombel = 'Semua';
  int _pbSemester = 1;

  // Modern Color Palette
  final Color primaryTeal = AppColors.primary;
  final Color bgColor = AppColors.backgroundColor;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _initRealtime();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _initRealtime() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchHistory(showLoading: false));
  }

  Future<void> _fetchHistory({bool showLoading = true}) async {
    try {
      if (!mounted) return;
      if (showLoading) setState(() => _isLoading = true);

      List<dynamic> response;
      if (widget.userRole == 'User' && widget.studentNis != null) {
        // Siswa: rapor published milik sendiri via RPC (direct select
        // assessments ditolak RLS utk non-staff). RPC flat -> adaptor.
        final rows = await apiService.callRpc('get_my_rapor',
            params: {'p_nis': widget.studentNis!.trim()});
        response = ((rows as List?) ?? [])
            .where((a) => _selectedSemester == 1
                ? ((a['semester'] ?? 1) == 1)
                : (a['semester'] == 2))
            .map((a) => {
                  ...a,
                  'students': {
                    'id': a['student_id'],
                    'name': a['student_name'],
                    'nis': a['student_nis'],
                    'class': a['student_class'],
                    'rombel': a['student_rombel'],
                    'batch': a['student_batch'],
                  },
                })
            .toList();
      } else {
        // Fetch assessments and students separately then join manually
        final assessments = await apiService.getTable('assessments');
        final students = await apiService.getTable('students');
        
        final studentMap = { for (var s in students) s['id']: s };
        
        response = assessments.where((a) {
          final sem = a['semester'];
          if (_selectedSemester == 1) return sem == 1 || sem == null;
          return sem == 2;
        }).map((a) {
          return {
            ...a,
            'students': studentMap[a['student_id']]
          };
        }).toList();
      }

      final Map<String, dynamic> grouped = {};
      for (var item in response) {
        var student = item['students'];
        if (student == null) continue;

        if (student is List && student.isNotEmpty) {
          student = student.first;
        }

        final studentId = student['id'].toString();
        if (!grouped.containsKey(studentId)) {
          grouped[studentId] = {
            'student': student,
            'semester': item['semester'] ?? 1,
            'assessments': [],
          };
        }
        grouped[studentId]['assessments'].add(item);
      }

      if (mounted) {
        setState(() {
          _groupedHistory = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _downloadPdfs({List<String>? targetIds}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primaryTeal),
                const SizedBox(height: 20),
                const Text('Menyiapkan PDF...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Mohon tunggu sebentar', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: pw.Font.times(),
          bold: pw.Font.timesBold(),
          italic: pw.Font.timesItalic(),
          boldItalic: pw.Font.timesBoldItalic(),
        ),
      );
      
    final school = await apiService.getFirstRow('school_data') ?? {};
    final idsToProcess = targetIds ?? _groupedHistory.keys.toList();
    
    // Load icons
    pw.MemoryImage? planetImg, rocketImg, bookImg, heroImg, mosqueImg, quranImg, familyImg, famlyImg;
    try {
      final pB = await rootBundle.load('assets/planet.png');
      planetImg = pw.MemoryImage(pB.buffer.asUint8List());
      final rB = await rootBundle.load('assets/roket.png');
      rocketImg = pw.MemoryImage(rB.buffer.asUint8List());
      final bB = await rootBundle.load('assets/buku.png');
      bookImg = pw.MemoryImage(bB.buffer.asUint8List());
      final hB = await rootBundle.load('assets/pahlawan.png');
      heroImg = pw.MemoryImage(hB.buffer.asUint8List());
      final mB = await rootBundle.load('assets/mesjid.png');
      mosqueImg = pw.MemoryImage(mB.buffer.asUint8List());
      final qB = await rootBundle.load('assets/alquran.png');
      quranImg = pw.MemoryImage(qB.buffer.asUint8List());
      final fB = await rootBundle.load('assets/keluarga.png');
      familyImg = pw.MemoryImage(fB.buffer.asUint8List());
      final fmB = await rootBundle.load('assets/famly.png');
      famlyImg = pw.MemoryImage(fmB.buffer.asUint8List());
    } catch (_) {}

    pw.MemoryImage? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/logo.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {}

      for (var studentId in idsToProcess) {
        final studentData = _groupedHistory[studentId];
        if (studentData == null) continue;
        
        await RaporPdfGenerator.generateRapor(
          pdf: pdf,
          student: studentData['student'],
          assessments: studentData['assessments'],
          school: school,
          logoImage: logoImage,
          planetImg: planetImg,
          rocketImg: rocketImg,
          bookImg: bookImg,
          heroImg: heroImg,
          mosqueImg: mosqueImg,
          quranImg: quranImg,
          familyImg: familyImg,
          childrenImg: famlyImg,
        );
      }

      if (mounted) Navigator.pop(context);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: targetIds == null ? 'Rapor_Semua_Siswa.pdf' : 'Rapor_Pilihan.pdf',
      );

      if (_isSelectionMode && mounted) {
        setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentIds = _groupedHistory.keys.toList();
    return _isLoading
        ? Center(child: CircularProgressIndicator(color: primaryTeal))
        : Column(
            children: [
              _buildHeaderSection(),
              _buildSemesterFilter(),
              Expanded(
                child: studentIds.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchHistory,
                        color: primaryTeal,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: studentIds.length,
                          itemBuilder: (context, index) {
                            final studentId = studentIds[index];
                            final studentData = _groupedHistory[studentId];
                            return _buildStudentCard(studentId, studentData);
                          },
                        ),
                      ),
              ),
            ],
          );
  }

  Widget _buildHeaderSection() {
    final studentIds = _groupedHistory.keys.toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _isSelectionMode
              ? Text('${_selectedIds.length} Terpilih', style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold, fontSize: 24))
              : Row(
                  children: [
                    Text('Download Nilai', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 24)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.paleBlue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${studentIds.length} siswa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.paleBlueText)),
                    ),
                  ],
                ),
          if (_isSelectionMode)
            IconButton(
              onPressed: () => _downloadPdfs(targetIds: _selectedIds.toList()),
              icon: Icon(Icons.file_download_outlined, color: primaryTeal, size: 28),
              tooltip: 'Download Terpilih',
            )
          else if (studentIds.isNotEmpty)
            Row(
              children: [
                if (widget.userRole != 'User') ...[
                  IconButton(
                    onPressed: _showPublishSheet,
                    icon: Icon(Icons.send_rounded, color: primaryTeal, size: 24),
                    tooltip: 'Kirim ke Akun User',
                  ),
                  IconButton(
                    onPressed: _showDownloadFilterSheet,
                    icon: Icon(Icons.download_for_offline_outlined, color: primaryTeal, size: 28),
                    tooltip: 'Download Semua',
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  void _showPublishSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final allStudents = _groupedHistory.values.map((v) => v['student'] as Map<String, dynamic>).toList();
          
          final batches = ['Semua', ...allStudents.map((s) => (s['batch'] ?? '').toString()).where((a) => a.isNotEmpty).toSet().toList()..sort()];
          
          final tempForClass = allStudents.where((s) => _pbBatch == 'Semua' || s['batch'] == _pbBatch).toList();
          final classes = ['Semua', ...tempForClass.map((s) => (s['class'] ?? '').toString()).where((c) => c.isNotEmpty).toSet().toList()..sort()];
          if (!classes.contains(_pbClass)) _pbClass = 'Semua';

          final tempForRombel = tempForClass.where((s) => _pbClass == 'Semua' || s['class'] == _pbClass).toList();
          final rombels = ['Semua', ...tempForRombel.map((s) => (s['rombel'] ?? '').toString()).where((r) => r.isNotEmpty).toSet().toList()..sort()];
          if (!rombels.contains(_pbRombel)) _pbRombel = 'Semua';

          return Container(
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 24),
                Text('Kirim Rapor ke User', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryTeal)),
                const SizedBox(height: 8),
                Text('Rapor yang dikirim akan dapat dilihat oleh Siswa/Orang Tua.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 24),

                _dlLabel('Angkatan'),
                _dlDropdown(batches, _pbBatch, (v) => setSheetState(() => _pbBatch = v!)),
                
                const SizedBox(height: 16),
                _dlLabel('Kelas'),
                _dlDropdown(classes, _pbClass, (v) => setSheetState(() => _pbClass = v!)),
                
                const SizedBox(height: 16),
                _dlLabel('Rombel'),
                _dlDropdown(rombels, _pbRombel, (v) => setSheetState(() => _pbRombel = v!)),

                const SizedBox(height: 16),
                _dlLabel('Semester'),
                _dlDropdown(['1', '2'], _pbSemester.toString(), (v) => setSheetState(() => _pbSemester = int.parse(v!))),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _publishReports();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('PUBLIKASIKAN RAPOR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _publishReports() async {
    setState(() => _isLoading = true);
    try {
      // 1. Get filtered student IDs
      final filteredIds = _groupedHistory.entries
        .where((e) {
          final s = e.value['student'];
          final matchesBatch = _pbBatch == 'Semua' || s['batch'] == _pbBatch;
          final matchesClass = _pbClass == 'Semua' || s['class'] == _pbClass;
          final matchesRombel = _pbRombel == 'Semua' || s['rombel'] == _pbRombel;
          return matchesBatch && matchesClass && matchesRombel;
        })
        .map((e) => e.key)
        .toList();

      if (filteredIds.isEmpty) {
        throw 'Tidak ada siswa yang sesuai filter.';
      }

      // 2. Update assessments table
      for (var sId in filteredIds) {
        await apiService.updateBulk('assessments', {
          'student_id': sId,
          'semester': _pbSemester,
        }, {'is_published': true});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil mengirim rapor ke akun user! ✨'), backgroundColor: Colors.green),
        );
      }
      _fetchHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDownloadFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final allStudents = _groupedHistory.values.map((v) => v['student'] as Map<String, dynamic>).toList();
          
          // 1. Unique Batches
          final batches = ['Semua', ...allStudents.map((s) => (s['batch'] ?? '').toString()).where((a) => a.isNotEmpty).toSet().toList()..sort()];
          
          // 2. Filter for Class choices
          final tempForClass = allStudents.where((s) => _dlBatch == 'Semua' || s['batch'] == _dlBatch).toList();
          final classes = ['Semua', ...tempForClass.map((s) => (s['class'] ?? '').toString()).where((c) => c.isNotEmpty).toSet().toList()..sort()];
          if (!classes.contains(_dlClass)) _dlClass = 'Semua';

          // 3. Filter for Rombel choices
          final tempForRombel = tempForClass.where((s) => _dlClass == 'Semua' || s['class'] == _dlClass).toList();
          final rombels = ['Semua', ...tempForRombel.map((s) => (s['rombel'] ?? '').toString()).where((r) => r.isNotEmpty).toSet().toList()..sort()];
          if (!rombels.contains(_dlRombel)) _dlRombel = 'Semua';

          // Final count based on filters
          final filteredCount = tempForRombel.where((s) => _dlRombel == 'Semua' || s['rombel'] == _dlRombel).length;

          return Container(
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 24),
                Text('Pilih Kelompok Download', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryTeal)),
                const SizedBox(height: 8),
                Text('Download semua PDF rapor berdasarkan filter di bawah ini.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 24),

                _dlLabel('Angkatan'),
                _dlDropdown(batches, _dlBatch, (v) => setSheetState(() => _dlBatch = v!)),
                
                const SizedBox(height: 16),
                _dlLabel('Kelas'),
                _dlDropdown(classes, _dlClass, (v) => setSheetState(() => _dlClass = v!)),
                
                const SizedBox(height: 16),
                _dlLabel('Rombel'),
                _dlDropdown(rombels, _dlRombel, (v) => setSheetState(() => _dlRombel = v!)),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: filteredCount == 0 ? null : () {
                      Navigator.pop(context);
                      final targetIds = _groupedHistory.entries
                        .where((e) {
                          final s = e.value['student'];
                          final matchesBatch = _dlBatch == 'Semua' || s['batch'] == _dlBatch;
                          final matchesClass = _dlClass == 'Semua' || s['class'] == _dlClass;
                          final matchesRombel = _dlRombel == 'Semua' || s['rombel'] == _dlRombel;
                          return matchesBatch && matchesClass && matchesRombel;
                        })
                        .map((e) => e.key)
                        .toList();
                      _downloadPdfs(targetIds: targetIds);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text('DOWNLOAD $filteredCount PDF', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dlLabel(String text) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))));

  Widget _dlDropdown(List<String> items, String value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s == 'Semua' ? 'Semua $s' : s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSemesterFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(child: _filterButton(1, 'Semester 1')),
          const SizedBox(width: 12),
          Expanded(child: _filterButton(2, 'Semester 2')),
        ],
      ),
    );
  }

  Widget _filterButton(int semester, String label) {
    bool isSelected = _selectedSemester == semester;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSemester = semester;
          _selectedIds.clear();
          _isSelectionMode = false;
        });
        _fetchHistory();
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? primaryTeal : bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(String studentId, dynamic studentData) {
    final student = studentData['student'];
    final assessments = studentData['assessments'] as List;
    final bool isSelected = _selectedIds.contains(studentId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
        border: isSelected ? Border.all(color: primaryTeal, width: 2) : Border.all(color: AppColors.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: isSelected ? primaryTeal : primaryTeal.withValues(alpha: 0.1),
            child: isSelected 
                ? const Icon(Icons.check, color: Colors.white)
                : Text(
                    student['name']?[0] ?? 'S', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: primaryTeal)
                  ),
          ),
          title: Text(
            student['name'] ?? 'Tanpa Nama', 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
          ),
          subtitle: Text(
            'Kelas: ${student['class'] ?? '-'} | ${assessments.length} Penilaian',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          trailing: _isSelectionMode 
              ? null 
              : Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
          onLongPress: () {
            if (widget.userRole != 'User') _toggleSelection(studentId);
          },
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(studentId);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailRaporPage(
                    student: student,
                    assessments: assessments,
                    semester: _selectedSemester,
                    userRole: widget.userRole,
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryTeal.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.description_outlined, size: 64, color: primaryTeal.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Belum ada nilai yang tersimpan', 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF64748B))
          ),
          const SizedBox(height: 8),
          Text(
            'Silakan input nilai siswa terlebih dahulu.',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _fetchHistory, 
            icon: Icon(Icons.refresh_rounded, color: primaryTeal),
            label: Text('Segarkan Halaman', style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

