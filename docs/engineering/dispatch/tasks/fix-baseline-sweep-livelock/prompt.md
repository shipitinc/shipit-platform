# Dispatch — fix-baseline-sweep-livelock

```yaml
MANAGER: engineering-manager (shipit-platform baseline-production work item)
TASK_ID: fix-baseline-sweep-livelock
TASK_TYPE: implement
FEATURE: Stop the onboarding sweep from livelocking against itself in production
AREA: BaselineOnboardingSweep
WORKTREE: /private/tmp/shipit-sweepfix
BRANCH: fix/baseline-sweep-livelock
BASE_SHA: 65ab1df
OWNED_PATHS:
  - apps/server/lib/src/baseline/baseline_onboarding_sweep.dart
  - apps/server/lib/src/baseline/baseline_onboarding_sweep_test.dart
  - apps/server/lib/src/baseline/baseline_runtime.dart
READ_ONLY_PATHS:
  - apps/server/lib/src/credentials/repository_access_verifier.dart
  - apps/server/lib/src/credentials/repository_snapshot_acquirer.dart
  - apps/server/lib/src/credentials/credential_key_service.dart
  - packages/product_registry/lib/src/**
  - packages/scheduler/lib/**
  - AGENTS.md
PROHIBITED_PATHS:
  - apps/server/lib/src/credentials/**
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
  A 30-second sweep pass that takes longer than the tick cannot overlap itself, and a pass does
  not re-acquire the repository when the product already has a non-terminal onboarding job.
VALIDATION_COMMANDS:
  - dart analyze apps/server
  - dart test apps/server/lib/src/baseline
ROUTING_CLASS: PRECISION
```

---

## Observed in live QA — this is not theoretical

The worker was deployed to QA and the sweep runs. Over **41 passes** it produced:

```
22 × incidents: 1      19 × skipped: 1      enqueued: 0      dispatched: 0
baselines: 0
```

Almost every pass fails with:

```
Concurrent modification of cred-shipit-platform-1791635510472520 (expected version 41, actual 42)
  #0 PostgresProductRegistryStore.saveProductCredential (postgres_product_registry_store.dart:406)
  #1 ProductRegistryEngine.recordCredentialCheck        (product_registry_engine.dart:1181)
  #2 CredentialKeyService.verifyAccess                  (credential_key_service.dart:403)
  #3 RepositorySnapshotAcquirer.acquire                 (repository_snapshot_acquirer.dart:443)
  #4 SnapshotPinnedRevisionResolver.resolve             (baseline_onboarding_sweep.dart:58)
  #5 BaselineOnboardingSweep._consider                  (baseline_onboarding_sweep.dart:473)
  #6 BaselineOnboardingSweep.run                        (baseline_onboarding_sweep.dart:345)
```

## Two compounding causes

**1. Passes overlap.** The sweep runs on `Timer.periodic(30s)`. One pass performs a real SSH clone,
which takes ~60s. `dart:async`'s `Timer.periodic` does **not** await its callback, so pass N+1 starts
while pass N is mid-clone. An independent reviewer already flagged this as *"safe only by accident of
the claim CAS and the DB dedupe index"* — that accident has now failed.

**2. Every pass mutates the credential.** `resolve()` → `acquire()` → `verifyAccess()` →
`recordCredentialCheck()` → a **CAS write** to `product_credential`, bumping `version`. The credential
went from version 1 to **59** during the observation window while the product state never advanced.
The sweep writes on every pass purely to learn a revision string — and that write is exactly what
makes the next pass conflict.

So it is self-inflicted: each pass guarantees the next one fails, and no pass completes the enqueue.

## What to change

**A. Re-entrancy guard on the sweep.** A pass must not begin while one is running. This is the
direct fix for cause 1 and is cheap. Make it observable — a skipped tick should be visible in the
`baseline.sweep.completed` result, not silent.

**B. Do not re-acquire when there is nothing to acquire.** `resolve()` runs *before* the dedupe-key
lookup, so every pass pays a full clone even when the product already has a non-terminal job. Look
for an existing non-terminal onboarding job for the product **first**, and only resolve a revision when
one would actually be enqueued. Preserve the existing invariant the reason string already states: a
job must never be keyed on "whatever HEAD is now", because that is a new job every pass.

**C. Consider whether a read-only acquisition should write at all.** If `acquire()` is only reading,
recording an *access check* on every sweep pass is arguably wrong — but **do not change
`RepositoryAccessVerifier` or `CredentialKeyService`**; they are outside your ownership and their
writes may be load-bearing elsewhere. If you judge this to be the deeper fix, describe it and stop
rather than reaching outside `OWNED_PATHS`.

## Constraints

- **Do not weaken honesty of reporting.** The per-product incident guard is working exactly as
  designed — it says *"this product is untouched; the rest of the pass continued"* and keeps the pass
  alive. Keep that. A fix that makes failures quiet is worse than the livelock.
- **Do not paper over by shortening the interval or by swallowing the CAS conflict.** Retrying a
  conflicting write would convert a visible incident into a silent overwrite — and
  `recordCredentialCheck` exists to detect exactly that.
- Product-agnosticism holds: no product names, no defaults, no environment lookups.
- §12's residual hole stays at full strength; the host-key distinction (never pass the credential
  fingerprint as the host key; no `ssh-keyscan`-and-trust fallback) must not be touched.
- Do not weaken, delete or skip any test. Existing sweep tests must still pass — if one asserts the
  old ordering, that is a real behavioural change and you must justify it, not delete the test.
- ZERO Docker/Compose commands. The QA stack is LIVE and I am driving it. Never `make clean` /
  `make qa-down` / `make test-env-down` / `make e2e-down` / bare `docker compose … down -v`.
- Run `dart pub get` from the repo root first if you see phantom `uri_does_not_exist` errors
  (pub workspace).
- Commit your work on the branch.

## Tests you must add

1. **Overlap is impossible** — two concurrent `run()` calls result in one pass and one visible skip.
2. **No re-acquire when already queued** — with a non-terminal job present, `run()` performs **zero**
   acquisitions. Assert the acquisition count, not merely the absence of a new job.
3. **The invariant still holds** — when there is no job, a revision IS resolved and a job IS enqueued
   with a stable key, and a second pass with unchanged HEAD does not create a second job.
4. **Incidents remain loud** — a genuinely failing product still surfaces as an incident, and the rest
   of the pass still continues.

## Report

Report IMPLEMENTED with exact HEAD, changed files, how you prevented overlap, how you avoided the
redundant acquisition, whether you judged cause 2 to need a change outside your ownership (and what
you recommend), gates run, and anything you left.