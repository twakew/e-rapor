import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import '../utils/notification_helper.dart';
import '../utils/media_helper.dart';

class DokumentasiPage extends StatefulWidget {
  final Function(int, {dynamic documentation})? onNavigate;

  const DokumentasiPage({super.key, this.onNavigate});

  @override
  State<DokumentasiPage> createState() => _DokumentasiPageState();
}

class _DokumentasiPageState extends State<DokumentasiPage> {
  final apiService = ApiService();
  Timer? _refreshTimer;
  bool _isLoading = true;
  List<dynamic> _dokumentasiList = [];
  List<dynamic> _filteredList = [];
  String _searchQuery = '';
  String _userRole = 'User';

  bool get _isMobile => MediaQuery.of(context).size.width < 900;

  // Clean Palette (Consistent with AngkatanPage & Dashboard)
  final Color primaryGreen = AppColors.primary;
  final Color primaryBlue = AppColors.infoBlue;
  final Color darkNavy = AppColors.textDark;
  final Color textSecondary = const Color(0xFF64748B);
  final Color textMuted = Color(0xFF94A3B8);
  final Color bgLight = AppColors.backgroundColor;
  final Color borderColor = AppColors.borderColor;

  @override
  void initState() {
    super.initState();
    _setupRealtime();
    _fetchUserRole();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _setupRealtime() {
    setState(() => _isLoading = true);
    _fetchDokumentasi();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchDokumentasi());
  }

  Future<void> _fetchUserRole() async {
    if (mounted) setState(() => _userRole = 'Admin');
  }

  Future<void> _fetchDokumentasi() async {
    try {
      setState(() => _isLoading = true);
      final response = await apiService.getTable('documentation');
      
      setState(() {
        _dokumentasiList = response;
        _filterData();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching documentation: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterData() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredList = _dokumentasiList;
      } else {
        _filteredList = _dokumentasiList.where((item) {
          final title = (item['title'] ?? '').toString().toLowerCase();
          final desc = (item['description'] ?? '').toString().toLowerCase();
          return title.contains(_searchQuery.toLowerCase()) || 
                 desc.contains(_searchQuery.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: Column(
        children: [
          _buildHeaderBar(),
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: primaryBlue))
              : RefreshIndicator(
                  onRefresh: _fetchDokumentasi,
                  color: primaryBlue,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: _isMobile ? 16 : 40, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterRow(),
                        const SizedBox(height: 24),
                        _buildGridSection(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
      floatingActionButton: (_userRole == 'Admin' || _userRole == 'Guru' || _userRole == 'Super Admin')
        ? FloatingActionButton.extended(
            onPressed: () {
              widget.onNavigate?.call(19);
            },
            backgroundColor: primaryBlue,
            elevation: 4,
            icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
            label: const Text('Tambah Dokumentasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        : null,
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(_isMobile ? 16 : 40, _isMobile ? 12 : 48, _isMobile ? 16 : 40, _isMobile ? 16 : 24),
      color: Colors.transparent,
      alignment: Alignment.centerLeft,
      child: Text('Dokumentasi Kegiatan', 
        style: TextStyle(fontSize: _isMobile ? 20 : 26, fontWeight: FontWeight.bold, color: darkNavy)
      ),
    );
  }

  Widget _buildFilterRow() {
    if (_isMobile) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardWhite, 
                borderRadius: BorderRadius.circular(12), 
                border: Border.all(color: borderColor)
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) {
                        _searchQuery = v;
                        _filterData();
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari judul...',
                        hintStyle: TextStyle(fontSize: 12, color: textMuted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
              ),
              child: Center(
                child: Text(
                  'Total: ${_dokumentasiList.length}', 
                  style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 12)
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardWhite, 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: borderColor)
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: primaryBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (v) {
                      _searchQuery = v;
                      _filterData();
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari judul atau deskripsi kegiatan...',
                      hintStyle: TextStyle(fontSize: 14, color: textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        _statusBadge('Total Data: ${_dokumentasiList.length}', primaryBlue),
      ],
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildGridSection() {
    if (_filteredList.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 100),
            Icon(Icons.collections_outlined, size: 80, color: textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Dokumentasi tidak ditemukan', style: TextStyle(color: textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1200 ? 4 : (screenWidth > 800 ? 3 : 2);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: _isMobile ? 12 : 24,
        crossAxisSpacing: _isMobile ? 12 : 24,
        childAspectRatio: _isMobile ? 0.85 : 0.8,
      ),
      itemCount: _filteredList.length,
      itemBuilder: (context, index) => _buildDokumentasiCard(_filteredList[index]),
    );
  }

  Widget _buildDokumentasiCard(dynamic item) {
    final bool isAdmin = _userRole == 'Admin' || _userRole == 'Guru' || _userRole == 'Super Admin';
    final String imageUrl = (item['image_url'] ?? '').toString();
    final String firstMedia = imageUrl.split(',').where((s) => s.trim().isNotEmpty).firstOrNull?.trim() ?? '';
    final bool isVideo = firstMedia.isNotEmpty && isVideoUrl(firstMedia);

    return GestureDetector(
      onTap: () {
        widget.onNavigate?.call(21, documentation: item);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_isMobile ? 16 : 24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_isMobile ? 16 : 24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Fotonya (Full Card)
              Hero(
                tag: 'image_${item['id']}',
                child: isVideo
                    ? Container(
                        color: AppColors.textDark,
                        child: const Center(
                          child: Icon(Icons.play_circle_fill_rounded, size: 56, color: Colors.white70),
                        ),
                      )
                    : imageUrl.isEmpty
                    ? Container(
                        color: AppColors.textMuted,
                        child: Icon(Icons.image_outlined, size: 48, color: textMuted),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.textMuted,
                          child: Icon(Icons.broken_image_outlined, size: 32, color: textMuted),
                        ),
                      ),
              ),
              
              // 2. Gradient Overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. Konten Teks
              Padding(
                padding: EdgeInsets.all(_isMobile ? 12 : 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(item['created_at']),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: _isMobile ? 9 : 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['title'] ?? 'Tanpa Judul',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _isMobile ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Action Buttons
              if (isAdmin)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      _buildGalleryActionButton(
                        icon: Icons.edit_rounded,
                        onTap: () {
                          widget.onNavigate?.call(20, documentation: item);
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildGalleryActionButton(
                        icon: Icons.delete_rounded,
                        onTap: () => _deleteDokumentasi(item),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper untuk tombol aksi di dalam foto
  Widget _buildGalleryActionButton({required IconData icon, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Material(
        color: Colors.black.withValues(alpha: 0.3),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return '';
    }
  }

  Future<void> _deleteDokumentasi(Map<String, dynamic> item) async {
    final id = item['id'];
    final imageUrl = item['image_url'] as String?;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus Dokumentasi?', style: TextStyle(fontWeight: FontWeight.bold, color: darkNavy)),
        content: const Text('Data ini akan dihapus permanen dari sistem.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            final String bucketName = 'dokumentasi';
            final urls = imageUrl.split(',');
            List<String> filesToDelete = [];
            for (var url in urls) {
              if (url.trim().isNotEmpty) {
                final uri = Uri.parse(url.trim());
                final pathSegments = uri.pathSegments;
                final bucketIdx = pathSegments.indexOf(bucketName);
                if (bucketIdx != -1 && bucketIdx < pathSegments.length - 1) {
                  filesToDelete.add(pathSegments.sublist(bucketIdx + 1).join('/'));
                }
              }
            }
            if (filesToDelete.isNotEmpty) {
              // Delete storage via backend is not yet supported, skipped for now
            }
          } catch (e) {
            debugPrint('Storage Delete Warning: $e');
          }
        }

        try {
          await apiService.delete('documentation', id.toString());
        } on DioException catch (e) {
          // 404 = baris sudah terhapus (klik ganda / tab lain) -> sukses.
          if (e.response?.statusCode != 404) rethrow;
        }
        // Hilangkan dari list langsung, jangan nunggu poll 15 detik.
        _dokumentasiList.removeWhere((d) => d['id'].toString() == id.toString());
        _filterData();
        if (mounted) NotificationHelper.show(context, 'Dokumentasi berhasil dihapus');
      } catch (e) {
        String msg = 'Gagal menghapus';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['error'] != null) {
            msg = data['error'].toString();
          } else if (e.response?.statusCode != null) {
            msg = 'Gagal menghapus (HTTP ${e.response!.statusCode})';
          }
        }
        if (mounted) NotificationHelper.show(context, msg, isError: true);
      }
    }
  }
}
