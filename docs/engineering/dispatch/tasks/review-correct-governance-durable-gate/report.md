# Focused re-review — correct-governance-durable-gate

**Lane:** focused re-review (read-only on production code).
**Worktree:** `/private/tmp/shipit-fix-governance`, branch `fix/governance-panel`.
**CORRECTED_FROM_HEAD:** `0bc016a97b70eb8a6baca593290d0fd58b244016`
**REVIEWED_HEAD:** `debde6e48d65f405a29d6852071b5901758b9ed7`
**Prior blocking review:** `review-fix-governance-panel/report.md` (B1).
**Docker/Compose commands issued:** one `docker compose -p shipit_review_rr_96791 … up -d --wait
postgres_integration` and one matching `down -v --remove-orphans`, both under my own project name in
a **throwaway `git worktree`**. No `make clean`, no `qa-down`, no `test-env-down`, no `e2e-down`,
no bare `down -v`, no `docker ps/logs/config/info` against the QA project. Nothing was redeployed or
restarted.

---

## 1. Verdict

**B1 is closed at the root.** Not mitigated, not surfaced — the gate is durable state read from the
registry on every load, and I verified the specific claim I could not previously confirm: **an
already-stranded product is genuinely drainable through this screen**, driven through the real
engine and the real endpoint against Postgres, in the exact Probe C state I created in my prior
review.

Every one of the eight items the dispatch asked me to check is verified. Both disclosures are
honest, and one of them I closed myself. The declined residual is correctly characterised and does
not gate this merge.

```
RESULT: APPROVE_CORRECTIONS
```

---

## 2. Provenance

| Check | Result |
|---|---|
| `git rev-parse HEAD` | `debde6e48d65f405a29d6852071b5901758b9ed7` — matches `NEW_HEAD` |
| Commits since `CORRECTED_FROM_HEAD` | `8befb92` (server), `c692a49` (server tests), `debde6e` (client) — matches report §11 |
| `git status` | clean before and after my review |
| Diff scope | 15 files, `+1652 / −544` — **exactly** report §14 |
| Parent of `8befb92` | `0bc016a` — the reviewed HEAD. Nothing rewritten. |

Provenance matches what was reported. No history was rewritten; the correction is a forward commit
chain on the reviewed HEAD.

---

## 3. B1 CLOSED AT THE ROOT — verified structurally, not by claim

### The client no longer derives gate state from the raise response

Confirmed by reading the diff, and confirmed by absence:

```
rg "pendingLifecycleDecision|pendingLifecycleAction" apps/control_plane/ apps/server/lib/
  → no matches (excluding pendingLifecycleGate)
```

The two state fields are **deleted, not kept alongside** — they are gone from the constructor, the
field declarations, and `copyWith` alike. What remains:

```dart
LifecycleGateResponse? get openLifecycleGate => detail?.pendingLifecycleGate;
bool get lifecycleGateOpen => openLifecycleGate != null;
```

And the raise response is genuinely discarded (`product_detail_bloc.dart:145`):

```dart
case GovernanceAction.pause:
case GovernanceAction.resume:
case GovernanceAction.offboard:
  await _repository.requestLifecycleDecision(          // return value dropped
    productId: event.productId,
    action: event.action.lifecycleWire!,
  );
  final detail = await _repository.getProductDetail(event.productId);
  emit(ProductDetailState(isLoading: false, detail: detail));   // re-read, nothing remembered
  return;
```

The `final decision = await …` binding is gone. There is no longer a place in the client where a
gate can be remembered instead of read. Both consumers moved with it: `product_detail_page.dart:678`
(`gateOpen = state.lifecycleGateOpen`) and `:737` (the render condition), and the resolve path
(`product_detail_bloc.dart:182`) now matches on `state.openLifecycleGate?.decisionId`.

### The root, not the surface

The server side is the actual fix, and it is real code rather than a client workaround:

- `ProductDetailView.pendingLifecycleGate: ProductLifecycleGateView?` — a **new Serverpod model
  field**, declared in `product_detail_view.yaml` and generated on both sides.
- `ControlPlaneService.openLifecycleGate` reads
  `readHumanDecisionsForScope(LifecycleDecisionBinding.scopeFor(productId))` and returns the first
  unresolved decision whose binding names this product.

The scope/product-id guard is correct and load-bearing, and I checked the reasoning in the comment
against the engine rather than accepting it: a lifecycle decision hangs off the synthetic scope
`product-lifecycle:<id>`, `pendingDecisions()`/`recentDecisions()` enumerate WorkItems, so this
read genuinely is the only discovery path. The `binding.productId != productId` skip is defensive but
correct — and `binding == null` also skips a non-lifecycle decision recorded at the same scope,
which is right: this screen cannot action one.

**One asymmetry worth noting, because the report does not mention it and it is harmless:** the
ordering it relies on (`updatedAt ASC`) is produced by the *production* store only.
`in_memory_human_decision_store.dart:25` sorts explicitly; `workflow_store`'s in-memory and
file-JSON implementations return an unsorted list; `postgres_workflow_store.dart:169` sorts with
`ORDER BY "updatedAt" ASC`. So the "oldest first" guarantee holds in production and under the
integration suite (which uses the Postgres store), and would be *unordered* on the file-JSON
dev-store path. That path has no lifecycle decisions in practice, and no test depends on it. Not a
finding; recorded so nobody later reads "oldest first" as a store-independent invariant.

---

## 4. THE OLDEST-GATE ORDERING CLAIM — tested, and it holds

The dispatch asked me to test this rather than reason about it, because the lane's own drain test
resolves with `reject`, which **skips** the staleness check at
`product_registry_engine.dart:1301-1313`. That means the lane's test does **not** prove my harder
Probe C case: a `pause` gate stranded on an **archived** product, where `approve` provably throws
`StaleBaselineApprovalException`.

So I reproduced my exact Probe C against the real engine and the real endpoint, on a disposable
Postgres, in a throwaway worktree:

```
PROBE C: pause=plc-pause-probe-c-fixture  offboard=plc-offboard-probe-c-fixture
PROBE C: product state after offboard = archived
PROBE C: decision plc-pause-probe-c-fixture  status=pending blocking=true     ← THE STRAND
PROBE C: decision plc-offboard-probe-c-fixture status=resolved blocking=true
PROBE C: productDetail.pendingLifecycleGate = plc-pause-probe-c-fixture action=pause
                                                       status=pending blocking=true
PROBE C: resolve(reject) -> ACCEPTED
PROBE C: after resolve(reject), pendingLifecycleGate = NULL
PROBE C RESULT: DRAINABLE. still-pending decisions = 0
```

This is the state that was, in my prior review, permanently unresolvable. It is now surfaced by the
durable read and resolvable. I also checked that the screen can *render* it:
`product_detail_page.dart:735-738` renders the gate whenever `state.lifecycleGateOpen`, with no
condition on product state, so an `archived` product still shows it — the drain is reachable by an
operator, not merely by an API caller.

**The claim is true, and stronger than the lane demonstrated.** The honest nuance is that recovery
goes through the `decline` / "Leave as is" outcome, not `proceed`: approving a pause against an
archived product is correctly refused by the engine's staleness guard. That is the right behaviour —
the guard is doing its job — and "Leave as is" is exactly the truthful outcome for a product that is
already archived. So the strand is *drainable*, though not *proceedable*. The lane did not claim
proceedability, and I did not find it claimed anywhere.

---

## 5. THE STRAND REPRODUCTION — reproduced independently

### 5.1 Red at `0bc016a`

I re-ran the strand at the reviewed HEAD myself. **The five new tests as committed do not compile
against `0bc016a`** — they reference `LifecycleGateResponse` and the `pendingLifecycleGate`
parameter, neither of which exists there:

```
error • Undefined class 'LifecycleGateResponse'. … test:130
error • The named parameter 'pendingLifecycleGate' isn't defined. … test:173
5 issues found.
```

That is expected and is *not* a discrepancy with the report: the report says the tests were written
"using only the API that existed there", i.e. they were authored against the old surface first,
failed, and were then adapted as the durable field was introduced. The **substance** of the claim is
what matters, so I authored my own probe against the `0bc016a` API and ran it:

```
RED probe: gate visible immediately after raise = 1
RED probe: gateVisible=0 pauseOffered=1 offboardOffered=1
Expected: a value greater than <0>
  Actual: <0>
```

That is my original Probe A, reproduced independently at the reviewed HEAD: after leaving and
returning, the blocking gate is invisible and both lifecycle actions are offered. The same probe
ported to the durable API at `debde6e`:

```
GREEN probe: gateVisible=1 pauseOffered=0 offboardOffered=0
All tests passed!
```

Red → green, same probe, both ends verified by me. Note also *why* the old API made the test
unwritable: `ProductDetailResponse` had no lifecycle field for the fake to populate, which is the
absence the fix removes.

### 5.2 Both mutations reproduce

| # | Mutation | Lane claimed | **I measured** |
|---|---|---|---|
| 1 | client `openLifecycleGate => null` | 15 of 38 | **15 of 38** — `+23 -15`, all five strand tests among them |
| 2 | server `openLifecycleGate` never returns a gate | 2 of 3 new server tests | **2 of 3** — exactly *surfaces the open lifecycle gate* and *drainable, oldest first* |

Both reverted; `git status` clean; gates re-run green afterwards. The lane's numbers are accurate
to the unit.

I also verified the lane's self-disclosure about the third server test: under mutation 2 it
**passed**, confirming it is vacuous against a server that surfaces nothing. The lane says so
plainly rather than claiming it as coverage. That is the correct call, and I agree with its
reasoning that the scope lookup already scopes by product.

---

## 6. THE TWO DISCLOSURES — both judged

### 6a. The edited test assertion — honest, and the real claim survives

The production string changed from *"A decision raised from this screen is open above"* to *"A
lifecycle decision is open above. Record it there before raising another."*

**This is honest, and it was necessary.** The old copy became literally false the instant the gate
outlived the screen: on return, this screen did not raise the gate. Shipping the old string would
have been a false statement in the UI, not merely a stale test. Changing production copy to keep a
test's string is the inverse of the usual test-weakening move, and here the truth runs toward
correctness.

**The test still asserts the real claim.** The load-bearing assertion in *"the action list is
withdrawn while a gate is open"* is untouched and still structural:

```dart
expect(find.text('Offboard this product'), findsNothing);   // still there, unchanged
expect(find.textContaining('A lifecycle decision is open'), findsOneWidget);  // string follows copy
```

The claim being tested — the action list is withdrawn while a gate is open — is unaffected by the
wording. And the new copy string is asserted in **three** places now, so the wording is pinned by
more coverage than before, not less.

**Nothing else was weakened.** Across both test directories the entire correction contains exactly
**one** deleted line, and it is the disclosed one:

```
-        find.textContaining('A decision raised from this screen is open'),
```

No test deleted, no `@Ignore`/`@Skip`, no filter. Mutation 1 above independently proves the group
still bites.

### 6b. The unexecuted wire→response mapping — I closed it

The lane discloses that `ControlPlaneRepository.getProductDetail`'s translation from wire model to
`LifecycleGateResponse` is compile-checked but never executed, because every test fake overrides
`getProductDetail` wholesale and `Client.productRegistryEndpoints` cannot be shadowed without
subclassing the fenced `client.dart`.

**I judge the disclosure correct and the gap small — and then I closed it anyway.** Rather than
accept the reasoning, I executed the translation against the real generated classes:

```dart
// server ProductLifecycleGateView.toJson()  ->  generated client .fromJson()
// -> the repository's mapping, transcribed verbatim from control_plane_repository.dart
FIELD-FOR-FIELD AGREEMENT WITH SERVER: EXACT
```

All nine fields round-trip identically, including the nested `DecisionContextView` and the
`DecisionOptionView` list. So the mapping is not merely type-checked — it is now *executed* and
correct, which converts the lane's "low consequence" estimate into a verified fact.

Worth recording for the framework: the lane's obstacle was an artefact of *this* test double's
shape, not an architectural wall. `server.toJson()` → `client.fromJson()` needs no client subclass
and no endpoint at all. The seam was reachable; the lane did not look for it. That is a process
observation for a future lane, not a defect in this correction.

---

## 7. THE RESIDUAL — declining to claim it closed is correct, and shipping is acceptable

Verified against the engine at `product_registry_engine.dart:1227-1235`: the idempotency check
requires `prior.action == action`, so a second, **different** gate is still accepted while one is
open. The lane's description of the residual is exact.

**I judge client-side withholding acceptable to ship, for a reason the lane states but does not
weigh:** the guard's absence no longer has an unreachable-consequence outcome. Before this
correction, an over-eager client could create a gate that *nothing on earth could ever resolve* —
that was B1. Now every gate the engine accepts is surfaced by the durable read and offered to the
operator with both outcomes, and §4 proves the previously-terminal state drains to zero. The
residual has been converted from **"silent permanent strand"** to **"a state an operator can see and
fix."** That is a genuine change in severity, not a relabelling: the engine-level guard is still
wanted, and `packages/product_registry` is read-only here — but the merge is no longer gated on it.

I record it as a **follow-up for the owning package**, not a blocker, and not merely because the
lane declined it.

---

## 8. NO MIGRATION — claim verified

| Claim | Verification |
|---|---|
| No model in `lib/src/models/` has a `table:` key | `grep -l '^table:' apps/server/lib/src/models/*.yaml` → **no matches** (exit 1) |
| `ProductDetailView` is a non-persisted `SerializableModel` | No `table:` ⇒ no `Table` ⇒ wire-contract type only |
| `pendingBaselineDecisionId` is precedent | Present on the same model; `grep -rn "pending_baseline\|pendingBaseline" apps/server/migrations/` → **no matches** |
| `migrations/**` untouched | `git diff --name-only 0bc016a..debde6e -- apps/server/migrations/` → **empty** |
| `verify_schema_bootstrap.sh` unaffected | **exit 0**, includes `no generated definition.sql claims these objects; the bootstrap is their only source` |

Verified rather than assumed. The dispatch's warning — *"a durable field is a Serverpod model field,
not a hand-maintained object"* — is honoured: `ProductLifecycleGateView` **is** a generated Serverpod
model on both sides, and nothing hand-maintained was put on the wire.

---

## 9. THE `client.dart` EXCEPTION — verified untouched

```
git diff 0bc016a..debde6e -- packages/control_plane_client/lib/src/protocol/client.dart
  → empty
```

Confirmed independently of the report. No endpoint method was added or changed; the fix needed no new
endpoint because the whole decision rides on the existing `productDetail` read. The `READ_ONLY`
exception is fully intact, and the reason given is correct rather than convenient.

---

## 10. PRIOR WORK NOT REGRESSED

Everything my prior review accepted survives at `debde6e`:

| Item | Verified |
|---|---|
| In-place panel in production | `_ProductDetailView` renders both branches identically; `_leaveRoute` disposes the bloc and the gate still returns — only possible via the production branch |
| All six actions routed | `proposeBaseline`, `reviewBaseline`, `pause`/`resume`/`offboard`, `revokePolicy` — no `_ => null` arm |
| Resolve path present and called | `resolveLifecycleDecision` invoked on `LifecycleDecisionResolved` (`:201`), matched against the durable `openLifecycleGate` |
| No needs-you routing | only `context.go('/products')` remains under `features/product_detail/**` |
| Action-scoped errors | `governanceError` → `_GovernanceError` in-panel, `liveRegion: true` (`:1321`, `:1442`) |
| `isRaisingGate` | present at `:114-117`, double-fire guarded |
| Accessibility | `Semantics` + `liveRegion` intact; gate renders on mobile too (`:702`) |
| `noWorkInFlight` as an explicit operator statement | `attestsNoWorkInFlight` still operator-sourced (default `false`, `:79`), not rubber-stamped; the "does not check it" copy is still asserted |
| `rework` wire fix | `request_correction` appears nowhere in `apps/control_plane/lib/` |
| Illegal-edge withholding | `availableFor` unchanged; `offboard` still offered only from states with a real edge |
| `revokePolicy` not throwing | real `revokeStandingPolicy` call with `_livePolicyId`; `UnimplementedError` absent from the whole client tree |
| 33 widget tests | **38** present (33 + 5 new); full suite **+309 all passed** |

The `paused` typed-fence deviation and the unmet `registered → baselinePending` criterion are
unchanged and remain as I recorded them in §8 of my prior review — human ratification items, not
defects, and not re-litigated here.

---

## 11. GATES — re-run independently

| Gate | Command | My result |
|---|---|---|
| Format | `dart format --output=none --set-exit-if-changed .` | **exit 0** — 768 files, 0 changed |
| Analyze (server) | `dart analyze apps/server` | **No issues found!** |
| Analyze (client) | `cd apps/control_plane && flutter analyze` | **No issues found!** |
| Test (client) | `cd apps/control_plane && flutter test` | **All tests passed! +309** — baseline 304, **+5**, exactly as claimed |
| Integration | `dart test test/integration/` (own disposable Postgres) | **+194 −1** — sole failure `dogfood_shipit_postgres_test.dart` |
| Generate | `serverpod generate` | **exit 0**, and `git status` **empty afterwards** — committed state is byte-identical to generator output, i.e. idempotent |
| Schema guard | `verify_schema_bootstrap.sh` | **exit 0** |

**The dogfood failure is the known linked-worktree artefact, confirmed not to be a regression.** In
my throwaway worktree `.git` is likewise a 64-byte gitdir pointer, and the test asserts
`Directory('${repoRoot.path}/.git').existsSync()` at line 88:

```
Expected: true
  Actual: <false>
  dogfood expects a git working tree at …/rr/probe
```

It fails **before doing any work**, and `git diff 0bc016a..debde6e -- …/dogfood_shipit_postgres_test.dart`
is empty. Not chased, correctly.

**Runtime/browser evidence:** none claimed, and none needed — every gate above is deterministic and
Docker-free except the sanctioned disposable Postgres.

---

## 12. Resource hygiene and worktree state

- My disposable Postgres ran under project **`shipit_review_rr_96791`** (never the QA project `docker`)
  and was removed with `down -v --remove-orphans`. Verified after: no container, no volume, no
  network carries that label.
- Per the dispatch's warning about `cp -R`, **every** mutation experiment used `git worktree add
  --detach` into `/var/folders/…/T/opencode/rr/`. The `red` worktree has been removed.
- **The reviewed worktree is pristine**, verified after all experiments:
  `git rev-parse HEAD` = `debde6e`, `git status --porcelain` → **empty**. The incident from my prior
  review did not recur, because the correct tool was used this time.
- No mutating Docker command touched the live QA stack. Nothing was redeployed or restarted.

---

## 13. Open items — none blocking

**Blockers: none.**

Non-blocking follow-ups to record (none gate this merge):

1. **Engine-level single-gate guard** — `ProductRegistryEngine.requestLifecycleDecision` still accepts
   a second, *different* lifecycle gate while one is open. Belongs in
   `packages/product_registry/lib/src/engine/product_registry_engine.dart` (read-only to this lane).
   Severity is now "an operator can see and fix it", not "nothing can ever fix it" (§7).
2. **The repository's wire→response mapping still has no standing test.** I verified it executes
   correctly today (§6b), but the lane's point stands as process feedback: the fix should leave a
   test behind, not just my one-off probe. A `toJson()` → `fromJson()` round-trip needs no endpoint
   and no `client.dart` subclass, so the infrastructure objection does not hold next time.
3. `readHumanDecisionsForScope`'s `updatedAt ASC` ordering is guaranteed by the Postgres store only;
   the file-JSON dev store returns unsorted. Harmless today; do not later treat "oldest first" as
   store-independent.
4. Carried forward from my prior review, unchanged: `noWorkInFlight` is caller-asserted and never
   verified server-side; `drainInFlight` is recorded and never read at resolve; the recorded
   decision `f9a043ae` does not name `paused` (ratify or overrule); the keyboard-activation test taps
   rather than sending a key event; `proposeBaseline` stays offered for `governed` and cannot succeed
   from this screen; `product_detail_baseline_bloc_test.dart` still builds its event with
   `request_correction`.

---

## 14. Required structured result

```
RESULT: APPROVE_CORRECTIONS

REVIEWED_HEAD: debde6e48d65f405a29d6852071b5901758b9ed7

FINDINGS_REVIEWED:
  B1 raised lifecycle gate was client-memory only        -> CLOSED AT THE ROOT
      * server: ProductDetailView.pendingLifecycleGate (new Serverpod model field,
        ProductLifecycleGateView), read from the decision store on every load
      * client: pendingLifecycleDecision/.pendingLifecycleAction DELETED (zero
        references remain); openLifecycleGate/lifecycleGateOpen derived from the
        durable read
      * the raise response is discarded, not stored (product_detail_bloc.dart:145)
      * no place remains in the client where a gate can be remembered
  oldest-gate ordering claim                            -> VERIFIED BY TEST
      * reproduced my exact Probe C on a real Postgres: a plc-pause gate stranded
        on an ARCHIVED product is surfaced by productDetail and drained to zero
        pending decisions. Recovery is via "Leave as is", not "proceed" — approve
        is correctly refused by the engine's staleness guard.
      * the gate renders for an archived product, so the drain is operator-reachable
  strand reproduction (red first, then green)           -> REPRODUCED INDEPENDENTLY
      * at 0bc016a the committed tests do not compile (expected; they were authored
        against the old API first). I authored my own probe on the old API: FAILS
        at 0bc016a (gateVisible=0, offboardOffered=1). Same probe at debde6e: PASSES
        (gateVisible=1, offboardOffered=0).
      * mutation 1 (client openLifecycleGate => null): 15 of 38 fail — as claimed
      * mutation 2 (server never returns a gate): 2 of 3 fail — as claimed; the
        third confirmed vacuous under it, exactly as the lane disclosed
  disclosure (a) edited test assertion / production copy   -> HONEST, CLAIM INTACT
      * the old copy was false once the gate outlived the screen; the change runs
        toward correctness, not away from it
      * the real assertion (action list withdrawn) is unchanged and structural
      * exactly ONE deleted line exists across both test dirs, and it is this one
      * the new copy string is now pinned in three places
  disclosure (b) unexecuted wire->response mapping        -> CLOSED BY THE REVIEWER
      * executed server toJson() -> generated client fromJson() -> the repository
        mapping transcribed verbatim: FIELD-FOR-FIELD AGREEMENT WITH SERVER: EXACT
      * the lane's stated obstacle was a test-double artefact, not a real wall
  residual: engine still accepts a second DIFFERENT gate   -> DISCLOSED CORRECTLY,
      not claimed closed. Severity materially reduced: every accepted gate is now
      surfaced and drainable, so the outcome is no longer a permanent strand.
      Acceptable to ship; follow-up belongs in packages/product_registry.
  no migration                                            -> VERIFIED (no table: key
      in any model; pendingBaselineDecisionId precedent absent from migrations/;
      migrations/** untouched; verify_schema_bootstrap.sh exit 0)
  client.dart READ_ONLY exception                         -> VERIFIED UNTOUCHED
      (git diff empty; no endpoint added — the whole decision rides the existing read)
  prior work not regressed                                -> VERIFIED — in-place panel,
      all six actions routed, resolve path present and called, no needs-you routing,
      action-scoped errors, isRaisingGate, accessibility, noWorkInFlight as an
      explicit operator statement, rework wire fix, illegal-edge withholding,
      revokePolicy not throwing, 38 widget tests (33 + 5) still biting

REGRESSIONS: none

BLOCKERS: none

GATES (re-run independently at debde6e):
  format=   pass  (exit 0; 768 files, 0 changed)
  analyze=  pass  (dart analyze apps/server: No issues found!;
                  flutter analyze: No issues found!)
  tests=    pass  (flutter test: +309 all passed, baseline 304, +5;
                  dart test test/integration/: +194 -1 — sole failure is
                  dogfood_shipit_postgres_test.dart, the linked-worktree
                  .git-as-a-file artefact, confirmed failing before it does any work
                  and untouched by this change)
  build=    pass  (serverpod generate exit 0 and idempotent — git status empty
                  afterwards; verify_schema_bootstrap.sh exit 0)
  runtime=  not-claimed (deterministic gates only; nothing driven against the live QA stack)

RESOURCE_HYGIENE:
  * disposable Postgres under project shipit_review_rr_96791, removed; no container,
    volume or network carries that label
  * all mutation work in detached `git worktree add` copies under the session temp dir;
    the "red" worktree removed. The cp -R incident of my prior review did not recur.
  * reviewed worktree verified pristine: HEAD debde6e, git status empty
  * ZERO mutating Docker commands against the live QA stack

READY_FOR_MERGE: YES
```
