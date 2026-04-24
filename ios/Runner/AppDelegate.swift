import Flutter
import UIKit
import ActivityKit
import Intents

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private var channel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // ── Method Channel: Siri Shortcuts + Dynamic Island ──────────────────
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    channel = FlutterMethodChannel(
      name: "com.mycontacts/native",
      binaryMessenger: controller.binaryMessenger
    )
    channel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {

      // ── Siri Shortcuts ──────────────────────────────────────────────────
      case "registerSiriShortcut":
        guard let args = call.arguments as? [String: String],
              let name = args["name"],
              let phone = args["phone"] else {
          result(FlutterError(code: "ARGS", message: "Missing arguments", details: nil))
          return
        }
        self?.registerSiriShortcut(name: name, phone: phone)
        result(nil)

      case "donateSiriShortcut":
        guard let args = call.arguments as? [String: String],
              let name = args["name"],
              let phone = args["phone"] else {
          result(FlutterError(code: "ARGS", message: "Missing arguments", details: nil))
          return
        }
        self?.donateSiriShortcut(name: name, phone: phone)
        result(nil)

      // ── Dynamic Island (Live Activities) ────────────────────────────────
      case "startCallActivity":
        guard let args = call.arguments as? [String: String],
              let name = args["name"],
              let phone = args["phone"] else {
          result(FlutterError(code: "ARGS", message: "Missing arguments", details: nil))
          return
        }
        if #available(iOS 16.2, *) {
          Task {
            await self?.startCallActivity(name: name, phone: phone)
            result(nil)
          }
        } else {
          result(nil)
        }

      case "endCallActivity":
        if #available(iOS 16.2, *) {
          Task {
            await self?.endAllActivities()
            result(nil)
          }
        } else {
          result(nil)
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // ── Handle deep links (mycontacts://call/PHONE) ──────────────────────────
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.scheme == "mycontacts" {
      if url.host == "call", let phone = url.pathComponents.dropFirst().first {
        channel?.invokeMethod("onDeepLink", arguments: ["action": "call", "phone": phone])
        return true
      }
      if url.host == "open" {
        channel?.invokeMethod("onDeepLink", arguments: ["action": "open"])
        return true
      }
    }
    return super.application(app, open: url, options: options)
  }

  // MARK: - Siri Shortcuts

  private func registerSiriShortcut(name: String, phone: String) {
    let activity = NSUserActivity(activityType: "com.mycontacts.call")
    activity.title = "חייג ל\(name)"
    activity.userInfo = ["phone": phone, "name": name]
    activity.isEligibleForSearch = true
    activity.isEligibleForPrediction = true
    activity.persistentIdentifier = NSUserActivityPersistentIdentifier("call-\(phone)")
    activity.suggestedInvocationPhrase = "חייג ל\(name) דרך אנשי קשר"
    activity.becomeCurrent()
  }

  private func donateSiriShortcut(name: String, phone: String) {
    let activity = NSUserActivity(activityType: "com.mycontacts.call")
    activity.title = "חייג ל\(name)"
    activity.userInfo = ["phone": phone, "name": name]
    activity.isEligibleForSearch = true
    activity.isEligibleForPrediction = true
    activity.persistentIdentifier = NSUserActivityPersistentIdentifier("call-\(phone)")
    activity.becomeCurrent()
  }

  // MARK: - Dynamic Island (Live Activities)

  @available(iOS 16.2, *)
  private func startCallActivity(name: String, phone: String) async {
    // Requires a Live Activity target with CallActivityAttributes
    // Defined in ios/LiveActivities/CallActivity.swift
    // This is a placeholder — the actual implementation requires
    // an ActivityKit extension with proper attributes definition.
    // See ios/LiveActivities/SETUP.md for instructions.
  }

  @available(iOS 16.2, *)
  private func endAllActivities() async {
    // Activity.activities would be used here when the Live Activity target is set up
  }
}
