# Dispatch — fix-credential-endpoint-return-types

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: fix-credential-endpoint-return-types
TASK_TYPE: correct
FEATURE: Make the credential endpoints return typed models so the client can deserialize them
AREA: apps/server credential endpoint signatures + the client's parsing
WORKTREE: /private/tmp/shipit-fix-endpoint-types
BRANCH: fix/credential-endpoint-return-types
BASE_SHA: cf1b210
OWNED_PATHS:
  - apps/server/lib/src/endpoints/credential_endpoints.dart
  - apps/server/lib/src/credentials/**
  - apps/server/test/**
  - apps/control_plane/lib/**
  - apps/control_plane/test/**
READ_ONLY_PATHS:
  - packages/control_plane_client/**
  - apps/server/lib/src/generated/**
PROHIBITED_PATHS:
  - apps/server/migrations/**
  - apps/server/tool/**
  - apps/server/lib/server.dart
  - packages/**
  - docker/**
  - .github/**
  - docs/adr/**
  - .decisions/**
ACCEPTANCE_CRITERIA: >
  credentialEndpoints.generate and verifyAccess return Serverpod-serialisable typed models, the
  generated client deserialises both, and the Add Product flow completes a mint in the live QA
  stack with Copy public key reachable.
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - dart analyze apps/server
  - cd apps/control_plane && flutter analyze
  - cd apps/control_plane && flutter test
ROUTING_CLASS: PRECISION
```

---

## The blocker, found by driving the live QA stack

The whole key flow is integrated and deployed. The mint **fails in the browser** with:

> Something went wrong … **No deserialization found for type dynamic**

Reproduced end to end at `http://localhost:8081/#/products/new`. The server log shows the UI calls
`productRegistryEndpoints.createProduct` and `addRepositoryReference` (both 200) and then makes **no
`credentialEndpoints` request at all** — the client throws while parsing.

**The cause is a contract mismatch.** `credential_endpoints.dart` declares:

```dart
Future<Map<String, dynamic>> generate(...)
Future<Map<String, dynamic>> verifyAccess(...)
```

Serverpod's generated client calls `callServerEndpoint<Map<String, dynamic>>` and its deserializer has no
entry for `dynamic`. Every **working** endpoint in this repository returns a typed model —
`homeEndpoints.overview` returns `Future<Overview>`, `productRegistryEndpoints.listProductSummaries`
returns `Future<List<ProductSummaryView>>`. The credential endpoints are the only ones returning a raw map.

**This is exactly the class of defect the endpoint-shape guard cannot see** — that guard validates method
*shape* for generation, not the wire type. The correction loop approved the map signatures across two
review cycles because every gate (`dart analyze`, `serverpod generate`, `+271` tests) passes: the map is
valid Dart, generates cleanly, and no test exercised the real browser→server hop.

## What to change

Return **typed, Serverpod-serialisable models** from both endpoints. Look at how the existing endpoints do
it — `Overview`, `ProductView`, `ProductDetailView` are the house style, all `serializable`-style classes
with `__className__` in responses.

- Define the response types in a sensible location. Given `OWNED_PATHS` covers both sides, put them where
  the rest of the credential model lives (`apps/server/lib/src/credentials/`) unless the repo's convention
  clearly says otherwise — justify the choice.
- `generate` must expose exactly what the client already reads: `credentialId`, `productId`, `repositoryId`,
  `publicKey`, `fingerprint`, `algorithm`, `referenceName`, `status`, `hostKeyStatus`, `host`. **The public
  key and fingerprint must remain in the response — that is the whole point of the call.**
- `verifyAccess` must expose what the client reads: `credentialId`, `status`, `canReachRepository`,
  `secretMaterialRemoved`, `hostKeyConfirmationProvenance`, and a failure reason when verification fails.
- **No private material may be reachable from either type.** Re-run your `.bytes` audit and state the
  result. `SecretBytes` must not become a field on a serialisable model — that is the invariant this whole
  work item exists to protect, and a serialisable class is exactly where it could leak by accident.
- Update `generateDeployKey` / `verifyDeployKeyAccess` in `control_plane_repository.dart` to read the typed
  fields instead of `Map<String, dynamic>` indexing, and drop the now-unneeded `_requiredResponseString`
  calls **only if they become genuinely dead** — check for other uses first.
- **Regenerate the client package** (`serverpod generate`) and commit the regenerated
  `packages/control_plane_client/**`. You own both sides, so this is yours to run. Verify the generated
  signatures are no longer `Map<String, dynamic>`.

## Proof required — this is the part that matters

1. **A test that fails at `cf1b210`.** The deserialization failure only appears across the real
   wire boundary, so an in-process test will not catch it. Write a test that goes through the generated
   client's deserializer against a **captured real response body** from the running server, and show it
   **fails at `cf1b210`** and passes at your HEAD. Report both outputs. A test that only exercises your own
   mock of the typed object proves nothing about the wire.
2. **Confirm the browser hop works.** If you can drive it headlessly, do; if you cannot, say so plainly
   rather than implying you verified it. Report honestly which of the two you achieved.
3. Re-run your `.bytes` audit and report the private-material site count before and after — it must not
   increase.

## Constraints

- `apps/server/migrations/**`, `tool/**`, `lib/src/generated/**` (generated output excepted), and
  `lib/server.dart` stay untouched. Read `apps/server/tool/schema_bootstrap.dart`'s header before going
  near migrations, and run `bash apps/server/tool/verify_schema_bootstrap.sh` if you touch anything there.
- **Never print, log, or echo the private half** — not in code, not in a test failure message, not in your
  report. This is the invariant the whole key service was built around.
- `docker/**` PROHIBITED. **The QA stack is up and running from merged `main` and must not be
  disturbed.** I am driving it. Read compose as text.
- **ZERO mutating Docker/Compose commands.** `make test-integration` is the only sanctioned database path
  and self-cleans; you should not need it. Never `make clean` / `make qa-down` / `make test-env-down` /
  `make e2e-down` / bare `down -v`.
- Do not weaken, skip, `@Ignore`, filter, or delete any test.

## Gates — verbatim

`dart pub get` at **REPO ROOT** first; `dart format --output=none --set-exit-if-changed .`;
`dart analyze apps/server`; `cd apps/control_plane && flutter analyze`;
`cd apps/control_plane && flutter test` (baseline **+271**); `serverpod generate` (report exit status and
confirm `apps/server/lib/src/generated/**` changes only as expected).

Note: a linked worktree makes `dogfood_shipit_postgres_test.dart` deterministically red — that is a known
worktree artefact, **not** a regression. Do not chase it.

## Open items you must NOT fix

G-7 (`referenceName` on the client — a product decision), M-4 (custody fallback logged lazily, accepted),
M-5 (attestation still operator-asserted, narrowed not closed), and the CI gaps F-A/F-B (no job runs
`serverpod generate` or `apps/server/test/`). Record anything you notice; do not widen scope.

## Other lanes

None are writing these paths. Manager holds `LANES.md` / `WORK_STATE.md` / `.decisions/**`.

Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`.

## Cleanup

Commit in logical commits. **Do not push, merge, or touch `main`.**

Report `READY_FOR_INDEPENDENT_REVIEW: YES`.