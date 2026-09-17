import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../providers/upgrade_providers.dart';
import 'nft_item_card.dart';

/// "Выберите предмет для апгрейда" panel.
class TargetItemPanel extends ConsumerWidget {
  const TargetItemPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(upgradeSessionProvider);
    final sessionNotifier = ref.read(upgradeSessionProvider.notifier);
    final catalog = ref.watch(catalogProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          Text(context.l10n.t('home_upgrade_to'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 15)),
          const SizedBox(height: 2),
          Text(context.l10n.t('home_select_target'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
          const SizedBox(height: 14),
          SizedBox(
            height: 148,
            child: session.targetItem == null
                ? GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 1,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: catalog.length.clamp(0, 6),
                    itemBuilder: (context, i) {
                      final item = catalog[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: NftItemCard(
                          item: item,
                          width: 108,
                          onTap: () => sessionNotifier.setTargetItem(item),
                        ),
                      );
                    },
                  )
                : Center(
                    child: NftItemCard(
                      item: session.targetItem!,
                      selected: true,
                      width: 128,
                      onTap: () => sessionNotifier.setTargetItem(session.targetItem!),
                    ),
                  ),
          ),
          if (session.targetItem != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: sessionNotifier.clearTargetItem,
                child: Text(context.l10n.t('home_change')),
              ),
            ),
        ],
      ),
    );
  }
}
