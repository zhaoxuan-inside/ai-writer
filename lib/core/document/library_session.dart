import 'document_models.dart';
import 'document_store.dart';

/// Application use-cases over [DocumentStore] for one library root.
class LibrarySession {
  LibrarySession({
    required this.root,
    required DocumentStore store,
  }) : _store = store;

  final String root;
  final DocumentStore _store;

  Future<List<DocumentEntry>> list({String? path}) =>
      _store.list(root, path: path);

  Future<DocumentContent> open(String relativePath) =>
      _store.read(root, relativePath);

  Future<void> save(String relativePath, String markdown) =>
      _store.write(root, relativePath, markdown);

  Future<void> createNew(String relativePath, {String initialMarkdown = ''}) =>
      _store.create(root, relativePath, initialMarkdown: initialMarkdown);
}
