import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Non-sensitive local preferences (sound toggles, onboarding flag, guest name).
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
