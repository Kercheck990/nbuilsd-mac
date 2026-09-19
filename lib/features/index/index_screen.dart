import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../data/models/nft_item.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../services/api_client.dart';

class IndexScreen extends ConsumerStatefulWidget {
  const IndexScreen({super.key});
  @override
  ConsumerState<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends ConsumerState<IndexScreen> {
  Set<String> _obtainedIds = {};
  bool _loadingObtained = true;

  @override
  void initState() {
    super.initState();
    _loadObtained();
  }

  Future<void> _loadObtained() async {
    try {
      await ref.read(catalogProvider.notifier).refresh();
    } catch (_) {}
    try {
      final r = await ApiClient.instance.getObtained();
      final list = (r['obtained'] as List?) ?? const [];
      if (mounted) setState(() {
        _obtainedIds = list.map((e) => e.toString()).toSet();
        _loadingObtained = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingObtained = false);
    }
  }

  bool _isObtained(NftItem item) {
    // Считаем полученным если item.id когда-либо был в инвентаре/кейсах/раундах (даже если продал) — сервер отдаёт distinct item_id
    return _obtainedIds.contains(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ownedCount = catalog.where((c) => _isObtained(c)).length;

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Row(
                    children: [
                      IconButton(onPressed: () => context.canPop() ? context.pop() : context.go('/home'), icon: const Icon(Icons.arrow_back, color: Colors.white)),
                      Expanded(child: ScreenHeader(title: 'Индекс', subtitle: 'Все предметы — $ownedCount/${catalog.length} получено')),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width >= 700 ? 4 : 3,
                    childAspectRatio: 0.82,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final item = catalog[i];
                    final obtained = _isObtained(item);
                    final col = AppColors.rarityColor(item.rarity.name);
                    return _IndexTile(item: item, obtained: obtained, color: col, isDark: isDark);
                  }, childCount: catalog.length),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndexTile extends StatelessWidget {
  final NftItem item;
  final bool obtained;
  final Color color;
  final bool isDark;
  const _IndexTile({required this.item, required this.obtained, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: obtained ? (isDark ? const Color(0xFF1A1A1A) : Colors.white) : const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: obtained ? color.withOpacity(0.35) : Colors.white10, width: 1),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: obtained ? 1 : 0.22,
                  child: Image.asset(item.resolvedAsset ?? 'assets/gifts/present.png', fit: BoxFit.contain, cacheWidth: 128, errorBuilder: (_, __, ___) => Text('🎁', style: TextStyle(fontSize: 28, color: color))),
                ),
                if (!obtained)
                  Container(
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.lock_rounded, color: Colors.white70, size: 22),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(obtained ? item.name : '???', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: obtained ? Colors.white : Colors.white38, fontSize: 10, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: obtained ? const Color(0xFF0F0F0F) : Colors.black26, borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(obtained ? Icons.stars : Icons.lock, size: 10, color: obtained ? const Color(0xFFFFC107) : Colors.white24),
              const SizedBox(width: 3),
              Text(obtained ? '${item.priceInCoins}' : '—', style: TextStyle(color: obtained ? const Color(0xFFFFC107) : Colors.white24, fontWeight: FontWeight.w800, fontSize: 10, decoration: TextDecoration.none)),
            ]),
          ),
        ],
      ),
    );
  }
}
