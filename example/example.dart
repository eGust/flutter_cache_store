import 'dart:io';
import 'package:flutter_cache_store/flutter_cache_store.dart';

void demo(String url) async {
  final store = await CacheStore.getInstance();
  final file = await store.getFile(url);
  // do something with file...
}

void api() async {
  // set expiration policy.
  // must be called before `CacheStore.getInstance` or will raise an exception.
  // default: LessRecentlyUsedPolicy(maxCount: 999)
  CacheStore.setPolicy(LessRecentlyUsedPolicy(maxCount: 4096));

  // get a singleton store instance
  CacheStore store = await CacheStore.getInstance(
      clearNow: true // default: false - whethere to clean up immediately
      );

  // fetch a file from an URL and cache it
  File file = await store.getFile(
    'url', // GET method
    key: null, // use custom string instead of URL
    headers: {}, // same as http.get
    flushCache: false, // whether to re-download the file
  );

  // flush specific files by keys
  await store.flush([
    'key', // key (default is the URL) passed to `getFile`
  ]);

  // remove all cached files
  await store.clearAll();
}

// Extends a Policy class and override `generateFilename`
class LRUCachePolicy extends LessRecentlyUsedPolicy {
  LRUCachePolicy({int maxCount}) : super(maxCount: maxCount);

  @override
  String generateFilename({final String key, final String url}) =>
      key; // use key as the filename
}

void customizedCacheFileStructure() async {
  // Set it as your Policy
  CacheStore.setPolicy(LRUCachePolicy(maxCount: 4096));

  // get a singleton store instance
  CacheStore store = await CacheStore.getInstance();

  // fetch a file from an URL and cache it
  String bookId = 'book123';
  String chapterId = 'ch42';
  String chapterUrl = 'https://example.com/book123/ch42';
  File file = await store.getFile(
    chapterUrl,
    key: '$bookId/$chapterId', // use IDs as path and filename
  );

  // Your file will be cached as `$TEMP/cache_store/book123/ch42`
}
