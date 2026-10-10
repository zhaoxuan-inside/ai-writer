sealed class AiProviderException implements Exception {
  const AiProviderException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class NotConfiguredError extends AiProviderException {
  const NotConfiguredError([
    super.message = 'API key not configured',
  ]);
}

class ProviderError extends AiProviderException {
  const ProviderError(super.message);
}
