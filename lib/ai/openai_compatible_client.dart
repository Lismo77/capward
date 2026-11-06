import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_client.dart';

/// Any provider that speaks the OpenAI "chat completions" format: OpenAI,
/// OpenRouter, Google Gemini (OpenAI endpoint), Mistral, Groq, and
/// self-hosted servers like Ollama or llama.cpp.
class OpenAiCompatibleClient implements AiClient {
  OpenAiCompatibleClient({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;

  /// May be empty for local servers that don't need a key.
  final String apiKey;
  final String model;
  final http.Client _http;

  Map<String, String> buildHeaders() => {
        'content-type': 'application/json',
        if (apiKey.isNotEmpty) 'authorization': 'Bearer $apiKey',
      };

  /// No token limit is sent: providers disagree on the field name
  /// (`max_tokens` vs `max_completion_tokens`) and some reject the wrong one.
  Map<String, Object?> buildBody({
    required String system,
    required List<AiMessage> messages,
  }) =>
      {
        'model': model,
        'messages': [
          {'role': 'system', 'content': system},
          for (final m in messages)
            if (m.images.isEmpty)
              {'role': m.role.name, 'content': m.text}
            else
              {
                'role': m.role.name,
                'content': [
                  {'type': 'text', 'text': m.text},
                  for (final img in m.images)
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:${img.mediaType};base64,${img.base64Data}',
                      },
                    },
                ],
              },
        ],
      };

  @override
  Future<String> complete({
    required String system,
    required List<AiMessage> messages,
    int maxTokens = 16000,
  }) async {
    final response = await _http
        .post(
          Uri.parse('${trimTrailingSlash(baseUrl)}/chat/completions'),
          headers: buildHeaders(),
          body: jsonEncode(buildBody(system: system, messages: messages)),
        )
        .timeout(const Duration(minutes: 3));

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode != 200) {
      throw AiException(describeHttpError(response.statusCode, decoded));
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AiException('Unexpected response from the AI provider.');
    }
    return parseResponse(decoded);
  }

  static String parseResponse(Map<String, dynamic> json) {
    final choices = json['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final message = (choices.first as Map)['message'];
      if (message is Map) {
        final content = message['content'];
        if (content is String && content.trim().isNotEmpty) return content;
      }
    }
    throw const AiException('The AI provider returned an empty reply.');
  }
}
