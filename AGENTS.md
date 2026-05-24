# Repository Guidelines

## 문서 운영 원칙

이 저장소의 단일 기준 문서는 `AGENTS.md`입니다. 별도 AI 인계 문서나 프로젝트 기준 문서를 만들지 말고, 구조·Firebase·디자인·플랫폼 범위·남은 작업이 바뀌면 이 파일을 먼저 갱신하세요. `README.md`는 빠른 실행 진입점만 담당합니다.

## 역할 부여

당신은 Flutter와 Dart 생태계에 정통하고, Android 우선 모바일 앱 개발과 이후 Web/Linux/Windows 확장 설계 경험이 풍부한 **시니어 Full-stack Dart 개발자**이자 **DevOps 엔지니어**입니다.


## 프로젝트 목표

1차 목표는 Android에서 알람 생성, 동기화, 푸시, 로컬 알림을 안정적으로 구현하는 **'Android 우선 실시간 동기화 알람 앱'**입니다. Web, Linux, Windows는 Android 기본 구현이 끝난 뒤 확장 구현 계획에 포함합니다.

## 긴급 MVP 우선순위

시간이 부족한 상태에서는 제출 PDF의 **기본 구현 기능(Android)**을 최우선으로 완성합니다. 기본 구현 완료 기준은 Android에서 알람 목록 표시, 알람 이름/시간 설정, 알람 생성/수정/삭제, 알람 활성화/비활성화, 알람 울림 알림, 알람 해제, 스누즈, Firebase 저장/동기화가 데모 가능한 상태입니다.

후순위로 미루는 항목은 Web/PC 확장 구현, 고급 계정 관리, 알람 기록, 카테고리/태그, 벨소리 선택 UI, Emulator Suite 정밀 테스트, 세부 unit/widget test 추가입니다. 시간이 부족하면 시스템 알림 액션 버튼보다 앱 내부 `AlarmRingScreen`의 `Dismiss`/`Snooze` 안정성을 우선합니다.

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

기본 구현 목표는 Android에서 Firebase 기반 알람 MVP를 완성하는 것입니다. Web, Linux, Windows는 기본 구현 완료 후 같은 Firestore 구조를 재사용하는 확장 구현으로 다룹니다. 직접 운영 백엔드, Serverpod, PostgreSQL, K3s, Tailscale은 현재 범위에서 제외합니다. Firebase 제품은 Email/Password Authentication, Cloud Firestore, FCM, 최소 Cloud Functions만 사용합니다.

기본 실행은 Firebase 없이 `LocalDemoAlarmRepository`를 쓰는 로컬 데모 모드입니다. 현재 Firebase 프로젝트는 `alarm-b70d1`로 연결되어 있으며, Firebase 모드는 `USE_FIREBASE=true`로 켭니다. Firebase 모드에서도 로그아웃 상태는 로컬 기본 알람 기능을 바로 사용하고, 이메일 계정으로 로그인한 뒤 활성 그룹이 있을 때만 Firestore/FCM 동기화 저장소로 전환합니다. 그룹은 앱 안에서 생성하거나 초대 코드로 참가합니다. 위젯은 Firebase를 직접 호출하지 말고 `AccountRepository`, `AlarmRepository`, controller를 통해 상태를 변경하세요.

Firestore 구조:

```text
users/{uid}
users/{uid}/groups/{groupId}
groups/{groupId}
groups/{groupId}/members/{uid}
groups/{groupId}/alarms/{alarmId}
groups/{groupId}/devices/{deviceId}
groups/{groupId}/commands/{commandId}
groupSecrets/{groupId}
```

핵심 Functions는 `createGroup`, `joinGroup`, `onAlarmWrite`, `onCommandCreate`, `cleanupInvalidTokens`입니다.

기기 등록은 `FirebaseDeviceRegistrar`가 담당합니다. 기본 구현에서는 로그인한 사용자의 활성 그룹에 Android FCM 토큰을 `groups/{groupId}/devices/{deviceId}`로 저장합니다. `deviceId`는 앱 로컬 저장소에 생성/보관합니다. Web FCM, Linux/Windows 실행 중 Firestore 동기화용 기기 문서는 확장 구현 단계에서 검증합니다.

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
  --dart-define=USE_FIREBASE=true
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

테스트 프레임워크는 `flutter_test`입니다. 테스트 이름은 사용자에게 보이는 동작 기준으로 작성합니다. 예: `shows the alarm list shell`.

긴급 MVP 기간에는 자잘한 테스트 추가보다 Android 데모 기능 완성을 우선합니다. 코드 수정 후 최소 검증은 `flutter analyze`와 `flutter build apk --debug`입니다. 시간이 허용될 때만 `flutter test`를 추가로 실행합니다. 동기화, 알림 예약, 해제/스누즈처럼 데모를 깨는 핵심 로직을 크게 바꿀 때는 해당 경로의 수동 테스트를 반드시 수행합니다.

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

access code, invite code, service account, secret 파일은 커밋하지 않습니다. Firebase client config인 `firebase_options.dart`와 `android/app/google-services.json`은 제출/협업 정책에 맞춰 포함 여부를 결정하되, 서비스 계정 키처럼 비밀값으로 취급하지 않습니다. 그룹 초대 코드는 클라이언트 코드나 설정 파일에 고정하지 말고 앱 실행 중 사용자가 입력하게 합니다. 초대 코드 해시는 Firestore의 `groupSecrets/{groupId}`에 저장하며 클라이언트 읽기를 금지합니다. Firestore rules는 `members/{uid}`가 있는 사용자만 그룹 데이터에 접근하게 해야 합니다.

## 현재 구현 상태

Android MVP의 핵심 기능은 코드 기준으로 대부분 구현되어 있습니다.

- 앱 기반: Flutter 프로젝트, Android 우선 실행 흐름, Web/Linux/Windows 확장 scaffold
- 시작 안정성: `main.dart` 진입점 복구, 첫 Flutter 프레임 선표시, Firebase/알림 startup 초기화 비동기화
- 디자인/UX: Stitch 기반 그린 테마, 앱 아이콘, 다크 모드, 한국어/영어 로컬라이징, 알람 설정 섹션 간격 조정, 설정 화면의 불필요한 스위치/정보성 항목 제거 및 compact row 구성, 홈 우상단 동기화 상태 아이콘, `FirebaseAuthException` 로그인/회원가입 오류 시 다국어(`AppLocalizations`) 매핑을 적용하여 친숙한 한글 에러 피드백 제공, 설정 화면 내 일반 설정(테마 모드 드롭다운 및 SharedPreferences 기반 로컬 영속화), 기본 알람 설정, 전체화면 알람 권한 상태 확인 및 Android 설정 이동, 앱 정보(버전 1.0.0+1 표시), 계정 설정 화면(`AccountSettingsScreen`) 추가
- 로컬 모드: Firebase 없이 알람 목록/생성/수정/삭제/활성화/비활성화 사용, `SharedPreferences` 기반 로컬 알람 영속 저장, 자동 생성 예시 알람 제거, `watchAlarms` 스트림 정렬 강제로 알람 목록 순서 요동 해결
- 계정/그룹: Email/Password 회원가입/로그인, 로그아웃 상태 로컬 사용, 로그인 후 그룹 생성/참가/전환, 활성 그룹 기준 Firebase 저장소 전환, `_upsertCurrentUserProfile` 시 기존 `createdAt` 필드 유실 방지(보존) 적용, 설정 화면에서 계정 정보와 동기화된 기기 목록 확인
- Firebase 구조: `users/{uid}`, `users/{uid}/groups/{groupId}`, `groups/{groupId}`, `members`, `alarms`, `devices`, `commands`, `groupSecrets/{groupId}`
- Cloud Functions: `createGroup`, `joinGroup`, `onAlarmWrite`, `onCommandCreate`, `cleanupInvalidTokens` 및 FCM 500개 단위 청크 분할 전송/개별 예외 처리 격리로 전송 신뢰성 확보
- 보안/동기화: 초대 코드 해시 저장, 그룹 member 기반 Firestore 접근, Android FCM token 기기 등록, 알람/명령 변경 FCM fan-out, `firestore.rules` 내 기기 update/delete 시 소유권 `uid` 조건 강제 및 alarms 컬렉션 내 5대 핵심 필드(createdAt, updatedAt, updatedBy, snoozeUntil, lastTriggeredDate) 타입 및 null 허용 규칙 추가, `cleanupInvalidTokens` 내 디바이스 토큰 삭제 시 소유권 확인 로직 추가, `deviceId`를 암호화 영역인 `flutter_secure_storage`에 안전하게 보관하고 SharedPreferences 데이터의 무중단 마이그레이션 적용.
- 아키텍처 개선: `joinGroup` 비즈니스 로직 중복 제거 및 `AccountRepository`로의 단일 책임 일원화. `FirebaseAlarmRepository` 및 `FirebaseDeviceRegistrar` 내 모든 Firestore 쓰기 작업을 `withFirebaseOperationTimeout`으로 처리하여 지연 차단
- 성능/메모리: `AlarmDueTickTracker` 내 `Map<String, DateTime>` 기반 Sliding Window 방식의 12시간 주기 틱 정리를 탑재하여 메모리 누수 방지. 처리된 due tick과 실제 해제/스누즈 완료된 resolved tick은 `SharedPreferences`에도 저장하고 읽기 전 `reload()`하여 알람 전용 Activity와 메인 Activity 사이의 재울림 및 최근 앱 복귀 시 stale 알람 화면 복원을 억제합니다. `AlarmHomeScreen`의 20초 주기 타이머 리빌드(`setState`)를 알람 목록 탭(`_selectedTab == 0`)일 때만 수행하도록 제한하여 렌더링 최적화
- 알람 설정: 이름, 시간, 요일 반복, 울림 지속 시간, 소리 on/off, 진동 on/off, 다시 알림 사용 on/off, 스누즈 간격, 스누즈 횟수, 알람 업데이트 시 `revision + 1` 증가로 버전 충돌 방지
- Android 알림: 로컬 예약 알림, exact/inexact schedule, 요일별 반복 예약, 스누즈 1회 예약, 전용 ringing channel, full-screen intent, 잠금화면 표시/화면 켜기, `LaunchRouterActivity` 기반 앱 실행/알람 실행 분기, 잠금화면 알람 전용 `AlarmActivity`, 앱 foreground 상태에서 Android `AlarmManager` 기반 `ForegroundAlarmReceiver`가 같은 예약 시각에 Flutter launch 이벤트를 전달합니다. 이 분기는 `f42aa56` 기준 동작을 유지하기 위해 이후 라우팅 단순화/중복 launch 억제 커밋은 포함하지 않습니다. 일반 앱 실행 task는 최근 앱에 남기고, 잠금화면 알람 전용 `AlarmActivity` task만 최근 앱에서 제외합니다. Android 14+ full-screen intent 권한은 native `NotificationManager.canUseFullScreenIntent()`로 확인하고, 꺼진 경우 앱 설정에서 시스템 권한 화면으로 이동할 수 있습니다. 앱 시작 후 첫 예약 동기화 시 stale 예약 알림 전체 정리
- 알람 제어: 앱 내부 `AlarmRingScreen`에 지정된 울림 지속 시간(`ringDurationMinutes`) 만료 시 구동되는 자동 스누즈 타이머 추가, 시스템 알림 `Dismiss`/`Snooze` 액션, background action callback, 알람 전용 Activity에서 액션 후 `finishAndRemoveTask()`로 메인 화면 노출 감소, 같은 tick 재울림 방지, Activity 간 공유 tick 처리로 dismiss 직후 몇 초 뒤 다시 울리는 현상 방지, 시스템 알림 액션 수신 시 백그라운드 Firebase 초기화 및 Firestore 알람 상태 patch/명령 전송 동기화 완료, 스누즈 상태일 때 Ongoing 알림으로 상단바에 상시 노출 및 앱 홈 화면 알람 카드 내에 스누즈 횟수/예정 시각 배지 및 해제 기능 연동 완료. 다시 알림이 비활성화된 알람은 앱 내부 울림 화면에서 `Snooze` 버튼을 숨기고, 울림 지속 시간이 지나면 자동 해제합니다. 앱 내부와 잠금화면 알람의 `Dismiss`/`Snooze` 후에는 native 알람 Activity 종료 성공 여부와 관계없이 Flutter의 `ringingAlarmProvider`를 정리해 최근 앱 복귀 시 알람 화면이 되살아나지 않게 합니다. 시스템 알림 액션이나 다른 기기의 `alarm.command`를 앱 내부 `AlarmRingScreen`이 수신하면 현재 표시 중인 같은 알람의 화면과 진동을 즉시 정리합니다. 스누즈 진행 알림은 action payload는 유지하되 앱 내부 알람 화면 실행 payload와 분리합니다. Android에서는 알림 채널의 시스템 진동을 끄고, `AlarmVibrationController`가 native `Vibrator` 반복 패턴을 `ringDurationMinutes` 동안 실행하며, `Dismiss`/`Snooze`/알람 화면 종료 시 즉시 중지합니다.
- Firebase 데이터 메시지: `alarm.created`, `alarm.updated`, `alarm.deleted`, `alarm.command` 수신 시 사용자 알림을 띄우지 않는 무소음(Silent Sync) 모드로 동작. 백그라운드 수신 시 OS 네트워크 차단 및 절전 모드 지연을 완벽하게 방지하기 위해 Firestore GET 네트워크 호출을 배제하고, FCM 데이터 페이로드 자체에 포함된 상세 속성(시간, 요일, 반복 등)을 직접 파싱 및 복원하여 즉시 로컬 안드로이드 시스템 알람을 재스케줄링하도록 구현 완료. `alarm.command`는 `alarm.updated`와 순서 경쟁을 일으키지 않도록 로컬 예약을 직접 취소하지 않고, 앱에 이미 떠 있는 알람 화면을 닫는 presentation sync 신호로만 처리합니다. 예약 생성/변경/삭제는 `alarm.created`, `alarm.updated`, `alarm.deleted` 페이로드만 담당합니다.



## 검증된 항목

최근 코드 기준으로 다음 검증을 통과한 상태입니다.

- `flutter analyze`
- 전체 `flutter test`
- `flutter build apk --debug --dart-define=USE_FIREBASE=true`
- `flutter build apk --release --dart-define=USE_FIREBASE=true`
- 주요 테스트 파일: `account_flow_test.dart`, `alarm_due_tick_tracker_test.dart`, `alarm_model_test.dart`, `alarm_notification_service_test.dart`, `alarm_task_controller_test.dart`, `device_registration_test.dart`, `local_demo_alarm_repository_test.dart`, `widget_test.dart`

## 수동 확인이 필요한 항목

아래 항목은 코드와 자동 테스트만으로는 완료 판정하지 않습니다. 실제 Android 기기에서 확인해야 합니다.

- 앱 실행 후 알람 목록 표시
- 일반 앱 실행 후 홈/최근 앱 진입 시 앱 task가 최근 앱 목록에 표시되는지 확인
- Firebase 모드 로그아웃 상태에서 로컬 알람 생성/수정/삭제와 앱 재시작 후 유지
- 로그인 후 이전 로컬 모드 예약 알림이 더 이상 울리지 않는지 확인
- 사용자가 만들지 않은 예시 알람 시간이 더 이상 예약되지 않는지 확인
- 이메일 회원가입, 로그인, 로그아웃
- 그룹 생성, 그룹 참가, 그룹 전환
- Firebase Console의 `groups/{groupId}/alarms` 생성/수정/삭제 반영
- 두 번째 Android 기기를 백그라운드에 둔 상태에서 첫 번째 기기의 알람 생성/수정/삭제가 두 번째 기기의 로컬 예약에 반영되는지 확인
- 첫 번째 기기에서 `Dismiss`/`Snooze` 후 두 번째 기기 백그라운드 예약이 `alarm.command` 수신 때문에 통째로 취소되지 않는지 확인
- 알람별 요일, 지속 시간, 소리, 진동, 스누즈 시간, 스누즈 횟수 설정 저장
- 알람별 다시 알림 사용 토글이 꺼졌을 때 스누즈 버튼/자동 스누즈가 해제 처리되는지 확인
- 실제 시간 도달 시 Android 알림/소리/진동 발생
- 앱 메인 화면이 열린 상태에서 20초 polling 없이 Android foreground 예약 trigger로 `AlarmRingScreen`이 표시되는지 확인
- 잠금화면/full-screen 알람 화면 표시
- 잠금화면/full-screen 알람의 `Dismiss`/`Snooze` 후 메인 화면이 노출되지 않고 알람 전용 Activity만 닫히는지 확인
- 잠금화면/full-screen 알람에서 `Dismiss` 후 같은 알람이 몇 초 뒤 다시 울리지 않는지 확인
- 앱 내부와 시스템 알림 액션의 `Dismiss` 후 알림/울림 중지
- 앱 내부와 시스템 알림 액션의 `Snooze` 후 설정 시간 뒤 재울림
- 한 기기에서 `Dismiss`/`Snooze`를 누르면 다른 기기에 이미 떠 있는 같은 알람 화면과 진동이 닫히는지 확인
- Android 14+ 기기에서 설정 > 일반 설정 > 전체화면 알람이 허용됨으로 표시되는지 확인하고, 꺼진 경우 해당 행을 눌러 시스템 설정에서 켭니다.
- 백그라운드 복귀, 최근 앱 복귀, 알람 액션 이후 검은/흰 화면 재현 여부
- 두 번째 Android 기기나 에뮬레이터에서 같은 그룹 알람 목록 동기화

## 다음 구현 우선순위

1. Android 실기기 수동 검증 체크리스트를 끝까지 수행하고 발견 버그를 수정합니다.
2. 멀티 디바이스 동기화를 두 기기 또는 기기+에뮬레이터로 검증합니다.
3. 알람 설정 UX를 다듬습니다. 우선순위는 설정 화면 간격, 라벨, 저장 피드백, 스누즈/소리/진동 설정 가독성입니다.
4. 제출용 안정화만 필요한 테스트를 보강합니다. 단, 긴급 MVP 기간에는 불필요한 세부 테스트보다 데모 안정성을 우선합니다.
5. 제출 후 확장으로 Web FCM, Linux/Windows 로컬 알림, 고급 계정 관리, 알람 기록, 카테고리/태그, 벨소리 선택 UI를 진행합니다.

## 커밋과 PR

수정이 끝날 때마다 커밋하세요. 짧은 명령형 제목을 사용하세요. 예: `Fix Android desugaring config`. PR에는 변경 요약, 검증 명령, UI 변경 스크린샷, Firebase/플랫폼 설정 변경 사항을 포함합니다.

## 기타 규칙
1. 항상 의존성은 최신으로
2. 항상 한국어를 사용하여 이야기하고 문서도 한국어로 작성할 것, 인앱 언어는 항상 한국어를 기본으로 작성할 것
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
