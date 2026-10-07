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

**D-1 … D-14** are the producing and correcting lanes' entries, unchanged. **D-15 … D-19** were added by
**Revision 3** (2026-10-06) and are collected under the heading *"ADDED BY REVISION 3"* below, because
Revision 3 read its facts at **three different revisions** and labels every citation — see that heading for
the label table and for `D-16`, which is about that labelling being necessary at all.

**D-20 … D-24** were added by **Revision 4** (2026-10-06) and are collected under the heading
*"ADDED BY REVISION 4"* at the end of this file. **D-16's subject was this lane's own BLOCKER B1**, and
`D-20` is the executable form of the rule `D-16` only stated. Revision 4 read **every** fact at one
revision (`361256c`, its own base), so **it carries no label table** — the absence of one is the point, and
§ 0.3 of the revision carries a citation index instead.

**D-25 … D-31** were added by **Revision 5** (2026-10-06, base `5436a4d`) and are collected under the heading
*"ADDED BY REVISION 5"* below. **D-31 is escalated, not persisted** — it is `CONTRADICTION`-class and it
touches governance.

**D-32 … D-34** were added by **Revision 6** (2026-10-07, base `1c3f5ad`) and are collected under the
heading *"ADDED BY REVISION 6"* at the end of this file. **`D-32` and `D-33` are `PROJECT_FACT` and
automatic**; **`D-34` is `WORKFLOW_IMPROVEMENT` and is ROUTED, not auto-persisted.** Revision 6 read every
fact at **one** revision, so it **carries no label table** either.

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

---

# ADDED BY REVISION 3 (2026-10-06) — classified against the resolved Gate D4

The entries below are new. **D-1 … D-14 above are unchanged**, including the retracted D-6 and the
restated D-7. Revision 3 read its facts at three different revisions and labels every citation:

| Label | SHA | Contains |
|---|---|---|
| `[77c19f1]` | this lane's HEAD | ADR 0018, the control plane, compose files, the client page |
| `[07c8c8f]` | `fix/credential-store-integrity` (**read-only**) | the store, the engine, the credential tests, `D-1`/`D-2`, migration `20261006150645000` |
| `[6220951]` | `main` (**read-only**) | the six resolved decision objects |

Neither `07c8c8f` nor `674b871` is an ancestor of `77c19f1` — verified. That is itself `D-16`.

## D-15 — A design approved against unresolved human decisions is superseded when they resolve, and the approval's value is bounded by the open set

- **Category**: `WORKFLOW_IMPROVEMENT`
- **Product-specific**: no — **reusable framework knowledge**. Not persisted to the product repository's
  knowledge by me; routed per `LEARNING_POLICY.md` §2 to independent review (product repo) / the
  framework.
- **Authority**: independent review. **NOT** auto-persisted by this lane.
- **Evidence**: the whole sequence is on record.
  - Design Revision 2 (`F21D5C64-…`) was written against four unresolved Gate D4 sub-questions and two
    unresolved decisions, and deliberately defaulted none of them. **That was correct behaviour.**
  - The Independent Design Review returned `RESULT: DESIGN_REVIEW_APPROVED`, `REVIEWED_HEAD 77c19f1`,
    `INDEPENDENT_RISK_LEVEL: 3`, `RISK_LEVEL_AGREEMENT: YES`, and — importantly —
    **`HUMAN_DECISION_REQUIRED: YES`**, with § 3 of the report devoted to re-running the leakage hunt and
    stating the open set explicitly.
  - The human then resolved all six decisions (`674b871`, `2026-10-06T13:05:00Z`), and **five of them
    changed the design's normative content**. Revision 3 was required.
- **The finding.** *Open* is not an absence of risk. It is a **scope limit on the review**. A reviewer can
  verify that a design **correctly presents and correctly withholds** an open question; they cannot verify
  the content of an answer. So a Gate D3 approval of a design carrying `OPEN-D4-*` items certifies **the
  framing, not the design**. The generalisation: **"correctly deferred" is a claim a reviewer can check, and
  it is not the same as "ready to build."** A design that has discharged its duty to the human is not
  thereby discharged of the answer.
- **Two executable rules that follow**, recorded here **and in `design-revision-3.md` § 0.2** rather than
  only in a review report:
  1. **The approval record must name the open set.** `report-revision-2.md` did, and it is why this defect
     surfaced within hours rather than in implementation. Keep it.
  2. **A revision written against open decisions must carry a `SUPERSEDED_BY_DECISION` disposition
     before the resolutions land**, so the ledger marks it rather than a human noticing later. The
     Manager did that (`WORK_STATE.md`); the artifact did not. Revision 3 now carries it in
     `design-revision-2.md`'s header and in `design-revision-metadata-2.yaml`.
- **Why it is reusable rather than product-specific**: any framework that lets a human reserve a decision
  can produce this. The pattern is not about credentials; it is about any gate that can certify a design
  *framing* while a human decision is outstanding.

## D-16 — A revision whose evidence lives on branches that are not ancestors of its own HEAD cannot be verified from its worktree

- **Category**: `PROJECT_FACT`
- **Product-specific**: yes
- **Authority**: automatic
- **Evidence**: this lane's `BASE_SHA`/`HEAD_SHA` is `77c19f1`. Verified:
  `git merge-base --is-ancestor 07c8c8f 77c19f1` → not an ancestor; the same for `674b871` (the
  resolutions) and `3a87e27` (the commit where Revision 2's artifacts are tracked).
- **What it costs**: Revision 3's substantive claims are about work that exists **only** on
  `fix/credential-store-integrity` and about decisions that exist **only** on `main`. A reviewer running
  in `/private/tmp/shipit-correct-addproduct-keys` cannot check a single one of them. Revision 3 therefore
  labels every citation with the SHA it was read at (§ 0.4) and § 10.1 item 1 asks for a re-base.
- **Executable form of the check**, for any lane whose dispatch names a base SHA and whose task depends on
  later commits:

  ```bash
  for c in <sha-from-another-branch> <sha-of-the-decision-commit>; do
    printf '%s: ' "$c"
    git merge-base --is-ancestor "$c" HEAD && echo ANCESTOR || echo "NOT an ancestor — citations span revisions"
  done
  ```
- **Why it matters as a class**: a design revision is the artifact a reviewer holds, and its citations look
  verifiable by construction. They are only verifiable relative to a base. Producing a revision whose base
  predates the work it describes is a silent provenance defect — the *content* can be entirely correct
  (this one aims to be) and the artifact still cannot be checked where it is claimed to live.

## D-17 — `saveProductCredential`'s conflict branch is reachable ONLY by the mint path — verified from its five call sites

- **Category**: `PROJECT_FACT`
- **Product-specific**: yes
- **Authority**: automatic. **Persisted as executable knowledge**: it is checkable by reading five call
  sites, and `design-revision-3.md` § R.9.1 tabulates them so a future lane need not re-derive it.
- **Evidence** — every `saveProductCredential` call site in the engine at `[07c8c8f]`:

  | Call site | `expectedVersion`? | Branch |
  |---|---|---|
  | `engine:979` — `recordGeneratedCredential` (the mint) | **none** | **upsert** |
  | `engine:1011` — `confirmHostKey` | `c.version` | CAS |
  | `engine:1025` — `confirmHostKey` | `c.version` | CAS |
  | `engine:1066` — `recordCredentialCheck` | `c.version` | CAS |
  | `engine:1088` — `revokeCredential` | `c.version` | CAS |

  (Revision 2's anchors for the same four CAS sites were `engine:997, :1011, :1052, :1074` at `77c19f1`;
  the store-integrity lane shifted them by +14.)
- **Why it matters**: it is the **entire safety argument** for `D-4` (§ R.9.1's "the mint path never
  upserts"). Making the conflict branch insert-only cannot break `confirmHostKey`, `recordCredentialCheck`
  or `revokeCredential`, because none of them can reach it — they all use `copyWith` + CAS. Without this
  fact, a reader cannot tell whether `D-4` is safe or breaks revocation, and would have to reason about it
  from the interface alone.
- **The corollary that is easy to get wrong**: it holds *because* `copyWith` cannot set the four immutable
  fields. It is a coincidence of two design decisions, not a structural guarantee. If a future caller
  constructs a `RepositoryCredential` by hand and passes it with `expectedVersion`, the CAS branch is
  reachable — which is why `D-1` was specified to predicate **both** branches.

## D-18 — A revoked credential can be resurrected by an identical-material re-mint, and no existing test covers it

- **Category**: `ARCHITECTURE_DISCOVERY`
- **Product-specific**: yes
- **Authority**: **human decision / Manager** — this is a credential security invariant, and the required
  behaviour (`D-4`) is specified in `design-revision-3.md` § R.9.1–R.9.2 but **not implemented by this
  lane** (`C-09`: production code is prohibited). **Reported, not implemented.**
- **Evidence** — the path, entirely through the public domain API, at `[07c8c8f]`:
  1. `readActiveCredentialForRepository(repositoryId)` selects
     `WHERE "repositoryId" = @id AND "status" <> 'revoked'` (`postgres_product_registry_store.dart:370-381`),
     so a **revoked** credential is invisible to it.
  2. `recordGeneratedCredential`'s one-active guard (`engine:954-960`) is
     `if (active != null && active.credentialId != supersedesCredentialId) throw …` — and `active` is
     **null** for a repository whose only credential is revoked, so **the guard cannot fire**.
  3. A caller-supplied `credentialId` naming the revoked row, plus **identical** material, satisfies `D-1`'s
     predicate (`store:325-328`), which is *satisfied by identical values*.
  4. `$assignments` (`:226-240`) then writes `status = generated`, `revokedAt = NULL`,
     `revokedReason = NULL`, `hostKeyStatus = unknown`, `hostConfirmedAt = NULL`, `hostConfirmedBy = NULL`,
     `lastVerifiedAt = NULL`, `lastVerifiedBy = NULL`, `lastFailureReason = NULL`, `hostKeyFingerprint =
     NULL`, `createdAt = <now>`, `version = 1`.
  5. The row re-enters the **active set** as `generated`.
- **Why it is worse under `79e860e2` than it was before that decision**: revocation now **destroys the
  manager handle** (`design-revision-3.md` § R.6.1). So the resurrected row claims a deploy key that
  exists **nowhere** — and because it occupies the active set, `D-2`'s partial unique index then **refuses
  the legitimate fresh mint** for that repository.
- **What is covered and what is not**: `credential_test.dart:323` — *"a revoked credential cannot be
  re-checked into life"* — closes the **check** path (`recordCredentialCheck` refuses a revoked
  credential). It does **not** close the **mint** path. The distinction is easy to miss because both
  sentences contain *"revoked credential"*.
- **Recovery**: `rotateCredential` (revoke-then-mint), so it is recoverable — but the state in between is
  corrupted and the audit trail is falsified. Specified as `T-D` (§ R.9.5).
- **Why it is `ARCHITECTURE_DISCOVERY` and not `PROJECT_FACT`**: the fact is verified, but the required
  behaviour is a credential invariant that changes what the store guarantees. It needs a human/Manager
  dispatch decision, not a test.

## D-19 — Two binding decisions interact where neither object says so: a substrate refusal also has to answer whether the `Product` row is created

- **Category**: `CONTRADICTION`
- **Product-specific**: yes
- **Authority**: **human decision** — a `CONTRADICTION` touching governance/architecture escalates here.
  **Flagged in `design-revision-3.md` § 5.2 and § 10.1 item 3; not decided by me.**
- **Evidence**: `7b1bc8b7` scopes its fail-closed refusal to *"no keypair is generated and no credential
  row is created"*. `898b07d0` makes the `Product` row and the `RepositoryReference` **the key flow's first
  step**. Neither object mentions the other's row. So the question *"if the secret manager is down, does a
  `Product` row exist afterwards?"* is **unaddressed by both**, and the two literal readings disagree.
- **How I resolved it, and why it is not a decision**: revision 3 specifies that the substrate precondition
  is evaluated **before any write**, so a refusal creates **nothing at all**. The reasoning is that step 1
  of `898b07d0` exists solely to make the mint satisfiable; with no substrate it achieves nothing and
  produces `898b07d0`'s accepted bad state (a visible product with no usable credential) **without any of
  the benefit that made that state acceptable**. The alternative reading is available and is not forbidden.
- **Why this is reported rather than absorbed**: the two objects are Manager-owned and I cannot edit them
  (§ C-09 / dispatch scope), the interaction is genuinely under-specified, and a reviewer should be able to
  overturn the reading without arguing with me about it. It is **not** blocking — the user-visible result is
  an error with remediation either way, so it is not a Level 2 UX change.

## Not persisted

| Finding | Why not |
|---|---|
| The a11y contrast figures (4.23:1 / 6.74:1 / 6.10:1) | Inherited from `design-register-button/report.md:71-76`; **not re-measured by this lane**. Independently re-measured and confirmed by the Independent Design Review (`design-review-addproduct-keyservice/report.md:33`). Reported as inherited in the revision, and labelled as such at `N-8` |
| `flutter analyze` / `dart analyze` / build / test results | **NOT_RUN** by both the producing and the correcting lane. Reported as `NOT_RUN`; no feasibility gate is claimed from them |
| `T-A` / `T-B` test outcomes | Specified and reasoned from source; **not executed**. Predicted to fail today; the prediction is stated as a prediction, not a result |
| Whether a real SSH transport accepts the generated key | Requires a running stack; `UNVERIFIED` with the command named. **No Docker or Compose command was run by this correction lane, not even a read-only one** |
| `AGENTS.md §13` / `§13b` content | **Not invented.** `G-1′` records that the section is absent and names the three ADRs that depend on it. Writing it is a Manager/human action outside `OWNED_PATHS` |
| Any change to `9417f8bf`, `79e860e2`, `898b07d0`, `7b1bc8b7`, `27ea6536`, `4d2c6b81`, `WORK_STATE.md`, `LANES.md`, `DECISIONS.md` | **Manager-owned.** Revision 3 read all six resolved objects **read-only** at `[6220951]` and edited none. Required changes are listed in `design-revision-3.md` § 10.1; **not edited** |
| Any change to `docs/adr/**` — the ADR 0018 amendment | **Human-owned** as ADR owner; a sibling lane is drafting it. `design-revision-3.md` § R.17 states the dependency contract it must satisfy (`:85-88` and `:113-114` superseded; `:87-88`'s prohibition **kept**; `:100-102` **upheld, must not be touched**; `:29-30`'s shape superseded). **Not edited** |
| Any change to `apps/server/migrations/**`, the store, the engine, the client, or the golden baselines | `C-09` — production code is `PROHIBITED_PATHS` for this lane. `D-4`, `D-5`, `G-7`, the `SecretProvider`, and the `product_detail` golden regeneration are all **specified and not built**. **Not edited** |
| `T-A` / `T-B` outcomes | Reported as green **by the implementer's report at `07c8c8f`**. **Not re-run and not re-verified by this lane** — no test was run. Stated as a report, never as this lane's result |
| `T-C` … `T-G` (revision 3's new tests) | **Specified from source, not executed.** Their predicted failure is stated as a prediction derived from the code path, with the path shown, and never as a result |
| Whether a secret manager is reachable in this repository's target topology | `UNVERIFIED` — `G-10`. No secret manager exists here, no probe was run, and **this lane issued no Docker or Compose command at all**, not even a read-only one |
| Whether a real SSH transport accepts the generated key, and whether host-key `changed` is detected | Require a running stack. `UNVERIFIED` with the command named in `design-revision-3.md` § 9.4 |
| The duplicate-credential audit against a deployed database | `NOT_RUN`, and **not runnable from any lane**. Carried forward verbatim from the implementer's own disclosure: the query as dispatched **does not execute** (quoted camelCase), and the only credential-bearing reachable database holds 0 rows — a vacuous "no". **Human-owned deployment precondition** |
| a11y contrast ratios | **Inherited, not re-measured.** `design-register-button/report.md:71-76`; independently re-measured by the Gate D3 review. `N-8` binds revision 3's new remediation copy to the same token |

---

# ADDED BY REVISION 4 (2026-10-06) — after the Gate D3 review of Revision 3

`D-1 … D-19` above are **unchanged**, including the retracted `D-6`, the restated `D-7`, and `D-15`–`D-19`.

**Provenance for this section: one revision.** Revision 4's `BASE_SHA` *is* its `HEAD_SHA`, `361256c`, and
**every SHA it cites is a verified ancestor of that base** (output quoted in `design-revision-4.md` § 0.3).
There is no label table here because there is nothing to disambiguate — **which is the change, not the
absence of rigour.** Two sources sit outside the base and are labelled at every point of use:
`[UNCOMMITTED 0bf2fa0]` (the `D-4`/`D-5`/`D-18` implementation, read-only, uncommitted) and
`[UNCOMMITTED 6220951]` (the ADR 0018 amendment design, read-only, uncommitted). Contrast figures are
**inherited, not re-measured**.

## D-20 — A design citing SHAs that are none of them ancestors of its own base cannot be verified by anyone reviewing it: labelling is necessary but not sufficient, the base itself must move

- **Category**: `WORKFLOW_IMPROVEMENT`
- **Product-specific**: **no** — **reusable framework knowledge**
- **Authority**: **independent review**. **NOT auto-persisted by this lane**; routed per
  `LEARNING_POLICY.md` §2 to independent review (product repo) and onward to the framework.
- **Evidence**: Revision 3 was reviewed `DESIGN_REVIEW_CHANGES_REQUIRED` with **B1** as a blocker. Its
  `HEAD_SHA` was `77c19f1`. Its own § 0.4 stated the problem in advance — *"`07c8c8f` nor `674b871` is an
  ancestor of `77c19f1` … **A reviewer therefore cannot verify this revision from this worktree alone**"* —
  and labelled **every citation** with the revision it was read at. **The labelling was meticulous. It was
  also insufficient, and the reviewer's finding is the proof:**

  | Consequence of the stale base | Where it surfaced |
  |---|---|
  | **`LANES.md:204-205` was listed as a surviving false claim.** At `77c19f1` the file is **172 lines** with no such assertion; on `main` **line 205 reads the retraction** (landed `4e2d237`). § 10.1 item 6 would have sent the Manager to retract an already-retracted claim | B1 |
  | **`G-1′` was listed as open.** `0bf2fa0` restored `AGENTS.md` §13/§13a/§13b. § 10.1 item 7 asked for an action **already completed** | B1 |
  | **`ae1c1f79` appeared zero times** in all four artifacts. Revision 3's mtime is 13:31; the decision is `decided_at 13:50`. **The artifact predated the decision and therefore could not reflect it** | B1, H4 |

  The last row is the generalisable one. **A stale base does not merely make citations awkward to check — it
  makes the artifact structurally unable to contain facts that happened after it was written**, and nothing
  in the artifact can disclose that except a reader who goes and looks.
- **The rule, stated so it is actionable:**

  > **Provenance labelling is necessary and not sufficient.** Labelling answers *"where was this read?"*
  > when the reader is already holding the right tree. It cannot answer *"is this tree the one the design is
  > about?"*, and a citation label **actively conceals** the second question by making the first one
  > checkable. **When a design's subject matter lives on commits the base does not contain, the correct
  > response is to move the base, not to annotate the gap.** A revision that documents its own
  > unverifiability and asks to be re-based has done the right *diagnosis* and the wrong *remedy* — and the
  > remedy is the one thing that cannot be deferred, because everything downstream of it inherits the
  > defect.
- **The executable form**, which is what makes this more than an opinion. Any lane whose dispatch names a
  base SHA and whose task depends on later commits:

  ```bash
  # 1. Before writing: does the base contain the work the design is about?
  for c in <each commit the task depends on> <each commit holding a cited decision>; do
    printf '%-9s ' "$c"
    git merge-base --is-ancestor "$c" HEAD && echo ANCESTOR || echo "NOT AN ANCESTOR — RE-BASE FIRST"
  done

  # 2. Re-base, then re-run 1. Note the method: a fast-forward is not a rebase,
  #    and saying "rebased" when the base is a descendant implies a rewrite that
  #    did not happen.
  git merge --ff-only <main>

  # 3. Re-verify every gap entry and every citation against the NEW base. A gap
  #    entry is a CLAIM ABOUT THE TREE, so it is exactly as stale as the tree was.
  git show <new-base>:<path> | sed -n '<lines>'
  ```
- **The step that is easy to skip, and that produced both of B1's false entries:** re-reading the tree is
  not enough — **re-reading the *ledger* is not enough either.** `LANES.md` and `AGENTS.md` are prose
  documents about the tree, and they were as stale as the code. **Every claim in a gap register is a claim
  about some file, including the files that make claims about other files.**
- **What this cost here:** one full pass over four artifacts, and two Manager actions that would have been
  performed against already-correct state — which is not harmless. An action performed twice is a small
  embarrassment; an action performed on a *stale* reading of a governance document can be a wrong change to
  a live policy file.
- **Generalises to any artifact class** — a design revision, a QA contract, a review report, an ADR — and to
  any lane whose base is chosen before its subject matter is known.

## D-21 — A spec expressed only as a SQL statement, whose named tests live in an in-memory suite, will silently produce two tiers with different predicates

- **Category**: `WORKFLOW_IMPROVEMENT`
- **Product-specific**: **no** — **reusable framework knowledge**
- **Authority**: **independent review**. **NOT auto-persisted by this lane.**
- **Evidence**: Revision 3 specified `D-4` and `D-5` as changes to **SQL statements** in
  `postgres_product_registry_store.dart`, and named their tests `T-C`, `T-F` and `T-G` — which are **all** in
  `packages/product_registry/test/credential_test.dart`, an **entirely in-memory** suite. The two facts are
  in the same section of the same document and do not reconcile:

  | | Revision 3 said |
  |---|---|
  | the requirement | *"On the conflict branch, an `ON CONFLICT ("credentialId")` that matches an existing row must update nothing"* — a **statement** requirement, given with SQL |
  | the test home | *"belong in `packages/product_registry/test/credential_test.dart` beside the existing group 'key material is chosen once, at mint'"* — an **in-memory** home |

  And the in-memory tier's own predicate is built to make the disagreement visible:

  ```dart
  /// Whether [next] carries the same key material as [previous].
  ///
  /// The four fields that identify the keypair itself. `credentialId` is the
  /// map key, so it cannot differ here. `repositoryId`/`productId` are
  /// deliberately not part of this predicate: it mirrors the immutability the
  /// Postgres store's write enforces, and the two must agree.
  ```

  (`in_memory_product_registry_store.dart:196-209` **[361256c]**.) **The comment states the invariant the
  specification was about to break, and then the specification broke it** — after which `_credentials[id] =
  credential` (`:193`) overwrites wholesale. The words `InMemory`, `both tiers` and `memory tier` appeared
  **zero times** across all four Revision 3 artifacts.
- **Why a Postgres-only fix fails *silently* rather than loudly.** Two reasons, and the second is the
  dangerous one:

  1. **The named tests go red** — which is at least visible. `T-C`, `T-F`, `T-G` keep failing after the SQL
     is fixed, and the implementer is likely to conclude the *tests* are wrong.
  2. **The defect the specification was written to prevent then exists in production shape and is invisible
     to every gate that passed.** `product_credential_immutability_postgres_test.dart:29-31` says it
     explicitly: *"Asserted on this tier as well as in-memory, **because a predicate that exists on only one
     tier is the same defect this file exists to catch**."* A test that runs on one tier cannot detect a
     predicate that exists on one tier. **The test's own tier placement is part of its specification**, and
     a design that names a test without naming its tier has not specified the test.
- **The rule, stated so it is actionable:**

  > **A specification expressed as a statement is a specification of one tier.** Where an implementation has
  > two tiers — persistence and in-memory, real and fake, client and server, producer and consumer — the
  > requirement must be stated **per tier, with a construct for each**, and the test must be assigned a tier
  > **in the same table**. Two tiers holding different predicates is not a test failure; it is a *contract*
  > that no gate was watching.

- **The two corollaries that cost the most to learn, both found in this pass:**

  - **The constructs cannot be mirrors of each other.** Tier A's fix was `ON CONFLICT … DO NOTHING`, which
    **evaluates no column predicate at all** — so Tier B cannot implement it by copying the *idea* of a
    predicate, and any guard Tier B adds on that path is a guard Tier A **cannot see**. When that happened it
    **masked** the identity guard behind it: with `D-4` removed, the resurrection test still passed. **A
    per-tier specification must state which guards each tier can and cannot evaluate**, because "the tiers
    must agree" is otherwise an aspiration with no mechanism.
  - **The tier that cannot express a requirement is still a tier.** "This is a property of the database and
    cannot be demonstrated by an in-memory map" is true of a *unique index* and **false of a write
    predicate**. The in-memory store can and must hold the same write contract; what it cannot hold is the
    index. Conflating the two produces a design that specifies the database and forgets the map.

- **How to check a design for this class, in one question:** *for every requirement expressed as a statement,
  a query, or a schema object — is there a second tier, is the requirement stated for it, and is a named test
  assigned to it?* If the answer to any part is no, the tests cannot witness what the specification claims,
  and "the tests pass" is not evidence.

## D-22 — A `finally` that compensates for a partial effect destroys the effect on the success path, unless the construct distinguishes the two exits

- **Category**: `WORKFLOW_IMPROVEMENT`
- **Product-specific**: **no** — **reusable framework knowledge**. The specific instance is product-specific
  (a credential handle); the shape is not.
- **Authority**: **independent review**.
- **Evidence**: Revision 3 specified the compensation for a failed credential mint as
  *"**compensate**: `destroy(handle)` in a `finally`, then refuse"* (§ R.5.2 step 5) and *"inside a `try`,
  with `destroy(handle)` in the `finally` on any failure"* (§ R.14.1 step 5). **Two normative locations, one
  construct, and the construct cannot express the requirement**: **Dart has no failure-only `finally`.**
  `finally` runs on every exit path. On the literal reading of both sentences the **success** path destroys
  the handle it has just recorded — which is the exact forbidden state the same section names as the reason
  compensation exists. Neither sentence was a typo; both read as though they said what they meant, and the
  reviewer found the defect by noticing that **the literal reading of both sentences is the same defect**.
- **Why it survived the author's own reasoning.** The intent was in the section title and in a test
  specification; the failure was in the **expression**. The author's mental model had a "failure branch", and
  `finally` reads like one to anyone not holding the language's control flow in their head. **A specification
  is read literally by an implementer who has never met its author**, and `finally` is the one keyword whose
  literal meaning is the opposite of the idiomatic one in most languages where people *do* have a
  failure-only construct.
- **The generalisable rule:**

  > **A design that compensates for a partial effect must state the construct, not the intent — and must
  > state it once, in one place, with the same words at every other site that needs it.** "Compensate on
  > failure" is an intent. A success flag, or catch-and-rethrow, is a construct. Two sites that need the same
  > construct and each describe it in their own words will eventually disagree — and the disagreement is
  > invisible until one of them is wrong.

  Three sub-rules, each of which this instance needed separately:

  1. **"Destroy the resource on failure" needs a success signal.** A success flag set immediately after the
     effect, or `catch (e, s) { …; rethrow; }`. **Never** a bare `finally` around the effect.
  2. **The compensating call's own failure must not mask the original.** An exception thrown from a
     `finally` **replaces** the in-flight exception. That is the same defect class as the teardown rule in
     `AGENTS.md` § Test resource hygiene — *"never discard its output … Silencing a teardown with
     `> /dev/null 2>&1 || true` turns a leaked container into a silent pass"* — applied to the mint path.
     Best-effort, audited, never rethrown.
  3. **Assert the success path explicitly, or nothing tests it.** The compensating behaviour is what every
     failure test exercises. **The success path needs its own assertion** — here, *after a successful mint the
     resource still resolves* — or a construct that destroys on success and one that does not are
     **indistinguishable from the outside**. That is why the finding's counterpart assertion was the thing
     that would have caught it, and why it is now specified: **a partial-effect design needs a test on
     *both* paths, and the success-path test is the one nobody writes.**

## D-23 — A capability enforced at one layer and not at another is described by whichever sentence a reader reaches first

- **Category**: `DESIGN_DISCOVERY`
- **Product-specific**: yes
- **Authority**: automatic
- **Evidence**: Revision 3 said, in **two** normative locations, that `HostKeyStatus.permitsConnection` *has
  **no runtime enforcer*** and that *"ShipIt refuses to connect to an unrecognised host"* is *decorative
  today*. **Both were over-broad**, and the correction came from outside this lane — the ADR 0018 amendment
  design's § 3.1 **[UNCOMMITTED 6220951]**, which found:

  | Layer | Status | Verified at `361256c` |
  |---|---|---|
  | **Domain** | **ENFORCED** — `recordCredentialCheck` (`engine:1047-1052`), `requireUsableCredential` (`engine:1162-1167`), `confirmHostKey` (`engine:1003-1015`), `canReachRepository` (`repository_credential.dart:128-129`) | all present |
  | **Transport** | **NOT ENFORCED** — `git_workspace_inspector.dart:106-112` runs `Process.run` with no `environment:`; the five host-key tokens grep to **0** matches | confirmed |

  The amendment design's own phrasing is the finding: *"A blanket 'decorative' label would have been false,
  and would have invited a reviewer to trust a gate that exists."* **Note the direction of the error.** The
  over-broad claim was *conservative* — it understated what is built — and it still caused harm, because
  `G-4` was scoped as *"nothing enforces this"* when the accurate scoping is *"one half enforces it"*, and
  the half that does not is the half a reader would not go looking for.
- **The rule:** **a capability enforced at one layer and not at another is not one capability with a gap; it
  is two capabilities, and a single adjective cannot describe both.** When a design writes *"X has no
  enforcer"*, the check is not whether that is true of the strongest enforcer — it is **which layer the
  sentence is about**, because the reader will build their threat model on whichever layer the sentence
  implies. This is the mirror image of `D-21`, and it is the same shape of mistake: **one word standing in
  for a set of things that differ.**
- **The fix, and it is a table not a sentence:** `design-revision-4.md` § R.7.1's threat-model row is now
  **split into two rows** — *host-key trust at the domain layer: enforced* and *host-key trust at the
  transport layer: nothing enforces it* — and § R.10.3 states the accurate normative sentence: **"SHIP IT
  will not *record* trust it does not have, and will not *hand out* a credential for an unconfirmed host.
  The connection itself is unverified."** ADR 0018 `:96-99` is then classified as **half-implemented**, which
  is more useful than "unimplemented" because it names what already exists and therefore what the remaining
  work is.
- **Also recorded, because the same review found it:** the amendment design cited `engine:1033` and `:1148`,
  which are **its** base (`6220951`). At `361256c` they are **`:1047` and `:1162`** — the store-integrity work
  shifted engine line numbers by **+14**. **Adopting a sibling lane's finding requires re-verifying its
  citations against your own base**, and the offset is knowable only by checking.

## D-24 — `get`-then-`create` is not get-or-create when both writes are `ON CONFLICT DO UPDATE`

- **Category**: `DESIGN_DISCOVERY`
- **Product-specific**: yes
- **Authority**: automatic (a verified fact about the existing code) · **the required behaviour** is
  `PROJECT_FACT`-shaped and specified in `design-revision-4.md` § R.14.1 step 3 as gap **`G-13`**
- **Evidence**: Revision 3 specified the split-identity flow's second step as *"Create the `Product` row
  (`ProductState.registered`) and the `RepositoryReference` if absent — `createProduct` and
  `addRepositoryReference`, **both idempotent by read-then-write**."* **Neither write is idempotent**, and the
  finding surfaced only because correcting `H2` forced me to read what those two methods actually do:

  ```dart
  // saveProduct, null expectedVersion — store:91-101
  INSERT … ON CONFLICT ("productId") DO UPDATE SET
    "name" = EXCLUDED."name", …, "state" = EXCLUDED."state",
    "createdAt" = EXCLUDED."createdAt", …

  // saveRepositoryReference — store:127-145
  INSERT … ON CONFLICT ("repositoryId") DO UPDATE SET
    "productId" = EXCLUDED."productId", "kind" = EXCLUDED."kind",
    "uri" = EXCLUDED."uri", …, "addedAt" = EXCLUDED."addedAt", …
  ```

  So the "read-then-write" makes the *caller* responsible for skipping the write, and if it does not: a
  re-entering user **resets the product's `state` to `registered`** — **un-committing a product that had
  already committed credential verification** — rewrites its `name` and `createdAt` (falsifying the
  record's age), and rewrites the reference's `uri` and `addedAt`.
- **Why the phrasing is the defect.** *"idempotent by read-then-write"* is a description of a **call
  discipline**, wearing the noun for a **property of the write**. The write is not idempotent; the sequence
  is only safe if a caller cooperates, and **"both idempotent" invites exactly the opposite reading** — that
  calling them again is harmless. It is not harmless; it is the mechanism by which a product silently loses
  its committed state.
- **The rule:**

  > **"Idempotent" is a property of the operation, not of the caller's discipline.** A design that writes
  > *"X is idempotent by read-then-write"* has specified a convention and labelled it a guarantee. The
  > distinction matters wherever a step is reachable **twice** — and in a flow whose entire purpose is to be
  > **re-enterable**, every step is reachable twice, by design.

  The check is cheap and general: for each step of a re-enterable flow, ask **what happens if this exact call
  is issued twice**, and check the answer against the *write*, not against the plan.
- **Second instance of the same shape, in the same file, recorded together because it is the same lesson:**
  `readActiveCredentialForRepository` **excludes revoked rows**, and Revision 3 read that exclusion as
  evidence that *"a revoked credential correctly does not come back"*. It does not; the query answers
  *"what credential is in force"*, and its answer was then used as if it answered *"has anything ever
  happened here"*. The `product_credential` table has **two** questions about its credentials and **two**
  reads; Revision 3 used one for both, and a revoked credential became **invisible** (gap `G-14`). **A
  predicate written for one question will answer a different one correctly, and nothing will complain.**

## Not persisted — Revision 4

| Finding | Why not |
|---|---|
| The a11y contrast figures (4.23:1 / 6.74:1 / 6.10:1) | **Inherited** from `design-register-button/report.md:71-76`; **not re-measured** by this lane, and **no contrast tool was run**. Independently re-measured by the Gate D3 review. Reported as inherited, and labelled as such at `N-8` |
| `flutter analyze` / `dart analyze` / build / test results | **NOT_RUN** by this lane. Reported as `NOT_RUN`; no feasibility gate is claimed from them |
| `T-A` … `T-K` outcomes | `T-A`/`T-B` reported green **by the implementer's report at `07c8c8f`** — **not re-run and not re-verified by me**. `T-C`…`T-K` **specified, not executed**; their predicted pre-fix failures are stated as predictions from the code path with the path shown, never as results |
| The `fix/credential-identity-invariants` gates | **NOT_RUN by me.** That lane reports format/analyze/unit/integration/schema passing and its review re-ran them. **I do not adopt its results as mine**, and the review found a MEDIUM gap in its own guard (`verify_schema_bootstrap.sh:267` — the `IF NOT EXISTS` normalisation forgives the one divergence in that clause that breaks the chain path) |
| Whether A3 is reachable in this repository's topology | **`UNVERIFIED` — `G-10`.** No secret manager exists here, no probe was run, and **this lane issued no Docker or Compose command at all**, not even a read-only one |
| Whether a real SSH transport accepts the generated key, and whether host-key `changed` is detected | Require a running stack. **`UNVERIFIED`**, with the command named in `design-revision-4.md` § 9.4 |
| **Any deletion** | **NONE MADE by this lane.** Files were created and edited only under `docs/engineering/dispatch/tasks/design-addproduct-keyservice/**`. No file was deleted, moved or renamed anywhere in the repository, and no such action is claimed. (A prior lane's report asserted deletions that had not happened; recording the *absence* is the honest form) |
| The duplicate-credential audit | **`NOT_RUN`, and not runnable from any lane.** Carried forward verbatim with the disclosure that the query as dispatched **does not execute** and that the only credential-bearing reachable database held **0 rows** — a vacuous *"no"*. Now in **both** gap registers as **`G-12`** |
| `docs/adr/**`, the ADR 0018 amendment | **Human-owned** as ADR owner. A sibling lane drafted it and the human **Accepted** it. `design-revision-4.md` § R.17.1 records its state and § R.17 states the contract it was written against. **Not merged, not edited, not authored by me** |
| `WORK_STATE.md`, `LANES.md`, `DECISIONS.md`, `AGENTS.md`, `.decisions/**` | **Manager-owned**, outside `OWNED_PATHS`. Required changes are listed in `design-revision-4.md` § 10.1; **not edited.** Two of them (`LANES.md`'s false claim, `AGENTS.md`'s missing §13) were already resolved on `main` — see `D-20` |
| Any change to production source, tests, goldens or migrations | `PROHIBITED_PATHS` for this lane. `D-4`, `D-5`, `D-6`, `G-7`, `G-13`, `G-14`, `SecretProvider` and the `product_detail` golden regeneration are all **specified and not built**. **Not edited** |

---

# ADDED BY REVISION 5

**D-25 … D-31**, added 2026-10-06 by the Revision 5 correction pass. Read at **one** revision —
`5436a4d`, this lane's own base, re-based from `361256c` by `git merge --ff-only main` — so, like
Revision 4, **this block carries no label table**; the absence is the point, and `design-revision-5.md`
§ 0.3 carries the citation index and the per-artifact `git hash-object` content pins instead.

## D-25 — WORKFLOW_IMPROVEMENT (reusable) · **ROUTED, NOT AUTO-PERSISTED**

> **A CLAIM OF HUMAN ACCEPTANCE WITH NO RECORD BEHIND IT SURVIVES A REVIEW CYCLE IF IT IS REPEATED
> ENOUGH TIMES.** Repetition is not corroboration: **thirteen restatements of an unsourced claim look like
> thirteen sources.**

Design Revision 4 asserted the ADR 0018 amendment was *"Accepted by the human"* in **thirteen-plus places**
across four artifacts, and **one of § 9.1's six risk reasons rested on it**. At Revision 4's own base
(`361256c`) **nothing on disk said so**: the amendment's metadata read `status: DRAFT`, `reviewed_by: null`,
`approved_by: null`, `human_gate.required: true` at level 3, with a blocking item reading, verbatim, *"ADR
0018 status remains Proposed. This lane does not declare it Accepted."* — and `.decisions/` held no
acceptance object. This is reviewer finding **B5**.

Two corollaries, both learned the hard way:

1. **A risk tally is the ONE place a status claim must be earned**, because a tally is precisely what a
   reviewer reads to see whether the reasoning was done. **A tally one leg optimistic because a
   dependency's status was asserted rather than read is worse than a missing leg** — it converts an
   absence into a false positive, and a false positive in a risk rationale is the kind that survives
   review, because it makes the artifact look *more* considered than it is. The tally is republished as
   **0 IMPROVED / 2 UNCHANGED / 4 WORSE**, and Revision 4's withdrawn sentence is printed beside it rather
   than deleted.
2. **An accepted artifact and a reviewed artifact are different things, and the distinction must travel
   WITH the claim.** It existed — inside the amendment's own `acceptance_is_not_review` field and the ADR's
   *"What acceptance is NOT"* bullet — but not where the claim was repeated. **A caveat stored only in the
   artifact it qualifies will not be read by the artifacts that cite it.** Revision 5 states
   *acceptance is not review* in § 0.2, § R.17.1 and `requirements_covered`, beside the claim itself.

The acceptance is now real and citable — Human Decision `876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml`
(`ARCHITECTURE`, `RESOLVED`, owner's verbatim answer *"Accept A2, record the gaps as accepted"*) and
amendment revision 2 (`status: ACCEPTED`). **The lesson is not that acceptance is doubtful; it is that a
claim of acceptance must carry its citation with it, wherever it is made.**

## D-26 — DESIGN_DISCOVERY (product-specific) · **automatic** · *new gap `G-16`*

> **CHOOSING A NARROWER STORE METHOD REMOVES WHATEVER GUARD THAT METHOD CONTAINED, AND NOTHING ON THE
> PATH IS LEFT TO SAY SO.**

This is the most serious finding of the Revision 5 pass, and it was **introduced by Revision 4's own
correction of a blocker**. Revision 4 fixed finding `H2` by moving `mintOrReadDeployKey`'s get-or-create
read from `engine.readActiveCredential` — which opens with `readRepositoryReference` and then calls
`_ensureOwned` at **`engine:1140`** — to the store's `readActiveCredentialForRepository`, which filters on
`"repositoryId" = @repositoryId AND "status" <> 'revoked'` (`postgres_product_registry_store.dart:370-381`;
`in_memory_product_registry_store.dart:221-232`) and **has no notion of a product and no `_ensureOwned` at
all**. **Choosing the store method is the bypass.**

Two claims Revision 4 made to justify it were both false, and both were checkable:

- *"by step 4 ownership is already established, because step 3 created the reference under `productId`"* —
  step 3 **does not establish ownership**. `addRepositoryReference` (`engine:150-170`) calls
  `await _store.readProduct(productId)` at **`engine:159`**, annotated in its own source
  `// existence + scope`, and that is **existence only** — it never calls `_ensureOwned`. And under
  `G-13`'s read-first discipline the subsequent write is **skipped whenever the reference already exists**.
  So on exactly the cross-product case, **step 3 performs no write and no check.**
- *"this endpoint does not call it and does not bypass it"* — false, and withdrawn by name.

**Consequence, verified:** `mintOrReadDeployKey(productId: 'A', repositoryId: <a repository of B>)` returned
**B's** `publicKey`, `credentialId`, `status`, `hostKeyStatus` and `alreadyExisted: true` — on an endpoint
that `design-revision-5.md` § R.15.1 records as carrying **no authentication services**
(`apps/server/lib/server.dart:71-73`) with loopback pinning un-implemented. **No step of Revision 4's
§ R.14.1 raised the `CrossProductAccessException` its own error table promised.**

**The generalisable rule: a "simpler, lower-level" substitution is a security-relevant edit unless you
diff what the removed call was doing.** The store method was chosen because it was the one that returned
`null` on a first mint instead of throwing — which is exactly what it was chosen for, and the guard was
inside the method that was rejected.

**Second instance in the same correction pass, recorded together because it is the same lesson.**
`saveRepositoryReference`'s conflict branch sets **`"productId" = EXCLUDED."productId"`** (`store:137`). So
calling `addRepositoryReference` with an **existing** `repositoryId` and a **different** `productId` does not
fail, does not warn, and does not touch a scope column — **it reparents the repository**, moving the
ownership graph out from under every credential already attached to it. `G-13`'s blast radius named five
rewritten columns and **omitted this one**, because the column was not in its list. **A hazard inventory
that lists only the columns someone already thought about is not a hazard inventory.** § R.10.0 now carries
the full seven-column and six-column sets and names the reparenting mechanism; `G-13`'s read-first
discipline is therefore **load-bearing rather than a footnote**.

## D-27 — DESIGN_DISCOVERY (product-specific) · **automatic**

> **A REQUIREMENT BOX AND ITS TWO IMPLEMENTATION CONSTRUCTS CAN DISAGREE ABOUT A SET, AND NOTHING NOTICES,
> BECAUSE THE PROSE AROUND THEM REASONS ABOUT THE MISSING MEMBER.**

`D-6`'s requirement box (`design-revision-5.md` § R.9.4) named **eight** durable-evidence columns.
Revision 4's Tier A construct (`_noClear` per column) and Tier B construct (`_clearsDurableEvidence`)
covered **seven**: **`lastFailureReason` was silently absent from both**, with no rationale — while the
paragraph immediately below the box explained at length why the *failure* branch's write of
`lastFailureReason` must be permitted. The column is real, nullable `text`
(`apps/server/migrations/20261006150645000/definition.sql:632`) and is written by `recordCredentialCheck`'s
failure branch (`product_registry_engine.dart:1061-1065`). **An implementer following Revision 4's
constructs ships `lastFailureReason` erasable on the CAS branch, on both tiers** — the one diagnostic
column, cleared by nothing more than a caller omitting a parameter. Reviewer finding **H9**.

**Why the prose made it worse rather than better.** The surrounding argument *mentioned* the missing
column, which is exactly what makes the omission invisible: a reader skims for the column, finds its name
in the discussion, and concludes it is covered. **A discussion of a member is not coverage of it.**

**The check that catches this is not a count — it is writing the set out member by member on a separate
line and comparing it against each construct.** Revision 5 decides the set **once, as eight**, gives each
column's type and its `definition.sql` line, adds the clause to Tier A and the disjunct to Tier B, makes
**`T-K` assert all eight by name**, and makes *"name the members and compare"* step 2 of the reviewer
checklist (§ 10.2). The set is now also stated in `§ R.9.5`, `SC-17`, `§ 12`'s read-path table and the
`G-13`-adjacent prose, so **no single construct can drift without contradicting four other places.**

## D-28 — DESIGN_DISCOVERY (product-specific) · **automatic**

> **A CONSTRUCT THAT ACCEPTS TWO FORMS MUST SPECIFY THE SAME OBLIGATIONS ON BOTH — AND THE SAMPLE IS THE
> SPECIFICATION AN IMPLEMENTER COPIES.**

§ R.5.7 (the compensation construct, added by Revision 4 to fix blocker B2) states **five obligations** and
declares that *"the required behaviour is identical"* between its two accepted forms. Revision 4's **FORM 2
did not meet obligation 4**, which requires the private-half buffer to be *"zeroed on every path, success
included"*:

```dart
final handle = await provider.put(binding, privateHalf);   // ✗ outside any try
try   { await engine.recordGeneratedCredential(/* … */ referenceName: handle); }
catch (error, stack) { await destroyQuietly(handle); rethrow; }   // ✗ ends here
zero(privateHalf);                                          // ✗ UNREACHABLE after rethrow
```

A `put` throw propagates past `zero(privateHalf)` entirely, so **the only copy of a freshly generated private
half stays live in a long-lived object** — and the trailing zero is not merely misplaced, it is
**unreachable**, because `rethrow` never returns. Reviewer finding **H8**.

The fix is one mechanism: **`finally` runs on every exit path, including a `rethrow`**, so obligation 4
becomes structural rather than a statement someone must remember to place after the last exit.
**`catch` keeps the `destroy`; `finally` keeps the `zero`. They are not interchangeable** — moving
`destroy` into the `finally` would **re-introduce blocker B2**, because `finally` also runs on the success
path. That asymmetry is the whole content of the construct, and it is why neither obligation alone is
sufficient.

**A second, smaller instance of the same rule, in the same section.** Revision 4's prose said
`destroyQuietly` *"must be **skipped**, not made with a null argument"* on the `put`-throws path — while
**FORM 1's `finally` called it unconditionally** inside `if (!recorded)`, which is reached with a `null`
handle **exactly** when `put` throws, because `recorded` is still `false` and `handle` was never assigned.
**The sample and the sentence disagreed, and the sample is the one an implementer copies.** Both forms now
guard on `handle != null`, and § 10.2's item 1 now asks the reviewer three questions of **each** form —
which is the generalisable form of the rule: **if you accept two shapes, enumerate the failure paths of
each, and check the sample against the prose.**

## D-29 — WORKFLOW_IMPROVEMENT (reusable) · **ROUTED, NOT AUTO-PERSISTED**

> **A SHA PINS A COMMIT, NOT CONTENT.** Provenance labelling answered *"where was this read?"*; the base
> check answered *"is this tree the one the design is about?"*. **Both were still insufficient**, because the
> working tree can differ from the commit the SHA names.

`D-20` (Revision 4) recorded that provenance labelling is necessary and not sufficient and made the
**base move** executable. This pass found the remaining half, in the most literal way available: Revision 4's
four artifacts were **untracked** in this worktree and **tracked on `main`** after the re-base, and
`git merge --ff-only main` **refused to run** because the merge would overwrite untracked files. I compared
all four with `git hash-object` against the blobs `main` carried — **all four identical** — moved the
untracked copies to a backup directory outside the repository, and proceeded. Had they differed, the
re-base would have silently substituted different content for the content a reviewer had read.

**The closure is one command per artifact, and it is now `design-revision-5.md` § 0.3, the metadata's
`provenance.content_pins`, and § 10.2's item 10 — where *"any artifact's blob hash differs from the
metadata's"* is a named falsifier.** Revision 4's four hashes are recorded too, so the content this
revision corrected is itself pinnable. Executable knowledge, per `LEARNING_POLICY.md`'s preference for
executable over prose.

## D-30 — WORKFLOW_IMPROVEMENT (reusable) · **ROUTED, NOT AUTO-PERSISTED**

> **A CORRECTION PASS CAN INTRODUCE A DEFECT WORSE THAN THE ONE IT FIXES, AND THE ONLY SIGNAL IS THE
> DIRECTION OF THE GAP COUNT.**

Revision 4 found **three** new defects in the specified flow (`G-13`, `G-14`, `G-15`). **This pass found
three more, and the worst of them was manufactured by Revision 4's own correction of a blocker** (`G-16`,
see `D-26`). Nothing about the workflow distinguishes a corrective edit from an additive one: both are
*"small, local, reviewable"*, both touch a named section, and both are the kind of change a reviewer has no
reason to distrust — because **a change that fixes a blocker is the change a reviewer is least likely to
read adversarially.**

The only cheap signal is the **direction of the gap register**. A correction pass that leaves the count flat
has probably done nothing; one that raises it has done something, and the question is whether what it added
outweighs what it removed. That question is answerable in one read of § R.18.2, and it is now recorded as
part of R4's reasoning in § 9.1 — where R4's status is **WORSE** and says so in those words:
*"this time one of them was manufactured by the previous pass."*

**A concrete, transferable sub-rule: in a correction pass, re-read your own prior pass's *rationale*, not
only its *output*.** Revision 4's H2 justification — *"ownership is not re-derived here"* — was the sentence
whose removal created the disclosure. It read correctly; it was **about the method it replaced**.

## D-31 — CONTRADICTION (product-specific) · **ESCALATED, NOT PERSISTED** · new gap `G-17`

> **ADR 0018's own text now falsely denies its own acceptance.**

`docs/adr/0018-per-product-git-credentials.md:16-21` (*"no Human Decision object on disk records this
acceptance"*, *"A decision object should be created by the Manager so the acceptance has a citable id"*) and
its section *"The acceptance itself"* (`:572-580`, *"There is no Human Decision object for it in
`.decisions/`"*, *"the acceptance has no citable decision id"*) are **both false as of `5436a4d`**.
**Human Decision `876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml` exists and was committed in the SAME COMMIT
(`5436a4d`, *"docs(adr): record ADR 0018 A2 acceptance"*) that landed that ADR text.**

This is **the same class as the absence `B5` was created to fix** — an absence recorded as fact in an
artifact — now sitting **inside the ADR itself**, in the document every future lane cites for custody. It
matters more here than it did in the design artifact: a design revision is read by reviewers who are told to
check it, and an ADR is read as settled record by lanes that have no reason to question its provenance.

**REPORTED, NOT EDITED.** `docs/adr/**` is `PROHIBITED_PATHS` for this lane, and **no such edit is claimed**.
Owner: **the ADR lane, or the human as ADR owner** — two sentences in one file. Recorded as **`G-17`** in
both gap registers and as `design-revision-5.md` § 10.1 action **1b**.

---

# ADDED BY REVISION 6 (2026-10-07) — recorded at base `1c3f5ad`

**D-1 … D-31 are unchanged**, including the escalated-and-not-persisted `D-31` above. Revision 6 read its
facts at **one** revision (`1c3f5ad`), so like Revision 4 it **carries no label table** — the absence of one
is the point, and `design-revision-6.md` § 0.3 carries the citation index's successor instead.

## D-32 — A correction map a document tells a reviewer to TRUST must be swept against its targets before the document ships

- **Category**: `PROJECT_FACT` · **Product-specific**: yes — **automatic** persistence
- **Authority**: automatic. Evidence-backed, and the rule is about this repository's own artifacts.

> Revision 5's § 0.4 was a nineteen-row table mapping each review finding to the section that corrected it.
> Revision 5's § 10.2 instructed the reviewer that *"each item is now checkable — what to run and what would
> falsify it."* The independent review found **two of the rows it spot-checked were BOTH wrong**:
> `L8` still asserted `:925` was the *desktop* `TechnicalDetails` — the inversion **Revision 5's own body
> corrected at `:2414`**, and which it also contradicted in two sibling artifacts; and `M5` described the ADR
> amendment as *"uncommitted and unmerged"* when it was **committed and landed at that very base**, and pointed
> at a § 10.1 action that **had been withdrawn and replaced by 1a/1b**.

**Why this is the finding that matters more than its size.** A design revision is not read end to end by a
reviewer; it is *spot-checked at the places the artifact nominates*. So a table whose stated purpose is
*"here is where each finding landed"* is not documentation — **it is the review's index**, and a wrong row
does not merely misinform, it **actively misdirects the check it exists to enable**. Revision 4's inversion
survived into the map and would have survived into the next review if the reviewer had not happened to read
the body first.

**The rule, and it is the executable form:** *before a correction artifact ships, sweep **every** row of any
table it nominates for a reviewer's trust against the section each row names — not only the rows that are
suspect.* Revision 6 performed that sweep and reports its result in `design-revision-6.md` § 0.4.1: 16 of 19
rows check out, 2 were wrong, and **1 further error was found that the reviewer had not looked for** (the
`L13` row claimed pins *"per artifact"* when three of four existed). Reporting the sweep's **limit** as well
as its result matters as much as the sweep: § 0.4.1 states that the rows were checked against the *sections*,
not against every `file:line`, so the next reviewer knows exactly what is and is not certified.

## D-33 — Closing a provenance gap can create the conditions for the next one; a gap closure must record its residue

- **Category**: `PROJECT_FACT` · **Product-specific**: yes — **automatic** persistence

> Revision 5 disclosed a `PROVENANCE_GAP`: the Rev-4 review report *"does not exist in any worktree, in the
> canonical repository, or in any commit reachable from any ref."* That was **true at `5436a4d`** and became
> **false at `289f1d3`** — the commit whose subject is *"persist the rev4 review that never landed"* — which is
> the very HEAD at which Revision 5 was reviewed. Closing that gap required the **same pre-flight** that
> immediately uncovered a **second, larger** one: Revision 3's four artifacts had **never been added on any
> ref**, and **eleven supersession banners** — the very thing that makes a six-revision chain readable — were
> **modified and uncommitted**.

**The rule.** *A provenance-gap closure is only honest if it records what the gap was **hiding**.* Folding
the residue into the closure would have produced a cleaner-looking artifact and a **less** accurate one: the
closure would have read as "provenance is now sound" while the chain's own supersession was still off-disk.
`design-revision-6.md` therefore registers the residue as a **separate** entry, **`G-20`**, and says in § 0.5
that it is registered separately *"precisely so that closing one gap is not a reason to stop looking"*.

The generalisable form: **gaps are rarely independent.** They share a cause — in this case, a review report
that was returned but never written before it was relayed. A closure that verifies one instance of a cause
and stops has verified the instance, not the cause.

## D-34 — A lane must check a Manager premise about *where an artifact lives*, not adopt it — and the check is one command

- **Category**: `WORKFLOW_IMPROVEMENT` (reusable) · **ROUTED, NOT AUTO-PERSISTED**
- **Authority**: independent review. Reported for the framework's dispatch hygiene; **not** persisted to the
  product repository's knowledge by this lane, and **no workflow change is made as a side effect**.

> The dispatch for Revision 6 stated: *"`design-revision-3.md` is **no longer an untracked file** — it exists
> and is committed on `main`."* It is **not**, for this lane: `git log --all --diff-filter=A --
> …/design-revision-3.md` returns **empty**. The premise is **true for two other lanes** — `16cd497` adds
> `design-adr-0018-amendment/design-revision-3.md` and `4e2d237` adds
> `design-addproduct-mobile/design-revision-3.md` — which is almost certainly how the premise arose: a
> **glob** matched, and a glob matching *three* `design-revision-3.md` files says nothing about whether the
> *right* one is committed.

**Why it was checked rather than adopted.** The dispatch's instruction was to **retire Revision 3** on the
strength of that premise. Adopting it would have removed a 137,494-byte revision from the record on a false
statement about where it lives — and this work item has **already** produced three false *"artifact absent"*
conclusions and one lane that accepted a Manager premise which turned out false. The dispatch itself warned
about this and **the warning was correct**.

**The rule, and it is one command:** *before acting on a premise about an artifact's location, run
`git log --all --diff-filter=A -- <exact path>`. An empty result means never committed on any ref; a
non-empty one tells you **which** commit and therefore **which** file.* `git ls-files` and `git status` both
answer the wrong question — the first reports the index, the second the working tree — and a `ls` or a `grep`
across a directory tree answers a third. This lane checked four ways before declining.

Owner of the underlying facts: **Manager** — Revision 3's four artifacts and the eleven uncommitted banners
need a commit decision. Recorded as **`G-20`** in both gap registers. See `design-revision-6.md` § 0.3.3.

## Not persisted — Revision 5

| Finding | Why not |
|---|---|
| The a11y contrast figures (4.23:1 / 6.74:1 / 6.10:1) | **Inherited** from `design-register-button/report.md:71-76`; **not re-measured** by this lane and **no contrast tool was run**. Reported as inherited, and labelled as such at `N-8` |
| `flutter analyze` / `dart analyze` / build / test results | **NOT_RUN** by this lane. Reported as `NOT_RUN`; **no feasibility gate is claimed from them** |
| `T-A` … `T-L` outcomes | `T-A`/`T-B`/`GAP-2` reported green **by the implementer's report at `07c8c8f`** — **not re-run and not re-verified by me**. `T-C`…`T-L` **specified, not executed**; their predicted pre-fix failures are predictions from the code path with the path shown, never results |
| The `fix/credential-identity-invariants` gates | **NOT_RUN by me.** That lane's results are **not adopted as mine** |
| Whether A3 is reachable in this repository's topology | **`UNVERIFIED` — `G-10`, and ADR accepted risk A4.** No secret manager exists here, no probe was run, and **this lane issued no Docker or Compose command at all**, not even a read-only one |
| Whether a real SSH transport accepts the generated key | **`UNVERIFIED`**, with the command named in `design-revision-5.md` § 9.4 |
| **Any deletion** | **NONE MADE by this lane.** Files were created and edited only under `docs/engineering/dispatch/tasks/design-addproduct-keyservice/**`. **No tracked file was deleted, moved or renamed anywhere in the repository.** Four *untracked* copies of Revision 4's artifacts were moved to a backup directory **outside** the repository to unblock a fast-forward, after their hashes were compared against `main`'s — recorded here rather than presented as nothing |
| The duplicate-credential audit | **`NOT_RUN`, and not runnable from any lane.** Carried forward verbatim with the disclosure that the query as dispatched **does not execute** and that the only credential-bearing reachable database held **0 rows** — a vacuous *"no"*. Now in **both** gap registers as **`G-12`** |
| `docs/adr/**`, the ADR 0018 amendment, and `G-17` | **Human-owned** as ADR owner. A sibling lane drafted the amendment; it is **human-accepted** (`876c6b97`) and **merged at `5436a4d`**; it has **never been independently reviewed**. `design-revision-5.md` § R.17.1 records all of it, including the ADR's own now-false *"no decision object"* statements. **Not merged, not edited, not authored by me** |
| The Rev-4 review report | **ABSENT** from every worktree, the canonical repository, and every reachable commit. **This revision is corrected against the Manager's relay**, with every finding's evidence re-verified against source at `5436a4d`. `design-revision-5.md` § 0.7 |
| The mobile lane's artifacts and Penpot | **PROHIBITED_PATHS.** That lane is blocked on Penpot (token-to-instance binding) and four of its boards carry `Art S` text that is **false under A3**. § R.11g carries a *"what the sibling lane needs"* block so its next pass does not have to reach me. **Edited none of it** |
| `WORK_STATE.md`, `LANES.md`, `DECISIONS.md`, `AGENTS.md`, `.decisions/**` | **Manager-owned**, outside `OWNED_PATHS`. Required changes are listed in `design-revision-5.md` § 10.1; **not edited** |
| Any change to production source, tests, goldens or migrations | `PROHIBITED_PATHS` for this lane. `D-4`, `D-5`, `D-6`, `G-7`, `G-13`, `G-14`, `G-16`, `SecretProvider` and the `product_detail` golden regeneration are all **specified and not built**. **Not edited** |

## Not persisted — Revision 6

| Finding | Why not |
|---|---|
| **The `Footer` text layer at 236,862 on the four desktop boards** | **CITED, NOT MEASURED.** Two independent read-only Penpot measurements — the sibling lane's `penpot-board-evidence.md` § 6.4, and the Rev-5 reviewer's own live pass — agree on it, and both are named as **source of evidence, not as authority**. **This lane called no Penpot tool and read no board**; it holds no board ownership and every board is `PROHIBITED_PATHS`. Re-verifying would have required a board the lane does not own, and an unowned second measurement would not have made the first more true. Recorded as **`G-18`** in both registers, with the required edit specified and an owner named — **the gap is registered, not closed** |
| **`27ea6536`'s `supersedes_design_lane_reading` and `follow_up_action` #3** | **`CONTRADICTION` — ESCALATED, NOT PERSISTED.** Both assert something two independent reviewers have since measured to be false. **`.decisions/**` is `PROHIBITED_PATHS`: nothing was written there and no such edit is claimed. **The exact append-only record fix is specified**, ready to apply, in `design-revision-6.md` § 6 — following the `876c6b97` precedent, changing no line above the marker. **NOT a re-opening**: the outcome stands untouched and the human is **not** asked to re-decide the footer. Recorded as **`G-19`** |
| **The false Manager premise about `design-revision-3.md`** | **`CONTRADICTION` — ESCALATED, NOT PERSISTED.** It is the Manager's own dispatch text, so persisting it into the product's knowledge would make the repository assert something about a dispatch it does not own. Recorded in `design-revision-6.md` § 0.3.3 and as **`D-34`** (routed for independent review) and **`G-20`** |
| **Whether Revision 3's artifacts and the eleven banners should be committed** | **Not this lane's call.** `COMMITTED: NO` was instructed. **Manager action** |
| The footer spec, the three code edits, and `design_primitives.dart:396` | **Confirmed by the Rev-5 reviewer against source, and NOT re-derived.** This lane re-read both source files at `1c3f5ad` only to confirm its citations still resolve — **a citation check, not a re-argument** |
| The Rev-4 review report's own contents | **Read at `289f1d3`/`1c3f5ad`** for the M-R5-4 reconciliation. That reconciliation is **recorded**; the report's findings are Revision 4's input, not this lane's discovery |
| Any gate result | **No analyzer, build, test, contrast measurement or integration run.** Every `NOT_RUN` remains `NOT_RUN`. **No feasibility claim is drawn from any of them** |
| **Any Docker or Compose command** | **NONE ISSUED**, not even a read-only one. **This repository has already lost its QA database** to a lane running `docker compose -f docker/compose.qa.yaml down -v --rmi local`. The rule was **not tested**, because testing it is the forbidden act. Compose files were **not read** |
| **The 9417f8bf / 876c6b97 scope notes' corrected reading** | **Cited, not adjudicated.** The Manager appended them at `1c3f5ad`; both decisions are cited **at that scoped reading** and **neither is re-opened**. **No accepted-risk count changed** |
