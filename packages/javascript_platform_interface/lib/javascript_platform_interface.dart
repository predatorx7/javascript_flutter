/// A common platform interface for the [`javascript_flutter`](https://pub.dev/packages/javascript_flutter) plugin's [JavaScript] API.
///
/// This interface allows platform-specific implementations of the
/// [`javascript_flutter`](https://pub.dev/packages/javascript_flutter) plugin, as well as the plugin itself, to ensure they are supporting the same interface.
library;

import 'package:javascript_platform_interface/src/unavailable_javascript.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/api/api.dart';

export 'src/api/api.dart';

/// The interface that implementations of javascript must implement.
///
/// Platform implementations should extend this class
/// rather than implement it as `JavaScript`.
/// Extending this class (using `extends`) ensures that the subclass will get
/// the default implementation, while platform implementations that `implements`
///  this interface will be broken by newly added [JavaScriptPlatform] methods.
abstract class JavaScriptPlatform extends PlatformInterface {
  /// Constructs a JavaScriptPlatform.
  JavaScriptPlatform() : super(token: _token);

  static final Object _token = Object();

  static JavaScriptPlatform _instance = JavaScriptUnavailablePlatform(
    JavaScriptEnvironmentUninitializedException(
      'No functioning JavaScript platform instance is available',
    ),
  );

  /// The default instance of [JavaScriptPlatform] to use.
  ///
  /// Defaults to [JavaScriptUnavailablePlatform].
  static JavaScriptPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [JavaScriptPlatform] when they register themselves.
  static set instance(JavaScriptPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Starts a new JavaScript environment with isolated state by id [javaScriptInstanceId].
  ///
  /// The [javaScriptInstanceId] is used to identify the environment and is used to
  /// communicate with the environment.
  Future<void> startNewJavaScriptEnvironment(String javaScriptInstanceId);

  /// Sets whether the underlying JavaScript environment is inspectable.
  Future<void> setIsInspectable(String javaScriptInstanceId, bool isInspectable);

  /// Evaluates the given JavaScript code [javaScript] in the context of the javascript environment
  /// with id [javaScriptInstanceId], and returns the result.
  ///
  /// {@template javascript_platform_result_contract}
  /// ## Result contract
  ///
  /// 1. The value the script evaluates to (its completion value, i.e. the last
  ///    expression statement; there is no top level `return`), or the value a
  ///    returned `Promise` resolves to, is returned as a [String] exactly
  ///    as-is. There is no JSON decoding, number or boolean parsing, or type
  ///    detection. `""` is `""`.
  /// 2. If that value is not a JavaScript string (a number, boolean, `null`,
  ///    `undefined`, object, array, bigint, function, `NaN`, `Infinity`, a
  ///    script ending in a declaration, an empty script, ...) the [Future]
  ///    resolves to the empty string `''` on every platform.
  /// 3. Promises are awaited (on Android this needs a WebView with
  ///    `JS_FEATURE_PROMISE_RETURN`; WebViews without it
  ///    resolve a Promise result to `''`). A rejected promise completes the [Future] with a
  ///    [JavaScriptExecutionException] carrying the rejection reason. A script
  ///    that throws or fails to parse completes it with a
  ///    [JavaScriptExecutionException] carrying the JavaScript error message.
  /// 4. The declared type is `Future<Object?>` for API compatibility, but the
  ///    [Future] always resolves to a [String]. It may be narrowed to
  ///    `Future<String>` in a future major version.
  ///
  /// To get structured data back, end the script with `JSON.stringify(...)`
  /// and decode it in Dart:
  ///
  /// ```dart
  /// final result = await platform.runJavaScriptReturningResult(
  ///   id,
  ///   'JSON.stringify({a: 1, b: [2, 3]})',
  /// );
  /// final data = jsonDecode(result as String); // {a: 1, b: [2, 3]}
  /// ```
  /// {@endtemplate}
  Future<Object?> runJavaScriptReturningResult(String javaScriptInstanceId, String javaScript);

  /// Loads the content of of file from [javaScriptFilePath] and evaluates it as javascript code in the context of the
  /// javascript environment with id [javaScriptInstanceId], and returns the result.
  ///
  /// The result follows the same contract as [runJavaScriptReturningResult]:
  ///
  /// {@macro javascript_platform_result_contract}
  Future<Object?> runJavaScriptFromFileReturningResult(
    String javaScriptInstanceId,
    String javaScriptFilePath,
  );

  /// Adds a new JavaScript channel to the set of enabled channels.
  ///
  /// JavaScript code calls `sendMessage(channelName, message)` where [message]
  /// is a string. The Dart handler
  /// ([JavaScriptChannelParams.onMessageReceived]) receives it verbatim in
  /// [JavaScriptMessage.message], and [JavaScriptReply.message] is delivered
  /// to JavaScript verbatim as the string the returned promise resolves to.
  /// Nothing is encoded or decoded on the way, so use `JSON.stringify` and
  /// `jsonDecode`/`jsonEncode` for structured data.
  ///
  /// Calling `sendMessage` with a channel name that is not registered throws
  /// in JavaScript.
  Future<void> addJavaScriptChannel(
    String javaScriptInstanceId,
    JavaScriptChannelParams javaScriptChannelParams,
  );

  /// Removes the JavaScript channel with the matching name from the set of
  /// enabled channels.
  ///
  /// This disables the channel with the matching name if it was previously
  /// enabled through the [addJavaScriptChannel].
  Future<void> removeJavaScriptChannel(String javaScriptInstanceId, String javaScriptChannelName);

  /// Disposes of the JavaScript environment with id [javaScriptInstanceId].
  Future<void> dispose(String javaScriptInstanceId);
}
