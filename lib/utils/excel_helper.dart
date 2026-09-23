import 'dart:io';
import 'package:excel_community/excel_community.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import 'package:printing/printing.dart';

class ExcelHelper {
  static final List<String> studentHeaders = [
    'NIS',
    'Nama Lengkap',
    'Jenis Kelamin (L/P)',
    'Angkatan (Contoh: 2024/2025)',
    'Kelas (TK A / TK B)',
    'Rombel (1/2/3/4)',
    'Status (Aktif/Lulus/Pindah/Keluar)',
    'Tempat Lahir',
    'Tanggal Lahir (YYYY-MM-DD)',
    'Agama',
    'Anak Ke-',
    'Alamat Siswa',
    'RT',
    'RW',
    'Desa/Kelurahan',
    'Nama Ayah',
    'Pekerjaan Ayah',
    'Nama Ibu',
    'Pekerjaan Ibu',
    'No. HP Orang Tua',
    'Alamat Orang Tua',
    'Kecamatan Orang Tua',
    'Kabupaten/Kota Orang Tua',
    'Provinsi Orang Tua',
    'Asal Sekolah'
  ];

  static final List<String> teacherHeaders = [
    'NIP/NUPTK',
    'NIK',
    'Nama Lengkap',
    'Jenis Kelamin (L/P)',
    'Tempat Lahir',
    'Tanggal Lahir (YYYY-MM-DD)',
    'Agama',
    'Pendidikan Terakhir',
    'Jurusan',
    'Universitas',
    'Jabatan',
    'Mata Pelajaran',
    'No. Telepon',
    'Email',
    'Alamat',
    'Wali Kelas (Nama Kelas)',
    'Rombel Wali (1/2/3/dst)',
    'Angkatan Wali (Contoh: 2024/2025)',
    'Status'
  ];

  static Future<void> downloadStudentTemplate() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    // Add Headers
    for (var i = 0; i < studentHeaders.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(studentHeaders[i]);
    }

    // Add Sample Data
    List<String> sampleData = [
      '2024001',
      'Ahmad Zaki',
      'L',
      '2024/2025',
      'TK A',
      '1',
      'Aktif',
      'Bandung',
      '2018-05-20',
      'Islam',
      '1',
      'Jl. Merdeka No. 123',
      '001',
      '002',
      'Ledeng',
      'Budi',
      'Wiraswasta',
      'Siti',
      'Ibu Rumah Tangga',
      '081234567890',
      'Jl. Merdeka No. 123',
      'Ledeng',
      'Kota Cirebon',
      'Jawa Barat',
      'TK Bintang Kecil'
    ];

    for (var i = 0; i < sampleData.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = TextCellValue(sampleData[i]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      Uint8List bytes = Uint8List.fromList(fileBytes);
      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: 'template_siswa.xlsx');
      } else {
        String? outputPath = await FilePicker.saveFile(
          dialogTitle: 'Simpan Template Siswa',
          fileName: 'template_siswa.xlsx',
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );

        if (outputPath != null) {
          if (!outputPath.toLowerCase().endsWith('.xlsx')) {
            outputPath += '.xlsx';
          }
          final file = File(outputPath);
          await file.writeAsBytes(bytes);
        }
      }
    }
  }

  static Future<void> downloadTeacherTemplate() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    for (var i = 0; i < teacherHeaders.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(teacherHeaders[i]);
    }

    List<String> sampleData = [
      '199001012023011001',
      '3201234567890001',
      'Budi Santoso',
      'L',
      'Jakarta',
      '1990-01-01',
      'Islam',
      'S2',
      'Pendidikan Matematika',
      'Universitas Pendidikan Indonesia',
      'Guru Kelas',
      'Matematika',
      '081234567891',
      'budi@example.com',
      'Jl. Pahlawan No. 10',
      'TK A',
      '1',
      '2024/2025',
      'Aktif'
    ];

    for (var i = 0; i < sampleData.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = TextCellValue(sampleData[i]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      Uint8List bytes = Uint8List.fromList(fileBytes);
      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: 'template_guru.xlsx');
      } else {
        String? outputPath = await FilePicker.saveFile(
          dialogTitle: 'Simpan Template Guru',
          fileName: 'template_guru.xlsx',
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );

        if (outputPath != null) {
          if (!outputPath.toLowerCase().endsWith('.xlsx')) {
            outputPath += '.xlsx';
          }
          final file = File(outputPath);
          await file.writeAsBytes(bytes);
        }
      }
    }
  }

  static Future<int> importStudentsFromExcel() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result == null) return 0;

    Uint8List? bytes;
    if (kIsWeb) {
      bytes = result.files.first.bytes;
    } else {
      bytes = await File(result.files.first.path!).readAsBytes();
    }

    if (bytes == null) return 0;

    var excel = Excel.decodeBytes(bytes);
    var sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) return 0;

    List<Map<String, dynamic>> students = [];

    // Skip header (row 0)
    for (var i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      if (row.isEmpty || row[1]?.value == null) continue; // Skip empty rows

      String val(int col) => row[col]?.value?.toString() ?? '';

      students.add({
        'nis': val(0),
        'name': val(1),
        'gender': val(2),
        'batch': val(3),
        'class': val(4),
        'rombel': val(5),
        'status': val(6),
        'birth_place': val(7),
        'birth_date': val(8),
        'religion': val(9),
        'child_number': int.tryParse(val(10)) ?? 1,
        'address': val(11),
        'rt': val(12),
        'rw': val(13),
        'village': val(14),
        'father_name': val(15),
        'father_job': val(16),
        'mother_name': val(17),
        'mother_job': val(18),
        'parent_phone': val(19),
        'parent_address': val(20),
        'parent_district': val(21),
        'parent_city': val(22),
        'parent_province': val(23),
        'school_of_origin': val(24),
      });
    }

    if (students.isEmpty) return 0;

    final apiService = ApiService();
    // Assuming backend endpoint /students supports bulk insert (array payload)
    await apiService.insert('students', students);
    
    return students.length;
  }

  static Future<int> importTeachersFromExcel() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result == null) return 0;

    Uint8List? bytes;
    if (kIsWeb) {
      bytes = result.files.first.bytes;
    } else {
      bytes = await File(result.files.first.path!).readAsBytes();
    }

    if (bytes == null) return 0;

    var excel = Excel.decodeBytes(bytes);
    var sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) return 0;

    List<Map<String, dynamic>> teachers = [];

    for (var i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      if (row.isEmpty || row[2]?.value == null) continue;

      String val(int col) => row[col]?.value?.toString() ?? '';

      teachers.add({
        'nip': val(0),
        'nik': val(1),
        'name': val(2),
        'gender': val(3).toLowerCase().startsWith('l') ? 'L' : 'P',
        'birth_place': val(4),
        'birth_date': val(5),
        'religion': val(6),
        'last_education': val(7),
        'major': val(8),
        'university': val(9),
        'role': val(10),
        'subject': val(11),
        'phone': val(12),
        'email': val(13),
        'address': val(14),
        'wali_kelas': val(15),
        'rombel_wali': val(16),
        'angkatan_wali': val(17),
        'status': val(18).isEmpty ? 'Aktif' : val(18),
      });
    }

    if (teachers.isEmpty) return 0;

    final apiService = ApiService();
    // Assuming backend endpoint /teachers supports bulk insert (array payload)
    await apiService.insert('teachers', teachers);
    
    return teachers.length;
  }
}
