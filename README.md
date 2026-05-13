# Team Project 1

Firebase 기반 Flutter 알람 앱 MVP입니다. 기본 구현은 Android에서 알람 생성, 동기화, FCM, 로컬 알림을 먼저 완성하고, Web/Linux/Windows는 이후 확장 구현으로 다룹니다.

상세 기준, 아키텍처, 디자인 토큰, 보안 규칙, 남은 작업은 [AGENTS.md](./AGENTS.md)를 단일 기준 문서로 사용합니다.

## 빠른 실행

```bash
cd synced_alarm
/home/devuser/flutter/bin/flutter pub get
/home/devuser/flutter/bin/flutter run -d <android-device-id>
```

기본 실행은 Firebase 없이 로컬 데모 저장소를 사용합니다.

## 기본 검증

```bash
cd synced_alarm
/home/devuser/flutter/bin/dart format .
/home/devuser/flutter/bin/flutter analyze
/home/devuser/flutter/bin/flutter test
```
