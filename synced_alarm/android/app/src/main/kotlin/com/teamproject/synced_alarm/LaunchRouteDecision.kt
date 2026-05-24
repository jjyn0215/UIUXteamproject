package com.teamproject.synced_alarm

import android.content.Intent

object LaunchRouteDecision {
    const val selectNotificationAction = "SELECT_NOTIFICATION"
    val launchedFromHistoryFlag: Int = Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY

    fun shouldRouteToAlarmActivity(
        action: String?,
        hasPayload: Boolean,
        flags: Int,
    ): Boolean {
        if (isLaunchedFromHistory(flags)) return false
        return action == selectNotificationAction && hasPayload
    }

    fun isLaunchedFromHistory(flags: Int): Boolean {
        return flags and launchedFromHistoryFlag != 0
    }
}
