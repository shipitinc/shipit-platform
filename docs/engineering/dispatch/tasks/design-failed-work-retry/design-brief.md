# Design Brief — "Restart after a problem": the operator screen for a failed work item

| Field | Value |
|---|---|
| `brief_id` | `5471fea4-accf-47be-a1a0-cee7d47a5daa` |
| `version` | **`1.5.0`** (mechanical correction pass — re-review of 1.4.0, **0 blockers**) |
| `status` | `UNDER_REVIEW` |
| `risk_level` | **3** (re-confirmed at 1.2.0 — see §12) |
| `branch` | `main` (design-only lane; no production file is modified) |
| `base_sha` | `4dc9c5e4e2dfe043132e048234cd4bb4dee96d65` |
| `head_sha` | `4dc9c5e4e2dfe043132e048234cd4bb4dee96d65` |
| `created_by` | `design-agent` |
| `created_at` | `2026-10-11T12:49:42Z` |
| `closeout_at` | `2026-10-11T13:40:00Z` (1.1.0) |
| `corrected_at` | `2026-10-11T15:10:00Z` (1.2.0) |
| `hd4_closeout_at` | `2026-10-11T17:20:00Z` (1.3.0) |
| `corrected_at_1_4` | `2026-10-11T18:40:00Z` |
| `corrected_at_1_5` | `2026-10-11T20:05:00Z` |

> ### ⚠️ READ FIRST — §6.6 is SUPERSEDED by HD-5, 2026-10-12
>
> This brief carries a **human decision record** — `.decisions/8585491a-11a9-473e-ae4f-d66a210408f3.yaml`
> (HD-5) — that **supersedes HD-3 (`5d9a1f62`) in full**. HD-3 required operator retry to **fail closed**:
> three retries per work item, and if `SHIPIT_OPERATOR_MAX_RETRIES` was unset the retry action was not
> offered at all.
>
> **Under HD-5, operator retry is UNCUNTED by default.** An unset, blank, unparseable or negative value
> resolves to uncounted and the action **is** offered; an explicit `0` still disables it; an explicit
> positive integer still caps it, counted per work item as HD-3 counted it. **AUTOMATIC retries are
> unaffected** — still bounded by the job's own `maxAttempts` via `RetryPolicy.canRetry`.
>
> **Every clause this brief states about the retry-count bound is marked SUPERSEDED in place, with a
> pointer and a reason. Nothing has been deleted.** The affected sites are §6.6 (heading, bullets and
> rationale), §6.6.1, the §6.3 `notConfigured` unset row, the §8 unset panel variant, A11, N14, AC-15b,
> AC-15c, AC-15d, the §12 retry-storm and unset-variable risk rows, the §13.1 HD-3 record, the change
> ledger, and the §2 premises note. **§6.6's banner is the single authoritative summary.**
>
> **If you are about to implement anything in §6, read the banner at §6.6 before you read the clause.**
> A superseded clause below it still says what HD-3 said, in HD-3's words, and it is there deliberately:
> the audit trail has to show the reversal rather than two apparently current answers to one question.

> ### 1.5.0 — re-review of 1.4.0: `CHANGES_REQUIRED`, **BLOCKERS: 0**
>
> The reviewer's verdict: *"the brief's design is finished — I found no defect in what gets built.
> Every one of the six required edits is a label, a cross-reference, or a count."* **Nothing verified
> is reopened.** P-1, P-2…P-6, HD-1/2/3/4, §7, §8, §9, AC-30, risk level 3 and **the AC set itself**
> are untouched — no criterion added, removed or renumbered.
>
> | | Finding | Disposition |
> |---|---|---|
> | **H-A** | §16.2 still mislabelled `metadataMerge` as `-- HD-2, unchanged`, **while the brief claimed at two sites that it had been relabelled**. | The 1.4.0 lane-box edit had **silently failed to match** — a `replace()` written without an `assert`, i.e. D-8's own failure class, committed by the lane that reported it. Lane box re-split by line index; both false completion claims now carry the correction. |
> | **H-B** | **AC-37 was assigned to no lane.** | Added to the Lane S positive list (body ASCII box, body table row, metadata `lane_s_seam`) and to §15 gap 2's current set. |
> | **H-C** | `findOperatorAction` used by normative pseudocode, **declared nowhere**; the interface gains **two** methods, not one. | Read method declared on `WorkflowStore` in §6.4.3; cost row, §6.4.5, metadata feasibility and risk all corrected. Headcount 8 unchanged. |
> | **M-A** | §16.2 ground (b) cited **AC-4**, which the brief's own panel mock **refutes**. | Replaced with **AC-1** — sound and stronger: without the edge the server-computed action set cannot offer `retry` at all. |
> | **M-B** | The `byte-identical` assertion survived at §16.3 and metadata AC-17 — **asserting what AC-29 retracts**. | Dropped at both sites; restated as review-enforced with AC-17's live tick as the behavioural proof. |
> | **L-A**…**L-E** | Seven-read-not-eight; a false ⟦SUPERSEDED⟧ claim; two pre-HD-4 parents; five *symbols* in two *files*; **D-7 cited but undefined**. | All corrected. D-7 is now a real record with a `LEARNING_POLICY` category. |
>
> ### D-8's sweep — completed, and it found a THIRD undeclared mechanism
>
> The review named two remaining instances. The sweep found **a third it had not**:
> **`jobsForWorkItem(workItemId)` matches no member of any store.** The real names are
> `JobStore.listJobsForWorkItem` (`job_store.dart:18`), surfaced by
> `ControlPlaneService.listJobsForWorkItem` (`control_plane_service.dart:1884`). Renamed.
>
> Everything else in §6.4 and §6.4.3 resolves — `readWorkItem`,
> `findTransitionByIdempotencyKey`, `appendTransitionRecord`, `isLegalTransition` are real members;
> `appendOperatorAction` and `metadataMerge` are declared in §6.4.3; `retryCount`/`configuredLimit`/
> `operatorRetryActor` are section-local names defined in §6.4.1 or §6.6. **Verified by reading
> `workflow_store.dart` and `job_store.dart` in full, not assumed** — the reviewer's statement that
> its two were the only remaining instances was itself wrong, which is the sweep doing its job.


---

## 0. Scope of this document, and ownership

This is a **design**. Proposed code appears **as text**. No production source, generated file, test,
schema, migration, or client file in this repository is modified. `git status` is unchanged for
every path outside this directory.

**Owner declaration (made before any file was written):**

| Class | Paths |
|---|---|
| `OWNED_PATHS` | `docs/engineering/dispatch/tasks/design-failed-work-retry/**` |
| `READ_ONLY_PATHS` | `packages/**`, `apps/**`, `docker/**`, `docs/**`, `.github/**`, `.decisions/**` |
| `PROHIBITED_PATHS` | `packages/**`, `apps/**`, `docker/**`, `.github/**`, `.decisions/**`, `AGENTS.md`, `docs/**` (outside `OWNED_PATHS`) |

**Docker/Compose:** 0 mutating commands issued, at 1.0.0 **and** at 1.1.0. `docker/compose.qa.yaml` was
read **as text** to learn the QA Postgres connection; state was read with read-only
`docker exec … psql -c "SELECT …"` against the live QA database. **No write, DDL, or `docker compose`
command of any kind was issued, and no live row was modified.** The 1.1.0 closeout issued **no
database command at all** — it is a paper exercise over `.decisions/**` and source already read.
AGENTS.md's shared-Docker rule and the dispatch's hard constraints are satisfied in full.

> **Note on `.decisions/**`, added at 1.1.0.** The three decision records were **read only**. They are
> already `RESOLVED` and none needed a correction, so `PROHIBITED_PATHS` was tightened to include
> `.decisions/**` rather than loosened.

---

## 1. Problem statement, with verified evidence

> **ShipIt detects that an agent execution failed, deliberately routes the work item to a human, and
> then gives that human nothing to click.** The item sits in `agent_failed` — a state with no
> dispatch entry in any `JobDefinition`, so it will never retry itself — and the operator screen
> that is supposed to receive it renders no action at all.

### 1.1 The live QA evidence (read-only, `2026-10-11`)

`work_item` — 12 rows, exactly as described in the dispatch:

```
 workItemId                        | state            | blockingHumanDecisionId | version
----------------------------------+------------------+-------------------------+--------
 defect-DEF-1791686704991884       | agent_failed     |                         |       6
 defect-DEF-1791686357139031       | agent_completed  |                         |       6
 ... (9 total at agent_completed)  |                  |                         |
 WI-feature-1791686174076431       | draft            |                         |       1
 design-remediation-DEF-...406     | planned          |                         |       3
 (12 rows)
```

The failed item's transition history:

```
 fromState          | toState          | actorType   | reason                                            | idempotencyKey
--------------------+------------------+-------------+---------------------------------------------------+------------------------------------------
 draft              | planning         | orchestrator|                                                   | triage-intake:planning
 planning           | planned          | orchestrator|                                                   | triage-intake:planned
 planned            | design_not_required| orchestrator|                                                | triage-intake:designNotRequired
 design_not_required| agent_executing  | orchestrator|                                                   | (none — the execution coordinator, §2.2)
 agent_executing    | agent_failed     | orchestrator| operator step 3: stranded by pre-fix zombie reclaim  | operator-step3:zombie-reclaim:wx-jb-…
                    |                  |             | (job jb-hn3liczxln-li36ts); reconciled to         |
                    |                  |             | agentFailed per reviewed reclaim semantics       |
```

Its only job:

```
 jobId             | jobType       | state  | attempt/maxAttempts | dedupeKey                          | activeDedupeKey
-------------------+---------------+--------+---------------------+------------------------------------+---------------
 jb-hn3liczxln-li36ts| triage_defect| failed |  1 / 2              | defect-DEF-1791686704991884:triage_defect | (NULL)
 failureJson: {"code":"executionInterrupted","kind":"permanent",
               "reason":"zombie execution reclaimed: execution wx-jb-hn3liczxln-li36ts is still
               agentExecuting, no live execution could be observed, and it has been non-terminal for
               484m (beyond the 30m bound)"}
```

### 1.2 Why the operator is shown a card and then given nothing

Three facts compose into the defect, each verified in source:

1. **The item is routed to a human on purpose.** `RunnableWorkEvaluator.evaluate` returns
   `RunnableWorkStatus.noAction` for any state outside a `JobDefinition`'s `entryStates`
   (`packages/scheduler/lib/src/policy/runnable_work.dart:83-85`), and `agentFailed` is in none of
   them. The doc comment says so in as many words: *"`agentFailed` and `reviewRejected` are NOT
   auto-enqueued: reworking a failed coding result routes through the workflow's correction/review
   gate, not an automatic LLM re-run"* (`runnable_work.dart:63-67`).
2. **The UI reads that as the operator's turn.** `PlainStatus.needsYouItFailed` is
   `"Needs you — it failed"` (`apps/control_plane/lib/core/plain_language.dart:31`) and
   `PlainStatus.isOperatorTurn` is true for it (`plain_language.dart:68-70`), so the row lands under
   the **"Needs you"** filter (`runs_page.dart:67`) and under the **"Failed"** filter
   (`runs_page.dart:69-70`).
3. **The run detail page then says the opposite.** `_RightColumn` shows
   *"Nothing needs you here / The system is still working on this run."* whenever
   `blockingHumanDecisionId == null` (`run_detail_page.dart:651-667`) — and this item has **no**
   blocking decision (the `work_item` row above; `blockingHumanDecisionId` is empty). There is no
   action panel, no restart control, no link anywhere.

So the screen states, in the same view, *"Needs you — it failed"* and *"Nothing needs you here."*
That is the repository's own doctrine violated in its own words: **a quiet screen must never be
indistinguishable from a healthy one** — here, an *actionable* screen is indistinguishable from a
*dead* one.

### 1.3 The information that would let a human decide is already durable — and already discarded

The record contains everything needed to explain the failure: the `work_item_transition.reason`
column and the terminal job's `failureJson`. Both are already read:

- `WorkflowEndpoints.inspect` returns `TransitionView(… reason: e.reason …)`
  (`apps/server/lib/src/endpoints/workflow_endpoints.dart:43-65`), the wire model has
  `reason: String?` (`apps/server/lib/src/models/transition_view.yaml`), and
  `ControlPlaneRepository.inspectWorkItem` maps it into `TransitionResponse.reason`
  (`control_plane_repository.dart:223`, `:1538-1555`).
- `SchedulerEndpoints.inspect` returns the job with its `failureJson`
  (`scheduler_endpoints.dart:46-72`).

**The run detail page throws both away.** `RunDetailBloc` builds each timeline entry from the
transition **pair** only — `plainTransitionMessage(t.fromState, t.toState)`
(`run_detail_bloc.dart:66-75`) — so the operator sees the generic pair copy
*"Agent's work hit an error"* (`shared/transition_copy.dart:39`) and never the recorded reason that
says a zombie execution was reclaimed after 484 minutes. The data crosses the wire and is discarded
at the presentation boundary.

---

## 2. Premise corrections — five things the design cannot be built on as stated

This section is load-bearing. Each item was re-derived from source rather than accepted from the
dispatch, and **each one changes the design**.

> **After the 1.1.0 closeout, nothing here was withdrawn.** HD-1/HD-2/HD-3 were decisions about
> *what to build*, not about *what is true*. In particular:
>
> ⚠️ **[PARTLY SUPERSEDED — HD-5 `8585491a`, 2026-10-12.]** The sentence above was true at the 1.1.0
> closeout and is **no longer true of HD-3**, which the human reversed on 2026-10-12 and which is
> **superseded in full** — a decision about *what to build*, after all. HD-1 and HD-2 stand. None of the
> five premise corrections (P-1…P-6) is touched by the reversal; every bullet below still holds, and
> **P-1 remains the single most important finding in this document.**
>
> - **P-1 is unaffected and remains the single most important finding in this document.** Resolving
>   HD-2 in favour of a real audit row did not make the dispatch path work; gates G1–G4 are untouched
>   by every decision, so the naive one-button design still strands a work item in `agentExecuting`
>   forever. §16.2 pins the sequencing that prevents it.
> - **P-3 was confirmed by the human, not overruled.** The finding was "there is no durable place to
>   record who retried and why". Decision `2b8f4c07` accepted the finding and paid for the fix with a
>   migration.
> - **P-2, P-4, P-5 and P-6 are untouched** and are not restated anywhere in this revision.

### P-1 — `agentFailed -> agentExecuting` alone is a **deadlock**, not a retry. The transition is legal but it dispatches nothing.

The dispatch's constraint 1 is right that this is the only explicit non-terminal edge. What it does
not say — and what the code says plainly — is that **landing in `agentExecuting` does not cause a
dispatch**, because `agentExecuting` is not an entry state of the job definition that runs this
work:

```dart
// packages/scheduler/lib/src/triage_defect.dart:6-13
const JobDefinition triageDefectDefinition = JobDefinition(
  …
  entryStates: {WorkItemState.designNotRequired, WorkItemState.designApproved},
  …
);
```

Four independent gates stand between "the item is in `agentExecuting`" and "an agent runs":

| # | Gate | Citation |
|---|---|---|
| G1 | `evaluate` returns `noAction` because `agentExecuting ∉ entryStates` | `runnable_work.dart:83-85` |
| G2 | `Scheduler.tick` step 3 enqueues **only** for `runnable`; `noAction` hits `break` | `scheduler.dart:492-516` |
| G3 | `_eligibleRunnableJobs` drops any job whose item is not `runnable`, so even a pre-existing queued job is never dispatched | `scheduler.dart:578-581` (and again at `:593-594`) |
| G4 | `JobQueue.enqueueIfAbsent` refuses to create a job when *any* job already exists under the dedupe key — **terminal or not** | `job_queue.dart:55-58`; `postgres_job_store.dart:246-256` |

G4 is the one that bites hardest, and it is live right now: the failed job's `dedupeKey` is
`defect-DEF-1791686704991884:triage_defect`, and `findLatestByDedupeKey` is
`SELECT * FROM "job" WHERE "dedupeKey" = @dedupeKey ORDER BY "createdAt" DESC LIMIT 1` — no state
filter. Its `activeDedupeKey` is `NULL` (terminal jobs release it,
`postgres_job_store.dart:17-26`), so a *new* job could be created — but **not under that key**.

> **Consequence, stated plainly because it is the whole reason this brief is not a one-button
> screen:** a design whose server side is "transition `agentFailed -> agentExecuting` and let the
> scheduler pick it up" ships a button that moves a work item from an honest *Needs you — it failed*
> into a permanent, silent *"Working on it"* with a queued job that will never be claimed. That is
> strictly worse than today's defect, and it is exactly the "button that silently does nothing"
> failure the dispatch forbids.

`agentExecuting` also means something specific in this topology: **"a job holds this item right
now."** It is entered by `ExecutionCoordinator.execute` *at dispatch time*
(`execution_coordinator.dart:148-155`), not before. So the design cannot use it as a "please run
this" parking spot without changing what the scheduler means by it. §6 specifies that change
explicitly and narrowly.

### P-2 — The retry edge has **no `agentAvailable()` guard**, unlike its siblings. This is load-bearing.

| Edge | Guards | Citation |
|---|---|---|
| `designRequired -> agentExecuting` | `actorAllowed([orchestrator])`, **`agentAvailable()`** | `work_item_transitions.dart:36-39` |
| `designInReview -> agentExecuting` | `actorAllowed([orchestrator])`, **`agentAvailable()`** | `:46-49` |
| `designApproved -> agentExecuting` | `actorAllowed([orchestrator])`, **`agentAvailable()`** | `:88-91` |
| `designNotRequired -> agentExecuting` | `actorAllowed([orchestrator])`, **`agentAvailable()`** | `:96-99` |
| **`agentFailed -> agentExecuting`** | **`actorAllowed([orchestrator])` only** | **`:108-110`** |

`agentAvailable()` reads `context['agentAvailable']` and `context['capabilitiesMatch']`, both
defaulting to `false` (`guard_conditions.dart:207-209`). **So capacity is not enforced by the
transition table on this edge** — the table will happily accept the retry with a full budget and no
agent available, and the only thing standing between that and an overshoot of
`SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS` is the claim-time guard inside the scheduler
(`job_capacity_guard.dart:92-186`).

This is not a bug to fix here; it is the reason the design **must not** treat the transition as the
retry. It is also why the screen must never offer a "start now regardless" affordance (§10).

### P-3 — There is **no durable place** to record *who* retried and *why*.

`DurableWorkflowEngine.transition` builds the persisted record with
`reason: transition.rejectionReason` (`durable_workflow_engine.dart:150-168`, **`:157`**, corrected at 1.2.0 — 1.1.0 said :156), and
`rejectionReason` is `null` on an accepted transition. Confirmed on the live rows above: every
accepted transition has an empty `reason`. The `context` map is passed to the policy for guard
evaluation but is **not** persisted anywhere — `work_item_transition` has no metadata column
(`apps/server/lib/src/database/work_item_transition.spy.yaml`).

Every other operator action in this repository *does* capture a reason: the decision screen makes
one mandatory — *"Add a short reason — saved with your name (required)"*, under the heading
`WHY DID YOU DECIDE THIS?` (`needs_you_page.dart:450`, `:461`), because *"the record should say why,
not just what"* (`needs_you_page.dart:386-388`).

> **A retry that leaves no trace of the human who spent the money is not acceptable here.** §6.4.2
> specifies the durable change.
>
> **[CLOSED by HD-2 → `AUDIT_TABLE_SAME_TX`, `2b8f4c07-6d51-4a93-8e17-93c5b0a2f6d4`.]**
> This finding was **confirmed, not overruled**. The human chose the heavier option: a dedicated
> `operator_action` audit row written **inside the transaction `DurableWorkflowEngine` already opens**,
> *plus* the additive `reason` parameter so the reason reaches `work_item_transition.reason` as well.
> My own recommendation at 1.0.0 was the additive parameter alone; the brief records plainly that the
> human's answer is the more correct one and that I flagged my proposal as the most contestable
> decision in the document for exactly this reason (see §13.2). §6.4.2 and §6.5 have been rewritten
> accordingly.

### P-4 — The operator is not the transition's actor, and cannot be.

The retry edge's only guard is `actorAllowed([ActorType.orchestrator])`
(`work_item_transitions.dart:109`). A human clicking a button is not `ActorType.orchestrator`.

This is not a blocker, because the repository already has the answer:
`WorkflowEndpoints.resolveDecision` performs the transition through the durable engine — whose
default actor is `WorkflowActor(actorId: 'orchestrator', actorType: ActorType.orchestrator)`
(`durable_workflow_engine.dart:40-43`) — and records the *human* separately, on the decision record,
with a name and a signature (`workflow_endpoints.dart:101-153`; `control_plane_service.dart:1841-1869`).

The retry follows that precedent: **the engine acts as the orchestrator; the human's identity and
stated reason are recorded as data on the same durable write.** It does not invent a new
`ActorType`, and it does not weaken `actorIsNotSelf()` anywhere.

### P-5 — The capacity guard has **no read-only probe**, and adding one would be a lie.

`JobCapacityGuard` exposes exactly one operation, `tryAdmit`, which claims inside the budget's
advisory-lock transaction (`job_capacity_guard.dart:92-186`). There is no
`hasCapacity()` / `peek()`. That is deliberate: the check must be atomic with the reservation, or
two replicas each read `inFlight = C-1` and the cap is exceeded by one *per replica*.

The design therefore **does not pre-check capacity as a gate**. A pre-check would be a
time-of-check/time-of-use race and would produce a button that says "go" and then does nothing —
the failure the dispatch forbids. Instead the retry enqueues and the existing guard decides at claim
time; the human is told the *outcome* (§7).

The screen may still **display** the budget, as a read-only "right now" statement, because that is
a fact about the durable `job.state` rows and is labelled as a snapshot rather than a promise.

### P-6 (minor, corroborating) — The vocabulary's own comment and code disagree about `agent_failed`.

> **`LEARNING_POLICY` category: `CONTRADICTION`** — the documented comment conflicts with its own
> code. Authority: independent review to reconcile; **NOT reconciled by this lane** because the label
> change shares its cause with the out-of-scope parked-items defect (§14.1). Tagged at 1.2.0 per the
> review's L4.

```dart
// apps/control_plane/lib/core/plain_language.dart:119-125
      // An un-escalated failure is still the system's problem, not the
      // operator's turn — it reads as stopped until a decision is raised.
      'agent_failed' ||
      …
      'design_rejected' => PlainStatus.needsYouItFailed,
```

The comment says an un-escalated failure "reads as stopped"; the code returns
`PlainStatus.needsYouItFailed`. The code is what live QA observed. **This brief does not change
either** — the label is a labelling question and is bundled into the out-of-scope follow-up in
§14, because the same defect produces the "9 parked items" symptom and splitting the label change
from that one would fix half of a defect whose cause is shared.

---

## 3. What the design must be true of

Restating the requirements as testable design commitments:

| # | Commitment |
|---|---|
| R-1 | Every action the screen offers maps to an edge in `WorkItemTransitions`. The **server** computes the legal action set; the client renders it. No action is derived client-side from a state string. |
| R-2 | The credit cost of a retry is stated in text, on the surface, **before** the operator commits — and again in the confirmation step. |
| R-3 | No path from the screen bypasses the execution capacity guard, and none weakens it. |
| R-4 | Every write goes through `DurableWorkflowEngine`/`WorkItemTransitions` with the injected policy. No SQL, no hand-written state. |
| R-5 | Double-click, refresh mid-flight, lost response and capacity denial each have a specified, convergent outcome. |
| R-6 | All copy comes from the existing vocabulary in `plain_language.dart` / `transition_copy.dart` / `decision_choice.dart`, or is the same register as it. No engineer jargon on the default surface. |
| R-7 | The failure reason is shown in plain language, with the raw record preserved verbatim under the existing "Show technical details" disclosure. A missing reason is reported as missing, never rendered as an empty box. |

---

## 4. Scope

### In scope

1. A **new action panel on the Run detail screen**, shown when (and only when) the server says an
   action is legal for the current state.
2. **Two actions** — `retry` and `stop` — plus a **why-it-failed** section, specified in §5.
3. **A new request-side RPC surface** (§6): one read (`workItemActionContext`) and two writes
   (`retryFailedWorkItem`, `stopFailedWorkItem`).
4. **The minimal scheduler seam** without which R-1/R-3 cannot be satisfied (§6.5), specified at
   contract level and explicitly separated into its own implementation lane.
5. The **durable operator-reason record** (§6.4), specified at contract level.
6. A **retry-count limit**, specified as a configured, fail-closed bound (§6.6) — because "retry
   spends real credits" and an unbounded button is a spend firehose.

### Explicitly **not** in scope (see §14 for the full list)

The 9 parked `agent_completed` items and the "Working on it" labelling defect; changing the
`agentFailed` exclusion from `RunnableWorkEvaluator`; any change to the zombie/timeout protections;
any migration; any change to the queue, claim, or adoption machinery.

---

## 5. The action set, mapped to the transition table

### 5.1 What the table actually offers from `agent_failed`

Derived from `WorkItemTransitions._legalTransitions` plus `_isGenericEscape`
(`work_item_transitions.dart:299-312`) — **read, not assumed**:

| # | Edge | Kind | Guard | Citation |
|---|---|---|---|---|
| E1 | `agentFailed -> agentExecuting` | explicit | `actorAllowed([orchestrator])` | `:108-110` |
| **E1′** | **`agentFailed -> designNotRequired`** | **explicit — ADDED by HD-4** | `actorAllowed([orchestrator])` | **§6.5.1** |
| E2 | `agentFailed -> cancelled` | generic escape | `actorAllowed([orchestrator])` | `:302-307`, `:322-326` |
| E3 | `agentFailed -> terminated` | generic escape | `actorAllowed([orchestrator, system])` | `:323-325` |

**As the table stands at `4dc9c5e`, `agentFailed` appears in exactly two places in the map:** as a
`to` at `:105-107` and as a `from` at `:108-110` (verified: `grep "(WorkItemState.agentFailed,"` → 1
hit). **This brief adds a second `from` edge, E1′ (§6.5.1), per HD-4.** So after this change
`agentFailed` has **two** explicit forward edges, and `retry` binds to **E1′**, not E1.

In particular, **`agentFailed -> waitingForHumanDecision` still does not exist** either before or
after, so "escalate this to a human" remains unavailable — a non-goal (§10).

### 5.2 The action set chosen

| Action | Edge | Offered when | Why |
|---|---|---|---|
| **`retry`** — "Try again" | **E1′** (`-> designNotRequired`, §6.5.1) | item state is `agent_failed` | It returns the item to a triage entry state the scheduler **already dispatches**, so the routed-to-human decision resolves into real work with no new dispatch code. **[REBOUND at 1.4.0 per HD-4; 1.3.0 still bound this row to E1 (`-> agentExecuting`) and called it "the only forward edge", both of which HD-4 made false.]** |
| **`stop`** — "Stop this work" | E2 | item state is `agent_failed` | A terminal escape, unchanged by HD-4. **Decided: offer it.** Justified below. |
| **`terminated`** (E3) | E3 | **never** | Same effect as `stop` from the operator's point of view, with a different word they cannot act on (`terminated` is also the actor `system`'s escape). Two buttons for one effect is worse than one. **Deliberately not offered.** |
| **"inspect why"** | *no transition* | always, when a failure is recorded | Not an action — it is **state of the panel**. The reason column is read-only. |

### 5.3 Is "stop this work" scope creep? — No. Here is the argument both ways.

**For omitting it:** the dispatch is about giving a human a way to *restart* work; a second,
destructive, irreversible button is extra surface, extra copy, extra confirmation, and extra test
matrix. It is the classic way a focused brief grows.

**For including it — which I conclude:**

1. **It is one of the two edges the table actually offers.** Constraint 1 asks for the action set
   mapped to legal transitions. Offering exactly one of two, with no statement about the other, is
   a design that has silently answered "may a human stop this?" — and the only way to answer *no*
   is to leave a human with a permanently-stranded work item and no in-product remedy.
2. **Without it, the retry is coercive.** The screen would say, in effect, *"this thing failed and
   I am offering you exactly one thing, and it costs money."* An operator who is out of credit, out
   of budget, or simply judging the defect not worth re-running has no answer. With it, "no" is a
   first-class outcome.
3. **The cost of refusal is worse than the cost of inclusion.** A stranded `agent_failed` item can
   only be cleared by someone writing SQL against `work_item` — which is precisely the incident the
   dispatch cites in constraint 4, where a hand-written state broke every scheduler tick. Designing
   a screen whose only exit for a human is "open a database client" is designing the next incident.
4. **It is cheap.** One more entry in a server-computed action list, one confirm strip reusing
   `_ConfirmStrip`'s existing shape, one button. The destructive-affordance cost is paid by
   rendering it as an `OutlinedButton` with a `negative` panel edge and a second confirmation — not
   by omitting it.

**The counter-case I could not dismiss, stated for the reviewer:** `cancelled` is terminal
(`platform_contracts/lib/src/enums/workflow_state.dart:36-39`) and irreversible. If a product later
regrets stopping a work item, there is no edge back from `cancelled` — the generic escape only
applies to non-terminal `from` (`work_item_transitions.dart:303-306`). The mitigation is that the
transition history and the item row survive, and the defect itself is untouched (only the *work
item* is cancelled). I flag this as **HD-1** for a human to confirm rather than settling it here.

> **[CLOSED by HD-1 → `INCLUDE_STOP`, `7c1e9a44-3b62-4d18-9f05-2a7c6e14d903` (PRODUCT, RESOLVED).]**
> The human adopted the recommendation above, on the same reasoning: *"A product that routes a
> decision to a human must give that human both answers."* Both answers existed in the escalation and
> `INCLUDE_STOP` was one of them, so **§5.2 and §5.3 stand exactly as written** and the panel
> composition is unchanged.
>
> Two consequences carried forward from the decision record:
>
> 1. **The single confirm strip is confirmed, not a typed confirmation.** The decision's options were
>    `INCLUDE_STOP` and `RETRY_ONLY`; there is no typed-confirmation option, so §8.3's one confirm
>    strip for both actions is what was chosen. I am not re-raising it.
> 2. **The decision's own follow-up action is binding on the implementation lane:** *"Implement the
>    `stop` action against the generic escape edge only. Never synthesise a transition that
>    `work_item_transitions.dart` does not already permit."* This is §10 N2/N4 restated by the human
>    and is not something an implementer may reinterpret.

### 5.4 Action labels, drawn from the existing vocabulary

Every label below is either an existing string or is written in the same register as existing
strings. **No new jargon is introduced.**

| Element | Text | Source |
|---|---|---|
| Panel heading | `Restart after a problem` | **existing** — `PlainLanguage.decisionType('escalation')` (`plain_language.dart:144`) |
| Panel status line | `Needs you — it failed` | **existing** — `PlainStatus.needsYouItFailed.label` (`:31`) |
| Why headline | `The work stopped with an error` | **existing** — `PlainLanguage.haltExplanation('agent_failed')` (`:267`) |
| Primary action | `Try again` | new string, same register (§5.5) |
| Secondary action | `Stop this work` | **existing** — `decisionChoiceLabel('cancel', decisionType: 'escalation')` (`decision_choice.dart:40`) |
| Resulting timeline row | `Retrying after an error` | **existing** — `transition_copy.dart:40` |
| Capacity-denied result | `Queued — it will start when a machine is free.` | new string, same register |
| Capacity snapshot | `2 of 2 agent slots busy` | new string; the Overview screen already prints `N of M machines busy` in this shape (`home_page.dart:637-639`) |

### 5.5 Why the primary action is **"Try again"** and not **"Resume"**

`decisionChoiceLabel` maps `approve` → **`Resume`** for an escalation gate
(`decision_choice.dart:39`). Reusing it here would be more consistent and would be **wrong**:

- "Resume" means *continue what was paused*. Nothing here was paused — an execution **failed**.
- "Resume" carries no cost signal. The whole point of this screen (constraint 2) is that the act
  spends real model credits.
- The two acts would collapse into one word: "resume a failed run" and "resume a paused run" would
  become indistinguishable on the same screen vocabulary, at very different cost.

`"Try again"` is plain English, matches the register of the rest of the surface
(`"Try all work"` / `"Retry"` in `DesignErrorState.onRetry`), and — critically — the **durable
record and the screen agree**: the transition the retry writes renders on the timeline as
*"Retrying after an error"*, which is what actually happens.

### 5.6 The "inspect why" section — showing the reason without leaking jargon

The recorded reason is engineer prose. Live example:

> `operator step 3: stranded by pre-fix zombie reclaim (job jb-hn3liczxln-li36ts); reconciled to
> agentFailed per reviewed reclaim semantics`

and the job failure:

> `zombie execution reclaimed: execution wx-jb-hn3liczxln-li36ts is still agentExecuting, no live
> execution could be observed, and it has been non-terminal for 484m (beyond the 30m bound)`

Neither may appear on the default surface (constraint 6). But neither may be **hidden**, because
then "Needs you — it failed" with an empty panel would be exactly the indistinguishable quiet
screen the doctrine forbids.

**Design: a closed-set classifier, never a free-text invention.**

The panel renders a plain sentence derived from a *known cause*, and always renders the raw record
verbatim in the existing `TechnicalDetails` disclosure at the page footer
(`run_detail_page.dart:185-193`). The classifier recognises **only** causes the repository itself
emits, and anything it does not recognise gets a truthful neutral sentence — never a guessed cause.

| Recorded signal (durable) | Plain sentence on the panel |
|---|---|
| `failureJson.code == 'executionInterrupted'`, or `reason` contains `zombie execution reclaimed` | `The machine running this work stopped answering, so it was stopped and handed back to you.` |
| `reason` contains `orphaned` (the coordinator's wording, `execution_coordinator.dart:412-419`) | `The machine running this work went away before finishing.` |
| A `reason` is present but matches nothing above | `The work stopped with an error. The technical details below say what the system recorded.` |
| **No `reason` recorded at all** | `The system did not record why this stopped.` |

The last row is the important one. **A missing reason is displayed as missing.** An empty panel,
a blank string, or a silently substituted generic message would all be the defect this screen
exists to close.

---

## 6. The client↔server contract

### 6.0 This is new surface, and there is no precedent to copy wholesale

`ControlPlaneService`'s class doc is explicit: *"This layer deliberately has NO operation that sets
`WorkItem.state` directly … Endpoints only observe state or unlock work that a human decision
blocked"* (`control_plane_service.dart:53-61`), and `WorkflowEndpoints.resolveDecision` is
documented as *"the only legal request-side state transition"* (`workflow_endpoints.dart:101-106`).

The retry is a **second** legal request-side transition that is **not** a decision resolution.
Adding it to `WorkflowEndpoints` would make both doc comments false without changing them, so the
design specifies a **new endpoint class** and an explicit obligation to amend both comments
(acceptance criterion **AC-11**).

There is also a wiring gap: the `Scheduler` is a local variable inside `run()`
(`apps/server/lib/server.dart:251-292`) and **no endpoint can currently reach it**. `ControlPlaneService`
is built per-request from a `Session` (`control_plane_service.dart:60-61`). §6.5 specifies the
composition-root handle that closes this.

### 6.1 New endpoint class

```dart
// apps/server/lib/src/endpoints/work_item_action_endpoints.dart   (NEW)

/// Operator actions on a work item that is parked in a failure state.
///
/// The SECOND legal request-side write path, after `WorkflowEndpoints.
/// resolveDecision`, and deliberately a separate class: the existing class's
/// doc comment claims resolveDecision is the only one, and widening it in place
/// would leave that comment false.
class WorkItemActionEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// READ. The legal action set for this work item, computed server-side from
  /// `WorkItemTransitions`, plus the failure record and the capacity snapshot.
  Future<WorkItemActionContextView> actionContext(
    Session session, {
    required String workItemId,
  });

  /// WRITE. `agentFailed -> designNotRequired` — the edge ADDED by HD-4
  /// (design-brief.md §6.5.1), guarded `actorAllowed([ActorType.orchestrator])`.
  ///
  /// NOT `agentExecuting`: that state means an execution is ALREADY RUNNING,
  /// so dispatching an item placed there is incoherent, and the scheduler
  /// correctly refuses it. `designNotRequired` is a triage entry state the
  /// scheduler already dispatches (triage_defect.dart:10). Nothing about the
  /// enqueue or the dispatch happens here — see §6.4.
  Future<WorkItemActionResult> retryFailedWorkItem(
    Session session, {
    required String workItemId,
    required String requestId,    // UUID, minted by the client ONCE per operator intent
    required String requestedBy,  // operator identity, recorded durably
    required String reason,       // required, non-empty: the record says why
  });

  /// WRITE. `agentFailed -> cancelled` via the generic escape.
  Future<WorkItemActionResult> stopFailedWorkItem(
    Session session, {
    required String workItemId,
    required String requestId,
    required String requestedBy,
    required String reason,
  });
}
```

**Naming rationale:** verb-phrase, camelCase, matching `resolveDecision` / `jobsForWorkItem` /
`pendingDecisions`. The two writes are named for the **state they are legal from**
(`…FailedWorkItem`), so a future edge from another state reads as a different method rather than a
parameterised one. No string names a state on the wire; the states live in
`WorkItemTransitions`.

### 6.2 New wire models

Declared in `apps/server/lib/src/models/*.yaml` (the repo's Serverpod 3 convention — see
`work_item_detail_view.yaml`) and regenerated. **Every string the client renders is a wire value
the client maps**, exactly as `UiViewMappers.workItemView` returns `state.wire` and the client maps
it through `PlainLanguage.statusFor` (`plain_language.dart:84`). No server-authored UI copy.

```yaml
# apps/server/lib/src/models/work_item_action_context_view.yaml
class: WorkItemActionContextView
fields:
  workItemId: String
  state: String                       # WorkItemState.wire
  actions: List<WorkItemActionView>   # server-computed from WorkItemTransitions
  failure: WorkItemFailureView?       # null when no failure is recorded
  capacity: ExecutionCapacityView
  # HD-3 (5d9a1f62): the unset-means-unavailable case is a REPORTED state,
  # not an absent one. Never a fallback value; never blank.
  retryLimitResolved: bool
  retryLimitDiagnostic: String?
  priorActions: List<OperatorActionSummaryView>   # NEW at 1.1.0 -- see OQ-1

---
class: OperatorActionSummaryView
fields:
  action: String            # 'retry' | 'stop'
  requestedBy: String       # the HUMAN -- the thing work_item_transition.actorId cannot hold
  reason: String
  at: DateTime
  attemptNumber: int        # 1-based position among this item's retries

---
class: WorkItemActionView
fields:
  action: String            # 'retry' | 'stop'   (a closed set; unknown => nothing rendered)
  toState: String           # the state this edge lands in
  confirmRequired: bool
  destructive: bool
  attemptNumber: int?       # this work item's 1-based retry count after this action
  attemptLimit: int         # the configured maximum; 0 means "unavailable, not configured"

---
class: WorkItemFailureView
fields:
  transitionId: String?
  at: DateTime?
  reason: String?           # work_item_transition.reason — verbatim, untranslated
  actorType: String?
  jobId: String?
  jobState: String?
  jobFailureCode: String?
  jobFailureReason: String?

---
class: ExecutionCapacityView
fields:
  budget: String            # 'agent_executions'
  cap: int
  inFlight: int
  snapshotOnly: bool        # always true — this is an observation, never a promise (§7)

---
class: WorkItemActionResult
fields:
  outcome: String           # see the outcome table in §6.3
  workItem: WorkItemView
  jobId: String?
  jobState: String?
  attemptNumber: int
  inFlight: int?
  cap: int?
  message: String?          # a FACT, not copy: e.g. the plain cause; the client words it
```

### 6.3 Outcomes — every call terminates in exactly one of these

| `outcome` | When | Durable effect | What the operator is told |
|---|---|---|---|
| `dispatched` | retry: transition committed, job claimed and started | item `agentExecuting`, job `running` | `Started.` |
| `queued` | retry: transition committed, **capacity denied** at claim | item `agentExecuting`, job `queued` | `Queued — it will start when a machine is free.` plus the snapshot |
| `alreadyRunning` | a non-terminal job exists for this item that is not this request's | **nothing written** | `This work is already running.` |
| `alreadyStopped` | a prior `stop` for this `requestId` was accepted | replay of the accepted result | `Already stopped.` |
| `notApplicable` | item is not in `agent_failed` | **nothing written** | `This work is not waiting on you.` + the current plain status |
| `notConfigured` | **limit reached**: retry count ≥ configured maximum | **nothing written** | `This work has already been tried 3 times. Stop it, or leave it for review.` |
| `notConfigured` | **limit unresolved** (HD-3): `SHIPIT_OPERATOR_MAX_RETRIES` unset/blank/unparseable/negative | **nothing written** | `Starting this again is switched off on this machine. Nothing has been changed.` — see §6.6.1, §8.2 |

⚠️ **[SUPERSEDED — HD-5 `8585491a`, 2026-10-12.]** The row above describes the **unset** case, and under
HD-5 the unset case **is no longer an outcome at all**: `notConfigured` is not returned because a value
is missing, because a missing value now means **uncounted** and the retry proceeds. The row is retained
as the record of HD-3's behaviour and must not be implemented.

**What replaces it:** `notConfigured` is returned for exactly two reasons — `SHIPIT_OPERATOR_MAX_RETRIES=0`
explicitly, or an explicit positive `N` whose count is reached. The `notConfigured` outcome itself, and the
rule that **every rejection path writes nothing at all**, are unchanged and still apply to those two.
| `invalidRequest` | empty/absent `reason` | **nothing written** | `Add a short reason before you continue.` |

**There is no error outcome for "capacity full".** A denial is a normal outcome with a defined
meaning — it is exactly what `Scheduler.deferred` already means ("the job is still queued and still
wanted", `scheduler.dart:537-543`) — and rendering it as an error would teach operators that the
system is broken when it is correctly bounded.

Every rejection path writes **nothing at all**: no transition, no job, no failure, no event. This is
the `CapacityDenied` contract verbatim — *"No claim is attempted and nothing is written: the job
stays `queued`/`retryWaiting` and is retried by a later tick"*
(`job_capacity_guard.dart:44-47`; `scheduler.dart:676-695`).

### 6.4 The retry algorithm — rewritten at 1.3.0, and it is much smaller

> **HD-4 removed two steps.** The 1.2.0 algorithm enqueued a job *before* the transition (a
> crash-window argument that only existed because the item had to be moved into a non-runnable
> state) and then called `requestOperatorDispatch` *after* it. With the item returned to
> `designNotRequired` — a state the scheduler already treats as runnable — **the retry RPC neither
> enqueues nor dispatches.** It performs exactly one durable write and returns. The scheduler does
> the rest on its existing path (§6.5.2).

```
retryFailedWorkItem(workItemId, requestId, requestedBy, reason):

  retryKey := 'operator-retry:' + requestId

  // (0) REPLAY. The operator_action row is unique on (workItemId, requestId),
  //     so it is the authoritative idempotency record. The transition's
  //     idempotencyKey is a second, independent witness.
  prior := workflowStore.readOperatorActionsForWorkItem(workItemId)   // §6.4.3
                  .firstWhereOrNull((a) => a.requestId == requestId)
  if prior != null:                        return accepted(prior)   // never re-write
  if findTransitionByIdempotencyKey(workItemId, retryKey).outcome == accepted:
                                           return accepted

  // (1) AUTHORISE. The edge is the new agentFailed -> designNotRequired (§6.5.1),
  //     checked against the SAME injected policy object the scheduler uses.
  item := workflowStore.readWorkItem(workItemId)
  if item.state != agentFailed:            return notApplicable
  if !WorkItemTransitions.isLegalTransition(item.state, designNotRequired):
                                          return notApplicable
  if retryCount(item) >= configuredLimit:  return notConfigured   // §6.6, counts audit rows
  if reason.trim().isEmpty:                return invalidRequest
  if listJobsForWorkItem(workItemId).any(nonTerminal): return alreadyRunning

  // (2) ATTEMPT NUMBER — derived from the durable audit ledger, never from memory.
  //     readOperatorActionsForWorkItem is the SAME method as step 0's (§6.4.3).
  n := workflowStore.readOperatorActionsForWorkItem(workItemId)
          .where((a) => a.action == 'retry').length + 1

  // (3) ONE TRANSACTION. DurableWorkflowEngine already opens a tx for the work
  //     item and the transition record; the audit row (HD-2's binding
  //     follow-up) and the attempt marker both go inside it. There is no
  //     window in which any two of these can disagree.
  try:
    updated := durableWorkflowEngine.transition(   // policy: the injected one
      workItemId: workItemId,
      to: designNotRequired,                      // §6.5.1 — the HD-4 target
      trigger: systemEvent,
      actor:   operatorRetryActor,                // §6.4.1
      context: {'operatorRetry': true, 'requestedBy': requestedBy},
      idempotencyKey: retryKey,
      reason: reason,                             // §6.4.2
      metadataMerge: {triageAttempt: n},          // §6.7 — makes the dedupe key distinct
      operatorAction: OperatorActionRecord(       // §6.4.3 — SAME TX
        action: 'retry',
        fromState: 'agent_failed', toState: 'design_not_required',
        requestedBy: requestedBy, reason: reason,
        requestId: requestId, workItemId: workItemId,
        attemptNumber: n,
      ),
    )
  on WorkflowTransitionRejectedException:  return notApplicable   // someone else moved it
                                            // and NO audit row: a refused action
                                            // was not taken, so there is nothing to
                                            // audit. The rejected transition record
                                            // (outcome=rejected, idempotencyKey set)
                                            // already records the attempt.
  on ConcurrentModificationException:      retry the WHOLE block, bounded at 3
                                           // (Scheduler._maxReclaimAttempts,
                                           //  scheduler.dart:322) — RE-COUNTING n
                                           // each pass, because the competing writer
                                           // may have moved the item on.

  // (4) DONE. The item is now `design_not_required` — a triage entry state. The
  //     next tick (≤30s) enqueues under the fresh key of §6.7 and dispatches
  //     when the capacity guard admits it. Nothing else is written here.
  return accepted
```

**Why the enqueue-first argument is gone.** It existed for one reason: 1.0.0–1.2.0 moved the item
into `agentExecuting`, where nothing would ever enqueue a job for it, so the RPC had to create one
itself and therefore had to order it before the transition. **With the item returned to a runnable
state, the scheduler enqueues on its own**, and the entire crash-window analysis evaporates: there is
now only **one** durable write, and it is transactional.

**Why `n` is counted from the audit ledger, not from a counter.** Deterministic and replay-safe by
construction: a network retry of the same operator action re-reads the same ledger and either finds
its own row (step 0 → `accepted`) or computes the same `n`. It cannot mint a second job, because the
dedupe key is derived from the *durable* `metadata.triageAttempt` it writes (§6.7) — never from the
`requestId` and never from anything in memory.

**Why the CAS retry must re-count.** Two operators pressing retry on the same item concurrently both
compute `n = 1`. The work-item compare-and-swap (`durable_workflow_engine.dart:203-205`) admits one;
the loser retries the block, re-reads the item, now sees `metadata.triageAttempt == 1`, and computes
`n = 2`. That is the correct outcome — two deliberate operator actions, two attempts — and the
bounded loop is the same shape the scheduler's own reclaim uses (`scheduler.dart:322`).

**One durable write, so the 1.0.0 "enqueue first so a crash leaves an honest state" analysis no longer
applies.** If the transaction commits, the item is `design_not_required` and honest. If it does not,
the item is still `agent_failed` and honest, and a replay redoes it. There is no third state.
#### 6.4.1 The actor

```
operatorRetryActor := WorkflowActor(
    actorId:   'operator-retry',          // identifies the PATH, not the person
    actorType: ActorType.orchestrator,    // the only type work_item_transitions:109 permits
)
```

The **person** is recorded as data (`requestedBy`, and the reason), on the same durable write. This
is exactly the `resolveDecision` shape (P-4) and it introduces no new `ActorType`. Nothing about
`actorIsNotSelf()` changes anywhere.

**[CORRECTED at 1.4.0]** The 1.3.0 version of this paragraph also claimed *"The work item's own
metadata is not touched."* **That was false**, and it was an affirmative, reasoned claim rather than a
stale aside: `§6.4 step 3` passes `metadataMerge: {triageAttempt: n}` (§6.4.5), which writes the item's
metadata inside the transition's transaction. **The metadata IS touched** — additively, by merge, and
only under the retry path. The correction does not weaken anything: `actorIsNotSelf()` is about the
transition's *actor*, which is unchanged, and no guard anywhere reads work-item metadata.

#### 6.4.2 The durable reason — the one required seam in `workflow_store`

**Change:** an additive optional `String? reason` parameter on
`DurableWorkflowEngine.transition`, defaulting to today's `transition.rejectionReason`.

```dart
// packages/workflow_store/lib/src/durable_workflow_engine.dart  — ADDITIVE
Future<WorkItem> transition({
  …,
  String? idempotencyKey,
  String? reason,          // NEW. When null, behaviour is byte-identical to today.
})
// …  :156   reason: reason ?? transition.rejectionReason,   ← SEE THE AMENDMENT BELOW
```

> #### ⚠ POST-APPROVAL AMENDMENT — the line above is WRONG as written, and the
> #### implemented code deliberately departs from it. Recorded 2026-10-11,
> #### Lane S, commit `c0c7c2d`. **This is a recorded correction to an approved
> #### artifact, not a silent change**, and it was found by implementation and
> #### confirmed by independent review, not by re-deriving the design.
>
> **What is wrong with it.** `_buildRecord` infers the record's `outcome` from
> `reason == null`:
>
> ```dart
> outcome: reason == null ? TransitionOutcome.accepted : TransitionOutcome.rejected
> ```
>
> That inference was safe **only** because an accepted transition had no reason
> to record. The moment a caller supplies an operator's own text, the two facts
> decouple — and the pseudocode above hands `reason` straight into `_buildRecord`
> while leaving `outcome` to be inferred. **100% of accepted retries would
> therefore have been persisted with `outcome = 'rejected'`**: the operator
> would press "Try again", the item would move to `design_not_required`, the
> scheduler would dispatch it — and the durable record of that spend would say
> the workflow refused it. AC-13 requires the opposite ("the accepted
> transition row carries a non-null `reason`"), and it is unsatisfiable with
> the pseudocode as written.
>
> **What was implemented instead.** The outcome is decided by the POLICY, not by
> the presence of a reason:
>
> ```dart
> reason: reason ?? transition.rejectionReason,
> outcome: transition.isValid
>     ? TransitionOutcome.accepted
>     : TransitionOutcome.rejected,
> ```
>
> with `outcome` a new optional parameter on `_buildRecord` that **defaults to
> the original inference**, so every pre-existing caller — the scheduler's zombie
> reclaim, `work_entry.dart`, the human-decision unlock — writes byte-identical
> records. Only a caller that passes `outcome` explicitly, which today means
> only `transition()`, can decouple the two, and it does so in the correct
> direction.
>
> **This strengthens nothing and weakens nothing.** It satisfies AC-13 as
> written rather than working around it, and it leaves the `reason == null ⇒
> behave exactly as today` guarantee — which is what makes the parameter safely
> additive — untouched. It is recorded here because **this brief is otherwise
> authoritative over the code**, and an implementer who followed §6.4.2
> literally would have shipped a durable record that lies about every retry.

Why the parameter is kept as well as the audit row:

- The column **exists** and is **named** for this (`work_item_transition.spy.yaml`, `reason: String?`).
- It is default-null, so **no existing caller changes behaviour** — the scheduler's zombie reclaim,
  `work_entry.dart`, `lane_a`/`lane_e` all keep writing what they write today, including the live
  `operator step 3: …` note.
- It is inside the transaction that moves the item, so the reason cannot exist without the move or
  the move without the reason.
- It puts the reason where a reader of *the workflow* already looks. The audit row says *who*; the
  transition says *why*, in the timeline the operator is already reading.

> **CLOSED by HD-2 → `AUDIT_TABLE_SAME_TX`, `2b8f4c07-6d51-4a93-8e17-93c5b0a2f6d4` (ARCHITECTURE,
> RESOLVED).** At 1.0.0 I escalated this and called the `reason` parameter alone the *minimal* change.
> **The human chose the heavier and more honest option, and was right to.** The parameter alone
> answers "why" but not "who", and — the part I under-weighted — authorizing a spend-arming action by
> a string prefix is not authorizing it at all. My proposal is **withdrawn as authorization** and
> survives only as the *reason carrier* the decision explicitly asked to keep.

#### 6.4.3 The `operator_action` audit row — the durable authorisation

**Decision:** a dedicated audit table, written **inside the transaction `DurableWorkflowEngine` already
opens**, so the audit and the state change cannot diverge under a crash. **Append-only: never updated,
never deleted.** A migration is accepted as the price — *"A migration is a fair price for an action
that spends money."*

```yaml
# apps/server/lib/src/database/operator_action.spy.yaml   (NEW)
class: OperatorActionRow
table: operator_action
serverOnly: true
indexes:
  operator_action_id_unique:
    fields: actionId
    unique: true
  operator_action_work_item_idx:
    fields: workItemId
  # The idempotency record. A replay of the same operator intent collides here
  # rather than creating a second row, a second job, or a second spend.
  operator_action_request_unique:
    fields: workItemId, requestId
    unique: true
  # The authorisation index: "which durable action armed this job?"
  operator_action_job_idx:
    fields: jobId
  # The spend-bound index: "how many times has this item been restarted?"
  operator_action_retry_idx:
    fields: workItemId, action
fields:
  actionId: String
  workItemId: String
  action: String                 # 'retry' | 'stop'  -- closed set
  fromState: String
  toState: String
  requestedBy: String            # the HUMAN, unlike work_item_transition.actorId
  reason: String
  requestId: String              # client-minted, stable per operator intent
  jobId: String?                 # set for 'retry'; the job this action armed
  transitionId: String?          # the work_item_transition row it authorised
  createdAt: DateTime
```

Two properties the shape is chosen for:

1. **`requestedBy` is a first-class column**, not a string parsed out of an idempotency key. That is
   the whole difference between an audit and a convention.
2. **`transitionId` closes the binding exactly.** `_buildRecord` runs *before* `inTransaction`
   (`durable_workflow_engine.dart:149-167` then `:201-208`), so the engine knows the transition id
   before it opens the transaction and can stamp it on the audit row inside the same commit. That is
   what lets §6.5 ask a single, precise question instead of reasoning about timestamps.

**How the write reaches the existing transaction.** `DurableWorkflowEngine.transition` already has the
transaction handle — `tx: WorkflowStore` — and already writes the item and the transition record
through it (`:201-208`). So the audit write needs **no new transaction plumbing**: it needs one new
method on the `WorkflowStore` interface and one line in the existing block.

```dart
// packages/workflow_store/lib/src/store/workflow_store.dart  — ADDITIVE, TWO methods
//
// Verified against the real interface at 1.5.0: it declares readWorkItem, readAllWorkItems,
// saveWorkItem, readHumanDecision, readHumanDecisionsForWorkItem, saveHumanDecision,
// readTransitionHistory, findTransitionByIdempotencyKey, appendTransitionRecord and inTransaction.
// Neither of the two below existed; the pseudocode in §6.4 called an operator-action read that
// was declared NOWHERE. (Discovery D-8.)

/// Appends one operator action. Append-only; there is no update or delete
/// counterpart, and none may be added (AC-14d).
Future<void> appendOperatorAction(OperatorActionRecord record);

/// Operator actions recorded against [workItemId], OLDEST FIRST.
///
/// ONE read serves BOTH of §6.4's needs, so no second read method exists:
///   - step 0's replay check   -> .firstWhereOrNull((a) => a.requestId == requestId)
///   - step 2's attempt count  -> .where((a) => a.action == 'retry').length
/// The ordering matters for step 0: the replay check must find the FIRST row for that
/// requestId, and the count is order-independent.
Future<List<OperatorActionRecord>> readOperatorActionsForWorkItem(
  String workItemId,
);

// packages/workflow_store/lib/src/durable_workflow_engine.dart — ADDITIVE, all three optional
Future<WorkItem> transition({
  …,
  String? reason,                        // §6.4.2  — confirmed by 2b8f4c07
  OperatorActionRecord? operatorAction,   // §6.4.3 — null ⇒ behaviour identical to today
  Map<String, dynamic>? metadataMerge,    // §6.4.5 — NEW at 1.3.0, from HD-4's accepted cost
})
// … inside the EXISTING transaction, after tx.appendTransitionRecord(record):
//   if (operatorAction != null) {
//     await tx.appendOperatorAction(
//       operatorAction.copyWith(transitionId: record.transitionId));
//   }
```

**All three default to `null`, and `null` means "behave exactly as today".** No existing caller is
changed by any of them.

**Atomicity, stated as the decision requires it.** The audit row and the work-item state change
commit or roll back together. If the compare-and-swap on the item version fails
(`durable_workflow_engine.dart:203-205`), the audit row rolls back with it: **no audit row without the
move, and no move without the audit row.** This is the decision's binding follow-up and the reason the
design does *not* write the audit row before the transition.

**Refused attempts write no audit row.** A rejected transition takes the early path at `:170-173` **(`if (!transition.isValid)` at `:170`, append at `:171`, throw at `:172` — corrected at 1.2.0; 1.1.0 said `:169-172`)**,
outside any transaction, and throws. Nothing was taken, so there is nothing to audit; the rejected
transition record already carries `outcome = 'rejected'` and the `idempotencyKey`, which is an
adequate record that the attempt was made.

#### 6.4.4 What this costs — and why it is still the right call

Stated rather than glossed, because the reviewer should price it:

| Cost | Detail |
|---|---|
| **A migration** | `operator_action` must exist in the chain-migrated path (`migrations/<ts>/migration.sql`) as well as in the regenerated `definition.sql` from the model. |
| **8 `WorkflowStore` implementors** | **[RECONCILED at 1.4.0]** The interface gains **TWO methods** — `appendOperatorAction` (HD-2) and `readOperatorActionsForWorkItem` (§6.4 step 0 and step 2). **[CORRECTED at 1.5.0: 1.4.0 said ONE. The 8-implementor HEADCOUNT is unchanged and remains correct; it was the per-implementor METHOD COUNT that was understated by 100%, which is the same cost-pricing error corrected at 1.2.0 for the same reason — a claim about an interface that was written before the interface was re-read.]** HD-4's `metadataMerge` (§6.4.5) adds **a parameter to the existing `transition()` method, not a method**, so this count is unchanged by it; verified against `WorkItem.copyWith` (`work_item.dart:119`, `metadata: metadata ?? this.metadata`) and `PostgresWorkflowStore`'s INSERT/UPDATE of `metadataJson` (`:50`, `:56`, `:140`), the work item already being written inside the existing transaction at `durable_workflow_engine.dart:203-205`. **[CORRECTED at 1.2.0 per the reviewer's M2 — 1.1.0 said 11; the true count is 8.]** 3 production: `PostgresWorkflowStore`, `InMemoryWorkflowStore`, `FileJsonWorkflowStore`. 5 test doubles: `racing_workflow_store.dart`, `faulty_workflow_store.dart`, `tick_reconcile_failure_reporting_test.dart` (`_FaultingWorkflowStore`), `lane_f_production_reachability_test.dart` and `triage_execution_test.dart` (both `_ScopedWorkflowStore`). Verified by `rg "implements WorkflowStore"` — 8 files. **The contract suite is NOT an implementor**: `workflow_store_suite.dart:9-11` takes a `Future<WorkflowStore> Function() createStore` factory and exercises whatever store it is handed. The 1.1.0 figure was wrong in the *safe* direction but was repeated twice as load-bearing risk-pricing evidence in the one section written to be priced honestly. |
| **A contract-suite test** | `workflow_store_suite.dart` already asserts *"transition history is append-only and idempotency-keyed"* (`:96-116`) and *"inTransaction batches mutations atomically when supported"* (`:117-126`). The operator-action analogue belongs beside them, and the atomicity test is the one that matters. |
| **`tool/schema_bootstrap.sql`** | **[REASONING RESTATED at 1.2.0 per the reviewer's L1 — the 1.1.0 evidence was a proxy, the conclusion was right.]** The real reason the file needs no change is that **`verify_schema_bootstrap.sh`'s `required_objects` admits only `trigger:` and `index:` kinds** (`:126-131`) — its four entries are two triggers and two indexes, and a generated *table* cannot be listed there at all. `schema_bootstrap.sql` is the hand-maintained home for exactly the objects the model-driven generator cannot render, and a plain table with plain btree indexes is not one of them. (1.1.0 argued this from "the file contains no `CREATE TABLE`", which was true but indirect.) The `operator_action` indexes are deliberately plain btree for this reason. `verify_schema_bootstrap.sh` must still pass, and `apps/server/tool/schema_bootstrap.dart` runs against the test database in CI. |

The reviewer should confirm the third row rather than take it from me: it is the difference between
"a migration touches three files" and "a migration touches five".

#### 6.4.5 `metadataMerge` — specified at 1.4.0, because HD-4's accepted cost depends on it

> **[SPECIFIED at 1.4.0. At 1.3.0 this parameter existed in the §6.4 pseudocode and in the §16.2 lane
> box but was absent from the additive signature this brief specifies — an unspecified mechanism on
> which a silent no-op depended. That is precisely the class of gap §7.3 warns about, so it is now
> specified here or removed. It is specified, because without it §6.7's key rule cannot function.]**

**Signature.** `Map<String, dynamic>? metadataMerge`, defaulting to `null`. Merged into
`WorkItem.metadata` **inside the transaction `DurableWorkflowEngine.transition` already opens**, as
part of the `finalItem` that `tx.saveWorkItem(finalItem, expectedVersion: item.version)` writes.

**Semantics: MERGE, never REPLACE.** This is the load-bearing part.

```dart
// packages/workflow_store/lib/src/durable_workflow_engine.dart
final updated = item.copyWith(
  …
  // MERGE. `WorkItem.copyWith` is `metadata: metadata ?? this.metadata`
  // (work_item.dart:119), so the merged map must be built BEFORE the call.
  metadata: metadataMerge == null
      ? item.metadata                                        // unchanged
      : {...?item.metadata, ...metadataMerge},                // MERGE
  …
);
```

**Why REPLACE would be a silent data-loss bug, not a style preference.** The live work item this
feature exists for, `defect-DEF-1791686704991884`, carries these eight metadata keys (verified
read-only against the QA database):

```
defectId · defectTitle · defectEvidence · defectReporter · defectSeverity
defectDescription · defectExpectedBehavior · defectReproductionSteps
```

Every one of them is read by `triageDefectInstruction` when the scheduler builds the job
(`triage_defect.dart:49-56`) and forms the **defect payload the agent is asked to triage**. A REPLACE
would wipe them on the first retry, so the retried triage job would receive
`defectId = workItemId`, empty description and `evidence = []` — a job that would **look perfectly
healthy and classify nothing**. That is the same silent-no-op class as D-4, one layer down.

**Proof that existing keys survive — required of the implementation (AC-37):** a test that seeds a
work item carrying all eight defect keys, performs the retry transition with
`metadataMerge: {triageAttempt: 1}`, and asserts that afterwards **all eight keys are still present,
byte-identical, with `triageAttempt` added**. The test must fail if the merge is ever changed to a
replace.

**What it costs. None beyond the additive parameter — and that is a verified claim, not an
assumption.** No **further** `WorkflowStore` method is required for `metadataMerge` specifically —
it is a parameter, not a method — and the implementor count does not move. **[The interface's OTHER
new method, `readOperatorActionsForWorkItem`, is unrelated to this one and is counted in the row
above; the total is two, not one.]**
because:

1. The work item is already written inside the existing transaction via
   `tx.saveWorkItem(finalItem, expectedVersion: item.version)` (`durable_workflow_engine.dart:203-205`),
   and the merge only changes what `finalItem.metadata` contains.
2. `PostgresWorkflowStore` already round-trips the column: `metadataJson` is in the INSERT
   (`postgres_workflow_store.dart:50`, `:56`), in the UPSERT `:140`, and is decoded back at `:263`.

**§6.4.4's cost table is corrected accordingly.** The earlier 1.3.0 wording — *"the interface gains
one method"* alongside a `metadataMerge` that no signature declared — understated nothing on the
implementor count but was internally inconsistent. **[CORRECTED at 1.5.0 — H-C: the count remains **8** (the HEADCOUNT is right); the METHOD count was wrong — the interface gains]
**TWO** methods: `appendOperatorAction` (from HD-2) and `readOperatorActionsForWorkItem` (§6.4.3). `metadataMerge` itself adds **a parameter to an existing method**, not a method.

**Relation to HD-2.** `metadataMerge` is **not** part of HD-2 and is not "unchanged" with it. HD-2 is
the audit row. `metadataMerge` is **new at 1.3.0**, introduced by **HD-4's accepted cost** — it is the
mechanism that makes the fresh dedupe key of §6.7 possible. §16.2 previously mislabelled it
`-- HD-2, unchanged`, which is exactly how an implementer drops new work; corrected there.

### 6.5 The workflow-engine edge — HD-4's answer, and the seam DELETED

> ### THE §6.5 SEAM IS DELETED. It is not re-specified, narrowed, or replaced by a fourth variant.
>
> **Three successive specifications of a scheduler dispatch seam have now failed, and this section is
> the record of why the fourth was not attempted.**
>
> | Version | What it specified | Why it was dead |
> |---|---|---|
> | **1.1.0** | The rule *appended* "after the existing checks, never instead of them" (`design-brief.md:975-992` at the time) | Two `continue`s already dropped any `agentExecuting` job — `scheduler.dart:578-581` and `:593-594`. The rule sat **behind a `continue` that had already fired**. Caught as finding B1. |
> | **1.2.0** | An explicit **alternative branch**, replacing `:579-581` and `:593-594` on branch B, with a policy re-check `evaluateWorkItemTransition(from: item.state, to: _definition.targetState)` | On branch B `item.state` **is** `agentExecuting` and the target **is** `agentExecuting`. `(agentExecuting, agentExecuting)` is **absent** from `_legalTransitions` (0 occurrences; `agentExecuting` is a `from` only at `:100` and `:105`), and `_isGenericEscape` returns false for self-transitions (`:303` — `if (from.isTerminal || to == from) return false;`). So `isLegalTransition` is false (`:309-312`), `validate()` fails the `legal_transition` guard (`:340-353`), `isValid` is false, and `if (!edge.isValid) continue;` drops **every** authorised retry. |
> | **1.2.0, worse** | The two conjuncts are **mutually unsatisfiable** | The authorisation conjunct requires the audit row to name the item's **latest** transition — which is the `agentFailed → agentExecuting` edge, so the item **is** in `agentExecuting`. The edge-legality conjunct requires `from != to` — so it is **not**. **No work item satisfies both.** |
>
> **Root cause, per decision `8a3f6b17` (HD-4): `agentExecuting` means "an execution is ALREADY
> RUNNING".** Transitioning a failed item into it asserts something untrue, and the scheduler
> *correctly* refuses to dispatch an item that claims to already be executing. **Specifying a
> dispatch seam around that target was the wrong shape, not merely a wrong implementation.**
>
> The decision's own instruction — *"Do not re-specify it, narrow it, or reach for a narrower
> variant — three narrower specifications already failed"* — is binding on this revision, and it is
> the lesson **D-6** recorded (a design-agent discovery about this very seam that had no durable ID
> until 1.3.0, and that **predicted this exact failure**).
>
> **What is therefore absent from this brief as of 1.3.0**, and must not reappear: any change to
> `Scheduler._eligibleRunnableJobs`; any branch on `statusOf`; any replacement of `isRunnable`;
> any `worker_execution` guard; any use of `isEligibleAt`, `hasAllProvidersDown`,
> `isLegalTransition` or `evaluateWorkItemTransition` in the retry path; and the `_policy.isLegalTransition(...)`
> call at former `:1136`, which named a method `WorkflowEngine` does not expose and contradicted
> the corrected API at `:1089`.

#### 6.5.1 The edge

**Decision `8a3f6b17` → `DESIGN_NOT_REQUIRED`.** The operator retry moves the item
**`agentFailed → designNotRequired`**, and the **existing** scheduler path does everything else.
`designNotRequired` is a triage entry state (`triage_defect.dart:10`) and
`designNotRequired → agentExecuting` is **already an exercised edge** — confirmed live,
`work_item_transition.tr-hn3lio9ndj-1hjznv6`, `design_not_required → agent_executing`,
`actorId = orchestrator`, `occurredAt 2026-10-11 02:45:25.310779`.

```dart
// packages/workflow_engine/lib/src/transitions/work_item_transitions.dart
// ONE new entry. Placed immediately after the existing agentFailed edge at :108-110.

    (WorkItemState.agentFailed, WorkItemState.agentExecuting): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    // RETRY: an operator returns a failed agent run to the DESIGN-NOT-REQUIRED
    // entry state, which the triage definition already lists (triage_defect.dart:10),
    // so the existing dispatch path applies unchanged. See design-brief.md §6.5.
    (WorkItemState.agentFailed, WorkItemState.designNotRequired): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
```

**The guard is derived from the real table's own convention for an edge into an entry state**, not
invented. Every edge in the file was classified by target:

| Target | Edges | Guards used |
|---|---|---|
| `→ agentExecuting` ("an agent is about to start") | `:36-39`, `:46-49`, `:88-91`, `:96-99`, `:108-110` | `actorAllowed` **+ `agentAvailable()`** — except `:108-110` |
| **`→ designNotRequired`** | `:28-30` (`planned → designNotRequired`) — **the only precedent** | `actorAllowed([ActorType.orchestrator])` **alone** |
| `→ designApproved` | `:50-59` | `actorAllowed` + `blockingHumanDecisionResolved` + `decisionActorIsHuman` |
| `→ cancelled`/`terminated` (escape) | `:302-307` | `actorAllowed([orchestrator])` / `[orchestrator, system]` |

`planned → designNotRequired` (`:28-30`) carries **no** evidence guard — no `designContractExists()`,
because `designNotRequired` asserts that **no** design is required, so there is nothing to prove. The
new edge is exactly analogous: an operator restarting a failed run is not asserting a design contract,
a QA contract, or an agent's availability. **It carries `actorAllowed([ActorType.orchestrator])` and
nothing else — which is precisely what the one existing edge into that state carries.**

> **On the absent `agentAvailable()` guard — this is the table's convention, not an oversight, and it
> is the same fact as P-2.** `agentAvailable()` appears only on `→ agentExecuting` edges, i.e. only
> where the transition asserts *"an agent is starting right now"*. Our edge asserts nothing of the
> kind; the agent will start later, when the scheduler claims a job, which is where
> `JobCapacityGuard` enforces the cap (`job_capacity_guard.dart:92-186`). **Capacity is therefore
> still enforced, at claim time, by machinery that already exists and is already tested** — which is
> the whole point of HD-4. Adding `agentAvailable()` here would assert an agent is available at a
> moment when, by construction, none has been claimed.

**Legality, proved against the real engine** — the failure mode of 1.2.0 was asserting a transition
legal without proving it, so this is a proof, not a claim:

1. `_legalTransitions[(agentFailed, designNotRequired)]` → the new entry is present.
   `agentFailed` therefore now has **two** explicit `from` edges (`:108-110` and the new one); before
   this change it had exactly one, verified by `grep "(WorkItemState.agentFailed,"` → 1 hit.
2. `_isGenericEscape(agentFailed, designNotRequired)` → `agentFailed.isTerminal` is **false**;
   `to != from` is **true**; but then `to == cancelled || to == terminated` is **false**, so the
   escape returns false (`:302-307`). **That is not a problem** — `isLegalTransition` is
   `_legalTransitions.containsKey(...) || _isGenericEscape(...)` (`:309-312`), and the first operand
   is already true.
3. `validate()` therefore does **not** take the `legal_transition` failure at `:340-353`, and instead
   evaluates the guards. `actorAllowed([ActorType.orchestrator])` passes for the operator actor
   (§6.4.1: `WorkflowActor(actorId: 'operator-retry', actorType: ActorType.orchestrator)`), which is
   the same actor `planned → designNotRequired` already uses.
4. **`from != to`.** `agentFailed ≠ designNotRequired`. **The 1.2.0 self-transition defect cannot
   recur**, because there is no state whose latest transition is both `agentFailed`-entered and
   `designNotRequired`-exited.

**Proved by test, not by this paragraph.** AC-35 requires a test that runs
`WorkItemTransitions.validate(from: agentFailed, to: designNotRequired, …)` with the operator actor and
asserts `isValid`, plus a negative control asserting
`validate(from: agentExecuting, to: agentExecuting, …)` is **invalid** — the latter exists so the
1.2.0 defect cannot be reintroduced silently.

#### 6.5.2 What the existing path then does — no change required

Starting from `designNotRequired`, **nothing in `packages/scheduler` is touched**:

| Step | Citation | Result |
|---|---|---|
| `RunnableWorkEvaluator.evaluate` | `runnable_work.dart:83-85` | `designNotRequired` **is** in `triageDefectDefinition.entryStates` (`triage_defect.dart:10`), so the entry-state gate passes |
| …then the policy check | `runnable_work.dart:94-100` | `evaluateWorkItemTransition(designNotRequired → agentExecuting)` — an edge that **exists** (`:96-99`), guarded by `actorAllowed([orchestrator])` + `agentAvailable()`, with `context: {agentAvailable: true, capabilitiesMatch: true}` and an orchestrator actor ⇒ **`runnable`** |
| `Scheduler.tick` step 3 | `scheduler.dart:492-516` | enqueues with the dedupe key of §6.7 |
| `_eligibleRunnableJobs` | `scheduler.dart:569-599` | `statusOf == runnable` ⇒ **not** dropped by `:578-581`; `isRunnable` re-check at `:593-594` ⇒ **passes** |
| `_claim` → `JobCapacityGuard.tryAdmit` | `scheduler.dart:652-697` | capacity enforced exactly as for any other job; denial leaves the job `queued` |
| a later tick | `scheduler.dart:524-556` | retries the job until a slot frees |

**This is the same path the live transition `tr-hn3lio9ndj-1hjznv6` already walked.** P-1's gates G1–G4
remain exactly as the reviewer confirmed them; what changes is that the retry now arrives at a state
**G1–G3 accept**, instead of colliding with them. G4 — the consumed terminal dedupe key — is handled
in §6.7.

#### 6.5.3 The honest bonus: the label stops lying

At 1.0.0 §7.1 had to *mitigate* a side-effect of the seam: a capacity-denied retry left the item in
`agentExecuting`, which reads **"Working on it"** although nothing is running — a second instance of
the quiet-screen defect, which the brief could only hand-wave.

**HD-4 removes it.** `design_not_required` maps to **`PlainStatus.waitingToStart`** —
*"Waiting to start"* (`plain_language.dart:102-104`) — whereas `agent_executing` maps to
`workingOnIt` (`:109-116`). So a retried item that cannot start yet now says **"Waiting to start"**,
which is **true**, and flips to **"Working on it"** only when a job is actually claimed and dispatched.

That is the doctrine's own test — *a quiet screen must never be indistinguishable from a healthy
one* — satisfied by the state choice rather than by copy. **No mapping is changed** (AC-23 holds);
the mapping was already correct and the seam was feeding it the wrong state.


### 6.6 Retry-count limit — a fail-closed bound on spending

> ### ⚠️ SUPERSEDED IN FULL — HD-5 `8585491a-11a9-473e-ae4f-d66a210408f3`, 2026-10-12
>
> **The heading above and every clause in §6.6 are SUPERSEDED.** They are retained verbatim as the record
> of what HD-3 (`5d9a1f62`) decided and of why it was defensible. They are **not current instruction** —
> do not implement from this section.
>
> **What is true now.** Operator retry is **UNCOUNTED by default**. `SHIPIT_OPERATOR_MAX_RETRIES` unset,
> blank, unparseable or negative ⇒ the action is **offered**, not withheld. An explicit `0` still disables
> operator retry; an explicit positive integer still caps it, counted per work item exactly as HD-3 counted
> it. **AUTOMATIC retries are UNAFFECTED** — still bounded by the job's own `maxAttempts` through
> `RetryPolicy.canRetry` (`triage_defect` is still `maxAttempts: 2`). `SHIPIT_OPERATOR_MAX_RETRIES` does
> not read or write that path.
>
> **Why the human reversed it.** The action is human-triggered through an authenticated operator session
> whose only caller is the operator UI, and an operator deciding whether to try again is the person best
> placed to decide. The human wants a count only where the retry is **agent-driven**, and that bound
> already exists one layer down.
>
> **HD-3 was not wrong.** *"An operator action that spends real credits must never be armed by a missing
> configuration"* is sound reasoning, applied to the wrong actor. Withholding the button when the variable
> is unconfigured is indistinguishable from a broken screen to the operator the screen exists for, and the
> spend firehose HD-3 feared is not reachable — there is no automation caller of that RPC.
>
> **Residual risk, stated rather than buried.** `requestedBy` is a **client-supplied `String`**, not a
> cryptographic identity claim. "Human-triggered" therefore rests on the **caller list**, not on the
> recorded identity. If an agent, cron, webhook or non-UI caller is ever added, this decision's premise
> is void and it must be **reopened**, not compensated for by raising the cap.
>
> Record: `.decisions/8585491a-11a9-473e-ae4f-d66a210408f3.yaml`. HD-3's own object carries the matching
> `## SUPERSEDED IN FULL` block: `.decisions/5d9a1f62-8b37-4e50-a9c4-71f2d8b3e605.yaml`.

The job's `maxAttempts: 2` (`triage_defect.dart:12`) is **per job**. A retry creates a new job and
therefore a **fresh** budget, so an unbounded button is a spend firehose: click it N times, pay N
times. The screen is where a human is told the running total, and it is where the bound belongs.

> **[CLOSED by HD-3 → `THREE_PER_ITEM_FAIL_CLOSED`, `5d9a1f62-8b37-4e50-a9c4-71f2d8b3e605` (POLICY,
> RESOLVED).]** The human confirmed the fail-closed mechanism and **rejected my proposed alternative
> shape**: *"a per-operator-per-day cap is trivially reset and does not bound a single pathological
> item."* The count is **per work item**. The value is **3**.
>
> ⚠️ **[SUPERSEDED — HD-5 `8585491a`, 2026-10-12.]** This blockquote is **retained as history, not as
> instruction.** HD-3 is superseded in full; see the §6.6 banner. One clause of it **survives and is
> still correct**: the human's rejection of a per-operator-per-day cap. That reasoning is unchanged and
> governs the explicit-cap case, which HD-5 keeps. The **value 3** no longer applies to anything — 3 is
> now a value an operator may choose to configure, not a default.

Design:

> ⚠️ **[SUPERSEDED — HD-5 `8585491a`, 2026-10-12.]** All three bullets below are superseded as
> instructions. Bullet 1's **fail-closed** arm ("absent, blank, unparseable, or negative ⇒ **retry is
> unavailable**") is now **inverted**: those values resolve to **unbounded** and the action is **offered**.
> Bullet 2 ("there is no code-level default") is superseded — there is now **no count at all** by default,
> which is a different thing and not a fallback constant. Bullet 3's **counting mechanism and its
> per-work-item ledger source survive intact** for the explicit-cap case. Bullet 1's sub-bullet is
> **split**: its "reuse the *pattern*" half is superseded, its "`0` must resolve to a RESOLVED value
> meaning *permanently disabled*" half is **still exactly right** and is preserved by HD-5.
>
> **What an implementer needs instead:** unset/blank/unparseable/negative ⇒ `unbounded`; `0` ⇒ permanently
> disabled; positive `N` ⇒ capped at `N`. `retryLimitResolved` no longer means "a count is configured" —
> the uncounted state is a **resolved** state, not a missing one.

- `SHIPIT_OPERATOR_MAX_RETRIES` — **required**, integer ≥ 0, resolved at startup by a resolution
  modelled on `ExecutionCapacityResolution.fromEnvironment`
  (`execution_capacity.dart:125-173`): absent, blank, unparseable, or negative ⇒ **retry is
  unavailable**, and the reason is stated in the startup log and in `WorkItemActionContextView`.
  - **[ADDED at 1.2.0 per the reviewer's M1 — DO NOT REUSE `ExecutionCapacityResolution` VERBATIM.]**
    That helper resolves `parsed < 1` to `UNRESOLVED` with a *"below the minimum of 1"* diagnostic
    (`execution_capacity.dart:156-164`), so an implementer who reuses it emits
    `retryLimitResolved: false` **plus a failure-styled diagnostic** for a configuration AC-15c calls
    **valid**. `0` must resolve to a **RESOLVED** value meaning *permanently disabled*, with a
    diagnostic that reads as configuration (`retry disabled by configuration: limit is 0`) and not as
    failure. Reuse the *pattern* — fail closed, named reason, no fallback — not the helper.
- **There is no code-level default, and this is deliberate.** The decision says both *"default 3 per
  work item"* and *"if the limit is unset the retry action is never offered"*. Read together they
  mean: **3 is the value operators must configure; there is no fallback constant in the code.** The
  reason is the decision's own: *"An operator action that spends real credits must never be armed by
  a missing configuration."* An implementer who reads "default 3" as "absent ⇒ 3" would invert the
  decision, so the brief states it three times: §6.6 bullet 2, AC-15b, and AC-15c.
  > ⚠️ **[SUPERSEDED — HD-5 `8585491a`, 2026-10-12.]** The *reasoning* above is HD-3's and it is
  > retained because it was sound; the *conclusion* is **reversed**. A missing configuration no longer
  > disarms the action — it leaves it **uncounted**. The trap this bullet warned about has moved rather
  > than vanished: an implementer who now reads "default 3" as "absent ⇒ 3" would re-introduce a
  > fallback constant where the decision wants **no count**. **There is no default and there is no
  > fallback: absent means uncounted.**
- `attemptNumber` counts `operator_action` rows for this work item with `action = 'retry'`
  (`operator_action_retry_idx`). At 1.0.0 this count was taken from accepted transitions; at 1.1.0 it
  comes from the audit table, which is exact and append-only. `attemptLimit` is the
  resolved maximum. When `attemptNumber >= attemptLimit` the server returns `notConfigured` and the
  client **does not render the retry button at all**.
- The panel states the position before the click: `This will be attempt 2 of 3.` Never a bare
  "Try again".

> **Why fail closed rather than ship with no limit.** A missing value must not mean "unlimited" —
> that is the exact reasoning already recorded for the capacity cap: *"a cap that defaults to
> 'unlimited' re-creates the host exhaustion it was built to prevent"*
> (`execution_capacity.dart:88-92`). The decision adopts the same reasoning verbatim.
>
> ⚠️ **[SUPERSEDED — HD-5 `8585491a`, 2026-10-12.]** This is the clause the reversal most directly
> inverts, so the scope of the reversal is stated precisely rather than swept broadly:
>
> - **Operator retry** now *does* ship with no limit, and a missing value **does** mean unlimited. This
>   bullet is therefore **wrong as applied to `SHIPIT_OPERATOR_MAX_RETRIES`** and must not be used to
>   argue for reinstating a fail-closed default.
> - **The capacity cap is NOT reversed.** `SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS` still fails closed when
>   unset, and `execution_capacity.dart:88-92` still says exactly what it says. The "unlimited re-creates
>   host exhaustion" reasoning remains **correct and governing for the capacity guard**, which is why HD-5
>   leaves automatic retries bounded by `maxAttempts` and touches nothing there.
> - **Why the two cases differ, since the cited reasoning would otherwise read as governing both.** The
>   capacity cap bounds *machine-wide agent concurrency* and a missing value there means *unbounded work
>   on a host that has already kernel-crashed once*. Operator retry bounds *one human pressing one
>   button*, and the action's only caller is an authenticated operator session. The reasoning was never
>   wrong; the two subjects are not alike, and HD-3 extended it to the weaker of the two.
>
> #### 6.6.1 The unset case is a VISIBLE state, not an absent one
>
> ⚠️ **[SUPERSEDED IN WHOLE — HD-5 `8585491a`, 2026-10-12.]** This subsection exists to make an
> unavailable action visible. **The action is no longer unavailable when the variable is unset** — it is
> offered, uncounted. All three obligations below, and the panel variant in §8, describe a state the
> product no longer has. They are retained because HD-3's follow-up demanded them and because the
> *reasoning* behind them survives in a narrowed form.
>
> **What survives, and it is real:** an operator must never have to guess whether a missing button means
> "you may not do this" or "something is broken". HD-3 got that right and it still binds — for the states
> that **remain**: an explicit `0` (permanently disabled) and an explicit positive `N` once reached
> (`notConfigured` from the count). The `liveRegion` announcement, the `retryLimitDiagnostic` on
> `WorkItemActionContextView` and the startup log line all remain correct **for those states**.
> `retryLimitResolved: false` now means **"explicitly disabled or count exhausted"**, never "unset".
>
> **What no longer applies:** obligation 2's `Starting this again is switched off on this machine. Nothing
> has been changed.` as the *unset* case, and obligation 3's use of `capacitySummary` as the reason to log
> an unset limit at all. An unset limit has nothing to announce, because it constrains nothing.
> The decision's binding follow-up: *"The unset-means-unavailable behaviour must be visible in the
> design and in the acceptance criteria, not treated as an incidental detail."* Three obligations
> follow, and all three are testable:
>
> 1. **The server says which.** `WorkItemActionContextView` gains `retryLimitResolved: bool` and
>    `retryLimitDiagnostic: String?`, carrying the same diagnostic string
>    `ExecutionCapacityResolution` produces — naming the variable and what was wrong with it. It is
>    never a fallback value and never a blank.
> 2. **The panel says which.** When `retryLimitResolved == false` the panel renders the retry
>    position as unavailable, in the existing vocabulary and not as an error:
>    *`Starting this again is switched off on this machine. Nothing has been changed.`* — with
>    **"Stop this work" still offered**, because HD-1 decided that an operator who cannot retry must
>    still have both answers. A missing configuration must not remove the human's only exit.
> 3. **The startup log says which**, on the same pattern as `capacitySummary`
>    (`scheduler.dart:391-396`), which exists precisely because *"an operator who cannot see the cap
>    in force cannot tell a saturated queue from an unbounded one"*.
>
> **QA pre-condition — recorded because getting it wrong makes a correct screen look broken.**
> `SHIPIT_OPERATOR_MAX_RETRIES=3` must be set on the QA stack **before** the screen is exercised.
> All four compose files that already carry `SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS`
> (`docker/compose.yaml:82`, `compose.qa.yaml:76`, `compose.e2e.yaml:64`, `compose.test.yaml:114`)
> are where the new variable belongs, beside it, with the same `${VAR:-3}`-style interpolation and the
> same do-not-delete comment. **Those files are deployment configuration and are outside this
> design lane's `OWNED_PATHS`** — this brief records the requirement and does not make the change.
> Owner: `orchestrator-main`, exactly as the decision's follow-up assigns it.
>
> ⚠️ **[SUPERSEDED — HD-5 `8585491a`, 2026-10-12.]** **This obligation is discharged, and it is
> discharged by REMOVAL — do not set the variable anywhere to satisfy it.** Setting
> `SHIPIT_OPERATOR_MAX_RETRIES=3` on any stack now *re-creates a cap the human removed*; a stack that
> wants the cap sets it deliberately, and a stack that does not sets nothing.
>
> **The `${VAR:-3}` interpolation this block prescribes must not be written into any compose file.** The
> four stacks now read `${SHIPIT_OPERATOR_MAX_RETRIES:-}` (empty) or omit the variable entirely. Three of
> them had `:-3` **committed** by `d41f2b6` and were lowered to empty by `8492dcb`; `compose.qa.yaml`
> never had it at any commit. The `:-3` the QA stack was actually running existed **only as an
> uncommitted working-tree edit** — so the cap the live QA environment carried was invisible to review
> and to anyone reading the repository. That edit has been removed and a comment recording why now
> stands in its place. Owner: `orchestrator-main`.
>
> Without it, the retry button will **correctly** not appear, and an operator (or QA) will reasonably
> conclude the screen is broken. That is the correct behaviour producing a false signal, and the two
> must not be confused.

### 6.7 The dedupe key — a fresh key per retry, derived from the audit ledger

**This is the cost HD-4 named and accepted, and it must be specified or the retry silently no-ops.**

**The fact (G4, unchanged).** `JobQueue.enqueueIfAbsent` returns the existing job whenever *any* job
already exists under the dedupe key, terminal or not — it calls `findLatestByDedupeKey`
(`job_queue.dart:55-58`), which is `SELECT * FROM "job" WHERE "dedupeKey" = @dedupeKey ORDER BY
"createdAt" DESC LIMIT 1` with **no state filter** (`postgres_job_store.dart:246-256`). The live
failed job owns `defect-DEF-1791686704991884:triage_defect` with `activeDedupeKey` NULL (terminal
releases it, `:17-26`). So the default key is **permanently consumed** for that item, and reusing it
returns `created: false` and does nothing. This is also discovery **D-4**, which additionally notes
that the one caller reporting this labels it *"a concurrent caller won this dedupe key"* — false
when the existing job is terminal.

**Why the key cannot carry the `requestId` (the 1.2.0 answer, now wrong).** §6.4 no longer enqueues,
so the RPC never computes a key. The only thing that computes one is the scheduler's
`dedupeKeyBuilder`, and its signature is fixed and **synchronous**:

```dart
// packages/scheduler/lib/src/scheduler.dart:113-115
/// Function to build a dedupe key for a work item.
typedef DedupeKeyBuilder =
    String Function(WorkItem item, JobDefinition definition);
```

No store, no async, no request context — and it runs on **every** tick for **every** runnable item,
including items nobody retried. **The only per-retry discriminator available synchronously is a field
on the `WorkItem` itself**, and `WorkItem.metadata` is exactly that: `triageDefectInstruction`
already reads `item.metadata` for `defectId`, `defectTitle` and the rest
(`triage_defect.dart:49-56`), `work_item.spy.yaml` carries `metadataJson`, and
`WorkItem.copyWith` supports it (`work_item.dart:85`, `:119`).

**The rule:**

```dart
// packages/scheduler/lib/src/triage_defect.dart — the ONLY change to this file

/// Builds a dedupe key for triage defect jobs: (defectId, jobType[, attempt]).
/// Only one active triage job per defect at a time.
///
/// ## Why the attempt suffix exists (HD-4, decision 8a3f6b17)
///
/// An operator retry returns the work item to `designNotRequired`, so the scheduler
/// enqueues for it again — but `JobQueue.enqueueIfAbsent` resolves a key that ANY job
/// already holds, terminal or not (`job_queue.dart:55-58` over
/// `postgres_job_store.dart:246-256`, which has no state filter). The original triage
/// job for a failed item is TERMINAL, so its key is consumed for ever and reusing it
/// returns `created: false`: the retry silently does nothing.
///
/// The discriminator has to be readable from the WorkItem alone, because
/// `DedupeKeyBuilder` is synchronous and takes no store (scheduler.dart:113-115).
/// `metadata['triageAttempt']` is written by the retry inside the transition's own
/// transaction (design-brief.md §6.4 step 3), so it is durable before any tick can
/// read it.
///
/// ## WHY THE ABSENT CASE IS BYTE-IDENTICAL TO TODAY
///
/// With no `triageAttempt` the key is exactly the historical format. Every job
/// already persisted under `'<workItemId>:triage_defect'` keeps matching, so this
/// change orphans NOTHING. Changing the format for the default path would silently
/// strand every historical triage job — the same error the work-entry design warns
/// about when it insists the key is imported and never re-spelled.
String triageDefectDedupeKey(WorkItem item, JobDefinition definition) {
  final base = '${item.workItemId}:${definition.jobType.wire}';
  final attempt = (item.metadata ?? const <String, dynamic>{})['triageAttempt'];
  return attempt is int ? '$base:a$attempt' : base;
}
```

**Four properties, each of which a test must hold (AC-36):**

| # | Property | Why it is the requirement |
|---|---|---|
| 1 | **Absent ⇒ unchanged.** No `triageAttempt` ⇒ `'<workItemId>:triage_defect'`, byte-identical to today. | No historical job is orphaned; the default path is untouched. **This is the property that must not be traded away for anything.** |
| 2 | **Distinct per retry.** Attempt *n* ⇒ `:a1`, `:a2`, `:a3`. Each retry therefore finds its key unconsumed and `enqueueIfAbsent` really creates a job. | Without it, retry #2 and onward silently no-op (D-4). |
| 3 | **Deterministic and replay-safe.** The key derives from the *durable* `metadata.triageAttempt`, written in the same transaction as the transition (§6.4 step 3). | A **network retry of the same operator action cannot mint a second job**: it either finds its own `operator_action` row and returns `accepted` (step 0), or recomputes the same `n` from the ledger. This is HD-4's explicit requirement: *"a network retry must NOT mint a second job."* |
| 4 | **Both enqueuers converge on the same key.** `Scheduler.tick` (`server.dart:272` injects `triageDefectDedupeKey`) and `WorkEntryTrigger.ensureWorkEntry` both call this same imported builder. | Two enqueuers, one key ⇒ the `job_active_dedupe_unique` index (`job.spy.yaml`) arbitrates a concurrent double-enqueue and `enqueueIfAbsent` re-resolves `DuplicateActiveJobException` to the winner (`job_queue.dart:82-88`). **One job, whoever creates it.** |

**One consequence stated rather than hidden.** The work-entry sweep (`defect_triage_sweep.dart`,
currently gated off) will also enqueue for a retried item, using this same builder and therefore the
same key. That is **correct** — it is the belt to the scheduler's braces — but its skip message still
mislabels a consumed terminal key as a concurrent race (D-4, §14.2). Unchanged by HD-4; not fixed here.
---

## 7. Capacity-denied behaviour, and the weird states

### 7.1 Denial is a queued alternative — and after HD-4 the retry itself cannot be denied

**The shape changed, and changed for the better.** At 1.2.0 the retry RPC claimed a slot itself and
could be refused. At 1.3.0 it writes one transition and returns; **capacity is never consulted on the
retry path at all**, so there is no retry-time denial outcome to design. What remains is the
scheduler's ordinary, already-tested behaviour.

1. **Nothing is pre-gated** (P-5), and now nothing is post-gated either — the retry RPC never
   contacts `JobCapacityGuard`.
2. **The retry always succeeds if the edge is legal.** `outcome: 'accepted'`. The operator is told:
   `Done — it will start as soon as a machine is free.`
3. **Capacity denial happens later, in the scheduler, where it has always happened.**
   `_claim` → `JobCapacityGuard.tryAdmit` returns `CapacityDenied`
   (`scheduler.dart:676-695`, `job_capacity_guard.dart:50-82`), which writes **nothing** — no claim,
   no state change, no failure — and records a `capacityDenied` scheduler event
   (`job_capacity_guard.dart:71-78`). The job stays `queued`, the tick reports it as `deferred`
   (`scheduler.dart:537-543`), and a later tick retries it with no human action and no loss.
4. **The item's label is now truthful while it waits.** `design_not_required` maps to
   **`PlainStatus.waitingToStart`** — *"Waiting to start"* (`plain_language.dart:102-104`) — and
   flips to `"Working on it"` only once a job is actually claimed and dispatched. **This is new at
   1.3.0 and it retires a hand-wave**: 1.0.0 §7.1 item 4 had to *mitigate* a capacity-denied retry
   falsely reading *"Working on it"* by relying on the panel still showing the job. HD-4 removes the
   falsehood at the source. **No mapping changes** (AC-23 still holds).
5. **The capacity snapshot stays**, because it is still true and still useful — `snapshotOnly` is
   always `true` (§7.2), and it is what lets the panel say *"2 of 2 agent slots busy"* before the
   operator commits.
6. **There is no UI affordance to override, prioritise, or force.** Not "run anyway", not "raise the
   cap", not "skip the queue" (§10). Unchanged, and now easier to honour: there is no seam through
   which an override could be threaded.

> **The requirement is unchanged even though the mechanism is not.** Dispatch constraint 3 asked for
> *"a queued alternative, NOT a button that silently does nothing."* HD-4 satisfies it **structurally**
> rather than by copy: the item lands in a state the scheduler genuinely re-dispatches, so the queued
> alternative is the platform's ordinary behaviour instead of a promise the design has to keep.

### 7.2 Capacity snapshot: a snapshot, labelled as one

`ExecutionCapacityView.snapshotOnly` is **always `true`**. The copy must read as an observation:
`2 of 2 agent slots busy` — never `You can start now`, never a promise of a start time. The
`inFlight` count is derived from durable `job.state` rows exactly as the guard derives it, so the
number on screen and the number the guard uses are the same number. **Unchanged at 1.3.0** — this is
the one part of the capacity story HD-4 did not touch, because the screen still shows the budget
before the operator decides.


### 7.3 The underlying job or execution is in a weird state

| Situation | Detected by | Behaviour |
|---|---|---|
| A non-terminal job exists for this item from another attempt | §6.4 step 1 | `alreadyRunning`. **Nothing written.** The panel says `This work is already running.` and offers no retry button while it holds. |
| The prior job is terminal (`failed` — today's case) | `activeDedupeKey IS NULL` | Retry proceeds under the **fresh** key of §6.7. Without that key this row silently no-ops (D-4). |
| A prior job is terminal `cancelled` | same | Retry proceeds. Cancelling a job is not cancelling the work item, and `WorkItemState.agentFailed` is still the truth. |
| A non-terminal **worker_execution** exists for this item | the scheduler's ordinary `worker_execution` reconciliation, untouched by this design | The job stays `queued` and is retried on a later tick. **The retry RPC's `alreadyRunning` guard (§6.4 step 1) already refuses a new action** while any non-terminal job exists, so the operator cannot add a second attempt on top. |
| The item is mid-zombie-reclaim (state flickers `agentExecuting`) | state re-read in step (1) of §6.4 | `notApplicable`. The screen re-reads the action context and shows whatever is legal *then*. |
| `saveWorkItem` loses its compare-and-swap | `ConcurrentModificationException` | Bounded retry, **3 attempts**, mirroring `Scheduler._maxReclaimAttempts`
(`scheduler.dart:322`). The two rejection signals are caught **separately**, because
`ConcurrentModificationException` is a *sibling* of `WorkflowTransitionRejectedException` and not a
subclass — a defect the scheduler already fixed once
(`scheduler.dart:1005-1028`). |
| The store faults mid-transaction | exception | Nothing written; `notApplicable` with a logged reason. The operator sees `We could not do that. Nothing changed.` — never a silent failure. |
| The item is in `agent_completed` (the 9 parked items) | state re-read | `notApplicable`; **no action panel**. Not this screen's problem (§14). |

---

## 8. Layout and interaction

### 8.1 Where it sits

**In the existing right-hand column of the Run detail page.** `run_detail_page.dart` already
composes `_LeftColumn` (record) + `_RightColumn` (392px `SidePanel`, `:176-179`), stacks them when
the pane is too narrow (`:150-168`), and puts a single primary button below the record on mobile
(`:136-148`). The action panel **replaces the current "Nothing needs you here" branch**
(`:651-667`) and adds nothing to the left column beyond one definition row.

No new route, no new screen, no new navigation entry. The URL the operator already has —
`/#/runs/defect-DEF-1791686704991884` — becomes the place where the work happens.

### 8.2 The panel

```
┌─ (3px negative edge, DesignPanel) ───────────────────────────────────────┐
│ Restart after a problem                                                  │  sectionTitle
│ Needs you — it failed. Nothing moves forward until you decide.           │  bodySmall
│ There is no time pressure beyond the limits shown.                        │  (the Home doctrine,
│                                                                          │   home_page.dart:441-445)
├─ WHY IT STOPPED ─────────────────────────────────────────────────────────┤  MicroLabel
│ The machine running this work stopped answering, so it was stopped       │  bodySmall — classifier,
│ and handed back to you.                                                  │   §5.6
│ Stopped today at 10:50 · stopped 1 time since it started.                │  bodyMicro, inkTertiary
├─ (ContentRule) ──────────────────────────────────────────────────────────┤
│ 2 of 2 agent slots busy.                                                 │  monoMeta
│ This will be attempt 1 of 3.                                             │  status, attention
├─ (ContentRule) ──────────────────────────────────────────────────────────┤
│ [ Try again ]        Stop this work                                      │  FilledButton / OutlinedButton
│ Trying again starts the agent from the beginning and costs model         │  bodyMicro, inkTertiary
│ credits. It does not resume where it stopped.                            │
└──────────────────────────────────────────────────────────────────────────┘
```

Everything above is existing vocabulary and existing tokens: `DesignPanel`, `SidePanel`,
`MicroLabel`, `ContentRule`, `ShipItType.sectionTitle` / `bodySmall` / `bodyMicro` / `status` /
`monoMeta`, `palette.negative` / `attention` / `inkTertiary`. **No new token, no new colour, no new
font, no new component.** The 3px panel edge uses `palette.negative`, which is already the tick
colour for `PlainStatus.needsYouItFailed` (`plain_language.dart:52`, `:60`) — the panel edge and the
row tick agree by construction.

**The unset-limit variant** (HD-3, `5d9a1f62` — §6.6.1). When `retryLimitResolved == false` the
`This will be attempt N of M.` line is replaced, and the layout below it does not change:

> ⚠️ **[SUPERSEDED — HD-5 `8585491a`, 2026-10-12.]** This mock is the **unset** case. Under HD-5 an unset
> limit renders `This will be attempt N.` with **no total** — there is no `of M` — and the retry button
> **is offered**. The variant below is still correct for the two states that remain (`0` = permanently
> disabled, and a positive `N` whose count is reached), including its accessibility reasoning: a screen
> reader user must never conclude the screen is broken because a control is missing. Only its *trigger*
> is narrowed, from "unset" to "explicitly disabled or count exhausted". Retained, not deleted.

```
├─ (ContentRule) ──────────────────────────────────────────────────────────┤
│ 2 of 2 agent slots busy.                                                 │  monoMeta
│ Starting this again is switched off on this machine.                      │  bodyMicro, inkTertiary
│ Nothing has been changed.                                                 │
├─ (ContentRule) ──────────────────────────────────────────────────────────┤
│                        [ Stop this work ]                                │  OutlinedButton, alone
└──────────────────────────────────────────────────────────────────────────┘
```

Three properties of this variant, each deliberate:

- **It is not styled as an error.** A missing configuration is an operator-configuration fact, not a
  run failure, and a red panel would misread as "this work is broken".
- **"Stop this work" remains offered.** HD-1 decided that an operator who cannot retry must still
  have both answers; a missing env var must not silently remove the only one that is left.
- **It still says what is true** — *"Nothing has been changed."* A silent omission is the quiet-screen
  failure this whole brief exists to close, in its newest form.

### 8.3 Confirming a retry that spends credits

Reuse the **established two-step shape**, not a dialog. `_ConfirmStrip` on the Needs you card
already does exactly this: press the action → the row is replaced in place by a confirm strip with a
mandatory reason field and a "This cannot be undone." line
(`needs_you_page.dart:329-357`, `:389-517`).

```
After pressing "Try again", in place:

● You chose: Try again                                       ← status, accent (sentiment.proceed)
  Starts a fresh agent run. The previous attempt is kept on record.
┌ WHY ARE YOU DOING THIS? ─────────────────────────────────┐
│ [ Add a short reason — saved with your name (required) ] │  autofocus, TextField
└──────────────────────────────────────────────────────────┘
[ Save: Try again ]   Cancel            This cannot be undone.
```

Copy, and where each string comes from:

| String | Source |
|---|---|
| `You chose: Try again` | existing `_ConfirmStrip` pattern (`:432`) |
| `Starts a fresh agent run. The previous attempt is kept on record.` | new; answers the operator's real question ("does this lose the evidence?") — and it is **true**: nothing is deleted, `jb-hn3liczxln-li36ts` stays `failed` |
| `WHY ARE YOU DOING THIS?` | mirrors `WHY DID YOU DECIDE THIS?` (`:450`) |
| `Add a short reason — saved with your name (required)` | mirrors `:461` verbatim; it is now **enforced server-side** too (§6.3 `invalidRequest`) |
| `Save: Try again` | mirrors `Save: <choice>` (`:484`) |
| `This cannot be undone.` | verbatim from `:499` |
| `Cancel` | `InlineLink` (`:492`), plus **Escape** (§9) |

While submitting: `Saving…` (`:483`), the field disabled (`:458`), and the button disabled. The
copy stays put — the layout does not jump under the pointer.

**The requestId lifecycle** (needed for §6.7's idempotency):

1. Minted **when the operator confirms**, i.e. on the first submit — not on page load, not per HTTP
   attempt.
2. Held in the confirm strip's widget state and **reused for every retry of that same confirmation**
   (network failure, refresh of the *network layer*).
3. Discarded when the confirm strip is cancelled or the action resolves.
4. A **new** confirm after another failure mints a **new** id — which is correct: a second
   deliberate confirm is a second deliberate spend.

### 8.4 What replaces what

| Today | After |
|---|---|
| `_RightColumn` → `SidePanel("Nothing needs you here" / "The system is still working on this run.")` for any item with no blocking decision (`:651-667`) | the action panel, when the server reports a legal action; **the existing text otherwise**, unchanged — a finished run still says *"This run has finished. Its record is kept for audit."* |
| `_LeftColumn` → `DefinitionEntry("WHAT'S NEEDED")` only when blocked (`:282-287`) | one new row: `WHAT YOU CAN DO` → `Start it again, or stop it.` — read-only text; the buttons are in the panel |
| Timeline row `"Agent's work hit an error"` (`transition_copy.dart:39`) | unchanged on the surface; the `reason` moves into the panel's **WHY IT STOPPED** section and stays verbatim in `TechnicalDetails` |
| `TechnicalDetails` footer (`:185-193`) | unchanged, plus two lines: the item's `operator_action` count and the capacity snapshot |

### 8.5 Mobile

`isMobile` (< 840px, `mobile_chrome.dart:450-451`). The panel follows the record, as the decision
CTA already does (`:136-148`): the two buttons become a full-width `MobilePrimaryButton("Try again")`
and a full-width `OutlinedButton("Stop this work")` stacked beneath it, and the confirm strip's
reason field is `maxLines: 2` — the same compromise `_GateCard(compact: true)` already makes and
documents (`needs_you_page.dart:210-213`).

---

## 9. Accessibility

Assessed against WCAG 2.2 AA and against the patterns already in this codebase.

| # | Requirement | How |
|---|---|---|
| A1 | The panel is announced as one unit with a name | `Semantics(container: true, explicitChildNodes: true, label: 'This work needs you: it failed. You can try again or stop it.')` — the **exact** pattern and the **exact** reason given in `_GateCard`'s comment: *"Without this, the buttons' tap actions merge upward into this node and the whole card becomes one tappable region"* (`needs_you_page.dart:218-227`). |
| A2 | The confirm button carries its own state | `Semantics(button: true, enabled: ready, label: ready ? 'Try again. Starts a fresh agent run.' : 'Add a reason first')` — mirrors `needs_you_page.dart:470-478`. |
| A3 | **The outcome is announced, not just drawn** | After the RPC, `Semantics(liveRegion: true)` announces `Queued — it will start when a machine is free.` A screen-reader user must not have to go hunting to discover the click did something. **New — no existing screen in this app uses a live region**, which is itself a gap this design must not extend. |
| A4 | Focus on confirm | The reason `TextField` autofocuses, exactly as `_ConfirmStrip` does (`:456`). |
| A5 | Cancel is reachable without a pointer | **Escape cancels the confirm strip** and returns focus to the action row. **New** — `_ConfirmStrip` today offers only a tap `InlineLink`, which is a WCAG 2.1.1 gap this design closes for the new surface rather than copying. |
| A6 | Nothing is conveyed by colour alone | Every state carries a word: the status label, the outcome sentence, and the button labels. The destructive action is distinguished by the word *Stop*, not by red. |
| A7 | Contrast | Existing tokens only; `ShipItType.bodyMicro` on `inkTertiary` and `status` on `attention` are already on the Overview and Needs you screens at the same sizes. No new pair is introduced. |
| A8 | Target size | Desktop buttons are 150×28 in the existing decision row idiom (`needs_you_page.dart:333-337`); mobile uses `MobilePrimaryButton`. |
| A9 | No motion | None added. `prefers-reduced-motion` is therefore trivially satisfied. |
| A10 | No colour-only state on the retry count | `This will be attempt 1 of 3.` is text, not a badge. |
| **A11 (NEW at 1.1.0, from HD-3)** **An unavailable action is announced, not silently absent** | When `retryLimitResolved == false`, the panel's `liveRegion` announces `Starting this again is switched off on this machine. Nothing has been changed.` A screen-reader user must not conclude the screen is broken because an environment variable is unset — which is precisely the misreading §6.6.1 exists to prevent. |

⚠️ **[SUPERSEDED IN ITS TRIGGER — HD-5 `8585491a`, 2026-10-12.]** The **criterion stands**; only its
`when` clause is narrowed. `retryLimitResolved == false` no longer means "an environment variable is
unset" — it now means **explicitly disabled (`0`) or count exhausted**. The unset case announces nothing
because it disables nothing. The accessibility argument underneath A11 is **not weakened by the
reversal** and should be read as its strongest form: an operator must never have to guess whether a
missing button means "you may not do this" or "something is broken" — which is the confusion HD-5
removes by no longer letting a missing configuration remove the button at all.

**Re-confirmed at 1.1.0.** Neither decision changed the accessibility position: HD-1 added a second
button to a panel already built around `_GateCard`'s semantics pattern (A1 covers both, and A6
distinguishes the destructive one by *word*, not colour); HD-2 changed what is stored, not what is
rendered — the audit row feeds the same `reason` field the panel already displays, plus OQ-1's
`priorActions` list, which reuses `DefinitionList` and therefore inherits the same semantics; HD-3
**adds** an obligation (A11) rather than relaxing one. No criterion from 1.0.0 was weakened.

⚠️ **[PARTLY SUPERSEDED — HD-5 `8585491a`, 2026-10-12.]** The claim "HD-3 **adds** an obligation rather
than relaxing one" is now **false**, and the reversal is a relaxation of A11's trigger. It is recorded
here rather than left to be discovered: A11 was added by HD-3, and HD-5 narrows the state that triggers
it (§9 above). The 1.0.0 accessibility criteria are still **not** weakened — nothing about contrast,
target size, motion or semantics changed. But the honest statement is that one criterion's *applicability*
was narrowed by a later human decision, not by a design revision.

**One honest limitation:** the "why it stopped" classifier (§5.6) is a heuristic over free text. When
it does not recognise a cause it says so in neutral, truthful words rather than guessing — which is
the correct failure direction, but it means the panel is occasionally less specific than the
underlying record. The raw record is always one disclosure away, and that is stated to the reviewer
rather than papered over.

---

## 10. What this screen must NOT do

Each of these is a design constraint, not an implementation detail, and each is testable.

| # | Prohibition | Why |
|---|---|---|
| N1 | **No bypass of the execution capacity guard.** No "run now", no "ignore the queue", no priority bump, no cap override. | The guard exists because an unbounded host crashed on 2026-10-10 (`server.dart:436-446`, `compose.qa.yaml:63-72`). |
| N2 | **No raw SQL, no hand-written state mutation.** Every move is `DurableWorkflowEngine.transition` under the injected policy. | A camelCase state written by hand during an incident broke every scheduler tick (dispatch constraint 4). |
| N3 | **No retry presented as free.** The cost line is on the panel, the consequence line is in the confirm strip, and the attempt count is stated. | Constraint 2. |
| N4 | **No action the transition table forbids.** The action set is computed server-side from `WorkItemTransitions`; the client renders what it is given and renders nothing for an unknown action id. | Constraint 1. |
| N5 | **No `agentFailed -> waitingForHumanDecision` "escalate" button.** That edge does not exist. | `work_item_transitions.dart` — `agentFailed` appears in exactly two entries. |
| N6 | **No auto-retry.** `RunnableWorkEvaluator` is untouched. Nothing in the tick ever walks a failed item back on its own. | The dispatch's own instruction; and `runnable_work.dart:63-67`. |
| N7 | **No silent failure.** Every terminal outcome has a stated operator-facing sentence; every non-terminal one has a visible pending state. | The doctrine. |
| N8 | **No fabricated cause.** The classifier never guesses; the raw reason is never rewritten. | §5.6. |
| N9 | **No change to `agentCompleted` behaviour, to the nine parked items, or to the `PlainStatus` mapping.** | §14 — out of scope, and conflating them would hide the real cause. |
| N10 | **No new `ActorType`, no weakening of `actorIsNotSelf()`, no new guard condition.** | §6.4.1, P-2. |
| N11 | **No second confirmation-free destructive path.** `stop` requires the same confirm strip as `retry`. | — |
| **N12 (NEW at 1.1.0, from HD-2)** **No authorization by string convention.** A dispatch is authorized only by an `operator_action` row — never by an `idempotencyKey` prefix, a metadata flag, a `dedupeKey` shape, or any other naming convention a future caller could satisfy by formatting a string correctly. | Decision `2b8f4c07`: *"Authorization-by-string-convention is not authorization."* Tested by AC-19b. |
| **N13 (NEW at 1.1.0, from HD-2)** **No audit row written outside the transition's transaction, and no update or delete of an existing one.** The audit is append-only and atomic with the state change. | The decision's binding follow-up. A separate write could diverge under a crash; an update would destroy the history the audit exists to keep. Tested by AC-14b/AC-14d. |
| **N14 (NEW at 1.1.0, from HD-3)** **No fallback for the retry limit.** An absent, blank, unparseable, or negative `SHIPIT_OPERATOR_MAX_RETRIES` must never resolve to a permissive number. | *"An operator action that spends real credits must never be armed by a missing configuration."* Tested by AC-15b/AC-15c. |

⚠️ **[SUPERSEDED IN FULL — HD-5 `8585491a`, 2026-10-12.]** N14 stated the rule with the wrong polarity.
An absent, blank, unparseable or negative `SHIPIT_OPERATOR_MAX_RETRIES` now resolves to **uncounted**,
which is permissive — that *is* the decision, not an accident of it, and an implementer must not "fix" it
back.

**What survives from N14 is the half that was never about permissiveness:** a missing or malformed value
must never resolve to an **arbitrary number**. `3` is not the value that must not be assumed; a
**fallback constant** is. HD-5 keeps that exactly — there is no default, no fallback and no count unless
an operator configures one. The quoted rationale is **withdrawn as applied to this action**, not because
spending credits is acceptable but because the action is human-triggered; the same reasoning still governs
`SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS` and automatic retries, both of which remain bounded.

---

## 11. Acceptance criteria

Testable. **AC-1 … AC-4 are gates on the *whole* change: the screen and the dispatch seam ship
together or not at all**, because shipping the screen alone produces the silent strand of P-1. **The
sequencing rule behind that gate is stated in §16.2 and is a review blocker, not advice.**

**Numbering note — brought current at 1.4.0 (it previously recorded only 1.1.0's changes):**

| Revision | Added | Rewritten | Deleted |
|---|---|---|---|
| 1.1.0 | AC-14a–e (audit, HD-2), AC-15b–d (HD-3), AC-19b/c, AC-31 | AC-30 (the 1.0.0 "no migration" claim withdrawn) | — |
| 1.2.0 | AC-15e, AC-32, AC-33, AC-34 | AC-13, AC-25, AC-15 | — |
| **1.3.0 (HD-4)** | **AC-35** (the edge, with a negative control), **AC-36** (the dedupe-key rule) | **AC-7, AC-10, AC-15, AC-16, AC-17, AC-19, AC-19b, AC-19c** | **AC-15e, AC-32, AC-33** — all three asserted properties of the deleted branch B |
| **1.4.0** | **AC-37** (`metadataMerge` preserves the defect payload) | **AC-29** (byte-identical → review-enforced) | — |
| **HD-5 (2026-10-12)** | — | **§6.6 and §6.6.1 in full; §6.3 `notConfigured` (unset row); N14; A11's trigger; AC-15b, AC-15c, AC-15d; §8 unset variant; the §12 `SHIPIT_OPERATOR_MAX_RETRIES` risk row; the §13.1 HD-3 record; the L2 premises note** — each **marked SUPERSEDED in place, none deleted**, per `8585491a-11a9-473e-ae4f-d66a210408f3` | **Nothing.** |

Net: 41 → **45**. Every deletion is justified in place; nothing from 1.0.0 was deleted, and no
criterion has ever been weakened.

### The action set

- **AC-1** Given a work item in `agent_failed`, `actionContext` returns exactly `[retry, stop]`, in
  that order, and nothing else — asserted against `WorkItemTransitions.isLegalTransition` in a test
  that enumerates every state and fails if any non-legal action is ever offered.
- **AC-2** Given a work item in any other state, `actionContext` returns `[]` and the page renders
  today's existing right-column text unchanged.
- **AC-3** The panel offers no control that maps to `terminated`, `waiting_for_human_decision`, or
  any state the table forbids from `agent_failed`.

### The cost is visible

- **AC-4** Before any confirmation, the panel contains the strings `This will be attempt N of M.`
  and a sentence stating that trying again costs model credits. Both are text, not tooltips.
- **AC-5** Pressing "Try again" replaces the button row with a confirm strip that requires a
  non-empty reason; the submit is refused client-side *and* returns `invalidRequest` server-side if
  the reason is blank.
- **AC-6** No path reaches `retryFailedWorkItem` without an explicit confirm step.

### The transition path

- **AC-7 (REWRITTEN at 1.3.0)** `retryFailedWorkItem` performs the move only through
  `DurableWorkflowEngine.transition(to: designNotRequired, actor: ActorType.orchestrator, …)` under an
  injected `WorkflowEngine` policy object shared with the scheduler. A test asserts the actor type
  and that the guard list evaluated is `actorAllowed([orchestrator])` and **not** `agentAvailable()`
  — matching the convention of the only other edge into that state,
  `planned → designNotRequired` (`work_item_transitions.dart:28-30`).
- **AC-8** No SQL string for `work_item` or `work_item_transition` appears anywhere in the change;
  no store method other than `WorkflowStore`/`JobStore` writes either table.
- **AC-35 (NEW at 1.3.0 — HD-4's core deliverable, and Lane S's primary acceptance)** The new edge is
  **proved legal through the real engine**, not asserted in prose. A test calls
  `WorkItemTransitions.validate(from: agentFailed, to: designNotRequired, trigger: systemEvent, actor:
  <operator actor>, …)` and asserts `isValid`. It carries a **negative control**:
  `validate(from: agentExecuting, to: agentExecuting, …)` must be **invalid**, so the 1.2.0
  self-transition defect — which made branch B always-false — cannot be reintroduced silently. A third
  assertion confirms `agentFailed` now has **two** explicit outgoing edges
  (`work_item_transitions.dart:108-110` and the new entry), and that neither is a self-transition.

### Idempotency and durability

- **AC-9** Two identical `retryFailedWorkItem` calls with the same `requestId` produce **one**
  transition row, **one** job, and identical results. Asserted by counting rows.
- **AC-10 (REWRITTEN at 1.3.0)** The retry is **one** durable transaction (§6.4), so the 1.2.0
  enqueue/transition crash window no longer exists. The test instead asserts the **atomicity**:
  forcing the work-item compare-and-swap to fail leaves **zero** `operator_action` rows and the item
  still `agent_failed`; and a crash *after* commit leaves the item `design_not_required` with the
  attempt marker set, so a replay of the same `requestId` finds its own audit row and returns
  `accepted` without writing again. **[The 1.2.0 AC tested a crash *between* two writes that HD-4
  removed. Coverage is not lost: the property that mattered — a crash never leaves a half-applied
  retry — is now stronger, because there is only one write to half-apply.]
- **AC-11** A refresh mid-flight shows the item's real state and never a button for an illegal
  action: after the retry commits, `actionContext` returns `[]`.
- **AC-12** A lost response followed by a client retry with the same `requestId` returns the first
  call's result and spends nothing twice.
- **AC-13** The accepted transition row carries a non-null `reason` equal to the operator's text
  (`2b8f4c07` keeps the additive `reason` parameter **as well as** the audit row), **and** an
  `operator_action` row exists carrying `requestedBy` and `reason` as first-class columns. The
  idempotencyKey still begins `operator-retry:` — as a **replay key only**, never as authorization
  (N12; the dispatch authorisation that consumed it in §6.5.1 was deleted with the seam).
- **AC-14** `retryFailedWorkItem` with a missing/blank `reason` writes nothing at all — asserted by
  row counts before and after.

### The audit record — NEW at 1.1.0, from decision `2b8f4c07`

- **AC-14a** A successful retry writes **exactly one** `operator_action` row per operator intent, and
  a stop writes exactly one with `action = 'stop'` and `job_id` null.
- **AC-14b** **Atomicity, the decision's binding follow-up.** Forcing the work-item compare-and-swap
  to fail must leave **zero** `operator_action` rows: the audit row and the state change commit or
  roll back together. There is no code path that writes an audit row outside the transition's
  transaction, and a test asserts the absence of one.
- **AC-14c** The `operator_action` row's `transitionId` equals the `work_item_transition.transitionId`
  of the transition it authorised, and that row is the item's **latest** transition at the moment of
  dispatch.
- **AC-14d** `operator_action` is append-only: no update or delete path exists anywhere in the
  repository, asserted by a test that fails if any `UPDATE`/`DELETE` against the table is introduced.
- **AC-14e** Replaying the same `(workItemId, requestId)` collides on
  `operator_action_request_unique` and creates **no** second row, **no** second job, and **no** second
  spend. **[Reinforced at 1.3.0: the "no second job" half is now the strong claim, not a corollary.
  The job is created by the scheduler from `metadata.triageAttempt`, so a replay that re-wrote the
  same `n` would produce the same dedupe key and `enqueueIfAbsent` would return the SAME job — but the
  unique index plus step (0) mean it never gets that far.]**
### Capacity, dispatch, and the retry's own reach

- **AC-15** With the global budget full, the **scheduler's** claim of a retried job is denied: a
  `scheduler_event` with `outcome: 'capacityDenied'` is written and **no** claim row is created
  (asserted against `job_claim`). **[UNCHANGED at 1.3.0 in substance]** — but note **who** does the
  denying: at 1.2.0 this was the retry RPC; at 1.3.0 it is the ordinary tick, because the retry RPC
  no longer claims anything (§6.4, §7.1).
- **AC-15b (HD-3)** With `SHIPIT_OPERATOR_MAX_RETRIES` **unset**, `actionContext` returns
  `retryLimitResolved: false` and a non-blank `retryLimitDiagnostic` naming the variable; the server
  returns `notConfigured` from `retryFailedWorkItem`; **and the audit row count is unchanged.** No
  fallback value appears anywhere: not in the response, not in the log line.
  > ⚠️ **[SUPERSEDED — HD-5 `8585491a`, 2026-10-12.]** Inverted. With the variable unset the retry is
  > **available and uncounted**: `actionContext` does not withhold it, `retryFailedWorkItem` does not
  > return `notConfigured`, and `operator_action` gains a row **plus** a transition and a job.
  >
  > **Two halves of AC-15b survive and are kept:** (a) **the audit row is authoritative and exact** — the
  > ledger, not an in-memory counter, is what an explicit count is computed from; and (b) **no fallback
  > value appears anywhere, not in the response and not in the log line.** (b) is *more* load-bearing now
  > than it was: with no default the response must say "uncounted" truthfully rather than quietly
  > reporting a number nobody configured.
- **AC-15c (HD-3)** **"Default 3" does not mean "absent ⇒ 3".** A test boots the resolution with the
  variable absent, blank, unparseable, and `0`, and asserts the retry action is unavailable in all
  four — with `0` meaning "permanently disabled", which is a valid configuration, not a failure. Only
  an explicit `3` arms the retry.
  > ⚠️ **[SUPERSEDED — HD-5 `8585491a`, 2026-10-12.]** The **premise** survives; the **conclusion** is
  > inverted. *"Default 3" does not mean "absent ⇒ 3"* is **still exactly right** — there is no `3`, no
  > default, and no fallback constant — but nothing needs arming, so the test's assertions change: with
  > the variable absent, blank or unparseable the action is **available**; with `0` it is **unavailable**;
  > with a positive `N` it is available until `N` is reached. `0` remains a valid configuration meaning
  > *permanently disabled*, not a failure — that clause is **carried forward verbatim**.
- **AC-15d (HD-3)** With the limit unset, **"Stop this work" is still offered** (HD-1), and the panel
  shows `Starting this again is switched off on this machine. Nothing has been changed.` styled as
  information, not as an error.
  > ⚠️ **[SUPERSEDED — HD-5 `8585491a`, 2026-10-12.]** Both halves are overtaken. With the limit unset the
  > panel shows no such message because nothing is switched off. The clause's **underlying HD-1
  > guarantee survives untouched and is unchanged by HD-5**: *"Stop this work"* is always offered, because
  > an operator who cannot retry must still have both answers. That guarantee is now strictly easier to
  > satisfy, since the only states in which retry is withheld are ones an operator configured.
- **AC-16 (REWRITTEN at 1.3.0)** The retry RPC returns `outcome: 'accepted'` and the operator is told
  `Done — it will start as soon as a machine is free.` The item then reads **"Waiting to start"**
  (`design_not_required` → `PlainStatus.waitingToStart`, `plain_language.dart:102-104`) until a job is
  actually claimed, at which point it reads **"Working on it"**. **[At 1.2.0 this AC asserted the
  retry RPC itself returned `'queued'` and that the item read "Working on it" while idle — both are
  now false, and both were consequences of the deleted seam.]** Justified rewrite, not a coverage
  loss: the operator-visible promise ("it will run, without me doing anything else") is unchanged and
  is now stronger, because it is the platform's ordinary behaviour rather than a design promise.
- **AC-17 (REWRITTEN at 1.3.0 — this is Lane S's POSITIVE acceptance; see §16.3)** After an operator
  retry moves a work item to `designNotRequired`, a **real `Scheduler.tick()`** with a free capacity
  slot dispatches a job for it and the job reaches `running` — through the **ordinary**
  `_eligibleRunnableJobs` → `_dispatchOne` path, with **no change to `Scheduler._eligibleRunnableJobs`
  (enforced by review — see AC-29 — not mechanically) and no `requestOperatorDispatch` in the
  codebase**. **[At 1.2.0 this AC read "with
  `requestOperatorDispatch` never called again"; that method no longer exists.]**
- **AC-18** No code path anywhere sets `inFlight` above `cap`; the existing capacity tests continue
  to pass unmodified.
- **AC-19 (REWRITTEN at 1.3.0)** The retry RPC refuses with `alreadyRunning` when **any** non-terminal
  job exists for the work item, so a second operator action can never be layered on top of a live
  attempt. **[At 1.2.0 this AC was about `requestOperatorDispatch` refusing a job whose item had a
  non-terminal `worker_execution` — a seam guard that no longer exists.]** The concern is preserved and
  relocated to the request path, where it is cheaper to test.
- **AC-19b (REWRITTEN at 1.3.0)** **A work item is never re-dispatched without a recorded operator
  action.** Concretely: given `agentFailed`, which is **not** in `triageDefectDefinition.entryStates`
  (`triage_defect.dart:10`), no tick enqueues for it and `_eligibleRunnableJobs` drops any job for it
  (`scheduler.dart:578-581`) — so the only way out is the `agentFailed → designNotRequired` edge
  (§6.5.1), and that edge is only ever taken by an RPC that writes an `operator_action` row in the
  same transaction. **A fabricated `idempotencyKey` prefix does not satisfy this**, and neither does a
  hand-written state change. **NOT sufficient on its own to accept Lane S** — see AC-17, AC-35, AC-36
  and §16.3, which is the incompleteness this revision inherits from 1.1.0 and 1.2.0.
- **AC-19c (REWRITTEN at 1.3.0)** The audit is **per attempt, not a standing licence**: after a retry's
  execution fails and the item returns to `agentFailed`, the *first* retry's `operator_action` row
  remains on file and does **not** authorise anything — a second retry must create its **own** row,
  with its **own** `transition_id` and its **own** `attempt_number`. Asserted by counting rows and
  checking `attempt_number` values `1, 2` across two retries. **[At 1.2.0 this AC asserted that a
  non-latest `transition_id` fails a scheduler predicate; there is no such predicate. The property
  that made "latest transition, not any" correct is preserved as an audit-integrity property, which
  is what it actually always was.]**


- **AC-36 (NEW at 1.3.0 — HD-4's accepted cost, and Lane S acceptance)** The dedupe-key rule of §6.7
  holds all four properties, each asserted separately:
  1. **absent `triageAttempt` ⇒ byte-identical key** to today (`'<workItemId>:triage_defect'`) — no
     historical job is orphaned;
  2. attempt *n* ⇒ `':a' + n`, so **each retry finds its key unconsumed** and really creates a job —
     proven by running two full retry→fail→retry cycles and counting **two** `triage_defect` job rows
     for one work item;
  3. **a network retry of the same operator action mints no second job** (the `requestId` replay path);
  4. the scheduler's tick and `WorkEntryTrigger` compute the **same** key for the same item, so the
     `job_active_dedupe_unique` index arbitrates rather than duplicating.

- **AC-37 (NEW at 1.4.0 — the `metadataMerge` merge-not-replace proof)** A work item seeded with all
  eight defect-payload metadata keys (`defectId`, `defectTitle`, `defectEvidence`, `defectReporter`,
  `defectSeverity`, `defectDescription`, `defectExpectedBehavior`, `defectReproductionSteps` — the
  keys `triage_defectInstruction` reads at `triage_defect.dart:49-56`) is carried through a retry
  transition with `metadataMerge: {triageAttempt: 1}` and comes out with **all eight unchanged and
  byte-identical, plus `triageAttempt`**. The test **fails if the merge is ever changed to a
  replace**, because a replace would feed the retried triage job an empty defect payload and the job
  would classify nothing while looking healthy (§6.4.5).


### Vocabulary and honesty

- **AC-20** Every string on the panel is either a byte-identical existing string from
  `plain_language.dart` / `transition_copy.dart` / `decision_choice.dart`, or is listed verbatim in
  §5.4/§8.2/§8.2's unset-limit variant. A reviewer greps; nothing else is permitted.
- **AC-21** With **no** `reason` recorded, the panel says `The system did not record why this
  stopped.` — not an empty region and not a substituted message.
- **AC-22** The raw `work_item_transition.reason` and the job's `failureJson` appear verbatim in the
  page's existing `TechnicalDetails` disclosure.
- **AC-23** `PlainLanguage.statusFor` is unchanged for every wire value; the nine `agent_completed`
  items still read `Working on it` after this change (**that is the point** — see §14).

### Accessibility

- **AC-24** The panel's semantics node is `container: true, explicitChildNodes: true`, with the
  buttons as distinct focusable children.
- **AC-25** After the RPC resolves, a `liveRegion` announces the outcome — including
  `Starting this again is switched off on this machine` when the limit is unresolved, so the absence
  is announced rather than merely seen.
- **AC-26** Escape cancels the confirm strip and returns focus to the action row.
- **AC-27** No new colour, token, font, or component; the golden tests for the run detail screen are
  re-baselined **only** for the new panel, with the diff reviewed.
- **AC-34 (NEW at 1.2.0 per the reviewer's L3 — semantics are NOT covered by the goldens)** A3 and
  A11 introduce `Semantics(liveRegion: true)`, which has **no precedent anywhere in this codebase**,
  and AC-27's golden comparison cannot see a semantics tree at all. Three widget tests are therefore
  required, each asserting on `tester.getSemantics()` rather than on pixels:
  1. the panel's semantics node is a single container with `explicitChildNodes` and the two actions
     as **distinct** focusable children (A1/AC-24);
  2. the confirm submit button's semantics label flips with its enabled state — *"Try again. Starts a
     fresh agent run."* vs *"Add a reason first"* (A2);
  3. after the RPC resolves, the outcome string (including *"Starting this again is switched off on
     this machine"*, and *"Queued — it will start when a machine is free."*) is present in the
     semantics tree marked as a live region (A3/A11/AC-25).
  **Concession stated rather than hidden:** with no precedent, these tests assert *that the string is
  in the semantics tree as a live region*, not that a particular screen reader announces it. Platform
  announcement behaviour is unverified on this app — §15 requirements-gap 6.

### Governance

- **AC-28** `ControlPlaneService`'s class doc (`control_plane_service.dart:53-61`) and
  `WorkflowEndpoints.resolveDecision`'s doc (`workflow_endpoints.dart:101-106`) are amended to
  name the second write path. A stale "the only legal request-side transition" claim in either is a
  merge blocker.
- **AC-29 (REWRITTEN at 1.4.0 — "byte-identical" was not a testable assertion)** **NOT** enforced
  by any golden, drift check or CI gate: a source file's bytes are not runtime-observable, and the
  reviewer is right that AC-27's goldens are scoped to the run-detail panel and cannot see a Dart
  source file at all. The property is real and is **enforced by review plus one behavioural test**:
  (i) §16.2's Lane S box marks `RunnableWorkEvaluator` ⛔ UNTOUCHED, so any edit to it is visible in
  the diff that review reads; (ii) **AC-17's live tick** proves behaviourally that dispatch still
  flows through the ordinary `_eligibleRunnableJobs` → `_dispatchOne` path, which it could not if
  the evaluator had been changed. **Stated honestly: this is review-enforced, not mechanically
  enforced.** An implementation lane wanting it mechanical must add a `git diff --exit-code` check
  over **five named symbols across TWO files** — `RunnableWorkEvaluator` in `runnable_work.dart`,
  and `Scheduler.tick` / `_eligibleRunnableJobs` / `_dispatchOne` / `_claim` in `scheduler.dart` —
  **[CORRECTED at 1.5.0 — L-D: 1.4.0 said “five named files”, which was wrong: five SYMBOLS in two
  FILES]** in its own pipeline; that is a repository-workflow change and is therefore **not**
  asserted here as if it existed.
- **AC-30 (REWRITTEN at 1.1.0 — the 1.0.0 "no migration" claim is withdrawn by decision
  `2b8f4c07`)** There is **exactly one** migration, and it creates **exactly one** table,
  `operator_action`. It changes **no** existing table. `serverpod generate` output is committed as
  generated — no hand-edited generated file.
- **AC-31** `apps/server/tool/verify_schema_bootstrap.sh` passes after the migration, and
  `apps/server/tool/schema_bootstrap.dart` passes against the test database. The brief's assessment
  is that `tool/schema_bootstrap.sql` needs **no** change (it contains no `CREATE TABLE`, only two
  partial/expression unique indexes and two trigger functions); **the implementer verifies this rather
  than trusting it**, and if the generator does emit something the bootstrap file must also carry, the
  bootstrap file is updated in the same change and the divergence check stays green.

---

## 12. Risks

`risk_level: 3` — **Major Workflow / Navigation / IA Change**. **Re-confirmed at 1.1.0**: HD-2 added a
migration and a new table, which is a reason to consider *raising* the level, and none to lower it —
the level was 3 because of what the change *does*, and the closeout did not change what it does.

Supporting it:

- **It changes what runs autonomously, under a human's hand.** Every other operator decision in this
  system resolves a *gate*; this one **starts a real agent execution that spends real model credits**.
  There is no precedent in the request path for spending money.
- **It changes the agent's mental model.** "Work failed and will not retry" becomes "work failed and
  a human restarts it". That is a change to how every operator reads every failed item.
- **It adds a second request-side state transition** and therefore a second way for the workflow
  engine to be driven from outside — the exact surface area that constraint 4 exists to protect.
- **It requires a change to `packages/scheduler`'s dispatch eligibility**, which is shared
  infrastructure on the live dispatch path, and a change to `DurableWorkflowEngine`'s signature.
- **NEW at 1.1.0 — it changes shared infrastructure twice over.** HD-2 adds a method to the
  `WorkflowStore` interface (**8 implementors** — 3 production, 5 test doubles; corrected at 1.2.0 per
  the reviewer's M2, 1.1.0 said 11 and wrongly counted the contract suite as an implementor) and a
  migration on the chain-migrated path. Both are additive, and both touch code every other lane
  depends on.
- **Level 3 ⇒ `HUMAN_DECISION_REQUIRED`.** HD-1, HD-2 and HD-3 (§13.1) landed at that gate and are
  now RESOLVED, so the risk level and the escalations were one fact seen twice and that fact has been
  discharged.

**Level 2 was considered and rejected:** *"Change to user flow, interaction pattern, or feature-level
UX"* fits the *panel*, but it does not fit "a new capability to spend credits and start autonomous
work", which is the substance. **Level 1 and 0 are excluded** — neither is "an inconsistency with
the established design system"; this adds a surface the design system has no answer for.

**A reviewer may reasonably land on Level 2** if they read the scheduler seam as an implementation
detail rather than part of the design. That disagreement is invited and the closeout does not depend
on it: the three decisions are RESOLVED (§13.1), so if Level 2 is chosen **nothing in the plan
changes** except which gate it passed through. HD-2's added weight — a migration and a new
`WorkflowStore` method — is an argument for the level being read at the *top* of its band, not below
it.

### Key implementation risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| The §6.5 eligibility rule is widened by a later change into a general `agentExecuting` re-dispatch | Medium | The rule is a named predicate with all conjuncts listed in the brief and in the code's doc comment; the `operator_action` authorisation conjunct is the one that must never be relaxed. AC-19b and AC-19c are the tests that catch it. |
| ~~The `operator-retry:` key prefix becomes load-bearing as authorisation~~ | ~~Medium~~ | **RESOLVED by HD-2 — this risk no longer exists.** The prefix is withdrawn as authorization (§6.5.1) and survives only as a replay key, where a mistake costs a duplicate no-op rather than an unauthorised spend. |
| **NEW at 1.3.0 — the attempt suffix in `triageDefectDedupeKey` is "tidied" away** because it looks like an edge case, reintroducing the silent no-op (D-4) | Medium | AC-36 asserts all four properties **separately**, and property 1 (absent ⇒ byte-identical key) is asserted as a *non-regression* against the historical format. A change to that builder must not pass review on a rationale that does not name both halves. |
| **NEW at 1.3.0 — the new edge is added WITHOUT the negative control**, and a later change reintroduces a self-transition somewhere else | Low–Medium | AC-35 mandates the negative control `(agentExecuting, agentExecuting) is invalid`, which is cheap and is the exact assertion whose absence let the 1.2.0 defect through review. |
| **NEW — the migration diverges between the fresh path and the chain path** | Low–Medium | `tool/schema_bootstrap.sql` holds no `CREATE TABLE`, so it should need no edit (verified, not assumed); `verify_schema_bootstrap.sh` and `schema_bootstrap.dart` are required gates (AC-31). The `operator_action` indexes are plain btree and renderable by the model generator — deliberately chosen so this is cheap. |
| **NEW — a retry authorisation survives a second failure and re-arms the old job** | Low | AC-19c. The `transition_id == latest transition` conjunct is what prevents it; this is precisely the case that made "latest transition" rather than "any transition" the right formulation. |
| A retry storm: N operators press retry on N items simultaneously | Low | The advisory lock is per-claim and already arbitrates (`job_capacity_guard.dart:92-186`); `enqueueIfAbsent` arbitrates per dedupe key; `operator_action_request_unique` arbitrates per intent; §6.6 bounds per item. |

⚠️ **[PARTLY SUPERSEDED — HD-5 `8585491a`, 2026-10-12.]** This row's last clause, *"§6.6 bounds per
item"*, is **no longer true**: §6.6 bounds per item only when an operator configures a cap, and bounds it
by nothing at all by default. The three arbitration mechanisms it names are unaffected and still hold —
what HD-5 removes is the **spend** bound, not the **concurrency** arbitration. An operator can now press
retry repeatedly on one item, and the capacity guard (`SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS`, still
fail-closed) plus each job's own `maxAttempts` are what bound the resulting work.
| The confirm strip's mandatory reason annoys operators | Medium | It matches the existing decision screen's behaviour exactly (`:461`). Consistency is the argument; if it is rejected, reject it for the decision screen too. |
| The panel's classifier mislabels a cause | Low | It can only be *less specific*, never wrong: unrecognised input yields a neutral sentence plus the raw record (AC-21, AC-22). |
| `SHIPIT_OPERATOR_MAX_RETRIES` unset ⇒ the button never appears | **High, by design** | Confirmed deliberate by HD-3. Now **visible** rather than silent (§6.6.1, AC-15b/AC-15d), with the QA pre-condition recorded so the correct behaviour is not mistaken for a broken screen. |

⚠️ **[SUPERSEDED IN FULL — HD-5 `8585491a`, 2026-10-12.]** The behaviour this row rates as **High** is
**no longer the behaviour**. With the variable unset the button **does** appear, and the retry proceeds.
The row is retained because it is the honest record of the risk HD-3 accepted.

**The risk itself did not vanish; it changed owner.** What remains is that an operator may press retry
repeatedly and spend repeatedly, with no running total in the UI unless a cap is configured. HD-5 prices
that and accepts it — the actor is a human behind an authenticated operator session whose only caller is
the operator UI, not an agent. The mitigation HD-3 relied on (the button being absent) is **no longer the
mitigation**, so the residual-risk statement in `8585491a` becomes load-bearing: `requestedBy` is a
**client-supplied string**, not a cryptographic identity claim. If a non-UI caller ever appears, reopen the
decision — do not respond by raising the cap.

---

## 13. Decision record

### 13.1 The three escalated questions — RESOLVED

Each is closed with the decision's own words. **None is reopened here.**

#### HD-1 → `INCLUDE_STOP` — `7c1e9a44-3b62-4d18-9f05-2a7c6e14d903` (PRODUCT, RESOLVED)

> *"Without an abandon action the panel is coercive — one available button, and pressing it spends
> real model credits. A human who declines to spend has exactly one remaining exit: a database client.
> That is the same failure class as the `agentFailed` vs `agent_failed` incident, where a hand-written
> SQL mutation bypassed the transition table and broke every scheduler tick. A product that routes a
> decision to a human must give that human both answers. `terminated` is deliberately NOT offered: same
> effect as `cancelled` but not a word an operator can act on."*

**My recommendation at 1.0.0 was option (A) and the human adopted it.** §5.2 and §5.3 stand unchanged.
Nothing in the panel needed re-deriving. The decision's follow-up action — *"Implement the `stop`
action against the generic escape edge only. Never synthesise a transition that
`work_item_transitions.dart` does not already permit"* — is binding on the implementation lane and is
§10 N2/N4 restated by the human. **Blocks nothing. Closed.**

#### HD-2 → `AUDIT_TABLE_SAME_TX` — `2b8f4c07-6d51-4a93-8e17-93c5b0a2f6d4` (ARCHITECTURE, RESOLVED)

> *"Authorization-by-string-convention is not authorization. Encoding dispatch authority in an
> `idempotencyKey` prefix means permission is a predicate matching a naming convention that any future
> caller could satisfy by formatting a string correctly; it is greppable but not enforced. Adding
> columns to `work_item` loses history — repeated retries overwrite the previous actor, which defeats
> the purpose of an audit trail for a spend-arming action. A dedicated audit row written inside the
> transaction DurableWorkflowEngine already opens is atomic with the state change (so the audit and the
> transition cannot diverge), keeps every retry in history, and makes authorization a real recorded fact
> rather than a convention. A migration is a fair price for an action that spends money."*

**This is the decision that overturned my own proposal, and I want it recorded plainly rather than
buried:** at 1.0.0 I recommended the transition `reason` column alone, called it *"the minimal durable
change"*, and — after §17 — named it *"the most contestable decision in this document"* because I had
authorised a spend-arming action with a **string prefix**. The human read it, rejected the prefix
outright, and paid for a real audit record. **They were right, and the reasoning is one I should have
weighted more heavily at 1.0.0:** I optimised for "atomic, greppable, no migration" and under-weighted
that *a permission enforced by a naming convention is not a permission*.

What changed as a result:

| At 1.0.0 | At 1.1.0 |
|---|---|
| Authorisation = `idempotencyKey` prefix | **Withdrawn.** §6.5.1 authorises on an `operator_action` row. |
| Operator identity = nowhere durable | **`operator_action.requested_by`, a first-class column.** |
| No schema change | **One migration, one new table** (AC-30). |
| `reason` parameter proposed as *sufficient* | `reason` parameter **confirmed and kept**, alongside the audit row, exactly as the decision directed. |
| Retry count from accepted transitions | Retry count from `operator_action` rows (`operator_action_retry_idx`). |

Sections rewritten: §6.4 (algorithm step 4), §6.4.2 (confirmed, plus a withdrawal note), **§6.4.3
(new — the audit table, its atomicity, and its real cost)**, §6.4.4 (new — the 8 implementors and
the migration), §6.5.1 (new — the restated authorisation conjunct), §6.2 (wire models), §11
(AC-13, AC-14a–e, AC-15b–d, AC-19b/c, AC-30, AC-31), §12. **Closed.**

#### HD-3 → `THREE_PER_ITEM_FAIL_CLOSED` — `5d9a1f62-8b37-4e50-a9c4-71f2d8b3e605` (POLICY, RESOLVED)

> ⚠️ **[SUPERSEDED IN FULL — HD-5 `8585491a-11a9-473e-ae4f-d66a210408f3`, 2026-10-12.]** Everything in
> this subsection is **retained as history and is not current instruction.** HD-3 is superseded in full.
> Its object carries a matching `## SUPERSEDED IN FULL` block, and its own text above is unedited — the
> decision trail reads in order.
>
> **One claim below must not survive into implementation:** that HD-3 is *closed and final*. It was
> closed, and the human has since reopened and reversed it. **HD-3's rejection of a per-operator-per-day
> cap is the one substantive judgment that survives** — that reasoning still governs the explicit-cap
> case, which HD-5 keeps. Its fail-closed default does not survive.

> *"Three permits enough genuine retries to work through a transient failure while still bounding the
> worst case. The cap is counted per work item, not per operator per day, because a per-operator-per-day
> cap is trivially reset and does not bound a single pathological item. Fail-closed is the deliberate
> choice and mirrors the capacity guard: if SHIPIT_OPERATOR_MAX_RETRIES is unset the retry action is not
> offered at all, rather than defaulting to a permissive value. An operator action that spends real
> credits must never be armed by a missing configuration."*

**The human rejected my proposed alternative shape** (I had raised per-operator-per-day alongside
per-item) and kept the per-item bound. The fail-closed mechanism is confirmed.

**One phrase in the decision needs disambiguating in the brief rather than in the code**, and the
brief states it three times so an implementer cannot misread it (§6.6 bullet 2, AC-15b, AC-15c):

> *"default 3 per work item"* **and** *"if the limit is unset the retry action is never offered"* are
> both true only under one reading: **3 is the value operators must configure; there is no fallback
> constant in the code.** An implementer who reads "default 3" as "absent ⇒ 3" would invert the
> decision and re-arm a credit-spending action from a missing configuration — the exact failure the
> decision exists to prevent. `0` remains a valid configuration meaning *permanently disabled*.

The decision's binding follow-up — *"The unset-means-unavailable behaviour must be visible in the design
and in the acceptance criteria, not treated as an incidental detail"* — is discharged by **§6.6.1**
(server diagnostic, panel copy, startup log), **AC-15b/AC-15c/AC-15d**, and **AC-25** (the absence is
announced on a live region, not merely seen). The QA pre-condition is recorded in §6.6.1. **Closed.**

#### HD-4 → `DESIGN_NOT_REQUIRED` — `8a3f6b17-92d4-4e08-b6c1-8f0d5b27a934` (ARCHITECTURE, RESOLVED)

> *"Retry returns the item to a state the scheduler ALREADY knows how to dispatch, rather than
> teaching the scheduler a second way to dispatch. `designNotRequired` is a triage entry state
> (`triage_defect.dart:10`) and `designNotRequired → agentExecuting` is already an exercised edge
> (live transition `tr-hn3lio9ndj-1hjznv6`), so the entire existing dispatch path applies unchanged.
> This deletes the eligibility branch rather than re-specifying it — which is the only reliable answer
> to a control-flow specification that produced dead code three times, and it is the lesson the design
> agent's own D-6 discovery recorded. It also matches the semantics honestly: a failed agent run leaves
> nothing to resume, so re-planning the item is the truthful operation, not a fiction of continuation.
> The cost is real and accepted: one new workflow-engine edge, and a fresh dedupe key per retry because
> `enqueueIfAbsent` cannot reuse a terminal dedupe key."*

**This decision overturned my design twice over, and the record should say so plainly.**

| | At 1.0.0–1.2.0 | At 1.3.0 (HD-4) |
|---|---|---|
| Retry target | `agentExecuting` | **`designNotRequired`** |
| Scheduler | a new eligibility seam (three failed specifications) | **untouched** |
| Retry RPC | enqueue + dispatch, 2+ durable writes | **one durable write**, returns `accepted` |
| Crash analysis | "enqueue first so a crash stays honest" | **one transaction; no window** |
| Dedupe key | `:retry-<requestId>`, computed by the RPC | `':a' + n` from durable `metadata.triageAttempt`, computed by the scheduler |
| Capacity denial | a retry-time outcome to design | **the scheduler's ordinary, already-tested behaviour** |
| Label while waiting | falsely *"Working on it"* — hand-waved at 1.0.0 §7.1 | **truthfully** *"Waiting to start"* |

**Why the human was right and I was wrong, stated without hedging.** `agentExecuting` means *"an
execution is already running."* Moving a failed item into it **asserts something untrue**, and the
scheduler correctly refuses to dispatch an item that claims to already be executing. My 1.2.0
"fix" made that refusal explicit — and then failed to notice that the refusal was *right*. I treated
the drop as a bug in the gate rather than a true statement about the state. **Three specifications
failed because I kept trying to make the scheduler agree with a target state, instead of asking
whether the target state was the right one.** D-6 recorded exactly that lesson before HD-4 was
raised, and is now a durable discovery in its own right.

**What HD-4 explicitly accepts as cost, and this brief specifies:** one new workflow-engine edge
(§6.5.1, AC-35) and a fresh dedupe key per retry (§6.7, AC-36). Both are covered.

**Binding follow-up actions from the decision, all discharged here:**
- *"DELETE the §6.5.2 scheduler eligibility seam in its entirety"* → done; §6.5 replaced, §6.5.2 gone
  (grep evidence in §17.1).
- *"Add the edge … with its guard, and prove it with a test through the real engine"* → §6.5.1 + **AC-35**.
- *"Every retry must use a fresh dedupe key"* → §6.7 + **AC-36**.
- *"Re-run the design review after the seam is deleted"* → this revision; §16.2 restated.

**Nothing else is reopened.** §5 (action set), §6.4.1–6.4.4 (actor, reason, audit table, cost),
§8 (panel), §9 (accessibility), and HD-1/HD-2/HD-3 are unchanged.

### 13.2 The one question the closeout genuinely opened (OQ-1)

Everything above is closed. One thing is new, and it is a **consequence of HD-2**, not a re-opening of
it.

#### OQ-1 — Should the panel show *who* restarted the work, now that the audit table knows?

`operator_action.requested_by` is the first place in this repository where the **human's** identity is
recorded for a workflow action. `work_item_transition.actorId` deliberately holds the *path*
(`operator-retry`), not the person (P-4). So the audit row knows something the screen currently cannot
show — and an audit that no operator-facing surface ever reads is only half of what the decision bought.

**Options:** (A) surface it in the existing panel — a `priorActions` list on
`WorkItemActionContextView` (already added in §6.2) rendering *"Started again by <name> on <date> — <reason>"*,
reusing `PlainLanguage.timeOfDay` and the existing `DefinitionList`; (B) leave the audit for engineers
and show nothing.

**Recommendation: (A)**, and I am authorised to say so: it serves constraint 2 (the cost is the
operator's decision to make, so the operator should see who made the previous one), it reuses two
existing components, and it is the difference between an audit table and a cost screen.

**Why it is not blocking.** It changes copy and one read, not structure: the retry path, the RPC
shape, the seam, and the audit semantics are identical under (A) and (B). If the human prefers (B),
it is a one-line revert of `priorActions` and nothing else. **It should not hold the seam.**

**Not escalated as a Human Decision.** It is a presentation choice with a clear default, inside this
design's authority, and I have given the answer. It is recorded here so a reviewer sees it was
considered rather than missed.

**HD-4's effect on OQ-1: none.** The audit row still records `requested_by`, so the question still
arises on the same terms. `priorActions` is already in the wire model (§6.2).

### 13.3 Deliberately NOT re-raised

For the avoidance of doubt, these were answered and are **not** reopened: the single-confirm-strip
shape for `stop` (HD-1's option set had no typed confirmation); per-item rather than
per-operator-per-day counting (HD-3); and the audit home — `operator_action`, not `HumanDirection`,
not `work_item` columns (HD-2).

---

### 13.4 D-6 — the durable discovery that predicted this, now persisted

**At 1.2.0 this brief reported, in its structured result, a `WORKFLOW_IMPROVEMENT` finding with no
durable ID anywhere in the artifacts.** The reviewer was right that it "does not exist as an ID" —
`discovery_handed_to_manager` held D-1…D-5 only. It is now a real, persisted discovery.

> **`LEARNING_POLICY` category: `WORKFLOW_IMPROVEMENT`**
> **D-6 — A design brief that appends a conjunct to an existing eligibility predicate should be
> treated as suspect until its exact line numbers are re-read.** `RunnableWorkEvaluator` and
> `Scheduler._eligibleRunnableJobs` are described in prose as *"the scheduler drops jobs whose work
> item is not runnable"* — which is true, and which is exactly the kind of true-but-incomplete summary
> that hides a `continue` sitting between the two places an implementer would add a check. Two
> concrete consequences, both of which occurred:
> 1. A prose summary of a control flow is not a specification of it. The predicate's `continue`s are
>    invisible in the summary and decisive in the code.
> 2. When a specification of a control flow fails **twice**, the correct inference is that the design
>    is wrong, not that the third formulation is. Stop and ask whether the *target state* is
>    correct — here, `agentExecuting` means "an execution is already running", and moving a failed item
>    into it asserts something untrue.
>
> **This discovery predicted the exact failure mode that then occurred** (the 1.2.0 self-transition,
> always-false branch), and the human's HD-4 rationale cites it. **Authority: independent review** —
> it concerns the reusable design/review process, not this product, so it is **not persisted by this
> lane** into any framework knowledge file; it is raised here for the Manager to route.

### 13.5 What HD-4 did NOT change

Explicit, because a fourth decision could invite re-opening work the reviewer confirmed sound:

| Kept as-is | Because |
|---|---|
| §5 the action set, and HD-1's `INCLUDE_STOP` | reviewer confirmed correct against the real table; HD-4 changes the *target state*, not which edges exist |
| §6.4.2–§6.4.4 — `reason` parameter, `operator_action` table, its cost | HD-2 unchanged; the audit row is still the authorisation record. **§6.4.1 was NOT verified-unchanged** — its 1.3.0 claim that work-item metadata is untouched was false (H2) and is corrected at 1.4.0. **§6.4.5 (`metadataMerge`) is NEW at 1.3.0**, not part of HD-2. |
| §8 the panel, all UX copy | reviewer confirmed |
| §9 accessibility, incl. AC-34 | reviewer confirmed; A11's unset-limit announcement is still required |
| P-1 … P-6 | reviewer confirmed all six verify against source. **P-1's gates G1–G4 are all still true** — a retried item IS re-dispatchable, now because it arrives at a runnable state rather than in spite of the gates |
| AC-30 | reviewer confirmed. **AC-29 was NOT verified-unchanged**: its "byte-identical" phrasing was not a testable assertion (H3) and is restated as review-enforced at 1.4.0. |
| risk level 3 | unchanged |


## 14. Non-goals and follow-ups

### Non-goals for this screen (stated so they are not smuggled in)

| # | Not doing | Why |
|---|---|---|
| G1 | Fixing the nine parked `agent_completed` items | See §14.1. A separate defect. |
| G2 | Changing `PlainLanguage.statusFor` | P-6. The labelling defect is shared with G1. |
| G3 | Changing `RunnableWorkEvaluator` or any `entryStates` | N6. |
| G4 | Any change to the zombie reclaim, the timeout, or the liveness probe | They worked; the evidence shows the reclaim *worked* (`tr-step3-9859703`). |
| G5 | **Any migration or schema change beyond the single `operator_action` migration that decision `2b8f4c07` requires** | **[CORRECTED at 1.2.0 — this row said "None is needed" at 1.0.0/1.1.0 and was a surviving 1.0.0 fragment, found by the review's full-brief sweep.]** HD-2 accepts one migration and one new table; every other schema change remains a non-goal. |
| G6 | Re-deciding that `agentFailed` is excluded from auto-dispatch | Correct as-is. |
| G7 | A "retry all failed" bulk action | One item, one human, one confirmation. |
| G8 | A retry-rate or cost dashboard | The Models section already carries cost (`model_stats_page.dart`); this screen needs one number. |
| G9 | Changing `WorkEntryTrigger`'s behaviour | §14.2. |
| G10 | Anything about `WAITING FOR YOU` on the Overview | The Overview counts are correct per `home_endpoints.dart`; the *semantics* are the defect (G1/G2). |

### 14.1 Follow-up (separate work item, NOT solved here) — the nine parked items

> **`LEARNING_POLICY` category: `DESIGN_DISCOVERY`** — a finding affecting UI/design and the Design
> Contract. Authority: independent review; **NOT persisted by this lane** (design-only, and the fix is
> a product/brief decision, not a knowledge-file edit). Tagged at 1.2.0 per the review's L4.

Verified live: nine work items sit at `agent_completed`, and `home_endpoints.dart:28-33` counts
`!state.isTerminal && blockingHumanDecisionId == null` as running. `agentCompleted` is **not**
terminal (`workflow_state.dart:36-39`) and `plain_language.dart:110` maps it to `workingOnIt`. With
the twelfth item in `agent_failed` also non-terminal and unblocked, the Overview's `WORKING ON IT`
metric reads **12**.

This is a **stale-state and labelling defect**, not a missing-screen defect:

- `RunnableWorkEvaluator` gives `agentCompleted` `noAction` for the triage definition, and the only
  non-terminal edge out of it is `agentCompleted -> reviewInProgress`, guarded by
  `agentResultValid()` — an independent-review lane that does not run for triage. So these items are
  parked by design and will stay parked.
- "Nothing moves forward until you decide. There is no time pressure" is the product's promise; an
  item that can never move is the quiet screen the doctrine forbids, and it is the **same
  doctrine** this brief is serving.
- **Conflating the two would fix a symptom and hide a cause.** This screen must not "solve" it by
  offering a retry for `agent_completed` — no such edge exists from there either
  (`work_item_transitions.dart:112-115` has no `agentCompleted -> agentExecuting`), and inventing one
  would be a real workflow change with its own governance.

**Recommended follow-up, one item, its own brief:** decide whether triage's terminal outcome should
be `completed` rather than `agent_completed` for a defect-triage work item (the triage lane's output
is a `TriageResult`, not an implementation awaiting review), and correct the counting predicate. It
touches the same vocabulary this brief reuses, which is exactly why it must be a separate item
rather than a line added here.

### 14.2 Follow-up (small, separate) — `enqueueIfAbsent` reports a stale terminal key as a race

> **`LEARNING_POLICY` category: `PROJECT_FACT`** — a stable, verified fact about this repository
> (`postgres_job_store.dart:246-256` has no state filter). Authority: automatic; **NOT persisted by
> this lane**, because the fix belongs to another lane's reviewed surface. Tagged at 1.2.0 per the
> review's L4.

`JobQueue.enqueueIfAbsent` maps "a job already exists under this key" to
`WorkEntrySkipped('TRIAGE_ALREADY_ACTIVE', 'a concurrent caller won this dedupe key; job … is the
one that exists')` (`work_entry.dart`, `design-work-entry` §11.1). When the existing job is
**terminal** — as it is for `defect-DEF-1791686704991884` — no concurrent caller won anything, and
the message is false. `findLatestByDedupeKey` cannot distinguish the two cases today
(`postgres_job_store.dart:246-256`).

This brief routes around it (§6.7) rather than fixing it, because the work-entry sweep's behaviour
is another lane's reviewed surface. It should be reported as its own small fix: the skip code
should distinguish `ACTIVE_JOB_EXISTS` from `TERMINAL_JOB_WITH_SAME_KEY`.

---

## 15. Traceability

### Requirements covered

| Requirement | Where |
|---|---|
| Design Brief in the repo's format and location | this file + `design-brief-metadata.yaml` + `prompt.md`, under `docs/engineering/dispatch/tasks/design-failed-work-retry/`, following `design-work-entry` |
| Problem statement with verified evidence | §1, with live read-only rows and file:line citations |
| Scope | §3, §4 |
| Action set mapped to the real transition table, with file:line citations | §5.1 (the complete edge set), §5.2 (chosen set) |
| Whether "abandon" is wanted or scope creep, justified | §5.3 — decided **yes**, argued both ways |
| Layout/interaction of the action panel | §8.1–8.5 |
| What it shows about WHY it failed | §5.6, §8.2 |
| How the human confirms a retry that spends credits | §8.3, AC-4/AC-5/AC-6 |
| RPC name and shape, specified as new surface | §6.0–6.3, §6.5 |
| Error and capacity-denied behaviour | §6.3 outcomes table, §7 |
| Accessibility and design-system conventions | §9, §8.2 (tokens named), AC-24…AC-27 |
| What the screen must NOT do | §10, N1–N14 |
| The "9 parked items" problem as a follow-up only | §14.1 |
| Constraint 1 (transition table is the authority) | §5.1, §6.1 step (1), N4, N5, AC-1/AC-3 |
| Constraint 2 (credit cost visible before committing) | §8.2, §8.3, AC-4, N3 |
| Constraint 3 (capacity guard + zombie/timeout respected) | §6.5, §6.5.1, §7.1, §7.2, AC-15…AC-19c, N1 |
| Constraint 4 (no raw SQL / hand-written state) | §6.1 step (4), AC-7, AC-8, N2 |
| Constraint 5 (durability/idempotency) | §6.3, §6.4, §6.4.3, §6.7, §8.3 requestId lifecycle, AC-9…AC-14e |
| Constraint 6 (plain language, existing vocabulary) | §5.4, §5.5, §5.6, §8.2 (+ unset variant), AC-20…AC-23 |
| OWNED_PATHS / READ_ONLY_PATHS declared | §0 |
| No production source modified | §0; `git status` unchanged outside `OWNED_PATHS` |
| Zero mutating Docker/Compose; live DB untouched | §0, §16 |
| Risk level 0–3 with rationale | §12 (`3`, re-confirmed at 1.1.0, re-confirmed again at 1.2.0) |
| **Human decisions routed and resolved** | **§13.1** — HD-1 `7c1e9a44` → `INCLUDE_STOP`; HD-2 `2b8f4c07` → `AUDIT_TABLE_SAME_TX`; HD-3 `5d9a1f62` → `THREE_PER_ITEM_FAIL_CLOSED`. 3 routed, **3 resolved, 0 open.** |
| **Decision follow-ups discharged** | `2b8f4c07` same-transaction atomicity → §6.4.3 + AC-14b; additive `reason` parameter → §6.4.2 (confirmed, not provisional). `5d9a1f62` visibility obligation → §6.6.1 + AC-15b/AC-15c/AC-15d + AC-25 + QA pre-condition. `7c1e9a44` generic-escape-only → §10 N2/N4, AC-3. |

⚠️ **[SUPERSEDED IN PART — HD-5 `8585491a`, 2026-10-12.]** The two rows above are **accurate as of
2026-10-11** and are retained unchanged as the ledger of that revision. Two updates a reader must have:

- **HD-3 is SUPERSEDED in full.** Its "visibility obligation" was discharged by the clauses listed in the
  §6.6 banner and is **now discharged by removal** — there is nothing to make visible when unset.
- **The ledger already omitted HD-4** (`8a3f6b17`), which is documented at 1.3.0/1.4.0 and is unaffected
  by HD-5. That omission is pre-existing and is **not** corrected here; correcting it would edit a
  revision record this lane does not own.
- **HD-5 is now routed and resolved:** `8585491a-11a9-473e-ae4f-d66a210408f3` (POLICY, RESOLVED) →
  `UNCOUNTED_OPERATOR_BOUNDED_AUTOMATIC`, superseding `5d9a1f62` in full.
| **Required implementation sequencing** | **§16.2** — seam first (or atomic with), then screen. **§16.3** — why a negative-only lane contract cannot discharge it. |
| **Constraint 3 "a queued alternative, NOT a button that silently does nothing"** | §7.1 item 5, AC-17, and **§6.5.2** — the alternative branch that makes a later tick actually retry a capacity-denied job. This was the constraint the reviewer's B1 found unmeetable at 1.1.0. |

### Requirements gaps

1. **~~HD-1, HD-2, HD-3 are unanswered.~~ — CLOSED at 1.1.0.** All three are RESOLVED (§13.1). This
   gap is discharged, not carried.
2. **The §6.5 engine edge still has no implementation lane assigned.** The brief specifies the edge at
   contract level with its guard, its legality proof and its test obligations; splitting it into its own
   lane with its own review is the Manager's call. **It remains a prerequisite for the screen, and §16.2
   states the sequencing explicitly and prominently.** **[CORRECTED at 1.5.0 — L-C: 1.4.0 left this parent
   line reading “§6.5’s seam … with its full predicate”. §6.5 has had no seam and no predicate since HD-4
   deleted the eligibility branch at 1.3.0. The sub-bullets beneath it had been updated; this parent
   had not.]**
   - **[DECLARED INCOMPLETENESS — first raised at 1.2.0 (reviewer B2), updated at 1.3.0 and 1.4.0.]**
     At 1.1.0 this gap's lane contract assigned Lane S only the **negative** tests AC-19b/AC-19c.
     **A negative-only lane contract cannot distinguish a working capability from a dead one**: an
     implemented eligibility branch and a completely inert one both satisfy "never dispatches without
     an `operator_action` row". That was not hypothetical — it is precisely how revision 1.1.0's rule
     was specified (B1), and it would have passed its own acceptance.
     - **Corrected at 1.2.0** by adding AC-15e and AC-17 (positive) plus AC-32/AC-33.
     - **Corrected at 1.3.0 (HD-4)**: AC-15e, AC-32 and AC-33 were **deleted** with branch B, and the
       current Lane S acceptance is **AC-35** (the edge is legal through the real engine, with a
       negative control), **AC-36** (the four dedupe-key properties), **AC-37** (the
       merge-not-replace proof — **added at 1.5.0**; until then the mechanism had no acceptance
       gate), **AC-17** (a retried item is dispatched by a normal tick), **AC-14a–e** (the audit
       record) and **AC-10** (one-transaction atomicity), with **AC-19b, AC-19c, AC-29, AC-7** as
       negatives.
     - **Extended at 1.4.0**: the review found HD-4's retarget had reached the core but not the
       periphery, and the peripheral sites are exactly the ones a reviewer reads to judge whether a
       lane's work is complete. §15 is the place that failure is now recorded, so the next reviewer
       does not have to rediscover it.
     **The incompleteness was real, recurred three times, and is recorded here rather than left
     implicit.**
3. **No golden-baseline impact has been measured.** AC-27 requires re-baselining the run detail
   golden images; the diff has not been produced, because producing it would require implementing.
4. ~~The exact `SHIPIT_OPERATOR_MAX_RETRIES` value is unknown.~~ — **CLOSED: 3**, per `5d9a1f62`. What
   remains is an *operational* obligation, not a design gap: every stack must actually set it
   (§6.6.1 QA pre-condition), which sits outside this lane's `OWNED_PATHS`.
   > ⚠️ **[SUPERSEDED — HD-5 `8585491a`, 2026-10-12.]** *"CLOSED: 3"* is **no longer the answer**: there is
   > no default value, and the operational obligation to set one is **discharged by removal**. This item
   > is better described as *closed by the reverse decision* — the question "what value?" was answered by
   > removing the question. The QA stack in particular must set nothing.
5. **NEW at 1.1.0 — `schema_bootstrap.sql` is assessed as needing no edit, but not verified.** §6.4.4
   records why (restated on the correct grounds at 1.2.0 — see L1 there), and AC-31 makes the
   implementer verify rather than trust it. If the generator emits something the bootstrap file must
   also carry, the bootstrap file is updated in the same change.
6. **NEW at 1.2.0 — `Semantics(liveRegion: true)` has no precedent in this codebase.** A3 and A11
   introduce it. It is specified, and L3 at 1.2.0 adds explicit semantic tests (AC-34), but no existing
   golden or widget test in this app exercises a live region, so its behaviour on this platform is
   an assumption rather than a verified property. **A reviewer should treat the first implementation as
   the first evidence.**

---

## 16. Provenance

### 16.1 Ledger

| | |
|---|---|
| Repository | `/Users/alkebut/air/shipit-platform` |
| Branch | `main` (design-only; no branch created, nothing committed, nothing pushed) |
| `base_sha` | `4dc9c5e4e2dfe043132e048234cd4bb4dee96d65` |
| `head_sha` | `4dc9c5e4e2dfe043132e048234cd4bb4dee96d65` |
| Brief version | **1.1.0** (closeout; was 1.0.0) |
| Files modified outside `OWNED_PATHS` | **0** |
| `.decisions/**` modified | **0** — all three read only; they were already RESOLVED and needed no correction |
| Mutating Docker/Compose commands issued | **0** |
| Live database writes | **0** — read-only `SELECT` only, against the live QA Postgres, via `docker exec … psql -c "SELECT …"` |
| Live database reads this revision | **0** — the closeout is a paper exercise over `.decisions/**` and source already read |
| Human decisions | **3 routed, 3 resolved, 0 open** |

`git status` shows pre-existing modifications to `apps/control_plane/test/failures/*.png`,
`docker/compose.qa.yaml` and `melos_shipit_platform.iml`, plus pre-existing untracked files at the
repository root (`*.sql`, `*.png`, `cloudbuild.release.yaml.archive`, `design-execution-limits/`) —
**all present before this lane began** and untouched by it. The three `.decisions/*.yaml` files are the
Manager's, untracked, and also untouched here. This is recorded rather than left implicit, so an
independent reviewer can tell lane-caused changes from pre-existing ones.

### 16.2 REQUIRED SEQUENCING — Lane S first (or together), Lane U never first

> **P-1 remains the governing finding, and it is unchanged.** Transitioning a work item into
> `agentExecuting` dispatches nothing: `agentExecuting` is not an entry state of
> `triageDefectDefinition` (`triage_defect.dart:10`), so `RunnableWorkEvaluator` returns `noAction`
> (`runnable_work.dart:83-85`), `Scheduler.tick` never enqueues for it
> (`scheduler.dart:492-516`), and `_eligibleRunnableJobs` drops any queued job for it anyway
> (`scheduler.dart:578-581`, and again at `:593-594`). **HD-4 did not change any of those gates — it
> changed which state the retry arrives at**, so the retry now lands where the gates say it should.

**Lane S is restated at 1.3.0 and is a different, smaller lane.** It no longer touches the
scheduler's dispatch path at all.

```
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │ LANE S — THE ENGINE EDGE (prerequisite)                                      │
 │                                                                             │
 │   packages/workflow_engine                                                 │
 │     work_item_transitions.dart : ONE new edge                              │
 │       (agentFailed, designNotRequired)                                      │
 │         -> actorAllowed([ActorType.orchestrator])       §6.5.1              │
 │     and AC-35's negative control: (agentExecuting, agentExecuting) is        │
 │       ILLEGAL, so the 1.2.0 defect cannot return silently.                  │
 │                                                                             │
 │   packages/scheduler                                                       │
 │     triage_defect.dart : triageDefectDedupeKey gains the attempt suffix    │
 │       §6.7 -- ABSENT metadata keeps the byte-identical historical key.     │
 │     ⛔ Scheduler.tick, _eligibleRunnableJobs, _dispatchOne, _claim and       │
 │        RunnableWorkEvaluator are ALL UNTOUCHED. There is no seam.           │
 │                                                                             │
 │   packages/workflow_store                                                  │
 │     appendOperatorAction + readOperatorActionsForWorkItem                  │
 │                     + transition(reason:, operatorAction:,                 │
 │                       metadataMerge:)                                      │
 │       -- the two WorkflowStore METHODS and the `reason` parameter are      │
 │          HD-2; metadataMerge is NEW AT 1.3.0, from HD-4's accepted cost    │
 │          (§6.4.5) and is NOT part of HD-2. It merges the attempt marker,   │
 │          which is what makes the §6.7 key rule work.                     │
 │                                                                             │
 │   apps/server : operator_action.spy.yaml + the migration + AC-31           │
 │   packages/store_contract_tests : append-only + atomicity contract tests    │
 │                                                                             │
 │   ACCEPTANCE (POSITIVE):  AC-35 · AC-36 · AC-37 · AC-17 · AC-14a–e · AC-10           │
 │   ACCEPTANCE (NEGATIVE):  AC-19b · AC-19c · AC-29 · AC-7                     │
 │   ⛔ BLOCKED ON NOTHING                                                      │
 └──────────────────────────────────┬──────────────────────────────────────────┘
                                    │  EDGE MERGED AND GREEN, OR IN THE SAME COMMIT
                                    ▼
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │ LANE U — THE SCREEN (depends on S)                                          │
 │   apps/server endpoints + wire models; apps/control_plane panel, confirm   │
 │     strip, plain-language copy, accessibility; goldens re-baselined          │
 │   ACCEPTANCE: AC-1…AC-8, AC-11…AC-16, AC-18…AC-28, AC-30, AC-31, AC-34       │
 │   ⛔ BLOCKED ON S.  May not merge before S.                                 │
 └─────────────────────────────────────────────────────────────────────────────┘
```

| Rule | Statement |
|---|---|
| **Prohibition — [JUSTIFICATION RESTATED at 1.4.0; ground (b) CORRECTED at 1.5.0]** | **The screen may not ship
alone.** AC-1…AC-4 remain a **joint gate on the whole change**, but **the stated harm changed, and the old
one is no longer true.** 1.3.0 justified it by saying a screen alone would write `agentFailed →
agentExecuting` and strand the item as a silent *“Working on it”*. **HD-4 removes exactly that harm:** without the
edge, a screen alone would write to a state that does not exist, the transition would be rejected, and
the panel would sit there accepting clicks that change nothing. The rule survives — and is arguably
**stronger** — on two truthful grounds:<br>**(a) It would be a button that does nothing.** §10 N7 forbids
silent failure; an operator pressing "Try again" and watching the panel persist is the exact quiet-screen
defect this brief exists to close. The failure is **immediate and visible** rather than silent-and-permanent,
which is an improvement, not a licence.<br>**(b) The screen cannot offer a restart at all.** The action list is
**server-computed from `WorkItemTransitions`** (§6.2: `actions: … server-computed from
WorkItemTransitions`), and without the new edge `isLegalTransition(agentFailed, designNotRequired)` is false,
so the server **cannot offer `retry`**. **AC-1 requires exactly `[retry, stop]`.** The panel would sit under
the heading *“Restart after a problem”* offering no restart — worse than a dead button, because it is a
panel that promises one.<br>**[CORRECTED at 1.5.0 — M-A: the 1.4.0 version of this ground cited AC-4 and is
REFUTED by this brief’s own panel mock. `attemptNumber` counts prior rows, so with zero prior rows the
panel renders “attempt 1 of 3” and AC-4’s string IS present: **AC-4 is satisfiable without the edge;
AC-1 is not.**]**<br>**Neither ground depends on the deleted seam.** |
| **Prohibited** | Shipping Lane U behind a feature flag that can be enabled before Lane S is deployed. |
| **Lane S acceptance — [RESTATED at 1.3.0]** | **POSITIVE:** AC-35 (the edge is legal through the real engine, with a negative control), AC-36 (the four dedupe-key properties), **AC-37 (the merge-not-replace proof — ADDED at 1.5.0, because the mechanism it guards had no acceptance gate)**, **AC-17 (a retried item is dispatched by a normal tick)**, AC-14a–e (the audit record), AC-10 (one-transaction atomicity). **NEGATIVE:** AC-19b (no re-dispatch without a recorded operator action), AC-19c (the audit is per attempt), AC-29 (`RunnableWorkEvaluator` untouched — review-enforced, not mechanical), AC-7 (the guard set). |
| **Retired from Lane S at 1.3.0** | **AC-15e, AC-32 and AC-33 are DELETED**, not reassigned. Each asserted something about branch B — that branch B dispatches, that branch B blocks without a row, and that branch B must not bypass `isEligibleAt`/provider health. **Branch B does not exist**, and the gates those ACs protected are the scheduler's existing ones, already covered by AC-18 and the untouched capacity suite. Keeping them would have required inventing a branch to test. |
| **Owner** | `orchestrator-main` — lane decomposition is the Manager's call, not this design lane's. |

### 16.3 Lane S completion gate — a dispatch must be OBSERVED, on the NORMAL path

> **[First stated at 1.2.0 for the deleted seam; restated at 1.3.0 for the path that replaced it.]**

**Lane S is NOT complete until a work item that an operator retry returned to `designNotRequired` is
observed DISPATCHING BY THE NORMAL TICK PATH** — with **no change to `Scheduler._eligibleRunnableJobs`
and no `requestOperatorDispatch` anywhere in the codebase.**

Concretely, the demonstrating test (AC-17): seed a work item at `designNotRequired` with
`metadata.triageAttempt = 1` and a free capacity slot; run one real `Scheduler.tick()`; assert a
`triage_defect` job is created under the `:a1` dedupe key **and** reaches `running`.
**[AT 1.5.0 — M-B]** The 1.4.0 text went on to call "`_eligibleRunnableJobs` is byte-identical" part of
the gate. **That assertion is dropped**: it is not mechanically checkable (AC-29), and asserting it
here contradicted the very retraction AC-29 made. The gate rests on the **behavioural** claim —
dispatch reached `running` through the ordinary path — plus the review obligation in AC-29.

**Why this gate exists.** This seam's specification has been wrong about the real control flow
**three times** — 1.1.0 appended behind two `continue`s; 1.2.0 substituted an always-false
self-transition; and both were invisible to the negative tests assigned to them. **A negative-only
lane contract cannot distinguish a working capability from a dead one**, and D-6 recorded that lesson
before it was proven the hard way. HD-4 deletes the seam rather than repairing it, which is the only
reliable answer to that — but the gate stays, because it is the property that would have caught all
three.

**What it costs.** One integration test owning a real `Scheduler` with a capacity guard and a stub
worker — the shape `tick_single_flight_test.dart` and `capacity_limit_test.dart` already use, so it is
a template, not an invention.
---

## 17. Where this brief is ready, and where it is not

**Ready for independent design review, and ready to implement.** All three escalations are RESOLVED
(§13.1) and their answers are folded back into the design rather than appended to it: §6.4's algorithm,
§6.4.2's confirmed `reason` parameter, §6.4.3's new audit table, §6.4.4's honest cost, §6.5.1's
restated authorisation conjunct, §6.6's confirmed fail-closed limit, §6.6.1's visibility
obligations, and the wire models in §6.2 all reflect the decisions. Nothing in the brief now says
"this is pending" or "to be decided".

**What remains open is one question (§13.2, OQ-1: whether the panel shows *who* restarted the work),
and it is not blocking** — it changes copy and one read, not structure, and it is answered with a
recommendation inside this design's authority.

**What a reviewer must not let happen (§16.2, §16.3).** The seam and the screen are one deliverable,
**and the seam must be *demonstrated dispatching*, not merely shown not to over-reach.** That is the
sequencing requirement of this brief, the reason AC-1…AC-4 are joint gates, and the reason Lane S
carries positive criteria.

**What this brief no longer defends, because the human overruled it.** At 1.0.0 §17 ended by naming
the `idempotencyKey`-prefix authorization as *"the most contestable decision in this document"* and
inviting a reviewer to treat it as such. Decision `2b8f4c07` rejected it: *"Authorization-by-string-
convention is not authorization."* **That withdrawal is the substantive change at 1.1.0**, and the
brief now rests on a recorded fact — an `operator_action` row written in the same transaction as the
state change — rather than on a predicate over a naming convention. §13.2 records the cost of being
wrong about that, which was mine.

### 17.1 Full-brief sweep for surviving 1.0.0 fragments — result

The reviewer's H1 asked for a sweep of the **whole** brief, not just the reported site. Run at 1.2.0:

| # | Fragment class | Sites found | Disposition |
|---|---|---|---|
| 1 | Text treating the **withdrawn** `operator-retry:` prefix as authorisation | 1 — §13.3 | **Deleted** (H1) |
| 2 | Orphaned `` `blocks:` `` line from the pre-closeout HD-2 block | 1 — §13.3 | **Deleted** (H1) |
| 3 | Duplicate unresolved `### HD-3 …` heading re-asking a closed question | 1 — §13.3 | **Deleted** (H1) |
| 4 | §14 **G5** "Any migration or schema change / **None is needed**" — untrue after HD-2 | 1 — §14 table | **Corrected** (found by this sweep, not reported) |
| 5 | Stale `reason:` citation `:156` | 1 — §2 P-3 | **Corrected** → `:157` (L2) |
| 6 | Stale rejected-path citation `:169-172` | 1 — §6.4.3 | **Corrected** → `:170-173` (L2) |
| 7 | "11 `WorkflowStore` implementors" | 2 — §6.4.4, §12 | **Corrected** → 8 (M2) |
| 8 | Bare `.decisions/**` naming as `PROHIBITED_PATHS` while §6.6.1 records a compose-file requirement | 1 — §0 | Already correct at 1.1.0 (tightened, not loosened) — **no change** |
| 9 | "escalated / not settled / to be decided" phrasing about the three decisions | 0 | **Clean** — the only two hits are §17's own claim that such phrasing is gone, and §13.2's "Not escalated as a Human Decision" (about OQ-1, which is correct) |

**Nine classes checked, one extra defect found that the review did not report (row 4).** Every other
"1.1.0 said" string in the brief is an intentional correction note and is left in place deliberately
— a correction that hides what it corrects is how this class of drift happens twice.

### 17.1a Seam-deletion sweep at 1.3.0 — grep evidence

The reviewer's instruction was to delete the seam and **not** produce a fourth variant. Verified
mechanically rather than asserted:

| Pattern searched | Hits | Verdict |
|---|---|---|
| `§6.5.2 ALTERNATIVE` | **0** | section gone |
| `_isOperatorRetryAuthorised` | **0** | helper gone |
| `_hasNonTerminalExecution` | **0** | branch guard gone |
| `OperatorDispatchOutcome` | **0** | promoted type gone |
| `statusOf[job.workItemId]!` | **0** | the null-hostile line is gone |
| `_policy.isLegalTransition` | **2** | **both in the prohibition list** (header record + the "must not reappear" list). Neither is live code |
| `requestOperatorDispatch` | **6** | **all historical or prohibitive**: 1.2.0 post-mortems, "that method no longer exists", and the two §16.2/§16.3 assertions that it must NOT exist |
| `branch B` | **5** | **all historical**: the 1.2.0 failure record, the always-false post-mortem, and the "deleted" notes |

`§6.5` now contains **no** `_eligibleRunnableJobs` change: §6.5.1 is the edge, §6.5.2 describes the
**existing** path it flows into, §6.5.3 is the label consequence. `Scheduler.tick`,
`_eligibleRunnableJobs`, `_dispatchOne`, `_claim` and `RunnableWorkEvaluator` are untouched
throughout. **Both are review-enforced, not mechanically enforced** — see AC-29 and §16.3; the
behavioural proof is AC-17's live tick.

### 17.2 What the reviewer verified, and this revision deliberately did NOT touch

P-1…P-6, the action set against the transition table, atomicity achievability, risk level 3, and the
three human decisions were all confirmed. **None was re-derived.**

> **[CORRECTED at 1.4.0 — the 1.3.0 version of this list was wrong in three places and understated how
> much had changed. It claimed §5, "§6.4's algorithm ordering" and "§6.5.1's authorisation conjunct"
> were not re-derived; all three were.]**

**Verified sound and not re-derived:** P-1 (gates G1–G4 exact), P-2…P-6, §5's **edge enumeration** and
the action set's *content* (only §5.2's *binding* of `retry` to E1 was wrong — corrected to E1′),
§6.4.3's audit-table shape, §6.5's edge and its legality proof, §6.6's limit, §7's capacity
behaviour, §8 (panel), §9 (accessibility), §13.1 (decision record), §14.1 (the nine parked items remain
out of scope), risk level 3.

**Changed by HD-4 at 1.3.0, and correctly recorded here at 1.4.0:** §6.4's algorithm (rewritten —
"much smaller", two steps removed), §6.5.1 (**no longer an authorisation conjunct** — it is the edge;
the conjunct died with the seam), §6.5.2/§6.5.3 (new), §6.7 (rewritten), §7.1 (rewritten), §16.2 and
§16.3 (restated).

