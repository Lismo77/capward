import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ai/ai_client.dart';
import '../../../ai/ai_providers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../style_profile/data/style_profile_repository.dart';
import '../../wardrobe/data/item_repository.dart';
import '../domain/coach_prompt.dart';

const _starterPrompts = [
  'Suggest an outfit for a casual Friday at the office',
  'What single item would add the most new outfits?',
  'Help me define my personal style',
  'Which of my items look like duplicates?',
];

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _messages = <AiMessage>[];
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    final client = await ref.read(aiClientProvider.future);
    if (!mounted) return;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Finish setting up your AI provider in Settings.')));
      return;
    }

    setState(() {
      _messages.add(AiMessage(role: AiRole.user, text: text));
      _input.clear();
      _sending = true;
    });

    try {
      final items = await ref.read(itemsProvider.future);
      final profile = await ref.read(styleProfileProvider.future);
      final reply = await client.complete(
        system: buildCoachSystemPrompt(profile: profile, items: items),
        messages: List.of(_messages),
      );
      if (!mounted) return;
      setState(() =>
          _messages.add(AiMessage(role: AiRole.assistant, text: reply)));
    } catch (e) {
      if (!mounted) return;
      // Drop the unanswered message so the conversation stays
      // user/assistant/user..., and give the text back for a retry.
      setState(() => _messages.removeLast());
      _input.text = text;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiSettingsProvider).valueOrNull;

    if (settings == null || !settings.enabled || !settings.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text('Style coach')),
        body: EmptyState(
          icon: Icons.auto_awesome_outlined,
          title: 'The AI coach is optional',
          message: 'Connect an AI provider with your own API key to get '
              'outfit ideas, gap analysis and style advice based on your '
              'wardrobe.',
          action: FilledButton(
            onPressed: () => context.push('/settings/ai'),
            child: const Text('Set up AI provider'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Style coach'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'New conversation',
              icon: const Icon(Icons.refresh),
              onPressed: _sending ? null : () => setState(_messages.clear),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _Intro(onPick: (p) => _input.text = p)
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _Bubble(message: _messages[i]),
                  ),
          ),
          if (_sending) const LinearProgressIndicator(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Ask your style coach...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Ask about outfits, gaps or your style.',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Each message sends your style profile and a text list of your '
          'items (no photos) to your chosen AI provider.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in _starterPrompts)
              ActionChip(label: Text(p), onPressed: () => onPick(p)),
          ],
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == AiRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(message.text),
      ),
    );
  }
}
