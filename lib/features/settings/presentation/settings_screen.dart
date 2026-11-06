import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ai/ai_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
            subtitle: const Text('Colours, shapes and words that define your look'),
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
