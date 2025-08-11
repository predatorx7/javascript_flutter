import Foundation

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#endif

public class JavaScriptPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    // let channel = FlutterMethodChannel(
    //   name: "javascript_darwin",
    //   binaryMessenger: registrar.messenger)
    // let instance = JavaScriptPlugin()
    // registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // switch call.method {
    // case "getPlatformName":
    //   result("MacOS")    
    // default:
    //   result(FlutterMethodNotImplemented)
    // }
  }
}
