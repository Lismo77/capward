import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/style_profile.dart';

class StyleProfileRepository {
  StyleProfileRepository(this._db);

  final Database _db;

  Future<StyleProfile> get() async {
    final rows = await _db.query('style_profile', where: 'id = 1');
    return rows.isEmpty ? const StyleProfile() : StyleProfile.fromRow(rows.first);
  }

  Future<void> save(StyleProfile profile) async {
    await _db.update('style_profile', profile.toRow(), where: 'id = 1');
  }
}

final styleProfileRepositoryProvider =
    FutureProvider<StyleProfileRepository>((ref) async {
  return StyleProfileRepository(await ref.watch(databaseProvider.future));
});

final styleProfileProvider = FutureProvider<StyleProfile>((ref) async {
  final repo = await ref.watch(styleProfileRepositoryProvider.future);
  return repo.get();
});
