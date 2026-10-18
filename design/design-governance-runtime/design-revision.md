# Design Revision 1 — Design Governance Runtime

**Revision ID:** `db7f8a05-13cb-4bcb-b269-5c23b68552f5`
**Brief ID:** `aabceaca-0d1f-492c-837c-2068a2ea9ed9`
**Revision number:** 1
**Status:** `DRAFT` → independent design review required. **Not approved. Not implemented. Not verified.**
**Authoring lane:** `design-DESIGN-GOVERNANCE-RUNTIME` (design-agent)
**Base SHA:** `b95bffd5f23f1322caf7ae086b35cccf78262790`
**Risk level:** **3 — Major Workflow Change.** `HUMAN_DECISION_REQUIRED` at Gate D4. **Open.**

> **A DESIGN IS NOT A VERIFICATION.** Everything below is derived by reading the tree at `b95bffd`.
> No Dart file was changed, so no analyzer run, no test run and no runtime evidence exists, and none is
> claimed. `READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES` is a claim about *this artifact's readiness to be
> reviewed*, and about nothing else. Per `aef-design-workflow` §4–§5, this lane never approves its own
> work.

---

## 0. Ownership

| | |
|---|---|
| `OWNED_PATHS` | the four files in `design/design-governance-runtime/` — this file, `design-revision-metadata.yaml`, `design-brief.md`, `design-brief-metadata.yaml` |
| `READ_ONLY_PATHS` | `apps/**`, `packages/**`, `docker/**`, `docs/adr/**`, `docs/checkpoints/**`, `docs/engineering/**`, `design/qa-contracts-feature-remediation/**`, `design/capability-parity/**` |
| `PROHIBITED_PATHS` | all production source; all test source; `docker/**`; `docs/engineering/FOLLOW_UPS.md`; `design/qa-contracts-feature-remediation/**` |

No production code, no test code, no docker, no psql, no mutation of any path outside `OWNED_PATHS`.
No live work-item, defect, or job id appears in this artifact.

---

## 1. What exists, and the precise gap

Six gaps, each with the file and line that proves it. **The dispatch's framing ("implemented nowhere")
is corrected in the brief §1.1; this table is the corrected version, and the ordering below is the
implementation ordering.**

| # | Gap | Proof |
|---|---|---|
| **G-A** | **No production scheduler is mounted on either design definition.** | `apps/server/lib/server.dart` constructs exactly three `Scheduler`s — `sched-triage` (`:485`), `sched-review` (`:533`), `sched-impl` (`:716`). `designRevisionDefinition` / `designReviewDefinition` are referenced in `apps/server/lib` **only** in comments. The definitions, their dedupe/instruction/request builders, and an e2e test exist; **nothing runs them in a server process.** |
| **G-B** | **No producer writes a `DesignRevision`.** | `saveDesignRevision` is defined (`postgres_design_governance_store.dart:77`) and called only from `packages/store_contract_tests/`. No non-test caller exists. Same for `saveDesignReviewResult` (`:269`). The tables, stores and contract suite are real; **the writer is absent.** |
| **G-C** | **Nothing raises `designApproval`.** | `HumanDecisionType.designApproval` appears in `platform_contracts` (enum) and `workflow_engine` (edges + routing). **Zero occurrences in `apps/`.** So `designInReview → waitingForHumanDecision` is callerless — the same class as `FOLLOW_UPS.md` F-95 (`reviewApproved → qaInProgress`, still callerless), and the dispatch is right to name that precedent. |
| **G-D** | **No `design_contract` table and no `DesignContractStore`.** | `DesignContract` and `DesignContractStatus` exist in `platform_contracts`. A repository search of `apps/server/migrations` for `design_contract` returns **nothing**. So `designContractExists()` can only be satisfied by a caller-supplied `context['designContractId']`, which `DurableWorkflowEngine.transition` **discards** — it is not persisted. This is precisely the fabrication lane E refused. |
| **G-E** | **Independence is unenforced in practice.** | `designReviewRequest` reads `item.metadata?['designerExecutionId']` (`scheduler.dart:3337`) and `designReviewDedupeKey` reads `item.metadata?['designRevisionId']` (`:3291`). **No production writer of either key exists.** Absent `designerExecutionId`, `excludedExecutionIds` is `const []` — the reviewer is **free to run in the designer's execution**, which is the one thing checkpoint 003 §7.1 calls a hard rule. Absent `designRevisionId`, the key collapses to `'…:unknown:design_review'`. |
| **G-F** | **`DesignRiskPolicy` does not exist anywhere.** | Repository-wide search across `apps`, `packages`, `docs` returns only ADR 0021 §6/§Consequences and checkpoint 003 §9.6 — **both specifications of it, neither an implementation**. `DesignRiskTier` exists. There is no type, no store, no table, no row. ADR 0021's *"risk policy is data, not hard-coded"* is currently true only because there is no risk policy at all. |

### 1.1 And the defect that is not on this list

**G-7 — the convergence defect.** `planned` is in `triageDefectDefinition.entryStates` with
`entryProbeTargets: {planned: designNotRequired}` (`triage_defect.dart:126-135`), and the scheduler is
category-blind. Lane E parks the remediation item at `planned`. **The triage scheduler therefore takes
it out to `designNotRequired`** — asserting that no design work is required — and re-dispatches it,
forever.

**This is why "build the runtime" did not fix the parked item and will not fix the next one by
mounting a scheduler.** The item never reaches `designRequired`. §4 specifies the replacement holding
state. It is listed last because it is the one an implementer would otherwise discover last.

---

## 2. The `designRevision` lane

### 2.1 The `JobDefinition` — adopted as-is

**It already exists and this design adopts it unchanged.** Inventing a new one would fork a definition
that eight test files already pin by name.

```dart
// packages/scheduler/lib/src/scheduler.dart:3255-3265 — VERBATIM, not proposed
const JobDefinition designRevisionDefinition = JobDefinition(
  jobType: JobType.designRevision,
  requiredRole: AgentRole.designAgent,
  requiredCapabilities: {
    WorkerCapability.penpotWrite,
    WorkerCapability.visualDesign,
  },
  entryStates: {WorkItemState.designRequired, WorkItemState.designRejected},
  priority: JobPriority.normal,
  maxAttempts: 3,
);
```

| Field asked for | Value | Verdict |
|---|---|---|
| `jobType` | `JobType.designRevision` (`design_revision`) | Matches checkpoint 003 §10.2. |
| `requiredRole` | `AgentRole.designAgent` | Matches. ADR 0021 §7 requires exactly this role. |
| `requiredCapabilities` | `{penpotWrite, visualDesign}` | **Diverges from checkpoint 003 §10.2, which also lists `penpotRead`.** See §2.2. |
| `entryStates` | `{designRequired, designRejected}` | Matches. `designRejected` is currently inert; §5.4 activates it. |
| `priority` | `JobPriority.normal` | Matches §10.2. |
| `maxAttempts` | `3` | **Diverges from checkpoint 003 §10.2's `2`.** See §2.3. |
| `skipWorkflowPolicyCheck` | **absent (false)** | Correct. The live probe is what stops the `designRejected` contradiction (§2.4). |

### 2.2 The `penpotRead` divergence — and why this design does **not** "fix" it

Checkpoint 003 §10.2 lists `penpotRead` as a design-agent capability. The tree omits it. Two readings:

- *The designer must read the existing design system before revising.* — true in general.
- *Therefore add the capability.* — not this design's call.

Checkpoint 003 §7.6 proposed these capabilities and was never ratified into an ADR. The shipped worker
in the e2e test carries `{linux, penpotWrite, visualDesign}` — **no `penpotRead`** — so a design job
requiring `penpotRead` would find **no eligible worker** and silently never dispatch. Adding the
capability without a worker carrying it converts a running lane into a silent one. **Left unchanged;
recorded as an open product question in §7.** It is not a defect this design may repair unilaterally.

### 2.3 `maxAttempts: 3` — accepted, with its consequence named

Checkpoint 003 §10.2 says `2`; §10.4 says *"maxAttempts exhaustion → routes to a human decision, never an
unbounded agent re-run."* The tree's `3` is the only divergence, and **exhaustion behaviour is not
implemented for this lane** — nothing raises a human decision on `JobState.failed` for a design job.
Adopted at `3` (changing it is not this lane's authority) with the gap named in §9 as **D-4**.

### 2.4 Why `designRequired` **is** an entry state

Four reasons, in descending order of how much they carry:

1. **It is the only state that means what it says.** `designRequired` asserts that design work is
   routed for this item. `designNotRequired` asserts the opposite; `agentExecuting` asserts an
   execution is *already running* (and is in no definition's `entryStates` — `triage_defect.dart:86`).
   An item that genuinely needs design has exactly one honest dispatchable state, and this is it.
2. **Disjointness is what prevents a second collision.** `triageDefectDefinition.entryStates` is
   `{designNotRequired, designApproved, reviewRejected, planned}`. `designRequired` is **not** in it, so
   triage cannot take a design-remediation item once the item is at `designRequired`. The collision the
   transitions file spent so much comment closing (`:24-56`) is closed here **structurally**, not by a
   runtime check. `packages/scheduler/test/implement_feature_entry_disjointness_test.dart` and
   `triage_entry_state_drift_guard_test.dart:629` pin it.
3. **The probe makes the second entry state inert rather than wrong.** `designRejected` is listed, and
   `RunnableWorkEvaluator` asks the policy about `designRejected → agentExecuting` — **not an edge** —
   so it answers `noAction`. The definition declares a route the graph has not grown yet, and the live
   probe is what stops that declaration from reaching a coordinator (`scheduler.dart:3207-3238` records
   the five-jobs-and-five-executions incident this fixed). This design **keeps the probe on** and does
   not add `designRejected → agentExecuting`.
4. **Falsifier for the claim itself.** If `designRequired` were removed from `entryStates`, a design
   defect triaged after the runtime ships would sit at `designRequired` with no job, no dispatch, and
   no operator signal — indistinguishable, on the row, from G-A's current state. The state would still
   *name* the condition correctly while nothing acted on it. **That is the failure this entry state
   prevents**, and it is why G-A (the missing scheduler) is a blocker even though the definition
   exists.

---

## 3. What the lane must assert before a revision may be proposed

ADR 0021 §2: **divergence from approved design is itself a defect.** A rule with no detector is a wish,
so every condition below is falsifiable by construction: **each names the input that makes it FAIL.**
A condition whose failure mode cannot be stated is not a gate and is not listed here.

### 3.1 Preconditions — before `JobType.designRevision` may be enqueued

| ID | Condition | **The input that makes it FAIL** |
|---|---|---|
| **P1** | The item is at `designRequired` **and** `workItem.designContractId` is non-null **and** resolves to a real `design_contract` row — read from the **durable column**, not from transition context. | An item at `designRequired` with `designContractId == NULL`. **Reachable today**: `planned → designRequired` is guarded by `context['designContractId'] != null` and `transition` discards it, so an item can sit at `designRequired` with a null column — the exact fabrication lane E removed. P1 refuses that item. |
| **P2** | A design system revision is named, non-empty, and equals the product's declared design-system revision. | `designSystemRevision: ''` — passes a null check, names nothing. **Also:** a revision naming a *different* system revision from its `parentRevisionId` without a design-system invalidation (checkpoint 003 §8.4). `design_revision.designSystemRevision` is `NOT NULL` but an empty string is accepted by the column. |
| **P3** | The revision's scope is named. For a **correction**, `parentRevisionId` is non-null, resolves, and is the *current approved* revision for this item. | A correction with `parentRevisionId == null`; or `parentRevisionId` pointing at a `superseded` revision; or two revisions claiming the same parent (forked lineage). |
| **P4** | For a **design-remediation** item, `Defect.classification == designDefect` and the defect still resolves. | `metadata['defectId']` naming a defect that no longer exists, or one whose classification is not `designDefect`. A remediation row whose `featureRef` and `metadata['defectId']` disagree. |
| **P5** | No live `design_revision` job for this item. | Two `JobType.designRevision` jobs non-terminal for one `workItemId`. **Structurally supplied today** by `designRevisionDedupeKey` (`workItemId:jobType`) + `enqueueIfAbsent` — and **see D-1, which is that this makes the correction loop unreachable.** |
| **P6** | The item carries no unresolved `designReviewRequest` or `designApproval` decision. | An item at `designRequired` with `blockingHumanDecisionId` set and the decision `pending` — dispatching a designer over a live human gate. |

### 3.2 Postconditions — before a revision may be proposed **for review**

These are what make F1 *exit*. A lane that returns without all of them has not run.

| ID | Condition | **The input that makes it FAIL** |
|---|---|---|
| **Q1** | A `design_revision` row exists and is **read back** by id. | `saveDesignRevision` returned without throwing but `readDesignRevision(revisionId) == null`. A silent no-op write is indistinguishable from success without the read-back — the same discipline `lane_e_design_remediation_work_item.dart:318-332` already applies to QA contracts. |
| **Q2** | `designerExecutionId` equals **the execution that just ran**, and no other work item's execution. | `designerExecutionId` equal to the reviewer's execution id (independence collapsed at the root, not merely at dispatch); or carrying a stale id from a previous attempt, so the reviewer is excluded from the wrong run. |
| **Q3** | `metadata['designRevisionId']` **and** `metadata['designerExecutionId']` are written onto the work item. | Either key absent. **Failing input:** `designerExecutionId` absent ⇒ `designReviewRequest` builds `excludedExecutionIds: const []` (`scheduler.dart:3350`) ⇒ the reviewer may run **inside the designer's execution**. `designRevisionId` absent ⇒ dedupe key `'…:unknown:design_review'` ⇒ every later review of this item collides with the first. **This is G-E, and it is the difference between "independent review" being enforced and merely named.** |
| **Q4** | `status == DesignRevisionStatus.draft` and `riskTier` is set by **policy evaluation**, not asserted by the designer. | `riskTier` written from the agent's own output, or from a hard-coded `switch`. **Failing input:** the designer returning `"low"` for a revision touching human-authority UI, and the platform believing it. That is the exact gate-bypass ADR 0021 §5 exists to prevent. |
| **Q5** | Penpot references are coherent with the declared provider. | `provider == penpot` with `penpotFileId == null` or `penpotPageId == null` — both columns are nullable, so the DB accepts it and the reviewer then has nothing to open. |
| **Q6** | `designSystemRevision` is unchanged from the parent unless an invalidation is recorded. | A child revision silently changing the design-system revision — the correction loop's version-fork (checkpoint 003 §8.4). |
| **Q7** | **The fidelity anchor exists and is machine-checkable.** See §3.5. | A `DesignRevision` whose `boardIdsJson` / `statesRepresentedJson` / `responsiveTargetsJson` are valid JSON with no declared schema, so an implementation that renders **none** of the boards string-equals one that renders all of them. |

### 3.3 Why Q7 is the one that matters most

`DesignRevision` carries four JSON blob columns — `boardIdsJson`, `responsiveTargetsJson`,
`statesRepresentedJson`, `artifactRefsJson` — all `NOT NULL` text, **none with a declared schema and
none with a validator anywhere in the tree.**

ADR 0021 §2 requires that implementation *"reproduces the approved revision with full fidelity"* and
that *"divergence from approved design is itself a defect"*. **Today the approved revision contains no
field an implementation can be checked against.** The rule is undecidable as written: fidelity cannot
be falsified against a document with no parseable content.

This is the design's central finding. It is a **blocker on switching the runtime on**, not on designing
it — building the scheduler without Q7 would produce a platform that produces design revisions nobody
can verify, which is worse than the current honest park because it would *look* governed.

### 3.4 The gates are not symmetric, deliberately

P1–P6 are cheap reads and refuse to enqueue. Q1–Q7 are expensive and run after a real agent execution.
**The asymmetry is load-bearing**: P6 and Q4 are the two that prevent a human gate being bypassed, and
neither is expressible as a guard on the `designRequired → agentExecuting` edge — that edge carries only
`actorAllowed` + `agentAvailable` (`work_item_transitions.dart:62-65`), by the table's own convention
for edges that assert an agent is starting *now*. **Capacity is `JobCapacityGuard`'s job; evidence is
the lane's.** No edge in the transition table is widened by this design.

### 3.5 What the fidelity anchor must be (specified, not invented wholesale)

The anchor is **not** invented here — it is named and ordered, because its shape is a product decision:

1. **A declared schema** for the four blob columns — what a board id is, what a "state" entry is, what
   an artifact ref must resolve to. Drawn from the approved QA artifact's `evidenceTypes` vocabulary
   where it already declares one (§6).
2. **A validator** that fails closed on an unparseable or schema-violating blob, in the same way
   `QAOrchestration.evaluate` returns `notExecuted` and `_isGateSatisfied` treats `notExecuted` as
   **unsatisfied** (`substantive-qa-gates.md` §1.1).
3. **A comparison basis** between the approved `DesignRevision` and the implementation's recorded
   evidence — this is where §6's `qaPassed` work attaches.

**Which of (1)–(3) lands first, and who owns them, is §7 undecidable item U-3.**

---

## 4. The boundary change

### 4.1 What lane E does today, and why it is right

Lane E walks `draft → planning → planned` and records `designRemediationRequired: true`,
`designGovernanceRuntime: 'unavailable'`, `blockedBy: EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY`. It refuses
`designRequired` because the guard is satisfiable only by a value that is then thrown away.

**This design does not overturn that refusal, and does not weaken any of those three keys.** The
runtime is built *behind* the refusal; the refusal is lifted only when §4.2 has actually landed.

### 4.2 What the runtime supplies so `designRequired` becomes truthful

Exactly three things, and **all three are needed** — any two leave the entry lying:

**(a) A durable design contract.** The `DesignContract` type and `DesignContractStatus` already exist;
**the table and the store do not** (G-D). So: a `design_contract` migration + `DesignContractStore`,
and a builder that writes one `draft` contract per remediation item at creation.

**(b) The id on the column, from the row that was read back.** `createWorkItem` accepts
`designContractId` (`durable_workflow_engine.dart:59, 83`). Lane E passes the id of the contract
**persisted and read back** — the discipline already used for QA contracts at
`lane_e_design_remediation_work_item.dart:385-401`, where a refusal is a *named reason* rather than a
bare null. Same pattern, same shape of honesty.

**(c) The same id in the transition context.** `planned → designRequired` is guarded by
`designContractExists()`, which reads `context['designContractId']`. So the walk passes that id in
`context` **and** on the column — **the same value**, because it names a row that exists.

### 4.3 The guard change this design requires (and why)

`designContractExists()` today reads **caller-supplied context**. That makes it satisfiable by any
caller that passes a string, whether or not a row exists — which is why lane E called it *"purely to
satisfy"* the guard. **A guard whose failure mode is a caller's choice is not a guard.**

**Required change:** `designContractExists()` must read the **durable `WorkItem.designContractId`
column**, and the contract's existence must be confirmed against the store.
**Falsifier for the change:** a caller passing `context: {'designContractId': 'anything'}` on an item
whose column is null — today this passes and persists an item at `designRequired` with nothing behind
it.

**Scope caution:** this guard is shared by `planned → designRequired` for **every** category, so the
change is wider than design remediation. It is named here as a required change with its failing input,
**not** made. This lane owns no production path.

### 4.4 The `planned` convergence defect — the actual boundary change

Because `planned` is a triage entry state with a `designNotRequired` probe target (G-7), lane E's
holding state is **not a holding state**. Three options, with the honest cost of each:

| Option | What it does | Cost |
|---|---|---|
| **R1 (recommended)** | Mount the design scheduler **and** land (a)–(c), so the item leaves `planned` for `designRequired` on the same reconciliation pass that fixes the contract. `planned` stops being a waiting state because it stops being reached. | Requires the contract work first. Until it lands, the convergence defect stands. |
| **R2** | Give design-remediation items their own park state (`featureIntakeParked` is the precedent — `work_item_transitions.dart:31-56`) instead of `planned`. | A new state + edges, for a window that closes when R1's work lands. Adds the state permanently. |
| **R3** | Make the triage entry probe category-aware for remediation items. | **Rejected.** The scheduler is category-blind *by construction*, and `triage_defect.dart:60-88` documents that blindness as the thing the park state was built to survive. Weakening it re-opens the original collision. |

**R1 is recommended and specified. R2 is the fallback if (a)–(c) slip.** R3 is rejected on the tree's
own evidence.

### 4.5 What the runtime must supply for §5's risk gate

`DesignRiskPolicy` (G-F) needs: a type with `{rules, mediumTierRequiresHumanApproval, policyVersion}`
(checkpoint 003 §9.6), a durable inspectable store, and `policyVersion` stamped **on the revision**
— "why was this not gated?" is unanswerable after a policy change without it. **Until it exists, see
§5.6's fail-closed default, which is a human decision.**

### 4.6 What the item records while the runtime is still absent

Unchanged, and stated so no implementer "simplifies" it:

- `blockedBy: EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY`
- `designGovernanceRuntime: 'unavailable'`
- `designRemediationRequired: true`
- `productQAContractSpecUnavailable: <named reason>` when the product has no QA contract — **a second,
  independent** strand. Recording only the first would leave an operator reading
  `EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY` and concluding the QA contract was handled, when
  `agentExecuting → agentCompleted`'s `qaContractExists()` is what will refuse completion.
- Item state: `planned` — **and, per G-7, `planned` is not safe to wait in.** §4.4.

### 4.7 The already-parked item

**It is not repaired by this design and is not claimed to be.** It has no design artifact, and no
procedure here reconstructs one. It requires re-triage. What this design owes it is only the §4.6
metadata continuing to say truthfully why it is parked.

---

## 5. The `designApproval` human gate

### 5.1 Answer to the dispatch's question: **no new `HumanDecisionType` is needed**

Confirmed against the tree, and it is worth stating precisely because ADR 0021 §5 names the type
without checking whether it was already there.

`HumanDecisionType.designApproval` exists (`human_decision.dart:2`), and all three of its choices are
already admitted by edges **and** routed:

| Choice | Transition (already in the table) | Guards | `targetFor` |
|---|---|---|---|
| `approve` | `waitingForHumanDecision → designApproved` (`:76-94`) | `blockingHumanDecisionResolved` + `decisionActorIsHuman()` | `designApproved` (`human_decision_routing.dart:93`) |
| `reject` | `waitingForHumanDecision → designRejected` (`:95-104`) | same | `designRejected` (`:95`) |
| `rework` | `waitingForHumanDecision → designInReview` (`:105-122`) | same **+ `escalationIndexWithinLimitForDecisionTypes({designApproval})`** | `designInReview` (`:97`) |

**No enum addition. No new choice. No new `WorkItemState`. No new waiting mechanism** — the same
principle as checkpoint 002 §12.4, cited by checkpoint 003 §9.4.

### 5.2 The trap: `designRejection` exists and is admitted by nothing

`HumanDecisionType.designRejection` is declared at `human_decision.dart:3` and is **referenced by no
transition edge, no routing arm, and no production caller.** An operator choosing "reject" produces
**type `designApproval`, choice `reject`** — not `designRejection`.

**So `designRejection` is a dead type that reads as the obvious answer.** A future implementer
reaching for it will build a decision that resolves to **no target**: `_ => null` in `targetFor`, and
the item sits at its gate with the decision answered. **Recorded as finding D-2; not removed** — it is
a `platform_contracts` change and therefore outside `OWNED_PATHS`.

### 5.3 Who raises it, and when — the thing that does not exist (G-C)

Per ADR 0021 §1 and checkpoint 003 §9: after the review verdict is durable and the tier is resolved.

| Tier | Path | Raised by |
|---|---|---|
| LOW | designer → reviewer → `approved`. **No human gate.** | nobody — platform sets `DesignRevisionStatus.approved` |
| MEDIUM, policy says ungated | reviewer → `approved` | nobody |
| MEDIUM, policy says gated | → **blocking `designApproval`** | the review-result recorder, evaluating the policy |
| HIGH | → **blocking `designApproval`**, mandatory | the review-result recorder, unconditionally |

`HumanDecisionRouting` already treats `designApproval`/`reject` as **not** an escalation
(`:229` returns `designInReview`, a known documented divergence at `:180-199`). Preserve that; do not
"fix" it as a side effect of this work.

### 5.4 How the item routes **out** of `designInReview` — including a dead end

- **Approve** → `designApproved` → `designApproved → agentExecuting` (`:123-126`) → the implementation
  lane. Clean.
- **Rework** → `designInReview`. The item re-enters the **review** lane, not the design lane. This is
  deliberate: a rework answer judges the *review*, so it goes back to review. Correct, and noted.
- **Reject** → `designRejected`. **And then it is stuck.**
  `designRejected` has exactly one out-edge: `designRejected → designInReview` (`:127-129`). It **is**
  an entry state of `designRevisionDefinition`, but the live probe refuses `designRejected →
  agentExecuting` because that edge does not exist (`scheduler.dart:3207-3244`). So **a human who
  rejects a design strands the item** — the "named and unreachable at once" state that file describes,
  and the reason it kept the state and the probe both.

  **This design specifies the missing edge:**

  ```dart
  // REQUIRED — the re-design route. `designRejected` is a HUMAN verdict, and
  // re-running the designer is what a rejected design asks for.
  // Guard set derived from this table's own convention for an edge into a
  // dispatchable entry state: `actorAllowed([orchestrator])` alone.
  //   - `agentAvailable()` belongs on `-> agentExecuting` edges only; this edge
  //     asserts no execution is starting, and capacity is JobCapacityGuard's.
  //   - No evidence guard: `designRejected` carries a decision already, and a
  //     guard the caller cannot satisfy makes the edge unreachable — the same
  //     reasoning as `agentFailed -> designRequired` (:195).
  (WorkItemState.designRejected, WorkItemState.designRequired): [
    GuardConditions.actorAllowed([ActorType.orchestrator]),
  ],
  ```

  **Why this is safe against the one-reachable-entry-state rule:** `Scheduler.
  _returnRetryableItemsToEntryStates` derives its return target from the policy and refuses an
  ambiguous answer (`:241-252`). `designRequired` is the **only** state reachable from `agentFailed`
  within this lane's entry set — `agentFailed → designRequired` exists (`:288-290`) and
  `agentFailed → designRejected` does not. Adding `designRejected → designRequired` adds a **target**,
  not a second entry state, so uniqueness is preserved. **This must be re-verified by the implementer
  against `retry_return_to_entry_state_test.dart`**, which asserts it by name; this lane may not
  assert it holds.

  **A human verdict must not be silently overturned**, which is why `agentFailed → designRejected` is
  and must remain absent (`:282-287`).

### 5.5 The rework loop is currently unbounded — finding D-3

`waitingForHumanDecision → designInReview` for `(designApproval, rework)` carries
`escalationIndexWithinLimitForDecisionTypes({designApproval})`, which reads
`context['maxEscalation'] ?? -1` (`guard_conditions.dart:542`) and **passes when the bound is negative**
(`:544`). The only supplier, `DurableWorkflowEngine._getMaxEscalationForDecisionType`, returns a
hard-coded **`-1`** with a comment conceding it is a stub (`durable_workflow_engine.dart:1047-1052`).

**So a human can send a design back for rework an unlimited number of times**, and the guard that
reads as a bound bounds nothing. Checkpoint 003 §8.4 requires loop bounds. **The runtime must supply
the bound** from the risk policy's `policyVersion`, and until it does, **the bound is not enforced** —
stated rather than implied, because a guard that reads as a guarantee and is not one is worse than no
guard.

### 5.6 The fail-closed default while no risk policy exists — **HUMAN DECISION REQUIRED**

`DesignRiskPolicy` does not exist (G-F), and checkpoint 003 §9.5 declares the thresholds **unfinalized
by the document itself**. Two options:

- **F-A (recommended): treat every revision as HIGH until a policy exists.** The HIGH path is the only
  one whose criteria are decidable from the tree today (§9.4's table is a list of six named conditions,
  not a tunable). Cost: a human gate on every revision, including trivia.
- **F-B: classify by checkpoint 003 §9.2–§9.4 prose.** Cost: hard-coded thresholds, which ADR 0021's
  Consequences and §9.6 both forbid, asserted at **confidence the source document explicitly disclaims**.

**This is product policy, not a technical default, and it is the one thing this artifact asks a human
to ratify.** F-A is recommended because it is the only option that cannot silently under-gate. It is
raised as a blocker, not decided here.

---

## 6. Interaction with the approved QA gates — `qaPassed` is NOT reopened

`design/qa-contracts-feature-remediation/` was Level-3 approved under decision `92d567e3`, which holds
`qaPassed` **CLOSED**. **This design does not reopen, weaken, or reinterpret it, and takes no position
on its gate set.** Four statements, and nothing more:

1. **The runtime never runs QA.** `qaInProgress → qaPassed` carries
   `allRequiredGatesPassed()` (`work_item_transitions.dart:732-738`). This design adds no gate, no
   evaluator, and no contract. `qaPassed` stays exactly as closed as it is today.
2. **Design remediation is upstream of QA, not a substitute for it.** A design defect's flow is
   `design → designApproved → implementation → … → QA`. This runtime **lengthens** the path to
   implementation; it does not shorten the path to `qaPassed`. `92d567e3`'s accepted cost — items
   accumulating at `reviewApproved` — is **unchanged and, if anything, pushed further out**, because a
   design-remediation item now passes two more states first.
3. **The fidelity anchor (§3.5, Q7) attaches to that artifact's evidence vocabulary — it does not
   change it.** The anchor needs a schema for what a board/state/artifact-ref *is*. That artifact
   already declares an `evidenceTypes` vocabulary (`committed_diff_paths`, `producedRevision`, and the
   rest) and already records that the vocabulary is **proposed, not derived from a controlled list**.
   The anchor **reuses** those names and **adds to them**; it does not redefine them. **If the anchor
   and that artifact ever disagree, that artifact wins** — it is the approved one.
4. **The one overlap, stated so it is not discovered as a conflict later:** `qa_contract` is a *second,
   independent* strand on a remediation item (lane E's `productQAContractSpecUnavailable`, §4.6), and
   `92d567e3` governs what a QA contract may *assert*. This runtime does not change whether a
   remediation contract is provisioned or what it contains.

**No question about `qaPassed` is answered here, and none is asked.**

---

## 7. What remains UNDECIDABLE — stated, not guessed

| # | Question | Why this lane will not answer it |
|---|---|---|
| **U-1** | **The already-parked remediation item's disposition.** | Not a design question — a product/operations one. It needs re-triage, and the human decision's own terms accept it is not repaired. **It must not be quietly forgotten** (§4.7). |
| **U-2** | **Whether MEDIUM defaults gated or ungated, and the thresholds between tiers.** | Checkpoint 003 §9.5 says the thresholds are **not finalized** and must not be treated as settled without evidence. §5.6's fail-closed default is the interim answer, and it is the human's. |
| **U-3** | **The fidelity anchor's schema, its owner, and its build order.** | §3.5 specifies what it must satisfy and why it blocks switching on; **which** schema is a product/design-system decision, and two of its three readers (`WorkspaceDeltaProbe`, `GitWorkspaceInspector`) live in different packages, which that artifact already records as undecided. |
| **U-4** | **Whether the design agent needs `penpotRead`** (§2.2). | Checkpoint 003 §7.6 was never ratified; adding the capability with no worker carrying it makes the lane silently undispatchable. Product/platform call. |
| **U-5** | **Whether `maxAttempts: 3` is right, and what exhaustion raises** (§2.3, D-4). | Checkpoint 003 §10.2 says `2`; the tree says `3`; §10.4 requires exhaustion to reach a human and no such path exists. Changing the number is not this lane's authority and would be arbitrary without the exhaustion behaviour. |
| **U-6** | **What a product's declared validation commands are**, and the path-ownership map. | `AGENTS.md` leaves both `TBD`. Same disposition the approved QA artifact used. Inventing values would make the gate a constant every product satisfies for free. |
| **U-7** | **Whether `DesignRiskPolicy` is seeded, defaulted, or operator-authored**, and its first version. | §4.5 specifies its required shape (checkpoint 003 §9.6) and its `policyVersion` requirement; **its content** is a product decision, and inventing thresholds is U-2 wearing a different hat. |

**None of these is answered by omission elsewhere in this artifact.** Each is a named, carried gap.

---

## 8. Findings routed to the Manager (`FOLLOW_UPS.md` is not mine to edit)

| # | Finding | Where it belongs |
|---|---|---|
| **D-1** | **`designRevisionDedupeKey` burns its key permanently, making the correction loop unreachable.** `JobQueue.enqueueIfAbsent` resolves a key held by *any* job, terminal or not (`scheduler.dart:3385-3391` documents this for `engineeringReview`, which fixed it with a `:a<n>` suffix from `triageAttempt`). The design lane's key is `'<workItemId>:design_revision'` with **no suffix** — so the **second** revision for an item is silently a no-op. That is precisely the correction loop ADR 0021 §6 gives `parentRevisionId` for. | New `FOLLOW_UPS` entry. **Not fixed here** — `packages/**` is `READ_ONLY_PATHS`. |
| **D-2** | **`HumanDecisionType.designRejection` is declared and admitted by nothing** (§5.2). An implementer reaching for it builds a decision that resolves to no target. | New `FOLLOW_UPS` entry. |
| **D-3** | **`escalationIndexWithinLimitForDecisionTypes` is unbounded in practice** — sole supplier hard-codes `-1` (`durable_workflow_engine.dart:1047-1052`) (§5.5). Affects `designApproval` rework today, not just design. | New `FOLLOW_UPS` entry; likely architecture-lane. |
| **D-4** | **No `maxAttempts`-exhaustion → human route for the design lane** (§2.3), contrary to checkpoint 003 §10.4. | New `FOLLOW_UPS` entry. |
| **D-5** | **`designContractExists()` reads caller-supplied context, not the durable column** (§4.3) — satisfiable by any caller passing a string. Shared with `planned → designRequired` for **all** categories. | Architecture-lane candidate; wider than this feature. |
| **D-6** | **The parked item is not in `planned` only by luck — `planned` is a triage entry state** (G-7, §4.4). Any future lane that parks there inherits the convergence. | New `FOLLOW_UPS` entry. |
| **D-7** | **ADR 0021 §3 names `ControlPlaneService.createDesignRemediationWorkItem()`; no such method exists.** The only reference to that name in the tree is a doc comment in `design_remediation_request.dart:11`. The implementation is `DesignRemediationWorkItemProvisioner.ensurePersisted()`. A `CONTRADICTION` between an accepted ADR and the code it governs. | New `FOLLOW_UPS` entry; ADR amendment is a human/architecture action. |

---

## 9. Build order — and why mounting the scheduler is **not** step 1

Each step is a precondition of the next. **The order is load-bearing, not preference.**

| Step | Delivers | Why it cannot move earlier |
|---|---|---|
| **1** | `design_contract` migration + `DesignContractStore` + builder (§4.2a) | Without a real row, `designRequired` is the fabrication lane E removed. |
| **2** | `designContractExists()` reads the durable column (§4.3) | Without it, step 1's row and a fabricated string are indistinguishable. |
| **3** | Lane E walks `planned → designRequired` on the read-back id (§4.2b/c) | Depends on 1–2. **This is what makes `planned` stop being a waiting state** (§4.4/R1). |
| **4** | **Fidelity anchor** schema + validator (§3.5, Q7) | Must precede *switching on*. Building the scheduler first would produce unverifiable revisions that look governed. |
| **5** | `DesignRiskPolicy` + fail-closed default (§4.5, §5.6) | Q4 needs a policy to evaluate. **Blocked on the human decision in §5.6.** |
| **6** | The producer: run `designRevision`, write the `DesignRevision`, stamp metadata (Q1–Q3, G-B, G-E) | Depends on 1–5 for its pre/postconditions to mean anything. |
| **7** | `designRejected → designRequired` edge (§5.4) | Without it, a rejected design is a human-stranded item — and it is only reachable once step 9 can raise a rejection. |
| **8** | Mount `sched-design-revision` (+ `sched-design-review`) in the composition root (G-A) | Depends on 6. **Mounting earlier is the specific mistake this table exists to prevent.** |
| **9** | Raise `designApproval` on the resolved tier (G-C, §5.3) | Last: a gate with no producer behind it is a gate nothing reaches. |
| **10** | Fix D-1 (dedupe suffix) before the first correction loop | Not blocking the first run; blocking the second. |

**Step 4 is the one most likely to be skipped and the one that matters most.** `92d567e3`'s own lesson
is that a gate which passes vacuously is worse than no gate — and an unvalidatable `DesignRevision`
produces exactly that, one layer up.

---

## 10. Traceability and self-assessment

**Requirements covered**

| Requirement | Where |
|---|---|
| `JobDefinition` — all six fields, and why `designRequired` | §2.1, §2.4 |
| Falsifiable pre/post conditions, each with a failing input | §3.1, §3.2 |
| The fidelity gap behind ADR 0021 §2 | §3.3, §3.5 |
| `designApproval` — no new type, choices, approve/reject/rework, routing out of `designInReview` | §5.1–§5.4 |
| Boundary change; what the runtime supplies; what the item records meanwhile | §4.2–§4.7 |
| `qaPassed` interaction, not reopened | §6 |
| Undecidable, stated not guessed | §7 |
| Findings routed, not self-edited | §8 |

**Requirements gaps:** G-1 … G-4 in the brief §7; U-1 … U-7 in §7.

| | | |
|---|---|---|
| `design_system_compliance` | **UNKNOWN** | This lane designs a **runtime**, not a UI. It specifies no tokens, components, or visual change, so there is nothing to assess against the design system. The **fidelity anchor** (Q7) is where design-system conformance becomes checkable — and its schema is U-3. `UNKNOWN`, not `PASS`: passing would claim a compliance this design has no standing to judge. |
| `ux_accessibility_score` | **UNKNOWN** | Same reason. No user-facing surface is designed here. Checkpoint 003 §9.4's HIGH criteria (human-authority UI) mean this runtime *governs* such surfaces — it does not design them. |
| `implementation_feasibility` | **MEDIUM** | Feasibility of §2–§5 is **HIGH** — the definitions, stores, tables, transitions, routing and gates all exist; the work is wiring plus the missing producer. **§3.5's fidelity anchor is `LOW`/unknown** (U-3: schema, owner, order all open), and §5.6 is blocked on a human. The MEDIUM is the honest aggregate, not an average that hides the low part. |

**Risk rationale:** Level 3 per `DESIGN_GOVERNANCE.md:88-96` — this governs a **core workflow stage that
does not exist**, changes the meaning of four states, and adds an edge to the one authority table that
governs all work-item movement (AGENTS.md §1). Comparable to the approved `qa-contracts-feature-remediation`
artifact, which was likewise Level 3.

**This revision requires `HUMAN_DECISION_REQUIRED`** at Gate D4, on the single question in §5.6.

---

## 11. References

ADR 0021 · Checkpoint 003 §7, §8, §9, §10, §11 · Checkpoint 002 §12.4, §16 · `AGENTS.md` §1, §12, §13 ·
`docs/engineering/DESIGN_GOVERNANCE.md` · `design/qa-contracts-feature-remediation/` (read-only) ·
`work_item_transitions.dart:24-56, 58-129, 195-293, 732-744` · `scheduler.dart:3205-3355` ·
`triage_defect.dart:126-138` · `guard_conditions.dart:136-174, 521-552` ·
`durable_workflow_engine.dart:59-89, 1047-1052` · `human_decision.dart:1-44` ·
`human_decision_routing.dart:85-247` · `lane_e_design_remediation_work_item.dart:137-208, 626-649`