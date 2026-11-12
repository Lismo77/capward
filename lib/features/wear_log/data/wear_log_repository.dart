import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../wardrobe/data/item_repository.dart';
import '../domain/wear_entry.dart';
import '../domain/wear_stats.dart';

class WearLogRepository {
  WearLogRepository(this._db);

  final Database _db;

  /// Newest first. Entries whose items have all been deleted are skipped.
  Future<List<WearEntry>> all() async {
    final rows = await _db.query('wear_log',
        orderBy: 'worn_on DESC, worn_at DESC, id DESC');
    final links = await _db.query('wear_log_items');
    final byWear = <int, List<int>>{};
    for (final link in links) {
      byWear
          .putIfAbsent(link['wear_id'] as int, () => [])
          .add(link['item_id'] as int);
    }
    return [
      for (final row in rows)
        if (byWear[row['id'] as int] case final ids? when ids.isNotEmpty)
          WearEntry.fromRow(row, ids),
    ];
  }

  /// Saves a new entry and returns its id.
  Future<int> log(WearEntry entry) => _db.transaction((txn) async {
        final id = await txn.insert('wear_log', entry.toRow());
        for (final itemId in entry.itemIds.toSet()) {
          await txn
              .insert('wear_log_items', {'wear_id': id, 'item_id': itemId});
        }
        return id;
      });

  Future<void> delete(int id) async {
    await _db.delete('wear_log', where: 'id = ?', whereArgs: [id]);
  }

  /// Adds pieces to an existing entry ("add to today's outfit"). Pieces
  /// already in it are ignored.
  Future<void> addItems(int wearId, Iterable<int> itemIds) =>
      _db.transaction((txn) async {
        for (final itemId in itemIds.toSet()) {
          await txn.insert(
              'wear_log_items', {'wear_id': wearId, 'item_id': itemId},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      });

  /// Takes a piece out of an entry: it wasn't worn after all. Removing the
  /// last piece deletes the entry. Returns true if the entry was deleted.
  Future<bool> removeItem(int wearId, int itemId) =>
      _db.transaction((txn) async {
        await txn.delete('wear_log_items',
            where: 'wear_id = ? AND item_id = ?', whereArgs: [wearId, itemId]);
        final left = await txn.query('wear_log_items',
            columns: ['item_id'],
            where: 'wear_id = ?',
            whereArgs: [wearId],
            limit: 1);
        if (left.isNotEmpty) return false;
        await txn.delete('wear_log', where: 'id = ?', whereArgs: [wearId]);
        return true;
      });
}

final wearLogRepositoryProvider =
    FutureProvider<WearLogRepository>((ref) async {
  return WearLogRepository(await ref.watch(databaseProvider.future));
});

/// Every wear entry, newest first. Invalidate after logging or deleting.
final wearLogProvider = FutureProvider<List<WearEntry>>((ref) async {
  final repo = await ref.watch(wearLogRepositoryProvider.future);
  return repo.all();
});

/// What's being worn right now (see [currentWear]), or null.
final currentWearProvider = Provider<WearEntry?>((ref) {
  final entries = ref.watch(wearLogProvider).valueOrNull;
  return entries == null ? null : currentWear(entries, DateTime.now());
});

final wardrobeStatsProvider = FutureProvider<WardrobeStats>((ref) async {
  final items = await ref.watch(itemsProvider.future);
  final entries = await ref.watch(wearLogProvider.future);
  return WardrobeStats.compute(
    items: items,
    entries: entries,
    today: DateTime.now(),
  );
});

/// Stats for one item, or null while loading or if the item is unknown.
final itemWearStatsProvider =
    Provider.family<ItemWearStats?, int>((ref, itemId) {
  final items = ref.watch(itemsProvider).valueOrNull;
  final entries = ref.watch(wearLogProvider).valueOrNull;
  if (items == null || entries == null) return null;
  return itemWearStats(items.where((i) => i.id == itemId), entries)[itemId];
});
