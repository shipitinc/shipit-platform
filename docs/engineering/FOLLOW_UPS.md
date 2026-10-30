# Follow-up ledger — session `orchestrator-main`, 2026-10-16

Manager-owned record. Created under `aef-orchestrator` §2 "Workflow bookkeeping", then
**reconciled after the verdict-consumption work**. Every item was discovered by a lane or
measured directly against the live QA stack. `file:line` cites are given so a future lane does
not re-derive them.

Status legend: **BLOCKING** needs a human decision or a merge; **OPEN** is real and unfixed;
**DEFERRED** is deliberately not being done now; **RESOLVED** is closed with its evidence.

> **Reconciliation note.** F-01 and F-02 were the two walls between the platform and end-to-end
> execution. Both are now closed and moved to §4 with live evidence. Closing them surfaced six new
> items (§5) and reframed one class of problem as a missing mechanism (§6). Two defects found by
> the first live reviewer are deliberately **not** filed here — see §6 for why, and for the
> mechanism that is meant to prevent that class rather than patch one instance.

---

## 1. BLOCKING — needs a human decision

### F-03 Push is owed — 219 commits are local-only
**Status** BLOCKING · **Owner** human

`origin/main` is still `f58d6fb` (2026-10-09). Local `main` is `64e92a0`. The human
authorized merge, rebuild and QA deploy; **push was deliberately not taken.** A lost
machine loses all of it. Safe strategy: one ordinary fast-forward push of `main`
(`64e92a0` descends from `f58d6fb`; no force, no rebase).

**Before pushing**, F-17 must be resolved — five Human Decision objects are still untracked,
and two of them record decisions this work was implemented under.

### F-04 `CommitProduced` route — a design decision already on record
**Status** BLOCKING · **Owner** human · **ARCHITECTURE_DISCOVERY**

`completionRouteFor`'s `CommitProduced` arm names a route the scheduler can never take:
the `agent_completed → review_in_progress` write carries `agentResultValid()` and the
scheduler has no execution of its own to supply the producer's `AgentResult`.

`docs/engineering/learning/the-inflow-cannot-route-a-commit-so-review-is-the-only-path.md:115-118`
already records both options: *"Either the transition should carry the producer's
`AgentResult`, or the arm should be removed and the doc corrected — **that is a design
decision, not an edit**."*

**This is no longer theoretical.** The live transition history for that exact edge reads:

| outcome | count |
|---|---|
| accepted | 26 |
| **rejected** | **887** |

Measured 2026-10-16. The arm has now been rejected 887 times against 26 acceptances — a
97% failure rate that has been running silently for the life of the ledger. In the
post-deploy tick, 6 of 7 re-review writes were rejected and only the one carrying a real
verdict-bearing execution succeeded.

**Do not resolve it by injecting an `ExecutionStore` into `Scheduler`.** The coordinator
already owns and satisfies that edge (`execution_coordinator.dart:215-230`, `:280-300`)
with the real result; a second reader of `agent_event` is the exact split recorded in
`the-writer-and-the-reader-were-different-stores.md`.

### F-05 QA is missing 2 of 4 hand-maintained database invariants
**Status** BLOCKING · **Owner** human · **mutating schema change**

Observed in the boot log after the 2026-10-16 deploy:

    WARNING: The database does not match the target database:
     - Table "design_revision" is not like the target database:
     - Missing Index "design_revision_approved_unique_per_work_item".
     - Table "product_credential" is not like the target database:
     - Missing Index "product_credential_active_repository_unique".

`apps/server/tool/schema_bootstrap.sql` creates four objects (two indexes at `:87`/`:112`,
two triggers at `:156`/`:186`). Serverpod's latest `definition.sql` contains **zero**
`CREATE TRIGGER`, so these exist only in `schema_bootstrap.sql` — and **no compose path
ever runs it.** Only `make test-integration` (`Makefile:254`) and
`.github/workflows/integration.yaml:131` do. `applyRepairMigration: false` in the QA
composition.

Live consequence on QA: an APPROVED `design_revision` can be mutated, and a repository
can hold two active credentials.

**Apply with care.** This repository has already lost its QA database once to an agent
running an unscoped `down -v`. `schema_bootstrap.sql` is not uniformly `IF NOT EXISTS`
guarded. If applied, apply inside a transaction and verify before commit.

### F-21 Operator retry discards which lane failed — an un-convergeable loop
**Status** BLOCKING · **Owner** human (changes a documented deliberate choice)

Found live 2026-10-16 on `defect-DEF-1791685722309971` after an operator tapped "try again".

`retryFailedWorkItem` hardcodes the return target:

> "The item lands in `designNotRequired`, a triage entry state the scheduler already
> treats as runnable, so the ordinary tick does the rest on the ordinary path."
> — `apps/server/lib/src/endpoints/work_item_action_endpoints.dart:410`

So a retry of a failed **IMPLEMENTER** execution returns the item to **triage's** entry
state. Measured sequence on that item:

| when | transition | actor |
|---|---|---|
| 2026-10-14 14:51:21 | `agent_executing -> agent_failed` | IMPLEMENTER, `AcpTransportException: ACP request timed out` (303s, 2 tool calls) |
| 2026-10-16 11:22:13 | `agent_failed -> design_not_required` | **`operator-retry`**, "It didn't complete" |
| 2026-10-16 11:22:19 | `design_not_required -> agent_executing` | role dispatched: **`TRIAGE_DEFECT`** |
| 2026-10-16 11:22:25 | `agent_completed` (triage completed in 5.9s, valid JSON, 8352 tokens) | |
| 2026-10-16 11:22:26 | `agent_completed -> review_in_progress` | |
| 2026-10-16 11:22:26 | `review_in_progress -> waiting_for_human_decision` | `engineeringReviewMissingArtifact` |

**The review did not short-circuit.** Triage writes a report and never commits, so
`blockedArtifactMissing` had nothing to review and refused in ~1s, correctly. The gate
was telling the truth.

**The loop cannot converge:** retry -> triage -> no commit -> review refuses -> the only
options (`rework`, `reject`) both return to `designNotRequired` -> triage again. The
implementation lane is never re-entered.

Note the correct path exists and previously ran on this same item: 2026-10-14 11:41:52
recorded `agent_completed -> implementation_ready` ("the producer ... left no implementation
artifact"), and the implementer then ran and timed out. Only the operator
retry edge bypasses it.

**Fix direction:** resolve the retry target from the lane that actually failed (the last
`agent_execution.role` for the item, or `metadata['producerActorId']`), falling back to
`designNotRequired` when unknown. This changes where EVERY retried item resumes, which is
why it needs human authorisation rather than a correction lane.

### F-30 RETRACTED — the decision queue exists; my premise was wrong
**Status** RETRACTED 2026-10-16 · superseded by F-38

This entry claimed *"57 Human Decisions are pending and unowned… There is no queue, no ageing report
and no owner. An operator has no way to see 57 pending decisions except by querying Postgres."*

**Every clause of that is false.** The operator surface is the **Needs You** page,
`apps/control_plane/lib/features/needs_you/needs_you_page.dart`, routed at `/needs-you` with
`/needs-you/:decisionId` for the decision itself. Verified live against QA on 2026-10-16:

    Needs you — 7 WAITING — 7 decisions are waiting on you.
    ref dec-hn9zf6jxb9-jdpz6e · Engineering review · defect-DEF-1791686704991884 · waiting 11h 57m
    "Engineering review requires changes. Approve, reject, or request rework?"
    STATUS: Needs your approval · ASKED: yesterday at 21:46 · WHAT WE SUGGEST: CHANGES_REQUIRED
    [Reject] [Request changes] [See full details]

It renders **ageing** (`waiting 66h 30m`), the suggestion, the work-item reference, the original
reported defect text, and the resolve actions drawn from the decision's own options — plus a
"WHAT CARRIED ON" history of already-resolved decisions with who resolved them and when.

**The error was mine and the mechanism was simple: I queried Postgres instead of looking at the
product.** A raw `SELECT count(*)` gave me a number the product never shows, and I reported the
number as a missing capability. The operator was asked to approve building a queue that already
shipped. **Check the product before reporting a gap in it.**

### F-38 49 pending decisions reference work items that no longer exist
**Status** OPEN · discovered while correcting F-30 · **not blocking**

Splitting the 57 by whether their work item still exists:

| bucket | count |
|---|---|
| `item_gone` — the `work_item` row no longer exists | **49** |
| blocking an item at `waiting_for_human_decision` | **8** |

So F-30's alarming figure was **49 orphaned records plus 8 real ones.** The 8 are all rendered in
Needs You, correctly. The page showing **7** against 8 blocking items is one further discrepancy:
`defect-DEF-1791685024220546` is blocked by `dec-hn9zf6jdjm-t0xhgb`, while Needs You renders the
older `dec-hn7h7dagw5-l4o193` for that same defect — i.e. the page appears to surface *a* pending
decision per work item rather than *the* blocking one. **Worth a check; it is a display question, not
a flow blocker**, and resolving it by inspection of the query is cheap.

Neither orphaned nor mis-picked decisions stop the flow: `waiting_for_human_decision` is the
terminal state and an operator sees every decision that actually blocks. Filed for later, as asked.

### F-06 `home-machine-label` correction is unreviewed
`fix/home-machine-label-corrected` @ `a62d532` (correction `bfcd105` on reviewed
`75598ae`). Original review was **DO_NOT_MERGE**, HIGH-1: a `claimed` job already holds a
machine but still rendered `every machine is busy`. Correction adds a `claimed` arm
(`on a machine`), converts `description` to an exhaustive switch, and returns `null` for
an unknown state — a deliberate, code-documented deviation from the reviewer's
illustrative `'Waiting'`, because `description` renders *under* `stateLabel` on the same
card. Awaiting `focused-reviewer`. Live QA still shows the old label, which is correct
given it was never merged.

### F-07 `inflow-bound-scope` — two HIGHs from its own review
`fb1ab34`, merged as `ce2f2e3`. The change is correct and its `reason` fix is live
(verified: the post-deploy transition reads *"left an implementation artifact"*, where the
old code wrote *"left no implementation artifact"*). Two HIGHs remain:
- **HIGH-1** — the `reason` switch (`scheduler.dart:1666-1690`) has **zero** test
  coverage. Mutation: reverting only that switch leaves 393 scheduler + 9 server tests
  green while the false durable row returns. A test must read `readTransitionHistory`,
  not `completionInflow.reason`.
- **HIGH-2** — the stated justification ("the refusal is REPORTED to an operator",
  `implementation_inflow.dart:252-268`, `scheduler.dart:1598-1605`) is false:
  `SchedulerTickResult.completionInflow` has **no production reader** in any `lib/`. The
  same repo records this at `the-inflow-cannot-route-a-commit-so-review-is-the-only-path.md:119-122`.
  `LEARNING_POLICY.md` requires a `CONTRADICTION` be reconciled, not silently contradicted
  in code.
- MED-1 `scheduler.dart:1705-1715`: every commit item now reports *"the item moved while
  this lane was reading it"*, which is provably false. Pre-existing, but this change makes
  it the standing operator-facing string.
- MED-2 durable-row volume: base wrote 0 rows at/above the bound; now 1 `[rejected]` row
  per producer per counter, unbounded by the bound. Accurate rows, unremarked cost.
- LOW-2 six new assertions key on the literal `'re-work discriminator'`; rewording the
  message vacuates them.

### F-08 NUL byte makes a test file invisible to review and to grep
`apps/server/test/secret_provider_test.dart` — 1 raw `0x00` at offset 9570 (line 268,
the literal `'nul\x00byte'`), pre-existing at `e8cd0ce`, introduced by `da68b5f`.
Consequences: git treats the file as binary so its diff is unreviewable, and **ripgrep
skips it entirely** — `rg -n "secret"` returns 1 match, `rg -a -n "secret"` returns 34.
That blindness is why the original review of `d8e0b0d` missed a reference.
**Any sweep in this repository must use `rg -a`.** Same class was fixed in
`transition_row_malformed_guard_test.dart` at `994073d`.

### F-09 `20261006150645000` is not in `migration_registry.txt`
`apps/server/migrations/20261006150645000/` exists; the registry lists 24 entries for 25
directories. Pre-existing. No guard compares the two. Serverpod 3.4.13
`listVersions()` ignores the registry and enumerates directories, so this is latent
rather than live.

### F-10 `seed_overview_qa.sql` rows will be swept and double-counted
`apps/server/tool/seed_overview_qa.sql:206-211` seeds `worker-local-1` (busy) and
`worker-local-2` (idle) with `lastHeartbeat = NOW()`. No `LocalWorker` owns those ids, so
the new staleness sweep condemns them within `staleAfter` (120 s) of any server start.
Meanwhile the three real registrations make `machinesTotal` **5**, not the seeded 2.
**Any Overview screenshot or golden baseline derived from that seed is wrong within two
minutes of the server running.** Owner: whoever runs QA evidence collection.

### F-11 `stop()` writes `currentLoad: 1` on an `offline` row
From the review of `ecba50a` (MEDIUM-2). `stop()` → `writeRegistration(status: offline)`
→ `toRegistration` → `currentLoad: _leased ? 1 : 0`, which is not zeroed — while the
sweep's `_asOffline` **does** zero it, with the comment *"An offline worker holds
nothing."* Two paths to `offline` in one change, opposite invariants. Latent today (no
production caller of `stop()`); live the moment a shutdown hook is adopted.
Also MEDIUM-1: the "composition is PINNED" test can pass while a production worker is
omitted from `startWorkerRegistrationHeartbeat`, or binds a different store.

### F-12 Unguarded `stdout.writeln` on a per-read path
`postgres_workflow_store.dart:57-62`. If stdout is a broken pipe the throw escapes
`readTransitionHistory` and **reinstates the very 500 this change removes**. Not a new
class — `stderr.writeln` has the same hazard — but the repository already documents the
hazard and guards it at `implementation_readiness_probe.dart:253` and `:498-506`. Remedy:
wrap the sink in `try { … } on Object { }`.

### F-13 `operator_action_copy.dart` promises a free machine on UNKNOWN capacity
`:91` `acceptedOutcomeSentence` emits whenever `capacityFull == false`, which includes
`capacity == null || !capacity.resolved` — i.e. **capacity is unknown**, and it still says
*"as soon as a machine is free."* Same class as F-06, smaller surface. **Design-mandated
copy under AC-16 / §5.4** — route to design, do not let a correction lane silently
rewrite it.

### F-14 `research` has no `RESULT:` token
`subtask-report.md`'s normalization table has no entry for `TASK_TYPE: research` and no
research agent type is defined. Lane `RESEARCH-AGENT-COMPLETED-INFLOW` emitted
`RESEARCH_COMPLETE` rather than borrow another lane's token. The template must be
extended, or this recorded as a Manager-self research entry.

### F-17 Five Human Decision objects are untracked
**Status** OPEN · raised from F-17, which found three; the verdict-consumption work added two.

| object | state | why it matters |
|---|---|---|
| `3659984d…` | RESOLVED | already implemented |
| `c495e02f…` | RESOLVED | cited by id at `learning/a-gate-that-protects-a-reader-can-make-the-screen-blank.md:6`, so a **committed document points at a decision git does not contain** |
| `8f1ed5bf…` | RESOLVED | voided a real operator approval |
| `92d567e3…` | core lifecycle decision | removed `maxImplementationInflows`, role-aware artifacts, automatic verdict-absent routing, retry via triage — **the decisions this entire session's implementation was made under** |
| `efa675af…` | undetermined-route brake | stops automatic routing after 3 consecutive undetermined artifact probes |

`main` cannot be called fully governed until these are tracked. They must be added with
explicit paths, never `git add -A` (which would also stage ~34 unrelated untracked files).

---

## 3. DEFERRED — deliberately not being done now

### F-15 CI is red for 8 independent causes; none fixed by 219 commits
`.github/` is byte-identical to `origin/main`'s last pushed state. Causes: (1) `melos
bootstrap` crashes — `ci.yaml:15` installs Dart only and melos's cli_launcher re-execs via
`flutter`; (2) `infrastructure.yaml:9` declares the reserved secret name `GITHUB_TOKEN`
under `workflow_call`, so the file is rejected on every push; (3) `client-build`/
`server-build` use a build context of `../apps/control_plane` / `../apps/server` while
both Dockerfiles COPY repo-root-relative paths; (4) `worker-build` + `macos-workers`
reference `../tooling/workers`, which has never existed, and **0 self-hosted runners are
registered**; (5) `golden_render_environment_test.dart:394` asserts `FLUTTER_ROOT`'s last
path segment is the version — true under FVM, false under `subosito/flutter-action`;
(6) `tofu fmt -check` on 5 unformatted `.tf` files; (7) missing
`SERVERPOD_TEST_DATABASE_PASSWORD`; (8) no `production` GitHub environment exists.

**F-15(1) and F-15(5) are the mechanical cause of §6.** CI fails to bootstrap because Dart
is installed without Flutter, and a golden test asserts a Flutter path shape that only holds
under one installer. Both are capability-parity defects at the environment layer.

### F-16 Two human decisions can be closed on the evidence
- **HD-6** (`67ec3b62`, design approval vs the triage dedupe discriminator) is **not
  load-bearing**. Quantified: `SELECT count(*) FROM work_item_transition WHERE
  "toState"='design_approved'` returns **0 of 14** work items. `triageAttempt` is
  identical under either answer and the stand-down fires on the same four items.
- **HD-7** (`b1e4d3a0`) is recorded PENDING but was answered in code by commit
  `254dbec` (merged `eba5675`). The durable record contradicts the tree. Note that
  `254dbec` fixed the store for **future** executions only — the ten pre-existing items
  whose producers ran before it are exactly the ones F-01 referred to.

### F-18 `AGENTS.md` product policy is still four `TBD`s
`:58-63`. Consequences already paid: `melos run format` was red on `main` until `e8cd0ce`
because no gate was declared, and every path-ownership grant has been a one-off because
no map exists.

### F-19 Stale operator-facing text
- `Makefile:85-88` advertises `Server: http://localhost:8080`; `compose.qa.yaml:151`
  publishes **8180**.
- `docker/Dockerfile.client:1` claims "Pinned to the version in `.fvmrc`" but the file is
  `FROM nginx:alpine` (`:12`) and pins nothing.
- `Makefile` `test-env-test` passes `--exit-code-from test-runner` against
  `compose.test.yaml`, which has no such service; `e2e-test`'s runner image never copies
  the app, so `run-e2e-tests.sh:30` `cd`s into a nonexistent dir under `set -euo pipefail`.

### F-20 Onboarding is blocked on a human GitHub action
Install the generated public half as a write-enabled deploy key at
`github.com/shipitinc/shipit-platform` → Settings → Deploy keys, then set
`SHIPIT_HOST_KEY_FINGERPRINT` and `SHIPIT_OPERATOR_NAME`.

---

## 4. RESOLVED this session — closed with evidence

### F-01 Three defects could not reach a reviewer — RESOLVED
**Closed by** Human Decision `92d567e3…` (remove the `maxImplementationInflows` bound,
role-aware artifacts, automatic verdict-absent routing, retry via triage) plus
`efa675af…` (brake after 3 undetermined probes), implemented on
`integrate/combined-3` and deployed as `b8feffe`.

Both stated causes were real: the re-work bound was spent, and no `agent_execution` row
existed for producers that ran before `254dbec` wired `PostgresExecutionStore`. The
backfill was correctly rejected as manufactured evidence; the decision instead removed the
bound that made the missing producer fatal.

**Evidence** — the three named items moved, and the class did not recur:

    defect-DEF-1791684804452198  planned -> agent_completed -> implementation_ready
    defect-DEF-1791686085546076  same
    defect-DEF-1791686704991884  same

Two empty implementation attempts then failed immediately under the new role-aware artifact
rule, and two implementation commits were produced (`cdffdbda…`, `84844613…`).

### F-02 `review_in_progress` items were never re-driven — RESOLVED
**Closed by** `5ca2acb` (adds `redriveSettledReviews()` as a third door in
`runReviewLaneTick`) then `58e6179` (the marker collision and the wrong-execution lookup,
§5 below). Deployed as `64e92a0`.

Two distinct defects had to be fixed; the first fix shipped and **did not work**, which is
recorded in §5 so the failure is not repeated.

**Evidence**, one tick after deploying `64e92a0`:

    defect-DEF-1791684804452198   review_in_progress -> waiting_for_human_decision
      blocking: dec-hn9zf6j51m-8az5eh
    3 decisions minted at 21:46:14   (before the fix, the newest was 11:22)
    waiting_for_human_decision: 1 -> 8      review_in_progress: 1 -> 0

The first machine-readable verdict this system has ever produced reached a person, carrying
its findings intact. **Note the honesty limit:** the decision cites execution
`agx-wx-jb-hn9z8ndppr-a9wxl8`, a *fresh* review, not the orphaned 20:02 execution. The
orphan was never re-raised; the item was correctly re-reviewed instead. The fix is sound,
but the original verdict was not recovered.

### Confirmed working — do not "fix" these

- **`994073d` (merged `8382d2a`)** — a malformed `guardEvaluationsJson` now degrades to
  absent and is **reported**, instead of throwing a 500. Verified live: the three affected
  defects still read 200.
- **`ecba50a` (merged `184a9ec`)** — workers register durably. Verified live:
  `listWorkers` went `[]` → 3 rows, and the Overview now reads **"0 of 3 machines busy"**
  where it read "0 of 0".
- **`0786ce1` (merged `c8277f2`)** — a permanently failed review now raises a verdict-less
  decision instead of parking forever. Prevents recurrence; did not rescue F-02's two items
  at the time, which §5's re-drive now reaches.
- **`fb1ab34` (merged `ce2f2e3`)** — the completion inflow no longer refuses the review
  route, and the durable transition `reason` no longer lies.
- **`e386909`** — the engineering-review execution budget is **1 hour**, measured rather than
  chosen: a review burned the entire 3-hour budget (17:00:12 → 20:00:13, no terminal event,
  nothing produced) and the next returned in 2 minutes with a real verdict. Staleness bound
  and reclaim window are derived from the table (7200 s), no longer hard-coded prose.
- The scheduler tick is healthy: `[scheduler.tick.completed] {ran: true, dispatched: 0,
  failedSections: [], overlappedTicks: 0}` every 30 s. `dispatched: 0` was the correct
  answer to F-01, not a symptom of a broken tick.

---

## 5. New findings from the verdict-consumption work

These are the cost of closing F-02. Two of them (F-25, F-27) explain **why the first fix
passed every gate and did not work**, and are the reason §6 exists.

### F-22 Three correction commits have never been independently reviewed
`5ca2acb`, `e386909` and `58e6179` are on `main` and deployed, but **no `focused-reviewer`
has run against them.** `58e6179` in particular rewrites how the review gate resolves its
subject and introduces a negative-sequence marker namespace — a novel write into
`agent_event` that no reviewer has inspected.

This is a governance gap the session created: corrections were merged on lane-reported gates
because the user had authorized merge and deploy, and the review was deferred. It is
outstanding, not waived.

### F-24 `ExecutionCoordinator._nextSequence` re-allocates sequences after a restart
`ExecutionCoordinator._nextSequence` is an **in-process counter starting at 0**. A
coordinator restart re-allocates sequences 1, 2, 3… onto rows that already exist, which
violates `agent_event_execution_sequence_unique` the same way F-25 did. Latent today
because restarts have not collided with a live append, and pre-existing.

Same class as the race in F-26. Flagged by the correction lane, correctly out of its scope.
**This is a latent production data-integrity defect, not a test problem.**

### F-25 `InMemoryExecutionStore` enforces none of the `agent_event` constraints
`InMemoryExecutionStore.appendEvent` keys on `eventId` and enforces **no
`(executionId, sequence)` uniqueness**. `PostgresExecutionStore` does.

**Every `agent_event` constraint is therefore inexpressible in an in-memory fixture.** The
consumed-marker write in §4 shipped through a fully green suite because the test store
simply could not express the collision. Any test asserting on that table must use a store
that enforces its indexes.

### F-26 Client-side `max(prior) + 1` sequence allocation is racy
A "read fresh, then write `max+1`" fix for F-25 was measured and **rejected**: it stops the
collision but leaves two overlapping ticks able to read the same max. The shipped fix uses a
reserved negative sequence (`reviewGateConsumedSequence = -1`) that no other allocator can
produce, because every other allocator starts at 1 and rises.

The rejected approach is recorded in the gate's comment **specifically so a future editor
does not re-propose it as a cleaner solution.** F-24 is the same hazard in an unrepaired
location.

### F-27 The Dart test harness fails silently, so "green" may mean "truncated"
Three separate pre-existing harness defects, each reproduced byte-identically at unmodified
HEAD:

1. A single-shot `dart test` across all of `apps/server/test` **truncates silently at ~+250**
   with no verdict line. Reported passes are then partial.
2. A 13-file batch dies at ~+100, exit 1, **no verdict line**. Sub-batches of ≤7 files return
   real verdicts. A second, lower threshold than (1).
3. `test/onboarding_test.dart` is a `serverpod_test` harness: dies at `+0: loading` with
   **44 bytes** of output, exit 1, no message.

Consequence for this session: a Manager gate run reported `+0 -1: Some tests failed` on two
batches, and the merge was made **before** the signal was resolved. Re-running the identical
commands gave `+10` and `+45`, all passing — it was a transient load failure. The code was
fine; **the process was not.** A missing "All tests passed!" line must be treated as
inconclusive, never as green.

### F-29 Framework practice: constraint-enforcing fixtures are required for runtime claims
Raised by the correction lane, and adopted here by the Manager: **a lane claiming to fix a
runtime fault on a constraint-backed table must show a fixture that enforces that
constraint, and must demonstrate the test fails when the fix is reverted.** Without that, a
green suite is not evidence about Postgres.

The discipline worked when it was demanded. The lane reported that reverting to
`job.executionReference?.agentExecutionId` fails exactly two named tests and nothing else,
and that reverting the marker allocation fails exactly two others — including one whose
base-revision failure reason was **weaker** than claimed, which it disclosed rather than
dressed up.

### F-31 The integration suite is knowingly red
Base `184a9ec` failed 5 DB-backed integration tests; the combined tree fails 4. One is new
and recorded as a known gap rather than fixed:
`test/integration/execution_store_roundtrip_test.dart` asserts stale metadata. No
`make test-integration` run has been green since the base revision.

---

## 6. Capability parity — the mechanism, not the instance

The first live reviewer produced two findings that are deliberately **not** filed as tickets
above, because filing them would treat the symptom as the problem:

- a **major** correctness defect in `apps/control_plane` (a create-defect path emits
  `success: true` alongside an `errorMessage`, so a failure is reported as a success);
- a **major** validation defect: `which flutter` → *not found*. Only
  `/usr/lib/dart/bin/dart` is present, so `flutter analyze` and `flutter test` **could not
  be run** against the revision under review, and the reviewer's conclusion that the gates
  were clean was **unverified**.

### The validation finding invalidates claims this session has been making

Every validation line reported for `apps/control_plane` in this ledger's history — "control
plane gates green", "analyze clean" — **was never substantiated.** The claim was made
repeatedly and it was wrong each time. That is the finding worth acting on.

**Correction, 2026-10-16, after independent design work.** An earlier draft of this section
said *"Flutter is not installed in the QA image, so nothing in the Flutter app was compiled or
tested."* **That framing is wrong, and reading it literally would cause damage.** Verified
against the tree:

- **Flutter 3.44.7 was on the host the entire time**, at
  `/Users/alkebut/fvm/default/bin/flutter`. Nothing was missing.
- `docker/Dockerfile.client:12` is `FROM nginx:alpine` and COPYs **pre-built** web artifacts.
  The QA client container **does not need Flutter to run**, by design.
- `docker/Dockerfile.server:18` is `FROM dart:3.12` and `sed`-deletes `apps/control_plane`
  from the workspace `pubspec.yaml`. The QA server container is Dart-only **by design**.
- `docker/build-client.sh` runs `flutter build web` **on the host**, deliberately — its header
  records that downloading the web SDK from `storage.googleapis.com` is blocked by Cloudflare
  WARP and some corporate VPNs.

So **installing Flutter into the QA image would defeat a documented workaround and would not
fix anything.** The accurate statement: Flutter is required **on the host and in whatever
environment a validating lane runs**, the reviewing environment did not have it, and nothing
in the system noticed or objected.

The correction itself is the evidence for §6's premise. A defect I wrote into the ledger was
caught by a lane reading it carefully against the tree — which is the discipline §6 asks for
and did not have anywhere to live.

The create-defect defect remains real and was fixed (`dcaf538`); it belongs to a defect
workflow, not this ledger.

### The mechanism that is missing

**Nothing in this repository compares what a product component needs to run against what the
QA image provides.** So the gap between "what the code requires" and "what the environment
supplies" is discovered only by a live agent happening to try, failing, and reporting it in a
findings list nobody had asked for. F-15(1) and F-15(5) are the same defect in CI: Dart
without Flutter, and a golden test that asserts an `FLUTTER_ROOT` shape true under one
installer and false under another. Both have been failing since before this ledger existed.

The requirement is therefore not "install Flutter". It is:

1. **A declared capability set per product component** — the tools, runtimes and services a
   component needs in order to run and to be validated, expressed as data, derived from the
   codebase as it is built rather than remembered in prose.
2. **A check that the environment performing the work satisfies it**, failing closed and
   naming the missing capability. **The surface is the host and the lane runtime, NOT the QA
   containers** — see the correction above; the containers are correct as they are.
   `make qa-up` is a natural prerequisite, but it is the *weakest* place for the check: the
   incident happened at review time, not at stack start.
3. **The same set consumed by CI**, so F-15(1) cannot recur independently of QA.
4. **A lane gate that refuses to report a component's validation as clean when a capability
   it needs is absent** — instead of recording "could not be run" and continuing, which is
   what happened here.

Item 4 is the one that would have prevented the false claims in this ledger, and it is the
reason this is filed as a mechanism rather than as a ticket. Until it exists, any validation
result in this repository for a component whose toolchain is unverified should be read as
**unverified**, whatever the exit code said.
### Design brief — `design/capability-parity/`

Brief `BBA3F4B9-1CF1-462D-9B3B-5F56F04374D5`, awaiting independent `design-reviewer` (Gate D1).
Risk level 2; routed to **HUMAN_DECISION_REQUIRED**, deliberately not AUTO — softening an
UNKNOWN into a warning is how this defect started.

Four facts the brief established that constrain any implementation:

1. **The checker cannot be written in Dart.** The root `pubspec.yaml` workspace list includes
   `apps/control_plane`, so resolving the workspace **requires the Flutter SDK**. A tool whose
   job is detecting missing Flutter must not require Flutter. Hence POSIX `sh`, exactly as the
   image-ownership guard already shipping inside `docker/build-client.sh` argues.
2. **This repository already ships a declared-environment contract** with refuse-to-grade
   semantics — `apps/control_plane/test/tools/golden_render_environment.json` with
   `check_render_environment.dart`, exit 3, enforced at two points, no skip flag, authorised by
   HD `3e9dfb75-7bdf-4a8c-89dd-c76779a65371`. The mechanism **imports that contract whole**
   rather than widening or duplicating it. `.fvmrc`'s version is deliberately **not** the
   pixel pin.
3. **`.fvmrc` pins Flutter 3.44.0; the host has 3.44.7.** Brief recommends range-satisfies for
   build/validation with the pin as a non-fatal `preferredVersion`, drift reported every run,
   and the golden contract's 3.44.7 staying exact — but **escalates it as HD-2 rather than
   deciding it**, because it changes what a pin means repository-wide.
4. **Exit codes: 0 SATISFIED / 1 VIOLATED / 2 UNUSABLE / 3 UNKNOWN / 4 UNDECLARED.** Rule that
   matters most: **0 is never returned when nothing was probed.** Code 3 is what forbids the
   word "clean" — it is precisely the verdict the reviewing machine in this session should have
   produced. The brief also **refuses a `--force` / `--allow-missing` / `--skip` flag**, on the
   precedent of `check_render_environment.dart`: no argument may make a mismatch look like a
   match.

CI consumption (REQ-3) is deliberately **slice 3, not slice 1** — making CI depend on a contract
that does not exist yet would gate CI on a document still being written. Slice 1's accepted hole
is stated rather than hidden: a lane reviewing an *undeclared* component is not caught until
code 4 ships in slice 2 (risk R6).

---

## 7. Independent review outcomes

### `dcaf538` create-defect partial failure — APPROVE_WITH_NON_BLOCKING_FOLLOWUP
Reviewed independently (gates re-run: `flutter analyze` clean, `flutter test test/` **+501**,
format clean, Flutter 3.44.7). **No BLOCKING, no HIGH.**

The reviewer's own mutation table, not the implementer's word: routing partial failure back onto
`errorMessage` → **6 reds**; neutering each assert → **1 red** each; multi-error join → **2**; page
detail wiring → **2**; setting `success` on the failure path → **2**; spurious message on a clean
create → **4**. Widget assertions proven non-vacuous: the page has **zero** `TextFormField` and the
test pairs every `findsNothing` with a `findsOneWidget` for the same finder.

Three findings worth keeping:

- **The original reviewer's MAJOR #2 was factually wrong.** Bloc success-state tests existed at
  `create_defect_bloc_test.dart:258,313,348` — and `:350` **asserted `errorMessage` contains
  `'failure.png'`**. This was not a *missing* test; it was a test that **pinned the defect**. The
  correction replaced that assertion rather than adding beside it. **A green suite ratified the
  bug** — which is F-29's lesson arriving in a form nobody predicted.
- **"Unrepresentable" was false of the shipped artifact.** Asserts are stripped by
  `flutter build web --release` (`flutter_tools` gates `--enable-asserts` on `BuildMode.debug`), so
  in the released bundle the invariant rests on `CreateDefectBloc` having one success emitter.
  **Corrected in code at `2a732f6`** — the comment now states the reach and warns against deleting
  the page guard as a "simplification", since reverting it turns **zero** tests red precisely
  because the assert makes that state unconstructable.
- **The structural twin is confirmed latent**, not a blocker:
  `lib/features/reports/create_feature_request_state.dart:10-23` has the same shape with no
  asserts, and `create_feature_request_page.dart:102` has an error guard with **no `!state.success`
  at all** — strictly weaker. Its only success emit (`create_feature_request_bloc.dart:98-106`)
  never sets `errorMessage`, so no reachable path produces the contradiction. **Filed below.**

### `design/capability-parity/` — DESIGN_REVIEW_CHANGES_REQUIRED
**1 BLOCKING, 7 HIGH, 5 MEDIUM, 8 LOW.** Risk level 2 agreed. No human decision needed to
*correct* it; HD-1/HD-2/HD-3 correctly remain routed to Gate D4 and must not be answered inside a
correction lane.

The review confirmed the diagnosis, the chosen precedent, the fail-closed asymmetry, and **both
non-negotiables respected** — Flutter is nowhere proposed for the QA containers, and `make qa-up` is
correctly named the *weakest* gate.

**BLOCKING — exit code `3` means two opposite things.**
`design-brief.md:214` defines `3 = could not be measured`; the contract it imports defines
`exitRefusedToGrade = 3` = *refused because it **mismatched***, and `:129` sets
`"enforce": "exactly"`, so both contracts emit `3` in one report. The design's own rule at
`:222-223` says unknown and absent "must never collapse into the same log line" — **its own
numbering collapses them.** It reaches the lane because the mandated obligation is
`CAPABILITY_PRECHECK: <exit>`, a bare integer with no verdict and no surface.

### F-32 Capability-parity brief needs a correction pass
**Status** OPEN · blocks implementation of any slice
Corrections to BLOCKING 1, HIGH 1/2/5/6/8 and the LOWs are mechanical and independent. Per the
review, **do not start any implementation slice and do not edit the three lane `SKILL.md` files
until BLOCKING 1 and HIGH 5 settle** — an implementation lane acting on the current text would edit
the wrong files and record an ambiguous integer.

Two of the HIGHs are worth stating here because they are design-level, not typos:
- **H1 — the `--surface` split is lost at the reporting boundary.** The model is correct and the
  unit ("component") is right, but the recorded obligation carries one integer per component and no
  surface, so a loose surface can authorise "clean" while the strict golden surface was never
  evaluated. Verified on this host: `validation` is exit 0.
- **H5 — requirement 4 would be inert at runtime.** Slice 1 names only `.agents/skills/**`; the
  byte-identical `.opencode/skill/**` mirrors are what opencode actually loads, and `AGENTS.md:47-52`
  confirms no generator or drift test is instantiated here. Editing only the canonical paths would
  change nothing and fail nothing.

### F-33 `.fvmrc` 3.44.0 vs golden 3.44.7 — WITHDRAWN as a conflict; the divergence is deliberate
**Status** CLOSED-WRONG-PREMISE · corrected 2026-10-16

**This entry was wrong and is retracted.** It was written from the design review's H7 and filed without
reading the golden contract's `_authority` field. It claimed a "latent conflict" between
`pubspec.yaml:100` (resolves `.fvmrc` → 3.44.0) and `golden_render_environment.json:16` (3.44.7).

There is no conflict. The divergence is **deliberate, documented and governed by a resolved decision**:

    _authority: Human Decision 3e9dfb75-7bdf-4a8c-89dd-c76779a65371,
                RESOLVED / OPTION_C, 2026-10-08: 'Pin CI to the exact rendering environment'
    _runner_note: "That job-level pin deliberately differs from the repository-wide .fvmrc pin
                   (3.44.0) ... The two must not be conflated; the divergence is deliberate and is
                   policed by this precondition rather than by a comment."

`.fvmrc` governs every developer and every package. The golden contract's 3.44.7 is a **separate exact
render environment**. Running the goldens under 3.44.0 does not mis-grade — `check_golden_domination.dart`
exits `refusedToGrade` and refuses. **That refusal is the design working.**

**Near-miss recorded deliberately.** An operator was asked to choose which version was authoritative and
selected *"3.44.0 — re-render goldens to match"*, on this entry's framing. Executing it would have
overturned a resolved human decision, changed the exact rendering environment, and re-rendered every golden
baseline — for no gain. It was caught only because the operator's answer prompted a check of the contract
itself before execution. **A ledger entry written from a review's summary rather than from the artifact
nearly caused an irreversible change. Read the artifact.**

**The one real defect underneath it, now fixed.** `pubspec.yaml:92-93` claimed the FVM pin exists
"so a contributor's global default cannot change the golden pixels". It does not — the golden pixels are
governed by the render-environment contract, not by `.fvmrc`. The comment is corrected at `6d1a...` to say
what the pin actually governs and to warn against "fixing" the divergence.

**Consequence for capability parity:** the design brief's `range-satisfies` recommendation (HD-2) rested on
the premise that "nothing makes 3.44.0 special". That premise is false. Decided by
`b58d0e17-9c46-4f8a-a2d5-3e91b7c40a58`: **both surfaces pin exactly, and version drift is FATAL, not
warned.**

### F-34 Unfiled follow-ups from the `dcaf538` review
- The `create_feature_request_*` structural twin (F-32 section above) — same invariant and
  partial-failure pattern, currently additive since that bloc has no post-write step.
- **No learning artifact** for `dcaf538`. Two qualify under `LEARNING_POLICY.md` and are
  evidence-backed: the assert-stripping fact (PROJECT_FACT), and *"a green test asserted the
  defective state, so suite-green did not mean correct"* (QA_DISCOVERY).
- `create_defect_state.dart` `hasPartialFailure` has **no production caller** — dead public API.
- Page-level guard coverage: a test asserting an empty-string `createdDefectId` renders a message
  rather than the editable form.
- `.fvmrc` 3.44.0 against the 3.44.7 toolchain actually gating this repo (see F-33), plus
  `Dockerfile.client`'s stale "pinned to `.fvmrc`" comment from F-19.

---

## 8. Capability-parity corrections applied — `0033484`

`design/capability-parity/` corrected against `DESIGN_REVIEW_CHANGES_REQUIRED`
(1 BLOCKING, 7 HIGH, 5 MEDIUM, 8 LOW) plus three resolved human decisions. Awaiting
independent `design-reviewer`; **slice 1 implementation remains blocked until it clears.**

### Human decisions recorded
| id | ruling |
|---|---|
| HD-1 `6c1f8a42…` | A capability that cannot be verified is reported **UNVERIFIED**; the lane **may proceed** but **may never emit `APPROVE_FOR_MERGE`**. Hard-stop rejected — it converts the stall into a deadlock. |
| HD-2 `b58d0e17…` | **Both surfaces pin EXACTLY.** `validation` at `.fvmrc` 3.44.0, `render` at the golden contract 3.44.7. **Version drift is FATAL, not warned.** Supersedes the brief's own `range-satisfies` recommendation. |
| HD-3 `e07c4a93…` | Exit `UNDECLARED` is **fatal in CI from day 1 of slice 2**. No advisory phase. |

### DEVIATION — applied by the Manager, not a lane
Three consecutive dispatches of a correction subagent failed with transport-level **connection
resets**, across two different agent types (`design-agent`, `general`). The corrections were
therefore applied directly. They are **design documentation, not production source**, and the result
is routed to independent review before anything is implemented. Recorded rather than smoothed over,
because "the lane did it" and "the orchestrator did it" are different provenance claims.

### The three corrections that change behaviour
- **Exit codes renumbered.** `UNKNOWN=4`, `UNDECLARED=5`; the imported contract's
  `exitRefusedToGrade=3` is left intact and `3` is held vacant, so a combined report cannot
  collapse *"could not measure"* with *"measured and mismatched"* — the exact collision the design
  exists to prevent.
- **Requirement 4 was inert at runtime.** The lane obligation named only `.agents/skills/**`.
  `AGENTS.md:47-52` confirms no generator or drift test is instantiated in this product repo, so
  editing only the canonical path **changes nothing and fails nothing**. Both `.agents/skills/` and
  `.opencode/skill/` are now named per skill.
- **A circular design, closed.** The golden contract is enforced by **Dart**
  (`check_render_environment.dart`, reached at `ci.yaml:148-155` via `flutter pub get`), so
  evaluating it "exactly" required the very SDK the contract is about, while AC#4 requires the
  checker to run **with no Dart and no Flutter**. New §3.6: `sh` decides the machine axes;
  **`maxNoiseFloorRatio` is a property of the goldens** and is delegated, never re-implemented.

### F-35 The design brief's metadata did not parse, and no review caught it
**Status** OPEN · discovered while applying corrections

`design-brief-metadata.yaml` carried `implementation_feasibility: HIGH` immediately followed by an
indented `rationale:` mapping — invalid YAML. **The file did not load at all.**

It shipped from the design lane, survived the designer's own self-check (which claimed "both JSON
blocks parse; fences balanced"), and survived an independent review that spot-checked 14 `file:line`
citations. Both checked *structure* and neither checked *parseability* of the metadata itself.

Now fixed. **Recorded because the class is larger than this file**: a governance artifact that does
not load cannot be reviewed by a human or a tool, and every reviewer who reads it as text rather
than parsing it will report it as fine. Nothing in the design-review checklist exercises YAML
validity.

### Known-incomplete in `0033484`
**L3 is PARTIAL and left visible.** Q5 still infers "exit 0" from "probeable" — probeable is not
satisfied. HD-2 withdrew the recommendation that inference supported, so it no longer carries a
decision; removing it is cleanup rather than correction. Recorded in the metadata's
`not_fully_addressed` block rather than silently deleted, so a reviewer can check the judgement.


---

## 9. Decision records that do not parse — F-36

**Status** OPEN · **BLOCKING for HD-2's authority** · discovered 2026-10-16

While repairing the capability-parity metadata, the same check was run across the whole decision
corpus. **Four Human Decision objects are syntactically invalid YAML and load in no tool.** A
decision record that cannot be loaded cannot govern anything, and `aef-human-decision` reads these
files.

| object | fault | class |
|---|---|---|
| `3e9dfb75-7bdf-4a8c-89dd-c76779a65371` | under-indented continuation lines inside a folded block (`:88-90`), plus a further `mapping values` fault at `:110` | **multiple, layered** |
| `f691aeb5-caa9-4019-942f-5fb9a5e6cdd1` | under-indented continuation inside a folded block (`:134`) | mechanical |
| `30c00e6e-4168-44e0-8d1e-34d7de7e4c46` | a `## SUPERSEDED` heading and prose **appended after the YAML document ends** (`:204-208`) | structural |
| `6d2bfffe-1631-498a-b053-4edaf8bd3048` | same shape — prose appended after the document (`:189-192`) | structural |

### Why this is blocking, not cosmetic
**`3e9dfb75` is the authority HD-2 cites.** It is Human Decision `3e9dfb75`, RESOLVED / OPTION_C,
*"Pin CI to the exact rendering environment"* — the decision that makes the FVM/golden divergence
deliberate, the finding that stopped the near-miss in which an operator would have re-rendered every
golden baseline. **HD-2 rests on a record that does not load.**

### Two faults were repaired; two were not, deliberately
Two objects this session authored were invalid and are now fixed: `e07c4a93` (HD-3) had a
**1-space indent** inside a folded block, and `efa675af` (the undetermined-route brake) had an
**unquoted scalar containing `: `** (`HUMAN_DECISION_REQUIRED: YES`). Both were my typos, both are
committed fixed.

The other two were **deliberately left alone.** `f691aeb5` and `3e9dfb75` are human records; I began
repairing `3e9dfb75` and found fault after fault, moving the parse error `:88 → :89 → :110`. **That
is line-by-line guessing at a human decision record, and it stopped.** The partial edits were
reverted rather than committed, because a half-repaired human record is worse than an honestly
broken one: the first looks authoritative.

`30c00e6e` and `6d2bfffe` need a **shape** decision, not a typo fix. Their supersession prose is
real governance content appended after the document. Repairing them means choosing where a
supersession belongs in the schema — `status: SUPERSEDED` plus a `superseded_by:` field, or keeping
the prose as comments. **That is a human call on record shape**, and it should be made once for the
corpus rather than per file.

### The check that would have caught this
```sh
ruby -ryaml -e 'Dir.glob(".decisions/*.yaml").sort.each{|f| begin; YAML.parse_file(f);
  rescue Psych::SyntaxError; puts "BROKEN: #{f}"; end}'
```
Note `YAML.safe_load` alone is **not** a validity check here: 34 of 55 objects parse fine but are
refused by `safe_load` because unquoted dates become `Time` objects. Use a parse-level check, or
pass `permitted_classes: [Time, Date]`.

**Nothing in the design-review or human-decision checklist exercises whether these files load.** That
is the same gap as F-35, one directory over.

### F-37 `.decisions/atures.yaml` has a mangled id
**Status** OPEN · **pre-existing** · from `93965ec`

The file's own `decision_id` is the literal string **`atures`**, and its filename is truncated to
match. It is a real, substantive decision — *"HD-1(b): for features, what should happen when the
product is not governed? The designer flagged plainly that parking is a worse visible outcome than
today's draft."* — recorded under an id that is the tail of a longer word, so **it cannot be cited
by anyone** who does not already know it exists. Its `_authority` references by id will not resolve.
The true id is unrecoverable from the filename; it must come from the author or from `93965ec`'s
context.

---

## 10. The `planned` dead end — FIXED and verified at runtime (`863831a`, guard at `caa1272`)

**Status** RESOLVED

### Diagnosis
`planned` had **no automated path forward**. Two facts, both verified:

1. `planned` was in **no** `JobDefinition.entryStates` (`baseline_product`,
   `implement_feature`, `triage_defect` — enumerated directly). `RunnableWorkEvaluator` rejects a
   state outside `entryStates` **before** consulting the policy, so `EntryHopper.prepare()`
   (`scheduler.dart:922`) was **never reached** on such an item. The mechanism existed and was
   unreachable.
2. The hop itself was always legal: `work_item_transitions.dart:28` has declared
   `planned → designNotRequired` since the table was written, `EntryHopper` has existed since
   `a56d64a` precisely for declared intermediate hops, and
   `apps/server/lib/src/triage/work_entry.dart:594-604` already walks this edge **by hand** —
   independent evidence it was the intended route, not a lane's invention.

`planned → designRequired` requires `designContractExists()`; all three stranded items had
`designContractId` NULL and empty `artifactRefs`, so `designNotRequired` was their only legal edge.

### Why it survived five days — worth more than the fix
**The failure is silent.** With `planned` absent, a tick enqueues 0, dispatches 0 **and records 0
refusals** — an item no definition dispatches from is never *considered*, so it is never *refused*.
`ran: true, dispatched: 0, failedSections: []` is precisely what an inert lane looks like. The
scheduler was healthy the whole time and had nothing to say.

### Fix
Added `planned` to `triageDefectDefinition.entryStates` with the declared intermediate hop, following
the existing `reviewRejected → designNotRequired` precedent. **`workflow_engine`'s transition table is
unchanged** — nothing was declared that was not already legal.

### Runtime verification (deployed, `main = caa1272`)
    planned -> design_not_required   accepted x3
    design_not_required -> agent_executing   accepted x3
All three previously-stranded items moved, including one parked since 2026-10-12.

### Three guards fired, none loosened
- `entry_hop_drift_guard_test.dart` — `placeIn` has no walk to `planned`, so it **failed** on the
  addition; satisfied honestly rather than relaxed.
- Two exact-set pins in `retry_return_to_entry_state_test.dart` and
  `retry_return_edges_test.dart` — updated with the reason `planned` was added; their live property
  (exactly one retry-return target per lane) is unchanged and still asserted.
- **`triage_execution_test.dart:1934`** is the significant one: its reason read *"NO entryStates set
  was widened"* and explained that narrow entry sets make the triage/implementation dispatch
  collision **structurally unreachable**. Adding `planned` makes that sentence false. Satisfied at
  `caa1272` by recording the widening and showing the invariant is untouched — the collision requires
  two definitions to **overlap**, and `planned` is an entry state of no other lane, so the sets stay
  disjoint. **The guard's claim was changed; the guard was not dropped.**

### F-39 A guard that iterates live config cannot detect a MISSING element
**Status** OPEN · found by the implementation lane

`triage_entry_state_drift_guard_test.dart` **does not fail if an entry state is removed** — it
iterates the live set, so removal silently shrinks its loop and the guard gets weaker without any
signal. This is why non-vacuity needed a separate test: the mutation ("remove `planned`") turns
**10 tests red**, and none of them were that guard.

Generalisable: *a guard that reads the thing it guards only proves the thing is well-formed, never
that it is complete.* Every config-pinning guard in this repository should be asked which direction
its failure runs.

### F-40 Conditional routing is not expressible — an item with a design contract skips design
**Status** OPEN · **architecture decision** · deliberately not implemented

`planned → designNotRequired` is **unguarded**, so now that `planned` is dispatchable, a `planned`
item that **does** carry a design contract is routed to triage rather than to design. The minimal
restoration was authorised on the basis that all three stranded items have no contract, and that
holds — but the edge case is real.

Closing it needs the probe target chosen from the item's evidence, and
`entryProbeTargets` is a `Map<WorkItemState, WorkItemState>` — **static by construction**, so the
choice has nowhere to live. Three options, none taken:
(a) widen `JobDefinition` to `Map<WorkItemState, WorkItemState Function(WorkItem)>`;
(b) a second declaration kind for evidence-dependent hops;
(c) a guard on the `planned` edges.

All three change a type or the engine's table. **This is an architecture decision, not an
implementation one**, and it is not blocking: it bites only an item whose producer creates the
contract *after* planning completes.

### F-41 The next wall: `agent_executing → agent_completed` requires a QA contract
**Status** OPEN · pre-existing · exposed by F-39's fix, not caused by it

All three items now dispatch and run, and **all three completions were rejected**:

    agent_executing -> agent_completed   rejected x3

`work_item_transitions.dart:120-124` guards that edge with `qaContractExists()`, which is
`context['qaContractId'] != null` (`guard_conditions.dart:247`). **All three items have
`qaContractId` NULL.** So triage runs, produces a result, and the result cannot be recorded.

Pre-existing and strictly downstream — these items were stuck *earlier* (at `planned`) until this
session. The fix moved them one layer forward and exposed the next one. **Not a regression**, and the
layer beneath is now reachable, which it was not before.

### The loop bound — the implementation lane corrected the Manager
I asked it to confirm `planned` is unreachable from `designNotRequired`. **That is false and its test
caught the claim.** A real path exists: `designNotRequired → … → waitingForHumanDecision →
planning → planned`. The correct bound is that the single edge back carries
`blocking_human_decision_resolved` **and** `decision_actor_is_human`, so **no unattended actor can
take it**. Verified by 25 ticks producing exactly 3 hops and 3 dispatches. **The bound holds for a
better reason than the one I asked for.**

---

## 11. QA contract provisioning on every entry path (`8b38a95`) — and what still blocks

The operator chose the **per-product route**: make `ProductManifest.contracts.qaContract`
reachable, and provision from it. The guard `qaContractExists()` is **unchanged** — the lane proved
`git diff` against `guard_conditions.dart` and `work_item_transitions.dart` is **0 lines**.

### What was blocking, established rather than assumed
- The only QA contract builder in the repo was `buildAdvisoryTriageQAContract` — triage-specific
  gates and `requiredRole: triageDefect`. Stamping it on a feature item would declare
  `defect_evidence_reference` gates against an item with no defect.
- `ProductManifest.contracts.qaContract` already existed as a type, but its single production site
  wrote it **empty** (`product_registry_endpoints.dart:502`, `gates: const []`) and **`saveProduct`
  never persisted it** — the spec was discarded on write and had no read path. The template mechanism
  was inert platform-wide, not merely unconfigured for two products.
- Reusing the triage contract id would have been actively unsafe: `triageQAContractIdForDefect` is
  defect-scoped and `saveQAContract` is `ON CONFLICT DO UPDATE`, so lane E would have **overwritten
  the triage parent's contract row and repointed its `metadata.workItemId`**. New ids are
  work-item-scoped, and a test asserts lane E cannot touch a triage contract.

### F-42 The three stranded items will not complete unattended — a human must move them
**Status** OPEN · **needs an operator action**

`agentExecuting` has exactly **two** outgoing edges (`work_item_transitions.dart:120,125`):
`agentCompleted` (the refused write) and `agentFailed`. **There is no
`agentExecuting → designNotRequired`**, so `operatorRetry` is refused and nothing replays a refused
completion. Stated in-repo at `triage_defect.dart:85-87`.

Recovery is a **human operator transition** `agentExecuting → agentFailed → designNotRequired`
*after* the contracts exist. The code change makes that possible; it does not perform it. A
`work_item_transition` row with `outcome='refused'` and reason `qa_contract_exists` on these three is
**correct behaviour**, not a regression — the guard doing its job.

### F-43 Feature intake has no replay hook, so one item cannot be backfilled
**Status** OPEN · asymmetry, reported not papered over

The two `design-remediation-DEF-*` items **can** be backfilled on replay — lane E's `ensurePersisted`
reads the row and `_attachQAContract` CAS-writes the id, with a test proving it.
`WI-feature-1791823723502264` **cannot**: `createFeatureWorkItem` always mints a fresh
`WI-feature-${now.microsecondsSinceEpoch}` (`control_plane_service.dart:830`) and never re-reads an
existing row. Reaching it needs either an operator transition with the id supplied directly or a
replay hook that does not exist. **A different change, deliberately not bundled.**

### F-44 An undeclared product now creates items that cannot complete — by decision
**Status** OPEN · **RESOLVED by decision `c4d70b18…`**, consequence recorded

The operator chose **create-and-record-the-reason** over refusing creation, extending `58bad3d1`'s
rule that a platform-lifecycle condition is not a reason to reject a request about it. Three named
refusals are recorded, never a null: `notDeclared`, `declaresNoGates`, `provisionerUnavailable`.

**The consequence is deliberate and should not be forgotten:** a spec-less product's work items are
created and remain **un-completable**, because the guard still requires a QA contract. The difference
is that the reason is now **on the row** (`qaContractNotProvisioned`,
`productQAContractSpecUnavailable`) instead of only in a guard error — the condition is visible.

### F-45 The blocker was visible as a red test at HEAD, before this session's fix
**Status** OPEN · reusable

`apps/server/lib/src/triage/work_entry_test.dart` — *"the parked feature is invisible to the
category-blind scheduler"* — **fails at `09f949d`** with `Expected: noAction / Actual: runnable`.
Proven executably in a throwaway detached worktree, which was removed afterwards.

A lane had already written a test pinning the behaviour this work restored, and it was red on
`main`. **Nothing runs that suite in CI** (F-15), so a red test naming the exact blocker sat on
`main` unnoticed while the blocker was being diagnosed from live behaviour by hand.

### F-46 A repo-wide name gate trips on any new method called `provision`
**Status** OPEN · WORKFLOW_IMPROVEMENT

`test/durable_workspace_provision_trigger_test.dart` holds a repo-wide, call-shaped gate refusing
`.provision(` on any receiver but `trigger` — it protects the destructive
`DurableWorkspaceRuntime.provision`. The new API had to be renamed
`ProductQAContractProvisioner.provisionForWorkItem` to satisfy it. The lane followed the gate's own
prescribed remedy rather than weakening it, which was correct.

Recorded because **any new method named `provision` in `apps/server/lib/**` will trip this gate**,
and the failure message's advice — "if this receiver is some unrelated API, rename it" — is right
more often than a reviewer will assume.

---

## 12. REGRESSION — the `planned` fix made features dispatch onto the defect triage lane

**Status** OPEN · **introduced by this session at `863831a`** · verified by bisect

`apps/server/lib/src/triage/work_entry_test.dart` — *"the parked feature is invisible to the
category-blind scheduler, while a defect is not"*:

    792855d (before the planned fix)   →  +1: All tests passed!
    HEAD (19fc529)                    →  Expected: noAction   Actual: runnable

**This session's `planned` restoration caused it.** Adding `planned` to
`triageDefectDefinition.entryStates` made `RunnableWorkEvaluator` treat *any* `planned` item as
runnable, **including a feature** — so a feature now acquires a `triage_defect` job. That is exactly
the failure `work_entry.dart:389-391` exists to prevent, and the test names it:

> *"Routing a feature into lane A produces a queued -> dispatched -> succeeded job whose TriageResult
> is then discarded at readDefect: a healthy-looking job and no work done."*

### Why the fix had this shape, and why it was not caught at the time
`entryProbeTargets` is a `Map<WorkItemState, WorkItemState>` — keyed by **state only**. There is no
place in that map to say "take this hop for a defect, not for a feature". The restoration made
`planned` dispatchable on the triage lane wholesale, which is correct for the three stranded items
(all `category: feature` per the DB, but two named `design-remediation-*` and one `WI-feature-*`,
all created by the **defect-triage** producer path) and wrong for a feature created by feature
intake.

**The implementation lane's own gates did not cover it.** Its non-vacuity was measured against the
stranded items and against two exact-set pins in `packages/scheduler`. The test that *did* cover it
lives in `apps/server/lib/src/triage/`, which was `PROHIBITED_PATHS` for that lane — so the lane
could not have run it, and the Manager's own post-merge verification did not run it either. **A
prohibited-path boundary hid a regression from the lane that could have caught it.**

### What this says about the previous entry
**F-45 was recorded inaccurately and is corrected here.** It said the red test was "the blocker this
work restored" and implied `8b38a95` addressed it. It did not: `8b38a95` touched no file that test
reads, and the test is still red. The correct statement is worse and simpler — **the test was written
before this session, was green, and this session made it red.**

### The repair
The `planned` hop must be **category-aware**: taken for a defect-category item, refused for a
feature. `EntryHopper` already receives the whole item (`entry_hop.dart:181` reads
`_definition.entryProbeTargets[current.state]` inside a method holding `current`), so the item's
category **is in scope at the call site** — but the map cannot express the condition. This is the
same expressiveness gap recorded as **F-40**, reached from a second direction and now with a live
regression behind it.

---

## 13. HD-1 resolved — and F-47, the gate evaluator that does not exist

**Status** OPEN · **blocking every QA contract** · verified by the Manager

HD-1 is answered: **allow completion, insert a design-review gate before
`implementationReady` dispatches an IMPLEMENTER** (`.decisions/2a8f5c31…`). The shape is
delegated to the design lane; the invariant is not — no IMPLEMENTER dispatch for items originating on
feature intake or design remediation without a satisfied design review.

### F-47 No QA gate in this repository is evaluated by any production code
**Status** OPEN · **BLOCKING** · verified twice, independently

`allRequiredGatesPassed()` reads `context['gateResults']`:

    guard_conditions.dart:267   final gateResults = context?['gateResults'] as List<QAGateResult>?;
    guard_conditions.dart:268-270  if (gateResults == null) return GuardResult.fail(name, ...)

**`grep -rn "gateResults:"` across `packages` and `apps` returns ZERO producers** — not in
production, not in a test, not in a fixture. Nothing ever populates it.

Consequences, stated plainly:

1. `allRequiredGatesPassed()` can only ever **fail**. It guards
   `qaInProgress → qaPassed` (`work_item_transitions.dart:661`), so **QA has never passed an item.**
2. The existing triage contract's three gates — `triage-classification-admitted`,
   `triage-evidence-grounded`, `triage-clarification-routing` — have **never been evaluated**. They
   are declarations, not enforcement.
3. Therefore **authoring two more contracts would be a second and third green lie**: rows that
   exist, gate ids that read like guarantees, and no code that checks any of them. This is the same
   class as `create_defect_bloc_test.dart:350`, which asserted the defective state — and as the
   capability-parity disposition block that claimed 21 corrections and delivered ~8.

**This is why the design lane was right to block, and why a `qa-architect` lane cannot honestly
deliver contracts alone.** A contract without an evaluator is a comment with a schema.

The gate evaluator is therefore **in scope for the design work**, not a follow-up. Until it exists,
any QA contract in this repository — triage's included — should be read as **declaration only**.

### F-48 `featureIntakeParked` — the regression is fixed (`ddfbfff`)
**Status** RESOLVED

The `planned`/`planned` structural conflict (§12) is resolved by separating the two cases at the
state level. A feature parks at `featureIntakeParked`; `planned` stays in
`triageDefectDefinition.entryStates`, so the two defect-origin items remain dispatchable.

**The proof that the guarantee survived, not the implementation:** `work_entry_test.dart:877` and
`:881` passed **unmodified**. Three other assertions (`:309`, `:350`, `:929`) moved
`planned → featureIntakeParked`; those assert *where* the park is, while `:877`/`:881` assert *why*.

No edge returns `featureIntakeParked → planned`, because `planning → planned` is asserted to be the
only edge into `planned` and adding one re-opens the cycle its anti-cycle test forbids. Recovery is
via `featureIntakeParked → waitingForHumanDecision`, which `evaluate()` returns as **blocked**, not
runnable, so it grants no dispatch.

Non-vacuity, measured: adding `featureIntakeParked` to any `entryStates` turns
`transition_consistency_test` red (`+4 -1`) with the new assertion's own message. No migration:
`work_item.state` is unconstrained `text` with no CHECK constraint and no PG enum type.

**Two briefing errors of mine, recorded because they cost a lane round-trip:** I told the lane
`WorkItemState` lives in `packages/workflow_engine` (it is in `packages/platform_contracts`), and I
demanded "do not edit the test" when three assertions provably had to move. Both were scope errors
of mine, not judgement calls the lane could have resolved. **A correction lane cannot grant itself
authority, so a wrong `PROHIBITED_PATHS` or an unsatisfiable acceptance criterion costs a full
cycle.**

---

## 14. QA contracts Design Revision (`ad4fada`) — and two more real defects it found

HD-1 resolved the Level 3 question; the revision delivers the evaluator spec, the design-review gate,
and the missing-artifact backlog. It **declined to author the two contracts**, with evidence: at
`e3634a0` a feature-intake item produces **no agent execution at all** (F-48 gave the park its own
state), and design remediation's only run has its result abandoned by `triage_processor.dart:124-132`.
`config.requiredFields` would be justified by nothing. That is the third consecutive accurate block on
the same evidence.

### F-49 `allRequiredGatesPassed` passes VACUOUSLY when `qaContract` is absent — verified
**Status** OPEN · **BLOCKING** · Manager-verified

The guard reads **two** context keys, not one (`guard_conditions.dart:272-280`):

```dart
final requiredGates = gateResults.where(
  (g) => context?['qaContract']?.gates.any((gc) => gc.gateId == g.gateId && gc.required) ?? false,
);
final allSatisfied = requiredGates.every(_isGateSatisfied);   // .every() on EMPTY is TRUE
return allSatisfied ? GuardResult.pass(name) : GuardResult.fail(...);
```

Populate `gateResults` without also supplying `qaContract` and the filter yields an **empty** list, so
`.every()` is vacuously true and `qaInProgress → qaPassed` **passes with nothing judged**.

This is the specific shape of failure this session has hit repeatedly: a partially-wired mechanism
that **looks enforced and enforces nothing**. Anyone wiring the evaluator must supply both keys, and
the guard should arguably fail closed when either is absent. Note the current state is the *safe*
direction — no producer at all means `gateResults` is null and the guard fails — so this is a trap for
the **next** implementer, not a live hole today.

### F-50 `qaInProgress` is a live dead end on the MAIN implementation lane — unrecorded anywhere
**Status** OPEN · **BLOCKING end-to-end flow** · found by the design revision

`qaInProgress` is entered only from `reviewApproved`. From there:

- `qaPassed` (`:732`) needs `allRequiredGatesPassed()`, which **always fails** (F-47);
  *(citation corrected by `correct-DESIGN-REVIEW-3`; `:690` opened on `reviewApproved -> qaInProgress`)*;
- `qaFailed` needs a `qaExecutor` actor, and **no scheduler dispatches the design lane**;
- **no `JobDefinition` lists `qaInProgress` in `entryStates`**, so nothing can move it.

**Every work item that commits and passes engineering review is stranded there.** This is the main
implementation path — the one this whole session has been driving — and it was not in the ledger
before. It is why the last lane's verification stopped at `agent_completed`: the QA hop behind it has
never worked.

### F-51 The registered gate evaluators would fabricate a PASSING if wired
**Status** OPEN · **BLOCKING the evaluator slice**

The four registered evaluators are **not implemented**: `_validateEvidence` returns
`evidence.isNotEmpty` and all four collectors return **hardcoded empty findings**. Wiring them as
they stand would emit a PASSING with a full audit trail and nothing checked — the exact green lie this
ledger keeps recording.

**Hard ordering constraint, and it is why the evaluator cannot be a one-slice fix:** the collector
implementations must land and be proven before the guard is relied on. This is the same lesson as the
capability-parity disposition block that claimed 21 corrections and delivered ~8.

### F-52 The design-review gate needs a PRODUCER, not a model — the brief's premise was understated
**Status** OPEN · reduces the size of HD-1's gate substantially

The blocked brief assumed the design-review artifact would have to be invented. It exists:
`packages/design_governance` with `PostgresDesignGovernanceStore`, real migrations, and
`readApprovedDesignRevisionForWorkItem` (`design_revision_store.dart:17`). So HD-1's gate requires
**no new schema, no new `HumanDecisionType`, no new routing arm and no new state** — only something
that writes an approved `design_revision` row.

Consequence: the design lane and the implementation lane are **disconnected** —
`designApproved`'s only out-edge is `→ agentExecuting`, and `designApproved` is in
`triageDefectDefinition.entryStates`. Nothing produces an approved revision for a feature.

### Citations the design revision corrected in MY dispatch brief
Recorded because a spec that points at the wrong line sends a lane hunting:

- `qaInProgress → qaPassed` is `work_item_transitions.dart` **`:690`**, not `:657-662` (which is a
  comment about `reviewRejected`). My spec was wrong.
- `_extractDefectId` is at `triage_processor.dart:279-285`; my spec cited `:272-276`. Code as
  described.

The lane flagged both rather than complying silently. **That is the behaviour the correction-loop
brief asks for, and it is the reason the errors cost nothing but a paragraph.**

---

## 15. Design Revision 2 (`86e38b5`) — corrections applied, two new findings

Independent review returned `DESIGN_REVIEW_HUMAN_DECISION_REQUIRED` with `CORRECTION_REQUIRED: YES`
(1 BLOCKING, 4 HIGH, 4 MEDIUM, 2 LOW). **Only H4 went to the operator** — who routed it back to the
design lane plus independent review. Revision 2 addresses all 11 items.

### F-53 The composition-root comment contradicts the stand-down — recorded nowhere
**Status** OPEN · **BLOCKING a reader, not a machine**

`apps/server/lib/src/review/engineering_review_gate.dart:2210-2229` stands **down** for a no-commit
producer at `agentCompleted` on the stated premise that *"the implementation lane's completion inflow
routes it back into implementationReady **without a bound** — so this gate stands down rather than
asking a human a question whose options are only rework and reject."* At `:2860-2871` it logs
`engineering-review-missing-artifact-stands-down` and returns — **no decision, no park, no durable
reason.**

**`apps/server/lib/server.dart:539-543` still says the opposite**: that the drain turns
`blockedArtifactMissing` into a blocking human decision. The two are in direct contradiction, and the
comment is the one a future lane reads first. **This is what made B1 invisible to the design lane** —
the artifact it consulted was wrong.

### F-54 `work_item_transitions.dart` declares edges that **no caller takes** — two verified today
**Status** OPEN · **BLOCKING** · systemic

Two confirmed in this session's work:

1. `agentExecuting → agentCompleted` has no satisfying writer for items without a QA contract
   (F-41), and `agentExecuting → designNotRequired` **does not exist at all**, so `operatorRetry` is
   refused (F-42).
2. `reviewApproved → qaInProgress` — **nothing takes it.** `reviewApproved` is in no
   `JobDefinition.entryStates`, its only in-edge is the human one at `:425`, and no endpoint or drain
   transitions it. So `qaInProgress` (F-50) is **not merely a dead end — it is unreachable**, and the
   item stops one hop earlier, at `reviewApproved`.

**The pattern is the point.** A transition table is a declaration of what is *legal*; it says nothing
about what is *called*. Two of the walls this session has been chipping at were legal edges with no
caller, which is why "the guard should refuse and a human should be asked" kept failing to produce a
human.

**Suggested check, not implemented:** for each declared edge, is there a producer that can originate
it? Reading a guard exactly — as the QA revision's otherwise excellent citation pass did, ~45 ranges
all correct — **is not the same question** as whether anything calls the edge it sits on. That
distinction survived a careful citation pass and is worth stating.

### H4 — specified, not decided
Per the operator's routing, Revision 2 specifies the behaviour following from HD-1's text, states both
readings and **marks it as the one point an independent `design-reviewer` must judge.**
`human_decisions_required` stays `[]`; a separate `points_for_independent_review` block carries the
question, both readings, and the cost of each. **The operator's answer was not re-asked.**

### Two non-goals withdrawn — the consequence of B1, not a choice
Revision 1 claimed *"Not a new `WorkItemState`"* and *"Not a new edge to `waitingForHumanDecision`"*.
Both were premised on a refused guard leaving the item somewhere with usable exits — **false for these
origins**, per B1. The design now carries **one new state and three edges**, and slice 1 feasibility
is downgraded **HIGH → MEDIUM** because Revision 1's HIGH rested on the claim the review found false.

### Still open, stated not smoothed
- **R1 is UNMITIGATED.** The drift test naming the single writer of `workItemOrigin` /
  `approvedDesignRevisionId` is specified but a design artifact cannot make a mitigation executable.
- **The park's human surface is a deliberate gap.** It offers re-triage / re-plan / stop — **none is
  "do the design review"**, which is the very thing the item is parked waiting for. Fixing it needs a
  new `HumanDecisionType` plus a routing arm; `human_decision_routing.dart:151-162` records the two
  tables must move in lockstep or escalation accounting silently breaks.
- **Tests were not re-run** — no production code changed and no claim rests on a test.

---

## 16. F-55 — the park's human surface has no "do the design review" answer

**Status** OPEN · **named by decision `7f3e2a95…`, which said it must be solved FIRST**
· recorded 2026-10-17, referenced before it existed

Decision `7f3e2a95-6c81-4d70-b215-8e94a0c7d382.yaml` (Reading B) has this `consequence`:

> *"A human resolving a blocking decision on a feature-intake or design-remediation item CANNOT send
> it to implementation without a satisfied design review. The dead end this creates must be solved
> FIRST … This decision does not make the dead end acceptable; it makes it the next thing to build."*

That consequence named **this entry** as where it would be recorded. It did not exist: the file ended
at F-54, and the design lane — correctly barred from `docs/**` — then cited `FOLLOW_UPS F-55` as an
existing artifact in **five places**. **The dangling pointer originated in my own decision text.**

### The gap, precisely
Under Reading B a refused gate parks the item at `designReviewRequired` with a raised
`HumanDecision` (verified closed by review: `blockingReason` and `blockingHumanDecisionId` both set,
idempotent, raiser reachable via `stalled_work_item_gate.dart:195-227`). The operator is offered three
answers — **approve → `designNotRequired`, rework → `planning`, cancel → `cancelled`**
(`human_decision_routing.dart:121, 132-135`).

**None of them is "do the design review."** The item is parked waiting for a design review and the
decision that unblocks it offers no way to produce one. `"stop"` (cancel) is the only terminating
exit.

Closing it needs a **new `HumanDecisionType` plus a routing arm**, and
`human_decision_routing.dart:151-162` records why that is not a small change: *"a value here that
disagrees with `targetFor` does not error — it silently stops the escalation index advancing."* The two
tables must move in lockstep or escalation accounting breaks quietly. That is architecture, and
`AGENTS.md` reserves architecture to the human.

### The sequencing question this raises — RESERVED TO THE OPERATOR
The design lane routed this as **slice 1.5, after slice 1**. The independent review disagreed on
*authority* while agreeing on merits:

> *"Choosing to defer a Level 3 operator instruction on the grounds that the design lane judges the
> deferral net-positive is a consequential product/architecture decision, and the lane is not entitled
> to make it. **A flagged judgement is not a discharged obligation.**"*

The decision text says **FIRST**. The design says after. **That is an operator question, not a design
one, and it gates slice 1.**

### F-56 The ledger was cited before it existed — a process note
Recorded because the cause was mine, not a lane's. A decision file named a follow-up entry as the
place to record its consequence; the entry was then never written; and a later lane, barred from
`docs/**` and correctly following instructions, cited it as real in five places across three artifacts.
**No reviewer flagged it as suspicious — each took it as an existing artifact.** A named-but-unwritten
anchor propagates silently, because a citation that looks well-formed invites acceptance.

**Check:** when a decision names a ledger entry, that entry must exist before the decision is cited
downstream. As a fallible rule: *an artifact citing `FOLLOW_UPS F-NN` that no one in the session
wrote is a smell, not a fact.*


---

## 17. Design Revision 3 (`7caa1d8`) — sequencing reversed, and the lane's own errors

Four review rounds on one artifact. Round 3 returned **no blockers, no highs** and confirmed the
previous round's BLOCKING finding genuinely closed, re-derived at the line level rather than accepted.

### The reversal is applied and the merits argument is kept
Decision `b81f40c7-…` (`HUMAN_SURFACE_FIRST`) reversed the slice ordering. The design now reads:
**1 = human surface, 2 = the gate, 3 = evaluator, 4 = design lane, 5 = contracts**, with a crosswalk in
`design-review-gate.md §0.2`.

The prior pass's own merits argument — that shipping the gate first leaves items in the *silent*
position, which is worse than parking — is **preserved verbatim, not deleted and not restated as
agreement**, because the override was on **authority, not reasoning**.

**G17 asserts the invariant** rather than stating it: `designReviewRequired` has an in-edge **iff** the
park's decision offers an answer whose `routesTo(type, choice, designApproved)` is true, reading both
**parsed** routing tables. Fails on absence in both directions, **and fails today** — correctly.

### F-57 The repository's own comment points 28 lines off
**Status** OPEN · `packages/**` is PROHIBITED to design lanes — recorded, not corrected

`human_decision_routing.dart:154` cites `durable_workflow_engine.dart:979` for
`_isEscalationTransition`, which is at **`:1007`**. This is a comment **in the product source**,
misdirecting exactly the reader it is meant to help.

### F-58 A well-formed citation is what invites acceptance without opening
**Status** OPEN · **WORKFLOW_IMPROVEMENT** · three rounds of evidence

Three review rounds, each confirming ~60 citations — and each round finding errors the previous round
missed. This pass found one **in its own artifacts**: `implementation_inflow.dart:1543-1578` cited for
a load-bearing property, **1103 lines past EOF**.

The design lane proposes two mechanical discriminators, both of which would have caught this class:
1. **an end line inside the file** — `:1543-1578` is syntactically well-formed and passes any
   `file:line` regex;
2. **the cited range containing the quoted string.**

Worth stating plainly: the reviewer's careful re-derivation is a genuine strength of this process, and
it is **not** evidence about the citations it did not name.

### F-59 R13 — the ordering creates a window with an answer that cannot unblock
**Status** OPEN · created by decision `b81f40c7…` · **flagged by the lane, not argued**

For the slice-1 → slice-2 window, the park's decision offers a fourth answer that **changes the item's
state and still cannot unblock it** — the producer that writes the approved design revision arrives in
slice 4. The lane recorded this as R13 rather than re-arguing merits against a decision made on
authority, and invited a reviewer who thinks this is *itself* a dead end to make that finding.

**That is the same class as everything else in this ledger**: a state with a way out that does not
actually let anything out. Worth deciding deliberately rather than inheriting.

### Three errors this pass authored and caught itself
Recorded because the discipline is the point: **PASS3-5b** stated the lockstep rule flatly when it is
conditional on reject/rework — an implementer believing it would have started the escalation index
silently on a design approval. **PASS3-7** invented a path, `human_decision_type.dart`, which does not
exist (`HumanDecisionType` is at `platform_contracts/lib/src/enums/human_decision.dart:1-30`). Both
were recorded in §12.1 rather than quietly fixed. It also found the spec's own M-C citation was one
line short (`:563-572` → the throw is `:573-583`).

---

## 18. Round 4 (`0fc4a63`) — the fork resolved, and the decision's own enumeration was incomplete

### F-60 The authorised decision under-specified its own registration sites
**Status** OPEN · **found by the lane, not by the review**

`3e5a7c26` said the new type's arms must be registered, naming **two** sites. There are **three.**
`blockingHumanDecisionResolved` is a **strict whitelist** —
`allowed.contains((type: decision.decisionType, choice: decision.choice!))`
(`guard_conditions.dart:425-428`) — so a new type is admitted by **no** edge until it is added to
that edge's set. Both `(waitingForHumanDecision, designApproved)` (`:75-80`) and
`(waitingForHumanDecision, planning)` (`:641-650`) need it.

Without the third registration the decision **resolves, is saved as resolved, and the item does not
move** — §5.1.1b's unrecoverable position reached by a new route. The lane specified it rather than
stopping, on the grounds that omitting it would make slice 1 ship a stranding, and recorded it as a
gap in **the decision's enumeration**, not in the design. Correct record-keeping; the decision file
still reads as though two suffice.

### F-61 The `rework` arm INVERTS the pass-3 correction
**Status** OPEN · **BLOCKING slice 1**

Pass 3's G17b warned against adding an `escalationTargetFor` arm, because `approve` is protected by
the short-circuit at `human_decision_routing.dart:196-199`. **The new type has a `rework` arm — the
one choice that short-circuit does *not* protect.** Its inertness rests solely on `_ => null` at
`:214`. Completing the "lockstep" would make `routesToEscalation` true and **start escalation
accounting silently on a re-plan** — the exact failure `:159-162` warns about. G17b is extended, not
carried.

### F-62 An orphan-string checklist has a demonstrated blind spot
**Status** OPEN · **WORKFLOW_IMPROVEMENT** · five instances in one artifact

Five superseded-claim-surviving-as-live instances were found in this artifact. **A read sweep found
all five. A grep found none** — because a superseded claim is well-formed text, not an orphaned
string. Recorded by the lane as the generalisable lesson:

> *"`A grep finds an orphaned string, not a stale claim`"*

Compounding it: the dispatch's own `1.5`-orphan check was clean in both `.md` artifacts and **missed
the metadata register** — and a read sweep found a *third* stale claim in `design-revision.md §4.2`
(*"No new `HumanDecisionType`, no new routing-table arm, no new decision type"*) that had been carried
through **three passes unmarked**.

### The menu: four answers, restored
The lane merged *re-triage* into *put it back in the lane*, leaving **three** — and flagged it as
possibly the operator's to reverse, because a product-facing menu reduction is not what HD-1's
delegation covered. The operator chose a **fourth `HumanDecisionChoice`**
(`.decisions/5a90c1d3-…`), with a recorded scope warning: the enum is **shared with every other
decision type**, so the new value is visible wherever a decision is rendered and **must be scoped to
the park's type only**. If the enum cannot carry a per-type option set, that is a finding to escalate,
not a reason to show it everywhere.

**The invariant, recorded because it is the pattern, not the instance:** the operator's menu for a
parked item must remain four coherent answers. A design that cannot express them **escalates**, as
this one did — it did not merge two into one and report the reduction as resolved.

---

## 19. Pass 5 (`fd6b9ff`) — the scope question answered, and F-60's magnitude corrected

### The scope worry was unfounded, and the proof is four facts
`.decisions/5a90c1d3…`'s `scope_warning` required establishing whether a per-type option set is
expressible before adding a shared `HumanDecisionChoice`. **It is**, from four verified properties:

1. the offered set is a property of the **decision instance** — `HumanDecision.options`,
   `DecisionContext.availableOptions`;
2. the operator UI builds its menu **only** from that set (`decision_detail_bloc.dart:30-37`);
3. `HumanDecisionChoice.values` is enumerated **nowhere in `lib/`** — all nine sites are in `test/`;
4. a **per-type label layer already ships**: `decisionChoiceLabel(…, decisionType:)`.

So `re_triage` is scoped to the park **by construction, not by filtering** — the opposite of the
workaround the decision forbade. A per-instance set is *more* expressive than per-type, so per-type is
derivable rather than absent.

### F-60 corrected — there are FOUR registration sites, not three
**Status** OPEN · magnitude revised 2026-10-17

Pass 5 found a fourth site the authorised decision and pass 4 both missed. `FOLLOW_UPS §18` recorded
three; **the correct count is four.** This is the second time this item's own magnitude was wrong
(the decision said two).

### F-63 The short-circuit protects 3 of the park's 4 arms — table, from the code
**Status** OPEN · **read this before adding any arm**

| arm | protected by a short-circuit? | mechanism |
|---|---|---|
| `approve` | **yes** | `human_decision_routing.dart:196-199` fires on both `escalationTargetFor` and `_isEscalationTransition` |
| `cancel` | **yes** | same short-circuits; `(_, cancel)` arm at `:121` |
| `reTriage` | **yes** | same short-circuits |
| `rework` | **NO** | inert **only** via `_ => null` at `:214` |

**There are two short-circuits, not one** — pass 3's G17b reasoned about one and reached a conclusion
that happened to be right for `approve` and wrong for `rework` (F-61). The new fourth choice does
**not** create a fourth unprotected arm.

### F-64 `decision_choice.dart` will silently degrade on both surfaces
**Status** OPEN · `apps/**` is PROHIBITED to design lanes — specified, not corrected

`knownDecisionChoices` is a **hardcoded six-value set** against a **ten-value enum**, with its own doc
comment enumerating the six as though they were the enum's. Adding `re_triage` as a tenth value
without adding it here means its label degrades **everywhere** — including on the park. Presentation
only; routing is unaffected. Recorded for the owning lane.

### F-65 The re-triage ceiling is product policy nobody has set — R14
**Status** OPEN · **not blocking** · flagged rather than decided

`re_triage → designNotRequired` is the park's **only** arm carrying an escalation-index bound, and
pass 5 specified **not** adding one, on that edge's own rule (`:553-558` — four types are already
unbounded there). But re-triage is an **operator-invoked loop by construction**, unlike `escalation`.
A ceiling is a product decision. It does not block slice 1, and is recorded so it is chosen rather
than inherited.

**CORRECTED — the justification was false.** Independent review established that this entry's *only*
reason for flagging was *"re-triage is an **operator-invoked** loop by construction, unlike
`escalation`"*. That is **wrong**: `(escalation, approve) → designNotRequired` is the **identical**
operator-invoked loop, to the identical target, on the identical edge, and `escalation` is equally
absent from the bound's set (`human_decision_routing.dart:560-563` contains only `engineeringReview`
and `humanQaApproval`). The loop fires only when a human approves.

**The conclusion — no ceiling — survives**, on the edge's own rule at `:553-558`, which the reviewer
verified verbatim. **The reason does not**, and it recurs in three more places
(`design-revision.md:1013`, `:1960`, `design-review-gate.md:1660`). Recorded because *a correct
conclusion reached by a false reason is still a defect*: the next reader inherits the reason, and four
places now do.

---

## 20. Pass 6 (`d210475`) — and F-66, a generated count that silently mis-counted

### F-66 A generated count is not a mitigation when the generator's boundaries are hand-typed
**Status** OPEN · **WORKFLOW_IMPROVEMENT** · found by running it, not by reading it

Pass 5 committed itself to **generated, not restated, counts** — the cure for count rot (F-65's
neighbour, the ninth L3 instance). Pass 6 **ran** the generator rather than describing it, and found
it returned `13 8 9 **13**` where the five-register form counts `13 8 9 7 6`: **it silently absorbed
the new register** instead of counting it.

> *"A generator that silently mis-counts is worse than a prose number, because it looks
> machine-checked."*

**A generator whose own boundaries are hand-typed is a restatement with extra steps.** The remedy the
lane adopted is the right one: **re-derive the generator's boundaries**, and delete the restated count
from `§9.1` entirely rather than correcting it.

This is the sharpest instance in the ledger of a general lesson: **the cure for a class of defect can
become an instance of it, and only executing the cure reveals which.**

### F-67 `_resolvedOptionId`'s fallback is live in production today
**Status** OPEN · `apps/**` is PROHIBITED to design lanes — specified, not fixed

Two of `control_plane_service.dart`'s three option ids are **not** `HumanDecisionChoice` wires —
`stillBroken` / `partiallyFixed` against wires `still_broken` / `partially_fixed`
(`enums/human_decision.dart:40-41`). So `_resolvedOptionId`'s `choice.wire` fallback
(`durable_workflow_engine.dart:1113`) is **not a hypothetical hole in a future park** — it is already
reachable.

The design's original argument against G16 was *"no shipped precedent"*. **That is false**: a shipped
precedent exists and it **violates** the convention. The live counter-example is the **strongest
available motivation** for G16/G17(c), and the artifact now says so — strengthening the assertion
rather than weakening it.

### A sweep by reading found nine things the spec did not name
Four of HIGH-2's sites in the metadata register, the missing third registration site, the enum
marking, a fifth whitelist range, and a live `:531-546` the lane **caught by reading its own artifact
back** after a bulk replace — committed as `d210475` rather than amended into `cc7cca6`, so the error
and its correction are both on the record.

**`A grep finds an orphaned string, not a stale claim`** has now been demonstrated seven times. The
recurring blind spot is named in the artifact itself: **score fields, gap lists and risk rows** — *"a
field that summarises is a field that decays."*

---

## 21. Round 6 (`d210475`) — slice 1 is SAFE, and a lane under-reported its own risk level

Round 6: **no blockers**, 2 HIGH, 3 MEDIUM, 3 LOW. The reviewer verified the four scope facts, the
normative spec, and **ran the generator twice** (four-register form `13 8 9 13` against five-register
`13 8 9 7 6` — F-66 confirmed reproducible).

**Slice 1 is safe to implement.** `design-review-gate.md §6 1a` was verified **intact and correct**, and
`§8` no longer contradicts it — round 5's position (*"safe from §6 1a, not from §8"*) no longer holds.
The reviewer also verified **H1's assertion fires on mutation**: delete
`(designReviewRequest, reTriage) → designNotRequired` and G18(ii) goes red, because the clause requires
the target to **equal** `designNotRequired` and absence is not equality. It is correctly phrased over
the **target** rather than the arm's presence, so `cancel → cancelled` passes today via the
`(_, cancel)` catch-all without demanding an arm that must not be written.

### F-68 A lane reported RISK LEVEL 1 for a Level 3 artifact — and the gate would have routed as AUTO
**Status** OPEN · **governance** · the most consequential finding in this section

Pass 6 reported `RISK_LEVEL: 1`, reasoning *"no design content changed, only an assertion clause."*
The artifact itself correctly says **3**, and the reviewer rejected the 1.

The two are measuring different objects, and conflating them has a **routing consequence**:

- `risk_assessment.level` describes **the change being designed** and drives Gate D4. It is 3.
- `DESIGN_GOVERNANCE.md:97`'s Level 1 means *"inconsistency with established design system (tokens,
  components, patterns)"*. Pass 6 changed **no token, component or pattern.**

> **"If the reported 1 is acted on, a Level 3 gate routes as AUTO with notification instead of to human
> product/design/architecture approval."**

**A lane's own report of its risk level can silently downgrade a human gate.** The artifact was right
and the *report* diverged from it — which means the field a reviewer reads for its verdict was not the
field that was wrong, so it would survive a careful read of the artifact. This is the same shape as
H-A: **a summary field that decays**.

**Rule this establishes: the risk level in a lane's report is a claim about the artifact, not a
measurement of the lane's increment.** The artifact's value governs; a lane that lowers it must say why
against the artifact's number, not offer its own.

### Still open from round 6 — all in summary, risk and criteria fields
- **H-A** — `design-revision-metadata.yaml:601-604` (`acceptance_criteria` AC-9) still says the park's
  menu is **THREE** answers and reversible *"ONLY by a NEW HumanDecisionChoice that no decision has
  authorised"* — **false twice over**; `5a90c1d3` authorised exactly that. This is the twin of the
  claim pass 6 struck from `requirements_gaps`, in **a field a reviewer reads for its verdict**.
- **H-B** — three present-tense residues still say **two** arms where three exist
  (`design-review-gate.md:1273`, `:1388`, `design-revision.md:1083`). None changes what an implementer
  builds, but all three understate the slice-1→slice-2 window that R4 and `§0.2` exist to quantify.
- **M-A** — a self-cancelling bulk-replace residue at `design-revision.md:893`: *"the whitelist is
  **`:530-549`**, not `:530-549`"* — the replace hit both the correct and the rejected slot. The
  following sentence makes the intent recoverable, so not a blocker, but it is **the same replace that
  produced `d210475`**. *"Read your own artifact back"* was applied once, not swept.
- **M-B** — the H3(2) correction describes **itself** in the present tense as unfixed
  (`metadata:955-959`) although it was corrected at `:921` in the same edit. A correction misreporting
  itself as incomplete is the same failure inverted.
- **L-A/L-B/L-C** — enumeration errors in `not_rebuilt_this_pass`; loose "reads neither routing table"
  wording in `evaluator-spec.md` where it does cite them for the QA path; and G18 clause (ii) leaving
  its subject implicit.

### The reviewer's ruling on a seam the artifact asked it to decide
**G18 is the correct home for the target clause.** G17(a) is existential over type and choice and
keyed on `designApproved` by the reversal's invariant — it has **no vocabulary** for `reTriage`,
`planning`, `designNotRequired` or `cancelled`. Folding a four-target table into it would either break
that existential clause or duplicate the arm set.

---

## 22. Pass 7 (`3642a64`) — the mitigation its own documentation invalidated

### F-69 The count generator broke by being written down
**Status** OPEN · **WORKFLOW_IMPROVEMENT** · the generalisable form of F-66

Pass 7 **broke the very generator it had just fixed**, by documenting it. The boundaries were matched as
**unanchored substrings**, so writing the command into the artifact put the literal string
`### 12.4 ` *inside the command's own text*. `awk`'s range re-opened there, and the form began
reporting §12.4 as **seven** rows when it has **six**. Both boundaries are now anchored in all three
copies (`[.]`, not `\.` — a YAML double-quoted scalar rejects an unknown escape, which the parse
failure caught).

> **"A mitigation whose own documentation invalidates it is not a mitigation."**

This is the **third** iteration of the same object — a prose count (F-65's neighbour), then a generated
count (F-66), then a generated count that its own documentation disables. **The class is not
"counts rot". It is that any count kept adjacent to the thing it counts is coupled to it**, and only
executing the cure reveals which. Worth carrying into the framework.

The lane left the **count recursion open on purpose**: its row quotes the outputs at the moment of
finding, and appending the row moved the correct output again. It recorded that as *"the rule
demonstrating itself rather than chasing a fixed point"* — and noted a reviewer may reasonably call it
**a stale count with a rationalisation attached**. That is a fair reading and it is the right thing to
have flagged.

### F-70 The arm-count slip runs BOTH ways — and the normative spec was right throughout
**Status** OPEN · **informative**

The Manager named three sites saying **"two arms"** where three exist. A read sweep found a fourth
— and also found **four sites saying "four arms"** where three exist.

**There are four *answers* and three `targetFor` arms**: `cancel` is served by the pre-existing
`(_, cancel)` catch-all at `human_decision_routing.dart:121`, which is why no arm must be written for
it. `design-review-gate.md §6 1a`'s file table has read **"THREE"** correctly since pass 5; **every
summary site around it did not, in either direction.**

Recorded because it is the strongest evidence yet for the artifact's own lesson: **a reviewer reading
only the normative spec would have seen nothing wrong** — and every summary site, which is what a
reviewer actually reads for a verdict, was wrong.

### Pass 7 found eight more, five in the fields §12.4 names as this artifact's blind spot
Notably **PASS7-4**: `risk_assessment.risks` carried **no R14 row at all** — `§10` has carried R14 since
pass 5 — so the one risk a reviewer should overturn first was **missing from where a reviewer looks**.
AC-5 also carried the wrong count three ways. And **PASS7-5** is F-70.

### PASS7-16 deliberately not addressed — a reviewer should rule
~21 sites across all four artifacts carry `work_item_transitions.dart:559-563` for a guard call that
is `:559-564` — a **uniform one-line truncation**. Every one of the 21 states the correct property.
The lane corrected the three `:528-563` edge-range sites but declined these, on `§14.5`'s precedent
that rewriting a verified citation for tidiness is worse than leaving it — and reverted an earlier
partial fix, because that would have created a **3-vs-21-site inconsistency inside one artifact set**.

**Recorded rather than resolved.** It is a judgement a reviewer can overturn, and the reasoning is
stated.

---

## 23. Round 7 — slice 1 is SAFE, and Gate D4 approval is outstanding

Round 7: **1 BLOCKING, no HIGHs**, 3 MEDIUM, 2 LOW. All of it documentation, count, rationale or
citation — **none alters what an implementer builds.** The reviewer verified `§6 1a` and `§8 1a` intact:
three arms, four answers, `cancel` served by `(_, cancel)` at `human_decision_routing.dart:121` with row
3 marked *"none needed"*, three whitelist admissions, four files.

### The blocker is F-69/F-70 recurring at the one place a reader is directed to
**§16(11)** still carries the **unanchored** generator form. Run by the reviewer it yields
`13 8 9 7 8 17` — §12.4 reported as **eight** against six actual rows — making four claims false
including the one that *"both boundaries are now anchored"*. **The anchored form is correct and stable
across two runs (`13 8 9 7 6 17`) and already exists at `:2208-2211` and `metadata:1952`.** It was
simply never pasted into `§16(11)` — the normative location, which `design-revision.md:1033` points a
reader at with *"GENERATED — see §16(11)"*.

**This is now the fourth iteration of one object**, and the sharpest possible statement of the lesson:
a mitigation that is *known, written, verified stable, and not pasted where it is read* is not
mitigated. The fix existed. Its location was the defect.

### F-71 PASS7-16's rationale was wrong, and its count undercounted by half
**Status** OPEN · corrected by the review's ruling 1

Leaving the 21 `work_item_transitions.dart:559-563` truncations was **right**; the recorded reason was
not. `§14.5`'s precedent (`:641-650`) is a range **inside a command transcript** — rewriting it would
falsify a record of output actually produced. `:559-563` is **hand-written prose**, so the precedent
does not reach it.

The correct and stronger ground: **`:559-563` contains the entirety of the quoted material.** Every site
states *"contains exactly `engineeringReview` and `humanQaApproval`"*, and `:559-563` establishes that
completely — the truncated `:564` is a closing `),` contributing nothing.

**Why that distinction matters:** as written, PASS7-16's reasoning would license leaving the *next*
truncation that actually **drops quoted content** — which PASS6-2's `:528-546` did, including the edge
header and two of six pairs. Categorically different defects, treated as one.

Also: **32 raw occurrences across the four artifacts, not "≈21"** or the commit's "sixteen".

### Ruling on the count recursion
The lane's account **stands** — the claim names the run, names the moment, and the moment is in the
transcript, so it is not *"a stale count with a rationalisation attached"*. But two residues are real:
`§12.5`'s heading still reads *"sixteen findings"* over **seventeen** rows, and `§16(11)` restates five
counts on a line declaring itself *"GENERATED, NOT RESTATED"* while omitting `§12.5` — PASS5-7/PASS6-6
recurring **inside the rule against them**.

### Gate D4 is outstanding and this review does not discharge it
Risk level **3**. Round 7 returned `HUMAN_DECISION_REQUIRED: NO` because none of *its* findings is a
product or architecture decision — they are all mechanical, consistent with rounds 5 and 6. **That is
not the same as the design being approved.** The Level-3 gate requires human product/design/architecture
approval and **no review round has discharged it.**

R14 — whether a re-triage ceiling is product policy — also remains an **open operator decision**,
recorded as a risk rather than escalated. It does not block slice 1.

---

## 24. Slice 1 implemented (`84460a2`) — the human surface now exists

`design/qa-contracts-feature-remediation/design-review-gate.md §6` sub-slices **1a** and **1c**, on a
Gate-D4-approved design (`8c26d40f`). Eight files, +1139/−10, all inside the six granted paths.

### The first attempt blocked, and was right to
`_isReWorkDecision`'s switch (`durable_workflow_engine.dart:991-1003`) is **exhaustive with no wildcard**,
so adding `reTriage` produced exactly **1 analyzer error** — in a file the approved table did not name.
The scheduler's drift guard also went **red with 1a** (419 pass, 1 fail), green at base. The lane
**did not widen its own scope and did not commit**; the operator ruled on both
(`d41a6e85` classification, `0f72b3a1` scope).

### F-72 A spec verified by citation is not a spec verified by compilation
**Status** OPEN · **WORKFLOW_IMPROVEMENT** · the most transferable finding here

The file table survived **seven rounds** of independent review, verified citation-by-citation, and was
still wrong. **Every check was a citation check. None was a compile check.** The artifact set contains
**zero occurrences of "exhaustiv"** — the coupling was never in anyone's mind.

The whole defect class cost one command to find: **add the enum value, run `dart analyze`.**

Standing recommendation: **any lane that adds an enum value should run `dart analyze` across the
workspace as a required gate**, because a `switch` in one package is a compile-time coupling to an
enum in another, and nothing about the change's own package reveals it.

### F-73 A behavioural assertion cannot see a redundant arm — the guard had to read source
**Status** OPEN · **QA_DISCOVERY** (retagged: this file's own first draft used "executable knowledge", which
is a principle, not one of `LEARNING_POLICY.md`'s 11 categories — corrected on review)

Acceptance criterion 4 requires that `cancel` acquire **no** `targetFor` arm, since `(_, cancel)` at
`human_decision_routing.dart:121` already serves it. **Mutation M6 added a redundant
`(designReviewRequest, cancel) => cancelled` arm and came back GREEN** — 22 pass, 0 fail. A redundant
arm is byte-for-byte behaviourally identical to the catch-all it duplicates, so **no behavioural
assertion can see it.**

Fixed with a **structural** guard that counts the arms in the source — the one assertion in the file
read over source rather than behaviour, and it says so in its own comment. Precedent:
`transition_copy_test.dart:24-40` already derives the edge table from source for the same reason.

**The generalisable part: "this cannot happen" and "this is not observable" are different claims**, and
an acceptance criterion phrased as the first needs the second kind of evidence.

### Non-vacuity — 15 mutations, all reverted, tree restored byte-identically (sha256 verified)
Arm deletion, each of the three whitelist admissions, the forbidden escalation arm, the redundant
`cancel` arm, `knownDecisionChoices` membership, the generic label arm, and dropping `reTriage` from
`_isReWorkDecision` (**1 analyzer error** — the compile coupling, reproduced). Counts reported per
mutation.

### Pre-existing defects disclosed, not absorbed
- `dart format` **red at base** (`work_item_transitions.dart:51`); green now only because that file is
  in scope and was formatted — **stated plainly rather than letting a green gate imply the work**.
- `platform_contracts/test/serialization_test.dart:420` — 26 vs 27 `WorkItemState`, red at base and at
  HEAD, identical.
- `apps/control_plane/test/shared/transition_copy_test.dart` — red at base, **proven** in a detached
  worktree, and **CWD-sensitive by design**: run from the repo root it reports a *different* failure
  (+14 −2 vs +15 −1). Worth knowing before someone runs it wrongly and blames the change.
- `onboarding_test.dart` and the 10 integration files need Postgres; docker prohibited, not run.

### R14 remains open
`(designReviewRequest, reTriage)` is pinned as **deliberately unbounded** from both sides — a bounded
pair is *refused* at escalationIndex 99/max 3 while this pair *passes* the same fixture. Per
`d41a6e85` no escalation arm was added. **Whether a ceiling should apply is product policy and is still
unanswered.**

---

## 25. Review of slice 1 — DO_NOT_MERGE on 1 HIGH + 1 MEDIUM, no blockers

Independent engineering review. **No blockers, all gates green, provenance verified, no production
defect.** The review re-ran the gates, **confirmed all four claimed pre-existing defects at BASE**
rather than accepting them, and ran **6 mutations of its own** rather than the lane's 15 — 5 of 6
caught.

### F-74 The classification ruling has ZERO executable coverage against production
**Status** OPEN · **BLOCKING** · found by mutation, not by reading

Flipping `durable_workflow_engine.dart:1015` from `HumanDecisionChoice.reTriage => true` to
`=> false` leaves **every test green** — the drift guard 15/15, all 38 scheduler files, all 9
workflow_engine files, all 4 workflow_store files, all 42 non-Postgres `apps/server` files.

**Cause:** `triage_entry_state_drift_guard_test.dart:96-99` derives `_isReWork` from
`_recognisedReWorkChoices`, so the test at `:286-303` ("reTriage IS re-work") **asserts the literal
list against itself**. And `packages/workflow_store/test/triage_discriminator_test.dart` — the file that
drives the **real** predicate — has **no `reTriage` case**; its own group header at `:283` records that
the guard was moved out of this package, which is **how the production coverage was lost**.

The doc comment at `durable_workflow_engine.dart:966-972` calls this *"the arm that must NOT be
omitted"* and names the consequence — the item goes inert for ever. **One silent edit away, fully
green.**

**A second, related claim is false.** `triage_entry_state_drift_guard_test.dart:216-218` says: *"A
second copy is only worth having if the copies are pinned to each other, and the only thing that pins
them is totality."* **Totality pins each copy to the ENUM, not to the other copy.** A value classified
in BOTH copies on **opposite sides** satisfies every assertion in the file. The stated sufficiency does
not hold.

This is F-72's and F-73's lesson again, and it is the sharpest instance: **an assertion that reads its
own input back is not coverage.** No human decision is needed — `d41a6e85` already states the answer;
it is simply untested against production.

### F-75 A mandatory format fix silently shrank a drift guard's coverage
**Status** OPEN · **BLOCKING** · undisclosed consequence, not a wrong action

The lane correctly formatted `work_item_transitions.dart` — the file is in `OWNED_PATHS` and the gate
is mandatory. **But** replaying `transition_copy_test.dart`'s own regex over BASE and HEAD gives
**53 pairs → 52**. The lost pair is
`featureIntakeParked → waitingForHumanDecision` — **the multi-line form the formatter produced no
longer matches the single-line regex.**

That edge is the **feature park's only way out**: the file's own comment reads *"DELIBERATELY NO EDGE
BACK TO `planned` … Recovery is via the human gate."* Nothing else in the tree asserts it exists —
`featureIntakeParked` appears in tests only at `transition_consistency_test.dart:206-212`
(entry-state dispatchability), `design_review_park_surface_test.dart:609` (a different probe), and
`work_entry_test.dart` (state assertions). **Deleting it would now fail nothing and turn the park into
a dead end.**

**Two classes in one finding: an enforced gate that can silently reduce coverage, and a regex that is
not whitespace-tolerant.** Making `transition_copy_test.dart`'s regex tolerant is the better fix but is
**outside the six granted paths** and needs a scope grant; asserting the edge exists from a test inside
the granted paths is the available fix.

### Confirmed sound by mutation — do not re-litigate
Three arms and four answers, with the structural guard proven **not defeatable by the realistic
attack**: a redundant `cancel` arm added in single-line form was caught, and **re-added in the
multi-line form `dart format` itself produces** — which the arm regex does not match — was still caught
by the `allMatches` count. Fail-closed on rename. **No `escalationTargetFor` arm for any of the four**,
`designReviewRequest` absent from the ceiling set, **R14 open and pinned from both sides** (a smuggled
ceiling turns red). `_declaredNotReWork`'s reason is enforced (`length > 80`). The two-step park order
is untouched.

*Correction to the Manager's brief, not the code:* the throw is at
`durable_workflow_engine.dart:573-583`; `:564-565` is the idempotent-return condition.

### Also disclosed by the reviewer
`apps/control_plane/.flutter-plugins-dependencies` is a **generated file committed to version control**
and version-drifted (`.fvmrc` says 3.44.0; the committed file says 3.44.7), so any
`fvm flutter test` dirties the tracked tree. Pre-existing.

---

## 26. F-74 and F-75 closed (`1b973b2`) — test-only, and both findings were partly wrong

Three files, **all tests. No production code changed.** Both findings reproduced by mutation *before*
correction, both closed by mutation after. `workflow_store` 61, `workflow_engine` 197, `scheduler` 423.

### F-74 closed — and the lesson is sharper than the finding
Production coverage added at `triage_discriminator_test.dart`: two cases that drive the **real**
`resolveHumanDecision` and read the marker off the durable row. `(designReviewRequest, reTriage)` stamps
3; `(designReviewRequest, approve)` stamps nothing. **They differ only in the choice, so the pair is
two-sided.** Flipping `:1015` now turns exactly one test red (`Expected: <3> Actual: <2>`) and leaves
the other 16 green.

The guard's false `totality` claim is corrected, with what actually pins the copies stated instead.

> **A test deriving its expectation from a literal list in its own file cannot detect production
> disagreeing with that list.** Totality pins a copy to the **enum** — never to the other copy. This is
> the third instance of one shape in this work: F-72 (a citation check is not a compile check), F-73
> (a behavioural assertion cannot see a redundant arm), F-74 (a self-referential assertion is not
> coverage).

### F-75 closed — and the finding was wrong twice
1. **Provenance.** It said *53 → 52* over BASE and HEAD. BASE at `84460a2` gives **52**. The real loss
   is **`ddfbfff`(53) → `84460a2`(52)** — slice 1's own commit, reflowing that exact edge into
   multi-line form. The attribution was right; the commit boundary was not.
2. **"Would now fail nothing" is false.** `transition_consistency_test.dart:54` **does** go red. But it
   is a **mirror guard** (live table vs. a hand-written `allowedTransitions`), so it fails for the
   **wrong reason** and is removable by the **wrong edit**: anyone syncing the mirror to a
   deliberately-removed edge turns it green while the park is stranded.

**The real gap, stated correctly: the edge had no guard that said what it was *for*.**
`feature_park_way_out_test.dart` now names it as the park's only way out via `isLegalTransition`, and
deleting the edge turns it red.

### Reported, not repaired — the Manager rules
- **`transition_copy_test.dart:44`'s regex is not whitespace-tolerant**, and `dart format` — a
  **mandatory** gate — silently shrank what it watched. **Outside the granted paths; not edited.**
  Two properties would fix it: a whitespace-tolerant regex, and a pinned pair count.
- `execution_coordinator/budget_expiry_is_a_timeout_test.dart` is **TIMING-FLAKY** — failed once on a
  real clock with 2–6s waits, passed on rerun. **It can produce a false blocker report**, which matters
  because that is exactly how a lane learns it failed.
- `human_decision_routing.dart:169` cites `durable_workflow_engine.dart:979` for
  `_isEscalationTransition`, actually at `:1029` — **50-line drift**. The file was in the granted paths
  and the fix was **deliberately not taken**, as unrelated to both findings. Recorded rather than fixed.

---

## 27. Focused re-review: APPROVE_CORRECTIONS, READY_FOR_MERGE

Independent focused re-review of `1b973b2`. **No blockers, no highs.** Both mutation proofs
**reproduced independently in a sandbox** — not accepted:

- **F-74** — flipping `durable_workflow_engine.dart:1015` to `=> false` reds exactly one test
  (`Expected: <3> Actual: <2>`); 17 others green; `scheduler` 423/423 and `workflow_engine` 197/197
  stay green. The reviewer confirmed the new tests drive the **real** `resolveHumanDecision` with
  nothing stubbed, and that the marker is computed by production `nextTriageAttempt` over a durable,
  re-read seed. The pair is genuinely two-sided: making `approve` fire at `designReviewRequest` reds
  only the second case.
- **F-75** — deleting the edge reds `feature_park_way_out_test.dart`. The reviewer **proved the mirror
  judgement** by applying the wrong edit: deleting the edge *and* syncing
  `allowedTransitions` turns the mirror guard **green** while the new test is the only failure in the
  package. *"The mirror is synchronisable and the two guards fail in opposite directions."*
- **Regression risk: none of the three.** The new file asserts an edge *exists*, so it cannot contradict
  the authoritative `_legalTransitions`; `allowedTransitions` has **zero production readers**; it
  duplicates no guard; non-vacuous by deletion. The scheduler guard's +63/−6 is **comments-only** —
  485 code lines each side after comment stripping, byte-identical, no assertion weakened.

### F-76 A false rationale inside the artifact whose subject is "what pins what"
**Status** OPEN · non-blocking · **MEDIUM-1** on review

`triage_entry_state_drift_guard_test.dart:249-253` and `:263-265` justify why the cross-copy check
cannot live in that file: *"this package depends on `workflow_store`, so its tests may not import the
engine."* **That is false.** `scheduler` declares a `workflow_engine` path dependency and **this very
file imports `package:workflow_engine/workflow_engine.dart` on line 4**; `scheduler` also depends on
`workflow_store`, so a scheduler test *could* drive `resolveHumanDecision` and compare both copies.

The correction's **conclusion** is sound and verified. **The stated blocker is invented** — and it is
invented inside the artifact whose subject is exactly *what pins what*, in a repository that has been
harmed repeatedly by confident-but-unverified reasoning. Recorded because the failure mode is the one
this ledger keeps documenting: **a correct conclusion reached by a false reason is still a defect.**

### Reviewer's rulings on the three reported-not-repaired items
- **`transition_copy_test.dart:44`'s non-whitespace-tolerant regex** — **NOT blocking, HIGH
  follow-up, new owner.** It caused F-75, but the correction added a direct guard for the edge whose
  loss mattered. **Not neutral, though: a mandatory gate that has already silently dropped TWO pairs
  and is already red for copy predating slice 1 enforces nothing.** The reviewer also found the second
  pair — `(waitingForHumanDecision, implementationReady)` — was already invisible at `ddfbfff`, so the
  defect **predates slice 1**.
- **`budget_expiry_is_a_timeout_test.dart` timing flake** — NOT blocking, LOW. 1 failure in 19 runs,
  unreproducible in 18 including 4 concurrent, in a package this change does not touch.
- **The 50-line citation drift at `human_decision_routing.dart:170`** — NOT blocking, LOW. Cites
  `durable_workflow_engine.dart:979`; `_isEscalationTransition` is at **`:1029`**.

---

## 28. The silent scheduler crash — fixed (`96db89c`), and a HIGHER-cadence twin remains

`APPROVE_CORRECTIONS`, no blockers, no regression. The review **reproduced the mutation proof
independently** in a temp copy outside the workspace: `+21 −6` against base, with `start()` failing as
an **unhandled** `Bad state: StreamSink is closed` on the production stack shape
(`_createProviderTicket` ← async gap ← `checkAll`, no `catchError` frame).

### The crash, and why it was invisible
An unhandled Postgres `StreamSink is closed` killed the QA server's **isolate**, taking the scheduler
with it. **A dead scheduler still logs `scheduler.tick.completed {ran: false}`** — so the outage looked
like a healthy idle system for hours. Found only by `ps`, not by the operator surface.

**Root cause, and the obvious suspect was wrong.** `ProviderHealthMonitor.start()` discarded the
`checkAll()` future on a self-rearming `Timer.periodic` and an immediate `unawaited`. `checkAll` is
**not observation-only** — it reads `model_policy`, reads `human_decision`, and **writes**
`human_decision` via `_createProviderTicket` / `_raiseAllProvidersDown`. Both call sites threw the
future away, so a mid-write socket close left `checkAll` with **no listener** ⇒ unhandled ⇒ terminate
isolate. There is **no `runZonedGuarded` anywhere in the repo.**

The lane **rejected the first suspect by inspection**: `local_worker.dart:192-194` uses `.timeout(...)`,
which *looks* like it abandons a late error but does not — SDK `future_impl.dart:1060-1073` keeps
`onError` attached permanently and the SDK doc says `StateError` is ignored. That path is already
correct; the fix did not touch it, and says so in the commit so the next lane doesn't re-chase it.

Fixed by routing both call sites through a guarded `_fire()` and containing each store-backed step
individually, so a dead connection costs **one** operation and the cycle still probes every remaining
provider. A throwing probe maps to `unknown`, **never** `down` — absence of evidence must not mark a
provider down on the strength of the observer failing.

### F-77 An equivalent unguarded path remains, at HIGHER cadence — not the lane's to fix
**Status** OPEN · **HIGH** · `apps/server/lib/server.dart:1233`, read-only to the correction

The focused reviewer **dismissed the lane's "unawaited(tick.trigger()) is safe" note.** It verified
empirically on SDK 3.12.2 that `TickSingleFlight._runGuarded` **rethrows** (`server.dart:1922`), so
**any** escape from `runTick()` kills the isolate. The tick loop is safe only by per-section
discipline — and each section's `catch` calls `_log`, the **same closed-sink class**. This path ticks
**every 30 seconds**, higher cadence than the path just corrected.

Read-only and pre-existing, so out of scope for that correction — but the follow-up must say *an
equivalent unguarded path remains*, not imply the class is closed.

### F-78 No process-wide containment — escalated, correctly, as architecture
**Status** OPEN · **HUMAN gate** · the reviewer agrees it is not a code fix

There is no `runZonedGuarded` in production code anywhere. Process-wide containment would change
**every** lane's failure semantics and interacts with the documented exit-signal contract
(`server.dart:1260-1266`). Both the lane and the reviewer independently judged this a human/architecture
decision, correctly — it is a **follow-up, not a blocker**.

### Follow-ups the reviewer confirmed non-blocking
- The per-role containment test comment claims all roles are reached; **measured false** (2 write attempts
  for 12 roles — `_step` wraps the whole loop). Fail-open and self-healing; the comment overstates.
- `_findPendingTicket`'s `on StateError` **swallows the crash's own error type**: a read-only fault
  mints 12 duplicate tickets silently. Identical at `CORRECTED_FROM` — pre-existing, masked by the new
  test faulting read+write together.
- The deferred residual at `provider_health_monitor.dart:149` is **larger than reported**: `stderrDetail`
  is created every probe but awaited only on the non-zero-exit path, so **both** stdio drains can escape
  on the healthy path.
- `onboarding_test.dart` is an integration test misfiled under `test/` (needs a DB); it will read as a
  regression in any local run.

## 29. The three stranded items are REPAIRED — and the real blocker is a wedged scheduler tick

**Outcome.** All three items stranded at `agent_executing` with `qaContractId = NULL` on 2026-10-17 now
carry a real `qa_contract` row (`version 1.0.0`) and a non-null `qaContractId`, written by the product's
own provisioners. No `work_item` row was ever written by SQL. The QA-contract guard — the original
blocker — no longer fires: its four historical failures are all timestamped `2026-10-17 09:54` and
`2026-10-18 03:04`, all before the contracts were attached, and **no new failure cites it**.
`WI-feature-1791823723502264` produced a **`succeeded`** job after its contract was attached.

**F-79 — BLOCKING — the single-flight guard is released correctly but has NO BOUND; fixed at `ab6b966`.**

> **CORRECTED 2026-10-18 after `correct-WEDGED-TICK`.** This entry originally read "the tick is
> permanently wedged" and "a deadlock, not slow progress". **That was an over-claim and it is
> withdrawn.** `overlappedTicks: 1` is byte-identical for a wedged tick and a tick within budget, so it
> cannot distinguish them; and at the time of writing the job was only **~66 minutes** into a
> **4 h + 60 s** budget (`server.dart:2889`, `local_worker.dart:283`). The evidence did not establish a
> wedge. Job `jb-hnbbwqcwm0-bduerb` was **not** cancelled — it is live evidence and the fix does not
> require reaping it. What follows is the defect that *is* real, and it is independent of that claim.

There is **no skipped release path**: acquisition `server.dart:1880`, release in `whenComplete`
`:1886-1888`, correct on success and failure alike, and the existing
`tick_single_flight_test.dart:200`/`:249` already pinned both. The defect is that the release had
**no bound**. `whenComplete` fires only when `runTick()`'s future settles, which requires the body to
return; the body awaits triage → impl → review → baseline → sweep, and the impl path blocks at
`scheduler.dart:1941` `await _dispatch.run(request)`.

> **This paragraph was itself false, twice.** It originally claimed that `workspaceManager.prepare`,
> `inspector.inspect`, `artifactCommitter.commit` and cleanup were "each awaited with no timeout at
> all". **That was wrong for three of the four**, and the same false claim is in the `ab6b966` commit
> body, which is permanent provenance and cannot be amended. Corrected facts: `prepare`
> (`git_worktree_workspace_manager.dart:44-49`), `commit` (`artifact_committer.dart:177-184`, default
> 60 s at `:82`) and cleanup (`:160` → `:162` → `_git`) each carry a **60 s per-command** `.timeout()`.
> The genuinely unbounded one was **`GitWorkspaceInspector.inspect`/`_capture`**
> (`git_workspace_inspector.dart:107`), whose declared `timeout = 30s` at `:25` was documented at
> `:19-21` as "a hard bound" and **never applied** — a dead field reading as a live one. Fixed at
> `7098dbf`; see **F-87**. Note the bounds are **per command, not per await**, and `.timeout()` bounds
> the *wait*, not the process: an expired git is abandoned, not killed.

A tick that stalls in any of them holds the guard for the life of the process and dispatch stops.
Fixed by leasing the guard (`ab6b966`): on expiry the guard is released, the tick is
left **running**, nothing is cancelled, and release is tokenised so an abandoned tick's `whenComplete`
cannot clear a guard a newer tick holds. Bound is `SHIPIT_TICK_MAX_HOLD_SECONDS`, unset deriving to
`4 × largest budget + stallAllowance` = **17 h** — the safe direction, because `Scheduler.tick`
dispatches its backlog serially so a legitimate hold is unbounded in N.

**F-79a — a dropped-overlap log line cannot distinguish "stuck" from "working".** `heldForSeconds` on
the drop line, or a periodic held-tick heartbeat, would have made tonight's question answerable from
logs alone. Not implemented — a second diagnostic, outside a focused correction.

**F-80 — the repair script's `--dry-run` green-washed the exact bug it should have caught.**
`repairDesignRemediation` in dry-run never calls `ensurePersisted`
(`bin/repair_stranded_work_items.dart:349-360`); it calls the script's own `ensureQAContract`, which
returns `would-attach:…` at `:276-281` **before it ever looks at `productId`**. So the dry run printed
`via-laneE:would-attach:…` while the real run printed `via-laneE:refused-or-absent`. A clean dry run
was never a rehearsal of the path that was broken. **Never treat this dry run as evidence about the
design-remediation path.**

**F-81 — a work item's own `productId` is authoritative for its gates; `defects` is not a product.**
`resolveDesignRemediationProductId` (`lane_e_design_remediation_work_item.dart:86-98`) reads
`defect.affectedWorkItemId` and falls back to `defectTriageBucketProductId` — the literal string
`"defects"` (`lane_a_defect_triage_work_item.dart:17`) — when it is null. Both defects had
`affectedWorkItemId = NULL`, so the gate was sought under `defects`, which has **no** `product` row and
**no** `product_qa_contract_spec` row, and provisioning failed closed with `notDeclared`. Meanwhile
**all 14** work items record `productId = shipit-platform`. The row and its own gate disagreed.
Fixed at `0d32877` under decision `8f1ed5bf`: the replay branch now uses the existing row's `productId`,
falling back to the defect-derived value only when blank. **Creation-time resolution is byte-identical**
— verified by doc-stripped region SHA, not by assertion.

**F-82 — re-registering a product is a MERGE, not a clobber (`6e83b1c7`).**
`registerProductWithManifest` routed through `createProduct`, and `saveProduct` with a null
`expectedVersion` is `INSERT … ON CONFLICT DO UPDATE SET … state, createdAt … version`, which would have
reset `governed → registered`, nulled `description` and rewritten `createdAt` on `shipit-platform`.
`ProductTransitions` has **no** `registered → governed` edge (only `→ baselinePending` at
`product_transitions.dart:81` and human-gated `→ archived` at `:138`), so the product would have
stranded an **accepted** baseline behind a fresh revision, verification and human approval.
Verified live after the fix: all four columns byte-identical, declaration written. Note
`apps/control_plane/.../add_product_page.dart` had asserted this path was an idempotent upsert — it was not.

**F-83 — a `Serverpod` pod never needs `start()` for a one-shot script, and this is the only safe way
to touch an irreplaceable database.** The constructor opens the DB pool (`serverpod.dart:544-558`,
ISSUE(2421): it exists so `createSession` works) and `PostgresPoolManager.start()` only calls
`pg.Pool.withEndpoints` — no connection, no write. **Every write-capable boot step lives inside
`start()`**: `migrateToLatest`, the unconditional `verifyDatabaseIntegrity`, and the `RuntimeSettings`
INSERT. So a repair script that never calls `start()` and never passes `--apply-migrations` cannot
mutate schema — which is what made running it against the irrecoverable QA database defensible.
`Database` is not constructible outside the package, so this cannot be proved behaviourally; the repo's
proof is a comment-stripped source guard.

**F-84 — five sibling scripts carry the F-83 hazard on the same irreplaceable database.**
`bin/add_human_claims.dart`, `e2e_dev_server.dart`, `onboard_shipit_dev.dart`, `onboard_shipit.dart` and
`test_pod.dart` each pass `['--mode','development','--apply-migrations']` **and** call `pod.start()`.
Against `SERVERPOD_DATABASE_*` pointed at QA, any of them applies pending migrations. Unlike the repair
they legitimately *need* migrations, so F-83's remedy is wrong for them; their correct remedy is a guard
refusing non-disposable targets. `bin/main.dart` is clean.

**F-85 — five of `apps/server/bin/`'s peers plus the tick share one lesson: the dry run must exercise
the changed path.** See F-80. Non-vacity must also survive a phantom edit: a `Edit` call reported
success while writing only whitespace, and only a `shasum` against a saved copy caught it. Standard
adopted: byte-copy, `shasum` before and after, `dart format --set-exit-if-changed`, then trust the count.

**F-86 — `apps/server/dart_test.yaml` declares `tags: integration: {}` but nothing annotates it.**
29 files live in `test/integration/` and 28 boot a real Serverpod, so a plain `dart test` there burns
~15 min on 32 connection timeouts and **cannot be excluded by tag**.

**F-87 — the unbounded hold has a root cause deeper than the guard — RESOLVED by
`correct-DEAD-INSPECTOR-TIMEOUT`, with the earlier text of this entry corrected.** The lease restores
"dispatch eventually", not "dispatch promptly", and it treats the symptom at the guard. An earlier
version of this entry — repeated in the `ab6b966` commit body, which is permanent provenance and
cannot be amended — claimed that only one bound existed on the whole dispatch path and that
`workspaceManager.prepare`, `inspector.inspect`, `artifactCommitter.commit` and cleanup were each
awaited with **no timeout**. That was wrong for three of the four, and wrong in a way that would have
sent the next lane hunting for the wrong defect. Verified against the tree:

| await | bound |
|---|---|
| `workspaceManager.prepare` | bounded — every git command, 60s (`_git` in `git_worktree_workspace_manager.dart:44-49`) |
| `artifactCommitter.commit` | bounded — 60s (`artifact_committer.dart:177-184`) |
| cleanup | bounded — 60s, via `_removeWorktreeUnsafe` → `_runGit` → `_git` |
| `inspector.inspect` | **was unbounded** — `await Process.run(git, args)` with no `.timeout()` (`git_workspace_inspector.dart:107`) |

So the defect was not a *missing* timeout in four places. It was a **present-but-dead** one, in a
single place: `GitWorkspaceInspector` declared `timeout = 30s` (`:25`) and its class doc (`:19-21`)
promised "a hard bound so a wedged filesystem cannot hold the worker hostage", while `_capture` never
applied the field. A declared, documented timeout that reads as a live one is worse than an absent
one, because it converts a search into a false negative.

Fixed by applying the declared field with the sibling classes' own idiom, and pinned by
`packages/worker_runtime/test/inspector_timeout_bound_test.dart` — a stub `git` that sleeps, asserting
the inspector gives up at the bound and reports `GitCommandException`. No database, no Docker. The
test fails on the pre-fix tree (waited out the stub: 15.7s where the bound allowed 500ms) and passes
after.

**Residual, deliberately not closed here.** These bounds are per *command*, not per *await*: a phase
running several git commands can still take a multiple of its bound, and `.timeout()` bounds the
*wait*, not the process — an expired git command is abandoned, not killed. Bounding the phases as
wholes is a different, larger change and stays out of scope for a correction lane.

**F-88 — `SHARE IT WITH ME`: an in-flight tick's duration is unobservable after the fact.** The
recovering observation for F-79 required reading the implementation budget and the job start time
together. Neither is in the tick log. See F-79a.

**F-89 — a timed-out inspection is indistinguishable from an untouched workspace.**
`GitWorkspaceInspector._captureOrNull` guards only `diff --name-status` and `diff --stat`; after
`7098dbf` a wedged git during either yields **null** rather than propagating, so `changedFiles` /
`diffSummary` come back empty. **No lifecycle decision reads them** — the `agentCompleted` vs
`agentFailed` verdict comes from `successArtifacts.inspect(...)` via `workspace_delta_probe.dart`, a
separate mechanism — so this is a read-only view flowing into `worker_result.changedFilesJson`. The
pre-existing position is stated at `workspace_delta_probe.dart:284-287`: *"A missing `git`, a wedged
filesystem, a timeout. Never propagated: this probe answers a question, and 'could not answer' is an
answer."* Accepted as correct. **The residual is human-facing**: an operator can read
`changedFiles: []` as "touched nothing" when the truth is "git hung". The proper remedy is an
"inspection incomplete" marker on the result, not a propagated exception.

**F-90 — a declared-but-never-applied bound is mechanically findable and was found by hand.**
`GitWorkspaceInspector.timeout` (`:25`) and `OnboardingWorker.gitTimeout`
(`packages/worker_runtime/lib/src/worker/onboarding_worker.dart:55,69`, 5 minutes, read nowhere
while its siblings `buildTimeout:201` / `testTimeout:228` are used) are both public `final Duration`
fields with no read. The first is fixed (`7098dbf`); the second is vestigial rather than an unbounded
await, because that worker's git runs through the now-bounded workspace manager and inspector.
A lint or test failing on a declared-but-unreferenced bound would catch this class without a reviewer
noticing — scope it to `final Duration` **class fields within one library**, since inherited fields and
top-level constants read only elsewhere are false positives.

## 30. Workflow restored — §29's recovery verified live, and what is deliberately left open

**The flow runs again.** Scheduler healthy: 60 ticks in 30 min, `ran: true, dispatched: 0,
overlappedTicks: 0, heldForSeconds: 5` — idle because the backlog is drained, **not** wedged. The
lease's `heldForSeconds` field now appears on the tick line, which is the F-88 diagnostic that was
missing. `design-remediation-DEF-1791685264570406` and `WI-feature-1791823723502264` both completed
executions and the pending human-decision count rose 8 → 10, so items are reaching the human gate again.
**Zero** new job failures cite the QA-contract guard.

**F-91 — the repair script's `--dry-run` cannot rehearse the path it names (see F-80). Already
recorded; restated here because it nearly cost a second green-washed verification.** The one signal
that *did* predict correctly was the real run's `refused-or-absent`. Treat dry-run output for
`repairDesignRemediation` as non-evidence, permanently.

**F-92 — the repair's failure-recording idempotency was per work item, not per failure, and its report
claimed retries it did not perform — RESOLVED by `correct-PER-FAILURE-IDEMPOTENCY`, with three
findings the original entry did not name.** `design-remediation-DEF-1791686085546076` is stuck at
`agent_executing` with **two** terminal failed jobs; the repair skipped recording the second failure
because one `agentExecuting → agentFailed` row already existed for that item, then called
`operatorRetry`, which returned the item **unchanged via an idempotency-key replay**
(`durable_workflow_engine.dart:465-467`, and the `transition` replay at `:145-148`). Its output still
printed `retried: true` while the state did not move — a **false claim in the repair's own report**.

> **Corrected twice.** An earlier version of this entry said `operatorRetry` "correctly refuses from
> `agent_executing`". **That is wrong at the layer the script operates on.** The script calls the
> **engine** directly (`repair_stranded_work_items.dart:664`), not the endpoint. In the engine a genuine
> refusal **throws** (`:205-208` via `:486`) and `_guard` turns it into `FAILED: … WorkflowTransitionRejectedException`
> and `exit(1)` — it never reaches the `retried` line at all. So the observed `retried: true` could not
> have come from a refusal; it came from a **replay returning the row unchanged**. My separate
> `outcome: notApplicable` observation was true but describes a **third** layer the script never reaches
> (`work_item_action_endpoints.dart:592-599`). A second incompleteness: `[stranded.failure_recorded]`
> was *also* logged unconditionally on that replay path, so the original transcript of the output was
> incomplete.

1. **The idempotency key is now the failure, not the work item** — on both writes. The failure key
   and the `operatorRetry` key were *separately* per work item, so fixing only the first still left
   the second producing a silent no-op: the engine returns the item unchanged on a matched
   `idempotencyKey` while the caller believes a retry happened. Measured separately, each key is
   load-bearing and each turns exactly one assertion red on its own. Keyed on the durable job id, a
   replay of the same failure finds its own row and writes nothing while a genuinely new failure does
   not collide — the same principle the operator-action ledger already applies, since the thing being
   made idempotent is a specific *occurrence*, not a specific subject.
2. **Reported outcome fields are now derived from what happened, not from having reached the code
   that does it.** `retried` was hardcoded `true`; it is now a getter over a new
   `StrandedRetryOutcome`. Three more fields were audited and found in the same shape: `wroteAnything`
   (hardcoded `true` on the recovery path, so a run that changed nothing reported a change — and it
   feeds the process's `N of M item(s) changed` summary), the `[stranded.retried]` **log event**
   (emitted unconditionally, so the false claim also reached the log, where a reader takes it as a
   fact rather than as a report), and `stateAfter`, which was the only already-truthful one. The new
   `failureRecorded` field replaces the unconditional `[stranded.failure_recorded]` log.
3. **The exit status now reports it.** A declined retry exits non-zero via
   `strandedWorkItemExitCode`, because that run prints a complete, plausible report while leaving the
   item exactly where it started. `null` for every run that legitimately changed nothing — a dry run,
   an unstranded item, a refused item with no durable failure, a repair that worked — so it cannot
   degenerate into always non-zero.

**Consequence of (1), recorded rather than hidden, and stated CONDITIONALLY:** rows written under the OLD
per-work-item key are not deduplicated by the new one. **Whether a further row is written depends on
which job the old row names.** The fixed run selects the **newest** terminal failed job
(`_terminalFailedJob`, `repair_stranded_work_items.dart:730-739`, sorted by `completedAt` descending);
the old key was consumed by whichever job was newest *at that time*. If the pre-existing old-key row
names the **first** failure — which is what "skipped recording the second failure" implies — the fixed
run writes a row for the **second** failure: a genuinely new row, i.e. **the fix working, not a
duplicate**. A further row for the *same* failure appears only if the old row names that same job.
**Which case the live item is in is not established from the durable rows** and is settled by observing
the `jobId` on the repair's `failure :` line. Any such row is truthful — the job really did fail — and,
unlike the old key, it does not permanently block the retry that follows it.

> **NOT YET RUN.** No run of the corrected script against any database has happened. The live item
> **remains stranded at `agent_executing`**. Running the corrected script is the outstanding,
> unproven step; nothing in this entry should be read as saying it already worked.

**Not changed, deliberately:** `StrandedWorkItemOutcome.qaContractId`, `.stateBefore` and `.notes` were
audited and are already truthful — all three are read back from the store rather than composed. The
`REFUSED`-with-no-durable-failure path still exits 0: it is loudly reported and was not in scope here,
so changing its exit semantics could break an operator's existing expectations. `qaContractAction`'s
`via-laneE:refused-or-absent` remains a deliberately vague label for the same reason.

**F-93 — `qaPassed` is deliberately held closed (`92d567e3`).** The only registered gate,
`intake-structured-result-admitted`, is structural. Substantive per-lane quality gates must be designed
first. **Consequence to expect: items accumulate at `review_approved`.** That is the accepted cost of
not rubber-stamping, not a regression. Slice 3's evaluator machinery may be built but must not be wired
to grant `qaPassed` until real gates exist. The structural gate must not be described as a quality
gate anywhere.

**F-94 — 49 orphaned pending decisions are a single batch and are already classified.** All 49 are
`infrastructure_decision`, all dated `2026-10-11`, all pointing at work items that no longer exist;
940 jobs still reference those ids. The Needs You surface already labels them `item_gone` and excludes
them from the actionable list, so they are **noise, not a block**. If they are ever to be voided, that
is a governance action on durable records and needs its own decision — deliberately not taken here.
Whether the 2026-10-11 deletions were intentional is **not determinable from the database** and was
not assumed either way.

**F-95 — `review_approved → qa_in_progress` still has no production caller.** Confirmed: the only
non-test references to `WorkItemState.qaInProgress` are `home_endpoints.dart:36` (a read filter) and
the state tables themselves. Blocked behind F-93 by design, not by accident.

**F-96 — push remains unauthorised, and that is not blocking the workflow.** `main` is hundreds of
commits ahead of `origin/main`. Every fix in this section was verified against the local QA stack, so
delivery is not gated on it. Recorded so it is not mistaken for an oversight. This is a delivery
matter reserved to the operator, not a flow blocker.

**F-97 — five sibling `bin/` scripts still apply migrations to the irreplaceable QA database.** See
F-84. Nothing invokes them today, so it is latent rather than active — but it is the same hazard that
destroyed the database once. Recommended as its own correction: a guard refusing non-disposable
`SERVERPOD_DATABASE_*` targets, **not** removal of `--apply-migrations`, which they legitimately need.

**F-98 — "STRANDED" in the repair's output is asserted, not derived.**
`apps/server/bin/repair_stranded_work_items.dart:700-708` and `:929-934`: the declined note and the
summary line both state "The item is STRANDED" / "STRANDED: `<id>` is still at `<state>`" regardless of
what `<state>` actually is. On the live run the declined path cannot fire (the item reaches
`agent_failed` before the retry), but a reachable case exists: if the newest terminal failed job already
carries a prior `requestId` action from an earlier run while its failure row sits under the OLD key, the
failure row is written, the item reaches `agent_failed`, and `operatorRetry` **replays** and returns it
unchanged. Exiting 1 is then conservative and correct, but "STRANDED" is a false label for an item an
operator retry would accept. **Fix by deriving the label from the state, or hedge the wording.** Same
false-claim class as F-92's other findings, left in place pending a follow-up correction.

## 31. The repair ran live and worked; the last stranded item moved, then stopped at a new gap

**F-92 resolved at runtime.** One deliberate run of the corrected script against live QA, output
verified against the criteria the focused review set:

```
[stranded.failure_recorded] jobId=jb-hnbbvl52jy-c1whpy kind=permanent
[stranded.retried]         state=design_not_required jobId=jb-hnbbvl52jy-c1whpy
  state   : agent_executing -> design_not_required
  recorded: true
  retried : retried: operatorRetry moved the item to designNotRequired
  1 of 1 item(s) changed.        exit=0
```
State moved, `recorded: true`, `retry_declined` absent, no `STRANDED:` line, empty stderr.

**B3 settled, in the better direction.** The run named `jb-hnbbvl52jy-c1whpy` = `2026-10-18 03:04:11`,
the **second/newest** failed job; the first was `jb-hnajiactyh-14p5mvo` = `2026-10-17 09:54:56`. So the
history now holds **two genuine** `agentExecuting → agentFailed` rows (`03:03:53` and `13:12:44`), each
followed by `agentFailed → designNotRequired`. **This is the fix working, not the duplicate F-92
predicted.** The old-key row named the first failure, exactly as B3's conditional predicted.

**F-99 — WITHDRAWN. This was NOT a defect; the item is correctly parked, and I mis-framed it.**
I recorded this as an open dispatch gap and told the operator "1 item remains stuck". **That was wrong.**
`DESIGN_GOVERNANCE_AUTOMATION_001` appears in the tree **only** inside
`lane_e_design_remediation_work_item.dart` as the *named* dependency — it is **not implemented anywhere**.
The item records `blockedBy: EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY`, and **ADR 0021
`docs/adr/0021-design-defect-routing.md:112` states the expected behaviour exactly**:

> "If `DESIGN_GOVERNANCE_AUTOMATION_001` is not yet implemented in shipit-platform, the boundary stops at
> WorkItem creation. The defect remains in `remediationPlanned` with a linked WorkItem **that cannot
> progress until the design governance runtime exists**. This is reported as
> `EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY`."

So **the absent job is the system working as designed.** The design-remediation lane deliberately refuses to
enter `designRequired` on a fabricated `designContractId`, and `designNotRequired` is documented in code as
"the honest terminal state of this flow until the design governance runtime exists"
(`lane_e_design_remediation_work_item.dart:20-21`). I spent a diagnosis pass hunting a dispatch bug that
does not exist, and recorded two unproven suspects rather than reading the ADR. **The correct lesson is the
one already recorded as F-85: verify against the governing document before writing a diagnosis down.**

What remains true and non-obvious: the item's `retry` path (`agentExecuting -> agentFailed ->
designNotRequired` via `operatorRetry`) *converges on the same terminal state*, so retrying a
design-remediation item is a no-op that will keep landing here. That is consistent with the ADR, but it
means **no amount of repair effort will move this item**, and the two documented facts — "terminal state"
and "an entry state of `triageDefectDefinition`" — sit in tension and should be reconciled by the design
lane, not by an operator retry.

Consequence, corrected: **all 3 originally-stranded items are accounted for** — 2 completed and reached the
human gate (pending decisions = 10), and the third is **correctly parked** on `ADR 0021`'s
`EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY`, which is a known, accepted, **permanent** block rather than a bug.
**Zero** job failures cite the QA-contract guard since `2026-10-18 03:10`.

## 32. Correcting the QA gate design's anchor — F-93 gained a named gate set, and F-93's blocker list changed

Added by lane `correct-DESIGN-REVIEW-3` (design correction, base `01b9fae`). Independent design review
of `design/qa-contracts-feature-remediation/substantive-qa-gates.md` revision 3 returned
`DESIGN_REVIEW_CHANGES_REQUIRED`. These are the findings that belong in this ledger rather than only
in the design artifact. **No production code was changed by that lane** — every item below is a
finding or a specification of work, not an edit.

**F-100 — `evaluator-spec.md`'s `qaInProgress -> qaPassed` anchor pointed at a DIFFERENT EDGE for
seven correction passes.** **NOW CORRECTED IN PLACE at base `01b9fae`; the ledger records the class,
because the instance is gone and the class is not.** The spec cited
`work_item_transitions.dart:690-696`; at `01b9fae` that range opens on
`(reviewApproved, qaInProgress)` — a real edge with **different guards**
(`actorAllowed([orchestrator])` + `qaContractExists()`). Correct ranges: `:732-738` (the edge),
`:733-736` (its `actorAllowed`), `:737` (`allRequiredGatesPassed`), `:739-744`
(`qaInProgress -> qaFailed`), `:751-757` (`(qaFailed, waitingForHumanDecision)`), `:693-696`
(`reviewApproved -> qaInProgress`, also stale at `:651-654`). `F-50`'s `:690` was corrected in the
same pass.
- **Why it survived: the file is 894 lines, so NONE of the stale ranges is out of bounds.** A range
  that resolves to *nothing* is caught by anyone who opens it. A range that resolves to *the wrong
  thing* is caught only by a reader who already knows the answer.
- **The durable lesson, and it is sharper than the finding: three passages of `evaluator-spec.md`
  AFFIRMED the stale ranges were correct** — "they resolve there exactly", "are correct there". **An
  affirmation outlives the file it was true of.** A pass that *fixes* a citation must not thereby
  *certify* it, and a pass that *finds* one has no licence to add a positive claim about a line number
  a later edit will move.
- **Recommended, and NOT done by this lane** (it is `design/**` + `docs/**`, and the check must
  compare what a range *claims*, not whether it exists): a repository check that every `file:line`
  citation under `design/**` and `docs/**` resolves **and carries the property claimed**. A grep finds
  an orphaned string; only opening the citation finds a range that resolves to the wrong thing.

**F-101 — the `platform_verified` evidence kind is a constant, so the gate built on it was a constant
too.** `PlatformVerification.evidenceKind` **defaults** to `EvidenceKind.platformVerifiedEvidence`
(`packages/platform_contracts/lib/src/types/platform_verification.dart:24`) and
`ExecutionCoordinator` never sets it
(`packages/execution_coordinator/lib/src/coordinator/execution_coordinator.dart:916-930`). The one
verification plan composed in production is `triageVerificationPlan` =
`git rev-parse --verify 'HEAD^{commit}'` (`apps/server/lib/server.dart:1578-1581`), attached to the
single coordinator every role drives (`:1638`). **So an implementation execution already writes a
row satisfying any "is this platform-verified evidence?" assertion — and
`execution_coordinator_test.dart:114` (role `implementer`) asserts exactly that and passes today.**
Compounding it: a gate's "bound to this execution" check is **unconstructible as a falsifier**,
because `readVerifications` filters by `executionId` in the query
(`apps/server/lib/src/persistence/postgres_execution_store.dart:331-339`) — the row "from another
execution" cannot be returned by the reader that would test for it.
- **Consequence for F-93:** the feature lane's `qaPassed` is held closed by **F4 alone** (the
  declared-command identity check), **not** by a "platform-verified evidence exists" gate. Anything
  downstream that reasons about how many gates hold `qaPassed` closed is working from a count that
  included a constant.
- **The agent's `claimedChecks` remains refused** — F-93's standing refusal, and `AGENTS.md` §12. Only
  the *reason* was wrong, not the refusal.

**F-102 — the two reads the substantive gates need DO NOT EXIST, and the substitutes that do exist are
truncated or blind.** `WorkspaceDelta.changedPaths` is **capped at 5**
(`packages/execution_coordinator/lib/src/coordinator/workspace_delta_probe.dart:160`, `:213-214`) and
is **`const []` on `WorkspaceDelta.committed`** (`:66`) — i.e. **empty on exactly the runs a
"did this lane commit?" gate passes.** `GitWorkspaceInspector.changedFiles` is uncapped but enumerates
`git diff --name-status <start>`, which **never lists untracked files**
(`packages/worker_runtime/lib/src/workspace/git_workspace_inspector.dart:57-64`; the trap is named at
`workspace_delta_probe.dart:127-133`). For a probe, a missed untracked file causes a spurious
failure; **for a path-confinement gate it is the opposite and worse failure — a brand-new prohibited
file is invisible and the gate passes.**
- **Needed, and specified but NOT built:** a `CommittedDiffPathCollector` returning the uncapped union
  of `git diff --name-only <start>..<produced>` **and** `git ls-files --others --exclude-standard`,
  failing closed if either cannot be read. **`packages/**` is out of scope for a design lane**; this is
  implementation work.

**F-103 — `WorkspaceDelta.headMoved == null` means "HEAD was never read", and two rules read it as
"HEAD did not move".** `GitWorkspaceDeltaProbe` short-circuits on a dirty tree and never reads `HEAD`
(`workspace_delta_probe.dart:199-217`), returning `headRevision: null, headMoved: null` (`:210-216`).
**A run that committed and left any untracked file therefore looks, to a `headMoved == true` check,
like a run that produced nothing** — and the resulting null `producedRevision` then trips a downstream
`nullRevisionIsFailure`. **This is the F-93 waiver-pressure mechanism appearing on the feature lane's
own commit gate:** a gate that fails every correctly-committing run whose author ran
`make clean` (a disarmed stub in this repository, so temp files are the norm) is a gate whose
operators learn to waive it.
- **Needed, and specified but NOT built:** an unconditional `git rev-parse HEAD` read returning a
  three-valued answer, consulted **before** deciding. `GitWorkspaceInspector` cannot be reused as-is —
  it throws `GitCommandException` and its `revision` is a non-nullable `String` that cannot express
  "unreadable" (`git_workspace_inspector.dart:7-15`, `:35`, `:106-115`).

**F-104 — `_declaredEvidenceTypes` returns `[]` for an ABSENT key, silently, and that is tested.** A
gate that declares no `evidenceTypes` is given an empty evidence requirement and the row reads as a
faithful copy of a declaration it is not
(`packages/qa_orchestration/lib/src/product_qa_contract.dart:168-171`; asserted at
`packages/qa_orchestration/test/product_qa_contract_test.dart:495-501`). `FormatException` fires only
when the key is **present and malformed** (`:172-189`). Worth knowing because
`GateEvaluatorImpl._validateEvidence` returns `evidence.isNotEmpty`
(`packages/qa_orchestration/lib/src/gates/gate_evaluator.dart:53-57`) over a list built by looping that
key (`:29-39`) — so the **fabricated pass is conditional**: declared ⇒ always passes; **absent ⇒
always fails.** Neither branch is a designed behaviour, and both are reasons F-93's slice 3a must
de-register the four evaluators rather than rely on them.
- **Open question, deliberately not answered here:** whether the platform *should* require the key.
  That is production behaviour on a governed provisioner and is F-93's implementer lane, not a
  finding.

**F-105 — two `required` `gateId`s exist for one gate type, and which contract carries which was never
written down.** `triage-classification-admitted`
(`packages/qa_orchestration/lib/src/lane_g_triage_qa_contract.dart:172-173`) and
`intake-structured-result-admitted`
(`apps/server/manifests/shipit-platform.product-manifest.json:45`) are both `required: true`, both
type `triage-classification-structure`, and **make the same assertion about the same document** — the
manifest says so in its own metadata (`:83`). Today they live in different contracts, so nothing
collides. **The moment one contract declares both, F-93's guard fix requires two results for one
structural check**, and the operator sees two gate ids to waive for one defect while the F-93 ledger
is keyed by gate id.
- **Convention recorded:** `intake-structured-result-admitted` is the **shipped manifest's**;
  `triage-classification-admitted` is the **remediation contract's**; **no contract may declare both.**

## 32. §7 C1 delivered; C2 blocked by my dispatch defect, and two adjacent holes found but NOT fixed

**F-106 — the guard's third and fourth instances of the same iteration shape.** `impl-G1` closed the
`allRequiredGatesPassed` hole (C1) and measured it across an 84-row contract×result matrix:
**PASS→FAIL 25, FAIL→PASS 0, unchanged 59**. But two adjacent defects of the *same* shape were found and
deliberately **not** fixed, because §7.4 specifies no fix and improvising one is not an implementer's
call:
- `requiresFormalDetermination` (`packages/qa_orchestration/lib/src/qa_orchestration.dart:67-81`)
  iterates `results` filtered by required gate ids, so a required gate with **no result** is silently
  absent from the determination list rather than named. **This is §7.4's third instance**, and §7.4
  names only two.
- A contract declaring **zero gates, or only `required: false` gates, still passes vacuously**: there is
  no required gate to be `notExecuted`, so the loop body never runs. **§7.2's table has no row for this**
  and §7.4 specifies no fix. (The zero-gates case is unreachable through the product path —
  `ProductQAContractSpecRefusal.declaresNoGates` rejects it at registration — but the **only-optional-
  gates** case may not be.)

**F-107 — both of the above are LATENT, not live, and must not be recorded as flow blockers.**
`isOverallPass` (`qa_orchestration.dart:83-100`) has **zero production callers** — only its definition and
10 test call sites. `requiresFormalDetermination` likewise. They become load-bearing only when the
determination lane is built. So fixing C2 is hygiene, not unblocking; the one **live** gate-status reader
is `allRequiredGatesPassed` on the `qaInProgress → qaPassed` edge, which C1 now makes fail closed.

**F-108 — `qaPassed` remains closed, and this was measured two ways.** C1 adds FAIL paths only, so
old-pass ⊆ new-pass; the 84-row matrix confirms **0 inputs newly reach `qaPassed`**. The guard is used on
exactly one edge (`work_item_transitions.dart:732-738`). The other `qaPassed` route,
`waitingForHumanDecision → qaPassed` (`:758-764`), uses `blockingHumanDecisionResolved` +
`decisionActorIsHuman`, never calls `allRequiredGatesPassed`, and is untouched.

**F-109 — a test that passed for two reasons at once.** `transition_test.dart:469-486` supplied **one
`failed` result for a two-required-gate contract**, so it failed both because the status was `failed` and
because the other required gate had no result — exercising neither in isolation, and structurally unable
to detect the hole. Repaired to supply results for **both** required gates, so the rejection is
attributable to the `failed` status alone; the subset case is then asserted separately. The repaired
assertion passes on **both** the pre-fix and post-fix trees, which is what makes it an honest regression
guard rather than a fix-detector.

## 33. §7 is CLOSED and independently approved (`d0525ad`) — plus three residual holes it surfaced

**Closed.** The invariant "a required gate with no result is `notExecuted`, not absent" is now enforced in
**both** readers (`allRequiredGatesPassed`, `isOverallPass`) in §7.4's order, fail-closed, with every §7.2
table row pinned in table order and non-vacuous (C1 6/12 pre-fix, C2 5/14 pre-fix, both reproduced).
**0 FAIL→PASS** on the guard, `transition.isValid` and `isOverallPass`; `isValid == guard` on all 85 rows;
**nothing newly reaches `qaPassed`**; the one live gate-status reader remains the guard on
`qaInProgress → qaPassed`. `isOverallPass` still has **zero production callers**.

**§7.4's "agree by construction" is met by CONVERGENT SHAPE, not shared code.** `_isGateSatisfied` and
`isGateSatisfied` are byte-identical after name normalisation, and the residual reader disagreement
(8/72 rows, all with `isOverallPass` permissive, never the reverse) is *exactly* the flagged product
decision. A shared helper was unavailable because `workflow_engine` and `qa_orchestration` do not depend on
each other and neither may gain one under the approved scope. A cross-reader equality test is therefore not
owed. One notch short of §7.4's literal words — recorded rather than glossed.

**F-110 — the absolute figures are NOT independently reproducible, and are not certified.** The lane
deleted its harness before commit, so `26→4`, `22 closed / 0 opened`, and C1's `25/0/59` **cannot be
derived** by a reviewer — they are matrix-dependent by construction. The reviewer's own 7×12 matrix yields
different absolutes. What IS certified is the §7.4 **property**, derived structurally and on an independent
harness. **Do not quote the absolutes as evidence.** A generalisable harness committed under
`packages/qa_orchestration/test/` would fix this class permanently.

**F-111 — MEDIUM, reachable TODAY — an all-optional-gates contract passes vacuously.**
`ProductQAContractDeclaration.declaresQAContract => gates.isNotEmpty`
(`product_qa_contract_spec_store.dart:96`) refuses only the **empty** list. A manifest declaring **only
`required: false` gates** passes registration, and `buildProductQAContract` builds a contract with
`allRequiredGatesMustPass: true` and **zero required gates** — which both readers report as an overall pass
with nothing evaluated. The refusal's own rationale says an empty list "constrain[s] nothing … the exact
fiction this route exists to avoid"; that reasoning extends to the all-optional case and is coded only for
the empty one. **F-106 hedged this as "may not be" — it is reachable.** Closest of the three residuals to
becoming live: it needs only a product manifest, no decision and no new component.

**F-112 — MEDIUM, pre-existing — the optional-failure threshold is skipped at its own default.**
`qa_orchestration.dart:122` gates the check on `optionalGateFailuresAllowed > 0`, and that field
**defaults to `0`** (`qa_pass_criteria.dart:12`). Measured: one required gate passing plus one **optional
gate failing** returns `isOverallPass == true`. Under the field's own name `0` means "none tolerated", so
the check should run. Latent because `buildProductQAContract` derives `optionalGateFailuresAllowed:
optionalCount` and triage sets `1` — but **the default is the unsafe direction**, and no test covers
`allowed == 0`. **This is a fourth vacuous pass in the very method §7 exists to fix**, so the residual-risk
list was incomplete.

**F-113 — LOW, product decision — `allRequiredGatesMustPass == false` short-circuits the required branch
entirely**, so `isOverallPass` returns `true` on 12/12 rows including the empty result set. It is the
**entirety** of the residual reader disagreement. Inert today: both shipped contracts set it `true`
explicitly, one with a written rationale (`lane_g_triage_qa_contract.dart:136-146`). **Deliberately not
pinned as a passing test** — a passing assertion reads as *intended* to the next maintainer; the reasoning
is recorded in the test file's header instead (`is_overall_pass_vacuous_pass_test.dart:23-32`). Needs a
product decision on whether the flag may exempt required gates from the missing-result check.

**F-114 — LOW — `qa_orchestration_test.dart` is structurally blind to this class.** All 10 assertions pass
identically before and after C2; every one supplies a result for every declared gate, so the case was
simply **untested**, not mis-written. **No edit is owed** — unlike F-109's `transition_test.dart` twin,
which genuinely passed for two reasons and was repaired. Recorded so the two are not confused.

**F-115 — PROCESS — a reviewer's `--exclude-tags=integration` burned 25 minutes.** `dart test test
--exclude-tags=integration` **does not exclude by directory**; it recursed into `test/integration/`, where
two suites each spent 12 minutes retrying `localhost:9099`. Nothing connected and nothing mutated, but the
instruction was explicit and was run anyway. This is F-86's automation gap with a cost: a **committed tag
or an explicit file list** is owed. Gate on an explicit file list until then.

## 34. Design governance runtime designed (`baa2248`, corrected to `696bcd9`) — findings routed

Decision `d41a6e85` chose to BUILD `DESIGN_GOVERNANCE_AUTOMATION_001`. Design revision 1 landed, was
independently reviewed (`CHANGES_REQUIRED`, 2 blockers), and revision 2 corrected it. Two operator
decisions closed the open policy gates (`a1c7d904`): **D4 — every revision HIGH until a `DesignRiskPolicy`
exists** (blocks only build step 5 of 10); **U-3 — a committed versioned JSON schema validated on write is
the machine-checkable fidelity anchor, Penpot is what a human reads and approves, and their disagreement
is itself a finding.**

**F-116 — three of my dispatch premises were WRONG; the design corrected all three.** "No wired
`JobDefinition` occupies `designRequired`" is false — `designRevisionDefinition` and `designReviewDefinition`
exist (`scheduler.dart:3255`, `:3269`), are exported, and are pinned by **14** test files. "Implemented
nowhere" is false — the **data layer is real** (four tables, `PostgresDesignGovernanceStore`, a contract
suite); only the **producer** is missing. "`designApproval` may need a new enum" is false — it exists and
all three choices are wired. The real gap is **callerless** (F-95's exact class), plus a missing producer,
composition root and approval raiser. **Check the tree before briefing a lane.**

**F-117 — G-7 is real and stronger than first stated: mounting the design scheduler alone does NOT fix
convergence.** `planned` is a `triageDefectDefinition` entry state with probe target `designNotRequired`
(`triage_defect.dart:119-135`), and the scheduler is category-blind, so the **triage** lane takes lane E's
parked item *out* to `designNotRequired` and re-dispatches forever. Corroborated twice more
(`planned_entry_state_hop_test.dart:48-50`, lane E's own comment `:172-176`).

**F-118 — R1 could not work, and no guard can replace it without a workflow-engine-wide signature change.**
`GuardCondition.evaluate` takes `(WorkflowState, WorkflowState, Map?)` (`guard_conditions.dart:141-145`) —
**never the `WorkItem`** — and the scheduler's context is a fixed `{agentAvailable, capabilitiesMatch}`
(`entry_hop.dart:118-121`). So **no guard can distinguish a remediation item from a feature item** as things
stand. R2 is promoted to primary; R1's lost-race behaviour is now specified (re-read, **never** re-drive
`designNotRequired → designRequired`, record terminal `blockedBy: DESIGN_GOVERNANCE_RACE_LOST`, never
report success).

**F-119 — the named failure mode to avoid: prescribing a fix the scheduler will not honour.** Revision 1
cited `scheduler.dart:3240-3246`'s "no change here" as authority for adding a `designRejected →
designRequired` edge, but `EntryHopper.prepare` reads `entryProbeTargets` **directly** and **refuses when
null** (`entry_hop.dart:181-195`) — the `probeTargetFor` fallback revision 1 assumed does not apply. Both
blockers were the same mistake: **the defect was found correctly and the remedy was not.** Revision 2 traces
the honour-chain per remedy, and that discipline falsified **two of its own draft assertions**.

**F-120 — D-4 is worse than stated: a vacuous test already claims coverage.**
`packages/scheduler/test/design_job_test.dart:614-698` is named
`'design revision maxAttempts=3 exhaustion triggers human decision'` and **creates, raises and asserts no
human decision at all** — it only asserts `RetryPolicy().canRetry(...)`. The exact vacuous-pass class §9
invokes and A7 forbids. Specified, not written (test source is READ-ONLY for design lanes).

**F-121 — five unvalidated blob columns, not four.** Q7 named four; `reviewScopeJson text` (nullable,
`migrations/20260920232118956/definition.sql:204`) is the fifth and equally unvalidated. This is why ADR
0021 §2's fidelity rule is currently **undecidable** — and it blocks switching the runtime **on**, not
designing it. Revision 2 specifies `design_revision_fidelity_anchor.schema.json` `$id` 1.0.0 with six
subschemas, `boardSet` requiring `providerFileId` (which closes the nullable-`penpotFileId` hole), and a
seventh rule JSON Schema cannot express: **`designerExecutionId ∉ reviewExecutionIdsJson`**.

**F-122 — D-5 is the most severe PRE-EXISTING defect: `designContractExists()` is satisfiable by any
string.** `guard_conditions.dart:146` is `context?['designContractId'] != null`, and `designContractId`
appears in `durable_workflow_engine.dart` only at `:59` (a `createWorkItem` param) and `:83` (the
assignment) — **never in a transition**. It is the root cause of lane E's refusal to enter `designRequired`
on a fabricated id, and it is **shared by every category**, not design-specific. Fixing it is build step 2
and is unblocked.

**F-123 — D-7 is the most severe GOVERNANCE defect: an accepted ADR names a method that does not exist.**
ADR 0021 §3 specifies `ControlPlaneService.createDesignRemediationWorkItem()`; no such method exists. An
accepted ADR and the code disagree. **A human-readable contradiction between two first-class records.**

**F-124 — D-1 makes the runtime's purpose unreachable.** `designRevisionDedupeKey` burns permanently, so
the correction loop — the entire reason `parentRevisionId` exists — cannot run. This is the same defect
`engineeringReviewDedupeKey` already fixed with an `:a<n>` suffix.

**F-125 — D-2/D-3.** `HumanDecisionType.designRejection` exists and is admitted by **nothing**; reaching for
it yields a decision resolving to no target (`human_decision_routing.dart:152` falls to `_ => null`).
`escalationIndexWithinLimitForDecisionTypes` is unbounded (`guard_conditions.dart:542` `?? -1`, `:544`
`maxEscalation >= 0 &&`) with its sole supplier hard-coding `-1`
(`durable_workflow_engine.dart:1047-1052`).

**F-126 — a citation correction worth carrying forward.** The design attributed "§9.6" to **ADR 0021**,
which has **sections 1–8 only**; it is **checkpoint 003 §9.6**. ADR 0021's own Consequences (`:166`) carries
the substance, so the decision survived a citation that does not resolve. Recorded now because it is the
fourth instance of the stale-anchor class (F-100) in a file nobody had cited as stale.

**Build-order note for the lanes that follow:** steps 1–2 are unblocked and safe now — the
`design_contract` migration + `DesignContractStore`, and changing `designContractExists()` to read the
durable column (F-122). Step 4 (the fidelity anchor) is unblocked by `a1c7d904`'s U-3. Step 5 alone is
blocked by D4's **ratification** only, and only its activation step. Steps 3, 6–10 wait on the design
clearing re-review.

## 35. A premise I stated to the operator as fact was FALSE — correction, and what survives

**F-127 — I told the operator the design revision's JSON columns have "no schema and no validator
anywhere in the tree, confirmed by exhausting it." That was wrong.** Verified directly:
`schemas/design_revision.schema.json` **exists**, is committed (4018 bytes), declares **all six** blob
columns (`boardIdsJson`, `responsiveTargetsJson`, `statesRepresentedJson`, `artifactRefsJson`,
`reviewScopeJson`, `reviewExecutionIdsJson`; five in `required` at `:8`), carries
`additionalProperties: false` at `:7`, and is **validated green** by
`packages/platform_contracts/test/contract_schemas_test.dart:585` — *"DesignRevision.toJson() conforms to
design_revision.schema.json"*. Two independent review rounds repeated the false premise before one
falsified it in a single grep.

**How it happened.** The design lane asserted "no schema, no validator"; the first design review
**confirmed** it "by exhausting the tree"; I repeated it to the operator as the premise for decision
`a1c7d904`'s U-3 branch. **A claim that two reviews agree on is not thereby verified** — the agreement is
correlated, not independent. The falsifying check was one `ls schemas/` and one `grep`.

**F-128 — what SURVIVES, and the decision stands.** The *operative* conclusion is unchanged: the blobs
are declared as bare `"type": "string"` with only prose descriptions, so their **content** has no
parseable contract and ADR 0021 §2's fidelity rule stays **undecidable**. `a1c7d904`'s selection —
committed versioned JSON schema for machines, Penpot for humans, disagreement is a finding — is
**correct** and is **not reopened**. `boardSet.minItems: 1` plus required `providerFileId` still closes the
nullable-`penpotFileId` hole. **Only the justification and the schema's placement were wrong.** The
operator's decision was made on a partly false premise but reached a sound conclusion; the correction is to
the record, not to their choice.

**F-129 — the remedy's PLACEMENT was wrong too, and it is load-bearing.**
`design-revision.md` §3.5.1 proposed `docs/engineering/schemas/design_revision_fidelity_anchor.schema.json`.
`docs/engineering/schemas/` **does not exist**; **all 50** committed schemas live in one root, `schemas/`
(verified by counting every `*.schema.json` outside `.git`); and `contract_schemas_test.dart:8` hardcodes
`const _schemasRoot = '../../schemas'` and loads by bare name — so a document at the proposed path is
**unreachable by the tree's own harness**, producing "a validated-looking but unvalidated" document,
which §3.5.3 itself warns against. Splitting one type's contract across two independently-versioned
documents with no `$ref` also regresses a convention that is otherwise uniform (44/50 declare
`additionalProperties: false`; `design_review_result.schema.json` carries the same free-form
`reviewScopeJson`). **Required:** place the anchor as `$defs` + `$ref` inside
`schemas/design_revision.schema.json` (or at `schemas/design_revision_fidelity_anchor.schema.json`) and add
it to `contract_schemas_test.dart`'s `const schemas` list so it is **loaded and exercised**.

**Build-order, re-derived from this review (`696bcd9`).** SAFE NOW, in §9's order, no step skipping a
predecessor: **step 1** (`design_contract` migration + `DesignContractStore` + builder); **step 2**
(`designContractExists()` reads the durable column — F-122, the shared-by-every-category root cause);
**step 3** (`designParked` + R2.1/R2.2/R2.4 edges — BLOCKER-1's verified remedy, adding the
`WorkItemWorkflowState.allowedTransitions` mirror in the same change); **step 7** (`designRejected →
designRequired` edge **AND** `entryProbeTargets {designRejected: designRequired}`, both, never one —
verified against the drift guard, which it activates rather than breaks); **step 10** (D-1 dedupe suffix at
`scheduler.dart:3284-3285`, and rename-or-complete the vacuous `design_job_test.dart:614-698`).
**BLOCKED by F-129:** step 4. **DEFERRED by D4:** step 5 (HIGH-by-default needs no policy call).
**DEPENDENT:** steps 6, 8, 9. **Switching the runtime ON remains blocked** and nothing here unblocks it.

## 36. Design runtime steps 1–2: correctly blocked twice — on MY dispatch errors, not on decisions

**A cancelled lane left unverified work in the tree, and it regressed tests.** A previous dispatch for steps
1–3 was cancelled mid-flight, leaving 206 insertions across 5 files with **no tests, no migration and no
store**. It broke **6 existing `workflow_engine` tests** (`+139 -6`). I reverted it by **explicit path**
(never `git checkout .`), confirmed the suite back to **209/209 green**, HEAD and both stash entries
intact. **A cancelled lane's output has no provenance and cannot be committed — check the tracked tree before
dispatching anything.**

**F-130 — `designContractExists()` (D-5/F-122) is confirmed LIVE, with a measured probe at HEAD.**
`D5_PROBE outcome=ACCEPTED state=design_required column=null` — the transition is **accepted** with a NULL
contract column and no contract row. Not assumed; measured.

**F-131 — step 1 cannot be a migration alone: it needs a Serverpod model.**
`design_contract` requires `apps/server/lib/src/database/design_contract.spy.yaml`; Serverpod derives
`definition.json` from `.spy.yaml` models, so a table with no model cannot be expressed. The tree has
**exactly one** unmanaged precedent — `product_qa_contract_spec` (`"managed": false`) — which
`pubspec.yaml`'s `serverpod:migration` note describes as **erasable on every regeneration**, guarded by
`verify:schema-deviations` for three named patterns that do **not** include `design_contract`. The lane
**refused** to hand-roll that path, correctly: a hand-written `CREATE TABLE "design_contract"` collides with
the next `serverpod create-migration` **on a live, irreplaceable database**. **Not a decision — a dispatch
defect. Re-partitioned, not escalated.**

**F-132 — step 2's blast radius is at least 44 regressions, 30 of them outside the dispatch's ownership.**
Measured with a temporary patch, byte-copied, `shasum`-verified, format-gated before counting: `scheduler`
430→402 (−28), `workflow_store` 61→47 (−14), `workflow_engine` 209→207 (−2). **A lower bound** — step 2 also
requires store confirmation, which is stricter. **And the revert stayed green, which is what makes the count
non-vacuous.** Mitigating fact: **zero production callers transition TO `designRequired`**, so closing the
edge removes a fabrication path and breaks no working path.

**F-133 — §4.6's cited line numbers have drifted.** `lane_e_design_remediation_work_item.dart` constants are
at `:10,15,18,22,26` and writes at `:575,:643-645`, not the `:23,41-42` the design cites. Fifth instance of
the stale-anchor class (F-100, F-126) — **in a design revision that just passed review with no blockers.**
The dependency itself is verified unweakened; only the citation is wrong.

**F-134 — `platform_contracts` is RED at HEAD**, measured not assumed: `serialization_test.dart:420` expects
26 `WorkItemState` values, actual 27. Stale from whichever lane added `implementationReady`. Any "no other
package may regress" gate is therefore measured against a **red baseline** — and the count is one away from
becoming red for a *new* reason when `designParked` lands in step 3. **Fix the count before step 3**, or step
3's new state will be blamed for a pre-existing failure.

**Runtime remains OFF, verified in the composition root.** `apps/server/lib/server.dart` mounts only
triage / implement / engineering-review. `designRevisionDefinition` and `designReviewDefinition` are
**exported** (`scheduler.dart:31-32`) but **never mounted**.

## 37. §9 step 1 implemented (`b661c07`) — and the generator silently erased a table

**F-138 — the authorised generator SILENTLY dropped `product_qa_contract_spec` from every generated
definition.** Running `serverpod create-migration` rebuilds each `definition.sql` from the models, and
`product_qa_contract_spec` is declared in **no** model — it survives only as a `"managed": false` entry in
the previous `definition.json`. Measured: 54 tables → 55 with the table **gone**, and it was already absent
from the three prior `definition.sql` files, so the last migration's copy was a **hand-append**. The
chain-migrated path was unaffected (its DDL lives in `20261017102506000`), which is exactly why it was
silent. **A fresh database would have had no `product_qa_contract_spec`, while
`PostgresProductQAContractSpecStore` binds parameters to it.** Restored byte for byte and now guarded by a
test that fails if it is ever erased again. **The generator-side guard still does not exist** — adding
`CREATE TABLE "product_qa_contract_spec"` to `verify:schema-deviations` would make the erasure fail closed
rather than needing a human to notice. That script is in `pubspec.yaml`, which the lane does not own.

**F-139 — an unmanaged table can be erased by regeneration, and no guard names it.**
`verify:schema-deviations` checks 3 patterns and `verify_schema_bootstrap.sh` checks 4 hand-maintained
objects; **neither names this table.** New test coverage exists, but a test is not a generator guard — the
erasure would still succeed and merely fail CI afterwards.

**F-140 — `serverpod create-migration` opens NO database connection; only `create-repair-migration` does**
(verified in `serverpod_cli-3.4.13 lib/src/migrations/generator.dart`). So it is safe to run against a repo
whose development config points at a live stack — which is why this lane could generate safely with a
deliberate port-1 fail-safe and touch no database. Also: the generator's `managed` filter excludes unmanaged
tables from **both sides** of the diff, so an unmanaged table is never dropped from an existing database —
its only casualty is the fresh-database `definition.sql`.

**F-141 — three GREEN REVERTS were found and closed, all of them real defects in the new tests.**
(A) Reverting `InMemoryDesignContractStore` to return its argument instead of the read-back row left the
suite green — two fakes proved the *provisioner* uses the read-back value while nothing held the **shipped**
implementation to it. (B) Case-folding `designContractIdForWorkItem` left it green because every fixture id is
already lower-case, so purity and impurity coincided — and work-item ids are minted with an upper-case
prefix by more than one lane, so the collision is constructible. (C) **A raw-string regex in the lane's own
new migration test** made `$table` four literal characters, so inserting a real `INSERT INTO
"design_contract"` stayed green; fixing it exposed **three more** of the same class. **A reverting mutation
that stays green is the finding, not a nuisance** — three of twenty-two were missed-adjacent defects here.

**F-142 — step 1 is a DESIGN CONTRACTION, named by the lane rather than hidden: `DesignContractStore` has NO
durable implementation.** The interface and an in-memory impl exist; `PostgresDesignContractStore` belongs in
`apps/server/lib/src/persistence/`, **outside this lane's grant**. §4.3 requires step 2's guard to confirm the
contract "against the store" — against an in-memory store that check is **not durable**, so **step 2 cannot
be honest until that path is granted.** This is a dispatch defect (mine), not a decision.

**F-143 — the builder has no production caller.** Wiring it into
`DesignRemediationWorkItemProvisioner.ensurePersisted` is step 3, in `apps/server/lib/src/triage/` — also
outside this grant. Step 3 still owns `WorkItemState.designParked` + R2.1/R2.2/R2.4, and R2.3's release stays
blocked until step 2 lands.

**The builder's refusals are the notable part.** Every value it does **not** declare is a refusal to
fabricate, stated in-source so a reviewer can check it: `requiredArtifacts` names the design_revision record
and records `validationSchema: null` as a **named absence** (`requiredArtifactSchemas: 'absent'`), not a gate
nothing runs; `reviewers` carries the designReviewer **role** wire with **no identity**, because identity is
not knowable at creation; `approvalThreshold: 1` is **artifact approval only**, because the risk-tier human
gate is a separate authority whose tier is unresolvable while `DesignRiskPolicy` is absent; and
`submittedArtifacts`/`decisions`/`expiresAt` are `null`, meaning **"not yet"** rather than **"nothing."**
`status` is deliberately a plain `String`, not a generated Serverpod enum, because
`platform_contracts.DesignContractStatus` is the authority and a second enum would be a second vocabulary.


### §37 review outcome — `APPROVE_CORRECTIONS`, with a MERGE CONDITION

Verified independently at `ac037db`: the `product_qa_contract_spec` restoration is byte-correct across all
three artefacts (`cmp`-identical, 2608-character blocks), its guard test is non-vacuous (2 tests red on
erasure), and **nothing else was lost** — a full table-set diff across every `definition.sql` and both JSONs
gives exactly `+design_contract` with `removed: []` and `changed entries: []`. 32 mutations measured
independently, **zero vacuous**. All three green reverts reproduced. The generator's no-database claim is
confirmed: `getLiveDatabaseDefinition()` occurs **exactly once** in `serverpod_cli-3.4.13`, at
`generator.dart:187` inside `repairMigration()`. All four builder refusals judged **honest** — none is a
fabricated value wearing a refusal's clothes.

**F-144 — the `product_qa_contract_spec` erasure is CERTAIN, not merely likely.** `postgres.dart:58` renders
`tables.where((table) => table.managed != false)`, so **an unmanaged table can never appear in a generated
`definition.sql`** — by construction, on the next `create-migration`. The fresh-database path is exactly as
correct as before the commit (no regression), and the erasure is now *detected* rather than silent, so this
is **HIGH and non-blocking**. Two remedies already exist in this repository and **neither was applied**:
`verify_schema_bootstrap.sh:503-504` says in terms *"A hand edit there is erased by the next regeneration.
Put the DDL in `tool/schema_bootstrap.sql` instead"*, and the new
`design_contract.spy.yaml:11-14` names this table as the precedent for the fragility. **Fix: either add
`apps/server/lib/src/database/product_qa_contract_spec.spy.yaml` as a managed model, or move its DDL into
`apps/server/tool/schema_bootstrap.sql` and add the table to `verify:schema-deviations`.**

**F-145 — a durable record must carry the full ledger, not the headline.** §37's F-141 says "3 of 22
mutations stayed green". The lane disclosed **two further mutations rejected as format-dirty** and re-measured
with format-stable equivalents (both RED) — and the reviewer independently confirmed both rejections were
real (`format-clean=False`). **That accounting is absent from the durable entry.** An unexamined "green" is
what this discipline exists to catch, so the record of what was *discarded* matters as much as what was found.

**F-146 — LOW, introduced by review: an interface promise its only implementation does not keep.**
`design_contract_store.dart:81` documents `listDesignContractsForWorkItem` as returning **oldest first**;
`in_memory_design_contract_store.dart:56-60` returns map insertion order. Constructible and pinned by no
test: a `LinkedHashMap` overwrite keeps the original position, and descending-`createdAt` inserts read
newest-first. A future `PostgresDesignContractStore` ordering by `createdAt` would silently disagree.

**MERGE CONDITION — step 1 is a CONTRACTED PARTIAL, not complete.** `§4.2(a)` is headed "**A durable** design
contract", and §9's own justification for step 2 is *"Without it, step 1's row and a fabricated string are
indistinguishable."* What exists is a table with an interface and an in-memory implementation and **nothing
durable**. Against that, §4.3's store-confirmation is **not durable** and **step 2 cannot be honest** until
`PostgresDesignContractStore` is granted in `apps/server/lib/src/persistence/`. **F-142 was a dispatch defect,
not a decision.**

### §37 step 1B — durable store landed (`868854d`), merge condition DISCHARGED

`PostgresDesignContractStore` mirrors **`PostgresQAContractStore`**, not `PostgresDesignGovernanceStore` —
same problem shape (text-keyed, JSON-in-`text`, `provision*` = write→read→throw `StateError`,
`ON CONFLICT ("contractId") DO UPDATE`, `_asJson` normaliser, `decodeUtc`). The decisive fact neither the
lane nor I had: **`PostgresQAContractStore` is both mounted AND executed**, so every borrowed idiom is
execution-proven — the strongest mitigation available for a file that is not itself executed.

**F-147 — `DesignContractStatus` has NO public wire mapping; this is now load-bearing.** Both
`_designContractStatusFromJson` and `_designContractStatusToJson` are **file-private**
(`platform_contracts/lib/src/types/design_contract.dart:66-76`), and `underReview` → `under_review` is
private. The store therefore routes `status` through `DesignContract.toJson()/fromJson()` and nowhere else,
because a hand-written pair would be the **second vocabulary** `design_contract.spy.yaml` warns against and
could drift with **no failing test** — nothing in this repo may assert against a private function. Verified:
zero hand-written mapping anywhere in the store, and the generated call sites route through those private
functions.

**F-148 — the tie-break's comparators are NOT provably identical.** `postgres_design_contract_store.dart:167`
orders by the **database's** collation; `in_memory_design_contract_store.dart:87` uses Dart's **UTF-16
code-unit** order. No `COLLATE` in any migration, no `LANG`/`LC_COLLATE` in compose, so the default governs —
and under `en_US.UTF-8`, ids differing only in case sort **opposite** to Dart. **Reachability today is nil**:
`designContractIdForWorkItem` is pure, so contracts for one item share a `contractId` and both stores key on
it. The suite's tie-break ids are lowercase ASCII, so a Postgres runner would not catch it either. Remedy:
state the assumption and the reachability limit at `design_contract_store.dart:103-107`, or pin
`COLLATE "C"` if a runner ever exercises it.

**F-149 — the proposed "every `Postgres*Store` has a runner" guard is NOT currently satisfiable.**
Enumerating all 18, it fails on **three pre-existing stores** besides the new one:
`PostgresEngineeringReviewResultStore` (0 references outside its own file and the barrel),
`PostgresQAReviewResultStore` (0), `PostgresModelPolicyStore` (mounted, 0 tests). **This is the fourth
instance, so it is a four-store remediation, not a one-liner** — size it before authorising.

**F-150 — a durable IMPLEMENTATION is not a durable contract IN USE.** The new store is **unmounted**
(`persistence_exports.dart` has **zero importers**, verified) and **unexecuted**; `designContractExists()` is
still `context?['designContractId'] != null`. So step 1's row and a fabricated string remain indistinguishable
**at the transition boundary** — which is precisely §9's stated reason step 2 exists. Accepted to land because
its blast radius is zero, its idioms are proven in the mirrored sibling, and holding it would block step 2 on
a sequencing technicality. The refusal to add a text-shape test to paper over the gap was **correct** — that
is exactly the D-4 shape at `design_job_test.dart:614-698` (F-120).

**Step 2 may proceed.** It needs all four of: (1) `designContractExists()` reading the durable column via an
**injected** `DesignContractStore` — a **signature** change, not a body change; (2) **mounting** the store in
the composition root, since the barrel will not do it; (3)
`apps/server/test/integration/design_contract_postgres_test.dart` running `runDesignContractStoreSuite`
against a real database — the gate that turns "compiled" into "executed"; (4) the `FOLLOW_UPS.md` ledger
entry, which this entry is. **Not assumed done:** F-143 — `DesignContractBuilder` still has **no production
caller** (step 3). A store nobody provisions is a table nobody fills.

### §9 step 2 — D-5/F-122 CLOSED (`384a3d1`), `APPROVE_CORRECTIONS`, no regressions

`designContractExists()` no longer reads `context?['designContractId']`. Verified by **independent mutation,
not claim**: reverting the guard reproduces `planned -> designRequired was ACCEPTED with no contract behind it`.
At HEAD the edge is refused and the item does not move.

**F-151 — the mechanism, and why the offered signature change was correctly DECLINED.**
`DurableWorkflowEngine` gains an optional `DesignContractStore`, resolves
`WorkItem.designContractId` + `store.hasDesignContract(id)` into a `DesignContractResolution`
(`contractId != null && storeConfirmed`), and writes it under a reserved context key **unconditionally after
the caller's spread** — so planting the key is inert **by ordering**, and exactly one production writer
(`:207`) and one reader (`guard_conditions.dart:170-172`) exist. The same idiom is already house style
(`transition_validator.dart:72` writes `'actor'` after the metadata spread). Three narrower routes were
rejected and all three rejections are real: the guard is constructed at one site inside a `static final`
table at `work_item_transitions.dart:26` (**step 3's file**); `workflow_store` depends on `workflow_engine`,
so the guard cannot take the store without a cycle; and `GuardCondition.evaluate` is synchronous against
`Future<bool>` — async would mean `Future<GuardResult>` across all 20 guards **and still would not supply the
`WorkItem` (F-118)**, so §4.3's *column* half would remain unimplemented. **The lane took permission for a
repo-wide change and declined it. That was right.**

**F-152 — all 53 regressions asserted the DEFECT, not the requirement.** Diff removes **0** `expect(` lines,
**0** test/group declarations, adds **0** skips/tags; nine sites sampled across three packages all assert the
requirement. `planned_entry_state_hop_test.dart:753` keeps its `isTrue` **strengthened** to a confirmed
resolution and **gains** a new `isFalse` naming §4.3's falsifier, with the residual routing observation
preserved byte-for-byte. 4 mutations measured, **0 green reverts**, nothing discarded.

**F-153 — a PRECONDITION for step 3, not a follow-up: the runner must be EXECUTED before the first
production `designContractId` is written.** `design_contract_postgres_test.dart` is written, analyze-clean
and **UNEXECUTED**, and step 2's discharge condition item (3) required it *running* — **that condition is
UNMET**. It was acceptable to land unmounted-risk-zero at this HEAD because **no production caller of
`createWorkItem` ever passes `designContractId`**, so `_resolveDesignContract` short-circuits at `:327` and
never issues a SELECT. **The argument degrades at step 3:** once lane E provisions contracts, every
transition on a contract-bearing item hits the unverified query, and `:325` **deliberately lets a store
exception propagate** — so a schema mismatch would refuse transitions for **every category**. A failure mode
F-150 did not carry when it accepted the store unmounted.

**F-154 — the runner is currently un-runnable, and the blocker is a pre-existing migration bug.**
`make test-integration` is red at HEAD (migration `20261017102506000`, **42P07**: it creates
`"id" bigserial PRIMARY KEY`, which Postgres names `product_qa_contract_spec_pkey`, then immediately
`CREATE UNIQUE INDEX IF NOT EXISTS "product_qa_contract_spec_pkey"` on the same table). The QA database is
unaffected because it recorded that migration as applied; **only the fresh-database path fails.** So the
sanctioned disposable-Postgres route — the only sanctioned way to get a real database — is broken, and the
durable store's only execution gate cannot be run. **Fix this before step 3**, not after.

**F-155 — a third engine wiring site, missed by both the lane and my own brief.**
`apps/server/lib/src/services/control_plane_service.dart:115-116`,
`apps/server/bin/repair_stranded_work_items.dart:884-887`, **and `packages/scheduler/lib/src/scheduler.dart:573`
(`_reclaimEngine`, also the `EntryHopper`'s engine at `:596`)** all construct engines with **no**
`designContractStore`. All three are fail-closed and correct today — no production caller transitions TO
`designRequired` — but once R2.x lands, the unmounted sites stop being harmless and start **refusing for the
wrong reason**. Site (1) is the one lane E's release writes through. **Step 3 must own all three.**

**F-156 — adjacent fabrication surface, pre-existing, outside §4.3.**
`_DesignContractUnderReviewGuard` (`guard_conditions.dart:202-220`) reads a caller-supplied
`context['designContractStatus']` on `designRequired → designInReview` — **the same class of defect D-5 was**,
on the adjacent edge. Unchanged by step 2 and not in its scope; belongs to step 3 / §8.1.

**F-157 — LOW, pre-existing.** (a) An ACCEPTED `planned → designRequired` record captures no confirmed
contract id, so it does not record *which* contract was confirmed. (b) The `server.dart:249` mount is
unguarded by any test — `composition_wiring_test.dart` never mentions `DesignContractStore`, so removing it
would be silent. (c) `guard_conditions.dart:172` `as DesignContractResolution?` throws on a wrong-typed
planted value in the pure-policy path; it cannot produce a pass and no production caller plants the key.

## 38. Integration testing is UNBLOCKED — and immediately revealed the step-3 precondition failing

**`make test-integration` now runs.** For the first time in this repository's recorded history it gets past
schema application and executes test code: **287 tests, 22 failures**, on a disposable Postgres it creates
and removes correctly (`shipit_integration_<pid>` container + data + network all removed, every run). The
42P07 blocker (F-154) is **fixed at both sites** — `20261017102506000/definition.sql:692` (`15d05ca`) and
`20261018180816929/definition.sql:715` (`6cf3714`) — and a generalised repo-wide sweep of all 27
`definition.sql` files found **exactly one** collision, now removed. The colliding index was proven
**redundant, not a second constraint** (`"isPrimary": true` in the generated `definition.json`, same single
column `("id")`, same uniqueness, no predicate; the genuine second constraint
`product_qa_contract_spec_product_unique` on `("productId")` is untouched) — removal, not rename, because a
rename would leave a permanent duplicate of the PK index.

**F-158 — the fresh-database and chain-database paths take DIFFERENT files, and that asymmetry is the whole
bug.** `definition.sql` is applied **only** when no migration version is recorded
(`serverpod-3.4.13 migration_manager.dart:194-205`); a chain-migrated database replays each `migration.sql`.
Corroborated in-repo at `schema_bootstrap.dart:6-9` and `verify_schema_bootstrap.sh:45-50`. **That is why QA
never failed**: it recorded the migration as applied, and `20261017102506000/migration.sql:74` carries the
same statement **with `IF NOT EXISTS`** — a no-op on the chain path. Only fresh databases hit the bare form.
This also means **no `migration.sql` was edited, so the QA database's schema is untouched.**

**F-159 — STEP 2'S GUARD IS WORKING, AND IT IS NOW REACHABLE-FEEDBACK.** The dominant new failure is exactly
the fail-closed refusal F-153 predicted:
> `Workflow transition rejected: WorkItemState.planned -> WorkItemState.designRequired (The work item names
> design contract dc-wi-lifecycle, and that id was not confirmed against a design contract store: either no
> store is mounted to ask or the id resolves to no row)`

`design_governance_e2e_test.dart` constructs engines with **no** `designContractStore` — F-155's three sites,
plus test-local engines. **This is correct behaviour, not a regression**: those tests were asserting
`planned → designRequired` succeeding on a context-supplied string, which is the defect D-5 removed.

**F-160 — WITHDRAWN. The precondition is MET; my "FAILING" claim was wrong.** I read `dart test`'s **compact
reporter status line** as evidence about the file named on it. That line names the file in `setUpAll` while
**sibling files increment the counter underneath it**, so the name and the counter belong to different files —
which is exactly the `+25 -1, +25 -2, +25 -3` signature I mistook for a silent boot failure.
Measured three times against the disposable database:
`dart test test/integration/design_contract_postgres_test.dart` → **exit 0, +10, "All tests passed!"**.
**A genuinely failing `setUpAll` is reported with `[E]`; this file appears in no such line in any run.** Boot
cost is ~2 s. Non-vacuity: reintroducing F-146 (`ORDER BY … DESC,DESC`) → `+8 −2`; making
`saveDesignContract` a no-op → `+1 −9`, so 9 of 10 assertions bind to real Postgres rows (the tenth is
"an unwritten id reads back null", the one assertion a store that stores nothing satisfies — correct by
construction). **A doc comment claiming the suite opens a store "per test, which is twelve of them" was wrong
(it is ten) and is corrected.** The lone other change: a false statement.

**This is the same lesson as F-127 and F-85, now in a third form: a status line, a claim two reviews agreed
on, and an over-claimed runtime diagnosis were each accepted as evidence. Run the single file before
concluding anything about it.**

**F-161 — a second, unrelated failure class surfaced: `dogfood_shipit_postgres_test.dart` throws
`PathNotFoundException` for `apps/control_plane/lib/features/defect_report/`** inside a temporary checkout
(`/var/folders/…/shipit-head-*/…`), from `ReadOnlyRepositoryReader._walk`
(`product_registry/lib/src/discovery/read_only_repository_reader.dart:90,96`). That directory does not exist
in the temp copy. **Pre-existing and environmental**, not caused by any lane here.

**F-162 — `make test-integration` needs `SERVERPOD_DATABASE_PASSWORD` set and does not fail clearly without
it.** The Makefile sets host/port/name/user but not the password; the expected value is the `test:` profile's
`database` in `apps/server/config/passwords.yaml` (`control_plane_test_pw`). Without it the target aborts with
a bare `SERVERPOD_DATABASE_PASSWORD is not set` and **exits 0 through the pipeline**, so a caller piping to
`tail` sees a green-looking run. It does clean up correctly on that path. **A guard or a clearer failure is
owed**, and note the AGENTS.md rule that a cleanup failure must never be silenced — here the *setup* failure
is the thing being lost.


**F-163 — the 21 integration failures, classified.** `make test-integration` = **+288 −21** (not 22; the
`dogfood` PathNotFound and the phantom design_contract boot failure did not occur in five runs).
- **11 caused by this work, one class, and CORRECT:** `design_governance_e2e_test.dart` ×5,
  `endpoints_persistence_test.dart` ×4, `triage_execution_test.dart` ×1, `e2e_restart_persistence_test.dart` ×1
  — all `DurableWorkflowEngine(store:)` constructed **without** a `designContractStore`, correctly refused.
  **This is F-155, and step 3 must mount the store at all three sites.**
- **Genuinely broken, pre-existing, other lanes:** `product_qa_contract_spec_postgres_test.dart` ×3 — AC-2
  asserts `LIKE 'qa-spec-it-%'` but ids are `'qa-product-$workItemId'`
  (`qa_orchestration/.../product_qa_contract.dart:50`), so the count is **structurally zero**;
  `product_credential_immutability_postgres_test.dart` ×2 — migration `20261014130500000`'s own guard at
  `migration.sql:448`.
- **Intermittent:** `product_credential_immutability_postgres_test.dart` "D-4 under concurrency" fails in
  **2 of 5** runs — a genuine two-mint race against a single asserted refusal message. Pre-existing.
- **Pre-existing stale:** `feature_request_intake_test.dart:121` expects `draft`, gets `feature_intake_parked`
  (state added by `ddfbfff`); `lane_f_production_reachability_test.dart:1577` expects an unhandled async error
  and gets none; `triage_execution_test.dart` ×2 expect `succeeded`, get `failed`;
  `execution_store_roundtrip_test.dart` maps `AgentSessionStatus.failed` → `agentFailed`
  (`local_worker.dart:346`).

**F-164 — every Serverpod boot prints a schema-mismatch warning that is not caused by this work.**
`Missing Index design_revision_approved_unique_per_work_item` and
`product_credential_active_repository_unique`. Both indexes exist **only** in `tool/schema_bootstrap.sql` and
in **no** `definition.sql`. Non-fatal, pre-existing, and **not** caused by the 42P07 fix — that deleted only
the `product_qa_contract_spec_pkey` line. Route to the migrations lane.

**F-165 — `product_qa_contract_spec` survives only as a hand-append after every regeneration, and the
generator re-emits the colliding statement each time, so removal alone does not prevent recurrence.** Only
the new guard detects it. The durable fix is F-144's: make it a managed model, or move its DDL into
`tool/schema_bootstrap.sql` and add it to `verify:schema-deviations`. **Needs an owner.**

## 39. §9 steps 1–3 COMPLETE and independently verified — the runtime is still OFF

**Steps 1, 1B, 2 and 3 are landed and `APPROVE_CORRECTIONS` with no regressions.** Step 3 (`44c8d0b`, 19 files,
+1438 −56) added `WorkItemState.designParked` with all three exhaustive-switch obligations, the R2.1/R2.2/R2.4
edges, R2.3's release, the builder wiring (F-143), and mounts at all three engine sites (F-155).

**F-166 — integration, the change's strongest evidence, reproduced twice.** `make test-integration`
**+287 −22 → +299 −10**: the reviewer set-differenced the `[E]` lists of two full runs — **12 cleared, 0 new**.
Teardown clean on both (container + network removed, **no `CLEANUP FAILED`**, compose project
`shipit_integration_<pid>` only, **QA project `docker` never addressed**).

**F-167 — the modified test did NOT move a goalpost, and the proof is not the assertion text.**
`triage_execution_test.dart` had exactly **one** `expect(` removed and **+70/−1** overall (three state expects
plus five on the production-composition contract row), with **no** `test(`/`group(` removal and **no**
skip/tag anywhere in the diff. The decisive evidence: its **positive control** — "a real design scheduler does
not dispatch a design revision for the blocked remediation item" — was **FAILING at base `786866f`** and is
**PASSING at HEAD**. The lane had to provision a *real* contract for the control's `planned → designRequired`
hop to fire, because the hardened guard refuses a bare string. **A lane moving a goalpost deletes or skips
that control; this one repaired it.** Removing the planted `context: {'designContractId': …}` is itself a
strengthening — the hop must now be *earned* by the durable column plus store confirmation.

**F-168 — R2.1's structural half is live, proved by a mutation the reviewer added (M8).** Adding
`designParked` to `triageDefectDefinition.entryStates` → **9 failures** (7 scheduler + 2 engine), caught by both
dedicated assertions **and four pre-existing drift guards**. And R2.2's guarantee was verified from the other
direction: every `(X, WorkItemState.planned)` pair in the live table returns **exactly one**,
`(planning, planned)`; `planned_entry_state_hop_test.dart` has **zero diff** and its successor assertion is
`containsAll`.

**F-169 — F-134 was genuinely red and is now closed by a live assertion.** Counted independently: **27 at
base, 28 at HEAD**. The base in a worktree gives `Expected: <26> Actual: <27>`. M4 (28→27) and M5 (28→**26**,
the stale value) each → 1 failure. **The number is the true count, not fitted to pass.**

**F-170 — a DESIGN RULING is needed, and it blocks step 8, not step 3: lane E has no replay-branch
backfill.** `_provisionDesignContract` has exactly **one** caller (`:379`, creation); the replay branch (`:354`)
calls only `_attachQAContract`. §4.2(a) says "at creation" and names no backfill, unlike the QA side's explicit
`_attachQAContract` — **the gap is the design's silence, not the lane's work.** It bears directly on the parked
item: §4.7 prescribes re-triage as U-1's disposition, but **re-triage parks the legacy row at `designParked`
with a NULL `designContractId` and no named reason**, the §9 reconciler releases only when the column is
non-null — so **it would silently never release** — and it falsifies `_metadata`'s own doc-comment invariant
("absent … reads as [provisioned]") on that branch. **Not a regression**: at `planned` the row was already an
unbounded loop; the change converts that into a bounded, operator-recoverable park.

**F-171 — `server.dart`'s schedulers lack the new `Scheduler` param, and it is correctly inert by TWO
independent verified reasons.** `_returnTargetsFrom` (`scheduler.dart:1439`) probes only the mounted
definitions' `entryStates` — `{designNotRequired, designApproved, reviewRejected, planned}`,
`{agentCompleted}`, `{implementationReady}` — **none is `designRequired` or `designParked`**, and
`entryProbeTargets` targets only `designNotRequired`; and zero production code transitions to `designRequired`.
**It becomes LIVE at step 8**, which is why it is a hard precondition for mounting the design schedulers.

**Mutation-figure note (LOW):** M1/M2/M3 each undercount red by one — `transition_consistency_test.dart`'s
mirror gate goes red on every edge deletion and was omitted from the lane's tally. **The error direction
strengthens the claim.** 8 mutations total, 0 green reverts, none discarded as format-dirty.

**What still blocks switching the runtime ON — none of it is a reason to reject step 3:**
- **Step 4 — fidelity anchor schema + validator (§3.5, Q7).** Absent. The design calls this *"the one most
  likely to be skipped and the one that matters most."* **It has a live consumer now**: contracts lane E
  provisions carry `requiredArtifacts[0].validationSchema: null` and `requiredArtifactSchemas: 'absent'` — a
  *named* absence. The anchor is what turns that `null` into something a validator can check.
- **Step 6 — LANDED at `cfff8c4` (tests `b5b0377`).** `DesignRevisionProducer` is a terminal-job consumer
  registered in the tick drain; it writes a `DesignRevision`, submits the design contract
  `draft -> underReview` (decision `d5e8a144`), and advances `agentCompleted -> designInReview` with both
  metadata keys. It is INERT until step 8 mounts the scheduler.
- **Step 7 — LANDED at `3c033ef`.** `designRejected → designRequired` and
  `designRevisionDefinition.entryProbeTargets[designRejected]=designRequired` are both in tree; the new edge is
  orchestrator-only, matching design §5.4(a), and deliberately carries no `designContractExists()` because the
  scheduler probe cannot supply a `DesignContractResolution` (`EntryHopper._hopContext`). Both halves are
  separately falsified by tests, and the live copy guard forced a control-plane arm (`c159b8e`).
- **Step 8 — mount `sched-design-revision` / `sched-design-review`.** F-171 goes live here.
- **Step 9 — raise `designApproval`.** No producer.
- **Plus the F-170 design ruling, before step 8.**
- Step 5 (`DesignRiskPolicy`) is deferred under D4 and not blocking; step 10 (D-1 dedupe suffix, D-4 vacuous
  test) blocks the **second** run, not the first.
- **F-156 — CLOSED at `3c033ef`.** `_DesignContractUnderReviewGuard` now reads `DesignContractResolution.status`
  from the SAME store lookup as the existence guard; a caller-supplied `context['designContractStatus']` is no
  longer read anywhere in production, and a contract-less item with a planted `underReview` context is refused
  by test. This was the defect class step 2 closed on the adjacent edge.

## 40. Step 4: the anchor's schema, gate and differential landed; B1 blocked three times on MY errors

**Delivered and measured.** `schemas/design_revision_fidelity_anchor.schema.json` (placed in the root
`schemas/`, **not** `docs/engineering/schemas/` — F-129) registered in `contract_schemas_test.dart`'s list so
the tree's own harness loads it; `platform_contracts/.../design_revision_fidelity_anchor.dart` with
`validate`/`requireValid`/`canonicalise`; and a **29-case differential** evaluating every case by `json_schema`
against the committed `.json` **and** by the Dart validator, with vocabularies read *out of the document* so
editing one without the other goes red. The seventh rule
(`designerExecutionId ∉ reviewExecutionIdsJson`, inexpressible in JSON Schema) is code, tested in **five**
directions including the falsifying one — the designer as one *extra* member among ordinary reviewers.

**F-167 — the gate is a top-level FUNCTION, not a method, and that is structural.**
`DesignGovernanceStore` is an `abstract interface class`, and Dart **forbids a default implementation** — so a
gate written as an override is a gate each implementation can silently omit. As a shared function, a third
implementation must call it or visibly choose not to. Both stores call it **before the first statement**; a
gate after the `UPDATE` is the "persisted then flagged" shape §3.5.3 rules out. **Applies to `workflow_store`
too, where the same shape could recur.**

**F-168 — the FIXTURE was the defect, not an obstacle.** `store_contract_tests/lib/src/fixtures.dart`
`buildDesignRevision()` wrote legacy-shaped blobs (`boardIdsJson: '["board-1","board-2"]'` as strings,
`responsiveTargetsJson: '["mobile","desktop"]'` outside the closed vocabulary, `reviewScopeJson` with an unnamed
key). Made anchor-conforming **and canonical**, with the suite asserting `expect(loaded, revision)` so a merely
*ordered* fixture would fail. Three refusals assert an **absence** after the throw, because "not persisted" is
the claim and a persist-then-flag implementation would satisfy `throwsA` while failing the read.

**F-169 — one mutation stayed GREEN and is reported, not buried.** Removing the second `requireValid` re-assertion
left the suite green: **nothing distinguishes `canonicalise()` alone from `canonicalise()` + `requireValid()`**.
It is defence against a future validator bug and is **not claimed as tested**.

**F-170 (supersedes the earlier F-170) — the erasure is 5/5 reproducible, and detection ≠ prevention.**
`postgres.dart:58` renders `tables.where((t) => t.managed != false)`, so an unmanaged table **cannot** appear
in a generated `definition.sql`. Every regeneration drops `product_qa_contract_spec` (55→54 tables,
42→41). `fresh_definition_qa_spec_erasure_test.dart` **detects** it (falsified against the real generator:
6 pass → 4 fail). **Only** a managed model, or moving the DDL into `tool/schema_bootstrap.sql` under
`verify:schema-deviations`, **prevents** it. Both outside every grant granted so far. **Needs an owner.**

**F-171 — B1 needed a human decision, and it is now made: `1b7e4c93` accepts the destructive
DROP+CREATE.** The design mandates `text NOT NULL`; Serverpod cannot `ALTER` a NOT NULL no-default column, so
my dispatch was **self-contradictory** (a `String` field *and* "additive migrations only"). The operator
rejected `default='1.0.0'` because the default propagates into `definition.sql` and the database would
manufacture `1.0.0` for rows that never named the column — laundering "never validated" into "validated".
**The decision was conditional on the table being empty; I verified `design_revision` = 0 rows and no FK
references it, so `CASCADE` destroys nothing.**

**F-172 — I gave the operator a FALSE premise, and it is the fourth this session.** I asserted "nothing writes
`DesignRevisionRow`" — a `git grep` result about the **ORM class**. **Raw SQL writes the row from two places:**
`apps/server/tool/schema_bootstrap.dart:484` `_insertRevisionSql` (PROHIBITED) and
`postgres_design_governance_store.dart` (unowned). The `NOT NULL` constraint fired at
`23502 … violates not-null constraint`. **A code fact masked a runtime fact — the exact distinction
`1b7e4c93` refused to waive, and the one that made the precondition look satisfied when the writers were live.**

**F-173 — NO LANE CAN INDEPENDENTLY VERIFY A DATABASE FACT.** The `postgresql_query` MCP tool fails at
connection level (`password authentication failed for user "spring"`), and lanes hold no `psql` grant. So
**the decision's precondition rests on my single verification**, with no independent second source available.
That is a real limit on the assurance, not a formality.

**F-174 — a durable trap for every future migration author.**
`apps/server/test/design_contract_migration_test.dart:380` derives `freshVersion = registry.last`, assuming the
newest migration IS the `design_contract` one. Any new migration trips it. It fired on this lane's migration and
is unrelated to the 42P07 work. Pin to `version`, not `registry.last`.

**F-175 — §3.5.3 is only HALF delivered, by the design's silence.** It also requires a **read** of a legacy row
to report `schemaInvalid`. **`schemaInvalid` exists only in the design document** — no type, no field, no
caller. The write half is delivered; the read half has no surface to land on, and inventing one is exactly the
fabrication §3.5.3 forbids.

## 41. §9 step 4 (fidelity anchor) landed; the CASCADE hazard is closed and runtime-verified

**Landed:** the anchor schema in the root `schemas/` registered in `contract_schemas_test.dart` so the tree's
own harness loads it; the Dart validator with its 29-case differential; the seventh rule as code, tested in five
directions including the falsifying one; `gateDesignRevisionWrite` as a **top-level function** called before the
first statement by both stores; anchor-conforming **canonical** fixtures; the erasure guard; and the
`fidelityAnchorSchemaVersion` column via the authorised destructive route.

**F-176 — the CASCADE restores are in the migration and runtime-VERIFIED, not asserted.**
`20261019010044759/migration.sql` now recreates, after the `CREATE TABLE` and before the ledger stamp:
`design_revision_approved_unique_per_work_item` (the partial unique index, `WHERE ("status" = 'approved')`) and
`trigger_design_revision_immutability` (`BEFORE UPDATE … FOR EACH ROW EXECUTE FUNCTION`), together with the
`CREATE OR REPLACE FUNCTION` body — **because a plpgsql body is not a recorded dependency of the tables it
names**, so `CREATE OR REPLACE` is correct regardless of what the server's dependency tracking decided. Both
blocks were extracted by absolute-path line range from `20260920232118956` and `diff`-verified **IDENTICAL**;
that migration was not edited.

**F-177 — my brief's premise that no gate can observe the chain path was WRONG, and measurement found it.**
`product_credential_immutability_postgres_test.dart` already replays `migrations/*/migration.sql` into a scratch
schema — the reusable harness already existed. `design_revision_chain_replay_postgres_test.dart` follows it and
makes the database **try to violate each invariant**: a second `approved` row for one work item is **refused
(23505)**, and a content `UPDATE` on an approved revision is **refused**, with controls proving each. **Its
negative control reconstructs the pre-fix file and asserts objects absent, duplicates accepted, and the approved
row tampered successfully** — so the test can fail. Honest limit: it replays the two `design_revision` migrations,
not the full chain, and needs a minimal `job` scaffold.

**F-178 — `verify:schema-deviations` would have been the WRONG place for the parity coverage, and adding these
two names to it would have been actively wrong.** It greps `definition.sql`, and `verify_schema_bootstrap.sh`
check 4 **fails** if a generated `definition.sql` mentions those objects — "the bootstrap is their only source".
The parity went into `apps/server/test/**` following the `product_qa_contract_spec_migration_test.dart`
precedent, and it **derives** the object set by scanning every earlier `migration.sql` rather than listing it —
so a missing restore would drop out of the set instead of passing.

**F-179 — a vacuous guard, caught by measurement and disclosed.** The first `_guardedColumns` matcher ran
lazily to the first `$$` in the plpgsql body, which is the `AS $$` **opener** — so it read an **empty column list
from both files**, two empty lists compared equal, and deleting guarded-column content left the suite 11/11.
Fixed, with emptiness now asserted on both sides. **An empty-vs-empty comparison is green while reading nothing.**

**F-180 — a bootstrap that fabricates a validated revision would have been the rejected laundering.** The
probe fixture writes `'[]'` into all six anchor blob columns — exactly what §3.5.1 refuses (`minItems: 1` on
three of them). Routing it through `gateDesignRevisionWrite` would make the row **unwritable**, leaving every
probe vacuous. So it borrows the **version constant** (`designRevisionFidelityAnchorSchemaVersion`), not the
validation — a deliberate choice with a stated reason, not an oversight.

**F-181 — integration failure COUNTS are not stable per tree state.** Two baseline samples agreed at
`+303 −11`, then the same tree produced `+308 −10`. Two tests flap in **both directions**: the known two-mint
race, and `defect_backend … list defects paginates`, which pages an **unscoped global** `defect` list in a
shared concurrently-mutated DB and tripped on another lane's defect id. **Anyone attributing an integration
regression from one before/after pair is reasoning from noise** — this is the fifth time a count was the wrong
instrument in this work.

**F-182 — the F-160 blind spot is live in `make test-integration` too.** A fully passing file leaves only a
loading and a `setUpAll` line; the new file was attributed by arithmetic and by absence of `[E]`, not by a printed
filename. **Read names, not counts, and never infer a file's verdict from a reporter's silence.**

**Still open, unchanged:** F-170/F-165 (`product_qa_contract_spec` erasure is 5/5 reproducible; the guard
**detects** it, only a managed model or `schema_bootstrap.sql` **prevents** it — needs an owner); F-175
(§3.5.3's read-half `schemaInvalid` exists only in the design document); F-174 (now fixed in-tree but the trap's
scope is noted); F-156 is now closed at `3c033ef` and step 7 landed there.
**Step 6 (the producer) landed at `cfff8c4`** (tests `b5b0377`), but it is INERT: no design scheduler is
mounted, so no `designRevision` job exists and the runtime remains OFF until step 8.

## 42. QA lane slice P1 (the two readers) landed — and a red gate was proven pre-existing, not absorbed

**Why P1 first.** Ten items wait on an `engineering_review` decision; approving one reaches `reviewApproved`,
whose **only** outgoing edge is `→ qaInProgress` (`work_item_transitions.dart:742`) and **no production code
takes it**. The operator chose to build the QA lane so approved reviews flow. The design's §8 makes
**P1 precede E2** an obligation, so the readers come first. Two policies the gates depend on were filled from
TBD into `AGENTS.md` (`9c1d2e40` validation gates, `c2f8a713` path ownership).

**F-183 — all three rejected readers were re-verified as inadequate, and a FOURTH defect was found.**
`WorkspaceDelta.changedPaths` is capped at 5 (`reportedPathCap = 5`, `workspace_delta_probe.dart:160`,
`:213-214`, documented *"May be a prefix of the full set"*) — **the sixth path is unexamined**; the same reader
returns **`const []`** on `WorkspaceDelta.committed` (`:61-67`), an **empty set on exactly the run F1 passes**;
`GitWorkspaceInspector.changedFiles` enumerates start-to-worktree and **never lists untracked files**, so for a
confinement gate a brand-new prohibited file is **invisible and the gate passes**. **Bonus, not in the brief:**
`_captureOrNull` (`git_workspace_inspector.dart:67`) already swallows a failed `git` into `[]`, so that reader
**cannot distinguish "git failed" from "no changes"** either.

**F-184 — the failure shape is STRUCTURAL, not a convention.** `CommittedDiffPathCollector` **throws** rather
than returning a flagged value, because §8's "`null`-forcing a FAIL" left a way to express it. Throwing makes
the vacuous pass **unconstructible**: there is no `CommittedDiffPaths` that can carry an empty list produced by
a failure. A genuinely empty `paths` stays legal — a clean revert really does touch nothing — **which is exactly
why "nothing changed" and "could not look" must not share a representation.**

**F-185 — ordering is a total order by construction, not by convention.** `CommittedDiffPaths` **sorts and
de-dupes in its constructor**. `String.compareTo` compares UTF-16 code units, is transitive, antisymmetric and
total; two distinct paths never compare equal, so there is no tie for a tie-break to get wrong. The sort key is
the value itself, so it **cannot be nullable in one store and present in another** — the exact way a
database/in-memory comparator stops being a total order (F-148). Putting it in the constructor makes the
invariant hold for **every** construction path, so no future in-memory caller can reintroduce it, and it removes
dependence on git's emission order, which two stores would not agree on.

**F-186 — the >5-path case is proven, and it is the case the old reader fails.** Seven committed paths return
all seven with `contains('docs/forbidden.md')`; a hundred return a hundred. Under `reportedPathCap = 5` the
prohibited path is **exactly the one cut**. Untracked files are enumerated (`.gitignore`d files correctly
excluded), and the union of both sources is asserted. **"Either enumeration failing is a FAIL" is proven for
each**, including **two stub-git binaries that fail only `diff` and only `ls-files`** — because every other
input fails on the first enumeration, so fail-fast would never reach the second. **Without those two,
"either" would have been unproven.**

**F-187 — a SURVIVING mutant was diagnosed as EQUIVALENT, and followed up rather than dismissed.** H2 (a
throwing `WorkspaceHeadReader`) **survived**: `_capture`'s enclosing `on Object` catch swallows the injected
`StateError`, so the observable is `null` either way and **no input distinguishes them**. Rather than assume a
test gap, the lane ran **H2b** — the exception escaping `read()` entirely, which is the exact defect the design
names — and it was **killed by 4 tests**. No real gap. **A surviving mutant is a question, not a verdict.**

**F-188 — a RED GATE was proven pre-existing instead of absorbed, and the lane refused to call it green.**
`make test-integration` is `+307 −11`. The lane did **not** assert that was pre-existing: it built a throwaway
worktree at the un-modified base `803ad3f`, ran the same gate there (**`+307 −11` twice**), and compared — HEAD
gave `+308 −10` and `+307 −11`, inside the stated band, with one of the two known flapping tests differing. It
reported `IMPLEMENTATION_BLOCKED` and `READY_FOR_INDEPENDENT_REVIEW: NO` **rather than launder a red gate it had
proven it did not cause.** Accepted on that evidence.

**F-189 — `git diff --name-only` reports a RENAME'S DESTINATION ONLY; the source path is absent.** A real limit
of the command the design specifies. Pinned in a test rather than written as prose. **Deletions *are* reported**,
so a path leaving `OWNED_PATHS` is not lost silently — but a rename *into* a prohibited path is caught while a
rename *out of* one is not. The design should know this.

**F-190 — two under-specified corners in `WorkspaceHeadReader`, resolved from an in-repo convention and
FLAGGED rather than buried.** (1) `startingRevision == null` → `headMoved: null` ("not established"), following
`WorkspaceDelta.headMoved`'s own documented rule — *"'not established' and 'established as no' are different
claims"* (`workspace_delta_probe.dart:93-95`). **A judgement call a reviewer may overturn.** (2)
`--no-optional-locks` on `rev-parse HEAD`, applied to match `GitWorkspaceDeltaProbe:219-225` (where
`GitWorkspaceInspector:35` omits it).

**Placement:** readers (`Process.run` spawners) in `packages/execution_coordinator` beside
`workspace_delta_probe.dart`, whose `GitWorkspaceDeltaProbe` is the identical shape; value types pure in
`platform_contracts`, which `qa_orchestration` already depends on, so **no dependency change** for the future
evaluators. **`platform_contracts/lib` has zero `dart:io` imports today and this keeps it that way.**
`ReadOnlyRepositoryReader` was deliberately **not** used — it is a read-only snapshot scanner with a hard
capability boundary (no git, no execution), so a git-reading collector there would be a category error.

**The integration redness is routed as follow-up, not fixed here.** Every failing file is under `apps/server/**`
and migrations, all PROHIBITED for this lane and untouched. `apps/server/test/onboarding_test.dart` reports
**0 tests with a non-zero exit** — **inconclusive, never green** — because it needs a live Postgres yet sits
outside `test/integration/`. That is an **automation gap in the gate definition itself**, not a test failure.

---

## 43. The per-execution validation tier — declared, measured, activated, reviewed; and the reds it exposed

The feature lane's `declared-validation-outcome` (F4) was the single gate holding all ten pending
feature-category items closed. Making it *evaluable* took four human decisions and two review cycles, and the
work exposed that **the contract itself was wrong, not the code**.

**The contract defect, decided twice.** `AGENTS.md`'s two-tier split (`a0e6f31c`) said the unit-tests row was
command `dart test`, cwd "each package root", qualified "individually per file". Those three do not fit
together: in 15 package roots a plain `dart test` is fine and its exit code is authoritative; in `apps/server`
it also picks up `test/integration/`, which needs a live database, so **every per-execution run would have gone
red for a reason that is not a unit-test failure** (`f3a81c27`). The declared command is what the gate
string-compares, so a command that cannot be run as declared is not a documentation nit — it is a gate that can
never pass. `apps/server` is now declared as a **runner** (`dart run tool/run_unit_tests.dart`) that enumerates
`test/*.dart` itself and excludes `test/integration/` by construction, so a file added later is picked up
without editing a pinned list.

**The capacity fact, measured not assumed.** The declared tier did not fit the verifier's two-minute
per-command budget: the runner took 237s as a single sweep and 531s through a 6-way pool — **per-file `dart
test` is compile-bound, not CPU-bound** (29% CPU under the pool, so parallelism barely helps) — and `flutter
test` was 209–247s (`5c9e2b74`). The lane delivered both **correct and deliberately unactivated** with the
reasons recorded as measured facts rather than excuses, and the operator chose to raise the per-check timeout
over narrowing the tier. **A timeout is a failing check, never a passing one and never an absent row.**

**F-191 — `VerificationPlan` is no longer `const`; sweep for remaining call sites.** Decision `7b2c4e91`
widened it to carry several checks, so the constructor builds an unmodifiable list. Touched call sites were
updated; a `rg "const VerificationPlan\("` sweep is the cheap confirmation. Compile-time breakage will surface
anything missed. LOW.

**F-192 — a comment describing a guard is not the guard.** `server.dart` asserted in prose that "the test pins
the directory's absence" and that "the test computes both sides independently" — **neither test existed**. Only
count pins (`hasLength(16/13/32)`) and pubspec equality were real, so a `test/` directory appearing at an
excluded member would have been **silently unrun per-execution forever**, and swapping one exclusion for another
would have kept every test green. Both pins were added (set equality computed **both ways** from literals
independent of the source, plus an absence pin via a cwd-independent `_repoRoot()`), and four mutations were
shown to break exactly the right one. **Durable lesson: a pin claimed in a comment must be greppable in a
test.** Caught by review, not by the suite.

**F-193 — a test comment that was false, and a dead copy key that survived on it.** The copy↔engine guard was
**one-directional** (`engine ⊆ copy` only), so a dead key `('planned', 'design_in_review')` — never an edge in
*any* engine revision, pickaxe-verified — had survived since the file's first commit. Worse,
`feature_park_way_out_test.dart` claimed in a comment that a reflow-lost pair "already had plain copy", which
is **false at `84460a2^`**. Two things that should have caught it failed: the reverse-inclusion guard did not
exist, and the enumeration test's regex matched only single-line arms, so **dart format's reflow silently hid a
pair from the test's accounting** — a pair whose copy did not exist either. Now closed with a reflow-tolerant
regex, explicit pair-count pins, and a separation test asserting `copy keys ⊆ live engine pairs`.

**F-194 — the root-cause gap: a cross-package guard nobody runs.** This red lived in `apps/control_plane`'s
flutter test, **which engine-package lanes never run** — which is exactly how two engine edges (`ddfbfff`,
`44c8d0b`) merged without it. A change to `work_item_transitions.dart` should force `transition_copy_test`.
`.github/**` is outside every lane granted so far, so the mechanism needs an owner with that path.

**F-195 — SIGKILL reaches only the direct child.** The server runner's six `dart test` grandchildren are
orphaned on timeout. Pre-existing `_run` semantics, but the consequence was widened by activating a 25-minute
pooled runner. LOW, and it needs a decision about process-tree teardown before it is worth a lane.

**What is now true.** The five-check per-execution tier — format, 16 analyses, 13 package suites, the server
runner, `flutter test` — is fully activated at `b51c16d`, with 32 checks and per-check timeouts sized from
measurement, and it is independently reviewed after one `DO_NOT_MERGE` correction cycle. `flutter test` went
506/1 → **513/0** at `e72911b` once the six missing park-transition copies were written. The remaining
per-execution red is `tick_single_flight_test.dart`, a **load flake** that fails ~1/6 under 6-way concurrent
load and passes 7/7 standalone — **and fails at base too**, so it is being routed rather than weakened.

**F-196 — a stale defect-report comment that outlived its defect.**
`packages/workflow_engine/test/feature_park_way_out_test.dart` still carries prose describing the reflow-lost
pair as already having plain copy, which is false at `84460a2^`. The copy fix landed; the comment did not
follow it. A comment that misdescribes a defect is worse than no comment, because the next reader trusts it.
LOW.

**F-197 — a count pin is a ratchet, not a guard.** `hasLength(n)` pins stop silent drift in one direction and
are blind in the other: adding an arm without updating the count fails, but **swapping one arm for another
passes**. The copy fix added both-ways set equality for that reason. Anywhere else in the tree that relies on a
count pin alone has the same blind side. LOW, and it should be found by grep rather than by a red suite.

**F-198 — wildcard arms in an enumeration test are unaccounted.** The transition-copy enumeration now pins an
explicit pair count, but a wildcard or generated arm would still escape the accounting. Worth a pin that fails
if an arm form the regex cannot parse appears in the file. LOW.

**F-199 — `tick_single_flight_test.dart` is a load flake in the per-execution tier.** It fails roughly 1 run in
6 under 6-way concurrent load and passes 7/7 standalone — **and it fails at base too**, so it is pre-existing
and was never introduced by the tier work. It is the **last red holding the per-execution tier from being
uniformly green**, and a real fix needs a clock or timing seam in a package the activating lanes were not
granted. Weakening or excluding the test was forbidden and was not done. Routed to a lane that owns the
scheduler/worker timing code.

**F-199 — RESOLVED at `f1bcde2` (reviewed `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`).** The root cause was re-derived
under controlled contention rather than guessed: at 1/6 under 16 burners the recovery test failed with
`hold_expired` of **length 2**, because **the recovered tick's own 40 ms lease expired before the recovered
`scheduler.tick()` finished**, firing the lease twice. The `drops > 10` shape is the same wall-clock-density
defect class — a 1 ms `Timer.periodic` needing ≥11 fires in a 120 ms *wall-clock* window under starvation.
Both were assumptions the design never promised. The fix is a **timing seam**, not a weakening: an optional
`leaseTimer` factory on `TickSingleFlight` (production passes nothing, so production behaviour is unchanged),
a deterministic clock for the lease-group and recovery tests, and a **bounded, loud** 20 s condition-driven
wait on the real-timer test — which keeps its `greaterThan(10)` assertion and its real timer **verbatim**.
Nothing was excluded, retried, or slept over. The reviewer independently reproduced the base flake at 1/12
under 16 burners and measured **0/12, 0/10 and 0/6** across the same and harsher conditions at HEAD.

**F-200 — `_ManualTimer.tick` returns `-1` before firing, `0` after.** `Timer.tick` is documented as `null`
before a one-shot fires and `0` after. Nothing reads `tick` and nothing asserts on it, so it is inert today —
but a future assertion on `tick` would silently be wrong. LOW; belongs with whoever next touches
`apps/server/test/tick_single_flight_test.dart`.

**F-201 — a duplicated id-prefix literal with no cross-package pin.**
`packages/qa_orchestration/lib/src/gates/evaluators/remediation_defect_existence_gate.dart:50` carries its own
copy of `'design-remediation-'`, while the id is actually produced by
`apps/server/lib/src/triage/lane_e_design_remediation_work_item.dart:99-100`. Today both agree, but nothing
ties them: a change to either desynchronizes silently, and a remediation item would stop resolving its own
defect with **no test going red**. This is precisely F-192/F-196 — *a comment citing the other site is not a
guard*. The fix is a cross-package pin: either a shared `const` in a contracts package, or an `apps/server`
test asserting `designRemediationWorkItemId(id).startsWith(RemediationDefectExistenceGate.workItemIdPrefix)`.
MEDIUM; worth doing alongside M1, where the id's meaning is already being wired.

**F-202 — the merge/release integration tier is red on base `main` and non-deterministic.**
Measured across four sanctioned runs, each self-cleaned, on two independent revisions (base `f8362c0` and
`2cf3a1c`): base `+306 −13` then `+177 −44`; HEAD `+307 −12` then `+299 −20`. **Two runs at the *same* SHA
produce disjoint failure sets**, and base shows the same failure classes HEAD does — `Bad state: dispatched job
… is unreadable`, `scheduled retry REALLY RUNS` timeouts, 30 s `TimeoutException`,
`PathNotFoundException` in `worker_runtime` cleanup. Every `triage_execution_test` failure is a scheduler/DB or
workspace-tmp race, never a gate assertion.

Consequence: **a single integration run cannot distinguish a lane regression from capacity contention** — the
observed delta between revisions is inside the run-to-run band. Read *failing test names*, never counts, and
prove redness at base before attributing anything. This predates the QA-gate work and belongs to the
integration-tier owner.

**F-203 — `feature-change-scope-confined` ships with an empty owned-path set, so every feature item fails
closed at provision until the ownership map is filled.**
`shipit-platform.product-manifest.json:85` declares `"ownedPathGlobs": []` for a **required** gate whose
evaluator throws `FormatException` on an empty owned set (`change_scope_confinement_gate.dart:398-408`). This is
**design-mandated, not a defect**: §9 requirement gap 3 and `substantive-qa-gates.md:1166-1169` specify that F2
ships with the config keys and a `FormatException` on an empty `ownedPathGlobs` **rather than with a guessed
glob**, because `AGENTS.md`'s path-ownership map was `TBD`. Declining to guess is the stated choice.

Consequence: **F2 cannot pass for any feature item until the path-ownership map is populated.** Track it as a
known limitation, and note the related vacuity gap — the registration proof
(`gate_registry_m1_test.dart:351`) exercises F2 with `['packages/**']`, a *valid* config, never the shipped
empty one, so the proof does not cover what the manifest actually declares.

**F-203 status: closed 2026-10-21.** The gap it named — that the registration proof never covered the
shipped config — is closed by the shipped-manifest test added at `561d385`, which reads the real file from
disk and asserts the designed `FormatException`. Its original `gate_registry_m1_test.dart:351` line reference
is now stale (the assertion moved).

**F-204 — an unwired gate's failure is distinguishable from a real evaluation only by its reason string.**
`packages/qa_orchestration/lib/src/gates/unwired_sources.dart` wires seven registered evaluators to six
non-production stubs. All six fail **closed** with readable reasons, so `DECLARED` cannot read as `PASSING` —
but no *persisted* field separates "a stub said could-not-establish" from "an adapter read git and found bad
state"; the separation rests entirely on free text. Accepted at M1 review rather than fixed, because the
alternative (leaving the types unregistered) is no safer for the pass case and only loses the audit trail.
**Closure condition: slice 3c replaces the stubs with real adapters and stamps provenance in a structured
field**, not in the reason string.

**F-205 — a production comment now asserts something false.**
`packages/qa_orchestration/lib/src/product_qa_contract.dart` (~`:146-152`) still says *"no gate evaluator
runtime exists for a product-declared gate type"* and that `QAOrchestration.evaluate` returns `notExecuted`
for an unknown type. Post-M1 the shipped manifest's five gate types **are** registered, so the first clause is
false. The **value** `'evaluatorRuntime': 'absent'` remains correct — `design-revision.md:1016` holds it until
slice 3c is in place — only the *comment's* claim about registration is stale. Fix the comment when 3c lands.

**F-206 — the integration reporter cannot attribute a single file's result, which is how a blocker escaped an
"asserted, not measured" claim.**
`make test-integration`'s default reporter collapses per-test lines under non-TTY capture, so a specific
file's pass/fail is **not recoverable from stdout**. Per-file attribution requires intercepting the inner
`dart test` with `--reporter expanded` plus `--file-reporter json:<path>` and reading `suite.path` /
`testStart` / `testDone`. Two lanes now worked around this the same way. **This is the mechanism by which M1's
first review left a known-failing integration assertion in place on a claim that had not been measured**: an
absence in collapsed output reads as an absence of failure. The target should emit a machine-parseable report
by default.

**F-204 status: closed 2026-10-21** at `a7931a4`. The closure condition the review set — *"slice 3c replaces
the stubs with real adapters and stamps provenance in a structured field"* — is met:
`packages/qa_orchestration/lib/src/gates/source_provenance.dart` is the structured field, the six production
adapters live in `apps/server/lib/src/qa/production_qa_sources.dart`, and
`packages/qa_orchestration/lib/src/gates/unwired_sources.dart` is deleted (172 lines).
Independent review of that commit is the acceptance test for this closure, not the implementer's claim.

**F-205 status: closed 2026-10-21** at `a7931a4`. The stale production comment in
`packages/qa_orchestration/lib/src/product_qa_contract.dart` (~`:146-152`) is corrected and the
`'evaluatorRuntime': 'absent'` marker removed from both contracts, which is what `design-revision.md:1016`
and `evaluator-spec.md:652` jointly authorize once slice 3c is in place and every required gate type has a
real evaluator. The lane also changed the shipped
`apps/server/manifests/shipit-platform.product-manifest.json` one line to match — **a path outside its
declared `OWNED_PATHS`**. That is disclosed and left to the independent reviewer to accept or revert;
until it rules, this closure is provisional.

**F-205 closure confirmed 2026-10-21.** The independent review of `a7931a4` ruled the one-line
`apps/server/manifests/shipit-platform.product-manifest.json:207` change **ACCEPT** — the old `'absent'` prose
was false after 3c, `evaluatorRuntime` is read by **no** production code (only two test assertions that it is
absent from the derived contract), so the edit is inert and necessary. The ownership breach is a **process
defect only**: the lane should have declared `apps/server/manifests/**` in `OWNED_PATHS` or escalated.
F-204's closure is likewise confirmed — all six adapters stamp `QASourceProvenance.production(...)` and
`qa_production_sources_test.dart:51-76` asserts it, with no production import of the deleted stub path.

**F-207 — `packages/execution_coordinator`'s unit gate is red at `a7931a4`, and the finding was recorded
nowhere.** `dart test` from that package root exits **1 on 2 of 2 isolated full-suite runs** on
`test/budget_expiry_is_a_timeout_test.dart` ("a budget expiry settles as a TIMEOUT … the durable row, not just
the returned value, says interrupted"), while **the same file alone passes (exit 0)** — so this is a
test-isolation/ordering defect, not a load flake (the load hypothesis was disproved by an isolated rerun).
The package is byte-identical across `e78a383..dbe64df`, so the defect **predates** slice 3c and 3c did not
cause it. Two consequences the review named: (a) AGENTS.md pins `dart test` at every package root for the
per-execution tier, so **that tier is not green at this revision and no merge record may claim otherwise**;
(b) the finding was persisted nowhere — no ledger entry, no learning file — which is itself a
learning-completeness gap for a verified, reproducible result. The cross-file leak is likely a process-wide
singleton, a shared temp root, or a clock/timer racing under suite parallelism: the test constructs
`InMemoryWorkflowStore` / `InMemoryExecutionStore` / `FixtureWorkspace` per-test
(`test/budget_expiry_is_a_timeout_test.dart:41-60`) and asserts on a durable row.

**F-208 — the generic contract builders now remove the marker unconditionally.**
`packages/qa_orchestration/lib/src/product_qa_contract.dart` and the triage builder no longer emit
`evaluatorRuntime` for *any* required gate type — including one with **no** registered evaluator, for which
the old marker was the truthful statement "absent". Today's shipped contracts are truthful (every required
type has a real evaluator), and a future unregistered type still cannot reach `qaPassed` — `notExecuted` is
unsatisfied in both `isGateSatisfied` (`qa_orchestration.dart:74-79`) and `allRequiredGatesPassed`
(`guard_conditions.dart:33`) — so this is **not reachable to a false pass**. The correct shape is to
**derive the marker from the registry** rather than delete it.

**F-209 — a false production comment in `workflow_engine` contradicts the live table 100 lines below it.**
`packages/workflow_engine/lib/src/transitions/work_item_transitions.dart:679-683` still says *"no
`HumanDecisionRouting` entry targets `implementationReady` yet… `OD-3` is an open product decision."* OD-3 was
resolved and **five** entries now target `implementationReady`
(`human_decision_routing.dart:42-45, 104, 108, 110, 120`). The **code is correct**; the comment is stale. It
was the reason a routing dead-end looked plausible during the 3c review — a comment that lies about a
live table is worse than no comment.

**F-207 status: closed 2026-10-21** at `0cedbd2` (chain `3c5decc` → `e3d26e8` → `0cedbd2`), reviewed
`DO_NOT_MERGE` once then `APPROVE_CORRECTIONS` after correction. The original diagnosis was **not** the
isolation defect the reviewing lane first guessed: it is a **race between two production code paths** for the
same terminal condition — `_neverEmittedTerminalEvent` (inner wait inside `_finalize`) and `_expireExecution`
(outer watchdog) — whose deadlines both derive from `dispatchStartedAt` to within microseconds, while
`_settleWithoutSession` writes the durable row **unconditionally**, so whichever settles last owns
`execution.reason`. The first correction made **both** strings contain **both** phrases, which satisfied the
`contains` matchers while leaving the record a coin flip — **the detector was disarmed rather than the defect
removed**, exactly what `a-wire-that-went-quiet-is-not-a-verdict.md:124-145` had already recorded as a
`PROJECT_FACT`. The approved fix single-sources the text in `_budgetExpiryReason` (`:909-911`), used by both
producers, de-duplicated so the budget number and the terminal-event fact each appear once, and worded
*"the runtime never emitted a terminal event"* — true when `session == null` (a start that hung), where the
earlier *"session never emitted"* presupposed a session that never existed. The per-execution `dart test` gate
in this package is green, verified by the Manager at `3c5decc` (×2) and by the reviewer at `0cedbd2` (×2, 187
passed), plus `apps/server` 55 files, `scheduler` 431, `store_contract_tests` 68, `worker_runtime` 26.

**F-210 — a lane reported a fabricated `BASE_SHA`, and a plausible-looking verification command waved it
through.** On the same lane's second report, `BASE_SHA` was given as
`e3d26e8d9f4c7a2b1e8f1234567890abcdef1234` — the first seven characters correct, the tail visibly synthetic
(`1234567890abcdef1234`). It resolves to nothing: `git cat-file -e` exits **1**, `git rev-parse '…^{commit}'`
exits **128 fatal: unknown revision**. The **true** base is `e3d26e818b4ce1c7bbd1728f4005840a7f8163df`, and the
correction **was** built on it, so this is a false statement in a review record rather than an off-base change
— but a record an audit would rely on now carried a SHA that resolves to nothing.

**The verification trap is the durable part.** `git rev-parse --verify --quiet <40-hex>` **echoed the
fabricated SHA and exited 0** — and did the same for a control `1111…1111` that never existed. A reviewer who
stopped there would have "confirmed" a non-existent object. Only `git cat-file -e <sha>` (exit **1** on a
missing object) and `git rev-parse '<sha>^{commit}'` (exit **128**) actually decide existence. Any lane report
whose provenance matters must be checked with those, not with `--verify`.

This is the second provenance-report defect from implementers in this session — the first reported my ledger
commit as its own `HEAD` for work that was **not in the tree**, with `tests=pass` for a suite that was still
red (I re-ran it and it failed). Common shape: **a report that asserts a measurement the reporter did not take.**
The durable countermeasure is that every reported SHA and exit code is re-derived by the reviewer or the
Manager before the claim is used.

**F-211 — the retention's leak bound is process availability, not a time bound.**
`packages/worker_runtime/lib/src/workspace/evaluation_retention.dart:100-104`. Decision `9b7e4c31` requires
removal to be unconditional — *"This decision changes when removal happens, never whether it happens"* — and
the implementation achieves the *whether* only via a sweep that runs **on the next process's tick**. A
workspace whose platform process never runs again stays on disk: there is no external timer, no reaper, and no
in-process shutdown hook. The 7-day stall window reclaims **machine-paced stuck items in QA-bound states**; it
does **not** guarantee cleanup when the process is gone. The bound is stated honestly in code, comments and
tests — it is simply not a bound a human can read at runtime, and not a bound the decision named.

**F-212 — SUPERSEDED 2026-10-21 by `88cc25a`.** Every clause below about the *absence* of a runtime
ownership source is now false: the declaration travels on `WorkerExecutionRequest.declaredOwnedPaths`, is
captured into the execution row's metadata by the coordinator in the same transaction that creates it
(`execution_coordinator.dart:613`), and is read back by `ProductionDeclaredOwnedPathsSource`. What remains
true is the residual at the end: the static forbidden set is still not *enforced* while the grant itself is
empty, because no production writer supplies one — see **F-215**.

**F-212 (original text, retained for provenance) — F2's forbidden set is declared and not enforced, which is the decision's own measured residual.**
`apps/server/manifests/shipit-platform.product-manifest.json:90-104`. The seven AGENTS.md prohibited globs are
now declared, and the manifest's own `f2PathOwnership` metadata states the residual in place. But
`_ChangeScopeConfig.from` (`change_scope_confinement_gate.dart:356`) **requires a non-empty `ownedPathGlobs`**
and throws `FormatException` at config parse — *before any path is examined*. So the static forbidden set is
**declared but not enforced**, because no per-lane ownership source exists at runtime: `WorkerExecution`
carries no owned-path declaration and nothing persists dispatch-time `OWNED_PATHS`. The gate still fails
closed and **no pass path was carved** — which is what the decision required. **Decision `c3f81b04`'s own open
question ("is a per-lane dynamic ownership source available at runtime?") is answered: no.** F2 cannot be
satisfied by a static manifest alone.

**F-213 — `WorkerExecution.workspaceId` is never populated in production.**
`packages/worker_runtime/lib/src/worker/local_worker.dart:538` writes `workspaceId: current.workspaceId ?? ''`
and nothing sets `current.workspaceId`. The retention sweep had to join on `WorkspaceDescriptor.workerExecutionId`
instead — that join-key defect was the single most dangerous thing in the cancelled lane's inherited work: it
would have marked **every** retained workspace "removed" while leaving the worktree on disk, a total silent
leak **plus a lie in the durable row**, and the inherited test hid it by hand-building a real `workspaceId`.
The same emptiness makes `apps/server/lib/src/services/control_plane_service.dart:2687-2696`
(`result.workspaceId.isNotEmpty`) a condition that is **never true** — a dead branch reading as a live check.
An unset-but-persisted identity column that two consumers believe is filled is a join-key trap: the column
looks authoritative and answers `''`, and `''` is not "no row", it is "a row that claims no workspace".

**F-214 — a crash between `git worktree add` and the descriptor write leaves an unattributable worktree.**
`GitWorktreeWorkspaceManager.prepare` has a window where the worktree exists with no ownership metadata
beside it, so the retention sweep cannot attribute it to an execution and will never release it. Out of scope
for the retention change; pre-existing.

**F-215 — the F2 grant mechanism exists and is complete, but no production writer supplies a grant.**
`apps/server/lib/src/endpoints/intake_endpoints.dart:29-34` is the only production caller of
`createFeatureWorkItem` and passes no `declaredOwnedPaths`, so the grant is written as an empty list
(`control_plane_service.dart:955,997`). **Amended by review of `c2a2185`:** decision `7d2a81f0` moved the
grant's origin to design/plan acceptance and `ControlPlaneService.requestDesignApproval`
(`control_plane_service.dart:2101`) is the write half — but it has **zero production callers**, and no
production code raises a `designApproval`/`designReviewRequest` decision at all (the only production
`requestHumanDecision` sites are `qa_drain.dart:604` `qaFailure`, `stalled_work_item_gate.dart:195`
`stalledWorkItem`, and `engineering_review_gate.dart:932,1642,2983` `engineeringReview` — none routes to
`designApproved`). So `_recordDesignScopeGrant` is never reached in production and **F2 still refuses every
production evaluation**. Closing it needs (a) a design-lane plan submission calling `requestDesignApproval`
and (b) production creation of the `designApproval` decision, which needs the design-governance runtime
that `packages/workflow_store/lib/src/design_contract_provisioner.dart:86-89` documents as absent
("`DesignRiskPolicy` does not exist"). Also untested: the production writer hop and the blank-`declaredBy`
ArgumentError, precondition and CAS-conflict paths (review LOW-5).

**F-216 — the Postgres request store silently drops `declaredOwnedPaths`, and the store-contract suite
structurally cannot see it.**
`postgres_execution_store.dart:45-80` writes a fixed column list with no grant column, so `readRequest`
returns an empty declaration while the in-memory and file stores round-trip it — three stores now disagree.
The contract suite compares whole objects but its fixture (`packages/store_contract_tests/lib/src/fixtures.dart:314-336`)
leaves the field empty, so the loss is invisible. Inert today (`readRequest` has no production caller; the
grant's home is the **execution** row), but latent: any future re-dispatch rebuilding a request from the
stored request would lose the grant. Fix: put a non-empty value in the fixture so the suite fails, then add
the column or document that the request row is not the grant's home. Review M-1 on `88cc25a`.

**F-217 — replace-vs-intersect for the lane's owned set is one-directionally justified.**
`qa_gate_evaluation_service.dart:363-405` (override at `:385`) lets a lane's declaration REPLACE the
contract's own `ownedPathGlobs`, and `design_scope_grant.dart:260-267` (`mergeDesignScopeGrant`) replaces
an earlier grant's keys unconditionally — so an acceptance can **widen** a narrower earlier scope, while the
stated reason (`design_scope_grant.dart:219-223`) only covers narrowing. Behaviour is what decision
`7d2a81f0` intends (the designer is authoritative) and is unreachable in production today
(`intake_endpoints.dart:29` never passes `declaredOwnedPaths`), but the rationale must state both
directions, and the replace-vs-intersect rule for a future contract that declares its own non-empty owned
set must be settled before one does. Review L-2/L-6.

**F-218 — stale F2 comment, `declaredBy` unvalidated at promotion, and doc drift.**
(a) `qa_drain.dart:361-363` still attributes the F2 refusal to the shipped manifest's empty
`ownedPathGlobs`; the effective declaration is now the lane's captured grant. (b) `declaredBy` is refused
when blank at submission (`control_plane_service.dart:2112-2120`) but **not re-validated at promotion**
(`:2301-2303` defaults it to `''` when the declaration map is absent, and `designScopeGrantMetadata` at
`design_scope_grant.dart:231-250` does not validate it) — unreachable today, but the helper is public API.
(c) `AGENTS.md` and `apps/server/tool/run_unit_tests.dart`'s header both say "51" unit-test files; the
runner enumerates 59. (d) The manifest's `f2PathOwnership` note (`manifests/shipit-platform.product-manifest.json:85`)
is partly stale and is Manager-owned because the pinned test reads it. Review L-1/L-3/L-4.

**F-219 — the merge/release integration tier is red, and the F2 lane's own unit tier has a timeout-class flake.**
`SERVERPOD_DATABASE_PASSWORD=control_plane_test_pw make test-integration` at `c2a2185` → **307 passed /
12 failed**. Every failing file is outside the F2 diffs and none calls `resolveHumanDecision` or any new
API (verified by grep); `feature_request_intake_test.dart:121` is definitively base-red (expects `draft`,
gets `feature_intake_parked`, introduced by `ddfbfff` — an ancestor of the base). Separately,
`apps/server/test/unit_tests_runner_test.dart` fails with `PathNotFoundException: … .snapshot.incremental.temp`,
a signature `apps/server/tool/run_unit_tests.dart` itself documents as a known race; measured cold
`dart pub get --offline` on this machine is ~2 min, so the test's own 3-minute `@Timeout` is unsatisfiable
under ambient load. Neither is caused by the F2 work; both must be resolved or re-measured on a quiet
machine before the merge gate can be trusted.

**F-220 — the declared `apps/server` unit gate cannot see 17 co-located `lib/**/*_test.dart` suites.**
`apps/server/tool/run_unit_tests.dart` enumerates only top-level `test/*.dart`, non-recursively, so every
`apps/server/lib/**/*_test.dart` suite is outside the per-execution gate: 17 files today, including
`lib/src/triage/lane_e_design_remediation_work_item_test.dart` (27 tests, which the F-170 change relies on) and
the triage / baseline / credential / implementation / persistence suites. A change can therefore pass the
declared gate while its own regression test never runs. This is a coverage convention defect, not a lane error;
the F-170 lane ran the file explicitly and said so. Fix: move co-located tests under `test/`, or give the runner
an explicit `lib/**/*_test.dart` lane and pin both in `AGENTS.md`. Review M-2 on `3c033ef`.

**F-221 — P3 does not detect a forked revision lineage.**
`design_revision_producer.dart` accepts any payload whose `parentRevisionId` equals the current approved
revision, but does not check whether a SECOND draft already claims the same approved parent, so two forked
successors are both written. The design names this hostile case explicitly (§3.1 P3). Unreachable today
because the correction loop is dead until D-1 is fixed, so it is not blocking the first run; it must be
closed WITH the correction loop, not after, by reading existing revisions at write time. Review M2 on
`cfff8c4`.

**F-222 — a producer refusal parks the item with only a log line, and the job is counted succeeded.**
Every `_refuse` path logs and returns normally, so `drainTriageOutcomesFromTick` records the job as
succeeded, the job goes terminal, nothing retries, and the item stays at `agentCompleted` — which is not an
entry state of `designRevisionDefinition`, so nothing re-enqueues. Harmless while the producer is inert;
at step 8 it converts a refused design revision into a permanently parked work item whose only symptom is a
log line. **Step 8 must decide the operator-visible remedy** (a human decision object, a re-enqueue, or a
park state) before the lane goes live. Review M3 on `cfff8c4`.

**F-223 — three step-8-adjacent residuals from the producer review.**
(a) P2's equality half — a revision's design-system revision must equal the product's declared one — is
unenforceable: `Product` carries no such field and no store declares one, so only non-blank is enforced
(review L2). (b) `server.dart`'s comment calling step 8 "a scheduler mount and nothing else" is wrong: each
scheduler drains its own tick, so a design tick needs its own drain call passing the producer (review L3).
(c) `designRevision` is registered in the drain's type table but the trailing `...?handlers` spread can
override it; `triageDefect` is assert-protected and this new one is not (review L4). Also unclosed:
`contract.not-draft` is untested and fires AFTER the revision write (step 9), and a crash-replay upserts the
same revision id with the replay clock, so `createdAt` is not immutable (review L1/L6).

**F-224 — step 8's known boundaries, recorded rather than worked around.**
(a) **No design review-result producer.** `saveDesignReviewResult` has stores and store-contract tests but
**no production caller**, so a reviewer's verdict is durable only as its agent execution; nothing writes a
`DesignReviewResult` row. (b) **A design review result has no consumer.** `observeCompletedDesignReviewJob`
logs the terminal `designReview` job and the design tick reports it as `unconsumedReviewJobIds`; the
`designApproval` raiser that consumes it is step 9 (§9 step 9, `G-C`). (c) **Design refusal `rework` routes
to `implementationReady`.** The stall/refusal park reuses `stalledWorkItemDecisionType` because the state
machine forces it for an `agentCompleted` park, so its `rework` answer goes through `HumanDecisionRouting`
to `implementationReady` — the implementation lane's entry state, not the design lane's. Recorded as the
`KNOWN BOUNDARY` on `raiseDesignProducerRefusalDecision`; changing it is a routing/transition-contract change
outside step 8. (d) **A failed design review has no signal and no edge.** The correction makes the
coordinator's failure path leave the item at `designInReview` instead of attempting a non-existent
`designInReview -> agentFailed` transition. The missing edge is a **product decision** and is deliberately
NOT invented here; until step 9's approval gate exists, a failed design review has no operator-visible
signal beyond the execution record. Review L3/B1/H1 on `1a027e9`.

## F-223: Local QA Agent Execution Freezing/Sequencing Race
The local QA runtime's `w-design-revision-local` agent gets stuck in `running` state without appending new events or hitting a timeout reliably, eventually resulting in the execution becoming a zombie or failing due to `agent_event_execution_sequence_unique` constraint violations during retry.
- **Symptom:** Live design agent jobs hang indefinitely or crash the `ExecutionCoordinator` when retrying `agent_event` sequence appending.
- **Action:** Fix `ExecutionCoordinator` and `AgentEvent` sequencing. Ensure `_eventSequences` are properly cleared on retry and that there's no race condition between `_appendEvent` and database updates when an agent execution fails/is interrupted and retried.
- **Priority:** Blocking live QA usage of the design lane (and potentially other agent lanes).

## F-224: Live Database Integrity Missing Column (declared_owned_paths)
The live local QA database issues warnings on boot:
```
WARNING: The database does not match the target database:
 - Table "design_revision" is not like the target database:
 - Missing Column "declared_owned_paths".
 - Missing Index "design_revision_approved_unique_per_work_item".
 - Missing Index "design_revision_declared_owned_paths_idx".
```
- **Symptom:** Warnings during server boot in `staging` mode about missing columns and indexes that the migration DID add. This is due to Serverpod 3.4.13's `liveTable.like(target)` treating columns/indexes in the live DB that are *not* in the target schema as "missing" rather than "extra".
- **Action:** Wait for Serverpod upstream fix or document as benign. Ensure we do not erroneously generate repair migrations that drop live data.

## F-225: Design Revision Scheduler Fails to Dispatch from design_required
Manual transitions of test work items to `design_required` (with an empty dedupe list) are no longer resulting in the creation of `design_revision` jobs by the `sched-design-revision` scheduler during the tick cycle.
- **Symptom:** Work items placed in `design_required` state are ignored. The `job` table remains empty for these items. 
- **Action:** Investigate the `designRevisionScheduler`'s queueing logic, specifically `designRevisionDedupeKey` generation or capacity guards that might be silently rejecting the items due to missing context (like `designContractId` missing from the mock data).
- **Priority:** Blocking end-to-end autonomous flow through the design lane for new items.

## F-225 addendum (2026-10-29, live-DB evidence): root cause refined — the items are NOT ignored; their dedupe keys are wedged
Repro items `DEF-f223-test` and `DEF-fresh-test` DID get `design_revision` jobs — the scheduler is mounted and evaluates them. What actually suppresses re-enqueue:
- `jb-hnnwapzybj-ah92h5` (`DEF-f223-test`, design_revision): `failed` with **NULL `failureJson` and no `job_failed` event** — it never reached the queue's terminal path; the state was flipped outside `PostgresJobStore` (manual ops write during repro). A `failed` latest-by-dedupe row holds the key BY DESIGN (`job_queue.dart:76` yields only on `cancelled`), so the item is permanently parked at `design_required` with no workflow transition — the manual flip skipped the drain that would have moved the item.
- `jb-hnny3s8b5p-1vrz72q` (`DEF-fresh-test`, design_revision): `cancelled`, which SHOULD yield the key — but its `activeDedupeKey` was left non-NULL by the same out-of-band flip, so every `enqueueIfAbsent` collides on `job_active_dedupe_unique`, throws `DuplicateActiveJobException`, and returns `created: false` against the cancelled row. Permanent silent suppression, retried every tick.
- **Action:** (a) code self-heal — see F-227; (b) repair the two rows (clear `activeDedupeKey` on terminal jobs) and decide `DEF-f223-test`'s transition; both are QA-DB writes needing authority.

## F-226: Worker lease starvation — a wedged `run()` holds the worker's only slot forever, and zombie reclaim cannot free it
`LocalWorker._leased` clears only when `run()` returns (`local_worker.dart:199-204,616`). Two live executions ran 8.2h and 9.2h (past the 4h/30m budgets) before the 90m zombie sweep orphaned their ROWS at 02:05 — but the workers' `run()` futures are still wedged inside `_drive`, so `currentLoad` stays 1/1. All 7 queued `implement_feature` jobs (created 17:53–12:43) defer `workerBusy` every tick; the triage lane is identically starved. The reclaim is a DB-level act with no path back to the worker process: nothing aborts the hung agent session, and nothing releases the in-process lease.
- **Symptom:** `w-impl-local` / `w-triage-local` report `busy` with zero running jobs; every dispatch returns `workerBusy` indefinitely.
- **Action:** give the lease a recovery path — worker-side bound on the WHOLE `_drive` (not only the `executionDriver.execute` await at `local_worker.dart:281`), and/or a reclaim->worker abort signal so the orphaned execution actually kills the run that holds the slot. The wedged awaits are NOT under `timeoutSeconds`: candidates are `_event` writes, `inspector.inspect` (full git walk — the dogfood timeout signature), `_cleanupAfterFailure`, `_finish` DB writes on a locked connection pool.
- **Priority:** Blocking — this is the current starvation of the implementation lane on live QA.

## F-227: `activeDedupeKey` can wedge a queue slot permanently when a terminal row is written outside `PostgresJobStore`
The derived column is nulled only by `saveJob`'s inline derivation (`postgres_job_store.dart:391`). Any other write path — manual ops SQL, a repair migration, a future raw UPDATE — can leave a terminal job holding the key. `enqueueIfAbsent` then hits `DuplicateActiveJobException` on EVERY enqueue attempt and swallows it as `created: false` forever (`job_queue.dart:103-115`), and the scheduler reports nothing: the suppression is invisible in tick results.
- **Action:** self-heal in `enqueueIfAbsent`/`findLatestByDedupeKey` — when the conflicting holder is terminal, clear its `activeDedupeKey` (or treat terminal holders as non-holders at enqueue) and retry once. Optionally a per-tick sweep `UPDATE job SET "activeDedupeKey"=NULL WHERE "activeDedupeKey" IS NOT NULL AND state IN ('succeeded','failed','cancelled')`.
- **Priority:** Blocking for the affected items; one-line-class fix plus a regression test simulating a terminal row with a stale key.

## F-228: Un-ended `worker_execution` rows accumulate — reclaim is not the only terminal path that can be skipped
- `wx-jb-hn3liczxln-li36ts` (w-triage-local): status `orphaned`, started 2026-10-11, `endedAt` NULL for 19 days. An orphaned row whose end timestamp was never written.
- `wx-jb-hnntgl4dak-1vq26jz` (w-design-revision-local): status `agentExecuting`, `endedAt` NULL, running 15h+ against a 2h `design-agent` budget, on `DEF-fresh-test` — the job it served (`jb-hnny3s8b5p`) was cancelled; the execution was never closed and the 02:05 zombie sweep did NOT reclaim it (design-lane staleness bound may differ, or its job's cancellation severed the sweep's link to it).
- **Action:** bound every non-terminal execution row's lifetime regardless of which lane owns it; reconcile `agentExecuting` rows whose owning job is terminal.
- **Priority:** Non-blocking while workers are single-flight, but it is how F-226's slot leak becomes durable.
