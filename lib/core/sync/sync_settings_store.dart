import 'package:shared_preferences/shared_preferences.dart';

import '../secrets/secret_store.dart';
import 'sync_models.dart';

const _kProviderId = 'sync_provider_id';
const _kFolderPath = 'sync_folder_path';
const _kGhOwner = 'sync_gh_owner';
const _kGhRepo = 'sync_gh_repo';
const _kGhBranch = 'sync_gh_branch';
const _kGhPrefix = 'sync_gh_prefix';
const _kGhToken = 'sync_gh_token';
const _kDavUrl = 'sync_dav_url';
const _kDavUser = 'sync_dav_user';
const _kDavPass = 'sync_dav_password';
const _kDavPrefix = 'sync_dav_prefix';

class SyncSettingsStore {
  SyncSettingsStore({SecretStore? secretStore})
      : _secrets = secretStore ?? PrefsSecretStore();

  final SecretStore _secrets;

  Future<SyncProviderId> loadSelectedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return SyncProviderIdX.tryParse(prefs.getString(_kProviderId)) ??
        SyncProviderId.folder;
  }

  Future<void> saveSelectedProvider(SyncProviderId id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProviderId, id.wire);
  }

  Future<FolderSyncConfig> loadFolderConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return FolderSyncConfig(remoteFolder: prefs.getString(_kFolderPath) ?? '');
  }

  Future<void> saveFolderConfig(FolderSyncConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFolderPath, config.remoteFolder.trim());
  }

  Future<GitHubSyncConfig> loadGitHubConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await _secrets.read(_kGhToken) ?? '';
    return GitHubSyncConfig(
      owner: prefs.getString(_kGhOwner) ?? '',
      repo: prefs.getString(_kGhRepo) ?? '',
      branch: prefs.getString(_kGhBranch) ?? 'main',
      pathPrefix: prefs.getString(_kGhPrefix) ?? '',
      token: token,
    );
  }

  Future<void> saveGitHubConfig(GitHubSyncConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGhOwner, config.owner.trim());
    await prefs.setString(_kGhRepo, config.repo.trim());
    await prefs.setString(_kGhBranch, config.branch.trim());
    await prefs.setString(_kGhPrefix, config.pathPrefix.trim());
    await _secrets.write(_kGhToken, config.token.trim());
  }

  Future<WebDavSyncConfig> loadWebDavConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final password = await _secrets.read(_kDavPass) ?? '';
    return WebDavSyncConfig(
      baseUrl: prefs.getString(_kDavUrl) ?? '',
      username: prefs.getString(_kDavUser) ?? '',
      password: password,
      pathPrefix: prefs.getString(_kDavPrefix) ?? '',
    );
  }

  Future<void> saveWebDavConfig(WebDavSyncConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDavUrl, config.baseUrl.trim());
    await prefs.setString(_kDavUser, config.username.trim());
    await prefs.setString(_kDavPrefix, config.pathPrefix.trim());
    await _secrets.write(_kDavPass, config.password.trim());
  }
}
