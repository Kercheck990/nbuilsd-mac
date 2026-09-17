import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  int _shake = 0;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validate(AppLocalizations l10n) {
    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(_email.text.trim());
    final passOk = _password.text.length >= 8;
    setState(() {
      _emailError = emailOk ? null : l10n.t('auth_err_email');
      _passwordError = passOk ? null : l10n.t('auth_err_password');
    });
    if (!emailOk || !passOk) setState(() => _shake++);
    return emailOk && passOk;
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_validate(l10n)) return;
    final ok = await ref.read(authProvider.notifier).login(
          email: _email.text,
          password: _password.text,
        );
    if (!mounted) return;
    if (!ok) {
      setState(() => _shake++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authProvider);

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
                      const StaggerIn(index: 0, child: AuthLogo()),
                      const SizedBox(height: 28),
                      StaggerIn(
                        index: 1,
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.t('auth_welcome'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.t('auth_welcome_sub'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 24),
                              AuthField(
                                controller: _email,
                                label: l10n.t('auth_email'),
                                icon: Icons.alternate_email,
                                keyboardType: TextInputType.emailAddress,
                                errorText: _emailError,
                              ),
                              const SizedBox(height: 12),
                              AuthField(
                                controller: _password,
                                label: l10n.t('auth_password'),
                                icon: Icons.lock_outline,
                                obscure: true,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                errorText: _passwordError,
                              ),
                              if (auth.errorCode != null) ...[
                                const SizedBox(height: 12),
                                _ErrorBanner(text: l10n.t(auth.errorCode!)),
                              ],
                              const SizedBox(height: 20),
                              AuthButton(
                                label: l10n.t('auth_login'),
                                icon: Icons.login_rounded,
                                busy: auth.busy,
                                onPressed: _submit,
                              ),
                              const SizedBox(height: 14),
                              TextButton(
                                onPressed: () => context.go('/register'),
                                child: Text(
                                  l10n.t('auth_no_account'),
                                  style: const TextStyle(
                                      color: AppColors.accentYellow,
                                      fontWeight: FontWeight.w600),
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

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 17, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
