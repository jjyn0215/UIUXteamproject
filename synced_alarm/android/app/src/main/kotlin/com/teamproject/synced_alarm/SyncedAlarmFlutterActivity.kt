package com.teamproject.synced_alarm

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

open class SyncedAlarmFlutterActivity : FlutterActivity() {
    private val alarmTaskChannel = "com.teamproject.synced_alarm/alarm_task"
    private val alarmTriggerChannelName = "com.teamproject.synced_alarm/alarm_trigger"
    private val alarmSchedulerChannelName = "com.teamproject.synced_alarm/alarm_scheduler"
    private var alarmTriggerChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleAlarmTriggerIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            alarmTaskChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "moveTaskToBack" -> {
                    moveTaskToBack(true)
                    result.success(true)
                }
                "finishAlarmPresentation" -> {
                    AlarmVibrationController.stop()
                    result.success(finishAlarmPresentation())
                }
                "startAlarmVibration" -> {
                    val args = call.arguments as? Map<*, *>
                    val vibrationEnabled = args
                        ?.get("vibrationEnabled") as? Boolean ?: true
                    val ringDurationMillis = (args
                        ?.get("ringDurationMillis") as? Number)
                        ?.toLong() ?: DEFAULT_RING_DURATION_MILLIS
                    AlarmVibrationController.start(
                        applicationContext,
                        vibrationEnabled,
                        ringDurationMillis,
                    )
                    result.success(true)
                }
                "stopAlarmVibration" -> {
                    AlarmVibrationController.stop()
                    result.success(true)
                }
                "openNotificationSettings" -> {
                    val intent = Intent().apply {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                            data = Uri.fromParts("package", packageName, null)
                        }
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open notification settings", e.message)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            alarmTriggerChannelName,
        ).also { channel ->
            alarmTriggerChannel = channel
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumePendingAlarmTrigger" -> {
                        result.success(consumePendingAlarmTriggerPayload())
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            alarmSchedulerChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleForegroundTriggers" -> {
                    ForegroundAlarmScheduler.schedule(this, call.arguments)
                    result.success(true)
                }
                "cancelForegroundTriggers" -> {
                    ForegroundAlarmScheduler.cancel(this, call.arguments)
                    result.success(true)
                }
                "cancelAllForegroundTriggers" -> {
                    ForegroundAlarmScheduler.cancelAll(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onStart() {
        super.onStart()
        if (isMainActivity()) {
            isMainActivityVisible = true
        }
    }

    override fun onStop() {
        if (isMainActivity()) {
            isMainActivityVisible = false
        }
        super.onStop()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAlarmTriggerIntent(intent)
    }

    protected open fun finishAlarmPresentation(): Boolean {
        return false
    }

    private fun isMainActivity(): Boolean {
        return javaClass.name == MainActivity::class.java.name
    }

    private fun handleAlarmTriggerIntent(source: Intent?) {
        if (source?.action != ACTION_ALARM_TRIGGER) return
        val payload = source.getStringExtra(EXTRA_ALARM_PAYLOAD)
        if (payload.isNullOrBlank()) return
        pendingAlarmTriggerPayload = payload
        alarmTriggerChannel?.invokeMethod(
            "alarmTriggered",
            payload,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (pendingAlarmTriggerPayload == payload) {
                        pendingAlarmTriggerPayload = null
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit

                override fun notImplemented() = Unit
            },
        )
    }

    companion object {
        const val ACTION_ALARM_TRIGGER = "com.teamproject.synced_alarm.ALARM_TRIGGER"
        const val ACTION_FOREGROUND_ALARM_TRIGGER =
            "com.teamproject.synced_alarm.FOREGROUND_ALARM_TRIGGER"
        const val EXTRA_ALARM_PAYLOAD = "alarm_payload"
        private const val DEFAULT_RING_DURATION_MILLIS = 5L * 60L * 1000L

        @Volatile
        private var isMainActivityVisible: Boolean = false

        @Volatile
        private var pendingAlarmTriggerPayload: String? = null

        fun shouldRouteForegroundAlarmToFlutter(): Boolean {
            return isMainActivityVisible
        }

        private fun consumePendingAlarmTriggerPayload(): String? {
            val payload = pendingAlarmTriggerPayload
            pendingAlarmTriggerPayload = null
            return payload
        }
    }
}
