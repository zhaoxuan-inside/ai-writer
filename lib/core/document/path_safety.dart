import 'package:path/path.dart' as p;

import 'document_errors.dart';

/// Resolves [relativePath] under [root] or throws [PathEscapeError].
String resolveUnderRoot(String root, String relativePath) {
  final normalizedRoot = p.normalize(p.absolute(root));
  final cleaned = relativePath.replaceAll('\\', '/');
  if (cleaned.isEmpty || cleaned == '.') {
    return normalizedRoot;
  }
  if (p.isAbsolute(cleaned) ||
      cleaned.split('/').contains('..') ||
      cleaned.startsWith('/')) {
    throw PathEscapeError('Path escapes library root: $relativePath');
  }

  final joined = p.normalize(p.join(normalizedRoot, cleaned));
  final rootPrefix = normalizedRoot.endsWith(p.separator)
      ? normalizedRoot
      : '$normalizedRoot${p.separator}';
  if (joined != normalizedRoot && !joined.startsWith(rootPrefix)) {
    throw PathEscapeError('Path escapes library root: $relativePath');
  }
  return joined;
}

String toPosixRelative(String root, String absolutePath) {
  final normalizedRoot = p.normalize(p.absolute(root));
  final relative = p.relative(absolutePath, from: normalizedRoot);
  return relative.replaceAll('\\', '/');
}
