"use strict";

const path = require("path");
const PptxGenJS = require("pptxgenjs");
const { svgToDataUri } = require("./pptxgenjs_helpers/svg");
const {
  warnIfSlideHasOverlaps,
  warnIfSlideElementsOutOfBounds,
} = require("./pptxgenjs_helpers/layout");

const pptx = new PptxGenJS();
const OUTPUT = path.join(__dirname, "Lets_alarm_발표자료_시각시안_3장.pptx");

const TITLE_FONT = "KIMM_Bold";
const TITLE_LIGHT = "KIMM_Light";
const BODY_FONT = "A2Z";

const C = {
  primary: "386948",
  primaryDark: "15382A",
  primaryContainer: "B9EFC5",
  primarySoft: "E7F7EB",
  background: "F7FAF4",
  surface: "FFFFFF",
  text: "2C342E",
  muted: "647168",
  border: "DAE6DD",
  line: "B8C9BC",
  firebase: "FFF3CD",
  firebaseLine: "F0BE53",
};

pptx.defineLayout({ name: "ALARM_WIDE", width: 13.333, height: 7.5 });
pptx.layout = "ALARM_WIDE";
pptx.author = "6조";
pptx.company = "UI/UX 프로그래밍";
pptx.subject = "Let's alarm 발표자료 시각 시안";
pptx.title = "Let's alarm - visual sample";
pptx.lang = "ko-KR";
pptx.theme = {
  headFontFace: TITLE_FONT,
  bodyFontFace: BODY_FONT,
  lang: "ko-KR",
};

function text(slide, value, x, y, w, h, options = {}) {
  slide.addText(value, {
    x,
    y,
    w,
    h,
    fontFace: BODY_FONT,
    fontSize: 11,
    color: C.text,
    margin: 0,
    charSpacing: 0,
    breakLine: false,
    valign: "mid",
    paraSpaceAfterPt: 0,
    ...options,
  });
}

function shape(slide, type, x, y, w, h, fill, line = fill, radius = 0.08) {
  slide.addShape(type, {
    x,
    y,
    w,
    h,
    rectRadius: radius,
    radius,
    fill: { color: fill },
    line: { color: line, width: 1 },
  });
}

function gradientSvg(width, height, from, to, orientation = "horizontal") {
  const vector =
    orientation === "vertical"
      ? { x1: "0", y1: "0", x2: "0", y2: "1" }
      : { x1: "0", y1: "0", x2: "1", y2: "0" };
  return svgToDataUri(`
    <svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
      <defs>
        <linearGradient id="g" x1="${vector.x1}" y1="${vector.y1}" x2="${vector.x2}" y2="${vector.y2}">
          <stop offset="0%" stop-color="#${from}"/>
          <stop offset="100%" stop-color="#${to}"/>
        </linearGradient>
      </defs>
      <rect width="${width}" height="${height}" fill="url(#g)"/>
    </svg>`);
}

function lineIconSvg(type, stroke = `#${C.primary}`) {
  const paths = {
    alarm: `<circle cx="24" cy="26" r="14"/><path d="M24 19v8l6 4"/><path d="M13 9 8 14M35 9l5 5M15 43l-3 3M33 43l3 3"/>`,
    tune: `<path d="M8 14h32M8 26h32M8 38h32"/><circle cx="18" cy="14" r="4" fill="#F7FAF4"/><circle cx="31" cy="26" r="4" fill="#F7FAF4"/><circle cx="22" cy="38" r="4" fill="#F7FAF4"/>`,
    cloud: `<path d="M13 36h23a9 9 0 0 0 1-18 13 13 0 0 0-25-1A10 10 0 0 0 13 36Z"/><path d="M19 27h13M27 22l5 5-5 5"/>`,
    bell: `<path d="M13 35h22l-3-5v-9a8 8 0 0 0-16 0v9Z"/><path d="M21 39a4 4 0 0 0 6 0"/>`,
    shield: `<path d="M24 7 38 13v11c0 10-7 15-14 18-7-3-14-8-14-18V13Z"/><path d="m18 25 4 4 8-9"/>`,
  };
  return svgToDataUri(`
    <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
      <g fill="none" stroke="${stroke}" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">
        ${paths[type]}
      </g>
    </svg>`);
}

function addIcon(slide, type, x, y, size = 0.42, color) {
  slide.addImage({ data: lineIconSvg(type, color), x, y, w: size, h: size });
}

function addFullBackground(slide, dark = false) {
  slide.background = { color: dark ? C.primaryDark : C.background };
  if (dark) {
    slide.addImage({
      data: gradientSvg(1100, 520, "15382A", "386948"),
      x: 0,
      y: 0,
      w: 13.333,
      h: 7.5,
    });
  } else {
    slide.addImage({
      data: gradientSvg(920, 400, C.background, C.primaryContainer),
      x: 7.35,
      y: 0,
      w: 5.983,
      h: 7.5,
    });
    slide.addShape(pptx.ShapeType.rect, {
      x: 0,
      y: 0,
      w: 8.56,
      h: 7.5,
      fill: { color: C.background, transparency: 0 },
      line: { color: C.background, transparency: 100 },
    });
  }
}

function addMeta(slide, section, page, dark = false) {
  const base = dark ? "E4F0E6" : C.muted;
  const accent = dark ? C.primaryContainer : C.primary;
  text(slide, "LET'S ALARM", 0.66, 0.42, 1.5, 0.2, {
    fontFace: BODY_FONT,
    fontSize: 9,
    bold: true,
    color: accent,
    charSpacing: 1.4,
  });
  text(slide, section, 10.1, 0.42, 2.4, 0.2, {
    fontSize: 8,
    color: base,
    align: "right",
    bold: true,
  });
  slide.addShape(pptx.ShapeType.line, {
    x: 0.66,
    y: 0.77,
    w: 12.01,
    h: 0,
    line: { color: dark ? "527768" : C.border, width: 1 },
  });
  text(slide, "UI/UX PROGRAMMING   /   TEAM 06", 0.66, 7.02, 4.1, 0.18, {
    fontSize: 8,
    color: base,
    charSpacing: 1.15,
  });
  text(slide, page, 12.2, 7.02, 0.45, 0.18, {
    fontSize: 9,
    bold: true,
    color: accent,
    align: "right",
  });
}

function addTag(slide, label, x, y, w, dark = false) {
  shape(
    slide,
    pptx.ShapeType.roundRect,
    x,
    y,
    w,
    0.32,
    dark ? "335C4E" : C.primarySoft,
    dark ? "335C4E" : C.primarySoft,
    0.08
  );
  text(slide, label, x + 0.12, y + 0.065, w - 0.24, 0.18, {
    fontSize: 8.5,
    bold: true,
    color: dark ? C.primaryContainer : C.primary,
    align: "center",
  });
}

function addPhonePlaceholder(slide, x, y, w, h, dark = false) {
  shape(slide, pptx.ShapeType.roundRect, x, y, w, h, dark ? "173127" : "FFFFFF", dark ? "547264" : "D3E0D7", 0.18);
  shape(slide, pptx.ShapeType.roundRect, x + 0.09, y + 0.1, w - 0.18, h - 0.2, dark ? "F7FAF4" : "F7FAF4", dark ? "F7FAF4" : "F7FAF4", 0.13);
  shape(slide, pptx.ShapeType.roundRect, x + w / 2 - 0.25, y + 0.17, 0.5, 0.08, "D2DDD5", "D2DDD5", 0.03);
  text(slide, "07:30", x + 0.29, y + 0.58, w - 0.58, 0.33, {
    fontFace: TITLE_FONT,
    fontSize: 17,
    color: C.text,
    align: "center",
    bold: true,
  });
  text(slide, "평일 아침", x + 0.29, y + 0.96, w - 0.58, 0.18, {
    fontSize: 8,
    color: C.muted,
    align: "center",
  });
  shape(slide, pptx.ShapeType.roundRect, x + 0.22, y + 1.43, w - 0.44, 0.67, C.surface, C.border, 0.08);
  text(slide, "06:40  기상 알람", x + 0.36, y + 1.58, w - 0.72, 0.16, {
    fontSize: 8,
    bold: true,
  });
  shape(slide, pptx.ShapeType.roundRect, x + w - 0.67, y + 1.64, 0.29, 0.12, C.primary, C.primary, 0.05);
  shape(slide, pptx.ShapeType.roundRect, x + 0.22, y + 2.23, w - 0.44, 0.67, C.surface, C.border, 0.08);
  text(slide, "07:30  회의 준비", x + 0.36, y + 2.38, w - 0.72, 0.16, {
    fontSize: 8,
    bold: true,
  });
  shape(slide, pptx.ShapeType.roundRect, x + w - 0.67, y + 2.44, 0.29, 0.12, C.primaryContainer, C.primaryContainer, 0.05);
  shape(slide, pptx.ShapeType.ellipse, x + w - 0.65, y + h - 0.83, 0.37, 0.37, C.primary, C.primary);
  text(slide, "+", x + w - 0.65, y + h - 0.75, 0.37, 0.16, {
    fontFace: BODY_FONT,
    fontSize: 12,
    bold: true,
    color: C.surface,
    align: "center",
  });
  text(slide, "실제 화면 교체 영역", x + 0.22, y + h - 0.4, w - 0.85, 0.16, {
    fontSize: 7,
    color: C.muted,
  });
}

function validateSlide(slide) {
  // Background gradients, icon glyphs, and card text are deliberately layered.
  // Enable the overlap diagnostic only while auditing that composition.
  if (process.env.PPTX_CHECK_OVERLAPS === "1") {
    warnIfSlideHasOverlaps(slide, pptx, {
      muteContainment: true,
      ignoreLines: true,
      ignoreDecorativeShapes: true,
    });
  }
  warnIfSlideElementsOutOfBounds(slide, pptx);
}

function addCoverSlide(page = "01", section = "PROJECT OVERVIEW") {
  const slide = pptx.addSlide();
  addFullBackground(slide, false);
  addMeta(slide, section, page);

  text(slide, "Android first", 0.66, 1.24, 2.3, 0.27, {
    fontSize: 10,
    color: C.primary,
    bold: true,
    charSpacing: 1.35,
  });
  text(slide, "Let's alarm", 0.64, 1.73, 6.1, 0.8, {
    fontFace: TITLE_FONT,
    fontSize: 42,
    bold: true,
    color: C.text,
  });
  text(slide, "렛츠알람", 0.68, 2.67, 2.6, 0.32, {
    fontFace: TITLE_FONT,
    fontSize: 18,
    bold: true,
    color: C.primary,
  });
  text(slide, "여러 Android 기기의 알람 변경 상태를 공유하는\nFlutter 기반 실시간 동기화 알람 앱", 0.67, 3.44, 5.95, 0.7, {
    fontSize: 15,
    color: C.text,
    bold: true,
    valign: "top",
    breakLine: false,
  });
  text(slide, "Firebase로 변경 내용을 연결하고, 실제 정각 울림은 각 기기의 로컬 예약이 담당합니다.", 0.68, 4.45, 5.75, 0.42, {
    fontSize: 10.5,
    color: C.muted,
  });

  addTag(slide, "Flutter / Dart", 0.67, 5.3, 1.37);
  addTag(slide, "Firebase", 2.16, 5.3, 1.12);
  addTag(slide, "Android / Kotlin", 3.4, 5.3, 1.58);

  text(slide, "김준형  계획·디자인·기능 구현·테스트", 0.68, 6.16, 3.42, 0.2, {
    fontSize: 8.5,
    color: C.muted,
    bold: true,
  });
  text(slide, "양상현  자료조사·발표자료·테스트", 4.07, 6.16, 3.04, 0.2, {
    fontSize: 8.5,
    color: C.muted,
    bold: true,
  });
  text(slide, "정준호  코드 작성·기능 구현·테스트     김민준  UI/UX 기획·요구사항 정의·테스트", 0.68, 6.47, 6.92, 0.2, {
    fontSize: 8.5,
    color: C.muted,
    bold: true,
  });

  addPhonePlaceholder(slide, 9.37, 1.13, 2.65, 5.6);
  text(slide, "01", 8.75, 1.24, 0.42, 0.42, {
    fontFace: TITLE_LIGHT,
    fontSize: 21,
    color: C.primary,
  });
  slide.addShape(pptx.ShapeType.line, {
    x: 8.78,
    y: 1.76,
    w: 0.42,
    h: 0,
    line: { color: C.primary, width: 1.4 },
  });
  validateSlide(slide);
}

function addFeatureSlide(
  page = "02",
  section = "UI FUNCTION",
  heading = "주요 UI 기능",
  lead = "알람 관리부터 울림 제어와 동기화 상태까지, 조작 중심으로 설계했습니다."
) {
  const slide = pptx.addSlide();
  addFullBackground(slide, false);
  addMeta(slide, section, page);

  text(slide, heading, 0.65, 1.1, 7.2, 0.5, {
    fontFace: TITLE_FONT,
    fontSize: 28,
    bold: true,
  });
  text(slide, lead, 0.67, 1.7, 7.2, 0.3, {
    fontSize: 11,
    color: C.muted,
  });

  text(slide, "01  ALARM LIST", 0.75, 2.33, 2.02, 0.2, {
    fontSize: 8.5,
    bold: true,
    color: C.primary,
    charSpacing: 1,
  });
  addPhonePlaceholder(slide, 0.72, 2.7, 2.2, 3.56);
  text(slide, "AlarmHomeScreen", 0.72, 6.49, 2.2, 0.2, {
    fontSize: 8,
    color: C.muted,
    align: "center",
  });

  text(slide, "02  EDIT & RING", 3.31, 2.33, 2.08, 0.2, {
    fontSize: 8.5,
    bold: true,
    color: C.primary,
    charSpacing: 1,
  });
  shape(slide, pptx.ShapeType.roundRect, 3.28, 2.7, 2.2, 3.56, C.surface, C.border, 0.13);
  text(slide, "알람 편집", 3.52, 3.04, 1.72, 0.25, {
    fontFace: TITLE_FONT,
    fontSize: 13,
    bold: true,
  });
  text(slide, "07 : 30", 3.52, 3.46, 1.72, 0.42, {
    fontFace: TITLE_FONT,
    fontSize: 20,
    color: C.primary,
    bold: true,
  });
  addTag(slide, "월", 3.52, 4.17, 0.29);
  addTag(slide, "화", 3.87, 4.17, 0.29);
  addTag(slide, "수", 4.22, 4.17, 0.29);
  addTag(slide, "목", 4.57, 4.17, 0.29);
  shape(slide, pptx.ShapeType.line, 3.52, 4.72, 1.74, 0, C.border, C.border);
  text(slide, "소리      ON", 3.52, 4.96, 1.72, 0.18, { fontSize: 8.5, bold: true });
  text(slide, "다시 알림   5분 / 2회", 3.52, 5.33, 1.72, 0.18, { fontSize: 8.5, bold: true });
  shape(slide, pptx.ShapeType.roundRect, 3.52, 5.73, 1.72, 0.26, C.primary, C.primary, 0.06);
  text(slide, "저장", 3.52, 5.785, 1.72, 0.13, {
    fontSize: 8,
    bold: true,
    color: C.surface,
    align: "center",
  });
  text(slide, "AlarmEditorSheet", 3.28, 6.49, 2.2, 0.2, {
    fontSize: 8,
    color: C.muted,
    align: "center",
  });

  text(slide, "FUNCTION FLOW", 6.18, 2.33, 2.42, 0.2, {
    fontSize: 8.5,
    bold: true,
    color: C.primary,
    charSpacing: 1,
  });
  const items = [
    ["alarm", "알람 관리", "생성 · 수정 · 활성화 토글"],
    ["tune", "세부 설정", "요일 · 소리 · 진동 · 스누즈"],
    ["bell", "울림 제어", "Dismiss / Snooze"],
    ["cloud", "그룹 동기화", "로그인 후 공유 알람 반영"],
  ];
  items.forEach(([icon, title, body], index) => {
    const y = 2.72 + index * 0.9;
    shape(slide, pptx.ShapeType.roundRect, 6.16, y, 6.12, 0.72, index === 3 ? C.primarySoft : C.surface, index === 3 ? C.primaryContainer : C.border, 0.08);
    addIcon(slide, icon, 6.38, y + 0.16, 0.34);
    text(slide, title, 6.9, y + 0.13, 1.48, 0.2, { fontSize: 11, bold: true });
    text(slide, body, 8.58, y + 0.15, 3.35, 0.18, {
      fontSize: 9,
      color: C.muted,
    });
  });
  text(slide, "실제 앱 캡처로 교체하여 최종 발표 화면 완성", 6.2, 6.48, 5.7, 0.2, {
    fontSize: 9,
    bold: true,
    color: C.primary,
  });
  validateSlide(slide);
}

function addNode(slide, title, subtitle, x, y, w, h, options = {}) {
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
  if (options.icon) {
    addIcon(slide, options.icon, x + 0.16, y + 0.19, 0.31, options.iconColor);
  }
  const left = options.icon ? x + 0.57 : x + 0.18;
  text(slide, title, left, y + 0.17, w - (left - x) - 0.13, 0.22, {
    fontSize: options.titleSize || 9.5,
    bold: true,
    color: options.titleColor || C.text,
  });
  text(slide, subtitle, left, y + 0.46, w - (left - x) - 0.13, 0.18, {
    fontSize: options.subSize || 7.5,
    color: options.subColor || C.muted,
  });
}

function addArrow(slide, x, y, w, label) {
  slide.addShape(pptx.ShapeType.chevron, {
    x,
    y,
    w,
    h: 0.16,
    fill: { color: C.primaryContainer },
    line: { color: C.primaryContainer, transparency: 100 },
  });
  if (label) {
    text(slide, label, x - 0.08, y - 0.27, w + 0.16, 0.18, {
      fontSize: 7.2,
      bold: true,
      color: C.primary,
      align: "center",
    });
  }
}

function addArchitectureSlide(page = "03", section = "SYSTEM ARCHITECTURE") {
  const slide = pptx.addSlide();
  addFullBackground(slide, true);
  addMeta(slide, section, page, true);

  text(slide, "Firebase 기반 동기화 알람 구조", 0.65, 1.09, 7.25, 0.48, {
    fontFace: TITLE_FONT,
    fontSize: 27,
    bold: true,
    color: C.surface,
  });
  text(slide, "기기 간에는 변경 상태를 전달하고, 정각 울림은 각 Android 기기가 수행합니다.", 0.67, 1.7, 7.5, 0.28, {
    fontSize: 10.5,
    color: "D5E9DE",
  });

  shape(slide, pptx.ShapeType.roundRect, 0.65, 2.45, 2.32, 3.1, "214537", "527768", 0.1);
  text(slide, "DEVICE A", 0.89, 2.69, 1.12, 0.18, {
    fontSize: 8,
    color: C.primaryContainer,
    bold: true,
    charSpacing: 1.05,
  });
  addNode(slide, "Flutter Android 앱", "알람 생성 / 수정", 0.88, 3.14, 1.87, 0.82, {
    fill: "F7FAF4",
    line: "F7FAF4",
    icon: "alarm",
  });
  addNode(slide, "로컬 알람 예약", "정각 울림 담당", 0.88, 4.3, 1.87, 0.82, {
    fill: "E7F7EB",
    line: C.primaryContainer,
    icon: "bell",
  });

  shape(slide, pptx.ShapeType.roundRect, 3.58, 2.25, 6.15, 3.5, "F7FAF4", "F7FAF4", 0.1);
  text(slide, "FIREBASE CLOUD", 3.86, 2.5, 2.1, 0.18, {
    fontSize: 8,
    color: C.primary,
    bold: true,
    charSpacing: 1.05,
  });
  addNode(slide, "Authentication", "사용자 식별", 3.89, 3.03, 1.25, 0.85, {
    fill: C.surface,
    line: C.border,
    icon: "shield",
    titleSize: 8.5,
  });
  addNode(slide, "Cloud Firestore", "공유 원본 저장", 5.36, 3.03, 1.28, 0.85, {
    fill: C.firebase,
    line: C.firebaseLine,
    titleSize: 8.3,
  });
  addNode(slide, "Cloud Functions", "변경 감지", 6.87, 3.03, 1.28, 0.85, {
    fill: C.firebase,
    line: C.firebaseLine,
    titleSize: 8.3,
  });
  addNode(slide, "FCM", "변경 전달", 8.39, 3.03, 1.03, 0.85, {
    fill: C.primarySoft,
    line: C.primaryContainer,
    icon: "cloud",
    titleSize: 9,
  });
  text(slide, "1. 저장", 5.44, 4.38, 0.72, 0.18, {
    fontSize: 7.5,
    bold: true,
    color: C.primary,
  });
  text(slide, "2. 감지", 6.99, 4.38, 0.72, 0.18, {
    fontSize: 7.5,
    bold: true,
    color: C.primary,
  });
  text(slide, "3. 전달", 8.47, 4.38, 0.72, 0.18, {
    fontSize: 7.5,
    bold: true,
    color: C.primary,
  });
  slide.addShape(pptx.ShapeType.line, {
    x: 3.91,
    y: 4.94,
    w: 5.45,
    h: 0,
    line: { color: C.border, width: 1 },
  });
  text(slide, "로그인 / 그룹 공유 알람 동기화 경로", 4.02, 5.14, 5.2, 0.19, {
    fontSize: 8.2,
    color: C.muted,
    align: "center",
  });

  shape(slide, pptx.ShapeType.roundRect, 10.33, 2.45, 2.35, 3.1, "214537", "527768", 0.1);
  text(slide, "DEVICE B", 10.57, 2.69, 1.12, 0.18, {
    fontSize: 8,
    color: C.primaryContainer,
    bold: true,
    charSpacing: 1.05,
  });
  addNode(slide, "Flutter Android 앱", "동기화 수신", 10.56, 3.14, 1.89, 0.82, {
    fill: "F7FAF4",
    line: "F7FAF4",
    icon: "cloud",
  });
  addNode(slide, "로컬 예약 갱신", "정각 울림 담당", 10.56, 4.3, 1.89, 0.82, {
    fill: "E7F7EB",
    line: C.primaryContainer,
    icon: "bell",
  });

  addArrow(slide, 3.03, 3.49, 0.43, "알람 저장");
  addArrow(slide, 9.8, 3.49, 0.42, "동기화 신호");

  shape(slide, pptx.ShapeType.roundRect, 0.66, 6.12, 12.02, 0.56, "335C4E", "335C4E", 0.06);
  text(slide, "FCM은 동기화 신호를 전달하고, 실제 알람 울림은 Android 로컬 예약이 담당합니다.", 0.93, 6.28, 11.45, 0.2, {
    fontSize: 11.5,
    bold: true,
    color: C.surface,
    align: "center",
  });
  validateSlide(slide);
}

async function writeSampleDeck() {
  addCoverSlide();
  addFeatureSlide();
  addArchitectureSlide();
  await pptx.writeFile({ fileName: OUTPUT });
  console.log(`PPTX 생성 완료: ${OUTPUT}`);
}

if (require.main === module) {
  writeSampleDeck().catch((error) => {
    console.error("PPTX 생성 실패:", error);
    process.exitCode = 1;
  });
}

module.exports = {
  pptx,
  C,
  TITLE_FONT,
  TITLE_LIGHT,
  BODY_FONT,
  text,
  shape,
  addIcon,
  addFullBackground,
  addMeta,
  addTag,
  addPhonePlaceholder,
  addNode,
  addArrow,
  validateSlide,
  addCoverSlide,
  addFeatureSlide,
  addArchitectureSlide,
};
