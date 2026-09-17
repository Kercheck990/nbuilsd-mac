import 'dart:math';
import 'package:flutter/material.dart';
import '../models/case_model.dart';

/// Рулетка кейса: лента призов крутится влево, по центру стрелка.
/// `itemsPool` — все предметы кейса для рандома ленты, `won` — выигранный.
class CaseRoulette extends StatefulWidget {
  final CaseItemModel won; // для генерации ленты win используем won как CaseItemModel
  final List<CaseItemModel> itemsPool;
  final Duration duration;
  final VoidCallback? onFinished;
  const CaseRoulette({super.key, required this.won, required this.itemsPool, this.duration = const Duration(milliseconds: 3200), this.onFinished});

  @override
  State<CaseRoulette> createState() => _CaseRouletteState();
}

class _CaseRouletteState extends State<CaseRoulette> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _anim;
  late List<CaseItemModel> _strip;
  static const double itemW = 92;
  static const double gap = 8;
  late double _finalOffset;

  @override
  void initState() {
    super.initState();
    _buildStrip();
    _c = AnimationController(vsync: this, duration: widget.duration);
    // финальный оффсет: выигранный элемент под стрелкой (центр)
    final winIndex = _strip.length - 7; // 7 элементов до конца оставим
    // центр экрана = ширина/2, нужно чтобы левый край выигранного был в центре - itemW/2
    // но мы не знаем ширину экрана в initState — посчитаем после лэйаута в didChangeDependencies
    _finalOffset = -(winIndex * (itemW + gap));
    // добавим рандом +- 20% ширины предмета для непредсказуемости
    final rnd = Random().nextDouble() * 18 - 9;
    _finalOffset += rnd;

    _anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onFinished?.call();
    });
    // чуть задержки старта чтобы выглядело живее
    Future.delayed(Duration(milliseconds: Random().nextInt(180)), () {
      if (mounted) _c.forward();
    });
  }

  void _buildStrip() {
    final rnd = Random();
    // 40 элементов ленты
    _strip = List.generate(40, (_) {
      // взвешенный рандом по шансам
      final roll = rnd.nextDouble() * 100;
      double acc = 0;
      for (final it in widget.itemsPool) {
        acc += it.dropChance;
        if (roll < acc) return it;
      }
      return widget.itemsPool.last;
    });
    // вставляем выигранный на позицию winIndex
    final winIndex = _strip.length - 7;
    _strip[winIndex] = widget.won;
    // также вокруг win ставим рандом чтобы не было повторов подряд
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final center = constraints.maxWidth / 2;
      // корректируем финальный оффсет с учетом центра
      final winIndex = _strip.length - 7;
      final target = -(winIndex * (itemW + gap)) + center - itemW / 2;
      // пересоздаем анимацию если target отличается (первый билд)
      if ((_finalOffset - target).abs() > 1) {
        _finalOffset = target;
      }
      return Container(
        height: 118,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                // добавляем стартовый разгон: начинаем с быстрого смещения
                final offset = _finalOffset * _anim.value;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: Row(
                    children: _strip.map((it) => _RouletteTile(item: it)).toList(),
                  ),
                );
              },
            ),
            // центральная стрелка
            Align(
              alignment: Alignment.center,
              child: Container(width: 2, height: double.infinity, color: const Color(0xFFFFC107).withOpacity(0.9)),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 2,
                height: 10,
                decoration: BoxDecoration(color: const Color(0xFFFFC107), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 2,
                height: 10,
                decoration: BoxDecoration(color: const Color(0xFFFFC107), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // стрелка картинка если есть
            Center(
              child: IgnorePointer(
                child: Image.asset(
                  'assets/case/strelka.png',
                  width: 28,
                  height: 118,
                  fit: BoxFit.fitHeight,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            // градиенты по краям
            Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 24, decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF0F0F0F), const Color(0xFF0F0F0F).withOpacity(0)])))),
            Positioned(right: 0, top: 0, bottom: 0, child: Container(width: 24, decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF0F0F0F).withOpacity(0), const Color(0xFF0F0F0F)])))),
          ],
        ),
      );
    });
  }
}

class _RouletteTile extends StatelessWidget {
  final CaseItemModel item;
  const _RouletteTile({required this.item});

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
    return Container(
      width: 92,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: col.withOpacity(0.5), width: 1.2),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Expanded(
            child: Image.asset(
              item.resolvedAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(child: Text('🎁', style: TextStyle(fontSize: 28, color: col))),
            ),
          ),
          const SizedBox(height: 4),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.stars, size: 10, color: Color(0xFFFFC107)),
            const SizedBox(width: 2),
            Text('${item.priceCoins}', style: const TextStyle(color: Color(0xFFFFC107), fontSize: 10, fontWeight: FontWeight.w800)),
          ]),
        ],
      ),
    );
  }
}

/// Контейнер для 1..10 рулеток (фото 4)
class MultiRoulette extends StatelessWidget {
  final List<CaseItemModel> wonItems; // выигранные как CaseItemModel (конвертим из won)
  final List<CaseItemModel> pool;
  final VoidCallback? onAllFinished;
  const MultiRoulette({super.key, required this.wonItems, required this.pool, this.onAllFinished});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(wonItems.length, (i) {
        return Padding(
          padding: EdgeInsets.only(bottom: i == wonItems.length - 1 ? 0 : 10),
          child: CaseRoulette(
            won: wonItems[i],
            itemsPool: pool,
            duration: Duration(milliseconds: 2800 + i * 180 + (i % 2) * 120),
            onFinished: i == wonItems.length - 1 ? onAllFinished : null,
          ),
        );
      }),
    );
  }
}
