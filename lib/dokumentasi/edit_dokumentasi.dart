import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';
import '../utils/notification_helper.dart';
import '../utils/media_helper.dart';

class EditDokumentasiPage extends StatefulWidget {
  final dynamic dokumentasi;
  final Function(int)? onNavigate; // Tambahkan onNavigate
  const EditDokumentasiPage({super.key, required this.dokumentasi, this.onNavigate});

  @override
  State<EditDokumentasiPage> createState() => _EditDokumentasiPageState();
}

class _EditDokumentasiPageState extends State<EditDokumentasiPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  PlatformFile? _pickedFile;
  bool _isLoading = false;
  final apiService = ApiService();

  bool get _isMobile => MediaQuery.of(context).size.width < 900;

  // Clean Palette (Consistent with the project)
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
    _titleController = TextEditingController(text: widget.dokumentasi['title']);
    _descController = TextEditingController(text: widget.dokumentasi['description']);
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'mp4', 'mov', 'webm', 'm4v'],
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  Future<Uint8List?> _compressImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) return null;

      if (image.width > 1024) {
        image = img.copyResize(image, width: 1024);
      }

      return Uint8List.fromList(img.encodeJpg(image, quality: 70));
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  Future<File> _saveTempFile(Uint8List bytes) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }

  Future<void> _updateDokumentasi() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      String? imageUrl = widget.dokumentasi['image_url'];

      if (_pickedFile != null) {
        final file = File(_pickedFile!.path!);
        if (isVideoName(_pickedFile!.name)) {
          // Video diupload apa adanya (tanpa kompresi gambar).
          imageUrl = await apiService.uploadFile('dokumentasi', file);
        } else {
          final compressedBytes = await _compressImage(file);
          // Upload via backend storage
          imageUrl = await apiService.uploadFile('dokumentasi', compressedBytes != null
              ? (await _saveTempFile(compressedBytes))
              : file);
        }
        // Old image deletion is handled server-side or ignored for now
      }

      await apiService.update('documentation', widget.dokumentasi['id'].toString(), {
        'title': _titleController.text,
        'description': _descController.text,
        'image_url': imageUrl,
      });

      if (mounted) {
        NotificationHelper.show(context, 'Dokumentasi berhasil diperbarui');
        if (widget.onNavigate != null) {
          widget.onNavigate!(4);
        }
      }
    } catch (e) {
      debugPrint('Error updating documentation: $e');
      if (mounted) {
        NotificationHelper.show(context, 'Gagal memperbarui: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: Column(
        children: [
          _buildHeaderBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: _isMobile ? 16 : 40, vertical: 24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  padding: EdgeInsets.all(_isMobile ? 20 : 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Foto / Video Dokumentasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkNavy)),
                        const SizedBox(height: 16),
                        _buildImagePicker(),
                        const SizedBox(height: 32),
                        _buildTextField(
                          label: 'Judul Kegiatan',
                          controller: _titleController,
                          icon: Icons.title_rounded,
                          hint: 'Masukkan judul dokumentasi...',
                          validator: (v) => v == null || v.isEmpty ? 'Judul tidak boleh kosong' : null,
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          label: 'Deskripsi Kegiatan',
                          controller: _descController,
                          icon: Icons.description_rounded,
                          hint: 'Berikan deskripsi singkat tentang kegiatan ini...',
                          maxLines: 5,
                        ),
                        SizedBox(height: _isMobile ? 32 : 48),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  if (widget.onNavigate != null) {
                                    widget.onNavigate!(4);
                                  } else {
                                    // Jika onNavigate null, kita set index manual via event bus atau cara lain
                                    // Tapi cara terbaik adalah memastikan dasbhor mengirimnya.
                                    // Untuk sekarang kita biarkan kosong agar TIDAK HITAM.
                                    debugPrint('Error: onNavigate is null in EditDokumentasiPage');
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: _isMobile ? 16 : 20),
                                  side: BorderSide(color: borderColor),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Batal', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold, fontSize: _isMobile ? 13 : 15)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _updateDokumentasi,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: _isMobile ? 16 : 20),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Text(
                                        _isMobile ? 'Simpan' : 'Simpan Perubahan', 
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: _isMobile ? 13 : 15),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildHeaderBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(_isMobile ? 16 : 40, _isMobile ? 48 : 60, _isMobile ? 16 : 40, _isMobile ? 12 : 24),
      alignment: Alignment.centerLeft,
      child: Text('Edit Dokumentasi', 
        style: TextStyle(fontSize: _isMobile ? 22 : 26, fontWeight: FontWeight.bold, color: darkNavy)
      ),
    );
  }

  Widget _buildImagePicker() {
    final existingUrl = (widget.dokumentasi['image_url'] ?? '').toString();
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: _isMobile ? 200 : 300,
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, style: BorderStyle.solid),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _pickedFile != null
              ? (isVideoName(_pickedFile!.name)
                  ? _buildVideoPreview()
                  : Image.file(File(_pickedFile!.path!), fit: BoxFit.cover))
              : existingUrl.isNotEmpty
                  ? (isVideoUrl(existingUrl)
                      ? _buildExistingVideoBadge()
                      : Image.network(
                          existingUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.broken_image_outlined, size: 48, color: textMuted),
                        ))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: _isMobile ? 32 : 48, color: textMuted),
                        const SizedBox(height: 12),
                        Text('Ketuk untuk mengubah foto/video', style: TextStyle(color: textSecondary, fontSize: _isMobile ? 12 : 14)),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            _pickedFile!.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${(_pickedFile!.size / (1024 * 1024)).toStringAsFixed(1)} MB',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingVideoBadge() {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.white),
          const SizedBox(height: 12),
          const Text('Video saat ini', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Ketuk untuk mengganti', style: TextStyle(color: textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: darkNavy)),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: textMuted, fontSize: 14),
            prefixIcon: Icon(icon, color: primaryBlue, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryBlue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
