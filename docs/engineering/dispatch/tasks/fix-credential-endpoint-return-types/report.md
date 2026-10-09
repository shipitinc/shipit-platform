# fix-credential-endpoint-return-types — report

```yaml
RESULT: CORRECTION_COMPLETE
CORRECTED_FROM_HEAD: cf1b2106b75238da4b43ebbff05e06414f2793ed
NEW_HEAD: 77d984a780baa8b4efc51f45ce5f49afaa563ea0
BRANCH: fix/credential-endpoint-return-types
WORKTREE: /private/tmp/shipit-fix-endpoint-types
READY_FOR_INDEPENDENT_REVIEW: YES
```

Verification that ran before any write: `git branch --show-current` == `fix/credential-endpoint-return-types`
and `git rev-parse HEAD` == `cf1b210…`, working tree clean. Both matched.

---

## 1. The root cause, located exactly

The dispatch's diagnosis was right and I pinned it to one generated line.
`serverpod_serialization-3.4.13/lib/src/serialization.dart:65-111` —
`SerializationManager.deserialize` walks a fixed table of primitive types and
then:

```dart
throw DeserializationTypeNotFoundException(type: t);
```

The generated client (`packages/control_plane_client/lib/src/protocol/protocol.dart:374-379`)
contains, for a map return type:

```dart
if (t == Map<String, dynamic>) {
  return (data as Map).map(
        (k, v) => MapEntry(deserialize<String>(k), deserialize<dynamic>(v)),
      ) as T;
}
```

`deserialize<dynamic>` is not in the table, so it throws
`No deserialization found for type dynamic` — **for every value in the map**.
The server had already minted the key and returned a correct body. The client
could not read a single field of it. That is also why no `credentialEndpoints`
request appeared in the server log as a *successful* one: the request is sent
and answered, and the client dies in `parseData` after the response.

I confirmed the deployed shape rather than assuming it. The running QA stack
still serves a bare map for a `Map<String,dynamic>` endpoint and a
`__className__`-tagged object for a typed one (bodies in §3).

---

## 2. What changed

### The wire types — `apps/server/lib/src/models/`

`minted_credential_view.yaml` and `credential_access_verification_view.yaml`,
regenerating to `lib/src/generated/minted_credential_view.dart` and
`credential_access_verification_view.dart`.

**Why `lib/src/models/` and not `lib/src/credentials/`, as the dispatch
suggested.** The dispatch said "unless the repo's convention clearly says
otherwise — justify the choice". It does, and the choice is forced rather than
preferred:

- `serverpod_cli` 3.4.13 discovers a **plain `.yaml`** model only under
  `lib/src/models/` or `lib/src/protocol/`. From
  `serverpod_cli-3.4.13/lib/src/util/model_helper.dart:154-174` — `isModelFile`
  admits a bare `.yaml` only when `path.containsAny([relativeModelSourcePathParts,
  relativeProtocolSourcePathParts])`, and `config.dart:153` pins
  `relativeModelSourcePathParts => ['lib','src','models']`. A `.yaml` anywhere
  else is not a model file and the generator ignores it **silently** — no error,
  no generated class, and the endpoint then fails to compile for a reason that
  has nothing to do with the change.
- All 24 existing non-table models in this server are in that directory. I
  checked for a counterexample and there is none: no `.yaml` exists anywhere
  under `apps/server/lib` outside `models/` and `database/`.

The credential *domain* objects stay in `lib/src/credentials/` where they are,
and the comment on the schema says the same thing so the next reader does not
move them.

`generate` exposes `credentialId`, `productId`, `repositoryId`, `publicKey`,
`fingerprint`, `algorithm`, `referenceName`, `status`, `hostKeyStatus`, `host`.
`verifyAccess` exposes `credentialId`, `status`, `canReachRepository`,
`secretMaterialRemoved`, `hostKeyConfirmationProvenance`, `failureReason`,
`lastVerifiedAt`, `observedHostKeyFingerprint`.

**The public key and fingerprint are in the response** and asserted by value
(not by field count) in the new test, because a model that dropped either would
still "work" and leave the operator with nothing to install.

### The endpoint — `credential_endpoints.dart`

Both methods now return the typed models. The projection is a field-by-field
named copy (`_mintedCredentialView`, `_accessVerificationView`), so a new
domain field cannot reach the wire without this file failing to compile. That
is the property the old shape lacked: `MintedCredential.toJson()` looked like
the contract, so it was reviewed as one, and nothing checked the client could
read it.

### `MintedCredential.toJson()` — deleted

It was the wire projection and nothing else called it. `AccessVerification
.toJson()` is **kept** and relabelled as not-the-wire-type, because
`credential_key_service_postgres_test.dart:804` asserts its shape
independently of the generated model — a real second opinion, not redundancy.

### The client — `control_plane_repository.dart`

`generateDeployKey` / `verifyDeployKeyAccess` read typed fields.
`_requiredResponseString` is deleted: I grepped for other uses across `apps/`,
`apps/server/`, `packages/` first, and its four call sites were the only ones,
all in the two methods being rewritten. It is genuinely dead.

### Regenerated

`serverpod generate` exit 0. Re-run after committing: **zero diff**, so the
committed output is exactly what the generator produces.

`callServerEndpoint<Map<String, dynamic>>` count: **24 → 23**, and neither
remaining credential method appears among them.

---

## 3. PROOF — a test that fails at cf1b210

I did this in a **separate detached worktree at `cf1b210`**, with only the two
new test files and their fixtures copied in. Nothing of my correction was
present.

### 3a. The canary — red at `cf1b210`, green at HEAD

`apps/server/test/credential_wire_return_type_test.dart`. It is written to
compile and run against **both** revisions — it reads the generated client's
declared return type from source rather than importing a Dart symbol, precisely
so it can run at the revision where the typed model does not exist. (The other
test file cannot do this; see 3b.)

**At `cf1b210` — exit 1:**

```
00:00 +0 -1: …credentialEndpoints.generate returns a serialisable model [E]
  Expected: not 'Map<String, dynamic>'
    Actual: 'Map<String, dynamic>'
  credentialEndpoints.generate declares `Map<String, dynamic>` on the wire. The
  generated client mirrors that type, so `Protocol.deserialize` will read the
  response body with `deserialize<dynamic>(v)`, for which Serverpod has no
  entry — the browser throws "No deserialization found for type dynamic" and
  no field of a successful mint is ever read. Every gate passes at this
  revision because a map is valid Dart and generates cleanly; only the wire
  boundary catches it.

00:00 +0 -2: …credentialEndpoints.verifyAccess returns a serialisable model [E]
  Expected: not 'Map<String, dynamic>'
    Actual: 'Map<String, dynamic>'
```

**At my HEAD `77d984a` — exit 0, same file, same command:**

```
00:00 +1: …credentialEndpoints.generate returns a serialisable model
00:00 +2: …credentialEndpoints.verifyAccess returns a serialisable model
00:00 +4: All tests passed!
```

### 3b. The deserialization itself, from a captured real response body

`credential_wire_return_type_test.dart` also reproduces the browser error
**verbatim from a real server's real response body**, and this passes at
`cf1b210` — it should, because the defect exists there. That is the control.

The fixtures were captured over HTTP from the running QA stack on 2026-10-09:

```
curl -X POST …/api/defectEndpoints/list                    -> {"defects":[],"totalCount":0}
curl -X POST …/api/productRegistryEndpoints/listProducts   -> [{"__className__":"ProductView",…}]
```

Same server process, same client, same `Protocol`, seconds apart. The map body
carries no `__className__` and throws; the typed body decodes. **The pair is
what makes the reproduction meaningful** — without the control, the map test
could be green for the wrong reason (a broken fixture, a broken `Protocol`, a
Dart version change). I asserted the control by *value*
(`productId == 'shipit-platform'`), not by shape, so it cannot pass on
`isNotEmpty` alone.

At `cf1b210`, the reproduction passes:
```
00:00 +2: All tests passed!
```

`credential_endpoint_wire_test.dart` cannot run at `cf1b210` — it imports
`MintedCredentialView`, which does not exist there, so it fails to *load*. That
is expected and is exactly why the canary in 3a is a separate file: a load
failure demonstrates that a type is new, not that a wire contract was broken.

### 3c. The fix, asserted at the wire

At my HEAD, `credential_endpoint_wire_test.dart` encodes a
`MintedCredentialView` with the **same `SerializationManager.encodeForProtocol`
the server uses** (`server.dart:516`), asserts the body carries
`__className__`, decodes it through the **generated client's** `Protocol`, and
checks `publicKey` and `fingerprint` survive. All 7 pass.

The body there is constructed, not captured, because the QA stack runs merged
`main` at the broken revision and cannot serve the fixed shape until it is
redeployed. I say so in the file header rather than implying it was captured.
The *shape difference* it depends on is the part established from a real server
in 3b.

---

## 4. Browser hop — NOT achieved. Stated plainly.

**I did not drive the browser hop, and I did not verify it.** The dispatch asked
me to be explicit about which of the two I achieved, so:

- The QA stack runs merged `main` (`cf1b210`), which I confirmed is still the
  broken revision by hitting a `Map<String,dynamic>` endpoint on `:8081` and
  getting a bare untagged map back.
- Driving the *fixed* hop requires rebuilding and redeploying that stack
  (`docker compose up --build`). `docker/**` is PROHIBITED for this lane and
  the stack is yours. **Zero mutating Docker/Compose commands were issued.**
- No headless browser was available in this environment either (`chromium not
  found`).

So: **the deserialization defect and its fix are proven against real captured
response bodies through the real generated client; the end-to-end mint in a
browser is not.** That last step needs a redeploy of the QA stack from this
branch, which is yours to run.

---

## 5. `.bytes` audit — before and after

Audit as documented in `ssh_keypair.dart:174`: `rg '\.bytes' apps/server/lib`.

| | sites |
|---|---|
| **before (`cf1b210`)** | **18** |
| **after (this HEAD)** | **18** |

Of those, 13 are code and 5 are comments/doc text. The code sites are the same
13 before and after, and a normalised `diff` of the two full site lists is
**empty** — no site added, removed, or moved. The three that must produce
material are unchanged (`local_file_secret_provider.dart:73`,
`gcp_secret_manager_secret_provider.dart:143`,
`repository_access_verifier.dart:364`), and the crypto-codec sites in
`ssh_keypair.dart` are unchanged.

`SecretBytes` is **not** a field on either wire type, and the new test pins that
from the generated source: no field of either model has a byte-carrying type
(`SecretBytes`, `ByteData`, `Uint8List`, `List<int>`) and no field name is in
the private-material set. Both models are asserted to carry **exactly** the
field set listed in §2, so an addition fails in either direction.

**No private half was printed, logged, echoed, or written anywhere**, including
in failure messages and in this report.

---

## 6. Gates

| gate | result |
|---|---|
| `dart pub get` (repo root) | pass |
| `dart format --output=none --set-exit-if-changed .` | **exit 0** — 665 files, 0 changed |
| `dart analyze apps/server` | **exit 0** — No issues found |
| `cd apps/control_plane && flutter analyze` | **exit 0** — No issues found |
| `cd apps/control_plane && flutter test` | **exit 0** — **+271**, baseline held |
| `serverpod generate` | **exit 0**, and a re-run after committing produced **zero diff** |

`apps/server` pure-Dart suites (`dart test`, concurrency 1):
**81 passed, exit 0** — the 5 pre-existing suites were **70 passed** at
`cf1b210` (I measured that baseline by stashing my work), plus **11 new**.

Two things I want to be explicit about rather than let a green row imply more
than it does:

- **`apps/server/test/integration/` was NOT run.** It needs a disposable
  Postgres via `make test-integration`, which is outside this lane's authority,
  and `SERVERPOD_DATABASE_PASSWORD` is not set here. It is **analyzed, not
  executed.** `credential_key_service_postgres_test.dart` — which I edited — is
  therefore statically verified only. Its edit is mechanical (see below), but a
  reviewer should treat its runtime as unverified by me.
- **`onboarding_test.dart` needs a DB** and hangs under `dart test` here. It is
  pre-existing and unrelated; I confirmed the same behaviour at `cf1b210`.

**No test was weakened, skipped, `@Ignore`d, filtered, or deleted.** The one
edited integration test, "the endpoint response contains no private material",
now reads `response.toJson()` — the generated model's own wire projection — so
every key sweep and every substring assertion still runs over the complete
response exactly as before. The typed fields are asserted *additionally*,
directly from the typed object the browser receives, and the key set is asserted
exactly.

---

## 7. Commits

```
77d984a test(credentials): prove the wire boundary, and read the client as a model
fc76d39 fix(credentials): return typed models from the credential endpoints
```

Logical, and the split is the natural one: the contract change, then the proof
and the client that consumes it. **Not pushed, not merged, `main` untouched.**

`FILES_CHANGED` — 14 files:

```
apps/server/lib/src/models/minted_credential_view.yaml                       (new)
apps/server/lib/src/models/credential_access_verification_view.yaml          (new)
apps/server/lib/src/generated/minted_credential_view.dart                    (new, generated)
apps/server/lib/src/generated/credential_access_verification_view.dart       (new, generated)
apps/server/lib/src/generated/protocol.dart                                  (generated)
apps/server/lib/src/endpoints/credential_endpoints.dart
apps/server/lib/src/credentials/credential_key_service.dart
apps/server/test/integration/test_tools/serverpod_test_tools.dart            (generated)
apps/server/test/credential_wire_return_type_test.dart                       (new)
apps/server/test/credential_endpoint_wire_test.dart                          (new)
apps/server/test/fixtures/credential_endpoint_wire/live_map_returning_body.json     (new)
apps/server/test/fixtures/credential_endpoint_wire/live_typed_returning_body.json   (new)
apps/server/test/integration/credential_key_service_postgres_test.dart
apps/control_plane/lib/data/control_plane_repository.dart
packages/control_plane_client/lib/src/protocol/client.dart                   (generated)
packages/control_plane_client/lib/src/protocol/protocol.dart                  (generated)
packages/control_plane_client/lib/src/protocol/minted_credential_view.dart    (new, generated)
packages/control_plane_client/lib/src/protocol/credential_access_verification_view.dart (new, generated)
```

Prohibited paths verified untouched in `cf1b210..HEAD`: `apps/server/migrations/**`,
`apps/server/tool/**`, `apps/server/lib/server.dart`, `docker/**`, `.github/**`,
`docs/adr/**`, `.decisions/**`, and every `packages/*` **except** the two files
under `packages/control_plane_client/`, which the dispatch assigned to me.

---

## 8. Recorded, not fixed

- **G-7** (`referenceName` on the client) — still carried on the wire. The
  schema documents why: the client already read it, and narrowing the contract
  is that decision's job.
- **M-4** (custody fallback logged lazily) — accepted, untouched.
- **M-5** (attestation operator-asserted) — `hostKeyConfirmationProvenance`
  carried verbatim, provenance string unchanged. Narrowed, not closed.
- **F-A / F-B** (no CI job runs `serverpod generate` or `apps/server/test/`) —
  unchanged.

### New for the Manager

1. **22 other endpoints still return `Map<String, dynamic>` and have the same
   latent defect.** My canary generalises to them for free — it is a two-line
   addition per endpoint, or better, a scan of the generated client that fails
   on *any* map-returning endpoint. Whether to fix them or to convert only the
   ones the browser actually reaches is a product call, so I did neither. This
   is the most important thing in this report: **the fix I made is per-endpoint,
   and the class is not.**
2. **`MintedCredential.toJson()`'s doc said "the wire projection".** It was, and
   it was wrong. A doc that names itself the contract gets reviewed as one.
   Worth a look at whether other domain classes carry similar claims.
3. **The QA stack must be redeployed from this branch before the browser hop can
   be verified.** Only you can do that; I did not touch it.
4. **`onboarding_test.dart` cannot run under plain `dart test`** (needs a DB) and
   is not tagged `integration`, so it is neither in a unit run nor in
   `make test-integration`'s `test/integration/` path. It appears to have no
   runner at all.
5. `repository_access_verifier_test.dart`'s leak check scans **system temp** for
   its prefix, so a leftover from any earlier run makes every later run red. I
   hit this and confirmed it is pre-existing by measuring the baseline. The
   check is right in spirit but the blast radius is the whole temp directory.

---

## 9. Parallel work

**`SAFE_PARALLEL_WORK`** — any path not listed below:

- `packages/**` except `packages/control_plane_client/**`
- `apps/server/lib/src/database/**`, `apps/server/lib/src/persistence/**`,
  `apps/server/lib/src/services/**`, `apps/server/lib/src/triage/**`
- other endpoint files under `apps/server/lib/src/endpoints/**`
- other `apps/server/lib/src/models/*.yaml` and their generated counterparts
- `apps/control_plane/test/**`, `apps/control_plane/lib/**` except
  `lib/data/control_plane_repository.dart`
- `docker/**` (you own it; I issued zero Docker commands)
- `docs/**` outside this task directory, `.github/**`

**`PROHIBITED_PARALLEL_WORK`** — do not write these while this correction is
under review:

- `apps/server/lib/src/models/minted_credential_view.yaml`,
  `apps/server/lib/src/models/credential_access_verification_view.yaml`
- `apps/server/lib/src/generated/minted_credential_view.dart`,
  `apps/server/lib/src/generated/credential_access_verification_view.dart`,
  `apps/server/lib/src/generated/protocol.dart`
- `packages/control_plane_client/**` — regenerating after a concurrent schema
  edit would silently renumber every `_iN.` import alias
- `apps/server/lib/src/endpoints/credential_endpoints.dart`,
  `apps/server/lib/src/credentials/credential_key_service.dart`
- `apps/control_plane/lib/data/control_plane_repository.dart`
- `apps/server/test/credential_wire_return_type_test.dart`,
  `apps/server/test/credential_endpoint_wire_test.dart`,
  `apps/server/test/fixtures/credential_endpoint_wire/**` — the canary reads
  the generated client from source, so a concurrent regeneration changes what it
  asserts
- `apps/server/test/integration/credential_key_service_postgres_test.dart`

---

```
RESULT: CORRECTION_COMPLETE

CORRECTED_FROM_HEAD: cf1b2106b75238da4b43ebbff05e06414f2793ed
NEW_HEAD: 77d984a780baa8b4efc51f45ce5f49afaa563ea0

FINDINGS_ADDRESSED:
  - BLOCKER: credentialEndpoints.generate/verifyAccess returned
    Future<Map<String, dynamic>>; the generated client called
    callServerEndpoint<Map<String, dynamic>> and Protocol.deserialize recursed
    into deserialize<dynamic>(v), which has no entry — "No deserialization found
    for type dynamic". Both now return generated Serverpod models
    (MintedCredentialView, CredentialAccessVerificationView).
  - generate exposes credentialId, productId, repositoryId, publicKey,
    fingerprint, algorithm, referenceName, status, hostKeyStatus, host.
    Public key and fingerprint retained and asserted by value.
  - verifyAccess exposes credentialId, status, canReachRepository,
    secretMaterialRemoved, hostKeyConfirmationProvenance, failureReason,
    lastVerifiedAt, observedHostKeyFingerprint.
  - No private material reachable from either type; SecretBytes is not a field.
    `.bytes` sites 18 -> 18, code sites 13 -> 13, site-list diff empty.
  - generateDeployKey/verifyDeployKeyAccess read typed fields;
    _requiredResponseString removed after checking for other uses (none).
  - Client regenerated: map-returning endpoints 24 -> 23; credential methods
    now typed.
  - Proof: test fails at cf1b210 (output above), passes at 77d984a.

FILES_CHANGED:
  apps/server/lib/src/models/minted_credential_view.yaml (new)
  apps/server/lib/src/models/credential_access_verification_view.yaml (new)
  apps/server/lib/src/generated/minted_credential_view.dart (new, generated)
  apps/server/lib/src/generated/credential_access_verification_view.dart (new, generated)
  apps/server/lib/src/generated/protocol.dart (generated)
  apps/server/lib/src/endpoints/credential_endpoints.dart
  apps/server/lib/src/credentials/credential_key_service.dart
  apps/server/test/integration/test_tools/serverpod_test_tools.dart (generated)
  apps/server/test/credential_wire_return_type_test.dart (new)
  apps/server/test/credential_endpoint_wire_test.dart (new)
  apps/server/test/fixtures/credential_endpoint_wire/live_map_returning_body.json (new)
  apps/server/test/fixtures/credential_endpoint_wire/live_typed_returning_body.json (new)
  apps/server/test/integration/credential_key_service_postgres_test.dart
  apps/control_plane/lib/data/control_plane_repository.dart
  packages/control_plane_client/lib/src/protocol/client.dart (generated)
  packages/control_plane_client/lib/src/protocol/protocol.dart (generated)
  packages/control_plane_client/lib/src/protocol/minted_credential_view.dart (new, generated)
  packages/control_plane_client/lib/src/protocol/credential_access_verification_view.dart (new, generated)

GATES:
format=pass (exit 0, 665 files, 0 changed)
analyze=pass (dart analyze apps/server: No issues found)
tests=pass (flutter test +271; apps/server pure-Dart 81 passed vs 70 baseline; the canary verified red at cf1b210 and green at HEAD)
build=pass (serverpod generate exit 0; post-commit re-run produced zero diff)
runtime=partial (wire boundary proven against captured live response bodies through the real generated client; browser hop NOT verified — QA stack runs merged main and redeploying it is prohibited for this lane)

NEW_DISCOVERIES:
  - 22 other endpoints still return Map<String, dynamic> with the same latent
    defect; the fix is per-endpoint and the class is not. Recorded, not fixed.
  - MintedCredential.toJson()'s doc claimed "the wire projection"; it was, and
    it was wrong. Deleted rather than kept as a second projection.
  - onboarding_test.dart needs a DB, is not tagged integration, and appears to
    have no runner.
  - repository_access_verifier_test.dart's leak check scans all of system temp,
    so a leftover from any earlier run reddens every later run (pre-existing).

READY_FOR_INDEPENDENT_REVIEW: YES
```