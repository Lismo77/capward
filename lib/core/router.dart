import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ai/ai_providers.dart';
import '../features/capsules/presentation/capsules_screen.dart';
import '../features/coach/presentation/coach_screen.dart';
import '../features/outfits/presentation/outfit_edit_screen.dart';
import '../features/outfits/presentation/outfits_screen.dart';
import '../features/settings/presentation/ai_settings_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/style_profile/presentation/style_profile_screen.dart';
import '../features/wardrobe/presentation/item_edit_screen.dart';
import '../features/wardrobe/presentation/wardrobe_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/wardrobe',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            HomeShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/wardrobe',
            builder: (context, state) => const WardrobeScreen(),
            routes: [
              // 'new' must come before ':id' so it isn't parsed as an id.
              GoRoute(
                path: 'new',
                builder: (context, state) => const ItemEditScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => ItemEditScreen(
                  itemId: int.parse(state.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/outfits',
            builder: (context, state) => const OutfitsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const OutfitEditScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => OutfitEditScreen(
                  outfitId: int.parse(state.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/capsules',
            builder: (context, state) => const CapsulesScreen(),
          ),
          GoRoute(
            path: '/coach',
            builder: (context, state) => const CoachScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'style',
                builder: (context, state) => const StyleProfileScreen(),
              ),
              GoRoute(
                path: 'ai',
                builder: (context, state) => const AiSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _Tab {
  const _Tab(this.path, this.icon, this.label);
  final String path;
  final IconData icon;
  final String label;
}

/// Bottom navigation. The Coach tab only exists when the user has opted in
/// to AI - without it the app is a complete manual wardrobe tracker.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiEnabled =
        ref.watch(aiSettingsProvider).valueOrNull?.enabled ?? false;
    final tabs = <_Tab>[
      const _Tab('/wardrobe', Icons.checkroom_outlined, 'Wardrobe'),
      const _Tab('/outfits', Icons.style_outlined, 'Outfits'),
      const _Tab('/capsules', Icons.inventory_2_outlined, 'Capsules'),
      if (aiEnabled) const _Tab('/coach', Icons.auto_awesome_outlined, 'Coach'),
      const _Tab('/settings', Icons.settings_outlined, 'Settings'),
    ];
    var index = tabs.indexWhere((t) => location.startsWith(t.path));
    if (index < 0) index = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(tabs[i].path),
        destinations: [
          for (final t in tabs)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}
