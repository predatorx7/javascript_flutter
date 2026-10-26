import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'javascript_android',
    input: 'pigeons/schema.dart',
    dartOut: 'lib/src/pigeons/messages.pigeon.dart',
    kotlinOptions: KotlinOptions(
      package: 'com.magnificsoftware.javascript_android',
    ),
    kotlinOut:
        'android/src/main/kotlin/com/magnificsoftware/javascript_android/Messages.kt',
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)
@ProxyApi()
abstract class JavaScriptAndroidConsoleMessageHandler {
  // ignore: avoid_unused_constructor_parameters
  JavaScriptAndroidConsoleMessageHandler();

  /// Handles callbacks messages from JavaScript.
  late void Function(String message) onMessage;
}

@HostApi()
abstract class JavaScriptAndroidPlatformApi {
  @asyncCallback
  void startJavaScriptEnvironment(String javascriptInstanceId);
  @asyncCallback
  void dispose(String javascriptInstanceId);
  @asyncCallback
  String? runJavaScriptReturningResult(
    String javascriptInstanceId,
    String javaScript,
  );
  @asyncCallback
  String? runJavaScriptFromFileReturningResult(
    String javascriptInstanceId,
    String javaScriptFilePath,
  );
  @asyncCallback
  void setIsInspectable(String javascriptInstanceId, bool isInspectable);
  @asyncCallback
  bool setJavaScriptConsoleMessageHandler(
    String javascriptInstanceId,
    int mJavaScriptAndroidConsoleMessageHandlerInstanceIdentifier,
  );
}
