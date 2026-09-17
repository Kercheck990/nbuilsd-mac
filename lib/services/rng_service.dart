import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Проверка честности на клиенте: пересчёт ролла раунда по раскрытым
/// сидам (доказательство, что сервер не подменил исход).
class FairnessCheck {
  FairnessCheck._();

  static String sha256Hex(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  /// sha256(serverSeed:clientSeed:nonce) → значение в [0, 100).
  static double rollFromSeeds(
      String serverSeed, String clientSeed, int nonce) {
    final hash = sha256Hex('$serverSeed:$clientSeed:$nonce');
    // Первые 13 hex-символов (52 бита) — более чем достаточно для double.
    final slice = hash.substring(0, 13);
    final intVal = BigInt.parse(slice, radix: 16);
    final maxVal = BigInt.parse('f' * 13, radix: 16);
    return (intVal / maxVal) * 100.0;
  }
}

/// Чистая математика шанса (клиентский предпросмотр), сервер — источник
/// правды и применяет потолок 75% + множители ивентов.
class ChanceCalculator {
  ChanceCalculator._();

  static double compute({
    required double totalStakeValue,
    required double targetValue,
    required double minPercent,
    required double maxPercent,
  }) {
    if (targetValue <= 0) return minPercent;
    final raw = (totalStakeValue / targetValue) * 100.0;
    return raw.clamp(minPercent, maxPercent);
  }
}
