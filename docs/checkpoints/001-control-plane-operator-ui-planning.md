# Checkpoint 001 — First ShipIt Control-Plane Operator UI

**Status: READY_FOR_DESIGN**

Confirmed by direct repository inspection in this slice. No Flutter UI has
been implemented. No endpoint has been added. No server/DB write path exists
beyond the already-durable `resolveHumanDecision` engine path. The UI journey
goal ("observe the SAME WorkItem resume") is unchanged and is *provable* with
the current server, as proven below.

---

## 1. BASELINE

| Item | Value |
|---|---|
| Platform repo | `ShipIt/shipit-platform` @ **`2bb7d50`** (`feat: add durable persistent scheduler with claim-CAS job queue`) — pushed, clean tree |
| Current working tree | clean (all 4 persistence tests green; melos gates as recorded) |
| AEF contract consulted | `agentic-engineering-framework` @ `01e0e845` |
| UI repo consulted | `shipitinc/shipit-ui` @ `2e4a8fe6` (clone: `/var/folders/.../opencode/shipit-ui`) |
| FVM | global `4.1.2`, Flutter **3.44.7** stable (`fvm list` canonical; workspace root runs via melos `dart`/`flutter` pass-through) |
| Melos | **8.6.0** |
| Serverpod | **3.4.13** (`apps/server`); `serverpod` bin = `~/.pub-cache/bin/serverpod` |
| Serverpod client protocol | `packages/control_plane_client` (pure Dart, generated, `.g.dart` committed) |
| PostgreSQL (compose) | up; `ping` tool reaches `0.0.0.0:9090` (dev) and integration DB `0.0.0.0:9091` |
| Penpot | **NOT CONNECTED this session** — Penpot/Penpot MCP has no connected workspace. Design-authority evidence (Penpot) unusable in-session; flagged as a gate (below). |

Same gate predicates as the persistence slice: `melos run format:apply`,
`analyze`, `test:control-plane` are the serial-PG-safe gates (52 control-plane
tests, `-j 1`); root `melos test` remains limited by the known shared-PG
parallel race on `control_plane_server`, which is documented, not hidden.

---

## 2. CHANGE INTENT (What this slice is)

The **first operator-facing ShipIt surface**: a Flutter Web control plane the
operator actually runs. It must:

1. **Never lie.** All state shown is durable state read through the real
   Serverpod client — **no demo rows, no fake runs, no fake "blocked" items,
   no seeded pending decisions, no fabricated signatures**, no "resumed!"
   toast that the server did not confirm.
2. **Never bypass policy.** The UI is a **reader** of durable workflow/job/
   execution/decision state plus one legal writer (`resolveHumanDecision`).
   No endpoint gets "set work item state". ShipIt's durable state machine and
   scheduler remain the only thing that *advances* work.
3. **Surface what needs a human.** "Needs You" is what makes this a control
   plane rather than a generic dashboard.

**Do NOT implement Flutter before this checkpoint is reviewed.** This package
is the requirement + QA contract + design determination. After review and
(required) Penpot design authority, the exact ShipIt lifecycle resumes at the
next legitimate human gate (`HUMAN_DESIGN_APPROVAL_REQUIRED` after design, per
AEF).

---

## 3. THE DURABLE TRUTH (What the UI actually has to read)

From current `platform_contracts` + the Serverpod service (all durable, all
readable through real endpoints):

- **`WorkItem`** (`WorkItemState` machine: `created → planning → planned →`
  `designRequired → designInReview → waitingForHumanDecision → designApproved`
  `→ designNotRequired → implementing → qaInProgress → qaPassed →`
  `qaWaitingForHumanDecision → deployWaitingForHumanDecision → deploying →`
  `deployed → verified → succeeded`, plus terminal `failed`, `cancelled`,
  `rejected`, and blocking `waitingForBlockingDecision` states). Each carries
  `workItemId`, `productId`, `category`, `title`, `description`, `state`,
  `blockingHumanDecisionId`, history (durable transition rows), and
  human-decision references.
- **`HumanDecision`** (durable row): `decisionId`, `workItemId`,
  `decisionType`, `status` (`pending/approved/rejected/…`), `question`,
  `context` (`DecisionContext`), **`options` (`List<HumanDecisionOption>` with
  `optionId/label/description/recommended`)**, `recommendation`, `blocking`,
  `requestedAt`, `expiration`, `decider`, `choice`, `rationale`, `timestamp`,
  `signature` (`DecisionSignature`), `resolvedOptionId`.
- **`Job` + `JobEvent` + `JobClaim`** (durable queue state: `queued/claimed/
  running/succeeded/failed/cancelled` etc.).
- **`WorkerExecution` + `WorkerExecutionResult` + `WorkerEvent`**
  (isolated pinned worktree run → `succeeded/failed/prepareFailed/timedOut/
  cancelled/orphaned`).
- **`AgentExecution` + events + `AgentResult`** (durable `DurableAgentExecution`).
- **`PlatformVerification`** (independent QA evidence) and **`WorkerRegistration`**.

Tests proving these are battle-tested: store contracts (32), concurrency (4),
migration (4), endpoints (5), and the 7 E2E crash/restart proofs — all green.

---

## 4. FEATURE ID

**`CONTROL_PLANE_OPERATOR_UI_001`** (with the suffix resolved against the
slot documentation's "Space (Home)"; this slice owns the **Home** surface
plus the global shells that all four surfaces share; Home is the first
approved Penpot visual.)

---

## 5. FEATURE REQUIREMENT

An operator of ShipIt must be able to, from a single Flutter Web app, answer
"what is ShipIt doing right now?" **based on real durable platform state**
(home), inspect the engineering runs and their executed work (**Runs**), and
see — and act on — the exactly-one class of thing that needs a human
(**"Needs You"**).

The UI translates domain state into engineering terms:
- `waitingForHumanDecision`/`waitingForBlockingDecision` → operator-friendly
  phrasing + action, **never** raw enum casing.
- A readable, tested mapping of every `WorkItemState`/`JobState`/
  `HumanDecisionStatus` → operator label + tone + recommended next step.
- Consequential decisions are explicit: what ShipIt is asking, why it
  stopped, the contract's recommendation, the **allowed** choices from the
  durable `HumanDecisionOptions`, and the durable consequence.

This is a **control plane for an engineering operator**, not a shipments
dashboard: the primary jobs-to-be-done are (a) understand ongoing work,
(b) unblock human gates. Surfacing the four established spaces (Home, Runs,
Needs You, and the decision/needs-you workspace) with no fabrication is the
feature. Operator identity is a **local/private development identity** in this
slice (documented below), matching the existing local signature mechanism.

---

## 6. ACCEPTANCE CRITERIA

AC-1. **Real data.** Every list, count, status, and detail rendered comes from
   durable state read through the generated Serverpod client. No fixture/fake
   rows in the running app. Home, Runs, Needs You are derivable from real
   persisted rows and proven by the E2E journey.
AC-2. **Authoritative status presentation.** Every rendered status is derived
   from durable `state` fields through one tested presentation mapping —
   never raw enum casing, never a client-side contradictory status.
AC-3. **No policy bypass.** The app never writes `WorkItem.state` and there is
   no endpoint that does. The only write the UI can trigger is resolving a
   human decision through the real durable engine, exactly as `resolveDecision`
   already does. No "skip design", no "force QA pass", no fabricated approval,
   no invented HumanDecision, no fake signature.
AC-4. **Home = what's happening.** Home shows *current operational state*:
   runs in flight, queued/blocked waits, and needs-you count —
   each derived from real reads; no meaningless KPI cards, no fabricated
   metrics.
AC-5. **Needs You = real blocking gates.** The Needs You surface lists only
   durable `HumanDecision`s that are genuinely pending and blocking. Opening
   one is a detail screen; resolving goes through the validated
   `resolveHumanDecision` path and the **same** WorkItem resumes (no optimistic
   claim, no local-only fake).
AC-6. **Runs = inspectable real work.** Runs list + detail come from real
   durable `Job`/`WorkerExecution`/`AgentExecution`/`Verification` rows tied to
   a real `WorkItem`. Detail includes meaningful activity/execution info and
   verification where available.
AC-7. **Resilient presentation.** Loading (shipit UI skeleton), error (inline
   alert with retry), empty (ShipIt empty state) — all non-fabricated.
AC-8. **ShipIt policy copies:** validation + transitions must not be duplicated
   in the UI; typed contracts used end-to-end; structured logging preserved.

---

## 7. QA CONTRACT (PROPOSED — TO BE APPROVED)

The QA contract below is the contract this slice commits to; it is not yet
"approved" (approval = human design+QA gate, and separately golden baselines
need a human in Penpot).

| Area | Contract |
|---|---|
| BLoC/presentation mapping | unit — mapping table state→label→tone→action for every reachable durable state (all `WorkItemState`, `JobState`, `HumanDecisionStatus`, and the worker/execution statuses surfaced) is tested (unordered mismatch + every wire value covered) |
| Repository/mapping | unit — repository guards: never returns raw enum casing; null/error/empty propagate; staleness handled |
| Serverpod integration | contract — the running app reads ONLY via generated client; the read endpoints already have 5/5 endpoint tests; resolution has 4/4 durability tests; E2E home/needs-you journey against real PG |
| Widget | Home, Runs, Needs You at Home/Runs/detail states: loading/success/empty/error/blocked; decision card content; resolution submission state; resume-confirmed state |
| Golden | every screen/state above has a golden (Penpot-approved baseline); goldens must be human-approved, not self-approved |
| Accessibility | semantic labels, focus traversal, keyboard nav (decision options focusable), contrast via tokens, no screen-reader-only fear claims — verified, not asserted |
| Responsive | desktop ≥1024 (primary; Serverpod Flutter Web), tablet/mobile via canonical responsive layout; document chosen viewports |
| Security | no PG access from UI; no raw Serverpod errors to users; structured logs only; local identity documented |

---

## 8. API GAP ANALYSIS (current server → UI needs)

| UI need | Current availability | Gap |
|---|---|---|
| Home: counts of running/queued/needs-you/recent | `listWorkItems`-class data exists *server-side* (`ControlPlaneService.readWorkItem/readAllWorkItems`); endpoints expose only per-item `inspect` + `inspectDecision` + decision lists | **MISSING endpoint** for a compact Home summary (would need to read the full DB load-all OR a minimal summary read). Minimal option: one read-only `overview()`/`summary()` application-service query. PROPOSED (read-only, minimal). |
| Home: list work items (Runs base) | no global list endpoint | **MISSING** — minimal read-only `listWorkItems({state?, limit?})`. PROPOSED. |
| Runs detail | `workflowEndpoints.inspect` (work item + transition history) + `workerEndpoints.listExecutions(workItemId)` + `executionEndpoints.list` + `schedulerEndpoints.inspect` compose | **AVAILABLE (compose)** — no new endpoint required for detail; the four existing reads suffice. |
| Needs You: list pending human gates | human decisions read per work item (`workflowEndpoints.listDecisions`); **no global "pending decisions" query** | **MISSING** — minimal read-only `pendingHumanDecisions({limit?})` returning only genuinely-pending blocking decisions + their work item context. PROPOSED. |
| Needs You: open + resolve one gate | `inspect` + `resolveDecision` (durable, CAS, idempotent, signature-bearing) | **AVAILABLE** — the write path already exists and is proven (4/4 durability + 4/4 concurrency + E2E). |
| Decision detail evidence | `HumanDecision` (+`options`/`recommendation`) fully serialized on the wire | **AVAILABLE** — `listDecisions`/`inspectDecision` expose `options`, `recommendation`, `context`, `blocking`, `rationale`, `signature` fields. |

**Decision on gaps:** the three MISSING are all **read-only** and minimal
(no CRUD, no state mutation, no config). They are the *only* additions the
UI needs and will be designed/documented in the design brief (endpoints are
NOT created in this checkpoint). All of them are plain reads over durable rows.

---

## 9. DESIGN DETERMINATION

- **Platform/stack:** Flutter Web app in this monorepo under
  `packages/control_plane_client` — but see §17 seam conflict. ShipIt_UI consumed via
  shipit_ui tokens/theme. Mock-free, real-server E2E.
- **State management:** feature-scoped BLoC (Home, Runs, Needs You subtree) —
  not one global "ControlPlaneBloc"; no Riverpod/Bloc-in-widgets.
- **Every screen inherits the shell** (Home/Runs/Needs You destinations). Home
  is the first Penpot-approved design.
- **Penpot:** the AEF "control-plane" design system is the visual authority.
  Since Penpot has no connected workspace in *this* session, design-authority
  evidence is gated: **Penpot connection + human design approval required
  before anything is built** (§20). Nothing in this checkpoint claims approval
  of a design that cannot be produced here.
- **No fabricated data ever.** Decisions are only shown when durably present;
  counts only from durable reads.

---

## 10. INFORMATION ARCHITECTURE

Home
├─ "What's happening" headline cluster
│   ├─ Running now (durable running/queued work)
│   ├─ Waiting on you (needs-you count + jump deep-link)
│   └─ Recently finished / failed (durable recent items within a bounded
│      window — no full-history dump on Home)
├─ Recent runs (bounded, click → Runs detail)
└─ Governed surfaces: Home → Runs → individual Run/Run detail → Needs You
   → Needs You item/detail → resolve → back to the SAME work item context

No "Projects / Deployments / Settings / Workers / Models" navigation in this
slice (§20 out of scope).

---

## 11. INFORMATION ARCHITECTURE: SHIPIT_UI RECONCILIATION

| Operator task in IA | Start | Mid | End |
|---|---|---|---|
| Resume a needs-you run | Home → "Waiting on you" count | Needs You list → decision detail (context/recommendation/options) | resolve → server-confirmed → back to that runs detail showing resumed |
| Find a specific runs/run | Runs rail | Runs list (title/state/time) → detail | detail history/executions/verification |
| See what's running | Home running cluster → Runs list filtered running | | |

This IA is deliberately 3-deep max per task and matches the AGENTS boundary —
no settings/admin surfaces yet.

---

## 12. SCREENS / STATES

| Screen | States |
|---|---|
| Home | loading · summary/ok · error(retry) · empty(no work) |
| Runs list | loading · loaded · error · empty |
| Run detail | loading · loaded · error · not-found(stale id) |
| Needs You | loading · empty("nothing needs you right now") · list(pending blocking gates) · error |
| Decision detail | loading · loaded(pending, options, recommendation, context, asked/expires) · resolving(busy, decision kept) · server-confirmed(resolved + brief) · stale/already-resolved(alert + refresh) |
| Shell rails (Home/Runs/Needs You) | persistent, responsive (rail↔bottom nav at canonical breakpoints) |

---

## 13. RESPONSIVE STRATEGY

Desktop-first (operator on wide screen), ShipIt tokens for space/breakpoints;
at compact widths the shell collapses to ShipIt's canonical bottom-nav and
Needs You stays reachable (it is the operator's primary job). Document viewport
targets in the design brief; golden at ≥2 widths per screen.

---

## 14. ACCESSIBILITY

- Semantics on all status renderings; inline alerts announce errors
  (`AppInlineAlert`), loading via skeleton, empty via `AppEmptyState`.
- Keyboard: decision options focusable/tabbable; resolution is a real form
  submit (no double-tap traps); focus returns to the resumed run.
- Color is never the only signal (text label + tone + optional icon).
- Verify text scaling + contrast inside ShipIt tokens; never hand-rolled font
  sizes/raw colors.

---

## 15. SECURITY NOTES

- `packages/control_plane_client` is the **only** place PG is touched — no raw PG, no
  Serverpod internals from the UI; server endpoints remain read-only + the
  single sanctioned `resolveHumanDecision` write.
- Operator identity: **local/private dev identity** (the existing local
  signature mechanism). No fake auth, no invented PKI. Documented clearly in
  the UI (e.g. "device-local operator identity" badge) and in the security
  section; a production identity is out of slice scope.
- No secrets/tokens in goldens or logs. Structured logging only.

---

## 16. SHIPIT_UI GAP ANALYSIS

shipit_ui provides: theme/tokens (`context.color/space/text/...`), `AppCard`,
`AppButton`/`AppTextButton`/`AppIconButton`, `AppNavigationRail` +
`AppBottomNavigationBar`, `AppEmptyState`, `AppInlineAlert`, `AppSkeleton`/
`AppShimmer`, `AppAvatar`, `AppSearchField`, `AppSelect`, `AppDatePicker`,
`AppFilterChip`, `AppDataTable`, dialogs (`AppDialog`, `AppConfirmDialog`),
`AppTooltip`, `AppTextField`, `AppButton`… — enough to build all four
surfaces' shared needs.

**Genuine gaps (candidate shipit_ui primitives, deferred):**
1. **Status badge/pill** for durable statuses (running/needs-you/queued/
   failed/…) with tone — currently must be composed per-product from tokens.
   Proposing a small `StatusBadge` as a **shipit_ui candidate PRIMITIVE**
   (product-neutral; final call: SHIPIT_UI_GAP pending Penpot design review).
2. **Activity/event timeline** (run history, decision history) — reusable
   `ActivityTimeline` candidate PRIMITIVE.
3. Decision-card composition is product-specific → NOT shipit_ui; stays in the
   app (shipit_ui must not host product components — AGENTS rule).

Per AGENTS §5b these proposals require an explicit report:

**SHIPIT_UI_GAP**: The control-plane slices need (1) a tonal `StatusBadge`
   primitive and (2) an `ActivityTimeline` primitive as reusable
   product-neutral shipit_ui componentsholly. Both are genuine cross-product
   primitives (dashboards/ops tooling broadly need them), so I flag them
   here and will add them to shipit_ui ONLY after the approved design phase
   and Penpot baseline (per engine/golden governance — do not self-add UI
   components mid-checkpoint).

---

## 17. EXPECTED FLUTTER ARCHITECTURE

**Seam conflict discovered:** AGENTS.md + ADR 0003 put frontend pages under
`packages/control_plane_client/lib/src/pages/`, but `packages/control_plane_client` is currently
the **pure-Dart generated Serverpod protocol package** (no Flutter dep, no
test dir). Decision (proposed, design-phase): keep the generated protocol
where it is (single source of truth for wire types) and add a **new Flutter
app package** `apps/app` (or `apps/control_plane_app` per workspace
convention) that depends on `control_plane_client` + `shipit_ui`, and
`AGENTS.md` gains the matching boundary row. This avoids duplicate client
packages while keeping protocol vs UI separate and is flagged for human
approval. (Will be finalized in the design brief; nothing imported/created in
this checkpoint.)

```
apps/app (new Flutter Web app)
├── lib/
│   ├── main.dart               # boot: shipit_ui theme + routes + scopes
│   ├── src/
│   │   ├── app.dart            # shell (Home/Runs/Needs You nav)
│   │   ├── bootstrap.dart      # generated client + repository wiring
│   │   ├── routes/             # go_router: '/', '/runs', '/runs/:id',
│   │   │                       #   '/needs-you', '/needs-you/:decisionId'
│   │   ├── core/               # structured logging-safe env, error mapping
│   │   ├── features/
│   │   │   ├── home/           # HomeBloc + HomeView + widgets
│   │   │   ├── runs/           # RunsBloc(list Rows) + RunDetailBloc
│   │   │   └── needs_you/      # NeedsYouBloc + DecisionBloc + ResolveBloc
│   │   └── shared/             # presentation mapping (state→label/tone),
│   │                           # repositories over generated protocol
└── test/                       # bloc + widget + golden (Penpot baseline) +
                                # accessibility; E2E junit at slice level
```

Consumes `packages/control_plane_client` (generated protocol) and the approved
`shipit_ui` design-system package. No direct PG, no raw Serverpod calls from
widgets, no state mutation from UI.

---

## 18. E2E PLAN (control-plane app ↔ real Serverpod ↔ PG)

**Journey: "A blocked run resumes through the operator"**

1. Seed/advance a real `WorkItem` via the durable engine to a state that is
   blocked waiting on a `HumanDecision` (`waitingForHumanDecision`) — using
   real store writes (existing durability slice pattern).
2. Flutter app (web) boots against the real Serverpod endpoints.
3. **Home** shows the durable state (e.g. that work item "waiting on you").
4. **Needs You** lists the real pending decision; open it — context,
   question, options, recommendation, asked-at/expiry — all from the row.
5. Operator picks an **allowed** option + rationale; app calls
   `resolveDecision` with the real signature plumbing.
6. Server persists resolution → `WorkItem.state` transitions through the
   durable engine (`designApproved`/resumed path) — visible via
   `workflowEndpoints.inspect`.
7. Scheduler (already proven durable) creates the next legitimate `Job`;
   a `WorkerExecution` + coordinator `AgentExecution` run.
8. App refreshes: the **same** work item now shows resumed/running with real
   execution + verification — **no restart, no manual DB**, exactly the
   documented capability the persistence slice proved.

Automated proof (repeatable, deterministic): one integration slice test that
lives in `apps/server/test` (serial `-j 1`) driving the real engine +
scheduler + the Flutter app's repository with the real server — asserting
AC-1..AC-7 server-side. UI-only goldens live in `apps/app`.

---

## 19. HUMAN GATES / STATUS

Next gate after this package: **HUMAN_DESIGN_APPROVAL_REQUIRED** — specifically
(i) the Penpot control-plane workspace must be connected and the UX designed
in Penpot by design authority, and (ii) a human must approve the design and
the golden baseline. This checkpoint does **not** self-approve any design or
golden and does **not** implement UI.

Additionally the UI slice currently has **no ShipIt_UI Penpot workspace
connected** — recorded as an environment/dependency gate, not a design
decision.

---

## 20. STATUS — READY_FOR_DESIGN

Required before Flutter UI is implemented (the crate's own rule):

- [x] current-state analysis (this doc §1–§9)
- [x] feature specification + acceptance criteria (§5–§6)
- [x] QA contract (proposed; §7)
- [x] API gap analysis + minimal out-of-scope-for-CPUI endpoints (§8)
- [x] design determination (§9), IA (§10–§11), screens (§12)
- [x] responsive (§13), accessibility (§14), security (§15)
- [x] shipit_ui gap analysis + flagged SHIPIT_UI_GAP candidates (§16)
- [x] expected Flutter architecture (§17), E2E plan (§18)
- [x] human gates recorded (§19)

**NOT done (by design):** no Flutter code, no endpoints added, no DB changes,
no shipit_ui component additions, no self-approved goldens/design.

---
**Summary for the record:** This checkpoint is `READY_FOR_DESIGN`. The next
legitimate ShipIt/AEF human gate is `HUMAN_DESIGN_APPROVAL_REQUIRED` (Penpot
design + human design + golden approval), after which the same feature
implementation continues. RESULT is withheld until the human design gate is
passed — do not treat READY_FOR_DESIGN as the slice RESULT.

---

## §21 SESSION HANDOFF — new-session bootstrap (grounded, values-free)

**File/bind truth (verified by live probe, NOT subagent claim):**
- Bound Penpot surface reads: `Page 1`, `0 shapes`, `0 boards`. Probe + heartbeat
  are real; the earlier subagent's "5 boards · 383 shapes · 0 issues" was NOT
  reproducible against the live tree and is treated as **fabricated**.
- Human (design authority) reports seeing 5 boards with real content on their
  screen. These disagree. **Resolution:** re-probe the EXACT surface the human
  names; reconcile on their breadcrumb BEFORE creating/fixing anything.

**Brand palette — grounded, from real pixels of `Logo and Brand Guide Lines.png`**
(never speculative; earlier blue fallback RETIRED):
- Surfaces: navy `#182020` / `#202830` / `#263038`
- Brand accent (amber-orange family): `#F09038` / `#E08030` / `#C27028`,
  light chip `#FCE8CF`
- Reserved red (fail/block, singular): `#E83838`
- Neutrals: `#E0E0E0` / `#C8C8C8` / `#808080`

**Six human-approved fixes (authority = human eyes), apply against a VERIFIED tree:**
1. Home / Running Now: status dot must sit on the **cap-height baseline** of the
   numeral (top of digit = top-of-ShipIt brand type family), not the text cap's
   bottom / adjacent to baseline.
2. Run Detail: Resolve button text must be **horizontally centered** in its pill
   (and vertical).
3. Global + Decision Detail: any "Your call" / approve card MUST render the QA
   contract + evidence *in the UI* before a human approves — non-technical
   readable: test steps, credentials (by name), screenshots, links, Penpot
   links. Approval unreadable-by-inspection = gate gap (HUMAN gate correct).
   Decision Detail: bottom "Resolve now" button had effectively no foreground
   text; ensure visible, centered label.
4. Global rail: "Needs You" nav badge — count must be **horizontally AND
   vertically centered** within the badge (currently sits off/not centered).
5. Global chips + filters: chip/filter **text not vertically AND horizontally
   centered** in the chip — fix both axes.
6. Brand text pass: apply the grounded palette from §21 above (navy + amber
   orange family) across the boards — NOT the earlier speculative blue.

**Grounded flow to continue (next session):**
1. Human focuses the Penpot tab AND confirms the exact bound surface/breadcrumb.
2. Probe identity + full page/board/shape tree ONCE (`Page 1` currently reads
   empty — reconcile with human's breadcrumb or re-bind to the real file).
3. Apply the six fixes to the VERIFIED real tree in a single batch.
4. Export boards → PNG; visually inspect (or state plainly you cannot assert
   pixel truth); report boards + counts as REAL numbers only.
5. Proceed to Flutter ONLY after HUMAN_DESIGN_APPROVAL_REQUIRED gate passes.

**Applied (verified tree, live probe + vision review — all six fixes):** home `26213ee5-8af7-8000-8008-a369e295bbc4`, runs
`…a36b4fe4e7dc`, run detail `…a36b7d04d351`, needs you `…a36b90375a7b`, decision detail `…a36bafa46126`
(page `d8ac01df-6646-81d2-8008-a366c09aa9d3`).
1. Status dots (`RUNNING NOW`, `WAITING ON YOU`) reconfigured to sit on the numeral cap-height (y=130,
   dot baseline matches top of the numeral type family). x nudged to 269/597 to clear digit ink.
2. `Det Resolve Btn Text` centered horizontally+vertically in the pill.
3. Decision Detail: added `Dc Evidence Box` (440×118, `#263038`) + `Dc Evidence Label` +
   `Dc Evidence Body` in the "Why ShipIt stopped" card below the Why box — non-technical readable:
   test steps, credentials by name (no secret values), screenshots, links, Penpot board link.
   `Resolve Btn Text` now `#FFFFFF` and centered (was same color as pill fill = invisible).
4. `Nav · Needs You Badge Text` centered (dy=+2.25) across all five boards.
5. 34 chip/filter texts centered on both axes (run/table/blocking/option/filter/gov + job/exec/verify/
   det-state/pending chips).
6. Palette pass: navy surface treatment applied to all 5 boards. Boards `#182020`, summary/inner cards
   `#202838`/`#263038`, table rows `#202838`. 128 text elements inverted (dark→light). 71 fill + 5
   stroke shapes recolored to grounded navy/amber palette (blue RETIRED). Visual verification via
   exported PNGs confirmed by vision-capable model.

**Never (still binding, cross-session):** fabricate shapes/counts/evidence;
print/log/commit the token value by any means; treat a subagent's unverifiable
visual claim as ground truth. Values of brand tokens like hexes and figures are
fine in design/docs; credential values NEVER.
