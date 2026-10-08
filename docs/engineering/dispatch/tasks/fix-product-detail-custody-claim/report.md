# Report — fix-product-detail-custody-claim

```yaml
RESULT: CORRECTION_COMPLETE
TASK_ID: fix-product-detail-custody-claim
TASK_TYPE: correct
AGENT: correction-implementer
WORKTREE: /private/tmp/shipit-fix-pd-custody
BRANCH: fix/product-detail-custody-claim
CORRECTED_FROM_HEAD: 43ede2ec362e0cc79e6a0b55f5994bc3651a5d72
NEW_HEAD: 878c3327aea383a2501fe7d698282b9dcc0bb586
FILES_CHANGED:
  - apps/control_plane/lib/features/product_detail/product_detail_page.dart  (1 line, :614)
READY_FOR_FOCUSED_REVIEW: YES
RECOMMENDED_NEXT_ACTION: FOCUSED_RE_REVIEW
PUSHED: NO
MERGED: NO
MAIN_TOUCHED: NO
```

---

## 1. Pre-flight verification (before any write)

```
$ git branch --show-current
fix/product-detail-custody-claim
$ git rev-parse HEAD
43ede2ec362e0cc79e6a0b55f5994bc3651a5d72
$ git status --porcelain
(clean)
```

Branch matched `fix/product-detail-custody-claim`, HEAD matched `43ede2e`, tree clean.
No BLOCKED condition. Proceeded.

---

## 2. Ownership

Declared exactly as dispatched; nothing outside `OWNED_PATHS` was written.

| Class | Paths | Honoured |
|---|---|---|
| OWNED | `apps/control_plane/lib/features/product_detail/product_detail_page.dart` | ✅ only file written |
| READ_ONLY | `add_product_page.dart`, `report-r3.md`, `design-revision-2.md`, `adr/0018-*.md`, `LANES.md` | ✅ read only, never written |
| PROHIBITED | `apps/server/**`, `packages/**`, `docker/**`, `.github/**`, `.decisions/**`, `docs/adr/**`, `apps/control_plane/test/**`, `lib/features/products/**`, `lib/shared/**`, `.claude/**`, `.junie/**`, `.opencode/**` | ✅ zero writes |

No concurrent writer holds the owned file, so there is no ownership overlap.

---

## 3. The correction

**One string literal, at `product_detail_page.dart:614`, inside `_AccessBlock`:**

```diff
@@ -611,7 +611,7 @@ class _AccessBlock extends StatelessWidget {
         const SizedBox(height: 4),
         Text(
-          'One key per repository. The private half never leaves this device.',
+          'One key per repository. The private half stays in the secret manager.',
           style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
         ),
         const SizedBox(height: 12),
```

I shipped **the exact target value given in the dispatch**, character for character.
**No IMPLEMENTATION_BLOCKED was warranted** — my independent checks support the Manager's
value rather than contradicting it (see §4).

---

## 4. Independent verification of the target value

I did not take the target on faith. Four checks, all read-only:

**(a) The claim really is false.** `docs/adr/0018-per-product-git-credentials.md`:

- `:4` — "A2 credential custody = external secret manager"
- `:226` — "**Custody is an external secret manager (A3). SHIP IT holds a reference, never key bytes.**"
- `:81` — "the private half is held by an **external secret manager**"

The private half is transmitted off-device and never persisted locally, so
*"never leaves this device"* is false. Finding confirmed.

**(b) The preserved first sentence really is true.** `ADR 0018` A1, `:40-51`:

- "is keyed by `repositoryId`; `productId` is retained for ownership checks only and is no
  longer the unit of scope"
- "a product simply shows one row per repository rather than one row overall"

This is corroborated directly in the owned file: `_AccessBlock` (`:628-634`) iterates
`detail.repositories` and pairs each with its own `detail.credentials` entry. So
*"One key per repository"* is the correct fact here, and key B's *"for this product only"*
would have been a **different false claim**. The dispatch's warning was right and I heeded it.

**(c) The custody clause is board-approved and already shipped.**
`docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r3.md:294`, key **B**:
`One key, for this product only. The private half stays in the secret manager.`
The custody clause `The private half stays in the secret manager.` is byte-identical to
string **A** as shipped in `add_product_page.dart:459-460` and `:957-958` (I read those —
`READ_ONLY`, unchanged):
```dart
'It clones over SSH. The private half stays in the secret manager '
'\u2014 never shown, logged or stored.',
```
The dispatch cites `:460`/`:958`; the literal actually begins on `:459`/`:957` because it is a
two-line concatenation. Immaterial — the clause is the same string. **I do not claim board
verification**: I have no Penpot access and verified nothing against a board. The 4-board
confirmation is `report-r3.md`'s claim, which I read rather than reproduced.

**(d) Style conformance.** The file uses plain single-quoted ASCII literals. The target
contains no apostrophe and no escape sequence; none was introduced. Confirmed byte-exact:

```
$ sed -n '614p' apps/control_plane/lib/features/product_detail/product_detail_page.dart | cat -et
          'One key per repository. The private half stays in the secret manager.',$
```
No `·`, no `\u00b7`, no smart quotes, no trailing whitespace.

### Design-authority gap — flagged, as instructed

The gap is real and I want it on the record rather than buried: **no board designs Product
Detail's `Access` block**, and the approved F5 registry has **no entry scoped to
`product_detail_page.dart:614`**. What I shipped is therefore a *composition* — the true
first sentence of `:614` plus key B's custody clause — not a verbatim board string.

I consider this within reach of existing approved copy for the specific reason that **half
the target string was already on this screen and true**. Half of it is board-blessed
(`report-r3.md:294`); the other half is the untouched original. The dispatch makes the call
that this minimal edit is authorised; I am not re-litigating it, but a focused reviewer
should confirm the composition itself, not merely the custody swap.

I deliberately did **not** extend key A (`— never shown, logged or stored`) onto this line.
That clause is true and board-approved, but adding it would change the string's length past
`L Sub`'s verified 596×30 geometry, which no board has sized for this slot. Out of scope for
a correction; if the Manager wants the fuller clause, that is a design decision requiring
board work, not a fix I should smuggle in here.

---

## 5. Scope proof — exactly one line

| Check | Expected | Actual | |
|---|---|---|---|
| Differing line numbers | `[614]` | `line 614 (old line 614)` | ✅ |
| Line count before | — | `1192` | |
| Line count after | identical | `1192` | ✅ |
| `git diff --stat` vs `43ede2e` | 1 file, 1 insert, 1 delete | `1 file changed, 1 insertion(+), 1 deletion(-)` | ✅ |
| `git status --porcelain` | exactly 1 entry | 1 entry | ✅ |

```
$ git diff -U0 -- <file> | grep '^@@'
@@ -614 +614 @@          → differing lines = [614]

$ git status --porcelain
 M apps/control_plane/lib/features/product_detail/product_detail_page.dart
   → 1 entry

$ git diff --stat 43ede2e
 apps/control_plane/lib/features/product_detail/product_detail_page.dart | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

File hashes, pre- and post-edit:

```
pre : 5dc9ee796d3c534f5c722463c96d91885945a722565801848bc7d2f83468e038
post: 8011e3e3acc55c07f75e3f92a0a68554554a716c2e7200d103e1d0cdb7298294
```

`1192 == 1192` and a single differing line prove the substitution was in-place, not a
delete-and-reinsert that could have shifted the rest of the file.

### Constraints — explicitly verified

**No test file touched.** `git status --porcelain` lists one entry, the source file. No test
added, changed, weakened, skipped, `@Ignore`d or deleted. Confirmed additionally:

```
$ grep -rn "never leaves" apps/control_plane/test
NONE — no test asserted the removed string
```
The suite never covered this literal, which is why a string-only change needs no test edit.

**The four unrelated "this device" strings left completely alone.** All four intact,
byte-identical, none staged, none touched:

```
apps/control_plane/lib/features/defect_report/defect_detail_page.dart:1087:  'Saved as you, on this device',
apps/control_plane/lib/features/decision_detail/decision_detail_page.dart:337: 'Saved as you, on this device',
apps/control_plane/lib/features/decision_detail/decision_detail_page.dart:436: 'Saved as you, on this device',
apps/control_plane/lib/shared/sidebar.dart:389:                            'Signed in on this device',
```
These describe session/decision authorship, not key custody. Not "fixed", not reformatted.

**Nothing else in the owned file.** `TechnicalDetails(note:)` at `:442` is byte-identical
(verified pre-edit; the single-line proof covers post-edit).

**H-R2 fully closed — this was the last one:**
```
$ grep -rniE "never leaves|stays on this device|created on this device|keychain" apps/control_plane/lib
NONE — last false key-custody claim in the client is gone
```

---

## 6. Gates — verbatim output

`dart pub get` was run at the **repository root** first, as required: the fresh worktree had
no `.dart_tool` (verified). Root-first ordering avoided the known spurious `apps/server`
churn — `git status --porcelain` was empty after it.

| Gate | Command | Baseline | Verbatim output line | |
|---|---|---|---|---|
| deps | `dart pub get` (repo root) | `Got dependencies!` | `Got dependencies!` | ✅ |
| format | `dart format --output=none --set-exit-if-changed .` | `631 files (0 changed)` | `Formatted 631 files (0 changed) in 5.21 seconds.` | ✅ |
| analyze | `cd apps/control_plane && flutter analyze` | `No issues found!` | `No issues found! (ran in 21.0s)` | ✅ |
| tests | `cd apps/control_plane && flutter test` | `+190: All tests passed!` | `+190: All tests passed!` | ✅ |

All four exit code `0`. Every one matches its stated baseline exactly — nothing was weakened,
skipped, filtered or suppressed to reach green. `flutter test` ran the full suite with no
`-x`, no name filter and no tag filter.

`make test-integration`: **not run**, and not required — string literal, no data path.
Per the dispatch it is out of scope.

---

## 7. Docker / Compose

**Zero Docker or Compose commands issued.** Not `ps`, `logs`, `config`, `info`, `up`, `down`,
or any other. No container, volume or compose project was created or touched. The QA stack
was not disturbed. Nothing to tear down — I started nothing.

I established the compose facts I needed (none were needed) by reading files as text, which
is the supported method. The one `AGENTS.md` risk I actively avoided was running
`dart pub get` inside `apps/server`; I ran it at the root only, and confirmed afterwards that
nothing under `apps/server` (PROHIBITED) was modified.

---

## 8. Commit

```
878c332 fix(product-detail): correct the false key-custody claim in the Access block
43ede2e docs(qa): QA environment up and onboarding-ready; ...   ← BASE, unchanged
```

Conventional commit, scope `product-detail`, matching the repo's existing style
(`37aadc5 fix(add-product): correct the false key-custody copy ...`). The body records what
was false, what replaced it, why the first sentence was deliberately preserved, and that no
test was touched.

Only the owned file was staged (`git diff --cached --stat` showed exactly one file; the
unstaged remainder was empty). Working tree clean afterwards.

**Not pushed, not merged, main untouched** — `main` still at `43ede2e`. The branch has **no
upstream configured** (`no upstream configured for branch 'fix/product-detail-custody-claim'`),
which is positive proof the branch was never pushed.

---

## 9. Parallel work

**SAFE_PARALLEL_WORK** — lanes that touch none of the paths above:

- Design lanes on `.decisions/**`, `docs/adr/**`, `docs/engineering/dispatch/**` (design
  revisions, decision objects, ADR amendments). I read `docs/adr/**` and
  `design-addproduct-mobile/**` read-only and hold no lock on them.
- `add_product_page.dart` / `lib/features/products/**` lanes (the four-site custody work at
  `c32f4f4` is complete; any new copy work there is disjoint from `:614`).
- `lib/features/{decision_detail,defect_report}/**` and `lib/shared/sidebar.dart` copy lanes —
  the four correct "this device" strings are untouched and available.
- Any `apps/server/**` or `packages/**` lane — I wrote nothing there and ran nothing that
  could have modified it.
- QA-contract and QA-execution lanes on **analysis and read-only** gates. ⚠️ Not on
  integration tests: any lane running `make test-integration` creates Docker resources, and
  per `AGENTS.md` only that target is sanctioned for DB work. It remains the one action in
  this worktree that mutates shared Docker state.

**PROHIBITED_PARALLEL_WORK** — anything overlapping my commit:

- Any edit, reformat or "drive-by" fix to
  `apps/control_plane/lib/features/product_detail/product_detail_page.dart`. My commit is a
  clean 1-line/1-file diff; any other change to that file breaks the scope proof and the
  focused review. `dart format` on the tree is safe only because the file is already
  format-clean (`631 files (0 changed)`).
- Any lane rewriting the `:614` custody clause with different wording. The value is
  board-approved registry copy (key B's clause) and is now verified by two shipped sites;
  changing it again re-opens H-R2.
- Extending the line to key A's full form (`— never shown, logged or stored`) without board
  sizing for this slot — see §4.
- Merging `fix/product-detail-custody-claim` to `main`, or pushing it, before a focused
  re-review clears it.
- Any write to `docs/adr/**` or `.decisions/**` that would retroactively change the A1/A3
  scope facts this edit's framing rests on (§4a, §4b).

---

## 10. Disclosures

- **No gate was weakened.** No test added, changed, weakened, skipped or deleted; no filter or
  exclusion flag on any gate.
- **No board verification performed.** I hold no Penpot access and verified nothing against a
  board. The 4-board confirmation of key B's clause is `report-r3.md`'s claim, which I read.
- **A design-authority gap exists and is not resolved by this commit** (§4). The value shipped
  is the dispatch's exact target; my checks support it but do not close the gap, which is that
  no board has ever scoped copy to this slot.
- **Line-number citation drift.** The dispatch cites `add_product_page.dart:460`/`:958`; the
  literals begin at `:459`/`:957`. Same strings; immaterial to the correction.
- **The dispatch's `grep` description was slightly loose.** `grep -rniE "never leaves|stays on
  this device|created on this device|keychain"` over `lib` returns **only** `:614` — the four
  unrelated strings (`Signed in on this device`, `Saved as you, on this device`) match a
  broader `this device` pattern, not that pattern set. Either way the conclusion holds and all
  four were left alone.
- **No Docker breach to disclose.** Zero Docker commands issued this session.
- **I cannot approve this work.** Ready for a fresh independent `focused-reviewer`.

---

## 11. New discoveries

Classified per `aef-repository-learning`. Authority-checked: I am reporting, not persisting.

1. **`PROJECT_FACT`** — The false key-custody sweep (H-R1/H-R2) is now **closed across
   `apps/control_plane/lib`**: zero matches for
   `never leaves|stays on this device|created on this device|keychain` remain. The four
   surviving "this device" strings are session/decision authorship, not custody, and are
   correct as written. Evidence: `878c332`, grep output in §5.
2. **`PROJECT_FACT`** — ADR 0018 **A1** is the authority for the per-repository framing that
   survives at `:614`: credentials are keyed by `repositoryId`, `productId` is ownership-only.
   Any future copy on this block must say *per repository*, not *per product*. This is the
   distinction the mobile review caught in G6 and the one most likely to be re-broken.
3. **`AUTOMATION_OPPORTUNITY`** (report only — above my authority) — Both false claims in this
   work item were found by **ad-hoc grep and human review, not by a gate**, and one of them
   (H-R2) survived a four-site fix purely because it sat outside the fixing lane's ownership.
   A repo-wide guard test asserting the custody vocabulary — the absence of
   `never leaves this device` / `keychain` in `lib`, plus a positive check that the approved
   clause is present — would make this class of regression mechanically impossible and would
   have caught H-R2 at `c32f4f4`. Route to independent review; I did not add it, since it
   means writing to `apps/control_plane/test/**`, which is PROHIBITED to this lane.
4. **`CONTRADICTION`** (escalate — governance) — **`AGENTS.md` §13 was restored on 2026-10-06
   by human authorization**, but `docs/engineering/dispatch/LANES.md` and
   `WORK_STATE.md`, which I was told the Manager holds, may still predate that restoration and
   describe §13 as absent. Three ADRs (0012, 0018, 0019) cite §13 text. I did not read those
   Manager-owned files to check, and did not modify them. Flagging so the Manager can
   reconcile; out of my ownership.
5. **`WORKFLOW_IMPROVEMENT`** (report only) — When a finding is routed to a lane as
   PROHIBITED-to-that-lane, record it in a queue that survives the session. H-R2 was raised in
   `design-revision-2.md`, marked "outside this lane's files", and then not picked up for
   multiple rounds — it survived precisely because it was correctly declined by a lane and the
   handoff had no owner. Cross-lane rejected findings need the same tracking as accepted ones.
6. **`RUNTIME_DISCOVERY`** — A fresh git worktree of this repo has **no `.dart_tool/`**;
   `dart pub get` must run at the **repository root** before any `dart format` gate, and
   running it in a subpackage (`apps/server`) produces spurious diffs under PROHIBITED paths.
   Root-first is verified safe here: `git status --porcelain` was empty afterwards.

---

## 12. Final result

```
RESULT: CORRECTION_COMPLETE

CORRECTED_FROM_HEAD: 43ede2ec362e0cc79e6a0b55f5994bc3651a5d72
NEW_HEAD: 878c3327aea383a2501fe7d698282b9dcc0bb586

FINDINGS_ADDRESSED:
  H-R2 — product_detail_page.dart:614 false key-custody claim
         "The private half never leaves this device."
         → custody clause replaced with the board-approved registry form
           (report-r3.md §5.3 key B): "The private half stays in the secret manager."
         First sentence "One key per repository." preserved — it is true per ADR 0018 A1.
         Shipped exactly the dispatch's target value; no value invented.

FILES_CHANGED:
  apps/control_plane/lib/features/product_detail/product_detail_page.dart   (:614, 1 line)

GATES:
format=pass   (Formatted 631 files (0 changed) in 5.21 seconds.)
analyze=pass  (No issues found! (ran in 21.0s))
tests=pass    (+190: All tests passed!)
build=not-applicable   (string literal; no build step in this repo's required gates)
runtime=not-required    (no behavior change; no user-interaction or data path)
deps=pass     (Got dependencies!)  [dart pub get at repo root, before format]

NEW_DISCOVERIES: 6 classified (§11) — 3 PROJECT_FACT, 1 RUNTIME_DISCOVERY,
  1 AUTOMATION_OPPORTUNITY, 1 CONTRADICTION (escalate), 1 WORKFLOW_IMPROVEMENT.
  None persisted: items 1/2 are product facts recorded here for the Manager to route;
  item 3 would require writing to a PROHIBITED path; item 4 touches Manager-owned
  governance files. No governance or unrelated change made as a side effect.

READY_FOR_FOCUSED_REVIEW: YES
```

**Not pushed. Not merged. `main` untouched at `43ede2e`. Zero Docker commands.**
I cannot approve my own work — this requires a fresh independent `focused-reviewer`.