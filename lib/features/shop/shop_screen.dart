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
    if (user.balanceCoins < item.priceInCoins) {
      TopNotify.show(context, l10n.f('shop_not_enough', {'v': '${item.priceInCoins - user.balanceCoins}'}), success: false);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.f('shop_buy_q', {'name': item.name})),
        content: Text(l10n.f('shop_buy_text', {
          'price': '${item.priceInCoins}',
          'rarity': item.rarity.label,
        })),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.t('shop_buy')),
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
      TopNotify.show(context, context.l10n.t(e.code == 'insufficient_funds' ? 'shop_fail_funds' : 'shop_fail'), success: false);
    }
  }

  /// Покупка через сервер (источник правды) + синк баланса и инвентаря.
  Future<Map<String, dynamic>> apiBuy(NftItem item) async {
    final res = await ApiClient.instance.buyItem(item.id);
    final balance = (res['balance_coins'] as num?)?.toInt();
    if (balance != null) {
      ref.read(userProvider.notifier).setBalance(balance);
    }
    await ref.read(inventoryProvider.notifier).refresh();
    setState(() => _justBoughtId = item.id);
    _confetti.play();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justBoughtId = null);
    });
    return res;
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
                          child: Row(
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    PickedBadge(
                                        text: l10n.t('up_picked')),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.t('menu_shop'),
                                      style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.t('shop_buy_hint'),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark
                                            ? Colors.white38
                                            : const Color(0xFF8A94A6),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(Icons.monetization_on,
                                            size: 16, color: green),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${user.balanceCoins}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: green,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        GestureDetector(
                                          onTap: () =>
                                              context.push('/topup'),
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 7),
                                            decoration: BoxDecoration(
                                              color: green,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                            child: Text(
                                              l10n.t('shop_topup'),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                          final afford = user.balanceCoins >=
                              item.priceInCoins;
                          return EntranceAnim(
                            index: i % 8,
                            child: _ShopTile(
                              item: item,
                              afford: afford,
                              justBought:
                                  _justBoughtId == item.id,
                              onBuy: () => _buy(item),
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

class _ShopTile extends StatelessWidget {
  final NftItem item;
  final bool afford;
  final bool justBought;
  final VoidCallback onBuy;
  const _ShopTile({
    required this.item,
    required this.afford,
    required this.justBought,
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
                          : '🪙 ${item.priceInCoins}',
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
