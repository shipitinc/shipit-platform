# Dispatch — impl-baseline-lane (L4)

```yaml
MANAGER: engineering-manager (shipit-platform baseline-production work item)
TASK_ID: impl-baseline-lane
TASK_TYPE: implement
FEATURE: The baseline-production lane — automatic, restart-safe, product-agnostic
AREA: baseline lane, snapshot acquisition, scheduler definition, tick dispatch
WORKTREE: /private/tmp/shipit-lane
BRANCH: impl/baseline-lane
BASE_SHA: d6af269
OWNED_PATHS:
  - apps/server/lib/src/baseline/**
  - apps/server/lib/src/credentials/repository_snapshot_acquirer.dart
  - packages/scheduler/lib/src/baseline_product.dart
  - apps/server/lib/src/triage/lane_i_tick_hook.dart
READ_ONLY_PATHS:
  - packages/platform_contracts/lib/src/types/{product_baseline,baseline_verification}.dart
  - packages/product_registry/lib/src/**
  - apps/server/lib/src/credentials/**
  - apps/server/lib/src/triage/lane_e_design_remediation_work_item.dart
  - apps/server/bin/onboard_shipit_dev.dart
  - apps/server/lib/src/database/product_baseline.spy.yaml
  - AGENTS.md
  - docs/engineering/dispatch/tasks/design-baseline-production-lane/**
PROHIBITED_PATHS:
  - packages/product_registry/**
  - packages/platform_contracts/**
  - apps/control_plane/**
  - apps/server/lib/src/endpoints/**
  - apps/server/lib/src/generated/**
  - apps/server/test/**
  - apps/server/tool/**
  - apps/server/migrations/**
  - apps/server/lib/src/database/**
  - docker/**
  - .github/**
  - .decisions/**
  - AGENTS.md
  - docs/**
ACCEPTANCE_CRITERIA: >
  A registered product with a usable repository reference gets a baseline proposed automatically,
  restart-safely and idempotently, with no ShipIt-specific behaviour anywhere in the lane.
VALIDATION_COMMANDS:
  - dart analyze apps/server packages/scheduler
  - dart test packages/scheduler
ROUTING_CLASS: PRECISION
CONCURRENT_LANE: impl-baseline-schema (L2) — disjoint paths, do not touch its files
```

---

## The answer to the question that started this

The operator asked: *"that script seems tailored to shipit — how would another product become governed?"*
The honest answer turned out to be **"someone remembers to run a dev script."** Your lane is that
missing capability. **Build it product-agnostically.** Nothing in your code may name `shipit`,
`shipit-platform`, or any specific product, repository, host or fingerprint.

## Read first

- `docs/engineering/dispatch/tasks/design-baseline-production-lane/design-revision.md` — §3.1 (trigger),
  §3.2 (acquiring the source), §3.3 (production vs verification), §3.6 (`JobType` reuse), §3.9
  (migration/rollout). This is your specification. Follow it.
- `AGENTS.md §12` — the normative policy. Automation stops at *verified and awaiting approval*; the
  human approval gate is final authority and no automation may satisfy `decisionActorIsHuman`.
- `apps/server/bin/onboard_shipit_dev.dart` — the logic you are productizing. **It is generic today**
  (`productId` from argv or `SHIPIT_PRODUCT_ID`), but it is a hand-run dev script. Move its correctness;
  do not move its shape.

## Already landed and reviewed — do not modify

`d6af269` carries three approved commits. `packages/**` contracts are FROZEN.

- `674a10d` — sealed `PlatformReDerivationProof`; `verifyBaseline` takes NO caller-selectable kind;
  identity-only records `agentClaimedEvidence`, which never satisfies `ProductGuard.baselineVerifiedIndependently`.
- `a58e137` — `normalizeBaselineIdentity`, applied once at construction.
- `f298713` — `verifyBaseline` **removed from the public RPC**, the generated dispatch table, and the
  generated client. The engine still has it, for server-side callers like you.

If the frozen contract cannot express what you need, STOP and report it as a finding.

## Required work

1. **`RepositorySnapshotAcquirer`** (new, `apps/server/lib/src/credentials/`) — a pinned, read-only
   snapshot plus its committed revision. Reuse `CredentialKeyService.verifyAccess` and
   `RepositoryAccessVerifier.verify`; do not invent a third acquisition path.

   **The distinction you must not blur (§3.2):** the deploy key's public-key fingerprint is the
   **credential's** fingerprint. It is **not** a **host key** fingerprint, and
   `RepositoryAccessVerifier.verify` requires `confirmedHostKeyFingerprint` — a different value with a
   different provenance. **Never pass the credential fingerprint as the host key fingerprint.** If a
   product's remote has no independently-confirmed host key, **stop at the external-dependency state
   (§3.9). Do NOT fall back to `ssh-keyscan` and trust the result** — that reintroduces exactly the gap
   ADR 0018 recorded as accepted.

   Credential material is referenced **by name only** (§13a). The value must never enter a log, a
   record, a job instruction, or a baseline fact.

2. **The lane** (`apps/server/lib/src/baseline/**`) — derivation, proposal, verification.

   **Move the content-dedupe logic verbatim from `onboard_shipit_dev.dart:160-164` and `:222-228`.** It
   reuses an existing baseline whose `contentHash` already equals the freshly derived one instead of
   superseding it with an identical copy, and it preserves human-authored (`humanProvided`) claims by
   merging rather than starting from scratch. It is correct today; losing it would be a regression.

   **Preserve the F-3 fix.** F-3 found that `:324-325` compares a scraped-only hash against a
   `contentHash` computed over scraped+human at `:205-213`, and that same path clears `verifiedAt` — so
   re-running after a human adds a claim exits 5, blaming the repository. The `else` branch at
   `:354-359` does it correctly. Whatever you move must not reintroduce that.

3. **Trigger (§3.1) — two triggers, one dedupe key.** `dedupeKey = onboarding:$productId:$repositoryId:$startingRevision`
   already exists at `control_plane_service.dart:1840`; reuse it. `triggerOnboarding` currently writes
   a job that has sat `queued` forever (**F-4**: `JobType.onboardProduct` already exists and nothing
   consumes it) — fix that; it is a live silent no-op. Plus a periodic sweep, deliberately narrow:

   ```
   enqueue onboarding  ⟺  product.state ∈ {draft, baselinePending, baselineBlocked}
                      ∧  ∄ row in product_baseline for productId
                      ∧  ∃ repositoryReference with a usable, confirmed credential
                      ∧  ∄ non-terminal job with this dedupeKey
   ```

   `baselineBlocked` is included because a product blocked on a clarification still has **no** baseline.
   The **lane** must skip it, not the sweep, so the skip is observable.

4. **Tick dispatch (`lane_i_tick_hook.dart:129-143`).** The hook **skips every job whose type is not
   `triageDefect`**. Without extending it your job is silently invisible — the exact silent-no-op class
   this work item keeps finding.

5. **`packages/scheduler/lib/src/baseline_product.dart`** — the scheduler definition (§3.6, reuse
   `JobType.onboardProduct`).

## Constraints

- **Do not fake what does not exist.** If a piece requires runtime absent from this repo, mirror
  `apps/server/lib/src/triage/lane_e_design_remediation_work_item.dart`: a `*RuntimeKey` constant, value
  `'unavailable'`, terminal `EXTERNAL_*_DEPENDENCY`, commented *"unavailable means the runtime does not
  exist in shipit-platform, not that a human declined to run it."* An honestly recorded dependency is
  correct; a stub that appears to verify without verifying is not.
- **Keep §12's residual hole at full strength.** Re-derivation assumes the verifier acquires the source
  independently of the producer; one compromised process controlling both defeats it. Do not let your
  implementation imply a stronger guarantee than that.
- **Never write a private half, key value, or fingerprint-of-a-secret** into a log, record, job
  instruction or baseline fact.
- Do not weaken, delete or skip any test. Put your tests **co-located under
  `apps/server/lib/src/baseline/**`** — `apps/server/test/**` belongs to lane L2 and you must not
  write there.
- ZERO Docker/Compose commands. **The QA stack is LIVE and I am driving it.** Read compose as text.
  NEVER run `make clean` / `make qa-down` / `make test-env-down` / `make e2e-down` / bare
  `docker compose … down -v` — those resolve to compose project `docker`, the live QA stack, and a
  `down -v` there destroyed the QA database irrecoverably once already. If you need a database you are
  BLOCKED: escalate and name the exact command you need. Do not improvise a compose project.
- Do not resolve a Human Decision. HD-1 (`7bbee7c6`), HD-2 (`2bb84f06`), F-1 (`8bc53162`) are resolved.

## Verification you must perform and report

- **Product-agnosticism:** prove it. Name a second hypothetical product and show nothing in your code is
  ShipIt-specific.
- **Restart-safety:** a crash between any two steps leaves the durable record consistent.
- **Idempotency:** re-running does not spam revisions or duplicate jobs.
- **The skip is observable:** a `baselineBlocked` product is skipped by the lane and that skip is
  visible in the job record — not silently dropped.
- **A producer that fabricates is caught** by divergence (`BaselineReDerivationDivergenceException`).
- **The human gate still holds:** after your lane runs, `decisionActorIsHuman` is unsatisfied and
  `governed` is unreachable without a human.

Report IMPLEMENTED with exact HEAD, changed-file list, which F-findings you closed, the product-agnosticism
proof, gates run and NOT run, and anything recorded as an honest unavailable-runtime dependency.