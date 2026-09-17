import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/top_notify.dart';
import '../../core/widgets/user_badges.dart';
import '../../data/models/nft_item.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../providers/balance_provider.dart';
import '../../services/api_client.dart';
import '../auth/providers/auth_provider.dart';
import '../upgrader/widgets/nft_item_card.dart';

/// Свой профиль: по центру аватар, ник со статусами, баланс,
/// статистика, витрина гифтов, действия.
class ProfileWalletScreen extends ConsumerStatefulWidget {
  const ProfileWalletScreen({super.key});

  @override
  ConsumerState<ProfileWalletScreen> createState() =>
      _ProfileWalletScreenState();
}

class _ProfileWalletScreenState extends ConsumerState<ProfileWalletScreen> {
  List<Map<String, dynamic>> _rounds = [];
  bool _loadingRounds = true;
  @override
  void initState() {
    super.initState();
    _loadRounds();
  }

  Future<void> _loadRounds() async {
    try {
      final res = await ApiClient.instance.history();
      if (!mounted) return;
      setState(() {
        _rounds = ((res['rounds'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingRounds = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final inventory = ref.watch(inventoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;

    final showcase = [...inventory]
      ..sort((a, b) => b.priceInCoins.compareTo(a.priceInCoins));
    final wins = _rounds.where((r) => r['success'] == true).length;

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(
                  title: l10n.t('profile_title'),
                  subtitle: l10n.t('pf_sub'),
                  showBack: true,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // ── Центр: аватар + ник + статусы ──
                      EntranceAnim(
                        index: 0,
                        child: BrandCard(
                          highlighted: true,
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 92,
                                    height: 92,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          green.withOpacity(0.35),
                                          Colors.transparent
                                        ],
                                      ),
                                    ),
                                  ),
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundColor: green.withOpacity(0.14),
                                    backgroundImage: user.avatarUrl != null
                                        ? NetworkImage(user.avatarUrl!)
                                        : null,
                                    child: user.avatarUrl == null
                                        ? Text(
                                            user.displayName.isEmpty
                                                ? '?'
                                                : user.displayName.characters.first
                                                    .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 30,
                                              fontWeight: FontWeight.w900,
                                              color: green,
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.displayName,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  UserBadgesRow(
                                      badges: user.badges,
                                      size: 17,
                                      locale: locale),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: green.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
                                child: Text('ID: ${user.id.length > 8 ? user.id.substring(0, 8) : user.id}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: green)),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.monetization_on,
                                      size: 17, color: green),
                                  const SizedBox(width: 5),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(
                                        begin: 0,
                                        end: user.balanceCoins.toDouble()),
                                    duration:
                                        const Duration(milliseconds: 600),
                                    builder: (_, v, __) => Text(
                                      v.toStringAsFixed(0),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _Stat(
                                      value: '${user.playtimeHours}',
                                      label: l10n.t('pf_hours')),
                                  _Stat(
                                      value: '$wins',
                                      label: l10n.t('pf_wins')),
                                  _Stat(
                                      value: '${_rounds.length}',
                                      label: l10n.t('pf_rounds')),
                                  _Stat(
                                      value: '${inventory.length}',
                                      label: l10n.t('pf_gifts')),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ProfileBtn(
                                      label: l10n.t('pf_topup'),
                                      icon: Icons.add_rounded,
                                      fill: true,
                                      green: green,
                                      onTap: () =>
                                          context.push('/topup'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _ProfileBtn(
                                      label: l10n.t(
                                          'inventory_title'),
                                      icon: Icons.backpack_outlined,
                                      fill: false,
                                      green: green,
                                      onTap: () =>
                                          context.push('/inventory'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Витрина гифтов ──
                      EntranceAnim(
                        index: 1,
                        child: BrandCard(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('🎁',
                                      style:
                                          TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Text(l10n.t('pf_showcase'),
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight:
                                              FontWeight.w800)),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () =>
                                        context.push('/inventory'),
                                    child: Text(l10n.t('pf_all'),
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w700,
                                            color: green)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (showcase.isEmpty)
                                Center(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            vertical: 12),
                                    child: Text(
                                      l10n.t(
                                          'pf_showcase_empty'),
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12.5),
                                    ),
                                  ),
                                )
                              else
                                SizedBox(
                                  height: 150,
                                  child: ListView.separated(
                                    scrollDirection:
                                        Axis.horizontal,
                                    itemCount:
                                        showcase.take(6).length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (_, i) =>
                                        NftItemCard(
                                      item: showcase[i],
                                      width: 108,
                                      onTap: () => context
                                          .push('/inventory'),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Промокод (ввод прямо в профиле) ──
                      EntranceAnim(
                        index: 2,
                        child: const _PromoCard(),
                      ),
                      const SizedBox(height: 14),
                      // ── Действия ──
                      EntranceAnim(
                        index: 3,
                        child: BrandCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _ActionTile(
                                icon: Icons.history_rounded,
                                label: l10n.t('history_title'),
                                onTap: () =>
                                    context.push('/history'),
                              ),
                              _ActionTile(
                                icon: Icons.support_agent_outlined,
                                label: l10n.t('se_support'),
                                onTap: () =>
                                    context.push('/support'),
                              ),
                              _ActionTile(
                                icon: Icons.settings_outlined,
                                label: l10n.t('settings_title'),
                                onTap: () =>
                                    context.push('/settings'),
                              ),
                              if (user.isAdmin)
                                _ActionTile(
                                  icon: Icons
                                      .admin_panel_settings_outlined,
                                  label: l10n.t('se_admin'),
                                  highlight: true,
                                  onTap: () =>
                                      context.push('/admin'),
                                ),
                              _ActionTile(
                                icon: Icons.logout_rounded,
                                label: l10n.t('auth_logout'),
                                danger: true,
                                last: true,
                                onTap: () => ref
                                    .read(authProvider.notifier)
                                    .logout(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── История ──
                      EntranceAnim(
                        index: 3,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('pf_rounds_title'),
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            if (_loadingRounds)
                              const Center(
                                  child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child:
                                          CircularProgressIndicator())),
                            if (!_loadingRounds &&
                                _rounds.isEmpty)
                              BrandCard(
                                child: Center(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            vertical: 12),
                                    child: Text(
                                        l10n.t('pf_no_rounds'),
                                        style: const TextStyle(
                                            color: Colors.grey)),
                                  ),
                                ),
                              ),
                            for (final r in _rounds.take(10))
                              _RoundTile(round: r),
                          ],
                        ),
                      ),
                    ],
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

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _ProfileBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool fill;
  final Color green;
  final VoidCallback onTap;
  const _ProfileBtn({
    required this.label,
    required this.icon,
    required this.fill,
    required this.green,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: fill ? green : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: green),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 17, color: fill ? Colors.black : green),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: fill ? Colors.black : green)),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool highlight;
  final bool last;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.highlight = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = danger
        ? AppColors.danger
        : highlight
            ? (isDark
                ? AppColors.brandNeon
                : AppColors.brandGreenDeep)
            : null;
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: color, size: 20),
          title: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: color)),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: Colors.grey, size: 20),
          onTap: onTap,
          dense: true,
        ),
        if (!last) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

class _PromoCard extends ConsumerStatefulWidget {
  const _PromoCard();
  @override
  ConsumerState<_PromoCard> createState() => _PromoCardState();
}

class _PromoCardState extends ConsumerState<_PromoCard> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _ctrl.text.trim();
    if (code.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final res = await ApiClient.instance.redeemPromocode(code);
      final coins = (res['coins'] as num?)?.toInt() ?? 0;
      final balance = (res['balance_coins'] as num?)?.toInt();
      if (balance != null) ref.read(userProvider.notifier).setBalance(balance);
      if (!mounted) return;
      _ctrl.clear();
      TopNotify.show(context, context.l10n.f('promo_success', {'coins': '$coins'}), success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final key = switch (e.code) {
        'invalid_code' => 'promo_invalid',
        'expired' => 'promo_expired',
        'exhausted' => 'promo_exhausted',
        'already_used' => 'promo_used',
        _ => 'error_generic',
      };
      TopNotify.show(context, context.l10n.t(key), success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 30, height: 30, decoration: BoxDecoration(color: AppColors.brandGreen.withOpacity(0.13), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.card_giftcard_rounded, size: 16, color: AppColors.brandGreenDeep)),
            const SizedBox(width: 10),
            Text(context.l10n.t('promo_title'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF101410))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _ctrl, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(hintText: 'PROMO-2024', prefixIcon: const Icon(Icons.card_giftcard_outlined, size: 19), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))), onSubmitted: (_) => _redeem())),
            const SizedBox(width: 10),
            SizedBox(height: 50, child: FilledButton(onPressed: _busy ? null : _redeem, style: FilledButton.styleFrom(backgroundColor: AppColors.brandGreen), child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(context.l10n.t('promo_apply')))),
          ]),
        ],
      ),
    );
  }
}

class _RoundTile extends StatelessWidget {
  final Map<String, dynamic> round;
  const _RoundTile({required this.round});

  @override
  Widget build(BuildContext context) {
    final success = round['success'] == true;
    final l10n = context.l10n;
    final color = success ? AppColors.success : AppColors.danger;
    final chance = (round['chance_percent'] as num?)?.toDouble() ?? 0;
    DateTime? at;
    try {
      at = DateTime.parse(round['created_at'].toString()).toLocal();
    } catch (_) {}
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.03)
            : const Color(0xFFF3F6F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white12
                : const Color(0xFFE3E8E3)),
      ),
      child: Row(
        children: [
          Icon(success ? Icons.check_circle : Icons.cancel, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${success ? l10n.t('pf_win') : l10n.t('pf_lose')} → ${round['target_name'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  '${chance.toStringAsFixed(1)}% · ${at != null ? DateFormat('d MMM, HH:mm').format(at) : ''}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '${(round['profit_coins'] as num?)?.toInt() ?? 0}',
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

/// Чужой профиль: центр, статусы, статистика, витрина.
class PublicProfileScreen extends ConsumerStatefulWidget {
  final String nickname;
  const PublicProfileScreen({super.key, required this.nickname});

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.publicProfile(widget.nickname);
      if (!mounted) return;
      setState(
          () => _profile = Map<String, dynamic>.from(res['profile'] as Map));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(
                  title: widget.nickname,
                  subtitle: l10n.t('pf_public_sub'),
                  showBack: true,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: _loading
                      ? const Center(
                          child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator()))
                      : _profile == null
                          ? BrandCard(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(l10n.t('pf_not_found'),
                                      style: const TextStyle(
                                          color: Colors.grey)),
                                ),
                              ),
                            )
                          : _PublicBody(
                              profile: _profile!,
                              green: green,
                              locale: locale,
                              nickname: widget.nickname,
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

class _PublicBody extends StatelessWidget {
  final Map<String, dynamic> profile;
  final Color green;
  final String locale;
  final String nickname;
  const _PublicBody({
    required this.profile,
    required this.green,
    required this.locale,
    required this.nickname,
  });

  @override
  Widget build(BuildContext context) {
    final stats =
        Map<String, dynamic>.from(profile['stats'] as Map? ?? {});
    final l10n = context.l10n;
    final showcase = ((profile['showcase'] as List?) ?? const [])
        .map((e) => NftItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final badges = ((profile['badges'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();

    return Column(
      children: [
        EntranceAnim(
          index: 0,
          child: BrandCard(
            highlighted: true,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: green.withOpacity(0.14),
                  backgroundImage: profile['avatar_url'] != null
                      ? NetworkImage(profile['avatar_url'].toString())
                      : null,
                  child: profile['avatar_url'] == null
                      ? Text(
                          nickname.characters.first.toUpperCase(),
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: green),
                        )
                      : null,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(nickname,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                    ),
                    UserBadgesRow(
                        badges: badges, size: 17, locale: locale),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(
                        value: '${profile['hours'] ?? 0}',
                        label: l10n.t('pf_hours')),
                    _Stat(
                        value: '${stats['wins'] ?? 0}',
                        label: l10n.t('pf_wins')),
                    _Stat(
                        value: '${stats['rounds'] ?? 0}',
                        label: l10n.t('pf_rounds')),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: _ProfileBtn(
                    label: l10n.t('pf_offer'),
                    icon: Icons.swap_horiz_rounded,
                    fill: true,
                    green: green,
                    onTap: () => context.push('/trade'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        EntranceAnim(
          index: 1,
          child: BrandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('pf_showcase_pub'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (showcase.isEmpty)
                  Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l10n.t('pf_showcase_empty_pub'),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12.5)),
                    ),
                  )
                else
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: showcase.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 10),
                      itemBuilder: (_, i) => NftItemCard(
                        item: showcase[i],
                        width: 108,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
