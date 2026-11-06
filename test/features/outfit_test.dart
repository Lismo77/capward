import 'package:capsule_wardrobe/features/outfits/domain/outfit.dart';
import 'package:capsule_wardrobe/features/wardrobe/domain/item.dart';
import 'package:flutter_test/flutter_test.dart';

Item _item(int id, String name, ItemCategory category,
        [List<String> colors = const []]) =>
    Item(
      id: id,
      name: name,
      category: category,
      colors: colors.map(ItemColor.named).toList(),
    );

void main() {
  final tee = _item(1, 'Tee', ItemCategory.top, ['white']);
  final sweater = _item(2, 'Sweater', ItemCategory.top, ['navy']);
  final jeans = _item(3, 'Jeans', ItemCategory.bottom, ['indigo']);
  final trousers = _item(4, 'Trousers', ItemCategory.bottom, ['black']);
  final dress = _item(5, 'Dress', ItemCategory.dress, ['navy']);
  final coat = _item(6, 'Coat', ItemCategory.outerwear, ['camel']);
  final boots = _item(7, 'Boots', ItemCategory.shoes, ['brown']);
  final byId = {
    for (final i in [tee, sweater, jeans, trousers, dress, coat, boots])
      i.id!: i
  };

  group('toggleOutfitItem', () {
    test('tops layer: several can be picked', () {
      var s = toggleOutfitItem({}, tee, byId);
      s = toggleOutfitItem(s, sweater, byId);
      expect(s, {1, 2});
    });

    test('a one-item slot swaps instead of adding', () {
      var s = toggleOutfitItem({}, jeans, byId);
      s = toggleOutfitItem(s, trousers, byId);
      expect(s, {4});
    });

    test('a dress replaces bottoms and the other way round', () {
      var s = toggleOutfitItem({1, 3}, dress, byId);
      expect(s, {1, 5});
      s = toggleOutfitItem(s, jeans, byId);
      expect(s, {1, 3});
    });

    test('tapping a selected item removes it', () {
      expect(toggleOutfitItem({1, 3}, jeans, byId), {1});
    });
  });

  test('display order runs top to bottom', () {
    final ordered = orderForDisplay([boots, jeans, tee, coat]);
    expect(ordered.map((i) => i.name), ['Coat', 'Tee', 'Jeans', 'Boots']);
  });

  test('palette follows display order and skips near-duplicates', () {
    final palette = outfitPalette([boots, dress, sweater, coat]);
    // coat camel, sweater navy, dress navy (duplicate, skipped), boots brown
    expect(palette, [
      ItemColor.named('camel').value,
      ItemColor.named('navy').value,
      ItemColor.named('brown').value,
    ]);
  });

  test('default names use the first two pieces', () {
    expect(defaultOutfitName(orderForDisplay([tee, jeans])), 'Tee + Jeans');
    expect(defaultOutfitName(orderForDisplay([tee, jeans, boots, coat])),
        'Coat + Tee + 2 more');
  });

  test('Outfit row round trip keeps source', () {
    const o = Outfit(name: 'X', source: OutfitSource.ai);
    final back = Outfit.fromRow({'id': 9, ...o.toRow()}, [1, 2]);
    expect(back.source, OutfitSource.ai);
    expect(back.itemIds, [1, 2]);
  });
}
