import 'package:flutter/foundation.dart';
import 'package:javascript_android/src/user_scripts.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

import 'src/engine_context.dart';
import 'src/pigeons/messages.pigeon.dart';
import 'src/scripts/messaging.dart';

/// The Android implementation of [JavaScriptPlatform].
class JavaScriptAndroid extends JavaScriptPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final pigeonPlatformApi = JavaScriptAndroidPlatformApi();

  /// Registers this class as the default instance of [JavaScriptPlatform]
  static void registerWith() {
    JavaScriptPlatform.instance = JavaScriptAndroid();
  }

  final _activeEngines = <String, EngineHostState>{};

  EngineHostState _requireEngineState(String javascriptEngineId) {
    if (!_activeEngines.containsKey(javascriptEngineId)) {
      throw Exception('Engine by id "$javascriptEngineId" is not found');
    }
    return _activeEngines[javascriptEngineId]!;
  }

  @override
  Future<void> startJavaScriptEngine(String javascriptEngineId) async {
    await pigeonPlatformApi.startJavaScriptEngine(javascriptEngineId);
    _activeEngines[javascriptEngineId] = EngineHostState();
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
    engineState.addChannel(
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
    _activeEngines.remove(javascriptEngineId);
    return pigeonPlatformApi.dispose(javascriptEngineId);
  }

  @override
  Future<Object?> runJavaScriptReturningResult(
    String javascriptEngineId,
    String javaScript,
  ) {
    return pigeonPlatformApi.runJavaScriptReturningResult(
      javascriptEngineId,
      javaScript,
    );
  }

  @override
  Future<void> setIsInspectable(String javascriptEngineId, bool isInspectable) {
    return pigeonPlatformApi.setIsInspectable(
      javascriptEngineId,
      isInspectable,
    );
  }
}
