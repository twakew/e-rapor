import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../penilaian/input_nilai_page.dart';
import '../utils/rapor_pdf_generator.dart';
import '../utils/notification_helper.dart';

class DetailRaporPage extends StatefulWidget {
  final dynamic student;
  final List<dynamic> assessments;
  final int semester;
  final String? userRole;

  const DetailRaporPage({
    super.key,
    required this.student,
    required this.assessments,
    required this.semester,
    this.userRole,
  });

  @override
  State<DetailRaporPage> createState() => _DetailRaporPageState();
}

class _DetailRaporPageState extends State<DetailRaporPage> {
  bool _isPrinting = false;
  DateTime? _reportDate;
  final apiService = ApiService();

  // --- Theme Palette (Teal & Navy) ---
  final Color primaryGreen = AppColors.primary;
  final Color darkNavy = AppColors.textDark;
  final Color textSecondary = const Color(0xFF64748B);
  final Color textMuted = Color(0xFF94A3B8);
  final Color bgLight = AppColors.backgroundColor;
  
  final Color colorBSB = const Color(0xFF10B981); // Emerald
  final Color colorBSH = const Color(0xFF3B82F6); // Blue
  final Color colorMB = const Color(0xFFF59E0B);  // Amber

  @override
  void initState() {
    super.initState();
    // Cari report_date dari data penilaian yang ada
    final firstWithDate = widget.assessments.firstWhere((a) => a['report_date'] != null, orElse: () => null);
    if (firstWithDate != null) {
      _reportDate = DateTime.parse(firstWithDate['report_date'].toString());
    }
  }

  Future<void> _editReportDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reportDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryGreen,
              onPrimary: Colors.white,
              onSurface: darkNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _reportDate) {
      setState(() => _isPrinting = true); // Use isPrinting as a general loading state for simplicity
      try {
        await apiService.updateBulk('assessments', {
          'student_id': widget.student['id'],
          'semester': widget.semester,
        }, {'report_date': picked.toIso8601String()});

        setState(() {
          _reportDate = picked;
          // Update local assessment objects to keep in sync if they are reused
          for (var a in widget.assessments) {
            a['report_date'] = picked.toIso8601String();
          }
        });
        if (mounted) NotificationHelper.show(context, 'Tanggal rapor berhasil diperbarui');
      } catch (e) {
        if (mounted) NotificationHelper.show(context, 'Gagal memperbarui tanggal: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isPrinting = false);
      }
    }
  }

  String _getMonthName(int month) {
    const months = ["", "Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"];
    return months[month];
  }

  Future<void> _deleteRapor() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Rapor'),
        content: Text('Hapus seluruh penilaian ${widget.student['name']} Semester ${widget.semester}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await apiService.deleteBulk('assessments', {
          'student_id': widget.student['id'],
          'semester': widget.semester,
        });
        
        if (mounted) {
          NotificationHelper.show(context, 'Rapor berhasil dihapus');
          Navigator.pop(context); // Kembali ke halaman sebelumnya
        }
      } catch (e) {
        if (mounted) NotificationHelper.show(context, 'Gagal menghapus: $e', isError: true);
      }
    }
  }

  Future<void> _generateAndPrintPDF() async {
    setState(() => _isPrinting = true);
    try {
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: pw.Font.times(),
          bold: pw.Font.timesBold(),
        ),
      );

      final school = await apiService.getFirstRow('school_data') ?? {};

      Future<pw.MemoryImage?> loadImage(String path) async {
        try {
          final bytes = await rootBundle.load(path);
          return pw.MemoryImage(bytes.buffer.asUint8List());
        } catch (_) { return null; }
      }

      final images = await Future.wait([
        loadImage('assets/logo.png'),
        loadImage('assets/planet.png'),
        loadImage('assets/roket.png'),
        loadImage('assets/buku.png'),
        loadImage('assets/pahlawan.png'),
        loadImage('assets/mesjid.png'),
        loadImage('assets/alquran.png'),
        loadImage('assets/keluarga.png'),
        loadImage('assets/famly.png'),
      ]);

      await RaporPdfGenerator.generateRapor(
        pdf: pdf,
        student: widget.student,
        assessments: widget.assessments,
        school: school,
        logoImage: images[0],
        planetImg: images[1],
        rocketImg: images[2],
        bookImg: images[3],
        heroImg: images[4],
        mosqueImg: images[5],
        quranImg: images[6],
        familyImg: images[7],
        childrenImg: images[8],
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Rapor_${(widget.student['name'] ?? 'Siswa').toString().replaceAll(' ', '_')}_Smtr${widget.semester}.pdf',
      );
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(context, 'Gagal mencetak: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> dataByCategory = {};
    for (var a in widget.assessments) {
      final key = a['category']?.toString() ?? '';
      dataByCategory[key] = a;
    }

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: Text('Detail Rapor', style: TextStyle(fontWeight: FontWeight.bold, color: darkNavy, fontSize: 18)),
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: darkNavy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: darkNavy),
            onSelected: (val) {
              if (val == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InputNilaiPage(
                      student: widget.student,
                      existingAssessments: widget.assessments,
                      initialSemester: widget.semester,
                    ),
                  ),
                );
              } else if (val == 'date') {
                _editReportDate();
              } else if (val == 'delete') {
                _deleteRapor();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 12), Text('Edit Data Nilai')])),
              const PopupMenuItem(value: 'date', child: Row(children: [Icon(Icons.calendar_month_outlined, size: 18), SizedBox(width: 12), Text('Edit Tanggal Rapor')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), SizedBox(width: 12), Text('Hapus Rapor', style: TextStyle(color: Colors.red))])),
            ],
          ),
          if (_isPrinting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF0D9488), strokeWidth: 2))),
            )
          else if (widget.userRole != 'User')
            IconButton(
              icon: Icon(Icons.print_rounded, color: primaryGreen),
              onPressed: _generateAndPrintPDF,
              tooltip: 'Cetak PDF',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            _buildStudentInfo(),
            const SizedBox(height: 24),
            
            _buildSectionHeader('CAPAIAN PEMBELAJARAN', Icons.auto_stories_rounded),
            _buildNarrativeCard(dataByCategory, 'Nilai Agama dan Budi Pekerti'),
            _buildNarrativeCard(dataByCategory, 'Jati Diri'),
            _buildNarrativeCard(dataByCategory, 'Dasar Literasi, Sains, Teknologi, Rekayasa, & Seni'),
            
            _buildSectionHeader('PROJEK PROFIL', Icons.stars_rounded),
            _buildNarrativeCard(dataByCategory, 'Projek Penguatan Profil Lulusan'),
            
            _buildSectionHeader('PROGRAM UNGGULAN', Icons.workspace_premium_rounded),
            _buildGridSection(dataByCategory, [
              'Qiro\'ati', 'Ibadah', 'Pendidikan Aqidah', 'Bahasa Arab'
            ]),
            
            _buildSectionHeader('TAHFIDZ', Icons.menu_book_rounded),
            _buildGridSection(dataByCategory, [
              'Al-Qur\'an', 'Do\'a-Do\'a', 'Hadits-Hadits'
            ]),

            _buildSectionHeader('PERTUMBUHAN & KEHADIRAN', Icons.accessibility_new_rounded),
            _buildGrowthAndAttendance(dataByCategory),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: primaryGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Center(
              child: Text(
                widget.student['name']?[0]?.toUpperCase() ?? 'S',
                style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.student['name'] ?? '-', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkNavy)),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text('Kelas ${widget.student['class'] ?? '-'} • Semester ${widget.semester}',
                      style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    if (_reportDate != null) ...[
                      Container(width: 4, height: 4, decoration: BoxDecoration(color: textMuted, shape: BoxShape.circle)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 12, color: textSecondary),
                          const SizedBox(width: 4),
                          Text('${_reportDate!.day} ${_getMonthName(_reportDate!.month)} ${_reportDate!.year}',
                            style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16, left: 4),
      child: Row(
        children: [
          Icon(icon, color: primaryGreen, size: 20),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textSecondary, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildNarrativeCard(Map<String, dynamic> data, String category) {
    final item = data[category];
    if (item == null) return const SizedBox();

    String scoreLong = '';
    Color scoreColor = Colors.grey;
    final scoreCode = item['score']?.toString() ?? '';

    if (scoreCode == 'BSB') {
      scoreLong = 'Berkembang Sangat Baik';
      scoreColor = colorBSB;
    } else if (scoreCode == 'BSH') {
      scoreLong = 'Berkembang Sesuai Harapan';
      scoreColor = colorBSH;
    } else if (scoreCode == 'MB') {
      scoreLong = 'Mulai Berkembang';
      scoreColor = colorMB;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkNavy)),
          const SizedBox(height: 12),
          if (scoreLong.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: scoreColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: scoreColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(scoreLong, style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(item['notes'] ?? 'Tidak ada catatan.', 
            style: TextStyle(fontSize: 13, height: 1.6, color: darkNavy.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _buildGridSection(Map<String, dynamic> data, List<String> categories) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final item = data[cat];
        if (item == null) return const SizedBox();

        final score = item['score']?.toString() ?? '';
        Color sColor = primaryGreen;
        if (score == 'BSB') sColor = colorBSB;
        if (score == 'BSH') sColor = colorBSH;
        if (score == 'MB') sColor = colorMB;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cat, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: darkNavy), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              if (score.isNotEmpty)
                Text(score, style: TextStyle(color: sColor, fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 8),
              Expanded(
                child: Text(item['notes'] ?? '-', 
                  style: TextStyle(fontSize: 11, color: textSecondary, height: 1.4),
                  maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrowthAndAttendance(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _growthRow('Berat Badan', data['Berat Badan']?['score'] ?? '-', 'kg'),
          _growthRow('Tinggi Badan', data['Tinggi Badan']?['score'] ?? '-', 'cm'),
          _growthRow('Lingkar Kepala', data['Lingkar Kepala']?['score'] ?? '-', 'cm'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Color(0xFFE2E8F0), height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _attItem('Hadir', data['Hadir']?['score'] ?? '0', colorBSB),
              _attItem('Sakit', data['Sakit']?['score'] ?? '0', colorMB),
              _attItem('Izin', data['Izin']?['score'] ?? '0', colorBSH),
              _attItem('Alfa', data['Tanpa Keterangan']?['score'] ?? '0', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _growthRow(String label, String value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary)),
          Text('$value $unit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: darkNavy)),
        ],
      ),
    );
  }

  Widget _attItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
