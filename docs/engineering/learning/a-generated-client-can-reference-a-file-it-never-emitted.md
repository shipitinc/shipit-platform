# Repository Learning: a generated client can reference a file it never emitted

**Feature**: IMPL-B6-CORRECTION-ALL-FIVE (repair fabricated engineering-review decisions)
**Date**: 2026-10-15
**HEAD**: see `git rev-parse HEAD` on `fix/unstick-unreviewable`
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic
authority. The framework-candidate half is flagged in the last section and NOT persisted here.

---

## Summary

`serverpod generate` was run against a `@doNotGenerate` endpoint method whose return type was
a **hand-written `SerializableModel` declared in `lib/src/endpoints/`**, with the generated
paths opened for it. It exited `0`, printed `✓ Generating code (38.0s)`, and emitted:

* the connector row in `lib/src/generated/endpoints.dart` — correct,
* the client method in `packages/control_plane_client/lib/src/protocol/client.dart` — correct,
* a `repairUnreviewedReview:` entry in `lib/src/generated/protocol.yaml` — correct,
* a test-tools shim — correct,

and then:

* an `import 'package:control_plane_client/src/endpoints/work_item_action_endpoints.dart'`
  in the generated client, **for a file it never wrote**, and
* **zero** occurrences of the model in `lib/src/generated/protocol.dart` or `protocol.yaml`.

The server package analyzed clean. The client package did not: `Target of URI doesn't exist`.

## The two halves of the failure, and why one is worse

The broken import is loud. The missing serialization registration is **silent**, and it is
the half that matters:

```
$ grep -c ReviewRepairResult apps/server/lib/src/generated/protocol.dart
0
```

`protocol.dart` is where `SerializationManager` learns what a wire type *is*. Zero
occurrences means the server cannot decode the method's return value **in either direction**
— not on the way in, not on the way out. The endpoint analyzes clean, the connector row is
present, and the method would still be uncallable. A green `dart analyze lib/` on the server
is not evidence that a generated endpoint works.

## What this repository actually requires

Every wire type is a **YAML model under `apps/server/lib/src/models/`**. There are 75 of
them. That directory generates into `apps/server/lib/src/generated/` *and*
`packages/control_plane_client/lib/src/protocol/`, and it is what puts a class into
`protocol.dart`'s serialization table. A hand-written `SerializableModel` elsewhere is
referenced by the generated client and never copied to it.

## Why this nearly shipped green

The obvious verification — "did the generator emit the connector row and the client method?"
— answers yes. Both checks pass, the diff looks like a clean 45-line addition, and the
method appears to be on the wire. The two checks that would have caught it are cheap:

```sh
grep -c <YourModel> apps/server/lib/src/generated/protocol.dart   # must be non-zero
cd packages/control_plane_client && dart analyze lib/src/protocol/client.dart
```

Note that `dart analyze lib/` in the client package reported **no issues** while the targeted
analyze of `client.dart` reported the error. A file nothing imports is not reached by the
directory-level analyze. Always name the file.

## What closing it costs, in files

Granting the two generated files is not enough. Reaching this state needs **five** paths
beyond the endpoint:

* `apps/server/lib/src/models/review_repair_result.yaml` — the declaration,
* `apps/server/lib/src/generated/review_repair_result.dart` — generated,
* `apps/server/lib/src/generated/protocol.dart` — regenerated,
* `packages/control_plane_client/lib/src/protocol/review_repair_result.dart` — generated,
* `packages/control_plane_client/lib/src/protocol.dart` — regenerated.

An ownership extension scoped to "run the generator on this endpoint" is therefore not
enough to close a wire gap, and the generator's reach is wider than the paths it was
authorised for. **Widen the grant to the model directory and both generated output
directories before running the generator, not after.**

## CLOSED on 2026-10-15 — and what closed it is now executable knowledge

The gap above was closed, not worked around. `ReviewRepairResult` is now
`apps/server/lib/src/models/review_repair_result.yaml`; `@doNotGenerate` is gone; and the
closure is held by `apps/server/test/integration/review_repair_wire_e2e_test.dart`, which
drives `client.workItemActionEndpoints.repairUnreviewedReview(...)` over real HTTP against
real PostgreSQL and asserts the return value decodes as a typed model with **all four**
fields intact.

That last clause is the part worth keeping. `detail` and `decisionId` are exactly what
reshaping the return onto `WorkItemActionResult` would have discarded, and it was possible
to make the wire go green that way — same-looking diff, green analyzer, shipped bug. The
e2e test names both fields, so a future reader who is tempted by the same shortcut finds it
already argued against in a test rather than having to rediscover it.

`dart analyze` in `packages/control_plane_client` — the check that failed last round — is
now clean, and `grep -c ReviewRepairResult apps/server/lib/src/generated/protocol.dart`
answers `9`.

### What `serverpod generate` actually touched

Wider than the paths the dispatch named, and all of it for this one type:

| path | change |
|---|---|
| `apps/server/lib/src/models/review_repair_result.yaml` | **new** — the declaration (hand-written) |
| `apps/server/lib/src/generated/review_repair_result.dart` | **new** — generated |
| `packages/control_plane_client/lib/src/protocol/review_repair_result.dart` | **new** — generated |
| `apps/server/lib/src/generated/endpoints.dart` | +45 — the connector row |
| `apps/server/lib/src/generated/protocol.yaml` | +1 — `repairUnreviewedReview:` |
| `apps/server/lib/src/generated/protocol.dart` | +17 semantic lines |
| `packages/control_plane_client/lib/src/protocol/protocol.dart` | +17 semantic lines |
| `packages/control_plane_client/lib/src/protocol/client.dart` | +the client method |
| `apps/server/test/integration/test_tools/serverpod_test_tools.dart` | +79 — generated |

Two findings here are the reason the first table said "grant the model directory and both
generated output directories": **three** generated files were written that no grant named
(the two new model copies and the test-tools shim), and they are unavoidable — `serverpod
generate` has no flag that emits a connector row without emitting the model behind it. A
grant scoped to "the generated files you expect" cannot be satisfied by running the tool.

### The `protocol.dart` diff is 373 lines and 17 lines of change

Normalising every `_i<n>` prefix alias to `_iN` collapses the diff from 373 changed lines
to 17, all of them `ReviewRepairResult`. A generated serialization table renumbers every
prefix alias when one import is inserted, so the raw diffstat overstates the change by an
order of magnitude. The command that shows the real size:

```sh
git show HEAD:$f | sed -E 's/_i[0-9]+/_iN/g' > /tmp/b.dart
sed -E 's/_i[0-9]+/_iN/g' "$f"                    > /tmp/a.dart
diff -u /tmp/b.dart /tmp/a.dart
```

### Unrelated churn that WAS there, and was not mine

`client.dart` also picked up a corrected copy of `retryFailedWorkItem`'s doc comment — text
from commit `611f2cc`, which edited the server endpoint and never re-ran the generator. That
is **pre-existing generated drift**: the client had been carrying a stale copy of its own
server's documentation for several commits. Running the generator is what fixed it. It is
the only change in this correction that is not about `ReviewRepairResult`, and it is not
scope creep — it is the generator doing its job on a file nobody had regenerated since.

## The second half of the grant was not enough either

With the wire closed, the operator affordance still could not be built under the ownership
given: `apps/control_plane/lib/features/run_detail/**` and
`apps/control_plane/lib/features/decision_detail/**` were granted, but
`apps/control_plane/lib/data/control_plane_repository.dart` was not, and it is the **only**
place a control-plane feature can reach the server. `ControlPlaneRepository._client` is
private, `ClientProvider._getClient()` is private, and every feature bloc in the app takes a
`ControlPlaneRepository` — there is no public seam from a feature directory to a
`Client`. Calling the repair from a feature file therefore requires adding one method to the
repository, mirroring `retryFailedWorkItem`.

The alternative was to construct a second `Client` inside the feature layer. That was
declined for the same reason the shortcut return type was: it creates a second connection
with its own lifecycle and its own copy of the base-URL resolution, and it is a decision
about the app's data architecture that belongs to whoever owns `lib/data/`. Shipping a
control wired to nothing would also have reproduced the exact defect this correction
exists to remove — an operator affordance that looks reachable and is not.

So the grant for a control-plane operator action needs the **data layer** as well as the
**feature layer**. That is the second instance of the same lesson in this correction: the
paths a change *touches* are not the paths a change *needs*.

## Framework candidates (NOT persisted here — reported for routing)

1. `WORKFLOW_IMPROVEMENT`: a correction dispatch that asks for `serverpod generate` should
   grant the model directory and both generated output directories up front. The generator's
   blast radius is knowable in advance from `serverpod generate --help` and the
   `client_package_path` in `config/generator.yaml`; discovering it by running is the
   expensive way. **Measurements above make this concrete: three unavoidable generated
   files beyond a "generated files" grant, and a 373-line diffstat that is 17 lines of
   change.**
2. `AUTOMATION_OPPORTUNITY`: a drift test asserting that every method named in
   `lib/src/generated/protocol.yaml` has its return type present in the serialization table
   of `protocol.dart` would have failed this in milliseconds, in CI, forever — and would
   catch the next instance of the same class of mistake. The e2e test added here is the
   expensive version of that check (real Postgres, ~40s); the cheap version is still unbuilt.
3. `AUTOMATION_OPPORTUNITY`: a CI check that re-runs `serverpod generate` and fails on any
   diff. That single check would have caught the `611f2cc` doc-comment drift, which sat in
   `client.dart` unnoticed for several commits, and would also make "do not hand-edit what
   the generator produced" mechanically enforced rather than a review instruction.
4. `WORKFLOW_IMPROVEMENT`: when a dispatch grants a feature-layer directory to build an
   operator affordance, it must also grant the repository/data file that affordance calls
   through. Two of the four grants in this correction were for *where the code lives* when
   what was needed was *where the client lives*.
