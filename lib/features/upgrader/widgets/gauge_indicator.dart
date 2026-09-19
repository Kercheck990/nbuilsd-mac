import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

/// Полный круг 360° — честный индикатор шанса.
///
/// - Серый фон — полный круг (0..100%).
/// - Зелёный сектор от верха по часовой = шанс (max 75% => 270°).
/// - Оставшаяся дуга (25% = 90° внизу) — тёмная зона проигрыша.
/// - Стрелка strelka.png вращается снаружи и указывает на rollPercent.
///   Попала в зелёный — апгрейд, за зелёным — удаление NFT (сервер решает).
class GaugeIndicator extends StatelessWidget {
  final double chancePercent;
  final double? spinAngleOverrideDeg;
  final bool isSpinning;
  final bool showBrandIcon;
  final bool overMaxLimit;
  final double size;

  const GaugeIndicator({
    super.key,
    required this.chancePercent,
    this.spinAngleOverrideDeg,
    this.isSpinning = false,
    this.showBrandIcon = false,
    this.overMaxLimit = false,
    this.size = 260,
  });

  static double angleForPercent(double percent) {
    final p = (percent / AppConstants.gaugeScaleMax).clamp(0.0, 1.0);
    return AppConstants.gaugeStartAngleDeg + AppConstants.gaugeSweepAngleDeg * p;
  }

  static String bandKey(double percent) {
    if (percent < 10) return 'gauge_very_low';
    if (percent < 30) return 'gauge_low';
    if (percent < 60) return 'gauge_medium';
    return 'gauge_high';
  }

  static Color bandColor(double percent) {
    final stops = AppColors.gaugeGradient;
    final t = (percent / 100).clamp(0.0, 1.0);
    final scaled = t * (stops.length - 1);
    final i = scaled.floor().clamp(0, stops.length - 2);
    return Color.lerp(stops[i], stops[i + 1], scaled - i)!;
  }

  static Color get winZoneColor => const Color(0xFF2B7FFF);
  static Color get winZoneGlow => const Color(0xFF4D9FFF);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = overMaxLimit ? AppColors.danger : const Color(0xFF2B7FFF);
    final glowColor = overMaxLimit ? AppColors.danger : const Color(0xFF4D9FFF);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: chancePercent.clamp(0, 100)),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, animatedPercent, _) {
                return CustomPaint(
                  size: Size(size, size),
                  painter: _GaugePainter(
                    fillPercent: animatedPercent,
                    spinAngleDeg: null,
                    isDark: isDark,
                    isSpinning: isSpinning,
                    overMaxLimit: overMaxLimit,
                  ),
                );
              },
            ),
          ),
          // Внутренний круг — чёрный/тёмный с тонкой рамкой
          Container(
            width: size * 0.62,
            height: size * 0.62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
              border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.06), width: 1),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withOpacity(isDark ? 0.12 : 0.08),
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.45 : 0.06),
                  blurRadius: 20,
                  spreadRadius: -8,
                ),
              ],
            ),
          ),
          // Стрелка из assets/strelka.png — вращается по spinAngle (фикc бага: попадание в зелёное засчитывало проигрыш)
          if (spinAngleOverrideDeg != null)
            Positioned.fill(
              child: Transform.rotate(
                angle: (spinAngleOverrideDeg! + 90) * math.pi / 180,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: size * 0.015),
                    child: Image.asset(
                      'assets/strelka.png',
                      width: size * 0.11,
                      height: size * 0.11,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.accentYellow,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.accentYellow.withOpacity(0.6), blurRadius: 12)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (showBrandIcon)
            Icon(
              Icons.keyboard_double_arrow_up_rounded,
              size: size * 0.24,
              color: AppColors.accentYellow.withOpacity(0.9),
            )
          else
            // Центр: большой процент + подпись
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: chancePercent),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Text(
                      '${value.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: size * 0.15,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: overMaxLimit ? AppColors.danger : (isDark ? Colors.white : AppColors.lightTextPrimary),
                        decoration: TextDecoration.none,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 3),
                Text(
                  overMaxLimit ? l10n.t('gauge_max') : l10n.t(bandKey(chancePercent)),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: size * 0.042,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                    letterSpacing: 0.2,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.t('up_chance'),
                  style: TextStyle(
                    fontSize: size * 0.032,
                    fontWeight: FontWeight.w500,
                    color: (isDark ? Colors.white38 : const Color(0xFF8A94A6)),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fillPercent;
  final double? spinAngleDeg;
  final bool isDark;
  final bool isSpinning;
  final bool overMaxLimit;

  _GaugePainter({
    required this.fillPercent,
    required this.spinAngleDeg,
    required this.isDark,
    required this.isSpinning,
    required this.overMaxLimit,
  });

  static double _deg2rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final startAngle = _deg2rad(AppConstants.gaugeStartAngleDeg);
    final fullSweep = _deg2rad(AppConstants.gaugeSweepAngleDeg);
    const strokeWidth = 16.0;

    // ---- 1. Фон — полный круг тёмный ---------------------------
    canvas.drawArc(
      rect,
      startAngle,
      fullSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = (isDark ? const Color(0xFF1E2522) : const Color(0xFFE6EADF)),
    );

    // ---- 2. Синяя зона шанса — от верха по часовой (замена зелёного на синий) ------------
    final fillFraction = (fillPercent / AppConstants.gaugeScaleMax).clamp(0.0, 1.0);
    if (fillFraction > 0.001) {
      final fillSweep = fullSweep * fillFraction;
      final shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + fillSweep,
        colors: overMaxLimit
            ? [AppColors.danger, AppColors.danger.withOpacity(0.9)]
            : isDark
                ? [const Color(0xFF1A5CFF), const Color(0xFF4D9FFF)]
                : [const Color(0xFF2B7FFF), const Color(0xFF1A5CFF)],
        stops: const [0.0, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(rect);

      // Убрали тяжёлый blur для перфоманса (был MaskFilter 10)
      canvas.drawArc(
        rect,
        startAngle,
        fillSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..shader = shader,
      );
    }

    // ---- 3. Индикатор 75% — тонкая красная засечка --------------
    final lockFraction = AppConstants.maxChancePercent / AppConstants.gaugeScaleMax;
    final limitAngle = startAngle + fullSweep * lockFraction;
    canvas.drawLine(
      Offset(center.dx + (radius - strokeWidth * 0.55) * math.cos(limitAngle),
          center.dy + (radius - strokeWidth * 0.55) * math.sin(limitAngle)),
      Offset(center.dx + (radius + strokeWidth * 0.55) * math.cos(limitAngle),
          center.dy + (radius + strokeWidth * 0.55) * math.sin(limitAngle)),
      Paint()
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = AppColors.danger.withOpacity(0.9),
    );

    // Подпись 75% чуть снаружи
    _paintLabel(canvas, center, radius + 18, limitAngle, '75%', AppColors.danger);

    // ---- 4. Метки процентов по кругу — 0,25,50,75,100 ------------
    final percentMarks = [0, 25, 50, 75, 100];
    for (final p in percentMarks) {
      if (p == 75) continue; // уже нарисовали
      final ang = startAngle + fullSweep * (p / 100);
      _paintLabel(canvas, center, radius + 14, ang, '$p%', (isDark ? Colors.white38 : const Color(0xFF8A94A6)));
    }

    // ---- 5. Мелкие насечки — лёгкие, 40 штук ----------------------
    final tickPaint = Paint()
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.08);
    const tickCount = 40;
    for (var i = 0; i < tickCount; i++) {
      final angle = startAngle + fullSweep * (i / tickCount);
      // пропускаем крупные метки
      if (i % 10 == 0) continue;
      final len = 3.0;
      final off = 11.0;
      canvas.drawLine(
        Offset(center.dx + (radius + off) * math.cos(angle), center.dy + (radius + off) * math.sin(angle)),
        Offset(center.dx + (radius + off + len) * math.cos(angle), center.dy + (radius + off + len) * math.sin(angle)),
        tickPaint,
      );
    }
    // Крупные насечки на 0,25,50,75,100
    final majorPaint = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.14);
    for (final p in percentMarks) {
      final ang = startAngle + fullSweep * (p / 100);
      canvas.drawLine(
        Offset(center.dx + (radius + 10) * math.cos(ang), center.dy + (radius + 10) * math.sin(ang)),
        Offset(center.dx + (radius + 15) * math.cos(ang), center.dy + (radius + 15) * math.sin(ang)),
        majorPaint,
      );
    }

    // ---- 6. Точка на краю синей зоны — без blur для перфоманса ---
    if (fillFraction > 0.001 && fillFraction < 0.999) {
      final edgeAngle = startAngle + fullSweep * fillFraction;
      _paintDot(canvas, center, radius, edgeAngle,
          color: overMaxLimit ? AppColors.danger : const Color(0xFF4D9FFF), r: 4.5);
    }
  }

  void _paintDot(Canvas canvas, Offset center, double radius, double angle,
      {required Color color, required double r}) {
    final pos = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
    // без blur — быстрее
    canvas.drawCircle(pos, r + 2, Paint()..color = color.withOpacity(0.25));
    canvas.drawCircle(pos, r, Paint()..color = color);
    canvas.drawCircle(pos, r - 2, Paint()..color = Colors.white.withOpacity(0.9));
  }

  void _paintLabel(Canvas canvas, Offset center, double radius, double angle, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, decoration: TextDecoration.none),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx + radius * math.cos(angle) - tp.width / 2, center.dy + radius * math.sin(angle) - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) {
    return old.fillPercent != fillPercent ||
        old.isDark != isDark ||
        old.overMaxLimit != overMaxLimit;
  }
}
