import 'package:capsule_wardrobe/ai/ai_client.dart';
import 'package:capsule_wardrobe/features/coach/data/coach_chat.dart';
import 'package:capsule_wardrobe/features/style_profile/data/style_profile_repository.dart';
import 'package:capsule_wardrobe/features/style_profile/domain/style_profile.dart';
import 'package:capsule_wardrobe/features/wardrobe/data/item_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Replies "reply N", or throws when [fail] is set.
class _FakeClient implements AiClient {
  var calls = 0;
  var fail = false;

  @override
  Future<String> complete({
    required String system,
    required List<AiMessage> messages,
    int maxTokens = 16000,
  }) async {
    if (fail) throw const AiException('offline');
    return 'reply ${++calls}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ProviderContainer container;
  late _FakeClient client;

  setUp(() {
    container = ProviderContainer(overrides: [
      itemsProvider.overrideWith((ref) async => const []),
      styleProfileProvider.overrideWith((ref) async => const StyleProfile()),
    ]);
    client = _FakeClient();
  });

  tearDown(() => container.dispose());

  List<String> texts() =>
      container.read(coachChatProvider).messages.map((m) => m.text).toList();

  test('keeps the conversation in the provider, not the screen', () async {
    final chat = container.read(coachChatProvider.notifier);
    await chat.send(client, 'hi');
    await chat.send(client, 'and?');
    expect(texts(), ['hi', 'reply 1', 'and?', 'reply 2']);
    expect(container.read(coachChatProvider).sending, isFalse);

    chat.clear();
    expect(texts(), isEmpty);
  });

  test('a failed send removes the unanswered message and rethrows', () async {
    final chat = container.read(coachChatProvider.notifier);
    await chat.send(client, 'hi');
    client.fail = true;
    await expectLater(chat.send(client, 'again'), throwsA(isA<AiException>()));
    expect(texts(), ['hi', 'reply 1']);
    expect(container.read(coachChatProvider).sending, isFalse);
  });
}
