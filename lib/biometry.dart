import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How the device confirms an App Store purchase.
enum DemoBiometry { faceId, touchId }

/// The verification hardware the App Store checkout should show, from
/// `LocalAuthentication` on iOS. Everywhere else it is a Face ID iPhone.
@immutable
class DemoDevice {
  const DemoDevice({
    required this.biometry,
    this.isTablet = false,
    this.homeButton = false,
    this.sensorReady = false,
  });

  /// iPhone X and later: double-click the side button, then Face ID.
  static const faceIdPhone = DemoDevice(biometry: DemoBiometry.faceId);

  final DemoBiometry biometry;
  final bool isTablet;

  /// Touch ID sits in a Home button; otherwise it is in the top button.
  final bool homeButton;

  /// A finger is enrolled, so the real sensor confirms the purchase instead
  /// of the on-screen stand-in.
  final bool sensorReady;

  bool get touchId => biometry == DemoBiometry.touchId;

  /// Where to put the finger, e.g. "Rest your finger on the top button".
  String get sensorHint =>
      homeButton
          ? 'Rest your finger on the Home button'
          : isTablet
          ? 'Rest your finger on the top button'
          : 'Rest your finger on the side button';
}

enum DemoAuthResult { success, cancelled, failed, unavailable }

/// Reads the device's biometrics through the `acatrain/biometry` channel.
/// Only Touch ID is ever evaluated; the result stays on the device and
/// unlocks nothing but the simulated checkout.
abstract final class DemoBiometrics {
  static const _channel = MethodChannel('acatrain/biometry');

  /// Replaces detection in tests.
  @visibleForTesting
  static DemoDevice? debugDevice;

  static Future<DemoDevice> detect() async {
    if (debugDevice case final device?) return device;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return DemoDevice.faceIdPhone;
    }
    try {
      final caps = await _channel
          .invokeMapMethod<String, Object?>('capabilities')
          .timeout(const Duration(milliseconds: 600));
      if (caps == null || caps['biometry'] != 'touchID') {
        return DemoDevice.faceIdPhone;
      }
      return DemoDevice(
        biometry: DemoBiometry.touchId,
        isTablet: caps['pad'] == true,
        homeButton: caps['homeButton'] == true,
        sensorReady: caps['enrolled'] == true,
      );
    } on PlatformException {
      return DemoDevice.faceIdPhone;
    } on MissingPluginException {
      return DemoDevice.faceIdPhone;
    } on Exception {
      return DemoDevice.faceIdPhone;
    }
  }

  /// Asks for a Touch ID match, which shows the system's Touch ID prompt.
  static Future<DemoAuthResult> authenticate(String reason) async {
    try {
      final result = await _channel.invokeMethod<String>('authenticate', {
        'reason': reason,
      });
      return switch (result) {
        'success' => DemoAuthResult.success,
        'cancelled' => DemoAuthResult.cancelled,
        _ => DemoAuthResult.failed,
      };
    } on PlatformException {
      return DemoAuthResult.unavailable;
    } on MissingPluginException {
      return DemoAuthResult.unavailable;
    }
  }
}
