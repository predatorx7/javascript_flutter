import 'package:javascript_platform_interface/javascript_platform_interface.dart';

void main(List<String> arguments) async {
  final platform = JavaScriptPlatform.instance;

  final javaScriptInstanceId = 'example';

  try {
    await platform.startNewJavaScriptEnvironment(javaScriptInstanceId);

    await platform.setIsInspectable(javaScriptInstanceId, true);

    final result = await platform.runJavaScriptReturningResult(
      javaScriptInstanceId,
      '("Hello," + "World!");',
    );

    print(result);

    await platform.dispose(javaScriptInstanceId);
  } on JavaScriptPlatformException catch (e) {
    switch (e) {
      case JavaScriptExecutionException():
        print('JavaScript evaluation failed: ${e.message}');
      case JavaScriptInstanceNotFoundException():
        print('JavaScript evaluation failed: ${e.message}');
      case JavaScriptEnvironmentUninitializedException():
        print('JavaScript environment is uninitialized: ${e.message}');
      case JavaScriptEnvironmentDeadException():
        print('JavaScript environment is dead: ${e.message}');
      case JavaScriptEnvironmentClosedException():
        print('JavaScript environment is closed: ${e.message}');
    }
  } catch (e) {
    print('An unexpected error occurred: $e');
  }
}
