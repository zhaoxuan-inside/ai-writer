import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ai/ai_models.dart';
import '../../core/sync/sync_models.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _model = TextEditingController();
  final _folder = TextEditingController();
  final _ghOwner = TextEditingController();
  final _ghRepo = TextEditingController();
  final _ghBranch = TextEditingController();
  final _ghPrefix = TextEditingController();
  final _ghToken = TextEditingController();

  SyncProviderId _syncProvider = SyncProviderId.folder;
  bool _loading = true;
  bool _obscureAi = true;
  bool _obscureGh = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    _folder.dispose();
    _ghOwner.dispose();
    _ghRepo.dispose();
    _ghBranch.dispose();
    _ghPrefix.dispose();
    _ghToken.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ai = await ref.read(aiCredentialsStoreProvider).load();
    final syncStore = ref.read(syncSettingsStoreProvider);
    final providerId = await syncStore.loadSelectedProvider();
    final folder = await syncStore.loadFolderConfig();
    final github = await syncStore.loadGitHubConfig();
    if (!mounted) return;
    _baseUrl.text = ai.baseUrl;
    _apiKey.text = ai.apiKey;
    _model.text = ai.model;
    _syncProvider = providerId;
    _folder.text = folder.remoteFolder;
    _ghOwner.text = github.owner;
    _ghRepo.text = github.repo;
    _ghBranch.text = github.branch;
    _ghPrefix.text = github.pathPrefix;
    _ghToken.text = github.token;
    setState(() => _loading = false);
  }

  Future<void> _pickSyncFolder() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose sync folder',
    );
    if (path == null) return;
    setState(() => _folder.text = path);
  }

  Future<void> _save() async {
    await ref.read(aiCredentialsStoreProvider).save(
          AiProviderConfig(
            baseUrl: _baseUrl.text.trim(),
            apiKey: _apiKey.text.trim(),
            model: _model.text.trim().isEmpty
                ? 'gpt-4o-mini'
                : _model.text.trim(),
          ),
        );
    final syncStore = ref.read(syncSettingsStoreProvider);
    await syncStore.saveSelectedProvider(_syncProvider);
    await syncStore.saveFolderConfig(
      FolderSyncConfig(remoteFolder: _folder.text.trim()),
    );
    await syncStore.saveGitHubConfig(
      GitHubSyncConfig(
        owner: _ghOwner.text.trim(),
        repo: _ghRepo.text.trim(),
        branch: _ghBranch.text.trim().isEmpty ? 'main' : _ghBranch.text.trim(),
        pathPrefix: _ghPrefix.text.trim(),
        token: _ghToken.text.trim(),
      ),
    );
    ref.invalidate(aiProviderConfigProvider);
    ref.invalidate(selectedSyncProviderIdProvider);
    ref.invalidate(activeSyncProviderProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: theme.textTheme.titleMedium),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('AI', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                TextField(
                  controller: _baseUrl,
                  decoration: const InputDecoration(
                    labelText: 'API Base URL',
                    hintText: 'https://api.openai.com/v1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKey,
                  obscureText: _obscureAi,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureAi
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureAi = !_obscureAi),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _model,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    hintText: 'gpt-4o-mini',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 28),
                Text('Sync', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  'Manual push/pull overwrites the other side. No conflict merge.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SyncProviderId>(
                  // ignore: deprecated_member_use
                  value: _syncProvider,
                  decoration: const InputDecoration(
                    labelText: 'Provider',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: SyncProviderId.folder,
                      child: Text('Sync folder'),
                    ),
                    DropdownMenuItem(
                      value: SyncProviderId.github,
                      child: Text('GitHub'),
                    ),
                    DropdownMenuItem(
                      value: SyncProviderId.nativeCloud,
                      child: Text('AI Writer Cloud (stub)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _syncProvider = v);
                  },
                ),
                const SizedBox(height: 16),
                if (_syncProvider == SyncProviderId.folder) ...[
                  TextField(
                    controller: _folder,
                    decoration: InputDecoration(
                      labelText: 'Remote / sync folder',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open_outlined),
                        onPressed: _pickSyncFolder,
                      ),
                    ),
                  ),
                ],
                if (_syncProvider == SyncProviderId.github) ...[
                  TextField(
                    controller: _ghOwner,
                    decoration: const InputDecoration(
                      labelText: 'Owner',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ghRepo,
                    decoration: const InputDecoration(
                      labelText: 'Repository',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ghBranch,
                    decoration: const InputDecoration(
                      labelText: 'Branch',
                      hintText: 'main',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ghPrefix,
                    decoration: const InputDecoration(
                      labelText: 'Path prefix (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ghToken,
                    obscureText: _obscureGh,
                    decoration: InputDecoration(
                      labelText: 'Personal access token',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureGh
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureGh = !_obscureGh),
                      ),
                    ),
                  ),
                ],
                if (_syncProvider == SyncProviderId.nativeCloud)
                  Text(
                    'Commercial cloud is not enabled. Interface is reserved; '
                    'pick Sync folder or GitHub for now.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
    );
  }
}
