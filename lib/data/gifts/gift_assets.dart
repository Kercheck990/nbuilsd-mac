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
  /// 52 уникальных картинки (1 NFT = 1 картинка), дубликаты удалены.
  static const Map<String, String> _registry = {
    // Базовые 11
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
    // Classic 19 — старые
    'classic_candy_cane': 'classic_candy_cane.png',
    'classic_clover_pin': 'classic_clover_pin.png',
    'classic_faith_amulet': 'classic_faith_amulet.png',
    'classic_franch_socks': 'classic_franch_socks.png',
    'classic_happy_brownie': 'classic_happy_brownie.png',
    'classic_icecream': 'classic_icecream.png',
    'classic_liberty_figure': 'classic_liberty_figure.png',
    'classic_loolpop': 'classic_loolpop.png',
    'classic_lunar_snake': 'classic_lunar_snake.png',
    'classic_mood_bag': 'classic_mood_bag.png',
    'classic_mousse_cake': 'classic_mousse_cake.png',
    'classic_pool_float': 'classic_pool_float.png',
    'classic_ramen': 'classic_ramen.png',
    'classic_snakebox': 'classic_snakebox.png',
    'classic_snoop_doge': 'classic_snoop_doge.png',
    'classic_swag_bag': 'classic_swag_bag.png',
    'classic_vicecream': 'classic_vicecream.png',
    'classic_whip_cupcake': 'classic_whip_cupcake.png',
    'classic_xmax': 'classic_xmax.png',
    // Новые 22 — добавлены, 1 к 1
    'classic_cooke_heart': 'classic_cooke_heart.png',
    'classic_fine_pen': 'classic_fine_pen.png',
    'classic_ginger_cooke': 'classic_ginger_cooke.png',
    'classic_happy_b_day': 'classic_happy_b_day.png',
    'classic_homemade_cake': 'classic_homemade_cake.png',
    'classic_kissed_frog': 'classic_kissed_frog.png',
    'classic_light_sword': 'classic_light_sword.png',
    'classic_party_spalker': 'classic_party_spalker.png',
    'classic_pet_snake': 'classic_pet_snake.png',
    'classic_pretty_posy': 'classic_pretty_posy.png',
    'classic_snoop_sigar': 'classic_snoop_sigar.png',
    'classic_stellar_rocket': 'classic_stellar_rocket.png',
    'classic_timeless_book': 'classic_timeless_book.png',
    'classic_victory_medal': 'classic_victory_medal.png',
    'classic_whitc_hat': 'classic_whitc_hat.png',
    'durov_cap': 'durov_cap.png',
    'input_key': 'input_key.png',
    'jacter_hat': 'jacter_hat.png',
    'mini_oscar': 'mini_oscar.png',
    'pepe': 'pepe.png',
    'precious_pearch': 'precious_pearch.png',
    'scare_cat': 'scare_cat.png',
    // Совместимость: старые nft_001..015 которые были дубликатами — оставляем для отображения старых инвентарей, но в каталоге они скрыты (is_active=FALSE)
    'nft_001': 'classic_candy_cane.png',
    'nft_002': 'classic_clover_pin.png',
    'nft_003': 'classic_faith_amulet.png',
    'nft_004': 'classic_franch_socks.png',
    'nft_005': 'classic_happy_brownie.png',
    'nft_006': 'classic_icecream.png',
    'nft_007': 'classic_liberty_figure.png',
    'nft_008': 'classic_lunar_snake.png',
    'nft_009': 'classic_mood_bag.png',
    'nft_010': 'classic_mousse_cake.png',
    'nft_011': 'classic_pool_float.png',
    'nft_012': 'classic_ramen.png',
    'nft_013': 'classic_snakebox.png',
    'nft_014': 'classic_snoop_doge.png',
    'nft_015': 'classic_swag_bag.png',
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
