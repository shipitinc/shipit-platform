# Design Revision — Bound agent execution

**Feature:** Bound agent execution so a burst of intake cannot exhaust the host
**Revision:** 1 · **Risk level:** 2 · **Status:** UNDER_REVIEW
**Branch:** `design/execution-limits` · **Base SHA:** `5fb319a`

> Design only. Every diff in this document is **proposed text**, not applied. No production source,
> generated file or test was modified. Zero Docker/Compose commands were issued.

---

## §0 Executive summary

Three of the dispatch's framing assumptions do not survive contact with the code, and correcting
them changes the design materially. §1 states the corrected incident model. Everything after it is
built on that model, not on the operator's estimate.

The corrected model is:

| Operator's framing | What the code says | Effect on this design |
|---|---|---|
| `clarificationCount: 3` = three rounds per defect | It is `clarificationRequired.length` — **three questions asked in one pass** (`triage_processor.dart:147`) | The 21–27 invocation estimate is wrong |
| "answering a clarification re-drives triage" | **Nothing re-drives it.** The dedupe key is held forever | The per-defect ceiling is not the amplifier |
| "no capacity limit anywhere" | True at `Scheduler`, **but** an accidental in-memory bound of 1 exists via the single `LocalWorker` | The cap's value is durability + visibility, not first-ever bounding |

The **must-ship** work is therefore **not** what the dispatch sequenced first. It is:

1. **A tick single-flight guard** (`apps/server/lib/server.dart:322`) — the actual unbounded
   amplifier, and a prerequisite for trusting any concurrency cap.
2. **A durable global concurrency cap** at claim time (`packages/scheduler`).

The per-defect ceiling and the queue-depth cap are **follow-on**. The host-load guard is
**recommended against as a code guard**, and replaced by a deployment concern — §6.

---

## §1 The corrected incident model

### 1.1 `clarificationCount` counts questions, not rounds

`apps/server/lib/src/triage/triage_processor.dart:142-148`:

```dart
logger?.call('triage.processed', {
  'jobId': job.jobId,
  'triageResultId': triageResult.resultId,
  'defectId': triageResult.defectId,
  'classification': triageResult.recommendedClassification.wire,
  'clarificationCount': triageResult.clarificationRequired.length,
});
```

That list is parsed straight out of the agent's single structured result
(`triage_processor.dart:230-237`, from `structured['clarificationRequired']`). A value of `3` is
**one triage agent asking three questions**. There is no counter of rounds anywhere.

This is consistent with the observed totals: `total=21` across 9 defects with `max_per_defect=3` is
21 *questions*, averaging 2.3 per defect — exactly what a single pass per defect asking up to three
questions looks like.

### 1.2 There is exactly one triage job per defect, forever

The dedupe key is `'${workItemId}:triage_defect'` (`packages/scheduler/lib/src/triage_defect.dart:17-18`).
`JobQueue.enqueueIfAbsent` resolves a duplicate by `findLatestByDedupeKey`
(`packages/scheduler/lib/src/queue/job_queue.dart:56-60`), which matches **any** job state,
**including terminal**. Nothing releases the key. The code says so itself:

```
// work_entry.dart:483-493
if (existing.isTerminal) {
  return WorkEntrySkipped(
    WorkEntrySkipCodes.dedupeKeyAlreadyConsumed,
    'job ${existing.jobId} already holds dedupe key ${existing.dedupeKey} and is
     ${existing.state.wire}, so no new job can be created for this work item...'
```

and `work_entry.dart:224-229`:

> *"A defect triaged once can never be triaged again on this key... re-keying would orphan every
> job already persisted under the current format — a decision this lane does not make on its own."*

### 1.3 Therefore: where are the second and third rounds?

**They do not exist.** The second and third *questions* come from the same single triage pass. There
is no re-enqueue on clarification answer — `defect_endpoints.dart:207` `answerClarification` calls
`service.answerDefectClarification` and returns; there is no `enqueueIfAbsent` in that file, and no
other path mints a second `triage_defect` job for an existing work item. A full `rg` for
`enqueueIfAbsent` across non-test Dart returns exactly three production call sites
(`scheduler.dart:245`, `work_entry.dart:459`, plus a definition), all of which resolve through the
same dedupe key.

### 1.4 The hard per-defect invocation bound already exists, and it is 2

`triageDefectDefinition.maxAttempts: 2` (`triage_defect.dart:12`), and one job per defect means:

> **Maximum agent invocations for one defect = 2. Today, by construction. Not 3, not 21.**

Every logged line in the incident evidence is `triage.processed`, which is emitted only on the
success path (`triage_processor.dart:142`, reached after the execution-status and result-status gate
at `:81-96`). So the burst produced **9 successful triage invocations**, not 21–27.

### 1.5 What actually scaled with queue depth: overlapping ticks

`apps/server/lib/server.dart:322`:

```dart
// Run the scheduler every 30 seconds.
Timer.periodic(const Duration(seconds: 30), (_) async {
  try {
    final tickResult = await scheduler.tick();
```

`Timer.periodic` **does not** wait for an async callback to finish. Meanwhile:

- `_dispatchOne` awaits the whole execution: `await _dispatch.run(request)` (`scheduler.dart:370`),
  which runs `await worker.run(request)` → `_drive` → a real `Process.start`
  (`opencode_process_transport.dart:58`), bounded by `timeoutSeconds: 300` (`server.dart:188`).
- So **one tick lasts minutes**, and a new one starts every 30 seconds regardless.
- Each overlapping tick independently re-reads *all* jobs
  (`_eligibleRunnableJobs` calls `_jobStore.listJobs()` per outer-loop iteration,
  `scheduler.dart:303`) and re-attempts a dispatch for every job the earlier tick has not yet
  claimed.

A search for any single-flight guard — `_tickLock`, `inFlight`, `_running`, `Completer`, `overlap`
— across `server.dart` and `scheduler.dart` returns **nothing**.

**This is the only component in the design that scales with queue depth without a limit.** It is
the mechanism by which 9 queued defects became 9 concurrently-dispatched attempts rather than a
strictly serial queue.

### 1.6 An accidental bound exists, and it is not a design

There is exactly one registered worker (`server.dart:141`, `server.dart:152`):

```dart
final triageWorker = LocalWorker(...);
final workerRegistry = WorkerRegistry()..register(triageWorker);
```

and `LocalWorker` is exclusive (`packages/worker_runtime/lib/src/worker/local_worker.dart:66, 69-72,
92`):

```dart
bool get isAcquirable => !_leased;
Future<void> acquire() async {
  if (_leased) throw const WorkerBusyException('');
  _leased = true;
}
```

So a second overlapping tick's dispatch attempt gets `workerBusy`, throws `WorkerDispatchException`,
and is reverted to `queued` (`scheduler.dart:376-385`). Simultaneous `LocalWorker.run` calls are
capped at **1 per registered worker**.

This bound is inadequate as a capacity policy, and each of its defects is specific:

- **It is in memory.** The crash is the demonstration: after a reboot, jobs sit `running` with
  expired leases while the counter reads 0.
- **It is unconfigured and unlogged.** It appears nowhere in the `server.composition` startup line
  (`server.dart:296-316`). An operator cannot know the bound exists.
- **It scales with worker count, not with a decision.** `docker/compose.yaml` ships a `worker-linux`
  service. Registering a second worker doubles the bound with no other change and no review.
- **It bounds `LocalWorker.run`, not host cost.** One execution forks `opencode` (Node, with its own
  children), a `git worktree`, and further spawns at
  `packages/execution_coordinator/lib/src/verifier/workspace_verifier.dart:75`. A count of Dart
  futures is not a count of host load.

**Therefore the concurrency cap in §3 is worth building — but its value is converting an accidental,
in-memory, unregistered property into an explicit, durable, configured, observable one. This design
does not claim it is the first bound that ever existed.**

---

## §2 Design decision record

| # | Decision | Alternative rejected |
|---|---|---|
| D1 | Tick single-flight guard — one tick at a time per process | Leaving it; it is the amplifier in §1.5 |
| D2 | Concurrency cap enforced **durably at claim time** | In-process semaphore (§3.2) |
| D3 | Cap is **global**, one budget for the whole cluster | Per-product / per-role scoping (§3.3) |
| D4 | Denial = stay `queued`, retried next tick, recorded | Fail the job; drop it silently |
| D5 | Per-tick dispatch budget **and** backlog cap, both | Either alone |
| D6 | Per-defect ceiling **derived** from `model_execution_record` | New column / new table (§5.2) |
| D7 | Ceiling source unavailable ⇒ **deny**, fail closed | Treat as "under the ceiling" |
| D8 | **No code-level host-load guard.** Compose limits instead | The in-container load guard (§6) |
| D9 | Capacity figures surfaced in `server.composition` | A guard that reads as protection but is not |

---

## §3 Requirement 1 — Global concurrency cap (MUST SHIP)

### 3.1 Where the semaphore lives: durable, at claim time

**Decision: durable, in the job store, evaluated inside the same transaction as the claim.**

The capacity question dispatch asks — "how much work is already in flight?" — is a fact about
durable state, and `_dispatchOne` already performs a durable CAS at `scheduler.dart:354-360`. Folding
the capacity check into that transaction makes "a slot was taken" and "the capacity was checked" one
atomic fact rather than two facts that can disagree.

An in-process semaphore in `Scheduler` is wrong on four specific counts:

1. **The process demonstrably holds concurrent ticks.** §1.5. A per-`Scheduler` semaphore would be
   shared across them — but only because they are in one process. That is an accident of topology.
2. **A restart resets it to zero while executions are still running.** This is not hypothetical: it
   is precisely the post-crash state.
3. **It does not survive replicas.** Production may run more than one; the cap would be `C × N`.
4. **The code already describes a durable concept.** `scheduler.dart:256-258`:

   > *"Re-reading live state each round lets a job that completed during this tick free a **capacity
   > slot** for the next one."*

   A capacity slot that must be freed by *another writer's* completion is not an in-process counter.
   The comment describes a limit that does not exist — the dispatch is right about the intent, and
   this design supplies the mechanism.

### 3.2 The claim-time transaction, and why it is correct under two replicas

Proposed: inside the existing `_store.inTransaction`, take a **PostgreSQL transaction-scoped
advisory lock** keyed to the capacity budget, count in-flight jobs, and only then attempt the claim.

```sql
SELECT pg_advisory_xact_lock($1);                      -- $1 = stable bigint per cap name
SELECT count(*) FROM job WHERE "state" IN ('claimed','running');
-- if count < C: proceed with the existing claim CAS
```

**Why this is correct under two replicas.** `pg_advisory_xact_lock` is held until the enclosing
transaction ends and is invisible-incorrectness-free across sessions: two replicas cannot both hold
it, so "count, then claim" cannot interleave. A bare `SELECT count(*)` followed by the claim would
let both replicas observe `count = C-1` and both claim — an overshoot by one per replica, per tick.

**Why this survives restart.** It reads `job.state`, which is durable. After the crash, jobs left
`running` are counted; reconciliation (`scheduler.dart:205-216`) reclaims expired leases, and the
count falls as those are adopted or requeued.

**Why the lock key is per-budget and the budget is global.** Different cap names take different
locks, so a triage burst cannot block onboarding dispatch. But there is exactly **one** agent-execution
budget, so the cap bounds the host regardless of which lane is asking.

**The cost, stated plainly.** There is **no index on `job.state`** — verified across all migrations:
only `job_id_unique`, `job_work_item_idx`, `job_dedupe_key_idx` and `job_active_dedupe_unique` exist
(`20260929123032034/migration.sql:33`, `20260914041810984/migration.sql:152-154`). The count is
therefore a sequential scan of `job`. On a table bounded by intake volume this is acceptable, and it
runs once per *claim attempt*, not once per job. **If `job` ever grows to the point where this
matters, the fix is an index on `state` — which is a migration, and is explicitly out of scope for
must-ship.** Recorded so the cost is a decision, not a surprise.

**Zero migration.** This mechanism adds no table, no column and no index. Nothing here touches the
schema drift guard. That is the main reason it is preferred over a capacity table.

### 3.3 Global, not per-(product, worker, runtimeType)

**Decision: global.** The dispatch's own reasoning is correct and is adopted: nine defects for one
product must be bounded, and per-product scoping bounds nothing at the host.

Per-(worker, runtimeType) is a genuine trap. `LocalWorker.toRegistration` already advertises
`maxConcurrency: 1` (`local_worker.dart:92`), and a per-worker cap would read as "the host is
bounded" while scaling linearly with every worker registration — the §1.6 failure mode, re-implemented
on purpose.

### 3.4 What happens to a job that does not get a slot

**It stays `queued`. It is never failed, never cancelled, never dropped, and never given up on.**

- The claim is simply **not attempted**, so no lease is taken and no state is written.
- `_dispatchOne` returns an outcome carrying `capacityDenied: true`.
- The tick records it in the **already-existing** `SchedulerTickResult.deferred` list
  (`scheduler.dart:92`, `:273-276`) — the same honest-reporting channel already used for "no worker
  could be acquired". No new reporting channel is invented.
- A `scheduler_event` of kind `dispatch.capacity_deferred` is emitted naming the job, the budget, the
  observed in-flight count and the cap.
- `attempted.add(job.jobId)` keeps the tick from spinning on the same denied job; the next tick
  retries it.

This is not a new behaviour shape — it is exactly what `workerBusy` already does today
(`scheduler.dart:376-385`), generalised.

### 3.5 The default `C` — escalated, not chosen

**This lane does not choose `C`.** It is routed as **HD-1** (§8). What this lane supplies is the
evidence the choice needs, and a mechanism that fails closed without a value.

Evidence available:

| Input | Value | Source |
|---|---|---|
| Registered triage workers today | 1 | `server.dart:152` |
| Incidental concurrency bound today | 1 | `local_worker.dart:66,92` |
| Execution timeout | 300 s | `server.dart:188` |
| Tick period | 30 s | `server.dart:322` |
| Observed invocations in the burst | 9 | §1.4 |
| Host core count / RAM | **UNKNOWN** | not observable; QA down, no Docker commands permitted |
| Measured RSS per agent session | **UNKNOWN** | never measured — no such telemetry exists |

**Recorded limitation.** The two inputs that would justify any `C > 1` — host core count and
measured per-session memory — are **not available to this lane**. This design therefore does not
assert a number it cannot support.

**Recommendation (a recommendation, not a decision):** `C = 1` for the first release. It is
*provably no worse than the state that crashed* — it matches today's incidental behaviour exactly, so
it cannot regress throughput — and it needs no host sizing input. Raising `C` above 1 is a host
capacity decision that requires measurement this repository does not yet collect.

**Fail-closed on an unset value.** `SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS` is **required**. If it is
absent or unparseable the scheduler **refuses to start** and logs the reason by name. A cap that
defaults to "unlimited" re-creates the incident; a cap that defaults to a guessed number is a lie in
a log line. The startup line states the resolved value in both directions.

### 3.6 Configuration without a code change

`SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS` — required, integer ≥ 1, read in the composition root
(`server.dart`, §5 of L2), injected into `Scheduler`. Changing the cap is a restart, not a release.

---

## §4 Requirement 2 — Queue depth (FOLLOW-ON)

Two different problems, two different mechanisms.

### 4.1 Per-tick dispatch budget — always on, no operator-visible refusal

A separate bound `D` on the number of *new claims* one tick may attempt. The concurrency cap bounds
what may be **in flight**; `D` bounds what one tick may **cost**, which is the store churn and
full-table rescan that §1.5 identifies as the thing that scales with queue depth. Recommend `D = 4C`.

This never refuses anything the operator asked for — a denied job is simply retried next tick. It is
code-only and needs no human decision.

### 4.2 Backlog cap at intake — refuse or not is escalated

**Whether intake may ever refuse is HD-2 (§8).** This lane does not decide it. The *shape*, if
adopted, is specified so the human is choosing between concrete options:

**The refusal must be honest and must not contradict a fact already on disk.** `control_plane_service.dart:895-930`
records the precedent at length:

> *"intake has already committed the request and told the reporter it was accepted... surfacing a
> conflict as an error contradicts a fact that is already on disk."*

So the designed shape is **load-shedding, not rejection**:

- The defect and its work item **are** recorded. The reporter's "accepted" stays true.
- The triage job is **not** enqueued.
- The decision is recorded under a new `WorkEntrySkipCodes`-shaped constant
  (`work_entry.dart:171-231`) — `BACKLOG_CAP_REACHED` — carrying defect id, product id and observed
  backlog, logged under a greppable event exactly as `work_entry.gated` already is
  (`work_entry.dart:412-418`).
- The defect remains visible to the operator as awaiting dispatch. **Never a silent drop.**

**A dependency that must not be missed.** Because the intake path and the sweep share one dedupe key
(`work_entry.dart:259-272`), a defect refused a triage job *can* be enqueued later — but only if
something re-runs the trigger. The `DefectTriageSweep` is that something, and **it is gated OFF**
(`defect_triage_sweep.dart:25-40`: *"do not enable the sweep on the live tick until P-2 and P-5 pass"*).

> **A backlog cap at intake, without the sweep enabled, converts load-shedding into stranded work.**
> Defects would be recorded, never enqueued, and never retried.

This is a hard dependency edge in §7: **L4 depends on the sweep gate being lifted, which depends on
P-2/P-5 evidence that this lane cannot produce.**

### 4.3 Depth cap does not bound the host by itself

Stated so the reviewer does not over-credit it: a backlog cap limits *arrival rate*, not
*concurrency*. The §1.6 crash was reachable with 9 items — well under any sane depth cap. Depth is
the second line, not the first.

---

## §5 Requirement 3 — Per-defect invocation ceiling (FOLLOW-ON)

### 5.1 What this is for, stated honestly

Per §1.2 and §1.4, the per-defect invocation count is **already structurally bounded at 2** and
cannot be the thing that crashed the host. Designing a ceiling that pretended otherwise would be
worse than not designing one.

The ceiling is built anyway, for three real reasons:

1. **It is the guard that makes a future change safe.** Raising `maxAttempts`, or introducing
   multi-round triage (which §1.3 shows the operator *believes* already happens), becomes a
   one-number change instead of a re-incident.
2. **It bounds cost and blast radius per defect**, not just concurrency.
3. **It is the only requirement of the four that has a clean, migration-free implementation** (§5.2).

A reviewer should read this section as forward protection, **not** as load-bearing for the crash.

### 5.2 Where the count lives — derived, with no new column and no migration

`model_execution_record` already holds exactly the right grain, already indexed, already written by
the runtime:

- **Grain:** one row per agent execution. `_insertModelExecutionRecord` is called from the three
  `execute` completion paths (`execution_coordinator.dart:420, 453, 618`), not per model call.
- **Index:** `model_execution_record_work_item` on `"workItemId"`
  (`apps/server/migrations/20261006150645000/definition.sql:505`).
- **Cost of deriving:** one indexed `COUNT(*)` per dispatch decision.

> ### ⚠ Trap — the `jobId` column does not hold a job id
>
> `execution_coordinator.dart:711-712`:
> ```dart
> final record = ModelExecutionRecord(
>   workItemId: request.workItemId,
>   jobId: request.workItemId,     // <-- workItemId, not jobId
> ```
>
> A per-defect count **must** filter on `"workItemId"`. A query written against `"jobId"` is
> semantically wrong and will produce a plausible, confidently wrong number. This is called out here
> because nothing in the schema marks the column.

**Off-by-one.** Rows are written at *completion*, so a dispatch-time count undercounts by the in-flight
execution. Given §1.2 (at most one live triage job per defect), the exact predicate is:

```
invocations(defect) = COUNT(*) FROM model_execution_record WHERE "workItemId" = $1
                    + (1 if the defect's job is claimed|running else 0)
```

**Migration cost: zero.** No table, no column, no index, no `definition.sql` edit — so nothing here
touches `verify_schema_bootstrap.sh` or the drift guard. This is the answer to the dispatch's question
about whether a new column is needed: **it is not.** Had a counter column been added instead, the real
cost would have been a new migration directory, a hand-maintained `schema_bootstrap.sql` edit, and a
re-run of the drift guard — which is exactly the class of cost that is easy to under-price.

### 5.3 Fail closed when the count is unavailable (D7)

`execution_coordinator.dart:692-693`:

```dart
final modelExecutionRecordStore = this.modelExecutionRecordStore;
if (modelExecutionRecordStore == null) return;   // silent no-op
```

If that dependency is absent, the count is permanently 0, the ceiling never fires, and the system
reports health. **That is the silent-success class this work item exists to end.**

So the gate treats an unavailable count source as **DENY**, recorded as
`EXTERNAL_MODEL_EXECUTION_RECORD_UNAVAILABLE` — per the established `EXTERNAL_*` convention. It is
never recorded as "under the ceiling", and never allowed through.

### 5.4 When the ceiling is reached

- The job goes **terminal** `failed` with a dedicated failure code `INVOCATION_CEILING_REACHED` and a
  human-readable reason naming the defect, the observed count, the ceiling and the escalation.
- A `scheduler_event` row records the same.
- **It is never a retry loop.** A ceiling that retries is not a ceiling.
- **The named visible path:** the ceiling is
  `SHIPIT_DEFECT_INVOCATION_CEILING`, and the reason text states it verbatim — *"raise
  `SHIPIT_DEFECT_INVOCATION_CEILING` or re-key `triageDefectDedupeKey`; re-keying orphans every job
  already persisted under the current format"*. A defect that legitimately needs more has a route a
  human can see and take. Nothing is silently truncated.

---

## §6 Requirement 4 — Host-load guard: recommended AGAINST as a code guard

This is the section the dispatch asked to be assessed honestly. The answer is that the guard is
**inert as configured today**, which is worse than absent.

### 6.1 What the server can actually see from inside its container

| Signal | Reachable? | Does it mean "the host"? |
|---|---|---|
| `/proc/loadavg` | Yes — **not namespaced** | **No, under Docker Desktop on macOS.** It is the LinuxKit VM's EWMA. The VM is not what crashed. |
| `/proc/meminfo` | Yes, host-wide | Same problem. No `lxcfs` mount exists in any compose file. |
| cgroup `memory.max` / `cpu.max` | Yes — the container's **own** | Meaningful, **but unbounded today** (below). |

### 6.2 The decisive fact: there is no limit to measure against

A search for `mem_limit`, `cpus`, `deploy.resources`, `limits`, `reservations` and `pids_limit`
across all six files in `docker/` returns **nothing**. `docker/compose.yaml` declares three volumes
and no resource constraints on any service.

A cgroup-derived load guard therefore reads **"not loaded" forever** and never fires. A guard that
cannot fire is not a weak guard; it is a guard that manufactures confidence in an operator while
providing none. Under the honest-reporting discipline this work item enforces, shipping it would be
worse than shipping nothing.

### 6.3 Recommendation: a Compose-level memory + CPU limit is strictly better

1. **It bounds the process tree, not the dispatch count.** `opencode` forks; `workspace_verifier.dart:75`
   spawns; each execution consumes a `git worktree` and disk. A concurrency cap counts *executions*.
   A cgroup bounds *whatever they actually cost*, including costs the cap cannot see.
2. **It fails safe by construction.** Exceeding the memory limit is an OOM-kill of the container,
   which the runtime restarts — instead of taking the host down.
3. **It is not agent-controlled.** A cap can be mis-set by a human; a cgroup cannot be exceeded by a
   runaway subprocess tree, which is the actual failure mode.
4. **It is a deployment concern**, so it belongs with the people who hold deployment authority —
   exactly the authority this lane does not hold.

**Recommended action: do not build the code guard. Add `mem_limit` + `cpus` (+ `pids_limit`, which
bounds fork storms specifically) to the `server` service in `docker/compose.yaml` and to
`worker-linux`.** The numbers are **HD-3** (§8): they depend on real host capacity this lane cannot
observe.

### 6.4 What replaces the guard's *intent*: visibility

Visibility is not protection, and this document does not claim it is. The `server.composition` startup
line (`server.dart:296-316`) gains the resolved cap, the budget name and the per-tick budget `D`. A
periodic `dispatch.capacity` event reports in-flight / cap. An operator can then see saturation
instead of inferring it from a crash.

---

## §7 Implementation lane plan

Non-overlapping `OWNED_PATHS`; no two lanes may write the same file.

| Lane | Scope | OWNED_PATHS | Depends on | Ship |
|---|---|---|---|---|
| **L1** | Concurrency cap at claim | `packages/scheduler/lib/src/capacity/**` (new)<br>`packages/scheduler/lib/src/scheduler.dart`<br>`packages/scheduler/lib/src/queue/job_queue.dart`<br>`packages/scheduler/test/capacity/**` | — | **MUST** |
| **L2** | Tick single-flight + composition-root wiring | `apps/server/lib/server.dart`<br>`apps/server/test/tick_single_flight_test.dart` | — | **MUST** |
| **L3** | Per-defect invocation ceiling | `apps/server/lib/src/triage/invocation_ceiling.dart` (new)<br>`apps/server/lib/src/triage/triage_processor.dart`<br>`apps/server/test/invocation_ceiling_test.dart` | L1 | follow-on |
| **L4** | Backlog cap + honest refusal | `apps/server/lib/src/triage/work_entry.dart`<br>`apps/server/lib/src/triage/defect_triage_sweep.dart`<br>`apps/server/test/backlog_cap_test.dart` | L1 **and** the sweep gate (P-2/P-5) | follow-on |
| **L5** | Compose resource limits | `docker/compose.yaml`<br>`docker/compose.qa.yaml`<br>`docker/compose.e2e.yaml`<br>`docker/compose.test.yaml` | HD-3 | follow-on |

**Dependency edges.** `L1 → L3`, `L1 → L4`. `L2` is independent and parallelisable with `L1`. `L5` is
independent of all code lanes and blocked only on a human decision.

**SAFE_PARALLEL_WORK:** `L1 ∥ L2`; `L5 ∥ {L1, L2, L3, L4}`.
**PROHIBITED_PARALLEL_WORK:** `L1 ↔ L3`; `L1 ↔ L4`; `L2 ↔ any lane owning `server.dart``; `L3 ↔ L4`
(shared `work_entry.dart` neighbourhood — serialise).

**L1 and L2 must ship together.** A cap without single-flight is correct in outcome but still pays
O(ticks × jobs) transactions forever; single-flight without a cap leaves concurrency at whatever the
worker registry happens to say.

---

## §8 Human decisions routed — none resolved by this lane

### HD-1 — The default value of `C`
*Question:* what is `SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS` on the first release?
*Recommendation:* `C = 1` — provably no worse than today's incidental behaviour, and it needs no
host-sizing input this lane cannot obtain. Any `C > 1` requires measured host capacity and measured
per-session memory, **neither of which this repository collects today**.
*Blocks:* D4 approval and production rollout. *Does not block:* implementing L1 and L2, which take `C`
as an injected parameter.
*Note:* the mechanism fails closed — an unset or unparseable value stops the scheduler rather than
defaulting to unbounded. The human's choice is therefore required, not merely advisable.

### HD-2 — May intake ever refuse?
*Question:* should a defect be recorded but **not** enqueued for triage when the eligible backlog
exceeds a cap? This is an operator-visible behaviour change and is squarely a product decision.
*Recommendation:* if yes, adopt the load-shedding shape in §4.2 — record, never reject, new
`BACKLOG_CAP_REACHED` skip code, never a silent drop — **and only alongside the enabled sweep**, or
refused defects are stranded (§4.2).
*Blocks:* L4 entirely. *Does not block:* L1, L2, L3, L5.

### HD-3 — Server and worker resource limits
*Question:* what `mem_limit`, `cpus` and `pids_limit` apply to `server` and `worker-linux` on each
deployment target?
*Blocks:* L5, and any shared or staging host. *Does not block:* restarting local QA on a
Docker-Desktop-bounded VM.

---

## §9 Test design

| # | Test | Assertion | Lane |
|---|---|---|---|
| T1 | N > C queued jobs | Instrumented fake runtime counts concurrent entries; observed max **== C**, never > C | L1 |
| T2 | Cap across ticks | Cap holds when the N jobs span multiple ticks; max never exceeds C in aggregate | L1 |
| T3 | Denied slot retries | A job denied a slot stays `queued`, appears in `deferred`, and **succeeds on a later tick** | L1 |
| T4 | **No overshoot by one** | Two concurrent `run()` calls against C=1 and two queued jobs → **exactly one** dispatch. This is the negative case for `pg_advisory_xact_lock`; without the lock this test fails | L1 |
| T5 | Restart stability | In-memory semaphore is discarded; a fresh scheduler instance still counts `running` jobs from the store | L1 |
| T6 | Single-flight | A tick that outlives the 30 s period does **not** admit a second concurrent tick | L2 |
| T7 | Unset cap | Absent/unparseable env → scheduler refuses to start, naming the variable | L2 |
| T8 | Ceiling reached | At the ceiling the defect reaches terminal `failed` with `INVOCATION_CEILING_REACHED` and a **named** escalation | L3 |
| T9 | **Ceiling source unavailable** | `modelExecutionRecordStore == null` → **DENY** under `EXTERNAL_MODEL_EXECUTION_RECORD_UNAVAILABLE`, never allowed | L3 |
| T10 | **Derivation correctness** | Fixture proves `COUNT(workItemId)` returns invocations and that `COUNT(jobId)` returns something else — pins the §5.2 trap | L3 |
| T11 | Refusal visible | Every depth/ceiling/capacity denial emits a named, greppable record; no path drops silently | L1, L4 |
| T12 | No migration | `verify_schema_bootstrap.sh` exit 0 before and after | all |

**T12 note.** The schema guard was run for this design: **exit 0, all 20 checks OK.** Because L1–L4
add no schema objects, the guard must remain at exit 0 afterwards — that is the regression test for
"no migration".

---

## §10 Traceability

### Constraints from the dispatch — coverage

| Constraint | Where |
|---|---|
| Design only; diffs as text; no source/test/generated file touched | Whole document; `files_modified_outside_owned_paths: 0` |
| Zero Docker/Compose commands | Whole document; `docker_or_compose_commands_issued: 0`. Compose read **as text** only |
| `verify_schema_bootstrap.sh` run and reported | §9 T12 — **exit 0, 20 OK** |
| Concurrency cap designed first, at dispatch | §3 |
| Where the semaphore lives; two-replica claim transaction | §3.1, §3.2 |
| Global vs per-product | §3.3 |
| What happens to a job denied a slot | §3.4 |
| Default `C` justified, configurable without code change | §3.5 — mechanism complete, **value escalated as HD-1** |
| Queue depth: budget, backlog cap, or both; honest refusal | §4 — both; refusal shape §4.2, adoption escalated as HD-2 |
| Per-defect ceiling; count location; schema cost priced | §5.2 — **zero migration**, and the `jobId` trap named |
| Host-load guard assessed honestly; Compose recommended | §6 — recommended against; §6.3 |
| Tests incl. all listed negative cases | §9 — T4, T9, T10 are the negative cases |
| Non-overlapping OWNED_PATHS + dependency edges | §7 |
| MUST-ship vs follow-on split | §11 |
| Human Decisions escalated, not resolved | §8 — HD-1, HD-2, HD-3 |
| Honest reporting; `EXTERNAL_*`, never stubbed | §5.3 (`EXTERNAL_MODEL_EXECUTION_RECORD_UNAVAILABLE`) |
| Premise skepticism — clarifications | §1.1, §1.3 |
| Premise skepticism — host-load guard in a container | §6.1, §6.2 |

### Requirements gaps — deliberate, not omissions

- **The default `C` is not decided.** HD-1. This lane lacks the two inputs that would justify any
  value above 1.
- **Intake refusal is not decided.** HD-2. §4.2 specifies the shape so the choice is between concrete
  options.
- **Resource limits are not chosen.** HD-3. Host capacity is not observable from this lane.
- **Host core count and per-session memory are UNKNOWN** — never measured, and this design asserts no
  number that depends on them.

---

## §11 What must ship before QA restarts

### MUST ship — L1 + L2

| | Why |
|---|---|
| **L1 concurrency cap** | The operator's named priority. Durable, configured, observable, restart-stable. No migration. |
| **L2 tick single-flight** | §1.5: the mechanism by which queue depth became concurrent work. The cap is not trustworthy without it. |

Neither requires a Human Decision to **implement** — both take their parameters as injected values and
are fully testable. `C` must be *set* before QA restarts; HD-1 governs the *policy* value, and the
fail-closed default means QA restart will not silently run unbounded.

### Follow-on — explicitly not required for QA restart

- **L3 per-defect ceiling** — already structurally bounded at 2 (§1.4). Forward protection.
- **L4 backlog cap** — depends on the sweep gate, which depends on P-2/P-5 evidence this lane cannot
  produce.
- **L5 Compose limits** — local QA runs on a Docker-Desktop-bounded VM, which is already constrained.
  **Required before any shared or staging host.**

### Explicitly not recommended

- **A code-level host-load guard** (§6). Inert as configured; replaced by L5.