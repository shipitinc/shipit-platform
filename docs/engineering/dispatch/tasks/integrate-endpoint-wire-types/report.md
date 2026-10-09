# Integration — fix/credential-endpoint-return-types

```
RESULT: MERGE_APPROVED

APPROVED_HEAD: dcf1edeeadfbeef3b324cc885524c472f5b34db0
CURRENT_MAIN:  a5c46e93c8916375e63b5e542fc610f5314c4383

GATES:
format=    PASS — exit 0 — "Formatted 765 files (0 changed)"
analyze=   PASS — exit 0 — "No issues found!" (server) / "No issues found!" (control_plane)
tests=     PASS — exit 0 — flutter test "+271 All tests passed!"; make test-integration "+192 All tests passed!", zero failures
build=     PASS — exit 0 — serverpod generate exit 0, byte-identical (idempotent); verify_schema_bootstrap.sh exit 0, 20/20 OK

PROVENANCE:
  base          cf1b2106b75238da4b43ebbff05e06414f2793ed
  approved head dcf1edeeadfbeef3b324cc885524c472f5b34db0
  merge commit  a5c46e93c8916375e63b5e542fc610f5314c4383  (parents: cf1b210 + dcf1ede)
  resulting main a5c46e93c8916375e63b5e542fc610f5314c4383
  origin/main   a5c46e93c8916375e63b5e542fc610f5314c4383
  ahead/behind  0 0
  push          cf1b210..a5c46e9  main -> main  (fast-forward, no force)
  merged tree   310b4fe969ffeb8a11afea6ca856d5eba685629c == dcf1ede tree (byte-identical)

READY_FOR_INTEGRATION: YES — merged and pushed to origin/main. Safe strategy was
  `git merge --no-ff` (no rebase, no squash; all five reviewed SHAs preserved and reachable).
  NO further human or deployment authority is required for the merge itself.
  The QA-stack redeploy and the browser hop remain yours, as you stated.
```

---

## Authority

The final approving review was read **first** and is the authority for this lane:
`docs/engineering/dispatch/tasks/review-correct-endpoint-wire-types-r2/report.md` —
`APPROVE_CORRECTIONS`, `REVIEWED_HEAD: dcf1ede…`, `REGRESSIONS: None`, `BLOCKERS: None`,
`READY_FOR_MERGE: YES`. Its `REVIEWED_HEAD` matches the dispatch's `NEW_HEAD` exactly.

The earlier blocking review
(`docs/engineering/dispatch/tasks/review-fix-credential-endpoint-types/report.md`,
`DO_NOT_MERGE`, blockers **B-1** and **B-2**) was also read. B-1 was the real blocker:
`productRegistryEndpoints.addRepositoryReference` returned a non-empty
`Map<String, dynamic>`, which makes the generated client's `deserialize<dynamic>`
throw `No deserialization found for type dynamic` — and it is called at
`add_product_page.dart:281` immediately **before** the deploy-key mint at `:147`.
B-2 was the `__className__` assertion in `credential_key_service_postgres_test.dart`.

Both are visibly closed on merged main:

```
product_registry_endpoints.dart:525   Future<RepositoryReferenceAddedView> addRepositoryReference(
control_plane_client/.../client.dart:976  => caller.callServerEndpoint<_i28.RepositoryReferenceAddedView>(
```

## Preconditions — all verified before the merge

| # | precondition | result |
|---|---|---|
| 1 | main is `cf1b210`, `main...origin/main` is `0 0` | **PASS** — both exactly `cf1b210…` |
| 2 | commits linear, no amends, base is ancestor | **PASS with a correction** — see below |
| 3 | `migrations/**` and `tool/**` byte-identical to base | **PASS** — tree hashes equal on both sides |
| 4 | no new file under `migrations/**` | **PASS** — 0 additions |

```
apps/server/migrations   base=3fcbd960147a  main=3fcbd960147a   IDENTICAL
apps/server/tool         base=4193c48cccd8  main=4193c48cccd8   IDENTICAL
git diff --name-status cf1b210..dcf1ede -- migrations tool  →  (empty)
git diff --diff-filter=A --name-only cf1b210..HEAD -- migrations  →  0
```

### Precondition 2 — the commit count is FIVE, not four

The dispatch said *"FOUR commits (two original + two corrections)"*. Measured:

```
git rev-list --count cf1b210..dcf1ede   →  5
```

The real composition is **2 original + 3 corrections**:

| SHA | role |
|---|---|
| `fc76d39` | original — return typed models from the credential endpoints |
| `77d984a` | original — prove the wire boundary, read the client as a model |
| `0dab461` | correction — the no-private-material sweep must name `__className__` (fixes **B-2**) |
| `72e90a5` | correction — no endpoint declares a raw map return type, all 22 (fixes **B-1**) |
| `dcf1ede` | correction — scan the whole generated client, not a list of two names (fixes **H-2**) |

**This is an arithmetic slip in the dispatch prose, not unreviewed work, and it does not block.** The
designated authority resolves it explicitly and in my favour: the R2 review states
`CORRECTED_FROM_HEAD: 77d984a` and lists *"commits on top of `77d984a`: `0dab461`, `72e90a5`,
`dcf1ede` (4 with `77d984a` inclusive)"* — i.e. it enumerates all three correction commits by SHA and
approves `dcf1ede`. The correction lane's own report carries the same
`CORRECTED_FROM_HEAD: 77d984a` → `NEW_HEAD: dcf1ede`. Every commit between base and the approved HEAD
is therefore named by the authority, and the approved HEAD is exactly the dispatch's `NEW_HEAD`.

I verified the rest of precondition 2 directly rather than by prose:

- **strictly linear** — each commit's parent is the previous one, `fc76d39 ← cf1b210` … `dcf1ede ← 72e90a5`
- **no amends** — the branch reflog contains **five plain `commit:` entries and zero `amend:` entries**:
  ```
  dcf1ede@{0}: commit: test(api): scan the whole generated client, not a list of two method names
  72e90a5@{1}: commit: fix(api): no endpoint declares a raw map return type — all 22, not two
  0dab461@{2}: commit: test(credentials): the no-private-material sweep must name __className__
  77d984a@{3}: commit: test(credentials): prove the wire boundary, and read the client as a model
  fc76d39@{4}: commit: fix(credentials): return typed models from the credential endpoints
  cf1b210@{5}: branch: Created from cf1b210
  ```
- **no empty/no-op commits** — every commit's tree differs from its parent's
- **base is an ancestor** — `git merge-base --is-ancestor` → true

### A second discrepancy: main had *not* advanced

The dispatch said *"`main` has advanced with docs-only commits since `cf1b210`, so `--ff-only` will be
impossible."* In fact `main` **was** exactly `cf1b210` and `main...origin/main` was `0 0`. A fast-forward
would therefore have been technically possible. It makes no difference to the outcome: `--no-ff` was the
mandated strategy and was used, producing the required merge commit. Recording it because the stated
justification for `--no-ff` does not hold, and a future lane should not rely on it.

## Merge

`git merge --no-ff fix/credential-endpoint-return-types` in the canonical checkout. **No rebase, no
squash, no force-push, no history rewrite.** All five reviewed SHAs remain reachable from `main`
(verified individually with `git merge-base --is-ancestor`).

The strongest available correctness check, and the reason this merge carries no risk of its own:

```
HEAD tree     310b4fe969ffeb8a11afea6ca856d5eba685629c
dcf1ede tree  310b4fe969ffeb8a11afea6ca856d5eba685629c
```

The merged main tree is **byte-identical to the approved HEAD**. The merge introduced no conflict
resolution and no content of its own, so `main` holds exactly the code that was reviewed.

## Gates on merged main — verbatim

| gate | command | result |
|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | **exit 0** — `Formatted 765 files (0 changed) in 6.68 seconds.` |
| analyze (server) | `dart analyze apps/server` | **exit 0** — `No issues found!` |
| analyze (client) | `cd apps/control_plane && flutter analyze` | **exit 0** — `No issues found! (ran in 26.2s)` |
| unit/widget | `cd apps/control_plane && flutter test` | **exit 0** — `00:55 +271: All tests passed!` |
| generate | `serverpod generate` (`dart run serverpod_cli generate`) | **exit 0** — `✓ Generating code (38.3s)` / `✅ Done.` |
| schema guard | `bash apps/server/tool/verify_schema_bootstrap.sh` | **exit 0** — 20 `OK:`, 0 `FAIL:` |
| integration | `make test-integration` | **exit 0** — `01:09 +192: All tests passed!` |

### `serverpod generate` — idempotent, and it matches the reviewer exactly

```
pre-generate   server protocol.dart  6a058ae57a43a0089c0c350ae4ffdcb8   ← reviewer's "6a058ae5…"
pre-generate   client protocol.dart  df76326de7471c8538e328b5d5328b28   ← reviewer's "df76326d…"
post-generate  server protocol.dart  6a058ae57a43a0089c0c350ae4ffdcb8   unchanged
post-generate  client protocol.dart  df76326de7471c8538e328b5d5328b28   unchanged

git status --porcelain -- generated paths  →  0
195-file md5 manifest, pre vs post         →  IDENTICAL
```

**Merged main does not differ from the reviewer's measurement.** The client md5 is `df76326d…`, matching
the value in the R2 review to the digit. Generate produced zero changes, so the committed generated
output is exactly what the generator emits — the merge introduced no generator drift.

### `make test-integration` — `+192`, zero failures. **There was no dogfood failure.**

This is the headline deviation from the dispatch's expectation, and it is a *better* result:

```
01:09 +192: All tests passed!
TEST_INTEGRATION_EXIT=0
```

The dispatch predicted a known single failure (`dogfood_shipit_postgres_test.dart`, the linked-worktree
artefact) and `+191 -1`. **That did not occur here.** The cause is exactly the mechanism the dispatch
described, and it resolves in the canonical checkout's favour: the dogfood test gates on
`Directory('.git').existsSync()`, and this checkout's `.git` is a **directory** (primary clone), whereas
the reviewer's lane worktree `/private/tmp/shipit-fix-endpoint-types` is a **linked worktree** whose
`.git` is a file. Verified directly:

```
git rev-parse --git-dir  →  .git
[ -d .git ]  →  YES
```

So the canonical checkout is the primary clone, and the suite is **`+192 All tests passed!`** — the
primary-clone figure the dispatch recorded as the expected behaviour outside a linked worktree.
**There is no failing test to report, and the sole-failure question is moot: the failure count is zero.**
The prior "dogfood is load-sensitive" claim remains disproved — this is purely a property of whether
`.git` is a directory or a file, deterministic in both cases.

**Cleanup confirmed.** The target's own trap took the success branch:

```
test-integration: removing shipit_integration_53650 (container + data)
 Container shipit_integration_53650-postgres_integration-1 Removed
 Network  shipit_integration_53650_default              Removed
```

No `CLEANUP FAILED`. I issued no further Docker command of any kind.

### One warning appeared — pre-existing, structural, unrelated to this change

Mid-run the suite printed:

```
WARNING: The database does not match the target database:
 - Missing Index "design_revision_approved_unique_per_work_item".
 - Missing Index "product_credential_active_repository_unique".
```

These are **exactly** the two hand-maintained indexes in the schema guard's `required_objects`. Serverpod's
own validator compares the live database against the *generated* model definition, and those two objects
are deliberately absent from it — schema-guard check 4 asserts *"no generated definition.sql claims these
objects; the bootstrap is their only source"*. The warning is the inherent cost of the hand-maintained
bootstrap design, is advisory only, and did not fail the run. It cannot have been introduced here:
`migrations/**` and `tool/**` are byte-identical to base, and I verified that **none** of the 51 new
model schemas declares a DB table (no `table:`, no `Table(`) — they are protocol/serialisation-only.

## Constraints

**Docker — zero mutating commands.** The only Docker activity in this entire lane was
`make test-integration`, the single sanctioned path. I issued **no** `docker`/`compose` command
otherwise — not `down`, `stop`, `rm`, `prune`, `up`, `pull`, `build`, `--rmi`, and not even read-only
`docker compose ps`, `logs`, `config` or `docker info`. Compose files were read **as text**, never
started. No `make clean`, `qa-down`, `test-env-down`, `e2e-down`, or bare `down -v`.

**The live QA stack was not disturbed.** Nothing I ran could reach compose project `docker`:
`test-integration` creates `shipit_integration_53650` via explicit `-p` and destroys exactly that project.
Your QA stack is up and running from merged `main`, untouched. I did not recreate containers, rebuild
images, or restart anything — the redeploy and browser hop are yours.

**Dirty files — not committed, byte-identical.** I hashed all 68 dirty files (sha256) **before** the merge
and re-verified **after the merge** and **again after every gate**:

```
status entries : 76  (before = after)      staged : 0  (before = after)
failures files : 48  (before = after)
68-file sha256 manifest, pre vs final      →  IDENTICAL
merge commit containing any dirty path     →  0
```

`.decisions/6bd29306-efe0-4335-9c31-d14bb4957523.yaml` and `melos_shipit_platform.iml` remain
`M` and **unstaged**. No `git add -A`, no `git commit -a`. The 26 untracked root files and the untracked
dispatch task directories are all still untracked.

**No lane worktree or branch deleted.** Verified by diffing full inventories taken before the merge
against current state:

```
WORKTREES: all 25 intact, none added, none removed
BRANCHES:  all 37 intact, none added, none removed
```

`/private/tmp/shipit-fix-endpoint-types` is still present at `dcf1ede`, and
`fix/credential-endpoint-return-types` still points at `dcf1ede`.

**No finding fixed.** G-7, M-4, M-5, N-1, F-A/F-B, M-1, L-1, L-2 and discovery M-3 all remain open and
untouched, as instructed.

**Remote URL split** — confirmed and preserved: fetch `https://github.com/shipitinc/shipit-platform.git`,
push `git@github.com:shipitinc/shipit-platform.git`. The push used the SSH URL.

## One correction to my own process

While checking that no worktree or branch had been removed, I printed comparison labels reading
`"was 26"` and `"was 40"`. Those numbers were **invented, not measured** — I had not recorded baselines
before the merge. I did not leave them standing: I reconstructed the pre-merge inventories from the
earlier `git worktree list` / `git branch -vv` output and diffed them properly. The real counts are
**25 worktrees and 37 branches, both unchanged**. The verified diff above supersedes the fabricated
labels.

## Push

```
To github.com:shipitinc/shipit-platform.git
   cf1b210..a5c46e9  main -> main
PUSH_EXIT=0
```

Fast-forward on the remote; not a force push.

```
git rev-list --left-right --count main...origin/main   →   0  0
git rev-parse origin/main                              →   a5c46e93c8916375e63b5e542fc610f5314c4383
git rev-parse main                                     →   a5c46e93c8916375e63b5e542fc610f5314c4383
```

---

## Your next step

`main` is now `a5c46e9` and the tree is byte-identical to the reviewed `dcf1ede`, so redeploying the QA
stack from `main` deploys exactly the reviewed code. The remaining evidence is the one no lane can
produce: the browser hop through Add Product. On the reviewed code that path is now deserialisable
end to end — `addRepositoryReference` returns `RepositoryReferenceAddedView` and the mint at `:147` is
reachable — so the hop should get past the call that was previously throwing.

M-3 (the correction lane's now-classified `NEW_DISCOVERIES`) is still the Manager's routing call and is
unresolved; the `PROJECT_FACT` about Serverpod 3.4.13 having no arbitrary-JSON model type is the most
durable of them.
