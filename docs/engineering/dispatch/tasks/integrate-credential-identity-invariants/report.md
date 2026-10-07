# Report — Integration, `fix/credential-identity-invariants` into `main`

Persisted per `aef-orchestrator` §14. Agent: `integrator`. Read-only with respect to source.

```yaml
RESULT: READY_FOR_INTEGRATION
TASK_ID: integrate-credential-identity-invariants
TASK_TYPE: integrate
FEATURE: Add Product rebuild — merge the credential identity invariants fix
WORKTREE_REVIEWED: /private/tmp/shipit-credential-identity   (branch fix/credential-identity-invariants)
WORKTREE_REHEARSAL: /private/tmp/shipit-integrate-cred-identity  (detached; the merge rehearsal — NOT main)
BRANCH: fix/credential-identity-invariants
BASE_SHA: 0bf2fa0
APPROVED_HEAD: a4c211c
TARGET: main @ 289f1d3
REHEARSAL_MERGE_COMMIT: 08c7590  (two parents 289f1d3 + a4c211c; tree 5b66ae0)
STRATEGY: merge commit (--no-ff), no history rewrite
MERGED: NO  — stopped before merging, per integration authority
GATES_RUN_ON: the merged tree (08c7590), not on the branch
HUMAN_DECISION_REQUIRED: YES — writing main and pushing are the Manager's and the human's
```

**Bottom line: every cheap invariant holds, the merge is provably conflict-free, and all gates pass on
the merged tree. The only thing standing between this and `main` is the decision to merge and push, which
is not mine to take.** The security gap this closes — a revoked credential resurrectable on `main` — stays
open until that decision is made.

---

## 1. The authorisation I am integrating

`docs/engineering/dispatch/tasks/review-credential-identity-invariants-final/report.md`, read from disk:

```
RESULT: APPROVE_CORRECTIONS
REVIEWED_HEAD: a4c211ccd1d094b4955f56f7d9ae385e377bb15f
REGRESSIONS: none
READY_FOR_MERGE: YES — conditional on the two tracked items in §11, neither of which is a gate
```

I read all four reports in the order given. The chain: baseline review
(`APPROVE_WITH_NON_BLOCKING_FOLLOWUP`, 1 MEDIUM) → focused re-review
(`DO_NOT_APPROVE_CORRECTIONS` — no commit existed, MEDIUM open, NEW MEDIUM found) → correction lane
(committed the reviewed tree as `3f3f4f4`, fixed the guard as `a4c211c`) → final focused re-review
(`APPROVE_CORRECTIONS`). The MEDIUM and LOW-1 are closed with mechanisms verified; the NEW MEDIUM
(`lastFailureReason`) is recorded-not-fixed by explicit scope decision; T4 is judged non-blocking by the
final review.

## 2. The three cheap invariants I was asked to verify — all hold

| Invariant | Result |
|---|---|
| `HEAD` is `a4c211c` | **`a4c211ccd1d094b4955f56f7d9ae385e377bb15f`** ✅ |
| The worktree is CLEAN | **`git status --porcelain` → empty output** ✅ |
| The diff I merge is exactly the 8 reviewed files | `0bf2fa0..a4c211c` → **9 paths, all reviewed** ✅ |

The 9th path is not a 9th change: it is
`apps/server/tool/tests/verify_schema_bootstrap_negative_controls.sh`, the **new file added by `a4c211c`**
(+300/-0). The `3f3f4f4` commit alone is the 8 reviewed files — verified by summing `--numstat`:
**8 files / 1271 insertions / 90 deletions**, exactly the figure both prior reviews recorded.

```
apps/server/lib/src/persistence/postgres_product_registry_store.dart              165  48
apps/server/test/integration/product_credential_immutability_postgres_test.dart   478   5
apps/server/tool/schema_bootstrap.sql                                              23   9
apps/server/tool/verify_schema_bootstrap.sh                                       270   6   (84/1 at 3f3f4f4)
apps/server/lib/../engine/product_registry_engine.dart                            23  12
packages/product_registry/lib/src/store/in_memory_product_registry_store.dart     90   3
packages/product_registry/lib/src/store/product_registry_store.dart               66  12  (48/12 at 3f3f4f4)
packages/product_registry/test/credential_test.dart                               360   0
apps/server/tool/tests/verify_schema_bootstrap_negative_controls.sh              300   0   (added by a4c211c)
```

`a4c211c` in isolation is **3 files, +515/-16** — the guard (+195/-14), the new self-test (+300), and the
store comment (+20/-2). Both commit shapes match what the correction lane and the final review recorded.

I was explicitly **not** asked to re-audit the reconstruction of `3f3f4f4`, and I did not. I note only
that the cheap check is consistent with it: `3f3f4f4`'s file count, insertion count and deletion count are
the numbers the two prior reviews independently recorded, so the commit is not obviously a different tree.

## 3. Divergence and the merge surface — verified, not assumed

```
merge-base(HEAD, main) = 0bf2fa0            ✅ matches the Manager's measurement
main..a4c211c          = 2 commits           ✅ (3f3f4f4, a4c211c)
a4c211c..main          = 5 commits           ✅
origin/main            = 289f1d3             ✅ in step with local main, no unpushed divergence
```

`git diff --name-only a4c211c...main` (what main has that HEAD lacks) is **23 paths, and every one is
`.decisions/`, `docs/adr/` or `docs/engineering/dispatch/`** — documentation, decisions and design
revisions. The overlap set against the 9 reviewed paths is **empty** (verified with `comm -12`, blank).
Main has touched **none** of the reviewed files, and the branch has touched none of main's 23.

Two independent confirmations that the merge is conflict-free:

1. **`git merge-tree --write-tree`** — `exit 0`, tree `5b66ae098027363d67c623f05b1f8e54d3e4c116`,
   **no conflict list**. Non-zero exit and a conflict list would have appeared had any path overlapped.
2. **The rehearsal merge actually performed** (§4) — `Merge made by the 'ort' strategy`, zero conflicts,
   and the resulting tree is `5b66ae0`, **byte-identical to the tree `merge-tree` predicted in advance**.

## 4. The rehearsal merge — how I proved it without writing `main`

Fast-forward is impossible (`main` has 5 commits the branch lacks), so this must be a true merge commit or
a rebase. **I chose the merge commit**, for the reasons the dispatch gives and which I agree with
independently:

- **No history rewrite.** `3f3f4f4` and `a4c211c` stay reachable and addressable. A rebase would mint new
  SHAs for both, and `a4c211c` — the exact revision the final review pinned its oracles and every gate
  result to — would cease to exist as a reviewable object. That is precisely the loss-of-provenance failure
  this work item has already suffered twice.
- **The audit trail keeps its shape.** The reviewer can still `git show a4c211c` and see the reviewed tree.

The merge was rehearsed in a **throwaway detached worktree at `main`**, so that `main` itself was never
advanced and never needed a clean tree in the human's checkout:

```
git worktree add --detach /private/tmp/shipit-integrate-cred-identity main
git -C /private/tmp/shipit-integrate-cred-identity merge --no-ff --no-edit fix/credential-identity-invariants
```

Result:

```
Merge made by the 'ort' strategy.
 9 files changed, 1775 insertions(+), 95 deletions(-)
 create mode 100755 apps/server/tool/tests/verify_schema_bootstrap_negative_controls.sh

08c75902a9c0a1643424f4576b58872c8291b289
parents: 289f1d33dcf1a2f24ead765c9e573b2f1ba1f107  a4c211ccd1d094b4955f56f7d9ae385e377bb15f
tree:    5b66ae098027363d67c623f05b1f8e54d3e4c116
```

**The merged tree is byte-identical to the approved branch on all 9 reviewed paths.** I hashed each blob
in both revisions and compared: `postgres_product_registry_store.dart`,
`product_credential_immutability_postgres_test.dart`, `schema_bootstrap.sql`,
`verify_schema_bootstrap_negative_controls.sh`, `verify_schema_bootstrap.sh`,
`product_registry_engine.dart`, `in_memory_product_registry_store.dart`,
`product_registry_store.dart`, `credential_test.dart` — **all 9 `IDENTICAL`**. The merge contributed
nothing to those files; it only carried main's 23 documentation commits alongside. That is the strongest
available statement that the merge cannot have altered reviewed behaviour.

### 4a. The rehearsal worktree needed `dart pub get` — a disclosure, because the first format run "failed"

My first `dart format` in the fresh worktree reported **`631 files (69 changed)`** with package-resolution
warnings. That was **not** a formatting defect: the new worktree had no `.dart_tool`, so `dart format`
could not resolve `package:lints/recommended.yaml` and fell back to default style. After `dart pub get`
(pubspec.lock unchanged, `git status --porcelain` empty afterwards) the same command reported
**631 files / 0 changed / exit 0**. I am recording the first run rather than reporting only the clean one,
because "69 changed" would otherwise read as a merge-introduced formatting failure.

### 4b. A staged file in the human's checkout blocks a *direct* merge there — relevant to the command

The canonical checkout has `docs/engineering/WORK_STATE.md` **staged** (+39/-12). I probed what happens if
the merge is run there as-is:

- `git merge --no-ff` in a checkout with that file staged: **`error: Your local changes to the following
  files would be overwritten by merge: docs/engineering/WORK_STATE.md`** — the merge refuses.
- `git merge --ff-only <merge-sha>`: **succeeds**, and leaves the staged edit intact (`M
  docs/engineering/WORK_STATE.md` afterwards).

So the command shape matters, and I verified both rather than reasoning about it. Both probes ran in
throwaway worktrees I then removed with `git worktree remove --force`; **no stage, discard or checkout was
ever run against the human's files**, and the canonical checkout is exactly as I found it.

## 5. Gates — all run on the MERGED tree (`08c7590`), not on the branch

| Gate | Command | Baseline | **Actual on the merged tree** | Verdict |
|---|---|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | 631 files / 0 changed | **`Formatted 631 files (0 changed)`, exit 0** | ✅ EXACT |
| analyze | `dart analyze` | exit 0, 2 pre-existing infos in `workflow_engine` | **exit 0, 2 issues — both `packages/workflow_engine/lib/src/states/workflow_state.dart` (`:146`, `:197`), a package this change does not touch** | ✅ EXACT |
| unit | `cd packages/product_registry && dart test` | `+148` | **`+148: All tests passed!`, exit 0** | ✅ EXACT |
| schema guard | `apps/server/tool/verify_schema_bootstrap.sh` | 20 OK / 0 FAIL | **20 `OK:`, 0 `FAIL:`, exit 0** | ✅ EXACT |
| negative controls | `apps/server/tool/tests/verify_schema_bootstrap_negative_controls.sh` | 12 / 0 | **`12 cases, 0 failed`, exit 0** | ✅ EXACT |
| integration | `SERVERPOD_DATABASE_PASSWORD=… make test-integration` | `+171 −1` on a good run | **4 runs, `+171 −1` on every one** — see §6 | ✅ EXACT, and T4 did **not** reproduce |
| build | — | — | **`NOT_RUN`** — this stack has no build step; there is no build command to run and no build baseline to match | n/a |
| runtime | — | — | **EXERCISED** — the integration suite bootstraps a real Postgres via `dart run tool/schema_bootstrap.dart` and the guard ran against the merged tree | ✅ |

`NOT_RUN`: nothing that was required. `build` is not a gate in this stack; the correction lane recorded
the same and I concur.

**`git status --porcelain` in the rehearsal worktree was empty after every single gate**, including after
the four integration runs. No source file was modified by me at any point. The only files I created were
two throwaway worktrees (removed) and this report.

### 5a. The negative-control harness did not touch the repository, verified again

The harness's `repository-untouched` case is one of its 12 and it passed. I additionally confirmed it
independently: `git status --porcelain` empty in the merged worktree after the run, and the merge
commit `08c7590`'s blob for `apps/server/tool/schema_bootstrap.sql` is unchanged from `a4c211c`.

### 5b. A credential I had to materialise to run the integration gate — disclosed

`make test-integration` aborts without `SERVERPOD_DATABASE_PASSWORD`, and the value lives in the
**gitignored** `apps/server/config/passwords.yaml`, which a fresh worktree does not have. I copied that
file from the reviewed worktree into the rehearsal worktree so the gate could run, resolved the value into
a shell variable, passed it through the environment, and **deleted the copy afterwards**. The value never
appears in this report, in any log, in any commit, or in any file I wrote. `git status --porcelain` was
empty both before and after, confirming the copy was gitignored and never staged. I did not use the
`postgresql_query` MCP tool — I cannot establish which database it points at, and guessing against the live
QA stack is not something to do.

## 6. T4 — the known flake. My disposition, per run, with the failing test named

**Obligation (a) — the failing test is named on every run. All four runs' only failure was:**

```
test/integration/dogfood_shipit_postgres_test.dart:
  S-1 DOGFOOD — Product: ShipIt (Postgres, read-only)
  register ShipIt, discover pinned HEAD read-only, propose baseline, survive restart

  Expected: true
  Actual: <false>
  dogfood expects a git working tree at /private/tmp/shipit-integrate-cred-identity
    apps/server/test/integration/dogfood_shipit_postgres_test.dart:87:11
```

**This is the known pre-existing failure, not a merge artifact, and I checked rather than assumed:**

- It is the **same test and line (`:87`)** the baseline review, the re-review and the correction lane all
  recorded as the sole baseline failure.
- It asserts `Directory('${repoRoot.path}/.git').existsSync()` — i.e. **the checkout is a git working
  tree**. `apps/server/test/integration/dogfood_shipit_postgres_test.dart` is **not in the merge diff**
  (`git diff --name-only main 08c7590 | grep -c dogfood` → **0**). The failure is a property of the
  checkout I ran in — a detached worktree of a git worktree — and it names **my** rehearsal path
  (`/private/tmp/shipit-integrate-cred-identity`) rather than the reviewed one, which is the message
  telling you the assertion is about the *directory*, not about the merge.
- `a4c211c` and `3f3f4f4` do not touch this file. The correction lane's diff likewise does not touch
  `apps/server/test/`.

**Obligation (b) — T4 did not reproduce, so no re-run-for-confirmation was triggered.** I ran the suite
**four** times rather than once, deliberately, because the whole point of T4 is that a single green run is
weak evidence:

| Run | Result | Failing test(s) | T4? |
|---|---|---|---|
| 1 | `+171 −1` | `dogfood_shipit_postgres_test.dart` S-1 (`:87`, expects a git working tree) | no |
| 2 | `+171 −1` | `dogfood_shipit_postgres_test.dart` S-1 | no |
| 3 | `+171 −1` | `dogfood_shipit_postgres_test.dart` S-1 | no |
| 4 | `+171 −1` | `dogfood_shipit_postgres_test.dart` S-1 | no |

`grep -c "D-4 under concurrency.*\[E\]"` = **0** on all four runs. T4 occurred in **3 of 8** prior runs
across the correction and final-review lanes; it occurred in **0 of 4** mine. So the disposition is
**T4 absent, no `-2` to adjudicate, and obligation (c) was never triggered.**

**Honest reporting, stated plainly rather than buried:** this does **not** overturn the final review's
diagnosis, and my 0-in-4 does not make the suite deterministically green. The mechanism is unchanged and
still holds — in D-4 both callers mint the same id into the same repository, so the losing tuple violates
two unique constraints at once, and what varies is only which one Postgres names. My four runs are one
more sample from a distribution that has produced a `-2` three times, not evidence that it cannot. **The
gate that gates a security fix is not deterministically green, and the Manager should know that before
relying on CI.** The final review's disposition stands: does not block, because the invariants D-4 exists
to prove held in all eight prior runs and in all four of mine.

**Obligation (d) — I did not touch it.** No fix, no weakened assertion, no skip, no `tags:`, no absorption.
The recommended disposition (fix the behaviour — give the mint branch the read-back the CAS branch already
has, so the store reports the identity conflict when that is what was violated; **not** relax D-4's
assertion) remains a separate change with its own review, and is required before `20261006150645000`
reaches a deployed database.

## 7. Provenance

**Local**

| | |
|---|---|
| canonical checkout | `/Users/alkebut/air/shipit-platform`, branch **`main`**, `HEAD` = `289f1d3` — **unmoved by me** |
| approved branch | `fix/credential-identity-invariants` @ `a4c211c` in `/private/tmp/shipit-credential-identity` — **clean tree, unmoved by me** |
| merge base | `0bf2fa0` |
| rehearsal merge | `08c7590`, parents `289f1d3` + `a4c211c`, tree `5b66ae0`, in `/private/tmp/shipit-integrate-cred-identity` (detached) |
| `git stash list` | untouched by me |

**Remote**

```
origin  https://github.com/shipitinc/shipit-platform.git (fetch/push)
origin/main = 289f1d33dcf1a2f24ead765c9e573b2f1ba1f107
local main  = 289f1d33dcf1a2f24ead765c9e573b2f1ba1f107   → identical, nothing unpushed
```

`origin/main` equals local `main`, so a push after the merge would be a plain fast-forward of the remote
by one merge commit. **I did not fetch and did not push.** My `origin/main` reading is therefore as of the
last fetch by someone else — if a lot of time has passed, re-run `git fetch` before acting on this line.

**The human's pre-existing dirty state — verified untouched.** The canonical checkout carries 40 modified
`apps/control_plane/test/failures/*.png`, modified design-brief files, `melos_shipit_platform.iml`,
one **staged** `docs/engineering/WORK_STATE.md` (+39/-12), and ~20 untracked `.sql` / scratch files. **I
staged nothing, cleaned nothing, discarded nothing, and ran no `checkout`/`reset`/`restore`/`stash` in that
checkout.** My overlap check proved the merge writes **none** of those paths (the 9 merge paths ∩ dirty
paths = empty), so the merge does not need a clean tree there — only the staged `WORK_STATE.md` interacts
with `git merge` in the way §4b documents, and `--ff-only` is unaffected.

**Rehearsal artifacts:** two throwaway worktrees (`shipit-integrate-staged-probe`,
`shipit-integrate-staged-probe2`) were created and **removed with `git worktree remove --force`**; I
verified they are gone from `git worktree list`. The main rehearsal worktree
`/private/tmp/shipit-integrate-cred-identity` is **left in place** — it holds the merge commit `08c7590`,
which is otherwise unreferenced, and it is the tree every gate above ran on. Remove it with
`git worktree remove --force /private/tmp/shipit-integrate-cred-identity` once `main` has advanced.

## 8. The evidence question — the lost-evidence problem, third occurrence

All four reports **exist on disk**. Their commit state:

| Report | On disk | On `main` | Staged |
|---|---|---|---|
| `review-credential-identity-invariants/report.md` | ✅ | ✅ **committed on `main`** | yes (part of the staged `WORK_STATE.md` batch's index) |
| `review-credential-identity-invariants-rereview/report.md` | ✅ | ❌ | ❌ |
| `correct-credential-identity-invariants-guard/report.md` | ✅ | ❌ | ❌ |
| `review-credential-identity-invariants-final/report.md` | ✅ | ❌ | ❌ |

So: **one of the four is on `main`; three are untracked and unstaged**, and the three untracked ones
include **the authorisation for this merge itself**. `3f3f4f4` and `a4c211c` commit the 9 code files only.

**I did not commit them** — they are not mine to commit and the Manager's bookkeeping has not staged them.
This is exactly the pattern the re-review flagged for the rev5 design review and called "a third place";
it is now live again, and **the missing evidence is the merge approval itself**. Recommended to the
Manager, in the same commit that lands the merge: add the three untracked report directories under
`docs/engineering/dispatch/tasks/`. That commit would also be the natural home for `T2` (the `D-6` eighth
column) and `T4`, neither of which is currently in `WORK_STATE.md` or `LANES.md` — the final review's §11
step 2, still outstanding.

## 9. What the merge would do, and the exact command

**What it does:** creates one merge commit on `main` with parents `289f1d3` and `a4c211c`, tree `5b66ae0`
(already computed and verified). It brings in 9 code files (+1775/-95) and changes **no** documentation,
decision or design file on `main` — main's 23 documentation commits pass through untouched. Then it
fast-forwards `origin/main` by that one commit.

**Preferred command — the merge commit, in a clean auxiliary worktree.** This is what I rehearsed, and it
is the shape that provably works:

```sh
# 1. rehearsals a merge commit on top of main, in a throwaway detached worktree
git -C /Users/alkebut/air/shipit-platform worktree add --detach /private/tmp/shipit-merge-cred main
git -C /private/tmp/shipit-merge-cred merge --no-ff \
    fix/credential-identity-invariants \
    -m "Merge fix/credential-identity-invariants: refuse credential re-pointing and re-mint, both tiers (D-4/D-18/D-5) + schema-guard IF NOT EXISTS expectation (MEDIUM), LOW-1 store contract"
MERGE_SHA=$(git -C /private/tmp/shipit-merge-cred rev-parse HEAD)

# 2. fast-forward main to it. --ff-only is verified to succeed even with the
#    staged docs/engineering/WORK_STATE.md in the canonical checkout,
#    and leaves that staged edit intact.
git -C /Users/alkebut/air/shipit-platform merge --ff-only "$MERGE_SHA"

# 3. push, after the human approves
git -C /Users/alkebut/air/shipit-platform push origin main
```

If the rehearsal worktree is kept instead of rebuilt, `MERGE_SHA` is `08c7590` and step 1 can be skipped —
but then main is fast-forwarding onto a commit whose gates I ran, which is the same thing and is
preferable. **Re-run `dart pub get` and the gates if a fresh worktree is used**, since the first
`dart format` in an unresolved worktree reports spurious changes (§4a).

**The command I did not run, and why.** Merging directly in the canonical checkout
(`git merge --no-ff fix/credential-identity-invariants`) is **blocked** by the staged `WORK_STATE.md`
(§4b). Resolving that means committing or unstaging a file that is not mine — so I stopped and reported it
rather than deciding. Note the reviewed SHAs `3f3f4f4` and `a4c211c` remain reachable either way, so a
delay costs nothing; what a delay costs is the revocation hole staying open.

**No force-push, no amend of anything reachable from a ref, no squash, no rebase, no `git push` of any kind
was performed by me.**

## 10. Docker disclosure — no breach

- **`make test-integration` — 4 invocations, and nothing else.** No `docker` or `docker compose` command
  of any other form was issued by me: no `up`, `down`, `stop`, `rm`, `prune`, `volume rm`, `pull`,
  `build`, `--rmi` — **and none of the read-only-looking ones either**: no `compose ps`, `compose logs`,
  `compose config`, `docker info`.
- **Never** `make clean`, `make test-env-down`, `make e2e-down`, or any bare
  `docker compose … down -v` without `-p <project>`. I did not test that rule.
- I read the `test-integration` recipe **as text** (`Makefile:191-230`) before running it: it declares its
  own compose project `shipit_integration_$$$$`, has an unconditional `down -v --remove-orphans` under that
  project, and a labelled leak check. That is why it is the sanctioned target and the only thing I used.
- **All four runs tore down their own project and reported removal** —
  `shipit_integration_75894`, `_77024`, and two further runs: each printed `Container … Removed` and
  `Network … Removed`. **`CLEANUP FAILED` count: 0, 0, 0, 0.**
- The known cosmetic artefact appeared as documented: after the suite's own `Some tests failed`, the trap
  removes the project successfully and `make` still prints `Error 1`/`Error 2` from the recipe. Not a leak.

**No breach to disclose.**

## 11. Tracked items carried forward, not absorbed

Not mine, not blocking this merge, and **not fixed by me**:

- **T4** — the D-4 concurrency test's order-dependence. Does not block. **Fix the behaviour, not the
  test** (mint-branch read-back), before `20261006150645000` reaches a deployed database.
- **T2** — `D-6`'s eighth column (`lastFailureReason`), guarded on neither tier, latent and unreachable
  via any engine path. Required before `20261006150645000` ships. Still absent from `WORK_STATE.md` /
  `LANES.md`.
- **T3** — the `asset-only` asymmetry caveat on
  `design_revision_approved_unique_per_work_item`, now written down at the declaration so a human must
  look at it. Deliberately unresolved.
- **F** — wire `apps/server/tool/tests/verify_schema_bootstrap_negative_controls.sh` into
  `.github/workflows/ci.yaml`. Twelve green controls that no push runs is **not** a gate.
- **Duplicate-credential audit** — must be run by a human against **every deployed database** before
  `20261006150645000`. Unchanged.
- **`CredentialIdentityConflictException`** — still needs an `exceptions.dart` ownership grant.
- **`design-revision-5.md` is `DESIGN_REVIEW_CHANGES_REQUIRED`** and its review report is untracked —
  the same lost-evidence problem in a third place (§8).

## 12. Result

```
RESULT: READY_FOR_INTEGRATION

APPROVED_HEAD: a4c211ccd1d094b4955f56f7d9ae385e377bb15f   verified == branch tip, clean tree
BASE_SHA:      0bf2fa0058bbbab12eeea43b4e6a50eadff07b4d   merge-base(HEAD, main), verified
CURRENT_MAIN:  289f1d33dcf1a2f24ead765c9e573b2f1ba1f107   == origin/main, both unmoved by this lane
MERGE_COMMIT:  08c75902a9c0a1643424f4576b58872c8291b289   rehearsed only — NOT on main
MERGE_TREE:    5b66ae098027363d67c623f05b1f8e54d3e4c116   == merge-tree's predicted tree, byte-identical

GATES (on the merged tree 08c7590):
  format    = PASS  631 files / 0 changed, exit 0                    (baseline exact)
  analyze   = PASS  exit 0, 2 infos, both packages/workflow_engine    (baseline exact)
  tests     = PASS  product_registry +148 All tests passed, exit 0   (baseline exact)
              integration 4 runs, +171 -1 on every run; sole failure
              dogfood_shipit_postgres_test.dart:87 (pre-existing, file not in the merge diff)
  build     = NOT_RUN  no build step in this stack; not applicable
  runtime   = PASS  schema guard 20 OK / 0 FAIL, exit 0
              negative controls 12 cases / 0 failed, exit 0

T4 DISPOSITION: did not reproduce — 0 of 4 runs. Failing test named on every run (dogfood :87),
              confirmed NOT T4 and NOT a merge artifact. -2 never observed, so obligation (b)
              never triggered and obligation (c) never reached. The suite remains
              non-deterministically green in principle; the final review's non-blocking
              disposition is unchanged and I did not touch the test.

PROVENANCE:
  branch        fix/credential-identity-invariants @ a4c211c, tree clean
  worktree      /private/tmp/shipit-credential-identity — clean, unmoved
  canonical     /Users/alkebut/air/shipit-platform @ main 289f1d3 — unmoved; human's dirty and
                staged state untouched (nothing staged, cleaned or discarded by me)
  remote        origin/main = 289f1d3 == local main (as of last fetch by someone else; I did not fetch)
  strategy      merge commit (--no-ff). FF impossible (diverged). No rebase, no squash, no amend,
                no force-push, no push. Approved SHAs stay addressable.
  conflict      none — merge-tree exit 0 and the rehearsal merge produced the predicted tree exactly;
                main's 23 paths that HEAD lacks are all docs/decisions, zero overlap with the 9
  docker        make test-integration x4 and nothing else; 0 CLEANUP FAILED; no breach
  evidence      all 4 reports on disk; review-credential-identity-invariants/report.md is on main,
                the other THREE (including the merge authorisation) are untracked and unstaged —
                reported, NOT committed by me

READY_FOR_INTEGRATION: YES
  Safe strategy: one merge commit on main, parents 289f1d3 + a4c211c, tree 5b66ae0, then
  fast-forward origin/main by that one commit. Proven conflict-free and already performed once
  in a throwaway worktree with every gate green on the resulting tree.
  Human/deployment authority still REQUIRED before any actual write: merging into main and pushing
  origin are the Manager's and the human's calls, and I stopped before both.
  Two things for the human/Manager to decide, neither of which I touched:
    (1) the canonical checkout has docs/engineering/WORK_STATE.md STAGED, which blocks a direct
        `git merge --no-ff` there; the preferred command above (merge in a clean worktree, then
        `git merge --ff-only <sha>`) is verified to work with that staged edit intact.
    (2) the three untracked review reports — including the APPROVE_CORRECTIONS verdict that authorises
        this merge — should land in the same commit, or the provenance for this security fix is lost
        exactly as it has been twice already in this work item.
  Until that decision is taken, a REVOKED CREDENTIAL REMAINS RESURRECTABLE ON main.
```

**One line for the Manager:** everything mechanical is done and verified — the merge is conflict-free,
gates are exact on the merged tree, provenance is clean, and nothing here needs fixing. What remains is
one decision — merge and push — and while it is pending the security hole this work item exists to close
is still open on `main`.
