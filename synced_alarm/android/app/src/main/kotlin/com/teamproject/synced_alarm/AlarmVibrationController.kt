package com.teamproject.synced_alarm

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

object AlarmVibrationController {
    private val handler = Handler(Looper.getMainLooper())
    private val stopRunnable = Runnable { stop() }
    private var vibrator: Vibrator? = null

    @Synchronized
    fun start(context: Context, vibrationEnabled: Boolean, durationMillis: Long) {
        stop()
        if (!vibrationEnabled) return

        val activeVibrator = context.applicationContext.alarmVibrator() ?: return
        if (!activeVibrator.hasVibrator()) return

        val safeDurationMillis = durationMillis.coerceIn(
            MIN_DURATION_MILLIS,
            MAX_DURATION_MILLIS,
        )
        val pattern = longArrayOf(0L, 700L, 300L, 700L, 900L)
        vibrator = activeVibrator

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = VibrationEffect.createWaveform(pattern, 1)
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .build()
            activeVibrator.vibrate(effect, attributes)
        } else {
            @Suppress("DEPRECATION")
            activeVibrator.vibrate(pattern, 1)
        }
        handler.postDelayed(stopRunnable, safeDurationMillis)
    }

    @Synchronized
    fun stop() {
        handler.removeCallbacks(stopRunnable)
        vibrator?.cancel()
        vibrator = null
    }

    private fun Context.alarmVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private const val MIN_DURATION_MILLIS = 1_000L
    private const val MAX_DURATION_MILLIS = 60L * 60L * 1000L
}
