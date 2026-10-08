# Independent Review — fix-golden-domination-n2

**Lane under review:** `fix/golden-domination-n2`
**Worktree:** `/private/tmp/shipit-fix-golden-domination`
**Authority:** Human Decision `cff0e948-80a5-48ab-9a7b-f2a99be6f870` — `RESOLVED` / `OPTION_A`
**Reviewer lane:** `engineering-reviewer` (independent, read-only)

---

## 0. Verdict summary

The engineering is sound and I reproduced every load-bearing claim. **All three refuted dispatch
premises are correct** — independently confirmed, not taken on trust. Every central prohibition
holds. All four gates pass verbatim.

The blocker is confined to one thing: the new `golden-integrity` **job is wired to a render
environment that is not the environment the baselines were produced in**, on a runner image GitHub
has marked deprecated, and the underlying contract that would fix it is governance the lane
explicitly declined to decide. That is a red required gate landing unowned.

---

## 1. Provenance

```
$ git rev-parse HEAD
f68a27ae561b9b06863f9b616878e9789026c533
$ git log --oneline -3
f68a27a Regenerate the 40 stale golden baselines
c68016a Fail the build when a golden passes only because the tolerance hid it
a8a990b decisions: resolve all three (1ed57d5d OPTION_A, cff0e948 OPTION_A, 6d2bfffe OPTION_B)
$ git status --porcelain
(empty — pristine)
```

Two commits, exactly as described. Commit `c68016a` = 5 files, +1308 lines (4 `.dart` + `ci.yaml`),
purely additive. Commit `f68a27a` = 40 PNGs only, nothing else.

### 1.1 The rebase changed no content — proven

The report was written against pre-rebase SHAs (`BASE 1657082`, `HEAD c4fa46e`). Both commits were
rebuilt onto `a8a990b`. The reflog confirms the Manager performed it:

```
f68a27a HEAD@{0}: rebase (finish): returning to refs/heads/fix/golden-domination-n2
f68a27a HEAD@{1}: rebase (pick): Regenerate the 40 stale golden baselines
c68016a HEAD@{2}: rebase (pick): Fail the build when a golden passes only because the tolerance hid it
a8a990b HEAD@{3}: rebase (start): checkout a8a990b
c4fa46e HEAD@{4}: commit: Regenerate the 40 stale golden baselines
0353c32 HEAD@{5}: commit: Fail the build when a golden passes only because the tolerance hid it
```

I compared the old and new HEADs blob-by-blob. **All 45 changed files are byte-identical:**

| Check | Result |
|---|---|
| 5 text files, `c4fa46e` vs `f68a27a` | **IDENTICAL** (5/5) |
| 40 PNGs, `c4fa46e` vs `f68a27a` | **IDENTICAL** (40/40) |
| `git diff c4fa46e f68a27a` | only the 4 decision-resolution files inherited from the new base |

The rebase is content-neutral. **REVIEWED_HEAD is valid.**

---

## 2. Central prohibitions — all verified

### 2.1 `golden_tolerance.dart` unchanged — blob hash, every cited revision

```
43ede2e   7cd735ca360f7399e28c9b4b10cc9b0a2c07300d   43:void useTolerantGoldens({double threshold = 0.005}) {
878c332   7cd735ca360f7399e28c9b4b10cc9b0a2c07300d   43:void useTolerantGoldens({double threshold = 0.005}) {
a7b58b1   7cd735ca360f7399e28c9b4b10cc9b0a2c07300d   43:void useTolerantGoldens({double threshold = 0.005}) {
1657082   7cd735ca360f7399e28c9b4b10cc9b0a2c07300d
a8a990b   7cd735ca360f7399e28c9b4b10cc9b0a2c07300d
f68a27a   7cd735ca360f7399e28c9b4b10cc9b0a2c07300d   43:void useTolerantGoldens({double threshold = 0.005}) {
worktree  7cd735ca360f7399e28c9b4b10cc9b0a2c07300d
```

`git log --all -- <path>` shows **one** commit in its entire history (`4e1fdb9`, long predating this
lane). This lane did not touch it. Threshold still `0.005` at **line 43**, as specified.

### 2.2 No production source change

```
$ git diff --name-only a8a990b HEAD -- apps/control_plane/lib/
(empty)
```

Full changed set is exactly: `.github/workflows/ci.yaml`, 40 files under
`apps/control_plane/test/goldens/`, 4 new files under `apps/control_plane/test/tools/`.
`apps/server/**`, `packages/**`, `docker/**`, `docs/adr/**`, `.decisions/**`, `.agents/**`,
`.claude/**`, `.junie/**`, `.opencode/**` — all untouched. Also untouched: `pubspec.yaml`,
`melos.yaml`, `.fvmrc`.

### 2.3 No test weakened, skipped, filtered or deleted

The strongest possible proof: **not one pre-existing test file was modified.** The diff adds only
four *new* files. Nothing could be skipped because nothing existing was edited.

- No `@Ignore`, `@Skip`, `skip:`, `tags:`, `only-tags`, `exclude-tags` anywhere in the four new files.
- `ci.yaml` diff is **purely additive** — zero removed lines, so no pre-existing job was weakened.
- No `continue-on-error`, no `|| true`, no `skip` introduced.
- Test count `+190 → +207` = exactly **+17**, matching the 17 new tests in
  `golden_domination_test.dart` counted by group (3+2+2+4+4+2). Arithmetic closes exactly, so
  nothing was deleted.

### 2.4 The comparator still performs a real pixel comparison

`golden_tolerance.dart:21-35` — untouched, and still real:

```dart
final result = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
if (result.passed || result.diffPercent <= _threshold) { ... return true; }
```

The domination check is a **classification layer on top**, exactly as required. It never writes to
the baseline directory (`golden_domination.dart:39`, and the CLI grades a `$RUNNER_TEMP` snapshot
taken before any render). The CI job also runs the unmodified suite *first*, so a genuine visual
regression still fails on pixels alone.

---

## 3. The three refuted premises — independently confirmed

### 3.1 "40 stale, not 44" — **CONFIRMED**

I extracted the whole `a8a990b` corpus and graded it against fresh renders of `HEAD` source (lib is
unchanged, so `HEAD` renders are a valid oracle for `BASE`):

```
BASE corpus: 54 png
TOLERANCE-DOMINATED (40)
CURRENT (14)
FAIL: 40 of 54 baselines are not current. The tolerance did not cause this; it hid it.
```

The 14 already-current are exactly those the report names:
`defect_list_loading_mobile{,_dark}`, `mobile_{all_work,decision_detail,needs_you,overview,run_detail}_{light,dark}`,
`product_detail_mobile_back_link{,_dark}`.

The implementer's reasoning is also right on the merits: absence-of-badge is not a staleness test.
A byte-identical baseline is current by definition regardless of what it depicts.

### 3.2 "26 badge-bearing, not 54" — **CONFIRMED, and the arithmetic closes**

I measured independently rather than taking the method on trust.

Frame geometry across all 54: **26 @ 1280×900** (desktop), **26 @ 390×844**, **2 @ 390×1080**
(`create_defect_mobile{,_dark}`).

Independent exact-colour count of `#F7A42C` on the 390-wide frames:

- 24 of the 26 @ 390×844 carry **171 px** each — exactly the figure the report predicted for the disc.
- `defect_list_loading_mobile{,_dark}` carry 0 — loading state, no badge in baseline *or* render.
- Both @ 390×1080 `create_defect_mobile` frames carry **171 px**.

→ **26 badge-bearing = 24 + 2.** The report's "26 of 54" is correct, and it falls out of the frame
geometry, not from a tuned detector.

Desktop rail confirmed as a *different widget*: in `all_work_light.png` the `#A35F00` population in
the rail (`x < 200`) is **8 px** — a glyph, not an 18×18 disc (324 px). In `all_work_dark.png` the
rail count is `#F7A42C` at 8 px. This validates D3: the badge is two widgets and the dispatch's
"has the badge" proxy was measuring the wrong thing.

**The dispatch's "196 and 200 orange px" does not reproduce under any method I could construct** —
I get 171 for the disc, matching the implementer. Declining to chase an unreproducible number and
saying so is the correct call, and it is the dispatch figure, not the report, that is wrong.

### 3.3 "The golden suite was never run by any CI job" — **CONFIRMED. This is the real finding.**

I enumerated every `run:`/`uses:` in all five workflows **at `a8a990b`, before the lane**:

| Workflow @ BASE | What it runs | Golden? |
|---|---|---|
| `ci.yaml` | `melos run analyze`, `melos run format`, `verify:schema-deviations`, `melos run test --no-select` | **no** — the melos `test` script explicitly lists `ignore: [control_plane, control_plane_server]` |
| `integration.yaml` | `apps/server` `dart test test/integration/` (Postgres) | no |
| `macos-workers.yaml` | `flutter test integration_test/ios_test.dart` in `packages/control_plane_client` | no — that package has **no `test/` directory and no `goldens/`** at all |
| `infrastructure.yaml` | `tofu fmt -check` | no |
| `release.yaml` | `docker build` ×3 | no |

**No workflow rendered a single golden. The claim is true.**

One nuance the implementer did not mention, which *softens* the novelty but not the substance:
`pubspec.yaml:87-98` **already documents this gap in the repo** — the `test:flutter` script's
comment reads "it left it unreachable from melos entirely — a 150+ test suite that only ran if
someone remembered to `cd apps/control_plane && flutter test`." So the gap was known and written
down; what was missing was anyone acting on it. D1 is a correct finding, but it is a *re-activation*
of a documented pre-existing gap, not a discovery of an unknown one. The report's framing ("nothing
was checking", presented as a surprise) slightly overstates it. The consequence is identical, and
fixing it is squarely this lane's job.

Also worth noting for the record: `melos run test:flutter` exists but is invoked by **no** workflow.

---

## 4. Gates — verbatim, re-run by me

```
$ dart pub get
Got dependencies!
52 packages have newer versions incompatible with dependency constraints.
exit=0

$ dart format --output=none --set-exit-if-changed .
Formatted 635 files (0 changed) in 5.66 seconds.
exit=0

$ cd apps/control_plane && flutter analyze
Analyzing control_plane...
No issues found! (ran in 22.4s)
exit=0

$ cd apps/control_plane && flutter test
00:40 +207: All tests passed!
exit=0
```

`635 files (0 changed)` — the dispatch expected `631`. The implementer's explanation is correct and I
confirm it: the count rose by exactly the four Dart files added, and `(0 changed)` is the assertion
that matters. **Not a finding.**

---

## 5. The check actually fires — reproduced independently

I did not accept the implementer's proof. I re-derived it from scratch.

### 5.1 Two independent renders, and the noise floor

```
=== RENDER PASS 1 ===  00:41 +207: All tests passed!
=== RENDER PASS 2 ===  00:44 +207: All tests passed!
$ git status --porcelain
(empty — regeneration reproduced the committed blobs exactly)

baseline-vs-pass1 differing: 0 / 54
pass1-vs-pass2   differing: 0 / 54   <- the noise floor
baseline-vs-pass2 differing: 0 / 54
```

Both independent renders are byte-identical to the committed baselines and to each other. The noise
floor on this platform is exactly **0.0000%**. D2's *measurement* is correct.

### 5.2 The check on the committed corpus — green

```
PASS: 54 of 54 baselines match the current render within this machine's noise floor (0.0000%).
exit=0
```

### 5.3 Revert one golden to its BASE blob — the defect reproduces

```
$ git show a8a990b:.../defect_list_empty_mobile.png > test/goldens/defect_list_empty_mobile.png
worktree blob now: a8cbe9938ec6ee97e7509163af84a85621ac4d0c   (== BASE)
HEAD blob is:      d13eef6ff7e9383f698e19277416bce8a695dc10
```

**A. Suite through the unchanged tolerant comparator:**

```
00:44 +207: All tests passed!
A_exit=0
```

A stale baseline is present in the tree and the suite is **green**. The defect, reproduced on demand.

**B. Domination check, same tree:**

```
TOLERANCE-DOMINATED (1)
  defect_list_empty_mobile.png                         0.0851%  280/329160 px, peak channel delta 234
CURRENT (53)
FAIL: 1 of 54 baselines are not current. The tolerance did not cause this; it hid it.
B_exit=1
```

Byte-for-byte identical to the report's §4B, including the delta figures. It names the file, reports
the measured delta, and explains the fix **and** warns against widening the tolerance.

### 5.4 Restore — green again

```
$ git checkout -- test/goldens/defect_list_empty_mobile.png
worktree == HEAD blob d13eef6ff7e9383f698e19277416bce8a695dc10
PASS: 54 of 54 baselines match the current render within this machine's noise floor (0.0000%).
C_exit=0
$ git status --porcelain
(empty — pristine)
```

**A check never observed failing is not a check. This one is.** Verified end-to-end, and the tree is
back to pristine at `f68a27a`.

### 5.5 The mid-lane CI-input correction

The implementer corrected `fvm-version-file:` → `flutter-version-file:` mid-lane and rebuilt both
commits. Verified two ways:

```
$ grep -rn 'fvm-version-file' .github/
(empty — the bad key survives nowhere in the repo)
$ grep -rn 'flutter-version-file' .github/
.github/workflows/ci.yaml:116:          flutter-version-file: .fvmrc
```

I checked the upstream `subosito/flutter-action` README directly. `flutter-version-file` **is** the
correct input name, it explicitly supports `.fvmrc`, and it auto-installs `yq`. **The correction was
right and is clean.** No finding.

---

## 6. Findings

### BLOCKER-1 — The `golden-integrity` job is pinned to a render environment that does not match the baselines, on a deprecated image

**Severity: HIGH. Blocks merge of `c68016a`.**

The baselines were rendered on:

| Axis | Render environment (verified) | What the job will use |
|---|---|---|
| OS | **macOS 26.6.2** (`sw_vers`) | **macOS 14** (`runs-on: macos-14`) |
| Arch | **arm64** (`uname -m`) | see note |
| Flutter | **3.44.7** (`flutter --version`) | **3.44.0** (`.fvmrc`) |

I verified the image table at `actions/runner-images`. Two facts:

1. `macOS 14` and `macOS 14 Arm64` **both carry the `deprecated` badge** (announcement
   `actions/runner-images#13518`). Per GitHub's own policy a deprecated image goes through brownouts
   and is eventually removed. A brand-new required gate is being pinned to it.
2. The `macos-14` label maps to the **arm64** image in the current table. (Historically `macos-14`
   was the Intel x64 standard runner, so the arch the job actually gets is itself not stable across
   the label's history. Either way it is not pinned.)

**The report identified only the Flutter axis** (§9) and explicitly declined to act on it as
governance (D5) — which is defensible. But it presented `runs-on: macOS` as though "macOS-ness"
were the render-platform contract. It is not. The contract that matters is *macOS 26.6.2 + arm64 +
Flutter 3.44.7*, and the job matches **none** of the three. A three-major-version OS gap (26 → 14)
changes the CoreText stack and glyph rasterisation, which is a much larger perturbation than the
patch-level Flutter delta the report worried about.

**Consequence, concretely.** Step 3 (`flutter test`, the *unmodified* comparator at tolerance
0.005) is the first thing that can fail. It will very likely fail on the runner, and the job goes
red **before the domination check is ever reached**. If it does pass, the check then grades the
corpus and emits a large `TOLERANCE-DOMINATED`/`DIVERGED` block → exit 1. Both roads end red.

**And the check's own safety guard does not cover this case.** `check_golden_domination.dart:104`
refuses to grade only when `noiseFloor >= tolerance`. On the CI runner the two renders will agree
perfectly *with each other* (same machine, same Flutter), so `noiseFloor ≈ 0`, the guard passes, and
the check then reports **54 confident verdicts that describe the runner rather than the corpus** —
verbatim the outcome the guard's own doc comment says it exists to prevent ("every verdict would
describe the runner rather than the corpus"). The guard covers *runner instability*. It does not
cover *runner-vs-baseline-platform systematic difference*, which is the most likely failure mode.

**Why this is a blocker and not "a documented calibration step."** A calibration step needs an
owned, decided contract and a non-blocking window. Here the contract is explicitly **undecided**
(D5 defers it to the Manager as "governance, not mine"), the image is deprecated, and the job would
land **blocking**. The result is a required gate that is predicted to go red, whose fix nobody owns,
landing on hardware that is scheduled for retirement. Note the repo invariant this collides with:
*"Required deterministic validation must pass before success is claimed."* A gate nobody has ever
seen pass, landing red, is the inverse.

**Resolution — human decides the contract, then it is mechanical:**

- **Human:** decide and record the render-environment contract — which platform + Flutter version
  owns `apps/control_plane/test/goldens/**`, recorded *next to* the baselines (this is D5, correctly
  deferred). `LEARNING_POLICY.md` §Classification categories classifies a finding of this kind as
  `ARCHITECTURE_DISCOVERY`, which "may require an ADR and, if consequential, a human decision." It is
  consequential.
- **Then choose one:**
  - **(a)** Pin the job to that exact environment (e.g. `runs-on: macos-26`, and the exact Flutter
    version), leaving the baselines untouched; or
  - **(b)** Regenerate all 54 baselines on the *declared* `.fvmrc` pin and the pinned runner, so the
    repository's own SDK owns them and the existing `test:flutter` script stays truthful.
  - **(a) vs (b) is the governance choice, not mine or the implementer's.**
- **Either way, land non-blocking first:** add `continue-on-error: true` (or make it
  `workflow_dispatch`-only) for one calibration run, and drop it once the job has been **observed
  green**.
- **Close the guard gap:** if `noiseFloor <= tolerance` but a large fraction of the corpus grades
  non-`CURRENT`, emit a platform-mismatch `ENVIRONMENT` diagnosis instead of 54 confident verdicts.

### MEDIUM-1 — The report's own provenance fields point at dead SHAs

`BASE_SHA: 1657082feb…`, `HEAD_SHA: c4fa46ec22…`, `COMMITS: 0353c32 → c4fa46e`. None of those are on
the branch any more. Provenance is a core framework invariant, and the durable record for a lane
that writes CI gates currently names revisions a reader cannot resolve.

**This is the Manager's rebase, not the implementer's error** — the implementer reported honestly
against the SHAs it was given, and §1.1 proves the content is unchanged. Actionable: append a
provenance note recording the rebase onto `a8a990b` and that content was verified identical
(`c68016a` / `f68a27a`). Cheap, and it preserves the audit trail.

### MEDIUM-2 — D2 is reported as persisted executable knowledge; it is not

`report.md` §10 D2 and `KNOWLEDGE_PERSISTED` both claim the noise-floor finding is executable
knowledge — "`golden_domination_test.dart` asserts the floor is 0 over the whole corpus, so a
platform where it stops being 0 fails the suite."

**No such assertion exists.** `golden_domination_test.dart:277-294` passes the **same directory**
as `baseline`, `current` *and* `repeat`:

```dart
final noise = measureNoiseFloor(
  baseline: Directory(goldens.path),
  current:  Directory(goldens.path),
  repeat:   Directory(goldens.path),
);
expect(noiseFloorOf(noise).ratio, 0);
```

`measureNoiseFloor` then calls `compareFrames(path, path)` on each file, which is trivially
byte-identical. **These two tests cannot fail regardless of render determinism** — they are
tautological. The only real content is `hasLength(54)`, which does confirm all 54 decode.

The *finding* is true — I measured the floor at 0/54 with two genuine renders and `cmp` — but it is
**report-only prose, not executable knowledge**, and must be recorded as such.

Actionable: either drop the claim from `KNOWLEDGE_PERSISTED`, or reclassify D2 as
`QA_DISCOVERY`-grade prose. Do **not** add a double-render assertion to `flutter test` to satisfy the
claim — it would triple an already 40-second suite.

### MEDIUM-3 — D5 is under-classified

D5 (the render-environment contract is pinned in CI but recorded nowhere) is filed as
`AUTOMATION_OPPORTUNITY` and "flagged to the Manager." Per `LEARNING_POLICY.md`, a finding that
affects architecture decisions and "may require an ADR and, if consequential, a human decision" is
`ARCHITECTURE_DISCOVERY`. Deciding what owns the goldens is exactly that. The filing is what let the
lane treat a governance question as an out-of-scope note — and it is the same question that BLOCKER-1
turns on. Reclassify and route it as the decision it is.

### LOW-1 — `assertComparatorIsReal()` is a substring check

`golden_domination.dart:136` greps for `GoldenFileComparator.compareLists`. A comparator that *calls*
it and then discards the result would pass the guard. It does catch the stated threat (a comparator
that never compares), and the negative test at `:33-44` covers that case. It is a tripwire, not a
proof — acceptable, worth knowing it is not the latter.

### LOW-2 — `flutter pub get` at repo root is sound but unexercised

The root `pubspec.yaml` declares a pub `workspace:` that **does** include `apps/control_plane`, so
root-level resolution covers the Flutter SDK dependencies, and I confirmed locally that
`flutter analyze` from `apps/control_plane` resolves against the root. Sound. Cosmetic note:
`pubspec.lock` is tracked, so a resolution change would dirty the tree without failing the job.

### LOW-3 — The job triples the full control_plane suite

`flutter test` runs the whole 207-test suite three times (verify + 2 renders), not just the golden
subset. That is *correct* — it is what closes the gap where a golden file added later escapes the
check — but it makes the entire previously-unrun suite a required macOS check and adds ~3 full-suite
runs to every CI run. Worth knowing before the job goes required.

### LOW-4 — Test quality note

Coverage is genuinely good for a grading layer: negative cases are present and real (fake comparator
rejected at `:33-44`, undecodable file named at `:66-77`, orphan `:233-253`, missing baseline
`:255-273`), the comparator is measured rather than asserted (`:89-114`), and all four classification
boundaries are pinned including the measured 0.3172% Product Detail drift. Only the noise-floor
group is vacuous (MEDIUM-2).

---

## 7. What I confirmed as good

Stated plainly, because it is most of the work:

- The comparator was **not** touched, at any revision — blob-identical across six SHAs including the
  three quoted from the decision, with a single commit in its whole history.
- `apps/control_plane/lib/**` untouched; the copy is correct and the goldens were brought to the
  source, not the reverse.
- **Zero existing test files modified.** Nothing weakened, skipped, `@Ignore`d, filtered or deleted.
  `+190 → +207` closes arithmetically at exactly +17.
- The comparator still does a real `GoldenFileComparator.compareLists` pixel comparison; the new
  check is a classification layer on top that never writes to the baseline directory.
- **The check fires** — `exit 1`, naming `defect_list_empty_mobile.png` at `0.0851%`,
  `280/329160 px`, peak channel delta 234 — while `flutter test` on the same tree exits **0**. The
  defect and its detection, demonstrated side by side.
- All 40 regenerated baselines are **byte-identical to a fresh render**, verified by two independent
  render passes and `cmp` (0/54 differing), with the working tree clean afterwards.
- The mid-lane CI-input correction (`flutter-version-file`, not `fvm-version-file`) was right, and
  no trace of the bad key survives.
- **All three refuted dispatch premises are correct.** The implementer was right to push back on all
  three, right to refuse to chase the unreproducible "196/200 px" figure, and right to note that its
  own authority read `PENDING` at the dispatched base purely because the resolution landed 5 minutes
  later (D4 — I confirmed the dispatch base `1657082` predates `a8a990b` and the decision file at
  `a8a990b` reads `RESOLVED` / `OPTION_A` / `2026-10-08T04:26:00Z`). Pushing back on a dispatch is
  the right instinct and it was correct three times out of three.

---

## 8. Constraints honoured

- **ZERO Docker/Compose commands.** No `ps`, `logs`, `info`, `config`, `down`, `up`. None. Compose
  files were read as text only, and not needed.
- **No production file edited.** The only file I wrote is this review report.
- No commit, no push, no merge, no touch of `main`.
- The one working-tree mutation required by the brief — reverting one golden to its BASE blob to
  observe the check fail — was restored with `git checkout`, and I verified the worktree is pristine
  and back at `f68a27a`.
- Scratch captures kept in `/tmp/rev_gi`, outside both the worktree and the repository.

---

## 9. Recommended next action

1. **Hold `c68016a`. Escalate D5 as a Human Decision** — what platform and Flutter version own
   `apps/control_plane/test/goldens/**`, recorded next to the baselines — then pin the job to it (or
   regenerate on the declared pin) and land the job non-blocking until observed green.
2. **`f68a27a` is independently clean and approvable.** I verified all 40 baselines are
   byte-identical to a fresh render of current source. It carries no wiring risk and no governance
   dependency. It can merge on its own now; it is genuinely separable, exactly as the implementer
   said. Do not let BLOCKER-1 hold the binaries hostage.
3. Fix MEDIUM-1/2/3 — the provenance note, the D2 persistence claim, and the D5 classification.
4. Do **not** touch `golden_tolerance.dart`. It is correct, it is load-bearing for cross-platform
   safety, and it is not the defect.

---

RESULT: DO_NOT_MERGE

REVIEWED_HEAD: f68a27ae561b9b06863f9b616878e9789026c533 (branch `fix/golden-domination-n2`, worktree
`/private/tmp/shipit-fix-golden-domination`, clean tree; two commits `c68016a` → `f68a27a` on base
`a8a990b`; diff content proven byte-identical to pre-rebase `c4fa46e`)

BLOCKERS:
1. (HIGH) `.github/workflows/ci.yaml` `golden-integrity` pins `runs-on: macos-14` + `.fvmrc`
   Flutter 3.44.0, while the 54 baselines were rendered on macOS 26.6.2 / arm64 / Flutter 3.44.7 —
   three axes unmatched, on a runner image GitHub marks **deprecated**. The job is predicted to go
   red before the domination check is reached, and its `noiseFloor >= tolerance` guard does not
   cover the runner-vs-baseline-platform case it exists to catch. Shipping an unowned red required
   gate is not a documented calibration step: the governing contract (D5) is explicitly undecided.
   Fix: human decides the render-environment contract (record it beside the baselines), pin the job
   to it or regenerate on the declared pin, and land the job non-blocking (`continue-on-error`) until
   one observed-green run.

HIGH: (none beyond the above)

MEDIUM:
1. Report provenance fields name dead SHAs (`BASE 1657082…`, `HEAD c4fa46e…`, commits `0353c32` →
   `c4fa46e`) after the Manager's rebase. Content verified identical, but the durable record for a
   CI-gate lane must resolve. Append a provenance note naming `a8a990b` / `c68016a` / `f68a27a`.
2. D2 is claimed as persisted executable knowledge; it is not.
   `golden_domination_test.dart:277-294` passes the same directory as `baseline`/`current`/`repeat`,
   so `compareFrames(path, path)` is tautologically byte-identical and the two tests can never fail.
   The finding itself is true (measured 0/54 by two real renders + `cmp`); reclassify it as prose
   knowledge. Do not add a double-render assertion to `flutter test` to satisfy the claim.
3. D5 is filed as `AUTOMATION_OPPORTUNITY` and merely flagged, but per `LEARNING_POLICY.md` a
   finding that "may require an ADR and, if consequential, a human decision" is
   `ARCHITECTURE_DISCOVERY`. That misfiling is what let BLOCKER-1's governing question go undecided.
   Reclassify and route as the decision it is.

LOW:
1. `assertComparatorIsReal()` (`golden_domination.dart:136`) is a substring check for
   `GoldenFileComparator.compareLists`; a comparator that calls it and discards the result would
   pass. Adequate tripwire for the stated threat, not a proof.
2. `flutter pub get` at repo root relies on the pub `workspace:` including `apps/control_plane` (it
   does). Sound but unexercised; `pubspec.lock` is tracked, so a resolution change dirties the tree
   without failing the job.
3. The job runs the full 207-test suite three times rather than a golden subset — correct, and what
   closes the "new golden escapes the check" hole, but it makes the whole suite a required macOS
   check and adds ~3 full-suite runs per CI run.
4. D3's two-widget finding (mobile 18×18 `#F7A42C` disc vs desktop rail `#A35F00`/`#F7A42C` text
   glyph, measured 171 px vs 8 px) confirms the dispatch's "has the badge" proxy was measuring the
   wrong thing. No action; recorded so it is not re-litigated.

CORRECTION_REQUIRED: YES

HUMAN_DECISION_REQUIRED: YES
   — One question, and BLOCKER-1 cannot be closed without it: **which platform and Flutter version
   own `apps/control_plane/test/goldens/**`, and where is that contract recorded?** The implementer
   correctly declined to decide it (D5) and classified it too low; it is an
   `ARCHITECTURE_DISCOVERY` per `LEARNING_POLICY.md`, it affects every future visual change in this
   repository, and choosing between "pin the job to the render environment" and "regenerate on the
   declared `.fvmrc` pin" is an architecture/governance call reserved to the human. Everything else in
   this report is mechanical and belongs in a correction lane.

SAFE_PARALLEL_WORK:
- Merging `f68a27a` (the 40 regenerated baselines) independently — verified byte-identical to a fresh
  render, no wiring risk, no governance dependency.
- Any lane owning `docs/**`, `.decisions/**`, `LANES.md`, `WORK_STATE.md`.
- `design-qa-startup-restructure` on `docker/**` and its own design artifacts — no path overlap with
  `apps/control_plane/test/**` or `.github/workflows/ci.yaml`.
- Read-only work anywhere in the repository.

PROHIBITED_PARALLEL_WORK:
- Any writer touching `.github/workflows/ci.yaml` until the Human Decision on the render-environment
  contract is resolved — this is a gate every future build depends on.
- Any writer touching `apps/control_plane/test/goldens/**` or `apps/control_plane/test/tools/**` —
  would invalidate the provenance verified in §1.1 and the byte-identity evidence in §5.
- Any change to `apps/control_plane/test/helpers/golden_tolerance.dart` — blob
  `7cd735ca360f7399e28c9b4b10cc9b0a2c07300d`, threshold `0.005` at line 43, identical across
  `43ede2e`, `878c332`, `a7b58b1`, `1657082`, `a8a990b` and `f68a27a`. The tolerance is not the
  defect; widening or bypassing it to force a green is a task failure.
- Any change to `apps/control_plane/lib/**` that would invalidate these baselines — they were
  regenerated from current source, so a lib change makes them stale again.
