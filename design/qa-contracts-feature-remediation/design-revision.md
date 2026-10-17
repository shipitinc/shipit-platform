# Design Revision — Revision 2 — QA contracts for feature intake and design remediation

**Brief:** [`QA-CONTRACTS-FEATURE-REMEDIATION`](./design-brief.md) (Revision 1, `DESIGN_REVISION_BLOCKED`)
**Revision number:** 2
**Supersedes:** Revision 1 (`8F3B27D4-6C15-4E9A-B0D7-3F62C81A4E50`, authored at `ad4fada`)
**Governing decisions:**
- `.decisions/2a8f5c31-9d47-4e6b-b2f8-7c15e0d9a4b2.yaml` — HD-1, RESOLVED
- `.decisions/7f3e2a95-6c81-4d70-b215-8e94a0c7d382.yaml` — **the reading of HD-1's undelegated
  clause, RESOLVED by the operator 2026-10-17: `READING_B_CLAUSE_COVERS_EVERY_ROUTE`.** Reading A
  is rejected. **H-3 of revision 2 is therefore closed as a decision, not as an open judgement.**
**Authoring HEAD:** `e3634a0cbbdf656267b22908284dd1ae8b655085` (revision 1)
**Revision 2 at:** `c8fd361906f0d831bbcfd431b75d1eb21ae9db5d`
**Corrected at:** `90b6f5f` (this correction pass, lane `design-QA-CONTRACTS-CORRECTION-2`)
**Branch:** `main` (worktree `/Users/alkebut/air/shipit-platform`)
**Authored by:** `design-agent` / lane `design-QA-CONTRACTS-CORRECTION`, then corrected by
`design-agent` / lane `design-QA-CONTRACTS-CORRECTION-2`
**Disposition:** `DESIGN_REVISION_COMPLETE` — Revision 1's central defect (the deliverable-2 gate's
refusal sink did not exist) is corrected with a specified park; deliverable 3 remains **declined on
evidence**, now split **per path** rather than asserted for both; and **the reading of HD-1 is now a
recorded human decision** (`.decisions/7f3e2a95…`) which this revision applies rather than asks about.

> **Revision 2 was returned as `DESIGN_REVIEW_CHANGES_REQUIRED` — 1 BLOCKING, 2 HIGH, 4 MEDIUM,
> 3 LOW.** Every item is addressed; `design-review-gate.md` §0 tabulates them in one place.
>
> **The BLOCKING finding was that revision 2's own correction was wrong in the same shape as the one
> it was correcting.** Revision 1 left a refused item where it was; revision 2 specified a park and
> asserted, in three artifacts, that the park *"carries a durable reason"* — citing a range of
> `durable_workflow_engine.dart` that writes `blockingReason: null`. **The park survived; the reason
> did not.** That is recorded rather than smoothed, because it is the third time this design has
> claimed a property no assertion checked.

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
`git checkout .`, no `git add -A`; explicit paths only. This correction pass is a NEW commit atop
`90b6f5f`; nothing was amended, rebased or reset. **`docs/engineering/FOLLOW_UPS.md` was not
modified** — it is the Manager's, and F-47 already records B3. **F-55, which the operator's decision
`.decisions/7f3e2a95…` names as the place the park's human-surface gap is recorded, was likewise
not written here** (`design-review-gate.md` §5.2.2) — the same reason, and named rather than left for
a reader to wonder about.

**Two non-goals are WITHDRAWN**, both because independent review showed their premises false:
*"Not a new `WorkItemState`"* and *"Not a new edge to `waitingForHumanDecision`"*. See §11 and
`design-review-gate.md` §3.5 and §5.1. Nothing else in §11 changes, and the reviews verified the
remaining ones stand.

**One further correction to a non-goal's reasoning.** The withdrawal above stands, but revision 2's
*justification* for keeping the state — that parking at `waitingForHumanDecision` instead *"would
re-park into the state it was just routed out of, with no durable change, forever"* — was right about
the conclusion and wrong about the mechanism. `design-review-gate.md` §5.1.1b now shows, against
`durable_workflow_engine.dart:816-841` and `:563-580`, that it is **worse than that**: a route-3
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
> The consequence for deliverable 1 is in [`evaluator-spec.md`](./evaluator-spec.md) §2.1: **slice 2c
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
`WorkItemState` (`designReviewRequired`), two new edges into it, one out. No new `HumanDecisionType`,
no new routing-table arm, no new decision type. It cannot create a silent dead end, because a
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
(§1.3, M5–M7). Until slice 3 lands, **intake items park and a human can re-triage, re-plan or stop
them — and nothing else.**

**That price is now the operator's, recorded knowing it — and it is not a resting state.** The
decision's `consequence` is explicit: *"The dead end this creates must be solved FIRST … This
decision does not make the dead end acceptable; it makes it the next thing to build."*
`design-review-gate.md` §5.2.2 records that as **slice 1.5, owner the Manager**, pointing at
`FOLLOW_UPS` **F-55**, which the decision names and which this lane does not write (`docs/**` is
`PROHIBITED_PATHS`). **The design's position that slice 1 should land without waiting for 1.5 is
flagged as this revision's own judgement**, because the decision calls 1.5 a precondition —
`design-review-gate.md` §5.2's closing callout states both sides of that.

R4 stays **re-opened**: revision 1 recorded it as "RESOLVED in this revision" on the strength of the
narrower reading, and revision 2 re-opened it. **It is now a named, owned, sequenced consequence
rather than a risk awaiting a judgement.**

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
origin — which is R1, and which remains unmitigated until sub-slice 1b's drift test exists.

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

Ordered by dependency. **Slice 0 is a decision, not a code change, and it is not this lane's.**

**0. (Manager-owned) Record the dead ends as live, and record what slice 1 costs.** §2.1 and §2.1a
are not in `FOLLOW_UPS.md` and they affect every implementation in the platform, not these two paths.
**`reviewApproved` is the corrected location, not `qaInProgress`** (§2.1), and the second finding is
a declared edge with no caller. Three entries belong in §13 next to F-47:

- the `reviewApproved` dead end, with `qaInProgress` named as a second unreachable state;
- `agentFailed -> implementationReady` as a callerless edge (the pattern, §2.1a);
- **the operational cost of slice 1:** under `.decisions/7f3e2a95…` (**Reading B — decided**), both
  intake paths become unable to reach an implementer until slice 3 lands, and a human's options at
  the park are re-triage, re-plan or stop. This is the consequence an operator must be told about
  before slice 1 ships, not after. `docs/**` is `PROHIBITED_PATHS` for this lane and was not written.
- **F-55**, the park's human-surface gap — **named by the operator's own decision
  (`.decisions/7f3e2a95…`: *"see FOLLOW_UPS F-55, which records why the park's human surface
  currently offers no 'do the design review' answer"*) and not written here**, for the same reason.
  It is **slice 1.5** (`design-review-gate.md` §5.2.2).

**1. The design-review gate — `design-review-gate.md` §6.** Self-contained, no dependency on the
evaluator, no dependency on the contracts. Sub-slices **1a** (the guard on the two caller-bearing
edges — **both in one commit**, `design-review-gate.md` §5.3, now required by
`.decisions/7f3e2a95…` rather than merely recommended), **1b** (the single context writer —
**including `packages/scheduler/lib/src/scheduler.dart`, whose `const` context at `:1746` must
become a computed map** — the single park helper performing *both* steps of §5.1.1a, and the
`DesignGovernanceStore` wiring in the composition root), **1c** (the edge pins
`implementation_ready_edge_test.dart` already asserts by name, extended for G5′/G6), **1d** (the
park: one new state, three edges, G7–G10/G12–**G16**). **This is the only slice in this revision
that changes what the platform does**, and it is a strict reduction in what the platform may do
**unattended *and* attended** — which is the reading the operator decided, not one this design asks
a reviewer to judge.

**Sequencing constraint inside slice 1, and it is load-bearing:** 1d must not lag. A route-1 guard
without the park is the BLOCKING finding reproduced in code — a refusal that goes nowhere, tested
green by G1/G2. **And a park taken by `transition` rather than `requestHumanDecision` is the
BLOCKING finding of *this* correction reproduced in code** — a refusal that goes somewhere with no
reason and nothing for an operator to answer, and G1/G2/G7 all pass over it. **G14 is the assertion
that distinguishes them.**

**2. The evaluator — `evaluator-spec.md` §5. Slice 2a de-registers the four fabricated evaluators**
(MEDIUM finding M3: replacing `_validateEvidence` is **insufficient**, because a predicate reading
`QAEvidence.content` still reads hardcoded collector output and stays a constant) and adds the
non-vacuity test that fails while the registry presents an evaluator whose evidence is not a function
of the work item. **Nothing may be wired before 2a lands.** 2b implements
`triage-classification-structure` against `GateEvaluator` directly. **2c is WIDENED (HIGH finding
H2): it must add both the `reviewApproved -> qaInProgress` caller *and* the `qaInProgress -> qaPassed`
drain with the `qa_contract` context key** — Revision 1's 2c had nothing to drain, because the item
stops at `reviewApproved`. **Slice 2 is what makes "enforced" mean anything** — and until 2c lands,
the §2.1 dead end is still a dead end, one hop earlier than Revision 1 said.

**3. M6 + M7 + M5 — the design lane**, in that order, and only after slice 1 has landed so the
gate is already in place to catch a producer that runs before the edge exists. §6's ordering
constraint applies: **M6/M5 without M7 is worse than not building them.**

> **1.5 — inserted between slice 1 and slice 2 by this correction pass, and owned by the Manager.**
> **The park's human surface offers re-triage / re-plan / stop and none is "do the design review"**,
> which is the thing the item is parked waiting for. `.decisions/7f3e2a95…` decided Reading B *and*
> made closing this dead end the next thing to build (`consequence`: *"The dead end this creates must
> be solved FIRST … it makes it the next thing to build."*), naming `FOLLOW_UPS` **F-55** as where it
> is recorded. **This lane cannot build it** — it needs a new `HumanDecisionType` plus a routing
> arm, and `human_decision_routing.dart:151-162` requires `targetFor` and `escalationTargetFor` to
> move in lockstep or escalation accounting *"silently stops"* advancing; that is an architecture
> change, and `AGENTS.md` reserves architecture to the human. `design-review-gate.md` §5.2.2 has the
> full hand-off. **This design's position is that slice 1 lands and 1.5 follows**, because slice 1 is
> a strict reduction in what the platform may dispatch and leaves items visible with a real reason —
> and that position is **this revision's judgement against the decision's own "FIRST", and is flagged
> as such** rather than presented as the decision's instruction.

**4. M8 + M9 + M10 (feature intake) and M12 + M10 (design remediation) — a real run per path**,
then, and only then, the two path-specific contracts. **This slice is what makes §4.4's reading
load-bearing rather than academic:** a real intake run produces a commit, which makes
`(engineeringReview, rework) -> implementationReady` (`human_decision_routing.dart:103-104`) a live
path for an intake origin, and an unguarded route 3 would be a live bypass of HD-1's undelegated
clause — which `.decisions/7f3e2a95…` has now forbidden.
clause. Each
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
| **4. What must exist before B1 is solvable** — result type, parser, instruction, `AgentRole` variants, and one `JobDefinition` per path; name each and where | §6, **M5–M12**, each with location and the gate it would justify. M12 restored (MEDIUM finding M1) |
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
- **M1-M4 as the brief numbered them** — carried forward as **M8–M10 and M12**, re-numbered so the
  design lane's M5-M7 do not collide, and each given a gate justification. **Corrected:** Revision 1
  wrote "carried forward as M8–M10", which silently dropped the brief's **M2** (a design-remediation
  `JobDefinition`). MEDIUM finding M1. Restored as M12; §6 states that M10 does not subsume it.
- **F-43** (`WI-feature-*` has no replay hook) — unchanged, deliberately not bundled.

---

## 10. Risks

| # | Risk | Likelihood | Severity | Mitigation / status |
|---|---|---|---|---|
| **R1** | The design-review guard is treated as satisfied because `context['approvedDesignRevisionId']` is supplied by a caller that did not read the store | MEDIUM | **HIGH** | The guard cannot verify its own input — `DurableWorkflowEngine.transition` passes `context` to the policy (`durable_workflow_engine.dart:173`) and persists **no guard-supplied key** (it reads back only `humanDecision` `:216` and `blockingReason` `:223`, both its own). This is the platform's **existing** enforcement model (`qaContractExists` at `guard_conditions.dart:247` is the same shape, and the coordinator reads the store at `execution_coordinator.dart:1072`). Stated as a property of the design, not hidden: a context guard is as strong as the component that fills it. `design-review-gate.md` §4.4 names that component and requires it to be the only writer. **Mitigation made executable (MEDIUM finding M4):** Revision 1's mitigation was "require it to be the only writer", which is not a test and therefore not a mitigation — G1–G6 test the *guard*, never the *supplier*, so every one of them passes with a lying writer. **The required artifact is a drift test naming the single writer of `workItemOrigin` and `approvedDesignRevisionId`**: assert that exactly one production call site constructs the map containing those two keys, and that it derives the second from `readApprovedDesignRevisionForWorkItem`. Named in sub-slice 1b. Until it lands, R1's rating stands **unmitigated**, and this table says so rather than implying otherwise. |
| **R2** | The evaluator is wired before `_validateEvidence` is replaced | MEDIUM | **CRITICAL** | §2.2. `evaluator-spec.md` §5 makes this a hard ordering constraint with a named non-vacuity test. This is the one ordering in this revision that must not be violated. |
| **R3** | The design-review gate strands an intake item silently | **Was LOW — was wrong** | **CRITICAL** | **Revision 1's mitigation was void (the BLOCKING finding of revision 2's review) and revision 2's own mitigation was void too (the BLOCKING finding of this correction).** Revision 1 claimed a refused item "stays at `agentCompleted`… which fails closed into a blocking human decision"; `engineeringReviewMissingArtifact` **stands down** for a no-commit producer (`engineering_review_gate.dart:2860-2871`, `:2210-2228`; `server.dart:1416-1421`). Revision 2 replaced that with a park — and then asserted, citing `durable_workflow_engine.dart:222-225`, that the park "carries a durable reason". **That range writes `blockingReason: null` for every non-`waitingForHumanDecision` target**, so revision 2's park erased its own reason and **B1 survived under a new state name**. **Mitigated in this revision** by: the park (`design-review-gate.md` §5.1.1); **the two-step exit whose second step is `DurableWorkflowEngine.requestHumanDecision`, which writes `blockingHumanDecisionId` and `blockingReason` itself (`:651-653`)** (§5.1.1a); and the assertions **G7** (leaves `agentCompleted` in one tick), **G14** (non-null non-default `blockingReason`), **G15** (non-null resolvable decision id), plus G9 (idempotence), G10 (no bypass loop), G16 (exact option set). **The rating stays CRITICAL**: a silent, indefinitely-repeating dead end with a green suite over it is the worst combination in this table — **and it has now happened twice in this design, the second time inside the fix for the first.** The reason it happened twice is that G7 asked whether the item *moved* and nothing asked what it *carried*. **G14 exists because of that, and a reviewer should treat any future property of the park asserted without an assertion as the same defect a third time.** |
| **R3b** | The park is implemented by `transition` rather than `requestHumanDecision`, and ships the reason-less park | MEDIUM | **CRITICAL** | **Recorded as a separate row because it is a distinct implementation error with a distinct fix**, and folding it into R3 would hide it. The failure is silent and passes G1/G2/G7/G9. **Mitigation:** sub-slice 1b names the park helper as performing *both* steps and says in terms that a step-1-only helper "is the B-1 defect and must not be written"; **G14/G15/G16 fail if it is**. |
| **R4** | A human cannot move an intake item to an implementer at all, and at the park has no answer that is "do the design review" | HIGH | HIGH | **Re-opened twice; now a decided consequence with a named owner.** Revision 1 recorded this as "RESOLVED" on the strength of the narrower reading — wrong. Revision 2 specified the guard ON the human edge and marked the reading for judgement. **`.decisions/7f3e2a95…` has now decided Reading B**, so the price is fixed and accepted: nothing writes an approved `design_revision` until slice 3, so a human's options at the park are re-triage, re-plan or stop, **and none of the three is the design review the item is waiting for**. **Mitigation, as far as this lane can take it:** the park's option list is made **explicit** (`requestHumanDecision`'s `options` argument) so the absence of a fourth answer is a recorded property rather than an emergent one, and asserted by **G16**; the gap is named as **slice 1.5 with the Manager as owner** and tied to `FOLLOW_UPS` **F-55**, which the operator's own decision names. **The honest residual: between slice 1 and slice 3+1.5, "stop" is the only answer that terminates.** This design's position is that slice 1 lands anyway — it is a strict reduction in what the platform may dispatch and it makes the item visible with a real reason, both strictly better than the status quo — **and that position is this revision's judgement against the decision's word "FIRST", flagged as such** rather than asserted as the decision's instruction. |
| **R5** | `qaInProgress` dead end (§2.1) goes unrecorded | MEDIUM | **HIGH** | §9.3. Reported, not designed. Slice 0 puts it in front of the Manager, who owns `FOLLOW_UPS.md`. |
| **R6** | The two contracts are authored anyway "to close the ticket" | MEDIUM | HIGH | §3. This revision is the obstacle, and it states exactly what each missing artifact would justify — so the next lane has a spec, not a prohibition. |
| **R7** | A future implementer routes `designApproved -> implementationReady` without M7, creating a loop | MEDIUM | HIGH | §6 ordering constraint and §4.1 Fact 2, which names the trap explicitly: `designApproved` is in `triageDefectDefinition.entryStates`. |
| **R8** | `sourceColumn` is interpolated into SQL | LOW | **CRITICAL** | `evaluator-spec.md` §3.4. It is a label; the evaluator reads through the typed store. Operator-authored manifest JSON is the threat model. |
| **R9** | `M6`/`M5` land without `M7` | MEDIUM | MEDIUM | §6 and §8 slice 3 order. Both M5 and M7 are in one slice. |
| **R10** | A reviewer reads `gateRegistry` and believes four gates work | HIGH | MEDIUM | §7's third row states it plainly, and `evaluator-spec.md` §5.1 requires the registry to stop presenting them as working. Slice 2a de-registers them (`evaluator-spec.md` §5.2 option 2, the only safe one). |
| **R11** | A future caller appears for `agentFailed -> implementationReady` and the guard is absent there | MEDIUM | **HIGH** | §2.1a. The edge is callerless today, so a guard there would be inert; adding one now would look like coverage and be nothing. Pinned by **G11**, which fails if the guard is absent from `:265-267` **while** a production caller of that edge exists — so the rule fires when the risk becomes real, and not before. |
| **R12** | Slice 1's route-1 and route-3 guards land in separate commits | MEDIUM | **HIGH** | `design-review-gate.md` §5.3. Between them, the park exists and the human route is unguarded — and slice 2c and slice 4 both make that window worth exploiting. Stated as an in-slice ordering constraint: **1a adds both in one commit**, and a reviewer seeing them split should treat it as a finding. |

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
- **Not** a change to `HumanDecisionRouting` — no new `HumanDecisionType`, no new routing arm, no
  new decision type. **Still true, and now load-bearing rather than incidental:** the park exits on
  `escalation`, whose `targetFor` arms already exist
  (`human_decision_routing.dart:121, 132-135`), so no routing table is touched. §4.4 explains what
  that costs. **Recorded because it is a first:** `escalation` is raised nowhere in production today,
  so this would be its first raiser — a new *use* of an existing type, not a new type, which is what
  keeps it inside this slice (`design-review-gate.md` §6, 1d).
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
- **Not** the dead end itself. The park offers re-triage / re-plan / stop and **no "do the design
  review"** — `.decisions/7f3e2a95…` requires that gap to be closed and names it as the next thing
  to build; closing it needs a new `HumanDecisionType` plus a routing arm, which is slice 1.5 and
  the Manager's (`design-review-gate.md` §5.2.2). **This lane cannot close it and does not pretend
  to.**
- **Not** a QA-contract evaluator runtime implementation. Specified, not built — this lane does
  not implement production code. §5 names the insertion points and the ordering constraint.
- **Not** the rewrite of the four fabricated evaluators. Specified as a hard prerequisite (§2.2).
- **Not** a decision on slice 0 (§9.3). The Manager owns it.
- **Not** an edit to `docs/engineering/FOLLOW_UPS.md` — **including F-55**, which the operator's
  decision names.

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
(`durable_workflow_engine.dart:816-841`) that nothing can re-open (`:563-580`) and no edge leads
away from. **That is the dead end the park's distinct state exists to prevent, so P3 is the sink
rather than a convenience.**

**One inherited conclusion is now wrong rather than merely mis-cited:** the predecessor's §3.3
"proof by execution" that the parked feature is dispatchable, and its `CONTRADICTION` against
F-45. Both are resolved by `ddfbfff` (§1.1), and the brief's Flow A no longer describes HEAD.

**And the pattern across all of these, stated once because it is the finding this document exists
to avoid.** Nine of the rows above are errors this lane made and a review caught — a citation
pointing at a comment that says something else, a `try` that guards something else, a pair count
inherited from a stale comment, a file omitted from the list that writes the thing the file was
supposed to help write. **Six of the nine are of one kind: citing a range as evidence for a property
that range does not state.** The correction is not "check the lines" — revision 2 checked them, and
the error is downstream of checking. **It is: if a property is load-bearing, some assertion must
fail when the property is absent.** G14, G15, G16 and the G5′ count exist because of that, and a
reviewer should treat any future load-bearing property asserted without an assertion as the same
defect.

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
that pass's output: eleven new rows, nine of them errors revision 2 made.** Two are the **L3
pattern** the review named — revision 2's metadata recorded Reading A as a live `DESIGN_DISCOVERY`
at `authority: HUMAN` *in the same list* as Reading B, and revision 2's §5.2 argued Reading B while
disposing of the rationale *"as a different field"*, which is the exact clause the operator's
`rejected_alternative` cites as a reason the reading was rejected. **Both are now removed rather than
relabelled**, and the reading is applied because `.decisions/7f3e2a95…` decided it.

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
7. **The park's human surface still offers no "do the design review".** **This is now the operator's
   named gap, not mine.** Revision 2 left it as a *deliberate* gap; the operator's decision
   (`.decisions/7f3e2a95…`) closed the question of whether to accept it and answered no —
   `consequence`: *"The dead end this creates must be solved FIRST … it makes it the next thing to
   build."* **What this pass adds over revision 2, and what it cannot add:**
   - **Resolved, and named:** the decision type is `escalation`, its three answers are fixed and
     explicit, and G16 asserts the option set cannot widen silently (`design-review-gate.md` §6, 1d).
     Revision 2 said `escalation` was the only safe type without pinning the answers.
   - **Not resolved, and stated as unresolved:** a human still cannot produce the design review the
     item is waiting for. That needs a new `HumanDecisionType` plus a routing arm, and
     `human_decision_routing.dart:151-162` requires the two routing tables to move in lockstep or
     escalation accounting *"silently stops"* advancing — **an architecture change, which `AGENTS.md`
     reserves to the human and which this lane has no authority to make.** It is **slice 1.5, owner
     the Manager**, tied to `FOLLOW_UPS` **F-55** (`design-review-gate.md` §5.2.2).
   - **What it costs in the meantime:** "stop" is the only park answer that terminates. That is R4.
   - **Also resolved this pass, and revision 2 had not:** whether `escalation` is safe to raise here
     at all. It is the first production raiser of that type, and that is now recorded (`§11`) rather
     than left to be discovered.
8. **I have not re-run the two test suites from §14.** They were run at `e3634a0` by Revision 1 and
   no production code changed, so re-running would produce the same output; this revision's claims
   are all tree-derived and none depends on a test result. Stated rather than implied.
9. **R1 remains UNMITIGATED.** The drift test that would mitigate it is *specified* (sub-slice 1b)
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
    and `:563-580` differently should say so, because the whole park shape turns on it.**
11. **One judgement call of mine, flagged because it cuts against the decision's own word.** The
    decision calls the dead end's fix a *precondition* — "must be solved **FIRST**". **This design's
    position is that slice 1 lands and slice 1.5 follows**, on the grounds that slice 1 is a strict
    reduction in what the platform may dispatch and leaves items visible with a real reason and a
    real pending decision. **That is my judgement, not the decision's instruction**, and it is the
    second thing a reviewer should look at hardest (`design-review-gate.md` §5.2's closing callout).

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
```

No command in this pass mutated state. No docker, no compose, no `psql`. The QA stack was not
touched.

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

**Reordered by this correction pass. The reading of HD-1 is no longer first — it is decided
(`.decisions/7f3e2a95…`), and what needs checking is whether this design applies the decision
faithfully, which is a different question with a different answer if the design is wrong.**

1. **`design-review-gate.md` §5.1.1b — the rejection of the recommended option.** This is the single
   load-bearing finding of this pass, and it is a *negative* claim: `waitingForHumanDecision` cannot
   be the park. It rests on `durable_workflow_engine.dart:816-841` (the decision is saved resolved,
   then the item is never moved) and `:563-580` (a resolved blocking decision cannot be re-raised).
   **Read those two ranges. If the reasoning is wrong, the park shape is wrong, and P3 exists for no
   reason.** This is first because everything in §5.1.1a depends on it.
2. **`design-review-gate.md` §5.1.1a and §5.1.2 — are the writers named, and are they the right
   ones?** Revision 2's failing was precisely a property asserted with no writer. The claim is now
   that `requestHumanDecision` is the writer and `resolveHumanDecision`'s caller originates P3. **A
   reviewer should check that the design names a component that exists and is reachable, not one
   that merely sounds right** — that is the error being corrected.
3. **G14, G15, G16.** Whether these are the right assertions for the property revision 2 asserted
   and did not check. **If a reviewer thinks G14 is insufficient — e.g. that asserting
   `blockingReason` non-null does not prove a human can act on it — that is the finding to make,
   and it would be the same class as B-1.**
4. **`design-review-gate.md` §5.2.2 — is the dead end hand-off honest or a deferral dressed as one?**
   The operator required this gap to be closed *first*; this design sequences it as slice 1.5 behind
   slice 1. **That ordering is this revision's judgement against the decision's own word, and it is
   flagged as one.** A reviewer who thinks slice 1 must be blocked until 1.5 has a decision should
   say so plainly — it is the second-most-consequential thing in this artifact.
5. **`design-review-gate.md` §5.2 — is the decision applied completely?** Reading B is in force, but
   a decision chooses a *scope*, not a mechanism. Specifically: is the route-3 guard correctly
   placed, is P3 correctly justified, and is `G5′`'s **six** the right number.
6. **`design-review-gate.md` §6 sub-slice 1b — is `scheduler.dart:1746` really the blocking
   `const`?** The sub-slice depends on that literal becoming a computed map. If a caller already
   computes it elsewhere, the sub-slice is over-scoped.
7. **§2.1 and §2.1a against the tree.** Whether the corrected dead-end locations are right. These
   were asserted by the review and adopted here; if either is wrong, slice 2c's shape is wrong.
8. **§3.3's per-path split.** Whether declining design remediation on M10 — against an establishable
   shape — is still the right call, now that the reasoning is stated rather than inferred.
9. **§6's M12.** Whether restoring the brief's M2 is complete, or whether other brief items were
   also dropped and this is a partial repair.
10. **THE DISCIPLINE, not the content.** §12 now lists **eleven** corrections, **nine of them
    errors this lane made and a review caught**, six of them of one kind: citing a range as
    evidence for a property that range does not state. **The correction proposed is not "check the
    lines" — revision 2 checked them.** It is: *every load-bearing property gets an assertion that
    fails when the property is absent.* A reviewer should decide whether this design actually holds
    to that everywhere, because that is the thing that has now failed twice.

Handed to an independent `design-reviewer`. **This lane does not approve its own work.**
