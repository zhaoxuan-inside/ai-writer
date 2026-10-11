import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../adapters/filesystem_document_store.dart';
import '../adapters/folder_sync_provider.dart';
import '../adapters/github_sync_provider.dart';
import '../adapters/native_cloud_stub_sync_provider.dart';
import '../adapters/openai_compatible_ai_provider.dart';
import '../adapters/quill_markdown_bridge.dart';
import '../adapters/webdav_sync_provider.dart';
import '../core/ai/ai_credentials_store.dart';
import '../core/ai/ai_models.dart';
import '../core/ai/ai_provider.dart';
import '../core/document/document_store.dart';
import '../core/document/library_session.dart';
import '../core/markdown/markdown_bridge.dart';
import '../core/sync/sync_models.dart';
import '../core/sync/sync_provider.dart';
import '../core/sync/sync_settings_store.dart';

const libraryRootPrefsKey = 'library_root';

final documentStoreProvider = Provider<DocumentStore>((ref) {
  return FilesystemDocumentStore();
});

final markdownBridgeProvider = Provider<MarkdownBridge>((ref) {
  return QuillMarkdownBridge();
});

final aiCredentialsStoreProvider = Provider<AiCredentialsStore>((ref) {
  return AiCredentialsStore();
});

final aiProviderConfigProvider = FutureProvider<AiProviderConfig>((ref) async {
  return ref.watch(aiCredentialsStoreProvider).load();
});

final aiProviderProvider = Provider<AiProvider>((ref) {
  final asyncConfig = ref.watch(aiProviderConfigProvider);
  final config = asyncConfig.asData?.value ??
      const AiProviderConfig(baseUrl: '', apiKey: '');
  return OpenAiCompatibleAiProvider(config: config);
});

final libraryRootProvider =
    NotifierProvider<LibraryRootNotifier, String?>(LibraryRootNotifier.new);

class LibraryRootNotifier extends Notifier<String?> {
  @override
  String? build() {
    Future<void>(() async {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(libraryRootPrefsKey);
      if (saved != null && saved.isNotEmpty && state != saved) {
        state = saved;
      }
    });
    return null;
  }

  Future<void> setRoot(String root) async {
    state = root;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(libraryRootPrefsKey, root);
  }

  Future<void> clear() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(libraryRootPrefsKey);
  }
}

final librarySessionProvider = Provider<LibrarySession?>((ref) {
  final root = ref.watch(libraryRootProvider);
  if (root == null || root.isEmpty) return null;
  return LibrarySession(root: root, store: ref.watch(documentStoreProvider));
});

final syncSettingsStoreProvider = Provider<SyncSettingsStore>((ref) {
  return SyncSettingsStore();
});

final selectedSyncProviderIdProvider =
    FutureProvider<SyncProviderId>((ref) async {
  return ref.watch(syncSettingsStoreProvider).loadSelectedProvider();
});

final activeSyncProviderProvider = FutureProvider<SyncProvider>((ref) async {
  final store = ref.watch(syncSettingsStoreProvider);
  final id = await store.loadSelectedProvider();
  switch (id) {
    case SyncProviderId.folder:
      final cfg = await store.loadFolderConfig();
      return FolderSyncProvider(remoteFolder: cfg.remoteFolder);
    case SyncProviderId.webdav:
      final cfg = await store.loadWebDavConfig();
      return WebDavSyncProvider(config: cfg);
    case SyncProviderId.github:
      final cfg = await store.loadGitHubConfig();
      return GitHubSyncProvider(config: cfg);
    case SyncProviderId.nativeCloud:
      return NativeCloudStubSyncProvider();
  }
});
