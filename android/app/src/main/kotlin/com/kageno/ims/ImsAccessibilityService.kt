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
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import org.json.JSONArray
import org.json.JSONObject
import java.lang.ref.WeakReference
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

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

        fun smartClickStatic(
            text: String,
            desc: String,
            viewId: String,
            className: String,
            index: Int,
            preferClickable: Boolean
        ): Boolean = instance?.smartClickInternal(
            text, desc, viewId, className, index, preferClickable
        ) ?: false

        fun smartTypeStatic(
            value: String,
            viewId: String,
            hint: String,
            className: String,
            index: Int
        ): Boolean = instance?.smartTypeInternal(
            value, viewId, hint, className, index
        ) ?: false

        fun findElementStatic(
            text: String,
            desc: String,
            viewId: String,
            className: String,
            index: Int
        ): Boolean = instance?.findElementInternal(
            text, desc, viewId, className, index
        ) ?: false

        fun clearAppDataStatic(pkg: String): Boolean =
            instance?.clearAppDataInternal(pkg) ?: false

        fun openAppStatic(pkg: String): Boolean =
            instance?.openAppInternal(pkg) ?: false

        fun clickAtStatic(x: Int, y: Int): Boolean =
            instance?.clickAtInternal(x, y) ?: false

        fun swipeStatic(x1: Int, y1: Int, x2: Int, y2: Int, d: Int): Boolean =
            instance?.swipeInternal(x1, y1, x2, y2, d) ?: false

        // ⭐ جديد: scroll بالـ Accessibility action (مش محتاج Gesture)
        fun scrollForwardStatic(): Boolean =
            instance?.scrollInternal(forward = true) ?: false

        fun scrollBackwardStatic(): Boolean =
            instance?.scrollInternal(forward = false) ?: false

        fun globalBackStatic(): Boolean =
            instance?.performGlobalAction(GLOBAL_ACTION_BACK) ?: false

        fun globalHomeStatic(): Boolean =
            instance?.performGlobalAction(GLOBAL_ACTION_HOME) ?: false

        fun globalRecentsStatic(): Boolean =
            instance?.performGlobalAction(GLOBAL_ACTION_RECENTS) ?: false

        fun currentPackageStatic(): String = try {
            instance?.rootInActiveWindow?.packageName?.toString() ?: ""
        } catch (_: Exception) {
            ""
        }

        fun dumpScreenStatic(): String =
            instance?.dumpScreenInternal() ?: "[]"
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
        } catch (_: Exception) {
        }
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
            } catch (_: Exception) {
            }
            if (roots.isEmpty()) {
                rootInActiveWindow?.let { roots.add(it) }
            }
            for (root in roots) {
                walkNode(root, 0, arr, seen)
            }
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
                if (android.os.Build.VERSION.SDK_INT >= 26) {
                    node.hintText?.toString()?.trim() ?: ""
                } else {
                    ""
                }
            } catch (_: Exception) {
                ""
            }
            val isClickable = node.isClickable
            val isLongClickable = node.isLongClickable
            val isFocusable = node.isFocusable
            val isEditable = node.isEditable
            val isVisible = node.isVisibleToUser
            val isEnabled = node.isEnabled
            val pkg = node.packageName?.toString() ?: ""

            val rect = Rect()
            node.getBoundsInScreen(rect)
            val childCount = try {
                node.childCount
            } catch (_: Exception) {
                0
            }

            if (isVisible && rect.width() > 0 && rect.height() > 0 &&
                arr.length() < 800
            ) {
                val hasContent = text.isNotEmpty() ||
                        desc.isNotEmpty() || hint.isNotEmpty()
                val isInteractive = isClickable || isLongClickable ||
                        isEditable || isFocusable
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
                                if (p.isClickable) {
                                    clickableParent = true
                                    break
                                }
                                p = p.parent
                                d++
                            }
                        } catch (_: Exception) {
                        }

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

            val count = try {
                node.childCount
            } catch (_: Exception) {
                0
            }
            for (i in 0 until count) {
                try {
                    walkNode(node.getChild(i), depth + 1, arr, seen)
                } catch (_: Exception) {
                }
            }
        } catch (_: Exception) {
        }
    }

    // ═══════════════ SMART CLICK ═══════════════
    private fun smartClickInternal(
        text: String,
        desc: String,
        viewId: String,
        className: String,
        index: Int,
        preferClickable: Boolean
    ): Boolean {
        val all = collectAllNodes()
        val matches = all.filter { node ->
            matchesQuery(node, text, desc, viewId, className)
        }
        if (matches.isEmpty()) return false
        val scored = matches.map { node ->
            Pair(node, scoreNode(node, preferClickable))
        }.sortedByDescending { it.second }
        val target = if (index >= 0 && index < scored.size) {
            scored[index].first
        } else {
            scored.first().first
        }
        return performClickOnNode(target)
    }

    private fun findElementInternal(
        text: String,
        desc: String,
        viewId: String,
        className: String,
        index: Int
    ): Boolean {
        val all = collectAllNodes()
        val matches = all.filter { node ->
            matchesQuery(node, text, desc, viewId, className)
        }
        if (matches.isEmpty()) return false
        val idx = if (index >= 0 && index < matches.size) index else 0
        return try {
            matches[idx].refresh()
        } catch (_: Exception) {
            false
        }
    }

    private fun matchesQuery(
        node: AccessibilityNodeInfo,
        text: String,
        desc: String,
        viewId: String,
        className: String
    ): Boolean {
        try {
            if (!node.refresh()) return false
            if (!node.isVisibleToUser) return false

            if (text.isNotEmpty()) {
                val t = node.text?.toString() ?: ""
                if (!t.contains(text)) return false
            }
            if (desc.isNotEmpty()) {
                val d = node.contentDescription?.toString() ?: ""
                if (!d.contains(desc)) return false
            }
            if (viewId.isNotEmpty()) {
                val id = node.viewIdResourceName ?: ""
                if (!(id == viewId ||
                            id.endsWith("/$viewId") ||
                            id.contains(viewId))
                ) {
                    return false
                }
            }
            if (className.isNotEmpty()) {
                val c = node.className?.toString() ?: ""
                if (!c.endsWith(className)) return false
            }
            return true
        } catch (_: Exception) {
            return false
        }
    }

    private fun scoreNode(
        node: AccessibilityNodeInfo,
        preferClickable: Boolean
    ): Int {
        try {
            if (node.isClickable && node.isEnabled) return 1000
            var p = node.parent
            var d = 0
            while (p != null && d < 5) {
                if (p.isClickable && p.isEnabled) return 800
                p = p.parent
                d++
            }
            if (node.isFocusable && node.isEnabled) return 400
            if (node.isEnabled) return 100
        } catch (_: Exception) {
        }
        return 0
    }

    private fun collectAllNodes(): List<AccessibilityNodeInfo> {
        val list = mutableListOf<AccessibilityNodeInfo>()
        try {
            val wins = windows
            if (!wins.isNullOrEmpty()) {
                for (w in wins) {
                    val root = w.root ?: continue
                    walkCollect(root, list)
                }
            }
        } catch (_: Exception) {
        }
        if (list.isEmpty()) {
            rootInActiveWindow?.let { walkCollect(it, list) }
        }
        return list
    }

    private fun walkCollect(
        node: AccessibilityNodeInfo?,
        list: MutableList<AccessibilityNodeInfo>
    ) {
        if (node == null || list.size > 2000) return
        try {
            node.refresh()
            list.add(node)
            for (i in 0 until node.childCount) {
                walkCollect(node.getChild(i), list)
            }
        } catch (_: Exception) {
        }
    }

    // ═══════════════ SMART TYPE ═══════════════
    private fun smartTypeInternal(
        value: String,
        viewId: String,
        hint: String,
        className: String,
        index: Int
    ): Boolean {
        val all = collectAllNodes()
        val editables = all.filter { node ->
            try {
                node.refresh()
                if (!node.isEditable || !node.isVisibleToUser) {
                    return@filter false
                }
                if (viewId.isNotEmpty()) {
                    val id = node.viewIdResourceName ?: ""
                    if (!(id == viewId ||
                                id.endsWith("/$viewId") ||
                                id.contains(viewId))
                    ) {
                        return@filter false
                    }
                }
                if (hint.isNotEmpty()) {
                    val h = try {
                        if (android.os.Build.VERSION.SDK_INT >= 26) {
                            node.hintText?.toString() ?: ""
                        } else {
                            ""
                        }
                    } catch (_: Exception) {
                        ""
                    }
                    if (!h.contains(hint)) return@filter false
                }
                if (className.isNotEmpty()) {
                    val c = node.className?.toString() ?: ""
                    if (!c.endsWith(className)) return@filter false
                }
                true
            } catch (_: Exception) {
                false
            }
        }
        if (editables.isEmpty()) {
            return typeTextInternal(value)
        }
        val target = if (index >= 0 && index < editables.size) {
            editables[index]
        } else {
            editables.first()
        }
        return doSetText(target, value) && verifyText(target, value)
    }

    // ═══════════════ كتابة عامة ═══════════════
    private fun typeTextInternal(text: String): Boolean {
        val delays = longArrayOf(0L, 120L, 220L, 350L)
        for (delay in delays) {
            if (delay > 0) {
                try {
                    Thread.sleep(delay)
                } catch (_: InterruptedException) {
                    return false
                }
            }
            if (tryOnce(text)) return true
        }
        return false
    }

    private fun tryOnce(text: String): Boolean {
        val focused = findFocusedInput()
        if (focused != null && tryMethodsWithVerify(focused, text)) {
            return true
        }
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

    private fun tryMethodsWithVerify(
        node: AccessibilityNodeInfo,
        text: String
    ): Boolean {
        if (!safeRefresh(node)) return false
        if (doSetText(node, text) && verifyText(node, text)) return true
        if (doFocusThenSet(node, text) && verifyText(node, text)) {
            return true
        }
        if (doFocusThenPaste(node, text) && verifyText(node, text)) {
            return true
        }
        return false
    }

    private fun doSetText(
        node: AccessibilityNodeInfo,
        text: String
    ): Boolean {
        return try {
            val args = Bundle().apply {
                putCharSequence(
                    AccessibilityNodeInfo
                        .ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                    text
                )
            }
            node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        } catch (_: Exception) {
            false
        }
    }

    private fun doFocusThenSet(
        node: AccessibilityNodeInfo,
        text: String
    ): Boolean {
        return try {
            node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            Thread.sleep(60)
            val args = Bundle().apply {
                putCharSequence(
                    AccessibilityNodeInfo
                        .ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                    text
                )
            }
            node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        } catch (_: Exception) {
            false
        }
    }

    private fun doFocusThenPaste(
        node: AccessibilityNodeInfo,
        text: String
    ): Boolean {
        return try {
            copyToClipboard(text)
            node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            Thread.sleep(60)
            node.performAction(AccessibilityNodeInfo.ACTION_PASTE)
        } catch (_: Exception) {
            false
        }
    }

    private fun verifyText(
        node: AccessibilityNodeInfo,
        expected: String
    ): Boolean {
        return try {
            Thread.sleep(50)
            if (!safeRefresh(node)) return false
            val now = node.text?.toString() ?: ""
            if (now.isEmpty()) return false
            now == expected || now.contains(expected)
        } catch (_: Exception) {
            true
        }
    }

    private fun safeRefresh(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false
        return try {
            node.refresh()
        } catch (_: Exception) {
            false
        }
    }

    private fun gestureTapAndPaste(
        node: AccessibilityNodeInfo,
        text: String
    ): Boolean {
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
            val gesture = GestureDescription.Builder()
                .addStroke(stroke).build()

            val completed = java.util.concurrent.atomic.AtomicBoolean(false)
            val done = java.util.concurrent.atomic.AtomicBoolean(false)

            dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(g: GestureDescription?) {
                    completed.set(true)
                    done.set(true)
                }

                override fun onCancelled(g: GestureDescription?) {
                    done.set(true)
                }
            }, mainHandler)

            val start = System.currentTimeMillis()
            while (!done.get() &&
                System.currentTimeMillis() - start < 1000
            ) {
                try {
                    Thread.sleep(20)
                } catch (_: InterruptedException) {
                }
            }
            if (!completed.get()) return false
            try {
                Thread.sleep(100)
            } catch (_: InterruptedException) {
            }

            var ok = false
            try {
                ok = node.performAction(AccessibilityNodeInfo.ACTION_PASTE)
            } catch (_: Exception) {
            }
            if (!ok) {
                val focused = findFocusedInput()
                if (focused != null) {
                    try {
                        ok = focused.performAction(
                            AccessibilityNodeInfo.ACTION_PASTE
                        )
                    } catch (_: Exception) {
                    }
                }
            }
            try {
                Thread.sleep(80)
            } catch (_: InterruptedException) {
            }
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
            val cm = getSystemService(
                Context.CLIPBOARD_SERVICE
            ) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("ims_autofill", text))
        } catch (_: Exception) {
        }
    }

    // ═══════════════ فتح التطبيقات ═══════════════
    private fun openAppInternal(pkg: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(pkg)
            if (intent == null) return false
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    // ═══════════════ مسح بيانات تطبيق ═══════════════
    private fun clearAppDataInternal(pkg: String): Boolean {
        try {
            if (pkg.isEmpty()) return false

            Log.d(TAG, "clearAppData: starting for $pkg")

            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$pkg")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)

            try { Thread.sleep(2000) } catch (_: Exception) {}

            val storageOpened = clickByAnyText(
                timeoutMs = 6000,
                maxAttempts = 30,
                keywords = arrayOf(
                    "Storage & cache",
                    "Storage and cache",
                    "Storage & cache usage",
                    "Storage usage",
                    "Storage",
                    "App storage",
                    "Manage storage",
                    "Memory",
                    "التخزين والذاكرة",
                    "التخزين والذاكرة المؤقتة",
                    "التخزين",
                    "مساحة التخزين",
                    "ذاكرة التخزين",
                    "استخدام التخزين",
                    "إدارة التخزين",
                    "التخزين المؤقت",
                    "الذاكرة والتخزين",
                    "المساحة والتخزين"
                )
            )
            Log.d(TAG, "clearAppData: storage opened = $storageOpened")

            try { Thread.sleep(1500) } catch (_: Exception) {}

            val clearClicked = clickByAnyText(
                timeoutMs = 6000,
                maxAttempts = 30,
                keywords = arrayOf(
                    "Clear storage",
                    "Clear data",
                    "Clear app data",
                    "Clear all data",
                    "Clear user data",
                    "Clear cache and data",
                    "Reset app",
                    "Erase data",
                    "Delete data",
                    "Delete app data",
                    "Delete all data",
                    "مسح التخزين",
                    "مسح البيانات",
                    "مسح بيانات التطبيق",
                    "مسح كل البيانات",
                    "محو التخزين",
                    "محو البيانات",
                    "محو كل البيانات",
                    "محو",
                    "مسح",
                    "حذف التخزين",
                    "حذف البيانات",
                    "حذف كل البيانات",
                    "إعادة تعيين التطبيق",
                    "إعادة التعيين",
                    "تفريغ التخزين",
                    "تفريغ البيانات",
                    "إزالة البيانات",
                    "إزالة التخزين"
                )
            )
            Log.d(TAG, "clearAppData: clear clicked = $clearClicked")
            if (!clearClicked) return false

            try { Thread.sleep(1800) } catch (_: Exception) {}

            if (clickAndroidDialogButton()) {
                Log.d(TAG, "clearAppData: dialog button clicked via ID")
                try { Thread.sleep(1000) } catch (_: Exception) {}
                return true
            }

            val confirmKeywords = arrayOf(
                "Clear all data",
                "Clear data",
                "Clear storage",
                "Delete",
                "Delete all",
                "Delete data",
                "Erase",
                "Erase all",
                "Erase data",
                "OK",
                "Ok",
                "ok",
                "Yes",
                "yes",
                "Yes, clear",
                "Yes, clear all",
                "Yes, delete",
                "Confirm",
                "Confirm clear",
                "Confirm delete",
                "Continue",
                "Proceed",
                "Reset",
                "Reset app",
                "Allow",
                "Agree",
                "Accept",
                "Got it",
                "Understood",
                "I understand",
                "Done",
                "مسح الكل",
                "مسح البيانات",
                "مسح التخزين",
                "محو الكل",
                "محو البيانات",
                "محو التخزين",
                "حذف الكل",
                "حذف البيانات",
                "حذف التخزين",
                "حذف",
                "محو",
                "مسح",
                "موافق",
                "أوافق",
                "الموافقة",
                "نعم",
                "حسناً",
                "حسنا",
                "تمام",
                "طيب",
                "متابعة",
                "استمرار",
                "تأكيد",
                "تأكيد المسح",
                "إعادة تعيين",
                "إعادة التعيين",
                "أفهم",
                "فهمت",
                "إزالة",
                "إزالة الكل",
                "تفريغ",
                "تفريغ الكل",
                "السماح",
                "قبول"
            )

            for (i in 0 until 5) {
                val ok = clickByAnyText(
                    timeoutMs = 2500,
                    maxAttempts = 15,
                    keywords = confirmKeywords
                )
                Log.d(TAG, "clearAppData: confirm attempt $i = $ok")
                if (!ok) break
                try { Thread.sleep(900) } catch (_: Exception) {}
            }

            return true
        } catch (e: Exception) {
            Log.e(TAG, "clearAppData", e)
            return false
        }
    }

    private fun clickAndroidDialogButton(): Boolean {
        try {
            val all = collectAllNodes()
            for (node in all) {
                try {
                    val viewId = node.viewIdResourceName ?: ""
                    if (viewId == "android:id/button1" && node.isVisibleToUser) {
                        val t = node.text?.toString()?.trim() ?: ""
                        if (t.contains("Cancel", ignoreCase = true) ||
                            t.contains("إلغاء") ||
                            t.contains("لا")
                        ) {
                            continue
                        }
                        if (performClickOnNode(node)) {
                            Log.d(TAG, "clicked android:id/button1 ($t)")
                            return true
                        }
                    }
                } catch (_: Exception) {}
            }
            for (node in all) {
                try {
                    val viewId = node.viewIdResourceName ?: ""
                    if (viewId == "android:id/button2" && node.isVisibleToUser) {
                        val t = node.text?.toString()?.trim() ?: ""
                        if (t.contains("Delete", ignoreCase = true) ||
                            t.contains("OK", ignoreCase = true) ||
                            t.contains("Yes", ignoreCase = true) ||
                            t.contains("حذف") ||
                            t.contains("محو") ||
                            t.contains("موافق") ||
                            t.contains("نعم")
                        ) {
                            if (performClickOnNode(node)) {
                                Log.d(TAG, "clicked android:id/button2 ($t)")
                                return true
                            }
                        }
                    }
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
        return false
    }

    private fun clickByAnyText(
        timeoutMs: Long,
        maxAttempts: Int,
        keywords: Array<String>
    ): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        var attempt = 0

        while (System.currentTimeMillis() < deadline &&
            attempt < maxAttempts
        ) {
            attempt++
            try {
                val all = collectAllNodes()
                for (node in all) {
                    try {
                        if (!node.isVisibleToUser) continue
                        val text = node.text?.toString()?.trim() ?: ""
                        val desc = node.contentDescription
                            ?.toString()?.trim() ?: ""
                        for (kw in keywords) {
                            if (text.equals(kw, ignoreCase = true) ||
                                text.contains(kw, ignoreCase = true) ||
                                desc.equals(kw, ignoreCase = true) ||
                                desc.contains(kw, ignoreCase = true)
                            ) {
                                if (performClickOnNode(node)) {
                                    Log.d(TAG, "clicked: $text / $desc")
                                    return true
                                }
                            }
                        }
                    } catch (_: Exception) {
                    }
                }
            } catch (_: Exception) {
            }
            try {
                Thread.sleep(200)
            } catch (_: Exception) {
            }
        }
        return false
    }

    // ═══════════════ click على عنصر ═══════════════
    private fun performClickOnNode(
        node: AccessibilityNodeInfo
    ): Boolean {
        try {
            if (node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                return true
            }
        } catch (_: Exception) {
        }
        try {
            var p = node.parent
            var depth = 0
            while (p != null && depth < 6) {
                if (p.isClickable &&
                    p.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                ) {
                    return true
                }
                p = p.parent
                depth++
            }
        } catch (_: Exception) {
        }
        return clickAtNodeCenter(node)
    }

    private fun clickAtNodeCenter(node: AccessibilityNodeInfo): Boolean {
        return try {
            val rect = Rect()
            node.getBoundsInScreen(rect)
            if (rect.width() <= 0 || rect.height() <= 0) return false
            clickAtInternal(
                rect.exactCenterX().toInt(),
                rect.exactCenterY().toInt()
            )
        } catch (_: Exception) {
            false
        }
    }

    // ⭐ clickAt — دلوقتي بيستنى الـ gesture ينتهي فعلاً
    private fun clickAtInternal(x: Int, y: Int): Boolean {
        return try {
            val path = Path().apply {
                moveTo(x.toFloat(), y.toFloat())
            }
            val stroke = GestureDescription.StrokeDescription(path, 0, 50)
            val gesture = GestureDescription.Builder()
                .addStroke(stroke)
                .build()

            val done = CountDownLatch(1)
            var success = false

            dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(g: GestureDescription?) {
                    success = true
                    done.countDown()
                }

                override fun onCancelled(g: GestureDescription?) {
                    done.countDown()
                }
            }, mainHandler)

            done.await(1500, TimeUnit.MILLISECONDS)
            success
        } catch (e: Exception) {
            Log.e(TAG, "clickAt failed", e)
            false
        }
    }

    // ⭐⭐ swipe — دلوقتي بيستنى الـ gesture ينتهي فعلاً + إصلاحات
    private fun swipeInternal(
        x1: Int,
        y1: Int,
        x2: Int,
        y2: Int,
        duration: Int
    ): Boolean {
        return try {
            // تأكد إن المسافة مش صغيرة أوي
            val dx = x2 - x1
            val dy = y2 - y1
            val distance = Math.sqrt((dx * dx + dy * dy).toDouble())
            if (distance < 30) {
                Log.w(TAG, "swipe: distance too small ($distance)")
                return false
            }

            // استخدم مسار فيه نقاط متعددة — أهم للـ scroll
            val path = Path().apply {
                moveTo(x1.toFloat(), y1.toFloat())
                // نقاط وسيطة لتنعيم الحركة
                val steps = 10
                for (i in 1..steps) {
                    val t = i.toFloat() / steps
                    lineTo(
                        x1 + dx * t,
                        y1 + dy * t
                    )
                }
            }

            val dur = duration.toLong().coerceIn(100L, 3000L)
            val stroke = GestureDescription.StrokeDescription(path, 0, dur)
            val gesture = GestureDescription.Builder()
                .addStroke(stroke)
                .build()

            val done = CountDownLatch(1)
            var success = false

            val dispatched = dispatchGesture(
                gesture,
                object : GestureResultCallback() {
                    override fun onCompleted(g: GestureDescription?) {
                        Log.d(TAG, "swipe: gesture completed")
                        success = true
                        done.countDown()
                    }

                    override fun onCancelled(g: GestureDescription?) {
                        Log.w(TAG, "swipe: gesture cancelled")
                        done.countDown()
                    }
                },
                mainHandler
            )

            if (!dispatched) {
                Log.w(TAG, "swipe: dispatchGesture returned false")
                return false
            }

            // استنى لحد 3 ثواني
            done.await(3000, TimeUnit.MILLISECONDS)

            Log.d(
                TAG,
                "swipe: ($x1,$y1) → ($x2,$y2) dur=$dur success=$success"
            )
            success
        } catch (e: Exception) {
            Log.e(TAG, "swipe failed", e)
            false
        }
    }

    // ⭐⭐ جديد: scroll بالـ Accessibility Action
    //       — مش محتاج Gesture خالص
    //       — أسرع وأخف من السحبة
    private fun scrollInternal(forward: Boolean): Boolean {
        return try {
            val all = collectAllNodes()
            // دوّر على أول scrollable node ظاهر
            val scrollable = all.firstOrNull { node ->
                try {
                    node.refresh()
                    node.isScrollable && node.isVisibleToUser
                } catch (_: Exception) {
                    false
                }
            }
            if (scrollable == null) {
                Log.w(TAG, "scroll: no scrollable node found")
                return false
            }
            val action = if (forward) {
                AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
            } else {
                AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
            }
            val ok = scrollable.performAction(action)
            Log.d(TAG, "scroll forward=$forward → $ok")
            ok
        } catch (e: Exception) {
            Log.e(TAG, "scroll failed", e)
            false
        }
    }

    private fun resolveCached(): AccessibilityNodeInfo? {
        return try {
            val n = lastEditableRef?.get()
            if (n != null && safeRefresh(n) &&
                n.isEditable && n.isVisibleToUser
            ) {
                n
            } else {
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun findFocusedInput(): AccessibilityNodeInfo? {
        try {
            val wins = windows
            if (!wins.isNullOrEmpty()) {
                for (w in wins) {
                    val root = w.root ?: continue
                    val f = root.findFocus(
                        AccessibilityNodeInfo.FOCUS_INPUT
                    )
                    if (f != null && safeRefresh(f) &&
                        f.isEditable && f.isVisibleToUser
                    ) {
                        return f
                    }
                }
            }
        } catch (_: Exception) {
        }
        return try {
            val root = rootInActiveWindow
            val f = root?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            if (f != null && safeRefresh(f) &&
                f.isEditable && f.isVisibleToUser
            ) {
                f
            } else {
                null
            }
        } catch (_: Exception) {
            null
        }
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
        } catch (_: Exception) {
        }
        val active = rootInActiveWindow ?: return null
        return findFirstEditable(active)
    }

    private fun findFirstEditable(
        node: AccessibilityNodeInfo?
    ): AccessibilityNodeInfo? {
        if (node == null) return null
        try {
            if (safeRefresh(node) && node.isEditable &&
                node.isVisibleToUser
            ) {
                return node
            }
        } catch (_: Exception) {
            return null
        }
        val cnt = try {
            node.childCount
        } catch (_: Exception) {
            0
        }
        for (i in 0 until cnt) {
            val c = try {
                node.getChild(i)
            } catch (_: Exception) {
                null
            } ?: continue
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