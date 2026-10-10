import 'dart:convert';
import 'dart:io';

import 'package:ai_writer/adapters/folder_sync_provider.dart';
import 'package:ai_writer/adapters/github_sync_provider.dart';
import 'package:ai_writer/adapters/native_cloud_stub_sync_provider.dart';
import 'package:ai_writer/core/sync/sync_errors.dart';
import 'package:ai_writer/core/sync/sync_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('FolderSyncProvider', () {
    late Directory library;
    late Directory remote;

    setUp(() async {
      library = await Directory.systemTemp.createTemp('ai_writer_lib_');
      remote = await Directory.systemTemp.createTemp('ai_writer_remote_');
    });

    tearDown(() async {
      if (await library.exists()) await library.delete(recursive: true);
      if (await remote.exists()) await remote.delete(recursive: true);
    });

    test('push overwrites remote markdown with local content', () async {
      final localFile = File(p.join(library.path, 'notes', 'a.md'));
      await localFile.parent.create(recursive: true);
      await localFile.writeAsString('local-v2');

      final remoteFile = File(p.join(remote.path, 'notes', 'a.md'));
      await remoteFile.parent.create(recursive: true);
      await remoteFile.writeAsString('remote-old');

      final provider = FolderSyncProvider(remoteFolder: remote.path);
      final result = await provider.push(
        library.path,
        const SyncSelection.paths(['notes/a.md']),
      );

      expect(result.ok, isTrue);
      expect(result.filesTouched, 1);
      expect(await remoteFile.readAsString(), 'local-v2');
    });

    test('pull overwrites local markdown with remote content', () async {
      final remoteFile = File(p.join(remote.path, 'b.md'));
      await remoteFile.writeAsString('from-remote');

      final localFile = File(p.join(library.path, 'b.md'));
      await localFile.writeAsString('from-local');

      final provider = FolderSyncProvider(remoteFolder: remote.path);
      final result = await provider.pull(
        library.path,
        const SyncSelection.paths(['b.md']),
      );

      expect(result.ok, isTrue);
      expect(result.filesTouched, 1);
      expect(await localFile.readAsString(), 'from-remote');
    });

    test('throws SyncNotConfiguredError when folder empty', () async {
      final provider = FolderSyncProvider(remoteFolder: '  ');
      expect(
        () => provider.push(library.path, const SyncSelection.entireLibrary()),
        throwsA(isA<SyncNotConfiguredError>()),
      );
    });
  });

  group('NativeCloudStubSyncProvider', () {
    test('push and pull throw SyncNotEnabledError', () async {
      final provider = NativeCloudStubSyncProvider();
      expect(provider.isConfigured, isTrue);
      expect(provider.requiresAccount, isFalse);
      expect(
        () => provider.push('/tmp', const SyncSelection.entireLibrary()),
        throwsA(isA<SyncNotEnabledError>()),
      );
      expect(
        () => provider.pull('/tmp', const SyncSelection.entireLibrary()),
        throwsA(isA<SyncNotEnabledError>()),
      );
    });
  });

  group('GitHubSyncProvider', () {
    test('throws SyncNotConfiguredError without token', () async {
      final provider = GitHubSyncProvider(
        config: const GitHubSyncConfig(owner: 'o', repo: 'r', token: ''),
      );
      expect(
        () => provider.push('/tmp', const SyncSelection.paths(['a.md'])),
        throwsA(isA<SyncNotConfiguredError>()),
      );
    });

    test('push puts file via Contents API with overwrite sha', () async {
      final library = await Directory.systemTemp.createTemp('ai_writer_gh_');
      addTearDown(() async {
        if (await library.exists()) await library.delete(recursive: true);
      });
      await File(p.join(library.path, 'doc.md')).writeAsString('hello gh');

      final puts = <Map<String, dynamic>>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.github.com'));
      dio.httpClientAdapter = _GitHubMockAdapter(
        onGet: (path) {
          if (path.contains('/contents/doc.md')) {
            return (
              200,
              {
                'type': 'file',
                'sha': 'abc123',
                'path': 'doc.md',
                'content': base64.encode(utf8.encode('old')),
              },
            );
          }
          return (404, {'message': 'Not Found'});
        },
        onPut: (path, data) {
          puts.add({'path': path, 'data': data});
          return (200, {'content': {'path': 'doc.md', 'sha': 'new'}});
        },
      );

      final provider = GitHubSyncProvider(
        config: const GitHubSyncConfig(
          owner: 'acme',
          repo: 'notes',
          token: 'pat-test',
          branch: 'main',
        ),
        dio: dio,
      );

      final result = await provider.push(
        library.path,
        const SyncSelection.paths(['doc.md']),
      );

      expect(result.ok, isTrue);
      expect(result.filesTouched, 1);
      expect(puts, hasLength(1));
      expect(puts.single['path'], contains('/repos/acme/notes/contents/doc.md'));
      final body = puts.single['data'] as Map<String, dynamic>;
      expect(body['sha'], 'abc123');
      expect(body['branch'], 'main');
      expect(
        utf8.decode(base64.decode(body['content'] as String)),
        'hello gh',
      );
    });

    test('pull writes decoded Contents API payload to local file', () async {
      final library = await Directory.systemTemp.createTemp('ai_writer_gh_pull_');
      addTearDown(() async {
        if (await library.exists()) await library.delete(recursive: true);
      });

      final dio = Dio(BaseOptions(baseUrl: 'https://api.github.com'));
      dio.httpClientAdapter = _GitHubMockAdapter(
        onGet: (path) {
          if (path.contains('/contents/remote.md')) {
            return (
              200,
              {
                'type': 'file',
                'sha': 'x',
                'path': 'remote.md',
                'content': base64.encode(utf8.encode('pulled-body')),
              },
            );
          }
          return (404, {'message': 'Not Found'});
        },
      );

      final provider = GitHubSyncProvider(
        config: const GitHubSyncConfig(
          owner: 'acme',
          repo: 'notes',
          token: 'pat-test',
        ),
        dio: dio,
      );

      final result = await provider.pull(
        library.path,
        const SyncSelection.paths(['remote.md']),
      );

      expect(result.ok, isTrue);
      expect(result.filesTouched, 1);
      expect(
        await File(p.join(library.path, 'remote.md')).readAsString(),
        'pulled-body',
      );
    });
  });

  group('SyncProviderId', () {
    test('settings wire ids round-trip for provider selection', () {
      expect(SyncProviderId.folder.wire, 'webdav_or_folder');
      expect(SyncProviderId.github.wire, 'github');
      expect(SyncProviderId.nativeCloud.wire, 'native_cloud');
      expect(SyncProviderIdX.tryParse('webdav_or_folder'), SyncProviderId.folder);
      expect(SyncProviderIdX.tryParse('github'), SyncProviderId.github);
      expect(SyncProviderIdX.tryParse('native_cloud'), SyncProviderId.nativeCloud);
    });
  });
}

typedef _MockResponse = (int status, Object body);

class _GitHubMockAdapter implements HttpClientAdapter {
  _GitHubMockAdapter({
    required this.onGet,
    this.onPut,
  });

  final _MockResponse Function(String path) onGet;
  final _MockResponse Function(String path, Map<String, dynamic> data)? onPut;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (options.method == 'GET') {
      final (status, body) = onGet(path);
      return ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.method == 'PUT') {
      final raw = options.data;
      final map = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);
      final (status, body) = (onPut ?? (_, __) => (500, {'message': 'no put'}))(
        path,
        map,
      );
      return ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString('{}', 405);
  }
}
