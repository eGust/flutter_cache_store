part of flutter_cache_store;

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

class LRUPayload extends CacheItemPayload {
  int accessedAt;
}

class LessRecentlyUsedPolicy extends CacheStorePolicy {
  static const _KEY = 'CACHE_STORE:LRU';
  LessRecentlyUsedPolicy({this.maxCount = 999});

  final int maxCount;

  Future<void> onAccessed(final CacheItem accessedItem, bool flushed) async {
    final LRUPayload payload = accessedItem.payload ?? LRUPayload();
    accessedItem.payload = payload;
    payload.accessedAt = DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> _save(List<CacheItem> items) async {
    final timestamps = <String, dynamic>{};
    items.forEach((item) {
      final LRUPayload p = item.payload;
      final ts = p?.accessedAt ?? DateTime.now().millisecondsSinceEpoch;
      timestamps[item.key] = ts.toString();
    });

    await CacheStore.prefs.setString(_KEY, jsonEncode(timestamps));
  }

  Future<Iterable<CacheItem>> cleanup(Iterable<CacheItem> allItems) async {
    final list = allItems.toList();
    if (list.length <= maxCount) {
      _save(list);
      return [];
    }

    list.sort((a, b) {
      final LRUPayload p1 = a.payload;
      final LRUPayload p2 = b.payload;
      return (p2?.accessedAt ?? 0) - (p1?.accessedAt ?? 0);
    });

    _save(list.sublist(0, maxCount));
    return list.sublist(maxCount);
  }

  Future<Iterable<CacheItem>> restore(List<CacheItem> allItems) async {
    Map<String, dynamic> stored =
        jsonDecode(CacheStore.prefs.getString(_KEY) ?? '{}');
    final now = DateTime.now().millisecondsSinceEpoch;
    return allItems.map((item) {
      final p = LRUPayload();
      final String ts = stored[item.key];
      p.accessedAt = ts == null ? now : int.parse(ts);
      item.payload = p;
      return item;
    });
  }
}
