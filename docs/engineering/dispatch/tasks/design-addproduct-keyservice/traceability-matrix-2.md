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
> Retained intact as the Revision 2 artifact. **Not edited below this line.** Two corrections matter to a reader
> of this file: its **citation labels are stale** (Revision 2 was based on `77c19f1`, which is **not** an
> ancestor of `main`; Revision 4's base is `361256c` and every SHA it cites is a verified ancestor of it —
> see `discoveries.md` **D-20**), and its **`AC-12` risk tally is withdrawn** (H6: Revision 3 tallied the same
> reasons four different ways across three artifacts; Revision 4 publishes **one** tally, verbatim, in three
> places). Successor: `traceability-matrix-4.md`.

# Traceability matrix — Design Revision 2 (`F21D5C64-006D-4203-A813-841E08E38B95`)

Brief `97484D0E-E16C-485E-BAA2-A277889C0FB6` **v1.1.0** · branch `design/correct-addproduct-keys` ·
Base SHA `77c19f1` · HEAD SHA `77c19f1` · **not committed**

Supersedes `traceability-matrix.md` (Revision 1), which is **retained intact** as the reviewed
artifact. This matrix is the one Gate D3 should check.

Every design element traces to (a) a requirement, (b) at least one resolved Human Decision, (c) a
**named architecture clause**, and (d) a named existing artifact. An element with no existing artifact
is marked **NEW** and justified.

---

## 1. Requirement → design element → decision → **architecture** → existing artifact

**Changes from Revision 1 are marked ⚠.**

| # | Design element | Rev 2 § | Requirement | Decision(s) | **Architecture clause** | Existing artifact |
|---|---|---|---|---|---|---|
| 1 | Mint is **get-or-create**, never create | R.16 | `R-2a`, `R-B6` | `73097d48`, `b869ec24` | ADR 0018 `:19-21` | `recordGeneratedCredential` (`engine:912-967`); one-active rule (`engine:940-941`) |
| 2 | ⚠ **`publicKey` cannot be changed on an existing row — at the STORE, not only in memory** | **R.15b.1 (`D-1`)** | `R-B6` | `b869ec24` | ADR 0018 `:92-95`, `:103-104` | `saveProductCredential` (`store:177-243`); CAS precedent at `engine:997,1011,1052,1074` |
| 3 | Second mint returns the existing key (`alreadyExisted: true`) | R.16 | `R-B6` | `73097d48` | ADR 0018 `:103-104` | `readActiveCredentialForRepository` (`store:46-50`, impl `:257-268`) |
| 4 | ⚠ **Concurrent mints collapse to one row — via a DB constraint** | **R.15b.2 (`D-2`)**, R.16 step 4 | `R-B6` | `b869ec24` | **ADR 0018 A1 `:19-21`** | `definition.sql:645-647`; rotation order `engine:1104`, `:1108-1119` |
| 5 | Mint refuses when no host can be derived from the URI | R.16 | `R-2d` | `b869ec24` | ADR 0018 `:96-99` | `RepositoryReference.uri`; `recordGeneratedCredential(host:)` |
| 6 | Generation triggered by a dedicated control that is live | Flow A | `R-2a` | `73097d48` | — | `canGenerateKey` (`add_product_page.dart:230`, currently 0 call sites) |
| 7 | `hostUnrecognised` state machine | R.9 | `R-2d` | `b869ec24` | **ADR 0018 `:96-99`** | `HostKeyStatus` (`credential_status.dart:41-50`) |
| 8 | **No Cancel/Skip/Dismiss affordance** (normative, `N-1`) | R.10 | `R-2d`, `R-H2` | `b869ec24` (addendum 2) | ADR 0018 `:96-99` ("must confirm") | *no existing control to remove* — net-new constraint |
| 9 | Navigation away is a route, not a cancellation (`N-2`) | R.10, R.12 | `R-H2` | `b869ec24` | — | Products page navigation |
| 10 | Trust step is blocking; check and register unavailable (`N-3`) | R.10 | `R-2b` | `b869ec24` | ADR 0018 `:96-99`, `:100-102` | `recordCredentialCheck` refuses (`engine:1033-1038`) |
| 11 | Out-of-band confirmation copy that does not overclaim (`N-4`) | R.10 | `R-2d` | `b869ec24` | **ADR 0018 `:99`** ("does not claim to have verified a host it cannot verify") | `credential_status.dart:38-40` |
| 12 | Confirmation is attributable (`N-5`) | R.10 | `R-2d` | `b869ec24` | ADR 0018 `:96-99` ("explicit human confirmation") | `confirmHostKey` (`engine:983-988`) |
| 13 | `changed` fails closed with a user-facing path, never auto-retrusted (`N-6`) | R.9, R.10 | `R-2d` | `b869ec24` | ADR 0018 `:96-99` | `confirmHostKey` records-then-throws (`engine:989-1002`); `credential_status.dart:49-50` |
| 14 | Host confirmation is durable and not re-prompted (`N-7`) | R.10 | `R-H2` | `b869ec24` | ADR 0018 `:96-99` | `hostConfirmedAt`/`hostConfirmedBy`; `repository_credential_view.yaml:24-25` |
| 15 | The way out, traceable to a field + read path | R.12 | `R-H2` | `b869ec24` | ADR 0018 `:92-95` | `product_credential.publicKey`; `readActiveCredentialForRepository` |
| 16 | Two orthogonal client axes (access + host trust) | R.11 | `R-2b` | `b869ec24` | ADR 0018 `:96-99` | `AccessStatus` (kept); `HostKeyStatus` (mirrored) |
| 17 | `canRegister` two-factor, mirroring `canReachRepository` | R.11 | `R-2b` | `73097d48` | ADR 0018 `:100-102` | `canReachRepository` (`repository_credential.dart:128-129`) |
| 18 | "Check access" normative definition | R.13 | `R-2c` | `73097d48` | ADR 0018 `:100-102` | `recordCredentialCheck` (`engine:1020-1054`) |
| 19 | Five-way failure taxonomy → distinct copy | R.14 | `R-2c` | `73097d48` | ADR 0018 `:99` (do not overclaim) | `CredentialStatus.failing` + `lastFailureReason` (`engine:1047-1051`) |
| 20 | Check path contains no generation call | R.3-client, R.17 | `R-B6`, `R-B5` | `73097d48` | — | NEW endpoint with no generation call |
| 21 | Real SSH keypair replaces `_generateMockKeyPair` | R.16 | `R-B4` | `73097d48` | ADR 0018 `:85` (`ed25519`) | **NEW** — replacement for `add_product_page.dart:126-138` |
| 22 | `mintOrReadDeployKey` endpoint returns only the public half | R.16 | `R-H1` | `b869ec24` | ADR 0018 `:89-91` ("public half is surfaced in the UI") | `ProductRegistryEndpoints`; `ControlPlaneService` |
| 23 | `DeployPublicKeyView` has no key-material-capable field | R.16 | `R-H1` | `b869ec24` | ADR 0018 `:115` ("No secret is ever entered into the Shipit UI") | **NEW**; `RepositoryCredentialView` lacks `publicKey` |
| 24 | `checkRepositoryAccess` endpoint | R.17 | `R-2c` | `73097d48` | ADR 0018 `:100-102` | **NEW** |
| 25 | `failureKind` is presentation-layer, not domain | R.14 | `R-2c` | `73097d48` | — | **NEW**; domain vocabulary unchanged |
| 26 | Private half never enters `packages/product_registry` | R.2 | `R-H1` | `b869ec24` | ADR 0018 `:92-95` | `engine:899-905`, `engine:933-939`, `credential_test.dart` group 1 |
| 27 | `RepositoryCredential` never gains a key-material field | R.2 | `R-H1` | `b869ec24` | ADR 0018 `:92-95` | `repository_credential.dart:12-18` |
| 28 | ⚠ **`referenceName` — invariant only; subject, substrate and client exposure all `OPEN`** | **R.3** | `R-H1`, `R-R1` | `b869ec24` | **ADR 0018 `:92-95`** (invariant) / `:85-88` (disputed subject) | `referenceName` (`repository_credential.dart:70-72`); **no index** (`spy.yaml:7-14`) |
| 29 | At-rest model is an OPEN D4 decision, not defaulted | R.1.1 | `R-R1` | `b869ec24` | **ADR 0018 `:85-88`** | **OPEN-D4-1 / `9417f8bf`** |
| 30 | Fail-open vs fail-closed left to the human | R.5 | `R-R1` | `b869ec24` | ADR 0018 `:99` | **OPEN-D4-1 Q2 / `7b1bc8b7`** |
| 31 | ⚠ **Revocation disposal asked as Q3′, not as an open menu** | **R.6.1** | `R-R1` | `b869ec24` (silent) | **ADR 0018 `:113-114`** | `revokedAt`/`revokedReason`; `revokeCredential` (`engine:1058-1076`); **`79e860e2`** |
| 32 | Private half readable only by the transport component | R.7 | `R-H1` | `b869ec24` | ADR 0018 `:87` ("never … transmitted") | **NEW** obligation; currently unenforceable (`G-4`) |
| 33 | Mint/check audited | R.18 | `R-H1` | `570bb640` | **ADR 0019 `:49-51`**; redaction vocabulary from **ADR 0020 `:137`** | `AuditEntityType.productCredential` (`audit_entity_type.dart:8`) |
| 34 | Exposure of the mint endpoint stated plainly, **four ways** | R.18 | `R-5` | `048f3367`, `570bb640` | — | `server.dart:71-72`; `docker/compose.yaml:62`, `:16-17`; `.env.example:16-18` |
| 35 | Deployment precondition, not proposed authentication | R.18 | `R-5` | `570bb640` | — | loopback pinning un-implemented (verified negative) |
| 36 | ⚠ **Registration-ordering conflict — now an ADR contradiction** | **R.19.1** | `R-2b` | `b869ec24`, `73097d48` | **ADR 0018 `:100-102`** | **OPEN-D4-2 / `898b07d0`**; `engine:43-61` (`:54`), `engine:150-170`, `engine:924-925` |
| 37 | `registered` product semantics used, not a new state | R.19.1 | `R-2b` | `73097d48` | — | `ProductState.registered` (**`product_state.dart:24-27`** — corrected from `:29-32`) |
| 38 | ⚠ **a11y: `inkSecondary` NORMATIVE for all new copy (`N-8`)** | **R.10 `N-8`** | `R-2c`, `R-2d` | — | — (requirement from **ADR 0021 `:86-91`**: a coding agent must not substitute its own judgement) | `ShipItPalette.inkSecondary`; failing idiom at `add_product_page.dart:542`, `:590` |
| 39 | ⚠ **`G-7` (client exposure of `referenceName`) has a named owner** | **R.4.1** | `R-H1` | — | ADR 0018 silent on the wire | **`9417f8bf`** |
| 40 | ⚠ **Transport injection seam, homed in an existing ADR** | R.9, § 9 | `R-2c` | `b869ec24` | **ADR 0015 `:55-59`** (`EnvironmentPolicy`); seam anticipated by **ADR 0018 `:67`** | `git_workspace_inspector.dart:106-112` (no `environment:`) |
| 41 | ⚠ **Baseline: `AGENTS.md §13`/`§13b` absent** (`G-1′`) | **R.21.1** | `R-6` | — | ADR 0018 `:140-141`; ADR 0012 `:34`; ADR 0019 `:121` | **Manager/human** — outside `OWNED_PATHS` |
| 42 | Implication: step order for the sibling lane (**four** current steps) | Brief § Implications #2 | `R-2b` | `73097d48` | ADR 0018 `:100-102` | `add_product_page.dart:650, :656, :662, :668` — **four** `_StepText` entries |

---

## 2. Finding → resolution

| Finding | Where it lives in code | How **revision 2** resolves it |
|---|---|---|
| **B4** — the deploy key is a mock | `add_product_page.dart:126-138` | Real SSH keypair generation server-side (R.16); `R-H1`, `DEC-73097d48`, ADR 0018 `:85` |
| **B5** — "Check access" cannot succeed | `:113-120`, `:233-236` | A check endpoint that can actually reach `verified` (R.13, R.17); `canRegister` made satisfiable (R.11) |
| **B6** — each press rotates the key | `:113-120` vs `:558` | **CORRECTED. Not closed.** Rev 1's "four independent mechanisms" was false at the store. Now: endpoint get-or-create (specified) + one-active guard (`engine:940-941`, conditional) + **`D-1` store-level immutability guard** + **`D-2` partial unique index**. `T-A`/`T-B` fail today (R.15, R.15b) |
| Bootstrap deadlock — `canGenerateKey` has 0 call sites | `:230` | Generation given its own live trigger (Flow A) |
| The key panel never renders | `_buildKeyBox` gated on `deployKey != null` | Mint no longer depends on the check control |
| D-3 / D-6 SSH trust-on-first-use | parked round | Answered by the human's point 2d **and mandated by ADR 0018 `:96-99`**; specified normatively (`N-1`–`N-8`) |
| **Reviewer B1** — ADR 0018 exists | `docs/adr/0018-per-product-git-credentials.md` | Rev 1's false `G-1` **withdrawn**; ADR read in full and made load-bearing throughout; real gap `G-1′` recorded; `architecture_refs` repopulated (R.21, § 1 above) |
| **Reviewer B2** — store defeats immutability | `store:177-243`, `engine:920/941/965`, `definition.sql:645-647` | **New required deliverables `D-1`/`D-2`/`D-3`** (§ R.15b); R.15 and R.16 rewritten; SC-02/SC-03 extended |

---

## 3. Coverage of the acceptance criteria

| AC | Where satisfied | Status |
|---|---|---|
| `AC-01` | `design-brief-1.1.0.md` — all 13 § Design Brief fields present | ✅ |
| `AC-02` | `design-revision-metadata-2.yaml` — all § Design Revision fields present | ✅ |
| `AC-03` | R.1.1 + R.4 (Q1′ re-framed against ADR 0018; A2 marked forbidden), R.5 (2 options), R.6 (Q3′ + 3 options), R.8 (per-option confidence, all LOW), R.7 (normative transport constraint); **no normative default anywhere — and the one leak (§ R.3) is fixed** | ✅ |
| `AC-04` | R.9 (state machine on existing `HostKeyStatus`), R.10 `N-6` (`changed` path) | ✅ |
| `AC-05` | R.10 `N-1` — normative, with rationale and its cost | ✅ |
| `AC-06` | R.12 — field + read path table | ✅ (conditional on OPEN-D4-2, and stated as such) |
| `AC-07` | R.13 + R.14 | ✅ |
| `AC-08` | R.15 (corrected: **two** mechanisms, not four) + **R.15b `D-1`/`D-2`/`D-3`**; R.16 step 3 (no caller-supplied `credentialId`) | ✅ **as a requirement**; the claim of structural impossibility is withdrawn |
| `AC-09` | R.4 — **39-row** reuse table (Rev 2 adds #36–#39) | ✅ |
| `AC-10` | R.16–R.18 — incl. the **fourth** exposure (direct database path) | ✅ |
| `AC-11` | R.21 (7 assumptions demoted to recorded ADR decisions), R.21.1 (`G-1′`), R.21.3 (`G-9`), R.22, + this matrix | ✅ |
| `AC-12` | `design-revision-metadata-2.yaml` `risk_level: 3` + `risk_rationale` (5 reasons) | ✅ |
| `AC-13` | R.8 `LOW`/`PARTIAL`/`PARTIAL`/`MEDIUM` with reasons; § 9.1 explicit `NOT_RUN` table; § 9.2 `UNVERIFIED` with the commands a human should run | ✅ |
| `AC-14` | `discoveries.md` D-1…D-14, incl. the wrong-identifier pattern as executable knowledge | ✅ |

---

## 4. Gaps and open decisions — **revision 2**

| ID | Type | Escalation | Blocks |
|---|---|---|---|
| `OPEN-D4-1` | Open Human Decision — at-rest protection, re-framed as **Q1′** (does `b869ec24`'s server-side custody supersede ADR 0018 `:85-88`?), plus Q2, Q3′, Q4 | **Gate D4 human decision** — `9417f8bf` | The private-half store specification; whether **A2 is available at all**; `Q4`/`G-7`'s wire-contract consequence; therefore `AC-03`'s completion |
| `OPEN-D4-2` | Open Human Decision — registration ordering, **re-escalated as an ADR contradiction** (`ADR 0018:100-102`) | **Gate D4 human decision** — `898b07d0` | Which flow triggers mint; § R.12's read-path exactness |
| ~~`G-1`~~ | ~~ADR 0018 / `§13a` absent~~ | — | **WITHDRAWN — FALSE.** `docs/adr/0018-per-product-git-credentials.md` exists, 158 lines. See `design-revision-2.md` § 0.1 |
| **`G-1′`** | **Governance — `AGENTS.md` has no `§13` and no `§13b`** (129 lines; `Product-specific policy` is `TBD` at `:59-63`), so ADR 0018's carve-out (`:140-141`), ADR 0012 `:34` and ADR 0019 `:121` all point at text that does not exist | **Manager / human** — `AGENTS.md` outside `OWNED_PATHS` | Documenting which credential convention applies where (ADR 0018 Negative `:126-127`). **Does not block Gate D3** — ADR 0018, the substantive document, is present and read |
| `G-2` | Governance — no read-only-over-Docker rule in `AGENTS.md` | Gate D4 item | Verifying the `UNVERIFIED` runtime claims. This lane ran no Docker/Compose command at all |
| `G-3` | Test gap — 0 tests import `add_product_page.dart` | Implementation lane / QA Contract | `SC-02`, `SC-04`, `SC-06` have no harness |
| `G-4` | Architecture gap — no SSH host-key verification | Implementation lane (architecture) | `SC-04`, `SC-05`; `N-6` enforcement. **Mandated** by ADR 0018 `:96-99`; seam homed by ADR 0015 `:55-59` |
| `G-5` | Minor — no read-only public-key endpoint | Implementation lane | Client must hold a `credentialId` to re-read |
| `G-6` | Minor — `host` is optional in `recordGeneratedCredential` | Implementation lane | Domain does not enforce what R.16 requires |
| `G-7` | Security — `referenceName` reaches clients | **`9417f8bf`** (`M4` — owner now named) | Wire-contract change in two packages |
| `G-8` | Minor — fingerprint provenance unspecified | Implementation lane | `N-4` copy precision |
| **`G-9`** | **Architecture — ADR 0018 A1's one-per-repository invariant is not a database constraint** | Implementation lane, via required deliverable **`D-2`** | Two concurrent mints yield two active credentials (§ R.15.4). **Does not depend on OPEN-D4-1** |
| **`L-6`** | **Index gap — `DECISIONS.md`'s index table (`:8-12`) omits `570bb640`** | **Manager** — `DECISIONS.md` outside `OWNED_PATHS`; **reported, not edited** | Nothing technical; an index that omits a RESOLVED risk-acceptance decision understates what has been accepted |

**Out of scope for this lane, by design** (not gaps): human points 2e/2f, and the four mobile Penpot
boards — both owned by `design-addproduct-mobile`. The sibling lane must be told that Brief v1.1.0
supersedes implication #2 of v1.0.0 (four `_StepText` entries, not three) and that `inkSecondary`
applies to its boards too.
