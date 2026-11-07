import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/settings/season_settings.dart';
import '../../wardrobe/data/item_repository.dart';
import '../../wardrobe/domain/item.dart';
import '../../wear_log/data/wear_log_repository.dart';
import '../domain/outfit.dart';
import '../domain/uniform.dart';
import 'outfit_repository.dart';

typedef ShuffledPick = ({DateTime day, List<int> itemIds});

/// Uniform picks rerolled with "Shuffle", by outfit id. Kept in memory only
/// and ignored once the day changes.
class ShuffledPicksNotifier extends Notifier<Map<int, ShuffledPick>> {
  final _random = Random();

  @override
  Map<int, ShuffledPick> build() => const {};

  void shuffle(Outfit outfit) {
    final items = ref.read(itemsProvider).valueOrNull ?? const <Item>[];
    final pick = shufflePick(
      outfit,
      {for (final i in items) i.id!: i},
      ref.read(currentSeasonProvider),
      _random,
      current: ref.read(todaysPiecesProvider(outfit.id!)),
    );
    state = {
      ...state,
      outfit.id!: (day: dateOnly(DateTime.now()), itemIds: pick),
    };
  }
}

final shuffledPicksProvider =
    NotifierProvider<ShuffledPicksNotifier, Map<int, ShuffledPick>>(
        ShuffledPicksNotifier.new);

/// The pieces to show and log for a saved outfit today (see
/// [piecesForToday]). Empty while loading or if the outfit is gone.
final todaysPiecesProvider = Provider.family<List<int>, int>((ref, outfitId) {
  final outfit = ref
      .watch(outfitsProvider)
      .valueOrNull
      ?.where((o) => o.id == outfitId)
      .firstOrNull;
  if (outfit == null) return const [];
  final items = ref.watch(itemsProvider).valueOrNull ?? const <Item>[];
  final entries = ref.watch(wearLogProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  final shuffled = ref.watch(shuffledPicksProvider)[outfitId];
  return piecesForToday(
    outfit,
    byId: {for (final i in items) i.id!: i},
    entries: entries,
    now: now,
    season: ref.watch(currentSeasonProvider),
    shuffled: shuffled != null && shuffled.day == dateOnly(now)
        ? shuffled.itemIds
        : null,
  );
});
