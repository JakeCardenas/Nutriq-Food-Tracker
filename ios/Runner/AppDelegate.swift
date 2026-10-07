import CoreML
import Flutter
import ImageIO
import UIKit
import Vision

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FoodVisionPlugin") {
      FoodVisionPlugin.register(with: registrar)
    }
  }
}

/// On-device food recognition with Apple's built-in image classifier (Vision).
/// The photo is analysed on the iPhone and never leaves it.
final class FoodVisionPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.prodbyjake.nutriq/food_vision", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(FoodVisionPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "classify",
      let args = call.arguments as? [String: Any],
      let image = args["image"] as? FlutterStandardTypedData
    else {
      result(FlutterMethodNotImplemented)
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let labels = try FoodVisionPlugin.classify(image.data)
        DispatchQueue.main.async { result(labels) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "vision_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  /// Labels with their confidence (0–1), most confident first.
  static func classify(_ data: Data) throws -> [[String: Any]] {
    let request = VNClassifyImageRequest()
    #if targetEnvironment(simulator)
      // The Simulator has no Neural Engine/GPU path for Vision's model; run it on the CPU.
      if #available(iOS 17.0, *) {
        let cpu = MLComputeDevice.allComputeDevices.first { device in
          if case .cpu = device { return true }
          return false
        }
        if let cpu { request.setComputeDevice(cpu, for: .main) }
      } else {
        request.usesCPUOnly = true
      }
    #endif
    let handler = VNImageRequestHandler(data: data, orientation: orientation(of: data), options: [:])
    try handler.perform([request])
    return (request.results ?? [])
      .filter { $0.confidence >= 0.05 }
      .prefix(40)
      .map { ["label": $0.identifier, "confidence": Double($0.confidence)] }
  }

  /// Camera photos are often stored sideways with an orientation flag.
  private static func orientation(of data: Data) -> CGImagePropertyOrientation {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let raw = properties[kCGImagePropertyOrientation] as? UInt32,
      let orientation = CGImagePropertyOrientation(rawValue: raw)
    else { return .up }
    return orientation
  }
}
