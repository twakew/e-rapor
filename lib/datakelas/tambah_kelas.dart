import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../utils/notification_helper.dart';

class TambahKelasPage extends StatefulWidget {
  final Map<String, dynamic>? classData;
  final bool isEmbedded;
  final VoidCallback? onBack;

  const TambahKelasPage({super.key, this.classData, this.isEmbedded = false, this.onBack});

  @override
  State<TambahKelasPage> createState() => _TambahKelasPageState();
}

class _TambahKelasPageState extends State<TambahKelasPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final apiService = ApiService();

  final _nameCtrl = TextEditingController();
  final _rombelCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();

  List<Map<String, dynamic>> _teachers = [];
  Map<String, dynamic>? _selectedTeacher;
  bool _isFetchingTeachers = true;

  Color get primaryTeal => AppColors.isDark ? AppColors.brand : AppColors.primary;
  final Color backgroundColor = AppColors.backgroundColor;
  final Color textDark = AppColors.textDark;
  final Color textSecondary = AppColors.textSecondary;
  final Color textMuted = AppColors.textMuted;
  final Color borderColor = AppColors.borderColor;
  final Color errorRed = AppColors.errorRed;

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
    if (widget.classData != null) {
      _nameCtrl.text = widget.classData!['name'] ?? widget.classData!['kelas'] ?? '';
      _rombelCtrl.text = widget.classData!['rombel'] ?? '';
      _batchCtrl.text = widget.classData!['batch'] ?? widget.classData!['angkatan'] ?? '';
    }
  }

  Future<void> _fetchTeachers() async {
    try {
      final res = await apiService.getTable('teachers');
      final List<Map<String, dynamic>> teachers = List<Map<String, dynamic>>.from(res);
      teachers.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      
      if (mounted) {
        setState(() {
          _teachers = teachers;
          if (widget.classData != null) {
            String superClean(dynamic val) {
              if (val == null || val.toString().isEmpty || val.toString() == '-') return '';
              return val.toString().toLowerCase()
                  .replaceAll('tk', '')
                  .replaceAll('kelompok', '')
                  .replaceAll('kelas', '')
                  .replaceAll('rombel', '')
                  .replaceAll('angkatan', '')
                  .replaceAll(RegExp(r'[^a-z0-9]'), '')
                  .trim();
            }

            final scClass = superClean(widget.classData!['name'] ?? widget.classData!['kelas']);
            final scRombel = superClean(widget.classData!['rombel']);
            final scBatch = superClean(widget.classData!['batch'] ?? widget.classData!['angkatan']);

            try {
              _selectedTeacher = teachers.firstWhere((t) {
                final tw = superClean(t['wali_kelas']);
                final tr = superClean(t['rombel_wali']);
                final tb = superClean(t['angkatan_wali']);
                
                // Tiered matching for selection too
                return (tw == scClass && tr == scRombel && tb == scBatch) ||
                       (tw == scClass && tr == scRombel) ||
                       (tw == scClass);
              });
            } catch (_) {
              _selectedTeacher = null;
            }
          }
          _isFetchingTeachers = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching teachers: $e');
      if (mounted) setState(() => _isFetchingTeachers = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rombelCtrl.dispose();
    _batchCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final className = _nameCtrl.text.trim();
      final rombel = _rombelCtrl.text.trim();
      final batch = _batchCtrl.text.trim();

      final data = {
        'name': className,
        'rombel': rombel,
        'batch': batch,
      };

      if (widget.classData != null && widget.classData!['id'] != null) {
        // 1. Get old data to clear previous assignments
        final oldClassName = widget.classData!['name'] ?? widget.classData!['kelas'];
        final oldRombel = widget.classData!['rombel'];
        final oldBatch = widget.classData!['batch'] ?? widget.classData!['angkatan'];

        // 2. Clear previous homeroom teacher for this class
        final matchingTeachers = await apiService.getTable('teachers', queryParameters: {
          'wali_kelas': oldClassName,
          'rombel_wali': oldRombel,
          'angkatan_wali': oldBatch,
        });
        for (var t in matchingTeachers) {
          await apiService.update('teachers', t['id'].toString(), {
            'wali_kelas': null, 'rombel_wali': null, 'angkatan_wali': null
          });
        }

        // 3. Update class data
        await apiService.update('classes', widget.classData!['id'].toString(), data);
        
        // 4. Update student records as well (if they exist and depend on these fields)
        final matchingStudents = await apiService.getTable('students', queryParameters: {
          'class': oldClassName,
          'rombel': oldRombel,
          'batch': oldBatch,
        });
        for (var s in matchingStudents) {
          await apiService.update('students', s['id'].toString(), {
            'class': className, 'rombel': rombel, 'batch': batch
          });
        }

        if (mounted) NotificationHelper.show(context, 'Berhasil memperbarui data kelas');
      } else {
        await apiService.insert('classes', data);
        if (mounted) NotificationHelper.show(context, 'Berhasil menambah kelas baru');
      }

      if (_selectedTeacher != null) {
        await apiService.update('teachers', _selectedTeacher!['id'].toString(), {
          'wali_kelas': className,
          'rombel_wali': rombel,
          'angkatan_wali': batch,
        });
      }

      if (mounted) {
        if (widget.onBack != null) {
          widget.onBack!();
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) NotificationHelper.show(context, 'Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteClass() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kelas'),
        content: const Text('Apakah Anda yakin ingin menghapus data kelas ini?'),
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
        final oldClassName = widget.classData!['name'] ?? widget.classData!['kelas'];
        final oldRombel = widget.classData!['rombel'];
        final oldBatch = widget.classData!['batch'] ?? widget.classData!['angkatan'];

        // 1. Clear homeroom teacher assignment
        final matchingTeachers = await apiService.getTable('teachers', queryParameters: {
          'wali_kelas': oldClassName,
          'rombel_wali': oldRombel,
          'angkatan_wali': oldBatch,
        });
        for (var t in matchingTeachers) {
          await apiService.update('teachers', t['id'].toString(), {
            'wali_kelas': null, 'rombel_wali': null, 'angkatan_wali': null
          });
        }

        // 2. Delete class
        await apiService.delete('classes', widget.classData!['id'].toString());
        
        if (mounted) {
          NotificationHelper.show(context, 'Kelas berhasil dihapus');
          if (widget.onBack != null) {
            widget.onBack!();
          } else {
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (mounted) NotificationHelper.show(context, 'Gagal menghapus kelas: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field('Nama Kelas', _nameCtrl, 'Contoh: TK A', required: true, icon: Icons.meeting_room_rounded),
                    const SizedBox(height: 20),
                    _field('Rombel', _rombelCtrl, 'Contoh: 1', required: true, icon: Icons.groups_3_rounded),
                    const SizedBox(height: 20),
                    _field('Angkatan / Tahun Ajaran', _batchCtrl, 'Contoh: 2024/2025', required: true, icon: Icons.calendar_today_rounded),
                    const SizedBox(height: 20),
                    _teacherDropdown(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveClass,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(widget.classData != null ? 'Simpan Perubahan' : 'Tambah Kelas', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.isEmbedded) return Container(color: backgroundColor, child: content);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(child: content),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.classData != null ? 'Edit Kelas' : 'Tambah Kelas Baru',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark),
          ),
          Row(
            children: [
              if (widget.classData != null && widget.classData!['id'] != null) ...[
                IconButton(
                  onPressed: _deleteClass,
                  icon: Icon(Icons.delete_outline_rounded, color: errorRed),
                  tooltip: 'Hapus Kelas',
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: () => widget.onBack != null ? widget.onBack!() : Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Batal'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textDark,
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teacherDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Wali Kelas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
        const SizedBox(height: 8),
        DropdownButtonFormField<Map<String, dynamic>>(
          initialValue: _selectedTeacher,
          hint: Text(_isFetchingTeachers ? 'Memuat guru...' : 'Pilih Wali Kelas', style: TextStyle(color: textMuted, fontSize: 13)),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.person_rounded, color: primaryTeal, size: 20),
            filled: true,
            fillColor: AppColors.backgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryTeal)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: [
            const DropdownMenuItem<Map<String, dynamic>>(
              value: null,
              child: Text('Belum ada wali kelas', style: TextStyle(fontSize: 14)),
            ),
            ..._teachers.map((t) => DropdownMenuItem(
              value: t,
              child: Text(t['name'] ?? '-', style: const TextStyle(fontSize: 14)),
            )),
          ],
          onChanged: _isFetchingTeachers ? null : (val) {
            setState(() => _selectedTeacher = val);
          },
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint, {bool required = false, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
        SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, color: primaryTeal, size: 20) : null,
            filled: true,
            fillColor: AppColors.backgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryTeal)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: required ? (v) => v == null || v.isEmpty ? 'Wajib diisi' : null : null,
        ),
      ],
    );
  }
}
