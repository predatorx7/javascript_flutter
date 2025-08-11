import 'package:javascript_platform_interface/javascript_platform_interface.dart';

import 'package:javascript_android/src/third_party/flutter_qjs/lib/flutter_qjs.dart';

/// The Android implementation of [JavaScriptPlatform].
class JavaScriptAndroid extends JavaScriptPlatform {
  /// Registers this class as the default instance of [JavaScriptPlatform]
  static void registerWith() {
    JavaScriptPlatform.instance = JavaScriptAndroid();
  }

  final _enabledChannels = <String, JavaScriptChannelParams>{};

  @override
  Future<void> addJavaScriptChannel(
    String javascriptEngineId,
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}

  @override
  Future<void> dispose(String javascriptEngineId) {
    final runtime = requireRuntime(javascriptEngineId);
    _activeRuntimes.remove(javascriptEngineId);
    return runtime.close();
  }

  @override
  Future<void> removeJavaScriptChannel(
    String javascriptEngineId,
    String javaScriptChannelName,
  ) async {}

  @override
  Future<Object?> runJavaScriptReturningResult(
    String javascriptEngineId,
    String javaScript,
  ) {
    final runtime = requireRuntime(javascriptEngineId);
    return runtime.evaluate(javaScript);
  }

  @override
  Future<void> setIsInspectable(
    String javascriptEngineId,
    bool isInspectable,
  ) async {
    // no op
  }

  final _activeRuntimes = <String, FlutterQjs>{};

  @override
  Future<void> startJavaScriptEngine(String javascriptEngineId) {
    final runtime = FlutterQjs();
    _activeRuntimes[javascriptEngineId] = runtime;
    return Future.value();
  }

  FlutterQjs requireRuntime(String javascriptEngineId) {
    final runtime = _activeRuntimes[javascriptEngineId];
    if (runtime == null) {
      throw ArgumentError.value(
        javascriptEngineId,
        'javascriptEngineId',
        'Runtime not found for id',
      );
    }
    return runtime;
  }
}
