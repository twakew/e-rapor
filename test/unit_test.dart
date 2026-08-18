import 'package:flutter_test/flutter_test.dart';
import 'package:laporsekolaherapor/utils/holiday_helper.dart';
import 'package:laporsekolaherapor/utils/rapor_pdf_generator.dart';

void main() {
  group('Unit Test - HolidayHelper', () {
    test('Mengidentifikasi Hari Kemerdekaan 17 Agustus sebagai Libur Nasional', () {
      final date = DateTime(2026, 8, 17);
      final holidayName = HolidayHelper.getHolidayName(date);
      final isLibur = HolidayHelper.isHoliday(date);

      expect(holidayName, equals('Hari Kemerdekaan RI'));
      expect(isLibur, isTrue);
    });

    test('Mengidentifikasi Hari Minggu sebagai Hari Libur', () {
      // 26 Juli 2026 adalah hari Minggu
      final sundayDate = DateTime(2026, 7, 26);
      expect(sundayDateIsSunday(sundayDate), isTrue);
      expect(HolidayHelper.isHoliday(sundayDate), isTrue);
    });

    test('Mengidentifikasi Hari Raya Idul Fitri dari Offline Backup', () {
      final idulFitri = DateTime(2026, 3, 20);
      final holidayName = HolidayHelper.getHolidayName(idulFitri);

      expect(holidayName, equals('Hari Raya Idul Fitri 1447 Hijriah'));
      expect(HolidayHelper.isHoliday(idulFitri), isTrue);
    });

    test('Hari kerja biasa bukan merupakan hari libur', () {
      // 28 Juli 2026 adalah Selasa
      final tuesdayDate = DateTime(2026, 7, 28);
      expect(HolidayHelper.getHolidayName(tuesdayDate), isNull);
      expect(HolidayHelper.isHoliday(tuesdayDate), isFalse);
    });
  });

  group('Unit Test - RaporPdfGenerator Utilities', () {
    test('Pembersihan karakter spesial pada string (clean function)', () {
      String rawString = "• Poin 1\n● Poin 2\n○ Poin 3\n▪ Poin 4\n– Strip 1\n— Strip 2";
      String cleaned = RaporPdfGenerator.clean(rawString);

      expect(cleaned.contains('•'), isFalse);
      expect(cleaned.contains('●'), isFalse);
      expect(cleaned.contains('○'), isFalse);
      expect(cleaned.contains('▪'), isFalse);
      expect(cleaned.contains('- Poin 1'), isTrue);
    });
  });
}

bool sundayDateIsSunday(DateTime d) => d.weekday == DateTime.sunday;
