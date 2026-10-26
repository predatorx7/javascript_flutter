import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/javascript_runtime.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/extensions/handle_promises.dart';
import 'package:javascript_darwin/src/third_party/flutter_js/lib/javascriptcore/jscore_runtime.dart';

void main() {
  test('disposing one runtime does not unregister another runtime', () {
    final first = JavascriptCoreRuntime();
    final second = JavascriptCoreRuntime();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    second.onMessage('echo', (value) => value);
    first.dispose();
    expect(second.evaluate('sendMessage("echo", "42")').stringResult, '42');
    expect(JavascriptRuntime.channelFunctionsRegistered,
        contains(second.getEngineInstanceId()));
  }, skip: !Platform.isMacOS);

  test('non-JSON JavaScript values do not release a null string', () {
    final runtime = JavascriptCoreRuntime();
    addTearDown(runtime.dispose);
    for (final script in [
      'undefined',
      '(function() {})',
      'Symbol("x")',
      'var cycle = {}; cycle.self = cycle; cycle',
    ]) {
      expect(runtime.jsonStringify(runtime.evaluate(script)), 'null');
    }
  }, skip: !Platform.isMacOS);

  test('promise polling stops after disposal', () async {
    final runtime = JavascriptCoreRuntime()..enableHandlePromises();
    final pending =
        runtime.handlePromise(runtime.evaluate('new Promise(() => {})'));
    final assertion = expectLater(pending, throwsStateError);
    runtime.dispose();
    await assertion;
  }, skip: !Platform.isMacOS);

  test('repeated native contexts unregister all channels', () {
    final before = JavascriptRuntime.channelFunctionsRegistered.length;
    for (var i = 0; i < 100; i++) {
      final runtime = JavascriptCoreRuntime();
      expect(runtime.evaluate('1 + 2').stringResult, '3');
      expect(runtime.evaluate('throw new Error("test")').isError, isTrue);
      expect(runtime.evaluate('Promise.resolve(42)').isPromise, isTrue);
      runtime.evaluate('setTimeout(function() {}, 60000)');
      runtime.dispose();
      runtime.dispose();
      expect(JavascriptRuntime.channelFunctionsRegistered.length, before);
      expect(() => runtime.evaluate('1'), throwsStateError);
    }
  }, skip: !Platform.isMacOS);

  test('late successful and failed channel replies do not enter dead JSC',
      () async {
    for (final fail in [false, true]) {
      final runtime = JavascriptCoreRuntime();
      final reply = Completer<String>();
      runtime.onMessage('late', (_) => reply.future);
      expect(runtime.evaluate('sendMessage("late", "null")').isPromise, isTrue);
      runtime.dispose();
      if (fail) {
        reply.completeError(StateError('late failure'));
      } else {
        reply.complete('late result');
      }
      await Future<void>.delayed(Duration.zero);
    }
  }, skip: !Platform.isMacOS);

  test('live async replies and JSON round trips still work', () async {
    final runtime = JavascriptCoreRuntime();
    addTearDown(runtime.dispose);
    runtime.onMessage('echo', (value) async => value);
    runtime.evaluate(
        'var answer; sendMessage("echo", "[1,2]").then(x => answer = x)');
    await Future<void>.delayed(Duration.zero);
    expect(runtime.jsonStringify(runtime.evaluate('answer')), '[1,2]');
    expect(runtime.convertValue<Map>(runtime.evaluate('({a: 1})')), {'a': 1});
  }, skip: !Platform.isMacOS);
}
