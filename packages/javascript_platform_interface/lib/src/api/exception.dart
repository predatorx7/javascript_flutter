/// Exception thrown when a JavaScript platform error occurs.
sealed class JavaScriptPlatformException implements Exception {
  const JavaScriptPlatformException(this.message);

  /// The message of the exception.
  final String message;

  @override
  String toString() {
    return 'JavaScriptPlatformException: $message';
  }
}

/// Exception thrown when a JavaScript execution fails.
///
/// Typically, this is thrown when:
/// - The JavaScript code given for evaluation is invalid i.e malformed or syntactically incorrect.
/// - The JavaScript code given for evaluation contains a syntax error.
/// - The JavaScript code given for evaluation throws an error upon evaluation.
abstract class JavaScriptExecutionException extends JavaScriptPlatformException {
  /// Creates a new [JavaScriptExecutionException] with the given message.
  const JavaScriptExecutionException(super.message);

  @override
  String toString() {
    return 'JavaScriptExecutionException: $message';
  }
}

/// Exception thrown when a JavaScript platform or JavaScript environment is unavailable.
///
/// See Also:
/// - [JavaScriptInstanceNotFoundException]
/// - [JavaScriptEnvironmentTerminatedException]
/// - [JavaScriptEnvironmentUninitializedException]
sealed class JavaScriptUnavailablePlatformException extends JavaScriptPlatformException {
  /// Creates a new [JavaScriptUnavailablePlatformException] with the given message.
  const JavaScriptUnavailablePlatformException(super.message);

  @override
  String toString() {
    return 'JavaScriptUnavailablePlatformException: $message';
  }
}

/// Exception thrown when a JavaScript environment is uninitialized.
///
/// This is thrown when the JavaScript environment is no longer available because it has not been initialized.
class JavaScriptEnvironmentUninitializedException extends JavaScriptUnavailablePlatformException {
  /// Creates a new [JavaScriptEnvironmentUninitializedException] with the given message.
  const JavaScriptEnvironmentUninitializedException(super.message);

  @override
  String toString() {
    return 'JavaScriptEnvironmentUninitializedException: $message';
  }
}

/// Exception thrown when a JavaScript instance with the given javascript instance id is not found.
///
/// This is typically thrown when:
/// - the JavaScript instance is not found by the provided instance id i.e it does not exist.
abstract class JavaScriptInstanceNotFoundException extends JavaScriptUnavailablePlatformException {
  /// Creates a new [JavaScriptInstanceNotFoundException] with the given message.
  const JavaScriptInstanceNotFoundException(super.message);

  @override
  String toString() {
    return 'JavaScriptInstanceNotFoundException: $message';
  }
}

/// Exception thrown when a JavaScript environment is terminated.
///
/// This is thrown when the JavaScript environment is no longer available because it has been uninitialized,disposed or crashed.
/// This is typically thrown when the underlying JavaScript environment has stopped and has become defunct.
///
/// See Also:
/// - [JavaScriptEnvironmentDeadException]
/// - [JavaScriptEnvironmentClosedException]
sealed class JavaScriptEnvironmentTerminatedException extends JavaScriptUnavailablePlatformException {
  /// Creates a new [JavaScriptEnvironmentTerminatedException] with the given message.
  const JavaScriptEnvironmentTerminatedException(super.message);

  @override
  String toString() {
    return 'JavaScriptEnvironmentTerminatedException: $message';
  }
}

/// Exception thrown when a JavaScript environment is dead.
///
/// This is thrown when the JavaScript environment is no longer available because it may have crashed.
abstract class JavaScriptEnvironmentDeadException extends JavaScriptEnvironmentTerminatedException {
  /// Creates a new [JavaScriptEnvironmentDeadException] with the given message.
  const JavaScriptEnvironmentDeadException(super.message);

  @override
  String toString() {
    return 'JavaScriptEnvironmentDeadException: $message';
  }
}

/// Exception thrown when a JavaScript environment is closed.
///
/// This is thrown when the JavaScript environment is no longer available because it has been disposed.
class JavaScriptEnvironmentClosedException extends JavaScriptEnvironmentTerminatedException {
  /// Creates a new [JavaScriptEnvironmentClosedException] with the given message.
  const JavaScriptEnvironmentClosedException(super.message);

  @override
  String toString() {
    return 'JavaScriptEnvironmentClosedException: $message';
  }
}
