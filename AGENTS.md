# Repository Guidelines

## 문서 운영 원칙

이 저장소의 단일 기준 문서는 `AGENTS.md`입니다. 별도 AI 인계 문서나 프로젝트 기준 문서를 만들지 말고, 구조·Firebase·디자인·플랫폼 범위·남은 작업이 바뀌면 이 파일을 먼저 갱신하세요. `README.md`는 빠른 실행 진입점만 담당합니다.

## 역할 부여

당신은 Flutter와 Dart 생태계에 정통하고, Android 우선 모바일 앱 개발과 이후 Web/Linux/Windows 확장 설계 경험이 풍부한 **시니어 Full-stack Dart 개발자**이자 **DevOps 엔지니어**입니다.


## 프로젝트 목표

1차 목표는 Android에서 알람 생성, 동기화, 푸시, 로컬 알림을 안정적으로 구현하는 **'Android 우선 실시간 동기화 알람 앱'**입니다. Web, Linux, Windows는 Android 기본 구현이 끝난 뒤 확장 구현 계획에 포함합니다.

## 프로젝트 구조

- `synced_alarm/`: Flutter 앱 루트
- `synced_alarm/lib/main.dart`: 앱 진입점
- `synced_alarm/lib/firebase_options.dart`: FlutterFire Firebase client config
- `synced_alarm/lib/src/app/`: 앱 셸과 `MaterialApp`
- `synced_alarm/lib/src/data/`: repository 추상화, 로컬 데모/Firebase 구현
- `synced_alarm/lib/src/design/`: Stitch 기반 테마 토큰
- `synced_alarm/lib/src/features/`: 알람, 설정 등 기능 UI
- `synced_alarm/lib/src/models/`: 알람, 명령, 기기 등록 모델
- `synced_alarm/test/`: Flutter widget test
- `synced_alarm/functions/`: Firebase Cloud Functions
- `synced_alarm/firestore.rules`: Firestore 보안 규칙

## 아키텍처 기준

기본 구현 목표는 Android에서 Firebase 기반 알람 MVP를 완성하는 것입니다. Web, Linux, Windows는 기본 구현 완료 후 같은 Firestore 구조를 재사용하는 확장 구현으로 다룹니다. 직접 운영 백엔드, Serverpod, PostgreSQL, K3s, Tailscale은 현재 범위에서 제외합니다. Firebase 제품은 Anonymous Auth, Cloud Firestore, FCM, 최소 Cloud Functions만 사용합니다.

기본 실행은 Firebase 없이 `LocalDemoAlarmRepository`를 쓰는 로컬 데모 모드입니다. 현재 Firebase 프로젝트는 `alarm-b70d1`로 연결되어 있으며, Firebase 모드는 `USE_FIREBASE=true`로 켭니다. 위젯은 Firebase를 직접 호출하지 말고 `AlarmRepository`와 controller를 통해 상태를 변경하세요.

Firestore 구조:

```text
groups/{groupId}
groups/{groupId}/members/{uid}
groups/{groupId}/alarms/{alarmId}
groups/{groupId}/devices/{deviceId}
groups/{groupId}/commands/{commandId}
```

핵심 Functions는 `joinGroup`, `onAlarmWrite`, `onCommandCreate`, `cleanupInvalidTokens`입니다.

기기 등록은 `FirebaseDeviceRegistrar`가 담당합니다. 기본 구현에서는 Android FCM 토큰을 `groups/{groupId}/devices/{deviceId}`에 저장합니다. Web FCM, Linux/Windows 실행 중 Firestore 동기화용 기기 문서는 확장 구현 단계에서 검증합니다.

## 빌드, 테스트, 실행 명령

앱 명령은 `synced_alarm/`에서 실행합니다.

```bash
/home/devuser/flutter/bin/flutter pub get
/home/devuser/flutter/bin/flutter run -d <android-device-id>
/home/devuser/flutter/bin/dart format .
/home/devuser/flutter/bin/flutter analyze
/home/devuser/flutter/bin/flutter test
/home/devuser/flutter/bin/flutter build apk --debug
```

확장 플랫폼 검증이 필요할 때만 다음 명령을 추가로 실행합니다.

```bash
/home/devuser/flutter/bin/flutter run -d chrome
/home/devuser/flutter/bin/flutter build web
```

Functions 검증:

```bash
cd synced_alarm/functions
npm run lint
npm audit --omit=dev
```

Firebase 모드 실행:

```bash
cd synced_alarm
/home/devuser/flutter/bin/flutter run -d <android-device-id> \
  --dart-define=USE_FIREBASE=true \
  --dart-define=ALARM_GROUP_ID=demo \
  --dart-define=ALARM_ACCESS_CODE=<secret> \
  --dart-define=ALARM_DEVICE_ID=<device-id>
```

Firebase Emulator를 쓸 때는 다음 플래그를 추가합니다.

```bash
--dart-define=USE_FIREBASE_EMULATOR=true \
--dart-define=FIREBASE_EMULATOR_HOST=localhost
```

Android 에뮬레이터에서 Firebase Emulator를 볼 때는 host를 `10.0.2.2`로 바꿉니다. Web FCM의 `FIREBASE_MESSAGING_VAPID_KEY`는 확장 구현 단계에서 Web을 검증할 때 추가합니다.

Firebase 프로젝트를 다시 생성하거나 앱 ID를 바꾸는 경우에만 다음 명령으로 client config를 재생성합니다.

```bash
PATH="$PATH:/home/devuser/flutter/bin:$HOME/.pub-cache/bin" flutterfire configure
```

## 코딩 스타일

Dart 코드는 `flutter_lints`와 `dart format`을 기준으로 합니다. 클래스와 위젯은 `PascalCase`, 변수와 메서드는 `camelCase`, 파일명은 `snake_case.dart`를 사용합니다. 기능별 UI는 `src/features/` 아래에 두고, 공유 모델은 `src/models/`, 데이터 접근은 `src/data/`에 둡니다.

## 테스트 규칙

테스트 프레임워크는 `flutter_test`입니다. 테스트 이름은 사용자에게 보이는 동작 기준으로 작성합니다. 예: `shows the alarm list shell`. 동기화, 명령 처리, repository 로직을 바꾸면 widget test 또는 unit test를 추가하세요. 작업 마무리 전 최소 `dart format .`, `flutter analyze`, `flutter test`를 실행합니다.

## 디자인 기준

Stitch 프로젝트 `projects/15792280768664650353`이 UI 기준입니다. 현재 구현은 실제 Stitch HTML의 그린 토큰을 우선합니다.

- 메인 화면: `screens/1ff8c69e0b1845f0972eca850ab77eaa`
- 설정 화면: `screens/3bb9b682726b465abe7accaa3183e0ba`
- Primary: `#386948`
- Primary container: `#b9efc5`
- Background: `#f7faf4`
- Surface: `#ffffff`
- Text: `#2c342e`
- Flutter page margin: `20px`
- Card radius: `12px`-`16px`

UI를 바꿀 때는 알람 카드, 하단 탭, FAB, 설정 카드의 구조를 Stitch 기준에서 크게 벗어나지 않게 유지합니다.

## 플랫폼 제약

기본 구현의 플랫폼 대상은 Android입니다. Android는 FCM 수신, 로컬 알림, 사운드, 알람 제어를 우선 검증합니다. Web, Linux, Windows는 확장 구현 대상이며, Web은 FCM/Notification API를 별도로 검증하고 Linux/Windows는 앱 실행 중 Firestore listener 기반 동기화와 로컬 알림을 검증합니다. `firebase_messaging`은 Windows/Linux 네이티브 FCM 수신 경로로 사용하지 않습니다. Linux 빌드는 `cmake`가 필요하고, Windows 빌드는 Windows 호스트에서 검증해야 합니다.

## 보안과 설정

access code, service account, secret 파일은 커밋하지 않습니다. Firebase client config인 `firebase_options.dart`와 `android/app/google-services.json`은 제출/협업 정책에 맞춰 포함 여부를 결정하되, 서비스 계정 키처럼 비밀값으로 취급하지 않습니다. access code는 클라이언트 코드가 아니라 Firebase Functions secret으로 관리합니다. Firestore rules는 `members/{uid}`가 있는 사용자만 그룹 데이터에 접근하게 해야 합니다.

## 현재 상태와 남은 작업

완료: Flutter 프로젝트 생성, Android 우선 로컬 데모 앱 흐름, 확장 대비 Web/Linux/Windows 타깃 scaffold, Stitch 기반 UI, Firestore rules 초안, Functions 초안, Android desugaring 설정, Firebase 초기화 대기 흐름, Firebase 작업 timeout/error 표시, Emulator 연결 플래그, Android FCM 토큰 기기 등록 scaffold, foreground/background FCM handler scaffold, Android 중심 로컬 알림 서비스 scaffold, Android 로컬 예약 알림 scheduling 연결 및 AndroidManifest 예약 권한/리시버 설정, notification action 처리를 위한 AndroidManifest `ActionBroadcastReceiver` 등록, Android 알람 전용 ringing 채널(`synced_alarm_ringing_v2`)과 반복 사운드 플래그/full-screen intent 설정, 매일 반복 예약과 스누즈 1회 예약 분리, Firebase 알람 동기화 데이터 메시지(`alarm.created`, `alarm.updated`, `alarm.deleted`, `alarm.command`)의 사용자 알림 미표시 처리 및 silent sync 채널 분리, 알람 notification payload의 앱 내부 실행 이벤트 파싱, notification/full-screen intent로 앱이 열릴 때 전용 `AlarmRingScreen` 표시, 시스템 알림의 `Snooze`/`Dismiss` 액션 버튼과 앱 내부 처리 연결, notification action background callback 등록 및 액션 클릭 시 앱 UI 비표시 처리, background callback의 로컬 취소/재예약 작업 await 처리, background `Dismiss` 로컬 취소와 `Snooze` 5분 재예약, notification action 자동 알림 닫힘 처리, full-screen 알람 화면 버튼 처리 후 Android task를 뒤로 보내는 native method channel, 알람 화면 액션 성공/실패와 관계없이 task 뒤로 보내기 보장, notification launch/action 이후 같은 알람 tick 재울림 방지, Android `MainActivity` 잠금화면 표시/화면 켜기 플래그 설정, FCM 지원 플랫폼 정책 테스트, FlutterFire Firebase 프로젝트 연결(`alarm-b70d1`), Anonymous Auth 활성화 확인, Firestore 기본 DB 생성 및 rules 배포, `GROUP_ACCESS_CODE` Functions secret 설정, Cloud Functions 4개 배포(`joinGroup`, `onAlarmWrite`, `onCommandCreate`, `cleanupInvalidTokens`), callable Functions invoker IAM 설정, Artifact Registry cleanup policy 설정, `flutter build apk --debug`. Web service worker와 Web 빌드 scaffold는 확장 구현 대비 상태입니다.

남음: Emulator Suite rules/functions 테스트, Android 실제 기기 FCM 수신 검증, Android 예약 알림의 실제 소리/진동/잠금화면 전체화면 전환 및 알림 액션 수동 확인. 이후 확장 구현으로 Web FCM/브라우저 알림, Linux/Windows 빌드와 tray/toast/로컬 알림을 검증합니다.

## 커밋과 PR

현재 Git 히스토리 기준 커밋 규칙은 없습니다. 짧은 명령형 제목을 사용하세요. 예: `Fix Android desugaring config`. PR에는 변경 요약, 검증 명령, UI 변경 스크린샷, Firebase/플랫폼 설정 변경 사항을 포함합니다.

## 기타 규칙
1. 항상 의존성은 최신으로
2. 항상 한국어를 사용하여 이야기하고 문서도 한국어로 작성할 것
3. 변경 사항 발생 시에는 Notion에 있는 문서도 갱신할 것(계획, 구조, 작업 현황 등)
4. 린트와 디버그를 스스로 수행하여 코드를 완성할 것

# Agents Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
