"use strict";

const path = require("path");
const PptxGenJS = require("pptxgenjs");
const {
  warnIfSlideHasOverlaps,
  warnIfSlideElementsOutOfBounds,
} = require("./pptxgenjs_helpers/layout");

const pptx = new PptxGenJS();
const outputPath = path.join(__dirname, "Lets_alarm_발표자료_텍스트초안.pptx");

const FONT = "Pretendard";
const MONO = "D2Coding";
const C = {
  primary: "386948",
  primaryContainer: "B9EFC5",
  background: "F7FAF4",
  surface: "FFFFFF",
  text: "2C342E",
  muted: "56635B",
  border: "D6E3D9",
  accent: "F5A623",
  firebase: "FFF3CD",
};

pptx.layout = "LAYOUT_WIDE";
pptx.author = "6조";
pptx.company = "UI/UX 프로그래밍";
pptx.subject = "Android 우선 실시간 동기화 알람 앱 발표";
pptx.title = "Let's alarm (렛츠알람)";
pptx.lang = "ko-KR";
pptx.theme = {
  headFontFace: FONT,
  bodyFontFace: FONT,
  lang: "ko-KR",
};
pptx.defineLayout({ name: "LET_WIDE", width: 13.333, height: 7.5 });
pptx.layout = "LET_WIDE";

function addBackground(slide, section, number) {
  slide.background = { color: C.background };
  slide.addShape(pptx.ShapeType.line, {
    x: 0.55,
    y: 0.58,
    w: 0.24,
    h: 0,
    line: { color: C.primary, width: 3 },
  });
  slide.addText(section, {
    x: 0.9,
    y: 0.4,
    w: 3.5,
    h: 0.3,
    fontFace: FONT,
    fontSize: 10,
    bold: true,
    color: C.primary,
    charSpacing: 0,
    margin: 0,
  });
  slide.addText(String(number).padStart(2, "0"), {
    x: 12.25,
    y: 7.05,
    w: 0.48,
    h: 0.25,
    fontFace: FONT,
    fontSize: 10,
    bold: true,
    color: C.primary,
    align: "right",
    margin: 0,
  });
  slide.addText("Let's alarm | UI/UX 프로그래밍 6조", {
    x: 0.58,
    y: 7.05,
    w: 4,
    h: 0.25,
    fontFace: FONT,
    fontSize: 8,
    color: C.muted,
    margin: 0,
  });
}

function addTitle(slide, title, lead) {
  slide.addText(title, {
    x: 0.58,
    y: 0.9,
    w: 12,
    h: 0.55,
    fontFace: FONT,
    fontSize: 26,
    bold: true,
    color: C.text,
    charSpacing: 0,
    margin: 0,
  });
  if (lead) {
    slide.addText(lead, {
      x: 0.6,
      y: 1.59,
      w: 11.9,
      h: 0.44,
      fontFace: FONT,
      fontSize: 13,
      color: C.primary,
      bold: true,
      charSpacing: 0,
      margin: 0,
    });
  }
}

function addPill(slide, text, x, y, w, fill = C.primaryContainer) {
  slide.addShape(pptx.ShapeType.roundRect, {
    x,
    y,
    w,
    h: 0.35,
    rectRadius: 0.08,
    fill: { color: fill },
    line: { color: fill },
    radius: 0.08,
  });
  slide.addText(text, {
    x: x + 0.13,
    y: y + 0.1,
    w: w - 0.26,
    h: 0.15,
    fontFace: FONT,
    fontSize: 9,
    bold: true,
    color: C.primary,
    align: "center",
    margin: 0,
  });
}

function addCard(slide, x, y, w, h, title, text, options = {}) {
  slide.addShape(pptx.ShapeType.roundRect, {
    x,
    y,
    w,
    h,
    rectRadius: 0.08,
    fill: { color: options.fill || C.surface },
    line: { color: options.line || C.border, width: 1 },
    radius: 0.08,
  });
  slide.addText(title, {
    x: x + 0.22,
    y: y + 0.2,
    w: w - 0.44,
    h: 0.28,
    fontFace: FONT,
    fontSize: options.titleSize || 13,
    bold: true,
    color: options.titleColor || C.text,
    margin: 0,
  });
  slide.addText(text, {
    x: x + 0.22,
    y: y + 0.65,
    w: w - 0.44,
    h: h - 0.83,
    fontFace: options.mono ? MONO : FONT,
    fontSize: options.fontSize || 11,
    color: C.muted,
    breakLine: false,
    valign: "top",
    paraSpaceAfterPt: 7,
    margin: 0,
    charSpacing: 0,
  });
}

function addNumberRow(slide, index, text, x, y, w, options = {}) {
  slide.addShape(pptx.ShapeType.roundRect, {
    x,
    y: y + 0.02,
    w: 0.32,
    h: 0.29,
    rectRadius: 0.04,
    fill: { color: options.fill || C.primaryContainer },
    line: { color: options.fill || C.primaryContainer },
    radius: 0.04,
  });
  slide.addText(String(index), {
    x,
    y: y + 0.095,
    w: 0.32,
    h: 0.13,
    fontFace: FONT,
    fontSize: 8,
    bold: true,
    color: C.primary,
    align: "center",
    margin: 0,
  });
  slide.addText(text, {
    x: x + 0.45,
    y,
    w: w - 0.45,
    h: options.h || 0.39,
    fontFace: FONT,
    fontSize: options.fontSize || 11,
    color: C.text,
    margin: 0,
    charSpacing: 0,
  });
}

function addPlaceholder(slide, label, x, y, w, h) {
  slide.addShape(pptx.ShapeType.roundRect, {
    x,
    y,
    w,
    h,
    rectRadius: 0.08,
    fill: { color: "EEF5F0" },
    line: { color: C.border, dash: "dash", width: 1 },
    radius: 0.08,
  });
  slide.addText(`[ ${label} 삽입 예정 ]`, {
    x: x + 0.15,
    y: y + h / 2 - 0.12,
    w: w - 0.3,
    h: 0.24,
    fontFace: FONT,
    fontSize: 10,
    color: C.muted,
    bold: true,
    align: "center",
    margin: 0,
  });
}

function validateSlide(slide) {
  warnIfSlideHasOverlaps(slide, pptx, {
    muteContainment: true,
    ignoreLines: true,
    ignoreDecorativeShapes: true,
  });
  warnIfSlideElementsOutOfBounds(slide, pptx);
}

// Slide 1: 표지 및 역할
{
  const slide = pptx.addSlide();
  addBackground(slide, "평가 (1) 프로그램 개요 및 설명", 1);
  slide.addText("Let's alarm", {
    x: 0.62,
    y: 1.14,
    w: 6.2,
    h: 0.77,
    fontFace: FONT,
    fontSize: 40,
    bold: true,
    color: C.text,
    margin: 0,
    charSpacing: 0,
  });
  slide.addText("렛츠알람", {
    x: 0.65,
    y: 2.02,
    w: 3.2,
    h: 0.48,
    fontFace: FONT,
    fontSize: 20,
    color: C.primary,
    bold: true,
    margin: 0,
  });
  slide.addText("Android 우선 실시간 동기화 알람 앱", {
    x: 0.65,
    y: 2.72,
    w: 6.4,
    h: 0.38,
    fontFace: FONT,
    fontSize: 17,
    color: C.text,
    margin: 0,
  });
  slide.addText("여러 Android 기기에서 같은 알람 변경 상태를 공유하는 Flutter 알람 앱", {
    x: 0.65,
    y: 3.34,
    w: 6.15,
    h: 0.62,
    fontFace: FONT,
    fontSize: 13,
    color: C.muted,
    margin: 0,
  });
  addPill(slide, "UI/UX 프로그래밍", 0.65, 4.24, 1.7);
  addPill(slide, "6조", 2.48, 4.24, 0.72);
  addPlaceholder(slide, "실제 앱 홈 화면", 8.34, 1.08, 3.32, 5.55);
  addCard(
    slide,
    0.65,
    5.04,
    6.3,
    1.2,
    "팀원 및 역할",
    "김준형  계획·디자인·기능 구현·테스트    양상현  자료조사·발표자료·테스트\n정준호  코드 작성·기능 구현·테스트       김민준  UI/UX 기획·요구사항 정의·테스트",
    { fontSize: 9.7 }
  );
  validateSlide(slide);
}

// Slide 2: 개요 및 개발 목표
{
  const slide = pptx.addSlide();
  addBackground(slide, "평가 (1) 프로그램 개요 및 설명", 2);
  addTitle(slide, "프로그램 개요 및 개발 목표", "기기마다 분리된 알람 상태를 Android 중심의 공유 흐름으로 연결합니다.");
  addCard(
    slide,
    0.62,
    2.3,
    5.75,
    2.05,
    "문제",
    "기기마다 알람 설정이 따로 관리되어\n해제와 스누즈 상태를 함께 반영하기 어렵습니다.",
    { fontSize: 15 }
  );
  addCard(
    slide,
    6.95,
    2.3,
    5.75,
    2.05,
    "해결 방향",
    "Android 알람 기능을 먼저 완성하고\nFirebase로 기기 간 변경 상태를 공유합니다.",
    { fill: C.primaryContainer, line: C.primaryContainer, fontSize: 15 }
  );
  addCard(
    slide,
    0.62,
    4.78,
    6,
    1.34,
    "기본 구현",
    "Flutter Android 앱 / 로컬 알람 / Firebase 로그인·그룹 동기화",
    { fontSize: 11 }
  );
  addCard(
    slide,
    6.87,
    4.78,
    5.83,
    1.34,
    "향후 확장",
    "Web / Linux / Windows",
    { fontSize: 11 }
  );
  addPill(slide, "Flutter (Dart)", 0.65, 6.45, 1.55);
  addPill(slide, "Firebase", 2.32, 6.45, 1.18);
  addPill(slide, "Kotlin (Android)", 3.63, 6.45, 1.72);
  validateSlide(slide);
}

// Slide 3: UI 알람 관리
{
  const slide = pptx.addSlide();
  addBackground(slide, "평가 (3) 주요 기능 설명", 3);
  addTitle(slide, "주요 UI 기능 I. 알람 관리", "사용자가 자주 조작하는 목록과 편집 기능을 Android 화면에 집중했습니다.");
  addPlaceholder(slide, "AlarmHomeScreen 캡처", 0.63, 2.25, 4.25, 3.65);
  addPlaceholder(slide, "AlarmEditorSheet 캡처", 5.18, 2.25, 4.25, 3.65);
  addCard(
    slide,
    9.76,
    2.25,
    2.93,
    3.65,
    "표시할 라벨",
    "홈 화면\n알람 목록 확인\n활성화 토글\n동기화 상태\n\n편집 화면\n이름과 시간\n요일 반복\n소리·진동\n스누즈 설정",
    { fontSize: 10 }
  );
  slide.addText("실제 앱 화면 캡처로 조작 위치를 설명", {
    x: 0.65,
    y: 6.3,
    w: 8.7,
    h: 0.3,
    fontFace: FONT,
    fontSize: 12,
    color: C.primary,
    bold: true,
    margin: 0,
  });
  validateSlide(slide);
}

// Slide 4: UI 울림 및 동기화
{
  const slide = pptx.addSlide();
  addBackground(slide, "평가 (3) 주요 기능 설명", 4);
  addTitle(slide, "주요 UI 기능 II. 울림과 계정 동기화", "로컬 기본 사용과 로그인 후 공유 동기화를 한 앱 안에서 지원합니다.");
  addPlaceholder(slide, "AlarmRingScreen 캡처", 0.63, 2.3, 4.05, 3.83);
  addPlaceholder(slide, "로그인 및 그룹 화면 캡처", 4.98, 2.3, 4.05, 3.83);
  addCard(
    slide,
    9.37,
    2.3,
    3.34,
    1.78,
    "울림 화면",
    "잠금화면 표시\nDismiss 종료 / Snooze 재알림",
    { fontSize: 11 }
  );
  addCard(
    slide,
    9.37,
    4.35,
    3.34,
    1.78,
    "계정과 그룹",
    "로그아웃: 로컬 알람\n로그인 + 그룹: 공유 동기화",
    { fontSize: 11, fill: C.primaryContainer, line: C.primaryContainer }
  );
  validateSlide(slide);
}

// Slide 5: 전체 구조
{
  const slide = pptx.addSlide();
  addBackground(slide, "평가 (2) 전체 구조도 설명", 5);
  addTitle(slide, "Firebase 기반 동기화 알람 구조", "FCM은 동기화 신호를 전달하고, 실제 정각 울림은 Android 로컬 예약이 담당합니다.");
  addPlaceholder(slide, "FigJam 전체 시스템 구조도", 0.63, 2.15, 12.07, 2.65);
  addCard(
    slide,
    0.63,
    5.14,
    12.07,
    1.06,
    "발표용 흐름",
    "사용자  ->  기기 A: Flutter Android 앱  ->  Cloud Firestore  ->  Cloud Functions  ->  FCM  ->  기기 B: Flutter Android 앱",
    { fontSize: 12, mono: true, fill: C.firebase, line: C.accent }
  );
  slide.addText(
    "기기 A·B 내부: Android 로컬 알람 예약 / 정각 울림     |     Authentication: 로그인 사용자 식별     |     Firestore: 공유 알람 원본 데이터",
    {
      x: 0.65,
      y: 6.5,
      w: 12.05,
      h: 0.27,
      fontFace: FONT,
      fontSize: 9.5,
      color: C.muted,
      margin: 0,
      align: "center",
    }
  );
  validateSlide(slide);
}

// Slide 6: 클래스 흐름
{
  const slide = pptx.addSlide();
  addBackground(slide, "평가 (2) 전체 구조도 설명", 6);
  addTitle(slide, "주요 클래스 흐름. 알람 생성과 저장", "저장 방식은 로그인 상태에 따라 분기되지만, 로컬 예약 갱신은 공통으로 수행됩니다.");
  addCard(
    slide,
    0.63,
    2.18,
    12.05,
    1.05,
    "사용자 입력에서 예약까지",
    "사용자 -> AlarmEditorSheet -> AlarmListController -> AlarmRepository -> AlarmNotificationService -> Android 로컬 알람 예약",
    { fontSize: 11, mono: true, fill: C.primaryContainer, line: C.primaryContainer }
  );
  addCard(
    slide,
    0.63,
    3.66,
    5.82,
    1.87,
    "로그아웃 / 로컬 모드",
    "LocalDemoAlarmRepository\n-> SharedPreferences",
    { fontSize: 15, mono: true }
  );
  addCard(
    slide,
    6.84,
    3.66,
    5.84,
    1.87,
    "로그인 및 활성 그룹 모드",
    "FirebaseAlarmRepository\n-> Cloud Firestore",
    { fontSize: 15, mono: true, fill: C.firebase, line: C.accent }
  );
  slide.addText("Repository가 저장 위치를 결정하고, 알림 서비스가 기기 예약을 갱신합니다.", {
    x: 0.66,
    y: 6.02,
    w: 11.9,
    h: 0.34,
    fontFace: FONT,
    fontSize: 13,
    bold: true,
    color: C.primary,
    margin: 0,
  });
  validateSlide(slide);
}

// Slide 7: 기능 흐름 및 진행
{
  const slide = pptx.addSlide();
  addBackground(slide, "평가 (2) 전체 구조도 설명", 7);
  addTitle(slide, "기능 흐름 및 구현 진행", "이미 예약된 알람은 오프라인에서도 울릴 수 있지만 새 변경 반영에는 네트워크가 필요합니다.");
  addCard(
    slide,
    0.62,
    2.13,
    12.06,
    1.28,
    "기기 간 변경 동기화",
    "기기 A 알람 수정 -> Firestore -> Cloud Functions -> FCM -> 기기 B AlarmNotificationService -> Android 로컬 예약 갱신",
    { fontSize: 10.7, mono: true }
  );
  addCard(
    slide,
    0.62,
    3.64,
    12.06,
    1.28,
    "알람 발생 이후 제어",
    "Android 예약 시간 도달 -> AlarmRingScreen / 소리 / 진동 -> Dismiss 종료 또는 Snooze 재예약",
    { fontSize: 11, mono: true, fill: C.firebase, line: C.accent }
  );
  addCard(
    slide,
    0.62,
    5.27,
    12.06,
    1.18,
    "진행 상태",
    "구현 반영: Android 기본 UI, 로컬 예약, 로그인/그룹 동기화 코드    |    실기기 확인 필요: 두 Android 기기 간 제어 동기화 안정성    |    향후 확장: Web/Linux/Windows",
    { fontSize: 9.7, fill: C.primaryContainer, line: C.primaryContainer }
  );
  validateSlide(slide);
}

// Slide 8: 데이터 구조와 보안
{
  const slide = pptx.addSlide();
  addBackground(slide, "평가 (2) 전체 구조도 설명", 8);
  addTitle(slide, "데이터 구조와 보안", "공유 데이터 접근은 그룹 멤버로 제한하고, 변경 전달은 등록된 기기만 대상으로 합니다.");
  addCard(
    slide,
    0.63,
    2.08,
    5.34,
    4.15,
    "Firestore 핵심 구조",
    "users/{uid}\ngroups/{groupId}/members/{uid}\ngroups/{groupId}/alarms/{alarmId}\ngroups/{groupId}/devices/{deviceId}\ngroups/{groupId}/commands/{commandId}\ngroupSecrets/{groupId}",
    { fontSize: 12, mono: true }
  );
  addCard(
    slide,
    6.28,
    2.08,
    6.42,
    1.55,
    "보안 원칙",
    "그룹 멤버만 그룹 데이터 접근  /  초대 코드는 해시 저장  /  FCM 토큰은 등록 기기 문서에서 관리",
    { fontSize: 10.5, fill: C.firebase, line: C.accent }
  );
  addNumberRow(slide, 1, "Authentication   로그인 사용자 식별", 6.47, 4.09, 5.92);
  addNumberRow(slide, 2, "Firestore Rules   그룹 멤버만 공유 알람 접근", 6.47, 4.67, 5.92);
  addNumberRow(slide, 3, "Functions / FCM   변경 내용을 Android 기기로 전달", 6.47, 5.25, 5.92);
  validateSlide(slide);
}

pptx
  .writeFile({ fileName: outputPath })
  .then(() => console.log(`PPTX 생성 완료: ${outputPath}`))
  .catch((error) => {
    console.error("PPTX 생성 실패:", error);
    process.exitCode = 1;
  });
