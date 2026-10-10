# Dispatch — impl-baseline-schema (L2)

```yaml
MANAGER: engineering-manager (shipit-platform baseline-production work item)
TASK_ID: impl-baseline-schema
TASK_TYPE: implement
FEATURE: Persist producer identity and enforce baseline verification independence in the database
AREA: schema, migration, bootstrap drift guard
WORKTREE: /private/tmp/shipit-schema
BRANCH: impl/baseline-schema
BASE_SHA: d6af269
OWNED_PATHS:
  - apps/server/tool/schema_bootstrap.sql
  - apps/server/tool/verify_schema_bootstrap.sh
  - apps/server/migrations/**
  - apps/server/lib/src/database/product_baseline.spy.yaml
  - apps/server/test/**
READ_ONLY_PATHS:
  - packages/platform_contracts/lib/src/types/{product_baseline,baseline_verification}.dart
  - packages/product_registry/lib/src/**
  - apps/server/lib/src/triage/lane_e_design_remediation_work_item.dart
  - apps/server/lib/src/endpoints/product_registry_endpoints.dart
  - AGENTS.md
  - docs/engineering/dispatch/tasks/design-baseline-production-lane/**
PROHIBITED_PATHS:
  - packages/**
  - apps/control_plane/**
  - apps/server/lib/src/baseline/**
  - apps/server/lib/src/triage/**
  - apps/server/lib/src/credentials/**
  - apps/server/lib/src/generated/**
  - docker/**
  - .github/**
  - .decisions/**
  - AGENTS.md
  - docs/**
ACCEPTANCE_CRITERIA: >
  Producer identity is persisted on the baseline row and compared by the database, not by the
  caller's supplied string; a trigger refuses platform_verified_evidence when the verifier equals
  the persisted producer; the drift guard passes; a round-trip test proves the column survives.
VALIDATION_COMMANDS:
  - bash apps/server/tool/verify_schema_bootstrap.sh
  - dart analyze apps/server
  - dart test apps/server/test --exclude-tags=integration
ROUTING_CLASS: PRECISION
CONCURRENT_LANE: impl-baseline-lane (L4) — disjoint paths, do not touch its files
```

---

## Context: the reviewed work already landed

`d6af269` carries three approved commits plus the restored policy:

- `674a10d` — sealed `PlatformReDerivationProof`; `verifyBaseline` no longer accepts a
  caller-selectable `EvidenceKind`; identity-only records `agentClaimedEvidence`, never unlocking the gate.
- `a58e137` — `normalizeBaselineIdentity`, applied once at construction, canonical-to-canonical comparison.
- `f298713` — `verifyBaseline` removed from the public RPC, the generated dispatch table and the generated client.
- `27a520a` — restored `AGENTS.md §12`, the normative policy. **Read it.**

**Do not modify `packages/**`.** The contract is reviewed, approved, and frozen. If the schema cannot
express what the contract requires, STOP and report it as a finding.

## The asymmetry you are closing

`schema_bootstrap.sql:162-189` defines `trigger_design_review_independence`, commented:

> *"Separation of duties is a database invariant here, not a convention the call sites are trusted to honour."*

**Design-review independence is DB-enforced. Baseline-verification independence is convention-only.**
That asymmetry is the defect. Your lane makes it a database invariant, using the same proven pattern.

## What the L1 lane explicitly left to you

The L1 implementer recorded this as a follow-up and deliberately did **not** do it, for a reason you
must respect:

> *No `proposedBy`/producer-identity column exists on `product_baseline`. `producedBy` is carried on
> the transient proof and is caller-supplied, so it is NOT a non-forgeable boundary on its own. The
> load-bearing guarantee is divergence; the identity check is defence-in-depth… I deliberately did NOT
> add the field — a column-less round-trip through the spy would silently null it, making tests green
> while production degraded.*

So you are persisting `proposedBy` on `product_baseline`, and the trigger must compare
`NEW."verifiedBy"` against the **stored** `proposedBy`, never against a caller-supplied value.

## Required work

1. Add the columns the contract needs on `product_baseline`: at minimum `proposedBy`, plus
   `verifiedContentHash` / `comparableSubsetHash` if §3.4 of the design requires them for the
   trigger's second clause. Read `packages/platform_contracts/lib/src/types/product_baseline.dart` and
   `baseline_verification.dart` first and match the names the frozen contract actually uses — do not
   invent near-miss names.

2. Add `enforce_product_baseline_verification_independence()` mirroring the design-review trigger:
   - refuse `platform_verified_evidence` when `NEW."verifiedBy"` equals the **stored** `proposedBy`;
   - refuse `platform_verified_evidence` when `NEW."verifiedContentHash"` is distinct from
     `NEW."comparableSubsetHash"`.
   Read `docs/engineering/dispatch/tasks/design-baseline-production-lane/design-revision.md` §3.4
   "Layer 4" for the specified shape and follow it.

3. Write the migration under `apps/server/migrations/**`.

4. **State what a DB trigger cannot do.** `baselineContentHashV3` is Dart with no SQL counterpart, so
   the trigger can enforce *internal consistency* (the stored producer, the two hashes) but NOT
   *correspondence to a real derivation*. The engine enforces that. Put this limit in a comment where
   the trigger is defined — do not let the trigger read as a complete guarantee, because §12 requires
   the residual hole be recorded deliberately rather than left implied.

5. Update `verify_schema_bootstrap.sh` so drift is caught. Prove it works: temporarily perturb the
   bootstrap and show the guard fails, then restore. Report both outputs.

6. **Round-trip test.** The L1 warning above is the trap: a spy column that never round-trips makes
   tests green while production silently degrades. Prove `proposedBy` survives a real write→read cycle
   against a database. This is the test that matters most in your lane.

## Constraints

- The 20 `OK:` lines from `verify_schema_bootstrap.sh` must all still pass.
- Existing schema parity tests must stay green. If adding a column requires touching a parity fixture,
  do it and say so — never weaken an assertion to accommodate your change.
- Do not weaken, delete or skip any test to get green.
- ZERO Docker/Compose commands. **The QA stack is LIVE and I am driving it.** Read compose as text.
  NEVER run `make clean` / `make qa-down` / `make test-env-down` / `make e2e-down` / bare
  `docker compose … down -v` — those resolve to compose project `docker`, the live QA stack with real
  data, and a `down -v` there destroyed the QA database irrecoverably once already. If you need a
  database you are BLOCKED: escalate and name the exact command you need, do not improvise. If you
  create a disposable database yourself, it must be under an explicitly named compose project and
  removed on success, failure and interrupt alike — resolve paths absolutely, because a cleanup trap
  that runs after the recipe `cd`-ed is how a leak happens.
- Do not resolve a Human Decision. HD-1 (`7bbee7c6`), HD-2 (`2bb84f06`) and F-1 (`8bc53162`) are
  recorded and resolved.

## Report

Report IMPLEMENTED with exact HEAD, changed-file list, the trigger's SQL, what the trigger can and
cannot enforce, the drift-guard perturbation proof (both outputs), which tests you modified and why,
gates run, gates NOT run (be explicit about anything database-gated), and anything left for L4.