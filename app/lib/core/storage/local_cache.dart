import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A tiny on-device key/value cache. Reads are synchronous (served from an
/// in-memory mirror) so the UI can show last-known values instantly on a cold
/// start; writes persist through to the backing store.
///
/// The default binding is an in-memory (non-persistent) implementation so unit
/// tests and any environment without the sqflite plugin keep working. `main()`
/// overrides [localCacheProvider] with the sqflite-backed [SqliteLocalCache].
abstract class LocalCache {
  // Raw string storage — the two methods concrete stores must implement.
  String? getRaw(String key);
  Future<void> setRaw(String key, String? value);

  // ---- typed helpers -------------------------------------------------------

  int? getInt(String key) {
    final v = getRaw(key);
    return v == null ? null : int.tryParse(v);
  }

  Future<void> setInt(String key, int value) => setRaw(key, '$value');

  static const _kCoins = 'wallet_coins';
  static const _kNextSpin = 'free_spin_next_at';
  static const _kBoard = 'selected_board_tier';

  /// Last-known wallet balance (for instant display before the network responds).
  int? get cachedCoins => getInt(_kCoins);
  Future<void> cacheCoins(int coins) => setInt(_kCoins, coins);

  /// When the next free spin unlocks (for an instant offline countdown).
  DateTime? get nextFreeSpinAt {
    final v = getRaw(_kNextSpin);
    return v == null ? null : DateTime.tryParse(v);
  }

  Future<void> setNextFreeSpinAt(DateTime? at) =>
      setRaw(_kNextSpin, at?.toIso8601String());

  /// The board tier the player last chose.
  String? get selectedBoardTier => getRaw(_kBoard);
  Future<void> setSelectedBoardTier(String key) => setRaw(_kBoard, key);
}

/// Non-persistent fallback used in tests / when the DB can't open.
class InMemoryLocalCache extends LocalCache {
  final Map<String, String> _mem = {};

  @override
  String? getRaw(String key) => _mem[key];

  @override
  Future<void> setRaw(String key, String? value) async {
    if (value == null) {
      _mem.remove(key);
    } else {
      _mem[key] = value;
    }
  }
}

/// Overridden in `main()` with the sqflite-backed cache.
final localCacheProvider = Provider<LocalCache>((ref) => InMemoryLocalCache());
