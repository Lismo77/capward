/// Provider-neutral AI interface. The rest of the app only talks to this;
/// each provider format gets its own adapter (see anthropic_client.dart and
/// openai_compatible_client.dart).
library;

enum AiRole { user, assistant }

class AiImage {
  const AiImage({required this.mediaType, required this.base64Data});

  /// e.g. 'image/jpeg'
  final String mediaType;
  final String base64Data;
}

class AiMessage {
  const AiMessage({
    required this.role,
    required this.text,
    this.images = const [],
  });

  final AiRole role;
  final String text;
  final List<AiImage> images;
}

class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AiClient {
  /// Sends a conversation and returns the model's text reply.
  /// Throws [AiException] on HTTP errors, refusals or empty replies.
  Future<String> complete({
    required String system,
    required List<AiMessage> messages,
    int maxTokens = 16000,
  });
}

/// Pulls a readable message out of a provider's JSON error body. Both
/// Anthropic and OpenAI-style APIs use `{"error": {"message": ...}}`.
String describeHttpError(int statusCode, Object? decodedBody) {
  if (decodedBody is Map && decodedBody['error'] is Map) {
    final message = (decodedBody['error'] as Map)['message'];
    if (message is String && message.isNotEmpty) {
      return 'AI provider error ($statusCode): $message';
    }
  }
  return switch (statusCode) {
    401 || 403 => 'The AI provider rejected the API key ($statusCode).',
    404 => 'Not found (404) - check the base URL and model name.',
    429 => 'Rate limited or out of credit (429). Try again later.',
    _ => 'AI provider error ($statusCode).',
  };
}

String trimTrailingSlash(String url) =>
    url.endsWith('/') ? url.substring(0, url.length - 1) : url;
