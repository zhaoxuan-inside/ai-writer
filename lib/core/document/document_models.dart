enum DocumentEntryKind { file, dir }

class DocumentEntry {
  const DocumentEntry({
    required this.relativePath,
    required this.name,
    required this.kind,
    this.modifiedAt,
  });

  final String relativePath;
  final String name;
  final DocumentEntryKind kind;
  final DateTime? modifiedAt;
}

class DocumentContent {
  const DocumentContent({
    required this.relativePath,
    required this.markdown,
    this.modifiedAt,
  });

  final String relativePath;
  final String markdown;
  final DateTime? modifiedAt;
}
