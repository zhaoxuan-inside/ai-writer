import '../core/document/document_errors.dart';
import '../core/document/document_models.dart';
import '../core/document/document_store.dart';
import '../core/document/path_safety.dart';

/// In-memory [DocumentStore] for tests and fakes.
class MemoryDocumentStore implements DocumentStore {
  MemoryDocumentStore([Map<String, String>? seed])
      : _files = {...?seed};

  /// Keys are posix relative paths from an implicit root `memory`.
  final Map<String, String> _files;

  static const _root = 'memory';

  String _key(String root, String relativePath) {
    resolveUnderRoot(root, relativePath);
    return relativePath.replaceAll('\\', '/');
  }

  @override
  Future<void> create(
    String root,
    String relativePath, {
    String initialMarkdown = '',
  }) async {
    final key = _key(root, relativePath);
    if (_files.containsKey(key)) {
      throw IoError('Already exists: $relativePath');
    }
    _files[key] = initialMarkdown;
  }

  @override
  Future<void> delete(String root, String relativePath) async {
    final key = _key(root, relativePath);
    if (!_files.containsKey(key)) {
      throw NotFoundError('Not found: $relativePath');
    }
    _files.remove(key);
  }

  @override
  Future<List<DocumentEntry>> list(String root, {String? path}) async {
    resolveUnderRoot(root, path ?? '.');
    final prefix = (path == null || path.isEmpty || path == '.')
        ? ''
        : path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');

    final names = <String, DocumentEntry>{};
    for (final key in _files.keys) {
      if (prefix.isNotEmpty) {
        if (key != prefix && !key.startsWith('$prefix/')) continue;
        if (key == prefix) continue;
      }
      final rest = prefix.isEmpty ? key : key.substring(prefix.length + 1);
      final segment = rest.split('/').first;
      final relativePath = prefix.isEmpty ? segment : '$prefix/$segment';
      final isFile = !rest.contains('/');
      names.putIfAbsent(
        relativePath,
        () => DocumentEntry(
          relativePath: relativePath,
          name: segment,
          kind: isFile ? DocumentEntryKind.file : DocumentEntryKind.dir,
        ),
      );
    }
    final entries = names.values.toList()
      ..sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return entries;
  }

  @override
  Future<DocumentContent> read(String root, String relativePath) async {
    final key = _key(root, relativePath);
    final markdown = _files[key];
    if (markdown == null) {
      throw NotFoundError('Not found: $relativePath');
    }
    return DocumentContent(relativePath: key, markdown: markdown);
  }

  @override
  Future<void> write(String root, String relativePath, String markdown) async {
    final key = _key(root, relativePath);
    if (!_files.containsKey(key)) {
      throw NotFoundError('Not found: $relativePath');
    }
    _files[key] = markdown;
  }

  /// Test helper — unused by production callers.
  Map<String, String> get debugFiles => Map.unmodifiable(_files);

  String get debugRoot => _root;
}
