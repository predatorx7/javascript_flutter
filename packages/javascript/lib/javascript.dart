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

    // A unique id for identifying the javascript environment.
    final id = Object().hashCode.toString();

    // Start a new javascript environment using the platform.
    await p.startJavaScriptEngine(id);

    return JavaScriptImpl._(p, id);
  }

  /// Disposes of the underlying javascript environment.
  Future<void> dispose();

  /// Sets whether the underlying javascript environment is inspectable.
  ///
  /// This is only applicable to some runtime engines.
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
  /// engine.addJavaScriptChannel(
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
  /// As per the example, the reply back to javascript will be a promise that resolves to `"3"`.
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
  /// There are multiple possible behaviors based on the output of the expression:
  /// 1. If the JS expression evaluates to a JS String or a Promise of a JS String, then the [Future] resolves to a [Map], [List], [String], [num], [bool], or [Null] if the string can be decoded as JSON, otherwise the [Future] resolves to the string.
  /// 2. If the JS expression evaluates to another data type, then the [Future] resolves to an **empty** [String] on some platforms.
  /// 3. The [Future] completes with an error if a JavaScript error occurred.
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
