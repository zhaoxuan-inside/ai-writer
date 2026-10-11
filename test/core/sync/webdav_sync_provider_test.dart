import 'dart:convert';
import 'dart:io';

import 'package:ai_writer/adapters/webdav_sync_provider.dart';
import 'package:ai_writer/core/sync/sync_errors.dart';
import 'package:ai_writer/core/sync/sync_models.dart';
import 'package:ai_writer/core/sync/sync_settings_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WebDavSyncProvider', () {
    test('throws SyncNotConfiguredError without base URL', () async {
      final provider = WebDavSyncProvider(
        config: const WebDavSyncConfig(
          baseUrl: ' ',
          username: 'u',
          password: 'p',
        ),
      );
      expect(
        () => provider.push('/tmp', const SyncSelection.paths(['a.md'])),
        throwsA(isA<SyncNotConfiguredError>()),
      );
    });

    test('push issues MKCOL for parents then PUT with basic auth', () async {
      final library = await Directory.systemTemp.createTemp('ai_writer_wd_');
      addTearDown(() async {
        if (await library.exists()) await library.delete(recursive: true);
      });
      final localFile = File(p.join(library.path, 'notes', 'a.md'));
      await localFile.parent.create(recursive: true);
      await localFile.writeAsString('hello dav');

      final adapter = _WebDavMockAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://dav.example.com/base'));
      dio.httpClientAdapter = adapter;

      final provider = WebDavSyncProvider(
        config: const WebDavSyncConfig(
          baseUrl: 'https://dav.example.com/base',
          username: 'user',
          password: 'pass',
        ),
        dio: dio,
      );

      final result = await provider.push(
        library.path,
        const SyncSelection.paths(['notes/a.md']),
      );

      expect(result.ok, isTrue);
      expect(result.filesTouched, 1);
      expect(adapter.mkcolPaths, ['/base/notes']);
      expect(adapter.puts, hasLength(1));
      expect(adapter.puts.single.path, '/base/notes/a.md');
      expect(adapter.puts.single.body, 'hello dav');
      expect(
        adapter.lastAuthHeader,
        'Basic ${base64.encode(utf8.encode('user:pass'))}',
      );
    });

    test('push honors path prefix for remote layout', () async {
      final library = await Directory.systemTemp.createTemp('ai_writer_wdp_');
      addTearDown(() async {
        if (await library.exists()) await library.delete(recursive: true);
      });
      await File(p.join(library.path, 'doc.md')).writeAsString('x');

      final adapter = _WebDavMockAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://dav.example.com/base'));
      dio.httpClientAdapter = adapter;

      final provider = WebDavSyncProvider(
        config: const WebDavSyncConfig(
          baseUrl: 'https://dav.example.com/base',
          username: 'u',
          password: 'p',
          pathPrefix: 'writing',
        ),
        dio: dio,
      );

      final result = await provider.push(
        library.path,
        const SyncSelection.paths(['doc.md']),
      );

      expect(result.ok, isTrue);
      expect(adapter.mkcolPaths, ['/base/writing']);
      expect(adapter.puts.single.path, '/base/writing/doc.md');
    });

    test('pull writes fetched files and skips missing ones', () async {
      final library = await Directory.systemTemp.createTemp('ai_writer_wd2_');
      addTearDown(() async {
        if (await library.exists()) await library.delete(recursive: true);
      });

      final adapter = _WebDavMockAdapter(
        files: {
          '/base/there.md': 'dav-body',
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://dav.example.com/base'));
      dio.httpClientAdapter = adapter;

      final provider = WebDavSyncProvider(
        config: const WebDavSyncConfig(baseUrl: 'https://dav.example.com/base'),
        dio: dio,
      );

      final result = await provider.pull(
        library.path,
        const SyncSelection.paths(['there.md', 'missing.md']),
      );

      expect(result.ok, isTrue);
      expect(result.filesTouched, 1);
      expect(
        await File(p.join(library.path, 'there.md')).readAsString(),
        'dav-body',
      );
      expect(await File(p.join(library.path, 'missing.md')).exists(), isFalse);
    });

    test('pull entire library walks PROPFIND recursively for markdown only',
        () async {
      final library = await Directory.systemTemp.createTemp('ai_writer_wd3_');
      addTearDown(() async {
        if (await library.exists()) await library.delete(recursive: true);
      });

      final adapter = _WebDavMockAdapter(
        files: {
          '/base/root.md': 'root file',
          '/base/notes/a.md': 'note a',
          '/base/notes/deep/c.md': 'note c',
        },
        propfindDirs: {
          '/base': _multistatus([
            _Response('/base/', isCollection: true),
            _Response('/base/root.md'),
            _Response('/base/notes/', isCollection: true),
            _Response('/base/readme.txt'),
          ]),
          '/base/notes': _multistatus([
            _Response('/base/notes/', isCollection: true),
            _Response('/base/notes/a.md'),
            _Response('/base/notes/deep/', isCollection: true),
          ]),
          '/base/notes/deep': _multistatus([
            _Response('/base/notes/deep/', isCollection: true),
            _Response('/base/notes/deep/c.md'),
          ]),
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://dav.example.com/base'));
      dio.httpClientAdapter = adapter;

      final provider = WebDavSyncProvider(
        config: const WebDavSyncConfig(baseUrl: 'https://dav.example.com/base'),
        dio: dio,
      );

      final result = await provider.pull(
        library.path,
        const SyncSelection.entireLibrary(),
      );

      expect(result.ok, isTrue);
      expect(result.filesTouched, 3);
      expect(
        await File(p.join(library.path, 'root.md')).readAsString(),
        'root file',
      );
      expect(
        await File(p.join(library.path, 'notes', 'a.md')).readAsString(),
        'note a',
      );
      expect(
        await File(p.join(library.path, 'notes', 'deep', 'c.md')).readAsString(),
        'note c',
      );
      expect(
        await File(p.join(library.path, 'readme.txt')).exists(),
        isFalse,
      );
    });
  });

  group('WebDav settings', () {
    test('wire id round-trips and config persists with secret password',
        () async {
      SharedPreferences.setMockInitialValues({});
      expect(SyncProviderId.webdav.wire, 'webdav');
      expect(SyncProviderIdX.tryParse('webdav'), SyncProviderId.webdav);
      expect(SyncProviderIdX.tryParse('webdav_or_folder'), SyncProviderId.folder);

      final store = SyncSettingsStore();
      await store.saveWebDavConfig(
        const WebDavSyncConfig(
          baseUrl: 'https://dav.example.com/base ',
          username: 'user',
          password: 'secret-pass',
          pathPrefix: 'writing',
        ),
      );

      final loaded = await store.loadWebDavConfig();
      expect(loaded.baseUrl, 'https://dav.example.com/base');
      expect(loaded.username, 'user');
      expect(loaded.password, 'secret-pass');
      expect(loaded.pathPrefix, 'writing');
      expect(loaded.isConfigured, isTrue);
    });
  });
}

class _PutCall {
  const _PutCall(this.path, this.body);

  final String path;
  final String body;
}

class _WebDavMockAdapter implements HttpClientAdapter {
  _WebDavMockAdapter({
    this.files = const {},
    this.propfindDirs = const {},
  });

  final Map<String, String> files;
  final Map<String, String> propfindDirs;
  final List<String> mkcolPaths = [];
  final List<_PutCall> puts = [];
  String? lastAuthHeader;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastAuthHeader = options.headers['authorization'] as String?;
    final path = options.uri.path;
    switch (options.method.toUpperCase()) {
      case 'PROPFIND':
        final body = propfindDirs[path];
        if (body == null) {
          return ResponseBody.fromString('', 404);
        }
        return ResponseBody.fromString(
          body,
          207,
          headers: {
            Headers.contentTypeHeader: ['application/xml'],
          },
        );
      case 'GET':
        final body = files[path];
        if (body == null) {
          return ResponseBody.fromString('not found', 404);
        }
        return ResponseBody.fromString(
          body,
          200,
          headers: {
            Headers.contentTypeHeader: ['text/plain'],
          },
        );
      case 'PUT':
        final chunks = await requestStream?.toList() ?? const [];
        final raw = <int>[];
        for (final chunk in chunks) {
          raw.addAll(chunk);
        }
        puts.add(_PutCall(path, utf8.decode(raw)));
        return ResponseBody.fromString('', 201);
      case 'MKCOL':
        mkcolPaths.add(path);
        return ResponseBody.fromString('', 201);
      default:
        return ResponseBody.fromString('method not allowed', 405);
    }
  }
}

String _multistatus(List<_Response> responses) {
  final items = responses.map((r) {
    final resourcetype = r.isCollection ? '<d:resourcetype><d:collection/></d:resourcetype>' : '<d:resourcetype/>';
    return '<d:response><d:href>${r.href}</d:href>'
        '<d:propstat><d:prop>$resourcetype</d:prop>'
        '<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
  }).join();
  return '<?xml version="1.0" encoding="utf-8"?>'
      '<d:multistatus xmlns:d="DAV:">$items</d:multistatus>';
}

class _Response {
  const _Response(this.href, {this.isCollection = false});

  final String href;
  final bool isCollection;
}
