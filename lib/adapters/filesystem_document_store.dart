import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/document/document_errors.dart';
import '../core/document/document_models.dart';
import '../core/document/document_store.dart';
import '../core/document/path_safety.dart';

class FilesystemDocumentStore implements DocumentStore {
  @override
  Future<void> create(
    String root,
    String relativePath, {
    String initialMarkdown = '',
  }) async {
    final absolute = resolveUnderRoot(root, relativePath);
    final file = File(absolute);
    if (await file.exists()) {
      throw IoError('Already exists: $relativePath');
    }
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(initialMarkdown);
    } on FileSystemException catch (e) {
      throw IoError(e.message);
    }
  }

  @override
  Future<void> delete(String root, String relativePath) async {
    final absolute = resolveUnderRoot(root, relativePath);
    final file = File(absolute);
    if (!await file.exists()) {
      throw NotFoundError('Not found: $relativePath');
    }
    try {
      await file.delete();
    } on FileSystemException catch (e) {
      throw IoError(e.message);
    }
  }

  @override
  Future<List<DocumentEntry>> list(String root, {String? path}) async {
    final absolute = resolveUnderRoot(root, path ?? '.');
    final dir = Directory(absolute);
    if (!await dir.exists()) {
      throw NotFoundError('Not found: ${path ?? '.'}');
    }
    try {
      final entities = await dir.list().toList();
      final entries = <DocumentEntry>[];
      for (final entity in entities) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;
        final relative = toPosixRelative(root, entity.path);
        final kind = entity is Directory
            ? DocumentEntryKind.dir
            : DocumentEntryKind.file;
        DateTime? modifiedAt;
        try {
          modifiedAt = await entity.stat().then((s) => s.modified);
        } on FileSystemException {
          modifiedAt = null;
        }
        entries.add(
          DocumentEntry(
            relativePath: relative,
            name: name,
            kind: kind,
            modifiedAt: modifiedAt,
          ),
        );
      }
      entries.sort((a, b) => a.relativePath.compareTo(b.relativePath));
      return entries;
    } on FileSystemException catch (e) {
      throw IoError(e.message);
    }
  }

  @override
  Future<DocumentContent> read(String root, String relativePath) async {
    final absolute = resolveUnderRoot(root, relativePath);
    final file = File(absolute);
    if (!await file.exists()) {
      throw NotFoundError('Not found: $relativePath');
    }
    try {
      final markdown = await file.readAsString();
      final modifiedAt = await file.lastModified();
      return DocumentContent(
        relativePath: relativePath.replaceAll('\\', '/'),
        markdown: markdown,
        modifiedAt: modifiedAt,
      );
    } on FileSystemException catch (e) {
      throw IoError(e.message);
    }
  }

  @override
  Future<void> write(String root, String relativePath, String markdown) async {
    final absolute = resolveUnderRoot(root, relativePath);
    final file = File(absolute);
    if (!await file.exists()) {
      throw NotFoundError('Not found: $relativePath');
    }
    try {
      await file.writeAsString(markdown);
    } on FileSystemException catch (e) {
      throw IoError(e.message);
    }
  }
}
