import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_widgets.dart';
import '../../../core/widgets/top_notify.dart';
import '../../../data/models/nft_item.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../providers/balance_provider.dart';
import '../../../providers/session_provider.dart';
import '../../../services/api_client.dart';
import '../../upgrader/providers/upgrade_providers.dart';
import '../widgets/gauge_indicator.dart';
import '../widgets/nft_item_card.dart';
import '../widgets/spin_gauge.dart';
import '../widgets/upgrade_button.dart';

/// UPGRADER 1в1 с макета.
/// Верх (светлая тема) / низ (тёмная) — обе через Theme.
/// Ошибка макета «Тут иконка кейсов» исправлена: слева — реальная ставка,
/// справа — реальная цель, а не заглушки.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<SpinGaugeState> _gaugeKey = GlobalKey<SpinGaugeState>();
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _onUpgradePressed() async {
    final session = ref.read(upgradeSessionProvider);
    final notifier = ref.read(upgradeSessionProvider.notifier);
    if (!session.canUpgrade) return;

    late final dynamic result;
    try {
      result = await notifier.runUpgrade();
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      TopNotify.show(context, _upgradeErrorText(context, e.code), success: false);
      return;
    }
    ref.read(upgradeHistoryProvider.notifier).add(result);

    final finalAngle = GaugeIndicator.angleForPercent(result.rollPercent);
    await _gaugeKey.currentState?.spinTo(finalAngle);

    if (!mounted) return;
    final l10n = context.l10n;
    // Звук — сразу после остановки стрелки, потом верхнее уведомление Удача/Проигрыш
    if (result.success) {
      _confetti.play();
      HapticFeedback.selectionClick();
      await playSound(ref, ref.read(soundServiceProvider).win);
      if (!mounted) return;
      TopNotify.show(context, l10n.t('up_win_top'), success: true);
    } else if (result.saved == true) {
      HapticFeedback.lightImpact();
      await playSound(ref, ref.read(soundServiceProvider).win);
      if (!mounted) return;
      TopNotify.show(context, l10n.t('up_saved_msg'), success: true);
    } else {
      HapticFeedback.mediumImpact();
      await playSound(ref, ref.read(soundServiceProvider).lose);
      if (!mounted) return;
      TopNotify.show(context, l10n.t('up_lose_top'), success: false);
    }
    // Авто-очистка после раунда — как просили: ставка и цель сбрасываются
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    notifier.resetForNextRound();
    // Стрелка остаётся 1.5 сек чтобы успел увидеть, потом в стандарт
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _gaugeKey.currentState?.resetIdle();
    });
  }

  String _upgradeErrorText(BuildContext context, String code) {
    final l10n = context.l10n;
    switch (code) {
      case 'insufficient_funds':
        return l10n.t('up_err_funds');
      case 'invalid_stake':
        return l10n.t('up_err_stake');
      case 'chance_above_limit':
        return l10n.t('up_err_limit');
      case 'error_network':
        return l10n.t('error_network');
      default:
        return l10n.t('up_err_generic');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(upgradeSessionProvider);
    final inventory = ref.watch(inventoryProvider);
    final catalog = ref.watch(catalogProvider);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 980;

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _UpgraderHeader(session: session)),
                  // Верх: два квадрата выбора (ставка и цель) — всегда в ряд на wide
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    sliver: SliverToBoxAdapter(
                      child: isWide
                          ? _buildWideTopCards(context, session)
                          : _buildMobileTopCards(context, session),
                    ),
                  ),
                  // Центр: гейдж + кнопка апгрейда — выше, отдельно, без наложения
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: EntranceAnim(
                            index: 2,
                            child: _GaugeColumn(
                              session: session,
                              gaugeKey: _gaugeKey,
                              onUpgrade: _onUpgradePressed,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Низ: мои подарки (квадраты) и выбор подарков (сетка вниз)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    sliver: SliverToBoxAdapter(
                      child: isWide
                          ? _buildWideBottom(context, session, inventory, catalog)
                          : _buildMobileBottom(context, session, inventory, catalog),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 24,
                  maxBlastForce: 20,
                  minBlastForce: 8,
                  gravity: 0.3,
                  colors: const [
                    AppColors.brandGlow,
                    AppColors.brandLime,
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

  // ── Верхний ряд: только выбор ставки и цели (квадраты) ──

  Widget _buildWideTopCards(BuildContext context, UpgradeSessionState session) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: EntranceAnim(index: 0, child: _StakeCard(session: session))),
        const SizedBox(width: 16),
        Expanded(child: EntranceAnim(index: 1, child: _TargetCard(session: session))),
      ],
    );
  }

  Widget _buildMobileTopCards(BuildContext context, UpgradeSessionState session) {
    return Column(
      children: [
        EntranceAnim(index: 0, child: _StakeCard(session: session)),
        const SizedBox(height: 14),
        EntranceAnim(index: 1, child: _TargetCard(session: session)),
      ],
    );
  }

  // ── Нижний ряд: мои подарки + все подарки ──

  Widget _buildWideBottom(BuildContext context, UpgradeSessionState session,
      List<NftItem> inventory, List<NftItem> catalog) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: EntranceAnim(
            index: 3,
            child: _MyGiftsCard(session: session, inventory: inventory),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 6,
          child: EntranceAnim(
            index: 4,
            child: _AllGiftsCard(session: session, catalog: catalog),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBottom(BuildContext context, UpgradeSessionState session,
      List<NftItem> inventory, List<NftItem> catalog) {
    return Column(
      children: [
        EntranceAnim(
          index: 3,
          child: _MyGiftsCard(session: session, inventory: inventory),
        ),
        const SizedBox(height: 14),
        EntranceAnim(
          index: 4,
          child: _AllGiftsCard(session: session, catalog: catalog),
        ),
      ],
    );
  }
}

// ── Шапка UPGRADER ──

class _UpgraderHeader extends StatelessWidget {
  final UpgradeSessionState session;
  const _UpgraderHeader({required this.session});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackBtn(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.keyboard_double_arrow_up_rounded,
                      color: isDark ? AppColors.brandNeon : AppColors.brandGreen,
                      size: 30,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'UPGRADER',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: isDark ? Colors.white : const Color(0xFF101410),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.t('up_sub'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white38 : const Color(0xFF8A94A6),
                  ),
                ),
              ],
            ),
          ),
          const _HeaderInventoryBtn(),
          const SizedBox(width: 8),
          const UserPill(),
        ],
      ),
    );
  }
}

class _BackBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => context.canPop() ? context.pop() : context.go('/home'),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : const Color(0x14000000),
          ),
        ),
        child: const Icon(Icons.arrow_back_rounded, size: 18),
      ),
    );
  }
}

class _HeaderInventoryBtn extends ConsumerWidget {
  const _HeaderInventoryBtn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = ref.watch(inventoryProvider).length;
    return GestureDetector(
      onTap: () => context.push('/inventory'),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : const Color(0x14000000),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.backpack_rounded,
              size: 19,
              color: isDark ? AppColors.brandNeon : AppColors.brandGreenDeep,
            ),
            if (count > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.brandNeon : AppColors.brandGreen,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Левая карточка: ставка ──

class _StakeCard extends ConsumerWidget {
  final UpgradeSessionState session;
  const _StakeCard({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final staked = session.stakedItems;
    final total = session.totalStakeValue;
    // Показываем фото первого выбранного подарка, а не коробку
    final firstItem = staked.isNotEmpty ? staked.first : null;

    return BrandCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _MiniGiftArt(
            emoji: staked.isEmpty ? '🎁' : '📦',
            filled: staked.isNotEmpty,
            item: firstItem,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                PickedBadge(text: l10n.t('up_picked')),
                const SizedBox(height: 8),
                Text(
                  staked.isEmpty
                      ? l10n.t('up_pick_stake')
                      : staked.map((e) => e.name).join(' + '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF101410),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  staked.isEmpty
                      ? l10n.t('up_stake_hint')
                      : l10n.f('up_stake_value',
                          {'v': total.toStringAsFixed(0)}),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : const Color(0xFF8A94A6),
                  ),
                ),
                if (staked.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () {
                      for (final it in [...staked]) {
                        ref.read(upgradeSessionProvider.notifier).toggleStakeItem(it);
                      }
                    },
                    child: Text(
                      l10n.t('up_clear'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.brandNeon : AppColors.brandGreenDeep,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}

// ── Правая карточка: цель ──

class _TargetCard extends ConsumerWidget {
  final UpgradeSessionState session;
  const _TargetCard({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final target = session.targetItem;

    return BrandCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _MiniGiftArt(
            emoji: target == null ? '🛍️' : '🎁',
            filled: target != null,
            item: target,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                PickedBadge(text: l10n.t('up_picked')),
                const SizedBox(height: 8),
                Text(
                  target?.name ?? l10n.t('up_pick_target'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF101410),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  target == null
                      ? l10n.t('up_target_hint')
                      : '${target.priceInCoins} ${l10n.t('coins')} · ${target.rarity.label}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : const Color(0xFF8A94A6),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}

class _MiniGiftArt extends StatelessWidget {
  final String emoji;
  final bool filled;
  final NftItem? item;
  const _MiniGiftArt({required this.emoji, this.filled = false, this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreen;
    // Квадратил — чёткий квадрат с рамкой, без круглого свечения
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: filled ? green.withOpacity(0.14) : (isDark ? const Color(0xFF141E1A) : const Color(0xFFF3F6F1)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: filled ? green.withOpacity(0.45) : (isDark ? Colors.white12 : const Color(0xFFE3E8E3)), width: 1.2),
        boxShadow: filled ? [BoxShadow(color: green.withOpacity(0.22), blurRadius: 14)] : null,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: item?.resolvedAsset != null
          ? Image.asset(item!.resolvedAsset!, width: 52, height: 52, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(emoji, style: const TextStyle(fontSize: 36)))
          : Text(
              emoji,
              style: TextStyle(
                fontSize: 38,
                shadows: [Shadow(color: green.withOpacity(0.5), blurRadius: 12)],
              ),
            ),
    );
  }
}

// ── Центр: gauge + кнопка ──

class _GaugeColumn extends ConsumerWidget {
  final UpgradeSessionState session;
  final GlobalKey<SpinGaugeState> gaugeKey;
  final VoidCallback onUpgrade;
  const _GaugeColumn({
    required this.session,
    required this.gaugeKey,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final events = ref.watch(eventsProvider);
    // Сервер умножает шанс ивентом — показываем тот же boosted-шанс.
    final boosted = (session.chancePercent * events.luckMultiplier)
        .clamp(0, AppConstants.maxChancePercent)
        .toDouble();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (events.luckMultiplier > 1 || events.saves)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                if (events.luckMultiplier > 1)
                  _EventPill(
                      text: l10n.f('up_luck',
                          {'mult': '${events.luckMultiplier}'})),
                if (events.saves)
                  _EventPill(text: l10n.t('up_saves')),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final mq = MediaQuery.of(context);
            final isLandscape = mq.orientation == Orientation.landscape;
            final w = constraints.maxWidth > 0 ? constraints.maxWidth : mq.size.width;
            final h = mq.size.height;
            double gaugeSize = (w * 0.64).clamp(210.0, 300.0);
            if (isLandscape && h < 500) {
              gaugeSize = (h * 0.60).clamp(160.0, 220.0);
            }
            final maxBox = isLandscape ? h * 0.72 : 340.0;
            final boxSize = (gaugeSize + 8).clamp(165.0, maxBox.clamp(200.0, 310.0));
            return RepaintBoundary(
              child: SizedBox(
                width: boxSize,
                height: boxSize,
                child: Center(
                  child: SpinGauge(
                    key: gaugeKey,
                    idleChancePercent: boosted,
                    showBrandIcon: session.targetItem == null && session.totalStakeValue <= 0,
                    overMaxLimit: session.isOverMaxLimit,
                    size: gaugeSize,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        if (session.isOverMaxLimit)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.danger.withOpacity(0.4)),
            ),
            child: Text(
              l10n.t('upgrade_blocked_max'),
              style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w700),
            ),
          ),
        UpgradeButton(
          status: session.status,
          canUpgrade: session.canUpgrade,
          blockedByLimit: session.isOverMaxLimit,
          onPressed: onUpgrade,
        ),
      ],
    );
  }

  Widget _scaleLabel(String t, bool isDark) {
    return Text(
      t,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white38 : const Color(0xFF8A94A6),
      ),
    );
  }
}

class _EventPill extends StatelessWidget {
  final String text;
  const _EventPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: green.withOpacity(0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: green.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: green.withOpacity(0.25), blurRadius: 12)],
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: green),
      ),
    );
  }
}

// ── Низ слева: мои подарки (ставка) ──

class _MyGiftsCard extends ConsumerWidget {
  final UpgradeSessionState session;
  final List<NftItem> inventory;
  const _MyGiftsCard({required this.session, required this.inventory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final notifier = ref.read(upgradeSessionProvider.notifier);
    final stakedIds = session.stakedItems.map((e) => e.id).toSet();

    return BrandCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.brandNeon : AppColors.brandGreen).withOpacity(0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.card_giftcard_rounded, size: 16, color: isDark ? AppColors.brandNeon : AppColors.brandGreenDeep),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.t('up_no_gifts').isEmpty ? 'Мои подарки' : 'Мои подарки',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF101410)),
              ),
              const Spacer(),
              if (inventory.isNotEmpty)
                Text('${inventory.length}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF8A94A6), fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          if (inventory.isEmpty)
            Row(
              children: [
                Text('🎁', style: TextStyle(fontSize: 40, color: isDark ? null : Colors.grey[400])),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    l10n.t('up_no_gifts'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : const Color(0xFF8A94A6),
                    ),
                  ),
                ),
              ],
            )
          else
            // Квадратил: ровная сетка квадратов, идёт вниз
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in inventory)
                  _StakeChip(
                    item: item,
                    selected: stakedIds.contains(item.id),
                    onTap: () => notifier.toggleStakeItem(item),
                  ),
              ],
            ),
          if (inventory.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l10n.f('up_stake_count', {'n': '${session.stakedItems.length}'}),
              style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white38 : const Color(0xFF8A94A6)),
            ),
          ],
          const SizedBox(height: 12),
          _BalanceStakeRow(session: session),
        ],
      ),
    );
  }
}

class _BalanceStakeRow extends ConsumerWidget {
  final UpgradeSessionState session;
  const _BalanceStakeRow({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final user = ref.watch(userProvider);
    final notifier = ref.read(upgradeSessionProvider.notifier);

    void setAmount(int v) {
      final clamped = v.clamp(0, user.balanceNc);
      notifier.setUseBalance(clamped > 0, amount: clamped);
      if (clamped > 0 && !session.useBalance) {
        notifier.setUseBalance(true, amount: clamped);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: session.useBalance
            ? green.withOpacity(0.10)
            : (isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF3F6F1)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: session.useBalance
              ? green.withOpacity(0.5)
              : (isDark ? Colors.white12 : const Color(0xFFE3E8E3)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => notifier.setUseBalance(!session.useBalance,
                amount: session.balanceStakeAmount),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: session.useBalance ? green : Colors.transparent,
                border: Border.all(color: green, width: 1.6),
              ),
              child: session.useBalance
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Ставить NC',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          _StepBtn(
              icon: Icons.remove_rounded,
              onTap: () => setAmount(session.balanceStakeAmount - 100)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '${session.balanceStakeAmount}',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: green, fontSize: 14),
            ),
          ),
          _StepBtn(
              icon: Icons.add_rounded,
              onTap: () => setAmount(session.balanceStakeAmount + 100)),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.withOpacity(0.4)),
        ),
        child: Icon(icon, size: 15, color: Colors.grey),
      ),
    );
  }
}

class _StakeChip extends StatelessWidget {
  final NftItem item;
  final bool selected;
  final VoidCallback onTap;
  const _StakeChip({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    // Уменьшены в разы как просили — компактные карточки
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 64,
        height: 64,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? green.withOpacity(0.14) : (isDark ? const Color(0xFF141E1A) : const Color(0xFFF3F6F1)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? green : (isDark ? Colors.white12 : const Color(0xFFE3E8E3)), width: selected ? 1.4 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 34, child: GiftImage(item: item, radius: 8)),
            const SizedBox(height: 2),
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
            Text('${item.priceInCoins}', style: TextStyle(fontSize: 8, color: green, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
          ],
        ),
      ),
    );
  }
}

// ── Низ справа: все подарки на улучшение (вертикальная сетка вниз) ──

class _AllGiftsCard extends ConsumerWidget {
  final UpgradeSessionState session;
  final List<NftItem> catalog;
  const _AllGiftsCard({required this.session, required this.catalog});

  double _chanceFor(NftItem target) {
    final stake = session.totalStakeValue;
    if (stake <= 0 || target.priceInCoins <= 0) return 0;
    final raw = (stake / target.priceInCoins) * 100.0;
    return raw.clamp(AppConstants.minChancePercent, AppConstants.maxChancePercent);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final notifier = ref.read(upgradeSessionProvider.notifier);
    final hasStake = session.totalStakeValue > 0;
    final width = MediaQuery.of(context).size.width;
    final crossCount = width >= 980 ? 3 : 2;

    return BrandCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.brandNeon : AppColors.brandGreen)
                      .withOpacity(0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: isDark ? AppColors.brandNeon : AppColors.brandGreenDeep,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.t('up_all_gifts'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF101410),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Вертикальная сетка: идёт вниз — карточки уменьшены в разы
          SizedBox(
            height: 320,
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount == 3 ? 4 : 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.90,
              ),
              itemCount: catalog.length,
              itemBuilder: (context, i) {
                final item = catalog[i];
                final chance = _chanceFor(item);
                final selected = session.targetItem?.id == item.id;
                return _TargetTile(
                  item: item,
                  chance: chance,
                  showChance: hasStake,
                  selected: selected,
                  onTap: () => notifier.setTargetItem(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetTile extends StatelessWidget {
  final NftItem item;
  final double chance;
  final bool showChance;
  final bool selected;
  final VoidCallback onTap;
  const _TargetTile({
    required this.item,
    required this.chance,
    required this.showChance,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final rarity = AppColors.rarityColor(item.rarity.name);
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark ? [rarity.withOpacity(0.22), const Color(0xFF131B15)] : [rarity.withOpacity(0.14), Colors.white],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? green : (isDark ? Colors.white12 : const Color(0xFFE3E8E3)), width: selected ? 1.2 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 38, child: GiftImage(item: item, radius: 8)),
              const SizedBox(height: 3),
              Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF101410), decoration: TextDecoration.none)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withOpacity(isDark ? 0.35 : 0.06), borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.keyboard_double_arrow_up_rounded, size: 10, color: green),
                  const SizedBox(width: 2),
                  Text(showChance ? '${chance.toStringAsFixed(1)}%' : '${item.priceInCoins}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF101410), decoration: TextDecoration.none)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
