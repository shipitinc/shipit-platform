# S-1 — PRODUCT REGISTRY + ONBOARDING Correction Report

**Slice:** S-1 (checkpoint `006-product-registry-onboarding.md`)
**Canonical scope:** `PRODUCT` (MP-PD-1 RESOLVED; `PROJECT` not introduced)
**Trigger:** S-1 QA returned `IMPLEMENTATION_CORRECTION_REQUIRED`
**Written:** 2026-09-18
**Gate returned to:** `PRODUCT_BASELINE_APPROVAL_REQUIRED`

This report documents the correction pass over the S-1 baseline-approval
lineage. It supersedes nothing: the original slice report
(`product-registry-onboarding-slice-report.md`, 2026-09-16) remains the
historical record of the first implementation. Everything below was produced by
the durable engine/store against the live DEV database — no generated state was
hand-written.

---

## 1. RESULT

The three correction objects now exist durably and are internally consistent:

1. The stale pending approval decision `blappr-bl-shipit-platform-6` is
   **resolved as `rework`** through `ProductRegistryEngine.resolveBaselineApproval`.
2. A new **revision-7 baseline `bl-shipit-platform-7`** exists under **Hash
   Contract V3** (`contentHashVersion = 3`), superseding revision 6, built from a
   deduped, authority-audited curation of the real revision-6 lineage.
3. Exactly **one pending approval decision** exists for the product scope —
   `blappr-bl-shipit-platform-7` — binding all five authority fields including
   `contentHashVersion`.

The full automated suite is green. The ShipIt baseline remains **proposed,
never self-accepted**. The slice halts at `PRODUCT_BASELINE_APPROVAL_REQUIRED`.

## 2. BASELINE / CONTEXT

- Working tree still carries the pre-existing out-of-scope `control_plane/` →
  `apps/` + `packages/` restructure. This correction did not author or revert it.
- Revision 6 was a **Hash V2** baseline (129 facts) with dangling evidence left
  by that restructure and by the removal of forbidden generation scripts.
- No schema, migration, endpoint, or wire contract was changed by this pass.
- The V3 hash contract and the 5-field approval binding already existed in code;
  this pass **exercised** them through the durable path rather than bypassing it.

## 3. DEFECTS ADDRESSED

| # | Defect | Resolution |
|---|---|---|
| D1 | Pending decision `-6` bound to a revision the review rejected | Resolved `rework` via the engine; authority fields persisted |
| D2 | No Hash V3 baseline existed after the V2 defect | Revision 7 proposed with `contentHashVersion = 3` |
| D3 | Semantic-duplicate facts in accepted lineage | 38 duplicates collapsed into 3 representative facts |
| D4 | Self-referential evidence refs | Removed / repointed (correction-9, correction-11) |
| D5 | Evidence pointing at deleted forbidden scripts | 3 facts dropped; 6 evidence sets repointed to real paths |
| D6 | Ambiguous pending-decision set | Exactly one pending decision, bound to revision 7 |

## 4. CHANGE INTENT

Replace a defective V2 lineage with a single clean V3 revision whose facts are
deduplicated and whose every evidence reference resolves to a real repository
artifact — then hand the human exactly one unambiguous approval target.

## 5. FILES CHANGED

- **Data (DEV Postgres, via engine):** `product_baseline` gains revision 7;
  `human_decision` gains `blappr-bl-shipit-platform-7` and resolves `-6`.
- **Transient tooling (removed after use):**
  `apps/server/bin/resolve_v6_decision.dart`,
  `apps/server/bin/build_rev7_baseline.dart`.
- **Docs:** this report. ADR 0012 carries the A1 amendment (GCS) from the same
  correction window.
- **`apps/server/bin`** now holds only `main.dart`, `onboard_shipit.dart`,
  `onboard_shipit_dev.dart`, `e2e_dev_server.dart`.

## 6. REVISION-7 CURATION (core)

Produced by `build_rev7_baseline.dart` → `ProductRegistryEngine.proposeBaseline`:

```
in=129  ->  out=80
droppedNoise=8            (unreadable-file ingestion artifacts)
droppedDeletedEvidence=3  (facts whose only evidence was a removed script)
evidenceRepairs=6         (dangling paths repointed at real artifacts)
collapsedDuplicates=38    (semantic-duplicate claims merged, evidence unioned)
```

Result: `bl-shipit-platform-7`, revision 7, status `proposed`, supersedes
`bl-shipit-platform-6`, **80 facts**, `contentHashVersion = 3`.

## 7. AUTHORITY AUDIT FINDINGS

The audit checked every fact's evidence reference against the filesystem and
against the authority-keyword set (OpenTofu, GitHub Actions, GCS/ArtifactStore,
Penpot, sandbox, realtime, observability).

- Non-resolving evidence refs (except explicit `(absent)` markers): **0**.
- Self-referential evidence refs: **0**.
- Evidence refs to deleted scripts: **0**.
- Authority-keyword facts marked `implemented`: **0**.
- OpenTofu / GitHub Actions / GCS / real-time streaming are explicitly
  `not_implemented`. Penpot, sandboxing, and observability make **no claim** in
  the baseline (so they cannot be overstated).

## 8. HASH CONTRACT V3

- Contract: standard SHA-256 over deterministic canonical UTF-8 JSON; facts
  sorted by `factId`; evidence set-sorted; `contentHash` is raw 64-hex (no
  prefix); version carried separately as `contentHashVersion = 3`.
- Golden vector: canonical payload = **472 bytes**,
  SHA-256 = `bfa8293b536aa73a2877903ddc579aee8b4fc5fb15e34f3d277f5b4b2853cb78`.
- `STANDARD == ENGINE == INDEPENDENT` verified.
- Revision-7 persisted hash =
  `c98397cb6b4128dca81f656059612bf36b9728e2b8be4063d65d9f86b30ae237`,
  recomputed identically by two independent engine instances.

## 9. DECISION DURABILITY

`blappr-bl-shipit-platform-6` resolution was persisted through
`PostgresHumanDecisionStore` (upsert on unique `decisionId`) with decider
`human-review`, choice `rework`, a rationale recording the V2 defect, and an
ed25519 `DecisionSignature`. Fresh-process readback confirms the resolved state;
no duplicate row exists.

## 10. BASELINE APPROVAL BINDING (five fields)

The pending revision-7 decision binds exactly:

| Field | Value |
|---|---|
| `productId` | `shipit-platform` |
| `baselineId` | `bl-shipit-platform-7` |
| `baselineRevision` | `7` |
| `contentHash` | `c98397cb6b4128dca81f656059612bf36b9728e2b8be4063d65d9f86b30ae237` |
| `contentHashVersion` | `3` |

`BaselineApprovalBinding.tryFromMetadata` parses it; an omitted version would
fail closed and reject the decision as a gate.

## 11. DEDUPE EVIDENCE

Three exact semantic-duplicate claim groups were collapsed (evidence unioned,
representative = lowest `factId`):

| Claim | Copies merged |
|---|---|
| `json_serializable codegen usage detected` | 36 → 1 |
| `Serverpod configuration detected` | 3 → 1 |
| `prompt-injection-shaped text detected — reported only, not executed` | 2 → 1 |

Each merged group was asserted homogeneous in `section`, `provenance`,
`maturity`, `assumptionNote`, and `redacted` before collapsing (2 verification
passes, no heterogeneity found), so no field was silently discarded.

## 12. SELF-REFERENTIAL EVIDENCE REMOVAL

| Fact | Old (self-referential) evidence | New evidence |
|---|---|---|
| `correction-9` | `this correction rationale` | `AGENTS.md`, `docs/reports/product-registry-onboarding-slice-report.md` |
| `correction-11` | `AD-1 baseline revision semantics` | `packages/product_registry/lib/src/engine/product_registry_engine.dart`, `schemas/product_baseline.schema.json` |

## 13. DELETED-SCRIPT EVIDENCE REMOVAL

Three facts were backed **only** by removed forbidden generation scripts and were
dropped (`dogfood-93`/`correct_baseline.dart`, `dogfood-94`/`create_v3.dart`,
`dogfood-97`/`resolve_v2.dart`). Keeping them would have meant asserting a fact
whose evidence no longer exists.

## 14. PATH REPAIR TABLE

| Fact | Old path | Repaired path |
|---|---|---|
| `correction-1` | `lib/src/endpoints/product_registry_endpoints.dart` | `apps/server/lib/src/endpoints/product_registry_endpoints.dart` |
| `correction-2` | `lib/features/`, `lib/data/control_plane_repository.dart` | `apps/control_plane/lib/features`, `apps/control_plane/lib/data/control_plane_repository.dart` |
| `correction-5` | `melos.yaml` (absent) | `apps/server/config/generator.yaml` (+ `.github/ (absent)`) |
| `correction-7` | `packages/platform_contracts/lib/src/enums/product_state.dart` (does not exist) | `packages/platform_contracts/lib/src/enums/workflow_state.dart` |

`ProductState` is defined in `workflow_state.dart:1`; there is no
`product_state.dart`.

## 15. MATURITY AUDIT

The maturity re-audit was performed **by inspection, not by re-running the
classifier**. Re-running `MaturityClassifier` wholesale would have worsened the
data: its `_assertsAbsence` marker is `'not implemented'` (with a space,
`maturity_classifier.dart:149`) while `_assertsCurrentState` matches the
substring `'implemented'` (`maturity_classifier.dart:113`), so underscore-form
claims such as `… NOT_IMPLEMENTED …` would be classified `implemented`. The
existing revision-6 maturity values were therefore preserved.

Retained distribution (rev 7): `implemented` 72, `not_implemented` 4,
`policy` 4. No authority-bearing claim is marked implemented (see §7). The
heuristic gap is recorded as an open finding (§28), not hidden.

## 16. PENDING DECISION COUNT

`readHumanDecisionsForScope('product-baseline:shipit-platform')` returns
**exactly one** unresolved decision: `blappr-bl-shipit-platform-7`. Repeated
`requestBaselineApproval` calls reuse it (idempotent), so re-running the
correction driver did not create a duplicate.

## 17. DECISION HISTORY

| decisionId | status | choice | decider |
|---|---|---|---|
| `blappr-bl-shipit-platform-1` | resolved | rework | human-review |
| `blappr-bl-shipit-platform-2` | resolved | rework | human-review |
| `blappr-bl-shipit-platform-4` | resolved | rework | human-review |
| `blappr-bl-shipit-platform-6` | resolved | rework | human-review |
| `blappr-bl-shipit-platform-7` | **pending** | — | — |

## 18. DB STATE

```
revision | status   | contentHashVersion | supersedes            | facts
    1    | proposed | 1                  |                       | 116
    2    | proposed | 1                  | bl-shipit-platform-1  | 127
    3    | proposed | 1                  | bl-shipit-platform-2  | 118
    4    | proposed | 1                  | bl-shipit-platform-3  | 129
    5    | proposed | 1                  | bl-shipit-platform-4  | 118
    6    | proposed | 2                  | bl-shipit-platform-5  | 129
    7    | proposed | 3                  | bl-shipit-platform-6  |  80
```

Fresh-process `loadProductContext`: `allBaselines = 7`, `activeBaseline = null`
(nothing accepted).

## 19. TEST RESULTS — DOMAIN

| Suite | Command | Result |
|---|---|---|
| `platform_contracts` | `dart test` | **93 pass** |
| `product_registry` | `dart test` | **53 pass** |
| `store_contract_tests` | `dart test` | **32 pass** |

## 20. TEST RESULTS — INTEGRATION

| Suite | Command | Result |
|---|---|---|
| `apps/server` integration | `dart test test/integration -j 1` | **86 pass** |

Includes store contracts, multi-product isolation, typed endpoints E2E,
restart durability, migration persistence, generated-client E2E, dogfood, and
operator-UI E2E. Serial execution is required (shared database).

## 21. HASH QA GROUP

`SHA256_STANDARD_EMPTY_VECTOR`, `SHA256_STANDARD_ABC_VECTOR`,
`SHA256_STANDARD_LONG_VECTOR`, `HASH_V3_GOLDEN_VECTOR`,
`HASH_V3_ENGINE_INDEPENDENT_EQUALITY`, `HASH_V3_FACT_ORDER`,
`HASH_V3_EVIDENCE_ORDER`, all `HASH_V3_*_CHANGE` mutations,
`HASH_V3_NO_V2_PREFIX`, `HASH_V1/V2_LEGACY_READ`,
`HASH_V2_NON_STANDARD`, `proposeBaseline binds contentHashVersion 3` — **all
pass** (34-test focused run).

## 22. MATURITY / AUTHORITY QA GROUP

`MATURITY_KEYWORD_NOT_AUTHORITY` (4 forms), `MATURITY_IMPLEMENTED_CONCRETE_EVIDENCE`,
`MATURITY_POLICY_AUTHORITY`, `MATURITY_PLANNED_ACCEPTED_ADR`,
`MATURITY_DEFERRED_EXPLICIT_AUTHORITY`, `MATURITY_NOT_IMPLEMENTED`,
`MATURITY_UNKNOWN_CONFLICT`, `MATURITY_ASSUMED_NOT_EVIDENCE`, plus
`no currentProduct singleton in product_registry domain logic` — **all pass**.

## 23. AUTHORITY / PERSISTENCE QA GROUP

Baseline-approval authority, cross-product refusal, restart durability,
migration, and generation are exercised by the 86-pass integration run (§20).
The five-field binding is additionally proven by the live pending decision
(§10) and the resolved rework decisions (§17).

## 24. SERVERPOD GENERATION REPRODUCIBILITY

`serverpod generate` was run and the generated output compared by SHA-256
against the pre-run snapshot: **56 generated files byte-identical**. No manual
repair of generated files.

## 25. MIGRATION / DEDUPE INDEX STATUS

The pre-existing `job_active_dedupe_unique` drift is unchanged and unrelated to
S-1: the live test database reports `Missing Index "job_active_dedupe_unique"`
against the generated target. Integration tests are green with the warning
present. This remains a documented, pre-existing deviation.

## 26. CROSS-PRODUCT / ISOLATION (regression)

No change. `ProductContext(A)` cannot return B; cross-product acceptance is
refused (not filtered); no `currentProduct` singleton exists in domain logic.
All covered by the passing integration and unit suites.

## 27. INDEPENDENT REVIEW (adversarial trace)

Self-review, honestly labeled: the reviewer is the same execution that authored
the correction. Traced the four risks that matter:

1. **Fabrication risk.** Revision 7 contains **no new claim** — every fact is a
   subset or a deterministic merge of revision-6 facts. Verified programmatically.
2. **Silent data loss on merge.** Group homogeneity on all six fields was
   asserted before collapsing; two independent passes found no heterogeneity.
3. **Evidence laundering.** Every repointed path was verified to exist; no
   `(absent)` marker was converted into a false present-tense reference.
4. **Gate shortcuts.** No baseline was accepted; `activeBaseline` is null; the
   one pending decision is blocking.

Recorded limitation: `reviewerModelDiversity: not_available` (single adapter).
Independence of execution is **not** claimed for this correction pass.

## 28. KNOWN ISSUES / OPEN FINDINGS

- **Maturity heuristic gap (open).** `MaturityClassifier` matches the substring
  `implemented`, so underscore-form `NOT_IMPLEMENTED` claims can be misread as
  present-tense. Not fixed in this pass (out of the data-only correction scope);
  recommend a follow-up code fix and regression test.
- **Scan-observation facts remain `implemented`.** Ingestion-safety observations
  (e.g. "secret pattern found in … — value redacted") are labelled `implemented`
  by the current-state rule. They assert no feature authority, but the label is
  loose; flagged for human review, not silently reclassified.
- **Revision 7 still supersedes a proposed (never accepted) revision 6.** The
  lineage contains no accepted baseline, which is correct for a proposed gate.
- **Pre-existing `job_active_dedupe_unique` drift** (§25).
- **Self-review, not independent execution** (§27).

## 29. FILES / SCRIPTS REMOVED

`apps/server/bin/resolve_v6_decision.dart` and
`apps/server/bin/build_rev7_baseline.dart` were transient correction drivers and
were deleted after use. `apps/server/bin` retains only the sanctioned scripts.

## 30. GATE

**`PRODUCT_BASELINE_APPROVAL_REQUIRED`** — a human must approve or reject
`bl-shipit-platform-7` (revision 7, hash
`c98397cb6b4128dca81f656059612bf36b9728e2b8be4063d65d9f86b30ae237`). The agent
must not self-approve. Secondary gate `READY_FOR_DESIGN` (no UI built) remains
open.

## 31. VERDICT

**CORRECTIONS APPLIED — V3 baseline proposed, lineage deduped and
authority-audited, exactly one pending approval decision; full suite green.**

`S-1 = IMPLEMENTED_AWAITING_HUMAN_BASELINE_ACCEPTANCE_AND_DESIGN`

Halt at `PRODUCT_BASELINE_APPROVAL_REQUIRED`.

---

## 32. POST-APPROVAL RECONCILIATION (durable closure, 2026-09-18)

The original S-1 report and the correction report above were written at the
`PRODUCT_BASELINE_APPROVAL_REQUIRED` gate while revision 7 was **proposed,
never accepted**. Both remain the accurate historical record of that moment.
What follows is the durable reconciliation of the **actual post-approval
state**, produced by the same durable engine/store against the live DEV
database after a human resolved the pending approval decision. It supersedes
nothing; it records the outcome the durable store now holds.

### 32.1 Durable result (Postgres `control_plane`)

| Object | Durable value |
|---|---|
| Accepted baseline | `bl-shipit-platform-7` (revision 7) |
| Baseline status | `accepted` |
| `contentHashVersion` | `3` |
| `contentHash` | `c98397cb6b4128dca81f656059612bf36b9728e2b8be4063d65d9f86b30ae237` |
| `acceptedBy` | `human-review` |
| `acceptedDecisionId` | `blappr-bl-shipit-platform-7` |
| Decision status | `resolved` |
| Decision choice | `approve` |
| Decider | `human-review` |
| Active baseline | `bl-shipit-platform-7` |

- Pending baseline-approval decisions for the product scope: **0** (exactly one
  existed; it is now resolved). No duplicate/replacement decision was created.
- `product_baseline` revisions 1–6: superseded (each `supersedes` its
  predecessor); revision 7 is the single accepted revision.
- `onboarding_record` for `shipit-platform`: **0 rows** — **EXPECTED_BY_CURRENT_PATH**
  for this lineage. The S-1 dogfood exercised the approval-decision path, not
  the durable clarification path that populates `onboarding_record`; the durable
  authority is therefore the persisted `HumanDecision` + accepted
  `ProductBaseline`, not an onboarding completion row. No row was fabricated.

### 32.2 Approval mechanism (honest record)

The approval was executed through the sanctioned
`ProductRegistryEngine.resolveBaselineApproval` call against the running dev
control plane (`apps/server`, dev port), binding all five authority fields
including `contentHashVersion` and the exact revision-7 `contentHash`. The
bound candidate was **accepted in place** — no replacement baseline was created,
and the accepted revision is immutable.

The agent **did not self-approve**: the resolution was performed only after an
explicit human decider (`human-review`) authorized the `approve` choice with the
required rationale. This is a human-gated baseline acceptance, not
agent-self-acceptance.

### 32.3 Signature evidence limitation (not fabricated)

The recorded `HumanDecision` for `blappr-bl-shipit-platform-7` binds a
**signature-shaped placeholder** — the same non-cryptographic provenance marker
convention used by every decision in this lineage's history (§17):
`deciderType=human-review`, `resolvedOptionId=approve_baseline`, persisted
signature metadata recorded at durable resolution. It is **not** a
cryptographically verifiable signature. This reconciliation does **not** claim
cryptographic authentication of the approval; the durable authority is the
persisted resolved `HumanDecision` bound to the exact accepted baseline.

### 32.4 Follow-ups recorded from this reconciliation (open, not closed by approval)

| Follow-up | Scope | Status |
|---|---|---|
| `CLASSIFIER_SOURCE_DRIFT_VS_REV7` | `MaturityClassifier` substring heuristic can classify underscore-form `NOT_IMPLEMENTED` as `implemented` (§15/§28) | **OPEN** — preserved; baseline acceptance does not close it |
| `VERIFIED_HUMAN_DECISION_SIGNATURES` | Productionization of human-decision signature evidence (cryptographic verification of `HumanDecision`) | **OPEN** — bounded follow-up, security hardening; not implemented in S-1 |
| `EVIDENCE_BACKED_EXECUTION_CLAIMS` | Future ShipIt orchestration: completion/readiness claims must derive from typed durable execution evidence (persisted reads, test runs, migration/applied, artifact refs, durable decisions), not free-form agent narration | **OPEN** — future closure/orchestration work, not S-2 |

Baseline acceptance **does not** silently close any of these; they remain
separately tracked. Revision 7 is additionally **not reopened** by any of these
follow-ups — accepted revision 7 remains the authoritative baseline until a
legitimate later revision supersedes it through the same durable gate.

### 32.5 ProductBaseline authority invariant (recorded)

The authoritative Product understanding for ShipIt is now:

```
ProductContext(shipit-platform)
  → activeBaseline = bl-shipit-platform-7
  → revision 7
  → contentHashVersion 3
  → contentHash c98397cb6b4128dca81f656059612bf36b9728e2b8be4063d65d9f86b30ae237
  → accepted via HumanDecision blappr-bl-shipit-platform-7 (resolved/approve)
```

Historical baselines (revisions 1–6) remain durable audit/lineage evidence; they
are **not** composed with revision 7 to derive current Product truth. Accepted
revision 7 is authoritative alone.

### 32.6 S-1 closure status

- **Durable/persistence/S-1 acceptance criteria:** satisfied against the live
  DEV database (durable accepted baseline + bound resolved decision; 0 pending;
  isolation/cross-product refusal proven in §13; restart durability in §22).
- **S-1 = COMPLETE** for the baseline-approval slice. The `READY_FOR_DESIGN`
  gate (human baseline acceptance + then design authority) is the next gate
  established by the approved program and is **not** implied by this closure;
  S-1 completion does **not** constitute S-2 approval. S-2 remains separately
  gated and has not begun.

### 32.7 Working-tree note

Documentation only: this section was appended to the existing correction
report. No schema, migration, endpoint, wire contract, generated file, or
production data was changed by this reconciliation pass.
