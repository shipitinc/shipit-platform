# Report — fix-product-detail-goldens-r1

```yaml
RESULT: CORRECTION_COMPLETE
TASK_ID: fix-product-detail-goldens-r1
BRANCH: fix/product-detail-custody-claim
WORKTREE: /private/tmp/shipit-fix-pd-custody
CORRECTED_FROM_HEAD: 878c3327aea383a2501fe7d698282b9dcc0bb586
NEW_HEAD: a7b58b1e4801a824a0720834bd229a201241d466
```

## Pre-flight verification (before writing)

```
$ git branch --show-current
fix/product-detail-custody-claim
$ git rev-parse HEAD
878c3327aea383a2501fe7d698282b9dcc0bb586
$ git status --porcelain
(empty)
```

Both matched the dispatch. Working tree was clean, so the diff against `878c3327` below is
attributable solely to this lane.

## What changed

Exactly two golden PNGs, regenerated from the current source. Nothing else.

```
$ git diff --stat 878c3327 HEAD
 .../goldens/product_detail_mobile_back_link.png     | Bin 58955 -> 59894 bytes
 .../product_detail_mobile_back_link_dark.png        | Bin 58649 -> 59486 bytes
 2 files changed, 0 insertions(+), 0 deletions(-)

$ git status --porcelain        # pre-commit, only the two intended paths
 M apps/control_plane/test/goldens/product_detail_mobile_back_link.png
 M apps/control_plane/test/goldens/product_detail_mobile_back_link_dark.png

$ git diff --stat 43ede2e HEAD   # branch point
 .../product_detail/product_detail_page.dart         |   2 +-
 .../goldens/product_detail_mobile_back_link.png     | Bin 58955 -> 59894 bytes
 .../product_detail_mobile_back_link_dark.png        | Bin 58649 -> 59486 bytes
 3 files changed, 1 insertion(+), 1 deletion(-)
```

The branch-point diff is the original one-line source change **plus** the two goldens. No test
`.dart` file, no third file, no helper, no `lib/**` file beyond the string correction already
committed at `878c3327`.

## Invocation — confirmed, not guessed

`--update-goldens` was confirmed from three independent in-repo sources before use, not guessed:

- `docs/engineering/learning/add_product_ui_learning.md:53` — "Use `flutter test --update-goldens` to generate initial baselines"
- `docs/checkpoints/DESIGN-HANDOFF.md:535` — "regenerated via `flutter test --update-goldens`"
- `docs/reports/S2_NON_VISUAL_RELEASE_BLOCKER_CLOSURE.md:609` — contrast run "(only, no `--update-goldens`)"

The test file's own comment at `apps/control_plane/test/product_detail_mobile_golden_test.dart:16-21`
also confirms the golden is a *candidate* for human review and that no board reference resolves in
this pass.

Command actually run, scoped to the single golden test file so the other 52 baselines could not be
touched at all:

```
$ flutter test test/product_detail_mobile_golden_test.dart --update-goldens
00:01 +2: All tests passed!
```

## Other-goldens integrity check (independent of git)

Beyond the git diff, I md5-checksummed all 54 goldens before and after. Exactly two changed:

```
$ md5 -q apps/control_plane/test/goldens/*.png > before   # 54 lines
$ flutter test test/product_detail_mobile_golden_test.dart --update-goldens
$ md5 -q apps/control_plane/test/goldens/*.png > after
$ diff before after
51,52c51,52
< bd8bcc3cc5d9eaa387c6fdd95afe64ed
< 97f13b539cd0c4d25f10d303b701a237
---
> be4d92ca7157503fda71162619d5dcf0
> a0fd9518c230461303ff5837320b345e
```

The other 52 are byte-identical. `--update-goldens` rewrote nothing beyond the two named files, so
there is no separate drift finding to absorb.

## Verification 1 — I opened the goldens and looked at them

I used the Read tool on both PNGs (the images were rendered back to me and inspected, not inferred
from the source string).

**Light** (`product_detail_mobile_back_link.png`) — 390×844 mobile Product Detail. The `‹ Products`
back link is present at top. Under the **Access** heading, the monospace line reads, wrapped across
two lines exactly as the layout puts it:

> One key per repository. The private half stays in the
> secret manager.

**Dark** (`product_detail_mobile_back_link_dark.png`) — same viewport, dark theme. The Access block
reads identically:

> One key per repository. The private half stays in the
> secret manager.

The retired claim "The private half never leaves this device." appears in **neither** file.

## Verification 2 — the regression is actually gone

The reason this was HIGH: `useTolerantGoldens()` (`golden_tolerance.dart:43`, `threshold = 0.005`)
made the re-wrapped line fall inside tolerance, so the golden test passed while painting a false
security guarantee. Measured pixel delta between the old baseline at `878c3327` and the regenerated
one:

```
size (390, 844) (390, 844)
differing pixels: 1044 of 329160 = 0.3172%
max channel delta: 212
```

0.317% of pixels changed with a peak delta of 212/255. The old comparator's 0.005 threshold sat
above that 0.00317 fraction, which is precisely why the stale baseline passed silently. The golden
now constrains this copy again. Note this measurement is only diagnostic — I did **not** touch
`golden_tolerance.dart`, and it remains at 0.005, unmodified.

## Gates — verbatim

`.dart_tool/` was present at both repo root and `apps/control_plane`; `dart pub get` was run anyway
at the REPO ROOT as instructed.

```
$ dart pub get
Got dependencies!
52 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.

$ dart format --output=none --set-exit-if-changed .
Formatted 631 files (0 changed) in 7.08 seconds.
format exit=0

$ cd apps/control_plane && flutter analyze
Analyzing control_plane...
No issues found! (ran in 3.6s)
analyze exit=0

$ cd apps/control_plane && flutter test
...
00:53 +190: All tests passed!
test exit=0
```

All four gates pass. `make test-integration` not run and not required — golden baselines need no
database.

## Hard constraints — all held

| Constraint | Status |
|---|---|
| Never touch `golden_tolerance.dart` | Not modified; still `threshold = 0.005`. Widening it to force a pass is forbidden and did not happen. |
| Never modify any test `.dart` file | Zero test files changed (`git diff --stat 43ede2e` shows only `lib/**` + 2 PNGs). |
| Never modify the other 52 goldens | Verified twice: git diff and md5 sweep. All 52 byte-identical. |
| Never touch `apps/control_plane/lib/**` | Untouched in this lane. |
| Zero Docker/Compose commands | None issued — not `ps`, not `logs`, not `info`. |
| `make test-integration` | Not required, not run. |
| One commit, no push/merge, `main` untouched | One commit `a7b58b1` on `fix/product-detail-custody-claim`. Not pushed, not merged. |

## What this does NOT prove

The regenerated baseline makes the golden **current**. It does **not** make the copy **approved**.

No board scopes copy to
`apps/control_plane/lib/features/product_detail/product_detail_page.dart:614`. The focused-reviewer
confirmed that as a separate open MEDIUM design-authority finding (**F1**), which is out of this
lane's scope and remains open. A current golden is not proof of approved copy, and I make no such
claim. These two files are **candidates for human review**, exactly as the test file's own header
says. Nothing in this report should be read as design sign-off.

## Commit

```
a7b58b1 test(goldens): refresh Product Detail mobile baselines after custody-claim fix
```

Body records why: the baselines were last generated at `0d5d132`, the tolerant comparator silently
accepted the re-wrapped line, tolerance and all test `.dart` files are untouched.

## Durable discoveries

- `PROJECT_FACT` — The Product Detail mobile goldens were stale from `0d5d132` through `878c3327`
  while `flutter test` still reported them passing. `golden_tolerance.dart`'s `threshold = 0.005`
  is large enough to absorb a re-wrapped copy line (measured 0.3172% of pixels, peak delta
  212/255), so *a green golden test does not by itself prove a golden is current* for this
  repository. Persisted here rather than in the product knowledge base, since this lane owns only
  the two PNGs and the report path.
- `AUTOMATION_OPPORTUNITY` (reported, not acted on) — nothing in CI detects a golden whose render
  is dominated by comparator tolerance. A stale-baseline check (e.g. re-run comparison at a tighter
  threshold in a separate job, or a golden freshness assertion) would convert this class of silent
  regression into a failure. Owned by the Manager / framework lane; it touches test tooling outside
  my `PROHIBITED_PATHS`.

## Recommended next action

`FOCUSED_RE_REVIEW` — a fresh independent `focused-reviewer` verifies `a7b58b1`.

---

```
RESULT: CORRECTION_COMPLETE

CORRECTED_FROM_HEAD: 878c3327aea383a2501fe7d698282b9dcc0bb586
NEW_HEAD: a7b58b1e4801a824a0720834bd229a201241d466

FINDINGS_ADDRESSED:
- R1 (HIGH): Product Detail mobile goldens still painted the retired claim
  "The private half never leaves this device." Both regenerated from current source.
  Verified by opening both PNGs: the Access block now reads
  "One key per repository. The private half stays in the secret manager."
  The tolerant comparator had masked this as a passing test; the baseline no longer
  matches the source, so the visual guard constrains this copy again.

FILES_CHANGED:
- apps/control_plane/test/goldens/product_detail_mobile_back_link.png (binary, 58955 -> 59894 bytes)
- apps/control_plane/test/goldens/product_detail_mobile_back_link_dark.png (binary, 58649 -> 59486 bytes)

GATES:
format=pass (Formatted 631 files, 0 changed, exit 0)
analyze=pass (No issues found!, exit 0)
tests=pass (flutter test 190/190, All tests passed!, exit 0)
build=n/a (no build gate in this lane; format/analyze/test are the required set)
runtime=n/a (no runtime/browser gate; golden baselines need no database and no Docker was touched)

NEW_DISCOVERIES:
- PROJECT_FACT: a green Product Detail golden test did not imply a current golden —
  golden_tolerance.dart's 0.005 threshold absorbed a re-wrapped copy line (0.3172% of pixels,
  peak delta 212/255).
- AUTOMATION_OPPORTUNITY (reported, not acted on): no CI check detects a golden dominated by
  comparator tolerance; owner is the Manager/framework lane, outside my PROHIBITED_PATHS.

READY_FOR_FOCUSED_REVIEW: YES

SAFE_PARALLEL_WORK:
- Any read-only review of a7b58b1 in this worktree.
- Design lanes holding .decisions/** and docs/adr/** — disjoint from the two golden PNGs.
- Manager updates to docs/engineering/dispatch/LANES.md and WORK_STATE.md.

PROHIBITED_PARALLEL_WORK:
- Any writer to apps/control_plane/test/goldens/** (no other lane holds it, per dispatch).
- Any writer to apps/control_plane/test/** — explicitly PROHIBITED to this lane; the tolerance
  and all test .dart files must stay untouched.
- apps/control_plane/lib/**, apps/server/**, packages/**, docker/**, docs/adr/**, .decisions/**.
- Any Docker or Compose command from any lane without deployment authority (QA stack must stay up).
```

I cannot approve my own work. `READY_FOR_FOCUSED_REVIEW: YES` is a readiness signal only.