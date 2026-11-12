import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/migrations.dart';
import '../../../core/photos/photo_store.dart';
import '../domain/backup_format.dart';

class BackupService {
  BackupService(this._db, this._photos);

  final Database _db;
  final PhotoStore _photos;

  /// Everything in the wardrobe, ready for [encodeBackup].
  Future<Backup> export({String? appVersion, DateTime? now}) async {
    final tables = <String, List<BackupRow>>{};
    for (final table in backupTables) {
      final rows = await _db.query(table, orderBy: 'rowid');
      tables[table] = [for (final r in rows) BackupRow.of(r)];
    }

    // Photos go in the zip; photo_path points at the zip entry instead of a
    // device-specific path.
    final photos = <String, Uint8List>{};
    for (final item in tables['items']!) {
      final ref = item['photo_path'] as String?;
      if (ref == null) continue;
      final bytes = await _photos.read(ref);
      if (bytes == null) {
        item['photo_path'] = null; // file already missing on this device
        continue;
      }
      final name = 'photos/${item['id']}${photoExtension(bytes)}';
      photos[name] = bytes;
      item['photo_path'] = name;
    }

    return Backup(
      schemaVersion: migrations.length,
      exportedAt: now ?? DateTime.now(),
      appVersion: appVersion,
      tables: tables,
      photos: photos,
    );
  }

  /// Replaces everything in the wardrobe with [backup]. All or nothing: if
  /// anything fails, the current data is left as it was.
  Future<void> restore(Backup backup) async {
    // Photos first. They're files on Android, so they can't join the
    // database transaction; if the restore fails they're removed again.
    final newRefs = <String, String>{};
    final oldRefs = await _photoRefs();
    try {
      for (final MapEntry(key: name, value: bytes) in backup.photos.entries) {
        newRefs[name] =
            await _photos.saveBytes(bytes, extension: p.extension(name));
      }
      await _db.transaction((txn) async {
        for (final table in backupTables.reversed) {
          await txn.delete(table);
        }
        for (final table in backupTables) {
          final columns = await _columns(txn, table);
          for (final raw in backup.tables[table] ?? const <BackupRow>[]) {
            final row = upgradeBackupRow(table, raw, backup.schemaVersion);
            final values = {
              for (final MapEntry(:key, :value) in row.entries)
                if (columns.contains(key)) key: value,
            };
            if (table == 'items' && values['photo_path'] is String) {
              values['photo_path'] = newRefs[values['photo_path']];
            }
            await txn.insert(table, values);
          }
        }
        // The app expects the single style profile row to exist.
        await txn.insert('style_profile', {'id': 1},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      });
    } on DatabaseException catch (e) {
      await _deleteAll(newRefs.values);
      throw BackupException('The backup is damaged and was not imported. '
          '(${e.toString().split('\n').first})');
    } catch (_) {
      await _deleteAll(newRefs.values);
      rethrow;
    }
    // Only now that the new data is in: remove the photos it replaced.
    await _deleteAll(oldRefs);
  }

  Future<List<String>> _photoRefs() async {
    final rows = await _db.query('items',
        columns: ['photo_path'], where: 'photo_path IS NOT NULL');
    return [for (final r in rows) r['photo_path'] as String];
  }

  Future<void> _deleteAll(Iterable<String> refs) async {
    for (final ref in refs) {
      try {
        await _photos.delete(ref);
      } catch (_) {
        // A leftover photo file is harmless; don't fail the restore for it.
      }
    }
  }

  static Future<Set<String>> _columns(DatabaseExecutor db, String table) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return {for (final c in info) c['name'] as String};
  }
}

final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  return BackupService(
    await ref.watch(databaseProvider.future),
    ref.watch(photoStoreProvider),
  );
});
