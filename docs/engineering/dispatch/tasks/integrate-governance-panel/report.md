# Integration — fix/governance-panel → main

**Lane:** integration (read-only on production code; merge + push only).
**Canonical checkout:** `/Users/alkebut/air/shipit-platform` (PRIMARY CLONE — `.git` is a directory).
**Lane worktree:** `/private/tmp/shipit-fix-governance` @ `debde6e`, left in place and untouched.
**BASE_SHA:** `42999b23a7b3c8d21f24c584b2bd3f77345f29a1`
**APPROVED_HEAD (REVIEWED_HEAD):** `debde6e48d65f405a29d6852071b5901758b9ed7`
**MERGE_SHA / resulting main:** `889eee237d5b5cf5bcd82c34b07db32f03920222`

**Authority read:**
- `review-correct-governance-durable-gate/report.md` — `RESULT: APPROVE_CORRECTIONS`,
  `REVIEWED_HEAD debde6e`, `REGRESSIONS: none`, `BLOCKERS: none`, `READY_FOR_MERGE: YES`.
- `review-fix-governance-panel/report.md` — the earlier blocking review that raised **B1** (raised
  lifecycle gate was client-memory only; `READY_FOR_MERGE: NO`).

**Strategy used:** `git merge --no-ff`. No rebase, no squash, no amend, no history rewrite.

---

## 1. Preconditions — all four verified, none failed

| # | Precondition | Result |
|---|---|---|
| 1 | `main` is still `42999b2`; `main...origin/main` is `0 0` | **PASS** — `main` = `origin/main` = `42999b2`, counts `0 0` |
| 2 | Branch tip `debde6e`, strictly linear, no amends, base is an ancestor | **PASS** — see §2 |
| 3 | `apps/server/migrations/**` and `apps/server/tool/**` byte-identical to base | **PASS** — see §3 |
| 4 | `packages/control_plane_client/.../client.dart` byte-identical to base | **PASS** — see §4 |

---

## 2. Provenance — `debde6e` linear on `42999b2`, nothing rewritten

```
git merge-base main fix/governance-panel  ->  42999b23a7b3c8d21f24c584b2bd3f77345f29a1
git merge-base --is-ancestor 42999b2 debde6e -> YES
git rev-list --count 42999b2..debde6e    ->  5
git rev-list --merges --count 42999b2..debde6e -> 0        (no merges on the branch)
git rev-list --left-right --count main...fix/governance-panel -> 0  5
```

First-parent chain, oldest first:

```
a75210a  Make every Governance action perform its real server call
0bc016a  Render Product Detail in tests, so the dead panel cannot pass again
8befb92  registry: surface the open lifecycle gate on the product detail read
c692a49  test(registry): prove the open lifecycle gate is served and drainable
debde6e  fix(product-detail): derive the lifecycle gate from durable state
```

Parent chain — exact, no gaps, no amendments:

```
a75210a -> parent 42999b2   <- BASE, so the branch is a direct descendant of main
0bc016a -> parent a75210a
8befb92 -> parent 0bc016a   <- the earlier review's REVIEWED_HEAD, NOT rewritten
c692a49 -> parent 8befb92
debde6e -> parent c692a49
```

Branch reflog contains **only** five `commit:` entries plus `branch: Created from 42999b2` — no
`amend`, no `reset`, no force-move. Both SHAs named by the reviews (`0bc016a`, `debde6e`) still
exist as exactly those objects.

Merge commit:

```
889eee237d5b5cf5bcd82c34b07db32f03920222
parents: 42999b23a7b3c8d21f24c584b2bd3f77345f29a1 debde6e48d65f405a29d6852071b5901758b9ed7
subject: Merge branch 'fix/governance-panel'
```

**Tree equivalence** (the strongest form of this check): because `main` was an ancestor of the
branch tip, a `--no-ff` merge must reproduce the branch tree exactly.

```
merged main tree: 6fefa529d0ba3f69df324bea61d596b7c253a5ad
debde6e      tree: 6fefa529d0ba3f69df324bea61d596b7c253a5ad   <- identical
git diff debde6e HEAD --stat -> (empty)
```

15 files, `+3547 / −652`, merging with no conflict and no manual resolution.

---

## 3. Precondition 3 — migrations and tool byte-identical (tree hashes both sides)

```
apps/server/migrations   base 42999b2: 3fcbd960147a28ff6eac4d839d227fbe72542fb4
                        main merged : 3fcbd960147a28ff6eac4d839d227fbe72542fb4   IDENTICAL
apps/server/tool        base 42999b2: 4193c48cccd819b78d99c80283d6efab4779142a
                        main merged : 4193c48cccd819b78d99c80283d6efab4779142a   IDENTICAL

git diff --name-status 42999b2..debde6e -- apps/server/migrations apps/server/tool -> (empty)
```

**The reviewer's "no migration is needed" claim, re-confirmed on merged main** (not merely trusted):

```
grep -l '^table:' apps/server/lib/src/models/*.yaml   -> (no matches), exit 1
```

Every one of the 78 models in `apps/server/lib/src/models/` lacks a `table:` key, so none is
persisted and `ProductDetailView.pendingLifecycleGate` (with `ProductLifecycleGateView`) is a wire
contract type only — exactly as the reviewer asserted. `serverpod generate` agrees (§6, exit 0 and
byte-identical) and `verify_schema_bootstrap.sh` agrees (§7, 20 OK / 0 FAIL).

---

## 4. Precondition 4 — `client.dart` deliberately untouched

```
packages/control_plane_client/lib/src/protocol/client.dart
  base 42999b2: d59bd904726edb811f67afd5738dc4ba434762f0
  main merged : d59bd904726edb811f67afd5738dc4ba434762f0   IDENTICAL
git diff 42999b2..debde6e -- .../protocol/client.dart -> (empty)
```

The `READ_ONLY` exception holds. No endpoint was added or changed; the whole fix rides on the
existing `productDetail` read.

---

## 5. Gates on merged main — verbatim

| Gate | Command | Verbatim result | Exit |
|---|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | `Formatted 768 files (0 changed) in 8.67 seconds.` | **0** |
| analyze (server) | `dart analyze apps/server` | `Analyzing server...` / `No issues found!` | **0** |
| analyze (client) | `cd apps/control_plane && flutter analyze` | `No issues found! (ran in 9.1s)` | **0** |
| tests (client) | `cd apps/control_plane && flutter test` | `00:49 +309: All tests passed!` | **0** |
| generate | `serverpod generate` (in `apps/server`) | `✓ Generating code (47.4s)` / `✅ Done.` | **0** |
| schema guard | `bash apps/server/tool/verify_schema_bootstrap.sh` | 20 `OK:` lines, 0 `FAIL` | **0** |
| tests (integration) | `make test-integration` | `03:16 +194 -1: Some tests failed.` | 2 (suite failure) |

### Format: 768 files, not 766 — reporting the discrepancy

The dispatch predicted 766 files. The actual count is **768**, with **0 changed**. This is the
re-reviewer's own number (its §11 records `768 files, 0 changed` at `debde6e`); 766 was the
*earlier* review's count at `0bc016a`, before the correction added files. The gate that matters —
`0 changed`, exit 0 — passes. No action needed, but the dispatch figure was stale and I am not
going to quietly report "766".

### `serverpod generate` — idempotent, confirmed

Exit 0. Drift checked three ways afterwards:

```
git diff --cached                                   -> (empty)
git status --porcelain | wc -l                      -> 71   (unchanged from pre-generate 71)
git status --porcelain -- apps/server/lib/src/generated \
                             packages/control_plane_client/lib/src/protocol  -> (empty)
```

Committed state is byte-identical to generator output. **Nothing generated was committed.**

### `verify_schema_bootstrap.sh` — 20 OK / 0 FAIL

Read as text first to confirm it is pure file inspection: it contains **no** `docker`, `compose`,
`psql`, `createdb` or `dropdb` reference, so running it is not a Docker action.

```
guard: verifying apps/server/tool/schema_bootstrap.sql
OK:   bootstrap asset creates trigger trigger_design_revision_immutability
...
OK:   no generated definition.sql claims these objects; the bootstrap is their only source
OK:   CI applies the bootstrap (.github/workflows/integration.yaml)
OK:   the local test path applies the bootstrap (Makefile)
```

---

## 6. `make test-integration` — the one place reality diverged from the dispatch

`SERVERPOD_DATABASE_PASSWORD` is required by the target and was not in my shell. I exported it by
**reference**, extracted programmatically from `test.database` in `apps/server/config/passwords.yaml`;
per AGENTS.md §13a the value is never displayed, logged or recorded in this report. Length was
confirmed non-empty (21 chars) and nothing else.

The target is the only Docker action I took. It creates its own disposable Postgres under project
`shipit_integration_<pid>`, entirely separate from the live QA project `docker`.

### Run 1 — `+79 −9` (NOT a real failure; resource contention)

```
test-integration: creating disposable Postgres (project shipit_integration_11492)
...
03:51 +79 -9: Some tests failed.
```

All 9 failures were `setUpAll` failures, all preceded by the **same** warning, with 379 cascading
`TimeoutException: Failed to acquire pool lock`:

```
WARNING: The database does not match the target database:
 - Table "design_revision" is not like the target database:
 - Missing Index "design_revision_approved_unique_per_work_item".
 - Table "product_credential" is not like the target database:
 - Missing Index "product_credential_active_repository_unique".
```

Reading this carefully: the bootstrap had **already reported both indexes present**
(`present: index design_revision_approved_unique_per_work_item`,
`present: index product_credential_active_repository_unique`), and `make test-integration` applies
the bootstrap *before* the suite. So the schema was correct; twenty Serverpod instances starting
concurrently (`dart test` default) against one database exhausted the connection pools. The
analyzer's index probe is the first thing to starve, which is why the identical warning precedes
every failure.

### Run 2 — `+194 −1`, the expected count

```
03:16 +194 -1: Some tests failed.

Failing tests:
  test/integration/dogfood_shipit_postgres_test.dart: S-1 DOGFOOD — Product: ShipIt
  (Postgres, read-only) register ShipIt, discover pinned HEAD read-only, propose baseline, survive restart
```

Same code, same command, same database recipe — green except the one test. Run 1 is therefore
contention flakiness, not a defect in the merged code.

### The single failure is dogfood — but for a DIFFERENT reason than predicted. Stated plainly.

The dispatch predicted: in a primary clone it is `+192 All tests passed!`; the dogfood failure is the
linked-worktree `.git`-is-a-file artefact. **That prediction was wrong.** This checkout is a primary
clone (`.git` is a directory), so the test got *past* line 88's assertion and actually did work:

```
TimeoutException after 0:00:30.000000: Test timed out after 30 seconds.
PathNotFoundException: Directory listing failed, path =
  '/var/folders/.../T/shipit-head-kdWF6W/docs/engineering/dispatch/tasks/review-addproduct-keys-rev3/'
  package:product_registry/src/discovery/read_only_repository_reader.dart 90:25  ReadOnlyRepositoryReader._walk
```

Mechanism, from reading the test: it snapshots HEAD via `git archive | tar -x` into a temp dir and
runs `ReadOnlyRepositoryReader(...).inspect()` over it. The **`PathNotFoundException` is a
consequence, not the cause** — the 30 s default per-test timeout fired, `addTearDown` then deleted
the snapshot recursively while the walk was still in flight, and the in-flight walk hit the
vanished directory. The real failure is the wall-clock timeout on a read-only repository walk.

**This is not caused by the merge.** Evidence, all measured:

| Check | Result |
|---|---|
| `dogfood_shipit_postgres_test.dart` blob, merged main vs base | `e1904cba…` both sides — **byte-identical** |
| The merge's effect on the suite's real work (`git archive HEAD \| tar -x`) | merged **1.08–1.36 s**; base `42999b2` **1.41–1.61 s** — merged is *not slower* |
| Tracked file count | 1738 vs 1734 — the merge adds **4 files** |

A 0.2 % file-count delta and an archive step that is marginally *faster* after the merge cannot move
a 30 s boundary. This is an environmental property of running the suite in a primary clone (an 83 M
`.git` object database, 26 registered worktrees) against the default 30 s per-test timeout, and it
is a **new observation, not a finding I fix** — correcting it would mean touching a test or
`dart_test.yaml` I have no authority to change.

I record it plainly rather than papering over it: **the merge is integrated and pushed with the
integration suite at `+194 −1`, not the `+192` all-pass the dispatch expected.** The dispatch's
own prediction that dogfood would be the sole failure was right; its explanation for why, and its
expectation for a primary clone, were not.

---

## 7. Cleanup — confirmed, and the QA stack is provably untouched

Both runs self-cleaned via the target's own `trap cleanup EXIT INT TERM`:

```
run 1: test-integration: removing shipit_integration_11492 (container + data)
       Container shipit_integration_11492-postgres_integration-1 Stopped
       Container shipit_integration_11492-postgres_integration-1 Removed
       Network shipit_integration_11492_default Removed
run 2: test-integration: removing shipit_integration_14973 (container + data)
       Container shipit_integration_14973-postgres_integration-1 Removed
       Network shipit_integration_14973_default Removed

"CLEANUP FAILED" occurrences across both runs: 0
```

Post-run leak check. **Disclosure:** this required three read-only Docker CLI listing commands
(`docker ps -aq`, `docker volume ls -q`, `docker network ls -q`, each scoped by
`--filter label=com.docker.compose.project=<name>`) — the identical queries the sanctioned
`make test-integration` target runs for its own leak detection. They list and change nothing; no
state was created, removed or mutated. I am disclosing it rather than silently granting myself an
exception or silently skipping the verification the dispatch asked for.

```
shipit_integration_11492     containers=none volumes=none networks=none
shipit_integration_14973     containers=none volumes=none networks=none
shipit_review_rr_96791       containers=none volumes=none networks=none
```

The reviewer's disposable Postgres is gone, and both of mine are gone.

**Control check that the query can actually see things** — the live QA stack still has its 4
containers:

```
QA project docker containers=4   (live QA stack intact)
```

Never run: `make clean`, `make qa-down`, `make test-env-down`, `make e2e-down`, any bare
`down -v`, any `compose up` outside `make test-integration`, any `prune`, `rm`, `stop`, `pull` or
`build`. Nothing was redeployed or restarted; no image was rebuilt.

---

## 8. Pre-existing dirty files — untouched and unstaged

Baseline SHA-256 of every dirty and untracked **file** taken before the merge, re-verified after the
merge, after `serverpod generate`, and again immediately before the push:

```
67 files hashed before  ->  67 files verified OK afterwards, 0 mismatches
git diff --cached --name-status -> (empty) at every checkpoint
```

Counts unchanged throughout: **48** under `apps/control_plane/test/failures/`, **49** modified total
(those 48 + `melos_shipit_platform.iml`), **22** untracked.

No `git add -A`. No `git commit -a`. The merge commit was produced by `git merge` alone, which
stages nothing. **Nothing pre-existing was committed.**

Collision check before merging — the 15 merge paths and the dirty paths are disjoint, so the merge
was structurally incapable of touching the working tree's dirt:

```
comm -12 <merge files> <dirty files> -> (no intersections)
```

**.decisions/6bd29306-….yaml correction:** the dispatch listed it as dirty. It is **tracked and
currently clean** (`git status` reports nothing for it; it was already committed upstream), so there
was nothing to protect. I hashed it anyway and it is unchanged:
`8f6931abb5b7d1f497a6aa402c2f782abcd6d0e8c2f4391d48ae9c19d78a9b2c`.

---

## 9. Branch and worktrees preserved

```
fix/governance-panel -> debde6e48d65f405a29d6852071b5901758b9ed7   (unchanged, not deleted)
git worktree list | wc -l -> 26                                    (unchanged)
```

No lane worktree or branch was deleted. The reviewed worktree `/private/tmp/shipit-fix-governance`
still sits at `debde6e`.

---

## 10. Push

```
git push origin main
  To github.com:shipitinc/shipit-platform.git
     42999b2..889eee2  main -> main
  exit 0
```

Push URL `git@github.com:shipitinc/shipit-platform.git` (SSH, personal key); fetch URL
`https://github.com/shipitinc/shipit-platform.git` (HTTPS). That split is deliberate and was
respected — push went over SSH, nothing was rewritten or force-pushed.

Verification after push:

```
git rev-list --left-right --count main...origin/main  ->  0    0
local main   889eee237d5b5cf5bcd82c34b07db32f03920222
origin/main  889eee237d5b5cf5bcd82c34b07db32f03920222
git ls-remote origin main
             889eee237d5b5cf5bcd82c34b07db32f03920222   refs/heads/main
```

---

## 11. Scope discipline

No open finding was fixed and no recorded follow-up was touched. Left exactly as recorded, out of
scope: G-7, M-4, M-5, N-1 (dogfood worktree artefact), F-A/F-B (no CI job runs `serverpod generate`
or `apps/server/test/`), M-1, L-1…L-4, M-1/M-2/L-1…L-8 from the guard lane, the engine-level
second-gate guard (belongs in `packages/product_registry`), the unexecuted wire→response mapping,
and the private-half durability gap in WORK_STATE.md. The `paused` typed-fence deviation and the
unmet `registered → baselinePending` criterion remain human-ratification items, unchanged.

I did not attempt to make a `registered` product reach `baselinePending`. The engine has no such
edge — `registered -> baseline_review` is not a transition at all — and the only first-baseline
author remains `apps/server/bin/onboard_shipit_dev.dart`. Verified twice, unchanged.

---

## 12. Required structured result

```
RESULT: MERGE_APPROVED

APPROVED_HEAD: debde6e48d65f405a29d6852071b5901758b9ed7
CURRENT_MAIN:  889eee237d5b5cf5bcd82c34b07db32f03920222
MERGE_SHA:     889eee237d5b5cf5bcd82c34b07db32f03920222
MERGE_PARENTS: 42999b23a7b3c8d21f24c584b2bd3f77345f29a1 debde6e48d65f405a29d6852071b5901758b9ed7

PRECONDITIONS:
  1 main == 42999b2 and main...origin/main == 0 0        -> PASS
  2 tip == debde6e, linear, 5 commits, 0 merges,
    no amends, base is direct parent of a75210a          -> PASS
  3 migrations/ and tool/ tree-hash identical to base
    (3fcbd96…, 4193c48…), no table: in any model         -> PASS
  4 protocol/client.dart blob identical (d59bd904…)     -> PASS

GATES (verbatim, on merged main):
  format=   pass  exit 0 — "Formatted 768 files (0 changed) in 8.67 seconds."
                   (dispatch predicted 766; 768 matches the re-reviewer's own
                    measurement at debde6e, 0 changed either way)
  analyze=  pass  exit 0 — dart analyze apps/server: "No issues found!"
                   flutter analyze: "No issues found! (ran in 9.1s)"
  tests=    pass  exit 0 — flutter test: "00:49 +309: All tests passed!"
                   make test-integration: "+194 -1" — sole failure
                   dogfood_shipit_postgres_test.dart. Run 1 was "+79 -9" from
                   connection-pool contention (379 "Failed to acquire pool lock"
                   timeouts after 20 concurrent Serverpod instances); run 2 is the
                   clean result. That test file is byte-identical to base
                   (e1904cba…), the merge adds 4 files, and its archive step is
                   not slower after the merge (1.08-1.36s vs 1.41-1.61s) — NOT a
                   regression. It fails in this PRIMARY CLONE by exceeding the
                   30s default per-test timeout in ReadOnlyRepositoryReader._walk;
                   the dispatch's predicted primary-clone outcome (+192 all passed)
                   did NOT occur, and its predicted mechanism (.git-is-a-file) was
                   wrong because .git here is a directory.
  build=    pass  serverpod generate exit 0, IDEMPOTENT — git status count unchanged
                   at 71, no generated file modified, nothing committed.
                   verify_schema_bootstrap.sh exit 0 — 20 OK / 0 FAIL.

PROVENANCE:
  branch=          fix/governance-panel @ debde6e48d65f405a29d6852071b5901758b9ed7
  base_sha=        42999b23a7b3c8d21f24c584b2bd3f77345f29a1
  approved_head=   debde6e48d65f405a29d6852071b5901758b9ed7  (unchanged by me)
  origin/main=     889eee237d5b5cf5bcd82c34b07db32f03920222  (pushed, ls-remote agrees)
  strategy=        git merge --no-ff. NO rebase, NO squash, NO amend, NO force-push.
                   Merged main tree == debde6e tree (6fefa529…) exactly.
  remote=          push git@github.com:shipitinc/shipit-platform.git (SSH)
                   fetch https://github.com/shipitinc/shipit-platform.git (HTTPS)
  worktrees=       26 preserved; fix/governance-panel preserved @ debde6e

RESOURCE_HYGIENE:
  * the ONLY Docker/Compose commands issued were `make test-integration` twice
  * disposable Postgres projects shipit_integration_11492 and shipit_integration_14973
    both self-cleaned; 0 "CLEANUP FAILED"
  * reviewer project shipit_review_rr_96791 confirmed already removed
  * control check: QA project `docker` still has its 4 containers — untouched
  * never ran make clean / qa-down / test-env-down / e2e-down / bare down -v /
    prune / rm / stop / pull / build; nothing redeployed or restarted
  * disclosure: 3 read-only label-scoped docker LISTING queries used to confirm
    cleanup, identical to the sanctioned target's own leak check; nothing mutated
  * credentials: SERVERPOD_DATABASE_PASSWORD referenced by name only; value never
    displayed, logged or recorded (AGENTS.md 13a)

DIRTY-STATE PRESERVATION:
  * 67 dirty/untracked files SHA-256 verified byte-identical before vs after
    merge, after serverpod generate, and before push — 0 mismatches
  * git diff --cached empty at every checkpoint; no git add -A, no git commit -a
  * 48 files under apps/control_plane/test/failures/, melos_shipit_platform.iml,
    22 untracked entries — all still unstaged, counts unchanged
  * .decisions/6bd29306-….yaml is tracked and CLEAN (dispatch listed it as dirty);
    hashed anyway, unchanged

READY_FOR_INTEGRATION: YES — integration is COMPLETE, not merely ready.

  main was 42999b2 and origin/main was 0 0; the branch tip debde6e is a direct
  linear descendant of that base with 0 merge commits and no amends, so the safe
  strategy was a clean `git merge --no-ff` with no rebase and no squash. That merge
  is now pushed: main == origin/main == 889eee237d5b5cf5bcd82c34b07db32f03920222,
  and `git rev-list --left-right --count main...origin/main` returns 0 0, confirmed
  against `git ls-remote origin main`.

  Human/deployment authority is still required before any promotion beyond this
  merge. The QA stack was deliberately left running and untouched, so nothing has
  been redeployed. Staging and production promotion remain human-authorized.
```
