import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/app_colors.dart';
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
        useMaterial3: true,
        // Selaras dengan AppColors (warm monochrome) — jangan dari seed indigo,
        // dulu semua widget Material bawaan berwarna ungu di tengah UI abu-abu.
        colorScheme: const ColorScheme.light(
          primary: AppColors.brand,
          onPrimary: Colors.white,
          secondary: AppColors.secondary,
          onSecondary: Colors.white,
          surface: AppColors.cardWhite,
          onSurface: AppColors.textDark,
          error: AppColors.errorRed,
          onError: Colors.white,
          outline: AppColors.borderColor,
        ),
        scaffoldBackgroundColor: AppColors.backgroundColor,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.cardWhite,
          foregroundColor: AppColors.textDark,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.textDark,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.backgroundColor,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.brand, width: 1.8),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.cardWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.textDark,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.borderColor,
          thickness: 1,
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
