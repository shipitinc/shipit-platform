# Focused re-review — correct-client-generate-reachability

```
RESULT: APPROVE_CORRECTIONS

REVIEWED_HEAD: 3f2805961865aa5d0b0ac3695a85792eda9bccbe
WORKTREE:      /private/tmp/shipit-client-keyflow  (branch impl/client-addproduct-keyflow)
REVIEWER:      focused-reviewer (read-only; no production file was edited)
```

---

## 0. Provenance — verified, not assumed

```
git rev-parse HEAD            -> 3f2805961865aa5d0b0ac3695a85792eda9bccbe   MATCH NEW_HEAD
git log %H %P -n 2            -> 3f28059... parent 2f6b78dfd721598b8ea60ae29ad70194c53a92e1   MATCH CORRECTED_FROM_HEAD
git branch --show-current     -> impl/client-addproduct-keyflow                 MATCH
git status --porcelain        -> (empty)                                          pristine
git diff 2f6b78d..HEAD --stat  -> 2 files, +663 / -10
git diff --name-only 2f6b78d..HEAD
    apps/control_plane/lib/features/products/add_product_page.dart
    apps/control_plane/test/widgets/add_product_keyflow_widget_test.dart
git diff --diff-filter=D 2f6b78d..HEAD -> (empty)                                  nothing deleted
```

Reviewed history is intact: `3f28059` is a single commit directly on top of the accepted
`2f6b78d`. No rewrite, no force, no stray file. Scope is exactly the two declared paths.

All experiments that mutate files were run in a throwaway clone at
`<tmp>/opencode/rr-clone` (`git clone --no-hardlinks` of the worktree). Its two changed files
were confirmed byte-identical to the reviewed worktree before any gate was run
(`add_product_page.dart` md5 `2759875260d48b66e099954148e859bd`,
`add_product_keyflow_widget_test.dart` md5 `0d230946e450fda769377de6c9bc370a`). The reviewed
worktree was re-checked at the end: still `git status --porcelain` empty.

---

## 1. REACHABILITY IS ACTUALLY FIXED, AT THE WIDGET LEVEL — CONFIRMED

I did **not** accept the lane's tests as proof. I wrote my own probe in the clone, structurally
independent of the lane's assertions: it never looks for the string "Generate a deploy key". It
counts `FilledButton`s with a non-null `onPressed`, taps *that*, and checks what the mint did.

Probe result at `3f28059`, both viewports:

```
desktop-1280x1400: cold render -> fill -> ONE pressable control mints      +1
mobile-390x844:   cold render -> fill -> ONE pressable control mints      +2  All tests passed!
```

The probe asserts, in order:
1. cold render does not throw, and `pressable == 0` — no action is offered before inputs exist;
2. both fields filled through `enterText` (the only state-change channel);
3. `pressable == 1` **exactly** — a new action became available;
4. tapping it sets `bloc.state.deployKey != null` — a real key, minted via
   `repository.generateDeployKey`;
5. `find.textContaining('ssh-ed25519')` finds the minted public key on screen;
6. `accessStatus == verified` and `canRegister == true`.

Step 6 matters for the "no bypass" requirement: the Register gate does not open because a key
exists, it opens because the *verification* ran and returned verified. That is the whole point of
minting and verifying living behind one press.

The probe was deleted afterwards; the clone is clean at `3f28059`.

**Verdict: the feature is reachable from a genuinely cold empty state on both layouts, and the
control that makes it reachable is the control that performs the mint.** No dead affordance.

---

## 2. THE PROOF IS LOAD-BEARING — REPRODUCED, AND PROVED STRONGER THAN CLAIMED

### 2a. The claimed reproduction, repeated independently

Clone at `3f28059`, test file untouched, production file reverted to `2f6b78d` only:

```
flutter test test/widgets/add_product_keyflow_widget_test.dart
EXIT=1
00:00 +0 -5: Some tests failed.
```

Both crashes reproduced verbatim, with the same frames the report quotes:

```
Null check operator used on a null value
  _DesktopAddProduct: .../add_product_page.dart:444:16
#0  _DesktopAddProduct.build (package:control_plane/features/products/add_product_page.dart:496:36)

Null check operator used on a null value
  _MobileAddProduct: .../add_product_page.dart:441:18
#0  _MobileAddProduct.build (package:control_plane/features/products/add_product_page.dart:1168:42)
```

Desktop `:496:36` and mobile `:1168` both match the report. Then, at `3f28059`, same test file:

```
EXIT=0
00:01 +5: All tests passed!
```

### 2b. The check the lane did NOT do — and the one that actually matters

The `+0 -5` at `2f6b78d` is **satisfiable by the crash alone**. If the five tests only proved
"the page throws", they would prove nothing about reachability, and a reviewer could not tell
whether the tests would still catch a build where the crash is fixed but the flow stays
unreachable. Given that this is the second time in this work item a green suite hid an
unreachable feature, I constructed that exact build and re-ran.

**Variant built**: `2f6b78d`'s production file, with *only* the two null-check restructures
applied to both `TechnicalDetails` blocks and nothing else. No panel. The diff is precisely the
guard local + the `...[]` spread, and nothing else.

```
rg 'deployKey!' variant  ->  236, 655, 1235   (the same three call-site-guarded sites as HEAD)
git diff vs 2f6b78d      ->  ONLY the two null-check hunks; no _GenerateDeployKeyPanel

flutter test .../add_product_keyflow_widget_test.dart
EXIT=1
00:01 +1 -4: Some tests failed.
grep -c "Null check operator" -> 0        <-- ZERO crashes
```

Zero crashes, and 4 of 5 still fail — with the precise, human-meaningful message:

```
Expected: exactly one matching candidate
  Actual: _AncestorWidgetFinder:<Found 0 widgets with type "FilledButton" that are
  ancestors of widgets with text "Generate a deploy key": []>
with a product name and a repository the mint can succeed, so it must be offered on the
desktop layout
```

and the mobile twin at `390x844`, identical.

The fifth test ("is shut while there is no key at all") passes in that variant, which is correct
and expected: it is a *negative* gate assertion (`canRegister == false` + subtext
"Generate a deploy key first"), and that is true precisely when the flow is broken. It is not
claiming reachability.

My own independent probe was then re-run against the same variant and failed with the right
reason and no crash:

```
Expected: <1>
  Actual: <0>
exactly one action becomes available once inputs are in
```

**Verdict: the five tests detect the reachability defect independently of the crash defect. The
proof is genuinely load-bearing, not incidentally satisfied by a null-check crash.** The one test
that passes on the broken build is the one that is supposed to.

---

## 3. THE NULL-CHECK CRASH — a genuine null-safe restructure, not a `!` moved

Both layouts now read one guarded local and use it in **both** lines:

```dart
final deployKey = state.deployKey;          // :458 desktop, :1132 mobile
...
if (deployKey != null) ...[
  'deployKeyFingerprint=${deployKey.fingerprint}',
  if (deployKey.credentialId.isNotEmpty)
    'credentialId=${deployKey.credentialId}',
],
```

This is the correct shape: the null test and the dereference are now driven by the *same*
immutable local, so they cannot disagree. Nothing was pushed into a later `else`, nothing was
suppressed, and no `!` was relocated. `dart analyze` is clean.

**Whole-file sweep for remaining unguarded `deployKey!`:**

| line | site | guarded by |
|---|---|---|
| 236 | `_onRegisterProductRequested` → `state.deployKey!.credentialId` | `if (!state.canRegister) return;` at :222, and `canRegister` (`:387`) begins with `deployKey != null` |
| 664 | `_buildKeyBox` desktop | only invoked at :609, under `if (state.deployKey != null)` at :608 |
| 1354 | `_buildKeyBox` mobile | only invoked at :1205, under `if (state.deployKey != null)` at :1204 |

All three are guarded at the call site by the very predicate they depend on. There is **no**
unguarded `state.deployKey!` anywhere in the file, and the general sweep for `state.<field>!`
found only other pre-existing, correctly guarded sites (`:29`, `:433`, `:765`, `:1452`).

---

## 4. MOBILE PARITY — both call sites real, and 390x844 genuinely exercised

```
 611:          _GenerateDeployKeyPanel(state: state),      <-- desktop composition
 945: class _GenerateDeployKeyPanel extends StatelessWidget {
 946:   const _GenerateDeployKeyPanel({required this.state});
1207:                    _GenerateDeployKeyPanel(state: state),   <-- mobile composition
```

Declared **once** at :945, rendered at **two** call sites — exactly as claimed. There is no second
copy that can be forgotten; the structural guarantee is real, not just an assertion.

The mobile test is not merely declared, it is genuinely executed at `390x844`:

- `kMobileSize = Size(390, 844)` and `pumpPage` sets `physicalSize = size` with
  `devicePixelRatio = 1.0`, so the logical viewport really is 390x844;
- the desktop/mobile loop runs the *identical* cold-start test body;
- **independent proof the mobile composition is really being built**: at `2f6b78d` the run
  produced a *separate* mobile failure whose frame is `_MobileAddProduct.build … :1168:42`. A test
  that silently fell back to the desktop layout could not produce that stack;
- my own probe ran the mobile case at 390x844 and passed.

`ShipItMetrics.mobileBreakpoint` is 840; 390 is below it, 1280 is above. Both branches taken.

---

## 5. NO WEAKENING — gate, copy and step text all verified untouched

### The gate

Lines 365-395 (covering `canGenerateKey`, `canCheckAccess` and `canRegister`) are **byte-identical**
between `2f6b78d` and `HEAD` — verified by diff, not by reading alone:

```dart
bool get canGenerateKey =>
    productName.isNotEmpty && repository.isNotEmpty && !isCheckingAccess;

bool get canRegister =>
    deployKey != null &&
    accessStatus == AccessStatus.verified &&
    !isRegistering;
```

The Register buttons are untouched at :857 (desktop) and :1262 (mobile):
`onPressed: state.canRegister && !state.isRegistering ? ... : null`.

**The panel is not a bypass, and it cannot become one**, for two independent reasons:

1. the panel renders its button only under `state.canGenerateKey`, which requires a product name
   and a repository — the panel *adds* a prerequisite, it removes none;
2. it dispatches the *existing* `CheckAccessRequested`, whose handler opens with
   `if (!state.canGenerateKey) return;` (`:123`). Even a forged event cannot mint through a
   blocked gate, and minting still sets `accessStatus: AccessStatus.notChecked`, not `verified`.

`verified` is written in exactly one place — the `verifyAccess` result — and reaching it still
requires an operator-supplied host-key fingerprint and a real server-side clone. The new test
asserts the middle state explicitly: with no attestation, `verifyDeployKeyAccess` is **not called**
and `canRegister` stays false.

### Copy and step text

- Micro-label `'DEPLOY KEY  ·  THIS PRODUCT ONLY'` — identical at :699 (desktop key box), :960
  (panel), :1386 (mobile key box).
- `'ed25519 · generated on the server · the private half stays in the secret manager'` —
  identical at :709, :972, :1396.
- `'Generate a deploy key'` (:990) is the exact affordance the Register subtext already promised
  at :908 (`'Generate a deploy key first'`). The promise now has something behind it, which is
  precisely what was missing.
- New strings introduced by the panel (a heading, a progress label, two "missing input" reasons)
  are additive UI copy in the voice of `_registerButtonSubtext`. No approved string was edited.
- `_StepText` and `_buildStepRow`: the four step rows are **byte-identical**, in both layouts.
  Diffed with line numbers stripped — only the line offsets moved (+133 insertions before them).
- `_statusLabel`, `_buildKeyBox`, `_copyToClipboard`, the attestation surface: untouched.

---

## 6. GATES — re-run by me at the corrected HEAD

Run in the throwaway clone on source byte-identical to the reviewed worktree.

| Gate | Command | Result |
|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | **exit 0** — `Formatted 658 files (0 changed)` |
| analyze | `cd apps/control_plane && flutter analyze` | **exit 0** — `No issues found!` |
| tests | `cd apps/control_plane && flutter test` | **exit 0** — `+271: All tests passed!` |
| baseline | same suite at `2f6b78d` | **exit 0** — `+266: All tests passed!` |

`266 + 5 = 271`. The baseline is confirmed by measurement, not accepted on trust.

### Nothing weakened, skipped, ignored, filtered or deleted

- `git diff --diff-filter=D 2f6b78d..HEAD` → empty. No test deleted.
- `rg '@Ignore|@Skip|skip:|skip =|Tags\(|excludeTags|testOn' apps/control_plane/test` → **zero
  matches across the whole suite**, not just the new file.
- `add_product_bloc_test.dart` does not appear in `git status` or the diff — **byte-identical**.
  The 266 pre-existing tests all ran and all passed.
- The new test file makes **zero direct `bloc.add` calls** (verified by reading the whole file):
  every state change arrives through `enterText` / `tap` on the widget tree. That is what makes
  the suite able to catch an unreachable UI at all, and it is why this correction does not repeat
  the failure mode of the one before it.

### Docker

**Zero Docker or Compose commands were issued by this review** — not mutating, not read-only, not
`docker info`, not `docker compose ps`. Per the shared-Docker rule in `AGENTS.md`, read-only
Docker commands are not granted either. The QA stack was not probed, started, or disturbed, and
its stopgap run-mode override is untouched. No `serverpod generate` was run; the client package
under `packages/control_plane_client/**` is byte-identical to `2f6b78d`.

---

## 7. FINDINGS (all non-blocking; none invalidate the correction)

### F1 — MEDIUM, documentation accuracy. The `setUp` warning is stated as a universal rule; it is not one.

`add_product_keyflow_widget_test.dart:318-331` asserts:

> "A bloc constructed in `setUp` — which runs outside that zone — keeps its event and listener
> plumbing bound to the zone it was born in, so `bloc.state` advances while `BlocBuilder` never
> gets a frame to rebuild for."

I reproduced **the symptom** exactly, on the real page:

| build site | `pressable` after fill | tree |
|---|---|---|
| `AddProductBloc` in `setUp` | **0** | frozen |
| `AddProductBloc` in the test body | **1** | correct |

and it is not a `pumpAndSettle` artefact — two bare `pump()`s do not recover it either.

But I could **not** reproduce the freeze for a bloc that does *not* use `on<Event>` transformers:

| case | tree after state change |
|---|---|
| plain `Cubit`, synchronous `emit`, bloc built in `setUp` | rebuilt correctly |
| plain `Cubit`, **async** handler with `Future.delayed`, bloc built in `setUp` | rebuilt correctly |
| `AddProductBloc` (`on<E>` + default event transformer), built in `setUp` | **frozen** |

So the freeze is real and the advice is correct — **build the bloc inside the test body** — but the
stated scope ("silently freezes *every* `BlocBuilder` in that test") is broader than the evidence
supports. The differentiator appears to be bloc's `on<Event>` transformer pipeline, which is where
the zone-bound microtasks actually live, not bloc construction in general.

This does not weaken anything: the five tests are proven load-bearing by §2b, and they build the
bloc in the body, which is the correct practice either way. It is a comment that will be read as
settled fact by the next lane.

**Actionable**: narrow the comment to what was actually observed, e.g. "a bloc that uses
`on<Event>` transformers and is constructed outside the `testWidgets` zone can emit state the tree
never sees", and drop "every `BlocBuilder` in that test".

### F2 — LOW. The escalation proposed in report §11 would propagate an unproven rule as framework guidance.

The report classifies this as a `WORKFLOW_IMPROVEMENT` "worth a line in the framework's
widget-test guidance". Per F1, the current wording should not be propagated. If the Manager still
escalates it, escalate the *practice* (build blocs inside `testWidgets` bodies), not the stated
mechanism.

### F3 — LOW, wording. The `UnimplementedRepositoryApis` drift is not "silent", and the count is 14 not 13.

The report calls the drift "a recurring, silent compile-friction cost". It cannot be silent:
`FakeRepositoryProbe` declares `implements ControlPlaneRepository`, so the moment
`ControlPlaneRepository` gains a member, `flutter analyze` fails at compile time. It is
ergonomics, not a correctness hazard — which is the correct classification, and the report reaches
it ("reported, not done"). The new fake hand-writes **14** overrides
(`getOverview`, `listProductSummaries`, `listWorkItems`, `pendingDecisions`, `inspectWorkItem`,
`inspectDecision`, `jobsForWorkItem`, `recentDecisions`, `requestLifecycleDecision`,
`resolveLifecycleDecision`, `requestPolicyAuthorisation`, `resolvePolicyAuthorisation`,
`revokeStandingPolicy`, `resolveDecision`), not 13.

**Assessment: does not matter for this correction.** It is pre-existing shared-helper scope,
correctly left alone, and correctly classified as a follow-up.

### Scope of the harness hazard in THIS repo — assessed, and the answer is: no victims.

I parsed every `setUp`/`setUpAll` block under `apps/control_plane/test` and matched brace
depth to find blocks that construct a bloc. Exactly one exists:

```
apps/control_plane/test/blocs/add_product_bloc_test.dart:420
    setUp(() { repository = _FakeRepository(); bloc = newBloc(); });
```

That file contains **no `testWidgets` at all** (verified: `rg -c testWidgets` → no match), so
there is no widget tree in it to freeze. Every other widget test in the repo — including the 10
files that build blocs — constructs them **inside** the test body or a helper called from it.

**Therefore the 266-test baseline could not have been silently weakened by this hazard**, and no
follow-up lane is warranted inside this repository. The lane's own choice (build the bloc in
`pumpPage`, called from the test body) is already the only safe pattern in the tree.

---

## 8. REGRESSION CHECK — the correction's blast radius

| Area touched by the correction | Risk assessed | Outcome |
|---|---|---|
| `TechnicalDetails` restructure (2 layouts) | changes what the debug panel prints for a null key | **None.** Previously it threw; now it prints `accessStatus` only. Strictly more correct. |
| Left/lower column `if/else` (2 layouts) | could displace `_buildKeyBox` once a key exists | **None.** `_buildKeyBox` still renders on exactly the same condition (`state.deployKey != null`) — the `else` is additive. |
| New `_GenerateDeployKeyPanel` | new widget, no existing consumer to break | **None.** Private class, single declaration, both call sites verified. |
| New `CheckAccessRequested` dispatch site | a second path into a handler that already guards itself | **None.** Handler still returns early unless `canGenerateKey`. |
| New test file | adds a fake that could drift from the interface | **None.** It compiles and analyzes clean; interface drift would be loud, not silent (F3). |
| Previously-approved areas (`2f6b78d` and earlier) | correction re-touched `add_product_page.dart` | **None found.** The diff is confined to the null-check guard, the two `if/else` slots, and the new class. Gates, gates, and step text byte-stable. |

The one regression risk worth naming — that fixing the crash could have *masked* the reachability
defect — was tested directly and did not materialise (§2b).

---

## 9. Bottom line

The defect as dispatched is real, the fix is correct, and — the part that matters most in this
work item — **it is guarded by tests that actually fail on the broken build, for the right reason,
independently of the second defect that was found alongside it.** I confirmed that with a
third line of evidence the lane did not produce: a build with the crash fixed and the flow still
unreachable, which the suite catches cleanly.

The gate is not weakened. Mobile parity is structural, not asserted. The two extra findings are
documentation-accuracy items in a test comment and a report's framing — neither touches the
product behaviour, and neither is a reason to hold the branch.

**The one thing the Manager should not let propagate unedited**: the universal-sounding
`setUp`-bloc rule (F1/F2). It is correct advice attached to an overstated mechanism, and it is
now written into a shipped test file as if it were settled.

---

```
RESULT: APPROVE_CORRECTIONS

REVIEWED_HEAD: 3f2805961865aa5d0b0ac3695a85792eda9bccbe

FINDINGS_REVIEWED:
  1. Reachability from a cold empty state, widget level, BOTH layouts ......... RESOLVED
     (independent label-free probe: 0 pressable when cold -> 1 after fill -> tap
      -> real key minted -> public key on screen -> verified -> canRegister)
  2. The 5 new tests fail at 2f6b78d and pass at 3f28059 .................... RESOLVED
     (reproduced: +0 -5 / exit 1, Null check at :496:36 desktop and :1168:42 mobile;
      AND 4/5 still fail with ZERO crashes when the crash is fixed but the panel is
      removed -> the tests catch the REACHABILITY defect, not merely the crash)
  3. state.deployKey! dereferenced in the credentialId condition .............. RESOLVED
     (genuine null-safe restructure: one guarded local drives the null test AND both
      dereferences; whole-file sweep finds 3 remaining `deployKey!`, all guarded at
      the call site by the predicate they depend on)
  4. Mobile parity: panel declared once, both call sites real, 390x844 ....... RESOLVED
     (611 + 1207 render one class declared at 945; mobile stack frame at :1168:42
      at the broken build proves the mobile composition is really built)
  5. No weakening of canRegister; approved copy and step text untouched ....... RESOLVED
     (gate block byte-identical; handler still returns early unless canGenerateKey;
      canRegister opens only on verified, never on key presence)

REGRESSIONS: NONE
  - Correction confined to the null-check guard, two additive if/else slots and one
    new private class; _buildKeyBox's render condition is unchanged.
  - Gates re-run independently at HEAD: format exit 0 (658 files, 0 changed),
    analyze "No issues found!", tests +271; baseline at 2f6b78d measured at +266.
  - add_product_bloc_test.dart byte-identical; zero @Ignore/@Skip/skip:/filter/deleted
    tests anywhere in the suite; zero direct bloc.add in the new file.
  - packages/control_plane_client/** untouched; no `serverpod generate`.

BLOCKERS: NONE

OPEN NON-BLOCKING FOLLOWUPS (do not hold the branch):
  F1 MEDIUM  apps/control_plane/test/widgets/add_product_keyflow_widget_test.dart:318-331
            — the setUp-bloc warning is stated as a universal rule. Symptom reproduced on
            the real page (setUp-built AddProductBloc: state advances, tree frozen, 0
            pressable even after two bare pumps); NOT reproduced for a plain Cubit with
            direct emit, sync or async. Advice is right, scope is wrong. Narrow the wording.
  F2 LOW     Do not propagate the current mechanism into framework widget-test guidance
            (report §11). Escalate the practice, not the stated cause.
  F3 LOW     Report §11 calls the UnimplementedRepositoryApis drift "silent"; it is
            compile-enforced by `implements ControlPlaneRepository`, so it fails analyze
            loudly. Count is 14 hand-written overrides, not 13. Ergonomics, not correctness.
  SCOPE      The harness hazard has ZERO victims in this repo: the only setUp that
            constructs a bloc is test/blocs/add_product_bloc_test.dart:420, which contains
            no testWidgets. The 266-test baseline cannot have been weakened by it. No
            follow-up lane needed here.

CONSTRAINTS HONOURED:
  - ZERO Docker/Compose commands issued (not even read-only ones). QA stack untouched.
  - No `serverpod generate`.
  - All mutation experiments confined to a throwaway clone in the session temp dir;
    the reviewed worktree was verified pristine (git status empty) at the end.

READY_FOR_MERGE: YES
```
