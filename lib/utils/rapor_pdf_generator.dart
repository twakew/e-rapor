import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

class RaporPdfGenerator {
  static String clean(String s) {
    if (s.isEmpty) return "";
    return s.replaceAll('•', '-')
            .replaceAll('●', '-')
            .replaceAll('○', '-')
            .replaceAll('▪', '-')
            .replaceAll('–', '-')
            .replaceAll('—', '-')
            .replaceAll(RegExp(r'[^\x20-\x7E\n]'), '');
  }

  static Future<pw.MemoryImage?> _getImg(String url) async {
    if (url.isEmpty) return null;
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) return pw.MemoryImage(r.bodyBytes);
    } catch (_) {}
    return null;
  }

  // Fungsi pencarian kategori yang super fleksibel & toleran
  static List<dynamic> _findItems(Map<String, List<dynamic>> g, String searchKey) {
    searchKey = searchKey.trim().toUpperCase();
    List<dynamic> results = [];
    
    // 1. Coba exact match dulu
    if (g.containsKey(searchKey)) {
      results.addAll(g[searchKey]!);
    }
    
    // 2. Normalisasi kunci pencarian (hapus spasi, simbol, ubah & jadi DAN)
    String normSearch = searchKey.replaceAll('&', 'DAN').replaceAll(RegExp(r'[^A-Z0-9]'), '');
    
    g.forEach((key, value) {
      String normKey = key.trim().toUpperCase().replaceAll('&', 'DAN').replaceAll(RegExp(r'[^A-Z0-9]'), '');
      
      // Jika hasil pencarian belum ada atau kunci cocok setelah dinormalisasi
      if (normKey == normSearch && !results.contains(value.first)) {
        results.addAll(value);
      } 
      // Kasus khusus Dasar Literasi / STREAM
      else if ((normSearch.contains("LITERASI") || normSearch.contains("STREAM")) && 
               (normKey.contains("LITERASI") || normKey.contains("STREAM"))) {
        if (!results.contains(value.first)) results.addAll(value);
      }
    });
    
    // Hilangkan duplikasi data berdasarkan ID jika ada
    final seen = <dynamic>{};
    return results.where((item) => seen.add(item['id'])).toList();
  }

  static Future<void> generateRapor({
    required pw.Document pdf,
    required dynamic student,
    required List<dynamic> assessments,
    required Map<String, dynamic> school,
    pw.MemoryImage? logoImage,
    pw.MemoryImage? planetImg,
    pw.MemoryImage? rocketImg,
    pw.MemoryImage? bookImg,
    pw.MemoryImage? heroImg,
    pw.MemoryImage? mosqueImg,
    pw.MemoryImage? quranImg,
    pw.MemoryImage? familyImg,
    pw.MemoryImage? childrenImg,
  }) async {
    // 0. Tentukan Tanggal Rapor (Satu sumber untuk semua halaman)
    final String reportDate = assessments.isNotEmpty 
        ? _formatDate(assessments.firstWhere((a) => a['report_date'] != null, orElse: () => assessments.first)['report_date'] ?? assessments.first['created_at']) 
        : _formatDate(DateTime.now().toIso8601String());

    // Normalisasi data siswa (Handle jika hasil join berupa List dari Supabase)
    final Map<String, dynamic> sData = (student is List && student.isNotEmpty) 
        ? Map<String, dynamic>.from(student.first) 
        : (student is Map ? Map<String, dynamic>.from(student) : {});

    final Map<String, List<dynamic>> grouped = {};
    for (var item in assessments) {
      String catRaw = (item['category']?.toString() ?? 'Lainnya').trim().toUpperCase();
      String catKey = (catRaw.contains('|') ? catRaw.split('|')[0] : catRaw).trim();
      if (!grouped.containsKey(catKey)) grouped[catKey] = [];
      grouped[catKey]!.add(item);
    }

    String getDisplayTitle(String originalKey, String defaultVal) {
      final items = _findItems(grouped, originalKey);
      if (items.isEmpty) return defaultVal;
      final raw = items.first['category']?.toString() ?? '';
      if (raw.contains('|')) return raw.split('|')[1].toUpperCase();
      return defaultVal;
    }

    String getMaterial(String category, String defaultVal) {
      final items = _findItems(grouped, category);
      if (items.isEmpty) return clean(defaultVal);
      final m = items.first['material']?.toString() ?? "";
      return clean(m.isEmpty ? defaultVal : m);
    }

    String getScore(String category) {
      final items = _findItems(grouped, category);
      if (items.isEmpty) return "-";
      final score = items.first["score"]?.toString() ?? "-";
      return (score.isEmpty || score == 'null') ? "-" : score;
    }

    // Helper untuk mengambil data siswa dengan aman (Sangat Robust)
    String val(String key, [String def = ""]) {
      // 1. Coba snake_case (standard)
      var v = sData[key];
      
      // 2. Coba camelCase (siapa tahu)
      if (v == null) {
        final camelKey = key.split('_').asMap().entries.map((e) => e.key == 0 ? e.value : e.value[0].toUpperCase() + e.value.substring(1)).join();
        v = sData[camelKey];
      }
      
      // 3. Coba mapping manual untuk field kritis
      if (v == null) {
        if (key == 'father_name') v = sData['nama_ayah'] ?? sData['ayah'];
        if (key == 'mother_name') v = sData['nama_ibu'] ?? sData['ibu'];
        if (key == 'parent_phone') v = sData['no_hp'] ?? sData['telepon'] ?? sData['parentPhone'];
        if (key == 'birth_place') v = sData['tempat_lahir'] ?? sData['birthPlace'];
        if (key == 'birth_date') v = sData['tanggal_lahir'] ?? sData['birthDate'];
      }

      if (v == null || v.toString().toLowerCase() == "null" || v.toString() == "-") return def;
      return v.toString();
    }

    // --- HALAMAN 1 & 2 (Cover & Identitas) ---
    pdf.addPage(pw.Page(build: (c) => pw.Center(child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
      if (logoImage != null) pw.Image(logoImage, width: 140),
      pw.SizedBox(height: 40),
      pw.Text("LAPORAN PERKEMBANGAN", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Text("PESERTA DIDIK TAMAN KANAK-KANAK ISLAM TERPADU", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
      pw.Text('"AL-HANIF LEDENG"', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 80),
      pw.Container(width: double.infinity, padding: const pw.EdgeInsets.symmetric(horizontal: 100), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _coverRow("Nama Lembaga", ": ${school['name']?.toString().toUpperCase() ?? 'TKIT AL-HANIF LEDENG'}"),
        _coverRow("Alamat", ": ${school['address'] ?? 'Jl. Ledeng Sitopeng Komp. Griya Bintang'}"),
        _coverRow("Desa/Kelurahan", ": ${school['village'] ?? 'Kalijaga'}"),
        _coverRow("Kecamatan", ": ${school['district'] ?? 'Harjamukti'}"),
        _coverRow("Kota/Kabupaten", ": ${school['city'] ?? 'Kota Cirebon'}"),
      ])),
      pw.SizedBox(height: 80),
      pw.Text("Nama Anak Didik", style: const pw.TextStyle(fontSize: 12)),
      pw.SizedBox(height: 10),
      pw.Text(val('name').toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
      pw.SizedBox(height: 5),
      pw.Text("Nomor Induk : ${val('nis')}"),
    ]))));

    pdf.addPage(pw.Page(margin: const pw.EdgeInsets.all(50), build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Center(child: pw.Text("IDENTITAS ANAK", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 30),
      pw.Padding(padding: const pw.EdgeInsets.only(left: 30), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _idRow("1. Nama Anak Didik", ": ${val('name').toUpperCase()}"),
        _idRow("   Nama Panggilan", ": ${val('nickname').isNotEmpty ? val('nickname').toUpperCase() : (val('name').isNotEmpty ? val('name').split(' ').first.toUpperCase() : '-')}"),
        _idRow("2. NISN / NIS", ": ${val('nis')}"),
        _idRow("3. Jenis Kelamin", ": ${val('gender').toUpperCase() == "L" ? "Laki-laki" : (val('gender').toUpperCase() == "P" ? "Perempuan" : val('gender'))}"),
        _idRow("4. Tempat, Tanggal Lahir", ": ${val('birth_place')}, ${_formatDate(val('birth_date'))}"),
        _idRow("5. Agama", ": ${val('religion')}"),
        _idRow("6. Anak ke", ": ${val('child_number')}"),
        pw.SizedBox(height: 10),
        _idRow("7. Orang Tua / Wali", "", isBold: true),
        _idRow("   Nama Ayah", ": ${val('father_name')}"),
        _idRow("   Nama Ibu", ": ${val('mother_name')}"),
        _idRow("   Nomor HP", ": ${val('parent_phone')}"),
        pw.SizedBox(height: 10),
        _idRow("8. Pekerjaan Orang Tua / Wali", "", isBold: true),
        _idRow("   Ayah", ": ${val('father_job')}"),
        _idRow("   Ibu", ": ${val('mother_job')}"),
        pw.SizedBox(height: 10),
        _idRow("9. Alamat Orang Tua / Wali", "", isBold: true),
        _idRow("   Nama Jalan", ": ${val('parent_address').isNotEmpty ? val('parent_address') : val('address', '-')}"),
        _idRow("   RT / RW", ": ${val('rt').isEmpty && val('rw').isEmpty ? '-' : '${val('rt')} / ${val('rw')}'}"),
        _idRow("   Kelurahan / Desa", ": ${val('village', '-')}"),
        _idRow("   Kecamatan", ": ${val('parent_district', '-')}"),
        _idRow("   Kabupaten / Kota", ": ${val('parent_city', '-')}"),
        _idRow("   Provinsi", ": ${val('parent_province', '-')}"),
      ])),
      pw.SizedBox(height: 90),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Container(width: 80, height: 110, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Center(child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [pw.Text("Foto", style: const pw.TextStyle(fontSize: 11)), pw.SizedBox(height: 10), pw.Text("3 x 4", style: const pw.TextStyle(fontSize: 11))]))),
        pw.SizedBox(width: 80),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text("Cirebon, $reportDate", style: const pw.TextStyle(fontSize: 11)),
          pw.Text("Kepala TKIT Al-Hanif Ledeng", style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 60),
          pw.Text(school['headmaster_name']?.toString().toUpperCase() ?? "SITI AISYAH S.P.d AUD", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline, fontSize: 11)),
          pw.Text("Nuptk. ${school['headmaster_nip'] ?? '-'}", style: const pw.TextStyle(fontSize: 10)),
        ]),
      ]),
    ])));

    // --- HALAMAN 3+: LAPORAN CAPAIAN ---
    final List<pw.Widget> mainWidgets = [];
    final int semester = assessments.isNotEmpty ? (assessments.first['semester'] ?? 1) : 1;
    final String semesterText = semester == 1 ? "I (Satu)" : "II (Dua)";

    mainWidgets.add(pw.Row(children: [
      if (logoImage != null) pw.Image(logoImage, width: 60),
      pw.SizedBox(width: 15),
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text("LAPORAN CAPAIAN PEMBELAJARAN", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.Text(school['name']?.toString().toUpperCase() ?? "TKIT AL-HANIF LEDENG", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.Text("TAHUN ${school['curriculum']?.toString() ?? '2025/2026'}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ])
    ]));
    mainWidgets.add(pw.SizedBox(height: 15));
    final DateTime refDate = assessments.isNotEmpty && assessments.first['created_at'] != null ? DateTime.parse(assessments.first['created_at'].toString()) : DateTime.now();

    mainWidgets.add(pw.Row(children: [
      pw.Expanded(child: pw.Column(children: [_box("Nama", val('name')), _box("Kelas", val('class')), _box("NIS", val('nis'))])),
      pw.SizedBox(width: 20),
      pw.Expanded(child: pw.Column(children: [_box("Semester", semesterText), _box("Usia", _calcAge(val('birth_date'), refDate)), _box("Fase", "Fondasi")])),
    ]));
    mainWidgets.add(pw.SizedBox(height: 10));
    mainWidgets.add(pw.Divider(thickness: 1, color: PdfColors.orange200));

    final categories = [
      {"t": "NILAI AGAMA DAN BUDI PEKERTI", "i": planetImg},
      {"t": "JATI DIRI", "i": rocketImg},
      {"t": "DASAR LITERASI, SAINS, TEKNOLOGI, REKAYASA, & SENI", "i": bookImg},
      {"t": "PROJEK PENGUATAN PROFIL LULUSAN", "i": heroImg},
    ];

    for (var cat in categories) {
      final String originalTitle = cat['t'] as String;
      final String title = getDisplayTitle(originalTitle, originalTitle);
      final pw.MemoryImage? icon = cat['i'] as pw.MemoryImage?;
      
      final List<dynamic> items = _findItems(grouped, originalTitle);
      if (items.isEmpty) continue;

      final List<pw.Widget> catSection = [];
      catSection.add(_catHeader(title, icon));
      
      String combinedNotes = "";
      List<String> allUrls = [];
      
      for (var item in items) {
        String n = clean(item['notes'] ?? '');
        if (n.isNotEmpty) {
          if (combinedNotes.isNotEmpty && !combinedNotes.contains(n)) {
            combinedNotes += "\n\n$n";
          } else if (combinedNotes.isEmpty) {
            combinedNotes = n;
          }
        }
        
        if (item['image_url'] != null && item['image_url'].toString().isNotEmpty && item['image_url'].toString() != 'null') {
          final List<String> urls = item['image_url'].toString().split(',')
              .map((u) => u.trim())
              .where((u) => u.isNotEmpty && u != 'null' && u.toLowerCase().startsWith('http'))
              .toList();
          allUrls.addAll(urls);
        }
      }
      
      if (combinedNotes.isNotEmpty) {
        catSection.add(pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text("        $combinedNotes", textAlign: pw.TextAlign.justify, style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 1.15))));
      }
      
      if (allUrls.isNotEmpty) {
        final List<String> distinctUrls = allUrls.toSet().take(3).toList();
        final List<pw.MemoryImage?> downloadedImages = await Future.wait(distinctUrls.map((u) => _getImg(u)));
        
        final List<pw.Widget> imgs = [];
        for (var img in downloadedImages) {
          if (img != null) {
            final double aspect = (img.width ?? 1).toDouble() / (img.height ?? 1).toDouble();
            final double w = aspect < 1.0 ? 85 : 150;
            imgs.add(pw.Container(width: w, height: 100, child: pw.ClipRRect(horizontalRadius: 2, verticalRadius: 2, child: pw.Image(img, fit: pw.BoxFit.cover))));
          }
        }
        if (imgs.isNotEmpty) {
          catSection.add(pw.Padding(padding: const pw.EdgeInsets.only(top: 10, bottom: 20), child: pw.Wrap(spacing: 10, runSpacing: 10, children: imgs)));
        }
      }

      mainWidgets.add(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start, 
        children: catSection,
      ));
    }

    // --- Tabel Materi & Unggulan tetap sama ---
    final qM = getMaterial("Qiro'ati", "Target Semester ${semester == 1 ? 'I' : 'II'}\n- Jilid Pra ${student['class']}");
    final iM = getMaterial("Ibadah", "- Doa Setelah Adzan\n- Doa Sesudah Wudhu\n- Niat Sholat Dhuha\n- Takbiratul Ikhram\n- Iftitah\n- Ruku\n- I'tidal");
    final aM = getMaterial("Pendidikan Aqidah", "- Kalimat Thoyyibah\n- Rukun iman\n- Tugas-tugas Malaikat\n- Asmaul Husna");
    final bM = getMaterial("Bahasa Arab", "- Anggota Tubuh Manusia\n- Jarak\n- Ukuran\n- Waktu\n- Pekerjaan\n- Warna");
    final alM = getMaterial("Al-Qur'an", "- Qs. An-Naba\n- Qs. Al-Fatihah\n- Qs. Al-Kautsar");
    final doM = getMaterial("Do'a-Do'a", "- Doa Kedua Orang Tua\n- Doa Kebaikan Dunia Akhirat\n- Doa Sebelum Tidur\n- Doa Bangun Tidur\n- Doa Sebelum Makan\n- Doa Sesudah Makan\n- Doa Masuk Kamar Mandi\n- Doa Keluar Kamar Mandi\n- Doa Ketika Turun Hujan\n- Doa Setelah Turun Hujan\n- Doa Dipagi Hari\n- Doa Disore Hari\n- Doa Ketika Bercermin");
    final hdM = getMaterial("Hadits-Hadits", "- Hadits Jangan Marah\n- Hadits Kasih Sayang\n- Hadits Adab Makan\n- Hadits Bersaudara\n- Hadits Tersenyum\n- Hadits Suka Memberi");

    mainWidgets.add(pw.SizedBox(height: 20));
    mainWidgets.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5), 
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle, 
        columnWidths: {0: const pw.FixedColumnWidth(30), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(3)}, 
        children: [
      pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.orange100), children: [
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: mosqueImg != null ? pw.Center(child: pw.Image(mosqueImg, width: 20, height: 20)) : pw.Center(child: pw.Text("No", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))),
        _p("PROGRAM UNGGULAN & MATERI", isBold: true),
        _p("CAPAIAN / NARASI", isBold: true)
      ]),
      _tRow("1", "Qiroati", qM, _getD(grouped, "Qiro'ati", qM)),
      _tRow("2", "Ibadah", iM, _getD(grouped, "Ibadah", iM)),
      _tRow("3", "Pendidikan Aqidah", aM, _getD(grouped, "Pendidikan Aqidah", aM)),
      _tRow("4", "Bahasa Arab", bM, _getD(grouped, "Bahasa Arab", bM)),
      pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.orange100), children: [
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: quranImg != null ? pw.Center(child: pw.Image(quranImg, width: 20, height: 20)) : pw.Text("")),
        _p("TAHFIDZ", isBold: true, center: true),
        _p("CATATAN PERKEMBANGAN", isBold: true, center: true)
      ]),
      _tRow("1", "Al-Qur'an", alM, _getD(grouped, "Al-Qur'an", alM)),
      _tRow("2", "Do'a-Do'a", doM, _getD(grouped, "Do'a-Do'a", doM)),
      _tRow("3", "Hadits-Hadits", hdM, _getD(grouped, "Hadits-Hadits", hdM)),
    ]));

    mainWidgets.add(pw.SizedBox(height: 30));
    final List<pw.Widget> refleksiContent = [];
    refleksiContent.add(_catHeader("REFLEKSI ORANG TUA", familyImg));
    refleksiContent.add(pw.SizedBox(height: 15));
    
    final refleksiItems = _findItems(grouped, "Refleksi Orang Tua");
    if (refleksiItems.isNotEmpty && refleksiItems.first['notes'] != null && refleksiItems.first['notes'].toString().isNotEmpty) {
      refleksiContent.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10),
        child: pw.Text("        ${clean(refleksiItems.first['notes'])}", textAlign: pw.TextAlign.justify, style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 1.15)),
      ));
    } else {
      refleksiContent.add(pw.Column(children: List.generate(3, (i) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 20), child: pw.Row(children: [pw.Expanded(child: pw.Container(height: 1, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(style: pw.BorderStyle.dotted, width: 1.2)))))])))));
    }
    mainWidgets.add(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: refleksiContent));
    
    mainWidgets.add(pw.SizedBox(height: 20));
    final List<pw.Widget> pertumbuhanContent = [];
    pertumbuhanContent.add(_catHeader("PERTUMBUHAN DAN KEHADIRAN ANAK", childrenImg));
    pertumbuhanContent.add(pw.SizedBox(height: 10));
    pertumbuhanContent.add(pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Expanded(child: pw.Table(border: pw.TableBorder.all(), children: [
        _gRow("Berat Badan", "${getScore("Berat Badan")} kg"),
        _gRow("Tinggi Badan", "${getScore("Tinggi Badan")} cm"),
        _gRow("Lingkar Kepala", "${getScore("Lingkar Kepala")} cm"),
      ])),
      pw.SizedBox(width: 15),
      pw.Expanded(child: pw.Table(border: pw.TableBorder.all(), children: [
        _gRow("Hadir", getScore("Hadir")),
        _gRow("Sakit", getScore("Sakit")), 
        _gRow("Izin", getScore("Izin")), 
        _gRow("Tanpa Keterangan", getScore("Tanpa Keterangan")),
      ])),
    ]));
    mainWidgets.add(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: pertumbuhanContent));

    mainWidgets.add(pw.SizedBox(height: 40));
    mainWidgets.add(pw.Table(children: [pw.TableRow(children: [pw.Column(children: [
      pw.Table(children: [
        pw.TableRow(children: [pw.SizedBox(), pw.Center(child: pw.Text("Cirebon, $reportDate", style: const pw.TextStyle(fontSize: 10)))]),
        pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Center(child: pw.Text("Orang Tua/Wali", style: const pw.TextStyle(fontSize: 10)))), pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Center(child: pw.Text("Guru Kelas ${student['class']}", style: const pw.TextStyle(fontSize: 10))))]),
        pw.TableRow(children: [pw.SizedBox(height: 55), pw.SizedBox(height: 55)]),
        pw.TableRow(children: [pw.Center(child: pw.Text("...................................", style: const pw.TextStyle(fontSize: 10))), pw.Center(child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [pw.Text(student['teacher_name'] ?? "..................", style: const pw.TextStyle(fontSize: 9)), pw.SizedBox(width: 20), pw.Text(student['teacher_name_2'] ?? "..................", style: const pw.TextStyle(fontSize: 9))]))]),
      ]),
      pw.SizedBox(height: 30),
      pw.Center(child: pw.Column(children: [
        pw.Text("Mengetahui,", style: const pw.TextStyle(fontSize: 11)),
        pw.Text("Kepala TKIT AL-HANIF LEDENG", style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 50),
        pw.Text(school['headmaster_name'] ?? "SITI AISYAH S.Pd AUD", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
        pw.Text("Nuptk. ${school['headmaster_nip'] ?? '-'}", style: const pw.TextStyle(fontSize: 10)),
      ])),
    ])])]));

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4, 
      margin: const pw.EdgeInsets.all(35), 
      build: (c) => mainWidgets,
    ));
  }

  static pw.Widget _coverRow(String l, String v) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Row(children: [pw.SizedBox(width: 100, child: pw.Text(l, style: const pw.TextStyle(fontSize: 11))), pw.Text(v, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))]));
  static pw.Widget _idRow(String l, String v, {bool isBold = false}) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2.5), child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.SizedBox(width: 170, child: pw.Text(l, style: pw.TextStyle(fontSize: 11, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, lineSpacing: 1.15))), pw.Expanded(child: pw.Text(v, style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.15)))]));
  static pw.Widget _box(String l, dynamic v) => pw.Row(children: [pw.SizedBox(width: 55, child: pw.Text(l, style: const pw.TextStyle(fontSize: 10))), pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(3), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Text(v?.toString() ?? "-", style: const pw.TextStyle(fontSize: 10))))]);
  static pw.Widget _catHeader(String t, [pw.MemoryImage? icon]) => pw.Container(width: double.infinity, padding: const pw.EdgeInsets.all(6), margin: const pw.EdgeInsets.symmetric(vertical: 8), decoration: const pw.BoxDecoration(color: PdfColors.orange100, borderRadius: pw.BorderRadius.all(pw.Radius.circular(10))), child: pw.Row(children: [if (icon != null) ...[pw.Image(icon, width: 22, height: 22), pw.SizedBox(width: 10)], pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5))]));
  static pw.Widget _p(String t, {bool isBold = false, bool center = false}) {
    final text = pw.Text(t, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 10));
    return pw.Padding(padding: const pw.EdgeInsets.all(5), child: center ? pw.Center(child: text) : text);
  }
  static pw.TableRow _tRow(String n, String t, String m, String v) => pw.TableRow(children: [
    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Center(child: pw.Text(n, style: const pw.TextStyle(fontSize: 10)))),
    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.SizedBox(height: 2), pw.Text(m, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700, lineSpacing: 1.2))])),
    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(v, textAlign: pw.TextAlign.justify, style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.3))),
  ]);
  static pw.TableRow _gRow(String l, String v) => pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(l, style: const pw.TextStyle(fontSize: 10))), pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text(v, style: const pw.TextStyle(fontSize: 10))))]);
  static String _getD(Map<String, List<dynamic>> g, String c, [String? m]) {
    String notes = groupedItem(g, c);
    if (notes.isEmpty) return "";
    String cleanCat = c.trim().toLowerCase();
    if (notes.toLowerCase().startsWith(cleanCat)) {
      notes = notes.substring(c.length).trim();
      if (notes.startsWith(':')) notes = notes.substring(1).trim();
    }
    if (m != null) {
      List<String> points = m.split('\n').map((l) => l.replaceAll(RegExp(r'^[•\-*\s]+'), '').trim()).where((l) => l.isNotEmpty).toList();
      for (var p in points) {
        final escapedP = RegExp.escape(p);
        final regex = RegExp('^[\\s\\n•\\-\\u2022*.]*$escapedP[\\s\\n\\-:]*', caseSensitive: false, multiLine: true);
        notes = notes.replaceAll(regex, '');
      }
    }
    return notes.trim();
  }
  static String groupedItem(Map<String, List<dynamic>> g, String c) {
    final items = _findItems(g, c);
    return items.isEmpty ? "" : clean(items.first['notes'] ?? "");
  }
  static String _formatDate(dynamic d) {
    if (d == null || d == "" || d == "-" || d == "null") return "";
    try {
      final dt = DateTime.parse(d.toString());
      const months = ["", "Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"];
      return "${dt.day.toString().padLeft(2, '0')} ${months[dt.month]} ${dt.year}";
    } catch (_) { return d.toString(); }
  }
  static String _calcAge(dynamic d, DateTime ref) {
    if (d == null || d == "-" || d == "") return "-";
    try {
      final birth = DateTime.parse(d.toString());
      int years = ref.year - birth.year;
      int months = ref.month - birth.month;
      if (ref.day < birth.day) months--;
      if (months < 0) { years--; months += 12; }
      if (years <= 0) return "$months Bulan";
      return months > 0 ? "$years Tahun $months Bulan" : "$years Tahun";
    } catch (_) { return "-"; }
  }
}
