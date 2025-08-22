import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';
import 'package:logging/logging.dart';

import 'exception.dart';
import 'src/parse.dart';
import 'src/host/state.dart';
import 'src/pigeons/messages.pigeon.dart';

final _logger = Logger('JavaScriptAndroid');

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

  // Don't hold reference to state after async gaps, [_requireEngineState] again to
  // ensure we still have the engine state, not having it will throw an error
  EngineHostState _requireEngineState(String javaScriptInstanceId) {
    if (!_activeEngineHostState.containsKey(javaScriptInstanceId)) {
      throw JavaScriptAndroidEnvironmentNotFoundException(javaScriptInstanceId);
    }
    return _activeEngineHostState[javaScriptInstanceId]!;
  }

  Future<void> _onConsoleMessage(
    String javaScriptInstanceId,
    String message,
  ) async {
    if (!message.contains("CONSOLE_MESSAGING_HACK")) return;

    try {
      const levelWarning = 16;
      final decodedMessage = json.decode(message) as Map;
      final level = decodedMessage['level'] as num;
      if (level != levelWarning) {
        return;
      }
      final consoleMessage = decodedMessage['message'];
      final payload = json.decode(consoleMessage) as Map;
      final channelName = payload['channelName'] as String;
      final id = payload['id'] as num;

      // Cannot rely on console messages for the transfer of large volumes of data. Overly large messages, stack traces, or source identifiers may be truncated.
      // That's why we use a separate js call to fetch messages by channel name & id.
      // Refer: https://developer.android.com/reference/kotlin/androidx/javascriptengine/JavaScriptConsoleCallback#onConsoleMessage(androidx.javascriptengine.JavaScriptConsoleCallback.ConsoleMessage)
      final messages = await _requireEngineState(
        javaScriptInstanceId,
      ).getPendingMessagesBy(
        channelName,
        id,
      );

      _requireEngineState(javaScriptInstanceId).onChannelMessages(messages);
    } catch (e, s) {
      _logger.severe(
        "Failed to process channel message for JavaScriptAndroid instance $javaScriptInstanceId",
        e,
        s,
      );
    }
  }

  final _consoleMessageHandler =
      <String, JavaScriptAndroidConsoleMessageHandler>{};

  @override
  Future<void> startNewJavaScriptEnvironment(
    String javaScriptInstanceId, {
    Duration messageListenerInterval = const Duration(milliseconds: 50),
    bool implementJsSetTimeout = true,
  }) async {
    await _usePlatform(
      (api) => api.startJavaScriptEnvironment(javaScriptInstanceId),
    );

    final didSetConsoleMessageHandler = await _usePlatform(
      (api) {
        final handler = JavaScriptAndroidConsoleMessageHandler(
          onMessage: (_, String message) async {
            _onConsoleMessage(javaScriptInstanceId, message);
          },
        );

        _consoleMessageHandler[javaScriptInstanceId] = handler;

        return api.setJavaScriptConsoleMessageHandler(
          javaScriptInstanceId,
          handler.pigeon_instanceManager.getIdentifier(handler)!,
        );
      },
    );

    _logger.config('useConsoleMessagingHack: $didSetConsoleMessageHandler');

    final engineHostState = await EngineHostState.create(
      engineId: javaScriptInstanceId,
      messageListenerInterval: messageListenerInterval,
      implementJsSetTimeout: implementJsSetTimeout,
      runJavaScript: (javaScript) {
        return runJavaScriptReturningResult(javaScriptInstanceId, javaScript);
      },
      useConsoleMessagingHack: didSetConsoleMessageHandler,
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
    _consoleMessageHandler.remove(javaScriptInstanceId);
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
