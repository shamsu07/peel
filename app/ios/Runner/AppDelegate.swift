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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WhatsAppBridge") {
      WhatsAppBridge.register(with: registrar)
    }
  }
}

/// Hands a sticker pack to WhatsApp, as in WhatsApp's official sample
/// (WhatsApp/stickers, Interoperability.swift): the pack JSON goes on the
/// pasteboard under WhatsApp's type, then we open whatsapp://stickerPack.
/// WhatsApp shows its own preview and never reports back.
final class WhatsAppBridge: NSObject, FlutterPlugin {
  private static let pasteboardType = "net.whatsapp.third-party.sticker-pack"
  private static let expirySeconds: TimeInterval = 60

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "peel/whatsapp", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(WhatsAppBridge(), channel: channel)
  }

  private var isInstalled: Bool {
    guard let url = URL(string: "whatsapp://") else { return false }
    return UIApplication.shared.canOpenURL(url)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      // iOS can't tell whether a pack is already in WhatsApp, and Business
      // isn't a sticker target here.
      result(["consumerInstalled": isInstalled, "businessInstalled": false])

    case "sendPack":
      guard let args = call.arguments as? [String: Any],
        let payload = args["payload"] as? FlutterStandardTypedData
      else {
        result(FlutterError(code: "args", message: "Missing payload", details: nil))
        return
      }
      guard isInstalled, let url = URL(string: "whatsapp://stickerPack") else {
        result(["outcome": "notInstalled"])
        return
      }
      UIPasteboard.general.setItems(
        [[Self.pasteboardType: payload.data]],
        options: [
          .localOnly: true,
          .expirationDate: Date(timeIntervalSinceNow: Self.expirySeconds),
        ])
      UIApplication.shared.open(url) { opened in
        result(["outcome": opened ? "sentToWhatsApp" : "notInstalled"])
      }

    case "openWhatsApp":
      guard isInstalled, let url = URL(string: "whatsapp://") else {
        result(false)
        return
      }
      UIApplication.shared.open(url) { opened in result(opened) }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
