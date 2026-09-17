import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_logo.dart';

// =====================================================================
// ФОН
// =====================================================================

/// Живой фон экранов авторизации: три размытых цветных пятна, которые
/// медленно дрейфуют по орбитам, плюс мерцающие частицы поверх.
/// Всё рисуется одним CustomPaint — дешевле, чем десяток виджетов.
class AuthBackground extends StatefulWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground>
    with TickerProviderStateMixin {
  late final AnimationController _orbs = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  late final AnimationController _particles = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  @override
  void dispose() {
    _orbs.dispose();
    _particles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF07070A), Color(0xFF12121A), Color(0xFF0A0A0F)]
                    : const [Color(0xFFF7F8FC), Color(0xFFEFF1F8), Color(0xFFFFFFFF)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _orbs,
            builder: (context, _) => CustomPaint(
              painter: _OrbsPainter(t: _orbs.value, isDark: isDark),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _particles,
              builder: (context, _) => CustomPaint(
                painter: _ParticlesPainter(t: _particles.value, isDark: isDark),
              ),
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _OrbsPainter extends CustomPainter {
  final double t;
  final bool isDark;
  _OrbsPainter({required this.t, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = isDark ? 0.30 : 0.16;
    final orbs = [
      (AppColors.accentYellow, 0.0, 0.62),
      (AppColors.glowViolet, 0.35, 0.72),
      (AppColors.glowCyan, 0.7, 0.55),
    ];
    for (final (color, phase, radiusFactor) in orbs) {
      final angle = (t + phase) * 2 * math.pi;
      final cx = size.width * (0.5 + 0.34 * math.cos(angle));
      final cy = size.height * (0.34 + 0.24 * math.sin(angle * 1.3));
      final r = size.width * radiusFactor * 0.5;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = color.withOpacity(opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbsPainter old) => old.t != t || old.isDark != isDark;
}

class _ParticlesPainter extends CustomPainter {
  final double t;
  final bool isDark;
  _ParticlesPainter({required this.t, required this.isDark});

  static final _rng = math.Random(7); // фиксированный сид = стабильный узор
  static final List<Offset> _seeds =
      List.generate(34, (_) => Offset(_rng.nextDouble(), _rng.nextDouble()));

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(isDark ? 0.5 : 0.35);
    for (var i = 0; i < _seeds.length; i++) {
      final s = _seeds[i];
      // Медленный дрейф вверх + лёгкое покачивание вбок.
      final y = (s.dy - t * (0.25 + (i % 5) * 0.05)) % 1.0;
      final x = s.dx + 0.02 * math.sin((t * 2 * math.pi) + i);
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 6 * math.pi + i));
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        (0.8 + (i % 3) * 0.7),
        paint..color = paint.color.withOpacity((isDark ? 0.45 : 0.3) * twinkle),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) => old.t != t;
}

// =====================================================================
// СТЕКЛЯННАЯ КАРТОЧКА
// =====================================================================

/// Полупрозрачная карточка с размытием фона и мягкой рамкой.
/// Появляется с плавным подъёмом и масштабом.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.white).withOpacity(isDark ? 0.06 : 0.72),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(isDark ? 0.12 : 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.45 : 0.08),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Поочерёдное появление элементов формы: каждый следующий выезжает
/// снизу с задержкой, за счёт чего форма «собирается» на глазах.
class StaggerIn extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration base;

  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.base = const Duration(milliseconds: 90),
  });

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.base * widget.index, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// =====================================================================
// ПОЛЯ ВВОДА
// =====================================================================

/// Поле ввода с подсветкой рамки при фокусе и встроенной ошибкой.
class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final String? errorText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? formatters;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.formatters,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final FocusNode _focus = FocusNode();
  bool _hidden = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final hasError = widget.errorText != null;
    final accent =
        hasError ? AppColors.danger : (focused ? AppColors.accentYellow : Colors.grey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withOpacity(focused || hasError ? 0.9 : 0.25),
              width: focused || hasError ? 1.5 : 1,
            ),
            boxShadow: focused && !hasError
                ? [
                    BoxShadow(
                      color: AppColors.accentYellow.withOpacity(0.22),
                      blurRadius: 18,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscure && _hidden,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            inputFormatters: widget.formatters,
            onSubmitted: widget.onSubmitted,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: TextStyle(color: focused ? accent : Colors.grey),
              prefixIcon: Icon(widget.icon, size: 20, color: accent),
              suffixIcon: widget.obscure
                  ? IconButton(
                      icon: Icon(
                        _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 19,
                      ),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    )
                  : null,
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(left: 6, top: 6),
                  child: Text(
                    widget.errorText!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Главная кнопка формы: градиент, свечение и спиннер вместо текста,
/// пока идёт запрос.
class AuthButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final IconData? icon;

  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.6,
        duration: const Duration(milliseconds: 200),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [AppColors.accentYellowDeep, AppColors.accentYellow],
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.accentYellow.withOpacity(0.38),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: enabled ? onPressed : null,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.black87),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 19, color: Colors.black87),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// ВВОД КОДА ИЗ ПИСЬМА
// =====================================================================

/// Шесть отдельных ячеек для 6-значного кода. Под капотом одно скрытое
/// текстовое поле — так работает вставка кода из буфера и автозаполнение
/// из SMS/почты, а ячейки просто отрисовывают его символы.
class OtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;

  const OtpInput({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
    this.hasError = false,
  });

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    widget.onChanged(value);
    if (value.length == widget.length) {
      HapticFeedback.lightImpact();
      widget.onCompleted?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    return Stack(
      children: [
        // Скрытое реальное поле.
        Opacity(
          opacity: 0,
          child: SizedBox(
            height: 1,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              maxLength: widget.length,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onChanged,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _focus.requestFocus(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (i) {
              final filled = i < text.length;
              final active = i == text.length && _focus.hasFocus;
              final color = widget.hasError
                  ? AppColors.danger
                  : (active || filled ? AppColors.accentYellow : Colors.grey);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 46,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withOpacity(active || filled || widget.hasError ? 0.95 : 0.25),
                    width: active ? 2 : 1.2,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.accentYellow.withOpacity(0.25),
                            blurRadius: 16,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Text(
                    filled ? text[i] : '',
                    key: ValueKey(filled ? text[i] : 'empty$i'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// Небольшая тряска — используем при неверном коде или логине.
class Shaker extends StatefulWidget {
  final Widget child;
  final int trigger;

  const Shaker({super.key, required this.child, required this.trigger});

  @override
  State<Shaker> createState() => _ShakerState();
}

class _ShakerState extends State<Shaker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(covariant Shaker old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) {
      _c.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final dx = math.sin(_c.value * math.pi * 6) * 10 * (1 - _c.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// Логотип с пульсирующим свечением — шапка экранов авторизации.
class AuthLogo extends StatefulWidget {
  const AuthLogo({super.key});

  @override
  State<AuthLogo> createState() => _AuthLogoState();
}

class _AuthLogoState extends State<AuthLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final glow = 18 + _c.value * 22;
        return Column(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentYellow.withOpacity(0.45),
                    blurRadius: glow,
                    spreadRadius: 2,
                  ),
                ],
              ),
              // Логотип из assets/logonftgrade.png (с запасным бейджем,
              // если файл ещё не добавлен). Сам AppLogo свечение не
              // рисует — пульс задаётся здесь.
              child: const AppLogo(size: 76, withGlow: false),
            ),
            const SizedBox(height: 14),
            const Text(
              'NFT-GRADER',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
          ],
        );
      },
    );
  }
}
