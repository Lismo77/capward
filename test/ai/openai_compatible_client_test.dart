import 'dart:convert';

import 'package:gansey/ai/ai_client.dart';
import 'package:gansey/ai/openai_compatible_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenAiCompatibleClient', () {
    test('posts to /chat/completions with system message first', () async {
      late http.Request sent;
      final mock = MockClient((req) async {
        sent = req;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'Hi there'}
              }
            ],
          }),
          200,
        );
      });
      final client = OpenAiCompatibleClient(
        baseUrl: 'https://openrouter.ai/api/v1',
        apiKey: 'k',
        model: 'some/model',
        httpClient: mock,
      );

      final reply = await client.complete(
          system: 'sys',
          messages: const [AiMessage(role: AiRole.user, text: 'hello')]);

      expect(reply, 'Hi there');
      expect(
          sent.url.toString(), 'https://openrouter.ai/api/v1/chat/completions');
      expect(sent.headers['authorization'], 'Bearer k');
      final messages = (jsonDecode(sent.body) as Map)['messages'] as List;
      expect(messages.first, {'role': 'system', 'content': 'sys'});
      expect(messages.last, {'role': 'user', 'content': 'hello'});
    });

    test('images become data URLs', () {
      final client = OpenAiCompatibleClient(
          baseUrl: 'http://localhost:11434/v1', apiKey: '', model: 'llava');
      final body = client.buildBody(system: 's', messages: const [
        AiMessage(
          role: AiRole.user,
          text: 'Tag this',
          images: [AiImage(mediaType: 'image/png', base64Data: 'QUJD')],
        ),
      ]);
      final content =
          ((body['messages'] as List).last as Map)['content'] as List;
      expect(content.last['image_url']['url'], 'data:image/png;base64,QUJD');
    });

    test('no Authorization header when the key is empty (local servers)', () {
      final client = OpenAiCompatibleClient(
          baseUrl: 'http://localhost:11434/v1', apiKey: '', model: 'llama3');
      expect(client.buildHeaders().containsKey('authorization'), isFalse);
    });
  });
}
