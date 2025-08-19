part of 'javascript_flutter.dart';

typedef _JavaScriptDefunctReason = (
  JavaScriptUnavailablePlatformException e,
  StackTrace? s
);

class _UsableJavaScript extends JavaScript {
  _UsableJavaScript._(this.platform, this.instanceId);

  @override
  final String instanceId;

  @override
  final JavaScriptPlatform platform;

  _JavaScriptDefunctReason? _unavailableReason;

  @override
  bool get isFunctional => _unavailableReason == null;

  @override
  Object? get unavailableReason => _unavailableReason?.$1;

  void _throwUnavailable(_JavaScriptDefunctReason reason) {
    final (e, s) = reason;

    if (s == null) throw e;

    Error.throwWithStackTrace(e, s);
  }

  Future<T> _usePlatform<T>(
    Future<T> Function(JavaScriptPlatform platform) callback,
  ) async {
    final reason = _unavailableReason;
    // New operations on an defunct instance will fail, so throw an error as a reason instead of the running the operation
    if (reason != null) {
      // If the instance becomes unavailable in any previous operation
      // throw the reason
      _throwUnavailable(reason);
    }
    try {
      return await callback(platform);
    } on JavaScriptUnavailablePlatformException catch (e, s) {
      _unavailableReason ??= (e, s);
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    return _usePlatform((platform) async {
      _unavailableReason = (
        JavaScriptEnvironmentClosedException(
          'The JavaScript environment has been disposed',
        ),
        null,
      );
      return platform.dispose(instanceId);
    });
  }

  @override
  Future<void> setIsInspectable(bool isInspectable) async {
    return _usePlatform((platform) {
      return platform.setIsInspectable(instanceId, isInspectable);
    });
  }

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    return _usePlatform((platform) {
      return platform.addJavaScriptChannel(instanceId, javaScriptChannelParams);
    });
  }

  @override
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) async {
    return _usePlatform((platform) {
      return platform.removeJavaScriptChannel(
          instanceId, javaScriptChannelName);
    });
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String javaScript) {
    return _usePlatform((platform) {
      return platform.runJavaScriptReturningResult(instanceId, javaScript);
    });
  }

  @override
  Future<Object?> runJavaScriptFromFileReturningResult(
    String javaScriptFilePath,
  ) {
    return _usePlatform((platform) {
      return platform.runJavaScriptFromFileReturningResult(
        instanceId,
        javaScriptFilePath,
      );
    });
  }
}
