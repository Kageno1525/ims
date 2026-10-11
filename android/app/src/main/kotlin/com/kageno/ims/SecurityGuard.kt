package com.kageno.ims

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Debug
import java.io.File

/**
 * ⭐ حماية متعددة الطبقات ضد:
 *   - Root
 *   - Debugger
 *   - Emulator
 *   - تعديل التطبيق
 */
object SecurityGuard {

    /**
     * فحص شامل — يرجّع قائمة بالتهديدات المكتشفة
     */
    fun fullCheck(context: Context): List<String> {
        val threats = mutableListOf<String>()
        if (isRooted()) threats.add("root")
        if (isDebuggerAttached()) threats.add("debugger")
        if (isEmulator()) threats.add("emulator")
        if (isHooked()) threats.add("hooks")
        if (isTampered(context)) threats.add("tampered")
        return threats
    }

    // ⭐ Root Detection
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
        // Build Tags
        val tags = Build.TAGS ?: ""
        if (tags.contains("test-keys")) return true

        // su binary in PATH
        try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val reader = process.inputStream.bufferedReader()
            val result = reader.readLine()
            process.destroy()
            if (result != null && result.isNotEmpty()) return true
        } catch (_: Exception) {}

        return false
    }

    // ⭐ Debugger Detection
    private fun isDebuggerAttached(): Boolean {
        return try {
            Debug.isDebuggerConnected() || Debug.waitingForDebugger()
        } catch (_: Exception) {
            false
        }
    }

    // ⭐ Emulator Detection
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

    // ⭐ Hooks Detection (Xposed, Frida, Substrate)
    private fun isHooked(): Boolean {
        // Frida
        try {
            if (File("/data/local/tmp/frida-server").exists()) return true
            if (File("/data/local/tmp/re.frida.server").exists()) return true
            if (File("/system/lib/libfrida-gadget.so").exists()) return true
            if (File("/system/lib64/libfrida-gadget.so").exists()) return true
        } catch (_: Exception) {}

        // Xposed
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

        // Check for Xposed classes
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

    // ⭐ Tamper Detection (Signature)
    private fun isTampered(context: Context): Boolean {
        try {
            val pm = context.packageManager
            val signatures = pm.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNATURES
            ).signatures ?: return false

            // لو التطبيق اتعدّل واتوقّع بمفتاح مختلف
            // ده يعتبر tampered
            // ملاحظة: هنحتاج نقارن مع SHA الأصلي
            // بس لسه محتاجين الـ debug signing
            // عشان ما نكسرش التطبيق في الـ development

            // دلوقتي بنرجع false — هيتم تفعيلها لما يعمل signingConfig
            return false
        } catch (_: Exception) {
            return false
        }
    }
}