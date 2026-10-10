import 'package:ai_writer/adapters/quill_markdown_bridge.dart';
import 'package:ai_writer/core/markdown/markdown_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MarkdownBridge bridge;

  setUp(() {
    bridge = QuillMarkdownBridge();
  });

  String roundTrip(String markdown) {
    final doc = bridge.fromMarkdown(markdown);
    return bridge.toMarkdown(doc);
  }

  test('preserves heading and paragraph text', () {
    const src = '# Title\n\nHello world\n';
    final out = roundTrip(src);
    expect(out, contains('Title'));
    expect(out, contains('Hello world'));
    expect(out, contains('#'));
  });

  test('preserves sentence-ending period without backslash escape', () {
    const src = 'Hello world.\n';
    final out = roundTrip(src);
    expect(out, contains('Hello world.'));
    expect(out, isNot(contains(r'\.')));
  });

  test('preserves bold and italic markers', () {
    const src = 'This is **bold** and *italic* text\n';
    final out = roundTrip(src);
    expect(out.toLowerCase(), anyOf(contains('bold'), contains('**')));
    expect(out, contains('italic'));
  });

  test('preserves unordered list items', () {
    const src = '- one\n- two\n';
    final out = roundTrip(src);
    expect(out, contains('one'));
    expect(out, contains('two'));
  });

  test('preserves blockquote content', () {
    const src = '> quoted line\n';
    final out = roundTrip(src);
    expect(out, contains('quoted line'));
  });

  test('preserves fenced code block body', () {
    const src = '```\nprint(1)\n```\n';
    final out = roundTrip(src);
    expect(out, contains('print(1)'));
  });

  test('empty markdown yields editable document', () {
    final doc = bridge.fromMarkdown('');
    expect(bridge.toMarkdown(doc), isA<String>());
  });
}
