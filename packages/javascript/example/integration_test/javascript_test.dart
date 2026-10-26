// Device tests pinning the public behavior of `javascript_flutter`.
//
// Run with `flutter test integration_test` from `packages/javascript/example`
// against an Android emulator, an iOS simulator or the macOS desktop target.
// Every expectation here must hold on every platform; that is the contract.
//
// Contract: the value a script evaluates to, or the value its Promise resolves
// to, is returned to Dart as a `String` exactly as-is. Nothing is decoded or
// coerced. A script that evaluates to anything other than a string resolves
// to an empty string. Scripts that throw, and promises that reject, throw a
// `JavaScriptExecutionException` carrying the JavaScript error message.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:javascript_flutter/javascript_flutter.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late JavaScript js;

  setUp(() async {
    js = await JavaScript.createNew();
  });

  tearDown(() async {
    await js.dispose();
  });

  Future<Object?> run(String source) => js.runJavaScriptReturningResult(source);

  group('string results are returned verbatim', () {
    final cases = <String, String>{
      '"hello"': 'hello',
      '""': '',
      '"42"': '42',
      '"true"': 'true',
      '"null"': 'null',
      '"undefined"': 'undefined',
      "'\"quoted\"'": '"quoted"',
      '"  padded  "': '  padded  ',
      '"line1\\nline2"': 'line1\nline2',
      '"héllo wörld 🌍"': 'héllo wörld 🌍',
      '"a".repeat(100000)': 'a' * 100000,
      'JSON.stringify({a: 1, b: [1, 2, 3], c: null})':
          '{"a":1,"b":[1,2,3],"c":null}',
      'String(40 + 2)': '42',
      '(40 + 2).toString()': '42',
      '`template \${1 + 1}`': 'template 2',
      'var s = "stateful"; s': 'stateful',
      'const f = () => "from function"; f()': 'from function',
      '(() => "iife")()': 'iife',
      '"last"; "expression"': 'expression',
    };

    cases.forEach((source, expected) {
      test(source, () async {
        final result = await run(source);
        expect(result, isA<String>());
        expect(result, expected);
      });
    });

    test('multi-line script whose completion value is a string', () async {
      final result = await run('''
        function add(a, b) {
          return a + b;
        }
        const total = add(40, 2);
        JSON.stringify({ total });
      ''');
      expect(result, '{"total":42}');
    });

    test('a JSON string can be decoded by the caller', () async {
      final result = await run(
        'JSON.stringify({a: 1, b: "two", c: [true, null]})',
      );
      final decoded = jsonDecode(result! as String);
      expect(decoded, {
        'a': 1,
        'b': 'two',
        'c': [true, null],
      });
    });
  });

  group('non-string results resolve to an empty string', () {
    final cases = <String>[
      '40 + 2',
      '0',
      '-0',
      '1.5',
      '1e21',
      '2 ** 63',
      'NaN',
      'Infinity',
      '-Infinity',
      'true',
      'false',
      'null',
      'undefined',
      'void 0',
      '10n',
      'Symbol("s")',
      '() => 1',
      'function f() {}; f',
      '({a: 1})',
      '[1, 2, 3]',
      'new Date(0)',
      'new Map([[1, 2]])',
      'var circular = {}; circular.self = circular; circular',
      // A thenable is not a Promise, so it is not awaited (the Android engine only awaits real Promises).
      '({then(resolve) { resolve("x"); }})',
      'var x = 1;',
      'if (true) { 1 }',
      '',
      '// only a comment',
    ];

    for (final source in cases) {
      test(source.isEmpty ? '<empty script>' : source, () async {
        final result = await run(source);
        expect(result, isA<String>());
        expect(result, '');
      });
    }
  });

  group('promises', () {
    test('a promise resolving to a string yields that string', () async {
      expect(await run('Promise.resolve("hi")'), 'hi');
    });

    test(
      'a promise resolving to an empty string yields an empty string',
      () async {
        expect(await run('Promise.resolve("")'), '');
      },
    );

    test('a promise resolving to JSON text yields it verbatim', () async {
      expect(await run('Promise.resolve(JSON.stringify({a: 1}))'), '{"a":1}');
    });

    test('a promise that resolves later is awaited', () async {
      expect(
        await run(
          'new Promise(resolve => setTimeout(() => resolve("late"), 50))',
        ),
        'late',
      );
    });

    test('an async function result is awaited', () async {
      expect(
        await run('(async () => { await null; return "async"; })()'),
        'async',
      );
    });

    test('an async function chain is awaited', () async {
      final result = await run('''
        const sum = async (a, b) => a + b;
        sum(1, 2).then(v => String(v));
      ''');
      expect(result, '3');
    });

    test(
      'a promise that adopts a thenable resolves to the thenable value',
      () async {
        expect(
          await run('Promise.resolve({then(resolve) { resolve("adopted"); }})'),
          'adopted',
        );
      },
    );

    test(
      'a promise resolving to a non-string yields an empty string',
      () async {
        expect(await run('Promise.resolve(42)'), '');
        expect(await run('Promise.resolve({a: 1})'), '');
        expect(await run('Promise.resolve(null)'), '');
        expect(await run('Promise.resolve(undefined)'), '');
        expect(await run('Promise.resolve(false)'), '');
      },
    );

    test('a rejected promise throws with the rejection reason', () async {
      await expectLater(
        run('Promise.reject(new Error("boom"))'),
        throwsA(
          isA<JavaScriptExecutionException>().having(
            (e) => e.toString(),
            'message',
            contains('boom'),
          ),
        ),
      );
    });

    test('an async function that throws rejects with the reason', () async {
      await expectLater(
        run('(async () => { throw new Error("async boom"); })()'),
        throwsA(
          isA<JavaScriptExecutionException>().having(
            (e) => e.toString(),
            'message',
            contains('async boom'),
          ),
        ),
      );
    });

    test('a promise rejected with a non-Error value throws', () async {
      await expectLater(
        run('Promise.reject("plain reason")'),
        throwsA(
          isA<JavaScriptExecutionException>().having(
            (e) => e.toString(),
            'message',
            contains('plain reason'),
          ),
        ),
      );
    });
  });

  group('errors', () {
    test('a thrown Error surfaces as JavaScriptExecutionException', () async {
      await expectLater(
        run('throw new Error("bad thing")'),
        throwsA(
          isA<JavaScriptExecutionException>().having(
            (e) => e.toString(),
            'message',
            contains('bad thing'),
          ),
        ),
      );
    });

    test('a ReferenceError surfaces as JavaScriptExecutionException', () async {
      await expectLater(
        run('definitelyNotDefined + 1'),
        throwsA(
          isA<JavaScriptExecutionException>().having(
            (e) => e.toString(),
            'message',
            contains('definitelyNotDefined'),
          ),
        ),
      );
    });

    test('a syntax error surfaces as JavaScriptExecutionException', () async {
      await expectLater(
        run('this is not javascript'),
        throwsA(isA<JavaScriptExecutionException>()),
      );
    });

    test('the environment keeps working after an error', () async {
      await expectLater(run('throw new Error("x")'), throwsA(anything));
      expect(await run('"still alive"'), 'still alive');
    });
  });

  group('environment', () {
    test('state persists between evaluations', () async {
      await run('var counter = 1;');
      await run('counter += 1;');
      expect(await run('String(counter)'), '2');
    });

    test('top-level let and const persist between evaluations', () async {
      await run('let letValue = "let"; const constValue = "const";');
      expect(await run('letValue + " " + constValue'), 'let const');
    });

    test('instances are isolated from each other', () async {
      final other = await JavaScript.createNew();
      addTearDown(other.dispose);
      await run('var onlyHere = "mine";');
      expect(await other.run('typeof onlyHere'), 'undefined');
    });

    test('runJavaScriptFromFileReturningResult evaluates a file', () async {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/javascript_flutter_test_${DateTime.now().microsecondsSinceEpoch}.js',
      );
      await file.create(recursive: true);
      await file.writeAsString(
        'const fromFile = { ok: true };\nJSON.stringify(fromFile);\n',
      );
      addTearDown(() => file.delete());

      final result = await js.runJavaScriptFromFileReturningResult(file.path);
      expect(result, '{"ok":true}');
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

    test('running after dispose throws', () async {
      final disposable = await JavaScript.createNew();
      await disposable.dispose();
      await expectLater(
        disposable.runJavaScriptReturningResult('"x"'),
        throwsA(isA<JavaScriptPlatformException>()),
      );
    });
  });

  group('channels', () {
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

    test('a plain string message arrives verbatim', () async {
      String? received;
      await js.addJavaScriptChannel(
        JavaScriptChannelParams(
          name: 'Echo',
          onMessageReceived: (message) {
            received = message.message;
            return JavaScriptReply(message: 'echo: ${message.message}');
          },
        ),
      );

      final result = await run("sendMessage('Echo', 'hello world')");

      expect(received, 'hello world');
      expect(result, 'echo: hello world');
    });

    test('a non-string message throws in JavaScript', () async {
      await js.addJavaScriptChannel(
        JavaScriptChannelParams(
          name: 'Strict',
          onMessageReceived: (_) => JavaScriptReply(message: 'unreachable'),
        ),
      );
      await expectLater(
        run("sendMessage('Strict', {a: 1})"),
        throwsA(isA<JavaScriptExecutionException>()),
      );
      await expectLater(
        run("sendMessage('Strict', 42)"),
        throwsA(isA<JavaScriptExecutionException>()),
      );
    });

    test('a null reply resolves the promise with null', () async {
      await js.addJavaScriptChannel(
        JavaScriptChannelParams(
          name: 'Nothing',
          onMessageReceived: (_) => const JavaScriptReply(message: null),
        ),
      );
      expect(
        await run(
          "sendMessage('Nothing', 'x').then(v => v === null ? 'was null' : 'was ' + typeof v)",
        ),
        'was null',
      );
    });

    test('the reply string is delivered verbatim', () async {
      await js.addJavaScriptChannel(
        JavaScriptChannelParams(
          name: 'Reply',
          onMessageReceived: (_) => JavaScriptReply(message: '  "spaced" \n'),
        ),
      );
      expect(await run("sendMessage('Reply', 'x')"), '  "spaced" \n');
    });

    test('an async channel handler is awaited', () async {
      await js.addJavaScriptChannel(
        JavaScriptChannelParams(
          name: 'Slow',
          onMessageReceived: (message) async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return JavaScriptReply(message: 'slow ${message.message}');
          },
        ),
      );
      expect(await run("sendMessage('Slow', 'reply')"), 'slow reply');
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

    test('a channel can be removed', () async {
      await js.addJavaScriptChannel(
        JavaScriptChannelParams(
          name: 'Temp',
          onMessageReceived: (_) => JavaScriptReply(message: 'temp'),
        ),
      );
      expect(await run("sendMessage('Temp', 'x')"), 'temp');
      await js.removeJavaScriptChannel('Temp');
      await expectLater(
        run("sendMessage('Temp', 'x')"),
        throwsA(isA<JavaScriptExecutionException>()),
      );
    });
  });
}

extension on JavaScript {
  Future<Object?> run(String source) => runJavaScriptReturningResult(source);
}
