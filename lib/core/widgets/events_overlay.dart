import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/session_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Иконки активных ивентов в левом нижнем углу (x2/x4 Удача, Сейвы)
/// с обратным отсчётом 15-минутки выходных.
class EventIcons extends ConsumerStatefulWidget {
  const EventIcons({super.key});

  @override
  ConsumerState<EventIcons> createState() => _EventIconsState();
}

class _EventIconsState extends ConsumerState<EventIcons> {
  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider);
    final active = events.events.where((e) => e.active).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    final endsAt = events.endsAt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in active)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _EventBadge(
              key: ValueKey(e.key),
              eventKey: e.key,
              endsAt: endsAt,
            ),
          ),
      ],
    );
  }
}

class _EventBadge extends StatelessWidget {
  final String eventKey;
  final DateTime? endsAt;
  const _EventBadge({super.key, required this.eventKey, required this.endsAt});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final l10n = AppLocalizations.of(context);
    final asset = switch (eventKey) {
      'x4' => 'assets/abuse/x4luck.png',
      'x2' => 'assets/abuse/x2luck.png',
      _ => 'assets/abuse/blesing.png',
    };
    final label = switch (eventKey) {
      'x4' => 'x4',
      'x2' => 'x2',
      _ => l10n.t('ev_saves'),
    };
    // Картинки стоят статично — без пульса/анимации, как просили
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1712).withOpacity(0.92) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: green.withOpacity(0.6)),
        boxShadow: [BoxShadow(color: green.withOpacity(0.22), blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(asset, width: 24, height: 24, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Text(eventKey == 'x4' ? '🍀' : eventKey == 'x2' ? '🍀' : '🛡️', style: const TextStyle(fontSize: 15))),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: green)),
          if (endsAt != null) ...[
            const SizedBox(width: 6),
            _Countdown(endsAt: endsAt!),
          ],
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  final DateTime endsAt;
  const _Countdown({required this.endsAt});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (_, __) {
        final left = endsAt.difference(DateTime.now());
        final text = left.isNegative
            ? '0:00'
            : '${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';
        return Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                fontFeatures: [FontFeature.tabularFigures()]));
      },
    );
  }
}

/// Баннер рассылки от администрации поверх всех экранов (закрываемый).
class BroadcastBanner extends ConsumerStatefulWidget {
  const BroadcastBanner({super.key});

  @override
  ConsumerState<BroadcastBanner> createState() => _BroadcastBannerState();
}

class _BroadcastBannerState extends ConsumerState<BroadcastBanner> {
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    _loadSeen();
  }

  Future<void> _loadSeen() async {
    final v = await ref.read(broadcastsProvider.notifier).seenId();
    if (mounted) setState(() => _seen = v);
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(broadcastsProvider);
    if (list.isEmpty) return const SizedBox.shrink();
    final fresh = list.where((b) => b.id > _seen).toList();
    if (fresh.isEmpty) return const SizedBox.shrink();
    final b = fresh.first;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Авто-скрытие через 5 сек как у TopNotify — красивое уведомление сверху
    Future.delayed(const Duration(seconds: 5), () async {
      final curSeen = await ref.read(broadcastsProvider.notifier).seenId();
      if (curSeen < b.id && mounted) {
        await ref.read(broadcastsProvider.notifier).markSeen(b.id);
        if (mounted) setState(() => _seen = b.id);
      }
    });

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
            offset: Offset(0, -12 * (1 - t)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121A14) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFFC107).withOpacity(0.55),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('📢', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    b.adminNickname,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFC107)),
                  ),
                  Text(
                    b.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 17),
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                await ref
                    .read(broadcastsProvider.notifier)
                    .markSeen(b.id);
                if (mounted) setState(() => _seen = b.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
