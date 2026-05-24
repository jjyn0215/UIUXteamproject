# Team Project 1

Firebase 기반 Flutter 알람 앱 MVP입니다. 기본 구현은 Android에서 알람 생성, 요일/소리/진동/스누즈 세부 설정, 동기화, FCM, 로컬 알림을 먼저 완성하고, Web/Linux/Windows는 이후 확장 구현으로 다룹니다.

상세 기준, 아키텍처, 디자인 토큰, 보안 규칙, 남은 작업은 [AGENTS.md](./AGENTS.md)를 단일 기준 문서로 사용합니다.

## 빠른 실행

```bash
cd synced_alarm
/home/devuser/flutter/bin/flutter pub get
/home/devuser/flutter/bin/flutter run -d <android-device-id>
```

기본 실행은 Firebase 없이 로컬 데모 저장소를 사용합니다.

Firebase 로그인/그룹 동기화 모드는 다음처럼 실행합니다. 이 모드에서도 로그인 전에는 로컬 알람 기능을 바로 사용할 수 있고, 설정에서 로그인한 뒤 그룹을 선택하면 Firebase 동기화로 전환됩니다.

```bash
cd synced_alarm
/home/devuser/flutter/bin/flutter run -d <android-device-id> \
  --dart-define=USE_FIREBASE=true
```

## 기본 검증

```bash
cd synced_alarm
/home/devuser/flutter/bin/dart format .
/home/devuser/flutter/bin/flutter analyze
/home/devuser/flutter/bin/flutter test
```

