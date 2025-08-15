import 'package:flutter_test/flutter_test.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

class JavaScriptMock extends JavaScriptPlatform {
  @override
  Future<void> startJavaScriptEngine(String javascriptEngineId) async {
    return Future.value();
  }

  @override
  Future<void> setIsInspectable(String javascriptEngineId, bool isInspectable) async {
    return Future.value();
  }

  @override
  Future<void> addJavaScriptChannel(
    String javascriptEngineId,
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    return Future.value();
  }

  @override
  Future<void> dispose(String javascriptEngineId) async {
    return Future.value();
  }

  @override
  Future<void> removeJavaScriptChannel(
    String javascriptEngineId,
    String javaScriptChannelName,
  ) async {
    return Future.value();
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String javascriptEngineId, String javaScript) async {
    return Future.value();
  }

  @override
  Future<Object?> runJavaScriptFromFileReturningResult(
    String javascriptEngineId,
    String javaScriptFilePath,
  ) async {
    return Future.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('JavaScriptPlatformInterface', () {
    late JavaScriptPlatform javascriptPlatform;

    setUp(() {
      javascriptPlatform = JavaScriptMock();
      JavaScriptPlatform.instance = javascriptPlatform;
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
