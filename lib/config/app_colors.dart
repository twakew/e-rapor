import 'package:flutter/material.dart';

class AppColors {
  // Dipanggil dari _MyAppState.didChangeDependencies — nilai true saat OS gelap.
  static bool isDark = false;

  // --- Core Palette (tetap konstan, kontras aman di dua mode) ---
  static const Color primary = Color(0xFF111111); // Charcoal (light) — lihat _darkValue
  static const Color secondary = Color(0xFF2F3437);
  static const Color accent = Color(0xFFF7F6F3);

  // --- Brand Accent (CTA, fokus, highlight) — indigo, warna seed asli project ---
  static const Color brand = Color(0xFF4F46E5); // Indigo 600
  static const Color brandDark = Color(0xFF4338CA); // Indigo 700
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand, brandDark],
  );

  // --- Brand Tints (state aktif, container M3) ---
  static Color get brandSoft => isDark ? const Color(0xFF232150) : const Color(0xFFEEF2FF);
  static Color get brandSofter => isDark ? const Color(0xFF34306E) : const Color(0xFFE0E7FF);

  // --- Backgrounds ---
  static Color get backgroundColor => isDark ? const Color(0xFF0F1116) : const Color(0xFFFBFBFA);
  static Color get cardWhite => isDark ? const Color(0xFF1A1D24) : const Color(0xFFFFFFFF);
  static Color get surfaceGray => isDark ? const Color(0xFF14161B) : const Color(0xFFF9F9F8);

  // --- Text (gelap = versi redup, tetap AA di atas cardWhite mode gelap) ---
  static Color get textDark => isDark ? const Color(0xFFF4F4F6) : const Color(0xFF111111);
  static Color get textSecondary => isDark ? const Color(0xFFC7CBD5) : const Color(0xFF5F5F5C);
  static Color get textMuted => isDark ? const Color(0xFFA3A9B7) : const Color(0xFF6B7280);

  // --- Borders & Dividers ---
  static Color get borderColor => isDark ? const Color(0xFF2C3038) : const Color(0xFFEAEAEA);

  // --- Muted Pastel Accents (Semantic) ---
  static Color get paleRed => isDark ? const Color(0xFF3A1F20) : const Color(0xFFFDEBEC);
  static Color get paleRedText => isDark ? const Color(0xFFE9A9A7) : const Color(0xFF9F2F2D);
  static Color get paleBlue => isDark ? const Color(0xFF17293B) : const Color(0xFFE1F3FE);
  static Color get paleBlueText => isDark ? const Color(0xFFA3CDEB) : const Color(0xFF1F6C9F);
  static Color get paleGreen => isDark ? const Color(0xFF1C2A1E) : const Color(0xFFEDF3EC);
  static Color get paleGreenText => isDark ? const Color(0xFFADD1A9) : const Color(0xFF346538);
  static Color get paleYellow => isDark ? const Color(0xFF33290F) : const Color(0xFFFBF3DB);
  static Color get paleYellowText => isDark ? const Color(0xFFE5CA84) : const Color(0xFF956400);

  // --- Semantic Colors (Desaturated) ---
  static Color get errorRed => isDark ? const Color(0xFFE1716E) : const Color(0xFF9F2F2D);
  static Color get successGreen => isDark ? const Color(0xFF7FC184) : const Color(0xFF346538);
  static Color get warningAmber => isDark ? const Color(0xFFDCB057) : const Color(0xFF956400);
  static Color get infoBlue => isDark ? const Color(0xFF7FB9E0) : const Color(0xFF1F6C9F);

  // --- Attendance Status ---
  static Color get hadir => paleGreen;
  static Color get hadirText => paleGreenText;
  static Color get izin => paleYellow;
  static Color get izinText => paleYellowText;
  static Color get sakit => paleBlue;
  static Color get sakitText => paleBlueText;
  static Color get alfa => paleRed;
  static Color get alfaText => paleRedText;

  // --- Core adaptif (dipakai sebagai tint ikon/avatar — gelap = terang) ---
  static Color get primaryAdaptive => isDark ? const Color(0xFFE2E5EA) : primary;
  static Color get secondaryAdaptive => isDark ? const Color(0xFFC5C9D0) : secondary;
  static Color get accentAdaptive => isDark ? const Color(0xFF262A31) : accent;

  // --- Ultra-Subtle Shadows ---
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.035),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.01),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.03),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // --- Hero Section ---
  static Color get heroBackground => isDark ? const Color(0xFF171A1F) : const Color(0xFFF7F6F3);
  static Color get heroText => textDark;
  static Color get heroBadge => isDark ? const Color(0xFF262A31) : const Color(0xFFEAEAEA);
  static Color get heroBadgeText => isDark ? const Color(0xFFD5D7DC) : const Color(0xFF2F3437);

  // --- Chart Colors ---
  static Color get chartGreen => isDark ? const Color(0xFF7FBF83) : const Color(0xFF346538);
  static Color get chartBlue => isDark ? const Color(0xFF82B8DE) : const Color(0xFF1F6C9F);
  static Color get chartAmber => isDark ? const Color(0xFFDCB057) : const Color(0xFF956400);
  static Color get chartGray => isDark ? const Color(0xFF9A9A97) : const Color(0xFF787774);
}
