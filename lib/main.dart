import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'splash_screen.dart';
import 'login&register/loginpath.dart';
import 'pengaturan/ganti_password_page.dart';
import 'utils/push_notification_service.dart';
import 'config/env_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi localization
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi Supabase
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    publishableKey: EnvConfig.supabasePublishableKey,
  );

  // Jalankan service notifikasi (OneSignal)
  await PushNotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    
    // Inisialisasi pendengar notifikasi dengan navigator key
    PushNotificationService.listenNotifications(_navigatorKey);
    
    // Mendengarkan perubahan status autentikasi
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        // Gunakan Future.delayed sedikit supaya Navigator benar-benar siap
        Future.delayed(Duration.zero, () {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (context) => const GantiPasswordPage()),
          );
        });
      } else if (event == AuthChangeEvent.signedOut) {
        // Jika akun keluar atau sesi habis, tendang ke halaman login
        Future.delayed(Duration.zero, () {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Lapor Sekola e-Rapor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
