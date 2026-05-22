package com.teamproject.synced_alarm

import android.app.Activity
import android.content.Intent
import android.os.Bundle

class LaunchRouterActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        route(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        route(intent)
    }

    private fun route(source: Intent?) {
        val targetClass = if (source.isAlarmNotificationLaunch()) {
            AlarmActivity::class.java
        } else {
            MainActivity::class.java
        }
        val target = Intent(this, targetClass).apply {
            action = source?.action
            source?.extras?.let { putExtras(it) }
            data = source?.data
            if (targetClass == AlarmActivity::class.java) {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
        }
        startActivity(target)
        finish()
    }

    private fun Intent?.isAlarmNotificationLaunch(): Boolean {
        if (this == null) return false
        return action == "SELECT_NOTIFICATION" && hasExtra("payload")
    }
}
