import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/item.dart';

class ItemRepository {
  ItemRepository(this._db);

  final Database _db;

  Future<List<Item>> all({ItemStatus? status}) async {
    final rows = await _db.query(
      'items',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status.name],
      orderBy: 'category, name COLLATE NOCASE',
    );
    return rows.map(Item.fromRow).toList();
  }

  Future<Item?> byId(int id) async {
    final rows = await _db.query('items', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Item.fromRow(rows.first);
  }

  /// Inserts a new item or updates an existing one. Returns the item id.
  Future<int> save(Item item) async {
    final row = item.toRow()..remove('id');
    if (item.id == null) {
      return _db.insert('items', row);
    }
    row['updated_at'] = DateTime.now().toIso8601String();
    await _db.update('items', row, where: 'id = ?', whereArgs: [item.id]);
    return item.id!;
  }

  Future<void> delete(int id) async {
    await _db.delete('items', where: 'id = ?', whereArgs: [id]);
  }
}

final itemRepositoryProvider = FutureProvider<ItemRepository>((ref) async {
  return ItemRepository(await ref.watch(databaseProvider.future));
});

/// Every item, any status. Invalidate this after writes to refresh the UI.
final itemsProvider = FutureProvider<List<Item>>((ref) async {
  final repo = await ref.watch(itemRepositoryProvider.future);
  return repo.all();
});
