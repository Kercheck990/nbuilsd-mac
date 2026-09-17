import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';

/// Главное меню 1в1 с макета:
/// сверху белая тема / снизу тёмная — обе поддерживаются через Theme.
/// Ошибка макета «Тут иконка кейсов» исправлена: это карточка «Кейсы».
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 980;
    final isTablet = width >= 640 && width < 980;
    final l10n = context.l10n;

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(
                  title: l10n.t('menu_title'),
                  subtitle: l10n.t('menu_sub'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: isWide
                      ? _WideGrid(context)
                      : isTablet
                          ? _TabletGrid(context)
                          : _MobileGrid(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Wide (как на фото): [Кейсы] [Upgrade/Лидеры] [Settings/Trade] [Shop] ──

class _WideGrid extends StatelessWidget {
  final BuildContext context;
  const _WideGrid(this.context);

  @override
  Widget build(BuildContext ctx) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 24,
            child: EntranceAnim(
              index: 0,
              child: _CasesCard(tall: true, onTap: () => context.push('/cases')),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 26,
            child: Column(
              children: [
                Expanded(
                  child: EntranceAnim(
                    index: 1,
                    child: _SmallCard(
                      title: context.l10n.t('menu_upgrade'),
                      subtitle: context.l10n.t('menu_upgrade_sub'),
                      art: const _Art(asset: 'assets/iconmainmenu/upgrader.png', glow: Color(0xFFFFC107)),
                      onTap: () => context.push('/upgrader'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: EntranceAnim(
                    index: 3,
                    child: _SmallCard(
                      title: context.l10n.t('menu_leaders'),
                      subtitle: context.l10n.t('menu_leaders_sub'),
                      art: const _Art(asset: 'assets/iconmainmenu/leaders.png', glow: AppColors.brandGreen),
                      onTap: () => context.push('/leaderboard'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 26,
            child: Column(
              children: [
                Expanded(
                  child: EntranceAnim(
                    index: 2,
                    child: _SmallCard(
                      title: context.l10n.t('menu_settings'),
                      subtitle: context.l10n.t('menu_settings_sub'),
                      art: const _Art(asset: 'assets/iconmainmenu/settings.png', glow: AppColors.brandGreen),
                      onTap: () => context.push('/settings'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: EntranceAnim(
                    index: 4,
                    child: _SmallCard(
                      title: context.l10n.t('menu_trade'),
                      subtitle: context.l10n.t('menu_trade_sub'),
                      art: const _Art(asset: 'assets/iconmainmenu/trade.png', glow: AppColors.brandGreen),
                      onTap: () => context.push('/trade'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 24,
            child: EntranceAnim(
              index: 5,
              child: _ShopCard(tall: true, onTap: () => context.push('/shop')),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletGrid extends StatelessWidget {
  final BuildContext context;
  const _TabletGrid(this.context);

  @override
  Widget build(BuildContext ctx) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: EntranceAnim(
                index: 0,
                child: _CasesCard(tall: false, onTap: () => context.push('/cases')),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: EntranceAnim(
                index: 1,
                child: _ShopCard(tall: false, onTap: () => context.push('/shop')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.9,
          children: [
            EntranceAnim(
              index: 2,
              child: _SmallCard(
                title: context.l10n.t('menu_upgrade'),
                subtitle: context.l10n.t('menu_upgrade_sub'),
                art: const _Art(asset: 'assets/iconmainmenu/upgrader.png', glow: Color(0xFFFFC107), small: true),
                onTap: () => context.push('/upgrader'),
              ),
            ),
            EntranceAnim(
              index: 3,
              child: _SmallCard(
                title: context.l10n.t('menu_settings'),
                subtitle: context.l10n.t('menu_settings_sub'),
                art: const _Art(asset: 'assets/iconmainmenu/settings.png', glow: AppColors.brandGreen, small: true),
                onTap: () => context.push('/settings'),
              ),
            ),
            EntranceAnim(
              index: 4,
              child: _SmallCard(
                title: context.l10n.t('menu_leaders'),
                subtitle: context.l10n.t('menu_leaders_sub'),
                art: const _Art(asset: 'assets/iconmainmenu/leaders.png', glow: AppColors.brandGreen, small: true),
                onTap: () => context.push('/leaderboard'),
              ),
            ),
            EntranceAnim(
              index: 5,
              child: _SmallCard(
                title: context.l10n.t('menu_trade'),
                subtitle: context.l10n.t('menu_trade_sub'),
                art: const _Art(asset: 'assets/iconmainmenu/trade.png', glow: AppColors.brandGreen, small: true),
                onTap: () => context.push('/trade'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MobileGrid extends StatelessWidget {
  final BuildContext context;
  const _MobileGrid(this.context);

  @override
  Widget build(BuildContext ctx) {
    Widget small(String title, String sub, String asset, Color glow, String route, int i) {      return EntranceAnim(
        index: i,
        child: _SmallCard(
          title: title,
          subtitle: sub,
          art: _Art(asset: asset, glow: glow, small: true),
          onTap: () => context.push(route),
        ),
      );
    }

    return Column(
      children: [
        EntranceAnim(
          index: 0,
          child: _CasesCard(tall: false, onTap: () => context.push('/cases')),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
                child: small(
                    context.l10n.t('menu_upgrade'),
                    context.l10n.t('menu_upgrade_sub'),
                    'assets/iconmainmenu/upgrader.png',
                    const Color(0xFFFFC107),
                    '/upgrader',
                    1)),
            const SizedBox(width: 14),
            Expanded(
                child: small(
                    context.l10n.t('menu_settings'),
                    context.l10n.t('menu_settings_sub'),
                    'assets/iconmainmenu/settings.png',
                    AppColors.brandGreen,
                    '/settings',
                    2)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
                child: small(
                    context.l10n.t('menu_leaders'),
                    context.l10n.t('menu_leaders_sub'),
                    'assets/iconmainmenu/leaders.png',
                    AppColors.brandGreen,
                    '/leaderboard',
                    3)),
            const SizedBox(width: 14),
            Expanded(
                child: small(
                    context.l10n.t('menu_trade'),
                    context.l10n.t('menu_trade_sub'),
                    'assets/iconmainmenu/trade.png',
                    AppColors.brandGreen,
                    '/trade',
                    4)),
          ],
        ),
        const SizedBox(height: 14),
        EntranceAnim(
          index: 5,
          child: _ShopCard(tall: false, onTap: () => context.push('/shop')),
        ),
      ],
    );
  }
}

// ── Карточки ──

/// Большая левая карточка. Исправлено: вместо плейсхолдера
/// «Тут иконка кейсов» — настоящий раздел «Кейсы».
class _CasesCard extends StatelessWidget {
  final bool tall;
  final VoidCallback onTap;
  const _CasesCard({required this.tall, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      onTap: onTap,
      child: tall ? _tallBody(context) : _wideBody(context),
    );
  }

  Widget _tallBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: _Float(child: _NftBoxArt(size: 150))),
        const SizedBox(height: 18),
        Text(
          l10n.t('menu_cases'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF101410),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.t('menu_cases_sub'),
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? Colors.white38 : const Color(0xFF8A94A6),
          ),
        ),
        const Spacer(),
        const Align(alignment: Alignment.bottomRight, child: GreenArrowBtn()),
      ],
    );
  }

  Widget _wideBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    return Row(
      children: [
        const _Float(child: _NftBoxArt(size: 118)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.t('menu_cases'),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF101410),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.t('menu_cases_sub'),
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white38 : const Color(0xFF8A94A6),
                ),
              ),
              const SizedBox(height: 12),
              const GreenArrowBtn(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShopCard extends StatelessWidget {
  final bool tall;
  final VoidCallback onTap;
  const _ShopCard({required this.tall, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final title = Text(
      l10n.t('menu_shop'),
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : const Color(0xFF101410),
      ),
    );
    final sub = Text(
      l10n.t('menu_shop_sub'),
      style: TextStyle(
        fontSize: 12.5,
        color: isDark ? Colors.white38 : const Color(0xFF8A94A6),
      ),
    );
    return BrandCard(
      onTap: onTap,
      highlighted: true,
      child: tall
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: _Float(delay: 400, child: _NftBagArt(size: 150))),
                const SizedBox(height: 18),
                title,
                const SizedBox(height: 6),
                sub,
                const Spacer(),
                const Align(alignment: Alignment.bottomRight, child: GreenArrowBtn()),
              ],
            )
          : Row(
              children: [
                const _Float(delay: 400, child: _NftBagArt(size: 118)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      title,
                      const SizedBox(height: 6),
                      sub,
                      const SizedBox(height: 12),
                      const GreenArrowBtn(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget art;
  final VoidCallback onTap;
  const _SmallCard({
    required this.title,
    required this.subtitle,
    required this.art,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BrandCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          art,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF101410),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white38 : const Color(0xFF8A94A6),
                  ),
                ),
              ],
            ),
          ),
          const GreenArrowBtn(size: 28),
        ],
      ),
    );
  }
}

// ── Арт — теперь картинки из assets/iconmainmenu вместо emoji ──

/// Круглая подложка + картинка из assets/iconmainmenu с зелёным свечением.
class _Art extends StatelessWidget {
  final String asset;
  final Color glow;
  final bool small;
  const _Art({required this.asset, required this.glow, this.small = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = small ? 58.0 : 74.0;
    final imgSize = small ? 38.0 : 48.0;
    return _Float(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: isDark
                ? [glow.withOpacity(0.35), Colors.transparent]
                : [glow.withOpacity(0.22), Colors.transparent],
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(color: glow.withOpacity(0.45), blurRadius: 18, spreadRadius: 1),
            ],
          ),
          child: Image.asset(
            asset,
            width: imgSize,
            height: imgSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported, size: imgSize * 0.6, color: glow),
          ),
        ),
      ),
    );
  }
}

/// Кейсы — картинка case.png из assets/iconmainmenu
class _NftBoxArt extends StatelessWidget {
  final double size;
  const _NftBoxArt({required this.size});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.78,
            height: size * 0.78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [const Color(0xFF2BE34A).withOpacity(0.28), Colors.transparent]
                    : [const Color(0xFF3EDB5A).withOpacity(0.20), Colors.transparent],
              ),
            ),
          ),
          _Float(
            child: Image.asset(
              'assets/iconmainmenu/case.png',
              width: size * 0.72,
              height: size * 0.72,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: size * 0.56,
                height: size * 0.56,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C120E),
                  borderRadius: BorderRadius.circular(size * 0.14),
                  border: Border.all(color: AppColors.brandNeon, width: 2.2),
                ),
                alignment: Alignment.center,
                child: const Text('NFT', style: TextStyle(color: AppColors.brandNeon, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Магазин — картинка shop.png из assets/iconmainmenu
class _NftBagArt extends StatelessWidget {
  final double size;
  const _NftBagArt({required this.size});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreen;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.78,
            height: size * 0.78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [green.withOpacity(0.28), Colors.transparent],
              ),
            ),
          ),
          _Float(
            delay: 400,
            child: Image.asset(
              'assets/iconmainmenu/shop.png',
              width: size * 0.72,
              height: size * 0.72,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: size * 0.52,
                height: size * 0.58,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C120E),
                  borderRadius: BorderRadius.circular(size * 0.12),
                  border: Border.all(color: green, width: 2.2),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_bag_outlined, color: green, size: size * 0.2),
                    Text('NFT', style: TextStyle(color: green, fontWeight: FontWeight.w900, fontSize: size * 0.15)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Плавное парение арта вверх-вниз.
class _Float extends StatefulWidget {
  final Widget child;
  final int delay;
  const _Float({required this.child, this.delay = 0});

  @override
  State<_Float> createState() => _FloatState();
}

class _FloatState extends State<_Float> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    if (widget.delay > 0) {
      final d = widget.delay / 2600;
      _c.value = d % 1.0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -5 * _c.value + 2.5),
        child: child,
      ),
      child: widget.child,
    );
  }
}
