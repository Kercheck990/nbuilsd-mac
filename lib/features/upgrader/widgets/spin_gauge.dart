import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import 'gauge_indicator.dart';

/// Обёртка над [GaugeIndicator] с анимацией прокрутки: several full rotations
/// with ease-out, then a small overshoot/bounce as it settles onto the
/// final angle that corresponds to the round's real outcome.
///
/// The caller supplies [targetAngleDeg] — the angle the pointer must land
/// on — which must be derived from the already-known [UpgradeResult],
/// never chosen independently by this widget.
class SpinGauge extends StatefulWidget {
  final double idleChancePercent;
  final bool showBrandIcon;
  final bool overMaxLimit;
  final double size;

  /// Pass a `GlobalKey<SpinGaugeState>` as this widget's `key:` (not a
  /// separate field) so callers can invoke `key.currentState?.spinTo(...)`.
  const SpinGauge({
    super.key,
    required this.idleChancePercent,
    this.showBrandIcon = false,
    this.overMaxLimit = false,
    this.size = 260,
  });

  @override
  State<SpinGauge> createState() => SpinGaugeState();
}

class SpinGaugeState extends State<SpinGauge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double? _currentAngle;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppConstants.spinDuration);
  }

  /// Runs the spin: [finalAngleDeg] is the resting angle that matches the
  /// server-provided outcome.
  Future<void> spinTo(double finalAngleDeg) async {
    final rand = Random();
    final rotations = AppConstants.spinFullRotationsMin +
        rand.nextInt(
            AppConstants.spinFullRotationsMax - AppConstants.spinFullRotationsMin + 1);

    final startAngle = _currentAngle ?? AppConstants.gaugeStartAngleDeg;
    // Overshoot a few degrees past the final resting point, then settle back.
    final overshoot = 4.0 + rand.nextDouble() * 2;
    final totalSweep = 360.0 * rotations + (finalAngleDeg - startAngle);

    setState(() => _spinning = true);

    final mainTween = Tween<double>(
      begin: startAngle,
      end: startAngle + totalSweep + overshoot,
    );
    final settleTween = Tween<double>(
      begin: startAngle + totalSweep + overshoot,
      end: startAngle + totalSweep,
    );

    _controller.reset();
    final anim = TweenSequence<double>([
      TweenSequenceItem(
        tween: mainTween.chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 85,
      ),
      TweenSequenceItem(
        tween: settleTween.chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
    ]).animate(_controller);

    void listener() {
      setState(() => _currentAngle = anim.value);
    }

    anim.addListener(listener);
    await _controller.forward();
    anim.removeListener(listener);

    _currentAngle = startAngle + totalSweep;
    setState(() => _spinning = false);
  }

  void resetIdle() {
    _controller.stop();
    setState(() {
      _currentAngle = null;
      _spinning = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GaugeIndicator(
      chancePercent: widget.idleChancePercent,
      spinAngleOverrideDeg: _currentAngle,
      isSpinning: _spinning,
      showBrandIcon: widget.showBrandIcon,
      overMaxLimit: widget.overMaxLimit,
      size: widget.size,
    );
  }
}
