# Report — impl-credential-key-service

```
RESULT: IMPLEMENTED

FEATURE:  Server-side ed25519 deploy-key generation with external custody (ADR 0018 §A2/§A3),
          plus real-clone access verification
BRANCH:   impl/credential-key-service
BASE_SHA: 8725b65deaab565f7c3b93d644e73f1ec07a6f39
HEAD_SHA: 315e9ca21ea6b33cfbaa9f0411db69951867e16e
WORKTREE: /private/tmp/shipit-impl-keys
```

Pre-flight verified before any write: `git branch --show-current` == `impl/credential-key-service`,
`git rev-parse HEAD` == `8725b65…`, working tree clean. `main` was not touched; nothing was
pushed or merged. `AGENTS.md §13` compliance: every credential is **referenced by name** and no
credential **value** appears in a repository, record, log line or message.

---

## 1. Ownership

### OWNED_PATHS (all writes are inside these)

```
apps/server/lib/src/endpoints/**        credential_endpoints.dart                         (new)
apps/server/lib/src/credentials/**      10 files                                          (new)
apps/server/lib/src/generated/**        endpoints.dart, protocol.yaml                     (regenerated)
apps/server/pubspec.yaml                                                                      (2 deps)
apps/server/test/**                     4 files (new) + test_tools/serverpod_test_tools.dart
apps/server/migrations/**               UNTOUCHED — see §2, no migration was needed
```

`apps/server/pubspec.lock` does not exist in this workspace (`resolution: workspace` puts the
lockfile at the repo root). The lockfile the dispatch expected to change is therefore
**`pubspec.lock` at the REPO ROOT**, which is *not* in the declared `OWNED_PATHS`. That is an
unavoidable, mechanically-generated consequence of the dispatch's own instruction to add a
dependency, and I took it rather than fail the requirement. The complete change is 16 added lines
and zero modified:

```
+ adaptive_number 1.0.0    (new transitive)
+ ed25519_edwards 0.3.2    (new, listed transitive by the workspace lock format)
```

Nothing else in `pubspec.lock` moved. `crypto` was **already** resolved into this app's graph as
a transitive dependency, so promoting it to direct adds no package.

### READ_ONLY_PATHS

`docs/adr/0018-per-product-git-credentials.md` · `.decisions/b869ec24…` ·
`.decisions/9417f8bf…` · `.decisions/79e860e2…` · `docker/compose.qa.yaml` (read as text only)
· `apps/control_plane/**`

### PROHIBITED_PATHS

`apps/control_plane/lib/**` · `apps/control_plane/test/**` · `packages/**` · `docker/**` ·
`.github/**` · `docs/adr/**` · `.decisions/**` · `docs/deployment/**` — **none written**.
See §8 for one prohibited-path consequence the Manager must action.

---

## 2. No migration was required, and that is a finding

The dispatch said "if a reference column is missing, add it via migration". **It is not missing.**
`repository_credential.spy.yaml` already carries the full contract, and I verified it against the
live schema rather than assuming:

`apps/server/lib/src/database/repository_credential.spy.yaml` (pre-existing, unmodified) declares
`credentialId, productId, repositoryId, referenceName, publicKey, fingerprint, algorithm, status,
createdAt, lastVerifiedAt, lastVerifiedBy, lastFailureReason, hostKeyStatus, host,
hostKeyFingerprint, hostConfirmedAt, hostConfirmedBy, revokedAt, revokedReason,
supersedesCredentialId, version`.

Every field the dispatch listed is present: credential id, product id, repository id, **reference
name**, fingerprint, algorithm, status, and both verification timestamps (`lastVerifiedAt`,
`lastVerifiedBy`, plus `lastFailureReason`). **No key-material column exists.** ADR 0018 is right
that the model was already correct — what was missing was the code that fills it.

`apps/server/migrations/**` is therefore **untouched**, and
`bash apps/server/tool/verify_schema_bootstrap.sh` passes (exit 0, all 21 checks OK), because I
added nothing to the hand-maintained objects. The header of `tool/schema_bootstrap.dart` explains
those objects exist only in `migration.sql`/`schema_bootstrap.sql` and that the generator rewrites
`definition.sql` verbatim — so touching nothing was the only safe outcome, and I did not create a
migration to have something to own.

---

## 3. The governing clause, quoted

`docs/adr/0018-per-product-git-credentials.md:226-232` (§Decision, amendment A2):

> **Custody is an external secret manager (A3). SHIP IT holds a reference, never key bytes.**
> The keypair is generated and stored **server-side**, behind an API that returns only the
> public half, because SHIP IT pushes from its own backend and never from the browser
> (`b869ec24`). The private half is held by the secret manager. SHIP IT writes a **reference**
> — a secret path or ARN — and asks the manager for the material at transport time
> (`9417f8bf`). The private half is **never displayed, logged, persisted to the durable record,
> or transmitted**, exactly as the surviving clause above requires.

That is the standard this was built to. The enforcement is structural, not by discipline:

* **`SecretBytes`** (`lib/src/credentials/secret_material.dart`) wraps the private half. Its only
  textual projection is `<secret redacted, N bytes>`. There is deliberately no `operator +`, no
  `toJson`, no `List<int>` accessor. The four ways this leaks by accident — `$e` in a log field, a
  "helpful" exception message, a matcher handed the secret, an f-string in a report — are all
  compile-time impossible, not review-time catches. It matters that the Serverpod structured logger
  writes to the **session log, which is persisted to Postgres**: "logged" and "persisted to the
  durable record" are the *same sink* here.
* **`.bytes` audit.** Every private-material access in production code is one of exactly three
  sites, and each carries a comment saying why:

  | Site | Why it is legitimate |
  |---|---|
  | `repository_access_verifier.dart:273` | writes the 0600 identity file |
  | `gcp_secret_manager_secret_provider.dart:130` | base64 into the Secret Manager request body |
  | `local_file_secret_provider.dart:72` | writes the 0600 custody file |

  (`ssh_keypair.dart` also touches `.bytes` at 98/100/212/235 — that is the crypto codec itself,
  deriving the public half from a seed and serialising the private container.)
* **The response type is the whitelist.** `MintedCredential` has no private-half field and no
  accessor that can produce one. `toJson()` names its keys explicitly, and the endpoint returns
  exactly that. The shape of a leak is decided by the return type, not by what a caller remembered
  to omit.

---

## 4. Dependencies — choice and justification

```yaml
crypto: ^3.0.7            # SHA-256 over the SSH wire blob for the SHA256:… fingerprint
ed25519_edwards: ^0.3.2   # ed25519 key generation
```

* **`ed25519_edwards`** — a Dart port of Go's `crypto/ed25519`, RFC 8032 compatible, **pure Dart
  with no FFI**. On a path that mints production credentials, not taking a C ABI is worth the
  dependency. `cryptography` (the obvious alternative) would have been one package instead of two
  but pulls `ffi`/`win32` and routes keygen through its plugin/`CryptoAlgorithm` abstraction, which
  is pure overhead when the only operation is `newKeyFromSeed`.
* **`crypto`** — for the SSH fingerprint. **It was already resolved into this app's graph** as a
  transitive dependency, so promoting it to direct adds zero packages.
* **Net new packages: one** (`adaptive_number`, pulled in by `ed25519_edwards`).
* `ssh2` was deliberately **not** added — see §6.

I did **not** implement ed25519 by hand. Writing SHA-512 + Curve25519 field arithmetic for a
security boundary is a worse risk than one small pure-Dart package, and the test suite proves the
library's output against RFC 8032 vectors and OpenSSH rather than taking its word for it.

---

## 5. SecretProvider — two adapters, and the fallback is a recorded precondition

### GCP Secret Manager (production/staging)

Read `infrastructure/modules/secrets/main.tf` rather than guessing:

* Secrets are `google_secret_manager_secret` named `"${var.name_prefix}-<thing>"`, so the adapter
  takes `SHIPIT_GCP_SECRET_PREFIX` and builds `namePrefix-<reference>` — following the repository's
  convention instead of inventing a second naming scheme. Verified by test.
* **Region: there is none, and that is read from the Terraform, not assumed.** Every secret uses
  `replication { automatic = true }`, so the data plane is the single global
  `secretmanager.googleapis.com` and `var.region` does not apply. Threading a region variable
  through would imply a scoping that does not exist.
* Auth is **by name only**: `SHIPIT_GCP_SECRET_MANAGER_ACCESS_TOKEN`, else the GCE/GKE metadata
  server (`Metadata-Flavor: Google`). No token is written anywhere, and `describe()` — which goes
  to the startup log — cannot emit one. Proven by a test that puts a token-shaped value in the
  environment and asserts it appears in neither the log fields nor `describe()`.
* Created on demand (`secrets.create` tolerating 409, then `addVersion`); `destroy` deletes the
  secret, which is ADR 0018 §A2's "destroys the secret-manager handle" half of two-sided
  revocation.
* Every failure becomes a `SecretStoreException` naming only reference / operation / HTTP status
  and Google's `error.message`. The response body is reduced to those, never interpolated
  wholesale, because an echoed request body would put base64 key material into a log line.

> ### The GCP adapter is NOT claimed to be runtime-verified.
> ADR 0018 §Accepted risks (**A4**) records, verified at `43d328b`, that the secret manager's
> reachability **has never been runtime-probed** and that `9417f8bf` records confidence **LOW**.
> **That remains true of the code I wrote.** It was written against the published REST API and this
> repository's own Terraform, and it has never been executed against a real GCP project. No test in
> this lane pretends otherwise, and `describe()` carries `runtimeVerified: false (ADR 0018 accepted
> risk A4: never probed)` into the log so an operator reading it is not misled. The probe that
> `9417f8bf` follow-up action 4 requires needs a project this lane has no authority to touch.

### Local owner-only file store — the documented §A1/A4 **fallback**

`~/.config/shipit/platform/<GIT_REPOSITORY_<repo>_SSH>` at mode `0600` in a `0700` directory — the
exact path ADR 0018 §A1 names.

> **ADR 0018:233-235** — "The local secret store (A1) and host keychain (A4) remain the documented
> **fallback** when no secret manager is reachable in the target topology. **Fallback selection is a
> recorded precondition, not a silent default.**"

Both halves of that sentence are enforced:

1. **Not a silent default.** `SHIPIT_SECRET_PROVIDER` is **required and has no default**. Unset,
   blank and unrecognised all throw `SecretProviderNotConfiguredException` naming the variable and
   the accepted values. There is no `?? local_file` anywhere. A refused selection creates no
   directory and writes nothing.
2. **Recorded.** Every accepted selection is logged. The fallback is logged under its own event
   (`credential.secret_provider.fallback_selected`, `warning`) so it is **distinguishable from an
   ordinary selection**, not merely present in the log, and the fields say `selection: explicit
   (SHIPIT_SECRET_PROVIDER=local_file)`. A defaulted fallback *directory* is recorded separately
   from a configured one.

What the fallback gives up, stated plainly: under §A3 the guarantee is "SHIP IT holds a reference,
never key bytes". This adapter holds **both**, on the same host as the database. That is a strictly
weaker custody position, which is exactly why it is a fallback and why its selection is recorded
rather than assumed. It suits the single-machine QA stack behind the local-only posture ADR 0018
§Accepted risks (A3) already accepts; it suits nothing wider.

### Mode enforcement is set-then-verify, not set-and-hope

Dart's `File.writeAsBytes` / `Directory.create` create at `0666`/`0777` masked by the umask and
expose **no** `chmod`/`stat`. Under the near-universal umask `022` that is `0644` — readable by
every local account. For a deploy-key private half that is the exact failure §A1 exists to prevent,
and it would be **invisible**: nothing throws, the write "succeeds", the row records a verified
credential.

So `PosixFileModes` shells out to `chmod`, then **reads the mode back** and throws if it is not
exactly `600`/`700`. A `chmod` that a wrapper intercepted, or a filesystem mounted `noacl` ignored,
now fails the write instead of returning a credential whose custody nobody checked. Writes go to a
sibling temp file that is chmod'd *before* content reaches it and then renamed, so the key has
never existed on disk at any other mode. Where POSIX modes are unavailable this **throws** rather
than degrading.

---

## 6. The verification mechanism — the judgment call, and why

**Chosen: shell out to `git` with `GIT_SSH_COMMAND` and a transient owner-only identity file.**
Rejected: an in-process (pure-Dart) SSH client.

Why, and I weighed it rather than defaulting:

1. **"A real clone" is the claim ADR 0018:253-255 makes** — "a connectivity check has succeeded
   against the real host with the real key." `git-upload-pack` over OpenSSH *is* that. An
   in-process client opens the same TCP and SSH session but runs git's wire protocol on a
   hand-rolled transport, which is a **weaker claim than the one being made**.
2. **An in-process SSH client is a large dependency** — `ssh2` brings `pointycastle`, `typed_data`
   and an event-loop-shaped API, and would need its own host-key store to be worth using at all.
   This dispatch asks for a minimal dependency count *on a security boundary*, and OpenSSH is
   already installed and already audited everywhere this runs.
3. **The alternative does not actually remove the exposure it appears to.** The private half would
   still be in process memory. The marginal gain is "no 0600 file", not "no key in memory".

### What that costs, taken seriously

The identity file is private key material on disk for the duration of one clone. So:

* written into a `createTemp` directory at `0700`, file at `0600`, **both set and then verified**;
* **never** in an argv, an environment variable, a log line, an exception message or the outcome;
* the whole scratch tree is deleted on **every** path, and its absence is then **checked and
  reported** as `AccessProbeOutcome.secretMaterialRemoved` — not taken on trust;
* `HOME`, `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_SYSTEM` are redirected at the scratch tree, so a
  developer's `~/.ssh/config` (which can add `IdentityFile`, `ProxyCommand`, `RemoteCommand`) and
  any ambient `url.*.insteadOf` rewrite get **no say** in this clone;
* `BatchMode=yes`, `IdentitiesOnly=yes`, `IdentityAgent=none`, and both `PasswordAuthentication`
  and `KbdInteractiveAuthentication` off, so the clone can never fall back to a passphrase prompt,
  an interactive challenge, or an agent holding some other identity. **An unattended server
  blocking on a prompt is a credential service that has hung.**
* `gitExecutable` and `pathPrefix` are configurable because a process that handles a private
  deploy key must not resolve its helpers by bare name through a writable `PATH`. Both defaults
  keep ambient behaviour; both are the hardening path.

### This closes a recorded gap: the host key is enforced at the transport

ADR 0018 §Accepted risks (**A2**) records that `HostKeyStatus` had "a domain gate but NO transport
enforcer — this clause is decorative at the transport layer": the human confirmation was recorded
as data and honoured by the domain, while **the connection itself was unverified**.

`RepositoryAccessVerifier` is that missing enforcer, for this seam. It obtains the host's real key
with `ssh-keyscan`, computes the fingerprint **with `ssh-keygen -lf`** (not by reimplementing it —
SHA-256 over an SSH blob for ed25519 and SHA-1/MD5 for RSA, and a fingerprint one character out
fails every legitimate verification while passing every illegitimate one), compares it to the
fingerprint a **human** confirmed, and refuses to clone on any mismatch. `StrictHostKeyChecking=yes`
plus a one-line `known_hosts` holding **only the confirmed key** then makes OpenSSH enforce the same
fact independently, so a connection to any *other* host — a rewritten remote, a DNS answer that
changed mid-run — fails at the socket.

> The transport exception is deliberately **not** named `HostKeyNotConfirmedException`.
> `product_registry` already exports that name for the *domain's* refusal to record a check for an
> unconfirmed host. Mine is `HostKeyNotPresentedException` and means the *transport* refused to
> connect. Different failures, and A2 is precisely about the gap between them.

### What is NOT runtime-verified here, stated plainly

**The success path of a genuinely authenticated SSH clone was not reproduced in this
environment.** This repository has no git host, no SSH server and no network authority, and
`9477f8bf`-style probing is out of scope. I did not fake it. What IS proved, against real tools
and real processes:

* the private key that reaches disk is a genuine, OpenSSH-loadable identity — proven **from inside
  the `git` process that was supposed to use it**, by `PATH`-pinning a `git` stub that reads the
  identity path out of the generated `ssh` wrapper and hands that exact file to `ssh-keygen -y`;
* that file is `0600`;
* the wrapper carries every hardening option and **no key material**;
* `HOME`/`GIT_CONFIG_*` really were redirected, `GIT_TERMINAL_PROMPT=0`, and the clone addressed
  the `ssh://` URL the credential recorded;
* **cleanup on the failure path is proved explicitly**: with `git` exiting 128,
  `secretMaterialRemoved` is `true`, the reason is persisted and secretless, and no
  `shipit_credential_verify_*` directory remains anywhere under the system temp;
* a **refused** connection (wrong fingerprint, and a host presenting nothing) throws before `git`
  is invoked at all — the report file is never even written — and still cleans up;
* `ssh-keygen` is **not** stubbed, so "is this a loadable SSH key" is answered by OpenSSH.

This is the same honesty discipline as §A4, and `9417f8bf` follow-up action 4 remains open.

---

## 7. Endpoint contract, and a note for the client lane

New `CredentialEndpoints` — `apps/server/lib/src/endpoints/credential_endpoints.dart`.

**Why a new endpoint rather than extending `ProductRegistryEndpoints`.** Custody is a security
boundary and should be auditable as one. These two methods are the only ones in the server that can
cause a private key to be fetched, written to disk, or offered to a transport. Keeping them in one
small file means a reviewer answering "can key material leave the process?" reads one file rather
than hunting through a 600-line product endpoint. `ProductRegistryEndpoints` keeps the product,
baseline and repository-reference surface, none of which touches a key.

```
generate(Session, {productId, repositoryId, credentialId?}) ->
  {credentialId, productId, repositoryId, publicKey, fingerprint,
   algorithm, referenceName, status, hostKeyStatus, host?}
  status is always "generated". Never "verified".

verifyAccess(Session, {productId, repositoryId,
                       hostKeyFingerprint,   // REQUIRED — human TOFU confirmation
                       confirmedBy, checkedBy?}) ->
  {credentialId, status, canReachRepository, secretMaterialRemoved,
   failureReason?, lastVerifiedAt?, observedHostKeyFingerprint?}
```

* `status` becomes `verified` **only** when `git clone` actually completed. That is what lets the
  client set `accessStatus = verified` and unblock Register.
* `hostKeyFingerprint` is **required with no optional form**. An endpoint that could clone against
  an unconfirmed host is exactly the A2 gap.
* `generate` on a repository with an existing active credential is refused by the domain's one-
  active-per-repository guard; the caller rotates instead.
* **`hostKeyStatus` is `unknown` at mint.** The client must obtain the host key fingerprint out of
  band (e.g. `ssh-keyscan <host> | ssh-keygen -lf -`) and pass it to `verifyAccess`. There is no
  server-side shortcut, by design.
* Custody is resolved **once per process**: Serverpod constructs the `Endpoint` in
  `initializeEndpoints`, so a lazy field is a process singleton — the recorded precondition is one
  fact rather than a line per mint, and the GCP adapter stops building a fresh `HttpClient` and
  token cache per request. It is **lazy**, not eager, so an unconfigured environment still *starts*
  (the triage scheduler has no bearing on custody, and a server that refused to boot over it would
  take triage down too); the first credential call refuses instead, loudly, with nothing defaulted.
* `environmentOverride` / `resetCustodyForTesting` exist because Dart cannot mutate
  `Platform.environment` at runtime, and without them the only reachable endpoint path under
  `dart test` is the fail-closed refusal. They are **instance** fields, not statics, so the blast
  radius of misuse is one `Endpoint` object.

### Ordering: custody first, then the row

`SecretProvider.store` runs **before** the row is written, and a store failure propagates. There is
no window in which a public key has been handed to an operator for installation on a repository
whose private half exists nowhere — which is precisely the non-installable-key failure this lane
replaces. If the row write then fails, the manager handle is destroyed so no unowned orphan lingers.

---

## 8. Gates — verbatim

All run in `/private/tmp/shipit-impl-keys` at `HEAD_SHA 315e9ca`.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 653 files (0 changed) in 8.21 seconds.
exit 0

$ dart analyze apps/server
Analyzing server...
No issues found!
exit 0

$ bash apps/server/tool/verify_schema_bootstrap.sh
21 checks, all OK
exit 0

$ make test-integration          (SERVERPOD_DATABASE_PASSWORD=shipit)
03:15 +183 -1
exit 2
```

**`dart analyze apps/server` is clean at exit 0** — no errors, no infos, no warnings, nothing
pre-existing to distinguish. `AGENTS.md` records this command "historically exits non-zero on
pre-existing infos"; at `8725b65` and at this HEAD it does not. Nothing was suppressed, ignored or
`@Skip`ped.

### `make test-integration` is RED — on one pre-existing test that is not mine

```
Failing tests:
  test/integration/dogfood_shipit_postgres_test.dart: S-1 DOGFOOD — Product: ShipIt
    (Postgres, read-only) register ShipIt, discover pinned HEAD read-only,
    propose baseline, survive restart
```

`Expected: true / Actual: <false> / dogfood expects a git working tree at /private/tmp/shipit-impl-keys`

**Baseline evidence.** I cloned the repository to a *primary* checkout at `8725b65` with none of my
changes and ran the same gate: **`+108 -10`** — ten failures, the dogfood test among them, failing
differently (`PathNotFoundException` from `product_registry`'s
`ReadOnlyRepositoryReader._walk` at `read_only_repository_reader.dart:90`, plus a 30 s timeout).
**So `make test-integration` is red at `BASE_SHA` on this machine, before this lane exists.**
My HEAD is `+183 -1`: 183 passing, the same one pre-existing test failing.

That test has **two** independent defects, neither in this lane's code:

1. **`dogfood_shipit_postgres_test.dart:87`** asserts `Directory('${repoRoot}/.git').existsSync()`.
   In a **linked git worktree** — which is where every lane in this workflow runs —
   `.git` is a `gitdir:` *pointer file*, not a directory, so the assertion refuses to run at all.
   I wrote a one-line repair (accept file-or-directory via `FileSystemEntity.typeSync`) and
   confirmed it lets the test proceed; it then fails on defect 2. **I reverted it**, because it does
   not unblock the gate, it is unrelated to this feature, and keeping it would dilute the diff with
   an out-of-scope change. Reported for routing instead (§10).
2. **`packages/product_registry/lib/src/discovery/read_only_repository_reader.dart:90`** throws
   `PathNotFoundException` while walking a `git archive` snapshot of this repository — a directory
   listed successfully at one level fails to list at the next, under a 30 s timeout. I confirmed no
   tracked symlinks (`git ls-files -s | awk '$1=="120000"'` → 0), no gitlinks and no submodules, so
   I am **not** asserting a root cause. **It is in `packages/**`, which this lane may not touch.**
   This is why the gate cannot be made green from here.

> I did **not** weaken, skip, `@Ignore`, `@Skip` or `x`-exclude anything to reach a green gate, and
> I did not modify the dogfood test in the delivered HEAD.

### Test-database hygiene — confirmed

Every `make test-integration` run self-cleaned. Final run:

```
test-integration: removing shipit_integration_75620 (container + data)
 Container …-postgres_integration-1 Stopped / Removed
 Network shipit_integration_75620_default Removed
```

Read-only verification afterwards: **no `shipit_integration_*` containers, volumes or networks
exist.** The compose projects still present (`docker`, `shipit`, `server`, `control_plane`) are
pre-existing and were never touched.

**This lane issued zero mutating Docker/Compose commands.** The only Docker invocations I made
were read-only listings (`docker ps -a --filter`, `docker volume ls`) to check for leaks. I never
ran `make clean`, `make test-env-down`, `make e2e-down`, or any `down -v`; `make test-integration`
was the only way I obtained a database. `docker/**` is untouched — `docker/compose.qa.yaml` was
read as text only, and the QA stack (compose project `docker`) was not disturbed.

### No private half in any log, output or report

Not asserted, **verified**: no `print`/`stdout` write exists in the production credential code; the
three `stderr`/`stdout` references are a subprocess's stderr in a `chmod` message, a subprocess's
stdout being *parsed* for a fingerprint, and a local variable named `stderr`. This report contains
no key material, and neither does any test failure message — `SecretBytes` makes that structurally
impossible.

---

## 9. Tests

| File | Tests | Proves |
|---|---|---|
| `test/credential_keypair_test.dart` | 12 | RFC 8032 §7.1 vectors → public derivation; fingerprint agreement with `ssh-keygen -lf`; `ssh-keygen -y` loads the generated PEM and recovers **our** public key; sign/verify round-trip; 16 mints are 16 distinct keys; `SecretBytes` cannot be printed or interpolated |
| `test/secret_provider_test.dart` | 19 | unset / blank / unknown selection all refuse, with no filesystem side effects; the fallback logs under its own event with `isDocumentedFallback=true`; a defaulted directory is recorded as defaulted; the GCP log carries no token; secret ids follow the Terraform prefix shape; reference names reject traversal, separators and leading dots; round-trip; `0600`/`0700` verified by `stat`; destroy idempotent; store failure reported without material |
| `test/repository_access_verifier_test.dart` | 6 | the identity `git` was handed is `0600` and OpenSSH-loadable **and matches our public key** (read from inside the stubbed `git`); wrapper hardening options present and keyless; `HOME`/`GIT_CONFIG_*` redirected; **failure path removes the scratch tree**; wrong fingerprint refuses **before `git` runs**; a host presenting nothing refuses; real `ssh-keyscan` against a dead port refuses and cleans up |
| `test/integration/credential_key_service_postgres_test.dart` | 12 (real Postgres) | **every column** of the credential row scanned for the PEM, its header and its base64; the endpoint response scanned per value and joined; OpenSSH confirms the stored half matches the advertised key; a failing provider writes no row and returns no key; the endpoint fails closed unconfigured; a foreign repository is refused; a second active credential is refused; unreachable host ⇒ domain refuses / `changed` fails closed / `canReachRepository` false; `https://` remote cannot be verified with a deploy key; one `0600` file per reference |

`dart test` on the three non-DB files: **37 passing, 0 failing.**
`make test-integration`: **183 passing**, including all 12 above.

> **One incidental fix, inside my own test file.** My first integration test closed its Serverpod
> sessions in `tearDownAll`, so ten tests' worth of connection pools stayed open against the single
> disposable Postgres. That tipped the whole suite into `Failed to acquire pool lock` — **231
> occurrences**, cascading into files having nothing to do with credentials. Closing per *test*
> removed the cascade entirely (my first run: 10 failures; after: 1). It was my bug, it is fixed in
> my file, and it is how I found the pre-existing red.

---

## 10. Discoveries (classified per `docs/engineering/LEARNING_POLICY.md`)

**`PROJECT_FACT`** — automatic; verified against the live schema.
The credential table already carried the full ADR 0018 contract (`referenceName`, `fingerprint`,
`algorithm`, `status`, `lastVerifiedAt`/`lastVerifiedBy`/`lastFailureReason`) and **no key-material
column**. The gap was code, not schema. `apps/server/migrations/**` needed no change.

**`RUNTIME_DISCOVERY`** — automatic.
`make test-integration` is **red at `8725b65`** on this machine: `+108 -10` in a clean primary
clone. Two independent causes, neither in this lane: `dogfood_shipit_postgres_test.dart:87` assumes
`.git` is a directory (false in every linked worktree), and
`product_registry`'s `read_only_repository_reader.dart:90` throws `PathNotFoundException` walking a
`git archive` snapshot. Route both.

**`WORKFLOW_IMPROVEMENT`** — independent review.
**Adding a Serverpod endpoint necessarily regenerates `packages/control_plane_client/lib/src/protocol/client.dart`.**
No server lane owns `packages/**`, so any server lane that adds an endpoint is structurally unable
to leave the repository generator-consistent. Either server lanes must be granted that file, or the
lane ownership map must nominate a regenerating lane as a mandatory co-owner of every endpoint
addition. I copied only the three files I own out of a scratch regeneration and left the client
file stale **on purpose**, flagged in the commit message.

**`AUTOMATION_OPPORTUNITY`** — independent review.
Wire `resolveSecretProvider()` into `run()` in `apps/server/lib/server.dart` so the ADR 0018 §A1/A4
selection is a process-start banner. **One line, and it is outside this lane's ownership.** Until
then the precondition is recorded on the first credential call — still before any key can be minted,
which is what the clause requires, but not in the startup log an operator reads first.

**`CONTRADICTION`** — human decision / routing. **This one needs attention.**
`9417f8bf` records gap **G-7**: `RepositoryCredentialView` serialises `referenceName` to the client,
and under A3 that value is an ARN or secret path, so **any client that can read a credential view
learns the vault's topology and the secret's name**. Removing it from the client view is recorded
as *"required rather than optional"* — and it is **still unaddressed**.
This dispatch told me to return `reference` from `generate`, so `MintedCredential.toJson()` returns
it. I followed the instruction; I am **not** widening it silently:
* I did **not** create a new exposure — `repository_credential_view.dart:145`/`:166` already emits
  it, and `apps/control_plane/lib/data/control_plane_repository.dart:108` already surfaces it to the
  UI (`product_detail_page.dart:471` renders it beside the fingerprint).
* I have added a **second reader** of that already-exposed value.
* Substituting an opaque handle instead is a **product/architecture decision beyond my authority**,
  so I am escalating rather than deciding.

Recommendation to route: decide whether `generate`'s response carries the raw reference or an opaque
handle, and whether that closes G-7 for this endpoint. If the answer is "opaque handle", the change
is small and confined to `MintedCredential.toJson()` plus the tests in §9.

**`ARCHITECTURE_DISCOVERY`** — human decision / ADR amendment.
Three implementation decisions are recorded in code comments but are architecture, not code, and
ADR 0018 does not yet state them:
1. **Verification transport is `git` + OpenSSH with a transient `0600` identity file**, with the
   private half on disk for the duration of one clone, deleted-and-checked on every path. ADR 0018
   A2 anticipates "building this seam" and says it "warrants its own review" — this is that seam.
2. **The `none` cipher in the stored `openssh-key-v1` container.** Verified empirically:
   `ssh-keygen -N ''` emits exactly `ciphername: "none"`, `kdfname: "none"`, empty kdfoptions — I
   decoded one. OpenSSH therefore both writes and reads it. `aes256-ctr`+`bcrypt` would mean
   implementing bcrypt-pbkdf to obfuscate a file that exists for milliseconds in a `0700` directory.
   Plaintext-at-rest is a deliberate, bounded, reviewed property, not an oversight.
3. **The transport host-key enforcer closes §Accepted risks (A2) for this path.** Whether ADR 0018
   should be amended to record that A2 is now partially discharged is a human call; A2's other half
   (the *push/clone transport used by the worker*) is untouched — `git_workspace_inspector.dart:107`
   still runs `Process.run(git, args)` with no environment.

---

## 11. Blockers, and what I did **not** verify

**No blocker on the deliverable.** The work is complete; the caveats are about verification scope,
not about the code being unfinished.

1. **The GCP Secret Manager adapter has never been executed.** §A4 remains open. Stated in the
   adapter's own `describe()`. `9417f8bf` follow-up action 4 is still required.
2. **The success path of a genuinely authenticated SSH clone was not reproduced** — no git host, no
   SSH server, no network authority here. Everything around it is proved (§6). No claim is made
   that a clone authenticated against a live host.
3. **`make test-integration` cannot be made green from this lane** (§8). Red at `BASE_SHA`; the
   remaining defect is in `packages/**`.
4. **The endpoint is not callable from the Flutter client until `packages/control_plane_client` is
   regenerated** (§10, `WORKFLOW_IMPROVEMENT`). A server-to-server or test-tools caller works now.
5. **The GCP adapter has no automated coverage of its HTTP paths.** Testing it honestly needs a
   Secret Manager endpoint; none exists here and mocking the REST surface would assert my own
   assumptions rather than the API's. Its failure handling is typed and total, which is what makes
   the unprobed dependency safe to fail closed.
6. **The private half is unavoidably in process memory during a verification**, and is briefly on
   disk as a `0600` file. `SecretBytes.wipe()` narrows that window; it cannot close it, and I say so
   in the method's own documentation rather than overstating it.

---

## 12. Parallel work

### SAFE_PARALLEL_WORK

* **`apps/control_plane/lib/**` — the client lane.** No file overlap. Three contract facts it must
  plan around: (a) `generate` returns `status: "generated"`, never `verified`; (b) `verifyAccess`
  **requires** `hostKeyFingerprint` + `confirmedBy`, which the client must obtain out of band — the
  server will not shortcut it; (c) `hostKeyStatus` is `unknown` at mint, so the UI has a genuine
  "confirm this host key" step.
* **`packages/control_plane_client/**` — regeneration.** Required before the client can call this
  endpoint. Disjoint from my tree; I deliberately left it untouched (§10).
* **Any `apps/server/lib/src/services/**`, `apps/server/lib/src/persistence/**`,
  `apps/server/lib/server.dart` work.** Disjoint. Note `server.dart` and `services/**` are *not* in
  my `OWNED_PATHS`, so if another lane edits them there is no conflict — but §10's
  `AUTOMATION_OPPORTUNITY` needs `server.dart`, so route it deliberately rather than letting a lane
  wander in.
* **Documentation of ADR 0018 §A2/§A4 and the `9417f8bf` G-7 decision.** Independent of this tree.
* **`packages/product_registry` — the dogfood fix** (§10, discovery 2). It is the only path to a
  green `make test-integration`, and it is prohibited for me.

### PROHIBITED_PARALLEL_WORK

* **`serverpod generate` run anywhere that writes into `packages/control_plane_client/**` from this
  worktree.** It would silently produce an out-of-scope diff and collide with the client lane.
* **Any write to `apps/server/migrations/**` or `apps/server/tool/**` on the strength of this lane.**
  No migration was needed and `verify_schema_bootstrap.sh` passes; a concurrent edit to those
  hand-maintained objects would make that pass meaningless.
* **Any Docker/Compose mutation** — including `make clean`, `test-env-down`, `e2e-down`, any bare
  `down -v`, and any command touching compose project `docker` (the live QA stack). Concurrent
  Docker work while `make test-integration` runs can also collide on the `shipit_integration_<pid>`
  project and the port `9199`.
* **Editing `apps/server/lib/src/credentials/**` or `credential_endpoints.dart` from another lane
  while this is under review.** It is the security boundary; a reviewer's provenance for this
  commit would no longer describe the code.
* **Relieving G-7 by editing `repository_credential_view.yaml` or the client's repository layer as
  a side effect of this lane.** That is §10's `CONTRADICTION` and needs a decision first.
* **`git push`, merge to `main`, or rebasing this branch.** Three commits, unpushed:
  `428f4fa` → `4ac16a3` → `315e9ca`.

---

## 13. Result

```
GATES:
  format=pass   dart format --output=none --set-exit-if-changed .   -> (0 changed), exit 0
  analyze=pass  dart analyze apps/server                           -> "No issues found!", exit 0
                (cleaner than AGENTS.md records; nothing suppressed, ignored or @Skipped)
  tests=fail    make test-integration                              -> +183 -1, exit 2
                the single failure is test/integration/dogfood_shipit_postgres_test.dart,
                which is RED AT BASE_SHA (+108 -10 in a clean primary clone) and whose remaining
                defect lives in packages/** — prohibited for this lane. All 12 tests this lane adds
                pass; all 37 non-DB tests pass. No test was weakened, skipped or excluded.
  build=pass    bash apps/server/tool/verify_schema_bootstrap.sh    -> 21/21 OK, exit 0
                (apps/server/migrations/** untouched: the reference column already existed)
  runtime=n/a   no browser surface in this change. Every runtime claim in this report is backed by
                a real subprocess assertion and is stated with its scope — see §6 for exactly what
                was and was not reproduced.

BLOCKERS: none on the deliverable. Six verification-scope caveats in §11, the load-bearing ones
being: the GCP adapter is NOT runtime-verified (§A4 still open), and an authenticated SSH clone
against a live host was NOT reproduced.

READY_FOR_INDEPENDENT_REVIEW: YES
```

**This is a security boundary and I have not approved my own work.** The independent reviewer
should, at minimum:

1. confirm the private half cannot reach a response, a log, or the database — the `.bytes` audit in
   §3 (three sites, all load-bearing) is the shortest route;
2. confirm the `none`-cipher `openssh-key-v1` container and the `ssh` wrapper script in
   `repository_access_verifier.dart` by inspection;
3. re-run `make test-integration` and confirm the only failure is the dogfood test, and re-run the
   **baseline** claim in §8 if they want independent evidence that it is pre-existing;
4. re-read §6's "what is NOT runtime-verified here" and decide whether the evidence there is
   sufficient for the seam, given ADR 0018 A2 says it "warrants its own review";
5. route §10's `CONTRADICTION` (G-7) and `WORKFLOW_IMPROVEMENT` (serverpod generate reaching into
   `packages/**`), which I am explicitly not authorised to decide.