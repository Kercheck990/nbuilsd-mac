import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/tfa_screen.dart';
import '../../features/auth/screens/verify_code_screen.dart';
import '../../features/cases/screens/case_detail_screen.dart';
import '../../features/cases/screens/cases_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/leaderboard/leaderboard_screen.dart';
import '../../features/menu/main_menu_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shop/shop_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/support/support_screen.dart';
import '../../features/trade/trade_screen.dart';
import '../../features/upgrader/screens/home_screen.dart';
import '../../features/wallet/profile_wallet_screen.dart';
import '../../features/wallet/topup_screen.dart';

/// Мост между Riverpod и go_router: перестраивает маршруты, когда
/// меняется статус авторизации.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

/// Плавный переход: лёгкий зум + затухание. Используется на всех
/// экранах, чтобы навигация не выглядела резкой.
CustomTransitionPage<T> _fadeThrough<T>({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;

      // Пока восстанавливаем сессию — держим сплэш.
      if (auth.status == AuthStatus.unknown) {
        return loc == '/' ? null : '/';
      }

      const authRoutes = {'/login', '/register', '/verify', '/tfa'};

      switch (auth.status) {
        case AuthStatus.unauthenticated:
          // Пускаем только на /login и /register.
          return (loc == '/login' || loc == '/register') ? null : '/login';
        case AuthStatus.pendingVerification:
          return loc == '/verify' ? null : '/verify';
        case AuthStatus.tfaRequired:
          return loc == '/tfa' ? null : '/tfa';
        case AuthStatus.authenticated:
          return (authRoutes.contains(loc) || loc == '/') ? '/home' : null;
        case AuthStatus.unknown:
          return null;
      }
    },
    routes: [
      GoRoute(path: '/', builder: (c, s) => const SplashScreen()),
      GoRoute(
        path: '/login',
        pageBuilder: (c, s) => _fadeThrough(child: const LoginScreen(), state: s),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (c, s) => _fadeThrough(child: const RegisterScreen(), state: s),
      ),
      GoRoute(
        path: '/verify',
        pageBuilder: (c, s) =>
            _fadeThrough(child: const VerifyCodeScreen(), state: s),
      ),
      GoRoute(
        path: '/tfa',
        pageBuilder: (c, s) => _fadeThrough(child: const TfaScreen(), state: s),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (c, s) => _fadeThrough(child: const MainMenuScreen(), state: s),
      ),
      GoRoute(
        path: '/upgrader',
        pageBuilder: (c, s) => _fadeThrough(child: const HomeScreen(), state: s),
      ),
      GoRoute(
        path: '/shop',
        pageBuilder: (c, s) => _fadeThrough(child: const ShopScreen(), state: s),
      ),
      GoRoute(
        path: '/trade',
        pageBuilder: (c, s) => _fadeThrough(child: const TradeScreen(), state: s),
      ),
      GoRoute(
        path: '/inventory',
        pageBuilder: (c, s) =>
            _fadeThrough(child: const InventoryScreen(), state: s),
      ),
      GoRoute(
        path: '/leaderboard',
        pageBuilder: (c, s) =>
            _fadeThrough(child: const LeaderboardScreen(), state: s),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (c, s) =>
            _fadeThrough(child: const ProfileWalletScreen(), state: s),
      ),
      GoRoute(
        path: '/profile/:nickname',
        pageBuilder: (c, s) => _fadeThrough(
          child: PublicProfileScreen(
              nickname: s.pathParameters['nickname'] ?? ''),
          state: s,
        ),
      ),
      GoRoute(
        path: '/support',
        pageBuilder: (c, s) =>
            _fadeThrough(child: const SupportScreen(), state: s),
      ),
      GoRoute(
        path: '/support/:id',
        pageBuilder: (c, s) => _fadeThrough(
          child:
              TicketDetailScreen(ticketId: s.pathParameters['id'] ?? ''),
          state: s,
        ),
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (c, s) =>
            _fadeThrough(child: const AdminScreen(), state: s),
      ),
      GoRoute(
        path: '/topup',
        pageBuilder: (c, s) => _fadeThrough(child: const TopUpScreen(), state: s),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (c, s) => _fadeThrough(child: const HistoryScreen(), state: s),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (c, s) =>
            _fadeThrough(child: const SettingsScreen(), state: s),
      ),
      GoRoute(
        path: '/cases',
        pageBuilder: (c, s) => _fadeThrough(child: const CasesScreen(), state: s),
      ),
      GoRoute(
        path: '/cases/:id',
        pageBuilder: (c, s) => _fadeThrough(
            child: CaseDetailScreen(caseId: s.pathParameters['id'] ?? ''), state: s),
      ),
    ],
  );
});
