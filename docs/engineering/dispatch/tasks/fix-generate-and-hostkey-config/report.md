# Correction report — fix-generate-and-hostkey-config

```yaml
TASK_ID: fix-generate-and-hostkey-config
TASK_TYPE: correct
WORKTREE: /private/tmp/shipit-impl-keys
BRANCH: impl/credential-key-service
CORRECTED_FROM_HEAD: 7d1b1b8abdf5cbfbb7b48dc9682baf3bfb99090c
NEW_HEAD: effc537ad504cf94693d70e1974fa1c3b278087f
RESULT: CORRECTION_BLOCKED      # BLOCKER-1 complete; BLOCKER-3 blocked on ownership
READY_FOR_FOCUSED_REVIEW: NO   # BLOCKER-3 unresolved — cannot be self-certified
```

Pre-flight verification before writing (both matched, so the lane proceeded):
`git branch --show-current` = `impl/credential-key-service`;
`git rev-parse HEAD` = `7d1b1b8abdf5cbfbb7b48dc9682baf3bfb99090c`. Tree clean.

---

## BLOCKER-1 — `serverpod generate` exits 1 — **FIXED**

### Reproduced first, not assumed

```
$ dart run serverpod_cli generate          # from apps/server, at base 7d1b1b8
⠋ Generating code...
ERROR: Found 1 issue.
Error on line 105, column 18 of
package:control_plane_server/src/endpoints/credential_endpoints.dart:
Return type must be a Future or a Stream.
✗ Generating code (10.5s)
EXIT CODE: 1
```

### The mechanism, read from the pinned generator rather than guessed

The server pins `serverpod_cli` **3.4.13**. Discovery lives in
`EndpointMethodAnalyzer.isEndpointMethod`, which returns true for a method that is
public, not `@doNotGenerate`, not one of Serverpod's own excluded names, and whose
**first required positional parameter is a `Session`**. Such a method must then
return `Future` or `Stream`. `recordCustodyPrecondition(Session)` returning
`SecretProvider` matches the discovery shape and fails the return-type rule.

### The choice: `@doNotGenerate` — and why each alternative was rejected

Chosen: annotate the method `@doNotGenerate` (`serverpod_shared`, exported from
`package:serverpod/serverpod.dart`, `@Target({classType, method})`). This is
Serverpod's own first-class mechanism for a public method that is deliberately not
on the wire — its bundled skill doc states "Single method: `@doNotGenerate` on the
method", and `package:serverpod` uses it on its own
`CloudStoragePublicEndpoint`.

| Option | Verdict | Reason |
|---|---|---|
| **`private`** (`_recordCustodyPrecondition`) | **rejected** | Satisfies the analyzer, but deletes the seam. `credential_key_service_postgres_test.dart:693,708` calls it **from another file**, and the entire documented purpose (doc `:90-104`) is that the `server.dart` owner calls it from `run()`. Private makes both unreachable and quietly reopens M-4. |
| **`static`** | **rejected, and does not work** | `isEndpointMethod` in 3.4.13 has **no `isStatic` check** (4.x added one), so a static `Session`-first method is still discovered and still fails. It would also lose the per-process `_secretProvider` cache and `_record` logger the method exists to prime. |
| **move to a non-endpoint collaborator** | **rejected** | Duplicates the process-singleton `_secretProvider` cache into a second home, while the only intended caller (`run()`) holds no endpoint instance to reach a collaborator through. Larger change than the blocker warrants. |
| **change the return type to `Future`** | **rejected, explicitly forbidden** | A lie about asynchrony; `SecretProvider` is what this is. |

The rationale is recorded **in the doc comment** so the next reader does not
"simplify" the annotation away.

### The method is not lost — and this is now enforced, not just asserted

The invariant that broke had **no test at all**, which is precisely how two review
cycles passed over it: the tests exercise the endpoint in-process and never ask
Serverpod to generate a client for it. Running the generator from a test is not an
option (≈20s, and it **writes another lane's client package**).

So `apps/server/test/endpoint_surface_shape_test.dart` (13 tests) re-implements
`isEndpointMethod`'s predicate over the endpoint sources and fails if any endpoint
grows a public, non-`@doNotGenerate`, `Session`-first method not returning
`Future`/`Stream`.

It is **syntactic, not `dart:mirrors`**, and that choice was forced and is
precedented in this very repo: `dart analyze` rejects the `dart:mirrors` import
outright, and `apps/server/test/credential_keypair_test.dart:114-115` already
records the decision — *"`dart:mirrors` is not available to a test on every target,
and what this needs to catch is a **declaration** that widens the surface, which is
a source-level fact."*

### The guard was negative-controlled, because a passing guard proves nothing

Two earlier drafts of this guard **passed while the defect was present**. Both were
caught and discarded rather than shipped:

1. A `dart:mirrors` version: `TypeMirror.simpleName` returns a **`Symbol`**, so
   every type comparison was silently false and the guard audited nothing.
2. A syntactic version: `_balancedParameterList` double-wrote the opening paren
   into the captured text, so the `Session` regex never matched.

Validation matrix actually executed (each edit applied and verified in place, file
restored byte-identical afterwards):

| # | Mutation | Required | Actual |
|---|---|---|---|
| T0 | baseline (fix in place) | PASS | **PASS** |
| T1 | `@doNotGenerate` removed | FAIL | **FAIL** — `recordCustodyPrecondition returns SecretProvider, not Future or Stream` |
| T2 | `Future<SecretProvider>`, no annotation (legit endpoint) | PASS | **PASS** |
| T3 | new `void sneaky(Session)` | FAIL | **FAIL** |
| T4 | new `Map<String, String> sneaky(Session)` | FAIL | **FAIL** — flagged for the right reason |
| T5 | new `@doNotGenerate void sneaky(Session)` | PASS | **PASS** |
| T6 | restore | PASS | **PASS**, file byte-identical |

T1 reproduces the generator's own message. T5 proves the guard does not merely
ban non-`Future` returns but correctly honours the annotation.

### Acceptance criterion 1 — PROVEN

```
apps/server/lib/src/generated/** sha256
  BEFORE  1206d0bddbabbc5506b6c6e82fcc7a0886cf6c4119487ee1ac7db6c7a532e5d0
  AFTER   1206d0bddbabbc5506b6c6e82fcc7a0886cf6c4119487ee1ac7db6c7a532e5d0
git diff --exit-code -- apps/server/lib/src/generated  ->  empty
untracked files under lib/src/generated                 ->  0
```

`serverpod generate` output (post-commit, at `effc537`):

```
⠋ Generating code...
✓ Generating code (17.3s)
✅ Done.
EXIT CODE: 0
```

The generated tree is byte-identical because the method was **already** being
excluded from the protocol — `EndpointsAnalyzer._parseLibrary` filters out methods
that fail validation, so a failing method contributed nothing. Removing the failure
changes no output. **No generated output is committed.**

---

## BLOCKER-2 — no action, by instruction

Unchanged, as directed. Decision `898b07d0` (RESOLVED / OPTION_A) settled the
ordering: the key flow creates the Product row (state registered) plus the
RepositoryReference first, then "Register product" commits credential verification.
Recorded here so nobody later "fixes" it by reordering.

---

## BLOCKER-3 — host-key values in the docker path — **BLOCKED, cannot be fixed within this lane's ownership**

**I did not change `docker/config.js.template`.** A template-only edit cannot work,
and shipping one would be actively harmful. Proven, not assumed.

### Why the template alone is insufficient — demonstrated

`docker/entrypoint.client.sh:8` uses the **allowlist** form of `envsubst`:

```sh
envsubst '${CONTROL_PLANE_API}' < .../config.js.template > .../config.js
```

Only the named variable is substituted. Executed locally with gettext `envsubst`
1.0 and **both** new variables present in the environment:

```
CONTROL_PLANE_API=https://api.example
SHIPIT_HOST_KEY_FINGERPRINT="SHA256:REALVALUE"
SHIPIT_OPERATOR_NAME="Real Operator"

$ envsubst '${CONTROL_PLANE_API}' < probe.template
  CONTROL_PLANE_API: "https://api.example"
  HOST_KEY_FINGERPRINT: "${SHIPIT_HOST_KEY_FINGERPRINT}"   <-- LITERAL
  OPERATOR_NAME: "${SHIPIT_OPERATOR_NAME}"                 <-- LITERAL
```

The literal `${SHIPIT_HOST_KEY_FINGERPRINT}` is **non-blank**, and the client's
`_configured` (`operator_attestation.dart:70-78` at `2f6b78d`) trims and treats
any non-empty value as configured. So a template-only edit would ship a config in
which a **literal placeholder string is presented to the operator as a host-key
fingerprint** — strictly worse than today's `null`, and a silent-default of exactly
the kind ADR 0018 §A1 refuses. There is no fail-safe template-only formulation.

### A correct fix needs three files, two of which I may not write

1. `docker/config.js.template` — add the two keys. **Owned. Not written** (see above).
2. `docker/entrypoint.client.sh:8` — extend the allowlist to
   `'${CONTROL_PLANE_API} ${SHIPIT_HOST_KEY_FINGERPRINT} ${SHIPIT_OPERATOR_NAME}'`.
   **Not in OWNED_PATHS. Not in PROHIBITED_PATHS. No lane owns it.**
3. `docker/compose.qa.yaml:70-72` — pass the values **into** the container.
   **Explicitly READ_ONLY_PATHS.** It currently hardcodes
   `CONTROL_PLANE_API: "http://localhost:8081/api/"` as a literal, so the new
   values must be added as `${SHIPIT_HOST_KEY_FINGERPRINT:-}` /
   `${SHIPIT_OPERATOR_NAME:-}` passthrough — otherwise they would be **hardcoded**,
   violating the "nothing hardcoded / substitutable from the environment"
   constraint.

Verified there is no other substitution path: `entrypoint.client.sh:8` is the only
`envsubst` call for `config.js`, and `compose.qa.yaml` sets only
`CONTROL_PLANE_API` and `API_UPSTREAM` on the client.

### Key names confirmed, not guessed

Read from the client lane's reviewed commit `2f6b78d` (read-only): the client
resolves `window.SHIPIT_CONFIG['HOST_KEY_FINGERPRINT']` and
`['OPERATOR_NAME']`, each falling back to `--dart-define=SHIPIT_HOST_KEY_FINGERPRINT`
/ `SHIPIT_OPERATOR_NAME`. Its own doc comment already anticipated this lane:

> `docker/config.js.template` … *enumerates the keys it publishes and is outside
> this lane's ownership*, so on a deployment that has not been updated the runtime
> lookup returns null and the build-time value below is used instead.

### Why this is escalated rather than done

Overwriting a shared container entrypoint and a READ_ONLY compose file is a
deployment/infra change with a blast radius across every environment that builds
this client image. Doing it silently would exceed my declared `OWNED_PATHS` and
make an unrequested governance change as a side effect. **No value was hardcoded,
and nothing I wrote implies these values are server-verified** (M-5 stays open).

### BLOCKER-2 note on M-5

Nothing in this change touches M-5. The values remain **operator-asserted and
unauthenticated**; `apps/control_plane/lib/data/operator_attestation.dart` at
`2f6b78d` still documents them as "its *provenance* is this configuration, not the
server. Nothing here may be described as proof of host identity." That wording must
survive the follow-up edit.

---

## Gates

| Gate | Result | Detail |
|---|---|---|
| `dart pub get` (repo root) | **pass** | Run **first**, per instruction. `Got dependencies!` — avoided the phantom `ed25519_edwards` `uri_does_not_exist`. |
| `dart format --output=none --set-exit-if-changed .` | **pass** | exit **0**, `Formatted 656 files (0 changed)`. Exit captured via `$?` after redirect — an initial attempt piped through `tail` and captured *tail's* code; corrected. |
| `dart analyze apps/server` | **pass** | exit **0**, `No issues found!` |
| `serverpod generate` | **pass** | exit **0** (was **1**); generated tree byte-identical |
| `make test-integration` | **KNOWN RED, unchanged** | `+191 -1` — matches the documented baseline exactly. See below. |
| `dart test` (apps/server unit) | **pass** | 5 files pass; `onboarding_test.dart` pre-existing failure, proven below. |

### `make test-integration` — known red, correctly attributed

`+191 -1`, sole failure `test/integration/dogfood_shipit_postgres_test.dart`,
matching the dispatch's documented `+191 -1` for this branch. Cleanup verified —
`docker ps -aq` / `volume ls -q` / `network ls -q` filtered on
`label=com.docker.compose.project=shipit_integration_48962` all returned **0**. QA
stack untouched (`docker-postgres-1` still `Up 23 hours (healthy)`).

**Mechanism differs from the dispatch's description, and this is worth recording.**
The dispatch attributed it to a load-sensitive 43 098 ms `git archive` walk against
the 30 s default. The failure actually observed here was:

```
Expected: true
  Actual: <false>
  dogfood expects a git working tree at /private/tmp/shipit-impl-keys
  test/integration/dogfood_shipit_postgres_test.dart 87:11
```

`_repoRoot()` (`:60-66`) derives the repo root and asserts
`Directory('${repoRoot.path}/.git').existsSync()`. In this dispatch's worktree
`.git` is a **75-byte file** (`gitdir: …/worktrees/shipit-impl-keys`) — a linked git
worktree, not a full checkout. `Directory.existsSync()` is **false for a file**, so
the assertion fails deterministically in any linked worktree. Same test, same
`+191 -1`, but here it is **environmental and deterministic, not load-sensitive**.

Either way: **not fixed, not a regression, not reported as one** — `.git` is
untouched and outside my ownership, and the instruction is explicit that this lane
does not touch it. It is in `apps/server/test/**`, which I *do* own, so I
deliberately did **not** "fix" it: that would be unrequested scope and would amount
to weakening a test to get green. Raised below instead.

### `onboarding_test.dart` — pre-existing, proven by stash-and-rerun

`dart test test/onboarding_test.dart` exits 1 after `loading`, with no failure
message. It uses `serverpod_test` and needs a database; it has **zero** references
to credentials. Proven pre-existing by stashing all my work and re-running at the
untouched base:

```
$ git stash push -u          HEAD still: 7d1b1b8
$ dart test test/onboarding_test.dart     ->  EXIT 1, same symptom
```

Not in the dispatch's `VALIDATION_COMMANDS` (which runs only `test/integration/`)
and not a regression of mine.

### Two orphaned scratch dirs cleaned (test hygiene, not Docker)

`repository_access_verifier_test.dart` asserts in `tearDown` that nothing matching
`shipit_credential_verify_` survives a run. Two orphans were present in
`systemTemp`, left by an earlier interrupted run. Removed, then the file passed in
isolation (`EXIT 0`). **Not Docker, not shared QA state.** Flagged below as a
hygiene gap: that assertion is only meaningful when the run is not interrupted.

---

## Docker discipline

- **Zero mutating Docker/Compose commands.** Only `docker ps`, `docker volume ls -q`,
  `docker network ls -q` (label-filtered reads) and `make test-integration` — the
  narrow, named exemption, which self-cleaned.
- Never ran `make clean`, `make qa-down`, `make test-env-down`, `make e2e-down`, or a
  bare `down -v`.
- `docker/build-client.sh` **not run**; `docker/config.js.template` **not modified**.
- QA stack left healthy and undisturbed.

## Constraints honoured

- Untouched: `apps/server/migrations/**`, `apps/server/tool/**`,
  `apps/server/lib/src/generated/**`, `apps/server/lib/server.dart`, `packages/**`,
  `apps/control_plane/**`, `docker/compose.qa.yaml`.
- `packages/control_plane_client/lib/src/protocol/client.dart` is **rewritten by
  every `serverpod generate` run** (see below) and was restored with
  `git checkout --` after each run. Final tree clean; **not committed**.
- **No private key material was printed, logged or echoed** at any point.
- New commit on top of `7d1b1b8`; no history rewritten; **not pushed, not merged,
  `main` untouched**.

### Discovery: the committed client `protocol/client.dart` is stale

Worth the next lane's attention. Every `serverpod generate` run rewrites
`packages/control_plane_client/lib/src/protocol/client.dart` (+101/-1), adding the
`EndpointCredentialEndpoints` client — which the committed file on this branch does
**not** contain, while the server-side `lib/src/generated/endpoints.dart:35` **does**
register `credentialEndpoints`. I verified the post-fix output is **byte-identical**
to the pre-fix output, so this is **pre-existing staleness entirely unrelated to my
fix** — not a regression, and exactly the client lane's to close. This is also why
the dispatch's "do not run `serverpod generate`" is unachievable as literally
stated: it must run, and the client file must be restored afterwards.

---

## Files changed

```
apps/server/lib/src/endpoints/credential_endpoints.dart   (+39, -0)  1 annotation + its rationale
apps/server/test/endpoint_surface_shape_test.dart          (new, 13 tests)
```

## New discoveries (for routing, not persisted by me)

1. **`PROJECT_FACT`** — Endpoint discovery in `serverpod_cli` **3.4.13** has **no
   `isStatic` check** in `isEndpointMethod`; 4.x added one. `static` is therefore
   not an escape hatch on this pinned version. Persisted already as executable
   knowledge in `endpoint_surface_shape_test.dart`.
2. **`RUNTIME_DISCOVERY`** — `serverpod generate` always rewrites the client
   package's `protocol/client.dart`; the committed copy on `impl/credential-key-service`
   is stale (missing `EndpointCredentialEndpoints`). Client lane's to close.
3. **`AUTOMATION_OPPORTUNITY`** — No CI gate runs `serverpod generate`'s **exit
   status**. That gap is what let BLOCKER-1 through two review cycles.
   `endpoint_surface_shape_test.dart` is a fast partial backstop; a real CI gate is
   still the durable fix.
4. **`CONTRADICTION`** — `dogfood_shipit_postgres_test.dart:87` asserts
   `Directory('<repoRoot>/.git').existsSync()`, which cannot hold in a linked git
   worktree. It makes the suite structurally unrunnable in worktree-based lanes.
   Owner: `apps/server/test/integration/**`. **Human/EM routing** — I did not touch it.
5. **`PROJECT_FACT`** — `repository_access_verifier_test.dart`'s `tearDown` leak
   assertion is bypassed by an interrupted run (a killed `dart test` leaves
   `shipit_credential_verify_*` in `systemTemp` that fails the *next* run). Two
   such orphans were present and were cleaned.
6. **`PROJECT_FACT`** — No gate covers `apps/server/test/*.dart` unit tests (only
   `test/integration/` runs). `onboarding_test.dart` fails there for want of a
   database and nobody notices. Related to finding 3.

---

## BLOCKER-3 — what the manager needs to decide

To make the host-key values reach the client, one of:

- **(a)** grant this lane `docker/entrypoint.client.sh` **and** write access to
  `docker/compose.qa.yaml` (for `${VAR:-}` passthrough so nothing is hardcoded), or
- **(b)** assign a lane holding all three files, with this report as the spec, or
- **(c)** accept the build-time `--dart-define` path in the docker stack.

The change is small and verified in substance — the substitution mechanism is
proven above — but it is deployment/infra configuration across two files outside my
`OWNED_PATHS`, one of them explicitly `READ_ONLY_PATHS`. I will not make that call.

---

```yaml
RESULT: CORRECTION_BLOCKED

CORRECTED_FROM_HEAD: 7d1b1b8abdf5cbfbb7b48dc9682baf3bfb99090c
NEW_HEAD: effc537ad504cf94693d70e1974fa1c3b278087f

FINDINGS_ADDRESSED:
  BLOCKER-1: FIXED — @doNotGenerate; generate exit 1 -> 0; generated tree byte-identical;
             regression guard added and negative-controlled (T1-T6).
  BLOCKER-2: NO ACTION BY INSTRUCTION — ordering is the approved architecture (898b07d0).
  BLOCKER-3: BLOCKED — provably impossible within OWNED_PATHS; requires
             docker/entrypoint.client.sh + docker/compose.qa.yaml. Not attempted,
             because a template-only edit ships a literal placeholder as a fingerprint.

FILES_CHANGED:
  apps/server/lib/src/endpoints/credential_endpoints.dart
  apps/server/test/endpoint_surface_shape_test.dart

GATES:
  format=pass (exit 0, 656 files unchanged)
  analyze=pass (exit 0, "No issues found!")
  tests=KNOWN RED AS APPROVED (make test-integration +191 -1, sole failure the pre-existing
         dogfood_shipit_postgres_test.dart; cleanup verified 0/0/0; unit tests pass;
         onboarding_test.dart pre-existing, proven by stash-and-rerun at base)
  build=pass (serverpod generate exit 0)
  runtime=n/a (no runtime/Docker mutation performed; docker path verified by substitution only)

NEW_DISCOVERIES:
  - serverpod_cli 3.4.13 isEndpointMethod has NO isStatic check (4.x added one)
  - committed client protocol/client.dart is stale; unrelated to this fix (byte-identical output)
  - no CI gate checks serverpod generate's exit status — the gap that hid BLOCKER-1
  - dogfood test cannot pass in a linked worktree (.git is a file) — CONTRADICTION, escalated
  - repository_access_verifier tearDown leak check is defeated by an interrupted run
  - apps/server/test/*.dart unit tests have no gate

READY_FOR_FOCUSED_REVIEW: NO
```

**A correction is never self-approved.** BLOCKER-1 is complete and proven and is
ready for focused re-review. BLOCKER-3 needs the ownership decision above before
the lane as a whole is. I cannot approve my own work.