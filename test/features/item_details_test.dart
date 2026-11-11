import 'package:gansey/features/outfits/domain/outfit.dart';
import 'package:gansey/features/wardrobe/domain/item.dart';
import 'package:gansey/features/wear_log/domain/wear_stats.dart';
import 'package:flutter_test/flutter_test.dart';

Item item(
  int id,
  ItemCategory category, {
  ItemStatus status = ItemStatus.active,
  int? price,
}) =>
    Item(
      id: id,
      name: 'Item $id',
      category: category,
      status: status,
      purchasePriceCents: price,
    );

void main() {
  group('hats', () {
    test('have their own slot, shown first', () {
      expect(OutfitSlot.forCategory(ItemCategory.hat), OutfitSlot.hat);
      expect(OutfitSlot.values.first, OutfitSlot.hat);
      expect(OutfitSlot.hat.multi, isFalse);
    });

    test('picking a second hat replaces the first', () {
      final cap = item(1, ItemCategory.hat);
      final beanie = item(2, ItemCategory.hat);
      final scarf = item(3, ItemCategory.accessory);
      final byId = {
        for (final i in [cap, beanie, scarf]) i.id!: i
      };

      var selected = toggleOutfitItem({}, cap, byId);
      selected = toggleOutfitItem(selected, scarf, byId);
      selected = toggleOutfitItem(selected, beanie, byId);

      expect(selected, {2, 3});
    });

    test('sit above everything else in display order', () {
      final ordered = orderForDisplay([
        item(1, ItemCategory.shoes),
        item(2, ItemCategory.hat),
        item(3, ItemCategory.outerwear),
      ]);
      expect(ordered.map((i) => i.id), [2, 3, 1]);
    });
  });

  group('price paid', () {
    test('0 means free, blank means unknown', () {
      expect(item(1, ItemCategory.top, price: 0).isFree, isTrue);
      expect(item(2, ItemCategory.top).isFree, isFalse);
      expect(item(3, ItemCategory.top, price: 2500).isFree, isFalse);
    });

    test('free items have no cost per wear', () {
      final gift = item(1, ItemCategory.top, price: 0);
      expect(ItemWearStats(item: gift, timesWorn: 4).costPerWearCents, isNull);
      final bought = item(2, ItemCategory.top, price: 4000);
      expect(ItemWearStats(item: bought, timesWorn: 4).costPerWearCents, 1000);
    });

    test('free and unpriced items stay out of the cost-per-wear list', () {
      final stats = WardrobeStats.compute(
        items: [
          item(1, ItemCategory.top, price: 0),
          item(2, ItemCategory.top),
          item(3, ItemCategory.top, price: 3000),
        ],
        entries: const [],
        today: DateTime(2026, 11, 11),
      );
      expect(stats.costPerWear.map((s) => s.item.id), [3]);
    });
  });

  group('wardrobe view', () {
    final items = [
      item(1, ItemCategory.top),
      item(2, ItemCategory.hat),
      item(3, ItemCategory.top, status: ItemStatus.retired),
      item(4, ItemCategory.top, status: ItemStatus.stored),
      item(5, ItemCategory.hat, status: ItemStatus.wishlist),
    ];

    test('hides retired items by default', () {
      expect(wardrobeView(items).map((i) => i.id), [1, 2, 4, 5]);
    });

    test('shows only retired items in the retired view', () {
      expect(wardrobeView(items, retired: true).map((i) => i.id), [3]);
    });

    test('filters by category within either view', () {
      expect(wardrobeView(items, category: ItemCategory.top).map((i) => i.id),
          [1, 4]);
      expect(wardrobeView(items, category: ItemCategory.hat, retired: true),
          isEmpty);
    });
  });
}
