import '../../game_engine/models/ludo_color.dart';

/// Typed paths to the original SVG / Lottie assets (declared in pubspec.yaml).
abstract class AppAssets {
  static const String _svg = 'assets/svg';
  static const String _anim = 'assets/animations';

  static String token(LudoColor c, {bool glow = false}) =>
      '$_svg/token_${c.name}${glow ? '_glow' : ''}.svg';

  static String die(int face) => '$_svg/die_$face.svg';

  static const String logo = '$_svg/logo_ludo_friends.svg';
  static const String splashLogo = '$_svg/splash_logo.svg';
  static const String appIcon = '$_svg/app_icon.svg';
  static const String landingLudoMotion = '$_svg/landing_ludo_motion.svg';
  static const String bgPattern = '$_svg/bg_pattern.svg';
  static const String fbButtonBg = '$_svg/btn_facebook_bg.svg';
  static const String facebookBrand = '$_svg/icon_facebook_brand.svg';
  static const String gmailBrand = '$_svg/icon_gmail_brand.svg';

  static String icon(String name) => '$_svg/icon_$name.svg';

  static const String avatarGuest = '$_svg/avatar_guest.svg';
  static String avatar(String kind) => '$_svg/avatar_$kind.svg';

  static const String illusNoInternet = '$_svg/illus_no_internet.svg';
  static const String illusEmpty = '$_svg/illus_empty_state.svg';
  static const String illusError = '$_svg/illus_error.svg';

  static const String confetti = '$_anim/confetti.json';
  static const String loading = '$_anim/loading_spinner.json';
}
