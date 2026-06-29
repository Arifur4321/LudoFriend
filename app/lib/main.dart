import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/di/providers.dart';
import 'core/storage/prefs_storage.dart';
import 'core/utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Crash/error reporting hook — route framework errors to the logger
  // (swap in Sentry/Crashlytics in services/analytics for production).
  FlutterError.onError = (details) {
    AppLogger.e('FlutterError', details.exception, details.stack);
    FlutterError.presentError(details);
  };

  // SharedPreferences is initialised once and injected, so the rest of the app
  // can read it synchronously via prefsProvider.
  final prefs = await PrefsStorage.create();

  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const LudoFriendsApp(),
    ),
  );
}
