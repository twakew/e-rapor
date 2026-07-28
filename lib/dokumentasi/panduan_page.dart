import 'package:flutter/material.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';

class PanduanPage extends StatefulWidget {
  final Function(int)? onNavigate;

  const PanduanPage({super.key, this.onNavigate});

  @override
  State<PanduanPage> createState() => _PanduanPageState();
}

class _PanduanPageState extends State<PanduanPage> {
  // Clean Palette (Consistent with the project)
  final Color primaryGreen = const Color(0xFF0D9488);
  final Color primaryBlue = const Color(0xFF1D4ED8);
  final Color darkNavy = const Color(0xFF1E1B4B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color bgLight = AppColors.backgroundColor;
  final Color borderColor = const Color(0xFFE2E8F0);

  final List<Map<String, dynamic>> _panduanList = [
    {
      'title': 'Manajemen Data Siswa',
      'icon': Icons.person_search_rounded,
      'desc': 'Cara menambah, mengedit, dan mencari data siswa per angkatan.',
      'color': const Color(0xFF1D4ED8),
      'steps': [
        'Buka menu Data Angkatan.',
        'Pilih tahun angkatan yang diinginkan.',
        'Gunakan fitur pencarian untuk menemukan nama atau NIS siswa.',
        'Klik detail siswa untuk melihat profil lengkap.'
      ]
    },
    {
      'title': 'Input Nilai E-Rapor',
      'icon': Icons.edit_document,
      'desc': 'Prosedur pengisian nilai perkembangan siswa setiap semester.',
      'color': const Color(0xFF0D9488),
      'steps': [
        'Pilih menu Input Nilai pada Dashboard.',
        'Pilih kelas dan mata pelajaran.',
        'Masukkan nilai berdasarkan rubrik yang tersedia.',
        'Klik Simpan dan verifikasi kembali data sebelum dipublish.'
      ]
    },
    {
      'title': 'Cetak Rapor PDF',
      'icon': Icons.picture_as_pdf_rounded,
      'desc': 'Langkah-langkah mengekspor laporan hasil belajar ke format PDF.',
      'color': const Color(0xFFE11D48),
      'steps': [
        'Buka profil detail siswa.',
        'Klik tombol "Cetak Rapor" di pojok kanan atas.',
        'Pilih semester yang akan dicetak.',
        'Tunggu sistem meng-generate PDF dan klik Download.'
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: Column(
        children: [
          _buildHeaderBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIntroSection(),
                  const SizedBox(height: 32),
                  _buildPanduanGrid(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pusat Panduan', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: darkNavy)),
              Icon(Icons.help_outline_rounded, color: primaryBlue),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Panduan Penggunaan', style: TextStyle(fontSize: 13, color: textMuted, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryBlue, primaryBlue.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: primaryBlue.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Halo, Butuh Bantuan?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            'Temukan panduan lengkap penggunaan aplikasi Lapor Sekolah E-Rapor di sini.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPanduanGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1200 ? 3 : (screenWidth > 800 ? 2 : 1);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: screenWidth > 600 ? 1.2 : 1.0,
      ),
      itemCount: _panduanList.length,
      itemBuilder: (context, index) => _buildPanduanCard(_panduanList[index]),
    );
  }

  Widget _buildPanduanCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: item['color'].withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(item['icon'], color: item['color'], size: 28),
          ),
          const SizedBox(height: 20),
          Text(item['title'], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkNavy)),
          const SizedBox(height: 10),
          Text(item['desc'], style: TextStyle(fontSize: 14, color: textSecondary, height: 1.5)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showDetailPanduan(item),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: primaryBlue),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Baca Selengkapnya', style: TextStyle(color: primaryBlue, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailPanduan(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 48, height: 6, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 32),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: item['color'].withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                  child: Icon(item['icon'], color: item['color'], size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['title'], style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkNavy)),
                      Text('Panduan Penggunaan', style: TextStyle(color: textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Text('Langkah-langkah:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkNavy)),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: item['steps'].length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: item['color'],
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: item['color'].withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                          ),
                          child: Center(
                            child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(child: Text(item['steps'][index], style: TextStyle(fontSize: 16, color: textSecondary, height: 1.6))),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkNavy,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Mengerti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
