import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let integrityChannel = "com.daktarpi/device_integrity"
  private var privacyShieldView: UIVisualEffectView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: integrityChannel,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(false)
          return
        }
        switch call.method {
        case "isDeviceCompromised":
          result(self.isJailbroken())
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    showPrivacyShield()
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    hidePrivacyShield()
  }

  private func showPrivacyShield() {
    guard privacyShieldView == nil else { return }
    guard let appWindow = window else { return }

    let blur = UIBlurEffect(style: .systemMaterial)
    let shieldView = UIVisualEffectView(effect: blur)
    shieldView.frame = appWindow.bounds
    shieldView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    appWindow.addSubview(shieldView)
    privacyShieldView = shieldView
  }

  private func hidePrivacyShield() {
    privacyShieldView?.removeFromSuperview()
    privacyShieldView = nil
  }

  private func isJailbroken() -> Bool {
    #if targetEnvironment(simulator)
      return false
    #else
      let suspiciousPaths = [
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/private/var/lib/apt/"
      ]

      for path in suspiciousPaths where FileManager.default.fileExists(atPath: path) {
        return true
      }

      return canWriteOutsideSandbox()
    #endif
  }

  private func canWriteOutsideSandbox() -> Bool {
    let testPath = "/private/daktarpi_integrity_check.txt"
    do {
      try "integrity-check".write(
        toFile: testPath,
        atomically: true,
        encoding: .utf8
      )
      try FileManager.default.removeItem(atPath: testPath)
      return true
    } catch {
      return false
    }
  }
}
