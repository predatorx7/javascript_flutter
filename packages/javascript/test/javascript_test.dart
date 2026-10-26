import 'package:flutter_test/flutter_test.dart';
import 'package:javascript_flutter/javascript_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockJavaScriptPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements JavaScriptPlatform {}

class FakeChannelParams extends Fake implements JavaScriptChannelParams {}

class _TestExecutionException extends JavaScriptExecutionException {
  const _TestExecutionException(super.message);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeChannelParams());
  });

  group('JavaScript', () {
    late MockJavaScriptPlatform platform;
    late JavaScript javascript;

    setUp(() async {
      platform = MockJavaScriptPlatform();
      when(() => platform.startNewJavaScriptEnvironment(any()))
          .thenAnswer((_) async {});
      when(() => platform.dispose(any())).thenAnswer((_) async {});
      when(() => platform.setIsInspectable(any(), any()))
          .thenAnswer((_) async {});
      when(() => platform.addJavaScriptChannel(any(), any()))
          .thenAnswer((_) async {});
      when(() => platform.removeJavaScriptChannel(any(), any()))
          .thenAnswer((_) async {});
      JavaScriptPlatform.instance = platform;
      javascript = await JavaScript.createNew();
    });

    group('createNew', () {
      test('starts an environment with the instance id on the platform',
          () async {
        verify(() =>
                platform.startNewJavaScriptEnvironment(javascript.instanceId))
            .called(1);
        expect(javascript.instanceId, isNotEmpty);
        expect(javascript.platform, same(platform));
        // ignore: deprecated_member_use_from_same_package
        expect(javascript.engineId, javascript.instanceId);
        expect(javascript.isFunctional, isTrue);
        expect(javascript.unavailableReason, isNull);
      });

      test('uses a unique id per instance', () async {
        final other = await JavaScript.createNew(platform: platform);
        addTearDown(other.dispose);
        expect(other.instanceId, isNot(javascript.instanceId));
      });

      test('uses the given platform instead of the default', () async {
        final explicit = MockJavaScriptPlatform();
        when(() => explicit.startNewJavaScriptEnvironment(any()))
            .thenAnswer((_) async {});
        final other = await JavaScript.createNew(platform: explicit);
        expect(other.platform, same(explicit));
        verify(() => explicit.startNewJavaScriptEnvironment(other.instanceId))
            .called(1);
      });
    });

    group('runJavaScriptReturningResult', () {
      test('forwards the script and returns the platform value untouched',
          () async {
        when(() => platform.runJavaScriptReturningResult(any(), any()))
            .thenAnswer((_) async => '42');

        final result = await javascript.runJavaScriptReturningResult('"42"');

        expect(result, isA<String>());
        expect(result, '42');
        verify(() => platform.runJavaScriptReturningResult(
            javascript.instanceId, '"42"')).called(1);
      });

      test('keeps an empty string as an empty string', () async {
        when(() => platform.runJavaScriptReturningResult(any(), any()))
            .thenAnswer((_) async => '');

        expect(await javascript.runJavaScriptReturningResult('1 + 1'), '');
      });

      test('does not decode JSON strings', () async {
        when(() => platform.runJavaScriptReturningResult(any(), any()))
            .thenAnswer((_) async => '{"a":1}');

        expect(
          await javascript.runJavaScriptReturningResult('x'),
          '{"a":1}',
        );
      });
    });

    test('runJavaScriptFromFileReturningResult forwards the path', () async {
      when(() => platform.runJavaScriptFromFileReturningResult(any(), any()))
          .thenAnswer((_) async => 'done');

      final result =
          await javascript.runJavaScriptFromFileReturningResult('/tmp/a.js');

      expect(result, 'done');
      verify(() => platform.runJavaScriptFromFileReturningResult(
          javascript.instanceId, '/tmp/a.js')).called(1);
    });

    test('addJavaScriptChannel forwards the params', () async {
      final params = JavaScriptChannelParams(
        name: 'Test',
        onMessageReceived: (message) => JavaScriptReply(message: 'ok'),
      );

      await javascript.addJavaScriptChannel(params);

      verify(() => platform.addJavaScriptChannel(javascript.instanceId, params))
          .called(1);
    });

    test('removeJavaScriptChannel forwards the name', () async {
      await javascript.removeJavaScriptChannel('Test');

      verify(() =>
              platform.removeJavaScriptChannel(javascript.instanceId, 'Test'))
          .called(1);
    });

    test('setIsInspectable forwards the flag', () async {
      await javascript.setIsInspectable(true);

      verify(() => platform.setIsInspectable(javascript.instanceId, true))
          .called(1);
    });

    group('dispose', () {
      test('forwards to the platform and marks the instance closed', () async {
        await javascript.dispose();

        verify(() => platform.dispose(javascript.instanceId)).called(1);
        expect(javascript.isFunctional, isFalse);
        expect(javascript.unavailableReason,
            isA<JavaScriptEnvironmentClosedException>());
      });

      test('a second dispose throws', () async {
        await javascript.dispose();

        await expectLater(
          javascript.dispose(),
          throwsA(isA<JavaScriptEnvironmentClosedException>()),
        );
        verify(() => platform.dispose(javascript.instanceId)).called(1);
      });

      test('use after dispose throws without reaching the platform', () async {
        await javascript.dispose();

        await expectLater(
          javascript.runJavaScriptReturningResult('1'),
          throwsA(isA<JavaScriptEnvironmentClosedException>()),
        );
        await expectLater(
          javascript.runJavaScriptFromFileReturningResult('a.js'),
          throwsA(isA<JavaScriptEnvironmentClosedException>()),
        );
        await expectLater(
          javascript.setIsInspectable(true),
          throwsA(isA<JavaScriptEnvironmentClosedException>()),
        );
        verifyNever(() => platform.runJavaScriptReturningResult(any(), any()));
      });
    });

    group('errors from the platform', () {
      test('an unavailable platform exception latches and is rethrown',
          () async {
        const reason = JavaScriptEnvironmentUninitializedException('gone');
        when(() => platform.runJavaScriptReturningResult(any(), any()))
            .thenThrow(reason);

        await expectLater(
          javascript.runJavaScriptReturningResult('1'),
          throwsA(same(reason)),
        );

        expect(javascript.isFunctional, isFalse);
        expect(javascript.unavailableReason, same(reason));

        // Subsequent calls rethrow the latched reason without hitting the platform again.
        await expectLater(
          javascript.runJavaScriptReturningResult('2'),
          throwsA(same(reason)),
        );
        await expectLater(
          javascript.removeJavaScriptChannel('x'),
          throwsA(same(reason)),
        );
        verify(() => platform.runJavaScriptReturningResult(any(), any()))
            .called(1);
      });

      test('an execution exception propagates unchanged and does not latch',
          () async {
        const error = _TestExecutionException('boom');
        when(() => platform.runJavaScriptReturningResult(any(), any()))
            .thenThrow(error);

        await expectLater(
          javascript.runJavaScriptReturningResult('throw 1'),
          throwsA(same(error)),
        );

        expect(javascript.isFunctional, isTrue);
        expect(javascript.unavailableReason, isNull);

        when(() => platform.runJavaScriptReturningResult(any(), any()))
            .thenAnswer((_) async => 'fine');
        expect(await javascript.runJavaScriptReturningResult('ok'), 'fine');
      });
    });
  });
}
