import 'package:sqflite/sqflite.dart';

import '../../features/outfits/domain/outfit.dart';
import '../../features/wear_log/domain/wear_entry.dart';
import '../../features/style_profile/domain/style_profile.dart';
import '../../features/wardrobe/domain/item.dart';
import '../format.dart';

/// Marks rows created by the sample loader so they can be replaced without
/// touching the user's own items.
const sampleNote = 'Sample item';

/// Developer tools for testing. Only reachable from debug builds.
class SampleData {
  /// Replaces any earlier sample items, outfits and wears with a fresh set.
  /// Fills in the style profile only if it is empty. Returns the number of
  /// items added.
  ///
  /// Sample items are back-dated 200 days so the "not worn in 90 days" stat
  /// has something to show.
  static Future<int> loadWardrobe(Database db, {DateTime? today}) async {
    final t = today ?? DateTime.now();
    final added = DateTime(t.year, t.month, t.day - 200);
    await db.transaction((txn) async {
      await txn.delete('wear_log', where: 'notes = ?', whereArgs: [sampleNote]);
      await txn.delete('outfits', where: 'notes = ?', whereArgs: [sampleNote]);
      await txn.delete('items', where: 'notes = ?', whereArgs: [sampleNote]);
      final idsByName = <String, int>{};
      for (final item in sampleItems) {
        idsByName[item.name] = await txn.insert('items', {
          ...item.toRow()..remove('id'),
          'created_at': '${isoDate(added)} 12:00:00',
        });
      }
      final outfitIds = <int>[];
      for (final (name, occasion, pieces) in sampleOutfits) {
        final outfitId = await txn.insert(
          'outfits',
          Outfit(name: name, occasion: occasion, notes: sampleNote).toRow(),
        );
        outfitIds.add(outfitId);
        for (final piece in pieces) {
          await txn.insert('outfit_items',
              {'outfit_id': outfitId, 'item_id': idsByName[piece]!});
        }
      }
      final uniformId = await txn.insert(
        'outfits',
        Outfit(name: sampleUniform.name, notes: sampleNote).toRow(),
      );
      for (final piece in sampleUniform.fixed) {
        await txn.insert('outfit_items',
            {'outfit_id': uniformId, 'item_id': idsByName[piece]!});
      }
      for (final (i, options) in sampleUniform.options.indexed) {
        for (final piece in options) {
          await txn.insert('outfit_items', {
            'outfit_id': uniformId,
            'item_id': idsByName[piece]!,
            'option_group': i + 1,
          });
        }
      }
      // Earlier wears, so rotation and "never picked" have data.
      for (final (days, pieces) in sampleUniformWears) {
        final wearId = await txn.insert(
          'wear_log',
          WearEntry(
            wornOn: DateTime(t.year, t.month, t.day - days),
            outfitId: uniformId,
            itemIds: const [],
            notes: sampleNote,
          ).toRow(),
        );
        for (final piece in [...sampleUniform.fixed, ...pieces]) {
          await txn.insert('wear_log_items',
              {'wear_id': wearId, 'item_id': idsByName[piece]!});
        }
      }
      for (final wear in sampleWears(t, outfitIds, idsByName)) {
        final wearId = await txn.insert('wear_log', wear.toRow());
        for (final itemId in wear.itemIds) {
          await txn
              .insert('wear_log_items', {'wear_id': wearId, 'item_id': itemId});
        }
      }
      final rows = await txn.query('style_profile', where: 'id = 1');
      if (rows.isNotEmpty && StyleProfile.fromRow(rows.first).isEmpty) {
        await txn.update('style_profile', sampleProfile.toRow(),
            where: 'id = 1');
      }
    });
    return sampleItems.length;
  }

  /// Deletes every item, outfit, capsule and wear log entry, and clears the
  /// style profile. Photo files are left on disk.
  static Future<void> clearAll(Database db) async {
    await db.transaction((txn) async {
      for (final table in [
        'wear_log_items',
        'wear_log',
        'outfit_items',
        'outfits',
        'capsule_items',
        'capsules',
        'items',
      ]) {
        await txn.delete(table);
      }
      await txn.update('style_profile', const StyleProfile().toRow(),
          where: 'id = 1');
    });
  }
}

/// About four months of made-up wears: the sample outfits in rotation (one
/// being worn today, two yesterday), a few loose pieces, the dress only in
/// late summer, and the turtleneck and chinos never.
List<WearEntry> sampleWears(
  DateTime today,
  List<int> outfitIds,
  Map<String, int> idsByName,
) {
  DateTime at(int daysBack, int hour, [int minute = 0]) =>
      DateTime(today.year, today.month, today.day - daysBack, hour, minute);
  List<int> ids(List<String> names) => [for (final n in names) idsByName[n]!];
  final outfitPieces = [for (final (_, _, pieces) in sampleOutfits) pieces];
  WearEntry outfit(int pick, DateTime when) => WearEntry(
        wornOn: when,
        wornAt: when,
        outfitId: outfitIds[pick],
        itemIds: ids(outfitPieces[pick]),
        notes: sampleNote,
      );
  WearEntry loose(List<String> names, DateTime when) => WearEntry(
        wornOn: when,
        wornAt: when,
        itemIds: ids(names),
        notes: sampleNote,
      );

  final wears = <WearEntry>[
    // Wearing the office outfit today.
    outfit(1, at(0, 8, 15)),
    // Yesterday: office, then changed for the evening.
    outfit(1, at(1, 8, 5)),
    outfit(2, at(1, 17, 40)),
  ];
  for (var d = 2; d <= 120; d++) {
    if (d % 2 == 0) {
      // Weekend layers twice as often as the others.
      wears.add(outfit(const [0, 1, 0, 2][(d ~/ 2) % 4], at(d, 8, 30)));
    } else if (d % 5 == 0) {
      wears.add(
          loose(['White cotton tee', 'Dark indigo straight jeans'], at(d, 9)));
    }
  }
  for (final d in [100, 104, 111]) {
    wears.add(loose(['Navy shirt dress', 'White leather sneakers'], at(d, 10)));
  }
  return wears;
}

/// (name, occasion, item names) - names must match [sampleItems].
const sampleOutfits = <(String, String?, List<String>)>[
  (
    'Weekend layers',
    'weekend',
    [
      'Grey marl tee',
      'Navy chore jacket',
      'Dark indigo straight jeans',
      'White leather sneakers',
    ],
  ),
  (
    'Office smart',
    'office',
    [
      'Light blue oxford shirt',
      'Navy merino crew-neck',
      'Black tailored trousers',
      'Black leather loafers',
      'Camel wool coat',
    ],
  ),
  (
    'Autumn skirt',
    null,
    [
      'Cream cable-knit sweater',
      'Camel midi skirt',
      'Brown Chelsea boots',
      'Grey wool scarf',
    ],
  ),
];

/// A uniform: fixed pieces plus option groups (one of each is worn).
/// The layer group is autumn and winter only, so it's skipped in summer.
const sampleUniform = (
  name: 'Smart casual uniform',
  fixed: ['Navy chore jacket', 'Brown Chelsea boots'],
  options: [
    ['Light blue oxford shirt', 'Black turtleneck'],
    ['Navy merino crew-neck', 'Cream cable-knit sweater'],
    ['Olive chinos', 'Black tailored trousers'],
  ],
);

/// (days ago, options picked) for [sampleUniform]. Leaves the turtleneck,
/// cable-knit and chinos unpicked.
const sampleUniformWears = <(int, List<String>)>[
  (
    3,
    [
      'Light blue oxford shirt',
      'Navy merino crew-neck',
      'Black tailored trousers'
    ]
  ),
  (10, ['Light blue oxford shirt', 'Black tailored trousers']),
];

const sampleProfile = StyleProfile(
  styleWords: 'minimal, relaxed, a little preppy',
  palette: 'navy, cream, camel, olive, white; brown leather',
  silhouettes: 'straight-leg trousers, boxy knits, midi lengths',
  avoid: 'bright orange, skinny fits, big logos',
  lifestyle: 'hybrid office job, weekend walks, cold winters',
);

/// A small, coherent neutral capsule, with one wishlist and one retired item
/// to exercise those statuses.
final sampleItems = <Item>[
  // Tops
  Item(
    name: 'White cotton tee',
    category: ItemCategory.top,
    colors: [ItemColor.named('white')],
    material: 'cotton',
    seasons: {Season.spring, Season.summer, Season.autumn},
    formality: 1,
    brand: 'Uniqlo',
    purchasePriceCents: 1500,
    purchaseDate: DateTime(2025, 4, 2),
    notes: sampleNote,
  ),
  Item(
    name: 'Grey marl tee',
    category: ItemCategory.top,
    colors: [ItemColor.named('grey')],
    material: 'cotton',
    seasons: {Season.spring, Season.summer, Season.autumn},
    formality: 1,
    purchasePriceCents: 1500,
    purchaseDate: DateTime(2025, 4, 2),
    notes: sampleNote,
  ),
  Item(
    name: 'Navy merino crew-neck',
    category: ItemCategory.top,
    colors: [ItemColor.named('navy')],
    material: 'merino wool',
    seasons: {Season.autumn, Season.winter},
    formality: 3,
    purchasePriceCents: 8900,
    purchaseDate: DateTime(2024, 10, 12),
    notes: sampleNote,
  ),
  Item(
    name: 'Cream cable-knit sweater',
    category: ItemCategory.top,
    colors: [ItemColor.named('cream')],
    material: 'wool',
    seasons: {Season.autumn, Season.winter},
    formality: 2,
    purchasePriceCents: 12000,
    purchaseDate: DateTime(2023, 11, 20),
    notes: sampleNote,
  ),
  Item(
    name: 'Light blue oxford shirt',
    category: ItemCategory.top,
    colors: [ItemColor.named('light blue')],
    material: 'cotton',
    seasons: {Season.spring, Season.summer, Season.autumn, Season.winter},
    formality: 3,
    purchasePriceCents: 5500,
    purchaseDate: DateTime(2024, 3, 8),
    notes: sampleNote,
  ),
  Item(
    name: 'Black turtleneck',
    category: ItemCategory.top,
    colors: [ItemColor.named('black')],
    material: 'merino wool',
    seasons: {Season.autumn, Season.winter},
    formality: 4,
    purchasePriceCents: 7000,
    purchaseDate: DateTime(2024, 12, 1),
    notes: sampleNote,
  ),
  // Bottoms
  Item(
    name: 'Dark indigo straight jeans',
    category: ItemCategory.bottom,
    colors: [ItemColor.named('indigo')],
    material: 'denim',
    seasons: {Season.spring, Season.autumn, Season.winter},
    formality: 2,
    brand: "Levi's",
    purchasePriceCents: 9800,
    purchaseDate: DateTime(2023, 9, 15),
    notes: sampleNote,
  ),
  Item(
    name: 'Black tailored trousers',
    category: ItemCategory.bottom,
    colors: [ItemColor.named('black')],
    material: 'wool blend',
    seasons: {Season.spring, Season.autumn, Season.winter},
    formality: 4,
    purchasePriceCents: 11000,
    purchaseDate: DateTime(2024, 1, 22),
    notes: sampleNote,
  ),
  Item(
    name: 'Olive chinos',
    category: ItemCategory.bottom,
    colors: [ItemColor.named('olive')],
    material: 'cotton twill',
    seasons: {Season.spring, Season.summer, Season.autumn},
    formality: 3,
    purchasePriceCents: 6500,
    purchaseDate: DateTime(2025, 5, 3),
    notes: sampleNote,
  ),
  Item(
    name: 'Camel midi skirt',
    category: ItemCategory.bottom,
    colors: [ItemColor.named('camel')],
    material: 'wool',
    seasons: {Season.autumn, Season.winter},
    formality: 3,
    purchasePriceCents: 8000,
    purchaseDate: DateTime(2024, 9, 30),
    notes: sampleNote,
  ),
  // Dress
  Item(
    name: 'Navy shirt dress',
    category: ItemCategory.dress,
    colors: [ItemColor.named('navy')],
    material: 'cotton',
    seasons: {Season.spring, Season.summer},
    formality: 3,
    purchasePriceCents: 9000,
    purchaseDate: DateTime(2025, 6, 14),
    notes: sampleNote,
  ),
  // Outerwear
  Item(
    name: 'Camel wool coat',
    category: ItemCategory.outerwear,
    colors: [ItemColor.named('camel')],
    material: 'wool',
    seasons: {Season.autumn, Season.winter},
    formality: 4,
    purchasePriceCents: 32000,
    purchaseDate: DateTime(2022, 11, 5),
    notes: sampleNote,
  ),
  Item(
    name: 'Navy chore jacket',
    category: ItemCategory.outerwear,
    colors: [ItemColor.named('navy')],
    material: 'cotton canvas',
    seasons: {Season.spring, Season.autumn},
    formality: 2,
    purchasePriceCents: 11500,
    purchaseDate: DateTime(2024, 4, 18),
    notes: sampleNote,
  ),
  Item(
    name: 'Black rain shell',
    category: ItemCategory.outerwear,
    colors: [ItemColor.named('black')],
    material: 'nylon',
    seasons: {Season.spring, Season.autumn, Season.winter},
    formality: 1,
    purchasePriceCents: 15000,
    purchaseDate: DateTime(2023, 3, 10),
    notes: sampleNote,
  ),
  // Shoes
  Item(
    name: 'White leather sneakers',
    category: ItemCategory.shoes,
    colors: [ItemColor.named('white')],
    material: 'leather',
    seasons: {Season.spring, Season.summer, Season.autumn},
    formality: 2,
    purchasePriceCents: 13000,
    purchaseDate: DateTime(2024, 5, 1),
    notes: sampleNote,
  ),
  Item(
    name: 'Brown Chelsea boots',
    category: ItemCategory.shoes,
    colors: [ItemColor.named('brown')],
    material: 'suede',
    seasons: {Season.autumn, Season.winter},
    formality: 3,
    purchasePriceCents: 19000,
    purchaseDate: DateTime(2023, 10, 2),
    notes: sampleNote,
  ),
  Item(
    name: 'Black leather loafers',
    category: ItemCategory.shoes,
    colors: [ItemColor.named('black')],
    material: 'leather',
    seasons: {Season.spring, Season.autumn, Season.winter},
    formality: 4,
    purchasePriceCents: 16000,
    purchaseDate: DateTime(2024, 2, 9),
    notes: sampleNote,
  ),
  // Accessories and bag
  Item(
    name: 'Grey wool scarf',
    category: ItemCategory.accessory,
    colors: [ItemColor.named('grey')],
    material: 'wool',
    seasons: {Season.autumn, Season.winter},
    formality: 2,
    purchasePriceCents: 4000,
    purchaseDate: DateTime(2022, 12, 18),
    notes: sampleNote,
  ),
  Item(
    name: 'Brown leather belt',
    category: ItemCategory.accessory,
    colors: [ItemColor.named('brown')],
    material: 'leather',
    seasons: {Season.spring, Season.summer, Season.autumn, Season.winter},
    formality: 3,
    purchasePriceCents: 4500,
    purchaseDate: DateTime(2023, 6, 6),
    notes: sampleNote,
  ),
  Item(
    name: 'Black canvas tote',
    category: ItemCategory.bag,
    colors: [ItemColor.named('black')],
    material: 'canvas',
    seasons: {Season.spring, Season.summer, Season.autumn, Season.winter},
    formality: 2,
    purchasePriceCents: 3500,
    purchaseDate: DateTime(2024, 8, 20),
    notes: sampleNote,
  ),
  // Other statuses
  Item(
    name: 'Olive field jacket',
    category: ItemCategory.outerwear,
    colors: [ItemColor.named('olive')],
    material: 'waxed cotton',
    seasons: {Season.spring, Season.autumn},
    formality: 2,
    status: ItemStatus.wishlist,
    notes: sampleNote,
  ),
  Item(
    name: 'Faded black skinny jeans',
    category: ItemCategory.bottom,
    colors: [ItemColor.named('black')],
    material: 'denim',
    seasons: {Season.spring, Season.autumn, Season.winter},
    formality: 1,
    purchasePriceCents: 6000,
    purchaseDate: DateTime(2019, 8, 1),
    status: ItemStatus.retired,
    notes: sampleNote,
  ),
];
