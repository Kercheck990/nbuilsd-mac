import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/nft_item.dart';
import '../../../data/models/upgrade_result.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../providers/balance_provider.dart';
import '../../../services/api_client.dart';
import '../../../services/rng_service.dart';

enum UpgradeStatus { idle, spinning, success, failure }

class UpgradeSessionState {
  final List<NftItem> stakedItems;
  final bool useBalance;
  final int balanceStakeAmount;
  final NftItem? targetItem;
  final UpgradeStatus status;
  final UpgradeResult? lastResult;

  const UpgradeSessionState({
    this.stakedItems = const [],
    this.useBalance = false,
    this.balanceStakeAmount = 0,
    this.targetItem,
    this.status = UpgradeStatus.idle,
    this.lastResult,
  });

double get totalStakeValue =>
      (stakedItems.fold<int>(0, (sum, i) => sum + i.priceInCoins) +
      (useBalance ? balanceStakeAmount : 0)).toDouble();

  /// «Сырой» шанс без потолка — нужен, чтобы понять, что игрок вышел за
  /// границу 75%, и объяснить ему это в интерфейсе.
  double get rawChancePercent {
    if (targetItem == null || totalStakeValue <= 0) return 0;
    if (targetItem!.priceInCoins <= 0) return 0;
    return (totalStakeValue / targetItem!.priceInCoins) * 100.0;
  }

  /// Шанс, который показывается на шкале. Ограничен снизу минимумом и
  /// сверху ЖЁСТКИМ потолком 75% ([AppConstants.maxChancePercent]).
  double get chancePercent {
    if (targetItem == null || totalStakeValue <= 0) {
      return AppConstants.minChancePercent;
    }
    return ChanceCalculator.compute(
      totalStakeValue: totalStakeValue,
      targetValue: targetItem!.priceInCoins.toDouble(),
      minPercent: AppConstants.minChancePercent,
      maxPercent: AppConstants.maxChancePercent,
    );
  }

  /// Ставка слишком велика относительно цели: шанс превысил бы 75%.
  /// В этом случае апгрейд запрещён — игрок должен либо уменьшить
  /// ставку, либо выбрать более дорогую цель.
  bool get isOverMaxLimit =>
      targetItem != null &&
      totalStakeValue > 0 &&
      rawChancePercent > AppConstants.maxChancePercent + 0.0001;

  bool get canUpgrade =>
      targetItem != null &&
      totalStakeValue > 0 &&
      !isOverMaxLimit &&
      status != UpgradeStatus.spinning;

  UpgradeSessionState copyWith({
    List<NftItem>? stakedItems,
    bool? useBalance,
    int? balanceStakeAmount,
    NftItem? targetItem,
    bool clearTargetItem = false,
    UpgradeStatus? status,
    UpgradeResult? lastResult,
  }) {
    return UpgradeSessionState(
      stakedItems: stakedItems ?? this.stakedItems,
      useBalance: useBalance ?? this.useBalance,
      balanceStakeAmount: balanceStakeAmount ?? this.balanceStakeAmount,
      targetItem: clearTargetItem ? null : (targetItem ?? this.targetItem),
      status: status ?? this.status,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class UpgradeSessionNotifier extends StateNotifier<UpgradeSessionState> {
  UpgradeSessionNotifier(this._ref) : super(const UpgradeSessionState());

  final Ref _ref;

  void toggleStakeItem(NftItem item) {
    final already = state.stakedItems.any((i) => i.id == item.id);
    if (already) {
      state = state.copyWith(
          stakedItems: state.stakedItems.where((i) => i.id != item.id).toList());
    } else {
      state = state.copyWith(stakedItems: [...state.stakedItems, item]);
    }
  }

  void setUseBalance(bool value, {int? amount}) {
    state = state.copyWith(
      useBalance: value,
      balanceStakeAmount: amount ?? state.balanceStakeAmount,
    );
  }

  void setBalanceStakeAmount(int amount) {
    state = state.copyWith(balanceStakeAmount: amount);
  }

  void setTargetItem(NftItem item) {
    state = state.copyWith(targetItem: item);
  }

  void clearTargetItem() {
    state = state.copyWith(clearTargetItem: true);
  }

  /// Минимальная цена цели, при которой шанс ещё не превышает 75%.
  double get minTargetPriceForLimit =>
      state.totalStakeValue / (AppConstants.maxChancePercent / 100.0);

  void applyQuickMultiplier(double multiplier) {
    final catalog = _ref.read(catalogProvider);
    final desiredValue = state.totalStakeValue * multiplier;
    final match = _closestByPrice(catalog, desiredValue, allowOnlyValid: true);
    if (match != null) setTargetItem(match);
  }

  /// Быстрый выбор цели под заданный шанс. Значения выше 75% игнорируются.
  void applyQuickChance(double chancePercent) {
    if (state.totalStakeValue <= 0) return;
    final capped = chancePercent.clamp(
        AppConstants.minChancePercent, AppConstants.maxChancePercent);
    final catalog = _ref.read(catalogProvider);
    final desiredValue = state.totalStakeValue / (capped / 100.0);
    final match = _closestByPrice(catalog, desiredValue, allowOnlyValid: true);
    if (match != null) setTargetItem(match);
  }

  /// Ищет ближайший по цене предмет. При [allowOnlyValid] отбрасывает
  /// цели, которые дали бы шанс выше 75% — их всё равно нельзя выбрать.
  NftItem? _closestByPrice(List<NftItem> items, double target,
      {bool allowOnlyValid = false}) {
    var pool = items;
    if (allowOnlyValid && state.totalStakeValue > 0) {
      final minPrice = minTargetPriceForLimit;
      final valid = items.where((i) => i.priceInCoins >= minPrice).toList();
      if (valid.isNotEmpty) pool = valid;
    }
    if (pool.isEmpty) return null;
    return pool.reduce((a, b) =>
        (a.priceInCoins - target).abs() < (b.priceInCoins - target).abs() ? a : b);
  }

  void clearAfterFailure() {
    state = const UpgradeSessionState();
  }

  void resetForNextRound() {
    state = state.copyWith(
      stakedItems: [],
      useBalance: false,
      balanceStakeAmount: 0,
      clearTargetItem: true,
      status: UpgradeStatus.idle,
    );
  }

  /// Полный раунд на сервере: клиент присылает только ставку и цель,
  /// шанс/ролл/исход считает сервер (источник правды). Потолок 75%
  /// и множители ивентов применяются там же.
  ///
  /// Угол остановки анимации ВСЕГДА выводится из [UpgradeResult.rollPercent],
  /// клиент не решает исход сам.
  Future<UpgradeResult> runUpgrade() async {
    final target = state.targetItem;
    if (target == null || !state.canUpgrade) {
      throw StateError('Нельзя начать раунд: нет цели/ставки или шанс выше 75%');
    }

    state = state.copyWith(status: UpgradeStatus.spinning);

    try {
      final stakeIds = state.stakedItems.map((i) => i.id).toList();
      final stakeCoins = state.useBalance ? state.balanceStakeAmount : 0;

      final res = await ApiClient.instance.upgrade(
        stakeInventoryIds: stakeIds,
        stakeCoins: stakeCoins,
        targetItemId: target.id,
      );

      final fairness = (res['fairness'] as Map?) ?? const {};
      final result = UpgradeResult(
        roundId: res['round_id'].toString(),
        success: res['success'] as bool? ?? false,
        saved: res['saved'] as bool? ?? false,
        luckMultiplier: (res['luck_multiplier'] as num?)?.toInt() ?? 1,
        chancePercent: (res['chance_percent'] as num?)?.toDouble() ?? 0,
        rollPercent: (res['roll_percent'] as num?)?.toDouble() ?? 0,
        serverSeedHash: fairness['server_seed_hash']?.toString() ?? '',
        serverSeed: fairness['server_seed']?.toString() ?? '',
        clientSeed: fairness['client_seed']?.toString() ?? '',
        nonce: (fairness['nonce'] as num?)?.toInt() ?? 0,
        timestamp: DateTime.now(),
        stakedItems: state.stakedItems,
        stakedCoins: stakeCoins,
        targetItem: target,
      );

      // Сервер — источник правды: баланс NC из ответа, инвентарь перечитываем.
      final balanceNc = (res['balance_nc'] as num?)?.toInt() ?? (res['balance_coins'] as num?)?.toInt();
      if (balanceNc != null) {
        _ref.read(userProvider.notifier).setNc(balanceNc);
      }
      _ref.read(dailyStakeProvider.notifier).addStake(state.totalStakeValue);
      await _ref.read(inventoryProvider.notifier).refresh();

      state = state.copyWith(
        status: result.success ? UpgradeStatus.success : UpgradeStatus.failure,
        lastResult: result,
      );

      return result;
    } on ApiException {
      state = state.copyWith(status: UpgradeStatus.idle);
      rethrow;
    }
  }
}

final upgradeSessionProvider =
    StateNotifierProvider<UpgradeSessionNotifier, UpgradeSessionState>((ref) {
  return UpgradeSessionNotifier(ref);
});

/// История раундов (для профиля).
class UpgradeHistoryNotifier extends StateNotifier<List<UpgradeResult>> {
  UpgradeHistoryNotifier() : super([]);

  void add(UpgradeResult result) => state = [result, ...state];
}

final upgradeHistoryProvider =
    StateNotifierProvider<UpgradeHistoryNotifier, List<UpgradeResult>>((ref) {
  return UpgradeHistoryNotifier();
});
