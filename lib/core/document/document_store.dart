import 'document_models.dart';

/// Seam: library-root-scoped document persistence (Markdown as authority).
abstract interface class DocumentStore {
  Future<List<DocumentEntry>> list(String root, {String? path});

  Future<DocumentContent> read(String root, String relativePath);

  Future<void> write(String root, String relativePath, String markdown);

  Future<void> create(
    String root,
    String relativePath, {
    String initialMarkdown = '',
  });

  Future<void> delete(String root, String relativePath);
}
