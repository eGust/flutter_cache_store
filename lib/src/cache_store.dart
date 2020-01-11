import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import 'utils.dart';
import 'cache_store_policy.dart';
import 'policies/less_recently_used_policy.dart';

/// Must implement sub-class to hold the extra-data you want
abstract class CacheItemPayload {}

/// Base class to hold cache item data
class CacheItem {
  /// [store] is used to indicate the base file path [store.path]
  /// [key] is used to identify uniqueness of a file
  /// [filename] is relative path and filename to [store.path]
  CacheItem({this.store, this.key, this.filename});

  /// Returns the store owns the item
  final CacheStore store;

  /// Returns the unique key of an item
  final String key;

  /// Relative path and filename to [rootPath]
  final String filename;

  /// Holds extra-data required by a `Policy`
  CacheItemPayload payload;

  /// Absolute path of the file
  String get fullPath => '${store.path}/$filename';

  /// Converts it to `JSON` to persist the item on disk
  Map<String, dynamic> toJson() => {
        'k': key,
        'fn': filename,
      };

  /// Creates [CacheItem] from `JSON` data
  CacheItem.fromJson(CacheStore store, Map<String, dynamic> json)
      : store = store,
        key = json['k'],
        filename = json['fn'];
}

bool isValidCacheItem(CacheItem item) =>
    item.store != null &&
    item.key != null &&
    item.filename != null &&
    File(item.fullPath).existsSync();

/// Singleton object to manage cache
class CacheStore {
  /// Unique namespace
  final String namespace;
  final CacheStorePolicy policyManager;
  String get path => namespace == null ? _rootPath : '${_rootPath}__$namespace';

  /// A simple callback function to customize your own fetch method.
  /// You can change it anytime. See its interface: [CustomFetch]
  CustomFetch fetch;

  CacheStore._(this.namespace, this.policyManager);

  static final _lockCreation = new Lock();
  static final Map<String, CacheStore> _cacheStores = {};
  static SharedPreferences _prefs;
  static String _rootPath;

  /// Public `SharedPreferences` instance
  static SharedPreferences get prefs => _prefs;

  static Future<String> _getRootPath() async {
    final tmpPath = (await getTemporaryDirectory()).path;
    return '$tmpPath/$_DEFAULT_STORE_FOLDER';
  }

  static Future<void> _initStatic() async {
    _rootPath ??= await _getRootPath();
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Returns [CacheStore] instance, all parameters are optional
  /// [namespace] is unique key and must be a valid filename
  /// [policy] is [CacheStorePolicy] you want to use, [LessRecentlyUsedPolicy] by default
  /// Set [clearNow] to `true` will immediately cleanup
  /// [fetch] is a shortcut to set [CacheStore.fetch]
  static Future<CacheStore> getInstance({
    final String namespace,
    final CacheStorePolicy policy,
    final bool clearNow = false,
    final CustomFetch fetch,
  }) async {
    CacheStore instance;
    await _lockCreation.synchronized(() async {
      instance = _cacheStores[namespace];
      if (instance != null) return;

      await _initStatic();

      instance = CacheStore._(namespace, policy ?? LessRecentlyUsedPolicy());
      instance.fetch = fetch;
      await instance._init(clearNow);
    });

    return instance;
  }

  static const _PREF_KEY = 'CACHE_STORE';
  static const _DEFAULT_STORE_FOLDER = 'cache_store';

  String get prefKey => namespace == null ? _PREF_KEY : '$_PREF_KEY/$namespace';

  Future<void> _init(final bool clearNow) async {
    final Map<String, dynamic> data =
        jsonDecode(prefs.getString(prefKey) ?? '{}');
    final items = (data['cache'] as List ?? [])
        .map((json) => CacheItem.fromJson(this, json))
        .toList()
        .where(isValidCacheItem)
        .toList();

    (await policyManager.restore(items))
        .forEach((item) => _cache[item.key] = item);

    if (clearNow) {
      await _cleanup();
    }
  }

  final _cache = <String, CacheItem>{};

  /// Returns `File` based on unique [key] from cache first, by default.
  /// [key] will use [url] (including query params) when omitted.
  /// A `GET` request with [headers] will be sent to [url] when not cached.
  /// Set [flushCache] to `true` will force it to re-download the file.
  /// Optional [fetch] to override [CacheStore.fetch] for downloading.
  /// Optional [custom] data to pass to [fetch] or [CacheStore.fetch] function.
  Future<File> getFile(
    final String url, {
    final Map<String, String> headers,
    final Map<String, dynamic> custom,
    final String key,
    final CustomFetch fetch,
    final bool flushCache = false,
  }) async {
    final item = await _getItem(key, url);
    policyManager.onAccessed(item, flushCache);
    _delayCleanUp();
    return Utils.download(item, !flushCache, policyManager.onDownloaded, url,
        fetch: fetch ?? this.fetch, headers: headers, custom: custom);
  }

  /// Forces to delete cached files with keys [urlOrKeys]
  /// [urlOrKeys] is a list of keys. You may omit the key then will be the URL
  Future<void> flush(final List<String> urlOrKeys) {
    final items = urlOrKeys
        .map((key) => _cache[key])
        .where((item) => item != null)
        .toList();
    final futures = items.map(_removeFile).toList();
    futures.add(policyManager.onFlushed(items));
    return Future.wait(futures);
  }

  final _itemLock = new Lock();

  Future<CacheItem> _getItem(String key, String url) async {
    final k = key ?? url;
    var item = _cache[k];
    if (item != null) return item;

    await _itemLock.synchronized(() {
      item = _cache[k];
      if (item != null) return;

      final filename = policyManager.generateFilename(key: key, url: url);
      item = CacheItem(store: this, key: k, filename: filename);
      _cache[k] = item;
      policyManager.onAdded(item);
    });
    return item;
  }

  bool _delayedCleaning = false;
  final _cleanLock = new Lock();
  int _lastCacheHash;

  Future<void> _removeFile(CacheItem item) async {
    final file = File(item.fullPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _cleanup() => _cleanLock.synchronized(() async {
        final expired = await policyManager.cleanup(_cache.values);
        expired.forEach((item) {
          _cache.remove(item.key);
        });

        final cacheString = jsonEncode({'cache': _cache.values.toList()});
        if (_lastCacheHash == cacheString.hashCode) return;

        _lastCacheHash = cacheString.hashCode;
        await Future.wait([
          prefs.setString(prefKey, cacheString),
          _removeCachedFiles(),
        ]);
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

  /// Removes all cached files and persisted data on disk.
  /// This method should be invoked when you want to release some space on disk.
  Future<void> clearAll() => _cleanLock.synchronized(() async {
        final items = _cache.values.toList();
        _cache.clear();

        await Future.wait([
          _removeCachedFiles(all: true),
          policyManager.clearAll(items),
        ]);
      });

  Future<void> _removeCachedFiles({bool all = false}) async {
    final ts = DateTime.now();
    final dir = Directory(path);
    if (!await dir.exists()) return;

    final entries =
        await dir.list(recursive: false, followLinks: false).toList();
    final items = Set.from(all ? [] : _cache.values.map((x) => x.fullPath));

    entries.forEach((entry) async {
      if (items.contains(entry.path)) return;
      if (await FileSystemEntity.isDirectory(entry.path)) return;

      final file = File(entry.path);
      if (!all && ts.isBefore(await file.lastModified())) return;
      file.delete(recursive: false);
    });
  }
}
