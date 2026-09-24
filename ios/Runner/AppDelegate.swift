import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AcatrainPlanIcon")
    let channel = FlutterMethodChannel(
      name: "acatrain/icon", binaryMessenger: registrar!.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "setPlan",
            let arguments = call.arguments as? [String: String],
            let plan = arguments["plan"] else {
        result(FlutterMethodNotImplemented)
        return
      }
      let icons: [String: String] = [
        "starter": "StarterIcon", "pro": "ProIcon", "max": "MaxIcon"
      ]
      guard plan == "free" || icons[plan] != nil else {
        result(FlutterError(code: "INVALID_PLAN", message: "Unknown icon plan", details: nil))
        return
      }
      DispatchQueue.main.async {
        guard UIApplication.shared.supportsAlternateIcons else {
          result(nil)
          return
        }
        let icon = icons[plan]
        if UIApplication.shared.alternateIconName == icon {
          result(nil)
          return
        }
        UIApplication.shared.setAlternateIconName(icon) { error in
          if let error = error {
            result(FlutterError(code: "ICON_CHANGE_FAILED", message: error.localizedDescription, details: nil))
          } else {
            result(nil)
          }
        }
      }
    }
  }
}
