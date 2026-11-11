import '../../../core/format.dart';
import '../../wardrobe/domain/item.dart';
import 'wear_entry.dart';

/// How much one item gets worn. A day counts once, even if the item was
/// logged twice that day (say, on its own and as part of an outfit).
class ItemWearStats {
  const ItemWearStats({
    required this.item,
    required this.timesWorn,
    this.lastWornOn,
  });

  final Item item;
  final int timesWorn;
  final DateTime? lastWornOn;

  /// Price divided by wears. An unworn item's cost per wear is its full
  /// price. Null when no price was entered, or when the item was free or a
  /// gift (there is nothing to earn back).
  int? get costPerWearCents {
    final price = item.purchasePriceCents;
    if (price == null || price == 0) return null;
    return timesWorn == 0 ? price : (price / timesWorn).round();
  }
}

/// Per-item stats for every item that has an id.
Map<int, ItemWearStats> itemWearStats(
  Iterable<Item> items,
  Iterable<WearEntry> entries,
) {
  final days = <int, Set<DateTime>>{};
  for (final e in entries) {
    for (final id in e.itemIds) {
      days.putIfAbsent(id, () => {}).add(e.wornOn);
    }
  }
  return {
    for (final item in items)
      if (item.id != null)
        item.id!: ItemWearStats(
          item: item,
          timesWorn: days[item.id]?.length ?? 0,
          lastWornOn: days[item.id]?.reduce((a, b) => a.isAfter(b) ? a : b),
        ),
  };
}

/// Everything the Stats screen shows.
class WardrobeStats {
  WardrobeStats._({
    required this.totalWearDays,
    required this.activeCount,
    required this.activeWornRecently,
    required this.mostWorn,
    required this.leastWorn,
    required this.notWorn,
    required this.costPerWear,
  });

  /// Computes stats as of [today].
  ///
  /// - Most worn: owned items (not wishlist), most wears first.
  /// - Not worn: active items unworn for [notWornDays] days. Never-worn
  ///   items only count once they've been in the app that long, so a freshly
  ///   entered wardrobe isn't flagged.
  /// - Least worn: other active items, fewest wears first, skipping any
  ///   already shown as most worn.
  /// - Cost per wear: owned items with a price above 0, highest first.
  factory WardrobeStats.compute({
    required List<Item> items,
    required List<WearEntry> entries,
    required DateTime today,
    int topN = 5,
    int notWornDays = 90,
    int recentDays = 30,
  }) {
    final t = dateOnly(today);
    final cutoff = DateTime(t.year, t.month, t.day - notWornDays);
    final recentCutoff = DateTime(t.year, t.month, t.day - recentDays);
    final stats = itemWearStats(items, entries);

    final owned = stats.values
        .where((s) => s.item.status != ItemStatus.wishlist)
        .toList();
    final active =
        owned.where((s) => s.item.status == ItemStatus.active).toList();

    final mostWorn = owned.where((s) => s.timesWorn > 0).toList()
      ..sort(_byWearsDesc);
    final topWorn = mostWorn.take(topN).toList();

    bool isNotWorn(ItemWearStats s) {
      final last = s.lastWornOn;
      if (last != null) return last.isBefore(cutoff);
      final added = s.item.createdAt;
      return added != null && dateOnly(added).isBefore(cutoff);
    }

    final notWorn = active.where(isNotWorn).toList()..sort(_byLastWornAsc);

    final shown = {
      for (final s in [...topWorn, ...notWorn]) s.item.id
    };
    final leastWorn = active.where((s) => !shown.contains(s.item.id)).toList()
      ..sort((a, b) {
        final byWears = a.timesWorn.compareTo(b.timesWorn);
        return byWears != 0 ? byWears : _byLastWornAsc(a, b);
      });

    final costPerWear = owned.where((s) => s.costPerWearCents != null).toList()
      ..sort((a, b) {
        final byCost = b.costPerWearCents!.compareTo(a.costPerWearCents!);
        return byCost != 0 ? byCost : _byName(a, b);
      });

    return WardrobeStats._(
      totalWearDays: {for (final e in entries) e.wornOn}.length,
      activeCount: active.length,
      activeWornRecently: active
          .where((s) =>
              s.lastWornOn != null && !s.lastWornOn!.isBefore(recentCutoff))
          .length,
      mostWorn: topWorn,
      leastWorn: leastWorn.take(topN).toList(),
      notWorn: notWorn,
      costPerWear: costPerWear,
    );
  }

  /// Distinct days with at least one wear logged.
  final int totalWearDays;

  /// Items in rotation.
  final int activeCount;

  /// Active items worn in the recent window (30 days by default).
  final int activeWornRecently;

  final List<ItemWearStats> mostWorn;
  final List<ItemWearStats> leastWorn;
  final List<ItemWearStats> notWorn;
  final List<ItemWearStats> costPerWear;
}

int _byName(ItemWearStats a, ItemWearStats b) =>
    a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());

int _byWearsDesc(ItemWearStats a, ItemWearStats b) {
  final byWears = b.timesWorn.compareTo(a.timesWorn);
  return byWears != 0 ? byWears : _byName(a, b);
}

/// Never worn first, then longest ago.
int _byLastWornAsc(ItemWearStats a, ItemWearStats b) {
  final la = a.lastWornOn, lb = b.lastWornOn;
  if (la == null && lb == null) return _byName(a, b);
  if (la == null) return -1;
  if (lb == null) return 1;
  final byDate = la.compareTo(lb);
  return byDate != 0 ? byDate : _byName(a, b);
}
