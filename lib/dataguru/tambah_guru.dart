import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../utils/notification_helper.dart';
import '../utils/push_notification_service.dart';

class TambahGuruPage extends StatefulWidget {
  final Map<String, dynamic>? teacher;
  final bool isEmbedded;
  final VoidCallback? onBack;
  const TambahGuruPage({super.key, this.teacher, this.isEmbedded = false, this.onBack});

  @override
  State<TambahGuruPage> createState() => _TambahGuruPageState();
}

class _TambahGuruPageState extends State<TambahGuruPage> {
  final _formKey = GlobalKey<FormState>();
  int _activeStep = 0;
  bool _isLoading = false;
  final apiService = ApiService();

  // --- Controllers Data Pribadi (Step 1) ---
  final _nipCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _birthPlaceCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // --- Controllers Pendidikan & Pekerjaan (Step 2) ---
  final _majorCtrl = TextEditingController();
  final _univCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _rankCtrl = TextEditingController();
  final _npwpCtrl = TextEditingController();
  final _dependentsCtrl = TextEditingController();
  final _waliKelasCtrl = TextEditingController();
  final _angkatanWaliCtrl = TextEditingController();

  // --- Controllers Kontak (Step 3) ---
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String? _selectedGender = 'Laki-laki';
  String? _selectedReligion;
  String? _selectedEducation;
  String? _selectedRole;
  String? _selectedEmploymentStatus = 'HONORER';
  String? _selectedMaritalStatus;

  List<String> _classList = ['Bukan Wali Kelas'];
  List<String> _batchList = ['-'];
  List<String> _rombelList = ['-'];
  List<String> _masterClasses = [];
  List<String> _masterBatches = [];
  List<String> _masterRombels = [];
  Set<String> _occupiedPairs = {};
  String _selectedWaliKelas = 'Bukan Wali Kelas';
  String _selectedAngkatanWali = '-';
  String _selectedRombelWali = '-';
  Color get primaryTeal => AppColors.isDark ? AppColors.brand : AppColors.primary;
  final Color backgroundColor = AppColors.backgroundColor;
  final Color textDark = AppColors.textDark;
  final Color textSecondary = AppColors.textSecondary;
  final Color textMuted = AppColors.textMuted;
  final Color borderColor = AppColors.borderColor;
  final Color errorRed = const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _fetchClassBatch();
    if (widget.teacher != null) {
      final t = widget.teacher!;
      _nipCtrl.text = t['nip'] ?? '';
      _nikCtrl.text = t['nik'] ?? '';
      _nameCtrl.text = t['name'] ?? '';
      _birthPlaceCtrl.text = t['birth_place'] ?? '';
      _birthDateCtrl.text = t['birth_date'] ?? '';
      _addressCtrl.text = t['address'] ?? '';
      _majorCtrl.text = t['major'] ?? '';
      _univCtrl.text = t['university'] ?? '';
      _subjectCtrl.text = t['subject'] ?? '';
      _phoneCtrl.text = t['phone'] ?? '';
      _emailCtrl.text = t['email'] ?? '';

      _selectedGender = t['gender'] == 'L' ? 'Laki-laki' : (t['gender'] == 'P' ? 'Perempuan' : (t['gender'] ?? 'Laki-laki'));
      _selectedReligion = t['religion'];
      _selectedEducation = t['last_education'];
      _selectedRole = t['role'];
      _selectedEmploymentStatus = t['employment_status'] ?? 'HONORER';
      _startDateCtrl.text = t['start_date'] ?? '';
      _rankCtrl.text = t['rank_grade'] ?? '';
      _npwpCtrl.text = t['npwp'] ?? '';
      _dependentsCtrl.text = t['number_of_dependents']?.toString() ?? '';
      _selectedMaritalStatus = t['marital_status'];
      _selectedWaliKelas = t['wali_kelas'] ?? 'Bukan Wali Kelas';
      _selectedAngkatanWali = t['angkatan_wali'] ?? '-';
      _selectedRombelWali = t['rombel_wali'] ?? '-';
    }
  }

  Future<void> _fetchClassBatch() async {
    try {
      // 1. Fetch all unique classes, batches, and rombels from students
      final students = await apiService.getTable('students');
      _masterClasses = students
          .map((s) => s['class']?.toString() ?? '')
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()..sort();
      _masterBatches = students
          .map((s) => s['batch']?.toString() ?? '')
          .where((b) => b.isNotEmpty)
          .toSet()
          .toList()..sort();
      _masterRombels = students
          .map((s) => s['rombel']?.toString() ?? '')
          .where((r) => r.isNotEmpty)
          .toSet()
          .toList()..sort();

      // 2. Fetch all currently assigned wali_kelas combinations from teachers table
      final teachersData = await apiService.getTable('teachers');
      _occupiedPairs = teachersData
          .where((t) => t['wali_kelas'] != null && t['angkatan_wali'] != null && t['rombel_wali'] != null)
          .map((t) => "${t['wali_kelas']}|${t['rombel_wali']}|${t['angkatan_wali']}")
          .toSet();

      // 3. If editing, remove current teacher's combination from occupied so it remains selectable
      if (widget.teacher != null) {
        final currentWali = widget.teacher!['wali_kelas'];
        final currentRombel = widget.teacher!['rombel_wali'];
        final currentAngkatan = widget.teacher!['angkatan_wali'];
        if (currentWali != null && currentRombel != null && currentAngkatan != null) {
          _occupiedPairs.remove("$currentWali|$currentRombel|$currentAngkatan");
        }
      }

      if (mounted) {
        _updateAvailableOptions();
      }
    } catch (e) {
      debugPrint('Error fetching classes/batches: $e');
    }
  }

  void _updateAvailableOptions() {
    setState(() {
      // Filter Classes based on selected Rombel & Batch
      if (_selectedRombelWali == '-' && _selectedAngkatanWali == '-') {
        _classList = ['Bukan Wali Kelas', ..._masterClasses];
      } else {
        final availableClasses = _masterClasses.where((c) {
          return !_occupiedPairs.contains("$c|$_selectedRombelWali|$_selectedAngkatanWali");
        }).toList();
        _classList = ['Bukan Wali Kelas', ...availableClasses];
      }

      // Filter Rombels based on selected Class & Batch
      if (_selectedWaliKelas == 'Bukan Wali Kelas' && _selectedAngkatanWali == '-') {
        _rombelList = ['-', ..._masterRombels];
      } else {
        final availableRombels = _masterRombels.where((r) {
          return !_occupiedPairs.contains("$_selectedWaliKelas|$r|$_selectedAngkatanWali");
        }).toList();
        _rombelList = ['-', ...availableRombels];
      }

      // Filter Batches based on selected Class & Rombel
      if (_selectedWaliKelas == 'Bukan Wali Kelas' && _selectedRombelWali == '-') {
        _batchList = ['-', ..._masterBatches];
      } else {
        final availableBatches = _masterBatches.where((b) {
          return !_occupiedPairs.contains("$_selectedWaliKelas|$_selectedRombelWali|$b");
        }).toList();
        _batchList = ['-', ...availableBatches];
      }

      // Ensure selections are still valid in the new lists
      if (!_classList.contains(_selectedWaliKelas)) {
        _selectedWaliKelas = 'Bukan Wali Kelas';
      }
      if (!_rombelList.contains(_selectedRombelWali)) {
        _selectedRombelWali = '-';
      }
      if (!_batchList.contains(_selectedAngkatanWali)) {
        _selectedAngkatanWali = '-';
      }
    });
  }

  @override
  void dispose() {
    _nipCtrl.dispose();
    _nikCtrl.dispose();
    _nameCtrl.dispose();
    _birthPlaceCtrl.dispose();
    _birthDateCtrl.dispose();
    _addressCtrl.dispose();
    _majorCtrl.dispose();
    _univCtrl.dispose();
    _subjectCtrl.dispose();
    _startDateCtrl.dispose();
    _rankCtrl.dispose();
    _npwpCtrl.dispose();
    _dependentsCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _waliKelasCtrl.dispose();
    _angkatanWaliCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _deleteTeacher() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data Guru'),
        content: Text('Apakah Anda yakin ingin menghapus data guru ${_nameCtrl.text}? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: errorRed),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await apiService.delete('teachers', widget.teacher!['id'].toString());
        if (mounted) {
          NotificationHelper.show(context, 'Data guru berhasil dihapus');
          if (widget.onBack != null) {
            widget.onBack!();
          } else {
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (mounted) NotificationHelper.show(context, 'Gagal menghapus data: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveTeacher() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'nip': _nipCtrl.text.trim(),
        'nik': _nikCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'gender': _selectedGender == 'Laki-laki' ? 'L' : 'P',
        'birth_place': _birthPlaceCtrl.text.trim(),
        'birth_date': _birthDateCtrl.text.trim(),
        'religion': _selectedReligion,
        'address': _addressCtrl.text.trim(),
        'last_education': _selectedEducation,
        'major': _majorCtrl.text.trim(),
        'university': _univCtrl.text.trim(),
        'role': _selectedRole,
        'subject': _subjectCtrl.text.trim(),
        'start_date': _startDateCtrl.text.trim().isEmpty ? null : _startDateCtrl.text.trim(),
        'employment_status': _selectedEmploymentStatus,
        'rank_grade': _rankCtrl.text.trim(),
        'npwp': _npwpCtrl.text.trim(),
        'marital_status': _selectedMaritalStatus,
        'number_of_dependents': int.tryParse(_dependentsCtrl.text.trim()) ?? 0,
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'wali_kelas': _selectedWaliKelas == 'Bukan Wali Kelas' ? null : _selectedWaliKelas,
        'rombel_wali': _selectedRombelWali == '-' ? null : _selectedRombelWali,
        'angkatan_wali': _selectedAngkatanWali == '-' ? null : _selectedAngkatanWali,
      };

      if (widget.teacher != null) {
        await apiService.update('teachers', widget.teacher!['id'].toString(), data);
        if (mounted) NotificationHelper.show(context, 'Berhasil memperbarui data guru');
      } else {
        await apiService.insert('teachers', data);
        if (mounted) NotificationHelper.show(context, 'Berhasil menambah data guru: ${_nameCtrl.text}');
        
        try {
          PushNotificationService.sendNotification(
            userId: null,
            title: 'DATA GURU BARU 👨‍🏫',
            message: 'Tenaga Pendidik Baru Telah Ditambahkan: ${_nameCtrl.text} sebagai ${_selectedRole ?? "-"}',
            data: {'include_staff': true},
          );
        } catch (e) {
          debugPrint('Gagal kirim notif: $e');
        }
      }

      if (!mounted) return;
      if (widget.onBack != null) {
        widget.onBack!();
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.show(context, 'Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        _buildPageHeader(),
        _buildStepperIndicator(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildActiveStepContent(),
              ),
            ),
          ),
        ),
        _buildBottomNavigation(),
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
      body: content,
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.teacher != null ? 'Edit Guru' : 'Tambah Guru',
                  style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 24),
                ),
              ],
            ),
          ),
          if (widget.teacher != null) ...[
            _headerActionBtn(Icons.delete_outline, 'Hapus', _deleteTeacher, isDanger: true),
            const SizedBox(width: 8),
          ],
          _headerActionBtn(Icons.arrow_back, 'Kembali', () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          }),
        ],
      ),
    );
  }

  Widget _headerActionBtn(IconData icon, String label, VoidCallback onTap, {bool isDanger = false}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: isDanger ? errorRed : textDark),
      label: Text(label, style: TextStyle(color: isDanger ? errorRed : textDark, fontWeight: FontWeight.w500)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: isDanger ? errorRed.withValues(alpha: 0.5) : borderColor),
        backgroundColor: AppColors.cardWhite,
      ),
    );
  }


  Widget _buildStepperIndicator() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 700;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepItem(1, 'Info Pribadi', 'Data diri', isCompleted: _activeStep > 0, isActive: _activeStep == 0),
          _stepLine(_activeStep > 0),
          _stepItem(2, 'Pekerjaan', 'Karir', isCompleted: _activeStep > 1, isActive: _activeStep == 1),
          _stepLine(_activeStep > 1),
          _stepItem(3, 'Kontak', 'Hubung', isCompleted: _activeStep > 2, isActive: _activeStep == 2),
          if (!isMobile) ...[
            _stepLine(_activeStep > 2),
            _stepItem(4, 'Konfirmasi', 'Finalisasi', isActive: _activeStep == 3),
          ],
        ],
      ),
    );
  }

  Widget _stepItem(int number, String title, String subtitle, {bool isCompleted = false, bool isActive = false}) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 700;

    return Expanded(
      flex: isMobile ? 0 : 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted || isActive ? primaryTeal : AppColors.surfaceGray,
              border: Border.all(
                color: isCompleted || isActive ? primaryTeal : borderColor,
                width: 2,
              ),
              boxShadow: isActive ? [
                BoxShadow(color: primaryTeal.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))
              ] : null,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(number.toString(), style: TextStyle(color: isActive ? Colors.white : textMuted, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isActive || isCompleted ? textDark : textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepLine(bool active) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: active ? primaryTeal : borderColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildActiveStepContent() {
    switch (_activeStep) {
      case 0: return _buildStepOneContent();
      case 1: return _buildStepTwoContent();
      case 2: return _buildStepThreeContent();
      case 3: return _buildStepFourContent();
      default: return Container();
    }
  }

  Widget _buildStepOneContent() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 700;

    return Column(
      key: const ValueKey(0),
      children: [
        _formSection(
          icon: Icons.person_outline_rounded,
          title: 'Informasi Pribadi',
          children: [
            _field('NIP / NUPTK', _nipCtrl, 'Masukkan NIP', required: true, prefixIcon: Icons.tag_rounded),
            const SizedBox(height: 20),
            _field('Nama Lengkap', _nameCtrl, 'Nama Sesuai Ijazah', required: true, prefixIcon: Icons.person_outline),
            const SizedBox(height: 20),
            if (isMobile) ...[
              _dropdownField('Jenis Kelamin', _selectedGender, ['Laki-laki', 'Perempuan'], (v) => setState(() => _selectedGender = v), required: true, prefixIcon: Icons.help_outline_rounded, hint: 'Pilih'),
              const SizedBox(height: 20),
              _field('Tempat Lahir', _birthPlaceCtrl, 'Kota', required: true, prefixIcon: Icons.apartment_rounded),
            ] else 
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _dropdownField('Jenis Kelamin', _selectedGender, ['Laki-laki', 'Perempuan'], (v) => setState(() => _selectedGender = v), required: true, prefixIcon: Icons.help_outline_rounded, hint: 'Pilih'),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _field('Tempat Lahir', _birthPlaceCtrl, 'Kota', required: true, prefixIcon: Icons.apartment_rounded),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            _dateField('Tanggal Lahir', _birthDateCtrl, required: true, prefixIcon: Icons.calendar_today_outlined, hint: 'Pilih Tanggal'),
            const SizedBox(height: 20),
            _dropdownField('Agama', _selectedReligion, ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Budha', 'Lainnya'], (v) => setState(() => _selectedReligion = v), required: true, prefixIcon: Icons.help_outline_rounded, hint: 'Pilih'),
            const SizedBox(height: 20),
            _dropdownField('Pendidikan Terakhir', _selectedEducation, ['SMA', 'D3', 'S1', 'S2', 'S3'], (v) => setState(() => _selectedEducation = v), required: true, prefixIcon: Icons.school_rounded, hint: 'Pilih'),
            const SizedBox(height: 20),
            _field('Jurusan', _majorCtrl, 'Contoh: Pend. Guru PAUD', required: true, prefixIcon: Icons.book_rounded),
            const SizedBox(height: 20),
            _field('Universitas / Instansi', _univCtrl, 'Nama Kampus', required: true, prefixIcon: Icons.account_balance_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildStepTwoContent() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 700;

    return Column(
      key: const ValueKey(1),
      children: [
        _formSection(
          icon: Icons.work_outline_rounded,
          title: 'Kepegawaian',
          children: [
            _dropdownField('Jabatan', _selectedRole, ['Kepala Sekolah', 'Guru Kelas', 'Guru Mapel', 'Staff TU'], (v) => setState(() => _selectedRole = v), required: true, prefixIcon: Icons.help_outline_rounded, hint: 'Pilih'),
            const SizedBox(height: 20),
            _field('Mata Pelajaran', _subjectCtrl, 'Mapel yang diampu', prefixIcon: Icons.book_rounded),
            const SizedBox(height: 20),
            _field('NIK / KTP', _nikCtrl, '16 Digit NIK', required: true, prefixIcon: Icons.assignment_ind_outlined),
            const SizedBox(height: 20),
            _dateField('Tanggal Mulai Mengajar', _startDateCtrl, prefixIcon: Icons.calendar_today_outlined, hint: 'Pilih Tanggal'),
            const SizedBox(height: 20),
            if (isMobile) ...[
              _dropdownField('Status Utama', _selectedEmploymentStatus, ['PNS', 'HONORER', 'KONTRAK'], (v) => setState(() => _selectedEmploymentStatus = v!), required: true, prefixIcon: Icons.badge_outlined, hint: 'Pilih'),
              const SizedBox(height: 20),
              _field('Golongan', _rankCtrl, 'Khusus PNS', prefixIcon: Icons.layers_outlined),
            ] else 
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _dropdownField('Status Utama', _selectedEmploymentStatus, ['PNS', 'HONORER', 'KONTRAK'], (v) => setState(() => _selectedEmploymentStatus = v!), required: true, prefixIcon: Icons.badge_outlined, hint: 'Pilih'),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _field('Golongan', _rankCtrl, 'Khusus PNS', prefixIcon: Icons.layers_outlined),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.school_rounded, color: primaryTeal, size: 20),
                const SizedBox(width: 12),
                Text('Status Wali Kelas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark)),
              ],
            ),
            const SizedBox(height: 16),
            if (isMobile) ...[
              _dropdownField('Wali Kelas', _selectedWaliKelas, _classList, (v) {
                _selectedWaliKelas = v!;
                _updateAvailableOptions();
              }, prefixIcon: Icons.meeting_room_rounded, hint: 'Pilih Kelas'),
              const SizedBox(height: 20),
              _dropdownField('Rombel Wali', _selectedRombelWali, _rombelList, (v) {
                _selectedRombelWali = v!;
                _updateAvailableOptions();
              }, prefixIcon: Icons.groups_3_rounded, hint: 'Pilih Rombel'),
              const SizedBox(height: 20),
              _dropdownField('Angkatan Wali', _selectedAngkatanWali, _batchList, (v) {
                _selectedAngkatanWali = v!;
                _updateAvailableOptions();
              }, prefixIcon: Icons.calendar_today_rounded, hint: 'Pilih Angkatan'),
            ] else 
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _dropdownField('Wali Kelas', _selectedWaliKelas, _classList, (v) {
                      _selectedWaliKelas = v!;
                      _updateAvailableOptions();
                    }, prefixIcon: Icons.meeting_room_rounded, hint: 'Pilih Kelas'),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _dropdownField('Rombel Wali', _selectedRombelWali, _rombelList, (v) {
                      _selectedRombelWali = v!;
                      _updateAvailableOptions();
                    }, prefixIcon: Icons.groups_3_rounded, hint: 'Pilih Rombel'),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _dropdownField('Angkatan Wali', _selectedAngkatanWali, _batchList, (v) {
                      _selectedAngkatanWali = v!;
                      _updateAvailableOptions();
                    }, prefixIcon: Icons.calendar_today_rounded, hint: 'Pilih Angkatan'),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 24),
        _formSection(
          icon: Icons.folder_shared_outlined,
          title: 'Administrasi Tambahan',
          children: [
            _field('NPWP', _npwpCtrl, 'Nomor NPWP', prefixIcon: Icons.description_outlined),
            const SizedBox(height: 20),
            if (isMobile) ...[
              _dropdownField('Status Nikah', _selectedMaritalStatus, ['Belum Menikah', 'Menikah', 'Cerai Hidup', 'Cerai Mati'], (v) => setState(() => _selectedMaritalStatus = v), prefixIcon: Icons.help_outline_rounded, hint: 'Pilih'),
              const SizedBox(height: 20),
              _field('Jml Tanggungan', _dependentsCtrl, 'Anak/Istri', prefixIcon: Icons.group_outlined, keyboardType: TextInputType.number),
            ] else 
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _dropdownField('Status Nikah', _selectedMaritalStatus, ['Belum Menikah', 'Menikah', 'Cerai Hidup', 'Cerai Mati'], (v) => setState(() => _selectedMaritalStatus = v), prefixIcon: Icons.help_outline_rounded, hint: 'Pilih'),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _field('Jml Tanggungan', _dependentsCtrl, 'Anak/Istri', prefixIcon: Icons.group_outlined, keyboardType: TextInputType.number),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepThreeContent() {
    return Column(
      key: const ValueKey(2),
      children: [
        _formSection(
          icon: Icons.contact_page_outlined,
          title: 'Kontak & Alamat',
          children: [
            _field('No. HP / WhatsApp', _phoneCtrl, '0812...', required: true, prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 24),
            _field('Email Aktif', _emailCtrl, 'contoh@mail.com', prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 24),
            _field('Alamat Lengkap', _addressCtrl, 'Jalan, RT/RW, Desa', required: true, prefixIcon: Icons.home_outlined, maxLines: 2),
          ],
        ),
      ],
    );
  }

  Widget _buildStepFourContent() {
    return Column(
      key: const ValueKey(3),
      children: [
        _formSection(
          icon: Icons.check_circle_outline,
          title: 'Konfirmasi Data',
          children: [
            _confirmDataHeader('Informasi Pribadi'),
            _confirmDataRow('Nama Lengkap', _nameCtrl.text),
            _confirmDataRow('NIP / NUPTK', _nipCtrl.text),
            _confirmDataRow('NIK', _nikCtrl.text),
            _confirmDataRow('L/P', _selectedGender ?? '-'),
            _confirmDataRow('Tempat, Tgl Lahir', '${_birthPlaceCtrl.text}, ${_birthDateCtrl.text}'),
            _confirmDataRow('Agama', _selectedReligion ?? '-'),
            _confirmDataRow('Pendidikan', '${_selectedEducation ?? "-"} ${_majorCtrl.text}'),
            _confirmDataRow('Universitas', _univCtrl.text),
            
            const Divider(height: 32),
            _confirmDataHeader('Kepegawaian'),
            _confirmDataRow('Jabatan', _selectedRole ?? '-'),
            _confirmDataRow('Mata Pelajaran', _subjectCtrl.text),
            _confirmDataRow('Status Utama', _selectedEmploymentStatus ?? '-'),
            _confirmDataRow('Golongan', _rankCtrl.text),
            _confirmDataRow('Mulai Mengajar', _startDateCtrl.text),
            _confirmDataRow('Wali Kelas', _selectedWaliKelas),
            _confirmDataRow('Rombel Wali', _selectedRombelWali),
            _confirmDataRow('Angkatan Wali', _selectedAngkatanWali),

            const Divider(height: 32),
            _confirmDataHeader('Administrasi'),
            _confirmDataRow('NPWP', _npwpCtrl.text),
            _confirmDataRow('Status Nikah', _selectedMaritalStatus ?? '-'),
            _confirmDataRow('Jml Tanggungan', _dependentsCtrl.text),

            const Divider(height: 32),
            _confirmDataHeader('Kontak & Alamat'),
            _confirmDataRow('No. HP / WA', _phoneCtrl.text),
            _confirmDataRow('Email', _emailCtrl.text),
            _confirmDataRow('Alamat', _addressCtrl.text),
            
            const Divider(height: 32),
            const Text('Pastikan data yang dimasukkan sudah benar sebelum menekan tombol simpan.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.orange, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _formSection({required IconData icon, required String title, String? description, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryTeal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primaryTeal, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title, 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                    ),
                    if (description != null)
                      Text(description, style: TextStyle(fontSize: 11, color: textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint, {int maxLines = 1, TextInputType? keyboardType, bool required = false, IconData? prefixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
            if (required) Text(' *', style: TextStyle(color: errorRed, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: textMuted, fontSize: 13),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: primaryTeal, size: 20) : null,
            filled: true,
            fillColor: AppColors.backgroundColor,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryTeal, width: 1.5)),
          ),
          validator: required ? (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null : null,
        ),
      ],
    );
  }

  Widget _dateField(String label, TextEditingController ctrl, {bool required = false, IconData? prefixIcon, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
            if (required) Text(' *', style: TextStyle(color: errorRed, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          readOnly: true,
          onTap: () => _selectDate(context, ctrl),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint ?? 'Pilih $label',
            hintStyle: TextStyle(color: textMuted, fontSize: 13),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: primaryTeal, size: 20) : null,
            suffixIcon: Icon(Icons.calendar_month_outlined, size: 18, color: textMuted),
            filled: true,
            fillColor: AppColors.backgroundColor,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryTeal, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _dropdownField(String label, String? selectedValue, List<String> items, ValueChanged<String?> onChanged, {bool required = false, IconData? prefixIcon, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
            if (required) Text(' *', style: TextStyle(color: errorRed, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: items.contains(selectedValue) ? selectedValue : null,
          decoration: InputDecoration(
            hintText: hint ?? 'Pilih $label',
            hintStyle: TextStyle(color: textMuted, fontSize: 13),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: primaryTeal, size: 20) : null,
            filled: true,
            fillColor: AppColors.backgroundColor,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryTeal, width: 1.5)),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _confirmDataHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryTeal),
      ),
    );
  }

  Widget _confirmDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(color: textSecondary, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold, color: textDark, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.end,
        children: [
          if (_activeStep > 0) ...[
            Expanded(
              flex: isMobile ? 1 : 0,
              child: _navButton(isMobile ? 'Balik' : 'Sebelumnya', Colors.white, textDark, borderColor, () => setState(() => _activeStep--)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: isMobile ? 1 : 0,
            child: _navButton('Batal', Colors.white, textDark, borderColor, () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.pop(context);
              }
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: isMobile ? 2 : 0,
            child: ElevatedButton(
              onPressed: _isLoading ? null : (_activeStep == 3 ? _saveTeacher : () => setState(() => _activeStep++)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 16 : 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_activeStep == 3 ? 'Simpan' : 'Lanjut', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 6),
                      Icon(_activeStep == 3 ? Icons.save : Icons.arrow_forward, size: 14),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(String label, Color bg, Color text, Color border, VoidCallback onTap) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 700;

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 24, vertical: isMobile ? 16 : 20),
        backgroundColor: bg,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label, 
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
