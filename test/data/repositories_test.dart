import 'dart:io';

import 'package:capsule_wardrobe/core/database/app_database.dart';
import 'package:capsule_wardrobe/core/database/migrations.dart';
import 'package:capsule_wardrobe/core/dev/sample_data.dart';
import 'package:capsule_wardrobe/features/outfits/data/outfit_repository.dart';
import 'package:capsule_wardrobe/features/outfits/domain/outfit.dart';
import 'package:capsule_wardrobe/features/wardrobe/data/item_repository.dart';
import 'package:capsule_wardrobe/features/wardrobe/domain/item.dart';
import 'package:capsule_wardrobe/features/wear_log/data/wear_log_repository.dart';
import 'package:capsule_wardrobe/features/wear_log/domain/wear_entry.dart';
import 'package:capsule_wardrobe/features/wear_log/domain/wear_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Runs the real schema and repositories against desktop SQLite.
void main() {
  late Database db;
  late ItemRepository items;
  late OutfitRepository outfits;
  late WearLogRepository wears;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    items = ItemRepository(db);
    outfits = OutfitRepository(db);
    wears = WearLogRepository(db);
  });

  tearDown(() => db.close());

  Future<int> addItem(String name, ItemCategory category) =>
      items.save(Item(name: name, category: category));

  test('items round-trip with colour swatches', () async {
    final id = await items.save(Item(
      name: 'Navy sweater',
      category: ItemCategory.top,
      colors: [ItemColor.fromValue(0x202B46), ItemColor.named('cream')],
    ));
    final back = await items.byId(id);
    expect(back!.colors.first.hex, '#202B46');
    expect(back.colors.map((c) => c.name), ['navy', 'cream']);
  });

  test('setStatus and deleteMany touch only the given items', () async {
    final a = await addItem('A', ItemCategory.top);
    final b = await addItem('B', ItemCategory.top);
    final c = await addItem('C', ItemCategory.top);

    await items.setStatus([a, b], ItemStatus.stored);
    expect((await items.byId(a))!.status, ItemStatus.stored);
    expect((await items.byId(c))!.status, ItemStatus.active);

    await items.deleteMany([a, c]);
    expect((await items.all()).map((i) => i.name), ['B']);
  });

  test('deleting an item removes it from outfits (cascade)', () async {
    final tee = await addItem('Tee', ItemCategory.top);
    final jeans = await addItem('Jeans', ItemCategory.bottom);
    final outfitId =
        await outfits.save(Outfit(name: 'Casual', itemIds: [tee, jeans]));

    await items.deleteMany([jeans]);
    expect((await outfits.byId(outfitId))!.itemIds, [tee]);
  });

  test('saving an existing outfit replaces its pieces', () async {
    final tee = await addItem('Tee', ItemCategory.top);
    final jeans = await addItem('Jeans', ItemCategory.bottom);
    final skirt = await addItem('Skirt', ItemCategory.bottom);
    final id = await outfits.save(Outfit(name: 'X', itemIds: [tee, jeans]));

    await outfits.save(Outfit(id: id, name: 'Y', itemIds: [tee, skirt]));
    final all = await outfits.all();
    expect(all, hasLength(1));
    expect(all.single.name, 'Y');
    expect(all.single.itemIds.toSet(), {tee, skirt});
  });

  test('sample loader can run twice without duplicates', () async {
    final coat = await addItem('My own coat', ItemCategory.outerwear);
    await wears.log(WearEntry(wornOn: DateTime(2026, 1, 1), itemIds: [coat]));
    final today = DateTime(2026, 11, 6);
    await SampleData.loadWardrobe(db, today: today);
    await SampleData.loadWardrobe(db, today: today);

    expect(await items.all(), hasLength(sampleItems.length + 1));
    final loaded = await outfits.all();
    expect(loaded, hasLength(sampleOutfits.length));
    expect(loaded.every((o) => o.itemIds.isNotEmpty), isTrue);

    final logged = await wears.all();
    final ids = {for (final o in loaded) o.id};
    expect(logged.where((w) => w.itemIds.contains(coat)), hasLength(1));
    expect(
        logged
            .where((w) => w.outfitId != null)
            .every((w) => ids.contains(w.outfitId)),
        isTrue);
    final samples = logged.where((w) => w.notes == sampleNote).length;
    expect(
        samples,
        sampleWears(today, [
          1,
          2,
          3
        ], {
          for (final i in sampleItems) i.name: 0,
        }).length);
  });

  test('sample wears give every stats section something to show', () async {
    final today = DateTime(2026, 11, 6);
    await SampleData.loadWardrobe(db, today: today);
    final stats = WardrobeStats.compute(
      items: await items.all(),
      entries: await wears.all(),
      today: today,
    );
    expect(stats.mostWorn, isNotEmpty);
    expect(stats.leastWorn, isNotEmpty);
    expect(stats.costPerWear, isNotEmpty);
    expect(stats.notWorn.map((s) => s.item.name),
        containsAll(['Black turtleneck', 'Olive chinos', 'Navy shirt dress']));
  });

  test('wear log round-trips and survives outfit and item deletes', () async {
    final tee = await addItem('Tee', ItemCategory.top);
    final jeans = await addItem('Jeans', ItemCategory.bottom);
    final outfitId =
        await outfits.save(Outfit(name: 'Casual', itemIds: [tee, jeans]));
    final id = await wears.log(WearEntry(
        wornOn: DateTime(2026, 11, 6, 20),
        outfitId: outfitId,
        itemIds: [tee, jeans]));
    await wears.log(WearEntry(wornOn: DateTime(2026, 11, 1), itemIds: [jeans]));

    var all = await wears.all();
    expect(all.map((w) => w.wornOn),
        [DateTime(2026, 11, 6), DateTime(2026, 11, 1)]);
    expect(all.first.itemIds.toSet(), {tee, jeans});

    // Deleting the outfit keeps the wear, minus the link.
    await outfits.delete(outfitId);
    all = await wears.all();
    expect(all.first.outfitId, isNull);
    expect(all.first.itemIds.toSet(), {tee, jeans});

    // Deleting every item in an entry hides it.
    await items.delete(jeans);
    all = await wears.all();
    expect(all, hasLength(1));
    expect(all.single.itemIds, [tee]);

    await wears.delete(id);
    expect(await wears.all(), isEmpty);
  });

  test('wear times round-trip and order entries within a day', () async {
    final tee = await addItem('Tee', ItemCategory.top);
    final morning = DateTime(2026, 11, 6, 8, 15);
    final evening = DateTime(2026, 11, 6, 17, 40);
    await wears.log(WearEntry.now(itemIds: [tee], now: evening));
    await wears.log(WearEntry.now(itemIds: [tee], now: morning));
    await wears.log(WearEntry(wornOn: DateTime(2026, 11, 6), itemIds: [tee]));

    final all = await wears.all();
    expect(all.map((w) => w.wornAt), [evening, morning, null]);
  });

  test('items read their created_at', () async {
    final id = await addItem('Tee', ItemCategory.top);
    expect((await items.byId(id))!.createdAt, isNotNull);
  });

  test('upgrading a v1 database keeps colours as swatches', () async {
    final dir = await Directory.systemTemp.createTemp('capward_test');
    final path = '${dir.path}/v1.db';
    final v1 = await openDatabase(path, version: 1, onCreate: (db, _) async {
      for (final sql in migrations.first) {
        await db.execute(sql);
      }
    });
    await v1.insert('items',
        {'name': 'Old sweater', 'category': 'top', 'colors': 'navy,cream'});
    await v1.close();

    final upgraded = await AppDatabase.open(path: path);
    final old = (await ItemRepository(upgraded).all()).single;
    expect(old.colors.map((c) => c.name), ['navy', 'cream']);
    expect(old.colors.first.value, ItemColor.named('navy').value);
    await upgraded.close();
    await dir.delete(recursive: true);
  });
}
