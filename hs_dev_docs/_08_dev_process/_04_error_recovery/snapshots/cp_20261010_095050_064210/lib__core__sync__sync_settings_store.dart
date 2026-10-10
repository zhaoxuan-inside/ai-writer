import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_models.dart';

const _kProviderId = 'sync_provider_id';
const _kFolderPath = 'sync_folder_path';
const _kGhOwner = 'sync_gh_owner';
const _kGhRepo = 'sync_gh_repo';
const _kGhBranch = 'sync_gh_branch';
const _kGhPrefix = 'sync_gh_prefix';
const _kGhToken = 'sync_gh_token';

class SyncSettingsStore {
  SyncSettingsStore({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

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
    final token = await _secure.read(key: _kGhToken) ?? '';
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
    await _secure.write(key: _kGhToken, value: config.token.trim());
  }
}
