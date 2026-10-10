import 'package:flutter_quill/flutter_quill.dart';

/// Seam: Markdown (disk authority) ↔ Quill [Document] (editor state).
abstract interface class MarkdownBridge {
  Document fromMarkdown(String markdown);

  String toMarkdown(Document document);
}
