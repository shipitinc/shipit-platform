// Harness: exercises docs/design/qa/design-qa.js outside Penpot with fake shapes.
const fs = require("fs");
const src = fs.readFileSync(require("path").join(__dirname, "design-qa.js"), "utf8");
const load = new Function("storage", "penpot", "penpotUtils", src);

// ---- fake shape model -------------------------------------------------------
let seq = 0;
function shape(o) {
  const s = Object.assign({ id: "s" + ++seq, name: "shape", children: [], fills: [], parent: null }, o);
  s.bounds = s.bounds || { x: s.x || 0, y: s.y || 0, width: s.width || 10, height: s.height || 10 };
  // real Penpot shapes expose x/y/width/height alongside bounds; mirror that or
  // any board-relative maths in the suite silently evaluates to NaN.
  s.x = s.bounds.x; s.y = s.bounds.y; s.width = s.bounds.width; s.height = s.bounds.height;
  for (const c of s.children) c.parent = s;
  return s;
}
function text(chars, x, y, w, h, color, size = 12, weight = 400, name = "t") {
  const s = shape({ type: "text", name, characters: chars, fontSize: size, fontWeight: weight,
    fills: [{ fillColor: color, fillOpacity: 1 }], bounds: { x, y, width: w, height: h } });
  s.textBounds = s.bounds;
  return s;
}
function rect(x, y, w, h, color, name = "r") {
  return shape({ type: "rectangle", name, fills: [{ fillColor: color, fillOpacity: 1 }],
    bounds: { x, y, width: w, height: h } });
}
// findShapes inside the suite searches descendants; the fake board provides that.
function board(name, x, y, w, h, bg, children) {
  return shape({ type: "board", name, fills: [{ fillColor: bg, fillOpacity: 1 }],
    bounds: { x, y, width: w, height: h }, children });
}

const walk = (root, out = []) => { for (const c of root.children || []) { out.push(c); walk(c, out); } return out; };

let PAGE = null;
const penpotUtils = {
  getPageById: () => PAGE,
  findShapes: (pred, root) => walk(root).filter(pred),
  analyzeDescendants: (root, ev) => walk(root).map((s) => ({ shape: s, result: ev(root, s) }))
    .filter((x) => x.result != null),
};

const storage = {};
const info = load(storage, {}, penpotUtils);
const dq = storage.dq;

// ---- assertions -------------------------------------------------------------
let pass = 0, fail = 0;
const t = (label, cond, extra) => {
  if (cond) { pass++; console.log("  ok   " + label); }
  else { fail++; console.log("  FAIL " + label + (extra ? "  -> " + JSON.stringify(extra) : "")); }
};

console.log("\n1. contrast maths validated against brand-tokens.md §6 measured values");
const r1 = dq.contrast("#E93E3A", "#1F2120");
t(`#E93E3A on #1F2120 = ${r1.toFixed(2)} (doc says 4.02)`, Math.abs(r1 - 4.02) < 0.02, r1);
const r2 = dq.contrast("#4496FC", "#2B3742");
t(`#4496FC on #2B3742 = ${r2.toFixed(2)} (doc says 4.06)`, Math.abs(r2 - 4.06) < 0.02, r2);
const r3 = dq.contrast("#A35F00", "#EFEFEC");
t(`#A35F00 on #EFEFEC = ${r3.toFixed(2)} (doc says 4.35)`, Math.abs(r3 - 4.35) < 0.02, r3);
t("white on black = 21", Math.abs(dq.contrast("#FFFFFF", "#000000") - 21) < 0.01);

console.log("\n2. model coherence (R1) catches an impossible gate binding");
const base = dq.checkModelCoherence();
t("post-HD-A model is fully coherent (no findings at all)", base.length === 0, base);

const saved = dq.MODEL.gates["GD-8a32"].workItemId;
dq.MODEL.gates["GD-8a32"].workItemId = "WI-7e0b"; // the pre-R1 defect
const broken = dq.checkModelCoherence();
t("pre-R1 binding (gate on agent_executing) is flagged major",
  broken.some((f) => f.severity === "major" && /cannot\s+coexist/.test(f.detail)), broken);
dq.MODEL.gates["GD-8a32"].workItemId = saved;

// HD-A/A1: a blocked item with no preGateState means its lane position would be
// authored rather than derived. That must be rejected, not tolerated.
const savedPre = dq.MODEL.workItems["WI-9c11"].preGateState;
delete dq.MODEL.workItems["WI-9c11"].preGateState;
t("blocked item without preGateState is flagged (lane would be authored)",
  dq.checkModelCoherence().some((f) => /declares no preGateState/.test(f.detail)),
  dq.checkModelCoherence());
dq.MODEL.workItems["WI-9c11"].preGateState = savedPre;

// The declared label must name the declared phase — this is the C defect class.
const savedLabel = dq.MODEL.gates["GD-5b1e"].phaseLabel;
dq.MODEL.gates["GD-5b1e"].phaseLabel = "HELD AT REVIEW";
t("phaseLabel naming a different phase than phaseIndex is flagged",
  dq.checkModelCoherence().some((f) => /phaseLabel .* names phase/.test(f.detail)),
  dq.checkModelCoherence());
dq.MODEL.gates["GD-5b1e"].phaseLabel = savedLabel;

// HD-B/B1: controls and routing keys must be the same set.
const savedControls = dq.MODEL.gates["GD-5b1e"].controls;
dq.MODEL.gates["GD-5b1e"].controls = ["Approve", "Request changes", "Stop run"];
t("controls not matching routing keys is flagged",
  dq.checkModelCoherence().some((f) => /do not match routing keys/.test(f.detail)),
  dq.checkModelCoherence());
dq.MODEL.gates["GD-5b1e"].controls = savedControls;

console.log("\n3. text-overlap detection (the defect automated QA missed)");
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("C · Decision Detail · Dark", 0, 0, 400, 400, "#222D35", [
    text("Recorded, signed, and final", 20, 300, 200, 16, "#FFFFFF"),
    text("Routing: Approve -> qa_in_progress", 20, 305, 220, 16, "#FFFFFF", 12, 400, "footer"),
    text("Well clear of everything", 20, 100, 180, 16, "#FFFFFF"),
  ]),
] }) };
const b = dq.studyBoards()[0];
const ov = dq.checkTextOverlap(b);
t("overlapping pair detected", ov.length === 1, ov);
t("non-overlapping text not flagged", !JSON.stringify(ov).includes("Well clear"), ov);

console.log("\n3b. text overflowing its own box (regression: the wrap overlap missed)");
// Reproduces D · Needs You `Q 1` exactly: a 900x34 box rendering 61px of text.
// checkTextOverlap missed this because the collision was ~1px.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("D · Needs You · Dark", 0, 0, 1280, 900, "#1F2120", [
    (() => { const t = text("Resume the Penpot design authority probe after the retry cap was hit?",
        80, 532, 900, 34, "#FAF8F2", 25, 700, "Q 1");
      t.textBounds = { x: 80, y: 532, width: 890, height: 61 }; return t; })(),
  ]),
] }) };
const ovf = dq.checkTextOverflow(dq.studyBoards()[0]);
t("two-line wrap in a one-line box is flagged",
  ovf.some((f) => f.check === "text-overflow" && /~2 lines/.test(f.detail)), ovf);

// The corrected copy fits: 31px of text in a 34px box.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("D · Needs You · Dark", 0, 0, 1280, 900, "#1F2120", [
    (() => { const t = text("Resume the Penpot probe after the retry cap was hit?",
        80, 532, 900, 34, "#FAF8F2", 25, 700, "Q 1");
      t.textBounds = { x: 80, y: 532, width: 717, height: 31 }; return t; })(),
  ]),
] }) };
t("corrected single-line copy is not flagged",
  dq.checkTextOverflow(dq.studyBoards()[0]).length === 0,
  dq.checkTextOverflow(dq.studyBoards()[0]));

// A 1-2px line-height overshoot is normal and must not be flagged.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("C · Home · Dark", 0, 0, 1280, 900, "#222D35", [
    (() => { const t = text("Approve the design for the claim-CAS dedupe patch?",
        80, 100, 800, 22, "#FFFFFF", 15, 400, "Int Q 0");
      t.textBounds = { x: 80, y: 100, width: 366, height: 24 }; return t; })(),
  ]),
] }) };
t("2px line-height overshoot on a correct node is not flagged",
  dq.checkTextOverflow(dq.studyBoards()[0]).length === 0,
  dq.checkTextOverflow(dq.studyBoards()[0]));

console.log("\n4. surface-aware contrast (no false positive for text on a button)");
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("B · Home · Light", 0, 0, 400, 400, "#FAF8F2", [
    rect(10, 10, 120, 40, "#F7A42C", "cta/waitFill"),
    text("Decide now", 20, 20, 100, 20, "#241A02", 13, 600, "cta-label"),
    text("body copy", 20, 200, 100, 16, "#B9B6AE", 12, 400, "low-contrast-neutral"),
  ]),
] }) };
const b2 = dq.studyBoards()[0];
const cs = dq.checkContrast(b2);
t("R5 CTA (#241A02 on #F7A42C) passes, resolved against the button not the board",
  !cs.some((f) => f.shape === "cta-label"), cs);
t("genuinely low-contrast neutral text is still flagged",
  cs.some((f) => f.shape === "low-contrast-neutral" && f.check === "contrast-neutral"), cs);

console.log("\n5. cross-field semantic consistency (R1/R2 defect class)");
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("C · Needs You · Dark", 0, 0, 600, 400, "#222D35", [
    text("GD-8a32", 20, 100, 60, 14, "#FFFFFF", 12, 400, "gate-id"),
    text("WI-7e0b  agent_executing", 100, 100, 220, 14, "#FFFFFF", 12, 400, "wi-cell"),
    text("GD-5b1e", 20, 200, 60, 14, "#FFFFFF", 12, 400, "gate-id-2"),
    text("WI-9c11  waiting_for_human_decision", 100, 200, 260, 14, "#FFFFFF", 12, 400, "wi-cell-2"),
  ]),
] }) };
const b3 = dq.studyBoards()[0];
const sem = dq.checkSemanticConsistency(b3);
t("stale GD-8a32 -> WI-7e0b binding flagged",
  sem.some((f) => f.check === "semantic-gate-binding" && /GD-8a32/.test(f.detail)), sem);
t("stale state beside the gate flagged",
  sem.some((f) => f.check === "semantic-state"), sem);
t("correct GD-5b1e -> WI-9c11 row not flagged",
  !sem.some((f) => /GD-5b1e/.test(f.detail)), sem);

console.log("\n6. control/routing labels are scoped per gate type (HD-B/B1)");
// A design_approval board: 'Reject' is correct, 'Stop run' is not offered here.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("B · Decision Detail · Dark", 0, 0, 400, 400, "#1F2120", [
    text("GD-5b1e", 20, 10, 60, 14, "#FFFFFF", 11, 400, "gate"),
    text("Reject", 20, 40, 60, 16, "#FFFFFF", 12, 600, "ctrl-good"),
    text("Stop run", 20, 70, 70, 16, "#FFFFFF", 12, 600, "ctrl-bad"),
    text("reject", 20, 100, 60, 16, "#FFFFFF", 11, 400, "route-good"),
  ]),
] }) };
const en = dq.checkEnumLabels(dq.studyBoards()[0]);
t("post-B1 control 'Reject' accepted on a design_approval gate",
  !en.some((f) => f.shape === "ctrl-good"), en);
t("'Stop run' flagged — not offered by a design_approval gate",
  en.some((f) => f.shape === "ctrl-bad" && f.check === "enum-label"), en);
t("routing row 'reject' accepted (it is a real choice of GD-5b1e)",
  !en.some((f) => f.shape === "route-good"), en);

// A qa_rework board: 'Stop run' is correct and must NOT be flagged.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("C · Needs You · Dark", 0, 0, 400, 400, "#222D35", [
    text("GD-8a32", 20, 10, 60, 14, "#FFFFFF", 11, 400, "gate"),
    text("Stop run", 20, 40, 70, 16, "#FFFFFF", 12, 600, "ctrl-ok"),
    text("Resume", 20, 70, 70, 16, "#FFFFFF", 12, 600, "ctrl-ok2"),
  ]),
] }) };
const en2 = dq.checkEnumLabels(dq.studyBoards()[0]);
t("'Stop run' accepted on a qa_rework gate", !en2.some((f) => f.shape === "ctrl-ok"), en2);
t("'Resume' accepted on a qa_rework gate", !en2.some((f) => f.shape === "ctrl-ok2"), en2);

// Resolved history copy must be exempt — R6 as written would have mangled it.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("B · Needs You · Dark", 0, 0, 400, 400, "#1F2120", [
    text("GD-5b1e", 20, 10, 60, 14, "#FFFFFF", 11, 400, "gate"),
    text("Reject design revision DES-R2", 20, 40, 220, 16, "#FFFFFF", 11, 400, "hist-desc"),
    text("waive", 20, 70, 50, 16, "#FFFFFF", 11, 400, "hist-choice"),
  ]),
] }) };
const en3 = dq.checkEnumLabels(dq.studyBoards()[0]);
t("resolved-history description not treated as a control label",
  !en3.some((f) => f.shape === "hist-desc"), en3);
t("resolved-history choice 'waive' exempt from the pending-gate choice set",
  !en3.some((f) => f.shape === "hist-choice"), en3);

console.log("\n6b. DURABLE STATE field must print WorkItem.state (HD-A/A1, R10)");
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("B · Decision Detail · Dark", 0, 0, 600, 400, "#1F2120", [
    text("WI-9c11", 20, 10, 60, 14, "#FFFFFF", 11, 400, "wi"),
    text("DURABLE STATE", 20, 50, 110, 14, "#FFFFFF", 9, 600, "key"),
    text("design_in_review", 150, 50, 130, 14, "#FFFFFF", 12, 400, "val-bad"),
  ]),
] }) };
const ds = dq.checkDurableStateField(dq.studyBoards()[0]);
t("pre-A1 'design_in_review' under DURABLE STATE is flagged",
  ds.some((f) => f.check === "durable-state-field" && /PRE-GATE/.test(f.detail)), ds);

PAGE = { root: shape({ type: "board", name: "root", children: [
  board("B · Decision Detail · Dark", 0, 0, 600, 400, "#1F2120", [
    text("WI-9c11", 20, 10, 60, 14, "#FFFFFF", 11, 400, "wi"),
    text("DURABLE STATE", 20, 50, 110, 14, "#FFFFFF", 9, 600, "key"),
    text("waiting_for_human_decision", 150, 50, 200, 14, "#FFFFFF", 12, 400, "val-good"),
  ]),
] }) };
t("post-A1 'waiting_for_human_decision' accepted",
  dq.checkDurableStateField(dq.studyBoards()[0]).length === 0,
  dq.checkDurableStateField(dq.studyBoards()[0]));

console.log("\n7. lifecycle labels are attributed by band, not board-wide (regression)");
// Reproduces C · Home exactly: the "HALTED AT BUILD" label sits in WI-3d8c's row
// (agent_failed -> phase 2, CORRECT), while GD-5b1e sits in a different row.
// A board-wide scan wrongly reported a contradiction here.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("C · Home · Dark", 0, 0, 1200, 800, "#222D35", [
    text("FAILED", 20, 414, 60, 14, "#FFFFFF", 11, 600, "St 3"),
    text("HALTED AT BUILD", 90, 414, 130, 14, "#FFFFFF", 11, 600, "Lc 3"),
    text("WI-3d8c", 240, 414, 60, 14, "#FFFFFF", 11, 400, "Id 3"),
    text("GD-5b1e", 20, 565, 60, 14, "#FFFFFF", 11, 400, "Int Gate 1"),
    text("design_approval", 90, 565, 110, 14, "#FFFFFF", 11, 400, "Int Ty 1"),
    text("WI-9c11", 240, 565, 60, 14, "#FFFFFF", 11, 400, "Int Wi 1"),
  ]),
] }) };
const b5 = dq.studyBoards()[0];
const lc = dq.checkLifecycleTruth(b5);
t("correct WI-3d8c 'HALTED AT BUILD' label is NOT flagged",
  !lc.some((f) => f.check === "lifecycle-label"), lc.filter((f) => f.check === "lifecycle-label"));
t("GD-5b1e in another band is not blamed for that label",
  !lc.some((f) => f.check === "lifecycle-label" && /GD-5b1e/.test(f.detail)), lc);

// And the genuine C · Decision Detail contradiction must still be caught.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("C · Decision Detail · Dark", 0, 0, 1200, 800, "#222D35", [
    text("LIFECYCLE POSITION — HELD AT REVIEW", 20, 115, 300, 14, "#FFFFFF", 11, 600, "Lc Pos"),
    text("GD-5b1e · design_approval · pending", 20, 120, 260, 14, "#FFFFFF", 11, 400, "F V 2"),
  ]),
] }) };
const b6 = dq.studyBoards()[0];
const lc2 = dq.checkLifecycleTruth(b6);
t("genuine 'HELD AT REVIEW' vs model phase 1 contradiction IS flagged",
  lc2.some((f) => f.check === "lifecycle-label" && /AT REVIEW/.test(f.detail)), lc2);

// Body prose must not be mistaken for a lifecycle label (regression).
// This exact sentence produced a bogus "AT THESE" phase on three real boards.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("C · Needs You · Dark", 0, 0, 1200, 800, "#222D35", [
    text("Autonomous execution has stopped at these points by design. It will not proceed without a human.",
         20, 60, 600, 16, "#FFFFFF", 11, 400, "Hold Sub"),
    text("GD-5b1e", 20, 200, 60, 14, "#FFFFFF", 11, 400, "g1"),
    text("GD-8a32", 20, 240, 60, 14, "#FFFFFF", 11, 400, "g2"),
  ]),
] }) };
const lc3 = dq.checkLifecycleTruth(dq.studyBoards()[0]);
t("body prose 'stopped at these points' not read as a phase label",
  !lc3.some((f) => /lifecycle-label/.test(f.check)), lc3.filter((f) => /lifecycle-label/.test(f.check)));

// A label with no id in its band, on a multi-gate board, must be reported as
// unverifiable rather than passed or blamed on an arbitrary gate.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("C · Home · Dark", 0, 0, 600, 400, "#222D35", [
    text("HELD AT DESIGN", 20, 40, 130, 14, "#FFFFFF", 11, 600, "orphan-label"),
    text("GD-5b1e", 20, 200, 60, 14, "#FFFFFF", 11, 400, "g1"),
    text("GD-8a32", 20, 240, 60, 14, "#FFFFFF", 11, 400, "g2"),
  ]),
] }) };
const lc4 = dq.checkLifecycleTruth(dq.studyBoards()[0]);
t("unattributable label on a multi-gate board reported as unverifiable",
  lc4.some((f) => f.check === "lifecycle-label-unattributed"), lc4);

console.log("\n7b. phase caption must agree with the lane segments (regression)");
// Reproduces the real defect: segments fill through DESIGN (index 1) while the
// caption highlights BUILD (index 2). Mechanical QA passed this; only the
// exported image revealed it.
const capBoard = (highlightIdx) => board("C · Needs You · Dark", 0, 0, 800, 300, "#222D35", [
  text("GD-5b1e", 20, 10, 60, 14, "#FFFFFF", 11, 400, "gate"),
  ...["PLAN", "DESIGN", "BUILD", "REVIEW", "QA", "SHIP"].map((p, i) =>
    text(p, 20 + i * 70, 60, 60, 12, i === highlightIdx ? "#F7A42C" : "#93A0AB", 9, 600, "G Ph 0" + i)),
]);
// GD-5b1e declares phase 1; pretend the lane fills through 1.
const resolver = () => 1;

PAGE = { root: shape({ type: "board", name: "root", children: [capBoard(2)] }) };
const cap = dq.checkPhaseCaptionHighlight(dq.studyBoards()[0], resolver);
t("caption highlighting BUILD while lane fills through DESIGN is flagged",
  cap.some((f) => f.check === "caption-highlight"), cap);

PAGE = { root: shape({ type: "board", name: "root", children: [capBoard(1)] }) };
t("caption highlighting DESIGN, matching the lane, is not flagged",
  dq.checkPhaseCaptionHighlight(dq.studyBoards()[0], resolver).length === 0,
  dq.checkPhaseCaptionHighlight(dq.studyBoards()[0], resolver));

// Without a resolver it must say "not assessed", never pass silently.
PAGE = { root: shape({ type: "board", name: "root", children: [capBoard(2)] }) };
t("no resolver => reported as not assessed rather than passed",
  dq.checkPhaseCaptionHighlight(dq.studyBoards()[0])
    .some((f) => f.check === "caption-highlight-not-assessed"),
  dq.checkPhaseCaptionHighlight(dq.studyBoards()[0]));

// Two highlighted captions in one row assert two positions at once.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("C · Needs You · Dark", 0, 0, 800, 300, "#222D35", [
    text("GD-5b1e", 20, 10, 60, 14, "#FFFFFF", 11, 400, "gate"),
    ...["PLAN", "DESIGN", "BUILD", "REVIEW", "QA", "SHIP"].map((p, i) =>
      text(p, 20 + i * 70, 60, 60, 12, (i === 1 || i === 3) ? "#F7A42C" : "#93A0AB", 9, 600, "G Ph 0" + i)),
  ]),
] }) };
t("two highlighted captions in one row flagged",
  dq.checkPhaseCaptionHighlight(dq.studyBoards()[0], resolver)
    .some((f) => f.check === "caption-multi-highlight"),
  dq.checkPhaseCaptionHighlight(dq.studyBoards()[0], resolver));

// A uniform row is a shared legend and asserts nothing.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("C · Home · Dark", 0, 0, 800, 300, "#222D35", [
    text("GD-5b1e", 20, 10, 60, 14, "#FFFFFF", 11, 400, "gate"),
    ...["PLAN", "DESIGN", "BUILD", "REVIEW", "QA", "SHIP"].map((p, i) =>
      text(p, 20 + i * 70, 60, 60, 12, "#93A0AB", 9, 600, "Legend " + i)),
  ]),
] }) };
t("uniform caption row (shared legend) asserts nothing",
  dq.checkPhaseCaptionHighlight(dq.studyBoards()[0], resolver).length === 0,
  dq.checkPhaseCaptionHighlight(dq.studyBoards()[0], resolver));

console.log("\n7c. content spilling out of its own card (regression)");
// Reproduces the mobile Needs-you bug: the button ended 2px below its card.
// checkContainment passed it because it was well inside the BOARD.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("BPM · Needs you · Dark", 0, 0, 390, 844, "#1F2120", [
    rect(16, 140, 358, 280, "#262827", "Card Bg 0"),
    rect(30, 392, 330, 30, "#4496FC", "Btn 0"),
  ]),
] }) };
const spill = dq.checkCardSpill(dq.studyBoards()[0]);
t("button ending 2px below its card is flagged",
  spill.some((f) => f.check === "card-spill" && /Btn 0/.test(f.detail)), spill);
t("containment alone does NOT catch it (documents why this check exists)",
  dq.checkContainment(dq.studyBoards()[0]).length === 0,
  dq.checkContainment(dq.studyBoards()[0]));

// Corrected geometry: card grown so the button sits inside with even padding.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("BPM · Needs you · Dark", 0, 0, 390, 844, "#1F2120", [
    rect(16, 140, 358, 286, "#262827", "Card Bg 0"),
    rect(30, 384, 330, 30, "#4496FC", "Btn 0"),
  ]),
] }) };
t("corrected card/button geometry is not flagged",
  dq.checkCardSpill(dq.studyBoards()[0]).length === 0,
  dq.checkCardSpill(dq.studyBoards()[0]));

// A neighbouring column must not be mistaken for spill.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("BP · Home · Dark", 0, 0, 1280, 900, "#1F2120", [
    rect(16, 140, 300, 100, "#262827", "Card Bg 0"),
    rect(400, 120, 200, 200, "#262827", "Other Panel"),
  ]),
] }) };
t("a shape outside the card horizontally is not flagged",
  dq.checkCardSpill(dq.studyBoards()[0]).length === 0,
  dq.checkCardSpill(dq.studyBoards()[0]));

console.log("\n7d. shared chrome drifting between boards (regression)");
// Reproduces the mobile bottom-nav defect: the same component, built by a helper
// that changed mid-build, ended up different on different boards. Each board was
// internally valid, so every per-board check passed.
const navBoard = (name, badgeBg, iconY) => board(name, 0, 0, 390, 844, "#1F2120", [
  rect(336, 772, 18, 18, "#F7A42C", badgeBg ? "Nav Badge Bg" : "Unrelated"),
  rect(324, iconY, 2, 8, "#F5F4F0", "Nav Ic2 bar"),
  rect(299, 778, 52, 26, "#2D2F2E", "Nav Pill 2"),
]);
PAGE = { root: shape({ type: "board", name: "root", children: [
  navBoard("BPM · Overview · Dark", true, 785),
  navBoard("BPM · All work · Dark", false, 781),
] }) };
const boards = dq.studyBoards();
const chrome = dq.checkSharedChrome(boards, ["Nav Badge Bg", "Nav Ic2 bar", "Nav Pill 2"]);
t("a board missing shared chrome is flagged",
  chrome.some((f) => f.check === "chrome-missing" && /Nav Badge Bg/.test(f.detail)), chrome);
t("the same chrome at a different position is flagged",
  chrome.some((f) => f.check === "chrome-drift" && /Nav Ic2 bar/.test(f.detail)), chrome);

PAGE = { root: shape({ type: "board", name: "root", children: [
  navBoard("BPM · Overview · Dark", true, 785),
  navBoard("BPM · All work · Dark", true, 785),
] }) };
t("identical chrome across boards is not flagged",
  dq.checkSharedChrome(dq.studyBoards(), ["Nav Badge Bg", "Nav Ic2 bar", "Nav Pill 2"]).length === 0,
  dq.checkSharedChrome(dq.studyBoards(), ["Nav Badge Bg", "Nav Ic2 bar", "Nav Pill 2"]));

// Typography drift: the real badge defect — same box, different font size.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("BPM · Overview · Dark", 0, 0, 390, 844, "#1F2120", [
    (()=>{ const t=text("2",336,772,18,18,"#241A02",11,700,"Nav Badge"); return t; })(),
  ]),
  board("BPM · All work · Dark", 0, 0, 390, 844, "#1F2120", [
    (()=>{ const t=text("2",336,772,18,18,"#241A02",9,600,"Nav Badge"); return t; })(),
  ]),
] }) };
t("same-box chrome rendered at a different font size is flagged",
  dq.checkSharedChrome(dq.studyBoards(), ["Nav Badge"])
    .some((f) => f.check === "chrome-typography-drift" && /fontSize/.test(f.detail)),
  dq.checkSharedChrome(dq.studyBoards(), ["Nav Badge"]));

// A nav label is bold when active and regular when inactive. Identical chrome,
// different ink. This must NOT be flagged.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("BPM · Overview · Dark", 0, 0, 390, 844, "#1F2120", [
    (()=>{ const t=text("Overview",10,810,110,16,"#F5F4F0",10,600,"Nav Label 0");
           t.textBounds={x:26,y:810,width:43.6,height:16}; return t; })(),
  ]),
  board("BPM · All work · Dark", 0, 0, 390, 844, "#1F2120", [
    (()=>{ const t=text("Overview",10,810,110,16,"#8A8983",10,400,"Nav Label 0");
           t.textBounds={x:27,y:810,width:41.7,height:16}; return t; })(),
  ]),
] }) };
t("active-vs-inactive label weight is not reported as drift",
  dq.checkSharedChrome(dq.studyBoards(), ["Nav Label 0"]).length === 0,
  dq.checkSharedChrome(dq.studyBoards(), ["Nav Label 0"]));

console.log("\n7e. optical centring of a glyph in its container (regression)");
// The exclamation glyph was 4px above the pill centre; the grid 1.5px.
PAGE = { root: shape({ type: "board", name: "root", children: [
  board("BPM · Needs you · Dark", 0, 0, 390, 844, "#1F2120", [
    rect(299, 778, 52, 26, "#2D2F2E", "Nav Pill 2"),
    rect(324, 781, 2, 8, "#F5F4F0", "Nav Ic2 bar"),
    rect(324, 791, 2, 2, "#F5F4F0", "Nav Ic2 dot"),
  ]),
] }) };
const oc = dq.checkOpticalCentring(dq.studyBoards()[0],
  [{ container: "Nav Pill 2", parts: ["Nav Ic2 bar", "Nav Ic2 dot"], label: "needs-you icon" }]);
t("glyph 4px above its container centre is flagged",
  oc.some((f) => f.check === "optical-centring"), oc);

PAGE = { root: shape({ type: "board", name: "root", children: [
  board("BPM · Needs you · Dark", 0, 0, 390, 844, "#1F2120", [
    rect(299, 778, 52, 26, "#2D2F2E", "Nav Pill 2"),
    rect(324, 785, 2, 8, "#F5F4F0", "Nav Ic2 bar"),
    rect(324, 795, 2, 2, "#F5F4F0", "Nav Ic2 dot"),
  ]),
] }) };
t("correctly centred glyph is not flagged",
  dq.checkOpticalCentring(dq.studyBoards()[0],
    [{ container: "Nav Pill 2", parts: ["Nav Ic2 bar", "Nav Ic2 dot"] }]).length === 0);

console.log("\n8. runAll never reports a silent pass while something is unresolved");
const rep = dq.runAll();
t("unresolvedCount > 0 surfaced in summary", rep.unresolvedCount > 0, rep.bySeverity);

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
