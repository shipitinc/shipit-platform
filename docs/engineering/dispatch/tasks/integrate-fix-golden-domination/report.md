# Integration Report — `fix/golden-domination-n2`

**Role:** Integrator
**Lane:** `integrate-fix-golden-domination`
**Branch:** `fix/golden-domination-n2`
**Reviewed HEAD:** `b7db6ef3fe3aadf2421a4f14087fb914badfb5f2`
**Result:** `INTEGRATION_BLOCKED` — local merge complete and fully verified; **remote push rejected by the host on credential scope.**

---

## 1. Headline

The merge itself **succeeded and is verified**: the merge commit is written, all three gates pass
on merged main, all four reviewed SHAs are preserved byte-for-byte, and the pre-existing dirty
files were not touched.

The push to `origin/main` **failed**, and I could not resolve it within my authority:

```
! [remote rejected] main -> main (refusing to allow an OAuth App to create or
  update workflow `.github/workflows/ci.yaml` without `workflow` scope)
```

This is a host-side credential-scope restriction, not a permission, history, or force-push
problem. It needs a human. See §7.

---

## 2. Precondition re-verification — one assertion was WRONG

I re-derived all five preconditions independently. **One of the five is factually false**, and it
is the one the authorization rested on most heavily.

| # | Precondition | Result |
|---|---|---|
| 1 | `main` still `068f952`, `origin/main` in sync | **PASS** — both `068f952e0cae...`, `0 0` |
| 2 | `git merge-base --is-ancestor 068f952 fix/golden-domination-n2` is TRUE | **FAIL — exit=1 (FALSE)** |
| 3 | `git merge-tree` still clean | **PASS** — exit 0, tree `8e73b4f9` |
| 4 | Branch HEAD `b7db6ef`, 4 commits in reviewed order | **PASS** |
| 5 | `golden_tolerance.dart` blob `7cd735ca`; nothing under `apps/control_plane/lib/` | **PASS** |

### Precondition 2 failed, and its stated conclusion was also wrong

```
$ git merge-base --is-ancestor 068f952 fix/golden-domination-n2
exit=1                                    # FALSE — Manager asserted TRUE

$ git merge-base main fix/golden-domination-n2
a8a990bd6633b237862309a1522f342efd566481  # the OLD main, not 068f952

$ git merge-base --is-ancestor fix/golden-domination-n2 main
exit=1                                    # branch is NOT in main either
```

The branch and `main` are **diverged**, not nested. `main` carries six decision commits the branch
does not contain:

```
068f952  decisions(security): production gap DEFERRED by human, recorded as first-class open item
94b2c6f  decisions(security): file PRODUCTION run-mode + missing-bootstrap gap
eb13f99  decisions: resolve round three; fault returns to OPTION_B with DL-2 fixed at the cause
e6e73d6  decisions: file two PENDING; correct a load-bearing Manager error
5cb81fd  decisions: resolve round two; 30c00e6e OPTION_C REVERSES 6d2bfffe OPTION_B
2e25372  decisions: file two more PENDING (startup RISK 3; golden CI environment)
```

So the dispatch's phrasing — *"main IS an ancestor of the branch, so the merge is a pure addition of
the branch's commits"* — is false on both counts. The merge is **not** a pure addition; it is a
three-way union with `main`'s six commits.

### Why I proceeded anyway

Precondition 2 was a **means**, not the end. Its purpose was to establish that the merge preserves
reviewed provenance and that post-merge gates return output identical to what the focused reviewer
saw at `b7db6ef`. That purpose is not actually dependent on ancestry — and I verified it directly,
by a stronger route, before touching anything:

```
$ comm -12 <(git diff --name-only a8a990b b7db6ef | sort) \
           <(git diff --name-only a8a990b 068f952 | sort)
(empty)                      # ZERO overlapping files between the two sides
```

- Branch side (49 files): `apps/control_plane/test/goldens/*.png`, `apps/control_plane/test/tools/*.dart`,
  `.github/workflows/ci.yaml`. Nothing else.
- `main` side (17 files): `.decisions/*.yaml` and `docs/**`. Nothing else.

The two sides are **completely disjoint**. And the decisive measurement:

```
$ git diff --name-only b7db6ef 8e73b4f903f2b6614a5127ad5dd000a3d72930a1   # reviewed HEAD vs merge tree
  .decisions/*.yaml  (6)
  docs/engineering/**  (11)

  .dart files differing:      0
  .png (goldens) differing:  0
  ci.yaml differing:          0
  test/tools/ differing:      0
```

Every input the gates consume — `.dart`, `.png`, `ci.yaml`, `test/tools` — is **byte-identical** to
`b7db6ef`. The 17 differing files are `main`'s own decision and documentation commits, which is
precisely what a correct merge must carry in. The safety conclusion the dispatch reached is right;
its stated reason for it was not. I proceeded on the measured fact, not on the assertion.

The designated stop condition — *"If main advanced again, stop and report INTEGRATION_BLOCKED"* —
was **not** met: `main` was still `068f952` on arrival.

---

## 3. The merge

```
$ git merge --no-ff fix/golden-domination-n2 -m "Merge branch 'fix/golden-domination-n2' ..."
Merge made by the 'ort' strategy.
 49 files changed, 2997 insertions(+)
MERGE_EXIT=0
```

Clean, no conflicts, no manual resolution.

```
new main HEAD : 34f60a2b9ffbe27e988f5ae2d080094c51c8d290
parents       : 34f60a2 068f952 b7db6ef     (main, then branch — as intended)
merge tree    : 8e73b4f903f2b6614a5127ad5dd000a3d72930a1
```

The realized tree hash matches the tree I predicted with `merge-tree` **before** merging, exactly.
`--no-ff` did its job — all four reviewed SHAs survive as ancestors of `main`, unmodified:

```
c68016a  YES      f68a27a  YES
8557da1  YES      b7db6ef  YES
```

and the reviewed artifacts are byte-identical inside the merge commit:

```
$ git rev-parse 34f60a2:.github/workflows/ci.yaml   ->  e7d5ffb0d4dae1223884f08d12d1d43808b4b659
$ git rev-parse b7db6ef:.github/workflows/ci.yaml   ->  e7d5ffb0d4dae1223884f08d12d1d43808b4b659
```

---

## 4. Post-integration gates on merged `main` — verbatim

### 4.1 Format (repo root)

```
Formatted 638 files (0 changed) in 7.16 seconds.
FORMAT_EXIT=0
```

Matches expectation (`638 files (0 changed)`) exactly.

### 4.2 Analyze (`apps/control_plane`)

```
Analyzing control_plane...
No issues found! (ran in 15.7s)
ANALYZE_EXIT=0
```

### 4.3 Test (`apps/control_plane`)

```
00:48 +240: .../products_page_test.dart: access a product with no repository says none attributed
00:48 +241: .../products_page_test.dart: access partial reachability reports the real ratio
00:48 +242: .../products_page_test.dart: empty and mobile an empty registry does not pretend otherwise
00:48 +243: .../products_page_test.dart: empty and mobile mobile stacks rows and keeps the status visible
00:49 +245: .../products_page_test.dart: empty and mobile mobile stacks rows and keeps the status visible
00:49 +246: All tests passed!
TEST_EXIT=0
```

Matches expectation (`+246: All tests passed!`) exactly. `flutter analyze` triggered an implicit
`pub get` against the workspace root; `.dart_tool` was already present at both root and
`apps/control_plane`, so no manual resolution step was required.

---

## 5. Pre-existing dirty files — untouched and uncommitted

I fingerprinted the working tree **before** merging and re-verified **after** the gates, since a
golden test run can write failure artifacts.

```
49 pre-existing modified files, all under apps/control_plane/test/failures/ (48)
  plus melos_shipit_platform.iml (1)

before merge : bc221513c6ecebf846d0282444acd1321c51f6934bf366320c3f5c6f0af57700  -
after  merge : bc221513c6ecebf846d0282444acd1321c51f6934bf366320c3f5c6f0af57700  -   IDENTICAL
after  gates : bc221513c6ecebf846d0282444acd1321c51f6934bf366320c3f5c6f0af57700  -   IDENTICAL

staged modifications:        0   (nothing staged)
modified set vs before:      IDENTICAL
untracked count:            19   (unchanged)
```

Content hash, file set, and staging state are all unchanged across the whole operation. I used no
`git add -A` and no `git commit -a`; the merge staged only what the merge brought. **None of these 49
files entered the merge commit.**

---

## 6. Push — REJECTED

```
$ git push origin main
To https://github.com/shipitinc/shipit-platform.git
 ! [remote rejected] main -> main (refusing to allow an OAuth App to create or
   update workflow `.github/workflows/ci.yaml` without `workflow` scope)
error: failed to push some refs to 'https://github.com/shipitinc/shipit-platform.git'
PUSH_EXIT=1
```

Exactly one file in the pending push touches a workflow path:

```
$ git diff --name-only origin/main main -- .github/workflows/
.github/workflows/ci.yaml
```

That file comes from reviewed commit `c68016a` (`+76` lines) and is **load-bearing**: it wires the
new golden-domination gate into CI. It cannot be dropped without destroying the reviewed content.

The remote uses an HTTPS credential. GitHub refuses workflow-file changes from OAuth App tokens
that lack the `workflow` scope, because otherwise any such token could exfiltrate repository secrets
by rewriting CI. This is GitHub's own protection, correctly triggered.

### State after the failed push — nothing was half-applied

```
origin/main : 068f952e0cae41b6feb69c079bb8b47d14fc77e8   (UNCHANGED)
main        : 34f60a2b9ffbe27e988f5ae2d080094c51c8d290   (local, verified)
ahead/behind: 5   0
```

Ref updates are atomic; the rejection left the remote untouched. Local `main` is intact, committed,
and passing all gates. **The merge is not lost — it is one authorized push away.**

---

## 7. Why I did not work around this

Every available workaround would have destroyed the property the merge-commit route exists to protect:

- **Force-push** — explicitly forbidden, and irrelevant (this is not a non-fast-forward).
- **Rebase / amend the merge to exclude `ci.yaml`** — rewrites the reviewed SHAs and silently ships
  a build whose CI wiring differs from what was reviewed and gated. This is the exact provenance
  destruction the `--no-ff` route was chosen to avoid. Rejected.
- **Swap or modify git credentials** — outside my authority. AGENTS.md §13a/§13b: credentials are
  referenced by name, never by value, and custody belongs to the human.

Escalating is the correct action, not a failure to finish.

### What a human needs to do (any one of these unblocks it)

1. **Grant `workflow` scope** to the existing OAuth credential used for `origin` (or issue a
   credential carrying it), then re-run `git push origin main`. Smallest change; the local merge is
   already correct and verified.
2. **Push over SSH** using the per-repository deploy key contemplated by ADR 0018. A deploy key is
   not an OAuth App token and is not subject to this restriction. Credential custody stays with the
   human either way.
3. **Land via PR** through an interface that already holds workflow scope — same commit, human path.

In all cases the object to publish is already local and unchanged: `34f60a2`.

---

## 8. Constraints observed

- **Zero Docker/Compose commands.** None issued — not even read-only ones (`ps`, `logs`, `config`).
- **Lane worktree and branch preserved.** `/private/tmp/shipit-fix-golden-domination` and
  `fix/golden-domination-n2` (`b7db6ef`) both left intact for the Manager to clean up.
- **No production code modified.** The only write to the repository was the merge commit and this
  report.
- **No force-push; no history rewrite.**

### Owed integrator action — render-environment contract placement

Per instruction, **no change made**; my prior judgement that none is needed stands. The constraint
forbidding `apps/**` edits outranks the owed README. Recorded as **owed to a lane owning
`apps/**`** — specifically, the `golden_render_environment` contract documentation that the new
checked precondition implies should live beside the code it governs, rather than in a README a
`docs/**` lane would author.

---

## 9. Structured result

```
RESULT: INTEGRATION_BLOCKED

APPROVED_HEAD:   b7db6ef3fe3aadf2421a4f14087fb914badfb5f2   (reviewed HEAD, unchanged, ancestor of main)
CURRENT_MAIN:    34f60a2b9ffbe27e988f5ae2d080094c51c8d290   (local; merge commit)
ORIGIN_MAIN:     068f952e0cae41b6feb69c079bb8b47d14fc77e8   (UNCHANGED — push rejected)
MERGE_COMMIT:    34f60a2b9ffbe27e988f5ae2d080094c51c8d290
MERGE_PARENTS:   068f952e0cae41b6feb69c079bb8b47d14fc77e8 b7db6ef3fe3aadf2421a4f14087fb914badfb5f2
MERGE_TREE:      8e73b4f903f2b6614a5127ad5dd000a3d72930a1
AHEAD_BEHIND:    5 0   (main vs origin/main)

GATES:
format=   PASS  "Formatted 638 files (0 changed) in 7.16 seconds."   exit 0
analyze=  PASS  "No issues found! (ran in 15.7s)"                   exit 0
tests=    PASS  "+246: All tests passed!"                            exit 0
build=    N/A   no build gate defined in repository policy

PROVENANCE:
  branch            fix/golden-domination-n2 @ b7db6ef (intact, preserved)
  merge base        a8a990bd6633b237862309a1522f342efd566481 (NOT 068f952 — precondition 2 was false)
  reviewed SHAs     c68016a, f68a27a, 8557da1, b7db6ef — all ancestors of main, byte-for-byte
  strategy          --no-ff, ort, 0 conflicts, no manual resolution
  reviewed artifacts byte-identical in merge commit (e.g. ci.yaml blob e7d5ffb0)
  pre-existing dirty 49 files unmodified by me, unstaged, uncommitted (hash bc221513… stable)
  untracked         19 files, unchanged, none committed
  remote            unchanged at 068f952; rejection atomic
  worktrees         all preserved, incl. /private/tmp/shipit-fix-golden-domination
  docker            zero commands issued

READY_FOR_INTEGRATION:
  YES for the MERGE — the merge commit 34f60a2 is correct, verified, and needs nothing further.
  NO  for the PUSH — blocked by GitHub refusing workflow-file changes from an OAuth App token
      lacking `workflow` scope. NOT pushable by me; requires human credential authority.

  Safe strategy: plain `git push origin main` (never --force) once a credential with `workflow`
  scope, or an SSH deploy key per ADR 0018, is in place. Object already local at 34f60a2.
  Human/deployment authority REQUIRED before the remote leg. No re-review needed: the merge tree is
  byte-identical to the reviewed HEAD for every .dart, .png, ci.yaml and test/tools input.
```

### Why not `MERGE_APPROVED`

The merge is done and verified, but **integration did not complete**. `origin/main` is still at
`068f952`; the reviewed work is not on the remote. Reporting `MERGE_APPROVED` would assert an
outcome that did not occur. The blocker is real, external, and needs human authority — precisely the
condition `INTEGRATION_BLOCKED` exists to name.
