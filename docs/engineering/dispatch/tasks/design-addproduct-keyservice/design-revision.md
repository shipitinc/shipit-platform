# Design Revision 1 — server-side deploy-key service + `hostUnrecognised` trust state

**Revision ID**: `46980EE0-E638-409C-A7D3-E1B9399FECE5`
**Brief ID**: `97484D0E-E16C-485E-BAA2-A277889C0FB6`
**Status**: DRAFT
**Risk level**: 3
**Worktree**: `/private/tmp/shipit-design-addproduct-keys` · **Branch**: `design/addproduct-keyservice` · **Base SHA**: `77c19f1`

Scope: human points **2a, 2b, 2c, 2d** only. Points 2e/2f and all four mobile Penpot boards belong to
`design-addproduct-mobile`. This revision creates and edits no board.

---

## 0. Two questions this revision deliberately does **not** answer

`R-R1` is explicit: *"I have NOT approved the at-rest protection model for the server-stored private
half. Surface it as a decision at Gate D4; do not default it."*

| # | Open question | Where | Status |
|---|---|---|---|
| **OPEN-D4-1** | **At-rest protection model** for the server-stored private half — substrate, degraded-mode behaviour, revocation disposal, client exposure of the reference | § R-1 | **`OPEN — HUMAN DECISION REQUIRED AT GATE D4`** |
| **OPEN-D4-2** | **Registration ordering** — when the `Product`/`RepositoryReference` rows are created, given that minting a credential *requires* them | § R-1.6 | **`OPEN — HUMAN DECISION REQUIRED AT GATE D4`** |

OPEN-D4-2 was **not** in the dispatch brief. It was found by reading the engine: it is a provable
circular dependency between human point 2b and the existing domain, it changes which user flow is
authoritative, and no design agent may settle it. Every section below is written so that **the
service interface is identical under either resolution of OPEN-D4-2**; only the *trigger* moves.

Everything else in this revision is normative and needs no human decision.

---

## R-1 — At-rest protection model — `OPEN — HUMAN DECISION REQUIRED AT GATE D4`

### R.1 What is already decided, and therefore not re-opened here

`DEC-b869ec24` (RESOLVED, ARCHITECTURE, OPTION_A) settles *where* the private half lives: **server-side,
generated and stored by a server capability, exposed to the browser only as the public half.** That is
architecture and it is settled. What it left open — and what the human has explicitly reserved — is
*how the server protects it at rest*.

### R.2 What the existing domain already constrains (independent of the decision)

Three constraints hold under **every** option below, because they are structural, not preferences:

1. **The private half never enters `packages/product_registry`.**
   `product_registry_engine.dart:901-905` states it outright; `:933-939` enforces it by rejecting any
   `publicKey` containing `PRIVATE KEY`; `credential_test.dart` group *"no key material reaches the
   domain"* locks it. The key service therefore lives in `apps/server/**` (or a new package), never in
   the registry engine.
2. **`RepositoryCredential` never gains a key-material field.** Its doc (`:12-18`) and `C-04` forbid it.
   A substrate that stores ciphertext *in the database* (§ R.4 A2) must therefore use a **separate
   table/type**, not a new column on `product_credential` — otherwise the invariant the existing test
   suite protects is broken.
3. **The private half is immutable per credential.** `copyWith`
   (`repository_credential.dart:137-172`) cannot change `referenceName`, `publicKey`, `fingerprint`,
   `algorithm` or `credentialId`. So "where the private half lives" is decided **once, at mint**, and
   cannot be silently repointed later. Changing the substrate for an existing key requires rotation —
   which is exactly the behaviour a key store should have.

### R.3 Reconciling `referenceName` — the design agent's decision

`DEC-b869ec24` moves the private half server-side, but `referenceName` is documented as *"Name under
which the private half is held in the local secret store, e.g. `GIT_PRODUCT_<productRef>_SSH`"*
(`repository_credential.dart:70-72`), and the same sentence is repeated in the store interface
(`product_registry_store.dart:38`), the table comment (`repository_credential.spy.yaml:4-6`) and the
wire view (`repository_credential_view.yaml:3-11`).

**Decision (normative, within this design agent's authority — it selects a substrate):** keep the
field, change its documented subject. `referenceName` continues to mean **"a stable reference to the
private half, never the private half"**. What changes is whose store it names: from *the operator's
local secret store* to *SHIP IT's own at-rest store for this credential*. Consequences:

- **No new column.** The column is already `referenceName: String` and already indexed as part of the
  row; the schema is unchanged, so no migration is proposed on this account.
- **No wire-contract break from the field's existence.** Its meaning changes, not its type.
- **`copyWith` immutability becomes a feature**, not a limitation: a credential's key cannot be
  repointed at a different store without rotation, which is the safe behaviour.
- **The engine's `referenceName` parameter keeps its name and position.** `recordGeneratedCredential`
  already takes it (`product_registry_engine.dart:915`) and already refuses key material passed as
  `publicKey`; the key service passes the store reference there.

**Rejected alternatives, with reasons:**

| Alternative | Why rejected |
|---|---|
| Add a second column `privateKeyRef` beside `referenceName` | Two references to one key, no way to tell which is authoritative, and `referenceName`'s contract is explicitly singular |
| Drop/null `referenceName` | Breaks the non-null `referenceName: String` on the domain type, the store, and the table; discards the only record of where the key is. Requires a migration for no gain |

**Explicitly still open:** whether `referenceName` may continue to reach the client. That depends on
the substrate (§ R.4 A4 consequence) and is part of OPEN-D4-1, not settled here.

### R.4 Q1 — storage substrate — `OPEN`, 4 atomic options

Each is independently selectable and self-contained.

#### A1 — Filesystem, mode `0600`, outside the repository tree

The private half is written to a path held under a dedicated directory outside the work tree, owned by
the server's service user, mode `0600`, on a volume not otherwise shared with application code.
`referenceName` = a path relative to that root.

- *For*: no new dependency; works in the current Compose topology; `DockerFile`/volume layout already
  exists; trivially inspectable by a human debugging a stuck registration.
- *Against*: protection is entirely the host filesystem's. With no volume encryption, a stolen volume,
  a backup, or a `docker cp` yields the key in cleartext. Filesystem permissions do not defend against
  a process running as the same uid — which the git transport is.
- *Blast radius of a mistake*: the whole key store.

#### A2 — Envelope-encrypted ciphertext in a **separate** table

The private half is sealed with a key-encryption key (KEK) and the ciphertext is stored in its own
table, **not** on `product_credential` (see § R.2 constraint 2). `referenceName` = an opaque row
reference. The KEK comes from configuration, never from the database.

- *For*: survives container replacement; the ciphertext is useless without the KEK; backups of the
  database alone no longer disclose the key; keeps rotation transactional with the rest of the store.
- *Against*: adds a migration and a second persistence path; the KEK becomes the single most valuable
  secret in the system and now needs its own rotation story; if the KEK lives in an env file, the
  ciphertext's strength equals the env file's protection; a SQL injection elsewhere in the server
  becomes a key-disclosure path rather than a data leak.
- *Note*: this is the only option that changes the shape of the data layer.

#### A3 — External secret manager / mounted secret (docker secret, Vault, SOPS file)

SHIP IT never writes key bytes at all; it writes a *reference* into the credential and asks the
manager for the material at transport time. `referenceName` = a secret path or ARN.

- *For*: strongest separation — SHIP IT holds a reference and never a value, which is **literally the
  existing contract**, so `referenceName` needs no reinterpretation at all; rotation and revocation
  are manager features; the key never appears in the database or its backups.
- *Against*: adds a runtime dependency that can be unavailable; introduces a new failure mode that
  lands directly on § R.5 (fail-open vs fail-closed); on a single local machine this may be more
  machinery than the problem warrants.
- *This option makes the reference's sensitivity highest*: an ARN discloses vault topology and path
  names, which is why its client exposure is a § R.4 consequence rather than a fixed answer.

#### A4 — OS keychain / hardware-backed keystore on the host

The private half is stored in the host's keychain (e.g. macOS Keychain) or a TPM-backed store, and
read by handle at transport time. `referenceName` = a keychain item label.

- *For*: strongest at-rest property of the four; hardware binding; per-item ACLs.
- *Against*: **feasibility is uncertain in this repository's topology.** SHIP IT runs as a container
  (`docker/compose.yaml`) while the keychain is the *host's*; container→host keychain access is
  awkward and host-dependent, and CI or another machine would have a different store. Per the
  no-Docker-command rule I could not test this; see § Feasibility `UNVERIFIED`.
- *Consequence if chosen*: the "local only" scope in `DEC-570bb640` becomes load-bearing for
  correctness, not just for security posture.

**Question asked at Gate D4 (Q1):** *Which substrate holds the server-stored private half?*
Answer `A1`/`A2`/`A3`/`A4` or a documented alternative.

### R.5 Q2 — what the server does when it **cannot** protect the key adequately — `OPEN`, 2 atomic options

This is the fail-open vs fail-closed axis and it is explicitly the human's.

#### B1 — Fail closed: refuse to mint, say why

If the chosen substrate is unavailable, or the server cannot verify the protection it claims (e.g. the
directory cannot be created `0600`, the manager is unreachable, the KEK is absent), **no keypair is
generated and no credential row is created.** The user is told the concrete remediation.

- *For*: consistent with the codebase's existing posture — `HostKeyStatus.changed` fails closed, and
  the whole credential design rests on *"access is proven, never assumed"*
  (`credential_status.dart:2-5`). It guarantees no key ever exists in weaker protection than the UI
  claims.
- *Against*: a legitimately-configured but unusual host cannot register at all; the user is blocked
  with **no in-flow remedy** — which is uncomfortable given `R-2d`'s finding that blocking users is
  what the human objected to. Note the tension explicitly: refusing is safe, and refusing is also a
  dead end unless the remediation is actionable.

#### B2 — Fail open with a recorded warning: mint anyway

The key is generated and stored; a degradation marker is recorded on the credential; the UI shows a
warning.

- *For*: registration is never blocked; the operator can proceed and fix the substrate later.
- *Against*: a key now exists in weaker protection than the UI implies; the warning is easy to miss;
  there is no enforcement, only a notice — and a notice is not a control. This would be the *only*
  place in the credential design where something is recorded rather than proven, which is precisely
  the property the existing tests exist to prevent.

**Question asked at Gate D4 (Q2):** *When protection cannot be established, does the server refuse to
mint, or mint with a recorded warning?* — **fail closed (B1)** or **fail open (B2)**.

### R.6 Q3 — key lifecycle: rotation, revocation, disposal on revoke — `OPEN`, 3 atomic options

`revokedAt`/`revokedReason` already exist (`repository_credential.dart:115-117`) and
`revokeCredential` (`product_registry_engine.dart:1058-1076`) **never deletes the row** — the
historical *record* stays readable (`credential_test.dart:246`). Nothing currently governs the private
half's *disposal*, which is a different question.

#### C-1 — Destroy the private half on revoke; keep the row

`revokeCredential` additionally destroys the key bytes. The credential row remains, fully readable,
with `status: revoked`, `revokedAt`, `revokedReason` — the audit trail is untouched. Any secret-store
handle is deleted.

- *For*: revocation becomes real; a leaked key stops working at the SHIP IT side immediately; nothing
  in the design requires the key bytes to survive, only the record.
- *Against*: an old credential cannot be re-verified after revocation; a forensic re-check is impossible.
- *Note*: the existing test *"revoked credentials stay readable, never deleted"* asserts the **record**,
  so C-1 does not contradict it.

#### C-2 — Retain the private half; revocation is a logical flag only

- *For*: forensic re-verification stays possible; simplest implementation.
- *Against*: `revoked` becomes a label that does not correspond to a security property; the key stays
  usable until removed at the host, so the operator's mental model ("revoked") is misleading.

#### C-3 — Retain for a grace period, then destroy

- *For*: supports rollback of an accidental revocation and a bounded forensic window.
- *Against*: requires a background job and a durable schedule; the grace period is a new tuning
  parameter nobody has justified.

**Question asked at Gate D4 (Q3):** *On revocation, is the private half destroyed (C-1), retained
(C-2), or retained for a grace period then destroyed (C-3)?*

**Rotation is not open.** It is already specified: `rotateCredential`
(`product_registry_engine.dart:1084-1119`) revokes the old credential, records
`supersedesCredentialId`, and creates a new one; host confirmation does **not** carry over, so the new
key re-enters `hostUnrecognised` by design. Covered by `credential_test.dart:221`.

### R.7 Q4 — is the private half readable by any process other than the git transport? — normative

Stated as a constraint rather than a choice, because every option in § R.4 and § R.5 must satisfy it
and it is the property that makes them comparable:

- The private half **must never** be returned by any endpoint, serialised into any wire type, logged,
  included in an exception message, or exposed to a Serverpod `Session`.
- It is readable **only** by the key-transport component, immediately before a transport attempt, for
  the minimum time needed, and never cached in a long-lived field.
- Every read is an auditable event. `AuditEntityType.productCredential` already exists
  (`packages/platform_contracts/lib/src/enums/audit_entity_type.dart:8`), so the audit sink is reusable.

**Honest status: this is currently unenforceable.** There is no transport seam to constrain
(§ Feasibility), `Serverpod` sessions are the ambient authority in every existing endpoint, and the
redaction discipline is not demonstrable from source today. What the design commits to is the
**interface** — key material crosses exactly one component boundary — and states that enforcement
requires that boundary to be built and reviewed. This is tracked as an implementation-time obligation,
not as a delivered property.

### R.8 Recommendation, evidence, risk (required by `R-R1`; **not** a decision)

The human asked for options and did not ask me to choose. Recorded as a recommendation only.

| Sub-question | Recommendation | Confidence | Evidence behind it |
|---|---|---|---|
| Q1 substrate | **A3** if a secret manager is already reachable in the target topology; otherwise **A2** with a KEK whose rotation is explicitly owned | MEDIUM | A3 preserves the existing "referenced by name, never by value" contract verbatim (`repository_credential.dart:12-18`), which is the design's strongest existing property. A2 is the strongest option that stays inside the current transactional store. I could not test A4's container→host feasibility under the no-Docker rule, so I do not recommend it. |
| Q2 degraded mode | **B1 (fail closed)**, and only if the error names a concrete remediation | MEDIUM | `HostKeyStatus.changed` already fails closed (`credential_status.dart:49-50`) and `confirmHostKey` records-then-refuses (`engine:992-1002`). B2 would introduce the single unproven-but-recorded state the credential design otherwise excludes. |
| Q3 revocation disposal | **C-1 (destroy)** | MEDIUM | `revokeCredential` retains the row for audit (`engine:1056-1057`) and the existing test asserts the record, not the key; C-1 makes `revoked` mean what it says without touching the audit trail. |
| Q4 transport exposure | The single-boundary constraint in § R.7, enforced by construction rather than by review | LOW | There is no SSH transport seam today (§ Feasibility), so any enforcement claim today would be unverified. |

**Risk of getting this wrong**: under-protecting a repository write key (§ R.5 A1) leaks the key;
over-blocking (§ R.5 B1) reintroduces exactly the "stuck and unable to register" outcome the human
objected to in point 2d, which is why B1's remediation text is a design obligation and not a nicety.

---

## R-2 — The `hostUnrecognised` trust state, with no Cancel (`R-2d`)

### R.9 State machine — grounded on the existing `HostKeyStatus`

`HostKeyStatus` (`credential_status.dart:41-50`) is `unknown | confirmed | changed` with
`permitsConnection` true only for `confirmed`. The design **reuses it unchanged**; `hostUnrecognised`
is the *client-side name for the server's `unknown` value*, not a new enum member.

```
                  (credential minted, no fingerprint recorded yet)
                                    │
                                    ▼
        ┌───────────────────  hostUnrecognised  ────────────────────┐
        │   hostKeyStatus = unknown                                │
        │   permitsConnection = false                               │
        │   user has seen: host name + fingerprint to confirm       │
        │   user has NOT seen: any cancel / reject / skip control  │
        └───────────┬──────────────────────────┬───────────────────┘
                    │ "Trust this host"         │ navigate away
                    │ (confirmHostKey,          │ → Products page
                    │  confirmedBy = actor)     │   state PERSISTS
                    ▼                           │
        ┌────────────────────────┐             │
        │  hostConfirmed         │             │
        │  hostKeyStatus=confirmed│            │
        │  permitsConnection=true │             │
        └───────────┬─────────────┘             │
                    │                           │
                    │ "Check access"            │
                    ▼                           │
        ┌────────────────────────┐             │
        │ checkSucceeded /       │             │
        │ checkFailed            │             │
        └────────────────────────┘             │
                                                  
        ┌────────────────────────┐  confirm a DIFFERENT fingerprint
        │  hostKeyChanged        │◀──────────────────────────────────┐
        │  hostKeyStatus=changed │                                   │
        │  permitsConnection=false│  (also reachable by the transport│
        │  FAILS CLOSED           │   itself presenting a new key)     │
        └────────────────────────┘                                   │
                                                                    │
        On re-entry: hostUnrecognised ──────────────────────────────┘
```

### R.10 Normative requirements for the trust step

- **N-1 — There is no Cancel affordance.** The trust step exposes **no** control that rejects,
  dismisses, defers, skips or cancels the host confirmation. Not "Cancel", not "Not now", not "Skip",
  not "Dismiss", not a swipe-to-dismiss, not a back gesture *on the trust panel itself*. **Rationale**:
  the human's point 2d — a cancel affordance creates a path to a dead end where the product can never
  be registered, because `canRegister` requires the host half and there is no other way to reach it.
  **Why that is the right trade**: `DEC-b869ec24` records the human's own reasoning that the user is
  not actually stuck — the Products page is always reachable and the key persists for later
  verification (§ R.12) — so the *absence* of an escape control on the panel costs nothing, while its
  *presence* manufactures the dead end.
  **Consequence for the implementer**: reintroducing a cancel control is a defect, not a variant.
  `SC-06`/`AC-05` make it testable.
- **N-2 — Navigation away is navigation, not cancellation.** The back link and the bottom nav leave the
  step. They do not set, imply or record any negative host state. Leaving is always safe and always
  reversible.
- **N-3 — The step is blocking.** While `hostKeyStatus != confirmed`, "Check access" and "Register
  product" are both unavailable. This is not a client preference: `recordCredentialCheck` refuses a
  non-permitting host outright (`engine:1033-1038`), so a check before trust has no result to record.
- **N-4 — The user is asked to confirm out of band, and the copy must say so.** The step shows the
  host name and the fingerprint **the server actually observed**, and instructs the user to verify it
  through a second, independent channel before trusting. The wording must not imply SHIP IT verified
  the host: `credential_status.dart:38-40` states *"SHIP IT cannot verify a host on the operator's
  behalf and does not claim to"*, and the UI must preserve that honesty.
- **N-5 — Confirmation is attributable.** The confirmation records *who* confirmed
  (`confirmedBy`), because trust-on-first-use is a human decision; `confirmHostKey` rejects an empty
  `confirmedBy` (`engine:983-988`) and `credential_test.dart:146` locks it.
- **N-6 — `changed` gets a user-facing path and is never auto-retrusted.** `changed` fails closed and
  is indistinguishable from interception (`credential_status.dart:49-50`). The UI must present it as
  a security stop — this host's key is not the one you confirmed — and must **not** offer a
  one-click "trust anyway". Recovery is out-of-band verification plus an explicit, separately-recorded
  re-trust (a deliberate act, attributable), or rotating the credential. There is **no** cancel
  affordance here either; the same `N-1` rationale applies, and a `changed` host has strictly less
  reason to offer an escape hatch than an unknown one.
- **N-7 — The confirmation is durable.** Once recorded, `hostConfirmedAt`/`hostConfirmedBy` persist and
  are surfaced by `RepositoryCredentialView` (`repository_credential_view.yaml:24-25`); re-entry must
  not re-prompt.

### R.11 Client state model — two orthogonal axes

The client's single `AccessStatus` (`add_product_page.dart:239`) conflates two server concepts that
the domain keeps separate, and cannot express `hostUnrecognised`. The design splits them:

| Axis | Type | Source | Members |
|---|---|---|---|
| Credential usability | `AccessStatus` (**kept, unchanged**) | mirrors `CredentialStatus` | `notGenerated \| notChecked \| checking \| verified \| failed` |
| Host trust | `HostTrustStatus` (**new client enum**) | mirrors `HostKeyStatus` 1:1 | `unknown \| confirmed \| changed` |

`HostTrustStatus` is genuinely new on the client — `grep -rn "hostUnrecognised\|HostKeyStatus"` over
`apps/control_plane/lib` returns nothing — and mirrors a server enum that already exists, so it adds
no domain vocabulary. `AccessStatus` keeps its five members so no client wire contract changes.

**`canRegister` becomes two-factor**, mirroring the server's own `canReachRepository`
(`repository_credential.dart:128-129`) rather than the current single-factor check:

```
canRegister = productName.isNotEmpty
           && repositorySshUrl is valid
           && credentialId != null
           && hostTrustStatus == confirmed
           && accessStatus   == verified
           && !isRegistering
```

This is human point 2b expressed as code, and it fixes the current defect that `canRegister` consults
only one half and is consequently never satisfiable.

### R.12 The way out — traceable to a field and a read path (`R-H2`)

`DEC-b869ec24` records the human's promise: *"if when down the road we want to create that product
we'll find the key on the machine ready to be verified again."* That promise is only credible if the
key survives navigation and is re-readable. It is, and here is the exact mechanism:

| Claim | Field | Read path |
|---|---|---|
| The credential survives navigation | `product_credential.credentialId` (row persists; nothing on the page-exit path deletes it) | `ProductRegistryEngine.readActiveCredential(productId, repositoryId)` → `ProductRegistryStore.readActiveCredentialForRepository(repositoryId)`, which **excludes revoked** (`product_registry_store.dart:46-50`) |
| "The key is still there" | `product_credential.publicKey` — **already a column** (`repository_credential.spy.yaml:20`) | Re-copying after re-entry is a pure **read** of that column. It never regenerates. |
| The key is still the same key | `product_credential.fingerprint` | Returned by `DeployPublicKeyView` and by `RepositoryCredentialView` |
| Host trust survives too | `hostKeyStatus`, `hostKeyFingerprint`, `hostConfirmedAt`, `hostConfirmedBy` | Surfaced by `RepositoryCredentialView` (`:24-25`) |
| The user is not blocked | `ProductState.registered` semantics | A registered product needs no credential to *exist* — `registered` is "no baseline, no governance, no work" (`product_state.dart:29-32`) |

**The precise mechanism, in one sentence**: on re-entry the page reads the active credential for the
repository and restores the public key, fingerprint and host-trust state from `product_credential`;
because generation is *get-or-create* (§ R.13) and `copyWith` cannot change `publicKey`, the restored key
is byte-identical to the one the user installed — which is the same mechanism that kills B6.

**This row depends on OPEN-D4-2.** If the `Product`/`RepositoryReference` rows exist when the user
leaves (option 1) the read path above is exact. If they do not, the credential cannot exist at all
today, because `recordGeneratedCredential` requires them — so "the key persists" is only true under
option 1 or 3. Stated rather than smoothed over.

---

## R-3 — "Check access" (`R-2c`) and the structural kill of B6

### R.13 The normative definition

> **Check access** performs exactly one real SSH transport attempt to the repository's host, using the
> private half stored for **this** credential, and records the outcome. It generates nothing, installs
> nothing, and changes no host-trust state.

| Question | Normative answer |
|---|---|
| What does it attempt? | One authenticated SSH transport to `host`, proving the stored key is accepted for the repository |
| Against which host? | `RepositoryCredential.host`, derived from `RepositoryReference.uri`. Mint refuses if a host cannot be derived (a trust decision with no host to trust is not a trust decision) |
| With which credential? | Exactly the `credentialId` the client already holds. **Never** a fresh keypair |
| What does success prove? | The key is installed and accepted, **and** the host presented the fingerprint that was confirmed. That is why host confirmation is a precondition, not a parallel step |
| What does it *not* prove? | Nothing about the user's typing, the product's baseline, or that work is approved. Registering is not governing (`add_product_page.dart:644`) |
| Is it repeatable? | Yes. N presses → N recorded check outcomes on the **same** `credentialId`, and **one** `product_credential` row |

### R.14 Outcome taxonomy

Each failure class maps onto the **existing** domain vocabulary — `CredentialStatus.failing` +
`lastFailureReason` (`engine:1047-1051`) — so no new domain enum is introduced. `failureKind` is a
**presentation-layer** wire enum, justified because the client must show different copy per cause.

| `failureKind` | Detected how | State transition | User sees |
|---|---|---|---|
| `hostUntrusted` | `!hostKeyStatus.permitsConnection` — no transport attempted (`engine:1033-1038`) | **none** (the transport was never attempted, so there is no result to record) | Route to the trust step: "Confirm this host's key first." |
| `hostKeyChanged` | Transport presented a fingerprint ≠ the confirmed one | `hostKeyStatus → changed`, `hostKeyFingerprint` updated (`engine:992-997`), then **refuse** | Security stop per `N-6` |
| `credentialNotInstalled` | Transport succeeded to the host; the host rejected the key (auth failure / key not authorized) | `status → failing`, `lastFailureReason` recorded | "Install the public key as a deploy key with **write** access, then check again." |
| `networkUnreachable` | DNS/TCP/timeout failure before authentication | `status → failing`, reason recorded | "Could not reach `<host>`." — explicitly *not* "install the key" |
| `revoked` | `status == revoked` (`engine:1030-1032`) | **none** | The credential is withdrawn; rotation is required |

Distinguishing `credentialNotInstalled` from `networkUnreachable` is the whole point of the
requirement: today the only copy is "Access check failed. Ensure the key is installed with write
access." (`:577-579`), which is wrong whenever the network is at fault and sends the user to install a
key they already installed.

### R.15 B6 is structurally impossible — four independent mechanisms

| # | Mechanism | Evidence |
|---|---|---|
| 1 | **Mint is get-or-create, not create.** A second call returns the existing credential's public half with `alreadyExisted: true`. | § R.16 endpoint semantics |
| 2 | **The check path has no call into generation.** `checkRepositoryAccess` reads a credential by id and has no generation step at all. | § R.16 |
| 3 | **The engine refuses a second credential.** `recordGeneratedCredential` throws unless `supersedesCredentialId` matches (`engine:940-947`). | `credential_test.dart:206` |
| 4 | **The key is immutable per credential.** `copyWith` cannot change `publicKey`, so even a buggy caller cannot re-point an existing credential's key. | `repository_credential.dart:137-172` |

**These are independent.** Even if the endpoint's idempotency were removed, mechanism 3 still refuses
and mechanism 4 still prevents silent substitution. Finding B6 cannot recur by a UX regression.

---

## R-4 — Reuse, not reinvention (`R-4`)

Every element maps to a named existing artifact. Genuinely new items are marked **NEW** and justified.

| # | Design element | Maps onto | New? |
|---|---|---|---|
| 1 | The credential record | `RepositoryCredential` (`repository_credential.dart:36`) | — |
| 2 | Credential lifecycle states | `CredentialStatus` `generated\|verified\|failing\|revoked` (`credential_status.dart:6-21`) | — |
| 3 | Host-trust states | `HostKeyStatus` `unknown\|confirmed\|changed` (`credential_status.dart:41-50`) | — |
| 4 | The "both halves" gate | `canReachRepository` (`:128-129`), `permitsConnection`, `isUsable` | — |
| 5 | Recording a minted credential | `recordGeneratedCredential` (`engine:912-967`) | — |
| 6 | Host confirmation | `confirmHostKey` (`engine:974-1013`) | — |
| 7 | Recording a check result | `recordCredentialCheck` (`engine:1020-1054`) | — |
| 8 | Revocation | `revokeCredential` (`engine:1058-1076`), `revokedAt`/`revokedReason` | — |
| 9 | Rotation | `rotateCredential` (`engine:1084-1119`), `supersedesCredentialId` | — |
| 10 | The credential a caller must use | `requireUsableCredential` (`engine:1138-1160`) | — |
| 11 | One-active-credential rule | `engine:940-947` + `credential_test.dart:206` | — |
| 12 | Key-material guard | `engine:933-939` + `credential_test.dart` group "no key material reaches the domain" | — |
| 13 | Durable storage | `saveProductCredential`, `readProductCredential`, `readActiveCredentialForRepository`, `readCredentialsForProduct` (`product_registry_store.dart:39-55`) | — |
| 14 | Postgres implementation | `postgres_product_registry_store.dart:173-320` | — |
| 15 | Table | `product_credential` (`repository_credential.spy.yaml`) | — |
| 16 | Existing credential wire type | `RepositoryCredentialView` (`repository_credential_view.yaml`) | — |
| 17 | View mapping | `UiViewMappers.repositoryCredentialView` (`ui_view_mappers.dart:169-188`) | — |
| 18 | Already surfaced to clients | `ProductDetailView.credentials` (`control_plane_service.dart:362-403`) | — |
| 19 | Error vocabulary | `CredentialNotFoundException`, `CredentialNotUsableException`, `HostKeyNotConfirmedException` (`packages/product_registry/lib/src/exceptions.dart:201,215,232`) | — |
| 20 | Audit sink | `AuditEntityType.productCredential` (`audit_entity_type.dart:8`) | — |
| 21 | Endpoint home | `ProductRegistryEndpoints` (`apps/server/lib/src/endpoints/product_registry_endpoints.dart`) — *"an endpoint never sets state directly"* | — |
| 22 | Service layer | `ControlPlaneService` (`control_plane_service.dart`) | — |
| 23 | Repository identity | `RepositoryReference` (`repository_reference.dart`), `.uri`, `.provider` | — |
| 24 | Client check axis | `AccessStatus` (`add_product_page.dart:239`) — unchanged | — |
| 25 | UI components | `DesignPanel`, `MicroLabel`, `InlineLink`, `ShipItType`, `ShipItPalette`, `ShipItMetrics` | — |
| 26 | Mint endpoint | `ProductRegistryEndpoints.mintOrReadDeployKey` | **NEW** — required by `R-H1`; no endpoint currently exposes a credential view (`grep -c RepositoryCredentialView apps/server/lib/src/endpoints/*.dart` → **0** for all 11 files) |
| 27 | Check endpoint | `ProductRegistryEndpoints.checkRepositoryAccess` | **NEW** — no access-check capability exists |
| 28 | Mint response type | `DeployPublicKeyView` | **NEW** — `RepositoryCredentialView` has **no** `publicKey` field (`repository_credential_view.yaml:7-26`), so it cannot express this response. A separate type also keeps the public half out of the `ProductDetailView` read surface |
| 29 | Check response type | `CredentialCheckResultView` + `failureKind` presentation enum | **NEW** — the wire must distinguish causes; the *domain* vocabulary is unchanged (§ R.14) |
| 30 | Client host-trust enum | `HostTrustStatus` | **NEW** — mirrors server `HostKeyStatus`; no client equivalent exists |
| 31 | The private-half store | — | **NEW, and `OPEN — HUMAN DECISION REQUIRED AT GATE D4`** (OPEN-D4-1) |
| 32 | Keypair generation | — | **NEW** — a real SSH implementation replaces `_generateMockKeyPair`; belongs in `apps/server/**` per `C-02` |
| 33 | SSH host-key verification | — | **NEW** — **no such code exists anywhere**; see § Feasibility |
| 34 | Credential injection into the transport | — | **NEW** — `GitWorkspaceInspector._capture` passes no `environment:` |
| 35 | Migration | **none proposed** | — § R.3 deliberately keeps the schema unchanged; A2 alone would need one, and it is `OPEN` |

**No parallel credential abstraction is introduced.** #26–#34 are transport, presentation and secret
material concerns; the credential *model* is entirely the existing one.

---

## R-5 — The endpoint (`R-5`)

### R.16 `mintOrReadDeployKey`

Placed on the existing `ProductRegistryEndpoints`, which states *"an endpoint never sets state
directly"* — the endpoint delegates to `ControlPlaneService`, which delegates to the engine.

```dart
Future<DeployPublicKeyView> mintOrReadDeployKey(Session session, {
  required String productId,
  required String repositoryId,
})
```

**Semantics — get-or-create:**

1. `readActiveCredential(productId, repositoryId)`.
2. **If a credential exists → return it with `alreadyExisted: true`. Never generate.**
3. Else: derive `host` from `RepositoryReference.uri`; if no host can be derived → refuse, write
   nothing. Generate the keypair; store the private half per **OPEN-D4-1**;
   `recordGeneratedCredential(...)`.
4. On the engine's one-active-credential exception (`engine:940-947`) — a concurrent mint — **re-read
   and return the winner's public half** with `alreadyExisted: true`. This is a concurrency
   resolution, not an error: two simultaneous presses must still yield one key.

**`DeployPublicKeyView`** (NEW; `apps/server/lib/src/models/deploy_public_key_view.yaml`):

| Field | Type | Note |
|---|---|---|
| `credentialId` | `String` | The handle every later action reuses |
| `publicKey` | `String` | The installable half |
| `fingerprint` | `String` | `SHA256:…` |
| `algorithm` | `String` | `ed25519` |
| `host` | `String?` | Derived from the repository URI |
| `hostKeyStatus` | `String` | `unknown\|confirmed\|changed` |
| `status` | `String` | `generated\|verified\|failing\|revoked` |
| `createdAt` | `DateTime` | |
| `alreadyExisted` | `bool` | The B6 guard, observable by the client |

**There is no field capable of carrying private key material** — not as an omission, as a design
property. `SC-09` makes it testable: a test asserts no response type of this surface can contain a
`PRIVATE KEY` marker.

**Error cases:**

| Case | Response | State written |
|---|---|---|
| Unknown product / repository, or cross-product access | `CredentialNotFoundException` / scope error → 4xx | none |
| Host not derivable from `RepositoryReference.uri` | 400 `repositoryUriUnparseable` | none |
| Concurrent mint (engine one-active rule) | 200, winner's credential, `alreadyExisted: true` | one row |
| Substrate unavailable / protection inadequate | **depends on Q2 — `OPEN`** (`B1` 503 + named remediation / `B2` mint + record degradation) | **`OPEN`** |
| `publicKey` containing `PRIVATE KEY` | `CredentialNotUsableException` (`engine:933-939`) | none |

### R.17 `checkRepositoryAccess`

```dart
Future<CredentialCheckResultView> checkRepositoryAccess(Session session, {
  required String productId,
  required String credentialId,
})
```

Reads by id; **contains no generation step**. Refuses when `!hostKeyStatus.permitsConnection`
(`N-3`), performs the transport attempt, calls `recordCredentialCheck`, and returns
`{ credentialId, status, hostKeyStatus, lastVerifiedAt, lastVerifiedBy, failureKind?, failureReason? }`
per § R.14.

### R.18 Exposure of a credential-minting endpoint — the honest answer

**Today, nothing protects this endpoint from an off-host caller.** Not a weakened control — none of
the controls exist:

- `apps/server/lib/server.dart:71-72` declares **no authentication services** for the control plane.
  `DEC-048f3367` resolved OPTION_C (*"Fix and add authentication"*), but `DEC-570bb640` superseded its
  authentication half: no auth now, accepted risk scoped to local/QA, auth a **blocking production
  precondition**.
- The "local only" premise `DEC-570bb640` relies on is **not enforced**.
  `grep -rn "127.0.0.1:" docker/*.yaml apps/server/docker-compose.yaml` returns **no match**; the
  mappings are unqualified (`docker/compose.qa.yaml:17,56,74` → `5432:5432`, `8080:8080`,
  `8081:8081`), which Docker publishes on `0.0.0.0`. `DEC-570bb640`'s own loopback-pinning
  follow-up is **un-implemented**.
- So this is not merely theoretical: on any shared network the endpoint is reachable today.

**What this changes relative to every existing endpoint.** The control plane can already be driven
without authentication — create and execute jobs, resolve human decisions (`DEC-048f3367` finding M4).
This endpoint is different in kind in three ways, and the revision states so rather than footnoting it:

1. **It is the first endpoint whose side effect is *persisting secret material*.** Every prior
   unauthenticated call is a governance bypass; this one causes a private key to come into existence.
2. **It is not bounded by an existing record.** Job creation and decision resolution operate on rows
   that must already exist. Minting *creates* one, so an off-host caller can cause unbounded key
   creation across repositories it names — a resource-exhaustion and key-sprawl vector, not just a
   read.
3. **The public half it returns is usable by anyone holding it**, because the design intends it to be
   pasted into `authorized_keys`.

**Consequences this revision accepts, and the mitigations that do not pretend to be authentication:**

- Every mint and every check is **logged and audited** via the existing `AuditEntityType.productCredential`.
- The endpoint refuses to mint when the host cannot be derived, which limits arbitrary target creation
  to syntactically valid SSH remotes.
- **The dependency to record, not to solve:** this endpoint must not ship to any environment where the
  control plane is reachable off-host until either the `DEC-570bb640` loopback pinning lands or API
  authentication lands. That is a **deployment precondition**, owned by the Manager/deployment
  authority, not something the design agent can enforce by writing an endpoint.
- **I am not proposing API authentication.** `DEC-570bb640` deferred it deliberately; smuggling a
  cross-cutting auth change in as a side effect of a deploy-key feature is exactly what
  `DEC-048f3367`'s own resolution warned against.

---

## R-6 — OPEN-D4-2, registration ordering (found while designing; **not** in the brief)

### R.19 The circular dependency

Human point 2b requires "Register product" to be **dependent on** key generation and host trust. The
domain requires the opposite order:

```
createProduct(productId, …)            engine:43-63   → state: ProductState.registered
addRepositoryReference(productId, …)   engine:150-174 → requires the product to exist
recordGeneratedCredential(productId, repositoryId, …)
                                      engine:912-967  → readRepositoryReference + _ensureOwned
                                                            ⇒ REQUIRES the repository AND product
confirmHostKey(…)                      engine:974-1013
recordCredentialCheck(…)               engine:1020-1054
```

`recordGeneratedCredential` **cannot** run before the product and repository exist
(`engine:924-925`). So if "Register product" is the act that creates the product, and it is gated on a
credential that requires the product, the gate is **unsatisfiable** — the same class of defect as the
current `canRegister`.

Note there is no pre-registration `ProductState` to hide in: `createProduct` hardcodes
`ProductState.registered` (`engine:52`), and `registered` is already defined as *"no baseline, no
governance, no work … a product is visible here before anything about it has been approved"*
(`product_state.dart:29-32`).

### R.20 Options — `OPEN`, 3 atomic options

| Option | Shape | Consequence |
|---|---|---|
| **1 — Split identity from registration** | The key flow creates the `Product` row (`registered`) + `RepositoryReference` as an explicit first step; "Register product" then commits credential verification. | Satisfies 2a/2b literally and matches `registered`'s existing semantics. **But** leaving the page early leaves a visible product with no usable credential, which sits awkwardly with the human's *"if when down the road we want to create that product"*. Makes § R.12's read path exact. |
| **2 — Decouple the credential from product ownership** | Mint against the repository only; `productId` nullable/pending until the product exists. | Preserves 2a/2b and the addendum's promise most faithfully. **But** breaks `RepositoryCredential.productId`'s non-null invariant and its stated purpose (*"scope enforcement so that knowing a credential id does not bypass the ownership graph"*, `:62-65`) — a contract **and** schema change with a real blast radius. |
| **3 — Mint at registration** | Key generation happens inside the register action; the key is copyable afterwards. | Minimal change to the domain; keeps product creation one explicit act; "the key persists" still holds. **But** it rejects human point 2a (generation on SSH URL input) and point 2b (registration gated on the key) as written, so it needs its own human sign-off. |

**Recommendation**: **Option 1**, because it is the only option that satisfies both human points as
written *and* sits inside the existing `ProductState.registered` semantics, and because it is the only
one that makes `R-H2`'s "the key is still there later" literally true via the § R.12 read path.
Confidence **MEDIUM** — it trades a visible half-registered product against a stricter reading of
`R-H2`, and that trade is a product judgement, not an architecture one.

**Question asked at Gate D4:** *Which of 1/2/3 resolves the ordering conflict between `R-2b` and the
credential domain's product-ownership requirement?*

**What is NOT open regardless of the answer:** the endpoint shapes (§ R.16–R.17), the trust state
machine (§ R.9–R.10), the check semantics (§ R.13–R.14), and the B6 kill (§ R.15). All three options
implement them identically; only the trigger moves.

---

## R-7 — Traceability gaps (`R-6`)

### R.21 ADR 0018 and `AGENTS.md §13a` are absent — and I cannot read my own governing ADR

**Verified**: `ls docs/engineering/adr/` → `0001`, `0002`, `0003` only. `AGENTS.md` sections are
`Inherited invariants`, `Orchestration`, `Product-specific policy`, `Framework provenance` — no §13.
Code cites them in **nine** places: `repository_credential.dart:10`, `credential_status.dart:1,36`,
`product_registry_store.dart:7,35`, `repository_credential.spy.yaml:4`,
`repository_credential_view.yaml:1`, `product_registry_engine.dart:898`.

This is a traceability gap of the first order: **the document that defines the credential model I am
designing onto does not exist in this repository.** I have not invented its content.

**Every assumption I made in its place:**

| # | Assumption | Basis | If wrong |
|---|---|---|---|
| 1 | Scope is one **repository**, not one product | Executed by `repository_credential.dart:20-27` and enforced at `engine:924-925` | The whole credential scoping changes |
| 2 | The private half is referenced by name, never by value | `repository_credential.dart:12-18`, `engine:932-939`, `credential_test.dart` group | `C-04` and OPEN-D4-1 both collapse |
| 3 | Access is proven, never assumed | `credential_status.dart:2-5`, `engine:1017-1019` | The `generated`→`verified` model and `SC-04` change |
| 4 | Host trust is human, attributable, out-of-band | `credential_status.dart:38-40`, `engine:983-988` | `N-4`/`N-5` and `HostKeyStatus` change meaning |
| 5 | `changed` fails closed | `credential_status.dart:49-50`, `engine:989-1002` | `N-6` has no security basis |
| 6 | One active credential per repository; rotate instead | `engine:940-947`, `credential_test.dart:206` | The B6 kill mechanism 3 fails |
| 7 | Revoked records are retained, never deleted | `engine:1056-1057`, `credential_test.dart:246` | OPEN-D4-1 Q3 and `C-1` change |
| 8 | `referenceName` names the operator's local secret store | `repository_credential.dart:70-72` | § R.3's reconciliation is unnecessary or differently scoped |
| 9 | SHA-256 host-key fingerprinting is the expected format | `repository_credential.dart:104-106` example is `SHA256:…` | Trust-step copy changes |
| 10 | A deploy key is per-repository installable with **write** access | Board copy at `add_product_page.dart:590` | Failure taxonomy copy changes |

**Reported as a gap, not resolved.** Correcting the dangling citations is a separate, Manager-owned
action; `WORK_STATE.md` and `.decisions/**` are outside this lane's `OWNED_PATHS`.

### R.22 Other recorded gaps

| # | Gap | Why it is a gap |
|---|---|---|
| `G-1` | ADR 0018 / `§13a` absent (§ R.21) | Governing architecture unreadable |
| `G-2` | No read-only-over-Docker rule in `AGENTS.md` | A design claim about the runtime could not be verified (§ Feasibility) |
| `G-3` | No test anywhere imports `add_product_page.dart` (0 of 26 per `DEC-73097d48`) | `SC-02`, `SC-04`, `SC-06` have no existing harness |
| `G-4` | No SSH host-key verification exists | `HostKeyStatus` has no runtime enforcer; `SC-04`/`SC-05` need one built |
| `G-5` | `GET`/read access to a product's public key has no endpoint | Fine — mint/get-or-create covers it, but it means the client cannot re-read a key without holding a `credentialId` |
| `G-6` | `recordGeneratedCredential`'s `host` is optional and defaults to `null` | A credential can exist with no host, making `N-4`'s copy impossible; the design refuses to mint without a host (§ R.16) but the domain does not enforce it |
| `G-7` | `RepositoryCredentialView` exposes `referenceName` to clients | Under server-side storage that is a **path/ARN disclosure**. Tied to OPEN-D4-1; removing it is a generated-contract change in two packages |
| `G-8` | Host fingerprint is presented to the user but its provenance is unspecified | The design says "the fingerprint the server actually observed" (`N-4`); **how** it is obtained (ssh-keyscan vs handshake) is unspecified and is part of the new transport seam |

---

## R-8 — Self-assessment (honest; no gate claimed that was not run)

### `design_system_compliance: PARTIAL`

The state machine reuses existing components **by name** — `DesignPanel`, `MicroLabel`, `InlineLink`,
`ShipItType`, `ShipItPalette`, `ShipItMetrics` — and adds no new component. But I did **not** author or
inspect the four mobile boards (`AC-11`, `C-11`: board creation/editing is prohibited for this lane),
so **visual and token compliance for `hostUnrecognised` and `hostKeyChanged` is `UNVERIFIED`** and
depends on the sibling lane. `PARTIAL`, not `PASS`.

### `ux_accessibility_score: PARTIAL`

Designed with: no cancel affordance (`N-1`), a blocking step with a named route out (`N-2`, `R.12`),
out-of-band confirmation wording that does not overclaim (`N-4`), and per-outcome copy rather than one
generic failure message (§ R.14). **Known contrast defect carried forward**: `inkTertiary` on
`palette.card` measures 4.23:1 in dark and **fails WCAG AA**; the prior round claimed ~6.0:1
(`docs/engineering/dispatch/tasks/design-register-button/report.md:71-76`). Requirement: specify
`inkSecondary` (6.74:1 light / 6.10:1 dark) for helper/technical text. **I did not re-measure these
ratios** — they are inherited from the prior reviewer's measurement, so they are reported as
inherited, not as verified by me. Focus order and live-region announcement for the async check result
are **specified but not verified** (no runnable build).

### `implementation_feasibility: MEDIUM`

| Component | Confidence | Basis |
|---|---|---|
| Credential lifecycle (mint/confirm/check/revoke/rotate/require) | **HIGH** | Already implemented **and covered** — 16 tests in `packages/product_registry/test/credential_test.dart` |
| Store + Postgres persistence | **HIGH** | `postgres_product_registry_store.dart:173-320`; table present |
| Endpoint + view mapper | **MEDIUM** | `ProductRegistryEndpoints`/`ControlPlaneService`/`UiViewMappers` patterns are established; needs generated protocol regeneration in **two** packages |
| **SSH transport seam (credential injection + host-key verification)** | **LOW** | **Nothing exists.** `git_workspace_inspector.dart:106-112` runs `Process.run(git, args)` with no `environment:`; repo-wide grep for `SSH_AUTH_SOCK\|known_hosts\|ssh-keyscan\|StrictHostKeyChecking\|IdentityFile` returns **no match**. Both must be built, and host-key verification is security-critical, so its correctness needs its own review |
| Private-half store | **`OPEN`** | Entirely dependent on OPEN-D4-1 |
| Client `AccessStatus` axis | **HIGH** | Exists today; unchanged |
| Client `HostTrustStatus` + `hostUnrecognised` UI | **MEDIUM** | New enum, new state; no existing harness (`G-3`) |

`MEDIUM`, not `HIGH`: the domain half is well-evidenced, the transport half is new and security
critical, and the store half is undecided. **I ran no analyzer, no build and no test** — claiming
`HIGH` would repeat exactly the prior review's finding that a lane asserted `implementation_feasibility: HIGH`
while its `flutter analyze` had never resolved packages. `dart analyze`/`flutter analyze` are
implementation-lane gates, not design-lane gates, and running them here would not change the design.

### Claims that could not be verified — `UNVERIFIED`, with the command a human should run

Per the no-Docker rule (`C-10`) I ran **no** Docker or Compose command. Consequently:

| Claim | Status | What a human should run |
|---|---|---|
| A real SSH transport accepts the generated public key | `UNVERIFIED` | `docker compose -f docker/compose.test.yaml up` then, inside the server container, install the returned `publicKey` into a scratch repo's `authorized_keys` and run a real check |
| A4 (host keychain from a container) is feasible | `UNVERIFIED` | Reachability depends on the host keychain being exposed to the container — must be tested on the actual deployment target |
| Host-key `changed` detection works against a real host | `UNVERIFIED` | Requires a host that presents a changed key |
| Loopback pinning is un-implemented | **VERIFIED (negative)** | `grep -rn "127.0.0.1:" docker/*.yaml apps/server/docker-compose.yaml` → no match. Fixing it is a deployment-lane action per `DEC-570bb640`. |

---

## Readiness

Ready for **Independent Design Review** (Gate D3). Not approved by its author.

Two questions are surfaced rather than answered, both **`OPEN — HUMAN DECISION REQUIRED AT GATE D4`**:
the at-rest protection model (OPEN-D4-1, as the human instructed) and the registration-ordering
conflict (OPEN-D4-2, found while designing). Gate D4 cannot be reached for this revision until a human
resolves both.