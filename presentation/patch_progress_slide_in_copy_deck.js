const fs = require("fs");
const path = require("path");
const JSZip = require("jszip");

const sourcePath = path.resolve(
  __dirname,
  "../사본 - Lets_alarm_발표자료_완성본_8장 (3).pptx",
);
const outputPath = path.resolve(
  __dirname,
  "Lets_alarm_발표자료_구현진행추가본.pptx",
);

const EMU_PER_INCH = 914400;
const emu = (inch) => Math.round(inch * EMU_PER_INCH);

function escapeXml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function shapeTransform(x, y, w, h) {
  return `<a:xfrm><a:off x="${emu(x)}" y="${emu(y)}"/><a:ext cx="${emu(w)}" cy="${emu(h)}"/></a:xfrm>`;
}

function rect({
  id,
  name,
  x,
  y,
  w,
  h,
  fill,
  radius = "roundRect",
  line = fill,
  lineWidth = 0,
}) {
  return `<p:sp><p:nvSpPr><p:cNvPr id="${id}" name="${name}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr>${shapeTransform(x, y, w, h)}<a:prstGeom prst="${radius}"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="${fill}"/></a:solidFill><a:ln w="${lineWidth}"><a:solidFill><a:srgbClr val="${line}"/></a:solidFill></a:ln></p:spPr></p:sp>`;
}

function text({
  id,
  name,
  value,
  x,
  y,
  w,
  h,
  size,
  color = "2C342E",
  bold = false,
  font = "Arial",
  align = "l",
  valign = "ctr",
}) {
  const paragraphs = value.split("\n").map((line) => {
    return `<a:p><a:pPr algn="${align}"/><a:r><a:rPr lang="ko-KR" sz="${Math.round(size * 100)}" b="${bold ? 1 : 0}"><a:solidFill><a:srgbClr val="${color}"/></a:solidFill><a:latin typeface="${font}"/><a:ea typeface="${font}"/></a:rPr><a:t>${escapeXml(line)}</a:t></a:r><a:endParaRPr lang="ko-KR" sz="${Math.round(size * 100)}"/></a:p>`;
  });
  return `<p:sp><p:nvSpPr><p:cNvPr id="${id}" name="${name}"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr><p:spPr>${shapeTransform(x, y, w, h)}<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr lIns="0" tIns="0" rIns="0" bIns="0" anchor="${valign}"><a:noAutofit/></a:bodyPr><a:lstStyle/>${paragraphs.join("")}</p:txBody></p:sp>`;
}

function addProgressShapes(slideXml) {
  let nextId = 600;
  const shapes = [];
  const addRect = (args) => shapes.push(rect({ id: nextId++, ...args }));
  const addText = (args) => shapes.push(text({ id: nextId++, ...args }));

  addText({
    name: "Progress slide title",
    value: "구현 진행 및 검증 현황",
    x: 0.65,
    y: 1.06,
    w: 9.7,
    h: 0.52,
    size: 28,
    bold: true,
    font: "Arial",
  });
  addText({
    name: "Progress slide subtitle",
    value: "Android 기본 구현과 발표 전 확인 항목을 구분해 정리합니다.",
    x: 0.67,
    y: 1.7,
    w: 10.8,
    h: 0.26,
    size: 11,
    color: "56615B",
  });

  const columns = [
    {
      x: 0.68,
      title: "구현 반영",
      fill: "E6F3EA",
      pill: "B9EFC5",
      items: [
        "알람 생성 / 수정 / 삭제",
        "요일 · 소리 · 진동 · 다시 알림",
        "로컬 예약 및 울림 화면",
        "로그인 · 그룹 동기화 구조",
      ],
    },
    {
      x: 4.73,
      title: "실기기 확인 필요",
      fill: "FFFFFF",
      pill: "E6F3EA",
      items: [
        "두 Android 기기 간 동기화",
        "해제 · 다시 알림 상태 전달",
        "잠금화면 전체화면 표시",
        "네트워크 재연결 후 반영",
      ],
    },
    {
      x: 8.78,
      title: "향후 확장",
      fill: "FFFFFF",
      pill: "E6F3EA",
      items: [
        "Web / Linux / Windows",
        "알람 기록과 카테고리",
        "벨소리 선택 UI",
        "추가 안정성 검증",
      ],
    },
  ];

  for (const column of columns) {
    addRect({
      name: `${column.title} panel`,
      x: column.x,
      y: 2.38,
      w: 3.82,
      h: 3.62,
      fill: column.fill,
      line: "DCE9E0",
      lineWidth: 9000,
    });
    addRect({
      name: `${column.title} pill`,
      x: column.x + 0.18,
      y: 2.62,
      w: 1.46,
      h: 0.38,
      fill: column.pill,
      line: column.pill,
    });
    addText({
      name: `${column.title} heading`,
      value: column.title,
      x: column.x + 0.29,
      y: 2.67,
      w: 1.25,
      h: 0.26,
      size: 10,
      bold: true,
      color: "386948",
    });
    column.items.forEach((item, index) => {
      const itemY = 3.35 + index * 0.56;
      addRect({
        name: `${column.title} marker ${index}`,
        x: column.x + 0.22,
        y: itemY + 0.1,
        w: 0.1,
        h: 0.1,
        fill: "386948",
        line: "386948",
      });
      addText({
        name: `${column.title} item ${index}`,
        value: item,
        x: column.x + 0.46,
        y: itemY,
        w: 3.04,
        h: 0.3,
        size: 11,
      });
    });
  }

  addRect({
    name: "Progress note band",
    x: 0.68,
    y: 6.3,
    w: 11.92,
    h: 0.43,
    fill: "E6F3EA",
    line: "E6F3EA",
  });
  addText({
    name: "Progress note",
    value:
      "실제 정각 울림은 Android 로컬 예약이 담당하며, 기기 간 변경 전달은 Firebase / FCM이 담당합니다.",
    x: 0.88,
    y: 6.38,
    w: 11.52,
    h: 0.24,
    size: 10,
    bold: true,
    color: "386948",
  });

  const patchedPageNumber = slideXml.replace(
    /<a:t>06<\/a:t>/,
    "<a:t>08</a:t>",
  );
  return patchedPageNumber.replace(
    "</p:spTree>",
    `${shapes.join("")}</p:spTree>`,
  );
}

async function build() {
  if (!fs.existsSync(sourcePath)) {
    throw new Error(`원본 PPTX가 없습니다: ${sourcePath}`);
  }
  const zip = await JSZip.loadAsync(fs.readFileSync(sourcePath));
  const file = zip.file("ppt/slides/slide9.xml");
  if (!file) {
    throw new Error("삽입 대상인 9번 슬라이드를 찾지 못했습니다.");
  }
  const slideXml = await file.async("string");
  zip.file("ppt/slides/slide9.xml", addProgressShapes(slideXml), {
    createFolders: false,
  });
  const output = await zip.generateAsync({
    type: "nodebuffer",
    compression: "DEFLATE",
    compressionOptions: { level: 6 },
  });
  fs.writeFileSync(outputPath, output);
  console.log(outputPath);
}

build().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
