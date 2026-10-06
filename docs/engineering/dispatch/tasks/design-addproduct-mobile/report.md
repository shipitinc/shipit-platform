# Report — Design Agent, `design-addproduct-mobile`

> **SUPERSEDED — this is revision 1's report. The current revision is `design-revision-4.md`; the current
> lane report is `correction-report-4.md`.** This file is retained **unedited** so the correction history
> stays diffable. Retention without a marker is not neutral — a reader who opens this file first sees only
> this file — so **three claims inside it are disproven and are marked in place**: the "no `500` weight"
> claim (**line 120**, marked), and the 36px `minimumSize` derivation (**lines 62 and 224**, marked).
>
> **Line numbers corrected at revision 4 (L-R3).** "line ~100" and "lines ~48 and ~197" were correct when
> revision 3 wrote them and were invalidated by the `WITHDRAWN` markers, which sit *at* those sites. The
> body's text is untouched. The `BRANCH` field below is **correct for revision 1's own lane** — see the
> provenance note at **lines 31-37**, which supersedes the older "marker at line ~13" pointer and must not
> be "corrected".

Returned verbatim by the `design-agent` lane and persisted here per `aef-orchestrator` §14.

## Mandatory header

```yaml
RESULT: DESIGN_REVISION_COMPLETE
TASK_ID: design-addproduct-mobile
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — four missing SM mobile boards + layout/copy corrections (points 2e-2f, 2a UI cues)
WORKTREE: /private/tmp/shipit-design-addproduct-mobile
BRANCH: design/addproduct-mobile
BASE_SHA: 77c19f1
HEAD_SHA: 77c19f1
COMMITTED: NO
```

> **Provenance note (added at revision 3; extended at revision 4).** The `WORKTREE` and `BRANCH` above are
> **correct for this lane**: `git worktree list` at HEAD `77c19f1` lists
> `/private/tmp/shipit-design-addproduct-mobile` on branch `design/addproduct-mobile`, which is where this
> report was produced. The branch name that *was* wrong is the one recorded in **revision 2's** artifacts
> (`design/correct-addproduct-mobile`); the actual branch for every revision-2, revision-3 and **revision-4**
> correction pass is **`design-correct-addproduct-mobile`** in worktree
> `/private/tmp/shipit-correct-addproduct-mobile`. Do not "correct" this block — it is accurate.

`BASE_SHA == HEAD_SHA` because I am forbidden to commit; my artifacts are untracked in the worktree for the Manager to persist. `HEAD` was re-read after all authoring and is unchanged.

## Executive summary

Four boards authored at 390x844 on page `d8ac01df-6646-81d2-8008-a366c09aa9d3`, each exported and read back in both themes. Design Brief, Design Revision and metadata persisted with every field `DESIGN_GOVERNANCE.md` requires. R1–R7 all satisfied, `requirements_gaps: []`.

**Three premises in my dispatch were false and changed what I drew.** Each is verified, not assumed:

1. **`Show technical details` was not removed.** It renders via the shared `TechnicalDetails` primitive (`design_primitives.dart:415`), which Add Product instantiates twice — `:316` desktop and `:925` mobile. The literal grep misses it because the spelling is centralised. So R3 is **not** a restoration; the duplication is `_buildFooter`'s rule+copy *plus* `TechnicalDetails`' own rule+note.
2. **The footer copy at `:383` is desktop-only.** `_buildFooter` is called solely from `:314`; `_MobileAddProduct` has no footer copy at all. On the screens I govern the copy line is *absent*.
3. **The mobile board has no bottom copy.** `BPM · Add Product · Light` has exactly one element below the helper — `Disclose`. The *desktop* boards put copy and disclosure on one line. I specified per-platform accordingly rather than picking one.

I also corrected the R5 trap in the opposite direction to the dispatch: the board grammar *already* uses `inkSecondary` for the key-meta line, so moving the build toward `inkSecondary` converges on the board rather than diverging from it.

## Files touched

```text
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-brief.md
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision.md
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata.yaml
docs/engineering/dispatch/tasks/design-addproduct-mobile/penpot-board-evidence.md
```

Plus four Penpot boards (not git). Nothing outside `OWNED_PATHS`; `git status --short` shows only the one untracked directory.

## What changed and why

- **Four new boards** `SM - Add Product - {Unknown host, Verified} - {Light, Dark}` at 390x844 — closes the human's point 1 ("we're missing mobile designs for these screens") and follow-up action 4 of `73097d48`.
- **Copy correction (the dispatch's most important item).** All four boards carry `ed25519 · private half stays server-side` in `inkSecondary`, in a layer named `Art S · PENDING D4 (at-rest model)`. Zero occurrences of "this device" or "keychain", audit-verified. That layer is the single string parameterized on the at-rest protection model; everything else is drawn against the settled architecture and complete.
- **One button/helper structure** for both platforms (mobile's sibling-below wins). Desktop button **collapses ≈50.4px → 36px**, landing on its own declared `minimumSize`; new desktop gap is **8px**, the value mobile already uses at `:912`. Both computed from `ShipItType._lh = 1.2` and the real style at `:685-689` — this is the number H2 left unspecified.

> **WITHDRAWN — revision 2 §6a; marker added at revision 3.** The desktop button collapses
> **50.4px → 36.4px, not to 36px**: `minimumSize: Size(0, 36)` is a minimum, `Size.constrain` raises only
> values *below* it, and `14.4 + 22 = 36.4` already exceeds it, so the minimum never binds. The **8px gap is
> still correct.** Corrected derivation: `design-revision-3.md` §3. **Retained unedited for diffability and
> superseded, not deleted.**
- **Footer specified per platform**: mobile = one `Show technical details ▸` row, no copy, `note:` dropped at `:926-928`; desktop = `delete _buildFooter` entirely (`:375-389`, `:314-315`), keeping `TechnicalDetails(note:)`. That deletion also removes the double `ContentRule`.
- **Required-field convention re-grounded** on the existing in-label `(OPTIONAL)` suffix; all **15** `FormFieldSlot(` invocations enumerated and classified; the `DesignTextField` compile trap resolved by adding **no** parameter (the marker already lives in the label string), and its 3 filter sites explicitly declared out of the convention's domain with a reason.
- **No new primitive, no new token.** Every board element maps to an existing `ShipItPalette` token or production primitive.
- **Deviation from plan:** two boards initially had text-collision defects on visual read-back (a wrapped key-meta line; a wrapped trust body). Both fixed before completion — documented in evidence §3 rather than quietly patched.

## Validation results

| Command | Status | Evidence / note |
|---|---|---|
| `git branch --show-current` | pass | prints `design/addproduct-mobile` |
| `git rev-parse --short HEAD` | pass | prints `77c19f1` (re-read after all authoring) |
| `grep -rn "OPTIONAL" apps/control_plane/lib/features/defects/create_defect_page.dart` | **fail — path does not exist** | `features/defects/` is not a directory. Correct path is `features/defect_report/`. Re-run against it: **4 hits at `:458,477,495,504`** — R4's premise **confirmed**. Dispatch's line numbers were right; its directory was wrong. |
| `grep -rn "inkTertiary\|inkSecondary\|inkPrimary" apps/control_plane/lib/shared/design_tokens.dart` | **fail — path does not exist** | Real path is `apps/control_plane/lib/core/design_tokens.dart`. Re-run: ink tokens at **`:99-101` light / `:120-122` dark** (dispatch cited `:96,101,117,122`). Ratios all confirmed by measurement. |
| `grep -rn "Show technical details\|_registerButtonSubtext\|FormFieldSlot" apps/control_plane/lib` | pass | 0 hits for the literal in `products/`, but `TechnicalDetails(` at `:316` and `:925` — which is how premise 1 above was caught. `FormFieldSlot(` = **16 lines = 15 invocations + 1 constructor**, matching B2. |
| Penpot board inventory before | pass | 156 boards / 158 root children; `SM -` filter returned `[]` |
| Penpot board inventory after | pass | **160** boards / 162 root children; delta exactly +4 |
| PNG export + visual read-back, all four boards | pass | two defects found and fixed; see evidence §3 |
| Pre-existing board integrity | pass | 4 reference boards re-read: position, name and child count unchanged |
| Forbidden-copy content audit | pass | 0 hits across all four boards for `this device`/`keychain`/`browser storage`/`Cancel` |
| `flutter analyze` | **NOT_RUN** | Not in this dispatch's `VALIDATION_COMMANDS`. Prior review recorded it returns 8090 `undefined_identifier` at this HEAD because `apps/control_plane/.dart_tool/package_config.json` is absent; fixing that needs `flutter pub get`, which writes outside my `OWNED_PATHS`. **This is why `implementation_feasibility` is MEDIUM, not HIGH.** |
| Any `docker` / `docker compose` command | **NOT_RUN** | None issued, per hard rule. |

## Evidence (revision-pinned)

```yaml
EVIDENCE_REVISION: 77c19f114ee691e8c434afe37b7c84494b66dc40
BUILD_COMMAND: n/a — no build; Penpot authoring is not a compile
SERVE_OR_RUN_COMMAND: n/a — Penpot plugin API via MCP against the live file
ENVIRONMENT / BASE_URL: Penpot file page d8ac01df-6646-81d2-8008-a366c09aa9d3 ("Page 1")
ARTIFACTS:
  - penpot:SM - Add Product - Unknown host - Light  id 6d055762-a70b-804c-8008-bf65ff750422  @ (7550, 10750)  390x844  42 layers  [PNG exported, read back]
  - penpot:SM - Add Product - Unknown host - Dark   id 6d055762-a70b-804c-8008-bf65e644269b  @ (7550, 9800)   390x844  42 layers  [PNG exported, read back]
  - penpot:SM - Add Product - Verified - Light      id 6d055762-a70b-804c-8008-bf660e124738  @ (8000, 10750)  390x844  34 layers  [PNG exported, read back]
  - penpot:SM - Add Product - Verified - Dark       id 6d055762-a70b-804c-8008-bf65f36b1c9a  @ (8000, 9800)   390x844  34 layers  [PNG exported, read back]
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-brief.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata.yaml
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/penpot-board-evidence.md
```

**Viewports captured:** 390x844 (both themes × 2 states). **Design frame refs compared against:** `BPM · Add Product · Light` (390x844, field pitch 64, boxes 34, key panel 116, submit 34, helper +8, disclose y=580) and the desktop state boards `S · Add Product · Unknown host · Light` / `… · Verified · Light` (1280x900) for state copy, state colours and the trust panel. No automated pixel-diff is claimed — this project has no such tooling and I did not build one.

### Categorized mismatch list (my boards vs. the build, at `77c19f1`)

- **MATERIAL** — build renders a nested subtext inside the desktop `FilledButton.child` (`:692-717`) in `inkPrimary` on the fill at **3.07:1 light / 2.72:1 dark**, failing AA in both themes; boards and `theme.dart:70-74` agree on `#ffffff`/`#06121f`.
- **MATERIAL** — build renders "What you're registering" (`:405`) and "What happens next" (`:639`, `:859`); neither exists on any board.
- **MATERIAL** — build's `_buildInfoPanel` (`:480-482`, `:979-981`) claims the private half "stays in this device's keychain"; false by `b869ec24`, and no mobile board has that panel.
- **MATERIAL** — build's key meta (`:542`, `:1038`) says "created on this device · the private half stays in the keychain"; boards corrected.
- **MATERIAL** — desktop paints two `ContentRule`s and two copy lines at the footer (`:380`+`:317-319`); boards specify one.
- **MATERIAL** — `canRegister` requires `AccessStatus.verified` (`:233-236`) which **nothing in the repository ever assigns** (`73097d48` quantitative data); the button is unreachable in every state.
- **TRIVIAL** — board submit 34px vs `MobilePrimaryButton` 36px (pre-existing).
- **TRIVIAL** — Penpot's IBM Plex Sans has no `500` weight, so link layers render at 400 while `ShipItType.link` uses 500.

> **WITHDRAWN — revision 2 §2; marker added at revision 3. This premise is false in both directions.**
> `IBM Plex Sans`'s variants are `100, 200, 300, 400, 500, 600, 700`: **`500normal` exists** — the very
> weight this bullet claimed was missing — **`900` does not exist**, and `100` exists though this bullet
> omitted it. There was no file-fidelity limitation. `Art L1` and `Art L2` are now **11/500** on all four
> boards, matching `ShipItType.link` (`apps/control_plane/lib/core/design_tokens.dart:426`).
> **Retained unedited for diffability and superseded, not deleted. Do not rely on this bullet.**
- **AMBIGUOUS** — no disabled-primary token exists in `ShipIPalette`; I drew the blocked button with the enabled accent treatment because that is what both existing desktop boards do, so no board in the file represents the disabled appearance.
- **AMBIGUOUS** — `TechnicalDetails` always paints a `ContentRule` (`:396`); the mobile board has none.

## Documentation updated

```text
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-brief.md
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision.md
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata.yaml
docs/engineering/dispatch/tasks/design-addproduct-mobile/penpot-board-evidence.md
```

## Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: STANDARD
MODEL_USED: opencode/space-bunny-free
REASONING_EFFORT: n/a
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

## Blockers

None prevent independent review. Four need routing:

- **B2 — Penpot board naming convention (design-system owner, Gate D4).** The page uses `·` (U+00B7) and `S ·` for state boards; the dispatch mandates `SM -` with hyphens. I followed the dispatch exactly (acceptance criterion; a rename is trivial) which leaves two conventions on the page. *Recommendation: rename the four to `S · Add Product · …`.*
- **B3 — is the footer copy meant to be removed on desktop too? (HUMAN, Level 2).** I read human 2f against the mobile boards and mobile build and specified no copy there. The desktop boards *do* carry that copy beside the disclosure, so a desktop-wide removal contradicts them — and editing desktop boards is PROHIBITED to me. One-line change if yes (`note: null` at `:317`). **I did not decide this.**
- **B4 — `negative` fails AA on dark.** 4.02:1 on `canvas`, 3.68:1 on `card` (measured). Used for `Key State` on my Unknown-host boards because the desktop boards do; no compliant alternative token exists, and this pre-exists on those boards too. Needs a palette decision.
- **B5 — the `hostUnrecognised` state machine is the sibling lane's.** My Unknown-host boards are correct against settled human input (2d + addendum 2: no Cancel, `‹ Products` is the way out, key persists server-side) but the `Trust *` layers are provisional.

Also reported to the Manager, not blockers: the two broken paths in `VALIDATION_COMMANDS` (`features/defects/…`, `shared/design_tokens.dart`) and the stale token line numbers — both corrected and re-run above.

## Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - design-addproduct-keyservice — disjoint OWNED_PATHS (it owns docs/engineering/dispatch/tasks/design-addproduct-keyservice/** and the backend/state-machine design; I own the four boards + these artifacts). I invented no backend behaviour, API shape, field name or verification semantics; four assumptions are labelled A1-A4 in design-revision.md §8.
  - the implementation lane's *non-UI* preparation — e.g. the mock-key removal at add_product_page.dart:126-138 and first-ever test coverage (F7), neither of which depends on my copy or layout decisions.
PROHIBITED_PARALLEL_WORK:
  - implement-addproduct (UI portion) — it must not start until Gate D3 passes, because the button structure, footer composition, helper token and field labels are all being changed here and implementing against the old design reproduces the defect.
  - visual-QA golden baseline capture — blocked on all of the above; note F6 (34 vs 36px submit) must be settled first or the baseline bakes in the wrong height.
  - any lane editing BPM · Add Product · Light/Dark or the desktop BP/S Add Product boards — I own only the four new boards; F5 requires a design-system owner to reconcile the sibling boards' stale helper token and keychain copy.
```

**Explicitly, as asked:** my boards would need **redrawing only if the sibling lane's state machine diverges** — and then only the **Unknown-host pair**, only the region between the key panel and the submit button. Specifically: a modal/sheet trust step moves the `Trust *` block out (submit returns to y=510/552/580); a third affordance grows the trust panel past 160px; server-push verification removes `Art L2` and changes the Unknown-host helper. That is ≤6 layers on 2 of 4 boards. The Verified pair, all copy, all tokens, all geometry and the footer are unaffected.

## Cleanup confirmation

- [x] All processes started by this lane are stopped. No server, port or PID was started; Penpot work was in-process via MCP.
- [x] Temporary artifacts removed. `/tmp/contrast.py` (the throwaway WCAG calculator) deleted. **Two scratch boards** created by two failed Penpot API calls (an unnamed 100x100 board, then a partial 3-layer `SM - …` board) were caught by inventory diff and **removed**; the count returned to the original 156 before the successful build and `strayBoards` is now `[]`.
- [x] `git status --short` shows only `?? docs/engineering/dispatch/tasks/design-addproduct-mobile/`.
- [x] No files modified outside `OWNED_PATHS`. No Docker command issued at any point.
- [x] No commit, no push, no self-approval.

## Recommended next action

`INDEPENDENT_DESIGN_REVIEW`

(`RISK_LEVEL: 2` means Gate D4 is `HUMAN_DECISION_REQUIRED` after D3 — blockers B3 and B4 are the escalations.)

---

```yaml
FEATURE: Add Product rebuild — four missing SM mobile boards + layout/copy corrections
BRIEF_ID: 52CB4098-FF87-4B78-81DA-1104269551A1
REVISION_ID: 65995C2B-4905-419F-A6E9-E547E86D8ECE
REVISION_NUMBER: 1
BRANCH: design/addproduct-mobile
BASE_SHA: 77c19f1
HEAD_SHA: 77c19f1

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - penpot:d8ac01df-6646-81d2-8008-a366c09aa9d3 — boards created (4, at 390x844)
READ_ONLY_PATHS:
  - apps/control_plane/lib/features/**; apps/control_plane/lib/shared/**; apps/control_plane/lib/core/**
  - docs/engineering/**; AGENTS.md; .decisions/**
PROHIBITED_PATHS:
  - apps/control_plane/lib/**; apps/server/**; packages/**; docker/**; .github/workflows/**
  - .decisions/**; WORK_STATE.md; LANES.md; the sibling lane's task directory
  - every pre-existing Penpot board (read-only, never edited/renamed/moved/deleted — integrity re-verified)

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-brief.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata.yaml
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/penpot-board-evidence.md
  - penpot:6d055762-a70b-804c-8008-bf65ff750422  SM - Add Product - Unknown host - Light
  - penpot:6d055762-a70b-804c-8008-bf65e644269b  SM - Add Product - Unknown host - Dark
  - penpot:6d055762-a70b-804c-8008-bf660e124738  SM - Add Product - Verified - Light
  - penpot:6d055762-a70b-804c-8008-bf65f36b1c9a  SM - Add Product - Verified - Dark

RISK_LEVEL: 2
RISK_RATIONALE: >
  Feature UX Change. The primary action's structure is redefined on both platforms (nested reason
  removed; desktop button ~50.4px -> 36px; new 8px desktop gap; new helper line). The required-field
  convention reaches four files plus a shared primitive. The a11y fix replaces a token and surfaces an
  AA failure in `negative` on dark that needs a palette decision. Below Level 3 because the
  highest-risk element — removing the SSH-trust Cancel affordance — is settled human input (point 2d +
  addendum 2, recorded in b869ec24); a resolved human decision does not re-open as a new gate, and no
  navigation or IA change is involved. Escalates to 3 only if the human also removes the desktop footer
  copy, contradicting the desktop boards (B3).
> **WITHDRAWN IN PART — revision 2 §6a; marker added at revision 3.** The parenthetical
> "desktop button ~50.4px -> 36px" is **false**: the button collapses to **36.4px**, because
> `minimumSize: Size(0, 36)` is a minimum that never binds. Everything else in this rationale — Level 2,
> the primary action's structure being redefined on both platforms, the 8px desktop gap, the four-file
> reach of R4, the `negative`-on-dark AA failure, and the escalation condition — is unchanged and was
> independently agreed at `INDEPENDENT_RISK_LEVEL: 2` in revision 2's re-review. **Retained unedited for
> diffability and superseded in this one respect only.**

CHANGELOG:
  - revision 1 — initial. The parked register-button round (revision 18A97195) is folded in by decision
    73097d48; its blockers B1, B2, H1, H2, H3 and traceability gaps 5 and 6 are addressed here.

TRACEABILITY:
  REQUIREMENTS_COVERED: [R1, R2, R3, R4, R5, R6, R7]
  REQUIREMENTS_GAPS: []
  NON_REQUIREMENT_GAPS:   # design-system / ownership, not requirement gaps
    - G1 normative hostUnrecognised state machine + 'Check access' semantics — sibling lane
    - G2 at-rest protection wording for layer 'Art S' — open human decision, marked PENDING D4
    - G3 negative on dark fails AA (4.02:1 canvas / 3.68:1 card); no compliant token exists
    - G4 TechnicalDetails' unconditional ContentRule vs a board with none
    - G5 build's 'What you're registering' / 'What happens next' panels have no board
    - G6 _buildInfoPanel repeats the false keychain guarantee; no mobile board has that panel
    - G7 34px board submit vs 36px MobilePrimaryButton
    - G8 flutter analyze not executed -> implementation_feasibility cannot be HIGH

DESIGN_SYSTEM_COMPLIANCE: PARTIAL
UX_ACCESSIBILITY_SCORE: PARTIAL
IMPLEMENTATION_FEASIBILITY: MEDIUM

DISCOVERIES:
  - DESIGN_DISCOVERY / PRODUCT_SPECIFIC / automatic — 'Show technical details' was never removed from
    Add Product; it renders via the shared TechnicalDetails primitive (design_primitives.dart:415),
    instantiated at add_product_page.dart:316 and :925. The literal-string grep that produced the
    "removed, not de-duplicated" finding is a false negative against a centralised label.
  - DESIGN_DISCOVERY / PRODUCT_SPECIFIC / automatic — the footer copy line at :383 is DESKTOP-only
    (_buildFooter is called solely from :314); _MobileAddProduct renders no footer copy. "Footer copy is
    present" is true only of desktop.
  - DESIGN_DISCOVERY / PRODUCT_SPECIFIC / automatic — BPM · Add Product · Light/Dark (mobile) carry NO
    bottom copy line, only 'Show technical details'; the DESKTOP boards carry copy + disclosure on one
    line. The footer spec is therefore per-platform, not global.
  - DESIGN_DISCOVERY / PRODUCT_SPECIFIC / automatic — the `(OPTIONAL)` required-field convention is
    applied through the LABEL STRING, so DesignTextField needs no new parameter; adding a non-defaulted
    one is what breaks model_executions_page.dart:851,857,863 at compile. The compile risk is avoidable
    by choosing the string convention over an API.
  - DESIGN_DISCOVERY / PRODUCT_SPECIFIC / automatic — moving the helper to inkSecondary CONVERGES on the
    board grammar: the existing key-meta line is already inkSecondary (#5a5c5b / #a8a6a0).
  - DESIGN_DISCOVERY / PRODUCT_SPECIFIC / automatic — ShipItPalette.negative fails WCAG AA on dark
    (4.02:1 on canvas, 3.68:1 on card; measured from design_tokens.dart:99-101/:120-122), while passing
    light (5.33:1 / 5.72:1). No compliant alternative token exists.
  - DESIGN_DISCOVERY / PRODUCT_SPECIFIC / automatic — ShipItPalette has NO disabled-primary token, so no
    board in the file (mine or existing) represents the disabled appearance of a primary action; Flutter
    derives it from ColorScheme instead.
  - CONTRADICTION / PRODUCT_SPECIFIC / human-decision escalation — the Penpot page's board-naming
    convention (· separator, `S ·` for state boards) contradicts the dispatched `SM - …` names. Surfaced,
    not reconciled (blocker B2).
  - PROJECT_FACT / PRODUCT_SPECIFIC / automatic — the dispatch's VALIDATION_COMMANDS contain two paths
    that do not exist (`features/defects/create_defect_page.dart`, `shared/design_tokens.dart`); real
    paths are `features/defect_report/…` and `core/design_tokens.dart`, and the ink tokens sit at
    :99-101/:120-122, not :96,101,117,122.
  - WORKFLOW_IMPROVEMENT / REUSABLE / independent-review — a lane's dispatched validation commands and
    "verified current state" premises were themselves wrong in four places this run (two paths, stale
    line numbers, one wholly false behavioural claim about a widget that renders through a primitive).
    Prompt-premise corrections should be re-verified by the child before being relied on, and a
    primitive-rendered UI string is not evidenced by grepping for that literal in the page file.
  - AUTOMATION_OPPORTUNITY / REUSABLE / independent-review — the contrast table in this revision is a
    throwaway script. Shipping it as a repo test that asserts every design-token pair used by a screen
    meets WCAG AA would make R5 self-verifying instead of re-measured per lane.

KNOWLEDGE_PERSISTED:
  - All findings are reported above and written into design-revision.md § 5/§ 7/§ 9 and
    penpot-board-evidence.md, inside my OWNED_PATHS. Nothing was written to docs/engineering/** outside
    my task directory, and nothing was written to .decisions/** (Manager-owned).
  - WORKFLOW_IMPROVEMENT and AUTOMATION_OPPORTUNITY items are product-agnostic and exceed this lane's
    authority; they are reported, not persisted.

BLOCKERS:
  - B2 Penpot board naming convention conflict (`SM - …` vs the page's `S · …`) — design-system owner, Gate D4
  - B3 Whether the footer copy is removed on desktop too (contradicts the desktop boards) — HUMAN, Level 2
  - B4 ShipItPalette.negative fails AA on dark and no compliant token exists — design-system owner
  - B5 hostUnrecognised state machine is the sibling lane's; the Trust * layers on 2 of 4 boards are provisional
  - (non-blocking, reported) two VALIDATION_COMMANDS paths do not exist; both re-run against correct paths

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```

One caveat on `READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES`: the four blockers are Gate D4 / design-system-owner escalations, not incomplete design work — all of R1–R7 are specified and the boards are authored and verified, so a reviewer can review this now. B2 in particular is a rename, not a redraw.
