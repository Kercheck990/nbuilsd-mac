import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Логотип приложения.
///
/// 1. Пробует `assets/nftgradelogo.png` (основной файл).
/// 2. Запасной — старый `assets/logonftgrade.png`.
/// 3. Если нет обоих — жёлтый бейдж со стрелками.
/// Приложение не падает ни в одном случае.
class AppLogo extends StatelessWidget {
  /// Основной путь к файлу логотипа в assets.
  static const String assetPath = 'assets/nftgradelogo.png';

  /// Старый файл — запасной вариант.
  static const String legacyAssetPath = 'assets/logonftgrade.png';

  final double size;
  final bool withGlow;

  const AppLogo({super.key, this.size = 76, this.withGlow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: withGlow
            ? [
                BoxShadow(
                  color: AppColors.accentYellow.withOpacity(0.45),
                  blurRadius: size * 0.35,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ClipOval(
            child: Image.asset(
              legacyAssetPath,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackBadge(),
            ),
          ),
        ),
      ),
    );
  }

  /// Запасной бейдж — показывается, пока файл логотипа не добавлен.
  Widget _fallbackBadge() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.accentYellowDeep, AppColors.accentYellow],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.keyboard_double_arrow_up_rounded,
        size: size * 0.52,
        color: Colors.black87,
      ),
    );
  }
}
