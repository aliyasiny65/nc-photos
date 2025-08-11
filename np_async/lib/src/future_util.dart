import 'dart:async';

import 'package:np_collection/np_collection.dart';

extension FutureNotNullExtension<T> on Future<T?> {
  Future<T> notNull() async => (await this)!;
}

extension FutureCollectionExtension<T> on Future<Iterable<T>> {
  Future<T> get first async => (await this).first;
}

Future<List<T>> waitOr<T>(
  Iterable<Future<T>> futures,
  T Function(Object error, StackTrace? stackTrace) onError,
) async {
  final completer = Completer<List<T>>();
  final results = List<T?>.filled(futures.length, null);
  var remaining = results.length;
  if (remaining == 0) {
    return Future.value(const []);
  }

  void onResult() {
    if (--remaining <= 0) {
      // finished
      completer.complete(results.cast<T>());
    }
  }

  for (final (:i, :e) in futures.withIndex()) {
    unawaited(
      e
          .then((value) {
            results[i] = value;
            onResult();
          })
          .onError((error, stackTrace) {
            results[i] = onError(error!, stackTrace);
            onResult();
          }),
    );
  }
  return completer.future;
}
