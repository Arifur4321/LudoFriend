import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../services/audio/audio_service.dart';

class SettingsState {
  const SettingsState({
    required this.sound,
    required this.music,
    required this.localeCode,
  });

  final bool sound;
  final bool music;
  final String localeCode;

  SettingsState copyWith({bool? sound, bool? music, String? localeCode}) =>
      SettingsState(
        sound: sound ?? this.sound,
        music: music ?? this.music,
        localeCode: localeCode ?? this.localeCode,
      );
}

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final p = ref.read(prefsProvider);
    return SettingsState(
      sound: p.soundEnabled,
      music: p.musicEnabled,
      localeCode: p.localeCode,
    );
  }

  Future<void> toggleSound() async {
    final v = !state.sound;
    state = state.copyWith(sound: v);
    await ref.read(prefsProvider).setSoundEnabled(v);
    ref.read(audioServiceProvider).enabled = v;
  }

  Future<void> toggleMusic() async {
    final v = !state.music;
    state = state.copyWith(music: v);
    await ref.read(prefsProvider).setMusicEnabled(v);
  }

  Future<void> setLocale(String code) async {
    state = state.copyWith(localeCode: code);
    await ref.read(prefsProvider).setLocaleCode(code);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
