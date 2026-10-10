# Dispatch — design-baseline-production-lane

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: design-baseline-production-lane
TASK_TYPE: design-produce
FEATURE: Design the missing automatic baseline-production path with verification separated from production
AREA: workflow job types, triage lanes, product-registry verification guard
WORKTREE: /private/tmp/shipit-design-baseline-lane
BRANCH: design/baseline-production-lane
BASE_SHA: 889eee2
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-baseline-production-lane/**
READ_ONLY_PATHS:
  - apps/server/lib/src/triage/**
  - apps/server/lib/src/endpoints/**
  - packages/workflow_engine/lib/**
  - packages/product_registry/lib/**
  - packages/platform_contracts/lib/**
  - apps/server/bin/onboard_shipit_dev.dart
  - apps/server/lib/src/credentials/**
PROHIBITED_PATHS:
  - apps/server/**
  - packages/**
  - apps/control_plane/**
  - docker/**
  - .github/**
  - docs/adr/**
  - .decisions/**
ACCEPTANCE_CRITERIA: >
  A Design Revision specifying how a registered product gets a baseline proposed automatically,
  how verification is performed by an identity genuinely separate from the producer, and how the
  product-registry guard stops the producer from attesting to its own work.
VALIDATION_COMMANDS:
  - bash apps/server/tool/verify_schema_bootstrap.sh
ROUTING_CLASS: PRECISION
```

---

## Why this lane exists

The operator asked: *"that script seems tailored to shipit — how would another product become governed?"*
Investigating found the honest answer is **"someone remembers to run a dev script."** That is a missing
capability, and the operator chose to **build the actual missing path** rather than run the script.

This is a **design** task, not implementation. It is a security boundary: the whole point of
`ProductGuard.baselineVerifiedIndependently` is that a product is not governed on an agent's say-so alone.
Produce a Design Revision; implement nothing.

## What exists today — verified, do not re-derive

**The only first-baseline author is `apps/server/bin/onboard_shipit_dev.dart`.** It is *generic* —
`productId` from `argv[0]` or `SHIPIT_PRODUCT_ID`, repository from `SHIPIT_REPOSITORY_PATH`, and only the
filename and defaults are ShipIt-flavored. Its reusable machinery: snapshot → observations →
`MaturityClassifier` → `BaselineFact[]`, plus content-hash dedup and merging of human-authored claims. It
reads a **local directory**, not a cloned repository.

**Job infrastructure exists but is triage-only.**
- `JobType` is a typed enum; only `JobType.triageDefect` exists for this flow.
- `apps/server/lib/src/triage/lane_i_tick_hook.dart:129-143` **skips every job whose type is not
  `triageDefect`**, so a new type would be invisible to the hook unless it is extended.
- Existing lanes: `lane_a_defect_triage_work_item.dart`, `lane_e_design_remediation_work_item.dart`.

**There is a precedent worth following.** `lane_e_design_remediation_work_item.dart` models a missing
runtime honestly: it records `designGovernanceRuntimeKey = 'unavailable'` and the terminal value
`EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY`, with the comment *"The honest terminal state of this flow until
the design governance runtime exists… `unavailable` means the runtime does not exist in shipit-platform, not
that a human declined to run it."* Use this shape when something is genuinely unavailable.

**The verification guard is weaker than it reads — this is the security finding that motivates the lane.**
`verifyBaseline` (`packages/product_registry/lib/src/engine/product_registry_engine.dart:259`) takes
`EvidenceKind kind = EvidenceKind.platformVerifiedEvidence` — **the permissive value as the default** — and
`isIndependentlyVerified` (`packages/platform_contracts/lib/src/types/product_baseline.dart:104-107`) tests
only `verificationKind == platformVerifiedEvidence && verifiedBy != null && verifiedBy.isNotEmpty`.

The doc comment above `verifyBaseline` states: *"an agent may produce a baseline but may never attest to it.
Only `platformVerifiedEvidence` satisfies `ProductGuard.baselineVerifiedIndependently`; an agent's own claim
is recorded but does not unlock the approval gate."* **Nothing in the code enforces that.** A caller that
omits `kind` self-certifies. The CLI exploits this: it builds the baseline and then verifies it **in the same
process**, passing `verifiedBy: 'worker:baseline-verifier/onboard_shipit_dev'` with the default kind. So
today, "independently verified" means *"a string was written in a field"* — the human gate on top is genuine,
but the precondition under it is self-attested.

**A real deploy key now exists** for `shipit-platform` (`verified`, fingerprint
`SHA256:5m1i2lVYE7H/aCdtJ/xDxR88lVxx807dkaPBhyyKOhg`) with a private half held by the secret provider, so a
worker could in principle clone. Assess whether that is the right credential for this and whether
`repository_access_verifier.dart` / `ssh_remote.dart` can be reused rather than reinvented.

## What the design must answer

1. **Trigger.** What starts baseline production for a registered product? An event on registration, a
   periodic sweep for registered products with no baseline, or a job the operator can request. Consider
   idempotency and what happens on restart.
2. **Acquiring the source.** The CLI reads a local path; a worker must obtain the repository. Reuse the
   credential/access verifier, or something else? This is where a deploy key earns its purpose.
3. **Production vs verification — the core question.** Make the producer/verifier separation *structural*
   rather than conventional: distinct identities, distinct execution contexts, and a verifier that cannot
   be the producer. State concretely what "independent" means here and how the system knows.
4. **Fixing the guard.** Make `isIndependentlyVerified` fail closed — a producer's own identity must not
   satisfy it, and the permissive `kind` must not be the default. Say exactly what changes and what could
   break. Note this alters an existing invariant, so be explicit about migration and about callers that
   currently rely on the default.
5. **What legitimately issues `platformVerifiedEvidence`?** If not an agent, then what — a second agent
   with a distinct identity, a deterministic re-derivation compared against the proposal, or a human?
   **If this cannot be answered without human authority, escalate it rather than choosing.** A plausible
   strong option worth evaluating: the verifier independently re-derives the baseline from the same source
   and compares content hashes, so a producer that lies is caught by divergence rather than by policy.
6. **A new `JobType`, or reuse?** If a new type, the tick hook must be extended or the lane will be silently
   skipped — the exact silent-no-op class this work item keeps finding.
7. **What remains human.** The approval gate must stay human (`decisionActorIsHuman`). Be explicit that
   automation stops at *verified-and-awaiting-approval*.
8. **Product-agnosticism.** The whole point is that *any* product gets this. Design against a second
   hypothetical product, not ShipIt.
9. **Migration and rollout.** Existing products with no baseline; the `EXTERNAL_*_DEPENDENCY` precedent if
   part of this is unavailable today.
10. **Verification plan** for the whole path, including the negative case: a producer that fabricates a
    baseline must be caught.

## Hard constraints

- **Produce a design only.** No production source, no generated files, no tests changed. Proposed diffs go
  **in the document as text**.
- **`packages/**`, `apps/server/**`, `apps/control_plane/**` are PROHIBITED** — read them, do not touch them.
- **ZERO Docker/Compose commands.** The QA stack is live and I am driving it. Read compose as text.
  `bash apps/server/tool/verify_schema_bootstrap.sh` is read-only text verification and is permitted; run it
  and report. Never `make clean` / `make qa-down` / `make test-env-down` / `make e2e-down` / bare `down -v`.
- Do not resolve a Human Decision. Where the design needs human authority (see 3 and 5), say so and route it.

## Deliverable

A Design Revision under your task directory per `DESIGN_GOVERNANCE.md`, with a **proposed diff as text**,
`RISK_LEVEL` with rationale, per-constraint traceability, and the plan for the implementation lanes this
unblocks (with non-overlapping `OWNED_PATHS` proposed per lane).

Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`, and
`READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES`. Note explicitly if you are escalating a human decision.

## Other lanes

None are writing these paths. The governance-panel fix is merged at `889eee2`. Manager holds
`LANES.md` / `WORK_STATE.md` / `.decisions/**`.