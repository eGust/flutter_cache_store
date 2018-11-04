part of flutter_cache_store;

abstract class CacheItemPayload {}

class CacheItem {
  static String _rootPath;
  static String get rootPath => _rootPath;

  CacheItem({this.key, this.filename});

  final String key, filename;
  CacheItemPayload payload;

  String get fullPath => '$_rootPath/$filename';

  Map<String, dynamic> toJson() => {
        'key': key,
        'filename': filename,
      };

  CacheItem.fromJson(Map<String, dynamic> json)
      : key = json['k']
      , filename = json['fn']
      ;
}
