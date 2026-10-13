# Design Brief — Implementation lane + durable workspace creation

| Field | Value |
|---|---|
| `brief_id` | `B4D91D4A-CF4A-4415-864A-E0700D893367` |
| `revision_id` | `97F50350-C9F1-485C-8F63-A8999D73C55D` |
| `revision_number` | `3` of this brief (revision 2 was `F35D3433-779B-4E82-868F-0A618280AFEA`; revision 1 was `45EFF1E2-E39F-46AE-98C9-D417EEF5BF0E`) |
| `version` | `3.0.0` |
| `status` | `UNDER_REVIEW` |
| `risk_level` | **3** — Major Workflow change; see §12. **Unchanged by this revision and independently confirmed by the operator at decision `fb3c3485`.** |
| `branch` | `design/implementation-lane-rev2` |
| `worktree` | `/Users/alkebut/air/.aef-lanes/impl-lane-design-rev2` |
| `base_sha` | `84be9794f83ee258664842cd2c9f73f562b0d5f7` (unchanged — revisions 2 and 3 both amend revision 1; the base did not move) |
| `supersedes` | revision 2 of this brief (`F35D3433`, commits `381b552`, `9bd8f6d`), on which revision 2 superseded revision 1 (`45EFF1E2`, commit `8ad9985`). Revision 1's own supersession of `IMPL-LANE-001` / `IMPL-LANE-001-R1` @ `5d7c276`, base `5cb2817`, stands unchanged — ledger in §1.3; nothing was merged, so nothing is retracted |
| `created_by` | `design-agent` |
| `created_at` | `2026-10-13` (rev 1) · `2026-10-13` (rev 2) · `2026-10-13` (rev 3, this pass) |
| `decisions_in_force` | `fb3c3485` (DESIGN, RESOLVED, option A) · `9bfe2d09` (ARCHITECTURE, RESOLVED, `OD-7` = option B) · `c04f6a8d` (ARCHITECTURE, RESOLVED, `OD-8` = option A). **Authoritative over any conflicting prose in this brief.** |
| `requirements_refs` | `IMPL-001`..`IMPL-005` (§13) — **no source-of-truth artifact exists in this repository; see the traceability limitation in §13.2** |
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

> ### What revision 2 is, and what it is not
>
> **This is a correction pass, not a redesign.** It folds in three operator answers and eight
> independent-review findings (M1–M5, L1–L3). **The design's spine is unchanged**: the corrected
> framing (§2), the Level 3 justification (§12.1), the collision argument (§7.4), the two
> lockstep corrections `D-13`/`D-14`, the retained-tree refusal `D-8`, and the §9.4 backlog
> refusal are all carried forward **verbatim in substance**. Every finding that touched them was
> re-verified against the code before being accepted — see §17.
>
> **Two findings were re-verified rather than trusted, and both held:** the operator's answer to
> `OD-8` is viable as stated (all four named per-execution consumers provably do not reference
> `OnboardingRecord`, so they stay byte-identical), and `OD-7` is **only partly answered** — the
> location is decided, the lifetime bound and the reclaimer are not (§11, `OD-7.2`/`OD-7.3`).
>
> **One consequence of an operator answer was larger than the brief anticipated** and is recorded
> as a new finding rather than absorbed: `OD-8` = option A changes a Dart field type, and its
> verified blast radius is materially wider than revision 1's conditional grant (§8.6). It is
> flagged for a path grant; it does not block this revision.

> ### What revision 3 is, and what it is not
>
> **A bookkeeping consolidation pass. It changes no design.** No unit's `OWNED_PATHS` moved, no
> ownership cell in §8.1 changed, no gate, obligation, prohibition, decision or `C-1`/`C-2`
> condition changed, and the §8.3 concurrency verdict is untouched. The substantive design passed
> two independent reviews with no blockers and no highs and is carried forward as it stood.
>
> **What it does change is how ownership is *stated*.** Earlier revisions described ownership as
> arithmetic over §8.1's row set — "nine rows new in revision 2", "the four plus five",
> "§8.6's five paths". That row set is **not a partition**: it mixes paths that do not exist at
> the base with rows whose *owner* changed, so every total over it meant one thing to its author
> and another to its reader, and successive correction passes kept chasing the symptom.
> Ownership is now stated **directly, as paths**, and §8.1 carries a `Revision 2` column that
> labels every row `NEW PATH`, `FLIP` or `same owner` so a reader can verify disjointness by
> reading the two ownership columns rather than by doing subtraction.
>
> **Two defects were corrected with it:** a decision ID that did not exist (D-E) and a count that
> contradicted §8.6's own enumeration (D-B). The decisions, paths, findings and open items are
> unchanged — only their bookkeeping.

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

`recordWorkspace` needed a `WorkspaceDescriptor`, and `WorkspaceDescriptor` is **per-execution,
not per-product** (§6.2). **`OD-8` has since been answered (option A):** A1 writes a new
`DurableWorkspaceDescriptor` instead, and `recordWorkspace`'s parameter type changes with it
(§8.6). `completeOnboarding` needs a `completedBaselineId`, so it can
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
routes** — and that is why §12's Level 3 justification rests on A2's lifecycle surface.

**But the approval is pair-wide (L3), and this section said otherwise.** Revision 1 continued:
*"the human approval request in §12.3 is scoped to A2's lifecycle surface rather than to the
pair."* That was wrong, and wrong in a way that mattered operationally: §12.3 items 3 and 4 were
explicitly asking the human to approve **A1's** clone location and **A1's** schema change. **A
design can be approved narrowly for its lifecycle risk while a human is still asked to accept its
storage and schema decisions** — those are part of what was approved.

**Corrected:** the **Level 3 justification** rests on A2's lifecycle surface (unchanged, §12.1 —
and §12.2's reasoning is untouched), while the **approval itself is pair-wide** (§12.3, L3). The
distinction is now explicit rather than left to be inferred from which section a reader lands on.

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

### 6.2 Prerequisite decision — `WorkspaceDescriptor` is per-execution; `OD-8` is now RESOLVED

`OnboardingRecord.workspace` is typed `WorkspaceDescriptor`
(`onboarding_record.dart:122`), and `WorkspaceDescriptor` is **structurally per-execution**:

| Field | Required? | Meaning for a product-scoped durable clone |
|---|---|---|
| `workspaceId` | yes (`workspace_descriptor.dart:15`) | Fine — mint a product-scoped id. |
| `workerExecutionId` | **yes** (`:16`) | **There is none.** A durable clone is created by a platform operation, not by a worker execution. |
| `workerId` | **yes** (`:17`) | **There is none**, for the same reason. |
| `repositoryPath` | yes (`:18`) | Fine — the clone path. |
| `startingRevision` | yes (`:19`) | Fine — the pin. |
| `worktreePath` | **yes** (`:20`) | **There is none.** A durable clone is not a worktree; worktrees are per-execution and removed. |

> **Offset correction (L1).** Revision 1 cited `repositoryPath` at `:20` and `startingRevision`
> at `:21`. Verified by grep at this base: `required this.repositoryPath` is at
> **`workspace_descriptor.dart:18`** and `required this.startingRevision` at **`:19`**
> (`workspaceId` `:15`, `workerExecutionId` `:16`, `workerId` `:17`, `worktreePath` `:20`).
> Revision 1's `:20` for `worktreePath` was right by coincidence — `:20` is also
> `worktreePath` — which is exactly how the error survived: two of three offsets were shifted
> by two and one was correct.

All three impossible fields are also `required` in **both** JSON Schemas
(`schemas/workspace_descriptor.schema.json:8-17` — revision 1 said `:8-16`; the array opens at
`:8` and closes at `:17`, **L1** — and the inlined copy at
`schemas/onboarding_record.schema.json:39-48`), so they cannot simply be omitted on the wire.
Every schema is conformance-tested (`packages/platform_contracts/test/contract_schemas_test.dart:36`
names the schema, `:58-66` iterates, `:59-65` is the test body) and `contract_schemas_test.dart`
validates the committed examples, so a shape change is a review-visible, test-breaking edit —
which is the correct blast radius for this question.

#### 6.2.1 The operator's answer — `OD-8` = option A, and it binds four things

Decision `c04f6a8d` (**RESOLVED**, ARCHITECTURE, selected `A`). **This section is
authoritative over everything else in the brief about descriptor shape.** It binds:

1. **`WorkspaceDescriptor` is NOT modified.** Not relaxed, not `kind`-tagged, not made
   nullable. `schemas/workspace_descriptor.schema.json` and the type itself are **READ-ONLY**
   for both units.
2. **A1 adds a NEW `DurableWorkspaceDescriptor` type with its OWN schema**, and writes it to
   `OnboardingRecord.workspace`.
3. **The per-execution consumers must remain behaviourally byte-identical, with no new null
   branch anywhere in that chain** — `worker_reconciler`, `local_worker`, `onboarding_worker`,
   `engineering_review_gate`.
4. **No migration.** The DB column is already `JsonValue?`, so a different JSON shape needs no
   `ALTER`.

**Re-verified before adopting, and it holds.** All four named consumers provably do **not**
reference `OnboardingRecord` at all — they read their own per-execution workspace:

```
apps/server/lib/src/review/engineering_review_gate.dart            no reference to OnboardingRecord
packages/worker_runtime/lib/src/reconcile/worker_reconciler.dart    no reference to OnboardingRecord
packages/worker_runtime/lib/src/worker/onboarding_worker.dart       no reference to OnboardingRecord
packages/worker_runtime/lib/src/worker/local_worker.dart            no reference to OnboardingRecord
```

So the binding in (3) is satisfiable **exactly as stated**: the type change touches the
onboarding record's own readers, and none of them is on the safety-critical artifact-resolution
path. This is the concrete reason the operator's rationale — *"the blocker is a type-shape
conflict, not a missing field"* — is the right call.

#### 6.2.2 Two obligations the answer creates that the answer does not itself state

**(a) A discriminator is mandatory, because one column now holds two shapes.**
`OnboardingRecord.workspace` will hold either a per-execution `WorkspaceDescriptor` or a
`DurableWorkspaceDescriptor`, and nothing in the JSON distinguishes them unless A1 says so.
`DurableWorkspaceDescriptor` **MUST** carry an explicit literal discriminator (recommended:
`"kind": "durable"`, constant and non-optional) so a reader can never mistake one for the
other. **Fabricated provenance is precisely the failure class this repository has already
caught once** (decision `c04f6a8d`, option `C`'s rationale). A reader that guesses is the
same defect wearing a different hat. This is a design obligation, recorded here so it is not
forgotten; it does not need a further decision.

**(b) The two types must never be silently interchangeable at a read.** Any new code that
reads `OnboardingRecord.workspace` **MUST** discriminate on (a) and refuse the other shape.
There is no implicit coercion, and no "if it parses, accept it" — a record naming the wrong
kind is a **fail-closed error**, not a fallback. This mirrors §7.7: a workspace that is
missing or of the wrong kind **defers**, never substitutes.

### 6.3 Durable-workspace location — `OD-7` RESOLVED (option B: host bind)

> **The operator's answer (decision `9bfe2d09`, RESOLVED, selected `B`) binds:**
> `${SHIPIT_HOST_WORKSPACE_DIR}` as a **host bind mount**, matching the existing
> `${SHIPIT_HOST_SECRET_DIR}` custody precedent (`compose.qa.yaml:119`). With **an explicit
> fail-closed sentinel of the same shape**, so an unconfigured deployment fails loudly rather
> than writing container-local state that silently loses work. And **any teardown or compose
> project is named explicitly with `-p`, never derived from the default.**
>
> **Host-inspectability is a stated requirement, not a convenience**: a reviewer must be able to
> read `producer.repositoryPath` without entering the container. See below for why that is a
> review property and not just an operational nicety.

#### 6.3.1 The mount, exactly

```yaml
# docker/compose.qa.yaml — server.volumes, added beside :119
      # Durable, host-backed PRODUCT CLONE (OD-7, decision 9bfe2d09). Same shape and
      # same rationale as the custody bind above it: a host path is not Docker's to
      # delete, so the clone survives `down`, `down -v` and volume pruning — and the
      # review gate can re-read producer.repositoryPath from the HOST without entering
      # the container. Sentinel default is deliberately a bad path, for the same
      # reason as the secret dir: a lost variable must land somewhere obviously wrong.
      - ${SHIPIT_HOST_WORKSPACE_DIR:-/tmp/shipit-workspaces-NOT-CONFIGURED}:/workspace-repo
```

**The precedent is exact, not approximate.** `compose.qa.yaml:113-118` already states the rule
this mount is copying, in the repo's own words: *"This bind mount is what makes it survive
container destruction. Sentinel default is deliberately a bad path so a lost variable lands
somewhere obviously wrong rather than in the writable layer."* Reusing that idiom rather than
inventing a second one is the stated rationale for the decision.

#### 6.3.2 The `-p` obligation is not decoration — it is the incident this repository already had

**Verified at this base: `docker/compose.qa.yaml` declares no top-level `name:`.** Compose
therefore derives the project name from the directory holding the compose file, which is
`docker/`, and every stack in this repository resolves to project `docker`. `AGENTS.md` records
what that has already cost: a review lane ran `docker compose … down -v --rmi local` against
the live QA stack and destroyed `docker_postgres_data_qa` **irrecoverably**, because no dump
existed.

So, binding:

- **Every command A1 or A2 causes to be run against this stack names its project with `-p`.**
- **No target may rely on the derived default.** A target that does is a defect even when it
  happens to be correct today, because it is correct by accident and one untracked line in the
  gitignored `.env` can redirect it.
- **Any new teardown target A1 introduces declares its own project name**, per `AGENTS.md`
  "Test resource hygiene".
- **This lane read the compose files as text and issued no Docker or Compose command of any
  kind**, including `ps`, `logs` and `info` (`AGENTS.md` "Shared Docker state" grants those
  neither, because reading a compose file as text is the supported way to establish what a
  stack does).

#### 6.3.3 Why host-inspectability is a review property, not an operational one

The review gate re-reads `producer.repositoryPath` and re-validates the revision **in it**
(`engineering_review_gate.dart:75`; `git_worktree_workspace_manager.dart:85-92`). Under a
named volume, an independent reviewer checking review-matrix rows **R-3** and **R-4** — *"a
deferring probe never dispatches"* and *"the fabrication hazard is closed"* — would have to
either trust the implementer's account of what is on disk, or enter the container to check.
Both weaken the review. A host bind keeps the evidence where the reviewer already has access
to it. That is the reason the decision cites it.

#### 6.3.4 Two consequences of the decision that are obligations, not options

1. **`.gitignore`.** The host workspace root must have an explicit `.gitignore` entry so a
   checkout that lands under a repository-adjacent path can never be committed. The root is
   operator-chosen and defaults under `/tmp`, so this is a cheap guard against a plausible
   misconfiguration, not a certainty.
2. **Documented uid/gid expectation.** A host bind does not get Docker's uid/gid management
   (option `A`'s stated advantage). A1's materialiser therefore owns the permission story for
   the identity file, the `known_hosts` file and the ssh wrapper — it already must, via
   `PosixFileModes` (§6.4) — and the operator-facing runbook must name the expected uid/gid.

#### 6.3.5 The options considered, kept for the record, and what each actually bought

Revision 1 argued W-A (named volume) and recommended it. **The operator chose W-B.** The
analysis is retained rather than deleted, because the reason the recommendation changed is
itself informative: W-A's decisive advantage — Docker manages uid/gid — is worth less than
its decisive disadvantage — a reviewer cannot reach the evidence from the host.

| Option | Verdict | What it bought / cost |
|---|---|---|
| **W-A — Docker named volume** (e.g. `workspace_repo_qa`) | **NOT SELECTED** | Survives `restart`, re-creation and rebuild; Docker manages uid/gid; precedent at the same mount site (`triage_repo_qa`, `compose.qa.yaml:111`). Lost to W-B on **review reachability** and on being a **second durability idiom** beside the existing secret bind. Also lost to `make qa-down`, which runs `down -v` (`Makefile:90-92`). |
| **W-B — host bind `${SHIPIT_HOST_WORKSPACE_DIR}`** | **SELECTED** (`9bfe2d09`) | Matches `${SHIPIT_HOST_SECRET_DIR}` exactly; host-inspectable for review; survives `down`, `down -v` and volume pruning. Costs: host path coupling, an explicit `.gitignore` entry, a documented uid/gid expectation. |
| **W-C — container-ephemeral, re-create on demand** | **DISQUALIFIED BY THE REQUIREMENT** | **It destroys the artifact.** §2.4 steps 3-4: the commit lives in the clone's object store and the reviewer resolves it out of `producer.repositoryPath`. Every implementation would fail closed at review — the same invisible failure as §4.2, arriving later and attributed to the reviewer. |
| **W-D — git host as source of truth, fetch per execution** | **NOT SELECTED** | Keeps the proven ephemeral-scratch model, but leaves no stable `repositoryPath` for the review gate to re-read, and keeps artifact commits accumulating only in retained trees — which have no bound and no reclaiming owner (`OD-9`). Re-introduces the unbounded-retention problem this repository already has. |

**What the requirement does NOT demand, stated so nobody builds it by accident:** multi-host
durability, artifact archival beyond the review window, or surviving the deletion of the host
directory by a human. If any of those is wanted, the answer is a platform-owned bare remote —
a larger architectural change, and not this one.

#### 6.3.6 `OD-7` is answered for its first part ONLY — two parts remain open

Revision 1's `OD-7` had **three** questions: where it lives, how long it lives, and who
deletes it. Decision `9bfe2d09` answers **the first**. Its own `binds` field says *"A1's
compose change is unblocked"* — and revision 1 said `OD-7` **"Blocks: A1's compose change and
its reclamation path."** The reclamation path is therefore **still blocked**. This is stated
plainly rather than allowed to read as "the whole of `OD-7` is closed":

| Sub-question | Status | Effect |
|---|---|---|
| **1 — where does it live** | **RESOLVED** — host bind `${SHIPIT_HOST_WORKSPACE_DIR}` (`9bfe2d09`) | A1's compose change is **unblocked**. |
| **2 — how long does it live** (`OD-7.2`) | **OPEN** | No lifetime bound is decided. The brief's recommendation stands as a recommendation only: reclaim when the product leaves `governed` for `archived`, and never before — the existing lifecycle rather than an invented timer. |
| **3 — who presses it** (`OD-7.3`) | **OPEN** | The brief's recommendation stands: a **human action, not a sweep**. Deleting a product's only checkout is not a machine decision. |

**So A1 can build and ship the mount, and cannot yet ship a reclamation policy.** `markCleaned`
exists (`workspace_descriptor.dart:51-62`) and `hasLiveWorkspace` reads it
(`onboarding_record.dart:150`), but for the durable descriptor `OD-8` introduces, **nothing
produces a cleaned state and nothing deletes a clone**. That is a bounded, named gap — not an
unbounded leak like `OD-9`'s — because the clone is **one per product**, not one per
execution (§6.5). It is recorded in §13.2 and in the dispatchable-vs-gated table in §12.3.

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

**Credential custody is unchanged — but the property is now an OBLIGATION, not an inheritance (M1).**

The stale brief escalated custody because a durable clone would hold a private key "for the
life of the product". It would not. `onRelease` destroys the private half **first and
unconditionally**, and the comment states the rule: *"An artifact is not a reason to keep a live
key on disk, so the credential material goes first and the repository's fate is decided
afterwards"* (`:867-882`). A durable clone is a plain git checkout with an `origin` remote and
**no credential configured on it**; any later `fetch`/`push` from it fails closed because
there is no key. `AGENTS.md §13a` (referenced by name, never by value) and ADR 0018 continue
to govern, unchanged. `OD-2` is withdrawn for this reason.

> #### What was wrong with revision 1's version of that claim, and what replaces it (M1)
>
> Revision 1's `D-7` asserted, as **established fact**, that *"a durable clone carries no
> credential."* **That sentence is true of the acquirer and false as a statement about A1.**
>
> It is true of `RepositorySnapshotAcquirer` because the acquirer does four specific things.
> Verified at this base:
>
> | # | What the acquirer does | Citation |
> |---|---|---|
> | 1 | The identity file, the `known_hosts` file and the ssh wrapper are written as **siblings** of the clone — all four paths are built from one `scratch.path`, and the clone is `${scratch.path}/checkout` | `repository_snapshot_acquirer.dart:740,743-746` |
> | 2 | The private half reaches git through a **per-invocation environment variable**, never through anything on disk or in config | `GIT_SSH_COMMAND` at `:1202`, passed to `_runBounded` at `:1196-1201` |
> | 3 | The ambient environment is **redirected away**, so a developer's `~/.ssh/config` cannot add an `IdentityFile` and a global gitconfig cannot add `url.*.insteadOf` — the file's own comment says so | `HOME` → `:1213`; `GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM` → `/dev/null` at `:1214-1215`; rationale comment at `:1209-1212` |
> | 4 | The private half is destroyed **first and unconditionally** at release | `:867-882` |
>
> **But A1 does not reuse the acquirer** — §6.4 forbids it for three verified reasons. So
> **none of those four properties is inherited by A1.** A1 is writing an **unwritten
> materialiser**, and on revision 1's text that materialiser had **no obligation whatsoever**
> to reproduce any of them. The property was an assumption wearing the costume of a citation.
>
> **Replaced by a binding obligation. A1's materialiser MUST, per acquisition:**
>
> 1. **Materialise the private half per acquisition**, from the product's own
>    `ProductCredential`, via `CredentialKeyService.generate` — never read from a path, never
>    cached across acquisitions, never held in a long-lived field.
> 2. **Write the identity, `known_hosts` and the ssh wrapper as siblings of the clone**, never
>    inside it, and remove them with the tree.
> 3. **Pass the private half only through a per-invocation environment** — `GIT_SSH_COMMAND`
>    plus a pinned `PATH`, with `GIT_TERMINAL_PROMPT=0` and `GIT_ASKPASS=''` so nothing can
>    block on a human prompt while a key is in memory.
> 4. **Redirect the ambient environment**, exactly as `:1209-1215` does: `HOME` pointed at the
>    materialisation root, `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_SYSTEM` both `/dev/null`.
> 5. **Leave NO `core.sshCommand` and NO identity reference in the clone's git config**, and
>    write **no** `~/.ssh/config`, `known_hosts` or credential file that outlives the
>    acquisition. The clone's config after `materialize` must be as credential-free as a
>    checkout made with the public half.
> 6. **Destroy the private half first and unconditionally**, before deciding anything about
>    the repository's fate — the ordering `:867-882` states in words.
>
> **Why this is a design obligation and not implementation trivia:** obligations 3–5 are
> **invisible on every success path**. A materialiser that keeps the identity file beside the
> clone works perfectly, produces green tests, and leaves a deploy-key identity on disk
> next to every governed product's checkout for the life of the deployment. Nothing in the
> functional test suite can see it. **Only the obligation makes it reviewable** — and
> review-matrix row **R-9** (§7.10) is what makes it checkable.

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
| **Durable product clone** (A1, this brief) | one per product | as long as the product is registered | **A1**, by policy — **location decided (`OD-7.1`); the bound is `OD-7.2` and the presser is `OD-7.3`, both OPEN** | **intended to be — currently NOT** (§6.3.6) |
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
   (`packages/platform_contracts/lib/src/types/repository_reference.dart:12-15` — **the full
   path, because a `repository_reference.dart` also exists in `apps/server/lib/src/generated/`,
   which is 613 lines of Serverpod codegen and contains no such text**).
2. **Must not re-pin on every run.** `recordWorkspace`'s doc: *"the record answers 'where is it
   NOW'"* and *"re-pinning a product whose workspace is still pinned to the old commit is a call
   that has to pass BOTH"* (`product_registry_engine.dart:1908-1911`, `:1946-1948`).
3. **Must not fabricate `workerExecutionId` / `workerId` / `worktreePath`** to satisfy the
   current descriptor shape. That is `OD-8`, and fabricating them is precisely how a fake would
   enter a record whose whole purpose is to be checkable. **`OD-8` is now answered (option A),
   so this is no longer a live temptation — it is a standing prohibition on ever taking the
   option-(a) shortcut after the fact.** A `DurableWorkspaceDescriptor` has no such fields and
   must not grow them.
4. **Must not call `completeOnboarding` before a human has accepted a baseline.** It requires
   `completedBaselineId` (`product_registry_engine.dart:1980`) and refuses a product with no
   onboarding record (`:1986-1991`).
5. **Must not leave a credential anywhere on or beside the durable clone.** §6.4's six
   obligations (M1): no identity file, no `known_hosts`, no ssh wrapper, no `core.sshCommand`,
   no identity reference in the clone's git config, and no `GIT_SSH_COMMAND` written into any
   persisted config. The private half lives in memory for the duration of one `git`
   invocation and is destroyed immediately after.
6. **Must not read `SHIPIT_*` or any other environment variable from a lane file**, and must
   not hardcode an absolute path. §6.7, and note that the **read belongs to A2** (M3, §15.16).
7. **Must not modify `repository_snapshot_acquirer.dart`** — or anything else under
   `apps/server/lib/src/credentials/**`. §6.8. A1 composes those primitives **read-only**;
   the retained-tree behaviour that file owns is `OD-9`'s, and `D-8` forbids A1 from fixing it.

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
   `_triageWorkspaceRoot()` (`server.dart:1281-1285`) reads `Platform.environment[...]` and
   feeds `GitWorktreeWorkspaceManager` (`:201`, `:210`). **This is why the A1/A2 path map in §8
   has to leave `server.dart` to exactly one unit.**

> #### Who owns that read — the correction (M3)
>
> **Revision 1 stated this as an A1 obligation (`D-18`) while assigning A1 a path map that made
> it impossible.** `server.dart` is assigned **exclusively to A2** under `C-1`, and the
> implementation-unit metadata listed it under A1's `does_not_own`. So A1 could not satisfy its
> own central agnosticism invariant within its own ownership: **another implementer was going to
> write the code A1's invariant depends on.**
>
> **Corrected, and deliberately without narrowing A1's grant.** The reviewer's alternative —
> give A1 `server.dart` — is noted and **declined**: `C-1`'s single-writer guarantee on a
> 1300-line composition root is the stronger invariant, and splitting it back across two
> concurrent writers is the exact defect §8.2 exists to prevent.
>
> **So the obligation moves to A2, under `C-1`, where it belongs:**
>
> > **`C-1` (revised).** `apps/server/lib/server.dart` is assigned **exclusively to A2**. A2
> > writes two things in it: its own composition (implement worker, `sched-impl`, the resolver
> > — §7.8) **and** the single environment-variable read for A1's durable-workspace root,
> > passing the resolved path **into** A1's factory as a parameter. **A2 owns that read under
> > `C-1` whether or not A1's branch has landed**, because the read is a composition-root
> > concern and `C-2` guarantees A1's factory accepts it as an argument.
>
> The model is the existing one: `_triageWorkspaceRoot()` is a **private function in
> `server.dart`** that resolves an env var and returns a path, and the agnosticism gate does not
> cover `server.dart` at all. A2 writes the durable equivalent; A1 receives a `String`.

### 6.8 A1 OWNED_PATHS — narrowed (M5)

**Revision 1 granted A1 `apps/server/lib/src/credentials/**` — a whole directory. M5 showed that
grant cannot enforce `D-8`/§15.13, and the reason is concrete: that directory *contains*
`repository_snapshot_acquirer.dart`**, the file that implements the retained-tree behaviour A1
is forbidden to fix (§6.5) and forbidden to reuse (§6.4). A directory-wide grant would hand A1
write access to the exact file whose behaviour it must not change, and a prohibitions register
is not a capability control.

**Verified: A1 needs to modify nothing in that directory.** A1 *composes* the primitives, and
every one of them already exposes what a materialiser needs:

| Primitive | Declaration | Already sufficient? |
|---|---|---|
| `CredentialKeyService` | `credential_key_service.dart:209` | **Yes** — `generate(...)` → `MintedCredential` (`:234`), `verifyAccess(...)` → `AccessVerification` (`:341`). Both are what a durable materialiser calls; neither needs a new method. |
| `RepositoryAccessVerifier` | `repository_access_verifier.dart:227` | Yes — reused for the host-key refusal taxonomy (§6.4). |
| `SecretProvider` | `secret_provider.dart` | Yes — used as the **port**, never modified. |
| `PosixFileModes` | `posix_file_permissions.dart:68` | Yes — §6.3.4's uid/gid obligation needs no new capability. |
| `SshKeyPair` | `ssh_keypair.dart:98` | Yes — an OpenSSH armour value type; `:16-39` is the PEM header/footer constant pair, not fields. Nothing to extend. |
| `SshRemote` | `ssh_remote.dart:8-39` | Yes — carries only `user` (`:17`), `host` (`:20`), `port` (`:23`), `repositoryPath` (`:26`) and `toSshUrl()` (`:35`). **No identity field**, so a durable clone needs no variant of it. |
| `SecretBytes` | `secret_material.dart:34` | Yes — the in-memory private half. |

**Therefore A1's map after narrowing:**

```
A1 OWNS (write):
  apps/server/lib/src/baseline/**                     the durable-workspace lane, its runtime
                                                      factory (C-2), its OWN materialiser, and
                                                      the product_agnosticism_test.dart update
                                                      (§6.7) — the materialiser lives HERE, so
                                                      the agnosticism gate covers it (§6.3.4)
  packages/platform_contracts/lib/src/types/durable_workspace_descriptor.dart   NEW (OD-8 = A)
  packages/platform_contracts/lib/src/types/onboarding_record.dart              field + validate()
  packages/platform_contracts/lib/src/types/onboarding_record.g.dart            regenerated
  packages/platform_contracts/test/contract_schemas_test.dart                   register new schema
  schemas/durable_workspace_descriptor.schema.json                              NEW (OD-8 = A)
  schemas/examples/durable_workspace_descriptor.example.json                    NEW (conformance)
  schemas/onboarding_record.schema.json                                          inlined shape
  packages/product_registry/**                                                    recordWorkspace's
                                                                                parameter type (§8.6)
  packages/store_contract_tests/**                                                the shared
                                                                                conformance suite
  apps/server/lib/src/persistence/postgres_product_registry_store.dart           JSON round-trip
  apps/server/lib/src/services/control_plane_service.dart                        the one debug-log
                                                                                reader (§8.6)
  docker/**                                                                     the host bind (§6.3)

A1 READ-ONLY in credentials/** — ALL THIRTEEN FILES, including:
  apps/server/lib/src/credentials/repository_snapshot_acquirer.dart        <-- M5's specific ask
  apps/server/lib/src/credentials/repository_snapshot_acquirer_test.dart
  credential_key_service.dart · repository_access_verifier.dart · secret_provider.dart
  posix_file_permissions.dart · ssh_keypair.dart · secret_material.dart · ssh_remote.dart
  gcp_secret_manager_secret_provider.dart · local_file_secret_provider.dart
  secret_provider_resolver.dart · secretless_error.dart
```

**The contingency is stated rather than assumed away.** If implementation finds a genuine need
to modify one of those thirteen files, it is **re-scoped through review — not taken in
silently** — the same rule §6.9 applies to `persistence/**`. The one modification this design
*foresees* and refuses is `repository_snapshot_acquirer.dart`, whose retained-tree behaviour is
`OD-9`'s to fix in its own lane (`D-8`).

> **A note on where the materialiser lives, because it is a decision with a reason.** Revision 1
> implied the materialiser would go under `credentials/**`, next to the acquirer it must not
> reuse. Narrowing the grant forces the question, and the answer is the lane directory:
> `lib/src/baseline/**` is under the **mechanical** product-agnosticism gate (§6.7), so A1's
> newest and most security-sensitive code is the code most likely to be checked for a hardcoded
> path or a product name. Placing it outside the gate would have traded a real safety property
> for file adjacency.

### 6.9 `apps/server/lib/src/persistence/**` — still no store change for its own sake, but one file is now in scope

**Revision 1's finding stands and was re-verified:** `PostgresProductRegistryStore.saveOnboarding`
already writes all three columns (`:1027-1059`) and `readOnboardingForProduct` already returns
them (`:1061-1071`); `_onboardingParams` / `_onboardingFromRow` already round-trip the JSON.
`recordWorkspace` and `completeOnboarding` are engine methods that need **no store change**.

**What changed is the type, not the plumbing.** Under `OD-8` = option A the Dart field type of
`OnboardingRecord.workspace` changes, so the one place that binds the stored JSON back to a
typed value — `postgres_product_registry_store.dart:1156-1166`, which reads the column as text
and decodes it — is in scope. It is **one file**, for **one binding**, and **no SQL changes**:
the column is already `JsonValue?` and the `down -v`-independent statement *"stored as JSON text
and read back through the same path"* (`:1147`) still holds.

**So the honest position is narrower than "A1 owns persistence" and wider than "A1 owns none":**

- **A1 owns `postgres_product_registry_store.dart`** — the single file listed in §6.8.
- **A1 owns nothing else under `apps/server/lib/src/persistence/**`.** If implementation finds a
  missing read in a *second* file, it is re-scoped through review — **not taken in silently.**
- **No migration.** Verified: `20261012213045000` added the column as nullable JSON with no
  default and no backfill, which is exactly the shape a second descriptor shape needs.

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
   with listeners. `transition_copy.dart:26-95` has the same shape (`_ => null` at `:94` → the
   neutral `kUnknownTransitionMessage`).
   **Both files are now GRANTED to A2 by decision `fb3c3485`**, and the operator recorded why:
   *"Without these two files an item at the new state is misreported as awaiting review."*
   **A2 therefore adds a `case 'implementation_ready'` to both switches.** This was the one
   requirement revision 1 could not deliver from inside either unit's map; it is now
   deliverable, and it moves §8.5 from gap to obligation. `transition_copy.dart` also needs the
   inbound and outbound pairs (`('implementation_ready', …)` and `(…, 'implementation_ready')`)
   so a work item entering or leaving the new state stops rendering as *"The work moved to a new
   stage."*

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
  `humanQaApproval`. Any pair retargeted to `implementationReady` needs a
  `waitingForHumanDecision -> implementationReady` edge carrying the **same** guard set.
  **The stale brief missed this entirely** — without the edge, the routing table moves a work
  item to a state no edge leaves, and the resolution is refused by the engine.
- **Obligation B — the escalation bound.** `escalationIndexWithinLimitForDecisionTypes` is
  bounded for `engineeringReview` and `humanQaApproval` on the rework edge.
  **Revision 1 cited `:280-284` for the bound; that range is the explanatory COMMENT, not the
  guard call — `L1`.** The comment occupies `:277-284` and says, in the file's own words, that
  `humanQaApproval` *"moved onto this edge from `agentExecuting`"* and that dropping it *"would
  quietly RELAX the bound it already had"*, while `qaRework`, `qaWaiver` and `escalation` are
  *"deliberately not added"* because *"inventing a bound here would be new policy rather than a
  lockstep move."* **The guard call is at `:285-290`**:
  `GuardConditions.escalationIndexWithinLimitForDecisionTypes(escalationDecisionTypes: {HumanDecisionType.engineeringReview, HumanDecisionType.humanQaApproval})`.
  Both references are given below so the citation cannot be re-broken the same way.
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
7. **Must not touch `apps/server/lib/src/baseline/**`, or write anywhere in
   `apps/server/lib/src/credentials/**`.** §8, §6.8. Those thirteen credential files are
   **READ-ONLY for both units** after M5's narrowing.
8. **Must not touch `docker/**`.** A1 owns the mount; A2 only reads the path A1 recorded.
9. **Must not modify `WorkspaceDescriptor` or its schema.** Decision `c04f6a8d` binds it
   READ-ONLY for **both** units. A2 touches neither.
10. **Must not add a `case` to a UI switch without adding the state it maps to.** §7.1/§7.4 —
    with `plain_language.dart` and `transition_copy.dart` now granted, the mapping is A2's to
    finish, and a half-done mapping is the mislabel this brief exists to prevent.

**A2's obligations under `C-1` that revision 1 assigned to A1 (M3), restated as A2's own:**

- **Write the durable-workspace-root environment-variable read in `server.dart`** and pass the
  resolved path into A1's factory as a parameter — the `_triageWorkspaceRoot()`
  (`server.dart:1281-1285`) pattern. **A1 must not perform this read**, both because
  `C-1` gives A2 exclusive ownership of the file and because the agnosticism gate forbids
  `SHIPIT` in `lib/src/baseline/**` (§6.7).
- **Add A1's wiring lines in the same composition pass**, after A1's factory signature exists
  (`C-2`).

### 7.10 Review-ability matrix — what an independent reviewer can check, and how

| # | Claim | How it is checked | Fails if |
|---|---|---|---|
| R-1 | Entry sets are disjoint | A test asserting `implementFeatureDefinition.entryStates ∩ triageDefectDefinition.entryStates == {}` **plus** the same for every other production definition | Any shared state |
| R-2 | The new state is not a stranding state | `entry_hop_drift_guard_test.dart` (add the definition) + `transition_consistency_test.dart` | The state is listed but has no legal route to `agentExecuting`, or the mirror disagrees |
| R-3 | A deferring probe never dispatches | Construct a `Scheduler` with a resolver that returns "no durable workspace" for **every** item; assert `dispatched == []`, `blockedArtifactMissing == []`, and that no `LocalWorker` was prepared | A dispatch, or a `blockedArtifactMissing` entry |
| R-4 | The fabrication hazard is closed | Point `sched-impl` at a workspace that does not exist; assert no dispatch **and** that the static `workload.repositoryPath` was never used | Any dispatch using `triageSource` |
| R-5 | Routing retargets keep the escalation index moving | A test over `HumanDecisionRouting.routesTo` / `routesToEscalation` for the two lockstep pairs, plus the transition-table guard set | `targetFor` moved and `escalationTargetFor` did not |
| R-6 | The UI does not lie about the new state | **Now A2's obligation** — decision `fb3c3485` granted `plain_language.dart` and `transition_copy.dart`. Assert `implementation_ready` maps to a defined `PlainStatus` and is not served by the `_ =>` default; assert the inbound/outbound transition pairs are covered | The new state still falls through to `_ => awaitingReview` (`:135`) or `_ => null` (`:94`) |
| R-7 | A1/A2 do not overlap | Path sets compared by the Manager before dispatch (§8.1) | Any shared path |
| R-8 | A2's own sources are product-agnostic | A2-owned test over `apps/server/lib/src/implementation/**` and its new `packages/scheduler/**` file, applying `product_agnosticism_test.dart`'s own rule: no product name, no host, no absolute-path default (§8.2/collision 3) | Any occurrence |
| **R-9** | **A1's materialiser leaves no credential on or beside the clone (M1)** | Materialise a clone, then assert **all** of: no `identity`, `known_hosts` or `ssh-wrapper.sh` remains beside the clone; `git -C <clone> config --get core.sshCommand` is unset; `git -C <clone> config --list` contains no path under the credential root; and the private half is gone from memory before the clone's fate is decided (§6.4's six obligations) | Any credential artefact survives, or `core.sshCommand` is set |
| **R-10** | **A1's two descriptor shapes are distinguishable (M1/§6.2.2)** | Write a `DurableWorkspaceDescriptor` into `OnboardingRecord.workspace` and assert the reader discriminates on `kind`; write a per-execution `WorkspaceDescriptor` and assert it is read as such. **A record of the wrong kind is a fail-closed error, never a fallback** | One shape is silently accepted as the other |

**R-9 exists because of a specific blind spot, and naming it is the point.** Obligations 3–5 of
§6.4 are **invisible on every success path**: a materialiser that leaves the identity file
beside the clone works perfectly and passes every functional test. There is no assertion a
functional suite can write that fails when a deploy-key identity is left on disk next to a
governed product's checkout — **unless the test looks for the file.** So it is written down, and
it is a review row rather than an implementation nicety.

**R-6 is no longer the row this brief cannot deliver.** `apps/control_plane/**` was READ-ONLY for
both units in revision 1; decision `fb3c3485` granted the two files A2 actually needs. §8.5 is
updated accordingly.

---

## 8. The split — disjoint path map, and the concurrency verdict

### 8.1 Path map — as revised

| Path | A1 | A2 | Revision 2 | Note |
|---|:--:|:--:|---|---|
| `apps/server/lib/src/baseline/**` | **OWN** | — | same owner | lane + `resolve(...)` factory + **its own materialiser** + gate update (§6.7, §6.8) |
| `apps/server/lib/src/credentials/**` | **READ-ONLY** | **READ-ONLY** | **FLIP** — A1 OWN → read-only for **both** | **all 13 files** (M5). `repository_snapshot_acquirer.dart` named explicitly. §6.8 |
| `packages/platform_contracts/lib/src/types/durable_workspace_descriptor.dart` | **OWN** *(NEW PATH)* | — | **NEW PATH** | `OD-8` = option A. Does not exist at `84be979` |
| `packages/platform_contracts/lib/src/types/onboarding_record.dart` + `.g.dart` | **OWN** | — | **FLIP** — unmapped → A1 OWN | the field type + `validate()`; §6.2.1 |
| `packages/platform_contracts/lib/src/types/workspace_descriptor.dart` | **READ-ONLY** | **READ-ONLY** | **FLIP** — conditional A1 OWN → read-only for **both** | **`OD-8` binds it unmodified for both** |
| `packages/platform_contracts/test/contract_schemas_test.dart` | **OWN** | — | **FLIP** — unmapped → A1 OWN | register the new schema |
| `schemas/durable_workspace_descriptor.schema.json` + `examples/…` | **OWN** *(NEW PATH)* | — | **NEW PATH** | `OD-8` = option A. Does not exist at `84be979` |
| `schemas/workspace_descriptor.schema.json` | **READ-ONLY** | **READ-ONLY** | **FLIP** — conditional A1 OWN → read-only for **both** | `OD-8` binds it unmodified for both |
| `schemas/onboarding_record.schema.json` | **OWN** | — | **FLIP** — conditional → **unconditional** A1 OWN | the inlined shape changes; §8.6 |
| `packages/product_registry/**` | **OWN** | — | **FLIP** — A1 read-only → A1 OWN | `recordWorkspace`'s parameter type (§8.6). **Was READ-ONLY in revision 1** |
| `packages/store_contract_tests/**` | **OWN** | — | **FLIP** — unmapped → A1 OWN | the shared conformance suite constructs `WorkspaceDescriptor` (§8.6) |
| `apps/server/lib/src/persistence/**` | **one file only** | — | **FLIP** — provisionally none → one file | `postgres_product_registry_store.dart` (§6.9, §8.6) |
| `apps/server/lib/src/services/control_plane_service.dart` | **OWN** | — | **FLIP** — unmapped → A1 OWN | one debug-log reader (§8.6) |
| `docker/**` | **OWN** | — | same owner | the host bind (§6.3) |
| `packages/platform_contracts/lib/src/enums/workflow_state.dart` | — | **OWN** | same owner, **formalised by grant** | granted by `fb3c3485`; required (§8.4) |
| `packages/scheduler/**` | — | **OWN** | same owner | new definition + drift-guard registration |
| `packages/workflow_engine/**` | — | **OWN** | same owner | new state mirror, new edge, routing retargets |
| `packages/workflow_store/**` | — | **OWN** | same owner | only if the escalation/rework reader changes |
| `apps/server/lib/src/implementation/**` | — | **OWN** *(NEW PATH)* | **NEW PATH** | granted by `fb3c3485`; §8.2/collision 3. Does not exist at `84be979` |
| `apps/control_plane/lib/core/plain_language.dart` | — | **OWN** | **FLIP** — carved out of the `apps/control_plane/**` read-only row → A2 OWN | **granted by `fb3c3485`**; §7.1 |
| `apps/control_plane/lib/shared/transition_copy.dart` | — | **OWN** | **FLIP** — carved out of the `apps/control_plane/**` read-only row → A2 OWN | **granted by `fb3c3485`**; §7.1 |
| **`apps/server/lib/server.dart`** | **—** | **OWN** | same owner | **the single shared seam; §8.3.** Also carries the env-var read A1 needs (M3) |
| `packages/platform_contracts/lib/src/types/workspace_descriptor.dart` | — | — | *(listed above)* | *(listed above — READ-ONLY for both)* |

**Legend for the `Revision 2` column — three values, and they mean different things:**
`NEW PATH` is a path that **does not exist at `84be979`** and that a unit will create.
`FLIP` is a path that **already existed** and whose **owner or reader-access changed** in revision
2 — sometimes into A1's ownership, sometimes out of it. `same owner` is a row revision 2 did not
move; the unit may still change what is *inside* it.

**Every `OWN` row above is disjoint between the two columns.** That is the property `C-1` and
`C-2` exist to guarantee, and review-matrix row **R-7** is how the Manager checks it before
dispatch. **Check it by reading the two ownership columns row by row. Do not check it by
counting**, and do not add the `NEW PATH` rows to the `FLIP` rows: the row set is the union of two
overlapping concerns — *does this path exist* and *who owns it* — so any total over it means one
thing when a reader assumes the other.

**Ownership is stated here as paths, and each is named rather than counted.** For reference:

- **Paths that do not exist at `84be979`** (`NEW PATH`): `durable_workspace_descriptor.dart`,
  `schemas/durable_workspace_descriptor.schema.json` + `schemas/examples/…`
  (both from `OD-8` = option A, §8.6), and `apps/server/lib/src/implementation/**`
  (the `fb3c3485` grant, §8.2/collision 3).
- **Paths whose ownership moved** (`FLIP`): into A1 — `packages/product_registry/**` (was A1
  read-only), `packages/store_contract_tests/**`, `apps/server/lib/src/services/control_plane_service.dart`,
  `apps/server/lib/src/persistence/**` (was provisionally none), `onboarding_record.dart` + `.g.dart`,
  `contract_schemas_test.dart`, `schemas/onboarding_record.schema.json` (was conditional);
  out of A1 — `apps/server/lib/src/credentials/**` (was A1 OWN, now read-only for both, M5) and
  `workspace_descriptor.dart` + its schema (were conditional A1 OWN, now read-only for both under
  `OD-8`); into A2 — `apps/control_plane/lib/core/plain_language.dart` and
  `apps/control_plane/lib/shared/transition_copy.dart` (both carved out of the single
  `apps/control_plane/**` row that was read-only for both).
- **The paths whose grant is still pending** are enumerated where they are escalated — §8.6's
  closing note — not summarised by a number here.

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
| Disjoint owned paths | **Yes**, after `C-1` — and it is checked by reading §8.1's two ownership columns row by row, **not** by counting rows, because §8.1's row set mixes paths that do not exist yet (`NEW PATH`) with rows whose owner changed (`FLIP`), and the two do not partition it | §8.1 |
| **Product code is independently compilable in either direction** | **Yes** | A1 calls `recordWorkspace`/`completeOnboarding`, which already exist (`f164d40`). A2 reads `readOnboardingForProduct`, which already exists (`postgres_product_registry_store.dart:1062-1071`). **Neither unit's own product code waits for the other's code to exist** — and since revision 2 granted A1 `packages/store_contract_tests/**`, A1's owned suite *does* transitively compile A2's `scheduler` and `workflow_store` at the base revision (`job_store_suite.dart:5` imports `package:scheduler/scheduler.dart`; `fixtures.dart:3` imports `package:workflow_store/workflow_store.dart` and builds `WorkItemState` values at `:13,103-104,145-146`), but it requires **no NEW declaration from A2**. The edge is one-directional — A1's → A2's — and it is satisfied by what already exists at base. |
| **The ONE-FILE composition-root integration is serialized** | **Yes, and it is not optional** | Once `C-1` is discharged, `server.dart` **references A1's runtime class** — so A2's composition cannot compile until A1's factory declaration is visible. **This is a compile-time dependency in exactly one direction, in exactly one file.** It is the accepted cost of `C-1` and it is two call lines. |
| A runtime dependency exists | **Yes — deliberately** | A2's readiness probe reads a record A1 writes (§7.7). |
| Concurrent **dispatch** without the workspace | **No, and must not happen** | The probe must defer, never dispatch (§7.7). This is a *runtime* ordering requirement, satisfied by the probe and testable by review-matrix row R-3. |
| Independent review of each unit is possible | **Yes** | A1: lane + materialiser + descriptor + gate + compose. A2: state + edge + definition + routing + probe + UI + compose. |

> **Operational consequence of the `store_contract_tests` edge — do not read one lane's green as
> evidence about the other.** The row above is about *compilation order*, and it holds. It is not a
> statement that the two lanes are independent *evidence*. Because A1's owned conformance suite
> compiles A2's `scheduler` and `workflow_store`, **a green A1 lane says nothing about A2's code** —
> it exercised A2 exactly as it stands at base, and A2's `WorkItemState.implementationReady` value
> and its new edge do not exist there. Two consequences for the Manager: **a passing A1 lane is not
> evidence about A2**, and **if A2 rebases onto A1 (or A1 onto A2), the rebase must re-run
> `packages/store_contract_tests/**`**, because that suite is where the two units' signatures meet.
> The same suite is the place a rebase conflict in either direction would surface as a compile
> failure rather than as a silently-wrong assertion.

> #### The correction (M2) — and why the wrong version was in the operator-facing field
>
> Revision 1's row read **"No compile-time dependency either direction | Yes"**, and the
> implementation-unit metadata carried the matching sentence: *"A2 compiles and passes its own
> tests without A1's code existing."* **Both are false once `C-1` is discharged**, because
> `server.dart` is A2's and it must reference A1's runtime type. A2's *product* code compiles
> independently; **A2's composition root does not, until A1's factory declaration exists.**
>
> That is not a pedantic distinction. The false claim sat in **`runtime_depends_on`** — the
> metadata field the dispatcher reads to decide whether two lanes may run concurrently. **A field
> that overstates independence is worse than no field**, because it is trusted precisely where
> nobody re-checks. The accurate statement is already in revision 1's own prose — §8.3's
> closing paragraph said *"serialized integration of the one shared file"* — **the wrong version
> was in the structured field and the right version was in the narrative.** Both now carry the
> accurate one.
>
> **What this does and does not change about the verdict:** `C-1` and `C-2` still hold, and the
> concurrency verdict is unchanged. `C-2` is precisely what makes the one dependency one-way and
> shallow: A1's factory is constructible without `server.dart`, so **A1 never waits on A2 at
> all** — the dependency is one-directional, and only A2's last composition step waits.

**So: concurrent code authoring, concurrent review, and serialized *integration of the one shared
file*.** That last clause is the honest cost and it is small — it is two call lines in a file
one of the units already owns.

### 8.4 Paths neither candidate list covers, which A2 therefore needs added

The dispatch's candidate list is incomplete against the code. Three additions are required and
are part of this revision's deliverable:

| Path | Needed by | Why the candidate list missed it | Status |
|---|---|---|---|
| `packages/platform_contracts/lib/src/enums/workflow_state.dart` | **A2** | `WorkItemState` is declared here (`:1-30`), not in `workflow_engine`. The dispatch said "add a state to `WorkItemState`" without naming the file. | **GRANTED** by `fb3c3485` |
| `apps/server/lib/src/implementation/**` | **A2** | §8.2/collision 3: the resolver must not live in an A1-owned directory. | **GRANTED** by `fb3c3485` |
| `apps/control_plane/lib/core/plain_language.dart`, `apps/control_plane/lib/shared/transition_copy.dart` | **A2** | §8.5 — the UI's state mapping defaults an unknown state to `awaitingReview`. | **GRANTED** by `fb3c3485` |

**The fourth row revision 1 carried conditionally is now settled by `OD-8` = option A, and the
answer changed the shape of the grant.** Revision 1 offered
`workspace_descriptor.dart` + `schemas/*.schema.json` **conditionally** — *"Not granted
pre-emptively; granted per the `OD-8` answer."* The answer was **option A (a second type)**, so:

- **`workspace_descriptor.dart` and `workspace_descriptor.schema.json` are NOT granted — they
  are READ-ONLY for both units**, because option A's whole content is that `WorkspaceDescriptor`
  is not modified.
- **What is needed instead is a NEW type and schema, plus the readers of the field whose type
  changes.** That is materially wider than revision 1's conditional row, and it is enumerated
  in the next section rather than folded in silently.

### 8.5 The UI gap — CLOSED by decision, converted to an obligation

**Revision 1 recorded this as a gap neither unit could close** and recommended granting A2 the
two UI files. **The operator granted them** (`fb3c3485`), with the reason recorded: *"Reviewer
confirmed the UI render gap: `plain_language.dart`'s switch defaults an unknown `WorkItemState`
to `PlainStatus.awaitingReview`, so `implementation_ready` would render falsely. Without these two
files an item at the new state is misreported as awaiting review."*

**So the "visible defect shipped knowingly" that §12.3 previously asked the human to accept is
no longer on the table.** The obligation is now A2's, and it is specific:

| File | Current behaviour | A2's obligation |
|---|---|---|
| `apps/control_plane/lib/core/plain_language.dart:110-135` | `_ => PlainStatus.awaitingReview` (`:135`) | Add `implementation_ready` to a defined arm. **Not** the default, and not `awaitingReview` — an item waiting to be implemented is not waiting for review. |
| `apps/control_plane/lib/shared/transition_copy.dart:26-95` | `_ => null` (`:94`) → `kUnknownTransitionMessage` | Add the inbound and outbound pairs so the state reads as a stage, not as *"The work moved to a new stage."* |

**This is why §12.3 item 5 disappears from the approval request**, and why
`DESIGN_SYSTEM_COMPLIANCE` moves from `PARTIAL` to `PASS` (§13.3) — not because the gap stopped
existing, but because it now has an owner and a test (R-6).

### 8.6 NEW — the verified blast radius of `OD-8` = option A, which revision 1 under-scoped

**This is a finding that arose from folding in an operator answer, not from the review.** It is
recorded here because §8.1 asserts ownership rows, and asserting ownership of a file whose
reader was never checked is how §8.2's original collision happened in the first place.

**The mechanism.** `OD-8` = option A requires `OnboardingRecord.workspace` to hold a
`DurableWorkspaceDescriptor`. The field is currently typed `WorkspaceDescriptor`
(`onboarding_record.dart:122`). So the field's **Dart type changes**, and every reader that binds
it to a typed value must change with it. The **JSON column does not** — it is already
`JsonValue?`, which is precisely why the decision says no migration is needed.

**Verified, file by file.** Every non-test reference to `OnboardingRecord` was enumerated and
each was checked for whether it binds `.workspace` to a typed value:

| File | What it does with `workspace` | Breaks? |
|---|---|---|
| `packages/platform_contracts/…/onboarding_record.dart` | the field type itself; `hasLiveWorkspace` (`:150`), `hasDurableWorkspace` (`:157`), `validate()` comparing `pin != ws.startingRevision` (`:238-244`) | **YES** — A1 owns; this is the intended change |
| `…/onboarding_record.g.dart` | generated serialisation | **YES** — regenerated |
| `packages/product_registry/…/product_registry_engine.dart` | `recordWorkspace({ … WorkspaceDescriptor? workspace … })` at **`:1917-1922`**, and `copyWith(workspace: …)` at `:1950` | **YES** — the parameter type must change. **Revision 1 listed `packages/product_registry/**` as READ-ONLY for A1.** |
| `packages/product_registry/…/in_memory_product_registry_store.dart` | round-trips through the same type | **YES** |
| `packages/product_registry/…/product_registry_store.dart` | the **abstract** store interface — `saveOnboarding(OnboardingRecord record)` at **`:184`** and `readOnboardingForProduct(String productId)` at **`:186`**. It names the record as a type and hands it on; it never reads `.workspace` | **NO** — the abstract store names the record, never `.workspace` |
| `packages/store_contract_tests/…/product_registry_store_suite.dart` | constructs `WorkspaceDescriptor(…)` at `:224-230` and asserts `.workspaceId` / `.startingRevision` / `.worktreePath` at `:246-266` | **YES** — the shared conformance suite |
| `apps/server/lib/src/persistence/postgres_product_registry_store.dart` | reads the column as text and decodes it (`:1147`, `:1156-1166`) | **YES** — one binding |
| `apps/server/lib/src/services/control_plane_service.dart` | `final workspace = onboarding?.workspace;` (`:2193`) and `workspace?.workspaceId` (`:2209`, inside a `logger.debug`) | **YES** — one line |
| `apps/server/lib/src/generated/**` | the **database** row's own `workspace`, already `String?` | **NO** — the DB layer is unaffected, which is the no-migration claim |
| `worker_reconciler`, `local_worker`, `onboarding_worker`, `engineering_review_gate` | **no reference to `OnboardingRecord` at all** | **NO** — `OD-8`'s byte-identical binding holds |

**What this does NOT do, stated because it is the part that matters.** It adds **no null branch
to the artifact-resolution chain**, which is the operator's stated reason for preferring option
A. `engineering_review_gate.dart:71-76` re-reads `producer.repositoryPath` and is untouched; the
four per-execution consumers are untouched. **Option A's cost is a wider A1 path map, not a
weakened hot path.** The trade the operator made was the right one; this section only makes the
bill exact.

**The one place a human could reasonably want more.** `control_plane_service.dart:2209` is a
`logger.debug` line reading `workspace?.workspaceId`. It must change, and the honest options are
(A1 owns the file) or (the read is deleted). **Recommendation: A1 owns the file** — deleting a
debug line that documents the execution-vs-product workspace distinction
(`:2181-2205`) would lose the explanation of why the two are different, and that comment is the
best documentation of the confusion this whole design exists to resolve.

> #### ⚠ Escalation to the Manager — a path grant is needed, and it is NOT self-granted
>
> The four new paths above — `packages/product_registry/**`, `packages/store_contract_tests/**`,
> `apps/server/lib/src/persistence/postgres_product_registry_store.dart` and
> `apps/server/lib/src/services/control_plane_service.dart` — plus the already-mapped
> `onboarding_record` type/schema trio **are not in the operator's
> `granted_paths_beyond_brief` list**, and A1 cannot compile or pass its own tests without them.
> The distinction is stated because it changes what the amendment is: the trio was **already A1's
> conditional map entry in revision 1** (§8.4's `OD-8` row, which anticipated that the cost would
> "move to a new schema file"), so it needs no new decision — only the **four** genuinely new paths
> do.
>
> **Ownership is granted by the Manager or the operator, never by the designer.** This lane
> therefore records the requirement and the recommendation and **takes nothing**. Extending the
> grant is a one-line amendment to a decision object, and it is the same class of action as the
> grants already made in `fb3c3485` — recorded there for exactly this reason: *"Without these
> two files an item at the new state is misreported as awaiting review."*
>
> **This does not block this revision.** The design is complete and reviewable; the grant is a
> **dispatch-time input**. If it is declined, A1 cannot start — which is why it is raised here,
> loudly, rather than discovered by an implementer at compile time.

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
| **D-4** | **Durable-workspace location: a HOST BIND, `${SHIPIT_HOST_WORKSPACE_DIR}`**, matching the `${SHIPIT_HOST_SECRET_DIR}` custody precedent (`compose.qa.yaml:119`), with a fail-closed sentinel of the same shape and explicit `-p` on every teardown. **`OD-7` = option B, resolved by `9bfe2d09`.** Revision 1 recommended a Docker named volume; **the operator chose the host bind**, and the deciding factor was review reachability (§6.3.5), not durability. | §6.3, decision `9bfe2d09` |
| **D-5** | **The durability requirement is stated as "survives container restart".** It is **not** "survive `make qa-down`" — `qa-down` is the documented teardown of the QA stack (`Makefile:90-92`) and `AGENTS.md` records what an unscoped `down -v` already destroyed. A host bind survives `down -v` **as a bonus**, not as a claim. | §6.3.2 |
| **D-6** | **A1 does not build its clone through `RepositorySnapshotAcquirer` + retain.** It composes the trust primitives with its own materialiser. Three independent reasons, §6.4. | §6.4 |
| **D-7** | **Credential custody is unchanged and out of scope — and the property is an OBLIGATION, not an inheritance (M1).** `OD-2` **withdrawn**. The acquirer provably leaves no credential (`repository_snapshot_acquirer.dart:740,743-746`, `:1202`, `:1209-1215`, `:867-882`), **but A1 does not reuse the acquirer**, so A1's own materialiser **MUST** reproduce all six properties in §6.4 — including leaving **no `core.sshCommand` and no identity reference in the clone's git config**. Revision 1 asserted this as fact about A1; it was an assumption about a file that does not exist yet. | §1.3, §6.4, §7.10 R-9 |
| **D-8** | **Snapshot retention is flagged, not inherited and not fixed.** Three distinct objects, three distinct reclaimer responsibilities (§6.5). **Enforced structurally, not by policy (M5):** all thirteen files in `apps/server/lib/src/credentials/**` are READ-ONLY for A1, including `repository_snapshot_acquirer.dart`, so A1 *cannot* fix the leak even by accident. | §6.5, §6.8 |
| **D-9** | **A new `WorkItemState` and the routing retargets are the ONLY lifecycle change in this design, and they sit in A2 alone.** A1 changes no lifecycle state. | §4.3 |
| **D-10** | **`implementFeatureDefinition.entryStates = {implementationReady}`, a one-element set, with no `entryProbeTargets`.** Disjointness is structural. | §7.2, §7.4 |
| **D-11** | **`defaultImplementFeatureDefinition` is NOT repurposed.** It is `const`, test-only in production, and used by ~20 test files. A sibling definition is added. | §7.2 |
| **D-12** | **The direct edge `implementationReady -> agentExecuting` is added**, with the guards copied from `designNotRequired -> agentExecuting`, and **without** `qaContractExists()`. | §7.3 |
| **D-13** | **Only two of the five rework pairs need `escalationTargetFor` lockstep**, not five. `escalationTargetFor` returns `null` unless the choice is `reject`/`rework` (`human_decision_routing.dart:135-138`; `durable_workflow_engine.dart:979-993`). **The stale brief was wrong on this and the correction is load-bearing.** | §7.5 |
| **D-14** | **A `waitingForHumanDecision -> implementationReady` edge with the same `blockingHumanDecisionResolved` guard set is an obligation**, whatever `OD-3` answers. **The stale brief missed this entirely.** | §7.5, Obligation A |
| **D-15** | **A2 blocks on A1 at runtime**: no durable workspace ⇒ defer, no dispatch, no human decision, never `HEAD`, never `triageSource`. | §7.7 |
| **D-16** | **`apps/server/lib/server.dart` is assigned exclusively to A2** (the file named in the dispatch, `apps/server/lib/src/scheduler.dart`, does not exist), with the two conditions in §8.3. | §8.2, §8.3 |
| **D-17** | **`packages/platform_contracts/lib/src/enums/workflow_state.dart` is added to A2's map**, and `apps/server/lib/src/implementation/**` is added as A2's resolver home. **Both granted by `fb3c3485`.** | §8.4 |
| **D-18** | **The product-agnosticism gate is treated as a design obligation, not a test to satisfy later**: A1's env-var read must happen in the composition root, not in `lib/src/baseline/`. **Corrected (M3): that read is now explicitly A2's obligation under `C-1`**, because `C-1` assigns `server.dart` exclusively to A2. Revision 1 recorded this as A1's obligation while A1's own path map made it impossible for A1 to perform. A1's grant was deliberately **not** narrowed instead, because `C-1`'s single-writer guarantee is the stronger invariant. | §6.7, §7.9, §8.3 |
| **D-19** | **Stranded `agent_completed` items are out of scope** and stay fail-closed. | §9.4 |
| **D-20** | **`OD-8` = option A: a NEW `DurableWorkspaceDescriptor` type + schema; `WorkspaceDescriptor` and its schema are READ-ONLY for both units.** The per-execution consumers are byte-identical — re-verified: all four provably never reference `OnboardingRecord`. No migration; the column is already `JsonValue?`. | §6.2.1, decision `c04f6a8d` |
| **D-21** | **The new type carries a mandatory literal discriminator** (recommended `"kind": "durable"`), and a record of the wrong kind is a **fail-closed error, never a fallback.** One column now holds two shapes; without this they are silently interchangeable, which is the fabricated-provenance failure class `c04f6a8d` option `C` was rejected for. | §6.2.2, R-10 |
| **D-22** | **A1's map is narrowed: `apps/server/lib/src/credentials/**` is READ-ONLY for BOTH units (M5)** — all thirteen files, `repository_snapshot_acquirer.dart` named. A1 composes the primitives; it modifies none. The materialiser lives under `lib/src/baseline/**` so the agnosticism gate covers it. | §6.8 |
| **D-23** | **The UI mislabel obligation moves to A2 (decision `fb3c3485`).** `plain_language.dart` and `transition_copy.dart` are granted; §8.5 closes and becomes R-6. `DESIGN_SYSTEM_COMPLIANCE` moves `PARTIAL` → `PASS`. | §7.1, §8.5, §13.3 |
| **D-24** | **A2's `runtime_depends_on` is corrected (M2): product code is independently compilable, but the ONE-FILE composition-root integration is SERIALIZED.** `server.dart` references A1's runtime class once `C-1` is discharged. Revision 1's "no compile-time dependency either direction" was false in the very field the dispatcher reads. | §8.3 |
| **D-25** | **`OD-8`'s verified consequence is recorded, not absorbed (new finding):** changing `OnboardingRecord.workspace`'s type puts `packages/product_registry/**`, `packages/store_contract_tests/**`, `postgres_product_registry_store.dart`, `control_plane_service.dart` and the `onboarding_record` type/schema trio in A1's scope. **These are not granted; the grant is escalated to the Manager and this lane takes nothing.** | §8.6 |

---

## 11. Open decisions — escalated, not decided

> **Status at revision 2. Two of seven are now closed, and neither closure is partial in a way
> that should be read as complete:**
>
> | Decision | Status | Authority |
> |---|---|---|
> | `OD-1` | RESOLVED, moot | merged code (`cc9317c`) |
> | `OD-2` | WITHDRAWN — premise false | this brief, §1.3 |
> | **`OD-7`** | **PARTIALLY RESOLVED — location only.** `OD-7.2` (lifetime) and `OD-7.3` (who presses) **remain open.** | decision `9bfe2d09` |
> | **`OD-8`** | **RESOLVED** — option A | decision `c04f6a8d` |
> | `OD-3` | **OPEN — not answered** | — |
> | `OD-4` | **OPEN — not answered** | — |
> | `OD-5` | **OPEN — not answered** | — |
> | `OD-9` | **OPEN — not answered** | — |
> | `OD-10` | **OPEN — not answered** | — |
>
> **The operator answered three questions in this round** (the Level 3 approval itself, `OD-7`,
> `OD-8`). **The other five were not put to them and are not answered.** They are **not
> silently closed, not inferred, and not treated as low-priority** — each is restated below with
> what it blocks, and the per-unit dispatchable-vs-gated table in §12.3 is built from exactly
> this status.

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

> **PARTIALLY RESOLVED — question 1 only.** Decision `9bfe2d09` (ARCHITECTURE, RESOLVED,
> option **B**) answers **where it lives**: a host bind, `${SHIPIT_HOST_WORKSPACE_DIR}`.
> **Questions 2 and 3 are still open** — see `OD-7.2` and `OD-7.3` below. Revision 1's sentence
> *"Blocks: A1's compose change and its reclamation path"* still holds: **the compose change is
> unblocked; the reclamation path is not.**

**Resolved part — where it lives.** §6.3. Host bind, matching the `${SHIPIT_HOST_SECRET_DIR}`
precedent, with a fail-closed sentinel of the same shape and explicit `-p` naming on every
teardown. §6.3.2–6.3.4 state the binding obligations. §6.3.5 retains revision 1's option analysis
for the record, including the fact that **revision 1 recommended the other option** and why the
operator's choice was better for review.

**The requirement, restated for the answer that was given.** §2.4: **the clone is the artifact,
so it must not be ephemeral.** The host bind satisfies it by the strongest available margin —
it survives `down`, `down -v` and volume pruning, because the host directory is not Docker's to
delete — and it additionally keeps the evidence reachable from the host, which is what makes
review-matrix rows R-3 and R-4 checkable.

#### `OD-7.2` — how long does a durable clone live? **STILL OPEN**

Unlike every other clone in this platform it has a **product** lifetime, not an execution
lifetime. `WorkspaceDescriptor.markCleaned(at)` exists for the "no longer there" transition
(`workspace_descriptor.dart:51-62`) and `OnboardingRecord.hasLiveWorkspace` reads it
(`onboarding_record.dart:150`) — **but nothing produces a cleaned durable descriptor, so there
is no policy.**

**Recommendation, unchanged from revision 1 and still only a recommendation:** a durable clone is
reclaimed when its product leaves `governed` for `archived`, and **never before**. That uses the
existing lifecycle rather than inventing a timer, and it is the only bound that ties a disk cost
to a fact the platform already records (`product_state.dart:58`).

**What is bounded already, so the gap is honest rather than alarming:** one clone **per product**,
not one per execution. This is categorically different from `OD-9`'s retained-tree leak, which is
**one per execution that committed**, unbounded, with no owner. A product-scoped leak grows with
the number of registered products; an execution-scoped one grows with everything the platform
does.

#### `OD-7.3` — who presses it? **STILL OPEN**

**Recommendation: a human action, not a sweep.** Deleting a product's only checkout is not a
machine decision — and `AGENTS.md`'s standing rule is that destructive operations are
human-authorised. A sweep would be a new autonomous destructive capability, which is a larger
decision than the one being asked.

**Blocks:** `OD-7.2`/`OD-7.3` block **A1's reclamation path only**. A1's compose change is
unblocked. **Does not block:** A2 entirely.

### ~~`OD-8` — `WorkspaceDescriptor` is per-execution; a durable clone is per-product. What shape?~~ **RESOLVED — option A**

> **RESOLVED** by decision `c04f6a8d` (ARCHITECTURE, selected **A**): add
> `DurableWorkspaceDescriptor` as a **separate type + schema**; leave `WorkspaceDescriptor`
> untouched; the per-execution consumers stay byte-identical with no new null branches; no
> migration. The operator's stated rationale: *"the blocker is a type-shape conflict, not a
> missing field. Weakening the per-execution type would push null-handling into the chain that
> must fail closed on a missing artifact."*
>
> **§6.2.1 is the binding text. §6.2.2 records the two obligations the answer implies but does
> not state. §8.6 records the verified consequence the answer did not anticipate.**

**What revision 1 recommended and why the operator overruled it.** Revision 1 recommended
option (b) — an explicit `kind` discriminator on `WorkspaceDescriptor` — and listed option (c),
a second type, as *"the cleanest model"*, while noting that migration `20261012213045000` had
rejected the second-*table* form in its own header. The operator chose the second-*type* form
anyway, and the reasoning is better than revision 1's: `kind` would have left one type meaning
two things, which is exactly how `escalationTargetFor` and `targetFor` came to disagree in this
repository (`human_decision_routing.dart:98-109`). **Revision 1 saw the risk and preferred a
mitigation to the separation; the operator preferred the separation.** Recorded so a reviewer can
check that the override was deliberate rather than an oversight.

**Blocks:** nothing in A1 any more — **`OD-8` was what blocked A1's write path, and it is
answered.** **Does not block:** A2 entirely.

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

## 12. Risk assessment — **Level 3**, and the approval that was granted

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

### 12.3 The approval — GRANTED at Risk Level 3, pair-wide

> ### ✅ APPROVAL GRANTED — `fb3c3485`, RESOLVED, option A
>
> **Risk Level 3 is confirmed and is NOT available for downgrade.** The operator granted the
> design at Level 3, independently against `DESIGN_GOVERNANCE.md:99`. **Revision 2 changes no
> ground of the Level 3 justification** (§12.1) — it adds no state, no edge, no route and no
> workflow change. `OD-8`'s answer widens A1's *file* map; it does not touch the lifecycle.
>
> **The approval is PAIR-WIDE (L3 correction).** Revision 1 was internally inconsistent about
> scope: §4.3 said the approval request *"is scoped to A2's lifecycle surface rather than to the
> pair"*, while §12.3 items 3 and 4 asked for approval on **A1's** clone location and **A1's**
> schema change. Both were really pair-wide and only one said so.
>
> **Corrected, and the correction matters because approval is what authorises work.** The grant
> is for **A1 + A2 as a pair**, and §12.3's list below is restated pair-wide. A1's compose change
> and A1's descriptor work were always inside what was being approved; they are simply now
> described as such.
>
> **What the approval binds (verbatim from the decision):** *"Concurrent DISPATCH without a
> durable workspace is NOT authorised. The §7.7 readiness probe must defer rather than dispatch.
> Approval authorises BUILDING A1 and A2, not landing IMPL-001/IMPL-002."*
>
> **The paths granted beyond the brief are these, and each is now reflected in §8.1**:
> `apps/control_plane/lib/core/plain_language.dart`,
> `apps/control_plane/lib/shared/transition_copy.dart`,
> `apps/server/lib/src/implementation/**`,
> `packages/platform_contracts/lib/src/enums/workflow_state.dart`.

#### What the human accepted, restated pair-wide

1. **A new `WorkItemState` (`implementationReady`) and a new transition edge** into the
   platform's core lifecycle enum and table. *Alternative considered and rejected:* reuse
   `designNotRequired` and add a guard — which cannot work, because the collision is
   structural and a guard is procedural (§7.4).
2. **Retargeting up to five human-decision routes**, changing what "rework" and "reject" mean
   across four decision types. The specific split recommended — and the specific pairs that
   must move `escalationTargetFor` in lockstep (`OD-3`, `D-13`) — is a **product decision**,
   and it is the one most worth overruling if the human reads "rework" differently than this
   brief does. **`OD-3` remains unanswered** — see the table below.
3. **A durable, product-scoped clone of every governed product's repository on shared storage.**
   **`DECIDED: host bind `${SHIPIT_HOST_WORKSPACE_DIR}`** (`9bfe2d09`, §6.3). Container-ephemeral
   was rejected because it destroys the artifact (§6.3.5). **The reclamation policy remains
   open** (`OD-7.2`, `OD-7.3`).
4. **A change to a published JSON Schema** — resolved in the operator's favour and **against
   revision 1's recommendation**: a **new** `DurableWorkspaceDescriptor` type + schema, with
   `WorkspaceDescriptor` untouched (`c04f6a8d`, §6.2.1). No migration is required. The
   verified path consequence is in §8.6.
5. ~~**A visible defect shipped knowingly**~~ — **NO LONGER ACCEPTED. CLOSED.** The operator
   granted the two UI files, so the mislabel obligation is A2's and testable (R-6). **This item
   is withdrawn from the list because the thing it accepted is no longer going to happen.**
6. **That the first implementation lane is supervised, not autonomous** (`OD-10`) — it
   dispatches only from resolved human decisions. If the human wants autonomous dispatch, that
   is a different design and this one should not be stretched to cover it. **`OD-10` remains
   unanswered.**

#### ⚠ 12.3.1 What approval did **NOT** authorise — per-unit, dispatchable now vs still gated (M4)

**This is the finding M4 identified, and it is the single most important honesty statement in
this document. Approval authorises BUILDING. It does not deliver `IMPL-001` or `IMPL-002`.**

> **Neither `IMPL-001` nor `IMPL-002` completes on approval alone.** Revision 1 did not partition
> this, so an approval could reasonably be misread as *"both requirements land"*. They do not.
> The table is per-unit and per-work-item, and the status column is derived **only** from the
> decisions actually recorded in §11 **and §8.6's recorded ungranted-path status** — never from an
> inference about intent. Exactly one row consults the second source: *"the field-type change and
> every reader it breaks"*, gated on a **path grant**, not on a decision in §11. The divergence is
> in the safe direction — §11 alone would read `YES`, §8.6's recorded status reads `NO — cannot
> start` — and the row names its own gate in the "Still gated on" column. §13.2 records the same
> row, so the two cannot drift apart unnoticed.

**A1 — durable workspace creation**

| Work item | Status after approval | Authorable now? | Still gated on |
|---|---|---|---|
| Host bind mount + sentinel + `-p` naming (§6.3) | ✅ **UNBLOCKED** (`9bfe2d09`) | **YES** | — |
| Lane, `resolve(...)` factory, agnosticism-gate update (§6.7, §6.8) | ✅ UNBLOCKED | **YES** | — |
| Own materialiser + the six credential obligations (§6.4, M1) | ✅ UNBLOCKED | **YES** | — |
| `DurableWorkspaceDescriptor` type + schema + `kind` discriminator (§6.2.1, D-21) | ✅ **UNBLOCKED** (`c04f6a8d`) | **YES** | — |
| The field-type change and every reader it breaks (§8.6) | ✅ Unblocked in principle | **NO — cannot start** | **Path grant for the paths §8.6 escalates: `packages/product_registry/**`, `packages/store_contract_tests/**`, `apps/server/lib/src/persistence/postgres_product_registry_store.dart`, `apps/server/lib/src/services/control_plane_service.dart`. Not self-granted.** |
| **Reclamation policy — lifetime bound** | ❌ **GATED** | **NO** | **`OD-7.2` — unanswered** |
| **Reclamation policy — who presses it** | ❌ **GATED** | **NO** | **`OD-7.3` — unanswered** |
| **A1's persisted output** (`IMPL-002`) | ❌ **NOT MET** | — | `OD-7.2`, `OD-7.3`, and the §8.6 grant |

**So: `OD-7` unblocked A1's *compose change*, which is one of two things it was blocking.** The
reclamation path is the other, and it is untouched. **`IMPL-002` is therefore not met by
approval** — the workspace will exist and be durable, but nothing bounds its life or names who
deletes it.

**A2 — implementation scheduler**

| Work item | Status after approval | Authorable now? | Still gated on |
|---|---|---|---|
| `WorkItemState.implementationReady` + exhaustive mirror (§7.1, §7.2) | ✅ UNBLOCKED | **YES** | — |
| Direct edge `implementationReady -> agentExecuting` (§7.3, D-12) | ✅ UNBLOCKED | **YES** | — |
| `implementFeatureDefinition`, one-element entry set (§7.2, D-10) | ✅ UNBLOCKED | **YES** | — |
| Drift-guard registration (§7.2) | ✅ UNBLOCKED | **YES** | — |
| **Routing retargets across the five pairs** (§7.5) | ❌ **GATED** | **NO** | **`OD-3` — unanswered.** `D-13`/`D-14` (lockstep + the missing edge) bind *regardless*, so the edge's guard set is authorable even though which pairs route there is not. |
| **Deferral shape** (§7.7) | ❌ **GATED** | **NO** | **`OD-4` — unanswered** |
| **Dispatch at all** | ❌ **GATED** | **NO** | **`OD-5`** (items stall at `agentExecuting` with no `qaContractId`, §9.1 precondition 3) **and `OD-10`** (nothing routes into `implementationReady`) |
| UI mapping (§7.1, §8.5) | ✅ UNBLOCKED (granted) | **YES** | — |
| Composition-root wiring incl. A1's env-var read (§8.3, M3) | ✅ UNBLOCKED, **serialized** | **YES, last** | waits on A1's factory declaration — `C-2` |
| **`IMPL-001` ("an implementation lane exists and is wired")** | ❌ **NOT MET** | — | `OD-4`, `OD-5`, `OD-10` |

**The honest summary, in one sentence: approval makes both units *buildable in full* and both
requirements *still unmet*.** What is unblocked is the writing of code; what remains gated is
every place where a product decision — not an engineering one — determines whether the lane does
anything at all.

**What that means for dispatch, concretely:** A1 and A2 may be dispatched as two concurrent
implementer lanes **today**, subject only to §8.6's path grant for A1. Neither will complete its
requirement. `IMPL-003` additionally depends on `OD-5` (§13.1).

> #### What `OD-5` and `OD-10` together mean, stated without softening
>
> `OD-10` asks what routes a work item into `implementationReady`. `OD-5` asks whether an item
> without a `qaContractId` may be dispatched at all. **Both are open, and they point at opposite
> ends of the same pipeline:** with `OD-10` unanswered there is no **inflow**, and with `OD-5`
> unanswered there is no **outflow** past `agentExecuting`. A2 built today would be **a scheduler
> that never dispatches** — which revision 1 called *"safe, but the requirement is unmet"*, and
> that phrasing is preserved deliberately. **Safe is not done.** It is stated here so nobody
> later reads a green A2 review as a working implementation lane.

---

## 13. Traceability

### 13.1 Requirements covered

> **Read §13.2's limitation first (L2).** `IMPL-001`..`IMPL-005` have **no source-of-truth
> requirements artifact in this repository** — they entered as dispatch text. The table below is
> therefore *dispatch-identifier → design section*, **not** evidence that the platform's
> requirements are covered. See §13.2.

| ID | Requirement | Where | Status after approval |
|---|---|---|---|
| `IMPL-001` | An implementation lane exists and is wired | §7.1-7.3, §7.8 | A2. **NOT MET** — gated on `OD-4`, `OD-5`, `OD-10`. A green A2 review is a built scheduler, not a working lane (§12.3.1). |
| `IMPL-002` | The workspace is real, durable, and credential-mediated | §2.2-2.4, §6.1-6.4, §6.7 | A1. **NOT MET** — location decided (`OD-7.1`); **reclamation gated** on `OD-7.2`/`OD-7.3`; the persistence path additionally blocked pending the §8.6 grant. Product-agnostic with a **mechanical** gate (§6.7). |
| `IMPL-003` | Engineering review dispatches instead of failing closed | §3, §9.1 | Verified end to end; requires `OD-5`. |
| `IMPL-004` | No concurrent double-dispatch onto one work item | §7.4, §8.1-8.3 | Disjoint entry sets; structural, re-verified against `cc9317c`. **Safe under any `OD-3` answer.** |
| `IMPL-005` | No artifact is manufactured | §4.2, §7.7, §9.2, §9.4 | The hazard, the guard, the negative control, and the backlog refusal. **Strengthened by R-9** (no credential left on the clone) **and R-10** (the two descriptor shapes are not interchangeable). |

### 13.2 Requirements gaps — recorded, not closed

**A traceability limitation, stated first because it bounds everything else in this section (L2).**

> **⚠ `IMPL-001`..`IMPL-005` have NO source-of-truth requirements artifact in this repository.**
> Verified at this base: a search for `IMPL-001`, `IMPL-002` … `IMPL-005` across every `.md`,
> `.yaml` and `.json` file returns **only this design folder**, and there is **no
> `docs/requirements/` directory** (`docs/` contains `adr`, `architecture`, `checkpoints`,
> `deployment`, `design`, `engineering`, `qa`, `reports`). The five IDs entered this brief as
> **dispatch text**, not as a durable requirements record.
>
> **What follows from that, stated so nobody over-reads §13.1:** the mapping below is from
> *requirement identifiers as stated in the dispatch* to *design sections*. **It is not evidence
> that the platform's requirements are covered**, because there is no independently-checkable
> statement of what they are. A reviewer should treat §13.1 as *"this design addresses what the
> dispatch asked for"* and not as *"these requirements are satisfied"*.
>
> **Recommendation, deliberately not actioned here:** persist a requirements artifact before
> `IMPL-001` is claimed complete, so the claim has something to be checked against. Writing one
> would mean authoring requirements text — a product decision outside this lane's authority.

| Gap | Consequence |
|---|---|
| **No requirements artifact exists (L2)** | The traceability above is dispatch-text-to-design, not requirements-to-design. **Bounds §13.1's meaning.** |
| `OD-7.2` / `OD-7.3` unanswered | **A1 can ship the mount but not a reclamation policy.** `IMPL-002`'s workspace will exist and be durable, with **no bound on its lifetime and no named reclaimer.** §6.3.6. |
| §8.6's escalated paths not granted — `packages/product_registry/**`, `packages/store_contract_tests/**`, `apps/server/lib/src/persistence/postgres_product_registry_store.dart`, `apps/server/lib/src/services/control_plane_service.dart` | **A1 cannot compile.** The field-type change `OD-8` requires is blocked until the grant is extended. **Dispatch-time input, not a design gap — and this lane took nothing.** |
| `OD-5` unanswered | `IMPL-003` cannot complete end to end; items A2 dispatches would stall at `agentExecuting` for ever. §9.1 precondition 3. |
| `OD-10` unanswered | `IMPL-001` may build a scheduler that never dispatches. Safe, but **the requirement is unmet**. |
| `OD-3` unanswered | A2's routing edits cannot be written. `D-13`/`D-14` bind regardless, so the guard set is authorable even though the route is not. |
| `OD-4` unanswered | The deferral shape is undecided; A2's composition is gated on it. |
| `OD-9` unanswered | Retained-tree reclamation has no owner. **Pre-existing; not a gap this design introduces, and deliberately not one it closes.** |
| ~~`apps/control_plane/**` not granted~~ | **CLOSED** — granted by `fb3c3485`; now an A2 obligation with a test (R-6). **No longer a gap.** |
| No QA-contract lane assumed | `OD-5`. Same dependency as above, named from the other side. |

### 13.3 Design-system and UX assessment

- **`DESIGN_SYSTEM_COMPLIANCE`: `PASS`** — **moved from `PARTIAL`** (D-23). No token, component
  or pattern is added or changed by either unit; the one gap that made `PARTIAL` honest is now
  closed. `apps/control_plane/lib/core/plain_language.dart` and
  `apps/control_plane/lib/shared/transition_copy.dart` are **granted to A2** by `fb3c3485`, so
  the new state's mapping is an A2 obligation with a test behind it (R-6). **A reviewer should
  read this as `PASS` conditional on A2 actually adding the `case`** — the score describes the
  design's completeness, and the test is what makes it true at implementation time. Revision 1's
  "a reviewer may reasonably read that as `FAIL` for A2" no longer applies: there is nothing left
  to read as a failure.
- **`UX_ACCESSIBILITY_SCORE`: `PASS`** — **moved from `PARTIAL`.** No new focusable element,
  input, or navigation; **no WCAG criterion is engaged by this design at all.** Revision 1 held
  this at `PARTIAL` because an operator would be told an unbuilt item is awaiting review. That is
  a *correctness* defect on an existing screen rather than an accessibility one — and it is now
  fixed at source. **The honest statement of what changed is that the defect is gone**, not that
  a criterion was reinterpreted more favourably.
- **`IMPLEMENTATION_FEASIBILITY`: `HIGH`.** Every mechanism already exists: `JobType.implementFeature`
  and `AgentRole.implementer` (`job_type.dart:7`, `agent_role.dart:2`), `Scheduler` +
  `workloadResolver` (`scheduler.dart:314-336`), `LocalWorker` + `WorkerRegistry` +
  `WorkerDispatcherAdapter` (`server.dart:195-220`), `ArtifactCommitter`
  (`artifact_committer.dart:98-158`), `GitWorktreeWorkspaceManager`, the full credential/host-key
  trust chain (`repository_snapshot_acquirer.dart:504-600`), `recordWorkspace` +
  `completeOnboarding` (`product_registry_engine.dart:1917`, `:1976`), and the
  `UnavailableBaselineLaneRunner` fail-closed pattern (`baseline_runtime.dart:72-97`). The new
  production artefacts are: one enum value, one edge, one `const JobDefinition`, one
  `JobDefinition` registration in an existing test, **one new descriptor type + schema**, two UI
  switch cases, and A1's lane + materialiser. **No migration, no generated code beyond the
  existing `.g.dart` regeneration, no new dependency.** Two reservations, both now *shapes*
  rather than feasibility: `OD-8` is answered (and its consequence is mapped in §8.6), and
  `OD-4` decides the resolver's result type.

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
| Durable product-scoped clone + its materialiser | **NEW** — location `OD-7.1` **decided**, bound `OD-7.2` / presser `OD-7.3` **open** |
| `DurableWorkspaceDescriptor` + its schema | **NEW** — `OD-8` = option A (`c04f6a8d`), with a `kind` discriminator (`D-21`) |
| `WorkspaceDescriptor` + its schema | **Reuse unchanged and READ-ONLY for both units** — `OD-8` binds them unmodified |
| Host-bind mount idiom (fail-closed sentinel + `-p`) | **Reuse** — copied from `${SHIPIT_HOST_SECRET_DIR}` (`compose.qa.yaml:113-119`) |
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
   descriptor shape. `OD-8` is answered (option A): write a `DurableWorkspaceDescriptor`, which
   has no such fields and **must not grow them**. `D-20`, `D-21`.
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
    **Structurally enforced:** all thirteen files under
    `apps/server/lib/src/credentials/**` are READ-ONLY for both units, including
    `repository_snapshot_acquirer.dart`, so neither unit *can* fix it by accident (`M5`, `D-22`).
14. **Do not add an autonomous producer for `implementationReady`.** `OD-10`.
15. ~~**Do not implement A1's compose change before `OD-7` is answered.**~~ **SUPERSEDED** —
    `OD-7` question 1 is answered (`9bfe2d09`); the host bind is authorised. **The surviving
    form of this prohibition is item 16.**

16. **Do not ship a reclamation policy for the durable clone before `OD-7.2` and `OD-7.3` are
    answered.** They are still open. The mount is unblocked; **the bound on a product's clone
    lifetime and the identity of whoever deletes it are not.** Do not invent either — a bound
    invented silently is a policy invented silently, and an autonomous deleter is a new
    destructive capability. §6.3.6.
17. **Do not leave a credential on or beside the durable clone (M1).** A1's materialiser MUST
    materialise the private half per acquisition, pass it only through a per-invocation
    environment (`GIT_SSH_COMMAND`, pinned `PATH`, `GIT_TERMINAL_PROMPT=0`, `GIT_ASKPASS=''`),
    redirect `HOME` and set `GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM` to `/dev/null`, write the
    identity/`known_hosts`/wrapper as **siblings** of the clone, and leave **no `core.sshCommand`
    and no identity reference in the clone's git config**. Destroy the private half **first and
    unconditionally**. §6.4's six obligations; review row **R-9**.
18. **Do not treat `D-7`'s "a durable clone carries no credential" as inherited from the acquirer
    (M1).** It is true of `repository_snapshot_acquirer.dart` and **false as a statement about
    A1**, because §6.4 forbids A1 from reusing it. The property is obligation 17, not an
    inheritance. This item exists because revision 1's text asserted it as established fact about
    a materialiser that does not exist yet.
19. **Do not read A1's environment variable from A1's own lane files (M3).** The read belongs to
    **A2 under `C-1`**, in `apps/server/lib/server.dart`, because the product-agnosticism gate
    forbids `shipit`/`SHIPIT` in `lib/src/baseline/**` and because `C-1` gives A2 exclusive
    ownership of that file. `_triageWorkspaceRoot()` (`server.dart:1281-1285`) is the model. A1
    receives a resolved path as a parameter.
20. **Do not modify `WorkspaceDescriptor` or `schemas/workspace_descriptor.schema.json` (D-20).**
    Decision `c04f6a8d` binds them READ-ONLY for **both** units. A new type + schema is the
    answer that was chosen.
21. **Do not let the two descriptor shapes be read interchangeably (D-21).** One column holds
    both. A reader MUST discriminate on the `kind` discriminator, and a record of the wrong kind
    is a **fail-closed error, never a fallback**. Review row **R-10**.
22. **Do not add a null branch to the artifact-resolution chain.** `worker_reconciler`,
    `local_worker`, `onboarding_worker` and `engineering_review_gate` stay **behaviourally
    byte-identical**; `OD-8` was chosen precisely so that they would. §6.2.1.
23. **Do not ship A2 with the UI mislabel.** `plain_language.dart` and `transition_copy.dart` are
    granted; an item at `implementation_ready` rendering as *"awaiting review"* is the false
    statement this whole brief exists to prevent. Review row **R-6**.

---

## 16. Provenance and self-check

| Item | Value |
|---|---|
| Worktree | `/Users/alkebut/air/.aef-lanes/impl-lane-design-rev2` (branch created at `84be979`; revision 1 committed at `8ad9985`; revision 2 at `381b552` then `9bd8f6d`) |
| Branch | `design/implementation-lane-rev2` |
| Base SHA | `84be9794f83ee258664842cd2c9f73f562b0d5f7` — **unchanged by revision 3 or revision 2**; the base did not move and both amend revision 1 on top of it |
| Files in this revision | `docs/design/implementation-lane/design-brief.md`, `docs/design/implementation-lane/design-revision-metadata.yaml` |
| Files modified outside `docs/design/implementation-lane/**` | **0** |
| **Unit `OWNED_PATHS` changed by this revision** | **none.** §8.1's two ownership columns are byte-identical to revision 2's; only the descriptive `Revision 2` column and the prose around it were rewritten. |
| Production code written | **none** |
| Migration written | **none** |
| Docker / Compose commands issued | **0** — including `ps`, `logs` and `info`; compose files were read **as text**, per `AGENTS.md` "Shared Docker state" |
| Database connections | **0**; `psql` **0** |
| `git stash` / amend / rebase / force-push / merge / push | **none** |
| Path ownership taken by this lane | `docs/design/implementation-lane/**` only |
| **Path ownership SELF-GRANTED to A1 or A2** | **none.** The paths §8.6 escalates are *recorded and escalated*, not taken; §8.1 records each of them as a `FLIP` row whose grant is pending. |
| Self-approval | **none.** This revision has not been reviewed by its author. |

**Verified at this base and relied on above:** `cc9317c`, `f164d40`, `1f39a05` and `5cb2817` are
all ancestors of `84be979`
(`git merge-base --is-ancestor` returned true for each).

---

## 17. What revision 2 re-verified rather than accepted

The review found **no blockers and no highs**, and revision 2 takes that seriously rather than
treating it as permission to stop checking. Each of these was re-derived from source at
`84be979` **before** the corresponding text was carried forward. A correction pass that only
*amends* is how a regression ships wearing a revision number.

| Claim re-confirmed | How it was re-verified | Holds? |
|---|---|---|
| **C-1** — the stale brief's core step was genuinely unexecutable | `currentBaselineRevision` is `final int` at `onboarding_record.dart:74`, documented at `:71-74` as *"A SEQUENCE COUNTER, not a git revision"*. `git rev-parse --verify <int>^{commit}` fails closed every time | ✅ |
| **C-8(a)** — only TWO rework pairs need `escalationTargetFor` lockstep | `escalationTargetFor` returns `null` unless the choice is `reject`/`rework` (`human_decision_routing.dart:131-138`); the lockstep arms are `(engineeringReview, rework)` `:141-142` and `(humanQaApproval, reject)` `:143-144`. **Exactly two.** | ✅ |
| **C-8(b)** — the stale brief missed an edge *and its guard* | `implementationReady` appears **nowhere** in `work_item_transitions.dart`, and nowhere in `packages/` or `apps/` at all — the edge and the state are both genuinely absent at this base | ✅ |
| **C-10** — the product-agnosticism gate covers A1 | `kForbidden` at `product_agnosticism_test.dart:30`; `_laneSources` `:84-113`; `_laneDirectorySources` `:120-127`, cross-checked so a mismatch **fails** | ✅ |
| **C-11** — traceability holds | ~40 citations re-checked by grep/sed at this base, including `runnable_work.dart:142-144`, `entry_hop.dart:288-297`, `engineering_review_gate.dart:69-77`, `git_worktree_workspace_manager.dart:85-92`, `guard_conditions.dart:247`, `scheduler.dart:322` and `:1698-1702`, `workflow_state.dart:36-39`, `human_decision_routing.dart:55-80`, `plain_language.dart:110-135`, `transition_copy.dart:94`, `compose.qa.yaml:113-119` | ✅ |
| **Risk Level 3 justification** | §12.1's four grounds each re-read; the operator independently confirmed Level 3 against `DESIGN_GOVERNANCE.md:99` and **declined a downgrade** | ✅ |
| **Dispatchable-vs-gated honesty** | §12.3.1's table is derived **only** from §11's recorded decision status **and §8.6's recorded ungranted-path status** — the two sources §12.3.1 now names explicitly, so this row and that section state one rule | ✅ |
| **`OD-8` = option A is viable as stated** | All four named per-execution consumers confirmed to contain **no reference to `OnboardingRecord`**, so the byte-identical binding holds | ✅ |
| **`OD-7` is only partly answered** | The decision's own `title` and `binds` field scope it to location; its `binds` says *"A1's compose change is unblocked"* while revision 1 said `OD-7` blocks *"the compose change **and its reclamation path**"* | ✅ — gap found and recorded |
| **`compose.qa.yaml` has no top-level `name:`** | Confirmed by grep — so every project resolves to `docker`, which is why `-p` is a binding obligation (§6.3.2) and not a style preference | ✅ |

**The one thing that changed my conclusion rather than just my text:** `OD-8` = option A widens
A1's blast radius beyond what revision 1's conditional grant assumed (§8.6). That was not a
review finding — it emerged from folding in the operator's own answer, and it would have surfaced
as a compile error in an implementer's lane had this pass not traced it. It is recorded, and the
grant it needs is escalated rather than taken.
