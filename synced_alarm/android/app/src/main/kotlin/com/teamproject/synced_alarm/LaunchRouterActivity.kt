package com.teamproject.synced_alarm

import android.app.Activity
import android.content.Intent
import android.os.Build
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
        val routeToAlarm = source.shouldRouteToAlarmActivity()
        val targetClass = if (routeToAlarm) {
            AlarmActivity::class.java
        } else {
            MainActivity::class.java
        }
        val target = Intent(this, targetClass).apply {
            if (!source.isLaunchedFromHistory()) {
                action = source?.action
                source?.extras?.let { putExtras(it) }
                data = source?.data
            }
            if (routeToAlarm) {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
        }
        startActivity(target)
        if (routeToAlarm && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            finishAndRemoveTask()
        } else {
            finish()
        }
    }

    private fun Intent?.shouldRouteToAlarmActivity(): Boolean {
        if (this == null) return false
        return LaunchRouteDecision.shouldRouteToAlarmActivity(
            action = action,
            hasPayload = hasExtra("payload"),
            flags = flags,
        )
    }

    private fun Intent?.isLaunchedFromHistory(): Boolean {
        if (this == null) return false
        return LaunchRouteDecision.isLaunchedFromHistory(flags)
    }
}
