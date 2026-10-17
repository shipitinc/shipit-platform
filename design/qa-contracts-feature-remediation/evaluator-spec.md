# Evaluator Spec — the QA gate evaluator

**Parent:** [`design-revision.md`](./design-revision.md) §5 — deliverable 1
**Authoring HEAD:** `e3634a0cbbdf656267b22908284dd1ae8b655085` (revision 1)
**Revision 2 at:** `c8fd361906f0d831bbcfd431b75d1eb21ae9db5d`
**Revision 2 corrected at:** `90b6f5f` (revision 2 correction lane
`design-QA-CONTRACTS-CORRECTION-2`) — LOW finding L-2: the triage contract's `required` flags are
counted correctly in §5.3 and §6.
**Correction pass 3 at:** `2b182fd3215fde12a5814f0c7db4753514aa4c62` — two changes, both mechanical
and both recorded where they were made: **the evaluator's slices are renumbered 2a/2b/2c → 3a/3b/3c**
(§8 of `design-revision.md`; the crosswalk is at `design-review-gate.md` §0.2), and **`§4.3` V6's
citation of `implementation_inflow.dart:1543-1578` is corrected** — that file is 440 lines long, so
the range pointed 1103 lines past its end; the property is stated at **`:124-126`** and demonstrated
at `scheduler.dart:1582-1599`. **No finding, no gate, no gate-result vocabulary and no ordering
constraint in this document changed.**
**Correction pass 4:** see `design-revision-metadata.yaml` `correction_pass_4_base_sha` (lane
`design-QA-CONTRACTS-CORRECTION-4`). **PROVENANCE ONLY — NO FINDING, NO GATE, NO GATE-RESULT
VOCABULARY AND NO ORDERING CONSTRAINT IN THIS DOCUMENT CHANGED.** The round-4 review confirmed the
pass-3 work in this file as exact: the 2a/2b/2c → 3a/3b/3c renumbering and the disposal of the phantom
"slice 2.3" both stand, and V6's corrected citation (`implementation_inflow.dart:124-126`) stands.
**The pass-4 fork — a new `HumanDecisionType` for the design-review park
(`.decisions/3e5a7c26-4b19-4f83-a0d7-6c29b8f1e540.yaml`) — does not touch this document**, because
the fork is entirely about the *human decision* routing tables and the park's call site, and nothing
here reads either. **Stated explicitly because "this document was in scope and I did not change it"
is exactly the claim a later reader cannot verify, and because the round-4 dispatch's own orphan sweep
had a demonstrated blind spot in a different artifact — so the non-change is recorded here rather
than left inferable from silence.**
**Correction pass 5:** see `design-revision-metadata.yaml` `correction_pass_5_base_sha` (lane
`design-QA-CONTRACTS-CORRECTION-5`). **PROVENANCE ONLY — NO FINDING, NO GATE, NO GATE-RESULT
VOCABULARY AND NO ORDERING CONSTRAINT IN THIS DOCUMENT CHANGED, AND THE NON-CHANGE WAS ESTABLISHED BY
READING, NOT INFERRED FROM SILENCE.** Pass 5's substantive change is the operator's
`.decisions/5a90c1d3-8e47-4b26-9f0c-3d7a5b2e6c19.yaml`, which restores the design-review park's fourth
answer and so adds a `HumanDecisionChoice`, an arm in `targetFor`, a third
`blockingHumanDecisionResolved` whitelist admission, and a presentation registration in
`apps/control_plane`. **This document reads none of them**: it is about `qaInProgress -> qaPassed`, the
`gateRegistry` evaluators, and the `gateResults` / `qaContract` context contract, and it contains no
claim about the park's menu, its decision type, its options list, or its routing arms — **verified by
reading all 526 lines, because this document established that convention on pass 4 and a non-change
that is merely asserted is the claim a later reader cannot check.**
**One finding pass 5 made in an adjacent file and did NOT propagate here, recorded so its absence is
deliberate:** pass 5 found `apps/control_plane/lib/shared/decision_choice.dart:12-19`'s
`knownDecisionChoices` to be a hardcoded six-value set against a ten-value enum, with the file's own
doc comment enumerating the six as though they were the enum's. **That file is a fourth registration
site for a human decision's presentation, and this evaluator spec does not read it either** — but
this document's subject (`gateRegistry`) is not a human decision, so the finding does not touch it.
**The finding is recorded in `design-revision-metadata.yaml` `durable_discoveries` rather than here,
because `durable_discoveries` is where a finding is meant to outlive the pass that made it.**
**Status of this document:** a specification. This lane implements no production code.

> The mandate: *"Who populates `context['gateResults']`, from what, at which point in the
> transition, and how a gate's `config` is actually read. Name the code that does it, or state it
> must be built and what it must do."*

**Answer in one line:** it must be built; the gate reads `context['gateResults']` and
`context['qaContract']`; nothing produces either; the producer belongs at the
`qaInProgress -> qaPassed` call, which today has no caller at all; and the four evaluators that
*are* registered must be treated as unimplemented before anything is wired.

---

## 1. What the guard actually reads — the whole contract

`packages/workflow_engine/lib/src/validation/guard_conditions.dart:257-318`:

```dart
final gateResults = context?['gateResults'] as List<QAGateResult>?;   // :267
if (gateResults == null) {                                            // :268-270
  return GuardResult.fail(name, 'Gate results required for QA evaluation');
}

final requiredGates = gateResults.where(
  (g) => context?['qaContract']?.gates.any(                            // :274
        (gc) => gc.gateId == g.gateId && gc.required) ?? false,
);

final allSatisfied = requiredGates.every(_isGateSatisfied);             // :280
```

So the guard consumes **two** context keys, not one:

| Key | Type | Used for | Failure mode if absent |
|---|---|---|---|
| `gateResults` | `List<QAGateResult>` | the results to judge | **fail**, `'Gate results required for QA evaluation'` (`:269`) |
| `qaContract` | `QAContract` | which of them are *required* | `requiredGates` is empty, so `.every()` on an empty iterable is **`true`** → **silent pass** |

**That second row is a live hazard and it is the opposite of fail-closed.** `allRequiredGatesPassed`
would return `GuardResult.pass` for an empty `gateResults` list — except that the `null` check at
`:268` catches the empty-adjacent case first. But supply `gateResults: []` **with** no `qaContract`
and the guard **passes**, vacuously, having evaluated nothing.

`design-brief.md` recorded the `gateResults` half. The `qaContract` half is not recorded anywhere,
and it is the half that makes a partially-wired evaluator *look* enforced: a producer that fills
`gateResults` but not `qaContract` yields a QA pass that judged nothing.

**This is a required property of the wiring slice:** both keys, in the same context map, or the
transition must not be attempted. `evaluator-spec.md` §4.3 makes it a non-vacuity assertion.

`_isGateSatisfied` (`:291-305`) is already correct and needs no change:
`passed`/`waived`/`notApplicable` satisfied; `skipped` satisfied only with an authority reference
(`:307-317`); `pending`/`running`/`failed`/`notExecuted` **not** satisfied. In particular
`notExecuted` is unsatisfied — which is why the current state is *honest* rather than *green*, and
why §5's ordering constraint is the thing standing between "honest" and "falsely green".

---

## 2. The transition, and the fact that nothing takes it

```dart
// packages/workflow_engine/lib/src/transitions/work_item_transitions.dart:690-696
(WorkItemState.qaInProgress, WorkItemState.qaPassed): [
  GuardConditions.actorAllowed([ActorType.qaExecutor, ActorType.orchestrator]),
  GuardConditions.allRequiredGatesPassed(),
],
```

`qaInProgress` is entered from exactly one edge — `reviewApproved -> qaInProgress`
(`:651-654`) — and has exactly two out-edges: this one and `qaInProgress -> qaFailed`
(`:697-702`).

### 2.1 Nothing takes `reviewApproved -> qaInProgress` either — revision 1 got the chain wrong

Revision 1 wrote the walk as:

```
agentCompleted -> reviewInProgress -> reviewApproved -> qaInProgress -> STUCK
```

**That is wrong by one hop, and the error mattered:** it put a QA drain in slice 3c that would have
had nothing to drain. Verified:

- `reviewApproved` is in **no** `JobDefinition.entryStates`. Every `entryStates` set in the
  repository is `baseline_product.dart:42`, `triage_defect.dart:126`,
  `scheduler.dart:3200, 3262, 3276, 3361`, `implement_feature.dart:114` — `reviewApproved` is in
  none of them.
- Its **only** in-edge is the human one, `waitingForHumanDecision -> reviewApproved`
  (`:425-434`), guarded by `blockingHumanDecisionResolved({(engineeringReview, approve)})`.
- Its **only** out-edge is `reviewApproved -> qaInProgress` (`:651-654`).
- **No production code calls `transition(to: WorkItemState.reviewApproved)` or
  `to: WorkItemState.qaInProgress`.** Every such call site in the tree is in a `*_test.dart`.

**So the real chain is two dead ends, not one:**

```
agentCompleted -> reviewInProgress -> reviewApproved -> STUCK          ← (no caller of the out-edge)
                                                                  \
                                                                   -> qaInProgress is UNREACHABLE
```

**Consequences, both required:**

1. `design-revision.md` §2.1's claim that *"every reviewable work item … walks to `qaInProgress` and
   stops there permanently"* is **corrected**: it stops one hop earlier, at `reviewApproved`, and
   `qaInProgress` is unreachable. The finding is not retired — it moves one state left and grows a
   second one.
2. **Slice 3c must be widened.** It is not "the drain"; it is *the drain **and** whatever walks
   `reviewApproved -> qaInProgress`*. The engine may not be reimplemented here, so slice 3c's
   specification is: **name the caller**, and its obligations are the existing
   `actorAllowed([orchestrator])` + `qaContractExists()` on that edge. The *reason* no caller exists
   is the design-governance-adjacent gap `server.dart:1327-1330` generalises: a transition declared
   with a guard nobody can satisfy is a wall, and the guard here — `qaContractExists()` — requires a
   product-declared contract, which not every product has. **Whoever designs that caller must decide
   what happens for a product that declared no contract, and this document does not decide it.**

### 2.2 The rest of the walk, and who can take `qaFailed`

`qaInProgress` is in **no** `JobDefinition.entryStates`, so nothing dispatches from it either.
`AgentRole.qaExecutor` exists (`agent_role.dart:6`) but `QAOrchestration` — the class that would be
that executor's brain — is constructed in exactly one place in the repository: its own test file
(`packages/qa_orchestration/test/qa_orchestration_test.dart`).

```
agentCompleted -> reviewInProgress -> reviewApproved -> STUCK
                                qaPassed requires allRequiredGatesPassed, which can only fail
                                qaFailed admits [qaExecutor, orchestrator] — and nobody dispatches either
```

**Correction to revision 1** (LOW finding): revision 1 wrote *"`qaFailed` requires a `qaExecutor`
that nothing dispatches"*. That is incomplete. The edge admits **both**
(`work_item_transitions.dart:697-702`):

```dart
(WorkItemState.qaInProgress, WorkItemState.qaFailed): [
  GuardConditions.actorAllowed([
    ActorType.qaExecutor,
    ActorType.orchestrator,      // ← revision 1 omitted this
  ]),
],
```

`design-revision.md:153-154` had it right; this document did not. **The distinction is load-bearing
for slice 3c:** the failure arm is reachable by `ActorType.orchestrator` today, which is what makes
§4.2 step 4's "record a failed QA rather than silently leave it in place" a wiring change rather
than a new-actor change.

---

## 3. The evaluator service

### 3.1 What it is

A new class in `packages/qa_orchestration/lib/src/`, beside `qa_orchestration.dart`:

```
QAGateEvaluationService.evaluateForWorkItem({
  required String workItemId,
  required String qaContractId,
  required AgentResult agentResult,
}) → Future<QAGateEvaluationOutcome>
```

returning **both** halves the guard needs:

```dart
class QAGateEvaluationOutcome {
  final QAContract contract;          // → context['qaContract']
  final List<QAGateResult> results;   // → context['gateResults']
}
```

The pairing is not cosmetic. §1 shows the guard silently passes when one key is present and the
other is not, so the two must be produced together by one call that cannot return half.

### 3.2 What it does — step by step

1. `contractStore.readQAContract(qaContractId)` → `QAContract`. Throws if absent; a work item
   stamped with an unreadable contract id is a store fault, not a gate failure, and must not be
   reported as one.
2. **`QAOrchestration.evaluate(workItemId, agentResult, contract)` — called verbatim**, not
   re-implemented. That method (`qa_orchestration.dart:11-39`) already does the right thing for
   every case:
   - registered type → `evaluator.evaluate(workItemId, agentResult, gate)` (`:34`);
   - unregistered type → `QAGateResult(status: QAGateStatus.notExecuted, evidence: [],
     metadata: {'reason': 'No evaluator for gate type: …'})` (`:21-29`).

   Re-deriving this loop would create a second definition of "unregistered", and the two would
   drift — which is exactly how `optionalGateFailuresAllowed` already drifted in meaning once
   (`design-brief.md` §11).
3. Apply `passCriteria` via the existing `QAOrchestration.isOverallPass` (`:83-120`) and
   `requiresFormalDetermination` (`:67-81`) and record both in the outcome. Neither is read by the
   guard, which does its own required-gate walk; they are recorded so the determination lane has
   them, and so a future change to the guard has a second, independent computation to compare
   against.
4. Persist the results durably. **The guard reads only `context`, and `context` is discarded** —
   `DurableWorkflowEngine.transition` passes it to the policy (`packages/workflow_store/lib/src/durable_workflow_engine.dart:173`)
   and writes nothing from it (`:211-233`). A `QAGateResult` that is only ever in a context map is
   an operator cannot see. There is a `PostgresQaReviewResultStore`
   (`apps/server/lib/src/persistence/postgres_qa_review_result_store.dart:10`); the persist call is
   the implementer's choice between it and a new table, and either is acceptable — what is **not**
   acceptable is context-only.

### 3.3 What it must not do

- **Must not evaluate the same contract twice and disagree.** One evaluation per transition.
- **Must not coerce an unreadable contract to "no gates".** An empty gate list with
  `allRequiredGatesMustPass: true` evaluates to pass (`:95-99` iterates nothing). A contract with no
  gates is refused at provisioning
  (`product_qa_contract.dart` `declaresNoGates`), so this is a store-integrity case, and it must
  surface as a fault rather than a pass.
- **Must not treat `notExecuted` as anything but unsatisfied.** Already true
  (`qa_orchestration.dart:56-61`); stated because §5 changes what is registered.

### 3.4 `sourceColumn` is a label, never a query

The only `config` key vocabulary declared anywhere in this repository is
`structuredClassificationAdmitted`'s
(`packages/qa_orchestration/lib/src/lane_g_triage_qa_contract.dart:172-188` — **note the package
path: this file lives under `packages/qa_orchestration/lib/src/`, not
`apps/server/lib/src/triage/`.** Revision 1 cited it without one; see `design-revision.md` §12):

```dart
config: <String, dynamic>{
  'sourceColumn': 'agent_result.structuredResultJson',   // :178
  'requiredFields': ['classification','status','confidence','suspectedCategory'],
  'classificationEnum': 'DefectClassification',           // :185
  'statusEnum': 'DefectStatus',                          // :186
},
```

`sourceColumn` names a table and a column. `config` arrives from a **product manifest**, which is
operator-authored JSON persisted by
`apps/server/lib/src/endpoints/product_registry_endpoints.dart:470-510`. Therefore:

> **`sourceColumn` MUST never be interpolated into a query.** An evaluator that does
> `SELECT … FROM ${config['sourceColumn']}` has turned an operator-supplied string into a SQL
> surface, on a path that runs for every work item of a governed product.

The evaluator reads the document through the **typed store reader** —
`ExecutionStore.readResult(...)` → `AgentResult.structuredResult`
(`packages/platform_contracts/lib/src/types/agent_result.dart:43`, `Map<String, dynamic>`) — and uses
`sourceColumn` **only** to populate the evidence row's `artifactRef`, which is already the
convention (`static_analysis_gate.dart:23`, `artifactRef: 'analysis-report.json'`).

A gate whose evidence genuinely lives elsewhere declares an **evidence type** that a named
`EvidenceCollector` implements, which is the extension point the architecture already has
(`packages/qa_orchestration/lib/src/gates/gate_evaluator.dart:5-13`). There is no need for a
config key to name a table, and allowing one is how that would happen.

---

## 4. The transition call site

### 4.1 Where the keys go

The `qaInProgress -> qaPassed` transition, called with:

```dart
context: {
  'qaContract':  outcome.contract,
  'gateResults': outcome.results,
  // …plus whatever the guards already need: this edge carries
  //    actorAllowed([qaExecutor, orchestrator]), which reads context['actorType'].
}
```

`ActorType` is resolved by `_ActorAllowedGuard`; the caller must pass the actor in the context in
the shape that guard reads. **This is the one detail an implementer must copy from an existing
caller rather than infer** — see §4.3.

### 4.2 Who calls it, and with what actor

Nobody today (§2). The wiring must add a drain that:

1. runs on the tick loop beside the existing `implementationTick` / `reviewTick`
   (`apps/server/lib/server.dart`), **not** as a new `Scheduler` — `qaInProgress` is a state that
   needs a *transition taken*, not a job dispatched, and adding a `JobDefinition` for it would
   reintroduce the `agentExecuting` stranding that `human_decision_routing.dart:12-30` documents;
2. reads items at `qaInProgress`;
3. calls `QAGateEvaluationService.evaluateForWorkItem(...)`;
4. takes the transition with `ActorType.qaExecutor` when `isOverallPass`, and with
   `ActorType.orchestrator` when it is not — the edge permits both (`:691-694`), and the
   distinction is what lets a *failed* QA be recorded rather than silently left in place;
5. on `qaFailed`, raises the blocking `qaRework`/`qaWaiver` decision that
   `qaFailed -> waitingForHumanDecision` expects (`:709-715`).

The closest existing precedent for "a lane that cannot dispatch raises a blocking human decision
instead" is the engineering-review missing-artifact drain (`apps/server/lib/server.dart:540-543`).
**Follow it**, including its distinction between channels: a channel that carries job ids cannot
carry a refusal for which no job was ever created.

### 4.3 Required non-vacuity assertions

The lane `docs/engineering/FOLLOW_UPS.md` §12 records is the lesson here: *"A prohibited-path
boundary hid a regression from the lane that could have caught it"*, and F-15 records that nothing
runs the relevant suite. So the wiring slice ships assertions that **fail when the gate is
bypassed**, not assertions that pass when it works:

| # | Assertion | Fails if |
|---|---|---|
| V1 | A work item at `qaInProgress` with a contract whose required gate **fails** does not reach `qaPassed` | `allRequiredGatesPassed` stops reading `gateResults` |
| V2 | A work item at `qaInProgress` with a contract whose required gate has **no registered evaluator** does not reach `qaPassed`, and its result is `notExecuted` | `notExecuted` is ever treated as satisfied |
| V3 | `gateResults` present but `qaContract` **absent** does not reach `qaPassed` | §1's vacuous-pass hole is reopened |
| V4 | `gateResults: []` with a contract declaring gates does not reach `qaPassed` | §1's empty-iterable hole is reopened |
| V5 | The drain reaches `qaFailed` (not `qaPassed`) on a failing contract, and a blocking decision is raised | the failure arm of `:691-694` is dropped |
| V6 | The drain is per-item isolated: one item whose contract id is unreadable does not lose the lane's whole tick | the throw escapes — the exact failure `implementation_inflow.dart:124-126` was written about (*corrected in pass 3: this row previously cited `:1543-1578` of a 440-line file*) |

V3 and V4 are the two that do not exist in any form today and that a naive wiring would pass.

---

## 5. The ordering constraint — nothing may be wired before 5.1

### 5.1 The four registered evaluators return a fabricated `PASSING`

```dart
// packages/qa_orchestration/lib/src/gates/gate_evaluator.dart:53-58
bool _validateEvidence(List<QAEvidence> evidence, Map<String, dynamic> config) {
  return evidence.isNotEmpty;
}
```

`evidence` gains one entry per element of `gate.evidenceTypes` (`:31-39`).
`QAGateDefinition.evidenceTypes` is **required and non-null**
(`packages/platform_contracts/lib/src/types/qa_contract.dart:72`, `:80`). So `evidence.isNotEmpty`
is **true for every contract that declares at least one evidence type** — which is every contract
in this repository.

The content is fabricated:

| Gate | `gateType` | Returned content | Line |
|---|---|---|---|
| `StaticAnalysisGate` | `static-analysis` | `{'tool': config['tool'] ?? 'dart analyze', 'issues': []}` | `predefined/static_analysis_gate.dart:24` |
| `TestCoverageGate` | `unit-tests` | `{'format': 'lcov', 'threshold': 0.8}` — **no coverage value is ever read** | `predefined/test_coverage_gate.dart:24` |
| `SecurityScanGate` | `security-scan` | `{'tool': …, 'vulnerabilities': []}` | `predefined/security_scan_gate.dart:24` |
| `PerformanceGate` | `performance` | `{'benchmarks': [], 'thresholds': {}}` | `predefined/performance_gate.dart:26` |

**So wiring `QAOrchestration.evaluate` into production today turns "no gate is evaluated" into
"all four gates pass, with a durable evidence row asserting `issues: []`, `vulnerabilities: []`,
`thresholds: {}`".** That is a false green with an audit trail, and it is strictly worse than the
`notExecuted` the guard currently handles correctly.

### 5.2 What slice 3a must do, before any wiring

Independent review found that revision 1's option 1 **cannot achieve what it was offered for**, and
the review is right. Stated as corrected:

**Option 1 — replace `_validateEvidence` with content-reading validation — is INSUFFICIENT on its
own, and this document no longer offers it as an alternative to option 2.**

The reason is the four collectors, not the predicate. Verified at
`packages/qa_orchestration/lib/src/gates/predefined/`:

| Collector | Line | `QAEvidence.content` it returns |
|---|---|---|
| `static_analysis_gate.dart` | `:24` | `{'tool': config['tool'] ?? 'dart analyze', 'issues': []}` |
| `test_coverage_gate.dart` | `:24` | `{'format': 'lcov', 'threshold': config['threshold'] ?? 0.8}` — **no coverage value at all** |
| `security_scan_gate.dart` | `:24` | `{'tool': config['tool'] ?? 'trivy', 'vulnerabilities': []}` |
| `performance_gate.dart` | `:24-27` | `{'benchmarks': config['benchmarks'] ?? [], 'thresholds': config['thresholds'] ?? {}}` |

`evidence` is exactly what those collectors return (`gate_evaluator.dart:31-39`). **So a predicate
reading `QAEvidence.content` reads hardcoded collector output.** `issues` is `[]` for every work
item; `vulnerabilities` is `[]` for every work item; there is no coverage number to compare a
threshold against, and `performance` echoes the config back. **Every predicate expressible over that
content is a constant, and the predicate is a constant with more steps.**

Two specific failures of the predicates revision 1 listed, stated so no implementer re-derives them:

- **"`issues` non-empty" is unsatisfiable** with the current collector. The predicate would be
  `false` for every work item, turning the fabricated pass into a fabricated *fail* — still constant,
  still not a gate, and now it fails work that has not been assessed.
- **"`issues` non-empty, `vulnerabilities` empty" is not a predicate.** It is two independent clauses
  written as one with a comma, and no coherent reading of it is satisfiable at the same time: with
  the real collectors `issues` is empty, so the first conjunct is false for every input.

**So there are two options, and only one of them is safe:**

1. ~~Replace `_validateEvidence`~~ — **INSUFFICIENT.** It cannot be non-vacuous while the collectors
   are hardcoded. It would also *replace* code that is currently unreachable, changing nothing
   observable, and risk reading as remediation.
2. **De-register all four until they are real. This is the only safe option, and it is
   RECOMMENDED.** A registry that lists four evaluators which pass unconditionally
   (`design-revision.md` R10) teaches every future reader that `gateRegistry` means something it does
   not — and §5.1 shows the pass is fabricated, so it is teaching something *false*.
   Un-registering converts `passed` into `notExecuted` (`qa_orchestration.dart:21-29`), which
   `isGateSatisfied` already treats as unsatisfied (`guard_conditions.dart:299-303`) — the **honest**
   state, and the one the current guards handle correctly.
3. **Either way**, add a non-vacuity test that **fails** when the registry presents an evaluator
   whose evidence content is not a function of the work item — the same shape as V1–V6. Concretely:
   *for each registered type, two `AgentResult`s that differ must produce different evidence
   content.* The current four fail this trivially (identical output for identical config).

**What a real `static-analysis` gate should assert is a `qa_architect` call**, not a design call —
recorded in `design-revision.md` §9.3 and not decided here.

### 5.3 `triage-classification-structure` — the one evaluator that is honestly specifiable now

The first real evaluator, and the one that makes the *existing* triage contract enforceable.
Implemented against `GateEvaluator` **directly** (`gate_evaluator.dart:5-13`), **not** by extending
`GateEvaluatorImpl`, because §5.1 is a property of `GateEvaluatorImpl`.

| `config` key | Type | Required | Evaluation |
|---|---|---|---|
| `requiredFields` | `List<String>` | **yes** — malformed ⇒ `FormatException`, mirroring `product_qa_contract.dart:168-192` | each name must be a **present, non-null** key of `agentResult.structuredResult` |
| `classificationEnum` | `String` | **yes** — the only supported value is `'DefectClassification'` | the field's value must be in `DefectClassification.values.map((e) => e.wire)` |
| `statusEnum` | `String` | **yes** — only `'DefectStatus'` | likewise against `DefectStatus` |
| `sourceColumn` | `String` | no | **label only** — §3.4 |

`passed` iff every `requiredFields` entry is present and both enum fields resolve. Anything else is
`failed`, with the offending key named in the evidence row.

**This is justified by a live consumer**, which is the whole point
(`design-brief.md` §6, M4): `TriageProcessor._parseTriageResult`
(`apps/server/lib/src/triage/triage_processor.dart:199-222`) throws `FormatException` unless
`classification`, `status`, `confidence` and `suspectedCategory` are all present, and returns
`null` on `FormatException` (`:270-276`). **The four `requiredFields` at
`{L}:179-184` are exactly those four keys.** The gate records as an obligation
what is currently an accident of a `catch` block — which is what `{L}:78-83` says
it is for.

Two **non-negotiable** properties:

- **It is a structural gate, not a defect gate.** It must NOT assert anything about defect
  existence, evidence ownership, or classification *correctness*. It answers "is this a
  well-formed triage classification", nothing more. Anything richer belongs in
  `triage-evidence-grounding` / `triage-clarification-routing`, neither of which has an evaluator
  and neither of which is in scope here.
- **It must be honest about the triage gates that have no evaluator.** After slice 3, the triage
  contract's *first* gate is `PASSING` when the shape is right and its **second required** gate
  remains `notExecuted`. Because `allRequiredGatesMustPass: true` and that gate is `required: true`
  (`{L}:175` and `{L}:202`), `allRequiredGatesPassed` **still fails** — which is correct. Recording
  this matters: a reader who sees one triage gate enforced must not infer the contract is satisfied.
  `{L}:107-118` already states the honest position; keep `'evaluatorRuntime': 'absent'` (`:156`)
  until *every required* gate has an evaluator, and record the partial state in a way that cannot be
  read as full enforcement.

  > **Correction (LOW finding L2) — revision 2 counted this wrong.** It wrote *"both are
  > `required: true` (`{L}:175`, `:201`)"* about the two gates left `notExecuted`. **There are two
  > required gates and one optional one.** Verified at `90b6f5f`:
  > `triage-classification-admitted` `required: true` (`:175`) ·
  > `triage-evidence-grounded` `required: true` (`:202`) ·
  > `triage-clarification-routing` **`required: false`** (`:222`) — and deliberately so, per its own
  > comment at `:216-218`: *"It is conditional on ambiguity, which is a property of the report
  > rather than of the run, so a required flag here would mark every well-formed triage as a gate
  > failure."*
  >
  > **The conclusion is unaffected** — `triage-evidence-grounding` is required and has no evaluator,
  > so `allRequiredGatesPassed` still fails — but the reasoning has to be right, because the honest
  > reading is *"one required gate is unsatisfiable"*, not *"two are"*. A `required: false` gate being
  > `notExecuted` is not a gate failure at all, and an implementer who trusted the count would go
  > looking for a second evaluator to build.

---

## 6. State vocabulary

| Word | Meaning | Applies to, at `e3634a0` |
|---|---|---|
| `ABSENT` | no declaration exists | the two contracts this revision declines (`design-revision.md` §3) |
| `DECLARED` | a `QAContract` row exists; its gates are readable and auditable; **nothing evaluates them** | `qa-triage-*`; every `qa-product-*` |
| `PARTIALLY ENFORCED` | some gate types have evaluators and pass/fail honestly; the contract's `allRequiredGatesMustPass` still cannot be satisfied because other required gates are `notExecuted` | reachable only after **slice 3b** (`triage-classification-structure` has an evaluator) *and* slice 3c (the drain that calls it) — **and only for a product whose every other required gate type also has an evaluator** |
| `PASSING` | every required gate evaluated and satisfied by a real evaluator | **nothing in this repository, at any slice of this spec** |

The single sentence this spec exists to make true: **`DECLARED` is not `PASSING`, and the word on
the row must never imply otherwise.** Both existing builders already write
`'evaluatorRuntime': 'absent'` (`packages/qa_orchestration/lib/src/lane_g_triage_qa_contract.dart:156`,
`packages/qa_orchestration/lib/src/product_qa_contract.dart:156`); that key must
survive every slice, and must be **removed only** when the contract's every required
gate type has a real evaluator.

**Correction to revision 1 (MEDIUM finding).** This table said `PARTIALLY ENFORCED` was "reachable
only after slice **2.3**". **No slice 2.3 has ever existed under any numbering of this design** —
`design-revision.md` §8 defines three sub-slices of the evaluator, now numbered **3a**
(de-registration and the content-reading replacement), **3b** (implement
`triage-classification-structure`) and **3c** (the `qaInProgress` drain, widened per §2.1 to include
the `reviewApproved -> qaInProgress` caller). The reference was a phantom and it is corrected rather
than resolved to whichever slice seemed nearest, because guessing would have been the same defect one
level down.
> **Correction pass 3 renumbers these, and says why the correction above is now phrased in absolute
> terms.** `.decisions/b81f40c7-…` reversed the slice order (the human surface is now slice 1, the
> gate slice 2), so "2a/2b/2c" became "3a/3b/3c". **A correction that pins a phantom reference to a
> bare number is itself fragile**: had this paragraph kept saying "no slice 2.3 exists — §8 defines
> 2a, 2b and 2c", the renumbering would have made the sentence meaningless without anything being
> wrong in isolation. Phrasing it against what §8 *defines* rather than against a numeral survives a
> renumbering. **Same failure class as the L3 pattern, in the other direction:** a claim that is only
> true because of a label rather than because of what it names.

**And one thing this table should have said and did not:** `PARTIALLY ENFORCED` is **not reachable
at all** under §5.2 as corrected. Reaching it requires a contract's **required** gates to be
evaluated honestly, and the only contract with an evaluator after 3b is the triage contract — whose
one remaining **required** gate, `triage-evidence-grounding`, has none
(`lane_g_triage_qa_contract.dart:199-209`, `required: true` at `:202`; package path given at §3.4).
Its third gate, `triage-clarification-routing`, is **`required: false`** (`:222`) and so is not a
barrier — **which is the L-2 correction applied here too.** So the honest cell reads **"not
reachable at any slice of this spec"**, exactly like `PASSING`.

`PARTIALLY ENFORCED` is a real state of the world. It is simply not one this repository can reach by
building only what this spec builds — which is itself the §5.2 finding, one vocabulary level up.