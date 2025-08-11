import 'package:flutter_test/flutter_test.dart';
import 'package:javascript_android/javascript_android.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JavascriptAndroid', () {
    test('can be registered', () {
      JavaScriptAndroid.registerWith();
      expect(JavaScriptPlatform.instance, isA<JavaScriptAndroid>());
    });
  });
}
