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

> **SUPERSEDED by Revision 4** (`F2D5AF31-CA53-481A-ACB4-C75DB033A15A`, `traceability-matrix-4.md`).
> Retained intact as the Revision 3 artifact. **Not edited below this line.** Two corrections matter to a reader
> of this file: its **citation labels are stale** (Revision 3 was based on `77c19f1`, which is **not** an
> ancestor of `main`; Revision 4's base is `361256c` and every SHA it cites is a verified ancestor of it —
> see `discoveries.md` **D-20**), and its **`AC-12` risk tally is withdrawn** (H6: Revision 3 tallied the same
> reasons four different ways across three artifacts; Revision 4 publishes **one** tally, verbatim, in three
> places). Successor: `traceability-matrix-4.md`.

# Traceability matrix — Design Revision 3 (`4B017787-25A0-4F45-ABDA-805C250AF63F`)

Brief `97484D0E-E16C-485E-BAA2-A277889C0FB6` **v1.1.0** · worktree
`/private/tmp/shipit-correct-addproduct-keys` · branch `design-correct-addproduct-keys` · Base SHA `77c19f1`
· HEAD SHA `77c19f1` · **not committed**

Supersedes `traceability-matrix-2.md` (Revision 2), which is **retained intact** as the reviewed artifact,
and `traceability-matrix.md` (Revision 1), likewise. **This is the matrix Gate D3 should check.**

Every design element traces to (a) a requirement, (b) a resolved Human Decision, (c) a **named
architecture clause with its supersession status**, and (d) a named existing artifact. An element with no
existing artifact is marked **NEW** and justified.

**Three citation revisions.** `[77c19f1]` = this lane's HEAD. `[07c8c8f]` = `fix/credential-store-integrity`
(the store, engine, credential tests, `D-1`/`D-2`, migration `20261006150645000`) — **not** an ancestor of
`77c19f1`. `[6220951]` = `main` (the six resolved decision objects) — **not** an ancestor either. A reviewer
**cannot verify this revision from this worktree alone**; § 10.1 of the revision requests a re-base.

---

## 1. Requirement → design element → decision → **architecture** → existing artifact

**New or changed in Revision 3 is marked ⚠.**

| # | Design element | Rev 3 § | Requirement | Decision(s) | **Architecture clause** | Existing artifact |
|---|---|---|---|---|---|---|
| 1 | Mint is **get-or-create**, never create | R.14.1 | `R-2a`, `R-B6` | `73097d48`, `b869ec24` | ADR 0018 `:19-21` | `recordGeneratedCredential` (`engine:926` **[07c8c8f]**); one-active rule (`engine:954-960`) |
| 2 | ⚠ **`publicKey` cannot be changed on an existing row — AT THE STORE** | R.8.1 (`D-1`) | `R-B6` | `b869ec24` | ADR 0018 `:92-95`, `:103-104` | `saveProductCredential` — predicated `WHERE` on **both** branches (`store:251-262`, `:322-331`) **[07c8c8f]**. **LANDED** |
| 3 | Second mint returns the existing key (`alreadyExisted: true`) | R.14.1 | `R-B6` | `73097d48` | ADR 0018 `:103-104` | `readActiveCredentialForRepository` (`store:370-381`) **[07c8c8f]** |
| 4 | ⚠ Concurrent mints collapse to one row — via a DB constraint **in BOTH homes** | R.8.1 (`D-2`) | `R-B6` | `b869ec24`, **`4d2c6b81`** | ADR 0018 A1 `:19-21` | `tool/schema_bootstrap.sql` **+ migration `20261006150645000`** **[07c8c8f]**. **LANDED** |
| 5 | Mint refuses when no host can be derived from the URI | R.14.1 step 3 | `R-2d` | `b869ec24` | ADR 0018 `:96-99` | `RepositoryReference.uri`; `recordGeneratedCredential(host:)` |
| 6 | Generation triggered by a dedicated control that is live | Brief Flow A | `R-2a` | `73097d48` | — | `canGenerateKey` (`add_product_page.dart:230`, 0 call sites today) |
| 7 | `hostUnrecognised` state machine | R.10.1 | `R-2d` | `b869ec24` | **ADR 0018 `:96-99`** | `HostKeyStatus` (`credential_status.dart:41-50`) |
| 8 | **No Cancel/Skip/Dismiss affordance** (normative, `N-1`) | R.10.2 | `R-2d`, `R-H2` | `b869ec24` | ADR 0018 `:96-99` (*"must confirm"*) | *no existing control to remove* — net-new constraint |
| 9 | Navigation away is a route, not a cancellation (`N-2`) | R.10.2 | `R-H2` | `b869ec24` | — | Products page navigation |
| 10 | Trust step is blocking; check and register unavailable (`N-3`) | R.10.2 | `R-2b` | `b869ec24` | ADR 0018 `:96-99`, `:100-102` | `recordCredentialCheck` refuses a non-permitting host (`engine:1034`) |
| 11 | Out-of-band confirmation copy that does not overclaim (`N-4`) | R.10.2 | `R-2d` | `b869ec24` | **ADR 0018 `:99`** | `credential_status.dart:38-40` |
| 12 | Confirmation is attributable (`N-5`) | R.10.2 | `R-2d` | `b869ec24` | ADR 0018 `:96-99` | `confirmHostKey` (`engine:988`) requires non-empty `confirmedBy` |
| 13 | `changed` fails closed with a user-facing path, never auto-retrusted (`N-6`) | R.10.1, R.10.2 | `R-2d` | `b869ec24` | ADR 0018 `:96-99` | `confirmHostKey` records-then-throws; `credential_status.dart:49-50` |
| 14 | Host confirmation is durable and not re-prompted (`N-7`) | R.10.2 | `R-H2` | `b869ec24` | ADR 0018 `:96-99` | `hostConfirmedAt`/`hostConfirmedBy` — **conditional on `D-4`** (§ R.8.3) |
| 15 | The way out, traceable to a field + read path | R.12 | `R-H2` | `b869ec24`, **`898b07d0`** | ADR 0018 `:92-95` | `product_credential.publicKey`; `readActiveCredentialForRepository` — **no longer conditional** |
| 16 | Two orthogonal client axes (access + host trust) | R.11 | `R-2b` | `b869ec24` | ADR 0018 `:96-99` | `AccessStatus` (kept); `HostTrustStatus` (mirrored) |
| 17 | `canRegister` two-factor, mirroring `canReachRepository` | R.11 | `R-2b` | `73097d48` | ADR 0018 `:100-102` | `canReachRepository` (`repository_credential.dart:128-129`) |
| 18 | ⚠ **`RegistrationCommitState` + the five tellable client states** | **R.11.1** | **`R-H2`** | **`898b07d0`** | ADR 0018 `:100-102` (upheld) | `ProductDetailView.credentials` + `canReachRepository`. Client-derived; **no new server field** |
| 19 | "Check access" normative definition | R.13.1 | `R-2c` | `73097d48` | ADR 0018 `:100-102` | `recordCredentialCheck` (`engine:1034`) |
| 20 | Six-way failure taxonomy → distinct copy | R.13.2 | `R-2c` | `73097d48`, **`9417f8bf`** | ADR 0018 `:99` (do not overclaim) | `CredentialStatus.failing` + `lastFailureReason`; **+ `secretReferenceMissing` (new under A3)** |
| 21 | Check path contains no generation call | R.13.1, R.14.2 | `R-B6`, `R-B5` | `73097d48` | — | endpoint with no generation call |
| 22 | Real SSH keypair replaces `_generateMockKeyPair` | R.14.1 | `R-B4` | `73097d48` | ADR 0018 `:85` (`ed25519`) | **NEW** — replacement for `add_product_page.dart:113`, `:126` |
| 23 | `mintOrReadDeployKey` returns only the public half | R.14.1 | `R-H1` | `b869ec24` | ADR 0018 `:89-91` | `ProductRegistryEndpoints`; `ControlPlaneService` |
| 24 | `DeployPublicKeyView` has no key-material-capable field | R.14.1 | `R-H1` | `b869ec24` | ADR 0018 `:115` | **NEW**; `RepositoryCredentialView` lacks `publicKey` |
| 25 | `checkRepositoryAccess` endpoint | R.14.2 | `R-2c` | `73097d48`, **`9417f8bf`** | ADR 0018 `:100-102` | **NEW**; now also resolves the handle from the manager |
| 26 | Private half never enters `packages/product_registry` | R.2.1 | `R-H1` | `b869ec24`, `9417f8bf` | ADR 0018 `:92-95` | `engine:899-905` **[77c19f1]**; `credential_test.dart` group 1 |
| 27 | `RepositoryCredential` never gains a key-material field | R.2.2 | `R-H1` | `b869ec24` | ADR 0018 `:92-95` | `repository_credential.dart:12-18` |
| 28 | ⚠ **`referenceName` names a reference, never a value — and its subject is now SETTLED** | **R.3.1** | `R-H1` | **`9417f8bf`** | ADR 0018 `:92-95` (upheld, load-bearing) | `referenceName` (`repository_credential.dart:72`); **no index** (`spy.yaml:7-14`) |
| 29 | ⚠ **THE SUBSTRATE: A3, an external secret manager — CLOSED, no option set** | **R.1** | `R-R1` | **`9417f8bf` OPTION_C** | ADR 0018 `:85-88` **SUPERSEDED**; `:87-88`'s prohibition **survives** | `SecretProvider` + `apps/server/lib/src/secret/**` — **NEW** |
| 30 | ⚑ **Opaque binding `credbind_<32 hex>`; topology derived from config at resolve time** | **R.1.3** | `R-H1`, `R-R1` | `9417f8bf` (consequence 3) | ADR 0018 `:92-95`, `:29-30` (shape superseded) | **NEW** — the one design choice inside the decision; alternative named and rejected |
| 31 | ⚠ **A1/A4 as the documented fallback, with an explicit trigger** | **R.1.5** | `R-R1` | `9417f8bf` follow-up | ADR 0018 `:86` names both | reachable only when **no manager is configured**; A4 reachability `UNVERIFIED` |
| 32 | ⚠ **A2 permanently excluded** | **R.1.6** | `R-R1` | `9417f8bf` | ADR 0018 `:87-88` **still binds** | — appears once, to record that it is *closed* not *missing* |
| 33 | ⚠ **Fail closed: four triggers, refusal, and the remediation copy verbatim** | **R.5.1–R.5.4** | `R-R1`, `R-2d` | **`7b1bc8b7` OPTION_A** | ADR 0018 `:99` (do not assert what is unproven) | `SecretSubstrateUnavailable` — **NEW**, in `apps/server` (not `product_registry`, `C-02`) |
| 34 | ⚠ **Substrate precondition evaluated before any write; `destroy(handle)` compensation** | **R.5.2** | `R-R1`, `R-H2` | `7b1bc8b7` + `898b07d0` | ADR 0018 `:87` | — **the one ordering interpretation this revision makes; flagged in § 10.1 item 3** |
| 35 | ⚠ **Consistency with the four existing credential refusals** | **R.5.5** | `R-4` | `7b1bc8b7` | ADR 0018 `:96-99` precedent | `exceptions.dart:201, :215, :232, :59` **[07c8c8f]** |
| 36 | ⚠ **Two-sided revocation: destroy the handle, then mark the row** | **R.6.1** | `R-R1` | **`79e860e2` OPTION_A** | ADR 0018 `:113-114` **SUPERSEDED** | `revokeCredential` (`engine:1072-1090`) **[07c8c8f]**; `SecretProvider.destroy` |
| 37 | ⚠ **The row is retained; C-1 does not contradict the retention test** | **R.6.2** | `R-4` | `79e860e2` | — | `credential_test.dart:310` **[07c8c8f]** (was `:246` at `77c19f1`) |
| 38 | ⚠ **Revocation's semantics depend on `D-4`** | **R.6.3** | `R-B6` | `79e860e2` | — | `$assignments` includes `revokedAt`/`revokedReason` (`store:238-239`) |
| 39 | Private half readable only by the transport component; **and the handle is never logged either** | R.7 | `R-H1` | `9417f8bf` | ADR 0018 `:87`; **ADR 0020 `:137`** redaction vocabulary | `AuditEntityType.productCredential` (`audit_entity_type.dart:8`) — the two A3 additions are § R.7 bullets 1–2 |
| 40 | Exposure of the mint endpoint stated plainly, **four ways** | R.15 | `R-5` | `048f3367`, `570bb640` | — | `server.dart:71-72`; `docker/compose.yaml:63`, `:16-17`; `.env.example:16-18` |
| 41 | ⚠ **Fourth-path consequence under A3: DISCLOSURE → DENIAL** | **R.15.1** | `R-5` | `9417f8bf` | — | an attacker with the DB gets a handle, not a key — and can delete handles |
| 42 | ⚠ **New: an unauthenticated caller can DENY the credential path** | **R.15.3** | `R-5`, `R-H2` | `7b1bc8b7`, `9417f8bf` | — | fail-closed + an exposed control plane. **`R-H2`'s promise narrows** |
| 43 | Deployment precondition, not proposed authentication | R.15.2 | `R-5` | `570bb640` | — | loopback pinning un-implemented (verified negative) |
| 44 | ⚠ **Registration-ordering cycle CLOSED: the flow creates the Product first** | **R.10** | `R-2b` | **`898b07d0` OPTION_A** | **ADR 0018 `:100-102` UPHELD — must not be amended** | `createProduct` (`engine:43`), `addRepositoryReference` (`engine:150`), `recordGeneratedCredential` (`engine:938-939`) **[07c8c8f]** |
| 45 | `registered` product semantics used, not a new state | R.10.0 | `R-2b` | `898b07d0` | — | `ProductState.registered` (`product_state.dart:24-27`) |
| 46 | ⚠ **`N-8` — `inkSecondary` NORMATIVE for all new copy, including the remediation** | **R.10.2** | `R-2c`, `R-2d` | — | requirement from **ADR 0021 `:86-91`** | `ShipItPalette.inkSecondary`; failing idiom at `add_product_page.dart:542`, `:590` |
| 47 | ⚠ **`N-9` — custody copy is truthful and names no substrate; the exact string** | **R.10.2** | `R-H1` | `9417f8bf`, `b869ec24` | ADR 0018 `:85-86` (the false claim) | `add_product_page.dart:542` — false in both halves under A3 |
| 48 | ⚠ **`G-7` REQUIRED — `referenceName` leaves `RepositoryCredentialView`, nothing replaces it** | **R.3.2** | `R-H1` | **`9417f8bf` follow-up** | ADR 0018 `:92-95` | `repository_credential_view.yaml:11` + **two generated protocols** + `ui_view_mappers.dart:176` + `control_plane_repository.dart:108/:1098/:1691/:1709` + `product_detail_page.dart:471/:676` |
| 49 | ⚠ **No digest/prefix substitute for the reference** | **R.3.3** | `R-H1` | `9417f8bf` | ADR 0019 `:49-51` (the audit goal a digest defeats) | — |
| 50 | ⚠ **No board may render a reference; the `product_detail` goldens must be regenerated** | **R.3.4** | `R-5` | `9417f8bf` | ADR 0018 `:29-30` (the superseded shape) | fixtures still use `GIT_PRODUCT_SHIPIT_REPO1_SSH` (`product_detail_mobile_golden_test.dart:33`, `widgets/product_detail_page_test.dart:18`) |
| 51 | ⚠ **`M-3` → `D-4`: the mint path NEVER upserts** | **R.9.1** | `R-B6` | — (engineering-review finding) | ADR 0018 `:96-99`, `:100-102` | `$assignments` (`store:226-240`) vs the predicate (`store:325-328`); call-site table proves only `engine:979` reaches the branch **[07c8c8f]**. **NOT BUILT** |
| 52 | ⚠ **A REVOKED credential can be resurrected by an identical-material re-mint** | **R.9.2** | `R-B6` | `79e860e2` | ADR 0018 `:103-104` (rotation must be visible) | `readActiveCredentialForRepository` excludes revoked (`store:370-381`), so the guard at `engine:954-960` cannot fire; `credential_test.dart:323` closes the **check** path only. **DERIVED IN REV 3** |
| 53 | ⚠ **`M-4` → `D-5`: `productId`/`repositoryId` immutable on an existing row** | **R.9.3** | `R-B6` | — (engineering-review finding) | ADR 0018 A1 `:19-21`; `:96-99` (a host nobody confirmed) | `store:228` (in `$assignments`) not in `store:325-328`; `repository_credential.dart:62-65`; `_ensureOwned` (`engine:1784-1790`) bounds the blast radius to one product. **NOT BUILT** |
| 54 | ⚠ **`T-C`…`T-G`** | **R.9.5** | `R-B6` | — | — | `credential_test.dart:342` group; `T-D` needs the Postgres tier. **NONE RUN BY THIS LANE** |
| 55 | ⚠ **`revokeRepositoryCredential` endpoint** | **R.14.3** | `R-R1` | `79e860e2` | — | **NEW** — `grep -c RepositoryCredentialView apps/server/lib/src/endpoints/*.dart` → **0** across all 11 files, so there is nothing to extend |
| 56 | ⚠ **Sibling-lane consumption contract, 6 items (including the resume requirement)** | **R.11g** | `R-H2` | `898b07d0`, `27ea6536`, `9417f8bf` | ADR 0018 `:85-86`, `:29-30` | `C-11` — **no board authored or edited**; `_buildFooter` `:375`/`:314`/`:383`, `_MobileAddProduct` `:774`, `TechnicalDetails` `:925` |
| 57 | ⚠ **Footer: no copy on either platform; per-platform structure per the human** | **R.11g item 6**, `SC-06` | point 2f | `27ea6536` (with a recorded deviation) | — | human's verbatim correction governs; boards authoritative over both lanes' readings |
| 58 | ⚠ **`D-3` RE-VERIFIED — no runtime enforcer for `HostKeyStatus`; an ADR GAP** | **R.10.3** | `R-2c`, `R-2d` | `9417f8bf` | **ADR 0018 `:96-99` is a REQUIREMENT with no implementation** | `packages/worker_runtime/lib/src/workspace/git_workspace_inspector.dart:106-112`; grep → **0 matches** **[07c8c8f]** |
| 59 | Transport injection seam, homed in an existing ADR, now **two** capabilities | R.1.4, R.10.3 | `R-2c` | `9417f8bf` | **ADR 0015 `:55-59`**; **ADR 0018 `:67`** | no `environment:` today |
| 60 | ⚠ **Duplicate-credential audit before migration `20261006150645000`** | R.8.3 | `R-B6` | `4d2c6b81` | ADR 0018 A1 `:19-21` | implementer's own disclosure, carried verbatim. **Human-owned deployment precondition** |
| 61 | ⚠ `AGENTS.md §13`/`§13b` absent (`G-1′`) | R.18.2 | `R-6` | — | ADR 0018 `:140-141`; ADR 0012 `:34`; ADR 0019 `:121` | **Manager/human** — outside `OWNED_PATHS` |

---

## 2. Finding → resolution

| Finding | Where it lives in code | How **revision 3** resolves it |
|---|---|---|
| **B4** — the deploy key is a mock | `add_product_page.dart:113`, `:126` | Real SSH keypair generation server-side (R.14.1); `R-B4`, `DEC-73097d48`, ADR 0018 `:85` |
| **B5** — "Check access" cannot succeed | `:113-120`, `:233-236` | A check endpoint that can reach `verified` (R.13.1, R.14.2); `canRegister` two-factor (R.11) |
| **B6** — each press rotates the key | `:113-120` vs `:558` | **ORIGINAL DEFECT CLOSED at the store**: `D-1` (predicated `ON CONFLICT … WHERE … RETURNING`, both branches) + `D-2` (partial unique index in **two** homes) + the endpoint requirement of no caller-supplied `credentialId` (R.8.2). **CONDITIONAL** on that application requirement. The **state-loss family is NOT closed**: `M-3`/`D-4` and `M-4`/`D-5` (R.9) |
| Bootstrap deadlock — `canGenerateKey` has 0 call sites | `:230` | Generation given its own live trigger (Brief Flow A) |
| The key panel never renders | `_buildKeyBox` gated on `deployKey != null` | Mint no longer depends on the check control |
| D-3 / D-6 — SSH trust-on-first-use | parked round | Answered by the human's point 2d **and mandated by ADR 0018 `:96-99`**; specified normatively `N-1`–`N-9` (R.10) |
| **Gate D3 B1** — ADR 0018 exists | `docs/adr/0018-per-product-git-credentials.md` | Rev 1's false `G-1` withdrawn in Rev 2; ADR read in full. **Rev 3 now classifies each clause as UPHELD / SUPERSEDED / SHAPE-SUPERSEDED** (R.17) |
| **Gate D3 B2** — store defeats immutability | `store:251-262`, `:322-331` | `D-1`/`D-2` **landed**; `T-A`/`T-B` reported green. `D-4`/`D-5` now specified on the **set** `D-1` did not name (R.9) |
| **Gate D3 M-A** — `D-1`/`D-2` owned by nothing | — | **Dispatched** as `fix/credential-store-integrity`; landed at `07c8c8f` (R.8.1) |
| **Engineering review M-3** — identical-material re-mint | `store:226-240` vs `:325-328`; `engine:963-978` | **→ `D-4`**, required (R.9.1), with the safety argument verified from the call-site table |
| **Engineering review M-4** — `repositoryId` rewritable | `store:228` not in `:325-328` | **→ `D-5`**, required (R.9.3), including the host-trust consequence |
| **This lane, Rev 3** — a revoked credential can be resurrected | `store:370-381` + `engine:954-960` + `$assignments` | **`D-4` delivers it**; specified as `T-D` (R.9.2). **Derived, not handed** |
| **This lane, Rev 3** — a substrate refusal that creates a product | `898b07d0` × `7b1bc8b7` | Specified: **nothing is written at all** (R.5.2), with the alternative reading named and flagged in § 10.1 item 3 |

---

## 3. Coverage of the acceptance criteria

| AC | Where satisfied | Status |
|---|---|---|
| `AC-01` | `design-brief-1.1.0.md` — all 13 § Design Brief fields present | ✅ **Brief NOT re-issued**; its `C-01`/`AC-03`/`SC-08` obligations were discharged by the resolutions and are mapped in revision § 0.3 |
| `AC-02` | `design-revision-metadata-3.yaml` — all § Design Revision fields present | ✅ |
| `AC-03` | **Superseded by its own resolution.** `C-01` (*"must not be defaulted"*) is discharged: the human decided. `SC-08a` now requires the model to be carried **as decided**, and re-presenting it as open is itself the defect | ✅ **as successor criteria** `SC-08a`, `SC-11`–`SC-16` |
| `AC-04` | R.10.1 (state machine on existing `HostKeyStatus`), R.10.2 `N-6` | ✅ |
| `AC-05` | R.10.2 `N-1` — normative, with rationale and its cost | ✅ |
| `AC-06` | R.12 — field + read path table, **no longer conditional** | ✅ **strengthened** — `898b07d0` discharged the dependency Rev 2 named |
| `AC-07` | R.13.1 + R.13.2 (now **six** failure kinds) | ✅ |
| `AC-08` | R.8.2 (B6: **two real persistence mechanisms + one application requirement**, honestly stated) + R.9 (`D-4`, `D-5`, `T-C`–`T-G`) | ✅ **as a requirement**; the state-loss family is explicitly **not** claimed closed |
| `AC-09` | R.16 — **46-row** reuse table (Rev 3 adds #40–#46 and revises #31/#35) | ✅ |
| `AC-10` | R.14, R.15 — incl. the fourth exposure, plus **two new A3 consequences** (disclosure→denial, and denial of the credential path) | ✅ **extended** |
| `AC-11` | R.17 (per-clause ADR status), R.18 (gaps closed / open), R.19-equivalent in `design-revision-metadata-3.yaml`, + this matrix | ✅ |
| `AC-12` | `design-revision-metadata-3.yaml` `risk_level: 3` + a **re-derived** `risk_rationale` (2 improved, 4 unchanged-or-worse, with the net argued) | ✅ |
| `AC-13` | R.9.2 `PARTIAL`/`PARTIAL`/`MEDIUM` with a per-component feasibility table; § 9.3 explicit `NOT_RUN` table including *"any Docker or Compose command: **none issued**"*; § 9.4 `UNVERIFIED` with the commands a human should run | ✅ |
| `AC-14` | `discoveries.md` D-1…D-15, incl. **D-15** — a design approved against unresolved decisions is superseded when they resolve, and the approval's value is bounded by the open set | ✅ **and recorded IN THE ARTIFACT** (§ 0.2), not only in the review |

---

## 4. Gaps and open decisions — **revision 3**

| ID | Type | Escalation | Blocks |
|---|---|---|---|
| ~~`OPEN-D4-1`~~ | — | — | **CLOSED** — `9417f8bf` (A3), `7b1bc8b7` (fail closed + remediation), `79e860e2` (two-sided revocation). See revision § R.1, R.5, R.6 |
| ~~`OPEN-D4-2`~~ | — | — | **CLOSED** — `898b07d0` OPTION_A. ADR 0018 `:100-102` **upheld**. See § R.10 |
| **`G-1′`** | Governance — `AGENTS.md` has no `§13`/`§13b` | **Manager / human** — outside `OWNED_PATHS` | Documenting which credential convention applies where. **Does not block Gate D3** |
| **`G-4`** | **ADR gap** — no SSH host-key verification exists; `HostKeyStatus` has no runtime enforcer; **ADR 0018 `:96-99` makes it a requirement** | Implementation (architecture) — revision § 10 asks that it get **its own review** | `SC-04`, `SC-05`, `N-6` enforcement. Under A3 the seam must also resolve material from the manager (§ R.1.4) |
| `G-3` | Test gap — 0 tests import `add_product_page.dart` | Implementation / QA Contract | `SC-02`, `SC-04`, `SC-06` |
| `G-5` | Minor — no read-only public-key endpoint | Implementation | Client must hold a `credentialId` to re-read |
| `G-6` | Minor — `host` optional in `recordGeneratedCredential` | Implementation | Domain does not enforce what R.14.1 requires |
| `G-8` | Minor — fingerprint provenance unspecified | Implementation | `N-4` copy precision |
| **`G-10`** | **`UNVERIFIED` — A3's reachability in the target topology.** No secret manager exists here; no probe was run; no Docker command was issued by this lane | **Implementer, before completion** (`9417f8bf`'s own follow-up action) | The substrate the whole design rests on. The decision itself records `confidence: LOW` |
| **`G-11`** | **`D-4`/`D-5` specified, NOT built.** `R-B6`'s state-loss family, § R.6's two-sided revocation and `N-7`'s durability all rest on them | **Implementer** — `fix/credential-store-integrity` scope or a new item; § 10 asks it merge **ahead** of the feature | **`79e860e2`'s own follow-up test fails until `D-4` lands** (`T-D`) |
| `L-6` | Index gap — `DECISIONS.md`'s index table (`:8-12`) omits `570bb640` | **Manager** — reported, not edited | Nothing technical |
| — | False ledger fact — `LANES.md:204-205` still asserts ADR 0018 / `AGENTS.md §13a` do not exist | **Manager** — reported, not edited | Nothing technical; the false claim is still in a Manager-owned file |
| **ADR 0018 amendment** | `:85-88` and `:113-114` **superseded**; `:29-30`'s **shape** superseded; `:100-102` **upheld, must not be touched** | **Human, as ADR owner** — a sibling lane is drafting it; revision § R.17 states the dependency contract | **BLOCKING PREDECESSOR for implementation** |

**Out of scope for this lane, by design** (not gaps): the Penpot boards and the footer layout itself
(`C-11`). Revision § R.11g states a **binding six-item consumption contract** so the sibling lane can
consume it rather than re-derive it — of which **item 3** (the flow must be re-enterable *from the
product*, or the accepted visible-half-registered-product consequence becomes the dead end human point 2d
rejected) is a **requirement on the sibling's design**, not an observation. **No board is authored and none
is edited by this lane.**
