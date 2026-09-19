/// Глобальная конфигурация механики апгрейда.
///
/// LEGAL / COMPLIANCE TODO:
/// Приложение реализует механику «поставить виртуальную ценность → шанс
/// её потерять» (skin/NFT-upgrader). Во многих юрисдикциях и сторах
/// (в частности Apple App Store) такие приложения классифицируются как
/// азартные игры, что требует лицензии, верификации возраста и раскрытия
/// информации, а где-то запрещено полностью. До подключения реальных
/// платёжных рельсов (карты, крипта, Telegram Stars) и публикации в
/// сторах обязательно проконсультируйтесь с юристом по игорному
/// регулированию в каждой целевой стране. Встроенный 18+ гейт и раздел
/// «Ответственная игра» сами по себе не являются достаточным комплаенсом.
class AppConstants {
  AppConstants._();

  static const String appName = 'NFT-GRADER';

  // ---------------------------------------------------------------------
  // ШАНС
  // ---------------------------------------------------------------------
  /// Минимальный шанс, который вообще может быть показан.
  static const double minChancePercent = 1.0;

  /// ЖЁСТКИЙ ПОТОЛОК. Больше 75% апгрейд запрещён — кнопка блокируется,
  /// шкала подсвечивает «запретную зону». Это единственное место, где
  /// значение задаётся; и клиент, и сервер (server/src/config.js)
  /// используют одно и то же число.
  static const double maxChancePercent = 75.0;

  /// Полная шкала гейджа всегда 0..100%, чтобы 50% визуально были ровно
  /// половиной круга, а зона 75..100 читалась как недоступная.
  static const double gaugeScaleMax = 100.0;

  // Быстрые пресеты
  static const List<double> quickMultipliers = [2, 5, 10];
  static const List<double> quickChancePercents = [10, 25, 50, 75];

  // Геометрия гейджа — ПОЛНЫЙ КРУГ 360° для честного отображения шанса.
  // 0% = верх (-90°), рост по часовой. Зелёный сектор = шанс (до 75%),
  // остаток круга = зона проигрыша (тёмная). Стрелка strelka.png вращается
  // вокруг центра и останавливается на rollPercent.
  static const double gaugeStartAngleDeg = -90; // верх (12 часов)
  static const double gaugeSweepAngleDeg = 360;

  // Анимация вращения
  static const Duration spinDuration = Duration(milliseconds: 3000);
  static const int spinFullRotationsMin = 2;
  static const int spinFullRotationsMax = 5;

  // Ответственная игра
  static const double defaultDailyStakeLimitCoins = 5000;

  // ---------------------------------------------------------------------
  // BACKEND
  // ---------------------------------------------------------------------
  /// База API. Продакшн — https://nftgrade.freesrv.com.
  /// Для локальной разработки переопределите:
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080 (Android эмулятор)
  /// или http://localhost:8080 (iOS/desktop).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nftgrade.freesrv.com',
  );

  static const Duration apiTimeout = Duration(seconds: 20);

  // Ключи локального хранилища
  static const String prefThemeMode = 'pref_theme_mode';
  static const String prefLocale = 'pref_locale';
  static const String prefSoundOn = 'pref_sound_on';
  static const String prefMusicOn = 'pref_music_on';
  static const String prefAgeConfirmed = 'pref_age_confirmed';
  static const String prefDailyStakeLimit = 'pref_daily_stake_limit';
  static const String prefClientSeed = 'pref_client_seed';
  static const String prefAuthToken = 'pref_auth_token';

  static const String supportedLocaleRu = 'ru';
  static const String supportedLocaleUk = 'uk';
  static const String supportedLocaleEn = 'en';
}
