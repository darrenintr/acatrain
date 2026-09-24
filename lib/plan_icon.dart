import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the home screen icon in step with the locally saved demo plan.
class PlanIcon {
  static const _channel = MethodChannel('acatrain/icon');

  static Future<void> apply(String plan) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod<void>('setPlan', {'plan': plan});
    } on PlatformException {
      // Icon changes are cosmetic; a launcher can reject an update.
    } on MissingPluginException {
      // Desktop and test hosts do not implement the channel.
    }
  }
}
