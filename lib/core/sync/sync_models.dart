class SyncSelection {
  const SyncSelection.entireLibrary()
      : entireLibrary = true,
        paths = const [];

  const SyncSelection.paths(this.paths) : entireLibrary = false;

  final bool entireLibrary;
  final List<String> paths;
}

class SyncResult {
  const SyncResult({
    required this.ok,
    this.message,
    this.filesTouched = 0,
  });

  final bool ok;
  final String? message;
  final int filesTouched;
}

enum SyncProviderId {
  folder,
  github,
  nativeCloud,
}

extension SyncProviderIdX on SyncProviderId {
  String get wire {
    return switch (this) {
      SyncProviderId.folder => 'webdav_or_folder',
      SyncProviderId.github => 'github',
      SyncProviderId.nativeCloud => 'native_cloud',
    };
  }

  static SyncProviderId? tryParse(String? raw) {
    return switch (raw) {
      'webdav_or_folder' || 'folder' => SyncProviderId.folder,
      'github' => SyncProviderId.github,
      'native_cloud' => SyncProviderId.nativeCloud,
      _ => null,
    };
  }
}

class FolderSyncConfig {
  const FolderSyncConfig({required this.remoteFolder});

  final String remoteFolder;
}

class GitHubSyncConfig {
  const GitHubSyncConfig({
    required this.owner,
    required this.repo,
    required this.token,
    this.branch = 'main',
    this.pathPrefix = '',
  });

  final String owner;
  final String repo;
  final String token;
  final String branch;
  final String pathPrefix;

  bool get isConfigured =>
      owner.trim().isNotEmpty &&
      repo.trim().isNotEmpty &&
      token.trim().isNotEmpty;
}
