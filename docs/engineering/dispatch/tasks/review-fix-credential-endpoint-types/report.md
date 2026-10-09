# Independent engineering review — fix-credential-endpoint-return-types

```yaml
RESULT: DO_NOT_MERGE
REVIEWED_HEAD: 77d984a780baa8b4efc51f45ce5f49afaa563ea0
BASE_SHA: cf1b2106b75238da4b43ebbff05e06414f2793ed
BRANCH: fix/credential-endpoint-return-types
WORKTREE: /private/tmp/shipit-fix-endpoint-types
CORRECTION_REQUIRED: YES
HUMAN_DECISION_REQUIRED: NO
```

**Lane read-only.** No file in the reviewed worktree was modified, created, committed or pushed;
`git status --porcelain` in `/private/tmp/shipit-fix-endpoint-types` is empty and HEAD is still
`77d984a`. **Zero mutating Docker/Compose commands were issued** — none at all, not even a
read-only `docker compose ps`. The QA stack was not touched. All experiments ran in throwaway
clones under `/var/folders/…/opencode/rev/` (`base-repro` at `cf1b210`, `head-probe` at
`77d984a`), both discarded after use. `make test-integration` was **not** run.

---

## Verdict in one line

The credential fix itself is correct, well-proven and safe. **The correction does not make the
dispatch's acceptance criterion achievable, and it breaks an existing integration test it claims
not to have broken.** Two independent blockers, both reproduced here from the repository's own
artefacts.

---

## 1. The proof is load-bearing — REPRODUCED, and it is genuine

### 1a. The canary is red at `cf1b210` — reproduced verbatim

Throwaway clone at `cf1b210`, only the two new artefacts copied in (no correction present):

```
$ cd apps/server && dart test test/credential_wire_return_type_test.dart
00:00 +0 -1: …credentialEndpoints.generate returns a serialisable model [E]
  Expected: not 'Map<String, dynamic>'
    Actual: 'Map<String, dynamic>'
00:00 +0 -2: …credentialEndpoints.verifyAccess returns a serialisable model [E]
  Expected: not 'Map<String, dynamic>'
    Actual: 'Map<String, dynamic>'
exit=1
```

Byte-for-byte the output the report claims, including the failure text. **At HEAD, same file, same
command: `00:00 +2: All tests passed!`** (`credential_wire_return_type_test.dart` +
`credential_endpoint_wire_test.dart` together: **+11, exit 0**).

The design choice — reading the generated client's declared return type **from source** so the file
compiles at the broken revision — is the right call and I checked it for vacuous-pass hazards:

- `classStart` is asserted `> -1`, so a generator rename fails loudly rather than auditing nothing;
- the signature regex is asserted `isNotNull`, same reason;
- the scope is `EndpointCredentialEndpoints`, not the first `Future<X>` in the file;
- the alias-stripping regex is global (`_\w+\.`), so `List<_i8.FeatureRequestSummaryView>` is
  handled, not just leading aliases.

No hole found. This is a real regression canary and it does what it says.

### 1b. The fixtures are real, and the control is asserted by value — verified

```
$ cat live_map_returning_body.json      → {"defects":[],"totalCount":0}
$ cat live_typed_returning_body.json    → [{"__className__":"ProductView","productId":"shipit-platform",
                                           "name":"ShipIt Platform", … ,"state":"registered", …}]
```

The map body is **non-empty** (two keys). That matters and is not obvious: I measured that a
zero-key map body `{}` deserialises **successfully**, because the generated
`(data as Map).map((k, v) => …)` never invokes `deserialize<dynamic>` when it iterates nothing. The
fixture therefore genuinely crosses the failure path, and the control is asserted **by value** —
`decoded.first.productId == 'shipit-platform'`, `.name == 'ShipIt Platform'`,
`.state == 'registered'` — not by `isNotEmpty`. Decoded as `List<ProductView>`, the type the
generated client actually declares for `listProducts`, so the control exercises the same concrete
generated branch rather than an `Object?` hole. **Without the control the map test could indeed pass
for the wrong reason** (broken fixture / broken `Protocol` / SDK change), and the lane's reasoning
is correct.

**One correction to the report:** `credential_endpoint_wire_test.dart` claims to *"reproduce the
browser error verbatim from a real server's real response body"* — true — but it is
**not** the canary's companion proof of the fix; §3c is honest that its body is constructed with the
server's own `SerializationManager.encodeForProtocol`. The report's §3b also says "this passes at
`cf1b210`" about `credential_endpoint_wire_test.dart`, then §3b's last paragraph correctly says that
file **cannot load** at `cf1b210`. The second statement is the true one (I confirmed: it imports
`MintedCredentialView`, which does not exist there). Internal inconsistency in prose only; the file
design is sound.

---

## 2. The wire type is actually fixed — VERIFIED

`packages/control_plane_client/lib/src/protocol/client.dart:95-168`:

```dart
class EndpointCredentialEndpoints extends _i1.EndpointRef {
  _i2.Future<_i3.MintedCredentialView> generate({…})
      => caller.callServerEndpoint<_i3.MintedCredentialView>(…);
  _i2.Future<_i4.CredentialAccessVerificationView> verifyAccess({…})
      => caller.callServerEndpoint<_i4.CredentialAccessVerificationView>(…);
```

Both registered in the client's `Protocol`: `deserialize` branches (`protocol.dart:126,153`),
`getClassNameForObject` (`:481,491`), `deserializeByClassName` (`:593,620`). `toJsonForProtocol` on
both server models emits `'__className__': 'MintedCredentialView'` / `'CredentialAccessVerificationView'`.

`generate` exposes exactly the ten fields the dispatch named, in the generated classes, including
`publicKey` and `fingerprint`. `verifyAccess` exposes the eight, including
`hostKeyConfirmationProvenance` and a nullable `failureReason`.

Client reads were converted to typed field access (`control_plane_repository.dart:1186-1192`,
`1216-1225`). Behaviour change worth noting but not a defect: the old
`_requiredResponseString` produced a named `StateError` on a malformed field and the map reads
carried defaults (`algorithm ?? 'ed25519'`); the typed model fails at deserialization instead, and
all three fields are non-nullable on the wire. That is a strictly better failure mode.

---

## 3. No private material reachable from either type — VERIFIED field by field

`apps/server/lib/src/generated/minted_credential_view.dart` abstract-class fields:

| field | type | verdict |
|---|---|---|
| `credentialId` `productId` `repositoryId` | `String` | identifiers |
| `publicKey` | `String` | public authorized-keys line — the point of the call |
| `fingerprint` | `String` | SHA-256 over the **public** blob |
| `algorithm` | `String` | `ed25519` |
| `referenceName` | `String` | secret-manager reference name — **G-7, carried deliberately and documented in the schema** |
| `status` `hostKeyStatus` | `String` | enums as text |
| `host` | `String?` | repository remote, public |

`credential_access_verification_view.dart`: `credentialId`, `status` (`String`), `canReachRepository`
(`bool`), `secretMaterialRemoved` (`bool`), `hostKeyConfirmationProvenance` (`String`),
`failureReason` (`String?`), `lastVerifiedAt` (`DateTime?`), `observedHostKeyFingerprint` (`String?`).

**No `SecretBytes`, `ByteData`, `Uint8List` or `List<int>` on either type. Neither type has a
transitive path to the private half**, and neither can acquire one without a schema change that the
generator, the client and the endpoint's field-by-field named copy would all have to be edited
together. `_mintedCredentialView` / `_accessVerificationView`
(`credential_endpoints.dart:339-368`) are named copies, so a new domain field breaks compilation
rather than silently serialising. The endpoint's `catch` blocks still route through
`credentialFailureLogFields` → `secretlessText`. **No private half is printed, logged or persisted
anywhere in the diff.** Invariant holds.

### `.bytes` audit — independently re-measured, claim confirmed

```
$ rg -n "\.bytes" apps/server/lib | sort   → cf1b210: 18 lines ; HEAD: 18 lines
$ diff base.txt head.txt                    → IDENTICAL (empty diff)
```

Not "18 → 18, trust me" — the two full site lists are byte-identical, including the 13 code sites
and the 5 comment sites. The three material-producing sites
(`local_file_secret_provider.dart:73`, `gcp_secret_manager_secret_provider.dart:143`,
`repository_access_verifier.dart:364`) and the crypto sites in `ssh_keypair.dart` are unchanged.
**Report claim §5 verified.**

---

## 4. The schema-location override — FORCED, and the lane was right

Verified against the pinned CLI, not from memory:

- `serverpod_cli-3.4.13/lib/src/util/model_helper.dart:154-174` `isModelFile`: a plain `.yaml` is a
  model file only when `path.containsAny([relativeModelSourcePathParts, relativeProtocolSourcePathParts])`.
- `lib/src/config/config.dart:153` → `['lib','src','models']`; `:140-143` → `['lib','src','protocol']`.
- The walk root is `config.libSourcePathParts` = `[serverPackageDirectoryPathParts, 'lib']` and
  `_loadAllModelFiles` lists it **recursively**, so a `lib/src/credentials/*.yaml` **is** walked and
  **is** then filtered out. Silent ignore, no error — exactly as the report states.

**The dispatch was wrong and the override was forced.** A schema in `lib/src/credentials/` would have
produced no class and a compile error with no causal connection to the change. Consistency check:
all 26 model schemas in this server are under `lib/src/models/` (24 pre-existing + these 2), none
under `database/` or `protocol/`. Correct call, correctly justified, and the rationale is written
into the schema header where the next reader will hit it. No finding.

---

## 5. Deletions — VERIFIED safe

| deletion | verification | verdict |
|---|---|---|
| `_requiredResponseString` | `rg -n "_requiredResponseString" .` (excluding `.git`) over the **whole repo** at HEAD → **no hits**. At `cf1b210` it had exactly 4 call sites (`:1181,1182,1183,1211`), all inside the two rewritten methods, plus its declaration. | genuinely dead |
| `MintedCredential.toJson()` | At `cf1b210`, the only call was `credential_endpoints.dart:188`. Repo-wide search finds no other user, and no other file even names the type. | genuinely dead |
| `AccessVerification.toJson()` (kept, relabelled) | **Still genuinely used**: `credential_key_service_postgres_test.dart:833-840` constructs an `AccessVerification` and asserts on `jsonEncode(verification.toJson())`. The one other `verification.toJson()` in the repo (`postgres_execution_store.dart:465`) is a different type, `platform_contracts.PlatformVerification`. | retention is correct |

Nothing deleted was reachable only from a non-default configuration path: the helper was a `static`
private on `ControlPlaneRepository` and the removed `toJson` was a public method on a domain class
with exactly one caller. Compile-time-checked removals. No finding.

---

## 6. The 22 other endpoints — count VERIFIED, consequence NOT correctly escalated

**Count.** Real (non-comment) `callServerEndpoint<Map<String, dynamic>>` sites:

- `cf1b210`: **24** → `HEAD`: **22**.

The report's "24 → 23" (§2) and §8.1's "22 other endpoints" disagree with each other; §8.1 is
right and §2's method is off by one because it counted a `///` doc-comment line the lane itself
added at `client.dart:66`. Cosmetic, but it is the number a Manager will quote, so fix the prose.

**Which of the 22 the browser actually reaches.** Intersecting the 22 map-returning client methods
with every `_client.<endpoint>.<method>(` call site in `control_plane_repository.dart`:

**13 are reachable from the live Flutter client:**

| endpoint | methods |
|---|---|
| `productRegistryEndpoints` | `addRepositoryReference` |
| `intakeEndpoints` | `createFeatureRequest` |
| `defectEndpoints` | `create`, `list`, `inspect`, `addEvidence`, `answerClarification`, `verifyFix` |
| `providerHealthEndpoints` | `getProviderHealth`, `listModelPolicies`, `updateModelPolicy`, `listModelExecutions`, `getModelStats` |

9 more (`executionEndpoints` ×2, `healthEndpoints.health`, `schedulerEndpoints` ×2,
`workerEndpoints` ×3, `defectEndpoints.requestClarification`) are not yet wired to a screen.

**The report treats this as "a product call, so I did neither."** It is not a free product call —
one of the 13 is on the path that gates the fix. See **B-1**.

Why the gates could never have caught the class, verified: `endpoint_surface_shape_test.dart`
documents the opposite — *"Only a type argument that IS `dynamic` or `void` is rejected … which is
why `Future<Map<String, dynamic>>` — the shape most endpoints in this repository return — stays a
legal endpoint."* The existing guard is not merely silent, it **explicitly blesses** the shape that
breaks the browser. Nothing in `apps/control_plane/test` crosses the wire either —
`add_product_keyflow_widget_test.dart` drives a `FakeRepositoryProbe`. See **H-2**.

---

## 7. What was not verified — and what it means

The lane's disclosure is accurate and I confirmed both halves.

**Browser hop: not verified.** Correct — redeploy is out of authority, and I did not attempt it.
Not knowing it is fine. **Knowing it is fine is the problem**, because the hop cannot succeed on this
branch. See **B-1**.

**`credential_key_service_postgres_test.dart` — analyzed, not executed.** Being analyzed rather
than executed is normally acceptable; **here the unexecuted edit breaks the test.** See **B-2**.

### B-2 detail: the edit does *not* leave the sweep intact

The lane's claim is *"its edit uses `response.toJson()` so every existing sweep still runs over the
complete response."* **The sweeps do survive** — `wireMap.keys`, `wireMap.values` and
`jsonEncode(response)` all still cover every field, and `toJson()` is the model's complete field
projection. That part is accurate.

The **new** assertion added on top does not hold. `MintedCredentialView.toJson()` is Serverpod's
generated projection and it **includes `__className__`** (`minted_credential_view.dart:141-154`);
`toJsonForProtocol()` adds it too. The expected set at
`credential_key_service_postgres_test.dart:442-456` does not list it. Measured on HEAD:

```
withHost:    [__className__, credentialId, productId, repositoryId, publicKey,
              fingerprint, algorithm, referenceName, status, hostKeyStatus, host]
withoutHost: [__className__, credentialId, productId, repositoryId, publicKey,
              fingerprint, algorithm, referenceName, status, hostKeyStatus]
expect(wireMap.keys.toSet(), {credentialId, …, if (host != null) 'host'})
  → Actual:   Set:[__className__, credentialId, …, host]
    Which:   larger than expected
```

This assertion sits in the test named *"the endpoint response contains no private material"* — the
one test in the file that exists to catch a field appearing in the response that nobody reviewed.
It will red-light the next `make test-integration` run and will look like a leak regression. The
report's blanket **"No test was weakened, skipped, `@Ignore`d, filtered, or deleted"** is therefore
**false as written**: nothing was skipped or deleted, but a previously-green test was converted to
red. The cause is benign — `dart analyze` cannot see it, and the suite was never executed — but the
consequence is not.

---

## BLOCKERS

### B-1 — `productRegistryEndpoints.addRepositoryReference` is left broken on the very path this correction fixes

`apps/server/lib/src/endpoints/product_registry_endpoints.dart:507` still returns
`Future<Map<String, dynamic>>`, and line 526 returns a **non-empty** map:

```dart
return {'success': true, 'repositoryId': ref.repositoryId};
```

The Add Product flow calls it **immediately before** the mint, in the same handler:

```
add_product_page.dart:143   await _ensureProductAndRepository(productId);
  └─ :281  await _repository.addRepositoryReference(...)   → Map<String, dynamic>  ← throws here
add_product_page.dart:147   final minted = await _repository.generateDeployKey(...)  ← never reached
```

`serverpod_client-3.4.13/lib/src/serverpod_client_shared.dart:561-570` calls
`parseData<T>(data, T, serializationManager)` for every non-`void` endpoint and `rethrow`s.
`ControlPlaneRepository.addRepositoryReference` (`:1147`) has no `try`/`catch`; the bloc catches at
`add_product_page.dart:203` and renders the error text verbatim.

Reproduced on HEAD through the **real generated client's `Protocol`**, using the server's own
`SerializationManager.encodeForProtocol` on that exact map:

```
BODY:   {"success":true,"repositoryId":"shipit-platform"}
THROWN: DeserializationTypeNotFoundException: No deserialization found for type dynamic
```

(Control, also measured: `{}` → `{}`, no throw — which is precisely why this failure mode presents
as endpoint-specific and gets misattributed.)

**This is also, I think, the actual cause of the reported symptom.** The dispatch recorded the
server log as: `createProduct` 200, `addRepositoryReference` 200, then **no `credentialEndpoints`
request at all**. A `200` from `addRepositoryReference` followed by silence is the exact signature of
a client-side parse failure at *that* call — the request is sent and answered, the client dies in
`parseData`, and the credential mint is never issued. `credentialEndpoints.generate` may well have
needed fixing too (it was broken the same way), but nothing in the evidence points at it as the
first throw.

**Consequence:** after this correction is merged and the QA stack is redeployed from it, the browser
hop **still** fails with `No deserialization found for type dynamic`, at `addRepositoryReference`,
before any key is minted. The dispatch's `ACCEPTANCE_CRITERIA` — *"the Add Product flow completes a
mint in the live QA stack with Copy public key reachable"* — is **not achievable from this branch**.
The Manager's post-integration browser verification is therefore not a formality; it is a known
failure that will be misread as "the fix did not work".

**Required correction:** give `addRepositoryReference` a typed return (a
`RepositoryReferenceAddedView` is the house-style answer; the client discards the value at
`control_plane_repository.dart:1147`, so nothing on the client changes), regenerate the client, and
extend `credential_wire_return_type_test.dart` to cover it.

### B-2 — the edited integration assertion is red

`apps/server/test/integration/credential_key_service_postgres_test.dart:442-456`. Expected set is
missing `__className__`, which the generated `toJson()` always includes.

**Required correction:** either add `'__className__'` to the expected set, or assert against
`response.toJson()..remove('__className__')` / over `toJsonForProtocol()` with the class tag stripped
— whichever states the intent (the field whitelist, not the framing envelope). Then actually
execute the file via `make test-integration` before reporting, since this is the second time in this
correction that an unexecuted suite would have caught a real problem.

---

## HIGH

### H-1 — the class was escalated as a scope question, but one member is on the critical path

The lane is right that fixing all 22 (or all 13 client-reachable) endpoints is a scope decision and
right to record rather than unilaterally do. But it recorded them as an undifferentiated "22 other
endpoints" without noticing that `addRepositoryReference` sits inside the acceptance criterion, and
without stating the consequence for the browser hop. That information was available: the dispatch
itself reported `addRepositoryReference` in the failing log sequence.

**Required:** B-1 fixed, and the Manager records an explicit decision (Human Decision object if not
taken now) on the remaining **12 client-reachable** map endpoints — `intakeEndpoints.
createFeatureRequest`, the six `defectEndpoints` methods, the five `providerHealthEndpoints` methods
— each of which will throw `No deserialization found for type dynamic` the first time its screen is
opened. That is a product-scope call, and this review does not make it.

### H-2 — `endpoint_surface_shape_test.dart` documents the defect class as correct

`apps/server/test/endpoint_surface_shape_test.dart:231-233` states that
`Future<Map<String, dynamic>>` *"stays a legal endpoint."* It is legal to the **generator**; it is
broken on the **wire**. The guard is correct about its own scope, but a guard whose prose endorses
the shape that has now cost two review cycles is a trap for the next reader — and a `CONTRADICTION`
under `docs/engineering/LEARNING_POLICY.md` that has not been surfaced or reconciled.

**Required:** amend that comment to say plainly that generator-legality is not wire-legality, and
cite `credentialEndpoints.generate` / `productRegistryEndpoints.addRepositoryReference` as the
counter-examples. Then extend the canary from a two-endpoint loop to a **scan of the generated
client** that fails on *any* map-returning endpoint method — one test, whole class, and it cannot go
stale the way a per-method list does. (The report's "it is a two-line addition per endpoint, or
better, a scan" already identifies this; the "or better" is the correct half and should be taken.)

---

## MEDIUM

- **M-1 — the report's own endpoint count is internally inconsistent.** §2 says `24 → 23`; §8.1 says
  "22 other endpoints". The real numbers are `24 → 22`; §2 counted a doc-comment line the lane added.
  Whichever number goes into `WORK_STATE.md` should be the measured one.
- **M-2 — the empty-map asymmetry is undocumented and it is what made this mis-diagnosable.** A
  `Map<String, dynamic>` endpoint returning `{}` deserialises fine; one returning any non-empty map
  throws. That is the whole reason a defect of this class presents as intermittent and endpoint-
  specific and gets blamed on the wrong endpoint. It belongs in the `endpoint_surface_shape_test`
  comment (H-2) and in the canary's header. Not recorded anywhere.
- **M-3 — `NEW_DISCOVERIES` are unclassified and unpersisted.** All four are durable
  (`PROJECT_FACT` / `AUTOMATION_OPPORTUNITY` / `QA_DISCOVERY`). They appear only in the lane report;
  no `WORKFLOW_IMPROVEMENT` candidate or repository-knowledge update was raised. The lane owned no
  docs path, so recording them in the report was the right handoff — the Manager still needs to
  classify and route them, and this review should not close without that.

## LOW

- **L-1 — the dispatch contradicts itself, not the lane.** `PROHIBITED_PATHS` lists `packages/**`;
  the body says *"Regenerate the client package … commit the regenerated
  `packages/control_plane_client/**`. You own both sides."* The lane followed the body and said so
  in its report. No action against the lane; the dispatch header should stop claiming a blanket
  `packages/**` prohibition on tasks that regenerate the client.
- **L-2 — `AccessVerification.toJson()` is retained on the strength of one caller that constructs
  its object by hand** (`credential_key_service_postgres_test.dart:833-840`) and is never produced by
  any endpoint. It now guards a projection no code path emits. Keeping it is defensible and the
  relabelling is honest, but it is a test of a literal, not of the system. Consider having the
  endpoint-level test assert against the generated view instead and letting `AccessVerification`
  carry no projection at all.
- **L-3 — `FILES_CHANGED — 14 files` is followed by 18 entries** in report §7. The list is right;
  the count above it is not.
- **L-4 — the schema comment cites `util/model_helper.dart` `isModelFile` / `_modelRootSuffixes` as
  if both were the filter.** The filter is `isModelFile` alone; `_modelRootSuffixes` is used only by
  the *shared-package* path extractor. The claim is still correct; the citation names one helper too
  many.

---

## What I verified independently (commands and results)

Run in throwaway clones; the reviewed worktree was never written to.

| check | command | result |
|---|---|---|
| provenance | `git rev-parse HEAD`, `git status --porcelain`, `git log --oneline -n 5` in the worktree | `77d984a…`, clean, branch `fix/credential-endpoint-return-types`, 2 commits over `cf1b210` |
| canary red at base | clone at `cf1b210`, copy in the 2 new artefacts, `dart test test/credential_wire_return_type_test.dart` | **exit 1**, exact reported message |
| canary green at head | `dart test test/credential_wire_return_type_test.dart test/credential_endpoint_wire_test.dart` | **exit 0**, +11 |
| baseline suites at base | 5 pre-existing non-DB suites at `cf1b210` | **+70 passed** |
| suites at head | same 5 + 2 new | **+81 passed, exit 0** |
| `dart pub get` | repo root | ok |
| format | `dart format --output=none --set-exit-if-changed .` | **exit 0** — 665 files, 0 changed |
| analyze | `dart analyze apps/server` | **exit 0** — No issues found |
| analyze | `cd apps/control_plane && flutter analyze` | **exit 0** — No issues found |
| flutter tests | `cd apps/control_plane && flutter test` | **exit 0** — **+271**, baseline held |
| generate | `serverpod generate` in `apps/server` (clone) | **exit 0**, and `git status` afterwards **empty** — committed output is byte-identical to a fresh run |
| generated diff | `git diff cf1b210..HEAD -- apps/server/lib/src/generated/protocol.dart` | alias renumbering + the 2 new model registrations only; no semantic drift |
| wire type | read `packages/control_plane_client/lib/src/protocol/{client,protocol}.dart` | both methods typed, both models registered in `deserialize` / `getClassNameForObject` / `deserializeByClassName` |
| `.bytes` audit | `rg -n "\.bytes" apps/server/lib \| sort` at both revisions, then `diff` | 18 vs 18, **diff empty** |
| model field audit | read both generated classes field by field | no byte-carrying type, no `SecretBytes` path |
| deletions | repo-wide `rg` for `_requiredResponseString`, `MintedCredential.toJson`, `AccessVerification.toJson` at both revisions | both deletions dead; retained method still used |
| map-endpoint count | `rg -n "callServerEndpoint<Map<String, dynamic>>"` excluding comment lines | **24 → 22** |
| client reachability | intersect the 22 with every `_client.X.Y(` in `control_plane_repository.dart` | **13 reachable**, incl. `addRepositoryReference` |
| schema-location claim | read `serverpod_cli-3.4.13` `model_helper.dart:154-174`, `config.dart:131-160`, `_loadAllModelFiles` | claim **true**; override **forced and correct** |
| **B-1** | probe: `SerializationManager.encodeForProtocol({'success': true, 'repositoryId': 'x'})` → `Protocol().decode<Map<String, dynamic>>(…)` | **throws `No deserialization found for type dynamic`** |
| **B-1 control** | same, with `{}` | `{}` decoded successfully — non-empty is required |
| **B-2** | probe: `MintedCredentialView(...).toJson().keys` vs the edited expected set | **red** — `__className__` extra |
| test weakening | `git diff` for `@Ignore`/`@Skip`/`skip:`/`tags:`; `--stat` for deletions | none added, none deleted |
| prohibited paths | `git diff --name-only cf1b210..HEAD` | `migrations/**`, `tool/**`, `lib/server.dart`, `docker/**`, `.github/**`, `docs/adr/**`, `.decisions/` all absent; `packages/**` limited to the two files the dispatch body authorised |

---

## SAFE_PARALLEL_WORK

This review is read-only; nothing was written and nothing is blocked. After the correction lands, the
Manager's lane may proceed on any path outside the correction's ownership list — including
`docker/**` (for the redeploy that B-1 and the browser hop require), `apps/server/migrations/**`,
`apps/server/tool/**`, `.github/**`, and `docs/**` outside this task directory.

**PROHIBITED_PARALLEL_WORK** until B-1/B-2 are corrected: writing
`apps/server/lib/src/endpoints/product_registry_endpoints.dart`,
`apps/server/lib/src/models/*.yaml`, `apps/server/lib/src/generated/protocol.dart`,
`packages/control_plane_client/**`, `apps/server/test/credential_wire_return_type_test.dart`,
`apps/server/test/credential_endpoint_wire_test.dart`, and
`apps/server/test/integration/credential_key_service_postgres_test.dart` — a concurrent
regeneration renumbers every `_iN.` import alias, and the canary reads the generated client from
source.

---

```
RESULT: DO_NOT_MERGE

REVIEWED_HEAD: 77d984a780baa8b4efc51f45ce5f49afaa563ea0

BLOCKERS:
  - B-1: productRegistryEndpoints.addRepositoryReference (product_registry_endpoints.dart:507,
    returning the non-empty map {'success': true, 'repositoryId': …} at :526) still returns
    Map<String, dynamic> and still throws "No deserialization found for type dynamic" in the
    generated client — reproduced on HEAD through the real Protocol. add_product_page.dart:143
    calls it (via _ensureProductAndRepository:281) immediately BEFORE generateDeployKey at :147,
    so the browser hop still fails on this branch and credentialEndpoints.generate is never
    reached. The dispatch's ACCEPTANCE_CRITERIA (Add Product completes a mint in the live QA stack)
    is unachievable; the dispatch's own failing log (addRepositoryReference 200, then silence)
    matches this call site better than it matches the credential one. FIX: type the return, make
    it the client's discard-value receiver (control_plane_repository.dart:1147), regenerate, and
    add it to the canary.
  - B-2: the assertion added to credential_key_service_postgres_test.dart:442-456 is red on HEAD.
    The generated MintedCredentialView.toJson() includes '__className__' (minted_credential_view.dart
    :141-154) and the expected set omits it, so the test named "the endpoint response contains no
    private material" fails on both the host and no-host paths (measured). FIX: include
    '__className__' or assert over the projection with the framing tag removed, and execute the
    suite via make test-integration before reporting. The report's "No test was weakened" claim is
    false as written.

HIGH:
  - H-1: the 22 remaining map-returning endpoints are recorded but the class was never escalated in
    a form the Manager could act on, and one of them (B-1) is on the acceptance-criteria path.
    13 of the 22 are reachable from the live Flutter client: addRepositoryReference;
    intakeEndpoints.createFeatureRequest; defectEndpoints create/list/inspect/addEvidence/
    answerClarification/verifyFix; providerHealthEndpoints getProviderHealth/listModelPolicies/
    updateModelPolicy/listModelExecutions/getModelStats. Each throws on first use. Record an
    explicit decision on the remaining 12 after B-1.
  - H-2: endpoint_surface_shape_test.dart:231-233 documents Future<Map<String, dynamic>> as "a legal
    endpoint" — generator-legal, wire-broken — and that CONTRADICTION is unreconciled. Amend the
    comment, and replace the two-endpoint canary loop with a scan of the generated client that
    fails on any map-returning endpoint method.

MEDIUM:
  - M-1: report §2's "24 → 23" and §8.1's "22 other endpoints" disagree; the measured figures are
    24 → 22 (the 23 counted a doc-comment line the lane added).
  - M-2: the empty-map asymmetry ({} deserialises, any non-empty map throws) is what makes this
    failure mode look intermittent and get misattributed; it is documented nowhere.
  - M-3: the four NEW_DISCOVERIES are durable and unclassified; the Manager must classify and route
    them per LEARNING_POLICY.md.

LOW:
  - L-1: the dispatch header prohibits packages/** while its body authorises regenerating
    packages/control_plane_client/**. The lane followed the body and disclosed it; fix the header.
  - L-2: AccessVerification.toJson() survives solely for a test that hand-constructs the object; no
    endpoint emits it.
  - L-3: "FILES_CHANGED — 14 files" precedes an 18-entry list.
  - L-4: the schema comment cites model_helper.dart's _modelRootSuffixes as part of the filter; only
    isModelFile is. The claim stands.

CORRECTION_REQUIRED: YES
HUMAN_DECISION_REQUIRED: NO

SAFE_PARALLEL_WORK: none blocked by this review (read-only; nothing written). After correction the
Manager may proceed on docker/** for the B-1-mandated redeploy, migrations/**, tool/**, .github/**,
and docs/** outside this task directory.
PROHIBITED_PARALLEL_WORK: product_registry_endpoints.dart, apps/server/lib/src/models/*.yaml,
apps/server/lib/src/generated/protocol.dart, packages/control_plane_client/**,
apps/server/test/credential_wire_return_type_test.dart,
apps/server/test/credential_endpoint_wire_test.dart,
apps/server/test/integration/credential_key_service_postgres_test.dart.
```
