import 'package:flutter/material.dart';

class AppColors {
  // --- Core Palette (Warm Monochrome) ---
  static const Color primary = Color(0xFF111111); // Charcoal
  static const Color secondary = Color(0xFF2F3437); // Dark Gray
  static const Color accent = Color(0xFFF7F6F3); // Warm Bone

  // --- Backgrounds ---
  static const Color backgroundColor = Color(0xFFFBFBFA); // Warm White
  static const Color cardWhite = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceGray = Color(0xFFF9F9F8); // Light Surface

  // --- Text ---
  static const Color textDark = Color(0xFF111111); // Off-Black
  static const Color textSecondary = Color(0xFF787774); // Muted Gray
  static const Color textMuted = Color(0xFFA8A8A6); // Lighter Gray

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
      color: Colors.black.withValues(alpha: 0.02),
      blurRadius: 8,
      offset: const Offset(0, 2),
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
