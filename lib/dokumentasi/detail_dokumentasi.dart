import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../utils/notification_helper.dart';
import '../utils/media_helper.dart';

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
  VideoPlayerController? _vc;

  @override
  void initState() {
    super.initState();
    final imageUrl = widget.dokumentasi['image_url'] as String? ?? '';
    _images = imageUrl.split(',').where((s) => s.trim().isNotEmpty).toList();
    // ponytail: mode video hanya untuk item tunggal; kalau nanti gallery
    // campur foto+video, pisah jadi list media bertipe.
    if (_images.isNotEmpty && isVideoUrl(_images.first)) {
      _vc = VideoPlayerController.networkUrl(Uri.parse(_images.first.trim()));
      _vc!.initialize().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  Future<void> _downloadImage() async {
    if (_isDownloading) return;
    if (_images.isEmpty) {
      if (mounted) NotificationHelper.show(context, 'Tidak ada foto untuk diunduh', isError: true);
      return;
    }

    setState(() => _isDownloading = true);

    try {
      final bool isVideo = _vc != null;
      final String url = (isVideo ? _images.first : _images[_currentPage]).trim();
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('Gagal mengunduh file');

      final uri = Uri.parse(url);
      final lastSeg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final String ext = lastSeg.contains('.')
          ? lastSeg.split('.').last
          : (isVideo ? 'mp4' : 'jpg');

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/downloaded_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File(path);
      await file.writeAsBytes(response.bodyBytes);

      String savedMsg;
      if (Platform.isWindows || Platform.isLinux) {
        // Gal (galeri) cuma Android/iOS/macOS -> desktop simpan ke Downloads.
        final downloads = await getDownloadsDirectory();
        if (downloads == null) throw Exception('Folder Downloads tidak ditemukan');
        final dest = File('${downloads.path}/${path.split('/').last}');
        await file.copy(dest.path);
        savedMsg = 'Tersimpan di ${dest.path}';
      } else if (isVideo) {
        await Gal.putVideo(path);
        savedMsg = 'Berhasil disimpan ke galeri';
      } else {
        await Gal.putImage(path);
        savedMsg = 'Berhasil disimpan ke galeri';
      }
      if (mounted) {
        NotificationHelper.show(context, "${isVideo ? 'Video' : 'Gambar'}: $savedMsg");
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
            child: _vc != null
                ? _buildVideoPlayer()
                : _images.isEmpty
                    ? const Center(child: Icon(Icons.image_not_supported_outlined, size: 80, color: Colors.white24))
                    : PageView.builder(
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
              // Mode video: header (Kembali/Unduh) selalu tampil.
              opacity: (_showInfo || _vc != null) ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !(_showInfo || _vc != null),
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
                        if (_vc == null && _images.length > 1)
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
          if (_vc == null)
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

  Widget _buildVideoPlayer() {
    final vc = _vc!;
    return GestureDetector(
      onTap: () => vc.value.isPlaying ? vc.pause() : vc.play(),
      child: Center(
        child: AspectRatio(
          aspectRatio: vc.value.isInitialized && vc.value.aspectRatio > 0 ? vc.value.aspectRatio : 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(vc),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: vc,
                builder: (context, value, _) {
                  return IgnorePointer(
                    ignoring: !value.isInitialized || value.isPlaying,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: value.isPlaying ? 0.0 : 1.0,
                      child: const Icon(Icons.play_circle_fill_rounded, size: 72, color: Colors.white70),
                    ),
                  );
                },
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: vc,
                  builder: (context, value, _) {
                    final maxMs = value.duration.inMilliseconds <= 0
                        ? 1
                        : value.duration.inMilliseconds;
                    final pos = value.position.inMilliseconds.clamp(0, maxMs);
                    return Slider(
                      value: pos.toDouble(),
                      max: maxMs.toDouble(),
                      onChanged: (v) => vc.seekTo(Duration(milliseconds: v.round())),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
