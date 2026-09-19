import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/top_notify.dart';
import '../../core/widgets/user_badges.dart';
import '../../data/models/user_model.dart';
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
      'Гифты',
      'Кейсы',
      'Ежедневки',
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
                    1 => const _GiftsTab(),
                    2 => const _CasesTab(),
                    3 => const _DailyAdminTab(),
                    4 => const _EventsTab(),
                    5 => const _PromoTab(),
                    6 => const _BroadcastTab(),
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
      if (mounted) _snack(context, context.l10n.t('ad_grant_hint'));
      return;
    }
    try {
      await ApiClient.instance.adminGrant(
        nickname: _selected!['nickname'].toString(),
        coins: coins,
        itemId: _itemId,
      );
      if (!mounted) return;
      // Не крашим — TopNotify безопасно, даже если контекст уже не в дереве
      try { _snack(context, context.l10n.t('ad_granted')); } catch (_) {}
      _coins.clear();
      if (mounted) {
        // Обновляем список игроков без падения
        try { await _search(''); } catch (_) {}
        // Если выдали себе — обновляем свой инвентарь/баланс без кика
        try {
          final meNick = ref.read(userProvider).displayName.toLowerCase();
          final targetNick = _selected!['nickname'].toString().toLowerCase();
          if (meNick == targetNick) {
            await ref.read(inventoryProvider.notifier).refresh();
            final meRes = await ApiClient.instance.me();
            final uj = (meRes['user'] ?? meRes) as Map<String, dynamic>?;
            if (uj != null) {
              // ignore: avoid_dynamic_calls
              ref.read(userProvider.notifier).setUser(AppUser.fromServer(uj as Map<String, dynamic>));
            }
          }
        } catch (_) {}
      }
    } on ApiException catch (e) {
      if (mounted) {
        try { _snack(context, _apiError(context, e)); } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        try { _snack(context, 'Ошибка: $e'); } catch (_) {}
      }
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
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon((_selected!['hide_from_top'] == true) ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 16),
                        label: Text((_selected!['hide_from_top'] == true) ? 'Показать в топе' : 'Скрыть из топа'),
                        onPressed: () async {
                          final hide = _selected!['hide_from_top'] != true;
                          try {
                            await ApiClient.instance.adminHideTop(nickname: _selected!['nickname'].toString(), hide: hide);
                            setState(() => _selected!['hide_from_top'] = hide);
                            _snack(context, hide ? 'Скрыт из топа' : 'Показан в топе');
                          } catch (e) {
                            if (mounted) _snack(context, 'Ошибка');
                          }
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: const Text('Обнулить всех игроков (wipe)'),
                      onPressed: () async {
                        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Обнулить всех?'), content: const Text('Удалит инвентарь, раунды, баланс (кроме админов). Подтвердите WIPE.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('WIPE'))]));
                        if (ok != true) return;
                        try {
                          await ApiClient.instance.adminWipe();
                          if (mounted) _snack(context, 'Все игроки обнулены ✅');
                        } catch (e) {
                          if (mounted) _snack(context, 'Ошибка wipe');
                        }
                      },
                    ),
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

// ── Гифты CRUD ──
class _GiftsTab extends ConsumerStatefulWidget {
  const _GiftsTab();
  @override
  ConsumerState<_GiftsTab> createState() => _GiftsTabState();
}
class _GiftsTabState extends ConsumerState<_GiftsTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  final _search = TextEditingController();
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.adminItems(_search.text.trim());
      if (!mounted) return;
      setState(() => _items = ((res['items'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {} finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _showEdit({Map<String, dynamic>? item}) async {
    final isNew = item == null;
    final idCtrl = TextEditingController(text: item?['id']?.toString() ?? '');
    final nameCtrl = TextEditingController(text: item?['name']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: item?['price_coins']?.toString() ?? '');
    final rarityCtrl = ValueNotifier<String>(item?['rarity']?.toString() ?? 'common');
    final collCtrl = TextEditingController(text: item?['collection']?.toString() ?? '');
    final imgCtrl = TextEditingController(text: item?['image_asset']?.toString() ?? '');
    final urlCtrl = TextEditingController(text: item?['image_url']?.toString() ?? '');
    final active = ValueNotifier<bool>(item?['is_active'] ?? true);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isNew ? 'Новый гифт' : 'Редактировать'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: idCtrl, enabled: isNew, decoration: const InputDecoration(labelText: 'ID (present, cup...)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Цена (монеты)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        ValueListenableBuilder<String>(valueListenable: rarityCtrl, builder: (_, v, __) => DropdownButtonFormField<String>(value: v, decoration: const InputDecoration(labelText: 'Редкость', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'common', child: Text('Common')), DropdownMenuItem(value: 'rare', child: Text('Rare')), DropdownMenuItem(value: 'epic', child: Text('Epic')), DropdownMenuItem(value: 'legendary', child: Text('Legendary'))], onChanged: (x) => rarityCtrl.value = x ?? 'common')),
        const SizedBox(height: 8),
        TextField(controller: collCtrl, decoration: const InputDecoration(labelText: 'Коллекция', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: imgCtrl, decoration: const InputDecoration(labelText: 'image_asset (present.png)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'image_url (опц.)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        ValueListenableBuilder<bool>(valueListenable: active, builder: (_, v, __) => SwitchListTile(title: const Text('Активен'), value: v, onChanged: (x) => active.value = x)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isNew ? 'Создать' : 'Сохранить'))],
    ));
    if (ok != true) return;
    try {
      if (isNew) {
        await ApiClient.instance.createAdminItem({'id': idCtrl.text.trim(), 'name': nameCtrl.text.trim(), 'price_coins': int.tryParse(priceCtrl.text) ?? 0, 'rarity': rarityCtrl.value, 'collection': collCtrl.text.trim(), 'image_asset': imgCtrl.text.trim(), 'image_url': urlCtrl.text.trim()});
      } else {
        await ApiClient.instance.updateAdminItem(item!['id'].toString(), {'name': nameCtrl.text.trim(), 'price_coins': int.tryParse(priceCtrl.text) ?? 0, 'rarity': rarityCtrl.value, 'collection': collCtrl.text.trim(), 'image_asset': imgCtrl.text.trim(), 'image_url': urlCtrl.text.trim(), 'is_active': active.value});
      }
      _snack(context, 'Сохранено ✅');
      _load();
      ref.read(catalogProvider.notifier).refresh();
    } on ApiException catch (e) { _snack(context, _apiError(context, e)); }
  }
  Future<void> _delete(String id) async {
    try { await ApiClient.instance.deleteAdminItem(id); _snack(context, 'Удалено'); _load(); ref.read(catalogProvider.notifier).refresh(); } on ApiException catch (e) { _snack(context, _apiError(context, e)); }
  }
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      BrandCard(child: Row(children: [
        Expanded(child: TextField(controller: _search, decoration: InputDecoration(hintText: 'Поиск по id/имени', prefixIcon: const Icon(Icons.search, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), onSubmitted: (_) => _load())),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 16), label: const Text('Найти')),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(onPressed: () => _showEdit(), icon: const Icon(Icons.add), label: const Text('Новый')),
      ])),
      const SizedBox(height: 12),
      if (_loading) const BrandCard(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))),
      for (final it in _items) Padding(padding: const EdgeInsets.only(bottom: 8), child: BrandCard(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${it['name']} (${it['id']})', style: const TextStyle(fontWeight: FontWeight.w800)), 
          Text('${it['price_coins']} монет · ${it['rarity']} ${it['is_active']==false ? '· скрыт' : ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showEdit(item: it)),
        IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => _delete(it['id'].toString())),
      ]))),
    ]);
  }
}

// ── Кейсы CRUD ──
class _CasesTab extends ConsumerStatefulWidget {
  const _CasesTab();
  @override
  ConsumerState<_CasesTab> createState() => _CasesTabState();
}
class _CasesTabState extends ConsumerState<_CasesTab> {
  List<Map<String, dynamic>> _cases = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.adminCasesAdmin();
      if (!mounted) return;
      setState(() => _cases = ((res['cases'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {} finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _showEdit({Map<String, dynamic>? c}) async {
    final isNew = c == null;
    final idCtrl = TextEditingController(text: c?['id']?.toString() ?? '');
    final nameCtrl = TextEditingController(text: c?['name']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: c?['price_nc']?.toString() ?? '');
    final imgCtrl = TextEditingController(text: c?['image_asset']?.toString() ?? '');
    final sortCtrl = TextEditingController(text: c?['sort_order']?.toString() ?? '0');
    final active = ValueNotifier<bool>(c?['is_active'] ?? true);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isNew ? 'Новый кейс' : 'Редактировать кейс'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: idCtrl, enabled: isNew, decoration: const InputDecoration(labelText: 'ID (case_mega)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Цена NC', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: imgCtrl, decoration: const InputDecoration(labelText: 'image_asset (case_xxx.png)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: sortCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Сортировка', border: OutlineInputBorder())),
        ValueListenableBuilder<bool>(valueListenable: active, builder: (_, v, __) => SwitchListTile(title: const Text('Активен'), value: v, onChanged: (x) => active.value = x)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isNew ? 'Создать' : 'Сохранить'))],
    ));
    if (ok != true) return;
    try {
      if (isNew) {
        await ApiClient.instance.createAdminCase({'id': idCtrl.text.trim(), 'name': nameCtrl.text.trim(), 'price_nc': int.tryParse(priceCtrl.text) ?? 0, 'image_asset': imgCtrl.text.trim(), 'sort_order': int.tryParse(sortCtrl.text) ?? 0});
      } else {
        await ApiClient.instance.updateAdminCase(c!['id'].toString(), {'name': nameCtrl.text.trim(), 'price_nc': int.tryParse(priceCtrl.text) ?? 0, 'image_asset': imgCtrl.text.trim(), 'sort_order': int.tryParse(sortCtrl.text) ?? 0, 'is_active': active.value});
      }
      _snack(context, 'Сохранено ✅'); _load();
    } on ApiException catch (e) { _snack(context, _apiError(context, e)); }
  }
  Future<void> _editItems(String caseId) async {
    List<Map<String, dynamic>> items = [];
    try {
      final res = await ApiClient.instance.adminCaseItems(caseId);
      items = ((res['items'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    final catalog = ref.read(catalogProvider);
    // локальная копия для редактирования — теперь шанс редактируемый для любого кейса
    final editList = items.map((e) => {'item_id': e['item_id'].toString(), 'drop_chance': e['drop_chance'].toString()}).toList();
    final chanceCtrls = <TextEditingController>[];
    for (final e in editList) {
      chanceCtrls.add(TextEditingController(text: e['drop_chance'].toString()));
    }
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Предметы кейса $caseId — можно менять любой кейс'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (editList.isEmpty) const Text('Пусто — добавь предметы', style: TextStyle(color: Colors.grey)),
        for (int i = 0; i < editList.length; i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
          Expanded(flex: 3, child: Text(editList[i]['item_id'].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          SizedBox(width: 90, child: TextField(controller: chanceCtrls[i], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '%', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)), onChanged: (v) => editList[i]['drop_chance'] = v)),
          IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setS(() { editList.removeAt(i); chanceCtrls.removeAt(i).dispose(); })),
        ])),
        const Divider(),
        DropdownButtonFormField<String>(hint: const Text('Гифт'), items: [for (final it in catalog) DropdownMenuItem(value: it.id, child: Text('${it.name} ${it.priceInCoins}'))], onChanged: (v) { if (v != null) setS(() { editList.add({'item_id': v, 'drop_chance': '10'}); chanceCtrls.add(TextEditingController(text: '10')); }); }, decoration: const InputDecoration(labelText: 'Добавить гифт в этот кейс', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        Builder(builder: (_) {
          final sum = editList.fold<double>(0, (s,e)=> s + (double.tryParse(e['drop_chance'].toString())??0));
          final ok = (sum - 100).abs() < 0.01;
          return Text('Сумма: ${sum.toStringAsFixed(2)}% ${ok ? '✓' : '(должно быть 100%)'}', style: TextStyle(fontSize: 11, color: ok ? Colors.green : Colors.red, fontWeight: FontWeight.w700));
        }),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')), FilledButton(onPressed: () async {
        for (int i=0;i<editList.length;i++) editList[i]['drop_chance'] = chanceCtrls[i].text;
        final payload = editList.map((e) => {'item_id': e['item_id'], 'drop_chance': double.tryParse(e['drop_chance'].toString()) ?? 0}).toList();
        try { await ApiClient.instance.setAdminCaseItems(caseId, payload); _snack(context, 'Сохранено ✅ для $caseId'); Navigator.pop(ctx); } on ApiException catch (e) { _snack(context, _apiError(context, e)); }
      }, child: const Text('Сохранить'))],
    )));
    for (final c in chanceCtrls) c.dispose();
  }
  Future<void> _delete(String id) async {
    try { await ApiClient.instance.deleteAdminCase(id); _snack(context, 'Удалено'); _load(); } on ApiException catch (e) { _snack(context, _apiError(context, e)); }
  }
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      BrandCard(child: Row(children: [const Text('Кейсы', style: TextStyle(fontWeight: FontWeight.w800)), const Spacer(), FilledButton.tonalIcon(onPressed: () => _showEdit(), icon: const Icon(Icons.add), label: const Text('Новый'))])),
      const SizedBox(height: 12),
      if (_loading) const BrandCard(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))),
      for (final c in _cases) Padding(padding: const EdgeInsets.only(bottom: 8), child: BrandCard(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${c['name']} (${c['id']}) — ${c['price_nc']} NC ${c['is_active']==false ? '· скрыт' : ''}', style: const TextStyle(fontWeight: FontWeight.w800))),
          IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showEdit(c: c)),
          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => _delete(c['id'].toString())),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          OutlinedButton(onPressed: () => _editItems(c['id'].toString()), child: const Text('Предметы')),
        ]),
      ]))),
    ]);
  }
}

// ── Ежедневки ──
class _DailyAdminTab extends ConsumerStatefulWidget {
  const _DailyAdminTab();
  @override
  ConsumerState<_DailyAdminTab> createState() => _DailyAdminTabState();
}
class _DailyAdminTabState extends ConsumerState<_DailyAdminTab> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dailyTasksAdmin();
      if (!mounted) return;
      setState(() => _tasks = ((res['tasks'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {} finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _edit({Map<String, dynamic>? t}) async {
    final isNew = t == null;
    final idCtrl = TextEditingController(text: t?['id']?.toString() ?? '');
    final titleCtrl = TextEditingController(text: t?['title']?.toString() ?? '');
    final descCtrl = TextEditingController(text: t?['description']?.toString() ?? '');
    final coinsCtrl = TextEditingController(text: t?['reward_coins']?.toString() ?? '100');
    final itemCtrl = TextEditingController(text: t?['reward_item_id']?.toString() ?? '');
    final typeCtrl = ValueNotifier<String>(t?['requirement_type']?.toString() ?? 'login');
    final countCtrl = TextEditingController(text: t?['requirement_count']?.toString() ?? '1');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isNew ? 'Новое задание' : 'Редактировать'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: idCtrl, enabled: isNew, decoration: const InputDecoration(labelText: 'ID', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Описание', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: coinsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Монеты награда', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'Гифт reward_item_id (опц)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        ValueListenableBuilder<String>(valueListenable: typeCtrl, builder: (_, v, __) => DropdownButtonFormField<String>(value: v, decoration: const InputDecoration(labelText: 'Тип', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'login', child: Text('login')), DropdownMenuItem(value: 'upgrade', child: Text('upgrade')), DropdownMenuItem(value: 'case_open', child: Text('case_open')), DropdownMenuItem(value: 'trade', child: Text('trade'))], onChanged: (x) => typeCtrl.value = x ?? 'login')),
        const SizedBox(height: 8),
        TextField(controller: countCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Количество', border: OutlineInputBorder())),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isNew ? 'Создать' : 'Сохранить'))],
    ));
    if (ok != true) return;
    try {
      await ApiClient.instance.createDailyTask({'id': idCtrl.text.trim(), 'title': titleCtrl.text.trim(), 'description': descCtrl.text.trim(), 'reward_coins': int.tryParse(coinsCtrl.text) ?? 0, 'reward_item_id': itemCtrl.text.trim().isEmpty ? null : itemCtrl.text.trim(), 'requirement_type': typeCtrl.value, 'requirement_count': int.tryParse(countCtrl.text) ?? 1});
      _snack(context, 'Сохранено ✅'); _load();
    } on ApiException catch (e) { _snack(context, _apiError(context, e)); }
  }
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      BrandCard(child: Row(children: [const Text('Ежедневные задания', style: TextStyle(fontWeight: FontWeight.w800)), const Spacer(), FilledButton.tonalIcon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Новое'))])),
      const SizedBox(height: 12),
      if (_loading) const BrandCard(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))),
      for (final t in _tasks) Padding(padding: const EdgeInsets.only(bottom: 8), child: BrandCard(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${t['title']} (${t['id']})', style: const TextStyle(fontWeight: FontWeight.w800)),
          Text('${t['description']} · ${t['reward_coins']} монет ${t['reward_item_id'] != null ? '+ гифт' : ''} · ${t['requirement_type']} x${t['requirement_count']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _edit(t: t)),
      ]))),
    ]);
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
  List<String> _musicFiles = [];

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

  bool _uploadingMusic = false;
  @override
  void dispose() {
    _musicUrl.dispose();
    super.dispose();
  }

  Future<void> _uploadMusic() async {
    try {
      // ignore: avoid_web_libraries_in_flutter
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a', 'aac'], withData: false);
      if (res == null || res.files.isEmpty) return;
      final path = res.files.single.path;
      if (path == null) {
        _snack(context, 'Не удалось прочитать файл');
        return;
      }
      setState(() => _uploadingMusic = true);
      final r = await ApiClient.instance.uploadMusic(path);
      if (!mounted) return;
      final url = r['url']?.toString() ?? r['path']?.toString() ?? '';
      if (url.isNotEmpty) {
        setState(() {
          _musicUrl.text = url;
          _settings['music_url'] = url;
          _settings['music_on'] = 'on';
        });
        ref.read(appSettingsProvider.notifier).refresh();
        ref.read(eventsProvider.notifier).refresh();
        _snack(context, 'Музыка загружена и включена ✅');
        _load();
      } else {
        _snack(context, 'Загружено, но URL не получен');
      }
    } on ApiException catch (e) {
      if (mounted) _snack(context, _apiError(context, e));
    } catch (e) {
      if (mounted) _snack(context, 'Ошибка загрузки: $e');
    } finally {
      if (mounted) setState(() => _uploadingMusic = false);
    }
  }

  Future<void> _playMusicFile(String file) async {
    try {
      await ApiClient.instance.musicPlay(file);
      if (!mounted) return;
      _snack(context, 'Включено: $file 🔊');
      _load();
    } on ApiException catch (e) {
      if (mounted) _snack(context, _apiError(context, e));
    }
  }

  Future<void> _stopMusic() async {
    try {
      await ApiClient.instance.musicStop();
      if (!mounted) return;
      _snack(context, 'Музыка остановлена ⏹️');
      _load();
    } on ApiException catch (e) {
      if (mounted) _snack(context, _apiError(context, e));
    }
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
      // список музыки из папки server/public/music
      try {
        final m = await ApiClient.instance.musicList();
        if (mounted) setState(() => _musicFiles = ((m['files'] as List?) ?? const []).map((e) => e.toString()).toList());
      } catch (_) {}
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _set(String key, String value) async {
    // Ручное включение с выбором времени — спрашиваем на сколько включить
    if (value == 'on' && (key == 'event_x2' || key == 'event_saves' || key == 'event_x4')) {
      final minutes = await showDialog<int>(context: context, builder: (ctx) => SimpleDialog(title: const Text('На сколько включить?'), children: [
        for (final m in [15, 30, 60, 120, 360, 720, 1440])
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, m), child: Text('${m < 60 ? '$m мин' : '${m ~/ 60} ч'}')),
      ]));
      if (minutes == null) return;
      try {
        final evKey = key.replaceFirst('event_', '');
        await ApiClient.instance.adminEventOn(evKey, minutes);
        if (!mounted) return;
        setState(() => _settings[key] = value);
        ref.read(eventsProvider.notifier).refresh();
        _snack(context, 'Включено на ${minutes}м ✅');
        _load();
        return;
      } on ApiException catch (e) {
        if (mounted) _snack(context, _apiError(context, e));
        return;
      }
    }
    if (value == 'off' && (key == 'event_x2' || key == 'event_saves' || key == 'event_x4')) {
      try {
        final evKey = key.replaceFirst('event_', '');
        await ApiClient.instance.adminEventOff(evKey);
      } catch (_) {}
    }
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
                    hintText: 'https://.../music.mp3 или загрузите файл ниже',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _uploadingMusic ? null : _uploadMusic,
                    icon: _uploadingMusic
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(_uploadingMusic ? 'Загрузка...' : 'Загрузить файл с устройства (mp3/wav)'),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Загрузите файл на сервер — он автоматом включится у всех игроков. Или вставьте URL вручную.', style: const TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.none)),
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
                if (_musicFiles.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Файлы в server/public/music (залей папку на сервер):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                  const SizedBox(height: 8),
                  for (final f in _musicFiles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
                        child: Row(children: [
                          const Icon(Icons.music_note_rounded, size: 16, color: Colors.white70),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f, style: const TextStyle(fontSize: 12, decoration: TextDecoration.none), overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(onPressed: () => _playMusicFile(f), icon: const Icon(Icons.play_arrow_rounded, size: 16), label: const Text('Вкл', style: TextStyle(fontSize: 12))),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _stopMusic, icon: const Icon(Icons.stop_rounded, size: 16), label: const Text('Остановить музыку у всех'))),
                ] else ...[
                  const SizedBox(height: 10),
                  Text('Папка server/public/music пуста — залей туда mp3/wav и нажми Обновить.', style: TextStyle(fontSize: 11, color: Colors.grey[500], decoration: TextDecoration.none)),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Обновить список')),
                ],
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

  Future<void> _deletePromo(String code) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Удалить промокод?'), content: Text('Удалить $code ?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить'))]));
    if (ok != true) return;
    try {
      await ApiClient.instance.deletePromocode(code);
      if (!mounted) return;
      await _load();
      _snack(context, 'Промокод $code удалён');
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
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent), onPressed: () => _deletePromo(_promos[i]['code'].toString()), tooltip: 'Удалить'),
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
