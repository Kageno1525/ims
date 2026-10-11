package com.kageno.ims

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Debug
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ims/autofill"
    private var methodChannel: MethodChannel? = null

    // ⭐⭐⭐ حماية كاملة — التطبيق يقفل فوراً عند أي تهديد
    private val KILL_ON_THREAT = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ⭐⭐⭐ فحص أمني
        val threats = fullSecurityCheck(this)
        if (threats.isNotEmpty()) {
            android.util.Log.w(
                "IMS_SECURITY",
                "⚠️ Threats detected: $threats"
            )

            if (KILL_ON_THREAT) {
                android.util.Log.e(
                    "IMS_SECURITY",
                    "🛑 Killing app due to threats: $threats"
                )
                finishAffinity()
                android.os.Process.killProcess(android.os.Process.myPid())
                kotlin.system.exitProcess(0)
                return
            }
        }

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
                "securityCheck" -> {
                    result.success(fullSecurityCheck(this))
                }
                "getDeviceHwid" -> {
                    try {
                        val prefs = getSharedPreferences(
                            "FlutterSharedPreferences",
                            MODE_PRIVATE
                        )
                        val hwid = prefs.getString(
                            "flutter.ims_device_hwid",
                            ""
                        ) ?: ""
                        result.success(hwid)
                    } catch (_: Exception) {
                        result.success("")
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

    // ═══════════════════════════════════════════════════
    // ⭐ SecurityGuard — داخل MainActivity
    // ═══════════════════════════════════════════════════

    private fun fullSecurityCheck(context: Context): List<String> {
        val threats = mutableListOf<String>()
        if (isRooted()) threats.add("root")
        if (isDebuggerAttached()) threats.add("debugger")
        if (isEmulator()) threats.add("emulator")
        if (isHooked()) threats.add("hooks")
        return threats
    }

    private fun isRooted(): Boolean {
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su",
            "/system/xbin/daemonsu",
            "/system/etc/init.d/99SuperSUDaemon",
            "/dev/com.koushikdutta.superuser.daemon/",
            "/system/xbin/busybox",
        )
        for (p in paths) {
            try {
                if (File(p).exists()) return true
            } catch (_: Exception) {}
        }
        val tags = Build.TAGS ?: ""
        if (tags.contains("test-keys")) return true

        try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val reader = process.inputStream.bufferedReader()
            val result = reader.readLine()
            process.destroy()
            if (result != null && result.isNotEmpty()) return true
        } catch (_: Exception) {}

        return false
    }

    private fun isDebuggerAttached(): Boolean {
        return try {
            Debug.isDebuggerConnected() || Debug.waitingForDebugger()
        } catch (_: Exception) {
            false
        }
    }

    private fun isEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic") ||
                Build.FINGERPRINT.startsWith("unknown") ||
                Build.MODEL.contains("google_sdk") ||
                Build.MODEL.contains("Emulator") ||
                Build.MODEL.contains("Android SDK built for x86") ||
                Build.MANUFACTURER.contains("Genymotion") ||
                (Build.BRAND.startsWith("generic") &&
                    Build.DEVICE.startsWith("generic")) ||
                "google_sdk" == Build.PRODUCT)
    }

    private fun isHooked(): Boolean {
        try {
            if (File("/data/local/tmp/frida-server").exists()) return true
            if (File("/data/local/tmp/re.frida.server").exists()) return true
            if (File("/system/lib/libfrida-gadget.so").exists()) return true
            if (File("/system/lib64/libfrida-gadget.so").exists()) return true
        } catch (_: Exception) {}

        try {
            throw Exception()
        } catch (e: Exception) {
            val stack = e.stackTrace
            for (element in stack) {
                val cn = element.className
                if (cn.contains("de.robv.android.xposed") ||
                    cn.contains("com.saurik.substrate")) {
                    return true
                }
            }
        }

        try {
            Class.forName("de.robv.android.xposed.XposedBridge")
            return true
        } catch (_: Exception) {}
        try {
            Class.forName("de.robv.android.xposed.XC_MethodHook")
            return true
        } catch (_: Exception) {}

        return false
    }

    // ═══════════════════════════════════════════════════

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
            Settings.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.split(':').any { it.equals(service, ignoreCase = true) }
    }
}