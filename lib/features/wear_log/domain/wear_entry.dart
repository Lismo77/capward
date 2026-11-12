import '../../../core/format.dart';
import '../../outfits/domain/outfit.dart';

/// One "I wore this" record: a day, the pieces worn, and the outfit they came
/// from (if any). Item ids are copied at logging time, so editing the outfit
/// later doesn't rewrite history.
class WearEntry {
  WearEntry({
    this.id,
    required DateTime wornOn,
    this.wornAt,
    this.outfitId,
    required this.itemIds,
    this.notes,
  }) : wornOn = dateOnly(wornOn);

  /// An entry for right now, with the time recorded.
  factory WearEntry.now({
    int? outfitId,
    required List<int> itemIds,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    return WearEntry(
        wornOn: t, wornAt: t, outfitId: outfitId, itemIds: itemIds);
  }

  final int? id;
  final DateTime wornOn;

  /// When it was put on. Null for entries logged before times were kept.
  final DateTime? wornAt;
  final int? outfitId;
  final List<int> itemIds;
  final String? notes;

  Map<String, Object?> toRow() => {
        'worn_on': isoDate(wornOn),
        'worn_at': wornAt?.toIso8601String(),
        'outfit_id': outfitId,
        'notes': notes,
      };

  factory WearEntry.fromRow(Map<String, Object?> row, List<int> itemIds) =>
      WearEntry(
        id: row['id'] as int?,
        wornOn: DateTime.parse(row['worn_on'] as String),
        wornAt: DateTime.tryParse(row['worn_at'] as String? ?? ''),
        outfitId: row['outfit_id'] as int?,
        itemIds: itemIds,
        notes: row['notes'] as String?,
      );
}

/// Later entries sort after earlier ones. Untimed entries count as the start
/// of their day; ties fall back to id (insertion order).
int compareWearTime(WearEntry a, WearEntry b) {
  final byTime = (a.wornAt ?? a.wornOn).compareTo(b.wornAt ?? b.wornOn);
  return byTime != 0 ? byTime : (a.id ?? 0).compareTo(b.id ?? 0);
}

/// What's being worn: the last wear logged today, from a saved outfit or
/// from loose pieces. Wearing another outfit replaces it; pieces added
/// during the day go into it ([addableItems]). Null if nothing is logged
/// today.
WearEntry? currentWear(Iterable<WearEntry> entries, DateTime now) {
  final today = dateOnly(now);
  WearEntry? latest;
  for (final e in entries) {
    if (e.wornOn != today) continue;
    if (latest == null || compareWearTime(e, latest) > 0) latest = e;
  }
  return latest;
}

/// The ones of [itemIds] not already in [wear], in order and without
/// repeats: what "add to today's outfit" would actually add.
List<int> addableItems(WearEntry wear, Iterable<int> itemIds) {
  final have = wear.itemIds.toSet();
  return [
    for (final id in itemIds)
      if (have.add(id)) id,
  ];
}

/// True when every one of [itemIds] is already logged on [day], so logging
/// again would only add a duplicate.
bool alreadyLogged(
  Iterable<WearEntry> entries,
  Iterable<int> itemIds,
  DateTime day,
) {
  final d = dateOnly(day);
  final worn = {
    for (final e in entries)
      if (e.wornOn == d) ...e.itemIds,
  };
  return itemIds.isNotEmpty && itemIds.every(worn.contains);
}

/// Number of distinct days the outfit was logged.
int outfitWearCount(Iterable<WearEntry> entries, int outfitId) => {
      for (final e in entries)
        if (e.outfitId == outfitId) e.wornOn
    }.length;

/// The last day the outfit was logged, or null.
DateTime? lastWornOn(Iterable<WearEntry> entries, int outfitId) {
  DateTime? last;
  for (final e in entries) {
    if (e.outfitId != outfitId) continue;
    if (last == null || e.wornOn.isAfter(last)) last = e.wornOn;
  }
  return last;
}

/// Most worn first; ties go to the one worn most recently, then by name.
List<Outfit> sortByMostWorn(
  Iterable<Outfit> outfits,
  Iterable<WearEntry> entries,
) {
  final count = <int, Set<DateTime>>{};
  final last = <int, DateTime>{};
  for (final e in entries) {
    final id = e.outfitId;
    if (id == null) continue;
    count.putIfAbsent(id, () => {}).add(e.wornOn);
    if (!(last[id]?.isAfter(e.wornOn) ?? false)) last[id] = e.wornOn;
  }
  final epoch = DateTime(0);
  return outfits.toList()
    ..sort((a, b) {
      final byCount =
          (count[b.id]?.length ?? 0).compareTo(count[a.id]?.length ?? 0);
      if (byCount != 0) return byCount;
      final byLast = (last[b.id] ?? epoch).compareTo(last[a.id] ?? epoch);
      if (byLast != 0) return byLast;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
}
