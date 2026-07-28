import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:laporsekolaherapor/config/app_colors.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:async';
import '../utils/notification_helper.dart';

class AbsensiPage extends StatefulWidget {
  final String? studentNis;
  final String? studentClass;
  final String? userRole;
  const AbsensiPage({super.key, this.studentNis, this.studentClass, this.userRole});

  @override
  State<AbsensiPage> createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;
  StreamSubscription? _attendanceSubscription;
  StreamSubscription? _studentsSubscription;
  StreamSubscription? _teachersSubscription;
  StreamSubscription? _schoolSubscription;

  // Modern Color Palette
  final Color primaryTeal = AppColors.primary;
  final Color bgColor = AppColors.backgroundColor;
  final Color colorHadir = const Color(0xFF10B981);
  final Color colorIzin = const Color(0xFFF59E0B);
  final Color colorSakit = const Color(0xFF3B82F6);
  final Color colorAlfa = const Color(0xFFEF4444);

  final Color textDark = AppColors.textDark;
  final Color textSecondary = AppColors.textSecondary;
  final Color textMuted = AppColors.textMuted;

  // State
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  
  // Filter state
  final TextEditingController _searchController = TextEditingController();
  String _selectedBatch = 'Angkatan';
  String _selectedClass = 'Kelas';
  String _selectedRombel = 'Rombel';
  
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _riwayatData = [];
  List<Map<String, dynamic>> _monitoringData = [];
  List<Map<String, dynamic>> _rawFilterData = [];
  Map<String, dynamic>? _schoolData;
  List<Map<String, dynamic>> _teachersList = [];
  bool _isFetchingRiwayat = false;
  bool _isFetchingMonitoring = false;
  int _monitoringMonth = DateTime.now().month;
  int _monitoringYear = DateTime.now().year;
  String _exportType = "Bulanan";

  bool get _isMobile => MediaQuery.of(context).size.width < 600;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      // Hanya refresh data jika animasi geser tab sudah SELESAI
      // Ini membuat transisi antar tab jauh lebih mulus (semoth)
      if (!_tabController.indexIsChanging) {
        _refreshAllData(showLoading: false);
      }
      setState(() {});
    });
    _searchController.addListener(_applySearch);
    _loadInitialData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    _studentsSubscription?.cancel();
    _teachersSubscription?.cancel();
    _schoolSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupRealtime() {
    // 1. Attendance Realtime
    _attendanceSubscription = supabase
        .from('attendance')
        .stream(primaryKey: ['student_id', 'date'])
        .listen((_) => _refreshAllData(showLoading: false));

    // 2. Students Realtime (for filters and lists)
    _studentsSubscription = supabase
        .from('students')
        .stream(primaryKey: ['id'])
        .listen((data) {
      if (mounted) {
        final List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(data)
            .where((s) => s['status']?.toString().toLowerCase() != 'lulus')
            .toList();

        setState(() {
          _rawFilterData = rawData;
        });
        _refreshAllData(showLoading: false);
      }
    });

    // 3. Teachers Realtime (for PDF Signatures)
    _teachersSubscription = supabase
        .from('teachers')
        .stream(primaryKey: ['id'])
        .listen((data) {
      if (mounted) {
        setState(() {
          _teachersList = List<Map<String, dynamic>>.from(data);
        });
      }
    });

    // 4. School Data Realtime (for PDF Signatures)
    _schoolSubscription = supabase
        .from('school_data')
        .stream(primaryKey: ['id'])
        .listen((data) {
      if (mounted) {
        setState(() {
          if (data.isNotEmpty) {
            _schoolData = data.first;
          }
        });
      }
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final filterData = await supabase.from('students').select('batch, class, rombel, status');
      final schoolRes = await supabase.from('school_data').select().limit(1).maybeSingle();
      final teachersRes = await supabase.from('teachers').select('name, nip, wali_kelas, angkatan_wali, rombel_wali');

      if (mounted) {
        final List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(filterData as List)
            .where((s) => s['status']?.toString().toLowerCase() != 'lulus')
            .toList();

        setState(() {
          _rawFilterData = rawData;
          _schoolData = schoolRes;
          _teachersList = List<Map<String, dynamic>>.from(teachersRes as List);
          
          // Reset filters to "Semua" on initial load as requested
          _selectedBatch = 'Angkatan';
          _selectedClass = 'Kelas';
          _selectedRombel = 'Rombel';
        });
        await _refreshAllData(showLoading: false);
      }
    } catch (e) {
      if (mounted) NotificationHelper.show(context, 'Gagal memuat data awal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAllData({bool showLoading = false}) async {
    await Future.wait([
      _fetchStudents(showLoading: showLoading),
      _fetchRiwayat(showLoading: showLoading),
      _fetchMonitoring(showLoading: showLoading),
    ]);
  }

  Future<void> _fetchStudents({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      var query = supabase.from('students').select('id, name, nis, class, rombel, status');
      
      if (_selectedBatch != 'Angkatan') query = query.eq('batch', _selectedBatch);
      if (_selectedClass != 'Kelas') query = query.eq('class', _selectedClass);
      if (_selectedRombel != 'Rombel') query = query.eq('rombel', _selectedRombel);

      final studentData = await query.order('name');
      final String dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      
      final attendanceData = await supabase
          .from('attendance')
          .select('student_id, status')
          .eq('date', dateStr);

      final List<Map<String, dynamic>> studentsWithAttendance = [];
      for (var student in (studentData as List)) {
        if (student['status']?.toString().toLowerCase() == 'lulus') continue;

        final att = (attendanceData as List)
            .where((a) => a['student_id'] == student['id'])
            .firstOrNull;

        studentsWithAttendance.add({
          'id': student['id'],
          'name': student['name'],
          'nis': student['nis'],
          'class': student['class'],
          'rombel': student['rombel'],
          'status': att?['status'] ?? 'Alfa', // Default harus Alfa, bukan Hadir
        });
      }

      if (mounted) {
        setState(() {
          _allStudents = studentsWithAttendance;
          _applySearch();
        });
      }
    } catch (e) {
      if (mounted) NotificationHelper.show(context, 'Gagal memuat data siswa: $e', isError: true);
    } finally {
      if (mounted && showLoading) setState(() => _isLoading = false);
    }
  }

  void _applySearch() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      if (query.isEmpty) {
        _filteredStudents = List.from(_allStudents);
      } else {
        _filteredStudents = _allStudents
            .where((s) => s['name'].toString().toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _saveAttendance() async {
    if (_allStudents.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final String dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      
      final List<Map<String, dynamic>> records = _allStudents.map((s) => {
        'student_id': s['id'],
        'date': dateStr,
        'status': s['status'],
      }).toList();

      await supabase.from('attendance').upsert(records, onConflict: 'student_id, date');

      if (mounted) {
        NotificationHelper.show(context, 'Berhasil menyimpan absensi hari ini');
        _refreshAllData();
      }
    } catch (e) {
      if (mounted) NotificationHelper.show(context, 'Gagal menyimpan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateStatus(int index, String newStatus) {
    setState(() {
      _filteredStudents[index]['status'] = newStatus;
      final dynamic id = _filteredStudents[index]['id'];
      final int allIdx = _allStudents.indexWhere((s) => s['id'] == id);
      if (allIdx != -1) _allStudents[allIdx]['status'] = newStatus;
    });
  }

  Future<void> _fetchRiwayat({bool showLoading = true}) async {
    if (showLoading) setState(() => _isFetchingRiwayat = true);
    try {
      final attendanceData = await supabase
          .from('attendance')
          .select('date, status, student_id, students(name, class, rombel, batch)')
          .order('date', ascending: false);

      final Map<String, Map<String, dynamic>> dateGrouped = {};
      
      for (var item in (attendanceData as List)) {
        final date = item['date'].toString().split('T')[0].split(' ')[0];
        if (!dateGrouped.containsKey(date)) {
          dateGrouped[date] = {
            'date': date,
            'hadir': 0,
            'izin': 0,
            'sakit': 0,
            'alfa': 0,
            'classes': <String, Map<String, dynamic>>{}, // Nested grouping by class key
          };
        }

        final student = item['students'];
        final status = item['status'].toString();
        
        // Stats at date level
        if (status == 'Hadir') {
          dateGrouped[date]!['hadir']++;
        } else if (status == 'Izin') {
          dateGrouped[date]!['izin']++;
        } else if (status == 'Sakit') {
          dateGrouped[date]!['sakit']++;
        } else if (status == 'Alfa') {
          dateGrouped[date]!['alfa']++;
        }

        // Inner Grouping: Class Key (Class + Rombel + Batch)
        final String className = student['class'] ?? '-';
        final String rombelName = student['rombel'] ?? '-';
        final String batchName = student['batch'] ?? '-';
        final String classKey = "$className|$rombelName|$batchName";

        final Map<String, dynamic> classesMap = dateGrouped[date]!['classes'];
        if (!classesMap.containsKey(classKey)) {
          classesMap[classKey] = {
            'className': className,
            'rombelName': rombelName,
            'batchName': batchName,
            'hadir': 0,
            'izin': 0,
            'sakit': 0,
            'alfa': 0,
            'students': [],
          };
        }

        final group = classesMap[classKey]!;
        if (status == 'Hadir') {
          group['hadir']++;
        } else if (status == 'Izin') {
          group['izin']++;
        } else if (status == 'Sakit') {
          group['sakit']++;
        } else if (status == 'Alfa') {
          group['alfa']++;
        }

        group['students'].add({
          'name': student['name'],
          'status': status,
        });
      }

      if (mounted) {
        setState(() {
          _riwayatData = dateGrouped.values.toList();
          _isFetchingRiwayat = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingRiwayat = false);
        NotificationHelper.show(context, 'Gagal memuat riwayat: $e', isError: true);
      }
    }
  }

  Future<void> _fetchMonitoring({VoidCallback? onComplete, bool showLoading = true}) async {
    if (showLoading) setState(() => _isFetchingMonitoring = true);
    try {
      var studentQuery = supabase.from('students').select('id, name, batch, class, rombel, status');
      if (_selectedBatch != 'Angkatan') studentQuery = studentQuery.eq('batch', _selectedBatch);
      if (_selectedClass != 'Kelas') studentQuery = studentQuery.eq('class', _selectedClass);
      if (_selectedRombel != 'Rombel') studentQuery = studentQuery.eq('rombel', _selectedRombel);
      
      final studentRes = await studentQuery;
      final List<Map<String, dynamic>> students = List<Map<String, dynamic>>.from(studentRes as List)
          .where((s) => s['status']?.toString().toLowerCase() != 'lulus')
          .toList();
      final List<dynamic> studentIds = students.map((s) => s['id']).toList();

      if (studentIds.isEmpty) {
        setState(() {
          _monitoringData = [];
          _isFetchingMonitoring = false;
        });
        return;
      }

      DateTime firstDay;
      DateTime lastDay;

      if (_exportType == "Semester 1") {
        firstDay = DateTime(_monitoringYear, 7, 1);
        lastDay = DateTime(_monitoringYear, 12, 31);
      } else if (_exportType == "Semester 2") {
        firstDay = DateTime(_monitoringYear, 1, 1);
        lastDay = DateTime(_monitoringYear, 6, 30);
      } else if (_exportType == "Harian") {
        firstDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        lastDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      } else {
        // Default: Bulanan
        firstDay = DateTime(_monitoringYear, _monitoringMonth, 1);
        lastDay = DateTime(_monitoringYear, _monitoringMonth + 1, 0);
      }

      final String startStr = "${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-${firstDay.day.toString().padLeft(2, '0')}";
      final String endStr = "${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}";

      final attendanceData = await supabase
          .from('attendance')
          .select('status, student_id, date')
          .inFilter('student_id', studentIds)
          .gte('date', startStr)
          .lte('date', endStr);

      final List<Map<String, dynamic>> rekap = [];
      for (var student in students) {
        final List studentAtt = (attendanceData as List).where((a) => a['student_id'] == student['id']).toList();
        
        final Map<int, String> daily = {};
        for (var att in studentAtt) {
          // Robust date parsing: ambil YYYY-MM-DD saja untuk menghindari pergeseran timezone
          final String dateOnly = att['date'].toString().split('T')[0].split(' ')[0];
          final dt = DateTime.parse(dateOnly);
          daily[dt.day] = att['status'];
        }

        rekap.add({
          'name': student['name'],
          'batch': student['batch'],
          'class': student['class'],
          'rombel': student['rombel'],
          'hadir': studentAtt.where((a) => a['status'] == 'Hadir').length,
          'izin': studentAtt.where((a) => a['status'] == 'Izin').length,
          'sakit': studentAtt.where((a) => a['status'] == 'Sakit').length,
          'alfa': studentAtt.where((a) => a['status'] == 'Alfa').length,
          'daily': daily,
        });
      }

      rekap.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

      if (mounted) {
        setState(() {
          _monitoringData = rekap;
          _isFetchingMonitoring = false;
        });
        if (onComplete != null) onComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingMonitoring = false);
        if (onComplete != null) onComplete();
        NotificationHelper.show(context, 'Gagal memuat monitoring: $e', isError: true);
      }
    }
  }

  Future<void> _generatePDF() async {
    if (_monitoringData.isEmpty) {
      NotificationHelper.show(context, 'Tidak ada data untuk diexport.', isWarning: true);
      return;
    }

    try {
      final pdf = pw.Document();
      final months = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
      final monthName = months[_monitoringMonth - 1];
      final daysInMonth = DateTime(_monitoringYear, _monitoringMonth + 1, 0).day;
      final now = DateTime.now();
      final timestamp = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      // Grouping data by Class for multiple tables
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var s in _monitoringData) {
        final key = "KELAS ${s['class'] ?? '-'} ${s['rombel'] ?? '-'}";
        if (!grouped.containsKey(key)) grouped[key] = [];
        grouped[key]!.add(s);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            String titleSuffix = "";
            if (_exportType == "Harian") {
              titleSuffix = "HARIAN - ${_formatDate(_selectedDate.toString())}";
            } else if (_exportType == "Semester 1") {
              titleSuffix = "SEMESTER 1 (GANJIL) - $_monitoringYear";
            } else if (_exportType == "Semester 2") {
              titleSuffix = "SEMESTER 2 (GENAP) - $_monitoringYear";
            } else {
              titleSuffix = "BULAN $monthName $_monitoringYear";
            }

            return [
              // HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('LAPORAN REKAPITULASI ABSENSI SISWA', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 4),
                      pw.Row(children: [
                        pw.Text('$titleSuffix  |  ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text('ANGKATAN: $_selectedBatch  |  ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                        pw.Text('KELAS: $_selectedClass  |  ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal700)),
                        pw.Text('ROMBEL: $_selectedRombel', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700)),
                      ]),
                    ],
                  ),
                  pw.Text(timestamp, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.blue900),
              pw.SizedBox(height: 15),

              for (var entry in grouped.entries) ...[
                // SUBHEADER PER KELAS
                pw.Text('${entry.key} - Angkatan: $_selectedBatch', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                
                if (_exportType == "Bulanan") ...[
                  // TABEL HARIAN (1-31)
                  pw.TableHelper.fromTextArray(
                    headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                    cellStyle: const pw.TextStyle(fontSize: 7),
                    columnWidths: {0: const pw.FixedColumnWidth(100)},
                    headers: [
                      'Nama Siswa',
                      ...List.generate(daysInMonth, (i) {
                        final day = i + 1;
                        final date = DateTime(_monitoringYear, _monitoringMonth, day);
                        final isSunday = date.weekday == DateTime.sunday;
                        return pw.Text('$day', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: isSunday ? PdfColors.red : PdfColors.black));
                      })
                    ],
                    headerCellDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    data: entry.value.map((s) {
                      return [
                        s['name'],
                        ...List.generate(daysInMonth, (i) {
                          final day = i + 1;
                          final date = DateTime(_monitoringYear, _monitoringMonth, day);
                          final isSunday = date.weekday == DateTime.sunday;
                          final status = s['daily'][day];
                          String label = '.';
                          if (status != null) {
                            switch (status) {
                              case 'Hadir': label = 'H'; break;
                              case 'Izin': label = 'I'; break;
                              case 'Sakit': label = 'S'; break;
                              case 'Alfa': label = 'A'; break;
                            }
                          }
                          return pw.Text(label, style: pw.TextStyle(fontSize: 7, color: isSunday ? PdfColors.red : PdfColors.black, fontWeight: isSunday ? pw.FontWeight.bold : pw.FontWeight.normal));
                        })
                      ];
                    }).toList(),
                  ),
                ],
                
                if (_exportType == "Bulanan" || _exportType.startsWith("Semester")) ...[
                  pw.SizedBox(height: 10),
                  // TABEL RINGKASAN TOTAL
                  pw.Text('RINGKASAN TOTAL ABSENSI - ${entry.key}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.SizedBox(height: 5),
                  pw.TableHelper.fromTextArray(
                    headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                    cellStyle: const pw.TextStyle(fontSize: 8),
                    headers: ['Nama Siswa', 'HADIR (H)', 'IZIN (I)', 'SAKIT (S)', 'ALFA (A)'],
                    data: entry.value.map((s) => [
                      s['name'],
                      s['hadir'].toString(),
                      s['izin'].toString(),
                      s['sakit'].toString(),
                      s['alfa'].toString(),
                    ]).toList(),
                  ),
                ],

                if (_exportType == "Harian") ...[
                  pw.TableHelper.fromTextArray(
                    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    headers: ['Nama Siswa', 'Status Kehadiran'],
                    data: entry.value.map((s) {
                      final status = s['daily'][_selectedDate.day] ?? "Tidak ada data";
                      return [s['name'], status];
                    }).toList(),
                  ),
                ],

                pw.SizedBox(height: 20),
                
                // SIGNATURES
                pw.Builder(builder: (pw.Context context) {
                  // Find Wali Kelas for this group (entry.key is "KELAS [class] [rombel]")
                  // The monitoring data 's' has batch, class, rombel.
                  final firstStudent = entry.value.first;
                  final currentBatch = firstStudent['batch']?.toString();
                  final currentClass = firstStudent['class']?.toString();
                  final currentRombel = firstStudent['rombel']?.toString();

                  final waliKelas = _teachersList.cast<Map<String, dynamic>?>().firstWhere(
                    (t) => t?['wali_kelas']?.toString() == currentClass && 
                           t?['rombel_wali']?.toString() == currentRombel &&
                           t?['angkatan_wali']?.toString() == currentBatch,
                    orElse: () => null,
                  );

                  final String headmasterName = _schoolData?['headmaster_name'] ?? '................................';
                  final String headmasterNip = _schoolData?['headmaster_nip'] ?? '................................';
                  final String teacherName = waliKelas?['name'] ?? '................................';
                  final String teacherNip = waliKelas?['nip'] ?? '................................';

                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text('Mengetahui,', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('Kepala Sekolah', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.SizedBox(height: 40),
                          pw.Text(headmasterName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Container(width: 140, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.8)))),
                          pw.SizedBox(height: 2),
                          pw.Text('NIP. $headmasterNip', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(_formatDate(now.toString()), style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('Wali Kelas', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.SizedBox(height: 40),
                          pw.Text(teacherName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Container(width: 140, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.8)))),
                          pw.SizedBox(height: 2),
                          pw.Text('NIP. $teacherNip', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                  );
                }),

                pw.SizedBox(height: 30),
              ],
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Laporan_Rekap_Absensi_$_exportType$_monitoringYear.pdf',
      );
    } catch (e) {
      if (mounted) NotificationHelper.show(context, 'Gagal membuat PDF: $e', isError: true);
    }
  }

  Future<void> _onScanQR(String code) async {
    final String scannedNis = code.trim();
    if (scannedNis.isEmpty) return;
    
    try {
      // 1. Cari langsung ke database berdasarkan NIS untuk akurasi 100%
      final studentData = await supabase
          .from('students')
          .select('id, name, nis, status')
          .eq('nis', scannedNis)
          .maybeSingle();
      
      if (studentData == null) {
        if (mounted) NotificationHelper.show(context, 'NIS $scannedNis tidak terdaftar.', isError: true);
        return;
      }

      if (studentData['status']?.toString().toLowerCase() == 'lulus') {
        if (mounted) NotificationHelper.show(context, 'Siswa ${studentData['name']} sudah lulus dan tidak aktif di absensi.', isError: true);
        return;
      }

      final String studentName = studentData['name'];
      final dynamic studentId = studentData['id'];

      // 2. Simpan ke database
      final now = DateTime.now();
      final String dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      await supabase.from('attendance').upsert({
        'student_id': studentId,
        'date': dateStr,
        'status': 'Hadir',
      }, onConflict: 'student_id, date');

      if (mounted) {
        NotificationHelper.show(context, 'BERHASIL: $studentName ($scannedNis) hadir');
        _refreshAllData(showLoading: false);
      }
    } catch (e) {
      if (mounted) NotificationHelper.show(context, 'Gagal proses QR: $e', isError: true);
    }
  }

  void _openScanner() {
    final MobileScannerController controller = MobileScannerController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Stack(
          children: [
            // 1. Scanner Layer
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      controller.dispose();
                      Navigator.pop(context);
                      _onScanQR(barcode.rawValue!);
                      break;
                    }
                  }
                },
              ),
            ),

            // 2. Custom Overlay Layer
            Positioned.fill(
              child: _ScannerOverlay(
                borderColor: primaryTeal,
                borderRadius: 24,
                borderLength: 30,
                borderWidth: 8,
              ),
            ),

            // 3. UI Controls (Top)
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Scan QR Code Siswa",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Posisikan QR di dalam kotak",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                  ),
                ],
              ),
            ),

            // 4. Scanning Line Animation
            const Center(
              child: _ScanningLine(),
            ),

            // 5. Camera Controls (Bottom)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _scannerActionBtn(
                    onTap: () => controller.toggleTorch(),
                    icon: Icons.flashlight_on_rounded,
                    label: "Flash",
                  ),
                  const SizedBox(width: 32),
                  _scannerActionBtn(
                    onTap: () => controller.switchCamera(),
                    icon: Icons.flip_camera_ios_rounded,
                    label: "Balik",
                  ),
                  const SizedBox(width: 32),
                  _scannerActionBtn(
                    onTap: () {
                      controller.dispose();
                      Navigator.pop(context);
                    },
                    icon: Icons.close_rounded,
                    label: "Tutup",
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }

  Widget _scannerActionBtn({required VoidCallback onTap, required IconData icon, required String label, bool isDestructive = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isDestructive ? Colors.red.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.15),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
              ),
              child: Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 70,
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Absensi Siswa', 
            style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1.0)
          ),
        ),
        centerTitle: false,
        actions: [
          Center(
            child: Material(
              color: primaryTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _fetchStudents();
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 16, color: primaryTeal),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(_selectedDate.toString()),
                        style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: primaryTeal,
              unselectedLabelColor: textMuted,
              indicatorColor: primaryTeal,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.2),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'Input Harian'),
                Tab(text: 'Riwayat'),
                Tab(text: 'Monitoring'),
                Tab(text: 'Rekap PDF'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_tabController.index == 0 || _tabController.index == 2) _buildFilters(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHarianTab(),
                _buildRiwayatTab(),
                _buildMonitoringTab(),
                _buildRekapTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _allStudents.isNotEmpty && _tabController.index == 0 ? _buildBottomSaveButton() : null,
    );
  }

  Widget _buildRiwayatTab() {
    if (_isFetchingRiwayat && _riwayatData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryTeal),
            const SizedBox(height: 16),
            Text("Memuat riwayat...", style: TextStyle(color: textMuted, fontSize: 13)),
          ],
        ),
      );
    }
    
    if (_riwayatData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text("Belum ada riwayat", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_isFetchingRiwayat)
          LinearProgressIndicator(
            backgroundColor: primaryTeal.withValues(alpha: 0.1),
            color: primaryTeal,
            minHeight: 2,
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _riwayatData.length,
            itemBuilder: (context, index) {
              final data = _riwayatData[index];
              final Map<String, dynamic> classesMap = data['classes'];
              final List<Map<String, dynamic>> classesList = classesMap.values.cast<Map<String, dynamic>>().toList();
              
              // Sort classes by name/rombel
              classesList.sort((a, b) {
                int cmp = a['className'].toString().compareTo(b['className'].toString());
                if (cmp != 0) return cmp;
                return a['rombelName'].toString().compareTo(b['rombelName'].toString());
              });

              int totalStudentsOnDate = 0;
              for (var c in classesList) {
                totalStudentsOnDate += (c['students'] as List).length;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    backgroundColor: Colors.white,
                    collapsedBackgroundColor: Colors.white,
                    iconColor: primaryTeal,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.calendar_today_rounded, color: primaryTeal, size: 20),
                    ),
                    title: Text(
                      _formatDate(data['date']),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                    ),
                    subtitle: Text(
                      "Hadir: ${data['hadir']} • Absen: ${totalStudentsOnDate - data['hadir']}",
                      style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () {
                                  _selectedDate = DateTime.parse(data['date']);
                                  _tabController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                                  _fetchStudents();
                                },
                                icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                                label: const Text("Edit Absensi Tanggal Ini", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryTeal,
                                  backgroundColor: primaryTeal.withValues(alpha: 0.05),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 0.5),
                      // --- Grouped by Class ---
                      ...classesList.map((classData) {
                        final List students = classData['students'];
                        students.sort((a, b) {
                          if (a['status'] == 'Hadir' && b['status'] != 'Hadir') return 1;
                          if (a['status'] != 'Hadir' && b['status'] == 'Hadir') return -1;
                          return a['name'].toString().compareTo(b['name'].toString());
                        });

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Class Header
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: bgColor.withValues(alpha: 0.5),
                              child: Row(
                                children: [
                                  Icon(Icons.groups_rounded, size: 14, color: textSecondary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "KELAS ${classData['className']} - ${classData['rombelName']} (${classData['batchName']})",
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textSecondary, letterSpacing: 0.5),
                                    ),
                                  ),
                                  Text(
                                    "H: ${classData['hadir']} I/S: ${classData['izin'] + classData['sakit']} A: ${classData['alfa']}",
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryTeal),
                                  ),
                                ],
                              ),
                            ),
                            // Student List for this class
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: students.map((s) {
                                  Color statusColor = colorHadir;
                                  if (s['status'] == 'Izin' || s['status'] == 'Sakit') statusColor = colorIzin;
                                  if (s['status'] == 'Alfa') statusColor = colorAlfa;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            s['name'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: s['status'] == 'Hadir' ? const Color(0xFF334155) : statusColor,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            s['status'].toUpperCase(),
                                            style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const Divider(height: 1, thickness: 0.5),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonitoringTab() {
    if (_isFetchingMonitoring) return const Center(child: CircularProgressIndicator());
    if (_monitoringData.isEmpty) return Center(child: Text("Tidak ada data", style: TextStyle(color: Colors.grey[400])));

    final daysInMonth = DateTime(_monitoringYear, _monitoringMonth + 1, 0).day;
    
    final query = _searchController.text.toLowerCase();
    final filteredMonitoring = _monitoringData.where((s) => s['name'].toString().toLowerCase().contains(query)).toList();

    // Grouping by Batch, Class & Rombel
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var s in filteredMonitoring) {
      final key = "Angkatan ${s['batch'] ?? '-'} - Kelas ${s['class'] ?? '-'} ${s['rombel'] ?? '-'}";
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(s);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return Column(
      children: [
        _buildMonthPicker(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Tabel ini terfilter berdasarkan 'Filter Kelompok' di atas.",
                  style: TextStyle(fontSize: 10, color: textMuted, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        _buildMonitoringLegend(),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedKeys.length,
            itemBuilder: (context, groupIdx) {
              final className = sortedKeys[groupIdx];
              final studentsInClass = grouped[className]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: primaryTeal.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.class_rounded, size: 18, color: primaryTeal),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(className, style: TextStyle(fontWeight: FontWeight.bold, color: primaryTeal, fontSize: 14)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: primaryTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                          child: Text("${studentsInClass.length} Siswa", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryTeal)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 12,
                      horizontalMargin: 8,
                      headingRowHeight: 45,
                      dataRowMinHeight: 45,
                      dataRowMaxHeight: 50,
                      headingRowColor: WidgetStateProperty.all(Colors.transparent),
                      columns: [
                        const DataColumn(label: SizedBox(width: 120, child: Text('Nama Siswa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))))),
                        ...List.generate(daysInMonth, (index) {
                          final day = index + 1;
                          final date = DateTime(_monitoringYear, _monitoringMonth, day);
                          final isSunday = date.weekday == DateTime.sunday;
                          return DataColumn(
                            label: Container(
                              alignment: Alignment.center,
                              width: 22,
                              child: Text('$day', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSunday ? Colors.red : const Color(0xFF64748B)))
                            )
                          );
                        }),
                        _rekapHeader("H", colorHadir),
                        _rekapHeader("I", colorIzin),
                        _rekapHeader("S", colorSakit),
                        _rekapHeader("A", colorAlfa),
                      ],
                      rows: studentsInClass.map((s) {
                        return DataRow(
                          cells: [
                            DataCell(SizedBox(width: 120, child: Text(s['name'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis))),
                            ...List.generate(daysInMonth, (index) {
                              final day = index + 1;
                              final date = DateTime(_monitoringYear, _monitoringMonth, day);
                              final isSunday = date.weekday == DateTime.sunday;
                              final status = s['daily'][day];
                              return DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  width: 22,
                                  decoration: isSunday ? BoxDecoration(color: Colors.red.withValues(alpha: 0.05)) : null,
                                  child: _statusSymbol(status, isSunday: isSunday),
                                )
                              );
                            }),
                            _rekapCell(s['hadir'].toString(), colorHadir),
                            _rekapCell(s['izin'].toString(), colorIzin),
                            _rekapCell(s['sakit'].toString(), colorSakit),
                            _rekapCell(s['alfa'].toString(), colorAlfa),
                          ]
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 40, thickness: 1, color: Color(0xFFF1F5F9)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  DataColumn _rekapHeader(String label, Color color) {
    return DataColumn(
      label: Container(
        alignment: Alignment.center,
        width: 22,
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color))
      )
    );
  }

  DataCell _rekapCell(String value, Color color) {
    return DataCell(
      Container(
        alignment: Alignment.center,
        width: 22,
        child: Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))
      )
    );
  }

  Widget _buildMonitoringLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem("Hadir", Icons.check_circle, colorHadir),
          const SizedBox(width: 12),
          _legendItem("Izin", null, colorIzin, text: "I"),
          const SizedBox(width: 12),
          _legendItem("Sakit", null, colorSakit, text: "S"),
          const SizedBox(width: 12),
          _legendItem("Alfa", null, colorAlfa, text: "A"),
        ],
      ),
    );
  }

  Widget _legendItem(String label, IconData? icon, Color color, {String? text}) {
    return Row(
      children: [
        icon != null 
          ? Icon(icon, size: 12, color: color)
          : Text(text!, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _statusSymbol(String? status, {bool isSunday = false}) {
    if (status == null) return Text(isSunday ? '' : '-', style: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 10));
    switch (status) {
      case 'Hadir': return Icon(Icons.check_circle_rounded, color: colorHadir, size: 16);
      case 'Izin': return Text('I', style: TextStyle(color: colorIzin, fontWeight: FontWeight.bold, fontSize: 12));
      case 'Sakit': return Text('S', style: TextStyle(color: colorSakit, fontWeight: FontWeight.bold, fontSize: 12));
      case 'Alfa': return Text('A', style: TextStyle(color: colorAlfa, fontWeight: FontWeight.bold, fontSize: 12));
      default: return Text(isSunday ? '' : '-', style: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 10));
    }
  }

  Widget _buildMonthPicker() {
    final months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _monitoringMonth,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryTeal, size: 20),
                  items: List.generate(12, (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 16, color: primaryTeal.withValues(alpha: 0.6)),
                        const SizedBox(width: 8),
                        Text(months[i], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )),
                  onChanged: (v) { if (v != null) setState(() => _monitoringMonth = v); _fetchMonitoring(); },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _monitoringYear,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryTeal, size: 20),
                  items: List.generate(5, (i) => DropdownMenuItem(
                    value: 2024 + i,
                    child: Row(
                      children: [
                        Icon(Icons.event_note_rounded, size: 16, color: primaryTeal.withValues(alpha: 0.6)),
                        const SizedBox(width: 8),
                        Text((2024 + i).toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )),
                  onChanged: (v) { if (v != null) setState(() => _monitoringYear = v); _fetchMonitoring(); },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final List months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return "${date.day} ${months[date.month - 1]} ${date.year}";
    } catch (e) { return dateStr; }
  }

  Widget _buildRekapTab() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_rounded, size: 80, color: Color(0xFFEF4444)),
              const SizedBox(height: 24),
              const Text("Export Rekap Absensi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 12),
              Text("Unduh laporan bulanan untuk ${_selectedClass == 'Semua Kelas' ? 'Semua Kelas' : 'Kelas $_selectedClass'} ${_selectedRombel == 'Semua Rombel' ? '' : _selectedRombel} periode $_monitoringMonth/$_monitoringYear.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _showExportOptions, 
                icon: const Icon(Icons.tune_rounded), 
                label: const Text("Pilih Opsi & Download"), 
                style: ElevatedButton.styleFrom(backgroundColor: primaryTeal, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            // Dynamic logic using _rawFilterData (similar to _buildFilters)
            final batchesList = ['Angkatan', ..._rawFilterData.map((e) => e['batch']?.toString()).whereType<String>().toSet().toList()..sort()];
            
            final tempForClass = _rawFilterData.where((e) => _selectedBatch == 'Angkatan' || e['batch']?.toString() == _selectedBatch).toList();
            final classesList = ['Kelas', ...tempForClass.map((e) => e['class']?.toString()).whereType<String>().toSet().toList()..sort()];

            final tempForRombel = tempForClass.where((e) => _selectedClass == 'Kelas' || e['class']?.toString() == _selectedClass).toList();
            final rombelsList = ['Rombel', ...tempForRombel.map((e) => e['rombel']?.toString()).whereType<String>().toSet().toList()..sort()];

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Cetak Laporan PDF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Text("Pilih periode dan kelas untuk rekapitulasi siswa.", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  const SizedBox(height: 24),
                  
                  _dlLabel("Pilih Angkatan"),
                  _modalDropdown("Angkatan", batchesList, _selectedBatch, (v) {
                    setModalState(() {
                      _selectedBatch = v!;
                      // Cascading reset logic inside modal
                      final currentClasses = ['Kelas', ..._rawFilterData.where((e) => _selectedBatch == 'Angkatan' || e['batch']?.toString() == _selectedBatch).map((e) => e['class']?.toString()).whereType<String>().toSet()];
                      if (!currentClasses.contains(_selectedClass)) {
                        _selectedClass = 'Kelas';
                      }
                      final currentRombels = ['Rombel', ..._rawFilterData.where((e) => (_selectedBatch == 'Angkatan' || e['batch']?.toString() == _selectedBatch) && (_selectedClass == 'Kelas' || e['class']?.toString() == _selectedClass)).map((e) => e['rombel']?.toString()).whereType<String>().toSet()];
                      if (!currentRombels.contains(_selectedRombel)) {
                        _selectedRombel = 'Rombel';
                      }
                    });
                    _fetchMonitoring(onComplete: () => setModalState(() {}));
                  }),
                  
                  _dlLabel("Pilih Kelas"),
                  _modalDropdown("Kelas", classesList, _selectedClass, (v) {
                    setModalState(() {
                      _selectedClass = v!;
                      // Cascading reset logic inside modal
                      final currentRombels = ['Rombel', ..._rawFilterData.where((e) => (_selectedBatch == 'Angkatan' || e['batch']?.toString() == _selectedBatch) && (_selectedClass == 'Kelas' || e['class']?.toString() == _selectedClass)).map((e) => e['rombel']?.toString()).whereType<String>().toSet()];
                      if (!currentRombels.contains(_selectedRombel)) {
                        _selectedRombel = 'Rombel';
                      }
                    });
                    _fetchMonitoring(onComplete: () => setModalState(() {}));
                  }),
                  
                  _dlLabel("Pilih Rombel"),
                  _modalDropdown("Rombel", rombelsList, _selectedRombel, (v) {
                    setModalState(() {
                      _selectedRombel = v!;
                    });
                    _fetchMonitoring(onComplete: () => setModalState(() {}));
                  }),
                  
                  _dlLabel("Jenis Laporan"),
                  _modalDropdown("Jenis Laporan", ["Bulanan", "Harian", "Semester 1", "Semester 2"], _exportType, (v) {
                    setModalState(() => _exportType = v!);
                    _fetchMonitoring(onComplete: () => setModalState(() {}));
                  }),
                  
                  if (_exportType == "Harian")
                    InkWell(
                      onTap: () async {
                        final p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (p != null) {
                          setModalState(() => _selectedDate = p);
                          _fetchMonitoring(onComplete: () => setModalState(() {}));
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: "Pilih Tanggal",
                            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: Row(
                            children: [
                              Text(_formatDate(_selectedDate.toString()), style: const TextStyle(fontSize: 15)),
                              const Spacer(),
                              const Icon(Icons.calendar_month, size: 20, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        if (!_exportType.startsWith("Semester"))
                          Expanded(
                            child: _modalDropdown("Bulan", ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'], ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'][_monitoringMonth - 1], (v) {
                              final idx = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'].indexOf(v!) + 1;
                              setModalState(() => _monitoringMonth = idx);
                              _fetchMonitoring(onComplete: () => setModalState(() {}));
                            }),
                          ),
                        if (!_exportType.startsWith("Semester")) const SizedBox(width: 12),
                        Expanded(
                          child: _modalDropdown("Tahun", List.generate(5, (i) => (2024 + i).toString()), _monitoringYear.toString(), (v) {
                            setModalState(() => _monitoringYear = int.parse(v!));
                            _fetchMonitoring(onComplete: () => setModalState(() {}));
                          }),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("BATAL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isFetchingMonitoring ? null : () {
                            Navigator.pop(context);
                            _generatePDF();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isFetchingMonitoring 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("DOWNLOAD PDF", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SafeArea(child: SizedBox(height: 10)),
                ],
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _modalDropdown(String label, List<String> items, String value, ValueChanged<String?> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 15)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildHarianTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        _buildSummaryCards(),
        const SizedBox(height: 24),
        if (_isLoading) const Padding(padding: EdgeInsets.only(top: 50), child: Center(child: CircularProgressIndicator()))
        else if (_filteredStudents.isEmpty) _buildEmptyState()
        else ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _filteredStudents.length, itemBuilder: (context, index) => _buildStudentItem(index)),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final hadir = _allStudents.where((s) => s['status'] == 'Hadir').length;
    final izinSakit = _allStudents.where((s) => s['status'] == 'Izin' || s['status'] == 'Sakit').length;
    final alpa = _allStudents.where((s) => s['status'] == 'Alfa').length;
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            "Hadir", 
            hadir.toString(), 
            colorHadir,
            onTap: () => _tabController.animateTo(1, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut),
          )
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard(
            "Izin/Sakit", 
            izinSakit.toString(), 
            colorIzin,
            onTap: () => _tabController.animateTo(1, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut),
          )
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard(
            "Alfa", 
            alpa.toString(), 
            colorAlfa,
            onTap: () => _tabController.animateTo(1, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut),
          )
        ),
      ],
    );
  }

  Widget _summaryCard(String label, String value, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05), 
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    // 1. Unique Batches (Always from full data)
    final batchesList = ['Angkatan', ..._rawFilterData.map((e) => e['batch']?.toString()).whereType<String>().toSet().toList()..sort()];
    
    // 2. Filter for Class choices based on Angkatan
    final tempForClass = _rawFilterData.where((e) => _selectedBatch == 'Angkatan' || e['batch'] == _selectedBatch).toList();
    final classesList = ['Kelas', ...tempForClass.map((e) => e['class']?.toString()).whereType<String>().toSet().toList()..sort()];

    // 3. Filter for Rombel choices based on Angkatan & Kelas
    final tempForRombel = tempForClass.where((e) => _selectedClass == 'Kelas' || e['class'] == _selectedClass).toList();
    final rombelsList = ['Rombel', ...tempForRombel.map((e) => e['rombel']?.toString()).whereType<String>().toSet().toList()..sort()];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: EdgeInsets.all(_isMobile ? 12 : 20),
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
      child: Row(
        children: [
          _dropdownFilter("Angkatan", batchesList, _selectedBatch, (v) {
            setState(() {
              _selectedBatch = v!;
              final validClasses = ['Kelas', ..._rawFilterData.where((e) => _selectedBatch == 'Angkatan' || e['batch'] == _selectedBatch).map((e) => e['class']?.toString()).whereType<String>().toSet()];
              if (!validClasses.contains(_selectedClass)) {
                _selectedClass = 'Kelas';
              }
              final validRombels = ['Rombel', ..._rawFilterData.where((e) => (_selectedBatch == 'Angkatan' || e['batch'] == _selectedBatch) && (_selectedClass == 'Kelas' || e['class'] == _selectedClass)).map((e) => e['rombel']?.toString()).whereType<String>().toSet()];
              if (!validRombels.contains(_selectedRombel)) {
                _selectedRombel = 'Rombel';
              }
            });
            _refreshAllData();
          }),
          const SizedBox(width: 8),
          _dropdownFilter("Kelas", classesList, _selectedClass, (v) {
            setState(() {
              _selectedClass = v!;
              final validRombels = ['Rombel', ..._rawFilterData.where((e) => (_selectedBatch == 'Angkatan' || e['batch'] == _selectedBatch) && (_selectedClass == 'Kelas' || e['class'] == _selectedClass)).map((e) => e['rombel']?.toString()).whereType<String>().toSet()];
              if (!validRombels.contains(_selectedRombel)) {
                _selectedRombel = 'Rombel';
              }
            });
            _refreshAllData();
          }),
          const SizedBox(width: 8),
          _dropdownFilter("Rombel", rombelsList, _selectedRombel, (v) {
            setState(() => _selectedRombel = v!);
            _refreshAllData();
          }),
        ],
      ),
    );
  }

  Widget _dropdownFilter(String label, List<String> items, String selectedValue, ValueChanged<String?> onChanged) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: _isMobile ? 10 : 11,
                fontWeight: FontWeight.w800,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            height: _isMobile ? 38 : 44,
            padding: EdgeInsets.symmetric(horizontal: _isMobile ? 8 : 12),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(_isMobile ? 10 : 12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedValue,
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: _isMobile ? 16 : 18, color: const Color(0xFF94A3B8)),
                style: TextStyle(
                  fontSize: _isMobile ? 11 : 12, 
                  color: const Color(0xFF1E293B), 
                  fontWeight: FontWeight.w600,
                ),
                items: items.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(fontSize: _isMobile ? 11 : 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentItem(int index) {
    final student = _filteredStudents[index];
    final status = student['status'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5)]
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(backgroundColor: primaryTeal.withValues(alpha: 0.1), child: Text(student['name'][0].toUpperCase(), style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold))),
              title: Text(student['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(
                "${student['class'] ?? '-'} • ${student['rombel'] ?? '-'}",
                style: TextStyle(fontSize: 12, color: Colors.grey[600])
              ),
              trailing: _statusChip(status),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _optionBtn("Hadir", colorHadir, status == "Hadir", () => _updateStatus(index, "Hadir")),
                  _optionBtn("Izin", colorIzin, status == "Izin", () => _updateStatus(index, "Izin")),
                  _optionBtn("Sakit", colorSakit, status == "Sakit", () => _updateStatus(index, "Sakit")),
                  _optionBtn("Alfa", colorAlfa, status == "Alfa", () => _updateStatus(index, "Alfa")),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == "Hadir" ? colorHadir : (status == "Alfa" ? colorAlfa : colorIzin);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)));
  }

  Widget _optionBtn(String label, Color color, bool isSelected, VoidCallback onTap) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: isSelected ? color : bgColor, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey[600]))))));
  }

  Widget _buildEmptyState() {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 60), child: Column(children: [Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey[200]), const SizedBox(height: 16), Text(_isLoading ? "Memuat..." : "Siswa tidak ditemukan", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold))]));
  }

  Widget _dlLabel(String text) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))));

  Widget _buildBottomSaveButton() {
    if (_isMobile) {
      // --- MOBILE FLOATING ISLAND STYLE ---
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primaryTeal.withValues(alpha: 0.12),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          children: [
            // SCAN BUTTON (Mobile)
            Material(
              color: primaryTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _openScanner,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  child: Icon(Icons.qr_code_scanner_rounded, color: primaryTeal, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // SIMPAN BUTTON (Mobile)
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [primaryTeal, const Color(0xFF0F766E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryTeal.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          "Simpan Absensi",
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
                        ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // --- DESKTOP DOCK STYLE (Keep original) ---
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -10),
            )
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                      onPressed: _openScanner,
                      icon: Icon(Icons.qr_code_scanner_rounded, size: 20, color: primaryTeal),
                      label: const Text("Scan", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryTeal,
                        side: BorderSide(color: primaryTeal.withValues(alpha: 0.2), width: 1.5),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        backgroundColor: primaryTeal.withValues(alpha: 0.02),
                      ))),
              const SizedBox(width: 12),
              Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: primaryTeal.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveAttendance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Simpan Absensi", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.2))),
                  )),
            ],
          ),
        ),
      );
    }
  }
}

class _ScannerOverlay extends StatelessWidget {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;

  const _ScannerOverlay({
    required this.borderColor,
    this.borderRadius = 10,
    this.borderLength = 20,
    this.borderWidth = 4,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScannerOverlayPainter(
        borderColor: borderColor,
        borderRadius: borderRadius,
        borderLength: borderLength,
        borderWidth: borderWidth,
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;

  _ScannerOverlayPainter({
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaWidth = size.width * 0.7;
    final double scanAreaHeight = scanAreaWidth;
    final Rect scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanAreaWidth,
      height: scanAreaHeight,
    );

    // 1. Draw Background Mask
    final Paint maskPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    final Path maskPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, Radius.circular(borderRadius)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(maskPath, maskPaint);

    // 2. Draw Corner Borders
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final double r = borderRadius;
    final double l = borderLength;

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.left, scanRect.top + l)
        ..lineTo(scanRect.left, scanRect.top + r)
        ..arcToPoint(Offset(scanRect.left + r, scanRect.top), radius: Radius.circular(r))
        ..lineTo(scanRect.left + l, scanRect.top),
      borderPaint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.right - l, scanRect.top)
        ..lineTo(scanRect.right - r, scanRect.top)
        ..arcToPoint(Offset(scanRect.right, scanRect.top + r), radius: Radius.circular(r))
        ..lineTo(scanRect.right, scanRect.top + l),
      borderPaint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.right, scanRect.bottom - l)
        ..lineTo(scanRect.right, scanRect.bottom - r)
        ..arcToPoint(Offset(scanRect.right - r, scanRect.bottom), radius: Radius.circular(r))
        ..lineTo(scanRect.right - l, scanRect.bottom),
      borderPaint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.left + l, scanRect.bottom)
        ..lineTo(scanRect.left + r, scanRect.bottom)
        ..arcToPoint(Offset(scanRect.left, scanRect.bottom - r), radius: Radius.circular(r))
        ..lineTo(scanRect.left, scanRect.bottom - l),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanningLine extends StatefulWidget {
  const _ScanningLine();

  @override
  State<_ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<_ScanningLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _animation = Tween<double>(begin: -100, end: 100).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.65,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0),
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
