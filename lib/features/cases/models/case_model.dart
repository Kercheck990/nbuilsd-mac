import 'package:equatable/equatable.dart';

class CaseModel extends Equatable {
  final String id;
  final String name;
  final int priceNc;
  final String? imageAsset;
  final int itemsCount;

  const CaseModel({
    required this.id,
    required this.name,
    required this.priceNc,
    this.imageAsset,
    this.itemsCount = 0,
  });

  bool get isFree => priceNc == 0;
  bool get isDaily => id == 'case_daily';
  bool get isTrash => id == 'case_trash';

  factory CaseModel.fromJson(Map<String, dynamic> j) => CaseModel(
        id: (j['id'] ?? j['case_id'] ?? '').toString(),
        name: (j['name'] ?? j['id'] ?? '').toString(),
        priceNc: j['price_nc'] == null ? 0 : int.tryParse(j['price_nc'].toString()) ?? (j['price_nc'] is num ? (j['price_nc'] as num).toInt() : 0),
        imageAsset: j['image_asset']?.toString(),
        itemsCount: j['items_count'] == null ? 0 : int.tryParse(j['items_count'].toString()) ?? 0,
      );

  @override
  List<Object?> get props => [id, name, priceNc, imageAsset];
}

class CaseItemModel extends Equatable {
  final String itemId;
  final String name;
  final int priceCoins;
  final String rarity;
  final String? imageAsset;
  final String? imageUrl;
  final double dropChance;

  const CaseItemModel({
    required this.itemId,
    required this.name,
    required this.priceCoins,
    required this.rarity,
    this.imageAsset,
    this.imageUrl,
    required this.dropChance,
  });

  factory CaseItemModel.fromJson(Map<String, dynamic> j) => CaseItemModel(
        itemId: (j['item_id'] ?? j['id'] ?? '').toString(),
        name: (j['name'] ?? j['item_id'] ?? '').toString(),
        priceCoins: j['price_coins'] == null ? 0 : int.tryParse(j['price_coins'].toString()) ?? 0,
        rarity: (j['rarity'] ?? 'common').toString(),
        imageAsset: j['image_asset']?.toString(),
        imageUrl: j['image_url']?.toString(),
        dropChance: j['drop_chance'] == null ? 0 : double.tryParse(j['drop_chance'].toString()) ?? 0,
      );

  String get resolvedAsset {
    if (imageAsset != null && imageAsset!.startsWith('assets/')) return imageAsset!;
    if (imageAsset != null) return 'assets/gifts/$imageAsset';
    return 'assets/gifts/$itemId.png';
  }

  @override
  List<Object?> get props => [itemId, dropChance];
}

class CaseOpenWon extends Equatable {
  final String inventoryId;
  final String itemId;
  final String name;
  final int priceCoins;
  final String rarity;
  final String? imageAsset;
  final double dropChance;
  final double roll;

  const CaseOpenWon({
    required this.inventoryId,
    required this.itemId,
    required this.name,
    required this.priceCoins,
    required this.rarity,
    this.imageAsset,
    required this.dropChance,
    required this.roll,
  });

  factory CaseOpenWon.fromJson(Map<String, dynamic> j) => CaseOpenWon(
        inventoryId: (j['inventory_id'] ?? j['id'] ?? '').toString(),
        itemId: (j['item_id'] ?? '').toString(),
        name: (j['name'] ?? j['item_id'] ?? '').toString(),
        priceCoins: j['price_coins'] == null ? 0 : int.tryParse(j['price_coins'].toString()) ?? 0,
        rarity: (j['rarity'] ?? 'common').toString(),
        imageAsset: j['image_asset']?.toString(),
        dropChance: j['drop_chance'] == null ? 0 : double.tryParse(j['drop_chance'].toString()) ?? 0,
        roll: j['roll'] == null ? 0 : double.tryParse(j['roll'].toString()) ?? 0,
      );

  String get resolvedAsset {
    if (imageAsset != null && imageAsset!.startsWith('assets/')) return imageAsset!;
    if (imageAsset != null) return 'assets/gifts/$imageAsset';
    return 'assets/gifts/$itemId.png';
  }

  @override
  List<Object?> get props => [inventoryId, itemId];
}
