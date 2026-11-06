import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ai/ai_client.dart';
import '../../../ai/ai_config.dart';
import '../../../ai/ai_providers.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _apiKey = TextEditingController();
  late AiSettings _initial;
  late String _presetId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initial = ref.read(aiSettingsProvider).valueOrNull ?? AiSettings.defaults;
    _presetId = _initial.presetId;
    _baseUrl.text = _initial.baseUrl;
    _model.text = _initial.model;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  AiPreset get _preset => aiPresetById(_presetId);

  void _choosePreset(String? id) {
    if (id == null) return;
    final p = aiPresetById(id);
    setState(() {
      _presetId = id;
      _baseUrl.text = p.baseUrl;
      _model.text = p.suggestedModel ?? '';
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await ref.read(aiSettingsProvider.notifier).save(
          _initial.copyWith(
            presetId: _presetId,
            baseUrl: _baseUrl.text.trim(),
            model: _model.text.trim(),
          ),
          newApiKey: _apiKey.text.trim(),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('AI settings saved')));
    context.pop();
  }

  Future<void> _clearKey() async {
    await ref.read(aiSettingsProvider.notifier).save(_initial, clearKey: true);
    if (!mounted) return;
    setState(() => _initial = _initial.copyWith(hasApiKey: false));
  }

  /// Sends a tiny request with the values currently in the form (not the
  /// saved ones), so users can check before saving.
  Future<void> _test() async {
    setState(() => _busy = true);
    final repo = await ref.read(aiSettingsRepositoryProvider.future);
    final typedKey = _apiKey.text.trim();
    final key = typedKey.isNotEmpty ? typedKey : await repo.readApiKey() ?? '';
    final client = createAiClient(
      format: _preset.format,
      baseUrl: _baseUrl.text.trim(),
      apiKey: key,
      model: _model.text.trim(),
    );
    String result;
    try {
      final reply = await client.complete(
        system: 'You are checking that an API connection works.',
        messages: const [
          AiMessage(role: AiRole.user, text: 'Reply with just the word OK.'),
        ],
        maxTokens: 2048,
      );
      result = 'Connected. The model replied: ${reply.trim()}';
    } catch (e) {
      result = 'Connection failed: $e';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKey = _initial.hasApiKey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI provider'),
        actions: [
          TextButton(
              onPressed: _busy ? null : _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (kIsWeb) const _WebNote(),
          DropdownButtonFormField<String>(
            initialValue: _presetId,
            decoration: const InputDecoration(labelText: 'Provider'),
            items: [
              for (final p in aiPresets)
                DropdownMenuItem(value: p.id, child: Text(p.label)),
            ],
            onChanged: _choosePreset,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Base URL',
              helperText: _preset.hint,
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: 'Model',
              helperText: "Use the provider's exact model name. Photo "
                  'features need a model that can read images.',
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKey,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'API key',
              helperText: hasKey
                  ? 'A key is saved. Leave blank to keep it.'
                  : _preset.needsKey
                      ? 'Required for this provider.'
                      : 'Usually not needed for this provider.',
              suffixIcon: hasKey
                  ? IconButton(
                      tooltip: 'Remove saved key',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _busy ? null : _clearKey,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _busy ? null : _test,
            icon: const Icon(Icons.network_check),
            label: const Text('Test connection'),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Requests go straight from this device to the provider you '
                'choose. There is no app server in between. Your key is '
                "stored in Android's encrypted keystore. The coach sends "
                'your style profile and a text list of your items. Photos '
                'are only sent when you ask the AI to tag a photo.\n\n'
                'Usage is billed by the provider to your account.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Browser limits worth knowing before entering a key.
class _WebNote extends StatelessWidget {
  const _WebNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: theme.colorScheme.surfaceContainerHigh,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Web version: your key is stored in this browser, which is less '
          'protected than the Android app. Use a key with a spending limit. '
          'Some providers block requests from browsers, and a self-hosted '
          'server needs HTTPS and must allow this site (for Ollama, set '
          'OLLAMA_ORIGINS).',
        ),
      ),
    );
  }
}
