const fs = require("fs");
const path = require("path");
const JSZip = require("jszip");

const sourcePath = path.resolve(
  __dirname,
  "../Lets_alarm_발표자료_완성본_8장 (3).pptx",
);
const outputPath = path.resolve(
  __dirname,
  "Lets_alarm_발표자료_완성본_8장_흐름추가본.pptx",
);

function escapeXml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function getShapeMatch(xml, shapeId) {
  const pattern = new RegExp(
    `<p:sp>(?:(?!<\\/p:sp>)[\\s\\S])*?<p:cNvPr id="${shapeId}"(?:(?!<\\/p:sp>)[\\s\\S])*?<\\/p:sp>`,
  );
  const match = xml.match(pattern);
  if (!match) {
    throw new Error(`슬라이드에서 shape id ${shapeId}를 찾지 못했습니다.`);
  }
  return match[0];
}

function setShapeRuns(xml, shapeId, textValues) {
  const shape = getShapeMatch(xml, shapeId);
  let valueIndex = 0;
  const replaced = shape.replace(/<a:t>[\s\S]*?<\/a:t>/g, () => {
    if (valueIndex >= textValues.length) {
      throw new Error(`shape id ${shapeId}의 텍스트 런 수가 예상보다 많습니다.`);
    }
    return `<a:t>${escapeXml(textValues[valueIndex++])}</a:t>`;
  });
  if (valueIndex !== textValues.length) {
    throw new Error(`shape id ${shapeId}의 텍스트 런 수가 예상과 다릅니다.`);
  }
  return xml.replace(shape, replaced);
}

function fillBlankShapeFromTemplate(xml, shapeId, templateId, text) {
  const shape = getShapeMatch(xml, shapeId);
  if (/<a:t>[\s\S]*?<\/a:t>/.test(shape)) {
    throw new Error(`shape id ${shapeId}가 비어 있지 않습니다.`);
  }
  const template = getShapeMatch(xml, templateId);
  const runMatch = template.match(/<a:r>[\s\S]*?<\/a:r>/);
  if (!runMatch) {
    throw new Error(`template shape id ${templateId}에 텍스트 런이 없습니다.`);
  }
  const run = runMatch[0].replace(
    /<a:t>[\s\S]*?<\/a:t>/,
    `<a:t>${escapeXml(text)}</a:t>`,
  );
  const replaced = shape.replace("<a:endParaRPr", `${run}<a:endParaRPr`);
  return xml.replace(shape, replaced);
}

function removeDuplicatedSlide7Shapes(xml) {
  return xml.replace(/<p:sp>[\s\S]*?<\/p:sp>/g, (shape) => {
    const idMatch = shape.match(/<p:cNvPr id="(\d+)"/);
    return idMatch && Number(idMatch[1]) >= 229 ? "" : shape;
  });
}

async function build() {
  if (!fs.existsSync(sourcePath)) {
    throw new Error(`원본 PPTX가 없습니다: ${sourcePath}`);
  }

  const zip = await JSZip.loadAsync(fs.readFileSync(sourcePath));
  const slide7File = zip.file("ppt/slides/slide7.xml");
  const slide8File = zip.file("ppt/slides/slide8.xml");
  if (!slide7File || !slide8File) {
    throw new Error("수정 대상인 7번 또는 8번 슬라이드를 찾지 못했습니다.");
  }

  let slide7 = await slide7File.async("string");
  slide7 = removeDuplicatedSlide7Shapes(slide7);
  slide7 = setShapeRuns(slide7, 228, ["잠금화면 울림"]);
  slide7 = fillBlankShapeFromTemplate(slide7, 202, 207, "Android 예약");
  slide7 = setShapeRuns(slide7, 203, ["시각 도달"]);
  slide7 = setShapeRuns(slide7, 207, ["LaunchRouterActivity"]);
  slide7 = setShapeRuns(slide7, 208, ["전체화면 분기"]);
  slide7 = setShapeRuns(slide7, 212, ["AlarmActivity"]);
  slide7 = setShapeRuns(slide7, 213, ["알람 전용 화면"]);
  slide7 = setShapeRuns(slide7, 217, ["AlarmRingScreen"]);
  slide7 = setShapeRuns(slide7, 218, ["소리 / 진동 표시"]);
  slide7 = setShapeRuns(slide7, 222, ["AlarmList", "Controller"]);
  slide7 = setShapeRuns(slide7, 223, ["해제 / 다시 알림"]);
  zip.file("ppt/slides/slide7.xml", slide7, { createFolders: false });

  let slide8 = await slide8File.async("string");
  slide8 = setShapeRuns(slide8, 335, ["공유 알람 저장"]);
  slide8 = setShapeRuns(slide8, 339, ["변경 감지"]);
  slide8 = setShapeRuns(slide8, 343, ["동기화 전달"]);
  slide8 = setShapeRuns(slide8, 356, ["울림 화면", "소리", "·", "진동"]);
  slide8 = setShapeRuns(slide8, 360, ["해제 또는"]);
  slide8 = setShapeRuns(slide8, 364, ["다시 알림"]);
  slide8 = setShapeRuns(slide8, 368, ["상태", "동기화"]);
  zip.file("ppt/slides/slide8.xml", slide8, { createFolders: false });

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
