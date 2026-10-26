import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:javascript_darwin/src/third_party/flutter_js/lib/extensions/handle_promises.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/javascriptcore/jscore_bindings.dart';
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
    // The JS side wrapper delivers every message as the exact string that was
    // passed to `sendMessage`.
    if (rawMessage is String) return rawMessage;
    try {
      return json.encode(rawMessage);
    } catch (_) {
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

/// JavaScript helpers installed in every environment.
///
/// - `channels`/`sendMessage`: channel messages are delivered to Dart as the
///   exact string passed by the script (the vendored bridge JSON-decodes its
///   payload, so the string is JSON-encoded here first), and sending to a
///   channel that is not registered throws, like it does on Android.
/// - `settle`/`status`/`take`: awaiting native Promises while keeping the
///   raw settled value alive on the JS side until Dart takes it.
const _environmentShim = r"""
var __jsf = (function () {
  var channels = Object.create(null);
  var nativeSendMessage = globalThis.sendMessage;
  globalThis.sendMessage = function (name, message) {
    name = String(name);
    if (name === 'ConsoleLog' || name === 'SetTimeout') {
      return nativeSendMessage.apply(this, arguments);
    }
    if (!channels[name]) {
      throw new Error('No JavaScript channel named "' + name + '" is registered');
    }
    if (typeof message !== 'string') {
      throw new Error('Message must be a string');
    }
    return nativeSendMessage(name, JSON.stringify(message));
  };
  var counter = 0;
  var pending = {};
  function describe(reason) {
    try {
      if (reason !== null && typeof reason === 'object' &&
          typeof reason.message === 'string') {
        var stack = typeof reason.stack === 'string' ? reason.stack : '';
        return reason.message + (stack ? '\n' + stack : '');
      }
      return String(reason);
    } catch (e) {
      return 'Unknown JavaScript rejection';
    }
  }
  return {
    channels: channels,
    settle: function (value) {
      // Only native Promises are awaited (like Android). Other objects,
      // thenables included, are not strings and so resolve to ''.
      if (!(value instanceof Promise)) return -1;
      var id = counter++;
      var record = { state: 0, value: undefined };
      pending[id] = record;
      Promise.resolve(value).then(
        function (v) { record.state = 1; record.value = v; },
        function (e) { record.state = 2; record.value = e; }
      );
      return id;
    },
    status: function (id) { return pending[id].state; },
    take: function (id) {
      var record = pending[id];
      delete pending[id];
      return record.state === 1 ? record.value : describe(record.value);
    }
  };
})();
""";

class _JavaScriptDarwinState {
  final JavascriptCoreRuntime runtime;
  final Map<String, JavaScriptChannelParams> enabledChannels;

  /// `__jsf.settle`, protected from garbage collection until disposal.
  late final Pointer settleFunction;

  _JavaScriptDarwinState({
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
    runtime.evaluate(_environmentShim);
    final settleFunction =
        runtime.evaluate('__jsf.settle').rawResult as Pointer;
    jSValueProtect(runtime.context.pointer, settleFunction);
    _activeState[javaScriptInstanceId]!.settleFunction = settleFunction;
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
    runtime.evaluate(
      '__jsf.channels[${json.encode(javaScriptChannelParams.name)}] = true;',
    );

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
    runtime.evaluate(
      'delete __jsf.channels[${json.encode(javaScriptChannelName)}];',
    );
    final enabledChannels = state.enabledChannels;
    enabledChannels.remove(javaScriptChannelName);
  }

  /// Evaluates [javaScript] and resolves to its completion value (or what a
  /// returned Promise/thenable resolves to) if, and only if, that value is a
  /// JavaScript string. The string is returned verbatim. Any other value
  /// resolves to an empty string. This matches the Android implementation.
  @override
  Future<Object?> runJavaScriptReturningResult(
    String javaScriptInstanceId,
    String javaScript,
  ) async {
    final state = _requireJsRuntimeState(javaScriptInstanceId);
    final runtime = state.runtime;

    final result = runtime.evaluate(javaScript);
    if (result.isError) {
      throw JavaScriptDarwinExecutionException.fromResult(
        runtime,
        result,
        StackTrace.current,
      );
    }

    final ref = result.rawResult as Pointer;
    if (_isString(runtime, ref)) {
      return result.stringResult;
    }
    if (jSValueIsObject(runtime.context.pointer, ref) != 1) {
      return '';
    }

    // Only native Promises are awaited. Hand the value to the cached JS side
    // settle helper, which keeps the settled value alive in a registry until
    // taken. The result is protected while it is only referenced from Dart.
    final context = runtime.context.pointer;
    jSValueProtect(context, ref);
    final int id;
    try {
      id = int.parse(
        runtime.callFunction(state.settleFunction, ref).stringResult,
      );
    } finally {
      if (!runtime.isDisposed) jSValueUnprotect(context, ref);
    }
    if (id < 0) return '';

    while (true) {
      if (runtime.isDisposed) {
        throw const JavaScriptEnvironmentClosedException(
          'The JavaScript environment was disposed while awaiting a Promise',
        );
      }
      final status = runtime.evaluate('__jsf.status($id)').stringResult;
      if (status != '0') {
        final taken = runtime.evaluate('__jsf.take($id)');
        if (status == '2') {
          final reason = taken.stringResult;
          throw JavaScriptDarwinExecutionException(
            reason,
            JsEvalResult(reason, taken.rawResult, isError: true),
            runtime,
            StackTrace.current,
          );
        }
        return _isString(runtime, taken.rawResult) ? taken.stringResult : '';
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  bool _isString(JavascriptCoreRuntime runtime, Object? value) =>
      jSValueIsString(runtime.context.pointer, value as Pointer) == 1;

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
    if (!runtime.isDisposed) {
      jSValueUnprotect(runtime.context.pointer, state.settleFunction);
    }
    runtime.dispose();
    _activeState.remove(javaScriptInstanceId);
    final enabledChannels = state.enabledChannels;
    enabledChannels.clear();
  }
}
