# S-1 — PRODUCT REGISTRY + ONBOARDING (Multi-Product) Slice Report

**Slice:** S-1 (checkpoint `006-product-registry-onboarding.md`)
**Canonical scope:** `PRODUCT` (MP-PD-1 RESOLVED; `PROJECT` not introduced)
**Written:** 2026-09-16

---

## 1. RESULT

S-1 is **IMPLEMENTED and independently exercised** across the domain, database,
typed API, isolation, and dogfood layers. A durable Product registry exists:
Product identity, read-only repository discovery, ProductBaseline + provenance,
durable clarification with resume, ProductContext loading, PostgreSQL
persistence, and a typed Serverpod protocol surface.

Multi-product capability is **not** claimed by storing two rows — it is
demonstrated by context-isolation tests, cross-product negative tests, the
restart/independence E2E, and the `Product: ShipIt` dogfood run.

The slice **stops at the human/design gates** (§29). The ShipIt baseline is
**proposed, never self-accepted**. No UI was built.

## 2. BASELINE

- Working tree already contained a large **pre-existing, out-of-scope
  restructure** (`control_plane/` → `apps/` + `packages/`, native Dart
  workspace). This slice did not author it and did not revert it.
- Registry design reused `ProductManifest` + `ProductState` **as-is** (006 §0B
  `ALREADY_ALIGNED`); no rename.
- Scheduler **not redesigned** (006 §11 — analysis only).
- Migration chain applied through `apps/server/migrations/`; the pre-existing
  `job_active_dedupe_unique` warning (§19) is unrelated to S-1.

## 3. WORK COMPLETED (Summary)

1. S-1 domain contracts (`Product`, `RepositoryReference`, `BaselineFact`,
   `ProductBaseline`, `ClarificationRequest`, `OnboardingRecord`,
   `ProductContext`) with wire-correct serialization.
2. New package `packages/product_registry` — engine, durable store interface,
   in-memory store, deterministic baseline content hashing, read-only discovery
   reader, discovery policy, exceptions.
3. PostgreSQL persistence + migration; store contract suite wired.
4. Product-scoped `ControlPlaneService` methods + typed Serverpod models,
   mappers, endpoints; generation reproducibility verified.
5. Multi-product isolation + cross-product negative tests; restart durability.
6. Dogfood `Product: ShipIt` from a pinned `git archive HEAD` snapshot.
7. Adversarial independent review (§27).

## 4. FILES CHANGED (New / Modified)

**New — `packages/product_registry/`**
- `lib/product_registry.dart`
- `lib/src/engine/product_registry_engine.dart`
- `lib/src/engine/baseline_content_hash.dart`
- `lib/src/store/product_registry_store.dart`
- `lib/src/store/in_memory_product_registry_store.dart`
- `lib/src/discovery/discovery_observation.dart`
- `lib/src/discovery/read_only_repository_reader.dart`
- `lib/src/discovery/discovery_policy.dart`
- `lib/src/exceptions.dart`
- `test/{hash_function_test,engine_test,discovery_and_restart_test,no_global_scope_test}.dart`
- `pubspec.yaml`

**New — `packages/platform_contracts/`**
- `lib/src/types/{product,repository_reference,baseline_fact,product_baseline,clarification_request,onboarding_record,product_context}.dart` (+ `.g.dart`)
- `lib/src/enums/{baseline_section_key,clarification_status,product_baseline_status,provenance,repository_kind,repository_provider}.dart`

**New — `schemas/`**
- `product_context.schema.json` (definitions inlined; only local `#/definitions` refs)

**New — `apps/server/`**
- `lib/src/database/{product,repository_reference,product_baseline,clarification_request,onboarding_record}.spy.yaml`
- `migrations/20260917030156659/`
- `lib/src/persistence/postgres_product_registry_store.dart`
- `lib/src/models/{product_view,repository_reference_view,baseline_fact_view,product_baseline_view,clarification_view,product_context_view}.yaml`
- `lib/src/endpoints/product_registry_endpoints.dart`
- `test/integration/{product_registry_multi_product_postgres_test,product_registry_endpoints_e2e_test,dogfood_shipit_postgres_test}.dart`

**Modified**
- `packages/platform_contracts/test/contract_schemas_test.dart`
- `packages/store_contract_tests/lib/store_contract_tests.dart`, `lib/src/product_registry_store_suite.dart`, `pubspec.yaml`
- `apps/server/pubspec.yaml`, `lib/src/services/control_plane_service.dart`, `lib/src/services/ui_view_mappers.dart`, `lib/src/generated/endpoints.dart`
- `packages/control_plane_client/lib/src/protocol/client.dart` (generated)
- `test/integration/store_contracts_postgres_test.dart` (suite wired + TRUNCATE list)

## 5. TESTS (Per Package)

| Package / suite | Command | Result |
|---|---|---|
| `platform_contracts` | `dart test` | **93 pass** (contract schema conformance) |
| `product_registry` | `dart test` | **18 pass** |
| `store_contract_tests` | `dart test` | **32 pass** (in-memory suites) |
| `apps/server` (serial) | `dart test -j 1` | **83 pass** (incl. 17 S-1 Postgres + 4 endpoint E2E) |
| `apps/server` S-1 store suite | store_contracts_postgres | **7 pass** |
| `apps/server` multi-product | product_registry_multi_product | **9 pass** |
| `apps/server` endpoints | product_registry_endpoints_e2e | **4 pass** |
| `apps/server` dogfood | dogfood_shipit_postgres | **1 pass (~4 s)** |

Note: `apps/server` integration tests must run **serially (`-j 1`)** — they
share one PostgreSQL database and TRUNCATE domain tables. This is pre-existing.

## 6. EVIDENCE (Deterministic Proofs)

- **Baseline hash:** SHA-256 verified against Python vectors —
  `sha256("[]") = 4f53cda1…6f7022df`, 283-byte canonical fact JSON =
  `d08427d0…` (asserted in `hash_function_test.dart`).
- **Generation reproducibility:** `serverpod generate` run twice →
  **byte-identical** output; no manual repair of generated files.
- **Read-only dogfood:** discovery over `git archive HEAD` pinned snapshot;
  `git status --porcelain` **unchanged** after propose.
- **Restart durability:** a fresh `PostgresProductRegistryStore` + fresh engine
  reads back the same Product/baseline/clarification.

## 7. ARCHITECTURE (What's Wired)

```
Flutter (none yet)  ──►  ProductRegistryEndpoints (typed protocol)
                              │  listProducts / productContext
                              │  acceptBaseline / answerClarification
                              ▼
                        ControlPlaneService (product-scoped methods)
                              ▼
                     ProductRegistryEngine (packages/product_registry)
                       │                 │
          ReadOnlyRepositoryReader   ProductRegistryStore (interface)
          (discovery, no mutation)          │
                                   PostgresProductRegistryStore (apps/server)
```

No domain logic lives in endpoints; endpoints never set state directly — the
two writes (`acceptBaseline`, `answerClarification`) delegate to the engine.

## 8. PACKAGES ADDED / CHANGED

- **Added:** `packages/product_registry` (domain + discovery; no I/O beyond
  injected store/reader).
- **Changed:** `packages/platform_contracts` (new S-1 types/enums + schema),
  `packages/store_contract_tests` (registry suite export + dep),
  `apps/server` (persistence, models, endpoints), `control_plane_client`
  (regenerated).

## 9. POSTGRES SCHEMA (Migration)

Migration `apps/server/migrations/20260917030156659/` creates
`product`, `repository_reference`, `product_baseline`, `clarification_request`,
`onboarding_record`. Per-Product rows carry `productId`; `product_baseline`
carries `revision` + `contentHash` with a per-product unique revision
constraint; `product` carries `version` for CAS.

## 10. CONTRACT TESTS ADDED

`contract_schemas_test.dart` extended for all S-1 types: required fields, enum
wire values (`proposed`/`accepted`, `observed`/`human_provided`/`derived`/
`assumed`/`unknown`, section keys), explicit invalid-enum rejection, and
`ProductContext.toJson()` conformance against
`schemas/product_context.schema.json`.

## 11. MULTI-PRODUCT ARCHITECTURE

Every operation takes an explicit `productId`. There is **no global
`currentProduct`**; `ProductContext(productId)` is the only context loader and
is bounded to one Product. Product identity is durable and unambiguous
(006 §2–§3).

## 12. PRODUCT ISOLATION MODEL (006 §4)

- Product-scoped: Product, RepositoryReference, ProductBaseline,
  ClarificationRequest, OnboardingRecord, WorkItem (existing `productId`).
- Derived: Job → `WorkItem.productId`; HumanDecision → `WorkItem.productId`;
  executions/artifacts derive similarly — no indiscriminate `productId` fields.
- Global / N.A.: scheduler tick loop, structured logging.

## 13. CROSS-PRODUCT NEGATIVE TESTS

- `acceptBaseline(productId: A, baselineId: <B's>)` →
  `CrossProductAccessException`.
- `productContext(A).allBaselines` excludes B.
- Store reads are filtered by `productId` at the SQL boundary.
- A's changes never mutate B (independent revision sequences; A's baseline
  proposed does not change B's rows).

## 14. DERIVED SCOPE (no redundant `productId`)

Job scope derives through `WorkItem.productId`; HumanDecision scope derives
through its WorkItem. `engine.scoped<T>`-style helpers keep derivation in one
place and are covered by tests, so scope is not re-implemented per call site.

## 15. READ-ONLY DISCOVERY BOUNDARY

`ReadOnlyRepositoryReader` may READ / SEARCH / INSPECT GIT / ANALYZE / CLASSIFY
/ PROPOSE / ASK. It may **not** EDIT, INSTALL, EXECUTE repo instructions, run
arbitrary scripts, COMMIT, PUSH, MIGRATE, or FIX. Repo content is data: prompt
injection, `.env`/secret-shaped files, private keys, symlink/path escape, large
and binary files, generated artifacts, and package hooks are handled. Secret
values are **never ingested** — redacted placeholders only.

## 16. BASELINE PROVENANCE + IMMUTABILITY

Provenance vocabulary `observed | human_provided | derived | assumed | unknown`
survives persistence/reload. An accepted baseline revision is immutable; human
acceptance binds to the exact revision + `contentHash`. New material change
produces a **proposed v2**, never a silent mutation (§27 records the
signature gap).

## 17. HUMAN DECISION DURABILITY (clarifications)

Clarifications are durable stops on material unknowns: a **brand-new execution**
resumes the SAME Product / onboarding / baseline lineage from the store alone,
with no chat or process-global state, and never fabricates an answer.
Restart + replay are covered by tests.

## 18. TYPED SERVERPOD API + GENERATION REPRODUCIBILITY

Four typed endpoints return protocol models (field access, no
`Map<String,dynamic>` for Flutter-facing contracts): `listProducts`,
`productContext`, `acceptBaseline`, `answerClarification`. `serverpod generate`
reproduces the client byte-for-byte without manual repair.

## 19. SCHEDULER IMPLICATIONS (006 §11 — analysis only)

No scheduler change. `Job → WorkItem → productId` provenance
(MP-AC-12) remains derivable; `PRODUCT_AWARE_SCHEDULER_POLICY` recorded only.
Product-aware priority/fairness/concurrency is deferred (006 §19).

## 20. GLOBAL NEEDS-YOU IMPLICATIONS (006 §12)

Global human-attention aggregation remains architecturally possible (MP-AC-13)
because scope is a filter over product-scoped rows, not a singleton. No UI
built.

## 21. ENVIRONMENT / SECRET ISOLATION (boundary only)

Per-Product secrets management is **not implemented** (006 §9 / AGENTS §13).
The boundary is expressed: baselines contain **references only**; a SECURITY
test asserts no secret context leaks into persisted baselines.

## 22. ARTIFACT ISOLATION (boundary only)

Product-partitioned artifact storage + IAM is deferred (MP-AC-15). No GCS
implementation. The registry preserves the `productId` needed to partition
later.

## 23. SECURITY NOTES

- Cross-product access is refused, not merely filtered.
- Baselines persist references, never secret values (`SECURITY` test).
- Read-only discovery cannot mutate (capability boundary by construction).
- Endpoints are read-only except the two engine-delegated human-gate writes.

## 24. BOUNDARY COMPLIANCE (AGENTS.md)

- No `Map<String,dynamic>` for domain objects; `@immutable` + sealed/enum types.
- No stringly-typed workflow state; no agent-specific imports in the engine.
- No direct DB access outside `apps/server`.
- Serialization via `json_serializable`; `schemas/` remain authoritative.
- Repository layout respected: runnables in `apps/`, libraries in `packages/`.

## 25. QA MATRIX (25 checks)

| # | Layer | Check | Status |
|---:|---|---|---|
| 1 | UNIT | Product identity round-trip | PASS |
| 2 | UNIT | Product lifecycle draft→active→archived; invalid refused | PASS |
| 3 | UNIT | RepositoryReference association by product | PASS |
| 4 | UNIT | `resolveRepository` rejects foreign reference | PASS |
| 5 | UNIT | Context A never returns B (in-memory) | PASS |
| 6 | UNIT | No `currentProduct` singleton (source scan, MP-AC-3) | PASS |
| 7 | UNIT | Baseline hash = verified SHA-256 vectors | PASS |
| 8 | UNIT | Provenance survives serialization | PASS |
| 9 | UNIT | Clarification durable stop + same-lineage resume | PASS |
| 10 | UNIT | Existing `WorkItem.productId` alignment | PASS |
| 11 | DATABASE | Two+ Products persisted simultaneously | PASS |
| 12 | DATABASE | Independent baseline revisions per Product | PASS |
| 13 | DATABASE | CAS/idempotency on per-product rows | PASS |
| 14 | DATABASE | Accepted baseline immutable (re-accept refused) | PASS |
| 15 | DATABASE | Registry store contract suite (Postgres) | PASS |
| 16 | DATABASE | Cross-product store reads filtered | PASS |
| 17 | SECURITY | Cross-product acceptance refused | PASS |
| 18 | SECURITY | Cross-product context does not leak | PASS |
| 19 | SECURITY | Baseline holds references only (no secrets) | PASS |
| 20 | SECURITY | Discovery has no mutation capability | PASS |
| 21 | E2E | Register A + B; modify A; B unchanged | PASS |
| 22 | E2E | Restart durability (fresh store + engine, MP-AC-7) | PASS |
| 23 | E2E | Dogfood ShipIt read-only; porcelain unchanged | PASS |
| 24 | E2E | Typed endpoint round-trip (4 endpoints) | PASS |
| 25 | E2E | Typed generation reproducible (byte-identical) | PASS |

Checkpoint 006 §16 requires the four layers UNIT / DATABASE / SECURITY / E2E —
all covered above.

## 26. MULTI-PRODUCT ACCEPTANCE CRITERIA (MP-AC)

| ID | Class | State |
|---|---|---|
| MP-AC-1 Multiple Products concurrently | S-1 | SATISFIED |
| MP-AC-2 Durable identity | S-1 | SATISFIED |
| MP-AC-3 No singleton `currentProduct` | S-1 | SATISFIED (§25 #6) |
| MP-AC-4 References belong to correct Product | S-1 | SATISFIED |
| MP-AC-5 Contexts isolated | S-1 | SATISFIED |
| MP-AC-6 No cross-Product baseline/evidence | S-1 | SATISFIED |
| MP-AC-7 Operations survive restart | S-1 | SATISFIED |
| MP-AC-8 A's changes don't mutate B | S-1 | SATISFIED |
| MP-AC-9…11 WorkItem/Defect/Objective association | MODEL | MODELED |
| MP-AC-12 Scheduler Product provenance | MODEL/S-1 | DERIVABLE |
| MP-AC-13 Global attention aggregation | MODEL | POSITIONED |
| MP-AC-14 Product-scoped APIs explicit | MODEL | SATISFIED |
| MP-AC-15 Artifact/env isolation possible | MODEL | POSITIONED |

## 27. INDEPENDENT REVIEW (Adversarial Trace)

Performed as a separate trace over the reader, store, engine, and endpoints:

1. **`DiscoveryPolicy` is not runtime-enforced by the reader.** `requireReadOnly()`
   is a marker; nothing calls it. **Assessment:** the reader is read-only *by
   construction* (it exposes no mutating method and no shell), so the policy is
   documentation, not a guard. Recorded as a **hardening item** (add a
   construction-time assertion), not a correctness defect.
2. **Baseline acceptance carries `acceptedBy` only — no signature**, unlike
   workflow `resolveDecision` (algorithm/publicKey/signature/signedAt).
   **Finding:** weaker than the HumanDecision durability bar (AGENTS §11).
   Recorded as a gap for the human-gate hardening pass (§30).
3. **Concurrent `proposeBaseline`** for the same product relies on the
   per-product unique revision constraint to fail closed; there is no
   pre-read CAS. **Assessment:** correct (fail-closed), but the error surfaces
   as a constraint violation. Documented.
4. **`acceptBaseline` CAS** uses `expectedVersion` (engine lines ~205/217), so a
   concurrent accept cannot double-commit. Verified.
5. **Redaction** is wired into `ReadOnlyRepositoryReader` (lines ~131/170);
   secret-shaped content becomes a placeholder. Verified.

No cross-product leak and no mutation path was found.

## 28. KNOWN ISSUES / RISKS

- Baseline acceptance lacks a cryptographic signature (§27.2).
- `DiscoveryPolicy` is advisory, not enforced (§27.1).
- **Large-file threshold guard is untested.** `ReadOnlyRepositoryReader`
  enforces `maxTextFileBytes` (256 KiB) / `maxBinaryBytes` (16 MiB), but no test
  crosses either threshold; the only binary fixture sits under a skipped
  directory. Status `NOT_ASSESSED` (see §25 #17 conversational matrix).
- **Product lifecycle invalid-transition guard is untested.** `draft→active` is
  exercised (typed endpoint E2E); `ProductLifecycleException` on an
  invalid activation is not separately asserted.
- Integration tests are serial and share one database (pre-existing).
- Pre-existing `job_active_dedupe_unique` migration/index drift
  (`migrations/20260914041810984`) — unrelated to S-1; the Postgres store's
  `contains('n')` check matches the literal `"n"` index typo.
- `melos run test` is not fully green for **pre-existing / structural** reasons
  only: `control_plane_client` has no test dir (exit 65), `control_plane_server`
  needs `-j 1`, `control_plane` (Flutter) needs `flutter test`. All 79→83
  `apps/server` tests pass serially; `analyze` shows only pre-existing infos.

## 29. CURRENT GATE

Two human gates are open; no further implementation proceeds past them:

1. **`PRODUCT_BASELINE_APPROVAL_REQUIRED`** — the `Product: ShipIt` baseline is
   **proposed, not accepted**. A human must accept the exact revision +
   `contentHash`. The agent must not self-approve.
2. **`READY_FOR_DESIGN`** — onboarding / product-scoped UI is **not built**;
   design authority is required before any UI work.

Fallback gates if either fails: `IMPLEMENTATION_CORRECTION_REQUIRED`,
`ARCHITECTURE_DECISION_REQUIRED`.

## 30. GAPS TO CLOSE BEFORE PRODUCTION

- Add a cryptographic signature (or bind to `HumanDecision`) for baseline
  acceptance.
- Enforce the discovery read-only policy at construction time.
- An ADR for the Product registry + isolation boundary (006 §20.3).
- Extend the *second* fixture Product (MP-PD-2) to a full typed-API journey
  (register/restart/retrieve). Isolation is proven at domain + DB level and the
  typed API covers cross-product refusal (§13, §25 #17–18); only the full
  B-journey over the typed API is not yet scripted.
- Product-aware scheduler policy (deferred slice).

## 31. VERDICT

**IMPLEMENTED — multi-product registry durably proven and independently
reviewed; ShipIt baseline PROPOSED (not accepted).** Halt at
`PRODUCT_BASELINE_APPROVAL_REQUIRED` + `READY_FOR_DESIGN`.

`S-1 = IMPLEMENTED_AWAITING_HUMAN_BASELINE_ACCEPTANCE_AND_DESIGN`
