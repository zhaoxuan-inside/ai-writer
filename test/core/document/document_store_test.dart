import 'dart:io';

import 'package:ai_writer/adapters/filesystem_document_store.dart';
import 'package:ai_writer/adapters/memory_document_store.dart';
import 'package:ai_writer/core/document/document_errors.dart';
import 'package:ai_writer/core/document/document_models.dart';
import 'package:ai_writer/core/document/document_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('MemoryDocumentStore', () {
    late DocumentStore store;
    const root = 'C:/library';

    setUp(() {
      store = MemoryDocumentStore();
    });

    test('create + read round-trip markdown', () async {
      await store.create(root, 'draft.md', initialMarkdown: '# Hi\n');
      final doc = await store.read(root, 'draft.md');
      expect(doc.markdown, '# Hi\n');
      expect(doc.relativePath, 'draft.md');
    });

    test('write updates existing document', () async {
      await store.create(root, 'a.md', initialMarkdown: 'v1');
      await store.write(root, 'a.md', 'v2');
      expect((await store.read(root, 'a.md')).markdown, 'v2');
    });

    test('list returns files and nested dirs', () async {
      await store.create(root, 'root.md', initialMarkdown: 'x');
      await store.create(root, 'chapters/one.md', initialMarkdown: 'y');
      final entries = await store.list(root);
      expect(
        entries.map((e) => e.relativePath),
        containsAll(['root.md', 'chapters']),
      );
      expect(
        entries.firstWhere((e) => e.relativePath == 'chapters').kind,
        DocumentEntryKind.dir,
      );
    });

    test('rejects path escape with ..', () async {
      expect(
        () => store.read(root, '../secret.md'),
        throwsA(isA<PathEscapeError>()),
      );
    });

    test('read missing file throws NotFoundError', () async {
      expect(
        () => store.read(root, 'missing.md'),
        throwsA(isA<NotFoundError>()),
      );
    });

    test('delete removes document', () async {
      await store.create(root, 'gone.md', initialMarkdown: 'x');
      await store.delete(root, 'gone.md');
      expect(
        () => store.read(root, 'gone.md'),
        throwsA(isA<NotFoundError>()),
      );
    });
  });

  group('FilesystemDocumentStore', () {
    late Directory temp;
    late DocumentStore store;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('ai_writer_doc_');
      store = FilesystemDocumentStore();
    });

    tearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    test('create read write under library root', () async {
      final root = temp.path;
      await store.create(root, 'notes/hello.md', initialMarkdown: 'hello');
      expect((await store.read(root, 'notes/hello.md')).markdown, 'hello');
      await store.write(root, 'notes/hello.md', 'world');
      expect((await store.read(root, 'notes/hello.md')).markdown, 'world');

      final listed = await store.list(root, path: 'notes');
      expect(listed.single.name, 'hello.md');
      expect(listed.single.kind, DocumentEntryKind.file);
    });

    test('rejects escape outside root', () async {
      final root = temp.path;
      expect(
        () => store.read(root, '../outside.md'),
        throwsA(isA<PathEscapeError>()),
      );
    });

    test('absolute-looking relative path is rejected', () async {
      final root = temp.path;
      // On Windows an absolute path would escape; also reject leading slash forms.
      expect(
        () => store.read(root, p.join(temp.parent.path, 'x.md')),
        throwsA(isA<PathEscapeError>()),
      );
    });
  });
}
