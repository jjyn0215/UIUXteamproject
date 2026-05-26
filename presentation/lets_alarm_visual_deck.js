"use strict";

const path = require("path");
const {
  pptx,
  C,
  TITLE_FONT,
  BODY_FONT,
  text,
  shape,
  addIcon,
  addFullBackground,
  addMeta,
  addTag,
  addNode,
  validateSlide,
  addCoverSlide,
  addArchitectureSlide,
} = require("./lets_alarm_visual_sample");

const OUTPUT = path.join(__dirname, "Lets_alarm_발표자료_완성본_8장.pptx");

pptx.title = "Let's alarm - presentation";
pptx.subject = "Android 우선 실시간 동기화 알람 앱 발표자료";

function addTitleBlock(slide, section, page, heading, lead, dark = false) {
  addFullBackground(slide, dark);
  addMeta(slide, section, page, dark);
  text(slide, heading, 0.65, 1.06, 9.7, 0.52, {
    fontFace: TITLE_FONT,
    fontSize: 27,
    bold: true,
    color: dark ? C.surface : C.text,
  });
  text(slide, lead, 0.67, 1.69, 10.8, 0.32, {
    fontSize: 10.5,
    bold: true,
    color: dark ? "D5E9DE" : C.primary,
  });
}

function addPanel(slide, title, body, x, y, w, h, options = {}) {
  shape(
    slide,
    pptx.ShapeType.roundRect,
    x,
    y,
    w,
    h,
    options.fill || C.surface,
    options.line || C.border,
    0.09
  );
  if (options.icon) {
    addIcon(slide, options.icon, x + 0.22, y + 0.21, 0.36, options.iconColor);
  }
  const titleX = options.icon ? x + 0.72 : x + 0.23;
  text(slide, title, titleX, y + 0.2, w - (titleX - x) - 0.22, 0.25, {
    fontFace: TITLE_FONT,
    fontSize: options.titleSize || 13,
    bold: true,
    color: options.titleColor || C.text,
  });
  text(slide, body, x + 0.24, y + 0.65, w - 0.48, h - 0.82, {
    fontSize: options.fontSize || 10,
    bold: options.bold || false,
    color: options.bodyColor || C.muted,
    valign: "top",
  });
}

function addCaptureFrame(slide, title, detail, x, y, w, h) {
  shape(slide, pptx.ShapeType.roundRect, x, y, w, h, C.surface, C.border, 0.1);
  shape(slide, pptx.ShapeType.roundRect, x + 0.16, y + 0.18, w - 0.32, h - 0.71, "EEF5F0", "EEF5F0", 0.06);
  slide.addShape(pptx.ShapeType.line, {
    x: x + 0.42,
    y: y + 0.49,
    w: w - 0.84,
    h: h - 1.31,
    line: { color: C.primaryContainer, width: 1, dash: "dash" },
  });
  slide.addShape(pptx.ShapeType.line, {
    x: x + w - 0.42,
    y: y + 0.49,
    w: -(w - 0.84),
    h: h - 1.31,
    line: { color: C.primaryContainer, width: 1, dash: "dash" },
  });
  text(slide, "실제 앱 화면 캡처 삽입", x + 0.3, y + h / 2 - 0.21, w - 0.6, 0.24, {
    fontSize: 9,
    bold: true,
    color: C.primary,
    align: "center",
  });
  text(slide, title, x + 0.19, y + h - 0.4, w * 0.54, 0.18, {
    fontSize: 8.6,
    bold: true,
    color: C.text,
  });
  text(slide, detail, x + w * 0.53, y + h - 0.4, w * 0.39, 0.18, {
    fontSize: 7.6,
    color: C.muted,
    align: "right",
  });
}

function addSmallLabel(slide, title, body, x, y, w, active = false, icon = null) {
  shape(
    slide,
    pptx.ShapeType.roundRect,
    x,
    y,
    w,
    0.68,
    active ? C.primarySoft : C.surface,
    active ? C.primaryContainer : C.border,
    0.06
  );
  if (icon) addIcon(slide, icon, x + 0.14, y + 0.17, 0.29);
  const lx = icon ? x + 0.53 : x + 0.17;
  text(slide, title, lx, y + 0.14, w - (lx - x) - 0.12, 0.18, {
    fontSize: 9,
    bold: true,
  });
  text(slide, body, lx, y + 0.4, w - (lx - x) - 0.12, 0.15, {
    fontSize: 7.3,
    color: C.muted,
  });
}

function addConnector(slide, x, y, w, label, dark = false) {
  slide.addShape(pptx.ShapeType.chevron, {
    x,
    y,
    w,
    h: 0.14,
    fill: { color: dark ? "8EC69C" : C.primaryContainer },
    line: { color: dark ? "8EC69C" : C.primaryContainer, transparency: 100 },
  });
  if (label) {
    text(slide, label, x - 0.12, y - 0.26, w + 0.24, 0.16, {
      fontSize: 7,
      bold: true,
      color: dark ? C.primaryContainer : C.primary,
      align: "center",
    });
  }
}

function addOverviewSlide() {
  const slide = pptx.addSlide();
  addTitleBlock(
    slide,
    "평가 (1) 프로그램 개요 및 설명",
    "02",
    "프로그램 개요 및 개발 목표",
    "기기마다 분리된 알람 상태를 Android 우선 구현과 Firebase 동기화로 연결합니다."
  );

  addPanel(
    slide,
    "Problem",
    "각 기기의 알람 설정과\n해제·스누즈 상태가 분리됨",
    0.68,
    2.4,
    5.23,
    2.07,
    { icon: "alarm", titleSize: 17, fontSize: 15, bold: true }
  );
  addPanel(
    slide,
    "Solution",
    "Android 알람을 먼저 완성하고\nFirebase로 변경 상태를 공유",
    6.28,
    2.4,
    6.38,
    2.07,
    {
      fill: C.primary,
      line: C.primary,
      icon: "cloud",
      iconColor: "#B9EFC5",
      titleColor: C.surface,
      bodyColor: C.surface,
      titleSize: 17,
      fontSize: 15,
      bold: true,
    }
  );

  text(slide, "IMPLEMENTATION SCOPE", 0.7, 4.95, 2.6, 0.18, {
    fontSize: 8.5,
    color: C.primary,
    bold: true,
    charSpacing: 1.05,
  });
  addSmallLabel(slide, "기본 구현", "Flutter Android 앱 / 로컬 알람", 0.68, 5.38, 3.54, true, "alarm");
  addSmallLabel(slide, "동기화", "로그인 / 그룹 / Firebase", 4.43, 5.38, 3.54, true, "cloud");
  addSmallLabel(slide, "향후 확장", "Web / Linux / Windows", 8.18, 5.38, 4.48, false, "tune");

  addTag(slide, "Flutter (Dart)", 0.68, 6.43, 1.48);
  addTag(slide, "Firebase", 2.3, 6.43, 1.14);
  addTag(slide, "Kotlin / Android", 3.58, 6.43, 1.63);
  validateSlide(slide);
}

function addAlarmManagementSlide() {
  const slide = pptx.addSlide();
  addTitleBlock(
    slide,
    "평가 (3) 주요 기능 설명",
    "03",
    "주요 UI 기능 I. 알람 관리",
    "목록에서 상태를 확인하고, 편집 화면에서 알람 조건을 구체적으로 설정합니다."
  );

  addCaptureFrame(slide, "AlarmHomeScreen", "홈 화면", 0.68, 2.33, 3.54, 3.92);
  addCaptureFrame(slide, "AlarmEditorSheet", "편집 화면", 4.5, 2.33, 3.54, 3.92);

  text(slide, "USER ACTION", 8.46, 2.34, 1.7, 0.19, {
    fontSize: 8.5,
    bold: true,
    color: C.primary,
    charSpacing: 1.05,
  });
  addSmallLabel(slide, "알람 목록 확인", "시간 / 상태 / 그룹 표시", 8.43, 2.73, 4.23, true, "alarm");
  addSmallLabel(slide, "활성화 토글", "예약 켜기 또는 끄기", 8.43, 3.59, 4.23, false, "tune");
  addSmallLabel(slide, "요일 반복 설정", "월 - 일 반복 선택", 8.43, 4.45, 4.23, false, "tune");
  addSmallLabel(slide, "소리 · 진동 · 다시 알림", "스누즈 간격 / 횟수", 8.43, 5.31, 4.23, true, "bell");
  validateSlide(slide);
}

function addRingAndAccountSlide() {
  const slide = pptx.addSlide();
  addTitleBlock(
    slide,
    "평가 (3) 주요 기능 설명",
    "04",
    "주요 UI 기능 II. 울림과 계정 동기화",
    "로컬 알람은 바로 사용할 수 있고, 로그인 후에는 그룹 단위 공유 상태를 동기화합니다."
  );

  addCaptureFrame(slide, "AlarmRingScreen", "울림 화면", 0.68, 2.33, 3.42, 3.81);
  addCaptureFrame(slide, "Auth / Group Screen", "계정 관리", 4.35, 2.33, 3.42, 3.81);

  addPanel(
    slide,
    "알람 울림",
    "잠금화면 전용 화면\nDismiss: 현재 울림 종료\nSnooze: 설정 시간 뒤 재알림",
    8.13,
    2.33,
    4.53,
    1.66,
    { icon: "bell", titleSize: 12, fontSize: 9.4 }
  );
  addPanel(
    slide,
    "사용 방식",
    "로그아웃   로컬 알람 사용\n로그인 + 그룹   공유 동기화 사용",
    8.13,
    4.26,
    4.53,
    1.43,
    {
      icon: "cloud",
      fill: C.primarySoft,
      line: C.primaryContainer,
      titleSize: 12,
      fontSize: 9.5,
    }
  );
  text(slide, "Firebase 내부 처리는 다음 구조도에서 설명합니다.", 8.15, 6.01, 4.42, 0.22, {
    fontSize: 8.8,
    bold: true,
    color: C.primary,
  });
  validateSlide(slide);
}

function addSequenceNode(slide, index, title, x, y, w, options = {}) {
  shape(
    slide,
    pptx.ShapeType.roundRect,
    x,
    y,
    w,
    0.76,
    options.fill || C.surface,
    options.line || C.border,
    0.07
  );
  shape(slide, pptx.ShapeType.ellipse, x + 0.13, y + 0.23, 0.27, 0.27, C.primary, C.primary);
  text(slide, String(index), x + 0.13, y + 0.296, 0.27, 0.12, {
    fontSize: 7,
    bold: true,
    color: C.surface,
    align: "center",
  });
  text(slide, title, x + 0.52, y + 0.22, w - 0.63, 0.25, {
    fontSize: options.fontSize || 8.5,
    bold: true,
    color: options.color || C.text,
  });
}

function addClassFlowSlide() {
  const slide = pptx.addSlide();
  addTitleBlock(
    slide,
    "평가 (2) 전체 구조도 설명",
    "06",
    "주요 클래스 흐름. 알람 생성과 저장",
    "입력, 상태 변경, 저장, 기기 예약을 순서대로 연결하는 앱 내부 처리 흐름입니다."
  );

  const nodes = [
    ["AlarmEditorSheet", 0.68, 1.82],
    ["AlarmListController", 2.79, 2.02],
    ["AlarmRepository", 5.1, 1.86],
    ["AlarmNotification\nService", 7.25, 2.22],
    ["Android 로컬 예약", 10.04, 2.02],
  ];
  nodes.forEach(([title, x, w], i) => addSequenceNode(slide, i + 1, title, x, 2.68, w, { fontSize: 8.2 }));
  addConnector(slide, 2.53, 2.99, 0.18, "저장");
  addConnector(slide, 4.89, 2.99, 0.17, "요청");
  addConnector(slide, 7.0, 2.99, 0.18, "갱신");
  addConnector(slide, 9.73, 2.99, 0.2, "예약");

  text(slide, "REPOSITORY BRANCH", 0.69, 4.08, 2.55, 0.2, {
    fontSize: 8.5,
    color: C.primary,
    bold: true,
    charSpacing: 1.04,
  });
  addPanel(
    slide,
    "로그아웃 / 로컬 모드",
    "LocalDemoAlarmRepository\n-> SharedPreferences",
    0.68,
    4.47,
    5.84,
    1.47,
    { titleSize: 12, fontSize: 12, fill: C.surface, line: C.border }
  );
  addPanel(
    slide,
    "로그인 + 활성 그룹 모드",
    "FirebaseAlarmRepository\n-> Cloud Firestore",
    6.83,
    4.47,
    5.83,
    1.47,
    { titleSize: 12, fontSize: 12, fill: C.primarySoft, line: C.primaryContainer }
  );
  text(slide, "저장 위치가 달라도 Android 로컬 알람 예약 갱신은 공통으로 수행됩니다.", 0.7, 6.36, 11.95, 0.24, {
    fontSize: 10.3,
    bold: true,
    color: C.primary,
    align: "center",
  });
  validateSlide(slide);
}

function addFlowLane(slide, label, steps, y, fill, numberColor) {
  shape(slide, pptx.ShapeType.roundRect, 0.68, y, 12, 1.25, fill, fill, 0.08);
  text(slide, label, 0.9, y + 0.18, 2.28, 0.22, {
    fontSize: 9,
    color: C.primary,
    bold: true,
    charSpacing: 0.7,
  });
  steps.forEach((step, index) => {
    const x = 0.91 + index * 2.25;
    shape(slide, pptx.ShapeType.ellipse, x, y + 0.62, 0.25, 0.25, numberColor, numberColor);
    text(slide, String(index + 1), x, y + 0.677, 0.25, 0.12, {
      fontSize: 6.7,
      bold: true,
      color: C.surface,
      align: "center",
    });
    text(slide, step, x + 0.35, y + 0.59, 1.75, 0.31, {
      fontSize: 8,
      bold: true,
    });
    if (index < steps.length - 1) {
      addConnector(slide, x + 2.06, y + 0.69, 0.12, "");
    }
  });
}

function addSyncAndControlSlide() {
  const slide = pptx.addSlide();
  addTitleBlock(
    slide,
    "평가 (2) 전체 구조도 설명",
    "07",
    "기능 흐름 및 구현 진행",
    "동기화 흐름과 실제 울림 제어 흐름을 분리하여 설명합니다."
  );

  addFlowLane(
    slide,
    "변경 동기화",
    ["기기 A\n알람 수정", "Firestore", "Functions", "FCM", "기기 B\n예약 갱신"],
    2.32,
    C.primarySoft,
    C.primary
  );
  addFlowLane(
    slide,
    "울림 제어",
    ["예약 시각\n도달", "RingScreen\n소리·진동", "Dismiss", "Snooze", "상태\n전달"],
    3.88,
    C.surface,
    C.primary
  );

  addTag(slide, "구현 반영", 0.7, 5.72, 1.12);
  text(slide, "Android UI / 로컬 예약 / 로그인·그룹 코드", 1.97, 5.77, 3.45, 0.2, {
    fontSize: 8.3,
    bold: true,
  });
  addTag(slide, "확인 필요", 5.67, 5.72, 1.12);
  text(slide, "두 기기 간 제어 동기화 안정성", 6.94, 5.77, 2.35, 0.2, {
    fontSize: 8.3,
    bold: true,
  });
  addTag(slide, "향후 확장", 9.53, 5.72, 1.14);
  text(slide, "Web / Linux / Windows", 10.81, 5.77, 1.62, 0.2, {
    fontSize: 8.1,
    bold: true,
  });
  text(slide, "이미 기기에 예약된 알람은 네트워크가 없어도 울릴 수 있으나, 다른 기기의 새 변경 반영에는 네트워크가 필요합니다.", 0.7, 6.45, 11.9, 0.23, {
    fontSize: 9,
    color: C.muted,
    align: "center",
  });
  validateSlide(slide);
}

function addCodeCard(slide, value, x, y, w, active = false) {
  shape(
    slide,
    pptx.ShapeType.roundRect,
    x,
    y,
    w,
    0.48,
    active ? C.primarySoft : C.surface,
    active ? C.primaryContainer : C.border,
    0.05
  );
  text(slide, value, x + 0.17, y + 0.15, w - 0.34, 0.18, {
    fontSize: 8.5,
    bold: true,
    color: active ? C.primary : C.text,
  });
}

function addSecuritySlide() {
  const slide = pptx.addSlide();
  addTitleBlock(
    slide,
    "평가 (2) 전체 구조도 설명",
    "08",
    "데이터 구조와 보안",
    "그룹 기반 접근 제어와 등록 기기 전달 범위를 핵심 구조로 설명합니다."
  );

  text(slide, "FIRESTORE COLLECTIONS", 0.7, 2.32, 2.56, 0.19, {
    fontSize: 8.5,
    color: C.primary,
    bold: true,
    charSpacing: 1.02,
  });
  addCodeCard(slide, "users/{uid}", 0.68, 2.76, 5.2, false);
  addCodeCard(slide, "groups/{groupId}/members/{uid}", 0.68, 3.38, 5.2, true);
  addCodeCard(slide, "groups/{groupId}/alarms/{alarmId}", 0.68, 4.0, 5.2, true);
  addCodeCard(slide, "groups/{groupId}/devices/{deviceId}", 0.68, 4.62, 5.2, false);
  addCodeCard(slide, "groups/{groupId}/commands/{commandId}", 0.68, 5.24, 5.2, false);
  addCodeCard(slide, "groupSecrets/{groupId}", 0.68, 5.86, 5.2, false);

  text(slide, "SECURITY POINTS", 6.39, 2.32, 2.32, 0.19, {
    fontSize: 8.5,
    color: C.primary,
    bold: true,
    charSpacing: 1.02,
  });
  addPanel(slide, "Authentication", "로그인 사용자 식별", 6.37, 2.76, 6.29, 0.9, {
    icon: "shield",
    titleSize: 11,
    fontSize: 8.5,
  });
  addPanel(slide, "Firestore Rules", "그룹 멤버만 공유 알람 접근", 6.37, 3.87, 6.29, 0.9, {
    icon: "shield",
    titleSize: 11,
    fontSize: 8.5,
    fill: C.primarySoft,
    line: C.primaryContainer,
  });
  addPanel(slide, "Functions / FCM", "변경 내용을 등록된 Android 기기로 전달", 6.37, 4.98, 6.29, 0.9, {
    icon: "cloud",
    titleSize: 11,
    fontSize: 8.5,
  });
  text(slide, "초대 코드는 해시 저장   /   FCM 토큰은 등록 기기 문서에서 관리", 6.42, 6.27, 6.16, 0.24, {
    fontSize: 9.1,
    color: C.primary,
    bold: true,
  });
  validateSlide(slide);
}

async function writeFullDeck() {
  addCoverSlide("01", "평가 (1) 프로그램 개요 및 설명");
  addOverviewSlide();
  addAlarmManagementSlide();
  addRingAndAccountSlide();
  addArchitectureSlide("05", "평가 (2) 전체 구조도 설명");
  addClassFlowSlide();
  addSyncAndControlSlide();
  addSecuritySlide();
  await pptx.writeFile({ fileName: OUTPUT });
  console.log(`PPTX 생성 완료: ${OUTPUT}`);
}

writeFullDeck().catch((error) => {
  console.error("PPTX 생성 실패:", error);
  process.exitCode = 1;
});
