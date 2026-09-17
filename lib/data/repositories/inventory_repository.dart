import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_client.dart';
import '../models/nft_item.dart';

/// Инвентарь игрока — источник правды сервер (GET /api/inventory).
/// Стартовый инвентарь пуст: подарки при входе больше не выдаются.
class InventoryNotifier extends StateNotifier<List<NftItem>> {
  InventoryNotifier() : super(const []);

  bool _loading = false;

  /// Подтягивает инвентарь с сервера. При ошибке сети оставляет
  /// прошлый список (офлайн-режим чтения).
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final items = await ApiClient.instance.inventory();
      state = items.map((i) => i.copyWith(isOwned: true)).toList();
    } catch (_) {
      // сеть недоступна — показываем кэш
    } finally {
      _loading = false;
    }
  }

  void clear() => state = const [];

  /// Локальное удаление после серверной операции (продажа/апгрейд),
  /// полный синк делает refresh().
  void removeItems(Iterable<String> ids) {
    state = state.where((item) => !ids.contains(item.id)).toList();
  }

  void addItem(NftItem item) {
    state = [...state, item.copyWith(isOwned: true)];
  }
}

final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, List<NftItem>>((ref) {
  return InventoryNotifier();
});

/// Каталог магазина/целей — источник правды сервер (GET /api/items).
class CatalogNotifier extends StateNotifier<List<NftItem>> {
  CatalogNotifier() : super(const []);

  bool _loading = false;

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      state = await ApiClient.instance.catalog();
    } catch (_) {
      // сеть недоступна — оставляем прошлый список
    } finally {
      _loading = false;
    }
  }

  void clear() => state = const [];
}

final catalogProvider =
    StateNotifierProvider<CatalogNotifier, List<NftItem>>((ref) {
  return CatalogNotifier();
});
