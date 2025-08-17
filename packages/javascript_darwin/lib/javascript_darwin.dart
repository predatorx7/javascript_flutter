import 'dart:convert';
import 'dart:io';

import 'package:javascript_darwin/src/third_party/flutter_js/lib/extensions/fetch.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/extensions/handle_promises.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/extensions/xhr.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/js_eval_result.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

import 'package:javascript_darwin/src/third_party/flutter_js/lib/javascriptcore/jscore_runtime.dart';

import 'package:javascript_darwin/src/third_party/flutter_js/lib/javascript_runtime.dart';
import 'package:logging/logging.dart';

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

class JavaScriptDarwinExecutionException
    implements JavaScriptExecutionException {
  @override
  final String message;
  final JsEvalResult jsEvalResult;
  final JavascriptCoreRuntime runtime;
  final StackTrace stackTrace;

  const JavaScriptDarwinExecutionException(
      this.message, this.jsEvalResult, this.runtime, this.stackTrace);

  @override
  String toString() {
    return 'JavaScriptDarwinException: $message';
  }

  factory JavaScriptDarwinExecutionException._fromResult(
    JavascriptCoreRuntime runtime,
    JsEvalResult result,
    StackTrace stackTrace,
  ) {
    final StringBuffer sb = StringBuffer(result.stringResult);
    try {
      final value = runtime.convertValue(result);
      if (value is Map && value.isNotEmpty) {
        sb.write('\n\n\t...${json.encode(value)}');
      }
    } catch (e, s) {
      _logger.severe('Failed to convert value', e, s);
    }
    return JavaScriptDarwinExecutionException(
        sb.toString(), result, runtime, stackTrace);
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

/// The Darwin implementation of [JavaScriptPlatform].
class JavaScriptDarwin extends JavaScriptPlatform {
  /// Registers this class as the default instance of [JavaScriptPlatform]
  static void registerWith() {
    JavaScriptPlatform.instance = JavaScriptDarwin();
  }

  final _activeRuntimes = <String, JavascriptCoreRuntime>{};

  static bool isFetchOrXhrEnabled = false;

  /// Returns the underlying engine's instance identifier.
  ///
  /// This is useful for debugging purposes.
  String getPlatformEngineInstanceId(String engineId) {
    final runtime = _requireJsRuntime(engineId);
    return runtime.getEngineInstanceId();
  }

  @override
  Future<void> startJavaScriptEngine(String javascriptEngineId) async {
    // For now using javascriptcore through ffis from flutter_js and flutter_jscore library.
    // Look if we can generate from https://github.com/WebKit/WebKit/blob/main/Source/JavaScriptCore and if its worth it.
    final runtime = JavascriptCoreRuntime();

    _enabledChannelsByEngineId[javascriptEngineId] = {};

    _activeRuntimes[javascriptEngineId] = runtime;
    if (isFetchOrXhrEnabled) {
      runtime.enableFetch();
      runtime.enableXhr();
    }
    runtime.enableHandlePromises();
  }

  final _enabledChannelsByEngineId =
      <String, Map<String, JavaScriptChannelParams>>{};

  JavascriptCoreRuntime _requireJsRuntime(String javascriptEngineId) {
    final runtime = _activeRuntimes[javascriptEngineId];
    if (runtime == null) {
      throw ArgumentError.value(
        javascriptEngineId,
        'javascriptEngineId',
        'JavaScript engine with the given id was not found',
      );
    }
    return runtime;
  }

  Map<String, JavaScriptChannelParams> getEnabledChannels(
      String javascriptEngineId) {
    final channels = _enabledChannelsByEngineId[javascriptEngineId];

    if (channels == null) {
      throw ArgumentError.value(
        javascriptEngineId,
        'javascriptEngineId',
        'Enabled channels for the given engine id was not found',
      );
    }

    return channels;
  }

  @override
  Future<void> addJavaScriptChannel(
    String javascriptEngineId,
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    final runtime = _requireJsRuntime(javascriptEngineId);

    runtime.removeBridge(javaScriptChannelParams.name);

    final enabledChannels = getEnabledChannels(javascriptEngineId);

    enabledChannels[javaScriptChannelParams.name] = javaScriptChannelParams;

    Future<Object?> onChannelRawMessage(
      Object? params,
    ) async {
      final enabledChannels = getEnabledChannels(javascriptEngineId);
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

    return runtime.onMessage(javaScriptChannelParams.name, onChannelRawMessage);
  }

  @override
  Future<void> removeJavaScriptChannel(
    String javascriptEngineId,
    String javaScriptChannelName,
  ) async {
    final runtime = _requireJsRuntime(javascriptEngineId);
    runtime.removeBridge(javaScriptChannelName);
    final enabledChannels = _enabledChannelsByEngineId[javascriptEngineId];
    enabledChannels?.remove(javaScriptChannelName);
  }

  @override
  Future<Object?> runJavaScriptReturningResult(
    String javascriptEngineId,
    String javaScript,
  ) async {
    final runtime = _requireJsRuntime(javascriptEngineId);
    try {
      final result = await runtime.evaluateAsync(javaScript);
      if (result.isError) {
        throw JavaScriptDarwinExecutionException._fromResult(
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
        throw JavaScriptDarwinExecutionException._fromResult(
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
        throw JavaScriptDarwinExecutionException._fromResult(
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
    String javascriptEngineId,
    String javaScriptFilePath,
  ) async {
    final file = File(javaScriptFilePath);
    final javaScript = await file.readAsString();
    return runJavaScriptReturningResult(javascriptEngineId, javaScript);
  }

  @override
  Future<void> setIsInspectable(
    String javascriptEngineId,
    bool isInspectable,
  ) async {
    final runtime = _requireJsRuntime(javascriptEngineId);
    runtime.setInspectable(isInspectable);
  }

  @override
  Future<void> dispose(String javascriptEngineId) async {
    final runtime = _requireJsRuntime(javascriptEngineId);
    runtime.dispose();

    _activeRuntimes.remove(javascriptEngineId);

    final enabledChannels =
        _enabledChannelsByEngineId.remove(javascriptEngineId);

    enabledChannels?.clear();
  }
}
