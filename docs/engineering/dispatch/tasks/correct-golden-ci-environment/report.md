# Correction report — correct-golden-ci-environment

**Lane:** `correction-implementer`
**Branch / worktree:** `fix/golden-domination-n2` / `/private/tmp/shipit-fix-golden-domination`
**Authority:** Human Decision `3e9dfb75-7bdf-4a8c-89dd-c76779a65371` — `RESOLVED` / **OPTION_C**,
"Pin CI to the exact rendering environment", decided 2026-10-08T05:14:00Z via the structured question
UI.
**Corrected from:** `f68a27ae561b9b06863f9b616878e9789026c533`
**Produced:** `b7db6ef3fe3aadf2421a4f14087fb914badfb5f2`
**Reviewed report being answered:** `docs/engineering/dispatch/tasks/review-fix-golden-domination-n2/report.md`
(`DO_NOT_MERGE`, `HUMAN_DECISION_REQUIRED: YES`, BLOCKER-1 + MEDIUM-1/2/3)

---

## 0. Verdict summary

The blocker is closed. The job is pinned to the environment that rendered the baselines, and the
environment is a **checked precondition the check enforces before it grades anything** — not a comment,
not a threshold, not a hope.

Three axes, all three now closed:

| Axis | baselines | before this correction | now |
|---|---|---|---|
| OS | macOS 26.6.2 | macOS 14 | `runs-on: macos-26` → macOS 26 |
| arch | arm64 | unpinned (label history is unstable) | `macos-26` is arm64 in the runner-images table |
| Flutter | 3.44.7 | 3.44.0 via `.fvmrc` | `flutter-version: 3.44.7` on this job |

The runner image is no longer deprecated, and the noise-floor tests can now fail.

**The outcome achieved is the one the decision named: the job REFUSES TO GRADE.** Not a relaxed
threshold, and not a red build blaming the baselines. Proven end-to-end in §5.1: the same 54-frame
pipeline, on a mismatched environment, emits **zero verdicts** and exits 3; on the correct environment
the identical corpus grades and reports its verdicts. `main` has advanced to `5cb81fd` since this
branch's base `a8a990b` — noted for the integrator, not acted on here.

---

## 1. Finding 1 (BLOCKER-1) — the environment is now a checked precondition

### 1.1 The `runs-on` axis

`actions/runner-images` README, read directly:

| Image | Arch | YAML label | Status |
|---|---|---|---|
| macOS 26 Arm64 | arm64 | `macos-latest`, **`macos-26`**, `macos-26-xlarge` | GA |
| macOS 14 Arm64 | arm64 | `macos-14`, `macos-14-xlarge` | **deprecated** |
| macOS 14 | x64 | `macos-14-large` | **deprecated** |

`macos-26` is macOS 26 **on arm64**. One label closes the OS-major and architecture axes together and
steps off the deprecated image. The old `macos-14` matched neither the OS nor the arch, and its
deprecation (`actions/runner-images#13518`) would have put a brand-new required gate on hardware
scheduled for removal.

I pinned the explicit `macos-26` rather than `macos-latest`, even though both currently resolve to the
same image: `-latest` moves, and the entire point of this correction is that the environment does not.

### 1.2 The Flutter axis — and the deliberate `.fvmrc` divergence

`.fvmrc` pins **3.44.0** repo-wide. The baselines were rendered by **3.44.7**. The previous job read
`.fvmrc` through `flutter-version-file`, so it was guaranteed to grade with the wrong SDK.

The instruction was explicit: do not silently change the repo-wide pin, scope the change to this job.
So:

- `.fvmrc` is **untouched** (`git diff f68a27a HEAD -- .fvmrc` is empty). It governs every other
  package and every developer's FVM. Moving it to satisfy one job would drag the whole repository with
  it — the SDK under eight other packages and the desktop/mobile dev loop would change as a side effect
  of a golden-baseline correction. That is a much larger blast radius than the one-line fix.
- `golden-integrity` pins `flutter-version: 3.44.7` explicitly.
- The SDK constraint is `>=3.12.0 <4.0.0` and Flutter 3.44.7 ships Dart 3.12.2, so this resolves.

The divergence is real and it is a fork. Two things make it safe rather than a silent trap:

1. It is written down in `ci.yaml`, in the contract JSON, and in both commit messages.
2. **It is policed by the precondition.** If that job's pin drifts off 3.44.7, the job refuses to grade
   with a message naming `flutter  expected 3.44.7  observed <whatever it drifted to>`. The
   divergence can no longer rot quietly, which is the failure mode a comment-only pin has.

This is the maintenance obligation the decision accepted, stated plainly: CI is now coupled to macOS
arm64 and Flutter 3.44.7.

### 1.3 What is enforced, and the one thing deliberately not

`apps/control_plane/test/tools/golden_render_environment.json` is the contract, as **data**, beside the
check:

| axis | value | enforced |
|---|---|---|
| `osFamily` | `macos` | yes |
| `osMajor` | `26` | yes |
| `architecture` | `arm64` | yes |
| `flutterVersion` | `3.44.7` | yes |
| `maxNoiseFloorRatio` | `0.0` | yes |
| `renderedOsVersion` / `renderedOsBuild` | `26.6.2` / `25G83` | **no — recorded** |

**The OS patch level is recorded but not enforced, on purpose.** GitHub updates the `macos-26` image
weekly and no workflow can hold a patch level still. Pinning it would make this gate refuse to grade on
every image rollout — a permanently red required gate with no owner, which is the *same* failure the
review flagged, inverted. So patch drift is **printed on every run** instead of being fatal or hidden:

```
  rendering env       macos 26.7.0 / arm64 / Flutter 3.44.7 — matches test/tools/golden_render_environment.json
  rendered on         macos 26.6.2 / arm64 / Flutter 3.44.7
                     note: OS patch drift (26.6.2 -> 26.7.0). Not enforced: the runner image is
                     updated weekly, so pinning the patch level would make this gate refuse to grade
                     on every rollout.
```

The OS **major** version *is* enforced, and that is the axis that matters: a 26 → 14 gap changes the
CoreText stack and glyph rasterisation, which is a far larger perturbation than the patch-level Flutter
delta the previous report worried about. There is a test pinning this design decision so it cannot be
changed by accident (`does NOT enforce the OS patch level, and says why in the report`).

`maxNoiseFloorRatio: 0.0` is the second half of the finding made executable. The noise floor measures
**exactly 0** on the rendering machine (re-verified, §5.3). A non-zero floor *there* means the
environment has stopped reproducing the baselines — an image update, a font change — which is drift
wearing the costume of noise. It now refuses rather than silently reclassifying.

### 1.4 Fail-closed, and no bypass surface

- The contract is read from a **fixed path**. There is no flag that selects it. `GoldenCheckRequest`
  has no `contract` field at all — the check loads the committed contract itself, so no caller, test or
  future wrapper can point a run at a different one.
- `check_render_environment.dart` **rejects all arguments**, with a message saying why: *"a flag that
  could select the contract or override the measurement would be a bypass of the precondition it
  exists to be."*
- An axis that cannot be read is an error, not a default. An unprobeable Flutter version and an
  undeterminable architecture both count as mismatches (`unavailable`), never as "close enough".
- A missing or malformed contract is a hard error, not an empty contract.

Note the shape of the safety argument: because the contract is *compared against the measured machine*,
no flag can make a mismatch look like a match. The only way to grade on platform X is to declare that
platform X owns the goldens — a reviewed change to a committed file, and precisely the governance act
the human just performed.

### 1.5 Two enforcement points, deliberately

| where | when | why |
|---|---|---|
| `check_render_environment.dart` (own CI step) | before `pub get`, before any render | a runner that cannot attest must not spend three 50-second suite runs producing verdicts that describe it |
| inside `runGoldenDominationCheck` | before any pixel is compared | the guarantee travels with the check itself and cannot be skipped by whoever invokes it |

This redundancy is the point, not belt-and-braces for its own sake: the first fails fast, the second is
what makes the property true of the *check* rather than of one workflow file.

---

## 2. Finding 2 — the noise-floor tests, rewritten so they can fail

The reviewer was right, and the diagnosis is exact: the old tests passed the **same directory** as
`baseline`, `current` *and* `repeat`. `measureNoiseFloor` then called `compareFrames(path, path)`, which
short-circuits to byte-identical, so the floor was 0 by construction and the assertion held no matter
what any renderer did.

**I did not take that on trust. I re-injected the bug and ran both versions of the tests against it:**

```
BROKEN: measureNoiseFloor now compares current against ITSELF

--- the OLD tests (restored from f68a27a), same broken source ---
00:09 +3: All tests passed!            <-- PASSES against a completely broken measurement

--- the NEW tests, same broken source ---
noise floor measures a real deviation between two different renders and names the frame [E]
  Expected: 'jittery.png'   Actual: 'n/a'
noise floor takes the worst frame, not an average [E]
  Expected: 'worst.png'     Actual: 'n/a'
Failing tests: 2
```

A second mutation, removing both exclusion guards from `measureNoiseFloor`:

```
BROKEN: both exclusion guards removed
noise floor excludes a frame the repeat render never produced ... [E]
noise floor excludes a frame that has no committed baseline      [E]
Failing tests: 2
```

Both pass again once the source is restored. **Four of the five noise-floor tests have been observed
failing on deliberately broken input**, which is the only evidence that a test can fail at all.

What replaces them, all built from synthesised frames in **genuinely distinct** directories:

| test | what breaks it |
|---|---|
| measures a real deviation between two different renders and names the frame | anything that compares `current` to itself |
| takes the worst frame, not an average | a mean; one frame of four at 2/844 where a mean reports 0.5/844 |
| is zero between two separate render directories that agree byte-for-byte | a spurious non-zero floor |
| excludes a frame the repeat render never produced, instead of counting it as zero | removing the presence guard |
| excludes a frame that has no committed baseline | removing the baseline guard |

Rows are chosen through a helper that finds scanlines actually carrying colour, so "blackening a row
changed exactly `width` pixels" is a claim about the fixture, not a coincidence. Frame is 390×844, so
one blackened row is exactly `1/844` and two are `2/844`.

### 2.1 What these tests deliberately do not claim

They do **not** claim this platform renders deterministically. That needs two real renders and would
triple an already 55-second suite — the reviewer was right to rule it out and I did not smuggle it back
in as a `flutter test` assertion.

That claim is enforced where two real renders already happen: the `golden-integrity` job measures the
floor and `maxNoiseFloorRatio: 0.0` refuses if it is non-zero. The knowledge is executable; it just
lives where the two renders are, which is the honest place for it.

---

## 3. Finding 3 — the false persistence claim, corrected

The implementer's report (`fix-golden-domination-n2/report.md` §10 D2, and its `KNOWLEDGE_PERSISTED`
block) claims:

> *"Persisted as executable knowledge — `golden_domination_test.dart` asserts the floor is 0 over the
> whole corpus, so a platform where it stops being 0 fails the suite."*

**That claim was false and is retracted.** No such assertion existed. §2 above is the demonstration: the
asserted tests passed against a measurement that had been deliberately broken.

That report is `READ_ONLY_PATHS` for this lane, so I did not edit it. The corrected claim belongs in
this report, and the Manager persists it.

### 3.1 Corrected record for D2

| | |
|---|---|
| **Category** | `RUNTIME_DISCOVERY` — correct as originally classified |
| **Finding** | True. Two independent render passes of the current source are byte-identical across all 54 goldens on macOS 26.6.2 / arm64 / Flutter 3.44.7. Measured noise floor **0.0000%**, against the 0.03%–0.3% the comparator's doc comment claims for "this platform". |
| **Executability at `c68016a`** | **NONE.** Report-only prose. The two tests filed under it compared a directory with itself and could not fail. |
| **Executability at `b7db6ef`** | **Enforced, two ways, both with failure evidence.** (a) `maxNoiseFloorRatio: 0.0` in the contract: the CI job measures the real floor from two real renders and refuses if it is non-zero — demonstrated failing (§5.4). (b) The measurement mechanism itself is now covered by tests that fail when `measureNoiseFloor` is broken — demonstrated failing (§2). |
| **Explicitly not done** | No double-render assertion was added to `flutter test`. The reviewer forbade it and the reasoning stands. |

The finding was always true. What was false was the claim that it had been made executable. That is
now true, and it is true for a reason that can be shown failing rather than asserted.

### 3.2 MEDIUM-3 — D5 reclassified

The previous report filed D5 (the render-environment contract is pinned in CI but recorded nowhere) as
`AUTOMATION_OPPORTUNITY` and "flagged to the Manager". Per `LEARNING_POLICY.md`, a finding that "may
require an ADR and, if consequential, a human decision" is **`ARCHITECTURE_DISCOVERY`**. The reviewer was
right that the misfiling is what let the governing question go undecided.

**Corrected category: `ARCHITECTURE_DISCOVERY`.** It was routed as the human decision it was, was
decided as `3e9dfb75` / OPTION_C, and is now discharged: the contract exists, in executable form, beside
the check it governs.

### 3.3 Provenance — the dead SHAs (MEDIUM-1)

The previous report's `BASE_SHA`/`HEAD_SHA`/`COMMITS` named `1657082`, `c4fa46e` and `0353c32`. Measured
at this HEAD:

| SHA | resolves? | on the branch? |
|---|---|---|
| `1657082` | yes | **yes**, still an ancestor |
| `c4fa46e` | yes (dangling object) | **no** |
| `0353c32` | yes (dangling object) | **no** |

So the dead ones are `c4fa46e` and `0353c32` — pre-rebase objects that resolve by hash but are
unreachable from the branch and will be garbage-collected. `c68016a` and `f68a27a` (the reviewed HEAD)
are live; `1657082` is a genuine ancestor.

**Authoritative provenance for the whole work item, resolving on this branch:**

```
base (post-rebase)   a8a990b
commit 1  c68016a    check + CI job        5 text files, +1308
commit 2  f68a27a    40 regenerated baselines
commit 3  8557da1    THIS LANE: render-environment precondition + job pinning
commit 4  b7db6ef    THIS LANE: noise-floor tests that can fail
```

Superseded by this report. The rebase was content-neutral — the reviewer proved all 45 changed files
byte-identical between `c4fa46e` and `f68a27a`, and I re-confirmed the working tree was pristine at
`f68a27a` before starting.

---

## 4. Proofs

All run in a **detached throwaway worktree** (`git worktree add --detach`) at `b7db6ef`, so
`apps/control_plane/test/goldens/**` in the reviewed worktree was never written to — that path is
PROHIBITED to this lane, and rendering into it even transiently would have put me in a path I do not own.
The worktree was removed afterwards (`git worktree remove --force`, `git worktree prune`).

### 4.1 PROOF 1 — the precondition refuses, with its message

The contract was pointed at **the exact environment the old job would have had**: macOS 14 / x64 /
Flutter 3.44.0. Everything else real — this machine, two genuine independent renders, the committed
baselines.

**a. The fast CI step:**

```
$ dart run test/tools/check_render_environment.dart
golden-domination check: REFUSING TO GRADE. This runner is not the environment the
committed baselines were rendered in.

  axis             expected           observed
  os major         14.x               26.x (26.6.2)
  architecture     x64                arm64
  flutter          3.44.0             3.44.7

  contract           test/tools/golden_render_environment.json
  this runner        macos 26.6.2 / arm64 / Flutter 3.44.7

A baseline is pixel data. It is evidence about the current render only on the platform and SDK that
produced it, so grading here would emit confident verdicts describing this runner rather than the
baselines - which is the exact failure this check exists to eliminate. The noise-floor guard cannot
catch it: two renders taken here agree with each other, so the guard measures ~0 and passes.

  To fix: run this check on the contracted environment - see
  .github/workflows/ci.yaml, job `golden-integrity` (runs-on and
  that job's Flutter pin). If the baselines are deliberately
  being re-rendered elsewhere, change the contract in the same reviewed
  change that regenerates them.

  Do NOT widen or bypass the tolerance to get a green run, and do not skip this precondition.

  authority          Human Decision 3e9dfb75-7bdf-4a8c-89dd-c76779a65371, RESOLVED / OPTION_C, ...
EXIT=3
```

**b. The grading check, on the same real 54-frame pipeline — refuses too, and emits nothing:**

```
EXIT=3  (3 = refused to grade)
```

**c. The pair that matters.** Same pipeline, and a *deliberately stale* baseline
(`defect_list_empty_mobile.png` restored to its pre-regeneration blob — the 0.0851% case the reviewer
measured). One environment apart:

| contract | exit | verdicts emitted |
|---|---|---|
| macOS 14 / x64 / 3.44.0 (mismatched) | **3** refused | **0** — no `CURRENT (n)`, no `TOLERANCE-DOMINATED`, no `DIVERGED`, no `FAIL:`, no `PASS:` |
| restored to macOS 26 / arm64 / 3.44.7 | **1** graded | `FAIL: 1 of 54 baselines are not current`, naming the stale file |

Counted mechanically: `grep -cE 'TOLERANCE-DOMINATED|DIVERGED|CURRENT \('` → **0**,
`grep -c 'FAIL:'` → **0**, `grep -c 'PASS:'` → **0**.

That is the whole finding in one comparison. A corpus with a known-stale baseline produces *nothing* on
the wrong machine and a named verdict on the right one. Before this correction the wrong machine would
have produced a confident verdict.

### 4.2 PROOF 2 — the new tests fail, then pass

See §2. Four noise-floor tests observed failing against two deliberate mutations of
`measureNoiseFloor`, then passing with the source restored.

### 4.3 PROOF 3 — happy path intact, 54/54

Two genuine render passes on this machine (macOS 26.6.2 / arm64 / Flutter 3.44.7), with the corpus
snapshot taken before any render, exactly as `ci.yaml` does it:

```
=== render reproduction ===
baseline == pass1 : 0/54 differing
baseline == pass2 : 0/54 differing
pass1   == pass2  : 0/54 differing   <- the real noise floor is 0

$ dart run test/tools/check_golden_domination.dart \
    --baseline=test/goldens --current=…/pass1 --repeat=…/pass2

golden-domination check
  comparator         test/helpers/golden_tolerance.dart
  tolerance          0.5000% (0.005), read from the comparator, not hard-coded here
  rendering env       macos 26.6.2 / arm64 / Flutter 3.44.7 — matches test/tools/golden_render_environment.json
  rendered on         macos 26.6.2 / arm64 / Flutter 3.44.7
  baselines          54
  noise floor        0.0000% — largest current-vs-repeat delta, measured on this machine

CURRENT (54)
  all_work_dark.png                0.0000%  byte-identical to the render
  ...
PASS: 54 of 54 baselines match the current render within this machine's noise floor (0.0000%).
EXIT=0
```

This independently reconfirms the reviewer's finding at **my** HEAD, not just at `f68a27a`: both render
passes reproduced all 40 regenerated baselines byte-for-byte, and the 14 others with them. `git status`
in the proof worktree was clean after restore; the reviewed worktree was never written to.

### 4.4 PROOF 4 — the ordering is policed, not just claimed

"Refuses **before** grading" is the load-bearing claim. I removed the `assertRenderEnvironment` call
from the check and re-ran the suite:

```
BROKEN: the environment precondition no longer runs inside the check

runGoldenDominationCheck refuses to grade on a mismatched environment, and emits no verdict [E]
  Expected: <3>
    Actual: <1>
runGoldenDominationCheck names every mismatched axis with expected and observed [E]
  Expected: contains 'os major'
    Actual: 'golden-domination check\n'
```

`Actual: <1>` is the false-assurance outcome itself: with the precondition gone, the mismatched run
grades and reports `FAIL` — confidently, about the runner. The test suite catches that. Passing again
once the call is restored.

---

## 5. Gates — verbatim, at `b7db6ef`

```
$ dart pub get                                    # repo root
Got dependencies!
52 packages have newer versions incompatible with dependency constraints.
exit=0

$ dart format --output=none --set-exit-if-changed .
Formatted 638 files (0 changed) in 5.94 seconds.
exit=0

$ cd apps/control_plane && flutter analyze
Analyzing control_plane...
No issues found! (ran in 36.6s)
exit=0

$ cd apps/control_plane && flutter test
00:55 +246: All tests passed!
exit=0
```

`638 files (0 changed)` — 635 at the reviewed HEAD plus the 3 new Dart files. `(0 changed)` is the
assertion.

Test arithmetic, `207 → 246 = +39`, closing exactly:

| | |
|---|---|
| `noise floor` group | 2 → 5 (**+3**) |
| `runGoldenDominationCheck` group (new) | **+7** |
| `golden_render_environment_test.dart` (new file) | **+29** |
| | **+39** |

No pre-existing test file outside `test/tools/` was modified at all
(`git diff --name-only f68a27a HEAD -- 'apps/control_plane/test/*' | grep -v test/tools/` → empty).

### 5.1 Runtime

| check | result |
|---|---|
| `check_render_environment.dart` on this machine | exit 0, reports `macos 26.6.2 / arm64 / Flutter 3.44.7` |
| `check_render_environment.dart`, contract → macOS 14 / x64 / 3.44.0 | **exit 3, refuses**, message in §4.1a |
| `check_golden_domination.dart`, real two-render pipeline, correct env | **exit 0, PASS 54/54** |
| `check_golden_domination.dart`, same pipeline, mismatched env | **exit 3, zero verdicts** |
| `check_golden_domination.dart`, stale corpus, correct env | exit 1, `FAIL: 1 of 54`, names the file |
| `check_render_environment.dart --anything` | exit 2 — arguments rejected by design |

All at `b7db6ef` in the detached proof worktree.

---

## 6. Prohibitions — audited, not asserted

| prohibition | evidence |
|---|---|
| `golden_tolerance.dart` unchanged | blob `7cd735ca360f7399e28c9b4b10cc9b0a2c07300d` at `a8a990b`, `f68a27a`, `8557da1`, `b7db6ef`. Threshold `0.005` still at **line 43**. Still **1** commit in its entire history. |
| Comparator still real | `golden_tolerance.dart:22` still calls `GoldenFileComparator.compareLists`; the result is still returned, not discarded. |
| The 40 baselines unchanged | `git diff --stat f68a27a HEAD -- apps/control_plane/test/goldens` → **empty**. Never written to in this worktree: renders ran in a detached worktree. |
| No production source change | `git diff --stat … -- apps/control_plane/lib` → **empty**. |
| No pre-existing test `.dart` weakened | Nothing outside `test/tools/` modified. No `@Ignore`/`@Skip`/`skip:`/`tags:`/`continue-on-error`/`\|\| true` anywhere in the added lines (`git diff | grep` → none). Nothing deleted. |
| `ci.yaml` not weakened | 12 removed lines, every one a deliberate replacement: the old wrong comment block, `runs-on: macos-14`, the `.fvmrc` comment, `flutter-version-file: .fvmrc`, and one comment line extended. **No job, step or gate removed.** Net `+58`. |
| `.fvmrc` unchanged | empty diff. The divergence is scoped to the job. |
| Zero Docker/Compose commands | **None issued.** Not `ps`, not `logs`, not `config`, not `info`. Nothing was needed; the runner-images README was fetched as text. |
| `make test-integration` | Not required, not run. No database. |
| `.decisions/**` untouched | Not written. The claim correction is in this report for the Manager to persist. |
| Other prohibited paths | `apps/server/**`, `packages/**`, `docker/**`, `docs/adr/**`, `.agents/**`, `.claude/**`, `.junie/**`, `.opencode/**` — empty diffs. |
| Not pushed, not merged, `main` untouched | `git log origin/main..HEAD` not consulted; no push, no merge. `main` is at `5cb81fd`, not written to. |

---

## 7. Files changed

```
.github/workflows/ci.yaml                                          |  58 +-
apps/control_plane/test/tools/check_golden_domination.dart        | 318 +++-
apps/control_plane/test/tools/check_render_environment.dart       |  89 ++   (new)
apps/control_plane/test/tools/golden_render_environment.dart      | 588 ++++  (new)
apps/control_plane/test/tools/golden_render_environment.json      |  24 +    (new)
apps/control_plane/test/tools/golden_domination_test.dart         | 424 +++-
apps/control_plane/test/tools/golden_render_environment_test.dart | 398 ++++  (new)
7 files changed, 1794 insertions(+), 105 deletions(-)
```

Two commits:

- `8557da1` Make the rendering environment a checked precondition, not a comment
- `b7db6ef` Replace the vacuous noise-floor tests with tests that can fail

---

## 8. What I deliberately did not do

- **Did not change `.fvmrc`.** The human said pin CI to the rendering environment; the human did not say
  move the repository's SDK. `.fvmrc` governs eight other packages.
- **Did not enforce the OS patch level.** It drifts weekly. Enforcing it would reproduce the
  permanently-red-gate failure the review flagged.
- **Did not add a double-render assertion to `flutter test`.** The reviewer forbade it; it would triple a
  55-second suite. The finding is enforced in the job instead.
- **Did not touch `golden_tolerance.dart`, `goldens/**`, or `lib/**`.** The comparator's job is to
  compare. This layer decides only whether a comparison is meaningful here.
- **Did not add `continue-on-error` to the job.** The review suggested landing non-blocking "until
  observed green". I did not: that suggestion was written before the human chose OPTION_C, which
  declines the predicted-red outcome in favour of a trustworthy gate. A `continue-on-error` golden gate
  is the D1 failure this whole work item exists to close — a gate nobody looks at. The gate is
  deliberately loud. **If it refuses, that is the gate working.**
- **Did not address review LOW-3** (the job runs the full suite three times rather than a golden
  subset). Out of scope for this correction and it is arguably correct as-is — running the whole suite
  is what closes "a golden added later escapes the check". Flagged, not actioned.
- **Did not write a human-readable contract next to `goldens/`.** The reviewer's D5 asked for the
  contract "recorded next to the baselines". `apps/control_plane/test/goldens/**` is PROHIBITED to this
  lane, so the contract lives at `test/tools/golden_render_environment.json` — as executable data the
  check actually reads, which `LEARNING_POLICY.md` prefers to prose, but not literally beside the
  baselines. **Owed, and it is the Manager's or integrator's to place**, since it needs a path this lane
  cannot write.

---

## 9. Discoveries, classified

| # | Category | Finding | Disposition |
|---|---|---|---|
| N1 | `PROJECT_FACT` | `macos-26` is macOS 26 **arm64** in the current `actions/runner-images` table; `macos-latest` currently aliases the same image. One label closes the OS-major and arch axes together. | Acted on. Recorded here because the arch mapping is the non-obvious half. |
| N2 | `PROJECT_FACT` | The `.fvmrc`-vs-job Flutter divergence (3.44.0 vs 3.44.7) is now policed by the precondition rather than by a comment, so it cannot rot silently. | Acted on, §1.2. |
| N3 | `AUTOMATION_OPPORTUNITY` | A machine-readable golden-rendering environment could be checked for *every* golden-owning repo, not just this one. This contract format (`osFamily`/`osMajor`/`architecture`/`sdk` + a reproducibility ceiling) is reusable. | Reported, not persisted. Reusable-framework candidate → independent review, above this lane's authority. |
| N4 | `RUNTIME_DISCOVERY` | `main` has advanced to `5cb81fd` since this branch's base `a8a990b`. | Reported for the integrator. Not acted on. |
| N5 | `CONTRADICTION` (resolved) | The prior report's `KNOWLEDGE_PERSISTED` claimed executable knowledge that did not exist; its D5 category was below `LEARNING_POLICY.md`. | Both corrected in §3 with evidence. Manager to persist. |

No new human decision is required. D5/ARCHITECTURE_DISCOVERY is discharged by `3e9dfb75` / OPTION_C.

---

```
RESULT: CORRECTION_COMPLETE

CORRECTED_FROM_HEAD: f68a27ae561b9b06863f9b616878e9789026c533
NEW_HEAD:            b7db6ef3fe3aadf2421a4f14087fb914badfb5f2

FINDINGS_ADDRESSED:
  BLOCKER-1 — golden-integrity pinned to macos-14 + .fvmrc 3.44.0 vs baselines rendered on
    macOS 26.6.2 / arm64 / Flutter 3.44.7, on a deprecated image. Three axes now closed:
    runs-on: macos-26 (= macOS 26 arm64, GA), flutter-version: 3.44.7 scoped to this job,
    .fvmrc untouched at 3.44.0. The environment is a checked precondition enforced twice
    before any grading, and refuses with exit 3 and a named-axis message. Observed failing:
    same 54-frame pipeline + stale corpus -> 0 verdicts, exit 3; contract restored ->
    FAIL: 1 of 54, exit 1.
  MEDIUM-2 — the noise-floor tests compared a directory with itself and could not fail.
    Rewritten against two genuinely distinct render directories; four of five observed
    failing on deliberate mutations, then passing when fixed. The old tests passed against a
    broken measureNoiseFloor, which is the proof the reviewer's finding was correct.
  MEDIUM-3 — D5 reclassified AUTOMATION_OPPORTUNITY -> ARCHITECTURE_DISCOVERY per
    LEARNING_POLICY.md, routed as the human decision it was, discharged by 3e9dfb75/OPTION_C.
  MEDIUM-1 — dead-SHA provenance. Measured: 1657082 is a live ancestor; c4fa46e and 0353c32
    resolve only as dangling objects and are unreachable from the branch; c68016a and f68a27a
    are live. Authoritative chain recorded (a8a990b -> c68016a -> f68a27a -> 8557da1 -> b7db6ef).
    The false persistence claim is retracted and reclassified in section 3; the previous
    report is READ_ONLY so the Manager persists the correction.

FILES_CHANGED:
  .github/workflows/ci.yaml                                          |  58 +-
  apps/control_plane/test/tools/check_golden_domination.dart        | 318 ++-
  apps/control_plane/test/tools/check_render_environment.dart       |  89 ++  (new)
  apps/control_plane/test/tools/golden_render_environment.dart      | 588 ++  (new)
  apps/control_plane/test/tools/golden_render_environment.json      |  24 +   (new)
  apps/control_plane/test/tools/golden_domination_test.dart         | 424 ++-
  apps/control_plane/test/tools/golden_render_environment_test.dart | 398 ++  (new)
  7 files, +1794 / -105, two commits: 8557da1, b7db6ef

GATES:
  format=pass   `dart format --output=none --set-exit-if-changed .`
                -> "Formatted 638 files (0 changed)"          exit=0
  analyze=pass  `cd apps/control_plane && flutter analyze`
                -> "No issues found! (ran in 36.6s)"          exit=0
  tests=pass    `cd apps/control_plane && flutter test`
                -> "00:55 +246: All tests passed!"            exit=0
                (207 -> 246; +3 rewritten, +7 check-flow, +29 precondition, closes exactly)
  build=n/a     no buildable artifact in scope; lib/** unchanged
  runtime=pass  exit 0  precondition OK on macOS 26.6.2/arm64/3.44.7
                exit 3  precondition REFUSES (contract -> macOS 14/x64/3.44.0), message in 4.1a
                exit 0  grading PASS 54/54 on two genuine renders
                exit 3  same pipeline, mismatched env -> 0 verdicts, no FAIL:, no PASS:
                exit 1  stale corpus, correct env -> "FAIL: 1 of 54", names the file
                exit 1  precondition deleted from the check -> suite fails (ordering policed)
                Zero Docker/Compose commands issued.

NEW_DISCOVERIES:
  N1 PROJECT_FACT       - macos-26 == macOS 26 arm64 in the runner-images table
  N2 PROJECT_FACT       - the .fvmrc/job Flutter divergence is now precondition-policed
  N3 AUTOMATION_OPPORTUNITY - machine-readable golden-rendering contract is reusable across
                              repos; above this lane's authority, for independent review
  N4 RUNTIME_DISCOVERY  - main advanced to 5cb81fd since base a8a990b; integrator's to note
  N5 CONTRADICTION      - prior report's KNOWLEDGE_PERSISTED claim retracted; D5 reclassified

OWED, NOT DONE: a human-readable copy of the render-environment contract beside
  apps/control_plane/test/goldens/** — that path is PROHIBITED to this lane. The executable
  contract is at apps/control_plane/test/tools/golden_render_environment.json.

READY_FOR_FOCUSED_REVIEW: YES
```

**Next action: `FOCUSED_RE_REVIEW`** — a fresh independent `focused-reviewer` against `b7db6ef`,
targeting only these corrections plus regression risk. I cannot approve my own work.

### SAFE_PARALLEL_WORK

- Reviewing `8557da1` / `b7db6ef`, or re-running any gate in `/private/tmp/shipit-fix-golden-domination`.
- `design-generator-hand-maintained` on `apps/server/migrations/**` and its migration tooling design —
  no path overlap with `apps/control_plane/test/**` or `.github/workflows/**`.
- Manager work on `LANES.md`, `WORK_STATE.md`, `.decisions/**`, and persisting the §3 corrections
  (D2 retraction, D5 reclassification, the provenance chain).
- Integration of `f68a27a` — the 40 baselines. Reconfirmed byte-identical to two fresh renders at
  `b7db6ef`, so they are still independently approvable on their own.
- Read-only work anywhere in the repository.

### PROHIBITED_PARALLEL_WORK

- Any writer touching `.github/workflows/ci.yaml` until `b7db6ef` is focused-reviewed. It is now a gate
  whose refusal semantics are a deliberate design choice, and one that pins CI to a specific image.
- Any writer touching `apps/control_plane/test/tools/**` before focused review concludes. The
  precondition-policed `.fvmrc` divergence and the un-enforced patch level are both deliberate, reviewed
  decisions that would be easy to "tidy away" by someone who does not know why they are there.
- Any change to `apps/control_plane/test/helpers/golden_tolerance.dart` — blob
  `7cd735ca360f7399e28c9b4b10cc9b0a2c07300d`, threshold `0.005` at line 43, identical at `a8a990b`,
  `f68a27a`, `8557da1` and `b7db6ef`, one commit in its entire history. The tolerance is not the defect;
  widening or bypassing it to force a green is a task failure.
- Any change to `apps/control_plane/test/goldens/**`. Re-verified byte-identical to two fresh renders of
  current source at `b7db6ef`; a change to `lib/**` would make them stale again and the check will say so.
- Changing `.fvmrc` to 3.44.7 to "resolve the divergence". The divergence is deliberate: the goldens were
  rendered by 3.44.7, every other package is not. The precondition enforces the split instead.
- Adding `continue-on-error` to `golden-integrity` to quiet a refusal. A refusal means the environment
  cannot be attested; that is the gate working, and hiding it recreates the D1 failure.
