import 'dart:convert';
import 'package:http/http.dart' as http;

class HolidayHelper {
  static Map<String, String> _apiHolidays = {};
  static int? _cachedYear;

  // 1. Daftar libur nasional dengan tanggal TETAP (Offline Selamanya)
  static final Map<String, String> _fixedHolidays = {
    '01-01': 'Tahun Baru Masehi',
    '05-01': 'Hari Buruh Internasional',
    '06-01': 'Hari Lahir Pancasila',
    '08-17': 'Hari Kemerdekaan RI',
    '12-25': 'Hari Raya Natal',
  };

  // 2. Data Cadangan Offline untuk hari raya (2024-2026) 
  // Biar tetep merah walau gak ada internet di tahun-tahun ini
  static final Map<String, String> _offlineBackup = {
    // 2024
    '2024-02-08': 'Isra Mikraj Nabi Muhammad SAW',
    '2024-02-10': 'Tahun Baru Imlek 2575 Kongzili',
    '2024-03-11': 'Hari Suci Nyepi Tahun Baru Saka 1946',
    '2024-03-29': 'Wafat Isa Almasih',
    '2024-03-31': 'Hari Paskah',
    '2024-04-10': 'Hari Raya Idul Fitri 1445 Hijriah',
    '2024-04-11': 'Hari Raya Idul Fitri 1445 Hijriah',
    '2024-05-09': 'Kenaikan Isa Almasih',
    '2024-05-23': 'Hari Raya Waisak 2568 BE',
    '2024-06-17': 'Hari Raya Idul Adha 1445 Hijriah',
    '2024-07-07': 'Tahun Baru Islam 1446 Hijriah',
    '2024-09-16': 'Maulid Nabi Muhammad SAW',
    // 2025
    '2025-01-29': 'Tahun Baru Imlek 2576 Kongzili',
    '2025-03-27': 'Isra Mikraj Nabi Muhammad SAW',
    '2025-03-29': 'Hari Suci Nyepi Tahun Baru Saka 1947',
    '2025-03-31': 'Hari Raya Idul Fitri 1446 Hijriah',
    '2025-04-01': 'Hari Raya Idul Fitri 1446 Hijriah',
    '2025-04-18': 'Wafat Yesus Kristus',
    '2025-04-20': 'Hari Paskah',
    '2025-05-12': 'Hari Raya Waisak 2569 BE',
    '2025-05-29': 'Kenaikan Yesus Kristus',
    '2025-06-06': 'Hari Raya Idul Adha 1446 Hijriah',
    '2025-06-27': 'Tahun Baru Islam 1447 Hijriah',
    '2025-09-05': 'Maulid Nabi Muhammad SAW',
    // 2026
    '2026-02-17': 'Tahun Baru Imlek 2577 Kongzili',
    '2026-03-16': 'Isra Mikraj Nabi Muhammad SAW',
    '2026-03-19': 'Hari Suci Nyepi Tahun Baru Saka 1948',
    '2026-03-20': 'Hari Raya Idul Fitri 1447 Hijriah',
    '2026-03-21': 'Hari Raya Idul Fitri 1447 Hijriah',
    '2026-04-03': 'Wafat Yesus Kristus',
    '2026-04-05': 'Hari Paskah',
    '2026-05-14': 'Kenaikan Yesus Kristus',
    '2026-05-31': 'Hari Raya Waisak 2570 BE',
    '2026-06-27': 'Hari Raya Idul Adha 1447 Hijriah',
    '2026-07-16': 'Tahun Baru Islam 1448 Hijriah',
    '2026-08-25': 'Maulid Nabi Muhammad SAW',
  };

  static Future<void> initHolidays(int year) async {
    if (_cachedYear == year && _apiHolidays.isNotEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('https://api-harilibur.vercel.app/api?year=$year'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        Map<String, String> tempHolidays = {};
        for (var holiday in data) {
          if (holiday['is_holiday'] == true) {
            tempHolidays[holiday['holiday_date']] = holiday['holiday_name'];
          }
        }
        _apiHolidays = tempHolidays;
        _cachedYear = year;
      }
    } catch (e) {
      // Gagal ambil API? Gak masalah, nanti pake data backup
    }
  }

  static String? getHolidayName(DateTime date) {
    // 1. Cek Libur Tetap (Offline - 17 Agt, dll)
    String fixedKey = "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    if (_fixedHolidays.containsKey(fixedKey)) return _fixedHolidays[fixedKey];

    // 2. Cek Data Online (Hasil Sync)
    String fullKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    if (_apiHolidays.containsKey(fullKey)) return _apiHolidays[fullKey];

    // 3. Cek Data Cadangan Offline (Buat jaga-jaga kalau gak ada internet)
    return _offlineBackup[fullKey];
  }

  static bool isHoliday(DateTime date) {
    return date.weekday == DateTime.sunday || getHolidayName(date) != null;
  }
}
