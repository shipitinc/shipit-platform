# Dispatch — impl-client-addproduct-keyflow

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: impl-client-addproduct-keyflow
TASK_TYPE: implement
FEATURE: Wire Add Product to the real key service so Register becomes pressable for SHIP IT Platform
AREA: apps/control_plane Add Product flow + the generated client package
WORKTREE: /private/tmp/shipit-client-keyflow
BRANCH: impl/client-addproduct-keyflow
BASE_SHA: c110aa2
OWNED_PATHS:
  - apps/control_plane/lib/**
  - apps/control_plane/test/**
  - packages/control_plane_client/**
READ_ONLY_PATHS:
  - apps/server/lib/src/credentials/**
  - apps/server/lib/src/endpoints/credential_endpoints.dart
  - docs/adr/0018-per-product-git-credentials.md
PROHIBITED_PATHS:
  - apps/server/**
  - docker/**
  - .github/**
  - docs/adr/**
  - .decisions/**
  - packages/product_registry/**
ACCEPTANCE_CRITERIA: >
  The Add Product flow calls the real credential endpoints, AccessStatus.verified is actually
  reachable, Register persists the credential, and the client mock key generator is gone.
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - cd apps/control_plane && flutter analyze
  - cd apps/control_plane && flutter test
ROUTING_CLASS: PRECISION
```

---

## This is the lane that makes the button pressable

The human's objective, narrowly: **onboard SHIP IT Platform through the Add Product page.** Everything
else is deferred. The Register button has never been pressable, for reasons this lane exists to remove.

### The blocker, in code

`apps/control_plane/lib/features/products/add_product_page.dart:233-236`:

```dart
bool get canRegister =>
    deployKey != null &&
    accessStatus == AccessStatus.verified &&
    !isRegistering;
```

**`AccessStatus.verified` is read in 9 places and written in ZERO.** Every occurrence is a comparison. So
`canRegister` is permanently false and the button is permanently disabled. There is no server-side reason —
this is a client state-machine gap.

And `_generateMockKeyPair` (`:126-138`) makes 32 random bytes and formats them
`ssh-ed25519 <base64> shipit+<product>`. **That is not an ed25519 key** — SSH would reject it. It exists
only to satisfy the non-null `deployKey` check. It must be deleted, not extended.

### The server half now exists and is merged

`apps/server/lib/src/endpoints/credential_endpoints.dart` on `main` — **verify the signatures yourself,
do not trust this summary**:

```dart
Future<Map<String, dynamic>> generate(
  Session session, {
  required String productId, required String repositoryId, String? credentialId,
})

Future<Map<String, dynamic>> verifyAccess(
  Session session, {
  required String productId, required String repositoryId,
  required String hostKeyFingerprint, required String confirmedBy, String? checkedBy,
})
```

`generate` returns only public half, fingerprint, algorithm, reference and status — **no private material
is reachable from the client by construction.** Read `MintedCredential`
(`apps/server/lib/src/credentials/credential_key_service.dart:38`) for the exact response shape.

**You now own `serverpod generate` for `packages/control_plane_client`.** It was unowned (H-1) and every
prior lane was told not to run it. Run it from your worktree, and confirm the generated client actually
exposes the credential endpoints — the previous reviewer checked and found **zero** `credentialEndpoints`
matches in `client.dart` before this merge, so verify the regeneration really landed rather than assuming.

## Required behaviour

1. **Delete the mock.** No client-side key generation of any kind.
2. **`Check access` calls `credentialEndpoints.generate`.** Store the returned public half, fingerprint and
   status. Never expect private material.
3. **`AccessStatus.verified` becomes reachable** — this is the actual fix. `verifyAccess` succeeding must
   set it. Keep the existing `enum` and the existing 9 read sites; do not weaken `canRegister` to make the
   button light up, because that would ship the F-9 defect knowingly.
4. **`Register` persists the credential.** Today `_onRegisterProductRequested` (`:143-180`) calls
   `createProduct` then `addRepositoryReference` and **discards the key** — it creates a product with no
   credential. Register must leave a credential row that points at the generated one.
5. **Keep the existing sequence and copy.** The UI is approved and independently reviewed; `Add a product`,
   `NOT REGISTERED YET`, the field order, the disabled-with-`Product name is required` behaviour, and the
   custody sentence *"It clones over SSH. The private half stays in the secret manager — never shown, logged
   or stored."* all stay as they are. You are wiring behaviour, not redesigning.

### Two things you must NOT decide

- **`hostKeyFingerprint` and `confirmedBy`** are required by `verifyAccess` and are **operator-asserted, not
  server-verified** (open finding M-5). Take them from **configuration**, never hardcode them, and surface
  them in the UI as something the operator supplies or confirms. GitHub publishes its host key
  fingerprints; surfacing them for confirmation is the point — do not treat a client-supplied value as
  proof of host identity.
- **G-7** — `9417f8bf` records that `referenceName` should be **removed from the client**. It is still there.
  Do not start removing it as a side effect of this lane; do not add new client-side uses of it either.
  Report what you observe and leave the decision where it sits.

## Tests you must write

1. `canRegister` is false with no credential, false while unverified, and **true** once `verifyAccess`
   succeeds. The middle case is the regression guard for the bug this lane exists to fix.
2. The mock generator is gone — assert no client-side key generation exists.
3. Register creates a credential row referencing the generated credential, and **no key material** reaches
   the client, a log, or the database.
4. `verifyAccess` failure leaves `canRegister` false and surfaces the error.

## Constraints

- `apps/server/**` is PROHIBITED — the key service is merged and reviewed; do not touch it.
- `docker/**` PROHIBITED. **The QA stack is up and healthy on a stopgap run-mode override and must not be
  disturbed.** Read compose as text.
- **ZERO mutating Docker/Compose commands.** Never `make clean` / `make qa-down` / `make test-env-down` /
  `make e2e-down` / bare `down -v`. This repository has already lost a QA database irrecoverably to a
  `down -v`. `make test-integration` is the only sanctioned database path, and you should not need it.
- Run `dart pub get` at the **REPO ROOT** first — and note that `serverpod generate` may require the root
  resolution to be current.
- Do not weaken, skip, `@Ignore`, filter, or delete any test.

## Gates — verbatim

- `dart format --output=none --set-exit-if-changed .` → expect `(0 changed)`
- `cd apps/control_plane && flutter analyze` → expect `No issues found!`
- `cd apps/control_plane && flutter test` → baseline is **+190**; report the real number
- Do **not** run `make test-integration`. The server side is already gated; your change is client-side.

## Report requirements beyond the contract

1. Proof `AccessStatus.verified` is now **written** — quote the line.
2. Confirmation the mock generator is deleted, with the grep that shows it.
3. Confirmation `packages/control_plane_client` exposes the credential endpoints after generation — quote
   the generated symbols.
4. What the end-to-end flow now does, step by step, and exactly what the human must do in the GitHub UI
   (install the public half as a deploy key) for `verifyAccess` to succeed.
5. Anything you found that blocks this flow, reported rather than worked around.

## Other lanes

None are writing `apps/control_plane/**` or `packages/control_plane_client/**`. Manager holds
`LANES.md` / `WORK_STATE.md` / `.decisions/**`.

Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`.

## Cleanup

Commit in logical commits. **Do not push, merge, or touch `main`.** Start nothing.

## You cannot approve this

Report `READY_FOR_INDEPENDENT_REVIEW: YES`.