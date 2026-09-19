import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../../providers/balance_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/theme_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../main.dart';

/// Общий фон всех экранов: градиент + мягкие пятна.
/// Подстраивается под тёмную / оранжевую / синюю / светлую темы.
class BrandBackground extends ConsumerWidget {
  final Widget child;
  const BrandBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = switch (appTheme) {
      AppThemeId.darkOrange => const [AppColors.darkOrangeBgTop, AppColors.darkOrangeBgBottom],
      AppThemeId.darkBlue => const [AppColors.darkBlueBgTop, AppColors.darkBlueBgBottom],
      AppThemeId.light => const [AppColors.lightBgTop, AppColors.lightBgBottom],
      _ => isDark ? const [AppColors.darkBgTop, AppColors.darkBgBottom] : const [AppColors.lightBgTop, AppColors.lightBgBottom],
    };
    final glowColor = switch (appTheme) {
      AppThemeId.darkOrange => AppColors.darkOrangeAccent,
      AppThemeId.darkBlue => AppColors.darkBlueAccent,
      _ => const Color(0xFF2BE34A),
    };
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          // Декоративные пятна — не перехватывают жесты.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GlowPainter(isDark: isDark, glowColor: glowColor, appTheme: appTheme),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final bool isDark;
  final Color glowColor;
  final AppThemeId appTheme;
  _GlowPainter({required this.isDark, required this.glowColor, required this.appTheme});

  @override
  void paint(Canvas canvas, Size size) {
    // Упрощено для производительности на ПК: только 2 мягких круга без луча и shader
    // (луч с LinearGradient и rotate вызывал лаги на 1920x1080)
    if (!isDark) {
      final soft = Paint()..color = const Color(0x103EDB5A);
      canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.12), 80, soft);
      canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.05), 100, soft);
      return;
    }
    final soft = Paint()..color = glowColor.withOpacity(0.09);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.08), 95, soft);
    canvas.drawCircle(Offset(size.width * 0.90, size.height * 0.92), 110, soft);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) => old.isDark != isDark || old.glowColor != glowColor || old.appTheme != appTheme;
}

/// Заголовок экрана 1в1 с макетов:
/// зелёная палочка + жирный титул + серый подзаголовок слева,
/// справа — пилюля пользователя + кнопка инвентаря.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showBack;
  const ScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBack)
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 2),
              child: _CircleIconBtn(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.canPop() ? context.pop() : context.go('/home'),
              ),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 5,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.brandNeon : AppColors.brandGreen,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: isDark
                        ? [
                            BoxShadow(
                              color: AppColors.brandNeon.withOpacity(0.7),
                              blurRadius: 10,
                            )
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: isDark ? Colors.white : const Color(0xFF101410),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white38 : const Color(0xFF8A94A6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const _FullscreenBtn(),
          const SizedBox(width: 6),
          const _InventoryBtn(),
          const SizedBox(width: 6),
          const NotificationBell(),
          const SizedBox(width: 8),
          const UserPill(),
        ],
      ),
    );
  }
}

class _FullscreenBtn extends ConsumerWidget {
  const _FullscreenBtn();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Показываем только на десктопе
    if (!(Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS)) {
      // Fallback проверка через Platform.isXXX невозможна в web, поэтому прячем по умолчанию на mobile
      // но всё равно показываем кнопку — на mobile она тогглит immersive mode
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFs = ref.watch(fullscreenProvider);
    return _PressScale(
      onTap: () => ref.read(fullscreenProvider.notifier).toggle(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : const Color(0x14000000)),
        ),
        child: Icon(isFs ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, size: 19, color: isDark ? AppColors.brandNeon : AppColors.brandGreenDeep),
      ),
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : const Color(0x14000000),
          ),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

/// Кнопка инвентаря в правом верхнем углу (рюкзак).
class _InventoryBtn extends StatelessWidget {
  const _InventoryBtn();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _PressScale(
      onTap: () => context.push('/inventory'),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : const Color(0x14000000),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.backpack_rounded,
              size: 19,
              color: isDark ? AppColors.brandNeon : AppColors.brandGreenDeep,
            ),
            Positioned(
              right: 7,
              top: 7,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.brandNeon : AppColors.brandGreen,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF0D1510) : Colors.white,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Колокольчик уведомлений под ID: при нажатии открывается меню с уведомлениями, можно выйти.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});
  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationsProvider.notifier).refresh());
    // авто-обновление каждые 20 сек
    Future.delayed(const Duration(seconds: 20), _loop);
  }

  void _loop() {
    if (!mounted) return;
    ref.read(notificationsProvider.notifier).refresh();
    Future.delayed(const Duration(seconds: 20), _loop);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unread = ref.watch(notificationsProvider.notifier).unread;
    return _PressScale(
      onTap: () => _showNotifications(context, ref, isDark),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : const Color(0x14000000)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, size: 19, color: isDark ? AppColors.brandNeon : AppColors.brandGreenDeep),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(99)),
                  child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context, WidgetRef ref, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121A14) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Consumer(
            builder: (c, ref2, _) {
              final async = ref2.watch(notificationsProvider);
              return Column(
                children: [
                  const SizedBox(height: 10),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(99))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        const Text('Уведомления', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        TextButton(onPressed: () => ref2.read(notificationsProvider.notifier).markAllRead(), child: const Text('Прочитать все')),
                        IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: async.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Ошибка: $e')),
                      data: (list) {
                        if (list.isEmpty) return const Center(child: Text('Пока нет уведомлений', style: TextStyle(color: Colors.grey)));
                        return ListView.separated(
                          controller: ctrl,
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final n = list[i];
                            final icon = switch (n.type) {
                              'role' => '🎭',
                              'ticket' => '🎫',
                              'update' => '📢',
                              'balance' => '💰',
                              'trade' => n.title.contains('принял') ? '🤝' : '❌',
                              'leader' => '🏆',
                              'daily' => '📅',
                              _ => '🔔',
                            };
                            return ListTile(
                              leading: Text(icon, style: const TextStyle(fontSize: 22)),
                              title: Text(n.title, style: TextStyle(fontSize: 13, fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800)),
                              subtitle: Text(n.body, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              trailing: n.isRead ? null : IconButton(icon: const Icon(Icons.done_rounded, size: 16), onPressed: () => ref2.read(notificationsProvider.notifier).markRead(n.id)),
                              onTap: () => ref2.read(notificationsProvider.notifier).markRead(n.id),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Выйти')),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Пилюля пользователя справа вверху: аватар + ник + ID + стрелка.
/// Тап — меню: профиль / тема / выйти.
class UserPill extends ConsumerWidget {
  const UserPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nick = user.displayName.isEmpty ? 'brautkk' : user.displayName;
    final shortId = user.id.length >= 6 ? user.id.substring(0, 6) : user.id;

    return _PressScale(
      onTap: () => _showUserMenu(context, ref, isDark),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : const Color(0x14000000),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Builder(builder: (_) {
                  ImageProvider? avatarImage;
                  if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
                    final url = user.avatarUrl!;
                    avatarImage = url.startsWith('assets/') ? AssetImage(url) as ImageProvider : NetworkImage(url) as ImageProvider;
                  }
                  return CircleAvatar(
                    radius: 14,
                    backgroundColor: isDark ? const Color(0xFF1C2A20) : const Color(0xFFE8F5E9),
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Text(
                            nick.characters.first.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: isDark ? AppColors.brandNeon : AppColors.brandGreenDeep,
                            ),
                          )
                        : null,
                  );
                }),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.brandGlow,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF0D1510) : Colors.white,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nick,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF101410),
                  ),
                ),
                Text(
                  'ID: $shortId',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : const Color(0xFF8A94A6),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isDark ? Colors.white54 : const Color(0xFF8A94A6),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserMenu(BuildContext context, WidgetRef ref, bool isDark) {
    final themeMode = ref.read(themeModeProvider);
    final l10n = AppLocalizations.of(context);
    final currentLoc = GoRouterState.of(context).matchedLocation;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121A14) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : const Color(0x14000000),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
            _menuTile(ctx, Icons.person_outline_rounded,
                l10n.t('um_profile'), () {
              Navigator.pop(ctx);
              if (currentLoc != '/profile') ctx.push('/profile');
            }),
            _menuTile(ctx, Icons.backpack_outlined,
                l10n.t('um_inventory'), () {
              Navigator.pop(ctx);
              if (currentLoc != '/inventory') ctx.push('/inventory');
            }),
            _menuTile(
              ctx,
              themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              themeMode == ThemeMode.dark
                  ? l10n.t('um_light')
                  : l10n.t('um_dark'),
              () {
                Navigator.pop(ctx);
                ref.read(themeModeProvider.notifier).setMode(
                      themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                    );
              },
            ),
            _menuTile(ctx, Icons.settings_outlined,
                l10n.t('um_settings'), () {
              Navigator.pop(ctx);
              if (currentLoc != '/settings') ctx.push('/settings');
            }),
            _menuTile(
                ctx, Icons.support_agent_outlined, l10n.t('um_support'),
                () {
              Navigator.pop(ctx);
              if (currentLoc != '/support') ctx.push('/support');
            }),
            const Divider(height: 8),
            _menuTile(ctx, Icons.logout_rounded, l10n.t('um_logout'), () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            }, danger: true),
            const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuTile(BuildContext ctx, IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    return ListTile(
      leading: Icon(icon, color: danger ? AppColors.danger : null, size: 20),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.visible,
        softWrap: false,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: danger ? AppColors.danger : null,
          decoration: TextDecoration.none,
        ),
      ),
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

/// Карточка раздела в стиле макетов: скругление 20, тонкая рамка,
/// опциональная неоновая подсветка (Shop), ховер-приподнимание на десктопе
/// и scale-анимация при нажатии. Внутри — произвольный контент.
class BrandCard extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool highlighted;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const BrandCard({
    super.key,
    required this.child,
    this.onTap,
    this.highlighted = false,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 20,
  });

  @override
  ConsumerState<BrandCard> createState() => _BrandCardState();
}

class _BrandCardState extends ConsumerState<BrandCard> {
  bool _hover = false;
  bool _press = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appTheme = ref.watch(appThemeProvider);
    final green = switch (appTheme) {
      AppThemeId.darkOrange => AppColors.darkOrangeNeon,
      AppThemeId.darkBlue => AppColors.darkBlueNeon,
      _ => isDark ? AppColors.brandNeon : AppColors.brandGreen,
    };

    final bg = switch (appTheme) {
      AppThemeId.darkOrange => const Color(0xFF2A1B12).withOpacity(0.94),
      AppThemeId.darkBlue => const Color(0xFF162040).withOpacity(0.94),
      _ => isDark ? const Color(0xFF0F1712).withOpacity(0.92) : Colors.white,
    };
    final border = widget.highlighted
        ? green.withOpacity(isDark ? 0.9 : 0.7)
        : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE3E8E3));

    // Убраны тяжёлые boxShadow и hover-анимация для ПК — причина лагов на 1080p
    return MouseRegion(
      onEnter: (_) {
        if (widget.onTap != null) setState(() => _hover = true);
      },
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _press = true),
        onTapUp: (_) => setState(() => _press = false),
        onTapCancel: () => setState(() => _press = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _press ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: border, width: widget.highlighted ? 1.4 : 1),
              // BoxShadow убран/упрощён для производительности
              boxShadow: widget.highlighted
                  ? [BoxShadow(color: green.withOpacity(isDark ? 0.18 : 0.12), blurRadius: 12, spreadRadius: -2)]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Маленькая круглая стрелка → как на макетах (справа внизу карточки).
class GreenArrowBtn extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;
  const GreenArrowBtn({super.key, this.onTap, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.brandNeon.withOpacity(0.14)
        : AppColors.brandGreen.withOpacity(0.12);
    final fg = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final w = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
        child: Icon(Icons.arrow_forward_rounded, size: 16, color: fg),
      ),
    );
    return w;
  }
}

/// Плавное появление элементов сетки: fade + slide up + лёгкий scale.
/// [index] задаёт stagger-задержку.
class EntranceAnim extends StatefulWidget {
  final int index;
  final Widget child;
  const EntranceAnim({super.key, this.index = 0, required this.child});

  @override
  State<EntranceAnim> createState() => _EntranceAnimState();
}

class _EntranceAnimState extends State<EntranceAnim> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // Оптимизировано для ПК: уменьшена длительность и стаггер, меньше нагрузки на vsync
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    // Ограничиваем задержку чтобы не спамить таймерами при большом списке
    final delay = (widget.index % 6) * 40;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _c.forward();
    });
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _fade = Tween(begin: 0.0, end: 1.0).animate(curve);
    _slide = Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(curve);
    _scale = Tween(begin: 0.98, end: 1.0).animate(curve);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

/// Нажатие с пружинкой (для пилюли, иконок, маленьких кнопок).
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressScale({required this.child, required this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  double _s = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _s = 0.93),
      onTapUp: (_) => setState(() => _s = 1.0),
      onTapCancel: () => setState(() => _s = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _s,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

/// Плашка "Выбранный подарок" — зелёный pill как на макете апгрейдера.
class PickedBadge extends StatelessWidget {
  final String text;
  const PickedBadge({super.key, this.text = 'Выбранный подарок'});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.brandNeon : AppColors.brandGreen).withOpacity(0.13),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: (isDark ? AppColors.brandNeon : AppColors.brandGreen).withOpacity(0.35),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.brandNeon : AppColors.brandGreenDeep,
        ),
      ),
    );
  }
}
