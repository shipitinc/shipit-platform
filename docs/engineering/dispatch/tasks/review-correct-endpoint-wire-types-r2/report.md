# Focused re-review — correct-endpoint-wire-types-r2

```
RESULT: APPROVE_CORRECTIONS

REVIEWED_HEAD: dcf1edeeadfbeef3b324cc885524c472f5b34db0

FINDINGS_REVIEWED:

REGRESSIONS:

BLOCKERS:

READY_FOR_MERGE: YES
```

---

## Provenance

| check | result |
|---|---|
| worktree | `/private/tmp/shipit-fix-endpoint-types`, branch `fix/credential-endpoint-return-types` |
| `git rev-parse HEAD` | `dcf1edeeadfbeef3b324cc885524c472f5b34db0` — **matches the lane's `NEW_HEAD`** |
| `CORRECTED_FROM_HEAD` | `77d984a` — present in history, exactly 3 commits back |
| commits on top of `77d984a` | `0dab461`, `72e90a5`, `dcf1ede` (4 with `77d984a` inclusive) |
| `git status --porcelain` | **empty before and after this review** — the reviewed worktree is pristine |

The two prior commits (`fc76d39`, `77d984a`) are untouched; the correction is additive.

**This lane was read-only.** No file in the reviewed worktree was modified. `serverpod generate` was run in a
throwaway mirror under `/tmp/opencode/` (since deleted), precisely so the reviewed tree could not be dirtied.
**Zero mutating Docker/Compose commands were issued by this review** — none at all, not even `docker compose ps`
or `docker info`. The single database path used was the sanctioned `make test-integration`; its own
leak-detecting `trap` took the success branch and removed project `shipit_integration_34474` (container and
network both `Removed`). The live QA stack was not touched.

---

## 1. B-1 — genuinely closed, and by the class, not the one call

### 1a. The endpoint is typed

`product_registry_endpoints.dart:525` now declares `Future<RepositoryReferenceAddedView>`, and at `:542-545`
constructs `RepositoryReferenceAddedView(success: true, repositoryId: ref.repositoryId)` instead of returning
`{'success': true, 'repositoryId': …}`. The generated client mirrors it (`client.dart:970,976`:
`callServerEndpoint<_i28.RepositoryReferenceAddedView>`). The call at `control_plane_repository.dart:1147` is
unchanged and still discards the value.

### 1b. I traced the path **from the page**, not from the lane's list

`grep '_repository\.'` over `add_product_page.dart` returns **exactly five** calls. That is the whole path:

```
add_product_page.dart:275  createProduct         → ProductDetailView
add_product_page.dart:281  addRepositoryReference→ RepositoryReferenceAddedView   ← was the throw
add_product_page.dart:147  generateDeployKey     → MintedCredentialView
add_product_page.dart:176  verifyDeployKeyAccess → CredentialAccessVerificationView
add_product_page.dart:235  getProductDetail      → ProductDetailView
```

The page makes **no other** repository call. `listProductSummaries` is not on the page.

**Correction to the lane's prose (LOW, harmless):** the report says `listProductSummaries` is called by
"the page's own load path". It is not — it is called by `app_shell.dart:86`
(`_count(() => repository.listProductSummaries()...)`). The call does happen while the Add Product page is
mounted, because the app shell wraps the route, so the **coverage claim holds**; only the provenance sentence
is wrong. Worth fixing because the next reviewer may look for a page-level call that does not exist.

### 1c. Every one of those endpoints has a real `Protocol.deserialize` branch

I did not accept "typed" as sufficient — a type with no branch fails exactly like `dynamic` does. I extracted all
59 endpoint methods from `client.dart` and cross-referenced their element types against the **204** `if (t == …)`
branches in the generated `Protocol.deserialize`:

| endpoint | declared return | element type | branch present |
|---|---|---|---|
| `productRegistryEndpoints.createProduct` | `ProductDetailView` | `ProductDetailView` | ✅ |
| `productRegistryEndpoints.addRepositoryReference` | `RepositoryReferenceAddedView` | `RepositoryReferenceAddedView` | ✅ |
| `productRegistryEndpoints.productDetail` | `ProductDetailView` | `ProductDetailView` | ✅ |
| `productRegistryEndpoints.listProductSummaries` | `List<ProductSummaryView>` | `ProductSummaryView` | ✅ |
| `credentialEndpoints.generate` | `MintedCredentialView` | `MintedCredentialView` | ✅ |
| `credentialEndpoints.verifyAccess` | `CredentialAccessVerificationView` | `CredentialAccessVerificationView` | ✅ |

Sweeping **all 59** endpoint methods, exactly one element type has no branch:
`resolvePolicyAuthorisation -> StandingPolicyView?`. It is a **nullable** type, resolved through the
`deserializeByClassName` path, and it is **pre-existing** (present identically at `cf1b210` and `77d984a`) —
out of scope for this correction and not a regression.

**B-1 is closed. The `No deserialization found for type dynamic` throw at `add_product_page.dart:143` is
structurally gone: the call now returns a model the client can deserialize, and the mint at `:147` is reachable.**

---

## 2. All 22 typed, and the canary is a real scan

### 2a. The count, verified independently — **22 → 0**

```
callServerEndpoint<Map<String, dynamic>> in packages/…/client.dart
  77d984a : 22 real code sites  + 1 doc-comment line   (that doc line is the lane's own client.dart:106)
  dcf1ede :  0 real code sites  + 1 doc-comment line
  cf1b210 : 24 real code sites  (matches my prior review's measured figure)
```

The single HEAD match is inside a doc comment (`/// callServerEndpoint<Map<String, dynamic>>, whose`) — verified
by reading its context, not by trusting a count. The report's "no `callServerEndpoint<Map<String, dynamic>>`
site at all" is true for code.

I also re-implemented the canary's scan algorithm independently in Python against the real generated client:
**12 endpoint classes, 59 methods, 0 offenders**. The count is right.

### 2b. The scan cannot pass vacuously — **proved, not asserted**

This is the failure mode the whole work item keeps hitting, so I attacked it directly in a throwaway mirror.

**Vacuous-pass probe.** I ran the canary's own code with its `classPattern` altered so it matches **0** classes
(the code still compiled). Result:

```
+1  the scan actually reads the generated client   ← the scan test went GREEN (0 offenders)
+1 -1  … [E]  Expected: a value greater than <50>
             Actual: <0>
             only 0 endpoint methods found in …/client.dart. The generator changed the file layout,
             so this scan is reading nothing and would pass for the wrong reason.
```

That is precisely the vacuous green, and the guard caught it. **The guard works.**

### 2c. It fails on regression — **proved twice, including off the named list**

| experiment | result |
|---|---|
| Revert `addRepositoryReference` to `Map<String, dynamic>` (B-1's own endpoint) | **RED.** Scan: `Offenders: [EndpointProductRegistryEndpoints.addRepositoryReference -> Map<String, dynamic>]`. Named test also red: `Expected: not 'Map<String, dynamic>' / Actual: 'Map<String, dynamic>'` |
| Revert `workerEndpoints.inspect` to `Map<String, dynamic>` — **not in the canary's named list at all** | **RED.** `Offenders: [EndpointWorkerEndpoints.inspect -> Map<String, dynamic>]`, while all six named path tests stayed green |

The second experiment is the decisive one: it shows the scan covers the **class**, not the six names, which was
the entire point of H-2. A hand-maintained list could not have caught it.

**Residual coverage note (LOW):** the scan inspects **return types only**, while the failure message says methods
"return **or accept** `Map<String, dynamic>`". I checked: **0** endpoint methods currently take a
`Map<String, dynamic>` parameter, so nothing is missed today, and a request-side parameter would not affect
response deserialization in any case. The message overstates the scan by one word.

---

## 3. B-2 closed **and the test was actually executed**

`'__className__'` is in the expected set (`credential_key_service_postgres_test.dart:461`), with the reasoning
written inline.

**I executed the suite myself at HEAD rather than taking the numbers on trust:**

```
$ make test-integration
01:26 +191 -1: Some tests failed.

Failing tests:
  test/integration/dogfood_shipit_postgres_test.dart: S-1 DOGFOOD — Product: ShipIt (Postgres, read-only) …
```

```
dogfood expects a git working tree at /private/tmp/shipit-fix-endpoint-types
```

**+191 −1 — exactly the reported figures**, and the sole failure is the **known linked-worktree artefact**,
whose cause I read out of the log rather than inferring it. It is not a regression: it is a property of the
worktree path, not of the code.

**Cleanup confirmed.** The target's own `trap` printed the removal of `shipit_integration_34474`'s container and
network and took the success branch (no `CLEANUP FAILED`). I issued no further Docker commands.

**B-2 is closed. The point of the finding was that "analyzed, not executed" let a red assertion ship; the suite
is green on execution, not by argument.**

---

## 4. No test weakened — **verified, and held to the standard that was false last round**

The prior review's finding was that this exact claim was false. I re-checked it from scratch.

**Skip/ignore/filter sweep** across `apps/server/test/**` and `apps/control_plane/test/**` for
`@Ignore`, `@Skip`, `skip:`, `tags:`, `only:`, `exclude`, `xfail` in **added** lines: **none.**
Pre-existing `@Ignore|@Skip|skip:` counts in the five touched integration files: **0 before, 0 after** in every one.

**Test cases and assertions, counted both revisions:**

| file | tests | expects |
|---|---|---|
| `defect_backend_postgres_test.dart` | 14 → **14** | 54 → **54** |
| `triage_execution_test.dart` | 23 → **23** | 231 → **231** |
| `feature_request_intake_test.dart` | 4 → **4** | 11 → **11** |
| `lane_f_production_reachability_test.dart` | 5 → **5** | 154 → **154** |
| `credential_key_service_postgres_test.dart` | 20 → **20** | 76 → **76** |
| `credential_wire_return_type_test.dart` | 3 → **6** | 8 → **14** |
| `credential_endpoint_wire_test.dart` | 7 → **7** | 19 → **20** |
| `endpoint_surface_shape_test.dart` | 2 → **2** | 3 → **3** |

Nothing deleted, nothing skipped; two files gained tests. The 93/56-line deletions in
`defect_backend`/`triage_execution` are verbose map-index reads replaced by shorter typed reads, not removed
coverage — the assertion counts prove it.

**The `no private material` test, compared against base `cf1b210`:** every original assertion survives
(`privateKey`/`private` key absence, `PRIVATE KEY` substring, the literal PEM, base64 of the PEM, the per-value
sweep), and it **gained** a `response.fingerprint` assertion and the entire key-set whitelist. The file diff is
**17 insertions, 0 deletions**. Adding `__className__` to an equality assertion on the key set does **not**
weaken it: equality still means any unlisted new payload key fails.

**The "relocated" assertions the lane flagged itself — they are a strengthening, not a weakening.** In
`credential_endpoint_wire_test.dart` the primary assertion moved from `decode<Map<String, dynamic>>(body)` to
`deserialize<dynamic>(jsonDecode(body))`. That change is *forced*: once the last map-returning endpoint is
typed, the generated branch is gone and the old form throws about a different thing. Critically, **the old form
is retained as a second assertion**, which now pins the branch's disappearance — so if a map-returning endpoint
is ever added back, that assertion fails. Nothing was lost; one fact was added.

**The claim now holds. This is the specific claim that was false last round, and it is true this round.**

---

## 5. Private material — re-audited field by field

### 5a. The `.bytes` site lists, diffed — **not accepted as a count**

```
rg -n "\.bytes" apps/server/lib   →  77d984a: 18 lines ; dcf1ede: 18 lines
diff of the two full site lists   →  EMPTY
```

I did not take the count on trust. My first diff showed 18 changed lines — because `git grep` prefixes each
line with the revision SHA. Re-diffing with the prefix stripped gives a **byte-identical** list of all 18 sites.
The three material-producing sites (`local_file_secret_provider.dart:73`, `gcp_secret_manager_secret_provider.dart:143`,
`repository_access_verifier.dart:364`) and the crypto sites in `ssh_keypair.dart` are unchanged. **Claim verified.**

### 5b. The two newly-typed models, projection by projection

`MintedCredentialView.toJson()` is a **closed** 11-key map — `__className__`, `credentialId`, `productId`,
`repositoryId`, `publicKey`, `fingerprint`, `algorithm`, `referenceName`, `status`, `hostKeyStatus`,
`host` (conditional). Every payload value is a `String`. No `SecretBytes`, no `ByteData`, no `Uint8List`,
no `List<int>`, and no field that could grow into one.

`RepositoryReferenceAddedView.toJson()` is 3 keys: `__className__`, `success` (bool), `repositoryId` (String).

Across **all 51** new schemas, **no** byte-carrying field type is declared. The only `SecretBytes`/`ByteData`
hits in any of them are inside the `minted_credential_view.yaml` **header comment** explaining their absence.

### 5c. The structural guarantee is the strong part

`grep toJson() apps/server/lib/src/endpoints/*.dart` finds **no** `toJson()` in any projection — all six
rewritten endpoint files use **named copies**, documented as such at `defect_endpoints.dart:311`,
`execution_endpoints.dart:87`, `provider_health_endpoints.dart:215`, `scheduler_endpoints.dart:75`,
`worker_endpoints.dart:104`. So a field added to a domain type **breaks the build at the projection** rather
than silently widening a wire contract. Leaking would require editing the schema, the generator output, the
endpoint and the whitelist assertion together.

**No private half is reachable, serialisable or leaked. Invariant holds.**

---

## 6. The constraint it measured — verified, and correctly judged

**The convention claim is true, and pre-dates this correction.** At `cf1b210` — before any of this work —
`defect_endpoints.dart` already published `'clientContextJson'`, `'metadataJson'` and `'payloadJson'` as **text**
(`'clientContextJson': d.clientContextJson`), and `human_direction_view.dart` was already a typed model
carrying `metadataJson: String?`. The lane adopted the convention that was already in the repository rather
than inventing one. That is the right call and it is verifiable.

**Nothing on the Add Product path carries a JSON-text field.** I checked all five view types reachable from the
page — `minted_credential_view`, `credential_access_verification_view`, `repository_reference_added_view`,
`product_detail_view`, `product_summary_view` — for any `*Json`/`metadata`/`payload`/`structuredResult` field:

> **zero, in every one of them.**

So the eight open-ended values cannot reintroduce parsing fragility on the critical path, which was the specific
thing to check.

**Stronger than required:** the client performs **zero** `jsonDecode` calls in
`control_plane_repository.dart`. Those values are opaque strings to the client — no parsing anywhere, which is
the lowest-fragility outcome available.

One presentational note: the report enumerates 8 domain fields; the corresponding views actually carry 11
`*Json` fields across 9 files (the extra three are `human_direction_*`, which were already typed at base).
This strengthens rather than weakens the "existing convention" claim — it shows the convention reaches further
than the report says.

---

## 7. The two items it flagged — both judged

### 7a. Migration ordering — the lane is **right**, and I verified it deeper than it did

`WorkerRegistrationView.capabilities` is `Map<String, CapabilitySpecView>`; `WorkerRegistration.capabilities`
is keyed by the `WorkerCapability` **enum**. I traced the actual wire, not the type:

- `WorkerRegistrationCodec.toJson` (`packages/worker_runtime/lib/src/store/worker_registration_store.dart:36`)
  — the codec the **old** endpoint published through — already keyed the map by **`capability.name`**.
- The new projection `_registrationView` (`worker_endpoints.dart:136-139`) keys by **`capability.name`** —
  the identical string.
- `WorkerCapability` has **no `toString()` override**, so `.toString() == .name` and no divergence is possible.
- The value shape is preserved too: `CapabilitySpecView{capability, version, metadata: Map<String,String>?,
  providedTools: List<String>?}` matches the old `_specToJson` field for field.

**So this is not a re-keying at all.** The wire keys are byte-identical before and after; only the Dart static
type changed, inside a named projection. There is nothing untested about the map itself.

**Judgement on the lane's question — must an untested re-keying block? No, and this one does not block:**

1. The wire keys are provably identical (above), so there is no behavioural change to test.
2. `workerEndpoints.listWorkers` has **no client caller** — `grep listWorkers apps/control_plane/lib` finds none.
3. The correction is not migratable separately from `77d984a` only because the *typed* endpoints differ, which
   is the normal consequence of changing a contract, and the lane flagged it correctly.

**One measurement worth recording (LOW, informational).** The lane claims Serverpod's `DateTime.toJson()`
"emits the identical `"2026-01-02T03:04:05.000Z"` form those adapters already parsed". For the endpoint it
cites this is exactly true — old `health()` used `DateTime.now().toUtc().toIso8601String()`, new is
`DateTime.now().toUtc()` → `toUtc().toIso8601String()`. Byte-identical. But Serverpod 3.4.13 implements it as
`toUtc().toIso8601String()`, while `WorkerRegistrationCodec` used bare `.toIso8601String()` with **no**
`toUtc()`. For a UTC value (what Postgres returns) the strings match; for a hypothetical local value the new
form would normalise the offset to `Z`. Both parse via `DateTime.parse`. Not a blocker, and not something the
lane asserted wrongly about the endpoint it cited — but the blanket "identical form" is only strictly true for
UTC values.

### 7b. `updateModelPolicy` — verified, and **not** a breaking change

The account is exactly right, and I confirmed each link:

- The client declared `Future<ModelPolicyResponse>`; `ModelPolicyResponse.fromJson` reads
  `role: json['role'] as String`, and the server returned `{'success': true}` — so the pair **could not have
  worked** if the result had ever been read. The lane's "it worked only because its one caller discards the
  result" is correct.
- The server now returns `ModelPolicyView`, which declares **`role: String`** — so `fromJson` now receives it.
  I checked the whole round trip: `ModelPolicyView.toJson()` supplies `role`, `chain` (list of maps),
  `version`, `updatedAt` (String via `.toJson()`), `updatedByDecisionId` — every key
  `ModelPolicyResponse.fromJson` reads, with compatible types. `isActive` defaults to `false`.
- **The one caller** (`model_policies_page.dart:204`) `await`s the call **without binding the result**, then
  dispatches `ModelPoliciesLoaded` to re-fetch the list. It never reads the value.

**Not breaking for the existing caller** — it goes from a latent throw to a correct value nobody reads.

---

## 8. Gates — re-run independently

| gate | command | result |
|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | **pass** — exit 0, `Formatted 765 files (0 changed)` |
| analyze (server) | `dart analyze apps/server` | **pass** — `No issues found!` |
| analyze (client) | `cd apps/control_plane && flutter analyze` | **pass** — `No issues found!` |
| unit | 7 DB-free suites under `apps/server/test/` | **pass** — **+88**, `All tests passed!` |
| integration | `make test-integration` | **pass with 1 known artefact** — **+191, −1**; sole failure `dogfood_shipit_postgres_test.dart` (`dogfood expects a git working tree at /private/tmp/shipit-fix-endpoint-types`), self-cleaned |
| flutter tests | `cd apps/control_plane && flutter test` | **pass** — **+271**, `All tests passed!` |
| generate | `dart run serverpod_cli generate` (throwaway mirror) | **pass** — exit 0; fresh output **byte-identical** to the committed `apps/server/lib/src/generated/` and `packages/control_plane_client/lib/src/protocol/`; second run idempotent (`protocol.dart` md5 `6a058ae5…` server / `df76326d…` client, unchanged) |

The client `protocol.dart` md5 `df76326d…` matches the lane's reported value exactly.

**`apps/server/test/onboarding_test.dart`** fails standalone with
`SocketException: Connection refused … port = 59609` — it needs a database and is not run by
`make test-integration`. Pre-existing and correctly disclosed by the lane. It remains an uncovered suite; see
L-5.

---

## Regression sweep over the correction itself

**Response fields dropped by the eight endpoint rewrites: none.** I extracted every string key the old endpoint
files published (109 keys) and intersected them with every field declared across all server models (318). One
key had no match — **`action`** — and reading its context shows it is a **`logger` field** in a `catch` block
(`product_registry_endpoints.dart:183`), not a response key; `requestLifecycleDecision` returns `DecisionView`
and was never one of the 22.

**Client call sites converted: 13, none lossy.** The full `control_plane_repository.dart` diff is 17 removed / 16
added lines, all mechanical `Response.fromJson(result)` → `Response.fromJson(result.toJson())`, plus the
`createFeatureRequest` field reads becoming typed. `createdAt` is still emitted as a **String**
(`'createdAt': createdAt.toJson()`), so `DateTime.parse` in `fromJson` is unaffected.

**Prohibited paths: untouched.** Across the whole branch `cf1b210..dcf1ede`, nothing under
`apps/server/migrations/`, `apps/server/tool/`, `apps/server/lib/server.dart`, `docker/`, `.github/`,
`.decisions/`, `.agents/`, `.claude/`, `.junie/`, `.opencode/` was changed. Confirmed by name-list filter, not
by trusting the report.

**H-2 correctly closed.** `endpoint_surface_shape_test.dart` now states plainly that generator-legality is not
wire-legality, shows the emitted branch, names both counter-examples (including which one is on the
acceptance path), documents the empty-map asymmetry, and — importantly — carries an explicit instruction **not**
to widen that function's remit, with the reason. That is the right boundary, argued in the file.

**M-2, M-1, L-4 addressed** (asymmetry documented in both files; measured figures 24 → 22; schema comment cites
`isModelFile` alone). **M-3 handed off** — `NEW_DISCOVERIES` are now classified. That routing remains the
Manager's; I record it below rather than treat it as closed.

---

## Findings carried forward — none blocking

- **L-1 — `toJsonObject` / `toJsonList` are now dead code.** After the eight endpoint rewrites, only their
  declarations remain (`apps/server/lib/src/services/structured_logger.dart:45,49`). Housekeeping; remove or
  keep deliberately.
- **L-2 — report provenance slip.** `listProductSummaries` is called by `app_shell.dart:86`, not by the Add
  Product page's load path. The coverage claim still holds; the sentence does not.
- **L-3 — canary message overstates the scan by one word.** The failure text says methods "return **or
  accept** `Map<String, dynamic>`"; the scan inspects return types only. Verified there are 0 such parameters
  today, so nothing is missed — but the next reader will trust that sentence.
- **L-4 — `DateTime` normalisation.** Serverpod emits `toUtc().toIso8601String()`; `WorkerRegistrationCodec`
  emitted bare `.toIso8601String()`. Identical for UTC values (all that Postgres returns); both parse.
- **L-5 — `onboarding_test.dart` runs under no gate.** It needs a database, is excluded from
  `make test-integration`, and therefore executes in no CI or local path. Pre-existing, and it is exactly the
  gap the lane's F-A/F-B notes describe.
- **Manager routing still open (M-3):** the lane's `NEW_DISCOVERIES` are now classified
  (`PROJECT_FACT` ×2, `QA_DISCOVERY`, `ANNOTATION_OPPORTUNITY`, `RUNTIME_DISCOVERY`) but not yet persisted into
  the authoritative artifact. That is the Manager's call, not this review's, and it is not a merge blocker.

---

## Verdict

Both blockers are closed and closed **by the mechanism, not by the instance**: the endpoint class is gone rather
than narrowed, and the canary is a scan I proved catches regressions on endpoints it was never told about and
proved goes red rather than green when it is auditing nothing.

The claim that was false last round — "no test was weakened" — is true this round, and I verified it by
counting test cases and assertions in both revisions rather than reading the assertion.

All eight gates pass on re-run, including the integration suite **executed rather than analysed**, with the
sole failure being the linked-worktree artefact the Manager has already identified.

The two flagged items are both correctly judged: the "re-keying" is wire-identical and does not need to block,
and `updateModelPolicy` is a latent-bug fix that breaks no caller.

The Add Product path is deserialisable end to end. The acceptance criterion is achievable from this branch —
subject to the Manager's post-integration browser verification against the redeployed QA stack, which is the
one thing neither this lane nor I can do, and which is now expected to get past `addRepositoryReference`.

---

## What I verified independently (commands and results)

| check | result |
|---|---|
| provenance | HEAD `dcf1edeeadf…`, clean tree, `77d984a` three commits back, matches lane's `NEW_HEAD` |
| **B-1** endpoint typed | server `Future<RepositoryReferenceAddedView>` at `:525`, client `callServerEndpoint<_i28.RepositoryReferenceAddedView>` at `client.dart:970,976` |
| **B-1** path traced **from the page** | `add_product_page.dart` has exactly 5 `_repository.*` calls; all 5 mapped to endpoint methods with a real `deserialize` branch |
| endpoint branch coverage | all 59 client methods cross-referenced against 204 `Protocol.deserialize` branches; only pre-existing nullable `StandingPolicyView?` lacks one |
| **22 count** | 22 real sites at `77d984a`, 0 at HEAD (HEAD match verified as a doc comment); `cf1b210` = 24 |
| canary scan coverage | independent re-implementation: 12 classes, 59 methods, 0 offenders |
| **vacuous-pass guard** | probe with a pattern matching 0 classes: scan test **green**, guard **red** (`Expected: greater than <50>, Actual: <0>`) |
| **regression proof** | `addRepositoryReference` → map: **RED**; `workerEndpoints.inspect` (unnamed) → map: **RED** |
| parameter coverage | 0 endpoint methods take a `Map<String, dynamic>` parameter |
| **B-2** | `'__className__'` at `:461`; **`make test-integration` executed by me: +191 −1** |
| dogfood cause | read from log: `dogfood expects a git working tree at /private/tmp/shipit-fix-endpoint-types` |
| cleanup | target's own trap removed `shipit_integration_34474` container + network, success branch |
| test weakening | 0 added `@Ignore`/`@Skip`/`skip:`/`tags:`/`only:`; 0 → 0 pre-existing in all 5 touched integration files |
| test/assert counts | identical or higher in all 8 touched test files (table in §4) |
| `no private material` | every base assertion intact, **plus** `fingerprint` **plus** the key-set whitelist; file diff 17 insertions / **0 deletions** |
| `.bytes` audit | 18 → 18, **diff empty** after stripping the revision prefix |
| model byte fields | 0 byte-carrying field across all 51 schemas; only comment mentions |
| projections | **no `toJson()`** in any endpoint file — all named copies |
| response-field loss | 109 old published keys vs 318 model fields; only `action`, which is a **logger** key |
| client call sites | 13 converted, 17 removed / 16 added lines, all mechanical; `createdAt` still a String on the wire |
| **JSON-text convention** | pre-existing at `cf1b210` (`defect_endpoints.dart`, `human_direction_view.dart`); **0** such fields on all 5 Add Product views; client does **0** `jsonDecode` |
| **7a** re-keying | `WorkerRegistrationCodec.toJson` keys by `capability.name`; new projection keys by `capability.name`; enum has no `toString()` override; value shape identical |
| **7a** DateTime | Serverpod = `toUtc().toIso8601String()`; old worker codec = bare `.toIso8601String()`; identical for UTC |
| **7b** | `ModelPolicyView.role` now supplied; `ModelPolicyResponse.fromJson` reads only keys the view provides; sole caller discards the result |
| prohibited paths | `migrations/`, `tool/`, `lib/server.dart`, `docker/`, `.github/`, `.decisions/`, `.agents/`, `.claude/`, `.junie/`, `.opencode/` — **none touched** across `cf1b210..dcf1ede` |
| format / analyze / unit / flutter / generate | all re-run, all pass (table in §8) |

---

## Post-review state

```
RESULT: APPROVE_CORRECTIONS

REVIEWED_HEAD: dcf1edeeadfbeef3b324cc885524c472f5b34db0

FINDINGS_REVIEWED:
  - B-1: CLOSED by the class. productRegistryEndpoints.addRepositoryReference returns
    RepositoryReferenceAddedView (server product_registry_endpoints.dart:525, client
    client.dart:970/976). The Add Product path was traced FROM THE PAGE, not from the lane's
    list: add_product_page.dart makes exactly five _repository calls — createProduct:275,
    addRepositoryReference:281, generateDeployKey:147, verifyDeployKeyAccess:176,
    getProductDetail:235 — and all five map to endpoint methods whose element type has a real
    branch in the generated Protocol.deserialize (204 branches; all 59 client methods swept).
    The No deserialization found for type dynamic throw at :143 is structurally gone and the
    mint at :147 is reachable.
    (LOW, non-blocking: the report says listProductSummaries is on "the page's own load path";
    it is called by app_shell.dart:86. The call still happens while the page is mounted, so the
    coverage claim holds; only the provenance sentence is wrong.)

REGRESSIONS:
  - None found.
    - Response fields dropped by the eight endpoint rewrites: NONE. All 109 string keys the old
      endpoint files published were intersected with all 318 fields declared across the server
      models; the single unmatched key, 'action', is a logger field in a catch block, not a
      response key.
    - No client field read was dropped: control_plane_repository.dart is a 17-removed/16-added
      mechanical conversion, and createdAt is still emitted as a String on the wire.
    - No test weakened, skipped, @Ignored, filtered or deleted: 0 added skip/ignore/filter
      tokens; 0 -> 0 pre-existing in all five touched integration files; test-case and assertion
      counts identical or higher in all eight touched test files; the 'no private material' test
      gained a fingerprint assertion and the key-set whitelist with a 17-insertions/0-deletions
      file diff.
    - Private material: .bytes site lists byte-identical 18 -> 18; no byte-carrying field on any
      of the 51 schemas; both new models project closed all-String maps; no toJson() in any
      endpoint projection, so the guarantee is compile-time, not by convention.
    - Prohibited paths untouched across cf1b210..dcf1ede.
    - H-2 correctly closed, including the in-file instruction not to widen that guard's remit.

BLOCKERS:
  - None.

READY_FOR_MERGE: YES
```

**Gate summary:** format exit 0 (765 files, 0 changed) · `dart analyze apps/server` clean · `flutter analyze`
clean · `flutter test` +271 · 7 DB-free suites +88 · `make test-integration` +191 −1 (sole failure the
known `dogfood_shipit_postgres_test.dart` linked-worktree artefact; self-cleaned, project
`shipit_integration_34474` removed) · `serverpod generate` exit 0, byte-identical to committed, idempotent.

**Manager's remaining work (not a merge blocker):** redeploy the QA stack from this HEAD and perform the
browser hop yourself — it is the one piece of evidence neither lane can produce — and route the lane's now
classified `NEW_DISCOVERIES` per `LEARNING_POLICY.md` (M-3), of which the `PROJECT_FACT` about Serverpod 3.4.13
having no arbitrary-JSON model type is the most durable.
