library flutter_cache_store.heap;

import 'dart:core';
import 'package:meta/meta.dart';

class PriorityQueue<T> implements Iterable<T> {
  final _items = <T>[];
  final int Function(T a, T b) _comparer;

  PriorityQueue(
      {Iterable<T> iterable, @required int Function(T a, T b) comparer})
      : this._comparer = comparer {
    if (iterable == null) return;
    _items.addAll(iterable);
    _heapifyUp();
  }

  int _leftChildOf(int parent) => parent * 2 + 1;
  int _parentOf(int child) => ((child - 1) / 2).floor();

  void _swap(int a, int b) {
    final t = _items[a];
    _items[a] = _items[b];
    _items[b] = t;
  }

  void _siftDown(int start, int end) {
    var parent = start;
    var child = _leftChildOf(parent);
    final last = end - 1;
    while (child <= last) {
      if (child < last && _comparer(_items[child], _items[child + 1]) < 0) {
        child += 1;
      }

      if (_comparer(_items[parent], _items[child]) >= 0) return;

      _swap(parent, child);
      parent = child;
      child = _leftChildOf(parent);
    }
  }

  void _siftUp(int start, int end) {
    for (var child = end - 1; child > start;) {
      final parent = _parentOf(child);
      if (_comparer(_items[parent], _items[child]) >= 0) return;

      _swap(parent, child);
      child = parent;
    }
  }

  void _heapifyUp() {
    final size = length;
    for (var i = 2; i <= size; i += 1) {
      _siftUp(0, i);
    }
  }

  void add(T value) {
    _items.add(value);
    _siftUp(0, length);
  }

  void push(T value) => add(value);

  void addAll(Iterable<T> iterable) {
    iterable.forEach(add);
  }

  T pop() {
    final r = first;
    if (isNotEmpty) {
      final t = _items.removeAt(length - 1);
      if (isNotEmpty) {
        _items[0] = t;
        _siftDown(0, length);
      }
    }
    return r;
  }

  T get peek => first;

  @override
  bool any(bool Function(T element) test) {
    return _items.any(test);
  }

  @override
  Iterable<R> cast<R>() {
    return _items.cast();
  }

  @override
  bool contains(Object element) {
    return _items.contains(element);
  }

  @override
  T elementAt(int index) {
    return _items.elementAt(index);
  }

  @override
  bool every(bool Function(T element) test) {
    return _items.every(test);
  }

  @override
  T get first => _items.first;

  @override
  T firstWhere(bool Function(T element) test, {T Function() orElse}) {
    return _items.firstWhere(test, orElse: orElse);
  }

  @override
  Iterable<T> followedBy(Iterable<T> other) {
    return _items.followedBy(other);
  }

  @override
  void forEach(void Function(T element) f) {
    _items.forEach(f);
  }

  @override
  bool get isEmpty => _items.isEmpty;

  @override
  bool get isNotEmpty => _items.isNotEmpty;

  @override
  Iterator<T> get iterator => _items.iterator;

  @override
  String join([String separator = ""]) {
    return _items.join(separator);
  }

  @override
  T get last => _items.last;

  @override
  T lastWhere(bool Function(T element) test, {T Function() orElse}) {
    return null;
  }

  @override
  int get length => _items.length;

  @override
  T reduce(T Function(T value, T element) combine) {
    return _items.reduce(combine);
  }

  @override
  T get single => _items.single;

  @override
  T singleWhere(bool Function(T element) test, {T Function() orElse}) {
    return _items.singleWhere(test);
  }

  @override
  Iterable<T> skip(int count) {
    return _items.skip(count);
  }

  @override
  Iterable<T> skipWhile(bool Function(T value) test) {
    return _items.skipWhile(test);
  }

  @override
  Iterable<T> take(int count) {
    if (count <= 0) return [];
    final result = <T>[];
    for (var i = count; i > 0 && isNotEmpty; i -= 1) {
      result.add(pop());
    }
    return result;
  }

  @override
  Iterable<T> takeWhile(bool Function(T value) test) {
    return _items.takeWhile(test);
  }

  @override
  List<T> toList({bool growable = true}) {
    return _items.toList();
  }

  @override
  Set<T> toSet() {
    return _items.toSet();
  }

  @override
  Iterable<T> where(bool Function(T element) test) {
    return _items.where(test);
  }

  @override
  Iterable<T> whereType<T>() {
    return _items.whereType();
  }

  @override
  Iterable<E> expand<E>(Iterable<E> Function(T element) f) {
    return _items.expand(f);
  }

  @override
  E fold<E>(E initialValue, E Function(E previousValue, T element) combine) {
    return _items.fold(initialValue, combine);
  }

  @override
  Iterable<E> map<E>(E Function(T e) f) {
    return _items.map(f);
  }
}
