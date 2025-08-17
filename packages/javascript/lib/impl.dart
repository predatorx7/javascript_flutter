part of 'javascript_flutter.dart';

class JavaScriptImpl implements JavaScript {
  JavaScriptImpl._(this.platform, this.engineId);

  @override
  final String engineId;

  @override
  final JavaScriptPlatform platform;

  @override
  Future<void> dispose() async {
    await platform.dispose(engineId);
  }

  @override
  Future<void> setIsInspectable(bool isInspectable) async {
    await platform.setIsInspectable(engineId, isInspectable);
  }

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    await platform.addJavaScriptChannel(engineId, javaScriptChannelParams);
  }

  @override
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) async {
    await platform.removeJavaScriptChannel(engineId, javaScriptChannelName);
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String javaScript) {
    return platform.runJavaScriptReturningResult(engineId, javaScript);
  }

  @override
  Future<Object?> runJavaScriptFromFileReturningResult(
      String javaScriptFilePath) {
    return platform.runJavaScriptFromFileReturningResult(
        engineId, javaScriptFilePath);
  }
}
