import 'package:shared_preferences/shared_preferences.dart';

import '../secrets/secret_store.dart';
import 'ai_models.dart';

const _kApiKey = 'ai_api_key';
const _kBaseUrl = 'ai_base_url';
const _kModel = 'ai_model';

/// Persists AI prefs + API key via [SecretStore].
class AiCredentialsStore {
  AiCredentialsStore({SecretStore? secretStore})
      : _secrets = secretStore ?? PrefsSecretStore();

  final SecretStore _secrets;

  Future<AiProviderConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _secrets.read(_kApiKey) ?? '';
    final baseUrl =
        prefs.getString(_kBaseUrl) ?? 'https://api.openai.com/v1';
    final model = prefs.getString(_kModel) ?? 'gpt-4o-mini';
    return AiProviderConfig(baseUrl: baseUrl, apiKey: key, model: model);
  }

  Future<void> save(AiProviderConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, config.baseUrl.trim());
    await prefs.setString(_kModel, config.model.trim());
    await _secrets.write(_kApiKey, config.apiKey.trim());
  }
}
