import 'package:capsule_wardrobe/features/coach/domain/coach_prompt.dart';
import 'package:capsule_wardrobe/features/style_profile/domain/style_profile.dart';
import 'package:capsule_wardrobe/features/wardrobe/domain/item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sweater = Item(
    id: 1,
    name: 'Navy merino crew-neck',
    category: ItemCategory.top,
    colors: ['navy'],
    material: 'merino wool',
    seasons: {Season.winter, Season.autumn},
    formality: 3,
  );
  const oldJeans = Item(
    id: 2,
    name: 'Old ripped jeans',
    category: ItemCategory.bottom,
    status: ItemStatus.retired,
  );
  const coat = Item(
    id: 3,
    name: 'Camel wool coat',
    category: ItemCategory.outerwear,
    status: ItemStatus.wishlist,
  );

  test('describeForAi is compact, with seasons in calendar order', () {
    expect(
      sweater.describeForAi(),
      '[1] Navy merino crew-neck - top; colors: navy; '
      'material: merino wool; seasons: autumn, winter; formality 3/5',
    );
  });

  test('prompt lists active items, keeps wishlist separate, skips retired',
      () {
    final prompt = buildCoachSystemPrompt(
      profile: const StyleProfile(palette: 'navy, cream, camel'),
      items: const [sweater, oldJeans, coat],
    );

    expect(prompt, contains('Palette: navy, cream, camel'));
    expect(prompt, contains('## Wardrobe (1 items in rotation)'));
    expect(prompt, contains('[1] Navy merino crew-neck'));
    expect(prompt, contains('## Wishlist'));
    expect(prompt, contains('[3] Camel wool coat'));
    expect(prompt, isNot(contains('Old ripped jeans')));
  });

  test('empty profile asks the coach to help fill it in', () {
    final prompt =
        buildCoachSystemPrompt(profile: const StyleProfile(), items: const []);
    expect(prompt, contains('Not filled in yet'));
    expect(prompt, contains('No items added yet.'));
  });

  test('Item survives a round trip through a database row', () {
    final row = sweater.toRow();
    final back = Item.fromRow(row);
    expect(back.name, sweater.name);
    expect(back.seasons, sweater.seasons);
    expect(back.colors, sweater.colors);
    expect(row['seasons'], 'autumn,winter');
  });
}
