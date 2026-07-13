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
  static const Duration capturedTokenStep = Duration(milliseconds: 45);
  static const Duration botThinkDelay = Duration(milliseconds: 650);

  // Secure-storage keys.
  static const String kAuthToken = 'auth_token';
  static const String kGuestId = 'guest_id';

  /// Cached JSON of the signed-in user, written alongside the Sanctum token.
  /// Lets the app restore the session instantly on launch and stay signed in
  /// when the network is briefly unavailable (the token itself remains the
  /// only credential; this is display/identity data, never a secret).
  static const String kAuthUser = 'auth_user';

  // Prefs keys.
  static const String kSoundEnabled = 'sound_enabled';
  static const String kMusicEnabled = 'music_enabled';
  static const String kVibration = 'vibration_enabled';
  static const String kTurnAlerts = 'turn_alerts_enabled';
  static const String kChatEnabled = 'chat_enabled';
  static const String kEmojiEnabled = 'emoji_enabled';
  static const String kOnboardingDone = 'onboarding_done';
  static const String kGuestName = 'guest_name';
  static const String kLocale = 'locale_code';
}
