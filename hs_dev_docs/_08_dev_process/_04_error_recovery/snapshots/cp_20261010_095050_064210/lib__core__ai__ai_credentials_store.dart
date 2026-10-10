import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_models.dart';

const _kApiKey = 'ai_api_key';
const _kBaseUrl = 'ai_base_url';
const _kModel = 'ai_model';

/// Persists non-secret AI prefs + API key in secure storage.
class AiCredentialsStore {
  AiCredentialsStore({
    FlutterSecureStorage? secureStorage,
  }) : _secure = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  Future<AiProviderConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _secure.read(key: _kApiKey) ?? '';
    final baseUrl =
        prefs.getString(_kBaseUrl) ?? 'https://api.openai.com/v1';
    final model = prefs.getString(_kModel) ?? 'gpt-4o-mini';
    return AiProviderConfig(baseUrl: baseUrl, apiKey: key, model: model);
  }

  Future<void> save(AiProviderConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, config.baseUrl.trim());
    await prefs.setString(_kModel, config.model.trim());
    await _secure.write(key: _kApiKey, value: config.apiKey.trim());
  }
}
