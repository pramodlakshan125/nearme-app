import Flutter
import CoreBluetooth
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var peripheralManager: CBPeripheralManager?
  private var pendingServiceUuid: CBUUID?
  private var pendingAdvertisingResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NearMeBluetooth")
    let channel = FlutterMethodChannel(
      name: "nearme/ble_advertising",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "startAdvertising":
        guard let uuid = call.arguments as? [String: Any],
              let serviceUuid = uuid["serviceUuid"] as? String,
              CBUUID(string: serviceUuid).uuidString == serviceUuid.uppercased() else {
          result(FlutterError(
            code: "invalid_token",
            message: "A valid service UUID is required.",
            details: nil
          ))
          return
        }
        self?.startAdvertising(serviceUuid, result: result)
      case "stopAdvertising":
        self?.stopAdvertising()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
  }

  private func startAdvertising(_ serviceUuid: String, result: @escaping FlutterResult) {
    guard let peripheralManager else {
      result(FlutterError(
        code: "bluetooth_unavailable",
        message: "Bluetooth peripheral manager is unavailable.",
        details: nil
      ))
      return
    }
    guard peripheralManager.state == .poweredOn else {
      result(FlutterError(
        code: "bluetooth_unavailable",
        message: "Turn on Bluetooth to become discoverable.",
        details: nil
      ))
      return
    }

    peripheralManager.stopAdvertising()
    pendingServiceUuid = CBUUID(string: serviceUuid)
    pendingAdvertisingResult = result
    beginAdvertisingIfReady()
  }

  private func beginAdvertisingIfReady() {
    guard let peripheralManager,
          peripheralManager.state == .poweredOn,
          let serviceUuid = pendingServiceUuid else {
      return
    }
    peripheralManager.startAdvertising([
      CBAdvertisementDataServiceUUIDsKey: [serviceUuid]
    ])
  }

  private func stopAdvertising() {
    peripheralManager?.stopAdvertising()
    pendingServiceUuid = nil
    pendingAdvertisingResult?(FlutterError(
      code: "advertising_cancelled",
      message: "BLE advertising was stopped.",
      details: nil
    ))
    pendingAdvertisingResult = nil
  }
}

extension AppDelegate: CBPeripheralManagerDelegate {
  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    if peripheral.state == .poweredOn {
      beginAdvertisingIfReady()
    } else if let result = pendingAdvertisingResult {
      pendingServiceUuid = nil
      pendingAdvertisingResult = nil
      result(FlutterError(
        code: "bluetooth_unavailable",
        message: "Bluetooth is not available.",
        details: nil
      ))
    }
  }

  func peripheralManagerDidStartAdvertising(
    _ peripheral: CBPeripheralManager,
    error: Error?
  ) {
    let result = pendingAdvertisingResult
    pendingServiceUuid = nil
    pendingAdvertisingResult = nil
    if let error {
      result?(FlutterError(
        code: "advertising_failed",
        message: error.localizedDescription,
        details: nil
      ))
    } else {
      result?(nil)
    }
  }
}
