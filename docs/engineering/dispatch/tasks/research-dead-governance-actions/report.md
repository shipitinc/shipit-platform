# Assessment — the dead governance actions on Product Detail

**Lane:** read-only investigation. No file outside this directory was created or modified.
**Reviewed HEAD:** `36cfb44b0f76096348e4fc9df114c2247a6d4eb4` (`main`, in sync with `origin/main`).
**Working tree:** dirty in `.decisions/` and in golden PNGs under `apps/control_plane/test/failures/`
(pre-existing; not mine, not touched).
**Docker/Compose commands issued:** zero.
**Lanes dispatched:** zero.

Note on paths: the Manager's brief cites
`apps/control_plane/lib/features/products/product_detail_bloc.dart:58-95`. That path does not
exist. The real file is `apps/control_plane/lib/features/product_detail/product_detail_bloc.dart`
(singular `product_detail`). Line numbers in the brief are otherwise accurate against the real
file, so the diagnosis lands on the right code.

---

## 1. Is the diagnosis complete?

**Partly. The `_ => null` arm is real, but it is the smallest of three defects, and two of the
six actions are dead for a second, independent reason the brief did not reach.**

### 1a. The `_ => null` arm — confirmed

`apps/control_plane/lib/features/product_detail/product_detail_bloc.dart:64-76`

```dart
final decision = switch (event.action) {
  GovernanceAction.proposeBaseline => _decisionFor(event.productId, await _gate(...)),
  GovernanceAction.reviewBaseline  => _decisionFor(event.productId, await _gate(...)),
  _ => null,                       // pause, resume, offboard, revokePolicy
};
```

Four of six actions return `null` without touching the repository. `_gate` at
`product_detail_bloc.dart:96-128` *already* contains working `pause` / `resume` / `offboard` arms
that call `requestLifecycleDecision` (lines 112-123) — they are simply unreachable, because the
dispatch switch never routes to them. This matches the observed evidence: zero API calls on tap.

`_decisionFor` (`:253-254`) is an identity function that discards its `productId` argument. It is
dead weight, not a defect.

### 1b. Other dead actions: all four, and `revokePolicy` is dead twice over

| Action | `availableFor` offers it at | Reachable via `_gate`? | Server support |
|---|---|---|---|
| `proposeBaseline` | `governed` (`:280`) | yes (`:101`) | yes |
| `reviewBaseline` | `baselineReview` + pending (`:291`) | yes (`:106`) | yes |
| `pause` | `governed` (`:281`) | **unreachable** (`:112`) | yes |
| `resume` | `paused` (`:286`) | **unreachable** (`:116`) | yes |
| `offboard` | `governed`, `paused`, `baselineReview`, `registered`, `baselinePending`, `baselineBlocked` (`:282,287,292,296`) | **unreachable** (`:120`) | yes |
| `revokePolicy` | `governed`/`paused` when `hasLivePolicy` (`:283,288`) | **unreachable AND throws** (`:124` `UnimplementedError('revocation needs productId + policyId')`) | yes — `revokeStandingPolicy` exists at `control_plane_repository.dart:286-297` and `product_registry_endpoints.dart:295-308` |

`revokePolicy` is the worst case. Even if the dispatch switch were widened naively to route
everything through `_gate`, `revokePolicy` would throw `UnimplementedError` into the `catch` at
`:84-92` and surface as a page-level error. It needs a different implementation, not the same one.
The comment at `:125` claims it "needs productId + policyId" — both are in scope
(`event.productId` and `livePolicies.first.policyId`, the latter already read at
`product_detail_page.dart:362,802`). The stated blocker is not a blocker.

### 1c. The `pendingDecision` render condition — it is not a dialog, and it is only mounted in tests

The brief calls it "the decision dialog's render condition". There is no dialog.
`product_detail_page.dart:41-47`:

```dart
child: BlocListener<ProductDetailBloc, ProductDetailState>(
  listener: (context, state) {
    final decision = state.pendingDecision;
    if (decision != null) {
      context.go('/needs-you/${decision.decisionId}');
    }
  },
  child: _ProductDetailView(productId: productId),
),
```

Two corrections that change the fix:

1. **It navigates; it does not render.** `context.go('/needs-you/<id>')` — `router.dart:74-82`
   routes to `DecisionDetailPage`.
2. **It only exists on the test-injected path.** The `BlocListener` wraps `_ProductDetailView`
   only inside the `provided != null` branch (`:37-50`), i.e. only when a `bloc` is passed in
   explicitly. The production branch (`:51-56`) builds a bare `BlocProvider` and the child is
   `_ProductDetailView` directly — **no listener, no navigation**. `ProductDetailPage` is
   constructed by the router at `router.dart:62-68` without a `bloc`, so in the real app
   `pendingDecision` has **no consumer whatsoever**. It is write-only in production.

This is the part the brief missed, and it is the more serious half: **even `proposeBaseline` and
`reviewBaseline` are half-wired.** They raise a real gate server-side and then do nothing
observable, because the navigation that would surface it is compiled out of the production widget
tree. So the current count is not "two work, four dead" — it is "two work server-side and
invisibly, four do nothing at all."

### 1d. Is the dialog/listener the only consumer of `pendingDecision`?

Yes. Repo-wide grep for `pendingDecision` in the app returns hits only in
`product_detail_bloc.dart` (`:80,200,216,241,249`) and `product_detail_page.dart:43`. Nothing in
`needs_you/`, `decision_detail/`, `home/` or `run_detail/` reads it. And per 1c, in production
even that one reader is absent.

---

## 2. What does the UI actually promise, and which fix is right?

The file's own contract, stated twice:

- `product_detail_page.dart:24-26` — "Governance actions are derived from durable state — an
  action that the engine would refuse is not rendered at all, rather than shown and then failing
  on tap."
- `product_detail_bloc.dart:258-260` — "an action that cannot succeed is not presented as if it
  could."

### The fix is (a) — wire them. Option (b) is a governance regression.

`availableFor` is not over-offering relative to the engine. Every action it lists maps to an edge
`ProductTransitions` actually has:

- `pause` → `(governed, paused)` — `product_transitions.dart:111-114`
- `resume` → `(paused, governed)` — `:115-118`
- `offboard` → `(governed|paused|registered|baselineBlocked, archived)` — `:127-145`
- `revokePolicy` → `revokeStandingPolicy` — engine `:1608-1627`, endpoint `:295-308`

The server test `lifecycle_decision_test.dart:252-268` asserts precisely this binding: every
`ProductLifecycleAction` guard matches at least one real inbound edge. So `availableFor` is
correct and the *dispatch* is what's broken. Removing the actions would delete a working
capability to hide a client bug — the exact inversion the file's comment warns against, and it
would also break the three existing widget tests that assert the labels render
(`product_detail_page_test.dart:185,192,198,225`).

### But (a) alone is not enough — the client is missing three more things

**(i) The resolve half does not exist for lifecycle actions.**
`ControlPlaneRepository.resolveLifecycleDecision` is defined at
`control_plane_repository.dart:222-243` and is called from **nowhere** in the app. Grep for
`resolveLifecycleDecision` across `apps/control_plane/lib` returns only the definition. The only
callers of the two resolution paths that do exist are:

- `needs_you_bloc.dart:186` → `resolveDecision` (workflow endpoint, `workflow_endpoints.dart:107`)
- `decision_detail_bloc.dart:102` → `resolveDecision` (same)
- `product_detail_bloc.dart:146` → `resolveBaselineApproval` (product-registry endpoint)

So for `proposeBaseline` / `reviewBaseline` both halves exist but are split across two different
surfaces: the raise is in the Governance panel, the resolve is in the inline
`_BaselineApprovalGate` (`product_detail_page.dart:70-85, 400-414`), which is driven by
`state.canApproveBaseline` (`:227-233`) reading durable `pendingBaselineDecisionId`. That path is
complete and works.

For `pause` / `resume` / `offboard` **neither half is reachable**: the raise is unreachable
(1a) and the resolve does not exist at all. Wiring `_gate` alone would raise a durable gate that
**no client surface can ever resolve** — precisely the outcome
`product_registry_endpoints.dart:164-165` promises to prevent ("a gate is never created that
nobody can action"). It would convert a silent dead button into a silent dead gate, and it would
write a `blocking: true` row into `human_decision` each time.

**(ii) The navigation target cannot render a lifecycle decision.**
Even if the `BlocListener` were mounted in production, `context.go('/needs-you/<id>')` lands on
`DecisionDetailPage`, whose bloc calls `_repository.inspectDecision(_runId)` →
`workflowEndpoints.listDecisions(workItemId)` → `control_plane_service.dart:1492-1496`
`readWorkItem`, which throws `WorkItemNotFoundException`
(`postgres_workflow_store.dart:27-36`). A lifecycle decision's `workItemId` is the synthetic scope
`product-lifecycle:<productId>` (`lifecycle_decision_binding.dart:87`), not a WorkItem row. The
baseline path dodges this — it is resolved in place on the Product Detail screen, never via
needs-you (see the comment at `product_detail_page.dart:62-64`). The lifecycle path would need the
same treatment.

**(iii) `pendingDecisions` will never list a lifecycle gate.**
`home_endpoints.dart:209-250` enumerates `readAllWorkItems()` and keeps only items with
`blockingHumanDecisionId != null`. Lifecycle decisions hang off a synthetic scope, so they are
invisible to the Needs You board even in principle. `recentDecisions` (`:165-206`) has the same
shape.

**Conclusion for Q2:** the correct fix is (a) plus an in-place lifecycle gate on the Product
Detail screen, mirroring `_BaselineApprovalGate`. Not a route to needs-you. And `revokePolicy` is
a fourth thing again: not a decision gate at all but a direct attributed write
(`revokeStandingPolicy`), so it does not belong in this switch either.

---

## 3. Is there a gate problem specific to offboard? Would it succeed for our exact case?

**For a freshly-registered, keyless product with no baseline and no in-flight work: `offboard`
would SUCCEED. There is no refusal in our case.**

Traced through:

1. `availableFor(ProductStatus.registered, ...)` → `[GovernanceAction.offboard]`
   (`product_detail_bloc.dart:294-296`). Offered, correctly.
2. `requestLifecycleDecision` → `ProductTransitions.explainRejection(registered, archived)`
   (`product_registry_engine.dart:1212`). `(registered, archived)` **is** a legal edge
   (`product_transitions.dart:138-141`). `explainRejection` returns `null`; no
   `ProductLifecycleException`. The gate is created.
3. On approve, `resolveLifecycleDecision` → `transitionProduct(to: archived, satisfiedGuards:
   {offboardDecisionRecorded, decisionActorIsHuman, ...additionalGuards})`
   (`product_registry_engine.dart:1347-1356`).
4. Required guards for `(registered, archived)` are `offboardDecisionRecorded` and
   `decisionActorIsHuman` — **`noWorkInFlight` is not among them**
   (`product_transitions.dart:138-141`). Contrast `(governed, archived)` and `(paused, archived)`
   at `:127-136`, which *do* require it.

So for a `registered` product the transition is clean. Note the transition comment at `:137`:
"Onboarding may be abandoned before anything was ever governed" — the table deliberately waives
the drain guard where there is nothing to strand.

**The "refuses offboarding with work still in flight" line in
`product_registry_endpoints.dart:191-192` is about a different case and does not apply here.** It
is enforced at *resolve* time, not request time, and only for governed/paused products. The
request-time refusal at `:164-165` is a different check entirely — it is
`explainRejection`, i.e. "is this edge in the table at all". Both are real; neither blocks a
keyless registered product.

**However — and this is the finding that matters for scope — a governed product WOULD hit the
refusal, and the client cannot satisfy it.** `control_plane_repository.dart:222-243` hardcodes
`noWorkInFlight: false` and the endpoint only adds the guard when the caller passes
`noWorkInFlight: true` (`product_registry_endpoints.dart:218-220`). So for a `governed` product
the offboard gate raises fine and then **fails at approve** with
`ProductLifecycleException: unsatisfied no_work_in_flight`
(`product_registry_engine.dart:96-101`; the refusal is exactly the test at
`lifecycle_decision_test.dart:133-145`). The client as written can never pass that guard, and
offers the operator no drain/halt choice — the `drainInFlight` option is presented in the
decision's option text (`product_registry_engine.dart:1383-1386`) but nothing in the client ever
sets it from an operator choice.

So: **not a refusal in our case, but a latent one in the adjacent case, and a third defect the
brief did not identify.**

---

## 4. What should the operator see if it is refused?

Today: nothing. Two independent reasons.

1. The `catch` at `product_detail_bloc.dart:84-92` does set `errorMessage` — but it also passes
   `clearError: true` in the same `copyWith` (`:88`). `copyWith` resolves this as
   `errorMessage: clearError ? null : (errorMessage ?? this.errorMessage)` (`:246`), so
   **`clearError` wins and the message is discarded**. The catch block is inert as written. This
   is a real bug independent of the dead actions, and it is the reason a refusal — were one
   raised — would still be invisible.
2. Even with that fixed, the error surface is a **whole-page takeover**:
   `product_detail_page.dart:344-352` returns `DesignErrorState` in place of the entire screen,
   titled *"We could not reach the system's records."* That copy is a lie for a refused action —
   the records were reached fine; the engine declined. It also destroys the operator's context
   (the product they were looking at) and its retry re-runs `ProductDetailLoaded`
   (`:348-350`), which cannot fix a refusal.

**Minimum honest fix, and it is small:**

- Fix the `catch`: drop `clearError: true` from `:88`. One line. Without it nothing else matters.
- Do **not** route action failures into the page-level `errorMessage`. That field means "we could
  not read the registry" and is rendered as such. Add a separate, action-scoped failure field
  (e.g. `governanceError`) surfaced **inside the Governance panel**
  (`product_detail_page.dart:847-859`, next to the actions that produced it), using
  `DesignPanel` with `edgeColor: palette.negative` — the same primitive `DesignErrorState` already
  uses (`state_views.dart:296-299`), so no new design-system surface.
- Copy must name the refusal, not the transport. The server sends a real reason string
  (`product_transitions.dart:190`: *"no legal transition from X to Y"*; engine `:98-99`:
  *"unsatisfied no_work_in_flight"*). Surface that verbatim in the panel, plus one plain sentence
  saying nothing was changed. `DesignErrorState`'s existing string
  *"Nothing has been changed. No decision was recorded..."* (`state_views.dart:311-312`) is
  exactly right and should be reused rather than reworded.
- The state already has the right flag: `isRaisingGate` (`:210`) is set and cleared but **read by
  nothing** (grep: only `product_detail_bloc.dart`). Wiring it to disable the tapped action while
  in flight is the honest affordance and costs almost nothing.

Accessibility note: the actions are `InlineLink` (`design_primitives.dart:195-243`), which is
`Semantics(link: true)` on a `GestureDetector` — no focusable node, no `button` role, no
disabled state. An error panel appearing next to a link the operator just activated needs
`Semantics(liveRegion: true)` to be announced, and the failing action needs a focusable,
`button: true` target. `FilterTabs` already does this correctly
(`design_primitives.dart:899-900`), so the pattern exists in-repo.

---

## 5. Customer-visible consequence: archived products vanish from `/products`

**Confirmed as described, and it is a real UX defect — but a second-order one, and not the one to
fix first.**

- `ProductStatus.archived('Archived', 'Kept for good; no new work can be created')` —
  `product_language.dart:33-34`. The brief's "Kept for good" is the second string; the chip label
  is "Archived".
- `ProductFilter.all => status != ProductStatus.archived` — `products_bloc.dart:150`.
- The list filters on it at `products_page.dart:78-80`. Default filter is `all`
  (`products_page.dart:57`).

So an offboarded product disappears from the default view and reappears under **Archived**
(`products_bloc.dart:142,154`). It is never deleted, and the Product Detail screen says so
explicitly when archived (`product_detail_page.dart:860-867`). The archive is also
non-destructive by construction — `ProductState.archived` freezes the baseline
(`product_state.dart:52-57`) and `lifecycle_decision_test.dart:161-173` asserts history stays
readable.

**Assessment: intended, with one genuine gap.** The filter set deliberately includes a dedicated
`Archived` tab, and the detail screen explains the retention. The real problem is narrower than
"it vanishes": **the operator gets no confirmation that anything happened.** The tap is silent
(§1), the page does not change, and if offboarding is later wired the operator will be navigated
to a decision screen with no indication that the product they are looking at is about to leave
their default list. The minimum honest fix is a consequence line at the point of action — the
`revokePolicy`-style "STANDING POLICY"/"DEPLOY KEY" fact rows in the panel
(`product_detail_page.dart:820-846`) already establish the pattern; an "Offboarding archives this
product and removes it from All products" note beside the action covers it. **Do not change the
filter predicate.** Changing `ProductFilter.all` to include archived would be a Level 2 IA change
and is not warranted by this defect.

---

## Findings, by severity

### BLOCKER

**B1. `pendingDecision` has no consumer in the production widget tree.**
`product_detail_page.dart:41-47` mounts the `BlocListener` only on the test-injected branch
(`bloc != null`). Production builds a bare `BlocProvider` at `:51-56`. Consequence:
`proposeBaseline` and `reviewBaseline` raise a durable server-side gate and then display nothing —
they are as invisible as the four dead actions, just less harmless. Any fix that only widens the
dispatch switch leaves this half-wired.

**B2. The lifecycle resolve half does not exist in the client.**
`ControlPlaneRepository.resolveLifecycleDecision` (`control_plane_repository.dart:222-243`) has
zero callers under `apps/control_plane/lib`. Wiring the raise without the resolve creates a
`blocking: true` gate nobody can action — the exact failure
`product_registry_endpoints.dart:164-165` claims to prevent.

**B3. The needs-you route cannot render a lifecycle decision.**
`DecisionDetailPage` → `inspectDecision` → `workflowEndpoints.listDecisions` →
`readWorkItem` throws for the synthetic scope `product-lifecycle:<id>`
(`postgres_workflow_store.dart:27-36`; scope at `lifecycle_decision_binding.dart:87`).
`pendingDecisions` (`home_endpoints.dart:217-242`) likewise cannot list it. The lifecycle gate
must be resolved **in place on Product Detail**, mirroring `_BaselineApprovalGate`, not routed.

### HIGH

**H1. The `catch` in `_onGovernanceActionRequested` is inert.**
`product_detail_bloc.dart:88` passes `clearError: true` alongside `errorMessage`, and `copyWith`
(`:246`) gives `clearError` precedence. Every governance failure is swallowed at the source.

**H2. `revokePolicy` throws rather than acting.**
`product_detail_bloc.dart:124` `UnimplementedError('revocation needs productId + policyId')`. Both
values are in scope. Server support is complete
(`product_registry_endpoints.dart:295-308`). It is also the wrong shape — revocation is an
attributed write, not a decision gate, so it does not belong in the decision switch.

**H3. `noWorkInFlight` is hardcoded `false`; a governed product's offboard can never be approved.**
`control_plane_repository.dart:227`, gated at `product_registry_endpoints.dart:218-220`. The
engine requires the guard for `(governed|paused, archived)` (`product_transitions.dart:127-136`)
and refuses without it (`product_registry_engine.dart:96-101`). The engine even offers the
operator a drain/halt choice in the decision's option text (`:1383-1386`) that no client ever
reads. Wiring offboard without this ships a second dead control for governed products.

### MEDIUM

**M1. Failures render as a whole-page takeover with the wrong copy.**
`product_detail_page.dart:344-352` — *"We could not reach the system's records."* for what is a
refusal. Destroys context; retry cannot help.

**M2. `isRaisingGate` is set, cleared, and read by nothing.** No in-flight affordance on any
action. Tapping twice fires two requests.

**M3. Actions are `Semantics(link: true)` on a `GestureDetector`.**
`design_primitives.dart:221-228`. No focusable node, no `button` role, no disabled state. An error
surfaced beside them needs a live region and a focusable target to be usable by keyboard or
screen-reader operators. `FilterTabs` (`:899-900`) is the in-repo pattern to copy.

**M4. `_decisionFor` is an identity function that discards its `productId` argument.**
`product_detail_bloc.dart:253-254`. Confusing dead weight in the exact switch being repaired.

### LOW

**L1. Offboarding gives no consequence statement.** See §5. One sentence beside the action.

**L2. `_gate`'s comment is stale** — `:110-111` says "Every other action — pause, resume, offboard,
revocation — is a lifecycle decision", which is false of `revokePolicy` (it is a policy write).

**L3. `_decisionFor` and the `pendingDecision` doc comment disagree with reality.**
`product_detail_bloc.dart:207-209` says "The UI routes to the needs-you surface with this id."
Per B1/B3 it does not, in production, for any of these decisions.

---

## Traceability

| Question | Answer | Primary evidence |
|---|---|---|
| Q1 diagnosis complete? | No — 3 defects, not 1; `proposeBaseline`/`reviewBaseline` also half-wired | `product_detail_bloc.dart:64-76,96-128`; `product_detail_page.dart:37-56` |
| Q1 other dead actions? | All 4: `pause`, `resume`, `offboard`, `revokePolicy` | `product_detail_bloc.dart:112-126,274-300` |
| Q1 dialog only consumer? | Yes, and in production there is no consumer at all | repo-wide grep, `product_detail_page.dart:43` |
| Q2 (a) or (b)? | **(a)** — `availableFor` matches the transition table; (b) would delete working capability | `product_transitions.dart:111-145`; `lifecycle_decision_test.dart:252-268` |
| Q2 both halves for baseline? | Baseline: yes, split across panel + inline gate. Lifecycle: **no resolve half at all** | `product_detail_bloc.dart:146`; `control_plane_repository.dart:222` (0 callers) |
| Q3 would offboard succeed? | **Yes** for registered/keyless — `(registered, archived)` is legal and omits `noWorkInFlight` | `product_transitions.dart:138-141`; `product_registry_engine.dart:1212,1347-1356` |
| Q3 if refused, with what? | Not refused here. For *governed*: `ProductLifecycleException: unsatisfied no_work_in_flight` at approve | `product_registry_engine.dart:96-101`; `product_transitions.dart:127-136` |
| Q4 error surface exists? | `DesignErrorState` at `:344-352`, but wrong copy + whole-page. And the `catch` is inert (H1) | `product_detail_page.dart:344-352`; `product_detail_bloc.dart:88,246` |
| Q5 archived vanishing | Real but intended; missing piece is confirmation, not the filter | `products_bloc.dart:142,150,154`; `product_language.dart:33-34`; `product_detail_page.dart:860-867` |

Requirements/architecture traced: ADR 0013 (durable human gate), ADR 0018 (lifecycle, non-delete),
ADR 0019 (non-delegable offboarding, policy revocation), `DESIGN_GOVERNANCE.md` risk levels,
AGENTS.md §11 (rationale is part of the decision). No requirement is orphaned; the gap is
implementation reachability, not design coverage.

---

## Recommended scope for the implementation lane

**IN SCOPE — wire these**

1. **Add an in-place lifecycle gate to Product Detail**, modelled on `_BaselineApprovalGate`
   (`product_detail_page.dart:70-85, 400-414`): a new `LifecycleDecisionResolved` event, a
   handler calling `repository.resolveLifecycleDecision`, and a panel that renders the raised
   decision's question, options, a required rationale, and the outcome buttons. Rationale is
   mandatory, per the existing baseline gate and AGENTS.md §11. **Do not route to
   `/needs-you/<id>`** — that path cannot read a synthetic-scope decision (B3).
2. **Route `pause` / `resume` / `offboard` in the dispatch switch** to the `_gate` arms that
   already exist (`product_detail_bloc.dart:112-123`) and set `pendingDecision` from the result,
   exactly as the two baseline arms do. Delete `_decisionFor` and its two call sites (M4).
3. **Mount the navigation/listener in the production branch** (B1) — or, if the in-place gate from
   (1) makes navigation unnecessary, delete the `BlocListener` and drop `pendingDecision` entirely
   rather than leaving a field that is written in one build configuration and read in another.
   Prefer the second: it is less machinery and matches how baseline already works.
4. **Honour the drain choice for offboard** (H3): surface "let running work finish" vs "stop it
   now" at request time, thread it into `requestLifecycleDecision(drainInFlight:)` **and** into
   `resolveLifecycleDecision(noWorkInFlight:)` so a governed product's offboard can actually be
   approved. Without this, offboard works for `registered` and is permanently broken for
   `governed`/`paused`.
5. **Fix the `catch`** (H1): drop `clearError: true` from `product_detail_bloc.dart:88`. Without
   this, no error from any of the above is visible.
6. **Add an action-scoped error surface inside the Governance panel** (§4): new state field, a
   `DesignPanel` with `edgeColor: palette.negative` beside the actions, the server's reason string
   verbatim, and the existing *"Nothing has been changed…"* line reused unchanged. Do **not** route
   it into the page-level `errorMessage`.
7. **Wire `isRaisingGate`** to disable the in-flight action (M2), and give the actions a
   focusable `button: true` target with a `liveRegion` on the error panel (M3), following
   `FilterTabs`.
8. **Implement `revokePolicy` separately** (H2): call `repository.revokeStandingPolicy` with
   `productId` + `livePolicies.firstOrNull.policyId` + `revokedBy: 'operator'`, then re-read the
   detail. It is an attributed write, not a gate — keep it out of the decision switch.

**LEAVE ALONE — out of scope, deliberately**

- `ProductFilter.all` (`products_bloc.dart:150`). The `Archived` tab exists; the retention is
  intentional and server-enforced. Changing it is a Level 2 IA change not warranted here.
- The engine, `ProductTransitions`, `ProductState`, and both endpoints. They are correct; every
  capability the client needs already exists server-side.
- `reinstate`. Supported server-side, absent from `GovernanceAction` (`:261-267`), and
  `availableFor` correctly offers archived products nothing (`:299`). Out of scope — that is a
  product decision about reinstatement, not a bug fix.
- The two inline-gate `copyWith` nullability quirks (`:249`) and the `DesignErrorState` reuse in
  `decision_detail_page.dart:84-91`. Noted, not in this lane.

**SURFACE TO THE OPERATOR**

- **Now, before any code ships:** the four actions are dead, and so are the two that appear to
  work. Nothing in the UI says so. This is a control that lies about its own capability.
- **After the fix:** a refusal must name itself in plain language, in place, saying what did not
  change. A gate raised must be resolvable from the screen that raised it.
- **At the moment of offboarding:** one sentence saying the product will be archived and will
  leave the "All products" list, while remaining readable under "Archived" (L1). This is the
  minimum honest handling of §5.

---

## Risk assessment (independent)

Per `DESIGN_GOVERNANCE.md` §Design-Change Risk Levels.

**INDEPENDENT_RISK_LEVEL: 2** — Feature UX Change. "Change to user flow, interaction pattern, or
feature-level UX that affects user behavior."

Rationale: this adds a working interaction (tap → gate → resolve) to a screen that today has
none, introduces a resolve panel that does not exist, and changes what a destructive-sounding
action actually does to the operator's product list. Behaviour, not just rendering, changes.

Not 3: no navigation-structure change (the gate stays in place on Product Detail, matching the
existing baseline gate), no IA change, no effect on other features' mental models.

Not 1: the fix introduces a new interactive surface and a new durable-write path. Design-system
tokens and components are reused (`DesignPanel`, `InlineLink`, `palette.negative`), so
design-system compliance is not the risk — user-visible behaviour is.

**HUMAN_DECISION_REQUIRED: YES** on one point, which I am escalating rather than resolving
because it is a product decision and not a defect:

> **Should `offboard` be offered for a `governed` product at all, given that offboarding a
> governed product permanently ends its ability to dispatch work and cannot be undone without a
> fresh baseline review (`ProductLifecycleAction.reinstate` targets `baselineReview`, not
> `governed` — `lifecycle_decision_binding.dart:26-29`)?** Today `availableFor` offers it from
> `governed` and from `paused` with no confirmation, no consequence statement, and no drain/halt
> choice (H3, L1). The engine permits it and the UI is not wrong to offer it. Whether a
> one-tap-to-archive of a live governed product should carry an explicit typed confirmation is a
> product/design call about the cost of a mistaken tap, not something I should settle.

Everything else in this assessment I consider ready to implement as scoped above, at Level 2,
with the human decision above recorded before or alongside it.
