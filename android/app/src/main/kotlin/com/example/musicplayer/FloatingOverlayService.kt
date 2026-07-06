package com.example.musicplayer

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.view.animation.LinearInterpolator
import java.net.URL
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper

class FloatingOverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var floatingView: LinearLayout? = null
    private var isPlaying = false
    private var rotationAnimator: ObjectAnimator? = null
    private var albumArtView: ImageView? = null

    private val handler = Handler(Looper.getMainLooper())
    private val visibilityRunnable = object : Runnable {
        override fun run() {
            updateVisibilityBasedOnForeground()
            handler.postDelayed(this, 800)
        }
    }

    override fun onCreate() {
        super.onCreate()
        handler.post(visibilityRunnable)
    }

    companion object {
        var isAppVisible = false
        const val ACTION_TOGGLE = "com.musicplayer.TOGGLE"
        const val ACTION_PREV = "com.musicplayer.PREV"
        const val ACTION_NEXT = "com.musicplayer.NEXT"
        const val ACTION_SEEK = "com.musicplayer.SEEK"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            val title = intent.getStringExtra("title") ?: "Unknown Title"
            val artist = intent.getStringExtra("artist") ?: "Unknown Artist"
            val artworkUrl = intent.getStringExtra("artworkUrl") ?: ""
            isPlaying = intent.getBooleanExtra("isPlaying", false)

            if (floatingView == null) {
                createFloatingWindow(title, artist, artworkUrl)
            } else {
                updateFloatingWindow(title, artist, artworkUrl)
            }
        }
        return START_NOT_STICKY
    }

    private fun createFloatingWindow(title: String, artist: String, artworkUrl: String) {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val density = resources.displayMetrics.density

        // Root Capsule view
        floatingView = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((16 * density).toInt(), (8 * density).toInt(), (16 * density).toInt(), (8 * density).toInt())

            // Rounded capsule background
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 20 * density
                setColor(Color.parseColor("#0F0F10"))
                setStroke((1.5 * density).toInt(), Color.parseColor("#E0E0E0"))
            }
        }

        // Album Art
        albumArtView = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams((32 * density).toInt(), (32 * density).toInt())
            setImageResource(android.R.drawable.ic_media_play) // Fallback
        }
        floatingView?.addView(albumArtView)

        // Title and Artist column
        val textContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val params = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
            params.setMargins((12 * density).toInt(), 0, (12 * density).toInt(), 0)
            layoutParams = params
        }

        val titleView = TextView(this).apply {
            text = title
            setTextColor(Color.WHITE)
            textSize = 12f
            maxLines = 1
        }
        val artistView = TextView(this).apply {
            text = artist
            setTextColor(Color.parseColor("#AAAAAA"))
            textSize = 9f
            maxLines = 1
        }
        textContainer.addView(titleView)
        textContainer.addView(artistView)
        floatingView?.addView(textContainer)

        // Play/Pause button
        val playButton = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams((28 * density).toInt(), (28 * density).toInt())
            setImageResource(if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)
            setColorFilter(Color.WHITE)
            setOnClickListener {
                sendBroadcast(Intent(ACTION_TOGGLE))
            }
        }
        floatingView?.addView(playButton)

        // Drag layout params
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            x = 0
            y = 100
        }

        // Drag handler
        floatingView?.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f

            override fun onTouch(v: View?, event: MotionEvent?): Boolean {
                if (event == null) return false
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        params.x = initialX + (event.rawX - initialTouchX).toInt()
                        params.y = initialY + (event.rawY - initialTouchY).toInt()
                        try {
                            windowManager?.updateViewLayout(floatingView, params)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                        return true
                    }
                }
                return false
            }
        })

        // Add to window safely (catches window manager permission issues)
        try {
            windowManager?.addView(floatingView, params)
        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
            return
        }

        // Setup rotation & image loading
        setupRotationAnimator()
        loadArtwork(artworkUrl)
    }

    private fun updateFloatingWindow(title: String, artist: String, artworkUrl: String) {
        val root = floatingView ?: return
        try {
            val textContainer = root.getChildAt(1) as LinearLayout
            val titleView = textContainer.getChildAt(0) as TextView
            val artistView = textContainer.getChildAt(1) as TextView
            val playButton = root.getChildAt(2) as ImageView

            titleView.text = title
            artistView.text = artist
            playButton.setImageResource(if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)

            if (isPlaying) {
                rotationAnimator?.resume()
            } else {
                rotationAnimator?.pause()
            }

            loadArtwork(artworkUrl)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun setupRotationAnimator() {
        val view = albumArtView ?: return
        rotationAnimator = ObjectAnimator.ofFloat(view, "rotation", 0f, 360f).apply {
            duration = 10000
            repeatCount = ValueAnimator.INFINITE
            interpolator = LinearInterpolator()
        }
        rotationAnimator?.start()
        if (!isPlaying) {
            rotationAnimator?.pause()
        }
    }

    private fun loadArtwork(url: String) {
        if (url.isEmpty()) return
        Thread {
            try {
                val connection = URL(url).openConnection()
                connection.connectTimeout = 3000
                connection.readTimeout = 3000
                val input = connection.getInputStream()
                val bitmap = BitmapFactory.decodeStream(input)
                Handler(Looper.getMainLooper()).post {
                    if (bitmap != null) {
                        albumArtView?.setImageBitmap(bitmap)
                    }
                }
            } catch (e: Exception) {
                // Ignore image fetch errors
            }
        }.start()
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(visibilityRunnable)
        rotationAnimator?.cancel()
        if (floatingView != null) {
            try {
                windowManager?.removeView(floatingView)
            } catch (e: Exception) {
                e.printStackTrace()
            }
            floatingView = null
        }
    }

    private fun updateVisibilityBasedOnForeground() {
        val view = floatingView ?: return
        val context = this
        
        if (isAppVisible) {
            view.visibility = View.GONE
            return
        }
        
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        var shouldShow = true // Default to true if in background so it always shows on Home Screen
        
        try {
            val tasks = am.getRunningTasks(1)
            if (tasks != null && tasks.isNotEmpty()) {
                val topActivity = tasks[0].topActivity
                val topPackage = topActivity?.packageName
                
                if (topPackage != null && topPackage != context.packageName) {
                    val intent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                    }
                    val resolveInfo = context.packageManager.resolveActivity(intent, 0)
                    val launcherPackage = resolveInfo?.activityInfo?.packageName
                    
                    if (launcherPackage != null && topPackage != launcherPackage) {
                        shouldShow = false
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            shouldShow = true
        }
        
        view.visibility = if (shouldShow) View.VISIBLE else View.GONE
    }
}
