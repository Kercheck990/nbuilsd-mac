import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Thin wrapper around audioplayers. Sound files are expected under
/// assets/sounds/ — add them and uncomment the asset entries in
/// pubspec.yaml. All calls are safe no-ops if the asset is missing.
class SoundService {
  SoundService({this.enabled = true});

  bool enabled;
  final AudioPlayer _player = AudioPlayer();

  Future<void> _play(String assetName) async {
    if (!enabled) return;
    try {
      await _player.play(AssetSource('sounds/$assetName'));
    } catch (_) {
      // Missing asset in dev/demo builds — ignore.
    }
  }

  Future<void> click() => _play('click.mp3');
  Future<void> spinTick() => _play('spin_tick.mp3');
  Future<void> win() => _play('win.mp3');
  Future<void> lose() => _play('lose.mp3');

  void dispose() => _player.dispose();
}

/// Wraps HapticFeedback so it can be toggled/mocked centrally.
class HapticService {
  HapticService({this.enabled = true});

  bool enabled;

  void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  void success() {
    if (enabled) HapticFeedback.selectionClick();
  }
}

/// Abstract wallet integration point (TON / Telegram). Swap the
/// implementation for a real connector later without touching UI code.
abstract class WalletService {
  Future<bool> isConnected();
  Future<String?> connectedAddress();
  Future<String> connect();
  Future<void> disconnect();
}

class MockWalletService implements WalletService {
  String? _address;

  @override
  Future<String?> connectedAddress() async => _address;

  @override
  Future<void> disconnect() async => _address = null;

  @override
  Future<bool> isConnected() async => _address != null;

  @override
  Future<String> connect() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _address = 'UQ' 'Demo1234WalletAddressPlaceholder';
    return _address!;
  }
}
