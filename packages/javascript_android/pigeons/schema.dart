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
@HostApi()
abstract class JavaScriptAndroidPlatformApi {
  @async
  void startJavaScriptEngine(String javascriptEngineId);
  @async
  void dispose(String javascriptEngineId);
  @async
  String? runJavaScriptReturningResult(
    String javascriptEngineId,
    String javaScript,
  );
  @async
  String? runJavaScriptFromFileReturningResult(
    String javascriptEngineId,
    String javaScriptFilePath,
  );
  @async
  void setIsInspectable(String javascriptEngineId, bool isInspectable);
}
