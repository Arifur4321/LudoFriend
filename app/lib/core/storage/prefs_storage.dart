import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Non-sensitive local preferences (sound/haptics toggles, alerts, onboarding
/// flag, guest name, locale).
class PrefsStorage {
  PrefsStorage(this._prefs);
  final SharedPreferences _prefs;

  static Future<PrefsStorage> create() async =>
      PrefsStorage(await SharedPreferences.getInstance());

  bool get soundEnabled => _prefs.getBool(AppConstants.kSoundEnabled) ?? true;
  Future<void> setSoundEnabled(bool v) =>
      _prefs.setBool(AppConstants.kSoundEnabled, v);

  bool get musicEnabled => _prefs.getBool(AppConstants.kMusicEnabled) ?? true;
  Future<void> setMusicEnabled(bool v) =>
      _prefs.setBool(AppConstants.kMusicEnabled, v);

  bool get vibrationEnabled =>
      _prefs.getBool(AppConstants.kVibration) ?? true;
  Future<void> setVibrationEnabled(bool v) =>
      _prefs.setBool(AppConstants.kVibration, v);

  bool get turnAlerts => _prefs.getBool(AppConstants.kTurnAlerts) ?? true;
  Future<void> setTurnAlerts(bool v) =>
      _prefs.setBool(AppConstants.kTurnAlerts, v);

  bool get chatEnabled => _prefs.getBool(AppConstants.kChatEnabled) ?? true;
  Future<void> setChatEnabled(bool v) =>
      _prefs.setBool(AppConstants.kChatEnabled, v);

  bool get emojiEnabled => _prefs.getBool(AppConstants.kEmojiEnabled) ?? true;
  Future<void> setEmojiEnabled(bool v) =>
      _prefs.setBool(AppConstants.kEmojiEnabled, v);

  bool get onboardingDone =>
      _prefs.getBool(AppConstants.kOnboardingDone) ?? false;
  Future<void> setOnboardingDone(bool v) =>
      _prefs.setBool(AppConstants.kOnboardingDone, v);

  String? get guestName => _prefs.getString(AppConstants.kGuestName);
  Future<void> setGuestName(String v) =>
      _prefs.setString(AppConstants.kGuestName, v);

  String get localeCode => _prefs.getString(AppConstants.kLocale) ?? 'en';
  Future<void> setLocaleCode(String v) =>
      _prefs.setString(AppConstants.kLocale, v);
}
