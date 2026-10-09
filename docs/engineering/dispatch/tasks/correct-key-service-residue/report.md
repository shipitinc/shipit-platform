# Correction — correct-key-service-residue

```
RESULT: CORRECTION_COMPLETE

CORRECTED_FROM_HEAD: da68b5f67d3766776b35d57d16956dd4b993ae7e
NEW_HEAD: 7d1b1b8abdf5cbfbb7b48dc9682baf3bfb99090c

FINDINGS_ADDRESSED:
  F-1  RESOLVED  hostKeyFingerprint bounded before every leg it takes (code)
  F-2  RESOLVED  guard widened to close both reproduced bypasses AND doc
                 corrected to state real scope; residual named (code + doc)
  F-3  RESOLVED  doc corrected to describe the length, not the value (doc only)
  F-4  RESOLVED  doc corrected; code untouched, as instructed (doc only)
  F-5  CORRECTED in the record — my report cited an `ignore` that does not exist
  F-6  CORRECTED in the record — my "no single level suffices" claim withdrawn

FILES_CHANGED:
  apps/server/lib/src/credentials/credential_key_service.dart    (+119/-2)
  apps/server/lib/src/credentials/secret_provider.dart           (+22/-3)
  apps/server/lib/src/credentials/secretless_error.dart          (+6/-2)
  apps/server/lib/src/credentials/ssh_keypair.dart               (+18/-4)
  apps/server/test/integration/credential_key_service_postgres_test.dart (+95/-0)
  apps/server/test/secretless_error_test.dart                     (+133/-42)

GATES:
  format=pass  dart format --output=none --set-exit-if-changed .
               -> "Formatted 655 files (0 changed)", exit 0
  analyze=pass dart analyze apps/server
               -> "No issues found!", exit 0
  tests=pass   non-DB: dart test test/credential_keypair_test.dart
               test/repository_access_verifier_test.dart
               test/secret_provider_test.dart test/secretless_error_test.dart
               -> +57: All tests passed!  (was +56; +1 is the new F-2 positive
                  assertion. F-1's test is in the integration file.)
  tests=pass   DB: make test-integration -> +191 -1, exit 1, sole failure the
               pre-existing dogfood test in packages/** (prohibited here).
               Base is +170 -2 per the reviewer's independent measurement.
  build=n/a    no build gate in this dispatch's VALIDATION_COMMANDS
  runtime=n/a  no deployment; see "Load and cascade" below for the two
               make test-integration runs on the mutation clone

NEW_DISCOVERIES:
  WORKFLOW_IMPROVEMENT  A `catch (…)` binding in a DIFFERENT file is invisible to
                        a same-file source audit; the audited surface must be
                        stated per file, and a positive assertion is the only
                        thing that covers a value aliased through a local.
  PROJECT_FACT          dogfood passes in a primary clone and fails in this
                        linked worktree — its assertion is on the working tree,
                        not on the branch.
  CONTRADICTION (minor) secretless_error.dart pointed its guard test at
                        `audit/secretless_error_test.dart`; the path is
                        `test/secretless_error_test.dart`.

READY_FOR_FOCUSED_REVIEW: YES
```

---

## 0. Provenance

| Check | Expected | Observed |
|---|---|---|
| Worktree | `/private/tmp/shipit-impl-keys` | same |
| Branch | `impl/credential-key-service` | same |
| Reviewed HEAD at start | `da68b5f67d3766776b35d57d16956dd4b993ae7e` | exact match |
| NEW_HEAD | one new commit on top | `7d1b1b8abdf5cbfbb7b48dc9682baf3bfb99090c` |
| Commits added | exactly 1, no rewrite | `git log --oneline da68b5f..HEAD` → `7d1b1b8` only |
| Working tree | clean | clean |
| `main` | `8725b65`, untouched | `8725b65deaab565f7c3b93d644e73f1ec07a6f39` |
| Pushed? | no | `origin/main` still `8725b65` |

All six changed files are inside this dispatch's `OWNED_PATHS`
(`apps/server/lib/src/credentials/**`, `apps/server/test/**`). Nothing in
`docker/**`, `packages/**`, `apps/control_plane/**`, `migrations/**`,
`tool/**`, `lib/src/generated/**` or `server.dart` was read-modified or
touched. `serverpod generate` was **not** run.

---

## 1. F-1 — `hostKeyFingerprint` is now bounded (code change)

**Root cause, and why the M-5 correction missed it.** M-5 bounded `confirmedBy`
and `checkedBy` for a stated reason — the code's own comment calls a control
character "a forge-the-previous-entry primitive" — and then passed
`hostKeyFingerprint` through unchanged. The reason it was easy to leave is that
it *reads* as a computed value (`SHA256:` + 43 base64 characters), and a
computed value looks safe to forward.

It does not stay in the column. The chain the review demonstrated is real and I
reproduced it here as a mutation (§4):

- `HostKeyNotPresentedException.secretlessDescription`
  (`repository_access_verifier.dart:176-180`) interpolates
  `confirmedFingerprint` verbatim;
- that type is an `AuditedFailure`, so `secretlessText` **forwards** it rather
  than suppressing it the way it suppresses an unvetted message;
- `credentialFailureLogFields` writes it to the Serverpod session log, which
  `config/test.yaml` persists to Postgres (`persistentEnabled: true`).

So the asymmetry the reviewer named is the whole finding: `confirmedBy` reaches
only a column; `hostKeyFingerprint` reached an exception description and
therefore a durable log row.

**The fix — `credential_key_service.dart`.** A sibling validator
`_validatedFingerprint`, called **before** `engine.confirmHostKey`, so every leg
is bounded rather than only the one that happened to be noticed. It is a
*sibling* and not a reuse of `_validatedConfirmer` because the refusal messages
are about a value compared against a computed fingerprint rather than about an
audit field, and a shared message would misdescribe one of them.

Three details I want on the record because they are judgement calls, not
mechanics:

1. **Bounding happens before `confirmHostKey`, not just before the verifier.**
   Reading the domain, `confirmHostKey` persists the caller's string verbatim on
   a first confirmation (`hostKeyFingerprint: hostKeyFingerprint` at
   `product_registry_engine.dart:1031`) *and* on a changed-key path
   (`:1019`). So the column leg is reachable too; bounding only the verifier call
   would have left it open.
2. **Two separate character classes, deliberately.** `confirmedBy` keeps
   accepting a **space** — it is a person's name, and "Dana Okafor" must work. The
   fingerprint rejects whitespace as well as control characters, because a
   fingerprint is a single opaque token that no `ssh-keygen -l` output can
   contain a space in. My first pass reused one class for both and would have
   broken ordinary operator names; I caught it before running anything and split
   them. `_kControlCharacter` (`[\x00-\x1f\x7f]`) and `_kNonTokenCharacter`
   (`[\x00-\x20\x7f]`), with the reason documented at each.
3. **No refusal quotes the value.** `_validatedConfirmer` already had this
   property; I kept it for the fingerprint too, and documented why. These
   messages reach a durable record, so a refusal that echoed the attacker's text
   would carry the forge into the path that rejects it. The test asserts it.

**Scope note.** The dispatch and the review both sized this at "3 lines". The
bounded *call* is 4 lines; the validator is ~25; the two regex/bound constants
and their reasoning are ~20. So ~50 lines, and I am reporting that rather than
under-scoping. I judged the sibling validator plus the shared, documented
character classes to be the honest minimum: a one-line
`if (fingerprint.contains('\n')) throw …` would close the newline but not the
length, would not cover `\r`/`\t`/the other C0 controls the sibling already
refuses, and would leave the asymmetry the review named half-open.

### Proof (requirement 1) — the reviewer's exact demonstration, inverted

New test: `apps/server/test/integration/credential_key_service_postgres_test.dart`
— *"a fingerprint carrying a forged log boundary never reaches the exception
(F-1)"*, in the same group as the M-5 test. It uses the reviewer's exact payload,
with the forged marker set to this file's own success line so a passing forgery
would be a plausible record of an event that did not happen:

```dart
const forged =
    '$_wrongFingerprint\n'
    '[credentials] credential.verify_access.completed ok';
```

Four proofs in the one test:

1. `verifyAccess(… hostKeyFingerprint: forged …)` throws
   `CredentialScopeException` whose `toString()` contains `hostKeyFingerprint`,
   contains no `\n`, and contains no `credential.verify_access.completed` — the
   refusal names the field without quoting the value.
2. It is **not** a `HostKeyNotPresentedException`, which is the audited type whose
   description interpolates the value. This is the assertion the reviewer's
   finding turns on.
3. The same guarantee asserted at the **sink** the review named, so the test does
   not depend on the exception's own rendering: whatever
   `credentialFailureLogFields` produces for this failure carries neither the
   newline nor the marker, and still contains `hostKeyFingerprint`.
4. **The legitimate value beside it still works** — `_wrongFingerprint` reaches
   the real verifier and is still refused by `HostKeyNotPresentedException`. This
   is what makes it a bound rather than a ban, and it is why the test cannot be
   satisfied by refusing everything.

At `7d1b1b8` this passes. **Removing the bounding makes it fail, and the failure
output reproduces the reviewer's demonstration** — see §4.

---

## 2. F-2 — I widened the guard **and** corrected the doc

The dispatch said "pick deliberately". I did both, because they are not
alternatives: the doc was the false statement, and leaving the guard as it was
would have left `SecretStoreException` — an audited type, so the type gate does
*not* cover this shape — with a net that its own doc advertised and its own code
did not provide. **Both bypasses now fail; the doc now states real scope; and the
residual a source audit cannot reach is covered by a positive assertion.**

### 2a. The two reproduced bypasses are closed

The old guard matched only a **multi-line** call site (`SecretStoreException\(\n`)
and only a **catch-binding interpolation** (`\$\{?error\b`). Both escapes were
real. Rewritten to match every call site regardless of line breaks, and to
reject any `reason:` argument that **names** a catch-clause binding except as the
argument of `secretlessText(…)`:

```dart
for (final match in RegExp(
  r'SecretStoreException\(\s*',
).allMatches(source)) {
  final block = _balancedCall(source, match.start);
  final reason = _argumentOf(block, 'reason');
  if (reason == null) continue;
  for (final name in caught) {
    final unsanctioned = reason.replaceAll(
      RegExp('secretlessText\\(\\s*$name\\s*\\)'),
      '',
    );
    if (RegExp('\\b$name\\b').hasMatch(unsanctioned)) { /* offender */ }
  }
}
```

`'$error'` and `_leak(error)` are now the same check; so are
`'${error.message}'` and a one-line call site.

The scan now also covers `lib/src/endpoints/credential_endpoints.dart`, which
holds a fourth `SecretProvider` implementation. The old doc said "any adapter"
while the guard scanned only `lib/src/credentials/**` — the same doc-vs-code gap
as B-2, one directory over. I verified both endpoint `SecretStoreException`
sites are literal-only and that the file has no `catch (name)` binding, so
adding it introduces no finding; it makes the claim true rather than weaker.

### 2b. The residual is named, and covered by a positive assertion

A source audit sees **names, not data flow**. It cannot follow a value aliased
through a local (`final message = '$error'; … reason: message`) or into a helper
in another file that catches for itself. Rather than leave that as a silent
residual — which is exactly how F-2 happened — the guard test now states it, and
a second test covers it for the adapter that actually handles key material:

> *"the real adapter reason carries no material, however it was produced"* —
> drives the **real** `LocalFileSecretProvider` through a **real** failure
> (a regular file where the store's directory should be, so the adapter's own
> `on Object catch (error)` block actually runs) while handing it a **real**
> ed25519 private key, and asserts on the string that came out: no fragment of
> the material in `reason`, none in `secretlessDescription`, and `reason`
> non-empty so the rule is not silence.

This is the reviewer's alternative option ("a positive assertion that a
`SecretStoreException.reason` contains no fragment of the material the adapter
handled") added *alongside* the widened guard rather than instead of it, because
it covers the residual the guard structurally cannot and the guard covers every
future adapter the assertion knows nothing about.

### 2c. Proof (requirement 2) — the bypass now fails

Mutations were applied in a **throwaway primary clone** outside the workspace
(`…/opencode/proof-keys`, deleted afterwards); the reviewed worktree was never
mutated.

**Before — at the reviewed HEAD `da68b5f`, both bypasses together:**

```
00:01 +7: no adapter interpolates a caught error into a reason no reason interpolates a catch-clause binding
00:01 +8: no adapter interpolates a caught error into a reason the reason of an adapter failure is still useful to an operator
00:01 +9: All tests passed!
```

`+9: All tests passed!` — the reviewer's exact reported figure, independently
reproduced.

**After — at `7d1b1b8`, each bypass alone:**

Bypass 1, the reviewer's: `reason: _leak(error)` with a top-level
`String _leak(Object error) => "store failed: $error";`

```
a SecretStoreException reason must be a literal, a package constant, or
secretlessText(...): [local_file_secret_provider.dart: reason hands the caught
`error` to something other than secretlessText(...)]
00:00 +8 -1: Some tests failed.
```

Bypass 2, the single-line call site:
`throw SecretStoreException(referenceName: …, reason: '$error');`

```
a SecretStoreException reason must be a literal, a package constant, or
secretlessText(...): [local_file_secret_provider.dart: reason hands the caught
`error` to something other than secretlessText(...)]
00:06 +9 -1: Some tests failed.
```

The reviewed worktree's own suite goes `+9` → `+10`, the extra test being the new
positive assertion.

### 2d. The corrected doc

`secret_provider.dart` now states what is enforced and what is not, and the
overstatement is gone. `secretless_error.dart` carried **the same false claim in
a second place** — plus a wrong path (`audit/secretless_error_test.dart`; the
file is `test/secretless_error_test.dart`) — and is corrected too. Both are in
owned files and both are the same defect, so leaving the second one would have
repeated the failure mode this dispatch exists to stop.

---

## 3. F-3 and F-4 — docs now match code (requirement 3)

Both were **doc** defects. The code is correct in both cases; F-4 explicitly
instructed "fix the doc, not the code", and I changed no code for either.

### F-3 — `_validatedConfirmer`, `credential_key_service.dart`

The old sentence claimed *"The value itself is reported back in the refusal,
since it is the operator's own text and they need to see what was rejected."*
The code reports `${trimmed.length} characters`. Corrected to:

> `/// NO REFUSAL QUOTES THE VALUE. The refusals name the field and, for the`
> `/// length refusal, report the length; they do not report the text back. The`
> `/// value is caller-supplied and these messages reach a durable record, so`
> `/// echoing it would make the refusal the forgeable surface instead of the`
> `/// field it is bounding.`

I did not simply replace "the value" with "the length", because the original
sentence's *reasoning* was the wrong part: echoing the value would have been
worse than the defect it describes. The corrected text says why it is not done.

### F-4 — `SshKeyPair`, `ssh_keypair.dart`

The old sentence claimed *"There is **no** public accessor that returns the seed
as a `Uint8List` or a `String`."* `privateSeed.bytes` is exactly that. Corrected
to the guarantee that actually holds — no **implicit** projection:

> `/// buffer had been wrapped at construction. Reaching the raw seed at all is`
> `/// an **explicit** act: [SecretBytes.bytes]. There is no implicit projection`
> `/// — no `toString`, no `toJson`, no operator — so nothing reaches a log line`
> `/// or a durable column by accident, which is the guarantee that actually`
> `/// matters here. (An earlier version of this sentence claimed there was "no`
> `/// public accessor that returns the seed as a `Uint8List` or a `String`".`
> `/// That was false — `privateSeed.bytes` is exactly that — in the same way`
> `/// the previous `String get privateKeyPem` contradicted the line above it,`
> `/// and it is corrected here rather than papered over.)`

The parenthetical names the hole rather than hiding it, which is what the
reviewer credited for the `privateKeyPem` removal.

The review also noted the neighbouring *"the three sites that genuinely need
them"* is really six. I counted them independently — three that genuinely
produce material (GCP request body, local store write, identity-file writer) and
three in crypto (`fromSeed` reading a recovered seed, wrapping a fresh copy,
`privateKeyPemBytes` handing it to the encoder) — and corrected the count with
each one named, plus the `rg` command that keeps it true.

---

## 4. Mutation proof — the corrections are load-bearing, not decorative

This is the standard the reviewer held the previous correction to, and the one
that separates "the fix works" from "the test is decorative".

**F-1, removing the bounding** (restoring `final fingerprint =
hostKeyFingerprint;` at the mutated commit, the `da68b5f` behaviour). The test
fails, and the failure output *is* the reviewer's demonstration:

```
04:01 +28 -14: credential_key_service_postgres_test.dart: the host-key
confirmation is labelled as operator-asserted (M-5) a fingerprint carrying a
forged log boundary never reaches the exception (F-1) [E]
  Expected: <Instance of 'CredentialScopeException'> with `toString`:
  (contains 'hostKeyFingerprint' and not contains '\n'
              '' and not contains 'credential.verify_access.completed')
    Actual: HostKeyNotPresentedException:<HostKeyNotPresentedException(
              github.com:22 — confirmed SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
            [credentials] credential.verify_access.completed ok, presented
            SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s, ...)>
   Which: is not an instance of 'CredentialScopeException'
```

That is `DESCRIPTION_CONTAINS_NEWLINE=true` and
`DESCRIPTION_CONTAINS_FORGED_MARKER=true` — the reviewer's two measurements,
produced again from inside the test runner, in an audited exception description
destined for Postgres.

**F-2, both bypasses** — §2c. Verified at `da68b5f` (passes, `+9`) and at
`7d1b1b8` (each fails alone).

**Nothing left behind.** After reverting the mutation, the clone's full
integration suite is green: **`+192: All tests passed!`**. The clone was then
deleted.

---

## 5. Load and cascade — reported rather than laundered

The machine was heavily loaded for this whole session (load averages 116 → 186 →
239 across the runs, on 8 CPUs), exactly as the dispatch warned. Recording it
because on this machine a bare pass/fail figure is not information.

| Run | Tree | Load before | Result |
|---|---|---|---|
| Gate | worktree `7d1b1b8` | 186.46 | `+191 -1`, sole failure dogfood |
| Proof, clean | clone `7d1b1b8` | 275.19 | **`+192: All tests passed!`** |
| Proof, mutated | clone `7d1b1b8` + F-1 mutation | 239.88 | F-1 test fails; total polluted |

**A cascade-polluted run is not evidence of a regression, so here is the
attribution.** The mutated run reported `-18` with `setUpAll` failures in
`concurrency_persistence_test.dart`, `defect_backend_postgres_test.dart`,
`design_governance_e2e_test.dart` and others — this is the M-2 pool-lock
cascade the reviewer recorded and could not reproduce, and it appeared on this
machine at load ~240. The **same commit with the mutation reverted** passed
`+192` with zero failures. The F-1 failure is therefore load-bearing: it is a
specific assertion about the forged marker, not a `setUpAll` artifact, and it is
absent the moment the bounding is restored.

I did not attempt to fix M-2. `docker/compose.test.yaml` `max_connections`, the
Makefile and a dedicated database are all `docker/**`/Makefile — prohibited, and
out of scope.

**Two load-related observations worth recording.** First, the clean clone run
passing `+192` while the worktree run gives `+191 -1` is not a discrepancy: the
sole difference is **dogfood**, whose assertion is *"dogfood expects a git working
tree at /private/tmp/shipit-impl-keys"*. This checkout is a **linked worktree**;
in a primary clone the assertion is satisfied and the test passes. So dogfood's
failure here is an artifact of the worktree layout, and it is red at `da68b5f`
and at base for the same reason. Second, base is `+170 -2` per the reviewer's
measurement, which supersedes the earlier `+171 -1`; my `+191 -1` against that
base is +21, fully accounted for: 19 integration + 20 non-DB tests added across
the two reviewed corrections, minus the D-4 flakiness, plus 1 new test here.

**Resource hygiene.** Every `make test-integration` ran the target's own
self-cleaning trap under a PID-scoped compose project, and each printed
`removing shipit_integration_<pid> (container + data)` followed by the container
and network `Stopping/Stopped/Removing/Removed` lines and no `CLEANUP FAILED`.
One run exited before creating anything and still printed its removal line and
"never existed"-equivalent output. **Zero mutating Docker or Compose commands
were issued by this lane**; no `make clean`, `make qa-down`,
`make test-env-down`, `make e2e-down`, or bare `down -v`. Per AGENTS.md I also
ran no `docker ps`/`logs`/`config` — the trap's own label-scoped leak check is
the evidence. QA was up on its stopgap run-mode override throughout and was not
disturbed; `docker/**` was read as text only.

One environment note for the next lane: `make test-integration` exits 2 before
creating any container unless `SERVERPOD_DATABASE_PASSWORD` is exported. I
exported the repository's own documented local default (already committed in
`.env.example`, so nothing secret is being handled here) so the client and the
disposable container agree. This matches the `PROJECT_FACT` already recorded in
`fix-credential-store-integrity/report.md`; I re-confirmed it rather than
assuming.

---

## 6. F-5 and F-6 — my own report's inaccuracies, corrected not deleted

**Where these are recorded, and a deliberate choice.** The two false claims are
in the closed task's report,
`docs/engineering/dispatch/tasks/correct-credential-key-service-b1b2/report.md`.
I have **not** edited that file. Two reasons: it is not in this dispatch's
`OWNED_PATHS` (`docs/engineering/**` is not), and it is a record the reviewer has
already verified — amending a closed report retroactively would alter a
provenance record after the fact, which is the same thing `aef-correction-loop`
forbids me to do to commits. So the correction is recorded **here**, quoting the
original claim verbatim so the record of what was claimed survives alongside what
is now known about it. If the Manager wants the b1b2 file itself amended, that
is a one-line routing decision, not something I should take unilaterally.

### F-5 — the `ignore` comment that does not exist

Original claim, at b1b2 report line 551 (repeated in the GATES block at line
779):

> "the single `ignore` comment in the diff is `prefer_initializing_formals` on
> the `SshKeyPair` constructor, with the reason inline."

**Withdrawn.** I re-verified rather than taking the reviewer's word for it:

```
$ git diff 8725b65..HEAD -- apps/server/lib apps/server/test apps/server/pubspec.yaml \
    | rg '^\+.*(//\s*)?ignore:'            -> NONE FOUND in added lines
$ for f in $(git diff --name-only 8725b65..HEAD); do rg -n 'ignore:' "$f"; done
                                                 -> NONE
$ rg 'ignore' apps/server/analysis_options.yaml  -> no analysis_options ignore
```

No `ignore` was added anywhere in the branch, in any changed file, in any layer.
The claim was false. What actually happened is better than what I described: the
`prefer_initializing_formals` concern was solved properly by splitting the
constructor into a factory over a positional generative constructor
(`ssh_keypair.dart:97-105`) so the field can be a *private* initializing formal,
with a comment explaining exactly why. My error was in the conservative
direction — I described a suppression that does not exist and implied the lint
was silenced, when in fact the lint was satisfied.

### F-6 — "no single one of them is sufficient on its own"

Original claim, at b1b2 report line 113:

> "The dispatch asked for the **class**. It is closed at three independent
> levels, because no single one of them is sufficient on its own."

**The necessity claim is withdrawn.** The reviewer measured that with both
unguarded decoders reintroduced, `secretless_error_test.dart` still passes
`+9` — because `FormatException` is unaudited, the type gate suppresses its
message on its own. So **level 2 alone would have blocked B-1's actual leak**,
and only level 1 was strictly necessary.

The **conclusion** stands and is, if anything, stronger than I claimed: the
custody-leak class is closed, by a mechanism rather than by two lines. Levels 2
and 3 are not necessary to close *this* leak; they are what make the *next*
version of this bug fail closed by default rather than leaky by default, and
F-1 is a live demonstration that the next version did arrive — a value this
correction left unbounded, on a path all three levels were supposed to cover, and
the levels did not catch it because the value was not a decode exception. What I
should not have claimed is that each level was load-bearing. A future editor who
removed level 3 on the strength of my sentence would have been misled about the
cost of doing so.

I have removed the false necessity claim from the record rather than leaving it
to be read again, and I have not deleted it: the original sentence is quoted
above so the correction is legible next to the claim.

---

## 7. Explicitly unchanged

- **M-4 stays.** Accepted by the reviewer; the ADR clause is met; `server.dart`
  is outside `OWNED_PATHS` and remains so.
- **M-5/M-6 residue stays tracked.** The outstanding M-6 handle question is an
  architecture/product decision owned by `design-agent`. The review's narrow
  note about `_destroyOrphan` on the handle-contract failure path is unchanged
  and still belongs to whoever implements the rotate path.
- **M-7** (discoveries not persisted) remains a Manager-owned step;
  `docs/engineering/**` is outside this dispatch's `OWNED_PATHS`.
- **L-5, L-6** unchanged. **F-7** (the `ps`-walk window) unchanged and still an
  accepted bound.
- **M-2** not fixed; out of ownership. Measured firing this session at load
  ~240 — I have now observed the hazard the reviewer recorded as plausible and
  unquantified, which is worth having, though the observation is under load I did
  not control.

No finding required a product, architecture, security, infrastructure or
deployment decision, so nothing is escalated as `HUMAN_DECISION_REQUIRED` from
this lane.

---

## 8. Durable discoveries (classified, for the Manager to route)

1. **`WORKFLOW_IMPROVEMENT`** — a source-level guard cannot see a `catch (…)`
   binding in *another file*, and cannot follow a value through a local. When a
   guard is the only net for a shape (because the shape's type is audited), its
   documented scope must state per file what it covers, and a positive assertion
   that inspects the produced string is the only thing that covers the residual.
   F-2 was caused by precisely this gap, and B-2 by a doc asserting the opposite
   of its code; the pattern is "an audit that claims more surface than it reads".
   Priority: reusable, not product-specific.
2. **`PROJECT_FACT`** — dogfood asserts on a *git working tree* and therefore
   passes in a primary clone but fails in a linked worktree such as
   `/private/tmp/shipit-impl-keys`. It is not a real regression signal in a
   worktree, and recording that saves the next lane from investigating it.
3. **`CONTRADICTION` (minor, self-corrected)** — `secretless_error.dart`
   referenced its guard test at `audit/secretless_error_test.dart`; the real path
   is `test/secretless_error_test.dart`. Fixed in this commit. Noted because it
   is the same class as F-2/F-3/F-4 (documentation pointing at something other
   than what exists) and there may be more instances elsewhere in the repo that no
   lane has audited yet — a cheap repository-wide check would settle it.

None of these were persisted to `docs/**`: `docs/engineering/**` is outside this
dispatch's `OWNED_PATHS`, which is exactly M-7 and is the Manager's step.

---

## 9. What I did not do, stated plainly

- I did **not** run `serverpod generate`, so no generated artifact changed.
- I did **not** touch `migrations/**`, `tool/**` or `lib/src/generated/**`.
- I did **not** weaken, skip, filter or delete a single test. No `@Ignore`,
  `@Skip`, `only:`, `tags:` or `excludeTags` was introduced. Net test growth this
  commit: **+1 non-DB, +1 integration**. Both new tests fail when the
  corresponding fix is reverted (§4).
- I did **not** push, merge, or touch `main`.
- I did **not** print, log or echo the private half — not in code, not in a test
  failure message, not in this report. The new F-2 positive test generates a real
  key and asserts on substrings; its failure reasons are written so that a
  failure prints no material.
- I did **not** edit the closed b1b2 report (§6), for the reasons given there.