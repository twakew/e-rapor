# Lapor Sekola e-Rapor (TK IT AL-HANIF LEDENG)

Sistem Informasi Manajemen Sekolah dan E-Rapor berbasis Flutter untuk **TK IT AL-HANIF LEDENG**. Aplikasi ini dirancang untuk memudahkan administrasi data siswa, guru, absensi, hingga penilaian rapor secara digital dan terintegrasi.

## 🚀 Fitur Utama

Aplikasi ini dilengkapi dengan berbagai fitur untuk mendukung operasional sekolah:

- **📊 Dashboard Interaktif**: Visualisasi data statistik sekolah mencakup total siswa, guru, dan dokumentasi secara real-time.
- **👥 Manajemen Data Siswa**: Pengelolaan informasi lengkap siswa, termasuk NIS, kelas, angkatan, data orang tua, dan status aktif.
- **👨‍🏫 Manajemen Data Guru**: Administrasi data tenaga pendidik untuk mempermudah pemantauan staf.
- **📝 Sistem Penilaian (E-Rapor)**: Pencatatan nilai siswa secara digital yang terorganisir per kelas dan semester.
- **📅 Absensi Digital**: Sistem pencatatan kehadiran siswa harian untuk memantau kedisiplinan.
- **🎓 Data Angkatan**: Fitur untuk mengelola dan mengelompokkan siswa berdasarkan tahun masuk atau angkatan.
- **🏫 Profil Sekolah**: Pengelolaan data resmi sekolah seperti NPSN, Akreditasi, Kurikulum, dan informasi kontak.
- **📸 Dokumentasi**: Galeri kegiatan sekolah untuk mendokumentasikan momen-momen penting dalam bentuk foto/media.
- **🔐 Sistem Autentikasi & Role**: Keamanan akses menggunakan backend Express (JWT) dengan pembagian peran (Super Admin, Admin, dan Guru).
- **🔔 Push Notifications**: Pengiriman pengumuman dan notifikasi penting secara real-time menggunakan integrasi OneSignal.
- **🔄 Sinkronisasi Data**: Data tersimpan di PostgreSQL dan disinkronkan lewat REST API backend (`lib/services/api_service.dart`) — bukan Supabase Realtime.

## 🛠️ Teknologi yang Digunakan

- **Frontend**: [Flutter](https://flutter.dev/) (mendukung Android, iOS, dan Windows Desktop)
- **Backend**: [Supabase](https://supabase.com/) (Database, Authentication, Storage, & Edge Functions)
- **Notifications**: [OneSignal](https://onesignal.com/)
- **State Management**: Flutter Stateful Widgets (dengan integrasi Supabase Streams)
- **Localization**: [intl](https://pub.dev/packages/intl) (untuk format tanggal dan mata uang Indonesia)

## 📱 Tampilan Platform
Aplikasi ini dioptimalkan untuk berbagai ukuran layar:
- **Mobile**: Antarmuka responsif dengan navigasi bawah (Bottom Navigation).
- **Desktop/Web**: Sidebar navigasi yang memudahkan penggunaan di perangkat layar lebar.

## ⚙️ Persiapan Pengembangan

1. Pastikan Flutter SDK sudah terinstal.
2. Konfigurasi `Supabase` pada file `lib/config/env_config.dart`.
3. Jalankan `flutter pub get` untuk menginstal dependensi.
4. Gunakan `flutter run` untuk menjalankan aplikasi.

---
© 2025 TK IT AL-HANIF LEDENG. All rights reserved.
