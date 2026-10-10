import 'ai_models.dart';

/// Seam: AI assist completion (modes continue/rewrite/expand/polish).
abstract interface class AiProvider {
  Future<AiCompleteResult> complete(AiCompleteRequest request);
}
