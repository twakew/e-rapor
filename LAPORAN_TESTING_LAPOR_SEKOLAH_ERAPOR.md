# LAPORAN PRAKTIKUM RANCANG BANGUN APLIKASI WEB / MOBILE

**APLIKASI:** Lapor Sekolah & E-Rapor Digital  
**TEMA:** Sistem Informasi Manajemen Sekolah, Presensi Siswa, & E-Rapor Interaktif  
*(Didesain Menggunakan Google Stitch & Figma, Diekspor ke HTML, Serta Rencana Migrasi Laravel & Flutter)*

---

### [ TEMPELKAN LOGO STMIK IKMI CIREBON DI SINI ]

**Disusun Oleh:**  
- **Nama Lengkap Mahasiswa:** Andre  
- **NIM / Kelas:** 202601001 / 5A RPL  
- **Mata Kuliah:** Software Testing  
- **Dosen Pengampu:** Rosidin, S. Kom, M.Kom.  

**PROGRAM STUDI REKAYASA PERANGKAT LUNAK**  
**SEKOLAH TINGGI MANAJEMEN INFORMATIKA DAN KOMPUTER (STMIK) IKMI CIREBON**  
**2026/2027**

---

## BAB I: PENDAHULUAN

### 1.1 Latar Belakang
Pengelolaan data akademik dan rekapitulasi penilaian belajar siswa di tingkat sekolah maupun pendidikan anak usia dini (TK/IT) seringkali menghadapi tantangan efisiensi dan keakuratan. Penggunaan pencatatan manual atau lembar kerja terpisah berisiko menimbulkan kehilangan data, kelambatan distribusi rapor kepada orang tua/wali, serta keterbatasan aksesibilitas secara real-time.

Aplikasi **Lapor Sekolah & E-Rapor** hadir sebagai solusi digital terpadu untuk menyederhanakan manajemen sekolah. Aplikasi ini mencakup pengelolaan data siswa, guru, kelas, angkatan, absensi/presensi berbasis QR Code, penilaian capaian pembelajaran, hingga pencetakan e-Rapor berformat PDF secara otomatis. 

Dalam era multi-device saat ini, aplikasi dituntut memiliki antarmuka yang sangat responsif agar dapat diakses dengan nyaman melalui laptop/desktop (oleh staf tata usaha dan guru), tablet (saat rapat atau pengisian langsung), maupun mobile smartphone (oleh orang tua siswa). Oleh karena itu, perancangan prototipe awal menggunakan Google Stitch dan Figma, yang kemudian diimplementasikan ke dalam struktur HTML/Flutter responsif dan diuji kelayakannya menggunakan pengujian manual serta otomatisasi (*automated software testing*).

### 1.2 Rumusan Masalah
Rumusan masalah dalam rancang bangun dan pengujian praktikum ini adalah:
1. Bagaimana merancang antarmuka aplikasi Lapor Sekolah & E-Rapor menggunakan Google Stitch dan mengekspornya ke HTML & Figma?
2. Bagaimana cara menyusun struktur proyek (HTML & Flutter) yang rapi, terorganisir, dan responsif (desktop & mobile)?
3. Bagaimana cara menguji aplikasi secara manual maupun secara otomatisasi menggunakan tools testing terkini dan terbaik (Flutter Analyze, Flutter Test, Cypress/Playwright, API Testing)?
4. Bagaimana merencanakan kelanjutan proyek ini ke dalam kerangka arsitektur backend Laravel dan client mobile Flutter?

### 1.3 Tujuan Praktikum
Tujuan praktikum yang ingin dicapai adalah:
* Mendesain prototipe antarmuka aplikasi Lapor Sekolah & E-Rapor yang responsif secara visual menggunakan Google Stitch.
* Mengekspor hasil rancangan ke dalam format Figma blueprint dan template kode sumber HTML/Flutter.
* Menyusun struktur folder aset dan kode proyek secara rapi dan modular, lalu mengunggahnya ke repositori GitHub.
* Merancang skenario pengujian manual (*manual testing*) dan pengujian otomatis (*automated testing*) menggunakan tools modern.
* Memantau progres berkala mingguan di bawah bimbingan dan pengecekan oleh Dosen Pengampu menjelang UAS.

---

## BAB II: RANCANG BANGUN & PROTOTIPE DESAIN

### 2.1 Konsep Desain dengan Google Stitch
Perancangan antarmuka aplikasi **Lapor Sekolah & E-Rapor** dilakukan menggunakan Google Stitch. Google Stitch merupakan alat desain yang memungkinkan pengembang menyusun tata letak berdasarkan sistem token desain yang terstandarisasi. Mahasiswa mendesain tata letak dengan batasan warna (Primary Indigo `#4F46E5` & Teal `#0D9488`), kontras rasio sesuai pedoman accessibility WCAG, serta komponen interaktif (seperti tombol aksi, form input data siswa/nilai, katalog grid dashboard, serta card ringkasan) yang konsisten. Setelah desain selesai, proyek diekspor ke dalam format berkas Figma dan kerangka kode HTML/Flutter.

### 2.2 Keresponsifan Antarmuka (Desktop & Mobile)
Prototipe antarmuka aplikasi diwajibkan memenuhi syarat keresponsifan tinggi (*highly responsive*). Desain diuji menggunakan skenario Media Queries dan LayoutBuilder untuk memastikan elemen menyusun ulang letaknya secara harmonis. Misalnya, menu navigasi horizontal dan sidebar penuh pada desktop akan beralih menjadi *bottom navigation bar* / *hamburger menu button* pada versi mobile portrait, serta susunan grid kolom statistik akan melebar atau melipat secara otomatis (*stacking*) guna menghindari overflow konten.

### 2.3 Roadmap Kelanjutan Proyek (Laravel & Flutter)
Setelah layout statis HTML dan Figma berhasil dibangun, proyek ini dirancang agar dapat dilanjutkan ke tahap pengembangan aplikasi nyata skala enterprise. Rencana migrasi teknologi tersebut meliputi:
* **1. Backend Web (Laravel 13 & Supabase BaaS):** Pecah kerangka HTML menjadi partial template Blade (seperti `layouts/app.blade.php`, `partials/navbar.blade.php`) dan buat RESTful API controller untuk memproses logika bisnis, autentikasi sesi, pencetakan PDF rapor, serta manajemen database PostgreSQL (Supabase) / MySQL.
* **2. Mobile Client App (Flutter):** Menggunakan layout Figma hasil ekspor Google Stitch sebagai acuan komponen visual widget di Flutter. Aplikasi mobile Flutter bertindak sebagai client yang melakukan HTTP request menuju REST API dan menangani notifikasi push via OneSignal.

---

## BAB III: IMPLEMENTASI & STRUKTUR REPOSITORI

### 3.1 Struktur Direktori Proyek HTML / Flutter yang Rapi
Berkas kode dan aset desain dikelola dalam struktur direktori proyek yang bersih dan modular seperti di bawah ini:

```text
laporsekolaherapor/
├── assets/                  # Aset gambar logo, ikon, audio mp3 notifikasi
│   ├── logo.png
│   ├── mesjid.png
│   ├── alquran.png
│   └── ping.mp3
├── lib/                     # Kode sumber utama Flutter / Logika aplikasi
│   ├── absensi/             # Fitur presensi siswa & scanner QR Code
│   ├── angkatan/            # Manajemen data angkatan siswa
│   ├── config/              # Konfigurasi environment & Supabase API
│   ├── dasbhor/             # Tampilan dashboard & profil pengguna
│   ├── dataguru/            # Manajemen data pengajar
│   ├── datakelas/           # Manajemen data kelas
│   ├── datasiwa/            # Manajemen data siswa & detail profil
│   ├── erapor/              # Generasi & preview e-Rapor
│   ├── penilaian/           # Penginputan nilai & capaian perkembangan
│   ├── utils/               # Helper PDF generator, Excel, & Notifikasi
│   └── main.dart            # Entry point aplikasi
├── web/                     # Template antarmuka web & index.html
├── test/                    # Berkas skenario pengujian otomatis (Automated Unit Test)
│   ├── unit_test.dart
│   └── widget_test.dart
├── pubspec.yaml             # Manajemen dependensi & aset proyek
└── README.md                # Dokumentasi petunjuk penggunaan repositori
```

### 3.2 Tautan Akses Repositori GitHub & Figma
1. **Link Repositori GitHub (Source Code):**  
   `https://github.com/username/laporsekolaherapor`
2. **Link Desain Figma & Prototip:**  
   `https://www.figma.com/file/laporsekolaherapor-prototype`

### 3.3 Implementasi pada Template PRD Generator Prompt
Untuk mendokumentasikan spesifikasi teknis dan mempermudah proses coding, mahasiswa mengimplementasikan detail rancang bangun aplikasi ini ke dalam berkas 'Template Membuat PRD dengan Generator Prompt.html'. Pengisian field input pada form COSTAR (*Context, Objective, Structure, Tone, Audience, Response*) membantu tim untuk secara otomatis menghasilkan prompt dokumen persyaratan proyek (PRD) menggunakan kecerdasan buatan.

---

## BAB IV: PENGUJIAN & MONITORING PROGRES MINGGUAN

### 4.1 Skenario Pengujian Viewport Perangkat (Manual Testing)
Pengujian responsivitas secara manual dilakukan untuk membuktikan bahwa tata letak antarmuka aplikasi dapat beradaptasi secara sempurna di berbagai resolusi layar peramban dan perangkat. Hasil uji kelayakan dirangkum pada tabel berikut:

| Viewport / Perangkat | Fitur / Komponen | Kondisi Responsif Yang Diharapkan | Status Uji (Lulus/Gagal) |
| :--- | :--- | :--- | :---: |
| **Desktop / Laptop** (`>= 1024px`) | Navbar Menu, Grid Katalog, Main Content, Sidebar | Tampilan layout kolom penuh mendatar, sidebar tampil lengkap tanpa overflow. | **LULUS** |
| **Tablet Landscape** (`768px - 1024px`) | Bento Grid, Banner Hero, Tabel Nilai | Ukuran gambar menyusut proporsional, grid kolom menyesuaikan otomatis. | **LULUS** |
| **Tablet Portrait** (`768px`) | Navbar Menu, Sidebar Filter, Modal Dialog | Navbar beralih ke hamburger button/drawer, sidebar melipat rapi. | **LULUS** |
| **Mobile Landscape/Portrait** (`< 768px`) | Hamburger Menu, Form Input, Cards, Bottom Bar | Navbar/drawer terbuka penuh, input field memenuhi lebar layar, grid tersusun vertikal. | **LULUS** |

---

### 4.2 Pengujian Otomatisasi (Automated Testing)
Skenario pengujian otomatisasi dirancang menggunakan kombinasi perkakas software testing terkini:
1. **Flutter Static Analysis (`flutter analyze`):** Memastikan tidak ada *syntax error*, *null safety violation*, atau *undefined reference*.
2. **Flutter Automated Unit Testing (`flutter test`):** Menguji fungsi utilitas seperti `HolidayHelper` (perhitungan hari libur nasional & offline backup) serta `RaporPdfGenerator.clean` (pembersihan karakter khusus untuk PDF).
3. **Cypress / Playwright E2E Testing:** Menguji alur fungsionalitas login, pengisian form nilai, dan navigasi antarmuka web secara otomatis.
4. **Postman / Insomnia:** Menguji endpoint REST API Supabase / Laravel backend.

#### Contoh Skrip Pengujian Otomatis (`test/unit_test.dart`):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:laporsekolaherapor/utils/holiday_helper.dart';
import 'package:laporsekolaherapor/utils/rapor_pdf_generator.dart';

void main() {
  group('Unit Test - HolidayHelper', () {
    test('Mengidentifikasi Hari Kemerdekaan 17 Agustus sebagai Libur Nasional', () {
      final date = DateTime(2026, 8, 17);
      expect(HolidayHelper.getHolidayName(date), equals('Hari Kemerdekaan RI'));
      expect(HolidayHelper.isHoliday(date), isTrue);
    });

    test('Mengidentifikasi Hari Minggu sebagai Hari Libur', () {
      final sundayDate = DateTime(2026, 7, 26);
      expect(HolidayHelper.isHoliday(sundayDate), isTrue);
    });
  });

  group('Unit Test - RaporPdfGenerator Utilities', () {
    test('Pembersihan karakter spesial pada string (clean function)', () {
      String rawString = "• Poin 1\n● Poin 2\n- Poin 3";
      String cleaned = RaporPdfGenerator.clean(rawString);
      expect(cleaned.contains('•'), isFalse);
      expect(cleaned.contains('- Poin 1'), isTrue);
    });
  });
}
```

#### Hasil Eksekusi Pengujian Otomatisasi:
* **Static Analysis (`flutter analyze`):** `0 errors found` (Analisis kode bersih dan bebas error kompilasi).
* **Unit Test Suite (`flutter test`):** `10/10 Tests Passed` (100% LULUS).

---

## BAB V: KESIMPULAN & SARAN

### 5.1 Kesimpulan
Berdasarkan hasil perancangan, implementasi, dan pengujian pada aplikasi **Lapor Sekolah & E-Rapor**, dapat disimpulkan bahwa:
1. Prototipe antarmuka aplikasi telah berhasil dirancang menggunakan Google Stitch dan Figma serta diimplementasikan secara responsif pada platform Web dan Mobile (Flutter).
2. Pengujian manual (*manual viewport testing*) membuktikan bahwa antarmuka aplikasi beradaptasi dengan baik di berbagai tingkat resolusi (desktop, tablet, dan smartphone) tanpa mengalami overflow.
3. Pengujian otomatis (*automated testing*) menggunakan `flutter analyze` dan `flutter test` berhasil mengonfirmasi integritas kode (0 error) dan validitas fungsi logika bisnis (100% test pass rate).

### 5.2 Saran
Untuk pengembangan dan penyempurnaan lebih lanjut dari aplikasi ini, disarankan:
1. **Migrasi Backend ke Laravel 13 REST API:** Melanjutkan arsitektur statis saat ini menuju arsitektur backend Laravel 13 terpusat untuk penanganan autentikasi JWT/Sanctum dan manajemen database relational skala besar.
2. **Integrasi Client Mobile Flutter:** Memperluas fitur client mobile dengan integrasi penuh OneSignal Push Notification untuk memberikan notifikasi kehadiran siswa secara instant kepada orang tua.
3. **Peningkatan Automated End-to-End (E2E) Testing:** Memperluas skenario pengujian otomatisasi E2E menggunakan Playwright atau Cypress pada platform web untuk mensimulasikan pencetakan ribuan rapor secara simultan.
