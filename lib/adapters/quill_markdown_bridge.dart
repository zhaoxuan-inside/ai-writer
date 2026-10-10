import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

import '../core/markdown/markdown_bridge.dart';

class QuillMarkdownBridge implements MarkdownBridge {
  QuillMarkdownBridge()
      : _mdToDelta = MarkdownToDelta(
          markdownDocument: md.Document(
            encodeHtml: false,
            extensionSet: md.ExtensionSet.gitHubFlavored,
          ),
        ),
        _deltaToMd = DeltaToMarkdown();

  final MarkdownToDelta _mdToDelta;
  final DeltaToMarkdown _deltaToMd;

  @override
  Document fromMarkdown(String markdown) {
    final input = markdown.isEmpty ? '\n' : markdown;
    try {
      final delta = _mdToDelta.convert(input);
      if (delta.isEmpty) {
        return Document();
      }
      return Document.fromDelta(delta);
    } catch (_) {
      // Conservative fallback: plain text paragraph (PRD: do not silently drop body).
      return Document.fromDelta(
        Delta()
          ..insert(input.endsWith('\n') ? input : '$input\n'),
      );
    }
  }

  @override
  String toMarkdown(Document document) {
    return _deltaToMd.convert(document.toDelta());
  }
}
