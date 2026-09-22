# SESSION HANDOFF — resume point

**Written:** 2026-09-15
**Reason:** Penpot browser plugin tab suspends repeatedly; session must be resumed fresh.

---

## ⚠️ CORRECTIONS APPLIED 2026-09-15 (resume session) — read before anything else

This handoff contained three false statements, found by measuring the live Penpot
file rather than trusting the record. They are corrected in place below and in
`001-control-plane-operator-ui-visual-direction-study.md` §6.1, §7, §8, §9.1–§9.4, §12.

| Claim in this handoff | Reality |
|---|---|
| "All 18 boards were built brand-compliant" (§1, §2) | Only **16** existed; the two `D · … · Light` ids resolved to `null`. **Both have since been built (R14) — 18 boards now genuinely exist.** New ids in study §6 |
| Study §7: legibility + neutral contrast "auto-corrected" to 0 | **Never applied.** 48 sub-9px nodes (all on C) and 274 contrast failures are still live. Only the containment result (0) held |
| R1–R7 are all mechanical and ready to apply | **R2 and R6 are defective as specified** and are blocked on human decisions (study §12 HD-A, HD-B) |

**Also now true:** the automated QA suite is no longer session-bound. It lives at
`docs/design/qa/design-qa.js` with a node harness `design-qa.test.js`
(**50 assertions**, all passing — run `node docs/design/qa/design-qa.test.js`).
It includes the checks the independent reviewer caught that the old suite missed,
plus `text-overflow` and `caption-highlight` — two classes that were invisible to
the suite and were caught only by exporting the boards and looking at them. It
also found 6 of its own false positives against real boards before any number was
recorded. **Do not re-author QA code in `storage` again.**

**Current status: 18 boards exist, zero major findings, `DCR-AC-1/2/3` satisfied.**
Human decisions **HD-A=A1, HD-B=B1, HD-C=C1, HD-D=D1** were recorded 2026-09-15
and both correction passes were applied — see study §9.5 (R1–R13) and §9.6
(R7, R11, R12, R14, plus new R15/R16).

**Measured: 391 findings → 45, all advisory.** The 45 are brand-palette
shortfalls that must NOT be auto-fixed (`brand-tokens.md` §6, brand-owner call).

### ONLY remaining work

1. **`DCR-AC-4` — targeted independent re-review.** The §8 scorecard was formed
   against boards that have since changed materially. **D especially: it gained a
   routing disclosure, a dense list primitive, full dataset parity, and two boards
   that did not previously exist.** A re-review comparing against the old D would
   be comparing against a different artifact. Must be a **separate execution**
   (designer self-approval fails `DCR-AC-4`). Model diversity records
   `not_available` and needs **no waiver** (003 §7.2).
2. **`DCR-AC-5`** — the human's selection at the §11 gate, after the re-review.
3. **R4** — deliberately not applied; no mechanical defect exists. Human call.

### Open findings for the human, not defects

- 45 brand-palette contrast advisories (003/`brand-tokens.md` §6).
- D's unselected radios render as solid dots rather than empty rings, in **both**
  modes. Inherited from D's original dark design; flagged rather than silently
  redesigned.
- §10's directional findings (brand gradients unused, D drops mint, etc.) remain
  open by design.

### CURRENT DESIGN STATE — 2026-09-15

| Lineage | Boards | Status |
|---|--:|---|
| Original 2026-09-14 | 10 | Preserved. The only visual record of what the running Flutter app implements |
| `B · …` | 6 | **Implementation-authoritative** (`DCR-001` = `SELECT_B`) |
| `BP · …` desktop | 10 | Plain-language variant, 5 surfaces × dark/light. `DCR-002` **OPEN** |
| `BPM · …` mobile | 10 | 5 surfaces × dark/light, 390×844, bottom nav |
| `C · …`, `D · …` | 0 | **Deleted** — not selected |

**36 boards. 0 major mechanical findings across all 26 B/BP/BPM boards.**

Two suite defects were found and fixed while building mobile:

1. **`STUDY_BOARD_RE` was `/^[BCD] · /`** — it matched **none** of the adopted
   `BP ·` or `BPM ·` boards. `runAll()` would have scanned zero boards and
   reported zero findings. Now `/^(BPM|BP|[BCD]) · /`, verified to match 26.
2. **`card-spill` added.** `checkContainment` validates against the *board*, so a
   button sitting 2px outside its own *card* passed clean. A human caught it as
   "uneven padding". Now checked, with a regression test asserting that
   containment alone does **not** catch it.

### Do this on every resume
```
node docs/design/qa/design-qa.test.js      # 36 assertions; proves the suite works
```
Then paste `docs/design/qa/design-qa.js` into `penpot_execute_code` and run
`storage.dq.runAll(undefined, { segmentResolver })`. **Then export the boards and
look at them** — two real defects in this round were invisible to the suite and
were caught only in the rendered image (study §9.5).

---

## 0. READ THESE FIRST, IN ORDER

1. `AGENTS.md` (repo root) — especially §13 Penpot/credential rules
2. `docs/design/brand-tokens.md` — **authoritative brand values, do not re-derive**
3. `docs/checkpoints/001-control-plane-operator-ui-visual-direction-study.md` — the live work
4. `docs/checkpoints/001-control-plane-operator-ui-design-change-request.md` — DCR-001
5. `docs/checkpoints/002-human-bug-reporting-ai-defect-triage-planning.md` — parked feature
6. `docs/checkpoints/003-design-governance-automation-planning.md` — future platform slice

---

## 1. WHERE WE ARE

Three governed threads are in flight:

| Feature | State |
|---|---|
| `CONTROL_PLANE_OPERATOR_UI_001` | Human QA = `REQUEST_DESIGN_CHANGE` → `DCR-001` open → visual direction study done → **awaiting `VISUAL_DIRECTION_APPROVAL_REQUIRED`** |
| `HUMAN_BUG_REPORTING_001` | `READY_FOR_DESIGN — PARKED` pending visual language selection |
| `DESIGN_GOVERNANCE_AUTOMATION_001` | `READY_FOR_PLANNING_REVIEW`, spec only, nothing implemented |

**Implementation status of the operator UI is unchanged and healthy:** 7/7 E2E tests against
real PostgreSQL, 19 BLoC tests, 4 widget, 3 responsive, 5 accessibility, 8 golden,
format + analyze clean. Nothing was deleted. No Flutter code was touched in the design work.

---

## 2. IMMEDIATE NEXT ACTION

Apply the **correction round R1–R7** specified in
`001-control-plane-operator-ui-visual-direction-study.md` §9, then hand the human the
`VISUAL_DIRECTION_APPROVAL_REQUIRED` gate.

### Why it didn't finish
~~All 18 boards were built brand-compliant.~~ **16 of the 18 boards were built** — the
tab suspended part-way through the D light row, so `D · Needs You · Light` and
`D · Decision Detail · Light` do not exist. The correction code was written and staged
into the Penpot session `storage` object, but the tab suspended before the rebuild ran.
**`storage` is session-bound and is now gone.** The 16 boards persist in the file.

The mechanical QA corrections study §7 reported as applied were **also** lost the
same way, but were reported as *done* rather than as *staged* — which is why §7 has
been retracted and remeasured.

### Two options for applying corrections

**Option A — targeted edits (RECOMMENDED).** The 16 boards exist. Most corrections are
surgical: rename text nodes, recolour fills, reposition two elements. This matches the
targeted-correction model in `DESIGN_GOVERNANCE_AUTOMATION_001` §8 and avoids rebuilding
~1400 shapes. R7 (D's consequence table) is the only genuine addition.

**Option B — full rebuild.** Requires re-authoring the builder JS from scratch. Expensive.
Only do this if the boards are found to be damaged.

**Verify current state first:**
```js
const page = penpotUtils.getPageById("d8ac01df-6646-81d2-8008-a366c09aa9d3");
return page.root.children.filter(c => /^[BCD] · /.test(c.name||"")).map(c => ({name:c.name, id:c.id}));
```
Expect **18** boards (verified 2026-09-15, after R14 built the 2 missing D light
boards). If you get 18, the correction rounds are applied; use Option A for any
further edits. If 0, use Option B.

**Then load the QA suite from disk and remeasure** rather than trusting any count
in these documents:
```
node docs/design/qa/design-qa.test.js   # 22 assertions, proves the suite works
```
then paste `docs/design/qa/design-qa.js` into `penpot_execute_code` and call
`storage.dq.runAll(undefined, { segmentResolver })`.
**Current state as of 2026-09-15: 45 findings across 18 boards, all advisory, zero majors.**

---

## 3. PENPOT SESSION FACTS (must be re-established)

| Item | Value |
|---|---|
| Team | `c828d3cf-7d4e-8145-8008-98dfd6576a0c` |
| File | `d8ac01df-6646-81d2-8008-a366c09aa9d3` |
| Page | `d8ac01df-6646-81d2-8008-a366c09aa9d3` |
| Uploaded logomark media id | `c514c1fb-1cda-8125-8008-a48a2b732164` (64×65 png) |

**The logomark is already uploaded to the file** — do NOT re-upload. Reference it as:
```js
r.fills = [{ fillOpacity: 1, fillImage: { id: "c514c1fb-1cda-8125-8008-a48a2b732164",
             width: 64, height: 65, mtype: "image/png" } }];
```
If that fails, re-upload from `docs/design/assets/shipit-logomark-64.png` using
**base64url** encoding (see §6 — plain base64 corrupts in transit).

### Original approved design — DO NOT TOUCH
15 shapes at y=0 (dark) and y=950 (light). Boards: Home `26213ee5-8af7-8000-8008-a369e295bbc4`,
Runs `…a36b4fe4e7dc`, Run Detail `…a36b7d04d351`, Needs You `…a36b90375a7b`,
Decision Detail `…a36bafa46126`. These are preserved historical evidence per DCR-001 §4.

---

## 4. HARD-WON LESSONS — do not repeat these mistakes

1. **CHECK FOR BRAND ASSETS BEFORE DESIGNING.** I invented three palettes (signal blue, cyan,
   lime+violet) and had to discard all 18 boards when the human pointed at
   `Logo and Brand Guide Lines.png`. Brand tokens are now in `docs/design/brand-tokens.md`.

2. **Sample hex values from pixels, don't read them off rendered text.** Small label text in
   the guide is ambiguous. `PIL` + `im.getpixel()` gives exact values.

3. **Penpot `uploadMediaData` corrupts plain base64 in transit** — a `+` (0x2B) arrives as
   `/` (0x2F). Use `base64.urlsafe_b64encode` and convert back in JS with
   `.replace(/-/g,"+").replace(/_/g,"/")`. Verify with a character-sum checksum before upload.

4. **Chunk large strings** (~3KB per call) and checksum each chunk.

5. **`eval()` on a stringified stored function loses its closure over `storage`.** Redefine
   functions explicitly instead.

6. **Font weights are per-family.** IBM Plex Sans has no 450. Clamp weights to the family's
   actual variants before setting.

7. **Penpot tab suspends after ~30–120s idle.** Batch work into fewer, larger calls. Re-verify
   state after any timeout — a "timed out" call may actually have **succeeded**.

8. **Automated contrast QA must be surface-aware.** Comparing text against the *board*
   background produces false positives for text on buttons. Resolve the smallest
   geometrically-containing filled rect or ellipse.

---

## 5. WHAT THE INDEPENDENT REVIEWER CAUGHT THAT AUTOMATED QA MISSED

Add both to the automated suite before the next design round:

1. **Text-node overlap detection** — two text nodes rendering on top of each other
   (C Decision Detail footer was illegible mush; QA reported 0 issues).
2. **Cross-field semantic consistency** — a lifecycle label, a highlighted rail segment, and a
   printed durable state all asserting different positions on one screen.

Also worth adding: **sample-data coherence assertions** (a WorkItem cannot be both
`agent_executing` and gate-blocked — this contradiction reached the reviewer).

---

## 6. INDEPENDENCE — SATISFIED. Do not re-raise this as a caveat.

The independent design review achieved **execution independence**: separate execution,
fresh context, no knowledge of designer intent, judged only rendered output.
**That is the whole of the independence requirement** (`DESIGN_GOVERNANCE_AUTOMATION_001`
§7.1), and it is satisfied.

Recorded attribute: **`reviewerModelDiversity: not_available`** — one model family is
available to this deployment (`agent_runtime` ships a single adapter; a second provider
is deferred as DI-10). This is a fact to record, **not a violation, limitation, or
caveat.** Model diversity has no violation state (§7.2).

> **This section previously told every future session to carry forward an "independence
> caveat".** It was wrong, and it worked: the caveat propagated into three documents and
> attached a standing qualifier to a valid review. §7.2.2 of
> `DESIGN_GOVERNANCE_AUTOMATION_001` now fixes the disclosure wording and lists the
> phrasings to avoid. **State the recorded value; add nothing around it.**

---

## 7. THINGS EXPLICITLY NOT DONE (and must stay not-done until gated)

- No Flutter/production UI changes
- No `shipit_ui` changes
- No Serverpod defect endpoints, no DB migrations, no scheduler changes
- No GCS implementation
- No `HUMAN_BUG_REPORTING_001` screen design
- No design-governance automation implementation
- The approved design lineage was not overwritten or deleted

---

## 8. OPEN QUESTIONS FOR THE HUMAN

1. **The gate:** `KEEP_CURRENT` / `SELECT_B` / `SELECT_C` / `SELECT_D` / `REQUEST_HYBRID` /
   `REQUEST_NEW_DIRECTIONS`. Reviewer advises C (57) over B (56) — genuinely close.
2. **Brand accessibility:** the official palette misses AA for small text (ratios 4.02–4.42 vs
   4.5). Three mitigation options in `docs/design/brand-tokens.md` §6. Needs a brand-owner call.
3. **Good Times licensing:** is the real font available for production? If not, the substitute
   needs brand sign-off and the lockup must ship as imported SVG.
4. **Brand gradients:** none of the three directions uses them. Should the selected direction
   be required to incorporate the warm and/or cool gradient?
5. **`DI-1` … `DI-13`** in `003-design-governance-automation-planning.md` §17 remain
   deferred. (This line previously said "HD-1..HD-5", which do not exist in that
   document — its deferred items are `DI-`prefixed. Nothing was unanswered that is
   not listed in §17.)
