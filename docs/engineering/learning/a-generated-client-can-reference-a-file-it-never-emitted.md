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

## Kept: a stale `@doNotGenerate` is a truthful `@doNotGenerate`

The annotation and the surrounding doc were restored rather than removed, and the doc now
carries the measured evidence above instead of the old claim that the generated paths were
read-only. A `@doNotGenerate` that says *why, with the run that failed* is more useful to the
next reader than a green build produced by shipping a broken client. The generated output was
reverted, so this lane leaves a **building** repository rather than one whose `client.dart`
imports a file that does not exist.

## Framework candidates (NOT persisted here — reported for routing)

1. `WORKFLOW_IMPROVEMENT`: a correction dispatch that asks for `serverpod generate` should
   grant the model directory and both generated output directories up front. The generator's
   blast radius is knowable in advance from `serverpod generate --help` and the
   `client_package_path` in `config/generator.yaml`; discovering it by running is the
   expensive way.
2. `AUTOMATION_OPPORTUNITY`: a drift test asserting that every method named in
   `lib/src/generated/protocol.yaml` has its return type present in the serialization table
   of `protocol.dart` would have failed this in milliseconds, in CI, forever — and would
   catch the next instance of the same class of mistake.
