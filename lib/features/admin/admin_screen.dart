import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/top_notify.dart';
import '../../core/widgets/user_badges.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../providers/balance_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/api_client.dart';

/// Админ-панель: игроки (баланс, гифты, галочки, бан), ивенты, музыка,
/// промокоды, рассылки, тикеты. Видна только админам.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final l10n = context.l10n;
    if (!user.isAdmin) {
      return Scaffold(
        body: BrandBackground(
          child: SafeArea(
            child: Column(
              children: [
                ScreenHeader(
                    title: l10n.t('ad_title'),
                    subtitle: l10n.t('ad_denied'),
                    showBack: true),
                Expanded(
                  child: Center(
                    child: Text(l10n.t('ad_denied'),
                        style: const TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tabs = [
      l10n.t('ad_tab_users'),
      l10n.t('ad_tab_events'),
      l10n.t('ad_tab_promo'),
      l10n.t('ad_tab_bc'),
      l10n.t('ad_tab_tickets'),
    ];
    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(
                  title: l10n.t('ad_title'),
                  subtitle: l10n.t('ad_sub'),
                  showBack: true,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++) ...[
                          _AdminTab(
                            label: tabs[i],
                            selected: _tab == i,
                            onTap: () => setState(() => _tab = i),
                          ),
                          if (i < tabs.length - 1)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: switch (_tab) {
                    0 => const _UsersTab(),
                    1 => const _EventsTab(),
                    2 => const _PromoTab(),
                    3 => const _BroadcastTab(),
                    _ => const _TicketsTab(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AdminTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? green.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? green
                : (isDark ? Colors.white12 : const Color(0xFFE3E8E3)),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? green : Colors.grey)),
      ),
    );
  }
}

void _snack(BuildContext ctx, String text) {
  try { TopNotify.show(ctx, text, success: true); } catch (_) {}
}

String _apiError(BuildContext ctx, ApiException e) {
  final l10n = ctx.l10n;
  switch (e.code) {
    case 'user_not_found':
      return l10n.t('ad_err_user');
    case 'item_not_found':
      return l10n.t('ad_err_item');
    case 'error_network':
      return l10n.t('error_network');
    default:
      return l10n.f('ad_err_generic', {'code': e.code});
  }
}

// ── Игроки ──

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  Map<String, dynamic>? _selected;
  final _coins = TextEditingController();
  String? _itemId;
  Set<String> _badges = {};

  @override
  void dispose() {
    _coins.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.adminUsers(q);
      if (!mounted) return;
      setState(() {
        _users = ((res['users'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } on ApiException catch (e) {
      if (mounted) _snack(context, _apiError(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pick(Map<String, dynamic> u) {
    setState(() {
      _selected = u;
      _badges =
          ((u['badges'] as List?) ?? const []).map((e) => e.toString()).toSet();
    });
  }

  Future<void> _grant() async {
    if (_selected == null) return;
    final coins = int.tryParse(_coins.text.trim()) ?? 0;
    if (coins == 0 && (_itemId == null || _itemId!.isEmpty)) {
      _snack(context, context.l10n.t('ad_grant_hint'));
      return;
    }
    try {
      await ApiClient.instance.adminGrant(
        nickname: _selected!['nickname'].toString(),
        coins: coins,
        itemId: _itemId,
      );
      if (!mounted) return;
      _snack(context, context.l10n.t('ad_granted'));
      _coins.clear();
      _search('');
    } on ApiException catch (e) {
      if (mounted) _snack(context, _apiError(context, e));
    }
  }

  Future<void> _saveBadges() async {
    if (_selected == null) return;
    try {
      final res = await ApiClient.instance.adminBadges(
        nickname: _selected!['nickname'].toString(),
        badges: _badges.toList(),
      );
      if (!mounted) return;
      setState(() => _selected!['badges'] = (res['user'] as Map)['badges']);
      _snack(context, context.l10n.t('ad_badges_saved'));
    } on ApiException catch (e) {
      if (mounted) _snack(context, _apiError(context, e));
    }
  }

  Future<void> _ban(bool banned) async {
    if (_selected == null) return;
    try {
      await ApiClient.instance.adminBan(
          nickname: _selected!['nickname'].toString(), banned: banned);
      if (!mounted) return;
      setState(() => _selected!['is_banned'] = banned);
      _snack(context,
          context.l10n.t(banned ? 'ad_banned' : 'ad_unbanned'));
    } on ApiException catch (e) {
      if (mounted) _snack(context, _apiError(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final catalog = ref.watch(catalogProvider);

    return Column(
      children: [
        EntranceAnim(
          index: 0,
          child: BrandCard(
            child: Column(
              children: [
                TextField(
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: l10n.t('ad_search'),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator()),
                for (final u in _users)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(u['nickname'].toString(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5)),
                        ),
                        UserBadgesRow(
                            badges: ((u['badges'] as List?) ?? const [])
                                .map((e) => e.toString())
                                .toList()),
                        if (u['is_banned'] == true)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Text('🚫',
                                style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    subtitle: Text(
                        l10n.f('ad_user_sub', {
                          'b': '${u['balance_coins']}',
                          'e': '${u['email']}'
                        }),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                    trailing: _selected?['nickname'] ==
                            u['nickname']
                        ? Icon(Icons.check_circle_rounded,
                            color: green)
                        : null,
                    onTap: () => _pick(u),
                  ),
              ],
            ),
          ),
        ),
        if (_selected != null) ...[
          const SizedBox(height: 14),
          EntranceAnim(
            index: 1,
            child: BrandCard(
              highlighted: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.f('ad_player',
                      {'nick': _selected!['nickname'].toString()}),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _coins,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.t('ad_coins'),
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _itemId,
                          hint: Text(l10n.t('ad_gift'),
                              style:
                                  const TextStyle(fontSize: 13)),
                          items: [
                            for (final c in catalog)
                              DropdownMenuItem(
                                value: c.id,
                                child: Text('${c.name} · ${c.priceInCoins}',
                                    style:
                                        const TextStyle(fontSize: 12)),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _itemId = v),
                          decoration: InputDecoration(
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _grant,
                      child: Text(l10n.t('ad_grant')),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(l10n.t('ad_badges'),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final b in UserBadges.all)
                        FilterChip(
                          avatar: UserBadges.assets[b] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: Image.asset(
                                    UserBadges.assets[b]!,
                                    width: 18,
                                    height: 18,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Text(UserBadges.icons[b] ?? ''),
                                  ),
                                )
                              : null,
                          label: Text(
                              UserBadges.assets[b] != null
                                  ? UserBadges.namesRu[b]!
                                  : '${UserBadges.icons[b]} ${UserBadges.namesRu[b]}',
                              style: const TextStyle(fontSize: 12)),
                          selected: _badges.contains(b),
                          onSelected: (v) => setState(() => v ? _badges.add(b) : _badges.remove(b)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saveBadges,
                          child: Text(l10n.t('ad_badges_save')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  (_selected!['is_banned'] == true)
                                      ? green
                                      : AppColors.danger),
                          onPressed: () => _ban(
                              _selected!['is_banned'] != true),
                          child: Text(l10n.t(
                              (_selected!['is_banned'] == true)
                                  ? 'ad_unban'
                                  : 'ad_ban')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Ивенты + музыка ──

class _EventsTab extends ConsumerStatefulWidget {
  const _EventsTab();

  @override
  ConsumerState<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends ConsumerState<_EventsTab> {
  Map<String, String> _settings = {};
  bool _loading = true;
  final _musicUrl = TextEditingController();

  static const _eventModes = ['auto', 'on', 'off'];
  static const _eventKeys = ['event_x2', 'event_x4', 'event_saves'];
  static const _eventNameKeys = {
    'event_x2': 'ad_ev_x2',
    'event_x4': 'ad_ev_x4',
    'event_saves': 'ad_ev_saves',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _musicUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.adminSettings();
      if (!mounted) return;
      final map = ((res['settings'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), v.toString()));
      setState(() {
        _settings = map;
        _musicUrl.text = map['music_url'] ?? '';
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _set(String key, String value) async {
    try {
      await ApiClient.instance.setAdminSetting(key, value);
      if (!mounted) return;
      setState(() => _settings[key] = value);
      ref.read(eventsProvider.notifier).refresh();
      ref.read(appSettingsProvider.notifier).refresh();
      _snack(context, context.l10n.t('ad_saved'));
    } on ApiException catch (e) {
      if (mounted) _snack(context, _apiError(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) {
      return const BrandCard(
        child: Center(
            child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator())),
      );
    }
    return Column(
      children: [
        EntranceAnim(
          index: 0,
          child: BrandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('ad_events'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  l10n.t('ad_events_hint'),
                  style:
                      const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                for (final key in _eventKeys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                              l10n.t(_eventNameKeys[key]!),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                        for (final m in _eventModes)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ChoiceChip(
                              label: Text(m,
                                  style:
                                      const TextStyle(fontSize: 12)),
                              selected: (_settings[key] ?? 'auto') == m,
                              onSelected: (_) => _set(key, m),
                            ),
                          ),
                      ],
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
                Text(l10n.t('ad_music'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                TextField(
                  controller: _musicUrl,
                  decoration: InputDecoration(
                    labelText: l10n.t('ad_music_url'),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _set('music_url', _musicUrl.text.trim()),
                        child: Text(l10n.t('ad_music_save')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _set(
                            'music_on',
                            (_settings['music_on'] == 'on')
                                ? 'off'
                                : 'on'),
                        child: Text(l10n.t(
                            (_settings['music_on'] == 'on')
                                ? 'ad_music_off'
                                : 'ad_music_on')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Промокоды ──

class _PromoTab extends ConsumerStatefulWidget {
  const _PromoTab();

  @override
  ConsumerState<_PromoTab> createState() => _PromoTabState();
}

class _PromoTabState extends ConsumerState<_PromoTab> {
  List<Map<String, dynamic>> _promos = [];
  bool _loading = true;
  final _code = TextEditingController();
  final _coins = TextEditingController();
  final _maxUses = TextEditingController();
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    _coins.dispose();
    _maxUses.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.adminPromocodes();
      if (!mounted) return;
      setState(() {
        _promos = ((res['promocodes'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final coins = int.tryParse(_coins.text.trim()) ?? 0;
    if (_code.text.trim().isEmpty || coins <= 0) {
      _snack(context, context.l10n.t('ad_promo_hint'));
      return;
    }
    try {
      await ApiClient.instance.createPromocode(
        code: _code.text.trim(),
        coins: coins,
        maxUses: int.tryParse(_maxUses.text.trim()),
        isActive: _active,
      );
      if (!mounted) return;
      _code.clear();
      _coins.clear();
      _maxUses.clear();
      await _load();
      _snack(context, context.l10n.t('ad_promo_created'));
    } on ApiException catch (e) {
      if (mounted) _snack(context, _apiError(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        EntranceAnim(
          index: 0,
          child: BrandCard(
            highlighted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('ad_promo_new'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'CODE',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _coins,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.t('ad_promo_coins'),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _maxUses,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.t('ad_promo_limit'),
                          hintText: '∞',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilterChip(
                      label: Text(l10n.t(
                          _active ? 'ad_promo_active' : 'ad_promo_off')),
                      selected: _active,
                      onSelected: (v) =>
                          setState(() => _active = v),
                    ),
                    const Spacer(),
                    FilledButton(
                        onPressed: _create,
                        child: Text(l10n.t('ad_promo_create'))),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const BrandCard(
              child: Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator()))),
        for (var i = 0; i < _promos.length; i++)
          Padding(
            padding: EdgeInsets.only(
                bottom: i == _promos.length - 1 ? 0 : 10),
            child: EntranceAnim(
              index: 1 + i,
              child: BrandCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            _promos[i]['code'].toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14),
                          ),
                          Text(
                            context.l10n.f('ad_promo_uses', {
                              'coins': '${_promos[i]['coins']}',
                              'used': '${_promos[i]['used_count']}',
                              'max': _promos[i]['max_uses'] != null
                                  ? context.l10n.f('ad_promo_max',
                                      {'v': '${_promos[i]['max_uses']}'})
                                  : '',
                            }),
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      (_promos[i]['is_active'] == true)
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: (_promos[i]['is_active'] == true)
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Рассылка ──

class _BroadcastTab extends ConsumerStatefulWidget {
  const _BroadcastTab();

  @override
  ConsumerState<_BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends ConsumerState<_BroadcastTab> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiClient.instance.broadcast(text);
      if (!mounted) return;
      _ctrl.clear();
      _snack(context, context.l10n.t('ad_bc_sent'));
    } on ApiException catch (e) {
      if (mounted) _snack(context, _apiError(context, e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(userProvider);
    final l10n = context.l10n;
    return EntranceAnim(
      index: 0,
      child: BrandCard(
        highlighted: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.f('ad_bc_title', {'nick': me.displayName}),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: l10n.t('ad_bc_hint'),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _send,
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(l10n.t('ad_bc_send')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Тикеты ──

class _TicketsTab extends ConsumerStatefulWidget {
  const _TicketsTab();

  @override
  ConsumerState<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends ConsumerState<_TicketsTab> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.adminTickets(_status);
      if (!mounted) return;
      setState(() {
        _tickets = ((res['tickets'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statuses = {
      '': l10n.t('ad_tk_all'),
      'open': l10n.t('ad_tk_open'),
      'answered': l10n.t('ad_tk_answered'),
      'closed': l10n.t('ad_tk_closed'),
    };
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final e in statuses.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value, style: const TextStyle(fontSize: 12)),
                    selected: _status == e.key,
                    onSelected: (_) {
                      setState(() => _status = e.key);
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const BrandCard(
              child: Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator()))),
        if (!_loading && _tickets.isEmpty)
          BrandCard(
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(l10n.t('ad_tk_empty'),
                          style:
                              const TextStyle(color: Colors.grey))))),
        for (final t in _tickets)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: BrandCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: () => context.push('/support/${t['id']}'),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['subject'].toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13.5)),
                        Text(
                          '${t['author_nickname']} · ${(t['last_text']?.toString() ?? '').isEmpty ? '—' : t['last_text']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const GreenArrowBtn(size: 26),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
