import 'cache_store.dart';
import 'utils.dart';

typedef OnDownloaded = Future<void> Function(CacheItem, Map<String, String>);

/// Base class of a `Policy`.
/// [cleanup] is the only method you must override.
/// You still need override at least one of [onAdded], [onAccessed] and [onDownloaded].
/// You may need to override [restore] as well.
///
/// You can follow the code of [TimestampBasedPolicy] and [TimestampPayload].
abstract class CacheStorePolicy {
  /// MUST override this method.
  /// You need to evict items based on the strategies.
  /// [allItems] includes all living [CacheItem] records holt by [CacheStore].
  /// You may not need it if you implemented your own data structure.
  /// Return all EXPIRED items. [CacheStore] will manage to remove them from disk.
  /// You may need to save persistent data to disk as well.
  Future<Iterable<CacheItem>> cleanup(Iterable<CacheItem> allItems);

  /// Restores persisted data when initializing.
  /// [allItems] is a list of items [CacheStore] restored from disk.
  /// Return all VALID items that still should be cached. Other files will be removed soon.
  Future<Iterable<CacheItem>> restore(List<CacheItem> allItems) async =>
      allItems;

  /// Event that triggers after an item has been added.
  /// [FifoPolicy] is a sample that only overrides this method.
  Future<void> onAdded(final CacheItem addedItem) async {}

  /// Event that triggers when the file has been visited.
  /// Both [LessRecentlyUsedPolicy] and [LeastFrequentlyUsedPolicy] are based on this event.
  Future<void> onAccessed(final CacheItem accessedItem, bool flushed) async {}

  /// Event that triggers after when http request is finished.
  /// [CacheControlPolicy] is mainly based on this event.
  Future<void> onDownloaded(
      final CacheItem item, final Map<String, String> headers) async {}

  /// Triggers after [CacheItem.flush] to clear your data.
  Future<void> onFlushed(final Iterable<CacheItem> flushedItems) async {}

  /// Override this when you need do extra work to clear your data on disk
  Future<void> clearAll(Iterable<CacheItem> allItems) async {}

  /// Override this to customize the filename with relative path on disk.
  /// There is a good example - `Cache File Structure` in `README.md`
  String generateFilename({final String key, final String url}) =>
      Utils.genName();
}
