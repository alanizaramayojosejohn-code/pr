import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalWorkoutStore {
  static Database? _db;

  static Future<void> init() async {
    if (kIsWeb) return;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'active_workout.db'),
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE session '
        '(session_id TEXT, routine_id TEXT, started_at TEXT)',
      ),
    );
  }

  static Future<void> save({
    required String sessionId,
    required String routineId,
    required String startedAt,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.delete('session');
    await db.insert('session', {
      'session_id': sessionId,
      'routine_id': routineId,
      'started_at': startedAt,
    });
  }

  static Future<({String sessionId, String routineId, String startedAt})?> load() async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query('session', limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return (
      sessionId: r['session_id'] as String,
      routineId: r['routine_id'] as String,
      startedAt: r['started_at'] as String,
    );
  }

  static Future<void> clear() async {
    await _db?.delete('session');
  }
}
