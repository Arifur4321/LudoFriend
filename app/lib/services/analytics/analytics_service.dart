import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/logger.dart';

/// Crash + analytics facade.
///
/// Default implementation only logs. Wire a real backend (Firebase, Sentry,
/// etc.) by swapping the provider — the rest of the app calls this interface.
class AnalyticsService {
  void logEvent(String name, [Map<String, Object?> params = const {}]) {
    AppLogger.d('analytics: $name $params');
  }

  void recordError(Object error, StackTrace stack, {String? reason}) {
    AppLogger.e('crash${reason == null ? '' : ' ($reason)'}', error, stack);
  }
}

final analyticsServiceProvider =
    Provider<AnalyticsService>((ref) => AnalyticsService());
