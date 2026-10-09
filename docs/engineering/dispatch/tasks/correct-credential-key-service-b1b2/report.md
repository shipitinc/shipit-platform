# Correction Report — correct-credential-key-service-b1b2

```
RESULT: CORRECTION_COMPLETE

CORRECTED_FROM_HEAD: 315e9ca21ea6b33cfbaa9f0411db69951867e16e
NEW_HEAD:            da68b5f67d3766776b35d57d16956dd4b993ae7e

BRANCH:   impl/credential-key-service
WORKTREE: /private/tmp/shipit-impl-keys
COMMITS:  4 — 428f4fa → 4ac16a3 → 315e9ca → da68b5f (NEW, on top; nothing rewritten)
BASE_SHA: 8725b65deaab565f7c3b93d644e73f1ec07a6f39  (main, untouched)
```

Pre-flight verified before any write: `git branch --show-current` == `impl/credential-key-service`,
`git rev-parse HEAD` == `315e9ca21ea6b33cfbaa9f0411db69951867e16e`, working tree clean. The three
reviewed commits are byte-identical to what the reviewer reviewed; the correction is one new commit
on top. Nothing pushed, nothing merged, `main` still at `8725b65`.

The reviewer's core judgement was right and I have nothing to add to it: `SecretBytes` is sound, key
generation is real ED25519, the response type is the whitelist, persistence holds, fail-closed is
genuinely proven, and the cleanup proof was sound. Both blockers were custody leaks, and both were
mine.

---

## 0. Ownership

```
OWNED_PATHS       apps/server/lib/src/credentials/**      (8 modified, 1 new)
                  apps/server/lib/src/endpoints/**        (credential_endpoints.dart)
                  apps/server/test/**                     (4 modified, 1 new)
READ_ONLY_PATHS   apps/server/lib/src/generated/**        NOT TOUCHED
                  apps/server/migrations/**                NOT TOUCHED
                  docs/adr/0018-per-product-git-credentials.md  read only
PROHIBITED_PATHS  apps/control_plane/** packages/** docker/** .github/**
                  docs/adr/** .decisions/**                NOT TOUCHED
```

`git diff --name-only 315e9ca..da68b5f | rg 'migrations/|lib/src/generated/|packages/|docker/|control_plane/'`
→ **empty**. `pubspec.lock` is unchanged by this correction (no dependency added or promoted), so
L-5's disclosure is unchanged but not repeated.

**`serverpod generate` was NOT run.** No endpoint signature changed, so no regeneration was needed.
`apps/server/lib/src/generated/**` is byte-identical to `315e9ca`. The `serverpod_test_tools.dart`
wrapper is untouched, so the next client lane's regeneration is unaffected.

---

## 1. M-1 — the baseline was wrong, and here is why

**The reviewer's `+171 -1` is correct. My `+108 -10` is withdrawn.**

Re-measured independently, in a fresh **primary clone** at `8725b65`:

```
$ git clone /Users/alkebut/air/shipit-platform <tmp>/base-clone && git checkout 8725b65
$ git rev-parse HEAD  -> 8725b65deaab565f7c3b93d644e73f1ec07a6f39
$ file .git           -> directory          (a primary clone, not a linked worktree)
$ dart pub get        -> Got dependencies!   (exit 0)
$ SERVERPOD_DATABASE_PASSWORD=shipit make test-integration
01:16 +171 -1: Some tests failed.

Failing tests:
  test/integration/dogfood_shipit_postgres_test.dart: S-1 DOGFOOD — Product: ShipIt
    (Postgres, read-only) register ShipIt, discover pinned HEAD read-only,
    propose baseline, survive restart

Failed to acquire pool lock occurrences: 0
Cleanup: Container shipit_integration_45832-postgres_integration-1 Removed
         Network shipit_integration_45832_default Removed
```

This reproduces the reviewer's figure exactly, on a run of mine. **172 tests ran; 171 passed, 1
failed.** The gate is red at `BASE_SHA`, before this feature exists, for a reason in `packages/**`.

### The reconciliation, and it is arithmetic rather than speculation

`108 + 10 = 118` tests ran in my reported baseline. `171 + 1 = 172` run in a clean one. **54 tests
never ran.** A `withServerpod` file whose `setUpAll` throws reports **one** failure for the entire
file and **none** of that file's tests — which is precisely the shape a `Failed to acquire pool
lock` cascade produces: fewer tests counted, more failures counted. The figure I reported was a
**cascade-polluted run mis-labelled as a baseline**, not a property of `BASE_SHA`.

I can show the shape reproducing rather than assert it. Five runs of this gate at the corrected HEAD
on this machine, with the pool-lock occurrence count:

| run | result | pool-lock occurrences | what failed |
|---|---|---|---|
| base clone `8725b65` | `+171 -1` | 0 | dogfood only |
| run 1 | `+189 -2` | 0 | dogfood + one concurrency race (§6) |
| run 2 | `+130 -9` | 111 | 4 unrelated `setUpAll`s |
| run 3 | `+11 -21` | 289 | 9 unrelated `setUpAll`s, incl. Serverpod start timeout |
| run 4 | `+181 -3` | 130 | 2 unrelated `setUpAll`s |
| run 5 | `+138 -5` | 118 | 4 unrelated `setUpAll`s |

Run 2 is `+130 -9` — the same *shape* as my old `+108 -10`: a large drop in the number of tests that
ran, paired with a jump in failures, and 111 pool-lock occurrences. The reported baseline was that,
at base. It is withdrawn, and the corrected base is **`+171 -1`**.

**Machine load is the variable, and it is not mine.** `uptime` during these runs: 113–214. The
cascade is a load-dependent connection-starvation artifact on a machine currently under extreme
external load; it is not caused by this change (see §6 for the causal analysis). I could not obtain a
fully clean run and I am not going to pretend I did.

---

## 2. B-1 — the custody leak, and closing the class rather than the two lines

`jsonDecode` at `:161` and `base64.decode` at `:172` were unguarded, `credential_endpoints.dart:162`
logged `error.toString()`, and the Serverpod session log persists that to Postgres. Correct.

The dispatch asked for the **class**. It is closed at three independent levels, because no single one
of them is sufficient on its own.

### 2.1 Every decode/parse in the adapters now fails typed

`GcpSecretManagerSecretProvider.read` has exactly one exit per failure shape, each a literal reason:

| malformed input | previously | now |
|---|---|---|
| not JSON at all | `FormatException` carrying an excerpt | `SecretStoreException`, `'the access response was not JSON at all; …'` |
| JSON but not an object | `TypeError` from `as Map<String, dynamic>` | `'the access response was not a JSON object; …'` |
| `payload` absent / not a map | `TypeError` or `null` | `'the access response carried no payload.data string'` |
| `payload.data` not a `String` | `TypeError` | same literal |
| not decodable base64 | `FormatException` **containing base64 private-key material** | `'the access response payload was not decodable as base64; …'` |

The casts are gone too: shape is checked with `is`, which yields a boolean, rather than `as`, which
throws an exception whose text this method does not control.

I also found and closed a **third-party** instance of the same class that B-1 did not name.
`_send` interpolated Google's `error.message` — free text from a third party — into a
`SecretStoreException` reason. On `addVersion` that request carries the base64 private key, so a
service in a position to echo it could put the payload into our exception message. The rule now
enforced is not "never report a service message" but:

> **a third-party message is included only when this request carried no key material.**

`addVersion` (the only request carrying material) reports `HTTP <code> (the service message was
withheld because this request carried key material)`; `create`, `access` and `destroy` keep the
diagnostic. Tested both ways (§2.4, tests 5 and 6).

### 2.2 The sink is gated by type, not by call-site discipline

New file `apps/server/lib/src/credentials/secretless_error.dart`:

```dart
abstract interface class AuditedFailure {
  String get secretlessDescription;   // built only from the fields the impl names
}

String secretlessText(Object error)     // an audited type's own fields; anything else → type only
Object  redactUnauditedFailure(Object e) // audited → unchanged; unaudited → UnauditedFailure
```

`error.toString()` is **never called** by the endpoint. The consequences:

- an exception type that has not opted in has its message **suppressed entirely** — only its
  `runtimeType`, which is a code identifier and cannot contain bytes;
- `redactUnauditedFailure` substitutes at the boundary so Serverpod's *own* unhandled-endpoint-error
  logging cannot reach the original message either;
- **a new failing path is silent by default rather than leaky by default.** That is the structural
  property B-1 asked for, and it is the one `SecretBytes` could not provide: `SecretBytes` protects
  values this code holds, and B-1 was a value a third-party exception captured on its behalf.

Audited types: `SecretStoreException`, `SecretProviderNotConfiguredException`, `PosixPermissionException`
(new), `HostKeyNotPresentedException`, `ScratchCleanupException`, `AccessVerificationTimeoutException`
(new), `CredentialScopeException`, `UnsupportedRepositoryUriException`.

Both endpoint `catch` blocks now log through one named function, `credentialFailureLogFields`, so
"the failure log line cannot carry an exception message" has a single implementation and a test that
can name it.

### 2.3 The three `$error` interpolations that were the same bug

`local_file_secret_provider.dart:82`, `:108` and `:127` all read `reason: '$error'` — the identical
shape, one file over, and the reviewer's `.bytes` audit could not see it. All three now read
`reason: secretlessText(error)`. The diagnostic **survives** (path, mode, OS message), because
`FileSystemException` and `ProcessException` have no field for file *content* and the projection reads
only `message` / `osError` / `path` — and `ProcessException.arguments`, the one field that could
carry something, is deliberately not read.

`PosixFileModes` also stopped throwing `StateError` built by string interpolation and now throws a
typed `PosixPermissionException(path, intendedMode, actualMode, detail)`, so its message is auditable
by inspecting the three fields rather than by trusting the `catch` that reports it.

### 2.4 PROOF — `apps/server/test/secret_provider_test.dart`, 6 new tests

The real adapter, against a real loopback `HttpServer`, serving one specific malformation each time.
The stub serves the metadata token too, so no production test seam was added.

```
a malformed secret at rest cannot reach a log line (B-1)
  a truncated access body yields a typed, silent failure
  an undecodable payload yields a typed, silent failure
  a non-object access body yields a typed, silent failure
  a payload of the wrong type yields a typed, silent failure
  a service that echoes our own request body cannot get it into a message
  a service message is still reported when no material was sent
```

Each asserts, on **both** shapes that reach a durable record — the exception's own `toString()`
(which Serverpod logs for an unhandled endpoint error) and `secretlessText(...)` of it — that none of
five forbidden fragments appears, where the fragments are **substrings** of the payload, not the
whole value:

```dart
const List<String> _forbiddenMaterialFragments = [
  'AAAAB3NzaC1lZDI1NTE5AAAAIEXAMPLESECRETHALFBASE64',
  'EXAMPLESECRETHALFBASE64',
  'SECRETHALF',
  'BASE64MATERIALHERE',
  'BASE64MATERIAL!!!',
  'PRIVATE KEY',
];
```

A whole-value containment test would pass on the exact defect, because a decoder embeds only an
excerpt. The assertions are `contains(fragment) == false` with a *label* in the reason, so even a
failure prints no material.

**Test 5 is the adversarial one**: the stub reads the real deploy key out of the `addVersion` request
body and returns it inside Google's `error.message`. The test first asserts the stub really received
>40 characters of material (so it is the echoing case, not a request that carried none), then asserts
the refusal carries `HTTP 400` + `withheld` and none of the payload.

**NEGATIVE CHECK — the tests genuinely fail against the defect.** I reintroduced both unguarded
decoders, ran the suite, and reverted:

```
defect reintroduced
00:03 +19 -1: … a truncated access body yields a typed, silent failure [E]
00:03 +19 -2: … an undecodable payload yields a typed, silent failure [E]
--- REVERTED ---
00:01 +25: All tests passed!
```

### 2.5 PROOF — the sink and the type gate, `apps/server/test/secretless_error_test.dart` (new, 9 tests)

- every material-bearing failure is stripped at `credentialFailureLogFields`, where the fixtures are
  produced by **really performing** `jsonDecode` and `base64.decode` rather than by writing a message
  that looks like one — with a sanity assertion that at least one of them really does carry material,
  so the test cannot pass vacuously;
- an unaudited failure loses its message entirely and is still diagnosable by type;
- an audited failure keeps its own fields, so the rule is not "be quiet";
- `redactUnauditedFailure` substitutes rather than forwards, and preserves the type of an audited
  failure so callers keep working;
- a `FileSystemException` keeps its path and OS message;
- **a source guard**: reads `lib/src/credentials/**`, strips comments, and fails if any
  `SecretStoreException` argument block interpolates a **catch-clause binding** — the
  `reason: '$error'` shape, in any adapter, in any file. The rule is stated precisely (literals and
  package constants are fine; caught objects are not) rather than as a blanket ban on `$`, so it does
  not fire on `$code`, `$accessTokenEnv` or `$kNoMaterialEchoed`.

**NEGATIVE CHECK** — I reintroduced `reason: '$error'` in one adapter:

```
00:00 +7 -1: … no reason interpolates a catch-clause binding [E]
  … local_file_secret_provider.dart: reason interpolates the caught `error`
--- REVERTED ---
00:00 +9: All tests passed!
```

### 2.6 PROOF — end to end, against real Postgres

`credential_key_service_postgres_test.dart` gains a test that drives the real GCP adapter against a
loopback stub returning a truncated 2xx body, then asserts that **all three** durable-reaching shapes
— the exception message, `secretlessText` of it, and `credentialFailureLogFields(...)` — contain none
of five payload fragments, and that **no credential row exists** for the repository.

---

## 3. B-2 — the custody type discipline, end to end

The finding was that `privateSeed` was a public `Uint8List`, `privateKeyPem` was a public `String`,
and the class doc asserted the negation of both. All three are fixed, and the `String` is gone at the
root rather than confined at the call site.

**`privateSeed` is now a `SecretBytes`.** Not a private field with a test accessor — the wrapper
itself, so a `log('$pair.privateSeed')` emits `<secret redacted, 32 bytes>` exactly as if the raw
buffer had been wrapped at construction, and reaching the bytes requires an explicit `.bytes` at the
three sites that need them. `SshKeyPair._` is a factory over a positional generative constructor
`SshKeyPair._custody(this._privateSeed, …)`, because a *named* parameter cannot be `_privateSeed` —
Dart takes the public part of the name, so naming it would publish the field. That is also why the
constructor is split in two rather than carrying a `prefer_initializing_formals` ignore: the lint's
suggestion is precisely the change B-2 forbids.

**`String get privateKeyPem` is deleted, and `encodeOpensshPrivateKeyPem` is now
`encodeOpensshPrivateKeyPemBytes`.** PEM is base64, and base64 of these bytes is ASCII, so the whole
armouring is emitted as bytes (`_pemArmour`) and **no `String` of key material is ever constructed** —
not in the codec, not in the intermediate frame, not in the test that hands the file to `ssh-keygen`.
The old `_pemWrap` returned the whole armoured document as a `String` and the getter handed it to
anyone who asked; there is nothing left to confine.

**The doc now matches the code.** It states what `privateSeed` is and why, names the one private
accessor that exists, and says explicitly that the previous `String get privateKeyPem` "was the exact
hole this doc used to deny existed".

### PROOF

- **Runtime**: `privateSeed` is a `SecretBytes`, `privateKeyPemBytes` is a `Uint8List`, and
  interpolating the seed does not yield the key.
- **The declared public surface is exactly the safe one.** A source audit of the `SshKeyPair` class
  body — comments stripped, class-member indentation only, `_`-prefixed declarations skipped — is
  compared against an allow-list:

  ```dart
  {algorithm, comment, fingerprint, privateKeyPemBytes, privateSeed,
   publicKeyAuthorizedLine, publicKeyBlob, publicKeyBytes, toString, wipeSeed}
  ```

  Adding a `String`, a `Uint8List` or a `List<int>` projection fails the test instead of reaching
  review. **NEGATIVE CHECK** — I re-added `String get privateKeyPem` and it failed:

  ```
  00:00 +9 -1: … the declared public surface is exactly the safe one [E]
  --- REVERTED ---
  00:01 +15: All tests passed!
  ```
- **The doc test** reads the class doc and asserts it no longer claims `deliberately holds no`, and
  does name `privateKeyPemBytes`.

### The test-file consequence, which the dispatch specifically warned about

Two existing tests would have printed a deploy key into the test output on failure — the same
durable-record prohibition reached through a failing matcher, which `SecretBytes` cannot prevent:

- `credential_keypair_test.dart` asserted `expect(pair.privateKeyPem, startsWith(...))`. A failure
  prints the whole PEM. Every PEM assertion is now a **boolean** over a decoded string
  (`pem.startsWith(h) == true`), so the failure prints `false`.
- `secret_provider_test.dart` asserted `expect(utf8.decode(read.bytes), pem)`. Now
  `expect(_sameBytes(read.bytes, pem), isTrue)`, and `_sameBytes` returns a bool.

---

## 4. M-3 — a timeout no longer leaves a `git`/`ssh` child alive

`Process.run(...).timeout(ceiling)` is a *Future* timeout: it stops the Dart side from waiting and
nothing else. On a clone that is not a leaked CPU — it is a live `git` with a live `ssh` child, both
holding the identity, both still able to authenticate with it, while the caller has already been told
the verification failed and has deleted the scratch tree.

`_runGitClone` now goes through `_runBounded`, which owns the `Process`:

1. `Process.start`, and the stdout/stderr joins and `exitCode` held;
2. on `TimeoutException`, **descendants are enumerated from `ps` *before* the parent is signalled** —
   signalling the parent first would re-parent the children to `init` and lose them;
3. `SIGKILL` to the direct child and to every enumerated descendant, deepest last. `SIGKILL` rather
   than `SIGTERM` because a `git` blocked in a network read installs no handler and must not be given
   the chance to;
4. the drain is awaited under a 5 s bound, then `AccessVerificationTimeoutException` is thrown — a
   typed, audited failure naming the helper, the ceiling and the pids that were signalled.

Dart has no API to place a child in a new process group, and macOS has no `setsid`, so a `ps` walk is
the honest answer rather than a `setsid` that would work on Linux only. `ps` is resolved through
`pathPrefix` like every other helper, because this runs while the private half is on disk. If `ps`
cannot answer, the walk degrades to killing the direct child — never to skipping the kill.

**The same treatment was applied to `_scanHostKeys`**, which had the identical `Process.run(…).timeout`
defect and would otherwise leave an `ssh-keyscan` running after the method gave up, and to
`_sshKeygenFingerprint`, which had **no** timeout at all and could hang `verify` for ever on a
`ssh-keygen` waiting for stdin this method will not write.

L-1 is resolved at the same time: `ScratchCleanupException`'s doc claimed a leftover private half "is
an exception rather than a log line", which was true on the failure path and false on the success
path. One rule now: a tree this process could not remove is an exception on **every** path. The dead
ternary `removed ? outcome.failureReason : outcome.failureReason` is gone.

### PROOF — `repository_access_verifier_test.dart`, `a timeout kills the process tree, not just the wait (M-3)`

The stub `git` forks a **grandchild** that opens the identity on a file descriptor and then sleeps
120 s, and records both pids. Dart's `kill` reaches only the direct child, so **the grandchild is the
part that proves the tree was walked** rather than the top process signalled.

```dart
expect(thrown, isA<AccessVerificationTimeoutException>());
expect(seen['child_opened_identity'], 'yes');   // it really was holding the key
for (final pid in [gitPid, childPid]) {
  expect(await _waitUntilDead(pid), isTrue, reason: 'pid $pid survived the clone timeout');
}
expect(scratch trees under systemTemp, isEmpty);
```

`kill -0` is the existence check (signal 0, no delivery), polled for up to 10 s because a signalled
process is reaped asynchronously and a single sample would be a race the test could lose.

**NEGATIVE CHECK 1** — the pre-correction `Process.run(…).timeout()` restored:

```
00:09 +5 -1: … the clone child and its grandchild are gone, and so is the file [E]
  Expected: Instance of 'AccessVerificationTimeoutException'
    Actual:   TimeoutException:<TimeoutException after 0:00:02.000000>
```

**NEGATIVE CHECK 2** — the typed exception kept but the kill removed:

```
00:25 +6 -1: … [E]
  Expected: true / Actual: <false>
  pid 40802 survived the clone timeout
```

Both reverted; the suite passes. This is the proof the dispatch asked for: not success, not ordinary
failure, but **the timeout path, with the child killed and the file gone**.

---

## 5. M-5 — the host-key confirmation is labelled for what it is

The reviewer is right that this is an enforcer over an **unauthenticated, client-asserted** value, and
that ADR 0018 §A2's gap is **narrowed, not closed**. Binding the confirmation to something the server
obtained needs a separate out-of-band transport and is a product decision, so I state it plainly at
every layer rather than pretend otherwise:

1. **`kHostKeyConfirmationProvenance`** is a published constant and a **required field of
   `AccessVerification`**, present in the response whitelist:

   > `operator-asserted: the fingerprint was supplied by the caller and is not authenticated by the
   > server; the server independently obtained the host key and enforced that they matched`

   A client — and a reader of a stored response — cannot mistake it for server-verified.
2. **`confirmedBy` is validated before it is persisted.** It attests to nothing, but it is written to
   `hostConfirmedBy` / `lastVerifiedBy`, which an operator reads as an audit trail. Empty (the domain
   checks it too), over 128 characters, and control characters are refused. The control-character
   case matters specifically: it is a forge-the-previous-log-entry primitive. Tested with three hostile
   values.
3. **`RepositoryAccessVerifier.verify`** now documents, on the method, what it does and does not
   establish — "a transport enforcer for an operator-asserted trust decision", including that a caller
   which scanned the network itself and supplied an attacker's key gets a clone against the attacker,
   faithfully enforced.
4. **`CredentialEndpoints.verifyAccess`** carries the same statement at the HTTP boundary.

My prior report's headline "**This closes a recorded gap**" was an overstatement. Withdrawn.

---

## 6. M-6 — the reference name, resolved as far as this lane may resolve it

`credential_key_service.dart` annotated the field *"Not the material; §13a by name, never by value"* —
the exact reasoning `9417f8bf` rejects, because §13a is what makes **credentials** safe to reference
and is not an assurance that a **reference** is harmless.

What I can make structural, I did, and it is the part that was previously only a property of whichever
adapters happened to exist:

- `SecretProvider.store` now documents a **handle contract**: the returned handle must be the bare
  reference name, never a provider-specific path, ARN or URL.
- `CredentialKeyService.generate` **verifies it** and fails the mint otherwise:

  > `the provider returned a handle that is not the reference it was given. Under ADR 0018 A3 the
  > reference is the sensitive artifact (9417f8bf gap G-7), so a handle that discloses vault topology
  > must never reach a client. The mint is refused.`

So `MintedCredential.referenceName` is provably `GIT_REPOSITORY_<sanitised repositoryId>_SSH` — a
pure function of an input the caller just supplied — and a future adapter returning an ARN breaks
loudly instead of leaking quietly. Tested: `_RenamingSecretProvider` returns
`projects/p/secrets/<ref>/versions/1`; the mint is refused, the failure carries no ARN, and **no row
is written**.

**What remains open and is not mine to decide**: replacing the raw reference with a non-identifying
handle is `9417f8bf` G-7, owner `design-agent`. That contradiction is real, it is recorded in the field
doc in those terms with a pointer to the open decision, and it is not settled here. A comment alone
would have been the failure mode; the enforcement above is not.

---

## 7. M-4 — fallback selection: recorded why not moved, and a seam to move it

ADR 0018:232-234 requires fallback selection to be "a recorded precondition, not a silent default".
It **is** recorded before any key can be minted — but on the first *credential call*, so a deployment
that never mints a credential records nothing and an operator cannot answer "is QA running on the
fallback?" from the log at all.

**It could not be moved from inside this lane, and the reason is structural rather than procedural:**
the destination is a Serverpod *session* log, so the write needs a `Session`, and a session does not
exist at process start. The startup log is `stdout`, reached from `apps/server/lib/server.dart` —
which is **outside this lane's `OWNED_PATHS`**. The dispatch did not grant it and I did not take it.

So I did what is inside the boundary:

- `CredentialEndpoints.recordCustodyPrecondition(Session)` is a **named seam** for that wiring: call it
  with any session at start-up and the precondition is recorded before anything else can happen.
  Tested — it resolves and returns the substrate, and it is memoised, so it is one process-start fact
  rather than a line per mint.
- An unset substrate returns a marker whose `describe()` says `resolved: false` and which **throws on
  any use**. Inventing a provider there would be the silent default the ADR forbids, so the refusal is
  surfaced rather than papered over. Tested.
- The outstanding change is one call in `run()`. Recorded as an `AUTOMATION_OPPORTUNITY` for the
  `server.dart` owner in §12.

---

## 8. The rest of the findings, triaged

| # | Finding | Disposition |
|---|---|---|
| **M-1** | base figure does not reproduce | **FIXED (measurement).** Base re-measured at `+171 -1` in a primary clone; `+108 -10` withdrawn and the cascade explained arithmetically. §1 |
| **M-2** | pool-lock cascade, this lane's 20th file contributes | **NOT FIXED — out of ownership.** Fixes are `docker/compose.test.yaml` `max_connections`, the Makefile, or a dedicated database; all touch `docker/**` or the Makefile, both prohibited. Recorded with the measurement: 5 runs at HEAD, cascade in 4 of them, host load 113–214 throughout. §1 table, §12 |
| **M-3** | timeout does not kill the child | **FIXED.** `Process.start` + `ps`-walked tree kill; same treatment for `ssh-keyscan` and `ssh-keygen`; negative-checked. §4 |
| **M-4** | fallback logged on first call, not startup | **PARTIALLY FIXED.** Cannot be moved from this lane (reason recorded, §7); a named seam was added and tested. The one-line `server.dart` call is outstanding and routed. |
| **M-5** | `hostKeyFingerprint`/`confirmedBy` unauthenticated | **FIXED as far as this lane may.** Provenance published on the response, `confirmedBy` bounded, documented at three layers. My prior "closes a recorded gap" is withdrawn. §5 |
| **M-6** | `"Not the material"` annotation | **FIXED + escalated.** Handle contract enforced, mint fails on a non-conforming handle, no row written; G-7's remaining decision named as its owner's. §6 |
| **M-7** | discoveries classified but not persisted to `docs/engineering/learning/` | **NOT FIXED — out of ownership.** `docs/engineering/**` is not in this dispatch's `OWNED_PATHS`. Classified findings re-stated in §12 for the Manager to persist. |
| **L-1** | dead ternary; inconsistent cleanup semantics | **FIXED.** Ternary removed; a tree this process could not remove is now an exception on every path. |
| **L-2** | identity written before the host key is confirmed | **FIXED.** Scan first, then write. The existing failure-path proof still asserts `identity_exists == yes` from inside the stub, so it still proves the write happened on the path that reaches the clone. |
| **L-3** | GCP re-mint leaves the previous version readable | **FIXED as a documented bound.** `store` deliberately adds a version rather than destroying first (destroying would delete a live installed credential's half), so a **rotation without a revocation** leaves both readable. Recorded in the adapter doc as a bound on §A2, with the note that `destroy` still removes every version, so an actual revocation is complete. |
| **L-4** | no revoke endpoint; `supersedesCredentialId` unreachable | **NOT FIXED — out of scope by the dispatch's own words** ("must not be forgotten"). Adding an endpoint method requires `serverpod generate`, which is **prohibited here** (it rewrites `packages/control_plane_client`, owned by the next client lane, and `lib/src/generated/**`, `READ_ONLY`). Re-stated in §12 as an open item. |
| **L-5** | root `pubspec.lock` outside `OWNED_PATHS` | **NOT FIXED — not fixable retroactively.** Unavoidable and disclosed in the reviewed commit; **this correction adds no dependency**, so the lockfile is unchanged (`git diff --name-only 315e9ca..da68b5f` → no `pubspec` entry). The dispatch's `OWNED_PATHS` should name the root lockfile next time. |
| **L-6** | unrelated stale nullability bundled into the test-tools regeneration | **NOT FIXED — cannot be.** The correction is a new commit and rewriting `315e9ca` is forbidden (the review's provenance depends on it). Already flagged in that commit's message; carried forward here so the next `product_registry` reviewer is not surprised. |
| **L-7** | public test-only seams on a production `Endpoint` | **FIXED (narrowed).** `environmentOverride` (a public mutable field, reassignable at any time by anything holding the endpoint) → `_environmentOverride`, set once by a named `CredentialEndpoints.forTesting({environment})` constructor; `resetCustodyForTesting` was **unused** and is deleted. Blast radius is now "one endpoint constructed for a test" rather than "any holder of the endpoint". |
| **L-8** | the known_hosts negative test was a wrapper-text proxy | **FIXED.** The stub `git` now reads `known_hosts` out of the generated wrapper and reports its **contents**. The test asserts the confirmed key is present, the unconfirmed key is **absent**, and the file has exactly **one** non-empty line — "the right key is somewhere in there" is no longer good enough. |

Nothing was silently dropped.

---

## 9. Gates — verbatim, at `da68b5f`

All run in `/private/tmp/shipit-impl-keys`.

```
$ dart pub get                                     (repo root)
Got dependencies!
exit 0

$ dart format --output=none --set-exit-if-changed .
Formatted 655 files (0 changed) in 5.84 seconds.
exit 0

$ dart analyze apps/server
Analyzing server...
No issues found!
exit 0

$ dart test test/credential_keypair_test.dart test/secret_provider_test.dart \
           test/repository_access_verifier_test.dart test/secretless_error_test.dart
00:13 +56: All tests passed!        (was +37 at the reviewed HEAD)

$ bash apps/server/tool/verify_schema_bootstrap.sh
21 checks, all OK
exit 0

$ SERVERPOD_DATABASE_PASSWORD=shipit make test-integration
01:14 +189 -2: Some tests failed.
exit 2
```

`dart analyze apps/server` is clean at **exit 0** — no errors, warnings or infos, nothing suppressed
and nothing `@Skip`ped. (The `unnecessary_cast`, `prefer_initializing_formals` and
`unnecessary_brace_in_string_interps` diagnostics that appeared during the work were **fixed**, not
ignored; the single `ignore` comment in the diff is `prefer_initializing_formals` on the `SshKeyPair`
constructor, with the reason inline.)

### `make test-integration` is RED — two failures, and I can account for both

Best run (`+189 -2`, zero pool-lock occurrences):

```
Failing tests:
  test/integration/dogfood_shipit_postgres_test.dart: S-1 DOGFOOD — Product: ShipIt
    (Postgres, read-only) register ShipIt, discover pinned HEAD read-only,
    propose baseline, survive restart
  test/integration/product_credential_immutability_postgres_test.dart:
    Postgres upholds credential key-material immutability (ADR 0018 A1)
    D-4 under concurrency: two mints of one id yield one row and one identity conflict
```

1. **dogfood** — red at `BASE_SHA` (`+171 -1`, §1), defect in
   `packages/product_registry/…/read_only_repository_reader.dart`, **prohibited to this lane**. Not
   introduced here and not fixable from here.
2. **D-4** — a pre-existing **concurrency race** in a file this correction does not touch
   (`git diff --name-only 315e9ca..da68b5f | rg immutability` → nothing). It calls
   `engine.recordGeneratedCredential` **directly**; no `CredentialKeyService`, no endpoint, no
   verifier, no provider, so there is no causal path from this change to it. It is load-sensitive —
   under `load average 113` its `_ReadBarrier` interleaving produces the one-active-per-repository
   refusal where the test expects the identity conflict.

**The other four runs were cascade-polluted** (111 / 289 / 130 / 118 pool-lock occurrences,
`+130 -9`, `+11 -21`, `+181 -3`, `+138 -5`) and are reported in §1's table rather than hidden. The
machine ran at load 113–214 throughout; the cascade is a load-dependent artifact and I could not
obtain a fully clean run. **I am not claiming a green gate.**

**My own integration tests: all 19 pass.** In the best run there is **no `[E]` line for
`credential_key_service_postgres_test.dart`**, and the reporter emits a per-test `[E]` for every other
file that fails. The one run in which my file did fail did so at `setUpAll` with
`Serverpod did not start within the timeout of 0:00:30` — a cascade symptom, in a run with 289
pool-lock occurrences.

**Test counts**: 12 → 19 integration tests in this file; 37 → 56 non-DB tests. **Nothing weakened,
skipped, `@Skip`ped or `x`-excluded.** The one pre-existing conditional `skip:` (on `ssh-keygen`
absence) is unchanged and **does not fire here** — `ssh-keygen -l -f /dev/null` exits 255 on this
host, the guard tests for 127, so the OpenSSH proofs ran.

### Test-database hygiene — confirmed on every run

All six runs ended with the target's own trap printing
`Container shipit_integration_<pid>-postgres_integration-1 Removed` and
`Network shipit_integration_<pid>_default Removed`, and **no `CLEANUP FAILED` line**. The database is
`tmpfs`, so there is no volume to leak. The throwaway baseline clone was removed.

**This lane issued ZERO mutating Docker/Compose commands.** The only Docker invocations were inside
`make test-integration`, which creates its own project `shipit_integration_<pid>` and self-cleans. No
`make clean`, no `qa-down`, no `test-env-down`, no `e2e-down`, no bare `down -v`, and no
`docker ps`/`volume ls`/`compose ps` — `AGENTS.md` withholds even the look-alike read-only commands on
shared state. `docker/**` was read as text only, and the QA stack on compose project `docker` was not
disturbed.

### No private half in any log, output, report or test failure

Structural now, not merely verified: the endpoint never calls `error.toString()`; every adapter
`reason` is a literal or `secretlessText(...)`, enforced by a test; `SshKeyPair` has no `String`
projection; and the two test files that previously asserted on PEM `String`s assert on booleans. This
report contains no key material, and neither does any test failure message.

---

## 10. Verification scope — what I did NOT verify, unchanged and re-stated

1. **The GCP Secret Manager adapter has still never been executed against a real project.** §A4
   remains open. Its HTTP paths are now covered against a real loopback server for the *failure* and
   *malformed* shapes; the success path against real GCP is still unproven, and `describe()` carries
   `runtimeVerified: false`.
2. **An authenticated SSH clone against a live host was still not reproduced.** No git host, no SSH
   server, no network authority. Everything around it is proved, including the timeout kill.
3. **`make test-integration` cannot be made green from this lane**, and on this machine it is not
   reliably green for anyone (§1, §9).
4. **The endpoint is still not callable from the Flutter client** — `packages/control_plane_client`
   is unowned and unregenerated (H-1). Deliberately not touched.
5. **`ScratchCleanupException` on the *success* path is not directly tested.** Inducing a failed
   `_destroy` needs a filesystem that refuses removal. The code is a single `if` shared with the
   failure path, which **is** tested; I am flagging the coverage gap rather than claiming it.

---

## 11. New durable discoveries (classified per `docs/engineering/LEARNING_POLICY.md`)

Reported, not persisted — `docs/engineering/**` is outside this lane's `OWNED_PATHS` (M-7).

**`PROJECT_FACT`** (Manager-persistable)
- The credential table already carried the full ADR 0018 contract and **no key-material column**;
  `apps/server/migrations/**` needed no change. Re-confirmed at `da68b5f`.

**`RUNTIME_DISCOVERY`** (Manager-persistable — every future lane will re-derive these)
- `make test-integration` is red at `BASE_SHA` at **`+171 -1`**, sole failure
  `dogfood_shipit_postgres_test.dart`, cause in `packages/product_registry`. **Do not trust any other
  baseline figure without re-measuring in a primary clone.**
- `dogfood_shipit_postgres_test.dart:87` asserts `Directory('${repoRoot}/.git').existsSync()`, which is
  false in **every linked worktree** — the failure mode differs by checkout kind, so a lane in a
  worktree and a reviewer in a clone see two different errors from one test.
- **A pool-lock cascade is load-dependent, not a property of any lane.** On a host at load 113–214 it
  turns one run into `+11 -21`; on an idle host the same commit gives `+189 -2`. Four `withServerpod`
  files aborting at `setUpAll` report **one** failure each and **none** of their tests, so a cascade
  *reduces* the passing count while inflating the failure count. Any gate figure reported from this
  suite is meaningless without the pool-lock occurrence count and the host load beside it.

**`WORKFLOW_IMPROVEMENT`** (independent review)
- **A source-level audit is cheap executable knowledge for a "no message may carry material" rule.**
  Two guard tests here (an allow-list of `SshKeyPair`'s public members; a ban on catch-clause
  bindings in a `SecretStoreException` reason) convert a review-time convention into a build failure.
  Both were negative-checked: they fail on the exact defects they exist to catch.
- **A `Future.timeout` on a subprocess is a waiting bug, not a termination bug**, and Dart offers no
  process group. `Process.start` plus a `ps`-walked tree kill is the portable answer; a test whose
  stub forks a **grandchild** is what proves the walk happened rather than the top process being
  signalled.

**`AUTOMATION_OPPORTUNITY`** (Manager → `server.dart` owner)
- One call in `run()` to `CredentialEndpoints.recordCustodyPrecondition(session)` moves the ADR 0018
  §A1/A4 selection from "first credential call" to process start. `apps/server/lib/server.dart` is not
  in any credential lane's `OWNED_PATHS`, so no credential lane can make this change.

**`CONTRADICTION`** (human decision — unchanged, still open)
- `9417f8bf` **G-7** vs `MintedCredential.referenceName`. The mitigation that made the incremental
  disclosure nil (both adapters return the bare name) is now **enforced** rather than assumed — but the
  decision between the raw reference and an opaque handle belongs to `design-agent`.
- **M-5 belongs on any ADR 0018 §A2 amendment**: this lane adds a transport enforcer for a
  *client-asserted, unauthenticated* trust decision. A2 is **narrowed, not discharged**.

---

## 12. Parallel work

### SAFE_PARALLEL_WORK

- **`packages/control_plane_client/**` regeneration.** Unchanged and still required before the client
  can call the endpoint (H-1). Disjoint from this tree; the fix for H-1. **No endpoint signature
  changed in this correction**, so regenerating will not conflict.
- **`apps/control_plane/lib/**` (client lane).** No file overlap. Contract facts it must plan around:
  `generate` returns `status: "generated"`, never `verified`; `verifyAccess` requires
  `hostKeyFingerprint` + `confirmedBy`, obtained out of band; `hostKeyStatus` is `unknown` at mint;
  **`verifyAccess`'s response now carries `hostKeyConfirmationProvenance`** — a client must not
  present it as "the server verified the host".
- **`packages/product_registry`** — the dogfood fix. The only path to a green
  `make test-integration`, and prohibited to this lane.
- **`docker/compose.test.yaml` `max_connections`, or the Makefile's concurrency** (M-2). Touches
  `docker/**`/Makefile; the only durable fix for the cascade.
- **`apps/server/lib/server.dart`** — the startup wiring (`recordCustodyPrecondition`).
- **`docs/engineering/learning/` persistence** of §11 (M-7), and documentation of ADR 0018 §A2/§A4 and
  `9417f8bf` G-7.
- **A revoke endpoint plus a rotation path** (L-4, L-3): needs `serverpod generate`, so it belongs to
  a lane that owns `packages/control_plane_client`.

### PROHIBITED_PARALLEL_WORK

- **`serverpod generate` from any worktree** until a lane owns `packages/control_plane_client`. It
  would race the client lane and rewrite `lib/src/generated/**`.
- **Editing `apps/server/lib/src/credentials/**` or `credential_endpoints.dart` from another lane**
  while `da68b5f` is under focused re-review. It is the security boundary; a reviewer's provenance
  for this commit would no longer describe the code.
- **Any write to `apps/server/migrations/**` or `apps/server/tool/**` on the strength of this lane.** No
  migration was needed and `verify_schema_bootstrap.sh` passes 21/21; a concurrent edit to those
  hand-maintained objects would make that pass meaningless.
- **Any Docker/Compose mutation** — including `make clean`, `test-env-down`, `e2e-down`, any bare
  `down -v`, and anything touching compose project `docker` (the live QA stack). Concurrent Docker
  work during `make test-integration` also collides on `shipit_integration_<pid>` and port 9199.
- **Relieving G-7 by editing `repository_credential_view.yaml` or the client's repository layer** as a
  side effect of this lane. That needs the decision first.
- **`git push`, merge to `main`, or rebasing this branch.** Four commits, unpushed:
  `428f4fa` → `4ac16a3` → `315e9ca` → `da68b5f`.

---

## 13. Result

```
RESULT: CORRECTION_COMPLETE

CORRECTED_FROM_HEAD: 315e9ca21ea6b33cfbaa9f0411db69951867e16e
NEW_HEAD:            da68b5f67d3766776b35d57d16956dd4b993ae7e

FINDINGS_ADDRESSED:
  B-1  FIXED, class closed at three levels (typed decode failures; a type-gated
       sink that never calls error.toString(); a source guard on adapter
       reasons). 6 adapter tests + 9 sink/gate tests + 1 integration test.
       Negative-checked against the reintroduced defect.
  B-2  FIXED. privateSeed is a SecretBytes; the String get privateKeyPem is gone
       at the root (PEM emitted as bytes); the class doc matches the code; an
       allow-list test pins the whole public surface. Negative-checked.
  M-1  FIXED (measurement). Base re-measured at +171 -1 in a primary clone.
       +108 -10 withdrawn and explained arithmetically.
  M-3  FIXED. Process.start + ps-walked tree kill; ssh-keyscan and ssh-keygen
       given the same treatment. Proved on the timeout path with a grandchild
       that only a tree walk can kill. Two negative checks.
  M-4  PARTIAL — cannot move the write from this lane (session log needs a
       Session; server.dart is outside OWNED_PATHS). Reason recorded, a named
       seam added and tested, the one-line call routed.
  M-5  FIXED as far as this lane may. Provenance published on the response,
       confirmedBy bounded, documented at three layers. Prior "closes a
       recorded gap" withdrawn.
  M-6  FIXED + ESCALATED. Handle contract enforced, mint fails closed, no row
       written; G-7's remaining decision named as its owner's.
  L-1  FIXED.  L-2 FIXED.  L-3 FIXED (documented bound).  L-7 FIXED (narrowed).
  L-8  FIXED (real assertion, not a wrapper-text proxy).
  M-2, M-7, L-4, L-5, L-6  NOT FIXED — each with a stated reason (§8).

FILES_CHANGED (15; git diff --numstat 315e9ca..da68b5f):
  M apps/server/lib/src/credentials/credential_key_service.dart              130+ 7-
  M apps/server/lib/src/credentials/gcp_secret_manager_secret_provider.dart   93+ 10-
  M apps/server/lib/src/credentials/local_file_secret_provider.dart           11+ 6-
  M apps/server/lib/src/credentials/posix_file_permissions.dart               60+ 12-
  M apps/server/lib/src/credentials/repository_access_verifier.dart          285+ 39-
  M apps/server/lib/src/credentials/secret_provider.dart                      35+ 4-
  A apps/server/lib/src/credentials/secretless_error.dart                    107+ 0-
  M apps/server/lib/src/credentials/ssh_keypair.dart                         141+ 50-
  M apps/server/lib/src/credentials/ssh_remote.dart                           12+ 3-
  M apps/server/lib/src/endpoints/credential_endpoints.dart                  156+ 40-
  M apps/server/test/credential_keypair_test.dart                            208+ 13-
  M apps/server/test/integration/credential_key_service_postgres_test.dart   338+ 2-
  M apps/server/test/repository_access_verifier_test.dart                    193+ 6-
  M apps/server/test/secret_provider_test.dart                               368+ 14-
  A apps/server/test/secretless_error_test.dart                               352+ 0-
  15 files changed, 2489 insertions(+), 206 deletions(-)
  Nothing outside OWNED_PATHS. migrations/**, lib/src/generated/**, packages/**,
  docker/**, pubspec.lock: all untouched.

GATES:
  format=pass  dart format --output=none --set-exit-if-changed .  -> Formatted 655
               files (0 changed), exit 0
  analyze=pass dart analyze apps/server  -> "No issues found!", exit 0.
               Nothing suppressed, ignored or @Skipped; the one lint ignore in
               the diff is prefer_initializing_formals on SshKeyPair's
               constructor, with the reason inline.
  tests=FAIL   make test-integration -> +189 -2, exit 2 (best of five runs).
               Both failures accounted for and neither mine: dogfood is red at
               BASE_SHA (+171 -1) in packages/**, prohibited here; D-4 is a
               pre-existing concurrency race in a file this correction does not
               touch, calling ProductRegistryEngine directly, load-sensitive
               (host load 113-214). Zero [E] lines for
               credential_key_service_postgres_test.dart, so all 19 of this
               lane's integration tests pass. The other four runs were
               cascade-polluted (111/289/130/118 pool-lock occurrences) and are
               reported, not hidden. No test weakened, skipped or excluded.
               Non-DB: dart test on four files -> +56: All tests passed!
               (37 -> 56.)
  build=pass   bash apps/server/tool/verify_schema_bootstrap.sh -> 21/21 OK,
               exit 0 (migrations/** untouched: the reference column already
               existed).
  runtime=n/a   No browser surface. Every runtime claim is backed by a real
               subprocess or a real loopback HTTP server and is stated with its
               scope. Not runtime-verified: the GCP adapter against real GCP
               (A4 open) and an authenticated SSH clone against a live host.

BLOCKERS: none on the deliverable. Two blockers and six further findings fixed;
five findings explicitly not fixed with reasons (§8). The gate is red for
pre-existing reasons this lane may not fix, and it is unreliable on this host
for reasons outside the repository (§1, §9).

NEW_DISCOVERIES: 2 PROJECT_FACT / RUNTIME_DISCOVERY, 2 WORKFLOW_IMPROVEMENT,
1 AUTOMATION_OPPORTUNITY, 1 CONTRADICTION — §11. Reported, not persisted
(docs/engineering/** is outside OWNED_PATHS; M-7).

READY_FOR_FOCUSED_REVIEW: YES
FOCUSED_RE_REVIEW
```

**This is a security boundary and I have not approved this work.** I cannot self-approve a correction,
and this report does not claim to.

The focused re-review should, at minimum:

1. confirm the B-1 closure is a class and not two lines — read
   `credentials/secretless_error.dart`, the three guard tests, and both `catch` blocks in
   `credential_endpoints.dart`;
2. run the four negative checks in this report (reintroduce the unguarded decoders; re-add
   `String get privateKeyPem`; reintroduce `reason: '$error'`; remove the kill) and confirm each fails;
3. confirm the B-2 doc now matches the code by reading `ssh_keypair.dart` top to bottom — that was the
   most dangerous artifact in the reviewed diff;
4. verify the M-3 proof reaches the **timeout** path, not success or ordinary failure, and that the
   grandchild is the part under test;
5. **re-run the base measurement in a primary clone at `8725b65`** if you want independent evidence
   for §1 — that figure is the thing my last report got wrong, and a wrong baseline makes every later
   comparison unreliable;
6. re-run `make test-integration` and **record the pool-lock occurrence count and the host load
   beside the result** — on this machine the same commit ranges from `+189 -2` to `+11 -21`, and a bare
   pass/fail figure is not information;
7. rule on the §11 `CONTRADICTION` (G-7, and the M-5 caveat on any ADR 0018 §A2 amendment), the
   `packages/**` ownership gap, and the `server.dart` startup wiring — all escalated by me and all
   outside my authority.