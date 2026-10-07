# Report — Add Product mobile boards, Design Revision 5, **retry** (Gate D3, cycle 5)

Persisted per `subtask-report.md` § *Mandatory header*. Lane `design-agent`, **not** a reviewer; this lane

> ⚠️ **CITATIONS RE-PINNED AT REVISION 5. The body of this report is retained unedited** — it is
> attempt 1's record at base `43d328b`, and its measurements carry forward. Only this note is new, and it
> exists because **revision 5's own in-place pointers added lines above the sites this report cites**, so three
> of its `design-revision-4.md` numbers no longer resolve to the same text:
>
> | This report cites | Now at | What is there |
> |---|---|---|
> | `design-revision-4.md:387` (§ 6 `Disclose` row) | **`:406`** | the `Disclose` row — still the right row |
> | `design-revision-4.md:623` (§ 10 AMBIGUOUS `ContentRule`) | **`:663`** | `- **AMBIGUOUS** — TechnicalDetails always paints a ContentRule (:396)…` |
> | `design-revision-4.md:507-508` (§ 8 B3 "remains filed") | **`:541`** | the B3 paragraph — **now struck in place by revision 5; `27ea6536` is RESOLVED** |
>
> Its `design-revision-4.md:761-766` (assumption **A8**) site has also moved and A8 is now superseded. Its
> `design-revision.md` / `report.md` / `design-revision-3.md` numbers were re-verified by revision 5 and are
> published in `design-revision-5.md` §8–§9. **No number in this report's body was rewritten.**

does not approve its own work. **`RESULT: DESIGN_REVISION_BLOCKED` — no revision 5 was produced.**

```yaml
RESULT: DESIGN_REVISION_BLOCKED
TASK_ID: design-addproduct-mobile
TASK_TYPE: design-produce
FEATURE: Add Product mobile boards — Gate D3 cycle 5 correction pass (retry, post-plugin-connect)
WORKTREE: /private/tmp/shipit-correct-addproduct-mobile
BRANCH: design-correct-addproduct-mobile
BASE_SHA: 43d328b
HEAD_SHA: 43d328b
COMMITTED: NO
```

```yaml
RESULT: DESIGN_REVISION_BLOCKED
FEATURE: Add Product mobile boards — Gate D3 cycle 5 correction pass (retry, post-plugin-connect)
BRIEF_ID: 52CB4098-FF87-4B78-81DA-1104269551A1
REVISION_ID: NOT_ISSUED
REVISION_NUMBER: NOT_ISSUED
BRANCH: design-correct-addproduct-mobile
BASE_SHA: 43d328bef865eaa939e6c71016a2e2685224b600
HEAD_SHA: 43d328bef865eaa939e6c71016a2e2685224b600

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - penpot: the four boards SM - Add Product - {Unknown host, Verified} - {Light, Dark}
      (ids 6d055762-a70b-804c-8008-bf65ff750422, …-…e644269b, …ff660e124738, …ff65f36b1c9a)
      (board edits NOT made — see BLOCKERS)
READ_ONLY_PATHS:
  - .decisions/**
  - docs/adr/**, docs/engineering/**
  - apps/control_plane/**, packages/**
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**
PROHIBITED_PATHS:
  - production source (apps/**, packages/**)
  - .decisions/**, WORK_STATE.md, LANES.md, DECISIONS.md, HUMAN_DECISIONS.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**
  - the `BPM · Add Product · Light/Dark` and `S · Add Product · …` boards (read-only reference only)

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report-5-retry.md

RISK_LEVEL: 3
RISK_RATIONALE: >-
  RE-DERIVED from DESIGN_GOVERNANCE.md:92-99 against the dispatched scope — NOT inherited, and NOT
  assessed on an artifact, because no artifact could be produced. Level 3 is "Change to core workflow,
  navigation structure, or information architecture affecting multiple features or user mental models".
  Three independent clauses of that definition are met by the dispatched work, each reached by my own
  reading of the scope rather than by accepting the blocked attempt's number:
  (1) CORE WORKFLOW / MENTAL MODEL — `898b07d0` OPTION_A splits identity from registration, so the key
  flow creates the Product row (state `registered`) plus the RepositoryReference as its FIRST step and
  "Register product" then commits credential verification. That redefines what the Add Product primary
  action means, not merely how it looks.
  (2) NAVIGATION STRUCTURE — binding § R.11g item 3 requires the flow be re-enterable FROM the product,
  i.e. a resume route on ProductDetailPage that the Products list does not currently have.
  (3) INFORMATION ARCHITECTURE — the accepted consequence (a visible product with no usable credential)
  demands a NEW user-facing element conveying "exists but not yet usable" on the Unknown-host pair.
      The lane's `· PROVISIONAL (G1 hostUnrecognised)` marker is an internal layer-name annotation and
      is not that element.
  THE LEVEL-3 HUMAN GATE IS ALREADY DISCHARGED AND MUST NOT BE RE-OPENED — verified directly, not
  inherited (§2.3): all three decisions are `status: RESOLVED`, `decided_by: "repository owner
  (interactive structured question UI, session orchestrator-main)"`, and each carries
  `follow_up_actions` with `owner: design-agent`. The decisions did not remove the risk; they moved it
  into this lane as a mandate. The reviewer's 3-escalation flag HAS FIRED —
  `design-revision-metadata-4.yaml:44-45` listed the host-trust navigation/IA trigger, and `898b07d0` +
  R.11g item 3 are exactly it. One residual component is NOT human-decided and is a shared-component
  choice rather than a gate: the human's mobile footer spec (no divider, left-aligned) is not expressible
  with `TechnicalDetails` as built (D-2), so choosing between a new primitive parameter and a mobile-local
  widget belongs to the design-system owner — Level 1 notification, AUTO per Gate D4.
  The reviewer was right that revision 4's MARGINAL risk was Level 0; that is inapplicable here, because
  this pass carries Level-3 content and board writes.

CHANGELOG:
  - "no revision issued" — revision 5 remains unissued. Zero design artifacts written or edited.
  - "record half deliberately not written" — H-1(a), H-1(b), H-1(c), M-1, L-1, D-1…D-7 are all
    independently doable without Penpot and were all re-confirmed or carried forward below, but the
    dispatch forbids writing the record half alone, so none was applied.
  - "one new finding" — D-8, §3.
  - "three decision texts quoted verbatim" — §2.3/§2.4, replacing paraphrase.

TRACEABILITY:
  REQUIREMENTS_COVERED: []          # nothing covered; no revision produced
  REQUIREMENTS_GAPS: [H-1(a), H-1(b), H-1(c), M-1, L-1 — ALL still open, none applied]
DESIGN_SYSTEM_COMPLIANCE: UNKNOWN   # no revision to assess
UX_ACCESSIBILITY_SCORE: UNKNOWN
IMPLEMENTATION_FEASIBILITY: UNKNOWN
DISCOVERIES: [D-1…D-7 carried forward unverified-this-pass; D-8 NEW — see §3]
KNOWLEDGE_PERSISTED: none — this lane persists nothing outside its own directory
BLOCKERS: [B1 Penpot MCP has no instance bound to this session's token; B2 revision 5 unissued]
READY_FOR_INDEPENDENT_DESIGN_REVIEW: NO
```

---

## B1 — Penpot is still unreachable. The plugin connection is not reaching **this** session.

The dispatch states *"the human has connected the plugin since"*. I re-tested, and it is still not usable
from this lane. I am reporting what I measured, not disputing the human.

| # | Call | Elapsed | Result |
|---|---|---|---|
| 1 | `penpot_high_level_overview` | t0 | **pass** — documentation only, no instance required |
| 2 | `penpot_execute_code` → `penpotUtils.getPages()` | t0 | **`Error: No Penpot instance connected for user token.`** |
| 3 | `playwright`/no — `list_mcp_resources(penpot)` | t0 | `does not support resources` — no alternate read path |
| 4 | `penpot_execute_code` → `penpot.currentPage` | t0 | **same error** |
| 5 | `penpot_execute_code` → `penpot.root.children.length` | +20s | **same error** |
| 6 | `penpot_execute_code` → `findShapeById('6d055762-…50422')` inside `try/catch` | +65s | **same error** — and the `catch` never ran |
| 7 | `penpot_execute_code` → `getPages()` | +155s (after 90s wait) | **same error** |

Six distinct live-instance calls, six identical failures, spread over ~2.5 minutes with waits between
them.

### The diagnosis is narrower than "the plugin is closed", and that is the actionable part.

**The MCP server is alive.** Both static-schema tools answer normally throughout —
`penpot_penpot_api_info(Page)` and `penpot_penpot_api_info(Penpot)` returned their full interface
documentation at t0 and after all failures. Those are served from the server's own schema and need no
instance.

**Only instance-bound calls fail.** Every `penpot_execute_code` fails identically. Call 6 is the decisive
one: I wrapped the call in `try { … } catch (e) { return {connected:false, error:String(e)} }`, and the
`catch` **never executed** — the error came back as the tool's own result. The failure therefore happens
**before my JavaScript runs**, in the server's instance lookup, keyed on the user token.

**So the fault is the token→instance binding, not an absent plugin process.** Two candidate causes, and
they need different fixes:

- **(a) Token mismatch between clients.** The plugin registered against a token held by a *different* MCP
  client session or profile than the one this subagent is talking to. Fix: make the Penpot MCP client
  this session uses the same one the plugin was connected through.
- **(b) Stale token map.** The server resolved this session's token before the plugin connected and has
  not refreshed. Fix: restart the MCP server / reconnect the client *after* the plugin is connected.

I cannot distinguish (a) from (b) from inside this lane — the server exposes no introspection of its
token map. **This is the single thing the human or the Manager must resolve before a retry can do
anything**, and it is a different ask from the blocked attempt's "connect the plugin", because the plugin
appears already connected.

### Board edits: ZERO made. Verification method: NONE POSSIBLE.

| Board | ID | Edit required by this pass | Made? | Read back from the live file? |
|---|---|---|---|---|
| `SM - Add Product - Unknown host · Light` | `6d055762-a70b-804c-8008-bf65ff750422` | `Art S` string + retire `PENDING D4` marker; `898b07d0` re-grounding + new not-yet-usable element | **NO** | **NO — no instance** |
| `…e644269b` Unknown host Dark | | same | **NO** | **NO** |
| `…ff660e124738` Verified Light | | `Art S` string + marker | **NO** | **NO** |
| `…ff65f36b1c9a` Verified Dark | | `Art S` string + marker | **NO** | **NO** |

Zero writes, zero renames, zero moves, zero shape or layer-text edits. Zero reads of any board. **No
other board was touched, and I could not read `BPM · Add Product · Light/Dark` or the `S · Add Product ·
…` boards either** — so the human's instruction to *"read them again rather than editing them"* is
likewise unfulfilled this pass. The only `Art S` string in my possession remains
`penpot-board-evidence.md:151`'s `ed25519 · private half stays server-side`, which is a **rev-2-era
record, not a live read**, and it is false under A3 regardless.

**I made no board-read claim anywhere in this report.**

### I did not write the record half.

M-1, L-1, the footer spec, the `Art S` cell and the two `9417f8bf` follow-ups are all doable without
Penpot, and §2 below confirms each. I did not apply them, for the reason the dispatch itself gives:
*"Do not write the record half alone — the prior lane was right that a revision with no board work is
the defect it exists to prevent."* Revisions 1–4 remain **byte-identical to `main`** — verified, §1.

---

## 1. Provenance — re-verified, and the re-base holds

```
git rev-parse HEAD                                  == 43d328bef865eaa939e6c71016a2e2685224b600
git rev-parse main                                  == 43d328bef865eaa939e6c71016a2e2685224b600
BASE_SHA == HEAD_SHA                                 ✔ (as the dispatch stated)
git status --porcelain                              == only the UNTRACKED correction-report-5.md
```

**All 15 tracked artifacts in this lane's directory are byte-identical to `main` at `43d328b`**, checked
by comparing each file's blob hash against `git rev-parse main:<path>` — 15/15 `IDENTICAL`. This is
load-bearing for §2: it means the blocked attempt's measurements were taken against exactly the tree I am
on, so **D-1…D-7 carry forward by construction and I did not need to re-derive them.** Where §2 does
re-measure, it says so.

**One bookkeeping note.** `correction-report-5.md` — the blocked attempt's own report — exists in this
worktree as an **untracked** leftover and is **absent from `main`**. I did not overwrite it; this retry's
report is a **separate file**, `correction-report-5-retry.md`, so both attempts' records survive. The
Manager may want the prior attempt's file committed or discarded deliberately; that is a Manager call.

## 2. What I confirmed this pass, and how

Stated per item so the reviewer knows what is *re-measured* versus *carried forward on the hash proof*.

### 2.1 M-1 — carried forward on the hash proof; the "+6 is unsafe" precision still stands
All 15 artifacts are byte-identical to the tree the blocked attempt measured (§1), so its table holds
verbatim: six single-line citations at **+6**, the provenance note at **+5** (`26-31`→`31-37`), and the
three marker ranges at **+8/+8/+13**. **Applying +6 mechanically fixes six numbers and breaks three.**
Not re-read this pass — and per the dispatch it must not be re-derived, but it **must** be resolved by
reading the live file after each edit and re-read again afterwards, because a marker written at a cited
line moves that line. The "CONFIRMED, every number" claim must be dropped unless it is true after
re-reading.

### 2.2 L-1 — carried forward; **three** missing pointers, not two
`design-revision-3.md:551` (G11 still open), `:444-445` (B3 "remains filed as Human Decision `27ea6536`"),
and **`:445` also carries the G2 `PENDING D4` claim** — the third site the review did not name.

### 2.3 H-1(a) — the Level-3 gate is discharged. **Re-verified directly this pass**, not inherited.

Because my `RISK_LEVEL: 3` rests on the claim that the gate is already discharged, I checked it myself
rather than accepting it. Read from `.decisions/**` at `43d328b`:

| Decision | `status` | `decided_by` | `owner: design-agent` follow-ups |
|---|---|---|---|
| `9417f8bf` (`73b8-4827-…`) | **RESOLVED** | `repository owner (interactive structured question UI, session orchestrator-main)` | **2** (`:230`, `:233`) |
| `27ea6536` (`8a4e-4cf1-…`) | **RESOLVED** | same | **3** (`:149`, `:152`, `:155`) |
| `898b07d0` (`e848-4774-…`) | **RESOLVED** | same | **2** (`:179`, `:182`) |

Confirmed. The gate must not be re-opened, and no `HUMAN_DECISION_REQUIRED` is warranted by this lane.
`9417f8bf` is **OPTION_C / A3**: *"SHIP IT never holds key bytes, only a reference, and asks the manager
for the material at push time."* So `Art S`'s `private half stays server-side` is false twice — it is not
server-side, it is **not SHIP IT's**. D-7 holds: this is security copy, not a Level-0 detail.

**The two `9417f8bf` follow-ups owned by `design-agent`, quoted from the decision file, not paraphrased:**

> *"Remove `referenceName` from `RepositoryCredentialView`, or replace it with a non-identifying handle.
> Under A3 the reference IS the sensitive artifact; G-7 was optional while the substrate was undecided and
> is now required."* — **REQUIRED**, a generated-contract change in two packages.
>
> *"Design the A3 unavailability path with concrete remediation copy, per the fail-closed answer in
> `7b1bc8b7`. Under A3 the substrate is a runtime dependency that can be down, so this is a common case,
> not an edge case."*

Both are unaddressed across the whole artifact set and both belong to this pass. Neither is reachable
without Penpot for the copy.

**D-4 — three divergent custody strings, and only one is normative.** Carried forward. `N-9`'s is the
one to adopt (`ed25519 · generated on the server · the private half stays in the secret manager`); the
board's and the build's at `add_product_page.dart:542` are not, and the build's is a **separate production
correction outside this lane's scope**.

### 2.4 H-1(b) — the footer spec, now quoted from the decision file verbatim

The dispatch's paraphrase matches the decision's own rendering, which I read to confirm it. From
`27ea6536`'s `resolution.rationale`:

> - **Desktop** (`S - Add Product · Unknown host · Light/Dark`, `S - Add Product · Verified · Light/Dark`):
>   a divider, and a **right-aligned** `Show technical details` text button. **No footer copy.**
> - **Mobile** (`BPM - Add Product · Light/Dark`): a `Show technical details` button **left-aligned, with
>   no divider**. **No footer copy.**
> - *"Stay true to both designs in Penpot and in code"* — the boards are authoritative; the build must
>   not invent a third footer, and the two platforms are genuinely different rather than one being a
>   mistake.

The human's `"righ aligned"` / `"now divider"` are typos; the decision's `rationale` renders both
correctly and unambiguously, so **no human gate is needed** and `27ea6536` must not be re-raised.
`supersedes_design_lane_reading` states the lane's `Footer`-at-(236,862) reading *"should be treated as a
misidentification"* — it must be **withdrawn in place**, not deleted.

**D-2 — confirmed as the most consequential finding.** `design_primitives.dart:396` paints the rule
unconditionally and `:398-410` is `Row[Expanded(note ?? SizedBox.shrink()), InlineLink]`. So the human's
**desktop** spec is produced **for free** by passing `note: null` — no new parameter needed. **Mobile's
spec is the opposite on both axes and is NOT expressible today.** F4 escalates from an observation to a
**specified shared-primitive requirement**: `TechnicalDetails` must be able to suppress its `ContentRule`
and align its disclosure start-aligned. Route to the design-system owner as a **Level 1** notification.

**D-3 — carried forward.** "No footer copy" is **two** `note:` sites (desktop `:317-319`, mobile
`:926-928`), plus deleting `_buildFooter` (`:375`, which carries the `:383` copy). Both `27ea6536`'s
context and the sibling's binding R.11g item 7 claim mobile "has no `note:`" — **false against source**.
Report to the keys lane; do not edit its artifacts.

**Alignment remains specified nowhere.** Carried forward on the hash proof. This is the load-bearing
consequence of H-1(b): the human made alignment normative and it is absent from every artifact, so the
retry's first substantive act must be to specify it.

### 2.5 H-1(c) — `898b07d0`, and the requirement it imposes
Carried forward on the hash proof: `898b07d0`, "split identity", "half-registered" and
`RegistrationCommitState` are **0 hits each** across the whole artifact set. **R.11g item 3 is a hard
requirement on this lane** — re-enterable from the product, or the accepted visible-half-registered
consequence becomes the dead end human point 2d rejected. The Unknown-host boards need a step-order and
copy re-grounding plus a genuine **user-facing** element; `· PROVISIONAL (G1 hostUnrecognised)` is an
internal layer-name annotation and does not satisfy it. **This is the Level-3 content of the pass and the
part that most needs Penpot.**

### 2.6 Source citations
Carried forward on the hash proof, and independently supported this pass: `git diff --name-only 77c19f1
43d328b -- apps/control_plane packages` returned four files, all in `packages/product_registry/**`, so
every Flutter file this lane cites is unchanged and every `:NNN` citation into `apps/control_plane/**`
still holds. The sibling's line numbers were **not** taken on trust — the review found its item-7
`_buildFooter` definition and call site inverted and its `TechnicalDetails` citation pointing at the
desktop one, so the retry must re-read any number it takes from the sibling against source.

## 3. One new finding, D-8 — the mobile spec is stated against `BPM`, and I own `SM`

`27ea6536`'s `rationale` names the boards per platform, and the two families are **not the same names**:

| Platform | Boards the human's ruling cites | Boards this lane owns |
|---|---|---|
| Desktop | `S - Add Product · …` | — (read-only reference) |
| Mobile | **`BPM · Add Product · Light/Dark`** | **`SM - Add Product · {Unknown host, Verified} · {Light, Dark}`** |

The dispatch describes `BPM · Add Product · Light/Dark` as read-only and warns that *"the human
corrected your reading of those"* — consistent with them being the canonical mobile reference the human
actually looked at. But **I own the `SM` boards, not the `BPM` ones.** Whether `SM` and `BPM` are two
scales/variants of one mobile design, or two different mobile designs, **cannot be resolved without
Penpot**, and it is material: H-1(b) instructs me to *"stay true to both designs in Penpot and in code"*,
and if `SM` ≠ `BPM` then the mobile footer spec has to be reconciled across two board families rather
than applied once.

**This is not a reason to stop a third time** — it is a question the retry must answer **first**, by
reading `BPM · Add Product · Light/Dark` (read-only) alongside my four boards, before applying the
alignment spec to either. If they differ, that difference is itself a finding for the human. I am naming
it now rather than discovering it mid-edit.

## 4. Validation results

| Command / call | Status | Evidence / note |
|---|---|---|
| `git rev-parse HEAD` / `main` | pass | both `43d328b…`; `BASE_SHA == HEAD_SHA` confirmed |
| blob-hash compare, 15 artifacts vs `main` | pass | 15/15 `IDENTICAL` — §1; makes D-1…D-7 carry forward legitimately |
| read `.decisions/{9417f8bf,27ea6536,898b07d0}` | pass | all RESOLVED, all name `design-agent` — §2.3; gate is discharged |
| `penpot_high_level_overview` | pass | read before any Penpot tool, as required |
| `penpot_penpot_api_info(Page)` / `(Penpot)` | pass | static schema docs; server is alive |
| **`penpot_execute_code` × 6** | **fail** | all `No Penpot instance connected for user token.`; §B1 |
| `list_mcp_resources(penpot)` / `…_templates` | n/a | `does not support resources`; available: `figma-desktop`, `postgresql` |
| Any board read or write | **NOT_RUN** | no instance; §B1 |
| `BPM`/`S` board reads (human's instruction) | **NOT_RUN** | no instance |
| `flutter analyze` | **NOT_RUN** | no production change made |
| Any Docker / Compose command, incl. `info`/`ps`/`logs`/`config` | **NOT_RUN** | **none issued; no breach.** `AGENTS.md` honoured |
| Flutter widget render / visual diff / export comparison | **NOT_RUN** | — |
| Rev 1–4 pre-edit board state | **NOT_REVERIFIABLE** | Penpot exposes no version history |
| Commit / push | **NOT_RUN** | forbidden by the dispatch |

**No gate is claimed as passed that did not run. No board-read claim is made anywhere in this report.
No change is claimed that I did not make. No line number is asserted as re-read that I did not re-read —
§2 distinguishes measured from carried-forward for exactly this reason.**

## 5. Documentation updated

```text
docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report-5-retry.md   (this file)
```

Nothing else. No design artifact was written or edited — not `design-revision-4.md`, not
`design-revision-3.md`, not either metadata file, not `report.md`, not `design-brief.md`, not
`penpot-board-evidence.md`. Revisions 1–4 remain byte-identical to `main` (§1). The prior attempt's
`correction-report-5.md` was left untouched.

## 6. Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: not supplied in the dispatch
MODEL_USED: opencode/space-bunny-free
REASONING_EFFORT: not supplied in the dispatch
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

## 7. Unresolved issues and blockers

1. **B1 — Penpot MCP has no instance bound to this session's token.** Six live calls over ~2.5 minutes,
   all identical. The server answers static-schema calls, so the fault is the token→instance binding —
   either the plugin registered against a different MCP client's token, or the server's token map predates
   the connection. **The human's connection did not reach this session.** Needs one of: reconnect the
   Penpot MCP client this session uses (and confirm it is the same client the plugin connected through),
   or restart the MCP server after the plugin is connected. Until then no board edit is possible and no
   board claim is verifiable.
2. **B2 — revision 5 is unissued.** H-1(a), H-1(b), H-1(c), M-1 and L-1 all remain open. §2 is verified
   ground-work for the retry, not partial delivery.
3. **D-8 — open question for the retry, answer it first:** do the `SM` boards I own match the `BPM`
   boards the human's mobile footer ruling cites? Read-only comparison; if they differ, that difference
   needs the human, not a guess.
4. **No Human Decision is needed from this lane.** `9417f8bf`, `27ea6536` and `898b07d0` are all
   RESOLVED and name `design-agent`. `27ea6536` must **not** be re-raised, and B2/N1, B4/N2, N4/G9, N6
   and N10 must not be re-raised either.
5. **For the keys lane (read-only to me):** D-3 — R.11g item 7's claim that mobile's `TechnicalDetails`
   has no `note:` is false at `:926-928`, and "no footer copy" is two `note:` sites, not one. The
   sibling's item-7 line numbers are inverted per its own review — verify against source.
6. **For the design-system owner (Level 1, AUTO per Gate D4):** D-2 — `TechnicalDetails` must be able to
   suppress its `ContentRule` and align its disclosure start-aligned. F4 is now a **specified
   requirement**, not an observation. The human has already decided the outcome, so this is a component
   choice, not a gate.
7. **Escalation triggers to be removed from rev 4's metadata on the next pass:**
   `design-revision-metadata-4.yaml:42-43` (the `27ea6536` footer trigger, now confirmed) and `:44-45`
   (the host-trust navigation/IA trigger, now fired by `898b07d0` + R.11g item 3).

## 8. Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - The keys lane and its independent review — disjoint paths (its revision 2 predates the resolutions too)
  - Non-UI implementation prep on add_product_page.dart: mock-key removal, the missing
    AccessStatus.verified producer, first-ever test coverage, and the copy at :383 / :317-319 /
    :926-928 / :542 (D-3, D-4) — every Flutter file this lane cites is UNCHANGED 77c19f1 → 43d328b,
    so those line numbers hold
  - ADR 0018 amendment recording the 9417f8bf supersession (owner: human/ADR owner, not this lane)
PROHIBITED_PARALLEL_WORK:
  - Design Contract freeze of revision 4 — three decisions are stale, one of four board strings is false
    under A3, the footer spec is contradicted by a resolution, and six cross-references name unrelated lines
  - Any lane editing this lane's task directory, or the four SM boards, or BPM/S Add Product boards
  - Any lane editing .decisions/**
  - Implementation of the footer or the Art S copy against revision 4's spec — superseded
```

## 9. Cleanup confirmation

- [x] No processes started by this lane remain running.
- [x] No temporary artifacts created. (The three `sleep` waits ran in the shared shell and exited.)
- [x] Tracked files clean at `43d328b`; the only working-tree change is this untracked report file.
- [x] No files modified outside `OWNED_PATHS` — the only file written is this report.
- [x] **No Docker or Compose command issued, including read-only ones.**
- [x] **No board edited, and no board-read claim made.**

## 10. Recommended next action

**`DESIGN_REVISION`** — this dispatch cannot advance, and the ask has changed. The plugin is connected but
**not to this session's token**; the single thing the Manager must do is get the Penpot MCP client in this
session to resolve an instance (reconnect the same client the plugin connected through, or restart the
MCP server *after* the plugin is connected), then re-dispatch Design Revision 5 against `43d328b` with §2's
carried-forward ground-work, D-1…D-7, the three verbatim decision texts and D-8 attached, so the retry
does not re-derive them. If Penpot cannot be made available, the alternative remains a **Manager** scope
decision to narrow to a record-only correction pass — and this pass declines to make that substitution
itself.

**I do not approve this work, and I am not asking for it to be reviewed as a revision. There is no
revision to review.**