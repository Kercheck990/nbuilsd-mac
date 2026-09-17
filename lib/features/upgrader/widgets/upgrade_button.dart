import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/upgrade_providers.dart';

class UpgradeButton extends StatelessWidget {
  final UpgradeStatus status;
  final bool canUpgrade;

  /// true, когда кнопка заблокирована именно из-за потолка в 75%.
  final bool blockedByLimit;
  final VoidCallback onPressed;

  const UpgradeButton({
    super.key,
    required this.status,
    required this.canUpgrade,
    required this.onPressed,
    this.blockedByLimit = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSpinning = status == UpgradeStatus.spinning;
    final l10n = context.l10n;
    final label = blockedByLimit
        ? l10n.t('upgrade_blocked_max')
        : switch (status) {
            UpgradeStatus.idle => l10n.t('upgrade_button'),
            UpgradeStatus.spinning => l10n.t('upgrade_spinning'),
            UpgradeStatus.success => l10n.t('upgrade_success'),
            UpgradeStatus.failure => l10n.t('upgrade_failure'),
          };
    final enabled = canUpgrade && !isSpinning;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: enabled
                ? [AppColors.accentYellowDark, AppColors.accentYellow]
                : [Colors.grey.shade700, Colors.grey.shade600],
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.accentYellow.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSpinning)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.black87,
                      ),
                    )
                  else
                    Icon(
                        blockedByLimit
                            ? Icons.lock_outline
                            : Icons.keyboard_double_arrow_up_rounded,
                        color: Colors.black87,
                        size: 20),
                  const SizedBox(width: 10),
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
    );
  }
}
