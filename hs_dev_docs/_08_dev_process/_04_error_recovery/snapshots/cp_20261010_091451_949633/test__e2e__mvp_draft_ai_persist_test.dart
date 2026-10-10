import 'dart:io';

import 'package:ai_writer/adapters/fake_ai_provider.dart';
import 'package:ai_writer/adapters/filesystem_document_store.dart';
import 'package:ai_writer/adapters/folder_sync_provider.dart';
import 'package:ai_writer/adapters/quill_markdown_bridge.dart';
import 'package:ai_writer/core/ai/ai_errors.dart';
import 'package:ai_writer/core/ai/ai_models.dart';
import 'package:ai_writer/core/document/library_session.dart';
import 'package:ai_writer/core/sync/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Desktop MVP main path: draft → AI rewrite accept → local persist → reopen.
void main() {
  late Directory library;
  late LibrarySession session;
  late FakeAiProvider ai;
  final bridge = QuillMarkdownBridge();

  setUp(() async {
    library = await Directory.systemTemp.createTemp('ai_writer_mvp_e2e_');
    session = LibrarySession(
      root: library.path,
      store: FilesystemDocumentStore(),
    );
    ai = FakeAiProvider();
  });

  tearDown(() async {
    if (await library.exists()) await library.delete(recursive: true);
  });

  test('draft → AI rewrite accept → save → reopen preserves markdown', () async {
    await session.createNew(
      'essay.md',
      initialMarkdown: '# Essay\n\nHello world.\n',
    );

    final opened = await session.open('essay.md');
    final editorDoc = bridge.fromMarkdown(opened.markdown);
    expect(bridge.toMarkdown(editorDoc), contains('Hello world'));

    final result = await ai.complete(
      const AiCompleteRequest(
        mode: AiAssistMode.rewrite,
        selectionMarkdown: 'Hello world.',
        documentTitle: 'essay.md',
      ),
    );
    expect(result.suggestionMarkdown, 'Rewritten: Hello world.');

    // Accept = replace selection (same seam as editor _acceptSuggestion).
    final acceptedMarkdown = opened.markdown.replaceFirst(
      'Hello world.',
      result.suggestionMarkdown,
    );
    await session.save('essay.md', acceptedMarkdown);

    final reopened = await session.open('essay.md');
    expect(reopened.markdown, contains('Rewritten: Hello world.'));
    expect(reopened.markdown, isNot(contains('\nHello world.\n')));

    final roundTrip = bridge.toMarkdown(bridge.fromMarkdown(reopened.markdown));
    expect(roundTrip, contains('Rewritten: Hello world.'));
  });

  test('AI NotConfigured does not block local save', () async {
    final offlineAi = FakeAiProvider(requireConfigured: true, configured: false);
    await session.createNew('local.md', initialMarkdown: 'only local\n');

    expect(
      () => offlineAi.complete(
        const AiCompleteRequest(
          mode: AiAssistMode.continueWriting,
          cursorContext: 'only local',
        ),
      ),
      throwsA(isA<NotConfiguredError>()),
    );

    await session.save('local.md', 'only local\nstill saved\n');
    expect(
      (await session.open('local.md')).markdown,
      'only local\nstill saved\n',
    );
  });

  test('folder sync push then pull overwrite round-trip', () async {
    final remote = await Directory.systemTemp.createTemp('ai_writer_mvp_remote_');
    addTearDown(() async {
      if (await remote.exists()) await remote.delete(recursive: true);
    });

    await session.createNew('note.md', initialMarkdown: 'v1\n');
    final sync = FolderSyncProvider(remoteFolder: remote.path);

    final push = await sync.push(
      library.path,
      const SyncSelection.paths(['note.md']),
    );
    expect(push.ok, isTrue);
    expect(await File(p.join(remote.path, 'note.md')).readAsString(), 'v1\n');

    await File(p.join(remote.path, 'note.md')).writeAsString('v2-remote\n');
    final pull = await sync.pull(
      library.path,
      const SyncSelection.paths(['note.md']),
    );
    expect(pull.ok, isTrue);
    expect((await session.open('note.md')).markdown, 'v2-remote\n');
  });
}
