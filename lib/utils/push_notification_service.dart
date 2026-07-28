import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  static void _updateExternalId() {
    if (!isSupported) return;
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      OneSignal.login(user.id);
      
      // Sync tagging role jika data profile tersedia
      Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle()
          .then((data) {
            if (data != null && data['role'] != null) {
              setTag('role', data['role'].toString().toLowerCase());
            }
          });

      // Update token/id di profile jika masih dibutuhkan
      Supabase.instance.client
          .from('profiles')
          .update({'onesignal_id': user.id})
          .eq('id', user.id)
          .then((_) => debugPrint('OneSignal External ID updated'))
          .catchError((e) => debugPrint('Error updating OneSignal ID: $e'));
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
      await Supabase.instance.client.functions.invoke(
        'send-push-notification',
        body: {
          'user_id': userId, // Jika null, bisa diatur di function untuk kirim ke Admin
          'title': title,
          'message': message,
          if (data != null) 'data': data,
        },
      );
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
