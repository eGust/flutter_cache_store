import 'timestamp_based_policy.dart';

class FifoPolicy extends TimestampBasedPolicy {
  FifoPolicy({int maxCount = 999}) : super(maxCount);

  static const _KEY = 'CACHE_STORE:FIFO';
  String get storeKey => _KEY;

  Future<void> onAdded(final CacheItem item) async {
    item.payload ??= TimestampPayload();
  }
}
