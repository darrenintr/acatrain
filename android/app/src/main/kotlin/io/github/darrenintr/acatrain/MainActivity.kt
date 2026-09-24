package io.github.darrenintr.acatrain

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "acatrain/icon")
            .setMethodCallHandler { call, result ->
                if (call.method != "setPlan") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val plan = call.argument<String>("plan")
                val aliases = mapOf(
                    "free" to "IconFree", "starter" to "IconStarter",
                    "pro" to "IconPro", "max" to "IconMax"
                )
                if (plan !in aliases) {
                    result.error("INVALID_PLAN", "Unknown icon plan", null)
                    return@setMethodCallHandler
                }
                try {
                    val manager = packageManager
                    // Enable the chosen alias first so the app always has a launcher entry.
                    for ((id, name) in aliases) {
                        if (id == plan) manager.setComponentEnabledSetting(
                            ComponentName(this, "${packageName}.$name"),
                            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                            PackageManager.DONT_KILL_APP
                        )
                    }
                    for ((id, name) in aliases) {
                        if (id != plan) manager.setComponentEnabledSetting(
                            ComponentName(this, "${packageName}.$name"),
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP
                        )
                    }
                    result.success(null)
                } catch (error: Exception) {
                    result.error("ICON_CHANGE_FAILED", error.message, null)
                }
            }
    }
}
