import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:javascript_android/exception.dart';
import 'package:javascript_android/javascript_android.dart';
import 'package:javascript_android/src/pigeons/messages.pigeon.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

const _prefix = 'dev.flutter.pigeon.javascript_android';
const _api = '$_prefix.JavaScriptAndroidPlatformApi';

/// Fakes the native side of the pigeon host API.
class FakeHost {
  FakeHost({this.supportsPorts = true, this.supportsConsole = true});

  bool supportsPorts;
  bool supportsConsole;

  /// Every call received, as `method -> list of argument lists`.
  final calls = <String, List<List<Object?>>>{};

  /// Result of `runJavaScriptReturningResult`; may throw [PlatformException].
  FutureOr<String?> Function(String script) onRun = (_) => '';

  /// Identifier of the handler registered for each transport.
  int? portHandlerId;
  int? consoleHandlerId;

  final scripts = <String>[];

  static final _codec = const StandardMessageCodec();

  List<List<Object?>> callsOf(String method) => calls[method] ?? [];

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final method in [
      'startJavaScriptEnvironment',
      'dispose',
      'runJavaScriptReturningResult',
      'runJavaScriptFromFileReturningResult',
      'setIsInspectable',
      'setJavaScriptConsoleMessageHandler',
      'setJavaScriptMessagePortHandler',
      'postMessageToJavaScript',
    ]) {
      messenger.setMockMessageHandler('$_api.$method', (data) async {
        final args = (_codec.decodeMessage(data) as List).cast<Object?>();
        calls.putIfAbsent(method, () => []).add(args);
        try {
          final result = await _handle(method, args);
          return _codec.encodeMessage(<Object?>[result]);
        } on PlatformException catch (e) {
          return _codec.encodeMessage(<Object?>[e.code, e.message, e.details]);
        }
      });
    }
    for (final name in ['ConsoleMessage', 'MessagePort']) {
      messenger.setMockMessageHandler(
        '$_prefix.JavaScriptAndroid${name}Handler.pigeon_defaultConstructor',
        (data) async => _codec.encodeMessage(<Object?>[null]),
      );
    }
  }

  void uninstall() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final key in calls.keys) {
      messenger.setMockMessageHandler('$_api.$key', null);
    }
  }

  Future<Object?> _handle(String method, List<Object?> args) async {
    switch (method) {
      case 'runJavaScriptReturningResult':
        final script = args[1]! as String;
        scripts.add(script);
        return onRun(script);
      case 'runJavaScriptFromFileReturningResult':
        return onRun('file:${args[1]}');
      case 'setJavaScriptMessagePortHandler':
        if (supportsPorts) portHandlerId = args[1]! as int;
        return supportsPorts;
      case 'setJavaScriptConsoleMessageHandler':
        if (supportsConsole) consoleHandlerId = args[1]! as int;
        return supportsConsole;
      default:
        return null;
    }
  }

  JavaScriptAndroidMessagePortHandler get portHandler =>
      PigeonInstanceManager.instance
          .getInstanceWithWeakReference<JavaScriptAndroidMessagePortHandler>(
              portHandlerId!)!;

  JavaScriptAndroidConsoleMessageHandler get consoleHandler =>
      PigeonInstanceManager.instance
          .getInstanceWithWeakReference<JavaScriptAndroidConsoleMessageHandler>(
              consoleHandlerId!)!;
}

Future<void> _pump() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JavascriptAndroid', () {
    test('can be registered', () {
      JavaScriptAndroid.registerWith();
      expect(JavaScriptPlatform.instance, isA<JavaScriptAndroid>());
    });
  });

  late FakeHost host;
  late JavaScriptAndroid platform;
  var counter = 0;
  late String id;
  final startedIds = <String>[];

  setUp(() {
    host = FakeHost();
    host.install();
    platform = JavaScriptAndroid();
    id = 'test-${counter++}';
  });

  tearDown(() async {
    // Stop polling timers so they cannot leak into the next test's fake host.
    for (final started in startedIds) {
      try {
        await platform.dispose(started);
      } catch (_) {}
    }
    startedIds.clear();
    JavaScriptAndroid.debugDisabledTransports = {};
    host.uninstall();
  });

  Future<void> start([String? instanceId]) async {
    final target = instanceId ?? id;
    startedIds.add(target);
    await platform.startNewJavaScriptEnvironment(target);
  }

  group('results are returned verbatim', () {
    for (final value in [
      '42',
      '{"a":1}',
      '',
      'true',
      'null',
      'false',
      '1.5',
      '[1,2]',
      '  padded ',
      'plain text',
    ]) {
      test('"$value" stays a String', () async {
        await start();
        host.onRun = (_) => value;
        final result = await platform.runJavaScriptReturningResult(id, 'x');
        expect(result, isA<String>());
        expect(result, value);
      });
    }

    test('a null host result becomes an empty string', () async {
      await start();
      host.onRun = (_) => null;
      expect(await platform.runJavaScriptReturningResult(id, 'x'), '');
    });

    test('file results are returned verbatim too', () async {
      await start();
      host.onRun = (_) => '{"ok":true}';
      expect(
        await platform.runJavaScriptFromFileReturningResult(id, '/a.js'),
        '{"ok":true}',
      );
      host.onRun = (_) => null;
      expect(
        await platform.runJavaScriptFromFileReturningResult(id, '/a.js'),
        '',
      );
    });
  });

  group('transport selection', () {
    test('prefers message ports', () async {
      await start();
      expect(
        JavaScriptAndroid.debugTransportFor(id),
        JavaScriptAndroidMessagingTransport.messagePort,
      );
      expect(host.callsOf('setJavaScriptConsoleMessageHandler'), isEmpty);
    });

    test('falls back to console messaging when ports are unsupported',
        () async {
      host.supportsPorts = false;
      await start();
      expect(
        JavaScriptAndroid.debugTransportFor(id),
        JavaScriptAndroidMessagingTransport.consoleMessaging,
      );
    });

    test('falls back to polling when nothing is supported', () async {
      host.supportsPorts = false;
      host.supportsConsole = false;
      await start();
      expect(
        JavaScriptAndroid.debugTransportFor(id),
        JavaScriptAndroidMessagingTransport.polling,
      );
    });

    test('debugDisabledTransports skips transports', () async {
      JavaScriptAndroid.debugDisabledTransports = {
        JavaScriptAndroidMessagingTransport.messagePort,
      };
      await start();
      expect(
        JavaScriptAndroid.debugTransportFor(id),
        JavaScriptAndroidMessagingTransport.consoleMessaging,
      );
      expect(host.callsOf('setJavaScriptMessagePortHandler'), isEmpty);

      final id2 = '$id-b';
      JavaScriptAndroid.debugDisabledTransports = {
        JavaScriptAndroidMessagingTransport.messagePort,
        JavaScriptAndroidMessagingTransport.consoleMessaging,
      };
      await start(id2);
      expect(
        JavaScriptAndroid.debugTransportFor(id2),
        JavaScriptAndroidMessagingTransport.polling,
      );
    });

    test('the transport is forgotten on dispose', () async {
      await start();
      await platform.dispose(id);
      expect(JavaScriptAndroid.debugTransportFor(id), isNull);
    });

    test('the port script is injected only for the port transport', () async {
      await start();
      expect(host.scripts.first, contains('usePort: true'));
      expect(host.scripts.first, contains('javascript_android_host'));
    });
  });

  group('message port routing', () {
    test('routes a message to the channel and replies over the port', () async {
      await start();
      final received = <String?>[];
      await platform.addJavaScriptChannel(
        id,
        JavaScriptChannelParams(
          name: 'Echo',
          onMessageReceived: (message) {
            received.add(message.message);
            return JavaScriptReply(message: 'echo: ${message.message}');
          },
        ),
      );

      const body = '{"a": "b \\" c"}\n';
      host.portHandler.onMessage(
        host.portHandler,
        jsonEncode({'channelName': 'Echo', 'id': 7, 'message': body}),
      );
      await _pump();

      expect(received, [body]);
      final posts = host.callsOf('postMessageToJavaScript');
      // The SetTimeout channel does not post anything on its own.
      expect(posts, hasLength(1));
      expect(posts.single[0], id);
      expect(jsonDecode(posts.single[1]! as String), {
        'channelName': 'Echo',
        'id': 7,
        'ok': true,
        'message': 'echo: $body',
      });
    });

    test('a null reply message is delivered as a real null', () async {
      await start();
      await platform.addJavaScriptChannel(
        id,
        JavaScriptChannelParams(
          name: 'Nothing',
          onMessageReceived: (_) => JavaScriptReply(message: null),
        ),
      );
      host.portHandler.onMessage(
        host.portHandler,
        jsonEncode({'channelName': 'Nothing', 'id': 1, 'message': 'x'}),
      );
      await _pump();
      final reply = jsonDecode(
        host.callsOf('postMessageToJavaScript').single[1]! as String,
      );
      expect(reply['ok'], true);
      expect(reply.containsKey('message'), isTrue);
      expect(reply['message'], isNull);
    });

    test('message ids stay unique when a channel is re-added', () {
      // Ids come from one counter shared by every HostMessenger.
      return start().then((_) {
        final script = host.scripts.first;
        expect(script, contains('nextMessageId++'));
        expect(script, isNot(contains('this.id')));
      });
    });

    test('removing a channel rejects its in-flight sends', () async {
      await start();
      await platform.addJavaScriptChannel(
        id,
        JavaScriptChannelParams(
          name: 'Gone',
          onMessageReceived: (_) => JavaScriptReply(message: ''),
        ),
      );
      host.scripts.clear();
      await platform.removeJavaScriptChannel(id, 'Gone');
      final script = host.scripts.single;
      expect(script, contains('rejectAll('));
      expect(script, contains('Channel Gone was removed'));
      expect(
        script.indexOf('rejectAll('),
        lessThan(script.indexOf('delete ')),
      );
    });

    test('a late reply after a channel is re-added keeps its own id', () async {
      await start();
      final release = Completer<void>();
      var calls = 0;
      JavaScriptChannelParams params(String name) => JavaScriptChannelParams(
            name: name,
            onMessageReceived: (m) async {
              calls++;
              if (m.message == 'old') await release.future;
              return JavaScriptReply(message: 'reply ${m.message}');
            },
          );
      await platform.addJavaScriptChannel(id, params('Re'));
      host.portHandler.onMessage(host.portHandler,
          jsonEncode({'channelName': 'Re', 'id': 5, 'message': 'old'}));
      await _pump();
      await platform.removeJavaScriptChannel(id, 'Re');
      await platform.addJavaScriptChannel(id, params('Re'));
      // The new messenger gets a fresh, never-used id from the shared counter.
      host.portHandler.onMessage(host.portHandler,
          jsonEncode({'channelName': 'Re', 'id': 6, 'message': 'new'}));
      await _pump();
      release.complete();
      await _pump();

      expect(calls, 2);
      final replies = host
          .callsOf('postMessageToJavaScript')
          .map((c) => jsonDecode(c[1]! as String) as Map)
          .toList();
      expect(replies.map((r) => r['id']).toSet(), {5, 6});
      expect(replies.firstWhere((r) => r['id'] == 6)['message'], 'reply new');
    });

    test('a throwing handler rejects with the error string', () async {
      await start();
      await platform.addJavaScriptChannel(
        id,
        JavaScriptChannelParams(
          name: 'Bad',
          onMessageReceived: (_) => throw StateError('nope'),
        ),
      );
      host.portHandler.onMessage(
        host.portHandler,
        jsonEncode({'channelName': 'Bad', 'id': 2, 'message': 'x'}),
      );
      await _pump();
      final reply = jsonDecode(
        host.callsOf('postMessageToJavaScript').single[1]! as String,
      );
      expect(reply['ok'], false);
      expect(reply['id'], 2);
      expect(reply['error'], contains('nope'));
    });

    test('an unknown channel is rejected gracefully', () async {
      await start();
      host.portHandler.onMessage(
        host.portHandler,
        jsonEncode({'channelName': 'Missing', 'id': 3, 'message': 'x'}),
      );
      await _pump();
      final reply = jsonDecode(
        host.callsOf('postMessageToJavaScript').single[1]! as String,
      );
      expect(reply['ok'], false);
      expect(reply['id'], 3);
      expect(reply['error'], contains('Missing'));
    });

    test('malformed port messages are ignored', () async {
      await start();
      host.portHandler.onMessage(host.portHandler, 'not json');
      host.portHandler.onMessage(host.portHandler, '{"id": 1}');
      await _pump();
      expect(host.callsOf('postMessageToJavaScript'), isEmpty);
    });

    test('the SetTimeout channel replies and schedules the callback', () async {
      await start();
      host.portHandler.onMessage(
        host.portHandler,
        jsonEncode({
          'channelName': 'SetTimeout',
          'id': 0,
          'message': jsonEncode({'timeoutIndex': '5', 'timeout': 10}),
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(
        jsonDecode(
            host.callsOf('postMessageToJavaScript').single[1]! as String),
        containsPair('message', ''),
      );
      expect(
        host.scripts
            .any((s) => s.contains('__NATIVE_HOST_JS__setTimeoutCallbacks[5]')),
        isTrue,
      );
    });
  });

  group('console messaging routing', () {
    test('still routes console notifications', () async {
      host.supportsPorts = false;
      await start();
      final received = <String?>[];
      await platform.addJavaScriptChannel(
        id,
        JavaScriptChannelParams(
          name: 'Echo',
          onMessageReceived: (message) {
            received.add(message.message);
            return JavaScriptReply(message: 'echo: ${message.message}');
          },
        ),
      );
      host.onRun = (script) {
        if (script.contains('getPendingMessages("Echo")')) {
          return jsonEncode({
            'Echo': [
              {'id': 4, 'message': 'hi'},
            ],
          });
        }
        return '';
      };

      final notification = jsonEncode({
        'tag': 'CONSOLE_MESSAGING_HACK',
        'id': 4,
        'channelName': 'Echo',
      });
      host.consoleHandler.onMessage(
        host.consoleHandler,
        jsonEncode({'level': 16, 'message': notification}),
      );
      await _pump();

      expect(received, ['hi']);
      expect(host.callsOf('postMessageToJavaScript'), isEmpty);
      expect(
        host.scripts.any(
          (s) => s.contains('["Echo"].resolveById(4, "echo: hi")'),
        ),
        isTrue,
      );
    });

    test('ignores console messages that are not notifications', () async {
      host.supportsPorts = false;
      await start();
      final before = host.scripts.length;
      host.consoleHandler.onMessage(
        host.consoleHandler,
        jsonEncode({'level': 16, 'message': 'something else'}),
      );
      await _pump();
      expect(host.scripts.skip(before).toList(), isEmpty);
    });
  });

  group('start-up failures', () {
    test('a failing start disposes the isolate and forgets the instance',
        () async {
      host.onRun = (script) {
        if (script.contains('__NATIVE_HOST_JS__setTimeoutCount')) {
          throw PlatformException(code: 'Weird');
        }
        return '';
      };
      host.supportsPorts = false;
      host.supportsConsole = false;
      startedIds.add(id);
      await expectLater(
        platform.startNewJavaScriptEnvironment(id),
        throwsA(isA<PlatformException>()),
      );
      expect(host.callsOf('dispose').single[0], id);
      expect(JavaScriptAndroid.debugTransportFor(id), isNull);
      // The polling timer must be stopped: no further polling scripts run.
      final count = host.scripts.length;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(host.scripts.length, count);
    });
  });

  group('polling', () {
    test('polls pending messages and replies via script', () async {
      host.supportsPorts = false;
      host.supportsConsole = false;
      await start();
      var served = false;
      host.onRun = (script) {
        if (script.contains('getPendingMessages("Echo")') && !served) {
          served = true;
          return jsonEncode({
            'Echo': [
              {'id': 9, 'message': 'poll'},
            ],
          });
        }
        return script.contains('getPendingMessages') ? '{"Echo":[]}' : '';
      };
      await platform.addJavaScriptChannel(
        id,
        JavaScriptChannelParams(
          name: 'Echo',
          onMessageReceived: (m) =>
              JavaScriptReply(message: 'got ${m.message}'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        host.scripts.any((s) => s.contains('resolveById(9, "got poll")')),
        isTrue,
      );
    });
  });

  group('exception mapping', () {
    Future<Object?> failWith(PlatformException e) async {
      host.onRun = (_) => '';
      id = 'test-${counter++}';
      await start();
      host.onRun = (_) => throw e;
      return platform.runJavaScriptReturningResult(id, 'x');
    }

    test('EvaluationFailedException keeps the message', () async {
      await expectLater(
        failWith(PlatformException(
          code: 'EvaluationFailedException',
          message: 'Error: boom',
        )),
        throwsA(
          isA<JavaScriptAndroidEvaluationFailedException>()
              .having((e) => e.toString(), 'toString', contains('boom'))
              .having((e) => e, 'is execution',
                  isA<JavaScriptExecutionException>()),
        ),
      );
    });

    test('DataInputException', () async {
      await expectLater(
        failWith(PlatformException(code: 'DataInputException', message: 'm')),
        throwsA(isA<JavaScriptAndroidDataInputException>()),
      );
    });

    test('EvaluationResultSizeLimitExceededException', () async {
      await expectLater(
        failWith(PlatformException(
          code: 'EvaluationResultSizeLimitExceededException',
        )),
        throwsA(
            isA<JavaScriptAndroidEvaluationResultSizeLimitExceededException>()),
      );
    });

    test('dead environment exceptions', () async {
      await expectLater(
        failWith(PlatformException(code: 'SandboxDeadException')),
        throwsA(isA<JavaScriptAndroidSandboxDeadException>()),
      );
      await expectLater(
        failWith(PlatformException(code: 'IsolateTerminatedException')),
        throwsA(isA<JavaScriptAndroidIsolateTerminatedException>()),
      );
      await expectLater(
        failWith(PlatformException(code: 'MemoryLimitExceededException')),
        throwsA(isA<JavaScriptAndroidMemoryLimitExceededException>()),
      );
      await expectLater(
        failWith(PlatformException(code: 'SandboxUnsupportedException')),
        throwsA(isA<JavaScriptAndroidSandboxUnsupportedException>()),
      );
    });

    test('a missing isolate maps to the gone exception', () async {
      await expectLater(
        failWith(PlatformException(
          code: 'IllegalStateException',
          message: 'No active isolate with id x',
        )),
        throwsA(isA<JavaScriptAndroidEnvironmentGoneException>()),
      );
    });

    test('other platform exceptions are rethrown', () async {
      await expectLater(
        failWith(PlatformException(code: 'Weird', message: 'w')),
        throwsA(isA<PlatformException>()),
      );
    });

    test('an unknown instance id throws', () {
      expect(
        () => platform.addJavaScriptChannel(
          'nope',
          JavaScriptChannelParams(
            name: 'X',
            onMessageReceived: (_) => JavaScriptReply(message: ''),
          ),
        ),
        throwsA(isA<JavaScriptAndroidEnvironmentNotFoundException>()),
      );
    });
  });
}
