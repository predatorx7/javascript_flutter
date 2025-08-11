import 'package:javascript_platform_interface/javascript_platform_interface.dart';

export 'package:javascript_platform_interface/javascript_platform_interface.dart';

part 'impl.dart';

abstract interface class JavaScript {
  /// Creates a new JavaScript engine.
  ///
  /// The [platform] is used to start a engine. If not provided, the default
  /// platform is used.
  static Future<JavaScript> createNew({JavaScriptPlatform? platform}) async {
    final p = platform ?? JavaScriptPlatform.instance;
    final id = Object().hashCode.toString();

    await p.startJavaScriptEngine(id);

    return JavaScriptImpl._(p, id);
  }

  /// Disposes of the JavaScript runtime.
  Future<void> dispose();

  /// Sets whether the JavaScript engine is inspectable.
  Future<void> setIsInspectable(bool isInspectable);

  /// Adds a new JavaScript channel to the set of enabled channels.
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  );

  /// Removes the JavaScript channel with the matching name from the set of
  /// enabled channels.
  ///
  /// This disables the channel with the matching name if it was previously
  /// enabled through the [addJavaScriptChannel].
  Future<void> removeJavaScriptChannel(String javaScriptChannelName);

  /// Runs the given JavaScript in the context of the current page, and returns the result.
  ///
  /// The Future completes with an error if a JavaScript error occurred, or if the
  /// type the given expression evaluates to is unsupported.
  Future<Object?> runJavaScriptReturningResult(String javaScript);
}
