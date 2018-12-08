import 'timestamp_based_policy.dart';

/// Implements a FIFO (first in, first out) Policy.
/// This policy is pretty useless. Mainly it's for demo purpose.
class FifoPolicy extends TimestampBasedPolicy {
  /// When reach [maxCount], oldest files will be clean first.
  FifoPolicy({int maxCount = 999}) : super(maxCount);

  static const _KEY = 'CACHE_STORE:FIFO';
  String get storeKey => _KEY;

  Future<void> onAdded(final CacheItem item) async {
    item.payload ??= TimestampPayload();
  }
}
