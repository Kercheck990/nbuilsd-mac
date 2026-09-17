import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

/// Круглая шкала шанса.
///
/// ГЛАВНОЕ ПРАВИЛО ЗАПОЛНЕНИЯ:
/// дуга заполняется РОВНО по проценту — 50% шанса = ровно половина
/// сектора, 75% = три четверти. Участок от 75% до 100% нарисован как
/// «запретная зона» (красная штриховка): апгрейд туда невозможен,
/// потолок задан в [AppConstants.maxChancePercent] = 75.
///
/// Во время прокрутки поверх шкалы бежит жёлтая точка — она
/// останавливается на позиции реального ролла, пришедшего с сервера.
/// Если точка встала внутри залитой части — победа.
class GaugeIndicator extends StatelessWidget {
  /// Текущий шанс 0..100 (уже с учётом потолка).
  final double chancePercent;

  /// Угол бегающей точки во время прокрутки (градусы).
  final double? spinAngleOverrideDeg;
  final bool isSpinning;
  final bool showBrandIcon;

  /// true, если связка ставка/цель даёт больше 75%: шкала подсвечивает
  /// запретную зону, кнопка апгрейда блокируется.
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

  /// Процент → угол на шкале. 0% — начало дуги, 100% — конец.
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

  /// Цвет полосы: чем выше шанс, тем зеленее.
  static Color bandColor(double percent) {
    final stops = AppColors.gaugeGradient; // [красный … зелёный]
    final t = (percent / 100).clamp(0.0, 1.0);
    final scaled = t * (stops.length - 1);
    final i = scaled.floor().clamp(0, stops.length - 2);
    return Color.lerp(stops[i], stops[i + 1], scaled - i)!;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = overMaxLimit ? AppColors.danger : bandColor(chancePercent);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Анимируем саму заливку, чтобы при смене ставки/цели дуга
          // плавно доезжала до нового процента.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: chancePercent.clamp(0, 100)),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, animatedPercent, _) {
              return CustomPaint(
                size: Size(size, size),
                painter: _GaugePainter(
                  fillPercent: animatedPercent,
                  spinAngleDeg: spinAngleOverrideDeg,
                  isDark: isDark,
                  isSpinning: isSpinning,
                  overMaxLimit: overMaxLimit,
                ),
              );
            },
          ),

          // Внутренний круг
          Container(
            width: size * 0.70,
            height: size * 0.70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.darkInnerCircle : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(isDark ? 0.18 : 0.10),
                  blurRadius: 30,
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.5 : 0.06),
                  blurRadius: 24,
                  spreadRadius: -6,
                ),
              ],
            ),
          ),

          if (showBrandIcon)
            Icon(
              Icons.keyboard_double_arrow_up_rounded,
              size: size * 0.26,
              color: AppColors.accentYellow.withOpacity(0.9),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: chancePercent),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Text(
                        '${value.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: size * 0.20,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: overMaxLimit
                              ? AppColors.danger
                              : (isDark ? Colors.white : AppColors.lightTextPrimary),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    overMaxLimit ? l10n.t('gauge_max') : l10n.t(bandKey(chancePercent)),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: size * 0.05,
                      fontWeight: FontWeight.w600,
                      color: color,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
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
    final radius = size.width / 2 - 22;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final startAngle = _deg2rad(AppConstants.gaugeStartAngleDeg);
    final fullSweep = _deg2rad(AppConstants.gaugeSweepAngleDeg);
    const strokeWidth = 18.0;

    // ---- 1. Фоновая дорожка (вся шкала 0..100%) --------------------
    canvas.drawArc(
      rect,
      startAngle,
      fullSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06),
    );

    // ---- 2. Запретная зона 75..100% --------------------------------
    final lockFraction = AppConstants.maxChancePercent / AppConstants.gaugeScaleMax;
    final lockStart = startAngle + fullSweep * lockFraction;
    final lockSweep = fullSweep * (1 - lockFraction);
    canvas.drawArc(
      rect,
      lockStart,
      lockSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = AppColors.danger.withOpacity(overMaxLimit ? 0.32 : 0.12),
    );
    _paintHatch(canvas, center, radius, lockStart, lockSweep, strokeWidth);

    // ---- 3. Заливка строго по проценту -----------------------------
    final fillFraction = (fillPercent / AppConstants.gaugeScaleMax).clamp(0.0, 1.0);
    if (fillFraction > 0.001) {
      final fillSweep = fullSweep * fillFraction;
      final shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + fullSweep,
        colors: AppColors.gaugeGradient,
        stops: const [0.0, 0.35, 0.65, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(rect);

      // Мягкое свечение под заливкой.
      canvas.drawArc(
        rect,
        startAngle,
        fillSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
          ..shader = shader,
      );
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

    // ---- 4. Засечка и подпись на отметке 75% -----------------------
    final limitAngle = startAngle + fullSweep * lockFraction;
    canvas.drawLine(
      Offset(center.dx + (radius - strokeWidth * 0.8) * math.cos(limitAngle),
          center.dy + (radius - strokeWidth * 0.8) * math.sin(limitAngle)),
      Offset(center.dx + (radius + strokeWidth * 0.7) * math.cos(limitAngle),
          center.dy + (radius + strokeWidth * 0.7) * math.sin(limitAngle)),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AppColors.danger.withOpacity(0.9),
    );
    _paintLabel(canvas, center, radius + 24, limitAngle, '75%');

    // ---- 5. Насечки по ободу ---------------------------------------
    final tickPaint = Paint()
      ..strokeWidth = 2
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.16);
    const tickCount = 20;
    for (var i = 0; i <= tickCount; i++) {
      final angle = startAngle + fullSweep * (i / tickCount);
      canvas.drawLine(
        Offset(center.dx + (radius + 12) * math.cos(angle),
            center.dy + (radius + 12) * math.sin(angle)),
        Offset(center.dx + (radius + 17) * math.cos(angle),
            center.dy + (radius + 17) * math.sin(angle)),
        tickPaint,
      );
    }

    // ---- 6. Маркер края заливки ------------------------------------
    final edgeAngle = startAngle + fullSweep * fillFraction;
    _paintDot(canvas, center, radius, edgeAngle,
        color: overMaxLimit ? AppColors.danger : Colors.white, r: 5.5, glow: 7);

    // ---- 7. Бегущая точка ролла ------------------------------------
    if (spinAngleDeg != null) {
      _paintDot(canvas, center, radius, _deg2rad(spinAngleDeg!),
          color: AppColors.accentYellow, r: isSpinning ? 7 : 6, glow: 12);
    }
  }

  void _paintDot(Canvas canvas, Offset center, double radius, double angle,
      {required Color color, required double r, required double glow}) {
    final pos = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    canvas.drawCircle(
      pos,
      r + 3,
      Paint()
        ..color = color.withOpacity(0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow),
    );
    canvas.drawCircle(pos, r, Paint()..color = color);
  }

  void _paintHatch(Canvas canvas, Offset center, double radius, double start,
      double sweep, double strokeWidth) {
    final paint = Paint()
      ..strokeWidth = 1.4
      ..color = AppColors.danger.withOpacity(overMaxLimit ? 0.55 : 0.22);
    const steps = 9;
    for (var i = 0; i <= steps; i++) {
      final a = start + sweep * (i / steps);
      canvas.drawLine(
        Offset(center.dx + (radius - strokeWidth / 2) * math.cos(a),
            center.dy + (radius - strokeWidth / 2) * math.sin(a)),
        Offset(center.dx + (radius + strokeWidth / 2) * math.cos(a),
            center.dy + (radius + strokeWidth / 2) * math.sin(a)),
        paint,
      );
    }
  }

  void _paintLabel(
      Canvas canvas, Offset center, double radius, double angle, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.danger.withOpacity(0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        center.dx + radius * math.cos(angle) - tp.width / 2,
        center.dy + radius * math.sin(angle) - tp.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) {
    return old.fillPercent != fillPercent ||
        old.spinAngleDeg != spinAngleDeg ||
        old.isDark != isDark ||
        old.isSpinning != isSpinning ||
        old.overMaxLimit != overMaxLimit;
  }
}
