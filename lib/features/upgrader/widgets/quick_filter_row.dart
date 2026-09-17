import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/upgrade_providers.dart';

class QuickFilterRow extends ConsumerWidget {
  const QuickFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(upgradeSessionProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final m in AppConstants.quickMultipliers) ...[
            _Pill(
              label: 'x${m.toStringAsFixed(0)}',
              onTap: () => notifier.applyQuickMultiplier(m),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            height: 20,
            width: 1,
            color: AppColors.darkBorder,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          const SizedBox(width: 8),
          for (final c in AppConstants.quickChancePercents) ...[
            _Pill(
              label: '${c.toStringAsFixed(0)}%',
              accent: true,
              onTap: () => notifier.applyQuickChance(c),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool accent;

  const _Pill({required this.label, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.accentYellow.withOpacity(0.12)
              : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accent
                ? AppColors.accentYellow.withOpacity(0.4)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: accent ? AppColors.accentYellow : null,
          ),
        ),
      ),
    );
  }
}
