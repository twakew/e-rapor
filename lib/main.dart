import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'splash_screen.dart';
import 'utils/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi localization
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi ApiService
  await ApiService().init();

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
    
    // Auth state changes need custom implementation if still required
    // (e.g. using a stream in ApiService, or handling timeouts manually).

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
