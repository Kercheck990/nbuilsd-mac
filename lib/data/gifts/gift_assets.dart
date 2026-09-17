/// Реестр картинок подарков.
///
/// КАК ДОБАВИТЬ СВОЙ ПОДАРОК
/// 1. Положите картинку в `assets/gifts/` (png или webp, квадрат 512×512,
///    прозрачный фон). Имя файла = id предмета, например `nft_016.png`.
/// 2. Добавьте одну строку в [_registry] ниже: `'nft_016': 'nft_016.png'`.
/// 3. Больше ничего делать не нужно — `pubspec.yaml` уже подключает всю
///    папку целиком, а карточка сама подхватит картинку по id.
///
/// Если файла нет — UI молча покажет 🎁-заглушку, приложение не падает.
class GiftAssets {
  GiftAssets._();

  /// Папка с картинками подарков.
  static const String dir = 'assets/gifts/';

  /// id предмета → имя файла внутри [dir].
  /// Все 11 файлов из assets/gifts + 15 nft_xxx мапятся на существующие png
  /// чтобы не показывать заглушку 🎁 если файл отсутствует.
  static const Map<String, String> _registry = {
    // Реальные файлы из assets/gifts/
    'present': 'present.png',
    'cup': 'cup.png',
    'cake': 'cake.png',
    'flowers': 'flowers.png',
    'heart': 'heart.png',
    'rose': 'rose.png',
    'ring': 'ring.png',
    'rocket': 'rocket.png',
    'bull_run': 'bull_run.png',
    'diamond': 'diamond.png',
    'bear': 'bear.png',
    // nft_001..015 — пока нет отдельных png, мапим на существующие
    'nft_001': 'present.png',
    'nft_002': 'cup.png',
    'nft_003': 'cake.png',
    'nft_004': 'flowers.png',
    'nft_005': 'ring.png',
    'nft_006': 'rocket.png',
    'nft_007': 'rose.png',
    'nft_008': 'diamond.png',
    'nft_009': 'bear.png',
    'nft_010': 'bull_run.png',
    'nft_011': 'heart.png',
    'nft_012': 'cup.png',
    'nft_013': 'heart.png',
    'nft_014': 'bull_run.png',
    'nft_015': 'diamond.png',
  };

  /// Полный путь к ассету для предмета или null.
  static String? pathFor(String itemId) {
    final file = _registry[itemId];
    return file == null ? null : '$dir$file';
  }

  /// Удобно, если вы называете файлы строго по id и не хотите вести
  /// реестр вручную: `GiftAssets.byConvention('nft_016')`.
  /// Внимание: путь вернётся всегда, даже если файла нет — карточка
  /// обработает ошибку загрузки и покажет заглушку.
  static String byConvention(String itemId, {String ext = 'png'}) =>
      '$dir$itemId.$ext';

  static bool has(String itemId) => _registry.containsKey(itemId);
}
