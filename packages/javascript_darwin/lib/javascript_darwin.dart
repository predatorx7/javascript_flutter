import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/extensions/fetch.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/extensions/handle_promises.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/extensions/xhr.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/js_eval_result.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

import 'package:javascript_darwin/src/third_party/flutter_js/lib/javascriptcore/jscore_runtime.dart';

import 'package:javascript_darwin/src/third_party/flutter_js/lib/javascript_runtime.dart';

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
      if (kDebugMode) {
        print('Failed to encode raw message: $rawMessage');
      }
      return null;
    }
  }
}

class JavaScriptDarwinExecutionException
    implements JavaScriptExecutionException {
  @override
  final String message;

  const JavaScriptDarwinExecutionException(this.message);

  @override
  String toString() {
    return 'JavaScriptDarwinException: $message';
  }

  factory JavaScriptDarwinExecutionException._fromResult(
    JavascriptCoreRuntime runtime,
    JsEvalResult result,
  ) {
    final StringBuffer sb = StringBuffer(result.stringResult);
    try {
      final value = runtime.convertValue(result);
      if (value is Map && value.isNotEmpty) {
        sb.write('\n\n\t...${json.encode(value)}');
      }
    } catch (e, s) {
      if (kDebugMode) {
        print('Failed to convert value: $e\n$s');
      }
    }
    return JavaScriptDarwinExecutionException(sb.toString());
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

  @override
  Future<void> startJavaScriptEngine(String javascriptEngineId) async {
    // For now using javascriptcore through ffis from flutter_js and flutter_jscore library.
    // Look if we can generate from https://github.com/WebKit/WebKit/blob/main/Source/JavaScriptCore and if its worth it.
    final runtime = JavascriptCoreRuntime();

    _activeRuntimes[javascriptEngineId] = runtime;
    if (isFetchOrXhrEnabled) {
      runtime.enableFetch();
      runtime.enableXhr();
    }
    runtime.enableHandlePromises();
  }

  final _enabledChannels = <String, JavaScriptChannelParams>{};

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

  @override
  Future<void> addJavaScriptChannel(
    String javascriptEngineId,
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    final runtime = _requireJsRuntime(javascriptEngineId);

    runtime.removeBridge(javaScriptChannelParams.name);

    _enabledChannels[javaScriptChannelParams.name] = javaScriptChannelParams;

    return runtime.onMessage(javaScriptChannelParams.name, (
      Object? params,
    ) async {
      final channel = _enabledChannels[javaScriptChannelParams.name];
      if (channel == null) {
        if (kDebugMode) {
          print(
            'Received a message on a channel "${javaScriptChannelParams.name}" that was not registered',
          );
        }
        return null;
      }
      final reply = await channel.onMessageReceived(
        JavaScriptDarwinMessage(rawMessage: params),
      );
      return reply.message;
    });
  }

  @override
  Future<void> dispose(String javascriptEngineId) async {
    final runtime = _requireJsRuntime(javascriptEngineId);
    runtime.dispose();

    _activeRuntimes.remove(javascriptEngineId);

    _enabledChannels.clear();
  }

  @override
  Future<void> removeJavaScriptChannel(
    String javascriptEngineId,
    String javaScriptChannelName,
  ) async {
    final runtime = _requireJsRuntime(javascriptEngineId);
    runtime.removeBridge(javaScriptChannelName);
    _enabledChannels.remove(javaScriptChannelName);
  }

  @override
  Future<Object?> runJavaScriptReturningResult(
    String javascriptEngineId,
    String javaScript,
  ) async {
    final runtime = _requireJsRuntime(javascriptEngineId);
    final result = await runtime.evaluateAsync(javaScript);
    if (result.isError) {
      throw JavaScriptDarwinExecutionException._fromResult(runtime, result);
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
      );
    }

    try {
      return runtime.convertValue(promiseResult);
    } on TypeError {
      return promiseResult.stringResult;
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
}
