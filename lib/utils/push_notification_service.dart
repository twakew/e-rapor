import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laporsekolaherapor/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../pengaturan/verifikasi_akun_page.dart';
import '../penilaian/penilaian_page.dart';
import '../absensi/absensi_page.dart';
import '../dokumentasi/dokumentasi_page.dart';
import '../config/env_config.dart';

class PushNotificationService {
  // OneSignal App ID
  static const String _oneSignalAppId = EnvConfig.oneSignalAppId;

  // Cek apakah platform mendukung OneSignal (Android & iOS)
  static bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> initialize() async {
    if (!isSupported) return;

    // Debugging (opsional)
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    // Inisialisasi OneSignal
    OneSignal.initialize(_oneSignalAppId);

    // Minta izin notifikasi
    await OneSignal.Notifications.requestPermission(true);
    
    // Pastikan user diaktifkan (Push Enabled)
    OneSignal.User.pushSubscription.optIn();

    // Update OneSignal External ID dengan User ID Supabase (agar bisa kirim notif per user)
    _updateExternalId();
  }

  static Future<void> _updateExternalId() async {
    if (!isSupported) return;
    
    final prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('jwt_token') ?? '';
    if (token.isNotEmpty) {
      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['id'];
      OneSignal.login(userId);
      
      try {
        final apiService = ApiService();
        final data = await apiService.getRow('profiles', userId);
        if (data.isNotEmpty && data['role'] != null) {
          setTag('role', data['role'].toString().toLowerCase());
        }

        await apiService.update('profiles', userId, {'onesignal_id': userId});
        debugPrint('OneSignal External ID updated');
      } catch (e) {
        debugPrint('Error updating OneSignal ID: $e');
      }
    }
  }

  static void setTag(String key, String value) {
    if (!isSupported) return;
    OneSignal.User.addTagWithKey(key, value);
    debugPrint("OneSignal Tag Set: $key = $value");
  }

  static void removeTag(String key) {
    if (!isSupported) return;
    OneSignal.User.removeTag(key);
  }

  static void logout() {
    if (isSupported) {
      OneSignal.logout();
      OneSignal.User.removeTag('role');
    }
    debugPrint("OneSignal Logged Out and Tags Clear");
  }

  static void login(String userId) {
    if (!isSupported) return;
    OneSignal.login(userId);
    debugPrint("OneSignal Logged In: $userId");
  }

  static Future<void> requestPermission() async {
    if (!isSupported) return;
    await OneSignal.Notifications.requestPermission(true);
  }

  /// Mengirim notifikasi melalui Supabase Edge Function
  /// [userId] adalah ID user penerima (bisa admin atau user spesifik)
  /// [title] judul notifikasi
  /// [message] isi pesan notifikasi
  static Future<void> sendNotification({
    required String? userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      await ApiService().callRpc('send-push-notification', params: {
        'user_id': userId,
        'title': title,
        'message': message,
        if (data != null) 'data': data,
      });
      debugPrint('Notifikasi dikirim ke: $userId');
    } catch (e) {
      debugPrint('Gagal mengirim notifikasi: $e');
    }
  }

  static void listenNotifications(GlobalKey<NavigatorState> navigatorKey) {
    if (!isSupported) return;

    // Handler saat notifikasi diklik
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      debugPrint('Notification clicked: ${event.notification.body} | Data: $data');
      
      if (data != null) {
        final screen = data['screen']?.toString();
        
        // Gunakan Future.delayed agar Navigator punya waktu untuk siap (terutama saat cold start)
        Future.delayed(const Duration(milliseconds: 500), () {
          if (navigatorKey.currentState == null) {
            debugPrint('NavigatorState is null, retrying in 1 second...');
            return;
          }

          if (screen == 'verifikasi') {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (context) => const VerifikasiAkunPage()),
            );
          } else if (screen == 'penilaian') {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (context) => const PenilaianPage()),
            );
          } else if (screen == 'absensi') {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => AbsensiPage(
                  studentNis: data['student_nis']?.toString(),
                  studentClass: data['student_class']?.toString(),
                ),
              ),
            );
          } else if (screen == 'dokumentasi') {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (context) => const DokumentasiPage()),
            );
          }
        });
      }
    });

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      debugPrint('Notification will display in foreground: ${event.notification.body}');
    });
  }
}
