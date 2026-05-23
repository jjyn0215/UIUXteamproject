package com.teamproject.synced_alarm

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager

class AlarmActivity : SyncedAlarmFlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableAlarmPresentation()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        enableAlarmPresentation()
    }

    override fun finishAlarmPresentation(): Boolean {
        AlarmVibrationController.stop()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            finishAndRemoveTask()
        } else {
            finish()
        }
        return true
    }

    override fun onDestroy() {
        AlarmVibrationController.stop()
        super.onDestroy()
    }

    private fun enableAlarmPresentation() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
