import 'cache_store.dart';
import 'utils.dart';

typedef OnDownloaded = Future<void> Function(CacheItem, Map<String, String>);

abstract class CacheStorePolicy {
  String generateFilename({final String key, final String url}) =>
      Utils.genName();
  Future<void> clearAll(Iterable<CacheItem> allItems) async {}

  Future<void> onAdded(final CacheItem addedItem) async {}
  Future<void> onAccessed(final CacheItem accessedItem, bool flushed) async {}
  Future<void> onFlushed(final Iterable<CacheItem> flushedItems) async {}
  Future<void> onDownloaded(
      final CacheItem item, final Map<String, String> headers) async {}

  Future<Iterable<CacheItem>> cleanup(Iterable<CacheItem> allItems);
  Future<Iterable<CacheItem>> restore(List<CacheItem> allItems) async =>
      allItems;
}
