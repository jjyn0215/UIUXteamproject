package com.teamproject.synced_alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object ForegroundAlarmScheduler {
    private const val PREFS_NAME = "synced_alarm_foreground_triggers"
    private const val PREF_IDS = "ids"

    fun schedule(context: Context, arguments: Any?) {
        val requests = arguments as? List<*> ?: return
        val alarmManager = alarmManager(context)
        val ids = storedIds(context)

        for (rawRequest in requests) {
            val request = rawRequest as? Map<*, *> ?: continue
            val id = (request["id"] as? Number)?.toInt() ?: continue
            val triggerAtMillis = (request["triggerAtMillis"] as? Number)?.toLong() ?: continue
            val payload = request["payload"] as? String ?: continue
            val operation = pendingIntent(
                context,
                id,
                payload,
                PendingIntent.FLAG_UPDATE_CURRENT,
            ) ?: continue
            scheduleAlarm(alarmManager, triggerAtMillis, operation)
            ids.add(id.toString())
        }

        saveIds(context, ids)
    }

    fun cancel(context: Context, arguments: Any?) {
        val rawIds = arguments as? List<*> ?: return
        val ids = storedIds(context)
        for (rawId in rawIds) {
            val id = (rawId as? Number)?.toInt() ?: continue
            cancelOne(context, id)
            ids.remove(id.toString())
        }
        saveIds(context, ids)
    }

    fun cancelAll(context: Context) {
        val ids = storedIds(context)
        for (id in ids) {
            id.toIntOrNull()?.let { cancelOne(context, it) }
        }
        saveIds(context, mutableSetOf())
    }

    private fun scheduleAlarm(
        alarmManager: AlarmManager,
        triggerAtMillis: Long,
        operation: PendingIntent,
    ) {
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !alarmManager.canScheduleExactAlarms() -> {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    operation,
                )
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    operation,
                )
            }
            else -> {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, operation)
            }
        }
    }

    private fun cancelOne(context: Context, id: Int) {
        val operation = pendingIntent(context, id, null, PendingIntent.FLAG_NO_CREATE)
        if (operation != null) {
            alarmManager(context).cancel(operation)
        }
    }

    private fun pendingIntent(
        context: Context,
        id: Int,
        payload: String?,
        pendingIntentFlag: Int,
    ): PendingIntent? {
        val intent = Intent(context, ForegroundAlarmReceiver::class.java).apply {
            action = SyncedAlarmFlutterActivity.ACTION_FOREGROUND_ALARM_TRIGGER
            if (payload != null) {
                putExtra(SyncedAlarmFlutterActivity.EXTRA_ALARM_PAYLOAD, payload)
            }
        }
        val immutableFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
        return PendingIntent.getBroadcast(context, id, intent, pendingIntentFlag or immutableFlag)
    }

    private fun alarmManager(context: Context): AlarmManager {
        return context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    }

    private fun storedIds(context: Context): MutableSet<String> {
        return context
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getStringSet(PREF_IDS, emptySet())
            ?.toMutableSet() ?: mutableSetOf()
    }

    private fun saveIds(context: Context, ids: MutableSet<String>) {
        context
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putStringSet(PREF_IDS, ids)
            .apply()
    }
}
