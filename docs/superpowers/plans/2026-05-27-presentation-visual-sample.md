# Let's alarm 3-Slide Visual Sample Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce an editable 16:9 three-slide visual sample PPTX for Let's alarm using the approved white-and-green presentation direction.

**Architecture:** A new PptxGenJS source file generates the sample independently of the existing eight-slide text draft. Reusable layout functions create consistent typography, gradient surfaces, labels, diagram blocks, and simple vector icons; the source writes a separate PPTX output and runs layout warning checks on each slide.

**Tech Stack:** PptxGenJS 4.0.1, bundled `pptxgenjs_helpers`, local KIMM/에이투지 TTF font families, Stitch color tokens.

---

### Task 1: Confirm Typeface and Asset Inputs

**Files:**
- Read: `서체/KIMM_bold.ttf`
- Read: `에이투지체-ttf-v1.001/에이투지체-4Regular.ttf`
- Read: `에이투지체-ttf-v1.001/에이투지체-6SemiBold.ttf`

- [ ] **Step 1: Inspect the internal family names used in PPTX font references**

Run:

```bash
fc-scan --format '%{family}\\n' 서체/KIMM_bold.ttf \
  에이투지체-ttf-v1.001/에이투지체-4Regular.ttf \
  에이투지체-ttf-v1.001/에이투지체-6SemiBold.ttf
```

Expected: family names for title and body fonts are printed so the JavaScript source can reference them correctly.

### Task 2: Build the Three-Slide PptxGenJS Source

**Files:**
- Create: `presentation/lets_alarm_visual_sample.js`
- Modify: `presentation/package.json`

- [ ] **Step 1: Add a separate build command without changing the text draft output**

Update the `scripts` section:

```json
{
  "scripts": {
    "build": "node lets_alarm_text_only_presentation.js",
    "build:sample": "node lets_alarm_visual_sample.js"
  }
}
```

- [ ] **Step 2: Implement reusable sample design helpers**

Create functions in `presentation/lets_alarm_visual_sample.js` for:

```js
const TITLE_FONT = "<KIMM family name>";
const BODY_FONT = "<에이투지 family name>";
const C = {
  primary: "386948",
  primaryContainer: "B9EFC5",
  background: "F7FAF4",
  surface: "FFFFFF",
  text: "2C342E",
};

function addGradientAccent(slide, x, y, w, h) { /* SVG gradient image */ }
function addHeader(slide, section, page) { /* title metadata */ }
function addOutlineIcon(slide, type, x, y, size) { /* simple vector icon */ }
function validateSlide(slide) {
  warnIfSlideHasOverlaps(slide, pptx, { muteContainment: true, ignoreLines: true });
  warnIfSlideElementsOutOfBounds(slide, pptx);
}
```

- [ ] **Step 3: Implement slide layouts from the approved design**

Generate exactly three slides:

```js
addCoverSlide();       // title, project summary, phone screenshot placeholder
addFeatureSlide();     // two UI screenshot placeholders with feature labels
addArchitectureSlide(); // device A -> Firebase Cloud -> device B block flow
```

The architecture slide must visibly contain this statement:

```text
FCM은 동기화 신호를 전달하고, 실제 알람 울림은 Android 로컬 예약이 담당합니다.
```

### Task 3: Generate and Validate the Sample

**Files:**
- Create: `presentation/Lets_alarm_발표자료_시각시안_3장.pptx`

- [ ] **Step 1: Generate the PPTX**

Run:

```bash
cd presentation
npm run build:sample
```

Expected: `Lets_alarm_발표자료_시각시안_3장.pptx` is created without layout warning output.

- [ ] **Step 2: Verify the output structure and source**

Run:

```bash
node --check presentation/lets_alarm_visual_sample.js
python3 - <<'PY'
from zipfile import ZipFile
import re
with ZipFile('presentation/Lets_alarm_발표자료_시각시안_3장.pptx') as z:
    slides = [n for n in z.namelist() if re.fullmatch(r'ppt/slides/slide\d+\.xml', n)]
assert len(slides) == 3
print('PPTX validation: 3 slides')
PY
git diff --check -- presentation
```

Expected: JavaScript syntax passes, the PPTX contains three slides, and Git reports no whitespace errors.

- [ ] **Step 3: Render for visual inspection when local tooling permits**

Run:

```bash
python3 /home/devuser/.codex/skills/slides/scripts/render_slides.py \
  presentation/Lets_alarm_발표자료_시각시안_3장.pptx \
  --output_dir presentation/rendered
```

Expected: slide PNG files are produced. If `pdf2image` or LibreOffice is unavailable, report that limitation instead of claiming visual render verification.

- [ ] **Step 4: Commit only sample outputs and source**

Run:

```bash
git add presentation/lets_alarm_visual_sample.js presentation/Lets_alarm_발표자료_시각시안_3장.pptx presentation/package.json presentation/package-lock.json
git commit -m "Add presentation visual sample slides"
```

Expected: user-provided font directories and unrelated `README.md` modifications are not included.
