# Dispatch — fix-generate-and-hostkey-config

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: fix-generate-and-hostkey-config
TASK_TYPE: correct
FEATURE: Make serverpod generate pass, and publish the host-key attestation values to the client
AREA: apps/server endpoint surface + docker client config template
WORKTREE: /private/tmp/shipit-impl-keys
BRANCH: impl/credential-key-service
BASE_SHA: 7d1b1b8abdf5cbfbb7b48dc9682baf3bfb99090c
OWNED_PATHS:
  - apps/server/lib/src/endpoints/credential_endpoints.dart
  - apps/server/lib/src/credentials/**
  - apps/server/test/**
  - docker/config.js.template
READ_ONLY_PATHS:
  - docker/compose.qa.yaml
  - docker/build-client.sh
  - apps/control_plane/lib/**
PROHIBITED_PATHS:
  - apps/server/migrations/**
  - apps/server/tool/**
  - apps/server/lib/src/generated/**
  - apps/server/lib/server.dart
  - apps/control_plane/**
  - packages/**
  - .github/**
  - docs/adr/**
  - .decisions/**
ACCEPTANCE_CRITERIA: >
  serverpod generate exits 0 and leaves apps/server/lib/src/generated/** byte-identical to base.
  The client runtime can read the host-key attestation values in the docker stack.
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - dart analyze apps/server
  - make test-integration
ROUTING_CLASS: STANDARD
```

---

## Context and why this is a correction to already-merged work

The credential key service merged to `main` as `c110aa2` after two review cycles. A client lane then
found a defect **no gate in those cycles could see**, because none of them ran the Serverpod code
generator.

**BLOCKER-1 — `serverpod generate` exits 1:**

```
CredentialEndpoints.recordCustodyPrecondition (:105)
  returns SecretProvider, not Future<...> or Stream<...>
```

Serverpod treats public methods on an `Endpoint` class as endpoints and requires that shape, so generation
fails. Client output still lands and is byte-identical run to run, and `apps/server/lib/src/generated/**`
came out byte-identical to base (hash `dd1483b0055…` before and after) — so nothing on disk is wrong. But
**any CI gate on generate's exit status will fail**, and a broken generator is a broken contract.

Note the method is a legitimate design artifact — the doc at `:253` explains it exists because the custody
precondition is not yet at process scope. The fix is to get it **out of Serverpod's endpoint surface**
without losing it: a Serverpod endpoint is discovered by public method shape, so consider whether it
belongs on a non-endpoint collaborator the endpoint holds, or a non-public method. **Choose deliberately
and justify it** — do not simply make it private if that breaks the collaborator design, and do not change
its return type to satisfy the generator, which would misrepresent what it is.

## BLOCKER-2 is NOT a defect — the existing decision already settled it

The client lane reported that `generate` resolves the repository reference first, so the product row must
exist before the mint, which is before the human can see the key, which is before Register — and called that
unreachable. **My dispatch wording caused this.** Decision `898b07d0` RESOLVED / OPTION_A already decided it:

> **Split identity from registration.** The key flow creates the Product row (state registered) plus the
> RepositoryReference as an explicit first step; "Register product" then commits credential verification.

So the ordering the lane observed **is the approved architecture**. The product row is created at
generate-time, and Register commits verification. Nothing to change. Recorded here so nobody "fixes" it
later by reordering.

## BLOCKER-3 — the host-key attestation values do not reach the client at runtime

`docker/config.js.template` publishes only `CONTROL_PLANE_API`, so the client reads **null** for the
host-key fingerprint and operator name. `--dart-define=SHIPIT_HOST_KEY_FINGERPRINT=…` works today with no
docker change, but **not** in the docker stack the human actually uses.

Make the two values reach the client in the docker path. Constraints:

- **Text-only edit to `docker/config.js.template`.** Read it as text; do not run the build.
- **ZERO mutating Docker/Compose commands.** Never `up`, `down`, `build`, `stop`, `restart`.
- **The QA stack is up and healthy on a stopgap run-mode override — do not disturb it.**
- These are **operator-asserted** values, not server-verified (open finding M-5). Whatever you do must not
  imply they are verified, and must not hardcode any value. Keep them substitutable from the environment.
- Match the template's existing substitution style rather than inventing a second mechanism.

## Also required

`make test-integration` is **known red and approved**: `+191 -1` against a base of `+170 -2`, sole failure
`dogfood_shipit_postgres_test.dart`, pre-existing, in `packages/**` you must not touch. Cause: a 43 098 ms
`git archive` walk against the 30 s `dart test` default. **It is load-sensitive** — an integrator measured
one fully green run, so do not conclude it is fixed, and do not report it as a regression.

Also run and report:

- `dart pub get` at the **REPO ROOT** first. Note the integrator found that a stale
  `.dart_tool/package_config.json` makes `dart analyze apps/server` fail with `uri_does_not_exist` for
  `ed25519_edwards` — a phantom failure worth knowing about.
- `dart format --output=none --set-exit-if-changed .`, `dart analyze apps/server` (exact output + exit code).
- **`serverpod generate` — this is the point of the lane.** Report its exact output and **exit status**.
  Then prove `apps/server/lib/src/generated/**` is byte-identical to base by hash. Do not commit any
  generated output.

## Proof required

1. `serverpod generate` exits **0**, and `apps/server/lib/src/generated/**` is byte-identical to base
   (hash before and after).
2. The host-key values are substitutable from the environment in the docker client path, with no value
   hardcoded, and nothing in the change implies they are server-verified.

## Constraints

- `apps/server/migrations/**`, `tool/**`, `lib/src/generated/**` and `lib/server.dart` stay untouched.
- Never print, log, or echo private key material.
- `make test-integration` is the only sanctioned database path and self-cleans. Never `make clean`,
  `make qa-down`, `make test-env-down`, `make e2e-down`, or a bare `down -v`.

## Other lanes

`impl/client-addproduct-keyflow` is **complete and awaiting review** at `2f6b78d`. It owns
`apps/control_plane/**` and `packages/control_plane_client/**` and is finished, so there is no write
overlap — but **do not run `serverpod generate`**, since that would rewrite the client package the reviewed
client lane produced.

Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`.

## Cleanup

Commit on your branch. **Do not push, merge, or touch `main`.**

Report `READY_FOR_FOCUSED_REVIEW: YES` and `FOCUSED_RE_REVIEW`. You cannot approve your own work.