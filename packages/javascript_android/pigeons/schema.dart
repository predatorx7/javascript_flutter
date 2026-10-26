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

@ProxyApi()
abstract class JavaScriptAndroidMessagePortHandler {
  // ignore: avoid_unused_constructor_parameters
  JavaScriptAndroidMessagePortHandler();

  /// Handles string messages posted by JavaScript over the message port.
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

  /// Opens a message port named `javascript_android_host` on the isolate and
  /// forwards the string messages JavaScript posts to [handler]. Returns false
  /// when message ports are unsupported by the device's WebView.
  @asyncCallback
  bool setJavaScriptMessagePortHandler(
    String javascriptInstanceId,
    int messagePortHandlerInstanceIdentifier,
  );

  /// Posts a string message to JavaScript over the message port.
  @asyncCallback
  void postMessageToJavaScript(String javascriptInstanceId, String message);
}
