package com.kageno.ims

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import java.lang.ref.WeakReference

class ImsAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "ImsA11y"

        @Volatile
        var instance: ImsAccessibilityService? = null

        @Volatile
        var volumeEnabled: Boolean = false

        @Volatile
        var onVolumeKey: ((String) -> Unit)? = null

        @Volatile
        private var lastEditableRef: WeakReference<AccessibilityNodeInfo>? = null

        fun typeTextStatic(text: String): Boolean {
            return instance?.typeTextInternal(text) ?: false
        }

        fun hasCachedEditable(): Boolean {
            return try {
                val n = lastEditableRef?.get()
                n != null && n.refresh() && n.isEditable
            } catch (_: Exception) { false }
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        try {
            val info = serviceInfo
            info.flags = info.flags or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_REQUEST_ENHANCED_WEB_ACCESSIBILITY
            info.notificationTimeout = 30
            serviceInfo = info
        } catch (e: Exception) {
            Log.e(TAG, "config", e)
        }
        Log.d(TAG, "Service connected")
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
    }

    override fun onInterrupt() {}

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        try {
            when (event.eventType) {
                AccessibilityEvent.TYPE_VIEW_FOCUSED,
                AccessibilityEvent.TYPE_VIEW_CLICKED,
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                    val src = event.source ?: return
                    if (src.isEditable && src.isVisibleToUser) {
                        lastEditableRef = WeakReference(src)
                    }
                }
            }
        } catch (_: Exception) {}
    }

    // ═══════════════ الكتابة مع Retry و Verification ═══════════════
    private fun typeTextInternal(text: String): Boolean {
        // ⭐ 4 محاولات مع تأخير متزايد
        val delays = longArrayOf(0L, 120L, 220L, 350L)
        for (delay in delays) {
            if (delay > 0) {
                try { Thread.sleep(delay) } catch (_: InterruptedException) { return false }
            }
            if (tryOnce(text)) return true
        }
        return false
    }

    private fun tryOnce(text: String): Boolean {
        // 1) الحقل المركّز حالياً
        val focused = findFocusedInput()
        if (focused != null && tryMethodsWithVerify(focused, text)) return true

        // 2) الحقل المخزّن
        val cached = resolveCached()
        if (cached != null && (focused == null || cached != focused)) {
            if (tryMethodsWithVerify(cached, text)) return true
        }

        // 3) أول حقل قابل للكتابة في الشاشة
        val best = findBestTarget()
        if (best != null && best != focused && best != cached) {
            if (tryMethodsWithVerify(best, text)) return true
        }

        // 4) fallback: gesture tap + paste (للـ WebViews اللي بترفض SET_TEXT)
        val gestureTarget = focused ?: cached ?: best
        if (gestureTarget != null) {
            return gestureTapAndPaste(gestureTarget, text)
        }

        return false
    }

    /// ⭐ تجرب كل الطرق المباشرة مع التحقق الفعلي من الكتابة
    private fun tryMethodsWithVerify(node: AccessibilityNodeInfo, text: String): Boolean {
        if (!safeRefresh(node)) return false

        // ⚠️ في WebViews، SET_TEXT ممكن ترجع true بدون ما تكتب فعلاً
        // فبنتحقق بعد كل محاولة

        // 1) SET_TEXT مباشرة
        if (doSetText(node, text)) {
            if (verifyText(node, text)) return true
        }

        // 2) FOCUS ثم SET_TEXT
        if (doFocusThenSet(node, text)) {
            if (verifyText(node, text)) return true
        }

        // 3) Clipboard + ACTION_PASTE مباشرة
        if (doFocusThenPaste(node, text)) {
            if (verifyText(node, text)) return true
        }

        return false
    }

    private fun doSetText(node: AccessibilityNodeInfo, text: String): Boolean {
        return try {
            val args = Bundle().apply {
                putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            }
            node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        } catch (_: Exception) { false }
    }

    private fun doFocusThenSet(node: AccessibilityNodeInfo, text: String): Boolean {
        return try {
            node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            Thread.sleep(60)
            val args = Bundle().apply {
                putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            }
            node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        } catch (_: Exception) { false }
    }

    private fun doFocusThenPaste(node: AccessibilityNodeInfo, text: String): Boolean {
        return try {
            copyToClipboard(text)
            node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            Thread.sleep(60)
            node.performAction(AccessibilityNodeInfo.ACTION_PASTE)
        } catch (_: Exception) { false }
    }

    /// ⭐ تحقق حقيقي إن النص اتكتب
    private fun verifyText(node: AccessibilityNodeInfo, expected: String): Boolean {
        try {
            Thread.sleep(50)
            if (!safeRefresh(node)) return false
            val now = node.text?.toString() ?: ""
            if (now.isEmpty()) return false
            return now == expected || now.contains(expected)
        } catch (_: Exception) {
            // لو مش عارفين نقرأ (مثلاً password field)، نفترض النجاح
            return true
        }
    }

    private fun safeRefresh(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false
        return try { node.refresh() } catch (_: Exception) { false }
    }

    // ═══════════════ Gesture Tap + Paste (الأقوى) ═══════════════
    /// ⭐ بيستنى الـ gesture تخلص فعلاً قبل ما يرد
    private fun gestureTapAndPaste(node: AccessibilityNodeInfo, text: String): Boolean {
        try {
            copyToClipboard(text)

            if (!safeRefresh(node)) return false
            val rect = Rect()
            node.getBoundsInScreen(rect)
            if (rect.width() <= 0 || rect.height() <= 0) return false

            val path = Path().apply {
                moveTo(rect.exactCenterX(), rect.exactCenterY())
            }
            val stroke = GestureDescription.StrokeDescription(path, 0, 50)
            val gesture = GestureDescription.Builder().addStroke(stroke).build()

            // ⭐ بنستخدم flag يخلص من غير blocking
            val completionFlag = java.util.concurrent.atomic.AtomicBoolean(false)
            val doneFlag = java.util.concurrent.atomic.AtomicBoolean(false)

            dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(g: GestureDescription?) {
                    completionFlag.set(true)
                    doneFlag.set(true)
                }
                override fun onCancelled(g: GestureDescription?) {
                    doneFlag.set(true)
                }
            }, mainHandler)

            // انتظر النتيجة (بس مش أكتر من ثانية)
            val start = System.currentTimeMillis()
            while (!doneFlag.get() && System.currentTimeMillis() - start < 1000) {
                try { Thread.sleep(20) } catch (_: InterruptedException) {}
            }

            if (!completionFlag.get()) return false

            // بعد ما الـ tap خلص، استنى الـ focus يوصل
            try { Thread.sleep(100) } catch (_: InterruptedException) {}

            // paste
            val ok = performGlobalAction(GLOBAL_ACTION_PASTE)
            try { Thread.sleep(80) } catch (_: InterruptedException) {}

            // تأكيد إن الكتابة حصلت
            if (safeRefresh(node)) {
                val now = node.text?.toString() ?: ""
                if (now.contains(text)) return true
            }
            return ok
        } catch (e: Exception) {
            Log.e(TAG, "gesture paste", e)
            return false
        }
    }

    private fun copyToClipboard(text: String) {
        try {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("ims_autofill", text))
        } catch (_: Exception) {}
    }

    // ═══════════════ البحث عن الحقل ═══════════════
    private fun resolveCached(): AccessibilityNodeInfo? {
        return try {
            val n = lastEditableRef?.get()
            if (n != null && safeRefresh(n) && n.isEditable && n.isVisibleToUser) n else null
        } catch (_: Exception) { null }
    }

    private fun findFocusedInput(): AccessibilityNodeInfo? {
        try {
            val wins = windows
            if (!wins.isNullOrEmpty()) {
                for (w in wins) {
                    val root = w.root ?: continue
                    val f = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                    if (f != null && safeRefresh(f) && f.isEditable && f.isVisibleToUser) return f
                }
            }
        } catch (_: Exception) {}

        return try {
            val root = rootInActiveWindow
            val f = root?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            if (f != null && safeRefresh(f) && f.isEditable && f.isVisibleToUser) f else null
        } catch (_: Exception) { null }
    }

    private fun findBestTarget(): AccessibilityNodeInfo? {
        try {
            val wins = windows
            if (!wins.isNullOrEmpty()) {
                for (w in wins) {
                    val root = w.root ?: continue
                    val e = findFirstEditable(root)
                    if (e != null) return e
                }
            }
        } catch (_: Exception) {}

        val active = rootInActiveWindow ?: return null
        return findFirstEditable(active)
    }

    private fun findFirstEditable(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null
        try {
            if (safeRefresh(node) && node.isEditable && node.isVisibleToUser) return node
        } catch (_: Exception) { return null }

        val count = try { node.childCount } catch (_: Exception) { 0 }
        for (i in 0 until count) {
            val c = try { node.getChild(i) } catch (_: Exception) { null } ?: continue
            val r = findFirstEditable(c)
            if (r != null) return r
        }
        return null
    }

    // ═══════════════ أزرار الصوت ═══════════════
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