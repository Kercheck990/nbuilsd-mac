import 'package:equatable/equatable.dart';

/// Статусы-галочки возле ника: owner, developer, moderator, media,
/// verified, guarantor, top.
class AppUser extends Equatable {
  final String id;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final int balanceCoins;
  final int balanceNc; // NFT Coin
  final String? walletAddress; // TON wallet, if linked
  final String? telegramHandle;
  final bool isAdmin;
  final List<String> badges;
  final bool tfaEnabled;
  final bool telegramLinked;
  final int playtimeSeconds;

  const AppUser({
    required this.id,
    required this.displayName,
    required this.balanceCoins,
    this.balanceNc = 30,
    this.email,
    this.avatarUrl,
    this.walletAddress,
    this.telegramHandle,
    this.isAdmin = false,
    this.badges = const [],
    this.tfaEnabled = false,
    this.telegramLinked = false,
    this.playtimeSeconds = 0,
  });

  int get playtimeHours => playtimeSeconds ~/ 3600;

  AppUser copyWith({
    String? displayName,
    String? email,
    String? avatarUrl,
    int? balanceCoins,
    int? balanceNc,
    String? walletAddress,
    String? telegramHandle,
    bool? isAdmin,
    List<String>? badges,
    bool? tfaEnabled,
    bool? telegramLinked,
    int? playtimeSeconds,
  }) {
    return AppUser(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      balanceCoins: balanceCoins ?? this.balanceCoins,
      balanceNc: balanceNc ?? this.balanceNc,
      walletAddress: walletAddress ?? this.walletAddress,
      telegramHandle: telegramHandle ?? this.telegramHandle,
      isAdmin: isAdmin ?? this.isAdmin,
      badges: badges ?? this.badges,
      tfaEnabled: tfaEnabled ?? this.tfaEnabled,
      telegramLinked: telegramLinked ?? this.telegramLinked,
      playtimeSeconds: playtimeSeconds ?? this.playtimeSeconds,
    );
  }

  /// Пользователь из ответа сервера (/api/me, login, verify).
  factory AppUser.fromServer(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'].toString(),
      displayName: json['nickname'] as String? ?? 'Player',
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      balanceCoins: (json['balance_coins'] as num?)?.toInt() ?? 0,
      balanceNc: (json['balance_nc'] as num?)?.toInt() ?? 30,
      telegramHandle: json['telegram_username'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      badges: ((json['badges'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      tfaEnabled: json['tfa_enabled'] as bool? ?? false,
      telegramLinked: json['telegram_linked'] as bool? ?? false,
      playtimeSeconds: (json['playtime_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        displayName,
        email,
        avatarUrl,
        balanceCoins,
        balanceNc,
        walletAddress,
        telegramHandle,
        isAdmin,
        badges,
        tfaEnabled,
        telegramLinked,
        playtimeSeconds,
      ];
}
