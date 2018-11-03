part of flutter_cache_store;

abstract class CacheStorePolicy {
  String generateFilename() => Utils.genName();
  Future<void> clearAll(Iterable<CacheItem> items) async {}

  Future<void> onAdded(final CacheItem item) async {}
  Future<void> onAccessed(final CacheItem item) async {}

  Future<Iterable<String>> cleanup(Iterable<CacheItem> items);
  Future<Iterable<CacheItem>> restore(List<CacheItem> items) async => items;
}

class LRUPayload extends CacheItemPayload {
  int accessedAt;
}

class LessRecentlyUsedPolicy extends CacheStorePolicy {
  static const _KEY = 'CACHE_STORE:LRU';
  LessRecentlyUsedPolicy({ this.maxCount = 200 });

  final int maxCount;

  Future<void> onAccessed(final CacheItem item) async {
    final LRUPayload payload = item.payload ?? LRUPayload();
    item.payload = payload;
    payload.accessedAt = DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> _save(List<CacheItem> items) async {
    final timestamps = <String, dynamic>{};
    items.forEach((item) {
      final LRUPayload p = item.payload;
      final ts = p?.accessedAt;
      timestamps[item.key] = ts?.toString();
    });

    await CacheStore.prefs.setString(_KEY, jsonEncode(timestamps));
  }

  Future<Iterable<String>> cleanup(Iterable<CacheItem> items) async {
    final list = items.toList();
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
    return list.sublist(maxCount).map((item) => item.key);
  }

  Future<Iterable<CacheItem>> restore(List<CacheItem> items) async {
    Map<String, dynamic> stored = jsonDecode(CacheStore.prefs.getString(_KEY) ?? '{}');
    final now = DateTime.now().millisecondsSinceEpoch;
    return items.map((item) {
      final p = LRUPayload();
      final String ts = stored[item.key];
      p.accessedAt = ts == null ? now : int.parse(ts);
      item.payload = p;
      return item;
    });
  }
}
