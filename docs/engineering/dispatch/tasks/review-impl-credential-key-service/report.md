# Independent Review — impl-credential-key-service

```
RESULT: DO_NOT_MERGE

REVIEWED_HEAD: 315e9ca21ea6b33cfbaa9f0411db69951867e16e

BLOCKERS:
  B-1  GCP adapter: two unguarded decode sites in SecretProvider.read() can put base64
       private-key material into an exception message, which the endpoint writes to the
       Serverpod session log, which is persisted to Postgres.
  B-2  The custody type discipline is not end-to-end. SshKeyPair exposes the seed as a
       public Uint8List and the private half as a public String, and a doc comment in the
       same file asserts the opposite of what the code does.

HIGH:
  H-1  packages/control_plane_client is not regenerated and no lane owns it. Real
       ownership gap; blocks the FEATURE (client cannot call the endpoint), not this merge.

MEDIUM:
  M-1  Claimed base redness figure (+108 -10) does not reproduce; measured +171 -1.
  M-2  Observed intermittent pool-lock exhaustion cascade that this lane's 20th
       integration file provably contributes to.
  M-3  RepositoryAccessVerifier does not kill the git/ssh child on cloneTimeout.
  M-4  Fallback selection is recorded on first credential call, not at startup (dispatch
       required startup).
  M-5  hostKeyFingerprint and confirmedBy are client-supplied and unauthenticated; the
       transport enforces exactly the value the client supplied.
  M-6  G-7: MintedCredential.referenceName is annotated "Not the material" — the exact
       reasoning 9417f8bf rejects.
  M-7  Durable discoveries classified but NOT persisted to docs/engineering/learning/.

LOW:
  L-1  verify() has a dead ternary and inconsistent ScratchCleanupException semantics.
  L-2  Identity file written before the host key is confirmed.
  L-3  GCP re-mint adds a version and leaves the previous one readable.
  L-4  No revoke/destroy path; supersedesCredentialId unreachable from the endpoint.
  L-5  Root pubspec.lock written outside declared OWNED_PATHS.
  L-6  serverpod_test_tools.dart regeneration also corrected an unrelated stale nullability.
  L-7  Production Endpoint carries public test-only seams.
  L-8  Test-only seams plus the hidden SSH host key are not covered by a negative test.

CORRECTION_REQUIRED: YES

HUMAN_DECISION_REQUIRED: NO

SAFE_PARALLEL_WORK:
  - apps/control_plane/lib/** (client lane) — no overlap with this diff.
  - packages/product_registry dogfood/read_only_repository_reader fix — the only path to a
    green gate; prohibited to this lane.
  - apps/server/lib/server.dart (wire resolveSecretProvider() into run()) — disjoint.
  - packages/control_plane_client/** regeneration — REQUIRED before the client can call the
    endpoint; disjoint, and the fix for H-1.
  - Documentation of ADR 0018 §A2/§A4 and 9417f8bf G-7.
```

---

## 1. Provenance — VERIFIED

| Check | Expected | Observed |
|---|---|---|
| Worktree | `/private/tmp/shipit-impl-keys` | same |
| Branch | `impl/credential-key-service` | same |
| `git rev-parse HEAD` | `315e9ca…` | `315e9ca21ea6b33cfbaa9f0411db69951867e16e` |
| Commits ahead of `8725b65` | 3 | 3 — `428f4fa`, `4ac16a3`, `315e9ca` |
| Working tree | clean | clean (`git status --porcelain` empty) |
| `main` touched / pushed / merged | no | no |

`git diff --name-status 8725b65..315e9ca` — 20 files, all inside declared `OWNED_PATHS` except one:

```
A  apps/server/lib/src/credentials/**            (10 new files)
A  apps/server/lib/src/endpoints/credential_endpoints.dart
M  apps/server/lib/src/generated/endpoints.dart
M  apps/server/lib/src/generated/protocol.yaml
M  apps/server/pubspec.yaml
A  apps/server/test/credential_keypair_test.dart
A  apps/server/test/secret_provider_test.dart
A  apps/server/test/repository_access_verifier_test.dart
A  apps/server/test/integration/credential_key_service_postgres_test.dart
M  apps/server/test/integration/test_tools/serverpod_test_tools.dart
M  pubspec.lock                                   <-- repo root, NOT in OWNED_PATHS
```

Prohibited paths, diffed explicitly — **empty**: `packages/**`, `apps/control_plane/**`, `docker/**`,
`.github/**`, `docs/adr/**`, `.decisions/**`, `docs/deployment/**`. The implementer's disclosure of the
undeclared root-`pubspec.lock` write is accurate (see L-5).

Governing clause re-read at `docs/adr/0018-per-product-git-credentials.md:226-232`. The implementer
quotes it correctly and builds to it.

---

## 2. Gates — re-run independently

All commands run by me, in `/private/tmp/shipit-impl-keys` at HEAD `315e9ca`.

| Gate | Command | Result | Report claim | Verdict |
|---|---|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | `Formatted 653 files (0 changed)`, exit 0 | same | MATCHES |
| analyze | `dart analyze apps/server` | `No issues found!`, **exit 0** | same | MATCHES |
| schema | `bash apps/server/tool/verify_schema_bootstrap.sh` | 21 checks, all OK, exit 0 | same | MATCHES |
| tests (non-DB) | `dart test test/credential_keypair_test.dart test/secret_provider_test.dart test/repository_access_verifier_test.dart` | `+37: All tests passed!` | "37 passing, 0 failing" | MATCHES |
| tests (DB) | `make test-integration` (run 1) | `+168 -3` | `+183 -1` | **does not match** — see §6 |
| tests (DB) | `make test-integration` (run 2) | `+183 -1`, sole failure `dogfood_shipit_postgres_test.dart` | `+183 -1` | MATCHES |
| tests (DB) baseline | `make test-integration` in a clean **primary** clone at `8725b65` | `+171 -1`, sole failure the same dogfood test | `+108 -10` | **figure does not reproduce** — see M-1 |

No `dart pub get` was needed; `.dart_tool/` was present at HEAD. `dart pub get` was run once in the
throwaway baseline clone (exit 0).

---

## 3. #1 THE CUSTODY RULE — claim PARTIALLY verified, and this is where the blocker is

The dispatch asks me to verify two claims. Verdict on each.

### 3.1 "`.bytes` audit finds exactly three private-material sites" — VERIFIED, but the audit is narrower than the claim

Exhaustive grep of `apps/server/lib/src/credentials/**` + `credential_endpoints.dart` for `.bytes`:

| Site | Justified? |
|---|---|
| `gcp_secret_manager_secret_provider.dart:130` — `base64.encode(secret.bytes)` into the request body | YES, load-bearing, carries a justifying comment (`:127-129`) |
| `local_file_secret_provider.dart:72` — `PosixFileModes.writeOwnerOnlyFile(path, secret.bytes)` | YES, load-bearing, comment `:67-71` |
| `repository_access_verifier.dart:273` — `writeOwnerOnlyFile(identityPath, privateKeyPem.bytes)` | YES, the single write of key material to disk in the subsystem, comment `:272` |
| `ssh_keypair.dart:72,98,100,101,138,212,235` | crypto codec; `:72/101/138/212` are the PUBLIC half, `:98/100/235` are the seed/private container |

Three sites, each justified — the report's table is accurate. **But `.bytes` is the wrong audit for
the property being claimed.** It cannot see a `String` projection, and it cannot see a third-party
exception carrying the payload. Both exist. That is B-2 and B-1.

### 3.2 "`SecretBytes` makes leaks compile-time impossible" — TRUE FOR THE TYPE, FALSE END-TO-END

`SecretBytes` itself is sound and I confirmed it empirically with my own program (outside the repo):

```
SECRET_TOSTRING=<secret redacted, 32 bytes>
SECRET_INTERP=x=<secret redacted, 32 bytes>
SECRET_EXC=Bad state: boom <secret redacted, 32 bytes>
```

No `toJson`, no `operator +`, no `List<int>` accessor, no `operator ==`. The only textual projection
is a length. That part of the claim holds.

**B-2 — the discipline does not cover the primary key type.** `ssh_keypair.dart`:

- `:107  final Uint8List privateSeed;` — a **public, unwrapped** mutable buffer. Any
  `log('$pair')`-adjacent mistake or a future `jsonEncode` of the pair leaks it; the `SecretBytes`
  wrapper offers no protection here at all.
- `:153  String get privateKeyPem => …` — the private half **as a `String`**, which interpolates into
  any message and is directly loggable.
- `:50` the class doc states: *"The type is deliberately NOT `toJson`-able and deliberately holds no
  `String` rendering of the secret."* Line 153 is exactly a `String` rendering of the secret. The
  comment asserts the negation of the code, inside the security file. That is the most dangerous
  artifact in this diff, because it is what tells the next reader the type is safe.

Neither member is *used* insecurely in this diff (`credential_key_service.dart:175` correctly goes
through `privateKeyPemBytes`), so there is no live leak here. The finding is that the load-bearing
guarantee is documented as structural and is not.

### 3.3 B-1 BLOCKER — a demonstrated path from the private half to Postgres

The report's §3 claims the four accidental-leak shapes are "compile-time impossible, not review-time
catches", and that "every `SecretStoreException`/`StateError` message names a reference, a mode or a
path". That is false in one place: a `dart:convert` exception in the **only method that handles key
material coming back from the secret manager**.

`gcp_secret_manager_secret_provider.dart:154-173`:

```dart
final decoded = jsonDecode(response) as Map<String, dynamic>;   // :161  (A)
…
return SecretBytes(base64.decode(data));                          // :172  (B)
```

Neither is guarded, and both throw `FormatException`, whose `toString()` **embeds an excerpt of the
offending input**. Reproduced with my own program (outside the repo, on the SDK in use here):

```
FORMAT_EXCEPTION_TOSTRING>>>
FormatException: Unterminated string (at character 122)
...load":{"data":"AAAAINNzaC1lZDI1NTE5AAAAIEXAMPLESECRETHALFBASE64MATERIALHERE
                                                                              ^
source_is_set=true
```

```
B64_FORMAT_EXCEPTION>>>
FormatException: Invalid character (at character 57)
AAAAINNzaC1lZDI1NTE5AAAAIEXAMPLESECRETHALFBASE64MATERIAL!!!
```

Site (A) fires on a truncated or corrupted 2xx body from Secret Manager — and the body of a
`versions/latest:access` response is exactly `{"name":…,"payload":{"data":"<base64 PEM>"}}`, so the
excerpt window lands inside the key. Site (B) fires on any base64 corruption in transit.

The sink is the one this review was told is the strictest reading, and it is real:
`credential_endpoints.dart:162-167` → `StructuredLogger._emit` (`apps/server/lib/src/services/structured_logger.dart:29-32`,
`_session.log(...)`) → Serverpod session log, and `apps/server/config/test.yaml` sets
`sessionLogs: persistentEnabled: true`. "Logged" and "persisted to the durable record" are the same
sink, exactly as the implementer says — which makes this path a violation of the standing A2
prohibition, not a nuisance.

Probability is low (it needs a malformed 2xx body) and the GCP adapter has never been executed against
a real project — ADR 0018 §A4 — so no test in this repo could ever have caught it. That is precisely
why independent review has to. I am holding the change for it because it is the exact prohibited act
on a security boundary, it invalidates the structural-immutability claim the lane asks reviewers to
rely on, and it is cheap to fix inside the lane's own owned file.

**Required correction (B-1).** In `GcpSecretManagerSecretProvider.read`, reduce both to typed,
secretless failures in the style already used at `:165-170`:

```dart
Map<String, dynamic> decoded;
try {
  decoded = jsonDecode(response) as Map<String, dynamic>;
} on Object {
  throw SecretStoreException(
    referenceName: referenceName, providerId: providerId, operation: 'read',
    reason: 'the access response was not the JSON this adapter expects',
  );
}
…
List<int> material;
try {
  material = base64.decode(data);
} on Object {
  throw SecretStoreException(
    referenceName: referenceName, providerId: providerId, operation: 'read',
    reason: 'the access response payload was not decodable',
  );
}
return SecretBytes(material);
```

Add a regression test that feeds `read()` a truncated access body and a bad-base64 body and asserts
`e.toString()` carries neither the payload nor the base64 prefix. Suggested trigger (no GCP needed):
a `Uri` served by a local `HttpServer` returning `200` with
`{"payload":{"data":"AAAAB3NzaC1lZDI1NTE5…` cut mid-string.

**Required correction (B-2).** In `ssh_keypair.dart`: make `privateSeed` private, delete or
`@Deprecated`-annotate the `String privateKeyPem` projection so the only production route to the
private bytes is `privateKeyPemBytes`, and fix the `:50` comment so it describes what the code does.
If the `String` getter must stay for tests, say so and mark it test-only.

---

## 4. #2 KEY GEN IS REAL — VERIFIED independently of the lane's own tests

I generated a keypair with my own program outside the repository and handed it to the real OpenSSH
tools on this host:

```
AUTHLINE_FIELD1=ssh-ed25519
AUTHLINE_FIELD2_LEN=68                      (4+11 length prefix + 4+32 blob = 51 bytes; the old
                                             mock's 32 random bytes is NOT reproduced)
ssh-keygen -lf id.pub  -> exit 0
  256 SHA256:6g0Pgo3l7rR5I7iq22Wb5DpEWa/veTOPsW/JsMxOH3o shipit+independent-review (ED25519)
pair.fingerprint        -> SHA256:6g0Pgo3l7rR5I7iq22Wb5DpEWa/veTOPsW/JsMxOH3o     <-- exact match
ssh-keygen -y  id       -> exit 0
  ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBkkFOqrQp4CFFnSeJoBFS0pUzM9KD3YrhUkf6GCRunT shipit+…
our authorized line      -> identical
ssh-keygen -lf id       -> same SHA256 fingerprint
CONTAINER cipher=none kdf=none kdfopts_len=0 nkeys=1
```

Confirmed: a genuine ed25519 keypair; the public half is a valid SSH public key that OpenSSH parses
as `(ED25519)`; **the fingerprint is computed over the real wire blob** and agrees with OpenSSH's own
`sha256` over `string("ssh-ed25519") || string(pub)`; the private container is loadable and its
public half *is* our public half; the `none`/`none` cipher claim in the report is exactly true (I
decoded a container). Entropy is `ed25519_edwards`' secure RNG, not `Random()`.

The old `add_product_page.dart:126-138` mock (`ssh-ed25519 <base64 of 32 random bytes>`) is not
reproduced anywhere in this diff.

---

## 5. #3, #4, #5, #6 — endpoint contract, persistence, provider, access verification

### #3 Endpoint contract — VERIFIED, and the serialized type is safe

`MintedCredential.toJson()` (`credential_key_service.dart:60-71`) is an explicit whitelist:
`credentialId, productId, repositoryId, publicKey, fingerprint, algorithm, referenceName, status,
hostKeyStatus, host?`. `AccessVerification.toJson()` (`:103-113`) is likewise. The endpoint returns
exactly those maps (`credential_endpoints.dart:104`, `:160`); Serverpod serializes
`Map<String,dynamic>` as the map itself, so the wire shape is the whitelist.

The claim "the response type is the whitelist" holds because `MintedCredential` has **no** private
field and no accessor that derives one — unlike `SshKeyPair` (B-2). Verified at the source of truth,
not just the handler.

`status` is `generated` at mint, never `verified`; `hostKeyStatus` is `unknown`. `hostKeyFingerprint`
and `confirmedBy` are `required` with no optional form — confirmed in the generated
`endpoints.dart` ParameterDescription (`'hostKeyFingerprint': nullable: false`) and in
`protocol.yaml`.

### #4 Persistence — VERIFIED against the spy file AND the live DDL

- `apps/server/lib/src/database/repository_credential.spy.yaml` is **not in the diff** — unmodified.
  It declares `referenceName`, `fingerprint`, `algorithm`, `status`, `lastVerifiedAt`,
  `lastVerifiedBy`, `lastFailureReason`, `hostKey*`, `revoked*`, `supersedesCredentialId` — and **no
  key-material column**.
- `git diff --stat 8725b65..315e9ca -- apps/server/migrations/` is **empty**.
- I did not take the report's word for it: `migrations/20261006150645000/definition.sql:619-642` is
  the live DDL. 21 columns, `referenceName text NOT NULL`, nothing else holding key bytes.
- `verify_schema_bootstrap.sh` 21/21 OK. The implementer's "no migration was needed, and that is a
  finding" is correct and well argued.

### #5 Secret provider — fail-closed VERIFIED, but not logged at startup (M-4)

`resolveSecretProvider()` has no default branch: unset, blank and unrecognised all throw
`SecretProviderNotConfiguredException` naming the variable and both accepted ids
(`secret_provider_resolver.dart:74-99`). No `?? local_file` exists anywhere. The GCP path
additionally refuses without `SHIPIT_GCP_PROJECT_ID` (`:312-319`).

**The test genuinely proves fail-closed rather than merely that a flag exists.** `secret_provider_test.dart`
`:36-106` asserts the throw for unset/blank/unknown *and* asserts no filesystem side effect
(`:80-90`), and the integration suite re-proves it end-to-end through the real endpoint
(`credential_key_service_postgres_test.dart:441-459`: unconfigured `generate` throws **and writes no
row**). That is the right test. The GCP log-fields test puts `ya29.super-secret` in the environment
and asserts it appears in neither the fields nor `describe()` — a real test, not a token-shaped
placeholder.

Recorded-ness is implemented properly: the fallback logs under its own event
`credential.secret_provider.fallback_selected`, at `warning`, with
`isDocumentedFallback=true` and `selection: explicit (SHIPIT_SECRET_PROVIDER=local_file)`, and a
defaulted *directory* is recorded separately from a configured one. The separation of "which
substrate" (must be explicit) from "where it points" (may default) is the right reading of A1/A4.

**M-4 (not a blocker).** The dispatch said the selection "must be **logged at startup**". It is not:
`_provider()` (`credential_endpoints.dart:61-65`) is a **lazy** field, so the precondition is recorded
on the *first credential call*, and only if one ever happens. Two consequences an operator should
know: (a) a deployment that never mints a credential records nothing, so "QA is running on the
fallback" cannot be established from the log at all in that state; (b) the `AUTOMATION_OPPORTUNITY`
in report §10 is the correct fix and is one line in `apps/server/lib/server.dart`, which is outside
this lane. The ADR clause itself ("a recorded precondition, not a silent default") is satisfied — the
selection cannot be silent and nothing is defaulted. Record it in `WORK_STATE.md` so it is not lost;
it is a routing item, not a merge condition.

### #6 Access verification — cleanup proof is SOUND; three real gaps

**The PATH-pinned-`git`-stub failure-path proof is sound, and I accept it.** Reason: cleanup is
performed by `RepositoryAccessVerifier._destroy` (`repository_access_verifier.dart:333-344`) on both
paths — `:239` on success, `:249` in the `on Object` handler — and that code runs *independently of
what `git` did*. Stubbing the leaf subprocess therefore cannot fake the cleanup result; it can only
fake the clone's exit status, which is not the property under test. The test also refuses to be fooled
about *which* path it is on: `repository_access_verifier_test.dart:276` asserts
`identity_exists == 'yes'`, so it has genuinely reached the post-write failure path rather than an
early refusal. `:278-284` then asserts no `shipit_credential_verify_*` directory survives anywhere
under system temp. The success path is proved symmetrically and additionally reads the identity
**from inside the stubbed `git`** — mode `600`, `ssh-keygen -y` loadable, and byte-identical to our
public half (`:196-214`). Owner-only permissions are *set and then verified* by
`PosixFileModes.applyStrict`, not trusted (`:266`, `:303`), and `writeOwnerOnlyFile` chmods a sibling
temp file **before** content reaches it and renames (`:99-110`) — the key never exists at any other
mode. I re-ran all three files: `+37: All tests passed!`.

The host-key enforcement is real: real `ssh-keyscan` (not stubbed `ssh-keygen`), fingerprint compared
against the confirmed value, refusal before `git` is invoked at all (`:280-287`), and a one-line
`known_hosts` holding **only** the matched key plus `StrictHostKeyChecking=yes` /
`GlobalKnownHostsFile=/dev/null` so OpenSSH independently enforces it. That is a genuine improvement
on ADR 0018 §A2's "decorative at the transport".

Gaps:

**M-3 — the timeout path does not kill the child.** `_runGitClone` is
`Process.run(...).timeout(cloneTimeout)` (`:500`). `Future.timeout` stops *waiting*; it does not
terminate the process. On a 3-minute timeout, `verify()`'s `on Object` handler unlinks the scratch
tree (so the file does not survive on disk) but a live `git`/`ssh` survives holding an open fd to the
identity and still able to authenticate with it. The dispatch asks for the private half not to
"survive the call"; on this path it does. No test covers it. Fix: use `Process.start`, hold the
`Process`, and on `TimeoutException` `kill(ProcessSignals.sigkill)` (ideally the process group) before
rethrowing — then add a test with a stub `git` that sleeps longer than `cloneTimeout` and assert no
such process remains.

**M-5 — the pinned fingerprint is exactly the client-supplied value.** `hostKeyFingerprint` arrives as
an endpoint parameter (`credential_endpoints.dart:136`, `nullable: false`) and is passed **unchanged**
to both `engine.confirmHostKey` and `verifier.verify(confirmedHostKeyFingerprint: …)`
(`credential_key_service.dart:253-270`). So the transport enforces whatever the client asserted. If a
caller obtains that value by scanning the network itself and supplies it, the first confirmation
records and enforces an attacker-chosen key, and the clone proceeds against the attacker. I checked
the mitigation: `confirmHostKey` (`product_registry_engine.dart:1014-1027`) does refuse a *changed*
fingerprint once one exists, so only the first confirmation is exposed — but the first confirmation
is exactly the one this change is meant to make trustworthy. `confirmedBy` is worse for audit: it is a
free-text string validated only by `isEmpty` (`:1008`), so `hostConfirmedBy` / `lastVerifiedBy` in the
durable record record whatever the caller typed.

This does not block: it is inherent to client-driven TOFU, and the domain guard does bound it. But the
report's §6 headline "**This closes a recorded gap**" overstates it. The honest statement is that this
lane adds a **transport enforcer** for a **client-asserted** trust decision — the gap ADR 0018 §A2
records ("the human confirmation was recorded as data … the connection itself was unverified") is
narrowed, not closed, because the provenance of the confirmed value is unchanged. That belongs in the
§10 `ARCHITECTURE_DISCOVERY` escalation as a caveat on any ADR amendment that claims A2 is discharged.

**L-2** `_probe` writes the identity file (`:273`) *before* `ssh-keyscan` (`:275`). Reordering the scan
before the write removes a pointless window in which key material sits on disk for a call that will
refuse anyway. Bounded (0700 dir, removed in the same call), so LOW.

---

## 6. #7 THE RED GATE — pre-existing redness REAL; the reported figures are not both reproducible

This was the most important item, so I reproduced the baseline myself rather than trusting it.

**Setup.** `git clone /Users/alkebut/air/shipit-platform <tmp>/base-clone && git checkout 8725b65`
→ `HEAD = 8725b65deaab565f7c3b93d644e73f1ec07a6f39`, working tree clean, and `.git` is a **directory**
(`file .git` → `directory`), which matters: it is what lets the dogfood test get past its own first
assertion. `dart pub get` exit 0. Then `SERVERPOD_DATABASE_PASSWORD=shipit make test-integration`.

**Result at BASE_SHA, independently measured: `+171 -1`, one failing test.**

```
Failing tests:
  test/integration/dogfood_shipit_postgres_test.dart: S-1 DOGFOOD — Product: ShipIt (Postgres, read-only)
    register ShipIt, discover pinned HEAD read-only, propose baseline, survive restart
```

with `TimeoutException after 0:00:30 … Test timed out after 30 seconds` and
`PathNotFoundException: Directory listing failed, path = …/docs/engineering/dispatch/tasks/design-approve-mobile-rev6/`
— i.e. `packages/product_registry`'s `ReadOnlyRepositoryReader._walk` failing mid-walk of a
`git archive` snapshot. **This is in `packages/**`, prohibited to this lane.** Zero pool-lock
occurrences at base.

**So the substantive claim is CONFIRMED: `make test-integration` is red at `BASE_SHA`, before this lane
exists, for a reason outside this lane's ownership.** The lane did not introduce the redness, and the
remaining defect is not fixable from here. That is the thing the dispatch most needed verified, and it
holds.

**M-1 — but the number is wrong, and it matters.** The report says base is `+108 -10` (ten failures).
I measure `+171 -1`. There is no reading of this run that yields ten failures: at base there is one,
and it is the same dogfood test. I do not think the lane introduced anything — both of us are looking
at the same defect — but the base evidence in the report is not reproducible, and it is the evidence a
reader would use to decide the gate is hopeless. Report the measured figures instead.

Also worth recording precisely, because it explains the discrepancy and is genuinely useful:
`dogfood_shipit_postgres_test.dart:87` asserts `Directory('${repoRoot}/.git').existsSync()`. In a
**linked worktree** `.git` is a `gitdir:` pointer *file*, so in the impl worktree the test fails at
`:87` ("dogfood expects a git working tree at /private/tmp/shipit-impl-keys"); in a **primary clone** it
fails later, on the `packages/product_registry` walk. Same test, two distinct causes, neither in this
lane. The implementer wrote a one-line repair for the first and **reverted** it — correct call.

**M-2 — I hit the pool-lock cascade, once.** My **first** HEAD run gave `+168 -3` with **92**
`TimeoutException: Failed to acquire pool lock` occurrences and two extra failures in files unrelated
to credentials (`design_governance_postgres_test.dart` setUpAll, `governance_endpoints_e2e_test.dart`
setUpAll). My **second** HEAD run gave `+183 -1` with **zero** pool-lock occurrences. Base had zero.
The test files went 19 → 20 and `withServerpod` files 17 → 18, and the new file opens 2-3 pooled
sessions per test against one disposable `postgres:16` under `dart test`'s default `--concurrency 4`.
So: the lane's own test file can, and on this machine did, push the shared disposable Postgres past its
connection budget and take two unrelated files' `setUpAll` down with it. The implementer hit exactly
this (231 occurrences on their first run) and fixed their own leak, which was the right fix — but the
residual hazard of *adding a 20th pooled file* is real and is not fixed. Report §13's
`tests=fail … All 12 tests this lane adds pass` is true; "the single failure is pre-existing" is true
only for runs that do not hit the cascade.

Action: make the run deterministic rather than lucky. Cheapest options, in order —
`dart test --concurrency=3 test/integration/`, or raise `max_connections` on
`docker/compose.test.yaml:postgres_integration`, or give the credential suite its own database.
All three touch `docker/**` or the Makefile, so they are routing items, not corrections to this lane.
What this lane *should* do is record the hazard so the next one inherits it.

**Test-database hygiene — VERIFIED on every run I made.** All three runs ended with the target's own
trap printing `Container …-postgres_integration-1 Removed` and `Network shipit_integration_<pid>_default
Removed`, and no `CLEANUP FAILED` line. The database is `tmpfs`, so there is no volume to leak.
**I issued zero mutating Docker/Compose commands**: only `make test-integration`, which creates its
own project `shipit_integration_<pid>` and self-cleans. No `make clean`, no `qa-down`, no
`test-env-down`, no `e2e-down`, no bare `down -v`, and no `docker ps`/`docker volume ls` (AGENTS.md
withholds even the look-alike read-only commands on shared state). I read `docker/compose.test.yaml`
and `docker/compose.qa.yaml` as text only. The QA stack on compose project `docker` was not disturbed.

---

## 7. #8 NO WEAKENED TESTS — VERIFIED

| Check | Result |
|---|---|
| Test files deleted vs base | **none** (`comm -23` of the two trees is empty) |
| Lines removed from any `apps/server/test/**` file across the whole diff | **exactly one**, see L-6 |
| `@Ignore` / `@Skip` / `x`-exclude / `--exclude` / `@OnPlatform` introduced | **none** |
| The only `skip:` in `apps/server/test/**` at HEAD | `credential_keypair_test.dart:247`, conditional on `ssh-keygen` being absent |
| Is that skip active here? | **No.** `ssh-keygen -l -f /dev/null` exits **255** on this host; the guard is `exitCode != 127`, so `_hasSshKeygen == true` and the OpenSSH proof **runs**. I confirmed the keygen tests execute by reproducing the same `ssh-keygen` calls myself. |
| `dogfood_shipit_postgres_test.dart` modified? | **not in the diff** — the one-line repair was correctly reverted |
| Assertions deleted or loosened in the new tests? | none; the tests are net-new |

**Do the lane's own tests genuinely assert custody, or merely pass?** Genuinely, and in the right
shape:

- `credential_key_service_postgres_test.dart:340-364` reads the row back with `SELECT *` and scans
  **every column** of the raw row against four predicates: `'PRIVATE KEY'`, `'BEGIN OPENSSH'`, the
  whole PEM, and `base64(pem)`. A hand-written column list would only prove the columns it happened to
  name; the defect this lane exists to prevent is a private half in *a* column. This is the right test.
- `:378-412` takes the **real endpoint's return value**, `jsonEncode`s it, scans the joined string and
  then scans **per value** (because a substring test over the joined map can miss a value straddling a
  JSON escape), and asserts the public half and `referenceName` **are** present — so it is not passing
  by returning nothing.
- `:201-218` `_publicHalfOfStoredMaterial` hands the *stored* bytes to real `ssh-keygen -y` and asserts
  the recovered public half equals the advertised one. That proves the manager returned a complete,
  loadable key — parsing the container in the test would only prove the test agrees with itself.
- `:414-439` a refusing provider ⇒ the mint throws **and no row exists**, which is the non-installable-
  key failure. `:441-459` unconfigured ⇒ throws **and no row exists**.

What is **not** covered, and should be: the two `FormatException` sites (B-1), the timeout/kill path
(M-3), the negative local-fallback case (a host serving a *different* key whose fingerprint equals the
confirmed one is unreachable by construction, so at minimum the second-key refusal — "only the confirmed
key goes into `known_hosts`" — needs a real assertion rather than a wrapper-text proxy), and the
private-folder/identity-file mode on the transport path (M-1's sibling, L-8).

---

## 8. #9 G-7 — real, correctly escalated, does NOT block

`9417f8bf` (`:220-223`, `:228-230`) is unambiguous: under A3 "the reference IS the sensitive
artifact", `RepositoryCredentialView` exposing `referenceName` is **gap G-7**, and removing it or
replacing it with a non-identifying handle is **REQUIRED rather than OPTIONAL**, owner
`design-agent`. The implementer's reading is accurate and they did not quietly widen it.

**Severity: MEDIUM, and it does not block.** My own assessment of the *incremental* exposure:

- It is a **second reader of an already-exposed value**, not a new exposure. Confirmed:
  `repository_credential_view.dart:145`/`:166` already emit it, and
  `apps/control_plane/lib/data/control_plane_repository.dart:108` already surfaces it to the UI.
- In *this* implementation the returned value is not an ARN or a vault path. It is
  `credentialReferenceName(repositoryId)` = `GIT_REPOSITORY_<sanitised repositoryId>_SSH`
  (`secret_provider.dart:182-187`), i.e. a **pure function of an input the caller just supplied**, and
  both adapters' `store()` return the bare name rather than a versioned resource path
  (`local_file_secret_provider.dart:73`, `gcp_secret_manager_secret_provider.dart:150`), so the
  `SHIPIT_GCP_SECRET_PREFIX` does not leak either. On these two adapters the incremental disclosure is
  **nil**.
- That mitigation is **implementation-dependent, not structural**. The moment a provider returns a
  real ARN from `store()`, this endpoint leaks vault topology with nothing to stop it —
  `MintedCredential.referenceName` is a bare `String` with no validation and no test that would fail.

**M-6 is the actionable part, and it is a documentation defect at a security boundary.**
`credential_key_service.dart:46-48` annotates the field: *"The name under which the private half is
held by the secret manager. Not the material; §13a by name, never by value."* §13a is what makes
*credentials* safe to reference; it is precisely **not** an assurance that the reference is harmless —
that is the reasoning `9417f8bf` rejects when it elevates G-7 to required. A future reader who trusts
that comment will add a provider returning a path. Replace it with a comment that states the residual
risk in the decision's own terms, and note that the returned value must remain non-identifying.

Routing: the contradiction is real and must be recorded as an open item in `WORK_STATE.md` (Manager
owned) so it is not lost between lanes. Choosing an opaque handle vs the raw reference is a
product/architecture call and is correctly **not** this lane's to make. It does not gate this change.

---

## 9. #10 WORKFLOW DEFECT — REAL, and it should be routed as HIGH, but it does not block this merge

**Verified, not taken on report.** `apps/server/config/generator.yaml:3` is
`client_package_path: ../../packages/control_plane_client` and `server_test_tools_path:
test/integration/test_tools`. So *every* `serverpod generate` in this repository writes into
`packages/**`, which this dispatch marks `PROHIBITED`. And I confirmed the client is stale:
`rg -c credentialEndpoints packages/control_plane_client/lib/src/protocol/client.dart` → **no match**.

The lane's handling was correct in the only way available to it: it regenerated the two server-side
artifacts it owns (`lib/src/generated/**`, `test_tools/serverpod_test_tools.dart`), copied **nothing**
out of `packages/**`, left the client stale deliberately, and flagged it in the commit message and in
report §10 as a `WORKFLOW_IMPROVEMENT`. Writing into `packages/**` to "fix" it would have been the
worse outcome.

**Why it is still HIGH and must be routed:** `AGENTS.md` §Product-specific policy records
"Path ownership map: **TBD**". There is therefore **no lane that may regenerate the client**, which
means *no server lane in this workflow can add an endpoint and leave the repository
generator-consistent*. That is a structural gap, not a one-lane oversight, and it will recur on the
next endpoint. Two candidate resolutions, both human/Manager calls: grant server lanes
`packages/control_plane_client/lib/src/protocol/client.dart`, or nominate a regenerating lane as
mandatory co-owner of every endpoint addition.

It does **not** block merging this server branch: the server half is self-consistent, the test-tools
wrapper for the new endpoint is regenerated, and a server-to-server / test-tools caller works today.
It **does** block the feature — the Flutter client cannot call `credentialEndpoints` until the client
is regenerated, which is the next step of the Add Product Register work. `SAFE_PARALLEL_WORK` for it
is disjoint from this diff.

---

## 10. Learning completeness — classified correctly, NOT persisted (M-7)

Report §10 classifies every discovery into exactly one `LEARNING_POLICY.md` category and routes
authority levels correctly:

- `PROJECT_FACT`, `RUNTIME_DISCOVERY` → automatic. **Correctly classified, not persisted.**
- `WORKFLOW_IMPROVEMENT`, `AUTOMATION_OPPORTUNITY` → independent review. **Correctly not persisted**;
  this review endorses the routing.
- `CONTRADICTION` (G-7) → escalate. **Correct** — the policy says a contradiction "must be surfaced and
  reconciled; never silently overwrite".
- `ARCHITECTURE_DISCOVERY` → human decision / ADR amendment. **Correct**, and I add the M-5 caveat to it.

**M-7.** Nothing under `docs/engineering/learning/` (or `WORK_STATE.md`) was touched by this diff. The
policy's first guiding principle is "Persist verified discoveries that future agents would otherwise
rediscover" — and the two automatic-category discoveries here are exactly that. Every future lane
running `make test-integration` in a linked worktree will re-derive the `.git`-is-a-file trap and the
`read_only_repository_reader` failure, and will re-derive the pool-lock contention hazard (M-2). This
is a Manager-owned persistence step, not a correction to the lane: append the base-redness fact, the
worktree-`.git` trap, and the pool-lock hazard to `docs/engineering/learning/`, and record G-7, the
`packages/**` ownership gap, and the `server.dart` wiring as open items.

---

## 11. Remaining findings

**L-1** `verify()` `:240-243`: `failureReason: removed ? outcome.failureReason : outcome.failureReason`
— a dead ternary, both arms identical; and `ScratchCleanupException`'s own doc says a leftover private
half "is an exception rather than a log line", yet on the **success** path a failed `_destroy` returns
`secretMaterialRemoved: false` instead of throwing (the failure path at `:249` does throw). Behaviour is
acceptable — `CredentialKeyService.verifyAccess:276` refuses to record `verified` while the flag is
false — but the inconsistency should be resolved one way, and the dead ternary removed.

**L-3** GCP `store` tolerates 409 and calls `addVersion`, so a re-mint leaves the **previous** private
half readable at an older version. `destroy` (Secret Manager secret destruction) removes all versions,
so two-sided revocation is sound; only the rotation-without-destroy window lingers. Worth one sentence
in the adapter's doc as an accepted bound, and worth a `destroy`-before-re-mint when the rotate path lands.

**L-4** No credential revoke endpoint exists, so `SecretProvider.destroy` is reachable only from
`_destroyOrphan` on a failed mint; and `supersedesCredentialId` is accepted by
`CredentialKeyService.generate` but **not** by the endpoint, so lineage/rotation is unreachable. ADR 0018
§A2's two-sided revocation is therefore specified-but-not-enforceable here — consistent with the caveat
the ADR already accepts. Out of scope for this dispatch; must not be forgotten.

**L-5** `pubspec.lock` at the **repo root** was written; `OWNED_PATHS` listed `apps/server/pubspec.lock`,
which does not exist because `resolution: workspace` puts the lockfile at the root. The diff is +16/-0,
additive only (`adaptive_number`, `ed25519_edwards`), and `crypto` was already in the graph — so
"promoting it to direct adds no package" is verified by the diff. Unavoidable, self-disclosed, benign;
the dispatch's `OWNED_PATHS` should say so next time.

**L-6** The regeneration of `serverpod_test_tools.dart` also changed one unrelated line:
`createProduct`'s `manifestJson` from `required String` to `String?`. I checked the server source:
`product_registry_endpoints.dart:444-450` already declares `String? manifestJson`, so the generated
file was **stale at base** and this corrects it. Not a weakening — it makes a previously impossible
call legal — but it is unrelated drift bundled into this diff and should be called out in the commit
message so the next reviewer of `product_registry` is not surprised.

**L-7** `CredentialEndpoints` exposes `environmentOverride` and `resetCustodyForTesting` as **public**
instance fields on a production `Endpoint`. Documented, instance-scoped (blast radius = one object), and
unavoidable given Dart cannot mutate `Platform.environment` — but they are reachable from any code
holding the endpoint, and there is no guard. Acceptable; flag for the owner of `server.dart` when the
startup wiring lands.

---

## 12. What I judge to be genuinely strong

Worth stating plainly, because the verdict is DO_NOT_MERGE on two narrow findings and this is
otherwise careful work on a boundary that is easy to get wrong:

- The `none`-cipher `openssh-key-v1` container is hand-written **and** then proven against OpenSSH's
  own loader rather than against itself. I verified that independently.
- `PosixFileModes` set-then-**verify**, with the sibling-temp-then-rename pattern so the key never
  exists at `0644` even briefly, and a hard failure (not degradation) where POSIX modes are
  unavailable. This is the fix for a failure that would have been completely invisible.
- The redirect of `HOME` / `GIT_CONFIG_GLOBAL` / `GIT_CONFIG_SYSTEM`, plus `BatchMode`, `IdentitiesOnly`,
  `IdentityAgent=none`, `GIT_TERMINAL_PROMPT=0` and configurable `gitExecutable` / `pathPrefix` — the
  `_pinnedPath` comment explaining why the PATH *list* separator, not `Platform.pathSeparator`, is the
  correct character is exactly the right level of care for a control that fails silently.
- Custody **before** the row (`credential_key_service.dart:179-196`) plus `_destroyOrphan` on the
  unwind: no window in which an operator holds a public key whose private half exists nowhere.
- Ordering the two host-key exceptions differently (`HostKeyNotPresentedException` for the transport vs
  the domain's `HostKeyNotConfirmedException`) is a small thing that is precisely right, because the
  gap A2 records *is* the gap between them.
- The report's honesty about what was **not** reproduced (no authenticated clone; GCP never executed)
  is what made this review tractable, and both claims are accurate.

---

## 13. Verdict

`DO_NOT_MERGE`, on two findings that are both confined to files this lane already owns.

The dispatch's central test — *"the review must be able to confirm the private half never reaches a
response, a log, or the database"* — I can confirm for the response and for the database, and I **cannot
confirm it for the log**: B-1 is a path by which base64 private-key material reaches
`error.toString()` → the Serverpod session log → Postgres, demonstrated with a reproducible PoC rather
than argued. B-2 is the reason the lane's own structural guarantee does not hold, and the doc comment
asserting the negation of the code is what makes it dangerous.

Neither blocker is an architecture, product, security-policy or infrastructure decision. Both are
small, concrete corrections inside `apps/server/lib/src/credentials/**`, with regression tests. G-7, the
ADR amendment question, the `packages/**` ownership gap and the `server.dart` startup wiring are all
genuine human/Manager routing items — all already escalated by the implementer, none of which should
hold this change.

**After B-1 and B-2 are corrected and the gates re-run, this is approvable.** A focused re-review
should verify: both new typed failures in `GcpSecretManagerSecretProvider.read`, the regression test
proving `e.toString()` carries no payload, `SshKeyPair`'s members and the corrected `:50` comment, and a
clean `dart analyze apps/server` + `make test-integration` at the new HEAD. It should not re-litigate
§4-§9.
