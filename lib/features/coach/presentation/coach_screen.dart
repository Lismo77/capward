import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ai/ai_client.dart';
import '../../../ai/ai_providers.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/coach_chat.dart';

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
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || ref.read(coachChatProvider).sending) return;

    final client = await ref.read(aiClientProvider.future);
    if (!mounted) return;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Finish setting up your AI provider in Settings.')));
      return;
    }

    _input.clear();
    try {
      await ref.read(coachChatProvider.notifier).send(client, text);
    } catch (e) {
      if (!mounted) return;
      // Give the text back for a retry.
      _input.text = text;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiSettingsProvider).valueOrNull;
    final chat = ref.watch(coachChatProvider);
    final messages = chat.messages;
    final sending = chat.sending;

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
          if (messages.isNotEmpty)
            IconButton(
              tooltip: 'New conversation',
              icon: const Icon(Icons.refresh),
              onPressed: sending
                  ? null
                  : () => ref.read(coachChatProvider.notifier).clear(),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _Intro(onPick: (p) => _input.text = p)
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) => _Bubble(message: messages[i]),
                  ),
          ),
          if (sending) const LinearProgressIndicator(),
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
                    onPressed: sending ? null : _send,
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
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        decoration: BoxDecoration(
          color:
              isUser ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(message.text),
      ),
    );
  }
}
