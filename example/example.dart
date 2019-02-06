import 'dart:io';
import 'package:flutter_cache_store/flutter_cache_store.dart';
import 'package:http/http.dart' show Response, get, post;

// [GET STARTED]
void demo(String url) async {
  final store = await CacheStore.getInstance();
  final file = await store.getFile(url);
  // do something with file...
}

// [BASIC OPTIONS]
void api() async {
  // set expiration policy.
  // must be called before `CacheStore.getInstance` or will raise an exception.
  // default: LessRecentlyUsedPolicy(maxCount: 999)
  CacheStore.setPolicy(LessRecentlyUsedPolicy(maxCount: 4096));

  // get a singleton store instance
  CacheStore store = await CacheStore.getInstance(
    clearNow: true, // default: false - whether to clean up immediately
    httpGetter: myFetch, // default: null - a shortcut of `CacheStore.fetch`
  );

  // Optional:
  // You can change custom fetch method at anytime.
  // Set it to `null` will simply use `http.get`
  CacheStore.fetch = myFetch;

  // fetch a file from an URL and cache it
  File file = await store.getFile(
    'url', // GET method
    key: null, // use custom string instead of URL
    headers: {}, // same as http.get
    // Optional: Map<String, dynamic> any custom you want to pass to your custom fetch function.
    custom: {'method': 'POST', 'body': 'test'},
    flushCache: false, // whether to re-download the file
  );

  // flush specific files by keys
  await store.flush([
    'key', // key (default is the URL) passed to `getFile`
  ]);

  // remove all cached files
  await store.clearAll();
}

// Custom fetch function.
// A demo of how you can achieve a fetch supporting POST with body
Future<Response> myFetch(url,
    {Map<String, String> headers, Map<String, dynamic> custom}) {
  final data = custom ?? {};
  switch (data['method'] ?? '') {
    case 'POST':
      {
        return post(url, headers: headers, body: data['body']);
      }
    default:
      return get(url, headers: headers);
  }
}

// [ADVANCED USAGE]
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
