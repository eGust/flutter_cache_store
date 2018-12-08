import 'dart:convert';

import '../cache_store.dart';
import '../cache_store_policy.dart';

/// [CacheItemPayload] to hold [LeastFrequentlyUsedPolicy] data
class LFUPolicy extends CacheItemPayload {
  LFUPolicy() : this.hits = [];
  LFUPolicy.from(List<int> list, {int chop}) {
    hits = list;
    if (chop != null) this.chop(chop);
  }

  List<int> hits;

  void chop(int now) {
    final size = hits.length;
    if (size == 0) return;
    if (hits[0] > now) return;
    if (hits[size - 1] < now) {
      hits = [];
      return;
    }

    for (var i = 1; i < size; i += 1) {
      if (hits[i] > now) {
        hits = hits.sublist(i);
        return;
      }
    }
  }
}

/// Implements a Least-Frequently-Used Policy.
class LeastFrequentlyUsedPolicy extends CacheStorePolicy {
  static const MAX_COUNT = 100 * 1000; // 100k

  /// When reach [maxCount], LFU file will be deleted first.
  /// [hitAge] is how long it will take count as "used" after the file been visited.
  /// Any `hit` after [hitAge] will expire.
  LeastFrequentlyUsedPolicy({
    this.maxCount = 999,
    Duration hitAge = const Duration(days: 30),
  }) : this.hitAge = hitAge.inSeconds {
    if (maxCount <= 0 || maxCount >= MAX_COUNT)
      throw RangeError.range(maxCount, 0, MAX_COUNT, 'maxCount');
  }

  final int maxCount;
  final int hitAge;

  static const _KEY = 'CACHE_STORE:LFU';
  String get storeKey => _KEY;

  Future<void> saveItems(List<CacheItem> items) async {
    final timestamps = <String, dynamic>{};
    items.forEach((item) {
      timestamps[item.key] = (item.payload as LFUPolicy).hits;
    });

    await CacheStore.prefs.setString(storeKey, jsonEncode(timestamps));
  }

  Future<Iterable<CacheItem>> cleanup(Iterable<CacheItem> allItems) async {
    final list = allItems.toList();
    final ts = now();
    for (var i = 0; i < list.length; i += 0) {
      (list[i].payload as LFUPolicy).chop(ts);
    }

    if (list.length <= maxCount) {
      saveItems(list);
      return [];
    }

    list.sort((a, b) {
      final ha = (a.payload as LFUPolicy).hits;
      final hb = (b.payload as LFUPolicy).hits;
      final cnt = hb.length - ha.length;

      return cnt != 0 ? cnt : ha.isEmpty ? 0 : hb.last - ha.last;
    });

    saveItems(list.sublist(0, maxCount));
    return list.sublist(maxCount);
  }

  int now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  Future<void> onAccessed(final CacheItem item, bool) async {
    item.payload ??= LFUPolicy();
    (item.payload as LFUPolicy).hits.add(now() + hitAge);
  }

  Future<Iterable<CacheItem>> restore(List<CacheItem> allItems) async {
    Map<String, dynamic> stored =
        jsonDecode(CacheStore.prefs.getString(storeKey) ?? '{}');

    final ts = now();
    return allItems.map((item) {
      item.payload = LFUPolicy.from(stored[item.key], chop: ts);
      return item;
    });
  }
}
