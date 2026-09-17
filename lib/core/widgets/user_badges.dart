import 'package:flutter/material.dart';

/// Статусы возле ника мини-иконками:
/// owner, developer, moderator, media, verified, top — теперь это
/// мини-фото из assets/nickpik/*.png, guarantor — fallback emoji.
class UserBadges {
  UserBadges._();

  /// Legacy emoji — остается для админки / fallback.
  static const Map<String, String> icons = {
    'owner': '👑',
    'developer': '🛠️',
    'moderator': '🛡️',
    'media': '📣',
    'verified': '✅',
    'guarantor': '🤝',
    'top': '🏆',
  };

  /// Пути к картинкам из assets/nickpik.
  static const Map<String, String> assets = {
    'owner': 'assets/nickpik/owner.png',
    'developer': 'assets/nickpik/developer.png',
    'moderator': 'assets/nickpik/moderator.png',
    'media': 'assets/nickpik/media.png',
    'verified': 'assets/nickpik/verefication.png',
    'top': 'assets/nickpik/leader.png',
    // guarantor intentionally has no image — fallback to emoji
  };

  /// Проверка что бейдж известен (либо есть asset либо emoji).
  static bool isKnown(String badge) =>
      assets.containsKey(badge) || icons.containsKey(badge);

  static const Map<String, String> namesRu = {
    'owner': 'Владелец',
    'developer': 'Разработчик',
    'moderator': 'Модератор',
    'media': 'Медиа-партнёр',
    'verified': 'Верифицирован',
    'guarantor': 'Гарант',
    'top': 'Лидер топа',
  };

  static const Map<String, String> namesUk = {
    'owner': 'Власник',
    'developer': 'Розробник',
    'moderator': 'Модератор',
    'media': 'Медіа-партнер',
    'verified': 'Верифікований',
    'guarantor': 'Гарант',
    'top': 'Лідер топу',
  };

  static const Map<String, String> namesEn = {
    'owner': 'Owner',
    'developer': 'Developer',
    'moderator': 'Moderator',
    'media': 'Media partner',
    'verified': 'Verified',
    'guarantor': 'Guarantor',
    'top': 'Top leader',
  };

  /// Все известные коды (для админки).
  static List<String> get all => icons.keys.toList();

  static String nameOf(String badge, String locale) {
    final table = switch (locale) {
      'uk' => namesUk,
      'en' => namesEn,
      _ => namesRu,
    };
    return table[badge] ?? badge;
  }
}

/// Ряд мини-иконок статусов после ника — теперь Image.asset вместо emoji.
class UserBadgesRow extends StatelessWidget {
  final List<String> badges;
  final double size;
  final String locale;

  const UserBadgesRow({
    super.key,
    required this.badges,
    this.size = 13,
    this.locale = 'ru',
  });

  @override
  Widget build(BuildContext context) {
    final known = badges.where((b) => UserBadges.isKnown(b)).toList();
    if (known.isEmpty) return const SizedBox.shrink();
    // Картинки чуть крупнее чем текст: size = fontSize, image = size * 1.35
    final double imgSize = (size * 1.45).clamp(14.0, 28.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final b in known)
          Tooltip(
            message: UserBadges.nameOf(b, locale),
            child: Padding(
              padding: const EdgeInsets.only(left: 3),
              child: _BadgeIcon(badge: b, size: imgSize, fontSize: size),
            ),
          ),
      ],
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final String badge;
  final double size;
  final double fontSize;
  const _BadgeIcon({required this.badge, required this.size, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final asset = UserBadges.assets[badge];
    if (asset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Text(
            UserBadges.icons[badge] ?? '',
            style: TextStyle(fontSize: fontSize),
          ),
        ),
      );
    }
    // Fallback emoji for guarantor etc.
    return Text(
      UserBadges.icons[badge] ?? '',
      style: TextStyle(fontSize: fontSize),
    );
  }
}
