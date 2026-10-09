# Correction report — correct-endpoint-wire-types-r2

```yaml
RESULT: CORRECTION_COMPLETE
TASK_ID: correct-endpoint-wire-types-r2
CORRECTED_FROM_HEAD: 77d984a780baa8b4efc51f45ce5f49afaa563ea0
NEW_HEAD: dcf1edeeadfbeef3b324cc885524c472f5b34db0
BRANCH: fix/credential-endpoint-return-types
WORKTREE: /private/tmp/shipit-fix-endpoint-types
BASE_SHA: cf1b2106b75238da4b43ebbff05e06414f2793ed
READY_FOR_FOCUSED_REVIEW: YES
HUMAN_DECISION_REQUIRED: NO
```

The two existing commits (`fc76d39`, `77d984a`) are untouched. This is four new
commits on top.

---

## Provenance verified before writing

`git branch --show-current` = `fix/credential-endpoint-return-types`.
`git rev-parse HEAD` = `77d984a780baa8b4efc51f45ce5f49afaa563ea0`, which is the
two-commit tip over `cf1b210`. `git status --porcelain` empty. Nothing was written
before that check.

---

## The three findings, and what each cost

### B-1 — fixed. The whole class, not the one call.

`productRegistryEndpoints.addRepositoryReference` returned a non-empty
`Map<String, dynamic>` (`{'success': true, 'repositoryId': …}`). It now returns
`RepositoryReferenceAddedView`, generated from
`apps/server/lib/src/models/repository_reference_added_view.yaml`.

**I traced the Add Product path from the page, not from the dispatch's list.**
`AddProductBloc._onCheckAccessRequested` runs, on one press of one control:

| # | call | was | now |
|---|---|---|---|
| 1 | `createProduct` | `ProductDetailView` | typed (already) |
| 2 | **`addRepositoryReference`** | **`Map<String, dynamic>`** | **`RepositoryReferenceAddedView`** |
| 3 | `generate` | fixed in `fc76d39` | `MintedCredentialView` |
| 4 | `verifyAccess` | fixed in `fc76d39` | `CredentialAccessVerificationView` |
| 5 | `productDetail` (on Register) | `ProductDetailView` | typed (already) |
| 6 | `listProductSummaries` | `List<ProductSummaryView>` | typed (already) |

The reviewer was right that fixing only the two named calls is what produced this
round, so **all 22** are typed. The count is confirmed by the canary, not by a
grep: at `77d984a` the scan names exactly 22 offenders, and at this HEAD it names
none.

### B-2 — fixed, and executed.

`'__className__'` added to the expected set at
`credential_key_service_postgres_test.dart`, with a comment saying it is the one
key in that map which is framing rather than payload, so a genuinely new payload
field still fails.

**`make test-integration` was executed**, twice at `77d984a` and twice at HEAD.

### The 22 — fixed, none left

`grep -rn "Future<Map<String, dynamic>>" apps/server/lib/src/endpoints/` returns
nothing but one explanatory comment. The generated client has no
`callServerEndpoint<Map<String, dynamic>>` site at all. **No endpoint was left
silently untyped** — the one place that looked like it might need an exception is
below.

---

## Proof required, item by item

### 1. A test that fails at `77d984a`

Throwaway worktree at `77d984a`, with **only** `credential_wire_return_type_test.dart`
and its fixtures copied in and no correction present:

```
$ dart test test/credential_wire_return_type_test.dart
00:00 +9 -2: Some tests failed.

Failing tests:
  ... the generated client declares no map-returning endpoint method
  ... productRegistryEndpoints.addRepositoryReference returns a serialisable model
```

The scan's failure message names all 22, verbatim:

```
Offenders: [EndpointDefectEndpoints.create -> Map<String, dynamic>,
 EndpointDefectEndpoints.list -> Map<String, dynamic>,
 EndpointDefectEndpoints.inspect -> Map<String, dynamic>,
 EndpointDefectEndpoints.addEvidence -> Map<String, dynamic>,
 EndpointDefectEndpoints.requestClarification -> Map<String, dynamic>,
 EndpointDefectEndpoints.answerClarification -> Map<String, dynamic>,
 EndpointDefectEndpoints.verifyFix -> Map<String, dynamic>,
 EndpointExecutionEndpoints.list -> Map<String, dynamic>,
 EndpointExecutionEndpoints.inspect -> Map<String, dynamic>,
 EndpointHealthEndpoints.health -> Map<String, dynamic>,
 EndpointIntakeEndpoints.createFeatureRequest -> Map<String, dynamic>,
 EndpointProductRegistryEndpoints.addRepositoryReference -> Map<String, dynamic>,
 EndpointProviderHealthEndpoints.getProviderHealth -> Map<String, dynamic>,
 EndpointProviderHealthEndpoints.listModelPolicies -> Map<String, dynamic>,
 EndpointProviderHealthEndpoints.updateModelPolicy -> Map<String, dynamic>,
 EndpointProviderHealthEndpoints.listModelExecutions -> Map<String, dynamic>,
 EndpointProviderHealthEndpoints.getModelStats -> Map<String, dynamic>,
 EndpointSchedulerEndpoints.listJobs -> Map<String, dynamic>,
 EndpointSchedulerEndpoints.inspect -> Map<String, dynamic>,
 EndpointWorkerEndpoints.listWorkers -> Map<String, dynamic>,
 EndpointWorkerEndpoints.listExecutions -> Map<String, dynamic>,
 EndpointWorkerEndpoints.inspect -> Map<String, dynamic>]
```

and the named path call reads:

```
Expected: not 'Map<String, dynamic>'
  Actual: 'Map<String, dynamic>'
```

At `dcf1ede`, same file, same command: **`+18, All tests passed`**. The `77d984a`
worktree was removed afterwards (`git worktree remove --force` + `prune`).

### 2. `make test-integration` executed — the real numbers

| revision | result |
|---|---|
| `77d984a` (baseline, before any of my edits) | **190 passed, 2 failed** |
| `dcf1ede` (this HEAD) | **191 passed, 1 failed** |

**Yes — the sole failure is `dogfood_shipit_postgres_test.dart`**, the known
linked-worktree artefact:

```
dogfood expects a git working tree at /private/tmp/shipit-fix-endpoint-types
```

That is the *only* failure at HEAD, and it also fails at `77d984a`, so it is not
a regression from this correction. The baseline's second failure was B-2 itself —
the red assertion this correction fixes.

B-2 was therefore caught by execution, not by analysis, exactly as the reviewer
said it would be. It also caught two more of my own edits that `dart analyze`
could not see (`isA<String>()` on a field that is now a real `DateTime`; a
`toJson()` key-set that omits a null field), both fixed and both re-run green.

`make test-integration` was the only database path used. It self-cleaned on every
run (`shipit_integration_<pid>` removed each time, verified in the target's own
output). **Zero mutating Docker/Compose commands were issued** — no `down`, `up`,
`stop`, `rm`, `prune`, no `docker compose ps`, no `docker info`. Compose files
were read as text only. `make clean`, `qa-down`, `test-env-down`, `e2e-down` and
bare `down -v` were never invoked.

### 3. `.bytes` audit — before and after, and the full site lists diffed

```
$ rg -n "\.bytes" apps/server/lib | sort   → 77d984a: 18 lines ; dcf1ede: 18 lines
$ diff base.txt head.txt                    → EMPTY
```

Re-measured the same way the reviewer measured the previous round — as a diff of
the two full site lists, not a matching count. **The private-material site count
has not risen: 18 before, 18 after, identical sites.** All three
material-producing sites (`local_file_secret_provider.dart:73`,
`gcp_secret_manager_secret_provider.dart:143`, `repository_access_verifier.dart:364`)
and the crypto sites in `ssh_keypair.dart` are untouched.

Independently, none of the 51 new model schemas declares a byte-carrying field:
no `ByteData`, `SecretBytes`, `Uint8List` or `List<int>` on any of them.

**The private half was never printed, logged or echoed** — not in code, not in a
test, not in this report.

---

## The constraint I had to measure, and it decided four endpoints

Serverpod 3.4.13 **has no type that can hold arbitrary JSON**. Measured on a
scratch schema (since deleted, and the fresh `serverpod generate` after its
deletion produced byte-identical output):

```
Error on line 4, column 6 of zz_probe_view.yaml:
  The datatype "dynamic" is not supported in models.
```

So a `Map<String, dynamic>` **model field** would fail identically one level down.
Eight values are open-ended JSON — `Defect.clientContextJson`,
`Defect.metadataJson`, `DefectEvent.payloadJson`, `AgentExecution.metadata`,
`AgentEventRecord.payload`, `AgentResult.structuredResult`,
`SchedulerEventRecord.payload`, `WorkerEventRecord.payload` — and all eight travel
as JSON **text**.

That is not an invention: this repository's existing defect read path already
published all three of its own as `*Json` strings before this correction
(`defect_endpoints.dart` `_defectDetailMap` / `_eventMap`). I adopted the
convention that was already there rather than the one that would have been easier
to invent. `jsonDecode` recovers each value exactly. Those eight are the reason
`executionEndpoints.inspect`, `executionEndpoints.list`, `schedulerEndpoints.inspect`
and `workerEndpoints.inspect` could be typed at all — I had expected to have to
leave them out and say so.

Every projection is a **named copy**, never `toJson()`. A field added to a domain
type breaks the build at the projection instead of silently widening a wire
contract.

---

## Two behaviour changes you should see before deploying

1. **Timestamps.** `health()` and every other endpoint above now carry real
   `DateTime` fields instead of hand-formatted ISO-8601 strings. That is what
   "typed model" means here. The client's `*Response.fromJson` adapters were fed
   `view.toJson()`, and I measured Serverpod's `DateTime.toJson()` emits the
   identical `"2026-01-02T03:04:05.000Z"` form those adapters already parsed, so
   the client adapters are unchanged.

2. **`providerHealthEndpoints.updateModelPolicy` now returns the policy it wrote**,
   not `{'success': true}`. Its client method was declared
   `Future<ModelPolicyResponse>` and read a `role` the server never sent, so the
   pair only appeared to work because the one caller discards the result. Forcing
   it to a typed model surfaced that, and I fixed the server side rather than
   inventing an adapter that reads `success`.

---

## One migration note — for the Manager, not for me

`WorkerRegistrationView.capabilities` is `Map<String, CapabilitySpecView>`, where
`WorkerRegistration.capabilities` is keyed by the `WorkerCapability` **enum**. Both
key types serialise to the same wire object and `WorkerRegistrationCodec.fromJson`
reads the string form, so `workerEndpoints.listWorkers` is wire-compatible — but
it is a contract change on an endpoint the client does not currently call, and it
is not something this correction can verify for you. Deploying `77d984a` and this
separately would not migrate; they need to go together.

---

## H-2 and the smaller findings

**H-2 done.** `endpoint_surface_shape_test.dart` said
`Future<Map<String, dynamic>>` "stays a legal endpoint" with no mention that
legal to the generator is not legal on the wire. That was an unreconciled
`CONTRADICTION` and it endorsed the shape that cost two review cycles. It now
carries the generated branch, the missing `dynamic` entry, both counter-examples,
the empty-map asymmetry, and a pointer to the canary — plus a note *not* to widen
that function's remit, because it tests the generator and the canary tests the
wire, and folding them together would make that file's answer depend on a
property the generator does not have. The two-method canary loop is replaced by a
whole-client scan with a vacuous-pass guard.

**L-4 done** (that schema comment now cites `isModelFile` alone).

**L-2, L-3, M-1, M-3 not actioned** — prose in a report, or the Manager's
routing call. Recorded below.

---

## Gates

| gate | command | result |
|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | **pass** — exit 0, 765 files, 0 changed |
| analyze | `dart analyze apps/server` | **pass** — No issues found |
| analyze | `cd apps/control_plane && flutter analyze` | **pass** — No issues found |
| unit | 7 DB-free suites under `apps/server/test/` | **pass** — **+88**, 0 failed |
| integration | `make test-integration` | **pass with 1 known artefact** — **+191, −1**; the sole failure is `dogfood_shipit_postgres_test.dart`, failing identically at `77d984a` |
| flutter tests | `cd apps/control_plane && flutter test` | **pass** — **+271**, 0 failed |
| generate | `dart run serverpod_cli generate` | **pass** — idempotent; a second run leaves `protocol.dart` byte-identical (md5 `df76326d…` both times) |
| runtime | browser hop in the live QA stack | **not run** — out of my authority; the QA stack is yours and I did not touch it. The wire path is proven by `make test-integration` (server side) and by the canary (client-side declared types). Your post-integration browser verification is still the one thing I cannot do for you, and after this it should get past `addRepositoryReference`. |

`apps/server/test/onboarding_test.dart` needs a database
(`SocketException: Connection refused`) and is not run by `make test-integration`.
I verified in a `77d984a` worktree that it fails there identically — pre-existing,
not a regression. Reporting it rather than omitting it.

---

## Files changed

`git diff --name-only cf1b310..dcf1ede` = 171 files:

- **51 new model schemas** — `apps/server/lib/src/models/*.yaml`
- **51 new generated classes** — `apps/server/lib/src/generated/*_view.dart`
- `apps/server/lib/src/generated/protocol.dart` (regenerated)
- `apps/server/test/integration/test_tools/serverpod_test_tools.dart` (regenerated)
- **8 endpoint files rewritten** — `product_registry`, `defect`, `intake`,
  `health`, `provider_health`, `scheduler`, `execution`, `worker`
- `apps/control_plane/lib/data/control_plane_repository.dart` — 13 client call
  sites now typed reads
- `packages/control_plane_client/lib/src/protocol/{client,protocol}.dart` +
  51 new `*_view.dart` (regenerated)
- **8 test files** — the two wire tests, `endpoint_surface_shape_test.dart`, and
  four integration files that read `result['key']`

**Prohibited paths verified untouched:** `git status --porcelain` matched nothing
under `migrations/`, `apps/server/tool/`, `apps/server/lib/server.dart`,
`docker/`, `.github/`, `docs/`, `.decisions/`, `.agents/`, `.claude/`,
`.junie/`, `.opencode/`. `packages/**` is limited to the regenerated client the
dispatch body authorised — and yes, I am recording again that the dispatch header
prohibits `packages/**` while its body authorises this; **L-1 stands, the header
should stop saying that.**

**No test was weakened, skipped, `@Ignore`d, filtered or deleted.** No `@Skip`,
`skip:`, `tags:` or `@Ignore` was added; nothing was deleted. Two assertions were
*strengthened* (`isA<DateTime>()`; `deserialize<dynamic>` instead of
`decode<Map<String, dynamic>>`, which can no longer pass because a map branch
happened to handle the fixture) and two were *relocated* with the reason written
into the file (the empty-map asymmetry, which can no longer be asserted through a
branch that no longer exists — its absence is now asserted instead).

`git status --porcelain` is empty. **Not pushed, not merged, `main` untouched.**

---

## NEW_DISCOVERIES

**`PROJECT_FACT` — Serverpod 3.4.13 cannot represent arbitrary JSON in a model.**
`serverpod_cli generate` rejects `dynamic` in a model schema outright, and the
`Map<String, dynamic>` deserialization branch is emitted *per map-returning
endpoint* rather than always — so removing the last map-returning endpoint
removes the branch, and any test written against `decode<Map<String, dynamic>>`
changes meaning silently. `JsonValue` does not exist until Serverpod 4.x. This
repo's answer is the `*Json`-text convention. Persist-worthy; it is a durable
constraint, and it is now written into both the canary header and
`endpoint_surface_shape_test.dart`.

**`QA_DISCOVERY` — `dart analyze` cannot see a wrong key in a set literal.**
`expect(wireMap.keys.toSet(), {...})` passed analysis with `__className__` missing.
Two independent mechanisms failed open on the same correction this review: "a map
is legal Dart" and an unexecuted suite. **`ANNOTATION_OPPORTUNITY` → the Manager:**
this repository's CI does not run `apps/server/test/` at all (F-A), and
`make test-integration` takes ~45 minutes, so nothing runs the fast suites on
every change. A cheap "unit suite on PR" job is the fix, and it is a workflow
change I cannot make from here.

**`PROJECT_FACT` — `updateModelPolicy` had a client/server contract that never
worked.** The repository method is declared `Future<ModelPolicyResponse>` and the
server returned `{'success': true}`. It survived only because its one caller
discards the result. Latent, not reported in either review; found because typing
the return type made the mismatch impossible to ignore.

**`RUNTIME_DISCOVERY` — the worktree/`main` migration ordering.** `77d984a` is
not migratable from `main` without this correction (see the migration note). Not
a code defect; a sequencing fact the Manager needs before deploying.

### Out of scope — recorded, not fixed

G-7 (`referenceName` on the client — product decision, still carried and
documented in the schema) · M-4 (custody fallback logged lazily, accepted) · M-5
(attestation operator-asserted, narrowed not closed) · F-A / F-B (CI gaps: no job
runs `serverpod generate` or `apps/server/test/`) · L-2 (`AccessVerification.toJson()`
survives only for a hand-constructing test) · L-3 (the previous report's miscount)
· M-1 (the previous report's `24 → 23`; the measured figures were `24 → 22`) ·
M-3 (the previous round's four discoveries were never classified — **this section
is the handoff that closes that, and it still needs your routing**).

---

## What I got wrong last round, stated plainly

I diagnosed the browser failure as `credentialEndpoints.generate` and shipped a
per-endpoint fix that left the call immediately before it broken. The Manager's
dispatch was wrong about one thing — the schema location — and I said so, and that
was right. But "the other 22 are a product call" was me declining a scope decision
that was mine to escalate with specifics, and I escalated it without noticing that
one of the 22 was on the acceptance path. The canary is now a scan rather than a
list precisely so that failure cannot recur as a stale checklist.

---

```
RESULT: CORRECTION_COMPLETE

CORRECTED_FROM_HEAD: 77d984a780baa8b4efc51f45ce5f49afaa563ea0
NEW_HEAD: dcf1edeeadfbeef3b324cc885524c472f5b34db0

FINDINGS_ADDRESSED:
  - B-1: addRepositoryReference returns RepositoryReferenceAddedView; the whole
    Add Product path traced and all six calls confirmed deserialisable; all 22
    map-returning endpoints typed, so the defect class is gone rather than
    narrowed. Canary scan names exactly 22 offenders at 77d984a and 0 at HEAD.
  - B-2: '__className__' added to the expected key set at
    credential_key_service_postgres_test.dart:442; make test-integration
    EXECUTED at both revisions (190/2 at 77d984a, 191/1 at HEAD).
  - 22 OTHERS: every one typed; no endpoint left silently untyped; the one
    genuine constraint (Serverpod 3.4.13 has no arbitrary-JSON type) measured
    and handled by this repository's existing *Json-text convention.
  - H-2: endpoint_surface_shape_test.dart comment rewritten to say plainly that
    generator-legality is not wire-legality, with both counter-examples and the
    empty-map asymmetry; the two-method canary loop replaced by a whole-client
    scan with a vacuous-pass guard.
  - L-4: schema comment now cites isModelFile alone.

FILES_CHANGED: 171 (51 new model schemas, 51 new generated server classes, 51 new
  generated client classes, protocol.dart + client.dart + test tools regenerated,
  8 endpoint files, 1 client repository, 8 test files). migrations/**,
  apps/server/tool/**, lib/server.dart, docker/**, .github/**, docs/**,
  .decisions/** and packages/** (beyond the regenerated client) all untouched.

GATES:
format=pass (exit 0, 765 files, 0 changed)
analyze=pass (dart analyze apps/server: No issues found; flutter analyze: No issues found)
tests=pass (+88 unit, 0 failed; flutter test +271, 0 failed)
build=pass (serverpod generate exits 0 and is idempotent — a second run leaves protocol.dart byte-identical)
runtime=pass-with-known-artefact (make test-integration EXECUTED: +191, -1; the
  sole failure is dogfood_shipit_postgres_test.dart, the linked-worktree artefact
  "dogfood expects a git working tree at /private/tmp/shipit-fix-endpoint-types",
  which fails identically at 77d984a and is not a regression. Browser hop NOT run
  — QA stack is the Manager's and was not touched; zero mutating Docker commands
  issued; make test-integration was the only database path and self-cleaned.)

NEW_DISCOVERIES:
  - PROJECT_FACT: Serverpod 3.4.13 has no arbitrary-JSON model type (measured:
    `dynamic` rejected in a model schema) and emits the Map<String, dynamic>
    deserialize branch per map-returning endpoint, so removing the last one
    removes the branch and silently changes what decode<Map<String, dynamic>>
    does. Serverpod 4.x adds JsonValue. Written into the canary header and the
    surface-shape comment; Manager may persist.
  - PROJECT_FACT: ControlPlaneRepository.updateModelPolicy is declared
    Future<ModelPolicyResponse> while the server returned {'success': true}; it
    worked only because its one caller discards the result. Now returns the
    policy it wrote.
  - RUNTIME_DISCOVERY: 77d984a is not migratable from main without this
    correction — they must deploy together.
  - QA_DISCOVERY / ANNOTATION_OPPORTUNITY: dart analyze cannot see a missing key
    in a set literal, and CI runs neither apps/server/test/ nor serverpod
    generate, so two independent mechanisms failed open on the same correction.
    A cheap unit-suite-on-PR job is the fix (F-A); workflow change, Manager's
    call.

READY_FOR_FOCUSED_REVIEW: YES

FOCUSED_RE_REVIEW: true

SAFE_PARALLEL_WORK:
  - docker/** and the QA stack: yours, and the B-1-mandated redeploy now has a
    client that can read addRepositoryReference's response.
  - apps/server/migrations/**, apps/server/tool/**, .github/** (F-A/F-B),
    docs/** outside this task directory, .decisions/**.
  - Any path outside apps/server/lib/src/{models,generated,endpoints}/**,
    apps/server/test/**, apps/control_plane/lib/data/**,
    packages/control_plane_client/**.

PROHIBITED_PARALLEL_WORK until this correction is reviewed and integrated:
  - apps/server/lib/src/endpoints/{product_registry,defect,intake,health,
    provider_health,scheduler,execution,worker}_endpoints.dart
  - apps/server/lib/src/models/*.yaml
  - apps/server/lib/src/generated/**
  - packages/control_plane_client/**
  - apps/server/test/credential_wire_return_type_test.dart
  - apps/server/test/credential_endpoint_wire_test.dart
  - apps/server/test/endpoint_surface_shape_test.dart
  - apps/server/test/integration/{credential_key_service,defect_backend,
    feature_request_intake,lane_f_production_reachability,triage_execution}_*.dart
  - apps/control_plane/lib/data/control_plane_repository.dart
  Reason: a concurrent `serverpod generate` renumbers every `_iN.` import alias,
  and the canary reads the generated client from source.
```

---

## For the focused reviewer — where to look first

1. **`repository_reference_added_view.yaml` + the projection in
   `product_registry_endpoints.dart`.** That is B-1. Small and decisive.
2. **The canary's whole-client scan**
   (`credential_wire_return_type_test.dart`, `_endpointMethods` /
   `_mapReturningEndpointMethods` / `_isUndeserialisable`). Check it for
   vacuous-pass holes the way the previous round's two-method loop was checked:
   the scan's own guard test asserts >50 methods across >5 classes, and the
   `_isUndeserialisable` predicate is the predicate the named per-path tests now
   share, so a method cannot pass one and fail the other.
3. **The two relocated assertions.** `credential_endpoint_wire_test.dart` now
   asserts `deserialize<dynamic>` and adds an assertion that the generated map
   branch is *gone*. That is the one place a reviewer could reasonably think a
   test was weakened; the reasoning is in the comment and in the commit body.
4. **The migration note.** `WorkerRegistrationView.capabilities` is the one
   contract change on an endpoint the client does not call. It is wire-compatible
   by my reading of `WorkerRegistrationCodec`, but it is unverified by any test,
   and I would rather flag it than have it found later.
5. **`.bytes`** — re-diff the two site lists yourself. Mine is an empty diff of
   18 against 18.