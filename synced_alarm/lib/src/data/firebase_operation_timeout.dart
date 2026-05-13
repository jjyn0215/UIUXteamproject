import 'dart:async';

const defaultFirebaseOperationTimeout = Duration(seconds: 12);

class FirebaseOperationTimeoutException implements Exception {
  const FirebaseOperationTimeoutException(this.operationName, this.timeout);

  final String operationName;
  final Duration timeout;

  @override
  String toString() {
    return 'Firebase $operationName did not finish within '
        '${timeout.inSeconds}s. Check Firebase Authentication setup, '
        'network access, and project configuration.';
  }
}

Future<T> withFirebaseOperationTimeout<T>(
  Future<T> future, {
  required String operationName,
  Duration timeout = defaultFirebaseOperationTimeout,
}) {
  return future.timeout(
    timeout,
    onTimeout: () {
      throw FirebaseOperationTimeoutException(operationName, timeout);
    },
  );
}
