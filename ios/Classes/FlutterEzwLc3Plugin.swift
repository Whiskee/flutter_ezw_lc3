import Flutter
import UIKit

// Ensure LC3 symbols are linked
@_silgen_name("flutter_ezw_lc3_ensure_symbols_linked")
func ensureLc3SymbolsLinked()

public class FlutterEzwLc3Plugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    // Call the function to ensure LC3 symbols are linked
    ensureLc3SymbolsLinked()
    
    let channel = FlutterMethodChannel(name: "flutter_ezw_lc3", binaryMessenger: registrar.messenger())
    let instance = FlutterEzwLc3Plugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
