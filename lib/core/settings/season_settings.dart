import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/wardrobe/domain/item.dart';

/// Whether the user lives in the southern hemisphere, which flips the
/// seasons. Stored on the device; defaults to northern.
class SouthernHemisphereNotifier extends AsyncNotifier<bool> {
  static const _key = 'southern_hemisphere';

  @override
  Future<bool> build() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  Future<void> set(bool southern) async {
    await (await SharedPreferences.getInstance()).setBool(_key, southern);
    state = AsyncData(southern);
  }
}

final southernHemisphereProvider =
    AsyncNotifierProvider<SouthernHemisphereNotifier, bool>(
        SouthernHemisphereNotifier.new);

/// Today's season, used to pick in-season uniform options.
final currentSeasonProvider = Provider<Season>((ref) {
  final southern = ref.watch(southernHemisphereProvider).valueOrNull ?? false;
  return Season.on(DateTime.now(), southernHemisphere: southern);
});
