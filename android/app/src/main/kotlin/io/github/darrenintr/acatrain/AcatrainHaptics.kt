package io.github.darrenintr.acatrain

import android.content.Context
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.HapticFeedbackConstants
import android.view.View
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Plays the tuned patterns from docs/design/expressive-haptics-ux.md §2.
 *
 * API 30+ devices that support every primitive in a pattern get a
 * VibrationEffect composition, scaled by the user's strength. Everything else
 * uses View.performHapticFeedback, which respects the system setting itself.
 */
class AcatrainHaptics(
    private val context: Context,
    private val view: () -> View?,
) : MethodChannel.MethodCallHandler {

    /**
     * One primitive. [at] is its start in ms from the trigger (as the spec
     * lists it); without it the primitive follows the previous one after [gap].
     */
    private data class Primitive(val id: Int, val scale: Float, val at: Int? = null, val gap: Int = 0)

    private val vibrator: Vibrator? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepare" -> result.success(null)
            "play" -> {
                val id = call.argument<String>("id")
                val scale = (call.argument<Double>("scale") ?: 1.0).toFloat()
                if (id == null) {
                    result.error("INVALID_HAPTIC", "Missing haptic id", null)
                    return
                }
                try {
                    play(id, scale.coerceIn(0f, 1f))
                    result.success(null)
                } catch (error: Exception) {
                    result.error("HAPTIC_FAILED", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun play(id: String, scale: Float) {
        val vibrator = vibrator ?: return
        if (!vibrator.hasVibrator()) return
        val primitives = composition(id)
        if (primitives != null &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            vibrator.areAllPrimitivesSupported(*primitives.map { it.id }.toIntArray())
        ) {
            // Before API 33 the touch-feedback usage does not exist, so honour
            // the system switch by hand.
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU && !systemHapticsOn()) return
            val ids = primitives.map { it.id }.distinct().toIntArray()
            val durations = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                ids.zip(vibrator.getPrimitiveDurations(*ids).toList()).toMap()
            } else emptyMap()
            val composition = VibrationEffect.startComposition()
            // Composition delays count from the end of the previous primitive.
            var cursor = 0
            for (p in primitives) {
                val delay = if (p.at != null) maxOf(0, p.at - cursor) else p.gap
                composition.addPrimitive(p.id, p.scale * scale, delay)
                cursor += delay + (durations[p.id] ?: 0)
            }
            val effect = composition.compose()
            vibrator.cancel()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                vibrator.vibrate(
                    effect,
                    VibrationAttributes.createForUsage(VibrationAttributes.USAGE_TOUCH),
                )
            } else {
                vibrator.vibrate(effect)
            }
            return
        }
        view()?.performHapticFeedback(fallback(id))
    }

    private fun systemHapticsOn(): Boolean = try {
        Settings.System.getInt(context.contentResolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1) != 0
    } catch (_: Exception) {
        true
    }

    /** The composition for [id], or null when this API level lacks a primitive. */
    private fun composition(id: String): List<Primitive>? {
        val sdk = Build.VERSION.SDK_INT
        if (sdk < Build.VERSION_CODES.R) return null
        val api31 = sdk >= Build.VERSION_CODES.S
        return when (id) {
            "tick" -> listOf(Primitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.5f))
            "tap" -> listOf(Primitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.5f))
            "flip" -> listOf(
                Primitive(VibrationEffect.Composition.PRIMITIVE_QUICK_RISE, 0.25f),
                Primitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.5f, at = 220),
            )
            "confirm" -> listOf(
                Primitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.7f),
                Primitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.4f, at = 70),
            )
            "again" -> if (api31) {
                listOf(Primitive(VibrationEffect.Composition.PRIMITIVE_LOW_TICK, 0.8f))
            } else null
            // The ticks land on the shake's peaks.
            "reject" -> if (api31) listOf(
                Primitive(VibrationEffect.Composition.PRIMITIVE_THUD, 0.5f),
                Primitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.5f, at = 59),
                Primitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.35f, at = 126),
                Primitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.2f, at = 193),
            ) else null
            "celebrate" -> listOf(
                Primitive(VibrationEffect.Composition.PRIMITIVE_SLOW_RISE, 0.5f),
                Primitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 1.0f),
                Primitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.4f, gap = 80),
                Primitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.3f, gap = 80),
                Primitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.2f, gap = 80),
            )
            "streak" -> listOf(
                Primitive(VibrationEffect.Composition.PRIMITIVE_QUICK_RISE, 0.4f),
                Primitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.6f, at = 110),
            )
            "toggleOn" -> listOf(Primitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.6f))
            "toggleOff" -> if (api31) {
                listOf(Primitive(VibrationEffect.Composition.PRIMITIVE_LOW_TICK, 0.5f))
            } else null
            "done" -> listOf(
                Primitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.4f),
                Primitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.3f, at = 70),
            )
            "error" -> if (api31) listOf(
                Primitive(VibrationEffect.Composition.PRIMITIVE_THUD, 0.6f),
                Primitive(VibrationEffect.Composition.PRIMITIVE_THUD, 0.6f, at = 110),
            ) else null
            "threshold" -> listOf(Primitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.6f))
            else -> null
        }
    }

    private fun fallback(id: String): Int {
        val sdk = Build.VERSION.SDK_INT
        val api30 = sdk >= Build.VERSION_CODES.R
        val api34 = sdk >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE
        return when (id) {
            "tick" -> if (api34) HapticFeedbackConstants.SEGMENT_TICK else HapticFeedbackConstants.CLOCK_TICK
            "tap" -> HapticFeedbackConstants.VIRTUAL_KEY
            "flip" -> HapticFeedbackConstants.CLOCK_TICK
            "confirm", "celebrate", "streak", "done" ->
                if (api30) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.VIRTUAL_KEY
            "again" -> if (api30) HapticFeedbackConstants.GESTURE_END else HapticFeedbackConstants.CLOCK_TICK
            "reject", "error" ->
                if (api30) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.LONG_PRESS
            "toggleOn" -> if (api34) HapticFeedbackConstants.TOGGLE_ON else HapticFeedbackConstants.CLOCK_TICK
            "toggleOff" -> if (api34) HapticFeedbackConstants.TOGGLE_OFF else HapticFeedbackConstants.CLOCK_TICK
            "threshold" ->
                if (api34) HapticFeedbackConstants.GESTURE_THRESHOLD_ACTIVATE
                else HapticFeedbackConstants.CONTEXT_CLICK
            else -> HapticFeedbackConstants.VIRTUAL_KEY
        }
    }
}
