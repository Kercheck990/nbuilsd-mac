import 'package:equatable/equatable.dart';
import 'nft_item.dart';

/// Outcome of a single upgrade round, as returned by [UpgradeApiService].
///
/// [serverSeed] is only revealed *after* the round resolves (provably-fair
/// pattern): the server commits to sha256(serverSeed) beforehand, then
/// reveals serverSeed afterwards so the player can recompute the roll.
class UpgradeResult extends Equatable {
  final String roundId;
  final bool success;
  /// true, если Сейвы вернули ставку при проигрыше.
  final bool saved;
  /// Множитель удачи ивента (1/2/4).
  final int luckMultiplier;
  final double chancePercent;
  final double rollPercent; // the actual roll, 0-100
  final String serverSeedHash; // committed before the round
  final String serverSeed; // revealed after the round
  final String clientSeed;
  final int nonce;
  final DateTime timestamp;
  final List<NftItem> stakedItems;
  final int stakedCoins;
  final NftItem targetItem;

  const UpgradeResult({
    required this.roundId,
    required this.success,
    this.saved = false,
    this.luckMultiplier = 1,
    required this.chancePercent,
    required this.rollPercent,
    required this.serverSeedHash,
    required this.serverSeed,
    required this.clientSeed,
    required this.nonce,
    required this.timestamp,
    required this.stakedItems,
    required this.stakedCoins,
    required this.targetItem,
  });

  @override
  List<Object?> get props => [
        roundId,
        success,
        saved,
        luckMultiplier,
        chancePercent,
        rollPercent,
        serverSeedHash,
        serverSeed,
        clientSeed,
        nonce,
        timestamp,
        stakedItems,
        stakedCoins,
        targetItem,
      ];
}

/// A lightweight feed entry for the live/global history screen.
class FeedEntry extends Equatable {
  final String playerName;
  final String? avatarUrl;
  final String fromLabel;
  final String toLabel;
  final double chancePercent;
  final bool success;
  final DateTime timestamp;

  const FeedEntry({
    required this.playerName,
    required this.fromLabel,
    required this.toLabel,
    required this.chancePercent,
    required this.success,
    required this.timestamp,
    this.avatarUrl,
  });

  @override
  List<Object?> get props =>
      [playerName, avatarUrl, fromLabel, toLabel, chancePercent, success, timestamp];
}
