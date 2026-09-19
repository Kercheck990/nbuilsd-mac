import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user_model.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../providers/balance_provider.dart';
import '../../../services/api_client.dart';

enum AuthStatus {
  /// Ещё не знаем — идёт восстановление сессии из хранилища.
  unknown,
  unauthenticated,

  /// Аккаунт создан, но код из письма ещё не введён.
  pendingVerification,

  /// Пароль верный, ждём 2FA-код из письма.
  tfaRequired,
  authenticated,
  banned,
}

class AuthState {
  final AuthStatus status;
  final String? pendingEmail;
  final bool busy;
  final String? errorCode;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.pendingEmail,
    this.busy = false,
    this.errorCode,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? pendingEmail,
    bool? busy,
    String? errorCode,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      busy: busy ?? this.busy,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    restore();
  }

  final Ref _ref;
  final ApiClient _api = ApiClient.instance;

  /// Пытается восстановить сессию по сохранённому токену.
  Future<void> restore() async {
    await _api.loadToken();
    if (!_api.isAuthenticated) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _api.me();
      _applyUser(user);
      final u = _ref.read(userProvider);
      if (u.isBanned) {
        state = state.copyWith(status: AuthStatus.banned);
        return;
      }
      state = state.copyWith(status: AuthStatus.authenticated);
    } on ApiException catch (e) {
      if (e.code == 'banned') {
        state = state.copyWith(status: AuthStatus.banned);
        return;
      }
      await _api.logout();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } catch (_) {
      await _api.logout();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  void _applyUser(Map<String, dynamic> json) {
    _ref.read(userProvider.notifier).setUser(AppUser.fromServer(json));
  }

  Future<bool> register({
    required String email,
    required String password,
    required String nickname,
    required String locale,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _api.register(
        email: email,
        password: password,
        nickname: nickname,
        locale: locale,
      );
      state = state.copyWith(
        busy: false,
        status: AuthStatus.pendingVerification,
        pendingEmail: email.trim().toLowerCase(),
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, errorCode: _mapError(e.code));
      return false;
    }
  }

  Future<bool> verify({required String code}) async {
    final email = state.pendingEmail;
    if (email == null) return false;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _api.verifyEmail(email: email, code: code);
      final user = await _api.me();
      _applyUser(user);
      state = state.copyWith(busy: false, status: AuthStatus.authenticated);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, errorCode: _mapError(e.code));
      return false;
    }
  }

  Future<bool> resend({required String locale}) async {
    final email = state.pendingEmail;
    if (email == null) return false;
    try {
      await _api.resendCode(email: email, locale: locale);
      return true;
    } on ApiException {
      return false;
    }
  }

  /// Возвращает true, если сервер запросил 2FA-код (статус tfaRequired —
  /// роутер сам уведёт на экран кода), иначе false.
  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await _api.login(email: email, password: password);
      if (result.tfaRequired) {
        state = state.copyWith(
          busy: false,
          status: AuthStatus.tfaRequired,
          pendingEmail: email.trim().toLowerCase(),
        );
        return true;
      }
      final user = await _api.me();
      _applyUser(user);
      state = state.copyWith(busy: false, status: AuthStatus.authenticated);
      return true;
    } on ApiException catch (e) {
      // Аккаунт есть, но почта не подтверждена: сервер уже выслал новый
      // код — ведём пользователя на экран ввода кода.
      if (e.code == 'email_not_verified') {
        state = state.copyWith(
          busy: false,
          status: AuthStatus.pendingVerification,
          pendingEmail: email.trim().toLowerCase(),
        );
        return true;
      }
      state = state.copyWith(busy: false, errorCode: _mapError(e.code));
      return false;
    }
  }

  /// Второй шаг входа: 2FA-код из письма.
  Future<bool> verifyTfa({required String email, required String code}) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _api.tfaVerify(email: email, code: code);
      final user = await _api.me();
      _applyUser(user);
      state = state.copyWith(busy: false, status: AuthStatus.authenticated);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, errorCode: _mapError(e.code));
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _ref.read(userProvider.notifier).reset();
    _ref.read(inventoryProvider.notifier).clear();
    _ref.read(catalogProvider.notifier).clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void backToLogin() {
    state = state.copyWith(status: AuthStatus.unauthenticated, clearError: true);
  }

  void clearError() => state = state.copyWith(clearError: true);

  /// Код ошибки сервера → ключ локализации.
  String _mapError(String code) {
    switch (code) {
      case 'email_taken':
        return 'auth_err_email_taken';
      case 'invalid_credentials':
        return 'auth_err_credentials';
      case 'invalid_code':
      case 'code_expired':
        return 'verify_err_code';
      case 'invalid_email':
        return 'auth_err_email';
      case 'weak_password':
        return 'auth_err_password';
      case 'banned':
        return 'banned';
      case 'error_network':
        return 'error_network';
      default:
        return 'error_generic';
    }
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));
