part of 'javascript.dart';

class JavaScriptImpl implements JavaScript {
  JavaScriptImpl._(this._platform, this._engineId);

  final JavaScriptPlatform _platform;
  final String _engineId;

  @override
  Future<void> dispose() async {
    await _platform.dispose(_engineId);
  }

  @override
  Future<void> setIsInspectable(bool isInspectable) async {
    await _platform.setIsInspectable(_engineId, isInspectable);
  }

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    await _platform.addJavaScriptChannel(_engineId, javaScriptChannelParams);
  }

  @override
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) async {
    await _platform.removeJavaScriptChannel(_engineId, javaScriptChannelName);
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String javaScript) {
    return _platform.runJavaScriptReturningResult(_engineId, javaScript);
  }

  @override
  Future<Object?> runJavaScriptFromFileReturningResult(String javaScriptFilePath) {
    return _platform.runJavaScriptFromFileReturningResult(_engineId, javaScriptFilePath);
  }
}
