import Flutter
import UIKit
import Security

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var securityChannel: FlutterMethodChannel?
  private let vaultQueue = DispatchQueue(label: "com.mimigo.refresh-vault")
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MimiGoSecurity") else { return }
    let channel = FlutterMethodChannel(name: "mimigo/security", binaryMessenger: registrar.messenger())
    securityChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "secureScreen" { result(nil); return } // Android FLAG_SECURE has no iOS equivalent here.
      if call.method == "screenProtected" { result(false); return }
      guard ["readRefresh", "writeRefresh", "clearRefresh"].contains(call.method), let self = self else { result(FlutterMethodNotImplemented); return }
      self.vaultQueue.async {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
          kSecAttrService as String: "com.mimigo.refresh.v1", kSecAttrAccount as String: "refresh",
          kSecAttrSynchronizable as String: false]
        var status: OSStatus = errSecSuccess
        var value: String?
        if call.method == "readRefresh" {
          query[kSecReturnData as String] = true
          query[kSecMatchLimit as String] = kSecMatchLimitOne
          var data: CFTypeRef?
          status = SecItemCopyMatching(query as CFDictionary, &data)
          if status == errSecSuccess, let bytes = data as? Data { value = String(data: bytes, encoding: .utf8) }
        } else if call.method == "clearRefresh" {
          status = SecItemDelete(query as CFDictionary)
        } else if let text = call.arguments as? String, let bytes = text.data(using: .utf8) {
          status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: bytes] as CFDictionary)
          if status == errSecItemNotFound {
            query[kSecValueData as String] = bytes
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(query as CFDictionary, nil)
          }
        } else { status = errSecParam }
        let succeeded = status == errSecSuccess || (status == errSecItemNotFound && call.method != "writeRefresh")
        DispatchQueue.main.async {
          if succeeded { result(value) }
          else { result(FlutterError(code: "SECURE_STORAGE_UNAVAILABLE", message: "Secure session storage unavailable.", details: nil)) }
        }
      }
    }
  }
}
