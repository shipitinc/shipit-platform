# Report — correct-governance-durable-gate

**Lane:** correction. One blocker, B1.
**Corrected from:** `0bc016a97b70eb8a6baca593290d0fd58b244016` (`fix/governance-panel`)
**Produced:** `debde6e48d65f405a29d6852071b5901758b9ed7`
**Worktree:** `/private/tmp/shipit-fix-governance`, branch `fix/governance-panel`. Not pushed, not merged, `main` untouched (still `42999b2`).
**Docker/Compose commands issued:** only `make test-integration`, three times. No `make clean`, `make qa-down`, `make test-env-down`, `make e2e-down`, no bare `down -v`, no `docker ps`/`logs`/`config`/`info`, no `compose up` of any kind outside the sanctioned target.
**Paths touched:** only those granted. `client.dart` — the named exception — **not touched**; see §6.

---

## 1. Verdict

B1 is fixed at the root, not mitigated. The open lifecycle gate is now durable state read from the registry on every load, and every decision the screen makes about it derives from that read.

The two mitigations offered in the dispatch were both rejected. The "withhold actions whenever the screen cannot prove no gate is open" route is **not taken as a fallback** — the screen now always can prove it, because the proof is on the wire. And the client-only route was impossible under the path grant anyway, which this lane used.

```
RESULT: CORRECTION_COMPLETE
READY_FOR_FOCUSED_REVIEW: YES
```

---

## 2. The shape of the fix

Two halves, joined by one wire field. Neither half is sufficient alone, and that is deliberate — the reviewer proved the client-only version cannot work, and the server-only version would ship a field nobody reads.

### Server — the durable read (`8befb92`)

`ProductDetailView` gains `pendingLifecycleGate: ProductLifecycleGateView?`, a new Serverpod model.

`ControlPlaneService.openLifecycleGate` (`control_plane_service.dart:411`) reads
`readHumanDecisionsForScope(LifecycleDecisionBinding.scopeFor(productId))` and returns the
first unresolved decision whose `LifecycleDecisionBinding.tryFromMetadata` names this
product. Three properties worth stating:

- **It carries the whole decision, not just its id.** The panel needs the question, the
  engine's own outcome labels, and the blocking flag. A bare id would have forced a second
  endpoint purely to re-render what the first read already held.
- **The action comes from the decision's own binding metadata**, not from the raise call.
  This is load-bearing on the client (§4) and it is why `action` is a field rather than
  something inferred from the product's state.
- **Oldest first.** `readHumanDecisionsForScope` orders `updatedAt ASC`, so the oldest open
  gate wins. That is what makes an **already-stranded** product drainable rather than merely
  detectable: resolving the exposed gate reveals the next one on the following read. A
  product that already carries two blocking gates — the exact state the reviewer created —
  is repaired by using this screen, not merely detected by it.

A binding naming a different product is skipped.

### Client — derived, not remembered (`debde6e`)

`ProductDetailState.pendingLifecycleDecision` and `.pendingLifecycleAction` are **deleted**,
not kept alongside. In their place:

```dart
LifecycleGateResponse? get openLifecycleGate => detail?.pendingLifecycleGate;
bool get lifecycleGateOpen => openLifecycleGate != null;
```

The raise response is now **discarded** in `product_detail_bloc.dart:141` — the code awaits
the call, then re-reads the detail, and keeps nothing from the response. There is no longer a
place in the client where a gate can be remembered instead of read.

The asymmetry the reviewer named in §5 — `_baselineGate` commented *"driven by durable state"*,
`_lifecycleGate` immediately above it *"the gate this screen raised"* — is gone from the code
and from the widget's own doc comment.

---

## 3. Why one field and not two

The dispatch named `pendingLifecycleDecisionId` "(or equivalent)". I chose the equivalent,
for a specific reason.

`pendingLifecycleDecisionId` + a new read endpoint would force the client to make a **second
call** to render a gate it has just been told about — reintroducing a race in which the gate
is raised between the two reads and the panel renders nothing. Two nullable fields
(`pendingLifecycleDecisionId` + `pendingLifecycleAction`) can also drift apart, and drift
between them is exactly the class of bug this lane exists to remove: a panel that shows one
decision and fences for another.

One non-null-shaped field, `pendingLifecycleGate`, carries the decision **and** its action.
They cannot be inconsistent because there is nothing to keep in step.

`DecisionView` already existed and is a superset, but reusing it would have meant fabricating
`workItemTitle` and `decisionType` on the client for a synthetic scope that has no WorkItem —
inventing wire values to satisfy a type. `ProductLifecycleGateView` is a deliberate subset:
the fields the gate renders, and nothing else.

---

## 4. The attestation hole this also closed

`lifecycleOffboardNeedsWorkInFlightAssertion` used to read
`pendingLifecycleAction == GovernanceAction.offboard` — session memory. It now reads the
gate's durable `action`.

This is not cosmetic. It matters in both directions:

- An operator returning to a screen with an open **offboard** gate must still be asked to
  state that no work is running. Otherwise `ProductGuard.noWorkInFlight` — which the engine
  hands over on trust and never verifies — is satisfied by nobody saying it, and the exact
  governance weakness your prior report escalated (§11.2) silently widens from a server-side
  gap to a client-side bypass.
- An operator returning to an open **pause** gate must **not** be asked to attest about work
  that is not being archived.

Neither was reachable before, because before the gate was not shown at all on return. The
durable action is what makes both correct.

---

## 5. Tests

### 5.1 Red first, then green — the strand reproduces at the reviewed HEAD

All five new widget tests were written and run against `0bc016a` **before any production
change**, using only the API that existed there. All five failed:

```
00:02 +0 -5: Some tests failed.
Failing tests:
  ... an open lifecycle gate is durable, not client memory the gate is still on screen after leaving the route and returning
  ... an open lifecycle gate is durable, not client memory the returned gate resolves without raising a second one
  ... an open lifecycle gate is durable, not client memory a second lifecycle action is withheld while one is open
  ... an open lifecycle gate is durable, not client memory the actions return once the gate is resolved
  ... an open lifecycle gate is durable, not client memory the strand sequence cannot happen: leave, return, offboard — one gate only
```

Representative failure — the reviewer's own reproduction:

```
Expected: no matching candidates
  Actual: _TextWidgetFinder:<Found 1 widget with text "Offboard this product">
 Which: means one was found but none were expected
```

After the change:

```
00:07 +5: All tests passed!
```

The five map onto the dispatch's requirements:

| Required | Test |
|---|---|
| Leave, return, gate STILL SHOWN AND RESOLVABLE | *the gate is still on screen after leaving the route and returning*; *the returned gate resolves without raising a second one* |
| A second lifecycle action is withheld while one is open | *a second lifecycle action is withheld while one is open* |
| After resolving, the actions return | *the actions return once the gate is resolved* |
| The reviewer's exact sequence | *the strand sequence cannot happen: leave, return, offboard — one gate only* |

The strand test is the reviewer's sequence verbatim: raise Pause on a governed product, leave
to Products, return, attempt to offboard. It asserts the second action is **not offered**, that
only one lifecycle request was ever made, and that the operator's real next step — recording
the pause decision — still works.

`_leaveRoute` replaces the whole widget tree, so the `BlocProvider` is disposed and its bloc
closed. That is what leaving the route does, and it is why a gate held in bloc memory alone
cannot survive it.

### 5.2 The test double now models the server

`_GovernanceRepository.requestLifecycleDecision` records the gate on the fake and returns it
from the next `getProductDetail`; `resolveLifecycleDecision` clears it.

This matters more than it looks. A fake that only knew the gate in the response it had just
returned would pass against a client that keeps the gate in memory — it would have made all
five tests vacuous. The fake models durability because that is what the server does.

### 5.3 Server tests — the half a widget test cannot reach

Three tests in `product_registry_endpoints_e2e_test.dart`, against the real endpoint and the
real engine (`194` in the integration suite, of which these are 3):

- **re-derivable** — a fresh `productDetail` read with no connection to the call that raised
  the gate carries the whole decision, the engine's own `proceed`/`decline` options, and
  `blocking: true`; it disappears once resolved, and the transition really happened.
- **drainable** — a product already carrying two open gates, raised through the engine exactly
  as the reviewer's Probe C created them. The read exposes the `pause` gate; resolving it
  exposes the `offboard` gate. This is the repair path for already-stranded products.
- **not cross-product** — a gate raised on A is never surfaced for B.

`_governed()` drives a product to `governed` through the real engine (propose → verify →
request approval → approve), because a lifecycle gate is only raisable from there.

### 5.4 The tests bite — two mutations, both reverted

| # | Mutation | Result |
|---|---|---|
| 1 | Client `openLifecycleGate => null` (durable read replaced by session memory) | **15 of 38** governance tests fail, including all the strand tests |
| 2 | Server `openLifecycleGate` never returns a gate | **2 of 3** new server tests fail (`productDetail surfaces the open lifecycle gate`; `…is drainable, oldest first`). Integration suite `+192 -3`. |

Mutation 2 left `+194 -3` → `+192 -3`, the extra failure being dogfood which is present either
way. Both mutations reverted; `git status` clean at `debde6e`; all gates re-run green after.

**Disclosed weakness.** The third server test (`a gate is never surfaced for a different
product`) is **vacuous under mutation 2** — it asserts `isNull`, which a server that surfaces
nothing trivially satisfies. It is not load-bearing today: the scope lookup already scopes by
product, and the engine cannot produce a binding naming another product at a given scope, so
the `binding.productId != productId` check is defensive. The test is a cheap guard against a
future engine change that breaks that invariant; it is not evidence for anything today, and I
am not claiming otherwise.

---

## 6. `serverpod generate`

**Exit status: 0.** Re-run at the final HEAD: exit 0 and a clean `git status`, so the committed
generated state is exactly what the generator produces.

Generated files changed — 4 modified, 2 new, and **nothing else**:

```
 M apps/server/lib/src/generated/product_detail_view.dart
?? apps/server/lib/src/generated/product_lifecycle_gate_view.dart   (new)
 M apps/server/lib/src/generated/protocol.dart
 M packages/control_plane_client/lib/src/protocol/product_detail_view.dart
?? packages/control_plane_client/lib/src/protocol/product_lifecycle_gate_view.dart   (new)
 M packages/control_plane_client/lib/src/protocol/protocol.dart
```

**`packages/control_plane_client/lib/src/protocol/client.dart` was NOT touched.** No endpoint
method was added or changed — the fix needed no new endpoint, which is a direct payoff of
carrying the whole decision on the existing `productDetail` read. The whole of the
`READ_ONLY` exception is intact; `git diff 0bc016a..HEAD -- …/protocol/client.dart` is empty.

The bulk of the `protocol.dart` churn (+463/−… on each side) is the generator renumbering its
type-alias imports after a new model is inserted; it is generated, not authored.

---

## 7. Migration — none needed, and why that is the correct answer

**No migration was created, and none was required.** This is a verified finding, not a
shortcut:

- Every model under `apps/server/lib/src/models/` declares **no `table:` key** — `grep -l
  '^table:' apps/server/lib/src/models/*.yaml` returns nothing. `ProductDetailView` is a
  `SerializableModel` with no `Table`, so it is a wire-contract type, not a schema one.
- `ProductDetailView.pendingBaselineDecisionId` is the direct precedent: the same model, the
  same kind of field, and it appears in **no** `migrations/*/`. `grep -rn "pending_baseline"
  apps/server/migrations/` → no matches.

So the dispatch's warning — *"a durable field is a Serverpod model field, not a
hand-maintained object"* — is honoured: the field **is** a Serverpod model field
(`ProductLifecycleGateView`), and nothing hand-maintained was put on the wire.

`bash apps/server/tool/verify_schema_bootstrap.sh` — **exit 0, 20 `OK`, 0 `FAIL`**, including
the two checks the dispatch named:

```
OK: index design_revision_approved_unique_per_work_item declares byte-identical DDL in both homes
OK: index product_credential_active_repository_unique declares byte-identical DDL in both homes
OK: no generated definition.sql claims these objects; the bootstrap is their only source
```

I read `apps/server/tool/schema_bootstrap.dart`'s header before touching anything under
`migrations/`, which is how the no-table finding was established. `migrations/**` is
untouched by this change.

---

## 8. Gates — all re-run at `debde6e`

| Gate | Command | Result |
|---|---|---|
| Deps | `dart pub get` (repo root) | **pass**, exit 0 |
| Format | `dart format --output=none --set-exit-if-changed .` | **pass**, exit 0 — `768 files (0 changed)` |
| Analyze (server) | `dart analyze apps/server` | **pass** — `No issues found!` |
| Analyze (client) | `cd apps/control_plane && flutter analyze` | **pass** — `No issues found!` |
| Test (client) | `cd apps/control_plane && flutter test` | **pass** — **`+309`, all passed** (baseline 304, **+5**) |
| Integration | `make test-integration` | **`+194 -1`** — see below |
| Generate | `serverpod generate` | **exit 0**, idempotent at final HEAD |
| Schema guard | `verify_schema_bootstrap.sh` | **exit 0**, 20 OK / 0 FAIL |

### `make test-integration` — the real number

**`+194 -1`. 194 passed, 1 failed. The sole failure is `dogfood_shipit_postgres_test.dart`,
and it is the known linked-worktree cause — not chased, as instructed.**

Confirmed rather than assumed: `/private/tmp/shipit-fix-governance/.git` is an **80-byte
regular file** (a gitdir pointer), and the test asserts
`Directory('${repoRoot.path}/.git').existsSync()` is `isTrue` at line 88. A `cp -R` or
worktree checkout has no `.git` directory, so the assertion fails before the test does any
work. I changed nothing in that file's dependency set:
`git diff --stat 0bc016a -- apps/server/test/integration/dogfood_shipit_postgres_test.dart` is
empty.

The arithmetic is consistent with a linked worktree: a primary clone reports `+192` passing;
`194 = 192 + 3` new tests, minus the 1 dogfood failure reported alongside them.

The disposable project `shipit_integration_*` was torn down on all three runs; the trap
printed `Container … Removed` / `Network … Removed` each time. No `CLEANUP FAILED`.

**No runtime/browser evidence is claimed.** This lane changed the Product Detail read and the
Governance panel, and demonstrating that against the live QA stack would have required driving
the stack you told me you are holding. Every gate above is deterministic and Docker-free except
the sanctioned `make test-integration`.

---

## 9. Constraints

| Constraint | Compliance |
|---|---|
| Zero mutating Docker/Compose outside `make test-integration` | 3 `make test-integration` runs, nothing else |
| Never `make clean` / `qa-down` / `test-env-down` / `e2e-down` / bare `down -v` | none issued |
| Never print/log/echo private key material | none. The one credential used is the integration database password, passed as an environment variable on the command line; it is the committed development value from `docker/compose.*.yaml`, not key material, and no repository file, log or message received it |
| No test weakened, skipped, `@Ignore`d, filtered or deleted | none — **with one disclosed change, below** |

**The one test edit you should judge.** `product_detail_governance_test.dart`'s
*the action list is withdrawn while a gate is open* asserted the string
`"A decision raised from this screen is open above"`. That copy became **false** the moment a
gate could outlive the screen, so the production string is now *"A lifecycle decision is open
above. Record it there before raising another."* and the assertion follows it.

The test's actual claim — that the action list is withdrawn while a gate is open — is unchanged
and still asserted (`find.text('Offboard this product'), findsNothing`). Only the quoted copy
moved. No assertion was weakened, removed or made conditional. Mutation 1 above shows the test
still bites.

**Nothing deleted.** `git diff 0bc016a..HEAD -- apps/control_plane/test/` contains zero deleted
lines outside the edited assertion string.

The mobile golden `product_detail_mobile_back_link{,_dark}.png` passes unchanged. No golden
PNG was regenerated — `git diff --stat 0bc016a..HEAD -- '*.png'` is empty — and the Governance
panel is unchanged for a product with no open gate, so the pixels it asserts are the same
pixels. The mobile golden test is among the 309 passing.

---

## 10. Known limit, disclosed

**The repository's wire→response mapping is covered by the type checker, not by a test.**
`ControlPlaneRepository.getProductDetail` is the seam between the two halves this fix joins:
the server test proves the field is *served*, the widget tests prove it is *consumed*, and
nothing executes the translation between them.

Every consumer of that mapping is the test fake `MockRepository`, which overrides
`getProductDetail` wholesale. Reaching the real body would mean injecting a stub endpoint
group, and `Client.productRegistryEndpoints` is assigned in the generated constructor — shadowing
it needs a subclass of a `client.dart` type, which is the one file the path grant fenced off.
I judged building that infrastructure to be scope expansion on a correction lane.

The practical exposure is small: a wrong field name or type would be a **compile** error, which
`flutter analyze` would catch, so the realistic failure mode is a field silently mapped to the
wrong source field — low consequence and type-checked on both sides. But it is a real gap and
the reviewer should know it exists rather than infer coverage from 309 green tests.

---

## 11. Commits

| SHA | What | Paths |
|---|---|---|
| `8befb92` | `registry: surface the open lifecycle gate on the product detail read` | server models + service + mapper, generated protocol (both sides) |
| `c692a49` | `test(registry): prove the open lifecycle gate is served and drainable` | `apps/server/test/**` |
| `debde6e` | `fix(product-detail): derive the lifecycle gate from durable state` | client repository, bloc, page, governance tests |

Each stands alone: `8befb92` adds a purely additive generated field and changes no existing
signature; `c692a49` is test-only and passes on `8befb92` (`dart analyze apps/server` was run
against exactly that file set); `debde6e` is the only commit touching client code. The
generator produces byte-identical output at `debde6e` to what is committed.

---

## 12. For the human / manager

1. **`noWorkInFlight` is still caller-asserted and never verified server-side.** Unchanged and
   still open — `packages/product_registry/**` is read-only here. What this change removes is
   the *client-side* half of the exposure: the operator can no longer reach an open offboard
   gate and approve it without being asked to state the assertion. The remaining gap is that
   the engine never checks the claim. Still needs a decision.
2. **`drainInFlight` is recorded at request time and never read at resolve.** Unchanged,
   out of scope.
3. **The `paused` typed-fence extension remains a deviation** awaiting ratification. This
   change makes it *more* load-bearing, not less: the fence now survives re-entry, because the
   assertion requirement is read from the durable action (§4). If the human overrules the
   extension, the revert is still the two lines in `lifecycleOffboardNeedsWorkInFlightAssertion`.
4. **The engine still permits two different lifecycle gates on one product.** The client now
   withholds the second action, but `ProductRegistryEngine.requestLifecycleDecision` will still
   accept `offboard` while a `pause` gate is open — it is idempotent for the *same* action and
   unguarded across *different* ones. The durable read makes such a state repairable from the
   UI, but the guard itself belongs in the engine, which is `packages/**` and read-only here.
   **This is the residual of B1 and I do not claim it closed at the engine level.**
5. **`registered → baselinePending` is still unreachable from the dashboard.** Unchanged, still
   out of scope, still a missing first-baseline author.

---

## 13. Safe / prohibited parallel work

**SAFE_PARALLEL_WORK** (disjoint from every path in §11):

- `packages/product_registry/**`, `packages/workflow_engine/**`, `packages/platform_contracts/**`
  — in particular `product_registry_engine.dart` and `product_transitions.dart`, for finding 4
  above and the `noWorkInFlight` verification question
- `apps/server/lib/src/triage/**`, `apps/server/lib/src/persistence/**` (other than the two
  files this branch touched)
- `apps/control_plane/lib/features/products/**` — the Add Product flow
- `apps/control_plane/test/{accessibility,pixel-fidelity,responsive,shared,tools,fixtures,helpers,home,products,runs,run_detail,needs_you,decision_detail,defect_report,reports,models,blocs}/**` except the files below
- `apps/control_plane/lib/shared/**`, `apps/control_plane/lib/core/**`
- `docker/**`, `.github/**`, `docs/**` (not `docs/engineering/dispatch/**`), `.decisions/**`
- `apps/server/migrations/**`

**PROHIBITED_PARALLEL_WORK** (collides, or would contradict the new wire contract):

- `apps/control_plane/lib/features/product_detail/**` — this branch's files
- `apps/control_plane/lib/data/control_plane_repository.dart`
- `apps/control_plane/test/widgets/product_detail_governance_test.dart`,
  `apps/control_plane/test/widgets/product_detail_page_test.dart`,
  `apps/control_plane/test/blocs/product_detail_baseline_bloc_test.dart`,
  `apps/control_plane/test/product_detail_mobile_golden_test.dart`
- `apps/server/lib/src/models/product_detail_view.yaml`,
  `apps/server/lib/src/models/product_lifecycle_gate_view.yaml`,
  `apps/server/lib/src/services/control_plane_service.dart`,
  `apps/server/lib/src/services/ui_view_mappers.dart`,
  `apps/server/lib/src/endpoints/product_registry_endpoints.dart`
- `apps/server/lib/src/generated/**` and `packages/control_plane_client/**` — both sides are
  regenerated together; a hand edit to either is erased by the next `serverpod generate`
- `apps/server/test/integration/product_registry_endpoints_e2e_test.dart` — the new tests share
  its `endpoint-{a,b}-fixture` rows and its purge; a concurrent writer on that file would
  collide on the fixture ids
- Anything that changes `HumanDecisionChoice` or `ProductLifecycleAction` wire values, or the
  `product-lifecycle:` scope format — the new tests assert on both
- Any lane driving `docker compose` against project `docker` — the QA stack is live

---

## 14. Required structured result

```
RESULT: CORRECTION_COMPLETE

CORRECTED_FROM_HEAD: 0bc016a97b70eb8a6baca593290d0fd58b244016
NEW_HEAD: debde6e48d65f405a29d6852071b5901758b9ed7

FINDINGS_ADDRESSED:
  B1  raised lifecycle gate is client-memory only        -> CLOSED
      * durable ProductDetailView.pendingLifecycleGate (Serverpod model field,
        ProductLifecycleGateView), read from the decision store on every load
      * ProductDetailState.pendingLifecycleDecision/.pendingLifecycleAction DELETED;
        openLifecycleGate/lifecycleGateOpen derived from the durable read
      * the raise response is discarded, not stored
      * a second lifecycle action is withheld while one is open, on a durable basis
      * an open gate is resolvable on return without raising again
      * an ALREADY-stranded product is drainable oldest-first (server test)
      * the no_work_in_flight assertion is read from the durable action, closing the
        re-entry attestation hole in both directions
      * panel copy no longer claims the gate came from this screen
      * prior commit preserved: in-place panel, action-scoped error surface,
        isRaisingGate, accessibility, noWorkInFlight as explicit operator statement,
        rework wire fix. Nothing from 0bc016a was reverted or regressed.

FILES_CHANGED:
  apps/control_plane/lib/data/control_plane_repository.dart
  apps/control_plane/lib/features/product_detail/product_detail_bloc.dart
  apps/control_plane/lib/features/product_detail/product_detail_page.dart
  apps/control_plane/test/widgets/product_detail_governance_test.dart
  apps/server/lib/src/models/product_detail_view.yaml
  apps/server/lib/src/models/product_lifecycle_gate_view.yaml           (new)
  apps/server/lib/src/services/control_plane_service.dart
  apps/server/lib/src/services/ui_view_mappers.dart
  apps/server/lib/src/generated/product_detail_view.dart               (generated)
  apps/server/lib/src/generated/product_lifecycle_gate_view.dart        (generated, new)
  apps/server/lib/src/generated/protocol.dart                           (generated)
  apps/server/test/integration/product_registry_endpoints_e2e_test.dart
  packages/control_plane_client/lib/src/protocol/product_detail_view.dart        (generated)
  packages/control_plane_client/lib/src/protocol/product_lifecycle_gate_view.dart (generated, new)
  packages/control_plane_client/lib/src/protocol/protocol.dart                  (generated)
  15 files, +1652 / -544.
  NOT touched: packages/control_plane_client/lib/src/protocol/client.dart (the named
  READ_ONLY exception), apps/server/migrations/**, docker/**, .github/**, docs/**,
  .decisions/**, apps/control_plane/lib/features/products/**

GATES:
  format=    pass  (dart format --output=none --set-exit-if-changed . ; exit 0; 768 files, 0 changed)
  analyze=   pass  (dart analyze apps/server: No issues found!; flutter analyze: No issues found!)
  tests=     pass  (flutter test: +309 all passed, baseline 304, +5;
                    make test-integration: +194 -1 — sole failure is dogfood_shipit_postgres_test.dart,
                    the known linked-worktree .git-as-a-file cause. Verified: .git is an 80-byte file
                    and the test asserts Directory('.git').existsSync() at line 88. Not chased.)
  build=     pass  (serverpod generate exit 0, idempotent at final HEAD;
                    verify_schema_bootstrap.sh exit 0, 20 OK / 0 FAIL, including
                    "no generated definition.sql claims these objects")
  runtime=   not-claimed  (would require driving the live QA stack, which the human holds)

NEW_DISCOVERIES:
  1. RUNTIME_DISCOVERY / PROJECT_FACT — every model in apps/server/lib/src/models/ has no
     `table:` key; ProductDetailView is a non-persisted SerializableModel. A field added to it
     is a wire-contract change and needs NO migration. Precedent: pendingBaselineDecisionId is
     on the same model and appears in no migrations/*. Verified, not assumed.
  2. PROJECT_FACT — readHumanDecisionsForScope orders by updatedAt ASC, so returning the FIRST
     unresolved decision makes a multi-gate product drainable oldest-first. That converts the
     B1 failure mode from "detected" to "repairable from the existing screen".
  3. PROJECT_FACT — the engine permits a second, DIFFERENT lifecycle gate while one is open
     (idempotent only for the same action). The client now withholds it, but the engine-level
     guard is still absent and belongs in packages/product_registry. Residual of B1, escalated
     as finding 4, not claimed closed.
  4. RUNTIME_DISCOVERY — Client.productRegistryEndpoints is assigned in the generated
     Client constructor, so the repository's wire->response mapping cannot be reached by a
     test double without subclassing client.dart, the one file fenced off by the path grant.
     That mapping is compile-checked but not executed by any test. Disclosed as §10.
  5. WORKFLOW_IMPROVEMENT (for the framework, not persisted here) — a correction lane that
     introduces a new durable wire field should state up front which half is under test. The
     server-serving half and the client-consuming half fail independently, and only the
     integration test caught a server that never sends the field.

READY_FOR_FOCUSED_REVIEW: YES
```

**FOCUSED_RE_REVIEW** — please cover: the durable read itself (is `openLifecycleGate` correct
about scope, ordering, and the product-id guard?); whether deleting the two state fields
rather than keeping them is right; the assertion-hole claim in §4; the one test assertion I
edited (§9); and the disclosed mapping gap in §10.