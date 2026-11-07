import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/ai_client.dart';
import '../../style_profile/data/style_profile_repository.dart';
import '../../wardrobe/data/item_repository.dart';
import '../domain/coach_prompt.dart';

class CoachChat {
  const CoachChat({this.messages = const [], this.sending = false});

  final List<AiMessage> messages;

  /// Waiting for a reply.
  final bool sending;
}

/// The coach conversation. Lives outside the screen so it survives switching
/// tabs, and a reply still lands if the screen is gone. Kept in memory only:
/// it's cleared when the app closes.
class CoachChatNotifier extends Notifier<CoachChat> {
  @override
  CoachChat build() => const CoachChat();

  void clear() {
    if (!state.sending) state = const CoachChat();
  }

  /// Sends [text] with the style profile and wardrobe as context. On failure
  /// the unanswered message is removed (so turns stay user/assistant) and
  /// the error is rethrown.
  Future<void> send(AiClient client, String text) async {
    if (state.sending) return;
    final messages = [
      ...state.messages,
      AiMessage(role: AiRole.user, text: text),
    ];
    state = CoachChat(messages: messages, sending: true);
    try {
      final items = await ref.read(itemsProvider.future);
      final profile = await ref.read(styleProfileProvider.future);
      final reply = await client.complete(
        system: buildCoachSystemPrompt(profile: profile, items: items),
        messages: messages,
      );
      state = CoachChat(messages: [
        ...messages,
        AiMessage(role: AiRole.assistant, text: reply),
      ]);
    } catch (_) {
      state = CoachChat(messages: messages.sublist(0, messages.length - 1));
      rethrow;
    }
  }
}

final coachChatProvider =
    NotifierProvider<CoachChatNotifier, CoachChat>(CoachChatNotifier.new);
