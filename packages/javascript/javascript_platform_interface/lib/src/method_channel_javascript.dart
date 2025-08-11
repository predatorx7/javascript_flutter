import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import 'package:javascript_platform_interface/javascript_platform_interface.dart';

/// An implementation of [JavaScriptPlatform] that uses method channels.
class MethodChannelJavaScript extends JavaScriptPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('javascript');

  @override
  Future<void> startJavaScriptEngine(String javascriptEngineId) {
    return methodChannel.invokeMethod<void>('startJavaScriptEngine', [javascriptEngineId]);
  }

  @override
  Future<void> setIsInspectable(String javascriptEngineId, bool isInspectable) {
    return methodChannel.invokeMethod<void>('setIsInspectable', [
      javascriptEngineId,
      isInspectable,
    ]);
  }

  final Map<String, JavaScriptChannelParams> _enabledJavascriptChannels =
      <String, JavaScriptChannelParams>{};

  @override
  Future<void> addJavaScriptChannel(
    String javascriptEngineId,
    JavaScriptChannelParams javaScriptChannelParams,
  ) {
    _enabledJavascriptChannels[javaScriptChannelParams.name] = javaScriptChannelParams;

    return methodChannel.invokeMethod<void>('addJavaScriptChannel', [
      javascriptEngineId,
      {"name": javaScriptChannelParams.name},
    ]);
  }

  @override
  Future<void> dispose(String javascriptEngineId) {
    return methodChannel.invokeMethod<void>('dispose', [javascriptEngineId]);
  }

  @override
  Future<void> removeJavaScriptChannel(String javascriptEngineId, String javaScriptChannelName) {
    _enabledJavascriptChannels.remove(javaScriptChannelName);

    return methodChannel.invokeMethod<void>('removeJavaScriptChannel', [
      javascriptEngineId,
      javaScriptChannelName,
    ]);
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String javascriptEngineId, String javaScript) {
    return methodChannel.invokeMethod<Object>('runJavaScriptReturningResult', [
      javascriptEngineId,
      javaScript,
    ]);
  }
}
