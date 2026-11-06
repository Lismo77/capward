import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_config.dart';

/// Plain settings live in shared preferences. The API key lives in secure
/// storage (Android Keystore-backed) and is never written anywhere else.
class AiSettingsRepository {
  AiSettingsRepository(this._prefs, this._secure);

  static const _kEnabled = 'ai.enabled';
  static const _kPreset = 'ai.preset';
  static const _kBaseUrl = 'ai.baseUrl';
  static const _kModel = 'ai.model';
  static const _kApiKey = 'ai.apiKey';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<AiSettings> load() async {
    const d = AiSettings.defaults;
    final key = await readApiKey();
    return AiSettings(
      enabled: _prefs.getBool(_kEnabled) ?? d.enabled,
      presetId: _prefs.getString(_kPreset) ?? d.presetId,
      baseUrl: _prefs.getString(_kBaseUrl) ?? d.baseUrl,
      model: _prefs.getString(_kModel) ?? d.model,
      hasApiKey: key != null && key.isNotEmpty,
    );
  }

  Future<void> save(AiSettings s) async {
    await _prefs.setBool(_kEnabled, s.enabled);
    await _prefs.setString(_kPreset, s.presetId);
    await _prefs.setString(_kBaseUrl, s.baseUrl);
    await _prefs.setString(_kModel, s.model);
  }

  Future<String?> readApiKey() => _secure.read(key: _kApiKey);

  Future<void> writeApiKey(String? key) async {
    if (key == null || key.isEmpty) {
      await _secure.delete(key: _kApiKey);
    } else {
      await _secure.write(key: _kApiKey, value: key);
    }
  }
}
