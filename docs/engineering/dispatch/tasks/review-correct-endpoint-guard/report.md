# Focused re-review — correct-endpoint-guard (BLOCKER-1 and BLOCKER-2)

```yaml
REVIEWED_HEAD: 4f96c78c9ffd65a9d1bafcdb65c4d12128a0ec3e
CORRECTED_FROM_HEAD: effc537ad504cf94693d70e1974fa1c3b278087f
BRANCH: impl/credential-key-service
WORKTREE: /private/tmp/shipit-impl-keys
SCOPE: the two blockers of review-fix-generate, plus regression risk, plus M-4/N-1/F-A/F-B/G-7.
RESULT: APPROVE_CORRECTIONS
```

Provenance verified independently, not taken from the report: `git rev-parse HEAD` =
`4f96c78c9ffd65a9d1bafcdb65c4d12128a0ec3e`, `HEAD^` = `effc537ad…`, `git status --porcelain
--untracked-files=all` empty before and after my review, and
`git diff --name-only effc537..HEAD` returns exactly one path
(`apps/server/test/endpoint_surface_shape_test.dart`, +136 −20). All three match the report.

---

## Verdict in one line

Both blockers are **genuinely closed**, not merely claimed: I reproduced every previously-false-negative
against `serverpod generate` myself and got full guard/generator agreement. The lane's **departure from
my instruction was correct and necessary** — I verified it empirically and at source. One factual error
in the report's own prose (`12 → 13`) does not affect the verdict.

---

## 1. BLOCKER 1 — the `static` fail-open and the false predicate — CLOSED

| Claim | My verification |
|---|---|
| `static` skip deleted | Yes. `git diff` shows the removal of `if (match.namedGroup('mods')!.contains('static')) continue;` and nothing replaces it. |
| `static SecretProvider f(Session)` now fails the guard | Yes — **guard exit 1**, message `CredentialEndpoints.probeStaticNonFuture returns SecretProvider — it is not Future or Stream at all.` |
| …and fails generate | Yes — **exit 1**, `Return type must be a Future or a Stream.` |
| Did not over-correct into failing every static member | **M5 `static Future<Map<String, dynamic>>` → guard PASS, generate exit 0.** This is the anti-over-correction proof and it holds. |
| Doc quotes `isEndpointMethod` verbatim | Yes — compared token-by-token against `serverpod_cli-3.4.13/lib/src/analyzer/dart/endpoint_analyzers/endpoint_method_analyzer.dart:79-86`. |
| Doc no longer contradicts the production comment | Yes — both now say "no `isStatic` check in 3.4.13"; the test derives from the same quoted source the production comment cites. |

I re-read the pinned source myself rather than trusting either account. `isEndpointMethod` in 3.4.13
has **no `isStatic` check**, confirming both the production comment and the corrected test doc. The
quote in the test is faithful: the only difference from the source is an added inline comment
`// @doNotGenerate` on the `markedAsIgnored` line and dropped blank lines — an annotation, not a
distortion of the logic. The load-bearing claim is correct.

## 2. BLOCKER 2 — `_isFutureOrStream` was narrower than `_validateReturnType` — CLOSED

- `Future<dynamic> f(Session)` → **guard exit 1** and **generate exit 1**
  (`Return generic must have a type defined. E.g. Future<String>.`).
- The message is now **true**: it says serverpod rejects a bare `dynamic` on a `Future` — it no longer
  asserts "not Future or Stream" *about a `Future`*. That was the right call; the old wording would have
  reintroduced the exact defect class (a false statement from the guard) this correction exists to remove.
- `_returnTypeRejection` is a faithful reproduction of `_validateReturnType`
  (`endpoint_method_analyzer.dart:106-165`), rule for rule: exactly one type argument; `dynamic` rejected
  **only on `Future`**; `void` rejected **only on `Stream`**; `Future<void>` accepted. It returns the
  reason, as claimed.

### The departure from my instruction — **the lane was right, and I would have shipped a false alarm**

I instructed "require a non-dynamic type argument". Applied literally that also rejects `Stream<dynamic>`.
I measured it:

- `Stream<dynamic> f(Session)` → **generate exit 0**, and it emits a real client streaming method.

So the literal rule would have cried wolf on legal code. The lane's narrowed rule — **non-dynamic on a
`Future`** — is correct, and it is not an approximation: it is exactly the generator's condition
`innerType is DynamicType && !dartType.isDartAsyncStream`. I confirmed the cited mechanism at source:
`analyzer-10.2.0` `DynamicTypeImpl.element => DynamicElementImpl.instance`, whose `name` is `'dynamic'`,
so `displayName` is **non-null** and `TypeDefinition.fromDartType` does not throw for `dynamic` on a
`Stream`. One small imprecision: the report says `displayName` *is* `dynamic`; the load-bearing fact is
that it is **non-null** (it actually renders as `<lib>.dynamic`). The conclusion is unaffected, and the
empirical measurement is what carries it.

## 3. Full agreement matrix — independently reproduced

I built a fresh throwaway clone (`git clone --no-hardlinks`, removed afterwards) and injected probes into
`CredentialEndpoints`, running **both** the guard and `serverpod generate` on each. Every probe is
analyzer-clean of compile errors. I first validated the harness with the T1 negative control
(`@doNotGenerate` deleted → guard exit 1 **and** generate exit 1), and discarded an earlier harness whose
injection landed in the wrong class.

| # | Injected declaration | Guard | generate | Agree |
|---|---|---|---|---|
| M1 | `static SecretProvider p(Session)` | **FAIL** | **exit 1** | ✅ |
| M2 | `Future<dynamic> p(Session)` | **FAIL** | **exit 1** | ✅ |
| M3 | `Stream<dynamic> p(Session)` | pass | exit 0 | ✅ (the asymmetry is real) |
| M4 | `Future<Map<String, dynamic>> p(Session)` | pass | exit 0 | ✅ |
| M5 | `static Future<Map<String, dynamic>> p(Session)` | pass | exit 0 | ✅ |
| M6 | `@doNotGenerate static SecretProvider p(Session)` | pass | exit 0 | ✅ |
| M7 | `Future<void> p(Session)` | pass | exit 0 | ✅ |
| M8 | `Stream<void> p(Session)` | **FAIL** | **exit 1** | ✅ |
| M9 | `Future p(Session)` (bare) | **FAIL** | **exit 1** | ✅ *(mine — beyond the report)* |
| M10 | `FutureOr<void> p(Session)` | **FAIL** | **exit 1** | ✅ *(mine)* |
| M11 | `Future<List<Map<String, int>>> p(Session)` | pass | exit 0 | ✅ *(mine — nested generics)* |
| M12 | `Stream<int> p(Session)` | pass | exit 0 | ✅ *(mine)* |
| M13 | `Stream<int>? p(Session)` | pass | exit 0 | ✅ *(mine)* |

**13/13 agreement**, including five cases beyond the report's matrix. M9/M10/M11/M12/M13 are the
generality evidence: the guard reproduces the whole return-type rule, including the bare-`Future`
rejection, the `FutureOr` rejection, nested generics, and a nullable outer `Stream` — it is not fitted to
today's single case.

## 4. Gates at `4f96c78` — re-run by me

| Gate | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | **exit 0** — `Formatted 656 files (0 changed)` |
| `dart analyze apps/server` | **exit 0** — `No issues found!` |
| `dart test test/endpoint_surface_shape_test.dart` | **exit 0** — `+13: All tests passed!` |
| `serverpod generate` (throwaway clone) | **exit 0** — `✓ Generating code (24.3s) ✅ Done.` |
| generated tree byte-identical | **yes** — tree hash `17d8989a673e…` before and after; `git diff` over `apps/server/lib/src/generated` **empty**; no untracked files |
| T1 negative control | guard **exit 1** + generate **exit 1** on the same declaration |

**Generate was run only in the throwaway clone — never in the reviewed worktree.** The parallel lane's
`packages/control_plane_client/lib/src/protocol/client.dart` is untouched at `4ad9a0778297…` and
`git status` is empty. Nothing needed restoring.

## 5. Nothing weakened — confirmed

- **No `expect()` removed.** The only deleted lines are the old predicate `bool _isFutureOrStream…`,
  its two call-site lines, and the `static` skip. `git diff` shows zero removed `expect(`.
- **No `@Ignore`, `@Tags`, `skip:`, `@Skip` introduced** anywhere in the diff.
- **The direction of the one behavioural deletion is a strengthening**: removing the `static` skip makes
  the guard audit *more* declarations, not fewer.
- Test count at `effc537` = 13; at `4f96c78` = 13. Same count, strictly greater coverage.

**One factual error in the report's prose (non-blocking).** The report states the "assertion count went
up (12 → 13)". It did not: both heads run **13** tests. I ran the `effc537` version of the file and got
`+13: All tests passed!`. The substantive claim — *nothing was weakened* — is independently true and
verified above; only the arithmetic in the report is wrong, and it errs toward understating the change.
**Actionable (cosmetic, does not block):** correct "12 → 13" in the record, or replace it with the true
statement: the test count is unchanged at 13 while the set of offenders the guard can catch grows from
{non-Future/Stream} to {non-Future/Stream, `Future<dynamic>`, bare `Future`, `Stream<void>`, and all
`static` declarations}.

## 6. Regression check against previously-approved areas

- The diff is **one test file**. No production code, no `credential_endpoints.dart`, no generated tree,
  no `packages/**`, no `.github/**`, no `docker/**`.
- `credential_endpoints.dart:128-132` is unchanged and remains correct.
- No key material printed or logged; no `print`/log added.
- **Zero mutating Docker/Compose commands were issued by me.** I did not invoke Docker at all — the QA
  stack was not read, started, stopped or disturbed.

## 7. The open items, judged on merits — **none blocks**

**M-4 (custody recorded on first credential call, not at startup) — ACCEPT is correct; does not block.**
ADR 0018's clause (`docs/adr/0018-…md:107-109`) is "Selecting a fallback is a recorded precondition and
is never defaulted silently." It says nothing about *when*. I verified the substantive half directly in
`secret_provider_resolver.dart`: the `switch` has an explicit `default:` arm that **throws**
`SecretProviderNotConfiguredException` (`:94-95`) — there is **no silent default branch**, so the clause
is met on its own terms. What remains is an observability nicety (an operator cannot answer "is QA on
the fallback?" from a log of a deployment that never minted a credential), and the code documents why it
cannot simply move — the destination is a Serverpod session log, which needs a `Session`, and wiring
startup touches `server.dart`, outside the lane's ownership. Non-blocking, unchanged by this correction,
already accepted by the prior review.

**N-1 (dogfood baseline) — the correction record is ACCURATE; it must not be persisted as `+191 −1`.**
I verified the mechanism in the source rather than accepting it: `dogfood_shipit_postgres_test.dart:87-91`
asserts `Directory('${repoRoot.path}/.git').existsSync()`, and `.git` is a **75-byte file** in a linked
worktree — `Directory.existsSync()` is `false` for a file. The throw is at `:87-91`, **before** the
`git archive` at `:107`, so in a worktree the 30 s timeout is unreachable, not marginal. The correction
record's §6 matches the prior review exactly and correctly declines to persist `+191 −1` or the
`43 098 ms` figure. It quoted the superseded claims rather than deleting them and stated the correct
baseline (`+192` in a full checkout). **Accurate, and the right call.** I did not re-run the full
integration suite — that is outside this correction's scope and the figure is already independently
established — but nothing in the record contradicts the source. Non-blocking.

**F-A / F-B (no CI runs the guard; no CI runs `serverpod generate`) — factually confirmed; routing was
correct; neither blocks.** Verified directly: `grep -rin "serverpod.*generate|serverpod_cli"
.github/workflows/` returns only an unrelated comment at `ci.yaml:24`; `ci.yaml:60-61` excludes
`apps/server` with the stated reason *"apps/server is covered by integration.yaml (it needs Postgres)"*;
`integration.yaml:139` runs `dart test test/integration/` only. So nothing executes
`apps/server/test/**`. The lane made **no** workflow edits, which is correct — `.github/**` was
PROHIBITED — and routed each with the exact change it needs. Its judgement that option **(a)** (a step in
`integration.yaml`) is right and option (b) contradicts `ci.yaml`'s own stated reason is **correct**: the
guard needs no database, so the "needs Postgres" justification does not cover it, and bolting it onto the
pure-Dart job would contradict the comment right above it. Good reasoning. These were already
non-blocking follow-ups at `effc537`; the correction did not introduce them. Worth noting as a genuine
strength: the corrected doc comment now carries a "WHAT THIS IS NOT" paragraph stating plainly that no CI
job runs the guard and that a green run does **not** mean generate passes. That converts a silent gap
into a documented one. Non-blocking.

**G-7 (`referenceName` still in the client, and mint also returns a reference) — confirmed open; a
product decision; does not block.** Verified: `referenceName` remains in the generated client models
(`packages/control_plane_client/lib/src/protocol/repository_credential_view.dart:25,42,92,125,171,186,207`
and `apps/server/lib/src/generated/database/repository_credential.dart`), and
`credential_key_service.dart:46,87,106` carries `MintedCredential.referenceName`. Correctly left open as
a product decision, out of scope for a test-file correction, and untouched by it. Non-blocking.

**F-C** (guard narrower than the full rule: `_validateUnauthenticatedAnnotation` — info severity, so it
does not fail generate — and `fromDartType` on the type argument) is honestly disclosed in the correction
and is unchanged. Non-blocking, and correctly attributed to F-B as the real answer.

---

## Constraints — honoured

| Constraint | Verified |
|---|---|
| Read-only w.r.t. production code | No file in the reviewed worktree was written. |
| Leave the reviewed worktree pristine | `git status --porcelain --untracked-files=all` empty; HEAD `4f96c78`; `client.dart` = `4ad9a0778297…` |
| Do not disturb the parallel lane's `client.dart` | Generate was run **only** in a throwaway clone. Nothing to restore. |
| Zero mutating Docker/Compose | No Docker command issued at all. QA untouched. |
| Use a throwaway clone for mutation experiments | `git clone --no-hardlinks` in the session temp dir, `rm -rf`'d afterwards. |

---

## One process note worth recording

My first probe harness produced a **false PASS on generate** for every probe including `M1` and `M2` —
i.e. it appeared to prove the guard *disagreed* with the generator. The cause was mine: I injected into
the file's **last** `}`, which belongs to `_UnresolvedProvider`, not `CredentialEndpoints`, so the probes
were never endpoint methods and the generator had nothing to validate. The T1 control caught it. This is
the same failure mode as the original defect — a probe that does not exercise the code path looks exactly
like a clean result — and it is the reason the T1 negative control is worth its cost. The lane ran T1
too, and the corrected 13/13 matrix is only trustworthy because it does.

```
RESULT: APPROVE_CORRECTIONS

REVIEWED_HEAD: 4f96c78c9ffd65a9d1bafcdb65c4d12128a0ec3e

FINDINGS_REVIEWED:
  BLOCKER-1 (guard fails open on `static`; doc states a false predicate): CLOSED — VERIFIED.
    - `static` skip deleted; `static SecretProvider f(Session)` -> guard exit 1 AND generate exit 1
      ("Return type must be a Future or a Stream."). Was a false negative at effc537.
    - Doc now quotes 3.4.13 isEndpointMethod verbatim; I compared it token-by-token against
      serverpod_cli-3.4.13 .../endpoint_method_analyzer.dart:79-86 — no isStatic check, as claimed.
      Only delta is an added inline `// @doNotGenerate` comment and dropped blank lines.
    - No over-correction: `static Future<Map<String, dynamic>> f(Session)` -> guard PASS, generate exit 0.
    - Test doc and credential_endpoints.dart:128-132 now make the same claim from the same source.
  BLOCKER-2 (_isFutureOrStream narrower than _validateReturnType): CLOSED — VERIFIED.
    - `Future<dynamic> f(Session)` -> guard exit 1 AND generate exit 1 ("Return generic must have a type
      defined."). Was a false negative at effc537.
    - Message is now TRUE (names the dynamic-on-Future rule) instead of asserting "not Future or Stream"
      about a Future — the right call, since the old wording would reintroduce the defect class.
    - _returnTypeRejection is a faithful reproduction of _validateReturnType (:106-165), not an
      approximation, and returns the reason.
  THE LANE'S DEPARTURE FROM MY INSTRUCTION ("require a non-dynamic type argument"): CORRECT, and
    necessary. A literal reading also rejects `Stream<dynamic>`, which I measured as generate exit 0 with
    a real client streaming method — a false alarm on legal code. The implemented rule ("non-dynamic ON
    A Future") is exactly the generator's `innerType is DynamicType && !dartType.isDartAsyncStream`.
    Mechanism confirmed at source: analyzer-10.2.0 DynamicTypeImpl.element => DynamicElementImpl.instance,
    name => 'dynamic', so displayName is non-null and fromDartType does not throw.
  MATRIX: 13/13 guard/generator agreement, independently reproduced, incl. 5 cases beyond the report's
    (bare Future -> both reject; FutureOr -> both reject; nested generic -> both accept; nullable outer
    Stream -> both accept). Generalises; not overfitted.
  GATES: format exit 0 (656 files, 0 changed); analyze exit 0; guard test exit 0 (+13); serverpod
    generate exit 0; generated tree byte-identical (17d8989a673e… before/after, git diff empty, 0
    untracked); T1 negative control guard exit 1 + generate exit 1 on the same declaration.

REGRESSIONS:
  NONE. The diff is one test file (+136 -20); no production, generated, packages/**, .github/** or
  docker/** path touched. Nothing weakened: no expect() removed, no @Ignore/@Tags/skip/@Skip introduced,
  and the single behavioural deletion (the `static` skip) strengthens the guard. Non-blocking record
  inaccuracy (below) found in the correction report; it does not affect any gate or verdict.

BLOCKERS:
  NONE OPEN.
  Non-blocking, actionable (record only, no code change): the correction report's "assertion count went
  up (12 -> 13)" is factually wrong — effc537 also runs 13 tests. Replace with the true statement: test
  count unchanged at 13 while the catchable-offender set grows from {non-Future/Stream} to also include
  {Future<dynamic>, bare Future, Stream<void>, and all static declarations}.
  Carried-forward open items, each judged non-blocking and none introduced by this correction:
    M-4 (lazy custody record) — prior ACCEPT is correct; ADR 0018 says "not a silent default", and
      secret_provider_resolver.dart's `default:` arm THROWS (no silent-default branch), so the clause is
      met on its terms; only startup observability remains.
    N-1 (dogfood) — the correction record is ACCURATE and correctly refuses to persist "+191 -1" /
      43 098 ms. Mechanism verified: dogfood_shipit_postgres_test.dart:87-91 Directory.existsSync() on a
      75-byte .git FILE throws BEFORE the :107 archive. Correct baseline is +192 in a full checkout.
    F-A / F-B (no CI runs the guard; no CI runs generate) — confirmed at ci.yaml:60-61 and
      integration.yaml:139; lane correctly made no .github/** edit (PROHIBITED) and routed both. Its
      judgement that option (a) is right and (b) contradicts ci.yaml's stated reason is correct.
    G-7 (referenceName in client; mint returns a reference) — confirmed still open; product decision,
      out of scope, untouched by this correction.
    F-C (guard narrower than the full generator rule) — honestly disclosed, unchanged, non-blocking.

READY_FOR_MERGE: YES
```
