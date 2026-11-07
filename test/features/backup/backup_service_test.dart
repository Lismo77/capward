import 'dart:typed_data';

import 'package:capsule_wardrobe/core/database/app_database.dart';
import 'package:capsule_wardrobe/core/database/migrations.dart';
import 'package:capsule_wardrobe/core/dev/sample_data.dart';
import 'package:capsule_wardrobe/core/photos/photo_store.dart';
import 'package:capsule_wardrobe/features/backup/data/backup_service.dart';
import 'package:capsule_wardrobe/features/backup/domain/backup_format.dart';
import 'package:capsule_wardrobe/features/outfits/data/outfit_repository.dart';
import 'package:capsule_wardrobe/features/style_profile/data/style_profile_repository.dart';
import 'package:capsule_wardrobe/features/wardrobe/data/item_repository.dart';
import 'package:capsule_wardrobe/features/wardrobe/domain/item.dart';
import 'package:capsule_wardrobe/features/wear_log/data/wear_log_repository.dart';
import 'package:capsule_wardrobe/features/wear_log/domain/wear_entry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Photos in memory, keyed `mem:<n>`.
class MemoryPhotoStore implements PhotoStore {
  final photos = <String, Uint8List>{};
  var _next = 0;

  @override
  Future<String> save(XFile file) async => saveBytes(await file.readAsBytes());

  @override
  Future<String> saveBytes(Uint8List bytes, {String extension = '.jpg'}) async {
    final ref = 'mem:${_next++}$extension';
    photos[ref] = bytes;
    return ref;
  }

  @override
  Future<Uint8List?> read(String ref) async => photos[ref];

  @override
  Future<void> delete(String ref) async => photos.remove(ref);

  @override
  Widget image(String ref,
          {BoxFit fit = BoxFit.cover, required WidgetBuilder fallback}) =>
      const SizedBox();
}

void main() {
  late Database db;
  late MemoryPhotoStore photos;
  late BackupService service;
  final today = DateTime(2026, 11, 6);
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 9, 9]);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    photos = MemoryPhotoStore();
    service = BackupService(db, photos);
  });

  tearDown(() => db.close());

  Future<Map<String, int>> counts() async => {
        for (final t in backupTables)
          t: (await db.rawQuery('SELECT COUNT(*) AS n FROM $t')).first['n']
              as int,
      };

  test('export, wipe, restore gives back the same wardrobe', () async {
    await SampleData.loadWardrobe(db, today: today);
    final items = ItemRepository(db);
    final tee =
        (await items.all()).firstWhere((i) => i.name == 'White cotton tee');
    final ref = await photos.saveBytes(jpeg);
    await db.update('items', {'photo_path': ref},
        where: 'id = ?', whereArgs: [tee.id]);
    final before = await counts();
    final wearsBefore = await WearLogRepository(db).all();
    final outfitsBefore = await OutfitRepository(db).all();
    expect(outfitsBefore.where((o) => o.isUniform), isNotEmpty,
        reason: 'the sample includes a uniform');

    // Through the real file format, as the app does it.
    final file = encodeBackup(await service.export(appVersion: '0.2.0'));
    final backup = decodeBackup(file, currentSchemaVersion: migrations.length);
    expect(backup.photos.keys, ['photos/${tee.id}.jpg']);

    // Change things after the export, then restore over them.
    await db.update('items', {'name': 'Renamed tee'},
        where: 'id = ?', whereArgs: [tee.id]);
    await db.delete('wear_log');
    await items.save(
        const Item(name: 'Unrelated coat', category: ItemCategory.outerwear));
    await service.restore(backup);

    expect(await counts(), before);
    final restoredTee = await items.byId(tee.id!);
    expect(restoredTee!.name, 'White cotton tee');
    expect(restoredTee.colors.map((c) => c.hex), tee.colors.map((c) => c.hex));
    expect(await photos.read(restoredTee.photoPath!), jpeg);
    expect(restoredTee.photoPath, isNot(ref), reason: 'saved as a new photo');
    expect(photos.photos.containsKey(ref), isFalse,
        reason: 'the replaced photo is cleaned up');

    String describe(WearEntry w) =>
        '${w.wornAt}|${w.outfitId}|${(w.itemIds.toList()..sort()).join(',')}';
    final wearsAfter = await WearLogRepository(db).all();
    expect(wearsAfter.map(describe), wearsBefore.map(describe));
    expect((await OutfitRepository(db).all()).map((o) => o.optionGroups),
        outfitsBefore.map((o) => o.optionGroups));
    expect((await StyleProfileRepository(db).get()).palette,
        sampleProfile.palette);
  });

  test('a failed restore leaves the current data alone', () async {
    await SampleData.loadWardrobe(db, today: today);
    final before = await counts();
    final bad = Backup(
      schemaVersion: migrations.length,
      exportedAt: today,
      tables: {
        'items': [
          {'id': 1, 'name': 'Tee', 'category': 'top'},
        ],
        // Points at an item that doesn't exist: the foreign key fails.
        'outfit_items': [
          {'outfit_id': 99, 'item_id': 42},
        ],
      },
      photos: {'photos/1.jpg': jpeg},
    );
    await expectLater(service.restore(bad), throwsA(isA<BackupException>()));
    expect(await counts(), before);
    expect(photos.photos, isEmpty, reason: 'photos saved for it are removed');
  });

  test('restoring a backup without a style profile still leaves the row',
      () async {
    await service.restore(
        Backup(schemaVersion: 1, exportedAt: today, tables: {'items': []}));
    expect(await db.query('style_profile'), hasLength(1));
  });

  test('unknown columns in a backup are ignored', () async {
    await service.restore(Backup(
      schemaVersion: migrations.length,
      exportedAt: today,
      tables: {
        'items': [
          {'id': 5, 'name': 'Tee', 'category': 'top', 'sparkle_level': 9},
        ],
      },
    ));
    expect((await ItemRepository(db).byId(5))!.name, 'Tee');
  });
}
