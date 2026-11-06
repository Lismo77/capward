import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ai/ai_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/dev/sample_data.dart';
import '../../outfits/data/outfit_repository.dart';
import '../../style_profile/data/style_profile_repository.dart';
import '../../wardrobe/data/item_repository.dart';
import '../../wear_log/data/wear_log_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _loadSample(BuildContext context, WidgetRef ref) async {
    final db = await ref.read(databaseProvider.future);
    final count = await SampleData.loadWardrobe(db);
    ref.invalidate(itemsProvider);
    ref.invalidate(styleProfileProvider);
    ref.invalidate(outfitsProvider);
    ref.invalidate(wearLogProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Loaded $count sample items')));
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all wardrobe data?'),
        content: const Text('Removes every item, outfit, capsule and wear '
            'log entry, and clears the style profile. AI settings are kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final db = await ref.read(databaseProvider.future);
    await SampleData.clearAll(db);
    ref.invalidate(itemsProvider);
    ref.invalidate(styleProfileProvider);
    ref.invalidate(outfitsProvider);
    ref.invalidate(wearLogProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All wardrobe data deleted')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ai = ref.watch(aiSettingsProvider);
    final settings = ai.valueOrNull;
    final enabled = settings?.enabled ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _Header('Your style'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Style profile'),
            subtitle:
                const Text('Colours, shapes and words that define your look'),
            onTap: () => context.push('/settings/style'),
          ),
          const _Header('AI style coach'),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Use AI features'),
            subtitle: const Text(
                'Optional. Uses your own API key. Nothing is sent to an AI '
                'provider while this is off.'),
            value: enabled,
            onChanged: ai.isLoading
                ? null
                : (v) => ref.read(aiSettingsProvider.notifier).setEnabled(v),
          ),
          ListTile(
            enabled: enabled,
            leading: const Icon(Icons.key_outlined),
            title: const Text('AI provider'),
            subtitle: Text(settings?.summary ?? 'Not set up yet'),
            onTap: () => context.push('/settings/ai'),
          ),
          if (kDebugMode) ...[
            const _Header('Developer (debug builds only)'),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Load sample wardrobe'),
              subtitle: const Text('Adds a test capsule. Replaces earlier '
                  'sample items and keeps your own.'),
              onTap: () => _loadSample(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('Delete all wardrobe data'),
              onTap: () => _clearAll(context, ref),
            ),
          ],
          const _Header('About'),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'Capward',
            applicationVersion: '0.1.0',
            applicationLegalese:
                'Free software under the GNU General Public License v3. '
                'No ads, no tracking.',
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(text,
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}
