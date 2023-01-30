import 'dart:math';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:synchronized/synchronized.dart';
import '../flutter_cache_store.dart';

/// Custom Fetch method interface
/// Optional parameter [custom] (`Map<String, dynamic>`) you can pass with [getFile]
typedef CustomFetch = Future<http.Response> Function(String url,
    {Map<String, String> headers, Map<String, dynamic> custom});

Future<http.Response> _defaultGetter(String url,
        {Map<String, String> headers, Map<String, dynamic> custom}) =>
    http.get(Uri.parse(url), headers: headers);

/// Some helpers for internal usage
class Utils {
  static final _rand = Random.secure();
  static const _EFF_TIME_FLAG = 0x2000 * (1 << 32) - 1; // 407+ day

  // 0-9, A..Z, _, `, a..z
  static int _c64(final int x) {
    if (x < 10) return 48 + x;
    if (x < 36) return 65 + x - 10;
    return 95 + x - 36;
  }

  /// Returns a random number based on timestamp. This number repeat every ~407 days
  static int genNow() => DateTime.now().microsecondsSinceEpoch & _EFF_TIME_FLAG;

  /// Returns a random filename with 11 chars based on timestamp
  static String genName() {
    final codes = List<int>.filled(11, 0);
    var x = genUniqId();
    codes[0] = _c64(((x & 0x7000000000000000) >> 60) | (x < 0 ? 8 : 0));
    x &= (1 << 60) - 1;
    for (var i = 10; i > 0; i -= 1, x >>= 6) {
      codes[i] = _c64(x & 0x3F);
    }
    return String.fromCharCodes(codes);
  }

  /// Generates a random number combined based on timestamp
  static int genUniqId() => (_rand.nextInt(0x80000) << 45) | genNow();

  static final _downloadLocks = <String, Lock>{};

  /// Makes a `GET` request to [url] and save it to [item.fullPath]
  /// [url] and Optional [headers] parameters will pass to `http.get`
  /// set [useCache] to `false` will force downloading regardless cached or not
  /// [onDownloaded] event triggers when downloading is finished
  static Future<File> download(
    CacheItem item,
    bool useCache,
    OnDownloaded onDownloaded,
    String url, {
    CustomFetch fetch,
    Map<String, String> headers,
    Map<String, dynamic> custom,
  }) async {
    final file = File(item.fullPath);
    final key = item.filename;
    if (useCache &&
        await file.exists() &&
        ((_downloadLocks.containsKey(key) && _downloadLocks[key] == null) ||
            await file.length() != 0)) {
      return file;
    }

    var lock = _downloadLocks[key];
    if (lock == null) {
      lock = Lock();
      _downloadLocks[key] = lock;
      try {
        await lock.synchronized(() async {
          final results = await Future.wait([
            file.create(recursive: true),
            (fetch ?? _defaultGetter)(url, headers: headers, custom: custom),
          ]);

          final File f = results.first;
          final http.Response response = results.last;

          await Future.wait([
            onDownloaded(item, response.headers),
            f.writeAsBytes(response.bodyBytes),
          ]);
        });
      } finally {
        _downloadLocks[key] = null;
      }
    } else {
      await lock.synchronized(() {});
    }
    return file;
  }
}
