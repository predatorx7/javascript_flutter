import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:javascript/javascript.dart';

abstract interface class JsRuntimeDelegate {
  factory JsRuntimeDelegate() {
    return JsRuntimeDefault();
  }

  Future<void> initialize();

  Future<Object?> evaluate(String source);
  dynamic onMessage(String channelName, dynamic Function(dynamic args) fn);

  void dispose();
}

final class JsRuntimeDefault implements JsRuntimeDelegate {
  JsRuntimeDefault();

  late final JavaScript _jsRuntime;

  @override
  Future<void> initialize() async {
    try {
      _jsRuntime = await JavaScript.createNew();
      if (kDebugMode) {
        print('kDebugMode: $kDebugMode, ${_jsRuntime.runtimeType}');
      }
      _jsRuntime.setIsInspectable(kDebugMode);
      _jsRuntime.runJavaScriptReturningResult("""
        console.info = function() {
          sendMessage('ConsoleLog', JSON.stringify(['info', ...arguments]));
        }
        """);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error initializing JS runtime: $e');
        print('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  @override
  Future<Object?> evaluate(String source) async {
    final value = await _jsRuntime.runJavaScriptReturningResult(source);
    print('evaluate: $value');
    return value;
  }

  @override
  dynamic onMessage(String channelName, dynamic Function(dynamic args) fn) {
    return _jsRuntime.addJavaScriptChannel(
      JavaScriptChannelParams(
        name: channelName,
        onMessageReceived: (message) {
          print('$channelName.onMessage: $message');
          final data = fn(message.message);
          return JavaScriptReply(message: json.encode(data));
        },
      ),
    );
  }

  @override
  void dispose() {
    _jsRuntime.dispose();
  }
}
