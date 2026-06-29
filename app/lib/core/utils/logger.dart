import 'dart:developer' as developer;

import '../config/app_config.dart';

/// Minimal logging facade. In dev it writes to the Dart developer log; in
/// production it routes to the crash/analytics hook (see `services/analytics`).
abstract class AppLogger {
  static void d(String message) {
    if (AppConfig.environment.isDev) {
      developer.log(message, name: 'LudoFriends');
    }
  }

  static void e(String message, [Object? error, StackTrace? stack]) {
    developer.log(message,
        name: 'LudoFriends', error: error, stackTrace: stack, level: 1000);
  }
}
