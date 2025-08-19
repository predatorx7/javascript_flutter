import 'dart:convert';
import 'dart:io';

import 'package:javascript_darwin/src/third_party/flutter_js/lib/extensions/handle_promises.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/js_eval_result.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

import 'package:javascript_darwin/src/third_party/flutter_js/lib/javascriptcore/jscore_runtime.dart';

import 'package:javascript_darwin/src/third_party/flutter_js/lib/javascript_runtime.dart';
import 'package:logging/logging.dart';

import 'exception.dart';

final _logger = Logger('JavaScriptDarwin');

class JavaScriptDarwinMessage extends JavaScriptMessage {
  final Object? rawMessage;

  JavaScriptDarwinMessage({required this.rawMessage})
      : super(message: fromRawMessage(rawMessage));

  static String? fromRawMessage(Object? rawMessage) {
    try {
      return json.encode(rawMessage);
    } catch (_) {
      if (rawMessage is String) {
        return rawMessage;
      }
      _logger.warning('Failed to encode raw message: $rawMessage');
      return null;
    }
  }
}

extension on JavascriptCoreRuntime {
  bool removeBridge(String channelName) {
    final channelFunctionCallbacks =
        JavascriptRuntime.channelFunctionsRegistered[getEngineInstanceId()]!;

    if (!channelFunctionCallbacks.keys.contains(channelName)) return false;

    channelFunctionCallbacks.remove(channelName);

    return true;
  }
}

class _JavaScriptDarwinState {
  final JavascriptCoreRuntime runtime;
  final Map<String, JavaScriptChannelParams> enabledChannels;

  const _JavaScriptDarwinState({
    required this.runtime,
    required this.enabledChannels,
  });
}

/// The Darwin implementation of [JavaScriptPlatform].
class JavaScriptDarwin extends JavaScriptPlatform {
  /// Registers this class as the default instance of [JavaScriptPlatform]
  static void registerWith() {
    JavaScriptPlatform.instance = JavaScriptDarwin();
  }

  final _activeState = <String, _JavaScriptDarwinState>{};

  /// Returns the underlying javascript environment's identifier.
  ///
  /// This is useful for debugging purposes.
  String getPlatformEnvironmentInstanceId(String javaScriptInstanceId) {
    final state = _requireJsRuntimeState(javaScriptInstanceId);
    return state.runtime.getEngineInstanceId();
  }

  @override
  Future<void> startNewJavaScriptEnvironment(
    String javaScriptInstanceId,
  ) async {
    // For now using javascriptcore through ffis from flutter_js and flutter_jscore library.
    // Look if we can generate from https://github.com/WebKit/WebKit/blob/main/Source/JavaScriptCore and if its worth it.
    final runtime = JavascriptCoreRuntime();

    _activeState[javaScriptInstanceId] = _JavaScriptDarwinState(
      runtime: runtime,
      enabledChannels: {},
    );

    runtime.enableHandlePromises();
  }

  _JavaScriptDarwinState _requireJsRuntimeState(String javaScriptInstanceId) {
    final state = _activeState[javaScriptInstanceId];
    if (state == null) {
      throw JavaScriptDarwinEnvironmentNotFoundException(javaScriptInstanceId);
    }
    return state;
  }

  Map<String, JavaScriptChannelParams> getEnabledChannels(
    String javaScriptInstanceId,
  ) {
    final state = _requireJsRuntimeState(javaScriptInstanceId);
    return state.enabledChannels;
  }

  @override
  Future<void> addJavaScriptChannel(
    String javaScriptInstanceId,
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    final state = _requireJsRuntimeState(javaScriptInstanceId);

    Future<Object?> onChannelRawMessage(
      Object? params,
    ) async {
      // Don't use reference of enabledChannels from parent scope to avoid memory leaks or race conditions.
      final enabledChannels = getEnabledChannels(javaScriptInstanceId);
      final channel = enabledChannels[javaScriptChannelParams.name];
      if (channel == null) {
        _logger.warning(
          'Received a message on a channel "${javaScriptChannelParams.name}" that was not registered',
        );
        return null;
      }
      final reply = await channel.onMessageReceived(
        JavaScriptDarwinMessage(rawMessage: params),
      );
      return reply.message;
    }

    final runtime = state.runtime;

    runtime.removeBridge(javaScriptChannelParams.name);

    final enabledChannels = state.enabledChannels;

    enabledChannels[javaScriptChannelParams.name] = javaScriptChannelParams;

    return runtime.onMessage(
      javaScriptChannelParams.name,
      onChannelRawMessage,
    );
  }

  @override
  Future<void> removeJavaScriptChannel(
    String javaScriptInstanceId,
    String javaScriptChannelName,
  ) async {
    final state = _requireJsRuntimeState(javaScriptInstanceId);
    final runtime = state.runtime;
    runtime.removeBridge(javaScriptChannelName);
    final enabledChannels = state.enabledChannels;
    enabledChannels.remove(javaScriptChannelName);
  }

  @override
  Future<Object?> runJavaScriptReturningResult(
    String javaScriptInstanceId,
    String javaScript,
  ) async {
    final state = _requireJsRuntimeState(javaScriptInstanceId);
    final runtime = state.runtime;

    try {
      final result = await runtime.evaluateAsync(javaScript);
      if (result.isError) {
        throw JavaScriptDarwinExecutionException.fromResult(
            runtime, result, StackTrace.current);
      }

      if (!result.isPromise) {
        try {
          return runtime.convertValue(result);
        } on TypeError {
          return result.stringResult;
        }
      }

      final promiseResult = await runtime.handlePromise(result);
      if (promiseResult.isError) {
        throw JavaScriptDarwinExecutionException.fromResult(
          runtime,
          promiseResult,
          StackTrace.current,
        );
      }

      try {
        return runtime.convertValue(promiseResult);
      } on TypeError {
        return promiseResult.stringResult;
      }
    } catch (e, s) {
      if (e is JavaScriptDarwinExecutionException) {
        rethrow;
      }
      if (e is JsEvalResult) {
        throw JavaScriptDarwinExecutionException.fromResult(
          runtime,
          e,
          s,
        );
      }
      rethrow;
    }
  }

  @override
  Future<Object?> runJavaScriptFromFileReturningResult(
    String javaScriptInstanceId,
    String javaScriptFilePath,
  ) async {
    final file = File(javaScriptFilePath);
    final javaScript = await file.readAsString();
    return runJavaScriptReturningResult(javaScriptInstanceId, javaScript);
  }

  @override
  Future<void> setIsInspectable(
    String javaScriptInstanceId,
    bool isInspectable,
  ) async {
    final runtime = _requireJsRuntimeState(javaScriptInstanceId).runtime;
    runtime.setInspectable(isInspectable);
  }

  @override
  Future<void> dispose(String javaScriptInstanceId) async {
    final state = _requireJsRuntimeState(javaScriptInstanceId);
    final runtime = state.runtime;
    runtime.dispose();
    _activeState.remove(javaScriptInstanceId);
    final enabledChannels = state.enabledChannels;
    enabledChannels.clear();
  }
}
