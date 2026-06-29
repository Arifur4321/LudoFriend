import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';

/// The set of in-game sound effects. Files live in `assets/sfx/` and are
/// intentionally short, royalty-free placeholders that can be swapped for final
/// audio without code changes.
enum Sfx { dice, move, capture, win, button }

/// Plays short sound effects, gated by the user's sound preference. All
/// playback failures are swallowed — audio is never allowed to break gameplay.
class AudioService {
  AudioService(this._enabled);

  bool _enabled;
  final AudioPlayer _player = AudioPlayer(playerId: 'ludo_sfx');

  bool get enabled => _enabled;
  set enabled(bool value) => _enabled = value;

  static const Map<Sfx, String> _files = {
    Sfx.dice: 'sfx/dice_roll.wav',
    Sfx.move: 'sfx/token_move.wav',
    Sfx.capture: 'sfx/capture.wav',
    Sfx.win: 'sfx/win.wav',
    Sfx.button: 'sfx/button.wav',
  };

  Future<void> play(Sfx sfx) async {
    if (!_enabled) return;
    final path = _files[sfx];
    if (path == null) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(path));
    } catch (_) {
      // Non-critical: ignore (e.g. asset not yet provided).
    }
  }

  Future<void> click() => play(Sfx.button);

  void dispose() => _player.dispose();
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final prefs = ref.watch(prefsProvider);
  final service = AudioService(prefs.soundEnabled);
  ref.onDispose(service.dispose);
  return service;
});
