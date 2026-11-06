import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'ai_client.dart';

/// Claude via the Anthropic Messages API (raw HTTP - there is no official
/// Dart SDK).
class AnthropicClient implements AiClient {
  AnthropicClient({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  static const apiVersion = '2026-10-21';

  /// Models that accept server-side refusal fallbacks. On these, if a safety
  /// classifier declines, the API retries on a suitable model in the same
  /// call instead of just stopping.
  static const _fallbackModels = {
    'claude-fable-5-1',
    'claude-opus-5-5',
    'claude-opus-5',
    'claude-sonnet-5-5',
  };
  static const _fallbackBeta = 'server-side-fallback-2026-07-01';

  final String baseUrl;
  final String apiKey;
  final String model;
  final http.Client _http;

  bool get _usesFallbacks => _fallbackModels.contains(model);

  Map<String, String> buildHeaders() => {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': apiVersion,
        if (_usesFallbacks) 'anthropic-beta': _fallbackBeta,
        // Anthropic rejects browser (CORS) requests without this opt-in. The
        // user's own key is already on their own device, so it's fine here.
        if (kIsWeb) 'anthropic-dangerous-direct-browser-access': 'true',
      };

  Map<String, Object?> buildBody({
    required String system,
    required List<AiMessage> messages,
    required int maxTokens,
  }) =>
      {
        'model': model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          for (final m in messages)
            {
              'role': m.role.name,
              'content': [
                // Images go before the text that refers to them.
                for (final img in m.images)
                  {
                    'type': 'image',
                    'source': {
                      'type': 'base64',
                      'media_type': img.mediaType,
                      'data': img.base64Data,
                    },
                  },
                {'type': 'text', 'text': m.text},
              ],
            },
        ],
        if (_usesFallbacks) 'fallbacks': 'default',
      };

  @override
  Future<String> complete({
    required String system,
    required List<AiMessage> messages,
    int maxTokens = 16000,
  }) async {
    final response = await _http
        .post(
          Uri.parse('${trimTrailingSlash(baseUrl)}/v1/messages'),
          headers: buildHeaders(),
          body: jsonEncode(buildBody(
            system: system,
            messages: messages,
            maxTokens: maxTokens,
          )),
        )
        .timeout(const Duration(minutes: 3));

    final decoded = _tryDecode(response.body);
    if (response.statusCode != 200) {
      throw AiException(describeHttpError(response.statusCode, decoded));
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AiException('Unexpected response from the AI provider.');
    }
    return parseResponse(decoded);
  }

  /// Joins the text blocks of a Messages API response. Thinking and other
  /// block types are skipped.
  static String parseResponse(Map<String, dynamic> json) {
    if (json['stop_reason'] == 'refusal') {
      throw const AiException('The model declined to answer this request.');
    }
    final content = json['content'];
    final text = content is List
        ? content
            .whereType<Map>()
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'] as String? ?? '')
            .join()
        : '';
    if (text.trim().isEmpty) {
      throw const AiException('The AI provider returned an empty reply.');
    }
    return text;
  }
}

Object? _tryDecode(String body) {
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}
