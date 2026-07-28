import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'tambah_guru.dart';
import 'detail_guru.dart';
import '../utils/notification_helper.dart';
import '../utils/excel_helper.dart';

class DataGuruPage extends StatefulWidget {
  final bool isEmbedded;
  final Function(int, {Map<String, dynamic>? teacher})? onNavigate;
  const DataGuruPage({super.key, this.isEmbedded = false, this.onNavigate});

  @override
  State<DataGuruPage> createState() => _DataGuruPageState();
}

class _DataGuruPageState extends State<DataGuruPage> {
  // --- Color Palette ---
  final Color primaryTeal = AppColors.primary; 
  final Color backgroundColor = AppColors.backgroundColor;
  final Color textDark = AppColors.textDark;
  final Color textSecondary = AppColors.textSecondary;
  final Color textMuted = AppColors.textMuted;

  final supabase = Supabase.instance.client;
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  bool _showFilters = true;
  final TextEditingController _searchController = TextEditingController();

  String _selectedGender = 'Semua Jenis Kelamin';
  String _selectedRole = 'Semua Jabatan';
  String _selectedSubject = 'Semua Mata Pelajaran';

  final List<String> _genders = ['Semua Jenis Kelamin', 'Laki-laki', 'Perempuan'];
  List<String> _roles = ['Semua Jabatan'];
  List<String> _subjects = ['Semua Mata Pelajaran'];

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final d = await supabase.from('teachers').select().order('name', ascending: true);
      if (mounted) {
        final roles = d.map((t) => (t['role'] ?? t['position'])?.toString()).whereType<String>().toSet().toList()..sort();
        final subjects = d.map((t) => t['subject']?.toString()).whereType<String>().toSet().toList()..sort();
        
        setState(() {
          _all = d;
          _roles = ['Semua Jabatan', ...roles];
          _subjects = ['Semua Mata Pelajaran', ...subjects];
          _applyFilters();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _all.where((t) {
        final query = _searchController.text.toLowerCase();
        final name = (t['name'] ?? '').toString().toLowerCase();
        final nip = (t['nip'] ?? '').toString().toLowerCase();
        final subject = (t['subject'] ?? '').toString().toLowerCase();

        final matchesSearch = name.contains(query) || nip.contains(query) || subject.contains(query);
        
        // Handle gender mapping if DB stores L/P
        final genderValue = t['gender'] == 'L' ? 'Laki-laki' : (t['gender'] == 'P' ? 'Perempuan' : t['gender']);
        final matchesGender = _selectedGender == 'Semua Jenis Kelamin' || genderValue == _selectedGender;

        final matchesRole = _selectedRole == 'Semua Jabatan' || (t['role'] ?? t['position']) == _selectedRole;
        final matchesSubject = _selectedSubject == 'Semua Mata Pelajaran' || t['subject'] == _selectedSubject;

        return matchesSearch && matchesGender && matchesRole && matchesSubject;
      }).toList();
    });
  }

  Future<void> _deleteTeacher(Map<String, dynamic> teacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data'),
        content: Text('Apakah Anda yakin ingin menghapus data guru ${teacher['name']}?'),
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
        await supabase.from('teachers').delete().eq('id', teacher['id']);
        if (mounted) {
          NotificationHelper.show(context, 'Data guru berhasil dihapus');
          _fetchData();
        }
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
                  _buildFilterSection(),
                  const SizedBox(height: 24),
                  _buildMainContentCard(),
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
            'Data Guru',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _headerButtonMobile(Icons.add_rounded, 'Tambah', onTap: () {
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(11);
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TambahGuruPage()));
                  }
                }, isPrimary: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _headerButtonMobile(Icons.download_rounded, 'Template', onTap: () async {
                  try {
                    await ExcelHelper.downloadTeacherTemplate();
                    if (mounted) NotificationHelper.show(context, 'Template berhasil didownload');
                  } catch (e) {
                    if (mounted) NotificationHelper.show(context, 'Gagal download template: $e', isError: true);
                  }
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _headerButtonMobile(Icons.upload_rounded, 'Import', onTap: () async {
                  try {
                    int count = await ExcelHelper.importTeachersFromExcel();
                    if (count > 0) {
                      if (mounted) NotificationHelper.show(context, 'Berhasil mengimpor $count data guru');
                      _fetchData();
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
        Text('Data Guru', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _headerButton(Icons.download_outlined, 'Download Template', onTap: () async {
              try {
                await ExcelHelper.downloadTeacherTemplate();
                if (mounted) NotificationHelper.show(context, 'Template berhasil didownload');
              } catch (e) {
                if (mounted) NotificationHelper.show(context, 'Gagal download template: $e', isError: true);
              }
            }),
            const SizedBox(width: 12),
            _headerButton(Icons.upload_outlined, 'Import Excel', onTap: () async {
              try {
                int count = await ExcelHelper.importTeachersFromExcel();
                if (count > 0) {
                  if (mounted) NotificationHelper.show(context, 'Berhasil mengimpor $count data guru');
                  _fetchData();
                }
              } catch (e) {
                if (mounted) NotificationHelper.show(context, 'Gagal impor data: $e', isError: true);
              }
            }),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                if (widget.onNavigate != null) {
                  widget.onNavigate!(11);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TambahGuruPage()));
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Guru', style: TextStyle(fontWeight: FontWeight.bold)),
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
        backgroundColor: Colors.white,
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
                            hintText: isMobile ? 'Cari...' : 'Cari nama guru, NIP, atau mata pelajaran...',
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
                      _dropdownFilter(_genders, _selectedGender, (v) {
                        setState(() => _selectedGender = v!);
                        _applyFilters();
                      }),
                      const SizedBox(width: 8),
                      _dropdownFilter(_roles, _selectedRole, (v) {
                        setState(() => _selectedRole = v!);
                        _applyFilters();
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _dropdownFilter(_subjects, _selectedSubject, (v) {
                        setState(() => _selectedSubject = v!);
                        _applyFilters();
                      }),
                    ],
                  ),
                ],
              )
            else
              Row(
                children: [
                  _dropdownFilter(_genders, _selectedGender, (v) {
                    setState(() => _selectedGender = v!);
                    _applyFilters();
                  }),
                  const SizedBox(width: 12),
                  _dropdownFilter(_roles, _selectedRole, (v) {
                    setState(() => _selectedRole = v!);
                    _applyFilters();
                  }),
                  const SizedBox(width: 12),
                  _dropdownFilter(_subjects, _selectedSubject, (v) {
                    setState(() => _selectedSubject = v!);
                    _applyFilters();
                  }),
                ],
              ),
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

  Widget _buildMainContentCard() {
    return Column(
      children: [
        ..._filtered.map((t) => _buildTeacherMobileCard(t)),
      ],
    );
  }

  Widget _buildTeacherMobileCard(Map<String, dynamic> t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (widget.onNavigate != null) {
              widget.onNavigate!(16, teacher: t);
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => DetailGuruPage(teacher: t)));
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
                    (t['name'] ?? '?').toString().isNotEmpty 
                        ? t['name'].toString()[0].toUpperCase() 
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
                        t['name'] ?? '-',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${t['role'] ?? 'Guru Kelas'} • ${t['subject'] ?? '-'}',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                      if (t['wali_kelas'] != null)
                        Text(
                          'Wali Kelas ${t['wali_kelas']} • ${t['angkatan_wali'] ?? '-'}',
                          style: TextStyle(fontSize: 11, color: primaryTeal, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
                _actionBtn(Icons.edit_outlined, Colors.blue, onTap: () {
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(11, teacher: t);
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => TambahGuruPage(teacher: t)));
                  }
                }),
                const SizedBox(width: 8),
                _actionBtn(Icons.delete_outline, Colors.red, onTap: () => _deleteTeacher(t)),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
              ],
            ),
          ),
        ),
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
        children: [
          Icon(icon, size: 18, color: textDark),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: textDark, fontWeight: FontWeight.w500)),
          ],
        ],
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
