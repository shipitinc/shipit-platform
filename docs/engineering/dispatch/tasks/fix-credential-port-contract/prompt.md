MANAGER: orchestrator-main
TASK_ID: fix-credential-port-contract
TASK_TYPE: correct
FEATURE: Unify the test DB credential contract, fix the port mismatch, and prove the migrations
AREA: apps/server/config, apps/server/docker-compose.yaml, .github/workflows/integration.yaml, apps/server/tool
WORKTREE: /private/tmp/shipit-cred-port
BRANCH: fix/credential-port-contract
BASE_SHA: 38768d0
OWNED_PATHS:
  - apps/server/config/**
  - apps/server/docker-compose.yaml
  - .github/workflows/integration.yaml
  - apps/server/tool/**
  - .github/workflows/*.md          # only if you add a comment header explaining the port/password contract
READ_ONLY_PATHS:
  - apps/server/pubspec.yaml
  - apps/server/bin/**
  - apps/server/lib/**
  - apps/server/test/**
  - packages/**
  - pubspec.yaml
  - docs/engineering/dispatch/tasks/review-baseline-0d5d132/report.md
  - .decisions/**
PROHIBITED_PATHS:
  - apps/server/migrations/**      # ABSOLUTELY — see "Do not touch migrations"
  - apps/control_plane/**
  - docker/**                      # the top-level stack; not this lane's contract
  - infrastructure/**
  - **/analysis_options.yaml
  - apps/server/config/passwords.yaml   # gitignored — create it locally, NEVER commit it
ACCEPTANCE_CRITERIA: >
  One authoritative, env-sourced value for the test DB password; one authoritative
  port; a comment at each site explaining the contract; and `dart test test/integration/`
  actually executed against a real Postgres — which closes the H1-H3 finding that no
  Postgres-backed suite has ever run.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-cred-port && dart analyze packages apps/server
  - cd /private/tmp/shipit-cred-port && melos run analyze
  - cd /private/tmp/shipit-cred-port && melos run format
  - cd /private/tmp/shipit-cred-port/apps/server && dart test test/integration/
  - cd /private/tmp/shipit-cred-port && flutter pub get
ROUTING_CLASS: PRECISION

## Isolation pre-flight

```bash
cd /private/tmp/shipit-cred-port
git branch --show-current    # must equal fix/credential-port-contract
git rev-parse --short HEAD   # must equal 38768d0
```

Do NOT touch the canonical checkout at /Users/alkebut/air/shipit-platform.

## Original request (verbatim)

> A single lane owning apps/server/config/**, apps/server/docker-compose.yaml,
> .github/workflows/integration.yaml, and tool/seed_overview_qa.sql, authorised to
> (a) resolve the 9090/9099 mismatch, (b) move all four sites to one env-sourced value,
> and (c) re-run `dart test test/integration/` against a real Postgres — which also
> finally closes the H1-H3 "no Postgres suite has ever run" finding.

## The problem, verified

`control_plane_test_pw` is the plaintext password for the `control_plane_test` Postgres DB
used by the Serverpod integration harness. It is committed in FOUR places that must agree:

| Site | Role |
|---|---|
| `apps/server/docker-compose.yaml:24` | `postgres_test` service `POSTGRES_PASSWORD`, published `"9090:5432"` |
| `apps/server/config/test.yaml:29,32` | Serverpod test-mode `database.port: 9099`, `database.password` |
| `.github/workflows/integration.yaml:14,23,24` | CI service `POSTGRES_PASSWORD`, `ports: [9090:5432]`, and a comment asserting test.yaml uses 9090 |
| `apps/server/tool/seed_overview_qa.sql:9` | operator `PGPASSWORD=... psql` inside a SQL comment |

`apps/server/config/passwords.yaml` is gitignored (`apps/server/.gitignore:15`) and holds
`test.database` plus the `shared.serviceSecret`, session pepper, and `development.database`.
CI materialises it from the base64 Actions secret `SERVERPOD_PASSWORDS_YAML`
(`.github/workflows/integration.yaml:44-57`).

**The port conflict.** `config/test.yaml` says `9099`. That is the ONLY `9099` in the repo.
Everything else says `9090`: compose, CI, `apps/server/bin/onboard_shipit.dart:25`,
`apps/server/bin/e2e_dev_server.dart:11`, `docs/reports/control-plane-persistence-slice-report.md:29`,
and two checkpoint docs. The CI comment at line 14 asserts the files agree. **They do not.**

**9090 is currently OCCUPIED on this machine by a different project:**
`partnerhub-test-db` (pgvector) holds `0.0.0.0:9090`. A prior agent session worked around the
clash with a throwaway override at
`/var/folders/1x/81jcxwg97dqczw4x548yfc940000gq/T/opencode/shipit-test-port-override.yaml`
(`postgres_test: ports: !override ["9099:5432"]`), which is how the running container
`control_plane-postgres_test-1` came to sit on 9099. **So naively pointing test.yaml at 9090
would collide with partnerhub.** Choose the port deliberately and document why.

## Do not touch migrations — and do not mutate the human's database

`apps/server/migrations/**` is `PROHIBITED`. Nine migrations
(`20260925052148069` … `20261001205247600`) are activated for the first time at this baseline and
have **never executed anywhere**. Finding H2 records a lineage brick: `migration_manager.dart:169-172`
throws when a database's recorded version has no directory, and `20260927120000000` was deleted
while a test DB still recorded it. Any database in that state cannot start the server.

**The lane's testing must be non-destructive:**

- The existing container `control_plane-postgres_test-1` on **9099** is the repository owner's
  LOCAL environment. It has 52 tables in `public` and **no `schema_version` table** — i.e.
  migrations have never been applied. **Do NOT run the integration suite against it.** Applying
  nine never-executed migrations to someone's working database is exactly the kind of
  destructive operation this framework reserves for a human.
- Instead, create **disposable** databases/containers that you own and destroy when finished.
  Test BOTH paths, because they behave differently:
  - **Fresh DB** (no tables): per `migration_manager.dart:194-205` only the latest
    `definition.sql` is applied, so individual `migration.sql` files never run.
  - **Existing DB with a recorded prior version**: the whole 9-migration chain runs at once,
    order-dependent, with zero execution history. This is the H1 blast radius.
- Report exactly which path you exercised and what happened. If migrations FAIL, that is a
  valuable finding — **report it and STOP. Do not edit migrations to make them pass.**

## Prerequisites you must satisfy

1. `apps/server/config/passwords.yaml` is absent in a fresh worktree. Without it Serverpod throws
   `PasswordMissingException` (`serverpod_shared/lib/src/config.dart:580-583`) during config load,
   aborting with exit 1 and no message. Create it locally from the canonical checkout's copy
   (`/Users/alkebut/air/shipit-platform/apps/server/config/passwords.yaml`) — it is gitignored, so
   it will never be committed. **Verify with `git check-ignore` and confirm it never appears in
   `git status`.**
2. `flutter pub get` / `melos bootstrap` at the worktree root before anything else.
3. Docker is running. `pgvector/pgvector:pg16` is the image both compose files use.

## Tasks

**(a) One env-sourced password value.** Replace all four committed literals with a single
documented source of truth. Follow the convention already established at
`apps/server/bin/onboard_shipit_dev.dart`, which the earlier correction lane fixed to
`_env('SERVERPOD_DATABASE_PASSWORD', 'shipit')`. Decide and document which of these is
authoritative:
- `config/passwords.yaml` `test.database` (gitignored, Serverpod's own secrets file), or
- an env var read by compose and by CI, with `passwords.yaml` generated from it.
Whatever you choose, `docker-compose.yaml`, `test.yaml`, `integration.yaml` and the SQL comment
must all resolve to the SAME value, and it must be overridable by env for CI. **If
`config/test.yaml` keeps a literal, add a comment stating that it must equal
`docker-compose.yaml` and why Serverpod's test config cannot read an env var.**

**(b) One port.** Resolve 9090 vs 9099 deliberately. Requirements:
- `config/test.yaml`, `apps/server/docker-compose.yaml` and `.github/workflows/integration.yaml`
  must all name the same port.
- The CI comment at line 13-16 must become true.
- The choice must not collide with `partnerhub-test-db` on 9090 on this machine. If you keep 9099,
  say so explicitly and explain that 9090 is taken by another project. If you move CI to 9099, do
  the same in reverse.
- Document the port's provenance in a comment at each site.

**(c) Actually run the integration suite.** `cd apps/server && dart test test/integration/`
against a disposable real Postgres. This is the point of the lane — it has never been done.
Report the exact pass/fail count and the exact test files run.

**(d) Remove the stale override reference.** Note in a comment that the throwaway
`shipit-test-port-override.yaml` is superseded by whatever you decide, so nobody re-derives the
9099 value from it again.

## Acceptance criteria

- [ ] `config/test.yaml`, `apps/server/docker-compose.yaml` and `.github/workflows/integration.yaml` all name ONE port, with a comment at each explaining the contract
- [ ] The port does not collide with `partnerhub-test-db` on 9090
- [ ] The CI comment at `integration.yaml:13-16` is factually true
- [ ] `control_plane_test_pw` no longer appears as a committed literal in any of the four sites; the value is env-sourced and consistent
- [ ] `apps/server/tool/seed_overview_qa.sql:9` instruction still works with the new contract
- [ ] `config/passwords.yaml` exists locally, is gitignored, and is NOT in `git status` or any commit
- [ ] `dart test test/integration/` was EXECUTED against a disposable real Postgres, with the exact count reported
- [ ] The repository owner's existing 9099 database is untouched — verify and report
- [ ] Both the fresh-DB and existing-DB migration paths were exercised, or the one you could not do is explained
- [ ] `dart analyze packages apps/server` exits 0; `melos run analyze` and `melos run format` SUCCESS
- [ ] `git diff 38768d0..HEAD --stat` touches ONLY your OWNED_PATHS
- [ ] Every commit is NEW on top of `38768d0` — never amend, rebase or squash

## Required validation commands

- [ ] `cd /private/tmp/shipit-cred-port && git check-ignore -v apps/server/config/passwords.yaml` — must be ignored
- [ ] `git status --porcelain` — must never list `passwords.yaml`
- [ ] `grep -rn "control_plane_test_pw" apps/server/config apps/server/docker-compose.yaml .github apps/server/tool` — must return nothing
- [ ] `grep -rn "9090\|9099" apps/server/config apps/server/docker-compose.yaml .github/workflows/integration.yaml` — report every hit and confirm consistency
- [ ] `dart analyze packages apps/server` → exit 0
- [ ] `melos run analyze` → SUCCESS; `melos run format` → SUCCESS
- [ ] `cd apps/server && dart test test/integration/` → report exact counts
- [ ] Confirm `partnerhub-test-db` still owns 9090 and you did not disturb it: `docker ps --format '{{.Names}}\t{{.Ports}}'`
- [ ] Confirm `control_plane-postgres_test-1` on 9099 still has its original 52 tables and no `schema_version`
- [ ] `git diff 38768d0..HEAD --stat` and `git log --oneline 38768d0..HEAD`
- [ ] `git diff 38768d0..HEAD -- '*migrations*' 'apps/control_plane/**' 'docker/**'` → must be EMPTY

## Hard rules for the child

- **`apps/server/migrations/**` is PROHIBITED.** If migrations fail, report the failure with
  evidence and STOP. Do not edit, reorder, rename or delete a migration.
- **Never mutate the repository owner's `control_plane-postgres_test-1` database on 9099**, and
  never stop or remove that container or the `partnerhub-*` containers. Use disposable databases
  you create, and clean them up.
- Never commit `apps/server/config/passwords.yaml` or any credential.
- Never weaken CI, a test, or an assertion to reach green. Do not add `continue-on-error`.
- Do not push, merge, or touch `main`. Commit on `fix/credential-port-contract` only.
- Retain your worktree; the Manager needs it for re-review. Clean up any container or database
  you created, and report any PIDs or ports you left running.
- Stop and report rather than resolving a product, architecture, security, infrastructure,
  destructive-operation, or deployment-authority question yourself; it is a
  `HUMAN_DECISION_REQUIRED` blocker.
- Every result carries exact repository/worktree/HEAD provenance.

## Report format

Return a report conforming to `subtask-report.md`. Your `RESULT:` must be verbatim one of your
own agent file's tokens from `.agents/agents/correction-implementer.md`. Report separately and
prominently: the integration test result, what the nine migrations did when they ran, whether
H1's blast radius is now proven or disproven, and whether the human's 9099 database is intact.
