import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:javascript_platform_interface/src/method_channel_javascript.dart';
import 'package:javascript_platform_interface/src/api/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$MethodChannelJavaScript', () {
    late MethodChannelJavaScript methodChannelJavascript;
    final log = <MethodCall>[];

    setUp(() async {
      methodChannelJavascript = MethodChannelJavaScript();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        methodChannelJavascript.methodChannel,
        (methodCall) async {
          log.add(methodCall);
          switch (methodCall.method) {
            case 'addJavaScriptChannel':
              return null;
            case 'removeJavaScriptChannel':
              return null;
            case 'runJavaScriptReturningResult':
              return null;
            case 'dispose':
              return null;
            default:
              return null;
          }
        },
      );
    });

    tearDown(log.clear);

    test('addJavaScriptChannel', () async {
      await methodChannelJavascript.addJavaScriptChannel(
        'test',
        JavaScriptChannelParams(
          name: 'test',
          onMessageReceived: (message) async => JavaScriptReply(message: 'test'),
        ),
      );
      expect(log, <Matcher>[
        isMethodCall(
          'addJavaScriptChannel',
          arguments: [
            'test',
            {'name': 'test'},
          ],
        ),
      ]);
    });
  });
}
