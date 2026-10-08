package com.kageno.ims

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo

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
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_REQUEST_ENHANCED_WEB_ACCESSIBILITY or
                    AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
            serviceInfo = info
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    // ═══════════ الكتابة ═══════════
    private fun typeTextInternal(text: String): Boolean {
        // جرّب 4 مرات مع تأخير — عشان الحقل ممكن يبقى لسه بيتفتح
        val delays = longArrayOf(0, 80, 180, 350)
        for (d in delays) {
            if (d > 0) {
                try { Thread.sleep(d) } catch (_: InterruptedException) { return false }
            }
            if (attemptType(text)) return true
        }
        return false
    }

    private fun attemptType(text: String): Boolean {
        val target = findBestTarget() ?: return false

        // الطريقة 1: SET_TEXT مباشرة
        if (trySetText(target, text)) return true

        // الطريقة 2: Focus ثم SET_TEXT
        if (tryFocusThenSetText(target, text)) return true

        // الطريقة 3: Clipboard + Paste
        if (tryPaste(target, text)) return true

        return false
    }

    /// يدور على أحسن حقل — يفحص كل النوافذ مش بس النشطة
    private fun findBestTarget(): AccessibilityNodeInfo? {
        // 1) فحص كل النوافذ للـ focused editable field
        try {
            val wins: List<AccessibilityWindowInfo>? = windows
            if (wins != null) {
                for (w in wins) {
                    val root = w.root ?: continue
                    val f = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                    if (f != null && f.isEditable && f.isVisibleToUser) return f
                }
                // 2) لو مفيش focused، أول editable في أي نافذة
                for (w in wins) {
                    val root = w.root ?: continue
                    val e = findFirstEditable(root)
                    if (e != null) return e
                }
            }
        } catch (_: Exception) {}

        // 3) fallback على الـ active window
        val active = rootInActiveWindow
        if (active != null) {
            val f = active.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            if (f != null && f.isEditable) return f
            val e = findFirstEditable(active)
            if (e != null) return e
        }
        return null
    }

    private fun trySetText(node: AccessibilityNodeInfo, text: String): Boolean {
        try {
            val args = Bundle().apply {
                putCharSequence(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                    text
                )
            }
            if (!node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)) {
                return false
            }
            return verifyText(node, text)
        } catch (_: Exception) {
            return false
        }
    }

    private fun tryFocusThenSetText(node: AccessibilityNodeInfo, text: String): Boolean {
        try {
            node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            try { Thread.sleep(70) } catch (_: Exception) {}
            val args = Bundle().apply {
                putCharSequence(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                    text
                )
            }
            if (!node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)) {
                return false
            }
            return verifyText(node, text)
        } catch (_: Exception) {
            return false
        }
    }

    private fun tryPaste(node: AccessibilityNodeInfo, text: String): Boolean {
        try {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = ClipData.newPlainText("ims_autofill", text)
            cm.setPrimaryClip(clip)

            node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            try { Thread.sleep(70) } catch (_: Exception) {}

            if (!node.performAction(AccessibilityNodeInfo.ACTION_PASTE)) return false
            try { Thread.sleep(60) } catch (_: Exception) {}
            return verifyText(node, text)
        } catch (_: Exception) {
            return false
        }
    }

    /// يتحقق إن النص فعلاً اتكتب — لو القراءة فشلت نعتبره نجح
    private fun verifyText(node: AccessibilityNodeInfo, expected: String): Boolean {
        try {
            node.refresh()
        } catch (_: Exception) {}
        return try {
            val now = node.text?.toString() ?: return true
            now == expected || now.contains(expected)
        } catch (_: Exception) {
            true
        }
    }

    private fun findFirstEditable(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null
        if (node.isEditable && node.isVisibleToUser) return node
        val count = try { node.childCount } catch (_: Exception) { 0 }
        for (i in 0 until count) {
            val c = try { node.getChild(i) } catch (_: Exception) { null } ?: continue
            val r = findFirstEditable(c)
            if (r != null) return r
        }
        return null
    }

    // ═══════════ أزرار الصوت ═══════════
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