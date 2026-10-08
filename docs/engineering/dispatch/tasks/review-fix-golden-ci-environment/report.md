# Focused Re-review — review-fix-golden-ci-environment

**Lane under review:** `correction-implementer`, branch `fix/golden-domination-n2`
**Worktree:** `/private/tmp/shipit-fix-golden-domination`
**CORRECTED_FROM_HEAD:** `f68a27ae561b9b06863f9b616878e9789026c533`
**NEW_HEAD claimed:** `b7db6ef3fe3aadf2421a4f14087fb914badfb5f2`
**Authority:** Human Decision `3e9dfb75-7bdf-4a8c-89dd-c76779a65371` — `RESOLVED` / **OPTION_C**
**Prior blocking review:** `review-fix-golden-domination-n2/report.md` (`DO_NOT_MERGE`,
`HUMAN_DECISION_REQUIRED: YES`, BLOCKER-1 + MEDIUM-1/2/3)
**Reviewer lane:** `focused-reviewer` (independent, read-only)

---

## 0. Verdict summary

**All four handed-in findings are genuinely resolved.** I did not accept the correction report's
proofs — I re-derived them from scratch, including three mutations of my own that the agent did not
report. BLOCKER-1 is closed on the merits: the job targets a real arm64 macOS 26 image, the Flutter
pin is exact, and the environment is a checked precondition that is **policed by tests**, not merely
present in the source order. The decisive comparison reproduces exactly:

| contract on the same 54-frame corpus with a known-stale baseline | exit | verdicts emitted |
|---|---|---|
| macOS 14 / x64 / 3.44.0 (mismatched) | **3** refused | **0** — stdout is literally zero lines |
| macOS 26 / arm64 / 3.44.7 (correct) | **1** graded | `FAIL: 1 of 54`, naming `defect_list_empty_mobile.png` at 0.0851% / 280/329160 px / peak 234 |

**No blockers. No regressions.** Four non-blocking findings, all of them accuracy issues in the
report's own prose rather than defects in the correction. Every central prohibition holds, verified by
blob, not by assertion.

---

## 1. PROVENANCE — verified

```
$ git rev-parse HEAD
b7db6ef3fe3aadf2421a4f14087fb914badfb5f2
$ git status --porcelain --untracked-files=all
(empty — pristine, including untracked)
$ git log --oneline -6
b7db6ef Replace the vacuous noise-floor tests with tests that can fail
8557da1 Make the rendering environment a checked precondition, not a comment
f68a27a Regenerate the 40 stale golden baselines
c68016a Fail the build when a golden passes only because the tolerance hid it
a8a990b decisions: resolve all three (...)
1657082 decisions: file three PENDING decisions; correct stale 70b47372 index row
```

HEAD matches the claimed `NEW_HEAD` exactly, sits directly on top of `f68a27a`, two commits as
described.

### 1.1 Changed set — inside `OWNED_PATHS` only

```
$ git diff --name-only f68a27a HEAD
.github/workflows/ci.yaml
apps/control_plane/test/tools/check_golden_domination.dart
apps/control_plane/test/tools/check_render_environment.dart
apps/control_plane/test/tools/golden_domination_test.dart
apps/control_plane/test/tools/golden_render_environment.dart
apps/control_plane/test/tools/golden_render_environment.json
apps/control_plane/test/tools/golden_render_environment_test.dart
```

7 files, +1794 / −105. Every path falls under `.github/workflows/**` or
`apps/control_plane/test/tools/**`. **Nothing outside ownership.** Notably
`test/tools/golden_domination.dart` and `test/tools/png_pixel_diff.dart` — the *grading logic itself*
— are **unchanged** by this correction. The layer was added beside them, not through them.

---

## 2. ENVIRONMENT PINNED — verified independently

### 2.1 `.fvmrc` is untouched — this is the critical item, confirmed three ways

```
$ git diff --stat f68a27a HEAD -- .fvmrc      → empty
$ git diff --stat a8a990b  HEAD -- .fvmrc      → empty   (whole branch, not just this correction)

blob:  a8a990b  457360f80661d694997014bf132873675dc1c88f
       f68a27a  457360f80661d694997014bf132873675dc1c88f
       8557da1  457360f80661d694997014bf132873675dc1c88f
       b7db6ef  457360f80661d694997014bf132873675dc1c88f
       worktree 457360f80661d694997014bf132873675dc1c88f
       content:  {"flutter": "3.44.0"}

$ git log --all --oneline -- .fvmrc
0d5d132 chore(baseline): commit the product implementation that existed only as uncommitted state
```

One blob across every revision and the working tree, and the only commit that has ever touched the
file is `0d5d132`, which predates this lane. **`.fvmrc` is byte-for-byte unchanged.** The repo-wide SDK
pin that governs every other package and every developer did not move.

### 2.2 The label and the pin really are in the workflow

```yaml
  golden-integrity:
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.44.7
          channel: stable
```

`flutter-version-file: .fvmrc` is gone; the previous `runs-on: macos-14` is gone. The pin is scoped to
this one job — no other job in `ci.yaml` was touched.

### 2.3 Is `macos-26` really arm64? — **Yes. Confirmed at source, not from the report.**

`actions/runner-images` README, fetched directly:

| Image | Arch | YAML Label | Status |
|---|---|---|---|
| macOS 26 Arm64 | **arm64** | `macos-latest`, **`macos-26`**, `macos-26-xlarge` | GA (no badge) |
| macOS 26 | x64 | `macos-latest-large`, `macos-26-intel`, `macos-26-large` | GA |
| macOS 14 Arm64 | arm64 | `macos-14`, `macos-14-xlarge` | **deprecated** (`runner-images#13518`) |
| macOS 14 | x64 | `macos-14-large` | **deprecated** |

One label closes the OS-major and architecture axes together, and steps off the deprecated image.
Both the agent's claim and the report's table are correct. (The prior reviewer's own note that
"`macos-14` maps to the arm64 image in the current table" is also confirmed — `macos-14` was arm64, and
deprecated; the new pin is arm64, and GA.)

### 2.4 Is Flutter 3.44.7 actually installable there? — **Yes, and exactly, not "latest stable".**

This was the one place where `channel: stable` could have silently degraded the pin into "whatever is
newest", which would have made the precondition refuse forever. I checked the action's implementation
rather than its prose:

- `action.yaml` passes `-n '${{ inputs.flutter-version }}'` and `-a '${{ inputs.architecture }}'` to
  `setup.sh`, with `architecture` defaulting to `${{ runner.arch }}` (arm64 on this image).
- `setup.sh:160` — `filter_by_channel "$CHANNEL" | filter_by_arch "$ARCH" | filter_by_version "$VERSION"`.
  With `VERSION=3.44.7` that is an **exact version match inside the stable channel**, not a channel
  head. The README's first documented pattern is exactly this combination ("Use specific version and
  channel").
- Flutter 3.44.7 stable darwin-arm64 exists and is what produced these baselines: this machine reports
  `frameworkVersion 3.44.7`, `channel stable`, `dartSdkVersion 3.12.2`, on macOS 26.6.2 / arm64.

**Verdict on the silent-no-op concern: not applicable, and not reachable.** If the label were wrong the
job would fail at *runner allocation* ("no runner matching labels"), not grade; if the Flutter version
were unavailable the action step would fail; if the SDK installed but differed from the contract the
precondition refuses with exit 3. There is no path on which the gate silently grades. I verified all
four exit paths by execution (§3, §4).

### 2.5 No `continue-on-error` was added — confirmed

```
$ grep -rn "continue-on-error" .github/                                  → (none)
$ git diff f68a27a HEAD | grep "continue-on-error"                       → (none)
$ git diff f68a27a HEAD | grep -E "^\+" | grep -iE "@Ignore|@Skip|skip:|tags:|only-tags|exclude-tags|\|\| true|xfail"
                                                                               → (none)
```

The agent's reasoning for declining it is also right, and I endorse it: the reviewer's
"land non-blocking until observed green" suggestion was written *before* the human chose OPTION_C, and
a non-blocking golden gate is precisely the D1 failure this work item exists to close. A refusal being
loud is the gate working.

---

## 3. PRECONDITION IS CHECKED BEFORE GRADING, AND REFUSES — verified

### 3.1 Ordering in the workflow

`ci.yaml`, `golden-integrity`, in order: checkout → install Flutter → analytics off →
**`flutter pub get`** → **`Refuse to grade unless this is the rendering environment`** →
snapshot baselines → `flutter test` → render pass 1 → render pass 2 → grade.

The precondition precedes **every render and every grading call**. ✔
(Minor: the report's §1.5 says this step runs "before `pub get`". It runs *after* `pub get`, necessarily
— `dart run` needs resolved dependencies. The load-bearing claim, "before any render", holds. See
Finding 2.)

### 3.2 Ordering inside the check

`runGoldenDominationCheck` calls `RenderEnvironmentContract.load()` then `assertRenderEnvironment(...)`
**before** `measureNoiseFloor` and **before** `gradeGoldens`. On refusal it returns
`exitCode: exitRefusedToGrade` with `output: []` — the empty verdict list is structural, not incidental,
because the throw happens before the grading call is reached.

### 3.3 No flag selects or overrides the environment contract — confirmed by enumerating the surface

- `check_render_environment.dart` **rejects all arguments**: `dart run … --force` → exit 2,
  *"This tool takes no arguments on purpose: a flag that could select the contract or override the
  measurement would be a bypass of the precondition it exists to be."* ✔ (executed)
- `check_golden_domination.dart` `_Options.parse` accepts exactly `--baseline`, `--current`,
  `--repeat`, `--tolerance`, `--help`. Nothing environment-related. ✔ (read in full)
- `GoldenCheckRequest` has **no `contract` field** — the check loads the committed contract from the
  fixed path `test/tools/golden_render_environment.json` itself, so no caller, test or future wrapper can
  substitute one. ✔
- `--tolerance` cannot relax anything: it is compared against the value parsed out of the comparator and
  rejected on any difference (`if ((declared - tolerance).abs() > 1e-12)`).
- Fail-closed on unreadable axes, confirmed by reading the code and by test: a missing contract is a
  `StateError`; a malformed one a `FormatException`; an unprobeable Flutter version and an
  undeterminable architecture both surface as `unavailable`, never as "close enough".

The safety argument holds in the right direction: because the contract is compared against the
**measured machine**, no flag can make a mismatch look like a match. The only way to grade on platform X
is to declare that platform X owns the goldens — a reviewed change to a committed file, which is the
governance act the human just performed.

### 3.4 The ordering is **policed**, not merely present — my own mutation

I copied the worktree to scratch (never editing the reviewed tree) and deleted the precondition call
from inside the check:

```
MUTATION: assertRenderEnvironment no longer runs inside the check

runGoldenDominationCheck refuses to grade on a mismatched environment, and emits no verdict [E]
  Expected: <3>
    Actual: <1>
runGoldenDominationCheck names every mismatched axis with expected and observed [E]
  Expected: contains 'os major'
    Actual: 'golden-domination check\n'

00:00 +5 -2: Some tests failed.
```

`Actual: <1>` is the false-assurance outcome itself: with the precondition gone, the mismatched run
**grades and reports `FAIL`** — confidently, about the runner. The suite catches it. This is the
reviewer's demand satisfied by execution, and I reproduced it independently.

---

## 4. NOISE-FLOOR TESTS CAN NOW FAIL — proven with three mutations, two of them mine

The prior review's diagnosis was exact: the old tests passed the **same directory** as `baseline`,
`current` *and* `repeat`; `measureNoiseFloor` then called `compareFrames(path, path)`, which
short-circuits to byte-identical, so the floor was 0 by construction.

### 4.1 My mutation A1 — reintroduce the exact original bug

`measureNoiseFloor` changed to compare `current` against itself:

- **New tests:** 2 failing —
  `noise floor measures a real deviation between two different renders and names the frame`
  (Expected `'jittery.png'`, Actual `'n/a'`) and
  `noise floor takes the worst frame, not an average` (Expected `'worst.png'`, Actual `'n/a'`).
- **Old tests, restored verbatim from `f68a27a`, against the same broken source:**
  `00:03 +3: All tests passed!`

Both halves of the agent's demonstration reproduce. The old tests cannot fail; the new ones do.

### 4.2 My mutation A2 — *not reported by the agent*

`noiseFloorOf` changed to return a **mean** and the first filename instead of the worst frame:

```
00:00 +1 -1: noise floor measures a real deviation between two different renders and names the frame [E]
00:00 +1 -2: noise floor takes the worst frame, not an average [E]
00:00 +1 -3: noise floor is zero between two separate render directories that agree byte-for-byte [E]
```

3 of the 5 fail. The rewrite detects a class of bug the agent's own mutations did not exercise.

### 4.3 What the new tests are actually made of

Genuinely distinct directories, asserted (`expect(pass1.path, isNot(pass2.path))`), seeded with frames
synthesised into two separate trees; rows chosen through `_nthColouredRow` so the "blackening a row
changed exactly `width` pixels" claim is about the fixture. `defect_list_empty_mobile.png` is 390×844,
so one blackened row is exactly `1/844` and two are `2/844`. I measured the fixture directly: rows 0, 1
and 2 of that frame are **390/390 non-black**, so the arithmetic the assertions depend on holds today.

The group also gained negative coverage the old one lacked: a frame the repeat render never produced, a
frame with no committed baseline, and (in the `runGoldenDominationCheck` group) a stale corpus, an
agreeing corpus, a mismatched environment, an unreadable comparator, and a missing directory.

### 4.4 What they deliberately do not claim

They do not claim this platform renders deterministically — that needs two real renders and would
triple a ~45-second suite, which the prior review forbade. The agent did not smuggle it back in. It is
enforced where two real renders already happen (§5). The separation is correct and honestly documented
in both the library doc comment and the test file.

---

## 5. PROHIBITIONS — all held, verified by blob

| prohibition | evidence |
|---|---|
| `golden_tolerance.dart` unchanged | blob `7cd735ca360f7399e28c9b4b10cc9b0a2c07300d` at `a8a990b`, `f68a27a`, `8557da1`, `b7db6ef` **and the working tree**. Threshold `0.005` still at **line 43**. `git log --all -- <path>` → **one** commit ever (`4e1fdb9`, long predating this lane). `git diff f68a27a HEAD` on it → empty. |
| Comparator still real | `golden_tolerance.dart` is untouched, and `golden_domination.dart` (the caller) is untouched by this correction. `readComparatorThreshold` is still what supplies the tolerance, and the CLI still prints `tolerance 0.5000% (0.005), read from the comparator, not hard-coded here`. |
| `goldens/**` not modified | `git diff --stat f68a27a HEAD -- apps/control_plane/test/goldens` → **empty**. Additionally I hashed all 54 worktree blobs against `f68a27a`: `checked=54 differing=0`. **Not one byte changed.** |
| Nothing leaked into the goldens directory | The agent rendered in a detached throwaway worktree; `git worktree list` shows no such worktree remains. **I did the same discipline**: my two full `--update-goldens` render passes ran in a scratch *copy* outside both the worktree and the repository, and `git status --porcelain --untracked-files=all` in the reviewed worktree was empty after every gate, after both renders, and at the end. `git worktree list` shows only the reviewed worktree for this branch. |
| No production source change | `git diff --name-only a8a990b HEAD -- apps/control_plane/lib` → **empty**. |
| No pre-existing test `.dart` weakened | `git diff --name-only f68a27a HEAD -- 'apps/control_plane/test/*' \| grep -v '^apps/control_plane/test/tools/'` → **empty**. The only pre-existing test file touched is `golden_domination_test.dart`, and its **entire 12-line removal is the body of the two vacuous noise-floor tests** — nothing else was deleted. No `@Ignore`/`@Skip`/`skip:`/`tags:`/`only-tags`/`exclude-tags`/`\|\| true` on any added line (grep → none). |
| `ci.yaml` not weakened | 46 insertions / **12 deletions**, and I enumerated **every** removed line: 5 lines of the old wrong comment block, `runs-on: macos-14`, 5 lines of the `.fvmrc` comment, `flutter-version-file: .fvmrc`, and 1 comment line extended. **No job, step or gate removed.** |
| Other prohibited paths | `apps/server/**`, `packages/**`, `docker/**`, `docs/adr/**`, `.decisions/**`, `.agents/**`, `.claude/**`, `.junie/**`, `.opencode/**` → all empty diffs. |
| Zero Docker/Compose | **None issued by this lane** — no `ps`, `logs`, `info`, `config`, `down`, `up`. **None issued by me either.** Compose files were not needed; the runner-images README and the action sources were fetched as text. |

---

## 6. FALSE CLAIM RETRACTED, PROVENANCE MEASURED — both verified

### 6.1 The retraction is real, and it is demonstrated rather than asserted

`correct-golden-ci-environment/report.md` §3 quotes the prior `KNOWLEDGE_PERSISTED` claim verbatim,
states **"That claim was false and is retracted"**, and reclassifies D2 as
`RUNTIME_DISCOVERY` / report-only prose at `c68016a` versus enforced at `b7db6ef`. The prior report was
`READ_ONLY_PATHS`, so leaving it unedited and correcting the record here is the right call — the Manager
persists it.

The retraction is not an assertion. **I proved the claim was false the same way:** the old tests,
restored from `f68a27a`, passed against a measurement I deliberately broke (§4.1). And I confirmed the
replacement claim — D2 *is* now executable in two places: `maxNoiseFloorRatio: 0.0` in the contract
(refuses a non-zero floor) and the five rewritten noise-floor tests (fail when `measureNoiseFloor` or
`noiseFloorOf` is broken).

### 6.2 Provenance measured, not assumed — my measurement matches exactly

| SHA | resolves? | ancestor of `b7db6ef`? | contained by any ref? |
|---|---|---|---|
| `1657082` | yes, commit | **yes** | yes — `main`, `fix/golden-domination-n2`, + 4 design branches |
| `c4fa46e` | yes, commit | **no** | **no** (unreachable → will be GC'd) |
| `0353c32` | yes, commit | **no** | **no** (unreachable → will be GC'd) |
| `c68016a`, `f68a27a` | yes | yes | `fix/golden-domination-n2` |

The agent's table is correct: `1657082` is a genuine ancestor, `c4fa46e` and `0353c32` are dangling
pre-rebase objects. The authoritative chain it records
(`a8a990b → c68016a → f68a27a → 8557da1 → b7db6ef`) is what `git log` shows.

### 6.3 D5 reclassification — correct

`AUTOMATION_OPPORTUNITY` → **`ARCHITECTURE_DISCOVERY`** per `LEARNING_POLICY.md`, routed as the human
decision it was, discharged by `3e9dfb75` / OPTION_C. The reviewer was right that the misfiling is what
let the governing question go undecided.

---

## 7. GATES — re-run by me at `b7db6ef`, verbatim

`dart pub get` at repo root first.

```
$ dart pub get                                    # repo root
Got dependencies!
52 packages have newer versions incompatible with dependency constraints.
exit=0

$ dart format --output=none --set-exit-if-changed .
Formatted 638 files (0 changed) in 6.20 seconds.
exit=0

$ cd apps/control_plane && flutter analyze
Analyzing control_plane...
No issues found! (ran in 27.7s)
exit=0

$ cd apps/control_plane && flutter test
00:43 +246: All tests passed!
exit=0
```

All four pass, matching the agent's report exactly: **638 files, 0 changed** (635 at `f68a27a` plus the
3 new Dart files — `(0 changed)` is the assertion) and **246 tests**. `pubspec.lock` was not dirtied;
the tree stayed pristine throughout.

**Test arithmetic closes independently.** I counted the declarations myself rather than trusting the
table: noise-floor group `2 → 5` (**+3**), `runGoldenDominationCheck` group (**+7**, all new),
`golden_render_environment_test.dart` (**+29**, new file). `3 + 7 + 29 = +39`, and `207 + 39 = 246`. ✔

**Runtime evidence, all re-executed by me** (scratch copy, real two-render pipeline):

| check | result |
|---|---|
| `check_render_environment.dart` on this machine | exit **0** — `macos 26.6.2 / arm64 / Flutter 3.44.7` |
| `check_render_environment.dart --force` | exit **2** — arguments rejected by design |
| same tool, contract → macOS 14 / x64 / 3.44.0 | exit **3**, refuses, names all three axes |
| real 54-frame pipeline, correct env, corpus current | exit **0** — `CURRENT (54)`, `PASS: 54 of 54`, noise floor `0.0000%` |
| same pipeline + one deliberately stale baseline, correct env | exit **1** — `FAIL: 1 of 54`, names the file |
| same pipeline + same stale baseline, mismatched env | exit **3** — **stdout is zero lines**: no `CURRENT (`, no `TOLERANCE-DOMINATED`, no `FAIL:`, no `PASS:` |
| `assertRenderEnvironment` deleted from the check | suite **fails** — `Actual: <1>`, the false-assurance outcome |

Two genuine render passes reproduced all 54 committed baselines byte-for-byte and agreed with each other
(`baseline vs pass1 = 0`, `baseline vs pass2 = 0`, `pass1 vs pass2 = 0` differing), which **reconfirms
at `b7db6ef`** — not only at `f68a27a` — that the 40 regenerated baselines are still current, and that
`maxNoiseFloorRatio: 0.0` is satisfiable on the contracted machine. The stale-baseline figures
(`0.0851%`, `280/329160 px`, peak 234) are now reproduced by three independent reviewers.

---

## 8. REGRESSIONS — none

Every behaviour change in the correction is a **tightening**, not a loosening:

| change | before | after | direction |
|---|---|---|---|
| environment check | none | refuses before grading (exit 3) | stricter |
| noise-floor ceiling | `< 0.005` tolerance → proceed | `<= 0.0` → else refuse (exit 3) | stricter |
| "machine too noisy" exit code | 2 | 3 (`refused to grade`) | clearer |
| `main()` structure | inline `exit()` calls | split into `runGoldenDominationCheck` returning an outcome | testable, same verdicts |
| flags | `--baseline/--current/--repeat/--tolerance` | identical set | unchanged |
| grading logic (`golden_domination.dart`, `png_pixel_diff.dart`) | — | **untouched** | unchanged |

The one consequence worth naming: a legitimately *slightly* jittery `macos-26` image (floor 0.1%, still
under the comparator's tolerance) would now **refuse** rather than grade. That is the deliberate design
— "drift wearing the costume of noise" — it is documented in the contract, the library doc comment, the
`ci.yaml` header and pinned by a test, and refusing is the correct outcome when the machine has stopped
reproducing the baselines. Not a regression.

I found no regression in previously-approved behaviour: the check still grades a snapshot without
writing to baselines, the tolerance is still read from the comparator and not hard-coded, the happy path
is byte-identical in shape, and no pre-existing gate was removed.

---

## 9. Non-blocking findings

### FINDING 1 (LOW) — the "SDK unavailable" contingency is a red build, not a refusal

The decision text names two contingencies. One is implemented; the other is not, and the report's §0
claims both are.

> Decision: *"3.44.7 may not be available on the chosen runner image. If it is not, the honest outcome is
> a job that REFUSES TO GRADE with a clear message, not a tolerance change and not a red build."*

- **Environment-mismatch axis** → refusal, exit 3, clear message, zero verdicts. **Implemented and
  verified.** ✔
- **SDK-not-installable axis** → `subosito/flutter-action` runs *before* the precondition, so if 3.44.7
  cannot be fetched for `darwin-arm64` the action step fails and the job goes **red at the SDK install**.
  The precondition cannot attest an SDK that does not exist, so this is an inherent ordering constraint,
  not an oversight in the placement.

Why this is **not** a blocker: it is not reachable today (3.44.7 stable darwin-arm64 demonstrably exists
and is what produced the baselines); every path is **loud**; and it is **never a false pass and never a
baseline verdict** — the D1 harm the decision cares about cannot occur. The lane's blanket refusal to
add `continue-on-error` is right for the gate, but too coarse for this one step.

Actionable, optional: give the install step an id with `continue-on-error: true` and convert its failure
into the same explicit refusal vocabulary (`exit 3`, *"REFUSING TO GRADE — the contracted SDK could not
be installed"*). That is the **only** legitimate use of `continue-on-error` here: it does not mask a
golden result, it converts one failure mode into the gate's own refusal. And correct the report's §0,
which currently claims the refusal outcome unconditionally.

### FINDING 2 (LOW) — report §1.5 misstates the precondition step's position

It says the fast CI step runs *"before `pub get`, before any render"*. It runs **after** `flutter pub
get` — necessarily, since `dart run` needs resolved dependencies — and before any render. The
load-bearing claim holds; the wording does not.

### FINDING 3 (LOW) — report §6 mislabels a `git diff --stat` number

*"No job, step or gate removed. Net `+58`."* `git diff --stat`'s `58 +-` is **churn** (46 insertions +
12 deletions). The net is **+34**. The agent read the stat format as a delta. Nothing depends on it —
the substantive claim (no job/step/gate removed) is correct and I verified it by enumerating all 12
removed lines.

### FINDING 4 (LOW) — the `.fvmrc` blast radius is understated

The report says `.fvmrc` governs *"eight other packages"*. The workspace has **16** members, of which one
is the golden owner `apps/control_plane`, so it governs **15** others. The number is wrong — and it
wrong in the direction that *strengthens* the lane's own conclusion not to touch the file.

### FINDING 5 (LOW, informational) — the environment guarantee at the library boundary rests on `main()`

`GoldenCheckRequest.observed` is injectable, so `runGoldenDominationCheck` trusts its caller to pass a
real probe; a future refactor of `main()` could pass a synthetic environment. **Bounded in practice:** the
CI job's *first* step (`check_render_environment.dart`) calls `probeRenderEnvironment()` itself, has no
injection point and rejects all arguments, so the fast gate is immune even if `main()` were tampered
with. Recorded so it is not mistaken for a proof. (Same shape as the prior review's LOW-1 on
`assertComparatorIsReal` being a tripwire.)

### FINDING 6 (nit) — `_nthColouredRow` guarantees less than its comment claims

The helper guarantees only *"at least one non-black pixel on the row"*, but the assertions depend on the
whole row changing (`ratio == 1/844`). Today that holds — I measured rows 0/1/2 of
`defect_list_empty_mobile.png` at 390/390 non-black — so the invariant is carried by the assertion, which
is the property that matters: a future sparse row would fail loudly rather than pass quietly, just with a
confusing delta message instead of a clear fixture message.

---

## 10. OWED ITEM — the contract's placement. **Acceptable. Integrator action, not a blocker.**

**My judgement: the placement at `apps/control_plane/test/tools/golden_render_environment.json` is
acceptable, and this should be an integrator action rather than another correction cycle.**

Reasoning:

1. **The constraint was real, not a shortcut.** `apps/control_plane/test/goldens/**` is listed under
   *both* `READ_ONLY_PATHS` and `PROHIBITED_PATHS` in the dispatch. PROHIBITED wins, so the lane genuinely
   could not write there. It stated this plainly instead of quietly writing a `README.md` into a path it
   did not own. That is the correct reading.
2. **What the decision actually asked for is answered.** The question in `3e9dfb75` was *"which platform
   and Flutter version own the goldens, and where is that contract recorded?"* OPTION_C answered the first
   half ("macOS arm64 and Flutter 3.44.7") and the second half now has a real answer: a committed,
   machine-readable file at a fixed path.
3. **The contract is stronger where it is.** The reviewer's "next to the baselines" was a suggested
   placement *inside* a human-decision resolution, not the decision's own text. What the lane built is
   executable — the check reads it, `golden_render_environment_test.dart` pins its four axes and its
   ceiling, `check_render_environment.dart` quotes its path in every message, and it refuses on drift.
   `LEARNING_POLICY.md` prefers executable knowledge to prose. A human-readable pointer beside the
   baselines is *discoverability polish on top of an already-enforced contract*, not a missing
   governance act.
4. **Nothing is lost.** A reader who opens the goldens directory will not see the contract; a reader who
   runs the check — which is everyone who touches this gate — sees it printed on every run and named in
   every refusal.

**Integrator action (tracked, not gated):** add
`apps/control_plane/test/goldens/README.md` — or a comment in the nearest existing test file that renders
goldens — naming the four enforced axes (`macos` / `26` / `arm64` / `3.44.7`), stating that the OS patch
level is recorded but deliberately not enforced, and pointing at
`apps/control_plane/test/tools/golden_render_environment.json` and the Human Decision. That needs a path
this lane did not own, which is why it is correctly not this lane's job.

---

## 11. Constraints honoured

- **ZERO Docker/Compose commands** — none, not even `ps`/`logs`/`info`/`config`.
- **No production file edited.** The reviewed worktree is at `b7db6ef` and **pristine**, including
  untracked files, after `dart pub get`, `dart format`, `flutter analyze`, `flutter test`, and after two
  full `--update-goldens` render passes.
- **No mutation performed in the reviewed worktree.** All mutation testing ran in a scratch *copy* of the
  tree outside both the worktree and the repository, driven by Python edits confined to that copy. I
  verified the copy was genuinely independent (a marker written there did not appear in the reviewed
  worktree) before trusting any mutation result. The scratch copy has been deleted.
- **No `git worktree add`**, so no worktree metadata was registered. `git worktree list` is unchanged.
- **No Penpot.**
- No commit, no push, no merge, no touch of `main`.

---

## 12. What this correction got right

- It did not take the runner-images table on trust — and the table says what it claimed.
- It left `.fvmrc` alone when moving it was the one-line fix, and explained the blast radius.
- It made the environment a **checked precondition in two places** rather than a comment, and then made
  the *ordering* executable instead of asserting it.
- It rewrote the vacuous tests against a mutation it re-injected itself, and the old tests' failure to
  notice is now documented as the proof that the reviewer was right.
- It retracted a false claim with evidence instead of quietly restating it.
- It declined `continue-on-error` on the merits, against the prior reviewer's own suggestion, because the
  human decision post-dated that suggestion.
- It declined to write into a path it did not own and reported the omission as owed, rather than
  stretching its ownership.
- Its gates, provenance and prohibitions all survived independent re-measurement.

---

```
RESULT: APPROVE_CORRECTIONS

REVIEWED_HEAD:
  b7db6ef3fe3aadf2421a4f14087fb914badfb5f2  (branch fix/golden-domination-n2,
  worktree /private/tmp/shipit-fix-golden-domination, clean tree including untracked;
  two commits on top of f68a27a — 8557da1 precondition + job pinning,
  b7db6ef noise-floor tests that can fail)

FINDINGS_REVIEWED:
  BLOCKER-1  RESOLVED (independently verified end to end)
    - .github/workflows/ci.yaml golden-integrity: runs-on macos-14 -> macos-26,
      flutter-version-file .fvmrc -> flutter-version 3.44.7 (job-scoped). CONFIRMED at
      actions/runner-images: macos-26 = macOS 26 Arm64, GA, not deprecated. CONFIRMED in
      subosito/flutter-action action.yaml + setup.sh: filter_by_channel | filter_by_arch |
      filter_by_version = an EXACT 3.44.7 within stable, not the channel head, so the pin
      is real and cannot drift to latest.
    - .fvmrc UNCHANGED, verified three ways: empty diffs at f68a27a and a8a990b; blob
      457360f80661d694997014bf132873675dc1c88f identical at a8a990b / f68a27a / 8557da1 /
      b7db6ef / worktree; only commit ever touching it is 0d5d132, predating the lane.
    - Environment is a CHECKED PRECONDITION: enforces before any render in the workflow and
      inside runGoldenDominationCheck before measureNoiseFloor/gradeGoldens. Refusal is
      structural (output: [] by construction).
    - NO bypass: check_render_environment.dart rejects all arguments (verified: --force ->
      exit 2); the CLI flag set is exactly --baseline/--current/--repeat/--tolerance/--help;
      GoldenCheckRequest has no contract field and the contract loads from a fixed path;
      --tolerance must equal the comparator's declared value.
    - NO continue-on-error added anywhere (grep over .github/ -> none; none in the diff).
    - Outcome achieved = REFUSES TO GRADE. Reproduced: same 54-frame pipeline + a stale
      baseline, mismatched contract -> exit 3, stdout literally zero lines (no CURRENT(, no
      TOLERANCE-DOMINATED, no FAIL:, no PASS:); same corpus, correct contract -> exit 1,
      "FAIL: 1 of 54" naming defect_list_empty_mobile.png at 0.0851% / 280/329160 px /
      peak 234. Happy path -> exit 0, PASS: 54 of 54, noise floor 0.0000%.
    - Ordering is POLICED, not merely present. My own mutation deleting
      assertRenderEnvironment makes the suite fail with Actual: <1> — the false-assurance
      outcome.
  MEDIUM-1  RESOLVED — provenance measured, matches my independent measurement:
    1657082 = live ancestor (also on main); c4fa46e and 0353c32 = resolve as commits but are
    NOT ancestors and are contained by NO ref (unreachable, will be GC'd); c68016a and
    f68a27a live. Chain a8a990b -> c68016a -> f68a27a -> 8557da1 -> b7db6ef confirmed.
  MEDIUM-2  RESOLVED — noise-floor tests can now fail. Proven with THREE mutations, two mine:
    (A1, mine) measureNoiseFloor comparing current with itself -> 2 fail, while the OLD
    tests restored verbatim from f68a27a PASS against the same broken source (+3 All tests
    passed) — reproducing the reviewer's diagnosis and the agent's demonstration;
    (A2, mine, not reported by the agent) noiseFloorOf returning a mean + first filename ->
    3 of 5 fail. New tests use genuinely distinct asserted directories and synthesised
    frames (390x844, so 1 row = 1/844; I measured rows 0/1/2 at 390/390 non-black).
  MEDIUM-3  RESOLVED — D5 reclassified AUTOMATION_OPPORTUNITY -> ARCHITECTURE_DISCOVERY per
    LEARNING_POLICY.md, routed as the human decision it was, discharged by 3e9dfb75/OPTION_C.
  FALSE PERSISTENCE CLAIM  RESOLVED — retracted in report section 3 with the prior claim
    quoted verbatim; D2 recorded as report-only prose at c68016a versus enforced at b7db6ef.
    The retraction is demonstrated, not asserted: the old tests passed against a measurement I
    broke myself. The prior report was READ_ONLY and correctly left unedited for the Manager.

REGRESSIONS: NONE
  All behaviour changes are tightenings: environment refusal added (exit 3); noise-floor
  ceiling 0.005 -> 0.0 (else refuse); "machine too noisy" exit 2 -> 3 for clarity; main()
  split into a testable runGoldenDominationCheck with identical verdicts; flag set
  unchanged; grading logic (golden_domination.dart, png_pixel_diff.dart) UNTOUCHED by this
  correction. One named consequence, deliberate and documented: a slightly jittery macos-26
  image would now refuse rather than grade — which is the intended design and is pinned by a
  test.

BLOCKERS: NONE

NON_BLOCKING (all LOW or below; none gates merge):
  1. The decision's OTHER contingency — 3.44.7 unavailable on the runner — produces a RED
     BUILD at the flutter-action step, not a refusal, because the SDK must exist before the
     precondition can probe it. Not reachable today; always loud; never a false pass.
     Report section 0 claims the refusal outcome unconditionally and should be qualified.
     Optional remedy: id + continue-on-error on the install step only, converted into an
     explicit exit-3 refusal. That is the one legitimate use of continue-on-error here.
  2. Report 1.5 says the fast precondition step runs "before pub get"; it runs after
     (dart run needs resolved deps) and before any render. Load-bearing claim holds.
  3. Report 6 says ci.yaml is "Net +58"; git's stat shows CHURN 58 (46+/12-). Net is +34.
     The substantive claim (no job/step/gate removed) is correct — all 12 removed lines
     enumerated and accounted for.
  4. Report says .fvmrc governs "eight other packages"; the workspace has 16 members, so it
     governs 15 others. Understated — which strengthens the lane's own conclusion.
  5. GoldenCheckRequest.observed is injectable, so the library-level guarantee rests on main()
     choosing probeRenderEnvironment(). Bounded: the CI job's first step has no injection
     point at all. Recorded so it is not mistaken for a proof.
  6. (nit) _nthColouredRow guarantees only ">=1 non-black pixel on the row" while the
     assertions need the whole row; the invariant is carried by the assertion (self-detecting),
     so a future sparse row fails loudly rather than passing quietly.

OWED, NOT A BLOCKER:
  The human-readable render-environment contract beside
  apps/control_plane/test/goldens/**. The lane could NOT write there — that path is
  PROHIBITED (PROHIBITED beats READ_ONLY), and it reported the omission instead of
  stretching its ownership. The placement at
  apps/control_plane/test/tools/golden_render_environment.json is ACCEPTABLE: the decision's
  question ("which platform and Flutter version own the goldens, and where is that contract
  recorded?") is answered by a committed, machine-readable, fixed-path, test-pinned file that
  the check reads and every refusal message quotes — executable knowledge over prose, which
  LEARNING_POLICY.md prefers. The reviewer's "next to the baselines" was a suggested placement
  inside the resolution, not the decision's text.
  INTEGRATOR ACTION (tracked, not gated): add
  apps/control_plane/test/goldens/README.md naming the four enforced axes (macos / 26 / arm64 /
  3.44.7), noting the OS patch level is recorded but deliberately not enforced, and pointing
  at the contract file and Human Decision 3e9dfb75.

GATES (re-run by me at b7db6ef, verbatim):
  dart pub get                            -> "Got dependencies!"                          exit=0
  dart format --output=none --set-exit-if-changed .
                                         -> "Formatted 638 files (0 changed) in 6.20s"   exit=0
  cd apps/control_plane && flutter analyze
                                         -> "No issues found! (ran in 27.7s)"            exit=0
  cd apps/control_plane && flutter test   -> "00:43 +246: All tests passed!"              exit=0
  Test arithmetic verified by my own counts, closes exactly:
    noise-floor 2->5 (+3) + runGoldenDominationCheck (+7) + golden_render_environment_test.dart
    (+29) = +39; 207 + 39 = 246.
  Runtime, all re-executed by me on a real two-render pipeline:
    exit 0  precondition OK on macos 26.6.2 / arm64 / 3.44.7
    exit 2  --force rejected by design
    exit 3  contract -> macOS 14 / x64 / 3.44.0: refuses, names all three axes
    exit 0  correct env, corpus current: CURRENT (54), PASS: 54 of 54, floor 0.0000%
    exit 1  correct env + stale baseline: FAIL: 1 of 54, names the file
    exit 3  mismatched env + SAME stale baseline: ZERO stdout lines, no verdict of any kind
    fails   assertRenderEnvironment deleted from the check (Actual: <1> — false assurance)
    Two real render passes reproduced all 54 committed baselines byte-for-byte and agreed
    with each other (0/54, 0/54, 0/54 differing), reconfirming at b7db6ef that the 40
    regenerated baselines are still current and that maxNoiseFloorRatio 0.0 is satisfiable.

PROHIBITIONS: ALL HELD
  golden_tolerance.dart blob 7cd735ca360f7399e28c9b4b10cc9b0a2c07300d identical at a8a990b /
  f68a27a / 8557da1 / b7db6ef / worktree; threshold 0.005 still at line 43; ONE commit ever.
  goldens/**: diff f68a27a..HEAD empty AND all 54 worktree blobs hashed equal to f68a27a
  (checked=54 differing=0). Nothing leaked — the agent rendered in a detached worktree
  (since removed, confirmed absent from git worktree list) and I rendered in a scratch copy
  outside the repository; the reviewed worktree is pristine including untracked files after
  every gate and both render passes.
  No lib/** change. No pre-existing test .dart weakened: the only file touched outside new
  files is golden_domination_test.dart, whose entire 12-line removal is the two vacuous
  noise-floor tests; no @Ignore/@Skip/skip:/tags:/only-tags/exclude-tags/|| true on any added
  line. ci.yaml: 12 removed lines, all enumerated, no job/step/gate removed. No Docker/Compose
  command of any kind, by this lane or by me.

READY_FOR_MERGE: YES

NEXT ACTION: INTEGRATE (with the two items above tracked, not gated)
  - Integrate 8557da1 + b7db6ef together with c68016a; BLOCKER-1 is closed, so the earlier
    split-the-commits rationale no longer applies and the decision directs integrating both.
  - Note for the integrator: main has advanced to 5cb81fd since this branch's base a8a990b
    (the agent's N4). Strategy is the integrator's call; I did not act on it.
  - Track non-blocking Finding 1 (SDK-unavailable contingency) and the owed goldens/ README
    as follow-ups.
  - Carry the prior review's LOW-3 forward: the job intentionally runs the full suite three
    times, which is what closes "a golden added later escapes the check" but makes the whole
    suite a required macOS check.
```
