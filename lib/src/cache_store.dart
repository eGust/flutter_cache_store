part of flutter_cache_store;

class CacheStore {
  CacheStore._(this.storeName, this.maxCount, this.maxExpiration);
  final String storeName;
  final int maxCount;
  final Duration maxExpiration;

  static const _NANED_STORES = <String, CacheStore>{};
  static final _lockCreation = new Lock();
  static SharedPreferences _prefs;
  static String _tmpPath;

  static Future<CacheStore> getStoreInstance(
      {final String name,
      final bool clearExpired = false,
      final maxCount = 200,
      final Duration maxExpiration = const Duration(days: 7)}) async {
    final storeName = name ?? _DEFAULT_STORE_NAME;
    var store = _NANED_STORES[storeName];

    if (store == null) {
      await _lockCreation.synchronized(() async {
        store = _NANED_STORES[storeName];
        if (store != null) return;

        store = CacheStore._(storeName, maxCount, maxExpiration);
        _tmpPath ??= (await getTemporaryDirectory()).path;
        _prefs ??= await SharedPreferences.getInstance();
        await store._restoreOrInitData();
        _NANED_STORES[storeName] = store;
      });
    }

    if (clearExpired) {
      await store._clear();
    }
    return store;
  }

  String get folderPath => "$_tmpPath$_folder";
  String get storeKey => "$_PREF_KEY:$storeName";

  Future<void> _restoreOrInitData() async {
    final savedData = _prefs.getString(storeKey);
    final Map<String, dynamic> json = jsonDecode(savedData ?? '{}');
    _folder = json['folder'] ?? _NameGenerator.next();
    _items = (json['items'] ?? []).map(CacheItem.fromJson);
    _items.forEach((item) => _cache[item.key] = item);
  }

  final _cache = <String, CacheItem>{};
  List<CacheItem> _items;
  String _folder;

  static const _PREF_KEY = '__CACHE_STORE';
  static const _DEFAULT_STORE_NAME = '__DEFAULT';

  Future<File> getFile(final String url,
      {final Map<String, String> headers, final String key}) async {
    final itemKey = key ?? url;
    final item = _cache[itemKey] ?? await _newItem(itemKey);
    final file = File("$folderPath/${item.filename}");
    if (!(await file.exists())) {
      await _download(file, url, headers);
    }
    item.accessedAt = DateTime.now();
    return file;
  }

  static final _lockItem = new Lock();

  Future<CacheItem> _newItem(final String key) async {
    CacheItem item;
    await _lockItem.synchronized(() async {
      item = _cache[key];
      if (item != null) return;

      item = CacheItem(key: key);
      _cache[key] = item;
      _items.add(item);
      _tryClean();
    });
    return item;
  }

  static final _downloadLocks = <String, Lock>{};

  Future<void> _download(
      File file, String url, Map<String, String> headers) async {
    var lock = _downloadLocks[file.path];
    if (lock == null) {
      lock = Lock();
      _downloadLocks[file.path] = lock;
      await lock.synchronized(() async {
        final objs = await Future.wait([
          file.create(recursive: true),
          http.get(url, headers: headers),
        ]);

        final File f = objs.first;
        final http.Response response = objs.last;
        f.writeAsBytesSync(response.bodyBytes);
      });
      _downloadLocks.remove(file.path);
    } else {
      await lock.synchronized(() {});
    }
  }

  static final _lockClean = new Lock();

  void _tryClean() => _lockClean.synchronized(() async {
        if (_items.length > maxCount) {
          await _clear();
        }
      });

  Future<void> _save() => _prefs.setString(
        storeKey,
        jsonEncode({
          'folder': _folder,
          'items': _items,
        }),
      );

  Future<void> _clear({bool all = false}) async {
    final items = <CacheItem>[];
    if (all) {
      items.addAll(_items);
      _items = [];
      _cache.clear();
      Directory(folderPath).deleteSync(recursive: true);
    } else {
      _items.sort((a, b) => b.accessedAt.compareTo(a.accessedAt));
      var deleteFrom = maxCount;

      if (maxExpiration != null) {
        final expired = DateTime.now().subtract(maxExpiration);
        final index =
            _items.indexWhere((item) => item.accessedAt.isBefore(expired));
        deleteFrom = min(deleteFrom, index < 0 ? deleteFrom : index);
      }

      items.addAll(_items.sublist(deleteFrom));
      _items.removeRange(deleteFrom, _items.length);
      await Future.wait(items.map((item) async {
        _cache.remove(item.key);
        await File("$folderPath/${item.filename}").delete();
      }));
    }
    await _save();
  }

  Future<void> clearExpired() => _lockClean.synchronized(_clear);

  Future<void> clearAll() => _lockClean.synchronized(() => _clear(all: true));
}
