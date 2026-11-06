import 'dart:convert';
import 'dart:math' as math;

/// A colour on an item: a human name (for the AI and for search) plus the
/// actual RGB value (for swatches and palette bars).
class ItemColor {
  const ItemColor(this.name, this.value);

  final String name;

  /// 0xRRGGBB
  final int value;

  /// A preset colour by name, e.g. 'navy'. Unknown names keep the name and
  /// get a neutral grey swatch.
  factory ItemColor.named(String name) {
    final key = name.trim().toLowerCase();
    for (final p in colorPresets) {
      if (p.name == key) return p;
    }
    return ItemColor(key, unknownColorValue);
  }

  /// An exact colour (e.g. from a photo), named after the closest preset.
  factory ItemColor.fromValue(int rgb) =>
      ItemColor(nearestPreset(rgb).name, rgb & 0xFFFFFF);

  String get hex => '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Map<String, String> toJson() => {'name': name, 'hex': hex};

  static ItemColor? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final hex = json['hex'];
    if (name is! String || hex is! String) return null;
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return value == null ? null : ItemColor(name, value);
  }

  static String encodeList(List<ItemColor> colors) =>
      jsonEncode([for (final c in colors) c.toJson()]);

  static List<ItemColor> decodeList(String? source) {
    if (source == null || source.isEmpty) return const [];
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return const [];
      return decoded.map(ItemColor.fromJson).whereType<ItemColor>().toList();
    } on FormatException {
      return const [];
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ItemColor && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(name, value);

  @override
  String toString() => '$name $hex';
}

const unknownColorValue = 0x9E9E9E;

/// Wardrobe-friendly named colours, heavy on neutrals.
const colorPresets = <ItemColor>[
  ItemColor('black', 0x1C1C1C),
  ItemColor('charcoal', 0x36454F),
  ItemColor('grey', 0x8E8E8E),
  ItemColor('light grey', 0xC8C8C8),
  ItemColor('white', 0xF7F7F5),
  ItemColor('ivory', 0xFFFDF0),
  ItemColor('cream', 0xF3E9D2),
  ItemColor('beige', 0xD9C7A7),
  ItemColor('sand', 0xC2B280),
  ItemColor('camel', 0xC19A6B),
  ItemColor('tan', 0xB08A5E),
  ItemColor('brown', 0x6F4E37),
  ItemColor('chocolate', 0x4A2C21),
  ItemColor('burgundy', 0x6D1A2B),
  ItemColor('red', 0xB3261E),
  ItemColor('rust', 0xA0522D),
  ItemColor('orange', 0xE07B39),
  ItemColor('mustard', 0xD4A017),
  ItemColor('yellow', 0xF2D24B),
  ItemColor('olive', 0x6B6B3A),
  ItemColor('khaki', 0xA39B6E),
  ItemColor('sage', 0x9CAF88),
  ItemColor('forest green', 0x2E4E3F),
  ItemColor('green', 0x3E7B4F),
  ItemColor('mint', 0xB5E2C8),
  ItemColor('teal', 0x2A7B7B),
  ItemColor('light blue', 0xA9C7E8),
  ItemColor('sky blue', 0x6FA8DC),
  ItemColor('denim', 0x5B7FA6),
  ItemColor('indigo', 0x2E3A63),
  ItemColor('navy', 0x1F2A44),
  ItemColor('lavender', 0xC8B6E2),
  ItemColor('purple', 0x6A4C93),
  ItemColor('plum', 0x5E3A5A),
  ItemColor('pink', 0xE8A0B4),
  ItemColor('blush', 0xEBC7C0),
];

ItemColor nearestPreset(int rgb) {
  var best = colorPresets.first;
  var bestDistance = double.infinity;
  for (final p in colorPresets) {
    final d = colorDistance(rgb, p.value);
    if (d < bestDistance) {
      best = p;
      bestDistance = d;
    }
  }
  return best;
}

/// Perceptual-ish distance between two 0xRRGGBB colours ("redmean"
/// approximation). 0 = identical, roughly 765 = black vs white.
double colorDistance(int a, int b) {
  final r1 = (a >> 16) & 0xFF, g1 = (a >> 8) & 0xFF, b1 = a & 0xFF;
  final r2 = (b >> 16) & 0xFF, g2 = (b >> 8) & 0xFF, b2 = b & 0xFF;
  final rMean = (r1 + r2) / 2;
  final dr = r1 - r2, dg = g1 - g2, db = b1 - b2;
  return math.sqrt((2 + rMean / 256) * dr * dr +
      4 * dg * dg +
      (2 + (255 - rMean) / 256) * db * db);
}
