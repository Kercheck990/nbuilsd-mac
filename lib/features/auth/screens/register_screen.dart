import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/locale_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nickname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();

  String? _nickErr, _emailErr, _passErr, _pass2Err;
  bool _ageConfirmed = false;
  bool _ageError = false;
  int _shake = 0;

  @override
  void dispose() {
    _nickname.dispose();
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  bool _validate(AppLocalizations l10n) {
    final nick = _nickname.text.trim();
    final nickOk = nick.length >= 3 && nick.length <= 20;
    final emailOk =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(_email.text.trim());
    final passOk = _password.text.length >= 8;
    final matchOk = _password.text == _password2.text;

    setState(() {
      _nickErr = nickOk ? null : l10n.t('auth_err_nickname');
      _emailErr = emailOk ? null : l10n.t('auth_err_email');
      _passErr = passOk ? null : l10n.t('auth_err_password');
      _pass2Err = matchOk ? null : l10n.t('auth_err_password_match');
      _ageError = !_ageConfirmed;
    });

    final ok = nickOk && emailOk && passOk && matchOk && _ageConfirmed;
    if (!ok) setState(() => _shake++);
    return ok;
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_validate(l10n)) return;
    final locale = ref.read(localeProvider).languageCode;
    final ok = await ref.read(authProvider.notifier).register(
          email: _email.text,
          password: _password.text,
          nickname: _nickname.text,
          locale: locale,
        );
    if (!mounted) return;
    if (!ok) setState(() => _shake++);
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
                      const SizedBox(height: 24),
                      StaggerIn(
                        index: 1,
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.t('auth_register_title'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 23, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.t('auth_register_sub'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 22),
                              AuthField(
                                controller: _nickname,
                                label: l10n.t('auth_nickname'),
                                icon: Icons.person_outline,
                                errorText: _nickErr,
                              ),
                              const SizedBox(height: 12),
                              AuthField(
                                controller: _email,
                                label: l10n.t('auth_email'),
                                icon: Icons.alternate_email,
                                keyboardType: TextInputType.emailAddress,
                                errorText: _emailErr,
                              ),
                              const SizedBox(height: 12),
                              AuthField(
                                controller: _password,
                                label: l10n.t('auth_password'),
                                icon: Icons.lock_outline,
                                obscure: true,
                                errorText: _passErr,
                              ),
                              const SizedBox(height: 12),
                              AuthField(
                                controller: _password2,
                                label: l10n.t('auth_password_repeat'),
                                icon: Icons.lock_reset_outlined,
                                obscure: true,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                errorText: _pass2Err,
                              ),
                              const SizedBox(height: 14),
                              _AgeCheckbox(
                                value: _ageConfirmed,
                                error: _ageError,
                                label: l10n.t('auth_age_confirm'),
                                errorLabel: l10n.t('auth_age_required'),
                                onChanged: (v) => setState(() {
                                  _ageConfirmed = v;
                                  if (v) _ageError = false;
                                }),
                              ),
                              if (auth.errorCode != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppColors.danger.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    l10n.t(auth.errorCode!),
                                    style: const TextStyle(
                                        color: AppColors.danger, fontSize: 13),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              AuthButton(
                                label: l10n.t('auth_register'),
                                icon: Icons.auto_awesome,
                                busy: auth.busy,
                                onPressed: _submit,
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => context.go('/login'),
                                child: Text(
                                  l10n.t('auth_have_account'),
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

/// Подтверждение 18+. Без него регистрация не проходит — это минимальный
/// возрастной барьер, а не полноценная верификация возраста.
class _AgeCheckbox extends StatelessWidget {
  final bool value;
  final bool error;
  final String label;
  final String errorLabel;
  final ValueChanged<bool> onChanged;

  const _AgeCheckbox({
    required this.value,
    required this.error,
    required this.label,
    required this.errorLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? AppColors.accentYellow : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: error
                          ? AppColors.danger
                          : (value ? AppColors.accentYellow : Colors.grey),
                      width: 1.5,
                    ),
                  ),
                  child: value
                      ? const Icon(Icons.check, size: 16, color: Colors.black87)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
        if (error)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 2),
            child: Text(errorLabel,
                style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ),
      ],
    );
  }
}
