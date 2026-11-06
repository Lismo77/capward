import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';
import 'platform/db_factory_io.dart'
    if (dart.library.js_interop) 'platform/db_factory_web.dart';

class AppDatabase {
  static Future<Database> open({String? path}) async {
    final factory = appDatabaseFactory;
    final dbPath =
        path ?? p.join(await factory.getDatabasesPath(), 'capsule_wardrobe.db');
    return factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: migrations.length,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          for (var i = 0; i < version; i++) {
            await _apply(db, migrations[i]);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          for (var i = oldVersion; i < newVersion; i++) {
            await _apply(db, migrations[i]);
          }
        },
      ),
    );
  }

  static Future<void> _apply(Database db, List<String> statements) async {
    final batch = db.batch();
    for (final sql in statements) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);
  }
}

final databaseProvider = FutureProvider<Database>((ref) async {
  final db = await AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});
