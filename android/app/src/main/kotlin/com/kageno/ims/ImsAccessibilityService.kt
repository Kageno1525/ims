package com.kageno.ims

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class ImsAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: ImsAccessibilityService? = null

        @Volatile
        var volumeEnabled: Boolean = false

        @Volatile
        var onVolumeKey: ((String) -> Unit)? = null

        fun typeTextStatic(text: String): Boolean {
            val svc = instance ?: return false
            return svc.typeTextInternal(text)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        try {
            val info = serviceInfo
            info.flags = info.flags or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_REQUEST_ENHANCED_WEB_ACCESSIBILITY
            serviceInfo = info
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    // ═══════ الكتابة ═══════
    private fun typeTextInternal(text: String): Boolean {
        // 1) جرّب مرة
        if (attemptType(text)) return true

        // 2) استنى شوية وجرّب تاني (يمكن الحقل لسه مااتفتحش)
        val handler = Handler(Looper.getMainLooper())
        for (delay in longArrayOf(120L, 250L, 450L)) {
            var done = false
            val latch = java.util.concurrent.CountDownLatch(1)
            handler.postDelayed({
                try {
                    if (attemptType(text)) done = true
                } finally {
                    latch.countDown()
                }
            }, delay)
            try { latch.await() } catch (_: InterruptedException) {}
            if (done) return true
        }
        return false
    }

    private fun attemptType(text: String): Boolean {
        val root = rootInActiveWindow ?: return false

        // 1) الحقل اللي عليه focus
        var target = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)

        // 2) لو مفيش، أول حقل قابل للكتابة
        if (target == null || !target.isEditable) {
            val found = findEditable(root)
            if (found != null) target = found
        }

        if (target == null) return false

        // 3) لو الحقل مش قابل للكتابة، طلع للأب
        var node: AccessibilityNodeInfo? = target
        while (node != null && !node.isEditable) node = node.parent
        if (node != null) target = node

        if (target == null || !target.isEditable) return false

        // 4) جرّب ACTION_SET_TEXT
        try {
            val args = Bundle()
            args.putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                text
            )
            if (target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)) {
                // تأكيد: اقرأ القيمة اللي اتكتبت
                try {
                    target.refresh()
                    val nowText = target.text?.toString() ?: ""
                    if (nowText.contains(text) || nowText == text) return true
                } catch (_: Exception) {
                    // مفيش قراءة متاحة - نفترض النجاح
                    return true
                }
            }
        } catch (_: Exception) {}

        // 5) جرّب Clipboard + Paste
        if (tryClipboardPaste(text, target)) return true

        // 6) جرّب Focus → Set text
        try {
            target.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            Thread.sleep(60)
            val args = Bundle()
            args.putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                text
            )
            if (target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)) return true
        } catch (_: Exception) {}

        return false
    }

    private fun tryClipboardPaste(text: String, node: AccessibilityNodeInfo): Boolean {
        try {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = ClipData.newPlainText("ims_autofill", text)
            cm.setPrimaryClip(clip)

            try { node.performAction(AccessibilityNodeInfo.ACTION_FOCUS) } catch (_: Exception) {}
            Thread.sleep(80)

            if (node.performAction(AccessibilityNodeInfo.ACTION_PASTE)) {
                try {
                    node.refresh()
                    val nowText = node.text?.toString() ?: ""
                    if (nowText.contains(text)) return true
                } catch (_: Exception) { return true }
            }
        } catch (_: Exception) {}
        return false
    }

    private fun findEditable(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isEditable && node.isVisibleToUser) return node
        for (i in 0 until node.childCount) {
            val c = node.getChild(i) ?: continue
            val r = findEditable(c)
            if (r != null) return r
        }
        return null
    }

    // ═══════ أزرار الصوت ═══════
    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (!volumeEnabled) return false
        if (event.action != KeyEvent.ACTION_DOWN) return false
        when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                onVolumeKey?.invoke("vol_up")
                return true
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                onVolumeKey?.invoke("vol_down")
                return true
            }
        }
        return false
    }
}