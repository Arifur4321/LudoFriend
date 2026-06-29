import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import '../storage/prefs_storage.dart';
import '../storage/secure_storage.dart';

/// Cross-cutting dependency-injection providers.
///
/// [prefsProvider] is overridden in `main()` once SharedPreferences has been
/// asynchronously initialised, so the rest of the app can read it synchronously.

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final prefsProvider = Provider<PrefsStorage>(
  (ref) =>
      throw UnimplementedError('prefsProvider must be overridden in main()'),
);

final dioClientProvider =
    Provider<DioClient>((ref) => DioClient(ref.watch(secureStorageProvider)));

final dioProvider = Provider<Dio>((ref) => ref.watch(dioClientProvider).dio);
