import 'dart:typed_data';

import 'package:gansey/features/wardrobe/domain/color_extraction.dart';
import 'package:gansey/features/wardrobe/domain/item.dart';
import 'package:flutter_test/flutter_test.dart';

/// A w x h RGBA image filled with [background], with a [foreground]
/// rectangle from (x0, y0) inclusive to (x1, y1) exclusive.
Uint8List _image(int w, int h, int background,
    {int? foreground, int x0 = 0, int y0 = 0, int x1 = 0, int y1 = 0}) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final inside =
          foreground != null && x >= x0 && x < x1 && y >= y0 && y < y1;
      final c = inside ? foreground : background;
      final i = (y * w + x) * 4;
      px[i] = (c >> 16) & 0xFF;
      px[i + 1] = (c >> 8) & 0xFF;
      px[i + 2] = c & 0xFF;
      px[i + 3] = 255;
    }
  }
  return px;
}

void main() {
  group('ItemColor', () {
    test('label is sentence case; name stays lowercase', () {
      final c = ItemColor.named('light grey');
      expect(c.label, 'Light grey');
      expect(c.name, 'light grey');
    });

    test('named presets are case-insensitive; unknown names get grey', () {
      expect(ItemColor.named('Navy').value, 0x1F2A44);
      final odd = ItemColor.named('chartreuse-ish');
      expect(odd.name, 'chartreuse-ish');
      expect(odd.value, unknownColorValue);
    });

    test('fromValue keeps the exact colour and names the nearest preset', () {
      final c = ItemColor.fromValue(0x202B46); // a hair off navy
      expect(c.name, 'navy');
      expect(c.hex, '#202B46');
    });

    test('JSON list round trip, ignoring junk', () {
      final colors = [ItemColor.named('camel'), ItemColor.fromValue(0x123456)];
      expect(ItemColor.decodeList(ItemColor.encodeList(colors)), colors);
      expect(ItemColor.decodeList('not json'), isEmpty);
      expect(ItemColor.decodeList('[{"name": 1}]'), isEmpty);
    });

    test('items saved before v2 get swatches from their colour names', () {
      final item = Item.fromRow({
        'id': 1,
        'name': 'Old row',
        'category': 'top',
        'colors': 'navy,cream',
        'seasons': '',
        'status': 'active',
      });
      expect(item.colors.map((c) => c.name), ['navy', 'cream']);
      expect(item.colors.first.value, 0x1F2A44);
    });
  });

  group('dominantColors', () {
    test('finds the garment and drops a plain background', () {
      const red = 0xB3261E, white = 0xFAFAFA;
      final px =
          _image(20, 20, white, foreground: red, x0: 4, y0: 4, x1: 16, y1: 16);
      final found = dominantColors(px, 20, 20);
      expect(found, hasLength(1));
      expect(nearestPreset(found.first).name, 'red');
    });

    test('keeps a garment that matches the background', () {
      const white = 0xF7F7F5;
      final px = _image(20, 20, white);
      expect(nearestPreset(dominantColors(px, 20, 20).single).name, 'white');
    });

    test('finds two colours in a two-tone garment', () {
      const navy = 0x1F2A44, cream = 0xF3E9D2;
      final px = _image(20, 20, navy,
          foreground: cream, x0: 0, y0: 10, x1: 20, y1: 20);
      final names =
          dominantColors(px, 20, 20).map((c) => nearestPreset(c).name);
      expect(names, containsAll(['navy', 'cream']));
    });

    test('ignores transparent pixels', () {
      final px = Uint8List(10 * 10 * 4); // all zero: transparent
      expect(dominantColors(px, 10, 10), isEmpty);
    });
  });

  group('applyColorSelection', () {
    final photoOlive = ItemColor.fromValue(0x707060); // greyish, named olive

    test('keeps a photo shade whose name stays selected', () {
      expect(photoOlive.name, 'olive');
      final result = applyColorSelection([photoOlive], ['olive']);
      expect(result, [photoOlive]);
    });

    test('adds new names as presets, in pick order', () {
      final result =
          applyColorSelection([photoOlive], ['olive', 'navy', 'cream']);
      expect(result.map((c) => c.name), ['olive', 'navy', 'cream']);
      expect(result[1], ItemColor.named('navy'));
    });

    test('drops colours whose name was unselected', () {
      final result =
          applyColorSelection([ItemColor.named('navy'), photoOlive], ['navy']);
      expect(result, [ItemColor.named('navy')]);
    });

    test('collapses existing duplicates of the same name', () {
      final result = applyColorSelection(
          [photoOlive, ItemColor.named('olive')], ['olive']);
      expect(result, [photoOlive]);
    });
  });
}
