package com.kageno.ims

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
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
import org.json.JSONArray
import org.json.JSONObject
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

        fun typeTextStatic(text: String): Boolean =
            instance?.typeTextInternal(text) ?: false

        fun hasCachedEditable(): Boolean = try {
            val n = lastEditableRef?.get()
            n != null && n.refresh() && n.isEditable
        } catch (_: Exception) { false }

        fun openAppStatic(pkg: String): Boolean = instance?.openAppInternal(pkg) ?: false
        fun clickByTextStatic(text: String): Boolean = instance?.clickByTextInternal(text) ?: false
        fun clickByDescStatic(desc: String): Boolean = instance?.clickByDescInternal(desc) ?: false
        fun clickByIdStatic(viewId: String): Boolean = instance?.clickByIdInternal(viewId) ?: false
        fun clickAtStatic(x: Int, y: Int): Boolean = instance?.clickAtInternal(x, y) ?: false
        fun swipeStatic(x1: Int, y1: Int, x2: Int, y2: Int, d: Int): Boolean =
            instance?.swipeInternal(x1, y1, x2, y2, d) ?: false
        fun globalBackStatic(): Boolean = instance?.performGlobalAction(GLOBAL_ACTION_BACK) ?: false
        fun globalHomeStatic(): Boolean = instance?.performGlobalAction(GLOBAL_ACTION_HOME) ?: false
        fun globalRecentsStatic(): Boolean = instance?.performGlobalAction(GLOBAL_ACTION_RECENTS) ?: false
        fun currentPackageStatic(): String = try {
            instance?.rootInActiveWindow?.packageName?.toString() ?: ""
        } catch (_: Exception) { "" }
        fun dumpScreenStatic(): String = instance?.dumpScreenInternal() ?: "[]"
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
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
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

    // ═══════════════ تفريغ الشاشة ═══════════════
    private fun dumpScreenInternal(): String {
        val arr = JSONArray()
        val seen = mutableSetOf<String>()
        try {
            val roots = mutableListOf<AccessibilityNodeInfo>()
            try {
                val wins = windows
                if (!wins.isNullOrEmpty()) {
                    for (w in wins) {
                        val r = w.root ?: continue
                        roots.add(r)
                    }
                }
            } catch (_: Exception) {}
            if (roots.isEmpty()) rootInActiveWindow?.let { roots.add(it) }
            for (root in roots) walkNode(root, 0, arr, seen)
        } catch (e: Exception) {
            Log.e(TAG, "dump", e)
        }
        return arr.toString()
    }

    private fun walkNode(
        node: AccessibilityNodeInfo?,
        depth: Int,
        arr: JSONArray,
        seen: MutableSet<String>
    ) {
        if (node == null || depth > 50) return

        try {
            if (!node.refresh()) return

            val text = node.text?.toString()?.trim() ?: ""
            val desc = node.contentDescription?.toString()?.trim() ?: ""
            val viewId = node.viewIdResourceName ?: ""
            val cls = node.className?.toString() ?: ""
            val hint = try {
                if (android.os.Build.VERSION.SDK_INT >= 26)
                    node.hintText?.toString()?.trim() ?: "" else ""
            } catch (_: Exception) { "" }
            val isClickable = node.isClickable
            val isLongClickable = node.isLongClickable
            val isFocusable = node.isFocusable
            val isEditable = node.isEditable
            val isVisible = node.isVisibleToUser
            val isEnabled = node.isEnabled
            val pkg = node.packageName?.toString() ?: ""

            val rect = Rect()
            node.getBoundsInScreen(rect)

            val childCount = try { node.childCount } catch (_: Exception) { 0 }

            if (isVisible && rect.width() > 0 && rect.height() > 0 && arr.length() < 800) {
                val hasContent = text.isNotEmpty() || desc.isNotEmpty() || hint.isNotEmpty()
                val isInteractive = isClickable || isLongClickable || isEditable || isFocusable
                val hasId = viewId.isNotEmpty()

                if (hasContent || isInteractive || hasId) {
                    val key = "$viewId|$text|$desc|${rect.left},${rect.top}|$cls"
                    if (!seen.contains(key)) {
                        seen.add(key)

                        var clickableParent = false
                        try {
                            var p = node.parent
                            var d = 0
                            while (p != null && d < 8) {
                                if (p.isClickable) { clickableParent = true; break }
                                p = p.parent
                                d++
                            }
                        } catch (_: Exception) {}

                        val obj = JSONObject()
                        obj.put("text", text)
                        obj.put("desc", desc)
                        obj.put("id", viewId)
                        obj.put("className", cls)
                        obj.put("hint", hint)
                        obj.put("clickable", isClickable)
                        obj.put("longClickable", isLongClickable)
                        obj.put("focusable", isFocusable)
                        obj.put("editable", isEditable)
                        obj.put("enabled", isEnabled)
                        obj.put("clickableParent", clickableParent)
                        obj.put("pkg", pkg)
                        obj.put("x", rect.centerX())
                        obj.put("y", rect.centerY())
                        obj.put("left", rect.left)
                        obj.put("top", rect.top)
                        obj.put("right", rect.right)
                        obj.put("bottom", rect.bottom)
                        obj.put("width", rect.width())
                        obj.put("height", rect.height())
                        obj.put("depth", depth)
                        obj.put("childCount", childCount)
                        arr.put(obj)
                    }
                }
            }

            val count = try { node.childCount } catch (_: Exception) { 0 }
            for (i in 0 until count) {
                try { walkNode(node.getChild(i), depth + 1, arr, seen) }
                catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    // ═══════════════ فتح التطبيقات ═══════════════
    private fun openAppInternal(pkg: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(pkg)
            if (intent == null) { Log.w(TAG, "no launch intent for $pkg"); return false }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) { Log.e(TAG, "openApp", e); false }
    }

    // ═══════════════ الكتابة ═══════════════
    private fun typeTextInternal(text: String): Boolean {
        val delays = longArrayOf(0L, 120L, 220L, 350L)
        for (delay in delays) {
            if (delay > 0) try { Thread.sleep(delay) } catch (_: InterruptedException) { return false }
            if (tryOnce(text)) return true
        }
        return false
    }

    private fun tryOnce(text: String): Boolean {
        val focused = findFocusedInput()
        if (focused != null && tryMethodsWithVerify(focused, text)) return true

        val cached = resolveCached()
        if (cached != null && (focused == null || cached != focused)) {
            if (tryMethodsWithVerify(cached, text)) return true
        }

        val best = findBestTarget()
        if (best != null && best != focused && best != cached) {
            if (tryMethodsWithVerify(best, text)) return true
        }

        val target = focused ?: cached ?: best
        if (target != null) return gestureTapAndPaste(target, text)
        return false
    }

    private fun tryMethodsWithVerify(node: AccessibilityNodeInfo, text: String): Boolean {
        if (!safeRefresh(node)) return false
        if (doSetText(node, text) && verifyText(node, text)) return true
        if (doFocusThenSet(node, text) && verifyText(node, text)) return true
        if (doFocusThenPaste(node, text) && verifyText(node, text)) return true
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

    private fun verifyText(node: AccessibilityNodeInfo, expected: String): Boolean {
        return try {
            Thread.sleep(50)
            if (!safeRefresh(node)) return false
            val now = node.text?.toString() ?: ""
            if (now.isEmpty()) return false
            now == expected || now.contains(expected)
        } catch (_: Exception) { true }
    }

    private fun safeRefresh(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false
        return try { node.refresh() } catch (_: Exception) { false }
    }

    private fun gestureTapAndPaste(node: AccessibilityNodeInfo, text: String): Boolean {
        try {
            copyToClipboard(text)
            if (!safeRefresh(node)) return false
            val rect = Rect()
            node.getBoundsInScreen(rect)
            if (rect.width() <= 0 || rect.height() <= 0) return false

            val path = Path().apply { moveTo(rect.exactCenterX(), rect.exactCenterY()) }
            val stroke = GestureDescription.StrokeDescription(path, 0, 50)
            val gesture = GestureDescription.Builder().addStroke(stroke).build()

            val completed = java.util.concurrent.atomic.AtomicBoolean(false)
            val done = java.util.concurrent.atomic.AtomicBoolean(false)

            dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(g: GestureDescription?) {
                    completed.set(true); done.set(true)
                }
                override fun onCancelled(g: GestureDescription?) { done.set(true) }
            }, mainHandler)

            val start = System.currentTimeMillis()
            while (!done.get() && System.currentTimeMillis() - start < 1000) {
                try { Thread.sleep(20) } catch (_: InterruptedException) {}
            }
            if (!completed.get()) return false

            try { Thread.sleep(100) } catch (_: InterruptedException) {}

            var ok = false
            try { ok = node.performAction(AccessibilityNodeInfo.ACTION_PASTE) } catch (_: Exception) {}
            if (!ok) {
                val focused = findFocusedInput()
                if (focused != null) try {
                    ok = focused.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                } catch (_: Exception) {}
            }

            try { Thread.sleep(80) } catch (_: InterruptedException) {}

            if (safeRefresh(node)) {
                val now = node.text?.toString() ?: ""
                if (now.contains(text)) return true
            }
            return ok
        } catch (e: Exception) { Log.e(TAG, "gesture paste", e); return false }
    }

    private fun copyToClipboard(text: String) {
        try {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("ims_autofill", text))
        } catch (_: Exception) {}
    }

    // ═══════════════ الضغط على العناصر ═══════════════
    private fun clickByTextInternal(text: String): Boolean {
        val node = findNodeByPredicate { n ->
            val t = n.text?.toString() ?: ""
            t == text || t.contains(text)
        } ?: return false
        return performClickOnNode(node)
    }

    private fun clickByDescInternal(desc: String): Boolean {
        val node = findNodeByPredicate { n ->
            val d = n.contentDescription?.toString() ?: ""
            d == desc || d.contains(desc)
        } ?: return false
        return performClickOnNode(node)
    }

    private fun clickByIdInternal(viewId: String): Boolean {
        val node = findNodeByPredicate { n ->
            val id = n.viewIdResourceName ?: ""
            id == viewId || id.endsWith(":id/$viewId") || id.endsWith("/$viewId")
        } ?: return false
        return performClickOnNode(node)
    }

    private fun findNodeByPredicate(pred: (AccessibilityNodeInfo) -> Boolean): AccessibilityNodeInfo? {
        try {
            val wins = windows
            if (!wins.isNullOrEmpty()) {
                for (w in wins) {
                    val root = w.root ?: continue
                    val r = searchNode(root, pred)
                    if (r != null) return r
                }
            }
        } catch (_: Exception) {}
        val active = rootInActiveWindow ?: return null
        return searchNode(active, pred)
    }

    private fun searchNode(
        node: AccessibilityNodeInfo?,
        pred: (AccessibilityNodeInfo) -> Boolean
    ): AccessibilityNodeInfo? {
        if (node == null) return null
        try {
            if (safeRefresh(node) && pred(node)) {
                if (node.isClickable) return node
                var p = node.parent
                var depth = 0
                while (p != null && depth < 6) {
                    if (p.isClickable) return p
                    p = p.parent
                    depth++
                }
                return node
            }
        } catch (_: Exception) {}

        val count = try { node.childCount } catch (_: Exception) { 0 }
        for (i in 0 until count) {
            val c = try { node.getChild(i) } catch (_: Exception) { null } ?: continue
            val r = searchNode(c, pred)
            if (r != null) return r
        }
        return null
    }

    private fun performClickOnNode(node: AccessibilityNodeInfo): Boolean {
        try { if (node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return true }
        catch (_: Exception) {}

        try {
            var p = node.parent
            var depth = 0
            while (p != null && depth < 6) {
                if (p.isClickable && p.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return true
                p = p.parent
                depth++
            }
        } catch (_: Exception) {}

        return clickAtNodeCenter(node)
    }

    private fun clickAtNodeCenter(node: AccessibilityNodeInfo): Boolean {
        return try {
            val rect = Rect()
            node.getBoundsInScreen(rect)
            if (rect.width() <= 0 || rect.height() <= 0) return false
            clickAtInternal(rect.exactCenterX().toInt(), rect.exactCenterY().toInt())
        } catch (_: Exception) { false }
    }

    private fun clickAtInternal(x: Int, y: Int): Boolean {
        return try {
            val path = Path().apply { moveTo(x.toFloat(), y.toFloat()) }
            val stroke = GestureDescription.StrokeDescription(path, 0, 50)
            val gesture = GestureDescription.Builder().addStroke(stroke).build()
            dispatchGesture(gesture, null, null)
            true
        } catch (e: Exception) { false }
    }

    private fun swipeInternal(x1: Int, y1: Int, x2: Int, y2: Int, duration: Int): Boolean {
        return try {
            val path = Path().apply {
                moveTo(x1.toFloat(), y1.toFloat())
                lineTo(x2.toFloat(), y2.toFloat())
            }
            val dur = duration.toLong().coerceAtLeast(80L)
            val stroke = GestureDescription.StrokeDescription(path, 0, dur)
            val gesture = GestureDescription.Builder().addStroke(stroke).build()
            dispatchGesture(gesture, null, null)
            true
        } catch (_: Exception) { false }
    }

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