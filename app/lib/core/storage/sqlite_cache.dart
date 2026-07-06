import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'local_cache.dart';

/// SQLite-backed [LocalCache]. On [create] it opens (or migrates) the DB and
/// loads the whole (tiny) cache table into memory, so subsequent reads are
/// synchronous; writes update memory and persist to SQLite.
class SqliteLocalCache extends LocalCache {
  SqliteLocalCache._(this._db, this._mem);

  final Database _db;
  final Map<String, String> _mem;

  static const _table = 'cache';

  static Future<SqliteLocalCache> create() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'ludo_cache.db'),
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE $_table (key TEXT PRIMARY KEY, value TEXT)',
      ),
    );

    final rows = await db.query(_table);
    final mem = <String, String>{
      for (final r in rows) r['key'] as String: (r['value'] as String? ?? ''),
    };

    return SqliteLocalCache._(db, mem);
  }

  @override
  String? getRaw(String key) => _mem[key];

  @override
  Future<void> setRaw(String key, String? value) async {
    if (value == null) {
      _mem.remove(key);
      await _db.delete(_table, where: 'key = ?', whereArgs: [key]);
    } else {
      _mem[key] = value;
      await _db.insert(
        _table,
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
