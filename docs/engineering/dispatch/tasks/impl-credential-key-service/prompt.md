# Dispatch — impl-credential-key-service

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: impl-credential-key-service
TASK_TYPE: implement
FEATURE: Server-side deploy-key generation with external custody, plus access verification
AREA: apps/server — credential endpoint, key service, SecretProvider
WORKTREE: /private/tmp/shipit-impl-keys
BRANCH: impl/credential-key-service
BASE_SHA: 8725b65
OWNED_PATHS:
  - apps/server/lib/src/endpoints/**
  - apps/server/lib/src/credentials/**
  - apps/server/lib/src/generated/**
  - apps/server/pubspec.yaml
  - apps/server/pubspec.lock
  - apps/server/test/**
  - apps/server/migrations/**
READ_ONLY_PATHS:
  - apps/control_plane/**
  - docs/adr/0018-per-product-git-credentials.md
  - .decisions/b869ec24-236e-4e9c-8703-70656fa368c4.yaml
  - .decisions/9417f8bf-73b8-4827-9515-bdfe92e5a9d5.yaml
  - .decisions/79e860e2-4edf-4510-8d5f-435460255848.yaml
  - docker/compose.qa.yaml
PROHIBITED_PATHS:
  - apps/control_plane/lib/**
  - apps/control_plane/test/**
  - packages/**
  - docker/**
  - .github/**
  - docs/adr/**
  - .decisions/**
  - docs/deployment/**
ACCEPTANCE_CRITERIA: >
  A real ed25519 keypair is generated server-side; the private half is placed in an external
  secret manager and is NEVER returned to the client, logged, or written to the database. A
  credential endpoint returns only public half, fingerprint, algorithm and a reference. Access
  verification performs a real SSH clone using the generated key. The credential row persists the
  reference and never key bytes.
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - dart analyze apps/server
  - make test-integration
ROUTING_CLASS: PRECISION
```

---

## Why this lane exists

The Add Product Register button is permanently disabled. Root causes, confirmed in code:

1. `add_product_page.dart:233-236` — `canRegister` requires `accessStatus == AccessStatus.verified`, and
   `AccessStatus.verified` is **read 9 times and written zero times** anywhere in the client.
2. `_generateMockKeyPair` (`add_product_page.dart:126-138`) makes 32 random bytes and formats them
   `ssh-ed25519 <base64> shipit+<product>`. **That is not an ed25519 key** — the encoding is wrong, so SSH
   would reject it. It exists only to satisfy a non-null check.
3. `SecretProvider` is **0 files** repo-wide.
4. **No credential endpoint exists** on the server.

You are building the missing server half. The client is a separate lane; do not touch it.

## Authority — already decided, do not re-litigate

- `b869ec24` RESOLVED / **OPTION_A — server-side key service**. Generation and storage are server-side;
  SHIP IT pushes from its own backend, never from the browser.
- `9417f8bf` RESOLVED / **OPTION_C — A3 custody is an external secret manager.** SHIP IT holds a
  **reference, never key bytes**.
- ADR 0018 §A2 (`:226-240`) is the governing clause. Quote it in your report; it is the standard you are
  building to.

### The exact custody rule you must not violate

> The private half is **never displayed, logged, persisted to the durable record, or transmitted**.

The durable record is the database. A private half in a database column, a Serverpod `definition.sql`,
a log line, a thrown exception message, or any endpoint response is a defect. The reference — a secret
path or ARN — is what you persist.

## SecretProvider: two adapters, and the fallback is a recorded precondition

ADR 0018 `:232-234` explicitly provides for this and forbids doing it silently:

> The local secret store (A1) and host keychain (A4) remain the documented **fallback** when no secret
> manager is reachable in the target topology. **Fallback selection is a recorded precondition, not a
> silent default.**

So build:

1. **A GCP Secret Manager adapter** for production/staging. The infrastructure already exists —
   `infrastructure/modules/secrets/main.tf` creates `google_secret_manager_secret` resources for
   `github_token`, `penpot_token`, `serverpod_signing_key`. Read it for the project/region conventions.
2. **A local fallback adapter** for the local QA stack, which has no GCP credentials. It must be
   **explicitly selected by configuration**, and its selection must be **logged at startup** so QA never
   silently runs on a fallback the operator did not choose.

ADR 0018 §A4 (`:511`) records that the secret manager's reachability **has never been runtime-probed**.
Your local fallback is what makes the local path work; do not claim the GCP adapter is verified.

## Endpoint contract

Expose via a new `CredentialEndpoints` (or extend `ProductRegistryEndpoints` if that is genuinely the
better home — justify it if you do).

- **Generate.** Takes product/repository identity, generates a real ed25519 keypair, stores the private
  half via `SecretProvider`, persists a credential row, returns **only**: public half, fingerprint,
  algorithm, reference, status. Never the private half.
- **Verify access.** Performs a **real** clone of the repository using the generated key and reports
  whether the clone succeeded. This is what lets the client set `accessStatus = verified`.

### On the verification mechanism — a real judgment call, make it explicitly

Proving access requires an SSH client using the private half. Weigh and choose deliberately, then
justify the choice in your report:

- Shelling out to `git` with a `GIT_SSH_COMMAND` identity file means writing the private half to a
  **temporary local file**. That is not the durable record, so it does not breach the rule — but it must be
  created with owner-only permissions, deleted in a `finally`/unwind path even on failure, never logged,
  and never left behind. If you choose this, prove the cleanup happens on the failure path.
- A pure-Dart SSH library avoids the temp file entirely but adds a dependency and its own risk surface.

**Whatever you choose, the private half must not survive the call.**

## Persistence

The credential row stores: credential id, product id, repository id, reference name, fingerprint,
algorithm, status, and access-verification timestamps. **No key bytes, in any column.** If the existing
schema lacks a reference column, add it via a migration — and note that `apps/server/migrations/**` is in
your `OWNED_PATHS`, but the hand-maintained objects there are load-bearing: read
`apps/server/tool/schema_bootstrap.dart`'s header before you touch anything, and run
`bash apps/server/tool/verify_schema_bootstrap.sh` after.

## Dependencies

`apps/server/pubspec.yaml` has **no** crypto or SSH package today. Add what you need (`ed25519_edwards` /
`cryptography` / `ssh2` as appropriate) and justify the choice. Keep the dependency count minimal.

## Hard constraints

- **`docker/**` is PROHIBITED.** The QA stack is up and healthy on a **stopgap** run-mode override that
  will not survive `make qa-up`; do not disturb it. Read compose files as text.
- **ZERO mutating Docker/Compose commands.** `make test-integration` is the **only** sanctioned way to get
  a real database (disposable Postgres under compose project `shipit_integration_<pid>`, self-cleaning).
  Never `make clean`, `make test-env-down`, `make e2e-down`, or a bare `down -v`. This repository has
  already lost a QA database irrecoverably to a `down -v`.
- **Never print, log, or echo the private half** — not in a debug statement, not in a test failure
  message, not in your report. A test that fails while including key material is a defect.
- No client changes. No `docs/adr/**`. No `.decisions/**`.

## Gates — verbatim output

- `dart pub get` at the **REPO ROOT** first if `.dart_tool/` is missing.
- `dart format --output=none --set-exit-if-changed .` → expect `(0 changed)`
- `dart analyze apps/server` → **must be clean.** Note: `AGENTS.md` records that this command historically
  exits non-zero on pre-existing infos/warnings. **Report the exact output and the exit code, and
  distinguish errors from pre-existing infos.** Do not suppress or weaken anything to make it pass.
- `make test-integration` → your integration tests must pass. This is the only sanctioned database path.

## Tests you must write and prove

1. A real generated keypair is a **valid ed25519 public key** — assert on structure/encoding, and
   preferably verify it parses as SSH.
2. **The private half never leaves the server.** Assert the endpoint response contains no private
   material, and that the persisted row has no key bytes.
3. The local fallback is **selected explicitly** and its selection is logged; an unconfigured environment
   fails closed rather than silently defaulting.
4. `SecretProvider` round-trips the private half, and a failure to store it **fails the generate call**
   rather than returning a key it cannot keep.

## Other lanes

- The client lane will touch `apps/control_plane/lib/**` — no overlap with you.
- Manager holds `LANES.md` / `WORK_STATE.md` / `.decisions/**`.

Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`.

## Cleanup

Commit in logical commits. **Do not push, do not merge, do not touch `main`.** `make test-integration`
cleans up its own database; confirm it did.

## You cannot approve this

This is a security boundary. Report `READY_FOR_INDEPENDENT_REVIEW: YES`; an independent
`engineering-reviewer` will verify it, and the review must be able to confirm the private half never
reaches a response, a log, or the database.