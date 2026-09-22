/* ShipIt automated design QA — durable, session-independent.
 *
 * WHY THIS FILE EXISTS
 * This suite previously lived only in the Penpot session `storage` object. The
 * browser tab suspended twice and the code was lost twice, costing a full
 * correction round each time (see docs/checkpoints/SESSION-HANDOFF.md §4.7).
 * It is now on disk so a resume costs one paste, not one re-authoring.
 *
 * STATUS
 * This is operator tooling, NOT the implementation of Automated Design QA as
 * planned in docs/checkpoints/003-design-governance-automation-planning.md §4
 * stage 6. That slice is `READY_FOR_PLANNING_REVIEW` and nothing in it is
 * implemented. This file is a precursor and must not be cited as satisfying it.
 *
 * SCOPE — mechanical checks only. This suite makes NO aesthetic judgement and
 * must never be used as design approval (study §7).
 *
 * USAGE (paste into penpot_execute_code, then call):
 *   storage.dq.runAll();                       // all study boards
 *   storage.dq.runAll(/^C · /);                // one direction
 *   storage.dq.checkModelCoherence();          // sample data, no boards needed
 */

storage.dq = (() => {
  // ---------------------------------------------------------------- constants

  const PAGE_ID = "d8ac01df-6646-81d2-8008-a366c09aa9d3";
  // Matches every design lineage in the file. NOTE: this was previously
  // /^[BCD] · / which silently matched none of the adopted `BP ·` (plain
  // language) or `BPM ·` (mobile) boards — so `runAll()` scanned zero boards and
  // reported zero findings. A checker that reports a clean run over an empty set
  // is the exact false pass this suite exists to prevent.
  const STUDY_BOARD_RE = /^(BPM|BP|[BCD]) · /;

  // docs/design/brand-tokens.md §1–§3. Authoritative; do not re-derive.
  const BRAND = new Set([
    "#FFF33B", "#E93E3A", "#6FFFCE", "#4496FC", "#F7A42C", "#F1813E",
    "#FFEC33", "#FCC210", "#EA443A",
    "#6EFDCF", "#62E0DC", "#56C3E8", "#4CA9F4", "#4497FC",
    // light-mode darkened derivatives of brand hues (brand-tokens.md §6)
    "#A35F00", "#B36A08",
  ]);
  const BRAND_BACKGROUNDS = new Set(["#1F2120", "#222D35"]);

  const LEGIBILITY_FLOOR_PX = 9;
  const AA_SMALL = 4.5;
  const AA_LARGE = 3.0;
  const OVERLAP_TOLERANCE = 0.15; // share of the smaller node's area

  // --------------------------------------------------- sample-data truth model
  // Grounded in study §4 as corrected by §9 R1 + R2. Single source of truth for
  // every semantic assertion below. If a board disagrees with this, the board is
  // wrong — unless the model itself is flagged UNRESOLVED.
  // Reflects human decisions HD-A (A1), HD-B (B1), HD-C (C1), HD-D (D1) recorded
  // 2026-09-15 in study §12.
  //
  // HD-A/A1: a work item with a PENDING blocking gate has durable state
  // `waiting_for_human_decision`. The state it halted in is `preGateState`, and
  // the lifecycle lane position derives from THAT, not from the durable state.
  // Two fields, two meanings. This is why `phase` is declared per work item
  // rather than looked up from the durable state alone — a blocked marker has
  // no lane position.
  const MODEL = {
    workItems: {
      "WI-4f2a": { title: "Ship bootstrap E2E journey", state: "agent_executing", phase: 2 },
      "WI-7e0b": { title: "Postgres migration contract test", state: "agent_executing", phase: 2 },
      "WI-9c11": { title: "Scheduler claim-CAS dedupe patch",
                   state: "waiting_for_human_decision", preGateState: "design_in_review", phase: 1 },
      // R1: GD-8a32 reassigned WI-7e0b -> WI-3d8c. Under A1 this work item is
      // therefore `waiting_for_human_decision`, having halted in `agent_failed`.
      "WI-3d8c": { title: "Penpot design authority probe",
                   state: "waiting_for_human_decision", preGateState: "agent_failed", phase: 2 },
      // MODEL-COVERAGE correction 2026-09-15: the All work boards also render
      // rows 4-7 (WI-1aa5, WI-6cf0, WI-b74d, WI-2ef9). Titles are the plain
      // English the boards display; state/phase are the durable values those
      // row states encode ("Finished" -> completed, "Working on it" ->
      // agent_executing, "Waiting to start" -> planned).
      "WI-1aa5": { title: "Check for duplicate safety rules", state: "completed", phase: 5 },
      "WI-6cf0": { title: "Check the AI connection works", state: "completed", phase: 5 },
      "WI-b74d": { title: "Make approvals survive a restart", state: "agent_executing", phase: 2 },
      "WI-2ef9": { title: "Check how much work fits at once", state: "planned", phase: 2 },
    },
    gates: {
      "GD-5b1e": {
        workItemId: "WI-9c11", type: "design_approval", phaseIndex: 1, phaseLabel: "HELD AT DESIGN",
        // HD-B/B1: the control is relabelled `Reject` to match
        // HumanDecisionType.designRejection, so the routing row stays truthful.
        controls: ["Approve", "Request changes", "Reject"],
        routing: { "approve": "design_approved", "request changes": "design_in_review", "reject": "design_rejected" },
      },
      "GD-8a32": {
        workItemId: "WI-3d8c", type: "qa_rework", phaseIndex: 2, phaseLabel: "HALTED AT BUILD",
        // A qa_rework gate is not a design gate; `Stop run` is correct here.
        controls: ["Resume", "Request changes", "Stop run"],
        routing: { "resume": "agent_executing", "request changes": "qa_in_progress", "stop run": "agent_failed" },
      },
    },
    // HD-D/D1: the boards also render a "Recently resolved" history section that
    // §4 never declared. These are RESOLVED decisions, not pending gates, and
    // their recorded `choice` is a durable historical value — not a control
    // label — so it is exempt from the control-label check.
    resolvedDecisions: {
      "GD-4c77": { desc: "Approve QA contract for bootstrap", choice: "approve", workItemId: "WI-4f2a", when: "today 09:41" },
      "GD-2a10": { desc: "Waive perf gate for probe run", choice: "waive", workItemId: "WI-3d8c", when: "today 08:15" },
      "GD-1f03": { desc: "Reject design revision DES-R2", choice: "reject", workItemId: "WI-9c11", when: "yest 17:52" },
    },
    phases: ["PLAN", "DESIGN", "BUILD", "REVIEW", "QA", "SHIP"],
    // Only used for ungated work items; gated ones declare `phase` explicitly
    // because `waiting_for_human_decision` has no lane position (HD-A).
    stateToPhase: {
      design_in_review: 1, design_rejected: 1,
      agent_executing: 2, agent_failed: 2,
      qa_in_progress: 4, completed: 5,
    },
    // A pending gate is only coherent on a work item that is actually blocked.
    gateCompatibleStates: ["waiting_for_human_decision"],
    // The field the boards label "DURABLE STATE" must print WorkItem.state.
    durableStateFieldLabels: ["DURABLE STATE", "WORKITEM.STATE", "WORK ITEM STATE"],
  };

  const WI_RE = /WI-[0-9a-f]{4}/g;
  const GD_RE = /GD-[0-9a-f]{4}/g;
  const STATE_RE = /\b(agent_executing|agent_failed|waiting_for_human_decision|design_in_review|design_rejected|design_approved|qa_in_progress|completed)\b/g;

  // -------------------------------------------------------------- colour maths

  const hexToRgb = (hex) => {
    const h = String(hex).replace("#", "");
    return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
  };
  const toLin = (c) => { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
  const luminance = (hex) => { const [r, g, b] = hexToRgb(hex).map(toLin); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
  const contrast = (a, b) => {
    const la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
  };
  const toHex = (n) => Math.round(Math.max(0, Math.min(255, n))).toString(16).padStart(2, "0").toUpperCase();
  const composite = (fgHex, bgHex, alpha) => {
    const f = hexToRgb(fgHex), b = hexToRgb(bgHex);
    return "#" + [0, 1, 2].map((i) => toHex(f[i] * alpha + b[i] * (1 - alpha))).join("");
  };

  /** First solid (non-image, non-gradient) fill of a shape, or null. */
  const solidFill = (shape) => {
    const fills = shape.fills;
    if (!Array.isArray(fills)) return null; // mixed/undefined on some shapes
    for (const f of fills) {
      if (!f || f.fillImage || f.fillColorGradient) continue;
      if (typeof f.fillColor !== "string") continue;
      const op = f.fillOpacity == null ? 1 : f.fillOpacity;
      if (op <= 0) continue;
      return { hex: f.fillColor.toUpperCase(), opacity: op };
    }
    return null;
  };

  // ------------------------------------------------------------------ geometry

  const rectOf = (shape) => {
    const b = (shape.type === "text" && shape.textBounds) || shape.bounds;
    return b ? { x: b.x, y: b.y, width: b.width, height: b.height } : null;
  };
  const contains = (outer, inner) =>
    inner.x >= outer.x - 0.5 && inner.y >= outer.y - 0.5 &&
    inner.x + inner.width <= outer.x + outer.width + 0.5 &&
    inner.y + inner.height <= outer.y + outer.height + 0.5;
  const intersectArea = (a, b) => {
    const w = Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x);
    const h = Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y);
    return w > 0 && h > 0 ? w * h : 0;
  };
  const isVisible = (shape) => {
    for (let s = shape; s; s = s.parent) if (s.hidden || s.visible === false) return false;
    return true;
  };

  // ------------------------------------------------------------------ plumbing

  const page = () => {
    const p = penpotUtils.getPageById(PAGE_ID);
    if (!p) throw new Error("page " + PAGE_ID + " not found");
    return p;
  };
  const studyBoards = (filter) =>
    page().root.children.filter((c) => STUDY_BOARD_RE.test(c.name || "") && (!filter || filter.test(c.name)));
  const textsIn = (board) =>
    penpotUtils.findShapes((s) => s.type === "text" && String(s.characters || "").trim() !== "", board)
      .filter(isVisible);
  const surfacesIn = (board) =>
    penpotUtils.findShapes((s) => ["rectangle", "ellipse", "board"].includes(s.type) && solidFill(s), board)
      .filter(isVisible);

  const finding = (board, shape, check, severity, detail) => ({
    board: board.name, check, severity,
    shape: shape ? shape.name : null, shapeId: shape ? shape.id : null,
    detail,
  });

  // -------------------------------------------------------------------- checks

  /** Descendants escaping their board (study §7). */
  const checkContainment = (board) => {
    const boardRect = rectOf(board);
    return penpotUtils.analyzeDescendants(board, (root, s) => {
      const r = rectOf(s);
      if (!r || !isVisible(s)) return null;
      if (contains(boardRect, r)) return null;
      return finding(board, s, "containment", "major",
        `bounds (${Math.round(r.x)},${Math.round(r.y)},${Math.round(r.width)}x${Math.round(r.height)}) escape board`);
    }).map((x) => x.result);
  };

  /** Text below the legibility floor (study §7). */
  const checkLegibility = (board) =>
    textsIn(board)
      .filter((t) => Number(t.fontSize) < LEGIBILITY_FLOOR_PX)
      .map((t) => finding(board, t, "legibility", "major",
        `fontSize ${t.fontSize}px < floor ${LEGIBILITY_FLOOR_PX}px`));

  /**
   * Surface-aware contrast (handoff §4.8). Comparing text against the *board*
   * background produces false positives for text sitting on a button, so the
   * background is the smallest filled shape that geometrically contains the
   * text. Brand-palette shortfalls are reported but NEVER auto-fixed — that is
   * a brand-owner decision (brand-tokens.md §6).
   */
  const checkContrast = (board) => {
    const surfaces = surfacesIn(board);
    const boardFill = solidFill(board);
    const out = [];
    for (const t of textsIn(board)) {
      const fg = solidFill(t);
      const tr = rectOf(t);
      if (!fg || !tr) continue;

      let best = null, bestArea = Infinity;
      for (const s of surfaces) {
        if (s.id === t.id) continue;
        const sr = rectOf(s);
        if (!sr || !contains(sr, tr)) continue;
        const area = sr.width * sr.height;
        if (area < bestArea) { bestArea = area; best = s; }
      }
      const surf = best ? solidFill(best) : boardFill;
      if (!surf) continue;

      const bgBase = boardFill ? boardFill.hex : "#FFFFFF";
      const bg = surf.opacity < 1 ? composite(surf.hex, bgBase, surf.opacity) : surf.hex;
      const fgHex = fg.opacity < 1 ? composite(fg.hex, bg, fg.opacity) : fg.hex;

      const size = Number(t.fontSize) || 0;
      const weight = Number(t.fontWeight) || 400;
      const large = size >= 18 || (size >= 14 && weight >= 700);
      const required = large ? AA_LARGE : AA_SMALL;
      const ratio = contrast(fgHex, bg);
      if (ratio >= required) continue;

      const isBrand = BRAND.has(fgHex);
      out.push(finding(board, t, isBrand ? "contrast-brand" : "contrast-neutral",
        isBrand ? "advisory" : "major",
        `${fgHex} on ${bg}${best ? ` (surface "${best.name}")` : " (board)"} = ` +
        `${ratio.toFixed(2)}:1, need ${required} at ${size}px/${weight}` +
        (isBrand ? " — brand hue, do NOT auto-fix (brand-tokens.md §6)" : "")));
    }
    return out;
  };

  /**
   * NEW — text-node overlap. The independent reviewer found C Decision Detail's
   * footer rendered as illegible mush on top of another text node while
   * automated QA reported zero issues (handoff §5.1). This is that check.
   */
  const checkTextOverlap = (board) => {
    const texts = textsIn(board).map((t) => ({ t, r: rectOf(t) })).filter((x) => x.r);
    const out = [];
    for (let i = 0; i < texts.length; i++) {
      for (let j = i + 1; j < texts.length; j++) {
        const a = texts[i], b = texts[j];
        const inter = intersectArea(a.r, b.r);
        if (inter <= 0) continue;
        const smaller = Math.min(a.r.width * a.r.height, b.r.width * b.r.height);
        if (smaller <= 0) continue;
        const share = inter / smaller;
        if (share < OVERLAP_TOLERANCE) continue;
        out.push(finding(board, a.t, "text-overlap", "major",
          `"${String(a.t.characters).slice(0, 40)}" overlaps ` +
          `"${String(b.t.characters).slice(0, 40)}" (${b.t.name}) by ` +
          `${Math.round(share * 100)}% of the smaller node`));
      }
    }
    return out;
  };

  /**
   * Text overflowing its OWN declared box.
   *
   * WHY THIS EXISTS: a copy change grew a gate question from 51 to 69
   * characters. On `D · Needs You` (25px Orbitron in a 900×34 box) it wrapped to
   * two lines and the second line rendered on top of the row beneath it.
   * `checkTextOverlap` did NOT catch it: the collision was ~1px of a 15%-area
   * threshold. The defect is not "two nodes collide", it is "this node does not
   * fit the box it declares", which is detectable without reference to
   * neighbours — and which predicts the collision instead of waiting for it.
   *
   * `textBounds` reports the *rendered* extent even when `growType` is "fixed",
   * so the comparison is real rather than estimated. A tolerance of 6px absorbs
   * the 1–2px line-height overshoot that several correct single-line nodes show.
   */
  const checkTextOverflow = (board) => {
    const out = [];
    for (const t of textsIn(board)) {
      const box = t.bounds, rendered = t.textBounds;
      if (!box || !rendered) continue;

      if (rendered.height > box.height + 6) {
        const lines = Math.round(rendered.height / Math.max(1, box.height));
        out.push(finding(board, t, "text-overflow", "major",
          `declares a ${Math.round(box.height)}px box but renders ` +
          `${Math.round(rendered.height)}px (~${lines} lines) at ${t.fontSize}px: ` +
          `"${String(t.characters).slice(0, 48)}"`));
      } else if (rendered.width > box.width + 4) {
        out.push(finding(board, t, "text-overflow", "major",
          `declares a ${Math.round(box.width)}px box but renders ` +
          `${Math.round(rendered.width)}px wide at ${t.fontSize}px: ` +
          `"${String(t.characters).slice(0, 48)}"`));
      }
    }
    return out;
  };

  /**
   * Content spilling out of its own CARD, as distinct from out of the board.
   *
   * WHY THIS EXISTS: on the mobile Needs-you board a primary button ended 2px
   * below the card it sat in. `checkContainment` passed it, because that check
   * validates descendants against the **board** — and the button was well inside
   * the board. The human spotted it as "uneven padding". It was not padding; the
   * content was outside its container.
   *
   * A card is identified by name (`… Bg`, `Card …`, `Panel …`). A shape is
   * treated as belonging to that card when it sits horizontally within it, which
   * avoids flagging neighbouring columns.
   */
  const CARD_NAME_RE = /(^|\s)(Card|Panel)(\s|$)|Bg\s*\d*$/;
  const checkCardSpill = (board) => {
    const out = [];
    const cards = penpotUtils.findShapes((s) => s.type !== "text" && CARD_NAME_RE.test(s.name || ""), board)
      .filter(isVisible)
      .filter((s) => { const r = rectOf(s); return r && r.width > 40 && r.height > 24; });

    for (const card of cards) {
      const cr = rectOf(card);
      if (!cr) continue;
      for (const s of penpotUtils.findShapes((x) => x.id !== card.id, board)) {
        if (!isVisible(s)) continue;
        const sr = rectOf(s);
        if (!sr || sr.width > cr.width || sr.height > cr.height) continue;
        const withinX = sr.x >= cr.x - 1 && sr.x + sr.width <= cr.x + cr.width + 1;
        const straddlesY = sr.y < cr.y + cr.height && sr.y + sr.height > cr.y;
        if (!withinX || !straddlesY) continue;
        const overTop = cr.y - sr.y;
        const overBottom = (sr.y + sr.height) - (cr.y + cr.height);
        if (overTop > 1 || overBottom > 1) {
          out.push(finding(board, s, "card-spill", "major",
            `"${s.name}" extends ${Math.round(Math.max(overTop, overBottom))}px ` +
            `outside "${card.name}" (${overBottom > 1 ? "below" : "above"} it)`));
        }
      }
    }
    return out;
  };

  /**
   * Shared chrome must be geometrically identical across every board that has it.
   *
   * WHY THIS EXISTS: the mobile bottom navigation is the same component on all
   * ten boards, but it was produced by a helper that changed mid-build. The
   * result: four boards had **no badge background at all**, the badge numeral
   * sat at two different offsets depending on which boards were built before
   * the helper was fixed, and three icon glyphs were each off-centre by a
   * different amount (1.5px, 3px, 4px). None of it was caught — every board
   * passed containment, overlap, overflow and contrast individually, because
   * each board was *internally* fine. The defect only exists *between* boards.
   *
   * Compares board-relative geometry only. Fills are deliberately ignored, so
   * dark and light variants of the same chrome compare equal.
   *
   * `names` is the set of shape names that constitute the shared chrome.
   * `boards` is the family to compare (e.g. all mobile boards).
   */
  const checkSharedChrome = (boards, names, opts = {}) => {
    const out = [];
    const tol = opts.tolerance == null ? 0.75 : opts.tolerance;
    if (!Array.isArray(boards) || boards.length < 2) return out;

    // Presence: every board must have the same chrome shapes.
    const present = boards.map((b) => ({
      board: b,
      have: new Set(names.filter((n) => findByName(b, n))),
    }));
    for (const n of names) {
      const withIt = present.filter((p) => p.have.has(n));
      if (withIt.length === 0 || withIt.length === boards.length) continue;
      for (const p of present.filter((x) => !x.have.has(n))) {
        out.push(finding(p.board, null, "chrome-missing", "major",
          `shared chrome "${n}" is present on ${withIt.length}/${boards.length} ` +
          `boards but missing here — the component has drifted between boards`));
      }
    }

    // Geometry: compare the LAYOUT BOX, not the rendered ink.
    //
    // `rectOf` returns a text node's ink extent, which legitimately differs
    // between boards: a nav label is weight 600 when its tab is active and 400
    // when it is not, so identical chrome produces different ink widths. Using
    // ink here produced a false positive on every inactive label. The box is
    // the layout contract; the ink is a consequence of state.
    //
    // Font SIZE and FAMILY are compared because those must never vary by state.
    // Font WEIGHT is not, for the reason above — pass `strictWeight` to include it.
    const ref = {};
    for (const b of boards) {
      for (const n of names) {
        const s = findByName(b, n);
        if (!s) continue;
        const bx = s.bounds;
        if (!bx) continue;
        const g = { x: bx.x - b.x, y: bx.y - b.y, w: bx.width, h: bx.height };
        const typo = s.type === "text"
          ? { fontSize: String(s.fontSize), fontFamily: String(s.fontFamily),
              ...(opts.strictWeight ? { fontWeight: String(s.fontWeight) } : {}) }
          : {};
        if (!ref[n]) { ref[n] = { g, typo, board: b.name }; continue; }
        const d = ["x", "y", "w", "h"].filter((k) => Math.abs(g[k] - ref[n].g[k]) > tol);
        if (d.length) {
          out.push(finding(b, s, "chrome-drift", "major",
            `shared chrome "${n}" differs from "${ref[n].board}" on ` +
            d.map((k) => `${k} ${g[k].toFixed(1)} vs ${ref[n].g[k].toFixed(1)}`).join(", ")));
        }
        const td = Object.keys(typo).filter((k) => typo[k] !== ref[n].typo[k]);
        if (td.length) {
          out.push(finding(b, s, "chrome-typography-drift", "major",
            `shared chrome "${n}" differs from "${ref[n].board}" on ` +
            td.map((k) => `${k} ${typo[k]} vs ${ref[n].typo[k]}`).join(", ")));
        }
      }
    }
    return out;
  };
  const findByName = (board, name) =>
    penpotUtils.findShapes((s) => s.name === name, board)[0] || null;

  /**
   * Glyphs that should read as centred within a container actually are.
   * `pairs` is a list of `{ container, parts }` name groups.
   */
  const checkOpticalCentring = (board, pairs, opts = {}) => {
    const out = [];
    const tol = opts.tolerance == null ? 0.75 : opts.tolerance;
    for (const { container, parts, label } of pairs) {
      const c = findByName(board, container);
      if (!c) continue;
      const cr = rectOf(c);
      const rs = parts.map((n) => findByName(board, n)).filter(Boolean).map(rectOf).filter(Boolean);
      if (!cr || rs.length === 0) continue;
      const top = Math.min(...rs.map((r) => r.y));
      const bot = Math.max(...rs.map((r) => r.y + r.height));
      const partMid = (top + bot) / 2;
      const contMid = cr.y + cr.height / 2;
      if (Math.abs(partMid - contMid) > tol) {
        out.push(finding(board, c, "optical-centring", "major",
          `${label || parts.join("+")} centres at ${partMid.toFixed(1)} but ` +
          `"${container}" centres at ${contMid.toFixed(1)} — off by ` +
          `${Math.abs(partMid - contMid).toFixed(1)}px`));
      }
    }
    return out;
  };

  /** Group text nodes into horizontal bands by vertical overlap (rows). */
  const bandsOf = (board) => {
    const items = textsIn(board).map((t) => ({ t, r: rectOf(t) })).filter((x) => x.r)
      .sort((p, q) => p.r.y - q.r.y);
    const bands = [];
    for (const it of items) {
      const band = bands[bands.length - 1];
      if (band && it.r.y < band.yMax - 2) {
        band.items.push(it);
        band.yMax = Math.max(band.yMax, it.r.y + it.r.height);
      } else {
        bands.push({ items: [it], yMin: it.r.y, yMax: it.r.y + it.r.height });
      }
    }
    return bands;
  };

  const uniq = (arr) => [...new Set(arr)];
  const matchAll = (s, re) => uniq(String(s).match(re) || []);

  /**
   * NEW — cross-field semantic consistency (handoff §5.2). A gate, the work item
   * it is bound to, and the durable state printed beside it must all agree with
   * MODEL. This is the class of defect that destroys trust on a surface
   * contracted to "every value is a read from durable state".
   */
  const checkSemanticConsistency = (board) => {
    const out = [];
    for (const band of bandsOf(board)) {
      const text = band.items.map((i) => i.t.characters).join("  ");
      const gates = matchAll(text, GD_RE);
      const wis = matchAll(text, WI_RE);
      const states = matchAll(text, STATE_RE);

      for (const g of gates) {
        // A resolved-decision history row is not a pending gate. Its recorded
        // work item and choice are historical durable facts, so it is checked
        // against `resolvedDecisions`, not against the pending-gate binding.
        const resolved = MODEL.resolvedDecisions[g];
        if (resolved) {
          for (const wi of wis) {
            if (wi !== resolved.workItemId) {
              out.push(finding(board, band.items[0].t, "semantic-resolved-binding", "major",
                `resolved decision ${g} rendered beside ${wi}; model records it against ${resolved.workItemId}`));
            }
          }
          continue;
        }

        const spec = MODEL.gates[g];
        if (!spec) {
          out.push(finding(board, band.items[0].t, "semantic-unknown-id", "major",
            `gate ${g} is in neither "gates" nor "resolvedDecisions"`));
          continue;
        }
        // R1: gate must be bound to the right work item.
        for (const wi of wis) {
          if (wi !== spec.workItemId) {
            out.push(finding(board, band.items[0].t, "semantic-gate-binding", "major",
              `${g} rendered beside ${wi}; model binds it to ${spec.workItemId}`));
          }
        }
        // HD-A/A1: the state printed beside a pending gate is the DURABLE state,
        // which for a blocked item is `waiting_for_human_decision`. The pre-gate
        // state is a different field and is allowed to appear too.
        const wi = MODEL.workItems[spec.workItemId];
        const allowed = [wi.state, wi.preGateState].filter(Boolean);
        for (const st of states) {
          if (!allowed.includes(st)) {
            out.push(finding(board, band.items[0].t, "semantic-state", "major",
              `${g} rendered beside state "${st}"; ${spec.workItemId} permits ` +
              `${allowed.map((s) => `"${s}"`).join(" or ")}`));
          }
        }
      }

      // Work-item rows with no gate: state must still match the model.
      if (gates.length === 0) {
        for (const w of wis) {
          const spec = MODEL.workItems[w];
          if (!spec) {
            out.push(finding(board, band.items[0].t, "semantic-unknown-id", "major",
              `work item ${w} is not in the sample-data model`));
            continue;
          }
          const allowed = [spec.state, spec.preGateState].filter(Boolean);
          for (const st of states) {
            if (!allowed.includes(st)) {
              out.push(finding(board, band.items[0].t, "semantic-state", "major",
                `${w} rendered with state "${st}"; model permits ` +
                `${allowed.map((s) => `"${s}"`).join(" or ")}`));
            }
          }
        }
      }
    }
    return out;
  };

  /**
   * HD-A/A1 — a field explicitly labelled "DURABLE STATE" must print
   * `WorkItem.state`, never the pre-gate state. This is the specific defect R10
   * records: the boards print `design_in_review  (WorkItem.state)` for a work
   * item that is actually `waiting_for_human_decision`.
   *
   * Takes the value from the band adjacent to the label, so it does not depend
   * on shape naming conventions that differ between directions.
   */
  const checkDurableStateField = (board) => {
    const out = [];
    const labels = MODEL.durableStateFieldLabels;
    const texts = textsIn(board).map((t) => ({ t, r: rectOf(t) })).filter((x) => x.r);

    for (const { t, r } of texts) {
      const c = String(t.characters).trim().toUpperCase().replace(/[()]/g, "");
      if (!labels.some((l) => c === l)) continue;

      // Nearest text node to the right of, or directly below, the label.
      let best = null, bestD = Infinity;
      for (const o of texts) {
        if (o.t.id === t.id) continue;
        const dx = o.r.x - r.x, dy = o.r.y - r.y;
        if (dx < -2 || dy < -2) continue;
        const d = Math.abs(dx) + Math.abs(dy) * 1.5;
        if (d < bestD) { bestD = d; best = o; }
      }
      if (!best || bestD > 260) continue;
      const printed = matchAll(best.t.characters, STATE_RE);
      if (printed.length === 0) continue;

      // Which work item does this block concern?
      const blockText = texts
        .filter((o) => Math.abs(o.r.y - r.y) < 200)
        .map((o) => o.t.characters).join("  ");
      const wis = matchAll(blockText, WI_RE).filter((w) => MODEL.workItems[w]);
      const gates = matchAll(blockText, GD_RE).filter((g) => MODEL.gates[g]);
      const subject = wis[0] || (gates[0] && MODEL.gates[gates[0]].workItemId);
      if (!subject) continue;

      const expected = MODEL.workItems[subject].state;
      for (const p of printed) {
        if (p !== expected) {
          out.push(finding(board, best.t, "durable-state-field", "major",
            `field "${t.characters}" prints "${p}" for ${subject}, whose durable ` +
            `state is "${expected}"` +
            (p === MODEL.workItems[subject].preGateState
              ? " — that is the PRE-GATE state, which belongs in a different field (HD-A/A1)"
              : "")));
        }
      }
    }
    return out;
  };

  /**
   * R2 lifecycle triple: phase label, highlighted lane segment, and printed
   * durable state must assert one position.
   *
   * The highlighted-segment half cannot be resolved without knowing how lane
   * segments are named and filled in the actual boards. Rather than report a
   * pass for a check that did not run, the highlighted-segment dimension is
   * reported as NOT ASSESSED unless a
   * `segmentResolver(board, gateId) -> activePhaseIndex|null` is supplied. A
   * suite that silently skips a dimension and still says "0 issues" is how the
   * original contradiction reached the reviewer.
   *
   * HD-A/A1 settled which value the lane reads (the pre-gate state), so the
   * previously-unresolved half of this check is now decidable.
   */
  const checkLifecycleTruth = (board, segmentResolver) => {
    const out = [];
    if (!segmentResolver) {
      out.push(finding(board, null, "lifecycle-segment-not-assessed", "unresolved",
        "no segmentResolver supplied, so the highlighted lane segment was NOT " +
        "compared against the declared phase; the label and printed state were"));
    }

    // A phase label is attributed to the ids in ITS OWN BAND, never board-wide.
    //
    // An earlier board-wide version of this check produced a false positive: on
    // `C · Home` the label "HALTED AT BUILD" sits in a band with WI-3d8c
    // (agent_failed -> phase 2, correct), but a board-wide scan pinned it to
    // GD-5b1e in a different band and reported a contradiction that did not
    // exist. A check that mis-attributes evidence is worse than no check, so
    // attribution is band-scoped and an unattributable label is reported as
    // exactly that rather than blamed on an arbitrary gate.
    // CASE-SENSITIVE and restricted to the actual phase words. An earlier
    // case-insensitive `([A-Z]+)` version matched ordinary body prose —
    // "Autonomous execution has stopped at these points by design" produced a
    // bogus `AT THESE` phase on three boards. A lifecycle label is rendered in
    // caps; prose is not, so case is the signal that separates them.
    const PHASE_LABEL_RE = new RegExp(
      `(?:HELD|HALTED|STOPPED)\\s+AT\\s+(${MODEL.phases.join("|")})\\b`);

    // Gate ids on this board, used for single-subject attribution below.
    const boardGates = matchAll(textsIn(board).map((t) => t.characters).join("  "), GD_RE)
      .filter((g) => MODEL.gates[g]);

    for (const band of bandsOf(board)) {
      const text = band.items.map((i) => i.t.characters).join("  ");
      const m = PHASE_LABEL_RE.exec(text);
      if (!m) continue;
      const shown = m[1];
      const shownIndex = MODEL.phases.indexOf(shown);

      // Resolve the subject of this label from its own band first.
      const gates = matchAll(text, GD_RE).filter((g) => MODEL.gates[g]);
      const wis = matchAll(text, WI_RE).filter((w) => MODEL.workItems[w]);
      let subjects = [
        ...gates.map((g) => ({ id: g, phaseIndex: MODEL.gates[g].phaseIndex, workItemId: MODEL.gates[g].workItemId })),
        ...wis.map((w) => ({ id: w, phaseIndex: MODEL.stateToPhase[MODEL.workItems[w].state], workItemId: w })),
      ];

      // Single-subject surface: if the whole board concerns exactly one gate,
      // a label anywhere on it unambiguously refers to that gate even though it
      // sits in its own band (this is how the Decision Detail boards are laid
      // out). Requiring band adjacency there would under-report a real defect.
      if (subjects.length === 0 && boardGates.length === 1) {
        const g = boardGates[0];
        subjects = [{ id: g, phaseIndex: MODEL.gates[g].phaseIndex, workItemId: MODEL.gates[g].workItemId,
                      viaSingleSubject: true }];
      }

      if (subjects.length === 0) {
        out.push(finding(board, band.items[0].t, "lifecycle-label-unattributed", "advisory",
          `phase label "AT ${shown}" has no work item or gate id in its own band, ` +
          `and the board concerns ${boardGates.length} gates, so it cannot be ` +
          `attributed to a subject and is NOT verified`));
        continue;
      }
      for (const s of subjects) {
        if (s.phaseIndex == null) continue; // derivation gap reported separately
        if (s.phaseIndex !== shownIndex) {
          out.push(finding(board, band.items[0].t, "lifecycle-label", "major",
            `${s.id} shows "AT ${shown}" (phase ${shownIndex}); model derives phase ` +
            `${s.phaseIndex} (${MODEL.phases[s.phaseIndex]})`));
        }
      }
    }

    // Derivation integrity: under HD-A/A1 the lane position comes from the
    // pre-gate state, so that is what must agree with the declared phase.
    const boardText = textsIn(board).map((t) => t.characters).join("  ");
    for (const g of matchAll(boardText, GD_RE)) {
      const spec = MODEL.gates[g];
      if (!spec) continue;
      const wi = MODEL.workItems[spec.workItemId];
      const basis = wi.preGateState || wi.state;
      const derived = MODEL.stateToPhase[basis];
      if (derived == null) {
        out.push(finding(board, null, "lifecycle-derivation", "major",
          `${g}: neither preGateState nor state ("${basis}") maps to a lane phase`));
      } else if (derived !== spec.phaseIndex) {
        out.push(finding(board, null, "lifecycle-derivation", "major",
          `${g}: declares phase ${spec.phaseIndex} but "${basis}" derives ${derived}`));
      }
      if (segmentResolver) {
        const active = segmentResolver(board, g);
        if (active != null && active !== spec.phaseIndex) {
          out.push(finding(board, null, "lifecycle-segment", "major",
            `${g}: highlighted segment ${active} != declared phase ${spec.phaseIndex}`));
        }
      }
    }
    return out;
  };

  /**
   * Phase-caption highlight must agree with the highlighted lane segment.
   *
   * WHY THIS EXISTS: this defect escaped every mechanical check above and was
   * caught only by exporting the board and looking at it. After the lane
   * segments were corrected to the declared phase, the *captions* still
   * highlighted the old phase — `C · Needs You` filled segments through DESIGN
   * while the caption highlighted BUILD, and through BUILD while the caption
   * highlighted QA. Two encodings of one fact, disagreeing, which is the exact
   * class of defect the independent reviewer found in the first place.
   *
   * A caption row is a set of text nodes whose contents are phase names sharing
   * a y band. The highlighted one is the node whose fill differs from the row's
   * majority (neutral) fill.
   */
  const checkPhaseCaptionHighlight = (board, segmentResolver) => {
    const out = [];
    const caps = textsIn(board)
      .filter((t) => MODEL.phases.includes(String(t.characters).trim().toUpperCase()));
    if (caps.length === 0) return out;

    // Group captions into rows by vertical proximity.
    const rows = [];
    for (const t of caps.slice().sort((a, b) => rectOf(a).y - rectOf(b).y)) {
      const r = rectOf(t);
      const row = rows[rows.length - 1];
      if (row && Math.abs(rectOf(row[0]).y - r.y) < 12) row.push(t);
      else rows.push([t]);
    }

    for (const row of rows) {
      if (row.length < 2) continue;
      const counts = {};
      for (const t of row) {
        const f = solidFill(t);
        if (f) counts[f.hex] = (counts[f.hex] || 0) + 1;
      }
      const sorted = Object.entries(counts).sort((a, b) => b[1] - a[1]);
      if (sorted.length < 2) continue; // uniform row = shared legend, no assertion
      const neutral = sorted[0][0];
      const highlighted = row.filter((t) => (solidFill(t) || {}).hex !== neutral);
      if (highlighted.length === 0) continue;
      if (highlighted.length > 1) {
        out.push(finding(board, highlighted[0], "caption-multi-highlight", "major",
          `${highlighted.length} phase captions are highlighted in one row ` +
          `(${highlighted.map((t) => t.characters).join(", ")}); a row asserts one position`));
        continue;
      }
      const shown = String(highlighted[0].characters).trim().toUpperCase();
      const shownIndex = MODEL.phases.indexOf(shown);

      // Compare against the segment row at the same vertical position, if resolvable.
      if (!segmentResolver) {
        out.push(finding(board, highlighted[0], "caption-highlight-not-assessed", "unresolved",
          `caption highlights ${shown} but no segmentResolver was supplied, so it ` +
          `was NOT compared against the lane segments`));
        continue;
      }
      const boardGates = matchAll(textsIn(board).map((t) => t.characters).join("  "), GD_RE)
        .filter((g) => MODEL.gates[g]);
      for (const g of boardGates) {
        const active = segmentResolver(board, g, rectOf(highlighted[0]));
        if (active == null || active === shownIndex) continue;
        out.push(finding(board, highlighted[0], "caption-highlight", "major",
          `caption highlights ${shown} (phase ${shownIndex}) but ${g}'s lane ` +
          `segments fill through phase ${active} (${MODEL.phases[active]})`));
      }
    }
    return out;
  };

  /**
   * HD-B/B1 — a gate's control labels must be that gate TYPE's labels, and a
   * routing row must quote the control it routes for.
   *
   * Scoped per gate type, because the labels legitimately differ: a
   * `design_approval` gate offers `Reject` (matching
   * HumanDecisionType.designRejection) while a `qa_rework` gate offers
   * `Stop run`. A global forbidden-word list — which is what R6 as written
   * implies — would also corrupt resolved-decision history copy such as
   * "Reject design revision DES-R2", so history rows are exempt.
   */
  const checkEnumLabels = (board) => {
    const out = [];
    const texts = textsIn(board);
    const boardText = texts.map((t) => t.characters).join("  ");
    const gates = matchAll(boardText, GD_RE).filter((g) => MODEL.gates[g]);

    // Copy that belongs to resolved history, exempt from control-label rules.
    const resolvedCopy = new Set(
      Object.values(MODEL.resolvedDecisions).flatMap((r) => [r.desc.toLowerCase(), r.choice.toLowerCase()]));

    for (const t of texts) {
      const raw = String(t.characters).trim();
      const c = raw.toLowerCase();
      if (resolvedCopy.has(c)) continue;

      // A short, bold, standalone string in a decision surface is a control label.
      const isControlish = raw.length < 24 && Number(t.fontWeight) >= 500 &&
        /^(approve|reject|request changes|stop run|resume|waive|decline|cancel)$/i.test(raw);
      if (!isControlish) continue;

      const permitted = new Set(gates.flatMap((g) => MODEL.gates[g].controls.map((s) => s.toLowerCase())));
      if (permitted.size === 0) continue;
      if (!permitted.has(c)) {
        out.push(finding(board, t, "enum-label", "major",
          `control label "${raw}" is not offered by the gate(s) on this board ` +
          `(${gates.join(", ")} permit: ${[...permitted].join(" / ")})`));
      }
    }

    // Routing rows must name a real choice of a gate on this board.
    for (const t of texts) {
      const raw = String(t.characters).trim();
      if (raw.length > 24 || Number(t.fontWeight) >= 500) continue;
      const c = raw.toLowerCase();
      if (resolvedCopy.has(c)) continue;
      if (!/^(approve|reject|request changes|stop run|resume|waive)$/i.test(raw)) continue;
      const permitted = new Set(gates.flatMap((g) => Object.keys(MODEL.gates[g].routing)));
      if (permitted.size === 0) continue;
      if (!permitted.has(c)) {
        out.push(finding(board, t, "routing-label", "major",
          `routing row "${raw}" is not a choice of ${gates.join(", ")} ` +
          `(choices: ${[...permitted].join(" / ")})`));
      }
    }
    return out;
  };

  /**
   * R1 — the sample data must be internally possible before any board renders
   * it. Needs no Penpot state. A work item cannot be mid-execution and halted
   * behind a human gate at the same time.
   */
  const checkModelCoherence = () => {
    const out = [];
    const bad = (detail) => out.push({ check: "model-coherence", severity: "major", detail });

    for (const [g, spec] of Object.entries(MODEL.gates)) {
      const wi = MODEL.workItems[spec.workItemId];
      if (!wi) { bad(`${g} targets unknown ${spec.workItemId}`); continue; }

      // A pending gate implies the work item is blocked on a human.
      if (!MODEL.gateCompatibleStates.includes(wi.state)) {
        bad(`${g} blocks ${spec.workItemId} whose state "${wi.state}" cannot coexist ` +
            `with a pending gate (allowed: ${MODEL.gateCompatibleStates.join(", ")})`);
      }
      // HD-A/A1: a blocked item must declare where it halted, and the lane phase
      // must derive from that, not be authored independently.
      if (!wi.preGateState) {
        bad(`${spec.workItemId} is blocked by ${g} but declares no preGateState, ` +
            `so its lane position would be authored rather than derived (HD-A/A1)`);
      } else {
        const derived = MODEL.stateToPhase[wi.preGateState];
        if (derived == null) bad(`${spec.workItemId}: preGateState "${wi.preGateState}" has no lane phase`);
        else if (derived !== spec.phaseIndex) {
          bad(`${g} declares phase ${spec.phaseIndex} but ${spec.workItemId}'s ` +
              `preGateState "${wi.preGateState}" derives ${derived}`);
        }
        if (wi.phase != null && wi.phase !== spec.phaseIndex) {
          bad(`${spec.workItemId}.phase (${wi.phase}) disagrees with ${g}.phaseIndex (${spec.phaseIndex})`);
        }
      }
      // The declared label must name the declared phase.
      const labelPhase = (/(?:HELD|HALTED|STOPPED)\s+AT\s+([A-Z]+)/.exec(spec.phaseLabel) || [])[1];
      if (labelPhase && MODEL.phases.indexOf(labelPhase) !== spec.phaseIndex) {
        bad(`${g}.phaseLabel "${spec.phaseLabel}" names phase ` +
            `${MODEL.phases.indexOf(labelPhase)} but phaseIndex is ${spec.phaseIndex}`);
      }
      // Every control must have a routing target and vice versa.
      const controls = spec.controls.map((s) => s.toLowerCase()).sort();
      const routes = Object.keys(spec.routing).sort();
      if (JSON.stringify(controls) !== JSON.stringify(routes)) {
        bad(`${g}: controls [${controls.join(", ")}] do not match routing keys [${routes.join(", ")}]`);
      }
    }

    // Resolved history must reference known work items and not collide with
    // pending gate ids.
    for (const [g, r] of Object.entries(MODEL.resolvedDecisions)) {
      if (MODEL.gates[g]) bad(`${g} is declared both as a pending gate and as resolved history`);
      if (!MODEL.workItems[r.workItemId]) bad(`resolved ${g} references unknown ${r.workItemId}`);
    }
    return out;
  };

  // ----------------------------------------------------------------- reporting

  const CHECKS = {
    containment: checkContainment,
    legibility: checkLegibility,
    contrast: checkContrast,
    textOverlap: checkTextOverlap,
    textOverflow: checkTextOverflow,
    cardSpill: checkCardSpill,
    semanticConsistency: checkSemanticConsistency,
    durableStateField: checkDurableStateField,
    phaseCaptionHighlight: checkPhaseCaptionHighlight,
    lifecycleTruth: checkLifecycleTruth,
    enumLabels: checkEnumLabels,
  };

  const runAll = (filter, opts = {}) => {
    const boards = studyBoards(filter);
    const findings = [];
    for (const b of boards) {
      for (const [name, fn] of Object.entries(CHECKS)) {
        if (opts.only && !opts.only.includes(name)) continue;
        try {
          findings.push(...fn(b, opts.segmentResolver));
        } catch (e) {
          findings.push(finding(b, null, name, "error", String(e && e.message || e)));
        }
      }
    }
    const model = checkModelCoherence();
    const bySeverity = {}, byCheck = {};
    for (const f of [...findings, ...model]) {
      bySeverity[f.severity] = (bySeverity[f.severity] || 0) + 1;
      byCheck[f.check] = (byCheck[f.check] || 0) + 1;
    }
    return {
      boardsScanned: boards.length,
      boards: boards.map((b) => b.name),
      bySeverity, byCheck,
      // Honest reporting: an empty `findings` list is NOT a pass if `unresolved`
      // is non-empty. Checks that did not run are counted, not hidden.
      unresolvedCount: bySeverity.unresolved || 0,
      modelFindings: model,
      findings,
    };
  };

  return {
    PAGE_ID, MODEL, BRAND, BRAND_BACKGROUNDS,
    contrast, luminance, composite, solidFill, rectOf, contains, intersectArea,
    studyBoards, textsIn, surfacesIn, bandsOf,
    checkContainment, checkLegibility, checkContrast, checkTextOverlap, checkTextOverflow, checkCardSpill,
    checkSharedChrome, checkOpticalCentring,
    checkSemanticConsistency, checkDurableStateField, checkLifecycleTruth,
    checkPhaseCaptionHighlight, checkEnumLabels, checkModelCoherence,
    runAll,
  };
})();

return {
  loaded: true,
  checks: Object.keys(storage.dq).filter((k) => k.startsWith("check")),
  modelCoherence: storage.dq.checkModelCoherence(),
};
