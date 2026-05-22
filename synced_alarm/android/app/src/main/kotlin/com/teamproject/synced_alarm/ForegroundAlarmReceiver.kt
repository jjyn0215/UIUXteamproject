package com.teamproject.synced_alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ForegroundAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != SyncedAlarmFlutterActivity.ACTION_FOREGROUND_ALARM_TRIGGER) {
            return
        }
        if (!SyncedAlarmFlutterActivity.shouldRouteForegroundAlarmToFlutter()) {
            return
        }

        val payload = intent.getStringExtra(SyncedAlarmFlutterActivity.EXTRA_ALARM_PAYLOAD)
        if (payload.isNullOrBlank()) return

        val target = Intent(context, MainActivity::class.java).apply {
            action = SyncedAlarmFlutterActivity.ACTION_ALARM_TRIGGER
            putExtra(SyncedAlarmFlutterActivity.EXTRA_ALARM_PAYLOAD, payload)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        context.startActivity(target)
    }
}
