import 'package:javascript_platform_interface/javascript_platform_interface.dart';

export 'package:javascript_platform_interface/javascript_platform_interface.dart';

part 'impl.dart';

/// Represents a connection to an environment where JavaScript code can be evaluated.
///
/// Each [JavaScript] instance has its own isolated state, and cannot interact with other [JavaScript] instances.
///
/// There is no guarantee of security boundary between [JavaScript] instances in a single application.
/// If the code in one [JavaScript] instance is able to compromise the security, then it may be able
/// to observe or manipulate other [JavaScript] instances
abstract interface class JavaScript {
  /// Creates & returns a new [JavaScript] instance by the [JavaScriptPlatform].
  ///
  /// The [platform] manages the control of the underlying javascript environment.
  /// If not provided, the default platform is used.
  static Future<JavaScript> createNew({JavaScriptPlatform? platform}) async {
    final p = platform ?? JavaScriptPlatform.instance;

    // A unique id for identifying this javascript instance.
    final id = Object().hashCode.toString();

    // Start a new javascript environment using the platform.
    await p.startNewJavaScriptEnvironment(id);

    return _UsableJavaScript._(p, id);
  }

  /// The id of the javascript environment.
  @Deprecated(
      'The `engineId` property has been renamed to `instanceId`, use `instanceId` instead')
  String get engineId => instanceId;

  /// The id of the javascript instance.
  String get instanceId;

  /// Whether the javascript instance is functional.
  ///
  /// A javascript instance is functional if it is available and can be used.
  /// Any further operations on a non-functional javascript instance that has become defunct will throw an [JavaScriptUnavailablePlatformException].
  bool get isFunctional;

  /// The reason why the javascript instance is not functional.
  ///
  /// If the javascript instance is functional, this will be `null`.
  /// If the javascript instance is not functional, this will be an exception, likely an [JavaScriptUnavailablePlatformException], which made the instance non-functional.
  Object? get unavailableReason;

  /// The platform that is used to control the underlying javascript environment.
  JavaScriptPlatform get platform;

  /// Disposes of the underlying javascript environment.
  Future<void> dispose();

  /// Sets whether the underlying javascript environment is inspectable.
  ///
  /// This is only applicable to some javascript environments and platforms.
  /// Right now only supported on iOS/MacOS when using [javascript_darwin](https://pub.dev/packages/javascript_darwin)
  /// to inspect the JavaScript context with Safari Web Inspector.
  Future<void> setIsInspectable(bool isInspectable);

  /// Adds a new JavaScript channel to the set of enabled channels for the context of the current [JavaScript] instance.
  ///
  /// The JavaScript code can then call `sendMessage('channelName', JSON.stringify("data"))` to send a message that
  /// will be passed to [JavaScriptChannelParams.onMessageReceived] and a reply will be sent back to the JavaScript code.
  ///
  /// For example, after adding the following JavaScript channel:
  /// ```dart
  /// javascript.addJavaScriptChannel(
  ///   JavaScriptChannelParams(
  ///     name: 'Sum',
  ///     onMessageReceived: (message) {
  ///       final data = json.decode(message.message!);
  ///       return JavaScriptReply(
  ///         message: json.encode(data['a'] + data['b']),
  ///       );
  ///     },
  ///   ),
  /// );
  /// ```
  ///
  /// The JavaScript code can then call:
  /// ```dart
  /// sendMessage('Sum', JSON.stringify({a: 1, b: 2}))
  /// ```
  ///
  /// to asynchronously send a message that will be passed to [JavaScriptChannelParams.onMessageReceived] and a reply
  /// will be sent back to the JavaScript code.
  ///
  /// The message is a string and is delivered verbatim to [JavaScriptMessage.message]. [JavaScriptReply.message]
  /// is delivered verbatim to JavaScript as the string the promise resolves to; as per the example, it resolves to `"3"`.
  /// Calling `sendMessage` with a channel name that is not registered throws in JavaScript.
  ///
  /// Calling this function more than once with the same [JavaScriptChannelParams.name] will remove the previously set [JavaScriptChannelParams].
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  );

  /// Removes the JavaScript channel with the matching name from the set of
  /// enabled channels for the context of the current [JavaScript] instance.
  ///
  /// This disables the channel with the matching name if it was previously
  /// enabled through the [addJavaScriptChannel].
  Future<void> removeJavaScriptChannel(String javaScriptChannelName);

  /// Evaluates the given JavaScript code [javaScript] in the context of the current [JavaScript] instance, and returns the result.
  ///
  /// {@template javascript_run_javascript_returning_result_behavior}
  /// ## Result contract
  ///
  /// 1. The value the script evaluates to (its completion value, i.e. the last
  ///    expression statement; do not use `return` at the top level), or the
  ///    value a returned `Promise` resolves to, is returned as a [String]
  ///    exactly as-is. There is no automatic JSON decoding, number or boolean
  ///    parsing, or type detection. `""` is `""`.
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
  /// To get a number or an object back, end the script with
  /// `JSON.stringify(...)` and decode it in Dart:
  ///
  /// ```dart
  /// final result = await javascript.runJavaScriptReturningResult(
  ///   'JSON.stringify({total: 1 + 2, items: [1, 2]})',
  /// );
  /// final data = jsonDecode(result as String) as Map<String, dynamic>;
  /// ```
  ///
  /// The global variables set by one evaluation are visible for later evaluations. This is similar to adding multiple `<script>` tags in HTML.
  /// {@endtemplate}
  Future<Object?> runJavaScriptReturningResult(String javaScript);

  /// Loads the content of of file from [javaScriptFilePath] and evaluates it as javascript code in the context of the
  /// current [JavaScript] instance, and returns the result.
  ///
  /// {@macro javascript_run_javascript_returning_result_behavior}
  Future<Object?> runJavaScriptFromFileReturningResult(
    String javaScriptFilePath,
  );
}
