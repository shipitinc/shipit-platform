# Durable discoveries — lane `design-addproduct-keyservice`

Classified per `docs/engineering/LEARNING_POLICY.md` § Classification categories. Each carries
exactly one category, a product-specific/reusable judgement, and the authority level required to
persist it.

**Authority note.** This lane's `OWNED_PATHS` is
`docs/engineering/dispatch/tasks/design-addproduct-keyservice/**`. `WORK_STATE.md`, `.decisions/**`
and `docs/engineering/dispatch/LANES.md` are Manager-owned, so I have **persisted nothing outside my
owned paths**. Findings marked below as *Manager action* are reported, not written into the ledger.
`PROJECT_FACT` and `DESIGN_DISCOVERY` are automatic-persist per the policy; `ARCHITECTURE_DISCOVERY`
and `CONTRADICTION` require a human decision and are escalated, not persisted by me.

---

## D-1 — The ledger's "zero deploy-key infrastructure" VERIFIED FACT is false

- **Category**: `CONTRADICTION`
- **Product-specific**: yes
- **Authority**: human decision / Manager (governance + architecture)
- **Evidence**: `WORK_STATE.md:329-330` and `DEC-b869ec24`'s context claim "no deploy-key
  infrastructure exists server-side", citing a grep for `deployKey`/`deploy_key`. Re-verified at
  `77c19f1`:

  ```bash
  grep -rn "RepositoryCredential\|recordGeneratedCredential\|product_credential" \
      apps/server/lib packages --include="*.dart"
  ```

  returns `RepositoryCredential` (`repository_credential.dart:36`), `CredentialStatus`/`HostKeyStatus`
  (`credential_status.dart:6,41`), the `product_credential` table (`repository_credential.spy.yaml:2`,
  present in 12 `definition.sql` migrations), `RepositoryCredentialView`
  (`repository_credential_view.yaml`), four store methods (`product_registry_store.dart:39-55`), the
  Postgres implementation (`postgres_product_registry_store.dart:173-320`), the mapper
  (`ui_view_mappers.dart:169`), and **six engine methods** — `recordGeneratedCredential` (912),
  `confirmHostKey` (974), `recordCredentialCheck` (1020), `revokeCredential` (1058),
  `rotateCredential` (1084), `requireUsableCredential` (1138).

- **Why it matters**: the wrong grep produced a *false architectural conclusion* ("this is net-new
  capability"), which would have led a future lane to invent a parallel credential abstraction beside
  `RepositoryCredential` — the exact thing dispatch R4 calls a review blocker. The naming is
  `credential`, not `deploy_key`.
- **Reusable lesson** (framework candidate): *before concluding "capability X does not exist", search
  for the domain's own vocabulary, not the requester's vocabulary.* A grep built from the words in a
  feature request is a grep that will miss the implementation.
- **Persistence**: reported to the Manager for `WORK_STATE.md` + a superseding decision note. **I did
  not edit them** (outside `OWNED_PATHS`).

## D-2 — The exact greps that would have prevented D-1

- **Category**: `PROJECT_FACT` (executable knowledge)
- **Authority**: automatic (evidence-backed)
- **Content**: the surface a future session must not re-derive:

  | Question | Command |
  |---|---|
  | Does credential infrastructure exist? | `grep -rn "RepositoryCredential\|recordGeneratedCredential\|product_credential" apps/server/lib packages --include="*.dart"` |
  | Does any endpoint expose a credential view? | `grep -c "RepositoryCredentialView" apps/server/lib/src/endpoints/*.dart` → **0** for all 11 files |
  | Is there SSH host-key verification? | `grep -rn "SSH_AUTH_SOCK\|known_hosts\|ssh-keyscan\|StrictHostKeyChecking\|IdentityFile" apps packages --include="*.dart" --include="*.yaml"` → **no match** |
  | Is the control plane authenticated? | `sed -n '71,72p' apps/server/lib/server.dart` → declares no authentication services |
  | Are compose bindings loopback-pinned? | `grep -rn "127.0.0.1:" docker/*.yaml apps/server/docker-compose.yaml` → **no match** |

- **Preferring executable knowledge**: per `LEARNING_POLICY.md` § "Prefer executable knowledge", these
  five commands are the durable form of this finding. Each returns a different answer than the
  corresponding claim in the ledger.

## D-3 — `HostKeyStatus` has no runtime enforcer; the git transport passes no environment

- **Category**: `ARCHITECTURE_DISCOVERY`
- **Authority**: human decision (architecture)
- **Evidence**:
  - `packages/worker_runtime/lib/src/workspace/git_workspace_inspector.dart:106-112` —
    `Future<String> _capture(List<String> args) => Process.run(git, args)`, with **no `environment:`
    argument**. Neither a credential nor a host-key policy can reach the transport today.
  - A repo-wide grep for `SSH_AUTH_SOCK|known_hosts|ssh-keyscan|StrictHostKeyChecking|IdentityFile`
    across `apps` and `packages` returns **no match**.
- **Why it matters**: the domain's most careful security property — a host that is not `confirmed`
  cannot be connected to (`HostKeyStatus.permitsConnection`) — is currently **decorative with respect
  to runtime**. Any design that assumes "the engine refuses unconfirmed hosts" is assuming an
  enforcement that does not exist. This affects any design that touches the credential path, not only
  mine.
- **Escalated**: to the Manager as a named prerequisite for the `implement-addproduct` lane.

## D-4 — Registering a product cannot be gated on a credential, because minting requires the product

- **Category**: `ARCHITECTURE_DISCOVERY`
- **Authority**: human decision (architecture + product)
- **Evidence**: `recordGeneratedCredential` (`engine:912-967`) calls
  `readRepositoryReference(repositoryId)` and `_ensureOwned(productId, repo.productId)` at `:924-925`;
  `addRepositoryReference` (`:150-174`) requires the product to exist; `createProduct` (`:43-63`)
  hardcodes `state: ProductState.registered`. So the enforced order is
  `createProduct → addRepositoryReference → recordGeneratedCredential → confirmHostKey →
  recordCredentialCheck`.
- **Why it matters**: human point 2b ("Register product is dependent on this key generation and trust
  of this host") is therefore **circular** against the domain — the gate depends on an artifact that
  the gated action creates. This is the same structural defect class as the current
  `canRegister == false`, arriving through a different route. Any future lane designing "generate on
  URL input, then gate registration on the key" will hit this and must not paper over it.
- **Not in the dispatch brief**; found by reading the engine. Surfaced as **OPEN-D4-2** with three
  options and a recommendation. Escalated, not decided.

## D-5 — `RepositoryCredential.copyWith` cannot change key material or identity

- **Category**: `PROJECT_FACT`
- **Authority**: automatic
- **Evidence**: `repository_credential.dart:137-172` — `copyWith` accepts only `status`,
  `lastVerifiedAt`, `lastVerifiedBy`, `lastFailureReason`, `hostKeyStatus`, `host`, `hostKeyFingerprint`,
  `hostConfirmedAt`, `hostConfirmedBy`, `revokedAt`, `revokedReason`, `version`. It has no parameter
  for `credentialId`, `productId`, `repositoryId`, `referenceName`, `publicKey`, `fingerprint`,
  `algorithm` or `supersedesCredentialId`, and `props` (`:180-202`) includes them all.
- **Why it matters**: this immutability is what makes silent key rotation **structurally** impossible
  rather than merely discouraged, and it means the substrate of a stored private key cannot be changed
  for an existing credential without rotation. That is a design constraint a future lane would
  otherwise have to rediscover — and it is the reason `DEK`-style repointing is safe by default.

## D-6 — ~~ADR 0018 and `AGENTS.md §13a` do not exist in this repository~~ — **RETRACTED 2026-10-06**

> **RETRACTION (revision 2, after Independent Design Review blocker B1).** **The ADR half of this
> entry is FALSE and is withdrawn. The `AGENTS.md` half is TRUE and survives.**
>
> `docs/adr/0018-per-product-git-credentials.md` **exists** — 158 lines, status *"Proposed (amended —
> A1)"*. `docs/adr/` holds **21** ADRs, `0001`–`0021`. The search below ran `ls docs/engineering/adr/`,
> which legitimately contains only the three framework-distribution ADRs. **13 production files cite
> ADR 0018 by number**, several by amendment — `postgres_product_registry_store.dart:172`,
> `product_registry_store.dart:35`, `repository_credential.spy.yaml:4`,
> `repository_credential_view.yaml:1`, `repository_credential.dart:10` and `:22`,
> `credential_status.dart:1` and `:36`, `repository_provider.dart:8`, `product_state.dart:1`,
> `product_registry_engine.dart:898` and `:1057`, `exceptions.dart:213`, `ui_view_mappers.dart:138`,
> `products_page.dart:308` — **including files this entry cited as evidence of its own absence.**
>
> `AGENTS.md` genuinely has **no §13** and **no §13b** (129 lines; `Product-specific policy` is `TBD`
> at `:59-63`). That is now recorded as **`G-1′`** in `design-revision-2.md` § R.21.1 — a real gap, and a
> *larger* one than this entry claimed, because ADR 0018 `:140-141`, ADR 0012 `:34` and ADR 0019 `:121`
> all depend on text that does not exist.
>
> The original text is retained below unchanged, as the audit trail of how the error was made.
> **The copies in `WORK_STATE.md` and `LANES.md` are Manager-owned and must be corrected by the
> Manager — I did not and cannot edit them.**

- **Category**: `CONTRADICTION`
- **Authority**: human decision / Manager (governance)
- **Evidence (ORIGINAL — first half false, see retraction above)**: `ls docs/engineering/adr/` →
  `0001-framework-distribution-and-versioning.md`, `0002-dart-mason-git-framework-driver.md`,
  `0003-product-generic-orchestrator-skill.md`. `AGENTS.md`
  sections are `Inherited invariants`, `Orchestration`, `Product-specific policy`,
  `Framework provenance` — no §13. Cited in nine places: `repository_credential.dart:10`,
  `credential_status.dart:1,36`, `product_registry_store.dart:7,35`,
  `repository_credential.spy.yaml:4`, `repository_credential_view.yaml:1`,
  `product_registry_engine.dart:898`.
- **Why it matters**: the credential model I was told to design onto is governed by a document that
  cannot be read. Any lane touching credentials will either cite ADR 0018 without having read it, or
  — worse — invent its content and present it as authoritative. I recorded **ten** substitute
  assumptions (`design-revision.md` § R.21) instead, each with the code that evidences it, so a
  reviewer can falsify any of them.
- **Reusable lesson**: *a code comment citing an ADR id is not evidence the ADR exists. Verify the
  citation resolves before reasoning from it.*
- **Escalated**: correcting the dangling citations is a Manager action (outside my `OWNED_PATHS`).

## D-7 — The loopback-pinning mitigation is not implemented — **a confirmed-unimplemented follow-up to `570bb640`, not a first-time finding** (`L5`)

> **Framing corrected in revision 2.** `DEC-570bb640`'s own context already records this exposure:
> `570bb640:22-27` (*"that property is currently NOT enforced by anything in the repository. No Docker
> Compose file pins a host interface"*) and `:67-72` (*"0 of 10 port mappings … use a `127.0.0.1` host
> prefix"*). So this is a **re-confirmation of a known, still-unimplemented follow-up** — the
> genuinely new information is only that it is still unimplemented at `77c19f1`. It is not a
> newly-discovered defect and must not be presented as one.

- **Category**: `PROJECT_FACT`
- **Authority**: automatic
- **Evidence**: `grep -rn "127.0.0.1:" docker/*.yaml apps/server/docker-compose.yaml` → **no match**.
  `docker/compose.qa.yaml:17,56,74` publish `5432:5432`, `8080:8080`, `8081:8081` unqualified, which
  Docker resolves to `0.0.0.0`.
- **Why it matters**: `DEC-570bb640` (RESOLVED, OPTION_B) relies on the "local only" premise being
  enforced, and names the pinning as a follow-up action. The decision's *accepted risk is therefore
  currently live on any shared network*. A design that cites `570bb640` as though the scope were
  enforced would be citing an intention, not a control. Recorded as a verified negative so no lane
  repeats the assumption.
- **Note**: read-only file inspection only. **No Docker or Compose command was executed by this lane.**

## D-8 — `RepositoryCredentialView` carries no `publicKey`

- **Category**: `PROJECT_FACT`
- **Authority**: automatic
- **Evidence**: `repository_credential_view.yaml:7-26` lists `credentialId`, `repositoryId`,
  `referenceName`, `fingerprint`, `algorithm`, `status`, `hostKeyStatus`, `host`,
  `canReachRepository`, `lastVerifiedAt`, `lastVerifiedBy`, `lastFailureReason`, `hostConfirmedAt`,
  `hostConfirmedBy`. **No `publicKey`.**
- **Why it matters**: the existing credential wire type cannot express a key-export response, so the
  mint endpoint needs a dedicated type. The upside is that the public half can stay **out** of the
  `ProductDetailView` read surface entirely — a better default than widening an existing view.
  Also: the type exposes `referenceName` to clients, which under server-side storage becomes a
  path/ARN disclosure (gap `G-7`).

## D-9 — The access-check control has zero producers of its success value

- **Category**: `DESIGN_DISCOVERY`
- **Authority**: automatic
- **Evidence**: `grep -rn "canRegister\|canGenerateKey\|AccessStatus\." apps/control_plane/lib` shows
  `AccessStatus.verified` appearing only in **predicates and labels** (`:235,563,609,659,731,884,1059,1105`),
  never as an assignment. The only `accessStatus:` assignment is `:118 → notChecked`. So
  `canRegister` (`:233-236`), which requires `verified`, is constantly `false`.
  Separately, `canGenerateKey` (`:230`) has **zero** call sites, and `deployKey` is assigned only at
  `:117` from inside `_buildKeyBox`, which renders only `if (state.deployKey != null)` — a bootstrap
  deadlock.
- **Why it matters**: finding B5 is not "the check needs wiring"; it is **two** independent defects —
  an unreachable success value *and* a deadlock that prevents the key panel from ever rendering. A
  correction lane fixing only the first would still see no key panel.

---

# Revision 2 addendum — correction lane `design/correct-addproduct-keys`

Added by the correction lane that produced Design Revision 2
(`F21D5C64-006D-4203-A813-841E08E38B95`) at `77c19f1`. **Revision 1's entries D-1…D-9 above are
retained as written**, except D-6 (retracted in place, original text preserved) and D-7 (framing
corrected in place per review `L5`).

**Ownership.** Same `OWNED_PATHS`. `WORK_STATE.md`, `LANES.md`, `DECISIONS.md` and `.decisions/**`
remain Manager-owned and were **not** touched. **No Docker or Compose command was executed by this
correction lane** — not even a read-only one.

## D-10 — The wrong-identifier pattern: two false "artifact absent" conclusions in one session

- **Category**: `AUTOMATION_OPPORTUNITY` (the fix is a mechanical preflight, not prose)
- **Authority**: independent review, per `LEARNING_POLICY.md` § Authority level 2
- **Product-specific**: the two instances are; the *pattern* is a framework candidate

Two independent claims of "this artifact does not exist" were made in this session, and **both were
false**, and **both were then propagated** into `WORK_STATE.md`, `LANES.md` and two Human Decision
objects before review caught them. They share one shape: a search was built from the **requester's**
vocabulary, or from a **guessed** directory, and its empty result was read as proof of absence.

| # | False claim | Wrong identifier used | What actually exists | The grep that would have prevented it |
|---|---|---|---|---|
| 1 | *"no deploy-key infrastructure exists server-side"* (`WORK_STATE.md:329-330`, `DEC-b869ec24` context) | `deployKey` / `deploy_key` — **the requester's words** | The domain's own name is **`credential`**: `RepositoryCredential`, `CredentialStatus`, `HostKeyStatus`, `product_credential`, `RepositoryCredentialView`, 4 store methods, 6 engine methods, 16 tests | `grep -rn "RepositoryCredential\|recordGeneratedCredential\|product_credential" apps/server/lib packages --include="*.dart"` |
| 2 | *"ADR 0018 … does not exist in this repository"* (`WORK_STATE.md:484-490`, `LANES.md:204-205`, `D-6`, `.decisions/898b07d0`, `.decisions/9417f8bf`) | `docs/engineering/adr/` — a **guessed** directory | `docs/adr/0018-per-product-git-credentials.md`, 158 lines, and **21** ADRs in `docs/adr/` | `ls docs/adr/` **and** `grep -rn "ADR 0018" apps packages --include="*.dart" --include="*.yaml"` → **13 hits** |

**Why the second is the more dangerous one.** Instance 1 fails *open* — a missing grep becomes an
invented abstraction beside the real one, which a reviewer can spot. Instance 2 fails **closed into
false confidence**: it produced a *traceability gap* entry asserting that the governing architecture
was unreadable, plus ten "substitute assumptions" presented as unverified inference where seven were
in fact recorded ADR decisions. A reader would have reasoned about a security-critical credential
design while believing its governing constraints were unavailable.

**The rule, stated so it can be applied mechanically:**

> Before concluding *artifact X does not exist*: (a) find the **domain's own vocabulary** for X and
> search that, not the requester's phrasing; (b) if X is a **cited identifier** — an ADR number, a
> decision id, a `§N` reference — search for **the citations themselves** and follow one to its
> source; an identifier that appears 13 times in production code is not absent; (c) enumerate
> candidate locations with `glob`, not `ls` on one guessed path.

**Executable form.** Per `LEARNING_POLICY.md` § "Prefer executable knowledge", the durable artefact is
the two commands above, not this paragraph. The automation opportunity is a preflight that runs
before any "does not exist" claim is recorded: resolve every ADR/decision identifier appearing in
`docs/**` and `apps/**` comments against the filesystem, and fail loudly on an unresolvable one. That
would have caught instance 2 automatically and cost one command.

## D-11 — `product_credential.publicKey` is overwritable in place through the engine's own API

- **Category**: `PROJECT_FACT`
- **Authority**: automatic
- **Evidence** (all read at `77c19f1`):
  - `postgres_product_registry_store.dart:177-243` — `saveProductCredential`. With a **non-null**
    `expectedVersion` it runs a guarded `UPDATE … WHERE "credentialId" = @id AND "version" = @expected`
    (`:212-236`). With a **null** `expectedVersion` it runs
    `INSERT … ON CONFLICT ("credentialId") DO UPDATE SET $assignments` (`:238-243`), where
    `$assignments` (`:195-210`) sets `"publicKey"`, `"fingerprint"`, `"algorithm"`, `"referenceName"`,
    `"repositoryId"`, `"productId"`, `"status"` …
  - `engine:965` — `await _store.saveProductCredential(credential);` **with no `expectedVersion`**.
  - `engine:920` — `String? credentialId` is caller-supplied.
  - `engine:940-941` — `if (active != null && active.credentialId != supersedesCredentialId) throw`.
  - Therefore `recordGeneratedCredential(credentialId: <existing>, supersedesCredentialId: <same>,
    publicKey: <new>, fingerprint: <new>, …)` passes the guard, and `engine:950-964` builds a fresh
    `RepositoryCredential` (`status: generated` at `:959`, `version: 1` at `:963`) that the upsert
    writes over the existing row — `copyWith` is **not** on this path.
  - `rotateCredential` (`engine:1084-1119`) is a second route: it forwards an optional
    caller-supplied `credentialId` (`:1091`, `:1117`) into `recordGeneratedCredential`.
  - The existing test at `credential_test.dart:206` uses `credentialId: 'cred-2'` with **no**
    `supersedesCredentialId`, so it exercises the second-*row* refusal, never the same-id replacement.
- **Why it matters**: `RepositoryCredential.copyWith` cannot change `publicKey`
  (`repository_credential.dart:137-172`), which reads like a structural guarantee. It is not one. Any
  claim that silent key rotation is *impossible* is false at the boundary that persists the row —
  which is the only boundary that matters for a stored secret. `credential_test.dart` gives false
  confidence: it passes today for the wrong reason.

## D-12 — A version CAS alone would NOT close D-11, because the mint path hardcodes `version: 1`

- **Category**: `ARCHITECTURE_DISCOVERY`
- **Authority**: human decision (architecture) — it changes a persistence invariant
- **Evidence**: `recordGeneratedCredential` constructs its object with `version: 1`
  (`engine:963`) and calls the store with no `expectedVersion` (`engine:965`). A row created by an
  earlier mint is **also** at version 1. So passing `expectedVersion: 1` would match the
  `WHERE "version" = @expected` clause at `store:214`, the `UPDATE` would affect one row, and
  `publicKey` would still be overwritten. The engine already uses CAS correctly on the other four
  credential writers — `engine:997` (`confirmHostKey`), `:1011`, `:1052` (`recordCredentialCheck`),
  `:1074` (`revokeCredential`) — which is exactly why the pattern is tempting and exactly why it is
  insufficient on the one path that must not version-check a fresh insert.
- **Why it matters**: the obvious fix, copied from four call sites in the same file, does not work.
  The guard has to be expressed on the **immutable fields** themselves — a predicated
  `ON CONFLICT ("credentialId") DO UPDATE SET … WHERE "publicKey" = @publicKey AND "fingerprint" =
  @fingerprint AND "algorithm" = @algorithm AND "referenceName" = @referenceName RETURNING
  "credentialId"` — which cannot be satisfied by a caller who did not already know the stored values.
  An implementer who copies the neighbouring CAS pattern will ship a fix that appears to work and does
  not. Specified as required deliverable `D-1` in `design-revision-2.md` § R.15b.1.

## D-13 — ADR 0018 A1's one-per-repository invariant is documented but not a database constraint

- **Category**: `ARCHITECTURE_DISCOVERY`
- **Authority**: human decision (architecture)
- **Evidence**: `apps/server/migrations/20261001205247600/definition.sql:645-647` declares exactly
  three indexes on `product_credential`: a **unique** one on `credentialId`, and **non-unique** ones
  on `repositoryId` and `productId`. ADR 0018 A1 `:19-21` states *"`RepositoryCredential` is keyed by
  `repositoryId`"*. The one-active rule is an untransacted read-then-write
  (`engine:940` read, `engine:965` write) whose `ON CONFLICT` is keyed on `credentialId`. Two
  concurrent mints therefore both pass the read and both insert → **two active credentials for one
  repository**.
- **Why it matters**: the platform's most-cited credential invariant is enforced by a convention in
  one method, so the guarantee is exactly as strong as that method's absence of a race. The safe
  predicate is already in the codebase: `readActiveCredentialForRepository` selects
  `WHERE "repositoryId" = @id AND "status" <> 'revoked'` (`postgres_product_registry_store.dart:262`),
  so `CREATE UNIQUE INDEX … ON product_credential (repositoryId) WHERE status <> 'revoked'` is
  consistent with the read by construction. Specified as required deliverable `D-2`
  (`design-revision-2.md` § R.15b.2). **Proposed only** — `C-09` forbids this lane creating migrations.

## D-14 — The live database is reachable with committed default credentials, and A2 puts the key there

- **Category**: `RUNTIME_DISCOVERY`
- **Authority**: automatic
- **Evidence**:
  - `docker/compose.yaml:62` — `SERVERPOD_DATABASE_PASSWORD: shipit`, in a **committed** file.
  - `docker/compose.yaml:16-17` — `- "5432:5432"` unqualified, which Docker resolves to `0.0.0.0`.
  - `.env.example:16-18` — `POSTGRES_DB=shipit`, `POSTGRES_USER=shipit`, `POSTGRES_PASSWORD=shipit`.
  - `.decisions/570bb640-…yaml:34-37` and `:73-75` record exactly this exposure as evidence.
- **Why it matters**: any argument that at-rest *encryption* helps because "a backup alone no longer
  discloses the key" is **false comfort in this topology**. The live database is the
  least-protected component in the system, and an attacker needs no backup — they need port 5432 and
  a password that is published in the repository. This inverts the usual threat ordering, where the
  database is the trusted tier and backups are the risk. Recorded in `design-revision-2.md` § R.4 A2
  *Against*, § R.7.1 and § R.18 point 4.

---

## Not persisted

| Finding | Why not |
|---|---|
| The a11y contrast figures (4.23:1 / 6.74:1 / 6.10:1) | Inherited from `design-register-button/report.md:71-76`; **not re-measured by this lane**. Independently re-measured and confirmed by the Independent Design Review (`design-review-addproduct-keyservice/report.md:33`). Reported as inherited in the revision, and labelled as such at `N-8` |
| `flutter analyze` / `dart analyze` / build / test results | **NOT_RUN** by both the producing and the correcting lane. Reported as `NOT_RUN`; no feasibility gate is claimed from them |
| `T-A` / `T-B` test outcomes | Specified and reasoned from source; **not executed**. Predicted to fail today; the prediction is stated as a prediction, not a result |
| Whether a real SSH transport accepts the generated key | Requires a running stack; `UNVERIFIED` with the command named. **No Docker or Compose command was run by this correction lane, not even a read-only one** |
| `AGENTS.md §13` / `§13b` content | **Not invented.** `G-1′` records that the section is absent and names the three ADRs that depend on it. Writing it is a Manager/human action outside `OWNED_PATHS` |
| Any change to `9417f8bf`, `79e860e2`, `898b07d0`, `WORK_STATE.md`, `LANES.md`, `DECISIONS.md` | **Manager-owned.** Reported with the exact required change in `design-revision-2.md` § 10; **not edited** |