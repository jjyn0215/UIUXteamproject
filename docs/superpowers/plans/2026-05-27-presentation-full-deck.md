# Let's alarm Full Visual Deck Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the approved green-and-white visual sample into an editable eight-slide presentation deck aligned to the class evaluation criteria.

**Architecture:** The approved three-slide generator retains ownership of shared typography, color, gradient, icon, and diagram primitives and exports them for reuse. A separate full-deck entry point composes the original cover, UI, and architecture designs with five new slides, leaving the sample PPTX reproducible and the full output independent.

**Tech Stack:** PptxGenJS 4.0.1, bundled `pptxgenjs_helpers`, `KIMM_Bold` title font, `A2Z` body font, Stitch green tokens.

---

### Task 1: Expose Approved Visual Builders

**Files:**
- Modify: `presentation/lets_alarm_visual_sample.js`

- [x] **Step 1: Guard sample generation and export approved primitives**

Wrap the existing three slide calls in `writeSampleDeck()` and export the drawing helpers used by the complete deck:

```js
async function writeSampleDeck() {
  addCoverSlide();
  addFeatureSlide();
  addArchitectureSlide();
  await pptx.writeFile({ fileName: OUTPUT });
}

if (require.main === module) {
  writeSampleDeck().catch((error) => {
    console.error("PPTX 생성 실패:", error);
    process.exitCode = 1;
  });
}

module.exports = {
  pptx, C, TITLE_FONT, TITLE_LIGHT, BODY_FONT,
  text, shape, addIcon, addFullBackground, addMeta, addTag,
  addPhonePlaceholder, addNode, addArrow, validateSlide,
  addCoverSlide, addFeatureSlide, addArchitectureSlide,
};
```

- [x] **Step 2: Confirm the original sample still builds**

Run:

```bash
cd presentation
npm run build:sample
```

Expected: `Lets_alarm_발표자료_시각시안_3장.pptx` remains generated without boundary warnings.

### Task 2: Compose the Eight-Slide Presentation

**Files:**
- Create: `presentation/lets_alarm_visual_deck.js`
- Modify: `presentation/package.json`
- Create: `presentation/Lets_alarm_발표자료_완성본_8장.pptx`

- [x] **Step 1: Add the complete-deck build command**

```json
{
  "scripts": {
    "build:deck": "node lets_alarm_visual_deck.js"
  }
}
```

- [x] **Step 2: Compose all eight required slides**

The new source imports approved helpers and creates these slides in order:

```js
addCoverSlide();
addOverviewSlide();
addFeatureSlide();
addRingAndAccountSlide();
addArchitectureSlide();
addClassFlowSlide();
addSyncAndControlFlowSlide();
addSecuritySlide();
```

New slides must express the approved source facts:

```text
기본 구현: Android / Flutter / Firebase
향후 확장: Web / Linux / Windows
로그아웃: 로컬 알람 사용
로그인 + 활성 그룹: 공유 동기화 사용
FCM은 동기화 신호, 실제 울림은 Android 로컬 예약
실기기 확인 필요: 두 Android 기기 간 동기화 안정성
```

- [x] **Step 3: Keep UI media locations replaceable**

The UI slides retain clearly captioned frames for later real app screenshots:

```text
[ AlarmHomeScreen 실제 캡처 삽입 ]
[ AlarmEditorSheet 실제 캡처 삽입 ]
[ AlarmRingScreen 실제 캡처 삽입 ]
[ 로그인 / 그룹 관리 실제 캡처 삽입 ]
```

### Task 3: Verify and Commit the Full Deck

**Files:**
- Test: `presentation/lets_alarm_visual_deck.js`
- Test: `presentation/Lets_alarm_발표자료_완성본_8장.pptx`

- [x] **Step 1: Generate and validate the full deck**

Run:

```bash
cd presentation
node --check lets_alarm_visual_sample.js
node --check lets_alarm_visual_deck.js
npm run build:sample
npm run build:deck
npm audit --omit=dev --audit-level=high
```

Expected: both PPTX files generate and audit reports zero high-severity vulnerabilities.

- [x] **Step 2: Verify slide count, text, and font references**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile
import re
p = Path('presentation/Lets_alarm_발표자료_완성본_8장.pptx')
with ZipFile(p) as z:
    slides = [n for n in z.namelist() if re.fullmatch(r'ppt/slides/slide\d+\.xml', n)]
    xml = ''.join(z.read(n).decode('utf-8', 'ignore') for n in slides)
assert len(slides) == 8
for required in ['KIMM_Bold', 'A2Z', 'Firebase 기반 동기화 알람 구조', '데이터 구조와 보안', 'Android 로컬 예약']:
    assert required in xml
print('PPTX validation: 8 slides')
PY
git diff --check -- presentation
```

Expected: eight slides exist, core content/font references are present, and no whitespace errors occur.

- [x] **Step 3: Attempt rendered validation and report environmental limits**

Run:

```bash
python3 /home/devuser/.codex/skills/slides/scripts/render_slides.py \
  presentation/Lets_alarm_발표자료_완성본_8장.pptx \
  --output_dir presentation/rendered
```

Expected: PNG rendering succeeds when LibreOffice and Python rendering dependencies exist; otherwise report unavailable dependencies explicitly.

- [x] **Step 4: Commit only presentation implementation files**

```bash
git add presentation/package.json \
  presentation/lets_alarm_visual_sample.js \
  presentation/lets_alarm_visual_deck.js \
  presentation/Lets_alarm_발표자료_완성본_8장.pptx
git commit -m "Build complete visual presentation deck"
```

Expected: unrelated `README.md` changes and user-provided untracked font directories remain unstaged.
