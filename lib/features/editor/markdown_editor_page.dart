import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ai/ai_errors.dart';
import '../../core/ai/ai_models.dart';
import '../settings/settings_page.dart';

/// WYSIWYG editor (Quill) with Markdown disk authority via [MarkdownBridge].
class MarkdownEditorPage extends ConsumerStatefulWidget {
  const MarkdownEditorPage({super.key, required this.relativePath});

  final String relativePath;

  @override
  ConsumerState<MarkdownEditorPage> createState() => _MarkdownEditorPageState();
}

class _MarkdownEditorPageState extends ConsumerState<MarkdownEditorPage> {
  QuillController? _controller;
  bool _loading = true;
  bool _dirty = false;
  bool _aiBusy = false;
  Object? _error;
  String? _suggestion;
  AiAssistMode? _lastMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = ref.read(librarySessionProvider);
    final bridge = ref.read(markdownBridgeProvider);
    if (session == null) {
      setState(() {
        _error = 'No library selected';
        _loading = false;
      });
      return;
    }
    try {
      final doc = await session.open(widget.relativePath);
      if (!mounted) return;
      final quillDoc = bridge.fromMarkdown(doc.markdown);
      final controller = QuillController(
        document: quillDoc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      controller.addListener(_onDocChanged);
      setState(() {
        _controller?.dispose();
        _controller = controller;
        _loading = false;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onDocChanged() {
    if (!_dirty && mounted) {
      setState(() => _dirty = true);
    }
  }

  Future<void> _save() async {
    final session = ref.read(librarySessionProvider);
    final bridge = ref.read(markdownBridgeProvider);
    final controller = _controller;
    if (session == null || controller == null) return;
    try {
      final markdown = bridge.toMarkdown(controller.document);
      await session.save(widget.relativePath, markdown);
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  String _selectionOrContext(QuillController controller) {
    final sel = controller.selection;
    final plain = controller.document.toPlainText();
    if (sel.isValid && !sel.isCollapsed) {
      final start = sel.start.clamp(0, plain.length);
      final end = sel.end.clamp(0, plain.length);
      if (end > start) {
        return plain.substring(start, end);
      }
    }
    final offset = sel.baseOffset.clamp(0, plain.length);
    final from = (offset - 400).clamp(0, plain.length);
    return plain.substring(from, offset);
  }

  Future<void> _requestAi(AiAssistMode mode) async {
    final controller = _controller;
    if (controller == null || _aiBusy) return;
    setState(() {
      _aiBusy = true;
      _lastMode = mode;
      _suggestion = null;
    });
    final sel = controller.selection;
    final hasSelection = sel.isValid && !sel.isCollapsed;
    final text = _selectionOrContext(controller);
    final request = AiCompleteRequest(
      mode: mode,
      selectionMarkdown: hasSelection ? text : null,
      cursorContext: hasSelection ? null : text,
      documentTitle: widget.relativePath,
    );
    try {
      final result = await ref.read(aiProviderProvider).complete(request);
      if (!mounted) return;
      setState(() {
        _suggestion = result.suggestionMarkdown;
        _aiBusy = false;
      });
    } on NotConfiguredError {
      if (!mounted) return;
      setState(() => _aiBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Configure an API key in Settings'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ),
      );
    } on AiProviderException catch (e) {
      if (!mounted) return;
      setState(() => _aiBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  void _acceptSuggestion() {
    final controller = _controller;
    final suggestion = _suggestion;
    if (controller == null || suggestion == null) return;
    final sel = controller.selection;
    final plain = controller.document.toPlainText();
    if (sel.isValid && !sel.isCollapsed) {
      final start = sel.start.clamp(0, plain.length);
      final len = (sel.end - sel.start).clamp(0, plain.length - start);
      controller.replaceText(start, len, suggestion, null);
      controller.updateSelection(
        TextSelection.collapsed(offset: start + suggestion.length),
        ChangeSource.local,
      );
    } else {
      final offset = sel.isValid ? sel.baseOffset.clamp(0, plain.length) : plain.length;
      controller.replaceText(offset, 0, suggestion, null);
      controller.updateSelection(
        TextSelection.collapsed(offset: offset + suggestion.length),
        ChangeSource.local,
      );
    }
    setState(() {
      _suggestion = null;
      _dirty = true;
    });
  }

  void _rejectSuggestion() {
    setState(() => _suggestion = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _controller;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.relativePath,
          style: theme.textTheme.titleSmall,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          TextButton(
            onPressed: _dirty && !_loading ? _save : null,
            child: Text(_dirty ? 'Save' : 'Saved'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('$_error'))
              : Column(
                  children: [
                    if (controller != null)
                      QuillSimpleToolbar(
                        controller: controller,
                        config: const QuillSimpleToolbarConfig(
                          multiRowsDisplay: false,
                          showFontFamily: false,
                          showFontSize: false,
                          showColorButton: false,
                          showBackgroundColorButton: false,
                          showSearchButton: false,
                          showSubscript: false,
                          showSuperscript: false,
                          showInlineCode: true,
                          showCodeBlock: true,
                          showQuote: true,
                          showIndent: false,
                          showLink: false,
                          showUndo: true,
                          showRedo: true,
                        ),
                      ),
                    const Divider(height: 1),
                    _AiAssistStrip(
                      busy: _aiBusy,
                      onMode: _requestAi,
                    ),
                    if (_suggestion != null) ...[
                      const Divider(height: 1),
                      _AiSuggestionPanel(
                        suggestion: _suggestion!,
                        mode: _lastMode,
                        onAccept: _acceptSuggestion,
                        onReject: _rejectSuggestion,
                      ),
                    ],
                    const Divider(height: 1),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: QuillEditor.basic(
                            controller: controller!,
                            config: QuillEditorConfig(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 24,
                              ),
                              placeholder: 'Start writing…',
                              customStyles: DefaultStyles(
                                paragraph: DefaultTextBlockStyle(
                                  theme.textTheme.bodyLarge!.copyWith(
                                    fontSize: 18,
                                    height: 1.7,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  HorizontalSpacing.zero,
                                  const VerticalSpacing(0, 8),
                                  VerticalSpacing.zero,
                                  null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _AiAssistStrip extends StatelessWidget {
  const _AiAssistStrip({required this.busy, required this.onMode});

  final bool busy;
  final ValueChanged<AiAssistMode> onMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'AI',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              _chip(context, 'Continue', AiAssistMode.continueWriting),
              _chip(context, 'Rewrite', AiAssistMode.rewrite),
              _chip(context, 'Expand', AiAssistMode.expand),
              _chip(context, 'Polish', AiAssistMode.polish),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, AiAssistMode mode) {
    return ActionChip(
      label: Text(label),
      onPressed: () => onMode(mode),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AiSuggestionPanel extends StatelessWidget {
  const _AiSuggestionPanel({
    required this.suggestion,
    required this.mode,
    required this.onAccept,
    required this.onReject,
  });

  final String suggestion;
  final AiAssistMode? mode;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Suggestion${mode == null ? '' : ' · ${mode!.name}'}',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Text(
                  suggestion,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: onAccept,
                  child: const Text('Accept'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onReject,
                  child: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
