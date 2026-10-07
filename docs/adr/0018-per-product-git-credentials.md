# ADR 0018: Per-Product Git Credentials

## Status
Accepted (amended — see §Amendments; A1 credential scope = per repository; A2 credential custody = external secret manager, revocation = two-sided)

**Accepted by the repository owner (ADR owner) on 2026-10-06**, as ADR owner, through the
structured question UI. The recorded answer was: **"Accept A2, record the gaps as accepted."**

- **What this acceptance covers.** Amendment A2 as recorded in §Amendments, and the four knowingly-open
  gaps it carries, which are recorded as **accepted risks** in §Accepted risks with their consequences
  stated. Acceptance is of the *design*, on the ADR owner's authority.
- **What acceptance is NOT.** It is **not independent review**. The Design Revision recording A2
  (`docs/engineering/dispatch/tasks/design-adr-0018-amendment/`) has never been independently
  reviewed; `reviewed_by` is null and stays null until a reviewer signs it. An accepted ADR is not
  a reviewed artifact, and no downstream artifact may treat it as one.
- **Authority note.** `.decisions/**` is outside the design lanes' declared write scope, so **no
  Human Decision object on disk records this acceptance**. The provenance of the acceptance is the
  ADR owner's answer in the structured question UI, relayed in the Manager's dispatch
  `design-adr-0018-amendment` and recorded in `docs/engineering/WORK_STATE.md:326-327`. A decision
  object should be created by the Manager so the acceptance has a citable id, following the
  precedent set in `ae1c1f79:8-11`.

## Amendments

Amendments are recorded by revision, not by silent rewrite. Superseded wording
is retained in-place and marked **SUPERSEDED (A1)** or **SUPERSEDED (A2)**, naming
the amendment that superseded it. Line numbers cited in §Amendments refer to the
revision named there, not to the current file.

| Rev | Date | Change | Reason |
|-----|------|--------|--------|
| A1 | 2026-09-19 | Credential scope: ~one keypair per product~ → **one keypair per repository** | A Product may own several repositories (`readRepositoriesForProduct` returns a list), and providers forbid reusing a deploy key across repositories in one organisation. A per-product key is therefore not installable for a multi-repo product — an internal contradiction this ADR already half-acknowledged in its own Negatives. |
| A2 | 2026-10-06 | Custody: private half in the **operator's local secret store** → **an external secret manager (A3)**; SHIP IT holds a **reference**, never key bytes. Revocation: provider-native and ~requires no ShipIt-side action~ → **two-sided**, destroying the manager handle. | Resolved Human Decisions `9417f8bf` (SECURITY, OPTION_C) and `79e860e2` (SECURITY, OPTION_A), with `b869ec24` (ARCHITECTURE, OPTION_A) already having moved generation and storage **server-side**. The superseded clauses were both written for a custody model in which SHIP IT held nothing: `:85-88` said the private half goes to the operator's device, and `:113-114` said revocation needs no ShipIt-side action. Once `b869ec24` made SHIP IT a participant in custody, both were false as written. |

### A1 — Scope is the repository, not the product

- **Previous (superseded):** one `ed25519` keypair per product, installed as a
  deploy key on that product's repository.
- **Current:** one `ed25519` keypair **per repository**. `RepositoryCredential`
  is keyed by `repositoryId`; `productId` is retained for ownership checks only
  and is no longer the unit of scope.
- **Effect on the decision's intent:** strictly strengthened. The blast radius
  goal was "a leaked key reaches one repository, not all of them" — per-repository
  scoping delivers exactly that, whereas per-product scoping only delivered it
  for single-repository products.
- **Effect on presentation:** none required. The UI continues to group
  credentials under their owning product; a product simply shows one row per
  repository rather than one row overall.
- **Reference name** becomes per repository, e.g.
  `GIT_PRODUCT_<productRef>_<repoRef>_SSH`.

### A2 — Custody is a secret manager, and revocation is two-sided

Line numbers in this section refer to the **A1** revision of this file (158 lines, status
"Proposed (amended — A1)").

#### Decisions recorded

Every replacement below traces to a resolved Human Decision, recorded here so the mapping is
auditable rather than asserted:

| Decision | Type / option | What it settles in this ADR |
|---|---|---|
| `73097d48` | PRODUCT / `OPTION_A` | Real `ed25519` deploy-key generation, replacing the non-installable mock. |
| `b869ec24` | ARCHITECTURE / `OPTION_A` | Generation and storage are **server-side**, behind an API returning only the public half, because SHIP IT pushes from its own backend and never from the browser. |
| `9417f8bf` | SECURITY / `OPTION_C` | **Custody is an external secret manager (A3).** Supersedes the custody half of `:85-88`. |
| `79e860e2` | SECURITY / `OPTION_A` | **Revocation destroys the secret-manager handle**, credential row retained. Supersedes `:113-114`. |
| `898b07d0` | ARCHITECTURE / `OPTION_A` | Split identity from registration. **Leaves `:100-102` standing** and makes it satisfiable. |
| `27ea6536` | DESIGN / `OPTION_A` | UI footer copy only. **No bearing on any clause here** — checked, see below. |

#### Previous (superseded) — custody

One `ed25519` keypair per repository, generated by ShipIt **on the operator's device**, the
private half written to the local secret store (macOS Keychain or
`~/.config/shipit/platform/` chmod 600) — never displayed, logged, persisted to the durable
record, or transmitted.

#### Current — custody (A3)

One `ed25519` keypair **per repository**; the scope from A1 is unchanged. The pair is generated
and stored **server-side**, and the private half is held by an **external secret manager**.
SHIP IT writes a **reference** — a secret path or ARN — and asks the manager for the material
at transport time. **SHIP IT never holds key bytes.** The prohibitions carry over verbatim and
are unchanged in force: the private half is never displayed, logged, persisted to the durable
record, or transmitted.

#### Effect on the decision's intent: strengthened

"Referenced by name, never by value" was already the contract — `RepositoryCredential` has no
key-material field at all. A3 is the first substrate under which that contract is true
*literally* rather than by convention: under the superseded local store, SHIP IT wrote the
bytes and relied on never reading them back. The blast-radius goal is unaffected, because the
unit of scope is still A1's per-repository keypair.

#### Effect on presentation

The public half is surfaced in the UI exactly as before. What changes is what the operator may
be told. A reference is a secret path or ARN, so UI copy must not claim the key "stays in the
keychain" on a device that no longer holds it. Board copy asserting that claim is already
tracked by the Add Product mobile design lane, which records the build text at
`add_product_page.dart:542` and `:1038` as "created on this device · the private half stays in
the keychain"; **this amendment did not re-verify that line reference** —
`apps/control_plane/**` is outside this lane's declared read scope.

#### Fallback is a precondition, not a default

Filesystem `0600` (A1) and host keychain (A4) remain the **documented fallback** when no secret
manager is reachable in the target topology. Selecting a fallback is a recorded precondition
(§Preconditions) and is never defaulted silently.

#### The envelope-encrypted-table substrate is permanently excluded

Sealed ciphertext stored in a table **is** the durable record, so the surviving "never persisted
to the durable record" clause rules it out. Recorded here so it is not re-proposed as an
available option in a later round. `9417f8bf` records the same exclusion and adds that such a
substrate would make the key-encryption key the single most valuable secret in the system.

#### Revocation — supersedes `:113-114`

Two-sided: the operator removes the deploy key at the host, **and** SHIP IT destroys the
secret-manager handle. The credential row is **retained** and stays fully readable with
`status`, `revokedAt` and `revokedReason`, so the audit trail is untouched. "Destroy" means
deleting the manager's handle — not overwriting bytes SHIP IT does not hold.

This clause carries a caveat recorded as **accepted risk A1** in §Accepted risks: **a revoked
credential can currently be resurrected by a re-mint**, so the revocation this amendment specifies
is not yet enforceable end to end. The repository owner accepted that gap alongside A2 on
2026-10-06 rather than gating A2 behind it.

#### The registration clause `:100-102` is upheld, not superseded — and was unsatisfiable

`898b07d0` splits identity from registration: the key flow creates the `Product` row (state
`registered`) plus the `RepositoryReference` as an explicit first step, and "Register product"
then commits credential verification. The clause's requirement — no registration without a
proven connectivity check against the real host with the real key — is therefore now
**satisfiable**.

It was not satisfiable as written. Minting a credential required the `Product` and
`RepositoryReference` rows that registration itself creates, so gating registration on a
credential made the cycle unbreakable. **This ADR and the domain contradicted each other until
this amendment**, and that contradiction is recorded here because a future reader must not
mistake the fix for a formality: if the split is not implemented in that order, the clause
becomes unsatisfiable again.

Its accepted cost is recorded for the same reason: leaving the page early leaves a **visible
product with no usable credential**. That is the price of honouring the clause literally, and
the repository owner has accepted it.

#### What survives A2 unchanged

One keypair per repository (A1); the prohibition on persisting key material to the durable
record; "referenced by name, never by value"; the public half surfaced in the UI with no secret
value ever typed into ShipIt; trust-on-first-use host confirmation with an operator-visible
fingerprint; rotation scoped to one repository.

#### `27ea6536` checked, and found not to bear on this ADR

It is a UI footer-copy and alignment decision — the `Show technical details` button, dividers,
and the removal of footer copy on both platforms. It makes no statement about custody,
references, or key material, so it does not reach the clause "no secret value is ever typed
into ShipIt", which stands unchanged.

## Context

Product onboarding (checkpoint 006) requires ShipIt to clone a product's source
repository at a pinned revision in order to build a baseline, and later to write
results back to that repository. This requires a durable credential.

AGENTS.md §13 establishes the platform's credential convention, written for
Penpot and tooling:

> One **role-scoped service-profile token** covers all shipit-platform products;
> never a token per project.
>
> Separation comes from role-scoping, never from spreading more secret values.

That convention is correct **for Penpot**, because Penpot access is granted
through a profile's *memberships and roles* on workspaces. One identity holds
many scoped grants, so one secret is sufficient and additional secrets would add
risk without adding separation.

Git hosting does not work that way:

- The provider-native mechanism for scoping access to a single repository **is**
  a per-repository key (GitHub Deploy Keys, GitLab Deploy Keys, Bitbucket Access
  Keys). There is no equivalent of Penpot's workspace-membership indirection.
- A single service-profile key must be attached to a bot account that holds
  permission on **every** product repository. With write access required
  (ADR 0012 promotion flows, result branches), that is a standing write grant
  across all products held in one secret.
- The blast radius of a leak is therefore every governed product, not one.
- Rotation is fleet-wide: rotating the one key invalidates access for every
  product simultaneously.

Additional constraints from checkpoint 006 design review:

- Workers are device-local today, remote later. The credential must be
  referenceable by name and injectable at the worker without redesign.
- Products may be hosted on **any** git host reachable over SSH, including
  self-hosted servers with no notion of fine-grained tokens.
- SSH is the only credential mechanism that is portable across all such hosts;
  personal access tokens differ per provider in scope model, granularity,
  expiry semantics and creation flow.

## Decision

**Each product owns its own SSH keypair. Git credentials are scoped per product,
not per platform.**

This is a deliberate, scoped deviation from AGENTS.md §13 for git credentials
only. §13 continues to govern Penpot and other tooling credentials unchanged.

Specifics:

- ~~**One `ed25519` keypair per product**~~ **SUPERSEDED (A1)** — see
  §Amendments. **One `ed25519` keypair per repository**, generated by ShipIt on
  the operator's device. The private half is written to the local secret store (macOS Keychain
  or `~/.config/shipit/platform/` chmod 600) and is never displayed, logged,
  persisted to the durable record, or transmitted.
  **SUPERSEDED (A2) in part — `9417f8bf`, `b869ec24`.** Superseded: the **custody** clause
  only, namely "generated by ShipIt on the operator's device" and "written to the local secret
  store (macOS Keychain or `~/.config/shipit/platform/` chmod 600)". The A1 **scope** clause
  ("one keypair per repository") and the whole **prohibition** clause ("never displayed,
  logged, persisted to the durable record, or transmitted") both **stand**, and the prohibition
  is now load-bearing: it is what permanently excludes the envelope-encrypted-table substrate.
- **Custody is an external secret manager (A3). SHIP IT holds a reference, never key bytes.**
  The keypair is generated and stored **server-side**, behind an API that returns only the
  public half, because SHIP IT pushes from its own backend and never from the browser
  (`b869ec24`). The private half is held by the secret manager. SHIP IT writes a **reference**
  — a secret path or ARN — and asks the manager for the material at transport time
  (`9417f8bf`). The private half is **never displayed, logged, persisted to the durable record,
  or transmitted**, exactly as the surviving clause above requires.
- **The local secret store (A1) and host keychain (A4) remain the documented fallback** when no
  secret manager is reachable in the target topology. Fallback selection is a recorded
  precondition, not a silent default. See §Preconditions.
- **The envelope-encrypted-table substrate is permanently excluded** by the surviving
  prohibition: sealed ciphertext in a table *is* the durable record. Recorded so it is not
  re-proposed.
- **The public half is surfaced in the UI** for the operator to install as a
  deploy key on the product's repository. No secret value is ever typed into
  ShipIt.
- **Referenced by name, never by value** — §13's core rule is preserved. The
  product record stores a credential *reference* (e.g.
  `GIT_PRODUCT_<productRef>_SSH`) plus the public key fingerprint. It never
  stores key material.
- **Host keys are trust-on-first-use with an explicit human confirmation.**
  ShipIt refuses to connect to an unrecognised host. The operator is shown the
  host, key type and fingerprint and must confirm it. ShipIt does not claim to
  have verified a host it cannot verify (§13 "verify before acting").
  **Requirement, not yet enforced at the transport.** This clause is recorded
  architecture and remains a requirement, but nothing today verifies a host key at
  the point of connection. See §Invariants enforced elsewhere and §Accepted risks A2.
- **Access is proven, not assumed.** A product cannot be registered until a
  connectivity check has succeeded against the real host with the real key. The
  result is stored with a timestamp and shown in the UI as a fact.
  **UPHELD (A2) — not superseded** (`898b07d0`). This clause was **unsatisfiable as
  written**: minting a credential required the `Product` and `RepositoryReference` rows
  that registration itself creates, so gating registration on a credential made the
  cycle unbreakable, and this ADR contradicted the domain. Splitting identity from
  registration makes it satisfiable. See §Amendments A2.
- **Rotation is per product.** Rotating a key affects exactly one product and
  requires re-installing the new public key on that repository.

## Consequences

### Positive

- A leaked key reaches one repository. Previously it would have reached all of
  them.
  **A3 does not change this, but the reference is now a second artifact in scope.**
  A leaked *key* still reaches exactly one repository, because scope is still the
  per-repository keypair from A1. But under A3 the *reference* is what SHIP IT holds, and a
  reference is a secret path or ARN — disclosing vault topology, naming the secret, and giving
  an attacker the exact handle to ask the manager for. The blast-radius argument is therefore
  about **two** artifacts, not one, and the reference is the one SHIP IT is likelier to leak,
  since it is persisted in the durable record while the key bytes are not. See
  §Invariants enforced elsewhere.
- Rotation blast radius is one product, not the fleet.
- ~~Revocation is provider-native: removing the deploy key from the repository is
  sufficient and requires no ShipIt-side action.~~ **SUPERSEDED (A2)** — `79e860e2`.
  Written for a custody model in which SHIP IT held nothing. Once `b869ec24` made SHIP IT a
  participant in custody, a ShipIt-side action became necessary, and it is now the point of
  the clause.
- **Revocation is two-sided: provider-side removal AND a ShipIt-side action.** Removing the
  deploy key at the host remains necessary and remains the operator's act — SHIP IT cannot do
  it. It is no longer *sufficient*. Revocation additionally **destroys the secret-manager
  handle**, so key material SHIP IT can reach is released at revocation rather than lingering
  until someone remembers to uninstall it at the host. The `RepositoryCredential` row is
  **retained** and stays fully readable with `status`, `revokedAt` and `revokedReason`, so the
  audit trail is untouched and history survives.
  **Accepted caveat:** a revoked credential can currently be resurrected by a re-mint, so this
  clause is specified but not yet enforceable end to end. Accepted by the repository owner on
  2026-10-06; see §Accepted risks A1.
- No secret is ever entered into the ShipIt UI, only copied out of it.
- Portable to any SSH-reachable host, including self-hosted, satisfying the
  "any git host" requirement.
- Read-only vs write is a property of the installed deploy key on the provider
  side, independently verifiable by the operator.

### Negative

- N products means N keypairs to create, install, verify and rotate. Onboarding
  gains a manual step (install the public key on the repository) that a shared
  bot account would not require.
- Deviates from the single-secret principle in AGENTS.md §13, so the repository
  now holds two credential conventions and must document which applies where.
- Some hosts cap the number of deploy keys. Per-repository scoping (A1) means
  key count grows with repository count, not product count, so a product with
  many repositories generates many keys.
- ~~forbid reusing one key across repositories in an organisation~~
  **SUPERSEDED (A1)**: this constraint is what forced the scope change, rather
  than something the decision tolerates.
- Self-hosted servers without a per-repository key concept require falling back
  to an account-level key, which reintroduces the shared blast radius for those
  products only.

### Mitigation

- AGENTS.md §13 gains a git-specific carve-out pointing at this ADR, so the two
  conventions are explicit rather than contradictory.
- The UI surfaces key state per product (`not created` / `not installed` /
  `verified <when>`) so the manual install step is visible and cannot be
  silently skipped.
- Credential management gets a dedicated per-product page rather than being
  buried in onboarding, so rotation and revocation are first-class.
- Where an account-level key is unavoidable, the product record records that
  fact so the wider blast radius is stated rather than assumed.

## Invariants enforced elsewhere

Under A2 the claims above stop being statements this ADR can make on its own evidence: SHIP IT
holds no key bytes, so every property that used to follow from *having* a key now has to be
enforced by something else. This section records what enforces each one, as verified against
source at `43d328b`, and states plainly where the enforcement is still absent.

> **Provenance correction (2026-10-06, re-verified at `43d328b`).** This section was first written
> against `6220951`, where the two database objects below **did not exist in `main`**. `e391c02`
> has since merged them. Both markers that said "not present at this revision" were true at
> `6220951` and are **false at `43d328b`**, so they are corrected here rather than carried into a
> frozen ADR. All line numbers in this section are as of `43d328b`.

**The one-active-credential-per-repository invariant (A1) is enforced in the domain AND, as of
`e391c02`, in the database on both the bootstrap and chain-migration paths.**

- Domain guard: `packages/product_registry/lib/src/engine/product_registry_engine.dart:954-960`
  reads the active credential for the repository and throws `CredentialNotUsableException` unless the
  caller is rotating the credential it already found.
- Database guard: the partial unique index `product_credential_active_repository_unique` is present
  at `43d328b` in **both** `apps/server/tool/schema_bootstrap.sql:98-100` and
  `apps/server/migrations/20261006150645000/migration.sql:53-55`, both
  `WHERE ("status" <> 'revoked')`. `apps/server/tool/verify_schema_bootstrap.sh:91` asserts the two
  agree, and migration `20261006150645000` is now the newest migration in
  `apps/server/migrations/` (previously `20261001205247600`).
- **What the index does and does not do.** It refuses a **second** non-revoked row for one
  repository, closing the race in which two callers both pass the domain read before either writes.
  It does **not** refuse a legitimate fresh mint after a proper revocation, because
  `rotateCredential` (`product_registry_engine.dart:1116-1132`) revokes first, so the superseded row
  is already excluded from the index when the replacement is inserted. An earlier draft of this
  section stated the opposite; that was wrong and is corrected here.

**Immutable key material per credential is enforced, as of `e391c02`.**

- `apps/server/lib/src/persistence/postgres_product_registry_store.dart:322-331` uses
  `ON CONFLICT ("credentialId") DO UPDATE SET … WHERE "product_credential"."publicKey" = @publicKey
  AND … "fingerprint" = @fingerprint AND … "algorithm" = @algorithm AND … "referenceName" =
  @referenceName RETURNING "credentialId"`, so a write that would **change** a credential's key
  material matches no row. The comment at `:306-310` states that `RETURNING` is the detection
  mechanism precisely because an empty result cannot be ignored by accident, and `:348-350` turns an
  empty result into `CredentialNotUsableException`.
- The unique-constraint translation at `:332-347` maps `SQLSTATE` **and** index name to
  `CredentialNotUsableException`, so the index failure reaches the caller as a domain error rather
  than a raw database error.
- The guard is documented at the engine boundary too: `product_registry_engine.dart:907-915` states
  that `[credentialId]` "must be a NEW identity" and that only the write can be atomic, which is why
  the enforcement lives in the store and not in the engine.
- **This is not the same as closing the resurrection gap in §Accepted risks (A1).** Immutability
  makes the `DO UPDATE` branch *predicated*; it does not make the branch *unreachable*. A re-mint
  supplying **identical** material still satisfies the predicate and still updates the row.

**`HostKeyStatus` has a domain gate but NO transport enforcer — this clause is decorative at the
transport layer.**

This is recorded honestly rather than restated as a requirement, because the distinction
matters. Re-verified at `43d328b`; the sites have moved **+14 lines** from the `6220951` reading, and
there are **three** of them, not two:

- *Enforced in the domain.* `product_registry_engine.dart:1047-1052` (recording a check,
  `recordCredentialCheck`) and `:1162-1167` (the path a caller uses before clone or push,
  `requireUsableCredential`) each test `c.hostKeyStatus.permitsConnection` and throw
  `HostKeyNotConfirmedException` when it is false. A third site, `:1012-1015`, records a **changed**
  host fingerprint and then throws, so re-pointing a confirmed host at a different key fails closed
  rather than silently re-trusting. `packages/platform_contracts/lib/src/types/repository_credential.dart:128-129`
  defines `canReachRepository` as requiring both a confirmed host and a proven credential. So SHIP IT
  will not *record* a verified status, nor hand out a usable credential, for an unconfirmed host.
- *Not enforced at the transport.* `packages/worker_runtime/lib/src/workspace/git_workspace_inspector.dart:107`
  runs `Process.run(git, args)` with **no `environment:`**, so no `IdentityFile`,
  `SSH_AUTH_SOCK` or `StrictHostKeyChecking` is ever passed to git, and a repository-wide search
  for `SSH_AUTH_SOCK|known_hosts|ssh-keyscan|StrictHostKeyChecking|IdentityFile` across `*.dart`
  and `*.sql` under `apps/` and `packages/` returns **no match** (re-run at `43d328b`). Nothing
  configures git to verify the host key, and no `known_hosts` is written. The clause at `:96-99`
  above is therefore a **recorded requirement that no runtime mechanism yet performs**; the human
  confirmation is recorded as data and honoured by the domain, but the connection itself is
  unverified. Building this seam is prerequisite work, and its correctness is security-critical
  enough to warrant its own review.

**The credential reference is the most sensitive artifact SHIP IT holds, and is not protected.**

- `RepositoryCredentialView` carries `referenceName` as a serialised field in both generated
  packages, and the server side emits it on the wire:
  `apps/server/lib/src/generated/repository_credential_view.dart:145` (`toJson`) and `:166`
  (`toJsonForProtocol`), with the client mirror at
  `packages/control_plane_client/lib/src/protocol/repository_credential_view.dart:144`.
- Under A3 that value is an ARN or secret path, so any client that can read a credential view
  learns the vault's topology and the secret's name. `9417f8bf` records this as gap **G-7** and
  makes removing `referenceName` from the client view, or replacing it with a non-identifying
  handle, **required rather than optional**. It is a generated-contract change in two packages.
- Aggravating factor: the live database is reachable on all interfaces with a committed default
  password — `docker/compose.yaml:16-17` publishes `5432:5432` unqualified, `:63` sets
  `SERVERPOD_DATABASE_PASSWORD: shipit`, and `.env.example:16-18` documents the same default.
  The reference is therefore readable by anything that can reach the port.

## Preconditions

These are preconditions on the ADR holding, not footnotes. Each names the enforcement that must
exist elsewhere, and each was verified at `43d328b`. The first and second are **accepted risks** —
see §Accepted risks (A3) and (A4).

- **The "local only" scope is accepted, not enforced.** `570bb640` adopted a local-only
  deployment scope on the human's instruction and recorded the unauthenticated posture as an
  accepted risk for the local QA environment. That premise is not enforced by anything: all nine
  port mappings across `docker/compose.yaml`, `docker/compose.qa.yaml` and
  `docker/compose.test.yaml` publish unqualified, and a search for `127.0.0.1:` in
  `docker/*.yaml` and `apps/server/docker-compose.yaml` returns **no match** (re-run at
  `43d328b`). The loopback-pinning follow-up is therefore **still un-implemented**. Until it is,
  "local only" is a stated posture rather than a property, and A3 widens the consequence: the
  substrate holding the private halves is expected to sit behind that same boundary.
- **The secret manager's reachability is a runtime dependency whose unavailability blocks the
  credential path.** Under A3 the substrate can be down, and when it is, minting, verification
  and push all fail together — a common operating condition, not a remote edge case. Its
  failure behaviour must be fail-closed, and which substrate is reachable must be recorded per
  deployment rather than defaulted.
- **A1/A4 fallback selection is a precondition.** Choosing the local secret store or host
  keychain because no manager is reachable must be an explicit recorded decision, since it
  changes what this ADR's custody guarantee means.

## Accepted risks

The four gaps A2 carries were put to the repository owner as a single question — accept them
alongside A2, or gate A2 behind them. The answer was **"Accept A2, record the gaps as accepted."**
Each is therefore an **accepted risk**, not an open blocker, and each is re-verified against `main`
at `43d328b` below. Nothing here is closed; each entry states the consequence that was accepted.

**A1 — A revoked credential can be resurrected by a re-mint. ACCEPTED.**

- *Verified at `43d328b`:* both active-credential read paths still exclude revoked rows —
  `apps/server/lib/src/persistence/postgres_product_registry_store.dart:373-378` selects
  `WHERE "repositoryId" = @repositoryId AND "status" <> 'revoked'`, and
  `packages/product_registry/lib/src/store/in_memory_product_registry_store.dart:224-227` filters
  `c.status != CredentialStatus.revoked`. So after revocation the one-active guard at
  `product_registry_engine.dart:954-960` sees no active credential and cannot fire.
  `recordGeneratedCredential` (`:926-981`) has **no** check on the status of an existing credential,
  so a mint naming the revoked credential's `credentialId` re-enters it into the active set as
  `generated`, erasing `revokedAt` and `revokedReason`.
- *What the `e391c02` work changed, and what it did not.* The upsert is now predicating
  (`postgres_product_registry_store.dart:322-331`), so a **differing**-material write is refused.
  A re-mint supplying **identical** material still satisfies the predicate, still takes the
  `DO UPDATE` branch, and still overwrites `status`. The partial unique index does not close this
  either: after revocation the repository holds exactly one non-revoked row once resurrected, so no
  index constraint is violated.
- *Consequence accepted.* This ADR's two-sided revocation clause is **specified but not yet
  enforceable end to end**: a credential the operator believes revoked can be brought back to
  `generated` through the mint path. Existing coverage closes only the neighbouring path —
  `packages/product_registry/test/credential_test.dart:323` asserts a revoked credential cannot be
  re-**checked** into life, which constrains `recordCredentialCheck` and says nothing about the
  mint path. The state is recoverable by `rotateCredential` (revoke-then-mint,
  `product_registry_engine.dart:1116-1132`), so this is a correctness and audit-integrity exposure
  rather than an unrecoverable one. Closing it requires a mint path that can never write to an
  existing `credentialId` (`DO NOTHING` or equivalent); a fix for this was reviewed as
  `APPROVE_WITH_NON_BLOCKING_FOLLOWUP` on `fix/credential-identity-invariants` and is **not merged
  into `main`** as of `43d328b`.

**A2 — SSH host-key verification is enforced in the domain and not at the transport, while the
clause at `:96-99` requires a transport enforcer. ACCEPTED.**

- *Verified at `43d328b`:* the domain enforcers are real and have moved — see §Invariants enforced
  elsewhere, which records all three sites and the +14 line shift. The transport enforcer is still
  absent: `git_workspace_inspector.dart:107` runs `Process.run(git, args)` with no
  `environment:`, and the repository-wide search for
  `SSH_AUTH_SOCK|known_hosts|ssh-keyscan|StrictHostKeyChecking|IdentityFile` across `*.dart` and
  `*.sql` returns no match.
- *Consequence accepted.* ShipIt will not record or hand out trust it does not have, but **the
  connection itself is unverified**. A MITM against the git transport is not prevented by anything
  this ADR can point at; the human confirmation gates the *record*, not the socket. The stated
  guarantee "ShipIt refuses to connect to an unrecognised host" is therefore narrower in practice
  than it reads. Building the seam is security-critical prerequisite work and warrants its own
  review.

**A3 — The "local only" scope is a stated posture, not a property. ACCEPTED.**

- *Verified at `43d328b`:* unchanged. `docker/compose.yaml:16-17` publishes `5432:5432`
  unqualified, `:63` sets `SERVERPOD_DATABASE_PASSWORD: shipit` with `:62` the user line, and
  `.env.example:16-18` documents the same default; the loopback-pinning search still returns no
  match, and all nine mappings across the three compose files are unqualified.
- *Consequence accepted.* Under A3 the secret manager holding the private halves is expected to sit
  behind that same unenforced boundary, and the database that stores the credential reference is
  reachable on every interface with a committed default password. A3 **widens** this exposure from
  "a local QA database" to "the substrate holding production key references". Accepted for the
  local-only deployment scope on the ADR owner's instruction per `570bb640`; it is not acceptable
  for any topology wider than one machine, and nothing in the repository enforces the difference.

**A4 — The external secret manager's reachability has never been runtime-probed. ACCEPTED.**

- *Verified at `43d328b`:* still unprobed, and not probeable by this lane. `9417f8bf:133,149`
  records confidence **LOW** and states plainly that no substrate option was runtime-verified. A
  search for `secretmanager|secret_manager|vault|substrate` across `*.dart` under `apps/server/lib`
  and `packages/*/lib` returns **no match**, so no substrate adapter exists to have been probed. No
  Docker or Compose command was issued by this lane, so **no runtime probe was run and none is
  claimed**.
- *Consequence accepted.* The architecture records a dependency whose availability is unproven in
  the target topology, and whose failure mode is a common operating condition rather than a remote
  edge case. Implementing against it carries the risk that the chosen substrate is unreachable in
  the deployment that matters, discovered late. `9417f8bf` follow-up action 4 requires the probe
  before implementation is called complete.

## Known gaps

Remaining items. **None of these is one of the four accepted risks above**, and none is a
blocker on this ADR.

- **The `AGENTS.md` §13 carve-out this ADR relies on now exists — this gap is CLOSED as of
  `0bf2fa0`, re-verified at `43d328b`.** §Mitigation assumed "AGENTS.md §13 gains a git-specific
  carve-out pointing at this ADR", and §Related pointed at "AGENTS.md §13 — Penpot / Tooling
  Credentials", and at `6220951` neither existed: `AGENTS.md` had no §13 at all, so ADR 0012:34 and
  ADR 0019:121 cited absent text too. At `43d328b` the section exists — `AGENTS.md:65`
  (`### §13 Credentials`), `:72` (`#### §13a Referenced by name, never by value`) and `:78`
  (`#### §13b Git credentials — a scoped deviation`) — and `:91` states "one SSH deploy keypair
  per repository, referenced by name per §13a". `AGENTS.md:96-101` records the restoration
  explicitly and names this ADR, ADR 0012 and ADR 0019 as the dependents. **The §13-versus-0018
  contradiction is therefore resolved in prose, not merely documented.**
- **Rotation is still described in product scope in two places.** §Decision and §Positive both
  say rotation is "per product", which A1 made per-repository. Recorded rather than silently
  rewritten, per the convention above. No security consequence; a documentation reconciliation.

## Related

- AGENTS.md §13 — Credentials (`:65`), §13a — Referenced by name, never by value (`:72`),
  §13b — Git credentials, a scoped deviation (`:78`). This ADR carves out git only, and
  §13b:91 states "one SSH deploy keypair per repository", which is A1's scope. The section
  **exists** as of `0bf2fa0`; the earlier note that it did not is retired, see §Known gaps.
- ADR 0012 — Immutable Artifact Promotion (human gates only where required:
  production)
- ADR 0013 — Human Gates Are Durable Workflow States
- ADR 0015 — Worker Execution Layer (worktree isolation pinned to a revision)
- Checkpoint 006 — Product Registry and Onboarding
- Design Revision recording A2 —
  `docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-2.md`
  (revision 2 records the owner's acceptance and the four accepted risks)

### Decisions governing amendment A2

Recorded here so the ADR's own authority chain is legible from the ADR:

- `73097d48` — real deploy-key generation (PRODUCT, `OPTION_A`)
- `b869ec24` — server-side generation and storage (ARCHITECTURE, `OPTION_A`)
- `9417f8bf` — external secret manager, A3 custody (SECURITY, `OPTION_C`)
- `79e860e2` — destroy the manager handle on revoke (SECURITY, `OPTION_A`)
- `898b07d0` — split identity from registration (ARCHITECTURE, `OPTION_A`)
- `27ea6536` — footer copy and alignment (DESIGN, `OPTION_A`); no bearing on
  any clause of this ADR
- `570bb640` — accepted local-only deployment scope; see §Preconditions and §Accepted risks A3

### The acceptance itself

The owner accepted A2 and its four gaps on **2026-10-06** ("Accept A2, record the gaps as
accepted"), recorded in §Status. **There is no Human Decision object for it in `.decisions/`** —
that path is outside the design lanes' declared write scope, so the acceptance has no citable
decision id and its provenance is the structured-question answer relayed by the Manager and
`docs/engineering/WORK_STATE.md:326-327`. This is recorded here rather than papered over, because
the absence of an id is precisely what let a downstream artifact assert an acceptance that nothing
on disk supported. A decision object belongs to the Manager to create.
