import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

/// Второй шаг входа: 6-значный 2FA-код из письма.
class TfaScreen extends ConsumerStatefulWidget {
  const TfaScreen({super.key});

  @override
  ConsumerState<TfaScreen> createState() => _TfaScreenState();
}

class _TfaScreenState extends ConsumerState<TfaScreen> {
  String _code = '';
  int _shake = 0;

  Future<void> _submit() async {
    if (_code.length != 6) {
      setState(() => _shake++);
      return;
    }
    final email = ref.read(authProvider).pendingEmail ?? '';
    final ok = await ref
        .read(authProvider.notifier)
        .verifyTfa(email: email, code: _code);
    if (!mounted) return;
    if (!ok) setState(() => _shake++);
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
                      StaggerIn(
                        index: 1,
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Icon(Icons.shield_outlined,
                                  size: 44,
                                  color: AppColors.accentYellow),
                              const SizedBox(height: 12),
                              Text(
                                l10n.t('tfa_title'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.f('tfa_sub', {'email': email}),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 26),
                              OtpInput(
                                hasError:
                                    auth.errorCode == 'verify_err_code',
                                onChanged: (v) {
                                  _code = v;
                                  if (auth.errorCode != null) {
                                    ref
                                        .read(authProvider.notifier)
                                        .clearError();
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
                                      color: AppColors.danger,
                                      fontSize: 13),
                                ),
                              ],
                              const SizedBox(height: 22),
                              AuthButton(
                                label: l10n.t('tfa_button'),
                                icon: Icons.verified_outlined,
                                busy: auth.busy,
                                onPressed: _submit,
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: () => ref
                                    .read(authProvider.notifier)
                                    .backToLogin(),
                                child: Text(
                                  l10n.t('back'),
                                  style: const TextStyle(
                                      color: Colors.grey),
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
