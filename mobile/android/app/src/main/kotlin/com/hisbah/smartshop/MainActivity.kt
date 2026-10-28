package com.hisbah.smartshop

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /// One short tone after a good barcode read. The notification stream follows the phone's
    /// silent / vibrate mode, so a muted phone stays quiet. Created lazily, released with the activity.
    private var tone: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hisbah/scan_feedback").setMethodCallHandler { call, result ->
            if (call.method != "beep") return@setMethodCallHandler result.notImplemented()
            try {
                val generator = tone ?: ToneGenerator(AudioManager.STREAM_NOTIFICATION, 60).also { tone = it }
                generator.startTone(ToneGenerator.TONE_PROP_BEEP, 90)
            } catch (_: RuntimeException) {
                // No audio route (or the generator failed to start): the haptic and pulse still play.
                tone = null
            }
            result.success(null)
        }
    }

    override fun onDestroy() {
        tone?.release()
        tone = null
        super.onDestroy()
    }
}
