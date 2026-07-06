package com.example.musicplayer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.musicplayer.pip"
    private var methodChannel: MethodChannel? = null

    private val toggleReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                FloatingOverlayService.ACTION_TOGGLE -> methodChannel?.invokeMethod("togglePlayPause", null)
                FloatingOverlayService.ACTION_PREV -> methodChannel?.invokeMethod("skipPrev", null)
                FloatingOverlayService.ACTION_NEXT -> methodChannel?.invokeMethod("skipNext", null)
                FloatingOverlayService.ACTION_SEEK -> {
                    val seekMs = intent.getLongExtra("seekPosition", 0)
                    methodChannel?.invokeMethod("seekTo", seekMs)
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setHighRefreshRate()
    }

    private fun setHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                window.windowManager.defaultDisplay?.let { display ->
                    val modes = display.supportedModes
                    val highRefreshMode = modes.maxByOrNull { it.refreshRate }
                    if (highRefreshMode != null) {
                        val params = window.attributes
                        if (params.preferredDisplayModeId != highRefreshMode.modeId) {
                            params.preferredDisplayModeId = highRefreshMode.modeId
                            window.attributes = params
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val params = window.attributes
                if (params.preferredRefreshRate != 120f) {
                    params.preferredRefreshRate = 120f
                    window.attributes = params
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "showOverlay" -> {
                        val title = call.argument<String>("title") ?: ""
                        val artist = call.argument<String>("artist") ?: ""
                        val artworkUrl = call.argument<String>("artworkUrl") ?: ""
                        val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                        showOverlayWindow(title, artist, artworkUrl, isPlaying)
                        result.success(true)
                    }
                    "updatePosition" -> {
                        val position = (call.argument<Number>("position") ?: 0).toLong()
                        val duration = (call.argument<Number>("duration") ?: 0).toLong()
                        updateOverlayPosition(position, duration)
                        result.success(true)
                    }
                    "hideOverlay" -> {
                        hideOverlayWindow()
                        result.success(true)
                    }
                    "checkOverlayPermission" -> {
                        val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.canDrawOverlays(this@MainActivity)
                        } else true
                        result.success(hasPermission)
                    }
                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this@MainActivity)) {
                            try {
                                startActivityForResult(
                                    Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")),
                                    1234
                                )
                            } catch (e: Exception) {
                                try { startActivityForResult(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION), 1234) }
                                catch (e2: Exception) { e2.printStackTrace() }
                            }
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(FloatingOverlayService.ACTION_TOGGLE)
            addAction(FloatingOverlayService.ACTION_PREV)
            addAction(FloatingOverlayService.ACTION_NEXT)
            addAction(FloatingOverlayService.ACTION_SEEK)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(toggleReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(toggleReceiver, filter)
        }
    }

    private fun showOverlayWindow(title: String, artist: String, artworkUrl: String, isPlaying: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) return
        startService(Intent(this, FloatingOverlayService::class.java).apply {
            putExtra("title", title); putExtra("artist", artist)
            putExtra("artworkUrl", artworkUrl); putExtra("isPlaying", isPlaying)
        })
    }

    private fun updateOverlayPosition(position: Long, duration: Long) {
        startService(Intent(this, FloatingOverlayService::class.java).apply {
            action = "UPDATE_POSITION"
            putExtra("position", position); putExtra("duration", duration)
        })
    }

    private fun hideOverlayWindow() {
        stopService(Intent(this, FloatingOverlayService::class.java))
    }

    override fun onResume() {
        super.onResume()
        FloatingOverlayService.isAppVisible = true
        setHighRefreshRate()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        setHighRefreshRate()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            setHighRefreshRate()
        }
    }

    override fun onPause() {
        super.onPause()
        FloatingOverlayService.isAppVisible = false
    }

    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(toggleReceiver) } catch (e: Exception) {}
    }
}
