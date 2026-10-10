import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/document/path_safety.dart';
import '../core/sync/sync_errors.dart';
import '../core/sync/sync_models.dart';
import '../core/sync/sync_provider.dart';

/// Copies Markdown files between [library root] and a user-chosen remote folder.
/// Covers the "sync folder / WebDAV-mounted folder" MVP path.
class FolderSyncProvider implements SyncProvider {
  FolderSyncProvider({required this.remoteFolder});

  final String remoteFolder;

  @override
  String get id => SyncProviderId.folder.wire;

  @override
  String get displayName => 'Sync folder';

  @override
  bool get requiresAccount => false;

  @override
  bool get isConfigured => remoteFolder.trim().isNotEmpty;

  @override
  Future<SyncResult> push(String root, SyncSelection selection) async {
    _ensureConfigured();
    final files = await _resolveLocalFiles(root, selection);
    var count = 0;
    for (final relative in files) {
      final local = File(resolveUnderRoot(root, relative));
      if (!await local.exists()) continue;
      final remotePath = p.join(remoteFolder, relative.replaceAll('/', p.separator));
      final remote = File(remotePath);
      await remote.parent.create(recursive: true);
      await local.copy(remote.path);
      count++;
    }
    return SyncResult(
      ok: true,
      message: 'Pushed $count file(s) (overwrite)',
      filesTouched: count,
    );
  }

  @override
  Future<SyncResult> pull(String root, SyncSelection selection) async {
    _ensureConfigured();
    final files = await _resolveRemoteFiles(selection);
    var count = 0;
    for (final relative in files) {
      final remote = File(p.join(remoteFolder, relative.replaceAll('/', p.separator)));
      if (!await remote.exists()) continue;
      final localPath = resolveUnderRoot(root, relative);
      final local = File(localPath);
      await local.parent.create(recursive: true);
      await remote.copy(local.path);
      count++;
    }
    return SyncResult(
      ok: true,
      message: 'Pulled $count file(s) (overwrite)',
      filesTouched: count,
    );
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const SyncNotConfiguredError('Sync folder path is empty');
    }
    if (!Directory(remoteFolder).existsSync()) {
      throw SyncIoError('Sync folder does not exist: $remoteFolder');
    }
  }

  Future<List<String>> _resolveLocalFiles(
    String root,
    SyncSelection selection,
  ) async {
    if (!selection.entireLibrary) {
      return selection.paths
          .map((e) => e.replaceAll('\\', '/'))
          .where((e) => e.endsWith('.md'))
          .toList();
    }
    final dir = Directory(root);
    if (!await dir.exists()) {
      throw SyncIoError('Library root missing: $root');
    }
    final out = <String>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.md')) continue;
      out.add(toPosixRelative(root, entity.path));
    }
    return out;
  }

  Future<List<String>> _resolveRemoteFiles(SyncSelection selection) async {
    if (!selection.entireLibrary) {
      return selection.paths
          .map((e) => e.replaceAll('\\', '/'))
          .where((e) => e.endsWith('.md'))
          .toList();
    }
    final dir = Directory(remoteFolder);
    final out = <String>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.md')) continue;
      out.add(toPosixRelative(remoteFolder, entity.path));
    }
    return out;
  }
}
