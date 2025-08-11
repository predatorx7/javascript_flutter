import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'javascript_android',
    input: 'pigeons/schema.dart',
    dartOut: 'lib/src/pigeons/messages.pigeon.dart',
    kotlinOptions: KotlinOptions(
      package: 'org.reclaimprotocol.javascript_android',
    ),
    kotlinOut:
        'android/src/main/java/org/reclaimprotocol/javascript_android/Messages.kt',
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)

/// Apis implemented by the Reclaim module for use by the host.
@HostApi()
abstract class JavaScriptAndroidPlatformApi {
  @async
  void startJavaScriptEngine(String javascriptEngineId);
  @async
  void dispose(String javascriptEngineId);
  @async
  Object? runJavaScriptReturningResult(
    String javascriptEngineId,
    String javaScript,
  );
  @async
  void setIsInspectable(String javascriptEngineId, bool isInspectable);
}
