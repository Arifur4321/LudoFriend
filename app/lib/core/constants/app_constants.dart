/// Static, non-secret constants used across the app.
abstract class AppConstants {
  static const String appName = 'Ludo Friends';

  // Asset roots (declared in pubspec.yaml).
  static const String svgPath = 'assets/svg';
  static const String imagePath = 'assets/images';
  static const String animationPath = 'assets/animations';
  static const String sfxPath = 'assets/sfx';

  // Common animation durations.
  static const Duration pageTransition = Duration(milliseconds: 350);
  static const Duration diceRoll = Duration(milliseconds: 700);
  static const Duration tokenStep = Duration(milliseconds: 160);
  static const Duration botThinkDelay = Duration(milliseconds: 650);

  // Secure-storage keys.
  static const String kAuthToken = 'auth_token';
  static const String kGuestId = 'guest_id';

  // Prefs keys.
  static const String kSoundEnabled = 'sound_enabled';
  static const String kMusicEnabled = 'music_enabled';
  static const String kOnboardingDone = 'onboarding_done';
  static const String kGuestName = 'guest_name';
  static const String kLocale = 'locale_code';
}
