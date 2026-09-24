import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../utils/notification_helper.dart';

class EditSekolahPage extends StatefulWidget {
  final Map<String, dynamic> schoolData;
  final bool isEmbedded;
  final Function(int)? onNavigate;
  const EditSekolahPage({super.key, required this.schoolData, this.isEmbedded = false, this.onNavigate});

  @override
  State<EditSekolahPage> createState() => _EditSekolahPageState();
}

class _EditSekolahPageState extends State<EditSekolahPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _npsnController;
  late TextEditingController _accreditationController;
  late TextEditingController _curriculumController;
  late TextEditingController _headmasterNameController;
  late TextEditingController _headmasterNipController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _websiteController;
  late TextEditingController _addressController;

  bool _isLoading = false;
  final apiService = ApiService();

  // --- Theme Colors ---
  Color get primaryTeal => AppColors.isDark ? AppColors.brand : AppColors.primary;
  final Color textDark = AppColors.textDark;
  final Color bgLight = AppColors.backgroundColor;
  final Color borderColor = AppColors.borderColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.schoolData['name']?.toString() ?? '');
    _npsnController = TextEditingController(text: widget.schoolData['npsn']?.toString() ?? '');
    _accreditationController = TextEditingController(text: widget.schoolData['accreditation']?.toString() ?? '');
    _curriculumController = TextEditingController(text: widget.schoolData['curriculum']?.toString() ?? '');
    _headmasterNameController = TextEditingController(text: widget.schoolData['headmaster_name']?.toString() ?? '');
    _headmasterNipController = TextEditingController(text: widget.schoolData['headmaster_nip']?.toString() ?? '');
    _emailController = TextEditingController(text: widget.schoolData['email']?.toString() ?? '');
    _phoneController = TextEditingController(text: widget.schoolData['phone']?.toString() ?? '');
    _websiteController = TextEditingController(text: widget.schoolData['website']?.toString() ?? '');
    _addressController = TextEditingController(text: widget.schoolData['address']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _npsnController.dispose();
    _accreditationController.dispose();
    _curriculumController.dispose();
    _headmasterNameController.dispose();
    _headmasterNipController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> updatedData = {
        'name': _nameController.text,
        'npsn': _npsnController.text,
        'accreditation': _accreditationController.text,
        'curriculum': _curriculumController.text,
        'headmaster_name': _headmasterNameController.text,
        'headmaster_nip': _headmasterNipController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'website': _websiteController.text,
        'address': _addressController.text,
      };

      if (widget.schoolData['id'] != null) {
        await apiService.update('school_data', widget.schoolData['id'].toString(), updatedData);
      } else {
        await apiService.insert('school_data', updatedData);
      }

      if (mounted) {
        NotificationHelper.show(context, 'Data profil sekolah berhasil disimpan');
        if (widget.isEmbedded && widget.onNavigate != null) {
          widget.onNavigate!(7);
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint('Error saving school data: $e');
      if (mounted) {
        NotificationHelper.show(context, 'Gagal menyimpan data: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: widget.isEmbedded 
        ? null 
        : AppBar(
            title: const Text('Edit Profil Sekolah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: AppColors.cardWhite,
            foregroundColor: primaryTeal,
            elevation: 0,
            centerTitle: false,
            actions: [
              if (!_isLoading)
                IconButton(
                  onPressed: _saveData,
                  icon: const Icon(Icons.check_rounded),
                  tooltip: 'Simpan',
                ),
              const SizedBox(width: 8),
            ],
          ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryTeal))
          : LayoutBuilder(
              builder: (context, constraints) {
                bool isWide = constraints.maxWidth > 800;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? (constraints.maxWidth - 750) / 2 : 24,
                    vertical: 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.isEmbedded) ...[
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                                onPressed: () => widget.onNavigate?.call(7),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Edit Profil Sekolah',
                                  style: TextStyle(
                                    fontSize: constraints.maxWidth < 600 ? 18 : 24, 
                                    fontWeight: FontWeight.bold, 
                                    color: primaryTeal
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (!_isLoading)
                                constraints.maxWidth < 600 
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: primaryTeal,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: IconButton(
                                      onPressed: _saveData,
                                      icon: const Icon(Icons.check_rounded, color: Colors.white),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Simpan',
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: _saveData,
                                    icon: const Icon(Icons.check_rounded, size: 18),
                                    label: const Text('Simpan'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryTeal,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                        _buildSectionHeader('Informasi Dasar'),
                        _buildTextField('Nama Sekolah', _nameController, Icons.school_rounded, 'Masukkan nama sekolah', validator: (v) => v!.isEmpty ? 'Nama tidak boleh kosong' : null),
                        
                        if (isWide)
                          Row(
                            children: [
                              Expanded(child: _buildTextField('NPSN', _npsnController, Icons.badge_rounded, 'Masukkan NPSN')),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField('Akreditasi', _accreditationController, Icons.verified_rounded, 'Contoh: A')),
                            ],
                          )
                        else ...[
                          _buildTextField('NPSN', _npsnController, Icons.badge_rounded, 'Masukkan NPSN'),
                          _buildTextField('Akreditasi', _accreditationController, Icons.verified_rounded, 'Contoh: A'),
                        ],

                        const SizedBox(height: 12),
                        _buildSectionHeader('Kurikulum & Akademik'),
                        _buildTextField('Kurikulum', _curriculumController, Icons.auto_stories_rounded, 'Contoh: Kurikulum Merdeka'),
                        
                        const SizedBox(height: 12),
                        _buildSectionHeader('Kepemimpinan'),
                        if (isWide)
                          Row(
                            children: [
                              Expanded(child: _buildTextField('Nama Kepala Sekolah', _headmasterNameController, Icons.person_rounded, 'Masukkan nama lengkap')),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField('NIP / NIY', _headmasterNipController, Icons.credit_card_rounded, 'Masukkan NIP atau nomor identitas')),
                            ],
                          )
                        else ...[
                          _buildTextField('Nama Kepala Sekolah', _headmasterNameController, Icons.person_rounded, 'Masukkan nama lengkap'),
                          _buildTextField('NIP / NIY', _headmasterNipController, Icons.credit_card_rounded, 'Masukkan NIP atau nomor identitas'),
                        ],
                        
                        const SizedBox(height: 12),
                        _buildSectionHeader('Kontak & Alamat'),
                        if (isWide)
                          Row(
                            children: [
                              Expanded(child: _buildTextField('Email', _emailController, Icons.email_rounded, 'Contoh: info@sekolah.id')),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField('Nomor Telepon', _phoneController, Icons.phone_rounded, 'Contoh: 021...')),
                            ],
                          )
                        else ...[
                          _buildTextField('Email', _emailController, Icons.email_rounded, 'Contoh: info@sekolah.id'),
                          _buildTextField('Nomor Telepon', _phoneController, Icons.phone_rounded, 'Contoh: 021...'),
                        ],
                        
                        _buildTextField('Situs Web', _websiteController, Icons.public_rounded, 'Contoh: https://...'),
                        _buildTextField('Alamat Lengkap', _addressController, Icons.location_on_rounded, 'Masukkan alamat operasional', maxLines: 3),
                        
                        const SizedBox(height: 40),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _saveData,
                                icon: const Icon(Icons.save_rounded),
                                label: const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryTeal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: primaryTeal.withValues(alpha: 0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, String hint, {int maxLines = 1, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.normal),
          hintText: hint,
          prefixIcon: Icon(icon, color: primaryTeal, size: 20),
          filled: true,
          fillColor: AppColors.backgroundColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryTeal, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
