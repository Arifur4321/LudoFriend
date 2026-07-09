import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../services/audio/audio_service.dart';

class SettingsState {
  const SettingsState({
    required this.sound,
    required this.music,
    required this.vibration,
    required this.turnAlerts,
    required this.chat,
    required this.emoji,
    required this.localeCode,
  });

  final bool sound;
  final bool music;
  final bool vibration;
  final bool turnAlerts;
  final bool chat;
  final bool emoji;
  final String localeCode;

  SettingsState copyWith({
    bool? sound,
    bool? music,
    bool? vibration,
    bool? turnAlerts,
    bool? chat,
    bool? emoji,
    String? localeCode,
  }) =>
      SettingsState(
        sound: sound ?? this.sound,
        music: music ?? this.music,
        vibration: vibration ?? this.vibration,
        turnAlerts: turnAlerts ?? this.turnAlerts,
        chat: chat ?? this.chat,
        emoji: emoji ?? this.emoji,
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
      vibration: p.vibrationEnabled,
      turnAlerts: p.turnAlerts,
      chat: p.chatEnabled,
      emoji: p.emojiEnabled,
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

  Future<void> toggleVibration() async {
    final v = !state.vibration;
    state = state.copyWith(vibration: v);
    await ref.read(prefsProvider).setVibrationEnabled(v);
  }

  Future<void> toggleTurnAlerts() async {
    final v = !state.turnAlerts;
    state = state.copyWith(turnAlerts: v);
    await ref.read(prefsProvider).setTurnAlerts(v);
  }

  Future<void> toggleChat() async {
    final v = !state.chat;
    state = state.copyWith(chat: v);
    await ref.read(prefsProvider).setChatEnabled(v);
  }

  Future<void> toggleEmoji() async {
    final v = !state.emoji;
    state = state.copyWith(emoji: v);
    await ref.read(prefsProvider).setEmojiEnabled(v);
  }

  Future<void> setLocale(String code) async {
    state = state.copyWith(localeCode: code);
    await ref.read(prefsProvider).setLocaleCode(code);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
