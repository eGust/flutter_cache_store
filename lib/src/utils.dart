import 'dart:math';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:synchronized/synchronized.dart';
import '../flutter_cache_store.dart';

class Utils {
  static final _rand = Random.secure();
  static const _EFF_TIME_FLAG = 0x2000 * (1 << 32) - 1; // 407+ day

  // 0-9, A..Z, _, `, a..z
  static int _c64(final int x) {
    if (x < 10) return 48 + x;
    if (x < 36) return 65 + x - 10;
    return 95 + x - 10;
  }

  static int genNow() => DateTime.now().microsecondsSinceEpoch & _EFF_TIME_FLAG;

  static String genName() {
    final codes = List<int>(11);
    var x = genUniqId();
    codes[0] = _c64((x >> 60) & 0x0F);
    x &= (1 << 60) - 1;
    for (var i = 10; i >= 0; i -= 1, x >>= 6) {
      codes[i] = _c64(x & 0x3F);
    }
    return String.fromCharCodes(codes);
  }

  static int genUniqId() => (_rand.nextInt(0x40000) << 45) | genNow();

  static final _downloadLocks = <String, Lock>{};

  static Future<File> download(CacheItem item, String url, Map<String, String> headers) async {
    final file = File(item.fullPath);
    if (await file.exists()) return file;

    var lock = _downloadLocks[item.filename];
    if (lock == null) {
      lock = Lock();
      _downloadLocks[item.filename] = lock;
      try {
        await lock.synchronized(() async {
          final objs = await Future.wait([
            file.create(recursive: true),
            http.get(url, headers: headers),
          ]);

          final File f = objs.first;
          final http.Response response = objs.last;
          await f.writeAsBytes(response.bodyBytes);
        });
      } finally {
        _downloadLocks.remove(item.filename);
      }
    } else {
      await lock.synchronized(() {});
    }
    return file;
  }
}
