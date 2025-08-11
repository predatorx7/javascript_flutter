import 'package:flutter_test/flutter_test.dart';
import 'package:javascript_darwin/javascript_darwin.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JavascriptMacOS', () {
    test('can be registered', () {
      JavaScriptDarwin.registerWith();
      expect(JavaScriptPlatform.instance, isA<JavaScriptDarwin>());
    });
  });
}
