import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart' as fp;
import '../services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../utils/notification_helper.dart';
import '../utils/push_notification_service.dart';

class InputNilaiPage extends StatefulWidget {
  final dynamic student;
  final List<dynamic>? existingAssessments;
  final int? initialSemester;
  final String? userRole;
  final bool isEmbedded;
  final Function(int)? onNavigate;

  const InputNilaiPage({
    super.key,
    required this.student,
    this.existingAssessments,
    this.initialSemester,
    this.userRole,
    this.isEmbedded = false,
    this.onNavigate,
  });

  @override
  State<InputNilaiPage> createState() => _InputNilaiPageState();
}

class _InputNilaiPageState extends State<InputNilaiPage> with SingleTickerProviderStateMixin {
  final apiService = ApiService();
  bool _isLoading = false;
  late TabController _mainTabController;
  DateTime _reportDate = DateTime.now();

  // --- Clean Palette based on Project Style (Teal) ---
  final Color primaryGreen = AppColors.primary;
  final Color darkNavy = AppColors.textDark;
  final Color textSecondary = const Color(0xFF64748B);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color bgLight = AppColors.backgroundColor;
  
  final Color colorBSB = const Color(0xFF10B981); // Emerald
  final Color colorBSH = const Color(0xFF3B82F6); // Blue
  final Color colorMB = const Color(0xFFF59E0B);  // Amber
  final Color colorBB = const Color(0xFFEF4444);  // Red

  String _activeCategory = 'Nilai Agama dan Budi Pekerti';
  final Map<String, String> _grades = {};
  final Map<String, TextEditingController> _notesControllers = {};
  final Map<String, TextEditingController> _materialControllers = {};
  final Map<String, int?> _assessmentIds = {};
  final Map<String, List<dynamic>> _selectedImages = {}; // Can be File or String (URL)

  bool get _isMobile => MediaQuery.of(context).size.width < 900;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 6, vsync: this);
    _mainTabController.addListener(() {
      if (!_mainTabController.indexIsChanging) {
        // Otomatis pindah ke aspek pertama di tab baru agar Sidebar & Editor sinkron
        setState(() {
          _activeCategory = _getAspectsForActiveTab().first['t'];
        });
      }
    });
    _initData();
  }

  void _initData() {
    final categories = [
      'Nilai Agama dan Budi Pekerti', 'Jati Diri', 'Dasar Literasi, Sains, Teknologi, Rekayasa, & Seni',
      'Projek Penguatan Profil Lulusan', 'Qiro\'ati', 'Ibadah', 'Pendidikan Aqidah', 'Bahasa Arab',
      'Al-Qur\'an', 'Do\'a-Do\'a', 'Hadits-Hadits', 'Berat Badan', 'Tinggi Badan', 'Lingkar Kepala', 
      'Hadir', 'Sakit', 'Izin', 'Tanpa Keterangan', 'Refleksi Orang Tua'
    ];

    for (var cat in categories) {
      _notesControllers[cat] = TextEditingController();
      _materialControllers[cat] = TextEditingController();
      _grades[cat] = '';
      _assessmentIds[cat] = null;
      _selectedImages[cat] = [];
      
      // Pre-fill standard targets
      if ((widget.initialSemester ?? 1) == 1) {
        if (cat == 'Qiro\'ati') {
          _materialControllers[cat]?.text = 'Target Semester I\n- Jilid Pra TK A';
        } else if (cat == 'Ibadah') {
          _materialControllers[cat]?.text = '- Doa Setelah Adzan\n- Doa Sesudah Wudhu\n- Niat Sholat Dhuha\n- Takbiratul Ikhram\n- Iftitah\n- Ruku\n- I\'tidal';
        } else if (cat == 'Pendidikan Aqidah') {
          _materialControllers[cat]?.text = '- Kalimat Thoyyibah\n- Rukun Iman\n- Tugas-tugas Malaikat\n- Asmaul Husna';
        } else if (cat == 'Bahasa Arab') {
          _materialControllers[cat]?.text = '- Anggota Tubuh Manusia\n- Jarak\n- Ukuran\n- Waktu\n- Pekerjaan\n- Warna';
        } else if (cat == 'Al-Qur\'an') {
          _materialControllers[cat]?.text = '- Qs. An-Naba\n- Qs. Al-Fatihah - Al-Kautsar';
        } else if (cat == 'Do\'a-Do\'a') {
          _materialControllers[cat]?.text = '- Doa Kedua Orang Tua\n- Doa Kebaikan Dunia Akhirat\n- Doa Sebelum Tidur\n- Doa Bangun Tidur\n- Doa Sebelum Makan\n- Doa Sesudah Makan\n- Doa Masuk Kamar Mandi\n- Doa Keluar Kamar Mandi\n- Doa Ketika Turun Hujan\n- Doa Setelah Turun Hujan\n- Doa Dipagi Hari\n- Doa Disore Hari\n- Doa Ketika Bercermin';
        } else if (cat == 'Hadits-Hadits') {
          _materialControllers[cat]?.text = '- Hadits Jangan Marah\n- Hadits Kasih Sayang\n- Hadits Adab Makan\n- Hadits Bersaudara\n- Hadits Tersenyum\n- Hadits Suka Memberi';
        }
      }
    }

    if (widget.existingAssessments != null && widget.existingAssessments!.isNotEmpty) {
      // Load report date from the first assessment found
      final firstWithDate = widget.existingAssessments!.firstWhere((a) => a['report_date'] != null, orElse: () => null);
      if (firstWithDate != null) {
        _reportDate = DateTime.parse(firstWithDate['report_date'].toString());
      }

      for (var a in widget.existingAssessments!) {
        final rawCat = a['category']?.toString() ?? '';
        
        // Pencarian kategori yang lebih fleksibel (fuzzy match)
        String catKey = rawCat;
        if (rawCat.toUpperCase().contains("DASAR LITERASI") || rawCat.toUpperCase().contains("STREAM")) {
          catKey = 'Dasar Literasi, Sains, Teknologi, Rekayasa, & Seni';
        } else if (rawCat.toUpperCase().contains("QIRO")) {
          catKey = 'Qiro\'ati';
        }

        if (_notesControllers.containsKey(catKey)) {
          final val = a['notes'] ?? '';
          final score = a['score']?.toString() ?? '';
          
          // Gabungkan catatan jika sudah ada isinya (jangan ditindih)
          if (_notesControllers[catKey]!.text.isEmpty) {
            _notesControllers[catKey]?.text = val;
          } else if (val.isNotEmpty && !_notesControllers[catKey]!.text.contains(val)) {
            _notesControllers[catKey]?.text += "\n\n$val";
          }

          if (_materialControllers[catKey]!.text.isEmpty) {
             _materialControllers[catKey]?.text = a['material'] ?? '';
          }
          
          if (_grades[catKey] == '') _grades[catKey] = score;
          if (_assessmentIds[catKey] == null) _assessmentIds[catKey] = a['id'];
          
          // Untuk numeric cats
          final numericCats = ['Berat Badan', 'Tinggi Badan', 'Lingkar Kepala', 'Hadir', 'Sakit', 'Izin', 'Tanpa Keterangan'];
          if (numericCats.contains(catKey) && _notesControllers[catKey]!.text.isEmpty) {
             _notesControllers[catKey]?.text = score;
          }

          // GABUNGKAN FOTO (Jangan ditindih)
          if (a['image_url'] != null && a['image_url'].toString().isNotEmpty && a['image_url'].toString() != 'null') {
            final List<String> urls = a['image_url'].toString().split(',')
                .map((u) => u.trim())
                .where((u) => u.isNotEmpty && u != 'null' && u.length > 5)
                .toList();
            
            for (var url in urls) {
              if (!_selectedImages[catKey]!.contains(url) && _selectedImages[catKey]!.length < 3) {
                _selectedImages[catKey]!.add(url);
              }
            }
          }
        }
      }
    }
  }

  Future<void> _pickImage(String category) async {
    if ((_selectedImages[category]?.length ?? 0) >= 3) {
      NotificationHelper.show(context, 'Maksimal 3 foto per aspek', isError: true);
      return;
    }

    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: _isMobile ? double.infinity : 400),
          margin: EdgeInsets.all(_isMobile ? 0 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: _isMobile 
              ? const BorderRadius.vertical(top: Radius.circular(32))
              : BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isMobile)
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Text('Pilih Sumber Foto', 
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: darkNavy, letterSpacing: -0.5)
                ),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                    child: Icon(Icons.photo_library_rounded, color: primaryGreen, size: 26),
                  ),
                  title: Text('Ambil dari Galeri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkNavy)),
                  subtitle: Text('Pilih foto yang sudah ada di galeri', style: TextStyle(color: textSecondary, fontSize: 12)),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.blue, size: 26),
                  ),
                  title: Text('Gunakan Kamera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkNavy)),
                  subtitle: Text('Ambil foto baru secara langsung', style: TextStyle(color: textSecondary, fontSize: 12)),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );

    if (source != null) {
      try {
        final currentCount = _selectedImages[category]?.length ?? 0;
        final remaining = 3 - currentCount;

        if (source == ImageSource.gallery) {
          if (!_isMobile) {
            // Khusus Desktop pakai file_picker (Multiple)
            final result = await fp.FilePicker.pickFiles(
              type: fp.FileType.image,
              allowMultiple: true,
            );
            if (result != null) {
              final filesToAdd = result.files
                  .where((f) => f.path != null)
                  .take(remaining)
                  .map((f) => File(f.path!))
                  .toList();
              setState(() {
                _selectedImages[category]!.addAll(filesToAdd);
              });
              if (result.files.length > remaining) {
                if (mounted) NotificationHelper.show(context, 'Hanya $remaining foto yang ditambahkan (Maks 3)', isError: false);
              }
            }
          } else {
            // Mobile Gallery pakai pickMultiImage
            final pickedFiles = await picker.pickMultiImage(
              imageQuality: 50,
              maxWidth: 1000,
            );
            if (pickedFiles.isNotEmpty) {
              final filesToAdd = pickedFiles.take(remaining).map((f) => File(f.path)).toList();
              setState(() {
                _selectedImages[category]!.addAll(filesToAdd);
              });
              if (pickedFiles.length > remaining) {
                if (mounted) NotificationHelper.show(context, 'Hanya $remaining foto yang ditambahkan (Maks 3)', isError: false);
              }
            }
          }
        } else {
          // Kamera tetap single pick
          final pickedFile = await picker.pickImage(
            source: source,
            imageQuality: 50,
            maxWidth: 1000,
          );
          if (pickedFile != null) {
            setState(() {
              _selectedImages[category]!.add(File(pickedFile.path));
            });
          }
        }
      } catch (e) {
        if (mounted) {
          String msg = source == ImageSource.camera 
            ? 'Kamera tidak tersedia atau akses ditolak' 
            : 'Gagal membuka galeri: $e';
          NotificationHelper.show(context, msg, isError: true);
        }
      }
    }
  }

  Future<void> _saveGrades() async {
    setState(() => _isLoading = true);
    try {
      final studentId = widget.student['id'];
      
      for (var cat in _notesControllers.keys) {
        final score = _grades[cat] ?? '';
        final notes = _notesControllers[cat]?.text ?? '';
        final material = _materialControllers[cat]?.text ?? '';
        
        if (score.isNotEmpty || notes.isNotEmpty || material.isNotEmpty || (_selectedImages[cat]?.isNotEmpty ?? false)) {
          // 1. Bersihkan duplikat kategori yang mirip (fuzzy) sebelum simpan
          // Ini untuk menghapus record lama seperti "STREAM" jika kita simpan sebagai "Dasar Literasi..."
          // Note: Backend needs to handle this custom delete or we fetch and delete one by one
          if (cat == 'Dasar Literasi, Sains, Teknologi, Rekayasa, & Seni') {
            final oldAssessments = await apiService.getTable('assessments', queryParameters: {
              'student_id': studentId,
              'semester': widget.initialSemester ?? 1
            });
            for (var a in oldAssessments) {
              if (a['id'] != _assessmentIds[cat] && 
                 (a['category'].toString().toUpperCase().contains('STREAM') || a['category'].toString().toUpperCase().contains('DASAR LITERASI'))) {
                await apiService.delete('assessments', a['id'].toString());
              }
            }
          }

          // 2. Upload foto baru
          List<String> finalUrls = [];
          final imagesToProcess = (_selectedImages[cat] ?? []).take(3);
          
          for (var img in imagesToProcess) {
            if (img is String) {
              // Hanya simpan link http yang valid dan bukan link rusak
              if (img.startsWith('http') && !img.contains('null') && img.length > 20) {
                finalUrls.add(img);
              }
            } else if (img is File) {
              // Buat nama file yang aman (Hanya Alphanumeric)
              // Upload via backend
              final url = await apiService.uploadFile('penilaian', img);
              finalUrls.add(url);
            }
          }

          await apiService.upsert('assessments', [{
            if (_assessmentIds[cat] != null) 'id': _assessmentIds[cat],
            'student_id': studentId,
            'category': cat,
            'score': score,
            'notes': notes,
            'material': material,
            'image_url': finalUrls.join(','),
            'semester': widget.initialSemester ?? 1,
            'report_date': _reportDate.toIso8601String(),
            'is_published': false, // Selalu simpan sebagai Draft dulu
            'created_at': DateTime.now().toIso8601String(),
          }], conflictColumn: 'id');
        }
      }

      try {
        await PushNotificationService.sendNotification(
          userId: widget.student['nis'].toString(),
          title: 'RAPOR TERISI 📝',
          message: 'Alhamdulillah, penilaian rapor Ananda ${widget.student['name']} telah diperbarui.',
          data: {'include_staff': true, 'screen': 'penilaian'},
        );
      } catch (_) {}

      if (mounted) {
        NotificationHelper.show(context, 'Berhasil menyimpan penilaian ✨');
        if (widget.isEmbedded && widget.onNavigate != null) {
          widget.onNavigate!(25); // Pindah ke Riwayat Penilaian
        } else if (!widget.isEmbedded) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) NotificationHelper.show(context, 'Gagal menyimpan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: _isMobile ? AppBar(
        title: const Text('Input Penilaian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: darkNavy,
        elevation: 0,
        actions: [
          IconButton(onPressed: _saveGrades, icon: Icon(Icons.check_circle_rounded, color: primaryGreen))
        ],
      ) : null,
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryGreen))
        : Column(
            children: [
              if (!_isMobile) _buildHeaderBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isMobile ? 16 : 40, 
                    vertical: 24
                  ),
                  child: Column(
                    children: [
                      if (!_isMobile) _buildInfoCards(),
                      if (_isMobile) ...[
                        _infoChip(
                          'Tanggal Rapor', 
                          '${_reportDate.day} ${_getMonthName(_reportDate.month)} ${_reportDate.year}', 
                          Icons.calendar_month_rounded,
                          onTap: () => _selectReportDate(context),
                          isAction: true,
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 24),
                      _buildHorizontalTabs(),
                      const SizedBox(height: 24),
                      if (_isMobile)
                        _buildMobileContent()
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildSidebarAspek()),
                            const SizedBox(width: 24),
                            Expanded(flex: 7, child: _buildEditorContent(_activeCategory)),
                          ],
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              if (!_isMobile) _buildBottomActionFrame(),
            ],
          ),
      floatingActionButton: _isMobile ? FloatingActionButton.extended(
        onPressed: _saveGrades,
        backgroundColor: primaryGreen,
        label: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.save_rounded),
      ) : null,
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Input Penilaian Rapor', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkNavy)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards() {
    return Row(
      children: [
        _infoChip('Siswa', widget.student['name'] ?? '-', Icons.person_rounded),
        const SizedBox(width: 12),
        _infoChip('Semester', 'Semester ${widget.initialSemester ?? 1}', Icons.layers_rounded),
        const SizedBox(width: 12),
        _infoChip('Kelas', widget.student['class'] ?? '-', Icons.school_rounded),
        const SizedBox(width: 12),
        _infoChip(
          'Tanggal Rapor', 
          '${_reportDate.day} ${_getMonthName(_reportDate.month)} ${_reportDate.year}', 
          Icons.calendar_month_rounded,
          onTap: () => _selectReportDate(context),
          isAction: true,
        ),
      ],
    );
  }

  Widget _infoChip(String label, String value, IconData icon, {VoidCallback? onTap, bool isAction = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isAction ? primaryGreen.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isAction ? primaryGreen.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: primaryGreen),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold)),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkNavy)),
              ],
            ),
            if (isAction) ...[
              const SizedBox(width: 8),
              Icon(Icons.edit_calendar_rounded, size: 14, color: primaryGreen),
            ],
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ["", "Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"];
    return months[month];
  }

  Future<void> _selectReportDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
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
      setState(() {
        _reportDate = picked;
      });
    }
  }

  Widget _buildHorizontalTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: TabBar(
        controller: _mainTabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: primaryGreen,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryGreen,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'Capaian Pembelajaran'),
          Tab(text: 'Projek Profil'),
          Tab(text: 'Program Unggulan'),
          Tab(text: 'Tahfidz'),
          Tab(text: 'Pertumbuhan & Kehadiran'),
          Tab(text: 'Refleksi'),
        ],
      ),
    );
  }

  Widget _buildMobileContent() {
    List<Map<String, dynamic>> aspects = _getAspectsForActiveTab();
    return Column(
      children: aspects.map((e) {
        bool active = _activeCategory == e['t'];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? primaryGreen : const Color(0xFFE2E8F0)),
          ),
          child: ExpansionTile(
            initiallyExpanded: active,
            onExpansionChanged: (val) {
              if (val) setState(() => _activeCategory = e['t']);
            },
            leading: Icon(e['i'] as IconData, color: active ? primaryGreen : textMuted),
            title: Text(e['t'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: active ? primaryGreen : darkNavy)),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildEditorContent(e['t'] as String),
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSidebarAspek() {
    List<Map<String, dynamic>> list = _getAspectsForActiveTab();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20), 
            child: Text('PILIH ASPEK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textMuted, letterSpacing: 1.2))
          ),
          ...list.map((e) {
            bool active = _activeCategory == e['t'];
            return InkWell(
              onTap: () => setState(() => _activeCategory = e['t'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: active ? primaryGreen.withValues(alpha: 0.05) : Colors.transparent,
                  border: active ? Border(left: BorderSide(color: primaryGreen, width: 4)) : null,
                ),
                child: Row(
                  children: [
                    Icon(e['i'] as IconData, size: 20, color: active ? primaryGreen : textMuted),
                    const SizedBox(width: 16),
                    Expanded(child: Text(e['t'] as String, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.bold : FontWeight.w500, color: active ? primaryGreen : darkNavy))),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getAspectsForActiveTab() {
    switch (_mainTabController.index) {
      case 0: return [
        {'t': 'Nilai Agama dan Budi Pekerti', 'i': Icons.church_outlined}, 
        {'t': 'Jati Diri', 'i': Icons.person_outline}, 
        {'t': 'Dasar Literasi, Sains, Teknologi, Rekayasa, & Seni', 'i': Icons.menu_book_outlined}
      ];
      case 1: return [{'t': 'Projek Penguatan Profil Lulusan', 'i': Icons.stars_outlined}];
      case 2: return [
        {'t': 'Qiro\'ati', 'i': Icons.menu_book_outlined}, 
        {'t': 'Ibadah', 'i': Icons.auto_awesome_outlined}, 
        {'t': 'Pendidikan Aqidah', 'i': Icons.shield_outlined}, 
        {'t': 'Bahasa Arab', 'i': Icons.translate_outlined}
      ];
      case 3: return [
        {'t': 'Al-Qur\'an', 'i': Icons.book_outlined}, 
        {'t': 'Do\'a-Do\'a', 'i': Icons.volunteer_activism_outlined}, 
        {'t': 'Hadits-Hadits', 'i': Icons.format_quote_outlined}
      ];
      case 4: return [
        {'t': 'Berat Badan', 'i': Icons.monitor_weight_outlined}, 
        {'t': 'Tinggi Badan', 'i': Icons.height_outlined}, 
        {'t': 'Lingkar Kepala', 'i': Icons.face_outlined},
        {'t': 'Hadir', 'i': Icons.check_circle_outline_rounded},
        {'t': 'Sakit', 'i': Icons.sick_outlined},
        {'t': 'Izin', 'i': Icons.mail_outline_rounded},
        {'t': 'Tanpa Keterangan', 'i': Icons.help_outline_rounded},
      ];
      default: return [{'t': 'Refleksi Orang Tua', 'i': Icons.chat_outlined}];
    }
  }

  String _getNarrationTemplate(String category, String code) {
    final name = widget.student['name'] ?? 'Ananda';
    final semester = widget.initialSemester ?? 1;

    if (category == 'Nilai Agama dan Budi Pekerti') {
      if (code == 'BSB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang sangat baik dalam aspek Nilai Agama dan Budi Pekerti. Ananda mampu mengenal dan memahami ajaran agama yang dianutnya serta menerapkannya dalam berbagai kegiatan sehari-hari. Ananda dapat menyebutkan ciptaan Allah, mengenal nama malaikat beserta tugasnya, serta menghafal doa harian, surat-surat pendek, dan hadits pilihan dengan baik. Dalam kesehariannya, Ananda terbiasa mengucapkan salam, bersikap santun kepada guru dan teman, serta menunjukkan perilaku peduli dan suka membantu. Ananda aktif mengikuti kegiatan ibadah, murojaah, qiroati, dan sholat dhuha bersama. Ananda juga mampu mematuhi aturan yang berlaku serta menjadi contoh yang baik bagi teman-temannya di sekolah.';
      } else if (code == 'BSH') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang baik sesuai harapan dalam aspek Nilai Agama dan Budi Pekerti. Ananda mulai memahami ajaran agama yang dianutnya dan mampu mengikuti berbagai kegiatan keagamaan yang dilaksanakan di sekolah. Ananda dapat mengenal beberapa ciptaan Allah, nama malaikat dan tugasnya, serta menghafal doa harian, surat-surat pendek, dan hadits pilihan dengan cukup baik. Dalam kehidupan sehari-hari, Ananda terbiasa mengucapkan salam, bersikap sopan kepada guru dan teman, serta berusaha membantu teman yang membutuhkan. Ananda mengikuti kegiatan ibadah bersama dengan antusias dan mampu mematuhi aturan sederhana yang berlaku meskipun terkadang masih memerlukan arahan dan pendampingan dari guru.';
      } else if (code == 'MB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name mulai menunjukkan perkembangan dalam aspek Nilai Agama dan Budi Pekerti. Ananda mulai mengenal ajaran agama yang dianutnya melalui kegiatan pembelajaran dan pembiasaan yang dilakukan di sekolah. Ananda sudah mampu mengikuti kegiatan ibadah bersama, murojaah, dan qiroati meskipun masih memerlukan bimbingan dalam pelaksanaannya. Ananda mulai mengenal doa harian, surat-surat pendek, hadits pilihan, serta beberapa ciptaan Allah dan nama malaikat. Dalam berinteraksi dengan guru dan teman, Ananda mulai belajar mengucapkan salam, bersikap sopan, serta mengikuti aturan sederhana yang berlaku. Dengan pendampingan dan latihan yang berkelanjutan, Ananda diharapkan dapat berkembang lebih optimal pada semester berikutnya.';
      }
    } else if (category == 'Jati Diri') {
      if (code == 'BSB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang sangat baik dalam aspek Jati Diri. Ananda mampu menjaga kebersihan diri secara mandiri, seperti mencuci tangan sebelum dan sesudah kegiatan serta membiasakan pola hidup sehat. Ananda mau mencoba berbagai jenis makanan bergizi, seperti sayuran dan buah-buahan, sebagai bentuk penerapan kebiasaan makan sehat. Ananda menunjukkan rasa percaya diri yang tinggi dalam berbagai kegiatan, berani tampil di depan kelas, dan antusias mencoba pengalaman baru. Ananda mampu mengenali serta mengungkapkan emosinya dengan baik, mudah bergaul, bekerja sama, berbagi dengan teman, serta aktif mengikuti kegiatan olahraga yang mendukung kesehatan dan kebugaran tubuh.';
      } else if (code == 'BSH') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang baik sesuai harapan dalam aspek Jati Diri. Ananda mulai terbiasa menjaga kebersihan diri, seperti mencuci tangan sebelum dan sesudah kegiatan, serta berusaha menerapkan pola hidup sehat. Ananda mau mencoba berbagai makanan bergizi dan berpartisipasi dalam kegiatan merapikan lingkungan kelas bersama teman-teman. Ananda menunjukkan kepercayaan diri yang baik saat mengikuti kegiatan pembelajaran dan sesekali berani tampil di depan kelas. Ananda mampu mengenali perasaan yang dialaminya, berinteraksi dengan teman secara positif, bekerja sama dalam kelompok, serta mengikuti kegiatan olahraga dengan antusias meskipun terkadang masih memerlukan motivasi dari guru.';
      } else if (code == 'MB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name mulai menunjukkan perkembangan dalam aspek Jati Diri. Ananda mulai belajar menjaga kebersihan diri, seperti mencuci tangan sebelum dan sesudah kegiatan dengan bimbingan guru. Ananda mulai mengenal pentingnya mengonsumsi makanan bergizi dan berpartisipasi dalam kegiatan menjaga kebersihan kelas. Dalam kegiatan pembelajaran, Ananda mulai menunjukkan keberanian untuk mencoba hal-hal baru dan berinteraksi dengan teman-temannya. Ananda juga mulai belajar mengenali serta mengungkapkan perasaannya dengan tepat. Pada kegiatan olahraga, Ananda mengikuti aktivitas dengan baik meskipun masih memerlukan arahan dan motivasi agar lebih aktif dan percaya diri dalam berbagai kegiatan sekolah.';
      }
    } else if (category == 'Dasar Literasi, Sains, Teknologi, Rekayasa, & Seni') {
      if (code == 'BSB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang sangat baik dalam aspek Dasar Literasi dan Matematika, Sains, Teknologi, Rekayasa, dan Seni (STEAM). Ananda memiliki rasa ingin tahu yang tinggi serta aktif mengamati, bertanya, dan mencari tahu berbagai hal di sekitarnya. Ananda mampu mengenali pola, bentuk, ukuran, dan hubungan antar benda dengan baik. Dalam kegiatan pemecahan masalah, Ananda dapat menyusun puzzle, membangun konstruksi menggunakan balok, serta menciptakan berbagai karya dari beragam media. Ananda juga kreatif dalam menggambar, mewarnai, bermain peran, dan mengekspresikan ide-idenya. Ananda mampu bekerja sama dengan teman, fokus dalam belajar, serta menunjukkan semangat belajar yang tinggi pada setiap kegiatan.';
      } else if (code == 'BSH') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang baik sesuai harapan dalam aspek Dasar Literasi dan Matematika, Sains, Teknologi, Rekayasa, dan Seni (STEAM). Ananda menunjukkan rasa ingin tahu yang baik melalui kegiatan mengamati, bertanya, dan mencoba berbagai pengalaman belajar yang diberikan. Ananda mampu mengenali beberapa pola, bentuk geometri, ukuran, dan hubungan sederhana antar benda. Dalam kegiatan pemecahan masalah, Ananda dapat menyusun puzzle, bermain balok, dan membuat karya sederhana dengan bimbingan yang minimal. Ananda juga aktif dalam kegiatan menggambar, mewarnai, serta bermain peran. Ananda mampu bekerja sama dengan teman dan menunjukkan semangat belajar yang baik selama mengikuti kegiatan pembelajaran.';
      } else if (code == 'MB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name mulai menunjukkan perkembangan dalam aspek Dasar Literasi dan Matematika, Sains, Teknologi, Rekayasa, dan Seni (STEAM). Ananda mulai menunjukkan rasa ingin tahu terhadap berbagai kegiatan pembelajaran melalui kegiatan mengamati dan mencoba. Ananda mulai mengenal bentuk, pola, ukuran, dan hubungan sederhana antar benda yang ada di sekitarnya. Dalam kegiatan pemecahan masalah, Ananda berusaha menyusun puzzle, bermain balok, dan membuat karya sederhana meskipun masih memerlukan arahan dari guru. Ananda juga mulai berpartisipasi dalam kegiatan menggambar, mewarnai, dan bermain peran. Dengan bimbingan yang berkelanjutan, Ananda diharapkan semakin percaya diri, kreatif, dan aktif dalam proses pembelajaran.';
      }
    } else if (category == 'Projek Penguatan Profil Lulusan') {
      if (code == 'BSB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang sangat baik dalam kegiatan Projek Penguatan Profil Lulusan. Ananda aktif mengikuti setiap tahapan projek dengan penuh antusias, mulai dari mengamati, bertanya, mencoba, hingga menyampaikan hasil kegiatan. Ananda mampu bekerja sama dengan teman, berbagi tugas, dan menunjukkan sikap tanggung jawab dalam menyelesaikan kegiatan yang diberikan. Ananda juga menunjukkan rasa percaya diri saat menyampaikan pendapat maupun hasil karyanya di depan kelas. Kreativitas Ananda terlihat dalam berbagai kegiatan projek yang melibatkan eksplorasi, pemecahan masalah, dan pembuatan karya. Ananda mampu menerapkan nilai-nilai karakter positif seperti gotong royong, disiplin, peduli, mandiri, dan gemar belajar dalam kehidupan sehari-hari.';
      } else if (code == 'BSH') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang baik sesuai harapan dalam kegiatan Projek Penguatan Profil Lulusan. Ananda mengikuti kegiatan projek dengan antusias and berpartisipasi dalam berbagai aktivitas yang dilaksanakan di sekolah. Ananda mampu bekerja sama dengan teman dalam kelompok, berbagi peran, serta menyelesaikan tugas dengan bimbingan yang minimal. Ananda mulai menunjukkan rasa percaya diri untuk menyampaikan ide and hasil karyanya kepada guru maupun teman. Melalui kegiatan projek, Ananda belajar mengembangkan sikap mandiri, tanggung jawab, disiplin, peduli, dan gotong royong. Ananda juga menunjukkan minat yang baik dalam mengeksplorasi pengalaman baru serta belajar dari lingkungan sekitarnya.';
      } else if (code == 'MB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name mulai menunjukkan perkembangan dalam kegiatan Projek Penguatan Profil Lulusan. Ananda mulai terlibat dalam berbagai kegiatan projek yang dilaksanakan di sekolah dan menunjukkan ketertarikan untuk mengikuti setiap tahap kegiatan. Ananda berusaha bekerja sama dengan teman, mengikuti arahan guru, serta menyelesaikan tugas yang diberikan sesuai kemampuannya. Ananda mulai belajar menyampaikan pendapat, menunjukkan hasil karya, dan berpartisipasi dalam diskusi sederhana bersama teman. Melalui kegiatan projek, Ananda mulai mengenal nilai-nilai positif seperti disiplin, tanggung jawab, kepedulian, kemandirian, dan gotong royong. Dengan pendampingan yang berkelanjutan, Ananda diharapkan semakin aktif, percaya diri, dan kreatif dalam kegiatan projek berikutnya.';
      }
    } else if (category == 'Qiro\'ati') {
      if (code == 'BSB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang baik dalam pembelajaran Qiroati dengan target Jilid Pra TK A. Ananda mengikuti kegiatan belajar dengan antusias, semangat, dan rasa ingin tahu yang baik. Ananda mulai mengenal huruf-huruf hijaiyah serta mampu menyebutkan dan membedakan beberapa huruf yang telah dipelajari. Dalam kegiatan pembelajaran, Ananda aktif mengikuti murojaah, menyimak bacaan guru, dan berusaha mengulang kembali materi yang telah diajarkan. Ananda juga menunjukkan sikap disiplin saat mengikuti kegiatan Qiroati dan mampu mengikuti arahan guru dengan baik. Dengan latihan yang rutin, pendampingan yang berkelanjutan, serta dukungan dari orang tua, kemampuan membaca Al-Qur\'an Ananda diharapkan semakin berkembang dan siap melanjutkan ke tahap pembelajaran berikutnya sesuai target yang telah ditetapkan.';
      } else if (code == 'BSH') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang baik sesuai harapan dalam pembelajaran Qiroati dengan target Jilid Pra TK A. Ananda mulai mengenal huruf-huruf hijaiyah dan mampu mengikuti pembelajaran yang diberikan oleh guru dengan cukup baik. Ananda aktif mengikuti kegiatan murojaah, menyimak bacaan guru, dan berusaha mengulang kembali materi yang telah diajarkan. Ananda juga menunjukkan sikap disiplin saat mengikuti kegiatan Qiroati dan mampu mengikuti arahan guru. Dengan latihan yang rutin, pendampingan yang berkelanjutan, serta dukungan dari orang tua, kemampuan membaca Al-Qur\'an Ananda diharapkan semakin berkembang.';
      } else if (code == 'MB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name mulai menunjukkan perkembangan dalam pembelajaran Qiroati dengan target Jilid Pra TK A. Ananda mulai mengenal huruf-huruf hijaiyah dan berusaha mengikuti pembelajaran yang diberikan oleh guru. Dalam kegiatan murojaah dan latihan membaca, Ananda menunjukkan ketertarikan untuk belajar meskipun masih memerlukan bimbingan dan pendampingan secara rutin. Ananda mampu mengikuti sebagian materi yang diajarkan sesuai tahap perkembangannya dan mulai berani mengulangi bacaan yang dicontohkan oleh guru. Dengan latihan yang lebih konsisten, motivasi yang berkelanjutan, serta dukungan dari orang tua dan guru, kemampuan Ananda dalam pembelajaran Qiroati diharapkan dapat berkembang lebih baik pada semester berikutnya.';
      }
    } else if (category == 'Ibadah') {
      if (code == 'BSB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang sangat baik dalam aspek Ibadah. Ananda terbiasa mengikuti berbagai kegiatan ibadah di sekolah dengan penuh antusias dan tanggung jawab. Ananda mampu mengikuti kegiatan sholat dhuha bersama, berdoa sebelum dan sesudah kegiatan, serta menghafal beberapa doa harian dengan baik. Ananda juga menunjukkan sikap khusyuk dan tertib saat mengikuti kegiatan keagamaan serta mampu mencontohkan perilaku yang sesuai dengan nilai-nilai agama dalam kehidupan sehari-hari. Selain itu, Ananda senang mengikuti kegiatan murojaah, ikrar, dan pembelajaran keagamaan lainnya. Dengan perkembangan yang dicapai, Ananda diharapkan dapat terus meningkatkan kebiasaan ibadahnya baik di sekolah maupun di rumah.';
      } else if (code == 'BSH') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang baik sesuai harapan dalam aspek Ibadah. Ananda mampu mengikuti kegiatan ibadah yang dilaksanakan di sekolah seperti sholat dhuha bersama, berdoa sebelum dan sesudah kegiatan, serta mengikuti murojaah dengan baik. Ananda menunjukkan sikap tertib dan antusias selama kegiatan berlangsung serta mulai memahami pentingnya melaksanakan ibadah dalam kehidupan sehari-hari. Ananda juga mampu menghafal beberapa doa harian sesuai tahap perkembangannya. Meskipun sesekali masih memerlukan arahan dan penguatan dari guru, Ananda terus berusaha mengikuti seluruh kegiatan dengan baik. Diharapkan kebiasaan ibadah Ananda semakin berkembang dan menjadi bagian dari kehidupan sehari-harinya.';
      } else if (code == 'MB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name mulai menunjukkan perkembangan dalam aspek Ibadah. Ananda mulai mengenal dan mengikuti berbagai kegiatan ibadah yang dilaksanakan di sekolah, seperti berdoa sebelum dan sesudah kegiatan, sholat dhuha bersama, serta murojaah sederhana. Ananda menunjukkan minat yang baik untuk mengikuti kegiatan keagamaan meskipun masih memerlukan bimbingan dan pendampingan dari guru dalam beberapa kegiatan. Ananda mulai menghafal doa-doa harian dan berusaha mengikuti bacaan yang dicontohkan oleh guru. Dengan latihan yang rutin, dukungan dari orang tua, serta pembiasaan yang berkelanjutan, diharapkan kemampuan dan kebiasaan ibadah Ananda dapat berkembang lebih baik pada semester berikutnya.';
      }
    } else if (category == 'Pendidikan Aqidah') {
      if (code == 'BSB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang sangat baik dalam Pendidikan Aqidah. Ananda mampu mengenal dan memahami dasar-dasar keimanan sesuai tahap perkembangannya, seperti mengenal Allah sebagai Pencipta, mengenal para malaikat beserta tugasnya, serta memahami bahwa segala sesuatu yang ada di alam semesta merupakan ciptaan Allah SWT. Ananda aktif mengikuti pembelajaran, menjawab pertanyaan guru, dan menunjukkan rasa ingin tahu yang tinggi terhadap materi yang dipelajari. Dalam kesehariannya, Ananda juga mulai menerapkan nilai-nilai keimanan melalui perilaku yang baik, jujur, santun, dan peduli kepada sesama. Ananda menunjukkan antusiasme yang tinggi dan mampu mengikuti pembelajaran dengan sangat baik.';
      } else if (code == 'BSH') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang baik sesuai harapan dalam Pendidikan Aqidah. Ananda mulai memahami dasar-dasar keimanan yang diajarkan di sekolah, seperti mengenal Allah SWT sebagai Pencipta, mengenal beberapa malaikat beserta tugasnya, dan memahami bahwa manusia harus bersyukur atas nikmat yang diberikan Allah. Ananda mengikuti kegiatan pembelajaran dengan baik dan mampu menjawab beberapa pertanyaan sederhana yang berkaitan dengan materi aqidah. Dalam kehidupan sehari-hari, Ananda mulai menunjukkan perilaku yang mencerminkan nilai-nilai keimanan seperti bersikap sopan, jujur, dan menghormati orang lain. Ananda mengikuti pembelajaran dengan antusias dan menunjukkan kemajuan yang baik selama semester ini.';
      } else if (code == 'MB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name mulai menunjukkan perkembangan dalam Pendidikan Aqidah. Ananda mulai mengenal konsep dasar keimanan melalui berbagai kegiatan pembelajaran yang diberikan di sekolah. Ananda mulai memahami bahwa Allah SWT adalah Pencipta alam semesta dan mengenal beberapa materi aqidah sederhana sesuai tahap perkembangannya. Dalam proses pembelajaran, Ananda menunjukkan minat untuk mengikuti kegiatan meskipun masih memerlukan bimbingan dan penguatan dari guru. Ananda juga mulai belajar menerapkan nilai-nilai keimanan dalam kehidupan sehari-hari melalui sikap sopan, jujur, dan menghargai orang lain. Dengan pembiasaan yang berkelanjutan, diharapkan pemahaman dan pengamalan aqidah Ananda semakin berkembang pada semester berikutnya.';
      }
    } else if (category == 'Bahasa Arab') {
      if (code == 'BSB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang sangat baik dalam pembelajaran Bahasa Arab. Ananda mampu mengenal dan menghafal kosakata (mufrodat) yang telah diajarkan sesuai tema pembelajaran dengan baik. Ananda aktif mengikuti kegiatan pembelajaran, berani mengucapkan kosakata Bahasa Arab dengan pelafalan yang cukup jelas, serta mampu memahami arti dari beberapa kosakata yang dipelajari. Dalam kegiatan bernyanyi, bermain, dan percakapan sederhana, Ananda menunjukkan antusiasme yang tinggi dan percaya diri. Ananda juga mampu mengingat kembali kosakata yang telah dipelajari serta menggunakannya dalam kegiatan sehari-hari di sekolah. Kemampuan ini menunjukkan perkembangan yang sangat baik sesuai target pembelajaran semester ini.';
      } else if (code == 'BSH') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang baik sesuai harapan dalam pembelajaran Bahasa Arab. Ananda mampu mengenal dan menghafal beberapa kosakata (mufrodat) yang diajarkan sesuai dengan tema pembelajaran. Ananda mengikuti kegiatan pembelajaran dengan antusias serta berusaha mengucapkan kosakata Bahasa Arab yang dicontohkan oleh guru. Dalam kegiatan bernyanyi, permainan edukatif, dan percakapan sederhana, Ananda mampu berpartisipasi dengan baik. Ananda juga mulai memahami arti dari beberapa kosakata yang sering digunakan dalam kegiatan sehari-hari di sekolah. Meskipun masih memerlukan latihan untuk meningkatkan kelancaran pelafalan dan daya ingat, Ananda menunjukkan semangat belajar yang baik selama proses pembelajaran berlangsung.';
      } else if (code == 'MB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name mulai menunjukkan perkembangan dalam pembelajaran Bahasa Arab. Ananda mulai mengenal berbagai kosakata (mufrodat) sederhana yang diajarkan melalui kegiatan bermain, bernyanyi, bercerita, dan pembelajaran di kelas. Ananda menunjukkan minat untuk mengikuti kegiatan pembelajaran serta berusaha mengulang kosakata yang dicontohkan oleh guru. Dalam beberapa kesempatan, Ananda sudah mampu mengingat dan menyebutkan kosakata sederhana meskipun masih memerlukan bimbingan dan pengulangan secara rutin. Ananda juga mulai memahami arti dari beberapa kosakata yang sering digunakan dalam kegiatan sehari-hari. Dengan latihan yang berkelanjutan dan pendampingan yang konsisten, kemampuan Bahasa Arab Ananda diharapkan semakin berkembang pada semester berikutnya.';
      }
    } else if (category == 'Al-Qur\'an') {
      if (code == 'BSB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang sangat baik dalam pembelajaran Al-Qur\'an. Ananda mampu mengikuti kegiatan membaca dan menghafal Al-Qur\'an dengan penuh semangat dan antusias. Ananda dapat menghafal surat-surat pendek sesuai target pembelajaran, melafalkan ayat-ayat Al-Qur\'an dengan cukup baik, serta aktif mengikuti kegiatan murojaah bersama guru dan teman-teman. Ananda menunjukkan sikap disiplin, percaya diri, dan konsisten dalam mengikuti pembelajaran Al-Qur\'an. Selain itu, Ananda mampu menyimak bacaan dengan baik dan berusaha memperbaiki bacaan sesuai arahan guru. Dengan perkembangan yang dicapai, Ananda diharapkan terus meningkatkan kecintaan terhadap Al-Qur\'an serta mengamalkan nilai-nilai yang terkandung di dalamnya.';
      } else if (code == 'BSH') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang baik sesuai harapan dalam pembelajaran Al-Qur\'an. Ananda mampu mengikuti kegiatan membaca, menghafal, dan murojaah Al-Qur\'an dengan baik sesuai tahap perkembangannya. Ananda dapat menghafal beberapa surat pendek yang menjadi target pembelajaran semester ini serta berusaha melafalkan ayat-ayat Al-Qur\'an dengan benar sesuai contoh yang diberikan guru. Dalam kegiatan pembelajaran, Ananda menunjukkan antusiasme dan semangat belajar yang baik. Meskipun masih memerlukan latihan untuk meningkatkan kelancaran dan ketepatan bacaan, Ananda terus menunjukkan kemajuan yang positif. Diharapkan Ananda dapat terus berlatih agar kemampuan membaca dan menghafal Al-Qur\'annya semakin berkembang.';
      } else if (code == 'MB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name mulai menunjukkan perkembangan dalam pembelajaran Al-Qur\'an. Ananda mulai mengenal dan menghafal surat-surat pendek melalui kegiatan murojaah dan pembelajaran yang dilaksanakan di sekolah. Ananda menunjukkan minat yang baik dalam mengikuti kegiatan membaca dan menghafal Al-Qur\'an serta berusaha mengikuti bacaan yang dicontohkan oleh guru. Meskipun masih memerlukan bimbingan dan pengulangan secara rutin, Ananda mulai mampu mengingat beberapa ayat dan surat pendek sesuai kemampuan yang dimiliki. Dengan latihan yang konsisten, pendampingan dari guru, serta dukungan orang tua di rumah, kemampuan membaca dan menghafal Al-Qur\'an Ananda diharapkan semakin berkembang pada semester berikutnya.';
      }
    } else if (category == 'Do\'a-Do\'a') {
      if (code == 'BSB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang sangat baik dalam hafalan dan pembiasaan doa-doa harian. Ananda mampu menghafal serta melafalkan berbagai doa harian sesuai target pembelajaran dengan baik dan lancar. Ananda terbiasa membaca doa sebelum dan sesudah melakukan kegiatan, seperti doa sebelum makan, sesudah makan, sebelum belajar, sesudah belajar, serta doa sebelum dan sesudah tidur. Dalam kegiatan pembelajaran, Ananda aktif mengikuti murojaah dan mampu mengingat kembali doa-doa yang telah dipelajari. Ananda juga menunjukkan antusiasme yang tinggi serta memahami pentingnya berdoa sebagai bentuk rasa syukur dan ketergantungan kepada Allah SWT dalam kehidupan sehari-hari.';
      } else if (code == 'BSH') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang baik sesuai harapan dalam hafalan dan pembiasaan doa-doa harian. Ananda mampu menghafal beberapa doa harian yang menjadi target pembelajaran serta berusaha melafalkannya dengan baik dalam kegiatan sehari-hari. Ananda mengikuti kegiatan murojaah dengan antusias dan mampu mengingat sebagian besar doa yang telah dipelajari. Dalam berbagai aktivitas di sekolah, Ananda mulai terbiasa membaca doa sebelum dan sesudah melakukan kegiatan. Meskipun masih memerlukan penguatan pada beberapa hafalan, Ananda menunjukkan semangat belajar yang baik dan terus mengalami perkembangan yang positif selama proses pembelajaran berlangsung.';
      } else if (code == 'MB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name mulai menunjukkan perkembangan dalam hafalan dan pembiasaan doa-doa harian. Ananda mulai mengenal dan menghafal beberapa doa sederhana yang diajarkan di sekolah melalui kegiatan pembiasaan dan murojaah bersama. Ananda menunjukkan minat yang baik untuk mengikuti kegiatan hafalan serta berusaha melafalkan doa yang dicontohkan oleh guru. Meskipun masih memerlukan bimbingan dan pengulangan secara rutin, Ananda mulai mampu mengingat beberapa doa harian sesuai tahap perkembangannya. Dengan latihan yang berkelanjutan, pendampingan dari guru, dan dukungan orang tua di rumah, kemampuan hafalan serta pembiasaan doa harian Ananda diharapkan semakin berkembang pada semester berikutnya.';
      }
    } else if (category == 'Hadits-Hadits') {
      if (code == 'BSB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang sangat baik dalam pembelajaran Hadits-Hadits Pilihan. Ananda mampu menghafal hadits-hadits yang menjadi target pembelajaran dengan baik dan menunjukkan kelancaran dalam melafalkannya. Ananda aktif mengikuti kegiatan murojaah, menyimak penjelasan guru, serta mampu mengingat kembali hadits yang telah dipelajari. Selain menghafal, Ananda juga mulai memahami makna sederhana dari hadits dan berusaha menerapkannya dalam kehidupan sehari-hari, seperti bersikap sopan, jujur, saling menyayangi, dan menghormati orang lain. Ananda menunjukkan antusiasme yang tinggi dalam setiap kegiatan pembelajaran serta memiliki semangat belajar yang sangat baik. Semoga Ananda terus mencintai dan mengamalkan ajaran Rasulullah SAW.';
      } else if (code == 'BSH') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name menunjukkan perkembangan yang baik sesuai harapan dalam pembelajaran Hadits-Hadits Pilihan. Ananda mampu menghafal beberapa hadits yang menjadi target pembelajaran dan berusaha melafalkannya dengan baik. Ananda mengikuti kegiatan murojaah dengan antusias serta mampu mengingat kembali sebagian besar hadits yang telah dipelajari. Melalui pembelajaran hadits, Ananda mulai memahami pesan-pesan sederhana yang terkandung di dalamnya dan berusaha menerapkannya dalam kehidupan sehari-hari. Meskipun masih memerlukan latihan pada beberapa hafalan, Ananda menunjukkan semangat belajar yang baik serta perkembangan yang positif selama mengikuti kegiatan pembelajaran. Diharapkan kemampuan hafalan dan pemahaman Ananda semakin meningkat pada semester berikutnya.';
      } else if (code == 'MB') {
        return 'Alhamdulillah pada Semester $semester ini, Ananda $name mulai menunjukkan perkembangan dalam pembelajaran Hadits-Hadits Pilihan. Ananda mulai mengenal dan menghafal beberapa hadits sederhana yang diajarkan di sekolah melalui kegiatan pembiasaan dan murojaah bersama. Ananda menunjukkan minat yang baik untuk mengikuti kegiatan hafalan serta berusaha melafalkan hadits yang dicontohkan oleh guru. Meskipun masih memerlukan bimbingan dan pengulangan secara rutin, Ananda mulai mampu mengingat beberapa hadits sesuai tahap perkembangannya. Dengan latihan yang berkelanjutan, pendampingan dari guru, dan dukungan orang tua di rumah, kemampuan hafalan serta pembiasaan hadits Ananda diharapkan semakin berkembang pada semester berikutnya.';
      }
    }
    return '';
  }

  Widget _buildEditorContent(String category) {
    final numericCats = ['Berat Badan', 'Tinggi Badan', 'Lingkar Kepala', 'Hadir', 'Sakit', 'Izin', 'Tanpa Keterangan'];
    final materialCats = ['Qiro\'ati', 'Ibadah', 'Pendidikan Aqidah', 'Bahasa Arab', 'Al-Qur\'an', 'Do\'a-Do\'a', 'Hadits-Hadits'];
    
    bool isNumeric = numericCats.contains(category);
    bool hasMaterial = materialCats.contains(category);

    return Container(
      padding: _isMobile ? EdgeInsets.zero : const EdgeInsets.all(32),
      decoration: _isMobile ? null : BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isMobile) ...[
            Text(category, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkNavy)),
            const SizedBox(height: 24),
          ],
          
          if (!isNumeric && category != 'Refleksi Orang Tua') ...[
            Text('Level Penilaian', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            _isMobile ? Column(
              children: [
                Row(children: [_levelOption(category, 'BSB', 'Sangat Baik', colorBSB), const SizedBox(width: 8), _levelOption(category, 'BSH', 'Sesuai Harapan', colorBSH)]),
                const SizedBox(height: 8),
                Row(children: [_levelOption(category, 'MB', 'Mulai Berkembang', colorMB)]),
              ],
            ) : Row(
              children: [
                _levelOption(category, 'BSB', 'Berkembang\nSangat Baik', colorBSB),
                const SizedBox(width: 12),
                _levelOption(category, 'BSH', 'Berkembang\nSesuai Harapan', colorBSH),
                const SizedBox(width: 12),
                _levelOption(category, 'MB', 'Mulai\nBerkembang', colorMB),
              ],
            ),
            if (['Nilai Agama dan Budi Pekerti', 'Jati Diri', 'Dasar Literasi, Sains, Teknologi, Rekayasa, & Seni', 'Projek Penguatan Profil Lulusan', 'Qiro\'ati', 'Ibadah', 'Pendidikan Aqidah', 'Bahasa Arab', 'Al-Qur\'an', 'Do\'a-Do\'a', 'Hadits-Hadits'].contains(category) && _grades[category] != '') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final template = _getNarrationTemplate(category, _grades[category]!);
                    final controller = _notesControllers[category];
                    if (controller != null) {
                      if (controller.text.isEmpty) {
                        controller.text = template;
                      } else {
                        // Tambahkan di bawah teks yang sudah ada
                        controller.text = '${controller.text}\n\n$template';
                      }
                      // Pindahkan kursor ke akhir
                      controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: controller.text.length),
                      );
                    }
                    setState(() {});
                  },
                  icon: Icon(Icons.auto_fix_high_rounded, size: 18, color: primaryGreen),
                  label: Text('Gunakan Narasi Otomatis (${_grades[category]})', style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],

          if (hasMaterial) ...[
            Text('Materi / Target', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            TextField(
              controller: _materialControllers[category],
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Tulis materi yang diajarkan...',
                filled: true,
                fillColor: bgLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
          ],

          Text(isNumeric ? 'Nilai / Jumlah' : 'Catatan Perkembangan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          if (isNumeric) 
            TextField(
              controller: _notesControllers[category],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                filled: true,
                fillColor: bgLight,
                hintText: 'Contoh: 15',
                prefixIcon: Icon(Icons.edit_note, color: primaryGreen),
              ),
              onChanged: (val) => _grades[category] = val,
            )
          else
            _buildEditorBox(category),
          
          if (!isNumeric && ['Nilai Agama dan Budi Pekerti', 'Jati Diri', 'Dasar Literasi, Sains, Teknologi, Rekayasa, & Seni', 'Projek Penguatan Profil Lulusan'].contains(category)) ...[
            const SizedBox(height: 24),
            Text('Dokumentasi (Maks 3)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            _buildImagePickerSection(category),
          ],
          
          if (!isNumeric) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: primaryGreen.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 20, color: primaryGreen),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Catatan ini akan muncul otomatis di laporan PDF rapor.', style: TextStyle(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _levelOption(String category, String code, String desc, Color color) {
    bool sel = _grades[category] == code;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _grades[category] = code),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? color : const Color(0xFFE2E8F0), width: 2),
          ),
          child: Column(
            children: [
              Text(code, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              Text(desc, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickerSection(String category) {
    final images = _selectedImages[category] ?? [];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ...images.asMap().entries.map((entry) {
          final idx = entry.key;
          final img = entry.value;
          return Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: img is String
                      ? (img.startsWith('http') 
                          ? Image.network(img, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.red))
                          : Image.file(File(img.startsWith('file://') ? Uri.parse(img).toFilePath() : img), fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.red)))
                      : Image.file(img, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.red)),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: () => setState(() => _selectedImages[category]!.removeAt(idx)),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),
        if (images.length < 3)
          InkWell(
            onTap: () => _pickImage(category),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: bgLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded, color: primaryGreen, size: 24),
                  const SizedBox(height: 4),
                  Text('Foto', style: TextStyle(fontSize: 10, color: primaryGreen, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEditorBox(String category) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)), 
        borderRadius: BorderRadius.circular(12)
      ),
      child: TextField(
        controller: _notesControllers[category],
        maxLines: 8,
        style: TextStyle(fontSize: 14, height: 1.6, color: darkNavy),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.all(16),
          border: InputBorder.none, 
          hintText: 'Tulis deskripsi di sini...'
        ),
        onChanged: (v) => setState(() {}),
      ),
    );
  }

  Widget _buildBottomActionFrame() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Row(
        children: [
          const Spacer(),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _saveGrades,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Simpan Penilaian', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen, 
              foregroundColor: Colors.white, 
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
              elevation: 0
            ),
          ),
        ],
      ),
    );
  }
}
