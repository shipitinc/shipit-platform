# Focused re-review — fix-product-detail-goldens-r1 (golden re-baseline)

```yaml
REVIEWER: focused-reviewer (independent, read-only)
REVIEWED_BRANCH: fix/product-detail-custody-claim
WORKTREE: /private/tmp/shipit-fix-pd-custody
CORRECTED_FROM_HEAD: 878c3327aea383a2501fe7d698282b9dcc0bb586
REVIEWED_HEAD: a7b58b1e4801a824a0720834bd229a201241d466
SCOPE: R1 (the two Product Detail mobile goldens) + regression risk from the correction
DOCKER_COMMANDS_ISSUED: 0
PENPOT_ACCESS: none — no board verification claimed
FILES_WRITTEN: this report only
```

**Verdict in one line:** R1 is genuinely resolved — both goldens now render the corrected custody
clause, the comparator was not weakened, and the other 52 baselines are byte-identical; the
correction additionally repaired an undisclosed second staleness (a missing nav badge) which
makes the baselines *more* faithful, not less, but the implementer's report mis-attributes the
pixel delta and that record should be amended.

---

## 1. Provenance — VERIFIED

```
$ git rev-parse HEAD
a7b58b1e4801a824a0720834bd229a201241d466          ← matches reported NEW_HEAD exactly

$ git rev-parse --abbrev-ref HEAD
fix/product-detail-custody-claim

$ git status --porcelain --untracked-files=all
(empty — clean tree before, during and after every gate I ran)

$ git log --oneline -n 3
a7b58b1 test(goldens): refresh Product Detail mobile baselines after custody-claim fix
878c332 fix(product-detail): correct the false key-custody claim in the Access block
43ede2e docs(qa): QA environment up and onboarding-ready; two faults diagnosed, one remaining string found

$ git rev-list --count 43ede2e..HEAD
2                                                ← exactly two commits ahead, as reported
```

- **Not pushed:** `git rev-parse --abbrev-ref '@{u}'` → `fatal: no upstream configured for branch
  'fix/product-detail-custody-claim'`. `git branch -r` shows only `origin/main`.
- **`main` untouched:** local `main` = `43ede2ec…` and `origin/main` = `43ede2ec…`, both identical to
  the reported branch point. No history rewritten.
- **No `.gitattributes`** at the repo root, so no clean/smudge filter could be reshaping the PNGs on
  the way in or out.

## 2. Diff scope — reconstructed independently

```
$ git diff 878c3327 HEAD --stat
 .../goldens/product_detail_mobile_back_link.png     | Bin 58955 -> 59894 bytes
 .../product_detail_mobile_back_link_dark.png        | Bin 58649 -> 59486 bytes
 2 files changed, 0 insertions(+), 0 deletions(-)

$ git diff 43ede2e HEAD --stat
 .../product_detail/product_detail_page.dart         |   2 +-
 .../goldens/product_detail_mobile_back_link.png     | Bin 58955 -> 59894 bytes
 .../product_detail_mobile_back_link_dark.png        | Bin 58649 -> 59486 bytes
 3 files changed, 1 insertion(+), 1 deletion(-)
```

- Against the lane's own base: **exactly the two named golden PNGs, nothing else.** ✔
- Against the branch point: the one-line source change plus the two goldens. ✔
- **No test `.dart` file and no third file is present.** Independently confirmed by asking for
  every Dart file changed anywhere on the branch:
  `git diff --name-only 43ede2e HEAD -- '*.dart'` → exactly one path,
  `apps/control_plane/lib/features/product_detail/product_detail_page.dart`.
- The source change is still the single in-place substitution, hunk `@@ -614 +614 @@`, byte-for-byte
  the string the prior focused review approved. This lane did not touch `lib/**`.

## 3. The central prohibition — the comparator was NOT weakened

This is the finding the dispatch was most emphatic about, so I checked it three ways: name-status,
blob identity across all three revisions, and the source itself.

```
$ git diff --name-only 43ede2e HEAD -- apps/control_plane/test/helpers/golden_tolerance.dart
(empty — unchanged)

$ git rev-parse 43ede2e:…/test/helpers/golden_tolerance.dart
7cd735ca360f7399e28c9b4b10cc9b0a2c07300d
$ git rev-parse 878c332:…/test/helpers/golden_tolerance.dart
7cd735ca360f7399e28c9b4b10cc9b0a2c07300d
$ git rev-parse HEAD:…/test/helpers/golden_tolerance.dart
7cd735ca360f7399e28c9b4b10cc9b0a2c07300d   ← identical blob at all three revisions
```

`golden_tolerance.dart:43` still reads, verbatim:

```dart
void useTolerantGoldens({double threshold = 0.005}) {
```

**The threshold is still 0.005 at line 43.** Not widened, not narrowed, not parameterised away.
Its last commit in repository history is `4e1fdb9`, long before this work item.

The comparator is also not **bypassed**. Read in full, `_TolerantGoldenComparator.compare` performs a
genuine byte comparison — `GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden))`
— and returns `true` only when `result.passed` (exact) or `diffPercent <= _threshold`. There is no
early return, no try/catch swallow, and no path that yields `true` without comparing.

The test that consumes it is equally untouched:

```
$ git rev-parse 43ede2e:…/test/product_detail_mobile_golden_test.dart
b89291ca2043dd21d090431d9967a7819125cc76
$ git rev-parse HEAD:…/test/product_detail_mobile_golden_test.dart
b89291ca2043dd21d090431d9967a7819125cc76   ← identical blob
```

It still calls `matchesGoldenFile(...)` (line 130) for both themes from the
`for (final themeMode in ['light','dark'])` loop (line 72), and still asserts the objective
`expect(find.text('‹  Products'), findsWidgets)`. No skip, no `@Ignore`, no `@TestOn`, no tag
filter, no `expected:`. **Verdict: the stale baseline was treated as the defect, exactly as
instructed.**

## 4. The other 52 goldens — byte-identical

Git says so, and I did not rely on git alone. I checksummed all 54 goldens against their blobs at
`878c332`:

```
total goldens compared: 54
DIFFERS: apps/control_plane/test/goldens/product_detail_mobile_back_link.png
DIFFERS: apps/control_plane/test/goldens/product_detail_mobile_back_link_dark.png
total differing goldens vs 878c332: 2
```

**52 of 54 byte-identical.** The tree holds 54 goldens; the working tree also holds 54; the two
changed files' working-tree md5s match their `HEAD` blobs exactly
(`a0fd9518…` light, `be4d92ca…` dark), so what I inspected is what is committed.

## 5. Visual verification — I opened both PNGs and read them

Both images were rendered back to me and inspected. Not inferred from the source string.

**Light — `product_detail_mobile_back_link.png` (390×844).** `‹  Products` back link at top;
`ShipIt Platform` with `GOVERNED · ACTIVE`; the five definition rows (WHAT THIS IS ABOUT, STATUS,
ACTIVE BASELINE, WHAT'S UNDER GOVERNANCE); then the **Access** heading, and directly beneath it the
grey monospace line, wrapped across two lines exactly as the layout puts it:

> One key per repository. The private half stays in the
> secret manager.

Then the credential row (`git@github.com:ac…` / `verified` / `GIT_PRODUCT_SHIPIT_R…`), the
Governance card, and the bottom nav.

**Dark — `product_detail_mobile_back_link_dark.png` (390×844).** Same viewport, dark theme, same
content. The Access block reads identically:

> One key per repository. The private half stays in the
> secret manager.

**The retired claim "The private half never leaves this device." appears in neither file.** I
confirmed this side-by-side rather than by squinting: I cropped the Access band (y=350–410) from the
old and new light golden and viewed them adjacent. Left (old): *"One key per repository. The private
half never leaves / this device."* Right (new): *"One key per repository. The private half stays in
the / secret manager."* The wrap point moved as well (`leaves` → `stays in the`), which is the
re-wrap the implementer described.

## 6. Gates — re-run by me, verbatim

`dart pub get` was run at the **REPO ROOT** first as instructed (both `.dart_tool` directories were
already present; I ran it regardless).

```
$ dart pub get                                        (repo root)
Got dependencies!
52 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
EXIT=0

$ dart format --output=none --set-exit-if-changed .   (repo root)
Formatted 631 files (0 changed) in 4.22 seconds.
EXIT=0

$ cd apps/control_plane && flutter analyze
No issues found! (ran in 2.4s)
EXIT=0

$ cd apps/control_plane && flutter test
…
00:41 +190: All tests passed!
EXIT=0
```

All four match their stated baselines exactly. `git status --porcelain --untracked-files=all` was
empty immediately after `dart pub get` and after `dart format`, confirming no PROHIBITED path was
touched by the gates (the known `apps/server` churn did not occur). **`make test-integration` was
not run and not required** — golden baselines need no database. **Zero Docker/Compose commands
were issued**, including `ps`, `logs`, `config` and `info`.

### The golden test is a real comparison, and it is not skipped

```
$ flutter test test/product_detail_mobile_golden_test.dart --reporter expanded
00:00 +0: loading …/test/product_detail_mobile_golden_test.dart
00:00 +0: (setUpAll)
00:00 +0: Product detail · mobile back link to Products light
00:01 +1: Product detail · mobile back link to Products dark
00:01 +2: (tearDownAll)
00:01 +2: All tests passed!
EXIT=0
```

Both theme cases execute and both compare. Run four times in total across my session — all `+2:
All tests passed!`, worktree clean after every run (no golden silently rewritten).

---

## 7. Findings

### R1 — HIGH — **RESOLVED, VERIFIED**

The finding was that both baselines still rendered the retired claim while `flutter test` reported
them passing, so the only visual guard on Product Detail mobile constrained nothing. All three of its
consequences are now closed:

1. *The baseline no longer encodes a false security guarantee.* Verified visually in both themes
   (§5), with an old-vs-new side-by-side.
2. *A human golden reviewer is no longer shown a claim the app does not make.* Same evidence.
3. *The guard constrains this copy again.* The baseline was written from the current source by the
   sanctioned path and passes the unmodified 0.005 comparator, while the **old** baseline sat 0.3172%
   away from the current render — see §8, where I reproduce that number exactly.

### N1 — LOW, non-blocking — **report mis-attributes the pixel delta; one undisclosed drift absorbed**

The regeneration changed more than the custody line, and the report does not say so. My independent
pixel diff of light golden `878c332 → a7b58b1`:

```
total pixels      : 329160
differing pixels  : 1044  (0.3172%)
per-band extrema  : ((0,203),(0,213),(0,234))  -> max channel delta 234
differing rows    : y=373..794
   row band y=373..382  pixels=324     <- custody line 1
   row band y=385..395  pixels=440     <- custody line 2
   row band y=776..794  pixels=280     <- an orange "2" Needs-you nav badge
```

**280 of the 1044 differing pixels (27%) are not the custody line at all** — they are a circular
orange "2" notification badge on the bottom nav's *Needs you* item, which the old baselines do not
have and the new ones do. I confirmed it by cropping and viewing the bottom band of both: the old
golden's badge box is flat `(239,239,236)` light / `(26,28,27)` dark; the new one carries 207 light /
204 dark orange pixels matching `(247,164,44)`. The report's §"Verification 2" describes the entire
delta as "the re-wrapped line" and its `PROJECT_FACT` generalises from that.

**This is an improvement, not a defect — and I checked that carefully rather than assuming it:**

- `app_shell.dart:37,97` — `_needsYouCount` is filled asynchronously by `_loadCounts()`;
  `mobile_chrome.dart:185` draws the badge when `(needsYouCount ?? 0) > 0`.
- `app_fixtures.dart:58` — the `MockRepository` default is
  `OverviewResponse(running: 5, waitingOnYou: 2, recentlyFinished: 12)`, and `app_fixtures.dart` has
  **no commit since the `0d5d132` baseline commit**. So the count is deterministic fixture data, not
  a clock and not a race — the badge cannot flip in and out between runs.
- All ten other AppShell baselines (`mobile_overview_*`, `mobile_needs_you_*`, `mobile_all_work_*`,
  `mobile_run_detail_*`, `mobile_decision_detail_*`) carry the badge, with badge bounding box
  **exactly** `(206,777,223,793)` — pixel-identical geometry to the new product_detail goldens.

Therefore the **old** product_detail baselines were the outlier: they had captured a frame taken
before the shell's counts resolved, and the regeneration moved them onto the corpus norm. Nothing
needs rolling back.

Two smaller inaccuracies in the same section, recorded so no later lane reasons from them: the
report's "max channel delta: 212" is 234 (light) / 221 (dark) as measured; and it quotes only the
light-theme figures, the dark theme being 1034 px / 0.3141%.

**Actionable (record only, no code change):** amend the `fix-product-detail-goldens-r1` report and
its `PROJECT_FACT` to state that 764 px of the delta is the custody line and 280 px is the nav badge
recovered from a pre-counts-load frame.

### N2 — LOW, informational — routed to the Manager, **not** this lane

The same tolerance-masked staleness that R1 described still exists elsewhere, and the correction
correctly did not absorb it. `defect_golden_test.dart` also renders through `AppShell` — I verified
this by cropping the defect mobile goldens' bottom bands, which show the identical
Overview/All work/Needs you/Products/Reports nav with *Reports* selected — yet all sixteen of
`defect_detail_*_mobile*.png` and `defect_list_*_mobile*.png` show **zero** badge pixels, i.e. the
same pre-counts-load frame the old product_detail baselines had. They were last touched at `0d5d132`
and pass today only because 280 px = 0.085% sits comfortably under the 0.005 threshold.

This is the implementer's own `AUTOMATION_OPPORTUNITY` realised with concrete evidence, and it shows
the class is **systemic across the golden corpus, not confined to the two files fixed**. Both paths
were PROHIBITED to this lane (`apps/control_plane/test/**.dart`, and every golden other than the two
named), so the decision not to touch them was correct. It belongs to the Manager / framework lane
alongside the stale-baseline detection idea.

### F1 — MEDIUM — **remains OPEN, unconverted, and correctly handled**

No board scopes copy to `product_detail_page.dart:614`; I have **no Penpot access and claim no board
verification**. I checked that the implementer did not quietly close it: its report says the
regenerated baseline "makes the golden **current**. It does **not** make the copy **approved**",
states no board scopes the string, keeps F1 open and out of scope, calls both files "**candidates
for human review**", and closes with "Nothing in this report should be read as design sign-off." That
is the correct handling. F1 is a design-lane task, not a code defect, and — consistent with the prior
review's own severity assessment — it does not block this branch.

### Honest limit of what I could verify

I could **not** directly measure `diffPercent(new golden, fresh render)`, because doing so requires
instrumenting `golden_tolerance.dart`, which is prohibited to me and to the implementer alike. So
"the new baseline is exact rather than merely tolerated" rests on inference rather than a measurement
of mine: it was written by the sanctioned `--update-goldens` path from current source, it passes the
unmodified comparator, it was stable across four consecutive runs, and its shared AppShell chrome is
pixel-identical in geometry to ten independently generated baselines. What I *did* measure is the
number that mattered for the diagnosis — the old baseline sat **0.3172%** from the current render,
reproduced exactly — which independently confirms R1's root-cause arithmetic.

---

## 8. Reproducing R1's root cause, independently

```
old golden (878c332) vs current render (= the new golden):
  1044 of 329160 pixels = 0.3172%   >  0   (would fail an exact comparator)
                                    <  0.5%  (absorbs under threshold 0.005 = 1645 px)
```

That is precisely why `flutter test` reported a stale baseline as passing, and it confirms the
dispatch's premise that the tolerance is not the defect — the stale baseline was.

## 9. What I did not do

- Did **not** edit any production, test or golden file. No `Write`/`Edit` at all; the only file
  written is this report. Scratch image analysis ran entirely outside the repository, in
  `/var/folders/…/opencode/pdg/`.
- Did **not** run `flutter test --update-goldens`, or any command that writes to the goldens.
- Did **not** run `make test-integration`, and issued **zero** Docker/Compose commands, including
  read-only ones. The QA stack was not disturbed.
- Did **not** claim board verification — no Penpot access.
- Did **not** re-review the string itself (`:614`) or the wider F5 copy work item; the prior focused
  review already approved those and they are byte-unchanged.
- Did **not** audit the `main` checkout's 49 modified tracked files. They are all under
  `apps/control_plane/test/failures/` and other stray QA scratch files, timestamped Sep 16 / Oct 1 /
  Oct 2 — **weeks before this session and unrelated to this branch**. The worktree under review was
  clean before, during and after every gate. Flagged only so it is not later mistaken for fallout of
  this correction.

## 10. Next action for the Manager

Land `a7b58b1` with `878c332`. R1 is closed and the two revisions are no longer out of step — which
was the whole point of this lane. Three items to carry forward, none blocking:

1. Amend the `fix-product-detail-goldens-r1` report's delta attribution per N1.
2. Route N2 (sixteen stale defect mobile baselines + the tolerance blind spot) to the framework lane
   as a standing item, alongside the implementer's `AUTOMATION_OPPORTUNITY`.
3. Route F1 (Product Detail's `Access` block has no board owner) to a design lane.

```
RESULT: APPROVE_CORRECTIONS

REVIEWED_HEAD: a7b58b1e4801a824a0720834bd229a201241d466

FINDINGS_REVIEWED:
  R1 (HIGH) — Product Detail mobile goldens still rendered the retired custody claim and passed
     only on tolerance. RESOLVED, VERIFIED on both themes.
     - Provenance: HEAD == a7b58b1e4801a824a0720834bd229a201241d466, exactly 2 commits ahead of
       43ede2e, clean tree, no upstream configured, local main and origin/main both still 43ede2e.
     - `git diff 878c3327 HEAD` == exactly the two golden PNGs; nothing else.
     - `git diff 43ede2e HEAD` == the one-line product_detail_page.dart change (@@ -614 +614 @@)
       PLUS the two goldens. No test .dart, no third file; the only Dart file changed anywhere on
       the branch is product_detail_page.dart.
     - CENTRAL PROHIBITION HELD: golden_tolerance.dart is blob-identical (7cd735ca…) at 43ede2e,
       878c332 and HEAD, and line 43 still reads `void useTolerantGoldens({double threshold =
       0.005}) {`. The comparator still performs a genuine compareLists byte comparison with no
       bypass path. The golden test file is blob-identical (b89291ca…) — no skip, no @Ignore, no
       filter, matchesGoldenFile and the objective back-link assertion both intact. The stale
       baseline was treated as the defect, not the comparator.
     - Other 52 goldens: md5-compared all 54 against their 878c332 blobs — exactly 2 differ,
       52 byte-identical.
     - Visual: opened both PNGs. Light and dark Access blocks both read "One key per repository.
       The private half stays in the / secret manager." The retired claim is absent from both,
       confirmed by an old-vs-new side-by-side crop of the Access band.
     - Gates re-run by me: dart pub get EXIT=0; format 631 files (0 changed) EXIT=0; analyze
       "No issues found!" EXIT=0; flutter test "+190: All tests passed!" EXIT=0. Golden test runs
       both light and dark with a real comparison, stable over 4 runs, tree clean throughout.
       Zero Docker/Compose commands.

REGRESSIONS: none.

  Non-blocking findings recorded, neither requiring code change nor blocking the merge:
  N1 (LOW) — the regenerated goldens also recovered a second, undisclosed staleness: an orange "2"
     Needs-you nav badge absent from the old baselines (280 of the 1044 differing pixels, 27%;
     764 px are the custody line). Confirmed to be an improvement — the count is deterministic
     fixture data (`waitingOnYou: 2`, fixtures unchanged since 0d5d132) and the new badge geometry
     (206,777,223,793) matches all ten other AppShell baselines exactly, so the OLD baselines were
     the outlier. But the implementer's report attributes the whole delta to the re-wrapped line and
     states max channel delta 212 where I measure 234 (light) / 221 (dark). Actionable: amend the
     report's delta attribution and PROJECT_FACT.
  N2 (LOW, Manager/framework lane) — the same tolerance-masked staleness persists in all sixteen
     `defect_detail_*_mobile*.png` / `defect_list_*_mobile*.png` baselines: they render through
     AppShell (verified by their bottom nav) yet carry zero badge pixels, i.e. a pre-counts-load
     frame, last touched at 0d5d132, passing only because 0.085% < 0.5%. Both paths were PROHIBITED
     to this lane, so not absorbing them was correct. Confirms the class is systemic across the
     corpus, which is the implementer's AUTOMATION_OPPORTUNITY with evidence.
  F1 (MEDIUM, OPEN, unchanged and correctly unconverted) — no board scopes copy to
     product_detail_page.dart:614; I have no Penpot access and claim no board verification. The
     implementer explicitly declined to claim design sign-off and kept F1 open. Design-lane task,
     not a code defect, non-blocking per the prior review's own assessment.

BLOCKERS: none

READY_FOR_MERGE: YES
```

`READY_FOR_MERGE: YES`. The prior review withheld it solely because R1 was open; R1 is now closed
and the two revisions are no longer out of step. F1 remains an open design-lane item and does not
block, exactly as the prior review concluded. N1 needs a report amendment, not a code change; N2
belongs to a lane this correction was forbidden from touching.
