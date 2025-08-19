import 'package:test/test.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

class JavaScriptMock extends JavaScriptPlatform {
  @override
  Future<void> startNewJavaScriptEnvironment(String javaScriptInstanceId) async {
    return Future.value();
  }

  @override
  Future<void> setIsInspectable(String javaScriptInstanceId, bool isInspectable) async {
    return Future.value();
  }

  @override
  Future<void> addJavaScriptChannel(
    String javaScriptInstanceId,
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    return Future.value();
  }

  @override
  Future<void> dispose(String javaScriptInstanceId) async {
    return Future.value();
  }

  @override
  Future<void> removeJavaScriptChannel(
    String javaScriptInstanceId,
    String javaScriptChannelName,
  ) async {
    return Future.value();
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String javaScriptInstanceId, String javaScript) async {
    return Future.value();
  }

  @override
  Future<Object?> runJavaScriptFromFileReturningResult(
    String javaScriptInstanceId,
    String javaScriptFilePath,
  ) async {
    return Future.value();
  }
}

void main() {
  group('JavaScriptPlatformInterface', () {
    late JavaScriptPlatform javascriptPlatform;

    setUp(() {
      javascriptPlatform = JavaScriptMock();
      JavaScriptPlatform.instance = javascriptPlatform;
    });

    test('startNewEnvironment', () async {
      await javascriptPlatform.startNewJavaScriptEnvironment(
        'test',
      );
    });

    test('addJavaScriptChannel', () async {
      await javascriptPlatform.addJavaScriptChannel(
        'test',
        JavaScriptChannelParams(
          name: 'test',
          onMessageReceived: (message) async => JavaScriptReply(message: 'test'),
        ),
      );
    });

    test('removeJavaScriptChannel', () async {
      await javascriptPlatform.removeJavaScriptChannel('test', 'test');
    });

    test('runJavaScriptReturningResult', () async {
      await javascriptPlatform.runJavaScriptReturningResult('test', 'console.log("test")');
    });

    test('runJavaScriptFromFileReturningResult', () async {
      await javascriptPlatform.runJavaScriptFromFileReturningResult('test', 'test.js');
    });
  });
}
