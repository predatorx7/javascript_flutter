import 'package:javascript_platform_interface/javascript_platform_interface.dart';

/// An implementation of [JavaScriptPlatform] that represents cases where the JavaScript is explicitly closed or uninitialized..
class JavaScriptUnavailablePlatform extends JavaScriptPlatform {
  /// Creates a new [JavaScriptUnavailablePlatform] platform with the reason for the unavailability.
  JavaScriptUnavailablePlatform(this.reason);

  /// The reason for the unavailability of the JavaScript platform.
  final JavaScriptUnavailablePlatformException reason;

  @override
  Future<void> startNewJavaScriptEnvironment(String javaScriptInstanceId) {
    throw reason;
  }

  @override
  Future<void> setIsInspectable(String javaScriptInstanceId, bool isInspectable) {
    throw reason;
  }

  @override
  Future<void> addJavaScriptChannel(
    String javaScriptInstanceId,
    JavaScriptChannelParams javaScriptChannelParams,
  ) {
    throw reason;
  }

  @override
  Future<void> dispose(String javaScriptInstanceId) {
    throw reason;
  }

  @override
  Future<void> removeJavaScriptChannel(String javaScriptInstanceId, String javaScriptChannelName) {
    throw reason;
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String javaScriptInstanceId, String javaScript) {
    throw reason;
  }

  @override
  Future<Object?> runJavaScriptFromFileReturningResult(
    String javaScriptInstanceId,
    String javaScriptFilePath,
  ) {
    throw reason;
  }
}
