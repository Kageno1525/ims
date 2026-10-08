package com.kageno.ims

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

class FloatingService : Service() {

    companion object {
        @Volatile
        var onClick: (() -> Unit)? = null

        private var instance: FloatingService? = null

        fun updateText(text: String) {
            instance?.setText(text)
        }
    }

    private var windowManager: WindowManager? = null
    private var view: View? = null
    private var textView: TextView? = null
    private var params: WindowManager.LayoutParams? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "SHOW" -> show()
            "HIDE" -> {
                hide()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun show() {
        if (view != null) return

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val type = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 40
            y = 300
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(36, 22, 36, 22)
        }

        val bg = GradientDrawable().apply {
            cornerRadius = 60f
            setColor(0xFF6C5CE7.toInt())
        }
        container.background = bg

        textView = TextView(this).apply {
            text = "—"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 15f
            gravity = Gravity.CENTER
            setPadding(10, 4, 10, 4)
        }
        container.addView(textView)

        view = container

        try {
            windowManager?.addView(view, params)
        } catch (e: Exception) {
            view = null
            return
        }

        attachTouch()
        instance = this
    }

    private fun attachTouch() {
        view?.setOnTouchListener(object : View.OnTouchListener {
            var initX = 0
            var initY = 0
            var touchX = 0f
            var touchY = 0f
            var moved = false
            var downTime = 0L

            override fun onTouch(v: View, e: MotionEvent): Boolean {
                when (e.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initX = params?.x ?: 0
                        initY = params?.y ?: 0
                        touchX = e.rawX
                        touchY = e.rawY
                        moved = false
                        downTime = System.currentTimeMillis()
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (e.rawX - touchX).toInt()
                        val dy = (e.rawY - touchY).toInt()
                        if (abs(dx) > 10 || abs(dy) > 10) moved = true
                        params?.let {
                            it.x = initX + dx
                            it.y = initY + dy
                            try { windowManager?.updateViewLayout(view, it) } catch (_: Exception) {}
                        }
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (!moved && System.currentTimeMillis() - downTime < 600) {
                            onClick?.invoke()
                        }
                        return true
                    }
                }
                return false
            }
        })
    }

    private fun setText(text: String) {
        textView?.post { textView?.text = text }
    }

    private fun hide() {
        view?.let {
            try { windowManager?.removeView(it) } catch (_: Exception) {}
        }
        view = null
        textView = null
        instance = null
    }

    override fun onDestroy() {
        hide()
        super.onDestroy()
    }
}