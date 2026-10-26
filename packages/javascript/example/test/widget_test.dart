import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:javascript_example/main.dart';
import 'package:javascript_example/src/model.dart';
import 'package:javascript_flutter/javascript_flutter.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A platform that never touches a real JavaScript engine.
class FakeJavaScriptPlatform extends JavaScriptPlatform
    with MockPlatformInterfaceMixin {
  final List<String> scripts = [];

  @override
  Future<void> startNewJavaScriptEnvironment(
    String javaScriptInstanceId,
  ) async {}

  @override
  Future<void> setIsInspectable(
    String javaScriptInstanceId,
    bool isInspectable,
  ) async {}

  @override
  Future<Object?> runJavaScriptReturningResult(
    String javaScriptInstanceId,
    String javaScript,
  ) async {
    scripts.add(javaScript);
    return '';
  }

  @override
  Future<Object?> runJavaScriptFromFileReturningResult(
    String javaScriptInstanceId,
    String javaScriptFilePath,
  ) async => '';

  @override
  Future<void> addJavaScriptChannel(
    String javaScriptInstanceId,
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}

  @override
  Future<void> removeJavaScriptChannel(
    String javaScriptInstanceId,
    String javaScriptChannelName,
  ) async {}

  @override
  Future<void> dispose(String javaScriptInstanceId) async {}
}

void main() {
  group('formatResultForDisplay', () {
    test('shows strings verbatim', () {
      expect(formatResultForDisplay('42'), '42');
      expect(formatResultForDisplay('hello'), 'hello');
    });

    test('makes an empty string visible', () {
      expect(formatResultForDisplay(''), '""');
    });

    test('pretty-prints JSON objects and arrays', () {
      final out = formatResultForDisplay('{"a":1,"b":[2,3]}');
      expect(out, contains('\n'));
      expect(jsonDecode(out), {
        'a': 1,
        'b': [2, 3],
      });
      expect(formatResultForDisplay('[1,2]'), contains('\n'));
    });

    test('leaves invalid JSON alone', () {
      expect(formatResultForDisplay('{not json'), '{not json');
    });
  });

  testWidgets('console app shows the result contract hint', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final platform = FakeJavaScriptPlatform();
    JavaScriptPlatform.instance = platform;

    await tester.pumpWidget(const JsInterpreterApp());
    await tester.pumpAndSettle();

    expect(find.text('JS Interpreter Console'), findsOneWidget);
    expect(find.text(resultContractHelp), findsOneWidget);
    // The console log bridge was installed through the platform.
    expect(platform.scripts, isNotEmpty);
  });
}
