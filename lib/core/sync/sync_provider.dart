import 'sync_models.dart';

/// Seam: push/pull documents with overwrite semantics (no conflict merge).
abstract interface class SyncProvider {
  String get id;

  String get displayName;

  bool get requiresAccount;

  bool get isConfigured;

  Future<SyncResult> push(String root, SyncSelection selection);

  Future<SyncResult> pull(String root, SyncSelection selection);
}
