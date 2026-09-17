import 'package:flutter/material.dart';

/// Central color palette for NFT-Grader.
/// Dark theme is the default brand look; light theme mirrors it with
/// inverted surfaces.
class AppColors {
  AppColors._();

  // Brand / accent
  static const Color accentYellow = Color(0xFFFFC107);
  static const Color accentYellowDeep = Color(0xFFF5A623);
  static const Color accentOrange = Color(0xFFFF7A00);
  static const Color accentYellowDark = Color(0xFF8A6D0A);

  // Brand green — главный цвет с макетов (белая + тёмная тема).
  // Светлая тема: глубокий зелёный, тёмная: неоновый.
  static const Color brandGreen = Color(0xFF22B14C);
  static const Color brandGreenDeep = Color(0xFF149A3E);
  static const Color brandNeon = Color(0xFF4DFF5C);
  static const Color brandLime = Color(0xFFA8FF00);
  static const Color brandGlow = Color(0xFF39FF5A);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);

  // Rarity
  static const Color rarityCommon = Color(0xFF9CA3AF);
  static const Color rarityRare = Color(0xFF3B82F6);
  static const Color rarityEpic = Color(0xFFA855F7);
  static const Color rarityLegendary = Color(0xFFF59E0B);

  // Dark theme surfaces
  static const Color darkBgTop = Color(0xFF070B08);
  static const Color darkBgBottom = Color(0xFF0D1510);
  static const Color darkSurface = Color(0xFF101814);
  static const Color darkSurfaceAlt = Color(0xFF151F19);
  static const Color darkCard = Color(0xFF0F1712);
  static const Color darkInnerCircle = Color(0xFF141417);
  static const Color darkBorder = Color(0x0FFFFFFF); // white 6%
  static const Color darkGreenBorder = Color(0xFF2BE34A);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextTertiary = Color(0xFF6B7280);

  // Light theme surfaces
  static const Color lightBgTop = Color(0xFFF3F6F1);
  static const Color lightBgBottom = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0x14000000);
  static const Color lightGreenBorder = Color(0xFF3EDB5A);
  static const Color lightTextPrimary = Color(0xFF111114);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  static Color rarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'rare':
        return rarityRare;
      case 'epic':
        return rarityEpic;
      case 'legendary':
        return rarityLegendary;
      case 'common':
      default:
        return rarityCommon;
    }
  }

  /// Градиент шкалы: начало дуги (0%) — красный, конец (100%) — зелёный.
  /// Порядок важен: шкала заливается от 0% по часовой стрелке, поэтому
  /// первый цвет = «низкий шанс».
  static const List<Color> gaugeGradient = [
    Color(0xFFEF4444), // красный  — 0%
    Color(0xFFFF7A00), // оранжевый
    Color(0xFFFFC107), // жёлтый
    Color(0xFF22C55E), // зелёный  — 100%
  ];

  /// Цвета «стеклянных» пятен на фоне экранов авторизации.
  static const Color glowViolet = Color(0xFF7C3AED);
  static const Color glowCyan = Color(0xFF06B6D4);
}
