import 'package:equatable/equatable.dart';
import '../gifts/gift_assets.dart';

enum NftRarity { common, rare, epic, legendary }

extension NftRarityX on NftRarity {
  String get label {
    switch (this) {
      case NftRarity.common:
        return 'Common';
      case NftRarity.rare:
        return 'Rare';
      case NftRarity.epic:
        return 'Epic';
      case NftRarity.legendary:
        return 'Legendary';
    }
  }

  static NftRarity parse(String? value) {
    switch (value?.toLowerCase()) {
      case 'rare':
        return NftRarity.rare;
      case 'epic':
        return NftRarity.epic;
      case 'legendary':
        return NftRarity.legendary;
      default:
        return NftRarity.common;
    }
  }
}

/// Один NFT-подарок.
///
/// Картинка ищется в три шага (см. [resolvedAsset] и NftItemCard):
///   1. [imageAsset] — прямой путь к файлу в assets/gifts/
///   2. реестр [GiftAssets] по [id] (файл assets/gifts/<id>.png)
///   3. [imageUrl] — картинка из сети
/// Если ничего не нашлось, карточка рисует 🎁-заглушку и не падает.
class NftItem extends Equatable {
  final String id;
  final String name;
  final String? imageAsset;
  final String? imageUrl;
  final int priceInCoins;
  final NftRarity rarity;
  final String collection;
  final bool isOwned;
  final bool isStarred;

  const NftItem({
    required this.id,
    required this.name,
    required this.priceInCoins,
    required this.rarity,
    required this.collection,
    this.imageAsset,
    this.imageUrl,
    this.isOwned = false,
    this.isStarred = false,
  });

  /// Итоговый путь к локальной картинке или null.
  /// Сервер присылает `image_asset` как имя файла (`present.png`) или полный
  /// путь `assets/gifts/present.png`. Поддерживаем оба варианта.
  /// Если поля нет — пробуем реестр GiftAssets, затем соглашение <id>.png.
  String? get resolvedAsset {
    if (imageAsset != null && imageAsset!.isNotEmpty) {
      final v = imageAsset!;
      if (v.startsWith('assets/')) return v;
      // Сервер хранит только имя файла: "present.png"
      if (v.contains('.')) return '${GiftAssets.dir}$v';
      return GiftAssets.byConvention(v);
    }
    return GiftAssets.pathFor(id) ?? GiftAssets.byConvention(id);
  }

  factory NftItem.fromJson(Map<String, dynamic> json) {
    return NftItem(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '—',
      priceInCoins: (json['price_coins'] ?? json['priceInCoins'] ?? 0) is int
          ? (json['price_coins'] ?? json['priceInCoins'] ?? 0) as int
          : int.tryParse('${json['price_coins'] ?? json['priceInCoins']}') ?? 0,
      rarity: NftRarityX.parse(json['rarity'] as String?),
      collection: json['collection'] as String? ?? '',
      imageAsset: (json['image_asset'] as String?) ?? _conventionAsset(json),
      imageUrl: json['image_url'] as String?,
      isOwned: json['is_owned'] as bool? ?? false,
      isStarred: json['is_starred'] as bool? ?? json['isStarred'] as bool? ?? false,
    );
  }

  /// Путь по соглашению `assets/gifts/<item_id>.png`, если id похож на
  /// каталожный (у инстансов инвентаря — UUID с дефисами, им не подходит).
  static String? _conventionAsset(Map<String, dynamic> json) {
    final iid = (json['item_id'] ?? json['id'] ?? '').toString();
    if (RegExp(r'^[A-Za-z]+_[A-Za-z0-9]+$').hasMatch(iid) && !iid.contains('-')) {
      return GiftAssets.byConvention(iid);
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price_coins': priceInCoins,
        'rarity': rarity.name,
        'collection': collection,
        'image_asset': imageAsset,
        'image_url': imageUrl,
        'is_owned': isOwned,
      };

  NftItem copyWith({
    String? id,
    String? name,
    String? imageAsset,
    String? imageUrl,
    int? priceInCoins,
    NftRarity? rarity,
    String? collection,
    bool? isOwned,
    bool? isStarred,
  }) {
    return NftItem(
      id: id ?? this.id,
      name: name ?? this.name,
      imageAsset: imageAsset ?? this.imageAsset,
      imageUrl: imageUrl ?? this.imageUrl,
      priceInCoins: priceInCoins ?? this.priceInCoins,
      rarity: rarity ?? this.rarity,
      collection: collection ?? this.collection,
      isOwned: isOwned ?? this.isOwned,
      isStarred: isStarred ?? this.isStarred,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, imageAsset, imageUrl, priceInCoins, rarity, collection, isOwned, isStarred];
}
