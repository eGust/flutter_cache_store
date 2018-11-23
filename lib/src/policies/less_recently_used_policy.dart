import 'timestamp_based_policy.dart';

class LessRecentlyUsedPolicy extends TimestampBasedPolicy {
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
