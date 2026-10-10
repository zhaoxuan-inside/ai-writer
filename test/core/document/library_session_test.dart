import 'package:ai_writer/adapters/memory_document_store.dart';
import 'package:ai_writer/core/document/library_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('open and save update store content', () async {
    const root = 'C:/lib';
    final store = MemoryDocumentStore({'essay.md': '# Draft\n'});
    final session = LibrarySession(root: root, store: store);

    final opened = await session.open('essay.md');
    expect(opened.markdown, '# Draft\n');

    await session.save('essay.md', '# Final\n');
    expect((await session.open('essay.md')).markdown, '# Final\n');
  });

  test('createNew then open', () async {
    const root = 'C:/lib';
    final store = MemoryDocumentStore();
    final session = LibrarySession(root: root, store: store);
    await session.createNew('new.md', initialMarkdown: 'hi');
    expect((await session.open('new.md')).markdown, 'hi');
  });
}
