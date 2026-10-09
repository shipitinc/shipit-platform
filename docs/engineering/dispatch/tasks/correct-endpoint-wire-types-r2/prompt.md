# Dispatch — correct-endpoint-wire-types-r2

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: correct-endpoint-wire-types-r2
TASK_TYPE: correct
FEATURE: Fix the real wire-type blocker (addRepositoryReference) and the red assertion
AREA: productRegistryEndpoints.addRepositoryReference + the credential integration test
WORKTREE: /private/tmp/shipit-fix-endpoint-types
BRANCH: fix/credential-endpoint-return-types
BASE_SHA: 77d984a
OWNED_PATHS:
  - apps/server/lib/src/endpoints/product_registry_endpoints.dart
  - apps/server/lib/src/models/**
  - apps/server/lib/src/generated/**
  - apps/server/test/**
  - apps/control_plane/lib/data/control_plane_repository.dart
READ_ONLY_PATHS:
  - apps/server/lib/src/credentials/**
  - apps/server/lib/src/endpoints/credential_endpoints.dart
  - packages/control_plane_client/**
PROHIBITED_PATHS:
  - apps/server/migrations/**
  - apps/server/tool/**
  - apps/server/lib/server.dart
  - packages/**
  - docker/**
  - .github/**
  - docs/adr/**
  - .decisions/**
ACCEPTANCE_CRITERIA: >
  Every endpoint on the Add Product path returns a Serverpod-deserialisable type, so the browser
  hop completes a mint. The integration test is green when executed, not merely analyzed.
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - dart analyze apps/server
  - make test-integration
  - cd apps/control_plane && flutter analyze
  - cd apps/control_plane && flutter test
ROUTING_CLASS: PRECISION
```

---

## Read first

`docs/engineering/dispatch/tasks/review-fix-credential-endpoint-types/report.md` — **`DO_NOT_MERGE`** with
two blockers. Your credential-endpoint work was otherwise judged **correct and genuinely well-proven**: the
canary was reproduced red at `cf1b210` byte-identically, the wire type is fixed, no private material is
reachable, and the `.bytes` claim was independently verified as an **empty diff of the full site lists**,
not just a matching count. Your schema-location override was **correct** — the dispatch was wrong, and
saying so was right.

Continue on your branch. Add new commits; do not rewrite the two existing ones.

## B-1 — BLOCKER: you fixed the wrong call. The browser hop still cannot work.

**`productRegistryEndpoints.addRepositoryReference`** (`product_registry_endpoints.dart:507`) still returns
`Map<String, dynamic>`, and at `:526` it returns a **non-empty** map `{'success': true, 'repositoryId': …}`.

`add_product_page.dart:143` calls it — via `_ensureProductAndRepository:281` — **immediately before**
`generateDeployKey` at `:147`. The reviewer reproduced the throw on your HEAD through the real generated
client's `Protocol`:

```
DeserializationTypeNotFoundException: No deserialization found for type dynamic
```

**The mint is never reached.** And this matches the original failing log better than your diagnosis did:
`addRepositoryReference` returning 200 followed by silence is exactly a client-side `parseData` death at
*that* call.

Note also the reviewer measured that an **empty** map body deserialises fine while any **non-empty** one
throws. That is why this class of defect presents as intermittent and gets misdiagnosed — mine did.

Fix `addRepositoryReference` to return a typed model. Keep `success` and `repositoryId`. Then **trace the
whole path the Add Product flow actually calls** — `createProduct`, `addRepositoryReference`, `listProductSummaries`,
`generate`, `verifyAccess`, and anything else on it — and confirm every one returns a deserialisable type.
Do not fix only the two I named; that is what produced this round.

## B-2 — BLOCKER: the integration test you edited is RED.

`credential_key_service_postgres_test.dart:442-456`. Your sweep reasoning is correct — but the assertion you
added on top is wrong: the generated `MintedCredentialView.toJson()` **includes `__className__`** and the
expected set at `:443-455` omits it. Measured failure: `Which: larger than expected`.

It sits inside the test named *"the endpoint response contains no private material"*, so the report's
"No test was weakened" is **false as written**. Fix the expected set to include `__className__`.

**And then actually execute it.** The reviewer confirmed `make test-integration` is available to you and
not run — "analyzed, not executed" plus "a map is legal Dart" is precisely the combination that let a red
assertion ship looking green. Two independent mechanisms failed open on the same correction. Run the suite.

## The 22 other endpoints — required now, not deferred

The reviewer **verified 22** endpoints still return `Map<String, dynamic>` with the identical latent defect,
and that **13 of them are reachable from the live Flutter client** — not an inert backlog. Your canary
generalises to them nearly free.

You previously called fixing them "a product call". Having now seen that shipping a per-endpoint fix left
the actual blocking call broken, **fix all of them** and extend the canary to cover every endpoint the
client can reach. If any genuinely cannot be typed, say which and why rather than leaving it silently.

## Proof required

1. **A test that fails at `77d984a`.** Extend the canary so it covers the whole Add Product path, and show
   it red at `77d984a` and green at your HEAD.
2. **`make test-integration` executed and green** — report the real number. Note a linked worktree makes
   `dogfood_shipit_postgres_test.dart` deterministically red (known artefact, not a regression); report the
   number honestly and say whether the sole failure is that one.
3. Re-run your `.bytes` audit; report the private-material site count before and after — it must not rise.

## Constraints

- **NEVER print, log, or echo the private half** — not in code, not in a test failure message, not in your
  report. It is the invariant this whole key service exists to protect, and a serialisable model is exactly
  where it could leak by accident.
- `migrations/**`, `tool/**`, `lib/server.dart` untouched. Read
  `apps/server/tool/schema_bootstrap.dart`'s header before going near migrations.
- `docker/**` PROHIBITED. **The QA stack is up and running from merged `main` and must not be disturbed** —
  I am driving it. Read compose as text.
- **ZERO mutating Docker/Compose commands.** `make test-integration` is the ONLY sanctioned database path
  and self-cleans. Never `make clean` / `make qa-down` / `make test-env-down` / `make e2e-down` / bare
  `down -v` — this repository has already lost a QA database irrecoverably to a `down -v`.
- Regenerate the client after signature changes (`serverpod generate`) and commit
  `packages/control_plane_client/**` + `apps/server/lib/src/generated/**`.
- Do not weaken, skip, `@Ignore`, filter, or delete any test.

## Out of scope — record, do not fix

G-7 (`referenceName` on the client — product decision), M-4 (custody fallback logged lazily, accepted),
M-5 (attestation operator-asserted, narrowed not closed), CI gaps F-A/F-B (no job runs
`serverpod generate` or `apps/server/test/`).

Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`. Commit; do **not** push, merge, or touch `main`.
Report `READY_FOR_FOCUSED_REVIEW: YES` and `FOCUSED_RE_REVIEW`.