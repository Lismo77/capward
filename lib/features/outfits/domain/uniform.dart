import 'dart:math';

import '../../../core/format.dart';
import '../../wardrobe/domain/item.dart';
import '../../wear_log/domain/wear_entry.dart';
import 'outfit.dart';

/// Whether [item] can be worn in [season]. No season tags means any season.
bool wearableIn(Item item, Season season) =>
    item.seasons.isEmpty || item.seasons.contains(season);

/// For each option group of [outfit], the options that can be picked: in
/// rotation and in season. A group can come back empty (no layer in summer).
List<List<int>> pickableOptions(
  Outfit outfit,
  Map<int, Item> byId,
  Season season,
) =>
    [
      for (final group in outfit.groups)
        [
          for (final id in group)
            if (byId[id] case final item?
                when item.status == ItemStatus.active &&
                    wearableIn(item, season))
              id,
        ],
    ];

/// The last day each item was worn, from every entry (outfits and loose).
Map<int, DateTime> lastWornByItem(Iterable<WearEntry> entries) {
  final last = <int, DateTime>{};
  for (final e in entries) {
    for (final id in e.itemIds) {
      if (!(last[id]?.isAfter(e.wornOn) ?? false)) last[id] = e.wornOn;
    }
  }
  return last;
}

/// Fixed pieces plus, from each option group, the in-season option worn
/// longest ago. Never-worn options come first; ties keep the group's order.
List<int> leastRecentPick(
  Outfit outfit,
  Map<int, Item> byId,
  Iterable<WearEntry> entries,
  Season season,
) {
  final last = lastWornByItem(entries);
  final chosen = <int>{
    for (final options in pickableOptions(outfit, byId, season))
      if (options.isNotEmpty)
        options.reduce((a, b) {
          final la = last[a];
          final lb = last[b];
          if (la == null) return a;
          if (lb == null) return b;
          return lb.isBefore(la) ? b : a;
        }),
  };
  return _withFixed(outfit, chosen);
}

/// Fixed pieces plus a random in-season option from each group. When a
/// different pick is possible, the result differs from [current].
List<int> shufflePick(
  Outfit outfit,
  Map<int, Item> byId,
  Season season,
  Random random, {
  Iterable<int> current = const [],
}) {
  final groups = pickableOptions(outfit, byId, season);
  final chosen = [
    for (final g in groups) g.isEmpty ? null : g[random.nextInt(g.length)],
  ];
  final previous = current.toSet();
  final unchanged = chosen.every((id) => id == null || previous.contains(id));
  if (unchanged) {
    final changeable = [
      for (var i = 0; i < groups.length; i++)
        if (groups[i].length > 1) i,
    ];
    if (changeable.isNotEmpty) {
      final i = changeable[random.nextInt(changeable.length)];
      final others = groups[i].where((id) => !previous.contains(id)).toList();
      chosen[i] = others[random.nextInt(others.length)];
    }
  }
  return _withFixed(outfit, chosen.whereType<int>().toSet());
}

/// The pieces to show and log for [outfit] today. A plain outfit is all its
/// pieces. A uniform is what was logged for it today, else today's
/// [shuffled] pick, else [leastRecentPick].
List<int> piecesForToday(
  Outfit outfit, {
  required Map<int, Item> byId,
  required Iterable<WearEntry> entries,
  required DateTime now,
  required Season season,
  List<int>? shuffled,
}) {
  if (!outfit.isUniform) return outfit.itemIds;
  final today = dateOnly(now);
  WearEntry? worn;
  for (final e in entries) {
    if (e.outfitId != outfit.id || e.wornOn != today) continue;
    if (worn == null || compareWearTime(e, worn) > 0) worn = e;
  }
  if (worn != null) return worn.itemIds;
  return shuffled ?? leastRecentPick(outfit, byId, entries, season);
}

/// For each option in a uniform, the number of days it was worn as part of
/// that uniform. Options never picked are included with 0.
Map<int, int> optionWearDays(Outfit outfit, Iterable<WearEntry> entries) {
  final days = <int, Set<DateTime>>{
    for (final id in outfit.optionGroups.keys) id: {},
  };
  for (final e in entries) {
    if (e.outfitId != outfit.id) continue;
    for (final id in e.itemIds) {
      days[id]?.add(e.wornOn);
    }
  }
  return days.map((id, d) => MapEntry(id, d.length));
}

List<int> _withFixed(Outfit outfit, Set<int> chosen) => [
      for (final id in outfit.itemIds)
        if (!outfit.optionGroups.containsKey(id) || chosen.contains(id)) id,
    ];
