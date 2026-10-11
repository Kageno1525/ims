package com.kageno.ims

import android.content.Intent
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
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())
                "openAccessibilitySettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    } catch (_: Exception) {}
                    result.success(null)
                }
                "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
                "openOverlaySettings" -> {
                    try {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                        )
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
                            startService(
                                Intent(this, FloatingService::class.java)
                                    .apply { action = "SHOW" }
                            )
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                }
                "hideFloating" -> {
                    try {
                        startService(
                            Intent(this, FloatingService::class.java)
                                .apply { action = "HIDE" }
                        )
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
                "clearAppData" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    runAsync(result) { ImsAccessibilityService.clearAppDataStatic(pkg) }
                }
                "smartClick" -> {
                    val text = call.argument<String>("text") ?: ""
                    val desc = call.argument<String>("desc") ?: ""
                    val viewId = call.argument<String>("viewId") ?: ""
                    val className = call.argument<String>("className") ?: ""
                    val index = call.argument<Int>("index") ?: 0
                    val preferClickable = call.argument<Boolean>("preferClickable") ?: true
                    runAsync(result) {
                        ImsAccessibilityService.smartClickStatic(
                            text, desc, viewId, className, index, preferClickable
                        )
                    }
                }
                "smartType" -> {
                    val value = call.argument<String>("value") ?: ""
                    val viewId = call.argument<String>("viewId") ?: ""
                    val hint = call.argument<String>("hint") ?: ""
                    val className = call.argument<String>("className") ?: ""
                    val index = call.argument<Int>("index") ?: 0
                    runAsync(result) {
                        ImsAccessibilityService.smartTypeStatic(
                            value, viewId, hint, className, index
                        )
                    }
                }
                "findElement" -> {
                    val text = call.argument<String>("text") ?: ""
                    val desc = call.argument<String>("desc") ?: ""
                    val viewId = call.argument<String>("viewId") ?: ""
                    val className = call.argument<String>("className") ?: ""
                    val index = call.argument<Int>("index") ?: 0
                    runAsync(result) {
                        ImsAccessibilityService.findElementStatic(
                            text, desc, viewId, className, index
                        )
                    }
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
                    runAsync(result) {
                        ImsAccessibilityService.swipeStatic(x1, y1, x2, y2, d)
                    }
                }
                "scrollForward" -> runAsync(result) {
                    ImsAccessibilityService.scrollForwardStatic()
                }
                "scrollBackward" -> runAsync(result) {
                    ImsAccessibilityService.scrollBackwardStatic()
                }
                "testGesture" -> {
                    Thread {
                        val r = ImsAccessibilityService.testGestureStatic()
                        Handler(Looper.getMainLooper()).post { result.success(r) }
                    }.start()
                }
                "globalBack" -> runAsync(result) {
                    ImsAccessibilityService.globalBackStatic()
                }
                "globalHome" -> runAsync(result) {
                    ImsAccessibilityService.globalHomeStatic()
                }
                "globalRecents" -> runAsync(result) {
                    ImsAccessibilityService.globalRecentsStatic()
                }
                "currentPackage" ->
                    result.success(ImsAccessibilityService.currentPackageStatic())
                "dumpScreen" -> {
                    try {
                        result.success(ImsAccessibilityService.dumpScreenStatic())
                    } catch (e: Exception) {
                        result.success("[]")
                    }
                }
                "listApps" -> {
                    try {
                        result.success(listInstalledApps())
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, String>>())
                    }
                }
                "resolvePackage" -> {
                    val name = call.argument<String>("name") ?: ""
                    result.success(resolvePackageByName(name))
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

    private fun listInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val map = mutableMapOf<String, String>()
        try {
            @Suppress("DEPRECATION")
            for (app in pm.getInstalledApplications(0)) {
                try {
                    val pkg = app.packageName
                    if (pkg == packageName) continue
                    if (pm.getLaunchIntentForPackage(pkg) == null) continue
                    val label = pm.getApplicationLabel(app).toString()
                    if (label.isNotBlank()) map[pkg] = label
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
        try {
            val mainIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            @Suppress("DEPRECATION")
            for (info in pm.queryIntentActivities(mainIntent, 0)) {
                try {
                    val pkg = info.activityInfo.packageName
                    if (pkg == packageName) continue
                    val label = info.loadLabel(pm).toString()
                    if (label.isNotBlank() && !map.containsKey(pkg)) {
                        map[pkg] = label
                    }
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
        return map.entries
            .map { mapOf("package" to it.key, "name" to it.value) }
            .sortedBy { (it["name"] ?: "").lowercase() }
    }

    private fun resolvePackageByName(query: String): String? {
        if (query.isBlank()) return null
        val q = query.trim()
        try {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(q, 0)
            return q
        } catch (_: Exception) {}
        val apps = listInstalledApps()
        val ql = q.lowercase()
        apps.firstOrNull { (it["name"] ?: "").lowercase() == ql }
            ?.let { return it["package"] }
        apps.firstOrNull {
            (it["name"] ?: "").lowercase().contains(ql) ||
                (it["package"] ?: "").lowercase().contains(ql)
        }?.let { return it["package"] }
        return null
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