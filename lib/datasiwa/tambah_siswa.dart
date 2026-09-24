import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../utils/notification_helper.dart';
import '../utils/push_notification_service.dart';

class TambahSiswaPage extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onBack;
  final Map<String, dynamic>? student;
  
  const TambahSiswaPage({super.key, this.isEmbedded = false, this.onBack, this.student});

  @override
  State<TambahSiswaPage> createState() => _TambahSiswaPageState();
}

class _TambahSiswaPageState extends State<TambahSiswaPage> {
  final _formKey = GlobalKey<FormState>();
  int _activeStep = 0;

  // --- Controllers Data Pribadi (Step 1) ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nisController = TextEditingController();
  final TextEditingController _birthPlaceController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _rtController = TextEditingController();
  final TextEditingController _rwController = TextEditingController();
  final TextEditingController _villageController = TextEditingController();
  final TextEditingController _childNumberController = TextEditingController();

  // --- Controllers Akademik (Step 2) ---
  final TextEditingController _batchController = TextEditingController();
  final TextEditingController _curriculumController = TextEditingController();
  final TextEditingController _academicYearController = TextEditingController();
  final TextEditingController _schoolOfOriginController = TextEditingController();

  // --- Controllers Orang Tua (Step 3) ---
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _fatherJobController = TextEditingController();
  final TextEditingController _fatherPhoneController = TextEditingController();
  final TextEditingController _fatherAddressController = TextEditingController();

  final TextEditingController _motherNameController = TextEditingController();
  final TextEditingController _motherJobController = TextEditingController();
  final TextEditingController _motherPhoneController = TextEditingController();
  final TextEditingController _motherAddressController = TextEditingController();

  final TextEditingController _parentDistrictController = TextEditingController();
  final TextEditingController _parentCityController = TextEditingController();
  final TextEditingController _parentProvinceController = TextEditingController();

  String? _selectedGender = 'Laki-laki'; // Default based on image
  String? _selectedReligion;
  String? _selectedClass;
  String? _selectedRombel;
  String _selectedStatus = 'Aktif';
  String? _selectedCurriculum;
  bool _isLoading = false;
  final apiService = ApiService();

  // --- Palette (Using central AppColors) ---
  final Color primaryTeal = AppColors.primary;
  final Color backgroundColor = AppColors.backgroundColor;
  final Color textDark = AppColors.textDark;
  final Color textSecondary = AppColors.textSecondary;
  final Color textMuted = AppColors.textMuted;
  final Color borderColor = AppColors.borderColor;
  final Color errorRed = AppColors.errorRed;

  @override
  void initState() {
    super.initState();
    if (widget.student != null) {
      final s = widget.student!;
      _nameController.text = s['name'] ?? '';
      _nisController.text = s['nis'] ?? '';
      _birthPlaceController.text = s['birth_place'] ?? '';
      _birthDateController.text = s['birth_date'] ?? '';
      _addressController.text = s['address'] ?? '';
      _rtController.text = s['rt']?.toString() ?? '';
      _rwController.text = s['rw']?.toString() ?? '';
      _villageController.text = s['village'] ?? '';
      _childNumberController.text = s['child_number']?.toString() ?? '';
      
      _batchController.text = s['batch'] ?? '';
      _curriculumController.text = s['curriculum'] ?? '';
      _schoolOfOriginController.text = s['school_of_origin'] ?? '';

      _fatherNameController.text = s['father_name'] ?? '';
      _fatherJobController.text = s['father_job'] ?? '';
      _fatherPhoneController.text = s['parent_phone'] ?? '';
      _fatherAddressController.text = s['parent_address'] ?? '';

      _motherNameController.text = s['mother_name'] ?? '';
      _motherJobController.text = s['mother_job'] ?? '';
      _motherPhoneController.text = s['parent_phone'] ?? '';
      _motherAddressController.text = s['parent_address'] ?? '';

      _parentDistrictController.text = s['parent_district'] ?? '';
      _parentCityController.text = s['parent_city'] ?? '';
      _parentProvinceController.text = s['parent_province'] ?? '';

      _selectedGender = s['gender'] == 'L' ? 'Laki-laki' : 'Perempuan';
      _selectedReligion = s['religion'];
      _selectedClass = s['class'];
      _selectedRombel = s['rombel'];
      _selectedStatus = s['status'] ?? 'Aktif';
      _selectedCurriculum = s['curriculum'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nisController.dispose();
    _birthPlaceController.dispose();
    _birthDateController.dispose();
    _addressController.dispose();
    _rtController.dispose();
    _rwController.dispose();
    _villageController.dispose();
    _childNumberController.dispose();
    _batchController.dispose();
    _curriculumController.dispose();
    _academicYearController.dispose();
    _schoolOfOriginController.dispose();
    _fatherNameController.dispose();
    _fatherJobController.dispose();
    _fatherPhoneController.dispose();
    _fatherAddressController.dispose();
    _motherNameController.dispose();
    _motherJobController.dispose();
    _motherPhoneController.dispose();
    _motherAddressController.dispose();
    _parentDistrictController.dispose();
    _parentCityController.dispose();
    _parentProvinceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'nis': _nisController.text.trim(),
        'class': _selectedClass,
        'rombel': _selectedRombel,
        'batch': _batchController.text.trim(),
        'curriculum': _selectedCurriculum == 'Lainnya' 
            ? _curriculumController.text.trim() 
            : _selectedCurriculum,
        'school_of_origin': _schoolOfOriginController.text.trim(),
        'birth_place': _birthPlaceController.text.trim(),
        'birth_date': _birthDateController.text.trim(),
        'gender': _selectedGender == 'Laki-laki' ? 'L' : 'P',
        'religion': _selectedReligion,
        'child_number': int.tryParse(_childNumberController.text.trim()),
        'address': _addressController.text.trim(),
        'rt': _rtController.text.trim(),
        'rw': _rwController.text.trim(),
        'village': _villageController.text.trim(),
        'status': _selectedStatus,
        'father_name': _fatherNameController.text.trim(),
        'mother_name': _motherNameController.text.trim(),
        'parent_phone': _fatherPhoneController.text.isNotEmpty 
            ? _fatherPhoneController.text.trim() 
            : _motherPhoneController.text.trim(),
        'father_job': _fatherJobController.text.trim(),
        'mother_job': _motherJobController.text.trim(),
        'parent_address': _fatherAddressController.text.isNotEmpty 
            ? _fatherAddressController.text.trim() 
            : _motherAddressController.text.trim(),
        'parent_district': _parentDistrictController.text.trim(),
        'parent_city': _parentCityController.text.trim(),
        'parent_province': _parentProvinceController.text.trim(),
      };

      if (widget.student != null) {
        await apiService.update('students', widget.student!['id'].toString(), data);
        if (!mounted) return;
        NotificationHelper.show(context, 'Berhasil memperbarui data siswa');
      } else {
        await apiService.insert('students', data);
        if (!mounted) return;
        NotificationHelper.show(context, 'Berhasil menambah data siswa: ${_nameController.text}');
        
        try {
          PushNotificationService.sendNotification(
            userId: null,
            title: 'DATA SISWA BARU 🎓',
            message: 'Data Siswa-Siswi Telah Ditambahkan ${_selectedClass ?? "-"} ${_batchController.text.trim()} 1 Siswa',
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
                  widget.student != null ? 'Edit Siswa' : 'Tambah Siswa',
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 24),
                ),
              ],
            ),
          ),
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

  Widget _headerActionBtn(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: textDark),
      label: Text(label, style: TextStyle(color: textDark, fontWeight: FontWeight.w500)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: borderColor),
        backgroundColor: AppColors.cardWhite,
      ),
    );
  }


  Widget _buildStepperIndicator() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 700;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepItem(1, 'Data Pribadi', 'Informasi dasar siswa', isCompleted: _activeStep > 0, isActive: _activeStep == 0),
          _stepLine(_activeStep > 0),
          _stepItem(2, 'Data Kelas', 'Informasi kelas dan angkatan', isCompleted: _activeStep > 1, isActive: _activeStep == 1),
          _stepLine(_activeStep > 1),
          _stepItem(3, 'Data Orang Tua', 'Informasi orang tua / wali', isCompleted: _activeStep > 2, isActive: _activeStep == 2),
          if (!isMobile) ...[
            _stepLine(_activeStep > 2),
            _stepItem(4, 'Konfirmasi', 'Periksa kembali data', isActive: _activeStep == 3),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted || isActive ? primaryTeal : Colors.white,
              border: Border.all(color: isCompleted || isActive ? primaryTeal : borderColor, width: 2),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
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
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isActive || isCompleted ? textDark : textSecondary)),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: textMuted)),
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
          icon: Icons.info_outline,
          title: 'Informasi Dasar',
          children: [
            _field('Nama Lengkap', _nameController, 'Masukkan nama lengkap', required: true, prefixIcon: Icons.person_outline),
            const SizedBox(height: 24),
            _field('NIS', _nisController, 'Masukkan NIS', required: true, prefixIcon: Icons.badge_outlined),
            const SizedBox(height: 24),
            if (isMobile) ...[
              _field('Tempat Lahir', _birthPlaceController, 'Masukkan tempat lahir', required: true, prefixIcon: Icons.location_on_outlined),
              const SizedBox(height: 24),
              _dateField('Tanggal Lahir', _birthDateController, required: true, prefixIcon: Icons.calendar_today_outlined),
            ] else 
              Row(
                children: [
                  Expanded(child: _field('Tempat Lahir', _birthPlaceController, 'Masukkan tempat lahir', required: true, prefixIcon: Icons.location_on_outlined)),
                  const SizedBox(width: 24),
                  Expanded(child: _dateField('Tanggal Lahir', _birthDateController, required: true, prefixIcon: Icons.calendar_today_outlined)),
                ],
              ),
            const SizedBox(height: 24),
            if (isMobile) ...[
              _dropdownField('Jenis Kelamin', _selectedGender, ['Laki-laki', 'Perempuan'], (v) => setState(() => _selectedGender = v), required: true, prefixIcon: Icons.people_outline),
              const SizedBox(height: 24),
              _dropdownField('Agama', _selectedReligion, ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Budha', 'Konghucu'], (v) => setState(() => _selectedReligion = v), required: true, prefixIcon: Icons.church_outlined),
            ] else 
              Row(
                children: [
                  Expanded(child: _dropdownField('Jenis Kelamin', _selectedGender, ['Laki-laki', 'Perempuan'], (v) => setState(() => _selectedGender = v), required: true, prefixIcon: Icons.people_outline)),
                  const SizedBox(width: 24),
                  Expanded(child: _dropdownField('Agama', _selectedReligion, ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Budha', 'Konghucu'], (v) => setState(() => _selectedReligion = v), required: true, prefixIcon: Icons.church_outlined)),
                ],
              ),
            const SizedBox(height: 24),
            _field('Anak Ke-', _childNumberController, 'Contoh: 1', prefixIcon: Icons.tag, keyboardType: TextInputType.number),
          ],
        ),
        const SizedBox(height: 24),
        _formSection(
          icon: Icons.home_outlined,
          title: 'Alamat',
          children: [
            _field('Jalan / Nama Tempat', _addressController, 'Masukkan nama jalan atau tempat', required: true, prefixIcon: Icons.home_outlined),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(flex: 1, child: _field('RT', _rtController, 'RT', prefixIcon: Icons.map_outlined, keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: _field('RW', _rwController, 'RW', prefixIcon: Icons.map_outlined, keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 24),
            _field('Desa/Kelurahan', _villageController, 'Masukkan desa/kelurahan', prefixIcon: Icons.business_outlined),
          ],
        ),
      ],
    );
  }

  // --- STEP 2: Data Akademik ---
  Widget _buildStepTwoContent() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 700;

    return Column(
      key: const ValueKey(1),
      children: [
        _formSection(
          icon: Icons.school_outlined,
          title: 'Akademik',
          children: [
            if (isMobile) ...[
              _dropdownField('Kelas', _selectedClass, ['TK A', 'TK B'], (v) => setState(() => _selectedClass = v), required: true, prefixIcon: Icons.menu_book_outlined),
              const SizedBox(height: 24),
              _dropdownField('Rombel', _selectedRombel, ['1', '2', '3', '4'], (v) => setState(() => _selectedRombel = v), required: true, prefixIcon: Icons.category_outlined),
            ] else 
              Row(
                children: [
                  Expanded(child: _dropdownField('Kelas', _selectedClass, ['TK A', 'TK B'], (v) => setState(() => _selectedClass = v), required: true, prefixIcon: Icons.menu_book_outlined)),
                  const SizedBox(width: 24),
                  Expanded(child: _dropdownField('Rombel', _selectedRombel, ['1', '2', '3', '4'], (v) => setState(() => _selectedRombel = v), required: true, prefixIcon: Icons.category_outlined)),
                ],
              ),
            const SizedBox(height: 24),
            if (isMobile) ...[
              _field('Angkatan', _batchController, 'Contoh: 2024', prefixIcon: Icons.calendar_today_outlined),
              const SizedBox(height: 24),
              _field('Kurikulum', _curriculumController, 'Contoh: Merdeka', prefixIcon: Icons.subject_outlined),
            ] else 
              Row(
                children: [
                  Expanded(child: _field('Angkatan', _batchController, 'Contoh: 2024', prefixIcon: Icons.calendar_today_outlined)),
                  const SizedBox(width: 24),
                  Expanded(child: _field('Kurikulum', _curriculumController, 'Contoh: Merdeka', prefixIcon: Icons.subject_outlined)),
                ],
              ),
            const SizedBox(height: 24),
            _field('Asal Sekolah', _schoolOfOriginController, 'Nama sekolah sebelumnya (jika pindahan)', prefixIcon: Icons.apartment_outlined),
            const SizedBox(height: 24),
            _dropdownField('Status', _selectedStatus, ['Aktif', 'Lulus', 'Keluar'], (v) => setState(() => _selectedStatus = v!), required: true, prefixIcon: Icons.info_outline),
          ],
        ),
      ],
    );
  }

  // --- STEP 3: Orang Tua ---
  Widget _buildStepThreeContent() {
    return Column(
      key: const ValueKey(2),
      children: [
        _formSection(
          icon: Icons.group_outlined,
          title: 'Orang Tua',
          children: [
            _field('Nama Ayah', _fatherNameController, 'Masukkan nama ayah', required: true, prefixIcon: Icons.person_outline),
            const SizedBox(height: 24),
            _field('Pekerjaan Ayah', _fatherJobController, 'Masukkan pekerjaan ayah', prefixIcon: Icons.subject_outlined),
            const SizedBox(height: 24),
            _field('Nama Ibu', _motherNameController, 'Masukkan nama ibu', required: true, prefixIcon: Icons.person_outline),
            const SizedBox(height: 24),
            _field('Pekerjaan Ibu', _motherJobController, 'Masukkan pekerjaan ibu', prefixIcon: Icons.subject_outlined),
            const SizedBox(height: 24),
            _field('No. HP Orang Tua', _fatherPhoneController, 'Masukkan nomor HP', prefixIcon: Icons.smartphone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 24),
            _field('Alamat Orang Tua', _fatherAddressController, 'Masukkan alamat orang tua', prefixIcon: Icons.home_work_outlined, maxLines: 2),
            const SizedBox(height: 24),
            _field('Kecamatan', _parentDistrictController, 'Masukkan kecamatan', prefixIcon: Icons.map_outlined),
            const SizedBox(height: 24),
            _field('Kabupaten / Kota', _parentCityController, 'Masukkan kabupaten/kota', prefixIcon: Icons.location_city_outlined),
            const SizedBox(height: 24),
            _field('Provinsi', _parentProvinceController, 'Masukkan provinsi', prefixIcon: Icons.public_outlined),
          ],
        ),
      ],
    );
  }

  // --- STEP 4: Konfirmasi ---
  Widget _buildStepFourContent() {
    return Column(
      key: const ValueKey(3),
      children: [
        _formSection(
          icon: Icons.check_circle_outline,
          title: 'Konfirmasi Data',
          children: [
            _confirmDataHeader('Informasi Pribadi'),
            _confirmDataRow('Nama Lengkap', _nameController.text),
            _confirmDataRow('NIS', _nisController.text),
            _confirmDataRow('Tempat, Tgl Lahir', '${_birthPlaceController.text}, ${_birthDateController.text}'),
            _confirmDataRow('Jenis Kelamin', _selectedGender ?? '-'),
            _confirmDataRow('Agama', _selectedReligion ?? '-'),
            _confirmDataRow('Anak Ke', _childNumberController.text),
            _confirmDataRow('Alamat', '${_addressController.text}, RT ${_rtController.text}/RW ${_rwController.text}, ${_villageController.text}'),
            
            const Divider(height: 32),
            _confirmDataHeader('Informasi Akademik'),
            _confirmDataRow('Kelas', _selectedClass ?? '-'),
            _confirmDataRow('Rombel', _selectedRombel ?? '-'),
            _confirmDataRow('Angkatan', _batchController.text),
            _confirmDataRow('Kurikulum', _curriculumController.text),
            _confirmDataRow('Asal Sekolah', _schoolOfOriginController.text),
            _confirmDataRow('Status', _selectedStatus),
            
            const Divider(height: 32),
            _confirmDataHeader('Data Orang Tua'),
            _confirmDataRow('Nama Ayah', _fatherNameController.text),
            _confirmDataRow('Pekerjaan Ayah', _fatherJobController.text),
            _confirmDataRow('Nama Ibu', _motherNameController.text),
            _confirmDataRow('Pekerjaan Ibu', _motherJobController.text),
            _confirmDataRow('No. HP', _fatherPhoneController.text.isNotEmpty ? _fatherPhoneController.text : _motherPhoneController.text),
            _confirmDataRow('Alamat OT', _fatherAddressController.text.isNotEmpty ? _fatherAddressController.text : _motherAddressController.text),
            _confirmDataRow('Kecamatan', _parentDistrictController.text),
            _confirmDataRow('Kab/Kota', _parentCityController.text),
            _confirmDataRow('Provinsi', _parentProvinceController.text),
            
            const Divider(height: 32),
            const Text('Pastikan data yang dimasukkan sudah benar sebelum menekan tombol simpan.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.orange, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  // --- UI COMPONENTS ---

  Widget _formSection({required IconData icon, required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryTeal, size: 20),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
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

  Widget _dateField(String label, TextEditingController ctrl, {bool required = false, IconData? prefixIcon}) {
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
          onTap: () => _selectDate(context),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Pilih $label',
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

  Widget _dropdownField(String label, String? selectedValue, List<String> items, ValueChanged<String?> onChanged, {bool required = false, IconData? prefixIcon}) {
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
            hintText: 'Pilih $label',
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
            width: 120,
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

    return Container(
      padding: EdgeInsets.fromLTRB(24, isMobile ? 12 : 0, 24, 24),
      decoration: isMobile ? BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ) : null,
      child: Row(
        mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.end,
        children: [
          if (_activeStep > 0 && !isMobile) ...[
            _navButton('Sebelumnya', Colors.white, textDark, borderColor, () => setState(() => _activeStep--)),
            const SizedBox(width: 12),
          ],
          if (isMobile && _activeStep > 0)
            Expanded(
              child: _navButtonMobile(Icons.arrow_back_ios_new_rounded, 'Back', () => setState(() => _activeStep--)),
            )
          else if (isMobile)
            Expanded(
              child: _navButtonMobile(Icons.close_rounded, 'Batal', () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              }),
            ),
          if (isMobile) const SizedBox(width: 12),
          Expanded(
            flex: isMobile ? 2 : 0,
            child: ElevatedButton(
              onPressed: _isLoading ? null : (_activeStep == 3 ? _saveStudent : () => setState(() => _activeStep++)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // Padding diperkecil
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Radius diperkecil
                elevation: 0,
              ),
              child: _isLoading 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_activeStep == 3 ? 'Simpan' : 'Lanjut', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), // Font diperkecil
                      const SizedBox(width: 6),
                      Icon(_activeStep == 3 ? Icons.save_rounded : Icons.arrow_forward_ios_rounded, size: 14),
                    ],
                  ),
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 12),
            _navButton('Batal', Colors.white, textDark, borderColor, () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.pop(context);
              }
            }),
          ]
        ],
      ),
    );
  }

  Widget _navButtonMobile(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: textDark),
      label: Text(label, style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14), // Padding diperkecil
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Radius diperkecil
        backgroundColor: AppColors.cardWhite,
      ),
    );
  }

  Widget _navButton(String label, Color bg, Color text, Color border, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        backgroundColor: bg,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: TextStyle(color: text, fontWeight: FontWeight.bold)),
    );
  }
}
