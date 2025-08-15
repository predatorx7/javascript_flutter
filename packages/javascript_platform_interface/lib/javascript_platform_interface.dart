import 'package:javascript_platform_interface/src/method_channel_javascript.dart';
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

  static JavaScriptPlatform _instance = MethodChannelJavaScript();

  /// The default instance of [JavaScriptPlatform] to use.
  ///
  /// Defaults to [MethodChannelJavaScript].
  static JavaScriptPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [JavaScriptPlatform] when they register themselves.
  static set instance(JavaScriptPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Starts a new JavaScript environment with isolated state by id [javascriptEngineId].
  ///
  /// The [javascriptEngineId] is used to identify the environment and is used to
  /// communicate with the environment.
  Future<void> startJavaScriptEngine(String javascriptEngineId);

  /// Sets whether the underlying JavaScript environment is inspectable.
  Future<void> setIsInspectable(String javascriptEngineId, bool isInspectable);

  /// Evaluates the given JavaScript code [javaScript] in the context of the javascript environment
  /// with id [javascriptEngineId], and returns the result.
  ///
  /// The Future completes with an error if a JavaScript error occurred, or if the
  /// type the given expression evaluates to is unsupported.
  Future<Object?> runJavaScriptReturningResult(String javascriptEngineId, String javaScript);

  /// Loads the content of of file from [javaScriptFilePath] and evaluates it as javascript code in the context of the
  /// javascript environment with id [javascriptEngineId], and returns the result.
  ///
  /// The Future completes with an error if a JavaScript error occurred, or if the
  /// type the given expression evaluates to is unsupported.
  Future<Object?> runJavaScriptFromFileReturningResult(
    String javascriptEngineId,
    String javaScriptFilePath,
  );

  /// Adds a new JavaScript channel to the set of enabled channels.
  Future<void> addJavaScriptChannel(
    String javascriptEngineId,
    JavaScriptChannelParams javaScriptChannelParams,
  );

  /// Removes the JavaScript channel with the matching name from the set of
  /// enabled channels.
  ///
  /// This disables the channel with the matching name if it was previously
  /// enabled through the [addJavaScriptChannel].
  Future<void> removeJavaScriptChannel(String javascriptEngineId, String javaScriptChannelName);

  /// Disposes of the JavaScript environment with id [javascriptEngineId].
  Future<void> dispose(String javascriptEngineId);
}
