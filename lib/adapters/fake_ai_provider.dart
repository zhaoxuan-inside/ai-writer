import '../core/ai/ai_errors.dart';
import '../core/ai/ai_models.dart';
import '../core/ai/ai_provider.dart';

/// Deterministic [AiProvider] for tests and offline demos.
class FakeAiProvider implements AiProvider {
  FakeAiProvider({this.requireConfigured = false, this.configured = true});

  final bool requireConfigured;
  final bool configured;

  @override
  Future<AiCompleteResult> complete(AiCompleteRequest request) async {
    if (requireConfigured && !configured) {
      throw const NotConfiguredError();
    }
    final seed = (request.selectionMarkdown?.trim().isNotEmpty ?? false)
        ? request.selectionMarkdown!.trim()
        : (request.cursorContext?.trim().isNotEmpty ?? false)
            ? request.cursorContext!.trim()
            : 'text';

    final suggestion = switch (request.mode) {
      AiAssistMode.continueWriting => '$seed …(continued)',
      AiAssistMode.rewrite => 'Rewritten: $seed',
      AiAssistMode.expand => 'Expanded: $seed\n\nMore detail here.',
      AiAssistMode.polish => 'Polished: $seed',
    };

    return AiCompleteResult(suggestionMarkdown: suggestion);
  }
}
