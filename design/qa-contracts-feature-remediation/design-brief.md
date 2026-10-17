# Design Brief — QA contracts for feature-intake and design-remediation work items

**Brief id:** `QA-CONTRACTS-FEATURE-REMEDIATION`
**Disposition:** `DESIGN_REVISION_BLOCKED` — no gate set is proposed. §6 names exactly what is missing.
**Authoring HEAD:** `5afc23051216f521a5404fa1e2ef2f20cf4b7889`
**Branch:** `main` (worktree `/Users/alkebut/air/shipit-platform`, no detached worktree)
**Authored by:** `design-agent` / lane `design-QA-CONTRACTS-FEATURE-REMEDIATION`

---

## 0. Ownership

| Class | Paths |
|---|---|
| `OWNED_PATHS` | `design/qa-contracts-feature-remediation/**` |
| `READ_ONLY_PATHS` | `apps/**`, `packages/**`, `docs/**`, `docker/**`, `Makefile` |
| `PROHIBITED_PATHS` | `apps/**`, `packages/**`, `docker/**`, `.github/**`, `Makefile`, `docs/**`, `tooling/**` — read, never written |

No docker, compose, `psql`, or any mutating command was issued. No `git stash`, `git checkout .` or
`git add -A`. Tests were run directly with `dart test` against in-memory stores only.

---

## 1. What this brief was asked to produce, and what it produces instead

The mandate was: author two QA contracts, one for feature-intake and one for design-remediation
work items, with gates **derived from the structured results those agents actually emit**, not copied
from triage and not guessed from role names.

**This brief does not propose gates.** It establishes, with `file:line` for every claim, that:

1. both paths **do** dispatch and run (the mandate's premise is correct — and I can prove it, because
   the repository's own test for the opposite is **red at HEAD**, §3);
2. the run they perform is **a triage run** — `AgentRole.triageDefect`, `triageDefectInstruction`,
   triage-shaped output (§4);
3. the **only** consumer of that output **throws the output away** for both paths (§5), which is
   what makes the run's result shape not govern anything; and
4. authoring gates on that shape would be a **third** green lie, because **no evaluator exists for
   any gate in this repository** (§7) and because the transition the contract unblocks is a
   **Level 3 human decision** (§8).

Point 4 is the operative finding. The blocked result is the more useful outcome, and §6 names the
artifacts that would have to exist first.

---

## 2. The gate model, as implemented

### 2.1 `QAContractSpec` / `QAGateSpec` — the declaration shape

`packages/platform_contracts/lib/src/types/product_manifest.dart:129-141` — `QAContractSpec` carries
**only** `gates`. No `passCriteria`, no `workItemCategory`, no `contractId`.

`product_manifest.dart:145-165` — `QAGateSpec` carries `gateId`, `type`, `required`, `config`.
**It has no `evidenceTypes` field.** This is the discovery the prior lane recorded.

`packages/qa_orchestration/lib/src/product_qa_contract.dart:73` —
`declaredGateEvidenceTypesConfigKey = 'evidenceTypes'` is the only derivation available:
`_declaredEvidenceTypes` (`product_qa_contract.dart:168-192`) reads `config['evidenceTypes']`,
returns `const []` when the key is **absent** (`:169-171`), and **throws `FormatException`** when the
key is present but is not a `List<String>` (`:172-191`). Confirmed by the passing test at
`packages/qa_orchestration/test/product_qa_contract_test.dart` ("a malformed evidenceTypes is
refused, not silently dropped", group at `:560`, assertion names gate `g1`).

**Consequence for this brief:** any gate I proposed would have had to carry `evidenceTypes` inside
`config`, and a malformed value would abort the whole provision — not degrade one gate. The design
would have had to be exactly right on first write. That is a reason to be careful, not a reason to
stop.

### 2.2 `QAGateDefinition` — the contract shape

`packages/platform_contracts/lib/src/types/qa_contract.dart:66-102` — `gateId`, `type` (free string),
`required`, `config`, `evidenceTypes` (required, non-null), `workerCapabilities` (optional).

### 2.3 Pass criteria derivation

`product_qa_contract.dart:128-141` — `buildProductQAContract` derives, and does not choose:
`allRequiredGatesMustPass: true`; `optionalGateFailuresAllowed: <count of optional gates>`;
`waiverRequiresHumanDecision: true`. `product_qa_contract.dart:86-107` states this is a derivation,
so a per-product pass rule would be a decision nobody has made.

---

## 3. The observed result shape — step 1: the dispatch is real, and the repository's own test says so

### 3.1 Both producers park at `planned` and nothing else

**Feature intake** — `apps/server/lib/src/triage/work_entry.dart:389-391`:

```dart
if (kind == WorkEntryKind.featureIntake) {
  return _parkFeature(item, gate: gate);
}
```

The branch is first and unconditional. `_parkFeature` (`work_entry.dart:528-582`) calls
`_walkToPlanned` (`:542`), which stops at `planned` (`:607-618`). No job is enqueued. The recorded
reason is `EXTERNAL_WORK_ENTRY_CONSUMER_DEPENDENCY` (`work_entry.dart:64`, written at `:560`).

**Design remediation** — `apps/server/lib/src/triage/lane_e_design_remediation_work_item.dart:449-492`:
`_advanceToPlanned` walks `draft -> planning -> planned` and stops; `:478-489` explicitly does **not**
force progress if the item is not at `planned`. The recorded reason is
`EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY` (`lane_e_design_remediation_work_item.dart:22-23`, written
at `:557`).

### 3.2 `planned` is an entry state of the category-blind triage lane

`packages/scheduler/lib/src/triage_defect.dart:122-138`:

```dart
const JobDefinition triageDefectDefinition = JobDefinition(
  jobType: JobType.triageDefect,
  requiredRole: AgentRole.triageDefect,              // :124
  entryStates: {
    WorkItemState.designNotRequired,
    WorkItemState.designApproved,
    WorkItemState.reviewRejected,
    WorkItemState.planned,                            // :130  ← added by 863831a
  },
  entryProbeTargets: {
    WorkItemState.reviewRejected: WorkItemState.designNotRequired,
    WorkItemState.planned: WorkItemState.designNotRequired,   // :134
  },
```

`planned` entered that set in commit `863831a` ("Restore the route out of `planned`, which was a
dead end with no exit") to unstrand three items. `RunnableWorkEvaluator` rejects a state outside
`entryStates` *before* consulting any policy, so adding `planned` made **every** work item at
`planned` — including both of these producers' output — dispatchable, and `RunnableWorkEvaluator`
reads neither `item.category` nor `item.productId`
(`packages/qa_orchestration/lib/src/product_qa_contract.dart` is unrelated; the blindness is stated
at `apps/server/lib/src/services/control_plane_service.dart:1420-1423`).

### 3.3 The repository's own test for the opposite is red at HEAD — executed

`apps/server/lib/src/triage/work_entry_test.dart:854-855` names the assertion:

> "the parked feature is invisible to the category-blind scheduler, while a defect is not"

and `:876-880` asserts `RunnableWorkStatus.noAction` for the parked feature. Run at `5afc230`:

```
$ dart test lib/src/triage/work_entry_test.dart -n "category-blind scheduler" -r expanded
00:00 +0 -1: N-4 a feature is NEVER routed to the defect triage lane
  the parked feature is invisible to the category-blind scheduler, while a defect is not [E]
  Expected: RunnableWorkStatus:<RunnableWorkStatus.noAction>
    Actual: RunnableWorkStatus:<RunnableWorkStatus.runnable>
  package:control_plane_server/src/triage/work_entry.dart 877:7
```

**A parked feature is `runnable` for the triage lane.** F-45 in `docs/engineering/FOLLOW_UPS.md §11`
records this test as red at `09f949d` and states the blocker was "restored" by this session's work.
**That restoration did not happen.** The test is red at `5afc230`, the commit after `8b38a95`, and
`8b38a95` touched no file this test reads. Recorded as `CONTRADICTION` in §13.

**Therefore the mandate's premise is confirmed by execution:** feature-intake and design-remediation
items dispatch, run a real agent, and reach `agentExecuting -> agentCompleted`, where
`GuardConditions.qaContractExists()` refuses them (`work_item_transitions.dart:120-124`;
`guard_conditions.dart:247`, `context?['qaContractId'] != null`).

---

## 4. The observed result shape — step 2: the run that happens is a triage run

The dispatch is `JobType.triageDefect` with `requiredRole: AgentRole.triageDefect`
(`triage_defect.dart:123-124`). The instruction is built by `triageDefectInstruction`
(`triage_defect.dart:222`), called from `work_entry.dart:459-464` for the defect path and by the
scheduler for `planned`.

### 4.1 The requested shape, verbatim

`triage_defect.dart:249-264`, transcribed with the elisions made explicit:

```text
{ "classification": <one of implementation_defect | design_defect |
                       requirement_gap | environment_defect>,
  "status": "triaging",
  "confidence": <number 0.0-1.0>,
  "suspectedCategory": <free-form area>,
  "suspectedComponents": [<component1>, <component2>],
  "reproductionSupported": <boolean>,
  "evidenceUsed": [<evidenceId1>, <evidenceId2>],
  "clarificationRequired": [ {"question": ..., "reason": ...} ],
  "recommendedNextAction": <investigate | fix | clarify | escalate | close_duplicate>,
  "possibleDuplicateDefectId": <defectId if duplicate suspected, else omit>,
  "recommendedWorkItemCategory": <feature | bugfix | refactor | docs | chore |
                                 security | performance>,
  "summary": <2-3 sentence summary of findings> }
```

Fenced as `text`, not `json`: the source uses `a | b` union syntax (`triage_defect.dart:250, 260, 262`)
which is not valid JSON, and the values in angle brackets are the source's own placeholders. It is a
prompt block, not a schema, and it is quoted here rather than restated — the drift guard for it is
`test/lane_m_triage_prompt_contract_test.dart`, per `triage_defect.dart:218-221`.

### 4.2 The accepted shape, verbatim, from the only parser

`apps/server/lib/src/triage/triage_processor.dart:184-270` — `_parseTriageResult`:

| Key | Line | Treatment |
|---|---|---|
| `classification` | `:200-204` | **required**; `DefectClassification.fromWire`, throws `FormatException` → `null` result |
| `status` | `:206-210` | **required**; `DefectStatus.fromWire` |
| `confidence` | `:211-214` | **required**; any `num`; no range enforcement (ADR 0020) |
| `suspectedCategory` | `:216-220` | **required** |
| `suspectedComponents` | `:221-223` | optional, defaults `[]` |
| `reproductionSupported` | `:225-226` | optional, defaults `false` |
| `evidenceUsed` | `:227-228` | optional, defaults `[]` |
| `clarificationRequired` | `:230-237` | optional |
| `recommendedNextAction` | `:241-242` | optional, defaults `'investigate'` |
| `possibleDuplicateDefectId` | `:254` | optional |
| `recommendedWorkItemCategory` | `:256` | optional |
| `summary` | `:257` | optional, defaults `'Triage completed'` |

The four required keys are **exactly** the four `requiredFields` of
`structuredClassificationAdmitted` (`lane_g_triage_qa_contract.dart:179-184`). That agreement is the
gate's whole justification and it holds.

### 4.3 What a feature item's instruction actually contains

`triage_defect.dart:223-231` reads `metadata['defectId']`, `['defectTitle']`, `['defectDescription']`,
`['defectSeverity']`, `['defectExpectedBehavior']`, `['defectReproductionSteps']`, `['defectEvidence']`
— every one with a fallback. For a `WI-feature-*` item **none of those metadata keys exists**
(`control_plane_service.dart:930-950` writes `featureRef` and QA-contract metadata only), so the
prompt degrades to:

- `ID:` the work-item id;
- `Title:` the feature title;
- `Description:` the feature description;
- `Severity:` `medium` (the fallback at `:228`);
- `Expected Behavior` / `Reproduction Steps:` absent (`'Not specified'` at `:240-241`);
- **`EVIDENCE: []`** (the fallback at `:231`).

`"Perform AI triage of defect "…"` (`triage_defect.dart:233`) is then asking a triage agent to
classify a feature request as a defect, with an empty evidence list, while
`triage_defect.dart:274` instructs it to `"reference evidence IDs from the provided evidence list"`
— a list that is empty.

**This is the shape, and it is not the shape the mandate hoped for.** It is a real shape with real
keys, and it is the wrong shape for both paths. §5 says why that is disqualifying.

### 4.4 What does *not* exist in the repository — the negative evidence

Searched and confirmed absent:

- **No committed `agent_result` fixture for a non-triage lane.** The only `structuredResult` literal
  in any test fixture is `packages/store_contract_tests/lib/src/fixtures.dart:409` —
  `{'route': '/landing'}`, `role: AgentRole.implementer`. That is a store round-trip fixture, not an
  observation of a lane's output.
- **No `structuredResultJson` literal in any `.sql` file** (migrations declare the column
  `text NOT NULL` and carry no seed value).
- **No `FeatureIntakeResult` type, no `feature_triage` schema.** Grep for
  `FeatureIntakeResult|feature_triage|structuredResult.*feature` over `**/*.dart` and `**/*.md`
  returns nothing.
- **No `AgentRole` for either path.** `packages/platform_contracts/lib/src/enums/agent_role.dart:1-13`
  has twelve roles; there is no feature-intake role and no design-remediation role. Both producers
  stamp `WorkItemCategory.feature` (`control_plane_service.dart:933`;
  `lane_e_design_remediation_work_item.dart:288`).
- **No `JobDefinition` for either path.** The seven wired definitions are
  `onboardProductDefinition`, `implementFeatureDefinition`, `defaultImplementFeatureDefinition`,
  `designRevisionDefinition`, `designReviewDefinition`, `engineeringReviewDefinition`,
  `triageDefectDefinition`.

**`structuredResult` is a free-form `Map<String, dynamic>`** (`agent_result.dart:43`). Its only
production construction sites are `execution_coordinator.dart:1437` (`const {}`) and the opencode
adapter `packages/agent_runtime/lib/src/adapters/opencode/opencode_session.dart:927` (whatever the
model returned). Nothing in the platform constrains it for a non-triage role.

---

## 5. The observed result shape — step 3: the result is discarded, which is why it governs nothing

`apps/server/lib/src/triage/triage_processor.dart` — `processCompletedTriageJob`:

1. `:48-49` — `if (job.jobType != JobType.triageDefect) return null;`. A feature item's job **is**
   `triageDefect`, so it proceeds.
2. `:102-103` — `_parseTriageResult(job, execution, result)`; `:105` — `saveTriageResult`.
3. `triage_processor.dart:272-276` — `_extractDefectId`:
   ```dart
   if (workItemId.startsWith('defect-')) return workItemId.substring(7);
   return workItemId;
   ```
   `WI-feature-1791823723502264` and `design-remediation-DEF-…` do **not** start with `defect-`, so
   `TriageResult.defectId` is set to the **work-item id**.
4. `:120-124` — `await defectStore.readDefect(triageResult.defectId)` throws
   `DefectNotFoundException`.
5. `:125-132` — the catch logs `triage.processed.defect_missing` and **`return triageResult;`**.

The result is persisted, then abandoned. No defect, no classification, no remediation request, no
clarification. The job sits `succeeded`.

The repository already names this exact outcome, in the code that the `planned` entry state bypassed.
`work_entry.dart:385-388`:

> "This branch is first and unconditional, so a feature cannot acquire a `triage_defect` job even if
> every later check passes. `TriageResult` would parse, `readDefect` would raise, the processor
> would return early and the job would sit `succeeded` with the outcome discarded: **a healthy
> looking job and no work done**."

**`863831a` made that sentence true for both paths.** The trigger's protection (`:389-391`) is
bypassed not by changing the trigger but by the scheduler reading `entryStates` directly.

**A gate whose document is parsed, persisted and then explicitly returned-without-use by its only
consumer is not a gate.** It would be a QA contract asserting properties of a record that the
platform's own code classifies as an artifact of a mis-routed item. That is the fabrication the
mandate told me to avoid, and it is larger than the one the mandate named.

---

## 6. BLOCKER — what is missing, named exactly

To author a real gate for either path, four artifacts must exist. None does.

| # | Missing artifact | Where it would live | Why no gate is authorable without it |
|---|---|---|---|
| M1 | A `JobDefinition` for feature intake, with an `entryStates` set that is **not** `{planned}` | `packages/scheduler/lib/src/` | Until it exists, the only run is `triageDefectDefinition`. A contract for feature intake governs a triage run it has no business governing. |
| M2 | A `JobDefinition` for design remediation, likewise | `packages/scheduler/lib/src/` | Same. Note `designRevisionDefinition` (`scheduler.dart:3262`) dispatches from `{designRequired, designRejected}` — not `planned` — so it cannot serve either. |
| M3 | An `AgentRole` for each path | `platform_contracts/lib/src/enums/agent_role.dart:1-13` | A contract's `metadata.requiredRole` is how a reader tells whose output it governs (`lane_g_triage_qa_contract.dart:151`). There is nothing truthful to put. |
| M4 | A result type + a parser + an instruction, per path — the analogue of `TriageResult` / `TriageProcessor._parseTriageResult` / `triageDefectInstruction` | `platform_contracts` + `apps/server/lib/src/` | **This is the load-bearing one.** A gate's `requiredFields` are justified by *a consumer that reads them* (§4.2: the triage gate's justification is `triage_processor.dart:200-220`). Without a consumer there is no justification, and `config.requiredFields` would be invented. |

**Supporting absence (not blocking on its own, but it removes the usual excuse):** no gate evaluator
exists for **any** gate in this repository. See §7.

### 6.1 What I could have proposed anyway, and why I did not

I could have written `feature-structured-result-admitted` with
`requiredFields: [classification, status, confidence, suspectedCategory]` and
`config: {sourceColumn: 'agent_result.structuredResultJson', classificationEnum: 'DefectClassification', statusEnum: 'DefectStatus'}`
— every key real, every enum real, zero invention. It would have been a faithful transcription.

It would also have been a **QA contract for a feature request asserting that a feature request was
correctly classified as a defect**, with the classification recorded against an id that is not a
defect and then discarded. A reviewer asking "what does this gate protect?" would get no answer that
isn't "it protects a document `triage_processor.dart:131` throws away." **I am not proposing it.**

---

## 7. The green-lie check — no gate in this repository is evaluated by anything

The mandate asked me to check whether the triage gates are enforced. They are not, and neither is
anything else.

- `packages/qa_orchestration/lib/src/gates/gate_registry.dart:19-23` registers **four** evaluators:
  `StaticAnalysisGate`, `TestCoverageGate`, `SecurityScanGate`, `PerformanceGate`. All are
  implementation gates (`gates/predefined/*.dart`).
- The three triage types — `triage-classification-structure`, `triage-evidence-grounding`,
  `triage-clarification-routing` — appear **nowhere except** their own declaration
  (`lane_g_triage_qa_contract.dart:174, 201, 221`), tests asserting their presence, and prose.
- `QAOrchestration.evaluate` returns `QAGateStatus.notExecuted` for an unknown type
  (`qa_orchestration.dart:19-32`); `isGateSatisfied(notExecuted)` is `false`
  (`qa_orchestration.dart:56-61`).
- **`QAOrchestration` itself is called from exactly one place: its own test file.** Grep across
  `apps/`, `packages/` for `QAOrchestration(`, `.evaluate(`, `isOverallPass`, `isGateSatisfied`,
  `requiresFormalDetermination` returns hits only in `packages/qa_orchestration/test/`.
- `GuardConditions.allRequiredGatesPassed()` exists (`guard_conditions.dart:32-33`) and is used on
  `qaInProgress -> qaPassed` (`work_item_transitions.dart:661`). Its body reads
  `context?['gateResults']` (`guard_conditions.dart:267`) and fails when absent (`:268-270`).
  **No production code writes `context['gateResults']`** — grep across `apps/**/lib` and
  `packages/*/lib` returns the three hits inside that guard's own file.
- Both existing builders already say so in writing:
  `lane_g_triage_qa_contract.dart:156` and `product_qa_contract.dart:156` both write
  `'evaluatorRuntime': 'absent'`.

**So: a `QAContract` today is a durable, readable, auditable *declaration*, and nothing more.** Its
gates are not enforced at `agentExecuting -> agentCompleted`, at `qaInProgress -> qaPassed`, or
anywhere else. Authoring two more gate sets adds two more unread declarations to `qa_contract`.

---

## 8. The escalation — why this cannot be a design decision, and must not be made here

`8b38a95` already made the transition *passable*: `GuardConditions.qaContractExists()` is a null-check
(`guard_conditions.dart:247`), and `ProductQAContractProvisioner` writes a row for **any** non-empty
declaration (`product_qa_contract.dart:117-127`, `:266-292`). Gate **content** is irrelevant to the
guard.

So for a product whose manifest declares at least one gate, the walk at HEAD is already legal:

```
planned  ──(entryProbeTargets, triage_defect.dart:134)──►  designNotRequired
designNotRequired ──(work_item_transitions.dart:116-119)──►  agentExecuting
agentExecuting ──(work_item_transitions.dart:120-124, qaContractExists ✓)──►  agentCompleted
agentCompleted ──(work_item_transitions.dart:306-308, actorAllowed[orchestrator] only)──►  implementationReady
```

and `implementationReady` is `implementFeatureDefinition.entryStates`
(`packages/scheduler/lib/src/implement_feature.dart:114`, `requiredRole: AgentRole.implementer`),
with `implementationReady -> agentExecuting` (`work_item_transitions.dart:112-115`).

**The consequence:** a QA contract for feature intake does not merely let a feature item record a
result. It lets a **human's raw feature request** — `title` + `description`, with
`Expected Behavior: Not specified` and `Reproduction Steps: Not specified`
(`triage_defect.dart:240-241`) — reach an **implementer** that will write code, with no design
review and no engineering review on the path.

Whether that is acceptable is a **product/governance decision**, not a QA-contract design decision.
Per `DESIGN_GOVERNANCE.md`'s risk table it is Level 3 (Major Workflow change affecting user mental
models of the platform's own intake), and per `AGENTS.md` human intervention is reserved for
consequential workflow decisions. **I am not making it, and this brief does not assume it.**

Escalated as **HD-1** in §12.

---

## 9. Which triage gate is genuinely reusable? Plainly: none

The mandate asked for this stated directly. Three triage gates; none transfers:

| Gate | Why it is not reusable |
|---|---|
| `triage-classification-admitted` (`lane_g_triage_qa_contract.dart:172`) | Its justification is `TriageProcessor._parseTriageResult` (`triage_processor.dart:200-220`) **requiring** those four keys for a real `Defect` row. On these paths the same parser runs and then `readDefect` raises (`triage_processor.dart:120-124`). The gate would govern a document whose consumer abandoned it. The shape transfers; the justification does not. |
| `triage-evidence-grounded` (`lane_g_triage_qa_contract.dart:199`) | Grounded in `DefectEvidence` rows in `defect_evidence` belonging to a reported defect (`config.sourceColumn: 'defect_evidence.evidenceId'`). A `WI-feature-*` item has no defect, so there is nothing to ground against. Its own doc already records that it is **not enforced anywhere** (`:84-90`). Reusing it on a feature item is the exact fabrication the mandate named. |
| `triage-clarification-routing` (`lane_g_triage_qa_contract.dart:219`) | Grounded in `DefectClarification` rows in `defect_clarification` raised for a defect. Same absence. It is also the one triage gate that is `required: false`, so it neither blocks nor would it do anything. |

And `lane_g_triage_qa_contract.dart:151` stamps `requiredRole: AgentRole.triageDefect` — a fact about
the producer, not a parameter. Neither path has a role (§6, M3).

The repository already refuses this reuse in writing:
`product_qa_contract_test.dart` — "NO triage gate, role or defect metadata is ever copied in"
(`:588-616`), asserting `triage-classification-structure`, `triage-evidence-grounding`,
`defect_evidence_reference`, `triageDefect` and `qaContractDefectIdMetadataKey` are all absent from a
product-declared contract. `lane_e_design_remediation_work_item_test.dart:322-338` asserts the same
for the remediation lane. **Both suites pass at `5afc230`** (18 and 11 tests, respectively, executed).

---

## 10. Work-item-scoped ids and the `qa-product-` prefix — sufficient?

**Yes for identity. No for anything else.** Stated precisely:

`product_qa_contract.dart:50-51` — `productQAContractIdForWorkItem(workItemId) =>
'qa-product-$workItemId'`.

**Sufficient, and already proven:**

- **Disjoint from the triage namespace.** `triageQAContractIdForDefect` yields `qa-triage-$defectId`
  (`lane_g_triage_qa_contract.dart:48`). The prefixes cannot collide.
- **Safe against the parent-repointing defect.** `design-remediation-DEF-X` and `defect-DEF-X` name
  one defect (`product_qa_contract.dart:40-49`). A defect-scoped id would have overwritten the
  triage parent's row — `saveQAContract` is `ON CONFLICT ("contractId") DO UPDATE` — and repointed
  its `metadata.workItemId`. Proven by
  `product_qa_contract_test.dart` ("provisioning for a remediation item leaves the triage contract for
  the SAME defect byte-identical") and `lane_e_design_remediation_work_item_test.dart:234-296`,
  both green.
- **Idempotent.** A pure function of the work-item id; replays converge on one row
  (`product_qa_contract.dart:214-220`; `product_qa_contract_test.dart` "three provisionings, one work
  item, one row", green).
- **Unambiguous for these two paths.** `WI-feature-<micros>` (`control_plane_service.dart:916`) and
  `design-remediation-<defectId>` (`lane_e_design_remediation_work_item.dart:69-70`) are distinct, so
  each addresses its own row. A `WI-feature-` id is generated per call and never re-read
  (`control_plane_service.dart:916`; F-43), so replay convergence is per-item only — which is
  sufficient for identity and is the reason no backfill hook exists for that path.

**Not sufficient, and worth stating so the prefix is not over-read:** the id namespace says nothing
about **what** the contract asserts. `qa-product-WI-feature-…` currently provisions a row containing
whatever the product's manifest happened to declare, whether or not that declaration was written with
these paths in mind. The prefix solves collision. It cannot solve content — which is what §6 says is
missing.

---

## 11. Pass criteria — stated conditionally, for when a shape exists

Recorded so that whoever unblocks this does not have to re-derive them, and so no lane hard-codes a
number that would then be wrong.

If a feature-intake and a design-remediation result shape ever exist (M1–M4), the pass criteria are
**not free choices.** `buildProductQAContract` derives them (`product_qa_contract.dart:128-141`), so
**neither contract declares its own.** They are:

```
allRequiredGatesMustPass:  true
optionalGateFailuresAllowed: <count of gates declared required: false>
waiverRequiresHumanDecision:  true
```

**On optionality — the triage precedent should NOT be copied.** The triage contract sets
`optionalGateFailuresAllowed: 1` (`lane_g_triage_qa_contract.dart:142-146`), and that number is
**correct there for a specific reason stated at `:139-141`**: the contract has exactly one optional
gate (`clarificationRouted`, `:219`), and the value is the count of optional gates — i.e. "an optional
gate may be unmet without blocking", which is the same as requiring it never to fail.

The rule to carry forward is the **derivation**, not the numeral. Any contract here must have
`optionalGateFailuresAllowed` equal its own optional-gate count or `isOverallPass`
(`qa_orchestration.dart:102-117`) stops meaning what it says. And the triage contract's own reasoning
at `:91-94` is the correct test for making any gate optional:

> "a required gate that is expected to fail is a gate that trains everyone to waive it."

For a run whose result is discarded (§5), *every* gate would be expected to fail — which by that
same test means the contract should declare **no optional gates at all** and should not exist. This is
the strongest argument in the brief and it is not mine: it is the triage contract's own criterion
applied to the situation the triage contract was written to avoid.

---

## 12. Human decision required — HD-1 (Level 3)

**Not decided here. Escalated to `orchestrator-main` for a `HUMAN_DECISION` object.**

> **HD-1 — Should a feature-intake or design-remediation work item be permitted to complete an agent
> execution at all?**
>
> At HEAD, `planned` is in `triageDefectDefinition.entryStates` (`triage_defect.dart:130`), so both
> producers' items are dispatched, hopped to `designNotRequired`, executed by
> `AgentRole.triageDefect` under `triageDefectInstruction`, and their output is discarded at
> `triage_processor.dart:120-132`. Once a QA contract exists (`8b38a95`), the completion transition
> **succeeds** and the item walks to `implementationReady` (§8), where `AgentRole.implementer` is
> dispatched on a human's raw feature request with no design review and no engineering review.
>
> Three options, none of which this brief picks:
> **(a)** Narrow `triageDefectDefinition.entryStates` so `planned` dispatches only items carrying a
> defect — restoring the invariant `work_entry.dart:380-382` states, and re-closing the `planned`
> dead end for these three items deliberately.
> **(b)** Build the missing runtimes (M1–M4) and give each path its own `JobDefinition`, role,
> instruction, result type and consumer, so the dispatch is deliberate rather than accidental.
> **(c)** Accept the walk and govern it — which is what the original mandate assumed was happening,
> and which would require the gates this brief declines to invent, plus a named owner for the
> implementer dispatch in §8.
>
> Until HD-1 is answered, no QA contract should be authored for these two paths, because **which
> contract is correct depends entirely on the answer** and (c) is not a state this platform should
> reach by accident.

---

## 13. Risks

| # | Risk | Likelihood | Severity | Mitigation / status |
|---|---|---|---|---|
| R1 | The red test at `work_entry_test.dart:877` is unnoticed, because nothing runs that suite in CI (F-15) | CERTAIN | HIGH | **Live now.** It is the repository's own proof of §3.3 and it will stay red until HD-1 is answered. |
| R2 | A gate set is authored anyway, "to close the ticket", against the triage shape | MEDIUM | HIGH | This brief is the obstacle. §6.1 states why the transcription, though faithful, is false, and `product_qa_contract_test.dart:588-616` will fail on the reuse itself. |
| R3 | Authoring contracts completes the walk and dispatches an implementer on a raw feature request (§8) | HIGH, if a contract is authored | CRITICAL | HD-1. This is the risk that makes authoring-before-deciding unsafe rather than merely premature. |
| R4 | The discarded result (`triage_processor.dart:131`) is mistaken for a triage outcome by a reader of `triage_result` | MEDIUM | MEDIUM | Pre-existing. Recorded here because §5 is what makes it visible. No test asserts a `triage_result` row cannot name a non-defect id. |
| R5 | Gates are treated as enforced because a `qa_contract` row exists | HIGH | MEDIUM | §7. Both existing builders write `'evaluatorRuntime': 'absent'` (`lane_g_triage_qa_contract.dart:156`, `product_qa_contract.dart:156`); any new one must too. |
| R6 | The `qa-product-` prefix is read as meaning the content is right | MEDIUM | LOW | §10. Id namespace and content are independent; the doc comment at `product_qa_contract.dart:22-49` already earns its keep. |
| R7 | `config['evidenceTypes']` is malformed and aborts provisioning | LOW | MEDIUM | Already fail-closed by `_declaredEvidenceTypes` (`product_qa_contract.dart:172-191`), which is correct. Not a risk to this design; recorded because any future gate must respect it. |

---

## 14. Non-goals

- **Not** a change to `GuardConditions.qaContractExists()` — untouched, and it should stay untouched.
- **Not** a change to `work_item_transitions.dart` — untouched, per `8b38a95`'s discipline.
- **Not** a QA-contract evaluator runtime. §7 names the absence; building it is a separate, large,
  independently-reviewable change.
- **Not** an implementation of M1–M4. Those are named so the next lane can scope them.
- **Not** a decision on HD-1.
- **Not** a repair for F-43 (`WI-feature-*` has no replay hook) — a different change, deliberately not
  bundled, per `FOLLOW_UPS.md §11`.
- **Not** an edit to `docs/engineering/FOLLOW_UPS.md` — owned by `orchestrator-main`.

---

## 15. Implementation sequence — for the lane that picks this up

Ordered by dependency, and **none of step 1 is a gate**.

1. **Answer HD-1.** Blocking. Options (a)/(b)/(c) at §12. Nothing below is well-defined without it,
   because the correct contract depends on the answer.
2. **Land R1's visibility as a decision, not a code change.** Whichever option is chosen, record in
   `FOLLOW_UPS.md §11` whether `work_entry_test.dart:854` is expected to be red or green at HEAD.
   It cannot stay ambiguous — an agent can read either answer from the repo.
3. **If (a):** narrow `triageDefectDefinition.entryStates`, with `test/triage_entry_state_drift_guard_test.dart`
   and the two exact-set pins updated *narrowing the lane's blast radius deliberately* — the inverse
   of `863831a`'s widening, and it re-strands the three `planned` items by design. Say so in the same
   commit.
4. **If (b):** M1/M2 `JobDefinition`s, M3 `AgentRole`s, then M4 instruction + result type + parser +
   consumer, in that order — the consumer last, because it is what makes the earlier ones
   verifiable. Only after a consumer exists do the result shapes exist; only after the shapes exist
   can gates be authored against them.
5. **Then, and only then, author the two contracts** — one `QAContractSpec` per product per path,
   each gate's `requiredFields` justified by a named line in the new parser, each `evidenceTypes`
   carried in `config['evidenceTypes']` as `List<String>` (else provisioning throws), each with
   `optionalGateFailuresAllowed` equal to its own optional-gate count (§11), and `'evaluatorRuntime':
   'absent'` in metadata until §7's runtime exists.
6. **Separately, and not bundled:** decide whether the evaluator runtime (§7) is in scope. Until it
   is, every contract written is a declaration, and every brief that authors one must say so in
   `metadata` and in its own `risk_assessment`.

---

## 16. Traceability

### 16.1 Requirements covered

| Requirement | Where |
|---|---|
| Observed result shape per role, with `file:line` or fixture evidence for every claim | §4, §5, §4.4 (including the negative evidence) |
| Which triage gate is genuinely reusable and why | §9 — plainly, none, with per-gate reasoning |
| Pass criteria per contract; whether any gate is optional | §11 — derivation recorded, optionality argued against the triage contract's own criterion |
| How a gate is evaluated — name the code, or state the evaluator does not exist | §7 — it does not exist, for **any** gate |
| Whether work-item-scoped ids and the `qa-product-` prefix are sufficient | §10 — yes for identity, no for content, with the proofs |
| Risks | §13 |
| Explicit non-goals | §14 |
| Implementation sequence | §15 |
| Gates expressible in `QAContractSpec` (no `evidenceTypes`; derived from `config`, malformed throws) | §2.1 |

### 16.2 Requirements gaps

| Gap | Why it is a gap, not an omission |
|---|---|
| **Proposed gates per contract** (`gateId`, `type`, `required`, `evidenceTypes`, `config` keys justified by the observed shape) | No consumer of either path's result exists (§6, M4), and the only run that happens has its output discarded (§5). Any `config.requiredFields` would be justified by nothing. This is the `DESIGN_BLOCKED` outcome the mandate authorised. |
| **Pass criteria per contract, as concrete numbers** | Derived from gate count, which does not exist. §11 records the derivation and the optionality rule so the numbers are a derivation once the gates are. |
| **Evaluator for the gates** | Does not exist for any gate (§7). Would need building; out of scope for a design brief and separately reviewable. |

### 16.3 Not addressed because it is out of scope

- The red test's own cause. §3.3 and §12 locate it; HD-1 decides it.
- F-42 (three items need a human operator transition) — unchanged by this brief; `8b38a95`'s scope.

---

## 17. Durable discoveries

Classified per `docs/engineering/LEARNING_POLICY.md`. Reported, not persisted — `docs/**` is
`PROHIBITED_PATHS` for this lane and the Manager owns `FOLLOW_UPS.md`.

- **`CONTRADICTION`** (highest priority; touches governance, so it is escalated, not reconciled
  here). `docs/engineering/FOLLOW_UPS.md §11` **F-45** states the blocker was "visible as a red test
  at HEAD, before this session's fix" and that this session restored the behaviour. The test
  `apps/server/lib/src/triage/work_entry_test.dart:854` is **red at `5afc230`** with
  `Expected: noAction / Actual: runnable`, executed above. `8b38a95` touched no file that test reads.
  F-45's restoration claim is not supported.
- **`PROJECT_FACT`**. `triageDefectDefinition.entryStates` contains `planned`
  (`triage_defect.dart:130`) with `entryProbeTargets[planned] = designNotRequired` (`:134`), added by
  `863831a`. Consequence: **every** work item at `planned` is dispatched on the triage lane,
  regardless of producer, because `RunnableWorkEvaluator` reads neither `category` nor `productId`.
  This defeats the protection at `work_entry.dart:389-391` without changing it.
- **`PROJECT_FACT`**. For a `WI-feature-*` or `design-remediation-*` work item, the triage run's
  outcome is persisted to `triage_result` keyed on the **work-item id** and then abandoned
  (`triage_processor.dart:272-276` → `:120-132`), while the job sits `succeeded`. The prediction at
  `work_entry.dart:385-388` is now realised.
- **`PROJECT_FACT`**. **No QA gate in this repository is evaluated by any production code.**
  `GateRegistry` holds four implementation evaluators (`gate_registry.dart:19-23`);
  `QAOrchestration` is called only from its own test; `GuardConditions.allRequiredGatesPassed()`
  reads `context['gateResults']` (`guard_conditions.dart:267`) which no production code writes. A
  `QAContract` is a durable declaration, not an enforced one.
- **`PROJECT_FACT`**. `agent_result.structuredResultJson` has **no committed fixture** for any lane
  other than a store round-trip (`packages/store_contract_tests/lib/src/fixtures.dart:409`,
  `{'route': '/landing'}`, `AgentRole.implementer`). No `.sql` file carries a value. Any claim about
  a lane's structured-result shape must cite the instruction that requests it and the parser that
  consumes it — there is nothing else to cite.
- **`DESIGN_DISCOVERY` / escalatable**. Authoring a QA contract for feature intake does not merely
  unblock a recorded result; it completes a walk to `implementationReady` and dispatches
  `AgentRole.implementer` on a human's raw feature request. That is a Level 3 governance decision
  and it gates all gate-authoring work (HD-1).
- **`WORKFLOW_IMPROVEMENT`** (independent review, not auto-persisted). `F-45`'s lesson generalises:
  a red test naming a blocker is only protection if something runs it, and F-15 records that nothing
  does. The proposal for `design/capability-parity/` — executable capability declaration — is the
  mechanism that would have caught this; it is unbuilt.

---

## 18. Disposition

`DESIGN_REVISION_BLOCKED`.

Not blocked on effort or on ambiguity. Blocked on two facts established by reading and by execution:
**the only run either path performs has its result discarded by its sole consumer** (§5), and
**no gate in this repository is evaluated by anything** (§7). A gate set authored today would be an
unenforced declaration about an abandoned record — and completing the transition it unblocks reaches
an implementer on an undesigned human request (§8), which is HD-1 and not mine to decide.

The `8b38a95` work stands and is sound: the provisioner is correct, the id scoping is correct and
proven, the three named refusals are correct, and both of its suites are green at `5afc230`
(18 + 11 tests, executed above). **What is missing is the contract content, and the brief's finding
is that the content cannot be authored until the run it would describe is decided to exist.**

Handed to an independent `design-reviewer`. This lane does not approve its own work.
