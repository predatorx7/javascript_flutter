// Exercises every Android messaging transport (message ports, console
// messaging and polling) by forcing each one in turn on a device that supports
// all of them. Skipped on other platforms.
//
// Run with `flutter test integration_test/android_transports_test.dart -d <android device>`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart' hide test;
import 'package:flutter_test/flutter_test.dart' as flutter_test show test;
import 'package:integration_test/integration_test.dart';
import 'package:javascript_android/javascript_android.dart';
import 'package:javascript_flutter/javascript_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isAndroid) {
    flutter_test.test('Android transports', () {}, skip: 'Android only');
    return;
  }

  // Transports the device can actually select, discovered with nothing
  // disabled. Selection order is messagePort, consoleMessaging, polling, so the
  // default pick tells us what is supported (e.g. a CI emulator WebView may lack
  // JS_FEATURE_MESSAGE_PORTS).
  late final JavaScriptAndroidMessagingTransport defaultTransport;

  setUpAll(() async {
    JavaScriptAndroid.debugDisabledTransports = {};
    final probe = await JavaScript.createNew();
    defaultTransport = JavaScriptAndroid.debugTransportFor(probe.instanceId)!;
    await probe.dispose();
  });

  for (final transport in JavaScriptAndroidMessagingTransport.values) {
    group('transport ${transport.name}', () {
      late JavaScript js;

      // Registers a test that is reported as skipped when this device cannot
      // select the transport under test.
      void test(String name, Future<void> Function() body) {
        flutter_test.test(name, () async {
          if (transport.index < defaultTransport.index) {
            markTestSkipped(
              '${transport.name} is not supported by this device '
              '(default transport: ${defaultTransport.name})',
            );
            return;
          }
          await body();
        });
      }

      setUp(() async {
        if (transport.index < defaultTransport.index) return;
        // Disable every transport that comes before the one under test, so the
        // selection order lands on it.
        JavaScriptAndroid.debugDisabledTransports = {
          for (final t in JavaScriptAndroidMessagingTransport.values)
            if (t.index < transport.index) t,
        };
        js = await JavaScript.createNew();
      });

      tearDown(() async {
        JavaScriptAndroid.debugDisabledTransports = {};
        if (transport.index < defaultTransport.index) return;
        await js.dispose();
      });

      Future<Object?> run(String source) =>
          js.runJavaScriptReturningResult(source);

      test('is the selected transport', () async {
        expect(JavaScriptAndroid.debugTransportFor(js.instanceId), transport);
      });

      test('a JSON message round-trips with a JSON reply', () async {
        Object? received;
        await js.addJavaScriptChannel(
          JavaScriptChannelParams(
            name: 'Sum',
            onMessageReceived: (message) {
              received = jsonDecode(message.message!);
              final data = received! as Map;
              return JavaScriptReply(
                message: jsonEncode({'sum': data['a'] + data['b']}),
              );
            },
          ),
        );
        final result = await run('''
          sendMessage('Sum', JSON.stringify({a: 40, b: 2}))
            .then(reply => JSON.parse(reply))
            .then(data => String(data.sum));
        ''');
        expect(received, {'a': 40, 'b': 2});
        expect(result, '42');
      });

      test('a plain string message and reply are verbatim', () async {
        String? received;
        await js.addJavaScriptChannel(
          JavaScriptChannelParams(
            name: 'Echo',
            onMessageReceived: (message) {
              received = message.message;
              return JavaScriptReply(
                message: '  "echo: ${message.message}" \n',
              );
            },
          ),
        );
        final result = await run("sendMessage('Echo', ' héllo \"wörld\" 🌍 ')");
        expect(received, ' héllo "wörld" 🌍 ');
        expect(result, '  "echo: ${received!}" \n');
      });

      test('many concurrent messages are all answered', () async {
        await js.addJavaScriptChannel(
          JavaScriptChannelParams(
            name: 'Double',
            onMessageReceived: (message) async {
              return JavaScriptReply(
                message: '${int.parse(message.message!) * 2}',
              );
            },
          ),
        );
        final result = await run('''
          Promise.all(Array.from({length: 50}, (_, i) => sendMessage('Double', String(i))))
            .then(replies => replies.join(','));
        ''');
        expect(result, List.generate(50, (i) => i * 2).join(','));
      });

      test('a handler error rejects the JavaScript promise', () async {
        await js.addJavaScriptChannel(
          JavaScriptChannelParams(
            name: 'Bad',
            onMessageReceived: (_) => throw StateError('handler boom'),
          ),
        );
        await expectLater(
          run("sendMessage('Bad', 'x')"),
          throwsA(
            isA<JavaScriptExecutionException>().having(
              (e) => e.toString(),
              'message',
              contains('handler boom'),
            ),
          ),
        );
      });

      test('setTimeout works', () async {
        final result = await run('''
          new Promise(resolve => {
            const order = [];
            setTimeout(() => { order.push("b"); resolve(order.join(",")); }, 150);
            setTimeout(() => order.push("a"), 10);
          })
        ''');
        expect(result, 'a,b');
      });

      test('plain string results are returned verbatim', () async {
        expect(await run('"42"'), '42');
        expect(await run('JSON.stringify({a: 1})'), '{"a":1}');
        expect(await run('"null"'), 'null');
        expect(await run('42'), '');
        expect(await run('Promise.resolve("later")'), 'later');
      });
    });
  }
}
