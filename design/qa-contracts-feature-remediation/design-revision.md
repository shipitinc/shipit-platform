# Design Revision — Revision 2 — QA contracts for feature intake and design remediation

**Brief:** [`QA-CONTRACTS-FEATURE-REMEDIATION`](./design-brief.md) (Revision 1, `DESIGN_REVISION_BLOCKED`)
**Revision number:** 2
**Supersedes:** Revision 1 (`8F3B27D4-6C15-4E9A-B0D7-3F62C81A4E50`, authored at `ad4fada`)
**Governing decisions:**
- `.decisions/2a8f5c31-9d47-4e6b-b2f8-7c15e0d9a4b2.yaml` — HD-1, RESOLVED
- `.decisions/7f3e2a95-6c81-4d70-b215-8e94a0c7d382.yaml` — **the reading of HD-1's undelegated
  clause, RESOLVED by the operator 2026-10-17: `READING_B_CLAUSE_COVERS_EVERY_ROUTE`.** Reading A
  is rejected. **H-3 of revision 2 is therefore closed as a decision, not as an open judgement.**
- `.decisions/b81f40c7-2a96-4e38-bd51-6c07e9f3a824.yaml` — **the SEQUENCING, RESOLVED by the
  operator 2026-10-17: `HUMAN_SURFACE_FIRST`.** The park's human surface is built **BEFORE** the
  gate, reversing the previous pass's "slice 1.5". **Overridden on AUTHORITY, not reasoning** — the
  previous pass's merits argument is kept in `design-review-gate.md` §0.2 so a reader can see which
  axis the override was on.
- `.decisions/3e5a7c26-4b19-4f83-a0d7-6c29b8f1e540.yaml` — **the SHAPE of the park's decision,
  RESOLVED by the operator 2026-10-17: `NEW_HUMAN_DECISION_TYPE`.** The park's human surface gets
  **its own `HumanDecisionType`** and may **not** re-use `escalation` or `designApproval`. **This
  decision closes the fork that three review rounds could not settle**, and §8's slice 1 is
  rewritten against it.
**Authoring HEAD:** `e3634a0cbbdf656267b22908284dd1ae8b655085` (revision 1)
**Revision 2 at:** `c8fd361906f0d831bbcfd431b75d1eb21ae9db5d`
**Corrected at:** `90b6f5f` (correction pass 1, lane `design-QA-CONTRACTS-CORRECTION-2`)
**Correction pass 3 at:** `2b182fd3215fde12a5814f0c7db4753514aa4c62` (lane
`design-QA-CONTRACTS-CORRECTION-3`)
**Correction pass 4 at:** see `design-revision-metadata.yaml` `correction_pass_4_base_sha` (lane
`design-QA-CONTRACTS-CORRECTION-4`) — **the fork the previous three passes left open is DECIDED**
(`.decisions/3e5a7c26-4b19-4f83-a0d7-6c29b8f1e540.yaml`, `NEW_HUMAN_DECISION_TYPE`, operator,
2026-10-17T14:40:00Z). **The park's human surface gets its own `HumanDecisionType`; `escalation` and
`designApproval` are both ruled out.** Everything in §4.2, §8, §11, §13.7 and §16 about the shape of
that answer was written against the open fork and is corrected or superseded in place below.
**Correction pass 5 at:** see `design-revision-metadata.yaml` `correction_pass_5_base_sha` (lane
`design-QA-CONTRACTS-CORRECTION-5`) — **the operator REVERSED pass 4's menu reduction**
(`.decisions/5a90c1d3-8e47-4b26-9f0c-3d7a5b2e6c19.yaml`, `FOURTH_CHOICE_VALUE`, operator,
2026-10-17T15:10:00Z). **The park's menu is FOUR again**; `re-triage` is a **new
`HumanDecisionChoice`** (`re_triage`) with its own `targetFor` arm and its own edge-whitelist
admission, so slice 1 is **four files** and **three whitelists**, not three and two. **The decision's
`scope_warning` was answered from the data model rather than assumed: a per-type option set IS
expressible, so this is not an escalation** (`design-review-gate.md` §6 1a). **Everything in §10, §12.3,
§13.7, §13.14 and §16 about the *number* of park answers was written against the reduction and is
corrected or superseded in place below.**
**Branch:** `main` (worktree `/Users/alkebut/air/shipit-platform`)
**Authored by:** `design-agent` / lane `design-QA-CONTRACTS-CORRECTION`, then corrected by
`design-agent` / lane `design-QA-CONTRACTS-CORRECTION-2`, then corrected again by
`design-agent` / lane `design-QA-CONTRACTS-CORRECTION-3`, then again by `design-agent` / lane
`design-QA-CONTRACTS-CORRECTION-4`, then again by `design-agent` / lane
`design-QA-CONTRACTS-CORRECTION-5`
**Disposition:** `DESIGN_REVISION_COMPLETE` — Revision 1's central defect (the deliverable-2 gate's
refusal sink did not exist) is corrected with a specified park; deliverable 3 remains **declined on
evidence**, now split **per path** rather than asserted for both; and **the reading of HD-1 is now a
recorded human decision** (`.decisions/7f3e2a95…`) which this revision applies rather than asks about.

> **Correction pass 2 was returned as `DESIGN_REVIEW_CHANGES_REQUIRED` — 1 BLOCKING, 2 HIGH, 4 MEDIUM,
> 3 LOW. Every item is addressed; `design-review-gate.md` §0 tabulates them in one place.**
>
> **The BLOCKING finding was that revision 2's own correction was wrong in the same shape as the one
> it was correcting.** Revision 1 left a refused item where it was; revision 2 specified a park and
> asserted, in three artifacts, that the park *"carries a durable reason"* — citing a range of
> `durable_workflow_engine.dart` that writes `blockingReason: null`. **The park survived; the reason
> did not.** That is recorded rather than smoothed, because it is the third time this design has
> claimed a property no assertion checked.
>
> ---
>
> **Correction pass 3 was returned with NO blockers and NO highs.** The review verified at the line
> level that B-1 is genuinely closed, **confirmed that this lane's refusal of the correction spec's
> recommended B-1 fix was correct on the merits**, and confirmed all eleven pass-2 corrections and the
> G14/G15/G16 assertions. **Nothing in that body of work is rebuilt here.**
>
> **What pass 3 changes is the SEQUENCING, and it is substantive.** The operator has decided
> (`.decisions/b81f40c7…`) that the park's human surface is built **before** the gate. The previous
> pass routed it as slice 1.5 and flagged that as its own judgement against the decision's word
> "FIRST"; **the independent review agreed with the merits and held that deferring a Level 3 operator
> instruction is the operator's call — *"a flagged judgement is not a discharged obligation."* The
> override is on **authority**, and `design-review-gate.md` §0.2 keeps the merits argument intact so a
> reader can see that. Everything else in pass 3 is metadata and argument: **M-A** (`FOLLOW_UPS` F-55
> now exists), **M-B** (a stale duplicate R4 row, withdrawn in place), **M-C** (the park's two-step
> order is load-bearing, and §5.1.1a now says why), **M-D** (the route-3 caller named to `file:line`),
> **L-A**, **L-B**, and **one citation defect the review did not raise** — `implementation_inflow.dart:
> 1543-1578`, a range 1103 lines past the end of a 440-line file, cited twice for a load-bearing
> property. **All are itemised in `design-revision-metadata.yaml` under `correction_items_disposition`.**

| Companion artifact | Contents |
|---|---|
| [`evaluator-spec.md`](./evaluator-spec.md) | Deliverable 1 in full — the QA gate evaluator |
| [`design-review-gate.md`](./design-review-gate.md) | Deliverable 2 in full — the HD-1 design-review gate |
| [`design-revision-metadata.yaml`](./design-revision-metadata.yaml) | Required metadata per `DESIGN_GOVERNANCE.md` |

---

## 0. Ownership

| Class | Paths |
|---|---|
| `OWNED_PATHS` | `design/qa-contracts-feature-remediation/**` |
| `READ_ONLY_PATHS` | `apps/**`, `packages/**`, `docs/**`, `docker/**`, `.github/**`, `Makefile`, `tooling/**` |
| `PROHIBITED_PATHS` | the same list — read freely, write nothing |

No docker, no compose, no `psql`. The QA stack was not touched. No `git stash`, no
`git checkout .`, no `git add -A`; explicit paths only. **All three correction passes are NEW commits
(`c8fd361`, `90b6f5f`, and pass 3's `2b182fd`); nothing was amended, rebased or reset.**

> **Correction (M-A): `docs/engineering/FOLLOW_UPS.md` was not modified by this lane — but F-55 now
> exists, and the previous pass's statement that it "was not written" is superseded.**
> `0bfb6fb` — the Manager's ledger commit — wrote **F-55** (*"the park's human surface has no 'do the
> design review' answer"*, §16) and **F-56** (the process note about it). **The previous pass cited
> F-55 as an existing artifact in six places across two artifacts while stating in four of them that
> it had never been written** — a dangling anchor that read as a fact because it was well-formed.
> **All six citations now resolve, and F-55 independently confirms this design's gap statement**
> (`design-review-gate.md` §5.2.2). **`docs/**` is `PROHIBITED_PATHS` here; F-55 and F-56 were read,
> not written.**

**Two non-goals are WITHDRAWN**, both because independent review showed their premises false:
*"Not a new `WorkItemState`"* and *"Not a new edge to `waitingForHumanDecision`"*. See §11 and
`design-review-gate.md` §3.5 and §5.1. Nothing else in §11 changes, and the reviews verified the
remaining ones stand.

**One further correction to a non-goal's reasoning.** The withdrawal above stands, but revision 2's
*justification* for keeping the state — that parking at `waitingForHumanDecision` instead *"would
re-park into the state it was just routed out of, with no durable change, forever"* — was right about
the conclusion and wrong about the mechanism. `design-review-gate.md` §5.1.1b now shows, against
`durable_workflow_engine.dart:816-841` and `:564-584`, that it is **worse than that**: a route-3
refusal leaves the item at `waitingForHumanDecision` holding a **resolved** decision id, which
nothing can re-open and no edge leads away from. **The distinct state is not a preference. It is the
sink.**

---

## 1. What has changed in the repository since the blocked brief

The brief was authored at `5afc230`. **The repository has moved, and three of the brief's four
foundings no longer hold as written.** They are corrected here rather than silently inherited,
because two of them change what can honestly be designed.

### 1.1 The red test is now green — the brief's CONTRADICTION is resolved

The brief (§3.3) proved its premise by executing a test that was red at `5afc230`:

```
Expected: noAction   Actual: runnable
```

Re-executed at `e3634a0`, **unmodified**:

```
$ dart test lib/src/triage/work_entry_test.dart -n "category-blind scheduler" -r expanded
00:00 +1: All tests passed!
```

The whole suite is green too — 37 tests, `work_entry_test.dart`, all pass. F-48 (`ddfbfff`) fixed
it by giving the feature park its own state. **The brief's `CONTRADICTION` against F-45 is no
longer live**; `FOLLOW_UPS.md` §12 and F-48 record the correction.

### 1.2 The two intake paths are no longer symmetric — this is the finding that matters

`ddfbfff` introduced `WorkItemState.featureIntakeParked`
(`packages/platform_contracts/lib/src/enums/workflow_state.dart:5`) and moved the feature park
there (`apps/server/lib/src/triage/work_entry.dart:543`, `:608-641`).

| Path | Parks at | In `triageDefectDefinition.entryStates`? | Consequence |
|---|---|---|---|
| Feature intake (`WI-feature-*`) | `featureIntakeParked` | **No** | **No run happens.** No result, nothing discarded. |
| Design remediation (`design-remediation-*`) | `planned` | **Yes** (`triage_defect.dart:130`) | **The run still happens, and its result is still discarded.** |

`featureIntakeParked` is in **no** `JobDefinition.entryStates` anywhere in the repository, and
`RunnableWorkEvaluator` rejects a state outside `entryStates` before consulting any policy
(`packages/scheduler/lib/src/policy/runnable_work.dart:172`). So a `WI-feature-*` item is
undispatchable by all three wired schedulers.

The design-remediation item is not: `_advanceToPlanned`
(`apps/server/lib/src/triage/lane_e_design_remediation_work_item.dart:449-492`) still stops at
`planned`, `planned` is still an entry state, and the run still ends with the outcome abandoned
(`apps/server/lib/src/triage/triage_processor.dart:279-285` → `:120-132`).

**So B2 survives for design remediation and is retired for feature intake.** The brief applied one
finding to both paths; that was correct at `5afc230` and is no longer.

### 1.3 The design governance *store* exists — the brief's premise understated it

The brief (§6, and lane E's own comment at
`lane_e_design_remediation_work_item.dart:125-127`) says there is "no `design_contract` table, no
`DesignContractStore`". **That is still true — and it is not the relevant absence.**

What exists at `e3634a0`:

- `packages/design_governance/` — a package with `DesignGovernanceStore`
  (`lib/src/store/design_governance_store.dart:8-13`), `InMemoryDesignGovernanceStore`, and four
  sub-interfaces carrying CAS, lineage traversal and idempotency
  (`lib/src/store/design_revision_store.dart:7-42`);
- `PostgresDesignGovernanceStore`
  (`apps/server/lib/src/persistence/postgres_design_governance_store.dart:9-10`), 693 lines,
  querying real tables created by migrations `20260928233022000` and `20261012145629000`;
- the contract types: `DesignRevision`
  (`packages/platform_contracts/lib/src/types/design_revision.dart:13-108`) carrying
  `status`, `riskTier`, `designerExecutionId`, `reviewExecutionIdsJson`, `approvedAt`;
  `DesignReviewResult` (`design_review_result.dart:12-46`) carrying `verdict`, `findings`,
  `assessedDimensions`; plus `DesignFinding`, `DesignRevisionEvent`, `DesignRiskTier`;
- a complete status lifecycle — `draft → inReview → changesRequired → reviewPassed →
  humanApprovalRequired → approved → superseded`
  (`packages/platform_contracts/lib/src/enums/design_revision_status.dart:1-28`), including
  `canTransitionToApproved` (`:24-28`), which admits only `reviewPassed` and
  `humanApprovalRequired`.

**And the one query HD-1's invariant needs already exists, implemented and tested:**

```dart
// apps/server/lib/src/persistence/postgres_design_governance_store.dart:46-60
SELECT * FROM "design_revision"
 WHERE "workItemId" = @workItemId AND "status" = @status   // status = 'approved'
```

What does **not** exist: `PostgresDesignGovernanceStore` is **instantiated nowhere** in
`apps/server/lib/server.dart`, and **no `Scheduler` dispatches the design lane** (§4.1).

**This is the single most consequential correction in this revision.** The brief's HD-1 framing
assumed the design-review artifact had to be invented. It does not. It has a typed model, a
durable store and a one-line query. What is missing is a *producer*, which is a different and much
smaller gap than a missing model.

---

## 2. The evaluator gap is worse than the brief or the Manager recorded

Both the brief (§7) and the Manager (`design-resume.md` §"B3 is worse than the brief recorded")
record that **no QA gate in this repository is evaluated by any production code.** That is correct
and re-verified:

```
$ rg "gateResults" packages apps          # 10 hits: 3 in the guard, 7 in tests, 0 in production
guard_conditions.dart:267   final gateResults = context?['gateResults'] as List<QAGateResult>?;
guard_conditions.dart:268   if (gateResults == null) return GuardResult.fail(name, ...);
```

Both also record the consequence: `allRequiredGatesPassed()` can only fail, so QA has never passed
an item. Correct. **Two further consequences are not recorded anywhere, and both are worse than
"unenforced".**

### 2.1 Every reviewable work item in the platform is stranded — one hop earlier than Revision 1 said, and by two edges, not one

> **Correction (HIGH finding H2).** Revision 1 wrote: *"`qaInProgress` is entered from exactly one
> edge — `reviewApproved -> qaInProgress` … Therefore: a work item that produces a reviewable
> commit, is engineering-reviewed, and is approved, walks to `qaInProgress` and stops there
> permanently."*
>
> **The chain is broken one hop earlier. `reviewApproved` is where the item stops, and
> `qaInProgress` is unreachable.** Verified:
>
> - `reviewApproved` is in **no** `JobDefinition.entryStates`. Every `entryStates` set in the
>   repository: `packages/scheduler/lib/src/baseline_product.dart:42`,
>   `packages/scheduler/lib/src/triage_defect.dart:126`,
>   `packages/scheduler/lib/src/scheduler.dart:3200, 3262, 3276, 3361`,
>   `packages/scheduler/lib/src/implement_feature.dart:114`. None contains it.
> - Its **only** in-edge is human: `waitingForHumanDecision -> reviewApproved`
>   (`packages/workflow_engine/lib/src/transitions/work_item_transitions.dart:425-434`).
> - Its **only** out-edge is `reviewApproved -> qaInProgress` (`:651-654`), and **no production code
>   calls `transition(to: WorkItemState.reviewApproved)` or `to: WorkItemState.qaInProgress`.** Every
>   such call site in the tree is in a `*_test.dart`.
>
> **So the finding is not retired — it moves one state left and becomes two findings.** The dead end
> is at `reviewApproved`, and `qaInProgress` is a second, unreachable state that has the same shape.
> The consequence for deliverable 1 is in [`evaluator-spec.md`](./evaluator-spec.md) §2.1: **slice 3c
> must be widened**, because a drain placed at `qaInProgress` has nothing to drain.

`qaInProgress` has exactly two out-edges:

- `qaInProgress -> qaPassed` (`:690-696`), guarded by `allRequiredGatesPassed()`, which **can
  only ever fail**;
- `qaInProgress -> qaFailed` (`:697-702`), guarded only by
  `actorAllowed([qaExecutor, orchestrator])`.

`qaInProgress` is in **no** `JobDefinition.entryStates`, so nothing dispatches from it either.
`AgentRole.qaExecutor` exists (`agent_role.dart:6`) but `QAOrchestration` — the class that would
be that executor's brain — is called from **its own test file only**.

**Therefore: a work item that produces a reviewable commit, is engineering-reviewed, and is
approved by a human, walks to `reviewApproved` and stops there permanently.** This is not specific to
feature intake or design remediation. It is the main implementation lane. It is a live dead end at the
centre of the platform, and no `FOLLOW_UPS.md` entry records it.

The brief's lesson — *a state nothing leaves is worse than one nothing enters* — is not a
generalisation here. **It is a live instance of itself**, and Revision 1 under-counted its own
instances.

### 2.1a A second declared edge with no caller — the same defect, on the gate's own edge

> **Correction (HIGH finding H1).** Revision 1's deliverable-2 table marked
> `agentFailed -> implementationReady` as an **automatic** route alongside
> `agentCompleted -> implementationReady`, placed the guard on both, and asserted the invariant was
> "enforced on both automatic routes". **There is no automatic route 2.**
>
> - the **only** `completionInflowFrom` in the repository is `{WorkItemState.agentCompleted}` —
>   `packages/scheduler/lib/src/implement_feature.dart:117`, verified by
>   `grep -rn completionInflowFrom packages apps` (the other hits are the field itself at
>   `runnable_work.dart:49, 128, 132` and tests);
> - the completion inflow filters by it: `if (!sources.contains(item.state)) continue;`
>   (`packages/scheduler/lib/src/scheduler.dart:1522`), so an item at `agentFailed` is skipped
>   before routing is attempted;
> - **no production code calls `transition(to: WorkItemState.implementationReady)`.**
>
> **So `agentFailed -> implementationReady` (`:265-267`) is a declared edge with no caller, and a
> guard on it is inert** — it would read `context['workItemOrigin']` from a context nobody built and
> return `pass`. `design-review-gate.md` §2.1 drops the guard from that edge and pins the rule with
> a drift assertion (G11).

**Both corrections are one pattern, and it is this revision's most useful finding:** `work_item_transitions.dart`
declares edges that no caller takes. Revision 1 read the table as a map of what happens. It is a map
of what *may* happen; the callers are in `scheduler.dart`, `execution_coordinator.dart` and the
endpoints, and they are a separate question. `server.dart:1327-1330` records the repository already
shipping this shape once ("built, tested green, and unreachable").

### 2.2 The four registered evaluators are not merely unenforced — they return a fabricated PASS

This is the finding that changes the evaluator design, and it cuts against the obvious approach.

`GateRegistry` registers four evaluators
(`packages/qa_orchestration/lib/src/gates/gate_registry.dart:19-23`). All four extend
`GateEvaluatorImpl`, whose validation is:

```dart
// packages/qa_orchestration/lib/src/gates/gate_evaluator.dart:53-58
bool _validateEvidence(List<QAEvidence> evidence, Map<String, dynamic> config) {
  return evidence.isNotEmpty;
}
```

`evidence` receives one entry per element of `gate.evidenceTypes`
(`gate_evaluator.dart:31-39`), and `evidenceTypes` is **required and non-null** on
`QAGateDefinition` (`packages/platform_contracts/lib/src/types/qa_contract.dart:72`, `:80`). So
`evidence.isNotEmpty` is **true for every contract that declares at least one evidence type** —
which is every contract this repository has.

The four collectors supply hardcoded, empty findings:

| Gate | Type string | Fabricated content | File |
|---|---|---|---|
| `StaticAnalysisGate` | `static-analysis` | `{'tool': …, 'issues': []}` | `predefined/static_analysis_gate.dart:24` |
| `TestCoverageGate` | `unit-tests` | `{'format': 'lcov', 'threshold': 0.8}` — **no coverage value** | `predefined/test_coverage_gate.dart:24` |
| `SecurityScanGate` | `security-scan` | `{'tool': …, 'vulnerabilities': []}` | `predefined/security_scan_gate.dart:24` |
| `PerformanceGate` | `performance` | `{'benchmarks': [], 'thresholds': {}}` | `predefined/performance_gate.dart:26` |

**Conclusion: if `QAOrchestration.evaluate` were wired into production today, all four would
return `QAGateStatus.passed` on every work item, with no analysis, no scan, no coverage run and no
benchmark executed.**

Today they are unreachable, so this is latent. But it inverts the naive plan. The instinct is
"wire the evaluator in and the gates start working." Following it would convert **"no gate is
evaluated"** — a `notExecuted`, which is honest and which `isGateSatisfied` correctly treats as
unsatisfied (`qa_orchestration.dart:56-61`) — into **"every gate passes"**, which is a false green
with a durable, auditable-looking evidence row attached to it.

**This is a worse state than the one we are in, and the evaluator slice must therefore replace
`_validateEvidence` before anything is wired.** That is a required sub-slice of deliverable 1,
not a follow-up to it. See [`evaluator-spec.md`](./evaluator-spec.md) §5.

---

## 3. Deliverable 3 — the two contracts: **declined on evidence**

The mandate: *"The two contracts, authored from what the agents actually emit — evidence, not
invention. If the result shape still cannot be established, say so rather than inferring one."*

**The result shape still cannot be established, and the reason is sharper than at `5afc230`.**

### 3.1 Feature intake — there is no run to describe

At `e3634a0` a `WI-feature-*` item parks at `featureIntakeParked`, which no scheduler dispatches
(§1.2). **No agent executes, so no `AgentResult` exists, so there is no result shape.** Not "the
wrong shape" — none.

The instruction the brief transcribed at `triage_defect.dart:249-264` and the parser at
`triage_processor.dart:199-222` are real and still cited correctly, but neither of them now runs
for a feature. Authoring a contract here would be authoring a contract for an execution that
cannot happen: a `QAContract` asserting properties of a document no process produces.

### 3.2 Design remediation — there is a run, and its result is abandoned

`design-remediation-*` still parks at `planned`, is still dispatched by `sched-triage`, and is
still executed by `AgentRole.triageDefect` under `triageDefectInstruction`.

The instruction's DEFECT DETAILS block degrades: `triage_defect.dart:223-231` reads
`metadata['defectId']`, `defectTitle`, `defectDescription`, `defectSeverity`, … and a
`design-remediation-DEF-…` work item carries none of those keys, so the prompt falls back to the
work-item id, the item's own title, and `EVIDENCE: []` (the fallback at `:231`) — while `:274`
instructs the agent to *"reference evidence IDs from the provided evidence list"*, a list that is
empty.

Then the result is discarded, exactly as the brief established:
`triage_processor.dart:102-105` parses and saves it; `_extractDefectId`
(`triage_processor.dart:279-285`) yields the work-item id because it does not start with
`defect-`; `readDefect` raises `DefectNotFoundException` at `:122`; the catch logs
`triage.processed.defect_missing` and `return triageResult;` at `:124-132`. **The job sits
`succeeded` with the outcome abandoned.** Re-verified at `e3634a0`; only the line numbers moved.

### 3.3 The refusal — **restated per path**, because Revision 1 asserted it for both

> **Correction (HIGH finding H3).** Revision 1's criterion was: *"A gate's `config.requiredFields`
> is justified by **a consumer that reads them**."* It then applied that criterion to both paths and
> concluded *"There is no consumer on either path."*
>
> **The criterion was silently tightened in mid-sentence to "…and its outcome is later used", and
> that tightening is what produced the wrong answer for design remediation.** On that stricter
> criterion the conclusion is right and uninteresting. On the criterion Revision 1 *stated*, the
> shape **is** establishable from the tree. Recording this is the point: the review found a live
> contradiction surviving because a decision was re-labelled rather than surfaced, and a reader who
> trusted the label would never check the code.

The two paths are therefore declined for **two different reasons**, and the dispositions are not
interchangeable:

| | **Feature intake** | **Design remediation** |
|---|---|---|
| **Grounds** | **No execution exists.** A `WI-feature-*` item parks at `featureIntakeParked`, which is in **no** `JobDefinition.entryStates` (§1.2), so `RunnableWorkEvaluator` returns `noAction` (`runnable_work.dart:172-174`) before consulting any policy. **No agent runs, no `AgentResult` exists, there is no result shape.** | **The shape IS establishable; what is missing is a *type*.** A run happens (§3.2). `triageDefectInstruction` is a **fixed template** naming the JSON schema verbatim (`packages/scheduler/lib/src/triage_defect.dart:222-276`, schema at `:249-264`). `_parseTriageResult` reads exactly four required keys (`apps/server/lib/src/triage/triage_processor.dart:199-222`) and **persists durably** via `saveTriageResult` (`:102-105`). |
| **What is missing** | Everything: a `JobDefinition` (M8), a role (M9), an instruction, a result type and a consumer (M10). | **M10 only** — *a design-remediation-specific instruction, result type, parser and consumer.* None exists; what exists is **triage's**, which is the wrong governance object for a design remediation. |
| **Declined on** | **Absence of the run.** Not inference; there is literally nothing to describe. | **M10's absence**, against an establishable shape. |
| **Also true, and stated because Revision 1 never mentioned it** | A product-declared `qaContractId` **is** provisioned for a feature item — `control_plane_service.dart:918-950`, stamped at `:940` (`qaContractId: provisioned.contractId`). | A product-declared `qaContractId` **is** provisioned for a remediation item — `lane_e_design_remediation_work_item.dart:283` (`_provisionQAContract`), stamped at `:294`. |
| **Disposition** | **Correct as written.** Not rebuilt; the review confirmed it. | **Correct in conclusion, wrong in reasoning.** Same answer, better-founded. |

**What the product-declared contract row changes:** Revision 1's §7 said the two declined contracts
are **`DOES NOT EXIST`**. That is true only of **path-specific** contracts. A contract *row* exists
for both paths today, because both provisions stamp `productQAContractIdForWorkItem(...)`. It is
unrelated to these gates and carries the product manifest's declaration, not a remediation-specific
obligation (`design-brief.md` §10: the `qa-product-` prefix is sufficient for **identity** and says
nothing about **content**). §7's table is corrected accordingly.

**The net position on deliverable 3 is unchanged — no gate set is authored — and the refusal is now
load-bearing on a named missing artifact rather than on a restated criterion.**

So this revision authors no gate set. The word for what would exist is `DECLARED`, and §7 says
what happens to it.

### 3.4 What the brief got right, and still holds

- `AgentRole` has twelve variants (`agent_role.dart:1-13`) and **none for either path**.
- `QAContractSpec` carries `gates` and nothing else
  (`packages/platform_contracts/lib/src/types/product_manifest.dart:129-141`);
  `QAGateSpec` carries `gateId`/`type`/`required`/`config` and **no `evidenceTypes` field**
  (`:145-165`), so any future gate must carry them in `config['evidenceTypes']` as a `List<String>`
  or `_declaredEvidenceTypes` throws `FormatException` and aborts the whole provision
  (`packages/qa_orchestration/lib/src/product_qa_contract.dart:168-192`).
- Pass criteria are **derived**, not chosen
  (`product_qa_contract.dart:128-141`): `allRequiredGatesMustPass: true`,
  `optionalGateFailuresAllowed: <optional gate count>`,
  `waiverRequiresHumanDecision: true`.
- The `qa-product-` prefix is sufficient for **identity** and says nothing about **content**.
- `product_qa_contract_test.dart` — **28 tests, green** at `e3634a0`, executed. The whole
  `packages/qa_orchestration` suite — 28 tests, green, executed.

---

## 4. Deliverable 2 — the design-review gate under HD-1

Specified in full in [`design-review-gate.md`](./design-review-gate.md). The summary:

### 4.1 The premise HD-1 was decided under has partly dissolved — and in the design's favour

HD-1 resolved on the reasoning that a human's undesigned request would reach
`AgentRole.implementer` through `implementationReady`. That reasoning is correct
(`implementFeatureDefinition.entryStates = {implementationReady}`,
`packages/scheduler/lib/src/implement_feature.dart:110-118`;
`implementationReady -> agentExecuting`,
`work_item_transitions.dart:135-138`). But three facts change what a gate can *be*:

**Fact 1 — the design lane cannot run.** `apps/server/lib/server.dart` constructs exactly three
`Scheduler` instances:

| Line | `schedulerId` | `definition` |
|---|---|---|
| `:475-481` | `sched-triage` | `triageDefectDefinition` |
| `:523-529` | `sched-review` | `engineeringReviewDefinition` |
| `:706-712` | `sched-impl` | `implementFeatureDefinition` |

`designRevisionDefinition` (`packages/scheduler/lib/src/scheduler.dart:3255-3265`) and
`designReviewDefinition` (`:3269-3280`) are declared, exported
(`packages/scheduler/lib/scheduler.dart:31-32`) and **never instantiated**. ADR 0021:112 says the
same thing from the governance side: *"If `DESIGN_GOVERNANCE_AUTOMATION_001` is not yet
implemented in shipit-platform, the boundary stops at WorkItem creation."*

**Fact 2 — the design lane and the implementation lane are disconnected in the graph.** There is
**no edge from any design state to `implementationReady`.** `implementationReady` has exactly three
*declared* in-edges: `agentCompleted` (`:340-342`), `agentFailed` (`:265`) and
`waitingForHumanDecision` (`:599-602`) — of which **only the first and third have callers**
(§2.1a). `designApproved`'s **only** out-edge is
`designApproved -> agentExecuting` (`:111-114`) — and `designApproved` is in
`triageDefectDefinition.entryStates` (`triage_defect.dart:128`), so an approved design routes the
item into **triage**, not implementation. `defaultImplementFeatureDefinition`
(`scheduler.dart:3196-3203`) is the one definition listing `designApproved`, and it is not wired
either.

**Fact 3 — therefore walking the design states is not an option.** A gate placed on
`designRequired -> designInReview` (`:55-58`) could never be reached, and placing the design review
on the path *through* `designApproved` would route the item into triage. A gate placed that way is
the dead end the mandate warns about.

**The gate must therefore be an artifact precondition on the route into `implementationReady`, not
a walk through states that nothing dispatches.** And the artifact check is available today,
because the durable approved-revision query already exists (§1.3).

### 4.2 The design in one paragraph

**One new `GuardCondition`, added to the two in-edges of `implementationReady` that have callers —
the automatic one and the human one — origin-conditional on the two intake origins, satisfied by a
real `DesignGovernanceStore.readApprovedDesignRevisionForWorkItem(workItemId)` result, and refused
items parked immediately in a state nothing dispatches with exactly one way out: a human.** One new
`WorkItemState` (`designReviewRequired`), two new edges into it, one out.
**~~No new `HumanDecisionType`, no new routing-table arm, no new decision type.~~ — SUPERSEDED IN PLACE
(CORRECTION PASS 4), and it is the **L3 pattern's fifth instance in this artifact set**: a superseded
claim surviving as a live one, in a paragraph no sweep had flagged. `.decisions/3e5a7c26-4b19-4f83-a0d7-6c29b8f1e540.yaml` —
operator, 2026-10-17T14:40:00Z,
`NEW_HUMAN_DECISION_TYPE` — decides the opposite on all three counts: the park's human surface **does**
add a new `HumanDecisionType`, **does** add a routing arm, and **does** introduce a new decision type.
The stale sentence was carried through passes 1, 2 and 3 unchanged and through two sweeps of this
paragraph, which is the point recorded in §12. It cannot create a silent dead end, because a
refusal parks rather than leaving the item where it was — **and `agentCompleted` is the one place
where "leave it where it was" is exactly a silent dead end** (§4.3).

**And the parked item's durable reason and blocking decision are produced by a named component** —
`DurableWorkflowEngine.requestHumanDecision`, not `transition` — because `transition` writes
`blockingReason: null` and `blockingHumanDecisionId: null` for every target that is not
`waitingForHumanDecision` (`durable_workflow_engine.dart:215-225`), while `requestHumanDecision`
writes both itself (`:651-653`). **Revision 2 got this wrong and three artifacts asserted the wrong
version as fact; `design-review-gate.md` §5.1.1a and §5.1.1b are the correction, and G14/G15/G16
are the assertions that would have caught it.**

Full specification, including the exact guard context contract, the park, and the four required
sub-slices, in [`design-review-gate.md`](./design-review-gate.md).

### 4.3 What happens to an item that never gets a design review

**Revision 1's answer to this question was wrong, and it was the BLOCKING finding.** It said: the
guard refuses, the item **stays at `agentCompleted`**, and *"`sched-review` picks it up, the
resolver returns `null` for a no-commit producer so no execution is burned, and it surfaces
`blockedArtifactMissing` → a **blocking human decision**."*

**Step 3 does not happen.** `engineeringReviewMissingArtifact`
(`apps/server/lib/src/review/engineering_review_gate.dart`) **stands down** for exactly this item:

```dart
// :2860-2871
if (item.state == WorkItemState.agentCompleted) {
  if (standDown.owns) {
    logger?.call('engineering-review-missing-artifact-stands-down', { … });
    return;                       // ← no decision, no park, no durable reason
  }
  …
}
```

`standDown.owns` is `true` for a no-commit producer by construction —
`_implementationInflowOwns` (`:2210-2228`) returns it *"unconditionally"* — and the composition root
documents the stand-down in prose (`apps/server/lib/server.dart:1416-1421`). **So the refused route
repeats every tick and nothing ever happens**: the silent dead end HD-1's delegated sub-question
required this design to rule out, and the shape `server.dart:1327-1330` records this repository as
shipping once.

**And Revision 1's assertions would have been green over it.** G1/G2 asserted only that the item
does not reach `implementationReady`, which a dead end satisfies.

**The corrected answer — specified in full at [`design-review-gate.md`](./design-review-gate.md)
§5.1.1 — is a park in the shape `ddfbfff` already shipped for this exact problem:**

1. the refusal is caught **by the caller that raised it**, in the same tick, and parked immediately;
2. `designReviewRequired` is in **no** `JobDefinition.entryStates`, so
   `RunnableWorkEvaluator` returns `noAction` for it (`runnable_work.dart:172-174`) — dispatchable
   by nobody, by construction rather than by accident;
3. it has exactly one named way out, `-> waitingForHumanDecision`
   (`work_item_transitions.dart:51-53`'s shape);
4. **no edge back** to `planned`, `designNotRequired` or `agentCompleted` — the reasoning at
   `:45-50`;
5. it is **idempotent**, which is what `server.dart:1412-1414` demands ("the scheduler re-surfaces
   the same job every tick … so this must be idempotent"), and which falls out of the state: a
   parked item is at a state in no `completionInflowFrom`, and is no longer `agentCompleted`, so the
   stand-down branch at `:2860` is never reached for it again.

> **CORRECTION — revision 2's step 3 carried a durable `blockingReason` "by" `transition`, and that
> was false.** It cited `durable_workflow_engine.dart:222-225`, which says:
>
> ```dart
> blockingReason: to == WorkItemState.waitingForHumanDecision
>     ? context['blockingReason'] as String? ?? 'Awaiting human decision at …'
>     : null,          // ← the park hop lands on designReviewRequired, so THIS branch runs
> ```
>
> `blockingHumanDecisionId` is conditional the same way (`:215-221`). **A park taken through
> `transition` erases whatever reason the item had and writes none** — B1's *"no decision, no park
> and no durable reason"* surviving under the new state name. Three artifacts asserted the opposite
> as fact: this section, `design-review-gate.md` §5.1.1, and the metadata's `design_system_compliance`
> and `ux_accessibility_score` fields.
>
> **The writer is named and it is not `transition`:** `DurableWorkflowEngine.requestHumanDecision`
> takes the park's out-edge as its own policy evaluation and then writes `blockingHumanDecisionId`
> and `blockingReason` itself (`:651-653`). It is a shipped, production-called component —
> `raiseStallDecision` (`apps/server/lib/src/triage/stalled_work_item_gate.dart:195-227`) is its
> caller today — it is idempotent (`:564-572`), and its decision lands on the Needs You surface an
> operator already uses (`apps/control_plane/lib/router.dart:70-75`).
>
> **And the precedent does not supply what revision 2 claimed from it.** The `featureIntakeParked`
> comment at `:34-40` explains **the way out of the park**; it does not record a durable reason, and
> the feature park has none. `design-review-gate.md` §3.5 records this rather than leaving the
> citation standing.

**New assertions close the holes revision 1's and revision 2's suites could not see:**
**G7** — a refused intake item is at `designReviewRequired`, not `agentCompleted`, within one tick;
**G14** — it arrives at `waitingForHumanDecision` with a non-null, non-default `blockingReason`;
**G15** — with a non-null, resolvable `blockingHumanDecisionId`; **G16** — offering exactly
`escalation`'s three answers. **This document no longer cites G1/G2 as evidence that the gate fails
closed**, and **G14 is the assertion whose absence let revision 2's false claim stand.**

**One consequence an operator will actually see, named because this design's idiom is to name it:**
a parked item is no longer at `agentCompleted`, so the review handler takes its `else` arm and logs
**`engineering-review-missing-artifact-unexpected-state`** (`engineering_review_gate.dart:2898-2905`)
on every tick. **That is expected, not a fault** — and `stalled_work_item_gate.dart:129-133`
(`stall.already-parked`) is the shipped pattern that answers such a log rather than riding it.

### 4.4 The human route, and the reading — DECIDED

Revision 1 left `waitingForHumanDecision -> implementationReady` (`:599-602`) **unguarded**, on the
reading that HD-1's `rationale_given` asks for no *"unattended"* dispatch — and then declared
`human_decisions_required: []`.

**That reading has been decided against.** `.decisions/7f3e2a95-6c81-4d70-b215-8e94a0c7d382.yaml`,
`RESOLVED`, `decided_by: operator`, `decided_at: 2026-10-17T13:40:00Z`:

> `resolution.selected: READING_B_CLAUSE_COVERS_EVERY_ROUTE` — *"The gate applies to
> waitingForHumanDecision -> implementationReady as well as the automatic routes."*
>
> `rationale_given` — *"The clause is unqualified … and **a clause that is not qualified is not
> narrowed by a rationale that explains why it was written.** Reading A was rejected."*
>
> `rejected_alternative` — *"…the independent reviewer found it 'defensible and not compelled' while
> noting **the design disposes of the rationale 'as a different field' in a single clause**, and
> never reconciles the design's own cost table — the strongest evidence against its own pick."*

**So the guard IS on the human edge, and this is applied rather than argued.** Revision 2's §5.2
stated the reading correctly and then argued it in a way the operator names as one of the reasons it
was rejected — *"Reading A imports one from a different field of the same document."* **That sentence
is gone.** `design-review-gate.md` §5.2 now applies the decision, keeps revision 2's grounds 2–4 as
*supporting* argument only, and reconciles the cost table rather than presenting it as evidence
against its own pick.

**What that costs, stated rather than minimised:** `HumanDecisionRouting.targetFor` routes four
decision pairs to `implementationReady`
(`packages/workflow_engine/lib/src/transitions/human_decision_routing.dart:103-104, 107-108,
109-110, 119-120`) — `(engineeringReview, rework)`, `(qaWaiver, reject)`, `(qaRework, reject)`,
`(humanQaApproval, reject)`. With the guard on, none of them can move an intake item to an
implementer until an approved `design_revision` exists, and **nothing writes one**
(§1.3, M5–M7). Until slice 4 lands, **intake items park and a human can re-triage, re-plan or stop
them — and nothing else.**

**That price is now the operator's, recorded knowing it — and it is not a resting state.** The
decision's `consequence` is explicit: *"The dead end this creates must be solved FIRST … This
decision does not make the dead end acceptable; it makes it the next thing to build."*

**And it is now also the operator's ORDER.** `.decisions/b81f40c7-2a96-4e38-bd51-6c07e9f3a824.yaml`,
`HUMAN_SURFACE_FIRST`, `decided_by: operator` — **the human surface is built before the gate.**
The previous pass routed it as slice 1.5 behind the gate and flagged that ordering as its own
judgement; `design-review-gate.md` §0.2 keeps that merits argument in full and records that the
override was **on authority, not reasoning**, with G17 added so the invariant the reversal exists to
enforce is *asserted* rather than promised. **`FOLLOW_UPS` F-55 now exists** (`0bfb6fb`, §16) and
independently states the gap, including that the sequencing question was *"RESERVED TO THE
OPERATOR"* — which is how `b81f40c7…` came to exist. `docs/**` is `PROHIBITED_PATHS`; this lane read
F-55 and wrote nothing.

R4 stays **re-opened**: revision 1 recorded it as "RESOLVED in this revision" on the strength of the
narrower reading, and revision 2 re-opened it. **It is now a named, owned, sequenced consequence
rather than a risk awaiting a judgement** — and since correction pass 3 the sequencing is **decided**,
so R4's only live content is the residual §5.2.2 names: the answer exists, the producer does not,
until slice 4.

### 4.5 Defect-origin items take a different path

The guard keys on the **work-item id prefix**, not on whether an underlying defect exists:

- `WI-feature-*` → gated
- `design-remediation-*` → gated
- `defect-*` → **not gated**

Note that a design-remediation item *is* defect-origin (`design-remediation-DEF-x`), so "has a
defect" is the wrong discriminator and would silently exempt it. The prefix is the discriminator.

Why defect-origin is exempt: a `defect-*` item has already been triaged by `sched-triage`, and
`agentCompleted -> implementationReady` (`:340`) — the one caller-bearing automatic edge — serves
the OD-10 route that the operator recorded verbatim — *"After triage completes, the item goes to
implementationReady instead of waiting at a human gate"*
(`implementation_inflow.dart:406-407`). Gating it would re-open a resolved decision for the main
defect lane. HD-1's invariant names only the two intake origins, and this is exactly it.

**One caveat Revision 1 did not state and this one does:** the exemption rests on the *prefix*
test being applied by the same single writer of `workItemOrigin` on every route that carries the
guard. A guard that keys on the id prefix is only as trustworthy as the component that derives the
origin — which is R1, and which remains unmitigated until sub-slice 2b's drift test exists.

---

## 5. Deliverable 1 — the QA gate evaluator

Specified in full in [`evaluator-spec.md`](./evaluator-spec.md). Summary:

- **Who populates `context['gateResults']`:** a new evaluation service that reuses
  `QAOrchestration.evaluate` **verbatim** (`qa_orchestration.dart:11-39`) rather than
  re-implementing the loop, and is called by the component that takes
  `qaInProgress -> qaPassed`.
- **From what:** the work item's `qaContractId` → `QAContractStore.readQAContract` → the
  `AgentResult`'s `structuredResult` document (`agent_result.dart:43`), plus whatever a gate's own
  `config` names.
- **At which point in the transition:** in the context map of the `qaInProgress -> qaPassed` call,
  alongside `context['qaContract']`, which the guard *also* reads
  (`guard_conditions.dart:274`). Both keys must be present; supplying one without the other
  yields a guard that fails for the wrong reason.
- **How a gate's `config` is actually read:** by key, by a per-type evaluator. The only declared
  key vocabulary in the repository is `structuredClassificationAdmitted`'s
  (`lane_g_triage_qa_contract.dart:177-187`): `sourceColumn`, `requiredFields`,
  `classificationEnum`, `statusEnum`.
- **`sourceColumn` MUST be treated as a label, never executed.** It names a table and column
  (`agent_result.structuredResultJson`), and a product manifest is operator-authored JSON
  (`apps/server/lib/src/endpoints/product_registry_endpoints.dart:470-510`). Interpolating it
  into a query would make an operator-supplied string a SQL surface. The evaluator reads through
  the store's typed reader and uses `sourceColumn` only to populate the evidence row's
  `artifactRef`.
- **Named code, or must be built:** it **must be built**, and the insertion points are named.

**The requirement that is not optional:** §2.2's finding means `_validateEvidence` must be
replaced with real, content-reading validation *before* any wiring lands. `evaluator-spec.md` §5
specifies that as a hard gate on the wiring slice, with the non-vacuity test that would catch a
regression of it.

---

## 6. Deliverable 4 — what must exist before B1's consumer problem is solvable

The brief's M1–M4 backlog, each item now carrying **the specific artifact, where it belongs, and
which gate it would justify** — so the next lane scopes rather than re-derives.

| # | Missing artifact | Where it belongs | What it produces | Gate it would justify |
|---|---|---|---|---|
| **M5** | **A design-lane producer** that writes a `DesignRevision` and an independent `DesignReviewResult`, advancing `status` to `approved` | `apps/server/lib` — a lane service beside `lane_e_design_remediation_work_item.dart`, using `designRevisionDefinition`/`designReviewDefinition` (`scheduler.dart:3255-3280`) and the existing `PostgresDesignGovernanceStore` | The rows `readApprovedDesignRevisionForWorkItem` looks for | **Satisfies the deliverable-2 gate.** Nothing else does. |
| **M6** | **A `sched-design` `Scheduler`** | `apps/server/lib/server.dart`, beside `:475`, `:523`, `:706` | Dispatch for `designRevisionDefinition` and `designReviewDefinition` | Prerequisite of M5. Without it the design lane cannot run at all (§4.1, Fact 1). |
| **M7** | **An edge from a design state to `implementationReady`** | `packages/workflow_engine/lib/src/transitions/work_item_transitions.dart` | The connection between the design lane and the implementation lane (§4.1, Fact 2) | Without it, an approved design routes to **triage**, not implementation. M5 alone would feed a loop. |
| **M8** | **A `JobDefinition` for feature intake** with an `entryStates` set that is not `{planned}`/`{featureIntakeParked}` | `packages/scheduler/lib/src/` | A real run to write a result about | Any feature-intake gate. Until it exists there is no execution. |
| **M9** | **An `AgentRole` per path** | `packages/platform_contracts/lib/src/enums/agent_role.dart:1-13` | `metadata.requiredRole`, which is how a reader tells whose output a contract governs (`lane_g_triage_qa_contract.dart:151`) | Metadata honesty. There is nothing truthful to put today. |
| **M10** | **A result type + parser + instruction per path** | `platform_contracts` + `apps/server/lib/src/` — the analogue of `TriageResult` / `_parseTriageResult` / `triageDefectInstruction` | The consumer that would justify `config.requiredFields` | **The load-bearing one for design remediation** — §3.3 establishes the shape, so only the *type* is missing. B1 is unresolvable without it on either path. |
| **M11** | **A real structural evaluator** for `triage-classification-structure` | `packages/qa_orchestration/lib/src/gates/` — `GateEvaluator` implemented **directly**, not via `GateEvaluatorImpl` | A gate that actually reads `structuredResult` | Makes the *existing* triage contract enforceable — a prerequisite for any new contract meaning anything |
| **M12** | **A `JobDefinition` for design remediation** — **restored; it had no successor** | `packages/scheduler/lib/src/` | A run whose instruction and result type are design remediation's rather than triage's | Any design-remediation gate. Carried forward from the brief's **M2**, which the independent review found had **no successor** in the M5–M11 table (MEDIUM finding M1). Revision 1 claimed M1–M4 were "carried forward as M8–M10"; that was incomplete — brief M2 (this row) was dropped. |

**M12 is not the same artifact as M10 and M8.** The brief's M2 was *"A `JobDefinition` for design
remediation, likewise"* (`design-brief.md:317`), with the note that `designRevisionDefinition`
(`scheduler.dart:3262`) dispatches from `{designRequired, designRejected}` — **not `planned`** — so
it cannot serve the path. M10 supplies the instruction/type/parser; M12 supplies the dispatch. The
design-remediation path needs **both**, and until it has both, `planned` remains the only thing
dispatching it and that is triage.

**`M10` does not subsume `M12`, and this revision says so explicitly** rather than letting the
earlier "carried forward as M8–M10" claim stand, because the independent review's finding was
precisely that a dropped artifact had been papered over with a sentence asserting nothing was
dropped.

**M11 is the one that is unblocked today.** It needs no producer, no role, no scheduler, no
human decision, and no schema change. It needs a `GateEvaluator` that reads four keys. It should
be the first slice (§8).

**Ordering constraint the brief did not state, and which M5/M7 make load-bearing:** the design
lane must not be built without M7. A `DesignRevision` reaching `status: approved` while the work
item's state routes to triage would create a loop — `planned -> designNotRequired ->
agentExecuting -> agentCompleted -> implementationReady` with a design lane feeding the front of
it. M6 and M5 without M7 is worse than not building them.

---

## 7. The honest word: `DECLARED`, not `PASSING`

The mandate is explicit and this revision honours it verbatim:

> Even after this revision, **no gate in this repository is enforced** until the evaluator is
> built. A contract that exists and is not evaluated is **`DECLARED`, not `PASSING`**.

Three levels, stated separately because they are at different states:

| Artifact | State today | State after the evaluator slice |
|---|---|---|
| `qa-triage-*` contract (3 gates) | `DECLARED` — declared at `lane_g_triage_qa_contract.dart:119-159`, `evaluatorRuntime: 'absent'` (`:156`), never evaluated | `DECLARED` until M11 lands for `triage-classification-structure`; the other two types still have no evaluator |
| `qa-product-*` contract (product-declared gates) | `DECLARED` — same, `product_qa_contract.dart:156` | `DECLARED` unless the product declares a type an evaluator exists for |
| The **path-specific** contract for feature intake | **DOES NOT EXIST** | Cannot exist until M8 + M9 + M10 — there is no execution to describe (§3.1) |
| The **path-specific** contract for design remediation | **DOES NOT EXIST** | Cannot exist until **M10 + M12** — and note the shape *is* establishable, so only the type is missing (§3.3) |
| A **product-declared** `qa-contract` row on either path | `DECLARED` — exists today and always did: `control_plane_service.dart:918-950` stamps it at `:940`; `lane_e_design_remediation_work_item.dart:283` stamps it at `:294` | unchanged. Carries the product manifest's declaration, not a path-specific obligation (`design-brief.md` §10) |

**And one level is worse than `DECLARED`:** the four *registered* gate types — `static-analysis`,
`unit-tests`, `security-scan`, `performance` — are, if ever invoked, **fabricated `PASSING`**
(§2.2). They are currently unreachable, which is the only reason this is latent. **They must be
treated as not implemented, and `gateRegistry` must not be trusted as a list of working gates.**

---

## 8. Implementation sequence — reviewable slices, each independently mergeable

> **H-2, CORRECTED IN PASS 4 — the heading promises something slice 1 no longer delivers, and the
> promise is narrowed here rather than left standing.** **Sub-slice 1b folds into 2b**: it widened
> the park helper's option list, and **2b is what creates the park helper**, so 1b either landed after
> its own prerequisite or edited a function that did not exist. **Slice 1 is therefore 1a + 1c**, and
> both are landable. **What is retracted is the implication that every sub-slice is separately
> landable**; what is kept is that every *slice* is. The promised property the review asked about —
> that G17 can ship with slice 1 — **still holds, and it now holds more precisely: G17(a) and G17b
> ship with slice 1, and G17(b)/G17(c) ship with the sub-slices that give them a subject.**

Ordered by dependency. **Slice 0 is a decision, not a code change, and it is not this lane's.**

> ### ⚠ THE ORDER CHANGED IN CORRECTION PASS 3, AND THE NUMBERING WITH IT
>
> `.decisions/b81f40c7-2a96-4e38-bd51-6c07e9f3a824.yaml` (`HUMAN_SURFACE_FIRST`, operator,
> 2026-10-17): *"Slice ordering REVERSES: the human surface becomes the FIRST slice, the gate
> follows."* **Slice 1 below is now that human surface; the gate is slice 2.**
>
> The previous pass routed it as "1.5, after the gate" and flagged that as its own judgement against
> the decision's word "FIRST". **The independent review agreed with the merits and held the ordering
> was the operator's call** — *"a flagged judgement is not a discharged obligation."* **The override
> is on AUTHORITY, not reasoning**, and `design-review-gate.md` §0.2 keeps the merits argument in full
> so a reader can see which axis it was on. **A reviewer holding the previous review should use the
> crosswalk in `design-review-gate.md` §0.2:** 1.5→1 (the human surface), 1→2 (the gate, sub-slices
> 2a–2d), 2→3 (the evaluator), 3→4 (the design lane), 4→5 (the contracts). **No claim changed; the
> numbers moved.**

**0. (Manager-owned) Record the dead ends as live, and record what slice 2 costs.** §2.1 and §2.1a
are not in `FOLLOW_UPS.md` and they affect every implementation in the platform, not these two paths.
**`reviewApproved` is the corrected location, not `qaInProgress`** (§2.1), and the second finding is
a declared edge with no caller. Three entries belong in §13 next to F-47:

- the `reviewApproved` dead end, with `qaInProgress` named as a second unreachable state;
- `agentFailed -> implementationReady` as a callerless edge (the pattern, §2.1a);
- **the operational cost of slice 2:** under `.decisions/7f3e2a95…` (**Reading B — decided**), both
  intake paths become unable to reach an implementer until slice 4 lands, and a human's options at
  the park are re-triage, re-plan, stop — **plus, once slice 1 lands, "do the design review", which
  moves the item to `designApproved` and, on its own, still produces nothing.** This is the
  consequence an operator must be told about before slice 2 ships, not after. `docs/**` is
  `PROHIBITED_PATHS` for this lane and was not written.
- **F-55**, the park's human-surface gap — **RECORDED, and it now exists.** The operator's decision
  named it (`.decisions/7f3e2a95…`: *"see FOLLOW_UPS F-55, which records why the park's human
  surface currently offers no 'do the design review' answer"*) and it was absent for the whole of the
  previous pass; **`0bfb6fb` wrote it, at `FOLLOW_UPS.md` §16, together with F-56.** It is **slice 1**
  (`design-review-gate.md` §6, §5.2.2). **This lane read F-55 and F-56 and wrote neither.**

**1. The park's human surface — `design-review-gate.md` §6 ("1 — the park's human surface"), §5.2.2.**
**NEW as the first slice, and the substantive change of this pass.** The decision ordered it first and
left the mechanism here; **`.decisions/3e5a7c26-4b19-4f83-a0d7-6c29b8f1e540.yaml` has now decided the
one thing the mechanism could have gone either way on — a NEW `HumanDecisionType`, with `escalation`
and `designApproval` both ruled out** (`NEW_HUMAN_DECISION_TYPE`, operator, 2026-10-17T14:40:00Z).
Sub-slices:

- **1a — the type, every arm, every registration site.** `HumanDecisionType.designReviewRequest('design_review_request')`
  in `packages/platform_contracts/lib/src/enums/human_decision.dart:1-20`; **two `targetFor` arms** in
  `human_decision_routing.dart:88-138` — `approve → designApproved` and `rework → planning`; **and
  TWO `blockingHumanDecisionResolved` whitelist admissions in `work_item_transitions.dart:75-80` and
  `:643-648`**, which the previous pass listed conditionally and wrongly said were not needed.
  **AND, PASS 5, A NEW `HumanDecisionChoice('re_triage')` for the restored fourth answer, a THIRD
  whitelist admission at `:528-546` (`designNotRequired`, which is the only one of the park's three
  edges carrying an escalation-index bound), and a FOURTH file — `decision_choice.dart` — because a
  CHOICE has a presentation registration that a type does not.**
  **`escalationTargetFor` gets NO arm for any of the four answers, and MUST NOT get one for the
  `rework` answer** — `:196-199` protects `approve`, `cancel` **and `reTriage`**; `rework` is protected
  only by `_ => null` at `:214`, and completing the "lockstep" would start escalation accounting
  silently on a re-plan. G17b pins all four. Full arm table, the short-circuit table showing which of
  the four are protected and which are not, the scope derivation that keeps the new value off every
  other decision's menu, and the forcing argument for why the park's whole menu must live on the new
  type: `design-review-gate.md` §6 1a. G16 is pinned to the four `(optionId, label, choice)` triples and
  **G18** asserts the count itself.
- **1b — FOLDED INTO 2b (H-2).** The park's option list is a property of the **raising call site**,
  and 2b creates it. Specified inside sub-slice 2b.
- **1c — the assertions: G17(a), G17(b), G17(c) and G17b.** **G17 was rewritten against the real data
  model in pass 4** — the previous form asked a parsed `HumanDecisionOption` list for a `decisionType`
  field that does not exist, and asserted nothing about the edge whitelist that decides whether the
  arm moves the item at all. See `design-review-gate.md` §5.2.2.

**What this slice does NOT do: it does not make the park resolvable.** Answering the new question
routes the item to `designApproved`, and nothing writes an approved `design_revision` until slice 4
(M5–M7). **That is R4, and it is the cost of the reversal this lane argued against and lost**
(`design-review-gate.md` §0.2).

**2. The design-review gate — `design-review-gate.md` §6.** Self-contained, no dependency on the
evaluator, no dependency on the contracts. Sub-slices **2a** (the guard on the two caller-bearing
edges — **both in one commit**, `design-review-gate.md` §5.3, now required by
`.decisions/7f3e2a95…` rather than merely recommended), **2b** (the single context writer —
**including `packages/scheduler/lib/src/scheduler.dart`, whose `const` context at `:1746` must
become a computed map** — the single park helper performing *both* steps of §5.1.1a **in the order
§5.1.1a shows is load-bearing**, and the `DesignGovernanceStore` wiring in the composition root),
**2c** (the edge pins `implementation_ready_edge_test.dart` already asserts by name, extended for
G5′/G6), **2d** (the park: one new state, three edges, G7–G10/G12–**G16**). **This is the only slice
in this revision that changes what the platform may dispatch**, and it is a strict reduction —
**unattended *and* attended** — which is the reading the operator decided, not one this design asks
a reviewer to judge.

**Sequencing constraints, and all three are load-bearing.** **Across slices:** slice 1 precedes
slice 2 — `.decisions/b81f40c7…`, asserted by **G17**. **Inside slice 2:** **2d must not lag.** A
route-1 guard without the park is the BLOCKING finding reproduced in code — a refusal that goes
nowhere, tested green by G1/G2. **And a park taken by `transition` rather than `requestHumanDecision`
is the BLOCKING finding of the correction pass reproduced in code** — a refusal that goes somewhere
with no reason and nothing for an operator to answer, and G1/G2/G7 all pass over it. **G14 is the
assertion that distinguishes them, and §5.1.1a now states that the two steps cannot be collapsed into
one call** — which is the failure mode a "simpler" implementation would choose. **Inside slice 2b:**
the park helper performs **both** steps, and the route-3 catch discriminates
`WorkflowTransitionRejectedException` (§5.1.2).

**3. The evaluator — `evaluator-spec.md` §5. Slice 3a de-registers the four fabricated evaluators**
(MEDIUM finding M3: replacing `_validateEvidence` is **insufficient**, because a predicate reading
`QAEvidence.content` still reads hardcoded collector output and stays a constant) and adds the
non-vacuity test that fails while the registry presents an evaluator whose evidence is not a function
of the work item. **Nothing may be wired before 3a lands.** 3b implements
`triage-classification-structure` against `GateEvaluator` directly. **3c is WIDENED (HIGH finding
H2): it must add both the `reviewApproved -> qaInProgress` caller *and* the `qaInProgress -> qaPassed`
drain with the `qa_contract` context key** — Revision 1's 3c had nothing to drain, because the item
stops at `reviewApproved`. **Slice 3 is what makes "enforced" mean anything** — and until 3c lands,
the §2.1 dead end is still a dead end, one hop earlier than Revision 1 said.

**4. M6 + M7 + M5 — the design lane**, in that order, and only after slice 2 has landed so the
gate is already in place to catch a producer that runs before the edge exists. §6's ordering
constraint applies: **M6/M5 without M7 is worse than not building them.**

> #### The "1.5" that was, and where it went
>
> **The previous pass inserted a "slice 1.5 — owned by the Manager" here**, on the argument that
> closing the park's dead end needs a new `HumanDecisionType` plus a routing arm
> (`human_decision_routing.dart:151-162`: `targetFor` and `escalationTargetFor` must move in lockstep
> or escalation accounting *"silently stops"* advancing), which is architecture and therefore
> `AGENTS.md`-reserved to the human — **and that slice 1 should land first**, because a strict
> reduction in dispatch that leaves items visible with a real reason beats a `HumanDecisionType` no
> guard consumes.
>
> **One of those premises is now known to be overstated, and it is corrected where it is specified
> rather than here** (`design-review-gate.md` §6, 1a): the lockstep rule is **conditional on the answer
> being a `reject` or a `rework`**. `escalationTargetFor` returns `null` for any other choice
> (`:196-199`), so an `approve` answer carries **no** lockstep obligation and increments no escalation
> index. G17b pins that. **The architecture claim stands** — the `HumanDecisionType` itself is
> `AGENTS.md`-reserved — and **the merits argument is unchanged**; only one supporting detail was
> wrong, and it was wrong in the direction that would have cost an implementer an unnecessary arm.
>
> **That is now slice 1, and the ordering is decided.** `.decisions/b81f40c7…` reversed it on
> **authority**: the review agreed with the merits and held that deferring a Level 3 operator
> instruction is not the lane's call. **The merits argument is preserved, not deleted**
> (`design-review-gate.md` §0.2), together with the cost the reversal carries — a decision type and a
> routing arm that **no guard consumes** for the slice-1→slice-2 window. **The operator has accepted
> that cost knowingly**; §5.2.2's final row names the residual that survives it (the answer exists,
> the producer does not, until slice 4).

**5. M8 + M9 + M10 (feature intake) and M12 + M10 (design remediation) — a real run per path**,
then, and only then, the two path-specific contracts. **This slice is what makes §4.4's reading
load-bearing rather than academic:** a real intake run produces a commit, which makes
`(engineeringReview, rework) -> implementationReady` (`human_decision_routing.dart:103-104`) a live
path for an intake origin, and an unguarded route 3 would be a live bypass of HD-1's undelegated
clause — which `.decisions/7f3e2a95…` has now forbidden.
**What each path's contract must carry, and by what rules:** each
gate's `requiredFields` justified by a named line in the new parser; `evidenceTypes` carried in
`config['evidenceTypes']` as `List<String>` or provisioning throws; `optionalGateFailuresAllowed`
equal to the contract's own optional-gate count (the *derivation* at `product_qa_contract.dart:128-141`,
not the triage numeral); and `'evaluatorRuntime': 'absent'` until slice 3c is in place and the
gate's type has an evaluator.

---

## 9. Traceability

### 9.1 Requirements covered

| Requirement | Where |
|---|---|
| **1. The QA gate evaluator — specified, not deferred.** Who populates `context['gateResults']`, from what, at which point in the transition, how `config` is read | [`evaluator-spec.md`](./evaluator-spec.md) §1-§4; summary §5 |
| **2. The design-review gate under HD-1** — where in the graph, which actor, what for an item that never gets one, defect-origin same path or not, invariant enforced | [`design-review-gate.md`](./design-review-gate.md); summary §4. All five sub-questions answered individually in §4.2-§4.4 |
| **3. The two contracts** | §3 — declined on evidence, as the mandate authorised. Evidence for the refusal in §3.1-§3.3 |
| **4. What must exist before B1 is solvable** — result type, parser, instruction, `AgentRole` variants, and one `JobDefinition` per path; name each and where | §6, **M5–M12**, each with location and the gate it would justify. M12 restored (MEDIUM finding M1) |
| **5. Traceability, risks, non-goals, implementation sequence in reviewable slices** | §7, §9, §10, §11, §8 |
| **Use the word `DECLARED`, not `PASSING`** | §7, stated three ways; `evaluator-spec.md` §6 |
| **Every `file:line` verified against the tree** | Verified individually at `e3634a0` by Revision 1. **Its** corrections of the inherited inputs were three of the resume spec (`:942`, `:943`, `:946`) and two of the predecessor brief (`:944`, `:945`) — **the previous pass's §9.1 stated these counts swapped; corrected at §12.1 PASS3-5, where the full ledger is **GENERATED — see §16(11) for the derivation command; do not restate it here.** As of this pass it is thirteen pass-2 rows, eight pass-3 rows, nine pass-4 rows and seven pass-5 rows. **PASS 5 CORRECTS THE LEDGER COUNT ITSELF, and this is the same count rot §12.3's PASS5-2 records: PASS3-5 wrote "eleven pass-2 rows plus six pass-3 rows" into this cell, and both numbers were correct WHEN WRITTEN and were invalidated by later passes appending rows to those registers.** A traceability cell that counts the register it points at is a count like any other, and it rots the same way.** |

### 9.2 Requirements gaps

| Gap | Why it is a gap |
|---|---|
| Two authored contracts | §3. There is no run for feature intake and no consumer for design remediation. B1 is unresolvable at `e3634a0`. |
| Concrete `requiredFields` for either path | Follows from the above. M10 is the precondition. |
| A design-review actor other than a human | §4.1 Fact 1. No scheduler dispatches the design lane, so an agent design review cannot be specified honestly today. **The design deliberately chooses the human and says so.** |
| An executable gate on the *QA* path | Follows from §2.1 and §2.2. Slices 3a-3c. |

### 9.3 Out of scope, deliberately

- **`qaInProgress` strandedness (§2.1)** — reported in full, **not designed here**. It is the main
  implementation lane, not these two paths, and fixing it is slice 3c. Designing it in a brief
  whose subject is intake would be scope theft, and the Manager owns `FOLLOW_UPS.md`.
- **The four fabricated evaluators (§2.2)** — specified as a *hard gate on* the wiring slice, not
  as a rewrite. Rewriting four implementation gates is `AUTOMATION_OPPORTUNITY` work, independently
  reviewable, and this lane has no authority to decide what a real `static-analysis` gate should
  assert.
- **M1-M4 as the brief numbered them** — carried forward as **M8–M10 and M12**, re-numbered so the
  design lane's M5-M7 do not collide, and each given a gate justification. **Corrected:** Revision 1
  wrote "carried forward as M8–M10", which silently dropped the brief's **M2** (a design-remediation
  `JobDefinition`). MEDIUM finding M1. Restored as M12; §6 states that M10 does not subsume it.
- **F-43** (`WI-feature-*` has no replay hook) — unchanged, deliberately not bundled.

---

## 10. Risks

| # | Risk | Likelihood | Severity | Mitigation / status |
|---|---|---|---|---|
| **R1** | The design-review guard is treated as satisfied because `context['approvedDesignRevisionId']` is supplied by a caller that did not read the store | MEDIUM | **HIGH** | The guard cannot verify its own input — `DurableWorkflowEngine.transition` passes `context` to the policy (`durable_workflow_engine.dart:173`) and persists **no guard-supplied key** (it reads back only `humanDecision` `:216` and `blockingReason` `:223`, both its own). This is the platform's **existing** enforcement model (`qaContractExists` at `guard_conditions.dart:247` is the same shape, and the coordinator reads the store at `execution_coordinator.dart:1072`). Stated as a property of the design, not hidden: a context guard is as strong as the component that fills it. `design-review-gate.md` §4.4 names that component and requires it to be the only writer. **Mitigation made executable (MEDIUM finding M4):** Revision 1's mitigation was "require it to be the only writer", which is not a test and therefore not a mitigation — G1–G6 test the *guard*, never the *supplier*, so every one of them passes with a lying writer. **The required artifact is a drift test naming the single writer of `workItemOrigin` and `approvedDesignRevisionId`**: assert that exactly one production call site constructs the map containing those two keys, and that it derives the second from `readApprovedDesignRevisionForWorkItem`. Named in sub-slice 2b. Until it lands, R1's rating stands **unmitigated**, and this table says so rather than implying otherwise. |
| **R2** | The evaluator is wired before `_validateEvidence` is replaced | MEDIUM | **CRITICAL** | §2.2. `evaluator-spec.md` §5 makes this a hard ordering constraint with a named non-vacuity test. This is the one ordering in this revision that must not be violated. |
| **R3** | The design-review gate strands an intake item silently | **Was LOW — was wrong** | **CRITICAL** | **Revision 1's mitigation was void (the BLOCKING finding of revision 2's review) and revision 2's own mitigation was void too (the BLOCKING finding of this correction).** Revision 1 claimed a refused item "stays at `agentCompleted`… which fails closed into a blocking human decision"; `engineeringReviewMissingArtifact` **stands down** for a no-commit producer (`engineering_review_gate.dart:2860-2871`, `:2210-2228`; `server.dart:1416-1421`). Revision 2 replaced that with a park — and then asserted, citing `durable_workflow_engine.dart:222-225`, that the park "carries a durable reason". **That range writes `blockingReason: null` for every non-`waitingForHumanDecision` target**, so revision 2's park erased its own reason and **B1 survived under a new state name**. **Mitigated in this revision** by: the park (`design-review-gate.md` §5.1.1); **the two-step exit whose second step is `DurableWorkflowEngine.requestHumanDecision`, which writes `blockingHumanDecisionId` and `blockingReason` itself (`:651-653`)** (§5.1.1a); and the assertions **G7** (leaves `agentCompleted` in one tick), **G14** (non-null non-default `blockingReason`), **G15** (non-null resolvable decision id), plus G9 (idempotence), G10 (no bypass loop), G16 (exact option set). **The rating stays CRITICAL**: a silent, indefinitely-repeating dead end with a green suite over it is the worst combination in this table — **and it has now happened twice in this design, the second time inside the fix for the first.** The reason it happened twice is that G7 asked whether the item *moved* and nothing asked what it *carried*. **G14 exists because of that, and a reviewer should treat any future property of the park asserted without an assertion as the same defect a third time.** |
| **R3b** | The park is implemented by `transition` rather than `requestHumanDecision`, and ships the reason-less park | MEDIUM | **CRITICAL** | **Recorded as a separate row because it is a distinct implementation error with a distinct fix**, and folding it into R3 would hide it. The failure is silent and passes G1/G2/G7/G9. **Mitigation:** sub-slice 2b names the park helper as performing *both* steps and says in terms that a step-1-only helper "is the B-1 defect and must not be written"; **G14/G15/G16 fail if it is**. |
| **R4** | A human cannot move an intake item to an implementer at all, and the answer that would let them produce the design review it is waiting for does not exist | HIGH | HIGH | **Re-opened twice; then DECIDED on both content and order.** Revision 1 recorded this as "RESOLVED in this revision" on the strength of the narrower reading — wrong. Revision 2 specified the guard ON the human edge and marked the reading for judgement. **`.decisions/7f3e2a95…` decided Reading B**, so the price is fixed and accepted: nothing writes an approved `design_revision` until slice 4, so a human's options at the park are re-triage, re-plan or stop, **and none of the three is the design review the item is waiting for**. **`.decisions/b81f40c7…` has now ALSO decided the order** — the human surface is built FIRST, and this lane's contrary ordering is overridden **on authority, not reasoning** (`design-review-gate.md` §0.2). **Mitigation as specified:** the park's option list is explicit (`requestHumanDecision`'s `options`) and asserted by **G16**, now pinned to the *set* rather than to the enum so it does not fail the moment slice 1 lands; the gap is **slice 1** (`design-review-gate.md` §6, §5.2.2); and the invariant that reversals exists to enforce — *no item may be parked at `designReviewRequired` before the decision raised there offers a "do the design review" answer* — is **asserted by G17**, not by convention. `FOLLOW_UPS` **F-55 now exists** (`0bfb6fb`) and records the gap in the Manager's own words. **The honest residual, unchanged by the reversal:** the answer routes the item to `designApproved` and **nothing produces an approved revision there until slice 4 (M5–M7)**, so for the whole of slices 1–4 the operator has an answer that changes the item's state and still cannot unblock it. Between the gate and slice 4, "stop" is the only park answer that terminates. **This lane's merits argument — that slice 1 should land first — is preserved in `design-review-gate.md` §0.2 and was overridden.** |
| **R5** | `qaInProgress` dead end (§2.1) goes unrecorded | MEDIUM | **HIGH** | §9.3. Reported, not designed. Slice 0 puts it in front of the Manager, who owns `FOLLOW_UPS.md`. |
| **R6** | The two contracts are authored anyway "to close the ticket" | MEDIUM | HIGH | §3. This revision is the obstacle, and it states exactly what each missing artifact would justify — so the next lane has a spec, not a prohibition. |
| **R7** | A future implementer routes `designApproved -> implementationReady` without M7, creating a loop | MEDIUM | HIGH | §6 ordering constraint and §4.1 Fact 2, which names the trap explicitly: `designApproved` is in `triageDefectDefinition.entryStates`. |
| **R8** | `sourceColumn` is interpolated into SQL | LOW | **CRITICAL** | `evaluator-spec.md` §3.4. It is a label; the evaluator reads through the typed store. Operator-authored manifest JSON is the threat model. |
| **R9** | `M6`/`M5` land without `M7` | MEDIUM | MEDIUM | §6 and §8 slice 4 order. Both M5 and M7 are in one slice. |
| **R10** | A reviewer reads `gateRegistry` and believes four gates work | HIGH | MEDIUM | §7's third row states it plainly, and `evaluator-spec.md` §5.1 requires the registry to stop presenting them as working. Slice 3a de-registers them (`evaluator-spec.md` §5.2 option 2, the only safe one). |
| **R11** | A future caller appears for `agentFailed -> implementationReady` and the guard is absent there | MEDIUM | **HIGH** | §2.1a. The edge is callerless today, so a guard there would be inert; adding one now would look like coverage and be nothing. Pinned by **G11**, which fails if the guard is absent from `:265-267` **while** a production caller of that edge exists — so the rule fires when the risk becomes real, and not before. |
| **R12** | Slice 2's route-1 and route-3 guards land in separate commits | MEDIUM | **HIGH** | `design-review-gate.md` §5.3. Between them, the park exists and the human route is unguarded — and slices 3c and 5 both make that window worth exploiting. Stated as an in-slice ordering constraint: **2a adds both in one commit**, and a reviewer seeing them split should treat it as a finding. |
| **R13** | Slice 1's human surface lands **without** an assertion tying it to the park, and the ordering the operator decided is preserved only in prose | MEDIUM | **HIGH** | **NEW in correction pass 3, and it is the risk the reversal creates.** `.decisions/b81f40c7…` orders the human surface first and states an `invariant` that "must be asserted, not assumed". **Asserted: G17** — **REWRITTEN IN PASS 4 as G17(a)/(b)/(c)**, because the original form asserted an iff over a parsed option list that carries no `decisionType` (`human_decision.dart:156-159`) and said nothing about `blockingHumanDecisionResolved`, which is the guard that decides whether the arm moves the item (`guard_conditions.dart:425-428`). G17(a) = the arm exists **and** the target edge admits the pair; G17(b) = the park may not acquire an in-edge while G17(a) is red (**this is the checkable ordering**); G17(c) = the raising call site actually offers it. **Without them the reversal would be exactly the defect this design has produced twice**: a property asserted in a decision and in three artifacts, with nothing that fails when it is absent. **The cost the reversal does carry** — a decision type, two routing arms, two edge-whitelist admissions and one offered option that **no guard consumes**, for the slice-1→slice-2 window — is stated in `design-review-gate.md` §0.2 and §5.2.2 rather than argued away. **Pass 4 notes that the cost GREW**: the previous pass's residue was "a type and an arm"; the decided shape adds two registrations, so the unconsumed surface is larger and more capable of being mistaken for working coverage. |
| **R14** | **The operator's re-triage answer routes to a visible non-terminating cycle, and nothing bounds how many times they may choose it** | **MEDIUM** | **MEDIUM** | **NEW in correction pass 5, and it is a judgement this lane made and flagged rather than escalated.** `.decisions/5a90c1d3…` restores `re-triage`; `design-review-gate.md` §6 1a routes it to `designNotRequired`, which §5.2.1 itself calls *"a cycle — visible, durable, and dispatching nothing."* `(waitingForHumanDecision, designNotRequired)` carries `escalationIndexWithinLimitForDecisionTypes({engineeringReview, humanQaApproval})` (`work_item_transitions.dart:559-563`) and **`designReviewRequest` is deliberately NOT added** — four other types already are not, and `:553-558` states the rule: *"inventing a bound here would be new policy rather than a lockstep move."* **Why that is defensible:** every traversal requires a human-resolved decision (`:517-522`), so nothing is unattended and nothing dead-ends silently; and the operator now gets that loop **under a name that says so**, which is what the decision bought. **Why it is still flagged:** `reTriage` is an **operator-invoked** loop by construction, unlike `escalation` (a one-off provider failure), so the precedent is weaker than the rule-of-three makes it look. **A ceiling on re-triage — "how many times may an operator re-triage an item?" — is product policy and is not this lane's to set.** Mitigated by G18 (the answer cannot be dropped without a decision), by G16 (its target is checked against the no-`implementationReady` property, which it passes), and by §6 2b requiring the option to carry a `description`. **Not mitigated: repetition count.** Recorded for the operator; §16(2)(c) asks a reviewer to overturn it if they disagree. |

---

## 11. Non-goals

- **Not** a change to `GuardConditions.qaContractExists()` — untouched, and it should stay
  untouched (`work_item_transitions.dart:126-134` explains why its absence on the dispatch edge is
  load-bearing).
- **Not** a change to `work_item_transitions.dart` beyond **adding one guard to two existing
  edges**, plus the three park rows of §5.1.1. Deliberately: the design lane's own §4.1 Fact 2
  finding is that adding edges is how this graph gets disconnected — which is why the park's
  out-edge is a *named existing component taking an existing shape* rather than a new route to
  `waitingForHumanDecision` chosen freely.
- **Not** a change to `HumanDecisionRouting` **in the gate slice** — **still exactly true, and pass 4
  makes it exactly true for a stronger reason than before.** No new `HumanDecisionType`, no new
  routing arm, no new decision type *in the gate slice*: slice 2's own rows add a state and three
  edges and nothing in the routing tables, because **the park's exits are `targetFor` arms that
  slice 1 already added** (`human_decision_routing.dart:121`, and the new
  `designReviewRequest` arms at §6 1a of the gate spec). §4.4 explains what that costs.
  **Recorded because it was a "first", and pass 4 removes the first:** `escalation` is raised nowhere
  in production today, and the previous pass recorded that this slice would be its first raiser —
  *"a new use of an existing type, not a new type, which is what keeps it inside this slice."*
  **`.decisions/3e5a7c26…` decides the park raises a NEW type instead, so the park is not
  `escalation`'s first raiser and `escalation` remains unraised after this design ships.**
  **The non-goal was never "this design adds no routing arm"; it was "the *gate* does not need
  one"** — still true, and now true of a design that adds a type, two arms and two edge admissions
  in a *different* slice. **Recorded here because the distinction is the entire reason the previous
  pass's unqualified sentence became a live superseded claim (see §4.2), and stating a non-goal
  without its scope is how that happened.**
  > **Correction (L-A).** This bullet also said the only production references to `escalation` are
  > *"the routing arms and the escalation-index computation (`durable_workflow_engine.dart:996`)"*.
  > **`:996` is not the escalation-index computation** — it is one line inside `_isReWorkDecision`
  > (`:987-1005`), which drives the `nextTriageAttempt` counter (`:788-792`). The escalation-index
  > predicate is **`_isEscalationTransition` (`:1007-1021`)**, which delegates to
  > `HumanDecisionRouting.routesToEscalation` (`:1016`; `human_decision_routing.dart:228-234`) and
  > therefore **never names the enum** — which is precisely why the grep finds only `:996`.
  > **The grep result was always right; the characterisation was not.** Full note, including a stale
  > citation found in production code while verifying, at `design-review-gate.md` §6 2d.
- **Not** a change to `DurableWorkflowEngine`. The park's exit uses `requestHumanDecision` **as it
  is**; nothing in `packages/workflow_store/**` is modified. **That matters:** it is why the durable
  reason survives at all. `transition` writes `blockingReason: null` and
  `blockingHumanDecisionId: null` for any target that is not `waitingForHumanDecision`
  (`durable_workflow_engine.dart:215-225`), and `requestHumanDecision` writes both itself
  (`:651-653`). **The correct fix was to use the API that already does the right thing, not to add
  one that does not.**
- ~~**Not** a new `WorkItemState`.~~ **WITHDRAWN.** The premise was that one guard on
  an existing edge "cannot create a dead end, because a refused guard leaves the item exactly where
  it was, in a state that already has exits" (`design-review-gate.md` §3.4). **`agentCompleted` does
  not have a usable exit for these origins** — the one consumer of that state stands down (§4.3) —
  so the premise was false and the non-goal was the thing that hid the BLOCKING finding. One state
  is now specified, with three edges, modelled on `featureIntakeParked` (`:31-53`). **Cost of the
  reversal, stated:** `workflow_state.dart` gains a variant and four registration entries, and the
  transition table gains three rows. That is a graph change inside a design that is otherwise two
  guard rows, and a reviewer who thinks that is too much should read `design-review-gate.md`
  §5.1.1b — **because the alternative was tested against the tree and it is worse than a refusal
  with nowhere to go: it is a refusal with nowhere to go *and* nothing for the operator to answer.*
- ~~**Not** a new edge to `waitingForHumanDecision`.~~ **WITHDRAWN with the above**: the park's only
  way out is that edge, on the `:51-53` shape.
- ~~**Not** the dead end itself.~~ **SUPERSEDED BY CORRECTION PASS 3, and the supersession is
  recorded rather than quietly applied.** This non-goal said the park offers re-triage / re-plan /
  stop and **no "do the design review"**, and that closing the gap *"needs a new `HumanDecisionType`
  plus a routing arm, which is slice 1.5 and the Manager's."*
  **Both halves are now false as a statement of scope:**
  1. **The gap is closed by a specified slice — slice 1 — not handed to the Manager.**
     `design-review-gate.md` §6 specifies 1a (the type, **the new choice's enum value**, its four
     arms and its **four** registration sites — three `blockingHumanDecisionResolved` whitelists plus
     the `decision_choice.dart` presentation registration)
     and 1c (**G17(a)/(b)/(c), G17b, and G18**), and the four-option list inside 2b. ~~and §5.2.2 names the shape of the
     answer: `designApproval`'s `(approve)` arm already targets `designApproved`
     (`human_decision_routing.dart:88-138`), so what is missing is a decision of that type *reachable
     from the park*, not necessarily a new enum value.~~ **SUPERSEDED AGAIN IN PASS 4, and this is
     the second supersession of this bullet:** that sentence named the SHAPE, and the shape is now
     **decided** — `.decisions/3e5a7c26-4b19-4f83-a0d7-6c29b8f1e540.yaml` requires a **new**
     `HumanDecisionType` and rules `designApproval` out, precisely because reusing it would re-point
     the park's other answers (`reject` → `designRejected`, `rework` → `designInReview`, the latter a
     state in no `entryStates`). **A supersession inside an already-superseded bullet is recorded
     here rather than collapsed, because collapsing it would make it look as though the shape had
     been settled in pass 3 — which is the exact defect this whole register exists to prevent.**
  2. **The ordering reversed** — `.decisions/b81f40c7…` puts that slice **first**, overriding the
     previous pass's "1.5, after the gate" on **authority, not reasoning**
     (`design-review-gate.md` §0.2 keeps the merits argument).
  **What is still a non-goal, stated precisely so the withdrawal is not over-read: producing an
  approved `design_revision` remains out of scope for slice 1.** Answering the new question routes the
  item to `designApproved`, and nothing writes that row until slice 4 (M5–M7). **The answer exists;
  the producer does not.** That residual is R4, and it is the one respect in which this lane's
  merits argument survives into the implemented order.
- **Not** a QA-contract evaluator runtime implementation. Specified, not built — this lane does
  not implement production code. §5 names the insertion points and the ordering constraint.
- **Not** the rewrite of the four fabricated evaluators. Specified as a hard prerequisite (§2.2).
- **Not** a decision on slice 0 (§9.3). The Manager owns it.
- **Not** an edit to `docs/engineering/FOLLOW_UPS.md` — **including F-55 and F-56**, which now exist
  (`0bfb6fb`, `FOLLOW_UPS.md` §16) and which the operator's decision names. **Correction pass 3 read
  both and wrote neither.** The previous pass cited F-55 as an existing artifact in six places while
  stating in four of them that it had never been written; all six now resolve, and F-55 independently
  confirms this design's gap statement (`design-review-gate.md` §5.2.2, M-A).

---

## 12. Corrections to the inputs this revision inherited

Recorded because each one changed a citation or a conclusion, and a silent correction would be
indistinguishable from an error.

| Source | Claimed | Actual at `90b6f5f` |
|---|---|---|
| **Revision 1 §2.1 (this lane's own)** | *"a work item … walks to `qaInProgress` and stops there permanently"* | **It stops at `reviewApproved`.** Nothing takes `reviewApproved -> qaInProgress`; `reviewApproved` is in no `entryStates` and no production code transitions to it. §2.1, `evaluator-spec.md` §2.1. **A live contradiction this lane asserted, not inherited.** |
| **Revision 1 §4 / deliverable-2 table (this lane's own)** | `agentFailed -> implementationReady` is an **automatic** route carrying the guard | **It has no caller.** The only `completionInflowFrom` is `{agentCompleted}` (`implement_feature.dart:117`); the inflow filters on it (`scheduler.dart:1522`). §2.1a. |
| **Revision 1 §4.3 (this lane's own)** | a refused item "stays at `agentCompleted` … `blockedArtifactMissing` → a **blocking human decision**" | **The handler stands down** (`engineering_review_gate.dart:2860-2871`). §4.3. **This was the BLOCKING finding of revision 2's review.** |
| **Revision 2 §4.3 step 3 (this lane's own)** | the park's out-edge carries a durable `blockingReason` "by" `DurableWorkflowEngine.transition` (`durable_workflow_engine.dart:222-225`) | **`transition` writes `blockingReason: null` for every target that is not `waitingForHumanDecision`** (`:222-225`), and `blockingHumanDecisionId: null` the same way (`:215-221`). The writer is **`requestHumanDecision`**, which writes both itself (`:651-653`). **This was the BLOCKING finding of this correction.** §4.3, `design-review-gate.md` §5.1.1a. |
| **Revision 2 §5.1.1 (this lane's own)** | `:34-40` of the `featureIntakeParked` comment "records this as the reason the feature park is not a silent stop" | **`:34-40` explains the way OUT of the park** — why an edge exists and where it goes. It does not mention a durable reason, and **the feature park has none**: it is reached by `transition`, which nulls `blockingReason`. **A precedent cited for a property it does not state.** `design-review-gate.md` §3.5. |
| **Revision 2 §5.1.2 (this lane's own)** | the park is taken "inside the existing per-item `try` (`scheduler.dart:1582-1599`)" | **`:1582-1599` is the `try` around the four per-item READS**, whose reason string is *"this item could not be read well enough to decide whether it should be reviewed or implemented."* The transition's `try` is `:1740-1843`; the rejection is caught at **`:1823-1833`**. Routing the park through the reads' `try` files the refusal under a reason about readability. `design-review-gate.md` §5.1.2. |
| **Revision 2 §6 sub-slice 1b (this lane's own)** | the context supplier belongs in `implementation_inflow.dart`, `server.dart`, and the route-3 caller | **The route-1 context writer is `packages/scheduler/lib/src/scheduler.dart`** (`:1741-1813`), and its context at **`:1746` is a `const` literal** — `workItemOrigin` and `approvedDesignRevisionId` cannot exist until it becomes a computed map. The file appeared in no sub-slice's list. `design-review-gate.md` §6, 1b. |
| **Revision 2 §6 G5′ (this lane's own)** | the edge admits "all **five** original `blockingHumanDecisionResolved` pairs" | **Six** (`:604-623`): `engineeringReview/rework`, `engineeringReview/reject`, `qaWaiver/reject`, `qaRework/reject`, `humanQaApproval/reject`, **`escalation/approve`**. "Five" was inherited from the **stale comment** at `:595`. The sixth is the pair §5.2 argues about, and G5′ exists to prove no existing bound was traded away — so the count is load-bearing. |
| **Revision 2 §4.1 (this lane's own)** | `blockingHumanDecisionResolved({ …unchanged… })  // :604-624` | **`:604-623`.** `:624` is `decisionActorIsHuman()`. LOW finding L-1. |
| **Revision 2 §5.2 (this lane's own)** | `(escalation, approve)` is "in the edge's `blockingHumanDecisionResolved` set (`:618-620`)" | **`:619-622`.** `:618` closes `humanQaApproval/reject`. Same finding, and the conclusion is unchanged: the edge permits it, `targetFor` does not route it there. |
| **`evaluator-spec.md` §5.3 / §6 (this lane's own)** | the triage contract's other two gates are "both `required: true` (`{L}:175`, `:201`)" and both are barriers | **Two required, one optional.** `triage-classification-admitted` `required: true` (`:175`); `triage-evidence-grounded` `required: true` (`:202`); **`triage-clarification-routing` `required: false` (`:222`)**, deliberately so per its own comment at `:216-218`. The conclusion (`allRequiredGatesPassed` still fails) is unaffected; the reasoning was wrong. LOW finding L-2. |
| **Revision 2 metadata `:596-598` (this lane's own)** | a `DESIGN_DISCOVERY` at `authority: HUMAN` recording **Reading A** as the design's finding | **Reading A is rejected** by `.decisions/7f3e2a95…`. Two entries in the same `durable_discoveries` list asserted opposite readings of the same clause — the exact shape the review calls the **L3 pattern**. MEDIUM finding M-5. |
| **Revision 2 metadata `:60` / `:601` (this lane's own)** | `context` "reaches the policy … and **is NOT persisted**", attributed to `packages/workflow_engine/lib/src/states/workflow_state.dart` | **Wrong file and wrong claim.** `DurableWorkflowEngine.transition` lives in **`packages/workflow_store/lib/src/durable_workflow_engine.dart`**, and it persists **no guard-supplied key** — it reads back `humanDecision` (`:216`) and `blockingReason` (`:223`), both its own. `design-review-gate.md` §4.4 already stated the corrected form; the metadata did not follow. MEDIUM finding M-5. |
| Revision 1 §3.3 (this lane's own) | *"There is no consumer on either path"* | **True for feature intake; under-stated for design remediation**, where the shape *is* establishable and only the type is missing. §3.3. |
| Revision 1 §9.3 (this lane's own) | brief's M1–M4 "carried forward as M8–M10" | **M2 was dropped.** Restored as M12. §6. |
| Correction spec (Manager, rev 2), B1 | the completion-inflow filter is at `scheduler.dart:1527` | **`:1522`.** The Manager's figure is off by five; the claim itself is confirmed. Recorded because the citation is load-bearing for the whole finding. |
| Correction spec (Manager, rev 2), H3 | `triageDefectInstruction` at `triage_defect.dart:222-278` | **`:222-276`.** `:277-278` are the doc comment and signature of the next function. The schema block at `:249-264` is confirmed exactly. |
| Correction spec (Manager, rev 2), H1 | `scheduler.dart:1527`; `implement_feature.dart:117` | `:1522` as above; `:117` **confirmed correct**. |
| Correction spec (Manager, this pass), B-1 | `stalled_work_item_gate.dart:182-191` | **The file is at `apps/server/lib/src/triage/stalled_work_item_gate.dart`, not `apps/server/lib/src/review/`.** `:182-191` is confirmed exact — the `else` arm logging `stall.not-parkable` with *"Nothing was written"*. The finding stands; only the path needed completing. |
| `design-resume.md` "Read first" | `work_item_transitions.dart:657-662` for `qaInProgress -> qaPassed` | **`:690-696`.** `:657-662` is a comment block about `reviewRejected`. The conclusion is unchanged and stronger (§2.1). |
| `design-resume.md` "Read first" | `triage_processor.dart:272-276` for `_extractDefectId` | **`:279-285`.** `:272-276` is the tail of the `FormatException` handler. The code is exactly as described. |
| Predecessor brief §4.2 | `possibleDuplicateDefectId` `:254`, `recommendedWorkItemCategory` `:256`, `summary` `:257`, `suspectedComponents` `:221-223` | `:259-260`, `:261-262`, `:263`, `:224-226`. All drifted; the table's substance is right. |
| Predecessor brief §5 / metadata | `triage_processor.dart:120-124`, `:125-132` | `:120-132` and `:124-132`. Substance right. |
| `FOLLOW_UPS.md` §13 F-47 and `design-resume.md` | `work_item_transitions.dart:661` for `qaInProgress -> qaPassed` | Same off-by-29 as the resume spec; correct line is `:690-696`. **`FOLLOW_UPS.md` §13 line 1073 carries this citation** — Manager-owned, not corrected here. |

**One spec item is answered with evidence rather than compliance — recorded here so a reviewer does
not have to reconstruct it.** The correction spec's B-1 named two fixes and **recommended the
second** (land the park at `waitingForHumanDecision` rather than in a new state), on the grounds
that it also closes H-2. **This revision keeps the distinct state, which the same spec permits on
condition that the writer and the originating component be named** — they are, in §5.1.1a and
§5.1.2. **Why the recommended option was not taken is argued against the tree in
`design-review-gate.md` §5.1.1b**, in two parts: `agentCompleted` has **no edge** to
`waitingForHumanDecision` (`stalled_work_item_gate.dart:97-99` says so), and — decisively — under
Reading B the gate refuses route 3 for decisions raised by the item's *own* lanes, which leaves the
item at `waitingForHumanDecision` holding a **resolved** decision id
(`durable_workflow_engine.dart:816-841`) that nothing can re-open (`:564-584`) and no edge leads
away from. **That is the dead end the park's distinct state exists to prevent, so P3 is the sink
rather than a convenience.**

**One inherited conclusion is now wrong rather than merely mis-cited:** the predecessor's §3.3
"proof by execution" that the parked feature is dispatchable, and its `CONTRADICTION` against
F-45. Both are resolved by `ddfbfff` (§1.1), and the brief's Flow A no longer describes HEAD.

**And the pattern across all of these, stated once because it is the finding this document exists
to avoid.** Thirteen of the rows above are errors **this lane's own prior work** made and a review
caught — a citation pointing at a comment that says something else, a `try` that guards something
else, a pair count inherited from a stale comment, a file omitted from the list that writes the thing
the file was supposed to help write, and (pass 3) a range 1103 lines past the end of a file.

**On this lane's own classification, eight of those thirteen are of ONE kind: citing a range as
evidence for a property that range does not state.** The other five are a file omitted from a list,
a superseded claim left live in a register (twice), a path error in an inherited spec, and the
out-of-range citation — which is a variant of the same kind rather than a new one.

> **The count is offered as a classification, not as a fact, and that is deliberate.** This sentence
> previously asserted *"Nine of the rows … Six of the nine are of one kind."* **Both numbers were
> wrong** (ten and eight, by the reckoning above), and nothing checked either. **A corrections table
> that states a precise count of its own error classes is asserting a number with no assertion behind
> it** — the very rule this paragraph exists to state. So the classification is now offered for the
> reviewer to dispute, the row-by-row sources are named above so it can be re-derived, and the
> mechanism that does not depend on the count at all is the one that follows.
>
> The correction is not "check the lines" — revision 2 checked them, and pass 2 checked them again.
> **It is: if a property is load-bearing, some assertion must fail when the property is absent.**
> G14, G15, G16, G17, G17b and the G5′ count exist because of that, and a reviewer should treat any
> future load-bearing property asserted without an assertion as the same defect.
>
> **M-1, PASS 4 — and the distinction the reviewer's sample forced, which this paragraph had not
> drawn.** Its second sentence proposed **two citation discriminators** as if they were part of the
> mechanism: **the end line is inside the file**, and **the cited range contains the quoted string**.
> **Both are necessary and NEITHER is sufficient, and that was demonstrated on a sample rather than
> asserted:** the first catches PASS3-1 (the range 1103 lines past the end of a 440-line file) and the
> second catches PASS3-4 (`:563-580`, ending one line short of the string it quotes at `:581`).
> **Neither catches PASS3-2 / L-A**, where `durable_workflow_engine.dart:996` exists, is inside the
> file, and sits in a range containing real lines — **the defect is that the line does not state the
> property it was cited for. And that is the LARGEST class: eight of the thirteen rows above.**
> **So the discriminators are recorded as PRE-FILTERS, not as closure.** A future pass must not read
> them as the mechanism, because a mechanical check catching two of three instances of the dominant
> class is worse than no mechanical check: **it produces the confidence of automation with a third of
> the coverage, which is the same failure as a well-formed `file:line`.**
>
> **The generalisable form, and the three mechanical checks that are necessary and insufficient.**
> A citation is mechanically checkable three ways: the end line is inside the file; the range contains
> the quoted string; **the cited construct's name appears in the range**. **All three are necessary
> and all three are insufficient**, because the failure none of them sees is a range that is *about
> the right construct and states the wrong property of it* — `:996` is inside `_isReWorkDecision`,
> which is a decision-type comparison, while the artifacts wanted the escalation-index computation,
> which lives at `:1007-1021`. **Only reading catches that class, and the assertion is what stops the
> class from being load-bearing.** **The mechanism is unchanged: the assertion rule. Citations are
> pre-filtered; properties are asserted.**

**Revision 1's own citation verification, recorded for completeness:** every range it cited was
read rather than inferred from a surrounding grep, and two were tightened in place —
`agentFailed -> implementationReady` from `:265` to `:265-267`, with the guard stated exactly
(`actorAllowed([orchestrator])`) instead of "per the surrounding convention"; and
`designRejected -> designInReview` at `:115-117`, confirmed. **The independent review confirmed
this discipline as sound and it is preserved.** Note that reading a guard exactly is not the same
as asking whether anything calls the edge it is on — that is the failure §2.1a records, and it
survived a careful citation pass.

**This revision re-verified every citation it touched at `c8fd361`**, and the corrections table
above records the six errors it found — five in Revision 1's own claims and two in the correction
spec itself (recorded separately, so six entries and two files).

**The correction pass at `90b6f5f` re-verified every citation it touched, and the table above is
that pass's output: eleven new rows — TEN of them errors revision 2 made, and one a path error in the
correction spec itself.**
> **CORRECTED IN PASS 3 (LOW L-B, extended), because this document's own corrections table was
> miscounting itself a second time.** The sentence above read *"eleven new rows, nine of them errors
> revision 2 made."* **The count of eleven is right; "nine" is wrong, and it is ten.** Counting the
> rows by what they correct: `Revision 2 §4.3 step 3`, `§5.1.1`, `§5.1.2`, `§6 sub-slice 1b`, `§6
> G5′`, `§4.1`, `§5.2`, `evaluator-spec.md §5.3/§6`, `metadata :596-598` and `metadata :60/:601` —
> **ten rows, every one an error revision 2 made** — plus `Correction spec (Manager, this pass), B-1`,
> which is a missing path in the spec, not a revision-2 error. **The same row count also appears in
> `design-revision-metadata.yaml`, which said §12 held "five corrections", and in §9.1, whose
> resume-spec/predecessor-brief counts were swapped. Three count defects in one artifact set, all in
> the register that exists to be exact, and none of them caught by the review that confirmed the
> **eleven rows themselves were accurate.** The lesson is not "count carefully" — it is that a count in
> prose is a load-bearing claim with no assertion behind it, which is the same rule §12 keeps stating
> about everything else in this document. Two are the **L3
pattern** the review named — revision 2's metadata recorded Reading A as a live `DESIGN_DISCOVERY`
at `authority: HUMAN` *in the same list* as Reading B, and revision 2's §5.2 argued Reading B while
disposing of the rationale *"as a different field"*, which is the exact clause the operator's
`rejected_alternative` cites as a reason the reading was rejected. **The reading is applied because
`.decisions/7f3e2a95…` decided it.**

> **AND CORRECTED A THIRD TIME IN PASS 5 (PASS5-2), because pass 3 corrected this sentence's
> *classification* and left its *count* wrong — and the classification it fixed cannot be right
> either. The table above carries THIRTEEN rows, not eleven.** Counting them by the `Source` column:
> **three correct Revision 1** (`§2.1`, `§4 / deliverable-2 table`, `§4.3`), **ten correct Revision
> 2**, and **no row for `Correction spec (Manager, this pass), B-1`** — which this paragraph names as
> the eleventh row and which **is not in this table**. So pass 3's enumeration adds eleven to eleven
> and gets twenty-two.
>
> **The correct version of this sentence is nineteen lines above it**, and it is a count that was never
> touched: *"Thirteen of the rows above are errors **this lane's own prior work** made and a review
> caught"* — **thirteen, all this lane's own, which is exactly what the `Source` column says.** **So
> this register held two paragraphs disagreeing with each other about its own size, and the one
> carrying the "Actual" claim was the wrong one.**
>
> **Why this is recorded rather than quietly fixed.** §12.1's `PASS3-5` row documents this sentence
> being corrected *once* for miscounting; §12.2's `PASS4-2` documents this **document's own §16**
> being corrected for the same class. **This is the third site, it is inside the register, and neither
> earlier correction caught it — because each corrected a number it was already looking at rather than
> re-deriving the count from the table.** That is the generalisable finding and it is `PASS5-2` in
> §12.3: **a count in prose is invalidated by the act of appending a row to the register it counts, and
> correcting one number in such a sentence is not the same as checking the others.**
>
> **Stale, retained for audit:** *"The count of eleven is right; 'nine' is wrong, and it is ten."* The
> method in that sentence — count the rows by what they correct — is what exposed this defect, and is
> kept. Its count was wrong, and its enumerated eleven does not account for the table's three
> revision-1 rows.

> **Correction (M-B) — this paragraph's claim was too strong, and the review was right to call it.**
> It read *"**Both are now removed rather than relabelled**"*, as a statement about everything that
> pass withdrew. **That is true of the two `durable_discoveries` instances and false of the third.**
> The third instance — a duplicate **R4** row in the metadata's `risk_assessment.risks` list — was
> **left in place carrying the opposite claim** (*"it is the reason §5.2 is marked for independent
> judgement"*), which `design-review-gate.md` §5.2 denies in terms (§5.2: *"This is no longer the open
> question revision 2 left for a reviewer to judge"*). **The disposition for that instance is
> different, and it is now stated correctly: the two `durable_discoveries` entries were REMOVED with a
> withdrawal argued in place; the duplicate R4 row is WITHDRAWN IN PLACE with its stale text
> PRESERVED and the reasoning alongside.** Two different dispositions, not one — and collapsing them
> into a single word is how a reader would have concluded nothing else needed doing.

### 12.1 Correction pass 3 — eight rows, all verified at `2b182fd`

The review of pass 2 returned **no blockers and no highs**. These are the rows pass 3 adds; the ones
it found are marked. **The B-1 body of work is not touched.**

| Source | Claimed | Actual at `2b182fd` |
|---|---|---|
| **PASS3-1** `design-review-gate.md` §6 (2b) and `evaluator-spec.md` §4.3 (V6) | the per-item isolation property is documented at `implementation_inflow.dart:1543-1578` | **`implementation_inflow.dart` is 440 lines long. The range is 1103 lines past the end of the file.** The property is real and is stated at **`implementation_inflow.dart:124-126`** — *"It throws INSIDE `_routeOneCompletion`'s per-item guard … rather than out of `tick`, which would cost the whole lane its pass"* — and demonstrated at `scheduler.dart:1582-1599`. **Found by this pass, not raised by the review**, and it is the L3 pattern in its purest form: a well-formed `file:line` pointing at nothing. **Both instances corrected.** |
| **PASS3-2** `design-review-gate.md` §6 (2d), `design-revision.md` §11, metadata `changelog` + `verification_commands` | `durable_workflow_engine.dart:996` is "the escalation-index computation" | **`:996` is inside `_isReWorkDecision` (`:987-1005`)**, whose result becomes `reTriageAttempt` (`:788-792`, `nextTriageAttempt` at `:384`) — **the triage-attempt counter, not escalation accounting.** The escalation-index predicate is **`_isEscalationTransition` (`:1007-1021`)**, called at `:770`, gating the `metadata['escalationIndex']` increment at `:847-849`; it delegates to `HumanDecisionRouting.routesToEscalation` (`:1016`; `human_decision_routing.dart:228-234`) and **never names the enum**, which is why the grep finds only `:996`. **The grep result claim was always accurate.** LOW finding L-A. |
| **PASS3-3** found while verifying PASS3-2 | — | **`human_decision_routing.dart:154` cites `DurableWorkflowEngine._isEscalationTransition (packages/workflow_store/.../durable_workflow_engine.dart:979)`. `_isEscalationTransition` is at `:1007`.** The repository's own comment about the lockstep rule points 28 lines off, landing the reader on `_getMaxEscalationForDecisionType`. **Recorded, not corrected — `packages/**` is `PROHIBITED_PATHS` for this lane.** Corroborates PASS3-2: the escalation-index computation is not at `:996`. |
| **PASS3-4** `design-review-gate.md` §5.1.1b, `design-revision.md` §12/§13.10, metadata `B-1-alt` and `durable_discoveries` | `durable_workflow_engine.dart:563-580` for *"returns a pending decision of the same type, or throws 'Work item is already waiting for a blocking human decision'"* | **`:563-580` ends one line short of the string it quotes.** Precise: the guard is `:564-565`, the idempotent return `:571`, the **throw `:573-583`**, and the reason string is **`:581`**. So the correct range is **`:564-584`**. **The property and the conclusion are unchanged** — a resolved id is the throw case (`:569-570`) — and **this is the citation discipline applied to the design's own load-bearing negative claim.** MEDIUM finding M-C names this range; the spec quoted it as `:563-572`, which is also one line short of the throw. **Both are corrected to `:564-584`.** |
| **PASS3-5b** `design-review-gate.md` §5.2.2 (this pass's OWN text, found while writing G17) | the lockstep rule (`human_decision_routing.dart:151-162`) applies to the human surface's new routing arm | **IT DOES NOT APPLY TO AN `approve` ANSWER, and stating it flatly is the L3 pattern in the other direction — a cited range pressed into a property it does not state for this case.** `escalationTargetFor` returns `null` for any choice that is not `reject` or `rework` (`:196-199`), and `_isEscalationTransition` short-circuits on the same condition (`durable_workflow_engine.dart:1012-1015`). **So answering "do the design review" increments no escalation index and appends no `EscalationTriggered` record**, and `:213`'s `(designApproval, _)` arm is unreachable for `approve`. Had an implementer taken the flat statement and added an arm, escalation accounting would have started **silently** on a design approval — the exact failure `:159-162` warns about. **Corrected in §5.2.2 and pinned by a new assertion, G17b**, so it is a decision rather than a side effect. G17's "if" half was also tightened to use the routing table's own predicate, `routesTo` (`:219-225`). **Recorded because it is the first time in this artifact set that a claim written by the correcting pass was itself wrong, and the only reason it was caught is that writing the assertion forced the question.** |
| **PASS3-7** `design-review-gate.md` §6 (new slice 1, file list — this pass's OWN text, found while verifying PASS3-2's neighbours) | the sub-slice's file list named `packages/platform_contracts/lib/src/enums/human_decision_type.dart`, with `human_decision_routing.dart:115-136` glossed as "wherever `HumanDecisionType` is declared" | **THE FIRST PATH WAS INVENTED — NO SUCH FILE EXISTS.** `HumanDecisionType` is declared at **`packages/platform_contracts/lib/src/enums/human_decision.dart:1-30`** (verified: the only `enum HumanDecisionType` in the repository, `grep -rn` over `packages` and `apps` excluding tests). `:115-136` of `human_decision_routing.dart` is the tail of `targetFor`, not a declaration. **A correct detail fell out of fixing it:** the enum carries NINETEEN values at `:1-20`, each with a `wire` at `:22-24`, and **no `options` field** — so the park's answer set is a property of the **call site**, not of the type, which is why sub-slice 1b touches the park helper and 1a touches the enum separately. **Recorded because a plausible-looking path is the most expensive form of this defect: nothing fails when it is wrong, and `HumanDecisionType` sits right beside it in the same directory.** |
| **PASS3-5** `design-revision.md` §9.1 (traceability) | *"§12 records **two** corrections of the resume spec and **three** of the predecessor's brief"* | **The counts are swapped.** Rows citing `design-resume.md`: `:942`, `:943`, and `:946` (which carries both `design-resume.md` and `FOLLOW_UPS.md` §13 F-47) — **three**. Rows citing the predecessor brief: `:944` (§4.2) and `:945` (§5 / metadata) — **two**. **Also understates §12 as a whole**: the table now carries **eleven pass-2 rows plus six pass-3 rows, seventeen in total**, not the five the same document's metadata `traceability` claimed (**L-B**). |
| **PASS3-6** `design-review-gate.md` §5.1.1a | the park's two steps, with the order left unstated | **The order is load-bearing and the document did not say so.** `requestHumanDecision` **throws** at `:573-583` for an item already at `waitingForHumanDecision` holding a non-null blocking id whose decision is resolved — precisely the state a **P3** entry is taken from. Step 1's `transition` nulls the id at `:219-221`, and **that null is the precondition step 2 tests at `:564-565`.** Stated in full in `design-review-gate.md` §5.1.1a, with the three failure modes enumerated. MEDIUM finding M-C. |

**Two claims in this document's own §12-adjacent prose were also corrected rather than left**, and
they are recorded here because they are the same defect class: the *"Both are now removed rather than
relabelled"* claim above (M-B), and this row's own counts (PASS3-5). **A corrections table that
miscounts itself is not a corrections table.**

### 12.2 Correction pass 4 — the fork is decided, and the consequences are not all in the fork

**The review of pass 3 returned 1 BLOCKING (two findings, B-1a and B-1b), 3 HIGH, 1 MEDIUM, 1 LOW.**
**Nothing in pass 3's body of work was rebuilt** — the review verified the §5.1.1a load-bearing
argument *exactly* (`:564-565`, `:569-570`, `:571`, `:573-583` with the reason at `:581`, and
`:215-221` nulling the id precisely because P3 changes the state), confirmed the reversal landed
cleanly, and confirmed M-B's R4 withdrawal is correct as an in-place withdrawal with stale text
preserved. **This table is additive.**

| Source | Claimed | Actual at `e1c191b` |
|---|---|---|
| **B-1a** `design-review-gate.md` §6 (G17) | G17 asserts the park's `options` list *"contains a `(decisionType, choice)` pair"* for which `routesTo(type, choice, designApproved)` is true | **`HumanDecisionOption` carries no `decisionType`.** The class is `packages/platform_contracts/lib/src/types/human_decision.dart:148-168` and its four fields are at **`:156-159`** — `optionId`, `label`, `description`, `recommended`. A decision's type is a property of **the decision**, resolved once as `targetFor(decision.decisionType, effectiveChoice)` (`durable_workflow_engine.dart:758-761`). **So G17 as written could never go green and no implementer could satisfy it.** **And it asserted nothing about the edge that decides whether the arm moves the item**: `blockingHumanDecisionResolved` is a strict whitelist, `allowed.contains((type: decision.decisionType, choice: decision.choice!))` (`guard_conditions.dart:420-428`). **Rewritten as G17(a)/(b)/(c).** |
| **B-1b** `design-review-gate.md` §6 (1a) | the new type needs a `targetFor` arm and, *"only if the answer is a `reject` or a `rework`"*, an `escalationTargetFor` arm; and `work_item_transitions.dart` is needed *"only if the new answer needs a bound on an existing edge"* — which it said it did not | **Three registration sites, not two, and the conditional is false.** A new type is admitted by no edge until it is added to that edge's `allowed` set, so **both** `(waitingForHumanDecision, designApproved)` (`:75-80`) and `(waitingForHumanDecision, planning)` (`:643-648`) need the pair. **`.decisions/3e5a7c26…`'s own `consequence` — *"Its routing arms MUST be registered in the same change"* — names two of the three and not the third.** Specified in full at `design-review-gate.md` §6 1a. |
| **B-2** `design-review-gate.md` §5.2.2 | slice 1 specifies *"the new `HumanDecisionType`, the `targetFor` arm, **the matching `escalationTargetFor` arm**, the park's option list…"* | **Doubly wrong, and superseded in place with the stale text preserved.** Given B-1b: **the enum value IS needed** (`:1020` said *"no NEW enum value is needed"*), **and the `escalationTargetFor` arm is NOT** — for the `rework` answer it must not exist, because `rework` is the one choice `:196-199`'s short-circuit does not protect and `_ => null` at `:214` is the only thing keeping `routesToEscalation` false. **G17b existed solely to catch exactly this, which means the correction lane knew the hazard and the specification still told an implementer to walk into it.** |
| **H-1** `design-review-gate.md` §5.3 / §6 (G17) | §5.3: *"G17 passes in this window … neither half of the iff is violated"*; G17: *"Also fails if such an answer is offered while the park is still unreachable"* | **Only one can be true, and both readings defeat the purpose.** Resolved structurally: G17 is split into three obligations and §5.2.2 now carries a **per-window verdict table**. **The honest answer is that G17 is green in the slice-1→slice-2 window, because the invariant cannot be violated there** — `designReviewRequired` does not exist and no item can be parked — **and the ordering is asserted by G17(b) going live at 2d, not by G17's verdict before it.** The sentence an implementer can be held to is *"2d may not land while G17(a) is red."* |
| **H-2** `design-review-gate.md` §6 (1b) / `design-revision.md` §8 | 1b is a landable sub-slice that adds one option to *"the set slice 2b raises"*, and every slice is *"each independently mergeable"* | **1b cannot land before 2b**: it edits the park helper, and **2b creates the park helper**. **1b folds into 2b.** The "independently mergeable" promise is **narrowed where it is now false and kept where it holds** — slice 1 remains landable (1a + 1c), and **G17 still ships with slice 1**, which is the property the review asked about. **L-1's dangling fragment in §8's slice 5 is repaired in the same pass** and is the artifact's own §13.12 warning about renumbering realised. |
| **H-3** `design-revision-metadata.yaml:869`, `:514` | present tense: the park's dead end *"is recorded as SLICE 1.5, OWNER THE MANAGER"* | **Reversed by SEQ (`:848`).** **This is the L3 pattern's fourth instance in a `.md`-clean sweep — and the sweep that missed it was the orphan-`1.5` check, which passed on both `.md` artifacts.** The same file demonstrates the supersession convention at `:470` and `:887`, so this is an inconsistent omission, not a missing convention. Superseded in place in both. |
| **PASS4-1** `design-revision.md` §4.2 — **found by this pass's sweep, not raised by the review** | *"No new `HumanDecisionType`, no new routing-table arm, no new decision type."* | **False on all three counts** under `.decisions/3e5a7c26…`, and **carried through passes 1, 2 and 3 unchanged with no supersession marker.** **The fifth instance of the L3 pattern, in a `.md` artifact that the orphan sweep had also passed.** Superseded in place. |
| **PASS4-2** `design-revision.md` §16(11) — **found by this pass's sweep** | *"§12 now lists **eleven pass-2 corrections (nine of them this lane's own errors, six of one kind)** and six pass-3 corrections"* | **Stale in the same document §12 corrected.** §12.1's PASS3-5 correction says the count is **ten** revision-2 errors, and §12's own classification says **eight** of thirteen are of one kind. **So §16(11) was quoting the pre-correction numbers out of the register that had already fixed them** — a live count contradicting its own source, which is the same class as the three count defects pass 3 found. Corrected. |
| **PASS4-3** `design-revision.md` §10 R4 / `design-revision-metadata.yaml` `risk_assessment.risks` — **found while verifying PASS4-1** | R4's mitigation names *"G16, now pinned to the set rather than to the enum"* and *"asserted by **G17**"* | Both **descriptions** are stale in substance, not only in naming: G16 is now pinned to three `(optionId, label, choice)` **triples on the new type**, and G17 is three assertions. **The risk itself is unchanged and R4's residual — the answer exists, the producer does not — survives everything this pass did.** Updated in place, not restated. |

**And the sweep's own result, stated because the check that should have caught these did not.** The
dispatch's orphan-`1.5` check was clean in both `.md` artifacts and **missed the metadata register
twice** (H-3), and this pass's sweep **found a third instance in `design-revision.md` §4.2 that the
same check had also passed over** (PASS4-1). **So the L3 pattern has now been caught five times in
this artifact set, and a grep-based check has a demonstrated blind spot: it finds an orphaned string,
not a stale claim.** The instruction that follows, recorded in the artifact set's own idiom: **a
reviewer's checklist is not a sweep, and this pass's sweep was four artifacts read end to end rather
than four greps.**

---

### 12.3 Correction pass 5 — the operator restored the fourth answer, and the register counted itself wrong

**The review of pass 4 returned 0 blockers and 0 highs; its B-1a/B-1b, B-2 and H-1 findings were
verified as landed, and none of its body of work is rebuilt here. This table is additive.** Pass 5's
substantive change is the operator's ruling; the other four rows are findings from this pass's sweep,
**three of them in this lane's own correction machinery.**

| Source | Claimed | Actual at `b63c771` |
|---|---|---|
| **P5-1** `design-review-gate.md` §6 1a, §6 2b, §7, §7.1; `design-revision.md` §13.7, §13.14, §16(2) | pass 4: *"the park's menu is **three** answers"* — the operator is offered one fewer, and *"the correct next step is a second human decision on `HumanDecisionChoice` — named here rather than taken"* | **THE OPERATOR TOOK IT, AND RULED THE OTHER WAY.** `.decisions/5a90c1d3-8e47-4b26-9f0c-3d7a5b2e6c19.yaml` (RESOLVED, `FOURTH_CHOICE_VALUE`, operator, 2026-10-17T15:10:00Z): *"Nine **existing** `HumanDecisionChoice` values cannot express four coherent answers, and the design lane merged 're-triage' into 'put it back in the lane', leaving three … **HD-1 delegates the park's handling to the design lane, but a product-facing menu reduction is not that delegation.**"* **The merge is undone in place; the menu is four** (`approve` / `rework` / **`re_triage`** / `cancel`). **Two errors in the withdrawn text, isolated:** HD-1's delegation covers *what happens to an item that never gets a review*, not **what the item's menu offers**; and *"the number of coherent answers is bounded by how many of the NINE values carry park meanings"* treats the current size of a shared enum as a fixed term in a product decision — **it is a function of how many values exist, and a design lane may propose a tenth.** Specified at `design-review-gate.md` §6 1a and §6 2b; asserted by **G16** (re-pinned to four) and **G18** (new). §13.14 and §16(2) superseded in place, stale text preserved. |
| **P5-2** **THE SCOPE WARNING — AND THE ANSWER IS THAT IT IS EXPRESSIBLE, SO THIS IS NOT THE ESCALATION THE DECISION CONTEMPLATES.** `5a90c1d3…`'s `scope_warning`; pass 4's §13.14 and §16(2), which recorded the reduction and invited reversal | **pass 4: no claim either way.** The new value is a **shared** `HumanDecisionChoice`, and the decision requires it *"be offered only by the design-review park's decision type … If the enum cannot carry a per-type option set, that is itself a finding to escalate rather than work around"* | **A PER-TYPE OPTION SET IS EXPRESSIBLE — more strongly, the option set is PER-DECISION-INSTANCE, so per-type is the weaker specialisation.** Four verified facts: **(1)** `HumanDecision.options` (`human_decision.dart:55`) and `DecisionContext.availableOptions` (`:204`) are fields of **the decision**, and the engine documents `availableOptions` as *"the caller's own option ids, in the caller's order"* (`durable_workflow_engine.dart:531-535`); **(2)** the operator UI builds its menu **only** from them (`decision_detail_bloc.dart:30-37`) — there is no enum filter anywhere in that path; **(3)** **`HumanDecisionChoice.values` is enumerated nowhere in `lib/`** — all nine sites are in `test/`; **(4)** a per-type presentation layer already exists in production: `decisionChoiceLabel(…, decisionType:)` (`decision_choice.dart:32-57`), with a live `escalation` arm at `:37-46`. **So `re_triage` is visible exactly where some decision's own option list names it — the park's raising call site and nowhere else — by construction, not by filtering.** Specified at `design-review-gate.md` §6 1a; **the four facts are the reviewable claim and §16(2)(d) asks a reviewer to check them, because the no-escalation decision rests on all four.** |
| **PASS5-3** `design-review-gate.md` §6 1a, §6 2b, G17b, §5.3, §2d | pass 4: **three** arms, **two** `blockingHumanDecisionResolved` admissions, **three** files | **A THIRD EDGE AND A FOURTH FILE.** `re_triage` routes to `designNotRequired`, so `(waitingForHumanDecision, designNotRequired)` (`work_item_transitions.dart:528-546`) is a **third** whitelist. **And it is the only one of the park's three edges that carries an escalation-index bound** (`escalationIndexWithinLimitForDecisionTypes({engineeringReview, humanQaApproval})` at `:559-563`). **The fourth file is `apps/control_plane/lib/shared/decision_choice.dart`, which a TYPE never needed and a CHOICE does**: its `knownDecisionChoices` (`:12-19`) is a hardcoded **six**-value set against a **ten**-value enum, and the file's own doc comment (`:3-5`) enumerates the six as though they were the enum's. Without a `re_triage` entry the operator sees caller prose instead of a mapped label on **both** surfaces (`decision_detail_bloc.dart:38`, `needs_you_bloc`). **Recorded, not corrected — `apps/**` is `PROHIBITED_PATHS`.** |
| **PASS5-4** `design-review-gate.md` §6 1a, the `rework` disposition — **pass 4's own text** | *"`rework` → … **the behaviour `(escalation, rework) → planning` already has today** (`escalationTargetFor`'s own comment calls it out at `:188-191`)"* | **THE BEHAVIOUR CLAIM IS CORRECT AND RE-DERIVED; THE CITATION IS NOT.** **`:188-191` is `## THE TWO LOCKSTEP ARMS MOVED WITH OD-3` and it does not mention `(escalation, rework)` or `planning` at all** — it is about `(engineeringReview, rework)` and `(humanQaApproval, reject)` moving to `implementationReady`. **This is the sixth instance of the L3 pattern and the second pass 4 introduced — in the very clause written to make `rework` the risky arm.** The property holds for a reason stated at `:196-199` and `:214`, not at `:188-191`; the citation is removed and the property is now carried by **G17b**. **Recorded because a true conclusion resting on a citation that does not state it is the same defect as a false one: the next edit to the range would have made it false silently.** |
| **PASS5-7** `design-revision.md` §16(11), §9.1 and `design-revision-metadata.yaml` `verification_commands` — **THIS PASS REPEATED THE DEFECT IT WAS NAMING, AND CAUGHT ITSELF** | pass 5 set out to correct the count rot and, in doing so, **wrote "§12.3 adds eleven pass-5 rows" into three sites when §12.3 has SIX rows** | **THE EIGHTH INSTANCE, AND THE ONLY ONE MADE BY A PASS THAT KNEW ABOUT THE PATTERN.** The cause is exactly the one §12.3 names: **pass 5 appended rows to a register and stated the new total in prose, having estimated it rather than counted it** — it wrote "eleven" from an intention of how many findings it planned, not from `rg -c` over the table it had just built. **Caught by re-counting the four registers before committing, after the same discipline had already been written up three paragraphs earlier.** All three sites corrected to six; §12 thirteen, §12.1 eight, §12.2 nine, §12.3 six — counted. **Recorded rather than quietly fixed, because the evidence that a stated process does not survive being written down is itself the finding, and because a register that hides its own lapse teaches a reader that the named lapse was rare.** The only durable mitigation is executable: **the counts must be generated, not typed** — and until that exists, every pass that appends a row must re-count rather than re-state. |
| **PASS5-6** `docs/engineering/FOLLOW_UPS.md` §18 `F-60` — **read, never written**; recorded here because `docs/**` is `PROHIBITED_PATHS` | F-60: *"`3e5a7c26` said the new type's arms must be registered, naming **two** sites. There are **three.**"* — naming the two edge whitelists at `:75-80` and `:641-650` | **VERIFIED, AND NOW ONE SHORT.** Both sites are correct and both are required, and pass 4's G17(a) names them. **But with the fourth answer there are FOUR registration sites, not three**: `re_triage` routes to `designNotRequired`, so `(waitingForHumanDecision, designNotRequired)` (`work_item_transitions.dart:528-546`) is a **third** edge whitelist — and the presentation registration in `apps/control_plane/lib/shared/decision_choice.dart` is a **fourth file** that a new TYPE never needed and a new CHOICE does. **So `F-60`'s finding — that the decision's own `consequence` enumerates incompletely — is correct in kind and has itself gone stale in magnitude, which is the pattern this artifact set exists to catch and the reason it is recorded rather than assumed.** **The Manager owns `FOLLOW_UPS.md` and this lane wrote nothing there**; F-60's *magnitude* needs updating to four, and §18's F-61 needs no change — pass 5's short-circuit table **confirms** it and adds that `reTriage` is on the protected side. |
| **PASS5-5** `design-revision.md` §12 (twice), §9.1, §16(11); `design-revision-metadata.yaml` `verification_commands` | pass 4's `PASS4-2` corrected **two** numbers in §16(11) and reported the count rot closed: *"§12 lists **eleven** pass-2 corrections … §12.1 adds **six** pass-3 corrections … §12.2 adds **nine** pass-4 rows"* | **THE ROT CONTINUED, AND THE FOURTH INSTANCE IS INSIDE THE ROW THAT CORRECTED THE THIRD.** Actual counts at `b63c771`: **§12 thirteen rows** (three correct Revision 1, ten Revision 2 — **every one marked `(this lane's own)`**, matching §12's own untouched classification at its "Thirteen of the rows above" sentence); **§12.1 eight**; **§12.2 nine**; **§12.3 eleven**. **Four prose sites were stale: §12's own "eleven new rows" summary (which also attributes an eleventh `Correction spec` row that is not in the table), §9.1's ledger count, §16(11), and the metadata's `verification_commands`.** §12.2's `PASS4-2` fixed *"nine → ten"* and *"six → eight of thirteen"* and left **two other numbers in the same sentence** uncorrected — **because they were correct when pass 3 wrote them, and pass 4 then appended a row to §12 and a row to §12.1.** **The generalisable finding, and it is not "count carefully": a count stated in prose is invalidated by the act of appending a row to the register it counts, and correcting one number in such a sentence is not the same as checking the others.** All four corrected here, and each is recorded at the site it was wrong rather than centrally, because a register that fixes its own counts in one place reproduces the defect. |

---

## 13. What I did not fully address, stated plainly

Per the lane's own no-placeholder rule, the items below are **not** done and are not claimed to be.

1. **The two contracts (§3) are not authored.** This is the mandate's deliverable 3 and I did not
   produce it. My reason is evidentiary, not effort: at `e3634a0` a feature-intake item produces
   **no agent execution at all** (§1.2, §3.1) and a design-remediation item produces one whose
   result its only consumer abandons (§3.2). A `requiredFields` list with no consumer behind it is
   the fabrication the mandate told me to avoid. The mandate permitted exactly this answer
   ("say so rather than inferring one"), and I have said so with the evidence rather than the
   bare refusal the predecessor offered.
2. **The design-review gate is `DECLARED`, not `PASSING`** (§7). Nothing writes a
   `design_revision` row today (§1.3), so `readApprovedDesignRevisionForWorkItem` returns `null`
   for every work item in existence. **The gate will refuse every intake item until slice 4
   lands.** That is the correct behaviour under HD-1 and it is also a real operational
   consequence: feature intake and design remediation cannot reach an implementer unattended,
   ever, in the current deployment. I flag it rather than let a reviewer discover it in staging.
3. **`qaInProgress` strandedness (§2.1) is reported, not designed.** It is outside this brief's
   subject and it is bigger than it. Slice 0 hands it to the Manager.
4. **The four fabricated evaluators (§2.2) are specified as a prerequisite, not rewritten.**
   What a real `static-analysis` gate should assert is a `qa_architect` call, not a design call.
5. **I have not verified any runtime behaviour against a running platform.** No docker, no
   compose, no `psql`. Every claim is from the tree at `e3634a0` plus the two test runs in §14.
6. **Whether `featureIntakeParked`'s new `agentExecuting -> featureIntakeParked` recovery edge
   (`work_item_transitions.dart:159-161`) is sufficient** for items already stranded mid-run by
   the pre-`ddfbfff` behaviour is a data-migration question I did not investigate; no `psql`, and
   the answer lives in the QA database.
7. **The park's human surface offers no "do the design review" — and from slice 1 it will.**
   **Superseded in part by correction pass 3, and the supersession is recorded rather than applied
   quietly.** Revision 2 left it as a *deliberate* gap; `.decisions/7f3e2a95…` closed the question of
   whether to accept it and answered no. **This pass closes the question of who builds it and when:
   slice 1, first** (`design-review-gate.md` §6, §5.2.2; `.decisions/b81f40c7…`).
   - **Now specified, not handed on:** 1a (**the `HumanDecisionType` — NOW DECIDED as a new one**,
`.decisions/3e5a7c26…` — **its arms, and its registration sites: at pass 4's count THREE (the enum,
      `targetFor`, and two `blockingHumanDecisionResolved` whitelists), and at pass 5's count FOUR
      FILES — THREE whitelists plus a presentation registration**), because `.decisions/5a90c1d3…`
      restores `re-triage`, whose target `designNotRequired` is a third admitted edge (`:528-546`)
      **and because the new value is a CHOICE, which adds a presentation registration in
      `apps/control_plane/lib/shared/decision_choice.dart`** that a type does not), 1c (**G17(a)/(b)/(c)**), and **1b
      folded into 2b** because the option list belongs to the raising call site (H-2). **G16 is
      re-widened with it**, now pinned to **four** `(optionId, label, choice)` triples on the new type,
      so it does not fail the moment slice 1 lands. **G18 is new in pass 5** and asserts the count
      itself, because the operator's `invariant` is about the count and no assertion covered it.
   - **A judgement of this pass that a human could reasonably reverse, stated here rather than
     buried: ~~the park's menu is **three** answers, not the four the previous pass specified. See
     §13.14.~~ — **REVERSED BY THE OPERATOR; see §13.14, which is superseded in place.** The park's
     menu is **four**: `approve` / `rework` / **`re_triage`** / `cancel`
     (`.decisions/5a90c1d3…`; `design-review-gate.md` §6 1a and §6 2b; asserted by **G16** and
     **G18**).
   - **Still not resolved, and stated as unresolved:** a human still cannot **produce** the design
     review the item is waiting for. Answering the new question routes the item to `designApproved`,
     and **nothing writes an approved `design_revision` there until slice 4** (M5–M7, §6). **The
     answer exists; the producer does not.** That is R4, and it is **not** closed by slice 1.
   - **What it costs in the meantime:** for the whole of slices 1–4, "stop" (`cancel`) is still the
     only park answer that terminates. Also R4. **Pass 4 verified this survives the new type**: the
     `cancel` arm needs no registration at all, because `(_, cancel)` is a catch-all
     (`human_decision_routing.dart:121`) and `waitingForHumanDecision → cancelled` is admitted by
     the generic escape (`work_item_transitions.dart:786-791`, `:806-811`; `:640` says so in the
     file's own words). **The one answer that terminates is the one that cannot be broken by a
     missing registration — which is the right way round.**
   - **`FOLLOW_UPS` F-55 now exists** (`0bfb6fb`, §16) and states the gap in the Manager's own words.
     The previous pass cited it as an existing artifact in six places while saying in four of them it
     had never been written. **All six now resolve; this lane wrote neither F-55 nor F-56.**
   - **Also resolved earlier, and revision 2 had not:** whether `escalation` is safe to raise here at
     all. **Pass 4 corrects the answer: the park does not raise `escalation` at all.**
     `.decisions/3e5a7c26…` rules it out, so the question is moot — and the consequence is that
     `escalation`, which is raised nowhere in production today, **stays** unraised after this design
     ships, while keeping three `targetFor` arms. Recorded in the metadata as a `PROJECT_FACT` for the
     Manager; `FOLLOW_UPS.md` is `PROHIBITED_PATHS` here.
8. **I have not re-run the two test suites from §14.** They were run at `e3634a0` by Revision 1 and
   no production code changed, so re-running would produce the same output; this revision's claims
   are all tree-derived and none depends on a test result. Stated rather than implied.
9. **R1 remains UNMITIGATED.** The drift test that would mitigate it is *specified* (sub-slice 2b)
   but does not exist, and no design artifact can supply it. §10 says so in the row rather than in a
   footnote.
10. **One spec item is answered against its recommendation, and a reviewer may disagree.**
    The correction spec recommended landing the park at `waitingForHumanDecision` over a new state.
    **This revision keeps the distinct state**, which the same spec permits if the writer and the
    originating component are named — they are (§5.1.1a, §5.1.2). The argument for preferring it is
    in `design-review-gate.md` §5.1.1b and rests on two verified facts: `agentCompleted` has no edge
    to `waitingForHumanDecision`, and a route-3 refusal leaves the item there holding a **resolved**
    decision id that nothing can re-open. **The second point is the one that decides it**, and it is
    the strongest single finding in this correction pass. **A reviewer who reads `durable_workflow_engine.dart:816-841`
    and `:564-584` differently should say so, because the whole park shape turns on it.**
11. **One judgement call of mine was overridden on AUTHORITY. It is recorded here as overridden,
    not deleted.** The decision called the dead end's fix a *precondition* — "must be solved
    **FIRST**". This design's position was that the gate (slice 2) lands first, on the grounds that it
    is a strict reduction in what the platform may dispatch and leaves items visible with a real
    reason and a real pending decision, whereas the human surface first leaves a decision type and a
    routing arm that **no guard consumes** for the slice-1→slice-2 window. **The independent review
    agreed with that argument on the merits** and held that deferring a Level 3 operator instruction is
    the operator's call: *"a flagged judgement is not a discharged obligation."* `.decisions/b81f40c7…`
    reversed the order, with an `authority_note` stating the merits argument *"is recorded and is not
    dismissed"* and is overridden *"on AUTHORITY, not on reasoning."*
    **So: the reasoning stands and is preserved verbatim at `design-review-gate.md` §0.2; the ordering
    does not. A reader must be able to see which axis each thing moved on, and §0.2 is where that is
    made visible. The disagreement that survives into the implemented order — an unconsumed
    human-facing answer — is named in R13 and `design-review-gate.md` §5.2's closing callout rather
    than argued away.**
12. **Correction pass 3 introduced one thing that can be wrong in a new way: the slice renumbering.**
    The reversal moves the gate off "slice 1", so every slice is renumbered (§0.2's crosswalk, and
    `design-review-gate.md` §0.2 carries the long form). **Renumbering is mechanical and is exactly
    where a citation pass produces new errors**, so it was applied as literal, counted replacements
    and the whole diff was re-read. **Two known consequences a reviewer should check first:** the
    quotes of `.decisions/7f3e2a95…`'s `precondition` say "sub-slice 1a" and "slice 1", which under
    this revision's numbering are **2a** and **slice 2** — every such quote carries an explicit gloss
    (`design-review-gate.md` §0.2, §5.2.2, §5.3), and **one decision quote I found in this document's
    own §12 tail was left unglossed and is corrected in §12.1**; and any reader comparing this
    revision against `225ee5c`'s review must use the crosswalk rather than the numbers.
13. **Correction pass 3 found a citation the review did not raise** — `implementation_inflow.dart:
    1543-1578`, in a 440-line file (§12.1, PASS3-1). **Recorded because it is the L3 pattern in its
    purest form and it was in *this lane's* artifacts**, and because a review that confirms ~60
    citations should not be read as a guarantee about the ones it does not name. **The lesson, which
    is the one this document has now learned four times: a `file:line` that looks well-formed invites
    acceptance. It is not evidence. It has to be opened.**
14. **~~Correction pass 4 made a product-facing reduction this lane decided rather than escalated, and
    a reviewer or the operator should reverse it if they disagree.~~ — **THE OPERATOR HAS REVERSED IT.
    `.decisions/5a90c1d3-8e47-4b26-9f0c-3d7a5b2e6c19.yaml` (RESOLVED, `FOURTH_CHOICE_VALUE`, operator,
    2026-10-17T15:10:00Z) restored the fourth answer. This item is superseded in place and its stale
    text is preserved verbatim, because it is the record of the exact error the decision names — and
    because "a flagged judgement is not a discharged obligation" cuts both ways: pass 4 flagged this
    rather than escalating it, which was the right call, and flagging it is why it was reversible.**
    ~~**The park's menu is THREE answers where the previous pass specified FOUR.** The forcing argument is a data-model fact, not a
    preference: `HumanDecisionOption` carries no `decisionType`
    (`platform_contracts/lib/src/types/human_decision.dart:156-159`), one decision carries one type,
    and every option resolves through it (`durable_workflow_engine.dart:758-761`) — **so the whole
    menu must live on the new type, and the number of coherent answers is bounded by how many of the
    NINE `HumanDecisionChoice` values (`enums/human_decision.dart:33-41`) carry park meanings.** They
    do not support four: `reject` and `waive` are wrong on their face (**a park answer that "waives"
    the gate it exists to enforce is worse than the missing answer**), and `defer`, `fixed`,
    `stillBroken`, `partiallyFixed` are verification vocabulary. **So one answer is merged rather
    than forced onto an ill-fitting choice**, and the merged-away target is chosen on evidence:
    **`designNotRequired` is the target `design-review-gate.md` §5.2.1 itself labels a defect** —
    *"re-enters triage; walks back to `agentCompleted`; refused again; parked again. **A cycle —
    visible, durable, and dispatching nothing.**"* **The cost is that the operator is offered one
    fewer answer.**
    - **Why this lane may decide it:** HD-1's `delegated` clause puts *"what happens to an item that
      never gets one"* with the design lane, and the park's menu is exactly that; the park does not
      exist, so no shipped surface changes; and `.decisions/3e5a7c26…` re-points this menu by
      mandating a new type whose arms are *"designed for it"*.
    - **Why it must not be widened instead:** the only way to keep four answers is a **new
      `HumanDecisionChoice`**, and `3e5a7c26…` authorised a new `HumanDecisionType`, **not** a new
      choice. **`platform_contracts` is outside that decision's scope, so adding a choice is exactly
      the widening the correction spec forbids.** **The merging is what keeps this pass inside the
      authorisation.** If four answers are wanted, the correct next step is a second human decision on
      `HumanDecisionChoice` — named here, not taken.~~

    **What the operator said, quoted rather than paraphrased, because the reasoning is the finding:**
    *"Nine **existing** `HumanDecisionChoice` values cannot express four coherent answers, and the
    design lane merged 're-triage' into 'put it back in the lane', leaving three. That silently
    removed a genuine operator choice: re-triaging a parked item would become cancel-and-refile,
    losing the item's history and the durable reason it was parked. **HD-1 delegates the park's
    handling to the design lane, but a product-facing menu reduction is not that delegation.**"*

    **The two errors in the withdrawn text, isolated, because both are generalisable and one is the
    kind of mistake a design lane should be slowest to make:**
    - **The delegation was read more broadly than it is written.** HD-1 delegates *"what happens to an
      item that never gets one"*; this item used it to justify **removing an answer from that item's
      menu**. **A delegation about handling a case is not a delegation to change what the case offers
      the human**, and the operator says so in one sentence.
    - **An artefact of a shared enum was treated as a constraint of the design.** *"The number of
      coherent answers is bounded by how many of the NINE values carry park meanings"* is true and
      worthless: the count of answers is a function of **how many enum values exist**, and a design
      lane may propose that a tenth be added. **Pass 4 treated the current size of `platform_contracts`
      as a fixed term in a product decision, merged two answers to fit, and then reported the
      reduction as resolved** — which is precisely what the decision's `invariant` forbids: *"A design
      that cannot express them must escalate, as this one did, rather than merge two into one and
      report the reduction as resolved."* **Note the tense: "as this one did" — the operator is
      characterising the escalation as the correct behaviour, and pass 4 did not escalate.**

    **What survives from this item and is used by pass 5:** the reasoning that `reject` and `waive`
    are **wrong on their face** for a park, and that `defer`, `fixed`, `stillBroken` and
    `partiallyFixed` are verification vocabulary carrying no park meaning. **All six rejections
    stand** — the answer that was missing was missing, and the remedy was a tenth value, not one of
    these six. **The finding produced this correction; the conclusion drawn from it is withdrawn.**
15. **Pass 4 found two things this lane's own review checklist did not, and that is a finding about
    the checklist.** The dispatch's orphan-`1.5` sweep was clean on both `.md` artifacts and **missed
    the metadata register twice** (H-3), and this pass's own sweep found a **third** stale claim in a
    `.md` artifact the same check had passed over (§4.2's *"No new `HumanDecisionType`"* —
    §12.2, PASS4-1). **A grep finds an orphaned string, not a stale claim.** The five instances of
    the L3 pattern in this artifact set are counted and named in `design-review-gate.md` §6's
    closing note, and **two of them were in this artifact's own correction machinery.**

---

## 14. Verification

### 14.1 Executed by Revision 1 at `e3634a0` — not re-run here

```
$ dart test lib/src/triage/work_entry_test.dart -r compact
00:03 +37: All tests passed!                      # 37 tests, incl. "the parked feature is
                                                   #   invisible to the category-blind scheduler"

$ dart test -r compact                            # packages/qa_orchestration, whole package
00:01 +28: All tests passed!                      # 10 qa_orchestration + 18 product_qa_contract

$ rg "gateResults" packages apps
  3 hits in packages/workflow_engine/lib/src/validation/guard_conditions.dart
  7 hits in *_test.dart
  0 producers in production code
```

**Not re-run by this revision** (§13.8): no production code changed, and none of this revision's
claims rests on a test result.

### 14.2 Executed by THIS revision at `c8fd361` — every finding re-derived from the tree

```
$ grep -rn "completionInflowFrom" packages apps --include='*.dart'
  packages/scheduler/lib/src/implement_feature.dart:117:  completionInflowFrom: {WorkItemState.agentCompleted},
  (+ runnable_work.dart:49,128,132 — the field itself — and tests)      # H1: one production line

$ grep -n "sources.contains(item.state)" packages/scheduler/lib/src/scheduler.dart
1522:      if (!sources.contains(item.state)) continue;                  # H1 (spec said :1527)

$ grep -rn "transition\|to:" … | grep implementationReady                # H1: no production caller
  every `to: WorkItemState.implementationReady` call site is in a *_test.dart

$ grep -n "WorkItemState.agentCompleted, WorkItemState." work_item_transitions.dart
340 (implementationReady), 343 (reviewInProgress), 347 (designInReview)   # §4.3: NO edge to waitingForHumanDecision

$ grep -n "(WorkItemState.reviewApproved, WorkItemState.qaInProgress)"
work_item_transitions.dart:651                                            # H2

$ grep -rn "reviewApproved\|qaInProgress" packages/scheduler/lib/src/triage_defect.dart
  (no output)                                                            # H2: in no entryStates

$ grep -rn "to: WorkItemState.reviewApproved\|to: WorkItemState.qaInProgress" packages apps
  (no output outside *_test.dart)                                         # H2: no production caller

$ sed -n '2860,2871p' apps/server/lib/src/review/engineering_review_gate.dart
  if (item.state == WorkItemState.agentCompleted) { if (standDown.owns) { …log…; return; } }   # B1

$ sed -n '2210,2229p' …/engineering_review_gate.dart                     # B1: returns owns: true unconditionally

$ sed -n '1416,1421p' apps/server/lib/server.dart                       # B1: the stand-down, in prose

$ grep -n "PostgresDesignGovernanceStore" apps/server/lib packages/      # F-52, re-confirmed
  only its own declaration at postgres_design_governance_store.dart:9-10

$ grep -n "lane_g_triage_qa_contract" → packages/qa_orchestration/lib/src/   # L1
```

No command in that lane mutated state. No docker, no compose, no `psql`.

### 14.3 Executed by the correction pass at `90b6f5f` — every finding re-derived again

```
$ sed -n '211,233p' packages/workflow_store/lib/src/durable_workflow_engine.dart
  blockingReason: to == waitingForHumanDecision ? context['blockingReason'] ?? … : null,   # B-1 :222-225
  blockingHumanDecisionId: to == waitingForHumanDecision ? … : null,                       # :215-221
  metadata: metadataMerge == null ? item.metadata : {...?item.metadata, ...metadataMerge}   # :230-232

$ sed -n '614,622p;651,653p' …/durable_workflow_engine.dart
  _policy.evaluateWorkItemTransition(from: item.state, to: waitingForHumanDecision, …)     # P4 as ITS edge
  blockingHumanDecisionId: id,  blockingReason: question ?? 'Awaiting human decision'       # ← THE WRITER

$ sed -n '816,841p;854,857p' …/durable_workflow_engine.dart
  saveHumanDecision(resolved); if (!unlock.isValid) throw …;   # :817 then :821 — item NEVER moved
  blockingHumanDecisionId: null, blockingReason: null           # :856-857 — unreachable on refusal

$ sed -n '563,580p' …/durable_workflow_engine.dart            # re-park refused for a RESOLVED decision
$ grep -n "(WorkItemState.waitingForHumanDecision," work_item_transitions.dart
  :73 :83 :93 :425 :435 :445 :528 :599 :641 :716 :723 :744 :754   # NO edge to reviewInReview…

$ sed -n '97,99p;40,42p' apps/server/lib/src/triage/stalled_work_item_gate.dart
  "agentCompleted has no direct edge to waitingForHumanDecision …"
  "Picking a different type here would have meant adding an edge … not this lane's to make."

$ sed -n '1582,1599p;1740,1746p;1809,1813p;1823,1843p' packages/scheduler/lib/src/scheduler.dart
  :1582-1599 the four per-item READS ("could not be read well enough …")          # M-2
  :1746    context: const {'agentAvailable': true, 'capabilitiesMatch': true}      # M-3 const literal
  :1809-1812 metadataMerge: { … }                                                # M-3 precedent
  :1823-1833 WorkflowTransitionRejectedException catch → "the item moved while …"

$ sed -n '604,624p' work_item_transitions.dart                                    # M-4 / L-1
  SIX pairs (:604-623); :624 is decisionActorIsHuman(); :595 says "five" (stale)

$ grep -n "gateId:\|required:" packages/qa_orchestration/lib/src/lane_g_triage_qa_contract.dart
  :175 required: true | :202 required: true | :222 required: false                # L-2

$ sed -n '2898,2905p' apps/server/lib/src/review/engineering_review_gate.dart
  else { logger?.call('engineering-review-missing-artifact-unexpected-state', …); return; }  # L-3

$ cat .decisions/7f3e2a95-6c81-4d70-b215-8e94a0c7d382.yaml
  RESOLVED · READING_B_CLAUSE_COVERS_EVERY_ROUTE · operator · 2026-10-17T13:40:00Z   # H-3

$ grep -rn "HumanDecisionType.escalation" --include='*.dart' apps packages | grep -v test
  routing arms + durable_workflow_engine.dart:996 only — RAISED NOWHERE IN PRODUCTION
  # CORRECTED IN PASS 3 (L-A). The RESULT is right; the label "escalation-index computation"
  # was wrong. See §14.4.
```

### 14.4 Executed by correction pass 3 at `2b182fd` — the reversal's citations, re-derived

```
$ sed -n '564,584p' packages/workflow_store/lib/src/durable_workflow_engine.dart
  564-565  the guard: at waitingForHumanDecision && blockingHumanDecisionId != null
  569-570  same type AND !existing.status.isResolved      ← a RESOLVED id is the throw case
  571      return existing;                                  ← idempotence arm
  573-583  throw WorkflowTransitionRejectedException( … )
  581      reason: 'Work item is already waiting for a blocking human decision'
  # M-C: this is the throw a single-call park helper hits on a P3 entry. §5.1.1a.

$ sed -n '215,221p' packages/workflow_store/lib/src/durable_workflow_engine.dart
  219-220  : identical(to, item.state) ? item.blockingHumanDecisionId
  221      : null          ← P2/P3 CHANGE the state, so the id is nulled. That null is the
                              precondition requestHumanDecision tests at :564-565.
  # M-C: step 1 is not a formality; it is the only thing that makes step 2 possible.

$ sed -n '141,142p;168,174p' apps/server/lib/src/endpoints/workflow_endpoints.dart
  141-142  try { final workItem = await service.resolveHumanDecision(
  168-174  } catch (error, stackTrace) { … logger.error('workflow.resolve.failed', …);
            Error.throwWithStackTrace(error, stackTrace); }   ← GENERIC. Does NOT discriminate
            WorkflowTransitionRejectedException. THAT DISCRIMINATION IS THE WORK. (M-D)

$ sed -n '2040p;2073p' apps/server/lib/src/services/control_plane_service.dart
  2040  Future<WorkItem> resolveHumanDecision({ … })
  2073  final workItem = await workflowEngine.resolveHumanDecision( …
  # M-D: the full chain, every hop with a line number. A StateError is thrown at :2065 for a
  # DIFFERENT refusal (verdict-absent choice, :2048-2071, nothing written) — must keep propagating.

$ sed -n '228,234p' packages/workflow_engine/lib/src/transitions/human_decision_routing.dart
  233  return escalationTargetFor(decisionType, choice) == target;   ← routesToEscalation

$ sed -n '987,1005p;1007,1021p' packages/workflow_store/lib/src/durable_workflow_engine.dart
  987-1005  _isReWorkDecision( … )  :996 decisionType == HumanDecisionType.escalation
  1007-1021 _isEscalationTransition( … ) :1016 → HumanDecisionRouting.routesToEscalation
  # L-A: :996 is inside _isReWorkDecision, which drives nextTriageAttempt (:788-792, :384).
  # The escalation-INDEX predicate is :1007-1021, which delegates and therefore never names
  # the enum — which is exactly why the grep finds only :996.

$ sed -n '151,162p' packages/workflow_engine/lib/src/transitions/human_decision_routing.dart
  159-162  "a value here that disagrees with targetFor does not error — it silently stops the
            escalation index advancing and changes the shape of the audit trail"
  # NOTE: its own comment at :154 cites durable_workflow_engine.dart:979 for _isEscalationTransition,
  # which is at :1007. The repository's comment points 28 lines off. RECORDED, not corrected —
  # packages/** is PROHIBITED_PATHS. (§12.1 PASS3-3)

$ wc -l packages/scheduler/lib/src/implementation_inflow.dart
  440 packages/scheduler/lib/src/implementation_inflow.dart
  # PASS3-1: the artifacts cited :1543-1578 of this file. It is 440 lines long. Correct range: :124-126.

$ sed -n '124,126p' packages/scheduler/lib/src/implementation_inflow.dart
  "It throws INSIDE `_routeOneCompletion`'s per-item guard, which turns that throw into 'leave
   this one item alone and say so', rather than out of `tick`, which would cost the whole lane
   its pass."                                                        ← the property, exactly

$ sed -n '1582,1599p' packages/scheduler/lib/src/scheduler.dart
  :1582 try { … } :1587 on Object catch (error) { … :1592-1594 'this item could not be read well
  enough to decide whether it should be reviewed or implemented ($error) …' :1599 }
  # Confirms the previous pass's M-2 correction of the park's catch site, to the line.

$ sed -n '228,234p' apps/server/lib/src/triage/stalled_work_item_gate.dart
  } on WorkflowTransitionRejectedException catch (e) { … return StallGateOutcome.notParkable; }
  # M-D's shipped precedent for the type-discriminated catch the route-3 caller needs. The range
  # was read and does state the property it is cited for.

$ sed -n '199,214p' apps/server/lib/src/triage/stalled_work_item_gate.dart
  options: [ HumanDecisionOption(optionId:, label:, description:) x2 ], recommendation, blocking
  # The shape §6 sub-slice 1b copies for the widened park option list.
  # PASS 4 NOTES, having re-read it: optionId is 'rework' at :201 and 'cancel' at :207 — both are
  # HumanDecisionChoice.wire values. That correspondence is the convention G16/G17(c) now assert.

$ sed -n '1267,1320p' docs/engineering/FOLLOW_UPS.md
  §16 F-55 "the park's human surface has no 'do the design review' answer" — status OPEN,
  recorded 2026-10-17, referenced before it existed. §16 F-56, the process note.
  # M-A: F-55 EXISTS as of 0bfb6fb. Every one of the previous pass's six citations now resolves.
  # F-55's own citations (:121, :132-135) were checked against the tree and are correct.
  # docs/** READ ONLY. Not modified.

$ cat .decisions/b81f40c7-2a96-4e38-bd51-6c07e9f3a824.yaml
  RESOLVED · HUMAN_SURFACE_FIRST · operator · 2026-10-17T14:10:00Z
  authority_note: "overridden on AUTHORITY, not on reasoning"
  invariant: "NO item may be parked at designReviewRequired before the decision raised there
  offers a 'do the design review' answer … must be asserted, not assumed."   → G17
```

**No command in this pass mutated state. No docker, no compose, no `psql`, and — per `AGENTS.md`'s
shared-Docker-state rule — no Docker or Compose command of any kind, not even a read-only one. The QA
stack was not touched.**

---

### 14.5 Executed by correction pass 4 at `e1c191b` — the fork's data model, re-derived

```
$ git rev-parse --short HEAD && git status --porcelain --untracked-files=no && git diff --quiet HEAD
  e1c191b
  (empty)                                    # tracked tree CLEAN. Verified, not assumed.
  0
  # The precondition. A previous attempt at this dispatch was cancelled mid-flight and the Manager
  # reverted it, so this was checked specifically. All porcelain entries were UNTRACKED (??) and
  # none is inside design/qa-contracts-feature-remediation/.

$ cat -n packages/platform_contracts/lib/src/enums/human_decision.dart
  1-20   enum HumanDecisionType — NINETEEN values
  2      designApproval('design_approval')
  22-24  const HumanDecisionType(this.wire); final String wire;
  26-29  fromWire → values.firstWhere(... orElse: throw FormatException)
  33-41  enum HumanDecisionChoice — NINE values: approve, reject, waive, rework, cancel, defer,
         fixed, stillBroken, partiallyFixed
  # B-1a: a new TYPE is added at :1-20 with its wire in the existing constructor at :22-24.

$ sed -n '148,168p' packages/platform_contracts/lib/src/types/human_decision.dart
  148  class HumanDecisionOption extends Equatable {
  156  final String optionId;
  157  final String label;
  158  final String? description;
  159  final bool? recommended;
  # B-1a's load-bearing fact, verified: NO decisionType. The old G17 asked this class for one.

$ sed -n '755,761p' packages/workflow_store/lib/src/durable_workflow_engine.dart
  758  final target = HumanDecisionRouting.targetFor(
  759    decision.decisionType,
  760    effectiveChoice,
  761  );
  # One decision, one type, resolved ONCE. Every option at the park routes through this call.

$ sed -n '707,709p;739p' that same file
  707-709  final effectiveChoice = alreadyResolved && decision.choice != null ? … : choice;
  739      resolvedOptionId: _resolvedOptionId(decision, effectiveChoice),
  # `choice` is an ARGUMENT to resolveHumanDecision — it is NOT derived from optionId.

$ sed -n '1106,1114p' that same file
  1110-1112  final option = decision.options?.where((o) => o.optionId == choice.wire).firstOrNull;
  1113       return option?.optionId ?? choice.wire;
  # The convention every production raiser follows, AND its silent hole: if no option matches, the
  # decision records an optionId the operator was never shown. G16/G17(c) now assert it.

$ sed -n '66,84p;88,93p;121p;132,137p;192,216p;219,225p' \
      packages/workflow_engine/lib/src/transitions/human_decision_routing.dart
  66-84    "WHICH RETARGETS NEED escalationTargetFor MOVED WITH THEM" + the per-pair table at 73-79
  88       static WorkItemState? targetFor(          (the method spans :88-138)
  93-94    (designApproval, approve) → designApproved
  121      (_, cancel) → cancelled                  ← covers EVERY type. The park's stop arm: free.
  132-133  (escalation, approve) → designNotRequired
  134-135  (escalation, rework) → planning
  192      static WorkItemState? escalationTargetFor( (the method spans :192-216)
  196-199  if (choice != reject && choice != rework) return null;   ← protects approve/cancel
  213      (designApproval, _) → designInReview;      ← keyed on TYPE; does NOT cover the new type
  214      _ => null,                                ← the ONLY thing keeping (newType, rework) inert
  219-225  routesTo = targetFor(type, choice) == target

$ sed -n '420,428p' packages/workflow_engine/lib/src/validation/guard_conditions.dart
  420-424  matchesResolution = decision != null && decision.status.isResolved && …
  425-428    && allowed.contains((type: decision.decisionType, choice: decision.choice!));
  # B-1b's finding, verified: a STRICT WHITELIST. targetFor returning designApproved moves NOTHING
  # unless the edge's allowed set carries the pair. This is the registration site the fork's own
  # consequence does not name.

$ sed -n '73,82p;641,650p' packages/workflow_engine/lib/src/transitions/work_item_transitions.dart
  73-82   (waitingForHumanDecision, designApproved):
            actorAllowed + blockingHumanDecisionResolved({ (designApproval, approve) }) + human
  641-650 (waitingForHumanDecision, planning):
            actorAllowed + blockingHumanDecisionResolved({ (escalation, rework) }) + human
  # The two edges the new type's arms must be admitted to. Neither admits it today.

$ grep -n 'WorkItemState.waitingForHumanDecision,' work_item_transitions.dart
  :73 :83 :93 :425 :435 :445 :528 :600 :641 :716 :723 :744 :754
  # THIRTEEN out-edges, and NONE is `cancelled`. :600 is the SECOND LINE of the route-3 row, whose
  # opening paren is at :599 and which spans :599-602 — so a grep for the single-line form returns
  # TWELVE and silently drops the very edge this design's route 3 is about. PASS 4 MADE THAT MISTAKE
  # IN THIS VERY TRANSCRIPT AND CORRECTED IT BEFORE COMMITTING. §5.1.1b's list of thirteen stands.

$ sed -n '783,791p;806,811p' that same file
  786-791  _isGenericEscape: to == cancelled || to == terminated, for any non-terminal state
  806-811  getGuards' escape branch: [actorAllowed([orchestrator])]
  # ...so the park's stop answer is admitted WITHOUT any registration. `:640` says so in the file's
  # own words: "stopping is already covered by the generic orchestrator escape to `cancelled`,
  # which must not be narrowed here."

$ grep -rn -A3 'HumanDecisionOption(' --include='*.dart' apps packages | grep optionId | grep -v _test
  optionId: 'rework' / 'cancel' / 'approve' / 'reject' / 'fixed' / 'stillBroken' / 'partiallyFixed'
  # All HumanDecisionChoice.wire values. The convention G16 and G17(c) now assert.

$ cat .decisions/3e5a7c26-4b19-4f83-a0d7-6c29b8f1e540.yaml
  RESOLVED · NEW_HUMAN_DECISION_TYPE · operator · 2026-10-17T14:40:00Z
  consequence: "Its routing arms MUST be registered in the same change … a new type whose arms are
                not registered fails with no error message."
  invariant:  "The park's decision type must have an arm reaching designApproved, and the artifact's
                assertion G17 must be rewritten against the REAL data model."
  # READ IN FULL.
```

**No command in this pass mutated state. No docker, no compose, no `psql`, and — per `AGENTS.md`'s
shared-Docker-state rule — no Docker or Compose command of any kind, not even a read-only one. The QA
stack was not touched.**


---

## 15. Disposition

`DESIGN_REVISION_COMPLETE`.

**Not** because the two path-specific contracts exist. They do not, and §3 and §13 say why with
evidence — now for two different and separately evidenced reasons.

Complete because the two things the Manager delegated and that *can* be specified honestly from the
repository now **are**:

- **The evaluator**, specified to the point of naming its insertion points, its guard-context
  contract, its `config` key vocabulary, and the ordering constraint that makes wiring it safe —
  plus the findings (§2.1, §2.1a, §2.2) that change what "wire it in" would mean.
- **The design-review gate**, specified as one guard on the two edges of `implementationReady`
  that have callers, satisfied by a store query that already exists and is already tested, with the
  dead-end question answered **by a specified park** rather than by assertion — and with the
  reading of HD-1 **applied as a recorded human decision** (`.decisions/7f3e2a95…`) rather than left
  for a reviewer to adjudicate.

**And because the correction that matters most is uncomfortable, twice.** Revision 1's central claim
— *"a refused guard leaves the item where it was, which is not a dead end"* — was **false**, and
false in the one place where it was load-bearing: the review drain stands down, so the refusal
repeats every tick under a green suite (G1/G2 assert only that the item does not reach
`implementationReady`, which a dead end satisfies).

**Then revision 2 fixed it, and made the same error in the same shape.** It specified the park and
asserted, in three artifacts, that the park *"carries a durable reason"* — citing a range of
`transition` that writes `blockingReason: null`. **So B1 survived under a new state name**, and the
correction to B1 was itself the second instance of the defect B1 is about. **The lesson generalises
past this design and past this lane:** a refused guard is only as safe as the exit its state has —
**and a park is only as safe as what it carries**, which is a separate question from where it puts
the item. G7 asked the first; nothing asked the second, until G14.

**The mechanism for the fix is worth naming because it is the opposite of the one revision 2
assumed.** Revision 2 thought a durable reason needed plumbing. **It needed none**:
`DurableWorkflowEngine.requestHumanDecision` already writes both `blockingReason` and
`blockingHumanDecisionId` — but only for its own `waitingForHumanDecision` landing, and `transition`
— which the park hop uses — writes `null` for anything else. **The correct fix was to use the API
that already does the right thing, not to add one that does not, and that is why
`packages/workflow_store/**` is untouched.**

**And the finding that recurs:** `work_item_transitions.dart` declares edges that no caller takes —
`reviewApproved -> qaInProgress`, `agentFailed -> implementationReady`, and (per
`design-review-gate.md` §5.2) four decision pairs that route to `implementationReady`. Revision 1
read the table as a map of what happens. It is a map of what *may* happen. **That is how five live
contradictions survived a review, and it is why the assertions in this revision are written to fail
on absence rather than on presence.**

---

## 16. What an independent reviewer should check, in priority order

**Reordered by correction pass 3 and then by correction pass 4. Three questions are no longer on this
list because they are decided: the reading of HD-1 (`.decisions/7f3e2a95…`), the sequencing
(`.decisions/b81f40c7…`) and — since pass 4 — **the shape of the park's decision**
(`.decisions/3e5a7c26…`, `NEW_HUMAN_DECISION_TYPE`).** What needs checking is whether this design
*applies* all three faithfully, and — for the reversal and the shape — whether the mechanisms the
operator left to this lane are the right ones.

**The reversal's merits argument is not on this list either, and that is deliberate.** §0.2 keeps it
because the decision's own `authority_note` says it *"is recorded and is not dismissed"*. **Re-arguing
merits against a decision made on authority changes nothing without a new human decision**, so
spending a review on it would be the reviewer's time spent in the wrong place.

1. **G17(a)/(b)/(c) — does it state the invariant the reversal exists to enforce, or a weaker
   restatement?**
   `.decisions/b81f40c7…`'s `invariant`, verbatim: *"NO item may be parked at `designReviewRequired`
   before the decision raised there offers a 'do the design review' answer … must be asserted, not
   assumed."* **The previous single G17 asserted this over a parsed `HumanDecisionOption` list asking
   for a `decisionType` field that does not exist (`human_decision.dart:156-159`), and asserted
   nothing about `blockingHumanDecisionResolved` — which is the guard that decides whether the answer
   moves the item at all (`guard_conditions.dart:425-428`). It could not go green, and it could not
   go red on the reachability half.** **It is now three obligations** — G17(a) the arm exists *and* is
   admitted, G17(b) the park may not acquire an in-edge while (a) is red, G17(c) the raising call site
   offers it. **The seams a reviewer would have chosen as alternatives — the option list, the edge
   set, the routing table — are all three obligations of one assertion.** **If a reviewer thinks the
   split is wrong, or that the invariant belongs somewhere else entirely, that is the finding to
   make** — and the specific thing to press is whether G17(b) really is the ordering assertion, or
   whether the ordering needs a gate of its own that fails *before* 2d rather than at it. **This is
   first because it remains the only load-bearing property in the pass whose assertion this pass
   rewrote**, and because the rewrite was forced by a defect the previous two passes shipped.
2. **`design-review-gate.md` §6 sub-slice 1a — is the arm set right, and are the registration
   sites all of them?** `.decisions/3e5a7c26…` ordered the human surface first and **has now decided
   the shape** — a new `HumanDecisionType` — so the question is no longer "new enum value or
   `designApproval`?". **It is now: is `HumanDecisionType.designReviewRequest` with four answers
   (`approve → designApproved`, `rework → planning`, `reTriage → designNotRequired`,
   `cancel → cancelled`) the right design, and are the three `blockingHumanDecisionResolved` whitelist
   admissions (`work_item_transitions.dart:75-80`, `:643-648`, `:528-546`) plus the
   `decision_choice.dart` presentation registration sufficient?**
   **Three things a reviewer should press hardest — and the first is now a different question than it
   was:**
   **(a) the arm set, and specifically the fourth answer's TARGET.** `.decisions/5a90c1d3…` ruled the
   menu is four; the design lane chose **`designNotRequired`** for `reTriage`, which is the state
   §5.2.1 itself calls a non-terminating cycle. **That is the one arm whose target this document has
   already called a defect, and the reviewer should press whether "re-triage" is the right thing to
   route an operator who wants the item reconsidered — or whether some other target expresses it
   without the loop.** The routing precedent for the choice is the routing table's own
   (`(escalation, approve) → designNotRequired`), and the operator's stated motive is that re-triage
   *"would become cancel-and-refile, losing the item's history"*, which this arm satisfies — **but
   the loop is real and the reviewer should confirm it is the one being bought.**
   **(b) the `escalationTargetFor` disposition per arm, especially that `(designReviewRequest,
   rework)` must get NO arm** — `rework` is the one choice `:196-199`'s short-circuit does not
   protect, so its inertness rests on `_ => null` at `:214`, and an implementer who "completes the
   lockstep" would start escalation accounting silently on a re-plan answer. **Pass 5 adds the
   short-circuit table itself, which shows `reTriage` is on the PROTECTED side** — so the fourth
   answer does not create a fourth unprotected arm — **and that the hazard for `reTriage` is the
   EDGE, not the arm**: `designNotRequired` carries an `escalationIndexWithinLimitForDecisionTypes`
   bound (`:559-563`) that does not include `designReviewRequest`.
   (c) whether `reTriage` should be bounded by that escalation guard at all.** **This pass says NO,
   on the edge's own stated rule** (`:553-558`: *"inventing a bound here would be new policy rather than
   a lockstep move"*, with four other types already unbounded there) — **but `reTriage` is an
   operator-invoked loop by construction, unlike `escalation`, so the precedent is weaker than it
   looks. A ceiling on re-triage is a product decision this lane has flagged rather than taken
   (R14), and it is the first thing a reviewer or the operator should overturn.**
   **(d) THE SCOPE DERIVATION — this is the claim on which "the other decisions are unaffected" rests,
   and it should be checked before the arm set, because if it is wrong the design must escalate
   instead.** `.decisions/5a90c1d3…`'s `scope_warning` requires that the new value *"must be offered
   only by the design-review park's decision type"*, and says that if the enum cannot carry a per-type
   option set *"that is itself a finding to escalate rather than work around."* **This pass concluded
   it CAN, from four verified facts** (`design-review-gate.md` §6 1a): the offered set is a property
   of the **decision instance** (`HumanDecision.options`, `DecisionContext.availableOptions`); the
   operator UI builds its menu **only** from that set (`decision_detail_bloc.dart:30-37`); and
   **`HumanDecisionChoice.values` is enumerated nowhere in `lib/`** — all nine sites are in `test/` —
   so nothing renders a value a decision did not list; and a per-type label layer already exists in
   production (`decisionChoiceLabel(…, decisionType:)`, `decision_choice.dart:32-57`).
   **A reviewer who disagrees with any one of those four should say so, because the whole
   no-escalation decision rests on them.** **The residual this pass flagged rather than solved is the
   fourth registration site** — `decision_choice.dart:12-19`'s `knownDecisionChoices` is a hardcoded
   six-value set against a ten-value enum, so without adding `re_triage` there the operator sees caller
   prose instead of a mapped label on both surfaces (`decision_detail_bloc.dart:38`,
   `needs_you_bloc`). Routing is unaffected; presentation is. **`apps/**` is `PROHIBITED_PATHS`, so it
   is specified here and recorded for the Manager, not corrected.**
3. **`design-review-gate.md` §5.1.1a — is the "the order is load-bearing" argument right?** This
   pass states that step 1's `transition` is what clears the resolved blocking id that would make
   step 2 throw (`durable_workflow_engine.dart:219-221` nulls it; `:564-584` throws for it), and that
   a single-call helper is therefore unimplementable on a P3 entry. **Read those two ranges. This is
   the strongest positive argument for the distinct state that this artifact has**, and pass 3's
   review **verified it exactly** (`:564-565`, `:569-570`, `:571`, `:573-583` with the reason at
   `:581`). **It is not rebuilt in pass 4.**
4. **`design-review-gate.md` §5.1.1b — the rejection of the recommended option.** The load-bearing
   *negative* claim: `waitingForHumanDecision` cannot be the park. It rests on
   `durable_workflow_engine.dart:816-841` (the decision is saved resolved, then the item is never
   moved) and `:564-584` (a resolved blocking decision cannot be re-raised). **If the reasoning is
   wrong, the park shape is wrong and P3 exists for no reason.** **The independent review confirmed
   this, so it is fourth rather than first — but it remains the claim everything else rests on, and a
   confirmation is not the same as this lane having shown it.**
5. **`design-review-gate.md` §5.1.2 — is the route-3 chain right, and is the discrimination
   identified as work?** The chain is now cited hop by hop
   (`workflow_endpoints.dart:141-142` → `control_plane_service.dart:2040`, `:2073` → engine
   `:758-761`, `:820-841` → `workflow_endpoints.dart:168-174`). **The claim is that the existing catch
   is generic and that telling the engine's `WorkflowTransitionRejectedException` from
   `control_plane_service.dart:2065`'s `StateError` is part of the sub-slice.** A reviewer who thinks
   that discrimination belongs in the service rather than the endpoint should say so.
6. **G14, G15, G16 — and G16's widening.** Whether G14/G15 are the right assertions for the property
   revision 2 asserted and did not check. **If a reviewer thinks G14 is insufficient — e.g. that
   asserting `blockingReason` non-null does not prove a human can act on it — that is the finding to
   make.** **G16 was changed by this pass** from "exactly `escalation`'s three — no fourth" to "exactly
   the set §6 1b specifies", because the previous form would have failed the moment slice 1 landed.
   **A reviewer should check that the widened form still pins something.**
7. **`design-review-gate.md` §5.2 — is Reading B applied completely?** A decision chooses a *scope*,
   not a mechanism. Specifically: is the route-3 guard correctly placed, is P3 correctly justified,
   and is `G5′`'s **six** the right number.
8. **`design-review-gate.md` §6 sub-slice 2b — is `scheduler.dart:1746` really the blocking
   `const`?** The sub-slice depends on that literal becoming a computed map. If a caller already
   computes it elsewhere, the sub-slice is over-scoped.
9. **§2.1 and §2.1a against the tree.** Whether the corrected dead-end locations are right. These
   were asserted by the review and adopted here; if either is wrong, slice 3c's shape is wrong.
10. **§3.3's per-path split**, and **§6's M12.** Whether declining design remediation on M10 is still
    the right call now that the reasoning is stated rather than inferred; and whether restoring the
    brief's M2 is complete or a partial repair.
11. **THE DISCIPLINE, not the content — and by pass 5 this is the SEVENTH instance, not the third,
    and two of the seven are in the mechanism that exists to prevent them.**
    §12 lists **thirteen pass-2 corrections (all thirteen of them this lane's own errors)**, §12.1 adds
    **eight pass-3 corrections**, **§12.2 adds nine pass-4 rows** and **§12.3** pass-5 rows.
    **THE COUNTS ON THIS LINE ARE GENERATED, NOT RESTATED — and that is the fix for the defect this
    line records, applied to itself.** Derive them with
    `for r in '## 12. Corrections:### 12.1 ' '### 12.1 :### 12.2 ' '### 12.2 :### 12.3 ' '### 12.3 :## 13.'; do
    awk -v a="${r%%:*}" -v b="${r##*:}" '$0 ~ a,index($0,b)>0' design-revision.md | rg -c '^\| \*\*'; done`
    **As of `b63c771`+this pass they are THIRTEEN, EIGHT, NINE and SEVEN.** A pass that appends a row
    must re-run that, not edit this sentence — which is precisely what pass 5 got wrong four times
    (§12.3, PASS5-5) and then got wrong a fifth time while writing the cure (PASS5-7). **THE COUNTS ON THIS LINE HAVE NOW BEEN WRONG FOUR TIMES, AND PASS 5 FOUND THE FOURTH
    INSIDE THE ROW THAT CORRECTED THE THIRD (PASS4-2).** It previously read *"nine of them this lane's
    own errors, six of one kind"*, which §12.1's PASS3-5 and §12's own classification had **already**
    corrected to ten and eight — a sibling row quoting pre-correction figures out of the register that
    had fixed them. **Pass 4 then corrected two numbers in that row and left the row-counts stale:
    "eleven pass-2 corrections" and "six pass-3 corrections" were both wrong before pass 4 appended a
    row to either register — and pass 4 appended one to both.** The numbers above are counted, not
    estimated.
    **The pass-3 set includes one the review did not raise** — `implementation_inflow.dart:1543-1578`,
    cited twice for a load-bearing property in a 440-line file — **and the pass-4 set includes THREE
    the review did not raise**: §4.2's live *"No new `HumanDecisionType`"*, §16's own stale count,
    and the two metadata rows (H-3). **And the pass-5 set includes four more the review had no chance
    to raise**, two of which are in the correction machinery itself: §12.3's PASS5-2 (this very count,
    stale in three prose sites), PASS5-3 (a malformed citation in the metadata register),
    PASS5-4 (a citation that does not state its property, in the clause pass 4 wrote to make `rework`
    the risky arm), and PASS5-5 (the count rot again, now measured).
    **The correction is still not "check the lines" — revision 2 checked them, pass 2 checked them
    again, and pass 4 established that the two mechanical discriminators catch only a minority of the
    dominant class (§12's M-1 note).** It is: *every load-bearing property gets an assertion that fails
    when the property is absent.* **And pass 4 adds the second half, which is about the checking
    rather than the thing checked: a reviewer's checklist found three of these and a plain read of all
    four artifacts found them all.** **A reviewer should decide whether this design holds to the
    discipline everywhere — including in the parts pass 4 rewrote, which is the part most likely to
    have acquired new errors of exactly this shape.**

Handed to an independent `design-reviewer`. **This lane does not approve its own work.**
