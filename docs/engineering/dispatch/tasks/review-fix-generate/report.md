# Focused re-review — fix-generate-and-hostkey-config (BLOCKER-1 only)

```yaml
REVIEWED_HEAD: effc537ad504cf94693d70e1974fa1c3b278087f
CORRECTED_FROM_HEAD: 7d1b1b8abdf5cbfbb7b48dc9682baf3bfb99090c
BRANCH: impl/credential-key-service
WORKTREE: /private/tmp/shipit-impl-keys
SCOPE: BLOCKER-1 only. BLOCKER-3 ignored by instruction.
RESULT: DO_NOT_APPROVE_CORRECTIONS
```

Provenance verified independently: `git rev-parse HEAD` = `effc537ad504cf94693d70e1974fa1c3b278087f`,
branch `impl/credential-key-service`, tree clean before and after my review. Matches the report.

**The fix is correct and BLOCKER-1 is genuinely fixed.** One blocker remains, and it is in the
correction's own new deliverable: the guard test ships a *false* statement about the pinned
generator's predicate, and it fails open on exactly the alternative the production doc comment
warns is fatal. Two lines to fix.

---

## 1. The fix actually works — VERIFIED

Ran it myself in the reviewed worktree.

```
$ cd apps/server && dart run serverpod_cli generate
⠋ Generating code...
✓ Generating code (19.6s)
✅ Done.
EXIT_CODE=0
```

| Check | Result |
|---|---|
| `apps/server/lib/src/generated/**` tree hash **before** | `1206d0bddbabbc5506b6c6e82fcc7a0886cf6c4119487ee1ac7db6c7a532e5d0` |
| same tree hash **after** | `1206d0bddbabbc5506b6c6e82fcc7a0886cf6c4119487ee1ac7db6c7a532e5d0` |
| `git diff -- apps/server/lib/src/generated` | empty |
| untracked files under `lib/src/generated` | 0 |

Byte-identical, exit 0. The lane's acceptance criterion 1 is **proven**.

**Parallel lane protected, as instructed.** Generate did rewrite
`packages/control_plane_client/lib/src/protocol/client.dart` (`4ad9a077…` → `3208b872…`), exactly
as the report disclosed. Restored with `git checkout --`; hash back to `4ad9a077…`;
`git status --porcelain --untracked-files=all` empty; HEAD still `effc537`. Worktree left pristine.

## 2. `@doNotGenerate` is the right mechanism on 3.4.13 — VERIFIED

Read out of the pinned source, not taken on trust.

- `serverpod_shared-3.4.13/lib/src/annotations.dart`: `const doNotGenerate = _DoNotGenerate();`
  annotated `@Target({TargetKind.classType, TargetKind.method})`. Exists; targets methods.
- `serverpod_cli-3.4.13/.../endpoint_analyzers/annotation.dart:34,43`: `'doNotGenerate'` is
  mapped into `endpointAnnotations`, and `markedAsIgnored => endpointAnnotations.has('doNotGenerate')`.
- `serverpod_cli-3.4.13/.../endpoint_method_analyzer.dart:79-86`:

  ```dart
  static bool isEndpointMethod(MethodElement method) {
    if (method.isPrivate) return false;
    if (method.markedAsIgnored) return false;
    if (_excludedMethodNameSet.contains(method.name)) return false;
    return method.formalParameters.isFirstRequiredParameterSession;
  }
  ```

  `markedAsIgnored` is honoured, at the method element. Applied correctly.

**The lane's `static` claim, checked independently — it is CORRECT.**

- 3.4.13 `isEndpointMethod` (above): **no `isStatic` check**.
- 4.0.3 `isEndpointMethod`: `if (method.isStatic) return false;` — added in 4.x, as claimed.
- Empirically, in a throwaway clone, I replaced the method with a compiling
  `static SecretProvider recordCustodyPrecondition(Session session) { … }`.
  `dart analyze` → *No issues found!*. `serverpod generate` →
  `Error on line 143, column 25 … Return type must be a Future or a Stream.` **EXIT 1.**

So `static` is not merely a worse alternative — it is **worse than the defect it was proposed to
replace**, and rejecting it was correct and important.

## 3. The alternatives were rejected for the right reasons — VERIFIED

**`private` — correctly rejected, and on the right ground.** It does satisfy the generator
(generate exits 0), so the rejection is *not* on generator grounds; it is on the seam, and the
seam is real. Applying `_recordCustodyPrecondition` in a throwaway clone:

```
$ dart analyze test/integration/credential_key_service_postgres_test.dart
error - :693:39 - The method 'recordCustodyPrecondition' isn't defined …
error - :708:13 - The method 'recordCustodyPrecondition' isn't defined …
```

Exactly the two call sites the lane cited, broken by Dart's library-level privacy — the integration
test is a different library. `lib/server.dart` has no `part`/`part of`, so it is a different library
too, and it does not reference the endpoint today (the seam is documented-future in the code comment
at `:96-101`, which is honest; the report's prose compresses it to present tense — cosmetic only).

So the annotation **expresses** a real constraint rather than suppressing an inconvenient one. That
is the right shape of fix.

---

## 4. THE GUARD TEST — load-bearing: YES. Generalising: NO. See BLOCKER.

I reproduced the defect in a throwaway clone (`git clone --no-hardlinks` at `effc537`), never in the
reviewed worktree, deleting only the annotation line:

```
$ perl -0pi -e 's/^  \@doNotGenerate\n//m' lib/src/endpoints/credential_endpoints.dart
$ dart test test/endpoint_surface_shape_test.dart
00:00 +12 -1: Some tests failed.
  Failing tests:
    … CredentialEndpoints exposes no endpoint method the generator would reject
  Expected: <offenders is empty>
    Actual: ['CredentialEndpoints.recordCustodyPrecondition returns SecretProvider, not Future or Stream']
GUARD_EXIT=1

$ dart run serverpod_cli generate
ERROR: Found 1 issue.
Error on line 143, column 18 … Return type must be a Future or a Stream.
GENERATE_EXIT=1
```

**The guard fails on exactly the declaration the generator rejects.** Perfect correlation, same
method, same message. The test cannot pass while the defect is live — which is precisely what the two
discarded drafts got wrong, and the lane was right to discard them rather than ship a green guard.

**Syntactic, not `dart:mirrors` — verified.** Probing with a throwaway file:

```
error - _probe_mirrors.dart:1:8 - Target of URI doesn't exist: 'dart:mirrors'. - uri_does_not_exist
```

The lane's claim holds exactly. The cited precedent exists
(`apps/server/test/credential_keypair_test.dart:115`).

**The 6-case matrix (T0–T6) — the parts I could reproduce, I did; the shape claims hold.**

| Mutation | Guard | Generator |
|---|---|---|
| T0 baseline (fix in place) | PASS (13 tests) | exit 0 |
| T1 `@doNotGenerate` removed | **FAIL**, right reason | **exit 1** |
| T2 — | not re-run (matrix credible; T1/T0 bracket it) | — |
| T3/T4 new `void` / `Map` `Session`-first | not re-run | — |
| T5 annotated non-endpoint | not re-run | — |
| **NEW: `static` non-Future `Session`-first** | **PASS** ← false negative | **exit 1** |
| **NEW: `Future<dynamic> … (Session)`** | **PASS** ← false negative | **exit 1** |

---

## BLOCKER-1 (blocking) — the guard fails open on `static`, and documents a predicate that is false for the pinned version

`apps/server/test/endpoint_surface_shape_test.dart`

- **`:23`** (doc comment) asserts the predicate: *"it is public, **not `static`**, not
  `@doNotGenerate`, not one of Serverpod's own excluded names…"*
- **`:189`** implements it: `if (match.namedGroup('mods')!.contains('static')) continue;`
- **`credential_endpoints.dart:128-132`** (same commit) asserts the exact opposite: *"`static` does
  not work at all. In `serverpod_cli` 3.4.13 … `isEndpointMethod` has no `isStatic` check (4.x added
  one), so a static method with `Session` first is still discovered and still fails."*

Two files, one commit, mutually exclusive claims — and the test's is the **wrong** one for the pinned
version, as the generator run above proves. This is the trap the fix exists to prevent: a future lane
reading the guard's doc comment concludes `static` is a safe escape hatch, writes one, and
`serverpod generate` exits 1 again with the guard still green. The guard has a **false negative on
one of the three alternatives it was written to adjudicate.**

**Second, same function, same class of gap — `_isFutureOrStream` (`:171-173`) accepts anything
matching `^(?:Future|Stream)\b`.** The generator additionally rejects a missing or `dynamic` type
argument (`_validateReturnType`: `typeArguments.length != 1` → *"Return generic must be type
defined"*, and `innerType is DynamicType` → same). Verified:

```
Future<dynamic> dynamicReturn(Session session) async => null;
  guard   -> PASS (not reported)
  generate -> Error … Return generic must have a type defined. E.g. Future<String>.   exit 1
```

**Required fix (both in `endpoint_surface_shape_test.dart`, ~3 lines):**

1. Delete the `static` skip at `:189` so static `Session`-first methods are audited.
2. Correct the predicate comment at `:21-25` to match 3.4.13: no `isStatic` check (and note 4.x
   added one *and* removed `_excludedMethodNameSet` — see follow-up 3).
3. Extend `_isFutureOrStream` to require a type argument that is neither absent nor `dynamic`.

## 5. Future-work false negatives — the other half of the picture

Honest assessment, stated plainly:

- The guard **generalises** on the shape it covers: any public, non-`@doNotGenerate`, `Session`-first
  method with a non-`Future`/`Stream` return is caught, across all 12 endpoint files, not just the one
  that broke.
- It **does not generalise** to the full generator rule. It is narrower than the rule it claims to
  encode, in the two places above. A real CI gate on `serverpod generate`'s exit status remains the
  only complete backstop — and the lane says so, unprompted, as discovery #3.
- No gate runs the guard at all. See follow-up 1.

## 6. BLOCKER-2 correctly left alone — VERIFIED

The entire diff to `credential_endpoints.dart`, stripped of `///` lines, is one line:

```
+  @doNotGenerate
```

No ordering change. Decision `.decisions/898b07d0-e848-4774-8007-f4dacbd89c78.yaml` confirmed:
`status: RESOLVED`, `selected_option: OPTION_A`, rationale verbatim — *"The key flow creates the
Product row (state registered) plus the RepositoryReference as an explicit first step; 'Register
product' then commits credential verification."* The lane's quotation is exact. No action was
correct.

---

## Constraints — all honoured

| Constraint | Verified |
|---|---|
| `apps/server/migrations/**`, `tool/**`, `lib/src/generated/**`, `lib/server.dart` untouched | `git diff 7d1b1b8..effc537 -- <paths>` **empty** |
| `packages/**`, `apps/control_plane/**`, `docker/**` untouched | same diff, **empty** |
| Nothing weakened / skipped / `@Ignore`d / filtered / deleted | no such token in the added lines |
| No key material printed or logged | new test contains no `print`/`log`; endpoint change is doc + annotation only |
| `dart format --output=none --set-exit-if-changed .` | **exit 0** — `Formatted 656 files (0 changed)` |
| `dart analyze apps/server` | **exit 0** — `No issues found!` |
| Zero mutating Docker/Compose commands | only `docker ps` / `volume ls -q` / `network ls -q`, label-filtered. Never `clean`, `qa-down`, `test-env-down`, `e2e-down`, `down -v` |
| QA stack undisturbed | `docker-postgres-1 Up 23 hours (healthy)` after every run |
| `make test-integration` cleanup | my two runs: `59636` and `57226` → containers=0 volumes=0 networks=0 |

---

## The disputed point — RESOLVED: **two distinct failure modes**, environment-gated, and only one of them is real

The three accounts were each partly right and none was complete. Measured, on the same HEAD:

| Environment | `.git` | Result |
|---|---|---|
| Linked worktree `/private/tmp/shipit-impl-keys` | **75-byte file** | `+191 -1: Some tests failed` — dogfood only |
| Primary clone (throwaway) | **directory** | **`+192: All tests passed!`** |

Worktree failure, verbatim:

```
Expected: true
  Actual: <false>
  dogfood expects a git working tree at /private/tmp/shipit-impl-keys
  test/integration/dogfood_shipit_postgres_test.dart 87:11
```

**Mode A — deterministic, and gated on being in a linked worktree.** `:88` asserts
`Directory('${repoRoot.path}/.git').existsSync()`. Confirmed with Dart: `Directory.existsSync()` on a
file is **false** (`File.existsSync()` is `true`). This throws at `:87-91`, *before* `git archive` at
`:107` is reached — so in a worktree the test can never get far enough for anything else to matter.

**Mode B — load-sensitive, and only reachable where Mode A cannot fire.** `Process.run` at `:107`
carries no timeout of its own; the 30 s ceiling is package:test's default per-test timeout
(`test_api-0.6.17`/`0.7.x` `lib/src/backend/invoker.dart:278` → `const defaultTimeout = Duration(seconds: 30)`),
and `apps/server/dart_test.yaml` sets no override.

**Mode B does not reproduce.** The identical command, both environments:

```
git archive --format=tar HEAD | tar -x -C "$T"
worktree: real 1.24s      clone: real 1.64s
```

The dogfood test itself took ~10 s wall in my clone run. The prior reviewer's **43 098 ms** walk
against the 30 s default is **not reproducible under normal load** — 30× more than measured here; it
was almost certainly taken while several `serverpod_cli generate` / analyzer runs were competing, or
misattributed. The integrator's fully-green run is exactly what I reproduced deterministically.

### The characterisation that must be persisted instead

> `dogfood_shipit_postgres_test.dart` is **not** structurally unrunnable. It fails **only in linked
> git worktrees**, where `.git` is a file and `:88`'s `Directory.existsSync()` assertion cannot hold —
> deterministic and load-independent there, and it short-circuits before `git archive` is reached.
> In a full checkout the same HEAD is **fully green: `+192 All tests passed!` at `effc537`**.
> A **separate, latent** 30 s `package:test` timeout risk exists on the archive body and did not fire;
> the 43 098 ms figure previously recorded is not reproducible at 1.3–1.6 s measured.

**Corollary that matters more than the mechanism:** `+191 -1` is a **worktree artefact**, not this
branch's baseline. Recording it as the approved baseline bakes an environmental failure into the
durable record. The honest baseline at `effc537` is **`+192`, fully green, in a checkout**.

---

## Non-blocking follow-ups (do not gate merge)

1. **No gate runs the new guard.** `ci.yaml:60-61` excludes `apps/server` explicitly (*"covered by
   integration.yaml … so neither belongs here"*) and `integration.yaml:139` runs only
   `dart test test/integration/`. The guard lives in `apps/server/test/`, so **no CI job executes it**.
   The lane disclosed this (discoveries #3, #6) rather than hiding it — good — but the guard's
   enforcement value today is manual-only. Recommend moving/duplicating it under `test/integration/`
   (it needs no database, so it would run there) or adding a `dart test test/` job for `apps/server`.
2. **No gate runs `serverpod generate`.** Confirmed: `rg -i "generate" .github/workflows/` → nothing.
   The root cause of BLOCKER-1 is still open in CI. The guard is a partial backstop only.
3. **Version drift in `_serverpodExcludedMethodNames` (`:158-165`).** It is a verbatim 3.4.13 copy;
   4.0.3 dropped `_excludedMethodNameSet` entirely. Harmless today (it only ever *skips*), but the
   list should be annotated as "3.4.13 shape" alongside the predicate comment.
4. **Meta-test floor is exactly today's count.** `greaterThanOrEqualTo(12)` with 12 endpoint files on
   disk catches narrowing to fewer (verified: narrowing the glob to one file fails with
   `Actual: <1>`), but if a 13th file is added, narrowing 13 → 12 still passes. Low value, low cost
   to leave.
5. `_isMarkedDoNotGenerate` (`:298-313`) only inspects the nearest non-blank line above the
   declaration, so a method carrying two annotations with `doNotGenerate` not nearest would be a
   false positive. No current code is affected.

---

## Verdict

BLOCKER-1 is fixed and I verified it independently and end-to-end: generate exits 0, the generated
tree is byte-identical, `@doNotGenerate` is the correct and correctly-placed mechanism on pinned
3.4.13, `static` genuinely does not work (proved by running it), `private` genuinely breaks the seam
(proved by the analyzer), BLOCKER-2 is untouched, and the guard is genuinely load-bearing (proved by
reproducing the defect). The lane's negative-control discipline was the right instinct and both
discarded drafts were correctly thrown away.

It is not approvable as written, for one reason only: the new guard documents a predicate that is
false for the pinned generator and skips `static`, so it passes a change that breaks
`serverpod generate` — and it contradicts the production comment added in the same commit. Persisting
a wrong fact about the exact trap this correction exists to close is the one outcome worse than having
no guard. The fix is three lines in one test file and does not touch the production change.

```
RESULT: DO_NOT_APPROVE_CORRECTIONS

REVIEWED_HEAD: effc537ad504cf94693d70e1974fa1c3b278087f

FINDINGS_REVIEWED:
  BLOCKER-1: FIXED AND VERIFIED — serverpod generate exit 0 (ran it; "✓ Generating code (19.6s)
  ✅ Done."), generated tree byte-identical 1206d0bd… before/after, 0 untracked,
  parallel lane's client.dart rewritten then restored, worktree pristine.
  - @doNotGenerate exists in serverpod_shared 3.4.13, @Target({classType, method}),
    isEndpointMethod honours markedAsIgnored. Correctly applied to the METHOD.
  - `static` claim VERIFIED CORRECT: 3.4.13 has no isStatic check (4.0.3 added it); a compiling
    static variant still fails generate with exit 1.
  - `private` correctly rejected: generate would pass, but analyze breaks
    credential_key_service_postgres_test.dart:693 and :708. Seam is real.
  - GUARD IS LOAD-BEARING: annotation removed in a throwaway clone -> guard FAILS with
    "returns SecretProvider, not Future or Stream" AND generate exits 1 on the same declaration.
  - Syntactic not dart:mirrors: verified (dart analyze -> uri_does_not_exist).
  BLOCKER-2: NO ACTION, CORRECT — diff is one executable line (@doNotGenerate); decision
    898b07d0 RESOLVED/OPTION_A confirmed verbatim; no ordering change.

REGRESSIONS:
  NONE to previously-approved areas. migrations/tool/generated/server.dart/packages/
  apps/control_plane/docker all untouched; no test weakened, skipped, ignored, filtered or
  deleted; no key material printed or logged; format exit 0 (656 files, 0 changed);
  analyze exit 0; QA stack Up 23 hours (healthy); both test-integration projects cleaned 0/0/0.

BLOCKERS:
  1. endpoint_surface_shape_test.dart fails open on `static` and documents a FALSE predicate.
     :23 claims the rule includes "not static"; :189 skips static members; but
     credential_endpoints.dart:128-132 (same commit) correctly states 3.4.13 has NO isStatic check.
     Verified: `static SecretProvider f(Session)` -> guard PASSES, generate EXITS 1. The guard has a
     false negative on one of the three alternatives it was written to adjudicate.
     FIX: delete the static skip at :189; correct the predicate comment at :21-25 to the 3.4.13 rule.

  2. _isFutureOrStream (:171-173) is narrower than the generator's rule. Verified:
     `Future<dynamic> f(Session)` -> guard PASSES, generate EXITS 1 with "Return generic must be
     type defined." Same class, same function.
     FIX: require a type argument that is neither absent nor `dynamic`.

  DISPUTED POINT RESOLVED — TWO distinct, environment-gated failure modes:
    Mode A (deterministic): .git is a 75-byte FILE in a linked worktree; :88's
      Directory.existsSync() is false; throws BEFORE the archive at :107. Load-independent.
    Mode B (load-sensitive): package:test default 30s timeout (test_api invoker.dart:278);
      dart_test.yaml sets no override. Reachable ONLY in a full checkout.
    MEASURED BOTH SIDES AT THE SAME HEAD effc537:
      worktree -> +191 -1 (dogfood, mode A message verbatim)
      primary clone -> +192 All tests passed! (mode A unreachable, mode B did not fire)
    The 43 098 ms archive figure is NOT REPRODUCIBLE: identical command measured 1.24 s (worktree)
    and 1.64 s (clone); the test body took ~10 s. The integrator's green run is reproducible.
    CORRECT PERSISTED CHARACTERISATION: the test is not structurally unrunnable — it fails ONLY in
    linked worktrees, and in a checkout this HEAD is FULLY GREEN (+192). Consequence: "+191 -1" is a
    worktree artefact and must NOT be recorded as this branch's baseline.

READY_FOR_MERGE: NO
```

The correction is one focused edit away from approvable. Do not re-review BLOCKER-3 here — it remains
the lane's escalated ownership decision, and this review takes no position on it.
