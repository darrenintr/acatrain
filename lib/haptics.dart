import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The tuned haptic patterns from the haptics board
/// (`docs/design/expressive-haptics-ux.md` §2). Each one is paired with a
/// visible change and fires only for something the user did.
enum AcHaptic {
  tick,
  tap,
  flip,
  confirm,
  again,
  reject,
  celebrate,
  streak,
  toggleOn,
  toggleOff,
  done,
  error,
  threshold,
}

/// Plays [AcHaptic] patterns through the `acatrain/haptics` platform channel
/// (Core Haptics on iOS, vibration compositions on Android), falling back to
/// Flutter's coarse presets. Web, desktop and devices without a motor stay
/// silent: there is never a sound in place of a vibration.
abstract final class Haptics {
  static const _channel = MethodChannel('acatrain/haptics');

  /// Strength from Settings: 0 off, 1 subtle (×0.6), 2 standard.
  static int level = 2;

  /// Patterns closer together than this are dropped, so the device plays at
  /// most one pattern at a time. The native side cancels whatever is still
  /// playing when a new one starts.
  static const minGap = Duration(milliseconds: 80);

  static DateTime? _last;

  /// Every pattern requested while this is non-null is appended to it. Tests
  /// use it to check the feedback map; debug builds also print each one.
  @visibleForTesting
  static List<AcHaptic>? debugLog;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> play(AcHaptic haptic) async {
    if (level == 0) return;
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < minGap) return;
    _last = now;
    debugLog?.add(haptic);
    if (kDebugMode) debugPrint('haptic: ${haptic.name} (level $level)');
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('play', {
        'id': haptic.name,
        'scale': level == 1 ? 0.6 : 1.0,
      });
    } on PlatformException {
      await _fallback(haptic);
    } on MissingPluginException {
      await _fallback(haptic);
    }
  }

  /// Warms up the iOS engine and generators when a screen that uses them
  /// appears, so the first pattern is not late.
  static Future<void> prepare() async {
    if (level == 0 || !_supported) return;
    try {
      await _channel.invokeMethod<void>('prepare');
    } on PlatformException {
      // Nothing to prepare; play() still works.
    } on MissingPluginException {
      // Same as above.
    }
  }

  @visibleForTesting
  static void debugReset() {
    _last = null;
    level = 2;
  }

  static Future<void> _fallback(AcHaptic haptic) => switch (haptic) {
    AcHaptic.tick ||
    AcHaptic.toggleOn ||
    AcHaptic.toggleOff => HapticFeedback.selectionClick(),
    AcHaptic.reject || AcHaptic.error => HapticFeedback.heavyImpact(),
    AcHaptic.confirm ||
    AcHaptic.celebrate ||
    AcHaptic.streak => HapticFeedback.mediumImpact(),
    _ => HapticFeedback.lightImpact(),
  };
}
