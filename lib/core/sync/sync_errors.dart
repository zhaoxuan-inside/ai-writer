sealed class SyncProviderException implements Exception {
  const SyncProviderException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class SyncNotConfiguredError extends SyncProviderException {
  const SyncNotConfiguredError([
    super.message = 'Sync provider is not configured',
  ]);
}

class SyncNotEnabledError extends SyncProviderException {
  const SyncNotEnabledError([
    super.message = 'Native cloud sync is not enabled yet',
  ]);
}

class SyncIoError extends SyncProviderException {
  const SyncIoError(super.message);
}
