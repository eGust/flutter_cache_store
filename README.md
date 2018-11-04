# flutter_cache_store

A flexible cache manager for Flutter.

This package is highly inspired by [flutter_cache_manager](https://pub.dartlang.org/packages/flutter_cache_manager). Can be easily switched to each other.

## Quick Start

```dart
import 'package:flutter_cache_store/flutter_cache_store.dart';

void demo(String url) async {
  final store = await CacheStore.getInstance();
  final file = await store.getFile(url);
  // do something with file...
}
```

---

## APIs

```dart
void api() async {
  // set expiration policy.
  // must be called before `CacheStore.getInstance` or will raise an exception.
  // default: LessRecentlyUsedPolicy(maxCount: 200)
  CacheStore.setPolicy(policy);

  // get a singleton store instance
  CacheStore store = await CacheStore.getInstance(
    clearNow: true // default: false - where to collect expired cache immediately
  );

  // fetch a file from an URL and cache it
  File file = await store.getFile(
    'url',              // GET method
    key: null,          // use custom string instead of URL
    headers: {},        // same as http.get
    flushCache: false,  // whether to re-download the file
  );

  // flush specific files by keys
  await store.flush([
    'key', // key (default is the URL) passed to `getFile`
  ]);

  // remove all cached files
  await store.clearAll();
}
```

---

## About Policy

> Currently, there is only one policy available. More policies may be added soon.

1. `LessRecentlyUsedPolicy`

    Less Recently Used files will be removed when reached `maxCount`. Each time you access a file will update its used timestamp.

    ```dart
    new LessRecentlyUsedPolicy(
      maxCount: 999, // default: 999
    );
    ```

    > The current version is super naive. It's simply sorting all items by last used timestamp. So it still possible hits performance you because of O(N*logN) complexity with a very large number.

### How to implement your own policy

The interface is a simple abstract class. You only have to implement a few methods.

```dart
abstract class CacheStorePolicy {
  // IT'S THE ONLY METHOD YOU HAVE TO IMPLEMENT.
  // `store` will invoke this method from time to time.
  // Make sure return all expired items at once.
  // then `store` will manage to remove the cached files.
  // you also have to save your data if need to persist some data.
  Future<Iterable<CacheItem>> cleanup(Iterable<CacheItem> allItems);

  // will be invoked when store.clearAll called.
  Future<void> clearAll(Iterable<CacheItem> allItems) async {}

  // will invoke only once when the `store` is created and load saved data.
  // you need to load persistent data and restore items' payload.
  // only returned items will be cached. others will be recycled later.
  Future<Iterable<CacheItem>> restore(List<CacheItem> allItems) async => allItems;

  // event when a new `CacheItem` has been added to the cache.
  // you may need to attach a `CacheItemPayload` instance to it.
  Future<void> onAdded(final CacheItem addedItem) async {}

  // event when an item just been accessed.
  // you may need to attach or update item's payload.
  Future<void> onAccessed(final CacheItem accessedItem, bool flushed) async {}

  // event when a request just finished.
  // the response headers will be passed as well.
  Future<void> onDownloaded(final CacheItem item, final Map<String, String> headers) async {}

  // event when `store.flush` has called
  Future<void> onFlushed(final Iterable<CacheItem> flushedItems) async {}

  // filename (including path) relative to `CacheItem.rootPath`
  // usually ignore this unless need a better files structure
  String generateFilename() => Utils.genName();
}
```

* Tips

    > You don't have to implement all of the `onAdded`, `onAccessed` and `onDownloaded`. Only override the one you needed. For example:

    1. You can create a FIFO policy with `onAdded`
    2. Least Frequently Used policy can be implement with only `onAccessed`
    3. Standard http cache can just use `onDownloaded`
