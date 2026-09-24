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
          primaryContainer: AppColors.brandSofter,
          onPrimaryContainer: AppColors.brandDark,
          secondary: AppColors.secondary,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.brandSoft,
          onSecondaryContainer: AppColors.brandDark,
          surface: AppColors.cardWhite,
          onSurface: AppColors.textDark,
          error: AppColors.errorRed,
          onError: Colors.white,
          outline: AppColors.borderColor,
          outlineVariant: AppColors.borderColor,
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
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textDark,
            side: const BorderSide(color: AppColors.borderColor),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardWhite,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.borderColor),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.brand),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: AppColors.textSecondary,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.textDark,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.textMuted,
          ),
          trackOutlineColor: WidgetStateProperty.all(AppColors.borderColor),
        ),
        checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.brandSoft,
          labelStyle: const TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.w600),
          side: const BorderSide(color: AppColors.brandSofter),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.brand,
          linearTrackColor: AppColors.brandSoft,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(Colors.black.withValues(alpha: 0.25)),
          thickness: WidgetStateProperty.all(6),
          radius: const Radius.circular(3),
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
