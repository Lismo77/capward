import 'package:gansey/core/dev/sample_data.dart';
import 'package:gansey/features/wardrobe/domain/item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sample items are tagged, uniquely named and survive a row round trip',
      () {
    final names = sampleItems.map((i) => i.name).toSet();
    expect(names.length, sampleItems.length);
    for (final item in sampleItems) {
      expect(item.notes, sampleNote);
      final back = Item.fromRow(item.toRow());
      expect(back.category, item.category);
      expect(back.seasons, item.seasons);
      expect(back.status, item.status);
    }
  });

  test('sample covers every category that outfits will need', () {
    final categories = sampleItems.map((i) => i.category).toSet();
    expect(
        categories,
        containsAll([
          ItemCategory.top,
          ItemCategory.bottom,
          ItemCategory.outerwear,
          ItemCategory.shoes,
        ]));
  });
}
