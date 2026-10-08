# Focused re-review — fix-product-detail-custody-claim

```yaml
REVIEWER: focused-reviewer (independent, read-only)
REVIEWED_BRANCH: fix/product-detail-custody-claim
WORKTREE: /private/tmp/shipit-fix-pd-custody
CORRECTED_FROM_HEAD: 43ede2ec362e0cc79e6a0b55f5994bc3651a5d72
REVIEWED_HEAD: 878c3327aea383a2501fe7d698282b9dcc0bb586
SCOPE: one corrected finding (H-R2, product_detail_page.dart:614) + regression risk
DOCKER_COMMANDS_ISSUED: 0
PENPOT_ACCESS: none — no board verification claimed
```

**Verdict in one line:** the one-line correction is exactly right and I approve it; but the
correction leaves behind a **stale golden baseline that still renders the retired false claim and
now passes only on tolerance**, so the branch is not merge-ready until a lane that owns
`apps/control_plane/test/**` regenerates it.

---

## 1. Provenance — VERIFIED

```
$ git -C /private/tmp/shipit-fix-pd-custody rev-parse HEAD
878c3327aea383a2501fe7d698282b9dcc0bb586          ← matches reported NEW_HEAD exactly

$ git -C /private/tmp/shipit-fix-pd-custody rev-parse --abbrev-ref HEAD
fix/product-detail-custody-claim

$ git status --porcelain
(empty — clean tree, before and after my gates)

$ git log --oneline -n 4
878c332 fix(product-detail): correct the false key-custody claim in the Access block
43ede2e docs(qa): QA environment up and onboarding-ready; …          ← reported BASE
964b089 docs(state): F5 COMPLETE — 52/52 footers deleted; …
68ae58c docs(state): F5 copy half COMPLETE — …
```

- HEAD is `878c3327…`, exactly the reported `NEW_HEAD`. No drift.
- `43ede2e` is the **direct parent** of `878c332` — exactly one commit on the branch, so the
  reviewed correction is the whole of the delta.
- **Not pushed:** `git rev-parse --abbrev-ref @{u}` → `fatal: no upstream configured for branch
  'fix/product-detail-custody-claim'`. Positive proof, matches the report.
- **`main` untouched:** main is still `43ede2ec…`, identical to the base. No history rewritten.

## 2. Scope proof — reconstructed independently, not taken on trust

I rebuilt the pre-edit state from the base commit and diffed it myself rather than re-running the
implementer's commands.

```
$ git log --oneline 43ede2e..HEAD
878c332 fix(product-detail): correct the false key-custody claim in the Access block
                                  → exactly one commit, no drive-bys

$ git diff --name-status 43ede2e..HEAD
M	apps/control_plane/lib/features/product_detail/product_detail_page.dart
                                  → exactly one path, matching OWNED_PATHS

$ git diff --stat 43ede2e..HEAD
 …/features/product_detail/product_detail_page.dart | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

$ git diff -U0 43ede2e..HEAD | grep '^@@'
@@ -614 +614 @@ class _AccessBlock extends StatelessWidget {
                                  → differing lines = [614] exactly

line count @43ede2e : 1192
line count @878c332 : 1192        → identical, so in-place substitution, not delete-and-reinsert
```

The full diff is four context lines around one changed line:

```diff
@@ -611,7 +611,7 @@ class _AccessBlock extends StatelessWidget {
         ),
         const SizedBox(height: 4),
         Text(
-          'One key per repository. The private half never leaves this device.',
+          'One key per repository. The private half stays in the secret manager.',
           style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
         ),
         const SizedBox(height: 12),
```

Word-diff confirms the custody clause is the *only* thing that moved, and that the
**"One key per repository."** framing is byte-preserved:

```
-  'One key per repository. The private half [-never leaves this device.',-]
+  'One key per repository. The private half [+stays in the secret manager.',+]
```

Byte check of `:614` — plain ASCII, no escape sequence, no `·`, no smart quote, no trailing
whitespace (satisfies the dispatch's style constraint):

```
$ sed -n '614p' …/product_detail_page.dart | od -c | tail
…   s   e   c   r   e   t       m   a   n   a   g   e   r   .   '   ,  \n
```

**Nothing outside `OWNED_PATHS` was written.** PROHIBITED paths (`apps/server/**`, `packages/**`,
`docker/**`, `.github/**`, `.decisions/**`, `docs/adr/**`, `apps/control_plane/test/**`,
`lib/features/products/**`, `lib/shared/**`, `.claude/**`, `.junie/**`, `.opencode/**`) are absent
from the diff — the `docker/**` and `apps/server/**` absence is additionally confirmed by my own
`dart pub get` run leaving `git status` empty (§6).

## 3. Composition — both sentences independently verified

### 3a. First sentence is TRUE for this block — verified in source, not inferred

`product_detail_page.dart:597-641`, read directly:

```dart
/// Per-repository credentials. States what is true, including when nothing is.
class _AccessBlock extends StatelessWidget {
  …
  if (detail.repositories.isEmpty)
    … 'No repository is attributed to this product.' …
  else
    for (final repo in detail.repositories)
      _CredentialRow(
        repo: repo,
        credential: detail.credentials
            .where((c) => c.repositoryId == repo.repositoryId)
            .firstOrNull,
      ),
}
```

The block iterates **repositories**, and pairs each row with the credential selected by matching
`c.repositoryId == repo.repositoryId`. The unit shown is the repository, so **one key per
repository** is exactly what the block renders; there is no per-product roll-up. The dispatch's
warning was correct and the implementer heeded it: copying registry key **B** verbatim
(`One key, for this product only. …`) would have replaced one false claim with a different false
claim. Corroborated by ADR 0018 A1 (credentials keyed by `repositoryId`, `productId` retained for
ownership checks only) — the distinction the mobile review caught in G6.

### 3b. Second sentence is approved copy — byte-exact against the registry

`docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r3.md:294`, §5.3, key **B**:

```
| **B** | `One key, for this product only. The private half stays in the secret manager.` | `L Sub` ×2 |
```

Programmatic byte comparison of the shipped line's second sentence against key B's second sentence:

```
registry B len 77
clause B == new second sentence: True
```

So the custody sentence is **byte-identical to approved registry key B**, the authority the dispatch
named. It is also the vocabulary already shipping on the sibling screen the dispatch cited —
`add_product_page.dart:459-460` and `:957-958`:

```dart
'It clones over SSH. The private half stays in the secret manager '
'— never shown, logged or stored.',
```

**One correction to the implementer's report (§4c), non-blocking:** it states the clause is
"byte-identical to string **A** as shipped". It is not, on the terminal character. String A as
shipped continues ` — never shown, logged or stored.`, so `The private half stays in the secret
manager.` (with the full stop) is **not** a substring of A — verified:

```
clause in shipped A (no period):     True
clause + period in shipped A:        False
```

This does not affect the shipped value: the authority that matches byte-exactly is registry key
**B**, which is what the dispatch directed. The mis-statement is in the report's justification, not
in the code. Recorded so no later lane reasons from "byte-identical to A" and re-derives the wrong
string.

### 3c. Nothing false now ships

The removed sentence guaranteed a property the platform does not have. ADR 0018 (A2/A3 custody =
external secret manager; `:226` "Custody is an external secret manager (A3). SHIP IT holds a
reference, never key bytes.") confirms the private half is transmitted off-device. The replacement
is true, and it is strictly a reduction in an over-promise. I confirmed the old vocabulary is gone
from the client source:

```
$ grep -rniE "never leaves|stays on this device|created on this device|keychain" apps/control_plane/lib
(no output)
```

I also independently confirmed the implementer's disclosure that the dispatch's grep description was
loose: those four strings match only a broader `on this device` pattern, and with that broader
pattern the client returns **exactly four** hits and nothing else.

## 4. The four unrelated "this device" strings — untouched and still correct

Blob-level equality base → head (stronger than a line diff; proves no reformat, no reordering):

```
IDENTICAL apps/control_plane/lib/features/defect_report/defect_detail_page.dart
IDENTICAL apps/control_plane/lib/features/decision_detail/decision_detail_page.dart
IDENTICAL apps/control_plane/lib/shared/sidebar.dart
```

Still present, byte-for-byte, at the same lines:

```
defect_detail_page.dart:1087      'Saved as you, on this device',
decision_detail_page.dart:337     'Saved as you, on this device',
decision_detail_page.dart:436     'Saved as you, on this device',
shared/sidebar.dart:389           'Signed in on this device',
```

I read each in context. They are **session / decision-authorship** statements — "this decision was
saved under your identity on this device", "you are signed in on this device" — sitting in a session
rail or under a decision card. None asserts anything about key custody, so none is a false claim,
and none needed touching. The implementer correctly did **not** "fix" them. No collateral damage.

## 5. Tests — untouched, none weakened

```
$ git diff --name-only 43ede2e..HEAD -- apps/control_plane/test
(empty)

$ git diff 43ede2e..HEAD | grep -niE "skip|ignore|@TestOn|expected:|golden"
(empty)
```

No test file changed, so no test was added, modified, weakened, skipped, `@Ignore`d or deleted. No
comparator tolerance was altered (`test/helpers/golden_tolerance.dart` is untouched, threshold still
`0.005`). `flutter test` ran the full suite with no `-x`, no name filter and no tag filter, and
reached the same count as the stated baseline. This matches the established pattern for a
string-literal-only change in this work item.

## 6. Gates — re-run by me, verbatim

`dart pub get` at the **repository root** first, as required for a worktree (`.dart_tool` was
present; I ran it anyway as the sanctioned root-level command). The known `apps/server` churn did
**not** occur — `git status --porcelain` was empty immediately afterwards, confirming a PROHIBITED
path was not modified.

```
$ dart pub get                                        (repo root)
Got dependencies!
52 packages have newer versions incompatible with dependency constraints.
EXIT=0     → git status --porcelain afterwards: (empty)

$ dart format --output=none --set-exit-if-changed .   (repo root)
Formatted 631 files (0 changed) in 3.94 seconds.
EXIT=0     → git status --porcelain afterwards: (empty)

$ cd apps/control_plane && flutter analyze
No issues found! (ran in 9.9s)
EXIT=0

$ cd apps/control_plane && flutter test
…
01:05 +190: All tests passed!
EXIT=0
```

All four match their stated baselines exactly (`Got dependencies!`, `631 files (0 changed)`,
`No issues found!`, `+190: All tests passed!`). `make test-integration` not required and not run
(string literal, no data path). **Zero Docker/Compose commands** were issued in this review —
including `ps`, `logs`, `config` and `info`. The QA stack was not disturbed. Compose facts were
established by reading files as text.

---

## 7. Findings

### R1 — HIGH — REGRESSION, introduced by this correction: the Product Detail mobile golden baseline still renders the retired false claim, and now passes only on tolerance

`apps/control_plane/test/goldens/product_detail_mobile_back_link.png` (plus its `_dark` twin)
**paints the Access block at 390 px and still contains the retired sentence.** I opened the
committed PNG: the meta line under `Access` reads *"One key per repository. The private half never
leaves / this device."* — wrapped across two lines.

Evidence chain, all read-only:

- The golden PNG is **unchanged** by this branch: absent from the diff, absent from `git status`,
  and `git log` shows its last touch was the baseline commit `0d5d132` — i.e. it was generated while
  the source still said the old thing.
- The source string changed at `878c332`.
- Therefore the freshly rendered frame differs from the committed golden — the diff is certain, not
  hypothetical.
- `flutter test` still reported `Product detail · mobile back link to Products light` as **passed**
  (visible in the run log), so the difference was absorbed by the pre-existing tolerant comparator
  `useTolerantGoldens({threshold = 0.005})` in `test/helpers/golden_tolerance.dart` — a whole 12 px
  mono line re-wrapping across ~350 px lands comfortably inside 0.5 % of a 390×844 frame.

I did not measure the exact `diffPercent`: doing so requires tightening or instrumenting the
comparator, i.e. editing `apps/control_plane/test/**`, which is PROHIBITED to this review as well.
The deduction above does not depend on the number.

Consequences, in order of seriousness:

1. **The repo's only visual regression guard for Product Detail mobile no longer constrains this
   copy.** A future reintroduction of a false custody claim on this screen will also pass, silently,
   and keep passing — which is precisely the regression class this whole work item exists to
   eliminate. The implementer's own §11.3 `AUTOMATION_OPPORTUNITY` predicted this and could not fix
   it; this is that hole, realised.
2. **The committed baseline is now a false artefact.** A human golden reviewer — and the test's own
   docstring says this golden "is a CANDIDATE for human review" — is shown a security guarantee the
   application no longer makes, presented as current rendering.
3. **Latent platform fragility.** The pass depends on this machine's rasterisation staying under
   0.5 %. A different renderer, font or DPR can push the same diff past the threshold and fail the
   suite for a reason that has nothing to do with the change under test.

**Not attributable to the implementer, and not fixable by the correction lane.** The implementer was
forbidden from touching `apps/control_plane/test/**` and from adding or modifying any test; they
obeyed, and their report's claim "no test asserted the removed string" is literally true for Dart
test sources while missing that a binary golden renders it. Returning this correction to that lane
would instruct it to violate its own dispatch, so it is routed out instead.

**Actionable remediation (a lane owning `apps/control_plane/test/**`):** re-baseline the two
`product_detail_mobile_back_link*.png` goldens against `878c332` — `flutter test
--update-goldens test/product_detail_mobile_golden_test.dart` from `apps/control_plane` — and commit
the regenerated PNGs, ideally in the same change that lands this correction so no revision ever ships
with the two out of step. Then re-run `flutter test` with the normal comparator to confirm the
baseline is exact rather than merely tolerated. Do not "fix" this by raising the tolerance.

### F1 — MEDIUM — OPEN, design-authority gap: no board copy exists for Product Detail's `Access` block

Confirmed independently, and it is slightly sharper than the implementer stated. No approved registry
entry is scoped to `product_detail_page.dart:614`:

- `report-r3.md` §5.2/§5.3 scope `L Sub` to `BP · Product Credentials` (Product Credentials /
  Add Product boards). The `BP · Product Detail` frames that lane enumerated (rows 17, 18, 23, 24,
  32, 39, 40 — all 862×100, list-shaped) are Product Detail **list** boards; the key strings were
  read off Product Credentials boards, not a Product Detail `Access` block.
- The **only** thing that lane read from `product_detail_page.dart` is `:442-444`, the
  `TechnicalDetails(note:)` row (`report-r3.md:424`) — a different string on a different block,
  handled by a previous lane.

So what shipped is a **composition**: the pre-existing (true) first sentence plus key B's approved
custody clause. The custody sentence is approved vocabulary and is byte-exact; the *pairing* is
correct because I verified the per-repository rendering in source; but no board has seen the string
`One key per repository. The private half stays in the secret manager.` as a whole, and no board has
measured it at any breakpoint.

Severity assessment — **non-blocking, and correct as shipped**:

- It removes a false guarantee, which is a safety-positive direction; shipping a *true* string in
  place of a false one is the right trade even without fresh board confirmation.
- Every word of the replacement is either untouched-and-true or approved registry copy.
- Correctness is not in question: I verified both halves against source rather than against taste.

Residual, and it should be recorded rather than closed by this correction: the string is **3
characters longer** than the one it replaced (66 → 69 chars; the golden shows the old one wrapping to
two lines at 390 px, so the new one also wraps to two — no line-count change, no overflow risk since
it is a plain wrapping `Text` inside a padded `SingleChildScrollView` Column, `softWrap` defaulting
true). But *no board has sized it at this slot*, and the implementer's judgement not to extend it to
key A's fuller `— never shown, logged or stored` form (which would add ~30 more chars) is correct
and should stay recorded. Product Detail's copy needs a board owner; that is a design-lane task, not
a code defect.

### O1 — LOW, informational — report accuracy

Two disclosures in the implementer's report are imprecise but harmless, recorded so they are not
inherited:

1. §4c's "byte-identical to string **A** as shipped" — false on the terminal period (see §3b). The
   authority that matches byte-exactly is key **B**.
2. §5's `grep -rniE "never leaves|…"` scope claim — the implementer already self-disclosed this
   correctly: that pattern returns only `:614`, not the four session strings. I re-ran both the
   narrow and the broad pattern and confirm their account.

Neither changes the verdict. The implementer's report was otherwise unusually honest — it flagged
the design-authority gap against its own interest, disclosed the absence of board verification
rather than implying it, declined to extend the string on geometry grounds, and self-reported the
loose grep. That is the behaviour the correction loop depends on.

---

## 8. What I did not do

- Did **not** repeat the four-site custody review that already shipped as `c32f4f4`. I verified only
  that those files are blob-identical and that the four strings are still semantically correct.
- Did **not** claim any board verification — no Penpot access. The 4-board confirmation of key B is
  `report-r3.md`'s claim, which I read, not reproduced.
- Did **not** run `make test-integration` (not required) or any Docker/Compose command, including
  read-only ones.
- Did **not** edit any production, test or golden file. The only file written is this report.
- Did **not** re-review the wider F5 copy work item or `add_product_page.dart`; I read
  `add_product_page.dart` only to confirm the shipped custody vocabulary, and it is byte-identical
  to the base.

## 9. Next action for the Manager

The correction is approved. To make it mergeable, dispatch a narrow **golden re-baseline** task with
`OWNED_PATHS: apps/control_plane/test/goldens/product_detail_mobile_back_link.png,
product_detail_mobile_back_link_dark.png` and authority to regenerate them via
`flutter test --update-goldens test/product_detail_mobile_golden_test.dart`, requiring
`flutter analyze` + `flutter test` at the merged HEAD. Land it with `878c332`, or ahead of it — but
never leave the two out of step, which is exactly the state this branch is currently in. The
design-authority gap (F1) should be routed to a design lane as a standing item: Product Detail's
`Access` block has no board owner, and that is the root cause of H-R2 being routed to a lane that
could not touch it.

```
RESULT: APPROVE_CORRECTIONS

REVIEWED_HEAD: 878c3327aea383a2501fe7d698282b9dcc0bb586

FINDINGS_REVIEWED:
  H-R2 — product_detail_page.dart:614 false key-custody claim — RESOLVED, VERIFIED.
        Old: 'One key per repository. The private half never leaves this device.'
        New: 'One key per repository. The private half stays in the secret manager.'
        Diff vs 43ede2e is exactly one line (@@ -614 +614 @@), 1 file / 1 insertion /
        1 deletion; line count 1192 before and after; only OWNED_PATHS touched.
        First sentence verified TRUE in source (_AccessBlock iterates detail.repositories
        and pairs each with detail.credentials.where(repositoryId == repo.repositoryId)
        — per repository, not per product; ADR 0018 A1 agrees).
        Second sentence verified byte-identical to report-r3.md §5.3 key B.
        Pure ASCII, no escapes, no trailing whitespace.
        Zero matches remain for "never leaves|stays on this device|created on this
        device|keychain" over apps/control_plane/lib.
  Four unrelated "this device" strings (defect_detail_page.dart:1087,
    decision_detail_page.dart:337/:436, shared/sidebar.dart:389) — VERIFIED UNTOUCHED
    (blob-identical base→head) and still correct: session/decision authorship, not custody.
  Test integrity — VERIFIED: no test file changed; no test weakened, skipped, @Ignored
    or deleted; tolerance untouched; full suite run unfiltered.

REGRESSIONS:
  R1 (HIGH) — apps/control_plane/test/goldens/product_detail_mobile_back_link.png and its
     _dark twin still render the RETIRED false claim ("…never leaves this device.",
     wrapped, under the Access heading) at 390 px. The golden is unchanged by this branch
     and was last generated at 0d5d132, so the freshly rendered frame necessarily differs
     from the committed baseline — yet `flutter test` reports the golden as passing,
     because the pre-existing 0.005 tolerant comparator absorbs the re-wrapped line.
     Impact: the only visual guard on Product Detail mobile no longer constrains this
     copy, so a future false custody claim here would pass silently; and a human golden
     reviewer is shown a security guarantee the app no longer makes. Not the correction
     lane's fault or remit — apps/control_plane/test/** is PROHIBITED to it. Remediation:
     a lane owning that path regenerates the two goldens against 878c332 via
     `flutter test --update-goldens test/product_detail_mobile_golden_test.dart`, re-runs
     the suite with the normal comparator, and never widens the tolerance.
  F1 (MEDIUM, open, non-blocking) — design-authority gap, confirmed independently: no
     approved copy is scoped to product_detail_page.dart:614 and no board designs the
     Access block (report-r3.md scopes L Sub to BP · Product Credentials; its only read of
     product_detail_page.dart is :442-444, a different string). What shipped is a
     composition of the true original first sentence + key B's approved clause; both
     halves are correct and the change removes a false guarantee, so it is safe to ship,
     but the string as a whole is unboarded and +3 chars longer (66→69) with no board
     sizing at this slot. Product Detail copy needs a board owner.

BLOCKERS: none

READY_FOR_MERGE: NO
```

`READY_FOR_MERGE: NO` is not a verdict on the code — the one-line correction is correct and I
approve it. It is set because R1 is an open regression, and merging `878c332` would leave the
repository's only Product Detail visual baseline encoding copy this work item exists to retire.
Clear R1 via a golden re-baseline lane and this becomes YES with no further review of the string
itself.
