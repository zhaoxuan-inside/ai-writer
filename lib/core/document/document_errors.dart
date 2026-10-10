sealed class DocumentStoreException implements Exception {
  const DocumentStoreException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class PathEscapeError extends DocumentStoreException {
  const PathEscapeError(super.message);
}

class NotFoundError extends DocumentStoreException {
  const NotFoundError(super.message);
}

class IoError extends DocumentStoreException {
  const IoError(super.message);
}
