import 'dart:math';

import 'package:capsule_wardrobe/features/outfits/domain/outfit.dart';
import 'package:capsule_wardrobe/features/outfits/domain/uniform.dart';
import 'package:capsule_wardrobe/features/wardrobe/domain/item.dart';
import 'package:capsule_wardrobe/features/wear_log/domain/wear_entry.dart';
import 'package:flutter_test/flutter_test.dart';

Item _item(int id, ItemCategory category,
        {Set<Season> seasons = const {},
        ItemStatus status = ItemStatus.active}) =>
    Item(
      id: id,
      name: 'Item $id',
      category: category,
      seasons: seasons,
      status: status,
    );

WearEntry _wear(DateTime day, List<int> itemIds, {int? outfitId}) =>
    WearEntry(wornOn: day, wornAt: day, outfitId: outfitId, itemIds: itemIds);

void main() {
  // The uniform from the planning discussion: fixed boots and jacket,
  // a choice of oxfords, a seasonal layer and a choice of ties.
  const boots = 1, jacket = 2;
  const oxfordWhite = 10, oxfordBlue = 11, oxfordGreen = 12;
  const vest = 20, sweater = 21;
  const tieA = 30, tieB = 31;
  final items = [
    _item(boots, ItemCategory.shoes),
    _item(jacket, ItemCategory.outerwear),
    _item(oxfordWhite, ItemCategory.top),
    _item(oxfordBlue, ItemCategory.top),
    _item(oxfordGreen, ItemCategory.top),
    _item(vest, ItemCategory.top, seasons: {Season.spring, Season.autumn}),
    _item(sweater, ItemCategory.top, seasons: {Season.winter}),
    _item(tieA, ItemCategory.accessory),
    _item(tieB, ItemCategory.accessory, status: ItemStatus.stored),
  ];
  final byId = {for (final i in items) i.id!: i};
  const uniform = Outfit(
    id: 7,
    name: 'Uniform',
    itemIds: [
      jacket, oxfordWhite, oxfordBlue, oxfordGreen, vest, sweater, //
      tieA, tieB, boots,
    ],
    optionGroups: {
      oxfordWhite: 1, oxfordBlue: 1, oxfordGreen: 1, //
      vest: 2, sweater: 2,
      tieA: 3, tieB: 3,
    },
  );
  final today = DateTime(2026, 11, 6, 8);

  group('Season.on', () {
    test('uses meteorological seasons', () {
      expect(Season.on(DateTime(2026, 3, 1)), Season.spring);
      expect(Season.on(DateTime(2026, 8, 31)), Season.summer);
      expect(Season.on(DateTime(2026, 11, 6)), Season.autumn);
      expect(Season.on(DateTime(2026, 12, 1)), Season.winter);
      expect(Season.on(DateTime(2027, 2, 28)), Season.winter);
    });

    test('flips in the southern hemisphere', () {
      expect(Season.on(DateTime(2026, 11, 6), southernHemisphere: true),
          Season.spring);
      expect(Season.on(DateTime(2026, 7, 1), southernHemisphere: true),
          Season.winter);
    });
  });

  test('pickable options skip out-of-season and stored items', () {
    expect(pickableOptions(uniform, byId, Season.autumn), [
      [oxfordWhite, oxfordBlue, oxfordGreen],
      [vest],
      [tieA],
    ]);
    expect(pickableOptions(uniform, byId, Season.summer)[1], isEmpty);
  });

  group('leastRecentPick', () {
    test('never-worn options come first, in group order', () {
      expect(leastRecentPick(uniform, byId, const [], Season.autumn),
          [jacket, oxfordWhite, vest, tieA, boots]);
    });

    test('takes the option worn longest ago', () {
      final entries = [
        _wear(DateTime(2026, 11, 5), [oxfordWhite]),
        _wear(DateTime(2026, 11, 1), [oxfordBlue]),
        _wear(DateTime(2026, 11, 3), [oxfordGreen]),
      ];
      expect(leastRecentPick(uniform, byId, entries, Season.autumn),
          contains(oxfordBlue));
    });

    test('a group with nothing in season is left out', () {
      final summer = leastRecentPick(uniform, byId, const [], Season.summer);
      expect(summer, isNot(contains(vest)));
      expect(summer, isNot(contains(sweater)));
      expect(leastRecentPick(uniform, byId, const [], Season.winter),
          contains(sweater));
    });
  });

  test('shufflePick keeps fixed pieces and always changes something', () {
    final random = Random(1);
    var current = leastRecentPick(uniform, byId, const [], Season.autumn);
    for (var i = 0; i < 20; i++) {
      final next =
          shufflePick(uniform, byId, Season.autumn, random, current: current);
      expect(next, containsAll([jacket, boots, vest, tieA]));
      expect(next.where((id) => uniform.optionGroups[id] == 1), hasLength(1));
      expect(next, isNot(equals(current)));
      current = next;
    }
  });

  group('piecesForToday', () {
    test('a plain outfit is all its pieces', () {
      const plain = Outfit(id: 3, name: 'Plain', itemIds: [boots, jacket]);
      expect(
          piecesForToday(plain,
              byId: byId, entries: const [], now: today, season: Season.autumn),
          [boots, jacket]);
    });

    test('what was worn today wins, then a shuffle, then rotation', () {
      List<int> pieces(List<WearEntry> entries, {List<int>? shuffled}) =>
          piecesForToday(uniform,
              byId: byId,
              entries: entries,
              now: today,
              season: Season.autumn,
              shuffled: shuffled);

      expect(pieces(const []), contains(oxfordWhite));
      expect(pieces(const [], shuffled: [boots, oxfordGreen]),
          [boots, oxfordGreen]);

      final wornToday =
          _wear(today, [boots, oxfordBlue, vest, tieA], outfitId: uniform.id);
      expect(pieces([wornToday], shuffled: [boots, oxfordGreen]),
          wornToday.itemIds);

      final wornYesterday =
          _wear(DateTime(2026, 11, 5), [oxfordWhite], outfitId: uniform.id);
      expect(pieces([wornYesterday]), contains(oxfordBlue),
          reason: 'yesterday rotates the next option in');
    });
  });

  test('optionWearDays counts days per option, including never picked', () {
    final entries = [
      _wear(DateTime(2026, 11, 1), [oxfordWhite, tieA], outfitId: uniform.id),
      _wear(DateTime(2026, 11, 2), [oxfordWhite], outfitId: uniform.id),
      _wear(DateTime(2026, 11, 3), [oxfordBlue]), // not via the uniform
    ];
    final days = optionWearDays(uniform, entries);
    expect(days[oxfordWhite], 2);
    expect(days[tieA], 1);
    expect(days[oxfordBlue], 0);
    expect(days.containsKey(boots), isFalse, reason: 'fixed pieces skipped');
  });
}
