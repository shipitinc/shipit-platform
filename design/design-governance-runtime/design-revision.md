# Design Revision 2 — Design Governance Runtime

**Revision ID:** `db7f8a05-13cb-4bcb-b269-5c23b68552f5`
**Brief ID:** `aabceaca-0d1f-492c-837c-2068a2ea9ed9`
**Revision number:** 2
**Status:** `DRAFT` → independent **focused** review required. **Not approved. Not implemented. Not verified.**
**Authoring lane:** `design-DESIGN-GOVERNANCE-RUNTIME` (design-agent); **corrected by** `correct-DESIGN-GOVERNANCE-REVIEW-1`
**Base SHA:** `b95bffd5f23f1322caf7ae086b35cccf78262790` · **Corrected from HEAD:** `4c82de3`
**Risk level:** **3 — Major Workflow Change.** Gate D4 **RESOLVED** (`a1c7d904-3b8e-4f21-9d6e-5c2f81b7a390`).

> **REVISION 2 IS A CORRECTION, NOT A REWRITE.** Revision 1 was reviewed
> (`DESIGN_REVIEW_CHANGES_REQUIRED`, `CORRECTION_REQUIRED: YES`, risk level 3 agreed) and its findings
> are recorded in §12 rather than absorbed. What revision 1 got right is untouched: the three premise
> corrections, the G-A…G-F gap set, G-7, the falsifier discipline of §3, §5.1's "no new
> `HumanDecisionType`", and the whole of §6.
>
> **The specific failure this correction exists to repair:** in both blocked places revision 1
> *identified the defect correctly* and then *prescribed a fix the scheduler will not honour* — §4.4/R1
> rested on a claim about reachability that `planned_entry_state_hop_test.dart:467-497` falsifies, and
> §5.4 rested on `scheduler.dart:3242-3248`'s own comment while `entry_hop.dart:181` reads a different
> field. **Both remedies below were opened in the code and traced through, not asserted.** Each names
> the file and line that proves the scheduler will honour it.

> **A DESIGN IS NOT A VERIFICATION.** Everything below is derived by reading the tree at `b95bffd`
> (revision 1) and `4c82de3` (revision 2). No Dart file was changed, so no analyzer run, no test run
> and no runtime evidence exists, and none is claimed. `READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES` is a
> claim about *this artifact's readiness to be reviewed*, and about nothing else. Per
> `aef-design-workflow` §4–§5, this lane never approves its own work — and a correction is not a
> self-approval either.

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
`entryProbeTargets: {planned: designNotRequired}` (`triage_defect.dart:126-138`), and the scheduler is
category-blind. Lane E parks the remediation item at `planned`. **The triage scheduler therefore takes
it out to `designNotRequired`** — asserting that no design work is required — and re-dispatches it,
forever.

**This is why "build the runtime" did not fix the parked item and will not fix the next one by
mounting a scheduler.** The item never reaches `designRequired`. §4 specifies the replacement holding
state. It is listed last because it is the one an implementer would otherwise discover last.

---

## 2. The `designRevision` lane

### 2.1 The `JobDefinition` — adopted, with **one required amendment**

**It already exists and this design adopts it unchanged except for one field.** Inventing a new one
would fork a definition the tree already pins: **14 test files** reference the design-revision lane,
and **12 of those pin `designRevisionDefinition` by name**
(`apps/server/test/integration/{design_governance_e2e,triage_execution}_test.dart` ·
`packages/scheduler/test/{design_job,entry_hop,entry_hop_drift_guard,implement_feature_entry_disjointness,
implementation_completion_inflow,retry_return_to_entry_state,triage_entry_state_drift_guard}_test.dart` ·
`packages/workflow_engine/test/{operator_retry_edge,retry_return_edges,transition_consistency}_test.dart`).
The other two — `design_governance_postgres_test.dart` and `store_contracts_postgres_test.dart` — pin
the lane's **data layer**, not the definition.

> **CORRECTION (rev 2).** Revision 1 called this "adopted as-is" and counted "eight test files". Both
> were wrong: the count is 14 (12 by name), and "as-is" is not achievable — the `designRejected` entry
> state is inert without a seventh field. See §2.4 and §5.4.

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

**The one required amendment** — the seventh field, added alongside the §5.4 edge and **not optional
with it**:

```dart
// REQUIRED — the scheduler will NOT reach designRequired from designRejected
// on the edge alone. See §5.4 for the full mechanism, verified at
// runnable_work.dart:46,98-99,187-196 and entry_hop.dart:176-195.
const JobDefinition designRevisionDefinition = JobDefinition(
  jobType: JobType.designRevision,
  requiredRole: AgentRole.designAgent,
  requiredCapabilities: {
    WorkerCapability.penpotWrite,
    WorkerCapability.visualDesign,
  },
  entryStates: {WorkItemState.designRequired, WorkItemState.designRejected},
  // THE FIELD THAT ACTIVATES designRejected. Without it this map is empty and
  // every probe below asks the illegal question `designRejected ->
  // agentExecuting`, which has no edge and answers noAction.
  entryProbeTargets: {
    WorkItemState.designRejected: WorkItemState.designRequired,
  },
  priority: JobPriority.normal,
  maxAttempts: 3,
);
```

This is the tree's own `reviewRejected → designNotRequired` precedent, verbatim in shape
(`triage_defect.dart:132-135`).

| Field asked for | Value | Verdict |
|---|---|---|
| `jobType` | `JobType.designRevision` (`design_revision`) | Matches checkpoint 003 §10.2. |
| `requiredRole` | `AgentRole.designAgent` | Matches. ADR 0021 §7 requires exactly this role. |
| `requiredCapabilities` | `{penpotWrite, visualDesign}` | **Diverges from checkpoint 003 §10.2, which also lists `penpotRead`.** See §2.2. |
| `entryStates` | `{designRequired, designRejected}` | Matches. `designRejected` is currently inert; §5.4 activates it. |
| `entryProbeTargets` | **`{}` today → `{designRejected: designRequired}`** | **CORRECTED IN REV 2. This is the required amendment, and the edge alone does not supply it.** See §5.4. |
| `priority` | `JobPriority.normal` | Matches §10.2. |
| `maxAttempts` | `3` | **Diverges from checkpoint 003 §10.2's `2`.** See §2.3. |
| `skipWorkflowPolicyCheck` | **absent (false)** | Correct, and it **stays** false. §2.4 pt 3 previously rested the `designRejected` contradiction on this; it now rests on the probe target, which is a stronger footing. |

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
3. **The probe is what makes the second entry state *inert*, and a second field is what makes it
   *useful*.** `designRejected` is listed today and is genuinely unreachable:
   `RunnableWorkEvaluator` probes `probeTargetFor(state)` =
   `entryProbeTargets[state] ?? targetState` (`runnable_work.dart:98-99`), `targetState` defaults to
   `agentExecuting` (`runnable_work.dart:46`), and there is no `designRejected → agentExecuting`
   edge — so the probe asks an illegal question and answers `noAction` (`:187-196`). That is the
   five-jobs-and-five-executions incident the probe fixed (`scheduler.dart:3207-3238`), and this
   design **keeps the probe on** and still does not add `designRejected → agentExecuting`.

   > **CORRECTION (rev 2).** Revision 1 stopped here and read the inertness as the fix for §5.4. It
   > is not — inertness is why the state is *safe*, not why the *re-design route works*. The
   > `EntryHopper` never consults `probeTargetFor`; it reads the map directly (`entry_hop.dart:181`)
   > and refuses when the key is absent (`:182-195`). So an edge alone leaves `designRejected`
   > refused, and revision 1's §5.4 would have been satisfied by nothing. §5.4 is rewritten and
   > §2.1's field table amended.
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
| **Q7** | **The fidelity anchor exists and is machine-checkable.** See §3.5. | Any of the six blob columns of §3.3 carrying a value the committed schema rejects — most sharply, a `boardIdsJson` of `[]` (a revision asserting no board, which `boardSet`'s `minItems: 1` forbids) or a `reviewScopeJson` of `{}` carrying keys the schema does not name. Today **every** such value is accepted, so an implementation rendering **none** of the boards string-equals one rendering all of them. |

### 3.3 Why Q7 is the one that matters most

`design_revision` carries **six** JSON blob columns, and **none has a declared schema; none has a
validator anywhere in the tree** (`apps/server/migrations/20260920232118956/definition.sql:196-204`,
and `DesignRevision` in `packages/platform_contracts/lib/src/types/design_revision.dart:52-66`):

| # | Column | Null? | What an unvalidated blob permits today |
|---|---|---|---|
| 1 | `boardIdsJson` | `NOT NULL` | An implementation rendering **none** of the boards string-equals one rendering all of them. |
| 2 | `responsiveTargetsJson` | `NOT NULL` | `[]` asserts no responsive targets; anything unparseable asserts nothing at all. |
| 3 | `statesRepresentedJson` | `NOT NULL` | States that name no board — so "every named state has a board" is uncheckable. |
| 4 | `artifactRefsJson` | `NOT NULL` | `{}` or `[]`; a revision with no traceable artifact is accepted silently. |
| 5 | `reviewExecutionIdsJson` | `NOT NULL` | **The independence rule is as undecidable as §2.** An implementation can claim `[]`, and checkpoint 003 §7.1's "reviewer ≠ designer" has nothing to check against. |
| 6 | `reviewScopeJson` | **nullable** | `null` vs `{}` vs arbitrary keys — a review can claim it was scoped to nothing and nothing objects. |

*(Correction lane: revision 1 named four columns and omitted 5 and 6. Both are equally unvalidated, and
6 being nullable makes it the likeliest of the six to be written as `{}`.)*

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

### 3.5 The fidelity anchor — **schema content decided** (U-3)

**U-3 is decided. Below is the content chosen, not a description of content to be chosen.**

> **Operator decision `a1c7d904-3b8e-4f21-9d6e-5c2f81b7a390` (U-3).** ADR 0021 §2's "divergence is a
> defect" is undecidable today because these columns have no schema and no validator. **Both anchors,
> each with a named role:** a **committed, versioned JSON schema validated on write** is what the
> **machine** diffs an implementation against; **Penpot** is what a **human reviewer** reads and
> approves. Both refer to the same approved revision, and **where they disagree, the disagreement is
> itself a finding.** Penpot alone was rejected: `penpotFileId`/`penpotPageId` are **nullable**
> (`definition.sql:194-195`) and nothing can diff against a board.

#### 3.5.1 The document

One committed schema document, `docs/engineering/schemas/design_revision_fidelity_anchor.schema.json`,
`$id` versioned **`1.0.0`**, with six named subschemas — one per column of §3.3. A seventh runtime
invariant is named below because JSON Schema cannot express it.

**Design rules applied to every subschema**, and *why each one is load-bearing*:

- **`additionalProperties: false` everywhere.** An unknown key is a claim the platform cannot check.
  Accepting one is how an unvalidated blob becomes a validated-looking one.
- **Every user-visible string is a `pattern` or `minLength`, never free text.** A board id that can be
  any string cannot be cross-checked against anything.
- **Closed `enum` vocabularies** for anything that names a design-system concept. This is what makes
  the anchor *design-system* rather than merely *well-formed*.
- **`uniqueItems: true` and a declared sort key per array.** Uniqueness makes a set a set; a sort key
  is what makes two encodings of the same revision **byte-identical**, which is the precondition for
  diffing at all.

| # | Column | Subschema | Required shape | The invariant it buys |
|---|---|---|---|---|
| 1 | `boardIdsJson` | `boardSet` | array, **`minItems: 1`**, unique, sorted by `boardId`; items `{boardId, provider, providerFileId, boardName?}`, `boardId` matches `^[A-Za-z0-9_-]{1,128}$`, `provider` enum `["penpot"]` | **A revision with no board asserts nothing and can be diffed against nothing.** `minItems: 1` makes that unrepresentable. `providerFileId` being **required inside the blob** is what closes the nullable-`penpotFileId` hole the operator named — it makes Q5 enforceable by validation instead of by a separate check. |
| 2 | `responsiveTargetsJson` | `responsiveSet` | array, **`minItems: 1`**, unique, sorted by `breakpoint`; items `{breakpoint, minViewportWidthCss, orientation?}`; `breakpoint` enum `["xs","sm","md","lg","xl","2xl"]`; `minViewportWidthCss` integer 0–4096 | The breakpoint vocabulary is **the design-system link**: these names must match the product's declared design-system revision, which is what P2 already requires to be named. This turns "did the implementation render the mobile board" from an opinion into a diff. |
| 3 | `statesRepresentedJson` | `stateSet` | array, **`minItems: 1`**, unique, sorted by `stateKey`; items `{stateKey, boardId, variant}`; `variant` enum `["default","loading","empty","error","success","disabled","focus","readonly"]` | **`boardId` must resolve into `boardSet`** — a cross-column referential-integrity rule, checked by the validator against `boardIdsJson` in the same write. This is what makes "every named state has a board" checkable, which today it is not. |
| 4 | `artifactRefsJson` | `artifactSet` | array, `minItems: 0`, unique, sorted by `(kind, ref)`; items `{kind, ref}`; `kind` enum `["commit","diff","file","url","penpot-component","penpot-asset","qadoc"]` | `minItems: 0` is honest — a revision may carry no extra artifact. What the `enum` buys is that **"artifact" stops meaning whatever the writer meant**, which is the vocabulary problem §6.3 describes for the QA artifact's `evidenceTypes`. |
| 5 | `reviewExecutionIdsJson` | `executionIdSet` | array, unique, `minItems: 0`, items `string` `minLength: 1`, sorted | Closes §3.3 row 5. |
| 6 | `reviewScopeJson` (**nullable**) | `reviewScope` | `type: ["object","null"]`, `additionalProperties: false`; `{dimensions?, boardIds?}`; `dimensions` items enum `["layout","typography","color","contrast","motion","responsive","content","a11y","state-coverage","brand"]` | **Nullable is preserved — the schema must accept `null`** — but it must **reject an object carrying unknown keys**. That is precisely the `null` / `{}` / arbitrary-keys confusion of §3.3 row 6, and the enum is what stops a reviewer claiming a dimension nobody can check. |

**The seventh rule, named because JSON Schema cannot express it** — it is a validator assertion over two
fields, not a document constraint:

> **`designerExecutionId ∉ reviewExecutionIdsJson`.** The designer is never also a reviewer of their
> own revision. This is checkpoint 003 §7.1 and ADR 0021 §Consequences, and it is the field
> `designReviewRequest` turns into `excludedExecutionIds`. **It is checkable the moment `designContract`
> 5 has a schema, and it is not checkable today** — which is why row 5 is on this list at all.

#### 3.5.2 Canonical form — the precondition for diffing

A schema alone does not make two encodings comparable. Four normalisation rules, applied **on write**,
so the stored value is already canonical and never has to be normalised twice:

1. Object keys sorted lexicographically at every level.
2. Arrays sorted by the declared sort key of the row above.
3. No insignificant whitespace.
4. **`fidelityAnchorSchemaVersion text NOT NULL` on `design_revision`** — a new column. Without it a
   schema change silently reinterprets every row already stored, and the anchor becomes a second
   undecidable document.

#### 3.5.3 Validated on write, failing closed

The validator runs in `DesignGovernanceStore` on the write path, and **fails closed**: a revision that
does not validate **is not persisted**. Not persisted-then-flagged — that is the same
`notExecuted`-counts-as-satisfied class §3.5's validator requirement rules out, and a flagged row is
readable by a reader that never checks the flag. A **read** of a legacy row that predates the schema and
fails validation reports `schemaInvalid`; it is never silently returned as valid.

#### 3.5.4 The comparison basis — what an implementation is diffed against

This is §3.5 item (3), and it is where §6's `qaPassed` work attaches. Against the same approved
revision, the implementation's recorded evidence must yield the same sets:

| Diff | Revision says | Implementation's evidence must say | A mismatch is |
|---|---|---|---|
| `{boardId} → set(routes)` | `boardSet` | the routes/files that render that board | a **missing surface** — a defect under ADR 0021 §2 |
| `{boardId} → set(stateKeys)` | `stateSet` | the states rendered for that board | a **missing state** |
| `set(breakpoints)` | `responsiveSet` | the breakpoints actually implemented | a **missing responsive target** |
| `set(executionIds)` ∩ `designerExecutionId` | `executionIdSet` | who reviewed it | **an independence violation** — escalate, never auto-resolve |

**And the operator's rule, which is not optional:** where the **schema** and the **Penpot board**
disagree, **the disagreement is itself a finding.** It is not resolved by picking a winner, and it is
not a build failure — it is reported, because it means one of the two records of the approved design
is wrong and the platform does not know which.

#### 3.5.5 What this closes, and what it does not

**Closes:** U-3's content question, and §3.3's central finding becomes decidable. **Still open and
named:** the schema's **owner** (this design proposes `workflow_engine`, since that is where guards
live — an architecture call), the **build order** relative to §9 step 1, and **how**
`WorkspaceDeltaProbe`/`GitWorkspaceInspector` — which the approved QA artifact already records as
undecided, and which live in different packages — obtain the implementation side of §3.5.4. Those stay
in §7 as U-3's residue.

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

**(c) The same id in the transition context.** `planned → designRequired` — and, after §4.4/R2,
`designParked → designRequired` — is guarded by `designContractExists()`, which reads
`context['designContractId']`. So the walk passes that id in `context` **and** on the column — **the
same value**, because it names a row that exists.

> **CORRECTION (rev 2).** Revision 1 specified this step as a `planning → planned → designRequired`
> walk in lane E. Under R2 (§4.4) that walk is **not** what releases the item: lane E parks at
> `designParked`, and the release is `designParked → designRequired` taken by the **readiness
> reconciler** once steps 1–2 have landed — not by lane E racing the triage scheduler.
> `designContractExists()` is still on that path, so (c) is unchanged in substance and changed in
> which edge carries it.

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
| **R2 (PRIMARY)** | Give design-remediation items their own park state (`designParked`) instead of `planned`. | A new state + edges, permanently. An architecture-lane enum addition. |
| **R1 (later simplification)** | Let the item rest at `planned` and rely on lane E winning the race to `designRequired`. | **Best-effort only — no atomicity guarantee exists.** The race is lost in normal operation. |
| **R3** | Make the triage entry probe category-aware for remediation items. | **Rejected.** The scheduler is category-blind *by construction*, and `triage_defect.dart:60-88` documents that blindness as the thing the park state was built to survive. Weakening it re-opens the original collision. |

> **CORRECTION (rev 2) — R1 is demoted to fallback, because its premise is false.**
> Revision 1 recommended R1 on the claim that mounting the scheduler and landing (a)–(c) makes
> "`planned` … stop being reached". **It cannot stop being reached.** `planning`'s only out-edges are
> `planned` and `cancelled` (`work_item_transitions.dart:17-23`) — there is no `planning →
> designRequired`, and none can be added, because `planned`'s **sole** predecessor is pinned as
> `planning` by name (`planned_entry_state_hop_test.dart:467-497`). Every design-remediation item
> therefore rests at `planned`, and `planned → designNotRequired` is guarded by
> `actorAllowed([orchestrator])` **alone** (`work_item_transitions.dart:28-30`) — it fires regardless
> of whether a contract exists. R1 is a race, and the tree loses it.

#### 4.4.1 Why no guard can close R1's race

A guard on `planned → designNotRequired` that spared design-remediation items would have to tell a
remediation item from a feature item. **It cannot.** `GuardCondition.evaluate` receives
`(WorkflowState from, WorkflowState to, Map<String, dynamic>? context)`
(`guard_conditions.dart:141-145`) — **states and a caller-supplied context, never the `WorkItem`.**
The one caller that would need to discriminate is the scheduler, and its context is a fixed
`{agentAvailable: true, capabilitiesMatch: true}` (`entry_hop.dart:118-121`). So a discriminating guard
would require changing the guard signature across `workflow_engine` — at which point the probe is
category-aware, which is R3, rejected above on the tree's own evidence.

#### 4.4.2 The atomicity guarantee under R1: **there is none, and none is available**

Lane E's `planned → designRequired` and triage's `planned → designNotRequired` are **two independent
compare-and-swap writes against the same row**, taken by two different components on two different
ticks. Nothing in the tree joins them into one transaction, and nothing orders them. Stating this
plainly is the whole correction: **R1 provides a best-effort race, not a guarantee**, which is why it
is a fallback and why R2 is primary.

#### 4.4.3 The lost-race behaviour under R1 — required, and never a silent continue

If triage wins, lane E's transition is rejected (CAS loss) and **the item is no longer at `planned`**.
Its state is then `designNotRequired`, and **what happens there is verified, not assumed**:

- `designNotRequired` has **exactly one** out-edge: `designNotRequired → agentExecuting`, guarded
  `actorAllowed([orchestrator])` + `agentAvailable()`
  (`work_item_transitions.dart:151-153`).
- There is **no** `designNotRequired → implementationReady` edge, and the **mounted** implementation
  lane dispatches from `{implementationReady}`, **not** from `designNotRequired`
  (`implement_feature.dart:114`; wired at `server.dart:721` as `sched-impl`).
- **No definition in the package lists `agentExecuting` in `entryStates`** — verified exhaustively
  across all seven. (`defaultImplementFeatureDefinition`, the one that does list `designNotRequired`,
  is declared "registered for the demo and used by fixtures" (`scheduler.dart:3194-3200`) and is
  **not referenced anywhere in `apps/server/lib/`.**)

**So the lost-race outcome is a stall, not a wrong dispatch — and that is the correct reading.** The
item sits at `designNotRequired` with **no mounted definition able to move it**, while carrying a
durable, false record: *no design work is required*, asserted by the triage lane over a defect that
is a design defect. It is also, exactly, the convergence loop of §1.1 — the item is re-dispatched to
triage and taken out to `designNotRequired` again, forever.

*(Correction lane: this subsection initially asserted the lost race "enters implementation". That was
wrong and was caught by checking `implementFeatureDefinition.entryStates` rather than reasoning from
the name. The verified consequence is stated above.)*

The required behaviour is therefore:

- **Re-read the item.** Never retry the transition against a state the item no longer holds.
- **Never re-drive `designNotRequired → designRequired`.** That would overturn a triage verdict the
  scheduler made on evidence this lane cannot see, and would mask the stall rather than report it.
- **Record a named, terminal, operator-visible refusal** — `blockedBy:
  DESIGN_GOVERNANCE_RACE_LOST`, carrying the observed state and the two competing transitions —
  and stop. This is lane E's existing refusal shape (`design_governance_runtime: 'unavailable'`).
- **Never report success.** A lane that lost this race has not run the design lane, and the item is
  now both stalled and mis-recorded. Both facts must be visible.

#### 4.4.4 R2 specified — the structural fix, reconciled with §2.4 pt 2

**§2.4 pt 2 demands structural closure, and R2 is the only option that provides it.** R1 closes the
*approach* by winning a race; R2 closes it because the parked state **is in no definition's
`entryStates`**, so no scheduler can see, probe or hop the item while it waits — the same property
`featureIntakeParked` was built for (`work_item_transitions.dart:34-50`).

| # | R2 requires | Verified against the tree |
|---|---|---|
| **R2.1** | New `WorkItemState.designParked`, in **no** definition's `entryStates`. | `featureIntakeParked`'s exact property (`work_item_transitions.dart:34-38`). Being in no entry set is what makes it a park: the drift guard only visits declared entry states (`entry_hop_drift_guard_test.dart:50-56`), so it adds no new obligation. |
| **R2.2** | `planned → designParked`, guarded `actorAllowed([orchestrator])`. | Does **not** add a predecessor to `planned`; `planned`'s sole-predecessor pin is untouched (`planned_entry_state_hop_test.dart:467-497`). The successor assertion is `containsAll`, not `equals` (`:489-495`), so a third successor is not a break. Mirrors `planned → featureIntakeParked` (`:31-33`). |
| **R2.3** | `designParked → designRequired`, guarded `actorAllowed([orchestrator])` + `designContractExists()`. | **Only after D-5 lands**, because that guard must read the durable column, not caller context (§4.3). This edge is the release and it is why the item is not a dead end — the defect `featureIntakeParked`'s own comment says it exists to end (`work_item_transitions.dart:36-38`). |
| **R2.4** | `designParked → waitingForHumanDecision` for operator recovery. | Mirrors `featureIntakeParked`'s operator route (`:51-56`), "slower and deliberately so". |
| **R2.5** | `designParked` **must not** be reachable from `agentFailed`. | `Scheduler._returnTargetsFrom` derives the retry-return target by probing **every** entry state and refuses on a second answer (`scheduler.dart:1420-1435`); `retry_return_to_entry_state_test.dart:733-735` records this exact reasoning for `planned`. Since `designParked` is in no entry set it cannot be a target at all — the constraint holds by construction, and the implementer must keep it that way. |

**Who releases it.** Because nothing dispatches from `designParked`, no scheduler hop can move it.
The release is R2.3 taken by the **runtime's readiness reconciler** (§9 steps 1–3), which reads the
durable `designContractId` and, when it is non-null, transitions `designParked → designRequired`. That
is **the atomicity guarantee R1 lacks**: while the item is parked, it is invisible to every scheduler,
so there is no competing write and no window.

**Consequence for §4.6.** Until R2.3 can be taken, a remediation item parks at `designParked` — and
`planned` stops being a holding state for this lane entirely. §4.6's item-state line changes
accordingly.

**R1 is retained, and demoted.** Once R2.3 lands and the release is deterministic, the interim
`planned` route is a simplification worth taking only if `planned` is simultaneously removed from
`triageDefectDefinition.entryStates` — which `triage_entry_state_drift_guard_test.dart` and
`retry_return_to_entry_state_test.dart:720-736` both pin, and which is therefore **not this lane's
call**. It is recorded, not scheduled.

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
- Item state: **`designParked`** (§4.4 R2) — **and, per G-7, `planned` is not safe to wait in.** §4.4.

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

  **This design specifies BOTH of the following. Neither alone is sufficient, and revision 1
  specified only the first — which is why that revision was wrong.**

  **(a) The re-design edge** in `work_item_transitions.dart`:

  ```dart
  // REQUIRED — the re-design route. `designRejected` is a HUMAN verdict, and
  // re-running the designer is what a rejected design asks for.
  // Guard set derived from this table's own convention for an edge into a
  // dispatchable entry state: `actorAllowed([orchestrator])` alone.
  //   - `agentAvailable()` belongs on `-> agentExecuting` edges only; this edge
  //     asserts no execution is starting, and capacity is JobCapacityGuard's.
  //   - No evidence guard: `designRejected` carries a decision already, and a
  //     guard the caller cannot satisfy makes the edge unreachable — the same
  //     reasoning as `agentFailed -> designRequired` (:288-290).
  (WorkItemState.designRejected, WorkItemState.designRequired): [
    GuardConditions.actorAllowed([ActorType.orchestrator]),
  ],
  ```

  **(b) The probe target** on `designRevisionDefinition` — §2.1's seventh field:

  ```dart
  entryProbeTargets: {
    WorkItemState.designRejected: WorkItemState.designRequired,
  },
  ```

  **Why (b) is not optional, verified in code, step by step.** Two *independent* components decide
  whether a `designRejected` item can be dispatched, and the edge feeds only one of them:

  | # | Component | What it does with an entry state | With the edge and **without** (b) |
  |---|---|---|---|
  | 1 | `RunnableWorkEvaluator` | `policy.evaluate(from: item.state, to: definition.probeTargetFor(item.state), …)` (`runnable_work.dart:187-193`), where `probeTargetFor` is `entryProbeTargets[entryState] ?? targetState` (`:98-99`) and `targetState` defaults to `agentExecuting` (`:46`). | Probes `designRejected → agentExecuting`. **No such edge ⇒ `noAction` (`:194-196`). Never enqueued.** |
  | 2 | `EntryHopper.prepare` | Reads `_definition.entryProbeTargets[current.state]` **directly** (`:181`) and returns `refused` when it is null (`:182-195`). Its own comment (`:169-175`) states it must use `targetState` and **"NEVER `probeTargetFor`"**, because the probe target is the hop it is deciding whether to take. | **No declared hop ⇒ `refused`, with the reason "no route to agentExecuting exists … and the definition declares no intermediate hop for it."** Even had component 1 passed, the item would never be moved. |

  The comment above `designRevisionDefinition` claims that growing the edge is enough — *"the moment
  `workflow_engine` grows a `designRejected -> designRequired` edge … the probe accepts it and design
  revision resumes with no change here"* (`scheduler.dart:3242-3248`). **That is the code's own
  comment being incomplete, and revision 1 cited it as authority.** The comment is right about
  component 1 and silent about component 2, and component 2 reads a different field.

  **With both (a) and (b), the full chain is verified against `EntryHopper.prepare` step by step:**
  `_edgeExists(designRejected, agentExecuting)` is false (`:176-177`) ⇒ not `direct`; `declared =
  designRequired`, non-null (`:181`) ⇒ not the null refusal; `_refusalFor(item, designRequired,
  agentExecuting)` (`:276-298`) passes **both** of its checks — `_canTransition` succeeds because edge
  (a) exists and `actorAllowed([orchestrator])` is satisfied by `schedulerOrchestratorActor`, and
  `entryStates.contains(designRequired)` is **true** because `designRequired` is already in
  `designRevisionDefinition.entryStates` (`:288`) — so it performs the hop (`:207-226`); and component 1
  now probes `designRejected → designRequired`, which is valid ⇒ `runnable`. This is precisely the
  `reviewRejected → designNotRequired` shape already shipped in `triage_defect.dart:132-135`.

  **Why not the simpler `designRejected → agentExecuting` edge instead?** It would satisfy both
  components (`prepare` returns `direct` at `:178`), and it is rejected on substance: it would take the
  item from a human verdict **straight to execution**, bypassing `designRequired` — and with it every
  precondition in §3.1, including **P1**, the check that a real `design_contract` row backs the item.
  Routing through `designRequired` keeps the hop visible in the transition table, which is the sole
  authority for all work-item movement (AGENTS.md §1), and keeps the design lane's entry conditions
  load-bearing.

  **Why this is safe against the one-reachable-entry-state rule — verified, not deferred.** Revision 1
  told the implementer to re-verify this; this lane has now done it. `Scheduler._returnTargetsFrom`
  derives the retry-return target by probing **every** entry state from the failure state and refusing
  on a second answer (`scheduler.dart:1420-1435`). From `agentFailed`, `designRevisionDefinition` is
  asked about `designRequired` (edge exists, `work_item_transitions.dart:288-290`) and `designRejected`
  (**no edge exists** — `designRejected`'s only out-edge today is `→ designInReview`, `:127`). The new
  edge is **from `designRejected`, not from `agentFailed`**, so it adds a route out of an entry state
  without adding a second answer to the retry derivation. `retry_return_to_entry_state_test.dart:740-743`
  pins the entry set by name and is unaffected.

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

### 5.6 The interim risk default — **DECIDED: every revision is HIGH**

> **Gate D4: RESOLVED by human decision `a1c7d904-3b8e-4f21-9d6e-5c2f81b7a390`.** Decision D4:
> **until a `DesignRiskPolicy` exists, every design revision is HIGH tier and requires human design
> approval.** The accepted cost is recorded, not minimised: *a trivial copy-tweak waits on a person.*

**Why F-B was rejected.** Classifying from checkpoint 003 §9.2–§9.4 prose was rejected because that
document **declares the question unsettled** (§9.5: the thresholds are NOT finalized) and because the
data-not-hard-coded rule is mandatory — stated as *§9.6 "Risk policy MUST be DATA, not hard-coded
control flow"* in **checkpoint 003**, and independently as *"`DesignRiskTier` + `DesignRiskPolicy`
(data, not code) drive human gate"* in **ADR 0021 §6** and its **Consequences**.
*(Correction lane: revision 1 and both metadata files attributed §9.6 to ADR 0021. ADR 0021 has
sections 1–8 only — §9.6 is checkpoint 003's. Re-cited here and in both metadata files.)*

**What this decides, precisely:**

| Tier | Path (§5.3) | Effect under D4 |
|---|---|---|
| LOW | → `approved`, no gate | **UNREACHABLE.** Every revision is HIGH. |
| MEDIUM | policy-dependent | **UNREACHABLE**, and its ungated/gated split is moot. |
| HIGH | → blocking `designApproval`, mandatory | **Every revision, unconditionally.** |

So the interim rule is **one row of §5.3's table**, taken unconditionally: *after the review verdict is
durable, the platform raises a blocking `HumanDecision(designApproval)` for every revision, from the
review-result recorder, with no policy evaluation in the path.* That last clause is what makes it
implementable before `DesignRiskPolicy` exists — **there is no policy call to make, so nothing has to
be faked**.

**Blast radius, as the decision states it.** This blocks **step 5 only** (§9). The other nine build
steps — the contract table, the D-5 guard change, the park state, the fidelity schema, the producer,
the re-design edge, the scheduler mount, the raiser — are **unaffected** and proceed in order. Step 5
here means *implementing `DesignRiskPolicy` and its tier evaluation*; that work is now **deferred
behind a rule that needs none of it**, which is why the decision does not block the build.

**What D4 does NOT settle.** `DesignRiskPolicy` still does not exist (G-F). HIGH-by-default is a
**standing platform rule**, not a temporary default with an expiry — it stops being right when a
policy lands, not when someone remembers. §4.5's required shape and §9's step 5 remain, and U-2 (MEDIUM
thresholds) and U-7 (how the policy is seeded) remain open. **Q4 stands as written** — `riskTier` is
set by policy evaluation or, until then, by this rule — and it is now *satisfiable*, which it was not
before: revision 1 could not have implemented Q4 at all.

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
| **U-3** | **RESIDUE ONLY — content decided.** §3.5 now specifies the schema's content: one committed, versioned document, six named subschemas, canonical form, fail-closed write validation, and the comparison basis. **Three residue items remain:** the schema's **owner** (proposed `workflow_engine`, where guards live — an architecture call); its **build order** against §9 step 1; and **how** `WorkspaceDeltaProbe` / `GitWorkspaceInspector` — which the approved QA artifact already records as undecided and which live in **different packages** — obtain the implementation side of the §3.5.4 diff. | These are build-sequence and ownership questions, not schema-content questions, and none is answerable from this artifact without an architecture ruling. |
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
| **D-4** | **No `maxAttempts`-exhaustion → human route for the design lane** (§2.3), contrary to checkpoint 003 §10.4. **Correction lane: additionally, a test already claims this coverage and does not provide it** — `packages/scheduler/test/design_job_test.dart:614-698` is named `'design revision maxAttempts=3 exhaustion triggers human decision'` yet **creates, raises and asserts no human decision at all.** It enqueues a job, drives `scheduleRetry` to attempt 3, and asserts only `RetryPolicy().canRetry(...)`; its own comment concedes "Here we verify the policy behavior directly" (`:695`). **This is the exact vacuous-pass class §9 forbids and acceptance criterion A7 rejects: a green test whose name asserts a behaviour it never exercises.** Either it must be renamed to what it actually asserts, or completed to raise and assert a real `designApproval`/exhaustion decision. **Named as part of this correction; not fixed here** — test source is `PROHIBITED_PATHS`. | New `FOLLOW_UPS` entry. |
| **D-5** | **`designContractExists()` reads caller-supplied context, not the durable column** (§4.3) — satisfiable by any caller passing a string. Shared with `planned → designRequired` for **all** categories. | Architecture-lane candidate; wider than this feature. |
| **D-6** | **The parked item is not in `planned` only by luck — `planned` is a triage entry state** (G-7, §4.4). Any future lane that parks there inherits the convergence. | New `FOLLOW_UPS` entry. |
| **D-7** | **ADR 0021 §3 names `ControlPlaneService.createDesignRemediationWorkItem()`; no such method exists.** The only reference to that name in the tree is a doc comment in `design_remediation_request.dart:11`. The implementation is `DesignRemediationWorkItemProvisioner.ensurePersisted()`. A `CONTRADICTION` between an accepted ADR and the code it governs. | New `FOLLOW_UPS` entry; ADR amendment is a human/architecture action. |

### 8.1 Executable persistence — specified, not written

`LEARNING_POLICY.md:8` and `:260` prefer **executable** knowledge over prose. **D-1, D-2, D-3 and D-5
are each falsifiable today by a test that would fail**, which makes them the wrong shape to carry as
prose alone: a finding nobody can run rots, and a finding that fails on every run cannot be quietly
forgotten. **Test source is `PROHIBITED_PATHS` for this lane, so these are specified, not written.**

| Finding | The failing test to write | Its failing input |
|---|---|---|
| **D-1** dedupe burns its key | `enqueueIfAbsent` called twice with `designRevisionDedupeKey` for one item after a first job is **terminal** | Second call returns the **first** job instead of a new one ⇒ the correction loop never runs. |
| **D-2** `designRejection` admitted by nothing | For each `HumanDecisionType` value, assert it resolves to a non-null `targetFor` | `HumanDecisionType.designRejection` ⇒ `null` ⇒ a decision resolves to no target. |
| **D-3** unbounded escalation | Resolve a `designApproval`/`rework` decision with `context` carrying no `maxEscalation` | Passes ⇒ the guard bounds nothing; the sole supplier returns `-1` (`durable_workflow_engine.dart:1047-1052`). |
| **D-5** `designContractExists` reads caller context | Transition `planned → designRequired` with `context: {'designContractId': 'anything'}` on an item whose `designContractId` column is `NULL` | Succeeds today ⇒ the guard is satisfied by a string, not by a row. |
| **D-4** vacuous test (§8) | Assert a human decision exists after `maxAttempts` exhaustion | `design_job_test.dart:614-698` is green with **no** decision raised. |

**The first four are also the falsifiers §3 and §4 already name.** Persisting them as tests is not new
work; it is the same assertion written where it cannot rot. **Routed for an implementation lane to
write — this lane proposes them and writes none.**

---

## 9. Build order — and why mounting the scheduler is **not** step 1

Each step is a precondition of the next. **The order is load-bearing, not preference.**

| Step | Delivers | Why it cannot move earlier |
|---|---|---|
| **1** | `design_contract` migration + `DesignContractStore` + builder (§4.2a) | Without a real row, `designRequired` is the fabrication lane E removed. |
| **2** | `designContractExists()` reads the durable column (§4.3) | Without it, step 1's row and a fabricated string are indistinguishable. Also gates R2.3. |
| **3** | **`designParked` + R2.1/R2.2/R2.4 edges; lane E parks there instead of `planned` (§4.4.4)** | Depends on nothing but must land before any item parks for design again. **This is the corrected step 3** — revision 1 put the race-dependent R1 walk here. |
| **4** | **Fidelity anchor** schema + validator (§3.5, Q7) | Must precede *switching on*. Building the scheduler first would produce unverifiable revisions that look governed. |
| **5** | `DesignRiskPolicy` + tier evaluation (§4.5, §5.6) | Q4 needs a policy to evaluate. **Deferred, not blocking**: decision D4 makes every revision HIGH until this lands, which needs no policy call. |
| **6** | The producer: run `designRevision`, write the `DesignRevision`, stamp metadata (Q1–Q3, G-B, G-E) | Depends on 1–5 for its pre/postconditions to mean anything. |
| **7** | `designRejected → designRequired` edge **AND** `entryProbeTargets: {designRejected: designRequired}` — **both, never one** (§5.4) | Without it, a rejected design is a human-stranded item — and it is only reachable once step 9 can raise a rejection. |
| **8** | Mount `sched-design-revision` (+ `sched-design-review`) in the composition root (G-A) | Depends on 6. **Mounting earlier is the specific mistake this table exists to prevent.** |
| **9** | Raise `designApproval` on the resolved tier (G-C, §5.3) | Last: a gate with no producer behind it is a gate nothing reaches. |
| **10** | Fix D-1 (dedupe suffix) before the first correction loop; **rename or complete the vacuous D-4 test** | Not blocking the first run; blocking the second, and blocking an honest suite. |

**Step 4 is the one most likely to be skipped and the one that matters most.** `92d567e3`'s own lesson
is that a gate which passes vacuously is worse than no gate — and an unvalidatable `DesignRevision`
produces exactly that, one layer up. **D-4 is the same lesson already present in the tree today**, in a
test that passes green while asserting something its name does not.

---

## 10. Traceability and self-assessment

**Requirements covered**

| Requirement | Where |
|---|---|
| `JobDefinition` — all fields incl. the seventh (`entryProbeTargets`), and why `designRequired` | §2.1, §2.4 |
| Falsifiable pre/post conditions, each with a failing input | §3.1, §3.2 |
| The fidelity gap behind ADR 0021 §2 — all **six** blob columns | §3.3 |
| **The fidelity anchor's schema content, decided** (U-3) | §3.5.1–§3.5.4 |
| `designApproval` — no new type, choices, approve/reject/rework, routing out of `designInReview` | §5.1–§5.4 |
| **The re-design remedy: edge AND probe target, both required, honour-chain traced** | §5.4(a)/(b) |
| Boundary change; what the runtime supplies; what the item records meanwhile | §4.2–§4.7 |
| **The `planned` convergence defect: structural fix, atomicity, lost-race behaviour** | §4.4, §4.4.1–§4.4.4 |
| Interim risk default (Gate D4 — **resolved**) | §5.6 |
| `qaPassed` interaction, not reopened | §6 |
| Undecidable, stated not guessed | §7 |
| Findings routed, not self-edited; executable persistence specified | §8, §8.1 |
| Review findings, each dispositioned | §12 |

**Requirements gaps:** G-1 … G-5 in `design-revision-metadata.yaml`; U-1 … U-7 in §7 (**U-3 reduced to
three residue items** — schema owner, build order, and the implementation-side diff).

| | | |
|---|---|---|
| `design_system_compliance` | **UNKNOWN** | This lane designs a **runtime**, not a UI. It specifies no tokens, components, or visual change, so there is nothing to assess against the design system. **The fidelity anchor** (Q7, §3.5) is where design-system conformance becomes checkable — its content is now decided, including the `breakpoint` vocabulary that ties it to the product's declared design-system revision. `UNKNOWN`, not `PASS`: passing would claim a compliance this design has no standing to judge. |
| `ux_accessibility_score` | **UNKNOWN** | Same reason. No user-facing surface is designed here. Checkpoint 003 §9.4's HIGH criteria (human-authority UI) mean this runtime *governs* such surfaces — it does not design them. The §3.5 schema constrains the review vocabulary (`contrast`, `a11y` dimensions in `reviewScope`) without asserting any conformance. |

> **RECORDED DEVIATION (correction lane).** `DESIGN_GOVERNANCE.md:81-82` defines both fields as
> `PASS | PARTIAL | FAIL`. **`UNKNOWN` is not in that enum**, and revision 1 recorded it bare, which
> left an out-of-enum value indistinguishable from an oversight. It is recorded here deliberately:
> `UNKNOWN` is used because neither `PASS` (claiming a conformance this design cannot judge) nor
> `FAIL` (asserting a defect in a surface it never designed) is honest for a runtime artifact. **This
> is a deviation from the documented shape and is surfaced for the Manager**, not silently adopted —
> if the governance doc should instead read `PASS | PARTIAL | FAIL | UNKNOWN`, that is a
> `docs/engineering/` change this lane does not own.

| | | |
|---|---|---|
| `implementation_feasibility` | **MEDIUM** | Feasibility of §2–§5 is **HIGH** — the definitions, stores, tables, transitions, routing and gates all exist; the work is wiring plus the missing producer, and §5.4's remedy is now verified against the code that will honour it. **§4.4/R2 is MEDIUM** — a new `WorkItemState` is an architecture-lane enum addition plus five edges, all verified against existing pins. **§3.5's anchor is MEDIUM** — its content is decided, but owner and the implementation-side diff remain open. §5.6's human gate is **resolved**, not pending. The MEDIUM is the honest aggregate, not an average that hides the low part. |

**Risk rationale:** Level 3 per `DESIGN_GOVERNANCE.md:88-96` — this governs a **core workflow stage that
does not exist**, changes the meaning of four states, and adds an edge to the one authority table that
governs all work-item movement (AGENTS.md §1). Comparable to the approved `qa-contracts-feature-remediation`
artifact, which was likewise Level 3.

**This revision requires `HUMAN_DECISION_REQUIRED`** at Gate D4, on the single question in §5.6.

---

## 11. References

ADR 0021 · Checkpoint 003 §7, §8, §9, §10, §11 · Checkpoint 002 §12.4, §16 · `AGENTS.md` §1, §12, §13 ·
`docs/engineering/DESIGN_GOVERNANCE.md:75-96` · `docs/engineering/LEARNING_POLICY.md:8, 260` ·
`design/qa-contracts-feature-remediation/` (read-only) ·
`work_item_transitions.dart:14-56, 58-129, 127, 174, 195, 288-293, 732-744` ·
`runnable_work.dart:38-50, 46, 63-99, 187-196` · `entry_hop.dart:118-121, 163-226, 176-195, 276-298` ·
`scheduler.dart:1420-1435, 3200, 3207-3248, 3255-3265` · `triage_defect.dart:122-138` ·
`guard_conditions.dart:91-154, 136-174, 521-552` · `durable_workflow_engine.dart:59-89, 1047-1052` ·
`human_decision.dart:1-44` · `human_decision_routing.dart:85-247` ·
`design_revision.dart:52-66` (platform_contracts) ·
`migrations/20260920232118956/definition.sql:186-211` ·
`planned_entry_state_hop_test.dart:455-509` · `entry_hop_test.dart:395-426` ·
`entry_hop_drift_guard_test.dart:40-130, 370-400` · `retry_return_to_entry_state_test.dart:720-789` ·
`design_job_test.dart:614-698` ·
`lane_e_design_remediation_work_item.dart:137-208, 318-332, 385-401, 626-649`

---

## 12. Review findings — disposition

`design-DESIGN-GOVERNANCE-REVIEW-1` returned `DESIGN_REVIEW_CHANGES_REQUIRED`,
`CORRECTION_REQUIRED: YES`, risk level 3 agreed. **Every finding is dispositioned below. Nothing was
absorbed silently and nothing the reviewer confirmed was "fixed".**

| # | Finding | Disposition | Where |
|---|---|---|---|
| **BLOCKER-1** | §4.4 R1 does not resolve G-7; `planned` must rest and `planned → designNotRequired` is unguarded; R1 leaves a race with no specified lost-race behaviour. | **CORRECTED.** R1 demoted to fallback with its premise falsified in code; **R2 promoted to primary and fully specified**; atomicity guarantee stated (**none exists under R1**, with the mechanism); lost-race behaviour specified as a named terminal refusal. Reconciled with §2.4 pt 2. | §4.4, §4.4.1–§4.4.4 |
| **BLOCKER-2** | §5.4's edge alone changes nothing; `RunnableWorkEvaluator` still probes `designRejected → agentExecuting` and `EntryHopper.prepare` reads `entryProbeTargets` directly and refuses. | **CORRECTED.** Both the edge **and** `entryProbeTargets: {designRejected: designRequired}` are specified, with the honour-chain traced step by step through `EntryHopper.prepare`. §2.1's six-field table amended to seven. The `scheduler.dart:3242-3248` citation is corrected. | §5.4(a)/(b), §2.1, §2.4 pt 3 |
| **HIGH-1** | D-4 understated; `design_job_test.dart:614-698` is a vacuous test already claiming coverage. | **CORRECTED.** D-4 now names the vacuous test as part of the finding, and §9 step 10 carries the rename-or-complete obligation. | §8 D-4, §8.1, §9 |
| **MEDIUM-1** | Gate D4's cited authority does not exist — ADR 0021 has §1–§8 only; §9.6 is checkpoint 003's. | **CORRECTED** at every site: `design-revision.md` §5.6, `design-revision-metadata.yaml`, `design-brief-metadata.yaml`. | §5.6 + both metadata files |
| **MEDIUM-2** | Q7 names four blob columns; `reviewScopeJson` is equally unvalidated. | **CORRECTED — and understated by the review too.** The tree has **six**: the four named, plus `reviewExecutionIdsJson` (`NOT NULL`, `:201`) and `reviewScopeJson` (nullable, `:204`). Both are now tabled with what each permits. | §3.3, Q7, §3.5 |
| **LOW (a)** | `UNKNOWN` is outside the `DESIGN_GOVERNANCE.md:81-82` enum; record the deviation. | **CORRECTED** — recorded explicitly as a deviation, with the reason and routed for a `docs/engineering/` decision this lane does not own. | §10 |
| **LOW (b)** | "eight test files" undercounts. | **CORRECTED** — **14** test files reference the lane, **12** pin `designRevisionDefinition` by name, with the two data-layer-only files named. | §2.1 |
| **LOW (c)** | `LEARNING_POLICY` prefers executable persistence; D-1/D-2/D-3/D-5 are pin-able today. | **CORRECTED** — §8.1 specifies five failing tests with their failing inputs. **Specified, not written** — test source is `PROHIBITED_PATHS`. | §8.1 |

**Confirmed by the review and deliberately untouched:** the three premise corrections; the G-A…G-F gap
set; G-7's convergence claim; Q7's "no validator anywhere"; Q3's falsifier; D-5; D-2; D-3; the parked
item not being claimed; §6's handling of `qaPassed`.

**Two operator decisions incorporated** (`a1c7d904-3b8e-4f21-9d6e-5c2f81b7a390`): **D4** — every
revision is HIGH until a `DesignRiskPolicy` exists, Gate D4 now **RESOLVED**, blocking step 5 only
(§5.6); **U-3** — both anchors with named roles, disagreement between them is itself a finding, Penpot
alone rejected because `penpotFileId`/`penpotPageId` are nullable, and **the schema content decided**
(§3.5).