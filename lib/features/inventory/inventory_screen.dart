import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/top_notify.dart';
import '../../data/models/nft_item.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../providers/balance_provider.dart';
import '../../services/api_client.dart';
import '../upgrader/widgets/nft_item_card.dart';

enum InventorySort { priceDesc, priceAsc, newest }

/// Инвентарь игрока в стиле макетов: шапка с пилюлей и кнопкой рюкзака,
/// highlighted-сумма, зелёные фильтры, stagger-анимация сетки.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  InventorySort _sort = InventorySort.priceDesc;
  NftRarity? _rarityFilter;
  bool _selling = false;
  bool _sellingAll = false;

  List<NftItem> _apply(List<NftItem> items) {
    var list = _rarityFilter == null
        ? [...items]
        : items.where((i) => i.rarity == _rarityFilter).toList();
    switch (_sort) {
      case InventorySort.priceDesc:
        list.sort((a, b) => b.priceInCoins.compareTo(a.priceInCoins));
        break;
      case InventorySort.priceAsc:
        list.sort((a, b) => a.priceInCoins.compareTo(b.priceInCoins));
        break;
      case InventorySort.newest:
        list = list.reversed.toList();
        break;
    }
    return list;
  }

  Future<void> _toggleStar(NftItem item) async {
    try {
      await ApiClient.instance.starItem(item.id, !item.isStarred);
      await ref.read(inventoryProvider.notifier).refresh();
    } catch (_) {
      if (!mounted) return;
      TopNotify.show(context, context.l10n.t('error_network'), success: false);
    }
  }

  Future<void> _sellAll() async {
    if (_sellingAll) return;
    final all = ref.read(inventoryProvider);
    final toSell = all.where((e) => !e.isStarred).toList();
    if (toSell.isEmpty) {
      TopNotify.show(context, 'Нет предметов для продажи (все со ⭐)', success: false);
      return;
    }
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Продать все?'),
        content: Text('Продать ${toSell.length} предметов без ⭐ за ${toSell.fold<int>(0, (s, i) => s + i.priceInCoins)} NC?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Продать все')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _sellingAll = true);
    try {
      final res = await ApiClient.instance.sellAll();
      final nc = res['balance_nc'] as int? ?? res['balance'] as int? ?? 0;
      ref.read(userProvider.notifier).setNc(nc);
      await ref.read(inventoryProvider.notifier).refresh();
      if (!mounted) return;
      TopNotify.show(context, 'Продано ${res['sold']} за ${res['gained']} NC', success: true);
    } catch (_) {
      if (!mounted) return;
      TopNotify.show(context, l10n.t('error_network'), success: false);
    } finally {
      if (mounted) setState(() => _sellingAll = false);
    }
  }

  Future<void> _showOptions(NftItem item) async {
    final l10n = context.l10n;
    // Проверяем витрину чтобы понять уже повешена или нет
    bool inShowcase = false;
    try {
      final sc = await ApiClient.instance.getShowcase();
      final list = (sc['showcase'] as List?) ?? const [];
      inShowcase = list.any((e) => (e as Map)['inventory_id'].toString() == item.id);
    } catch (_) {}
    if (!mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF121A14) : Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.sell_outlined), title: Text(l10n.t('inventory_sell')), onTap: () => Navigator.pop(ctx, 'sell')),
          ListTile(leading: Icon(inShowcase ? Icons.visibility_off_outlined : Icons.visibility_rounded), title: Text(inShowcase ? 'Убрать с профиля' : 'Повесить на профиль'), onTap: () => Navigator.pop(ctx, inShowcase ? 'unshow' : 'show')),
          ListTile(leading: Icon(item.isStarred ? Icons.star_rounded : Icons.star_border_rounded, color: item.isStarred ? const Color(0xFFFFC107) : null), title: Text(item.isStarred ? 'Снять ⭐' : 'Поставить ⭐'), onTap: () => Navigator.pop(ctx, 'star')),
          const Divider(height: 8),
          ListTile(leading: const Icon(Icons.close_rounded), title: Text(l10n.t('cancel')), onTap: () => Navigator.pop(ctx, 'cancel')),
        ]),
      ),
    );
    if (!mounted || action == null || action == 'cancel') return;
    if (action == 'sell') {
      await _sell(item);
    } else if (action == 'star') {
      await _toggleStar(item);
    } else if (action == 'show' || action == 'unshow') {
      await _toggleShowcase(item, inShowcase);
    }
  }

  Future<void> _toggleShowcase(NftItem item, bool wasIn) async {
    try {
      final sc = await ApiClient.instance.getShowcase();
      final list = ((sc['showcase'] as List?) ?? const []).map((e) => (e as Map)['inventory_id'].toString()).toList();
      List<String> newIds;
      if (wasIn) {
        newIds = list.where((id) => id != item.id).toList();
      } else {
        if (list.length >= 6) {
          if (!mounted) return;
          TopNotify.show(context, 'На профиле максимум 6 NFT', success: false);
          return;
        }
        newIds = [...list, item.id];
      }
      await ApiClient.instance.setShowcase(newIds);
      if (!mounted) return;
      TopNotify.show(context, wasIn ? 'Убрано с профиля' : 'Повешено на профиль ✅', success: true);
    } on ApiException catch (e) {
      if (mounted) TopNotify.show(context, e.message, success: false);
    } catch (e) {
      if (mounted) TopNotify.show(context, 'Ошибка: $e', success: false);
    }
  }

  Future<void> _sell(NftItem item) async {
    if (_selling) return;
    if (item.isStarred) {
      TopNotify.show(context, 'Снимите ⭐ чтобы продать', success: false);
      return;
    }
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.t('inventory_sell')),
        content: Text(l10n.f('inventory_sell_confirm', {
          'name': item.name,
          'price': '${item.priceInCoins}',
        })),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.t('inventory_sell')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _selling = true);
    try {
      final ncBalance = await ApiClient.instance.sellItem(item.id);
      ref.read(userProvider.notifier).setNc(ncBalance);
      await ref.read(inventoryProvider.notifier).refresh();
      if (!mounted) return;
      TopNotify.show(context, 'Продано за ${item.priceInCoins} NC', success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'starred' ? 'Снимите ⭐ чтобы продать' : e.code == 'too_many_requests' ? 'Подожди секунду' : l10n.t('error_network');
      TopNotify.show(context, msg, success: false);
    } finally {
      if (mounted) setState(() => _selling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all = ref.watch(inventoryProvider);
    final items = _apply(all);
    final total = all.fold<int>(0, (s, i) => s + i.priceInCoins);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(
                  title: l10n.t('inventory_title'),
                  subtitle: l10n.f('inv_sub',
                      {'total': '$total', 'n': '${all.length}'}),
                  showBack: true,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: EntranceAnim(
                    index: 0,
                    child: BrandCard(
                      highlighted: true,
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: green.withOpacity(0.13),
                            ),
                            alignment: Alignment.center,
                            child: Text('🎒',
                                style: TextStyle(
                                  fontSize: 24,
                                  shadows: [
                                    Shadow(
                                        color: green.withOpacity(0.6),
                                        blurRadius: 12)
                                  ],
                                )),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.t('inventory_total_value'),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.monetization_on,
                                        size: 18, color: green),
                                    const SizedBox(width: 5),
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(
                                          begin: 0,
                                          end: total.toDouble()),
                                      duration: const Duration(
                                          milliseconds: 600),
                                      curve: Curves.easeOut,
                                      builder: (context, v, _) => Text(
                                        v.toStringAsFixed(0),
                                        style: const TextStyle(
                                            fontSize: 21,
                                            fontWeight:
                                                FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: (all.isEmpty || _sellingAll) ? null : _sellAll,
                            style: TextButton.styleFrom(
                              backgroundColor: green.withOpacity(0.12),
                              foregroundColor: green,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                            ),
                            child: const Text('Продать все', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<InventorySort>(
                            icon: Icon(Icons.sort_rounded,
                                color: green),
                            tooltip: l10n.t('inventory_sort'),
                            onSelected: (v) =>
                                setState(() => _sort = v),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: InventorySort.priceDesc,
                                child: Text(l10n.t(
                                    'inventory_sort_price_desc')),
                              ),
                              PopupMenuItem(
                                value: InventorySort.priceAsc,
                                child: Text(l10n.t(
                                    'inventory_sort_price_asc')),
                              ),
                              PopupMenuItem(
                                value: InventorySort.newest,
                                child: Text(l10n.t(
                                    'inventory_sort_newest')),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(
                                  isDark ? 0.3 : 0.05),
                              borderRadius:
                                  BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${all.length} ${l10n.t('inventory_items')}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: _RarityFilter(
                    selected: _rarityFilter,
                    onSelected: (r) =>
                        setState(() => _rarityFilter = r),
                  ),
                ),
              ),
              if (items.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  sliver: SliverToBoxAdapter(
                    child: BrandCard(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            const Text('🎁',
                                style: TextStyle(fontSize: 46)),
                            const SizedBox(height: 12),
                            Text(
                              l10n.t('inventory_empty'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final item = items[i];
                        return EntranceAnim(
                          index: i % 8,
                          child: Column(
                            children: [
                              Expanded(
                                child: NftItemCard(
                                  item: item,
                                  width: double.infinity,
                                  showStar: true,
                                  onStarToggle: () => _toggleStar(item),
                                  onTap: () => _showOptions(item),
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 26,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                  ),
                                  onPressed: () => _showOptions(item),
                                  child: Text(
                                    l10n.t('inventory_sell'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: green,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: items.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 160,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.60,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RarityFilter extends StatelessWidget {
  final NftRarity? selected;
  final ValueChanged<NftRarity?> onSelected;

  const _RarityFilter({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          _chip(context, null, l10n.t('inventory_filter_all'), isDark),
          for (final r in NftRarity.values)
            _chip(context, r, r.label, isDark),
        ],
      ),
    );
  }

  Widget _chip(
      BuildContext context, NftRarity? value, String label, bool isDark) {
    final isSel = selected == value;
    final color = value == null
        ? (isDark ? AppColors.brandNeon : AppColors.brandGreenDeep)
        : AppColors.rarityColor(value.name);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onSelected(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: isSel ? color.withOpacity(0.16) : null,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSel ? color : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSel ? color : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
