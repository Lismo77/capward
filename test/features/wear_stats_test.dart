import 'package:capsule_wardrobe/features/outfits/domain/outfit.dart';
import 'package:capsule_wardrobe/features/wardrobe/domain/item.dart';
import 'package:capsule_wardrobe/features/wear_log/domain/wear_entry.dart';
import 'package:capsule_wardrobe/features/wear_log/domain/wear_stats.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 11, 6);
DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

Item item(
  int id,
  String name, {
  int? price,
  ItemStatus status = ItemStatus.active,
  int addedDaysAgo = 365,
}) =>
    Item(
      id: id,
      name: name,
      category: ItemCategory.top,
      purchasePriceCents: price,
      status: status,
      createdAt: daysAgo(addedDaysAgo),
    );

WearEntry wear(int daysBack, List<int> ids, {int? outfitId}) =>
    WearEntry(wornOn: daysAgo(daysBack), itemIds: ids, outfitId: outfitId);

void main() {
  group('itemWearStats', () {
    test('counts distinct days and finds the last one', () {
      final s = itemWearStats([
        item(1, 'Tee')
      ], [
        wear(10, [1]),
        wear(3, [1]),
        wear(3, [1]), // logged twice that day
      ])[1]!;
      expect(s.timesWorn, 2);
      expect(s.lastWornOn, daysAgo(3));
    });

    test('cost per wear', () {
      final stats = itemWearStats([
        item(1, 'Coat', price: 10000),
        item(2, 'Tee', price: 1500),
        item(3, 'Gift'),
      ], [
        wear(1, [1]),
        wear(2, [1]),
        wear(3, [1]),
      ]);
      expect(stats[1]!.costPerWearCents, 3333);
      expect(stats[2]!.costPerWearCents, 1500, reason: 'unworn = full price');
      expect(stats[3]!.costPerWearCents, isNull);
    });
  });

  group('WardrobeStats', () {
    final items = [
      item(1, 'Favourite tee', price: 1000),
      item(2, 'Jeans', price: 9000),
      item(3, 'Old sweater', price: 6000), // last worn 120 days ago
      item(4, 'Never worn shirt'), // added a year ago
      item(5, 'New shirt', addedDaysAgo: 10), // too new to flag
      item(6, 'Winter coat', status: ItemStatus.stored),
      item(7, 'Wanted boots', status: ItemStatus.wishlist, price: 20000),
    ];
    final entries = [
      for (var d = 1; d <= 10; d++) wear(d, [1]),
      wear(5, [2]),
      wear(40, [2]),
      wear(120, [3]),
      wear(200, [6]),
    ];
    final stats =
        WardrobeStats.compute(items: items, entries: entries, today: today);
    List<String> names(List<ItemWearStats> l) =>
        [for (final s in l) s.item.name];

    test('most worn, most first, includes stored items', () {
      expect(names(stats.mostWorn),
          ['Favourite tee', 'Jeans', 'Old sweater', 'Winter coat']);
    });

    test('not worn in 90 days: active only, never-worn first', () {
      expect(names(stats.notWorn), ['Never worn shirt', 'Old sweater']);
    });

    test('least worn skips items shown elsewhere', () {
      expect(names(stats.leastWorn), ['New shirt']);
    });

    test('cost per wear ignores wishlist and unpriced items', () {
      expect(
          names(stats.costPerWear), ['Old sweater', 'Jeans', 'Favourite tee']);
      expect(stats.costPerWear.first.costPerWearCents, 6000);
    });

    test('summary counts', () {
      expect(stats.totalWearDays, 13);
      expect(stats.activeCount, 5);
      expect(stats.activeWornRecently, 2); // tee and jeans
    });
  });

  group('wear entry helpers', () {
    final entries = [
      wear(0, [1, 2], outfitId: 9),
      wear(0, [3]),
      wear(1, [1, 2], outfitId: 9),
      wear(1, [1, 2], outfitId: 9),
    ];

    test('alreadyLogged needs every item logged on that day', () {
      expect(alreadyLogged(entries, [1, 2], today), isTrue);
      expect(alreadyLogged(entries, [1, 3], today), isTrue);
      expect(alreadyLogged(entries, [1, 4], today), isFalse);
      expect(alreadyLogged(entries, [3], daysAgo(1)), isFalse);
      expect(alreadyLogged(entries, [], today), isFalse);
    });

    test('outfitWearCount counts days', () {
      expect(outfitWearCount(entries, 9), 2);
      expect(outfitWearCount(entries, 8), 0);
    });

    test('a wear entry keeps only the date', () {
      expect(
          WearEntry(wornOn: DateTime(2026, 1, 2, 18, 45), itemIds: [1]).wornOn,
          DateTime(2026, 1, 2));
    });
  });

  group('currentOutfitWear', () {
    DateTime t(int daysBack, int hour) =>
        DateTime(today.year, today.month, today.day - daysBack, hour);
    WearEntry timed(int id, DateTime at, {int? outfitId}) => WearEntry(
        id: id, wornOn: at, wornAt: at, outfitId: outfitId, itemIds: [1]);
    final now = t(0, 20);

    test('the last outfit put on today wins', () {
      final entries = [
        timed(1, t(0, 8), outfitId: 10), // office
        timed(2, t(0, 17), outfitId: 20), // switched for the evening
        timed(3, t(0, 19)), // loose scarf doesn't count as a change
      ];
      expect(currentOutfitWear(entries, now)!.outfitId, 20);
    });

    test('switching back to an earlier outfit works', () {
      final entries = [
        timed(1, t(0, 8), outfitId: 10),
        timed(2, t(0, 12), outfitId: 20),
        timed(3, t(0, 18), outfitId: 10),
      ];
      expect(currentOutfitWear(entries, now)!.id, 3);
    });

    test("yesterday's outfit isn't current today", () {
      expect(
          currentOutfitWear([timed(1, t(1, 22), outfitId: 10)], now), isNull);
    });

    test('untimed entries (logged before v3) sort first, then by id', () {
      final entries = [
        WearEntry(id: 5, wornOn: today, outfitId: 30, itemIds: [1]),
        WearEntry(id: 4, wornOn: today, outfitId: 40, itemIds: [1]),
        timed(1, t(0, 7), outfitId: 10),
      ];
      expect(currentOutfitWear(entries, now)!.outfitId, 10);
      expect(currentOutfitWear(entries.take(2), now)!.outfitId, 30);
    });
  });

  group('quick choose order', () {
    final office = const Outfit(id: 1, name: 'Office', itemIds: [1]);
    final date = const Outfit(id: 2, name: 'Date night', itemIds: [1]);
    final weekend = const Outfit(id: 3, name: 'Weekend', itemIds: [1]);
    final fresh = const Outfit(id: 4, name: 'Brand new', itemIds: [1]);
    final entries = [
      wear(1, [1], outfitId: 1),
      wear(1, [1], outfitId: 1), // same day twice counts once
      wear(9, [1], outfitId: 1),
      wear(2, [1], outfitId: 3),
      wear(20, [1], outfitId: 3),
      wear(30, [1], outfitId: 2),
    ];

    test('most worn first, then most recently worn, then name', () {
      final sorted = sortByMostWorn([fresh, date, weekend, office], entries);
      expect(sorted.map((o) => o.name),
          ['Office', 'Weekend', 'Date night', 'Brand new']);
    });

    test('lastWornOn', () {
      expect(lastWornOn(entries, 3), daysAgo(2));
      expect(lastWornOn(entries, 4), isNull);
    });
  });
}
