# synced_alarm

Flutter 앱 소스 루트입니다. 기본 구현 대상은 Android이며, 실행, 아키텍처, Firebase, 디자인, 확장 플랫폼 범위, 기여 규칙은 상위 [AGENTS.md](../AGENTS.md)를 기준으로 합니다.

## 배포용 서명 설정

릴리스 APK/AAB를 스토어용으로 내보내려면 `synced_alarm/android/key.properties`와 업로드 keystore가 필요합니다. 저장소에는 비밀값을 넣지 않도록 `synced_alarm/android/key.properties.example`을 기준으로 로컬 파일을 만들어 사용하세요.

예시:

1. `synced_alarm/android/key.properties.example`을 복사해 `synced_alarm/android/key.properties`로 저장합니다.
2. `storeFile`에 맞는 keystore 파일을 `synced_alarm/android/app/upload-keystore.jks`에 둡니다.
3. 빌드합니다.

```bash
cd synced_alarm
/home/devuser/flutter/bin/flutter build apk --release
/home/devuser/flutter/bin/flutter build appbundle --release
```

Firebase 프로덕션까지 포함하려면 아래처럼 실행합니다.

```bash
cd synced_alarm
/home/devuser/flutter/bin/flutter build apk --release --dart-define=USE_FIREBASE=true
/home/devuser/flutter/bin/flutter build appbundle --release --dart-define=USE_FIREBASE=true
```
