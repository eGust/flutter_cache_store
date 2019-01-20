import 'dart:convert';

import '../cache_store.dart';
import '../cache_store_policy.dart';

export 'dart:async';
export '../cache_store.dart';

/// [CacheItemPayload] to hold a timestamp field
class TimestampPayload extends CacheItemPayload {
  TimestampPayload([int value]) {
    timestamp = value ?? DateTime.now().millisecondsSinceEpoch;
  }
  int timestamp;
}

/// Generic base class for policies based on timestamps.
/// This is a good example of how to implement a policy.
/// You can override this class if you need a timestamp-based policy.
abstract class TimestampBasedPolicy extends CacheStorePolicy {
  static const MAX_COUNT = 100 * 1000; // 100k
  TimestampBasedPolicy(this.maxCount) {
    if (maxCount <= 0 || maxCount >= MAX_COUNT)
      throw RangeError.range(maxCount, 0, MAX_COUNT, 'maxCount');
  }

  String get storeKey; // must override

  int getTimestamp(CacheItem item) =>
      (item?.payload as TimestampPayload)?.timestamp;

  void updateTimestamp(CacheItem item, [int value]) =>
      (item.payload as TimestampPayload)?.timestamp =
          value ?? DateTime.now().millisecondsSinceEpoch;

  final int maxCount;

  Future<void> saveItems(List<CacheItem> items) async {
    final timestamps = <String, dynamic>{};
    items.forEach((item) {
      final ts = getTimestamp(item) ?? DateTime.now().millisecondsSinceEpoch;
      timestamps[item.key] = ts.toString();
    });

    await CacheStore.prefs.setString(storeKey, jsonEncode(timestamps));
  }

  Future<Iterable<CacheItem>> cleanup(Iterable<CacheItem> allItems) async {
    final list = allItems.toList();
    if (list.length <= maxCount) {
      saveItems(list);
      return [];
    }

    list.sort((a, b) => (getTimestamp(a) ?? 0) - (getTimestamp(b) ?? 0));

    saveItems(list.sublist(0, maxCount));
    return list.sublist(maxCount);
  }

  Future<Iterable<CacheItem>> restore(List<CacheItem> allItems) async {
    Map<String, dynamic> stored =
        jsonDecode(CacheStore.prefs.getString(storeKey) ?? '{}');
    final now = DateTime.now().millisecondsSinceEpoch;
    return allItems.map((item) {
      final String ts = stored[item.key];
      item.payload = TimestampPayload(ts == null ? now : int.parse(ts));
      return item;
    });
  }
}
