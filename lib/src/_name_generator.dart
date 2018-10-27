part of flutter_cache_store;

class _NameGenerator {
  static final _rand = Random.secure();

  static void _buffWrite(final StringBuffer buff, int n) {
    while (n > 0) {
      final r = n % 62;
      n = n ~/ 62;
      buff.write(r < 10
          ? '$r'
          : String.fromCharCode(r < 36 ? 65 + r - 10 : 97 + r - 36));
    }
  }

  static String next() {
    final buff = StringBuffer();
    _buffWrite(buff, DateTime.now().microsecondsSinceEpoch);
    _buffWrite(buff, _rand.nextInt(0x7FFFFFFF));
    return buff.toString();
  }
}
