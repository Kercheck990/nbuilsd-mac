import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/top_notify.dart';
import '../../data/models/nft_item.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../providers/balance_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/api_client.dart';
import '../upgrader/widgets/nft_item_card.dart';

/// Магазин в стиле макета: сверху highlighted-карточка с NFT-сумкой,
/// ниже сетка товаров с покупкой за монеты и продажей своих предметов.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 1));
  String _tab = 'all'; // all | cases | gifts
  String? _justBoughtId;

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  List<NftItem> _filtered(List<NftItem> catalog) {
    if (_tab == 'cases') {
      return catalog.where((e) => e.priceInCoins < 500).toList();
    }
    if (_tab == 'gifts') {
      return catalog.where((e) => e.priceInCoins >= 500).toList();
    }
    return catalog;
  }

  Future<void> _buy(NftItem item) async {
    final l10n = context.l10n;
    final user = ref.read(userProvider);
    // Shop — цена в NFC
    final priceNfc = item.priceInCoins; // 1:1
    if (user.balanceCoins < priceNfc) {
      TopNotify.show(context, 'Не хватает ${priceNfc - user.balanceCoins} NFC. Пополните баланс.', success: false);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.f('shop_buy_q', {'name': item.name})),
        content: Text('${priceNfc} NFC · ${item.rarity.label}\nПредмет сразу в инвентаре.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Купить за NFC'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await apiBuy(item);
      if (!mounted) return;
      TopNotify.show(context, context.l10n.f('shop_bought', {'name': item.name}), success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'insufficient_funds' ? 'Не хватает NFC. Пополните баланс.' : context.l10n.t('shop_fail');
      TopNotify.show(context, msg, success: false);
    }
  }

  /// Покупка за NFC через /api/shop/buy/:id
  Future<Map<String, dynamic>> apiBuy(NftItem item) async {
    final res = await ApiClient.instance.shopBuy(item.id);
    final bal = (res['balance_coins'] as num?)?.toInt() ?? (res['balance_nc'] as num?)?.toInt();
    if (bal != null) {
      ref.read(userProvider.notifier).setBalance(bal);
    }
    await ref.read(inventoryProvider.notifier).refresh();
    setState(() => _justBoughtId = item.id);
    _confetti.play();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justBoughtId = null);
    });
    return res;
  }

  Future<void> _buyBoost(String type) async {
    try {
      Map<String, dynamic> res;
      if (type == 'blessing') {
        res = await ApiClient.instance.buyBlessing();
      } else {
        res = await ApiClient.instance.buyLuck(type == 'x4' ? 4 : 2);
      }
      final bal = (res['balance_coins'] as num?)?.toInt() ?? (res['balance_nc'] as num?)?.toInt();
      if (bal != null) ref.read(userProvider.notifier).setBalance(bal);
      ref.read(eventsProvider.notifier).refresh();
      if (!mounted) return;
      TopNotify.show(context, 'Куплено! Эффект 15 минут активен.', success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      TopNotify.show(context, e.code == 'insufficient_funds' ? 'Не хватает NFC' : 'Ошибка покупки', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final user = ref.watch(userProvider);
    final items = _filtered(catalog);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final l10n = context.l10n;

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ScreenHeader(
                      title: l10n.t('menu_shop'),
                      subtitle: l10n.t('shop_sub'),
                      showBack: true,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: EntranceAnim(
                        index: 0,
                        child: BrandCard(
                          highlighted: true,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      gradient: RadialGradient(
                                        colors: [
                                          green.withOpacity(0.30),
                                          Colors.transparent
                                        ],
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '🛍️',
                                      style: TextStyle(
                                        fontSize: 48,
                                        shadows: [
                                          Shadow(
                                              color: green.withOpacity(0.6),
                                              blurRadius: 16)
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: const Color(0xFFFFC107).withOpacity(0.15), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.5))),
                                          child: const Text('МАГАЗИН · NFC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFFFC107))),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          l10n.t('menu_shop'),
                                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Покупай за NFC',
                                          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white38 : const Color(0xFF8A94A6)),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(color: const Color(0xFFFFC107).withOpacity(0.12), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.5))),
                                              child: Row(children: [
                                                const Icon(Icons.stars, size: 14, color: Color(0xFFFFC107)),
                                                const SizedBox(width: 4),
                                                Text('${user.balanceCoins} NFC', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFFFC107))),
                                              ]),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white12)),
                                              child: Row(children: [
                                                const Icon(Icons.monetization_on, size: 14, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text('${user.balanceNc} NC', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey)),
                                              ]),
                                            ),
                                            const Spacer(),
                                            GestureDetector(
                                              onTap: () => context.push('/topup'),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                                decoration: BoxDecoration(color: const Color(0xFFFFC107), borderRadius: BorderRadius.circular(99)),
                                                child: const Text('Пополнить NFC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Бусты за NFC
                              Row(
                                children: [
                                  Expanded(child: _BoostCard(icon: '🛡️', title: 'Благословение', price: '50 NFC', sub: 'Сейв 50% 15м', onTap: () => _buyBoost('blessing'))),
                                  const SizedBox(width: 8),
                                  Expanded(child: _BoostCard(icon: '🍀', title: 'x2 Удача', price: '30 NFC', sub: '15 минут', onTap: () => _buyBoost('x2'))),
                                  const SizedBox(width: 8),
                                  Expanded(child: _BoostCard(icon: '🍀', title: 'x4 Удача', price: '70 NFC', sub: '15 минут', onTap: () => _buyBoost('x4'))),
                                ],
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
                      child: Row(
                        children: [
                          _tabChip('all', l10n.t('shop_all')),
                          const SizedBox(width: 8),
                          _tabChip('cases', l10n.t('shop_cases')),
                          const SizedBox(width: 8),
                          _tabChip('gifts', l10n.t('shop_gifts')),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => context.push('/inventory'),
                            child: Row(
                              children: [
                                Icon(Icons.backpack_outlined,
                                    size: 15, color: green),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.t('shop_sell_own'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final item = items[i];
                          final priceNfc = item.priceInCoins;
                          final afford = user.balanceCoins >= priceNfc;
                          return EntranceAnim(
                            index: i % 8,
                            child: _ShopTile(
                              item: item,
                              afford: afford,
                              justBought: _justBoughtId == item.id,
                              onBuy: () => _buy(item),
                              priceLabel: '$priceNfc NFC',
                            ),
                          );
                        },
                        childCount: items.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 190,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.68,
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 18,
                  colors: const [
                    AppColors.brandGlow,
                    AppColors.accentYellow,
                    Colors.white,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabChip(String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sel = _tab == value;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    return GestureDetector(
      onTap: () => setState(() => _tab = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? green.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: sel
                ? green
                : (isDark ? Colors.white12 : const Color(0xFFE3E8E3)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: sel ? green : Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _BoostCard extends StatelessWidget {
  final String icon;
  final String title;
  final String price;
  final String sub;
  final VoidCallback onTap;
  const _BoostCard({required this.icon, required this.title, required this.price, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141E1A) : const Color(0xFFF3F6F1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.45)),
        ),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          Text(sub, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFFFC107), borderRadius: BorderRadius.circular(99)),
            child: Text(price, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black)),
          ),
        ]),
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  final NftItem item;
  final bool afford;
  final bool justBought;
  final String priceLabel;
  final VoidCallback onBuy;
  const _ShopTile({
    required this.item,
    required this.afford,
    required this.justBought,
    required this.priceLabel,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    return AnimatedScale(
      scale: justBought ? 1.04 : 1.0,
      duration: const Duration(milliseconds: 220),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1712) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: justBought
                ? green
                : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE3E8E3)),
            width: justBought ? 1.6 : 1,
          ),
          boxShadow: [
            if (justBought)
              BoxShadow(color: green.withOpacity(0.3), blurRadius: 18),
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: GiftImage(item: item)),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              item.rarity.label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onBuy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: afford
                      ? green
                      : (isDark ? Colors.white10 : const Color(0xFFF1F4F1)),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (justBought)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.check_rounded,
                            size: 14, color: Colors.black),
                      ),
                    Text(
                      justBought
                          ? context.l10n.t('shop_bought_btn')
                          : priceLabel,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: afford || justBought
                            ? Colors.black
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
