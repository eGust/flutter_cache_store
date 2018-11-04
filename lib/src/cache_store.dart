part of flutter_cache_store;

class CacheStore {
  CacheStore._();

  static final _lockCreation = new Lock();
  static SharedPreferences _prefs;
  static CacheStore _instance;
  static CacheStorePolicy _adapter;

  static SharedPreferences get prefs => _prefs;

  static void setAdapter(final CacheStorePolicy adapter) {
    if (_instance != null) throw Exception('Cache store already been instantiated');
    if (adapter == null) throw Exception('Cannot pass null adapter');
    _adapter = adapter;
  }

  static Future<CacheStore> getInstance({ final bool clearNow = false }) async {
    if (_instance == null) {
      await _lockCreation.synchronized(() async {
        if (_instance != null) return;

        final tmpPath = (await getTemporaryDirectory()).path;
        CacheItem._rootPath = '$tmpPath/$_DEFAULT_STORE_FOLDER';
        _prefs = await SharedPreferences.getInstance();
        _adapter ??= LessRecentlyUsedPolicy();

        _instance = CacheStore._();
        await _instance._init(clearNow);
      });
    }

    return _instance;
  }

  static const _PREF_KEY = 'CACHE_STORE';
  static const _DEFAULT_STORE_FOLDER = 'cache_store';

  Future<void> _init(final bool clearNow) async {
    final Map<String, dynamic> data = jsonDecode(_prefs.getString(_PREF_KEY) ?? '{}');
    final items = (data['cache'] as List ?? [])
                    .map((json) => CacheItem.fromJson(json))
                    .toList();

    (await _adapter.restore(items))
      .where((item) => item.key != null && item.filename != null)
      .forEach((item) => _cache[item.key] = item);
    if (clearNow) {
      await _cleanup();
    }
  }

  final _cache = <String, CacheItem>{};

  Future<File> getFile(final String url, {
      final Map<String, String> headers,
      final String key,
    }) async {
    final itemKey = key ?? url;
    final item = await _getItem(itemKey);
    _adapter.onAccessed(item);
    _delayCleanUp();
    return Utils.download(item, url, headers);
  }

  static final _itemLock = new Lock();

  Future<CacheItem> _getItem(String key) async {
    var item = _cache[key];
    if (item != null) return item;

    await _itemLock.synchronized(() {
      item = _cache[key];
      if (item != null) return;

      item = CacheItem(key: key, filename: _adapter.generateFilename());
      _cache[key] = item;
      _adapter.onAdded(item);
    });
    return item;
  }

  static bool _delayedCleaning = false;
  static final _cleanLock = new Lock();
  int _lastCacheHash;

  Future<void> _cleanup() =>
    _cleanLock.synchronized(() async {
      final removedKeys = await _adapter.cleanup(_cache.values);
      await Future.wait(removedKeys.map((key) async {
        final item = _cache.remove(key);
        final file = File(item.fullPath);
        if (await file.exists()) {
          await file.delete();
        }
      }));

      final cacheString = jsonEncode({ 'cache': _cache.values.toList() });
      if (_lastCacheHash == cacheString.hashCode) return;

      _lastCacheHash = cacheString.hashCode;
      await _prefs.setString(_PREF_KEY, cacheString);
    });

  static const _DELAY_DURATION = Duration(seconds: 60);

  Future<void> _delayCleanUp() async {
    if (_delayedCleaning) return;

    _delayedCleaning = true;
    await Future.delayed(_DELAY_DURATION, () async {
      _delayedCleaning = false;
      await _cleanup();
    });
  }

  Future<void> clearAll() =>
    _cleanLock.synchronized(() async {
      final items = _cache.values.toList();
      _cache.clear();

      await Future.wait([
        _removeCacheFolder(),
        _adapter.clearAll(items),
      ]);
    });

  Future<void> _removeCacheFolder() async {
    final dir = Directory(CacheItem._rootPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
