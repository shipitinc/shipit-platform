# Report — correct-client-generate-reachability

```yaml
RESULT: CORRECTION_COMPLETE
CORRECTED_FROM_HEAD: 2f6b78dfd721598b8ea60ae29ad70194c53a92e1
NEW_HEAD:            3f2805961865aa5d0b0ac3695a85792eda9bccbe
BRANCH:              impl/client-addproduct-keyflow   (worktree /private/tmp/shipit-client-keyflow)
PARENT_OF_NEW_HEAD:  2f6b78dfd721598b8ea60ae29ad70194c53a92e1  — reviewed history intact
PUSHED/MERGED:       no. Not pushed, not merged, main untouched.
```

---

## 1. Verification before writing

```
git branch --show-current  -> impl/client-addproduct-keyflow   MATCH
git rev-parse HEAD         -> 2f6b78dfd721598b8ea60ae29ad70194c53a92e1   MATCH
git status --porcelain     -> (empty)
```

Both matched. Nothing was written until after this.

---

## 2. The blocker, and what was actually wrong

The reported circularity was confirmed exactly as stated — and my cold-start
widget test, written before any production edit, found **a second defect on the
same path** that the dispatch did not mention.

### Defect A (reported): the flow is unreachable

```
deployKey SET          -> :159  only, inside _onCheckAccessRequested
_buildKeyBox called    -> :600, :1085  only under `if (state.deployKey != null)`
CheckAccessRequested   -> :723, :1300  only from inside _buildKeyBox
=> null key -> no key box -> nothing dispatches the event -> key never mints
```

### Defect B (found during this correction, same file, same cold path): a hard crash

`TechnicalDetails` guarded the fingerprint line and then dereferenced
`state.deployKey!` **in the condition of the next line**:

```dart
if (state.deployKey != null)
  'deployKeyFingerprint=${state.deployKey!.fingerprint}',
if (state.deployKey!.credentialId.isNotEmpty)     // <-- evaluated unconditionally
  'credentialId=${state.deployKey!.credentialId}',
```

With `deployKey == null` — the state the form *starts* in — this throws
`Null check operator used on a null value`. So the cold render did not merely
lack a control; **it crashed before rendering anything**, on both layouts
(`:496` desktop, `:1168` mobile). This had to be fixed for the acceptance
criterion ("from a cold empty state … surfaces a working control") to be
reachable at all, so it is in scope rather than scope creep.

---

## 3. Proof required #1 — the cold-start test FAILS at 2f6b78d, PASSES at HEAD

I wrote the widget tests first, then ran them against the **unmodified** reviewed
HEAD. Full logs: `FAIL-at-2f6b78d-final.txt`, `PASS-at-HEAD.txt`.

### At `2f6b78d` — all five fail (`+0 -5`, exit 1)

First failure, verbatim:

```
00:00 +0: the deploy-key flow is reachable from a cold empty state desktop:
nothing to press when cold, then one press mints a key and makes Copy public key reachable
══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═════════════════════════════════
The following _TypeError was thrown building _DesktopAddProduct(dirty, dependencies:
[InheritedCupertinoTheme, _InheritedTheme, _LocalizationsScope-[GlobalKey#d66c5]]):
Null check operator used on a null value

The relevant error-causing widget was:
  _DesktopAddProduct
  _DesktopAddProduct:.../add_product_page.dart:444:16

#0  _DesktopAddProduct.build (.../add_product_page.dart:496:36)
```

and the mobile twin, identically:

```
00:06 +2: ... mobile: nothing to press when cold, then one press mints a key
...
Null check operator used on a null value
...
00:06 -2: ... mobile: ... [E]
```

Final tally at `2f6b78d`:

```
00:07 +0 -5: Some tests failed.

Failing tests:
  ... desktop: nothing to press when cold, then one press mints a key and makes Copy public key reachable
  ... mobile:  nothing to press when cold, then one press mints a key and makes Copy public key reachable
  ... the generate control is not offered until both the product name and the repository are present ...
  ... canRegister, through the widget tree is shut while there is no key at all
  ... canRegister, through the widget tree is shut while a key exists but access is unproven ...
```

Isolation was done by `git stash push` on **only** the production file, so the
test file under test was byte-identical in both runs.

### At `3f28059` — all five pass (exit 0)

```
00:00 +0: loading .../add_product_keyflow_widget_test.dart
00:06 +1: ... desktop: nothing to press when cold, then one press mints a key and makes Copy public key reachable
00:08 +2: ... mobile:  nothing to press when cold, then one press mints a key and makes Copy public key reachable
00:09 +3: ... the generate control is not offered until both the product name and the repository are present ...
00:10 +4: ... canRegister, through the widget tree is shut while there is no key at all
00:12 +5: ... canRegister ... is shut while a key exists but access is unproven ...
00:16 +5: All tests passed!
```

---

## 4. Proof required #2 — `CheckAccessRequested` now dispatched from OUTSIDE `_buildKeyBox`

```
$ grep -n "CheckAccessRequested()" apps/control_plane/lib/features/products/add_product_page.dart
63:  const CheckAccessRequested();          <- the event's own declaration
734:                      const CheckAccessRequested(),      <- inside _buildKeyBox (desktop, :662)
979:                const CheckAccessRequested(),            <- inside _GenerateDeployKeyPanel  ** NEW **
1423:                            const CheckAccessRequested(), <- inside _buildKeyBox (mobile, :1352)

$ grep -n "_buildKeyBox" ...
609:          _buildKeyBox(context, state)
662:  Widget _buildKeyBox(BuildContext context, AddProductState state) {
1205:                    _buildKeyBox(context, state)
1352:  Widget _buildKeyBox(BuildContext context, AddProductState state) {

CheckAccessRequested dispatched INSIDE a _buildKeyBox:  [734, 1423]
CheckAccessRequested dispatched OUTSIDE any _buildKeyBox: [979]      (+63, the declaration)
```

`:979`, in `_GenerateDeployKeyPanel`:

```dart
if (ready)
  FilledButton(
    onPressed: () => context.read<AddProductBloc>().add(
      const CheckAccessRequested(),
    ),
    ...
    child: Text('Generate a deploy key', ...),
  )
```

The circular edge is broken at exactly the right place: it reuses
`CheckAccessRequested`, whose handler already calls `_ensureProductAndRepository`
**before** `_repository.generateDeployKey`. The test asserts that ordering
(`containsAllInOrder(['createProduct','addRepositoryReference','generateDeployKey'])`)
and the fake refuses a mint without them, as the engine does.

## 5. Proof required #3 — the mobile twin reaches it too

The panel is **declared once and rendered from both compositions**, so there is
no second copy that can be forgotten:

```
desktop  :606-611   if (state.deployKey != null) _buildKeyBox(context, state)
                    else _GenerateDeployKeyPanel(state: state),
mobile   :1202-1207 if (state.deployKey != null) _buildKeyBox(context, state)
                    else _GenerateDeployKeyPanel(state: state),
```

And the mobile reachability is asserted, not assumed — the desktop/mobile loop
runs the **identical** cold-start test at `390x844`, and the `Null check
operator` failure at `2f6b78d` appeared for mobile as its own case.

---

## 6. What was changed

Only `apps/control_plane/lib/**` and `apps/control_plane/test/**`. Two files.

**`apps/control_plane/lib/features/products/add_product_page.dart`** (+133/−10)

1. **New `_GenerateDeployKeyPanel`** — renders in the slot `_buildKeyBox`
   occupies when `deployKey == null`. Dispatches `CheckAccessRequested`.
   Gated on `state.canGenerateKey`, so an action that cannot succeed is *not
   offered*; while unavailable it names the missing input
   ("A product name is required first" / "A repository URL is required first"),
   in the same voice as `_registerButtonSubtext`.
   Reuses approved copy only: the existing `DEPLOY KEY · THIS PRODUCT ONLY`
   micro-label and the `ed25519 · generated on the server · the private half
   stays in the secret manager` line from the key box, and the exact string the
   Register subtext already promised. Step text and `_buildStepRow` untouched.
2. **Null-check crash fixed** in both layouts: one guarded local
   (`final deployKey = state.deployKey;`) replaces `state.deployKey!` in the
   condition of the `credentialId` line.

**`apps/control_plane/test/widgets/add_product_keyflow_widget_test.dart`** (new, 530 lines, 5 tests)

Explicitly **not** a copy of the bloc test's fake: this one renders cold and
counts taps; that one needs a call log. Sharing one would have meant editing
reviewed test code for no gain.

- **The point of the file** — zero direct `bloc.add` calls. Every state change
  comes from `enterText`/tap through the widget tree. The cold-start test
  asserts, in order: no control offered → `Product name is required` → fill both
  → control appears → tap → `deployKey != null` and the mint ordering held →
  public key on screen and `Copy public key` reachable → step 1 done →
  `accessStatus == verified`, `canRegister == true`.
- Mobile reachability via the same loop at `390x844`.
- Gating: not offered with nothing filled, and **not** offered with only the
  product name — the mint resolves the repository reference first.
- `canRegister` transitions: false with no key (and Register reads
  "Generate a deploy key first"); false with a key but unproven, with
  `verifyDeployKeyAccess` asserted **not** called without a host-key
  confirmation; true once `verifyAccess` succeeds (desktop + mobile).

---

## 7. Gates — verbatim, all at `3f28059`

| Gate | Command | Result |
|---|---|---|
| pub | `dart pub get` (repo root) | `Got dependencies!` |
| format | `dart format --output=none --set-exit-if-changed .` | exit 0 — `Formatted 658 files (0 changed)` |
| analyze | `cd apps/control_plane && flutter analyze` | **`No issues found!`** |
| tests | `cd apps/control_plane && flutter test` | **`+271: All tests passed!`** |

Baseline was `+266`. `+271` = 266 + the 5 added. **Real number reported: 271.**

`make test-integration` deliberately **not** run (client-side change).

### No test was weakened, skipped, ignored, filtered or deleted

`apps/control_plane/test/blocs/add_product_bloc_test.dart` is **byte-identical** —
it does not appear in `git status`. All 266 pre-existing tests still run and pass.
No `-x`, no skip flag, no `@Ignore`, no deleted case.

---

## 8. Constraints honoured

- `apps/server/**`, `packages/**`, `docker/**`, `.github/**`, `docs/adr/**`,
  `.decisions/**` — untouched. `git status` shows exactly two files.
- **No `serverpod generate`.** The client package at this branch is untouched.
- **Zero Docker/Compose commands were issued at all** — not mutating, not
  read-only, not `docker info`. The QA stack was not probed, started, or
  disturbed. Compose files were not read either; nothing in this change needed
  them.
- No `make clean` / `qa-down` / `test-env-down` / `e2e-down` / bare `down -v`.
- No push, no merge, `main` untouched. New commit on top of `2f6b78d`.

---

## 9. Parallel work

**SAFE_PARALLEL_WORK** (no path overlap with `apps/control_plane/lib/**` or
`apps/control_plane/test/**`)

- `impl/credential-key-service` (`4f96c78`) — server-side; owns
  `apps/server/**`. Unaffected by, and unaffected in turn: this change only
  calls the repository API that lane already wired.
- `fix/hostkey-config-wiring` (`437cdb6`) — its config keys read
  `readRuntimeConfigValue`. **Integrates AFTER this branch** (ordering
  constraint from the dispatch, preserved).
- Any server, package, docs, CI, or QA-stack work.

**PROHIBITED_PARALLEL_WORK** (concurrent write would overlap ownership)

- Any other writer touching `apps/control_plane/lib/**` — in particular any
  further edit to `add_product_page.dart`, `add_product_bloc_test.dart`, or
  `add_product_keyflow_widget_test.dart`.
- Any regeneration of `packages/control_plane_client/**` (`serverpod generate`).
- Anything that mutates the QA Docker stack — it is up and healthy on a stopgap
  run-mode override. Read compose as text; never start it.

---

## 10. Disclosures

**A second defect was found and fixed beyond the dispatched finding** (Defect B,
the null-check crash). It is disclosed prominently because it was not in the
brief. It sat on the same cold path and blocked the same acceptance criterion,
so fixing it was necessary rather than optional; it is 8 lines across two
layouts and is called out in the commit message.

**A harness trap is documented in the test file because it cost real time and is
indistinguishable from the bug being hunted.** A bloc constructed in `setUp`
runs outside the `testWidgets` `FakeAsync` zone; its event/listener plumbing stays
bound to that zone, so `bloc.state` advances while `BlocBuilder` never rebuilds.
The symptom is a page that looks frozen at its first render — `bloc.state` shows
both fields filled while the tree still renders the cold frame, including a stale
"A product name is required". I initially misread this as the product failing to
update and nearly wrote it up as a third defect. It is not: the same code renders
the generate control immediately when the bloc is created inside the test body.
The bloc is now created inside `pumpPage`, and the reason is written down at that
call site so it is not rediscovered as a product bug.

One unreachable defensive branch remains in `_generateBlockedReason` (its final
`return`), required for the `if`/`return` chain to be total. It is not dead code
in the sense of being wrong — it is the "cannot determine" default.

---

## 11. Repository learning (classified, not persisted unilaterally)

| Category | Finding |
|---|---|
| `PROJECT_FACT` | On `AddProductPage`, the deploy-key flow is reachable from a cold empty state on **both** layouts via one shared `_GenerateDeployKeyPanel`, gated on `canGenerateKey`, dispatching `CheckAccessRequested`. Persisted as executable knowledge: the 5 widget tests, which fail at `2f6b78d` and guard it. |
| `WORKFLOW_IMPROVEMENT` | A bloc built in `setUp` rather than inside the `testWidgets` body silently freezes every `BlocBuilder` in that test, and the output looks exactly like an unreachable-state bug. Worth a line in the framework's widget-test guidance; escalated to the Manager rather than written into product governance. |
| `AUTOMATION_OPPORTUNITY` | `UnimplementedRepositoryApis` (`apps/control_plane/test/helpers/`) has drifted behind `ControlPlaneRepository` — 13 members must be overridden by hand in every new fake. A generated or `noSuchMethod`-based stand-in would remove a recurring, silent compile-friction cost. Reported, not done: it is shared test-helper scope beyond this correction. |

No `ARCHITECTURE_DISCOVERY`, no `CONTRADICTION`, no governance change. Nothing
was persisted outside `apps/control_plane/`.

---

## 12. I cannot approve my own work

This is a correction, not a self-approval. The `2f6b78d`-fails / `3f28059`-passes
evidence above is what a **fresh focused reviewer** should independently re-run;
it is offered as evidence, not as a verdict.

```
READY_FOR_FOCUSED_REVIEW: YES
```

Focused re-review should cover: the new panel's placement and copy, the gating
decision (`canGenerateKey`, not merely `!= null`), the null-check fix in both
layouts, and the 5 new tests — in particular that they genuinely fail at
`2f6b78d`, since that is the property the whole correction rests on.