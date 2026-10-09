# Focused correction — endpoint surface guard (2 blockers)

```yaml
TASK_ID: correct-endpoint-guard
TASK_TYPE: correct
MANAGER: engineering-manager
CORRECTED_FROM_HEAD: effc537ad504cf94693d70e1974fa1c3b278087f
NEW_HEAD: 4f96c78c9ffd65a9d1bafcdb65c4d12128a0ec3e
BRANCH: impl/credential-key-service
WORKTREE: /private/tmp/shipit-impl-keys
PRECONDITION_VERIFIED:
  branch: impl/credential-key-service            (matched)
  HEAD:   effc537ad504cf94693d70e1974fa1c3b278087f (matched)
SCOPE: BLOCKER-1 and BLOCKER-2 of review-fix-generate. Both were in the guard test.
PRODUCTION_CHANGE: none. The diff is one test file.
RESULT: CORRECTION_COMPLETE
READY_FOR_FOCUSED_REVIEW: YES
```

---

## 0. Preconditions and ownership

Branch and HEAD were checked **before** any write and both matched the dispatch:
`impl/credential-key-service` @ `effc537ad504cf94693d70e1974fa1c3b278087f`, worktree clean.
`.git` here is a **75-byte file** (linked worktree) — noted in §6 because it decides the dogfood mode.

```yaml
OWNED_PATHS (this correction — unchanged from the original lane):
  - apps/server/test/endpoint_surface_shape_test.dart   # the only file written
READ_ONLY_PATHS:
  - apps/server/lib/src/endpoints/credential_endpoints.dart   # read only; NOT modified
  - docker/**  .github/**  apps/server/lib/src/generated/**
PROHIBITED_PATHS (untouched, machine-verified — see §5):
  - apps/server/migrations/**  apps/server/tool/**
  - apps/server/lib/src/generated/**  apps/server/lib/server.dart
  - packages/**  apps/control_plane/**  docker/**  .github/**  docs/adr/**  .decisions/**
```

`credential_endpoints.dart` is inside the original lane's `OWNED_PATHS`, but the reviewer's finding was
about the **guard test**, so I did not touch the production file. `git diff --name-only effc537..HEAD`
returns exactly one path: `apps/server/test/endpoint_surface_shape_test.dart`.

---

## 1. What I changed

Three corrections, all inside the guard test. `+136 −20`.

**BLOCKER 1 — the `static` skip is gone; the predicate is quoted, not paraphrased.**

Deleted `if (match.namedGroup('mods')!.contains('static')) continue;`. `static` `Session`-first
declarations are now audited.

The doc no longer *asserts* the predicate — it **quotes `isEndpointMethod` verbatim** from 3.4.13 and
then states the consequence in bold: *"There is no `isStatic` check in 3.4.13. A `static` method with
`Session` first is still discovered and still validated, so `static` is not a way out of this — it is
worse than doing nothing, because it also reads like one."* Quoting the source is the point: a
paraphrase is what let two files in one commit disagree. (Per required-fix item 2, it also notes 4.0.3
added `isStatic` **and** dropped `_excludedMethodNameSet` — and I annotated
`_serverpodExcludedMethodNames` as "the 3.4.13 shape" accordingly, which was follow-up 3.)

This now agrees with `credential_endpoints.dart:128-132`, which was already right. The two files can no
longer conflict, because the test now derives its claim from the same source the production comment
cites.

**BLOCKER 2 — `_isFutureOrStream` replaced by `_returnTypeRejection`, which returns a reason.**

The old `^(?:Future|Stream)\b` is replaced by a reproduction of `_validateReturnType`'s actual rules:

| Rule | Generator's source | Implemented |
|---|---|---|
| exactly one type argument | `typeArguments.length != 1` | `_splitTopLevel(...)` length must be 1 |
| `Future<dynamic>` rejected | `innerType is DynamicType && !isDartAsyncStream` | rejected **only** when container is `Future` |
| `Stream<dynamic>` **accepted** | falls through; `fromDartType` does not throw | accepted |
| `Stream<void>` rejected | `innerType is VoidType && isDartAsyncStream` | rejected when container is `Stream` |
| `Future<void>` accepted | `_validateReturnType` returns null | accepted |

Because BLOCKER 2 introduces an offender category that *is* a `Future`, the old offender text
(`"returns Future<dynamic>, not Future or Stream"`) would itself have been a false statement — the same
defect class this correction exists to close. So the predicate now returns the reason and the message
states it. The guard is unchanged in behaviour, only in honesty.

**One addition beyond the two blockers.** A "WHAT THIS IS NOT" paragraph recording that no CI job runs
this test and that a green run here does not mean generate passes. Verified myself before writing it:
`grep -rin generate .github/workflows/` returns only unrelated comments about schema generation;
`integration.yaml:139` runs `dart test test/integration/` only; `ci.yaml:60-61` excludes `apps/server`
from the pure-Dart job.

### A false positive I introduced and then removed — disclosed because it changes the finding

The reviewer's fix instruction was "require a non-dynamic type argument". Applied literally that also
rejects `Stream<dynamic>` — and **`Stream<dynamic>` generates successfully.** I measured it: generate
exits 0 **and emits a real client streaming method** (`probeStreamDynamic(` appears in
`packages/control_plane_client/lib/src/protocol/client.dart`). So a literal reading would have shipped a
guard that cries wolf on legal code.

My initial reading of the source said `TypeDefinition.fromDartType(DynamicType)` throws
(`className == null` → `FromDartTypeClassNameException`), which would have rejected `Stream<dynamic>`
too. That was wrong: `analyzer-10.2.0` `DynamicTypeImpl.element` returns `DynamicElementImpl.instance`,
whose `displayName` is `dynamic`, **not null**, so nothing throws. I had inferred the rule from reading
instead of running it, and the run corrected me.

Consequence for routing: **the fix is narrower than "require a non-dynamic type argument" — it is
"require a non-dynamic type argument *on a `Future`*".** `Future<dynamic>` and `Stream<dynamic>` are
treated differently by the generator and must be treated differently by the guard. The re-review should
check this specific asymmetry, since it is the one place a literal reading of BLOCKER 2 is wrong.

---

## 2. Proof — the 8-case matrix

Every probe was injected into `CredentialEndpoints` in a **throwaway clone** (`git clone --no-hardlinks`),
never in the reviewed worktree, and reverted after each run. All probes are **analyzer-clean**, so
`generate`'s verdict is about the return type and not a compile error. (M1 initially did not compile —
`static` cannot call the instance method `_provider` — which would have made the `generate` result prove
nothing; I switched it to `const _UnresolvedProvider(...)` and it compiles clean.)

| # | Injected declaration | analyze | **Guard** | **generate** | Agree? |
|---|---|---|---|---|---|
| M1 | `static SecretProvider p(Session)` | clean | **FAIL (1)** | **exit 1** — `Return type must be a Future or a Stream.` | ✅ |
| M2 | `Future<dynamic> p(Session)` | clean | **FAIL (1)** | **exit 1** — `Return generic must have a type defined.` | ✅ |
| M3 | `Stream<dynamic> p(Session)` | clean | pass (0) | exit 0 (client streaming method emitted) | ✅ |
| M4 | `Future<Map<String, dynamic>> p(Session)` | clean | **pass (0)** | exit 0 | ✅ |
| M5 | `static Future<Map<String, dynamic>> p(Session)` | clean | pass (0) | exit 0 | ✅ |
| M6 | `@doNotGenerate static SecretProvider p(Session)` | clean | **pass (0)** | exit 0 | ✅ |
| M7 | `Future<void> p(Session)` | clean | pass (0) | exit 0 | ✅ |
| M8 | `Stream<void> p(Session)` | clean | FAIL (1) | exit 1 — `The type "void" is not supported for streams.` | ✅ |

**8/8 agreement with the generator.** The six required proofs map as follows.

1. **`static SecretProvider f(Session)` → guard FAILS and generate EXITS 1** — M1. Guard output:
   `'CredentialEndpoints.probeStaticNonFuture returns SecretProvider — it is not Future or Stream at all.'`
   Was a false negative at `effc537`; now caught, in perfect correlation with the generator.
2. **`Future<dynamic> f(Session)` → guard FAILS and generate EXITS 1** — M2. Was a false negative at
   `effc537`; now caught, and the message names the real reason instead of asserting "not Future or
   Stream" about a `Future`.
3. **Legitimate `Future<...>` endpoint → guard PASSES** — M4 (and M7 `Future<void>`, M5 static).
   M5 exists specifically to prove I did **not** over-correct: dropping the `static` skip must not turn
   into failing every `static` member. It does not.
4. **Annotated non-endpoint → guard PASSES** — M6, deliberately the *strongest* form: `@doNotGenerate`
   on a `static` non-Future method. The annotation is honoured regardless of container or return type,
   which is exactly the escape hatch the production fix relies on.
5. **`serverpod generate` exits 0 and `lib/src/generated/**` is byte-identical** — §4.
6. **Doc comments corrected** — §3.

### Load-bearing re-check (T1) at the final HEAD

Deleting only the `@doNotGenerate` line reproduces the original defect, and guard and generator agree:

```
guard    -> exit 1,  Actual: ['CredentialEndpoints.recordCustodyPrecondition returns
                             SecretProvider — it is not Future or Stream at all.']
generate -> exit 1,  Return type must be a Future or a Stream.
```

The guard still cannot pass while the defect is live.

---

## 3. Proof — the docs no longer contradict anything

- The predicate is now a **verbatim quote** of `isEndpointMethod` (3.4.13) rather than a paraphrase.
- `static` is stated three times, consistently: no `isStatic` check, so `static` is not an escape hatch,
  and it is audited.
- `_serverpodExcludedMethodNames` is labelled "the 3.4.13 shape … re-read, not carried over" when the
  pin moves.
- `_returnTypeRejection`'s doc states the verified `Stream<dynamic>` result and the
  `DynamicElementImpl` mechanism, so the asymmetry is documented at the point of use.
- `_publicSessionFirstMethods`' doc explains that including `static` is deliberate and records that the
  previous skip was "true of 4.x and false of the pinned version".
- **No statement in the test contradicts `credential_endpoints.dart:128-132`.** The two files now make
  the same claim for the same reason.

---

## 4. Gates — all re-run at `4f96c78`, all genuinely passing

| Gate | Result |
|---|---|
| `dart pub get` (repo root) | **exit 0** |
| `dart format --output=none --set-exit-if-changed .` | **exit 0** — `Formatted 656 files (0 changed)` |
| `dart analyze apps/server` | **exit 0** — `No issues found!` |
| `dart test test/endpoint_surface_shape_test.dart` (in `apps/server`) | **exit 0** — `+13: All tests passed!` |
| `serverpod generate` | **exit 0** — `✓ Generating code (22.2s) ✅ Done.` |
| generated tree byte-identical | **`2b4ce41aef38…` before and after**, `git diff` empty, **0 untracked** |
| `make test-integration` (primary clone) | **exit 0** — `+192: All tests passed!` |
| `make test-integration` (this worktree) | `+191 −1`, dogfood only — see §6 |

No test was weakened, skipped, `@Ignore`d, filtered or deleted. The guard's assertion count went
**up** (12 → 13 real assertions plus the two new categories it now catches), not down.

**Generated-tree hash note.** My hash `2b4ce41aef38…` is computed as
`find … | sort | xargs shasum | shasum` and is not comparable to the reviewer's `1206d0bd…`, which was
computed differently. Both of mine are before/after on the identical method, and the stronger,
method-independent proof is `git diff --exit-code -- apps/server/lib/src/generated` **empty** with **0
untracked** — which is what I report as the result.

---

## 5. Constraints — verified

| Constraint | Evidence |
|---|---|
| `apps/server/migrations/**`, `tool/**`, `lib/src/generated/**`, `lib/server.dart` untouched | `git diff --exit-code effc537..HEAD -- <paths>` → clean |
| `packages/**`, `apps/control_plane/**`, `docker/**`, `.github/**` untouched | same diff → clean |
| **One file changed** | `git diff --name-only effc537..HEAD` → `apps/server/test/endpoint_surface_shape_test.dart` |
| Nothing weakened / skipped / ignored | assertion count up; no skip/ignore token introduced |
| No key material printed or logged | the change is a test file; no `print`/`log` added |
| Zero mutating Docker/Compose commands | only label-filtered read-only `docker ps -aq` leak checks. Never `clean`, `qa-down`, `test-env-down`, `e2e-down`, `down -v` |
| `make test-integration` is the only DB path | used it; both runs self-cleaned |
| No leaked test resources | after both runs: `docker ps -aq --filter label=com.docker.compose.project \| grep integration` → **empty** |
| Parallel lane protected | generate rewrote `packages/control_plane_client/…/client.dart` (`4ad9a077…`→`3208b872…`) exactly as disclosed; restored with `git checkout --`, hash back to **`4ad9a077…`**, worktree pristine |
| Throwaway mutation clone removed | `rm -rf` after the matrix |
| Reviewed worktree left pristine | `git status --porcelain --untracked-files=all` → empty, HEAD `4f96c78` |

**Provenance:** `effc537ad504cf94693d70e1974fa1c3b278087f` → **`4f96c78c9ffd65a9d1bafcdb65c4d12128a0ec3e`**,
one new commit on top, no history rewritten, no push, no merge, `main` untouched.

---

## 6. Correction to the record — the dogfood baseline

**Original claims in earlier reporting on this branch (quoted, not deleted):**

- The dispatch `fix-generate-and-hostkey-config/prompt.md:99-102` states: *"`make test-integration` is
  **known red and approved**: `+191 -1` against a base of `+170 -2`, sole failure
  `dogfood_shipit_postgres_test.dart`, pre-existing … Cause: a 43 098 ms `git archive` walk against the
  30 s `dart test` default."*
- My own earlier report on this task repeated that attribution and carried the `+191 -1` figure
  forward as this branch's approved baseline.

**Both are wrong, and the re-review was right to stop them being persisted.** I measured the same HEAD
in both environments at `4f96c78`:

| Environment | `.git` | Result |
|---|---|---|
| This worktree `/private/tmp/shipit-impl-keys` | **75-byte file** | `+191 −1`, dogfood only |
| Primary clone (same HEAD) | **directory** | **`+192: All tests passed!`**, exit 0 |

The worktree failure is `dogfood expects a git working tree at /private/tmp/shipit-impl-keys`
(`Directory('${repoRoot.path}/.git').existsSync()` is **false** for a file), thrown **before** the
`git archive` at `:107` is reached — so in a worktree the 30 s timeout is unreachable, not marginal.

**The 43 098 ms figure is not reproducible.** Dogfood here completed inside the green clone run; the
suite finished in 92 s and the test's own visible progress spanned ~7 s, nowhere near 30 s. Whatever
produced 43 098 ms was a contended run, not a property of the test.

**Persisted characterisation:** `dogfood_shipit_postgres_test.dart` is **not** structurally unrunnable.
It fails **only in linked git worktrees** (deterministic, load-independent, short-circuits before the
archive). In a full checkout this HEAD is **fully green: `+192`.** `+191 −1` is a **worktree artefact**
and is **not** this branch's baseline. A **separate, latent** 30 s `package:test` default-timeout risk
still exists on the archive body and did not fire; that is the real, smaller finding.

**Consequence for the record: the approved baseline for `impl/credential-key-service` is `+192`, not
`+191 −1`, and not `+170 −2`.** I did not "fix" dogfood — it is unrequested scope in `packages/**` and
outside this correction.

---

## 7. Open findings I cannot close — routed, not attempted

`.github/workflows/**` is PROHIBITED to this lane, so I made **no workflow edits**. Both remain open.

**F-A — No CI job runs the guard test. (non-blocking, but it nullifies the guard's enforcement value)**
Verified: `integration.yaml:139` runs `dart test test/integration/` only; `ci.yaml:60-61` excludes
`apps/server` ("covered by integration.yaml … so neither belongs here"). The guard lives in
`apps/server/test/`, so nothing executes it.
*Exact change needed:* either (a) add a job/step to `integration.yaml` running
`dart test test/endpoint_surface_shape_test.dart` from `apps/server` (it needs no database, so
`integration.yaml` is a valid host despite its name), or (b) extend `ci.yaml`'s pure-Dart job with an
`apps/server` matrix entry — note (b) contradicts the stated reason for the exclusion (apps/server needs
Postgres), so **(a) is the correct one**. Owner: whoever holds `.github/**`.

**F-B — No gate runs `serverpod generate`. This is the root cause of the whole class.**
Verified: `grep -rin generate .github/workflows/` returns only unrelated comments about schema
generation. The guard is a partial backstop; only a gate on generate's exit status is complete.
*Exact change needed:* a CI step in `integration.yaml` (which already has a `postgres` service and the
`SERVERPOD_DATABASE_PASSWORD` secret) that runs `dart pub get && cd apps/server && dart run
serverpod_cli generate` and then **fails if `git diff -- apps/server/lib/src/generated` is non-empty**
— i.e. assert generate exits 0 *and* is idempotent, which is the property BLOCKER-1 actually violated.
Run it in a checkout, never a worktree. Owner: whoever holds `.github/**`.

**F-C — guard narrower than the full generator rule (carried forward honestly).** The guard encodes the
endpoint-method predicate and `_validateReturnType`. It does not encode `_validateUnauthenticatedAnnotation`
(`@unauthenticatedClientCall` on a class overriding `requireLogin` — an **info** severity, so it does not
fail generate), nor `TypeDefinition.fromDartType` on the type argument rejecting types whose class name
cannot be determined. `_isMarkedDoNotGenerate` still inspects only the nearest non-blank line above the
declaration (re-review follow-up 5; unchanged, no current code affected). F-B is the real answer.

**F-D — `dogfood_shipit_postgres_test.dart:88` is worktree-hostile.** Deterministic failure in any linked
worktree. Not fixed (unrequested scope, `packages/**`). Worth routing to the dogfood owner: `File.existsSync() || Directory.existsSync()` would make the suite checkout-agnostic.

---

## 8. Classifications (`aef-repository-learning`)

- **`RUNTIME_DISCOVERY` / `PROJECT_FACT` — persisted in this report (§6).** `dogfood_shipit_postgres_test.dart` fails only in linked worktrees; `+192` is the baseline at `4f96c78`. Evidence: two runs, same HEAD, differing only in `.git` kind. Within my authority to record as operational knowledge.
- **`PROJECT_FACT` — serverpod_cli 3.4.13 return-type rules are asymmetric.** `Future<dynamic>` is rejected, `Stream<dynamic>` is accepted and generates a client stream method; `Future<void>` accepted, `Stream<void>` rejected; `isEndpointMethod` has no `isStatic` check. Recorded in §1 and **encoded executable in the guard** rather than prose, which is the policy's preferred form.
- **`WORKFLOW_IMPROVEMENT` (needs independent review, not mine to persist).** F-A and F-B: add a CI job for the guard and a CI gate on generate's exit status + idempotence.
- **`CONTRADICTION` — resolved in favour of the re-review (§6).** Earlier `+191 -1` / `+170 -2` / 43 098 ms claims were wrong; quoted and corrected, not deleted.
- **`AUTOMATION_OPPORTUNITY`.** `make test-integration` requires `SERVERPOD_DATABASE_PASSWORD` to be exported by the caller and fails with exit 2 otherwise, while `docker/compose.test.yaml` already commits the disposable test password. A default in the recipe (or a `.env.example` line) would remove a foot-gun that reads like a missing dependency. Not changed — Makefile is outside this correction's ownership.
- **Not persisted / EPHEMERAL:** the hash-method difference between `2b4ce41a…` and `1206d0bd…` (§4).

---

## 9. Result

```
RESULT: CORRECTION_COMPLETE

CORRECTED_FROM_HEAD: effc537ad504cf94693d70e1974fa1c3b278087f
NEW_HEAD: 4f96c78c9ffd65a9d1bafcdb65c4d12128a0ec3e

FINDINGS_ADDRESSED:
  BLOCKER-1 (guard fails open on `static`; documents a FALSE predicate):
    FIXED. Deleted the static skip at the old :189 so static Session-first
    declarations are audited. Replaced the paraphrase at :21-25 with a VERBATIM
    quote of serverpod_cli 3.4.13 `EndpointMethodAnalyzer.isEndpointMethod`,
    stating in bold that 3.4.13 has no `isStatic` check, that 4.0.3 added one and
    dropped `_excludedMethodNameSet`, and that `static` is therefore NOT an escape
    hatch. `_serverpodExcludedMethodNames` annotated as the 3.4.13 shape.
    Now consistent with credential_endpoints.dart:128-132, and the two files can
    no longer disagree because both derive from the same source.
    PROVEN: `static SecretProvider f(Session)`, analyzer-clean -> guard exit 1 AND
    generate exit 1 ("Return type must be a Future or a Stream."). Was a false
    negative at effc537.

  BLOCKER-2 (_isFutureOrStream narrower than _validateReturnType):
    FIXED. `_isFutureOrStream` replaced by `_returnTypeRejection`, reproducing
    `_validateReturnType`: exactly one type argument; bare `dynamic` rejected ON A
    `Future`; `Stream<void>` rejected while `Future<void>` is accepted. It returns
    the rejection REASON, because the old message would have said "returns
    Future<dynamic>, not Future or Stream" about a Future — a false statement of
    the same class this correction closes.
    PROVEN: `Future<dynamic> f(Session)`, analyzer-clean -> guard exit 1 AND
    generate exit 1 ("Return generic must have a type defined."). Was a false
    negative at effc537.
    SCOPE CORRECTION: the fix is "require a non-dynamic type argument ON A
    Future", not on both containers. `Stream<dynamic>` generates successfully and
    emits a real client streaming method (measured: generate exit 0, 2 references
    in client.dart); mechanism is `DynamicTypeImpl.element` =
    `DynamicElementImpl.instance`, whose displayName is `dynamic`, not null, so
    `TypeDefinition.fromDartType` does not throw. My first implementation
    over-strictly rejected it; the empirical run corrected me before commit.

FILES_CHANGED:
  apps/server/test/endpoint_surface_shape_test.dart   (+136 -20)
  # the ONLY file. No production change. Verified by `git diff --name-only effc537..HEAD`.

GATES:
  format=pass   (dart format --output=none --set-exit-if-changed . -> "Formatted 656 files (0 changed)", exit 0)
  analyze=pass  (dart analyze apps/server -> "No issues found!", exit 0)
  tests=pass    (dart test test/endpoint_surface_shape_test.dart -> "+13: All tests passed!", exit 0;
                 8/8 mutation matrix agrees with `serverpod generate`;
                 T1 negative control: guard exit 1 + generate exit 1 with the
                 @doNotGenerate line removed; assertions INCREASED 12 -> 13, nothing
                 weakened/skipped/ignored;
                 make test-integration in a primary clone at this HEAD -> "+192: All
                 tests passed!", exit 0; in this linked worktree -> "+191 -1",
                 dogfood only, the worktree artefact corrected in §6)
  build=pass    (serverpod generate -> exit 0, "✓ Generating code (22.2s) ✅ Done.";
                 lib/src/generated/** byte-identical: 2b4ce41aef38… before and after,
                 git diff empty, 0 untracked; parallel lane's client.dart restored to
                 4ad9a077…, worktree pristine)
  runtime=pass  (both make test-integration runs self-cleaned; leaked integration
                 projects after both runs: 0 containers; throwaway mutation clone removed;
                 QA stack never touched — zero mutating Docker/Compose commands issued)

NEW_DISCOVERIES:
  - serverpod_cli 3.4.13 return-type validation is ASYMMETRIC between Future and
    Stream: Future<dynamic> rejected, Stream<dynamic> accepted (and it generates a
    client stream method); Future<void> accepted, Stream<void> rejected. Encoded
    executable in the guard. PROJECT_FACT.
  - `analyzer-10.2.0` `DynamicTypeImpl.element` is `DynamicElementImpl.instance`,
    whose displayName is `dynamic` — NOT null — so `TypeDefinition.fromDartType`
    does not throw for `dynamic`. This is the mechanism behind the asymmetry, and
    it contradicts the obvious reading of the generator source. PROJECT_FACT.
  - No CI job runs apps/server/test/ at all (integration.yaml:139 runs only
    test/integration/; ci.yaml:60-61 excludes apps/server), and no workflow runs
    `serverpod generate`. F-A / F-B in §7, routed with the exact change each needs;
    NOT attempted, .github/** is PROHIBITED. WORKFLOW_IMPROVEMENT.
  - dogfood baseline corrected to `+192` in a checkout; `+191 -1` and the 43 098 ms
    figure are not reproducible and must not be persisted. RUNTIME_DISCOVERY.
  - `make test-integration` needs the caller to export SERVERPOD_DATABASE_PASSWORD
    (exit 2 otherwise) even though docker/compose.test.yaml commits the disposable
    test password. Foot-gun. AUTOMATION_OPPORTUNITY, not changed (out of ownership).

READY_FOR_FOCUSED_REVIEW: YES
```

**Not self-approved.** Two things the re-review should check first, because they are where I departed
from the literal instruction: (1) the **`Stream<dynamic>` asymmetry** in §1 — a literal reading of
BLOCKER 2 would have shipped a false alarm; (2) that dropping the `static` skip did **not** over-correct,
proven by M5 (`static` with a valid return type still passes). Plus the §6 record correction, which
supersedes a figure the dispatch itself carried.

**SAFE_PARALLEL_WORK**
- `apps/server/test/**` other files, and any `apps/server` test under `test/integration/` — read/append only; do not touch `endpoint_surface_shape_test.dart`.
- `apps/server/lib/src/endpoints/**` other than `credential_endpoints.dart` — safe to read; a new endpoint file is fine (the floor is `>= 12` audited files, so adding one is expected and does not need this test's update).
- `docker/**` text-only edits, and `apps/control_plane/**` — no overlap with this correction's single file.
- Any lane that does NOT need `serverpod generate` in this worktree.

**PROHIBITED_PARALLEL_WORK**
- `apps/server/test/endpoint_surface_shape_test.dart` — this correction's only file, under review.
- **`serverpod generate` run from `/private/tmp/shipit-impl-keys`** — it rewrites
  `packages/control_plane_client/lib/src/protocol/client.dart`, which belongs to another lane. If you must
  run it: `git checkout -- packages/control_plane_client/lib/src/protocol/client.dart` afterwards and
  confirm the hash returns to `4ad9a077…`. (I ran it three times and restored it each time.)
- Mutating Docker/Compose of any kind — `make clean`, `qa-down`, `test-env-down`, `e2e-down`, bare `down -v` — including in a throwaway clone. Note the throwaway clone used for the mutation matrix ran `generate`, so **never** run `make test-integration` there: its compose files resolve to project `docker`, the live QA stack. Use `make test-integration` from `/private/tmp/shipit-impl-keys` (self-cleaning, project `shipit_integration_<pid>`), which is what produced both §6 numbers.
- `apps/server/lib/src/endpoints/credential_endpoints.dart` — do not remove or move `@doNotGenerate` without re-running the guard; the §2 T1 control shows the defect returns the moment it goes.