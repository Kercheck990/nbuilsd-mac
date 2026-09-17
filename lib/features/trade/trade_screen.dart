import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/top_notify.dart';
import '../../core/widgets/user_badges.dart';
import '../../data/models/nft_item.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../services/api_client.dart';
import '../upgrader/widgets/nft_item_card.dart';

/// Настоящие трейды между игроками (сервер — источник правды):
/// создание оффера, входящие/исходящие, атомарный обмен при принятии.
class TradeScreen extends ConsumerStatefulWidget {
  const TradeScreen({super.key});

  @override
  ConsumerState<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends ConsumerState<TradeScreen> {
  int _tab = 0; // 0 обмен, 1 входящие, 2 исходящие
  List<Map<String, dynamic>> _players = [];
  String _search = '';
  bool _searching = false;
  String? _selectedNick;
  List<NftItem> _showcase = [];
  bool _loadingShowcase = false;
  final Set<String> _giveIds = {};
  final Set<String> _takeIds = {};
  bool _sending = false;

  Map<String, dynamic>? _lists;
  bool _loadingLists = false;

  @override
  void initState() {
    super.initState();
    _loadPlayers('');
    _loadLists();
  }

  Future<void> _loadPlayers(String q) async {
    setState(() => _searching = true);
    try {
      final res = await ApiClient.instance.tradePlayers(q);
      if (!mounted) return;
      setState(() {
        _players = ((res['players'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (_) {
      if (mounted) _snack(context.l10n.t('error_network'));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _loadLists() async {
    setState(() => _loadingLists = true);
    try {
      final res = await ApiClient.instance.trades();
      if (!mounted) return;
      setState(() => _lists = res);
    } catch (_) {
      if (mounted) _snack(context.l10n.t('error_network'));
    } finally {
      if (mounted) setState(() => _loadingLists = false);
    }
  }

  Future<void> _pickPlayer(String nick) async {
    setState(() {
      _selectedNick = nick;
      _takeIds.clear();
      _showcase = [];
      _loadingShowcase = true;
    });
    try {
      final res = await ApiClient.instance.tradeShowcase(nick);
      if (!mounted) return;
      setState(() {
        _showcase = ((res['items'] as List?) ?? const [])
            .map((e) => NftItem.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {
      if (mounted) _snack(context.l10n.t('tr_err_generic'));
    } finally {
      if (mounted) setState(() => _loadingShowcase = false);
    }
  }

  Future<void> _send() async {
    if (_selectedNick == null || _giveIds.isEmpty || _takeIds.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ApiClient.instance.createTrade(
        toNickname: _selectedNick!,
        offerIds: _giveIds.toList(),
        askIds: _takeIds.toList(),
      );
      if (!mounted) return;
      setState(() {
        _giveIds.clear();
        _takeIds.clear();
        _tab = 2;
      });
      await _loadLists();
      _snack(context.l10n.t('tr_sent'));
    } on ApiException catch (e) {
      if (mounted) _snack(_tradeError(context, e.code));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _decide(
      String id, Future<void> Function() call, String okKey) async {
    try {
      await call();
      await _loadLists();
      await ref.read(inventoryProvider.notifier).refresh();
      if (mounted) _snack(context.l10n.t(okKey));
    } on ApiException catch (e) {
      if (mounted) _snack(_tradeError(context, e.code));
    }
  }

  String _tradeError(BuildContext context, String code) {
    final l10n = context.l10n;
    switch (code) {
      case 'invalid_offer':
        return l10n.t('tr_err_offer');
      case 'invalid_ask':
        return l10n.t('tr_err_ask');
      case 'stale':
        return l10n.t('tr_err_stale');
      case 'already_decided':
        return l10n.t('tr_err_done');
      case 'error_network':
        return l10n.t('error_network');
      default:
        return l10n.t('tr_err_generic');
    }
  }

  void _snack(String text) {
    TopNotify.show(context, text, success: true);
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final l10n = context.l10n;
    final incoming = ((_lists?['incoming'] as List?) ?? const []).length;
    final outgoing = ((_lists?['outgoing'] as List?) ?? const []).length;

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(
                  title: l10n.t('menu_trade'),
                  subtitle: l10n.t('tr_sub'),
                  showBack: true,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      _Tab(l10n.t('tr_create'), 0, _tab,
                          (i) => setState(() => _tab = i)),
                      const SizedBox(width: 8),
                      _Tab(
                          '${l10n.t('tr_incoming')}${incoming > 0 ? ' ($incoming)' : ''}',
                          1,
                          _tab,
                          (i) => setState(() => _tab = i)),
                      const SizedBox(width: 8),
                      _Tab(
                          '${l10n.t('tr_outgoing')}${outgoing > 0 ? ' ($outgoing)' : ''}',
                          2,
                          _tab,
                          (i) => setState(() => _tab = i)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: switch (_tab) {
                    0 => _CreateTab(
                        search: _search,
                        searching: _searching,
                        players: _players,
                        selectedNick: _selectedNick,
                        showcase: _showcase,
                        loadingShowcase: _loadingShowcase,
                        giveIds: _giveIds,
                        takeIds: _takeIds,
                        sending: _sending,
                        inventory: inventory,
                        green: green,
                        onSearch: (v) {
                          _search = v;
                          _loadPlayers(v);
                        },
                        onPick: _pickPlayer,
                        onToggleGive: (id) => setState(() => _giveIds.contains(id)
                            ? _giveIds.remove(id)
                            : _giveIds.add(id)),
                        onToggleTake: (id) => setState(() => _takeIds.contains(id)
                            ? _takeIds.remove(id)
                            : _takeIds.add(id)),
                        onSend: _send,
                      ),
                    1 => _TradesList(
                        trades: ((_lists?['incoming'] as List?) ?? const [])
                            .map((e) => Map<String, dynamic>.from(e as Map))
                            .toList(),
                        loading: _loadingLists,
                        incoming: true,
                        onRefresh: _loadLists,
                        onAccept: (id) => _decide(
                            id,
                            () => ApiClient.instance.acceptTrade(id),
                            'tr_done_accept'),
                        onDecline: (id) => _decide(
                            id,
                            () => ApiClient.instance.declineTrade(id),
                            'tr_done_decline'),
                      ),
                    _ => _TradesList(
                        trades: ((_lists?['outgoing'] as List?) ?? const [])
                            .map((e) => Map<String, dynamic>.from(e as Map))
                            .toList(),
                        loading: _loadingLists,
                        incoming: false,
                        onRefresh: _loadLists,
                        onCancel: (id) => _decide(
                            id,
                            () => ApiClient.instance.cancelTrade(id),
                            'tr_done_cancel'),
                      ),
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

class _Tab extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;
  const _Tab(this.label, this.index, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sel = index == current;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: sel ? green.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel ? green : (isDark ? Colors.white12 : const Color(0xFFE3E8E3)),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: sel ? green : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateTab extends StatelessWidget {
  final String search;
  final bool searching;
  final List<Map<String, dynamic>> players;
  final String? selectedNick;
  final List<NftItem> showcase;
  final bool loadingShowcase;
  final Set<String> giveIds;
  final Set<String> takeIds;
  final bool sending;
  final List<NftItem> inventory;
  final Color green;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onToggleGive;
  final ValueChanged<String> onToggleTake;
  final VoidCallback onSend;

  const _CreateTab({
    required this.search,
    required this.searching,
    required this.players,
    required this.selectedNick,
    required this.showcase,
    required this.loadingShowcase,
    required this.giveIds,
    required this.takeIds,
    required this.sending,
    required this.inventory,
    required this.green,
    required this.onSearch,
    required this.onPick,
    required this.onToggleGive,
    required this.onToggleTake,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    return Column(
      children: [
        EntranceAnim(
          index: 0,
          child: BrandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🤝', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(l10n.t('tr_pick'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (searching)
                      const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: l10n.t('tr_search'),
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                if (players.isEmpty && !searching)
                  Text(l10n.t('tr_no_players'),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in players)
                      _PlayerChip(
                        nick: p['nickname'].toString(),
                        badges: ((p['badges'] as List?) ?? const [])
                            .map((e) => e.toString())
                            .toList(),
                        count: (p['items_count'] as num?)?.toInt() ?? 0,
                        selected: selectedNick == p['nickname'].toString(),
                        onTap: () => onPick(p['nickname'].toString()),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (selectedNick != null) ...[
          const SizedBox(height: 14),
          EntranceAnim(
            index: 1,
            child: BrandCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      l10n.f('tr_give', {'n': '${giveIds.length}'}),
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (inventory.isEmpty)
                    Text(l10n.t('tr_empty_inv'),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final it in inventory)
                          _PickChip(
                            label: '${it.name} · ${it.priceInCoins}',
                            selected: giveIds.contains(it.id),
                            onTap: () => onToggleGive(it.id),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          EntranceAnim(
            index: 2,
            child: BrandCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      l10n.f('tr_get', {
                        'nick': '$selectedNick',
                        'n': '${takeIds.length}'
                      }),
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (loadingShowcase)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator())),
                  if (!loadingShowcase && showcase.isEmpty)
                    Text(l10n.t('tr_empty_show'),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  if (!loadingShowcase && showcase.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final it in showcase)
                          _PickChip(
                            label: '${it.name} · ${it.priceInCoins}',
                            selected: takeIds.contains(it.id),
                            onTap: () => onToggleTake(it.id),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: (giveIds.isEmpty || takeIds.isEmpty || sending) ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: (giveIds.isEmpty || takeIds.isEmpty)
                    ? (isDark ? Colors.white10 : const Color(0xFFF1F4F1))
                    : green,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: sending
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      l10n.t('tr_send'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: (giveIds.isEmpty || takeIds.isEmpty)
                            ? Colors.grey
                            : Colors.black,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final String nick;
  final List<String> badges;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _PlayerChip({
    required this.nick,
    required this.badges,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? green.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? green : (isDark ? Colors.white12 : const Color(0xFFE3E8E3)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(nick,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? green : null)),
            UserBadgesRow(badges: badges),
            const SizedBox(width: 4),
            Text('· $count',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _PickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PickChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? green.withOpacity(0.16)
              : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF3F6F1)),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? green : (isDark ? Colors.white12 : const Color(0xFFE3E8E3)),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? green : null)),
      ),
    );
  }
}

class _TradesList extends StatelessWidget {
  final List<Map<String, dynamic>> trades;
  final bool loading;
  final bool incoming;
  final VoidCallback onRefresh;
  final ValueChanged<String>? onAccept;
  final ValueChanged<String>? onDecline;
  final ValueChanged<String>? onCancel;

  const _TradesList({
    required this.trades,
    required this.loading,
    required this.incoming,
    required this.onRefresh,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (trades.isEmpty) {
      return BrandCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              context.l10n.t(incoming ? 'tr_no_in' : 'tr_no_out'),
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < trades.length; i++)
          EntranceAnim(
            index: i % 6,
            child: Padding(
              padding: EdgeInsets.only(bottom: i == trades.length - 1 ? 0 : 12),
              child: _TradeCard(
                trade: trades[i],
                incoming: incoming,
                onAccept: onAccept,
                onDecline: onDecline,
                onCancel: onCancel,
              ),
            ),
          ),
      ],
    );
  }
}

class _TradeCard extends StatelessWidget {
  final Map<String, dynamic> trade;
  final bool incoming;
  final ValueChanged<String>? onAccept;
  final ValueChanged<String>? onDecline;
  final ValueChanged<String>? onCancel;

  const _TradeCard({
    required this.trade,
    required this.incoming,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final status = trade['status'].toString();
    final id = trade['id'].toString();
    final partner = incoming
        ? trade['from_nickname'].toString()
        : trade['to_nickname'].toString();
    final offer = ((trade['offer'] as List?) ?? const []).length;
    final ask = ((trade['ask'] as List?) ?? const []).length;

    final statusColor = switch (status) {
      'pending' => green,
      'accepted' => const Color(0xFFFFC107),
      'declined' => Colors.grey,
      _ => Colors.grey,
    };
    final statusText = switch (status) {
      'pending' => l10n.t('tr_st_pending'),
      'accepted' => l10n.t('tr_st_accepted'),
      'declined' => l10n.t('tr_st_declined'),
      _ => l10n.t('tr_st_cancelled'),
    };

    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/profile/${Uri.encodeComponent(partner)}'),
                  child: Text(
                    incoming
                        ? l10n.f('tr_from', {'nick': partner})
                        : l10n.f('tr_to', {'nick': partner}),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(statusText,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _SidePreview(label: l10n.t('tr_you_give'), items: trade[incoming ? 'ask' : 'offer'], isDark: isDark)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.swap_horiz_rounded, color: Colors.grey),
              ),
              Expanded(child: _SidePreview(label: l10n.t('tr_you_get'), items: trade[incoming ? 'offer' : 'ask'], isDark: isDark)),
            ],
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (incoming && onAccept != null)
                  Expanded(
                    child: _ActionBtn(
                        label: l10n.t('tr_accept'),
                        fill: true,
                        green: green,
                        onTap: () => onAccept!(id)),
                  ),
                if (incoming && onAccept != null && onDecline != null)
                  const SizedBox(width: 8),
                Expanded(
                  child: _ActionBtn(
                    label: incoming
                        ? l10n.t('tr_decline')
                        : l10n.t('tr_cancel'),
                    fill: false,
                    green: green,
                    onTap: () => incoming ? onDecline!(id) : onCancel!(id),
                  ),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  l10n.f('tr_counts', {'a': '$offer', 'b': '$ask'}),
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}

class _SidePreview extends StatelessWidget {
  final String label;
  final dynamic items;
  final bool isDark;
  const _SidePreview({required this.label, required this.items, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final list = ((items as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 6),
        SizedBox(
          height: 56,
          child: list.isEmpty
              ? const Text('—', style: TextStyle(color: Colors.grey))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final it = list[i];
                    return Container(
                      width: 52,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white12 : const Color(0xFFE3E8E3),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: GiftImage(
                              item: NftItem(
                                id: it['item_id']?.toString() ?? '',
                                name: it['name']?.toString() ?? '',
                                priceInCoins: (it['price_coins'] as num?)?.toInt() ?? 0,
                                rarity: NftRarityX.parse(it['rarity']?.toString()),
                                collection: it['collection']?.toString() ?? '',
                                imageAsset: it['image_asset']?.toString(),
                                imageUrl: it['image_url']?.toString(),
                              ),
                              radius: 6,
                            ),
                          ),
                          Text(
                            '${(it['price_coins'] as num?)?.toInt() ?? 0}',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final bool fill;
  final Color green;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.fill,
    required this.green,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: fill ? green : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: green),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
            color: fill ? Colors.black : green,
          ),
        ),
      ),
    );
  }
}
