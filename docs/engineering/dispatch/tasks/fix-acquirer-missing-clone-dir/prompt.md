# Dispatch — fix-acquirer-missing-clone-dir

```yaml
MANAGER: engineering-manager (shipit-platform baseline-production work item)
TASK_ID: fix-acquirer-missing-clone-dir
TASK_TYPE: implement
FEATURE: The snapshot materializer runs git -C against a directory that does not exist
AREA: RepositorySnapshotAcquirer / SshPinnedSnapshotMaterializer
WORKTREE: /private/tmp/shipit-clonefix
BRANCH: fix/acquirer-missing-clone-dir
BASE_SHA: 27c3e0e
OWNED_PATHS:
  - apps/server/lib/src/credentials/repository_snapshot_acquirer.dart
  - apps/server/lib/src/credentials/repository_snapshot_acquirer_test.dart
  - apps/server/lib/src/baseline/repository_snapshot_acquirer_test.dart
READ_ONLY_PATHS:
  - apps/server/lib/src/credentials/repository_access_verifier.dart
  - apps/server/lib/src/baseline/**
  - apps/server/lib/src/credentials/credential_key_service.dart
PROHIBITED_PATHS:
  - apps/server/lib/src/baseline/baseline_onboarding_sweep.dart
  - apps/server/lib/src/endpoints/**
  - apps/server/lib/src/services/**
  - apps/server/lib/src/triage/**
  - apps/server/lib/src/generated/**
  - apps/server/test/**
  - packages/**
  - apps/control_plane/**
  - docker/**
  - .github/**
  - .decisions/**
  - AGENTS.md
  - docs/**
ACCEPTANCE_CRITERIA: >
  A real acquisition against a real remote succeeds from a fresh scratch tree, and the fix is
  covered by a test that fails against the current code without running a real clone.
VALIDATION_COMMANDS:
  - dart analyze apps/server
  - dart test apps/server/lib/src/baseline
ROUTING_CLASS: PRECISION
```

---

## Root cause — confirmed by reproduction against the real remote

The worker is deployed to QA and the sweep now runs cleanly (`incidents: 0, overlappedPasses: 0`),
but it has **never enqueued a job**. Every pass records `skipped: 1` and the credential `version`
climbs (360+) because the access check runs and then the acquisition dies.

`SshPinnedSnapshotMaterializer.materialize` (`repository_snapshot_acquirer.dart:545,578`) does:

```dart
final clonePath = '${scratch.path}/checkout';
...
await _git(remote, wrapperPath, clonePath, ['init', '--quiet']);
```

and `_git` (`:736-739`) spawns:

```dart
['--no-pager', '-C', clonePath, ...gitArguments]
```

`git -C <dir>` **changes directory before the subcommand runs**, so the directory must already exist.
`scratch` was just created by `createTempSync` and `checkout` is never created, so the **first** git
call fails. That is `BaselineSnapshotMaterializationException`, which `SnapshotPinnedRevisionResolver`
catches and turns into `null` — so the sweep reports *unresolvable revision* and never enqueues.

Reproduced verbatim inside the QA server container against the real GitHub remote:

```
A) git -C "$S/checkout" init --quiet        # dir absent — what the materializer does today
   fatal: cannot change to '/tmp/tmp.aSEAIxiYo0/checkout': No such file or directory

B) mkdir -p "$S/checkout" then the identical sequence
   init OK
   fetch OK
   resolved revision: f58d6fb129c1d4265ada5af9dc359eb5ac27a9a2
```

So **everything else about this path is proven working** — the bind-mounted custody directory, the
deploy key, the host-key confirmation, the SSH wrapper, the shallow fetch. Only this one thing fails.

## Why no test caught it

Every test drives an in-memory or fake git. The `kRepositoryHeadRef` carve-out added by the wire-up
lane (`65ab1df`) is what introduced the `init` → `remote add` → `fetch` → `checkout` sequence against
`clonePath`, and its tests all substitute a fake for the process layer.

## What to do

1. **Create the working tree before the first `_git` call**, with the same strict mode the rest of this
   class already applies (`PosixFileModes.applyStrict`). Do not weaken it to `createSync` default modes
   — this class is deliberate about 0700/0600 and a clone tree is private material in transit.

2. **Check whether `RepositoryAccessVerifier` has the same defect.** It is `READ_ONLY` to you: report
   it with `file:line` and a reproduction, do **not** edit it. (It appears not to — `verifyAccess`
   succeeds against the live remote — but confirm rather than assume.)

3. **Add a test that fails against the current code without running a real clone.** Assert the
   precondition directly: that the directory exists before the first git invocation, or that the
   spawn arguments reference an existing path. A test that shells out to GitHub is not acceptable here.

4. Confirm the fix against the **real** remote from inside the QA container before reporting — but
   read-only: a manual clone into a temp dir you remove yourself. **Zero Docker/Compose commands.**

## Constraints

- **This is a one-line-class fix. Do not refactor.** The materializer duplicates
  `RepositoryAccessVerifier`'s hardening deliberately (recorded as B7 — duplication was preferred over
  an acquisition with no host-key check, which would be the ADR 0018 A2 gap). Preserve that shape.
- Host-key distinction is an ADR 0018 A2 invariant and must remain byte-identical: never pass the
  credential fingerprint as the host key, and **no `ssh-keyscan`-and-trust fallback** — the scan only
  ever *checks* an already-settled value.
- Credential handled by name only; the snapshot must carry no key, no fingerprint and no reference name.
- §12's residual hole stays at full strength — this acquisition is not independence.
- Do not weaken, delete or skip any test. Do not resolve a Human Decision.
- ZERO Docker/Compose commands. The QA stack is LIVE and I am driving it. Never `make clean` /
  `make qa-down` / `make test-env-down` / `make e2e-down` / bare `docker compose … down -v`.
- Run `dart pub get` from the repo root first if you see phantom `uri_does_not_exist` errors.
- Commit your work on the branch.

## Report

Report IMPLEMENTED with exact HEAD, the diff, the new test and what it asserts, your finding on
whether `RepositoryAccessVerifier` shares the defect (with `file:line`), the read-only real-remote
verification and how you cleaned up after it, and gate results.