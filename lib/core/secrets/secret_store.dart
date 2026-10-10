import 'package:shared_preferences/shared_preferences.dart';

/// Small key/value secret seam used for API keys and PATs.
///
/// Desktop MVP stores values in [SharedPreferences] (app-private prefs) so
/// Windows release builds do not require Visual Studio ATL (`atlstr.h`),
/// which `flutter_secure_storage`'s legacy C++ plugin needs.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PrefsSecretStore implements SecretStore {
  PrefsSecretStore({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<String?> read(String key) async {
    final prefs = await _ensure();
    return prefs.getString(_prefKey(key));
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await _ensure();
    await prefs.setString(_prefKey(key), value);
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await _ensure();
    await prefs.remove(_prefKey(key));
  }

  String _prefKey(String key) => 'secret__$key';
}
