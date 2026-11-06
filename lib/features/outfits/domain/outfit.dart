import '../../wardrobe/domain/item.dart';

enum OutfitSource { user, ai }

class Outfit {
  const Outfit({
    this.id,
    required this.name,
    this.occasion,
    this.notes,
    this.source = OutfitSource.user,
    this.itemIds = const [],
  });

  final int? id;
  final String name;
  final String? occasion;
  final String? notes;

  /// Who made it. AI-built outfits are saved the same way as manual ones.
  final OutfitSource source;
  final List<int> itemIds;

  Map<String, Object?> toRow() => {
        'name': name,
        'occasion': occasion,
        'notes': notes,
        'source': source.name,
      };

  factory Outfit.fromRow(Map<String, Object?> row, List<int> itemIds) => Outfit(
        id: row['id'] as int?,
        name: row['name'] as String,
        occasion: row['occasion'] as String?,
        notes: row['notes'] as String?,
        source:
            OutfitSource.values.asNameMap()[row['source']] ?? OutfitSource.user,
        itemIds: itemIds,
      );
}

/// Where an item sits in an outfit, top to bottom. Display order and the
/// palette bar follow this order.
enum OutfitSlot {
  outerwear('Outerwear', multi: false),
  top('Tops', multi: true), // layering: shirt + sweater
  dress('Dress', multi: false),
  bottom('Bottoms', multi: false),
  shoes('Shoes', multi: false),
  bag('Bag', multi: false),
  accessory('Accessories', multi: true);

  const OutfitSlot(this.label, {required this.multi});

  final String label;

  /// Whether more than one item can fill this slot.
  final bool multi;

  static OutfitSlot forCategory(ItemCategory category) => switch (category) {
        ItemCategory.top || ItemCategory.activewear => OutfitSlot.top,
        ItemCategory.bottom => OutfitSlot.bottom,
        ItemCategory.dress => OutfitSlot.dress,
        ItemCategory.outerwear => OutfitSlot.outerwear,
        ItemCategory.shoes => OutfitSlot.shoes,
        ItemCategory.bag => OutfitSlot.bag,
        ItemCategory.accessory || ItemCategory.other => OutfitSlot.accessory,
      };
}

/// Selects or deselects [item]. Picking an item in a one-item slot replaces
/// whatever was there, and a dress replaces bottoms (and the other way round).
Set<int> toggleOutfitItem(
  Set<int> selected,
  Item item,
  Map<int, Item> itemsById,
) {
  final id = item.id!;
  final next = {...selected};
  if (next.remove(id)) return next;

  final slot = OutfitSlot.forCategory(item.category);
  next.removeWhere((otherId) {
    final other = itemsById[otherId];
    if (other == null) return false;
    final otherSlot = OutfitSlot.forCategory(other.category);
    if (!slot.multi && otherSlot == slot) return true;
    return (slot == OutfitSlot.dress && otherSlot == OutfitSlot.bottom) ||
        (slot == OutfitSlot.bottom && otherSlot == OutfitSlot.dress);
  });
  next.add(id);
  return next;
}

/// Items sorted top to bottom (outerwear, tops, ... accessories).
List<Item> orderForDisplay(Iterable<Item> items) => items.toList()
  ..sort((a, b) {
    final bySlot = OutfitSlot.forCategory(a.category)
        .index
        .compareTo(OutfitSlot.forCategory(b.category).index);
    return bySlot != 0 ? bySlot : a.name.compareTo(b.name);
  });

/// The outfit's colours in top-to-bottom order, without near-duplicates.
List<int> outfitPalette(Iterable<Item> items, {int maxColors = 8}) {
  final palette = <int>[];
  for (final item in orderForDisplay(items)) {
    for (final c in item.colors) {
      if (palette.length >= maxColors) return palette;
      if (palette.any((p) => colorDistance(p, c.value) < 30)) continue;
      palette.add(c.value);
    }
  }
  return palette;
}

/// "Grey marl tee + Dark indigo straight jeans + 2 more"
String defaultOutfitName(List<Item> ordered) {
  if (ordered.isEmpty) return 'Outfit';
  final names = ordered.take(2).map((i) => i.name).join(' + ');
  final more = ordered.length - 2;
  return more > 0 ? '$names + $more more' : names;
}
