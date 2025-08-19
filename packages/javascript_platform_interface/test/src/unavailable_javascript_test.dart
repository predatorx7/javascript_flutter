import 'package:test/test.dart';
import 'package:javascript_platform_interface/src/unavailable_javascript.dart';
import 'package:javascript_platform_interface/src/api/api.dart';

void main() {
  group('$JavaScriptUnavailablePlatform', () {
    late JavaScriptUnavailablePlatform platform;

    setUp(() async {
      platform = JavaScriptUnavailablePlatform(
          JavaScriptEnvironmentUninitializedException('Platform is unavailable'));
    });

    test('addJavaScriptChannel', () async {
      expect(() {
        return platform.addJavaScriptChannel(
          'test',
          JavaScriptChannelParams(
            name: 'test',
            onMessageReceived: (message) async => JavaScriptReply(message: 'test'),
          ),
        );
      }, throwsA(isA<JavaScriptEnvironmentUninitializedException>()));
    });

    test('dispose', () async {
      expect(() {
        return platform.dispose('test');
      }, throwsA(isA<JavaScriptEnvironmentUninitializedException>()));
    });

    test('removeJavaScriptChannel', () async {
      expect(() {
        return platform.removeJavaScriptChannel('test', 'test');
      }, throwsA(isA<JavaScriptEnvironmentUninitializedException>()));
    });

    test('runJavaScriptReturningResult', () async {
      expect(() {
        return platform.runJavaScriptReturningResult('test', 'test');
      }, throwsA(isA<JavaScriptEnvironmentUninitializedException>()));
    });

    test('runJavaScriptFromFileReturningResult', () async {
      expect(() {
        return platform.runJavaScriptFromFileReturningResult('test', 'test');
      }, throwsA(isA<JavaScriptEnvironmentUninitializedException>()));
    });

    test('setIsInspectable', () async {
      expect(() {
        return platform.setIsInspectable('test', true);
      }, throwsA(isA<JavaScriptEnvironmentUninitializedException>()));
    });

    test('startNewJavaScriptEnvironment', () async {
      expect(() {
        return platform.startNewJavaScriptEnvironment('test');
      }, throwsA(isA<JavaScriptEnvironmentUninitializedException>()));
    });
  });
}
