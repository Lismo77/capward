import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_client.dart';
import 'ai_config.dart';
import 'ai_settings_repository.dart';
import 'anthropic_client.dart';
import 'openai_compatible_client.dart';

final aiSettingsRepositoryProvider =
    FutureProvider<AiSettingsRepository>((ref) async {
  return AiSettingsRepository(
    await SharedPreferences.getInstance(),
    const FlutterSecureStorage(),
  );
});

class AiSettingsNotifier extends AsyncNotifier<AiSettings> {
  @override
  Future<AiSettings> build() async {
    final repo = await ref.watch(aiSettingsRepositoryProvider.future);
    return repo.load();
  }

  /// [newApiKey]: null or empty keeps the stored key. [clearKey] removes it.
  Future<void> save(
    AiSettings settings, {
    String? newApiKey,
    bool clearKey = false,
  }) async {
    final repo = await ref.read(aiSettingsRepositoryProvider.future);
    if (clearKey) {
      await repo.writeApiKey(null);
    } else if (newApiKey != null && newApiKey.isNotEmpty) {
      await repo.writeApiKey(newApiKey);
    }
    await repo.save(settings);
    state = AsyncData(await repo.load());
  }

  Future<void> setEnabled(bool enabled) async {
    final current = state.valueOrNull ?? AiSettings.defaults;
    await save(current.copyWith(enabled: enabled));
  }
}

final aiSettingsProvider =
    AsyncNotifierProvider<AiSettingsNotifier, AiSettings>(
        AiSettingsNotifier.new);

AiClient createAiClient({
  required AiApiFormat format,
  required String baseUrl,
  required String apiKey,
  required String model,
}) =>
    switch (format) {
      AiApiFormat.anthropic =>
        AnthropicClient(baseUrl: baseUrl, apiKey: apiKey, model: model),
      AiApiFormat.openAiCompatible =>
        OpenAiCompatibleClient(baseUrl: baseUrl, apiKey: apiKey, model: model),
    };

/// The configured client, or null when AI is off or not set up. Features
/// must handle null - that's the "no AI" mode, and it is a first-class mode.
final aiClientProvider = FutureProvider<AiClient?>((ref) async {
  final settings = await ref.watch(aiSettingsProvider.future);
  if (!settings.enabled || !settings.isConfigured) return null;
  final repo = await ref.watch(aiSettingsRepositoryProvider.future);
  return createAiClient(
    format: settings.preset.format,
    baseUrl: settings.baseUrl,
    apiKey: await repo.readApiKey() ?? '',
    model: settings.model,
  );
});
