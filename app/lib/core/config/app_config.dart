import 'app_environment.dart';

/// Central, **secret-free** runtime configuration.
///
/// Nothing here is hardcoded to a private value: every externally-sensitive
/// setting comes from `--dart-define` at build time (see `docs/DEPLOYMENT.md`).
/// Example:
/// ```
/// flutter run \
///   --dart-define=APP_ENV=staging \
///   --dart-define=API_BASE_URL=https://staging.api.ludofriends.app \
///   --dart-define=WS_HOST=staging.ws.ludofriends.app \
///   --dart-define=WS_KEY=public_pusher_key
/// ```
abstract class AppConfig {
  static const String _env =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  static const String _apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static const String _wsHostOverride =
      String.fromEnvironment('WS_HOST', defaultValue: '');

  /// The *public* Pusher/Reverb app key (safe to ship; not a secret).
  static const String wsKey =
      String.fromEnvironment('WS_KEY', defaultValue: 'ludo_local_key');

  static const int wsPort = int.fromEnvironment('WS_PORT', defaultValue: 6001);

  static const bool wsTls = bool.fromEnvironment('WS_TLS', defaultValue: false);

  /// Configurable application id (Android applicationId / iOS bundle id).
  static const String appId = String.fromEnvironment(
    'APP_ID',
    defaultValue: 'com.arifurrahman.ludofriends',
  );

  // Monetization & social toggles — all OFF by default (not pay-to-win).
  static const bool adsEnabled =
      bool.fromEnvironment('ADS_ENABLED', defaultValue: false);
  static const bool iapEnabled =
      bool.fromEnvironment('IAP_ENABLED', defaultValue: false);
  // Social sign-in toggles. Facebook needs native App ID/client token setup.
  static const bool googleEnabled =
      bool.fromEnvironment('GOOGLE_ENABLED', defaultValue: true);
  static const bool facebookEnabled =
      bool.fromEnvironment('FACEBOOK_ENABLED', defaultValue: false);
  static const String googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID', defaultValue: '');
  static const String googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

  static AppEnvironment get environment {
    switch (_env) {
      case 'prod':
        return AppEnvironment.prod;
      case 'staging':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.dev;
    }
  }

  /// REST API base. Falls back to per-environment defaults when not overridden.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    switch (environment) {
      case AppEnvironment.prod:
        return 'https://api.ludofriends.app/api/v1';
      case AppEnvironment.staging:
        return 'https://staging.api.ludofriends.app/api/v1';
      case AppEnvironment.dev:
        // Android emulator reaches host machine via 10.0.2.2.
        return 'http://10.0.2.2:8000/api/v1';
    }
  }

  /// Absolute URL of Laravel's `/broadcasting/auth` (at the app root, NOT under
  /// `/api/v1`). Used to authorize private Reverb/Pusher channels with the
  /// bearer token.
  static String get broadcastingAuthUrl {
    final base = apiBaseUrl;
    final i = base.indexOf('/api/');
    final root = i >= 0 ? base.substring(0, i) : base;
    return '$root/broadcasting/auth';
  }

  static String get wsHost {
    if (_wsHostOverride.isNotEmpty) return _wsHostOverride;
    switch (environment) {
      case AppEnvironment.prod:
        return 'ws.ludofriends.app';
      case AppEnvironment.staging:
        return 'staging.ws.ludofriends.app';
      case AppEnvironment.dev:
        return '10.0.2.2';
    }
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
