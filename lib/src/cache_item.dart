part of flutter_cache_store;

class CacheItem {
  CacheItem({this.key, String filename, DateTime accessedAt})
      : this.filename = filename ?? _NameGenerator.next(),
        this.accessedAt = accessedAt ?? DateTime.now();
  final String key, filename;
  DateTime accessedAt;

  Map<String, dynamic> toJson() => {
        'key': key,
        'filename': filename,
        'accessedAt': accessedAt.toIso8601String(),
      };

  static CacheItem fromJson(Map<String, dynamic> json) => CacheItem(
      key: json['key'],
      filename: json['filename'],
      accessedAt: DateTime.parse(json['accessedAt']));
}
