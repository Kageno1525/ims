package com.kageno.ims

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "ims/autofill"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityEnabled())
                }
                "openAccessibilitySettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    } catch (_: Exception) {}
                    result.success(null)
                }
                "hasOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "openOverlaySettings" -> {
                    try {
                        val i = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(i)
                    } catch (_: Exception) {}
                    result.success(null)
                }
                "typeText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val ok = ImsAccessibilityService.typeTextStatic(text)
                    result.success(ok)
                }
                "startVolume" -> {
                    ImsAccessibilityService.volumeEnabled = true
                    result.success(null)
                }
                "stopVolume" -> {
                    ImsAccessibilityService.volumeEnabled = false
                    result.success(null)
                }
                "showFloating" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        result.success(false)
                    } else {
                        try {
                            val i = Intent(this, FloatingService::class.java).apply {
                                action = "SHOW"
                            }
                            startService(i)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }
                "hideFloating" -> {
                    try {
                        val i = Intent(this, FloatingService::class.java).apply {
                            action = "HIDE"
                        }
                        startService(i)
                    } catch (_: Exception) {}
                    result.success(null)
                }
                "updateFloatingText" -> {
                    val text = call.argument<String>("text") ?: ""
                    FloatingService.updateText(text)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ربط callbacks من الـ Services
        ImsAccessibilityService.onVolumeKey = { action ->
            runOnUiThread {
                methodChannel?.invokeMethod("onVolume", action)
            }
        }
        FloatingService.onClick = {
            runOnUiThread {
                methodChannel?.invokeMethod("onFloatingClick", null)
            }
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val service = "$packageName/${ImsAccessibilityService::class.java.name}"
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.split(':').any { it.equals(service, ignoreCase = true) }
    }
}