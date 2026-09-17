import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

/// Текущий язык приложения. Если пользователь ещё ничего не выбирал —
/// берём язык системы, а если он не поддерживается, падаем на русский.
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('ru')) {
    _load();
  }

  static const _supported = {
    AppConstants.supportedLocaleRu,
    AppConstants.supportedLocaleUk,
    AppConstants.supportedLocaleEn,
  };

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.prefLocale);
    if (saved != null && _supported.contains(saved)) {
      state = Locale(saved);
      return;
    }
    final system = PlatformDispatcher.instance.locale.languageCode;
    state = Locale(_supported.contains(system) ? system : AppConstants.supportedLocaleRu);
  }

  Future<void> setLocale(String code) async {
    if (!_supported.contains(code)) return;
    state = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefLocale, code);
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) => LocaleNotifier());
