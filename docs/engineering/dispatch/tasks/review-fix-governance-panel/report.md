# Focused re-review — fix-governance-panel

**Lane:** focused re-review (read-only on production code).
**Worktree:** `/private/tmp/shipit-fix-governance`, branch `fix/governance-panel`.
**CORRECTED_FROM_HEAD:** `42999b23a7b3c8d21f24c584b2bd3f77345f29a1`
**REVIEWED_HEAD:** `0bc016a97b70eb8a6baca593290d0fd58b244016`
**Docker/Compose commands issued:** zero.
**Mutation experiments:** confined to a throwaway copy and the session temp dir. The reviewed
worktree is verified clean at `0bc016a` (`git status` → empty). **Incident disclosed in §9.**

---

## 1. Verdict

All five findings are **genuinely closed**, and the three extra defects the lane found are real and
correctly fixed. The test suite bites — I reproduced six independent reverts and each one fails.

One blocker remains. It is **not** one of the five findings, it is **not** a regression, and it cannot
be fixed inside this lane's `OWNED_PATHS`. It is the residual form of finding #3 and it is
**undisclosed** in a report that was otherwise scrupulous about its limits. Details in §5.

```
RESULT: DO_NOT_APPROVE_CORRECTIONS
```

---

## 2. Provenance

| Check | Result |
|---|---|
| `git rev-parse HEAD` | `0bc016a97b70eb8a6baca593290d0fd58b244016` — matches `NEW_HEAD` |
| Parent of HEAD | `a75210a` → parent `42999b2` — matches `CORRECTED_FROM_HEAD` |
| `git status` | clean |
| Commits | `a75210a` (real server calls), `0bc016a` (render in tests) — logical, matches report §10 |
| Diff scope | 3 files, all under `apps/control_plane/lib/**` and `apps/control_plane/test/**` |
| Prohibited paths | `apps/server/**`, `packages/**`, `docker/**`, `docs/**`, `.decisions/**`, `.github/**` — **untouched** |

`git diff --stat` confirms nothing outside the declared `OWNED_PATHS` moved. The 3-file diff matches
report §10 exactly.

---

## 3. The five findings — each verified independently

### F1. `pendingDecision` had no production consumer — **CLOSED**

The write-only state field and its `BlocListener` are **deleted, not worked around**.

- Repo-wide grep: no `pendingDecision` **state field** remains. Remaining hits are
  `pendingDecisions()` (an unrelated repository list API), `pendingBaselineDecisionId`, and the
  report/doc prose.
- `product_detail_page.dart:37-66`: both branches now render `_ProductDetailView` identically; only
  the repository instance differs.
- The production branch is reached by the router with no `bloc`, so it now consumes the gate.

**Proven, not assumed.** I wrote a throwaway widget test that pumps `ProductDetailPage` twice with the
same repository — once, taps *Pause work for this product*, disposes the tree (so the `BlocProvider`'s
bloc is closed, exactly as leaving the route does), and re-enters. Result at the corrected HEAD:
`gateVisible=true`. The raised gate survives navigation.

### F2. Two of six actions routed — **CLOSED**

`product_detail_bloc.dart:119-165` switches on every `GovernanceAction`. `pause`, `resume` and
`offboard` reach `requestLifecycleDecision(action: event.action.lifecycleWire!)`; `revokePolicy`
reaches `revokeStandingPolicy`; `proposeBaseline` / `reviewBaseline` reach their own calls. No `_ =>
null` arm survives.

### F3. The resolve half did not exist — **CLOSED**

`resolveLifecycleDecision` now has a caller: `product_detail_bloc.dart:199`, driven by
`LifecycleDecisionResolved` → `_LifecycleDecisionGate`. The action-scoped failure path is in place too
(`product_detail_bloc.dart:185-193`).

A raised gate is therefore actionable, **with one carve-out — see §5**.

### F4. The needs-you route cannot render a lifecycle decision — **CLOSED**

No lifecycle gate is routed anywhere. The only `context.go` left under
`features/product_detail/**` is `context.go('/products')` (`product_detail_page.dart:705`).
`home_page.dart` still routes gates to needs-you, but its data comes from `pendingDecisions()`, which
the server builds by enumerating WorkItems (`home_endpoints.dart:209-250`) — a lifecycle decision's
`workItemId` is the synthetic scope `product-lifecycle:<id>`, so it can never appear there. The
synthetic-scope crash path is unreachable from this code.

### F5. The catch was inert — **CLOSED**

`product_detail_bloc.dart:171-178` sets `governanceError` and never mentions `errorMessage` or
`clearError`. The governance path cannot touch the page-level field.

**Reverting this fails 5 tests** (§7).

---

## 4. Errors surface in place — **CLOSED**

- `_GovernanceError` (`product_detail_page.dart:~1477-1520`) renders inside the Governance panel:
  `DesignPanel(edgeColor: palette.negative)`, the server's reason **verbatim**, `Semantics(liveRegion:
  true)`, and a Dismiss that only clears (`GovernanceErrorDismissed` → `clearGovernanceError`) and does
  not re-run the action.
- `DesignErrorState` is retained for **load** failures only (`product_detail_page.dart:635, 645`),
  which is what it actually means. It is **not** used for a governance refusal.
- On the misdescribing copy: the report reuses `DesignErrorState`'s *sentence* inside the in-place panel
  ("Nothing has been changed. No decision was recorded and no work was started or stopped by this"),
  not its *title* or its whole-page takeover. That is **correct**, and it is what the assessment
  explicitly instructed (`research-dead-governance-actions/report.md:258-260`: *"is exactly right and
  should be reused rather than reworded"*). For a server refusal the sentence is factually true and now
  sits under the honest title *"The registry refused that action."* I checked
  `state_views.dart:311-312` — the wording matches.

**Honest disclosure carried forward:** `_onBaselineApprovalResolved` still routes failures to the
page-level `errorMessage` (`product_detail_bloc.dart:247-251`). Pre-existing, three tests pin it, and
report §7 discloses it. Accepted.

---

## 5. BLOCKER — a raised lifecycle gate is forgotten on navigation, and a second gate can be stranded

### What is wrong

`pendingLifecycleDecision` is **client memory only**. It is set from the *response* of the raise
(`product_detail_bloc.dart:152`) and cleared on resolve. Unlike the baseline gate — which is
**re-derived from durable state** via `canApproveBaseline` ← `detail.pendingBaselineDecisionId` — there
is no durable source for it. `ProductDetailResponse` has no lifecycle-decision field, and no endpoint
exposes one (`product_registry_endpoints.dart` has no "list open lifecycle decisions"; `pendingDecisions`
and `recentDecisions` are both WorkItem-shaped and cannot see a synthetic scope).

The page's own reasoning depends on this field being true.
`product_detail_page.dart:666` computes `final gateOpen = state.pendingLifecycleDecision != null;` and
withholds the action list on that basis — under a comment that says *"raising a second one would leave
the first unresolvable from this screen."* That protection holds **only within one page session.**

### Reproduced

Probe A — a throwaway widget test against the corrected HEAD, disposing the tree between pumps
(exactly what leaving the route does):

```
RELOAD PROBE: gateVisible=false pauseOffered=true offboardOffered=true
```

The `blocking: true` gate is still pending server-side and the screen shows no trace of it.

Probe B — same test, continuing: raise *Pause*, leave, return, then offboard a governed product
(passing the typed fence):

```
SECOND GATE PROBE: gates raised = [pause, offboard]
```

Two distinct `blocking: true` lifecycle gates now coexist for one product.

Probe C — driven through the real engine, in the worktree's own `product_registry`:

```
raised pause gate: plc-pause-p
raised offboard gate: plc-offboard-p
OPEN blocking lifecycle decisions: [plc-pause-p, plc-offboard-p]
after offboard approve, product state: archived
pause gate status: pending  blocking=true
can the UI re-raise it? (archived -> paused) : no legal transition from archived to paused
  re-raise REFUSED: ... no legal transition from archived to paused
UNRESOLVABLE blocking decisions left on the record: [plc-pause-p]
```

The pause gate is now **permanently** pending and blocking, and **no surface can reach it**: the
product is `archived`, so re-raising `pause` is refused by the transition table
(`product_registry_engine.dart:1211-1219`), and the needs-you / decision-detail surfaces cannot read a
synthetic scope.

That is precisely the outcome `product_registry_endpoints.dart:164-165` promises never to happen —
*"a gate is never created that nobody can action"* — which is the whole reason finding F3 existed.

### Honest weighting — why this is a blocker and not a note

- **It is squarely inside the corrected finding.** F3 is "the resolve half does not exist … raising a
  gate without a resolve path creates a `blocking: true` gate nobody can action." The resolve half now
  exists, but only for a gate the current page session remembers.
- **It is new behaviour this correction introduced.** Before it, `pause`/`resume`/`offboard` were
  unreachable, so no lifecycle gate could be created from this screen at all. The correction creates
  the raise path; the raise path is what makes the sequence reachable.
- **It is undisclosed.** The report applies exactly the right standard to two comparable limits —
  `registered → baselinePending` (§3c) and caller-asserted `noWorkInFlight` (§5) — and passes over a
  third of the same species. The asymmetry is visible in the code itself: `_baselineGate` is commented
  *"driven by durable state rather than by the response of the call that raised it"*, and
  `_lifecycleGate` immediately above it is *"the lifecycle gate this screen raised"*. That asymmetry is
  the bug, stated in two adjacent doc comments.

### Required fix

Make the lifecycle gate durable the way the baseline gate already is. In outline:

1. **Server** (`apps/server/**`, outside this lane's ownership): add a
   `pendingLifecycleDecisionId` to `ProductDetail`, computed the way
   `pendingBaselineDecisionId` already is at `control_plane_service.dart:380-397` — read
   `readHumanDecisionsForScope('product-lifecycle:<productId>')` and return the first unresolved one.
2. **Client**: replace the memory-only check with a durable one —
   `bool get hasOpenLifecycleGate => detail.pendingLifecycleDecisionId != null` — and derive
   `gateOpen` from **that**, not from the raise response. Recovering the full `DecisionResponse` for
   rendering then needs either a decision-read endpoint or the question/options already known; the
   minimum honest version is a panel that states a decision is open and offers the outcome buttons.

Until (1) exists, a **client-only mitigation** is available and should be taken now, because it removes
the stranding without any server work: **withhold every lifecycle action whenever the screen cannot
prove no gate is open.** That is, when `pendingLifecycleDecision == null` the panel cannot distinguish
"no gate" from "a gate this session forgot" — so on the first load after entry, offer the lifecycle
actions **only** if the server confirms the product has no open lifecycle gate, or accept that a
reload after raising costs the operator a blocked control. Given the shipped alternative is a stranded
`blocking: true` decision, blocking the action and saying why is the safe direction.

**Severity note:** this is *narrower* than it looks in one respect, and the fix should know it. Raising
the **same** action again is idempotent — the engine returns the existing unresolved decision
(verified: `first raise: plc-pause-p` → re-raise → `plc-pause-p`, `same=true`). So the single-gate
case self-heals if the operator repeats the action. Only the **cross-action** case strands. That is
still reachable by ordinary use (raise Pause → click back to Products → return → Offboard).

---

## 6. The three extra defects — all real, all correctly fixed

**(a) `offboard` offered from `baselinePending` / `baselineReview` were illegal edges — REAL, FIXED.**
Verified against the transition table by direct probe:

```
baseline_pending -> archived : false  guards=[]
baseline_review  -> archived : false  guards=[]
registered       -> archived : true   guards=[offboard_decision_recorded, decision_actor_is_human]
baseline_blocked -> archived : true   guards=[offboard_decision_recorded, decision_actor_is_human]
governed         -> archived : true   guards=[..., no_work_in_flight]
paused           -> archived : true   guards=[..., no_work_in_flight]
```

`availableFor` (`product_detail_bloc.dart:466-472`) now offers `offboard` only from the four states
with a real edge.

**(b) `request_correction` is not a valid `HumanDecisionChoice` — REAL, FIXED. Verified against the enum.**

`packages/platform_contracts/lib/src/enums/human_decision.dart` defines exactly
`approve, reject, waive, rework, cancel, defer, fixed, still_broken, partially_fixed`. There is no
`request_correction`. Probe:

```
HumanDecisionChoice.fromWire("request_correction")
  THROWS: FormatException: Unknown human decision choice: request_correction
HumanDecisionChoice.fromWire("rework")  ->  HumanDecisionChoice.rework
```

The endpoint calls `HumanDecisionChoice.fromWire(choice)`
(`product_registry_endpoints.dart:209`), so the old button was a guaranteed 500. `rework` is correct:
the engine maps it onto `requestCorrectionOptionId = 'request_baseline_correction'`
(`product_registry_engine.dart:892`) — the engine's own "send it back" option, matching the button
label. The lane's disclosure was right and the fix was in scope (owned paths, and named by the
acceptance criterion *"a product in baselineReview can be approved or sent back"*).

**One loose end, disclosed by the lane:** `product_detail_baseline_bloc_test.dart:210` still constructs
the event with the string `request_correction`. It tests pass-through, not the wire, so it passes — but
the fixture now documents a value the wire rejects. Legitimate follow-up; not a blocker.

**(c) `noWorkInFlight` hardcoded `false` made a governed offboard permanently unapprovable — REAL, FIXED.**
`control_plane_repository.dart:227` still defaults the parameter to `false` (that is the correct
default); the correction now threads an **operator statement** through
`product_detail_bloc.dart:204`. The UI gates it on
`lifecycleOffboardNeedsWorkInFlightAssertion` (`product_detail_bloc.dart:367-369`), which correctly
asks only where the transition table actually requires the guard.

---

## 7. `noWorkInFlight` — sound, and not a silent bypass

**The engine does not verify it.** Proven, not inferred: driving a product to `governed` and resolving
an offboard while asserting the guard with **no work in flight anywhere**:

```
-- resolve WITHOUT asserting the guard --
   REFUSED: ... unsatisfied no_work_in_flight
-- resolve ASSERTING the guard with no work in flight at all --
   ACCEPTED
```

`transitionProduct` checks only membership:
`required.where((g) => !satisfiedGuards.contains(g))` (`product_registry_engine.dart:92-101`). The
guard set is **handed** to it, not established by it.

**The UI cannot assert it without the operator meaning to.** `_WorkInFlightAssertion` starts unchecked;
`_canSubmit` refuses to submit while the assertion is required and unticked; the field defaults to
`false` on `LifecycleDecisionResolved`; and the copy is explicit — *"You are stating this; the registry
records your statement and does not check it."* A blind `true` is exactly what the lane refused to
write, and it would archive a product whose work is still running.

**Reverting either half fails a test** — hardcoding `true` fails
*"a registered offboard does not ask for an assertion it does not need"*; dropping the assertion fails
*"a governed offboard asks the operator to state that no work is running"*.

The report also correctly notes `drainInFlight` is recorded at request time and never read at resolve.
Confirmed in the engine: it is stored in the binding
(`lifecycle_decision_binding.dart:114`) and surfaces only in the option *description*
(`product_registry_engine.dart:1376-1390`). A real governance weakness, correctly routed to the human
as a server-side item, and `packages/**` is read-only for this lane.

---

## 8. The deviation, and the unmet acceptance criterion

### The deviation — typed fence extended to `paused`: **faithful, not scope creep. No finding.**

The recorded decision `f9a043ae` says: *"Offboarding a **governed** product requires typing the
product id; a **registered** product offboards in one tap."* `paused` is not named.

The lane's grounds check out against the source:

- `product_state.dart:46-49` documents `paused` as *"Governed, but the scheduler will not dispatch new
  work"* — literally a governed product, dispatch stopped. It holds the same accepted baseline.
- `(paused, archived)` carries the **identical** guard set including `no_work_in_flight`
  (`product_transitions.dart:132-136` vs `:127-131`).
- The decision's own rationale — *"offboarding a governed product discards an accepted baseline and
  cannot be reversed without a fresh baseline review"* — therefore applies to `paused` verbatim. The
  `(paused, archived)` edge carries `offboardDecisionRecorded`, i.e. it is the same irreversible class.

`registered` and `baselineBlocked` are untouched: one tap, no typing, no assertion
(`product_detail_bloc.dart:471-472`; test *"offboard from a registered product calls the server in one
tap"*). The decision's second half is honoured exactly.

Being stricter than a recorded human decision **is** a deviation, and the lane flagged it in three
places (§6, §11.3) with a two-line revert named. That is the correct disposition under
`aef-correction-loop`. I record it for the human to ratify or overrule; I do not treat it as a defect.

### The unmet acceptance criterion: **the lane was right to report, not to fake. Verified.**

*"A registered product can reach baselinePending"* cannot be met from this client. Confirmed twice over:

```
registered -> baseline_review : false          (not an edge at all)
requestBaselineApproval from registered, no baseline row
  REFUSED: BaselineNotFoundException: Product baseline not found: bl-r1-1
proposeBaseline with zero facts from registered
  REFUSED: EmptyBaselineException: ... an empty baseline asserts nothing while remaining verifiable
  state after: registered
```

And the reachable substitute genuinely works — driven end-to-end through the real engine:

```
requestBaselineApproval BEFORE verification  -> REFUSED: BaselineNotVerifiedException
requestBaselineApproval AFTER verification   -> ACCEPTED: blappr-bl-p1-1, blocking=true
                                                 state now: baseline_review
```

This matches the Manager's independent finding (zero rows in `product_baseline` / `baseline_fact`;
`requestBaselineApproval` requires a `baselineId` that does not exist). The lane's conclusion — the gap
is a **missing first-baseline author**, not a missing button, and that author today is
`apps/server/bin/onboard_shipit_dev.dart` — is correct and correctly bounded. Building the button anyway
would have been building a guaranteed 500, which the dispatch forbids.

The one thing I would add: **`proposeBaseline` remains offered for a `governed` product and cannot
succeed from this screen** (the client sends `facts: const []`, so `EmptyBaselineException` refuses
before any write). The lane keeps it deliberately, because the capability is real and the refusal is now
reported in place instead of swallowed. I agree with keeping it — but it is a permanently-failing
control on the offered list, which is the same class the dispatch said must not ship. It is honest
(§11.4 raises it for a product call) and low-severity because the failure is now visible rather than
silent. **Non-blocking follow-up**, not a finding against this correction.

---

## 9. `revokePolicy` — decided, not left throwing

**Implemented.** `product_detail_bloc.dart:159-164` calls
`revokeStandingPolicy(productId, policyId, revokedBy: 'operator')`, with `policyId` read from durable
state by `_livePolicyId` (`product_detail_bloc.dart:271-282`) rather than guessed. It is correctly kept
**out** of the decision switch — it is an attributed write, not a gate. `UnimplementedError` is gone
from the codebase.

**Nothing on the offered list throws on tap.** I traced each of the six:
`proposeBaseline`/`reviewBaseline` → real calls with a real refusal path; `pause`/`resume`/`offboard` →
real calls, guarded behind the typed fence where required; `revokePolicy` → real call, and it is only
offered when `hasLivePolicy` (`availableFor:456, 462`), with `_livePolicyId` throwing a readable
`StateError` in the impossible case rather than crashing.

The rationale for implementing rather than removing is also right: both ids were in scope, server
support is complete (`product_registry_endpoints.dart:295-308`), and removing a working capability to
hide a client bug is the inversion the file's own comment warns against.

---

## 10. The tests bite — reproduced

**Structure is the fix.** All 33 tests pump `ProductDetailPage` with **no bloc injected**
(`_pumpProduction`, `product_detail_governance_test.dart:258-276`), so the production `BlocProvider`
builds the bloc. Assertions are on repository calls and the rendered tree, never on bloc state alone.
This is the direct structural answer to "a green suite that never renders the screen".

**I reproduced six independent reverts in a throwaway copy. Every one bites:**

| # | Revert | Tests failed |
|---|---|---|
| 1 | typed fence removed (`_needsTypedConfirmation` → `false`) | **6** |
| 2 | governance errors back to the inert catch (`clearError: true` + `errorMessage`) | **5** |
| 3 | `resume` unrouted — the original `_ => null` bug | **1** |
| 4 | `offboard` re-offered from `baselinePending` / `baselineReview` | **2** |
| 5 | no lifecycle gate on mobile (the original gap) | **1** |
| 6 | `noWorkInFlight` hardcoded `true` (client rubber-stamps the guard) | **1** |
| 7 | operator never asked to state no-work-in-flight | **1** |

Revert 2 is the important one: it reinstates the **exact** original inert-catch bug
(`clearError: true` alongside `errorMessage`) and 5 tests fail — including
*"the reason appears inside the Governance panel"* and *"the refusal is announced as a live region"*.
The green-suite failure mode is genuinely closed.

Reverts 6 and 7 matter for §7: the suite pins the guard in **both** directions, so neither a blind
`true` nor a silent removal can pass.

**One weak test, non-blocking.** *"they are reachable by keyboard activation"* only taps; it never sends
a key event, so it does not test what its name claims. The `FocusableActionDetector` wiring is real
(`Enter`/`Space` → `ActivateIntent`) and `Semantics(button: true, enabled:)` is asserted by the sibling
test. Worth renaming or strengthening in a follow-up.

---

## 11. Nothing weakened; the golden claim verified carefully

- **Nothing deleted, filtered, skipped or `@Ignore`d.** `git diff 42999b2..0bc016a -- test/` contains
  **zero** deleted lines. No `@Ignore`, `@Skip`, `skip:` or platform filter in the new or touched test
  files.
- **Counts verified independently.** Removing `product_detail_governance_test.dart` entirely:
  **`All tests passed! ... +271`**. With it: **`+304`**. **271 + 33 = 304 exactly**, as claimed.

### The mobile golden — "same pixels, different semantics" is **correct**

I checked this structurally rather than trusting the green, because a golden passing while controls
change is exactly the sort of thing that deserves suspicion. Here it does not apply:

- `git diff --stat 42999b2..0bc016a -- '*.png'` is **empty**. No golden PNG was regenerated.
- The golden fixture is a `governed` product with **no policies**, so
  `availableFor(governed)` = `[proposeBaseline, pause, offboard]` — **three `_GovernanceAction`s are
  inside the golden's viewport.** The widget swap is genuinely covered.
- I diffed the two render trees. `InlineLink` (`design_primitives.dart:216-242`) builds
  `Semantics(link: true) > MouseRegion > GestureDetector > Row(mainAxisSize: min) > Text(label,
  ShipItType.link.copyWith(color: palette.accent))`.
  `_GovernanceAction` builds `Semantics(button, enabled) > FocusableActionDetector > GestureDetector >
  Row(mainAxisSize: min) > Text(label, ShipItType.link.copyWith(color: palette.accent))`.
  **Identical leaf, identical padding (`Padding(bottom: 10)`), identical parent.** The only
  differences are semantic (`link` → `button`), the added non-painting `FocusableActionDetector`
  wrapper, and the mouse cursor — none of which paint. Neither control's visibility nor its disabled
  state differs at rest.

So "same pixels, different semantics" is exactly right, and the golden is a meaningful regression guard
here rather than a stale file.

---

## 12. Gates re-run independently

| Gate | Command | Result |
|---|---|---|
| Deps | `dart pub get` (repo root) | pass |
| Format | `dart format --output=none --set-exit-if-changed .` | pass — `766 files (0 changed)`, exit 0 |
| Analyze | `cd apps/control_plane && flutter analyze` | pass — `No issues found!` |
| Test | `cd apps/control_plane && flutter test` | pass — `All tests passed!` **304** |

All four reproduce the lane's §9 exactly, at the reviewed HEAD, with no Docker involved.

---

## 13. Blocking findings

**B1 — A raised lifecycle gate is client-memory only; a second gate can be stranded permanently.**
`product_detail_bloc.dart:152` (set from the raise response), `:209` (cleared on resolve);
`product_detail_page.dart:666` (`gateOpen` derived from it). Reproduced in §5, including the engine-level
proof that the stranded `blocking: true` decision can never be raised, listed or resolved again.

Not fixable within `OWNED_PATHS`: it needs a `pendingLifecycleDecisionId` on `ProductDetail`
(`apps/server/**`, prohibited here). Either route it to a follow-up server+client lane, or take the
client-only mitigation in §5 before merge. **Do not merge without one of the two.**

### Non-blocking follow-ups (record, do not gate)

1. `product_detail_baseline_bloc_test.dart:210` still builds the event with `request_correction`, which
   the wire rejects. Fixture now contradicts the documented choice set.
2. The keyboard-activation test taps rather than sending a key event.
3. `proposeBaseline` stays offered for `governed` and cannot succeed from this screen. Honest, visible,
   and already escalated as a product call — but it is a permanently-failing control.
4. `noWorkInFlight` is caller-asserted and never verified server-side; `drainInFlight` is recorded and
   never read at resolve. Already escalated for a human decision; `packages/**` is read-only here.
5. The recorded decision `f9a043ae` does not name `paused`. Ratify or overrule the extension (§8).

---

## 14. Self-disclosure — incident during this review

While measuring the baseline I ran `git rm` inside a `cp -R` copy of the worktree. Because
`/private/tmp/shipit-fix-governance/.git` is a **file** pointing at the real repository's gitdir, the
copy's git commands resolved to the **real index**, staging a deletion of
`apps/control_plane/test/widgets/product_detail_governance_test.dart` in the reviewed worktree.

Detected immediately, disclosed here rather than quietly repaired, and fully reversed:
`git reset HEAD -- <file>`. Verified afterwards: `git rev-parse HEAD` = `0bc016a`, `git status` → empty,
`git diff HEAD` → empty, file present at 956 lines. **No content was lost** — the file was never
removed from disk, only staged. The reviewed worktree is byte-identical to the reviewed HEAD.

The fault is mine, not the lane's: I used a copy rather than a `git worktree`, and `cp -R` copies a
gitdir *pointer* without detaching it. The correct tool was `git worktree add` into the temp dir.
Recorded because the AGENTS.md rule on shared-state breaches is that disclosure is what bounds the
damage, and because the same mistake in a lane holding a QA stack would have been worse.

**No mutating Docker/Compose command was issued at any point.**

---

## 15. Required structured result

```
RESULT: DO_NOT_APPROVE_CORRECTIONS

REVIEWED_HEAD: 0bc016a97b70eb8a6baca593290d0fd58b244016

FINDINGS_REVIEWED:
  F1 pendingDecision write-only / no production consumer  -> CLOSED (field + BlocListener deleted; verified by re-entry probe)
  F2 _onGovernanceActionRequested handled 2 of 6           -> CLOSED (all six routed; revert fails)
  F3 resolveLifecycleDecision had zero callers            -> CLOSED with carve-out -> see B1
  F4 needs-you cannot render a lifecycle decision         -> CLOSED (no lifecycle route; synthetic scope unreachable)
  F5 inert catch (clearError beat errorMessage)           -> CLOSED (governanceError; revert fails 5 tests)
  E1 offboard illegal from baselinePending/baselineReview -> REAL + FIXED (probe-verified non-edges)
  E2 request_correction is not a HumanDecisionChoice      -> REAL + FIXED (fromWire throws; rework is correct)
  E3 noWorkInFlight hardcoded false                       -> REAL + FIXED (operator statement; both directions pinned)
  noWorkInFlight soundness / not a silent bypass          -> SOUND (engine never verifies it; UI cannot assert silently)
  Deviation: typed fence extended to paused               -> FAITHFUL, disclosed; not scope creep; human ratification only
  Unmet AC: registered -> baselinePending unreachable     -> LANE CORRECT to report; independently verified twice
  revokePolicy decided not throwing                        -> IMPLEMENTED as attributed write; nothing on the list throws
  Tests bite / nothing weakened / golden claim            -> VERIFIED (7 reverts; 271+33=304; golden structurally justified)

REGRESSIONS: none

BLOCKERS:
  B1 A raised lifecycle gate is client-memory only (product_detail_bloc.dart:152 / :209,
     product_detail_page.dart:666). On leaving the route the blocking gate is invisible and a
     second, different gate can be raised; resolving that one can leave the first permanently
     pending and blocking with no surface able to raise, list or resolve it. Reproduced in-widget
     and against the real engine. Not fixable within OWNED_PATHS -- needs
     ProductDetail.pendingLifecycleDecisionId (apps/server/**, prohibited here) plus a
     durable gateOpen on the client. Do not merge without that, or without the client-only
     mitigation (withhold lifecycle actions when the screen cannot prove no gate is open).

READY_FOR_MERGE: NO
```
