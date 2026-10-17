# Design Revision — Revision 2 — QA contracts for feature intake and design remediation

**Brief:** [`QA-CONTRACTS-FEATURE-REMEDIATION`](./design-brief.md) (Revision 1, `DESIGN_REVISION_BLOCKED`)
**Revision number:** 2
**Supersedes:** Revision 1 (`8F3B27D4-6C15-4E9A-B0D7-3F62C81A4E50`, authored at `ad4fada`)
**Governing decision:** `.decisions/2a8f5c31-9d47-4e6b-b2f8-7c15e0d9a4b2.yaml` (HD-1, RESOLVED)
**Authoring HEAD:** `e3634a0cbbdf656267b22908284dd1ae8b655085` (revision 1)
**Corrected at:** `c8fd361906f0d831bbcfd431b75d1eb21ae9db5d` (this revision)
**Branch:** `main` (worktree `/Users/alkebut/air/shipit-platform`)
**Authored by:** `design-agent` / lane `design-QA-CONTRACTS-CORRECTION`
**Disposition:** `DESIGN_REVISION_COMPLETE` — Revision 1's central defect (the deliverable-2 gate's
refusal sink did not exist) is corrected with a specified park; deliverable 3 remains **declined on
evidence**, now split **per path** rather than asserted for both; and **one reading of HD-1 is
specified and explicitly left for an independent reviewer to judge** (`design-review-gate.md` §5.2).

> **Revision 1 was returned as `DESIGN_REVIEW_HUMAN_DECISION_REQUIRED` with `CORRECTION_REQUIRED:
> YES` — 1 BLOCKING, 4 HIGH, 4 MEDIUM, 2 LOW.** Every item is addressed. The independent review's
> confirmations (F-49, F-51, F-52, feature intake's refusal, and the citation discipline) are
> **preserved unchanged** and were not rebuilt; §12 records which of them this revision deliberately
> left alone.

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
`c8fd361`; nothing was amended, rebased or reset. **`docs/engineering/FOLLOW_UPS.md` was not
modified** — it is the Manager's, and F-47 already records B3.

**Two non-goals are WITHDRAWN by this revision**, both because independent review showed their
premises false: *"Not a new `WorkItemState`"* and *"Not a new edge to
`waitingForHumanDecision`"*. See §11 and `design-review-gate.md` §3.5 and §5.1. Nothing else in §11
changes, and the review verified the remaining ones stand.

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
   (`work_item_transitions.dart:51-53`'s shape), carrying a durable `blockingReason`
   (`durable_workflow_engine.dart:222-225`);
4. **no edge back** to `planned`, `designNotRequired` or `agentCompleted` — the reasoning at
   `:45-50`;
5. it is **idempotent**, which is what `server.dart:1412-1414` demands ("the scheduler re-surfaces
   the same job every tick … so this must be idempotent"), and which falls out of the state: a
   parked item is at a state in no `completionInflowFrom`, and is no longer `agentCompleted`, so the
   stand-down branch at `:2860` is never reached for it again.

**New assertion G7 closes the hole Revision 1's suite could not see:** *a refused intake item is at
`designReviewRequired` — not `agentCompleted` — within one tick.* This document no longer cites
G1/G2 as evidence that the gate fails closed.

### 4.4 The human route, and the reading this revision specifies

Revision 1 left `waitingForHumanDecision -> implementationReady` (`:599-602`) **unguarded**, on the
reading that HD-1's `rationale_given` asks for no *"unattended"* dispatch — and then declared
`human_decisions_required: []`.

**This revision specifies the opposite reading and flags it for judgement.** HD-1's `delegated`
clause is unconditional — *"What is NOT delegated is that an IMPLEMENTER dispatch must be preceded
by a satisfied design review for items originating on these two paths"* — and the word *"unattended"*
appears in the **rationale**, describing the harm, not narrowing the clause. So the guard **is** on
the human edge.

**What that costs, stated rather than minimised:** `HumanDecisionRouting.targetFor` routes four
decision pairs to `implementationReady`
(`packages/workflow_engine/lib/src/transitions/human_decision_routing.dart:103-104, 107-108,
109-110, 119-120`) — `(engineeringReview, rework)`, `(qaWaiver, reject)`, `(qaRework, reject)`,
`(humanQaApproval, reject)`. With the guard on, none of them can move an intake item to an
implementer until an approved `design_revision` exists, and **nothing writes one**
(§1.3, M5–M7). Until slice 3 lands, **intake items park and a human can re-triage, re-plan or stop
them — and nothing else.**

**That is the price, and this document asserts it is the right one**, on four grounds set out at
`design-review-gate.md` §5.2. **It is not settled here.** The operator was asked and answered *"Let
the design lane specify it and have it reviewed"* — so
**`design-review-gate.md` §5.2 is marked, in a boxed callout, as the single point an independent
`design-reviewer` must judge**, with the exact question and both branches spelled out.

R4 is therefore **re-opened, not closed**: Revision 1 recorded it as "RESOLVED in this revision" on
the strength of the narrower reading.

### 4.4 Defect-origin items take a different path

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
- **the operational cost of slice 1:** under the reading §4.4 specifies, both intake paths become
  unable to reach an implementer *permanently* until slice 3 lands, and a human's options at the
  park are re-triage, re-plan or stop. This is the consequence an operator must be told about before
  slice 1 ships, not after. `docs/**` is `PROHIBITED_PATHS` for this lane and was not written.

**1. The design-review gate — `design-review-gate.md` §6.** Self-contained, no dependency on the
evaluator, no dependency on the contracts. Sub-slices **1a** (the guard on the two caller-bearing
edges — **both in one commit**, `design-review-gate.md` §5.3), **1b** (the single context writer,
the single park helper, and the `DesignGovernanceStore` wiring in the composition root), **1c**
(the edge pins `implementation_ready_edge_test.dart` already asserts by name, extended for G5′/G6),
**1d** (the park: one new state, three edges, G7–G10/G12/G13). **This is the only slice in this
revision that changes what the platform does**, and it is a strict reduction in what the platform may
do **unattended *and* attended** — which is the reading §4.4 specifies and the point an independent
reviewer must judge.

**Sequencing constraint inside slice 1, and it is load-bearing:** 1d must not lag. A route-1 guard
without the park is the BLOCKING finding reproduced in code — a refusal that goes nowhere, tested
green by G1/G2.

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

**4. M8 + M9 + M10 (feature intake) and M12 + M10 (design remediation) — a real run per path**,
then, and only then, the two path-specific contracts. **This slice is what makes §4.4's reading
decisive rather than academic:** a real intake run produces a commit, which makes
`(engineeringReview, rework) -> implementationReady` (`human_decision_routing.dart:103-104`) a live
path for an intake origin, and an unguarded route 3 would be a live bypass of HD-1's undelegated
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
| **R3** | The design-review gate strands an intake item silently | **Was LOW — was wrong** | **CRITICAL** | **Revision 1's mitigation was void and this is the BLOCKING finding.** It claimed a refused item "stays at `agentCompleted`… which fails closed into a blocking human decision"; `engineeringReviewMissingArtifact` **stands down** for a no-commit producer (`engineering_review_gate.dart:2860-2871`, `:2210-2228`; `server.dart:1416-1421`), so the item sat there forever, repeating the same refused route every tick. **Mitigated in this revision** by the specified park (`design-review-gate.md` §5.1.1) and, above all, by **G7** — a refused intake item must be at `designReviewRequired`, not `agentCompleted`, within one tick — plus G9 (idempotence) and G10 (no bypass loop). The rating stays **CRITICAL**: the failure mode is a silent, indefinitely-repeating dead end with a green suite over it, which is the worst combination in this table. |
| **R4** | A human cannot move an intake item to an implementer at all | HIGH | HIGH | **Re-opened; Revision 1 recorded this as "RESOLVED" and that was wrong.** §4.4 specifies the guard ON the human edge (HD-1's undelegated clause is unconditional), and nothing writes an approved `design_revision` until slice 3. So today a human's options at the park are re-triage, re-plan or stop. **This is the specified behaviour, not an unresolved risk** — but it is the reason §5.2 is marked for independent judgement, and it is escalated to the Manager as a consequence to be recorded before slice 1 ships (slice 0). |
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
  edges**. No edge added, removed or retargeted. Deliberately: the design lane's own §4.1 Fact 2
  finding is that adding edges is how this graph gets disconnected.
- **Not** a change to `HumanDecisionRouting` — no new `HumanDecisionType`, no new routing arm, no
  new decision type. **Still true, and now load-bearing rather than incidental:** the park exits on
  `escalation`, whose `targetFor` arms already exist
  (`human_decision_routing.dart:121, 132-135`), so no routing table is touched. §4.4 explains what
  that costs.
- ~~**Not** a new `WorkItemState`.~~ **WITHDRAWN by this revision.** The premise was that one guard on
  an existing edge "cannot create a dead end, because a refused guard leaves the item exactly where
  it was, in a state that already has exits" (`design-review-gate.md` §3.4). **`agentCompleted` does
  not have a usable exit for these origins** — the one consumer of that state stands down (§4.3) —
  so the premise was false and the non-goal was the thing that hid the BLOCKING finding. One state
  is now specified, with three edges, modelled on `featureIntakeParked` (`:31-53`). **Cost of the
  reversal, stated:** `workflow_state.dart` gains a variant and four registration entries, and the
  transition table gains three rows. That is a graph change inside a design that is otherwise two
  guard rows, and a reviewer who thinks that is too much should read §5.2 — because the cheaper
  alternative is a refusal with nowhere to go.
- ~~**Not** a new edge to `waitingForHumanDecision`.~~ **WITHDRAWN with the above**: the park's only
  way out is that edge, on the `:51-53` shape.
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
| **Revision 1 §2.1 (this lane's own)** | *"a work item … walks to `qaInProgress` and stops there permanently"* | **It stops at `reviewApproved`.** Nothing takes `reviewApproved -> qaInProgress`; `reviewApproved` is in no `entryStates` and no production code transitions to it. §2.1, `evaluator-spec.md` §2.1. **A live contradiction this lane asserted, not inherited.** |
| **Revision 1 §4 / deliverable-2 table (this lane's own)** | `agentFailed -> implementationReady` is an **automatic** route carrying the guard | **It has no caller.** The only `completionInflowFrom` is `{agentCompleted}` (`implement_feature.dart:117`); the inflow filters on it (`scheduler.dart:1522`). §2.1a. |
| **Revision 1 §4.3 (this lane's own)** | a refused item "stays at `agentCompleted` … `blockedArtifactMissing` → a **blocking human decision**" | **The handler stands down** (`engineering_review_gate.dart:2860-2871`). §4.3. **This was the BLOCKING finding.** |
| **Revision 1 §3.3 (this lane's own)** | *"There is no consumer on either path"* | **True for feature intake; under-stated for design remediation**, where the shape *is* establishable and only the type is missing. §3.3. |
| **Revision 1 §9.3 (this lane's own)** | brief's M1–M4 "carried forward as M8–M10" | **M2 was dropped.** Restored as M12. §6. |
| Correction spec (Manager), B1 | the completion-inflow filter is at `scheduler.dart:1527` | **`:1522`.** The Manager's figure is off by five; the claim itself is confirmed. Recorded because the citation is load-bearing for the whole finding. |
| Correction spec (Manager), H3 | `triage_defectInstruction` at `triage_defect.dart:222-278` | **`:222-276`.** `:277-278` are the doc comment and signature of the next function. The schema block at `:249-264` is confirmed exactly. |
| Correction spec (Manager), H1 | `scheduler.dart:1527`; `implement_feature.dart:117` | `:1522` as above; `:117` **confirmed correct**. |
| `design-resume.md` "Read first" | `work_item_transitions.dart:657-662` for `qaInProgress -> qaPassed` | **`:690-696`**. `:657-662` is a comment block about `reviewRejected`. The conclusion is unchanged and stronger (§2.1). |
| `design-resume.md` "Read first" | `triage_processor.dart:272-276` for `_extractDefectId` | **`:279-285`**. `:272-276` is the tail of the `FormatException` handler. The code is exactly as described. |
| Predecessor brief §4.2 | `possibleDuplicateDefectId` `:254`, `recommendedWorkItemCategory` `:256`, `summary` `:257`, `suspectedComponents` `:221-223` | `:259-260`, `:261-262`, `:263`, `:224-226`. All drifted; the table's substance is right. |
| Predecessor brief §5 / metadata | `triage_processor.dart:120-124`, `:125-132` | `:120-132` and `:124-132`. Substance right. |
| `FOLLOW_UPS.md` §13 F-47 and `design-resume.md` | `work_item_transitions.dart:661` for `qaInProgress -> qaPassed` | Same off-by-29 as the resume spec; correct line is `:690-696`. **`FOLLOW_UPS.md` §13 line 1073 carries this citation** — Manager-owned, not corrected here. |

**One inherited conclusion is now wrong rather than merely mis-cited:** the predecessor's §3.3
"proof by execution" that the parked feature is dispatchable, and its `CONTRADICTION` against
F-45. Both are resolved by `ddfbfff` (§1.1), and the brief's Flow A no longer describes HEAD.

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
7. **The park's human surface is specified by what it is *not*.** I have specified the state, the
   edges, the durable reason and the idempotence. I have **not** specified which decision type
   should be raised at the park's exit, and §5.2's table shows why: `escalation` is the only
   existing type whose answers are all safe (re-triage, re-plan, cancel), and choosing a *new* type
   to give a human a "produce a design review" option would require a `HumanDecisionRouting` arm —
   an architecture change, not a gate-shape one. **So the specified park hands a human three answers
   and none of them is "do the design review".** That is a real gap in the specification, it is a
   deliberate one, and it is a consequence of the reading §5.2 specifies. If a reviewer judges
   Reading A instead, this gap disappears along with the park.
8. **I have not re-run the two test suites from §14.** They were run at `e3634a0` by Revision 1 and
   no production code changed, so re-running would produce the same output; this revision's claims
   are all tree-derived and none depends on a test result. Stated rather than implied.
9. **R1 remains UNMITIGATED.** The drift test that would mitigate it is *specified* (sub-slice 1b)
   but does not exist, and no design artifact can supply it. §10 says so in the row rather than in a
   footnote.

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

No command in this lane mutated state. No docker, no compose, no `psql`.

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
  reading of HD-1 that is not settled here marked, in a boxed callout, as the single point an
  independent reviewer must judge.

**And because the correction that matters most is uncomfortable.** Revision 1's central claim —
*"a refused guard leaves the item where it was, which is not a dead end"* — was **false**, and it was
false in the one place where it was load-bearing. The failure it would have shipped is silent,
repeats every tick, and would have been covered by a green suite: G1 and G2 assert only that the item
does not reach `implementationReady`, which a dead end satisfies. **The lesson generalises past this
design:** a refused guard is only as safe as the exit its state has, and the reviewer of this
revision found that the assertion suite could not tell "parked" from "vanished" because nothing in
it ever asked.

**And the finding that recurs:** `work_item_transitions.dart` declares edges that no caller takes —
`reviewApproved -> qaInProgress`, `agentFailed -> implementationReady`, and (per
`design-review-gate.md` §5.2) four decision pairs that route to `implementationReady`. Revision 1
read the table as a map of what happens. It is a map of what *may* happen. **That is how five live
contradictions survived a review, and it is why the assertions in this revision are written to fail
on absence rather than on presence.**

---

## 16. What an independent reviewer should check, in priority order

1. **`design-review-gate.md` §5.2 — the reading of HD-1.** Not whether the argument is well-made but
   whether the operator's text supports it. This is the one point deliberately left open.
2. **`design-review-gate.md` §5.1 — the park.** Whether `designReviewRequired` is the right answer
   to B1, or whether the honest answer is to change the stand-down instead (an architecture change
   behind a resolved decision, which this lane cannot make).
3. **G7.** Whether an assertion that the item *leaves* `agentCompleted` is sufficient, or whether
   the reviewer's view is that the design must also prove the park cannot be re-entered.
4. **§2.1 and §2.1a against the tree.** Whether the corrected dead-end locations are right. These
   were asserted by the review and adopted here; if either is wrong, slice 2c's shape is wrong.
5. **§3.3's per-path split.** Whether declining design remediation on M10 — against an establishable
   shape — is still the right call, now that the reasoning is stated rather than inferred.
6. **§6's M12.** Whether restoring the brief's M2 is complete, or whether other brief items were
   also dropped and this is a partial repair.

Handed to an independent `design-reviewer`. **This lane does not approve its own work.**
