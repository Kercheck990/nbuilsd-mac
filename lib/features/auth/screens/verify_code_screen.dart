import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/top_notify.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/locale_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

/// Экран ввода 6-значного кода, который пришёл на почту.
/// Код живёт 10 минут (см. server/src/routes/auth.js), повторная
/// отправка доступна раз в 60 секунд.
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  String _code = '';
  int _shake = 0;
  int _resendIn = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendIn = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.length != 6) {
      setState(() => _shake++);
      return;
    }
    final ok = await ref.read(authProvider.notifier).verify(code: _code);
    if (!mounted) return;
    if (!ok) {
      setState(() => _shake++);
    }
  }

  Future<void> _resend() async {
    final locale = ref.read(localeProvider).languageCode;
    final ok = await ref.read(authProvider.notifier).resend(locale: locale);
    if (!mounted) return;
    _startTimer();
    TopNotify.show(context, context.l10n.t(ok ? 'verify_sent' : 'error_generic'), success: ok);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authProvider);
    final email = auth.pendingEmail ?? '';

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Shaker(
                  trigger: _shake,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const StaggerIn(index: 0, child: _MailIcon()),
                      const SizedBox(height: 24),
                      StaggerIn(
                        index: 1,
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.t('verify_title'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.f('verify_sub', {'email': email}),
                                textAlign: TextAlign.center,
                                style:
                                    const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 26),
                              OtpInput(
                                hasError: auth.errorCode == 'verify_err_code',
                                onChanged: (v) {
                                  _code = v;
                                  if (auth.errorCode != null) {
                                    ref.read(authProvider.notifier).clearError();
                                  }
                                },
                                onCompleted: (_) => _submit(),
                              ),
                              if (auth.errorCode != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  l10n.t(auth.errorCode!),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppColors.danger, fontSize: 13),
                                ),
                              ],
                              const SizedBox(height: 22),
                              AuthButton(
                                label: l10n.t('verify_button'),
                                icon: Icons.verified_outlined,
                                busy: auth.busy,
                                onPressed: _submit,
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _resendIn > 0 ? null : _resend,
                                child: Text(
                                  _resendIn > 0
                                      ? l10n.f('verify_resend_in',
                                          {'sec': '$_resendIn'})
                                      : l10n.t('verify_resend'),
                                  style: TextStyle(
                                    color: _resendIn > 0
                                        ? Colors.grey
                                        : AppColors.accentYellow,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    ref.read(authProvider.notifier).backToLogin(),
                                child: Text(
                                  l10n.t('back'),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Конверт, который слегка «дышит» — визуальный якорь экрана.
class _MailIcon extends StatefulWidget {
  const _MailIcon();

  @override
  State<_MailIcon> createState() => _MailIconState();
}

class _MailIconState extends State<_MailIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
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
        return Transform.translate(
          offset: Offset(0, -6 * _c.value),
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentYellow.withOpacity(0.14),
              border: Border.all(color: AppColors.accentYellow.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentYellow.withOpacity(0.25 + 0.2 * _c.value),
                  blurRadius: 24 + 16 * _c.value,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.mark_email_unread_outlined,
                size: 38, color: AppColors.accentYellow),
          ),
        );
      },
    );
  }
}
