MANAGER: orchestrator-main
TASK_ID: fix-design-triggers
TASK_TYPE: correct
FEATURE: Restore design-revision immutability triggers on fresh databases; enforce test-resource cleanup
AREA: apps/server migrations/schema bootstrap, CI, test tooling, AGENTS.md policy
WORKTREE: /private/tmp/shipit-triggers
BRANCH: fix/design-triggers-and-cleanup
BASE_SHA: 60c8136
OWNED_PATHS:
  - apps/server/migrations/**
  - apps/server/tool/**
  - .github/workflows/**
  - docker/compose.test.yaml
  - Makefile
  - AGENTS.md
  - apps/server/config/**
READ_ONLY_PATHS:
  - apps/server/pubspec.yaml
  - apps/server/lib/**
  - apps/server/test/**
  - apps/server/bin/**
  - apps/control_plane/**
  - packages/**
  - docs/engineering/dispatch/tasks/fix-credential-port-contract/report.md
PROHIBITED_PATHS:
  - apps/control_plane/lib/**          # format-only discipline; no changes needed
  - packages/**/lib/**
  - infrastructure/**
  - .decisions/**
  - docs/engineering/**
ACCEPTANCE_CRITERIA: >
  A freshly created database enforces the same design-revision immutability and
  review-independence rules as a chain-migrated one — proven by probe, not assumed —
  and the rule cannot silently regress.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-triggers && melos run analyze
  - cd /private/tmp/shipit-triggers && melos run format
  - cd /private/tmp/shipit-triggers/apps/server && dart test test/integration/
  - fresh-DB parity probe (specified below) — MUST show immutability enforced
ROUTING_CLASS: PRECISION

## Isolation pre-flight

```bash
cd /private/tmp/shipit-triggers
git branch --show-current    # must equal fix/design-triggers-and-cleanup
git rev-parse --short HEAD   # must equal 60c8136
```
Do NOT touch /Users/alkebut/air/shipit-platform.

## Original request (verbatim)

> 2. Add the triggers

and, regarding test hygiene:

> 1. Yes delete that. In the future I'd like any test db/containers to get cleaned up
>    after their done running their tests

## The defect you are fixing

`fix-credential-port-contract` proved H1. Both migration paths yield 52 tables, but the
schemas are NOT the same:

| | fresh DB | chain-migrated DB |
|---|---|---|
| `trigger_design_revision_immutability` | **absent** | present |
| `trigger_desing_review_independence` / `trigger_design_review_independence` | **absent** | present |
| `design_revision_approved_unique_per_work_item` | **absent** | present |

The triggers exist only in `apps/server/migrations/20260920232118956/migration.sql`, which the
model-driven generator cannot express, so no generated `definition.sql` ever carried them.
Serverpod applies ONLY the latest `definition.sql` on a fresh database
(`migration_manager.dart:194-205`), so **every fresh database — CI included — lacks them.**

Direct probe by that lane, tampering with an APPROVED `design_revision`:

- fresh DB → `UPDATE 1`, value became `TAMPERED` — **silently mutated**
- chain DB → `ERROR: Cannot modify approved design revision`

Manager-verified: `grep -rl trigger_design_revision_immutability apps/server/migrations/`
returns `20260920232118956/migration.sql` only; `grep -rl trigger_design
apps/server/migrations/*/definition.sql` returns nothing.

Also: `melos run verify:schema-deviations` passes while this divergence is live, because its
guard checks three unrelated patterns.

## Your task, part 1 — make fresh databases safe

The hard constraint: **you cannot fix this by hand-editing a generated `definition.sql`.**
Serverpod regenerates it from the Dart models on the next `serverpod create-migration`, so any
hand edit is silently lost — which is precisely how this bug arose. Find a mechanism that
survives regeneration. Investigate and choose deliberately among options such as:

- a checked-in, hand-maintained SQL asset applied as a post-migration bootstrap step, wired into
  both CI and the local test path, where Serverpod's own lifecycle cannot overwrite it;
- making the `verify:schema-deviations` guard actually detect fresh-vs-chain divergence;
- any Serverpod-supported extension point you can find in the pinned 3.4.13 source — **verify it
  against the package source, do not assume it exists.**

Whichever you choose, it must be **idempotent** (`IF NOT EXISTS` / `CREATE OR REPLACE`) and must
fail loudly if it does not apply.

Requirements:
- A freshly created database enforces the same rules as a chain-migrated one.
- The mechanism survives `serverpod create-migration` regenerating `definition.sql`. **Prove
  this** — regenerate or simulate regeneration and show the triggers survive.
- The existing `verify:schema-deviations` guard gap is closed, or a new guard covers it, so this
  class of drift fails loudly instead of passing silently.

### Mandatory probe — this is the acceptance evidence

You must demonstrate, on a **disposable** database you create and destroy:

1. Create a fresh DB via the normal path.
2. Confirm the three objects above now EXIST.
3. Tamper with an APPROVED `design_revision` → it must be **REJECTED**.
4. Create a second fresh DB, chain-migrate it, and confirm behaviour matches.
5. Report both results side by side.

If you cannot achieve this, report `RESULT: CORRECTION_BLOCKED` with the evidence and a concrete
proposal. Do NOT fake it, and do NOT weaken the probe.

## Your task, part 2 — enforce test-resource cleanup

**Standing rule, human-mandated: every test database, container, volume and compose project
created for testing must be removed when the run finishes — success, failure, or interrupt.**

Implement it so it is enforced by tooling, not by discipline:

- Audit every path that creates test infrastructure: `docker/compose.test.yaml`,
  `docker/compose.e2e.yaml`, `docker/run-e2e-tests.sh`, `Makefile` (`test-env-*`, `e2e-*`), and
  `.github/workflows/*`. Find any that leaks a container, volume, or project on failure.
- `docker compose run --rm` / `--abort-on-container-exit` semantics, `trap`-based cleanup in
  shell, and `--exit-code-from` are all in scope. Choose per site what is correct.
- Prefer compose `down -v` (removes volumes) over `stop`, and make it unconditional.
- If a GitHub Actions job needs `if: always()` cleanup steps, add them.

Then **record the rule durably** in `AGENTS.md` under § Product-specific policy, which is
currently entirely `TBD`. Add a short "Test resource hygiene" subsection stating the rule. Do not
attempt to fill in the rest of § Product-specific policy — that is a separate decision.

## Absolute prohibitions

- **NEVER mutate the repository owner's environment.** `control_plane-postgres_test-1` on 9099 is
  theirs (52 tables, 552 rows). Never run tests against it, never create databases inside it,
  never stop or remove it or any `partnerhub-*` container. Use your own disposable containers
  with unique names, and remove every one of them plus its volumes.
- Never weaken or skip a test, never add `continue-on-error`, never delete an assertion.
- Never commit `apps/server/config/passwords.yaml` or any credential.
- Do not push, merge, or touch `main`. Commit on `fix/design-triggers-and-cleanup` only.
- Never amend, rebase or squash `60c8136`.
- Retain your worktree; the Manager needs it for re-review.

## Acceptance criteria

- [ ] Fresh-DB probe: the three objects exist AND tampering with an approved `design_revision` is REJECTED
- [ ] Chain-migrated DB probe: identical enforcement
- [ ] Mechanism proven to survive `definition.sql` regeneration
- [ ] A guard now fails loudly on fresh-vs-chain divergence
- [ ] Every test-infra path audited; no container/volume/project leak on failure or interrupt
- [ ] Cleanup rule recorded in `AGENTS.md` § Product-specific policy
- [ ] `melos run analyze` and `melos run format` SUCCESS
- [ ] `dart test test/integration/` run and reported (157/158 expected — the 1 failure is the
      pre-existing `dogfood_shipit_postgres_test.dart:87` `Directory('.git')` assertion, which is
      environmental in a linked worktree; confirm it is that same one and no others)
- [ ] Zero disposable containers, volumes, or databases left behind — list what you created and
      prove each is gone
- [ ] `git diff 60c8136..HEAD --stat` touches only OWNED_PATHS

## Hard rules for the child

- Stop and report rather than resolving a product, architecture, security, infrastructure,
  destructive-operation, or deployment-authority question yourself; it is a
  `HUMAN_DECISION_REQUIRED` blocker. In particular: if the only robust fix requires changing
  Serverpod's generated-schema model or the migration history's recorded hashes, STOP — that is
  an architecture decision, not a correction.
- Report every container, volume, database and port you create, and prove each is cleaned up.
- Every result carries exact repository/worktree/HEAD provenance.

## Report format

Return a report conforming to `subtask-report.md`. Your `RESULT:` must be verbatim from
`.agents/agents/correction-implementer.md`. Report prominently: the before/after probe results,
the mechanism you chose and why it survives regeneration, the cleanup changes per site, and your
complete create/cleanup ledger.
