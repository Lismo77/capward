enum AiApiFormat { openAiCompatible, anthropic }

/// A starting point for the AI settings form. Users can still edit the base
/// URL and model after picking one.
class AiPreset {
  const AiPreset({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.format,
    this.needsKey = true,
    this.suggestedModel,
    this.hint,
  });

  final String id;
  final String label;
  final String baseUrl;
  final AiApiFormat format;
  final bool needsKey;
  final String? suggestedModel;
  final String? hint;
}

const aiPresets = <AiPreset>[
  AiPreset(
    id: 'anthropic',
    label: 'Anthropic (Claude)',
    baseUrl: 'https://api.anthropic.com',
    format: AiApiFormat.anthropic,
    suggestedModel: 'claude-opus-5-5',
  ),
  AiPreset(
    id: 'openai',
    label: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    format: AiApiFormat.openAiCompatible,
  ),
  AiPreset(
    id: 'openrouter',
    label: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    format: AiApiFormat.openAiCompatible,
    hint: 'One key for many models. Model names look like "vendor/model".',
  ),
  AiPreset(
    id: 'gemini',
    label: 'Google Gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    format: AiApiFormat.openAiCompatible,
  ),
  AiPreset(
    id: 'mistral',
    label: 'Mistral',
    baseUrl: 'https://api.mistral.ai/v1',
    format: AiApiFormat.openAiCompatible,
  ),
  AiPreset(
    id: 'groq',
    label: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    format: AiApiFormat.openAiCompatible,
  ),
  AiPreset(
    id: 'ollama',
    label: 'Ollama (self-hosted)',
    baseUrl: 'http://192.168.1.10:11434/v1',
    format: AiApiFormat.openAiCompatible,
    needsKey: false,
    hint: "Use your computer's network address. 'localhost' would mean the "
        'phone itself.',
  ),
  AiPreset(
    id: 'custom',
    label: 'Other (OpenAI-compatible)',
    baseUrl: '',
    format: AiApiFormat.openAiCompatible,
    needsKey: false,
  ),
];

AiPreset aiPresetById(String id) =>
    aiPresets.firstWhere((p) => p.id == id, orElse: () => aiPresets.last);

class AiSettings {
  const AiSettings({
    required this.enabled,
    required this.presetId,
    required this.baseUrl,
    required this.model,
    required this.hasApiKey,
  });

  /// AI is off until the user opts in.
  static const defaults = AiSettings(
    enabled: false,
    presetId: 'anthropic',
    baseUrl: 'https://api.anthropic.com',
    model: 'claude-opus-5-5',
    hasApiKey: false,
  );

  final bool enabled;
  final String presetId;
  final String baseUrl;
  final String model;

  /// Whether a key is stored. The key itself is only read when sending a
  /// request, never kept in app state.
  final bool hasApiKey;

  AiPreset get preset => aiPresetById(presetId);

  bool get isConfigured =>
      baseUrl.isNotEmpty && model.isNotEmpty && (hasApiKey || !preset.needsKey);

  String get summary =>
      isConfigured ? '${preset.label} · $model' : 'Not set up yet';

  AiSettings copyWith({
    bool? enabled,
    String? presetId,
    String? baseUrl,
    String? model,
    bool? hasApiKey,
  }) =>
      AiSettings(
        enabled: enabled ?? this.enabled,
        presetId: presetId ?? this.presetId,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        hasApiKey: hasApiKey ?? this.hasApiKey,
      );
}
