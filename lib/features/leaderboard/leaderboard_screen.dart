import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/user_badges.dart';
import '../../services/api_client.dart';

/// Одна строка таблицы лидеров.
class LeaderRow {
  final int rank;
  final String nickname;
  final String? avatarUrl;
  final List<String> badges;
  final int value; // монеты / часы — зависит от метрики
  final int wins;
  final bool isMe;
  final bool rewardGranted;

  const LeaderRow({
    required this.rank,
    required this.nickname,
    required this.value,
    required this.wins,
    this.avatarUrl,
    this.badges = const [],
    this.isMe = false,
    this.rewardGranted = false,
  });

  factory LeaderRow.fromJson(Map<String, dynamic> j, int index) => LeaderRow(
        rank: (j['rank'] as num?)?.toInt() ?? index + 1,
        nickname: j['nickname'] as String? ?? '—',
        avatarUrl: j['avatar_url'] as String?,
        badges: ((j['badges'] as List?) ?? const []).map((e) => e.toString()).toList(),
        value: (j['value'] as num?)?.toInt() ?? 0,
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        isMe: j['is_me'] as bool? ?? false,
        rewardGranted: j['reward_granted'] as bool? ?? false,
      );
}

/// Параметры запроса топа: метрика + период.
class LeaderboardQuery {
  final String metric; // balance | inventory | hours
  final String period; // day | week | all
  const LeaderboardQuery(this.metric, this.period);

  @override
  bool operator ==(Object other) =>
      other is LeaderboardQuery && other.metric == metric && other.period == period;

  @override
  int get hashCode => Object.hash(metric, period);
}

/// Топ-35 с сервера. Никаких моков: пустой ответ = пустой топ.
final leaderboardProvider =
    FutureProvider.family<List<LeaderRow>, LeaderboardQuery>((ref, q) async {
  final res = await ApiClient.instance
      .leaderboard(metric: q.metric, period: q.period, limit: 35);
  final rows = (res['rows'] as List?) ?? const [];
  return [
    for (var i = 0; i < rows.length; i++)
      LeaderRow.fromJson(rows[i] as Map<String, dynamic>, i)
  ];
});

/// Лидерборды: три реальные категории с сервера, топ-35, без моков.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 980;
    final l10n = context.l10n;

    final byBalance = ref.watch(leaderboardProvider(const LeaderboardQuery('balance', 'all')));
    final byInventory = ref.watch(leaderboardProvider(const LeaderboardQuery('inventory', 'all')));
    final byHours = ref.watch(leaderboardProvider(const LeaderboardQuery('hours', 'all')));

    Widget card(int index, String title, String icon, AsyncValue<List<LeaderRow>> async,
        String unit) {
      return EntranceAnim(
        index: index,
        child: _LeaderCard(
          title: title,
          icon: icon,
          async: async,
          unit: unit,
          onRefresh: () => ref.invalidate(leaderboardProvider),
        ),
      );
    }

    final cards = [
      card(0, l10n.t('lb_balance'), '💰', byBalance, ''),
      card(1, l10n.t('lb_inventory'), '🎁', byInventory, ''),
      card(2, l10n.t('lb_hours'), '⏳', byHours,
          l10n.t('lb_hours_unit')),
    ];

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(
                  title: l10n.t('lb_title'),
                  subtitle: l10n.t('lb_sub'),
                  showBack: true,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: isWide
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < cards.length; i++) ...[
                                Expanded(child: cards[i]),
                                if (i < cards.length - 1) const SizedBox(width: 16),
                              ],
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              cards[i],
                              if (i < cards.length - 1) const SizedBox(height: 14),
                            ],
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

class _LeaderCard extends StatelessWidget {
  final String title;
  final String icon;
  final AsyncValue<List<LeaderRow>> async;
  final String unit;
  final VoidCallback onRefresh;

  const _LeaderCard({
    required this.title,
    required this.icon,
    required this.async,
    required this.unit,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreen;
    return BrandCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: green.withOpacity(0.12),
                  border: Border.all(color: green.withOpacity(0.35)),
                  boxShadow: [
                    BoxShadow(color: green.withOpacity(0.25), blurRadius: 14),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: isDark ? Colors.white : const Color(0xFF101410),
                  ),
                ),
              ),
              InkWell(
                onTap: onRefresh,
                borderRadius: BorderRadius.circular(99),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.refresh_rounded,
                      size: 16, color: isDark ? Colors.white38 : Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => _CardMessage(
              icon: Icons.cloud_off_outlined,
              text: context.l10n.t('error_network'),
              actionLabel: context.l10n.t('retry'),
              onAction: onRefresh,
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return _CardMessage(
                  icon: Icons.emoji_events_outlined,
                  text: context.l10n.t('lb_empty'),
                );
              }
              return Column(
                children: [
                  if (rows.any((r) => r.isMe && r.rewardGranted))
                    const _RewardBanner(),
                  for (var i = 0; i < rows.length; i++)
                    _LeaderRowTile(row: rows[i], unit: unit, index: i),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Плашка «топ-3 получил +250» — награда выдаётся сервером один раз.
class _RewardBanner extends StatelessWidget {
  const _RewardBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.t('lb_reward'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _CardMessage({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: Colors.grey),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            if (actionLabel != null) ...[
              const SizedBox(height: 10),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaderRowTile extends StatefulWidget {
  final LeaderRow row;
  final String unit;
  final int index;
  const _LeaderRowTile({required this.row, required this.unit, required this.index});

  @override
  State<_LeaderRowTile> createState() => _LeaderRowTileState();
}

class _LeaderRowTileState extends State<_LeaderRowTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0.08, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 90 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final row = widget.row;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final locale = Localizations.localeOf(context).languageCode;
    final rankColor = switch (row.rank) {
      1 => const Color(0xFFFFC107),
      2 => const Color(0xFF9AA5B1),
      3 => const Color(0xFFE0955A),
      _ => isDark ? Colors.white38 : const Color(0xFF8A94A6),
    };

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: () => context.push(
              '/profile/${Uri.encodeComponent(row.nickname)}'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: row.isMe
                  ? green.withOpacity(0.10)
                  : (isDark
                      ? Colors.white.withOpacity(0.035)
                      : const Color(0xFFF1F4F1)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: row.isMe
                    ? green.withOpacity(0.5)
                    : (isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE3E8E3)),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '#${row.rank}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: rankColor,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 15,
                  backgroundColor: isDark ? const Color(0xFF1C2A20) : const Color(0xFFE8F5E9),
                  backgroundImage: row.avatarUrl != null ? NetworkImage(row.avatarUrl!) : null,
                  child: row.avatarUrl == null
                      ? Text(
                          row.nickname.characters.first.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: green,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          row.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF101410),
                          ),
                        ),
                      ),
                      UserBadgesRow(badges: row.badges, locale: locale),
                      if (row.rewardGranted)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text('🎁', style: TextStyle(fontSize: 13)),
                        ),
                    ],
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: row.value.toDouble()),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => Text(
                    '${_fmt(v)}${widget.unit}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: row.rank == 1 ? const Color(0xFFFFC107) : green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K'.replaceAll('.0K', 'K');
    }
    return v.toStringAsFixed(0);
  }
}
