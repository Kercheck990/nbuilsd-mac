import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/top_notify.dart';
import '../../data/models/user_model.dart';
import '../../providers/balance_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../services/api_client.dart';
import '../auth/providers/auth_provider.dart';

/// Настройки игрока в стиле макетов: карточки BrandCard,
/// зелёные акценты, анимации появления, живой предпросмотр темы.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final locale = ref.watch(localeProvider);
    final user = ref.watch(userProvider);
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(
                  title: l10n.t('settings_title'),
                  subtitle: l10n.t('se_sub'),
                  showBack: true,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      EntranceAnim(
                        index: 0,
                        child: _ProfileCard(
                          nick: user.displayName.isEmpty ? 'brautkk' : user.displayName,
                          balance: user.balanceCoins,
                          isDark: isDark,
                          userId: user.id,
                        ),
                      ),
                      const SizedBox(height: 14),
                      EntranceAnim(index: 0, child: _AvatarPicker()),
                      const SizedBox(height: 14),
                      EntranceAnim(
                        index: 1,
                        child: _NicknameCard(current: user.displayName),
                      ),
                      const SizedBox(height: 14),
                      EntranceAnim(
                        index: 2,
                        child: _SecurityCard(),
                      ),
                      const SizedBox(height: 14),
                      EntranceAnim(
                        index: 1,
                        child: _SectionCard(
                          title: l10n.t('se_look'),
                          icon: '🎨',
                          child: Column(
                            children: [
                              _ThemeSegmented(
                                current: themeMode,
                                onPick: (m) => ref
                                    .read(themeModeProvider.notifier)
                                    .setMode(m),
                              ),
                              const SizedBox(height: 10),
                              _AppThemePicker(),
                              const SizedBox(height: 6),
                              _AnimatedThemePreview(isDark: isDark),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      EntranceAnim(
                        index: 2,
                        child: _SectionCard(
                          title: l10n.t('se_sound'),
                          icon: '🔊',
                          child: Column(
                            children: [
                              _SwitchRow(
                                icon: Icons.volume_up_outlined,
                                label: l10n.t('settings_sound'),
                                value: settings.soundOn,
                                onChanged: notifier.setSoundOn,
                              ),
                              const Divider(height: 8),
                              _SwitchRow(
                                icon: Icons.music_note_outlined,
                                label: l10n.t('settings_music'),
                                value: settings.musicOn,
                                onChanged: notifier.setMusicOn,
                              ),
                              const Divider(height: 8),
                              _YoutubeMusicRow(),
                              if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
                                const Divider(height: 8),
                                Consumer(builder: (context, ref, _) {
                                  final isFs = ref.watch(fullscreenProvider);
                                  return _SwitchRow(
                                    icon: Icons.fullscreen_rounded,
                                    label: 'Полный экран (ПК)',
                                    value: isFs,
                                    onChanged: (_) => ref.read(fullscreenProvider.notifier).toggle(),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      EntranceAnim(
                        index: 3,
                        child: _SectionCard(
                          title: l10n.t('settings_language'),
                          icon: '🌐',
                          child: Column(
                            children: [
                              for (final e
                                  in AppLocalizations.languageNames.entries)
                                _LangRow(
                                  label: e.value,
                                  selected:
                                      locale.languageCode == e.key,
                                  onTap: () {
                                    ref
                                        .read(localeProvider.notifier)
                                        .setLocale(e.key);
                                    // Язык применяется мгновенно + сохраняется
                                    // на сервере для писем и уведомлений.
                                    ApiClient.instance.updateMe(
                                        locale: e.key);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      EntranceAnim(
                        index: 4,
                        child: _SectionCard(
                          title: l10n.t('settings_responsible'),
                          icon: '🛡️',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      l10n.f('se_daily', {
                                        'v': settings.dailyStakeLimit
                                            .toStringAsFixed(0)
                                      }),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    l10n.f('se_used', {
                                      'v': ref
                                          .watch(dailyStakeProvider)
                                          .toStringAsFixed(0)
                                    }),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              Slider(
                                value: settings.dailyStakeLimit,
                                min: 500,
                                max: 20000,
                                divisions: 39,
                                activeColor: isDark
                                    ? AppColors.brandNeon
                                    : AppColors.brandGreen,
                                label: settings.dailyStakeLimit
                                    .toStringAsFixed(0),
                                onChanged: notifier.setDailyStakeLimit,
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                    Icons.pause_circle_outline),
                                title: Text(
                                  l10n.t('se_pause'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14),
                                ),
                                subtitle: Text(
                                  l10n.t('se_pause_sub'),
                                  style:
                                      const TextStyle(fontSize: 12),
                                ),
                                trailing: const GreenArrowBtn(size: 28),
                                onTap: () =>
                                    _pauseDialog(context, l10n),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      EntranceAnim(
                        index: 5,
                        child: BrandCard(
                          onTap: () =>
                              ref.read(authProvider.notifier).logout(),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.danger
                                      .withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.logout_rounded,
                                  color: AppColors.danger,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l10n.t('auth_logout'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.danger,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'NFT-GRADER · v1.1.0',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

void _pauseDialog(BuildContext context, AppLocalizations l10n) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: Text(l10n.t('se_pause_title')),
      content: Text(
        l10n.t('se_pause_text'),
        style: const TextStyle(fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.t('se_pause_ok')),
        ),
      ],
    ),
  );
}
}

class _NicknameCard extends ConsumerStatefulWidget {
  final String current;
  const _NicknameCard({required this.current});

  @override
  ConsumerState<_NicknameCard> createState() => _NicknameCardState();
}

class _NicknameCardState extends ConsumerState<_NicknameCard> {
  late final _ctrl = TextEditingController(text: widget.current);
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nick = _ctrl.text.trim();
    if (nick.length < 3 || nick.length > 20 || _busy) return;
    setState(() => _busy = true);
    try {
      final res = await ApiClient.instance.updateMe(nickname: nick);
      ref
          .read(userProvider.notifier)
          .setUser(ref.read(userProvider).copyWith(displayName: nick));
      if (!mounted) return;
      TopNotify.show(context, context.l10n.t('se_nick_saved'), success: true);
      res; // ответ содержит user — локально уже обновили
    } on ApiException catch (e) {
      if (!mounted) return;
      TopNotify.show(context, context.l10n.t(e.code == 'nickname_taken' ? 'se_nick_taken' : 'se_nick_fail'), success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      child: Row(
        children: [
          const Text('✏️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: context.l10n.t('se_nick_label'),
                counterText: '',
                border: InputBorder.none,
              ),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              onSubmitted: (_) => _save(),
            ),
          ),
          TextButton(onPressed: _save, child: const Text('OK')),
        ],
      ),
    );
  }
}

/// Безопасность и связь: 2FA, Telegram, поддержка, админка.
class _SecurityCard extends ConsumerWidget {
  const _SecurityCard();

  Future<void> _refreshMe(WidgetRef ref) async {
    try {
      final me = await ApiClient.instance.me();
      ref
          .read(userProvider.notifier)
          .setUser(AppUser.fromServer(me['user']));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final l10n = context.l10n;

    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔐', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(l10n.t('se_security'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          // 2FA
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.shield_outlined, color: green),
            title: Text(l10n.t('se_2fa'),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              user.tfaEnabled
                  ? l10n.t('se_2fa_on')
                  : l10n.t('se_2fa_off'),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Switch(
              value: user.tfaEnabled,
              activeColor: green,
              onChanged: (v) => v
                  ? _enableTfa(context, ref)
                  : _disableTfa(context, ref),
            ),
            onTap: () => user.tfaEnabled
                ? _disableTfa(context, ref)
                : _enableTfa(context, ref),
          ),
          const Divider(height: 8),
          // Telegram
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.send_rounded, color: green),
            title: const Text('Telegram',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              user.telegramLinked
                  ? (user.telegramHandle ?? l10n.t('se_tg_linked'))
                  : l10n.t('se_tg_desc'),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const GreenArrowBtn(size: 28),
            onTap: () => user.telegramLinked
                ? _unlinkTg(context, ref)
                : _linkTg(context, ref),
          ),
          const Divider(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.support_agent_outlined, color: green),
            title: Text(l10n.t('se_support'),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(l10n.t('se_support_sub'),
                style: const TextStyle(fontSize: 12)),
            trailing: const GreenArrowBtn(size: 28),
            onTap: () => context.push('/support'),
          ),
          if (user.isAdmin) ...[
            const Divider(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.admin_panel_settings_outlined,
                  color: green),
              title: Text(l10n.t('se_admin'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
              subtitle: Text(l10n.t('se_admin_sub'),
                  style: const TextStyle(fontSize: 12)),
              trailing: const GreenArrowBtn(size: 28),
              onTap: () => context.push('/admin'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _enableTfa(BuildContext context, WidgetRef ref) async {
    try {
      await ApiClient.instance.tfaEnable();
    } on ApiException {
      if (context.mounted) {
        TopNotify.show(context, context.l10n.t('error_network'), success: false);
      }
      return;
    }
    if (!context.mounted) return;
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(context.l10n.t('se_2fa_code_title')),
        content: TextField(
          controller: code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            hintText: '000000',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.t('ok'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.instance.tfaConfirm(code: code.text.trim());
      await _refreshMe(ref);
      if (context.mounted) {
        TopNotify.show(context, context.l10n.t('se_2fa_enabled'), success: true);
      }
    } on ApiException {
      if (context.mounted) {
        TopNotify.show(context, context.l10n.t('se_2fa_bad'), success: false);
      }
    }
  }

  Future<void> _disableTfa(BuildContext context, WidgetRef ref) async {
    try {
      await ApiClient.instance.tfaDisable();
      await _refreshMe(ref);
      if (context.mounted) {
        TopNotify.show(context, context.l10n.t('se_2fa_disabled'), success: true);
      }
    } on ApiException {
      if (context.mounted) {
        TopNotify.show(context, context.l10n.t('error_network'), success: false);
      }
    }
  }

  Future<void> _linkTg(BuildContext context, WidgetRef ref) async {
    try {
      final res = await ApiClient.instance.telegramCode();
      final code = res['code'].toString();
      final settings = ref.read(appSettingsProvider);
      final bot = settings['tg_bot']?.trim() ?? '';
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text(context.l10n.t('se_tg_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.t('se_tg_hint'),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              SelectableText(
                code,
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6),
              ),
              if (bot.isNotEmpty) ...[
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () async {
                    final uri = Uri.tryParse(
                        bot.startsWith('http') ? bot : 'https://t.me/$bot');
                    if (uri != null) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(context.l10n.t('se_tg_open')),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.t('ok'))),
          ],
        ),
      );
    } on ApiException {
      if (context.mounted) {
        TopNotify.show(context, context.l10n.t('error_network'), success: false);
      }
    }
  }

  Future<void> _unlinkTg(BuildContext context, WidgetRef ref) async {
    try {
      await ApiClient.instance.telegramUnlink();
      await _refreshMe(ref);
      if (context.mounted) {
        TopNotify.show(context, context.l10n.t('se_tg_unlinked'), success: true);
      }
    } on ApiException {
      if (context.mounted) {
        TopNotify.show(context, context.l10n.t('error_network'), success: false);
      }
    }
  }
}

class _ProfileCard extends StatelessWidget {
  final String nick;
  final int balance;
  final bool isDark;
  final String userId;
  const _ProfileCard(
      {required this.nick, required this.balance, required this.isDark, required this.userId});

  @override
  Widget build(BuildContext context) {
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreen;
    return BrandCard(
      highlighted: true,
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: green.withOpacity(0.14),
                child: Text(
                  nick.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: green,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: AppColors.brandGlow,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF0D1510)
                            : Colors.white,
                        width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nick,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.monetization_on,
                        size: 15, color: green),
                    const SizedBox(width: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                          begin: 0, end: balance.toDouble()),
                      duration:
                          const Duration(milliseconds: 600),
                      builder: (_, v, __) => Text(
                        v.toStringAsFixed(0),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: green.withOpacity(0.13),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              'ID: ${userId.length > 8 ? userId.substring(0, 8) : userId}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.brandNeon
                    : AppColors.brandGreenDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String icon;
  final Widget child;
  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF101410),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AppThemePicker extends ConsumerWidget {
  const _AppThemePicker({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = ref.watch(appThemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget chip(AppThemeId id, String label, Color color) {
      final sel = cur == id;
      return GestureDetector(
        onTap: () => ref.read(appThemeProvider.notifier).setTheme(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? color : (isDark ? Colors.white12 : const Color(0xFFE3E8E3))),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? color : Colors.grey)),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Темы', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        chip(AppThemeId.dark, 'Тёмная', AppColors.brandNeon),
        chip(AppThemeId.light, 'Светлая', AppColors.brandGreenDeep),
        chip(AppThemeId.darkOrange, 'Тёмно-оранжевая', AppColors.darkOrangeAccent),
        chip(AppThemeId.darkBlue, 'Тёмно-синяя', AppColors.darkBlueAccent),
      ]),
    ]);
  }
}

class _ThemeSegmented extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onPick;
  const _ThemeSegmented({required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreen;
    Widget seg(ThemeMode m, IconData icon, String label) {
      final sel = current == m;
      return Expanded(
        child: GestureDetector(
          onTap: () => onPick(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? green.withOpacity(0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: sel
                    ? green
                    : (isDark ? Colors.white12 : const Color(0xFFE3E8E3)),
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    size: 18,
                    color: sel ? green : Colors.grey),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: sel ? green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        seg(ThemeMode.dark, Icons.dark_mode_outlined,
            l10n.t('settings_theme_dark')),
        const SizedBox(width: 8),
        seg(ThemeMode.light, Icons.light_mode_outlined,
            l10n.t('settings_theme_light')),
        const SizedBox(width: 8),
        seg(ThemeMode.system, Icons.settings_suggest_outlined,
            l10n.t('settings_theme_system')),
      ],
    );
  }
}

/// Живой мини-превью двух тем: две маленькие карточки.
class _AnimatedThemePreview extends StatelessWidget {
  final bool isDark;
  const _AnimatedThemePreview({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _previewTile(false, !isDark)),
        const SizedBox(width: 8),
        Expanded(child: _previewTile(true, isDark)),
      ],
    );
  }

  Widget _previewTile(bool dark, bool active) {
    final green = dark ? AppColors.brandNeon : AppColors.brandGreen;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0F1712) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? green : (dark ? Colors.white12 : const Color(0xFFE3E8E3)),
          width: active ? 1.6 : 1,
        ),
        boxShadow: active
            ? [BoxShadow(color: green.withOpacity(0.25), blurRadius: 14)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 8,
            width: 52,
            decoration: BoxDecoration(
              color: green.withOpacity(0.7),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 22,
            decoration: BoxDecoration(
              color: (dark ? Colors.white : Colors.black).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                height: 22,
                width: 44,
                decoration: BoxDecoration(
                  color: (dark ? Colors.white : Colors.black).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward,
                  size: 13, color: green),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon,
            size: 19,
            color: isDark
                ? AppColors.brandNeon
                : AppColors.brandGreenDeep),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        Switch(
          value: value,
          activeColor: isDark
              ? AppColors.brandNeon
              : AppColors.brandGreen,
          onChanged: (v) {
            onChanged(v);
          },
        ),
      ],
    );
  }
}

class _YoutubeMusicRow extends ConsumerStatefulWidget {
  const _YoutubeMusicRow();
  @override
  ConsumerState<_YoutubeMusicRow> createState() => _YoutubeMusicRowState();
}

class _YoutubeMusicRowState extends ConsumerState<_YoutubeMusicRow> {
  late final TextEditingController _ctrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(settingsProvider).userMusicUrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndPlay() async {
    final url = _ctrl.text.trim();
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(settingsProvider.notifier).setUserMusicUrl(url);
      if (url.isEmpty) {
        await ref.read(musicControllerProvider.notifier).stopCustom();
        if (mounted) {
          TopNotify.show(context, 'Музыка остановлена', success: false);
        }
        return;
      }
      // Пробуем сразу проиграть
      final ok = await ref.read(musicControllerProvider.notifier).playCustom(url);
      if (!mounted) return;
      if (ok) {
        TopNotify.show(context, 'Музыка запущена ✅', success: true);
      } else {
        TopNotify.show(context, 'Не удалось запустить — проверьте ссылку', success: false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    await ref.read(settingsProvider.notifier).setUserMusicUrl('');
    _ctrl.clear();
    await ref.read(musicControllerProvider.notifier).stopCustom();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final isPlaying = ref.watch(musicControllerProvider);
    final settings = ref.watch(settingsProvider);
    // Синхронизируем контроллер когда поле изменилось извне
    if (_ctrl.text != settings.userMusicUrl && !_busy) {
      // avoid cursor jump: only if not focused?
      // simple update on next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ctrl.text != settings.userMusicUrl) _ctrl.text = settings.userMusicUrl;
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.youtube_searched_for, size: 19, color: green),
            const SizedBox(width: 10),
            const Expanded(child: Text('YouTube музыка', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            if (isPlaying)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: green.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
                child: Row(children: [Icon(Icons.music_note, size: 12, color: green), const SizedBox(width: 4), Text('Играет', style: TextStyle(fontSize: 11, color: green, fontWeight: FontWeight.w700))]),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Вставь ссылку с YouTube (https://youtube.com/watch?v=...) и нажми ▶ — музыка заиграет у тебя локально. Работает с любыми mp3 ссылками тоже.', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : const Color(0xFF8A94A6))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/watch?v=...',
                  hintStyle: const TextStyle(fontSize: 12),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.link_rounded, size: 18),
                ),
                style: const TextStyle(fontSize: 13),
                onSubmitted: (_) => _saveAndPlay(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 42,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: green, padding: const EdgeInsets.symmetric(horizontal: 14)),
                onPressed: _busy ? null : _saveAndPlay,
                child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.play_arrow_rounded, color: Colors.black),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 42,
              child: OutlinedButton(
                onPressed: _stop,
                child: const Icon(Icons.stop_rounded, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LangRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangRow(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color:
              selected ? green.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? green : null,
                  )),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0.6,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 19,
                color: selected ? green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPicker extends ConsumerStatefulWidget {
  const _AvatarPicker();
  @override
  ConsumerState<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<_AvatarPicker> {
  List<String> _avatars = [];
  @override
  void initState() {
    super.initState();
    _loadAvatars();
  }

  Future<void> _loadAvatars() async {
    try {
      // Flutter 3.22+: AssetManifest.json deprecated, используем rootBundle + AssetManifest
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final avatars = manifest.listAssets().where((k) => k.startsWith('assets/avatar/') && (k.endsWith('.png') || k.endsWith('.jpg') || k.endsWith('.jpeg'))).toList()..sort();
      if (avatars.isNotEmpty) {
        if (mounted) setState(() => _avatars = avatars);
        return;
      }
    } catch (_) {}
    // Fallback: пробуем старый AssetManifest.json
    try {
      final String manifestContent = await rootBundle.loadString('AssetManifest.json');
      final RegExp reg = RegExp(r'"assets\/avatar\/[^"]+\.(png|jpg|jpeg)"');
      final matches = reg.allMatches(manifestContent).map((m) => m.group(0)!.replaceAll('"', '')).toList();
      if (matches.isNotEmpty) {
        if (mounted) setState(() => _avatars = matches);
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _avatars = ['assets/avatar/avatar1.png','assets/avatar/avatar2.png','assets/avatar/avatar3.png','assets/avatar/avatar4.png','assets/avatar/avatar5.png','assets/avatar/avatar6.png']);
  }

  Future<void> _pick(String asset) async {
    try {
      await ApiClient.instance.updateMe(avatarUrl: asset);
      ref.read(userProvider.notifier).setUser(ref.read(userProvider).copyWith(avatarUrl: asset));
      if (mounted) TopNotify.show(context, 'Аватар обновлён ✅', success: true);
    } catch (e) {
      if (mounted) TopNotify.show(context, 'Не удалось сохранить', success: false);
    }
  }

  Future<void> _clear() async {
    try {
      await ApiClient.instance.updateMe(avatarUrl: '');
      ref.read(userProvider.notifier).setUser(ref.read(userProvider).copyWith(avatarUrl: null));
      if (mounted) TopNotify.show(context, 'Аватар сброшен — показывается буква', success: true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BrandCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Text('🖼️', style: TextStyle(fontSize: 18)), const SizedBox(width: 8), const Text('Аватар', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), const Spacer(), TextButton(onPressed: _clear, child: const Text('Буква'))]),
        const SizedBox(height: 10),
        if (_avatars.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('Нет аватарок — добавь файлы в assets/avatar', style: TextStyle(color: Colors.grey, fontSize: 12))))
        else
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final a in _avatars)
              GestureDetector(
                onTap: () => _pick(a),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: user.avatarUrl == a ? (isDark ? AppColors.brandNeon : AppColors.brandGreen) : Colors.white12, width: user.avatarUrl == a ? 2.5 : 1),
                    image: DecorationImage(image: AssetImage(a), fit: BoxFit.cover),
                  ),
                ),
              ),
          ]),
      ]),
    );
  }
}
