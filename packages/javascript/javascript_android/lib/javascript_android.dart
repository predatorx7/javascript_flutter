import 'package:flutter/foundation.dart';
import 'package:javascript_android/src/user_scripts.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

import 'src/parse.dart';
import 'src/engine_context.dart';
import 'src/pigeons/messages.pigeon.dart';

/// The Android implementation of [JavaScriptPlatform].
class JavaScriptAndroid extends JavaScriptPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final pigeonPlatformApi = JavaScriptAndroidPlatformApi();

  /// Registers this class as the default instance of [JavaScriptPlatform]
  static void registerWith() {
    JavaScriptPlatform.instance = JavaScriptAndroid();
  }

  final _activeEngineHostState = <String, EngineHostState>{};

  EngineHostState _requireEngineState(String javascriptEngineId) {
    if (!_activeEngineHostState.containsKey(javascriptEngineId)) {
      throw Exception('Engine by id "$javascriptEngineId" is not found');
    }
    return _activeEngineHostState[javascriptEngineId]!;
  }

  @override
  Future<void> startJavaScriptEngine(
    String javascriptEngineId, {
    Duration messageListenerInterval = const Duration(milliseconds: 50),
  }) async {
    await pigeonPlatformApi.startJavaScriptEngine(javascriptEngineId);
    _activeEngineHostState[javascriptEngineId] = EngineHostState(
      engineId: javascriptEngineId,
      messageListenerInterval: messageListenerInterval,
      runJavaScript: (javaScript) {
        return runJavaScriptReturningResult(javascriptEngineId, javaScript);
      },
    );
    for (final script in getEngineStartupScripts()) {
      await runJavaScriptReturningResult(javascriptEngineId, script);
    }
  }

  @override
  Future<void> addJavaScriptChannel(
    String javascriptEngineId,
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    final engineState = _requireEngineState(javascriptEngineId);
    await engineState.addChannel(
      javaScriptChannelParams.name,
      javaScriptChannelParams,
    );
  }

  @override
  Future<void> removeJavaScriptChannel(
    String javascriptEngineId,
    String javaScriptChannelName,
  ) async {
    final engineState = _requireEngineState(javascriptEngineId);
    engineState.removeChannel(javaScriptChannelName);
  }

  @override
  Future<void> dispose(String javascriptEngineId) {
    final engineState = _requireEngineState(javascriptEngineId);
    engineState.dispose();
    _activeEngineHostState.remove(javascriptEngineId);
    return pigeonPlatformApi.dispose(javascriptEngineId);
  }

  @override
  Future<Object?> runJavaScriptReturningResult(
    String javascriptEngineId,
    String javaScript,
  ) async {
    final result = await pigeonPlatformApi.runJavaScriptReturningResult(
      javascriptEngineId,
      javaScript,
    );
    return parseValue(result);
  }

  @override
  Future<void> setIsInspectable(String javascriptEngineId, bool isInspectable) {
    return pigeonPlatformApi.setIsInspectable(
      javascriptEngineId,
      isInspectable,
    );
  }
}
