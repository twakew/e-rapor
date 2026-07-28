import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import '../utils/notification_helper.dart';

class DetailDokumentasiPage extends StatefulWidget {
  final dynamic dokumentasi;
  final VoidCallback? onBack;
  const DetailDokumentasiPage({super.key, required this.dokumentasi, this.onBack});

  @override
  State<DetailDokumentasiPage> createState() => _DetailDokumentasiPageState();
}

class _DetailDokumentasiPageState extends State<DetailDokumentasiPage> {
  int _currentPage = 0;
  late List<String> _images;
  bool _isDownloading = false;
  bool _showInfo = true;

  @override
  void initState() {
    super.initState();
    final imageUrl = widget.dokumentasi['image_url'] as String? ?? '';
    _images = imageUrl.split(',').where((s) => s.trim().isNotEmpty).toList();
  }

  Future<void> _downloadImage() async {
    if (_isDownloading) return;
    
    setState(() => _isDownloading = true);
    
    try {
      final String url = _images[_currentPage].trim();
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/downloaded_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(path);
        await file.writeAsBytes(response.bodyBytes);
        
        await Gal.putImage(path);
        if (mounted) NotificationHelper.show(context, 'Gambar berhasil disimpan ke galeri');
      } else {
        throw Exception('Gagal mengunduh gambar');
      }
    } catch (e) {
      if (mounted) NotificationHelper.show(context, 'Gagal mengunduh: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full Image Gallery
          GestureDetector(
            onTap: () => setState(() => _showInfo = !_showInfo),
            child: PageView.builder(
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: _images.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Hero(
                    tag: 'image_${widget.dokumentasi['id']}_$index',
                    child: Image.network(
                      _images[index].trim(),
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      },
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined, 
                        size: 80, 
                        color: Colors.white24
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Header Buttons (Back & Download) - Glassy Style
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showInfo ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showInfo,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGlassButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () {
                        if (widget.onBack != null) {
                          widget.onBack!();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    Row(
                      children: [
                        if (_images.length > 1)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Text(
                                  '${_currentPage + 1} / ${_images.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        _buildGlassButton(
                          icon: _isDownloading ? Icons.hourglass_empty_rounded : Icons.download_rounded,
                          onTap: _downloadImage,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Info Panel - Glassmorphism Effect
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showInfo ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showInfo,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _formatDate(widget.dokumentasi['created_at']),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.dokumentasi['title'] ?? 'Tanpa Judul',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.dokumentasi['description'] ?? 'Tidak ada deskripsi.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              onPressed: () => setState(() => _showInfo = false),
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({required IconData icon, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 20),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }
}
