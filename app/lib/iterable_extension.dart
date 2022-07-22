import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nc_photos/list_extension.dart';
import 'package:nc_photos/override_comparator.dart';
import 'package:tuple/tuple.dart';

extension IterableExtension<T> on Iterable<T> {
  /// Return a new sorted list
  List<T> sorted([int Function(T a, T b)? compare]) => toList()..sort(compare);

  /// Return a new stable sorted list
  List<T> stableSorted([int Function(T a, T b)? compare]) =>
      toList()..stableSort(compare);

  /// Return a string representation of this iterable by joining the result of
  /// toString for each items
  String toReadableString() => "[${join(', ')}]";

  Iterable<U> mapWithIndex<U>(U Function(int index, T element) fn) sync* {
    int i = 0;
    for (final e in this) {
      yield fn(i++, e);
    }
  }

  Iterable<Tuple2<int, T>> withIndex() => mapWithIndex((i, e) => Tuple2(i, e));

  /// Whether the collection contains an element equal to [element] using the
  /// equality function [equalFn]
  bool containsIf(T element, bool Function(T a, T b) equalFn) =>
      any((e) => equalFn(e, element));

  /// Same as [contains] but uses [identical] to compare the objects
  bool containsIdentical(T element) =>
      containsIf(element, (a, b) => identical(a, b));

  Iterable<Tuple2<U, List<T>>> groupBy<U>({required U Function(T e) key}) {
    final map = fold<Map<U, List<T>>>(
        {},
        (previousValue, element) =>
            previousValue..putIfAbsent(key(element), () => []).add(element));
    return map.entries.map((e) => Tuple2(e.key, e.value));
  }

  /// Return a new list with only distinct elements
  List<T> distinct() {
    final s = <T>{};
    return where((element) => s.add(element)).toList();
  }

  /// Return a new list with only distinct elements determined by [equalFn]
  List<T> distinctIf(
      bool Function(T a, T b) equalFn, int Function(T a) hashCodeFn) {
    final s = <OverrideComparator<T>>{};
    return where((element) =>
        s.add(OverrideComparator<T>(element, equalFn, hashCodeFn))).toList();
  }

  /// Invokes [action] on each element of this iterable in iteration order
  /// lazily
  Iterable<T> forEachLazy(void Function(T element) action) sync* {
    for (final e in this) {
      action(e);
      yield e;
    }
  }

  Future<List<U>> computeAll<U>(ComputeCallback<T, U> callback) async {
    final list = asList();
    if (list.isEmpty) {
      return [];
    } else {
      return await compute(
          _computeAllImpl<T, U>, _ComputeAllMessage(callback, list));
    }
  }

  /// Return a list containing elements in this iterable
  ///
  /// If this Iterable is itself a list, this will be returned directly with no
  /// copying
  List<T> asList() {
    if (this is List) {
      return this as List<T>;
    } else {
      return toList();
    }
  }

  /// The first index of [element] in this iterable
  ///
  /// Searches the list from index start to the end of the list. The first time
  /// an object o is encountered so that o == element, the index of o is
  /// returned. Returns -1 if element is not found.
  int indexOf(T element, [int start = 0]) {
    var i = 0;
    for (final e in this) {
      if (e == element) {
        return i;
      }
      ++i;
    }
    return -1;
  }
}

extension IterableFlattenExtension<T> on Iterable<Iterable<T>> {
  /// Flattens an [Iterable] of [Iterable] values of type [T] to a [Iterable] of
  /// values of type [T].
  ///
  /// This function originated in the xml package
  Iterable<T> flatten() => expand((values) => values);
}

class _ComputeAllMessage<T, U> {
  const _ComputeAllMessage(this.callback, this.data);

  final ComputeCallback<T, U> callback;
  final List<T> data;
}

Future<List<U>> _computeAllImpl<T, U>(_ComputeAllMessage<T, U> message) async {
  final result = await Future.wait(
      message.data.map((e) async => await message.callback(e)));
  return result;
}
