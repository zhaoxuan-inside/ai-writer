import '../core/sync/sync_errors.dart';
import '../core/sync/sync_models.dart';
import '../core/sync/sync_provider.dart';

/// Commercial native-cloud placeholder. Same seam; not enabled in MVP.
class NativeCloudStubSyncProvider implements SyncProvider {
  @override
  String get id => SyncProviderId.nativeCloud.wire;

  @override
  String get displayName => 'AI Writer Cloud (coming soon)';

  @override
  bool get requiresAccount => false;

  @override
  bool get isConfigured => true;

  @override
  Future<SyncResult> push(String root, SyncSelection selection) async {
    throw const SyncNotEnabledError();
  }

  @override
  Future<SyncResult> pull(String root, SyncSelection selection) async {
    throw const SyncNotEnabledError();
  }
}
