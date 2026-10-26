import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:javascript_darwin/exception.dart';
import 'package:javascript_darwin/javascript_darwin.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

// Runs real JavaScriptCore on the macOS host. Mirrors the shared device test in
// packages/javascript/example/integration_test/javascript_test.dart.
void main() {
  final skip = !Platform.isMacOS;
  late JavaScriptDarwin js;
  var counter = 0;
  late String id;

  setUp(() async {
    js = JavaScriptDarwin();
    id = 'env-${counter++}';
    await js.startNewJavaScriptEnvironment(id);
  });

  tearDown(() async {
    try {
      await js.dispose(id);
    } on JavaScriptInstanceNotFoundException {
      // Already disposed by the test.
    }
  });

  Future<Object?> run(String source) =>
      js.runJavaScriptReturningResult(id, source);

  Matcher throwsJsError(String text) => throwsA(
        isA<JavaScriptDarwinExecutionException>().having(
          (e) => e.toString(),
          'message',
          contains(text),
        ),
      );

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
      '"ERROR: not an error"': 'ERROR: not an error',
      '"\\u0000nul"': '\u0000nul',
    };
    cases.forEach((source, expected) {
      test(source.length > 60 ? source.substring(0, 60) : source, () async {
        final result = await run(source);
        expect(result, isA<String>());
        expect(result, expected);
      });
    });
  }, skip: skip);

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
      'var x = 1;',
      'if (true) { 1 }',
      '',
      '// only a comment',
      '({ toString() { throw new Error("no"); } })',
    ];
    for (final source in cases) {
      test(source.isEmpty ? '<empty script>' : source, () async {
        final result = await run(source);
        expect(result, isA<String>());
        expect(result, '');
      });
    }

    // Previously: FormatException out of convertValue.
    test('NaN, Infinity, 1e21 and 2 ** 63 no longer throw FormatException',
        () async {
      for (final s in ['NaN', 'Infinity', '-Infinity', '1e21', '2 ** 63']) {
        expect(await run(s), '', reason: s);
      }
    });

    // Previously: silently Dart null.
    test('undefined, functions, symbols, bigint and cycles are not null',
        () async {
      for (final s in [
        'undefined',
        '(function() {})',
        'Symbol("x")',
        '1n',
        'var c = {}; c.self = c; c',
      ]) {
        expect(await run(s), isNotNull, reason: s);
        expect(await run(s), '', reason: s);
      }
    });
  }, skip: skip);

  group('promises', () {
    test('resolving to a string yields that string, not JSON', () async {
      // Previously double encoded as '"hi"'.
      expect(await run('Promise.resolve("hi")'), 'hi');
      expect(await run('Promise.resolve("")'), '');
      expect(await run('Promise.resolve(JSON.stringify({a: 1}))'), '{"a":1}');
      expect(await run('Promise.resolve("  \\"x\\" \\n")'), '  "x" \n');
    });

    test('resolving to a non-string yields an empty string', () async {
      // Previously '42' etc.
      for (final v in ['42', '{a: 1}', 'null', 'undefined', 'false', '[]']) {
        expect(await run('Promise.resolve($v)'), '', reason: v);
      }
    });

    test('bare thenables are not awaited, adopted ones are', () async {
      expect(await run('({ then(resolve) { resolve("x"); } })'), '');
      expect(
        await run('Promise.resolve({ then(resolve) { resolve("adopted"); } })'),
        'adopted',
      );
      await expectLater(
        run(
          'Promise.resolve({ then(_, reject) { reject(new Error("thenable boom")); } })',
        ),
        throwsJsError('thenable boom'),
      );
    });

    test('later, async and chained promises are awaited', () async {
      expect(
        await run(
            'new Promise(resolve => setTimeout(() => resolve("late"), 50))'),
        'late',
      );
      expect(
        await run('(async () => { await null; return "async"; })()'),
        'async',
      );
      expect(
        await run('''
          const sum = async (a, b) => a + b;
          sum(1, 2).then(v => String(v));
        '''),
        '3',
      );
    });

    test('rejection reasons are surfaced', () async {
      await expectLater(
          run('Promise.reject(new Error("boom"))'), throwsJsError('boom'));
      await expectLater(
        run('(async () => { throw new Error("async boom"); })()'),
        throwsJsError('async boom'),
      );
      await expectLater(
          run('Promise.reject("plain reason")'), throwsJsError('plain reason'));
      await expectLater(run('Promise.reject(42)'), throwsJsError('42'));
      await expectLater(run('Promise.reject({message: "obj msg"})'),
          throwsJsError('obj msg'));
      await expectLater(
          run('Promise.reject(undefined)'), throwsJsError('undefined'));
      await expectLater(
          run('Promise.reject(Symbol("sym"))'), throwsJsError('sym'));
      await expectLater(
        run('Promise.reject(Object.create(null))'),
        throwsA(isA<JavaScriptDarwinExecutionException>()),
      );
    });

    test('environment keeps working after a rejection', () async {
      await expectLater(run('Promise.reject("x")'), throwsA(anything));
      expect(await run('Promise.resolve("ok")'), 'ok');
    });
  }, skip: skip);

  group('errors', () {
    test('thrown values surface as JavaScriptDarwinExecutionException',
        () async {
      await expectLater(
          run('throw new Error("bad thing")'), throwsJsError('bad thing'));
      await expectLater(run('definitelyNotDefined + 1'),
          throwsJsError('definitelyNotDefined'));
      await expectLater(
          run('throw "plain string"'), throwsJsError('plain string'));
      await expectLater(run('this is not javascript'),
          throwsA(isA<JavaScriptDarwinExecutionException>()));
    });

    test('implements JavaScriptExecutionException', () async {
      await expectLater(run('throw new Error("x")'),
          throwsA(isA<JavaScriptExecutionException>()));
    });

    test('the environment keeps working after an error', () async {
      await expectLater(run('throw new Error("x")'), throwsA(anything));
      expect(await run('"still alive"'), 'still alive');
    });
  }, skip: skip);

  group('environment', () {
    test('state persists, including let and const', () async {
      await run('var counter = 1;');
      await run('counter += 1;');
      expect(await run('String(counter)'), '2');
      await run('let letValue = "let"; const constValue = "const";');
      expect(await run('letValue + " " + constValue'), 'let const');
    });

    test('instances are isolated', () async {
      final other = 'other-$id';
      await js.startNewJavaScriptEnvironment(other);
      addTearDown(() => js.dispose(other));
      await run('var onlyHere = "mine";');
      expect(await js.runJavaScriptReturningResult(other, 'typeof onlyHere'),
          'undefined');
    });

    test('runJavaScriptFromFileReturningResult evaluates a file', () async {
      final dir = Directory.systemTemp.createTempSync('jsdarwin');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/a.js')
        ..writeAsStringSync('const f = {ok: true};\nJSON.stringify(f);\n');
      expect(await js.runJavaScriptFromFileReturningResult(id, file.path),
          '{"ok":true}');
    });

    test('setTimeout works', () async {
      expect(
        await run('''
          new Promise(resolve => {
            const order = [];
            setTimeout(() => { order.push("b"); resolve(order.join(",")); }, 30);
            setTimeout(() => order.push("a"), 10);
          })
        '''),
        'a,b',
      );
    });

    test('running after dispose throws', () async {
      await js.dispose(id);
      await expectLater(
          run('"x"'), throwsA(isA<JavaScriptInstanceNotFoundException>()));
    });

    test('disposing while a promise is pending completes with an error',
        () async {
      final pending = run('new Promise(() => {})');
      final assertion = expectLater(
          pending, throwsA(isA<JavaScriptEnvironmentClosedException>()));
      await js.dispose(id);
      await assertion;
    });
  }, skip: skip);

  group('channels', () {
    test('a JSON message round-trips with a JSON reply', () async {
      String? received;
      await js.addJavaScriptChannel(
        id,
        JavaScriptChannelParams(
          name: 'Sum',
          onMessageReceived: (message) {
            received = message.message;
            return JavaScriptReply(message: '{"sum":42}');
          },
        ),
      );
      final result = await run('''
        sendMessage('Sum', JSON.stringify({a: 40, b: 2}))
          .then(reply => String(JSON.parse(reply).sum));
      ''');
      expect(received, '{"a":40,"b":2}');
      expect(result, '42');
    });

    test('plain, empty and awkward string messages arrive verbatim', () async {
      final received = <String?>[];
      await js.addJavaScriptChannel(
        id,
        JavaScriptChannelParams(
          name: 'Echo',
          onMessageReceived: (message) {
            received.add(message.message);
            return JavaScriptReply(message: 'echo: ${message.message}');
          },
        ),
      );
      expect(
          await run("sendMessage('Echo', 'hello world')"), 'echo: hello world');
      expect(await run("sendMessage('Echo', '')"), 'echo: ');
      expect(await run("sendMessage('Echo', '  \"q\" \\n\\u00e9 🌍 ')"),
          'echo:   "q" \né 🌍 ');
      expect(await run("sendMessage('Echo', '42')"), 'echo: 42');
      expect(received, ['hello world', '', '  "q" \né 🌍 ', '42']);
    });

    test('the reply string is delivered verbatim', () async {
      await js.addJavaScriptChannel(
        id,
        JavaScriptChannelParams(
          name: 'Reply',
          onMessageReceived: (_) => JavaScriptReply(message: '  "spaced" \n'),
        ),
      );
      expect(await run("sendMessage('Reply', 'x')"), '  "spaced" \n');
    });

    test('async handlers and many concurrent messages', () async {
      await js.addJavaScriptChannel(
        id,
        JavaScriptChannelParams(
          name: 'Slow',
          onMessageReceived: (message) async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return JavaScriptReply(message: 'slow ${message.message}');
          },
        ),
      );
      expect(await run("sendMessage('Slow', 'reply')"), 'slow reply');
      await js.addJavaScriptChannel(
        id,
        JavaScriptChannelParams(
          name: 'Double',
          onMessageReceived: (message) async =>
              JavaScriptReply(message: '${int.parse(message.message!) * 2}'),
        ),
      );
      final result = await run('''
        Promise.all(Array.from({length: 50}, (_, i) => sendMessage('Double', String(i))))
          .then(replies => replies.join(','));
      ''');
      expect(result, List.generate(50, (i) => i * 2).join(','));
    });

    test('unregistered and removed channels throw', () async {
      await expectLater(run("sendMessage('Nope', 'x')"), throwsJsError('Nope'));
      await js.addJavaScriptChannel(
        id,
        JavaScriptChannelParams(
          name: 'Temp',
          onMessageReceived: (_) => JavaScriptReply(message: 'temp'),
        ),
      );
      expect(await run("sendMessage('Temp', 'x')"), 'temp');
      await js.removeJavaScriptChannel(id, 'Temp');
      await expectLater(run("sendMessage('Temp', 'x')"), throwsJsError('Temp'));
    });

    test('non-string messages throw synchronously in JS', () async {
      await js.addJavaScriptChannel(
        id,
        JavaScriptChannelParams(
          name: 'Strict',
          onMessageReceived: (_) => JavaScriptReply(message: 'never'),
        ),
      );
      await expectLater(
        run("sendMessage('Strict', {a: 1})"),
        throwsJsError('Message must be a string'),
      );
      await expectLater(
        run("sendMessage('Strict', 42)"),
        throwsJsError('Message must be a string'),
      );
      expect(await run("sendMessage('Strict', 'ok')"), 'never');
    });

    test('a null reply resolves the JS promise with null', () async {
      await js.addJavaScriptChannel(
        id,
        JavaScriptChannelParams(
          name: 'Nothing',
          onMessageReceived: (_) => JavaScriptReply(message: null),
        ),
      );
      expect(
        await run(
          "sendMessage('Nothing','x').then(v => v === null ? 'was null' : 'was ' + typeof v)",
        ),
        'was null',
      );
    });

    test('console.log keeps working', () async {
      expect(await run('console.log("hi"); "after"'), 'after');
    });
  }, skip: skip);
}
