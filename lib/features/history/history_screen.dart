import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../services/api_client.dart';
import '../../services/rng_service.dart';

/// История раундов игрока — только реальные данные с сервера.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<Map<String, dynamic>> _rounds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(
                  title: l10n.t('history_title'),
                  subtitle: '${_rounds.length}',
                  showBack: true,
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_rounds.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  sliver: SliverToBoxAdapter(
                    child: BrandCard(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(l10n.t('history_empty'),
                              style:
                                  const TextStyle(color: Colors.grey)),
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  sliver: SliverList.separated(
                    itemCount: _rounds.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _RoundCard(round: _rounds[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundCard extends StatelessWidget {
  final Map<String, dynamic> round;
  const _RoundCard({required this.round});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final success = round['success'] == true;
    final color = success
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    final chance = (round['chance_percent'] as num?)?.toDouble() ?? 0;
    final roll = (round['roll_percent'] as num?)?.toDouble() ?? 0;
    final profit = (round['profit_coins'] as num?)?.toInt() ?? 0;
    DateTime? at;
    try {
      at = DateTime.parse(round['created_at'].toString()).toLocal();
    } catch (_) {}
    return EntranceAnim(
      index: (round.hashCode % 6).abs(),
      child: BrandCard(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.cancel,
              color: color,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '→ ${round['target_name'] ?? ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    '${l10n.f('hi_roll_chance', {
                      'roll': roll.toStringAsFixed(2),
                      'chance': chance.toStringAsFixed(1),
                    })}${at != null ? ' · ${DateFormat('d MMM, HH:mm').format(at)}' : ''}',
                    style: const TextStyle(
                        fontSize: 11.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Text(
              '${profit >= 0 ? '+' : ''}$profit',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: color),
            ),
            TextButton(
              onPressed: () => _showFairness(context, round),
              child: Text(l10n.t('hi_check'),
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  /// Пересчёт ролла на клиенте: roll == sha256(server:client:nonce).
  void _showFairness(BuildContext context, Map<String, dynamic> round) {
    final l10n = context.l10n;
    final serverSeed = round['server_seed']?.toString() ?? '';
    final clientSeed = round['client_seed']?.toString() ?? '';
    final nonce = (round['nonce'] as num?)?.toInt() ?? 0;
    final rollShown = (round['roll_percent'] as num?)?.toDouble() ?? 0;
    final recomputed =
        FairnessCheck.rollFromSeeds(serverSeed, clientSeed, nonce);
    final hashOk = FairnessCheck.sha256Hex(serverSeed) ==
        (round['server_seed_hash']?.toString() ?? '');
    final match = (recomputed - rollShown).abs() < 0.001;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Provably Fair'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv(l10n.t('hi_roll_server'), rollShown.toStringAsFixed(3)),
            _kv(l10n.t('hi_roll_calc'), recomputed.toStringAsFixed(3)),
            _kv(l10n.t('hi_match'),
                match ? l10n.t('hi_yes') : l10n.t('hi_no')),
            _kv(l10n.t('hi_hash'),
                hashOk ? l10n.t('hi_yes') : l10n.t('hi_no')),
            _kv('Nonce', '$nonce'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.t('ok')),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12.5, color: Colors.grey),
          children: [
            TextSpan(
                text: '$k: ',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: v),
          ],
        ),
      ),
    );
  }
}
