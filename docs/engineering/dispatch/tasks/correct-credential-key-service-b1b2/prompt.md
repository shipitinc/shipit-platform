# Dispatch — correct-credential-key-service-b1b2

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: correct-credential-key-service-b1b2
TASK_TYPE: correct
FEATURE: Close the two custody leaks found in independent review of the key service
AREA: apps/server/lib/src/credentials/** + the credential endpoint
WORKTREE: /private/tmp/shipit-impl-keys
BRANCH: impl/credential-key-service
BASE_SHA: 315e9ca21ea6b33cfbaa9f0411db69951867e16e
OWNED_PATHS:
  - apps/server/lib/src/credentials/**
  - apps/server/lib/src/endpoints/**
  - apps/server/test/**
READ_ONLY_PATHS:
  - apps/server/lib/src/generated/**
  - apps/server/migrations/**
  - docs/adr/0018-per-product-git-credentials.md
PROHIBITED_PATHS:
  - apps/control_plane/**
  - packages/**
  - docker/**
  - .github/**
  - docs/adr/**
  - .decisions/**
  - apps/server/migrations/**
  - apps/server/lib/src/generated/**
ACCEPTANCE_CRITERIA: >
  No code path can place private-key material into an exception message, a log, or a response.
  The private half is not exposed as a public Uint8List or String. A timeout cannot leave a git
  or ssh child alive holding the temp identity file.
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - dart analyze apps/server
  - make test-integration
ROUTING_CLASS: PRECISION
```

---

## Read first

- The review that blocks you: `docs/engineering/dispatch/tasks/review-impl-credential-key-service/report.md`
- Your own report: `docs/engineering/dispatch/tasks/impl-credential-key-service/report.md`

`RESULT: DO_NOT_MERGE`, `CORRECTION_REQUIRED: YES`, `HUMAN_DECISION_REQUIRED: NO`. You are continuing in
the same worktree and branch. **Add new commits on top of `315e9ca`.** Do not rewrite the three existing
commits — the review's provenance depends on them.

Your architecture was accepted: the `.bytes` audit's three sites were judged justified, `SecretBytes`
redaction was independently confirmed sound, key generation is genuinely real ED25519 (`ssh-keygen -lf`
reports `(ED25519)` and the fingerprint matches), the response type `MintedCredential` has no private
field, persistence was confirmed against live DDL, fail-closed is genuinely proven, and **the cleanup
proof was accepted as sound** — the reviewer agreed your PATH-pinned `git` stub cannot fake it because
cleanup is done by the verifier independently of `git`.

## B-1 — BLOCKER: the GCP adapter can leak the private half into the database

`gcp_secret_manager_secret_provider.dart:161` (`jsonDecode`) and `:172` (`base64.decode`) are unguarded.
A `FormatException` from either carries the offending input in its message — which for `base64.decode` is
**base64 private-key material**. `credential_endpoints.dart:162` logs `error.toString()`, and the
Serverpod structured logger persists that to a **session log in Postgres**.

So: a malformed secret at rest becomes private-key material in the durable record. This is precisely the
invariant ADR 0018 §A2 forbids, and it defeats your own `SecretBytes` design — which protects *values you
hold*, not *values a third-party exception captured for you*.

**This is the finding that matters most.** The reviewer noted `.bytes` is too narrow to discharge the claim
it was used for: it cannot see `String` projections (B-2) or third-party exceptions (B-1). Close both
classes, not just these two lines — audit every decode/parse/unwrap in the provider and at the endpoint
boundary, and make it structurally impossible for an exception message to carry material. A test that
feeds malformed material at each site and asserts the resulting log output contains none is the proof.

## B-2 — BLOCKER: custody type discipline is not end-to-end

`ssh_keypair.dart:107` exposes the seed as a public `Uint8List`; `:153` exposes the private half as a
public `String`; and the class doc at `:50` **asserts the opposite of what the code does**. A doc that
contradicts its own class is worse than no doc, because a future reader trusts it.

Make the custody discipline actually end-to-end: no public accessor yields private material in a
projectable form. If a `String` projection is genuinely unavoidable somewhere, confine it and justify
it the way you justified the three `.bytes` sites — and correct the doc so it matches reality.

## Also required — these bear on the same invariant

- **M-3 — a timeout does not kill the `git`/`ssh` child.** If the child survives, the temp identity file
  can survive too, so the private half outlives the call. Kill the process group on timeout and prove the
  file is gone on the timeout path, not only on success and ordinary failure.
- **M-5 — `hostKeyFingerprint` and `confirmedBy` are client-supplied and unauthenticated.** The client can
  assert any host key it likes, which makes the host-trust check decorative. Bind the confirmation to
  something the server obtained, or state plainly that it is operator-asserted and unauthenticated.
- **M-4 — the fallback is logged on first credential call, not at startup.** ADR 0018 `:232-234` requires
  fallback selection to be "a recorded precondition, not a silent default". Logging it lazily is close but
  not the same as a startup precondition. Move it, or record why not.
- **M-6 — `MintedCredential.referenceName` is annotated "Not the material".** That annotation is the exact
  reasoning `9417f8bf` rejects. Resolve it properly or escalate it; do not settle it with a comment.

## Triage the rest, and say what you did

`M-1, M-2, L-1..L-8`: fix, or record explicitly as not-fixed with a reason. **Do not silently drop any of
them.** Note the reviewer's correction: it measured the base at **`+171 -1`**, not the `+108 -10` you
reported — re-measure and reconcile, because a wrong baseline makes every later comparison unreliable.

## Out of scope — do not do these

- **H-1 `packages/control_plane_client` is unowned.** `serverpod generate` rewrites it and no lane owns
  it. That blocks the FEATURE, not this merge. It is assigned to the next client lane — **do not run
  `serverpod generate`** from this worktree; it would race that lane and rewrite
  `apps/server/lib/src/generated/**`, which is `READ_ONLY` here.
- `migrations/**` and `lib/src/generated/**` stay untouched. Your no-migration-needed finding was
  confirmed — keep it that way.

## Constraints unchanged

- `docker/**` PROHIBITED. QA is up on a stopgap run-mode override — do not disturb it.
- **ZERO mutating Docker/Compose commands.** `make test-integration` is the only sanctioned database path
  and it self-cleans. Never `make clean` / `make qa-down` / `make test-env-down` / `make e2e-down` / bare
  `down -v`.
- **Never print, log, or echo the private half** — including in your report or in a test failure message.
  B-1 is precisely a bug where that happened by accident.

## Gates — verbatim

`dart pub get` at REPO ROOT first if needed; `dart format --output=none --set-exit-if-changed .`;
`dart analyze apps/server` (report exact output and exit code); `make test-integration` (report the real
numbers, reconciled against the corrected `+171 -1` base).

## Proof you must produce

1. **B-1:** malformed material at every decode/parse site → the resulting log output and exception message
   contain no key material. Show the test.
2. **B-2:** no public accessor projects private material; the class doc matches the code.
3. **M-3:** on timeout, the child is killed and the identity file is gone. Show it.

Commit as new commits on the branch. **Do not push, merge, or touch `main`.**

Write your report to `docs/engineering/dispatch/tasks/correct-credential-key-service-b1b2/report.md`.

Report `READY_FOR_FOCUSED_REVIEW: YES` and `FOCUSED_RE_REVIEW`. **You still cannot approve this work.**