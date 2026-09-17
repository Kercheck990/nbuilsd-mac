import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/balance_provider.dart';
import '../providers/upgrade_providers.dart';
import 'nft_item_card.dart';

/// "Выберите предметы и/или баланс для использования" panel.
class ItemPickerPanel extends ConsumerWidget {
  const ItemPickerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(upgradeSessionProvider);
    final sessionNotifier = ref.read(upgradeSessionProvider.notifier);
    final user = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _PanelShell(
      title: 'Select items and/or balance',
      subtitle: 'You can select multiple items',
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 148,
            child: session.stakedItems.isEmpty
                ? _EmptyPickerState(isDark: isDark)
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: session.stakedItems.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final item = session.stakedItems[i];
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          NftItemCard(
                            item: item,
                            selected: true,
                            width: 108,
                            onTap: () => sessionNotifier.toggleStakeItem(item),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: GestureDetector(
                              onTap: () => sessionNotifier.toggleStakeItem(item),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Switch(
                value: session.useBalance,
                activeColor: AppColors.accentYellow,
                onChanged: (v) => sessionNotifier.setUseBalance(
                  v,
                  amount: v ? (user.balanceCoins).clamp(0, user.balanceCoins) : 0,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(context.l10n.t('home_use_balance'),
                    style: const TextStyle(fontSize: 13)),
              ),
              Text(
                '${user.balanceCoins}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentYellow,
                ),
              ),
            ],
          ),
          if (session.useBalance) ...[
            Slider(
              value: session.balanceStakeAmount
                  .clamp(0, user.balanceCoins)
                  .toDouble(),
              min: 0,
              max: user.balanceCoins.toDouble().clamp(1, double.infinity),
              activeColor: AppColors.accentYellow,
              onChanged: (v) => sessionNotifier.setBalanceStakeAmount(v.round()),
            ),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.t('home_stake'),
                  style: const TextStyle(fontSize: 13)),
              Text(
                session.totalStakeValue.toStringAsFixed(0),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.accentYellow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyPickerState extends StatelessWidget {
  final bool isDark;
  const _EmptyPickerState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceAlt : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentYellow.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: 0.2,
        child: Icon(
          Icons.keyboard_double_arrow_up_rounded,
          size: 56,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}

class _PanelShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;
  final Widget child;

  const _PanelShell({
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
