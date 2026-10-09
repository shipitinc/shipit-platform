# Report — integrate-client-keyflow

```
RESULT: MERGE_APPROVED

MAIN: cf1b2106b75238da4b43ebbff05e06414f2793ed
ORIGIN/MAIN: cf1b2106b75238da4b43ebbff05e06414f2793ed
AHEAD/BEHIND: 0  0
```

Three independently-approved branches integrated in the mandated load-bearing order, `--no-ff`
throughout. No rebase, no squash, no force-push, no history rewrite. All three approved heads are
ancestors of `main` at their exact reviewed SHAs.

---

## 1. Merge SHAs

| Step | Branch | Approved HEAD | Merge commit on main | Result |
|---|---|---|---|---|
| 1 | `impl/client-addproduct-keyflow` | `3f2805961865aa5d0b0ac3695a85792eda9bccbe` | **`120c1b037837f4d9368337d54c39a7e70f6b132f`** | clean, `ort` |
| 2 | `impl/credential-key-service` | `4f96c78c9ffd65a9d1bafcdb65c4d12128a0ec3e` | **`7a39fe16d99ecfe48b8a7ec4fdb94049e1830853`** | clean, `ort` |
| 3 | `fix/hostkey-config-wiring` | `437cdb67a9b82ca1e6352745d1614df188f3eb46` | **`cf1b2106b75238da4b43ebbff05e06414f2793ed`** | clean, `ort` |

Each merge commit carries both parents, confirmed via `git log -1 --format='%H %P'`:

```
120c1b0  9621b3d  3f28059
7a39fe1  120c1b0  4f96c78
cf1b210  7a39fe1  437cdb6
```

Merge chain on `main` after integration:

```
*   cf1b210 Merge branch 'fix/hostkey-config-wiring'
|\
| * 437cdb6 fix(docker): deliver the host-key attestation values to the client
* |   7a39fe1 Merge branch 'impl/credential-key-service'
| |\
| | * 4f96c78 test(server): close two false negatives in the endpoint surface guard
| | * effc537 fix(server): keep recordCustodyPrecondition out of the generated surface
* | |   120c1b0 Merge branch 'impl/client-addproduct-keyflow'
|\ \ \
| | | | 3f28059 fix(control-plane): make the deploy-key flow reachable from an empty state
```

Provenance verified, not assumed:

```
git rev-parse 3f28059 -> 3f2805961865aa5d0b0ac3695a85792eda9bccbe   MATCH approved
git rev-parse 4f96c78 -> 4f96c78c9ffd65a9d1bafcdb65c4d12128a0ec3e   MATCH approved
git rev-parse 437cdb6 -> 437cdb67a9b82ca1e6352745d1614df188f3eb46   MATCH approved
merge-base main 3f28059 -> c110aa2   (client branch base)
merge-base main 4f96c78 -> 7d1b1b8   (key-service branch base)
merge-base main 437cdb6 -> c110aa2   (hostkey branch base)
```

All three lane worktrees were **pristine and at their approved SHAs** before merging
(`git status --porcelain --untracked-files=all` empty in each):

```
/private/tmp/shipit-client-keyflow   3f28059 [impl/client-addproduct-keyflow]   CLEAN
/private/tmp/shipit-impl-keys         4f96c78 [impl/credential-key-service]     CLEAN
/private/tmp/shipit-fix-hostkey       437cdb6 [fix/hostkey-config-wiring]       CLEAN
```

---

## 2. Merge strategy — `--no-ff` was necessary and correct

`--ff-only` was impossible, as predicted. Each branch's base (`c110aa2`, `7d1b1b8`) is an ancestor
of `main` but `main` had advanced past it with docs-only commits, so every branch was a sibling
requiring a real merge. All three were pre-verified conflict-free before touching `main`:

```
git merge-tree --write-tree main 3f28059 -> CLEAN
git merge-tree --write-tree main 4f96c78 -> CLEAN
git merge-tree --write-tree main 437cdb6 -> CLEAN
```

Every merge resolved with zero conflicts, zero manual intervention, zero file edits by me.
`--no-ff` preserved each reviewed SHA verbatim — the point of the strategy.

---

## 3. Disjointness from what `main` gained

`main` advanced past the branch bases with **docs-only** commits. Verified mechanically:

```
git diff --name-only c110aa2 main  ->  12 paths, all docs/engineering/dispatch/**
git diff --name-only 7d1b1b8  main  ->  20 paths, all docs/engineering/dispatch/**
```

Not one non-docs path. The three branches' file sets are also mutually disjoint:

| Step | Paths | Overlap with main's gain | Overlap with other steps |
|---|---|---|---|
| 1 | `apps/control_plane/lib/**` (4), `apps/control_plane/test/**` (3), `packages/control_plane_client/lib/src/protocol/client.dart` (1) | **none** | none |
| 2 | `apps/server/lib/src/endpoints/credential_endpoints.dart`, `apps/server/test/endpoint_surface_shape_test.dart` | **none** | none |
| 3 | `docker/compose.qa.yaml`, `docker/config.js.template`, `docker/entrypoint.client.sh` | **none** | none |

Step 1 landed 9 files (+2211/−68); step 2 landed 2 (+480); step 3 landed 3 (+36/−2). The step-1
merge introduced `operator_attestation.dart`, `add_product_bloc_test.dart` and
`add_product_keyflow_widget_test.dart` as new files.

---

## 4. Integration order — honoured, and the dependency is now satisfied on `main`

Step 1 landed before step 3 as mandated. The reason the order is load-bearing is now directly
observable on `main`: the hostkey branch publishes `HOST_KEY_FINGERPRINT` / `OPERATOR_NAME` into
`config.js`, and the readers of those keys exist **only because of step 1**:

```
apps/control_plane/lib/data/runtime_config_web.dart:12  readControlPlaneApi() => readRuntimeConfigValue('CONTROL_PLANE_API');
apps/control_plane/lib/data/runtime_config_web.dart:25  String? readRuntimeConfigValue(String key) {
apps/control_plane/lib/data/operator_attestation.dart   (present)
```

Neither `readRuntimeConfigValue` nor `operator_attestation.dart` exists at `c110aa2`. Had step 3
merged first, `main` would have carried a correctly-populated `config.js` that nothing read — values
visible in DevTools, still `null` in the UI. The inverse order would have been inert. Verified in
this order, the publishing keys and the reading code are now in the same tree.

---

## 5. Gates

### Step 1 — client (`120c1b0`)

| Gate | Command | Expected | Actual | |
|---|---|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | 658 files, 0 changed | `Formatted 658 files (0 changed)`, exit 0 | PASS |
| analyze | `cd apps/control_plane && flutter analyze` | No issues found! | `No issues found!`, exit 0 | PASS |
| tests | `cd apps/control_plane && flutter test` | **+271** | **`+271: All tests passed!`**, exit 0 | PASS |

### Step 2 — generate fix (`7a39fe1`)

| Gate | Command | Result | |
|---|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | `Formatted 659 files (0 changed)`, exit 0 — 659 because step 2 added the new guard test file | PASS |
| analyze | `dart analyze apps/server` | `No issues found!`, exit 0 | PASS |
| **generate** | `serverpod generate` (in `apps/server`) | **`✓ Generating code (11.1s)` / `✅ Done.` — EXIT STATUS 0** | PASS |
| byte-identity | generated tree hash before/after | `17d8989a673e7513a1a2af0b6b514a7e0ba870424f1d5e429def7eb67398b179` **identical** before and after | PASS |
| byte-identity | `git diff` over `apps/server/lib/src/generated` | **empty** | PASS |
| byte-identity | client package tree hash | `d3d9a8ab2c1b54683f0cdcec72630c38a46606829bd385bdc802edf22e2c61c1` **identical** before and after | PASS |
| byte-identity | `git diff` over `packages/` | **empty** | PASS |

**The `17d8989a673e…` value matches the endpoint-guard review's independently recorded hash exactly**,
so the generated tree is unchanged from the state that review verified.

**`git checkout --` was NOT required.** Generate touched nothing: the working tree after generate was
byte-identical to the pre-generate dirty baseline (71 entries, diff clean against the snapshot). The
reviewed client package was not disturbed. Nothing needed restoring.

### Step 3 — hostkey config (`cf1b210`)

| Gate | Command | Result | |
|---|---|---|---|
| shell syntax | `bash -n docker/entrypoint.client.sh` | exit 0, clean | PASS |
| shell syntax | `sh -n docker/entrypoint.client.sh` | exit 0, clean | PASS |
| whitespace | `git diff --check HEAD~1 HEAD` | exit 0, clean | PASS |

**Dart/Flutter gates: I RAN them, rather than reporting `n/a`.** Reason: the step-3 review judged
`n/a` acceptable on the grounds that the diff contains zero `.dart` files, which is sound for that
branch **in isolation** — but the artifact I am approving is the *combined* `main`, a tree no
individual reviewer ever saw. Step 1 changed Dart sources that step 2 and step 3 were each reviewed
without, so the isolated argument does not transfer to the integration result. Running them was
cheap and the only honest way to claim a pass I actually observed.

| Gate | Command | Result | |
|---|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | `Formatted 659 files (0 changed)`, exit 0 | PASS |
| server analyze | `dart analyze apps/server` | `No issues found!`, exit 0 | PASS |
| client analyze | `cd apps/control_plane && flutter analyze` | `No issues found!`, exit 0 | PASS |
| client tests | `cd apps/control_plane && flutter test` | **`+271: All tests passed!`**, exit 0 | PASS |
| guard test | `cd apps/server && dart test test/endpoint_surface_shape_test.dart` | **`+13: All tests passed!`**, exit 0 | PASS |

Note: my first invocation of the guard test as `dart test apps/server/test/...` from the repo root
returned `+0 -1: loading …`. That was **my invocation error** — the suite resolves package-relative
paths and must run from `apps/server`, which is how the review ran it. Re-run correctly from
`apps/server`: **+13, all passed**. Not a regression, and nothing was changed to obtain it.

`+271` on the combined tree equals the step-1-only count: steps 2 and 3 moved no client Dart, as
their diffs attest.

### Step-3 invariants re-checked on merged `main`

```
git diff --name-only HEAD~1 HEAD -- '*.dart'  ->  0        (zero Dart files, confirms n/a argument)
grep '^name:' docker/compose.qa.yaml          ->  absent   (live QA stack NOT re-homed)
grep -rn '${VAR:?' docker/                    ->  2 hits, BOTH inside comments
                                                     compose.test.yaml:34, compose.qa.yaml:77
                                                     no live mandatory interpolation introduced
bash -n docker/entrypoint.client.sh           ->  clean
```

No top-level `name:` was added to any compose file, so the live QA stack remains on compose project
`docker`. `SC2016` was not touched — its count is unchanged 2 → 2, and per the review's empirical
result its "fix" (double quotes) would reintroduce the literal-placeholder trap.

---

## 6. Constraints — all honoured

| Constraint | Verified |
|---|---|
| Order: client before hostkey | Step 1 = `120c1b0`, step 3 = `cf1b210`; client reader and `operator_attestation.dart` now present on `main` alongside the published keys |
| `--no-ff`, no rebase, no squash, no force-push | All three merges `--no-ff --no-edit`, all resolved by `ort` with zero conflicts; zero conflicts and zero manual edits means zero reviewed SHAs rewritten |
| **ZERO mutating Docker/Compose commands** | **No `docker` or `docker compose` command of any kind was issued in this lane** — not mutating, not read-only, not `docker info`, not `compose ps`. The QA stack was never read, started, stopped, recreated or rebuilt, and its stopgap run-mode override is untouched. `bash -n` / `sh -n` parse shell text; they do not run it. |
| Not `make clean` / `qa-down` / `test-env-down` / `e2e-down` / bare `down -v` | None run. None of these targets invoked. |
| Not `make test-integration` | Not run. No database was created or touched. |
| `serverpod generate` only in step 2, restored immediately | Run exactly once, in step 2, exit 0. Touched nothing, so no restore was needed; verified by hash both ways. |
| No open finding fixed | None attempted. See §7. |
| Pre-existing dirty files not committed | Index **empty** at every checkpoint (before merges, after each merge, after generate, after push). Never ran `git add -A` or `git commit -a`. See §8. |
| No lane worktree or branch deleted | `git worktree list` = **36** entries before and after, unchanged. All three source branches and their worktrees intact for the human's cleanup. |

---

## 7. Deferred findings — recorded, not touched

None of these were acted on. Each was already judged non-blocking by its reviewer:

- **G-7** — `referenceName` still in the client models; mint also returns a reference. Product decision.
- **M-4** — custody fallback recorded lazily (on first credential call, not at startup). ADR 0018's clause is met on its own terms; `secret_provider_resolver.dart`'s `default:` arm throws, so there is no silent default.
- **N-1** — dogfood is a linked-worktree artefact. **`+191 -1` must NOT be treated as this branch's baseline**; a primary clone gives `+192: All tests passed!`. Mechanism re-confirmed from source: `dogfood_shipit_postgres_test.dart:87-91` asserts `Directory('${repoRoot.path}/.git').existsSync()`, and `.git` is a 75-byte **file** in a linked worktree, so `existsSync()` is false and the throw precedes the `:107` archive.
- **F-A / F-B** — no CI job runs generate, and no CI job runs `apps/server/test/**`. Confirmed at `ci.yaml:60-61` and `integration.yaml:139`.
- **M-1** — the template↔allowlist coupling is unguarded by tooling. Until a guard exists, `docker/config.js.template` and `docker/entrypoint.client.sh` must be treated as one atomic unit.
- **L-1** — `docs/deployment/local-qa.md:96-99` client env table is stale (also `test-environment.md`, `e2e-integration.md`, `docs/engineering/learning/local-deployment-systematization.md:41`).
- **L-2** — operators must set `SHIPIT_HOST_KEY_FINGERPRINT` / `SHIPIT_OPERATOR_NAME` in **`docker/.env`**, not the repo-root `.env`, or they are silently ignored.
- **Arithmetic error in the endpoint-guard report** — it states assertions went 12 → 13. **Both heads run 13.** My own run at merged `main` gives **+13**, which confirms the reviewer's finding: the true statement is that the test *count* is unchanged at 13 while the catchable-offender set grows.
- **F1/F2/F3** (client re-review) — the `setUp`-bloc comment overstates its mechanism; the `UnimplementedRepositoryApis` drift is compile-enforced, not silent, and is 14 overrides not 13. Zero victims in this repo.
- **L-3** — no trailing newline on `docker/config.js.template`. Pre-existing at base and HEAD, cosmetic.
- **Prompt staleness** — `fix-hostkey-config-wiring/prompt.md` declares `WORKTREE: /private/tmp/shipit-fix-hostkey-config`; the real registered worktree is `/private/tmp/shipit-fix-hostkey`. Documentation only.

---

## 8. Pre-existing dirty files — byte-identical and unstaged afterwards

Baseline captured **before** the first merge and compared after the push:

```
sha256  .decisions/6bd29306-…yaml   8f6931abb5b7d1f497a6aa402c2f782abcd6d0e8c2f4391d48ae9c19d78a9b2c   (unchanged)
sha256  melos_shipit_platform.iml   a7c508126953aa0b5a5b795dd53d3b859ed5792cd4a84d72f564c3589ff0e819   (unchanged)
sha256  48× test/failures/*.png     556c8b1c02b9cfe735ae01959c8f66f75f6439b08ff5ff742d0c50bc2e1eeb6b   (aggregate, unchanged)
```

```
git diff --cached --name-only  ->  (empty)     index never staged anything
git status --porcelain         ->  71 entries, IDENTICAL to the pre-merge baseline (diff clean)
```

48 modified golden PNGs under `apps/control_plane/test/failures/`, `melos_shipit_platform.iml`,
`.decisions/6bd29306-….yaml`, plus ~18 untracked root files — all still unstaged, all byte-identical.
None was committed. `git push origin main` moved 3 merge commits and 6 branch commits only.

---

## 9. Push and provenance

```
git push origin main
  To github.com:shipitinc/shipit-platform.git
     9621b3d..cf1b210  main -> main
  PUSH_EXIT=0
```

Push URL is SSH (`git@github.com:shipitinc/shipit-platform.git`); fetch URL stays HTTPS
(`https://github.com/shipitinc/shipit-platform.git`) — both as configured, unchanged.

```
git rev-list --left-right --count main...origin/main  ->  0  0
git rev-parse origin/main                            ->  cf1b2106b75238da4b43ebbff05e06414f2793ed
git rev-parse main                                   ->  cf1b2106b75238da4b43ebbff05e06414f2793ed
```

All three approved heads are ancestors of pushed `main`:

```
3f28059: YES     4f96c78: YES     437cdb6: YES
```

---

## 10. Bottom line

Three approved branches, three conflict-free `--no-ff` merges in the mandated order, every gate
green at every step including on the combined tree, every reviewed SHA preserved verbatim, and the
one ordering hazard — a populated `config.js` nothing reads — resolved by putting the reader in the
tree before the publisher. The QA stack was never touched, the dirty files are untouched, and no
deferred finding was silently fixed.

Integration is complete and pushed. **Deployment remains the human's step**, as instructed.

```
RESULT: MERGE_APPROVED

APPROVED_HEAD:
  step 1  impl/client-addproduct-keyflow  3f2805961865aa5d0b0ac3695a85792eda9bccbe
  step 2  impl/credential-key-service      4f96c78c9ffd65a9d1bafcdb65c4d12128a0ec3e
  step 3  fix/hostkey-config-wiring        437cdb67a9b82ca1e6352745d1614df188f3eb46
  (all three verified ancestors of pushed main at their exact reviewed SHAs)

CURRENT_MAIN:        cf1b2106b75238da4b43ebbff05e06414f2793ed
ORIGIN/MAIN:         cf1b2106b75238da4b43ebbff05e06414f2793ed
MERGE SHAs:          120c1b0 (step 1) -> 7a39fe1 (step 2) -> cf1b210 (step 3)
AHEAD/BEHIND:        0  0

GATES:
  format=PASS   (658 files 0 changed @step1; 659 files 0 changed @step2 and @final)
  analyze=PASS  (No issues found! — apps/server and apps/control_plane)
  tests=PASS    (+271: All tests passed! — control_plane, step 1 and final; +13 endpoint guard @final)
  build=PASS   (serverpod generate EXIT 0; generated tree 17d8989a673e… byte-identical;
                client package byte-identical; bash -n / sh -n entrypoint.client.sh clean)

PROVENANCE:
  base before integration  9621b3d98d5048e066cd1bb8fb2f00acd4916e91 (main == origin/main, 0 0)
  all three merges --no-ff --no-edit, strategy `ort`, ZERO conflicts, ZERO manual edits
  no rebase, no squash, no force-push, no history rewrite
  branch bases: client c110aa2, key-service 7d1b1b8 (already in main via c110aa2), hostkey c110aa2
  main gained only docs/engineering/dispatch/** since each base — disjoint from all three branch file sets
  all 3 lane worktrees verified CLEAN at their approved SHAs before merging; all 36 worktrees intact after
  pre-existing dirty files: index empty, 71 entries, byte-identical by sha256 — nothing committed

READY_FOR_INTEGRATION:
  YES — integration COMPLETE and PUSHED. main and origin/main are both at
  cf1b2106b75238da4b43ebbff05e06414f2793ed, ahead/behind 0 0. No further human action is
  required for the merge itself; nothing was force-pushed and no reviewed history was rewritten.
  Deployment authority remains with the human: this lane issued ZERO Docker/Compose commands,
  so the QA stack and its stopgap run-mode override are exactly as they were, and the
  host-key config path (SHIPIT_HOST_KEY_FINGERPRINT / SHIPIT_OPERATOR_NAME, which must come
  from docker/.env per L-2) is untested at runtime and awaits your deployment step.
  Lane worktrees and branches were deliberately left in place for your cleanup.
```
