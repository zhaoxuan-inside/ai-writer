enum AiAssistMode {
  continueWriting,
  rewrite,
  expand,
  polish,
}

class AiCompleteRequest {
  const AiCompleteRequest({
    required this.mode,
    this.selectionMarkdown,
    this.cursorContext,
    this.documentTitle,
    this.model,
  });

  final AiAssistMode mode;
  final String? selectionMarkdown;
  final String? cursorContext;
  final String? documentTitle;
  final String? model;
}

class AiCompleteResult {
  const AiCompleteResult({
    required this.suggestionMarkdown,
    this.raw,
  });

  final String suggestionMarkdown;
  final String? raw;
}

class AiProviderConfig {
  const AiProviderConfig({
    required this.baseUrl,
    required this.apiKey,
    this.model = 'gpt-4o-mini',
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  bool get isConfigured =>
      apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty;
}
