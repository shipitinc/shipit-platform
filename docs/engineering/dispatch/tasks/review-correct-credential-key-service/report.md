# Focused Re-Review — correct-credential-key-service-b1b2

```
RESULT: APPROVE_CORRECTIONS

REVIEWED_HEAD: da68b5f67d3766776b35d57d16956dd4b993ae7e

FINDINGS_REVIEWED:
  B-1  RESOLVED. The custody-leak class is closed, and it is closed by a TYPE
       GATE that is real, complete, and on the path Serverpod actually uses.
  B-2  RESOLVED. No String projection of private material survives anywhere; the
       class doc matches the code; the two test-file leak paths are closed.
  M-1  RESOLVED (measurement). I re-measured base independently: +170 -2, and I
       found D-4 FAILING AT BASE, which is stronger evidence than the report has.
  M-3  RESOLVED. The kill really reaps descendants; the identity file is gone on
       the TIMEOUT path; the grandchild is provably the part under test.
  M-4  ACCEPTED. The ADR clause is already satisfied. A tested seam is NOT a
       substitute for an unmet requirement, because there is no unmet requirement.
  M-5  ACCEPTED as a partial with residue tracked. Correctly withdrawn.
  M-6  ACCEPTED as a partial with residue tracked. Enforcement added; the
       decision left to its owner.
  MUTATION PROOF  REPRODUCED — five mutations, all load-bearing (I did four plus
       one extra to disambiguate which pid survived).
  NO WEAKENED TESTS  VERIFIED.
  NOT-FIXED LIST  All five confirmed not fixed; all five reasons hold.

REGRESSIONS: none. Six findings recorded, none blocking. One is MEDIUM (F-1) and
       is the incomplete application of the M-5 hardening to the *other*
       client-supplied field; it carries no key material and violates no clause
       this review enforces, so it does not hold the merge.

BLOCKERS: none

READY_FOR_MERGE: YES
```

---

## 1. Provenance — VERIFIED

| Check | Expected | Observed |
|---|---|---|
| Worktree | `/private/tmp/shipit-impl-keys` | same |
| Branch | `impl/credential-key-service` | same |
| `git rev-parse HEAD` | `da68b5f…` | `da68b5f67d3766776b35d57d16956dd4b993ae7e` |
| `CORRECTED_FROM_HEAD` | `315e9ca…` | `315e9ca21ea6b33cfbaa9f0411db69951867e16e` is `HEAD~1`, unchanged |
| Commits in the correction | 1 | 1 — `da68b5f` only |
| Working tree | clean | clean (`git status --porcelain` empty) |
| `main` | `8725b65`, untouched | `8725b65deaab565f7c3b93d644e73f1ec07a6f39`; `da68b5f` only on `impl/credential-key-service`; nothing pushed |

Nothing was rewritten. The three reviewed commits are byte-identical to what I
reviewed; the correction is one new commit on top, which is what
`aef-correction-loop` requires.

**Prohibited paths — diffed explicitly, empty.** `git diff --name-only
8725b65..da68b5f | rg 'migrat|tool/|schema|packages/'` → **nothing**. That is the
load-bearing fact for §7 below: this branch changes **no migration, no schema
bootstrap, no tool, no `packages/**`, and no `docker/**`. All 21 changed files are
inside `apps/server/lib/src/credentials/**`, `credential_endpoints.dart`, the two
generated server artifacts, `apps/server/pubspec.yaml`, `apps/server/test/**`, and
the pre-existing root `pubspec.lock`.

---

## 2. THE CENTRAL QUESTION — I can now confirm it

*"Can private-key material reach an HTTP response, a log, the database, an exception
message, or disk surviving the call?"* My prior review could confirm it for the
response and the database and **not** for the log. At `da68b5f` I can confirm all
five. Each leg, with what I checked:

**(a) An HTTP response — CONFIRMED CLEAN.** `MintedCredential.toJson()`
(`credential_key_service.dart:99-110`) and `AccessVerification.toJson()`
(`:147-158`) are explicit whitelists. Neither type has a private field nor an
accessor deriving one, so the wire shape cannot carry a private half. The only new
response field in this correction is `hostKeyConfirmationProvenance`, a `const`
string literal that I read (`credential_key_service.dart:24-27`).

**(b) A log — CONFIRMED CLEAN, and this is the leg B-1 broke.**
`credential_endpoints.dart` never calls `error.toString()` — I grepped; the only
hits in that file are in comments. Both `catch` blocks log through the single
named function `credentialFailureLogFields` (`:273-283`), which renders
`secretlessText(error)`.

**Is `secretlessText` on the path Serverpod uses for unhandled errors? Yes.**
That was the question I most expected to fail, because an endpoint's *own* logger
is only half the sink — Serverpod also logs an error that escapes an endpoint
handler. `credential_endpoints.dart:160` and `:224` both do
`Error.throwWithStackTrace(redactUnauditedFailure(error), stackTrace)`.
`redactUnauditedFailure` (`secretless_error.dart:76-77`) returns the original only
when it is an `AuditedFailure`; otherwise it substitutes a fresh
`UnauditedFailure(runtimeType)` whose `toString()` (`:90-95`) is a fixed literal
and which **does not retain the original or its stack**. So what Serverpod
stringifies is the stand-in, not the carrier. The rethrown `stackTrace` is a list of
frames and cannot carry a message. This is the piece B-1 needed and it is correct.

**(c) The database — CONFIRMED CLEAN.** `apps/server/migrations/**` is not in the
diff; `verify_schema_bootstrap.sh` passes 21/21 (I re-ran it). `lastFailureReason`
is the only failure text reaching a column, and it is `git`/`ssh` stderr with the
scratch path replaced and truncated (`_sanitise`,
`repository_access_verifier.dart:767-773`) — OpenSSH does not echo an identity
file.

**(d) An exception message — CONFIRMED CLEAN.** I enumerated every `throw` in
`credentials/**` and checked each:

- All 8 exception types in the directory are `AuditedFailure`, and I read every
  `secretlessDescription`: each composes from its own closed set of named fields.
- The 3 remaining non-audited throw sites carry **no material** and fail in the
  *safe* direction: `validateReferenceName` throws `ArgumentError.value(length…)`
  (`secret_provider.dart:183-198`), `ssh_keypair.dart:139/279` throw
  `ArgumentError.value(seed.length, …)`, and `repository_access_verifier.dart:655`
  throws a re-built `ProcessException`. Being unaudited, any of them reaching the
  endpoint sink is suppressed to its `runtimeType`.
- `_googleMessage` (`gcp_secret_manager_secret_provider.dart:310-325`) has its own
  `try`/`on Object` returning the literal `(no parsable error message)` — the same
  class of bug, fixed in the same place a third time.

**Is the third instance correctly scoped, or does withholding only on `addVersion`
leave another request path exposed? Correctly scoped — and I verified it by reading
every call site, not by trusting the claim.** The adapter makes exactly four
requests: `POST /secrets` (body `secretId` + `replication`, no material),
`POST /secrets/$id:addVersion` (body `payload.data` = base64, material — the only
one), `GET …/access` (null body), `DELETE /secrets/$id` (null body). The
`carriesSecretMaterial: true` flag is on `addVersion` and only there
(`:156-165`). For the other three the service never received the payload, so it has
nothing to echo — the invariant is not "we decided to withhold on the risky one",
it is "we withhold wherever we sent it". Also checked: `_send` returns the raw 2xx
body and `store` discards both results, so an API echo of the payload could not be
retained even in memory past the call.

**(e) Disk surviving the call — CONFIRMED CLEAN.** See §4.

**Conclusion: B-1 is genuinely closed, and the mechanism is a class rather than two
lines.** One inaccuracy in the report's justification, recorded as F-6 — it makes
the fix *stronger* than claimed, not weaker.

---

## 3. B-1 — the mutation proof (four claimed; I ran five)

I did not touch the reviewed worktree. I made a throwaway primary clone at
`da68b5f` outside the workspace, mutated there, and deleted it afterwards. The
clone's full suite passes `+56` after every revert, which is my proof that nothing
was left behind.

**Mutation 1 — reintroduce both unguarded decoders** (`jsonDecode(response) as
Map<String, dynamic>` and `base64.decode(data)`, i.e. the exact B-1 defect):

```
00:06 +28 -1: a truncated access body yields a typed, silent failure [E]
  Expected: <Instance of 'SecretStoreException'>
    Actual: FormatException:<FormatException: Unterminated string (at character 146)
            ...load":{"data":"AAAAB3NzaC1lZDI1NTE5AAAAIEXAMPLESECRETHALFBASE64MATERIALHERE
                                                                                        ^
00:06 +28 -2: an undecodable payload yields a typed, silent failure [E]
00:06 +28 -3: a non-object access body yields a typed, silent failure [E]
```

Three tests fail. Note that the failure output *itself* reproduces B-1 — the
`FormatException` message carries the base64 material — which is the original leak,
demonstrated again from inside the test runner.

**Mutation 2 — re-add `String get privateKeyPem`:**

```
00:03 +18 -1: the declared public surface is exactly the safe one [E]
  Expected: Set:[algorithm, comment, fingerprint, privateKeyPemBytes, privateSeed,
                  publicKeyAuthorizedLine, publicKeyBlob, publicKeyBytes,
                  toString, wipeSeed]
```

**Mutation 3 — reintroduce `reason: '$error'` in the local adapter:**

```
00:00 +7 -1: no reason interpolates a catch-clause binding [E]
  Actual: ['local_file_secret_provider.dart: reason interpolates the caught `error`']
```

**Mutation 4 — remove the descendant kill, keep the parent kill:**

```
00:17 +0 -1: the clone child and its grandchild are gone, and so is the file [E]
  Expected: true  Actual: <false>
  pid 94892 survived the clone timeout
```

**Mutation 5 (my addition) — remove *all* kills.** Reported `pid 96571`. A
different pid. Since the test asserts `git_pid` first and mutation 4 kills the
parent, the differing pid proves **mutation 4 failed specifically on the
grandchild**. That is the decisive evidence that the `ps` walk is load-bearing and
that Dart's `process.kill` genuinely cannot reach the grandchild.

**All four claimed negative checks reproduce. The tests are load-bearing.**

---

## 4. B-2 and M-3 — verified at the source

### B-2 — no String projection survives; the doc now matches the code

`rg '\bprivateKeyPem\b'` across `--type dart`: every remaining hit is a **parameter
name** (`repository_access_verifier.dart:267/298/306/335` — a `SecretBytes`
parameter, which is the right type), a **doc reference**, or a **test-file comment
naming the removed member**. The getter itself does not exist.

The codec confirms the claim at the root: `encodeOpensshPrivateKeyPemBytes`
returns `Uint8List`, `_pemArmour` (`:339-358`) emits the whole armouring as bytes,
and there is no intermediate `String` of key material anywhere in the codec. The
transient `base64.encode(der)` inside `_pemArmour` is a `String` in memory for one
statement and is dropped on the next line; the report states this rather than
hiding it, and ADR 0018 §A2 governs display/log/persist/transmit, not transient
process memory. `SecretBytes.toString()` remains length-only.

The class doc (`:66-90`) now describes the code. One imprecision, recorded as F-4:
"no public accessor that returns the seed as a `Uint8List`" is literally false,
because `privateSeed.bytes` is exactly that. The guarantee that matters — no
*accidental* projection, since `log('$pair.privateSeed')` emits
`<secret redacted, 32 bytes>` — holds and is separately proven.

**The two test-file leak paths are closed, as reported.** I confirmed both in the
diff: `expect(utf8.decode(read.bytes), pem)` → `expect(_sameBytes(read.bytes, pem),
isTrue)`, and every PEM assertion is now a **boolean** over a decoded string
(`pem.startsWith(h) == true`), so a failure prints `false`. `rg '\.bytes'` in
`credentials/**` returns six sites, every one justified and documented: three
produce material that legitimately must exist (the GCP request body, the local
store write, the identity-file write) and three are inside the crypto codec. All
six were justified in my prior review and all six still are.

### M-3 — the kill reaps descendants; the file is gone on the TIMEOUT path

`_runBounded` (`repository_access_verifier.dart:637-697`):

1. `Process.start`; stdout/stderr joins and `exitCode` held (`:663-665`).
2. On `TimeoutException`, `_descendantPids(process.pid)` is read from `ps -A -o
   pid=,ppid=` **before** the parent is signalled (`:678`) — and the ordering claim
   is correct, since signalling the parent first would re-parent the children to
   `init` and lose them.
3. `process.kill(ProcessSignal.sigkill)` then `_signalPid` for each descendant
   (`:680-683`). `SIGKILL` not `SIGTERM` is right for a `git` blocked in a network
   read. `_descendantPids` returns shallowest-first, so `.reversed` signals deepest
   first.
4. Drain bounded at 5 s, then `AccessVerificationTimeoutException` — typed, audited,
   naming the helper, the ceiling, **and the pids signalled**
   (`killedProcessIds`), which is the right thing for an operator to be able to
   check.

**The identity file is gone on the timeout path, not only on success and ordinary
failure.** `AccessVerificationTimeoutException` propagates out of `_probe` through
`verify`'s `on Object` handler (`:316-323`), which calls `_destroy(scratch)` **before**
rethrowing, so the removal happens. The test asserts this directly: it polls
`kill -0` for both pids and then asserts no `shipit_credential_verify_*` directory
survives anywhere under system temp. And the test cannot be fooled about *which*
path it is on: the stub records `child_opened_identity=yes` from inside the
grandchild, so the identity file provably existed and was held open when the
timeout fired.

The same treatment reached `_scanHostKeys` (which previously had the identical
`Process.run(…).timeout` defect) and `_sshKeygenFingerprint` (which previously had
**no** timeout at all). Both fail closed — a bounded `ssh-keyscan` yields `{}`,
which `matched.isEmpty` turns into a refusal; a bounded `ssh-keygen` yields `null`,
which drops the key. I checked for regression in the refactor: `_helperEnvironment`
was already being passed to both at `315e9ca`, so the environment handling is
unchanged, and `ProcessResult.stdout` is still a `String`, so `(clone.stderr as
String)` still holds.

**One accepted bound, recorded as F-7** — see §9.

---

## 5. THE GATE — D-4 is genuinely unrelated, and I have stronger evidence than the report

This was the most important item and I treated it as such. All runs recorded with
the pool-lock occurrence count and the host load beside them, because on this
machine a bare pass/fail figure is not information.

| # | Tree | Load before | Result | Pool-lock | Failures |
|---|---|---|---|---|---|
| M1 | **BASE `8725b65`** (primary clone) | 85.95 | **`+170 -2`** | **0** | dogfood + **D-4** |
| M2 | HEAD `da68b5f` | 128.76 | `+190 -1` | **0** | dogfood only |
| — | base `8725b65` (my prior review) | not recorded | `+171 -1` | 0 | dogfood only |
| — | base `8725b65` (implementer) | 113–214 | `+171 -1` | 0 | dogfood only |
| — | HEAD `da68b5f` (implementer, best of 5) | 113–214 | `+189 -2` | 0 | dogfood + D-4 |

**D-4 fails at BASE.** Verbatim from my base run:

```
01:28 +71 -1: product_credential_immutability_postgres_test.dart:
  D-4 under concurrency: two mints of one id yield one row and one identity conflict [E]
  Expected: (contains 'already exists' and not contains 'already has an active credential')
    Actual: 'repository credimm-repo-1 already has an active credential; another
             caller recorded one first, so rotate it instead of issuing a second one'
     Which: does not contain 'already exists'
  this refusal must name the identity conflict, not the one-active-per-repository race
```

This is **the identical failure mode** the implementer described, in a file whose
last commit is `3f3f4f4`, long before this branch. Answering the three questions the
dispatch asked:

1. **Is it a race?** Yes. D-4 (`:1039-1093`) drives two `recordGeneratedCredential`
   calls through a `_ReadBarrier` so both claim the same id `cred-race`. The engine
   has two distinct refusals available — the identity conflict ("already exists")
   and the one-active-per-repository index ("already has an active credential") —
   and the test requires them to stay tellable apart. The barrier's interleaving
   under load selects the second one. The test's own comment at `:1043-1049` says
   exactly this.
2. **Does it reproduce at base?** **Yes — I measured it at `8725b65`, in a primary
   clone, with zero pool-lock occurrences.** That is the finding the dispatch most
   needed and neither prior report could supply, because in all three earlier base
   runs the race happened to fire in the other direction.
3. **Is there a causal path?** No. `git diff --name-only 8725b65..da68b5f` touches no
   migration, no `tool/`, no schema bootstrap, and no `packages/**`. The
   `$_activeIndexName` index it collides with comes from the untouched bootstrap.
   `ProductRegistryEngine`, `PostgresProductRegistryStore` and the test file itself
   are all untouched by the whole branch. D-4 calls `engine.recordGeneratedCredential`
   directly — no `CredentialKeyService`, no endpoint, no provider, no verifier. The
   only conceivable path is **timing**: the branch adds a 20th pooled `withServerpod`
   file, which raises connection and scheduler pressure and can shift the
   interleaving. That is a scheduling effect, not a semantic one, and the direction
   of my two runs is decisive — D-4 failed at base and passed at HEAD on the same
   machine on the same day.

**So the dispatch's premise is wrong, and in the lane's favour.** There is **no new
failure relative to base.** The correct statement is: *base is `+170 -2` to `+171 -1`
depending on whether D-4's race fires; HEAD is `+190 -1` to `+189 -2` for the same
reason; the delta attributable to this change is zero.* An unexamined "pre-existing"
claim would have been a way to launder a regression — I examined it, and it holds.

**This lane's own 19 integration tests all pass.** Zero `[E]` lines for
`credential_key_service_postgres_test.dart` in the HEAD run, and the reporter emits
a per-test `[E]` for every other failing file in that same run.

**Gate summary, all re-run by me at `da68b5f`:**

| Gate | Command | Result | Report claim | Verdict |
|---|---|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | `Formatted 655 files (0 changed)`, exit 0 | same | MATCHES |
| analyze | `dart analyze apps/server` | `No issues found!`, exit 0 | same | MATCHES |
| schema | `bash apps/server/tool/verify_schema_bootstrap.sh` | 21 checks, all OK, exit 0 | same | MATCHES |
| tests (non-DB) | `dart test` × 4 files | `+56: All tests passed!` | `+56` | MATCHES |
| tests (DB) | `make test-integration` | `+190 -1`, sole failure dogfood | `+189 -2` best of 5 | MATCHES in substance |
| tests (DB) base | `make test-integration` in a primary clone at `8725b65` | `+170 -2`, **incl. D-4** | `+171 -1` | **differs — and §7 explains why the report's figure is not wrong, just incomplete** |

**M-1 reconciliation — accepted.** The arithmetic is sound and I can confirm the
mechanism: a `withServerpod` file whose `setUpAll` throws reports **one** failure
for the whole file and **none** of its tests, which is why a cascade *reduces* the
passing count while inflating the failure count. `108 + 10 = 118` against
`171 + 1 = 172` is a 54-test shortfall, exactly the shape. Withdrawing `+108 -10`
rather than explaining it away is the right call, and so is publishing the
cascade-polluted runs instead of only the best one. I add one correction of my own:
the corrected base figure is **not** a single number but a **range**, because D-4
is flaky at base too (§7). `+171 -1` is the optimistic end of it.

---

## 6. M-4 — a tested seam is not a substitute, because there is no unmet requirement

I re-read the governing clause at `docs/adr/0018-per-product-git-credentials.md:232-234`:

> "Fallback selection is a **recorded precondition**, not a silent default."

**The ADR says nothing about startup.** The requirement is that the choice be
recorded rather than silent. That is satisfied today, and I verified the mechanics:

- `resolveSecretProvider` has **no default branch at all**. Unset, blank and
  unrecognised all throw `SecretProviderNotConfiguredException` naming the variable
  and the accepted ids. There is no `?? local_file` anywhere in the repository, so
  the fallback cannot be selected silently — it is not reachable without an
  explicit `SHIPIT_SECRET_PROVIDER=local_file`.
- Whenever the fallback **is** selected it is recorded: at `warning`, under
  `credential.secret_provider.fallback_selected`, with `isDocumentedFallback=true`,
  `selection: explicit (SHIPIT_SECRET_PROVIDER=local_file)`, and a defaulted
  directory recorded separately from a configured one.
- That recording happens **before any key can be minted** — `_provider(session)`
  consults the resolver, which logs during resolution, and the service is only
  reached afterwards.

So the ADR clause is met. **"At startup" was a dispatch requirement, not an ADR
one**, and my prior review already recorded it as a routing item rather than a
merge condition. The correction has made the residual *smaller* rather than
papering over it: `CredentialEndpoints.recordCustodyPrecondition(Session)` (`:105`)
is a named, tested seam; an unset substrate returns a marker whose `describe()`
says `resolved: false` and which **throws on any use** rather than inventing a
provider — the correct failure direction, because inventing one there is precisely
the silent default the ADR forbids. Both are tested against real Postgres
(`credential_key_service_postgres_test.dart:677-721`).

**Verdict: M-4 does not block.** The structural reason the implementer gives is
also correct and I checked it: the destination is a Serverpod *session* log, a
session does not exist at process start, and `apps/server/lib/server.dart` is
outside the dispatch's `OWNED_PATHS` — taking it would have been the ownership
violation, not the fix. The outstanding work is one line in `run()`, correctly
routed as an `AUTOMATION_OPPORTUNITY`.

**Residue that must be tracked, and is real:** a deployment that never mints a
credential records nothing, so an operator cannot answer "is QA running on the
fallback?" from the log at all in that state. That is an operational gap worth a
line in `WORK_STATE.md`. It is not a merge condition and it violates no clause.

---

## 7. M-5 / M-6 — the partial states are acceptable to merge with residue tracked

**M-5.** The prior report's "This closes a recorded gap" is **withdrawn by the
implementer**, correctly — the provenance of the confirmed value is unchanged by
anything here. What the correction adds is real and I verified all four layers:
`kHostKeyConfirmationProvenance` is a published `const` and a **required** field of
`AccessVerification` present in the response whitelist (`credential_endpoints.dart:209`
logs it, `credential_key_service.dart:147-158` returns it);
`_validatedConfirmer` bounds empty / >128 / control-character values on both
attribution fields; and the statement appears on the method, on the service, and at
the HTTP boundary. The test drives a real `HostKeyNotPresentedException` and asserts
the wire says `operator-asserted` and `not authenticated by the server`.

**Do not block.** Binding the confirmation to something the server obtained needs
an out-of-band transport, which is a product decision. Blocking would require this
lane to invent one. **F-1 below is the residue that *is* in this lane's ownership
and should be closed in a follow-up.**

**M-6.** The correction did the part it could and made it structural. I verified the
enforcement at `credential_key_service.dart:238-249` and the test
(`:729-760`): `_RenamingSecretProvider` returns
`projects/p/secrets/<ref>/versions/1`, the mint is refused, the refusal carries **no
ARN** (asserted), and **no row is written** (asserted against a real Postgres). So
`MintedCredential.referenceName` is provably
`GIT_REPOSITORY_<sanitised repositoryId>_SSH` — a pure function of an input the
caller just supplied — and a future adapter returning an ARN breaks loudly instead
of leaking quietly. The comment that was the finding (`"Not the material; §13a by
name, never by value"`) is gone, replaced by one that states the residual risk in
`9417f8bf`'s own terms and names G-7's owner.

**Do not block.** Choosing an opaque handle vs the raw reference is an
architecture/product decision owned by `design-agent`. This lane's contribution —
turning "our two adapters happen to return a bare name" into an enforced property —
is exactly the right division. **One narrow observation, not a finding against the
code:** on the handle-contract failure the `on Object` handler calls
`_destroyOrphan(referenceName)` with the **bare** reference, which for a real GCP
adapter deletes the whole secret — including any live credential's half. That path
is unreachable with the two shipped adapters (both return the bare name), and the
alternatives are worse (leak the ARN, or silently skip cleanup), so I record it as
a note for whoever implements the rotate path.

---

## 8. No weakened tests — VERIFIED

| Check | Result |
|---|---|
| Test files deleted vs base | **none** — `comm -3` over `git ls-tree` for `apps/server/test` shows five files, all with a leading tab, i.e. all **added** |
| `@Ignore` / `@Skip` / `excludeTags` / `only:` / `tags:` / `@TestOn` / `@OnPlatform` introduced anywhere in the branch | **none** |
| The only `skip:` in `apps/server/test/**` at HEAD | `credential_keypair_test.dart:349`, the pre-existing conditional ssh-keygen guard (was `:247`; the file grew above it) |
| Is that skip active here? | **No.** The guard is `probe.exitCode != 127`; I ran `ssh-keygen -l -f /dev/null` and got **255**, so `_hasSshKeygen == true` and the OpenSSH proofs execute |
| Assertions deleted or loosened | none. I read every deleted line in `apps/server/test/**` (38 lines total): 15 are the mechanical consequence of `privateSeed` becoming a `SecretBytes` and `privateKeyPem` being removed, 6 are `utf8.encode`/`utf8.decode` wrapping of the now-bytes PEM, 3 are the `_privatePem()` helper, 1 is `resetCustodyForTesting()` (deleted as **unused** — narrowing, not weakening), and 1 is a wrapper-text proxy replaced by a **stronger** assertion |
| Net test growth | non-DB **37 → 56**, integration **12 → 19** — independently counted from `git show`, matching the report exactly |
| All of this lane's tests pass | `+56` non-DB; **zero** `[E]` lines for `credential_key_service_postgres_test.dart` in the HEAD DB run |

The L-8 change is worth calling out because it is the shape of a *strengthening*
rather than a loosening: the stub `git` now **reads `known_hosts` out of the
generated wrapper and reports its contents**, and the test asserts the confirmed key
is present, the unconfirmed key is **absent**, and the file has exactly **one**
non-empty line. "The right key is somewhere in there" is no longer good enough.

---

## 9. Not-fixed list — all five confirmed, all five reasons hold

Nothing was silently dropped. Each is stated in the report's §8 table with a reason,
and I checked each independently.

- **M-2** (pool-lock cascade). Not fixed, out of ownership. The fixes are
  `docker/compose.test.yaml` `max_connections`, the Makefile, or a dedicated
  database — all `docker/**`/Makefile, all prohibited. **I could not reproduce the
  cascade: zero pool-lock occurrences in both of my runs.** The underlying hazard
  is real in principle — the branch adds a 20th pooled `withServerpod` file — but
  I did not measure it firing, so I record it as plausible and unquantified rather
  than as a demonstrated contribution. Reason holds.
- **M-7** (discoveries not persisted). Confirmed: `git diff --name-only
  8725b65..da68b5f | rg docs/` → **empty**. `docs/engineering/**` is outside this
  dispatch's `OWNED_PATHS`. Classified-and-reported is the correct behaviour for a
  lane that may not write there; this is a Manager-owned persistence step.
- **L-4** (no revoke endpoint). Confirmed: `credential_endpoints.dart` has exactly
  two endpoint methods, `generate` and `verifyAccess`; there is no revoke/destroy
  method. Adding one requires `serverpod generate`, which rewrites
  `packages/control_plane_client` (the next client lane's, and unowned) and
  `lib/src/generated/**` (`READ_ONLY`). **The reason is structurally correct** — the
  dispatch prohibited the only tool that could fix it.
- **L-5** (root `pubspec.lock` outside `OWNED_PATHS`). Confirmed unchanged: no
  `pubspec` entry in `315e9ca..da68b5f`. Not fixable retroactively; the next
  dispatch's `OWNED_PATHS` should name the root lockfile.
- **L-6** (unrelated nullability drift in the regenerated test tools). Confirmed:
  `serverpod_test_tools.dart` is **not** in the correction diff. The reason is
  correct and I endorse it: the correction is a new commit, and rewriting `315e9ca`
  would destroy the provenance this whole re-review rests on. Correctly carried
  forward in the commit message so the next `product_registry` reviewer is not
  surprised.

---

## 10. Findings — none blocking

**F-1 — MEDIUM, non-blocking. `hostKeyFingerprint` is unbounded, and it reaches a
Postgres-persisted log line.**
This is the residue of the M-5 correction, and it is the incomplete application of
a hardening the same commit performed. `_validatedConfirmer` bounds `confirmedBy`
and `checkedBy` for exactly this reason — the correction's own comment calls a
control character "a forge-the-previous-entry primitive" — but
`credential_key_service.dart:335` and `:348` pass `hostKeyFingerprint`
**unchanged**. It then reaches `HostKeyNotPresentedException(confirmedFingerprint:
hostKeyFingerprint)`, whose `secretlessDescription`
(`repository_access_verifier.dart:176-180`) interpolates it verbatim. That type is
an `AuditedFailure`, so `secretlessText` **forwards** it, and
`credentialFailureLogFields` writes it to the session log, which
`config/test.yaml` persists to Postgres.

I demonstrated it rather than arguing it. Driving the real verifier with
`hostKeyFingerprint: 'SHA256:AAAA\n[credentials] credential.verify_access.completed ok'`:

```
THROWN_TYPE=HostKeyNotPresentedException
DESCRIPTION_CONTAINS_NEWLINE=true
DESCRIPTION_CONTAINS_FORGED_MARKER=true
```

Note the asymmetry: `confirmedBy` is bounded and reaches only a **column**;
`hostKeyFingerprint` is unbounded and reaches an **exception message and therefore
the log**. The stored column is safe (a match requires exact equality with a
fingerprint this code computed, so the *persisted* value is the code's, not the
client's), which is why I rate this MEDIUM and not HIGH.
**Fix, in the lane's own file:** run `hostKeyFingerprint` through the same shape
check — at minimum reject control characters, ideally bound length and character
set — either by widening `_validatedConfirmer` or by adding a sibling validator. Do
not block the merge on it: it carries no key material, it violates no ADR 0018
clause, and it is a 3-line fix. But the M-5 hardening should not be described as
complete until it is closed, and the next credential change must not build on the
assumption that it is.

**F-2 — LOW/MEDIUM. The source guard's real scope is narrower than the in-code doc
claims, and I found a bypass.**
`secret_provider.dart:52-56` states the guard "fails if any
`SecretStoreException(` argument block grows a `$`". It does not. The test
(`secretless_error_test.dart:246-294`) fails only when the `reason:` argument block
interpolates a **name bound in a `catch (…)` in the same file**, and only for a
**multi-line** `SecretStoreException(` call site. Two escapes follow: a one-line call
site, and any helper. I demonstrated the second — replacing
`reason: secretlessText(error)` with `reason: _leak(error)`, where `_leak` is a
top-level `String _leak(Object error) => 'store failed: $error'`:

```
00:02 +9: All tests passed!
```

The guard passes while the caught error's message flows into a durable record
verbatim. This matters more than a normal test-coverage gap because
`SecretStoreException` **is** an `AuditedFailure`, so the type gate does *not*
catch this shape — the source guard is the only net for it, and its only net is
narrower than advertised. The report's §2.5 wording is accurate; the in-code doc is
not.
**Fix (both, in owned files):** correct `secret_provider.dart:52-56` to state the
real scope, and either broaden the guard (reject any `$` or any call argument in a
`reason:` block) or add a positive assertion that a `SecretStoreException.reason`
contains no fragment of the material the adapter handled. The report's own
`WORKFLOW_IMPROVEMENT` note — "a source-level audit is cheap executable knowledge" —
is right; the audit just needs to cover the surface it claims.

**F-3 — LOW. `_validatedConfirmer`'s doc asserts something the code does not do.**
`credential_key_service.dart:394-395`: "The value itself is reported back in the
refusal, since it is the operator's own text and they need to see what was
rejected." The code reports `${trimmed.length} characters` and nothing else
(`:406-410`). The code is *stricter* than the doc, so the safe direction — but it
is the same defect class as B-2 (a doc in a security file asserting something the
code does not do), and it is in the file a future reader will trust. One line.

**F-4 — LOW. `SshKeyPair`'s doc overstates its own guarantee.**
`ssh_keypair.dart:74-76`: "There is **no** public accessor that returns the seed as
a `Uint8List` or a `String`." `privateSeed.bytes` is a public `Uint8List` of the
seed. The guarantee that actually matters — that nothing *accidental* projects it,
so `log('$pair.privateSeed')` emits `<secret redacted, 32 bytes>` — holds and is
proven; and the explicit `.bytes` escape hatch is deliberate and greppable
(`secret_material.dart:41-48`). But the sentence as written is false, and B-2 was
blocked for precisely this. Reword to: the only route to the raw seed is an
explicit `.bytes` call, and there are six such sites, all justified. Related: the
doc's "the three sites that genuinely need them" (`:162-163`) is really six
(3 material-producing + 3 in the codec).

**F-5 — LOW. Report §9 states a suppression that does not exist.** It says "the
single `ignore` comment in the diff is `prefer_initializing_formals` on the
`SshKeyPair` constructor, with the reason inline." I grepped: **no ignore comment
was added anywhere in the branch.** The `prefer_initializing_formals` concern was
solved properly — by splitting the constructor into a factory over a positional
generative constructor (`ssh_keypair.dart:97-105`) so the field can be a private
initializing formal, with a comment explaining exactly why. The report's error is
in the conservative direction and the code is cleaner than claimed, but it is a
false statement about the artifact and it should not survive into the record.

**F-6 — LOW. The B-1 justification is wrong in the direction that flatters it.**
Report §2: the class is "closed at three independent levels, because no single one
of them is sufficient on its own." I measured the opposite for level 2. With
Mutation 1 applied (both unguarded decoders reintroduced),
`secretless_error_test.dart` still passes **`+9`** — because `FormatException` is
unaudited, the type gate suppresses its message on its own. So the type gate alone
**would** have blocked B-1's actual leak; only level 1 was strictly necessary, and
levels 2 and 3 are what make the *next* version of this bug fail closed by default.
That is a stronger result than claimed, but the stated reasoning is wrong and a
reader relying on "no single level suffices" would mis-prioritise a future edit that
removed, say, level 3.

**F-7 — LOW, accepted bound, not a defect.** `_descendantPids` reads `ps` *before*
the parent is signalled (correctly, for re-parenting), which leaves a window of
microseconds in which `git` could fork an `ssh` that is not in `tree`. Such a
process would survive. This is practically unreachable for `git clone`, which forks
`ssh` once at transport start and not again while blocked in a network read; and
`_descendantPids` returns empty rather than throwing when `ps` cannot answer, so the
code degrades to killing the direct child rather than skipping the kill — the right
degradation. Recorded because a `ps`-walked tree kill is inherently a snapshot, and
a future reader should know that.

---

## 11. What I judge genuinely strong

- The type gate is the right shape for this problem. "A new failing path is silent
  by default rather than leaky by default" converts a review-time convention into a
  structural property, and it is enforced at the **type** level rather than by
  call-site discipline — which is the only thing that survives the next contributor.
- `redactUnauditedFailure` at the boundary closes the half of B-1 I was about to
  raise: an endpoint's own logger is not the only sink, because Serverpod also logs
  what escapes a handler. Substituting (not forwarding) is correct, and not
  retaining the original is what makes it irreversible downstream.
- The `reason: '$error'` → `secretlessText` change in the local adapter **preserves
  the diagnostic** — path, mode, OS message — while `ProcessException.arguments`, the
  one field that could carry something, is deliberately not read. That is a
  considered trade, documented at the call site.
- Every decode site in the GCP adapter now fails typed, `is` rather than `as`, and
  `_googleMessage` has its own guarded parse returning a literal. The class is
  closed consistently, not at the two lines B-1 named.
- Deleting `String get privateKeyPem` **at the root** rather than confining it at
  the call site, with the class doc updated to name the hole it used to deny — the
  report's own wording ("was the exact hole this doc used to deny existed") is the
  right way to record it.
- The M-3 test proving the fix with a **grandchild** is the correct instrument, and
  my fifth mutation confirms it discriminates: a direct-child kill passes, and only
  a tree walk fails. That is the difference between "the fix works" and "the test
  is decorative", and it is the one thing the dispatch most needed.
- The report **withdrew** its own overstated claims twice — "This closes a recorded
  gap" (M-5) and `+108 -10` (M-1) — and published cascade-polluted runs rather than
  only the best one. An implementer that corrects its own evidence is doing the part
  of the job that matters.

---

## 12. Verdict

`APPROVE_CORRECTIONS`.

**Both blockers are genuinely resolved, not merely claimed.** B-1 is closed by a
type-level gate that I traced onto the exact path Serverpod uses for unhandled
errors, and whose third instance is correctly scoped — `addVersion` is verifiably
the only request carrying material. B-2 is closed at the root: no `String` projection
of private material survives anywhere in production code, the class doc matches the
code, and the two test-file paths that would have printed a deploy key on failure
now assert on booleans. M-3 is closed on the **timeout** path with a tree kill
proven by a grandchild.

**The mutation proof is real.** I reproduced all four claimed negative checks plus a
fifth of my own, and every one failed the corresponding test. This is the difference
between "the fix works" and "the test is decorative", and here the tests are
load-bearing.

**The gate is red for pre-existing reasons only, and I have stronger evidence than
either prior report.** D-4 fails at `BASE_SHA` in a primary clone with zero
pool-lock occurrences — the same failure mode, in a file this branch never touches,
with no migration, schema, engine or `packages/**` change to provide a causal path.
**There is no new failure relative to base; the dispatch's premise of one was wrong,
and the lane is right.** The corrected base figure is `+170 -2` on my machine and
`+171 -1` in all three earlier runs, because D-4 is flaky at base in both directions.

**No test was weakened, skipped, filtered or deleted.** Net growth 37 → 56 non-DB and
12 → 19 integration, independently counted. The single `skip:` is pre-existing and
does not fire.

**The not-fixed list is complete and every reason holds**; L-6's reason is not merely
convenient but structurally correct, since rewriting `315e9ca` would destroy the
provenance this re-review rests on.

**Six findings are recorded, none blocking.** F-1 (MEDIUM) is the one I would fix
first and it is the residue of M-5's own hardening: `hostKeyFingerprint` is passed
unchanged into an exception message that reaches a Postgres-persisted log line,
which I demonstrated, while the sibling field `confirmedBy` was bounded for exactly
that reason. It carries no key material, violates no clause this review enforces,
and is a three-line fix in an owned file — so it does not hold the merge, but the
M-5 hardening should not be called complete until it is closed. F-2 (LOW/MEDIUM) is
a guard whose in-code doc overstates its scope, with a bypass I reproduced; F-3
through F-7 are documentation inaccuracies and one accepted bound, two of which are
errors in the report rather than in the code.

**The central question, unchanged from the last review, is now answerable
affirmatively:** private-key material cannot reach an HTTP response, a log, the
database, an exception message, or disk surviving the call.
