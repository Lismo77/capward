import 'dart:convert';

import 'package:gansey/ai/ai_client.dart';
import 'package:gansey/ai/anthropic_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AnthropicClient', () {
    test('sends required headers, system prompt, and images before text',
        () async {
      late http.Request sent;
      final mock = MockClient((req) async {
        sent = req;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'thinking', 'thinking': ''},
              {'type': 'text', 'text': 'Hello'},
            ],
            'stop_reason': 'end_turn',
          }),
          200,
        );
      });
      final client = AnthropicClient(
        baseUrl: 'https://api.anthropic.com/',
        apiKey: 'test-key',
        model: 'claude-opus-5-5',
        httpClient: mock,
      );

      final reply = await client.complete(system: 'sys', messages: const [
        AiMessage(
          role: AiRole.user,
          text: 'What is this?',
          images: [AiImage(mediaType: 'image/jpeg', base64Data: 'AAAA')],
        ),
      ]);

      expect(reply, 'Hello');
      expect(sent.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(sent.headers['x-api-key'], 'test-key');
      expect(sent.headers['anthropic-version'], AnthropicClient.apiVersion);

      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['model'], 'claude-opus-5-5');
      expect(body['system'], 'sys');
      expect(body['fallbacks'], 'default');
      final content = (body['messages'] as List).first['content'] as List;
      expect(content.first['type'], 'image');
      expect(content.first['source']['media_type'], 'image/jpeg');
      expect(content.last, {'type': 'text', 'text': 'What is this?'});
    });

    test('does not send fallbacks for models that do not support them', () {
      final client = AnthropicClient(
          baseUrl: 'https://api.anthropic.com',
          apiKey: 'k',
          model: 'claude-haiku-5-5');
      final body = client.buildBody(
          system: 's',
          messages: const [AiMessage(role: AiRole.user, text: 'hi')],
          maxTokens: 100);
      expect(body.containsKey('fallbacks'), isFalse);
      expect(client.buildHeaders().containsKey('anthropic-beta'), isFalse);
    });

    test('a refusal becomes an AiException', () {
      expect(
        () => AnthropicClient.parseResponse({
          'content': <Object>[],
          'stop_reason': 'refusal',
        }),
        throwsA(isA<AiException>()),
      );
    });

    test('HTTP errors surface the provider message', () async {
      final mock = MockClient((_) async => http.Response(
            jsonEncode({
              'type': 'error',
              'error': {
                'type': 'not_found_error',
                'message': 'model: no-such-model'
              },
            }),
            404,
          ));
      final client = AnthropicClient(
          baseUrl: 'https://api.anthropic.com',
          apiKey: 'k',
          model: 'no-such-model',
          httpClient: mock);

      expect(
        client.complete(
            system: 's',
            messages: const [AiMessage(role: AiRole.user, text: 'hi')]),
        throwsA(isA<AiException>()
            .having((e) => e.message, 'message', contains('no-such-model'))),
      );
    });
  });
}
