import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.prefThemeMode);
    switch (saved) {
      case 'light':
        state = ThemeMode.light;
        break;
      case 'system':
        state = ThemeMode.system;
        break;
      default:
        state = ThemeMode.dark;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefThemeMode, mode.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Sound / music / haptics toggles, persisted the same way.
class SettingsState {
  final bool soundOn;
  final bool musicOn;
  final bool hapticsOn;
  final double dailyStakeLimit;
  final String userMusicUrl; // локальная YouTube ссылка пользователя

  const SettingsState({
    this.soundOn = true,
    this.musicOn = true,
    this.hapticsOn = true,
    this.dailyStakeLimit = AppConstants.defaultDailyStakeLimitCoins,
    this.userMusicUrl = '',
  });

  SettingsState copyWith({
    bool? soundOn,
    bool? musicOn,
    bool? hapticsOn,
    double? dailyStakeLimit,
    String? userMusicUrl,
  }) {
    return SettingsState(
      soundOn: soundOn ?? this.soundOn,
      musicOn: musicOn ?? this.musicOn,
      hapticsOn: hapticsOn ?? this.hapticsOn,
      dailyStakeLimit: dailyStakeLimit ?? this.dailyStakeLimit,
      userMusicUrl: userMusicUrl ?? this.userMusicUrl,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      soundOn: prefs.getBool(AppConstants.prefSoundOn) ?? true,
      musicOn: prefs.getBool(AppConstants.prefMusicOn) ?? true,
      dailyStakeLimit: prefs.getDouble(AppConstants.prefDailyStakeLimit) ??
          AppConstants.defaultDailyStakeLimitCoins,
      userMusicUrl: prefs.getString('pref_user_music_url') ?? '',
    );
  }

  Future<void> setSoundOn(bool value) async {
    state = state.copyWith(soundOn: value);
    (await SharedPreferences.getInstance())
        .setBool(AppConstants.prefSoundOn, value);
  }

  Future<void> setMusicOn(bool value) async {
    state = state.copyWith(musicOn: value);
    (await SharedPreferences.getInstance())
        .setBool(AppConstants.prefMusicOn, value);
  }

  Future<void> setUserMusicUrl(String url) async {
    state = state.copyWith(userMusicUrl: url.trim());
    (await SharedPreferences.getInstance()).setString('pref_user_music_url', url.trim());
  }

  // Язык живёт в отдельном localeProvider (lib/providers/locale_provider.dart),
  // чтобы MaterialApp перестраивался только при смене языка.

  Future<void> setDailyStakeLimit(double value) async {
    state = state.copyWith(dailyStakeLimit: value);
    (await SharedPreferences.getInstance())
        .setDouble(AppConstants.prefDailyStakeLimit, value);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
