import CoreHaptics
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

  private let haptics = AcatrainHaptics()

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let hapticsRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "AcatrainHaptics")
    FlutterMethodChannel(name: "acatrain/haptics", binaryMessenger: hapticsRegistrar!.messenger())
      .setMethodCallHandler(haptics.handle)
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

/// Plays the tuned patterns from docs/design/expressive-haptics-ux.md §2.
/// Rich patterns use one prepared Core Haptics engine; single taps use
/// UIFeedbackGenerator. Both follow the system haptics switch on their own.
final class AcatrainHaptics {
  private var engine: CHHapticEngine?
  private var player: CHHapticPatternPlayer?
  private let selection = UISelectionFeedbackGenerator()
  private let notification = UINotificationFeedbackGenerator()
  private let light = UIImpactFeedbackGenerator(style: .light)
  private let soft = UIImpactFeedbackGenerator(style: .soft)
  private let rigid = UIImpactFeedbackGenerator(style: .rigid)

  private var supportsHaptics: Bool {
    CHHapticEngine.capabilitiesForHardware().supportsHaptics
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "prepare":
      prepare()
      result(nil)
    case "play":
      guard let arguments = call.arguments as? [String: Any],
            let id = arguments["id"] as? String else {
        result(FlutterError(code: "INVALID_HAPTIC", message: "Missing haptic id", details: nil))
        return
      }
      let scale = Float(min(max((arguments["scale"] as? Double) ?? 1, 0), 1))
      play(id, scale: scale)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func prepare() {
    selection.prepare()
    light.prepare()
    soft.prepare()
    _ = startEngine()
  }

  private func startEngine() -> CHHapticEngine? {
    guard supportsHaptics else { return nil }
    if let engine = engine { return engine }
    do {
      let created = try CHHapticEngine()
      created.isAutoShutdownEnabled = true
      created.playsHapticsOnly = true
      created.resetHandler = { [weak self] in
        self?.player = nil
        try? self?.engine?.start()
      }
      created.stoppedHandler = { [weak self] _ in self?.player = nil }
      try created.start()
      engine = created
      return created
    } catch {
      return nil
    }
  }

  private func play(_ id: String, scale: Float) {
    // A new pattern cancels the one still playing.
    try? player?.stop(atTime: CHHapticTimeImmediate)
    player = nil
    switch id {
    case "tick": selection.selectionChanged()
    case "tap": light.impactOccurred(intensity: CGFloat(0.7 * scale))
    case "again": soft.impactOccurred(intensity: CGFloat(0.6 * scale))
    case "toggleOn": light.impactOccurred(intensity: CGFloat(0.5 * scale))
    case "toggleOff": soft.impactOccurred(intensity: CGFloat(0.35 * scale))
    case "done": soft.impactOccurred(intensity: CGFloat(0.5 * scale))
    case "error": notification.notificationOccurred(.warning)
    case "threshold": rigid.impactOccurred(intensity: CGFloat(0.6 * scale))
    default:
      guard let events = pattern(id, scale: scale), playPattern(events) else {
        fallback(id, scale: scale)
        return
      }
    }
  }

  private func playPattern(_ pattern: (events: [CHHapticEvent], curves: [CHHapticParameterCurve])) -> Bool {
    guard let engine = startEngine() else { return false }
    do {
      let built = try CHHapticPattern(events: pattern.events, parameterCurves: pattern.curves)
      let next = try engine.makePlayer(with: built)
      try next.start(atTime: CHHapticTimeImmediate)
      player = next
      return true
    } catch {
      return false
    }
  }

  private func fallback(_ id: String, scale: Float) {
    switch id {
    case "confirm", "celebrate": notification.notificationOccurred(.success)
    case "reject": notification.notificationOccurred(.error)
    case "streak": rigid.impactOccurred(intensity: CGFloat(0.6 * scale))
    default: light.impactOccurred(intensity: CGFloat(0.7 * scale))
    }
  }

  private func transient(_ at: Double, _ intensity: Float, _ sharpness: Float, _ scale: Float) -> CHHapticEvent {
    CHHapticEvent(
      eventType: .hapticTransient,
      parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * scale),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
      ],
      relativeTime: at)
  }

  /// A continuous swell from [from] to [to] intensity over [duration] s.
  private func swell(_ duration: Double, from: Float, to: Float, sharpness: Float, scale: Float)
    -> (CHHapticEvent, CHHapticParameterCurve)
  {
    let event = CHHapticEvent(
      eventType: .hapticContinuous,
      parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
      ],
      relativeTime: 0, duration: duration)
    let curve = CHHapticParameterCurve(
      parameterID: .hapticIntensityControl,
      controlPoints: [
        .init(relativeTime: 0, value: from * scale),
        .init(relativeTime: duration, value: to * scale),
      ],
      relativeTime: 0)
    return (event, curve)
  }

  private func pattern(_ id: String, scale: Float)
    -> (events: [CHHapticEvent], curves: [CHHapticParameterCurve])?
  {
    switch id {
    case "flip":
      let (rise, curve) = swell(0.18, from: 0.1, to: 0.3, sharpness: 0.2, scale: scale)
      return ([rise, transient(0.22, 0.5, 0.5, scale)], [curve])
    case "confirm":
      return ([transient(0, 0.8, 0.6, scale), transient(0.07, 0.5, 0.4, scale)], [])
    case "reject":
      return ([
        transient(0, 0.7, 0.2, scale), transient(0.059, 0.5, 0.5, scale),
        transient(0.126, 0.35, 0.5, scale), transient(0.193, 0.2, 0.5, scale),
      ], [])
    case "celebrate":
      let (rise, curve) = swell(0.3, from: 0.2, to: 0.6, sharpness: 0.2, scale: scale)
      return ([
        rise, transient(0.3, 1.0, 0.7, scale), transient(0.38, 0.4, 0.9, scale),
        transient(0.46, 0.3, 0.9, scale), transient(0.54, 0.2, 0.9, scale),
      ], [curve])
    case "streak":
      let (rise, curve) = swell(0.09, from: 0.1, to: 0.3, sharpness: 0.2, scale: scale)
      return ([rise, transient(0.09, 0.6, 0.8, scale)], [curve])
    default:
      return nil
    }
  }
}
