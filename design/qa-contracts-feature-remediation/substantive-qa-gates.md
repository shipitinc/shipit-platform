# Substantive QA Quality Gates — the feature lane and the remediation lane

**Artifact type:** Design Revision, additive companion to
[`design-revision.md`](./design-revision.md) (revision 2, Gate-D4 APPROVED)
**Authoring lane:** `design-SUBSTANTIVE-QA-GATES` (design-agent)
**Base SHA:** `9300eea9259b1bc6f0ecaeaae5d45832652bf549` — verified `git rev-parse --short HEAD` ==
`9300eea` before the first edit; tracked tree clean (`git status --porcelain --untracked-files=no`
empty, `git diff --quiet HEAD` returned 0).
**Governing human decision:** `92d567e3-da03-4c43-99f4-e3726472f0ab` — `PRODUCT`,
`RESOLVED`, `DESIGN_SUBSTANTIVE_GATES_FIRST`, operator, 2026-10-18. Its
`scope_note` dispatches this as an ordinary design lane with independent review and states
*"No further human gate is required to run that design."* **This artifact therefore raises no
`HUMAN_DECISION_REQUIRED`, and §10 says plainly which questions it declines to decide rather than
answering them by guess.**

> **THE ONE SENTENCE THIS ARTIFACT EXISTS TO MAKE TRUE:** *`qaPassed` on a feature item means the
> platform itself observed a commit at a recorded revision and ran declared validation against that
> revision; on a remediation item it means the cited defect and every cited evidence id really exist
> and belong to each other.* Neither sentence can be satisfied by a well-formed payload.

---

## 0. Ownership, and what this artifact does not do

| | |
|---|---|
| `OWNED_PATHS` | `design/qa-contracts-feature-remediation/substantive-qa-gates.md` (this file, NEW); `design/qa-contracts-feature-remediation/design-revision-metadata.yaml` (**additive revision entry only**, §11) |
| `READ_ONLY_PATHS` | `apps/**`, `packages/**`, `docs/**`, `docker/**`, `.decisions/**`, `.github/**`, `Makefile`, and the sibling artifacts in this directory |
| `PROHIBITED_PATHS` | everything else. In particular: `docs/engineering/FOLLOW_UPS.md` (Manager-owned — **read, never written**), all production source, all test source, the shipped product manifest, and `evaluator-spec.md` / `design-review-gate.md` / `design-revision.md` (approved, independently reviewed — **read and cited, not rewritten**) |

**No production code was written. No docker, no docker compose, no psql.** Every claim below is
derived by reading the tree, per `AGENTS.md`'s shared-Docker-state rule for a lane without
deployment authority. `dart analyze` (CLI) was not run because this lane changed no Dart file —
`packages/**` is `READ_ONLY_PATHS` and nothing under it was touched, so there is nothing for the
analyzer to be evidence about.

**What this artifact changes about the approved design: nothing.** It is subordinate to
`evaluator-spec.md`, which owns `context['gateResults']`, `context['qaContract']`, the
`QAGateResult` shape, the `qaInProgress -> qaPassed` guard and the 3a/3b/3c ordering. Where this
artifact and `evaluator-spec.md` differ, `evaluator-spec.md` wins and the difference is recorded in
§1.2 rather than resolved here.

---

## 1. Two premise corrections, made before the design rather than inside it

### 1.1 `QAGateSpec.type` is **not** a closed enum — it is a bare `String`

The dispatch brief states the `type` field carries *"a CLOSED `type` enum"*, and asks which existing
types exist and which must be added. **That premise is false against the tree, and the difference is
load-bearing, so it is corrected here rather than answered in the brief's terms.**

```dart
// packages/platform_contracts/lib/src/types/product_manifest.dart:145-165
class QAGateSpec extends Equatable {
  const QAGateSpec({required this.gateId, required this.type,
                    required this.required, required this.config});
  final String type;                       // :155 — String, not an enum
```

and the generated deserializer accepts any string at all:

```dart
// packages/platform_contracts/lib/src/types/product_manifest.g.dart:109-114
QAGateSpec _$QAGateSpecFromJson(Map<String, dynamic> json) => QAGateSpec(
  gateId: json['gateId'] as String,
  type: json['type'] as String,            // :111 — no membership check exists
```

A repository-wide search for a gate-type enum returns nothing: no `knownGateTypes`, no
`supportedGateTypes`, no `GateType` declaration outside the four `GateEvaluator` classes that
publish `gateType` as a `String`. **Consequences, and they are both favourable:**

1. **Adding a type needs no enum change and no schema migration.** It needs (a) a `GateEvaluator`
   registered under that string and (b) a contract that declares it. This is materially smaller than
   the brief's framing implies, and it is why §4's new types are cheap to land.
2. **An unknown type is already fail-closed.** `QAOrchestration.evaluate` returns
   `QAGateStatus.notExecuted` for a type with no registered evaluator
   (`qa_orchestration.dart:19-31`), and `_isGateSatisfied` treats `notExecuted` as **unsatisfied**
   (`guard_conditions.dart:299-303`; `qa_orchestration.dart:56-61`). A product manifest declaring a
   type this design never heard of degrades to an honest block, not a silent pass.

**What is genuinely closed is the set of types with an evaluator** — `GateRegistry._evaluators` is a
`Map<String, GateEvaluator>` (`gate_registry.dart:9-17`) and `register` overwrites by key. That map,
not the `type` field, is the closed set that matters.

### 1.2 `evaluator-spec.md`'s `work_item_transitions.dart` citations have drifted by 42 lines

Recorded because every gate in §3 is anchored on that edge, and an implementer following the
approved spec's line numbers would land on a **different edge**.

| Property | `evaluator-spec.md` cites | At `9300eea` it is | What the cited range opens on today |
|---|---|---|---|
| `qaInProgress -> qaPassed` | `:690-696` | **`:732-738`** | `reviewApproved -> qaInProgress` (`:693-696`) — a different edge, with different guards |
| `actorAllowed([qaExecutor, orchestrator])` | `:691-694` | **`:733-736`** | `actorAllowed([orchestrator])` |
| `allRequiredGatesPassed()` | — | `:737` | itself, correct |
| `qaInProgress -> qaFailed` | `:697-702` | **`:739-744`** | inside the comment block above `:697` |
| `qaFailed -> waitingForHumanDecision` | `:709-715` | **`:751-757`** | `qaFailed`'s edge is at `:751`; `:709` is inside a comment |

`work_item_transitions.dart` is 894 lines, so none of these ranges is out of bounds — which is why
the defect survived seven correction passes: a range that resolves *to the wrong thing* is harder to
catch than one that resolves to nothing. `FOLLOW_UPS.md` §15 F-50 carries the same `:690`. This is
the **L3 pattern** (`evaluator-spec.md` §12.5, PASS3-1) in a new place, and
`docs/engineering/FOLLOW_UPS.md` is `PROHIBITED_PATHS` for this lane, so **it is reported, not
fixed**. Every citation in this artifact was re-derived at `9300eea`.

### 1.3 The complete inventory of gate types, existing and proposed

| `type` | Where | Registered evaluator? | Fabricated? | Verdict |
|---|---|---|---|---|
| `static-analysis` | `gate_registry.dart:20` | **yes** — `StaticAnalysisGate` | **yes** — collector returns `{'tool': …, 'issues': []}` (`static_analysis_gate.dart:24`) | must be **de-registered** per `evaluator-spec.md` §5.2 |
| `unit-tests` | `:21` | **yes** — `TestCoverageGate` | **yes** — returns `{'format':'lcov','threshold':…}` and **reads no coverage value at all** (`test_coverage_gate.dart:24`) | de-register |
| `security-scan` | `:22` | **yes** — `SecurityScanGate` | **yes** — `{'vulnerabilities': []}` (`security_scan_gate.dart:24`) | de-register |
| `performance` | `:23` | **yes** — `PerformanceGate` | **yes** — echoes `config` back (`performance_gate.dart:24-27`) | de-register |
| `triage-classification-structure` | `lane_g_triage_qa_contract.dart:174`; shipped in `apps/server/manifests/shipit-platform.product-manifest.json` as gate `intake-structured-result-admitted` | **no** | n/a | **structural.** Specified honestly at `evaluator-spec.md` §5.3; not yet implemented |
| `triage-evidence-grounding` | `:201` | **no** | n/a | **substantive, relational** — reused by §3.2 |
| `triage-clarification-routing` | `:221` | **no** | n/a | `required: false` (`:222`), deliberately — conditional on ambiguity, a property of the *report*, not of the run |

**So: no substantive gate type with a working evaluator exists anywhere in this repository.** The one
precedent — `structuredClassificationAdmitted`, `lane_g_triage_qa_contract.dart:172-189` — is a
precedent for **declaration shape** (`gateId`/`type`/`required`/`config` with a `config` vocabulary an
evaluator can read and a `sourceColumn` that is label-only), and this artifact copies that shape
exactly. It is not a precedent for evaluation, because it has no evaluator.

---

## 2. What "QA passed" must mean, per lane — and why the two lanes differ

### 2.1 The feature lane

> **Assertion F.** A feature item is QA-passed **iff**, for the implementation execution that produced
> it, all five of the following were established by reading durable rows the platform wrote:
>
> 1. **a commit exists at a recorded revision** — the workspace delta is readable and `headMoved` is
>    `true`;
> 2. **every path that commit touched matches the lane's declared owned paths and none matches a
>    declared prohibited path**;
> 3. **platform-verified evidence exists** for that execution, carrying
>    `EvidenceKind.platformVerifiedEvidence` — never `agentClaimedEvidence`;
> 4. **every declared check ran, under the declared command**, and reported `passed`;
> 5. **the revision engineering review approved is the revision the commit produced.**
>
> No agent-authored field participates in any of the five.

**Why this is the assertion and not a weaker one.** The demonstrated failure on this lane is
*vacuous completion*: *"seven IMPLEMENTER executions existed in QA, all seven completed with zero
files touched and zero commits, and all seven still reached `agent_completed` — which is the state
`engineeringReviewDefinition` dispatches from, so the review lane then failed closed forever because
there was no artifact to review"* (`success_artifact.dart:18-22`, quoted). A structural gate cannot
see that failure: an `AgentResult` with a well-formed `structuredResult` and an empty `changedFiles`
is structurally perfect. The feature lane's substance **has to be observed by something that is not
the agent**, and the only such thing in this repository is `WorkspaceDelta` (git, read by the
platform) and `PlatformVerification` (a real spawned process, `WorkspaceVerifier.verify`,
`workspace_verifier.dart:22-66`).

**Why no agent-authored field may participate.** `AgentResult.changedFiles` is documented
*"Files the agent reports changing"* (`agent_result.dart:53-54`) and `AgentResult.claimedChecks` is
documented *"Validation the AGENT claims. **Distinct from platform-verified evidence.**"*
(`agent_result.dart:56-57`). A gate that reads either is a gate the subject grades itself. This is the
same separation `AGENTS.md` §12 draws between `agentClaimedEvidence` and `platformVerifiedEvidence`,
and the same reason `PlatformReDerivationProof` "cannot be constructed" from a claim
(`apps/server/bin/onboard_shipit_dev.dart:344`).

### 2.2 The remediation lane

> **Assertion R.** A remediation item is QA-passed **iff** the defect it names resolves in durable
> storage, every evidence id its classification cites exists **and belongs to that defect**, and the
> classification is durably recorded rather than discarded.

**Why the two assertions are not the same assertion with different parameters.** Their failure modes
are opposites and their evidence is not interchangeable:

| | **Feature lane** | **Remediation lane** |
|---|---|---|
| What the item would change if wrongly passed | **production code that ships** — the blast radius is the product and its users | **no code directly** — but the recorded defect *scopes every later fix*, so the error propagates into code that does ship |
| The demonstrated failure | *produced nothing and looked complete* — seven of seven | *claimed something and recorded nothing* — `triage_processor.dart:124-132` logs `triage.processed.defect_missing`, returns the result, and the job sits `succeeded` with the classification abandoned (`design-revision.md` §3.2) |
| Substance is obtainable by… | **running something** — a commit, a validator, a revision identity. Expensive, strictly physical | **cross-referencing durable rows** — does this defect exist, do these evidence ids exist, do they belong to it. Cheap, strictly relational |
| Gate evidence class | execution-derived (`WorkspaceDelta`, `PlatformVerification`, review/revision identity) | relational (`defect`, `defect_evidence`) |
| Consequence for gate set | must include a gate that refuses a cheap liveness probe wearing a validator's name (§3.1 F4) | needs no execution gate at all — and **must not get one**, because a triage run legitimately produces no commit (that is exactly why `SuccessArtifactKind` is `ROLE_AWARE`, `success_artifact.dart:293-301`) |

**Neither set is a subset of the other, and that asymmetry is the design.** A commit proves nothing
about whether a cited evidence id exists. A resolvable defect id proves nothing about whether the
code that fixes it builds. **A single merged gate list would be a gate list whose members are
individually vacuous on one of the two lanes** — which is the defect this artifact exists to prevent.

---

## 3. The gate sets

### 3.0 Rules every gate below obeys

1. **Declared in a product manifest** as `QAGateSpec{gateId, type, required, config}` and
   **derived** by `buildProductQAContract` (`product_qa_contract.dart:117-127`) — no bespoke path.
2. **`config['evidenceTypes']` is always a `List<String>`**, or
   `ProductQAContract._declaredEvidenceTypes` throws `FormatException` and aborts the whole
   provision (`product_qa_contract.dart:168-192`). This is why the key appears in every gate below
   even though `QAGateSpec` has no such field (`product_manifest.dart:145-165`).
3. **`sourceColumn`, where present, is a label only.** It populates the evidence row's `artifactRef`
   and is **never** interpolated into a query. `evaluator-spec.md` §3.4 already rules this; the
   consequence is that every gate below reads through a **typed store reader** or a **named collector**,
   never through a table name.
4. **Each gate is implemented against `GateEvaluator` directly, not `GateEvaluatorImpl`.**
   `GateEvaluatorImpl._validateEvidence` returns `evidence.isNotEmpty`
   (`gate_evaluator.dart:53-58`), which is **true for every contract** because `evidenceTypes` is
   required and non-null — that is `evaluator-spec.md` §5.1's fabricated pass, and inheriting it would
   reproduce the defect.
5. **Each gate has exactly one `gateType` and exactly one evaluator class.** No gate branches on
   config to become a different gate.

### 3.1 Feature lane — five gates, five distinct falsifiers

| # | `gateId` | `type` (**all five NEW**) | `required` | What it asserts |
|---|---|---|---|---|
| **F1** | `feature-change-committed` | `implementation-artifact-provenance` | `true` | A commit exists at a recorded revision |
| **F2** | `feature-change-scope-confined` | `change-scope-confinement` | `true` | Every changed path is owned; none is prohibited |
| **F3** | `feature-validation-platform-verified` | `platform-verified-evidence` | `true` | Platform-verified evidence exists, bound to *this* execution |
| **F4** | `feature-declared-checks-executed` | `declared-validation-outcome` | `true` | Every declared check ran, under the declared command, and passed |
| **F5** | `feature-review-bound-to-revision` | `revision-identity-match` | `true` | The reviewed revision *is* the produced revision |

---

#### **F1 — `feature-change-committed`** · type `implementation-artifact-provenance`

```dart
config: <String, dynamic>{
  'evidenceTypes': ['execution_delta', 'committed_revision'],
  'requireReadableDelta': true,        // unreadable ⇒ FAIL, never 'missing'
  'requireHeadMoved': true,            // dirty-but-uncommitted ⇒ FAIL
  'recordProducedRevision': true,
}
```

Reads `WorkspaceDelta` for the lane's execution via `WorkspaceDeltaProbe.probe`
(`workspace_delta_probe.dart:118-123`) against `AgentExecution.workspace`.

`passed` **iff** `delta.isReadable && delta.headMoved == true`.

**Falsifies when** — each of these is a concrete input, not a category:

| Input | Result | Why it must not pass |
|---|---|---|
| HEAD equals `startingRevision`, tree clean (`WorkspaceDelta.unchanged`) | **FAIL** | nothing was produced. This is the seven-of-seven case |
| Tree dirty, HEAD unmoved (`WorkspaceDelta.changed`, `headMoved == null` or `false`) | **FAIL** | uncommitted work is not an artefact a later review can pin a revision to |
| `WorkspaceDelta.unreadable(reason)` | **FAIL** | *"I could not look"* must never be laundered into *"I looked and saw nothing"* — `workspace_delta_probe.dart:8-11` and `success_artifact.dart:266-281` both build on that distinction, and this gate inherits it rather than re-deciding it |
| `AgentResult.changedFiles` non-empty but HEAD unmoved | **FAIL** | the agent's claim cannot substitute for git's reading. This row is the gate's reason for existing |

---

#### **F2 — `feature-change-scope-confined`** · type `change-scope-confinement`

```dart
config: <String, dynamic>{
  'evidenceTypes': ['committed_diff_paths'],
  'ownedPathGlobs':    <List<String>>,  // REQUIRED, non-empty
  'forbiddenPathGlobs': <List<String>>,  // REQUIRED, may be empty list, may NOT be absent
  'pathSource': 'git_diff_name_only',    // label; the read is a typed collector
}
```

Passes **iff** every path in the diff `<startingRevision>..<producedRevision>` matches ≥1 owned glob
and **zero** forbidden globs.

**Falsifies when** — the diff touches `packages/workflow_engine/**` while the lane's
`OWNED_PATHS` named `apps/server/**` → **FAIL**, naming the offending path in the evidence row.
This is the falsification of a failure `evaluator-spec.md` §4.3 records in this repository's own
history: *"A prohibited-path boundary hid a regression from the lane that could have caught it."*
A structural gate cannot see a path at all, so it cannot catch this; the gate that can, must.

**A deliberate non-goal, stated so it is not mistaken for an omission:** this gate checks **confinement,
not correctness**. It does not assert the change was *right*. That is F4's job and engineering
review's.

---

#### **F3 — `feature-validation-platform-verified`** · type `platform-verified-evidence`

```dart
config: <String, dynamic>{
  'evidenceTypes': ['platform_verification'],
  'requireEvidenceKind': 'platformVerifiedEvidence',  // the ONLY permitted value
  'requireBoundToExecution': true,                     // executionId must equal the lane's
  'rejectClaimedEvidence': true,                       // see failure row 2
}
```

Reads `PlatformVerification` rows through `ExecutionStore.readVerifications(executionId)`
(`execution_store.dart:32`). Passes **iff** ≥1 row exists with
`evidenceKind == EvidenceKind.platformVerifiedEvidence` and `status == AgentClaimStatus.passed`.

**Falsifies when**

| Input | Result |
|---|---|
| **Every** row carries `EvidenceKind.agentClaimedEvidence` | **FAIL** — the exact substitution this gate exists to refuse. `AGENTS.md` §12: a producer's claim is preserved but *"does not satisfy `ProductGuard.baselineVerifiedIndependently` and never unlocks the approval gate"* |
| `readVerifications` returns `[]` | **FAIL** — no plan ran |
| The only rows belong to a **different** `executionId` | **FAIL** — evidence from a sibling run is not evidence about this one |
| `evidenceKind` is `platformVerifiedEvidence` but `status == failed` | **FAIL** |

> **F3 IS RED TODAY, AND THAT IS ITS CORRECT STATE.** `ExecutionCoordinator` carries **one**
> `verificationPlan` field for **all** roles (`execution_coordinator.dart:151-151`, `:162`), and the
> only plan composed in production is `triageVerificationPlan` — `git rev-parse --verify 'HEAD^{commit}'`,
> `checkName: 'git_worktree_head'` — attached to the single coordinator every role drives
> (`server.dart:1578-1583`, `:1638`). `server.dart`'s own comment states the consequence without
> hedging: *"Do not read a green implementation execution as evidence that verification ran."*
>
> **F3 therefore cannot be made green by anything this lane designs.** It goes green when the
> implementation lane has a role-scoped `VerificationPlan` — an architecture decision `server.dart`
> explicitly reserves as `OD-6` and declines to make itself. **F3 is specified as a red gate on
> purpose.** The alternative — reading `AgentResult.claimedChecks` so the bar is reachable — is the
> shortcut this artifact was dispatched to refuse, and it would convert the one gate that can tell
> "the code was verified" from "the code was verified" into "the agent said the code was verified."

---

#### **F4 — `feature-declared-checks-executed`** · type `declared-validation-outcome`

```dart
config: <String, dynamic>{
  'evidenceTypes': ['platform_verification'],
  'requireCheckNames':   <List<String>>,  // REQUIRED, non-empty
  'requireCommands':     <Map<String, String>>, // checkName -> EXACT command string; REQUIRED
  'requireStatus': 'passed',
  'commandMatchIsExact': true,           // not substring, not token overlap
}
```

Passes **iff** every entry of `requireCheckNames` has a row whose `checkName` matches **and** whose
`command` **string-equals** the declared command **and** whose `status` is `passed`.

**Falsifies when**

| Input | Result | Why it must not pass |
|---|---|---|
| A row named `dart_test` whose `command` is `git rev-parse --verify 'HEAD^{commit}'` | **FAIL** | **This is the live shape, not a hypothetical one.** `triageVerificationPlan` is already attached to every role's coordinator (`server.dart:1638`). Matching on `checkName` alone would let a liveness probe satisfy a test declaration, and `WorkspaceVerifier` sets `checkName` from the coordinator's plan, not from what the command proves (`execution_coordinator.dart:918-925`) |
| One of three declared checks has no row | **FAIL** | completeness, not best-effort |
| All three ran; one reports `failed` | **FAIL** | |
| A `commandMatchIsExact: false` implementation is written | — | the config key exists so the **strictness is a declared property**, and §6 requires a test that fails when a gate is implemented loosely against it |

**F4 is also red today**, for F3's reason, and turns green in the same commit that turns F3 green.

---

#### **F5 — `feature-review-bound-to-revision`** · type `revision-identity-match`

```dart
config: <String, dynamic>{
  'evidenceTypes': ['review_verdict', 'committed_revision'],
  'reviewedRevisionField': 'endingRevision',
  'producedRevisionField': 'producedRevision',   // what F1 recorded
  'requireStringEquality': true,
  'nullRevisionIsFailure': true,
}
```

Passes **iff** the engineering-review verdict's recorded revision is a non-null string **equal** to
the revision F1 recorded.

**Falsifies when**

| Input | Result |
|---|---|
| Review verdict names `a1b2c3`, F1 recorded `d4e5f6` | **FAIL** — the review approved code that is not the code produced. This is the failure named in the repository's own words: *"§9.2 row 5 (`endingRevision` null ⇒ review fails closed), which is a real check on the artefact — not on the code's behaviour"* (`server.dart:1616-1619`) |
| `endingRevision` is `null` | **FAIL** — not skipped, not `notApplicable`. `nullRevisionIsFailure: true` is the config form of that |
| `endingRevision` is `''` | **FAIL** — an empty string is not a revision; the emptiness check is stated because `String?` admits it and `null`-only checks do not catch it |

> **The cited `§9.2 row 5` is a reference to a design document this repository does not contain.**
> `server.dart:1616-1619` writes the bare `§9.2 row 5`; `design-revision.md`'s §9.2 is *"Requirements
> gaps"* (`design-revision.md:1035`) and the string `endingRevision` appears **nowhere** in it, in
> `evaluator-spec.md`, or in `design-review-gate.md`. **So which design §9.2 belongs to is not
> determinable from this tree**, and F5 does not depend on it — F5's own assertion is stated in full
> above and is independently checkable. Recorded rather than quietly citing a document that cannot be
> opened.

**The field exists.** `WorkerExecution.endingRevision` and `WorkerExecutionResult.endingRevision` are
both declared (`worker_execution.dart:60`, `worker_execution_result.dart:48`) and persisted through a
`WorkerStore` with compare-and-swap on version
(`packages/store_contract_tests/lib/src/worker_store_suite.dart:15-16`, `:19-22`). **What is not
established is the lookup path** — `readWorkerExecution` is keyed by execution id, and whether a
`WorkerExecution` is retrievable *by work item id* is a question this lane could not settle from the
tree. §10 records it rather than assuming it.

---

### 3.2 Remediation lane — three gates, three distinct falsifiers

The remediation lane reuses the **existing declared type** `triage-evidence-grounding`
(`lane_g_triage_qa_contract.dart:201`) rather than inventing one. Its `gateId` is
`triage-evidence-grounded` — the same declaration the triage contract already carries, which means
**a remediation contract and a triage contract that declare it agree by construction rather than by
convention.**

| # | `gateId` | `type` | `required` | What it asserts | Type status |
|---|---|---|---|---|---|
| **R1** | `remediation-defect-resolvable` | `triage-defect-existence` | `true` | The cited defect resolves | **NEW** |
| **R2** | `triage-evidence-grounded` | `triage-evidence-grounding` | `true` | Every cited evidence id exists **and belongs to that defect** | **EXISTING, declared, unregistered** |
| **R3** | `triage-classification-admitted` | `triage-classification-structure` | `true` | The structured result is well-formed | **EXISTING, declared, unregistered** — **structural; see §5** |

---

#### **R1 — `remediation-defect-resolvable`** · type `triage-defect-existence` (NEW)

```dart
config: <String, dynamic>{
  'evidenceTypes': ['defect_row'],
  'sourceColumn': 'defect.defectId',     // LABEL ONLY — never interpolated
  'requireResolvable': true,
  'idSource': 'workItemDefectReference',  // the id the item itself names
}
```

Passes **iff** a `defect` row exists for the id the remediation item names.

**Falsifies when** the work item is `design-remediation-DEF-x` and no `defect` row `DEF-x` resolves →
**FAIL**. **That is not a hypothetical: it is the live path.** `triage_processor.dart:122` reads the
defect and the read raises `DefectNotFoundException`; `:124-132` catches it, logs
`triage.processed.defect_missing`, and returns the result — leaving the job `succeeded` with the
classification discarded (`design-revision.md` §3.2, re-verified there). **R1 turns a
logged-and-dropped condition into a recorded gate outcome.**

---

#### **R2 — `triage-evidence-grounded`** · type `triage-evidence-grounding` (EXISTING)

Config **verbatim** from `lane_g_triage_qa_contract.dart:204-208`:

```dart
config: <String, dynamic>{
  'sourceColumn': 'defect_evidence.evidenceId',   // LABEL ONLY
  'everyCitedEvidenceMustExist': true,
  'mustBelongToReportedDefect': true,
}
```

Its own comment (`:196-198`) calls it *"the gate that makes a triage classification a statement ABOUT
THE REPORTED DEFECT rather than an unfalsifiable assertion, and it is the one the platform does not
currently enforce."* This artifact enforces it.

**Falsifies when**

| Input | Result |
|---|---|
| The classification cites `E-99`; no `defect_evidence` row `E-99` exists | **FAIL** |
| `E-7` exists but belongs to **a different defect** | **FAIL** — this second row is why this is a *grounding* gate and not an *existence* gate. A gate that only checked existence would pass a classification that cites a real evidence id belonging to somebody else's defect |
| The classification cites nothing at all | **FAIL** — `everyCitedEvidenceMustExist` over an empty citation list is **vacuously true**, so an evaluator must require **≥1** citation. **This vacuity is named here, in the config, so no implementer ships it.** |

---

#### **R3 — `triage-classification-admitted`** · type `triage-classification-structure` (EXISTING)

Config **verbatim** from `lane_g_triage_qa_contract.dart:177-188`
(declaration `:172-188`), per
`evaluator-spec.md` §5.3's specified semantics. **It is retained as a structural precondition and is
explicitly NOT counted as substance** — see §5.

**Falsifies when** `classification`, `status`, `confidence` or `suspectedCategory` is absent or null,
or `classification` is outside `DefectClassification` → **FAIL**, with the offending key named.

**Its limit, stated because it is the gate the whole exercise is about:** R3 passes on a payload whose
four fields are present, non-null, and enum-valid **and which asserts nothing true about any defect**.
`{"classification": "bug", "status": "open", "confidence": 0.0, "suspectedCategory": "unknown"}` is a
well-formed classification of nothing. **R3 alone must never be capable of producing `qaPassed`**, and
§7 is the mechanism that guarantees it.

---

**These three gates are reachable through the contract the product already declares.** A remediation
item creates `WorkItemCategory.feature` (`lane_e_design_remediation_work_item.dart:325`, `:387`) and
the shipped manifest declares `workItemCategories: ["feature"]`
(`apps/server/manifests/shipit-platform.product-manifest.json:32-34`), so the product-declared
provisioning path applies to it exactly as it does to a feature item. **They are not a contract for a
lane that has none** — which was `design-revision.md` §3's standing objection to authoring path-specific
gates, and which §3.2 answers by reusing an already-declared type rather than inventing a lane.

### 3.3 Why the remediation lane has no execution gate, stated as a decision

It would be easy to add F1 to the remediation contract — the item ran an agent. **It must not be done,
and the reason is in the code.** `SuccessArtifactKind.kindFor` maps
`AgentRole.triageDefect => SuccessArtifactKind.classificationResult`
(`success_artifact.dart:298`) and only `implementer` and `correctionImplementer` to
`committedCode` (`:294`, `:297`), on the explicit grounds that *"Triage legitimately finishes without
touching the product — it writes a classification report into a scratch repo, never code"*
(`success_artifact.dart:11-16`). `triage-repo` contains only `README.md`
(`server.dart:1557-1561`), so `dart test` cannot run there and a commit gate would fail every
correct triage run.

**Adding F1 to the remediation contract would produce a permanently red remediation lane** — and a
permanently red lane is how operators learn to waive gates. **This is the concrete mechanism by which a
gate set that looks stricter can be weaker in practice**, and it is why §6 requires the
waiver-rate assertion.

---

## 4. Which gate types are new — the exact delta

**New, requiring a `GateEvaluator` implementation each (5):**

| `type` | Gate | Falsifies on |
|---|---|---|
| `implementation-artifact-provenance` | F1 | HEAD unmoved / delta unreadable |
| `change-scope-confinement` | F2 | a changed path outside `ownedPathGlobs`, or inside `forbiddenPathGlobs` |
| `platform-verified-evidence` | F3 | every row is `agentClaimedEvidence`; or no rows; or rows bound to another execution |
| `declared-validation-outcome` | F4 | `checkName` matches but `command` does not; or a declared check is missing |
| `revision-identity-match` | F5 | reviewed revision ≠ produced revision; or `null`/empty |
| `triage-defect-existence` | R1 | cited defect does not resolve |

**Existing, declared but unregistered — needs only an evaluator (2):**
`triage-classification-structure` (R3), `triage-evidence-grounding` (R2).

**To be DE-REGISTERED (4):** `static-analysis`, `unit-tests`, `security-scan`, `performance` — per
`evaluator-spec.md` §5.2 option 2, which is the only option §5.2 leaves open. Each currently returns a
fabricated `PASSING` with an audit trail.

**No change to any type in `platform_contracts`.** §1.1 establishes there is no enum to extend. This
is the single largest reduction in estimated effort between the dispatch's framing and the tree.

---

## 5. Migration from `intake-structured-result-admitted` — **RETAIN, as a structural precondition**

**Decision: retain it, unchanged, `required: true`, alongside the substantive gates. Do not replace it
and do not weaken it.**

**Why retain, in the decision's own words.** `92d567e3` says the gate *"stays registered and truthful —
it really does assert that the structured result was produced and parsed"*, and the only thing it
forbids is describing it as a quality gate. Retaining it costs nothing, asserts something true, and
keeps the shipped manifest's contract shape intact. Replacing it would destroy a working declaration
to no end.

**Why it is not sufficient, and where that is enforced rather than promised.** R3 passes on a
structurally-valid-but-empty payload. Three independent mechanisms make such a payload incapable of
producing `qaPassed`, and **all three are required**:

1. **R1 and R2 are `required: true` in the same contract.** `isOverallPass` requires every required
   gate to be satisfied (`qa_orchestration.dart:86-100`).
2. **§7 closes the vacuous pass**, so "R1 and R2 were never evaluated" cannot be laundered into
   "R1 and R2 were satisfied".
3. **§6's non-vacuity test** fails if any registered evaluator's verdict is not a function of its
   input.

**The naming discipline, which is an obligation and not a preference.** The gate keeps its id and its
`gateId`. **It must not be described as a quality gate anywhere** — not in code comments, not in a
contract's `metadata`, not in a UI label. The contract `metadata` key `evaluatorRuntime`
(`product_qa_contract.dart:156`, `lane_g_triage_qa_contract.dart:156`) survives until *every* required
gate type has a real evaluator (`evaluator-spec.md` §6). **Naming a structural gate "quality" is the
cheapest way to make this whole artifact ineffective**, because it restores the exact wording the
operator rejected.

**The honest position on the remediation lane's structural gate.** R3's `requiredFields` are justified
by a live consumer — `_parseTriageResult` throws `FormatException` unless those four keys are present
and returns `null` on it (`triage_processor.dart:199-222`, `:270-276`), which is what
`evaluator-spec.md` §5.3 establishes. **R3 records as an obligation what is currently an accident of a
`catch` block.** That is a real justification, and it is a *structural* one. The design does not
upgrade it to a substantive one, and this artifact is the reason the distinction stays visible.

---

## 6. Falsification tests implementers must write, and the non-vacuity discipline

### 6.1 The rule

> **Every gate ships a test that FAILS when the gate is bypassed.** A test that passes when the gate
> works proves the gate was not consulted — it passes identically when the gate is deleted.

This is `evaluator-spec.md` §4.3's V1–V6 discipline, restated per gate because V1–V6 govern the
*drain* while §6.2 governs the *evaluators*, and an evaluator that is never tested is exactly the
fabricated pass §5.1 describes. §6.2 states **fourteen required tests across the eight gates** —
two per feature gate, three for R2 — and §6.4 adds two assertions that are not per-gate.

The rule V3 and V4 carry is inherited verbatim: **"V3 and V4 are the two that do not exist in any
form today and that a naive wiring would pass."** F2, R2's *belonging* row, and F4's command-identity
row are that same class here — **each passes under the obvious implementation and fails only under the
one that reads the property.**

### 6.2 The required test per gate

| Gate | The test that must exist | It fails when |
|---|---|---|
| **F1** | An execution with `headRevision == startingRevision` and a clean tree | `WorkspaceDelta.hasChanges` is read instead of `headMoved` |
| **F1** | An execution with `WorkspaceDelta.unreadable(...)` | `unreadable` is coerced to `missing` |
| **F2** | A diff touching one forbidden path | the glob list is read from the contract but never matched |
| **F3** | Only `agentClaimedEvidence` rows present | `evidenceKind` is not read at all |
| **F3** | Rows bound to a different `executionId` | the execution filter is dropped |
| **F4** | `checkName: 'dart_test'` with `command: 'git rev-parse …'` | `commandMatchIsExact` is implemented as a substring test |
| **F4** | Two of three declared checks present | the loop short-circuits on the first match |
| **F5** | `endingRevision` ≠ produced revision | only one side of the comparison is read |
| **F5** | `endingRevision == null` | the null case is treated as `notApplicable` |
| **R1** | A `design-remediation-*` item whose defect does not resolve | the catch that logs `triage.processed.defect_missing` swallows the refusal |
| **R2** | An evidence id that exists but belongs to another defect | only `everyCitedEvidenceMustExist` is implemented |
| **R2** | A classification citing **zero** evidence ids | the vacuous-`every` passes |
| **R3** | A payload with `classification: 'not_an_enum'` | the enum check is a presence check |

### 6.3 The non-vacuity discipline this repository now requires

`docs/engineering/FOLLOW_UPS.md` §29 **F-85** records the lesson, verbatim: *"an `Edit` call
reported-success while writing only whitespace, and only a `shasum` against a saved copy caught it.
Standard-adopted: byte-copy, `shasum` before and after, `dart format --set-exit-if-changed`, then
trust the count."*

**Applied to every count an implementer reports about this work:**

1. **Byte-copy before editing.** `cp <file> /tmp/<file>.orig`.
2. **`shasum` before and after.** If the hashes are equal, the edit was a phantom — **report it; do
   not re-run and hope.** F-85's phantom reported success.
3. **`dart format --set-exit-if-changed <file>`** — CLI, not the MCP analyzer tool, which has
   reported "no errors" on code with ten real ones.
4. **Then** trust any count, line range, or `file:line` citation.
5. **A citation is a claim that opens onto something.** §1.2 is the worked example in this very
   artifact set: `evaluator-spec.md`'s `:690-696` resolves to a *different edge* at `9300eea`, and it
   survived seven correction passes because a range that resolves to the wrong thing is harder to
   catch than one that resolves to nothing. **Open every citation you carry.**

### 6.4 Two more assertions that belong with the eight gates

| # | Assertion | Fails if |
|---|---|---|
| **N1** | **Differential non-vacuity.** For each registered type, **two inputs that differ must produce different verdicts.** | The evaluator's verdict is a constant. All four current evaluators fail this trivially — identical output for identical config — which is `evaluator-spec.md` §5.2's reason de-registration is the only safe option |
| **N2** | **Waiver-rate assertion.** After the gates are live, a `required: true` gate waived more than **N** times per 20 items trips a durable operator alert | Waivers became the normal path. A red gate that operators learn to waive is weaker than no gate, and this is the only assertion that detects it |

---

## 7. The vacuous-pass hole in `allRequiredGatesPassed()` — **it closes, and it is worse than recorded**

### 7.1 What is actually there

```dart
// packages/workflow_engine/lib/src/validation/guard_conditions.dart:257-289
final gateResults = context?['gateResults'] as List<QAGateResult>?;      // :267
if (gateResults == null) {
  return GuardResult.fail(name, 'Gate results required for QA evaluation'); // :268-270
}

final requiredGates = gateResults.where(                                  // :272
  (g) => context?['qaContract']?.gates.any(
        (gc) => gc.gateId == g.gateId && gc.required) ?? false,           // :274-277
);

final allSatisfied = requiredGates.every(_isGateSatisfied);               // :280
```

### 7.2 The hole is **wider** than `evaluator-spec.md` §1 and `FOLLOW_UPS.md` F-49 record

Both describe the same failure: *supply `gateResults` without `qaContract`, the filter yields an empty
iterable, `.every()` on it is `true`, and the guard passes.* **That is real. It is not the whole
hole.**

**The filter at `:272` selects from `gateResults`, not from `qaContract.gates`.** So the guard asks
*"of the results I was handed, are the required ones satisfied?"* — and **never asks "was every
required gate given a result at all?"**

**Therefore: with `qaContract` present and correctly populated, a contract declaring three required
gates and a `gateResults` list containing only the one that passed — evaluates `requiredGates` to
that single element, `.every()` returns `true`, and the guard PASSES.** The other two required gates
were never evaluated and the guard never noticed.

| `qaContract` required gates | `gateResults` supplied | Current guard verdict | Correct verdict |
|---|---|---|---|
| 3 | 3, all satisfied | pass | pass |
| 3 | 3, one `failed` | fail | fail |
| 3 | **3, one `notExecuted`** | fail | fail |
| 3 | **1 — the passing one only** | **PASS** | **FAIL** |
| 3 | **`[]`** | **PASS** | **FAIL** |
| 3 | **results for three gates that are all `required: false`** | **PASS** | **FAIL** |
| absent | any non-null list | **PASS** | **FAIL** |

**F-49 says *"the current state is the safe direction — no producer at all means `gateResults` is null
and the guard fails — so this is a trap for the next implementer, not a live hole today."* That
remains true of the *no-producer* state, and it is exactly why the hole has survived: with nothing
wired, the `null` branch catches everything. **The moment slice 3c wires a producer, the hole becomes
live** — and the producer is the next implementer, not a hypothetical future actor.

### 7.3 `isOverallPass` has the identical defect

```dart
// packages/qa_orchestration/lib/src/qa_orchestration.dart:86-100
final requiredGates = contract.gates.where((g) => g.required).map((g) => g.gateId).toSet();
final requiredResults = results.where((r) => requiredGates.contains(r.gateId));  // :91-93
for (final result in requiredResults) {                                            // :95
  if (!isGateSatisfied(result)) return false;
}
```

`requiredResults` is filtered from `results`; the loop iterates **results**, never `requiredGates`.
Three required gates, one passing result → `true`. **A fix to the guard alone would leave
`isOverallPass` able to report an overall pass on a contract it never fully evaluated**, and
`evaluator-spec.md` §3.2 step 3 records `isOverallPass` as the value the determination lane reads.
**Both must be fixed, or the fix is half a fix.**

### 7.4 How it closes

**The invariant, in one line:** *a required gate with no result is `notExecuted`, not absent.*

**C1 — `_AllRequiredGatesPassedGuard` (`guard_conditions.dart:257-289`), in this order:**

1. `gateResults == null` → **FAIL** (unchanged, `:268-270`).
2. **`qaContract` absent from `context` → FAIL** with a reason naming the missing key. *(New. Closes
   the F-49 / `evaluator-spec.md` §1 hole.)*
3. **For every `gc` in `qaContract.gates` where `gc.required`: there MUST exist a result with
   `result.gateId == gc.gateId`. If none exists → FAIL**, naming the gate id. *(New. Closes the
   subset hole — the wider one.)*
4. **Every such result must satisfy `_isGateSatisfied`** (unchanged semantics, `:291-305`).

Step 3 is the whole fix and it is four lines. **It is fail-closed by construction:** a gate that was
never evaluated and a gate that evaluated and failed now produce the same verdict, which is the correct
one and is the property `evaluator-spec.md` §1 already states as desirable.

**C2 — `QAOrchestration.isOverallPass` (`qa_orchestration.dart:86-100`):** invert the iteration — loop
`requiredGates` and look each one up in `results`, failing on a miss — so it agrees with C1 by
construction rather than by parallel maintenance.

**C3 — `QAGateEvaluationService` (§3.1 of `evaluator-spec.md`) must return both keys.** Already
specified there; recorded here because C1 step 2 makes it **load-bearing**: a half-returning outcome
is now a guard refusal rather than a silent pass.

**C4 — a guard test for each row of §7.2's table.** All seven rows, including the three currently
green-and-wrong.

**Not proposed, and stated so it is not assumed: a change to `_isGateSatisfied`.** It is already
correct (`guard_conditions.dart:291-317`): `passed`/`waived`/`notApplicable` satisfied; `skipped`
satisfied only with an authority reference; `pending`/`running`/`failed`/`notExecuted` not. **The bug
is in what is iterated, not in how each element is judged.**

---

## 8. Implementation sequence

**Label discipline, because the approved spec's slice numbers are load-bearing.**
`evaluator-spec.md` §5.2 defines **3a**, §5.3 defines **3b**, and §2.1/§4.2 define **3c** — those
three names are **reused here unchanged and mean exactly what they mean there**. Steps this artifact
introduces are prefixed **`G`** (guard), **`E`** (evaluator) and **`M`** (manifest), so no new step can
collide with a slice number an implementer has already read in the approved spec.

| Step | What | Ordering obligation |
|---|---|---|
| **3a** *(approved)* | De-register the four fabricating evaluators | Before anything is wired |
| **G1** *(new)* | **C1 + C2 (§7.4)** and the seven-row guard test | **Before any evaluator is registered.** A guard carrying the subset hole makes every later gate optional |
| **E1** *(new)* | The two declared triage evaluators: `triage-classification-structure`, `triage-evidence-grounding` | Same as approved **3b**, which E1 completes — E1 does not replace or renumber it |
| **E2** *(new)* | `implementation-artifact-provenance` (F1), `change-scope-confinement` (F2) | Each lands **with** its evaluator, never ahead of it |
| **E3** *(new)* | `platform-verified-evidence` (F3), `declared-validation-outcome` (F4), `revision-identity-match` (F5), `triage-defect-existence` (R1) | Each lands with its evaluator |
| **3c** *(approved)* | The `qaInProgress` drain, widened to include the `reviewApproved -> qaInProgress` caller | **Last of the runtime wiring.** F-49's warning is that wiring a *producer* is what makes the hole live — and **G1 is what stops it being live** |
| **M1** *(new)* | The product manifest's feature-lane gate set (§3.1); the remediation contract's R1 (§3.2) | Only after E1–E3, so no contract ever declares a gate with no evaluator |

**The two orderings that are obligations, not preferences:**

- **G1 precedes 3c.** Wiring the producer before the guard is closed is what turns F-49's *"trap for the
  next implementer"* into a live vacuous pass. §7.4 is four lines; the cost of doing it last is a
  production window in which `qaPassed` means nothing.
- **E1–E3 precede 3c.** `QAOrchestration.evaluate` returns `notExecuted` for an unregistered type
  (`qa_orchestration.dart:19-31`), which `_isGateSatisfied` treats as unsatisfied
  (`guard_conditions.dart:299-303`) — so this ordering makes the drain fail **closed and honestly**,
  which is `evaluator-spec.md` §6's `PARTIALLY ENFORCED`, not §5.1's fabricated `PASSING`.

**`qaPassed` stays closed until E1–E3 and M1 land, and — for the feature lane — until a role-scoped
implementation `VerificationPlan` exists.** That is `92d567e3`'s accepted cost, restated: items
accumulate at `review_approved`. **No step above is weakened to shorten the queue, and the queue is not
a reason to shorten a step.**

---

## 9. Traceability

**Requirements covered**

| Requirement | Where |
|---|---|
| Machine-checkable meaning of "QA passed", per lane | §2.1 (F), §2.2 (R) |
| Different risk per lane, and why | §2.2's table |
| Concrete gate set with `gateId`/`type`/`required`/`config` | §3.1, §3.2 |
| Every gate falsifiable, with the failing input | §3.1/§3.2 per-gate tables; §6.2 |
| Existing vs. new gate types, explicitly | §1.3, §4 |
| Falsification tests + non-vacuity discipline (F-85) | §6 |
| The vacuous-pass hole: closure or proof it cannot fire | §7 — **it closes**; C1 step 3 |
| Migration from the structural gate | §5 — **retain**, with three enforcement mechanisms |
| What remains undecidable | §10 |
| A gate a structurally-valid-but-empty payload cannot pass | §2 (R3's limit), §5, §6.3 N1 |

**Requirements gaps** — carried, not closed

1. **`OD-6`, the role-scoped implementation `VerificationPlan`.** F3 and F4 are red until it is
   decided. `server.dart` reserves it as an architecture decision and declines to make it. **This is
   the gap that most limits what this design can deliver**, and it is named rather than engineered
   around.
2. **The `WorkerExecution` lookup key** for F5 (§3.1 F5).
3. **The item's declared owned/forbidden path globs.** F2's config cannot be filled from the
   repository: `AGENTS.md`'s `Product-specific policy → Path ownership map` is `TBD`. **F2 ships with
   the config keys and a `FormatException` on an empty `ownedPathGlobs`, not with a guessed glob.**
4. **`requiredCheckNames` / `requireCommands` per product** — same reason. The gate needs the product
   to say what "validated" means; the platform cannot infer it.

---

## 10. What remains UNDECIDABLE — stated, not guessed

1. **What a product's declared validation commands are.** `AGENTS.md`'s "Required validation gates" is
   `TBD`. F4's `requireCheckNames`/`requireCommands` are therefore specified as **required config
   keys that must be non-empty**, and no values are invented. Inventing `['dart','analyze','dart','test']`
   as a default would make the gate a constant that every product satisfies for free — the fabricated
   pass in a new costume.
2. **The path-ownership map.** `AGENTS.md`'s "Path ownership map" is `TBD`. Same disposition.
3. **The `evidenceTypes` vocabulary for F1/F2/F5** (`execution_delta`, `committed_diff_paths`,
   `review_verdict`, `committed_revision`). `QAEvidence.evidenceType` is a free `String` and no
   registry of evidence types exists; these names are proposed, not derived from a controlled list.
   An implementer must confirm no consumer depends on the existing spellings.
4. **`OD-6`'s shape** — per-role coordinator vs. a plan resolved from the job's role.
   `server.dart:1624-1638` reserves this explicitly and declines to make it, naming the two options.
   **It is the single decision that unblocks F3 and F4** (§3.1).
5. **Whether the remediation contract is a separate contract or the triage contract with R1 and R3
   appended.** §3.2 reuses `triage-evidence-grounded`'s declaration; if the two contracts are the same
   row, adding R1 and R3 changes `optionalGateFailuresAllowed`'s derivation
   (`product_qa_contract.dart:128-140`). Not determined from the tree.

> **AN ITEM THIS LANE FIRST LISTED HERE AND THEN ANSWERED — recorded rather than silently dropped,
> because a question removed from a gaps list without its answer reads as never having been asked.**
> An earlier draft of this section carried, as undecidable: *"whether the shipped product manifest's
> `workItemCategories` should keep being `["feature"]` alone, and whether a remediation item gets a
> product-declared contract at all."* **The tree answers it.**
> `lane_e_design_remediation_work_item.dart:325` and `:387` both create
> `WorkItemCategory.feature`, and the manifest's own `metadata.inertFields` says so in words:
> *"feature is the only category any intake path on this product actually files (triage, design
> remediation and feature intake all create `WorkItemCategory.feature`)"*
> (`apps/server/manifests/shipit-platform.product-manifest.json:81`). **So §3.2's remediation gates
> ARE reachable through the shipped manifest's declared contract**, and the question is closed. What
> remains open is only the *sharing* question above, which is narrower.

---

## 11. Revision entry

A revision entry recording this artifact is appended to
`design-revision-metadata.yaml` as **`revision_number: 3`**, additive only, touching no existing key's
value. Per `DESIGN_GOVERNANCE.md:92-99` the risk level is:

**Level 3 — Major Workflow Change.** It changes the meaning of a core workflow state transition
(`qaInProgress -> qaPassed`) for two lanes, introduces a guard that fails closed where it previously
passed vacuously, and specifies new gate types registered on a governed path. Gate D4 is
`HUMAN_DECISION_REQUIRED` for Level 3.

**No `HUMAN_DECISION_REQUIRED` is raised by this lane, and that is not an evasion of Gate D4.** The
governing decision `92d567e3`'s `scope_note` states: *"Dispatchable as an ordinary design lane with
independent review, under the Gate-D4 approved `design/qa-contracts-feature-remediation/`. No further
human gate is required to run that design."* **This artifact is that design.** What Gate D4 requires
next is independent design review followed by human approval of the reviewed artifact — **which is not
this lane's to grant, and this lane does not grant it.**