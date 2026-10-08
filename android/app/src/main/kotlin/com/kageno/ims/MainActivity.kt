package com.kageno.ims

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
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
                "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())
                "openAccessibilitySettings" -> {
                    try { startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) } catch (_: Exception) {}
                    result.success(null)
                }
                "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
                "openOverlaySettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                    } catch (_: Exception) {}
                    result.success(null)
                }
                "typeText" -> {
                    val text = call.argument<String>("text") ?: ""
                    runAsync(result) { ImsAccessibilityService.typeTextStatic(text) }
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
                            startService(Intent(this, FloatingService::class.java).apply { action = "SHOW" })
                            result.success(true)
                        } catch (_: Exception) { result.success(false) }
                    }
                }
                "hideFloating" -> {
                    try {
                        startService(Intent(this, FloatingService::class.java).apply { action = "HIDE" })
                    } catch (_: Exception) {}
                    result.success(null)
                }
                "updateFloatingText" -> {
                    val text = call.argument<String>("text") ?: ""
                    FloatingService.updateText(text)
                    result.success(null)
                }
                "openApp" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    runAsync(result) { ImsAccessibilityService.openAppStatic(pkg) }
                }
                "clickByText" -> {
                    val t = call.argument<String>("text") ?: ""
                    runAsync(result) { ImsAccessibilityService.clickByTextStatic(t) }
                }
                "clickByDesc" -> {
                    val d = call.argument<String>("desc") ?: ""
                    runAsync(result) { ImsAccessibilityService.clickByDescStatic(d) }
                }
                "clickById" -> {
                    val v = call.argument<String>("viewId") ?: ""
                    runAsync(result) { ImsAccessibilityService.clickByIdStatic(v) }
                }
                "clickAt" -> {
                    val x = call.argument<Int>("x") ?: 0
                    val y = call.argument<Int>("y") ?: 0
                    runAsync(result) { ImsAccessibilityService.clickAtStatic(x, y) }
                }
                "swipe" -> {
                    val x1 = call.argument<Int>("x1") ?: 0
                    val y1 = call.argument<Int>("y1") ?: 0
                    val x2 = call.argument<Int>("x2") ?: 0
                    val y2 = call.argument<Int>("y2") ?: 0
                    val d = call.argument<Int>("duration") ?: 300
                    runAsync(result) { ImsAccessibilityService.swipeStatic(x1, y1, x2, y2, d) }
                }
                "globalBack" -> runAsync(result) { ImsAccessibilityService.globalBackStatic() }
                "globalHome" -> runAsync(result) { ImsAccessibilityService.globalHomeStatic() }
                "globalRecents" -> runAsync(result) { ImsAccessibilityService.globalRecentsStatic() }
                "currentPackage" -> result.success(ImsAccessibilityService.currentPackageStatic())

                // ⭐ جديد: قائمة التطبيقات المثبتة
                "listApps" -> {
                    try {
                        val pm = packageManager
                        val intent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_LAUNCHER)
                        }
                        @Suppress("DEPRECATION")
                        val apps = pm.queryIntentActivities(intent, 0)
                        val list = apps.mapNotNull { info ->
                            try {
                                val pkg = info.activityInfo.packageName
                                val name = info.loadLabel(pm).toString()
                                mapOf("package" to pkg, "name" to name)
                            } catch (_: Exception) { null }
                        }.sortedBy { (it["name"] ?: "").lowercase() }
                        result.success(list)
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, String>>())
                    }
                }

                else -> result.notImplemented()
            }
        }

        ImsAccessibilityService.onVolumeKey = { action ->
            runOnUiThread { methodChannel?.invokeMethod("onVolume", action) }
        }
        FloatingService.onClick = {
            runOnUiThread { methodChannel?.invokeMethod("onFloatingClick", null) }
        }
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Boolean) {
        Thread {
            val ok = try { block() } catch (_: Exception) { false }
            Handler(Looper.getMainLooper()).post { result.success(ok) }
        }.start()
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