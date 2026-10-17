# Design Revision — Revision 1 — QA contracts for feature intake and design remediation

**Brief:** [`QA-CONTRACTS-FEATURE-REMEDIATION`](./design-brief.md) (Revision 1, `DESIGN_REVISION_BLOCKED`)
**Revision number:** 1
**Governing decision:** `.decisions/2a8f5c31-9d47-4e6b-b2f8-7c15e0d9a4b2.yaml` (HD-1, RESOLVED)
**Authoring HEAD:** `e3634a0cbbdf656267b22908284dd1ae8b655085`
**Branch:** `main` (worktree `/Users/alkebut/air/shipit-platform`)
**Authored by:** `design-agent` / lane `design-QA-CONTRACTS-RESUME`
**Disposition:** `DESIGN_REVISION_COMPLETE` — with deliverable 3 (the two contracts) **declined on
evidence**, which the mandate explicitly authorised ("If the result shape still cannot be
established, say so rather than inferring one").

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
`git checkout .`, no `git add -A`; explicit paths only. This revision is a NEW commit atop
`e3634a0`; nothing was amended, rebased or reset. **`docs/engineering/FOLLOW_UPS.md` was not
modified** — it is the Manager's, and F-47 already records B3.

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

### 2.1 Every reviewable work item in the platform is stranded at `qaInProgress`

`qaInProgress` is entered from exactly one edge — `reviewApproved -> qaInProgress`
(`packages/workflow_engine/lib/src/transitions/work_item_transitions.dart:651-654`) — and has
exactly two out-edges:

- `qaInProgress -> qaPassed` (`:690-696`), guarded by `allRequiredGatesPassed()`, which **can
  only ever fail**;
- `qaInProgress -> qaFailed` (`:697-702`), guarded only by
  `actorAllowed([qaExecutor, orchestrator])`.

`qaInProgress` is in **no** `JobDefinition.entryStates`, so nothing dispatches from it either.
`AgentRole.qaExecutor` exists (`agent_role.dart:6`) but `QAOrchestration` — the class that would
be that executor's brain — is called from **its own test file only**.

**Therefore: a work item that produces a reviewable commit, is engineering-reviewed, and is
approved, walks to `qaInProgress` and stops there permanently.** This is not specific to feature
intake or design remediation. It is the main implementation lane. It is a live dead end at the
centre of the platform, and no `FOLLOW_UPS.md` entry records it.

The brief's lesson — *a state nothing leaves is worse than one nothing enters* — is not a
generalisation here. **It is a live instance of itself.**

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

### 3.3 Why the brief's refusal still stands

A gate's `config.requiredFields` is justified by **a consumer that reads them**. The triage gate's
justification is real and is `triage_processor.dart:199-222` — a live parser that returns `null`
unless all four keys are present. For design remediation the same parser runs and then **gives
up** at `:124-132`. For feature intake it never runs.

**There is no consumer on either path.** Any `requiredFields` list would be justified by nothing
but the shape of a triage contract, which is precisely the reuse `product_qa_contract_test.dart`
("NO triage gate, role or defect metadata is ever copied in") refuses.

**So this revision authors no gate set.** The word for what would exist is `DECLARED`, and §7 says
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
**no edge from any design state to `implementationReady`.** `implementationReady` is entered from
exactly three edges: `agentCompleted` (`:340-342`), `agentFailed` (`:265`), and
`waitingForHumanDecision` (`:599-602`). `designApproved`'s **only** out-edge is
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

**One new `GuardCondition`, added to the two *automatic* edges into `implementationReady`,
origin-conditional on the two intake origins, satisfied by a real
`DesignGovernanceStore.readApprovedDesignRevisionForWorkItem(workItemId)` result.** No new state,
no new edge, no new `HumanDecisionType`, no new routing-table arm, no new scheduler. It cannot
create a dead end, because a refused guard leaves the item where it was — at `agentCompleted`,
which is not a dead end (§4.3). Full specification, including the exact guard context contract and
the three required sub-slices, in [`design-review-gate.md`](./design-review-gate.md).

### 4.3 What happens to an item that never gets a design review

The guard refuses; the item **stays at `agentCompleted`**. That is not a dead end, and the reason
is a mechanism that already exists and already runs:

1. `agentCompleted` is `engineeringReviewDefinition.entryStates`
   (`scheduler.dart:3361`), so `sched-review` looks at it on its next tick;
2. for a no-commit producer — which is exactly what a triage or intake run is
   (`packages/scheduler/lib/src/implementation_inflow.dart:383-390`, `noCommitProduced`) — the
   review workload resolver returns `null`, so **no reviewer execution is burned**
   (`apps/server/lib/server.dart:540-543`);
3. the tick surfaces `blockedArtifactMissing`, and the review drain turns it into a **blocking
   human decision** — fail closed, with a durable record naming the cause.

That is the same shape `ddfbfff` established for the feature park
(`work_item_transitions.dart:34-53`): park at a state nothing dispatches, with a durable reason,
and route out through a human. And `runnable_work.dart:168-170` returns `blocked` for
`waitingForHumanDecision`, so the park grants no dispatch while it waits.

**And the human retains the override.** The guard is placed on the two automatic edges
(`agentCompleted -> implementationReady`, `agentFailed -> implementationReady`) and **not** on
`waitingForHumanDecision -> implementationReady` (`:599-602`), which already carries
`decisionActorIsHuman()` plus a resolved blocking decision
(`:604-624`). That is faithful to HD-1's own stated rationale — *"refusing to let an unreviewed
request reach implementation **unattended**"* — and it avoids the genuine dead end that guarding
all three edges would create: a human could then never move the item forward at all.

### 4.4 Defect-origin items take a different path

The guard keys on the **work-item id prefix**, not on whether an underlying defect exists:

- `WI-feature-*` → gated
- `design-remediation-*` → gated
- `defect-*` → **not gated**

Note that a design-remediation item *is* defect-origin (`design-remediation-DEF-x`), so "has a
defect" is the wrong discriminator and would silently exempt it. The prefix is the discriminator.

Why defect-origin is exempt: a `defect-*` item has already been triaged by
`sched-triage`, and `agentFailed -> implementationReady` (`:265-267`) and
`agentCompleted -> implementationReady` (`:340`) serve the OD-10 route that the operator
recorded verbatim — *"After TRIAGE COMPLETES, the item goes to implementationReady instead of
waiting at a human gate"* (`implementation_inflow.dart:406-407`). Gating it would re-open a
resolved decision for the main defect lane. HD-1's invariant names only the two intake origins,
and this is exactly it.

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
| **M10** | **A result type + parser + instruction per path** | `platform_contracts` + `apps/server/lib/src/` — the analogue of `TriageResult` / `_parseTriageResult` / `triageDefectInstruction` | The consumer that would justify `config.requiredFields` | **The load-bearing one.** B1 is unresolvable without it. |
| **M11** | **A real structural evaluator** for `triage-classification-structure` | `packages/qa_orchestration/lib/src/gates/` — `GateEvaluator` implemented **directly**, not via `GateEvaluatorImpl` | A gate that actually reads `structuredResult` | Makes the *existing* triage contract enforceable — a prerequisite for any new contract meaning anything |

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
| The two contracts this revision declines | **DOES NOT EXIST** | Cannot exist until M8–M10 |

**And one level is worse than `DECLARED`:** the four *registered* gate types — `static-analysis`,
`unit-tests`, `security-scan`, `performance` — are, if ever invoked, **fabricated `PASSING`**
(§2.2). They are currently unreachable, which is the only reason this is latent. **They must be
treated as not implemented, and `gateRegistry` must not be trusted as a list of working gates.**

---

## 8. Implementation sequence — reviewable slices, each independently mergeable

Ordered by dependency. **Slice 0 is a decision, not a code change, and it is not this lane's.**

**0. (Manager-owned) Record `qaInProgress` as a live dead end.** §2.1 is not in `FOLLOW_UPS.md`
and it affects every implementation in the platform, not these two paths. It needs an entry in
§13 next to F-47, and a decision on whether the evaluator slice is a QA-platform work item rather
than a continuation of this one. `docs/**` is `PROHIBITED_PATHS` for this lane and was not
written.

**1. The design-review gate — `design-review-gate.md` §6.** Self-contained, no dependency on the
evaluator, no dependency on the contracts. Sub-slices 1a (the guard + the two edges), 1b (the
`DesignGovernanceStore` wiring in the composition root), 1c (the three edge pins
`implementation_ready_edge_test.dart` already asserts by name, plus the new non-vacuity test
that adding the guard to an exempt origin leaves the route untouched). **This is the only slice
in this revision that changes what the platform does**, and it is a strict reduction in what the
platform may do unattended.

**2. The structural evaluator — `evaluator-spec.md` §5. Slice 2a replaces `_validateEvidence`**
with content-reading validation and adds the non-vacuity test. **Nothing may be wired before 2a
lands.** 2b implements `triage-classification-structure` against `GateEvaluator` directly. 2c adds
the `qaInProgress -> qaPassed` caller, the drain, and the `qa_contract` context key. **Slice 2 is
what makes "enforced" mean anything** — and until 2c lands, the §2.1 dead end is still a dead end.

**3. M6 + M7 + M5 — the design lane**, in that order, and only after slice 1 has landed so the
gate is already in place to catch a producer that runs before the edge exists. §6's ordering
constraint applies: **M6/M5 without M7 is worse than not building them.**

**4. M8 + M9 + M10 — a real run for feature intake**, then, and only then, the two contracts. Each
gate's `requiredFields` justified by a named line in the new parser; `evidenceTypes` carried in
`config['evidenceTypes']` as `List<String>` or provisioning throws; `optionalGateFailuresAllowed`
equal to the contract's own optional-gate count (the *derivation* at `product_qa_contract.dart:128-141`,
not the triage numeral); and `'evaluatorRuntime': 'absent'` until slice 2c is in place and the
gate's type has an evaluator.

---

## 9. Traceability

### 9.1 Requirements covered

| Requirement | Where |
|---|---|
| **1. The QA gate evaluator — specified, not deferred.** Who populates `context['gateResults']`, from what, at which point in the transition, how `config` is read | [`evaluator-spec.md`](./evaluator-spec.md) §1-§4; summary §5 |
| **2. The design-review gate under HD-1** — where in the graph, which actor, what for an item that never gets one, defect-origin same path or not, invariant enforced | [`design-review-gate.md`](./design-review-gate.md); summary §4. All five sub-questions answered individually in §4.2-§4.4 |
| **3. The two contracts** | §3 — declined on evidence, as the mandate authorised. Evidence for the refusal in §3.1-§3.3 |
| **4. What must exist before B1 is solvable** — result type, parser, instruction, `AgentRole` variants; name each and where | §6, M5-M11, each with location and the gate it would justify |
| **5. Traceability, risks, non-goals, implementation sequence in reviewable slices** | §7, §9, §10, §11, §8 |
| **Use the word `DECLARED`, not `PASSING`** | §7, stated three ways; `evaluator-spec.md` §6 |
| **Every `file:line` verified against the tree** | Verified individually at `e3634a0`. Two corrections of the resume spec and three of the predecessor's brief are recorded in §12 |

### 9.2 Requirements gaps

| Gap | Why it is a gap |
|---|---|
| Two authored contracts | §3. There is no run for feature intake and no consumer for design remediation. B1 is unresolvable at `e3634a0`. |
| Concrete `requiredFields` for either path | Follows from the above. M10 is the precondition. |
| A design-review actor other than a human | §4.1 Fact 1. No scheduler dispatches the design lane, so an agent design review cannot be specified honestly today. **The design deliberately chooses the human and says so.** |
| An executable gate on the *QA* path | Follows from §2.1 and §2.2. Slices 2a-2c. |

### 9.3 Out of scope, deliberately

- **`qaInProgress` strandedness (§2.1)** — reported in full, **not designed here**. It is the main
  implementation lane, not these two paths, and fixing it is slice 2c. Designing it in a brief
  whose subject is intake would be scope theft, and the Manager owns `FOLLOW_UPS.md`.
- **The four fabricated evaluators (§2.2)** — specified as a *hard gate on* the wiring slice, not
  as a rewrite. Rewriting four implementation gates is `AUTOMATION_OPPORTUNITY` work, independently
  reviewable, and this lane has no authority to decide what a real `static-analysis` gate should
  assert.
- **M1-M4 as the brief numbered them** — carried forward as M8-M10, re-numbered so the design
  lane's M5-M7 do not collide, and each given a gate justification.
- **F-43** (`WI-feature-*` has no replay hook) — unchanged, deliberately not bundled.

---

## 10. Risks

| # | Risk | Likelihood | Severity | Mitigation / status |
|---|---|---|---|---|
| **R1** | The design-review guard is treated as satisfied because `context['approvedDesignRevisionId']` is supplied by a caller that did not read the store | MEDIUM | **HIGH** | The guard cannot verify its own input — `DurableWorkflowEngine.transition` passes `context` to the policy and **discards it** (`packages/workflow_store/lib/src/durable_workflow_engine.dart:173`, `:211-233`). This is the platform's **existing** enforcement model (`qaContractExists` at `guard_conditions.dart:247` is the same shape, and the coordinator reads the store at `execution_coordinator.dart:1072`). Stated as a property of the design, not hidden: a context guard is as strong as the component that fills it. `design-review-gate.md` §4 names that component and requires it to be the only writer. |
| **R2** | The evaluator is wired before `_validateEvidence` is replaced | MEDIUM | **CRITICAL** | §2.2. `evaluator-spec.md` §5 makes this a hard ordering constraint with a named non-vacuity test. This is the one ordering in this revision that must not be violated. |
| **R3** | The design-review gate strands an intake item | LOW | HIGH | §4.3. Refusal leaves the item at `agentCompleted`, which `sched-review` picks up and which fails closed into a blocking human decision. Proved structurally, not asserted. |
| **R4** | A human cannot move an intake item forward at all | **Was HIGH** | HIGH | **Resolved in this revision.** §4.3: the guard is deliberately not on `waitingForHumanDecision -> implementationReady`, which already carries `decisionActorIsHuman()`. Had it been placed on all three edges this would have been a genuine dead end. |
| **R5** | `qaInProgress` dead end (§2.1) goes unrecorded | MEDIUM | **HIGH** | §9.3. Reported, not designed. Slice 0 puts it in front of the Manager, who owns `FOLLOW_UPS.md`. |
| **R6** | The two contracts are authored anyway "to close the ticket" | MEDIUM | HIGH | §3. This revision is the obstacle, and it states exactly what each missing artifact would justify — so the next lane has a spec, not a prohibition. |
| **R7** | A future implementer routes `designApproved -> implementationReady` without M7, creating a loop | MEDIUM | HIGH | §6 ordering constraint and §4.1 Fact 2, which names the trap explicitly: `designApproved` is in `triageDefectDefinition.entryStates`. |
| **R8** | `sourceColumn` is interpolated into SQL | LOW | **CRITICAL** | `evaluator-spec.md` §3.4. It is a label; the evaluator reads through the typed store. Operator-authored manifest JSON is the threat model. |
| **R9** | `M6`/`M5` land without `M7` | MEDIUM | MEDIUM | §6 and §8 slice 3 order. Both M5 and M7 are in one slice. |
| **R10** | A reviewer reads `gateRegistry` and believes four gates work | HIGH | MEDIUM | §7's third row states it plainly, and `evaluator-spec.md` §5.1 requires the registry to stop presenting them as working. |

---

## 11. Non-goals

- **Not** a change to `GuardConditions.qaContractExists()` — untouched, and it should stay
  untouched (`work_item_transitions.dart:126-134` explains why its absence on the dispatch edge is
  load-bearing).
- **Not** a change to `work_item_transitions.dart` beyond **adding one guard to two existing
  edges**. No edge added, removed or retargeted. Deliberately: the design lane's own §4.1 Fact 2
  finding is that adding edges is how this graph gets disconnected.
- **Not** a change to `HumanDecisionRouting` — no new `HumanDecisionType`, no new routing arm, no
  new edge to `waitingForHumanDecision`. §4.3 explains why the existing human route is left intact.
- **Not** a new `WorkItemState`. One guard was chosen over one state precisely because a state
  cannot be satisfied without a producer and cannot be left without an edge.
- **Not** a QA-contract evaluator runtime implementation. Specified, not built — this lane does
  not implement production code. §5 names the insertion points and the ordering constraint.
- **Not** the rewrite of the four fabricated evaluators. Specified as a hard prerequisite (§2.2).
- **Not** a decision on slice 0 (§9.3). The Manager owns it.
- **Not** an edit to `docs/engineering/FOLLOW_UPS.md`.

---

## 12. Corrections to the inputs this revision inherited

Recorded because each one changed a citation or a conclusion, and a silent correction would be
indistinguishable from an error.

| Source | Claimed | Actual at `e3634a0` |
|---|---|---|
| `design-resume.md` "Read first" | `work_item_transitions.dart:657-662` for `qaInProgress -> qaPassed` | **`:690-696`**. `:657-662` is a comment block about `reviewRejected`. The conclusion is unchanged and stronger (§2.1). |
| `design-resume.md` "Read first" | `triage_processor.dart:272-276` for `_extractDefectId` | **`:279-285`**. `:272-276` is the tail of the `FormatException` handler. The code is exactly as described. |
| Predecessor brief §4.2 | `possibleDuplicateDefectId` `:254`, `recommendedWorkItemCategory` `:256`, `summary` `:257`, `suspectedComponents` `:221-223` | `:259-260`, `:261-262`, `:263`, `:224-226`. All drifted; the table's substance is right. |
| Predecessor brief §5 / metadata | `triage_processor.dart:120-124`, `:125-132` | `:120-132` and `:124-132`. Substance right. |
| `FOLLOW_UPS.md` §13 F-47 and `design-resume.md` | `work_item_transitions.dart:661` for `qaInProgress -> qaPassed` | Same off-by-29 as the resume spec; correct line is `:690-696`. **`FOLLOW_UPS.md` §13 line 1073 carries this citation** — Manager-owned, not corrected here. |

**One inherited conclusion is now wrong rather than merely mis-cited:** the predecessor's §3.3
"proof by execution" that the parked feature is dispatchable, and its `CONTRADICTION` against
F-45. Both are resolved by `ddfbfff` (§1.1), and the brief's Flow A no longer describes HEAD.

**Own citations were verified individually at `e3634a0`**, by reading each cited range rather than
inferring it from a surrounding grep. Two were tightened on that pass and both are corrected in
place rather than left loose:

- `agentFailed -> implementationReady` was cited `:265` and is now `:265-267`, so the table in
  [`design-review-gate.md`](./design-review-gate.md) §2 states its guard exactly
  (`actorAllowed([orchestrator])`) instead of saying "per the surrounding convention" — the guard
  was read, not assumed.
- `designRejected -> designInReview` was cited `:115-117`; verified correct.

Everything else was confirmed on first citation. Where a range is given, both endpoints were
checked; where a single line is given, that line was read.

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
   for every work item in existence. **The gate will refuse every intake item until slice 3
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

---

## 14. Verification performed at `e3634a0`

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

No other command in this lane mutated state. No docker, no compose, no `psql`.

---

## 15. Disposition

`DESIGN_REVISION_COMPLETE`.

**Not** because the two contracts exist. They do not, and §3 and §13 say why with evidence.

Complete because the two things the Manager delegated and that *can* be specified honestly from
the repository now **are**:

- **The evaluator**, specified to the point of naming its insertion points, its guard-context
  contract, its `config` key vocabulary, and the ordering constraint that makes wiring it safe —
  plus two findings (§2.1, §2.2) that change what "wire it in" would mean.
- **The design-review gate**, specified as one guard on two existing edges, satisfied by a store
  query that already exists and is already tested, with the dead-end question answered
  structurally rather than by assertion — and with the one placement that would have created a
  real dead end identified and deliberately avoided.

And because the correction that matters most is uncomfortable: **the design lane's persistence
layer already exists**, so HD-1's gate does not need a new model, a new schema, a new enum or a
new routing arm. It needs a producer. The brief's framing made that look like a larger gap than it
is, and a design built on the brief's framing would have been substantially larger than necessary.

Handed to an independent `design-reviewer`. **This lane does not approve its own work.**