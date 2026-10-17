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

- `qaPassed` (`:690`) needs `allRequiredGatesPassed()`, which **always fails** (F-47);
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
