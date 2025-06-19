import Flutter
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let iconChannel = FlutterMethodChannel(
      name: "com.iot.technion.smart_pomodoro/app_icon",
      binaryMessenger: controller.binaryMessenger)
    
    iconChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "setAlternateIcon" {
        if let args = call.arguments as? [String: Any],
           let iconName = args["iconName"] as? String? {
          UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
              result(FlutterError(code: "ICON_CHANGE_FAILED",
                                message: error.localizedDescription,
                                details: nil))
            } else {
              result(nil)
            }
          }
        } else {
          result(FlutterError(code: "INVALID_ARGUMENTS",
                            message: "Invalid arguments for icon change",
                            details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
