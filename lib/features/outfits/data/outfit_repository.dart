import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/outfit.dart';

class OutfitRepository {
  OutfitRepository(this._db);

  final Database _db;

  /// Newest first.
  Future<List<Outfit>> all() async {
    final rows =
        await _db.query('outfits', orderBy: 'created_at DESC, id DESC');
    final links = await _db.query('outfit_items');
    final byOutfit = <int, List<int>>{};
    for (final link in links) {
      byOutfit
          .putIfAbsent(link['outfit_id'] as int, () => [])
          .add(link['item_id'] as int);
    }
    return [
      for (final row in rows)
        Outfit.fromRow(row, byOutfit[row['id'] as int] ?? const []),
    ];
  }

  Future<Outfit?> byId(int id) async {
    final rows = await _db.query('outfits', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final links = await _db
        .query('outfit_items', where: 'outfit_id = ?', whereArgs: [id]);
    return Outfit.fromRow(
        rows.first, [for (final l in links) l['item_id'] as int]);
  }

  /// Inserts or updates the outfit and replaces its item links. Returns the id.
  Future<int> save(Outfit outfit) => _db.transaction((txn) async {
        final int id;
        if (outfit.id == null) {
          id = await txn.insert('outfits', outfit.toRow());
        } else {
          id = outfit.id!;
          await txn.update('outfits', outfit.toRow(),
              where: 'id = ?', whereArgs: [id]);
          await txn
              .delete('outfit_items', where: 'outfit_id = ?', whereArgs: [id]);
        }
        for (final itemId in outfit.itemIds.toSet()) {
          await txn
              .insert('outfit_items', {'outfit_id': id, 'item_id': itemId});
        }
        return id;
      });

  Future<void> delete(int id) async {
    await _db.delete('outfits', where: 'id = ?', whereArgs: [id]);
  }
}

final outfitRepositoryProvider = FutureProvider<OutfitRepository>((ref) async {
  return OutfitRepository(await ref.watch(databaseProvider.future));
});

final outfitsProvider = FutureProvider<List<Outfit>>((ref) async {
  final repo = await ref.watch(outfitRepositoryProvider.future);
  return repo.all();
});
