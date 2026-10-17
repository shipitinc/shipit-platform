# Evaluator Spec — the QA gate evaluator

**Parent:** [`design-revision.md`](./design-revision.md) §5 — deliverable 1
**Authoring HEAD:** `e3634a0cbbdf656267b22908284dd1ae8b655085`
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

**There is no caller.** `qaInProgress` is in no `JobDefinition.entryStates`, so no scheduler
dispatches from it; and `QAOrchestration` — the class an `ActorType.qaExecutor` would be embodied
by — is constructed in exactly one place in the repository: its own test file
(`packages/qa_orchestration/test/qa_orchestration_test.dart`).

So the walk today is:

```
agentCompleted -> reviewInProgress -> reviewApproved -> qaInProgress -> STUCK
                                                                       ^
                              qaPassed  requires allRequiredGatesPassed, which always fails
                              qaFailed  requires a qaExecutor that nothing dispatches
```

**This is a live dead end on the main implementation lane**, reported here because the evaluator
is what unblocks it, and recorded in `design-revision.md` §2.1 for the Manager. It is not designed
in this brief — `FOLLOW_UPS.md` is the Manager's and `qaInProgress` is not this brief's subject.

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
`structuredClassificationAdmitted`'s (`lane_g_triage_qa_contract.dart:177-187`):

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
| V6 | The drain is per-item isolated: one item whose contract id is unreadable does not lose the lane's whole tick | the throw escapes — the exact failure `implementation_inflow.dart:1543-1578` was written about |

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

### 5.2 What slice 2a must do, before any wiring

1. **Replace `_validateEvidence`** with validation that reads `QAEvidence.content` against the
   gate's declared `config` thresholds. `issues` non-empty, `vulnerabilities` empty,
   `threshold` actually compared against a real coverage value. Whether each of those is *achievable*
   is a `qa_architect` question — what is **not** negotiable here is that the predicate stops
   being a constant.
2. **Or** de-register all four until they are real. This is the cheaper and more honest option and
   it is **recommended**: a registry that lists four evaluators which pass unconditionally
   (`design-revision.md` R10) teaches every future reader that `gateRegistry` means something it
   does not.
3. Either way, add a non-vacuity test that **fails** when the predicate is the constant — the same
   shape as V1-V6, so a future refactor cannot quietly restore it.

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
`lane_g_triage_qa_contract.dart:179-184` are exactly those four keys.** The gate records as an
obligation what is currently an accident of a `catch` block — which is what
`lane_g_triage_qa_contract.dart:78-83` says it is for.

Two **non-negotiable** properties:

- **It is a structural gate, not a defect gate.** It must NOT assert anything about defect
  existence, evidence ownership, or classification *correctness*. It answers "is this a
  well-formed triage classification", nothing more. Anything richer belongs in
  `triage-evidence-grounding` / `triage-clarification-routing`, neither of which has an evaluator
  and neither of which is in scope here.
- **It must be honest about the two triage gates that have no evaluator.** After slice 2, the
  triage contract's *first* gate is `PASSING` when the shape is right and the other two remain
  `notExecuted`. Because `allRequiredGatesMustPass: true` and both are `required: true`
  (`:175`, `:201`), `allRequiredGatesPassed` **still fails** — which is correct. Recording this
  matters: a reader who sees one triage gate enforced must not infer the contract is satisfied.
  `lane_g_triage_qa_contract.dart:107-118` already states the honest position; keep
  `'evaluatorRuntime': 'absent'` (`:156`) until *all three* have evaluators, and record the
  partial state in a way that cannot be read as full enforcement.

---

## 6. State vocabulary

| Word | Meaning | Applies to, at `e3634a0` |
|---|---|---|
| `ABSENT` | no declaration exists | the two contracts this revision declines (`design-revision.md` §3) |
| `DECLARED` | a `QAContract` row exists; its gates are readable and auditable; **nothing evaluates them** | `qa-triage-*`; every `qa-product-*` |
| `PARTIALLY ENFORCED` | some gate types have evaluators and pass/fail honestly; the contract's `allRequiredGatesMustPass` still cannot be satisfied because other required gates are `notExecuted` | reachable only after slice 2.3 |
| `PASSING` | every required gate evaluated and satisfied by a real evaluator | **nothing in this repository, at any slice of this spec** |

The single sentence this spec exists to make true: **`DECLARED` is not `PASSING`, and the word on
the row must never imply otherwise.** Both existing builders already write
`'evaluatorRuntime': 'absent'` (`lane_g_triage_qa_contract.dart:156`,
`product_qa_contract.dart:156`); that key must survive every slice, and must be **removed only**
when the contract's every required gate type has a real evaluator.