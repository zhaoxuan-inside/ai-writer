import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../core/document/path_safety.dart';
import '../core/sync/sync_errors.dart';
import '../core/sync/sync_models.dart';
import '../core/sync/sync_provider.dart';

/// GitHub Contents API sync (PAT). Overwrite-only; no merge / conflict UI.
class GitHubSyncProvider implements SyncProvider {
  GitHubSyncProvider({
    required GitHubSyncConfig config,
    Dio? dio,
  })  : _config = config,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.github.com',
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
                headers: {
                  'Accept': 'application/vnd.github+json',
                  'X-GitHub-Api-Version': '2022-11-28',
                },
              ),
            );

  final GitHubSyncConfig _config;
  final Dio _dio;

  @override
  String get id => SyncProviderId.github.wire;

  @override
  String get displayName => 'GitHub';

  @override
  bool get requiresAccount => false;

  @override
  bool get isConfigured => _config.isConfigured;

  @override
  Future<SyncResult> push(String root, SyncSelection selection) async {
    _ensureConfigured();
    final files = await _localMarkdownFiles(root, selection);
    var count = 0;
    for (final relative in files) {
      final local = File(resolveUnderRoot(root, relative));
      if (!await local.exists()) continue;
      final content = await local.readAsString();
      final remotePath = _remotePath(relative);
      final sha = await _getSha(remotePath);
      await _putFile(remotePath, content, sha: sha);
      count++;
    }
    return SyncResult(
      ok: true,
      message: 'Pushed $count file(s) to GitHub (overwrite)',
      filesTouched: count,
    );
  }

  @override
  Future<SyncResult> pull(String root, SyncSelection selection) async {
    _ensureConfigured();
    final paths = selection.entireLibrary
        ? await _listRemoteMarkdown()
        : selection.paths.map(_remotePath).toList();
    var count = 0;
    for (final remotePath in paths) {
      final payload = await _getFile(remotePath);
      if (payload == null) continue;
      final relative = _relativeFromRemote(remotePath);
      final local = File(resolveUnderRoot(root, relative));
      await local.parent.create(recursive: true);
      await local.writeAsString(payload);
      count++;
    }
    return SyncResult(
      ok: true,
      message: 'Pulled $count file(s) from GitHub (overwrite)',
      filesTouched: count,
    );
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const SyncNotConfiguredError('GitHub owner/repo/token required');
    }
    _dio.options.headers['Authorization'] = 'Bearer ${_config.token}';
  }

  String _remotePath(String relative) {
    final cleaned = relative.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
    final prefix = _config.pathPrefix
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^/+|/+$'), '');
    if (prefix.isEmpty) return cleaned;
    return '$prefix/$cleaned';
  }

  String _relativeFromRemote(String remotePath) {
    final prefix = _config.pathPrefix
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^/+|/+$'), '');
    var path = remotePath.replaceAll('\\', '/');
    if (prefix.isNotEmpty && path.startsWith('$prefix/')) {
      path = path.substring(prefix.length + 1);
    }
    return path;
  }

  Future<List<String>> _localMarkdownFiles(
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
    final out = <String>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.md')) continue;
      out.add(toPosixRelative(root, entity.path));
    }
    return out;
  }

  Future<String?> _getSha(String path) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/repos/${_config.owner}/${_config.repo}/contents/$path',
        queryParameters: {'ref': _config.branch},
      );
      final sha = res.data?['sha'];
      return sha is String ? sha : null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw SyncIoError(_dioMessage(e));
    }
  }

  Future<String?> _getFile(String path) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/repos/${_config.owner}/${_config.repo}/contents/$path',
        queryParameters: {'ref': _config.branch},
      );
      final data = res.data;
      if (data == null || data['type'] != 'file') return null;
      final encoded = data['content'];
      if (encoded is! String) return null;
      final cleaned = encoded.replaceAll('\n', '');
      return utf8.decode(base64.decode(cleaned));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw SyncIoError(_dioMessage(e));
    }
  }

  Future<void> _putFile(String path, String content, {String? sha}) async {
    try {
      await _dio.put<Map<String, dynamic>>(
        '/repos/${_config.owner}/${_config.repo}/contents/$path',
        data: {
          'message': 'ai-writer sync: $path',
          'content': base64.encode(utf8.encode(content)),
          'branch': _config.branch,
          if (sha != null) 'sha': sha,
        },
      );
    } on DioException catch (e) {
      throw SyncIoError(_dioMessage(e));
    }
  }

  Future<List<String>> _listRemoteMarkdown() async {
    final prefix = _config.pathPrefix
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^/+|/+$'), '');
    final start = prefix.isEmpty ? '' : prefix;
    final out = <String>[];
    await _walkRemote(start, out);
    return out;
  }

  Future<void> _walkRemote(String path, List<String> out) async {
    try {
      final res = await _dio.get<dynamic>(
        path.isEmpty
            ? '/repos/${_config.owner}/${_config.repo}/contents'
            : '/repos/${_config.owner}/${_config.repo}/contents/$path',
        queryParameters: {'ref': _config.branch},
      );
      final data = res.data;
      if (data is Map && data['type'] == 'file') {
        final name = data['path'];
        if (name is String && name.endsWith('.md')) out.add(name);
        return;
      }
      if (data is! List) return;
      for (final item in data) {
        if (item is! Map) continue;
        final type = item['type'];
        final itemPath = item['path'];
        if (itemPath is! String) continue;
        if (type == 'dir') {
          await _walkRemote(itemPath, out);
        } else if (type == 'file' && itemPath.endsWith('.md')) {
          out.add(itemPath);
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return;
      throw SyncIoError(_dioMessage(e));
    }
  }

  String _dioMessage(DioException e) {
    final status = e.response?.statusCode;
    if (status != null) return 'GitHub HTTP $status';
    return e.message ?? 'GitHub network error';
  }
}
