> ## SUPERSEDED BY DESIGN REVISION 5 — `traceability-matrix-5.md`
>
> **Retained verbatim. No body line below has been edited** — only this banner is added. Its `BASE_SHA`
> and `HEAD_SHA` (`361256c`) are its own and are **not** current; the chain is now at `5436a4d`.
>
> **Revision 4 was returned `CHANGES_REQUIRED` and was never approved.** Three corrections are carried in
> `traceability-matrix-5.md`: the `AC-12` tally is **0 IMPROVED / 2 UNCHANGED / 4 WORSE**, not
> 1/1/4; rows 47, 50, 56, 57, 60, 61, 62 and 68 are revised and rows 72–74 are new (`G-16`, `rotateCredential`'s
> caller-supplied `credentialId`, `G-17`); and the ADR-amendment row is **CITED and MERGED, never
> reviewed**, where this matrix records it as an uncommitted sibling worktree.
>
> **⚠ The Rev-4 review report is ABSENT** — see `design-revision-5.md` § 0.7.

# Traceability matrix — Design Revision 4 (`F2D5AF31-CA53-481A-ACB4-C75DB033A15A`)

Brief `97484D0E-E16C-485E-BAA2-A277889C0FB6` **v1.1.0** · worktree
`/private/tmp/shipit-correct-addproduct-keys` · branch `design-correct-addproduct-keys` · **Base SHA
`361256c`** · **HEAD SHA `361256c`** · **not committed** · **not pushed**

Supersedes `traceability-matrix-3.md` (Revision 3), `traceability-matrix-2.md` (Revision 2) and
`traceability-matrix.md` (Revision 1) — **all three retained intact**. **This is the matrix Gate D3 should
check.**

**ONE CITATION REVISION.** Every unlabelled `file:line` in Revision 4 is at **`361256c`**, which is this
revision's own base, and **all nine SHAs this revision cites are verified ancestors of it** (output quoted
in `design-revision-4.md` § 0.3). **A reviewer can verify every citation in this matrix from this
worktree** — which is the whole of what the Revision-3 review's blocker B1 required, and the reason
Revision 3's three-label split is gone. Two sources sit outside the base and are labelled at every point of
use: `[UNCOMMITTED 0bf2fa0]` (the `D-4`/`D-5`/`D-18` implementation, read-only) and `[UNCOMMITTED
6220951]` (the ADR 0018 amendment design, read-only). Contrast figures are **inherited, not re-measured**.

Every design element traces to (a) a requirement, (b) a resolved Human Decision, (c) a **named
architecture clause with its supersession status**, and (d) a named existing artifact at **`361256c`**. An
element with no existing artifact is marked **NEW** and justified.

---

## 1. Requirement → design element → decision → **architecture** → existing artifact

**⚠ NEW in Revision 4. ⚑ changed in Revision 4. ↩ carried from Revision 3 unchanged.**

| # | Design element | Rev 4 § | Requirement | Decision(s) | **Architecture clause** | Existing artifact at `361256c` |
|---|---|---|---|---|---|---|
| 1 | Mint is **get-or-create**, never create | R.14.1 step 4 | `R-2a`, `R-B6` | `73097d48`, `b869ec24` | ADR 0018 `:19-21` | `recordGeneratedCredential` (`engine:926`); one-active rule (`engine:954-961`) |
| 2 | ↩ **`publicKey` cannot be changed on an existing row — AT THE STORE** | R.8.1 (`D-1`) | `R-B6` | `b869ec24` | ADR 0018 `:92-95`, `:103-104` | `saveProductCredential` — predicated `WHERE` on both branches. **LANDED** at `07c8c8f`, merged as `e391c02` |
| 3 | ↩ Second mint returns the existing key (`alreadyExisted: true`) | R.14.1 step 4 | `R-B6` | `73097d48` | ADR 0018 `:103-104` | `readActiveCredentialForRepository` (`store:370-381`) |
| 4 | ↩ Concurrent mints collapse to one row — a DB constraint in **BOTH** homes | R.8.1 (`D-2`) | `R-B6` | `b869ec24`, `4d2c6b81` | ADR 0018 A1 `:19-21` | `tool/schema_bootstrap.sql` **+ migration `20261006150645000`**. **LANDED** |
| 5 | ↩ Mint refuses when no host can be derived from the URI | R.5.2 step 1, R.14.1 step 2 | `R-2d` | `b869ec24` | ADR 0018 `:96-99` | `RepositoryReference.uri`; `recordGeneratedCredential(host:)` — **now parsed from the endpoint parameter, not read from a row** |
| 6 | ↩ Generation triggered by a dedicated live control | Brief Flow A | `R-2a` | `73097d48` | — | `canGenerateKey` (`add_product_page.dart:230`, 0 call sites today) |
| 7 | ↩ `hostUnrecognised` state machine | R.10.1 | `R-2d` | `b869ec24` | **ADR 0018 `:96-99`** | `HostKeyStatus` (`credential_status.dart:45-50`) |
| 8 | ↩ **No Cancel/Skip/Dismiss affordance** (`N-1`) | R.10.2 | `R-2d`, `R-H2` | `b869ec24` | ADR 0018 `:96-99` (*"must confirm"*) | *no existing control to remove* — net-new constraint |
| 9 | ↩ Navigation away is a route, not a cancellation (`N-2`) | R.10.2 | `R-H2` | `b869ec24` | — | Products page navigation |
| 10 | ↩ Trust step is blocking; check and register unavailable (`N-3`) | R.10.2 | `R-2b` | `b869ec24` | ADR 0018 `:96-99`, `:100-102` | **enforced in the domain** — `recordCredentialCheck` refuses a non-permitting host (`engine:1047-1052`) |
| 11 | ↩ Out-of-band confirmation copy that does not overclaim (`N-4`) | R.10.2 | `R-2d` | `b869ec24` | **ADR 0018 `:99`** | `credential_status.dart:45-50` |
| 12 | ↩ Confirmation is attributable (`N-5`) | R.10.2 | `R-2d` | `b869ec24` | ADR 0018 `:96-99` | `confirmHostKey` (`engine:988`) requires non-empty `confirmedBy` |
| 13 | ↩ `changed` fails closed, never auto-retrusted (`N-6`) | R.10.1, R.10.2 | `R-2d` | `b869ec24` | ADR 0018 `:96-99` | `confirmHostKey` records-then-throws (`engine:1003-1015`); `credential_status.dart:48-50` |
| 14 | ↩ Host confirmation is durable and not re-prompted (`N-7`) | R.10.2 | `R-H2` | `b869ec24` | ADR 0018 `:96-99` | `hostConfirmedAt`/`hostConfirmedBy` — **conditional on `D-4` (mint) and `D-6` (CAS)**, § R.8.3 |
| 15 | ↩ The way out, traceable to a field + read path | R.12 | `R-H2` | `b869ec24`, `898b07d0` | ADR 0018 `:92-95` | `product_credential.publicKey`; `readActiveCredentialForRepository` — no longer conditional |
| 16 | ↩ Two orthogonal client axes (access + host trust) | R.11 | `R-2b` | `b869ec24` | ADR 0018 `:96-99` | `AccessStatus` (kept); `HostTrustStatus` (mirrored) |
| 17 | ↩ `canRegister` two-factor, mirroring `canReachRepository` | R.11 | `R-2b` | `73097d48` | ADR 0018 `:100-102` | `canReachRepository` (`repository_credential.dart:128-129`) |
| 18 | ⚑ **`RegistrationCommitState` + the five tellable client states** | R.11.1 | `R-H2` | `898b07d0` | ADR 0018 `:100-102` (upheld) | `ProductDetailView.credentials` + `canReachRepository`. Client-derived — **but no longer derivable from the read path alone; `G-14` supplies the data** |
| 19 | ↩ "Check access" normative definition | R.13.1 | `R-2c` | `73097d48` | ADR 0018 `:100-102` | `recordCredentialCheck` (`engine:1034`) |
| 20 | ↩ Six-way failure taxonomy → distinct copy | R.13.2 | `R-2c` | `73097d48`, `9417f8bf` | ADR 0018 `:99` | `CredentialStatus.failing` + `lastFailureReason`; **+ `secretReferenceMissing`** |
| 21 | ↩ Check path contains no generation call — **and no `put`** | R.13.1, R.14.2 | `R-B6`, `R-B5` | `73097d48` | — | the check path resolves a handle; it never creates one, so § R.5.7 cannot leak into it |
| 22 | ↩ Real SSH keypair replaces `_generateMockKeyPair` | R.14.1 | `R-B4` | `73097d48` | ADR 0018 `:85` | **NEW** — replaces `add_product_page.dart:113`, `:126` |
| 23 | ↩ `mintOrReadDeployKey` returns only the public half | R.14.1 | `R-H1` | `b869ec24` | ADR 0018 `:89-91` | `ProductRegistryEndpoints`; `ControlPlaneService` |
| 24 | ↩ `DeployPublicKeyView` has no key-material-capable field | R.14.1 | `R-H1` | `b869ec24` | ADR 0018 `:115` | **NEW**; `RepositoryCredentialView` lacks `publicKey` |
| 25 | ↩ `checkRepositoryAccess` endpoint | R.14.2 | `R-2c` | `73097d48`, `9417f8bf` | ADR 0018 `:100-102` | **NEW**; also resolves the handle from the manager |
| 26 | ↩ Private half never enters `packages/product_registry` | R.2.1 | `R-H1` | `b869ec24`, `9417f8bf` | ADR 0018 `:92-95` | `engine:897-915`; `credential_test.dart` group *"no key material reaches the domain"* |
| 27 | ↩ `RepositoryCredential` never gains a key-material field | R.2.2 | `R-H1` | `b869ec24` | ADR 0018 `:92-95` | `repository_credential.dart:61-78` |
| 28 | ↩ **`referenceName` names a reference, never a value — subject SETTLED** | R.3.1 | `R-H1` | `9417f8bf` | ADR 0018 `:92-95` (upheld, load-bearing) | `referenceName` (`repository_credential.dart:72`) |
| 29 | ↩ **THE SUBSTRATE: A3, an external secret manager — CLOSED, no option set** | R.1 | `R-R1` | `9417f8bf` OPTION_C | ADR 0018 `:85-88` **SUPERSEDED**; `:87-88`'s prohibition **survives** | `SecretProvider` + `apps/server/lib/src/secret/**` — **NEW** |
| 30 | ↩ **Opaque binding `credbind_<32 hex>`; topology derived at resolve time** | R.1.3 | `R-H1`, `R-R1` | `9417f8bf` (consequence 3) | ADR 0018 `:92-95`, `:29-30` (shape superseded) | **NEW** — the one design choice inside the decision; alternative named and rejected. **Reviewer confirmed it as a proper judgement; no HIGH raised** |
| 31 | ↩ **A1/A4 as the documented fallback, with an explicit trigger** | R.1.5 | `R-R1` | `9417f8bf` follow-up | ADR 0018 `:86` names both | reachable only when **no manager is configured**; A4 reachability `UNVERIFIED` |
| 32 | ↩ **A2 permanently excluded** | R.1.6 | `R-R1` | `9417f8bf` | ADR 0018 `:87-88` **still binds** | — appears once, to record it is *closed* not *missing* |
| 33 | ↩ **Fail closed: four triggers, refusal, remediation copy verbatim** | R.5.1–R.5.4 | `R-R1`, `R-2d` | `7b1bc8b7` OPTION_A | ADR 0018 `:99` | `SecretSubstrateUnavailable` — **NEW**, in `apps/server` |
| 34 | ↩ **Substrate precondition evaluated before any write** | R.5.2 | `R-R1`, `R-H2` | `7b1bc8b7` + `898b07d0` + **`ae1c1f79`** | ADR 0018 `:87` | — **no longer an interpretation. `ae1c1f79` RESOLVED OPTION_A and adopted Revision 3's reading; § 10.1 item 3 is WITHDRAWN** |
| 35 | ⚑ **`destroy(handle)` COMPENSATION — the construct, stated once** | **R.5.7** | `R-R1`, `R-H2` | `7b1bc8b7`, `79e860e2` | ADR 0018 `:87`, `:113-114` | **B2.** Revision 3's *"in a `finally`"* **destroys the handle on the success path** — Dart has no failure-only `finally`. § R.5.7 states the construct with **five obligations**; `T-I` added |
| 36 | ↩ **Consistency with the four existing credential refusals** | R.5.5 | `R-4` | `7b1bc8b7` | ADR 0018 `:96-99` precedent | `exceptions.dart:59`, `:201`, `:215`, `:232` |
| 37 | ⚑ **Two-sided revocation: destroy the handle, then mark the row — in `apps/server`** | **R.6.1** | `R-R1` | `79e860e2` OPTION_A | ADR 0018 `:113-114` **SUPERSEDED** | `revokeCredential` (`engine:1072-1090`); `SecretProvider.destroy`. **H7: the pseudocode's attribution is corrected — it is application-layer code, not the engine** |
| 38 | ↩ **The row is retained; C-1 does not contradict the retention test** | R.6.2 | `R-4` | `79e860e2` | — | `credential_test.dart:310` |
| 39 | ↩ **Revocation's semantics depend on `D-4` + `D-6`** | R.6.3 | `R-B6` | `79e860e2` | — | `$assignments` includes `revokedAt`/`revokedReason` (`store:226-240`) |
| 40 | ↩ Private half readable only by the transport; **the handle is never logged either** | R.7 | `R-H1` | `9417f8bf` | ADR 0018 `:87`; **ADR 0020 `:137`** | `AuditEntityType.productCredential` (`audit_entity_type.dart:8`) |
| 41 | ↩ Exposure of the mint endpoint stated plainly, **four ways** | R.15 | `R-5` | `048f3367`, `570bb640` | — | `server.dart:71-73`; `docker/compose.yaml:63`, `:16-17`; `.env.example:16-18` |
| 42 | ↩ **Fourth-path consequence under A3: DISCLOSURE → DENIAL** | R.15.1 | `R-5` | `9417f8bf` | — | **Rev 4 sharpens it:** an attacker with the DB can also set `status = 'revoked'`, so `D-2` blocks the legitimate re-mint — `D-4` is an **availability** control here too |
| 43 | ↩ **New: an unauthenticated caller can DENY the credential path** | R.15.3 | `R-5`, `R-H2` | `7b1bc8b7`, `9417f8bf`, `ae1c1f79` | — | **`ae1c1f79` strengthens it: not even a `Product` row is created**, so the user is not left with a half-built product |
| 44 | ↩ Deployment precondition, not proposed authentication | R.15.2 | `R-5` | `570bb640` | — | loopback pinning un-implemented (verified negative) |
| 45 | ↩ **Registration-ordering cycle CLOSED: the flow creates the Product first** | R.10 | `R-2b` | `898b07d0` OPTION_A | **ADR 0018 `:100-102` UPHELD — must not be amended** | `createProduct` (`engine:43-61`), `addRepositoryReference` (`engine:150-170`), `recordGeneratedCredential` (`engine:938-939`) |
| 46 | ↩ `registered` product semantics used, not a new state | R.10.0 | `R-2b` | `898b07d0` | — | `ProductState.registered` (`product_state.dart:24-28`) |
| 47 | ⚑ **`G-13` — the get-or-create step must not rewrite an existing row** | **R.14.1 step 3, R.12** | `R-H2` | `898b07d0` | ADR 0018 A1 `:19-21` | **NEW gap, found in Rev 4.** `saveProduct` (`:91-101`) and `saveRepositoryReference` (`:127-145`) are **both `ON CONFLICT DO UPDATE`** — re-entry resets `state` to `registered` and rewrites `name`, `createdAt`, `uri`, `addedAt`. Revision 3 called the step *"idempotent by read-then-write"* without checking |
| 48 | ↩ **`N-8` — `inkSecondary` NORMATIVE for all new copy** | R.10.2 | `R-2c`, `R-2d` | — | requirement from **ADR 0021 `:86-91`** | `ShipItPalette.inkSecondary`; failing idiom at `add_product_page.dart:542`, `:590` |
| 49 | ↩ **`N-9` — custody copy is truthful; the exact string** | R.10.2 | `R-H1` | `9417f8bf`, `b869ec24` | ADR 0018 `:85-86` (the false claim) | `add_product_page.dart:542` — false in both halves under A3 |
| 50 | ⚑ **`G-7` REQUIRED — `referenceName` leaves the view; **twelve rows across eleven files** | **R.3.2** | `R-H1` | `9417f8bf` follow-up | ADR 0018 `:92-95` | model source `:11`/`:4`; `ui_view_mappers.dart:176`; `control_plane_repository.dart:1691/:1709/:1708/:108/:1098`; `product_detail_page.dart:471/:676`; **two fixtures that WILL NOT COMPILE** (`product_detail_mobile_golden_test.dart:33`, `widgets/product_detail_page_test.dart:18`). **`protocol.dart` NO-OP** (client: 0 occurrences, class registry) |
| 51 | ↩ **No digest/prefix substitute for the reference** | R.3.3 | `R-H1` | `9417f8bf` | ADR 0019 `:49-51` | — |
| 52 | ↩ **No board may render a reference; the goldens must be regenerated** | R.3.4 | `R-5` | `9417f8bf` | ADR 0018 `:29-30` | both fixtures use `GIT_PRODUCT_SHIPIT_REPO1_SSH`. **Rev 4: the regeneration must cover BOTH, and their *data* changes too** |
| 53 | ↩ **`M-3` → `D-4`: the mint path NEVER upserts — BOTH TIERS** | R.9.1 | `R-B6` | — (engineering-review finding) | ADR 0018 `:96-99`, `:100-102` | Tier A `$assignments` (`store:226-240`) vs the predicate (`store:325-328`); Tier B `_sameKeyMaterial` (`in_memory:196-209`) then wholesale overwrite (`in_memory:193`). Call-site table proves only `engine:979` reaches the branch. **NOT BUILT** |
| 54 | ↩ **A REVOKED credential can be resurrected by an identical-material re-mint** | R.9.2 | `R-B6` | `79e860e2` | ADR 0018 `:103-104` | **mechanism named correctly in Rev 4:** the **engine's one-active guard** (`engine:954-961`) stands down because the read excludes revoked rows; `D-2`'s index is the **backstop**, not the refuser. `credential_test.dart:323` closes the **check** path only |
| 55 | ↩ **`M-4` → `D-5`: `productId`/`repositoryId` immutable — BOTH TIERS, CAS branch** | R.9.3 | `R-B6` | — (engineering-review finding) | ADR 0018 A1 `:19-21`; `:96-99` | `store:227-228` in `$assignments`, in no predicate; `repository_credential.dart:63-65`; `_ensureOwned` (`engine:1784-1790`) bounds the blast radius to one product. **Rev 4 corrects the host-trust prose** — the mint path *destroys* the confirmation, the CAS path *carries* it; both contradict `:96-99` |
| 56 | ⚑ **`D-6`: durable evidence MAY BE SET, MUST NOT BE ERASED — BOTH TIERS** | **R.9.4** | `R-B6`, `R-H2` | `79e860e2` | ADR 0018 `:99` (*do not overclaim*), `:103-104` | **H3.** Revision 3's merged sentence was **unsatisfiable** — `revokeCredential` (`engine:1082-1087`), `confirmHostKey` (`engine:1006-1011`) and `recordCredentialCheck` (`engine:1054-1065`) all **SET** these columns through the CAS branch. Construct: Tier A `_noClear(column, type)`; Tier B `_clearsDurableEvidence`. **NOT BUILT** |
| 57 | ⚑ **`T-C`…`T-K`, with a TIER column** | **R.9.6** | `R-B6` | — | — | **B4.** Revision 3 placed `T-C`/`T-F`/`T-G` in an **entirely in-memory** file while specifying SQL-only changes — so a Postgres-only fix would leave them red. Now: `T-C`, `T-D`, `T-F`, `T-G`, `T-J`, `T-K` on **BOTH** tiers; `T-B` Postgres-only; `T-I`/`T-H` need a fake provider. **NONE RUN BY THIS LANE** |
| 58 | ⚑ **The store contract doc is a required change** | **R.9.7** | `R-B6` | — | ADR 0018 A1 | **M2.** `product_registry_store.dart:40-68` currently narrows `D-4` to *"differs"*, so a reader implementing to it **reproduces `M-3`**. Four required edits, the fourth being *"identical predicates on every tier"* |
| 59 | ⚑ **`revokeRepositoryCredential` endpoint** | R.14.3 | `R-R1` | `79e860e2` | — | **NEW** — `grep -c RepositoryCredentialView apps/server/lib/src/endpoints/*.dart` → **0** across all 11 files. **Depends on `G-14` landing first** |
| 60 | ⚑ **`G-14`: revoked credentials must reach the product detail** | **R.11.2** | `R-H2` | `79e860e2` | ADR 0018 `:100-102`, `:103-104` | **B3.** `loadProductDetail` (`control_plane_service.dart:360-367`) reads **only** `readActiveCredentialForRepository`, which excludes revoked rows on both tiers. Fix = the **existing** `readCredentialsForProduct` (`store:384-393`; `in_memory:233-238`), whose contract already says *"including revoked ones"* (`product_registry_store.dart:78-82`). **No new field, no migration.** Revision 3's stated cause (`AccessStatus`) **mislocated it one layer down** |
| 61 | ⚑ **Sibling-lane consumption contract, SEVEN items** | R.11g | `R-H2` | `898b07d0`, `27ea6536`, `9417f8bf`, **`ae1c1f79`** | ADR 0018 `:85-86`, `:29-30` | **item 5 is NEW** (`ae1c1f79` follow-up 2): after a refused mint the Products list is **unchanged**, and the **Unknown-host board must not double as the refused-mint board**. **No board authored or edited** |
| 62 | ↩ **Footer: no copy on either platform; per-platform structure** | R.11g item 7, `SC-06` | point 2f | `27ea6536` | — | `_buildFooter` `:375`/`:314`/`:383`, `_MobileAddProduct` `:774`, `TechnicalDetails` `:925` |
| 63 | ⚑ **`D-3` — the host-key enforcement SPLIT, corrected** | **R.10.3** | `R-2c`, `R-2d` | `9417f8bf` | **ADR 0018 `:96-99` is a REQUIREMENT, and it is HALF-IMPLEMENTED** | **DOMAIN: enforced** — `engine:1047-1052`, `:1162-1167`, `:1003-1015`; `repository_credential.dart:128-129`. **TRANSPORT: not enforced** — `git_workspace_inspector.dart:106-112`; five host-key tokens grep to **0**. Revision 3's *"no runtime enforcer / decorative"* was **over-broad and is withdrawn** |
| 64 | ↩ Transport injection seam, now **two** capabilities | R.1.4, R.10.3 | `R-2c` | `9417f8bf` | **ADR 0015 `:55-59`**; **ADR 0018 `:67`** | no `environment:` today |
| 65 | ⚑ **The `SecretProvider` composition boundary — three named layers** | **R.1.7** | `R-H1` | `9417f8bf` | ADR 0018 `:92-95` | **H7.** Revision 3's § R.6.1 pseudocode, headed `revokeCredential` and using the engine's private `_ensureOwned`, reads as the engine method's body — which `C-02` and `engine:897-915` forbid. `SC-18` asserts `grep -rn SecretProvider packages/product_registry/` → **0** |
| 66 | ⚑ **Duplicate-credential audit — a gap register entry, `G-12`** | R.8.4 row 7, R.18.2 | `R-B6` | `4d2c6b81` | ADR 0018 A1 `:19-21` | **M1.** Previously carried in **prose and a changelog only**. The query as dispatched **DOES NOT EXECUTE**; the only credential-bearing database held **0 rows**, a vacuous *"no"* |
| 67 | ⚑ **`G-15`: `CredentialIdentityConflictException` does not exist** | R.18.2, R.16 row 38 | `R-B6` | — | — | named by `D-4`; the implementer could not create it (`exceptions.dart` outside its `OWNED_PATHS`). Behaviour complete; **no API behaviour changes** |
| 68 | ⚑ **ADR 0018 amendment — WRITTEN AND ACCEPTED** | **R.17.1** | `R-R1` | `9417f8bf`, `79e860e2` | `:85-88` superseded, **`:87-88` kept**, `:113-114` superseded, `:100-102` upheld | `/private/tmp/shipit-design-adr0018` `[UNCOMMITTED 6220951]`, **158 → 465 lines**, four gaps recorded as **accepted**. **RESIDUAL: uncommitted, not merged** — § 10.1 action 1 |
| 69 | ⚑ **The landed store comment at `store:312-319` is FALSIFIED by `D-18`** | **R.8.5** | `R-B6` | `79e860e2` | — | **L1.** *"no reachable path moves a credential from revoked back into the active set"* is contradicted by § R.9.2, and its two justifications fail. **Correcting it is a required deliverable of `D-4`, in three parts** |
| 70 | ↩ `AGENTS.md §13`/`§13b` — **CLOSED** | R.18.1 | `R-6` | — | ADR 0018 `:140-141`; ADR 0012 `:34`; ADR 0019 `:121` | **B1.** `0bf2fa0` restored §13/§13a/§13b, now at `AGENTS.md:65-101`. **Revision 3 asked the Manager for an action already taken; no action remains** |
| 71 | ↩ The false ledger claim — **CLOSED** | R.18.1 | `R-6` | — | — | **B1.** `LANES.md` is **399 lines** at `361256c` and `:204-205` reads *"That was false"* (landed `4e2d237`). At Revision 3's base the file was **172 lines** with no such assertion |

---

## 2. Finding → resolution — **Revision 3's Gate D3 review, finding by finding**

| Finding | Class | Where it lives in code | **How Revision 4 resolves it** |
|---|---|---|---|
| **B1** stale base | BLOCKER | — | Worktree re-based onto `361256c` (a fast-forward). All nine cited SHAs verified ancestors, output quoted (§ 0.3). `G-1′` **closed** (`0bf2fa0`); the `LANES.md` row **closed** (`4e2d237`) — both § 10.1 items **withdrawn**, not re-requested |
| **B2** `destroy` in a `finally` | BLOCKER | no code — the *specification* was the defect | § R.5.7 states the construct **once**, with five obligations; § R.5.2, § R.10.1 and § R.14.1 all **reference** it. **`T-I`** added: after a successful mint, `resolve(handle)` returns the material |
| **B3** state 4 unreachable | BLOCKER | `control_plane_service.dart:360-367` | § R.11.2 specifies the **server-side change as a required deliverable**, `G-14`. Cause corrected (it is a **query**, not `AccessStatus`). Added to § R.16 (row 47), § R.8.4, § R.18.2, § 8 (`SC-19`), `requirements_gaps` |
| **B4** in-memory tier absent | BLOCKER | `in_memory:193`, `:196-209` | § R.9.1 and § R.9.3 each carry a **Tier A and a Tier B** construct; § R.9.6 requires the tests on **both** tiers; § R.9.7 puts the tier requirement **in the contract** |
| **H1** host derived from a row the next step creates | HIGH | — | § R.5.2 step 1 parses the **endpoint's parameter**; no row may be read. § R.10.1 and § R.14.1 point at it |
| **H2** read precedes the reference; no `repositoryId`; wrong exception | HIGH | `engine:1139`; `exceptions.dart:12` | Signature gains `repositoryId`; the read **moves to step 4** and switches to the **store** method; the error table is rewritten into seven rows with `RepositoryNotFoundException` |
| **H3** CAS branch has no construct or test | HIGH | `engine:1006-1011`, `:1054-1065`, `:1082-1087` | Requirement **split**: `D-4` = mint branch, **`D-6`** = CAS branch, in the only satisfiable form (*may SET, must not erase*). Constructs for both tiers; **`T-J`** and **`T-K`** |
| **H4** `ae1c1f79` absent | HIGH | — | Cited; § R.5.2 re-framed as **implemented as decided**; all three follow-up actions traced; **§ R.11g item 5** added |
| **H5** blast radius seven, two will not compile, `protocol.dart` a no-op | HIGH | `control_plane_repository.dart:1691` (required); two fixtures | § R.3.2 rewritten: **twelve rows across eleven files**, the three compile-breaking sites **marked as such**, `protocol.dart` **marked NO-OP**. My count is stated with its derivation |
| **H6** four risk tallies | HIGH | — | **One tally** — 1 IMPROVED / 1 UNCHANGED / 4 WORSE — in **three** places, verbatim. Revision 3's four tallies withdrawn by name |
| **H7** `SecretProvider` inside the domain package | HIGH | `engine:897-915` | § R.1.7 — three named layers, the sample attributed to `apps/server`, three testable obligations, `SC-18` |
| **M1** audit in no gap register | MEDIUM | — | `G-12`, in **both** § R.18.2 and `requirements_gaps`, plus § R.8.4 row 7 |
| **M2** store contract doc in no change list | MEDIUM | `product_registry_store.dart:40-68` | § R.9.7 — four required edits, each with what becomes false |
| **L1** `D-18` misnamed; the store comment falsified | LOW | `store:312-319` | § R.9.2's **mechanism table** (one-active guard stands down; `D-2` is the backstop); § R.8.5 makes correcting the comment a **required deliverable of `D-4`** |
| **L2** no citation index | LOW | — | § 0.3 — **22 rows** with a one-command completeness check whose output is quoted; § 10.2 item 10 replaces the uncheckable item 6 |
| **L3** "public domain API" over-read | LOW | — | § R.9's preamble — reachable **in-process**; **no Serverpod endpoint calls `recordGeneratedCredential`** (negative grep recorded in § 9.4) |
| **L4** rotation test cited `:520` | LOW | `credential_test.dart:521` | Corrected in § R.9.1 and § R.9.3 |
| **B4** (original finding) — the deploy key is a mock | — | `add_product_page.dart:113`, `:126` | Real SSH keypair generation server-side; `R-B4`, `73097d48`, ADR 0018 `:85` |
| **B5** — "Check access" cannot succeed | — | `:113-120`, `:233-236` | A check endpoint that can reach `verified`; `canRegister` two-factor |
| **B6** — each press rotates the key | — | `:113-120` vs `:558` | **ORIGINAL DEFECT CLOSED at the store** by `D-1`/`D-2`; **conditional** on the no-caller-supplied-`credentialId` requirement. **The state-loss family is NOT closed**: `D-4`, `D-5`, `D-6` (§ R.9) |
| **Gate D3 B1** (rev 1→2) — ADR 0018 exists | — | — | Each clause classified UPHELD / SUPERSEDED / SHAPE-SUPERSEDED (§ R.17) |
| **Engineering M-3** — identical-material re-mint | — | `store:226-240` vs `:325-328` | **`D-4`**, required, **per tier** |
| **Engineering M-4** — `repositoryId` rewritable | — | `store:227-228` not in `:325-328` | **`D-5`**, required, **per tier**; host-trust prose corrected |
| **This lane, Rev 3** — a revoked credential can be resurrected | — | `store:370-381` + `engine:954-961` + `$assignments` | **`D-4` delivers it**; `T-D`. **Mechanism named correctly in Rev 4.** Reviewer **re-derived and confirmed it independently** |
| **This lane, Rev 3** — a substrate refusal that creates a product | — | `898b07d0` × `7b1bc8b7` | **Escalated in Rev 3; DECIDED by `ae1c1f79` OPTION_A, which adopted Rev 3's reading** |
| **This lane, Rev 4** — the get-or-create step is destructive | — | `store:91-101`, `:127-145` | **`G-13`**; § R.14.1 step 3 specifies read-first / write-only-when-absent |
| **This lane, Rev 4** — `D-4`'s named exception does not exist | — | `exceptions.dart` | **`G-15`** |

---

## 3. Coverage of the acceptance criteria

| AC | Where satisfied | Status |
|---|---|---|
| `AC-01` | `design-brief-1.1.0.md` — all 13 § Design Brief fields present | ✅ **Brief NOT re-issued**; its `C-01`/`AC-03`/`SC-08` obligations were discharged by the resolutions. Revision § 0.6 maps every superseded item; § 0.5 lists what is carried verbatim |
| `AC-02` | `design-revision-metadata-4.yaml` — all § Design Revision fields present | ✅ |
| `AC-03` | **Superseded by its own resolution.** `SC-08a` requires the model to be carried **as decided**, and **re-presenting it as open is itself the defect** | ✅ as successor criteria `SC-08a`, `SC-11`–`SC-19` |
| `AC-04` | R.10.1 (state machine on existing `HostKeyStatus`), R.10.2 `N-6` | ✅ |
| `AC-05` | R.10.2 `N-1` — normative, with rationale and its cost | ✅ |
| `AC-06` | R.12 — field + read path table, **no longer conditional** | ✅ **strengthened** — `898b07d0` discharged the dependency; `G-14` adds the revocation row |
| `AC-07` | R.13.1 + R.13.2 (**six** failure kinds) | ✅ |
| `AC-08` | R.8.2 (B6: **two real persistence mechanisms + one application requirement**, honestly stated) + R.9 (`D-4`, `D-5`, **`D-6`**, `T-C`–`T-K` **per tier**) | ✅ **as a requirement**; the state-loss family is explicitly **not** claimed closed |
| `AC-09` | R.16 — **49-row** reuse table (Rev 4 adds #47–#49 and revises #44/#45/#46) | ✅ |
| `AC-10` | R.14, R.15 — the fourth exposure plus **two A3 consequences** | ✅ **extended** — R.15.1 adds the availability reading |
| `AC-11` | R.17 (per-clause ADR status **+ § R.17.1's accepted state**), R.18 (gaps closed / open), `requirements_gaps`, + this matrix | ✅ **and § 0.3's citation index**, which `AC-11`'s verifiability needs |
| `AC-12` | `design-revision-metadata-4.yaml` `risk_level: 3` + a **re-derived** `risk_rationale` with **ONE tally** (1 improved / 1 unchanged / 4 worse) reproduced verbatim in three places | ✅ **H6 discharged** — and § 10.2 item 11 makes a fourth tally a review finding |
| `AC-13` | R.9.2 `PARTIAL`/`PARTIAL`/`MEDIUM` with a per-component feasibility table; § 9.3 explicit `NOT_RUN` table including *"any Docker or Compose command: **none issued**"* and *"**deletions: NONE MADE**"*; § 9.4 `UNVERIFIED` with the commands a human should run | ✅ **extended** — the deletions row is new, against a predecessor that reported deletions it had not made |
| `AC-14` | `discoveries.md` D-1…D-24, incl. **D-15** (an approval is bounded by the open set), **D-16** (a revision whose evidence is off-base cannot be verified) and **D-20**–**D-24** | ✅ **and recorded IN THE ARTIFACT** (§ 0.2), not only in the review |

---

## 4. Gaps and open decisions — **Revision 4**

**Both registers must agree.** § R.18.2 of the revision and `requirements_gaps` in the metadata carry the
same list; § 10.2 item 12 makes divergence a review finding. **M1's finding was a gap living in prose or a
changelog only**, so the register is the place, not the narrative.

| ID | Type | Escalation | Blocks |
|---|---|---|---|
| ~~`OPEN-D4-1`~~ | — | — | **CLOSED** — `9417f8bf`, `7b1bc8b7`, `79e860e2`. § R.1, R.5, R.6 |
| ~~`OPEN-D4-2`~~ | — | — | **CLOSED** — `898b07d0` OPTION_A; ADR 0018 `:100-102` **upheld**. § R.10 |
| ~~`G-1′`~~ | Governance | — | **CLOSED** by `0bf2fa0` — `AGENTS.md:65-101` now carries §13/§13a/§13b. **B1. No action remains** |
| ~~the `LANES.md` claim~~ | Ledger | — | **CLOSED** at `4e2d237` — the file is 399 lines and `:204-205` reads the retraction. **B1. § 10.1's item is withdrawn** |
| **`G-4`** | **ADR gap — host-key verification absent AT THE TRANSPORT.** ADR 0018 `:96-99` is a REQUIREMENT and is **half-implemented**: the domain enforces it, the transport does not | Implementation (architecture) — revision § 10 asks that it get **its own review** | `SC-04`, `SC-05`, `N-6` enforcement. Under A3 the seam must also resolve material from the manager (§ R.1.4) |
| `G-3` | Test gap — 0 tests import `add_product_page.dart` | Implementation / QA Contract | `SC-02`, `SC-04`, `SC-06` |
| `G-5` | Minor — no read-only public-key endpoint | Implementation | Client must hold a `credentialId` to re-read |
| `G-6` | Minor — `host` optional in `recordGeneratedCredential` | Implementation | Domain does not enforce what § R.14.1 requires |
| `G-8` | Minor — fingerprint provenance unspecified | Implementation | `N-4` copy precision |
| **`G-10`** | **`UNVERIFIED` — A3's reachability in the target topology.** No secret manager exists here; no probe was run; **no Docker command was issued by this lane** | **Implementer, before completion** (`9417f8bf`'s own follow-up action) | The substrate the whole design rests on. The decision records `confidence: LOW` |
| **`G-11`** | **`D-4`/`D-5`/`D-6` specified, NOT merged** — and **per tier**, which is more work than Revision 3 asked for | **Implementer**; § 10 asks it merge **ahead** of the feature | **`79e860e2`'s own follow-up test fails until `D-4` lands** (`T-D`); `SC-13` needs `D-4` **and** `D-6` |
| **`G-12`** | **Deployment precondition — the duplicate-credential audit.** The query as dispatched **does not execute**; the only credential-bearing database held **0 rows**, a vacuous *"no"* | **HUMAN**, against every deployed database, with the corrected query, **before** migration `20261006150645000` is applied anywhere. **Not runnable from any lane** | The migration itself |
| **`G-13`** | **Destructive get-or-create** — `saveProduct` and `saveRepositoryReference` are both `ON CONFLICT DO UPDATE`; re-entry resets `state` to `registered` and rewrites `name`, `createdAt`, `uri`, `addedAt` | Implementation — § R.14.1 step 3 | § R.12's re-entry; § R.10's `registered` semantics. **Silent, and it un-commits a registered product** |
| **`G-14`** | **State 4 not derivable from the read path** — `loadProductDetail` reads only the active credential; the user is told *"no key generated yet"* about a withdrawn key that may still be installed | Implementation — § R.11.2, **one method** | § R.11.1 state 4; `SC-19`. **Must land before the revoke UI ships** |
| **`G-15`** | **`CredentialIdentityConflictException` does not exist** — named by `D-4`; the implementer could not create it. Behaviour complete, **no API behaviour changes** | Implementation, **with an ownership grant** (§ 10.1 item 7) | `D-4`'s distinct typing; `D-5`'s scope reason stays distinguishable |
| `L-6` | Index gap — `DECISIONS.md`'s index table (`:8-12`) omits `570bb640`, and `:16`'s *"All five are `PENDING`"* is **false** | **Manager** — reported, **not edited** | Nothing technical |
| — | **ADR 0018 amendment — WRITTEN AND ACCEPTED but UNCOMMITTED and unmerged** | **Human, as ADR owner** (§ 10.1 action 1) | `R6`'s residual. **No longer a drafting task** |
| — | **ADR 0018 `:103`'s wording** — *"Rotation is per product"* against its own `:104` and against A1 | ADR lane / human | Nothing technical; § R.17 **upholds** the clause as the design relies on it |

**Out of scope for this lane, by design** (not gaps): the Penpot boards and the footer layout itself
(`C-11`). § R.11g states a **binding seven-item consumption contract** — of which **item 3** (the flow must
be re-enterable *from the product*) and **item 5** (a refused mint leaves the Products list unchanged, and
must not share the Unknown-host board) are **requirements on the sibling lane's design**, not observations.
**No board is authored and none is edited by this lane.**
