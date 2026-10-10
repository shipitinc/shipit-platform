# Dispatch — fix-baseline-guard (L1, fast-tracked security remediation)

```yaml
MANAGER: engineering-manager (shipit-platform baseline-production work item)
TASK_ID: fix-baseline-guard
TASK_TYPE: implement
FEATURE: Make baseline verification independence structural and fail closed
AREA: platform-contracts baseline types + product-registry engine
WORKTREE: /private/tmp/shipit-fix-guard
BRANCH: fix/baseline-guard
BASE_SHA: 27a520a
OWNED_PATHS:
  - packages/platform_contracts/lib/src/types/product_baseline.dart
  - packages/platform_contracts/lib/src/types/baseline_verification.dart
  - packages/platform_contracts/test/**
  - packages/product_registry/lib/src/**
  - packages/product_registry/test/**
READ_ONLY_PATHS:
  - apps/server/lib/src/endpoints/product_registry_endpoints.dart
  - apps/control_plane/lib/data/control_plane_repository.dart
  - AGENTS.md
  - docs/engineering/dispatch/tasks/design-baseline-production-lane/**
PROHIBITED_PATHS:
  - apps/**
  - docker/**
  - .github/**
  - .decisions/**
  - AGENTS.md
  - docs/**
ACCEPTANCE_CRITERIA: >
  A producer's own identity cannot satisfy ProductGuard.baselineVerifiedIndependently; there is no
  permissive default and no caller-selectable evidence kind; platformVerifiedEvidence requires a
  re-derivation proof; existing behaviour outside baseline verification is unchanged.
VALIDATION_COMMANDS:
  - dart analyze packages/platform_contracts packages/product_registry
  - dart test packages/platform_contracts
  - dart test packages/product_registry
ROUTING_CLASS: PRECISION
SECURITY_REMEDIATION: true
HUMAN_DECISIONS:
  - 8bc53162-a4fd-4856-aa5c-c5dd70285a3d  # fast-track F-1
  - 7bbee7c6-c6a8-4600-aa51-129f479320b7  # HD-1 independent re-derivation
  - 2bb84f06-af46-40f1-93a9-82a6d327491a  # HD-2 restore section 12
```

---

## Why this lane is fast-tracked

The human decided (`8bc53162`) to close a **live governance bypass** ahead of the rest of the design work.
`verifyBaseline` today takes `EvidenceKind kind = EvidenceKind.platformVerifiedEvidence` — the **permissive
value as the default** — and `isIndependentlyVerified` tests only that kind plus a non-empty `verifiedBy`.
Any caller that omits `kind` self-certifies. That permissive default is also hardcoded on the **wire**
(`product_registry_endpoints.dart:557-560`), so any API client can forge `verifiedBy` and unlock
`baselineVerifiedIndependently` for a first baseline **and** for re-baselining a governed product.

Read `AGENTS.md §12` — **restored in this base commit (`27a520a`)**, which previously did not exist despite
eleven citations. That section is now the normative policy you implement.

## What to build

**Make independence structural, not conventional.** Per HD-1 (`7bbee7c6`), the basis of the guard is
**independent re-derivation**: a verifier recomputes the baseline from the same source and compares the
result against what was proposed. A producer that fabricates must be caught by **divergence**.

Design guidance from the approved revision
(`docs/engineering/dispatch/tasks/design-baseline-production-lane/design-revision.md`, read it — §1–§5):

1. **Remove the caller's ability to name the kind at all.** Introduce a sealed
   `PlatformReDerivationProof` in `baseline_verification.dart` whose construction **requires** the
   re-derived hash. Then there is no default to omit and no wire parameter to abuse. A caller that
   supplies only an identity cannot unlock the gate.
2. **`isIndependentlyVerified` must fail closed.** It must not be satisfiable by a producer's own
   identity. Consider whether the baseline should record *who proposed* it and refuse verification when
   the verifier matches.
3. **Replace the permissive default.** `verifyBaseline` must no longer default to
   `platformVerifiedEvidence`. An agent's own claim is recorded as `agentClaimedEvidence` — preserved as
   real evidence of what was asserted, but never unlocking the gate.
4. **The decisive precedent is in this repo.** `schema_bootstrap.sql:162-189` has
   `trigger_design_review_independence`, whose comment reads *"Separation of duties is a database
   invariant here, not a convention the call sites are trusted to honour."* Design-review independence is
   DB-enforced; baseline-verification independence is convention-only. **That asymmetry is the defect.**

## Constraints you must not violate

- **State the residual hole.** §12 requires it be recorded deliberately: re-derivation assumes the
  verifier acquires the source independently of the producer, so a single compromised process controlling
  both acquisitions defeats it. Put this in a code comment where the proof is constructed — do not let the
  guarantee read as absolute.
- **Keep the change surgical.** This is security remediation on a live path. Do not refactor
  `proposeBaseline`, lifecycle transitions, or anything outside baseline verification.
- **Schema is another lane's (L2).** Do not edit `apps/server/**`, `schema_bootstrap.sql`, or
  `*.spy.yaml`. If the DB layer appears to need a column, record it as a follow-up rather than doing it.
- **`apps/**` is PROHIBITED** — the RPC layer is lane L3, which runs after you and cannot compile until
  your signature change lands. Expect L3 to need a mechanical follow-up; keep your API change minimal and
  obvious.
- **Existing tests that relied on the permissive default will fail.** That is the bug reproducing. Update
  them to assert the new fail-closed behaviour, and **list every test you changed and why**.
- **Zero Docker/Compose commands.** The QA stack is live and I am driving it. Read compose as text. Never
  `make clean` / `make qa-down` / `make test-env-down` / `make e2e-down` / bare `down -v`.
- Do not resolve a Human Decision; all three are recorded and resolved.

## Verification you must perform and report

- The **negative case**: a producer that fabricates a baseline is caught by divergence.
- The **self-attestation case**: verification attributed to the producing identity is refused.
- The **fail-closed case**: an identity-only call cannot unlock the gate.
- Tests in both owned packages green; `dart analyze` clean.

Do not self-approve. Report `IMPLEMENTED` with exact HEAD, the changed files, every test you modified and
why, and anything you deliberately left for L3.

## Other lanes

`L3` (remove `kind` from the RPC/service/client) is queued and blocked on you. `L2` (schema/tool/migration)
is separate and must not touch your library contract. Manager holds `AGENTS.md`, `.decisions/**`,
`docs/**`, and the lane plan.