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
  webdav,
  github,
  nativeCloud,
}

extension SyncProviderIdX on SyncProviderId {
  String get wire {
    return switch (this) {
      SyncProviderId.folder => 'webdav_or_folder',
      SyncProviderId.webdav => 'webdav',
      SyncProviderId.github => 'github',
      SyncProviderId.nativeCloud => 'native_cloud',
    };
  }

    static SyncProviderId? tryParse(String? raw) {
      return switch (raw) {
        'webdav_or_folder' || 'folder' => SyncProviderId.folder,
        'webdav' => SyncProviderId.webdav,
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

class WebDavSyncConfig {
  const WebDavSyncConfig({
    required this.baseUrl,
    this.username = '',
    this.password = '',
    this.pathPrefix = '',
  });

  /// Server collection URL, e.g. https://dav.example.com/remote.php/dav/files/me
  final String baseUrl;
  final String username;
  final String password;
  final String pathPrefix;

  bool get isConfigured => baseUrl.trim().isNotEmpty;
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
