# DESIGN HANDOFF — `CONTROL_PLANE_OPERATOR_UI_001`

**Written:** 2026-09-15 · **For:** the next agent picking up this feature
**Repo:** `shipit-platform` · **Penpot file & page:** `d8ac01df-6646-81d2-8008-a366c09aa9d3`

Everything below is measured against the live Penpot file and the repo, not
recalled. Where something is *unverified*, it says so.

---

## 1. READ THESE, IN THIS ORDER

1. `AGENTS.md` — especially §13 (Penpot/credentials) and §8 (no fabrication)
2. `docs/design/brand-tokens.md` — authoritative brand values, do not re-derive
3. `docs/checkpoints/001-control-plane-operator-ui-design-change-request.md` — DCR-001, **RESOLVED = `SELECT_B`**
4. `docs/checkpoints/001-control-plane-operator-ui-visual-direction-study.md` — the B/C/D study, §9.5–§9.7 for corrections
5. `docs/checkpoints/004-plain-language-usability-design-change-request.md` — **DCR-002, OPEN** — the plain-language + mobile work. §11–§14 is the current state
6. `docs/checkpoints/003-design-governance-automation-planning.md` — §7.2 if anything raises model-diversity

---

## 2. WHAT IS AUTHORITATIVE RIGHT NOW

> **`BP · …` desktop + `BPM · …` mobile is the implementation-authoritative design.
> `B · …` is SUPERSEDED (preserved as historical evidence).**

`DCR-001` closed with a human recording `SELECT_B`. `DCR-002` resolved with the
human recording **`ADOPT_PLAIN`** (DCR2-AC-7, 2026-09-15). The pixel-level visual
review (20/20 boards) returned `VISUAL_APPROVED_WITH_MINOR_FINDINGS`. The design
gate is **PASS**.

| Lineage | Boards | Status |
|---|--:|---|
| Original 2026-09-14 | 10 | Preserved. Historical evidence of what was running |
| `B · …` | 6 | **SUPERSEDED** — preserved for historical reference, old goldens, DCR-001 |
| `BP · …` (desktop, plain language) | 10 | **Implementation-authoritative**. 5 surfaces × dark/light |
| `BPM · …` (mobile) | 10 | **Implementation-authoritative**. 5 surfaces × dark/light, 390×844 |
| `C · …`, `D · …` | 0 | Deleted — directions not selected |

**36 boards total. 0 BLOCKING/MAJOR findings. 1 MINOR (fixture/data coherence).**
18 `contrast-brand` advisories remain and are **deliberate** — the brand palette
misses AA for small text and that is a brand-owner decision
(`brand-tokens.md` §6), not a defect to fix.

---

## 3. DO NOT DO THESE

1. **Do not delete `B · …`.** It is SUPERSEDED, not deleted. Preserve as
   historical evidence, old goldens, DCR-001 baseline. `DCR-001` §8.
2. **Do not delete the original 10 boards.** They are the visual record of what
   was running, and the baseline for the previous golden tests.
3. **Do not self-approve golden re-baselining.** Generate candidate goldens after
   implementation, then present for human approval.
4. **Do not re-author the design QA suite in Penpot session `storage`.** It lives
   on disk. It has been lost twice by doing that.
5. **Do not conflate design authority with implementation state.** The Flutter
   app still implements the old B design until implementation correction
   completes.

---

## 4. THE DESIGN QA SUITE — AND A TRAP IN IT

`docs/design/qa/design-qa.js` + `design-qa.test.js`. **50 passing assertions.**

```
node docs/design/qa/design-qa.test.js     # prove the suite works FIRST
```
Then paste `design-qa.js` into `penpot_execute_code` and call
`storage.dq.runAll(undefined, { segmentResolver })`.

**The trap:** `STUDY_BOARD_RE` was `/^[BCD] · /`, which matched **none** of the
adopted `BP ·` or `BPM ·` boards — so `runAll()` scanned zero boards and reported
zero findings. It is now `/^(BPM|BP|[BCD]) · /`. **If you add a new board prefix,
update that regex or the suite will silently pass over an empty set.**

Checks, and the specific defect each was written for:

| Check | Written because |
|---|---|
| `containment`, `legibility`, `contrast` | original mechanical pass |
| `text-overlap` | C's footer rendered as illegible mush; old QA said "0 issues" |
| `text-overflow` | a copy edit made a question wrap and collide; overlap missed it (1px vs a 15% threshold) |
| `semantic-*`, `durable-state-field` | a gate bound to a work item that could not coexist with it |
| `lifecycle-*`, `caption-highlight` | label, lane segment and printed state asserting three different positions |
| `card-spill` | a button sat 2px outside its own card; `containment` passed it because it validates against the **board** |
| `chrome-drift`, `chrome-typography-drift`, `optical-centring` | the mobile bottom nav differed across boards — every board was internally valid, the defect existed only *between* boards |

**Visual inspection is still mandatory.** Multiple real defects this session were
invisible to every mechanical check and were caught only by exporting a board and
looking at it, or by a human looking at it.

---

## 5. WHAT DCR-002 PROPOSES, IN ONE PARAGRAPH

B is functionally sound but 54% of its interface strings were not plain English
(83 of 153 — jargon, opaque ids, snake_case enum values, and three footers that
were literal source code). `BP` is B's design system with plain language on the
surface and exact durable values one deliberate action away behind
**"Show technical details"** — a layer, never a replacement, because a screen
that hides its durable values stops being verifiable. `BPM` is the same at
390×844 with a bottom nav. Measured: **0 jargon violations** in the default view
of the desktop set.

Two rules adopted that the next agent should not undo:
- **Blue means you can click it; status colour means state.** B's review flagged
  brand blue as overloaded across state/link/CTA; for a non-technical user that
  means they cannot tell what is interactive.
- **The UI states facts and consequences; it does not argue for its own
  trustworthiness.** Eight self-justifying strings were removed (e.g. *"An AI
  cannot change where your decision sends this work"*). One reassurance was kept
  — `This cannot be undone.` under the commit button.

---

## 6. OPEN DECISIONS — THESE NEED A HUMAN, NOT AN AGENT

| ID | Decision | Why it matters |
|---|---|---|
| **`DCR2-AC-6`** | Independent review of BP/BPM by a separate execution | Blocks the gate. Designer self-approval is not acceptable. It will record `reviewerModelDiversity: not_available` — this is **compliant and needs no waiver** (003 §7.2) |
| **`DCR2-AC-7`** | Human selects at the gate: `ADOPT_PLAIN` / `ADOPT_PLAIN_WITH_CHANGES` / `KEEP_B_AS_IS` / `REQUEST_NEW_ROUND` | Until then B stands |
| **`PL-4`** | Is "QA reviewer" a distinct role with distinct *permissions*? | If yes, this stops being a copy change and acquires a permissions dimension needing its own scope |
| **`PL-5`** | Is the expiry behaviour intended? | **Probable bug — see §7** |
| **`PL-6`** | Make `WorkItem.description` mandatory and plain for anything reaching a human gate | **RESOLVED** — enforced at `DurableWorkflowEngine.createWorkItem` (required description ≥ 12 chars, distinct from title after trim). See §15. |
| — | `play_circle` → a list glyph for the renamed "All work" tab | Small implementation change |
| — | Raise the mobile commit button from 34px to the 44px touch-target guideline | Costs the vertical budget that currently lets the decision fit one screen |

These are the DCR-002 gate-blockers. Four **post-gate** surfaces — report bugs,
queue work, ask/direct the agent, launch or onboard a project — are NOT
gate-blockers and are captured in §12.

---

## 7. TWO FINDINGS IN THE CODE, NOT THE DESIGN

Both were found by reading `packages/` rather than assuming, and both need a
decision before BP can be implemented faithfully.

### 7.1 Decision expiry silently strands work (`PL-5`)

- `HumanDecision.expiration` is `DateTime?` — **nullable**, so most decisions have
  no deadline and the old UI was inventing one.
- It is referenced in exactly one place in logic:
  `packages/workflow_engine/lib/src/validation/guard_conditions.dart:401`, in the
  `blocking_human_decision_resolved` guard.
- That guard marks a decision `expired` when
  `!decision.timestamp!.isBefore(decision.expiration!)` and then **refuses the
  transition**.

So nothing auto-approves, escalates or notifies at the deadline — but **a decision
made after it is rejected and the work item stays blocked, with no UI signal.**
The countdown was removed from the design and replaced with how long the decision
has waited. Whether the underlying behaviour is intended is a workflow-semantics
question, not a design one.

### 7.2 Plain titles need `description` to be guaranteed (`PL-6`)

`WorkItem` already has **`description`** alongside `title` — no new field is
needed. BP leads with a plain description and demotes the technical `title` to the
disclosure layer. But `description` is nullable and unconstrained today, so
nothing prevents a technical string being written there. **Without a validation
rule plus authoring guidance, BP's plain titles have nothing reliable to read
from.**

Also confirmed available and now surfaced in the design, with no contract change:
`WorkItem.artifactRefs` is `List<ArtifactReference>?` and `ArtifactType` already
includes `design_revision` and `qa_evidence`, so the design under review can be
linked and previewed. Production must bind the preview to `ArtifactReference.uri`.

---

## 8. RESPONSIVE CONSTRAINTS — ALREADY IMPLEMENTED AND TEST-ENFORCED

Read from code, and authoritative per `DCR-001` §5. The mobile boards honour all
of it:

| Fact | Source |
|---|---|
| Breakpoint `maxWidth < 840` | `apps/control_plane/lib/shared/app_shell.dart:14` |
| Mobile = `Scaffold` + bottom `NavigationBar` | `app_shell.dart:39` |
| Exactly **3** destinations for **5** surfaces | `app_shell.dart` |
| Rail and bottom bar never both visible | `test/responsive/` |

Consequence: `Run Detail` and `Decision Detail` are **pushed routes, not tabs**,
so on mobile they carry a back affordance instead of the wordmark.

---

## 9. STATE OF THE IMPLEMENTATION — BASELINE RECORDED 2026-09-15

**No Dart or Flutter code was touched in the design work.** Baseline recorded
before implementation correction begins:

| Metric | Result |
|---|---|
| Git SHA | `6584e7d8346fbfe26fc9517886c408abc6bbcdb6` |
| Flutter tests | **42 pass / 0 fail** (a11y expectation mismatches corrected) |
| Format | clean |
| Analyze | 0 errors / 9 info |
| Server tests | 59/59 (prior session, `dart test -j 1`) |
| E2E | 7/7 (prior session, `operator_ui_e2e_test.dart`) |
| Golden images | Regenerated for BP/BPM (10 candidate goldens) |

Adopting BP invalidates the 8 golden *images* (not their coverage).
Re-baselining requires human approval and must not be self-approved.

---

## 10. SUGGESTED NEXT ACTIONS, IN ORDER

1. **Verify the implementation claims in §9.** Cheap, and everything downstream
   assumes them.
2. **Answer `PL-5` and `PL-6`.** Both are contract/semantics questions that block
   a faithful BP implementation, and `PL-5` may be a genuine bug.
3. **Dispatch the independent review for `DCR2-AC-6`** — separate execution, fresh
   context, judging the rendered exports. It cannot be the execution that built
   the boards.
4. **Put the `DCR2-AC-7` gate to the human** with the review attached.
5. **Only then** implement, re-baseline goldens with approval, and delete `B · …`
   followed by the original 10 once BP is live.
6. **Post-gate:** the human-input surfaces in §12 become buildable — bug
   reporting (002, unparks on the visual-language outcome), the `HumanDirection`
   contract + Inbox, typed work intake, and the product registry + onboarding.
   Each needs its own scope (002 already exists; the rest need an ADR and a new
   planning checkpoint — candidate `005`).

---

## 11. HOW TO BE USEFUL HERE

The repeated failure mode in this feature's history has been **asserting things
that were not true**: a study that claimed 18 boards when 16 existed, that
reported mechanical fixes as applied when they were never written, and a QA suite
that reported clean runs while scanning zero boards. Every number in this document
was measured immediately before writing it.

When you continue: measure before claiming, trace each finding to a specific
shape or line of code before recording it, export and look at the boards, and
leave the human the decisions that are theirs.

---

## 12. POST-GATE PLATFORM SURFACES — WHAT ADOPTING PLAIN LANGUAGE UNLOCKS

Folded in 2026-09-15 from a four-question architectural review (queue work / ask
questions / report bugs; categorize + store human input; avoid the
"done-then-stuck-at-QA/prod" failure; launch or onboard a project). Nothing here
is gate-blocking (§6); all of it is what the gate outcome makes buildable. Every
claim below was read from the repo immediately before writing.

### 12.1 What a human can do today — the whole interaction model

| Interaction | Exists today? | Path |
|---|---|---|
| See work, runs, jobs, executions, evidence | Yes (read-only) | `home` / `workflow` / `scheduler` / `execution` / `worker` endpoints |
| Resolve a gate behind a blocking decision | Yes — the **only** write | `workflow_endpoints.dart: resolveDecision` |
| Queue a new work item | **No** — `WorkItem` creation sites are tests/builders only; no endpoint | — |
| Ask the orchestrator / an agent something | **No** — no direction/query contract; AGENTS.md forbids storing conversation as state | — |
| Report a bug | **No (spec'd, parked)** — `002-human-bug-reporting-ai-defect-triage-planning.md` (`HUMAN_BUG_REPORTING_001`) | — |
| Launch / onboard a project | **No** — `ProductManifest` and the existing-repo worktree manager exist; no registry, no endpoints, no UI | — |

Only `HumanDecision` is persisted as structured human input today: **17 decision
types**, two-phase, durable, `blocking` + `expiration`.

### 12.2 Item by item

| # | Surface | Status | Gap / decision needed | Home |
|---|---|---|---|---|
| 1 | **Report bugs** | Spec complete, parked | Implement 002. Park reason was visual-language selection (**R4**); DCR-001 picked `B`, DCR-002 may supersede → **build the bug-report UI against whichever direction the gate adopts.** Note **R2** (GCS artifacts) and **R3**: a `designDefect` remediation BLOCKS until the design-governance lifecycle (003) exists | 002 |
| 2 | **Queue new work** | No mechanism | New write endpoint creating a `WorkItem` at `draft`. Guard `planning_evidence_provided` (`guard_conditions.dart`) requires `featureRef`/`requirementRef`, so intake needs a project/feature registry (see #4). The **scheduler must endorse**; the **workflow policy must govern** — never the endpoint | new checkpoint (candidate `005`) |
| 3 | **Ask / direct the agent** | No mechanism | New durable `HumanDirection` contract: categorized (`HumanDirectionType`), target-scoped (product / work item / run / execution / job / none), status (`created → acked/working → completed | rejected | superseded`), Postgres-persisted, read-only endpoints, UI **Inbox**. Folded into the **next** bounded job — never injected mid-execution. Requires an ADR (new contract) | new checkpoint (candidate `005`) |
| 4 | **Launch / onboard a project** | No mechanism | Persist `ProductManifest` (id/name, capabilities, `EnvironmentConfig`s, design/QA/deploy contract specs) → **product registry**; bootstrap endpoints; an onboarding worker job (clone at pinned revision, baseline build + test, write `WorkspaceDescriptor`); UI wizard. The worker layer is already repo-aware (`git_worktree_workspace_manager.dart` pins to the request's explicit starting revision) | new checkpoint (candidate `005`) |

Categorization vocabulary to build on already exists: `WorkItemCategory` (7),
`HumanDecisionType` (17), `AgentRole` (11), `DefectClassification` (4) +
`DefectIntakeCategory` (7, in 002). The missing axes are **intent** (gate vs
directive) and **target** (product / work item / run / execution / job).

### 12.3 Why the "done-then-stuck" failure of the older AEF flow is already answered here

Progress is machine-decided, not LLM-decided: states + guards + `runnable_work`
(entry-state routing) decide "next"; the coordinator stamps roles; a job carries
one bounded instruction. QA readiness is a contract (`qa_contract_exists` guard;
agents produce evidence, workers validate — AGENTS §12); prod readiness requires
`artifact_built` + the `deployment_approval` gate + the `deployment_protocol`
promotion path. An agent cannot promote itself.

The residual risks are exactly items 2–3: **no goal/planning layer** (`JobType`
is still only `implement_feature`) and **no human-visible inbox** for guard
failures. The `waitingForHumanDecision` path is the escape hatch; PL-5/PL-6 keep
it from wedging (§7).

### 12.4 Suggested ordering after the gate

1. Implement 002 (bug reporting) against the adopted direction.
2. `HumanDirection` contract + Inbox (ADR).
3. Typed work intake (scheduler-endorsed, policy-governed).
4. Product registry + onboarding (persist `ProductManifest`).

Items 2–4 cross contracts / persistence / endpoints / UI → **one new planning
checkpoint + ADR**, not silent extension.

---

## 13. INDEPENDENT REVIEW RECORD — DCR2-AC-6 (issued 2026-09-15)

Issued by a separate execution (penpot read-only; reviewer execution identity
recorded; `reviewerModelDiversity: not_available` — COMPLIANT per 003 §7.2).
Evidence trail (baseline runs, live QA tallies, per-board geometry and copy
records for all 20 BP/BPM boards) is in the issuing session; conclusions below.

**Verdict: `APPROVED_WITH_FINDINGS`** — no mechanical defect remains on the
BP/BPM boards as *designs*.

| Severity | Finding | Disposition |
|---|---|---|
| BLOCKING | none | — |
| MAJOR | **MODEL-COVERAGE GAP** — the 4 "All work" boards list 8 rows (WI-1aa5, WI-6cf0, WI-b74d, WI-2ef9); the truth MODEL declares 4 → 16 `semantic-unknown-id` majors | Fix the MODEL (add the 4 WIs) or trim the rows — **data/model, not a board redesign** |
| MINOR | `StatusChip` semantics duplicate state text (`'Status: RUNNING\nRUNNING'`, `shared/status_chip.dart:22`) | Implementation, not board |
| MINOR | Test mechanics: missing `await` on `setSurfaceSize` broke responsive + goldens; stale expectations in `accessibility_test.dart` | Test authoring; goldens were never exercised |
| ADVISORY | `→ design_approved · the build can start` visible next to the Approve option on BPM Decision Detail (both themes) | **Retracted as a defect** — documented deliberate disclosure (004 §14.4 per §12.2: "Each option still prints where it sends the work"). Desktop discloses the same routing in the "What happens after you decide" table. Presentational difference, not a leak |
| ADVISORY | 18 `contrast-brand` advisories | Brand-owner decision (`brand-tokens.md` §6), not a defect |

**Verdict revision note:** an earlier review pass read `→ design_approved` as a
default-view technical leak and returned `CHANGES_REQUIRED`. Reading 004 §14.4
shows it is a documented deliberate decision; the only previously-required
correction dissolves and the verdict above replaces the earlier one. The human
still holds `DCR2-AC-7`.

**Limitation recorded:** the reviewing model has no image input, so STEP 3
"visual inspection" was executed as a full programmatic pass (geometry,
overflow, typography, copy). The 20 board exports must get a pixel-level look by
a human or an image-capable reviewer as part of the gate package — the handoff's
§4 warning ("visual inspection is still mandatory") stands.

---

## 14. HUMAN DECISION RECORD — DCR2-AC-7 (issued 2026-09-15)

**Decision: `ADOPT_PLAIN`**

The exact BP/BPM design revision represented by the 20-board export manifest is
now **implementation-authoritative** for `CONTROL_PLANE_OPERATOR_UI_001`.

### Authority binding

| Field | Value |
|---|---|
| Penpot file | `d8ac01df-6646-81d2-8008-a366c09aa9d3` |
| Page | `d8ac01df-6646-81d2-8008-a366c09aa9d3` |
| Board IDs | 20 BP/BPM (see export manifest in §13 pixel review) |
| Export artifacts | 20 PNGs bound to exact board IDs |
| Independent review | DCR2-AC-6 `APPROVED_WITH_FINDINGS` (MAJOR resolved) |
| Pixel visual review | 20/20 `VISUAL_APPROVED_WITH_MINOR_FINDINGS` |
| Human approval | `ADOPT_PLAIN` (this record) |

### Design gate result

| Gate | Result |
|---|---|
| DCR2-AC-7 | `ADOPT_PLAIN` |
| DCR-002 | `RESOLVED` |
| DESIGN_GATE | `PASS` |
| PIXEL_VISUAL_REVIEW | `VISUAL_APPROVED_WITH_MINOR_FINDINGS` |
| STRUCTURAL_DESIGN_REVIEW | `APPROVED_WITH_FINDINGS` |
| MECHANICAL_DESIGN_QA | `PASS` for executed checks |
| LIFECYCLE_SEGMENT_CHECK | `NOT_ASSESSED` (no segment resolver; not a defect) |
| KNOWN_BRAND_CONTRAST_RISK | 18 advisories (brand-tokens.md §6) |

### Previous authority

`B · …` is marked **SUPERSEDED** but **NOT DELETED**. Preserved:
- B boards (6)
- Original 10 boards
- Previous design approval (DCR-001 `SELECT_B`)
- Previous implementation screenshots
- Old golden evidence
- DCR-001 history
- DCR-002 history

Design authority and deployed implementation state must not be conflated. The
Flutter app still implements the old B design until implementation correction
completes.

### Minor fixture finding preserved

| Finding | Classification |
|---|---|
| All Work metric "Working on it 2" vs 3 visible rows | `FIXTURE_DATA_COHERENCE` |

Non-blocking. Align fixture/aggregation semantics during test correction. Does
NOT reopen DCR-002.

---

## 15. IMPLEMENTATION CORRECTION RECORD — 2026-09-15 (AFTER `ADOPT_PLAIN`)

Surface conformance to BP/BPM applied to the Flutter app. Recorded the same day
as the gate; re-verify every claim before building on it.

### Applied

| Surface | Conformance |
|---|---|
| Nav (shell + rail) | `Overview` (grid icon), `All work` (list glyph), `Needs you` (`priority_high`); `play_circle` retired |
| Home | H1 `Overview` (was `Dashboard`) |
| All work | H1 `All work` with item count; lanes `All work / Working on it / Needs you / Finished / Failed`; desktop table `REF / WHAT IT IS / STATUS / RUNNING FOR`; mobile a single `Showing: All work ▾` control (`LayoutBuilder` < 560px); rows `ref {id}` muted mono → plain name → `StatusChip(state.toUpperCase())` → elapsed (`{d}d`, `{h}h {m}m`, `{m}m`) |
| Needs you | H1 `Needs you` (was `Needs Your Decision`); header overflow fixed (`Expanded` + ellipsis) |
| Run Detail | H1 = plain `description` when present, technical `title` demoted to `description · ref {id}`; `Review and decide` CTA (accent `FilledButton`) when `waiting_for_human_decision` && `blockingHumanDecisionId != null`, routing to `/needs-you/{blockingHumanDecisionId}`; timeline heading "What's happened so far" (was `Event Log`); plain event messages for known transitions, unknown (`pending -> running`) pairs fall back to the durable raw pair |
| Decision contract | Wire values = lowercase `HumanDecisionChoice`; chips show `label`, submit `value`; `decisionChoiceLabel(wire, fallback)` for unknown values; verify bar "Decisions: one-way" semantics preserved |
| Parser | `WorkItemResponse` now parses `description` (nullable) — no server/contract change |

### New test-only dependency seam

All five pages accept an optional `bloc:` parameter ("Test-only dependency
seam"); when provided they wrap their private view in `BlocProvider<…>.value`,
else they construct from `ClientProvider.repository`. Real production widget
hierarchy is unchanged; goldens + accessibility tests now render real pages with
seeded states instead of stubs. This is the replacement package-boundary
consequence of DCR2-AC-8 in 004 — no business logic moved into widgets.

### Practical copy rule honored

`WidgetStatus`: `running` = non-terminal AND not waiting; `success`; `failed`;
`waiting`; unknown states fall through to the generic "with the team" label so
state changes don't silently go unlabeled. Plain copy elsewhere is a layer over
durable values, never a replacement — the `Show technical details` layer of BP
remains a separate surface.

### StatusChip semantics advisory (DCR2-AC-6 MINOR) — RESOLVED in this pass

The MINOR (`'Status: RUNNING\nRUNNING'`) is fixed: `ExcludeSemantics` splits
decoration from the technical label and `semanticsOnly` re-applies exact single
`Status: LABEL` semantics. Covered by `test/accessibility/accessibility_test.dart`
(`statusChipSemantics`), which continues to pass.

### Metrics (post-correction, measured 2026-09-15)

| Metric | Result |
|---|---|
| `flutter test` | **62 pass / 0 fail** (was 51) — added transition_copy_test, run-detail plain/description tests, expanded goldens to 10 + 2 decision detail states |
| Server `dart test -j 1` | **62 pass / 0 fail** (was 59) — added generated_client_e2e_test (3 real-client HTTP E2E tests) |
| Real generated-client E2E | **3 pass / 0 fail** — overview+listWorkItems, inspect transition history, resolve round-trip with SAME WorkItem ID preservation |
| Goldens | Regenerated `--update-goldens` 10/10 + 2 decision detail states (pending, submitted) green. **Still require human approval before use as fidelity evidence** (§3.3). They now exercise real states (seeded blocs; submitted state actually taps the chip + submit) rather than empty/repetitive shells |
| Analyze | 0 errors / 9 info (style `prefer_initializing_formals`, pre-existing) |
| Format | clean |
| Real UI (Playwright) | Overview → All work → Needs you → Decision Detail → submit → SAME WorkItem advances (DESIGN_APPROVED) → Run Detail timeline, DB durably persists; 6 desktop + 5 mobile screenshots captured |

### Known non-conformances carried forward (NOT fabricated away)

1. **`PL-6`** — **RESOLVED** (2026-09-15). Description is now required at
   `DurableWorkflowEngine.createWorkItem`: nonempty, ≥ `kMinHumanFacingDescriptionLength`
   (12 chars), distinct from `title` after trim. Legacy persisted null/blank
   descriptions MAY display `title` as fallback (no mutation / bulk migration).
   Rule: `packages/workflow_store/lib/src/human_facing_description.dart`.
2. **`PL-4`** staying open — "QA reviewer" not assumed; the failed/rejected states
   use plain copy already in the design.
3. **`PL-5`** — expiry behaviour untouched; no countdown added because none exists
   in the durable model.
4. **Needs You cards** — artifact links (`WorkItem.artifactRefs`) NOT yet
   implemented at the row level; skills "status: handoff" from §6 stands, read
   but not surfaced for a card-level `ArtifactType` render.
5. **Overview metric "running"** — scope is non-terminal AND not blocked
   (includes failed non-terminal) vs the Working-on-it lane (`agent_executing`);
   the two numbers differ intentionally and remain semantically distinct.

### Scope guard

Nothing in this record claims pixel fidelity: Penpot geometry was NOT
retrievable in the implementing session (no open-file session), so
implementation followed the BP/BPM text spec recorded in 004 §11–§14. The 20
board exports must still get a pixel-level look by a human or image-capable
reviewer as part of the gate package (§13 limitation). Goldens are candidate
evidence only. No copy was invented for `PL-6`; where a human decision does not
exist, the real durable value is shown.

### Additional work (2026-09-16 session)

| Change | What / Why |
|---|---|
| **Decision Detail `?wi=` wiring** | `needs_you_page.dart`, `run_detail_page.dart`, `decision_detail_page.dart` now carry the workItemId via `?wi=` query param. Without it `runId` fell back to `decisionId` and `listDecisions(decisionId)` returned nothing → empty page. Affects all real-UI flows that open Decision Detail. |
| **Generated-client E2E** | New `test/integration/generated_client_e2e_test.dart`: real in-process Serverpod + real `control_plane_client.Client` over real HTTP → real PostgreSQL. 3/3 tests (overview, inspect transitions, resolve round-trip). Also serves as regression canary for the `_jsonValue` nested-payload hand-patch in `protocol.dart`. |
| **E2E dev server** | New `bin/e2e_dev_server.dart`: fixed port 8190, mode test, configOverride (insights/web/redis null). Security note: Serverpod binds `anyIPv6`; intended for trusted single-user dev only. |
| **Real Playwright E2E** | Full desktop flow: Overview (HOME_DATA_PROOF: "Running 5, Waiting on You 2, Recently Finished 1") → All work (9 items, title fallback on `wi-legacy-1`) → Needs you → click card → Decision Detail (real question, choices, wait time) → Approve + rationale → submit → "Decision Submitted" → Needs you shows 2 pending → same `wi-ny-1` = DESIGN_APPROVED in All work + Run Detail timeline. DB durably persists: `wi-ny-1` state=`design_approved`, `dec-ny-1` status=`resolved`, transition row present. |
| **Transition copy** | `transition_copy.dart` rewritten with snake_case wire values (`agent_executing`, `waiting_for_human_decision`, etc.) per `platform_contracts` wires. Full test coverage in `transition_copy_test.dart` (16+ tests: all engine pairs + generic escapes). |
| **Run Detail CTA** | `Review and decide` routes to `/needs-you/{blockingHumanDecisionId}?wi={runId}` — carries both IDs. |
| **Desktop + mobile screenshots** | 11 captures: 6 desktop (Home, All work, Needs you, Decision Detail pending/submitted, Run Detail) + 5 mobile (Home, All work, Needs you, Decision Detail pending, Run Detail) in `test/pixel-fidelity/`. |
| **Independent review** | No P0. P1: `e2e_dev_server.dart` security (bind all interfaces → documented), `protocol.dart` hand-edit fragility (regression canary added). P2: `decision_detail_page.dart` fallback from `?? decisionId` is misleading on manual deep links (no functional regression — no app path produces that URL). |

### Analysis conclusions (2026-09-16, agent analysis — NOT human decisions)

#### PL-4 — "QA reviewer" as a distinct role

The decision flow the UI exposes separates human *approve* vs *reject* only. It
never references a "QA reviewer" persona or role. No durable contract,
authorization check, or workflow permission differentiates QA from an
engineer. Conclusion: **no new authorization model is required** to be
BP/BPM-conformant; the flow works with ordinary operator permissions. This is an
analysis conclusion; the formal gate record remains open until the human review.

#### PL-5 — decision expiry (`guard_conditions.dart` → expired → refused transition)

`HumanDecision.expiration` is `DateTime?`; the guard rejects a resolution made
after `expiration` and leaves the work item blocked with no UI signal. This is a
probable bug but a workflow-semantics question. Conclusion: **defer with
authority** — change nothing this session, keep a bounded tracked reference to
the finding (this record), and raise it in the human gate so the semantics can
be decided (auto-escalate vs notify vs permit). No countdown is added anywhere.

#### ArtifactRefs fidelity audit

`WorkItem.artifactRefs` is `List<ArtifactReference>?`; wire: artifactId,
artifactType, uri, provider, contentHash, description, createdAt. Audit result:

| Surface | Article | Status |
|---|---|---|
| `wi-tl-1` seeded with artifactRefsJson | Run Detail timeline — raw present, fields visible via response | IMPLEMENTED (data-bearing) |
| Needs You cards — inline `DESIGN · Version 3 · open ↗` rendering | BP shows artifact inline per card | GAP (not surfaced at card level; read but not rendered) |
| Run log link on failed items | BP shows `LAST RUN · Log · open ↗` | DEFERRED (existing log surface unchanged) |
| Preview binding to `ArtifactReference.uri` | Production preview must bind to the ref | N.A. (no preview surface built) |

The audit was done on the seeded `wi-tl-1` row (7 transitions + artifactRefs)
through real HTTP + Playwright. No artifactRefs described but not present.

#### Golden binding metadata

Goldens are screenshot-based and bind to: page + seeded bloc state (no external
I/O), fixed `ShipItTheme.dark()` palette, and a fixed test-font environment. They
are **implementation evidence, not approved design baselines** (§3.3 pending
human approval). Current artifacts:
`test/goldens/goldens/home_page.png, runs_page_desktop.png, needs_you_page_with_decisions.png,
run_detail_page_loaded.png, decision_detail_page_pending.png, decision_detail_page_submitted.png`
(+ responsive/mobile variants), regenerated via `flutter test --update-goldens`.
