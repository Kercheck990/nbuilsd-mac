import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'core/l10n/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/events_overlay.dart';
import 'features/auth/providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/session_provider.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    // Винда — фулл ХД как просили
    WindowOptions opts = const WindowOptions(size: Size(1920, 1080), center: true, title: 'NFT Grade PC Build', minimumSize: Size(1280, 720));
    await windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } else {
    // Мобилки — только альбом (перевёрнутый телефон как на фото 3), оптимизация под горизонтальный геймплей
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    // Иммерсив для большего поля
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(const ProviderScope(child: NftGraderApp()));
}

class FullscreenNotifier extends StateNotifier<bool> {
  FullscreenNotifier() : super(false);
  Future<void> toggle() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final isFull = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFull);
      state = !isFull;
    } else {
      // mobile — immersive
      if (state) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
      state = !state;
    }
  }
}

final fullscreenProvider = StateNotifierProvider<FullscreenNotifier, bool>((ref) => FullscreenNotifier());

class NftGraderApp extends ConsumerWidget {
  const NftGraderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appThemeId = ref.watch(appThemeProvider);
    final themeMode = ref.watch(themeModeProvider);
    // fallback sync: if appTheme is orange/blue, override themeMode dark
    final effectiveMode = appThemeId == AppThemeId.light ? ThemeMode.light : ThemeMode.dark;
    final locale = ref.watch(localeProvider);
    final router = ref.watch(routerProvider);

    // Синк сессии с сервером + heartbeat/ивенты/музыка, пока игрок в сети.
    ref.watch(sessionSyncProvider);
    final authStatus = ref.watch(authProvider.select((a) => a.status));
    ref.listen(authProvider.select((a) => a.status), (_, status) {
      if (status == AuthStatus.authenticated) {
        ref.read(heartbeatRunnerProvider).start(ref);
      } else if (status == AuthStatus.unauthenticated) {
        ref.read(heartbeatRunnerProvider).stop();
      }
    });
    if (authStatus == AuthStatus.authenticated) {
      // Первый запуск таймеров после hot-restart / сборки.
      Future.microtask(() => ref.read(heartbeatRunnerProvider).start(ref));
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f11): () => ref.read(fullscreenProvider.notifier).toggle(),
        const SingleActivator(LogicalKeyboardKey.escape): () async {
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
            try {
              final isFs = await windowManager.isFullScreen();
              if (isFs) ref.read(fullscreenProvider.notifier).toggle();
            } catch (_) {}
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: MaterialApp.router(
      title: 'NFT-GRADER',
      debugShowCheckedModeBanner: false,
      themeMode: effectiveMode,
      theme: switch (appThemeId) {
        AppThemeId.darkOrange => AppTheme.darkOrange,
        AppThemeId.darkBlue => AppTheme.darkBlue,
        _ => AppTheme.light,
      },
      darkTheme: switch (appThemeId) {
        AppThemeId.darkOrange => AppTheme.darkOrange,
        AppThemeId.darkBlue => AppTheme.darkBlue,
        AppThemeId.light => AppTheme.light,
        _ => AppTheme.dark,
      },
      routerConfig: router,
      locale: locale,
      builder: (context, child) => DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none, decorationColor: Colors.transparent),
        child: Stack(
          children: [
            child ?? const SizedBox.shrink(),
            // Таймер до админ абьюза сверху (как на фото)
            const Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: SafeArea(child: Center(child: AdminAbuseCountdown())),
            ),
            // Белый флэш + blessing/x2 во время абьюза
            const Positioned.fill(child: SafeArea(child: AdminAbuseOverlay())),
            // Иконки ивентов слева внизу + баннер рассылок — поверх всех экранов.
            const Positioned(
              left: 12,
              bottom: 12,
              child: SafeArea(child: EventIcons()),
            ),
            const Positioned(
              top: 64,
              left: 16,
              right: 16,
              child: SafeArea(child: BroadcastBanner()),
            ),
          ],
        ),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
  }
}
