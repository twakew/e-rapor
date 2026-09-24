import 'package:flutter/material.dart';

class AppColors {
  // --- Core Palette (Warm Monochrome) ---
  static const Color primary = Color(0xFF111111); // Charcoal
  static const Color secondary = Color(0xFF2F3437); // Dark Gray
  static const Color accent = Color(0xFFF7F6F3); // Warm Bone

  // --- Brand Accent (CTA, fokus, highlight) — indigo, warna seed asli project ---
  static const Color brand = Color(0xFF4F46E5); // Indigo 600
  static const Color brandDark = Color(0xFF4338CA); // Indigo 700

  // --- Brand Tints (state aktif, container M3) — satu sumber untuk pill/CTA lembut ---
  static const Color brandSoft = Color(0xFFEEF2FF); // Indigo 50
  static const Color brandSofter = Color(0xFFE0E7FF); // Indigo 100
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand, brandDark],
  );

  // --- Backgrounds ---
  static const Color backgroundColor = Color(0xFFFBFBFA); // Warm White
  static const Color cardWhite = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceGray = Color(0xFFF9F9F8); // Light Surface

  // --- Text ---
  static const Color textDark = Color(0xFF111111); // Off-Black
  static const Color textSecondary = Color(0xFF5F5F5C); // Muted Gray — AA di atas putih & abu terang (dulu #787774 borderline 4.0:1)
  static const Color textMuted = Color(0xFF6B7280); // Gray-500 — kontras AA di atas putih (dulu #A8A8A6 cuma 2.1:1)

  // --- Borders & Dividers ---
  static const Color borderColor = Color(0xFFEAEAEA); // Ultra-light Gray

  // --- Muted Pastel Accents (Semantic) ---
  static const Color paleRed = Color(0xFFFDEBEC);
  static const Color paleRedText = Color(0xFF9F2F2D);
  static const Color paleBlue = Color(0xFFE1F3FE);
  static const Color paleBlueText = Color(0xFF1F6C9F);
  static const Color paleGreen = Color(0xFFEDF3EC);
  static const Color paleGreenText = Color(0xFF346538);
  static const Color paleYellow = Color(0xFFFBF3DB);
  static const Color paleYellowText = Color(0xFF956400);

  // --- Semantic Colors (Desaturated) ---
  static const Color errorRed = Color(0xFF9F2F2D);
  static const Color successGreen = Color(0xFF346538);
  static const Color warningAmber = Color(0xFF956400);
  static const Color infoBlue = Color(0xFF1F6C9F);

  // --- Attendance Status ---
  static const Color hadir = paleGreen;
  static const Color hadirText = paleGreenText;
  static const Color izin = paleYellow;
  static const Color izinText = paleYellowText;
  static const Color sakit = paleBlue;
  static const Color sakitText = paleBlueText;
  static const Color alfa = paleRed;
  static const Color alfaText = paleRedText;

  // --- Ultra-Subtle Shadows ---
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.035),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.01),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // --- Hero Section (Flat Warm Background) ---
  static const Color heroBackground = Color(0xFFF7F6F3);
  static const Color heroText = Color(0xFF111111);
  static const Color heroBadge = Color(0xFFEAEAEA);
  static const Color heroBadgeText = Color(0xFF2F3437);

  // --- Chart Colors (Flat, Muted) ---
  static const Color chartGreen = Color(0xFF346538);
  static const Color chartBlue = Color(0xFF1F6C9F);
  static const Color chartAmber = Color(0xFF956400);
  static const Color chartGray = Color(0xFF787774);
}
