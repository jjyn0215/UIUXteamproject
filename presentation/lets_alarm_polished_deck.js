"use strict";

const path = require("path");
const {
  pptx,
  C,
  TITLE_FONT,
  TITLE_LIGHT,
  BODY_FONT,
  text,
  shape,
  addFullBackground,
  addMeta,
  addTag,
  validateSlide,
} = require("./lets_alarm_visual_sample");

const OUTPUT = path.join(__dirname, "Lets_alarm_발표자료_디자인정리본_9장.pptx");
const HOME_CAPTURE = path.join(__dirname, "assets", "alarm_home_capture.png");
const ICONS = {
  alarm: path.join(__dirname, "assets", "icon_alarm.png"),
  bell: path.join(__dirname, "assets", "icon_bell.png"),
  cloud: path.join(__dirname, "assets", "icon_cloud.png"),
  shield: path.join(__dirname, "assets", "icon_shield.png"),
  tune: path.join(__dirname, "assets", "icon_tune.png"),
};

pptx.title = "Let's alarm - 디자인 정리본";
pptx.subject = "UI/UX 프로그래밍 6조 발표자료";

function addIcon(slide, kind, x, y, size = 0.32) {
  slide.addImage({ path: ICONS[kind], x, y, w: size, h: size });
}

function titleBlock(slide, section, page, heading, lead, dark = false) {
  addFullBackground(slide, dark);
  addMeta(slide, section, page, dark);
  text(slide, heading, 0.68, 1.03, 11.65, 0.5, {
    fontFace: TITLE_FONT,
    fontSize: 27,
    bold: true,
    color: dark ? C.surface : C.text,
  });
  text(slide, lead, 0.7, 1.68, 11.55, 0.29, {
    fontSize: 11,
    bold: true,
    color: dark ? "D5E9DE" : C.primary,
  });
}

function panel(slide, x, y, w, h, options = {}) {
  shape(
    slide,
    pptx.ShapeType.roundRect,
    x,
    y,
    w,
    h,
    options.fill || C.surface,
    options.line || C.border,
    0.08
  );
}

function panelText(slide, label, heading, body, x, y, w, h, options = {}) {
  panel(slide, x, y, w, h, options);
  if (label) {
    text(slide, label, x + 0.25, y + 0.24, w - 0.5, 0.17, {
      fontSize: 8.5,
      bold: true,
      charSpacing: 1,
      color: options.labelColor || C.primary,
    });
  }
  text(slide, heading, x + 0.25, y + 0.64, w - 0.5, 0.34, {
    fontFace: TITLE_FONT,
    fontSize: options.headingSize || 16,
    bold: true,
    color: options.textColor || C.text,
  });
  text(slide, body, x + 0.25, y + 1.15, w - 0.5, h - 1.38, {
    fontSize: options.bodySize || 11,
    bold: options.bodyBold || false,
    color: options.bodyColor || C.muted,
    valign: "top",
    breakLine: false,
  });
}

function numberedCard(slide, number, heading, caption, x, y, w, active = false) {
  panel(slide, x, y, w, 0.78, {
    fill: active ? C.primarySoft : C.surface,
    line: active ? C.primaryContainer : C.border,
  });
  shape(slide, pptx.ShapeType.ellipse, x + 0.19, y + 0.22, 0.33, 0.33, C.primary, C.primary);
  text(slide, number, x + 0.19, y + 0.282, 0.33, 0.15, {
    fontSize: 8,
    bold: true,
    color: C.surface,
    align: "center",
  });
  text(slide, heading, x + 0.68, y + 0.16, w - 0.86, 0.22, {
    fontSize: 11,
    bold: true,
  });
  text(slide, caption, x + 0.68, y + 0.47, w - 0.86, 0.17, {
    fontSize: 8.5,
    color: C.muted,
  });
}

function screenPlaceholder(slide, label, caption, x, y, w, h) {
  panel(slide, x, y, w, h);
  shape(slide, pptx.ShapeType.roundRect, x + 0.18, y + 0.18, w - 0.36, h - 0.73, "F1F7F2", C.primaryContainer, 0.06);
  addIcon(slide, "tune", x + w / 2 - 0.22, y + h / 2 - 0.48, 0.44);
  text(slide, "화면 캡처 삽입 영역", x + 0.3, y + h / 2 + 0.06, w - 0.6, 0.22, {
    fontSize: 9.5,
    bold: true,
    color: C.primary,
    align: "center",
  });
  text(slide, label, x + 0.2, y + h - 0.4, w - 0.4, 0.18, {
    fontSize: 9,
    bold: true,
  });
  text(slide, caption, x + 0.2, y + h - 0.21, w - 0.4, 0.16, {
    fontSize: 7.5,
    color: C.muted,
  });
}

function screenshotCard(slide, label, caption, x, y, w, h) {
  panel(slide, x, y, w, h);
  const imageW = 1.84;
  const imageH = 3.68;
  slide.addImage({
    path: HOME_CAPTURE,
    x: x + (w - imageW) / 2,
    y: y + 0.16,
    w: imageW,
    h: imageH,
  });
  text(slide, label, x + 0.2, y + h - 0.4, w - 0.4, 0.18, {
    fontSize: 9,
    bold: true,
  });
  text(slide, caption, x + 0.2, y + h - 0.2, w - 0.4, 0.16, {
    fontSize: 7.5,
    color: C.muted,
  });
}

function simpleArrow(slide, x, y, w, label, dark = false) {
  slide.addShape(pptx.ShapeType.chevron, {
    x,
    y,
    w,
    h: 0.13,
    fill: { color: dark ? "90CDA4" : C.primaryContainer },
    line: { color: dark ? "90CDA4" : C.primaryContainer, transparency: 100 },
  });
  if (label) {
    text(slide, label, x - 0.06, y - 0.25, w + 0.12, 0.17, {
      fontSize: 7.5,
      bold: true,
      color: dark ? C.primaryContainer : C.primary,
      align: "center",
    });
  }
}

function node(slide, heading, body, x, y, w, h, options = {}) {
  panel(slide, x, y, w, h, options);
  if (options.icon) {
    addIcon(slide, options.icon, x + 0.16, y + 0.18, 0.3, options.iconColor);
  }
  const left = options.icon ? x + 0.55 : x + 0.2;
  text(slide, heading, left, y + 0.18, w - (left - x) - 0.18, 0.23, {
    fontSize: options.headingSize || 10,
    bold: true,
    color: options.textColor || C.text,
  });
  text(slide, body, left, y + 0.51, w - (left - x) - 0.18, 0.18, {
    fontSize: options.bodySize || 8,
    color: options.bodyColor || C.muted,
  });
}

function coverSlide() {
  const slide = pptx.addSlide();
  addFullBackground(slide);
  addMeta(slide, "평가 (1) 프로그램 개요 및 설명", "01");
  text(slide, "Android first  /  Firebase sync", 0.68, 1.36, 4.6, 0.2, {
    fontSize: 10,
    color: C.primary,
    bold: true,
    charSpacing: 1.2,
  });
  text(slide, "Let's alarm", 0.66, 1.86, 6.9, 0.74, {
    fontFace: TITLE_FONT,
    fontSize: 42,
    bold: true,
  });
  text(slide, "렛츠알람", 0.7, 2.74, 3, 0.32, {
    fontFace: TITLE_FONT,
    fontSize: 18,
    bold: true,
    color: C.primary,
  });
  text(slide, "여러 Android 기기에서 같은 알람 변경 상태를 공유하는\nFlutter 기반 실시간 동기화 알람 앱", 0.7, 3.52, 6.5, 0.68, {
    fontSize: 16,
    bold: true,
    valign: "top",
  });
  addTag(slide, "Flutter / Dart", 0.7, 4.77, 1.46);
  addTag(slide, "Firebase", 2.3, 4.77, 1.12);
  addTag(slide, "Android / Kotlin", 3.58, 4.77, 1.62);
  text(slide, "UI/UX 프로그래밍  |  6조", 0.7, 5.56, 3.6, 0.24, {
    fontSize: 11,
    bold: true,
    color: C.primary,
  });
  panel(slide, 9.24, 1.02, 2.75, 5.76);
  slide.addImage({ path: HOME_CAPTURE, x: 9.57, y: 1.3, w: 2.09, h: 4.18 });
  text(slide, "ALARM HOME", 9.59, 5.86, 2.06, 0.17, {
    fontSize: 8,
    color: C.primary,
    bold: true,
    charSpacing: 1,
  });
  text(slide, "실제 Android 홈 화면", 9.59, 6.17, 2.08, 0.2, {
    fontSize: 10,
    bold: true,
  });
  validateSlide(slide);
}

function contentsSlide() {
  const slide = pptx.addSlide();
  titleBlock(slide, "CONTENTS", "02", "목차", "발표 흐름을 구현 기능과 시스템 구조 중심으로 구성했습니다.");
  const entries = [
    ["01", "프로그램 개요 및 목표", "문제 정의와 Android 우선 구현 범위"],
    ["02", "주요 UI 기능", "알람 관리, 울림, 계정 동기화"],
    ["03", "전체 구조와 클래스 흐름", "Firebase 동기화와 로컬 알람 예약"],
    ["04", "구현 진행 및 보안", "제어 흐름, 데이터 구조, 접근 제어"],
  ];
  entries.forEach(([number, heading, caption], index) => {
    const y = 2.48 + index * 0.94;
    numberedCard(slide, number, heading, caption, 0.7, y, 9.4, index === 2);
    text(slide, String(index + 1).padStart(2, "0"), 10.74, y + 0.13, 1.28, 0.48, {
      fontFace: TITLE_LIGHT,
      fontSize: 26,
      bold: true,
      color: index === 2 ? C.primary : C.primaryContainer,
      align: "right",
    });
  });
  validateSlide(slide);
}

function overviewSlide() {
  const slide = pptx.addSlide();
  titleBlock(
    slide,
    "평가 (1) 프로그램 개요 및 설명",
    "03",
    "개발 배경 및 목표",
    "기기마다 분리된 알람 상태를 Android 알람과 Firebase 동기화로 연결합니다."
  );
  panelText(
    slide,
    "PROBLEM",
    "기기별 알람 상태 분리",
    "각 기기에서 변경한 시간과\n해제·스누즈 상태가 따로 남아\n일관된 사용이 어렵습니다.",
    0.7,
    2.38,
    5.56,
    2.33,
    { headingSize: 18, bodySize: 13 }
  );
  panelText(
    slide,
    "SOLUTION",
    "Android 우선 + Firebase",
    "Flutter Android 알람을 먼저 완성하고,\nFirebase로 여러 기기의 변경 상태를\n공유합니다.",
    6.57,
    2.38,
    6.08,
    2.33,
    {
      fill: C.primarySoft,
      line: C.primaryContainer,
      headingSize: 18,
      bodySize: 13,
    }
  );
  text(slide, "IMPLEMENTATION SCOPE", 0.72, 5.18, 2.7, 0.18, {
    fontSize: 8.5,
    bold: true,
    color: C.primary,
    charSpacing: 1,
  });
  numberedCard(slide, "1", "기본 구현", "Android 알람 / 로컬 예약", 0.7, 5.56, 3.72, true);
  numberedCard(slide, "2", "동기화", "로그인 / 그룹 / Firebase", 4.63, 5.56, 3.72, true);
  numberedCard(slide, "3", "향후 확장", "Web / Linux / Windows", 8.56, 5.56, 4.09, false);
  validateSlide(slide);
}

function uiManagementSlide() {
  const slide = pptx.addSlide();
  titleBlock(
    slide,
    "평가 (3) 주요 기능 설명",
    "04",
    "주요 UI 기능 I. 알람 관리",
    "목록에서 알람 상태를 확인하고, 편집 화면에서 조건을 설정합니다."
  );
  screenshotCard(slide, "AlarmHomeScreen", "목록 / 활성화 토글 / 동기화 상태", 0.7, 2.3, 3.08, 4.2);
  screenPlaceholder(slide, "AlarmEditorSheet", "이름 / 시간 / 요일 / 다시 알림", 4.06, 2.3, 3.08, 4.2);
  text(slide, "USER ACTION", 7.62, 2.34, 2.0, 0.18, {
    fontSize: 8.5,
    color: C.primary,
    bold: true,
    charSpacing: 1,
  });
  numberedCard(slide, "1", "알람 목록 확인", "시간과 활성화 상태 확인", 7.6, 2.75, 5.04, true);
  numberedCard(slide, "2", "시간 · 요일 편집", "반복 알람 조건 설정", 7.6, 3.7, 5.04, false);
  numberedCard(slide, "3", "소리 · 진동 설정", "알람별 울림 방식 선택", 7.6, 4.65, 5.04, false);
  numberedCard(slide, "4", "다시 알림 설정", "스누즈 간격과 횟수 설정", 7.6, 5.6, 5.04, true);
  validateSlide(slide);
}

function uiSyncSlide() {
  const slide = pptx.addSlide();
  titleBlock(
    slide,
    "평가 (3) 주요 기능 설명",
    "05",
    "주요 UI 기능 II. 울림과 계정 동기화",
    "로그아웃 상태에서는 로컬 알람을 사용하고, 로그인 후에는 그룹 알람을 공유합니다."
  );
  screenPlaceholder(slide, "AlarmRingScreen", "잠금화면 울림 화면", 0.7, 2.31, 3.13, 4.15);
  screenPlaceholder(slide, "Account / Group", "로그인 및 그룹 관리", 4.1, 2.31, 3.13, 4.15);
  panelText(
    slide,
    "ALARM ACTION",
    "Dismiss / Snooze",
    "Dismiss  현재 울림 종료\nSnooze  설정 시간 뒤 재알림",
    7.66,
    2.31,
    4.99,
    1.82,
    { headingSize: 15, bodySize: 10.5 }
  );
  panelText(
    slide,
    "SYNC MODE",
    "로컬 또는 공유 사용",
    "로그아웃  로컬 알람 사용\n로그인 + 그룹  공유 동기화 사용",
    7.66,
    4.42,
    4.99,
    1.82,
    {
      fill: C.primarySoft,
      line: C.primaryContainer,
      headingSize: 15,
      bodySize: 10.5,
    }
  );
  validateSlide(slide);
}

function architectureSlide() {
  const slide = pptx.addSlide();
  titleBlock(
    slide,
    "평가 (2) 전체 시스템 구조도",
    "06",
    "Firebase 기반 동기화 알람 구조",
    "변경 데이터는 Firebase로 전달하고, 실제 정각 울림은 각 Android 기기가 실행합니다.",
    true
  );
  panel(slide, 0.7, 2.42, 2.54, 3.15, { fill: "214537", line: "527768" });
  text(slide, "DEVICE A", 0.93, 2.68, 1.4, 0.18, {
    fontSize: 8.5,
    color: C.primaryContainer,
    bold: true,
    charSpacing: 1,
  });
  node(slide, "Flutter Android", "알람 생성 / 수정", 0.93, 3.14, 2.08, 0.83, {
    fill: C.surface,
    line: C.surface,
    icon: "alarm",
  });
  node(slide, "로컬 알람 예약", "정각 울림 담당", 0.93, 4.3, 2.08, 0.83, {
    fill: C.primarySoft,
    line: C.primaryContainer,
    icon: "bell",
  });
  panel(slide, 3.73, 2.25, 5.85, 3.5, { fill: C.background, line: C.background });
  text(slide, "FIREBASE CLOUD", 4.02, 2.53, 2.3, 0.18, {
    fontSize: 8.5,
    bold: true,
    color: C.primary,
    charSpacing: 1,
  });
  node(slide, "Authentication", "사용자 식별", 4.02, 3.14, 1.63, 0.82, {
    fill: C.surface,
    line: C.border,
  });
  node(slide, "Firestore", "공유 원본", 5.87, 3.14, 1.6, 0.82, {
    fill: C.firebase,
    line: C.firebaseLine,
  });
  node(slide, "Functions", "변경 감지", 7.69, 3.14, 1.58, 0.82, {
    fill: C.firebase,
    line: C.firebaseLine,
  });
  node(slide, "FCM", "변경 전달", 5.88, 4.48, 1.58, 0.82, {
    fill: C.primarySoft,
    line: C.primaryContainer,
    icon: "cloud",
  });
  simpleArrow(slide, 3.29, 3.52, 0.35, "1. 저장", true);
  simpleArrow(slide, 9.69, 3.52, 0.35, "4. 수신", true);
  text(slide, "2. 변경 감지   ->   3. FCM 전송", 4.2, 5.12, 5.05, 0.2, {
    fontSize: 9,
    color: C.primary,
    bold: true,
    align: "center",
  });
  panel(slide, 10.08, 2.42, 2.57, 3.15, { fill: "214537", line: "527768" });
  text(slide, "DEVICE B", 10.33, 2.68, 1.4, 0.18, {
    fontSize: 8.5,
    color: C.primaryContainer,
    bold: true,
    charSpacing: 1,
  });
  node(slide, "Flutter Android", "동기화 수신", 10.33, 3.14, 2.08, 0.83, {
    fill: C.surface,
    line: C.surface,
    icon: "cloud",
  });
  node(slide, "로컬 예약 갱신", "정각 울림 담당", 10.33, 4.3, 2.08, 0.83, {
    fill: C.primarySoft,
    line: C.primaryContainer,
    icon: "bell",
  });
  panel(slide, 0.7, 6.08, 11.95, 0.58, { fill: "315B4B", line: "315B4B" });
  text(slide, "FCM은 동기화 신호를 전달하고, 실제 알람 울림은 Android 로컬 예약이 담당합니다.", 1.05, 6.27, 11.25, 0.2, {
    fontSize: 11,
    bold: true,
    color: C.surface,
    align: "center",
  });
  validateSlide(slide);
}

function classFlowSlide() {
  const slide = pptx.addSlide();
  titleBlock(
    slide,
    "평가 (2) 주요 클래스 흐름",
    "07",
    "주요 클래스 흐름. 알람 생성과 저장",
    "사용자 입력에서 Android 로컬 예약 갱신까지 앱 내부 처리 순서를 보여줍니다."
  );
  const steps = [
    ["01", "AlarmEditorSheet", "정보 입력", 0.7, 1.92],
    ["02", "AlarmListController", "요청 처리", 2.91, 2.18],
    ["03", "AlarmRepository", "모드별 저장", 5.42, 2.08],
    ["04", "NotificationService", "예약 갱신", 7.8, 2.33],
    ["05", "Android 예약", "정각 트리거", 10.44, 2.2],
  ];
  steps.forEach(([number, heading, caption, x, w]) => {
    numberedCard(slide, number, heading, caption, x, 2.62, w, number === "05");
  });
  simpleArrow(slide, 2.67, 2.95, 0.17, "");
  simpleArrow(slide, 5.19, 2.95, 0.17, "");
  simpleArrow(slide, 7.58, 2.95, 0.17, "");
  simpleArrow(slide, 10.2, 2.95, 0.17, "");
  text(slide, "REPOSITORY BRANCH", 0.72, 4.15, 2.75, 0.2, {
    fontSize: 8.5,
    color: C.primary,
    bold: true,
    charSpacing: 1,
  });
  panelText(
    slide,
    "LOCAL MODE",
    "로그아웃 / 로컬 모드",
    "LocalDemoAlarmRepository  ->  SharedPreferences",
    0.7,
    4.56,
    5.86,
    1.48,
    { headingSize: 14, bodySize: 10.5 }
  );
  panelText(
    slide,
    "SYNC MODE",
    "로그인 + 활성 그룹 모드",
    "FirebaseAlarmRepository  ->  Cloud Firestore",
    6.79,
    4.56,
    5.86,
    1.48,
    {
      fill: C.primarySoft,
      line: C.primaryContainer,
      headingSize: 14,
      bodySize: 10.5,
    }
  );
  text(slide, "저장 위치가 달라도 Android 로컬 알람 예약 갱신은 공통으로 수행됩니다.", 0.72, 6.38, 11.9, 0.2, {
    fontSize: 10,
    color: C.primary,
    bold: true,
    align: "center",
  });
  validateSlide(slide);
}

function flowLane(slide, label, steps, y, active = false) {
  panel(slide, 0.7, y, 11.95, 1.32, {
    fill: active ? C.primarySoft : C.surface,
    line: active ? C.primarySoft : C.border,
  });
  text(slide, label, 0.96, y + 0.22, 1.56, 0.2, {
    fontSize: 10,
    color: C.primary,
    bold: true,
  });
  steps.forEach((item, index) => {
    const x = 2.58 + index * 1.92;
    shape(slide, pptx.ShapeType.ellipse, x, y + 0.55, 0.29, 0.29, C.primary, C.primary);
    text(slide, String(index + 1), x, y + 0.615, 0.29, 0.14, {
      fontSize: 7,
      bold: true,
      color: C.surface,
      align: "center",
    });
    text(slide, item, x + 0.38, y + 0.48, 1.32, 0.4, {
      fontSize: 8.5,
      bold: true,
      valign: "mid",
    });
    if (index < steps.length - 1) simpleArrow(slide, x + 1.68, y + 0.64, 0.13, "");
  });
}

function controlFlowSlide() {
  const slide = pptx.addSlide();
  titleBlock(
    slide,
    "평가 (2) 기능 흐름 및 구현 진행",
    "08",
    "기능 흐름 및 구현 진행",
    "변경 동기화와 알람 울림 제어는 서로 다른 책임으로 처리합니다."
  );
  flowLane(slide, "변경 동기화", ["기기 A\n수정", "Firestore", "Functions", "FCM", "기기 B\n예약"], 2.34, true);
  flowLane(slide, "울림 제어", ["시각\n도달", "RingScreen", "Dismiss", "Snooze", "상태\n전달"], 4.0, false);
  addTag(slide, "구현 반영", 0.72, 5.83, 1.14);
  text(slide, "Android UI / 로컬 예약 / 그룹 코드", 2.0, 5.89, 3.25, 0.18, {
    fontSize: 9,
    bold: true,
  });
  addTag(slide, "확인 필요", 5.57, 5.83, 1.14);
  text(slide, "두 기기 간 동기화 안정성", 6.84, 5.89, 2.27, 0.18, {
    fontSize: 9,
    bold: true,
  });
  addTag(slide, "확장 계획", 9.48, 5.83, 1.14);
  text(slide, "Web / Linux / Windows", 10.77, 5.89, 1.73, 0.18, {
    fontSize: 8.5,
    bold: true,
  });
  text(slide, "이미 예약된 알람은 네트워크가 없어도 울릴 수 있으며, 새로운 변경 동기화에는 네트워크가 필요합니다.", 0.74, 6.5, 11.85, 0.2, {
    fontSize: 9,
    color: C.muted,
    align: "center",
  });
  validateSlide(slide);
}

function codeRow(slide, value, x, y, active = false) {
  panel(slide, x, y, 5.35, 0.45, {
    fill: active ? C.primarySoft : C.surface,
    line: active ? C.primaryContainer : C.border,
  });
  text(slide, value, x + 0.17, y + 0.14, 5.0, 0.18, {
    fontSize: 8.8,
    bold: true,
    color: active ? C.primary : C.text,
  });
}

function securitySlide() {
  const slide = pptx.addSlide();
  titleBlock(
    slide,
    "평가 (2) 데이터 구조와 보안",
    "09",
    "데이터 구조와 보안",
    "공유 알람은 그룹 구성원에게만 열리고, 변경 신호는 등록된 Android 기기로 전달됩니다."
  );
  text(slide, "FIRESTORE COLLECTIONS", 0.72, 2.35, 2.7, 0.18, {
    fontSize: 8.5,
    color: C.primary,
    bold: true,
    charSpacing: 1,
  });
  [
    "users/{uid}",
    "groups/{groupId}/members/{uid}",
    "groups/{groupId}/alarms/{alarmId}",
    "groups/{groupId}/devices/{deviceId}",
    "groups/{groupId}/commands/{commandId}",
    "groupSecrets/{groupId}",
  ].forEach((value, index) => codeRow(slide, value, 0.7, 2.74 + index * 0.54, index === 1 || index === 2));
  text(slide, "SECURITY POINTS", 6.55, 2.35, 2.5, 0.18, {
    fontSize: 8.5,
    color: C.primary,
    bold: true,
    charSpacing: 1,
  });
  node(slide, "Authentication", "로그인 사용자 식별", 6.54, 2.74, 6.11, 0.83, {
    icon: "shield",
  });
  node(slide, "Firestore Rules", "그룹 멤버만 공유 알람 접근", 6.54, 3.79, 6.11, 0.83, {
    fill: C.primarySoft,
    line: C.primaryContainer,
    icon: "shield",
  });
  node(slide, "Functions / FCM", "변경 내용을 등록된 Android 기기로 전달", 6.54, 4.84, 6.11, 0.83, {
    icon: "cloud",
  });
  panel(slide, 6.54, 5.98, 6.11, 0.62, {
    fill: C.primary,
    line: C.primary,
  });
  text(slide, "초대 코드 해시 저장  /  FCM 토큰은 기기 문서에서 관리", 6.8, 6.19, 5.6, 0.2, {
    fontSize: 9.5,
    bold: true,
    color: C.surface,
    align: "center",
  });
  validateSlide(slide);
}

async function writeDeck() {
  coverSlide();
  contentsSlide();
  overviewSlide();
  uiManagementSlide();
  uiSyncSlide();
  architectureSlide();
  classFlowSlide();
  controlFlowSlide();
  securitySlide();
  await pptx.writeFile({ fileName: OUTPUT });
  console.log(`PPTX 생성 완료: ${OUTPUT}`);
}

writeDeck().catch((error) => {
  console.error("PPTX 생성 실패:", error);
  process.exitCode = 1;
});
