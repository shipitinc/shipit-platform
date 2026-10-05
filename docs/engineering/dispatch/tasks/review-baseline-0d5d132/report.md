# Report — review-baseline-0d5d132

Persisted verbatim per `aef-orchestrator` §14. Lane: `engineering-reviewer` (risk-stratified).
Worktree: `/private/tmp/shipit-review-baseline` (created detached at `0d5d132`, removed).
Canonical checkout verified unchanged: HEAD `2f018af`, 62 entries.

## Gate results (all re-run by the reviewer in a fresh detached worktree)

| Gate | Command | Result |
|---|---|---|
| Provenance | `git rev-parse HEAD` | `0d5d132c2d6fb29ec2227d8b457a1b2beb2c3216` |
| Deps | `flutter pub get` | exit 0 |
| Frontend analyze | `flutter analyze --no-pub` | exit 1 — 33 info, **0 errors, 0 warnings** |
| Frontend tests | `flutter test --no-pub` | **190/190**, exit 0 |
| Web build | `flutter build web --no-pub` | exit 0 (first attempt SIGTERM from host load, retry passed) |
| **Backend analyze** | `dart analyze packages apps/server` | **exit 3 — 10 errors, 2 warnings, 433 info** |
| **CI format gate** | `dart format --output=none --set-exit-if-changed lib test` | **FAIL — 40 files across 8 of 17 packages** |

Two prior-lane claims did not reproduce: `flutter analyze` shows 0 warnings (not 1), and the
web build needed a retry. Reported honestly rather than claimed as clean first-pass.

## Structured result (verbatim)

```
RESULT: DO_NOT_MERGE

REVIEWED_HEAD: 0d5d132c2d6fb29ec2227d8b457a1b2beb2c3216 (branch baseline/product-2026-10-05)

BLOCKERS:

B1. apps/server does not analyze — 10 compile errors; CI is red on arrival.
    All four files are NEWLY ADDED by 0d5d132 and have ZERO references anywhere in the repo.
      apps/server/bin/onboard_simple.dart:31   undefined_function ('DatabaseConfig')
      apps/server/bin/onboard_simple.dart:54:7 undefined_named_parameter ('timeout')
      apps/server/bin/onboard_simple.dart:59   undefined_function ('PersistenceDatabase')
      apps/server/bin/onboard_simple.dart:60   undefined_function ('PostgresWorkflowStore')
      apps/server/bin/onboard_simple.dart:61   undefined_function ('PostgresHumanDecisionStore')
      apps/server/bin/onboard_simple.dart:62   undefined_function ('PostgresProductRegistryStore')
      apps/server/bin/onboard_direct.dart:31   undefined_function ('DatabaseConfig')
      apps/server/bin/onboard_direct.dart:55   argument_type_not_assignable ('Connection' -> 'Database')
      apps/server/bin/onboard_fixed.dart:43    argument_type_not_assignable ('Connection' -> 'Database')
      apps/server/bin/add_human_claims_mature.dart:35 argument_type_not_assignable
    Verified: `cd apps/server && dart analyze` -> exit 3, 10 errors.
    Why it is CI-fatal: .github/workflows/ci.yaml:17 runs `melos run analyze`; pubspec.yaml:32-35
    defines it as `dart analyze` per package; apps/server IS in the melos workspace
    (pubspec.yaml:26). No prior lane ran this, so it was never reported.
    Fix: delete the four dead scratch scripts (superseded by bin/main.dart per
    apps/server/pubspec.yaml:49), or repair them; then re-run `dart analyze packages apps/server`.

B2. CI format gate fails — 40 files across 8 of 17 packages.
    .github/workflows/ci.yaml:19 runs `melos run format`; pubspec.yaml:37-40 defines it as
    `dart format --output=none --set-exit-if-changed lib test` per package. Failures in:
    agent_runtime (1), execution_coordinator (2), platform_contracts (8), product_registry (4),
    scheduler (1), workflow_engine (1), apps/server (9), apps/control_plane (14).
    NOTE: melos' format script covers only `lib` and `test`, which is exactly why the
    unformatted bin/ scratch scripts in B1 survived.

B3. Hardcoded Postgres SUPERUSER password committed.
    apps/server/bin/test_pod.dart:16  password: 'fd6239170e2e5511e8ac0fa79a03695f28781037d4c8b644'
    This is the `postgres` superuser account (test_pod.dart:15). It must not land in shared history.
    Fix: replace with a config/env read; rotate the credential if it is live anywhere.
    Rotation is a HUMAN_SECURITY decision.

B4. The baseline contradicts its own authoritative status record.
    S2_NON_VISUAL_RELEASE_BLOCKER_CLOSURE.md:236-245 "## FINAL VERDICT" -> "RELEASE_CORRECTION_REQUIRED",
    listing three open non-human blockers (triage execution-path not green; migration clean-chain
    unproven via stale 20260927120000000; Phase 6 durable boundary unresolved, ADR 0021 decision
    and confidence semantics), and :172-181 leaving HUMAN_GOLDEN_REVIEW_REQUIRED,
    HUMAN_DECISION_REQUIRED and HUMAN_SECURITY_DECISION_REQUIRED all OPEN.
    The repository owner's own committed record states this tree is not in a mergeable state.

HIGH:

H1. Nine migrations are activated for the first time in this commit and none has ever executed.
    New dirs 20260925052148069, 20260925181113034, 20260927041236430, 20260928140116000,
    20260928233022000, 20260929123032034, 20260930022649505, 20261001025330452, 20261001205247600.
    Prior lanes understated this as one migration of 2 tables/8 indexes; it is 4 tables/17 indexes
    (20260925181113034/migration.sql:6,42,68,90).
    Mechanism verified against serverpod-3.4.13 source, not assumed:
      file_system.dart:28-43 — listVersions() lexically sorts migration DIRECTORIES and
        ignores migration_registry.txt entirely.
      migration_manager.dart:165-175 — _getVersionsToApply is POSITIONAL (indexOf + sublist).
      migration_manager.dart:194-205 — with no installed version, ONLY the latest
        definition.sql is applied; individual migration.sql files never run.
    Consequence: on a FRESH database the newly activated migration.sql never executes (no risk);
    on an EXISTING database the whole 9-migration chain runs at once, unproven.
    20260925181113034/migration.sql uses bare CREATE TABLE with no IF NOT EXISTS, and
    20260930022649505/migration.sql:6 does ALTER TABLE "defect" ADD COLUMN "productId" — so the
    chain is internally order-dependent and has zero execution history.

H2. Migration-lineage brick is still unremediated.
    migration_manager.dart:169-172 THROWS "DB has migration version <v> registered but it is not
    found in the project files" whenever a database's recorded version has no directory. The
    baseline deletes 20260921_defect_tables and had already deleted 20260927120000000 while a test
    DB still recorded it. Any database in that state cannot start the server at all.

H3. Every Postgres-backed durability claim is unverified.
    S2_NON_VISUAL_RELEASE_BLOCKER_CLOSURE.md:79-84: "Defect PostgreSQL tests: NOT RUN",
    "Product Registry PostgreSQL tests: NOT RUN", "Triage PostgreSQL tests: NOT RUN".
    Therefore docs/reports/control-plane-persistence-slice-report.md:274-288 (CAS & MULTI-REPLICA
    RACE claims) has no execution evidence.

MEDIUM:

M1. Migration-history rewrite with a factually incorrect rationale.
    apps/server/migrations/20260920232118956/migration.sql — a PRE-EXISTING, registry-listed
    migration was edited to add `IF NOT EXISTS`. The inserted comment asserts "A fresh database
    replays both migrations in order and would abort this whole transaction". That is FALSE for
    Serverpod 3.4.13 (a fresh DB applies only the latest definition.sql). Editing shipped migration
    files is hash-drift; shipping a false technical claim is worse.

M2. .bak file committed: apps/server/lib/src/endpoints/human_direction_endpoints.dart.bak (new).

M3. 51 KB operator status report committed at repository ROOT:
    S2_NON_VISUAL_RELEASE_BLOCKER_CLOSURE.md. Belongs under docs/reports/.

M4. No authentication on the entire control-plane API, with a dangling justification.
    apps/server/lib/server.dart:71-72 states the API is unauthenticated "for local / trusted-network
    use (documented under SECURITY ASSUMPTION in the control-plane persistence slice report)".
    "SECURITY ASSUMPTION" appears nowhere else; the cited report's section 22 documents data
    minimisation, not the auth assumption. An unauthenticated API that can create/execute jobs
    and resolve human decisions is a security-posture decision.

M5. framework-manifest.yaml records no baseline hashes — its own integrity mechanism is inert.
    framework-manifest.yaml:47-60 says local-modification state "is DERIVED by comparing an
    artifact's current hash against its recorded install/source baseline hash", yet every
    source_hash/install_hash is the literal "TBD". framework.version "0.1.0" also disagrees with
    AGENTS.md ("Framework version: TBD").

M6. Golden authority is not reconcilable. 54 golden PNGs exist under
    apps/control_plane/test/goldens/; S2_NON_VISUAL_RELEASE_BLOCKER_CLOSURE.md:187-216 claims
    "Total: 34 candidates", but only 18 of those names appear, leaving 36 committed goldens with
    no recorded VISUALLY_APPROVED / HUMAN_GOLDEN_REVIEW_REQUIRED status.

M7. .gitignore rule is inert for the debris it targets. .gitignore:15 adds `**/test/failures/`,
    but 80 failure-byproduct PNGs remain tracked and 46 are currently dirty — the churn the rule
    was written to stop is still happening. `git rm --cached` is required.

M8. Two unused_shown_name warnings at
    apps/server/lib/src/endpoints/product_registry_endpoints.dart:16-17.

LOW:

L1. packages/scheduler/lib/src/queue/job_queue.dart:180-192 — _promote returns a `Job` that was
    never persisted when its CAS is lost. Fails closed today via a subsequent saveJob, but hands
    back a phantom state. Return the re-read `current`.
L2. apps/control_plane/test/helpers/golden_tolerance.dart:43 — 0.5% threshold against a documented
    0.03-0.3% noise floor is only a ~1.7x margin.
L3. apps/control_plane/test/responsive/detail_widths_test.dart has 0 explicit assertions across 8
    generated cases; valid as a layout-overflow smoke test but cannot detect visual regressions.
L4. flutter build web warns "Expected to find fonts for (MaterialIcons,
    packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons)".
L5. apps/server/bin/onboard_shipit.dart:28 (password 'control_plane_test_pw'),
    apps/server/onboard_shipit_serverpod.dart:38 (password 'shipit') — committed dev credentials.
L6. AGENTS.md § Product-specific policy is still TBD while .github/workflows/ci.yaml +
    pubspec.yaml:32-40 define real, enforceable gates. The repo has no DECLARED gate contract,
    which is the root cause of B1/B2 going undetected.
L7. REFUTED, recorded so it is not re-raised: .agents/ vs .opencode/ adapter differences are the
    expected generator frontmatter transform (allowed-tools -> mode/permission), 9 diff lines per
    agent file, zero body drift. NOT adapter drift.

CORRECTION_REQUIRED: YES

HUMAN_DECISION_REQUIRED: YES

SAFE_PARALLEL_WORK:
  - Read-only investigation/design/QA-contract authoring in any lane, on any branch.
  - Read-only review lanes and documentation work under docs/ (not root).
  - Any lane whose OWNED_PATHS exclude apps/server, packages/**, and .github/**.
PROHIBITED_PARALLEL_WORK:
  - Any production-writing lane branching from 0d5d132 as BASE_SHA (B1/B2 make the tree CI-red).
  - Any lane touching apps/server/bin, apps/server/migrations, or .github/workflows.
  - Any lane touching packages/product_registry, agent_runtime, scheduler, execution_coordinator,
    control_plane_client, platform_contracts, or apps/server/lib/src/triage.
  - Any credential rotation or secret-store decision (B3 / M4) — human-owned.
  - Any merge to main or push.

MODEL_USED: opencode/space-bunny-free
ROUTING_CLASS_REQUESTED: PRECISION
```

## Explicit coverage statement (from the reviewer — NOT a line-by-line review)

**Covered:** full diff scope verification; complete migration-directory and
`migration_registry.txt` reconstruction; Serverpod 3.4.13 migration semantics verified against
the actual package source; credential sweep across all 585 files; all 8 gates re-run from a
fresh worktree; `apps/server` authz surface; job/workflow CAS correctness; all 26 control_plane
test files' assertion density; golden comparator and tolerance; the 3 runtime-config files;
adapter-drift check.

**NOT covered — no claim made:** ~157k lines in `apps/server` (151 files) beyond targeted
security/CAS/migration surfaces; `packages/product_registry`, `agent_runtime`, `scheduler`,
`control_plane_client`, `platform_contracts` beyond transition/guard types and CAS call sites;
the 6630 lines under `docs/`; the 8231 lines of framework adapters; `docker/`,
`infrastructure/`, `.github` beyond CI gate definitions. **No Postgres-backed test was executed
(no database available), so every durability claim remains unproven.** No `melos run
analyze`/`format` invoked directly, only their exact underlying per-package commands. No
visual/golden human review.

## Reviewer's scoping proposal

1. **Correction lane (no judgement needed):** delete the 4 dead scratch scripts (B1), run
   `dart format lib test` in the 8 packages (B2), remove the `.bak` and root report (M2, M3).
2. **Human decision (security):** the superuser credential in `test_pod.dart:16` — remove, and
   decide whether rotation is required (B3, M4).
3. **Human decision (architecture):** ADR 0021 — dedicated `DesignRemediationRequest` table vs
   `WorkItem` metadata, plus ADR 0020 confidence-semantics compliance.
4. **Then scope the real review** as bounded parallel lanes rather than one 204k-line pass.
5. **Before any of it:** establish a real Postgres and actually run the defect /
   product-registry / triage suites (H3).

> "I would rather hand you a small green tree plus five honest reviews than a large approved one."
