import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/nft_item.dart';

/// A single NFT card: 1:1 image placeholder area (falls back to a 🎁 icon
/// if [item.imageUrl] is null or fails to load), price badge, and an
/// optional rarity corner badge.
class NftItemCard extends StatelessWidget {
  final NftItem item;
  final bool selected;
  final VoidCallback? onTap;
  final bool showRarityBadge;
  final double width;
  final bool showStar;
  final VoidCallback? onStarToggle;

  const NftItemCard({
    super.key,
    required this.item,
    this.selected = false,
    this.onTap,
    this.showRarityBadge = true,
    this.width = 120,
    this.showStar = false,
    this.onStarToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rarityColor = AppColors.rarityColor(item.rarity.name);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.accentYellow
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.accentYellow.withOpacity(0.25),
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: GiftImage(item: item),
                  ),
                  if (showRarityBadge)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: rarityColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.rarity.label,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (showStar)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onStarToggle,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: item.isStarred ? const Color(0xFFFFC107) : Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Icon(
                            item.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 16,
                            color: item.isStarred ? Colors.black : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              _PriceBadge(price: item.priceInCoins),
            ],
          ),
        ),
      ),
    );
  }
}

/// Картинка подарка.
///
/// Порядок поиска:
///   1. локальный ассет из `assets/gifts/` (item.resolvedAsset)
///   2. картинка из сети (item.imageUrl)
///   3. 🎁-заглушка
/// Ошибка загрузки на любом шаге просто откатывает на заглушку — карточка
/// никогда не падает из-за отсутствующего файла.
class GiftImage extends StatelessWidget {
  final NftItem item;
  final double radius;

  const GiftImage({super.key, required this.item, this.radius = 14});

  @override
  Widget build(BuildContext context) {
    final asset = item.resolvedAsset;
    final url = item.imageUrl;

    Widget child;
    if (asset != null) {
      child = Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        // Ограничиваем декодирование для ПК — меньше лагов
        cacheWidth: 256,
        errorBuilder: (_, __, ___) => _fallback(url),
      );
    } else {
      child = _fallback(url);
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.rarityColor(item.rarity.name).withOpacity(0.18),
                AppColors.darkSurfaceAlt,
              ],
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          child: child,
        ),
      ),
    );
  }

  Widget _fallback(String? url) {
    if (url == null || url.isEmpty) {
      return const Text('🎁', style: TextStyle(fontSize: 32));
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Text('🎁', style: TextStyle(fontSize: 32)),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _ShimmerBox(),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox();
  @override
  Widget build(BuildContext context) {
    // Статичная заглушка — убран AnimatedBuilder для производительности на ПК
    return Container(color: Colors.white.withOpacity(0.06));
  }
}

class _PriceBadge extends StatelessWidget {
  final int price;
  const _PriceBadge({required this.price});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.monetization_on, size: 13, color: AppColors.accentYellow),
        const SizedBox(width: 3),
        Text(
          '$price',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.accentYellow,
          ),
        ),
      ],
    );
  }
}
