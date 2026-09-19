import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_model.dart';

class UserNotifier extends StateNotifier<AppUser> {
  UserNotifier()
      : super(const AppUser(
          id: 'local_user',
          displayName: 'Player',
          balanceCoins: 0,
          balanceNc: 0,
        ));

  /// Подставляет пользователя, пришедшего с сервера (после входа или
  /// обновления баланса).
  void setUser(AppUser user) => state = user;

  void setBalance(int coins) => state = state.copyWith(balanceCoins: coins);
  void setNc(int nc) => state = state.copyWith(balanceNc: nc);

  void reset() => state = const AppUser(
        id: 'guest',
        displayName: 'Guest',
        balanceCoins: 0,
        balanceNc: 0,
      );

  void addCoins(int amount) {
    state = state.copyWith(balanceCoins: state.balanceCoins + amount);
  }

  bool spendCoins(int amount) {
    if (state.balanceCoins < amount) return false;
    state = state.copyWith(balanceCoins: state.balanceCoins - amount);
    return true;
  }

  void addNc(int amount) => state = state.copyWith(balanceNc: state.balanceNc + amount);
  bool spendNc(int amount) {
    if (state.balanceNc < amount) return false;
    state = state.copyWith(balanceNc: state.balanceNc - amount);
    return true;
  }

  void setWallet(String address) => state = state.copyWith(walletAddress: address);

  void clearWallet() => state = state.copyWith(walletAddress: null);
}

final userProvider = StateNotifierProvider<UserNotifier, AppUser>((ref) {
  return UserNotifier();
});

/// Tracks how many coins the player has staked today, for the Responsible
/// Gaming daily limit feature. Resets are not persisted across app
/// restarts in this mock — a real build should key this by calendar day
/// in local storage.
class DailyStakeNotifier extends StateNotifier<double> {
  DailyStakeNotifier() : super(0);

  void addStake(double amount) => state += amount;

  void reset() => state = 0;
}

final dailyStakeProvider =
    StateNotifierProvider<DailyStakeNotifier, double>((ref) => DailyStakeNotifier());
