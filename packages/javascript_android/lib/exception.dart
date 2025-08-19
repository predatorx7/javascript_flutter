import 'package:flutter/services.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

bool _isExceptionMatch(PlatformException e, String key) {
  return e.code == key ||
      e.code.contains(key) ||
      e.message?.contains(key) == true;
}

/// Indicates that a JavaScriptIsolate javascript execution environment with the given id was not found.
class JavaScriptAndroidEnvironmentNotFoundException
    extends JavaScriptInstanceNotFoundException {
  /// Identifier of the JavaScript instance id
  final String javaScriptInstanceId;

  JavaScriptAndroidEnvironmentNotFoundException(this.javaScriptInstanceId)
      : super(
          'JavaScriptAndroid could not find a JavaScriptIsolate javascript execution environment with id "$javaScriptInstanceId"',
        );
}

/// Indicates that an execution failed due to a data input exception, evaluation failed exception, or evaluation result size limit exceeded exception.
///
/// See Also:
/// - [JavaScriptAndroidDataInputException]
/// - [JavaScriptAndroidEvaluationFailedException]
/// - [JavaScriptAndroidEvaluationResultSizeLimitExceededException]
sealed class JavaScriptAndroidExecutionException
    extends JavaScriptExecutionException {
  const JavaScriptAndroidExecutionException(super.message);

  /// The platform exception that caused the execution exception.
  PlatformException get platformException;

  static void throwIfMatch(PlatformException e) {
    if (JavaScriptAndroidDataInputException.isMatch(e)) {
      throw JavaScriptAndroidDataInputException(e);
    }
    if (JavaScriptAndroidEvaluationFailedException.isMatch(e)) {
      throw JavaScriptAndroidEvaluationFailedException(e);
    }
    if (JavaScriptAndroidEvaluationResultSizeLimitExceededException.isMatch(
        e)) {
      throw JavaScriptAndroidEvaluationResultSizeLimitExceededException(e);
    }
  }
}

/// Indicates that streaming JavaScript code into the JS evaluation environment has failed.
///
/// The JavaScript isolate may continue to be used after this exception has been produced.
/// The JavaScript evaluation will not proceed if the JavaScript code streaming fails.
///
/// Refer: https://developer.android.com/reference/kotlin/androidx/javascriptengine/DataInputException
final class JavaScriptAndroidDataInputException
    extends JavaScriptAndroidExecutionException {
  /// Creates a new [JavaScriptAndroidDataInputException] with the given [platformException].
  JavaScriptAndroidDataInputException(this.platformException)
      : super(
          platformException.message ?? 'JavaScript execution failed',
        );

  @override
  final PlatformException platformException;

  static bool isMatch(PlatformException e) {
    return _isExceptionMatch(e, 'DataInputException');
  }

  @override
  String toString() {
    return 'JavaScriptAndroidDataInputException: $message';
  }
}

/// Indicates that an evaluation failed due to a syntax error or exception produced by the script.
///
/// Refer: https://developer.android.com/reference/kotlin/androidx/javascriptengine/EvaluationFailedException
final class JavaScriptAndroidEvaluationFailedException
    extends JavaScriptAndroidExecutionException {
  /// Creates a new [JavaScriptAndroidEvaluationFailedException] with the given [platformException].
  JavaScriptAndroidEvaluationFailedException(this.platformException)
      : super(
          platformException.message ?? 'JavaScript execution failed',
        );

  @override
  final PlatformException platformException;

  static bool isMatch(PlatformException e) {
    return _isExceptionMatch(e, 'EvaluationFailedException');
  }

  @override
  String toString() {
    return 'JavaScriptAndroidEvaluationFailedException: $message';
  }
}

/// Indicates that a JavaScriptIsolate's evaluation failed due to it returning an oversized result.
///
/// This exception is produced when exceeding the size limit configured for the isolate via IsolateStartupParameters, or the default limit.
///
/// The isolate may continue to be used after this exception has been thrown.
///
/// Refer: https://developer.android.com/reference/kotlin/androidx/javascriptengine/EvaluationResultSizeLimitExceededException
final class JavaScriptAndroidEvaluationResultSizeLimitExceededException
    extends JavaScriptAndroidExecutionException {
  /// Creates a new [JavaScriptAndroidEvaluationResultSizeLimitExceededException] with the given [platformException].
  JavaScriptAndroidEvaluationResultSizeLimitExceededException(
      this.platformException)
      : super(
          platformException.message ?? 'JavaScript execution failed',
        );

  @override
  final PlatformException platformException;

  static bool isMatch(PlatformException e) {
    return _isExceptionMatch(e, 'EvaluationResultSizeLimitExceededException');
  }

  @override
  String toString() {
    return 'JavaScriptAndroidEvaluationResultSizeLimitExceededException: $message';
  }
}

/// Indicates that an environment is dead due to a sandbox unsupported exception, sandbox dead exception, isolate terminated exception, or memory limit exceeded exception.
///
/// See Also:
/// - [JavaScriptAndroidSandboxUnsupportedException]
/// - [JavaScriptAndroidSandboxDeadException]
/// - [JavaScriptAndroidIsolateTerminatedException]
/// - [JavaScriptAndroidMemoryLimitExceededException]
sealed class JavaScriptAndroidEnvironmentDeadException
    extends JavaScriptEnvironmentDeadException {
  /// Creates a new [JavaScriptAndroidEnvironmentDeadException] with the given [message].
  const JavaScriptAndroidEnvironmentDeadException(super.message);

  /// The platform exception that caused the environment dead exception.
  PlatformException get platformException;

  static void throwIfMatch(PlatformException e) {
    if (JavaScriptAndroidSandboxUnsupportedException.isMatch(e)) {
      throw JavaScriptAndroidSandboxUnsupportedException(e);
    }
    if (JavaScriptAndroidSandboxDeadException.isMatch(e)) {
      throw JavaScriptAndroidSandboxDeadException(e);
    }
    if (JavaScriptAndroidIsolateTerminatedException.isMatch(e)) {
      throw JavaScriptAndroidIsolateTerminatedException(e);
    }
    if (JavaScriptAndroidMemoryLimitExceededException.isMatch(e)) {
      throw JavaScriptAndroidMemoryLimitExceededException(e);
    }
  }
}

/// Exception thrown when attempting to create a JavaScriptSandbox via createConnectedInstanceAsync when doing so is not supported.
///
/// This can occur when the WebView package is too old to provide a sandbox implementation.
///
/// Refer: https://developer.android.com/reference/kotlin/androidx/javascriptengine/SandboxUnsupportedException
final class JavaScriptAndroidSandboxUnsupportedException
    extends JavaScriptAndroidEnvironmentDeadException {
  /// Creates a new [JavaScriptAndroidSandboxUnsupportedException] with the given [platformException].
  const JavaScriptAndroidSandboxUnsupportedException(
    this.platformException,
  ) : super('JavaScriptAndroid javascript environment cannot be used because androidx.javascriptengine.JavaScriptSandbox is not supported');

  @override
  final PlatformException platformException;

  static bool isMatch(PlatformException e) {
    return _isExceptionMatch(e, 'SandboxUnsupportedException');
  }

  @override
  String toString() {
    return 'JavaScriptAndroidSandboxDeadException: $message';
  }
}

/// Exception thrown when evaluation is terminated due the JavaScriptSandbox being dead.
/// This can happen when close is called or when the sandbox process is killed by the framework.
///
/// Refer: https://developer.android.com/reference/kotlin/androidx/javascriptengine/SandboxDeadException
final class JavaScriptAndroidSandboxDeadException
    extends JavaScriptAndroidEnvironmentDeadException {
  /// Creates a new [JavaScriptAndroidSandboxDeadException] with the given [platformException].
  const JavaScriptAndroidSandboxDeadException(
    this.platformException,
  ) : super('JavaScriptAndroid javascript environment terminated because androidx.javascriptengine.JavaScriptSandbox is dead because of being closed or due to some crash');

  @override
  final PlatformException platformException;

  static bool isMatch(PlatformException e) {
    return _isExceptionMatch(e, 'SandboxDeadException');
  }

  @override
  String toString() {
    return 'JavaScriptAndroidSandboxDeadException: $message';
  }
}

/// Exception produced when evaluation is terminated due to the JavaScriptIsolate being closed or due to some crash.
///
/// Refer: https://developer.android.com/reference/kotlin/androidx/javascriptengine/IsolateTerminatedException
final class JavaScriptAndroidIsolateTerminatedException
    extends JavaScriptAndroidEnvironmentDeadException {
  /// Creates a new [JavaScriptAndroidIsolateTerminatedException] with the given [platformException].
  const JavaScriptAndroidIsolateTerminatedException(
    this.platformException,
  ) : super('JavaScriptAndroid javascript environment terminated because androidx.javascriptengine.JavaScriptIsolate was terminated');

  @override
  final PlatformException platformException;

  static bool isMatch(PlatformException e) {
    return _isExceptionMatch(e, 'IsolateTerminatedException');
  }

  @override
  String toString() {
    return 'JavaScriptAndroidIsolateTerminatedException: $message';
  }
}

/// Indicates that a JavaScriptIsolate's evaluation failed due to the isolate exceeding its heap size limit.
///
/// Refer: https://developer.android.com/reference/kotlin/androidx/javascriptengine/MemoryLimitExceededException
final class JavaScriptAndroidMemoryLimitExceededException
    extends JavaScriptAndroidEnvironmentDeadException {
  /// Creates a new [JavaScriptAndroidMemoryLimitExceededException] with the given [platformException].
  const JavaScriptAndroidMemoryLimitExceededException(
    this.platformException,
  ) : super('JavaScriptAndroid javascript environment terminated because androidx.javascriptengine.JavaScriptIsolate memory limit was exceeded');

  @override
  final PlatformException platformException;

  static bool isMatch(PlatformException e) {
    return _isExceptionMatch(e, 'MemoryLimitExceededException');
  }

  @override
  String toString() {
    return 'JavaScriptAndroidMemoryLimitExceededException: $message';
  }
}

/// An exception thrown when a JavaScript environment is gone due to it being uninitialized, disposed, crashed or never existed.
final class JavaScriptAndroidEnvironmentGoneException
    extends JavaScriptEnvironmentClosedException {
  /// Creates a new [JavaScriptAndroidEnvironmentGoneException] with the given [platformException].
  const JavaScriptAndroidEnvironmentGoneException(this.platformException)
      : super(
            'JavaScriptAndroid javascript environment is unavailable because no active javascript environment was found because it is uninitialized, disposed, crashed, or never existed');

  /// The platform exception that caused the environment gone exception.
  final PlatformException platformException;

  static bool isMatch(PlatformException e) {
    return e.code == 'IllegalStateException' &&
        e.message?.contains('No active isolate with id') == true;
  }

  @override
  String toString() {
    return 'JavaScriptAndroidEnvironmentGoneException: $message';
  }
}
