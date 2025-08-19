import 'dart:convert';

import 'package:javascript_platform_interface/javascript_platform_interface.dart';

import 'package:javascript_darwin/src/third_party/flutter_js/lib/javascriptcore/jscore_runtime.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/js_eval_result.dart';
import 'package:logging/logging.dart';

/// Exception thrown when a JavaScriptCore javascript execution environment is not found.
class JavaScriptDarwinEnvironmentNotFoundException
    extends JavaScriptInstanceNotFoundException {
  /// Identifier of the JavaScript instance id
  final String javaScriptInstanceId;

  JavaScriptDarwinEnvironmentNotFoundException(this.javaScriptInstanceId)
      : super(
          'JavaScriptDarwin could not find a JavaScriptCore javascript execution environment with id "$javaScriptInstanceId"',
        );
}

/// Exception thrown when a JavaScriptCore javascript execution fails
class JavaScriptDarwinExecutionException
    implements JavaScriptExecutionException {
  @override
  final String message;
  final JsEvalResult jsEvalResult;
  final JavascriptCoreRuntime runtime;
  final StackTrace stackTrace;

  const JavaScriptDarwinExecutionException(
      this.message, this.jsEvalResult, this.runtime, this.stackTrace);

  @override
  String toString() {
    return 'JavaScriptDarwinException: $message';
  }

  factory JavaScriptDarwinExecutionException.fromResult(
    JavascriptCoreRuntime runtime,
    JsEvalResult result,
    StackTrace stackTrace,
  ) {
    final logger = Logger('JavaScriptDarwinExecutionException');
    final StringBuffer sb = StringBuffer(result.stringResult);
    try {
      final value = runtime.convertValue(result);
      if (value is Map && value.isNotEmpty) {
        sb.write('\n\n\t...${json.encode(value)}');
      }
    } catch (e, s) {
      logger.severe('Failed to convert value', e, s);
    }
    return JavaScriptDarwinExecutionException(
        sb.toString(), result, runtime, stackTrace);
  }
}
