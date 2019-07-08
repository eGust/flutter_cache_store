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
  static String _rootPath;

  /// Returns the path where files will be cached
  static String get rootPath => _rootPath;

  /// [key] is used to identify uniqueness of a file
  /// [filename] is relative path and filename to [rootPath]
  CacheItem({this.key, this.filename});

  /// Returns the unique key of an item
  final String key;

  /// Relative path and filename to [rootPath]
  final String filename;

  /// Holds extra-data required by a `Policy`
  CacheItemPayload payload;

  /// Absolute path of the file
  String get fullPath => '$_rootPath/$filename';

  /// Converts it to `JSON` to persist the item on disk
  Map<String, dynamic> toJson() => {
        'key': key,
        'filename': filename,
      };

  /// Creates [CacheItem] from `JSON` data
  CacheItem.fromJson(Map<String, dynamic> json)
      : key = json['k'],
        filename = json['fn'];
}

/// Singleton object to manage cache
class CacheStore {
  CacheStore._();

  static final _lockCreation = new Lock();
  static SharedPreferences _prefs;
  static CacheStore _instance;
  static CacheStorePolicy _policyManager;

  /// A simple callback function to customize your own fetch method.
  /// You can change it anytime. See its interface: [CustomFetch]
  static CustomFetch fetch;

  /// Public `SharedPreferences` instance
  static SharedPreferences get prefs => _prefs;

  /// Must be called before [getInstance] or you will get an `Exception`.
  /// You can create your own [CacheStorePolicy]
  static void setPolicy(final CacheStorePolicy policy) {
    if (_instance != null)
      throw Exception('Cache store already been instantiated');
    if (policy == null) throw Exception('Cannot pass null policy');
    _policyManager = policy;
  }

  /// Returns singleton of [CacheStore]
  /// Set [clearNow] to `true` will immediately cleanup
  /// [httpGetter] is a shortcut to [CacheStore.fetch]
  static Future<CacheStore> getInstance({
    final bool clearNow = false,
    final CustomFetch httpGetter,
  }) async {
    fetch = httpGetter;
    if (_instance == null) {
      await _lockCreation.synchronized(() async {
        if (_instance != null) return;

        final tmpPath = (await getTemporaryDirectory()).path;
        CacheItem._rootPath = '$tmpPath/$_DEFAULT_STORE_FOLDER';
        _prefs = await SharedPreferences.getInstance();
        _policyManager ??= LessRecentlyUsedPolicy();

        _instance = CacheStore._();
        await _instance._init(clearNow);
      });
    }

    return _instance;
  }

  static const _PREF_KEY = 'CACHE_STORE';
  static const _DEFAULT_STORE_FOLDER = 'cache_store';
  static List<CacheItem> _recycledItems;

  Future<void> _init(final bool clearNow) async {
    final Map<String, dynamic> data =
        jsonDecode(_prefs.getString(_PREF_KEY) ?? '{}');
    final items = (data['cache'] as List ?? [])
        .map((json) => CacheItem.fromJson(json))
        .toList();

    (await _policyManager.restore(items))
        .where((item) => item.key != null && item.filename != null)
        .forEach((item) => _cache[item.key] = item);

    final recycled =
        items.where((item) => !_cache.containsKey(item.key)).toList();
    _recycledItems = recycled.isEmpty ? null : recycled;

    if (clearNow) {
      await _cleanup();
    }
  }

  final _cache = <String, CacheItem>{};

  /// Returns `File` based on unique [key] from cache first, by default.
  /// [key] will use [url] (including query params) when omitted.
  /// A `GET` request with [headers] will be sent to [url] when not cached.
  /// Set [flushCache] to `true` will force it to re-download the file.
  /// Optional [fetch] to override global [CustomFetch] for downloading.
  /// Optional [custom] to pass to [CustomFetch] function.
  Future<File> getFile(
    final String url, {
    final Map<String, String> headers,
    final Map<String, dynamic> custom,
    final String key,
    final CustomFetch fetch,
    final bool flushCache = false,
  }) async {
    final item = await _getItem(key, url);
    _policyManager.onAccessed(item, flushCache);
    _delayCleanUp();
    return Utils.download(item, !flushCache, _policyManager.onDownloaded, url,
        fetch: fetch ?? CacheStore.fetch, headers: headers, custom: custom);
  }

  /// Forces to delete cached files with keys [urlOrKeys]
  /// [urlOrKeys] is a list of keys. You may omit the key then will be the URL
  Future<void> flush(final List<String> urlOrKeys) {
    final items = urlOrKeys
        .map((key) => _cache[key])
        .where((item) => item != null)
        .toList();
    final futures = items.map(_removeFile).toList();
    futures.add(_policyManager.onFlushed(items));
    return Future.wait(futures);
  }

  static final _itemLock = new Lock();

  Future<CacheItem> _getItem(String key, String url) async {
    final k = key ?? url;
    var item = _cache[k];
    if (item != null) return item;

    await _itemLock.synchronized(() {
      item = _cache[k];
      if (item != null) return;

      final filename = _policyManager.generateFilename(key: key, url: url);
      item = CacheItem(key: k, filename: filename);
      _cache[k] = item;
      _policyManager.onAdded(item);
    });
    return item;
  }

  static bool _delayedCleaning = false;
  static final _cleanLock = new Lock();
  int _lastCacheHash;

  Future<void> _removeFile(CacheItem item) async {
    final file = File(item.fullPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _cleanup() => _cleanLock.synchronized(() async {
        if (_recycledItems != null) {
          final items = _recycledItems;
          _recycledItems = null;
          await Future.wait(items.map(_removeFile));
        }

        final removedKeys = await _policyManager.cleanup(_cache.values);
        await Future.wait(
            removedKeys.map((item) => _removeFile(_cache.remove(item.key))));

        final cacheString = jsonEncode({'cache': _cache.values.toList()});
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

  /// Removes all cached files and persisted data on disk.
  /// This method should be invoked when you want to release some space on disk.
  Future<void> clearAll() => _cleanLock.synchronized(() async {
        final items = _cache.values.toList();
        _cache.clear();

        await Future.wait([
          _removeCacheFolder(),
          _policyManager.clearAll(items),
        ]);
      });

  Future<void> _removeCacheFolder() async {
    final dir = Directory(CacheItem._rootPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
