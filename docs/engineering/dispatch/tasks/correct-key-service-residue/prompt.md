# Dispatch — correct-key-service-residue

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: correct-key-service-residue
TASK_TYPE: correct
FEATURE: Close the F-1/F-2/F-3/F-4 residue from the approved focused re-review
AREA: apps/server/lib/src/credentials/** — value bounding and doc accuracy
WORKTREE: /private/tmp/shipit-impl-keys
BRANCH: impl/credential-key-service
BASE_SHA: da68b5f67d3766776b35d57d16956dd4b993ae7e
OWNED_PATHS:
  - apps/server/lib/src/credentials/**
  - apps/server/lib/src/endpoints/credential_endpoints.dart
  - apps/server/test/**
READ_ONLY_PATHS:
  - apps/server/lib/src/generated/**
  - apps/server/migrations/**
PROHIBITED_PATHS:
  - apps/control_plane/**
  - packages/**
  - docker/**
  - .github/**
  - docs/adr/**
  - .decisions/**
  - apps/server/migrations/**
  - apps/server/lib/src/generated/**
  - apps/server/lib/server.dart
ACCEPTANCE_CRITERIA: >
  No attacker-controlled string can forge a log line boundary, and no doc comment in the
  credentials package asserts a guarantee the code does not provide.
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - dart analyze apps/server
  - make test-integration
ROUTING_CLASS: STANDARD
```

---

## Read first

`docs/engineering/dispatch/tasks/review-correct-credential-key-service/report.md` — `APPROVE_CORRECTIONS`,
`READY_FOR_MERGE: YES`, blockers none. Your custody work is accepted: **B-1, B-2, M-1, M-3 resolved**,
M-4/M-5/M-6 accepted with residue tracked, and the reviewer **reproduced all four of your mutations plus
one of their own**. The `ps` tree walk is confirmed genuinely load-bearing — with the parent kill removed
but the walk intact, the surviving pid differs, which proves the test fails on the grandchild.

Also corrected in that review, against my dispatch: **D-4 is pre-existing**, not new. Base measures
`+170 -2` with D-4 failing; HEAD gives `+190 -1` with it passing. There is no new failure relative to base
and no causal path. Withdraw that concern.

These four findings are non-blocking and small. They are here because **two of them are doc-vs-code
mismatches**, which already caused one finding in this work item — B-2 existed partly because a class doc
asserted the opposite of its code. Shipping more of those would be repeating a known failure mode.

## F-1 (MEDIUM) — do this one first

`_validatedConfirmer` bounds `confirmedBy` because an unescaped control character is "a
forge-the-previous-entry primitive". But **`hostKeyFingerprint` is passed unchanged** into
`HostKeyNotPresentedException`, whose description interpolates it — and that exception type is audited,
so the type gate forwards it straight through.

The reviewer **demonstrated** `DESCRIPTION_CONTAINS_FORGED_MARKER=true` reaching a Postgres-persisted log.
No key material and no ADR clause is violated, which is why it does not block — but a log-forgery vector in
a security boundary should not ship knowingly. Apply the same bounding to `hostKeyFingerprint` that
`confirmedBy` already gets. Claimed as a three-line fix; if it turns out larger, say so rather than
under-scoping it.

## F-2 (LOW/MED) — the source guard is narrower than its doc says

`secret_provider.dart:52-56` claims the source guard fires on **any** `$` interpolation. It only fires on
**catch-clause bindings**. The reviewer reproduced a bypass: `reason: _leak(error)` with a top-level helper
passes, giving `+9: All tests passed`.

This matters because `SecretStoreException` is audited, so this guard is the **only** net for that shape.
Either widen the guard to cover helper-returned messages, or — if that is genuinely out of reach — correct
the doc to state precisely what it catches, and say in your report which you did and why. A doc that
overstates the guarantee is the defect; pick deliberately.

## F-3 (LOW) — doc contradicts code

`_validatedConfirmer`'s doc asserts it reports the value; the code reports a length. Make the doc match.

## F-4 (LOW) — doc contradicts code

`SshKeyPair`'s doc says "no public accessor returns the seed as Uint8List". That is **false** —
`privateSeed.bytes` is. The reviewer notes the guarantee that actually matters (no *projection into a
loggable/serialisable form*) still holds, so the code is fine and the **doc is wrong**. Fix the doc, not
the code.

## Also correct your own report's inaccuracies

The reviewer found two claims in your last report that do not hold against the branch:

- **F-5** — your report cites an `ignore` comment that **does not exist anywhere** in the branch.
- **F-6** — your report states "no single B-1 level suffices". The reviewer **measured that the type gate
  alone would have blocked the leak**. Your three-level defence is still better defence-in-depth; the claim
  that each level was necessary is not supported.

Correct both where they are recorded. Do not delete the record of what you originally claimed — record the
correction, the way the M-1 withdrawal was handled.

## Explicitly still out of scope

- **M-4 stays as it is.** The reviewer accepted your reasoning: the ADR clause is "a recorded
  precondition, not a silent default" and says nothing about startup; there is no default branch at all, so
  the clause is already met. `server.dart` remains outside your ownership.
- **M-5/M-6 residue stays tracked.** Blocking would require you to invent a transport or a handle scheme,
  which are not your calls.
- **Do NOT run `serverpod generate`.** It rewrites `packages/control_plane_client` (assigned to the next
  client lane) and `apps/server/lib/src/generated/**` which is `READ_ONLY` here.
- `migrations/**`, `tool/**` and `lib/src/generated/**` stay untouched.

## Constraints unchanged

- `docker/**` PROHIBITED. QA is up and healthy on a **stopgap** run-mode override — do not disturb it. Read
  compose as text.
- **ZERO mutating Docker/Compose commands.** `make test-integration` is the only sanctioned database path
  and it self-cleans. Never `make clean` / `make qa-down` / `make test-env-down` / `make e2e-down` / bare
  `down -v`. This repository has already lost a QA database irrecoverably to a `down -v`.
- **Never print, log, or echo the private half** — not in code, not in a test failure message, not in your
  report.

## Gates — verbatim

`dart pub get` at **REPO ROOT** first if `.dart_tool/` is missing; `dart format --output=none
--set-exit-if-changed .`; `dart analyze apps/server` (exact output + exit code); `make test-integration`
(report real numbers — note the base is `+170 -2` per the reviewer, superseding the earlier `+171 -1`).

**The machine may be under load.** A cascade-polluted run is not evidence of a regression; if you see one,
re-run and say so rather than reporting the cascade as a failure.

## Proof required

1. **F-1:** the reviewer's exact demonstration — a `hostKeyFingerprint` containing a forged line-boundary
   marker no longer reaches the exception description. Show the test.
2. **F-2:** either the helper bypass now fails, or the doc states precisely what the guard catches. Say
   which, and prove it.
3. **F-3/F-4:** docs match the code. Quote the corrected lines.

Commit as a new commit on the branch. **Do not push, merge, or touch `main`.**

Write your report to `docs/engineering/dispatch/tasks/correct-key-service-residue/report.md`.

Report `READY_FOR_FOCUSED_REVIEW: YES` and `FOCUSED_RE_REVIEW`. You still cannot approve your own work.