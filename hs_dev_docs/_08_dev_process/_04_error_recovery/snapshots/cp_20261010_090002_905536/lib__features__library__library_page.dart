import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/document/document_models.dart';
import '../../core/sync/sync_errors.dart';
import '../../core/sync/sync_models.dart';
import '../editor/markdown_editor_page.dart';
import '../settings/settings_page.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  String? _browsePath;
  List<DocumentEntry>? _entries;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose writing folder',
    );
    if (path == null) return;
    await ref.read(libraryRootProvider.notifier).setRoot(path);
    _browsePath = null;
    await _reload();
  }

  Future<void> _reload() async {
    final session = ref.read(librarySessionProvider);
    if (session == null) {
      setState(() {
        _entries = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await session.list(path: _browsePath);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _openFile(DocumentEntry entry) async {
    if (entry.kind == DocumentEntryKind.dir) {
      setState(() => _browsePath = entry.relativePath);
      await _reload();
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarkdownEditorPage(relativePath: entry.relativePath),
      ),
    );
    await _reload();
  }

  Future<void> _createFile() async {
    final session = ref.read(librarySessionProvider);
    if (session == null) return;
    final nameController = TextEditingController(text: 'untitled.md');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New document'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'name.md'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    var name = nameController.text.trim();
    if (name.isEmpty) return;
    if (!name.endsWith('.md')) name = '$name.md';
    final relative = _browsePath == null || _browsePath!.isEmpty
        ? name
        : '$_browsePath/$name';
    await session.createNew(relative, initialMarkdown: '# $name\n\n');
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarkdownEditorPage(relativePath: relative),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final root = ref.watch(libraryRootProvider);
    final theme = Theme.of(context);

    ref.listen(libraryRootProvider, (prev, next) {
      if (prev != next) {
        _browsePath = null;
        _reload();
      }
    });

    if (root == null || root.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('AI Writer', style: theme.textTheme.titleMedium),
          actions: [
            IconButton(
              tooltip: 'Settings',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsPage(),
                  ),
                );
              },
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Choose a folder to start writing.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your files stay in the folder you pick. No account required.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _pickFolder,
                    child: const Text('Choose folder'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _browsePath == null || _browsePath!.isEmpty ? root : _browsePath!,
          style: theme.textTheme.titleSmall,
          overflow: TextOverflow.ellipsis,
        ),
        leading: _browsePath != null && _browsePath!.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  final parts = _browsePath!.split('/');
                  setState(() {
                    _browsePath = parts.length <= 1
                        ? null
                        : parts.sublist(0, parts.length - 1).join('/');
                  });
                  _reload();
                },
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Change folder',
            onPressed: _pickFolder,
            icon: const Icon(Icons.folder_open_outlined),
          ),
          IconButton(
            tooltip: 'New document',
            onPressed: _createFile,
            icon: const Icon(Icons.note_add_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsPage(),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('$_error'))
              : ListView.separated(
                  itemCount: _entries?.length ?? 0,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = _entries![index];
                    return ListTile(
                      leading: Icon(
                        entry.kind == DocumentEntryKind.dir
                            ? Icons.folder_outlined
                            : Icons.description_outlined,
                      ),
                      title: Text(entry.name),
                      onTap: () => _openFile(entry),
                    );
                  },
                ),
    );
  }
}
