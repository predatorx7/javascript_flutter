import 'package:flutter_test/flutter_test.dart';
import 'package:javascript_platform_interface/javascript_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockJavascriptPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements JavaScriptPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Javascript', () {
    late JavaScriptPlatform javascriptPlatform;

    setUp(() {
      javascriptPlatform = MockJavascriptPlatform();
      JavaScriptPlatform.instance = javascriptPlatform;
    });
  });
}
