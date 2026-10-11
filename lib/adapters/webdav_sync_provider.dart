import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../core/document/path_safety.dart';
import '../core/sync/sync_errors.dart';
import '../core/sync/sync_models.dart';
import '../core/sync/sync_provider.dart';

/// WebDAV sync over PUT/GET with MKCOL for collections and PROPFIND for
/// listing. Overwrite-only; no merge / conflict UI.
class WebDavSyncProvider implements SyncProvider {
  WebDavSyncProvider({
    required WebDavSyncConfig config,
    Dio? dio,
  })  : _config = config,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: config.baseUrl.trim(),
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
              ),
            );

  static const _propfindBody = '<?xml version="1.0" encoding="utf-8"?>'
      '<d:propfind xmlns:d="DAV:">'
      '<d:prop><d:resourcetype/></d:prop>'
      '</d:propfind>';

  final WebDavSyncConfig _config;
  final Dio _dio;

  @override
  String get id => SyncProviderId.webdav.wire;

  @override
  String get displayName => 'WebDAV';

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
      await _mkdirsBelowBase(relative);
      await _put(relative, await local.readAsString());
      count++;
    }
    return SyncResult(
      ok: true,
      message: 'Pushed $count file(s) to WebDAV (overwrite)',
      filesTouched: count,
    );
  }

  @override
  Future<SyncResult> pull(String root, SyncSelection selection) async {
    _ensureConfigured();
    final relatives = selection.entireLibrary
        ? await _listRemoteMarkdown()
        : selection.paths.map(_normalize).toList();
    var count = 0;
    for (final relative in relatives) {
      final payload = await _get(relative);
      if (payload == null) continue;
      final local = File(resolveUnderRoot(root, relative));
      await local.parent.create(recursive: true);
      await local.writeAsString(payload);
      count++;
    }
    return SyncResult(
      ok: true,
      message: 'Pulled $count file(s) from WebDAV (overwrite)',
      filesTouched: count,
    );
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const SyncNotConfiguredError('WebDAV server URL required');
    }
    if (_config.username.trim().isNotEmpty) {
      final raw = utf8.encode('${_config.username}:${_config.password}');
      _dio.options.headers['Authorization'] = 'Basic ${base64.encode(raw)}';
    }
  }

  String _normalize(String relative) => relative.replaceAll('\\', '/');

  String _cleanPrefix() => _config.pathPrefix
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'^/+|/+$'), '');

  /// Request path below the configured base collection, segments encoded.
  /// Empty for the base collection itself so dio hits the bare base URL.
  String _remotePath(String relative) {
    final segments = [
      if (_cleanPrefix().isNotEmpty) ..._cleanPrefix().split('/'),
      ..._normalize(relative).split('/'),
    ].where((s) => s.isNotEmpty).map(Uri.encodeComponent).toList();
    if (segments.isEmpty) return '';
    return '/${segments.join('/')}';
  }

  /// MKCOL every ancestor collection below the base for [relative].
  /// The base collection itself is assumed to exist (405 = exists, ignore).
  Future<void> _mkdirsBelowBase(String relative) async {
    final dirs = [
      if (_cleanPrefix().isNotEmpty) ..._cleanPrefix().split('/'),
      ..._normalize(relative).split('/')..removeLast(),
    ].where((s) => s.isNotEmpty);
    var made = <String>[];
    for (final dir in dirs) {
      made = [...made, Uri.encodeComponent(dir)];
      try {
        await _dio.request('/${made.join('/')}', options: Options(method: 'MKCOL'));
      } on DioException catch (e) {
        if (e.response?.statusCode != 405) {
          throw SyncIoError(_dioMessage(e));
        }
      }
    }
  }

  Future<void> _put(String relative, String content) async {
    try {
      await _dio.put(
        _remotePath(relative),
        data: content,
        options: Options(
          headers: {Headers.contentTypeHeader: 'text/markdown; charset=utf-8'},
        ),
      );
    } on DioException catch (e) {
      throw SyncIoError(_dioMessage(e));
    }
  }

  Future<String?> _get(String relative) async {
    try {
      final res = await _dio.get<String>(
        _remotePath(relative),
        options: Options(responseType: ResponseType.plain),
      );
      return res.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw SyncIoError(_dioMessage(e));
    }
  }

  Future<List<String>> _listRemoteMarkdown() async {
    final out = <String>[];
    await _walkRemote('', out);
    return out;
  }

  Future<void> _walkRemote(String requested, List<String> out) async {
    final String body;
    try {
      final res = await _dio.request<String>(
        _remotePath(requested),
        data: _propfindBody,
        options: Options(
          method: 'PROPFIND',
          responseType: ResponseType.plain,
          headers: {
            'Depth': '1',
            Headers.contentTypeHeader: 'application/xml',
          },
        ),
      );
      body = res.data ?? '';
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return;
      throw SyncIoError(_dioMessage(e));
    }

    final List<({bool isCollection, String relative})> entries;
    try {
      entries = _parseMultistatus(body);
    } on XmlException {
      throw const SyncIoError('WebDAV PROPFIND returned malformed XML');
    }

    for (final entry in entries) {
      // Depth:1 responses echo the requested collection itself; skip it.
      if (_trimSlashes(entry.relative) == _trimSlashes(requested)) continue;
      if (entry.isCollection) {
        await _walkRemote('${entry.relative}/', out);
      } else if (entry.relative.toLowerCase().endsWith('.md')) {
        out.add(entry.relative);
      }
    }
  }

  String _trimSlashes(String s) => s.replaceAll(RegExp(r'^/+|/+$'), '');

  /// Extracts (relative-to-base-and-prefix) paths from a multistatus body.
  List<({bool isCollection, String relative})> _parseMultistatus(String body) {
    final doc = XmlDocument.parse(body);
    final basePath = Uri.parse(_dio.options.baseUrl)
        .path
        .replaceAll(RegExp(r'^/+|/+$'), '');
    final prefix = _cleanPrefix();
    final entries = <({bool isCollection, String relative})>[];
    for (final response
        in doc.findAllElements('response', namespaceUri: '*')) {
      String? href;
      for (final candidate
          in response.findAllElements('href', namespaceUri: '*')) {
        href = candidate.innerText.trim();
        break;
      }
      if (href == null || href.isEmpty) continue;
      final hrefPath = Uri.tryParse(href)?.path ?? href;
      var path = hrefPath;
      if (basePath.isNotEmpty && path.startsWith('/$basePath')) {
        path = path.substring(basePath.length + 1);
      }
      var relative = path.split('?').first.replaceAll(RegExp(r'^/+|/+$'), '');
      if (prefix.isNotEmpty && relative.startsWith('$prefix/')) {
        relative = relative.substring(prefix.length + 1);
      }
      if (relative.isEmpty) continue;
      relative = _decodePath(relative);
      entries.add((
        isCollection: response
            .findAllElements('collection', namespaceUri: '*')
            .isNotEmpty,
        relative: relative,
      ));
    }
    return entries;
  }

  String _decodePath(String path) {
    try {
      return Uri.decodeComponent(path);
    } on FormatException {
      return path;
    }
  }

  Future<List<String>> _localMarkdownFiles(
    String root,
    SyncSelection selection,
  ) async {
    if (!selection.entireLibrary) {
      return selection.paths.map(_normalize).toList();
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

  String _dioMessage(DioException e) {
    final status = e.response?.statusCode;
    if (status != null) return 'WebDAV HTTP $status';
    return e.message ?? 'WebDAV network error';
  }
}
