import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../data/models/nft_item.dart';

/// Ошибка API с кодом, который можно сопоставить со строкой локализации.
class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  ApiException(this.code, this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException($code): $message';
}

/// Итог входа: либо токен уже сохранён, либо нужен 2FA-код.
class LoginResult {
  final bool tfaRequired;
  final String? email;

  const LoginResult._(this.tfaRequired, this.email);

  factory LoginResult.ok() => const LoginResult._(false, null);

  factory LoginResult.tfa({required String email}) => LoginResult._(true, email);
}

/// Тонкая обёртка над Dio: базовый URL, JWT в заголовке, единый разбор
/// ошибок. Все сетевые вызовы приложения идут через этот класс.
class ApiClient {
  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.apiTimeout,
      receiveTimeout: AppConstants.apiTimeout,
      headers: {'Content-Type': 'application/json'},
      validateStatus: (s) => s != null && s < 500,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
    ));
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  String? _token;

  String? get token => _token;
  bool get isAuthenticated => _token != null;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.prefAuthToken);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(AppConstants.prefAuthToken);
    } else {
      await prefs.setString(AppConstants.prefAuthToken, token);
    }
  }

  // -------------------------------------------------------------------
  // Низкоуровневые помощники
  // -------------------------------------------------------------------
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
      final data = res.data;
      if (res.statusCode! >= 400) {
        final code = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'error_generic';
        final msg = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Request failed';
        throw ApiException(code, msg, res.statusCode);
      }
      if (data is Map<String, dynamic>) return data;
      return {'data': data};
    } on DioException catch (e) {
      throw ApiException('error_network', e.message ?? 'Network error');
    }
  }

  // -------------------------------------------------------------------
  // Авторизация
  // -------------------------------------------------------------------

  /// Регистрация. Сервер создаёт пользователя в статусе «не подтверждён»
  /// и отправляет 6-значный код на почту. Токен выдаётся только после
  /// подтверждения кода.
  Future<void> register({
    required String email,
    required String password,
    required String nickname,
    required String locale,
  }) async {
    await _request('POST', '/api/auth/register', body: {
      'email': email.trim().toLowerCase(),
      'password': password,
      'nickname': nickname.trim(),
      'locale': locale,
    });
  }

  /// Подтверждение кода из письма. Возвращает JWT.
  Future<String> verifyEmail({required String email, required String code}) async {
    final res = await _request('POST', '/api/auth/verify', body: {
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
    });
    final token = res['token'] as String;
    await setToken(token);
    return token;
  }

  Future<void> resendCode({required String email, required String locale}) async {
    await _request('POST', '/api/auth/resend', body: {
      'email': email.trim().toLowerCase(),
      'locale': locale,
    });
  }

  /// Вход. Если почта ещё не подтверждена, сервер вернёт ошибку
  /// `email_not_verified` и повторно отправит код.
  /// Если включён 2FA — вернётся [LoginResult.tfaRequired] без токена.
  Future<LoginResult> login({required String email, required String password}) async {
    final res = await _request('POST', '/api/auth/login', body: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    if (res['tfa_required'] == true) {
      return LoginResult.tfa(email: res['email'] as String? ?? email.trim().toLowerCase());
    }
    final token = res['token'] as String;
    await setToken(token);
    return LoginResult.ok();
  }

  Future<void> logout() => setToken(null);

  Future<Map<String, dynamic>> me() async {
    final res = await _request('GET', '/api/me');
    return res['user'] as Map<String, dynamic>;
  }

  // -------------------------------------------------------------------
  // Предметы
  // -------------------------------------------------------------------
  Future<List<NftItem>> catalog() async {
    final res = await _request('GET', '/api/items');
    return (res['items'] as List)
        .map((e) => NftItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<NftItem>> inventory() async {
    final res = await _request('GET', '/api/inventory');
    return (res['items'] as List)
        .map((e) => NftItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Продажа предмета из инвентаря. Возвращает новый баланс.
  Future<int> sellItem(String inventoryId) async {
    final res = await _request('POST', '/api/inventory/$inventoryId/sell');
    return res['balance_coins'] as int;
  }

  Future<Map<String, dynamic>> starItem(String inventoryId, bool starred) =>
      _request('POST', '/api/inventory/$inventoryId/star', body: {'starred': starred});

  Future<Map<String, dynamic>> sellAll() => _request('POST', '/api/inventory/sell-all');

  /// История раундов игрока (сервер, последние 50).
  Future<Map<String, dynamic>> history() => _request('GET', '/api/history');

  // -------------------------------------------------------------------
  // Апгрейд (серверное разрешение раунда)
  // -------------------------------------------------------------------

  /// Просит сервер провести раунд. Сервер сам считает шанс, проверяет
  /// потолок 75% и владение предметами — клиент не может это подделать.
  Future<Map<String, dynamic>> runUpgrade({
    required List<String> stakeInventoryIds,
    required int stakeCoins,
    required String targetItemId,
  }) async {
    return _request('POST', '/api/upgrade', body: {
      'stake_inventory_ids': stakeInventoryIds,
      'stake_coins': stakeCoins,
      'target_item_id': targetItemId,
    });
  }

  // -------------------------------------------------------------------
  // Топы
  // -------------------------------------------------------------------

  /// [metric]: balance | inventory | hours | wins | profit.
  Future<Map<String, dynamic>> leaderboard({
    required String metric,
    required String period,
    int limit = 35,
  }) {
    return _request('GET', '/api/leaderboard',
        query: {'metric': metric, 'period': period, 'limit': limit});
  }

  // -------------------------------------------------------------------
  // Платежи
  // -------------------------------------------------------------------

  /// Создаёт счёт у провайдера и возвращает {payment_id, pay_url}.
  /// Монеты начисляются ТОЛЬКО после вебхука от провайдера.
  Future<Map<String, dynamic>> createPayment({
    required int amountCoins,
    required String provider, // stripe | crypto | stars
  }) async {
    return _request('POST', '/api/payments/create', body: {
      'amount_coins': amountCoins,
      'provider': provider,
    });
  }

  /// Статус платежа: pending | paid | failed | expired.
  Future<Map<String, dynamic>> paymentStatus(String paymentId) async {
    return _request('GET', '/api/payments/$paymentId');
  }

  // -------------------------------------------------------------------
  // 2FA
  // -------------------------------------------------------------------

  /// Второй шаг входа: обмен 2FA-кода из письма на JWT.
  Future<String> tfaVerify({required String email, required String code}) async {
    final res = await _request('POST', '/api/auth/tfa/verify', body: {
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
    });
    final token = res['token'] as String;
    await setToken(token);
    return token;
  }

  /// Начать включение 2FA: сервер шлёт код на почту.
  Future<void> tfaEnable() => _request('POST', '/api/auth/tfa/enable');

  /// Подтвердить включение 2FA кодом.
  Future<void> tfaConfirm({required String code}) =>
      _request('POST', '/api/auth/tfa/confirm', body: {'code': code.trim()});

  /// Выключить 2FA.
  Future<void> tfaDisable() => _request('POST', '/api/auth/tfa/disable');

  // -------------------------------------------------------------------
  // Telegram
  // -------------------------------------------------------------------

  /// Код для привязки: игрок отправляет его боту.
  Future<Map<String, dynamic>> telegramCode() =>
      _request('POST', '/api/auth/telegram/code');

  /// Отвязать Telegram.
  Future<void> telegramUnlink() => _request('POST', '/api/auth/telegram/unlink');

  // -------------------------------------------------------------------
  // Профиль / heartbeat / события / настройки
  // -------------------------------------------------------------------

  /// Пинг раз в минуту: сервер копит наигранные часы.
  Future<Map<String, dynamic>> heartbeat() => _request('POST', '/api/heartbeat');

  /// Объявления от администрации (последние).
  Future<Map<String, dynamic>> broadcasts({int limit = 10}) =>
      _request('GET', '/api/broadcasts', query: {'limit': limit});

  /// Публичные настройки: музыка, саппорт, бот.
  Future<Map<String, dynamic>> publicSettings() => _request('GET', '/api/settings');

  /// Активные ивенты (x2/x4/Сейвы).
  Future<Map<String, dynamic>> events() => _request('GET', '/api/events');

  /// Смена ника/языка.
  Future<Map<String, dynamic>> updateMe({String? nickname, String? locale}) {
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (locale != null) body['locale'] = locale;
    return _request('PUT', '/api/me', body: body);
  }

  /// Публичный профиль игрока: статусы, статистика, витрина гифтов.
  Future<Map<String, dynamic>> publicProfile(String nickname) =>
      _request('GET', '/api/users/${Uri.encodeComponent(nickname)}');

  /// Поиск игроков по нику.
  Future<Map<String, dynamic>> searchUsers(String q) =>
      _request('GET', '/api/users/search', query: {'q': q});

  // -------------------------------------------------------------------
  // Магазин
  // -------------------------------------------------------------------

  /// Покупка гифта за монеты. Возвращает новый баланс.
  Future<Map<String, dynamic>> buyItem(String itemId) =>
      _request('POST', '/api/items/buy', body: {'item_id': itemId});

  // -------------------------------------------------------------------
  // Апгрейд (серверный раунд — источник правды)
  // -------------------------------------------------------------------

  Future<Map<String, dynamic>> upgrade({
    required List<String> stakeInventoryIds,
    required int stakeCoins,
    required String targetItemId,
  }) {
    return runUpgrade(
      stakeInventoryIds: stakeInventoryIds,
      stakeCoins: stakeCoins,
      targetItemId: targetItemId,
    );
  }

  // -------------------------------------------------------------------
  // Трейды
  // -------------------------------------------------------------------

  Future<Map<String, dynamic>> tradePlayers(String q) =>
      _request('GET', '/api/trades/players', query: {'q': q});

  Future<Map<String, dynamic>> tradeShowcase(String nickname) =>
      _request('GET', '/api/trades/showcase/${Uri.encodeComponent(nickname)}');

  Future<Map<String, dynamic>> createTrade({
    required String toNickname,
    required List<String> offerIds,
    required List<String> askIds,
  }) =>
      _request('POST', '/api/trades', body: {
        'to_nickname': toNickname,
        'offer_ids': offerIds,
        'ask_ids': askIds,
      });

  Future<Map<String, dynamic>> trades() => _request('GET', '/api/trades');

  Future<void> acceptTrade(String id) => _request('POST', '/api/trades/$id/accept');

  Future<void> declineTrade(String id) => _request('POST', '/api/trades/$id/decline');

  Future<void> cancelTrade(String id) => _request('POST', '/api/trades/$id/cancel');

  // -------------------------------------------------------------------
  // Тикеты поддержки
  // -------------------------------------------------------------------

  Future<Map<String, dynamic>> tickets() => _request('GET', '/api/tickets');

  Future<Map<String, dynamic>> createTicket({required String subject, required String text}) =>
      _request('POST', '/api/tickets', body: {'subject': subject, 'text': text});

  Future<Map<String, dynamic>> ticket(String id) => _request('GET', '/api/tickets/$id');

  Future<void> sendTicketMessage(String id, String text) =>
      _request('POST', '/api/tickets/$id/messages', body: {'text': text});

  Future<void> closeTicket(String id) => _request('POST', '/api/tickets/$id/close');

  Future<Map<String, dynamic>> adminTickets(String status) =>
      _request('GET', '/api/tickets/admin/all', query: status.isEmpty ? null : {'status': status});

  // -------------------------------------------------------------------
  // Промокоды
  // -------------------------------------------------------------------

  Future<Map<String, dynamic>> redeemPromocode(String code) =>
      _request('POST', '/api/promocodes/redeem', body: {'code': code});

  Future<Map<String, dynamic>> adminPromocodes() =>
      _request('GET', '/api/promocodes/admin');

  Future<Map<String, dynamic>> createPromocode({
    required String code,
    required int coins,
    int? maxUses,
    bool isActive = true,
    String? expiresAt,
  }) =>
      _request('POST', '/api/promocodes/admin', body: {
        'code': code,
        'coins': coins,
        if (maxUses != null) 'max_uses': maxUses,
        'is_active': isActive,
        if (expiresAt != null) 'expires_at': expiresAt,
      });

  // -------------------------------------------------------------------
  // Кейсы
  // -------------------------------------------------------------------

  Future<Map<String, dynamic>> cases() => _request('GET', '/api/cases');

  Future<Map<String, dynamic>> caseDetail(String caseId) =>
      _request('GET', '/api/cases/${Uri.encodeComponent(caseId)}');

  Future<Map<String, dynamic>> openCase(String caseId, {int count = 1}) =>
      _request('POST', '/api/cases/${Uri.encodeComponent(caseId)}/open', body: {'count': count});

  // -------------------------------------------------------------------
  // Админка
  // -------------------------------------------------------------------

  Future<Map<String, dynamic>> adminUsers(String search) =>
      _request('GET', '/api/admin/users', query: {'search': search});

  Future<Map<String, dynamic>> adminGrant({
    required String nickname,
    int coins = 0,
    String? itemId,
  }) =>
      _request('POST', '/api/admin/grant', body: {
        'nickname': nickname,
        'coins': coins,
        if (itemId != null && itemId.isNotEmpty) 'item_id': itemId,
      });

  Future<Map<String, dynamic>> adminBadges({
    required String nickname,
    required List<String> badges,
  }) =>
      _request('POST', '/api/admin/badges', body: {
        'nickname': nickname,
        'badges': badges,
      });

  Future<Map<String, dynamic>> adminBan({required String nickname, required bool banned}) =>
      _request('POST', '/api/admin/ban', body: {'nickname': nickname, 'banned': banned});

  Future<Map<String, dynamic>> adminSettings() => _request('GET', '/api/admin/settings');

  Future<Map<String, dynamic>> setAdminSetting(String key, String value) =>
      _request('POST', '/api/admin/settings', body: {'key': key, 'value': value});

  Future<Map<String, dynamic>> broadcast(String text) =>
      _request('POST', '/api/admin/broadcast', body: {'text': text});
}
