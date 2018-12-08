import 'timestamp_based_policy.dart';

/// Implements a Less-Recently-Used Policy.
/// This is the default policy if you dont specify a policy in [CacheStore.setPolicy].
class LessRecentlyUsedPolicy extends TimestampBasedPolicy {
  /// When reach [maxCount], LRU file will be deleted first.
  LessRecentlyUsedPolicy({int maxCount = 999}) : super(maxCount);

  static const _KEY = 'CACHE_STORE:LRU';
  String get storeKey => _KEY;

  Future<void> onAccessed(final CacheItem item, bool) async {
    if (item.payload == null)
      item.payload = TimestampPayload();
    else
      updateTimestamp(item);
  }
}
