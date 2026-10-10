# Report — fix-governance-panel

**Lane:** correction/implementation. Client-only, as dispatched.
**Corrected from:** `42999b23a7b3c8d21f24c584b2bd3f77345f29a1` (`fix/governance-panel`)
**Produced:** `0bc016a97b70eb8a6baca593290d0fd58b244016`
**Worktree:** `/private/tmp/shipit-fix-governance`, branch `fix/governance-panel`, not pushed, not merged, `main` untouched.
**Docker/Compose commands issued:** zero. No `make clean`, `make qa-down`, `make test-env-down`, `make e2e-down`, no bare `down -v`.
**Paths touched:** `apps/control_plane/lib/**` and `apps/control_plane/test/**` only. `apps/server/**`, `packages/**`, `docker/**`, `docs/**`, `.decisions/**`, `.github/**` untouched.

---

## 1. The five findings, verified rather than inherited

All five were re-derived against this HEAD.

1. **`pendingDecision` had no production consumer.** Confirmed. `product_detail_page.dart:37-56` mounted the
   `BlocListener` only inside the `bloc != null` branch; production took the `else` branch and built a bare
   `BlocProvider`. So the field was write-only for every operator. The `BlocListener` and the field are
   **deleted**, not worked around.

2. **`_onGovernanceActionRequested` handled two of six actions.** Confirmed. `_ => null` covered `pause`,
   `resume`, `offboard`, `revokePolicy`.

3. **The resolve half did not exist.** Confirmed. `ControlPlaneRepository.resolveLifecycleDecision` had zero
   callers under `apps/control_plane/lib`.

4. **The needs-you route cannot render a lifecycle decision.** Confirmed and taken as binding. The gate is
   rendered **in place**; no navigation was added.

5. **The catch was inert.** Confirmed: `clearError: true` at `:88` beat `errorMessage` inside `copyWith`. The
   governance failure path no longer touches `errorMessage` at all.

**One more defect found while verifying, not in the brief:** the baseline gate's "Request correction" button sent
`request_correction`, which is not a `HumanDecisionChoice` wire value. `HumanDecisionChoice.fromWire` throws
`FormatException` on it (verified by probe), so that button was a guaranteed 500. The correct value is `rework`,
which the engine maps onto its own `request_baseline_correction` option
(`product_registry_engine.dart:892`). Fixed, because "a product in baselineReview can be **approved or sent back**"
is in the acceptance criteria and "sent back" was impossible. **Disclosed as a scope call** — see §7.

---

## 2. What was built

| # | Scope item | Where | Note |
|---|---|---|---|
| 1 | In-place decision panel, raise **and** resolve | `_LifecycleDecisionGate`, `LifecycleDecisionResolved` | Mirrors `_BaselineApprovalGate`. Renders on desktop **and mobile** (mobile previously had no gate at all, so it produced write-only decisions). While a gate is open the action list is withdrawn, because raising a second one would strand the first. |
| 2 | `availableFor` corrected against the engine | `GovernanceAction.availableFor` | See §3. Three changes, all verified. |
| 3 | Typed confirmation for a governed offboard | `_TypedConfirmation` | Human Decision `f9a043ae` (2026-10-09). **Extended to `paused`** — see §6. |
| 4 | Failures visible, in place | `governanceError` + `_GovernanceError` | Action-scoped field, `DesignPanel(edgeColor: palette.negative)`, `Semantics(liveRegion: true)`, server's reason verbatim, `DesignErrorState`'s existing "Nothing has been changed…" sentence reused. `DesignErrorState` is still used for load failures, where it is correct. |
| 5 | `isRaisingGate` + accessibility | `_GovernanceAction` | Actions disabled + "Working…" while in flight; double-tap blocked in the UI **and** in the bloc. `Semantics(button: true, enabled:)` over `FocusableActionDetector` with Enter/Space activation. Pixels are unchanged — the mobile golden still passes byte-for-byte. |
| 6 | `revokePolicy` — **implemented** | `revokeStandingPolicy(productId, policyId, revokedBy: 'operator')` | Both ids were already in scope (`event.productId`, the live policy from `detail.policies`). Server support is complete. It is an attributed write, not a gate, so it is **not** in the decision switch. See §7 for why implement rather than remove. |

`_decisionFor` (an identity function that discarded its `productId`) is deleted.

---

## 3. `availableFor` — three corrections, each verified against the engine

Verification method: a read-only Dart probe run **outside the repository**, importing the worktree's
`product_registry` package via the repo `package_config.json`. It drove the real engine through the real stores.
No file under `packages/**` was created or modified.

```
governed        -> archived  guards=[offboard_decision_recorded, decision_actor_is_human, no_work_in_flight]
paused          -> archived  guards=[offboard_decision_recorded, decision_actor_is_human, no_work_in_flight]
registered      -> archived  guards=[offboard_decision_recorded, decision_actor_is_human]
baseline_blocked-> archived  guards=[offboard_decision_recorded, decision_actor_is_human]

registered      -> baseline_review legal?  false
baseline_blocked-> baseline_review legal?  false
baseline_pending-> baseline_review legal?  true
baseline_pending-> archived        legal?  false
baseline_review -> archived        legal?  false   (not an edge at all)
```

**(a) `offboard` removed from `baselinePending` and `baselineReview`.** These were dead controls the brief did
not name. The probe drove each state into place and called `requestLifecycleDecision(offboard)`:

```
wanted=baseline_pending  RAISE: REFUSED  no legal transition from baseline_pending to archived
wanted=baseline_review   RAISE: REFUSED  no legal transition from baseline_review to archived
wanted=baseline_blocked  RAISE: accepted → resolved → archived
wanted=registered        RAISE: accepted → resolved → archived
wanted=governed          RAISE: accepted → RESOLVE REFUSED: unsatisfied no_work_in_flight
wanted=paused            RAISE: accepted → RESOLVE REFUSED: unsatisfied no_work_in_flight
```

**(b) `reviewBaseline` now offered from `baselinePending` when a worker has verified the candidate.** This is
the one reachable way to open a baseline gate from the UI, and the engine accepts it:

```
baselinePending + independently verified -> requestBaselineApproval
  ACCEPTED; state after baseline_review
```

It is withheld when the candidate is unverified (`BaselineNotVerifiedException`) or there is no candidate.

**(c) `proposeBaseline` offered for `registered` — REPORTED, NOT BUILT.** The brief said to verify and report if
the server refuses. It refuses, twice over:

```
requestBaselineApproval from `registered`  → REFUSED: Product baseline not found: bl-p1-1
(registered, baseline_review) is an edge?    → false
requestBaselineApproval from `baselineBlocked` → REFUSED: no legal transition from baseline_blocked to baseline_review
proposeBaseline(facts: [])                   → REFUSED: EmptyBaselineException (state stays registered)
```

`requestBaselineApproval` needs an existing baseline to name, and there is none; even with one, the edge does not
exist. `proposeBaseline` with real facts *does* move `registered → baselinePending`, but the endpoint then fails
its approval half, and **this client has no source of baseline facts** — inventing them would be fabricating
governance content, and the approval half would refuse anyway. So no baseline action is offered from
`registered`. Building one would have been building a guaranteed 500, which the brief explicitly forbids.

**Consequence, stated plainly:** acceptance criterion "a registered product can reach baselinePending" is **NOT
met**, and cannot be met from this client. `registered → baselinePending` is reached today by
`apps/server/bin/onboard_shipit_dev.dart`, a CLI that scrapes a pinned repository snapshot — a worker, not the
dashboard. The gap is a missing first-baseline author, not a missing button. The reachable substitute — a
`baselinePending` product opening its baseline gate — is built and tested.

**`proposeBaseline` is kept for `governed`** (not in the brief's six items, so no test pins it away). It cannot
succeed from this screen: the client sends zero facts, `EmptyBaselineException` refuses that before any write,
and with facts the approval half still refuses anything unverified. It is kept because the capability is real,
three existing tests assert the label renders, and with fix 4 it now performs its call and reports its real
refusal in place instead of failing silently. Collecting baseline facts is its own piece of work.

---

## 4. The limit the brief told me not to work around — confirmed, and honoured

```
registered -> baselinePending   (no guards — unconditional)
baselinePending -> baselineReview   guards: baseline_proposed + baselineVerifiedIndependently
baselineReview -> governed     guards: baselineApproved + decisionActorIsHuman
```

Hop 2 requires a baseline that is **built and independently verified**, and nothing in this app does that:
`verifyBaseline` exists as an endpoint and has **no caller** outside its own unit test and
`onboard_shipit_dev.dart`. **It was not called.** A product moved to `baselinePending` reads
`Building baseline` / `Reading the repository`, not `Governed`. Nothing here can turn a product green, and I did
not try to.

---

## 5. `noWorkInFlight` — what I did about it, and the gap I am reporting

`(governed|paused) → archived` requires `ProductGuard.noWorkInFlight`; the probe confirms the resolve is
refused without it. The client previously hardcoded `noWorkInFlight: false`, so a governed offboard could never
be approved.

I did **not** pass `true` unconditionally. `transitionProduct` checks only that the caller *claims* the guard
(`required.where((g) => !satisfiedGuards.contains(g))`) — the engine never verifies it. A silent `true` would be
a rubber stamp, and with `drainInFlight: true` (let running work finish) it could archive a product whose work is
still running.

Instead, for an offboard raised from `governed`/`paused`, the in-place gate requires the operator to tick an
explicit statement, and the copy says what it is: *"You are stating this; the registry records your statement and
does not check it."* That value is passed as `noWorkInFlight`. For `registered` and `baselineBlocked` the
assertion is **not** asked for — the transition table waives the guard there, so demanding it would fence an
irreversible action over nothing.

**Reported gap (not fixed — server-side):** `noWorkInFlight` is caller-asserted and never checked. A drain/halt
choice at request time (`requestLifecycleDecision(drainInFlight:)`) is recorded in the decision binding but is
never read at resolve. This is a governance weakness in `product_registry_engine`, which is READ_ONLY in this
lane. It needs a human decision.

---

## 6. Typed confirmation — and where I extended the recorded decision

Human Decision `f9a043ae` (2026-10-09): *governed* offboard requires typing the product id; a *registered*
product offboards in one tap. Implemented exactly, and **extended to `paused`**, which the decision does not
name.

Reason, stated for the human to overrule: `paused` is documented in `product_state.dart` as *"Governed, but the
scheduler will not dispatch new work"*, it holds the same accepted baseline, and `(paused, archived)` carries
the identical `no_work_in_flight` guard. The decision's own rationale — *"offboarding a governed product
discards an accepted baseline and cannot be reversed without a fresh baseline review"* — therefore applies to
`paused` verbatim. Being stricter on an irreversible action is the safe direction; being stricter *than a recorded
human decision* is still a deviation, so it is flagged here rather than buried. It is a two-line revert.

The registered case is unchanged and tested: one tap, no typing, no assertion.

---

## 7. Decisions taken, and one scope call to be judged

- **`revokePolicy`: implemented, not removed.** Server support is complete; both ids were in scope; and removing
  a working capability to hide a client bug is the exact inversion the file's own comment warns against. It is an
  attributed write, so it sits outside the decision switch.
- **The `pendingDecision` field and its `BlocListener` are deleted**, not kept as a state field read elsewhere.
  The in-place gate makes navigation unnecessary, and leaving a field written in one build configuration and read
  in another is how the original defect survived review.
- **A `repository` constructor seam was added to `ProductDetailPage`.** Without it the production branch cannot be
  tested at all — its bloc is built from the app-wide `ClientProvider.repository`, which has no test seam. The
  brief required a test that renders a *production* build, so both branches now render identically and only the
  repository instance differs. Documented at the constructor.
- **Out of the six items, and disclosed:** the `request_correction` → `rework` fix (§1). It is in owned paths and
  named in the acceptance criteria, and leaving it would have shipped a guaranteed 500 on a rendered control in a
  lane whose purpose is to stop shipping those.

**Left alone, deliberately:** `_onBaselineApprovalResolved` still reports failures through the page-level
`errorMessage`. Three existing tests in `product_detail_baseline_bloc_test.dart` pin that field, and changing it
would mean editing those tests for a path outside the six items. Note that
`product_detail_baseline_bloc_test.dart:210` still constructs the event with the string `request_correction`; it
tests bloc pass-through, not the wire, and passes — but the fixture is now inconsistent with the documented
choice set. One-line cleanup for a follow-up lane.

---

## 8. Tests

New file: `apps/control_plane/test/widgets/product_detail_governance_test.dart` — **33 tests**.

They pump `ProductDetailPage` with **no bloc injected**, so the production `BlocProvider` builds the bloc over a
recording repository, and they assert on repository calls and the rendered tree — never on bloc state alone.
That is the structural fix for why 271 passing tests coexisted with a dead panel.

Against the dispatch's five requirements:

| Required | Covered |
|---|---|
| Each action issues its real server call, with the right arguments | 6 tests — `requestLifecycleDecision` (pause/resume/offboard, exact wire values), `revokeStandingPolicy(productId, policyId, revokedBy)`, `proposeBaseline`, `requestBaselineApproval` |
| A raised gate renders the in-place panel in a production build | 3 tests — desktop, the action list withdrawn while a gate is open, and mobile |
| A rejection surfaces in place, not a whole-page takeover | 5 tests — the reason is on screen, the product stays readable, `"We could not reach the system's records."` is absent, live region present, dismiss does not re-run the action |
| Governed offboard requires typing the id; registered does not | 5 + 1 tests — the tap alone sends nothing, a wrong id sends nothing and says so, the exact id sends, cancel restores, consequence stated first; registered offboards in one tap |
| A registered product can reach a raised baseline gate | **Refused by the server — reported instead.** Substituted with the reachable path: `baselinePending` + worker-verified candidate reaches a raised baseline gate, and a `registered` product is asserted to be offered no control the engine refuses |

Plus: offboard withheld from the two states whose archived edge does not exist; actions are real buttons, disabled
and double-tap-proof while in flight.

**They bite.** Reverting the fixes (typed fence removed; governance errors routed back to `errorMessage`;
`pause` unrouted; `offboard` re-offered from `baselinePending`/`baselineReview`) fails **22 of 33**. The run was
then reverted and the full suite re-verified green.

---

## 9. Gates — all run at `0bc016a`

| Gate | Result |
|---|---|
| `dart pub get` (repo root) | pass |
| `dart format --output=none --set-exit-if-changed .` | pass — 766 files, 0 changed |
| `cd apps/control_plane && flutter analyze` | pass — No issues found |
| `cd apps/control_plane && flutter test` | pass — **304 tests, all passed** (baseline 271, **+33**) |

The mobile golden `product_detail_mobile_back_link{,_dark}.png` passes unchanged: the new `_GovernanceAction`
renders the same pixels `InlineLink` did, and only its semantics differ. No test was weakened, skipped,
`@Ignore`d, filtered or deleted.

No runtime/browser evidence is claimed: this lane changed no behaviour the QA stack hosts, and driving it would
have required mutating the live stack.

---

## 10. Commits

| SHA | What |
|---|---|
| `a75210a` | Make every Governance action perform its real server call (bloc + page) |
| `0bc016a` | Render Product Detail in tests, so the dead panel cannot pass again |

`main` not touched. Nothing pushed, nothing merged.

---

## 11. For the human / manager

1. **A registered product still cannot reach `baselinePending` from the dashboard.** The only author of a first
   baseline today is the `onboard_shipit_dev` CLI. Needs a decision: a worker that builds and verifies
   baselines, or an operator-authored first claim (which would be a new surface and a provenance question).
2. **`noWorkInFlight` is caller-asserted and never verified** by the engine. Needs a server-side fix or an
   accepted risk.
3. **The typed-confirmation fence was extended to `paused`**, one step beyond the recorded decision. Revert is a
   two-line change if the human disagrees.
4. **`proposeBaseline` remains offered for a governed product and cannot succeed from this screen.** It now
   reports its refusal honestly. Removing it, or building a facts-authoring surface, is a product call.

## 12. Safe / prohibited parallel work

**SAFE_PARALLEL_WORK** (disjoint paths; no overlap with this branch):
- `packages/**` — including `product_registry`, `workflow_engine`, `platform_contracts`
- `apps/server/**` — especially `product_registry_engine.dart` (`noWorkInFlight` verification, a first-baseline
  authoring path) and `product_transitions.dart`
- `apps/control_plane/lib/features/products/**` — the Add Product flow
- `apps/control_plane/test/{accessibility,pixel-fidelity,responsive,shared,tools,fixtures,helpers}/**`
- `apps/control_plane/test/{home,products,runs,run_detail,needs_you,decision_detail,defect_report,reports,models}/**`
- `docker/**`, `apps/server/migrations/**`, `docs/**` (not `docs/engineering/dispatch/**`)

**PROHIBITED_PARALLEL_WORK** (would collide or contradict):
- `apps/control_plane/lib/features/product_detail/**` — this branch's files
- `apps/control_plane/test/widgets/product_detail_page_test.dart`,
  `apps/control_plane/test/widgets/product_detail_governance_test.dart`,
  `apps/control_plane/test/blocs/product_detail_baseline_bloc_test.dart`,
  `apps/control_plane/test/product_detail_mobile_golden_test.dart`
- `apps/control_plane/lib/shared/{design_primitives,form_primitives,state_views,mobile_chrome}.dart`,
  `apps/control_plane/lib/core/{design_tokens,product_language,theme}.dart`,
  `apps/control_plane/lib/data/control_plane_repository.dart`,
  `apps/control_plane/test/fixtures/app_fixtures.dart` — all touched by this change's contract
- Anything that changes `HumanDecisionChoice` wire values or `ProductGuard` names, which the new tests assert on
- Any lane driving `docker compose` against project `docker` — the QA stack is live
