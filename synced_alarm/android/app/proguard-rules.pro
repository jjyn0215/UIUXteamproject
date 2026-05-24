# Flutter local notifications 플러그인의 클래스들이 난독화되거나 최적화 과정에서 제거되지 않도록 유지합니다.
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# 알람 및 진동 제어, 화면 켜기 분기를 담당하는 우리 앱의 모든 네이티브 Kotlin 클래스들을 보존합니다.
# R8 난독화로 인해 AndroidManifest.xml에 등록된 액티비티나 리시버 클래스명이 바뀜으로써 발생하는
# PendingIntent / ActivityNotFound 오류를 방지합니다.
-keep class com.teamproject.synced_alarm.MainActivity { *; }
-keep class com.teamproject.synced_alarm.AlarmActivity { *; }
-keep class com.teamproject.synced_alarm.LaunchRouterActivity { *; }
-keep class com.teamproject.synced_alarm.ForegroundAlarmReceiver { *; }
-keep class com.teamproject.synced_alarm.ForegroundAlarmScheduler { *; }
-keep class com.teamproject.synced_alarm.AlarmVibrationController { *; }
-keep class com.teamproject.synced_alarm.LaunchRouteDecision { *; }
-keep class com.teamproject.synced_alarm.SyncedAlarmFlutterActivity { *; }

# 일반적인 Androidx 및 Kotlin 기본 규칙 유지
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Firebase Messaging (FCM) 백그라운드 수신용 설정 보존
-keep class com.google.firebase.messaging.** { *; }
