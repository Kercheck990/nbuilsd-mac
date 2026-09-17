import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../data/models/user_model.dart';
import '../data/repositories/inventory_repository.dart';
import '../features/auth/providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/app_services.dart';
import 'balance_provider.dart';
import 'theme_provider.dart';

// =====================================================================
// Синхронизация сессии: после входа подтягиваем профиль, инвентарь,
// каталог, ивенты и настройки. Всё — с сервера, без моков.
// =====================================================================

final sessionSyncProvider = FutureProvider<void>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.status != AuthStatus.authenticated) return;
  final api = ApiClient.instance;
  try {
    final me = await api.me();
    ref.read(userProvider.notifier).setUser(AppUser.fromServer(me['user']));
  } catch (_) {}
  await ref.read(inventoryProvider.notifier).refresh();
  await ref.read(catalogProvider.notifier).refresh();
  await ref.read(eventsProvider.notifier).refresh();
  await ref.read(appSettingsProvider.notifier).refresh();
  await ref.read(broadcastsProvider.notifier).refresh();
});

// =====================================================================
// Звук
// =====================================================================

final soundServiceProvider = Provider<SoundService>((ref) {
  final s = SoundService();
  ref.onDispose(s.dispose);
  return s;
});

/// Проигрывает звук с учётом тумблера «Звук» в настройках.
Future<void> playSound(WidgetRef ref, Future<void> Function() play) async {
  final on = ref.read(settingsProvider).soundOn;
  ref.read(soundServiceProvider).enabled = on;
  if (on) {
    try {
      await play();
    } catch (_) {}
  }
}

// =====================================================================
// Ивенты (x2/x4/Сейвы)
// =====================================================================

class GameEvent {
  final String key; // x2 | x4 | saves
  final bool active;
  final DateTime? endsAt;

  const GameEvent({required this.key, required this.active, this.endsAt});

  factory GameEvent.fromJson(Map<String, dynamic> j) => GameEvent(
        key: j['key'].toString(),
        active: j['active'] as bool? ?? false,
        endsAt: j['ends_at'] != null ? DateTime.tryParse(j['ends_at'].toString()) : null,
      );
}

class EventsState {
  final List<GameEvent> events;
  final bool weekend;
  final DateTime? nextWindowAt;

  const EventsState({this.events = const [], this.weekend = false, this.nextWindowAt});

  bool get x2 => _on('x2');
  bool get x4 => _on('x4');
  bool get saves => _on('saves');

  bool _on(String key) => events.any((e) => e.key == key && e.active);

  int get luckMultiplier {
    if (x4) return 4;
    if (x2) return 2;
    return 1;
  }

  DateTime? get endsAt {
    for (final e in events) {
      if (e.active && e.endsAt != null) return e.endsAt;
    }
    return null;
  }
}

class EventsNotifier extends StateNotifier<EventsState> {
  EventsNotifier() : super(const EventsState());

  Future<void> refresh() async {
    try {
      final res = await ApiClient.instance.events();
      final list = ((res['events'] as List?) ?? const [])
          .map((e) => GameEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      state = EventsState(
        events: list,
        weekend: res['weekend'] as bool? ?? false,
        nextWindowAt: res['next_window_at'] != null
            ? DateTime.tryParse(res['next_window_at'].toString())
            : null,
      );
    } catch (_) {}
  }
}

final eventsProvider = StateNotifierProvider<EventsNotifier, EventsState>((ref) {
  return EventsNotifier();
});

// =====================================================================
// Публичные настройки (музыка, саппорт, бот)
// =====================================================================

class AppSettingsNotifier extends StateNotifier<Map<String, String>> {
  AppSettingsNotifier() : super(const {});

  Future<void> refresh() async {
    try {
      final res = await ApiClient.instance.publicSettings();
      final map = ((res['settings'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), v.toString()));
      state = map;
    } catch (_) {}
  }

  String get musicUrl => state['music_url'] ?? '';
  bool get musicOn => state['music_on'] == 'on';
  String get supportTg => state['support_tg'] ?? 'https://t.me/nftgrader_support';
  String get tgBot => state['tg_bot'] ?? '';
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, Map<String, String>>((ref) {
  return AppSettingsNotifier();
});

// =====================================================================
// Музыка от админа + YouTube (стрим по URL / YouTube ссылке)
// =====================================================================

String? _extractYoutubeId(String url) {
  final reg = RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/|music\.youtube\.com\/watch\?v=)([^&\n?#]+)');
  final m = reg.firstMatch(url);
  if (m != null) return m.group(1);
  // также пробуем параметр v=
  final uri = Uri.tryParse(url);
  if (uri != null && uri.queryParameters.containsKey('v')) return uri.queryParameters['v'];
  return null;
}

Future<String> _resolveAudioUrl(String raw) async {
  final vid = _extractYoutubeId(raw);
  if (vid == null) return raw;
  // YouTube — вытаскиваем прямой аудио-поток через youtube_explode
  final yt = YoutubeExplode();
  try {
    final manifest = await yt.videos.streamsClient.getManifest(vid);
    // пробуем аудио-only с наивысшим битрейтом, иначе muxed
    final audio = manifest.audioOnly;
    if (audio.isNotEmpty) {
      audio.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      return audio.first.url.toString();
    }
    final muxed = manifest.muxed;
    if (muxed.isNotEmpty) {
      muxed.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      return muxed.first.url.toString();
    }
  } catch (_) {
  } finally {
    yt.close();
  }
  return raw;
}

class MusicController extends StateNotifier<bool> {
  MusicController() : super(false);

  final AudioPlayer _player = AudioPlayer();
  String _rawUrl = '';
  String _resolvedUrl = '';

  /// Воспроизведение YouTube / mp3 ссылки напрямую (для локального теста из настроек)
  Future<bool> playCustom(String rawUrl) async {
    if (rawUrl.trim().isEmpty) {
      await _player.stop();
      state = false;
      _rawUrl = '';
      _resolvedUrl = '';
      return false;
    }
    try {
      final resolved = await _resolveAudioUrl(rawUrl.trim());
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(UrlSource(resolved));
      _rawUrl = rawUrl.trim();
      _resolvedUrl = resolved;
      state = true;
      return true;
    } catch (_) {
      state = false;
      return false;
    }
  }

  Future<void> stopCustom() async {
    await _player.stop();
    state = false;
    _rawUrl = '';
    _resolvedUrl = '';
  }

  Future<void> sync({required String url, required bool serverOn, required bool userOn, String? userUrl}) async {
    // Приоритет: локальная YouTube-ссылка пользователя, если она задана и музыка включена
    String effective = '';
    bool want = false;
    final local = userUrl?.trim() ?? '';
    if (local.isNotEmpty && userOn) {
      effective = local;
      want = true;
    } else {
      want = serverOn && userOn && url.isNotEmpty;
      effective = url;
    }
    if (!want || effective.isEmpty) {
      if (state) {
        await _player.stop();
        state = false;
      }
      _rawUrl = '';
      _resolvedUrl = '';
      return;
    }
    if (state && _rawUrl == effective) return;
    _rawUrl = effective;
    try {
      final resolved = await _resolveAudioUrl(effective);
      _resolvedUrl = resolved;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(UrlSource(resolved));
      state = true;
    } catch (_) {
      state = false;
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

final musicControllerProvider =
    StateNotifierProvider<MusicController, bool>((ref) => MusicController());

// =====================================================================
// Рассылки от администрации
// =====================================================================

class Broadcast {
  final int id;
  final String adminNickname;
  final String text;
  final DateTime createdAt;

  const Broadcast({
    required this.id,
    required this.adminNickname,
    required this.text,
    required this.createdAt,
  });

  factory Broadcast.fromJson(Map<String, dynamic> j) => Broadcast(
        id: (j['id'] as num).toInt(),
        adminNickname: j['admin_nickname'] as String? ?? 'Admin',
        text: j['text'] as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now(),
      );
}

class BroadcastsNotifier extends StateNotifier<List<Broadcast>> {
  BroadcastsNotifier() : super(const []);

  static const _seenKey = 'broadcast_seen_id';

  Future<void> refresh() async {
    try {
      final res = await ApiClient.instance.broadcasts(limit: 10);
      state = ((res['broadcasts'] as List?) ?? const [])
          .map((e) => Broadcast.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<int> seenId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_seenKey) ?? 0;
  }

  Future<void> markSeen(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seenKey, id);
  }
}

final broadcastsProvider =
    StateNotifierProvider<BroadcastsNotifier, List<Broadcast>>((ref) {
  return BroadcastsNotifier();
});

// =====================================================================
// HeartbeatScope: таймеры heartbeat/ивентов/музыки, пока игрок в сети.
// Монтируется один раз в MaterialApp.builder.
// =====================================================================

class HeartbeatRunner {
  Timer? _hb;
  Timer? _ev;

  bool get running => _hb != null;

  void start(WidgetRef ref) {
    if (running) return;
    _tick(ref); // сразу
    _hb = Timer.periodic(const Duration(seconds: 60), (_) => _tick(ref));
    _ev = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(eventsProvider.notifier).refresh();
    });
  }

  Future<void> _tick(WidgetRef ref) async {
    try {
      final res = await ApiClient.instance.heartbeat();
      final secs = (res['playtime_seconds'] as num?)?.toInt();
      if (secs != null) {
        final u = ref.read(userProvider);
        ref.read(userProvider.notifier).setUser(u.copyWith(playtimeSeconds: secs));
      }
    } catch (_) {}
    await ref.read(eventsProvider.notifier).refresh();
    final s = ref.read(appSettingsProvider.notifier);
    await s.refresh();
    final userSettings = ref.read(settingsProvider);
    await ref.read(musicControllerProvider.notifier).sync(
          url: s.musicUrl,
          serverOn: s.musicOn,
          userOn: userSettings.musicOn,
          userUrl: userSettings.userMusicUrl,
        );
  }

  void stop() {
    _hb?.cancel();
    _ev?.cancel();
    _hb = null;
    _ev = null;
  }
}

final heartbeatRunnerProvider = Provider<HeartbeatRunner>((ref) => HeartbeatRunner());
