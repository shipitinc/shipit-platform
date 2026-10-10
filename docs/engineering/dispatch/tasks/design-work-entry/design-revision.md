# Design Revision #1 — Work-Entry Trigger: making triage live, and what it is honest to make live

| Field | Value |
|---|---|
| `revision_id` | `b5ff65f3-ce59-4349-a457-01187b112e0d` |
| `brief_id` | `6fbb5bb2-4225-4856-b943-5eff1ff045be` (inline; no prior Design Brief exists for this work item) |
| `revision_number` | 1 |
| `status` | `UNDER_REVIEW` |
| `risk_level` | **2** |
| `branch` | `design/work-entry` |
| `base_sha` | `d25a4d8` |
| `head_sha` | `d25a4d8a3a70ff49485c43af83019347d790d8f7` (design-only lane; no production file is modified) |
| `created_by` | `design-agent` |
| `created_at` | `2026-10-10T23:11:09Z` |

---

## 0. Scope of this document

This is a **design**. Proposed diffs appear **as text**. No production source, generated file, test,
schema, or client file in this repository is modified.

> **Dispatch-file provenance note.** The dispatch path
> `docs/engineering/dispatch/tasks/design-work-entry/prompt.md` **does not exist** in either the
> worktree or the canonical checkout (verified: `ls` returns *No such file or directory*; the task
> directory did not exist and was created by this lane). The dispatch content was supplied inline in
> the task message and is the sole source for the requirements traced in §9. This is recorded rather
> than silently worked around, because it means **there is no durable record of what was asked**,
> and an independent reviewer reading only the repository will not find it.

**Owner declaration (made before any file was written):**

| Class | Paths |
|---|---|
| `OWNED_PATHS` | `docs/engineering/dispatch/tasks/design-work-entry/**` |
| `READ_ONLY_PATHS` | `packages/**`, `apps/**`, `docker/**`, `.github/**`, `docs/**` |
| `PROHIBITED_PATHS` | `packages/**`, `apps/**`, `docker/**`, `.github/**`, `.decisions/**`, `AGENTS.md`, `docs/**` (outside `OWNED_PATHS`) |

---

## 1. Premise corrections — four of the dispatch's stated facts do not survive reading

The dispatch presented its facts as "verified, do not re-derive". Three of them are wrong at
`d25a4d8`. Each is corrected below with the call site that proves it. This section is load-bearing:
**the design that follows is materially different from the design the dispatch's premises imply.**

### P-1 — `createDefect` **already enqueues a `JobType.triageDefect` job**. "Nothing enqueues one anywhere" is false.

```dart
// apps/server/lib/src/services/control_plane_service.dart:1036-1062
final defectWorkItem = await _triageWorkItemProvisioner.ensurePersisted(
  defect: defect,
  evidenceJson: jsonEncode(intakeEvidence),
);
final dedupeKey = triageDefectDedupeKey(defectWorkItem, triageDefectDefinition);
final instruction  = triageDefectInstruction(defectWorkItem, triageDefectDefinition);
final enqueueResult = await jobQueue.enqueueIfAbsent(
  workItemId: defectWorkItem.workItemId,
  definition: triageDefectDefinition,
  dedupeKey: dedupeKey,
  instruction: instruction,
);
if (enqueueResult.created) {
  final updatedDefect = defect.copyWith(
    currentTriageJobId: enqueueResult.job.jobId, ...);
  await defectStore.saveDefect(updatedDefect);
}
```

The method's own doc comment says *"Enqueues a triage job"* (`:909`). `DefectTriageWorkItemProvisioner`
is wired as a live getter over the same `workflowStore`/`workflowEngine` the scheduler reads
(`:94-100`), and `jobQueue` is a live `JobQueue` over the live `PostgresJobStore` (`:73`).

### P-2 — The root cause of the dispatch's call-site trace: `saveJob` has a **third** enqueue path, behind an interface indirection.

The dispatch traced `jobStore.saveJob` and found two callers. `JobQueue.enqueueIfAbsent` calls
`tx.saveJob(job)` on a **`JobStore` transaction handle** (`packages/scheduler/lib/src/queue/job_queue.dart:75`),
which a `rg saveJob\(` for a concrete `jobStore` does not surface as an intake call site. The full
non-test enqueue path set is:

| Caller | Writes | Found by the dispatch's trace? |
|---|---|---|
| `baseline_onboarding_sweep.dart:668` | `jobStore.saveJob(onboardingJob(...))` | yes |
| `control_plane_service.dart:1889` (`triggerOnboarding`) | `jobStore.saveJob(job)` | yes |
| **`job_queue.dart:75`** via **`enqueueIfAbsent`** | `tx.saveJob(job)` | **no** |
| ↳ `control_plane_service.dart:1048` | `jobQueue.enqueueIfAbsent(triageDefectDefinition)` | **no** |
| ↳ `scheduler.dart:245` (`Scheduler.tick`) | `_queue.enqueueIfAbsent(_definition)` | **no** |

**This is the same defect class the work item is chasing, one level up.** An exhaustive trace that
only follows concrete-type call sites will report "nothing enqueues" while the interface-mediated
path enqueues on every single defect report. Recorded as **D-1** (§8) — a workflow-improvement
candidate for the verification tooling, not a code fix in this revision.

### P-3 — The scheduler already enqueues. `Scheduler.tick` is not dispatch-only.

`Scheduler.tick` step 3 (`packages/scheduler/lib/src/scheduler.dart:230-254`) iterates **every**
work item, and for each one the policy classifies `runnable`, calls
`_queue.enqueueIfAbsent(... dedupeKeyBuilder ...)`. The triage `Scheduler` in `server.dart:165-193`
is built with `definition: triageDefectDefinition` and
`dedupeKeyBuilder: triageDefectDedupeKey`.

**Consequence: a defect never needs a bespoke enqueue at all once its work item is durably walked
to `designNotRequired`.** The scheduler will find it and enqueue on the next tick. Intake's
`enqueueIfAbsent` is an *optimisation for latency*, not the mechanism — and it is also the thing
that has no recovery path when it does not happen.

### P-4 — There **is** a feature-request UI. The dispatch says there is not.

The dispatch listed the control plane's feature directories and concluded *"NO feature-request
screen"*. They exist, inside a directory the dispatch itself listed:

- `apps/control_plane/lib/features/reports/create_feature_request_page.dart`
- `apps/control_plane/lib/features/reports/feature_request_list_page.dart`
- `apps/control_plane/lib/features/reports/intake_tabs.dart`
- blocs: `create_feature_request_bloc.dart`, `feature_request_list_bloc.dart`
- repository: `control_plane_repository.dart:543` `createFeatureRequest`, `:565` `listFeatureRequests`
- `intake_endpoints.dart:52` — *"The Reports screen's Feature tab calls it"*

**Why it matters to the design:** the feature path has a **rendered, human-facing surface with
listeners**, not a dead API. That raises the change's UX risk (§10) and means §7 must be written
against what the operator will actually see.

### P-5 (corroborating, not a correction) — `saveJob`'s remaining callers are queue bookkeeping.

`job_queue.dart:149,181,213,245,303,354,401` and `baseline_dispatch.dart:537` are all
CAS transitions on jobs that already exist, not enqueues. The dispatch's "exactly two callers" was
right about *what it was looking at* and wrong about what that implied.

### What actually survives

| Dispatch claim | Verdict |
|---|---|
| "`createFeatureWorkItem` … **It enqueues nothing.**" | **TRUE** — verified, `control_plane_service.dart:766-800` writes a `draft` work item and a `workIntake` direction, and nothing walks the item out of `draft` (`rg 'WI-feature'` finds only the allocator and its test). |
| "the whole defect-triage pipeline is built and dormant" | **FALSE** — built **and wired**. Whether it has ever *executed* is a runtime fact; see §2.2. |
| "`Scheduler` takes ONE `JobDefinition` and skips jobs whose `workItemId` is not a real `WorkItem`" | **TRUE** — and irrelevant here (defects and features both have real rows). Confirmed, see §5. |
| "`triageDefectDedupeKey` = `'${item.workItemId}:${definition.jobType.wire}'`" | **TRUE** — `packages/scheduler/lib/src/triage_defect.dart:17-18`. |

---

## 2. Restated problem

### 2.1 The real gap

| Path | Enqueues today? | Consumer exists? | Gap |
|---|---|---|---|
| **Defect** | **Yes** (`control_plane_service.dart:1048`) | Yes (`TriageProcessor`) | **No recovery path.** Intake-only enqueue: if it throws, races, or predates `0d5d132`, nothing ever retries. The code comment at `:1028-1029` records **18 jobs already stranded `queued` in the live test DB with no work item behind them** — those are still stranded, and this revision does not clear them. |
| **Feature** | **No** — item parked at `draft`, never walked | **No** — see §6 | Both halves missing. |

So the defect class is real, but it is **not** "no trigger". It is:

> **An intake-only trigger with no sweep, and a whole second intake path that never started.**

### 2.2 The one fact I could not verify, stated plainly

The defect path is *wired*. Whether it has ever *run* is a runtime question. I did not start the
server (Docker is live and out of bounds for this lane), so:

> **I make no claim that triage has ever dispatched.** The first task of the implementation lane is
> to establish it from the durable record — `SELECT jobType, state, count(*) FROM job GROUP BY 1,2`
> — before anything in §3 is built. If no `triage_defect` job has ever left `queued`, the defect
> path has a *runtime* defect this design does not cover and it must be opened as its own item.

---

## 3. Answer 1 — Trigger shape: **both**, and the sweep is the one that matters

**Answer: two triggers, one operation, one dedupe key — the baseline lane's shape, because it is
the only shape in this repository that has been built, reviewed and shipped.**

| Trigger | Where | What it is for |
|---|---|---|
| **Intake** | `createDefect` (already there; keep) and `createFeatureWorkItem` (new) | Immediate. Latency, and the human's confirmation that the request was *received into the pipeline*. |
| **Periodic sweep** | new `DefectTriageSweep` on the existing 30 s tick | **The actual fix.** Covers intake-time failure, the 18 stranded jobs, and anything filed before this feature existed. |

**Weighing, explicitly:**

- *Intake-only* strands work on the first exception. `createDefect` performs ~8 durable writes before
  the enqueue; any of them can throw, and there is no retry. It also cannot repair history — the 18
  orphaned jobs prove the failure is real and is already on disk.
- *Sweep-only* adds up to one tick of latency (≤30 s) to every defect and every feature. That is the
  price of correctness, and it is the same price the baseline lane already pays.
- *Both* is cheap **because both are the same function**. §4 defines `ensureWorkEntry`; intake calls
  it, the sweep calls it, and idempotency is a property of the function rather than a convention
  two callers must agree on.

**Why this is not the onboarding case.** The baseline sweep needed an *acquisition* to build its
dedupe key, and that acquisition wrote to the credential row — which is why it livelocked against
itself in production (41 passes, 22 incidents, credential version 1→59, documented at
`baseline_onboarding_sweep.dart:577-599`). **The triage sweep has no equivalent hazard**: it reads
defect rows and work items, and its only write is a conditional enqueue guarded by
`enqueueIfAbsent`'s transaction + the store's active-dedupe constraint. It cannot livelock because
it has no CAS-bumping side effect. That asymmetry is the reason the same shape is safe here, and an
implementer must not add an acquisition to this sweep.

---

## 4. The design: `ensureWorkEntry`

One idempotent operation. Both triggers call it. It is the whole design.

```dart
// apps/server/lib/src/triage/work_entry.dart   (NEW)

/// One decision about one piece of work, by the trigger that made it.
sealed class WorkEntryDecision {
  const WorkEntryDecision();
  final String? code;   // greppable; null only for Enqueued
  final String? reason; // operator-facing; never carries credential material
}

final class WorkEntryEnqueued extends WorkEntryDecision {
  const WorkEntryEnqueued(this.jobId) : super();
  final String jobId;
}

final class WorkEntrySkipped extends WorkEntryDecision {
  const WorkEntrySkipped(this.code, this.reason);
  final String code;
  final String reason;
}

/// Reason codes. Every one of them is a decision someone can grep for, which is
/// the entire point — "the sweep ran and found nothing" and "the sweep is not
/// running" produce the same counts and must not produce the same log line.
abstract final class WorkEntrySkipCodes {
  /// A non-terminal triage job already exists for this work item.
  static const String triageAlreadyActive = 'TRIAGE_ALREADY_ACTIVE';

  /// The work item's product is not in `governed`. See §7 — and HD-1.
  static const String productNotGoverned = 'PRODUCT_NOT_GOVERNED';

  /// No consumer exists for this category. See §6. EXTERNAL_* — this is a
  /// missing runtime, not a human refusing to act.
  static const String noConsumerForCategory = 'EXTERNAL_WORK_ENTRY_CONSUMER';

  /// The item is in a state no lane claims; the graph is the authority.
  static const String notTriagableState = 'NOT_TRIAGABLE_STATE';

  /// A non-terminal job of a DIFFERENT type holds the item.
  static const String otherLaneOwnsItem = 'OTHER_LANE_OWNS_ITEM';
}
```

```dart
class WorkEntryTrigger {
  WorkEntryTrigger({
    required this.workflowStore,
    required this.workflowEngine,
    required this.productRegistryEngine,
    required this.jobQueue,
    this.log,
  });

  /// ## THE OPERATION
  ///
  /// Idempotent in the strong sense: calling it N times on an unchanged durable
  /// record produces exactly one job, and calling it after a partial run resumes
  /// rather than restarts. Read-before-create plus a per-hop idempotency key on
  /// every transition, exactly as `DefectTriageWorkItemProvisioner` and
  /// `DesignRemediationWorkItemProvisioner` already do.
  ///
  /// ## WHY THE CATEGORY ROUTING LIVES HERE AND NOT IN THE SCHEDULER
  ///
  /// `RunnableWorkEvaluator.evaluate` never reads `item.category`. The
  /// WorkItem-scoped `Scheduler` is **category-blind**: any work item at
  /// `designNotRequired` is classified `runnable` under `triageDefectDefinition`
  /// and receives a `triageDefect` job. That is load-bearing for §6 — routing is
  /// therefore decided by *not walking* an item into an entry state, not by
  /// filtering at dispatch. Deciding it here is the only place that is honest.
  Future<WorkEntryDecision> ensureWorkEntry({
    required WorkItem item,
    required WorkItemCategory category,
  }) async {
    final workItemId = item.workItemId;

    // 1. Product-scoped guard, BEFORE anything is written. Cheap: two indexed
    //    reads, no acquisition. Mirrors `BaselineOnboardingSweep`'s
    //    `_activeOnboardingJob` ordering — the expensive question is never asked
    //    while the cheap one already answers it.
    final active = await _activeTriageJob(workItemId);
    if (active != null) {
      return WorkEntrySkipped(
        WorkEntrySkipCodes.triageAlreadyActive,
        'job ${active.jobId} is still ${active.state.wire}; no second triage job '
        'was created.',
      );
    }

    // 2. Routing. Category decides which lane may claim the item — see §6.
    final route = _routeFor(category);
    if (route == null) {
      return WorkEntrySkipped(
        WorkEntrySkipCodes.noConsumerForCategory,
        'category ${category.name} has no triage consumer in shipit-platform. '
        'Recorded as ${WorkEntrySkipCodes.noConsumerForCategory}; it is a '
        'missing runtime, not a human decision.',
      );
    }

    // 3. Walk the item to an ENTRY STATE of the definition its route names.
    //    `transition` is idempotent under the supplied key, so a crash between
    //    any two hops replays to the same state rather than re-running.
    final ready = await _walkTo(route.entryState, item);

    // 4. Enqueue. `enqueueIfAbsent` is one transaction with the store's
    //    active-dedupe constraint behind it; a concurrent second caller loses
    //    the constraint and is resolved to the winning job, not a duplicate.
    final result = await jobQueue.enqueueIfAbsent(
      workItemId: ready.workItemId,
      definition: route.definition,
      dedupeKey: route.dedupeKey(ready, route.definition),
      instruction: route.instruction(ready, route.definition),
    );
    return result.created
        ? WorkEntryEnqueued(result.job.jobId)
        : WorkEntrySkipped(
            WorkEntrySkipCodes.triageAlreadyActive,
            'a concurrent caller won this dedupe key; job '
            '${result.job.jobId} is the one that exists.',
          );
  }
}
```

**One dedupe key, one builder — the baseline lane's hard-won rule.**
`route.dedupeKey` **is** `triageDefectDedupeKey` (`packages/scheduler/lib/src/triage_defect.dart:17`).
It is imported, not re-spelled. The intake caller and the sweep therefore cannot drift, and the
already-persisted `'{workItemId}:triage_defect'` keys in the live database keep matching — a change
to the key format would orphan every job already written.

### Route table — one row today

```dart
class WorkEntryRoute {
  const WorkEntryRoute({
    required this.definition,
    required this.entryState,
    required this.dedupeKey,
    required this.instruction,
    required this.walkUp,
  });
  final JobDefinition definition;
  final WorkItemState entryState;
  final DedupeKeyBuilder dedupeKey;
  final InstructionBuilder instruction;
  final List<WorkItemState> walkUp; // e.g. [planning, planned, designNotRequired]
}

/// ## THE ROUTE TABLE IS THE ROUTING DECISION, IN ONE PLACE
///
/// `WorkItemCategory` has seven values (`platform_contracts/.../work_item_category.dart`).
/// Exactly one is routed. The other six are not "unsupported because we forgot";
/// they are unsupported because **no consumer exists for them**, and that is a
/// recorded dependency, not a silent skip. See §6 and `EXTERNAL_WORK_ENTRY_CONSUMER`.
const Map<WorkItemCategory, WorkEntryRoute> _routes = {
  WorkItemCategory.feature: WorkEntryRoute(
    definition: triageDefectDefinition,
    entryState: WorkItemState.designNotRequired,
    dedupeKey: triageDefectDedupeKey,
    instruction: triageDefectInstruction,
    walkUp: [WorkItemState.planning, WorkItemState.planned,
             WorkItemState.designNotRequired],
  ),
  // `bugfix`/`refactor`/`docs`/`chore`/`security`/`performance` are ABSENT, and
  // their absence is deliberate and recorded. Adding a route without adding its
  // consumer is the failure this table exists to make impossible to write.
};
```

> **Correction to my own table above.** The route table maps `WorkItemCategory.feature` — but a
> *defect's* triage work item is created with `category: triageWorkItemCategory`, **not** `feature`
> (`lane_a_defect_triage_work_item.dart:133`, whose own comment notes this is unchanged from
> previous behaviour and that *"changing it is a domain decision, not wiring"*). The route table
> must therefore key on **the intake that created the item**, not on `item.category`, because the
> defect triage item's category is not a routing signal and must not be repurposed into one.
>
> **Revised design:** `ensureWorkEntry` takes an explicit `WorkEntryKind` (`defectTriage`,
> `featureIntake`) supplied by the caller, *not* a category read off the row. Routing is a
> property of **which intake opened the file**, which is knowable and stable; `category` is a
> domain field that two intake paths already disagree about and that a human decision (HD-2)
> governs. **The diff in §11 reflects this corrected form.**

---

## 5. Answer 3 — The scheduler seam: **unchanged. No baseline-class change is needed.**

The dispatch asked me to assess rather than assume. Assessed:

| Baseline needed a product-scoped dispatcher because… | Does it apply here? |
|---|---|
| onboarding jobs have **no `WorkItem`** — filed under synthetic `onboarding-<productId>` | **No.** `DefectTriageWorkItemProvisioner` persists a real row *before* enqueue (`lane_a…:124`), and features get one from `createWorkItem`. `_eligibleRunnableJobs`' `byId[job.workItemId] == null → skip` (`scheduler.dart:305-309`) does not bite. |
| the eligibility question is **product-scoped**, answered from the registry | **No.** It is answered from a `WorkItem`, which is exactly what `RunnableWorkEvaluator` asks. |
| the baseline lane runs a **deterministic platform operation**, not an agent | **No.** Triage runs an agent through the real `LocalWorker` + `OpencodeAdapter` composition. |

**Verdict: `Scheduler` is used exactly as constructed today. Not one line of `packages/scheduler`
changes.** The only scheduler-side fact the design depends on is P-3 (it already enqueues), which is
a *reason to expect* behaviour, not a change.

**But the seam has a property that must be stated, because it is a trap:**

> **`RunnableWorkEvaluator` never reads `WorkItemCategory`.** The triage `Scheduler` will enqueue a
> `triageDefect` job for **any** work item that reaches `designNotRequired`, of any category, for
> any product. Today that is harmless only because exactly two kinds of item reach that state
> (`defect-{id}` triage items and `design-remediation-{id}` items — and the latter park at
> `planned`, which is *not* an entry state, precisely because lane E walked them to `designRequired`
> once and learned).
>
> **The design's routing therefore works by NOT walking an item into an entry state (§4, §6), not
> by filtering at dispatch.** A future change that moves an unrelated item to `designNotRequired`
> will silently triage it as a defect, and nothing will complain. That is recorded as **D-4**
> (§8) and is the strongest argument in this revision for keeping `work_entry.dart` as the single
> place that walks anything.

---

## 6. Answer 4 — Features vs defects: **two paths. A feature consumer does not exist, and I am not going to pretend one does.**

The dispatch asked me to read lane A and lane E and say which. Read; here is the evidence.

**Lane A is structurally defect-bound, not merely defect-flavoured.** Three independent
structural dependencies, each sufficient on its own:

1. **`TriageResult.defectId` is non-nullable** (`platform_contracts/.../triage_result.dart:36`).
   `_parseTriageResult` must supply one, and the only source is
   `_extractDefectId(job.workItemId)`, which strips a `defect-` prefix
   (`triage_processor.dart:275-281`). A feature id `WI-feature-1789…` has no such prefix, so it
   **falls through and returns the entire work-item id as a "defect id."**
2. **`processCompletedTriageJob` then calls `defectStore.readDefect(<that>)`**
   (`triage_processor.dart:118`). For a feature item there is no `defect` row, it raises
   `DefectNotFoundException`, and the processor **returns early at `:128`** — before the defect
   update, before clarifications, before lane E.
3. **`triage_result` and `defect_clarification` have no foreign key to `work_item`**, so a feature
   triage result is not rejected by the database — it is *accepted and meaningless*. A `TriageResult`
   whose `defectId` is `WI-feature-…` is a fact-shaped lie that the schema will happily hold.

**What that means concretely:** routing a feature work item into `triageDefectDefinition` would
produce a `queued → dispatched → succeeded` job whose outcome is then thrown away at
`readDefect`. **The job would look perfectly healthy and nothing would happen.** That is the exact
silent-no-op class this whole work item exists to close — reintroduced at the seam rather than
eliminated.

**So: one path is not sufficient, and the honest answer is that the feature path is HALF built.**

### What exists for features, and what does not

| Piece | Exists? | Where |
|---|---|---|
| Intake endpoint | **yes** | `intake_endpoints.dart:20` |
| Service write (work item + `workIntake` direction, one transaction) | **yes** | `control_plane_service.dart:766-800` |
| Client UI (create + list) | **yes** | `features/reports/create_feature_request_page.dart`, `feature_request_list_page.dart` |
| Trigger | **no** | this revision |
| Consumer for a feature triage result | **NO** | — |
| Lane E equivalent | **no** | lane E is *defect*-driven (`lane_e…:72` keys on `designRemediationWorkItemId(defectId)`) |

### The honest dependency — mirroring lane E exactly

`lane_e_design_remediation_work_item.dart` records `EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY` with
`designGovernanceRuntime = 'unavailable'`, and its comment is precise:

> *`unavailable` means the runtime does not exist in shipit-platform, not that a human declined to run it.*

This revision does the same for the missing consumer, and **stops the walk at `planned`**, which is
the last state reachable without a consumer:

```dart
// apps/server/lib/src/triage/work_entry.dart   (NEW)
const String workEntryConsumerKey = 'workEntryConsumer';
const String workEntryFeatureIntakeKey = 'featureIntake';
const String externalWorkEntryConsumerDependency =
    'EXTERNAL_WORK_ENTRY_CONSUMER_DEPENDENCY';
const String workEntryConsumerUnavailable = 'unavailable';
```

`planned → designNotRequired` needs **no** design artifact (`work_item_transitions.dart:31-33`,
`actorAllowed([orchestrator])` only) — which is precisely why walking one hop further would be the
tempting, dishonest move, and why `designContractExists()`'s earlier absence was caught for lane E.
The gap here is not a guard; it is a consumer. **There is no guard for "does anything read this."**

**Consequence, stated so no one is surprised:** features will be *recorded, triaged-in-name-only
and parked*. Their UI-visible state will be `planned` with a recorded reason. That is a **worse
user-visible outcome than today** (today: `draft`), and it is honest rather than silent. §10
concedes this; HD-1 asks the human whether parking is acceptable or whether intake should refuse.

---

## 7. Answer 2 — An ungoverned product: **accept at intake, gate the walk** — with one part escalated

### The contract text already answers half of it

`ProductState` (`platform_contracts/lib/src/enums/product_state.dart:23-53`) says:

- `governed` — *"A baseline is accepted. **Work may be dispatched for this product.**"*
- `paused` — *"Governed, but **the scheduler will not dispatch new work.**"*
- `offboarded` — *"**No new work can be created or dispatched.**"*

So the contract already says what this dispatch calls an open question. **And nothing enforces
it.** `RunnableWorkEvaluator` receives a `WorkItem` and never resolves `item.productId`; there is no
product-state gate anywhere in `Scheduler.tick`, `RunnableWorkEvaluator`, or `LocalWorker`. Recorded
as **D-2** (§8).

### The decision I am authorised to make: gate the **walk**, never the **intake**

| | Defects | Features |
|---|---|---|
| Refuse at intake? | **No** — it would break the live bug-reporting path | **No** — `createFeatureWorkItem` already raises a `workIntake` direction for a human; that direction **is** the human gate |
| Enqueue and fail terminally? | **No** — a product mid-onboarding would permanently lose triage | **No** — same, and it manufactures a `failed` job per tick |
| **Accept, gate the walk on `governed`** | **yes** | **yes** |

**Justification.** Refusing at intake converts a *product-lifecycle* condition into a *request
rejection*: the operator files a legitimate bug report and is told no, because the platform has not
finished its own onboarding. For defects that is plainly wrong — the report is about reality, not
about scope, and a governed product would be *required* to accept one. Terminal failure is worse
still: it burns the dedupe key's budget (`maxAttempts: 2`) and the work item is then permanently
un-retryable, so the "wait" becomes "give up". Waiting is correct: the product *will* become
governed, the sweep will notice, and the work is dispatched then. That is the same reasoning the
baseline sweep uses for `baselineBlocked` (`baseline_onboarding_sweep.dart:307-316`).

```dart
// apps/server/lib/src/triage/work_entry.dart   (NEW)
// Called from ensureWorkEntry, BEFORE the walk and before the enqueue.
Future<ProductState> _productStateOf(String productId) async =>
    productRegistryEngine.readProduct(productId).state.canonical;
```

`canonical` is used, not the raw value, for the reason `BaselineOnboardingSweep.sweepStates` gives
(`:336-339`): a row persisted as the parse-only legacy `draft` must be read as what it means.

### What I am **not** authorised to decide → **HD-1**

Two things in this area are product/governance decisions, not design choices, and I am escalating
both rather than picking.

**HD-1(a) — Does a *human-reported defect* require a `governed` product before it may be triaged?**

Today `createDefect` calls `_requireRegisteredProduct` (`control_plane_service.dart:923`), which
checks **registration only** — and then enqueues triage immediately, for a product in any state,
including `registered` and `offboarded`. Against the enum's own text that is a live contradiction,
and this revision's governance gate would newly *enforce* it — i.e. I would be changing shipped,
working behaviour on a path nobody asked me to change.

My reading is that it should **stand** — safety/reporting work about reality should not be gated on
whether the platform finished onboarding — but that is a governance-model call, and enforcing it
retroactively to defects is a product decision with human authority. **Not decided here.**

**HD-1(b) — For features: park at `planned` with a recorded reason, or refuse the submission?**

Parking is truthful and loses nothing. Refusing is honest at the moment of submission ("this product
is not governed, so we are not accepting feature work yet") but rejects a human's request over a
platform-internal condition, and it is a **user-visible behaviour change on a screen with listeners**
(`feature_request_list_page.dart`, `create_feature_request_page.dart` — P-4). That is a product
decision about what the Reports screen means. **Not decided here.**

> **HD-1 does not block implementation of the defect half.** It blocks the *feature* half's
> behaviour and Gate D4. §11's lane plan sequences accordingly.

---

## 8. Answer 5 — Idempotency and restart-safety

**Key.** `'${item.workItemId}:${definition.jobType.wire}'` — imported from
`packages/scheduler/lib/src/triage_defect.dart:17`. **Not re-spelled anywhere.** Every job already
persisted under this format keeps matching; changing the format would orphan all of them, and the
already-persisted `defect-{id}:triage_defect` keys are what the sweep will find.

**Three layers of idempotency, each sufficient, none relying on the next:**

| Layer | Mechanism | Failure it absorbs |
|---|---|---|
| **Work item** | read-before-create + fixed id `defect-{defectId}` | two concurrent intakes → one item |
| **Each transition** | `DurableWorkflowEngine.transition(idempotencyKey:)` — a fixed per-hop key per work item (`triage-intake:planning` etc., `lane_a…:31-33`) | crash mid-walk-up → replay returns the accepted outcome, does not re-run |
| **Job** | `JobQueue.enqueueIfAbsent` in one transaction + `DuplicateActiveJobException` re-resolved to the winner (`job_queue.dart:84-90`) | two sweeps, or a sweep and an intake, at the same instant |

**Restart mid-dispatch — the one worth being precise about.** There are three windows, and they are
*not* symmetric with the baseline lane:

| Window | Durable state on restart | Recovery | Safe to re-run? |
|---|---|---|---|
| Before the claim | `queued` | next sweep/tick takes it | **yes** — `enqueueIfAbsent` finds it |
| After the claim, before the lane finishes | `running` + claim | `Scheduler.tick` step 1 lease recovery → `_reconcileClaim` (`scheduler.dart:205-216`) | **yes** — `Scheduler._reconcileClaim` consults the **worker store** and either adopts the finished execution or renews the lease rather than double-executing |
| After dispatch, before the outcome is recorded | `running` + `executionReference` | same as above | **yes, and provably so** |

The third row is where this design is *stronger* than the baseline lane, and the difference is worth
stating: `BaselineProductDispatcher` requeues and **re-runs the lane**, which is safe only because
baseline derivation is a pure function of a pinned revision (`baseline_dispatch.dart:212-236`). Triage
is **not** a pure function — it is an LLM call. Its safety comes from a *different* mechanism:
`Scheduler._reconcileClaim` reads `job.executionReference` and asks
`_workerStore.readWorkerExecution(ref.workerExecutionId)`; if the execution is still alive it
**renews the lease instead of starting a second one**, and if it ended it adopts its result
(`scheduler.dart:489-524`). At-least-once for the *claim*, exactly-once for the *execution*.

> **The residual, named honestly:** if the worker store loses the execution record **and** the lease
> has expired, `_reconcileClaim` requeues and a second execution occurs. The guard against a
> duplicate *triage result* is then `TriageResult.resultId = 'tr-${job.jobId}'` — stable per job —
> so a second execution produces a `saveTriageResult` CAS conflict rather than a second result.
> That is a real property, not a hope, but it is a property of one `saveTriageResult` and **no
> implementer may describe triage as exactly-once.**

**Sweep pass non-overlap.** `BaselineOnboardingSweep.run()` guards re-entrancy because
`Timer.periodic` does not await its callback (`baseline_onboarding_sweep.dart:355-410`). The triage
sweep is on the **same timer** and takes the same shape; the guard is copied, not reinvented, and
`overlappedPasses` is reported even when zero — for the same stated reason: a dropped tick and an
idle pass print the same counts otherwise.

---

## 9. Answer 6 — Product-agnosticism

**Design rule, enforceable as a grep gate — same form the baseline lane used:**

> No file under `apps/server/lib/src/triage/` may contain `shipit`, `SHIPIT_`, or a hardcoded
> filesystem path.

| Property | This design |
|---|---|
| Product identity | read from `WorkItem.productId` at call time; **no default, no fallback** |
| Product state | resolved from the registry; no env var, no literal |
| Dedupe key | derived from `workItemId`; carries no product identity of its own |
| Instruction | `triageDefectInstruction` reads `item.metadata`; carries no product name |
| Sweep predicate | over `DefectStore.listDefects()` / `WorkflowStore.readAllWorkItems()` — no registry scan, no hardcoded id |

**Two pre-existing product-agnosticism defects this revision does NOT fix and must not be copied:**

| # | Defect | Evidence |
|---|---|---|
| **A-1** | The triage **execution context is not product-scoped**. `SchedulerWorkload.repositoryPath` is one value from one env var resolved once at startup (`server.dart:182`, `:337`, `:358-366`), so **every triage job for every product runs in a worktree of the same repository**. | `server.dart` `_resolveTriageSource` |
| **A-2** | `defectTriageBucketProductId = 'defects'` is a **shared bucket**, and a defect with no resolvable `affectedWorkItemId` is filed under it (`lane_a…:8-17`). It is not a product and no product id is invented. | `lane_a_defect_triage_work_item.dart:17` |

A-1 is the load-bearing one: **per-product source resolution would require exactly the
product-scoped scheduler change the baseline lane made**, and this revision deliberately does not
make it (§5). An implementer must therefore not write a test or a log line implying triage reads a
product's own source.

---

## 10. Risk assessment — **Level 2**

`risk_level: 2`

- **It changes a user flow.** A submitted feature request currently sits at `draft` for ever; after
  this revision it moves to `planned` with a recorded reason, and defects gain a recovery path. The
  Reports screen and the feature-request list have listeners (P-4). That is Level 2 by the
  taxonomy's own words: *"Change to user flow, interaction pattern, or feature-level UX that affects
  user behavior."*
- **It changes what runs autonomously.** A `triageDefect` job is an LLM invocation against a real
  worktree. Making that path restart-safe makes it *reachable*, which is the point, and is not
  trivial.
- **Level 2 ⇒ `HUMAN_DECISION_REQUIRED` at Gate D4.** That gate is where HD-1 lands, so the risk
  level and the escalation are the same fact seen twice.

**Level 3 was considered and rejected.** Level 3 is *"core workflow, navigation structure, or
information architecture affecting multiple features or user mental models."* None of the three
holds: no navigation changes, no IA changes, one feature. **Level 1 was considered and rejected**
because it *"does not affect user flow"* — and this does.

**A reviewer may reasonably disagree in either direction, and should say so.** If you read the
`governed` gate as a governance-model change (§7), Level 3 is defensible; I place it at 2 because
this revision changes *no* guard, *no* evidence kind, *no* transition table, and *no* human gate —
every one of which was the baseline lane's Level 3 justification.

**`implementation_feasibility: HIGH`.** Every mechanism exists: `triageDefectDefinition`,
`triageDefectDedupeKey`, `triageDefectInstruction`, `Scheduler.tick`'s existing enqueue step,
`DefectTriageWorkItemProvisioner`, `transition(idempotencyKey:)`, `enqueueIfAbsent`,
`BaselineOnboardingSweep` as the literal template, `lane_e` as the literal dependency template.
The two new files are additive Dart. **No schema change, no migration, no generated code, no new
dependency, and not one line of `packages/scheduler`.**

**`design_system_compliance: PASS` / `ux_accessibility_score: PASS` by non-applicability** — with
the concession stated rather than hidden: this revision changes **no** view, token, component or
route, but it **does** change what two existing screens display (a feature request's state, and
whether a defect appears classified). No WCAG criterion is engaged; the reviewer should confirm
that a `planned`-state chip with a reason is legible in the existing token set rather than assuming
it.

---

## 11. Proposed implementation — diff as TEXT

> Nothing below is applied. This is the text an implementation lane would implement.

### 11.1 `apps/server/lib/src/triage/work_entry.dart` (NEW)

```dart
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart' show ProductRegistryEngine;
import 'package:scheduler/scheduler.dart'
    show
        DedupeKeyBuilder,
        InstructionBuilder,
        JobDefinition,
        JobQueue,
        JobStore,
        triageDefectDefinition,
        triageDefectDedupeKey,
        triageDefectInstruction;
import 'package:workflow_engine/workflow_engine.dart' show DurableWorkflowEngine;
import 'package:workflow_store/workflow_store.dart' show WorkflowStore;

// ---------------------------------------------------------------------------
// The dependency that does not exist yet. See design-revision.md §6.
//
// `unavailable` means the runtime does not exist in shipit-platform, NOT that a
// human declined to run it. It must never be rendered as "this request failed".
// ---------------------------------------------------------------------------
const String workEntryConsumerKey = 'workEntryConsumer';
const String externalWorkEntryConsumerDependency =
    'EXTERNAL_WORK_ENTRY_CONSUMER_DEPENDENCY';
const String workEntryConsumerUnavailable = 'unavailable';
const String workEntryBlockedByKey = 'blockedBy';

/// Which intake opened a work item. NOT `WorkItemCategory`.
///
/// A defect's triage item is created with `triageWorkItemCategory` and a
/// feature's with `WorkItemCategory.feature`; `category` is a domain field two
/// intakes already disagree about, and repurposing it as a routing signal would
/// be a domain decision nobody made. The intake that created the file knows
/// which lane owns it, and that is knowable and stable.
enum WorkEntryKind {
  /// `DefectTriageWorkItemProvisioner` opened `defect-{defectId}`.
  defectTriage,

  /// `createFeatureWorkItem` opened `WI-feature-{...}`.
  featureIntake,
}

/// Metadata recorded on a work item parked because nothing consumes it.
Map<String, dynamic> workEntryExternalDependencyMetadata() => <String, dynamic>{
  workEntryConsumerKey: workEntryConsumerUnavailable,
  workEntryBlockedByKey: externalWorkEntryConsumerDependency,
};

class WorkEntryTrigger {
  WorkEntryTrigger({
    required this.workflowStore,
    required this.workflowEngine,
    required this.productRegistryEngine,
    required this.jobStore,
    this.log,
  }) : _queue = JobQueue(store: jobStore);

  final WorkflowStore workflowStore;
  final DurableWorkflowEngine workflowEngine;
  final ProductRegistryEngine productRegistryEngine;
  final JobStore jobStore;
  final JobQueue _queue;
  final void Function(String event, Map<String, dynamic> data)? log;

  /// The two lane-defining identities, kept here because the sweep needs them
  /// and they must not be re-derived. `lane_a_defect_triage_work_item.dart:25`
  /// documents that this exact shape is load-bearing in three places.
  static String triageWorkItemIdForDefect(String defectId) => 'defect-$defectId';

  /// Idempotency keys for the walk-up. One per hop, constant per work item, so
  /// a crash between any two hops replays to the accepted outcome.
  static const String _planningKey = 'work-entry:planning';
  static const String _plannedKey = 'work-entry:planned';
  static const String _designNotRequiredKey = 'work-entry:designNotRequired';

  Future<WorkEntryDecision> ensureWorkEntry({
    required WorkItem item,
    required WorkEntryKind kind,
  }) async {
    final workItemId = item.workItemId;

    // --- 1. CHEAP GUARD FIRST -------------------------------------------------
    // `listJobsForWorkItem` is one indexed read. Nothing below it is written
    // until this returns null. Mirrors `_activeOnboardingJob`'s ordering.
    final active = await _activeTriageJob(workItemId);
    if (active != null) {
      return WorkEntrySkipped(
        WorkEntrySkipCodes.triageAlreadyActive,
        'job ${active.jobId} is still ${active.state.wire}; nothing was written.',
      );
    }

    // --- 2. GOVERNANCE GATE ---------------------------------------------------
    // Reads `canonical`, not the raw state: a row persisted as the parse-only
    // legacy `draft` must be read as `registered` (see
    // `BaselineOnboardingSweep.sweepStates`'s reason).
    final product = await productRegistryEngine.readProduct(item.productId);
    if (product.state.canonical != ProductState.governed) {
      return WorkEntrySkipped(
        WorkEntrySkipCodes.productNotGoverned,
        'product ${item.productId} is ${product.state.canonical.wire}, not '
        'governed, so no work may be dispatched for it (ProductState). The '
        'request is NOT rejected and the job is NOT failed: the sweep retries '
        'when the product becomes governed.',
      );
    }

    // --- 3. ROUTING -----------------------------------------------------------
    // Features have no consumer (design-revision.md §6). The walk below stops at
    // `planned`; the item is annotated so the gap is greppable rather than
    // inferred from a state someone might later walk further.
    if (kind == WorkEntryKind.featureIntake) {
      await _walkToPlanned(item, featureRef: item.workItemId);
      await _annotateExternalDependency(item, featureRef: item.workItemId);
      return WorkEntrySkipped(
        WorkEntrySkipCodes.noConsumerForCategory,
        'no triage consumer exists for a feature work item; recorded as '
        '$externalWorkEntryConsumerDependency. `unavailable` means the runtime '
        'does not exist in shipit-platform, not that a human refused.',
      );
    }

    // --- 4. WALK TO AN ENTRY STATE OF triageDefectDefinition ------------------
    final ready = await _walkToDesignNotRequired(item);

    // --- 5. ENQUEUE -----------------------------------------------------------
    // The key and the instruction are the canonical builders, imported. Never
    // re-spelled: the format is persisted on every historical job and the
    // sweep matches on it.
    final result = await _queue.enqueueIfAbsent(
      workItemId: ready.workItemId,
      definition: triageDefectDefinition,
      dedupeKey: triageDefectDedupeKey(ready, triageDefectDefinition),
      instruction: triageDefectInstruction(ready, triageDefectDefinition),
    );
    return result.created
        ? WorkEntryEnqueued(result.job.jobId)
        : WorkEntrySkipped(
            WorkEntrySkipCodes.triageAlreadyActive,
            'a concurrent caller won this dedupe key; job '
            '${result.job.jobId} is the one that exists.',
          );
  }

  /// Resuming from wherever a prior partial run left it — never restarting.
  Future<WorkItem> _walkToDesignNotRequired(WorkItem item) async {
    var current = item;
    final featureRef = current.featureRef ?? current.workItemId;

    if (current.state == WorkItemState.draft) {
      current = await workflowEngine.transition(
        workItemId: current.workItemId,
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
        actor: _orchestrator,
        context: {'featureRef': featureRef, 'workEntry': true},
        idempotencyKey: _planningKey,
      );
    }
    if (current.state == WorkItemState.planning) {
      current = await workflowEngine.transition(
        workItemId: current.workItemId,
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        actor: _orchestrator,
        context: {'featureRef': featureRef, 'workEntry': true},
        idempotencyKey: _plannedKey,
      );
    }
    if (current.state == WorkItemState.planned) {
      current = await workflowEngine.transition(
        workItemId: current.workItemId,
        to: WorkItemState.designNotRequired,
        trigger: TransitionTrigger.systemEvent,
        actor: _orchestrator,
        context: {'featureRef': featureRef, 'workEntry': true},
        idempotencyKey: _designNotRequiredKey,
      );
    }
    if (current.state != WorkItemState.designNotRequired &&
        current.state != WorkItemState.designApproved) {
      // Someone else owns this item. The graph is the authority; force nothing.
      // Surfaced loudly: the defect will not be triaged until a human moves it.
      log?.call('work_entry.not_triageable', {
        'workItemId': current.workItemId,
        'state': current.state.wire,
      });
    }
    return current;
  }

  Future<WorkItem> _walkToPlanned(WorkItem item, {required String featureRef}) async {
    var current = item;
    if (current.state == WorkItemState.draft) {
      current = await workflowEngine.transition(
        workItemId: current.workItemId, to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent, actor: _orchestrator,
        context: {'featureRef': featureRef, 'workEntry': true},
        idempotencyKey: _planningKey);
    }
    if (current.state == WorkItemState.planning) {
      current = await workflowEngine.transition(
        workItemId: current.workItemId, to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent, actor: _orchestrator,
        context: {'featureRef': featureRef, 'workEntry': true},
        idempotencyKey: _plannedKey);
    }
    return current;
  }

  Future<void> _annotateExternalDependency(
    WorkItem item, {
    required String featureRef,
  }) async {
    if ((item.metadata?[workEntryBlockedByKey]) == externalWorkEntryConsumerDependency) {
      return; // already recorded; a replay is a read
    }
    await workflowStore.saveWorkItem(
      item.copyWith(
        metadata: <String, dynamic>{
          ...?item.metadata,
          ...workEntryExternalDependencyMetadata(),
        },
      ),
      expectedVersion: item.version,
    );
  }

  /// Scoped to the WORK ITEM, not to one dedupe key — `onboarding`'s lesson
  /// applied. Filtered by `JobType.triageDefect` so a future job type written
  /// under the same id does not silently block triage for ever.
  Future<Job?> _activeTriageJob(String workItemId) async {
    Job? active;
    for (final job in await jobStore.listJobsForWorkItem(workItemId)) {
      if (job.jobType != JobType.triageDefect) continue;
      if (job.isTerminal) continue;
      if (active == null || !job.createdAt.isBefore(active.createdAt)) active = job;
    }
    return active;
  }

  static const WorkflowActor _orchestrator = WorkflowActor(
    actorId: 'work-entry',
    actorType: ActorType.orchestrator,
  );
}
```

### 11.2 `apps/server/lib/src/triage/defect_triage_sweep.dart` (NEW)

```dart
/// Enqueues triage for defects whose intake-time enqueue did not happen.
///
/// ## WHY A SWEEP, AND WHY IT CANNOT LIVELOCK
///
/// `BaselineOnboardingSweep` livelocked in production because it resolved a
/// pinned revision — a real SSH clone that calls `CredentialKeyService
/// .verifyAccess`, writing the credential row twice and bumping its `version` —
/// on every pass, so each pass invalidated the next pass's CAS (41 passes,
/// 22 incidents, credential version 1->59; `baseline_onboarding_sweep.dart:
/// 577-599`).
///
/// THIS SWEEP HAS NO ACQUISITION. It reads defect rows, work items and product
/// rows, and its only write is a conditional enqueue. It cannot invalidate its
/// own precondition. An implementer who adds a clone here reintroduces the
/// livelock.
///
/// ## THE PREDICATE, AND EVERY CONJUNCT
///
/// ```text
///   enqueue triage  <==>  defect.status is triagable
///                   AND  no non-terminal triageDefect job for defect-{defectId}
///                   AND  the defect's product is `governed`
/// ```
class DefectTriageSweep {
  DefectTriageSweep({
    required this.defectStore,
    required this.trigger,
    this.log,
  });

  final DefectStore defectStore;
  final WorkEntryTrigger trigger;
  final void Function(String event, Map<String, dynamic> data)? log;

  /// Product-agnostic: statuses, not product names or ids.
  static const Set<DefectStatus> triagableStatuses = {
    DefectStatus.reported,
    DefectStatus.triaging,
    DefectStatus.needsClarification,
  };

  bool _running = false;

  /// `run` is deliberately NOT `async`; see `BaselineOnboardingSweep.run()`'s
  /// doc for why the re-entrancy guard has to be taken in the caller's turn.
  Future<DefectTriageSweepResult> run() {
    if (_running) {
      log?.call('work_entry.sweep.completed', const {
        'considered': 0, 'enqueued': 0, 'skipped': 0,
        'overlappedPasses': 1, 'code': 'SWEEP_PASS_OVERLAPPED',
      });
      return Future<DefectTriageSweepResult>.value(
        const DefectTriageSweepResult(
            considered: 0, enqueued: const [], skipped: const [],
            overlappedPasses: 1),
      );
    }
    _running = true;
    return _runPass().whenComplete(() => _running = false);
  }

  Future<DefectTriageSweepResult> _runPass() async {
    final enqueued = <String>[];
    final skipped = <WorkEntrySkipped>[];
    var considered = 0;

    for (final defect in await defectStore.listDefects()) {
      if (!triagableStatuses.contains(defect.status)) continue;
      considered++;
      final workItemId =
          WorkEntryTrigger.triageWorkItemIdForDefect(defect.defectId);
      WorkItem? item;
      try {
        item = await trigger.workflowStore.readWorkItem(workItemId);
      } on WorkItemNotFoundException {
        // The defect predates the provisioner (or its item was lost). This is
        // exactly the orphan class the sweep exists for; rebuilding it is the
        // provisioner's job and is a separate call, recorded, never invented.
        skipped.add(WorkEntrySkipped(
          WorkEntrySkipCodes.workItemMissing,
          'no work item at $workItemId; the triage item must be provisioned '
          'before it can be enqueued. Not repaired by guessing.',
        ));
        continue;
      } on Object catch (e, st) {
        // PER-DEFECT ISOLATION: one defect's failure must not abandon the rest.
        log?.call('work_entry.sweep.defect_incident', {
          'defectId': defect.defectId,
          'error': e.toString(),
          'stack': st.toString(),
          'action': 'this defect is untouched; the pass continued',
        });
        continue;
      }

      final decision = await trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.defectTriage,
      );
      switch (decision) {
        case WorkEntryEnqueued():
          enqueued.add(decision.jobId);
        case WorkEntrySkipped():
          skipped.add(decision);
      }
    }

    log?.call('work_entry.sweep.completed', {
      'considered': considered,
      'enqueued': enqueued.length,
      'skipped': skipped.length,
      'overlappedPasses': 0,
    });
    return DefectTriageSweepResult(
      considered: considered,
      enqueued: List.unmodifiable(enqueued),
      skipped: List.unmodifiable(skipped),
    );
  }
}
```

### 11.3 `apps/server/lib/src/services/control_plane_service.dart` (EDIT — 2 hunks)

```dart
// HUNK 1 — feature intake gains the trigger, in the SAME transaction as the
// work item and the direction. All three are one fact: a request whose work
// item exists but whose trigger did not run is exactly the orphan class this
// revision exists to end.
  Future<WorkItem> createFeatureWorkItem({...}) async {
    await _requireRegisteredProduct(productId);
    final now = DateTime.now().toUtc();
    final workItemId = 'WI-feature-${now.microsecondsSinceEpoch}';

    return _db.inTransaction(() async {
      final workItem = await workflowEngine.createWorkItem(
        workItemId: workItemId,
        productId: productId,
        category: WorkItemCategory.feature,
        title: title,
        description: description,
        // `planning -> planned` is guarded by `planningEvidenceProvided()`
        // (work_item_transitions.dart:18-21). A feature request IS its own
        // requirement reference; leaving this null makes the walk-up illegal.
        featureRef: workItemId,
      );

      await humanDirectionStore.createDirection(...);   // unchanged

      // The trigger. `governed`-gated and consumer-gated per design §7/§6;
      // it records why it did nothing rather than failing the request.
      await workEntryTrigger.ensureWorkEntry(
        item: workItem,
        kind: WorkEntryKind.featureIntake,
      );

      return workItem;
    });
  }

// HUNK 2 — one live view over the same stores, like `_triageWorkItemProvisioner`.
  WorkEntryTrigger get workEntryTrigger => WorkEntryTrigger(
        workflowStore: workflowStore,
        workflowEngine: workflowEngine,
        productRegistryEngine: productRegistryEngine,
        jobStore: jobStore,
        log: (event, fields) => logger.info(event, fields),
      );
```

> `createDefect` is **not** modified in the defect path — it already calls
> `_triageWorkItemProvisioner.ensurePersisted` + `enqueueIfAbsent` (P-1). The sweep is what makes
> it robust. Editing it would risk the one path that already works.

### 11.4 `apps/server/lib/server.dart` (EDIT — 1 hunk)

```dart
  // The work-entry sweep, on the SAME timer as the triage tick and the baseline
  // pass, in its OWN try: a triage tick that fails must not prevent work entry
  // from running, and vice versa.
  final defectTriageSweep = DefectTriageSweep(
    defectStore: defectStore,
    trigger: WorkEntryTrigger(
      workflowStore: workflowStore,
      workflowEngine: durableWorkflowEngine,
      productRegistryEngine: ProductRegistryEngine(
        store: baselineRegistryStore,
        humanDecisionStore: PostgresHumanDecisionStore(workflowStore),
      ),
      jobStore: jobStore,
      log: _log,
    ),
    log: _log,
  );

  // …inside the existing Timer.periodic, after the baseline try:
  try {
    final sweep = await defectTriageSweep.run();
    _log('work_entry.tick.completed', {'sweep': sweep.toString()});
  } catch (e, st) {
    _log('work_entry.tick.failed', {
      'error': '$e', 'stack': st.toString(),
      'action': 'work entry is retried on the next tick; nothing else is affected',
    });
  }
```

### 11.5 Tests to be written (TEXT ONLY — not written here)

```
apps/server/lib/src/triage/work_entry_test.dart          (unit, in-memory stores)
apps/server/lib/src/triage/defect_triage_sweep_test.dart  (unit, fake DefectStore)
apps/server/test/integration/work_entry_integration_test.dart
```

### 11.6 Explicitly NOT changed

| Path | Why |
|---|---|
| `packages/scheduler/**` | §5: the seam is used as-is. **A change here is a review-blocking finding.** |
| `apps/server/lib/src/triage/lane_a_defect_triage_work_item.dart` | it works; changing it risks the live path |
| `apps/server/lib/src/triage/triage_processor.dart` | §6: the consumer gap is *recorded*, not patched around |
| `apps/server/lib/src/endpoints/**`, `apps/control_plane/**` | no wire or UI change (P-4 notwithstanding) |
| `apps/server/migrations/**`, `apps/server/tool/**` | **no schema change; no new columns, tables or triggers** |
| `apps/server/lib/src/generated/**` | nothing to regenerate |

---

## 12. Verification plan

**Positive**

| ID | Case | Layer |
|---|---|---|
| P-1 | A `reported` defect for a `governed` product → work item at `designNotRequired`, job enqueued with `'{id}:triage_defect'`, `defect.currentTriageJobId` set | integration |
| P-2 | Sweep over a defect whose intake enqueue never ran → exactly one job, same key | integration |
| P-3 | A feature request on a `governed` product → work item at `planned`, metadata carries `EXTERNAL_WORK_ENTRY_CONSUMER_DEPENDENCY`, **and zero jobs enqueued** | integration |
| P-4 | Restart mid-walk-up (crash between `planning` and `planned`) → replay converges to one item, no duplicate | integration |
| P-5 | The 18 historically orphaned jobs are found by the sweep and repaired (or reported under `WORK_ITEM_MISSING` and **not** guessed at) | integration |

**Negative — the ones the dispatch asked for**

| ID | Case | Expected |
|---|---|---|
| **N-1** | **Ungoverned product.** Feature request against a `registered` product. | Request **accepted**; work item created; **no transition, no job**; reason `PRODUCT_NOT_GOVERNED`. NOT rejected, NOT failed. Then: flip the product to `governed`, run the sweep → dispatched. |
| **N-2** | **Two submissions of the same work item.** Intake, then sweep, same tick. | Exactly one job. `enqueueIfAbsent` returns `created: false`; the second reports `TRIAGE_ALREADY_ACTIVE` naming the first job id. |
| **N-3** | **Restart mid-dispatch.** Kill after claim, before the lane finishes; lease expired. | `_reconcileClaim` requeues; the **same execution** is adopted, or the lease is renewed if it is still alive. Assert **no second `TriageResult`** (`resultId = 'tr-{jobId}'` is stable). |
| **N-4** | **A feature job, if one were ever enqueued.** Assert the guard directly: `TriageProcessor.processCompletedTriageJob` on a `WI-feature-*` work item returns `null` and writes no `TriageResult`. | Pins §6 so a future "let's just route features through lane A" change **fails a test**. |
| **N-5** | **`paused` / `offboarded` product.** | Same as N-1. `ProductState` says *"the scheduler will not dispatch new work"*; the test asserts it is now actually enforced. |
| **N-6** | **Concurrent sweep + intake**, same defect. | `DuplicateActiveJobException` resolved to the winner; exactly one job; **neither** throws. |
| **N-7** | **Overlapping sweep passes** (`Timer.periodic` semantics). | Second pass does not run; `overlappedPasses: 1` is **reported**, not silently dropped. |
| **N-8** | **Product-agnosticism grep gate.** | `rg 'shipit|SHIPIT_'` over `apps/server/lib/src/triage/work_entry.dart` and `defect_triage_sweep.dart` → **0 matches**, asserted in CI. |
| **N-9** | **No product name in the predicate.** | The sweep's triagable set is statuses, and the route is `WorkEntryKind` — never a product id. Asserted by N-8 + review. |
| **N-10** | **No regression on the live defect path.** | The full existing defect-intake integration suite passes **unchanged**; `createDefect` is not edited. |

**N-1, N-2 and N-4 are the acceptance criteria.** If they do not fail closed, this work item has not
succeeded regardless of what else passes.

---

## 13. Human Decisions routed — **not resolved here**

Per `aef-human-decision`, neither is resolved, implied, or pre-answered. **No `HumanDecision` object
is created.**

> ### HD-1(a) — Must a **human-reported defect** have a `governed` product before it may be triaged?
>
> Today `createDefect` checks **registration only** (`control_plane_service.dart:923`) and enqueues
> triage immediately, for a product in any state including `offboarded`. Against `ProductState`'s
> own text — *"governed … Work may be dispatched for this product"* — that is a live contradiction.
> This revision's governance gate would newly **enforce** it, i.e. change shipped, working
> behaviour on a path outside this work item's scope.
>
> - **A.** Triage is exempt: classifying a real-world defect report is not "work for the product",
>   and a governed product must still accept one. *(my reading — offered as input, not a decision)*
> - **B.** Triage obeys `governed` like everything else; ungoverned products get no classification.
>
> **Blocking:** Gate D4. **Does not block** the defect sweep (§11.1–11.2, 11.4).
> **Evidence:** `product_state.dart:43-53`; `control_plane_service.dart:923,1048`; §7.

> ### HD-1(b) — For a feature request on an ungoverned product: **park**, or **refuse**?
>
> - **A. Park.** Request accepted; work item at `planned` with a recorded reason. Truthful, loseless,
>   but a human sees their request accepted and then stall at `planned` — a *worse* visible outcome
>   than today's `draft`, and it changes what the Reports screen shows (P-4).
> - **B. Refuse.** Reject at intake: *"this product is not governed, so we are not accepting feature
>   work."* Honest at the moment of submission; rejects a human over a platform-internal condition.
>
> **Blocking:** Gate D4 **and** the feature half's behaviour (HD-1(b) chooses between the two
> `WorkEntrySkipped` reasons in §4 — a two-line change at one branch).
> **Evidence:** §7; `intake_endpoints.dart:20`; P-4.
> **Recommendation:** *A (park), and pair it with UI copy that says why.* Offered as input.

> ### HD-2 — Should a defect's triage work item keep `category: triageWorkItemCategory`?
>
> Not raised to change it. Raised because §4 **had** to route on `WorkEntryKind` instead of
> `WorkItemCategory` **because these disagree**, and a reader deserves to know that is a standing
> inconsistency rather than a choice this revision made.
>
> - **A.** Leave it. Routing keys on the intake, not the category — the design already does this.
> - **B.** Harmonise the categories so routing can key on `category` later.
>
> **Blocking:** nothing. **Does not block** implementation. Recorded for the next reader.
> **Evidence:** `lane_a_defect_triage_work_item.dart:127-133`, whose own comment says
> *"changing it is a domain decision, not wiring."*

---

## 14. Discoveries (per `aef-repository-learning`)

| ID | Finding | Category | Authority |
|---|---|---|---|
| **D-1** | An exhaustive `saveJob` call-site trace misses `JobQueue.enqueueIfAbsent`, because it calls `tx.saveJob` on a `JobStore` **transaction handle**. This is exactly why the dispatch reported "nothing enqueues triage" while it enqueues on every defect report. Any verification tooling that traces concrete types rather than interfaces will produce this false negative. | `WORKFLOW_IMPROVEMENT` | independent review |
| **D-2** | `ProductState.governed`/`paused`/`offboarded` state in prose what may be dispatched, and **nothing enforces it** — `RunnableWorkEvaluator` receives a `WorkItem` and never resolves `productId`. | `ARCHITECTURE_DISCOVERY` | **human** (HD-1a) |
| **D-3** | `RunnableWorkEvaluator` is **category-blind**; any work item at `designNotRequired` is triaged as a defect regardless of `category`. Routing must therefore be done by not walking, never by filtering at dispatch. | `PROJECT_FACT` | automatic (Lane 1) |
| **D-4** | `TriageResult.defectId` is non-nullable and `_extractDefectId` is `defect-`-prefix-bound, so a feature work item routed to lane A produces a job that **succeeds and is then discarded** at `readDefect` — a new silent no-op, structurally identical to F-4. | `PROJECT_FACT` | automatic (test N-4 pins it) |
| **D-5** | The triage execution context is **not product-scoped**: one `SHIPIT_TRIAGE_REPOSITORY_PATH` for every product, so all triage runs in one repository's worktree. | `PROJECT_FACT` | automatic (documented, not fixed) |
| **D-6** | The 18 orphaned `queued` triage jobs the code comment records are **still on disk and still un-repaired** by any current code path. | `PROJECT_FACT` | automatic (Lane 1 — test P-5) |
| **D-7** | `verify_schema_bootstrap.sh` — **exit 0, 20 `OK:` assertions**, 0 failures, at `d25a4d8`. Unchanged by this revision (no schema change). | `PROJECT_FACT` | automatic — **executed** |

**Persisted:** none. This is a design-only lane; its owned path is its own task directory. D-1
exceeds design authority (tooling) and D-2 is escalated.

---

## 15. Implementation lanes

### `OWNED_PATHS` — disjoint by construction

| Lane | Scope | `OWNED_PATHS` (exclusive) |
|---|---|---|
| **L1** — Trigger | `work_entry.dart` + its unit test | `apps/server/lib/src/triage/work_entry.dart`<br>`apps/server/lib/src/triage/work_entry_test.dart` |
| **L2** — Sweep | `defect_triage_sweep.dart` + its unit test | `apps/server/lib/src/triage/defect_triage_sweep.dart`<br>`apps/server/lib/src/triage/defect_triage_sweep_test.dart` |
| **L3** — Wiring | feature-intake hunk + composition | `apps/server/lib/src/services/control_plane_service.dart`<br>`apps/server/lib/server.dart` |
| **L4** — Integration | the integration suite + the N-4 guard | `apps/server/test/integration/work_entry_integration_test.dart` |

### Dependency edges

```
L1 ──┬─→ L2          (the sweep calls the trigger)
     ├─→ L3          (intake calls the trigger; composition constructs it)
     └─→ L4

L2 ─────→ L3         (the sweep is constructed on the tick)
```

**SAFE_PARALLEL_WORK:** `L1` alone. It is the only file nothing else needs to exist before it is
written, and every other lane is downstream of it. Read-only lanes (this one, design review, QA
contract authoring, any research) may run concurrently with **all four**.

**PROHIBITED_PARALLEL_WORK:**
- `L2 ∥ L3`, `L3 ∥ L4`, `L2 ∥ L4` — each has L1 as a dependency; running them early means writing
  against an API that does not exist yet.
- **Any** lane modifying `packages/scheduler/**` — §5 says the seam is used unchanged; a change
  there is a review-blocking finding, not a task.
- **Any** lane modifying `apps/server/lib/src/triage/triage_processor.dart` or
  `lane_a_defect_triage_work_item.dart` — both work; both are on the live defect path.
- **Any** lane touching `apps/server/migrations/**`, `apps/server/tool/**`, or
  `apps/server/lib/src/generated/**` — no schema change, no regeneration.
- **Any** implementation lane resolving HD-1, HD-2, or **taking a Docker/Compose action**.

**Suggested order:** `L1` → (`L2 ∥ L3`) → `L4`. **Suggested gate:** do not enable the sweep on the
live tick until P-2 and P-5 pass — the sweep is the first thing that will touch the 18 orphans.

---

## 16. Traceability

| Requirement | Source | Section | Status |
|---|---|---|---|
| **0** — re-derive the stated facts | dispatch *"KEY FACTS — verified, do not re-derive"* | §1 | **Four corrected (P-1…P-4).** Honoured in substance by checking; not honoured as instruction, because three premises are false at `d25a4d8` and building on them would have designed a fix for a defect that does not exist. |
| 1 — trigger shape: intake / sweep / both | dispatch Q1 | §3, §11.1–11.4 | **Both**, one operation, one key |
| 2 — ungoverned product: refuse / wait / fail | dispatch Q2 | §7 | **Answered: accept, gate the walk.** **HD-1(a)/(b) escalated, not decided** |
| 3 — scheduler seam; do not assume baseline transfers | dispatch Q3 | §5, §11.6 | **Unchanged; assessed, not assumed** |
| 4 — features vs defects; mirror `EXTERNAL_*` | dispatch Q4 | §6, §11.1 | **Two paths. Consumer does not exist; recorded, not faked** |
| 5 — idempotency + restart, using the existing key | dispatch Q5 | §8 | **Key imported, never re-spelled; three layers** |
| 6 — product-agnostic: no names, defaults, env lookups | dispatch Q6 | §9, N-8 | **Grep gate N-8** |
| 7 — verification incl. the 3 named negatives | dispatch Q7 | §12 | **N-1, N-2, N-3 present as named cases** |
| design only; diffs as text | dispatch CONSTRAINTS | §11 (header) | Honoured — **0 files modified outside `OWNED_PATHS`** |
| `packages/**`, `apps/**`, `docker/**`, `.github/**`, `.decisions/**`, `AGENTS.md`, `docs/**` read-only | CONSTRAINTS | §0, §11.6 | Honoured |
| **ZERO** Docker/Compose | CONSTRAINTS | §17 | Honoured — **0 commands issued** |
| `verify_schema_bootstrap.sh` run + reported | CONSTRAINTS | §14 (D-7), §17 | **exit 0, 20 `OK:`** |
| do not resolve a Human Decision | CONSTRAINTS | §13 | Honoured — **3 routed, 0 resolved** |
| non-overlapping `OWNED_PATHS` + dependency edges | CONSTRAINTS | §15 | Honoured |
| `AGENTS.md §12` baseline independence | CONSTRAINTS | §17 | Read; **not engaged** — this revision touches no baseline, no evidence kind, no verification. Stated rather than assumed. |

**`requirements_gaps`:** requirement **0** is answered by *contradicting the dispatch's premises*
rather than confirming them. Requirement **2** and the feature half of **4** are answered as
*escalated rather than decided*. None is a coverage gap; all three are deliberate refusals.

---

## 17. Validation performed by this lane

| Check | Result |
|---|---|
| `git rev-parse HEAD` | `d25a4d8a3a70ff49485c43af83019347d790d8f7` ✅ (dispatch: `d25a4d8`) |
| `git rev-parse --abbrev-ref HEAD` | `design/work-entry` ✅ |
| `git status --porcelain` before writing | empty ✅ |
| Files modified outside `docs/engineering/dispatch/tasks/design-work-entry/` | **0** ✅ |
| **Docker / Compose commands issued** | **0** ✅ — no `compose`, no `make clean`, no `qa-down`, no `test-env-down`, no `e2e-down`, no `down -v`. Compose was read as **text** only. |
| `bash apps/server/tool/verify_schema_bootstrap.sh` | **exit 0**, **20 `OK:` assertions**, 0 failures ✅ |
| `AGENTS.md §12` | read; **not engaged** by this revision (touches no baseline/evidence/verification path) |
| Baseline-lane reports read | `design-baseline-production-lane/design-revision.md` (905 lines), `review-baseline-0d5d132/report.md` (212 lines) ✅ |
| Commit / push performed | **none** — not instructed, not authorised |

---

## 18. Independent review focus

Suggested, not directed — the reviewer owns the verdict.

1. **Are P-1…P-4 right?** The whole revision rests on them. If any is wrong the design is wrong.
   Re-run `control_plane_service.dart:1036-1062` and `features/reports/`.
2. **Is "governed gate" (§7) the right shape, or should intake refuse?** That is HD-1(b); the
   reviewer should say whether parking is acceptable UX, not whether it is implementable.
3. **Does §5's category-blindness finding argue for a `Scheduler` change anyway?** I argue no, and
   argue it is a *reason to keep* `work_entry.dart` the only thing that walks items. Push back if
   the coupling is too implicit.
4. **Is Risk 2 right?** I explicitly considered and rejected both 1 and 3 with reasons; disagree
   openly.
5. **Is N-4 a good enough guard** for the feature-consumer gap, or is a test the wrong instrument
   for a missing runtime?
6. **Does §2.2's unanswered "has triage ever run?" belong here at all**, or should it be a
   precondition that blocks L1 entirely?