# Design Brief — Implementation lane + durable workspace creation

| Field | Value |
|---|---|
| `brief_id` | `B4D91D4A-CF4A-4415-864A-E0700D893367` |
| `revision_id` | `45EFF1E2-E39F-46AE-98C9-D417EEF5BF0E` |
| `revision_number` | `1` of this brief (first revision on this base) |
| `version` | `1.0.0` |
| `status` | `UNDER_REVIEW` |
| `risk_level` | **3** — Major Workflow change; see §12 |
| `branch` | `design/implementation-lane-rev2` |
| `worktree` | `/Users/alkebut/air/.aef-lanes/impl-lane-design-rev2` |
| `base_sha` | `84be9794f83ee258664842cd2c9f73f562b0d5f7` |
| `created_by` | `design-agent` |
| `created_at` | `2026-10-13` |
| `supersedes` | `IMPL-LANE-001` / `IMPL-LANE-001-R1` @ `5d7c276`, base `5cb2817` — **per-decision supersession ledger in §1.3**; nothing was merged, so nothing is retracted |
| `requirements_refs` | `IMPL-001`..`IMPL-005` (§13) |
| `architecture_refs` | `docs/adr/0018-per-product-git-credentials.md`, `docs/adr/0019-standing-policy-authorisations.md`, `docs/adr/0020-defect-domain-model.md`, `docs/adr/0021-design-defect-routing.md`, `AGENTS.md §13a/§13b`, `docs/engineering/DESIGN_GOVERNANCE.md` |
| `companion` | `docs/design/implementation-lane/design-revision-metadata.yaml` |

> **Identifiers follow the live repository convention and do not collide.**
> `brief_id` / `revision_id` are UUIDs, matching every current dispatch-task brief
> (`5471fea4-…`, `9E045515-…`, `6fbb5bb2-…`, `b5ff65f3-…`) and the two briefs under
> `docs/design/**`. Human decisions in this repository are `HD-N` and `HD-1`..`HD-7`
> are **already taken** (`docs/engineering/dispatch/DECISIONS.md:372,402,424`), so this
> brief does **not** mint `HD-8`. Open decisions below use `OD-N`, a prefix with zero
> prior use anywhere in `docs/` or `.decisions/` (verified by grep at this base).

---

## 0. Provenance, method, and what this document is not

Written at `BASE_SHA 84be979` on branch `design/implementation-lane-rev2`. Every claim
about existing behaviour carries a `file:line` citation that resolves against that exact
revision. Verified in this lane by reading the real files; `git merge-base --is-ancestor`
confirms `cc9317c`, `f164d40`, `1f39a05` and `5cb2817` are all ancestors of this base.

**Not done by this lane, and stated so a reviewer does not have to infer it:** no production
file modified; no migration written; no Docker or Compose command issued (compose files were
read **as text**, per `AGENTS.md` "Shared Docker state"); no database connection; no `psql`;
no `git stash`; no state-changing git operation. The worktree was clean before writing and
the only commit is the one carrying this artifact.

**Attributed, not re-derived.** Three facts were verified by the Manager against the running
QA stack and are repeated here as inputs, because re-deriving them would have required a
database connection this lane is forbidden to make:

- `onboarding_record` has **0 rows**;
- the deployed-key private half is present at the container path
  `/var/lib/shipit/secrets/GIT_REPOSITORY_shipit-platform_SSH` as a `0600` regular file,
  and the `product_credential` row reads `status = verified`,
  `hostKeyStatus = confirmed`, `lastVerifiedBy = lane:baseline-production`;
- no durable clone exists on disk anywhere.

**Credential custody is solved and this brief does not redesign it.** That was `OD-2` in the
stale brief and it is **withdrawn**, not re-argued — see §1.3.

---

## 1. What changed between the stale brief and this base

### 1.1 The four merges that land between `5cb2817` and `84be979`

| SHA | Merge | What it changed | Effect on this design |
|---|---|---|---|
| `cc9317c` | `SUPERSESSION-HOP` | `packages/scheduler/lib/src/policy/entry_hop.dart` added (315 lines); `Scheduler` constructs an `EntryHopper` (`scheduler.dart:374-378`) and calls `prepare` on every `runnable` item (`:616`) | **`OD-1` is moot.** Resolved in §1.2, not re-litigated. |
| `f164d40` | `ONBOARDING-WORKSPACE-DURABLE` | `OnboardingRecord` gains nullable `pinnedRevision` / `workspace` / `completedBaselineId`; migration `20261012213045000`; `recordWorkspace` + `completeOnboarding` added to `ProductRegistryEngine` | **The storage and the writer both exist. The production caller does not** — §2.2. This is A1's reason to exist. |
| `1f39a05` | `SNAPSHOT-RELEASE` | A snapshot tree carrying an artifact commit is **retained**, a marker `RETAINED_ARTIFACT.json` is written **beside** the checkout, and `SnapshotReleaseDisposition.treeRetainedForArtifact` is returned to the caller | Retention is now a first-class, **unbounded and unowned** obligation. §6.5, `OD-9`. |
| `a867acc` | `SNAPSHOT-CORRECTION` | A releaser that threw now leaves the disposition `null` and **replays the failure** on every later `release()` instead of reporting `treeDestroyed` | The "is the tree gone?" question is now three-valued and honest. §6.5 depends on this. |

### 1.2 `OD-1` — resolved, not re-opened

The stale brief's `OD-1` asked whether to land before, after, or independently of the
`SUPERSESSION-HOP` lane, and recommended "land independently; the design is built to need no
performed hop." `cc9317c` has landed. **The recommendation turned out to be correct and is
now a fact rather than a hope**, verified two ways:

1. **The hop is not declared and therefore cannot be taken.** `EntryHopper.prepare` first
   asks whether the edge the coordinator will attempt exists
   (`entry_hop.dart:176-179`, `_edgeExists` at `:129-138`); only if it does not exist does it
   consult `definition.entryProbeTargets` (`:181`). A2 declares `entryStates` and **no**
   `entryProbeTargets` (`§7.2`), and adds the direct edge `implementationReady -> agentExecuting`
   (`§7.3`), so `prepare` returns `EntryHopStatus.direct` and moves nothing.
2. **The drift guard already enforces exactly this.** `entry_hop_drift_guard_test.dart:50-56`
   enumerates the production definitions, and case (1) "direct" or case (2) "hopped" must
   hold for every entry state. A2 must add its definition to that list (`§7.2`), which makes
   "needs no hop" a **test-enforced** property rather than a design intention.

**Consequence for the collision argument — and this is the part that had to be re-checked.**
`EntryHopper` does **not** weaken the disjoint-entry-state argument, and the reason is the
order of operations in `RunnableWorkEvaluator.evaluate`:

```dart
// packages/scheduler/lib/src/policy/runnable_work.dart:142-144
if (!definition.entryStates.contains(item.state)) {
  return RunnableWorkStatus.noAction;
}
```

That test runs **before** the legality probe (`:157-163`) and long before `EntryHopper` is
reached, which happens only inside the `case RunnableWorkStatus.runnable:` arm
(`scheduler.dart:606-616`). So an item can only ever be *prepared* by a definition that
already claims its state. `EntryHopper` can move an item only onto a state in **its own**
definition's `entryStates` (`entry_hop.dart:288-297` refuses anything else). **A hop can
therefore never be the thing that carries an item from one lane's entry set into another's.**
The collision argument survives `cc9317c` intact and is restated and re-verified in §7.4.

### 1.3 Supersession ledger — the stale brief, decision by decision

Nothing is deleted. Each stale decision is marked with its disposition and, where merged
code has overtaken it, the SHA that did the overtaking.

| Stale ID | Subject | Disposition at `84be979` | Overtaken by |
|---|---|---|---|
| `OD-1` | `EntryHopper` not in base | **RESOLVED — moot.** `cc9317c` landed; design still needs no hop. §1.2 | `cc9317c` |
| `OD-2` | Durable clone ⇒ credential custody | **WITHDRAWN — premise false.** Custody works and is verified; the private half is materialised per acquisition and destroyed **first and unconditionally** at release (`repository_snapshot_acquirer.dart:876-882`). A durable clone does not change custody, because a durable clone does not need the key after it is made. | Manager verification; `f164d40` |
| `OD-3` | What "rework" means for the five routes into `designNotRequired` | **RETAINED, still open, and SHARPENED.** The new state is already decided (§7.1), so the question is now "which of these five retargets to it". The stale brief's claim that all five must move `escalationTargetFor` in lockstep is **wrong for three of them** — §7.5, `OD-3`. | — |
| `OD-4` | `null` from `WorkloadResolver` means `blockedArtifactMissing` | **RETAINED, still open.** Unchanged by any merge: `WorkloadResolver` is still `Future<SchedulerWorkload?> Function(Job, WorkItem)` (`scheduler.dart:143-145`), `null` still maps to exactly one outcome (`:763-767`), and that outcome is still documented as a fail-closed signal the composition root must turn into a blocking human decision (`:298-303`, field declared at `:303`). | — |
| `OD-5` | The QA-contract precondition | **RETAINED, still open, and now blocking.** Unchanged: `agentExecuting -> agentCompleted` still carries `GuardConditions.qaContractExists()` (`work_item_transitions.dart:102`); the guard still reads `context?['qaContractId'] != null` (`guard_conditions.dart:247`); the coordinator still supplies it only when the item has one (`execution_coordinator.dart:830`). | — |
| `OD-6` | The implementation `VerificationPlan` | **RETAINED, downgraded from open decision to a composition-root obligation.** The stale brief already conceded "would work is not a decision"; it is recorded as an obligation in §7.8 rather than escalated, because the evidence now settles the *shape* (the product repository has `pubspec.yaml` and `test/`; the triage repository has only `README.md` — `docker/compose.qa.yaml:31`). | — |

**The stale brief's core step is not superseded — it is wrong, and the error is load-bearing.**
§4.4 of `IMPL-LANE-001` resolved the workspace as:

```
2. OnboardingRecord exists AND currentBaselineRevision > 0   (baseline READ BACK)
3. a durable, platform-owned, PRODUCT-SCOPED local mirror exists and reports
   `rev-parse --verify <currentBaselineRevision>^{commit}`
4. -> SchedulerWorkload(repositoryPath: mirrorPath, startingRevision: currentBaselineRevision)
```

`currentBaselineRevision` is an `int`
(`packages/platform_contracts/lib/src/types/onboarding_record.dart:74`), documented in the
type itself as *"A SEQUENCE COUNTER, not a git revision"* (`:71-74`), produced by
`nextBaselineRevision` — *"max existing + 1, or 1"*
(`packages/product_registry/lib/src/store/product_registry_store.dart:150-151`, implemented
at `postgres_product_registry_store.dart:823`) — and set on the record by `approveBaseline`
when a human accepts a baseline (`product_registry_engine.dart:608-611`).
Feeding it to `git rev-parse --verify <n>^{commit}`
would fail closed every time, and `startingRevision` would carry a number where the worktree
manager requires a commit (`git_worktree_workspace_manager.dart:89-96`).
**This revision deletes that step.** §2 states the corrected framing.

### 1.4 What carries forward unchanged

Retained from `IMPL-LANE-001` because every citation still resolves at this base:

- **The manufactured-artifact analysis** (§4, §4.1, §7.1, §8 there). `/triage-repo` is still a
  README-only scratch repository (`docker/compose.qa.yaml:20-38`), still both shipped
  schedulers' `repositoryPath` (`server.dart:307-311`, `:349-351`), and the review resolver
  still requires `endingRevision != null && != requestedStartingRevision`
  (`engineering_review_gate.dart:71-73`). Pointing an implementer at it would produce a
  green review of a fabricated commit. **Now §4.3 and §9.**
- **The review-resolver anchoring argument** (§4.4, §7.1 row 10 there). The reviewer re-reads
  `producer.repositoryPath` (`engineering_review_gate.dart:75`) and the worktree manager
  re-validates the revision **in that repository** before creating anything
  (`git_worktree_workspace_manager.dart:85-92`). So the repository holding the artifact
  commit must outlive the execution. **Now §6.4.**
- **The entry-state collision argument and the candidate analysis** (§5 there). Every
  candidate is re-checked against `cc9317c` in §7.4. Candidate B is still impossible — the
  discriminator is *absent from the data*, not merely unused, because defect-triage work
  items are filed as `WorkItemCategory.feature`
  (`packages/qa_orchestration/lib/src/lane_g_triage_qa_contract.dart:27`) and there is no
  `bug` variant (`packages/platform_contracts/lib/src/enums/work_item_category.dart`).
- **The "manufactured evidence" refusal** for the stranded `agent_completed` items (§8
  there). Unchanged. **Now §9.4.**
- **The review-ability matrix.** Restated against this base in §7.10.

---

## 2. The corrected framing — this is the section the stale brief got wrong

> **Durable workspaces have never been built, because no lane has ever needed one. Every lane
> so far was read-only. An implementation lane is the first lane needing a persistent writable
> clone, and that code was never written. Workspace CREATION is a prerequisite of
> implementation — not something derived from the baseline.**

The rest of this section is the evidence for that sentence, and each fact is load-bearing for
a decision later in the brief.

### 2.1 The baseline lane acquires into SCRATCH, by design and correctly

`SshPinnedSnapshotMaterializer.materialize` creates a throwaway directory and clones into it:

```dart
// apps/server/lib/src/credentials/repository_snapshot_acquirer.dart:740,746
final scratch = Directory.systemTemp.createTempSync(scratchPrefix);   // :697 'baseline_snapshot_'
...
final clonePath = '${scratch.path}/checkout';
```

`Directory.systemTemp` is `/tmp` **inside the server container**, and `/tmp` is not a volume
in any of the four compose files (verified by grep at this base). So a baseline snapshot is
container-ephemeral by construction — and that is **right**: `ReadOnlyRepositoryReader` is
handed a tree it must not write to (`repository_snapshot_acquirer.dart:273-278`), a derivation
that mutates its own input is not re-derivable, and the derivation throws the tree away when it
is done. Nothing is wrong here. It is simply not a workspace.

### 2.2 The durable machinery exists, is merged, tested, and has **zero production callers**

| Fact | Evidence at `84be979` |
|---|---|
| `OnboardingRecord` carries the full answer | `pinnedRevision` `onboarding_record.dart:105`, `workspace` `:122`, `completedBaselineId` `:129` |
| The single read that answers "is there one?" | `hasDurableWorkspace` `onboarding_record.dart:157` |
| The two columns cannot silently disagree | `validate()` refuses a `pinnedRevision` that differs from `workspace.startingRevision` `onboarding_record.dart:238-244`; both store tiers call it before writing (`postgres_product_registry_store.dart:1033`, `in_memory_product_registry_store.dart:465`) |
| The columns persist | migration `20261012213045000` — three nullable `ADD COLUMN`s, no default, no backfill |
| The writer exists | `ProductRegistryEngine.recordWorkspace` `product_registry_engine.dart:1917-1957`; `completeOnboarding` `:1976-2002` |
| Its callers | **none in production.** The only call sites are `packages/product_registry/test/onboarding_workspace_test.dart` and `apps/server/test/integration/onboarding_workspace_postgres_test.dart` |

`recordWorkspace` and `completeOnboarding` are **shipped, schema-backed, contract-tested, and
uncalled.** `ControlPlaneService.triggerOnboarding` even documents the absence as the reason
it does *not* write a pin (`control_plane_service.dart:2086-2096`): *"The run that actually
creates the workspace is what calls `ProductRegistryEngine.completeOnboarding`, and that write
is the one that makes the pin durable."* **That run does not exist.** The comment names a
missing caller, and this brief supplies it.

### 2.3 The Serverpod container has no volume for durable workspaces

`docker/compose.qa.yaml` mounts exactly three things into `server` (`:109-119`):
`triage_repo_qa:/triage-repo`, `triage_workspaces_qa:/triage-workspaces`, and
`${SHIPIT_HOST_SECRET_DIR:-…}:/var/lib/shipit/secrets`. **There is nowhere for a product clone
to live that survives container destruction.** `/triage-workspaces` is a real named volume, but
it holds `GitWorktreeWorkspaceManager`'s per-execution artefacts — a worktree directory that is
`git worktree remove`d on cleanup (`git_worktree_workspace_manager.dart:160-171`) and a
descriptor JSON that outlives it (`:115-135`). It is a workspace *root*, not a workspace.

### 2.4 What the durable answer actually has to hold together

The chain that must survive the implementation execution is fully verified from source:

1. The implementer's agent writes files into a detached worktree.
2. `LocalWorker` commits them via `ArtifactCommitter` for every non-reviewer role
   (`local_worker.dart:280-305`), onto `<branchPrefix>/<workItemId>` with the default prefix
   `shipit/impl` (`artifact_committer.dart:103,124-127`), and records the produced SHA as
   `endingRevision` (`local_worker.dart:290-291`).
3. `git worktree add --detach` means the worktree and the source repository **share one object
   store and one ref namespace** — `git_worktree_workspace_manager.dart:158-160` says so in
   words: *"The repository becomes the source of truth again; dirty agent edits inside the
   worktree die with it."* So the artifact commit lands in the **source repository**, not in the
   worktree. Removing the worktree does not remove the commit; **removing the source repository does.**
4. The reviewer is dispatched with exactly `producer.repositoryPath` + `produced`
   (`engineering_review_gate.dart:69-76`), and `GitWorktreeWorkspaceManager.prepare` re-validates
   `rev-parse --verify <rev>^{commit}` **in that repository** before creating anything
   (`git_worktree_workspace_manager.dart:85-96`).

**Therefore: the source repository is the artifact. It must not be ephemeral. That is the whole
of the durability requirement, and it is stated as a property of a git object store rather than
as a slogan about workspaces.**

### 2.5 The consequence for the split

`recordWorkspace` needs a `WorkspaceDescriptor`, and `WorkspaceDescriptor` is **per-execution,
not per-product** (§6.2, `OD-8`). `completeOnboarding` needs a `completedBaselineId`, so it can
only run **after a human has accepted a baseline** (`product_registry_engine.dart:1980,1986-1991`
and `:597-611`). Neither is a scheduler concern. Both belong to a lane whose job is *creating
the thing*, which is why A1 exists as a separate unit rather than as a step inside A2.

---

## 3. Problem statement, verified end to end

Engineering review fails closed on every defect, correctly, against an item that was never
implemented.

1. Only two schedulers are wired: `sched-triage` (`server.dart:281`) and `sched-review`
   (`server.dart:320`). There is no implementation lane.
2. `TriageProcessor` writes only to the defect row — `defect.copyWith(metadataJson: …)`
   (`triage_processor.dart:131-132`). It never writes a file.
3. So `ArtifactCommitter` returns `ArtifactCommitOutcome.none()` (`artifact_committer.dart:118-122`),
   `endingRevision` stays null (`local_worker.dart:290-291`), and
   `engineeringReviewWorkloadResolver` returns `null`
   (`engineering_review_gate.dart:71-73`).
4. `null` short-circuits dispatch (`scheduler.dart:763-767`) and surfaces as
   `blockedArtifactMissing` (`:665-671`), which the composition root turns into a **blocking**
   `engineeringReview` human decision (`engineering_review_gate.dart:317-412`).

**Nothing here is broken. Review is doing exactly what it is designed to do to an item with no
artifact.** The dead end is real, and §4.3 explains why closing it naively would convert a
*visible* dead end into an *invisible* one.

---

## 4. Why the split is A1-then-A2, and what the split buys

### 4.1 A2 cannot be built without A1, and that is fine

A2 dispatches an agent into a repository and then reviews the commit that agent produced. With
no durable clone there is no such repository, so A2 has nothing to point at. **A2 is not merely
easier after A1; it is meaningless before it.**

### 4.2 The manufactured-artifact hazard, stated as a negative control

If `sched-impl` were wired to `triageSource` — the pattern both shipped schedulers use
(`server.dart:307-311`, `:349-351`) — then:

1. the implementer writes into `/triage-repo`, a repository whose entire content is one
   `README.md` (`docker/compose.qa.yaml:31`);
2. `ArtifactCommitter` commits it, `endingRevision` is set;
3. the review resolver's four conditions are satisfied
   (`engineering_review_gate.dart:50-76`);
4. a reviewer dispatches and returns a verdict **on a fabricated artifact**.

That is strictly worse than stranding. Stranding is visible on a run page; fabrication produces
a **green review of code nobody wanted**. **The shipped design must be structurally incapable
of running without a real durable clone** — not "configured correctly in production", incapable.
`§7.7` is the mechanism, and its negative control is `§9.2` row 1.

### 4.3 A1 does not change the lifecycle; A2 does

`ProductState` is untouched by either unit. A1 flips `OnboardingRecord.completed`, which is an
onboarding-progress flag on a durable record, not a `WorkItemState` and not a `ProductState`.
**A2 is the unit that adds a `WorkItemState`, changes entry states, and retargets human-decision
routes** — and that is why §12's Level 3 justification rests on A2 alone, and why the human
approval request in §12.3 is scoped to A2's lifecycle surface rather than to the pair.

---

## 5. State flow

Current flow, with the two wired lanes and the states each claims:

```
                 OPERATOR / HUMAN DECISIONS
  draft -> planning -> planned ---------------------------------.
       |                                                             |
       |  planned -> designNotRequired  (orchestrator)               |
       v                                                             |
  designNotRequired  <---------------------------------------------- +
       |  +-- ENTRY STATE of triageDefectDefinition        (triage_defect.dart:59)
       |  +-- ENTRY STATE of defaultImplementFeatureDefinition      <== COLLISION
       |      (scheduler.dart:1702 — TEST-ONLY, §7.4)
       |                                                             |
       +--> [sched-triage]  entryStates {designNotRequired, designApproved, reviewRejected}
              |                                    (triage_defect.dart:58-62)
              |  work_entry.dart:592-605 walks the item HERE ON PURPOSE
              v
          agentExecuting     (execution_coordinator.dart, :277 raises
              |               WorkItemSupersededException on a refused edge)
              |  no file written -> ArtifactCommitOutcome.none()
              |  -> endingRevision = null
              v
          agentCompleted      producerActorId stamped on the SUCCESS branch only
              |                (execution_coordinator.dart:838)
              |  +-- ENTRY STATE of engineeringReviewDefinition {agentCompleted}
              |      (scheduler.dart:1863)
              v
          [sched-review]  resolver: producer ended with no artifact -> null
              |  -> no dispatch (scheduler.dart:763-767)
              v
          HUMAN DECISION, blocking, fail-closed     <-- stranded items sit here

  agentFailed --(operator retry, work_item_transitions.dart:129-131)--> designNotRequired
```

Proposed flow — the two lanes are given **disjoint dispatch surfaces**:

```
  designNotRequired  <-- TRIAGE-ONLY dispatch surface (UNCHANGED, proven, byte-identical)
       |                  triageDefectDefinition.entryStates =
       |                  {designNotRequired, designApproved, reviewRejected}
       v
  agentCompleted  ----> HUMAN DECISION (unchanged fail-closed path)

  --------------------------- NEW, disjoint ----------------------------

  implementationReady  <-- IMPLEMENTATION-ONLY dispatch surface
       |                     implementFeatureDefinition.entryStates = {implementationReady}
       |                     — ONE state, no overlap, ever
       |                     + readiness probe: no durable workspace => DEFER (§7.7)
       v
  agentExecuting  --(coordinator attempts implementationReady -> agentExecuting,
       |            which EXISTS: work_item_transitions.dart, §7.3.
       |            EntryHopper.prepare() finds the edge and returns `direct`;
       |            nothing is hopped.)
       |
       |  implementer WRITES FILES
       |    -> ArtifactCommitter commits shipit/impl/<workItemId> INTO THE DURABLE CLONE
       |       (the clone is the source repository; §2.4 step 3)
       v
  agentCompleted  ----> [sched-review] resolver finds endingRevision != start
                          -> dispatch -> reviewInProgress -> HUMAN DECISION
```

**The invariant the new state buys:** the two `entryStates` sets are **disjoint**, so no single
work item can be classified `runnable` by both definitions in the same tick. That is
structural, not procedural — it does not depend on a guard, a check, or a filter being
remembered. §7.4 re-verifies it against `cc9317c`.

---

## 6. Unit A1 — durable workspace creation

**A1 changes no lifecycle.** It adds no `WorkItemState`, no transition edge, no `JobDefinition`,
no `entryStates`, and no human-decision route. Its entire product surface is: a product-scoped
writable clone exists on durable storage, and `OnboardingRecord` names it.

### 6.1 What A1 produces

1. A **durable, product-scoped, writable clone** at an exact pinned commit, built from the
   product's own `RepositoryReference` and its own verified `ProductCredential` — no product
   names, no repository paths, no environment defaults (§6.7).
2. A `pinnedRevision` holding a real lowercase 40-hex commit SHA
   (`onboarding_record.dart:143`, `gitRevisionPattern`).
3. A `workspace` `WorkspaceDescriptor` whose `startingRevision` is **the same commit** — the
   one pairing `validate()` enforces (`onboarding_record.dart:238-244`).
4. A production caller for `recordWorkspace` and `completeOnboarding`
   (`product_registry_engine.dart:1917`, `:1976`).

### 6.2 Prerequisite decision — `WorkspaceDescriptor` is the wrong shape, and that is a finding

`OnboardingRecord.workspace` is typed `WorkspaceDescriptor`
(`onboarding_record.dart:122`), and `WorkspaceDescriptor` is **structurally per-execution**:

| Field | Required? | Meaning for a product-scoped durable clone |
|---|---|---|
| `workspaceId` | yes (`workspace_descriptor.dart:15`) | Fine — mint a product-scoped id. |
| `workerExecutionId` | **yes** (`:16`) | **There is none.** A durable clone is created by a platform operation, not by a worker execution. |
| `workerId` | **yes** (`:17`) | **There is none**, for the same reason. |
| `repositoryPath` | yes (`:20`) | Fine — the clone path. |
| `startingRevision` | yes (`:21`) | Fine — the pin. |
| `worktreePath` | yes (`:20`) | **There is none.** A durable clone is not a worktree; worktrees are per-execution and removed. |
| `branch`, `detached` | optional | `detached` defaults `true`, which is right for a clone pinned to a commit. |

All three impossible fields are also `required` in **both** JSON Schemas
(`schemas/workspace_descriptor.schema.json:8-16` and the inlined copy at
`schemas/onboarding_record.schema.json:39-47`), so they cannot simply be omitted on the wire.
Every schema is conformance-tested (`packages/platform_contracts/test/contract_schemas_test.dart:53,56`, test body at `:58-60`)
and `contract_schemas_test.dart` validates the committed examples, so a shape change is a
review-visible, test-breaking edit — which is the correct blast radius for this question.

**Three ways out, none of which this brief picks:**

- **(a) Relax the three fields to nullable** and let a product-scoped clone carry them as null.
  Smallest diff, but it makes `WorkspaceDescriptor` mean two things, and
  `hasLiveWorkspace`/`validate()` do not currently reason about the difference.
- **(b) Extend `WorkspaceDescriptor` with an explicit `kind`** (`execution` | `product`) and a
  validation rule per kind. Honest, and it is a schema + contract-suite change.
- **(c) Introduce a second type** (`ProductWorkspaceDescriptor`) and a second column.
  Cleanest model, and it is the one the migration `20261012213045000` explicitly **rejected**
  in its own header comment: *"WHY ONE TABLE AND NOT A NEW `workspace` TABLE … A separate table
  would be a SECOND home for the same answer."* Recorded so A1 does not re-litigate it by
  accident.

**This is `OD-8`. It is escalated rather than decided** because it changes a published JSON
Schema and a published contract suite, and because `AGENTS.md §12` is the section that makes a
producer's own claim about a baseline checkable — a change to the baseline's own descriptor
shape belongs in front of a human, not behind one.

### 6.3 Durable-workspace location — the single most important open question in this revision

The requirement is precisely stated in §2.4: **the clone is the artifact, so it must not be
ephemeral.** Three answers are possible. All three are stated with what they actually buy,
because "durable" is not one property.

**Option W-A — a Docker named volume, sibling to `triage_repo_qa`.**

```yaml
# docker/compose.qa.yaml — server.volumes, added beside :110
- workspace_repo_qa:/workspace-repo
# and at :154-157
volumes:
  postgres_data_qa:
  triage_repo_qa:
  triage_workspaces_qa:
  workspace_repo_qa:      # <- NEW
```

*Buys:* survives `docker restart`, container re-creation, and image rebuild — because the
volume is owned by the **compose project**, not by the container. **This is not a new idea in
this repository: `triage_repo_qa` is already a named volume holding a git repository that the
server forks worktrees from** (`compose.qa.yaml:111`, `server.dart:307-311`). The precedent is
literally the same shape one line above.
*Costs:* not readable from the host without `docker volume inspect`; lost to
`docker compose … down -v`, and `Makefile:90-92` (`qa-down:`) runs exactly that.

**Option W-B — a configured host bind mount, mirroring the secrets mount.**

```yaml
- ${SHIPIT_HOST_WORKSPACE_DIR:-/tmp/shipit-workspaces-NOT-CONFIGURED}:/workspace-repo
```

*Buys:* survives `down -v` **and** volume pruning, because the host directory is not Docker's
to delete. The precedent is again one line below: `${SHIPIT_HOST_SECRET_DIR:-…}:/var/lib/shipit/secrets`
(`compose.qa.yaml:119`) exists for exactly this reason, and its comment names the reason:
*"This bind mount is what makes it survive container destruction."*
*Costs:* a host path an operator must create and permission; a variable that can be unset.

**Option W-C — container-ephemeral, with defined re-creation.**

*Buys:* nothing. No new volume, no new host path, no operator step.
*Costs:* **it destroys the artifact.** §2.4 steps 3-4: the commit lives in the clone's object
store, and the reviewer resolves it out of `producer.repositoryPath`. A re-created clone is at
the pinned commit and does not contain `shipit/impl/<workItemId>`. Every implementation would
fail closed at review — the same invisible failure as §4.2, arriving later and attributed to
the reviewer.

**Recommendation: W-A for the compose-managed stacks, with W-B as the documented production
variant.** Three reasons, in order of weight:

1. **W-C is disqualified by the requirement, not by preference.** It cannot hold the artifact.
2. **W-A matches the durability the requirement actually demands.** The requirement is "survive
   container restart". It is **not** "survive `make qa-down`" — `qa-down` is documented as the
   deliberate teardown of the QA stack (`Makefile:90-92`), and `AGENTS.md` records that
   destroying `docker_postgres_data_qa` once already. A volume that `qa-down` removes is
   behaving exactly as documented; claiming it survives that would be the over-claim.
3. **W-A has an in-repo precedent at the same mount site.** Introducing a *new kind* of mount
   for a repo that already has one, one line apart, is the costlier choice.

**What the requirement does NOT demand, stated so nobody builds it by accident:** multi-host
durability, artefact archival beyond the review window, or surviving `down -v`. If a reviewer
or the operator wants any of those, the answer is a platform-owned bare remote, which is a
larger architectural change and is named as such in `OD-7`.

### 6.4 Reusing the trust chain, and refusing to reuse the snapshot lifecycle

**Reuse the trust decision; do not reuse `RepositorySnapshot`.**

The whole trust chain is already composed at `baseline_runtime.dart:99-122`:
`SecretProvider` → `CredentialKeyService` → `RepositoryAccessVerifier`, with the acquirer
holding all three (`repository_snapshot_acquirer.dart:504-513`). Every refusal it makes is a
refusal to proceed, never a degraded result (`acquire`'s own doc, `:515-522`):

| Refusal | Exception | Where |
|---|---|---|
| no minted credential | `BaselineSourceUnavailableException` | `:54` |
| host key not independently confirmed, or the value offered is this key's own public fingerprint | `HostKeyNotIndependentlyConfirmedException` | `:101`, checked at `:562-575` |
| tree is not the pinned revision | `PinnedRevisionNotAcquiredException` | `:120` |
| credential material could not be destroyed | `BaselineSnapshotCleanupException` | `:148` |

**A1 must not build its durable clone by calling `RepositorySnapshotAcquirer.acquire` and
retaining the tree.** Three independent reasons, each sufficient:

1. `RepositorySnapshot.root` **throws** after `release()` (`repository_snapshot_acquirer.dart:283-292`),
   so the caller cannot read the path back after the `finally` that every lane uses.
2. The retain path is decided by *"did anything commit into this tree"* — local branch refs
   (`:892-902`, `_localBranchRefs` at `:968`). A durable clone created by A1 has **no local
   head** at creation time, so it would be classified read-only and **destroyed**.
3. A durable clone is a **long-lived product**; a snapshot is a **per-execution** with a
   documented release contract. Reusing the object would import that contract into a thing that
   must not have one.

A1 therefore composes the **trust primitives** (`CredentialKeyService`,
`RepositoryAccessVerifier`, `SecretProvider`, `PosixFileModes`) with its **own** materialiser,
exactly as `RepositorySnapshotMaterializer` is already a port for
(`repository_snapshot_acquirer.dart:412-430`, "A port, so the lane's trust logic can be
exercised without a network, a database, or a git host"). **A durable clone must not be a
`RepositorySnapshot`, and the design says so in the type's own words when A1 writes it.**

**Credential custody is unchanged and the design says why, because the obvious worry is wrong.**
The stale brief escalated custody because a durable clone would hold a private key "for the life
of the product". It would not. `onRelease` destroys the private half **first and
unconditionally**, and the comment states the rule: *"An artifact is not a reason to keep a live
key on disk, so the credential material goes first and the repository's fate is decided
afterwards"* (`:867-882`). A durable clone is a plain git checkout with a `origin` remote and
**no credential configured on it**; any later `fetch`/`push` from it fails closed because there
is no key. `AGENTS.md §13a` (referenced by name, never by value) and ADR 0018 continue to
govern, unchanged. `OD-2` is withdrawn for this reason.

### 6.5 Coexistence with the now-RETAINED snapshot trees, and who reclaims what

Since `1f39a05` and `a867acc`, a snapshot tree that carries an artifact commit is **kept**,
marked, and reported:

- `SnapshotReleaseDisposition.treeRetainedForArtifact` (`repository_snapshot_acquirer.dart:183`)
  is returned to the caller, and its own doc says, in bold: *"**The caller owns reclaiming it.**"*
  (`:177`) and *"Anything that bounds it — how long, and who reclaims — has to be a decision
  made by whoever owns the artifact's lifecycle, not by the object that happens to clone it"*
  (`:179-182`).
- A marker `RETAINED_ARTIFACT.json` (`:33`) is written **beside** the checkout, not inside it —
  deliberately, because `ArtifactCommitter` runs `git add -A` and a marker inside the worktree
  would be swept into the artifact commit (`:904-911`, `:1060`).
- A releaser that threw leaves the disposition `null` and **replays the failure** rather than
  reporting `treeDestroyed` (`a867acc`; `:260-264`, `:367-395`).

**Verified: nothing in the repository reclaims a retained tree.** `grep` for
`treeRetainedForArtifact`, `RETAINED_ARTIFACT` and `retainedArtifactMarkerName` outside the
acquirer's own file and its tests returns nothing. **Retention today is unbounded and
unowned.**

The design's position, stated as three distinct objects so nothing is conflated:

| Object | Scope | Lifetime | Who reclaims it | Bounded? |
|---|---|---|---|---|
| **Durable product clone** (A1, this brief) | one per product | as long as the product is registered | **A1**, by policy — `OD-7` decides the bound | **must be** |
| **Retained snapshot tree** (`1f39a05`) | one per execution that committed | until someone reclaims it | **nobody** | **no — a pre-existing leak** |
| **Per-execution worktree** | one per worker execution | until `cleanup` | `GitWorktreeWorkspaceManager.cleanup` | yes (`removeAlways`, `worker_cleanup_policy.dart:5`) |

**A1 does not inherit the leak, and does not fix it.** A1 never produces a retained snapshot:
its clone is created durable and is not a `RepositorySnapshot` at all (§6.4). The retained-tree
leak is **pre-existing, orthogonal, and flagged** — it belongs to whoever owns the snapshot
lifecycle, not to this work item. `OD-9` records it; fixing it is a separate lane. **Silently
inheriting it would put an unbounded disk cost inside a product-scoped clone, and silently
fixing it would expand A1's blast radius into a lifecycle it does not own.**

### 6.6 What A1 must NOT do

1. **Must not point at `triageSource`, `SHIPIT_TRIAGE_REPOSITORY_PATH`, or any hardcoded path.**
   The product's own `RepositoryReference.uri` and its own credential are the inputs.
   `RepositoryReference`'s own doc is the rule: *"Product identity is never derived from the
   filesystem: durable identity is the registry record, not the worktree location"*
   (`repository_reference.dart:12-15`).
2. **Must not re-pin on every run.** `recordWorkspace`'s doc: *"the record answers 'where is it
   NOW'"* and *"re-pinning a product whose workspace is still pinned to the old commit is a call
   that has to pass BOTH"* (`product_registry_engine.dart:1908-1911`, `:1946-1948`).
3. **Must not fabricate `workerExecutionId` / `workerId` / `worktreePath`** to satisfy the
   current descriptor shape. That is `OD-8`, and fabricating them is precisely how a fake would
   enter a record whose whole purpose is to be checkable.
4. **Must not call `completeOnboarding` before a human has accepted a baseline.** It requires
   `completedBaselineId` (`product_registry_engine.dart:1980`) and refuses a product with no
   onboarding record (`:1986-1991`).

### 6.7 Product-agnosticism — A1 has a MECHANICAL gate, and it constrains the design

`apps/server/lib/src/baseline/product_agnosticism_test.dart` is an executable grep gate, and it
covers A1 directly. Verified at this base:

- `kForbidden = ['shipit', 'SHIPIT', 'ShipIt', 'airlock']` (`:30`), applied to every gated file (`:221-246`).
- A hardcoded-absolute-path regex `["']/(usr|home|repo|srv|var|opt|private)/` (`:252`), applied at `:248-262`.
- **Every non-test `.dart` file physically in `lib/src/baseline` must be listed** — `_laneDirectorySources`
  (`:120-127`) is cross-checked against `_laneSources` (`:84-113`) and a mismatch **fails**
  (`:170-199`).

Two consequences that are design obligations, not implementation trivia:

1. **Any new A1 file under `apps/server/lib/src/baseline/**` must be added to `_laneSources()`
   or the gate fails.** A1 owns that file, so this is self-contained — but it means A1 cannot
   add a lane file and leave the gate alone.
2. **A1's lane code cannot contain the substring `shipit`/`SHIPIT`, and cannot hardcode an
   absolute path.** So the durable-workspace-root **environment variable name must not be
   `SHIPIT_*` if that read lives in `lib/src/baseline/`**. The house answer already exists:
   read the variable in the composition root (`apps/server/lib/server.dart`, which the gate does
   not cover) and pass the resolved path **in** as a parameter — exactly how
   `_triageWorkspaceRoot()` (`server.dart:1281-1285`) feeds `GitWorktreeWorkspaceManager`
   (`:201`, `:210`). **This is why the A1/A2 path map in §8 has to leave `server.dart` to
   exactly one unit.**

### 6.8 A1 OWNED_PATHS

```
apps/server/lib/src/baseline/**          new durable-workspace lane + runtime + gate update (§6.7)
apps/server/lib/src/credentials/**       the durable materialiser + the trust primitives it composes
apps/server/lib/src/persistence/**       ONLY IF a store read is missing — see §6.9
docker/**                                the named volume / mount from §6.3
```

### 6.9 A1 probably does NOT need `apps/server/lib/src/persistence/**`

Verified: `PostgresProductRegistryStore.saveOnboarding` already writes all three columns
(`:1027-1059`) and `readOnboardingForProduct` already returns them (`:1061-1071`);
`_onboardingParams` / `_onboardingFromRow` already round-trip the JSON. `recordWorkspace` and
`completeOnboarding` are engine methods that need no store change.

**So `apps/server/lib/src/persistence/**` is provisionally OUT of A1's map**, and the brief says
so rather than granting a path nobody needs. If implementation finds a missing read, it is
re-scoped through review — not taken in silently.

---

## 7. Unit A2 — the implementation scheduler

A2 consumes A1's output. **A2 never creates a clone, never pins, never writes
`OnboardingRecord`, and never touches `docker/**`.** Its only contact with A1 is a **read**:
the readiness probe in §7.7.

### 7.1 The state — `WorkItemState.implementationReady`

```dart
// packages/platform_contracts/lib/src/enums/workflow_state.dart — PROPOSED, NOT WRITTEN
implementationReady('implementation_ready'),
```

Placed beside `agentExecuting` / `agentCompleted` in the execution cluster. Three mechanical
consequences, each verified rather than assumed:

1. **`isTerminal` needs no change** — it is a `switch` with a `_ => false` default
   (`workflow_state.dart:36-39`).
2. **`WorkItemWorkflowState.allowedTransitions` MUST gain a case, and the compiler says so.**
   That `switch` is exhaustive over `WorkItemState` with **no default**
   (`packages/workflow_engine/lib/src/states/workflow_state.dart:32-164`), so omitting the case
   is a **compile error**, not a silent lie. The mirror is then cross-checked against the real
   table by `packages/workflow_engine/test/transition_consistency_test.dart`. **A new state
   therefore cannot be added with a lying mirror.**
3. **The wire value reaches the UI as an unlabelled string.** `WorkItemView.state` is a
   `String` (`packages/control_plane_client/lib/src/protocol/work_item_view.dart:35,76`), and
   the UI maps it by a `switch` whose default is `PlainStatus.awaitingReview`
   (`apps/control_plane/lib/core/plain_language.dart:110-135`, default at `:135`). So an item at
   `implementation_ready` would render as **"awaiting review"** — a false statement on a screen
   with listeners. `transition_copy.dart:26-95` has the same shape (`_ => null` → the neutral
   `kUnknownTransitionMessage`). **Both files are `apps/control_plane/**`, which is READ-ONLY for
   both units** — recorded as a gap in §8.5 and `§13`, not silently absorbed.

### 7.2 The definition — disjoint entry set, live policy probe, real capabilities

```dart
// packages/scheduler/lib/src/scheduler.dart — PROPOSED, NOT WRITTEN
const JobDefinition implementFeatureDefinition = JobDefinition(
  jobType: JobType.implementFeature,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: {WorkerCapability.linux, WorkerCapability.git},
  entryStates: {WorkItemState.implementationReady},   // <- the whole change
  priority: JobPriority.normal,
  maxAttempts: 2,
);
```

- **`entryStates` is the entire fix**, and it is a **one-element set**. `RunnableWorkEvaluator`
  gates on `definition.entryStates.contains(item.state)` and nothing else about the item
  (`runnable_work.dart:142-144`). A single state that no triage definition lists makes the
  collision unreachable by construction.
- **No `entryProbeTargets`.** Declared absence is load-bearing: `EntryHopper.prepare` consults
  the map only after the direct edge is found missing (`entry_hop.dart:176-181`), and
  `entry_hop_drift_guard_test.dart:14-24` requires every entry state to be either *direct* or
  *hopped*. With the edge added in §7.3 the definition is *direct*, so the drift guard is
  satisfied with the map empty.
- **`skipWorkflowPolicyCheck` stays `false`.** The probe here can genuinely succeed, so skipping
  it would discard a real check. `engineeringReviewDefinition` sets it `true`
  (`scheduler.dart:1878`) because its edge carries `agentResultValid()` and the scheduler has
  no execution to supply one (`:1866-1877`) — that is the counter-example, not the precedent.
- **`git` is added to `requiredCapabilities`.** The current
  `defaultImplementFeatureDefinition` declares `{linux}` only (`scheduler.dart:1701`) while the
  implementer's lane genuinely commits — `ArtifactCommitter` runs `rev-parse`, `checkout -B`,
  `add -A`, `commit` (`artifact_committer.dart:113-141`). Selection compares the job's set
  against the worker's (`server.dart:195-205`, whose own comment records that an empty registry
  made every job defer forever), so **the implementer worker must be registered from
  `implementFeatureDefinition.requiredCapabilities`, not from a hand-copied list.**
- **`defaultImplementFeatureDefinition` is left untouched.** It is `const`, it is **test-only in
  production** (verified: the sole non-test reference is its own definition site,
  `scheduler.dart:1698`), and ~20 test files use it as a generic host. Repurposing it would
  churn every one of them for no production benefit. **It is not "replaced"; it is joined by a
  sibling.**
- **A2 must add `implementFeatureDefinition` to `productionDefinitions` in
  `entry_hop_drift_guard_test.dart:50-56`.** That file's own doc says a production definition
  absent from the list "is itself the defect this test exists to prevent" (`:47-49`). Note it
  does **not** currently list `onboardProductDefinition` either, because that job is dispatched
  per `JobType` from the tick hook rather than by a `Scheduler`.

### 7.3 The edge

```dart
// packages/workflow_engine/lib/src/transitions/work_item_transitions.dart
// — PROPOSED, NOT WRITTEN, placed in the /*** Execution ***/ block beside :96-99
(WorkItemState.implementationReady, WorkItemState.agentExecuting): [
  GuardConditions.actorAllowed([ActorType.orchestrator]),
  GuardConditions.agentAvailable(),
],
```

The guards are copied from `designNotRequired -> agentExecuting` (`:96-99`), which is the
table's own convention for an edge *into* `agentExecuting`: those edges assert **an agent is
starting right now**, and capacity is enforced at claim time by `JobCapacityGuard`, not by a
guard on the edge (`:119-128`). **No `qaContractExists()`** — that guard belongs on the *exit*
edge (`agentExecuting -> agentCompleted`, `:102`), and adding it here would make the probe
unreachable from the scheduler, which has no `AgentResult` and no `qaContractId` to supply.

### 7.4 The collision argument, re-verified against `cc9317c`

```
triageDefectDefinition.entryStates              = {designNotRequired, designApproved, reviewRejected}
                                  (packages/scheduler/lib/src/triage_defect.dart:58-62)

defaultImplementFeatureDefinition.entryStates   = {designNotRequired, designApproved}
                                  (packages/scheduler/lib/src/scheduler.dart:1702)  [TEST-ONLY]

implementFeatureDefinition.entryStates          = {implementationReady}      <- A2
```

`RunnableWorkEvaluator` performs **no category check and no product check**: it reads
`item.state` against `definition.entryStates` and asks the policy
(`runnable_work.dart:142-163`). The same blindness is documented at
`apps/server/lib/src/triage/work_entry.dart` ("category-blind AND product-state-blind").
`Scheduler.tick` reads **every** work item — `readAllWorkItems()` at `scheduler.dart:569` —
and enqueues for every `runnable` one (`:606-641`).

**Three candidates, re-checked at this base:**

| Candidate | Verdict at `84be979` | Why |
|---|---|---|
| **B — category-aware runnable policy** | **REJECTED, not a close call** | The discriminator is **absent from the data**, not merely unused. `WorkItemCategory` has no `bug` variant (`work_item_category.dart:1-9`) and every defect-triage item is filed as `feature` (`lane_g_triage_qa_contract.dart:27`, applied at `lane_a_defect_triage_work_item.dart:252`). The source comment says so outright: *"triage reports are filed as `feature` and this contract says so"* (`:25-26`). A policy built on today's rows cannot separate them; one built to separate them would exclude **every** defect in the system. |
| **C — retarget triage's completion** | **REJECTED on timing** | The collision does not happen *after* triage completes. It happens while the item **sits at `designNotRequired` waiting for triage to start** — and that state is *manufactured on purpose*: `WorkEntryTrigger._walkToDesignNotRequired` walks `draft -> planning -> planned -> designNotRequired` specifically so dispatch will mint a triage job (`work_entry.dart:592-605`). Retargeting completion closes the wrong edge. The stronger reading of C ("triage must never occupy an implementation entry state") cannot be delivered without giving triage a state of its own — **which is candidate A.** |
| **D — one combined definition** | **REJECTED** | `SchedulerWorkload` is a single construction-time value (`scheduler.dart:23-37,322`) and `WorkloadResolver` is a single optional override (`:332`). One definition gives both lanes one `repositoryPath` and one `startingRevision`. Triage must never run in the product repository and implementation must never run in the scratch repository; one value cannot express both. It would also change the `JobType` wire contract seeded per role (`server.dart:242`, `:1126-1160`). |
| **A — a distinct implementation entry state** | **ADOPTED** | Disjoint by construction. |

**The claim, stated so it can be checked:** because `RunnableWorkEvaluator.evaluate` rejects any
item not in `entryStates` **before** the probe (`runnable_work.dart:142-144`), and because
`EntryHopper.prepare` is only reached inside the `runnable` arm
(`scheduler.dart:606-616`) and may only land on **its own** definition's entry states
(`entry_hop.dart:288-297`), **no work item can be classified `runnable` by both definitions in
the same tick, and no hop can be the mechanism that moves it between them.** That is structural:
it survives forgetting a guard because there is no guard to forget.

**Cost, stated honestly:** an operator will see a state name that is new, and §7.1 records that
the UI will mislabel it until `apps/control_plane/**` is updated. The stale brief called that a
small cost; against a UI whose default renders `awaitingReview`, **it is not small, and §8.5
escalates it rather than absorbing it.**

### 7.5 Retargeting "rework" and human-decision routes — `OD-3`, retained and sharpened

`DurableWorkflowEngine.resolveHumanDecision` derives its target from `HumanDecisionRouting.targetFor`
**alone** and takes no caller-supplied state (`human_decision_routing.dart:12-16`), so this table
— not the transition table — decides where a resolved human decision lands.

Five routes currently target `designNotRequired`, which after A2 would feed **triage only**:

| Pair | Current target | Line | Candidate A2 target |
|---|---|---|---|
| `(engineeringReview, rework)` | `designNotRequired` | `:55-56` | `implementationReady` |
| `(qaWaiver, reject)` | `designNotRequired` | `:59-60` | `implementationReady` |
| `(qaRework, reject)` | `designNotRequired` | `:61-62` | `implementationReady` |
| `(humanQaApproval, reject)` | `designNotRequired` | `:71-72` | `implementationReady` |
| `(escalation, approve)` | `designNotRequired` | `:79-80` | `implementationReady` |

**Which of these may legally move is a product decision, not an implementation detail — it
decides what "rework" means.** The stale brief's recommendation, carried forward unchanged:
`(engineeringReview, rework)` and `(qaRework, reject)` mean **re-classify** (re-triage, unchanged);
`(qaWaiver, reject)`, `(humanQaApproval, reject)` and `(escalation, approve)` mean **re-do the
work** (implementation). Rationale: a waiver rejection and a human-QA rejection are judgements
about the *result*, after classification was never in doubt; escalation-approve is a human
explicitly overriding a failure.

**Three obligations that bind REGARDLESS of the answer, and one correction to the stale brief.**

- **Correction: only TWO of the five touch `escalationTargetFor`.**
  `escalationTargetFor` returns `null` unless the choice is `reject` or `rework`
  (`human_decision_routing.dart:135-138`), and `_isEscalationTransition` short-circuits on the
  same condition before ever calling it (`durable_workflow_engine.dart:979-993`). So
  `(escalation, approve)` is **already not classified as an escalation transition** — moving its
  target from `designNotRequired` to `implementationReady` keeps it not-classified and has
  **zero** escalation-accounting effect. The stale brief's claim that all five must move in
  lockstep is wrong for three pairs. The pairs that **must** move together are exactly the two
  the table names: `(engineeringReview, rework)` (`:141-142`) and `(humanQaApproval, reject)`
  (`:143-144`).
- **Why the lockstep still matters when it applies:** the comparison is the *only* thing that
  method does at runtime, gating the `escalationIndex` increment and the `EscalationTriggered`
  audit record. A divergence **does not error** — it silently stops the escalation index
  advancing (`:98-109`).
- **Obligation A — the transition-table guard.** `waitingForHumanDecision -> designNotRequired`
  carries `blockingHumanDecisionResolved({…six pairs…})`
  (`work_item_transitions.dart:254-277`) plus an escalation bound for `engineeringReview` and
  `humanQaApproval` (`:280-284`). Any pair retargeted to `implementationReady` needs a
  `waitingForHumanDecision -> implementationReady` edge carrying the **same** guard set.
  **The stale brief missed this entirely** — without the edge, the routing table moves a work
  item to a state no edge leaves, and the resolution is refused by the engine.
- **Obligation B — the escalation bound.** `escalationIndexWithinLimitForDecisionTypes` is
  bounded for `engineeringReview` and `humanQaApproval` on the rework edge (`:195-200`, `:280-284`).
  Moving a pair must move its bound with it. Dropping a bound is a **silent relaxation**;
  inventing a bound where none existed is new policy. Both are decisions, not mechanics.

### 7.6 Where the work item comes from — the reachability half

A state nothing routes into is inert. `implementationReady` must have at least one producer, and
the candidate routes differ in kind:

- `waitingForHumanDecision -> implementationReady` (the five resolved-decision pairs above);
- `agentCompleted -> …` after review (`reviewApproved -> qaInProgress` exists;
  `qaPassed -> deploying` exists) — i.e. **the happy path runs through review and QA, and
  implementation is upstream of it, not downstream**;
- **the actual entry**: today `WorkEntryTrigger` parks a **feature** at `planned` and records
  `externalWorkEntryConsumerDependency`, because no consumer runtime exists for a feature work
  item (`work_entry.dart:542-586`; `WorkEntrySkipCodes.noConsumerForWorkEntryKind`, `:191`; the
  constant `externalWorkEntryConsumerDependency` at `:63`).
  **An implementation lane is that consumer.** Without a route from a classified work item into
  `implementationReady`, A2 builds a scheduler that never dispatches.

That route is **the reachability question**, it is a product decision about who decides an item
is ready to build, and it is `OD-10`. It is listed as a gap rather than answered, because
answering it would be inventing the entry condition for a human-owned decision.

### 7.7 The readiness probe — A2's runtime dependency on A1

`WorkloadResolver` is `Future<SchedulerWorkload?> Function(Job, WorkItem)`
(`scheduler.dart:143-144`), and `null` means exactly one thing today: `blockedArtifactMissing`
(`:763-767`), reported apart from `deferred` because *"there is nothing to review" is a
FAIL-CLOSED signal the composition root must act on (raise a blocking human decision), not
ordinary transient back-pressure* (`:298-303`, field declared at `:303`). `engineeringReviewMissingArtifact` then performs
`agentCompleted -> reviewInProgress` and raises a blocking `engineeringReview` decision
(`engineering_review_gate.dart:317-412`) — **a review action. Applying it to an implementation
job would move a work item through a gate it never entered, and would raise a human decision
about "no artifact was produced" for an item that never started.**

**So the probe must distinguish three outcomes, and `null` cannot carry them.**

| Probe result | Meaning | Required behaviour |
|---|---|---|
| product not `governed` (`product_state.dart:44`) | work may not be dispatched at all | **defer.** Never dispatch, never fail, never raise. |
| `OnboardingRecord` absent, or `!hasDurableWorkspace` (`onboarding_record.dart:157`) | A1 has not run / has not finished | **defer with a reason.** No dispatch. No human decision. |
| recorded workspace missing on disk, or `rev-parse --verify <pin>^{commit}` fails | A1's record is stale | **defer, loudly**, and record the git output. **Never substitute `HEAD`** — the `HEAD` carve-out (`repository_snapshot_acquirer.dart:432-454`) is a *resolution the sweep performs*, never a pin. |
| all satisfied | the workspace is real and at the pin | resolve to `SchedulerWorkload(repositoryPath: <recorded path>, startingRevision: <recorded pinnedRevision>)` |

**Answer to the dispatch question the brief must answer explicitly:** **yes, A2 must block on
A1 at runtime.** The readiness probe returning "no durable workspace" must produce **deferral
and no dispatch** — never a dispatch against `triageSource`, never the construction-time
workload, never `HEAD`. **Concurrent code authoring with a runtime dependency is fine;
concurrent dispatch without the workspace is not.** The code can be authored and reviewed in
parallel because the dependency is a *data* dependency on a record A1 writes, not a compile-time
dependency on A1's code — §8.2 proves that.

**The shape of the deferral is `OD-4` and it is not decided here.** Three options, none chosen:

- **(a) widen `WorkloadResolver` to a sealed `WorkloadResolution {resolved, deferred, blocked}`** —
  one meaning per result, which is the property whose absence made this defect class possible.
  Touches the review path's contract too.
- **(b) keep `null`, add a per-definition flag for which tick channel a `null` belongs to.**
  Smaller diff; the risk is that the flag is per-definition and a future definition picks wrong.
- **(c) keep `null` and let the existing `deferred` channel absorb it** — **REJECTED in this
  brief**, because it requires the construction-time `workload` to be non-null for the job to
  reach dispatch at all (`scheduler.dart:322` is a required argument), which is exactly the
  "dispatch at the wrong repository" hazard.

### 7.8 Composition-root obligations (design only — not applied by this lane)

```diff
--- a/apps/server/lib/server.dart      # PROPOSED. See §8 for WHO may write this file.
@@ composition root @@
+  // The implementer. Capabilities come from the DEFINITION, not from a list
+  // copied by hand, so "the worker can be selected for every implementation
+  // job" is true by construction — the failure a hand-copied list causes is
+  // recorded at `server.dart:191-194` for the triage worker.
+  final implementWorker = LocalWorker(
+    workerId: 'w-impl-local',
+    poolId: 'impl-pool',
+    capabilities: implementFeatureDefinition.requiredCapabilities,  // {linux, git}
+    workspaceManager: GitWorktreeWorkspaceManager(workspaceRoot: workspaceRoot),
+    executionDriver: CoordinatorAgentExecutionDriver(coordinator),
+    workerStore: workerStore,
+    platform: Platform.operatingSystem,
+  );
   final workerRegistry = WorkerRegistry()
     ..register(triageWorker)
     ..register(reviewWorker)
+    ..register(implementWorker);   // distinct workerId => distinct lease and role identity
+
+  final implScheduler = Scheduler(
+    schedulerId: 'sched-impl',
+    workflowStore: workflowStore,
+    jobStore: jobStore,
+    workerStore: workerStore,
+    dispatch: dispatch,                     // the same WorkerDispatcherAdapter (:218-220)
+    definition: implementFeatureDefinition,
+    modelSelection: modelSelection,
+    executionLiveness: executionLiveness,
+    dedupeKeyBuilder: implementFeatureDedupeKey,
+    instructionBuilder: implementFeatureInstruction,
+    requestBuilder: implementFeatureRequest,
+    capacityGuard: capacityGuard,
+    workloadResolver: implementationWorkloadResolver(/* A1's read: §7.7 */),
+    // Required constructor argument (:322). INERT: the resolver is authoritative
+    // and a deferring result prevents dispatch, exactly as for sched-review
+    // (:340-355). Never dispatched from.
+    workload: SchedulerWorkload(
+      repositoryPath: triageSource.path,     // never dispatched from — see below
+      startingRevision: triageSource.startingRevision,
+      timeoutSeconds: 1800,
+      runtimeTypeId: triageRuntimeTypeId,
+    ),
+    clock: () => DateTime.now().toUtc(),
+    providerHealthMonitor: providerHealthMonitor,
+  );
```

Mandatory non-obvious details, each argued:

- **`timeoutSeconds: 1800`, not `300`.** Both shipped schedulers use 300 (`:312`, `:351`).
  An implementation run is not a five-minute classification. `zombieStalenessBound` is
  `timeoutSeconds * 4 + claimLease` (`scheduler.dart:436-444`), so this also sets the reclaim
  bound — the value that produced a multi-hour zombie when it was wrong.
- **The static `workload` above is inert and must stay inert.** It is required by the
  constructor (`:322`) and is documented as inert for `sched-review` at `:346-348`. The
  `repositoryPath` shown is `triageSource.path` because it must name *a* real repository to
  satisfy the type; **if the readiness probe ever falls through to it, §4.2's fabrication
  hazard becomes live.** §9.2 row 1 is the test that proves it cannot.
- **A dedicated `VerificationPlan`, pinned deliberately.** The default is `dart test`, which
  **cannot** pass in a triage worktree — that checkout has only `README.md`, no `pubspec.yaml`,
  no `test/` — and the failure turned every successful triage job into `executedFail`
  (`server.dart:728-755`). The product repository has both, so the default becomes correct for
  the first time; **"would work" is still not a decision**, so the plan is pinned at the
  composition root. Failure must land at `agentFailed` and must **not** stamp `producerActorId`
  (`execution_coordinator.dart:782-812`), because the verification-failure branch deliberately
  omits the `metadataMerge` (`:796`) while the success branch sets it (`:838`).
- **No `blockedArtifactMissing` handler for `sched-impl`.** `engineeringReviewMissingArtifact`
  is a review action (§7.7). The deferral path is `OD-4`.
- **No `agent_completed` retrofit for the stranded items.** §9.4.

### 7.9 What A2 must NOT do

1. **Must not widen `triageDefectDefinition.entryStates`.** It is correct, load-bearing, and has
   an independently-reviewed decision behind it (`2acb7fc`; documented at
   `triage_defect.dart:8-53`).
2. **Must not repurpose `defaultImplementFeatureDefinition`.** §7.2.
3. **Must not set `skipWorkflowPolicyCheck: true`.** The probe can succeed here; skipping it
   discards a real check.
4. **Must not move `escalationTargetFor` separately from `targetFor`.** §7.5.
5. **Must not omit the `waitingForHumanDecision -> implementationReady` edge and its guard set.**
   §7.5, Obligation A.
6. **Must not dispatch from `triageSource` or from `HEAD`.** §4.2, §7.7.
7. **Must not touch `apps/server/lib/src/baseline/**`, `credentials/**` or `docker/**`.** §8.

### 7.10 Review-ability matrix — what an independent reviewer can check, and how

| # | Claim | How it is checked | Fails if |
|---|---|---|---|
| R-1 | Entry sets are disjoint | A test asserting `implementFeatureDefinition.entryStates ∩ triageDefectDefinition.entryStates == {}` **plus** the same for every other production definition | Any shared state |
| R-2 | The new state is not a stranding state | `entry_hop_drift_guard_test.dart` (add the definition) + `transition_consistency_test.dart` | The state is listed but has no legal route to `agentExecuting`, or the mirror disagrees |
| R-3 | A deferring probe never dispatches | Construct a `Scheduler` with a resolver that returns "no durable workspace" for **every** item; assert `dispatched == []`, `blockedArtifactMissing == []`, and that no `LocalWorker` was prepared | A dispatch, or a `blockedArtifactMissing` entry |
| R-4 | The fabrication hazard is closed | Point `sched-impl` at a workspace that does not exist; assert no dispatch **and** that the static `workload.repositoryPath` was never used | Any dispatch using `triageSource` |
| R-5 | Routing retargets keep the escalation index moving | A test over `HumanDecisionRouting.routesTo` / `routesToEscalation` for the two lockstep pairs, plus the transition-table guard set | `targetFor` moved and `escalationTargetFor` did not |
| R-6 | The UI does not lie about the new state | **Cannot be satisfied inside A2's map** — §8.5 | Recorded as a gap, not hidden |
| R-7 | A1/A2 do not overlap | Path sets compared by the Manager before dispatch (§8.1) | Any shared path |
| R-8 | A2's own sources are product-agnostic | A2-owned test over `apps/server/lib/src/implementation/**` and its new `packages/scheduler/**` file, applying `product_agnosticism_test.dart`'s own rule: no product name, no host, no absolute-path default (§8.2/collision 3) | Any occurrence |

**R-6 is the one this brief cannot deliver and does not pretend to.** `apps/control_plane/**` is
READ-ONLY for both units, and the UI's state mapping defaults a new state to `awaitingReview`.

---

## 8. The split — disjoint path map, and the concurrency verdict

### 8.1 Path map

| Path | A1 | A2 | Note |
|---|:--:|:--:|---|
| `apps/server/lib/src/baseline/**` | **OWN** | — | durable-workspace lane + runtime; includes `product_agnosticism_test.dart` (§6.7) |
| `apps/server/lib/src/credentials/**` | **OWN** | — | the durable materialiser + trust primitives |
| `apps/server/lib/src/persistence/**` | *(provisionally none — §6.9)* | — | re-scoped through review if needed |
| `docker/**` | **OWN** | — | the volume / mount from §6.3 |
| `packages/platform_contracts/lib/src/enums/workflow_state.dart` | — | **OWN** | **required; see §8.4** |
| `packages/platform_contracts/lib/src/types/workspace_descriptor.dart` | **OWN** *(if `OD-8` = relax or kind)* | — | see §8.4 |
| `schemas/workspace_descriptor.schema.json`, `schemas/onboarding_record.schema.json` | **OWN** *(if `OD-8` ≠ new type)* | — | see §8.4 |
| `packages/scheduler/**` | — | **OWN** | new definition + drift-guard registration |
| `packages/workflow_engine/**` | — | **OWN** | new state mirror, new edge, routing retargets |
| `packages/workflow_store/**` | — | **OWN** | only if the escalation/rework reader changes |
| `packages/product_registry/**` | **read-only** | — | `recordWorkspace` / `completeOnboarding` already exist; **A1 calls, does not change** |
| **`apps/server/lib/server.dart`** | **—** | **OWN** | **the single shared seam; §8.3** |
| `apps/control_plane/**` | — | — | **neither** — READ-ONLY for both; §8.5 |

### 8.2 The three candidate collisions, tested one at a time

**Collision 1 — the composition root. NOT DISJOINT AS DISPATCHED. This is the answer to the
question, stated plainly.**

The dispatch named `apps/server/lib/src/scheduler.dart` as A2's composition file. **That file
does not exist.** The composition root is `apps/server/lib/server.dart`, and it is where both
units must write:

- A1 must resolve the durable-workspace root and register the runtime — the analogue of
  `BaselineProductionRuntime.resolve(...)` at `server.dart:401-407`;
- A2 must register the implement worker and `sched-impl` — the analogue of `server.dart:195-220`
  and `:281-356`;
- and per §6.7, **the environment-variable read that A1's lane must not contain has to happen in
  this file**, because the agnosticism gate forbids `SHIPIT` in `lib/src/baseline/**`.

**Two agents cannot write one file.** `AGENTS.md` (concurrency invariant) and
`docs/engineering/WORKFLOW.md` both forbid overlapping ownership between concurrent writers, and
this is not a technicality: two writers of a 1300-line composition root produce a merge that no
reviewer has reviewed as a unit, and this file is where the §4.2 fabrication hazard is wired.

**Resolution — one owner, and the order is already forced by the runtime dependency.** Assign
`apps/server/lib/server.dart` **exclusively to A2**, with one obligation attached: *after A1's
runtime factory exists, A2 adds the A1 wiring lines in the same composition pass.* This works
because of a property verified above, not assumed:

> **A1's runtime must be constructible without `server.dart`.** A1 ships a factory — the exact
> shape `BaselineProductionRuntime.resolve` already has — that takes its `ProductRegistryEngine`,
> store, job store and log as parameters. That is precisely how the baseline runtime is
> integration-tested today without the server: `baseline_dispatch_integration_test.dart:57` and
> `:749` both call `BaselineProductionRuntime.resolve(...)` directly. **A1's own gates therefore
> run without `server.dart`, and A2 can write and review its composition against A1's declared
> factory signature before A1's code exists.**

**Collision 2 — `docker/**`. DISJOINT.** A2 needs no compose change: it never creates a clone,
only reads A1's recorded path. `docker/**` is A1's alone.

**Collision 3 — the agnosticism gate. DISJOINT, and the design had to earn it.**
`apps/server/lib/src/baseline/product_agnosticism_test.dart` cross-checks
`_laneDirectorySources` against `_laneSources` (`:170-199`), so **any new A1 file in that
directory breaks the gate unless A1 lists it.** A1 owns the file, so it is self-contained.
The residual hazard is the reverse direction: if A2's implementation resolver is placed under
`lib/src/baseline/`, A2 would have to edit an A1-owned test. **Therefore A2's resolver MUST live
outside `lib/src/baseline/`, `credentials/` and `persistence/`.** Proposed home:
`apps/server/lib/src/implementation/**` (new), A2-owned. It is not covered by the agnosticism
gate, which means **A2 inherits the product-agnosticism discipline without the mechanical
enforcement** and must assert it itself — recorded as review-matrix row **R-8** (§7.10).

**A2's new scheduler file has the same problem in miniature:** `packages/scheduler/**` is not
covered by the gate either (only `baseline_product.dart` and `baseline_dispatch.dart` are listed,
`:134-151`). Same obligation.

### 8.3 VERDICT — genuinely concurrent-safe, with two conditions

> **Yes, A1 and A2 are genuinely concurrent-safe**, subject to:
>
> **(C-1)** `apps/server/lib/server.dart` is assigned **exclusively to A2**, and A2 adds A1's
> wiring lines after A1's factory exists. A1 touches it not at all.
> **(C-2)** A1's runtime is **constructible without `server.dart`** — a `resolve(...)`-shaped
> factory taking its dependencies as parameters, modelled on `BaselineProductionRuntime`.
>
> Both are design constraints this brief imposes, not hopes. If an implementer of A1 reaches for
> `server.dart` to register the runtime, **C-2 is violated and the two units stop being
> concurrent-safe**, because A2 would then hold a dependency it cannot compile until A1's
> branch lands.

**What concurrency-safe means here, precisely:**

| Property | Holds? | Why |
|---|---|---|
| Disjoint owned paths | **Yes**, after `C-1` and after assigning the three unassigned paths in §8.4 | §8.1 |
| No compile-time dependency either direction | **Yes** | A1 calls `recordWorkspace`/`completeOnboarding`, which already exist (`f164d40`). A2 reads `readOnboardingForProduct`, which already exists (`postgres_product_registry_store.dart:1062-1071`). **Neither unit waits for the other's code to exist in order to compile or to pass its own tests.** |
| A runtime dependency exists | **Yes — deliberately** | A2's readiness probe reads a record A1 writes (§7.7). |
| Concurrent **dispatch** without the workspace | **No, and must not happen** | The probe must defer, never dispatch (§7.7). This is a *runtime* ordering requirement, satisfied by the probe and testable by review-matrix row R-3. |
| Independent review of each unit is possible | **Yes** | A1: lane + materialiser + gate + compose. A2: state + edge + definition + routing + probe + compose. |

**So: concurrent code authoring, concurrent review, and serialized *integration of the one shared
file*.** That last clause is the honest cost and it is small — it is two call lines in a file
one of the units already owns.

### 8.4 Paths neither candidate list covers, which A2 therefore needs added

The dispatch's candidate list is incomplete against the code. Three additions are required and
are part of this revision's deliverable:

| Path | Needed by | Why the candidate list missed it |
|---|---|---|
| `packages/platform_contracts/lib/src/enums/workflow_state.dart` | **A2** | `WorkItemState` is declared here (`:1-30`), not in `workflow_engine`. The dispatch said "add a state to `WorkItemState`" without naming the file. |
| `packages/platform_contracts/lib/src/types/workspace_descriptor.dart` + `schemas/*.schema.json` | **A1**, *if* `OD-8` resolves to relax-or-kind | `OD-8` is escalated precisely because this shape is wrong. If the human picks (c) — a second type — the cost moves to a new schema file instead. **Not granted pre-emptively; granted per the `OD-8` answer.** |
| `apps/server/lib/src/implementation/**` | **A2** | §8.2/collision 3: the resolver must not live in an A1-owned directory. |

### 8.5 The gap neither unit may close — recorded, not absorbed

`apps/control_plane/**` is READ-ONLY for both units and for this design lane. Against it:

| UI surface | Current behaviour for an unknown state | Consequence |
|---|---|---|
| `apps/control_plane/lib/core/plain_language.dart:110-135` | `switch` default `_ => PlainStatus.awaitingReview` (`:135`) | An item at `implementation_ready` renders **"awaiting review"** — false, and on a screen with listeners |
| `apps/control_plane/lib/shared/transition_copy.dart:26-95` | `_ => null` (`:94`) → `kUnknownTransitionMessage` | Every transition into and out of the new state renders **"The work moved to a new stage."** |

**Options: (i) grant A2 the two UI files, (ii) add a third lane owning them, (iii) ship A2 with
the mislabel and accept it.** This brief recommends **(i)** — two map entries and two switch
cases — and flags that (iii) means an operator is told an unbuilt item is awaiting review, which
is the same class of false statement this whole brief exists to prevent (§4.2). **It is the
operator's call, and it is listed in §12.3.**

---

## 9. Failure and verification

### 9.1 What must be true for review to dispatch rather than fail closed

Re-verified end to end at this base:

| # | Precondition | Evidence |
|---|---|---|
| 1 | Item reaches `agentCompleted` | `engineeringReviewDefinition.entryStates = {agentCompleted}` (`scheduler.dart:1863`) |
| 2 | `agentExecuting -> agentCompleted` passes `qaContractExists()` | edge `work_item_transitions.dart:100-104`; guard reads `context?['qaContractId'] != null` (`guard_conditions.dart:237-255`, read at `:247`) |
| 3 | …which requires the work item to carry a `qaContractId` | the coordinator supplies it **only when non-null**: `if (item.qaContractId != null) 'qaContractId': item.qaContractId` (`execution_coordinator.dart:830`) |
| 4 | …and `agentResultValid()` — `AgentResult.status == completed` | `work_item_transitions.dart:103`; `guard_conditions.dart:218-233` |
| 5 | Platform verification did not fail | `verificationFailed = verification?.status == failed` → routes to `agentFailed` (`execution_coordinator.dart:782-806`) |
| 6 | `producerActorId` stamped on the item | `metadataMerge: {'producerActorId': stamped.executionId}` — **success branch only** (`:838`); the verification-failure branch deliberately omits it (`:796`) |
| 7 | Exactly one worker execution with `agentExecutionId == producerActorId`, not a reviewer | resolver filters on it and requires `matches.length == 1` (`engineering_review_gate.dart:64-67`) |
| 8 | That execution's `endingRevision != null && != requestedStartingRevision` | `engineering_review_gate.dart:71-73` |
| 9 | …so the implementer must produce a real commit | `LocalWorker` commits for every non-reviewer role (`local_worker.dart:280-305`) |
| 10 | …and the repository holding that commit **still exists at review time** | resolver re-reads `producer.repositoryPath` (`engineering_review_gate.dart:75`); the worktree manager re-validates the revision **in it** (`git_worktree_workspace_manager.dart:85-96`) — **this is the durability requirement of §2.4 restated as a gate** |

**Precondition 3 is the non-obvious one and it is a hard blocker for any implementation lane.**
A work item with `qaContractId IS NULL` can never reach `agentCompleted`, on any future
execution, with nothing repairing it. Triage provisions its contract at intake
(`lane_a_defect_triage_work_item.dart:257`) and has a backfill for pre-contract items (`:336-370`,
guard `if (item.qaContractId != null) return item;` at `:346`). **A feature work item created by
`createFeatureWorkItem` carries no `qaContractId` at all** (`control_plane_service.dart:818-850`).
So every item A2 dispatches would stall at `agentExecuting` for ever. **OD-5.**

### 9.2 Failure paths, and what each must do

| # | Failure | Mechanism | Required behaviour | Covered by |
|---|---|---|---|---|
| 1 | **Fabrication guard.** No durable workspace, probe defers | §7.7 | **No dispatch.** Never the construction-time `workload`, never `HEAD`. Never `blockedArtifactMissing`. | R-3, R-4 |
| 2 | Product not `governed` | `product_state.dart:44`; `ProductState`'s own text is *"Work may be dispatched for this product"* | **Defer.** Never dispatch, never fail, never raise a decision. | §7.7 |
| 3 | A1 recorded a workspace that is gone or at the wrong commit | §7.7 | **Defer loudly**, record the `git rev-parse --verify` output. Never substitute `HEAD` — that carve-out (`repository_snapshot_acquirer.dart:432-454`) is a *resolution*, never a pin. | §7.7 |
| 4 | No custody substrate | `baseline_runtime.dart:72-97` pattern | Runtime reports `unavailable` **with a reason at startup** and constructs the lane inert, never half-wired. A sweep with no custody could only ever return "unresolvable" for every product — *"a pass that examined everything and enqueued nothing"* (`:88-96`). | §6.4 |
| 5 | Implementer writes nothing | `ArtifactCommitOutcome.none()` (`artifact_committer.dart:118-122`) | `endingRevision` stays null → resolver returns null → review fails closed. **Correct today; must stay.** | R-4 |
| 6 | Artifact commit fails after files were written | `ArtifactCommitOutcome.failed` (`artifact_committer.dart:31-33,150-152`) | Run is **not** aborted; emitted as a worker event and never swallowed (`local_worker.dart:292-304`). Review then fails closed on a null/matching revision. | — |
| 7 | Platform verification fails | `execution_coordinator.dart:782-812` | `agentFailed`, **no `producerActorId`** (`:796`). Operator retry returns it via `agentFailed -> designNotRequired` (`work_item_transitions.dart:129-131`) → re-triage. | §7.8 |
| 8 | Item left `agentExecuting` between claim and dispatch | coordinator raises `WorkItemSupersededException` (`execution_coordinator.dart:277`) | Audit record preserved in transition history. With A2 the two-lane version of this is structurally unreachable (§7.4). | R-1 |
| 9 | Job queued but the item left the entry states | `_retireSupersededForItem` (`scheduler.dart:1647-1671`) | Job `cancelled` with an explicit reason, **not `failed`** — a `failed` would assert an execution that never happened. | — |
| 10 | A retained snapshot tree accumulates forever | §6.5 | **Pre-existing and out of scope.** Flagged as `OD-9`, not inherited by A1, not silently fixed. | §6.5 |

### 9.3 Verification

The load-bearing difference from triage is the `VerificationPlan`: its **failure** must reach
`agentFailed` and must not stamp `producerActorId`; its **success** must reach `agentCompleted`
and must stamp it. Those two branches (`execution_coordinator.dart:782-838`) are the only place
the distinction is made, and the design's obligation is to make the implementation lane land in
the right one every time. A plan that fails softly would produce an item that is reviewed with
no `producerActorId`, which fails closed at precondition 6 — **visible and correct**. A plan that
is absent would let `executedFail` runs reach `agentCompleted` by another route, which is not.

### 9.4 The stranded `agent_completed` items — explicitly not fixed by this design

Work items at `agent_completed` with no artifact will continue to fail closed. Retrofitting them
means hand-authoring a commit and a `producerActorId`.

**That is manufacturing the evidence engineering review exists to test**, and it is strictly
worse than stranding: a reviewer receiving such an item is reviewing a fabrication, and the
verdict it returns is not a false negative — it is a false positive on work nobody did. They stay
behind the existing fail-closed human decision.

Stated here so no implementer reads "add an implementation lane" as "also clear the backlog".

---

## 10. Decisions taken in this brief

Each is a decision this brief **makes**, with the evidence it rests on. Open questions are §11.

| # | Decision | Rests on |
|---|---|---|
| **D-1** | `OD-1` is resolved as moot. The design needs no performed hop and `cc9317c` makes that a test-enforced property, not an intention. | §1.2; `entry_hop_drift_guard_test.dart:14-24` |
| **D-2** | **The stale brief's workspace-resolution step is deleted, not amended.** `currentBaselineRevision` is a sequence counter (`onboarding_record.dart:71-74`; `product_registry_store.dart:150-151`) and cannot be resolved, verified or dispatched against. | §1.3 |
| **D-3** | **Workspace creation is a prerequisite of implementation, not a derivation from the baseline.** A1 is a separate unit. | §2, §4.1 |
| **D-4** | **Durable-workspace location: a Docker named volume**, mirroring `triage_repo_qa` at the same mount site; **W-B (host bind mount) is the documented production variant; W-C (container-ephemeral) is rejected** because it destroys the artifact. | §6.3 |
| **D-5** | **The durability requirement is stated as "survives container restart", not "survives `make qa-down`".** `qa-down` is the documented teardown of the QA stack (`Makefile:90-92`), and claiming a volume survives it would be an over-claim. | §6.3 |
| **D-6** | **A1 does not build its clone through `RepositorySnapshotAcquirer` + retain.** It composes the trust primitives with its own materialiser. Three independent reasons, §6.4. | §6.4 |
| **D-7** | **Credential custody is unchanged and out of scope.** The private half is destroyed first and unconditionally (`repository_snapshot_acquirer.dart:867-882`); a durable clone carries no credential. `OD-2` **withdrawn**. | §1.3, §6.4 |
| **D-8** | **Snapshot retention is flagged, not inherited and not fixed.** Three distinct objects, three distinct reclaimer responsibilities (§6.5). | §6.5 |
| **D-9** | **A new `WorkItemState` and the routing retargets are the ONLY lifecycle change in this design, and they sit in A2 alone.** A1 changes no lifecycle state. | §4.3 |
| **D-10** | **`implementFeatureDefinition.entryStates = {implementationReady}`, a one-element set, with no `entryProbeTargets`.** Disjointness is structural. | §7.2, §7.4 |
| **D-11** | **`defaultImplementFeatureDefinition` is NOT repurposed.** It is `const`, test-only in production, and used by ~20 test files. A sibling definition is added. | §7.2 |
| **D-12** | **The direct edge `implementationReady -> agentExecuting` is added**, with the guards copied from `designNotRequired -> agentExecuting`, and **without** `qaContractExists()`. | §7.3 |
| **D-13** | **Only two of the five rework pairs need `escalationTargetFor` lockstep**, not five. `escalationTargetFor` returns `null` unless the choice is `reject`/`rework` (`human_decision_routing.dart:135-138`; `durable_workflow_engine.dart:979-993`). **The stale brief was wrong on this and the correction is load-bearing.** | §7.5 |
| **D-14** | **A `waitingForHumanDecision -> implementationReady` edge with the same `blockingHumanDecisionResolved` guard set is an obligation**, whatever `OD-3` answers. **The stale brief missed this entirely.** | §7.5, Obligation A |
| **D-15** | **A2 blocks on A1 at runtime**: no durable workspace ⇒ defer, no dispatch, no human decision, never `HEAD`, never `triageSource`. | §7.7 |
| **D-16** | **`apps/server/lib/server.dart` is assigned exclusively to A2** (the file named in the dispatch, `apps/server/lib/src/scheduler.dart`, does not exist), with the two conditions in §8.3. | §8.2, §8.3 |
| **D-17** | **`packages/platform_contracts/lib/src/enums/workflow_state.dart` is added to A2's map**, and `apps/server/lib/src/implementation/**` is added as A2's resolver home. | §8.4 |
| **D-18** | **The product-agnosticism gate is treated as a design obligation, not a test to satisfy later**: A1's env-var read must happen in the composition root, not in `lib/src/baseline/`. | §6.7 |
| **D-19** | **Stranded `agent_completed` items are out of scope** and stay fail-closed. | §9.4 |

---

## 11. Open decisions — escalated, not decided

None of these is decided here. Each is stated with the evidence that frames it, a recommendation
the human may accept or overrule, and what it blocks.

### `OD-1` — ~~is `EntryHopper` in our base?~~ **RESOLVED, MOOT** (§1.2, `D-1`)

### `OD-2` — ~~may the platform hold a durable clone with custody consequences?~~ **WITHDRAWN** (§1.3, `D-7`)

### `OD-3` — which rework pairs mean "re-do the work" rather than "re-classify"?

**Question.** For `(engineeringReview, rework)`, `(qaWaiver, reject)`, `(qaRework, reject)`,
`(humanQaApproval, reject)`, `(escalation, approve)` — does the resolved decision send the item
to **triage** (re-classify, unchanged) or to **implementationReady**?

**Evidence.** All five currently target `designNotRequired`
(`human_decision_routing.dart:55-56,59-60,61-62,71-72,79-80`), which feeds both lanes today.
The meanings genuinely differ: `qaRework/reject` is QA-derived and arguably wants
re-classification, while `escalation/approve` is a human explicitly saying "run it again".

**Recommendation.** `(engineeringReview, rework)` and `(qaRework, reject)` → **re-triage**
(unchanged meaning). `(qaWaiver, reject)`, `(humanQaApproval, reject)`, `(escalation, approve)` →
**implementation**. Rationale: waiver-rejection and human-QA-rejection are judgements about the
*result*, after classification was never in doubt; escalation-approve is a human overriding a
failure.

**Obligation regardless of the answer** — `D-13` and `D-14`: only `(engineeringReview, rework)`
and `(humanQaApproval, reject)` must move `escalationTargetFor` in lockstep, and the
transition-table guard set must follow.

**Blocks:** A2's routing edits. **Does not block:** A2's state, edge, definition, readiness probe.

### `OD-4` — how does the implementation lane say "deferred, not blocked"?

**Question.** `null` from `WorkloadResolver` means exactly one thing today:
`blockedArtifactMissing` (`scheduler.dart:763-767`), documented as a fail-closed signal the
composition root must turn into a blocking human decision (`:298-303`, field declared at `:303`). A product that has not
been onboarded is a **waiting state, not a fault**; raising a decision for it on every tick is
noise, and `engineeringReviewMissingArtifact` is the wrong handler because it is a review action
(§7.7).

**Options.** (a) widen `WorkloadResolver` to a sealed `WorkloadResolution {resolved, deferred,
blocked}` — one meaning per result, at the cost of touching the review path's contract too;
(b) keep `null` and add a **per-definition** flag for which tick channel a `null` belongs to;
(c) keep `null` and let `deferred` absorb it — **rejected here**, because the construction-time
`workload` is a required constructor argument (`:322`) and would become the dispatch path.

**Recommendation.** (a). One meaning per result is the property whose absence made this defect
class possible; a second consumer of the same `null` is how it recurs. **(b) is acceptable if the
reviewer prefers a smaller diff — but the flag must be per-definition, never global.**

**Blocks:** A2's composition. **Does not block:** A1 entirely.

### `OD-5` — must the implementation lane provision a QA contract, or refuse to dispatch items without one?

**Question.** `agentExecuting -> agentCompleted` carries `qaContractExists()`
(`work_item_transitions.dart:102`; `guard_conditions.dart:247`), and the coordinator supplies
`qaContractId` only when the item has one (`execution_coordinator.dart:830`). An item without one
is **permanently stuck** — refused on every future execution, with nothing repairing it. A feature
work item created by `createFeatureWorkItem` carries none (`control_plane_service.dart:818-850`).

**Recommendation.** Gate dispatch on a resolvable `qaContractId`, and reuse the triage backfill
shape (`lane_a_defect_triage_work_item.dart:336-370`, guard `if (item.qaContractId != null)
return item;` at `:346`) for items that lack one.

**But note the dependency, which is the actual content of this decision:** a `qa_architect` lane
must exist to *produce* that contract, or the gate can never open. **Whether this brief may assume
that lane is in scope is itself part of the question.** If it may not, A2 can ship with the gate
closed and dispatch nothing — safe and useless — or ship without the gate and strand every item,
which is neither.

**Blocks:** A2's dispatch behaviour. **Does not block:** A1 entirely.

### ~~`OD-6` — the verification plan~~ **DOWNGRADED** to a composition-root obligation (§7.8)

### `OD-7` — where exactly does the durable clone live, and what bounds it?

**This is the most important open question in the revision.** The dispatch named it as such and it
is named so here.

**Question.** Three parts, all consequential:

1. **Named volume (W-A) or host bind mount (W-B)?** The recommendation is W-A for the
   compose-managed stacks, W-B documented as the production variant (§6.3).
2. **How long does a durable clone live?** Unlike every other clone in this platform it has a
   **product** lifetime, not an execution lifetime. `WorkspaceDescriptor.markCleaned(at)` exists
   for the "no longer there" transition (`workspace_descriptor.dart:51-62`) and
   `OnboardingRecord.hasLiveWorkspace` reads it (`onboarding_record.dart:150`) — **but nothing
   produces a cleaned durable descriptor, so there is no policy.**
3. **Who deletes one?** Onboarding a new product? Offboarding
   (`ProductState.archived`, `product_state.dart:58`)? A human action? **Today, nothing.**

**Evidence.** §2.4 (why it must not be ephemeral), §6.3 (the three options and what each buys),
§6.5 (the three distinct objects and their three distinct reclaimer responsibilities).

**Recommendation.** W-A for compose-managed stacks, with an explicit **`OD-7.2` policy**: a
durable clone is reclaimed when its product leaves `governed` for `archived`, and never before.
That uses the existing lifecycle rather than inventing a timer, and it is the only bound that
ties a disk cost to a fact the platform already records. **`OD-7.3` (who presses it) should be a
human action, not a sweep** — deleting a product's only checkout is not a machine decision.

**Blocks:** A1's compose change and its reclamation path. **Does not block:** A2 entirely.

### `OD-8` — `WorkspaceDescriptor` is per-execution; a durable clone is per-product. What shape?

**Question.** Three required fields of `WorkspaceDescriptor` — `workerExecutionId`, `workerId`,
`worktreePath` — have no meaning for a product-scoped durable clone, and all three are `required`
in both JSON Schemas (`schemas/workspace_descriptor.schema.json:8-16`;
`schemas/onboarding_record.schema.json:39-47`) and conformance-tested
(`contract_schemas_test.dart:59-60`). Which way does it go? §6.2 sets out (a) relax to nullable,
(b) add an explicit `kind`, (c) a second type.

**Recommendation.** **(b) — an explicit `kind` discriminator with a per-kind validation rule.**
(a) is the smallest diff but leaves one type meaning two things, which is how
`escalationTargetFor` and `targetFor` came to disagree in this repository
(`human_decision_routing.dart:98-109`). (c) is the cleanest model and is the one migration
`20261012213045000` explicitly rejected, in its own header, for good reason.

**Why it is escalated rather than decided.** It changes a published JSON Schema and a published
contract suite, and `AGENTS.md §12` is the section that makes a *baseline's* own claims
independently checkable. A change to the descriptor that describes a product's pinned workspace
belongs in front of a human rather than behind one.

**Blocks:** A1's persistence writes. **Does not block:** A2 entirely.

### `OD-9` — who reclaims a retained snapshot tree, and when?

**Question.** `SnapshotReleaseDisposition.treeRetainedForArtifact` says in bold that *"the
caller owns reclaiming it"* (`repository_snapshot_acquirer.dart:177`) and that *"anything that
bounds it — how long, and who reclaims — has to be a decision made by whoever owns the artifact's
lifecycle"* (`:179-182`). **Verified: nothing reclaims one. Retention is unbounded and unowned
today.**

**Recommendation.** **Do not fix it here.** It is pre-existing, orthogonal to A1 and A2, and
fixing it would put a snapshot-lifecycle change inside a design about a different object. File it
against the snapshot lifecycle and give it its own lane with its own bound.

**Blocks:** nothing in this design. **Recorded because A1 must not inherit it silently** (`D-8`).

### `OD-10` — what puts a work item into `implementationReady`?

**Question.** A state nothing routes into is inert. `WorkEntryTrigger` currently parks a
**feature** at `planned` and records `externalWorkEntryConsumerDependency` because no consumer
runtime exists (`work_entry.dart:542-586`; the constant at `:63`). **An implementation lane is
that consumer** — so this design closes a gate a human decision opened (a feature against an
ungoverned product is accepted and parked, never refused; `control_plane_service.dart:809-817`) —
but *who decides* an item is ready to build is a product decision, and the answer determines
whether the lane is supervised or autonomous.

**Recommendation.** **Route from the human-decision resolution set only** — i.e. the `OD-3`
retargets — and add **no** autonomous producer in this design. That keeps the first implementation
lane supervised by construction, which is the right default for the first time a lane writes
code. Adding an autonomous producer is a separate decision, once the supervised path has been
observed.

**Blocks:** whether A2 dispatches anything at all. **Does not block:** A2's code.

---

## 12. Risk assessment — **Level 3**, and the approval being requested

`DESIGN_GOVERNANCE.md:99` (Level 3 — *Change to core workflow, navigation structure, or
information architecture affecting multiple features or user mental models*) requires
**product/design/architecture approval**. This design qualifies on four independent grounds, and
they are stated separately so a reviewer can disagree with any one of them without discarding the
rest.

### 12.1 Why Level 3, argued

1. **A state is added to the platform's core lifecycle.** `WorkItemState`
   (`platform_contracts/lib/src/enums/workflow_state.dart:1-30`) is the single enum every
   component obeys: the scheduler's entry sets, the coordinator's edges, the workflow store, the
   control-plane API, and the operator UI. Adding a value changes what "a work item exists" means
   platform-wide, not for one feature.
2. **The transition table every other component must obey gains an edge.**
   `work_item_transitions.dart` is the authority; `RunnableWorkEvaluator` asks it and never
   reimplements it (`runnable_work.dart:152-163`). A new edge changes what every future
   `JobDefinition` may declare.
3. **Human-decision routes are retargeted**, which changes what *"rework"* and *"reject"* mean to
   a human resolving a gate — across **five** decision/choice pairs spanning four decision types
   (`human_decision_routing.dart:55-56,59-60,61-62,71-72,79-80`), plus a guard-set change on the
   matching transition (`work_item_transitions.dart:256-284`).
4. **The escalation audit trail changes shape** if `D-13` is implemented as specified — and the
   failure mode of getting it wrong is **silent**: `escalationTargetFor` "does not error — it
   silently stops the escalation index advancing" (`human_decision_routing.dart:105-109`).

### 12.2 Levels considered and rejected, so the rating is not asserted

| Level | Why not |
|---|---|
| **0** — Implementation Correction | It changes a lifecycle enum, a transition table, and five routing entries. Nothing here "can be resolved in implementation without design revision". |
| **1** — Design-System Correction | No token, component or pattern changes. The UI gap in §8.5 is a *consequence*, not the subject. |
| **2** — Feature UX Change | A single-feature reading is available — the control plane's work-item screens gain a state — and it is rejected because the change is to the **governance model every future feature inherits**, not to one feature's flow. A reviewer may reasonably land on 2; that disagreement is invited rather than defended against. |

### 12.3 The approval request — what the human and the reviewer are being asked to accept

> **APPROVAL REQUESTED — RISK LEVEL 3**
>
> **What is being approved.** A design, in two units, that together make an implementation lane
> possible: **A1** creates a durable, product-scoped, credential-mediated workspace and records
> it; **A2** adds a supervised implementation scheduler that will, for the first time in this
> platform, have an autonomous agent **write production code**.
>
> **What the human is specifically accepting:**
>
> 1. **A new `WorkItemState` (`implementationReady`) and a new transition edge** into the
>    platform's core lifecycle enum and table. *Alternative considered and rejected:* reuse
>    `designNotRequired` and add a guard — which cannot work, because the collision is
>    structural and a guard is procedural (§7.4).
> 2. **Retargeting up to five human-decision routes**, changing what "rework" and "reject" mean
>    across four decision types. The specific split recommended — and the specific pairs that
>    must move `escalationTargetFor` in lockstep (`OD-3`, `D-13`) — is a **product decision**, and
>    it is the one most worth overruling if the human reads "rework" differently than this brief does.
> 3. **A durable, product-scoped clone of every governed product's repository on shared storage**
>    (`OD-7`). The brief's recommendation is a Docker named volume with a lifecycle-bound
>    reclamation policy; a host bind mount is defensible for production; container-ephemeral is
>    **not**, and the brief says why (§6.3).
> 4. **A change to a published JSON Schema** — `WorkspaceDescriptor` currently cannot describe a
>    product-scoped workspace without fabricating three fields that have no meaning (`OD-8`).
> 5. **A visible defect shipped knowingly if `apps/control_plane/**` is not granted to A2**: an
>    item at `implementation_ready` renders **"awaiting review"** in the operator UI, because that
>    file's `switch` defaults unknown states to `awaitingReview`
>    (`plain_language.dart:110-135`). **The brief recommends granting A2 those two files.**
> 6. **That the first implementation lane is supervised, not autonomous** (`OD-10`) — it
>    dispatches only from resolved human decisions. If the human wants autonomous dispatch, that
>    is a different design and this one should not be stretched to cover it.
>
> **What the reviewer is being asked to check, beyond the above:** the disjointness argument in
> §7.4 against `cc9317c`; the two lockstep corrections in `D-13`/`D-14`; the composition-root
> ownership call in §8.2-8.3; and whether `D-8` (flag, do not inherit, do not fix the retained-tree
> leak) is the right call or a deferral dressed as a decision.

---

## 13. Traceability

### 13.1 Requirements covered

| ID | Requirement | Where | Notes |
|---|---|---|---|
| `IMPL-001` | An implementation lane exists and is wired | §7.1-7.3, §7.8 | A2. Blocked in practice by `OD-5` and `OD-10`, both stated. |
| `IMPL-002` | The workspace is real, durable, and credential-mediated | §2.2-2.4, §6.1-6.4, §6.7 | A1. Product-agnostic with a **mechanical** gate (§6.7). |
| `IMPL-003` | Engineering review dispatches instead of failing closed | §3, §9.1 | Verified end to end; `IMPL-003` additionally requires `OD-5` to be answered. |
| `IMPL-004` | No concurrent double-dispatch onto one work item | §7.4, §8.1-8.3 | Disjoint entry sets; structural, re-verified against `cc9317c`. |
| `IMPL-005` | No artifact is manufactured | §4.2, §7.7, §9.2, §9.4 | The hazard, the guard, the negative control, and the backlog refusal. |

### 13.2 Requirements gaps — recorded, not closed

| Gap | Consequence |
|---|---|
| `OD-7` unanswered | `IMPL-002`'s storage location is a recommendation, not a decision. **A1's compose change should not be implemented before this is answered**, because the two options differ in what survives. |
| `OD-8` unanswered | `IMPL-002` cannot be *persisted* without either fabricating three descriptor fields or changing a schema. **Blocks A1's write path.** |
| `OD-5` unanswered | `IMPL-003` cannot complete end to end; items A2 dispatches would stall at `agentExecuting` for ever. |
| `OD-10` unanswered | `IMPL-001` may build a scheduler that never dispatches. Safe, but the requirement is unmet. |
| `OD-3`, `OD-4` unanswered | Lifecycle completeness and the deferral shape; `IMPL-004` is safe under any answer. |
| `apps/control_plane/**` not granted | §8.5. The UI states something false about the new state. |
| Retained-tree reclamation has no owner | `OD-9`. Pre-existing; **not** a gap this design introduces. |
| No QA-contract lane assumed | `OD-5`. Same dependency as above, named from the other side. |

### 13.3 Design-system and UX assessment

- **`DESIGN_SYSTEM_COMPLIANCE`: `PARTIAL` by non-applicability, with a named gap.** No token,
  component or pattern is added or changed by either unit. Recorded **not** as `PASS`: the new
  state reaches an existing UI through `WorkItemView.state` as an unlabelled `String`
  (`control_plane_client/lib/src/protocol/work_item_view.dart:35,76`), and the UI's mapping
  defaults it to `awaitingReview` (§8.5). A reviewer may reasonably read that as `FAIL` for A2 —
  the argument is set out rather than hidden.
- **`UX_ACCESSIBILITY_SCORE`: `PARTIAL` by non-applicability.** No new focusable element, input,
  or navigation. The one user-visible change is the mislabelled state above. **No WCAG criterion
  is engaged by the design itself**; the §8.5 gap is a *correctness* defect on an existing screen,
  not an accessibility one, and it is escalated as such.
- **`IMPLEMENTATION_FEASIBILITY`: `HIGH`.** Every mechanism already exists: `JobType.implementFeature`
  and `AgentRole.implementer` (`job_type.dart:7`, `agent_role.dart:2`), `Scheduler` +
  `workloadResolver` (`scheduler.dart:314-336`), `LocalWorker` + `WorkerRegistry` +
  `WorkerDispatcherAdapter` (`server.dart:195-220`), `ArtifactCommitter`
  (`artifact_committer.dart:98-158`), `GitWorktreeWorkspaceManager`, the full credential/host-key
  trust chain (`repository_snapshot_acquirer.dart:504-600`), `recordWorkspace` +
  `completeOnboarding` (`product_registry_engine.dart:1917`, `:1976`), and the
  `UnavailableBaselineLaneRunner` fail-closed pattern (`baseline_runtime.dart:72-97`). The only
  new production artefacts are: one enum value, one edge, one `const JobDefinition`, one
  `JobDefinition` registration in an existing test, and A1's lane + materialiser. **No migration,
  no generated code, no new dependency.** The reservation is `OD-8` — and it is a *shape*
  question, not a feasibility one.

---

## 14. Reuse register — what is built versus what is new

| Component | Status |
|---|---|
| `JobType.implementFeature`, `AgentRole.implementer` | **Reuse** (`job_type.dart:7`, `agent_role.dart:2`) |
| `Scheduler` + `workloadResolver` + `EntryHopper` | **Reuse unchanged** (`scheduler.dart:314-336`, `entry_hop.dart`) |
| `RunnableWorkEvaluator` (legality by policy) | **Reuse unchanged** (`runnable_work.dart:137-167`) |
| `LocalWorker`, `WorkerRegistry`, `WorkerDispatcherAdapter` | **Reuse** (`server.dart:195-220`) |
| `ArtifactCommitter` (`shipit/impl/<workItemId>`) | **Reuse** (`artifact_committer.dart:98-158`) |
| `GitWorktreeWorkspaceManager` (validate-then-create) | **Reuse** (`git_worktree_workspace_manager.dart:71-135`) |
| `CredentialKeyService`, `RepositoryAccessVerifier`, `SecretProvider`, `PosixFileModes` | **Reuse for the trust decision** (`baseline_runtime.dart:99-122`) |
| `RepositorySnapshotAcquirer`'s **trust chain** | **Reuse** — its refusal taxonomy is the model (`repository_snapshot_acquirer.dart:523-600`) |
| `RepositorySnapshotAcquirer`'s **lifecycle** | **NOT reused** — see §6.4, three reasons |
| `UnavailableBaselineLaneRunner` pattern | **Reuse** (`baseline_runtime.dart:72-97`) |
| `product_agnosticism_test.dart` | **Reuse and extend** (§6.7) |
| `OnboardingRecord.pinnedRevision` / `.workspace` / `.hasDurableWorkspace` | **Reuse** (`onboarding_record.dart:105,122,157`) |
| `ProductRegistryEngine.recordWorkspace` / `.completeOnboarding` | **Reuse — this is what gives them their first production caller** (`:1917`, `:1976`) |
| `PostgresProductRegistryStore` onboarding read/write | **Reuse unchanged** (§6.9) |
| `defaultImplementFeatureDefinition` | **Reuse unchanged; a sibling is added** (`D-11`) |
| `WorkItemState.implementationReady` | **NEW** |
| `implementationReady -> agentExecuting` edge | **NEW** |
| `implementFeatureDefinition` (+ drift-guard registration) | **NEW** |
| `implementationWorkloadResolver` | **NEW** — `OD-4` decides its result type |
| Durable product-scoped clone + its materialiser | **NEW** — `OD-7`, `OD-8` |
| Workload-resolution widening | **NEW** — `OD-4` |

---

## 15. What an implementer must NOT do

Consolidated from §6.6, §7.9 and the above. Each names the defect it prevents, because a bare
prohibition ages badly.

1. **Do not derive a workspace from `currentBaselineRevision`.** It is an `int` sequence counter
   (`onboarding_record.dart:71-74`), not a commit. This is the specific error the stale brief made.
2. **Do not point `sched-impl` at `triageSource`, `SHIPIT_TRIAGE_REPOSITORY_PATH`, or
   `/triage-repo`.** That repository contains one `README.md` (`compose.qa.yaml:31`).
   It converts a visible dead end into a green review of a fabrication (§4.2).
3. **Do not substitute `HEAD` for the pin** — in the probe, in the materialiser, or in a
   `SchedulerWorkload`. The `HEAD` carve-out (`repository_snapshot_acquirer.dart:432-454`) is a
   resolution the sweep performs, never a pin a lane accepts.
4. **Do not fabricate `workerExecutionId` / `workerId` / `worktreePath`** to satisfy the current
   descriptor shape. That is `OD-8`, and a fabricated field in the record whose purpose is to be
   checkable is exactly the failure class this whole design exists to prevent.
5. **Do not build A1's clone by acquiring a `RepositorySnapshot` and retaining it.** §6.4.
6. **Do not move `escalationTargetFor` separately from `targetFor`**, and do not move it for a
   pair that does not need it (`D-13`). Either way the escalation index silently stops advancing.
7. **Do not omit the `waitingForHumanDecision -> implementationReady` edge and its guard set.**
   `D-14`. Without it the routing table moves a work item to a state nothing leaves.
8. **Do not set `skipWorkflowPolicyCheck: true`** on the implementation definition. The probe can
   succeed here; skipping it discards a real check.
9. **Do not reuse `engineeringReviewMissingArtifact`** as the implementation lane's `null`
   handler. It is a review action that performs `agentCompleted -> reviewInProgress` and raises a
   blocking `engineeringReview` decision (`engineering_review_gate.dart:317-412`).
10. **Do not widen `triageDefectDefinition.entryStates`.** It is correct, load-bearing, and has an
    independently-reviewed decision behind it (`2acb7fc`; `triage_defect.dart:8-53`).
11. **Do not repurpose `defaultImplementFeatureDefinition`.** It is `const`, used by ~20 test
    files as a generic host, and test-only in production (`D-11`).
12. **Do not hand-author commits or `producerActorId` values** for the stranded `agent_completed`
    items. §9.4.
13. **Do not fix the retained-tree reclamation leak here** — and do not inherit it. `D-8`, `OD-9`.
14. **Do not add an autonomous producer for `implementationReady`.** `OD-10`.
15. **Do not implement A1's compose change before `OD-7` is answered.** The three options differ
    in what survives `docker compose down -v`, and that difference is invisible until it is
    tested by a container teardown.

---

## 16. Provenance and self-check

| Item | Value |
|---|---|
| Worktree | `/Users/alkebut/air/.aef-lanes/impl-lane-design-rev2` (created by this lane from `84be979`) |
| Branch | `design/implementation-lane-rev2` |
| Base SHA | `84be9794f83ee258664842cd2c9f73f562b0d5f7` |
| Files created | `docs/design/implementation-lane/design-brief.md`, `docs/design/implementation-lane/design-revision-metadata.yaml` |
| Files modified outside `docs/design/implementation-lane/**` | **0** |
| Production code written | **none** |
| Migration written | **none** |
| Docker / Compose commands issued | **0** — compose files were read as text only, per `AGENTS.md` "Shared Docker state" |
| Database connections | **0**; `psql` **0** |
| `git stash` / amend / rebase / force-push / merge / push | **none** |
| Self-approval | **none.** This brief is `UNDER_REVIEW` and has not been reviewed by its author. |

**Verified at this base and relied on above:** `cc9317c`, `f164d40`, `1f39a05` and `5cb2817` are
all ancestors of `84be979`
(`git merge-base --is-ancestor` returned true for each).
