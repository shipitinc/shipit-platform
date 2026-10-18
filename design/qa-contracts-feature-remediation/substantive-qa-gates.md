# Substantive QA Quality Gates — the feature lane and the remediation lane

**Artifact type:** Design Revision, additive companion to
[`design-revision.md`](./design-revision.md) (revision 2, Gate-D4 APPROVED)
**Authoring lane:** `design-SUBSTANTIVE-QA-GATES` (design-agent)
**Base SHA:** `9300eea9259b1bc6f0ecaeaae5d45832652bf549` — verified `git rev-parse --short HEAD` ==
`9300eea` before the first edit; tracked tree clean (`git status --porcelain --untracked-files=no`
empty, `git diff --quiet HEAD` returned 0).

> ## ⚠ CORRECTION PASS `correct-DESIGN-REVIEW-3` — read this first
>
> **Base SHA:** `01b9fae178b877ab05564273f0f583a4006ab042`, verified `git rev-parse --short HEAD` ==
> `01b9fae` and `git status --porcelain --untracked-files=no` empty before the first edit.
> **Independent review of revision 3 returned `DESIGN_REVIEW_CHANGES_REQUIRED`,
> `CORRECTION_REQUIRED: YES`, `HUMAN_DECISION_REQUIRED: NO`.** Risk level 3 agreed and unchanged.
>
> **The corrections that matter most to an implementer, before you read anything else:**
>
> 1. **The former gate F3 did not exist in substance.** It was **green today** — every implementation
>    execution already satisfies it — and it is **merged into F4**. **F4 alone holds the feature lane
>    closed today.** §3.1 states the corrected claim in full, with the four facts it rests on.
> 2. **Two readers F1, F2 and F5 depend on do not exist in this repository.** §8 **P1** names them
>    and orders them before the evaluators. **Building a gate before P1 will produce a gate that
>    passes vacuously on committed runs.**
> 3. **`evaluator-spec.md`'s `work_item_transitions.dart` citations were wrong and are now corrected
>    in place.** If you read the approved spec before this correction, **its anchor for
>    `qaInProgress -> qaPassed` pointed at a different edge.** See §1.2.
> 4. **§6.2's test count was wrong in three directions and is now 16, derived by addition.** A count
>    an implementer can satisfy by padding is a live hazard.
>
> **Everything §7 establishes about the vacuous pass is unchanged**, as are §5's retention decision,
> the risk-asymmetry argument, and the four de-registered evaluators. **§11.2 lists every change in
> the reviewer's order.**
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
| `OWNED_PATHS` *(this correction pass)* | `design/qa-contracts-feature-remediation/substantive-qa-gates.md` (this file); `design/qa-contracts-feature-remediation/design-revision-metadata.yaml` (**additive entry only**, §11); `design/qa-contracts-feature-remediation/evaluator-spec.md` (**CITATIONS ONLY** — §1.2); `docs/engineering/FOLLOW_UPS.md` (**line 1153's citation, plus the new findings entries**, §1.2) |
| `OWNED_PATHS` *(revision 3, the authoring lane)* | the first two entries only. The third and fourth were `PROHIBITED_PATHS` for that lane and it was correct to refuse them — see §1.2 |
| `READ_ONLY_PATHS` | `apps/**`, `packages/**`, `docker/**`, `.decisions/**`, `.github/**`, `Makefile`, and the sibling artifacts in this directory not named above |
| `PROHIBITED_PATHS` | all production source, all test source, `docker/**`, `.decisions/**`, `apps/server/manifests/shipit-platform.product-manifest.json`, `design-review-gate.md`, `design-revision.md`, `design-brief.md`, `design-brief-metadata.yaml`. **No production change was made, and where this correction implies one it is named as a finding — §8 P1 and §8 G1 are implementation work, not design edits.** |

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

### 1.2 `evaluator-spec.md`'s `work_item_transitions.dart` citations have drifted by 42 lines — **now FIXED, and the fix is an approved artifact**

> **CORRECTION PASS — READ THIS BEFORE YOU WORK FROM `evaluator-spec.md`.** Revision 3 of this
> artifact *reported* these citations rather than fixing them, because `evaluator-spec.md` and
> `docs/engineering/FOLLOW_UPS.md` were `PROHIBITED_PATHS` for that lane. **That refusal was correct
> and this correction supersedes it**: both paths are in this pass's `OWNED_PATHS`, and the citations
> below have been corrected **in place**. **The approved spec's anchor was wrong.** If you read
> `evaluator-spec.md` before this correction landed, you read a `qaInProgress -> qaPassed` edge that is
> not the one in the tree.

Recorded because every gate in §3 is anchored on that edge, and an implementer following the approved
spec's line numbers landed on **a different edge**.

| Property | `evaluator-spec.md` **used to cite** | At `01b9fae` it is | What the cited range opens on today |
|---|---|---|---|
| `qaInProgress -> qaPassed` | `:690-696` | **`:732-738`** | `reviewApproved -> qaInProgress` (`:693-696`) — a different edge, with different guards |
| `actorAllowed([qaExecutor, orchestrator])` | `:691-694` | **`:733-736`** | `actorAllowed([orchestrator])` |
| `allRequiredGatesPassed()` | — | `:737` | itself, correct |
| `qaInProgress -> qaFailed` | `:697-702` | **`:739-744`** | inside the comment block above `:697` |
| `qaFailed -> waitingForHumanDecision` | `:709-715` | **`:751-757`** | `qaFailed`'s edge is at `:751`; `:709` is inside a comment |

`work_item_transitions.dart` is 894 lines, so none of these ranges is out of bounds — which is why
the defect survived seven correction passes: a range that resolves *to the wrong thing* is harder to
catch than one that resolves to nothing.

> **This correction did NOT touch the property the citations describe.** Every citation in
> `evaluator-spec.md` and in `FOLLOW_UPS.md` §15 F-50 was re-derived by opening the range at
> `01b9fae` (`grep -n` on the five `(from, to)` edge headers, then the range itself). **The assertions
> are unchanged and no implementer builds anything different** — what changed is only which lines
> those assertions open onto. The same is true of every citation in this artifact.
>
> **One honest caveat.** The corrections are line-number substitutions inside existing sentences.
> `evaluator-spec.md` at lines 65, 173 and 405 **affirmatively asserted that the stale ranges were
> correct** — *"they resolve there exactly"*, *"are correct there"*. **An affirmative false claim
> cannot be repaired by rewriting the number beside it**, so those sentences were rewritten to state
> the drift and the correct range, and the historical PASS-7 passage that made the claim is preserved
> and explicitly marked as having been wrong.

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
> it, all four of the following were established by reading durable rows the platform wrote:
>
> 1. **a commit exists at a recorded revision** — the workspace delta is readable and `headMoved` is
>    `true`;
> 2. **every path that run touched matches the lane's declared owned paths and none matches a
>    declared prohibited path**;
> 3. **every declared check ran, under the declared command**, and reported `passed` — and the rows
>    carrying that verdict were written by the platform's own spawned process, not by the agent;
> 4. **the revision engineering review approved is the revision the commit produced.**
>
> No agent-authored field participates in any of the four.

> #### Why this is four items and not five — a correction made under review, recorded in place
>
> Revision 3 of this artifact asserted a fifth item: *"platform-verified evidence exists for that
> execution, carrying `EvidenceKind.platformVerifiedEvidence` — never `agentClaimedEvidence`."* **That
> item asserted a distinction the platform cannot currently express on this path, and it is removed
> rather than weakened.** The reason is established in full in §3.1's merged gate: `PlatformVerification`
> declares `evidenceKind` with a **default of `platformVerifiedEvidence`**
> (`platform_verification.dart:24`), `ExecutionCoordinator` never sets the field
> (`execution_coordinator.dart:915-930`), and the only verification plan composed in production is a
> liveness probe (`server.dart:1578-1581`, `:1638`). **Every implementation execution therefore already
> satisfies item 3 as an independent assertion — it is satisfied before the gate exists.** What
> item 3 *did* mean survives as a **defensive invariant inside item 4**, where it is still refused and
> still costs nothing to keep, but it is no longer counted as one of the ways a pass is earned.
>
> **The refusal is unchanged; only its stated reason was false.** Reading `AgentResult.claimedChecks`
> remains out of bounds — the operator rejected it and `AGENTS.md` §12 forbids a producer's own claim
> satisfying an independence guard. That refusal is unaffected by this correction. What was false is the
> claim that F3 was *red by construction*: it is **green today**, and §3.1 says so.

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
2. **`config['evidenceTypes']` is READ BACK by `_declaredEvidenceTypes`, and an ABSENT key yields `[]`
   silently** — it does **not** throw. The function returns `const []` when
   `!gate.config.containsKey('evidenceTypes')` (`product_qa_contract.dart:168-171`), and that is the
   **documented and tested** behaviour: a gate that declares none "says so explicitly rather than
   being skipped", asserted as `isEmpty` (`product_qa_contract_test.dart:495-501`, run green).
   `FormatException` fires **only when the key is present and malformed** — not a `List`, or a `List`
   containing a non-`String` (`:172-189`).
   > **CORRECTION.** Revision 3 of this artifact asserted the opposite: *"`config['evidenceTypes']`
   > is always a `List<String>`, or `ProductQAContract._declaredEvidenceTypes` throws `FormatException`
   > and aborts the whole provision"* — and inferred from it that the key is **mandatory**. **Both are
   > false.** The key is **recommended, not mandatory**, and it appears in every gate below for a
   > different reason: **omitting it produces an empty evidence requirement**, which is a *weaker*
   > gate, not a rejected declaration. See rule 4 for what an empty list actually causes.
3. **`sourceColumn`, where present, is a label only.** It populates the evidence row's `artifactRef`
   and is **never** interpolated into a query. `evaluator-spec.md` §3.4 already rules this; the
   consequence is that every gate below reads through a **typed store reader** or a **named collector**,
   never through a table name.
4. **Each gate is implemented against `GateEvaluator` directly, not `GateEvaluatorImpl`.**
   `GateEvaluatorImpl._validateEvidence` returns `evidence.isNotEmpty`
   (`gate_evaluator.dart:53-57`), and `evidence` is built by looping `gate.evidenceTypes`
   (`:29-39`). **So the fabricated pass is conditional, and the condition is rule 2's absent key:**
   with `evidenceTypes` declared, `evidence` is non-empty for every contract and the evaluator passes
   on the **shape of the config alone**; with `evidenceTypes` **absent**, the loop never runs,
   `evidence` is `[]`, and the evaluator returns `failed` — an accidental honesty that is not a
   property anyone should rely on. Inheriting the fabricated branch is what `evaluator-spec.md` §5.1
   describes, and every gate below is specified against `GateEvaluator` directly instead.
   > **CORRECTION.** Revision 3 said the fabricated pass holds *"for **every** contract** because
   > `evidenceTypes` is required and non-null"*. Under rule 2's corrected reading the key is **not
   > required**, so "every contract" was wrong in the other direction too: a contract that omits the
   > key fails. Neither branch is a designed behaviour and both are why the gates below do not use
   > this class.
5. **Each gate has exactly one `gateType` and exactly one evaluator class.** No gate branches on
   config to become a different gate.

### 3.1 Feature lane — four gates, four distinct falsifiers

> **CORRECTION.** Revision 3 of this artifact specified **five** feature gates, F1–F5, and asserted
> *"five gates, five distinct falsifiers."* **It is four, and the fifth was not a distinct falsifier** —
> F3's `evidenceKind` condition cannot fail on any production input (§3.1 F4, corrected). F3 is merged
> into F4, and the type count drops from six new types to five. The **property §3.1 was written to
> protect is unchanged**: every surviving gate still has a falsifier reachable in production, which is
> a stronger claim than having a falsifier reachable only under test.

| # | `gateId` | `type` (**all four NEW**) | `required` | What it asserts |
|---|---|---|---|---|
| **F1** | `feature-change-committed` | `implementation-artifact-provenance` | `true` | A commit exists at a **recorded** revision |
| **F2** | `feature-change-scope-confined` | `change-scope-confinement` | `true` | Every changed path is owned; none is prohibited |
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

`passed` **iff** `delta.isReadable && delta.headMoved == true`, **evaluated after the re-read below.**

> #### `headMoved == null` is "HEAD was never read", not "HEAD did not move" — and the gate re-reads
>
> Revision 3 of this artifact wrote F1's second falsification row as *"Tree dirty, HEAD unmoved
> (`WorkspaceDelta.changed`, `headMoved == null` or `false`)"*. **That row conflated two different
> facts, and the conflation made the gate fail on a real commit.**
>
> `GitWorkspaceDeltaProbe` **short-circuits on a dirty tree and never reads `HEAD`**
> (`workspace_delta_probe.dart:199-217`): when `git status --porcelain` is non-empty it returns
> `WorkspaceDelta.changed(headRevision: null, headMoved: null)` (`:210-216`) without spawning the
> second subprocess (`:219-225`). So **`headMoved == null` means "not established", never "established
> as no"** — the probe's own doc says so (`workspace_delta_probe.dart:31-35`), and
> `WorkspaceDelta.headMoved` is a deliberate `bool?` for that reason (`:87-96`).
>
> **The consequence is a false negative on the best-behaved runs in the repository.** An
> implementation that commits its work **and** leaves any untracked file — which is every lane whose
> `make clean` was disarmed, and this artifact set's own §6.3 requires `cp <file> /tmp/…` before every
> edit — returns `headMoved: null`, `headRevision: null`. F1 as written **FAILS that run**, F1 records
> no `producedRevision`, and F5's `nullRevisionIsFailure` then fires on a **null that was never
> established**. **The cascade was invisible because §6.2 tested only `unchanged` and `unreadable`,
> and never the third value.**
>
> **This is the waiver-pressure mechanism §3.3 names against the remediation lane, appearing on F1
> itself and unnamed.** A gate that fails every correctly-committing run that leaves an untracked file
> is a gate whose operators learn to waive it — which is precisely what §6.4 N2 exists to detect, and
> what makes a gate set that *looks* stricter weaker in practice.

**The decision: REPROBE, never accept.** The gate does not treat a dirty tree as a pass, and it does
not treat an unread `HEAD` as "unmoved". It re-reads:

```dart
// §8 P1 — WorkspaceHeadReader, which must be WRITTEN. It does not exist today.
final head = await headReader.read(          // Future<WorkspaceHead?>
  workingDirectory: execution.workspace.path,
  startingRevision: delta.startingRevision,
);
if (head == null) {
  return FAIL('HEAD could not be established, so no revision can be recorded; '
              'this is "I could not look", not "nothing was produced"');
}
```

`passed` **iff** `delta.isReadable && head.headMoved == true`. The re-read is unconditional and the
gate's own pass condition is stated in terms of **its** answer, so a `WorkspaceDeltaProbe`
implementation change cannot silently re-open the hole. §8 P1 carries it as a prerequisite because
there is no such reader in the tree: `GitWorkspaceInspector` reads `git rev-parse HEAD` unconditionally
(`git_workspace_inspector.dart:35`) but **throws** `GitCommandException` on failure (`:106-115`) and
returns a `GitWorkspaceInspection` whose `revision` is a `String` that cannot express "unreadable"
(`:7-15`, `:45-49`). A gate needs the three-valued answer; that type does not exist.

**Falsifies when** — each of these is a concrete input, not a category:

| Input | Result | Why it must not pass |
|---|---|---|
| HEAD equals `startingRevision`, tree clean (`WorkspaceDelta.unchanged`) | **FAIL** | nothing was produced. This is the seven-of-seven case |
| **Tree dirty, HEAD unmoved and the re-read confirms it** (`headMoved: false`) | **FAIL** | uncommitted work is not an artefact a later review can pin a revision to |
| **Tree dirty, HEAD never read, and the re-read finds `HEAD` at a new revision** (`headMoved: null` → re-read → `true`) | **PASS** | **this row is the correction.** The run *did* commit; the probe simply declined to look. Failing it is failing a correct run |
| **Tree dirty, HEAD never read, and the re-read cannot establish it** (`headMoved: null` → re-read → `null`) | **FAIL**, reason *"HEAD could not be established"* | **never** *"nothing was produced"*. `unreadable` and `unchanged` are different claims (`workspace_delta_probe.dart:8-11`) and a gate that collapses them lets a tooling fault be read as an agent that did nothing |
| `WorkspaceDelta.unreadable(reason)` | **FAIL** | *"I could not look"* must never be laundered into *"I looked and saw nothing"* — `workspace_delta_probe.dart:8-11` and `success_artifact.dart:266-281` both build on that distinction, and this gate inherits it rather than re-deciding it |
| `AgentResult.changedFiles` non-empty but HEAD unmoved | **FAIL** | the agent's claim cannot substitute for git's reading. This row is the gate's reason for existing |

**The deliberate non-goal, stated so it is not mistaken for a design choice:** the gate does **not**
accept `delta.hasChanges` (which is `dirty || moved`, `workspace_delta_probe.dart:113-114`) as a pass.
`hasChanges` is the **committer's** predicate and it is true for a dirty tree with no commit at all —
accepting it would make the gate pass on the seven-of-seven case wearing a different predicate. The
gate re-reads `HEAD` and decides on **a commit existing**, which is a stricter and more specific claim
than "something changed", and it is the claim F2 and F5 both need downstream.

---

#### **F2 — `feature-change-scope-confined`** · type `change-scope-confinement`

```dart
config: <String, dynamic>{
  'evidenceTypes': ['committed_diff_paths'],
  'ownedPathGlobs':    <List<String>>,  // REQUIRED, non-empty
  'forbiddenPathGlobs': <List<String>>,  // REQUIRED, may be empty list, may NOT be absent
  'pathSource': 'git_diff_name_only',    // label; the reader is named below
}
```

Passes **iff** every path in the enumerated set is `>=1` owned glob and **zero** forbidden globs.

> #### The reader this gate needs DOES NOT EXIST, and the artifact must name it — a correction
>
> Revision 3 of this artifact wrote `'pathSource': 'git_diff_name_only', // label; the read is a typed
> collector` and asserted that the read *"is a typed collector"* **without naming one**. **There is no
> such collector in this repository**, and the two obvious substitutes are each broken in a way that
> matters *for this gate specifically*:
>
> | Candidate | Why it is not the reader |
> |---|---|
> | `WorkspaceDelta.changedPaths` | **Truncated to 5.** `GitWorkspaceDeltaProbe` takes `paths.take(reportedPathCap)` with `reportedPathCap = 5` (`workspace_delta_probe.dart:160`, `:213-214`). The field is documented as *"May be a prefix of the full set"* (`:98-99`) because it exists to make a failure reason name something concrete. **A confinement gate that reads a prefix has no bound: the sixth path is unexamined, and the cap is a property of a failure message, not of the change.** |
> | `WorkspaceDelta.changedPaths` on a committed run | **`const []`.** `WorkspaceDelta.committed` hard-codes `changedPaths = const []` (`workspace_delta_probe.dart:61-67`, with the reasoning at `:44-60`). So on **exactly the run F1 passes** — committed, tree clean, `headMoved == true` — the confinement gate reads an **empty** path set and **passes vacuously**. That is this artifact's own §6.4 N1 rule applied to F2, and §6.2 never tested for it. |
> | `GitWorkspaceInspector.changedFiles` | Genuinely **uncapped** (`git_workspace_inspector.dart:53-75`), and it does read `HEAD` (`:35`) — but it enumerates `git diff --name-status <start>` (`:57-64`), i.e. **start-to-worktree, not `<start>..<produced>`**, and **`git diff` never lists untracked files.** `workspace_delta_probe.dart:127-133` names this exact trap: *"an implementer that creates a brand-new file and leaves it untracked reports a clean diff."* For `WorkspaceDeltaProbe` a missed untracked file causes a spurious failure; **for a confinement gate it is the opposite and worse failure — a brand-new prohibited file is invisible and the gate passes.** |
>
> **The reader to write, named precisely.** §8 **P1** specifies it:
>
> ```dart
> // packages/.../committed_diff_path_collector.dart — MUST BE WRITTEN. Does not exist.
> class CommittedDiffPathCollector {
>   Future<CommittedDiffPaths> collect({
>     required String workingDirectory,
>     required String startingRevision,
>     required String producedRevision,   // what F1's re-read established
>   });
> }
> class CommittedDiffPaths {
>   final String startingRevision;
>   final String producedRevision;
>   final List<String> paths;             // UNCAPPED, and never an empty list standing for "none"
> }
> ```
>
> `paths` is the **uncapped** union of exactly two enumerations, and the gate fails closed if either
> cannot be read:
>
> 1. `git -C <ws> --no-optional-locks diff --name-only <startingRevision>..<producedRevision>` —
>    the committed range, which is the assertion's actual subject;
> 2. `git -C <ws> --no-optional-locks ls-files --others --exclude-standard` — everything still
>    untracked in the worktree at settle time, which (2) above exists because `git diff` will never
>    report it and an untracked **new** file is exactly what a confinement gate must catch.
>
> **Neither enumeration may be truncated, sampled or capped, and a failed enumeration is a FAIL, not
> an empty list** — the empty list is the F2-on-a-committed-run hole above, and reproducing it inside
> the new reader would rebuild the defect at a second layer.

**Falsifies when** — each of these is a concrete input, not a category:

| Input | Result | Why it must not pass |
|---|---|---|
| The diff touches `packages/workflow_engine/**` while the lane's `OWNED_PATHS` named `apps/server/**` | **FAIL**, naming the offending path in the evidence row | This is the falsification of a failure `evaluator-spec.md` §4.3 records in this repository's own history: *"A prohibited-path boundary hid a regression from the lane that could have caught it."* A structural gate cannot see a path at all, so it cannot catch this; the gate that can, must |
| **The commit touches six paths, and the SIXTH is the prohibited one** | **FAIL** | **This is the row that fails under the obvious implementation.** `changedPaths` reports five and stops (`workspace_delta_probe.dart:213-214`); a gate built on it passes. Only the uncapped reader of §8 P1 fails, and only it fails for the right reason |
| **The run committed and left the tree clean** (`WorkspaceDelta.committed`) | **FAIL** if any path in `<start>..<produced>` is unowned | **the empty-list trap above.** `committed.changedPaths` is `const []` (`:66`), so the obvious reader enumerates nothing and passes vacuously |
| A brand-new prohibited file is left **untracked** | **FAIL** | `git diff` never lists untracked files; without enumeration (2) the gate cannot see it. This row is the reason the reader enumerates two sources rather than one |
| `ownedPathGlobs` is empty or absent | **FAIL at provision**, `FormatException` naming the gate | §9's requirement gap 3: `AGENTS.md`'s path-ownership map is `TBD`. A gate whose owned set is empty would fail every path, which is stricter-but-useless; a gate that treated empty as "all owned" would be a no-op. Neither is acceptable, so it is a declared refusal |

**A deliberate non-goal, stated so it is not mistaken for an omission:** this gate checks **confinement,
not correctness**. It does not assert the change was *right*. That is F4's job and engineering
review's.

---

#### **F3 and F4, MERGED — `feature-declared-checks-executed`** · type `declared-validation-outcome`

> ##### F3 WAS GREEN TODAY. It was not red by construction, and it is not a distinct falsifier.
>
> Revision 3 of this artifact carried F3 as a separate gate, type `platform-verified-evidence`, and
> asserted in a block quotation: **"F3 IS RED TODAY, AND THAT IS ITS CORRECT STATE"** and **"F3
> therefore cannot be made green by anything this lane designs."**
>
> **Both are false, and the way they are false is the whole finding.** `ExecutionCoordinator` carries
> **one** `verificationPlan` for **all** roles (`execution_coordinator.dart:151`, `:162`), and the one
> composed in production is `triageVerificationPlan` — `git rev-parse --verify 'HEAD^{commit}'`,
> `checkName: 'git_worktree_head'` — attached to the single coordinator every role drives
> (`server.dart:1578-1581`, `:1638`). **So an implementation execution already writes a
> `PlatformVerification` row today**, and it satisfies every one of the four conditions F3 named —
> three of them unconditionally, and the fourth by construction:
>
> | F3's condition | Can it fail in production? | Established at |
> |---|---|---|
> | `readVerifications(executionId)` is non-empty | **yes**, but only when no plan is attached or the execution was already settled (`:909` guards `plan != null && !alreadySettled`) | `execution_coordinator.dart:905`, `:909` |
> | `evidenceKind == platformVerifiedEvidence` | **NO.** `PlatformVerification.evidenceKind` **defaults** to `EvidenceKind.platformVerifiedEvidence` (`platform_verification.dart:24`) and `ExecutionCoordinator` **never sets it** (`:916-930`) | `platform_verification.dart:24`; `execution_coordinator.dart:916-930` |
> | `status == AgentClaimStatus.passed` | **NO.** `git rev-parse --verify 'HEAD^{commit}'` succeeds on any checkout that has a commit, and `outcome.passed` maps straight to `passed` (`:921-923`) | `server.dart:1578-1581`; `execution_coordinator.dart:921-923` |
> | `requireBoundToExecution` | **NO — unconstructible.** The binding is not a gate predicate at all: `readVerifications` filters by `executionId` in the query itself, so a row "bound to another execution" **cannot be returned by this reader**. | `postgres_execution_store.dart:331-339` (`WHERE "executionId" = @executionId`); `in_memory_execution_store.dart:109-115` |
>
> **This is not a reading of the code — it is the existing test suite.** `execution_coordinator_test.dart`
> builds an `AgentExecutionRequest` with **`role: AgentRole.implementer`** (`:93`), asserts
> `readVerifications('exec-1')` has length 1 with `status == passed` and `evidenceKind ==
> EvidenceKind.platformVerifiedEvidence` (`:125-131`), and **the file passes today**:
> `00:02 +9: All tests passed!` **F3's pass condition is satisfied by every implementation execution in
> this repository, before the gate exists.** Two of its four falsification rows — "every row is
> `agentClaimedEvidence`" and "the only rows belong to a different `executionId`" — name inputs that
> **production cannot produce**, and a gate with unreachable falsifiers is a gate that cannot fail.
>
> **The consequence for the artifact's own discipline:** F3 fails this document's **§6.4 N1**
> differential non-vacuity rule as originally written, and it did so while the artifact asserted the
> opposite in a block quotation. §7.2's finding about the guard filtering from `gateResults` rather
> than `qaContract.gates` is a **strictly smaller** version of the same shape — *a required thing that
> is checked against the wrong collection* — and the artifact found it in the guard while missing it
> in its own gate.

**The merge, and why merging rather than repairing.** Three dispositions were available: give F3 a
discriminator that has no default; merge it into F4; or keep it and mark `evidenceKind`
non-discriminating. **Merging is chosen, for a reason that is visible in the tree rather than
preferred:**

1. **A discriminator that has no default does not exist.** The candidate would be "the row must have
   had `evidenceKind` *explicitly* set". `PlatformVerification` is `@JsonSerializable` with
   `includeIfNull: false` and `evidenceKind` is **non-nullable**, so it is **always** serialized
   (`platform_verification.g.dart`, and the DB column `NOT NULL`) — a persisted row is
   **indistinguishable** from one that took the default. **The information the discriminator would
   read was never written.**
2. **`requireBoundToExecution` is a property of the reader, not of the gate.** `readVerifications`
   already filters (table above). Writing it as gate config would assert something the gate does not
   do.
3. **What remains after removing both is "≥1 platform-written row exists, and it passed" — which is
   F4's substrate, not a second gate.** Two gates over one row set, where one has no reachable
   falsifier, is one gate plus a constant. **So `evidenceKind` survives as a defensive invariant
   inside the merged gate and stops being counted as an earned assertion** (§2.1's correction).

```dart
config: <String, dynamic>{
  'evidenceTypes': ['platform_verification'],
  'requireCheckNames':   <List<String>>,  // REQUIRED, non-empty
  'requireCommands':     <Map<String, String>>, // checkName -> EXACT command string; REQUIRED
  'requireStatus': 'passed',
  'commandMatchIsExact': true,           // not substring, not token overlap

  // ---- DEFENSIVE INVARIANTS, NOT DISCRIMINATORS. See the three facts above. ----------------
  // requireEvidenceKind: 'platformVerifiedEvidence'   // enforced; NON-DISCRIMINATING in production
  // requireStatusOfEveryOtherRow: 'passed'           // enforced; refuses a failed sibling row
  // boundToExecution: STRUCTURAL, not configurable — `readVerifications(executionId)` filters
  //                    server-side, so "a row from another execution" is unconstructible.
}
```

Passes **iff** every entry of `requireCheckNames` has a row whose `checkName` matches **and** whose
`command` **string-equals** the declared command **and** whose `status` is `passed` **and** whose
`evidenceKind` is `platformVerifiedEvidence`.

**Falsifies when**

| Input | Result | Why it must not pass | Discriminating in production today? |
|---|---|---|---|
| A row named `dart_test` whose `command` is `git rev-parse --verify 'HEAD^{commit}'` | **FAIL** | **This is the live shape, not a hypothetical one.** `triageVerificationPlan` is attached to every role's coordinator (`server.dart:1638`), so the row the coordinator actually writes carries the liveness probe's command. Matching on `checkName` alone would let a liveness probe satisfy a test declaration, and `WorkspaceVerifier` sets `checkName` from the coordinator's plan, not from what the command proves (`execution_coordinator.dart:920`) | **YES — this is the row that holds the feature lane closed.** It fires on every implementation execution today |
| One of three declared checks has no row | **FAIL** | completeness, not best-effort | **YES** |
| All three ran; one reports `failed` | **FAIL** | | **YES** |
| Every other property matches a declared check but `evidenceKind` is `agentClaimedEvidence` | **FAIL** | the substitution `AGENTS.md` §12 forbids: a producer's own claim *"never unlocks the approval gate"* | **NO — production never writes it** (the default, `platform_verification.dart:24`). Retained as an invariant and tested; **not counted toward §6.4 N1** |
| A `commandMatchIsExact: false` implementation is written | — | the config key exists so the **strictness is a declared property**, and §6 requires a test that fails when a gate is implemented loosely against it | n/a — a property of the implementation, not an input |

> ##### What this gate is, stated so it cannot be re-read as the thing it is not
>
> **F4 alone holds the feature lane closed today, and it is red for one reason: the only verification
> row that exists carries the command `git rev-parse --verify 'HEAD^{commit}'`, which does not
> string-equal any command a product would declare.** F1 is red today too, on a different and
> independent ground — no commit at all is what it refuses. **F3 held the lane closed by nothing.**
>
> **The refusal of `AgentResult.claimedChecks` is unchanged and is not what was wrong.** Reading the
> agent's own claim is refused because the operator rejected it and `AGENTS.md` §12 forbids a
> producer satisfying an independence guard. What was wrong was only the *reason* F3 was given for
> being red: it was not red, and building a gate set on that misreading would have left the feature
> lane's closure resting on a constant.
>
> **F4 turns green in the same commit that decides `OD-6`** — a role-scoped implementation
> `VerificationPlan` whose commands the product declares. That remains a named gap (§9 gap 1), not an
> engineering problem this design can close.

---

#### **F5 — `feature-review-bound-to-revision`** · type `revision-identity-match`

```dart
config: <String, dynamic>{
  'evidenceTypes': ['review_verdict', 'committed_revision'],
  'reviewedRevisionField': 'endingRevision',
  'producedRevisionField': 'producedRevision',   // what F1's RE-READ established (§8 P1)
  'requireStringEquality': true,
  'nullRevisionIsFailure': true,
}
```

> **`producedRevision` is a hard dependency, and F1's correction is what makes it obtainable.**
> Revision 3 specified this field as *"what F1 recorded"* while F1 recorded nothing at all whenever
> `headMoved` was `null` — i.e. on every run that committed and left an untracked file (F1's
> correction, above). **Under that arrangement F5's `nullRevisionIsFailure` fired on a null that had
> never been established, on correct runs, for a reason no test covered.** §8 **P1** therefore makes
> the re-read a **prerequisite of F5 as well as of F1**: a `producedRevision` F5 can rely on is one a
> `WorkspaceHeadReader` actually read. **F5 must not be implemented before P1.**

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

The remediation lane reuses **existing declared types** rather than inventing them. Its `gateId`s are
the **same declarations the triage contract already carries** (`lane_g_triage_qa_contract.dart:172-189`,
`:196-208`), which means **a remediation contract and a triage contract that declare them agree by
construction rather than by convention.**

| # | `gateId` | `type` | `required` | What it asserts | Type status |
|---|---|---|---|---|---|
| **R1** | `remediation-defect-resolvable` | `triage-defect-existence` | `true` | The cited defect resolves | **NEW** |
| **R2** | `triage-evidence-grounded` | `triage-evidence-grounding` | `true` | Every cited evidence id exists **and belongs to that defect** | **EXISTING, declared, unregistered** |
| **R3** | **`triage-classification-admitted`** | `triage-classification-structure` | `true` | The structured result is well-formed | **EXISTING, declared, unregistered** — **structural; see §5** |

> #### R3's `gateId` — which id the remediation contract carries, and the one rule that follows
>
> Revision 3 of this artifact gave R3 the `gateId` **`triage-classification-admitted`**
> (`lane_g_triage_qa_contract.dart:172-173`) while §5 retains **`intake-structured-result-admitted`**
> (`shipit-platform.product-manifest.json:45`) — **two `required: true` `gateId`s for one `type`**,
> and it never said which contract carried which.
>
> **The decision: the remediation contract carries `triage-classification-admitted`.** §5 retains
> `intake-structured-result-admitted` in **the shipped product manifest's feature contract**, which
> is a different contract. **They never meet in one contract** — and the following rule is what makes
> that true rather than accidental:
>
> > **MUTUAL EXCLUSION (normative). No `QAContract` may declare both `triage-classification-admitted`
> > and `intake-structured-result-admitted`.** They are the same `type`, the same `evidenceTypes`
> > (`triage_structured_result`), and the same assertion over the same document — the manifest says so
> > in its own words: *"Both gates make the SAME assertion about the SAME document … so an evaluator
> > registered once for that type evaluates both"* (`shipit-platform.product-manifest.json:83`). One
> > evaluator, one assertion, one result — **two gate ids would demand two results for one structural
> > check**, because §7.4 C1 step 3 requires a result for **every** `required` `gateId`.
>
> **What the collision would actually cost, so the rule is not read as pedantry.** It is not a
> correctness hole — both results would carry the same verdict. It is three concrete defects:
> `optionalGateFailuresAllowed` is derived by counting non-required gates
> (`product_qa_contract.dart:128`) and a duplicated id shifts nothing there but does double the
> failure surface a waiver can be taken against; `QAPassCriteria.waiverRequiresHumanDecision` means an
> operator sees **two** gate ids to waive for **one** defect; and `FOLLOW_UPS.md`'s whole ledger is
> keyed by gate id, so a defect filed against either id is invisible to anyone reading the other.
>
> **§5 is aligned to this decision below.** The `gateId` `intake-structured-result-admitted` is the
> one the **shipped manifest** keeps; `triage-classification-admitted` is the one the **remediation
> contract** declares; and §7.4 C1 step 3 is the mechanism that would have caught the collision if
> both had appeared.

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

> **Which `gateId` this gate carries, answered once and only once:** **`triage-classification-admitted`** —
> the declaration in `packages/qa_orchestration/lib/src/lane_g_triage_qa_contract.dart:172-188`, which
> lives **next to the type it declares** and is what §3.2's own *"reuse the existing declared type"*
> posture requires. **It is NOT `intake-structured-result-admitted`**, which is the id §5 retains and
> which stays in the **shipped product manifest's** feature contract
> (`shipit-platform.product-manifest.json:45`). The normative mutual-exclusion rule and what a
> collision would cost are in §3.2. **A remediation contract that declares `intake-structured-result-admitted`
> as well is a defect in the contract, not a stricter contract.**

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

> **CORRECTION.** Revision 3 of this artifact headed the first table *"New, requiring a `GateEvaluator`
> implementation each (**5**)"* and then listed **six** rows. The numeral was wrong **because the
> table was** — with F3 merged into F4 (§3.1), the count is **five new types** and **five rows**, and
> the arithmetic below is shown rather than asserted so a reviewer can check it in one pass:
> **7 evaluators in total = 5 new types (F1, F2, F4, F5, R1) + 2 declared-but-unregistered (R2, R3).**

**New, requiring a `GateEvaluator` implementation each (5):**

| `type` | Gate | Falsifies on |
|---|---|---|
| `implementation-artifact-provenance` | F1 | HEAD unmoved, **or delta unreadable, or HEAD unreadable and the re-read could not establish it** |
| `change-scope-confinement` | F2 | a changed path outside `ownedPathGlobs`, or inside `forbiddenPathGlobs` — **enumerated uncapped, including untracked** |
| `declared-validation-outcome` | F4 *(absorbs former F3)* | `checkName` matches but `command` does not; **or** a declared check is missing; **or** a row reports `failed` |
| `revision-identity-match` | F5 | reviewed revision ≠ produced revision; or `null`/empty |
| `triage-defect-existence` | R1 | cited defect does not resolve |

**The type `platform-verified-evidence` is GONE from this list.** Revision 3 named it as a sixth new
type. It is withdrawn: `GateRegistry.register` keys by the `type` string
(`gate_registry.dart:9-17`), so the single evaluator registered under `declared-validation-outcome`
serves F4 — **and its `evidenceKind` check survives there as a defensive invariant, documented as
non-discriminating (§3.1).** A sixth type would have been a second evaluator over the same rows for
no additional assertion.

**Existing, declared but unregistered — needs only an evaluator (2):**
`triage-classification-structure` (R3, `gateId` `triage-classification-admitted`),
`triage-evidence-grounding` (R2).

**To be DE-REGISTERED (4):** `static-analysis`, `unit-tests`, `security-scan`, `performance` — per
`evaluator-spec.md` §5.2 option 2, which is the only option §5.2 leaves open. Each currently returns a
fabricated `PASSING` with an audit trail.

**No change to any type in `platform_contracts`.** §1.1 establishes there is no enum to extend. This
is the single largest reduction in estimated effort between the dispatch's framing and the tree.

---

## 5. Migration from `intake-structured-result-admitted` — **RETAIN, as a structural precondition**

**Decision: retain it, unchanged, `required: true`, alongside the substantive gates. Do not replace it
and do not weaken it.**

> #### Which contract it stays in — the alignment §3.2 owes this section
>
> Revision 3 of this artifact retained `intake-structured-result-admitted` **here** and gave R3 the
> `gateId` `triage-classification-admitted` **there**, with nothing joining the two. **This section is
> that join.**
>
> `intake-structured-result-admitted` is retained **in the shipped product manifest's feature
> contract** (`shipit-platform.product-manifest.json:42-47`), exactly as shipped. It is **not** added to
> the remediation contract, which carries `triage-classification-admitted` for the same type
> (§3.2). **The two ids never appear in one `QAContract`** — that is the mutual-exclusion rule, and
> §7.4 C1 step 3 is what would fail loudly if a future manifest declared both.
>
> **Nothing in the shipped manifest is edited by this design.** `shipit-platform.product-manifest.json`
> is `PROHIBITED_PATHS` for this lane, and §8's **M1** step is where a manifest change would be made —
> by an implementer, under review, and **only** to add the §3.1 feature gate set.

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
fabricated pass §5.1 describes. §6.2 states **sixteen required tests across the seven gates** —
**4** for F1, **3** for F2, **3** for F4, **2** for F5, **1** for R1, **2** for R2, **1** for R3
(**4+3+3+2+1+2+1 = 16**) — and §6.4 adds two assertions that are not per-gate.

> **CORRECTION, and the hazard it removes.** Revision 3 claimed *"fourteen required tests across the
> eight gates — two per feature gate, three for R2"* and **§6.2 listed thirteen rows** (F2=1, not 2;
> R2=2, not 3; feature total 9, not 10). **The count was wrong in three directions and the prose was
> wrong in a fourth** ("three for R2" where the table's third R2 row is the *zero-citation* row
> grouped under the *belonging* row). **A count an implementer can satisfy by padding is a live
> hazard**: the implementer would add rows until the number matched, which is the opposite of writing
> a test that fails when the gate is bypassed. **The count below is derived by addition and shown as
> an addition.** It changed for a second reason this pass: F3 is merged into F4, B5 added two F1 rows
> for the two branches of the re-read decision, and B2 added two F2 rows for the truncation and the
> empty-list cases. **Corrections that add rows are additions to the discipline, never subtractions
> from it.**

The rule V3 and V4 carry is inherited verbatim: **"V3 and V4 are the two that do not exist in any
form today and that a naive wiring would pass."** F2's two new rows, R2's *belonging* row, and F4's
command-identity row are that same class here — **each passes under the obvious implementation and
fails only under the one that reads the property.**

### 6.2 The required test per gate

| Gate | The test that must exist | It fails when |
|---|---|---|
| **F1** | An execution with `headRevision == startingRevision` and a clean tree | `WorkspaceDelta.hasChanges` is read instead of the re-read's `headMoved` |
| **F1** | An execution with `WorkspaceDelta.unreadable(...)` | `unreadable` is coerced to `missing` |
| **F1** | **A dirty tree with `headMoved == null`, where the re-read finds HEAD at a new revision** | the gate fails a correct committed run — this is the B5 pass branch, and an implementation reading `headMoved` without re-reading gets it wrong |
| **F1** | **A dirty tree with `headMoved == null`, where the re-read cannot establish HEAD** | the failure reason says *"nothing was produced"* instead of *"HEAD could not be established"* |
| **F2** | A diff touching one forbidden path | the glob list is read from the contract but never matched |
| **F2** | **A commit touching six paths, where the SIXTH is the forbidden one** | the reader is `WorkspaceDelta.changedPaths`, which reports five (`workspace_delta_probe.dart:213-214`) |
| **F2** | **A committed-and-clean run (`WorkspaceDelta.committed`) whose `changedPaths` is `const []`** | the empty list is read as "no path violated confinement" and the gate passes vacuously (`:66`) |
| **F4** | `checkName: 'dart_test'` with `command: 'git rev-parse …'` | `commandMatchIsExact` is implemented as a substring test |
| **F4** | Two of three declared checks present | the loop short-circuits on the first match |
| **F4** | **Every other property matching a declared check, with `evidenceKind: agentClaimedEvidence`** | the merged gate's defensive invariant is dropped. **Production never writes this input** (`platform_verification.dart:24` defaults it), so the test's purpose is stated: it pins the invariant for the day a claim-producing producer exists, and it is **not** counted as production-discriminating |
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
   artifact set: `evaluator-spec.md`'s `:690-696` resolved to a *different edge* for seven correction
   passes because a range that resolves to the wrong thing is harder to catch than one that resolves
   to nothing. **It is now corrected in place (§1.2), and it is recorded as an open finding in
   `FOLLOW_UPS.md` so the class, not just the instance, is tracked.** **Open every citation you carry.**
6. **A falsification row must name an input production can produce.** §6.4 N1a. Revision 3 of this
   artifact specified two rows no production path could emit and called the gate red; **open every
   falsification row the way you would open a citation.**

### 6.4 Two more assertions that belong with the seven gates

> **CORRECTION.** Revision 3 headed this *"the eight gates"*. There are **seven** (§3.1 merged F3 into
> F4). **And this artifact failed its own N1 before this correction** — F3's `evidenceKind` condition
> had no production input that could falsify it, which is the failure N1 exists to catch. N1 is
> applied to **each registered type**, and it is now applied to **each falsification row's
> reachability**, so a row that no production path can produce is recorded as non-discriminating
> rather than counted.

| # | Assertion | Fails if |
|---|---|---|
| **N1** | **Differential non-vacuity.** For each registered type, **two inputs that differ must produce different verdicts.** | The evaluator's verdict is a constant. All four current evaluators fail this trivially — identical output for identical config — which is `evaluator-spec.md` §5.2's reason de-registration is the only safe option |
| **N1a** | **Production reachability, per falsification row.** Every falsification row in §3 must name an input **a production path can actually produce.** | A row that no production writer can emit is counted as a falsifier when it is decoration. **The former F3 failed this on two of its four rows** — `agentClaimedEvidence` is unreachable while `PlatformVerification.evidenceKind` defaults to `platformVerifiedEvidence` (`platform_verification.dart:24`), and a row "bound to another `executionId`" is unconstructible through `readVerifications`, which filters server-side |
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
   > **This step is also what makes §3.2's mutual-exclusion rule mechanical.** A contract declaring
   > both `triage-classification-admitted` and `intake-structured-result-admitted` for one type would
   > require **two** results for one structural check; with the fix, the missing second result is a
   > **named guard failure**, not a silent duplication. §3.2 forbids the pair at the contract level;
   > **this step is what fails loudly if the rule is violated anyway.**
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
introduces are prefixed **`P`** (prerequisite reader), **`G`** (guard), **`E`** (evaluator) and
**`M`** (manifest), so no new step can collide with a slice number an implementer has already read in
the approved spec.

> **`P1` IS NEW IN THIS CORRECTION, and it is a named production finding rather than a design edit.**
> Revision 3 of this artifact assumed two reads that **do not exist in this repository** and named
> neither: F2's *"the read is a typed collector"*, and F1's implicit need for an established
> `headRevision` to hand F5. **This lane writes no production code**, so `P1` is a **specification of
> work an implementer must do**, listed as a prerequisite here because **three of the seven gates
> cannot be implemented without it** and because an implementer who discovers that mid-way will reach
> for the broken substitutes — `WorkspaceDelta.changedPaths` (capped at 5, `const []` on a committed
> run) and `GitWorkspaceInspector.changedFiles` (misses untracked files). **Both substitutes pass
> tests. That is why they are named here rather than left for the implementer to find.**

| Step | What | Ordering obligation |
|---|---|---|
| **3a** *(approved)* | De-register the four fabricating evaluators | Before anything is wired |
| **G1** *(new)* | **C1 + C2 (§7.4)** and the seven-row guard test | **Before any evaluator is registered.** A guard carrying the subset hole makes every later gate optional |
| **P1** *(new — this correction)* | **Two readers, both of which must be WRITTEN. Neither exists today.** ① **`WorkspaceHeadReader`** — `Future<WorkspaceHead?> read({workingDirectory, startingRevision})` running `git rev-parse HEAD` **unconditionally**, returning `{headRevision, headMoved}` or `null` for "could not establish". ② **`CommittedDiffPathCollector`** — `Future<CommittedDiffPaths> collect({workingDirectory, startingRevision, producedRevision})` returning the **uncapped** union of `git diff --name-only <start>..<produced>` and `git ls-files --others --exclude-standard`, `null`-forcing a FAIL on either enumeration (§3.1 F2) | **Before E2 and before F5 is implemented.** F1's re-read decision (§3.1 F1) *is* ①; F2's assertion *is* ②; F5's `producedRevision` comes from ①. **A gate built before P1 will be built on a broken substitute and will pass vacuously on committed runs** |
| **E1** *(new)* | The two declared triage evaluators: `triage-classification-structure`, `triage-evidence-grounding` | Same as approved **3b**, which E1 completes — E1 does not replace or renumber it |
| **E2** *(new)* | `implementation-artifact-provenance` (F1), `change-scope-confinement` (F2) | **After P1.** Each lands **with** its evaluator, never ahead of it |
| **E3** *(new)* | **`declared-validation-outcome` (F4, merged — `platform-verified-evidence` is withdrawn)**, `revision-identity-match` (F5), `triage-defect-existence` (R1) | **F5 after P1** (its `producedRevision` is ①'s output). Each lands with its evaluator |
| **3c** *(approved)* | The `qaInProgress` drain, widened to include the `reviewApproved -> qaInProgress` caller | **Last of the runtime wiring.** F-49's warning is that wiring a *producer* is what makes the hole live — and **G1 is what stops it being live** |
| **M1** *(new)* | The product manifest's feature-lane gate set (§3.1); the remediation contract's R1 (§3.2). **Not** `intake-structured-result-admitted` — §3.2's mutual-exclusion rule | Only after E1–E3, so no contract ever declares a gate with no evaluator |

**The three orderings that are obligations, not preferences:**

- **G1 precedes 3c.** Wiring the producer before the guard is closed is what turns F-49's *"trap for the
  next implementer"* into a live vacuous pass. §7.4 is four lines; the cost of doing it last is a
  production window in which `qaPassed` means nothing.
- **P1 precedes E2, and precedes F5 inside E3.** **This is new, and it is a correction of an ordering
  the previous revision could not state because it did not know the readers were missing.** F1
  without ① fails every committed run that leaves an untracked file (§3.1 F1); F2 without ② passes
  vacuously on exactly the runs F1 passes (§3.1 F2); F5 without ① compares against a `producedRevision`
  that is `null` on those same runs. **Three gates, one missing prerequisite.**
- **E1–E3 precede 3c.** `QAOrchestration.evaluate` returns `notExecuted` for an unregistered type
  (`qa_orchestration.dart:19-31`), which `_isGateSatisfied` treats as unsatisfied
  (`guard_conditions.dart:299-303`) — so this ordering makes the drain fail **closed and honestly**,
  which is `evaluator-spec.md` §6's `PARTIALLY ENFORCED`, not §5.1's fabricated `PASSING`.

**`qaPassed` stays closed until E1–E3 and M1 land, and — for the feature lane — until a role-scoped
implementation `VerificationPlan` exists** (`OD-6`, §9 gap 1). That is `92d567e3`'s accepted cost,
restated: items accumulate at `review_approved`. **No step above is weakened to shorten the queue, and
the queue is not a reason to shorten a step.**

> #### What this revision's correction changes about that sentence — the honest version
>
> Revision 3 said the feature lane's `qaPassed` stayed closed *"until E1–E3 and M1 land, and — for
> the feature lane — until a role-scoped implementation `VerificationPlan` exists"*, and attributed the
> feature lane's closure jointly to F3 **and** F4. **After the correction the attribution is exact:**
>
> - **F4 alone holds the feature lane closed today**, and it is red for one reason — the only
>   verification row that exists carries `git rev-parse --verify 'HEAD^{commit}'`, which does not
>   string-equal any command a product would declare (§3.1).
> - **F3 held it closed by nothing.** It was green before it existed (§3.1).
> - **F1 is independently red**, on a ground unrelated to `OD-6`: it refuses a run with no commit.
> - **F2 is red today** for want of a reader (P1), which is a build gap rather than a runtime verdict.
>
> **`OD-6` is therefore still a real gap — F4 cannot go green without it — but it is now the gap behind
> ONE gate rather than two, and the sentence above no longer over-credits a gate that was a constant.**
> The accepted cost is unchanged: items accumulate at `review_approved`.

---

## 9. Traceability

**Requirements covered**

| Requirement | Where |
|---|---|
| Machine-checkable meaning of "QA passed", per lane | §2.1 (F — **four** items), §2.2 (R) |
| Different risk per lane, and why | §2.2's table |
| Concrete gate set with `gateId`/`type`/`required`/`config` | §3.1 (F1, F2, F4, F5), §3.2 (R1–R3) |
| Every gate falsifiable, with the failing input | §3.1/§3.2 per-gate tables; §6.2 (16 rows) |
| **Every falsification row reachable in production** | §6.4 **N1a** — added by this correction; the former F3 failed it |
| Existing vs. new gate types, explicitly | §1.3, §4 (**5 new + 2 declared-unregistered**) |
| Falsification tests + non-vacuity discipline (F-85) | §6 |
| The vacuous-pass hole: closure or proof it cannot fire | §7 — **it closes**; C1 step 3 |
| Migration from the structural gate | §5 — **retain**, with three enforcement mechanisms |
| **Which `gateId` each structural assertion carries, and the rule preventing two for one type** | §3.2's mutual exclusion; §5's alignment; §7.4 C1 step 3 |
| **The readers the gates depend on, named and ordered** | §8 **P1** — added by this correction |
| What remains undecidable | §10 |
| A gate a structurally-valid-but-empty payload cannot pass | §2 (R3's limit), §5, §6.4 N1 |

**Requirements gaps** — carried, not closed

1. **`OD-6`, the role-scoped implementation `VerificationPlan`.** **F4 is red until it is decided, and
   F4 alone.** `server.dart` reserves it as an architecture decision (`server.dart:1621-1638`) and
   declines to make it. **This is still the gap that most limits what this design can deliver** —
   but revision 3 of this artifact said *"F3 and F4 are red until it is decided"*, and **that was
   wrong: F3 was green.** One gate, not two, is blocked on it, and the other three feature gates
   (F1, F2, F5) do not depend on it at all.
2. **The `WorkerExecution` lookup key** for F5 (§3.1 F5).
3. **The item's declared owned/forbidden path globs.** F2's config cannot be filled from the
   repository: `AGENTS.md`'s `Product-specific policy → Path ownership map` is `TBD`. **F2 ships with
   the config keys and a `FormatException` on an empty `ownedPathGlobs`, not with a guessed glob.**
4. **`requiredCheckNames` / `requireCommands` per product** — same reason. The gate needs the product
   to say what "validated" means; the platform cannot infer it.
5. **NEW IN THIS CORRECTION — where `WorkspaceHeadReader` and `CommittedDiffPathCollector` live.**
   §8 **P1** specifies both readers' shapes and orders them, and **this lane writes no production
   code**, so the package placement, the error type, and whether they belong beside
   `WorkspaceDeltaProbe` or in `worker_runtime` beside `GitWorkspaceInspector` are **not decided
   here**. **Three of the seven gates cannot be implemented until this is.** Recorded as gap 5 rather
   than assumed, because the two existing readers live in **different packages** and neither shape
   fits.

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
   `server.dart:1621-1638` reserves this explicitly and declines to make it, naming the two options.
   **It is the single decision that unblocks F4** (§3.1). *Revision 3 said "F3 and F4" — corrected:
   F3 was green (§3.1), so `OD-6` blocks one gate, not two.*
5. **Whether the remediation contract is a separate contract or the triage contract with R1 and R3
   appended.** §3.2 reuses `triage-evidence-grounding`'s declaration; if the two contracts are the same
   row, adding R1 and R3 changes `optionalGateFailuresAllowed`'s derivation
   (`product_qa_contract.dart:128-140`). Not determined from the tree.
6. **NEW IN THIS CORRECTION — the package and shape of the two readers of §8 P1.** Both readers are
   fully specified at the call site (§3.1 F1, F2). **Which package owns them is not:** `WorkspaceDeltaProbe`
   is in `packages/execution_coordinator/lib/src/coordinator/` and `GitWorkspaceInspector` is in
   `packages/worker_runtime/lib/src/workspace/`, and the gate evaluation path would have to reach
   across both. Not decided here, because deciding it is production placement and this lane owns no
   production path. Recorded rather than guessed for the same reason §10.1 refuses to invent a
   validation command.
7. **NEW IN THIS CORRECTION — whether `evidenceTypes` should become mandatory.** §3.0 rule 2's
   correction establishes that an absent key yields `[]` silently
   (`product_qa_contract.dart:169-171`). **That is a live, tested, documented behaviour of a
   governed provisioner**, and it is the kind of gap that lets a gate declare no evidence and pass a
   shape check. **This artifact does not change it** — the provisioner is production code and out of
   this lane's scope — but §3.0's gates all declare the key, and the question of whether the platform
   should *require* it is recorded here rather than silently relied upon.

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

### 11.1 Revision 3 — the authoring lane (`design-SUBSTANTIVE-QA-GATES`, base `9300eea`)

Recorded in `design/qa-contracts-feature-remediation/design-revision-metadata.yaml` at the key
`revision_3_substantive_qa_gates`, additive only, touching no existing key's value. Per
`DESIGN_GOVERNANCE.md:92-99` the risk level is:

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

### 11.2 Revision 3a — this correction (`correct-DESIGN-REVIEW-3`, base `01b9fae`)

**Independent design review of revision 3 returned `DESIGN_REVIEW_CHANGES_REQUIRED`,
`CORRECTION_REQUIRED: YES`, `HUMAN_DECISION_REQUIRED: NO`, risk level 3 agreed.** This pass is that
correction. Its entry is appended to `design-revision-metadata.yaml` at the key
`revision_3a_correction_design_review_3`, **append-only, verified by byte-prefix** — never by diff,
because the original file ended without a trailing newline and a diff reports that final line as
removed-and-re-added.

**Risk level is UNCHANGED at 3, and the correction does not lower it.** It removes a gate that was not
a gate, and that is a **reduction in what the artifact claims**, not a reduction in what it governs:
the guard closure (G1), the vacuous-pass fix (§7), the retention decision (§5) and the four
de-registrations are untouched, and `qaPassed` remains held closed by F1 and F4.

**The reviewer's confirmations were not rebuilt.** The append-only property, §7's C1/C2, the
risk-asymmetry argument, the four de-registered evaluators' fabrication, `QAGateSpec.type` as an
unvalidated `String`, `OD-6` being load-bearing, the path-ownership map and validation commands being
required-but-unfilled, and F5's undecidable lookup key were each verified correct and **carried
forward unchanged**. §7 in particular is byte-for-byte unchanged except for the addition of one
cross-reference note to §3.2's mutual-exclusion rule at C1 step 3.

**What this pass changed, in the reviewer's order** — B1 F3 green-today and merged into F4; B2 the
named, uncapped `CommittedDiffPathCollector` plus §8 P1 and two new F2 tests; B3 §3.0 rule 2's
absent-key behaviour, and rule 4 as it depended on that; B4 R3's `gateId` and the mutual-exclusion
rule; B5 F1's `headMoved == null` re-read decision and two new F1 tests; B6 `evaluator-spec.md`'s and
`FOLLOW_UPS.md`'s citations corrected in place; MEDIUM §6.1's count (13 → 16, by addition); LOW §4's
heading numeral.

**The one finding that changed the artifact's shape rather than its wording is B1.** Everything else
was a wrong statement attached to a right design. B1 was a right design attached to a wrong premise —
*"the gate is red"* — which is why it survived two independent reads: every citation in the block was
true, and the conclusion drawn from them was false. **The correction adds §6.4 N1a so that class of
error has a name and a test.**

**No production change was made.** §7's guard fix and §8 P1's two readers are **named as findings**,
not implemented — `apps/**` and `packages/**` are `PROHIBITED_PATHS`. **No docker, no compose, no
psql.** `packages/**` is unchanged, so `dart analyze` has nothing to be evidence about; the two test
files this pass ran (`execution_coordinator_test.dart`, `product_qa_contract_test.dart`) were run from
their own package roots and **both reported `All tests passed!`**.

**This lane approves nothing.** Independent focused re-review is next; a reviewer may refute B1's and
B2's corrected claims directly from the tree, and is expected to.