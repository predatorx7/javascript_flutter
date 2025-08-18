/// Exception thrown when a JavaScript platform error occurs.
abstract class JavaScriptPlatformException implements Exception {
  final String message;

  const JavaScriptPlatformException(this.message);

  @override
  String toString() {
    return 'JavaScriptPlatformException: $message';
  }
}

/// Exception thrown when a JavaScript execution fails.
abstract class JavaScriptExecutionException extends JavaScriptPlatformException {
  const JavaScriptExecutionException(super.message);

  @override
  String toString() {
    return 'JavaScriptExecutionException: $message';
  }
}

/// Exception thrown when a JavaScript engine is not found.
///
/// This is typically thrown when:
/// - the JavaScript engine is not found by the provided instance id i.e it does not exist.
abstract class JavaScriptEngineNotFoundException extends JavaScriptPlatformException {
  const JavaScriptEngineNotFoundException(super.message);

  @override
  String toString() {
    return 'JavaScriptEngineNotFoundException: $message';
  }
}

/// Exception thrown when a JavaScript environment is terminated.
///
/// This is thrown when the JavaScript environment is no longer available because it has been disposed or crashed.
/// This is typically thrown when the underlying JavaScript environment has stopped and has become defunct.
sealed class JavaScriptEngineTerminatedException extends JavaScriptPlatformException {
  const JavaScriptEngineTerminatedException(super.message);

  @override
  String toString() {
    return 'JavaScriptEngineTerminatedException: $message';
  }
}

/// Exception thrown when a JavaScript environment is dead.
///
/// This is thrown when the JavaScript environment is no longer available because it may have crashed.
abstract class JavaScriptEngineDeadException extends JavaScriptEngineTerminatedException {
  const JavaScriptEngineDeadException(super.message);

  @override
  String toString() {
    return 'JavaScriptEngineDeadException: $message';
  }
}

/// Exception thrown when a JavaScript environment is disposed.
///
/// This is thrown when the JavaScript environment is no longer available because it has been disposed.
abstract class JavaScriptEngineDisposedException extends JavaScriptEngineTerminatedException {
  const JavaScriptEngineDisposedException(super.message);

  @override
  String toString() {
    return 'JavaScriptEngineDisposedException: $message';
  }
}
