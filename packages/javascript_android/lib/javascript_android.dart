import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

import 'exception.dart';
import 'src/parse.dart';
import 'src/host/state.dart';
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

  EngineHostState _requireEngineState(String javaScriptInstanceId) {
    if (!_activeEngineHostState.containsKey(javaScriptInstanceId)) {
      throw JavaScriptAndroidEnvironmentNotFoundException(javaScriptInstanceId);
    }
    return _activeEngineHostState[javaScriptInstanceId]!;
  }

  @override
  Future<void> startNewJavaScriptEnvironment(
    String javaScriptInstanceId, {
    Duration messageListenerInterval = const Duration(milliseconds: 50),
    bool implementJsSetTimeout = true,
  }) async {
    await _usePlatform(
        (api) => api.startJavaScriptEngine(javaScriptInstanceId));
    final engineHostState = await EngineHostState.create(
      engineId: javaScriptInstanceId,
      messageListenerInterval: messageListenerInterval,
      implementJsSetTimeout: implementJsSetTimeout,
      runJavaScript: (javaScript) {
        return runJavaScriptReturningResult(javaScriptInstanceId, javaScript);
      },
    );
    _activeEngineHostState[javaScriptInstanceId] = engineHostState;
  }

  @override
  Future<void> addJavaScriptChannel(
    String javaScriptInstanceId,
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    final engineState = _requireEngineState(javaScriptInstanceId);
    await engineState.addChannel(javaScriptChannelParams);
  }

  @override
  Future<void> removeJavaScriptChannel(
    String javaScriptInstanceId,
    String javaScriptChannelName,
  ) async {
    final engineState = _requireEngineState(javaScriptInstanceId);
    engineState.removeChannel(javaScriptChannelName);
  }

  @override
  Future<void> dispose(String javaScriptInstanceId) {
    final engineState = _requireEngineState(javaScriptInstanceId);
    engineState.dispose();
    _activeEngineHostState.remove(javaScriptInstanceId);
    return _usePlatform((api) => api.dispose(javaScriptInstanceId));
  }

  @override
  Future<Object?> runJavaScriptReturningResult(
    String javaScriptInstanceId,
    String javaScript,
  ) async {
    final result = await _usePlatform((api) {
      return api.runJavaScriptReturningResult(
        javaScriptInstanceId,
        javaScript,
      );
    });

    return parseValue(result);
  }

  @override
  Future<Object?> runJavaScriptFromFileReturningResult(
    String javaScriptInstanceId,
    String javaScriptFilePath,
  ) async {
    final result = await _usePlatform((api) {
      return api.runJavaScriptFromFileReturningResult(
        javaScriptInstanceId,
        javaScriptFilePath,
      );
    });

    return parseValue(result);
  }

  @override
  Future<void> setIsInspectable(
      String javaScriptInstanceId, bool isInspectable) {
    return _usePlatform((api) {
      return api.setIsInspectable(
        javaScriptInstanceId,
        isInspectable,
      );
    });
  }

  Future<T> _usePlatform<T>(
      Future<T> Function(JavaScriptAndroidPlatformApi api) usePlatform) async {
    try {
      return await usePlatform(pigeonPlatformApi);
    } on PlatformException catch (e) {
      JavaScriptAndroidExecutionException.throwIfMatch(e);
      JavaScriptAndroidEnvironmentDeadException.throwIfMatch(e);
      if (JavaScriptAndroidEnvironmentGoneException.isMatch(e)) {
        throw JavaScriptAndroidEnvironmentGoneException(e);
      }
      rethrow;
    }
  }
}
