# Subtask Prompt — integrate-credential-identity-invariants

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-credential-identity-invariants
TASK_TYPE: integrate
FEATURE: Add Product rebuild — merge the credential identity invariants fix
WORKTREE: /private/tmp/shipit-credential-identity   (branch fix/credential-identity-invariants @ a4c211c)
BRANCH: fix/credential-identity-invariants
BASE_SHA: 0bf2fa0
HEAD_SHA: a4c211c          # APPROVED — this is now pinnable
TARGET: main @ 289f1d3
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/integrate-credential-identity-invariants/**   (your report)
READ_ONLY_PATHS: everything else until you have decided the merge strategy
PROHIBITED_PATHS: any source edit — you are integrating an APPROVED tree, not changing it
ACCEPTANCE_CRITERIA: |
  Verify the approved HEAD, verify current main, determine a safe integration strategy, run the
  required post-integration gates, and merge only if everything holds.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-credential-identity && git rev-parse --short HEAD
  - cd /private/tmp/shipit-credential-identity && git status --porcelain
  - git -C /Users/alkebut/air/shipit-platform rev-parse --short main
ROUTING_CLASS: PRECISION
```

## The approval you are integrating — read the reports, do not take the Manager's word

```
RESULT: APPROVE_CORRECTIONS
REVIEWED_HEAD: a4c211ccd1d094b4955f56f7d9ae385e377bb15f
REGRESSIONS: none
READY_FOR_MERGE: YES
```

Reports, all on disk:

1. `docs/engineering/dispatch/tasks/review-credential-identity-invariants/report.md` — baseline review,
   `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`
2. `docs/engineering/dispatch/tasks/review-credential-identity-invariants-rereview/report.md` —
   `DO_NOT_APPROVE_CORRECTIONS` (no commit existed, MEDIUM, new MEDIUM)
3. `docs/engineering/dispatch/tasks/correct-credential-identity-invariants-guard/report.md` — the
   correction: committed the reviewed tree as `3f3f4f4`, fixed the guard as `a4c211c`
4. `docs/engineering/dispatch/tasks/review-credential-identity-invariants-final/report.md` —
   **`APPROVE_CORRECTIONS` / `READY_FOR_MERGE: YES`** ← your authorisation

## What this change does, and why it is urgent

**D-4, D-18 and D-5.** The security consequence: **until this lands, a REVOKED CREDENTIAL CAN BE
RESURRECTED ON `main`.** That path is live today and independent of every other item in this work item
— no design revision, no human decision, no other lane gates it. That is why it is being merged ahead
of the design work that is otherwise further along.

## ⚠ THE RECONSTRUCTION — verify it before you merge

`3f3f4f4` was **not** produced by committing a working tree. The correction lane reported that the
reviewed state **survived nowhere on disk** (26 `/private/tmp/shipit-*` worktrees searched) and that it
**reconstructed** it by exact inverse edits before committing.

The final re-review checked this against the oracles the baseline review recorded and **every one
passed**: 8 files / 1271 insertions / 90 deletions; guard 361 lines; the pre-correction
`sed 's/^[^:]*://'` at `:267`; the `exit 2` idiom at `:221-228`; the policy comments at `:306-312` and
`:313-315`; guard 18 OK / 0 FAIL. It added an oracle the lane had no way to check — **the MEDIUM defect
itself reproduces at `3f3f4f4`**, bit-identical to its own §2.2 record — plus eleven line-level oracles
across five files.

**You are not being asked to re-audit that.** You **are** asked to verify the cheap invariants yourself
before merging: that `HEAD` is `a4c211c`, that the tree is **clean**, and that the diff you are merging
is exactly the 8 reviewed files. If any of that does not hold, stop.

## Integration strategy — Manager-measured, verify it

```
merge-base(HEAD, main) = 0bf2fa0
main..HEAD   = 2 commits (3f3f4f4, a4c211c)
HEAD..main   = 5 commits
```

`git diff --name-only HEAD...289f1d3` (what main has that HEAD lacks) is **23 files, all docs and
decisions** — no overlap with the 8 code files. **Main has touched none of them.** A merge should be
clean and conflict-free. **Verify that yourself rather than assuming it.**

Decide and record: fast-forward is impossible (main has diverged), so this is a true merge commit or a
rebase. **Prefer the merge commit** — no history rewrite, and the approved SHAs stay addressable. Never
force-push, never amend anything reachable from a ref, never squash a reviewed history.

## Gates you must run AFTER the merge, on the merged tree

Baseline on the approved branch:

- `dart format --output=none --set-exit-if-changed .` — 631 files, 0 changed
- `dart analyze` — exit 0, 2 pre-existing infos in the untouched `packages/workflow_engine`
- `cd packages/product_registry && dart test` — **+148**
- `apps/server/tool/verify_schema_bootstrap.sh` — **20 OK, 0 FAIL**
- `apps/server/tool/verify_schema_bootstrap_negative_controls.sh` — **12/0**
- `SERVERPOD_DATABASE_PASSWORD=… make test-integration` — **+171 −1** on a good run

**Run the gates on the MERGED tree, not on the branch.** The point is to prove the merge did not break
anything.

## ⚠ T4 — a known flake. You must judge it, not inherit it

**The integration suite is NOT deterministically green.** The final re-review ran it four times:
`+170 -2, +171 -1, +171 -1, +171 -1`; the correction lane's four were `+171 -1, +170 -2, +170 -2,
+171 -1`. **Three of eight runs had the extra failure.**

The diagnosis, established by the final review: the failing test is the reviewed work's own **D-4
concurrency test**. Both callers mint the same id into the same repository, so the loser violates **two**
unique constraints at once. Exactly one row is written either way; **what varies is only which constraint
Postgres names**, and nothing pins that. Corroborated by test `T-C`, which builds the same
double-violation sequentially, asserts the same message, and **never flakes**. **There is no masked
security bug.** The final review judged this **does not block** the merge.

The reviewer's recommended disposition is **fix the behaviour, not the test**: add a mint-branch read-back
so the message stops saying *"another caller recorded one first"* when no race happened. **That fix is
NOT part of this merge** — it is a separate change with its own review.

**Your obligations:** (a) do not treat a `-2` run as a gate failure **without** checking it is T4 and not
something new — name the failing test in your report every time; (b) if you see `-2`, re-run to confirm;
(c) **if you see any failure other than T4, stop and report `INTEGRATION_BLOCKED`**; (d) do not fix it,
weaken it, skip it or absorb it. Reporting the flake honestly is part of your deliverable.

## Merged tree must also keep the reviewable evidence

`3f3f4f4` and `a4c211c` commit the 8 code files only. **The four review reports above are currently
uncommitted working-tree files in the canonical checkout.** Before you finish, confirm they exist and say
whether they are on their way into a commit — **a design/review verdict with no provenance is this work
item's lost-evidence problem recurring, and it has now happened three times.** Do not commit them
yourself unless the Manager's bookkeeping already staged them; report the state.

## HARD RULES — the Docker rule is not negotiable

- **Run no Docker or Compose command that can change state.** No `down`, `stop`, `rm`, `prune`,
  `volume rm`, `compose up`, `pull`, `build`, `--rmi`. **And not read-only-looking ones** —
  `docker compose ps`, `logs`, `config`, `docker info` are **NOT granted.** Every exception becomes the
  next precedent.
- **NEVER** run `make clean`, `make test-env-down`, `make e2e-down`, or any bare
  `docker compose … down -v` without `-p <project>`. **These resolve to compose project `docker` = the
  LIVE QA STACK.** `make clean` is a disarmed stub that removes nothing. **This repository has already
  lost its QA database irrecoverably** (volumes `docker_postgres_data_qa`, `docker_triage_repo_qa`,
  `docker_triage_workspaces_qa`; no dump existed) to a **review lane** running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`. **Do not test this rule.**
- **`make test-integration` is the ONLY sanctioned way to get a real database** — disposable, project
  `shipit_integration_<pid>`, self-cleaned on success, failure and interrupt alike. Use it and nothing else.
- If you need a mutating Docker operation `make test-integration` does not provide, **that is a blocker
  to report, not a command to run.**
- If you have already breached this, **disclose it immediately, naming the exact commands.**

## Other rules

- **Do not modify any source file.** You are integrating an approved tree. If you find yourself wanting a
  change, that is a finding, not an edit.
- **Never force-push. Never rewrite reviewed history. Never amend a commit reachable from a ref.**
- The canonical checkout at `/Users/alkebut/air/shipit-platform` has **pre-existing unrelated dirty
  state** (`apps/control_plane/test/failures/*.png`, `melos_shipit_platform.iml`, several untracked
  `.sql` scratch files at the repo root). **It is not yours and not this lane's — do not touch it, do not
  stage it, and do not treat it as yours to clean.** If your merge strategy requires a clean working
  tree in the canonical checkout, say so and stop rather than discarding the human's files.
- **PERSIST YOUR FULL REPORT TO DISK** at
  `docs/engineering/dispatch/tasks/integrate-credential-identity-invariants/report.md` before returning.
  **Two reports were lost to a relay in this work item.** Do not be the third.
- Every result carries exact provenance: SHAs, branch, worktree, and the gate output.

## Integration authority — READ THIS

**Stop at `RESULT: MERGE_APPROVED` / `READY_FOR_INTEGRATION`.**

Repository policy does **not** authorise you to push to `origin` or to merge into `main` on your own
initiative. **This is a genuine change with human-visible security consequences**, and the human has
authorised this merge in principle while reviewing the work item — but the final call to write `main`
and push is **the Manager's and the human's, not yours.**

So: perform every verification, determine the strategy, prepare the merge, **and stop before merging.**
Report exactly what you verified, what the merge would do, and what remains. If the human or the
Manager authorises the merge afterwards, it is a mechanical step from your report.

## Report format

Report per `.agents/skills/aef-orchestrator/templates/subtask-report.md`:

```
RESULT: MERGE_APPROVED | READY_FOR_INTEGRATION | INTEGRATION_BLOCKED
```

Include: verified SHAs, tree cleanliness, the strategy chosen and why, the full gate results on the
merged tree, the T4 disposition for each run, local and remote provenance, and the exact command that
would perform the merge.