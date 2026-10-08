# Report — fix-golden-domination-n2

**Authority:** Human Decision `cff0e948-80a5-48ab-9a7b-f2a99be6f870`, `RESOLVED` /
`OPTION_A` ("Add the tolerance-domination check + regenerate all 44"), decided 2026-10-08T04:26:00Z
through the structured question UI. I read it at `main` (`a8a990b`) rather than at this branch's
`BASE_SHA`, where it still reads `PENDING` — see D4.

---

## Headline

Two of the dispatch's premises did not survive measurement, and both are corrections the
independent reviewer needs:

| Dispatch said | Measured | Evidence |
|---|---|---|
| 44 goldens are stale | **40 are stale.** Four of the 44 (`product_detail_mobile_back_link` ×2, `defect_list_loading_mobile` ×2) are byte-identical to the current render | two independent render passes byte-identical across all 54; §4 |
| after regeneration all 54 should carry the Needs-you badge | **26 of 54.** 28 of the 54 render no mobile nav bar at all and therefore cannot carry the 18×18 badge — 26 desktop frames (the `Sidebar` rail renders the count as text in `palette.attention`, not a disc) and 2 `defect_list_loading_mobile` frames | §1 |
| the golden suite is under a threshold that hides it | **the golden suite was not running in CI at all** | §3 — this is the more serious finding |

The decision's own scope discipline was followed: the comparator was not touched, no production
source was touched, no test was weakened, and zero Docker commands were issued.

---

## 1. The badge sweep after regeneration

**Method, stated so it can be checked or rejected.** The mobile nav badge is an 18×18 solid disc
of `palette.attentionTick` (`#F7A42C`, `design_tokens.dart:106,127` — identical in both themes)
with the count digit punched out in `#241A02` (`mobile_chrome.dart:273-288`). I detect it by
building an exact-colour mask of `#F7A42C` and eroding by a 5×5 window: a present badge leaves a
solid core of 6 px, an absent one leaves 0. Across all 54×2 frames the discriminator has no
overlap — 6 vs 0 — and I confirmed it visually on a rendered crop before trusting it.

```
BEFORE (1657082): total=54  carriesNeedsYouBadge=12  noBadge=42
AFTER  (HEAD):    total=54  carriesNeedsYouBadge=26  noBadge=28
```

**The 28 that do not carry it, and why each cannot:**

- **26 desktop frames (1280×900)** — `defect_golden_test.dart:65`, `design_render_test.dart:214`
  and `overview_render_test.dart:123` all mount the `Sidebar` rail, not the mobile nav bar. The
  rail renders the Needs-you count as a `Text` in `palette.attention` (`sidebar.dart:262-276`),
  which is `#A35F00` in light and `#F7A42C` in dark — text, never an 18×18 disc. Verified: the
  rail count glyph is present in **26 of 26** desktop baselines, at bbox `[173,159]-[177,166]`,
  in exactly the right palette colour for its theme.
- **2 `defect_list_loading_mobile` frames** — a loading state. The badge is absent in the
  baseline *and* in the current render. It is not stale; it is current, and it correctly renders
  no badge.

**So the dispatch's expectation is not achievable as stated.** 28 of the 54 goldens render no
mobile nav bar, and no regeneration can put a mobile nav badge into a desktop frame. What *is*
true and now holds: **every badge the source can produce is present in a baseline**, and all 54
baselines are byte-identical to what the current source renders (§4).

I did not chase the dispatch's "196 and 200 orange px" figure. It does not reproduce under any
method I could construct — the badge disc yields 171 exact-`#F7A42C` px, and the light-theme rail
count yields a separate `#A35F00` population. Whatever produced 196/200, it was counting
something my detector does not reproduce, and I would rather report a number I can defend than
one I cannot. The pixel-delta measurement in §4 is the authoritative staleness signal anyway, and
it needs no colour-key assumption at all.

---

## 2. What the check does

`apps/control_plane/test/tools/golden_domination.dart` grades each committed baseline against a
fresh render and reports the delta **as a number**. The discriminator between "changed a little,
legitimately" and "stale and silent" is **this machine's own noise floor**, measured rather than
assumed: two independent renders of the same source, and the largest delta between them.

| Verdict | Condition | Meaning |
|---|---|---|
| `CURRENT` | `ratio <= noiseFloor` | matches the render as closely as this platform can be expected to |
| `TOLERANCE-DOMINATED` | `noiseFloor < ratio <= 0.005` | **the silent case.** The golden tests pass it, and the pass is an artefact of the threshold |
| `DIVERGED` | `ratio > 0.005` | the real comparator already fails it |
| `ORPHANED-BASELINE` | baseline exists, nothing renders it | a committed artefact describing nothing |
| `MISSING-BASELINE` | frame rendered, nothing committed | a new golden that was never committed |

Three properties I deliberately built in, because the check's value is entirely in not being
foolable:

1. **The threshold is parsed out of `golden_tolerance.dart`, not duplicated.** `RegExp(r'double\s+threshold\s*=\s*([0-9]*\.?[0-9]+)')`.
   A check pointed at a tolerance the comparator does not use would grade against a fiction.
   `--tolerance` exists for experiments and is rejected if it disagrees with the file.
2. **The check refuses to grade if the comparator stops being a real comparison.**
   `assertComparatorIsReal()` fails unless `golden_tolerance.dart` still calls
   `GoldenFileComparator.compareLists`. A comparator returning `true` unconditionally would make
   every golden in this repository unfalsifiable, and the check would then report a fiction as
   evidence.
3. **The check refuses to grade on a platform whose two renders disagree.** If `noiseFloor >=
   tolerance` it exits 2 with `ENVIRONMENT` wording instead of reporting 54 confident verdicts
   that describe the runner rather than the corpus.

**The comparator is untouched.** It still does a real byte/pixel comparison, on every golden,
through `GoldenFileComparator.compareLists`. This is a classification layer on top of it. The
golden suite runs unmodified in CI ahead of the check, so a genuine visual regression still fails
on pixels alone.

`png_pixel_diff.dart` is a ~120-line dependency-free PNG reader and per-pixel comparator. It has
to run as a plain `dart run` tool in CI, outside `flutter test`, so it cannot use `flutter_test`
or `dart:ui`; all 54 goldens are 8-bit non-interlaced RGBA (verified across the corpus) and
`dart:io` ships the inflate. **I validated the decoder against an independent implementation
(Pillow) before trusting it** — dumped every pixel of four goldens spanning all three viewport
sizes and both themes; byte-for-byte identical output, 18.4 MB / 6.7 MB / 5.3 MB / 4.3 MB of
pixel data.

---

## 3. The more serious finding: the golden suite was not in CI

`ci.yaml`'s `test` job runs `melos run test --no-select`, and melos's `test` script explicitly
ignores `control_plane` (`pubspec.yaml:67-75`, with a comment explaining that `dart test` cannot
run a Flutter widget suite). No other workflow in `.github/workflows/` renders a golden:
`macos-workers.yaml` runs an iOS integration test in `packages/control_plane_client`,
`infrastructure.yaml` runs tofu, `release.yaml` runs docker builds.

**So no CI job had ever looked at a single golden.** The tolerance was not merely hiding drift —
nothing was checking. That reframes the defect: a threshold that reports `PASS` with no number is
a latent problem, but here it was never even reached, because the suite that installs the
threshold was not executing in the build at all. Both need fixing, and the new
`golden-integrity` job does both.

### The CI job

`golden-integrity` on `macos-14`: checkout → Flutter at the repo's own `.fvmrc` pin →
`flutter pub get` → snapshot the committed baselines → `flutter test` (real comparator) →
`flutter test --update-goldens` ×2, keeping each render → grade the **snapshot** against both
renders.

Grading the snapshot rather than the working tree means the step cannot commit or bless a render.
Taking the renders from the **whole** suite rather than from a file list means a golden test file
added later cannot silently escape the check — `MISSING-BASELINE` catches it.

`runs-on` is pinned to macOS deliberately and the reason is in the job comment: the baselines are
platform-specific pixel data. On a platform whose text rasterisation differs, the check would
report 54 confident verdicts describing the runner, so guard 3 above exists and exits 2 with
that diagnosis instead.

**I verified the action inputs against the upstream README rather than guessing them.** My first
draft used `fvm-version-file:`, which does not exist; the documented input is
`flutter-version-file:`, which reads `pubspec.yaml`, `.fvmrc` or `.fvm/fvm_config.json` through
`yq` (auto-installed by the action). Both commits were rebuilt after that correction, so the
reported HEAD never contained the bad input.

---

## 4. Proof the check fires

Required, and the point of the whole lane. I reverted **one** golden to its `1657082` blob in the
working tree — `git show 1657082:…/defect_list_empty_mobile.png` — and ran both the suite and the
check against the same tree.

### A. The golden suite, through the **unchanged** tolerant comparator

```
$ flutter test
00:47 +207: All tests passed!          exit=0
```

The stale baseline is present, 280 pixels of it differ from the current render at a peak channel
delta of 234, and the suite is **green**. This is the defect, reproduced on demand.

### B. The domination check, same working tree

```
$ dart run test/tools/check_golden_domination.dart \
    --baseline=test/goldens --current=/tmp/gi2/pass1 --repeat=/tmp/gi2/pass2
golden-domination check
  comparator         test/helpers/golden_tolerance.dart
  tolerance          0.5000% (0.005), read from the comparator, not hard-coded here
  noise floor        0.0000% — largest current-vs-repeat delta, measured on this machine

TOLERANCE-DOMINATED (1)
  defect_list_empty_mobile.png      0.0851%  280/329160 px, peak channel delta 234
CURRENT (53)
  …

FAIL: 1 of 54 baselines are not current. The tolerance did not cause this; it hid it.
  1 of them pass the golden comparator ONLY because their delta sits inside the 0.5000%
  tolerance. Those are stale baselines being reported green, which is the exact failure
  this check exists to catch.
exit=1
```

It names the file and the measured delta. Restored with `git checkout`; tree clean.

### C. The same check on the corpus as it stood at `1657082`

```
TOLERANCE-DOMINATED (40)
  run_detail_dark.png                       0.4934%  5684/1152000 px, peak channel delta 216
  run_detail_light.png                      0.4543%  5233/1152000 px, peak channel delta 245
  needs_you_dark.png                        0.3963%  4565/1152000 px, peak channel delta 142
  all_work_light.png                        0.3612%  4161/1152000 px, peak channel delta 149
  …
  create_defect_mobile.png                  0.0665%  280/421200 px,  peak channel delta 234
CURRENT (14)
FAIL: 40 of 54 baselines are not current.
```

`run_detail_dark.png` sat at 98.7% of the entire tolerance budget and reported PASS. That is the
class this closes.

### D. After regeneration

```
CURRENT (54)
PASS: 54 of 54 baselines match the current render within this machine's noise floor (0.0000%).
exit=0
```

### Noise floor

Two independent render passes of the current source are **byte-identical across all 54 files**
(`cmp`, verified outside the tool as well). The noise floor on this platform — macOS arm64,
Flutter 3.44.7 — is exactly **0.0000%**.

This contradicts the comparator's own doc comment, which claims 0.03%–0.3% run-to-run text jitter
"on this platform". Measured, the floor is zero here. I am **not** proposing any change to the
tolerance — it is forbidden here, and it does buy real cross-platform safety on a runner whose
rasterisation differs. But a reviewer should know the headroom the threshold is spending is
currently unspent on the platform the baselines were made on.

---

## 5. The regenerated baselines, by name

**40 files**, all under `apps/control_plane/test/goldens/`. A full-suite `--update-goldens`
rewrote nothing beyond this set — the other 14 were already byte-identical.

| # | File | Was stale by |
|---|---|---|
| 1 | `all_work_dark.png` | 0.3584% — 4129/1152000 px, peak 142 |
| 2 | `all_work_light.png` | 0.3612% — 4161/1152000 px, peak 149 |
| 3 | `create_defect_desktop.png` | 0.3202% — 3689/1152000 px, peak 149 |
| 4 | `create_defect_desktop_dark.png` | 0.3174% — 3657/1152000 px, peak 142 |
| 5 | `create_defect_mobile.png` | 0.0665% — 280/421200 px, peak 234 |
| 6 | `create_defect_mobile_dark.png` | 0.0665% — 280/421200 px, peak 221 |
| 7 | `decision_detail_dark.png` | 0.3584% — 4129/1152000 px, peak 142 |
| 8 | `decision_detail_light.png` | 0.3612% — 4161/1152000 px, peak 149 |
| 9 | `defect_detail_design_remediation_pending_desktop.png` | 0.3202% — 3689/1152000 px, peak 149 |
| 10 | `defect_detail_design_remediation_pending_mobile.png` | 0.0851% — 280/329160 px, peak 234 |
| 11 | `defect_detail_needs_clarification_desktop.png` | 0.3202% — 3689/1152000 px, peak 149 |
| 12 | `defect_detail_needs_clarification_mobile.png` | 0.0851% — 280/329160 px, peak 234 |
| 13 | `defect_detail_resolved_verified_desktop.png` | 0.3202% — 3689/1152000 px, peak 149 |
| 14 | `defect_detail_resolved_verified_mobile.png` | 0.0851% — 280/329160 px, peak 234 |
| 15 | `defect_detail_triage_complete_desktop.png` | 0.3202% — 3689/1152000 px, peak 149 |
| 16 | `defect_detail_triage_complete_mobile.png` | 0.0851% — 280/329160 px, peak 234 |
| 17 | `defect_detail_untriaged_desktop.png` | 0.3202% — 3689/1152000 px, peak 149 |
| 18 | `defect_detail_untriaged_mobile.png` | 0.0851% — 280/329160 px, peak 234 |
| 19 | `defect_detail_verification_pending_desktop.png` | 0.3202% — 3689/1152000 px, peak 149 |
| 20 | `defect_detail_verification_pending_mobile.png` | 0.0851% — 280/329160 px, peak 234 |
| 21 | `defect_list_empty_desktop.png` | 0.3202% — 3689/1152000 px, peak 149 |
| 22 | `defect_list_empty_desktop_dark.png` | 0.3174% — 3657/1152000 px, peak 142 |
| 23 | `defect_list_empty_mobile.png` | 0.0851% — 280/329160 px, peak 234 |
| 24 | `defect_list_empty_mobile_dark.png` | 0.0851% — 280/329160 px, peak 221 |
| 25 | `defect_list_error_desktop.png` | 0.3202% — 3689/1152000 px, peak 149 |
| 26 | `defect_list_error_desktop_dark.png` | 0.3174% — 3657/1152000 px, peak 142 |
| 27 | `defect_list_error_mobile.png` | 0.0851% — 280/329160 px, peak 234 |
| 28 | `defect_list_error_mobile_dark.png` | 0.0851% — 280/329160 px, peak 221 |
| 29 | `defect_list_loading_desktop.png` | 0.3202% — 3689/1152000 px, peak 149 |
| 30 | `defect_list_loading_desktop_dark.png` | 0.3174% — 3657/1152000 px, peak 142 |
| 31 | `defect_list_populated_desktop.png` | 0.3202% — 3689/1152000 px, peak 149 |
| 32 | `defect_list_populated_desktop_dark.png` | 0.3174% — 3657/1152000 px, peak 142 |
| 33 | `defect_list_populated_mobile.png` | 0.0851% — 280/329160 px, peak 234 |
| 34 | `defect_list_populated_mobile_dark.png` | 0.0851% — 280/329160 px, peak 221 |
| 35 | `needs_you_dark.png` | 0.3963% — 4565/1152000 px, peak 142 |
| 36 | `needs_you_light.png` | 0.3612% — 4161/1152000 px, peak 149 |
| 37 | `overview_dark.png` | 0.3584% — 4129/1152000 px, peak 142 |
| 38 | `overview_light.png` | 0.3612% — 4161/1152000 px, peak 149 |
| 39 | `run_detail_dark.png` | 0.4934% — 5684/1152000 px, peak 216 |
| 40 | `run_detail_light.png` | 0.4543% — 5233/1152000 px, peak 245 |

### Untouched, and why — the other 14

| Files | Reason |
|---|---|
| `mobile_all_work_{light,dark}`, `mobile_decision_detail_{light,dark}`, `mobile_needs_you_{light,dark}`, `mobile_overview_{light,dark}`, `mobile_run_detail_{light,dark}` (10) | already byte-identical to the current render |
| `product_detail_mobile_back_link{,_dark}.png` (2) | regenerated by `fix-product-detail-goldens-r1`; already current |
| `defect_list_loading_mobile{,_dark}.png` (2) | loading state; renders no nav badge in baseline or render, and is otherwise current |

These 14 are why the dispatch's 44 over-counts. The Manager sweep classified by "has the badge";
four of those 44 have no badge *and* are current, because the badge is not the only thing that
drifts and absence-of-badge is not a staleness test.

### Where the drift actually was

The badge is only part of it, and the reviewer should know the baseline frames were wrong in ways
a badge count cannot see:

- **The 14 mobile frames** — diff bbox is exactly 18×19 px at `[206,776]-[223,794]` in a 390×844
  frame: the badge anchor, nothing else. I confirmed the shape by rendering the crop as ASCII —
  baseline solid, current an `#F7A42C` disc with the `2` punched out.
- **The 26 desktop frames** — drift in the **sidebar rail**, not the nav bar. For
  `all_work_light.png`, all 4161 differing pixels are at `x < 200` (the rail) within `y 160–415`;
  the content area is untouched. The rail's top count block (`y 158–170`) and bottom block
  (`y 358–396`) match the baseline; the nav list between them does not — the current rail renders
  roughly four more destinations than the baseline shows.

---

## 6. `golden_tolerance.dart` is unchanged

| | Blob hash |
|---|---|
| `43ede2e` (per decision) | `7cd735ca360f7399e28c9b4b10cc9b0a2c07300d` |
| `878c332` (per decision) | `7cd735ca360f7399e28c9b4b10cc9b0a2c07300d` |
| `a7b58b1` (per decision) | `7cd735ca360f7399e28c9b4b10cc9b0a2c07300d` |
| **BEFORE** `1657082` | `7cd735ca360f7399e28c9b4b10cc9b0a2c07300d` |
| **AFTER** `c4fa46e` | `7cd735ca360f7399e28c9b4b10cc9b0a2c07300d` |
| working tree | `7cd735ca360f7399e28c9b4b10cc9b0a2c07300d` |

Not the threshold, not the comparator, not a bypass. `git diff 1657082 -- …/test/helpers/` is
empty. This is confirmed three ways: blob hash at `BASE` vs `HEAD`, `git hash-object` of the
worktree file, and an empty diff over the whole `test/helpers/` directory. The threshold is
additionally pinned by an assertion in `golden_domination_test.dart`
(`expect(readComparatorThreshold(), 0.005)`), so widening it now breaks the suite rather than
slipping through.

Every other prohibition, verified mechanically:

```
$ git diff --name-only 1657082 HEAD | grep -vE '^(apps/control_plane/test/(goldens|tools)/|\.github/workflows/ci\.yaml)'
   (nothing)
```

`apps/control_plane/lib/**`, `apps/server/**`, `packages/**`, `docker/**`, `docs/adr/**`,
`.decisions/**`, `.agents/**`, `.claude/**`, `.junie/**`, `.opencode/**` — all untouched. No test
weakened, skipped, `@Ignore`d, filtered or deleted; the suite went 190 → **207** (+17 new tests).
`make test-integration` not run. **Zero Docker or Compose commands** issued — including no
`ps`, `logs`, `info` or `config`. Nothing to tear down: no container, no database, no compose
project was created.

---

## 7. `git diff --stat 1657082`

```
 45 files changed, 1307 insertions(+)
```

### Split

**Text — `.dart` + workflow, 5 files, +1307 lines**

```
 .github/workflows/ci.yaml                                 |  76 +++++
 apps/control_plane/test/tools/check_golden_domination.dart | 277 ++++++++++++
 apps/control_plane/test/tools/golden_domination.dart       | 282 +++++++++++
 apps/control_plane/test/tools/golden_domination_test.dart  | 348 ++++++++++++++
 apps/control_plane/test/tools/png_pixel_diff.dart          | 325 ++++++++++++
```

**Binaries — 40 PNGs, +~1.2 MB**

```
40 files changed, 0 insertions(+), 0 deletions(-)   # line counts are meaningless for PNG
```

Per-file sizes run from `Bin 87686 -> 94860 bytes` (`run_detail_dark.png`) upward; the 26 desktop
frames grow the most (they gained rail content), the 14 mobile frames least (they gained one
18×18 disc).

### Commits — two, independently reviewable

| Commit | Contents | Reviewable as |
|---|---|---|
| `0353c32` | the check + the CI job (4 `.dart` files + `ci.yaml`) | the durable fix, reviewed on its own logic |
| `c4fa46e` | the 40 binaries, nothing else | a binary diff reviewed by file list and delta table |

---

## 8. Gates — verbatim

```
$ dart pub get
Got dependencies!
52 packages have newer versions incompatible with dependency constraints.
```
exit `0`

```
$ dart format --output=none --set-exit-if-changed .
Formatted 635 files (0 changed) in 8.69 seconds.
```
exit `0`

The dispatch expected `631 files (0 changed)`. **635, not 631** — I added four Dart files, so the
count rises by exactly four. `(0 changed)` is the assertion that matters and it holds.

```
$ cd apps/control_plane && flutter analyze
Analyzing control_plane...
No issues found! (ran in 9.7s)
```
exit `0`

```
$ cd apps/control_plane && flutter test
00:53 +207: All tests passed!
```
exit `0`

`+207`, above the `+190` baseline: **+17** new tests in `golden_domination_test.dart` covering the
PNG decoder (corpus dimensions, loud failure on an unreadable file), the pixel comparator (zero
on self-compare, a measured non-zero on a synthesised change), the classification boundaries
including the measured Product Detail drift, and the two structural verdicts. All four gates run
at `HEAD = c4fa46ec22188ac9b0463b1f2d6340a7bdfc55ea` with a clean working tree.

---

## 9. Residual risk I cannot close from this lane

**The `golden-integrity` job has never run.** I cannot execute GitHub Actions here. The logic it
calls is proven — it is the same command proven firing in §4 — but the *workflow wiring* is
unexercised: the runner label, the Flutter setup from `.fvmrc`, `flutter pub get` at the workspace
root.

The specific thing to watch: **`.fvmrc` pins Flutter 3.44.0, and these baselines were rendered
with Flutter 3.44.7** (the version on this machine's PATH). If 3.44.0 rasterises IBM Plex Sans
differently, the job goes red with a per-file delta table naming every frame. That is the correct
behaviour — loud, with numbers, not a silent pass — and it is a decision to make deliberately with
that evidence in hand, not something I should pre-empt by overriding the repo's SDK pin inside a
CI file. **I recommend the first run of this job be treated as a calibration, and I flag it for
the reviewer rather than claiming it green.**

I pinned the job to `.fvmrc` rather than to 3.44.7 on purpose: forking the pin inside a workflow
would make the declared SDK and the rendering SDK disagree, and the goldens are pixel data whose
meaning includes the rasteriser that produced them.

---

## 10. Discoveries, classified

| # | Category | Finding | Disposition |
|---|---|---|---|
| D1 | `PROJECT_FACT` | **The control_plane golden suite was never executed by any CI job.** `ci.yaml`'s `test` excludes `control_plane` (melos `test` ignores it, `pubspec.yaml:67-75`) and no other workflow renders a golden. | **Fixed in `0353c32`** — `golden-integrity` job added |
| D2 | `RUNTIME_DISCOVERY` | Two independent render passes of the current source are **byte-identical across all 54 goldens** on macOS arm64 / Flutter 3.44.7. Measured noise floor is 0.0000%, against the 0.03%–0.3% the comparator's doc comment claims for "this platform". | Persisted as executable knowledge — `golden_domination_test.dart` asserts the floor is 0 over the whole corpus, so a platform where it stops being 0 fails the suite |
| D3 | `PROJECT_FACT` | The "Needs-you badge" is two different widgets. Mobile: an 18×18 `attentionTick` disc (`mobile_chrome.dart:273`). Desktop rail: a `Text` in `palette.attention` (`sidebar.dart:262-276`), `#A35F00` light / `#F7A42C` dark. Absence of the disc is not evidence of staleness. | Persisted as executable knowledge — `classify()` tests grade on pixel delta and need no colour assumption; the two renderings are recorded in this report |
| D4 | `RUNTIME_DISCOVERY` | The authority file reads `status: PENDING` **at this branch's `BASE_SHA`**; the resolution (`RESOLVED`, `selected_option: OPTION_A`, `decided_at: 2026-10-08T04:26:00Z`) landed on `main` in `a8a990b` at 06:37:06, five minutes *after* my base `1657082` (06:32:20). No contradiction — this branch was cut 5 minutes before the human's answer was committed. Checked against `git show main:.decisions/…`. | **Not an action item.** Recorded so the reviewer is not sent looking for a governance problem that does not exist. I confirmed the resolved option matches the dispatch (`OPTION_A`) and that its recorded scope discipline — comparator not to be widened, tightened or bypassed; the check must classify, not weaken — is exactly what I implemented. |
| D5 | `AUTOMATION_OPPORTUNITY` | The tolerance's declared justification (cross-platform text jitter) is currently unspent on the baselines' own platform (D2), but is presumably load-bearing on a Linux runner. The render platform is now pinned in the CI job but recorded nowhere the app can read. | **Reported, not actioned.** Recording a render-environment contract (platform + Flutter version next to the baselines) would need a decision about which Flutter version *owns* the goldens — that is governance, not mine. Flagged to the Manager. |
| D6 | `PROJECT_FACT` | The resolved decision's follow-up actions name three requirements; all three are met. *"Regenerate … report the file list explicitly"* → §5, by name with each file's measured delta. *"Assert `golden_tolerance.dart` is unchanged and that the golden suite still runs a real byte comparison"* → §6 (blob hash) and the `assertComparatorIsReal()` precondition plus its test. *"Independent-review before integration, since the lane writes CI gates"* → `READY_FOR_INDEPENDENT_REVIEW: YES`, and I do not approve my own work. | Verified against `git show main:.decisions/…` rather than the dispatch summary |

D1 is the finding that matters. Anyone reading only "the tolerance was too wide" would have
shipped a check that never runs.

---

## 11. Cleanup

Nothing to tear down. No container, no database, no compose project was created. Scratch
directories used for the render captures are outside the repository
(`/tmp/gi`, `/tmp/gi2`) and are not part of the worktree. The working tree at `HEAD` is clean;
the deliberately-stale golden used for the §4 proof was restored with `git checkout`.

Not pushed. Not merged. `main` untouched.

---

RESULT: IMPLEMENTED

FEATURE: Tolerance-domination CI check for golden baselines, and regeneration of the stale ones
BRANCH: fix/golden-domination-n2
BASE_SHA: 1657082febfc9e4a4ccea0eb2b21296ee56c4b2e
HEAD_SHA: c4fa46ec22188ac9b0463b1f2d6340a7bdfc55ea
COMMITS: 0353c32 (check + CI) → c4fa46e (40 binaries), two logical commits, neither pushed

OWNED_PATHS:
  - apps/control_plane/test/goldens/**
  - apps/control_plane/test/tools/**
  - .github/workflows/ci.yaml
READ_ONLY_PATHS:
  - apps/control_plane/lib/features/product_detail/product_detail_page.dart (read)
  - apps/control_plane/lib/features/products/add_product_page.dart (read)
  - apps/control_plane/lib/shared/{mobile_chrome,sidebar}.dart, lib/core/design_tokens.dart (read)
  - docs/engineering/dispatch/tasks/fix-product-detail-goldens-r1/report.md (read)
  - docs/engineering/dispatch/tasks/review-fix-product-detail-goldens-r1/report.md (read)
  - docs/engineering/learning/add_product_ui_learning.md, docs/checkpoints/DESIGN-HANDOFF.md,
    docs/reports/S2_NON_VISUAL_RELEASE_BLOCKER_CLOSURE.md (read)
  - .decisions/cff0e948-80a5-48ab-9a7b-f2a99be6f870.yaml (read)
PROHIBITED_PATHS: none touched — verified by empty `git diff --name-only 1657082 HEAD` outside
  OWNED_PATHS. `apps/control_plane/lib/**`, `apps/server/**`, `packages/**`, `docker/**`,
  `docs/adr/**`, `.decisions/**`, `.agents/**`, `.claude/**`, `.junie/**`, `.opencode/**` clean.
  `apps/control_plane/test/helpers/golden_tolerance.dart` blob `7cd735ca` unchanged.

FILES_CHANGED:
  5 text files (+1307 lines):
    .github/workflows/ci.yaml                                 |  76 +
    apps/control_plane/test/tools/check_golden_domination.dart | 277 +
    apps/control_plane/test/tools/golden_domination.dart       | 282 +
    apps/control_plane/test/tools/golden_domination_test.dart  | 348 +
    apps/control_plane/test/tools/png_pixel_diff.dart          | 325 +
  40 binaries (apps/control_plane/test/goldens/*.png), listed by name in §5

GATES:
  deps=pass    `dart pub get` (repo root) → "Got dependencies!"
  format=pass  `dart format --output=none --set-exit-if-changed .` → "Formatted 635 files (0 changed)"
               (dispatch said 631; +4 because I added four Dart files — (0 changed) is the assertion)
  analyze=pass `cd apps/control_plane && flutter analyze` → "No issues found! (ran in 9.7s)"
  tests=pass   `cd apps/control_plane && flutter test` → "+207: All tests passed!" (baseline +190, +17 new)
  build=n/a    no buildable artifact in scope; no production source changed
  runtime=pass  golden suite executed through the unchanged tolerant comparator at this exact
               HEAD_SHA; `dart run test/tools/check_golden_domination.dart` → "PASS: 54 of 54
               baselines match the current render" exit 0, and exit 1 naming the file and delta on a
               deliberately stale baseline (§4). Zero Docker/Compose commands issued.
  new-check-fired=pass  §4 A/B/C/D — suite green on a stale baseline, check red on the same tree

DISCOVERIES:
  D1 PROJECT_FACT — the control_plane golden suite was never run by any CI job; the tolerance was
     not merely hiding drift, nothing was checking. Fixed by the new `golden-integrity` job.
  D2 RUNTIME_DISCOVERY — render-to-render noise floor is exactly 0 on macOS arm64 / Flutter 3.44.7,
     contradicting the comparator's documented 0.03%–0.3% for "this platform". Persisted as an
     assertion over all 54 goldens.
  D3 PROJECT_FACT — the Needs-you badge is two widgets (mobile disc vs rail text), so
     absence-of-badge is not a staleness test; 4 of the dispatch's 44 were current for that reason.
  D4 RUNTIME_DISCOVERY — the authority file reads PENDING at this branch's BASE_SHA only because
     the resolution landed on main 5 minutes later; verified RESOLVED/OPTION_A against main. No
     governance action needed.
  D5 AUTOMATION_OPPORTUNITY — render platform is pinned in CI but recorded nowhere the app reads;
     deciding which Flutter version owns the goldens is governance. Flagged, not actioned.
  D6 PROJECT_FACT — all three follow-up actions named in the resolved decision are met (§5, §6,
     and this hand-off). Verified against the resolved file, not the dispatch summary.

KNOWLEDGE_PERSISTED:
  Executable, inside OWNED_PATHS, run by the existing suite:
    - apps/control_plane/test/tools/golden_domination_test.dart (17 tests) — decoder validated
      against the corpus, comparator, the four classification boundaries including the measured
      0.3172% Product Detail drift, the two structural verdicts, the noise floor over all 54, and
      `expect(readComparatorThreshold(), 0.005)` so widening the tolerance now breaks the build.
    - The noise-floor guard that refuses to grade on a platform whose two renders disagree.
  Prose only, in this report (not persisted to repository knowledge): §1 badge method, §5 drift
  localisation, §9 the Flutter-version calibration risk.

BLOCKERS: none.

READY_FOR_INDEPENDENT_REVIEW: YES

SAFE_PARALLEL_WORK:
  - Reviewing these two commits; re-running any gate in this worktree
  - Any lane owning docs/**, .decisions/**, LANES.md, WORK_STATE.md
  - design-qa-startup-restructure on docker/** and its own design artifacts — no path overlap
    with apps/control_plane/test/** or .github/workflows/ci.yaml
  - Read-only work anywhere in the repo
PROHIBITED_PARALLEL_WORK:
  - Any writer touching apps/control_plane/test/goldens/** or
    apps/control_plane/test/tools/** — concurrent ownership would invalidate this provenance
  - Any writer touching .github/workflows/ci.yaml — this is a gate every future build depends on
  - Any change to apps/control_plane/test/helpers/golden_tolerance.dart: byte-identical across
    43ede2e, 878c332, a7b58b1, 1657082 and c4fa46e, and must stay so. The tolerance is not the
    defect; widening it to force a green is a task failure.
  - Any change to apps/control_plane/lib/** that would invalidate these baselines — they were
    regenerated from current source, so any lib change makes them stale again and
    `golden-integrity` will fail. That is the check working.

RECOMMENDED NEXT ACTION: INDEPENDENT_REVIEW
  Suggested focus, in priority order:
  1. The 40/44 correction and the 26/54 badge number — both contradict the dispatch. §1 and §4C.
  2. Whether `golden-integrity` is green on a real `macos-14` runner. It has never executed
     (§9). Treat the first run as calibration and read the Flutter 3.44.0-vs-3.44.7 risk before
     deciding anything about the SDK pin.
  3. The classification rules in `golden_domination.dart` — in particular whether "max over the
     corpus" is the right noise floor, and whether the `noiseFloor >= tolerance` refusal is the
     right behaviour on a Linux runner.
  4. The two commits are separable; the check/CI commit can be reviewed and merged independently
     of the 40 binaries.
  I cannot approve this. It writes CI gates every future build depends on.