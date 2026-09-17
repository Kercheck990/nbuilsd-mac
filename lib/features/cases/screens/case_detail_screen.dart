import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_widgets.dart';
import '../../../core/widgets/top_notify.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../providers/balance_provider.dart';
import '../../../services/api_client.dart';
import '../models/case_model.dart';
import '../providers/cases_provider.dart';
import '../widgets/case_roulette.dart';

class CaseDetailScreen extends ConsumerStatefulWidget {
  final String caseId;
  const CaseDetailScreen({super.key, required this.caseId});
  @override
  ConsumerState<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends ConsumerState<CaseDetailScreen> {
  int _count = 1;
  bool _autoOpen = false;
  bool _spinning = false;
  List<CaseItemModel> _wonPool = [];
  List<CaseOpenWon> _lastWon = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(caseDetailProvider(widget.caseId).notifier).load());
  }

  Future<void> _open() async {
    if (_spinning) return;
    final detail = ref.read(caseDetailProvider(widget.caseId));
    final c = detail.info;
    if (c == null) return;
    final user = ref.read(userProvider);
    final total = c.priceNc * _count;
    if (total > user.balanceNc) {
      TopNotify.show(context, context.l10n.t('case_not_enough_nc'), success: false);
      return;
    }
    setState(() {
      _spinning = true;
      _wonPool = [];
      _lastWon = [];
    });
    try {
      final won = await ref.read(caseOpenProvider.notifier).open(c.id, _count);
      // баланс — безопасно, не падаем если me вернул null
      try {
        final me = await ApiClient.instance.me();
        final userJson = (me['user'] ?? me) as Map<String, dynamic>?;
        if (userJson != null) {
          final nc = userJson['balance_nc'];
          final coins = userJson['balance_coins'];
          if (nc != null) {
            ref.read(userProvider.notifier).setNc(int.tryParse(nc.toString()) ?? (user.balanceNc - total));
          } else {
            ref.read(userProvider.notifier).setNc(user.balanceNc - total);
          }
          if (coins != null) {
            ref.read(userProvider.notifier).setBalance(int.tryParse(coins.toString()) ?? user.balanceCoins);
          }
        } else {
          ref.read(userProvider.notifier).setNc(user.balanceNc - total);
        }
      } catch (_) {
        ref.read(userProvider.notifier).setNc(user.balanceNc - total);
      }
      await ref.read(inventoryProvider.notifier).refresh();

      final wonAsPool = won.map((w) => CaseItemModel(itemId: w.itemId, name: w.name, priceCoins: w.priceCoins, rarity: w.rarity, imageAsset: w.imageAsset, dropChance: w.dropChance)).toList();
      setState(() {
        _wonPool = wonAsPool;
        _lastWon = won;
      });
    } catch (e) {
      if (mounted) {
        String msg = e is ApiException ? e.message : e.toString();
        if ((e is ApiException) && e.code == 'daily_limit') msg = context.l10n.t('case_daily_done');
        if ((e is ApiException) && e.code == 'insufficient_nc') msg = context.l10n.t('case_not_enough_nc');
        if (msg.contains("type 'Null'")) msg = 'Ошибка сервера, попробуйте еще раз';
        TopNotify.show(context, msg, success: false);
      }
      setState(() => _spinning = false);
    }
  }

  void _onRouletteFinished() {
    setState(() => _spinning = false);
    if (_autoOpen && _count == 1) {
      // автоматом открыть снова через 1 сек если включено
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _autoOpen && !_spinning) _open();
      });
    }
    // показать диалог выигрыша?
    if (_lastWon.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => _WinDialog(won: _lastWon),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detail = ref.watch(caseDetailProvider(widget.caseId));
    final user = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (detail.loading) {
      return Scaffold(body: BrandBackground(child: Center(child: CircularProgressIndicator(color: AppColors.brandGreen))));
    }
    if (detail.error != null) {
      return Scaffold(body: BrandBackground(child: Center(child: Text(detail.error!))));
    }
    final c = detail.info!;
    final items = detail.items;
    final totalPrice = c.priceNc * _count;
    final canAfford = totalPrice <= user.balanceNc;
    final priceLabel = c.priceNc == 0 ? (c.id == 'case_daily' ? l10n.t('case_daily_free') : l10n.t('case_trash_free')) : '$totalPrice NC';

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              context.go('/cases');
                            }
                          },
                          icon: const Icon(Icons.arrow_back, color: Colors.white)),
                      Expanded(child: Text(c.name, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF101410), fontWeight: FontWeight.w900, fontSize: 18))),
                      Row(children: [
                        Checkbox(value: _autoOpen, onChanged: (v) => setState(() => _autoOpen = v ?? false), side: const BorderSide(color: AppColors.brandGreen), activeColor: AppColors.brandGreen),
                        Text(l10n.t('case_count') == 'case_count' ? 'Авто' : 'Авто', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF6B7280), fontSize: 11)),
                      ]),
                    ],
                  ),
                ),
              ),
              // картинка кейса
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [AppColors.brandGreen.withOpacity(0.14), Colors.transparent]),
                          ),
                        ),
                        Image.asset(
                          c.imageAsset ?? 'assets/case/${c.id}.png',
                          width: 115,
                          height: 115,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset('assets/iconmainmenu/case.png', width: 95, height: 95, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2, size: 64, color: AppColors.brandNeon)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              // цена + счетчик
              SliverToBoxAdapter(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stars, color: Color(0xFFFFC107), size: 22),
                      const SizedBox(width: 6),
                      Text(priceLabel, style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.w900, fontSize: 18)),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              // рулетка или заглушка
              if (_wonPool.isNotEmpty && _spinning)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: MultiRoulette(wonItems: _wonPool, pool: items, onAllFinished: _onRouletteFinished),
                  ),
                )
              else if (_wonPool.isNotEmpty && !_spinning)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF101814), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.brandGreen.withOpacity(0.3))),
                      child: Column(
                        children: [
                          Text('${l10n.t('case_won')}:', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: _lastWon.map((w) => _WonTile(won: w)).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              // выбор количества 1..10
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(10, (i) {
                        final n = i + 1;
                        final sel = _count == n;
                        return Expanded(
                          child: GestureDetector(
                            onTap: _spinning ? null : () => setState(() => _count = n),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 36,
                              decoration: BoxDecoration(
                                color: sel ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: sel ? null : Border.all(color: Colors.transparent),
                              ),
                              alignment: Alignment.center,
                              child: Text('$n', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: sel ? Colors.black : Colors.white)),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              // кнопка открыть
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (_spinning || !canAfford) ? null : _open,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7A00), disabledBackgroundColor: Colors.grey[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(_spinning ? l10n.t('case_opening') : l10n.t('case_open'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ),
                ),
              ),
              if (!canAfford && !_spinning)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(child: Text(l10n.t('case_not_enough_nc'), style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              // список предметов в кейсе
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(l10n.t('case_items_in'), textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF101410), fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.92, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final it = items[i];
                    return _CaseItemTile(item: it);
                  }, childCount: items.length),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WonTile extends StatelessWidget {
  final CaseOpenWon won;
  const _WonTile({required this.won});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(children: [
        Image.asset(won.resolvedAsset, height: 56, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('🎁', style: TextStyle(fontSize: 32))),
        const SizedBox(height: 6),
        Text(won.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.stars, size: 12, color: Color(0xFFFFC107)),
          const SizedBox(width: 2),
          Text('${won.priceCoins}', style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
      ]),
    );
  }
}

class _CaseItemTile extends StatelessWidget {
  final CaseItemModel item;
  const _CaseItemTile({required this.item});

  Color _rarityColor(String r) {
    switch (r) {
      case 'legendary':
        return const Color(0xFFF59E0B);
      case 'epic':
        return const Color(0xFFA855F7);
      case 'rare':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = _rarityColor(item.rarity);
    final displayName = item.name.isEmpty ? item.itemId : item.name;
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14), border: Border.all(color: col.withOpacity(0.35))),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${item.dropChance.toStringAsFixed(item.dropChance.truncateToDouble() == item.dropChance ? 0 : 2)}%', style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
            const Icon(Icons.close, size: 14, color: Colors.white24),
          ]),
          Expanded(
            child: Center(
              child: Builder(builder: (context) {
                // пробуем 3 варианта пути как в GiftAssets
                final candidates = [item.resolvedAsset, 'assets/gifts/${item.itemId}.png'];
                return Image.asset(item.resolvedAsset, fit: BoxFit.contain, errorBuilder: (_, __, ___) {
                  // fallback на GiftAssets
                  final fallback = _giftFallback(item.itemId);
                  if (fallback != null && fallback != item.resolvedAsset) {
                    return Image.asset(fallback, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Text('🎁', style: TextStyle(fontSize: 32, color: col)));
                  }
                  return Text('🎁', style: TextStyle(fontSize: 32, color: col));
                });
              }),
            ),
          ),
          Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF0F0F0F), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.stars, size: 12, color: Color(0xFFFFC107)),
              const SizedBox(width: 4),
              Text('${item.priceCoins}', style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }

  String? _giftFallback(String id) {
    const map = {
      'present': 'assets/gifts/present.png',
      'cup': 'assets/gifts/cup.png',
      'cake': 'assets/gifts/cake.png',
      'flowers': 'assets/gifts/flowers.png',
      'heart': 'assets/gifts/heart.png',
      'rose': 'assets/gifts/rose.png',
      'ring': 'assets/gifts/ring.png',
      'rocket': 'assets/gifts/rocket.png',
      'bull_run': 'assets/gifts/bull_run.png',
      'diamond': 'assets/gifts/diamond.png',
      'bear': 'assets/gifts/bear.png',
      'nft_001': 'assets/gifts/present.png',
      'nft_002': 'assets/gifts/cup.png',
      'nft_003': 'assets/gifts/cake.png',
      'nft_004': 'assets/gifts/flowers.png',
      'nft_005': 'assets/gifts/ring.png',
      'nft_006': 'assets/gifts/rocket.png',
      'nft_007': 'assets/gifts/rose.png',
      'nft_008': 'assets/gifts/diamond.png',
      'nft_009': 'assets/gifts/bear.png',
      'nft_010': 'assets/gifts/bull_run.png',
      'nft_011': 'assets/gifts/heart.png',
      'nft_012': 'assets/gifts/cup.png',
      'nft_013': 'assets/gifts/heart.png',
      'nft_014': 'assets/gifts/bull_run.png',
      'nft_015': 'assets/gifts/diamond.png',
    };
    return map[id];
  }
}

class _WinDialog extends StatelessWidget {
  final List<CaseOpenWon> won;
  const _WinDialog({required this.won});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF101814),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Вы выиграли!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: won.map((w) => _WonTile(won: w)).toList()),
        const SizedBox(height: 12),
        Text('Предметы добавлены в инвентарь', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ок', style: TextStyle(color: AppColors.brandGreen)))],
    );
  }
}
