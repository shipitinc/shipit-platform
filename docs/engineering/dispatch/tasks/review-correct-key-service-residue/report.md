# Focused Re-Review — correct-key-service-residue

```
RESULT: APPROVE_CORRECTIONS

REVIEWED_HEAD: 7d1b1b8abdf5cbfbb7b48dc9682baf3bfb99090c

FINDINGS_REVIEWED:
  F-1  RESOLVED, and the scope is right. I reproduced the prior reviewer's
       `HostKeyNotPresentedException` demonstration from inside the test runner
       at the mutated HEAD. Both the bounding-before-`confirmHostKey` reasoning
       and the two-distinct-character-classes catch are verified empirically.
  F-2  RESOLVED. Both halves done; both demonstrated bypasses reproduced and
       both now fail. The string-literal false positive is real, is precisely
       characterised by the lane, and I sharpen it (N-3, N-4).
  F-3  RESOLVED. Doc now matches the code; quoted verbatim in §4.
  F-4  RESOLVED. Doc no longer denies `privateSeed.bytes`; quoted verbatim in §4.
       Residual in the same sentence pair recorded as N-5.
  F-5  RESOLVED. Claim confirmed false; withdrawal accurate.
  F-6  RESOLVED. Claim confirmed false; withdrawal accurate.
  NOT-EDITING-THE-CLOSED-REPORT  CORRECT DECISION, wrong lead reason (N-1 note).
  NEW-FINDING (`secretless_error.dart`)  VERIFIED FIXED. And YES, other
       instances exist: one, in `secret_material.dart` (N-2).
  MUTATIONS  REPRODUCED INDEPENDENTLY — four, all load-bearing.
  NO WEAKENED TESTS  VERIFIED.
  PROHIBITED PATHS  VERIFIED.

REGRESSIONS: none. Three of the four touched source files are doc-only; the
       fourth adds a bound at the single entry point and feeds the SAME validated
       value to both the column and the transport, so stored and verified cannot
       diverge.

BLOCKERS: none.

OPEN FOLLOW-UPS (none blocking): N-1 HIGH (a false PROJECT_FACT that must be
       corrected in the record BEFORE it is persisted — dogfood is NOT a
       worktree artifact and I disproved it), N-2 LOW, N-3 LOW, N-4 LOW, N-5 LOW.

READY_FOR_MERGE: YES
```

---

## 1. Provenance — VERIFIED

| Check | Expected | Observed |
|---|---|---|
| Worktree | `/private/tmp/shipit-impl-keys` | same |
| Branch | `impl/credential-key-service` | same |
| `git rev-parse HEAD` | `7d1b1b8abdf…` | `7d1b1b8abdf5cbfbb7b48dc9682baf3bfb99090c` |
| `CORRECTED_FROM_HEAD` | `da68b5f67d37…` | `da68b5f67d3766776b35d57d16956dd4b993ae7e` = `HEAD~1` |
| Commits in the correction | 1, no rewrite | 1 — `7d1b1b8` only |
| Working tree | clean | clean, before and after my review |
| `main` | `8725b65`, untouched | `8725b65deaab565f7c3b93d644e73f1ec07a6f39`; nothing pushed |
| `git diff --name-only 8725b65..7d1b1b8 -- docs/` | empty | **0 files** |

I mutated nothing in the reviewed worktree. Every mutation ran in a throwaway
primary clone outside the workspace, now deleted; the worktree's `git status` is
empty before and after.

**Prohibited paths — diffed explicitly for THIS commit.** `git diff --name-only
da68b5f..7d1b1b8 | rg 'migrations/|^tool/|src/generated/|docker/|packages/|pubspec'`
→ **nothing**. `migrations/**`, `tool/**` and `lib/src/generated/**` are untouched
by the correction, as claimed. (For the record and not a finding: the whole branch
does touch `lib/src/generated/endpoints.dart`, `lib/src/generated/protocol.yaml`,
`apps/server/pubspec.yaml` and root `pubspec.lock`, but in **earlier** commits that
the prior review already covered.)

---

## 2. The three judgement calls the dispatch asked for

### 2.1 F-1 SCOPE — over-built, or the right size? Where is the line, and is this it?

**Judgement: the size is justified and the charset bound is exactly right. Approve
as-is.** Duplication exists in the prose, not in the control.

**Where the right line actually is.** The sink is a Postgres `text` column plus a
Serverpod structured logger. The only characters that can forge a *line* in that
sink are the C0 controls and DEL, plus the space because this particular field is a
token and a space inside a token means the value is not what it claims to be.
`[\x00-\x20\x7f]` is that complete set, and nothing beyond it buys anything:

- **Unicode line/paragraph separators (U+2028, U+2029, U+0085) — correctly NOT
  rejected.** Neither Postgres text nor the structured logger treats them as line
  boundaries, so they are not a forge primitive here. Adding them would be
  over-bounding dressed up as thoroughness.
- **A stricter shape whitelist (`^[A-Za-z0-9+/=:-]+$`) — correctly NOT applied.**
  It would reject nothing legitimate either, but it would introduce a *second*
  notion of "what a fingerprint looks like" in a layer whose job is to refuse the
  characters that can act in the sink. Deciding shape is the verifier's job: it
  compares byte-for-byte against a value the transport computed, and a wrong shape
  fails closed there for free. Duplicating the shape rule here would create a second
  place to update when OpenSSH ever changes its fingerprint format.

So the answer to "should it reject more of the charset than whitespace + control
characters?" is **no** — and note it already rejects exactly one character more than
that phrase implies: the space, which is the deliberate difference from the sibling
validator.

**Is 128 the right length?** Real shapes are 50 (`SHA256:` + 43) and 51
(`MD5:` + 47 hex pairs). 128 is ~2.5× the longest — generous in the direction that
matters, because under-bounding is the risk the prior finding demonstrated and
over-bounding would only ever reject a paste of something else.

**On the size.** `credential_key_service.dart` is +119/-2, but the *control* is 4
lines of call plus a ~25-line validator; the rest is three documented constants
(`_kControlCharacter`, `_kNonTokenCharacter`, `_kMaxCallerTextLength`) and their
reasoning. I agree with the lane's own accounting rather than the dispatch's "3
lines", because I checked that a one-line `contains('\n')` guard would leave `\r`,
`\t`, the other C0 controls and the length unbounded — and the asymmetry the prior
review named was precisely that the *sibling* field was bounded and this one was
not. A shared validator would have been the wrong call for a second reason the lane
anticipated: the refusal messages are about different things (an audit field vs a
value compared against a computed fingerprint), and a shared message would
misdescribe one of them.

The duplication I do flag is prose-only: the `WHY IT NEEDED ITS OWN CALL` block
re-argues the F-1 rationale that the report and the `verifyAccess` comment already
carry. That is the cost of a security file that has to be readable without its
history — I would not block on it, and I would not want it thinner.

**Bounding before `confirmHostKey` — VERIFIED CORRECT, and it matters more than the
report claims.** `packages/product_registry/lib/src/engine/product_registry_engine.dart`:

- `:1014-1027` — the **changed-key** path: on a mismatch it does
  `c.copyWith(hostKeyStatus: HostKeyStatus.changed, hostKeyFingerprint: hostKeyFingerprint, …)`
  and `await _store.saveProductCredential(changed, …)` **and only then** throws
  `HostKeyNotConfirmedException`. The caller's string is persisted **before** any
  refusal.
- `:1029-1034` — the **first-confirm** path: `hostKeyFingerprint: hostKeyFingerprint`
  into the `confirmed` `copyWith`, saved.

Both write the caller's string verbatim, and there is no validation on either path
in the domain layer. So the column leg was genuinely reachable, and bounding only
the verifier call would have left a persisted unbounded value behind — including on
the changed-key path, where the value lands in the database *before* the exception.
The lane's reasoning is correct as stated.

One thing the report does not call out and should have: the lane routes **one**
validated local into **both** legs —

```dart
final fingerprint = _validatedFingerprint(hostKeyFingerprint, 'hostKeyFingerprint');
await engine.confirmHostKey(…, hostKeyFingerprint: fingerprint, …);
…
final outcome = await verifier.verify(…, confirmedHostKeyFingerprint: fingerprint);
```

— which is the right shape. Validating into one variable and forwarding the raw
string to the second consumer would let the stored value and the verified value
diverge by leading/trailing whitespace, and then a later verification would compare
against a column it did not write. This is a small thing done correctly.

**The two validators are genuinely distinct — VERIFIED EMPIRICALLY**, not by reading.
I ran both compiled regexes over twelve inputs:

| value | `_kControlCharacter` `[\x00-\x1f\x7f]` | `_kNonTokenCharacter` `[\x00-\x20\x7f]` |
|---|---|---|
| `Dana Okafor` | **accept** | **REJECT** |
| `SHA256:AAAA…AAA` (43 chars) | accept | **accept** |
| `MD5:aa:bb:…:99` (real MD5 form) | accept | **accept** |
| `plain` | accept | accept |
| `a<TAB>b` | REJECT | REJECT |
| `a<LF>b` | REJECT | REJECT |
| `a<CR>b` | REJECT | REJECT |
| `a<NUL>b` | REJECT | REJECT |
| `a<ESC>b` | REJECT | REJECT |
| `a<DEL>b` | REJECT | REJECT |
| `a b` (internal space) | **accept** | **REJECT** |

So the lane's own catch was real and the split is real: `confirmedBy` still accepts
an operator's name, both real fingerprint forms still pass, and every C0 control,
DEL, tab, CR, LF, NUL and ESC is refused by both. The bound is a bound, not a ban,
which is what makes the accompanying Proof 4 (the legitimate `_wrongFingerprint`
still reaches the verifier and is refused on its merits by
`HostKeyNotPresentedException`) a meaningful assertion rather than a tautology.

**Regression check on the newly bounded field.** `AccessVerification.toJson()`
does **not** carry `hostKeyFingerprint` — only `observedHostKeyFingerprint`, which
is transport-computed by `ssh-keygen -l`, not caller text. `confirmHostKey` has
exactly one caller in `apps/server/lib` and it is the bounded one. The endpoint
(`credential_endpoints.dart:198`) hands the wire value straight to `verifyAccess`,
so the bound sits on the untrusted boundary and covers every caller. The only
behavioural change beyond the bound is that an **empty** fingerprint is now refused
up front with `CredentialScopeException` rather than being persisted as `''` and
later refused by the verifier — the same treatment `_validatedConfirmer` already
gave `confirmedBy`, and `CredentialScopeException` is an `AuditedFailure`, so the
endpoint's `redactUnauditedFailure` path handles it identically to
`HostKeyNotPresentedException`. No client-visible inconsistency introduced.

---

### 2.2 F-2 — the guard now reads inside string literals

**Judgement: acceptable as written; do not block. Narrowing it would cost more than
the latent false positive is worth, but two sharpenings belong in the record (N-3,
N-4).**

I confirmed the widening is real and does match inside string literals, and I found
the live instance the lane describes: `secret_provider.dart:93` —

```dart
  @override
  String get secretlessDescription =>
      'SecretStoreException(provider: $providerId, operation: $operation, '
      'reference: $referenceName, reason: $reason)';
```

— contains `SecretStoreException(` **inside a string literal**. It is inert today
only because of an ordering accident, exactly as the lane reports: after
`_withoutComments` strips `///` lines, `secret_provider.dart`'s `caught` set is empty
(its only `catch (e)` is at line 47, inside a doc comment), so `if (caught.isEmpty)
continue;` skips the file before the call-site loop runs. I checked every audited
file: `catch (name)` bindings exist **only** in `local_file_secret_provider.dart`
(×3) and `repository_access_verifier.dart` (×1), and `credential_endpoints.dart` has
**none** — so adding it to the audited set introduces no finding, which is what the
lane claims.

**Why I still would not narrow it.** The user's worry — a guard that fires on
innocuous content trains people to add an `ignore` — is right in general, and it is
*not* the right worry here, for three reasons:

1. **The failure mode is legible, not silent.** The offender message names the file
   and the binding (`local_file_secret_provider.dart: reason hands the caught
   \`error\` to something other than secretlessText(...)`). A maintainer meets a
   sentence that says what to look at, not an opaque red. Legible failures are what
   buy patience; silent ones buy overrides.
2. **The false-positive surface is genuinely narrow, and I measured it rather than
   assuming it.** Tracing `_balancedCall` + `_argumentOf` against `secret_provider.dart:93`:
   `_balancedCall` returns `SecretStoreException(provider: $providerId, operation: $operation, reference: $referenceName, reason: $reason)`,
   `_argumentOf(block, 'reason')` returns `" $reason"`, and the offender test
   `\b$name\b` only fires for a catch binding literally named `reason`. So a
   false positive needs a file that binds a catch clause *and* carries a
   `SecretStoreException(` string literal with a `reason:`-shaped argument.
3. **Narrowing means either a hand-rolled tokenizer or a heuristic**, both of which
   are new maintenance surface inside a security file — and the heuristic versions
   reopen exactly the class F-2 was raised about. That is a worse trade than a
   documented latent false positive.

The lane also did the thing that actually de-risks it: it **named** the residual in
the code (`WHAT THAT GUARD ACTUALLY COVERS`) instead of leaving the next reader to
discover it. That is the difference between a latent defect and a documented
boundary.

**My two sharpenings** — both LOW, neither blocking:

- **N-3.** The sanctioned-shape strip is `RegExp('secretlessText\\(\\s*$name\\s*\\)')`
  — exactly **one** argument. Today `secretlessText(Object error)` takes exactly
  one parameter, so it cannot false-positive. The moment anyone adds an optional
  parameter, every sanctioned call site becomes an offender and the natural fix a
  maintainer reaches for is an `ignore`. This is the real "how guards die" path and
  it is a one-line fix now:
  `RegExp('secretlessText\\(\\s*$name\\s*(,[^)]*)?\\)')`.
- **N-4.** `_auditedSources()` reads `lib/src/credentials` with a non-recursive
  `listSync()`. There are no subdirectories today (verified: `find … -type d` returns
  the directory itself), but the doc claims "every [SecretProvider] implementation
  in this directory", and a future adapter in `lib/src/credentials/<vendor>/` would be
  silently unaudited — and the `sources.length > 10` sanity floor (actual: 12) would
  not notice, because a new subdirectory does not change the count.

**Both halves done — VERIFIED.** The guard widened (`SecretStoreException\(\s*`, and
`\b$name\b` on the reason with `secretlessText(name)` removed first) *and* both docs
corrected: `secret_provider.dart:52-70` and `secretless_error.dart:30-40`. Neither
doc now claims the old, false coverage.

---

### 2.3 Not editing the closed b1b2 report

**Judgement: the decision is right. The lead reason is the weaker of the two the
lane gives, and should not be the one recorded.**

Verified first, because the argument depends on what the file is:

- `docs/engineering/dispatch/tasks/correct-credential-key-service-b1b2/report.md` is
  **untracked** in the main workspace (`git status --porcelain` → `??`), mtime
  18:01 — before the residue correction began (its own report: 20:00). Unmodified.
- `git diff --name-only 8725b65..7d1b1b8 -- docs/` → **0 files**. The branch writes
  no docs at all.
- `docs/engineering/**` is outside this dispatch's `OWNED_PATHS`.

**The decision is right** — and my view, since the dispatch asked for mine:

1. **Ownership is the decisive reason, not provenance.** Amending
   `docs/engineering/**` would have been an ownership violation *whatever* the
   provenance argument said. `docs/**` is not this lane's to write (the lane itself
   records this as M-7, the Manager's step).
2. **The prior reviewer cited that file by line number.** `551`, `779` and `113` are
   quoted in `review-correct-credential-key-service/report.md`. Moving the text
   would silently invalidate three citations in a report that is itself the record
   of what was verified. That is a real documentary-provenance hazard, and it does
   not depend on the file being committed.
3. **Recording the correction beside the claim, with the original quoted verbatim,
   is the right pattern.** I checked all three quotes against the file and they are
   verbatim: line 551 `…the single \`ignore\` comment in the diff is
   \`prefer_initializing_formals\` on the \`SshKeyPair\``, line 779 `Nothing suppressed,
   ignored or @Skipped; the one lint ignore in`, line 113 `The dispatch asked for the
   **class**. It is closed at three independent levels, because no single one`.

**Where the lead reason is wrong.** §6 argues that amending the closed report "is a
provenance record after the fact, which is the same thing `aef-correction-loop`
forbids me to do to commits." That argument is **weaker than it sounds here, precisely
because the file is untracked**: it is not a git object, so no hash changes and no
history is rewritten. The commit-rewrite rule does not transfer to an uncommitted
working-copy file. The lane reaches the correct outcome and does mention ownership
first in the same paragraph, but it presents provenance as the primary justification
and it does not carry its weight.

**Recommendation to the Manager:** record the reason as **ownership + line-number
citation by the prior reviewer**, not as commit-provenance. The outcome is unchanged;
the reason is the part a future lane would otherwise rely on.

I also confirmed F-5's substance while I was there. The b1b2 report claims an
`ignore` on the `SshKeyPair` constructor. `git grep -n 'ignore:' 7d1b1b8 -- apps/server/lib
apps/server/test apps/server/pubspec.yaml` returns exactly **one** hit:
`apps/server/lib/src/endpoints/home_endpoints.dart:72 // ignore: deprecated_member_use`
— a pre-existing file outside this branch's diff. And `ssh_keypair.dart:99-105`
confirms the concern was solved properly, as the lane describes:

```dart
  // Split into a factory plus a generative constructor so the seed can be a
  // *private* initializing formal (`this._privateSeed`) while the call sites read
  // `privateSeed:`. Writing `required this.privateSeed` instead would publish the
  // seed as public API, which is the B-2 defect, and `prefer_initializing_formals`
  // is right to complain — hence the two-step rather than an ignore.
```

F-5's withdrawal is accurate, and its note that the original error was "in the
conservative direction" is correct: the code is cleaner than the report described.

---

## 3. F-1 and F-2 mutations — reproduced independently

Throwaway primary clone at exactly `7d1b1b8`, outside the workspace, deleted
afterwards. The reviewed worktree was never mutated.

**F-1 — removing the bound** (`final fingerprint = hostKeyFingerprint;`, restoring
`da68b5f` behaviour), full `make test-integration`:

```
01:04 +70 -1: credential_key_service_postgres_test.dart: … the host-key confirmation
is labelled as operator-asserted (M-5) a fingerprint carrying a forged log boundary
never reaches the exception (F-1) [E]
  Expected: <Instance of 'CredentialScopeException'> with `toString`:
  (contains 'hostKeyFingerprint' and not contains '\n'
              '' and not contains 'credential.verify_access.completed')
    Actual: HostKeyNotPresentedException:<HostKeyNotPresentedException(github.com:22 —
            confirmed SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    [credentials] credential.verify_access.completed ok, presented SHA256:uNiVztks
    CsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s, …)>
     Which: is not an instance of 'CredentialScopeException'
```

That is the prior reviewer's `DESCRIPTION_CONTAINS_NEWLINE=true` and
`DESCRIPTION_CONTAINS_FORGED_MARKER=true`, produced again from inside the test
runner, in an audited exception description destined for Postgres. **Exactly two
failures in the whole run** (F-1 + dogfood) — no cascade, so this is a specific
assertion failure and not a load artifact. **Load-bearing.**

**F-2, bypass 1 — `reason: _leak(error)` with a top-level helper**, at `7d1b1b8`:

```
  a SecretStoreException reason must be a literal, a package constant, or secretlessText(...):
  [local_file_secret_provider.dart: reason hands the caught `error` to something other
   than secretlessText(...), … ×3]
00:02 +9 -1: Some tests failed.
```

**The new positive test still passed** — which is the point: the leaked
`FileSystemException.toString()` contains no key material, so only the *source* guard
catches this shape. That is direct evidence the two halves are complementary rather
than redundant, and it is the reviewer's alternative option working as intended.

**F-2, bypass 2 — single-line call site** `throw SecretStoreException(referenceName: …, reason: '$error');`
at `7d1b1b8`: guard test fails, `+9 -1`.

**The "before" figure, independently.** Checking out the `da68b5f` versions of both
files and re-applying bypass 1: **`+9: All tests passed!`** — the prior reviewer's
exact reported number, reproduced. Unmutated `7d1b1b8`: **`+10: All tests passed!`**
(`+9` guard + 1 new positive test).

All four checks reproduce. Nothing was left behind in the clone.

---

## 4. F-3 and F-4 — docs now match the code

Both are **doc-only** changes; I diffed the code and there is none.

**F-3**, `credential_key_service.dart:432-436`, replacing "The value itself is
reported back in the refusal, since it is the operator's own text and they need to
see what was rejected." The code reports `${trimmed.length} characters` and nothing
else:

```dart
  /// NO REFUSAL QUOTES THE VALUE. The refusals name the field and, for the
  /// length refusal, report the length; they do not report the text back. The
  /// value is caller-supplied and these messages reach a durable record, so
  /// echoing it would make the refusal the forgeable surface instead of the
  /// field it is bounding.
```

The lane is right not to have merely swapped "the value" for "the length": the
original sentence's *reasoning* was the wrong part. Corrected.

**F-4**, `ssh_keypair.dart:75-82`. The claim that "there is **no** public accessor
that returns the seed as a `Uint8List` or a `String`" is gone; the doc now states
the guarantee that actually holds and names the hole:

```dart
///     buffer had been wrapped at construction. Reaching the raw seed at all is
///     an **explicit** act: [SecretBytes.bytes]. There is no implicit projection
///     — no `toString`, no `toJson`, no operator — so nothing reaches a log line
///     or a durable column by accident, which is the guarantee that actually
///     matters here. (An earlier version of this sentence claimed there was "no
///     public accessor that returns the seed as a `Uint8List` or a `String`".
///     That was false — `privateSeed.bytes` is exactly that — in the same way
///     the previous `String get privateKeyPem` contradicted the line above it,
///     and it is corrected here rather than papered over.)
```

`privateSeed.bytes` exists and is a public `Uint8List`; the doc now says so. The
"three sites" → six correction is also verified: `rg '\b(seed|secret|privateKeyPem|_privateSeed)\.bytes\b'`
returns exactly six code sites — `ssh_keypair.dart:152/156/240` (the codec) and
`local_file_secret_provider.dart:73`, `gcp_secret_manager_secret_provider.dart:143`,
`repository_access_verifier.dart:364` (the material producers). The names match
one-for-one. **N-5** records one imprecision in the same edit.

---

## 5. The NEW FINDING — the same defect in `secretless_error.dart`, and other instances

**`secretless_error.dart` — VERIFIED FIXED, and it was a real second instance.**
Old: *"bytes. \`audit/secretless_error_test.dart\` holds a guard test that fails if a
\`SecretStoreException\` argument block grows a string interpolation…"* New:

```dart
///   bytes. `test/secretless_error_test.dart` holds a guard test that reads the
///   adapter sources and fails if a `SecretStoreException` `reason:` argument
///   names a caught binding other than inside `secretlessText(...)`, and a
///   second that drives the real local adapter and feeds real material-bearing
///   failures through this function.
```

Both halves were wrong — the **path** (`audit/…` when the file is `test/…`) and the
**overstated scope** (the same claim F-2 was raised for) — and both are fixed.
`rg 'audit/'` over the repository now returns **zero hits**, and the only two
surviving references to the guard test in the package both say
`test/secretless_error_test.dart`.

**Other instances in the package: YES — one, and it is the same class.**
**N-2 (LOW), `secret_material.dart:30-33`** — the file that *roots* the B-2
guarantee:

```dart
/// Wrapping the bytes makes leakage a compile-time impossibility instead of a
/// review-time catch: [toString] is the only textual projection and it emits a
/// length, never a byte. There is deliberately no `operator +`, no `toJson`, no
/// `List<int>` accessor — reaching the bytes requires an explicit, greppable
/// [bytes] call at the exact sites that genuinely need them (the cipher codec,
/// the identity-file writer, the secret-manager request body).
```

Two defects, both inherited verbatim from the sentences F-4 flagged in
`ssh_keypair.dart`, which this correction fixed in *that* file and left here:

1. **"no `List<int>` accessor" is false.** `Uint8List get bytes` on line 51 *is* a
   `List<int>` accessor (`Uint8List implements List<int>`). This is character-for-
   character the F-4 defect: a doc in the custody file denying an accessor that
   exists. And the two files now **disagree with each other** — `ssh_keypair.dart:75`
   was corrected to "There is no implicit projection — no `toString`, no `toJson`,
   no operator", while `secret_material.dart` still claims no accessor at all.
2. **The site list is wrong and incomplete.** It names three ("the cipher codec, the
   identity-file writer, the secret-manager request body"). There are six
   `SecretBytes.bytes` sites, and **the local store write
   (`local_file_secret_provider.dart:73`) is not among the three named** — the very
   sentence the prior reviewer flagged in `ssh_keypair.dart` and the lane corrected
   there.

The operative guarantee survives both defects ("reaching the bytes requires an
explicit, greppable `bytes` call" is true, and `.bytes` is greppable), so this is
documentation only and holds no gate. It is one line in an owned path and it is the
direct answer to the dispatch's "check whether other instances exist" — **they do.**
The lane's `CONTRADICTION` note even predicts the possibility ("there may be more
instances elsewhere in the repo that no lane has audited yet"); here is one, in the
package it audited.

**Full sweep for the rest of the class:** I read every absolute/negative doc claim
across `apps/server/lib/src/credentials/*.dart` and found no other instance. Nothing
else in the package points at a path that does not exist.

---

## 6. Gates — re-run by me

| Gate | Command | Result | Report claim | Verdict |
|---|---|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | `Formatted 655 files (0 changed)`, exit 0 | same | MATCHES |
| analyze | `dart analyze apps/server` | `No issues found!`, exit 0 | same | MATCHES |
| tests (non-DB) | `dart test` × 4 files, at `7d1b1b8` in the worktree | **`+57: All tests passed!`** | `+57` | MATCHES |
| guard only, in the clone | `dart test test/secretless_error_test.dart` | `+10` unmutated; `+9` at `da68b5f` with bypass 1 | `+9 → +10` | MATCHES |
| tests (DB) | `make test-integration` in a primary clone at `7d1b1b8` | **`+191 -1`, sole failure dogfood** | `+191 -1` (worktree), `+192` (clone) | figures match for the worktree; **`+192` NOT reproducible — see N-1** |
| tests (DB), mutated | same, F-1 mutation applied | F-1 test fails; exactly 2 failures total | F-1 fails | MATCHES |
| build | — | not in this dispatch's `VALIDATION_COMMANDS` | n/a | agreed |

### N-1 (HIGH follow-up, non-blocking) — the dogfood `PROJECT_FACT` is FALSE as stated

The dispatch flagged this as a new and important claim. I verified it, and **the
mechanism is right but the conclusion is wrong.**

**What is right.** The observation is correct and I confirmed it from the filesystem:
`/private/tmp/shipit-impl-keys/.git` is a **75-byte ASCII file** (`gitdir:
/Users/…/.git/worktrees/shipit-impl-keys`), and `git rev-parse --git-dir` returns the
main repo's `worktrees/` directory. So `Directory('${repoRoot.path}/.git').existsSync()`
at `dogfood_shipit_postgres_test.dart:88` is **false** in this linked worktree and
**true** in a primary clone (`.git` is a directory — verified in the throwaway clone).
The assertion really is on the working tree, not on the branch.

**What is wrong.** *"in a primary clone the assertion is satisfied and the test
passes"* — it does not pass. In a clean primary clone at exactly `7d1b1b8`,
`make test-integration` gives **`+191 -1`, sole failure dogfood** — the identical
figure the lane reported for the worktree. And the failure is **not** the `.git`
assertion: the test gets past line 88 and dies 57 lines later.

```
03:56 +182 -1: dogfood_shipit_postgres_test.dart: … [E]
  TimeoutException after 0:00:30.000000: Test timed out after 30 seconds.
03:57 +183 -1: dogfood_shipit_postgres_test.dart: … [E]
  PathNotFoundException: Directory listing failed, path = '…/shipit-head-XXXX/
  docs/engineering/dispatch/tasks/integrate-baseline-product/' (OS Error: 2)
  package:product_registry/src/discovery/read_only_repository_reader.dart 90:25
```

**The cause, measured directly.** I extracted a snapshot exactly as the test does
(`git archive HEAD | tar -x`, 1537 files / 359 dirs) and ran
`ReadOnlyRepositoryReader(snapshotRoot: …).inspect()` against it:

```
observations=49 elapsed=43098ms
```

**43 seconds against `dart test`'s 30-second default.** Dogfood is red here because
the repository-wide discovery walk exceeds the per-test timeout — which is exactly
what has been happening as `docs/engineering/dispatch/tasks/` accumulated thirty-odd
task directories. The `PathNotFoundException` is a *consequence*: the
`addTearDown` that deletes the snapshot runs while `_walk` is still walking it. It is
load-sensitive, not worktree-sensitive.

**Cross-check, and it sides with the prior reviewer.** `review-correct-credential-key-service/report.md:279`
records base `8725b65` **in a primary clone** as `+170 -2` with failures
"dogfood + **D-4**". The lane's `PROJECT_FACT` asserts the opposite for the same tree
shape and never reconciled the conflict with the report immediately above it in its
own dispatch chain.

**Why this must be corrected before persistence.** If the Manager records PROJECT_FACT
#2 as written, the next lane will conclude dogfood is noise in any worktree and never
look at it — when in fact it is a real, branch-independent failure of a 30-second
timeout against an unbounded repository walk, present in *both* tree shapes and in the
already-accepted prior measurement. The correct fact is the opposite of the useful one:
**`+191 -1` with dogfood as the sole failure is the expected figure on this machine,
in either tree shape, and dogfood is a real signal that wants a timeout bump or a
bounded walk.**

The lane's *observation* deserves to be recorded too — it is a genuine property of the
test — but as a note ("this test asserts `.git` is a **directory**, so it cannot pass
in a linked worktree"), not as an explanation of the failure. Two facts, one true and
one false, were merged into one causal claim.

I did **not** fix dogfood: `apps/server/test/integration/**` is in the lane's owned
paths, but it is outside this dispatch's findings, and a timeout change is a test-behaviour
change that deserves its own review.

---

## 7. Nothing weakened, skipped, filtered or deleted — VERIFIED

| Check | Result |
|---|---|
| `@Ignore` / `@Skip` / `only:` / `tags:` / `excludeTags` / `@TestOn` / `@OnPlatform` / `skip:` added by this commit | **none** (`git diff da68b5f..7d1b1b8 -- apps/server/test \| rg '^\+' \| rg …` → empty) |
| Test files added or deleted by this commit | **none** — two existing files modified |
| Deleted test lines | exclusively the replaced old guard body and its doc header (the `SecretStoreException\(\n` regex, the `\$\{?name\b` check, the old test name, the old group name). **No assertion deleted or loosened.** |
| The single pre-existing `skip:` in `apps/server/test/**` | `credential_keypair_test.dart`, the `ssh-keygen` guard. **Inactive**: `ssh-keygen -l -f /dev/null` exits **255**, not 127, so the OpenSSH proofs execute. |
| Net test growth | +1 non-DB (`secretless_error_test.dart`), +1 integration. Matches the report. |
| Both new tests fail when the fix is reverted | **verified independently** — §3 |

---

## 8. Open follow-ups

None of these hold the merge. N-1 is the one that matters, because it is a false
statement about a gate that has been offered for persistence.

**N-1 (HIGH, record correction — Manager step).** The dogfood `PROJECT_FACT` is false
as stated (§6). Do not persist it as "dogfood passes in a primary clone". Persist
instead: *"the test asserts `Directory(<root>/.git).existsSync()`, which is a
**directory** in a primary clone and a **file** in a linked worktree such as
`/private/tmp/shipit-impl-keys`, so it cannot pass in a worktree; however dogfood is
also red in a primary clone because `ReadOnlyRepositoryReader.inspect()` over a
`git archive` snapshot of this repository measures ~43 s against the 30 s `dart test`
default, and the teardown then races the still-running walk. `+191 -1` with dogfood as
the sole failure is the expected figure in either tree shape."* Fixing that timeout is
real work, not a worktree artifact.

**N-2 (LOW, `secret_material.dart:30-33`, owned path, ~2 lines).** Remove "no
`List<int>` accessor" (false — `Uint8List get bytes` is one) and complete the site list
to six with each named, as `ssh_keypair.dart:166-175` already does. Leaving it makes
two files in the same package state contradictory guarantees about the same class.

**N-3 (LOW, `secretless_error_test.dart`, ~1 line).** Widen the sanctioned-shape strip
to `RegExp('secretlessText\\(\\s*$name\\s*(,[^)]*)?\\)')` so adding an optional
parameter to `secretlessText` does not turn every sanctioned call site into an
offender.

**N-4 (LOW, `secretless_error_test.dart`).** Make `_auditedSources()` recursive, or
state in its doc that it is not, and that an adapter in a subdirectory of
`lib/src/credentials/` would be unaudited.

**N-5 (LOW, `ssh_keypair.dart:174`).** The stated audit command
`rg '\.bytes' apps/server/lib/src/credentials` returns **18** hits, 12 of which are
`publicKey.bytes` / `privateKey.bytes` / `digest.bytes` — it does not produce the
stated six. The six sites and their names are correct; only the command is wrong.
Either narrow the command to `SecretBytes`-typed receivers
(`rg '\b(seed|secret|privateKeyPem|_privateSeed)\.bytes\b'`) or reword it as "search
for `.bytes` and justify each new one".

---

## 9. Verdict

**`APPROVE_CORRECTIONS`.**

**Every handed-in finding is genuinely resolved, and I proved it rather than reading
it.** F-1's bound is the right bound at the right place: `_validatedFingerprint` refuses
exactly the characters that can forge a line in the sink (C0 + DEL + the space, because
this field is a token), it is applied **before** `confirmHostKey` because
`product_registry_engine.dart:1019` and `:1031` both persist the caller's string
verbatim — and on the changed-key path *before* the refusal, so the column leg was
genuinely open — and the same validated value feeds both the column and the transport,
so they cannot diverge. Rejecting more of the charset would be over-bounding dressed as
thoroughness; the verifier's equality check is where shape belongs. The lane's own
caught error — one regex for both fields, which would have refused "Dana Okafor" — is
real, and I confirmed empirically that the two classes are now distinct and that both
real fingerprint forms still pass.

F-2's guard is genuinely widened and both docs genuinely corrected, and I reproduced
both of the prior review's bypasses failing at `7d1b1b8` and the `+9` pass at
`da68b5f`. The string-literal false positive is real, is precisely characterised by
the lane, and should **not** be narrowed before merge: the guard fails loudly and
names the file, the false-positive surface is narrow enough that I could enumerate it
down to a single historical candidate, and narrowing means either a hand-rolled
tokenizer in a security file or a heuristic that reopens the very class F-2 is about.
The lane reported the residual instead of papering over it, and added the positive
assertion that covers what the source audit structurally cannot — and my bypass-1
mutation proved the two halves are complementary, because the positive test *passed*
while the guard caught the leak.

**F-5 and F-6's handling is right, for a better reason than the one given.** The b1b2
report is untracked, so the commit-provenance argument does not transfer to it; the
decisive reasons are the `docs/**` ownership boundary and the prior reviewer's
line-number citations (551, 779, 113), which I confirmed are quoted verbatim. Both
claims are genuinely false — `git grep 'ignore:'` over the branch finds only a
pre-existing hit in an untouched file, and the constructor was split into a factory
over a positional generative constructor rather than suppressed. The lane's error was
in the conservative direction and it says so.

**The NEW FINDING is real and correctly fixed**, and the answer to "are there other
instances?" is **yes** — `secret_material.dart:30-33` still carries the F-4 defect
verbatim, including a site list that omits the local store write.

**The gates pass and nothing was weakened.** Format, analyze and the four non-DB files
re-run by me at `7d1b1b8`; `+57`. No `@Ignore`, no `skip`, no filter, no deleted
assertion, no test file added or removed. The one pre-existing `skip:` is inactive.
`migrations/**`, `tool/**` and `lib/src/generated/**` are untouched by the correction,
as are `docker/**`, `packages/**` and the pubspecs.

**One claim in the report is false and must not be persisted.** Dogfood is **not** a
linked-worktree artifact. The `.git`-is-a-file mechanism the lane found is real and
worth recording as a note about that test, but the causal claim fails on measurement:
in a clean primary clone at the same HEAD the suite is `+191 -1` with dogfood still the
sole failure, because `ReadOnlyRepositoryReader.inspect()` over a snapshot of this
repository measures **43 s against a 30 s `dart test` timeout** (with a
`PathNotFoundException` teardown race as its consequence). That also means the lane's
`+192: All tests passed!` is not reproducible, and that dogfood agrees with the prior
reviewer's primary-clone base measurement rather than contradicting it. It does not
hold the merge — the code at HEAD is unaffected and `+191 -1` is the expected figure
either way — but it is the one thing here that could cause future harm if recorded, so
N-1 must be corrected in the Manager's persistence step.

**Resource hygiene.** Zero mutating Docker or Compose commands were issued by me. Two
`make test-integration` runs, both under the target's own PID-scoped trap and a
`-p`-scoped project; both printed `removing shipit_integration_<pid> (container + data)`
followed by `Stopping/Stopped/Removing/Removed` for the container and `Removing/Removed`
for the network, and **no `CLEANUP FAILED`**. Projects `72178` and `76833`; nothing
survived. No `docker ps`/`logs`/`config`. No `make clean`, `make qa-down`,
`make test-env-down`, `make e2e-down`, or bare `down -v`. QA was up on its stopgap
run-mode override throughout and was not disturbed; `docker/**` was read as text only.
Load averaged 68–128 throughout, recorded beside every run above, and the F-1 mutation
run produced exactly two failures with no `setUpAll` cascade — so the cascade-pollution
caveat does not apply to any conclusion here.
