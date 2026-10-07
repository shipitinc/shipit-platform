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
> Retained intact as the Revision 1 artifact. **Not edited below this line.** Two corrections matter to a reader
> of this file: its **citation labels are stale** (Revision 1 was based on `77c19f1`, which is **not** an
> ancestor of `main`; Revision 4's base is `361256c` and every SHA it cites is a verified ancestor of it —
> see `discoveries.md` **D-20**), and its **`AC-12` risk tally is withdrawn** (H6: Revision 3 tallied the same
> reasons four different ways across three artifacts; Revision 4 publishes **one** tally, verbatim, in three
> places). Successor: `traceability-matrix-4.md`.

# Traceability matrix — Design Revision 1 (`46980EE0-E638-409C-A7D3-E1B9399FECE5`)

Brief `97484D0E-E16C-485E-BAA2-A277889C0FB6` · branch `design/addproduct-keyservice` · Base SHA `77c19f1`

Every design element is traced to (a) a requirement, (b) at least one resolved Human Decision, and
(c) a named existing artifact. An element with no existing artifact is marked **NEW** and justified.

---

## 1. Requirement → design element → decision → existing artifact

| # | Design element | Revision § | Requirement | Decision(s) | Existing artifact |
|---|---|---|---|---|---|
| 1 | Mint is **get-or-create**, never create | R.13, R.16 | `R-2a`, `R-B6` | `73097d48`, `b869ec24` | `recordGeneratedCredential` (`engine:912-967`); one-active rule (`engine:940-947`) |
| 2 | `publicKey` immutable per credential | R.15 #4 | `R-B6` | `b869ec24` | `copyWith` (`repository_credential.dart:137-172`) |
| 3 | Second mint returns the existing key (`alreadyExisted: true`) | R.16 | `R-B6` | `73097d48` | `readActiveCredentialForRepository` (`store:48-50`) |
| 4 | Concurrent mint resolves to one row, not a 500 | R.16 | `R-B6` | `b869ec24` | `engine:940-947` |
| 5 | Mint refuses when no host can be derived from the URI | R.16 | `R-2d` | `b869ec24` | `RepositoryReference.uri`; `recordGeneratedCredential(host:)` |
| 6 | Generation triggered by a dedicated control that is live | R.13 Flow A | `R-2a` | `73097d48` | `canGenerateKey` (`add_product_page.dart:230`, currently 0 call sites) |
| 7 | `hostUnrecognised` state machine | R.9 | `R-2d` | `b869ec24` | `HostKeyStatus` (`credential_status.dart:41-50`) |
| 8 | **No Cancel/Skip/Dismiss affordance (normative, `N-1`)** | R.10 | `R-2d`, `R-H2` | `b869ec24` (addendum 2) | *no existing control to remove* — net-new constraint |
| 9 | Navigation away is a route, not a cancellation (`N-2`) | R.10, R.12 | `R-H2` | `b869ec24` | Products page navigation |
| 10 | Trust step is blocking; check and register unavailable (`N-3`) | R.10 | `R-2b` | `b869ec24` | `recordCredentialCheck` refuses (`engine:1033-1038`) |
| 11 | Out-of-band confirmation copy that does not overclaim (`N-4`) | R.10 | `R-2d` | `b869ec24` | `credential_status.dart:38-40` |
| 12 | Confirmation is attributable (`N-5`) | R.10 | `R-2d` | `b869ec24` | `confirmHostKey` (`engine:983-988`); `credential_test.dart:146` |
| 13 | `changed` fails closed with a user-facing path, never auto-retrusted (`N-6`) | R.9, R.10 | `R-2d` | `b869ec24` | `confirmHostKey` records-then-throws (`engine:989-1002`) |
| 14 | Host confirmation is durable and not re-prompted (`N-7`) | R.10 | `R-H2` | `b869ec24` | `hostConfirmedAt`/`hostConfirmedBy`; `repository_credential_view.yaml:24-25` |
| 15 | The way out, traceable to a field + read path | R.12 | `R-H2` | `b869ec24` | `product_credential.publicKey`; `readActiveCredentialForRepository` |
| 16 | Two orthogonal client axes (access + host trust) | R.11 | `R-2b` | `b869ec24` | `AccessStatus` (kept); `HostKeyStatus` (mirrored) |
| 17 | `canRegister` two-factor, mirroring `canReachRepository` | R.11 | `R-2b` | `73097d48` | `canReachRepository` (`repository_credential.dart:128-129`) |
| 18 | "Check access" normative definition | R.13 | `R-2c` | `73097d48` | `recordCredentialCheck` (`engine:1020-1054`) |
| 19 | Five-way failure taxonomy → distinct copy | R.14 | `R-2c` | `73097d48` | `CredentialStatus.failing` + `lastFailureReason` (`engine:1047-1051`) |
| 20 | Check path contains no generation step | R.13, R.17 | `R-B6`, `R-B5` | `73097d48` | NEW endpoint with no generation call |
| 21 | Real SSH keypair replaces `_generateMockKeyPair` | R.16 | `R-B4` | `73097d48` | **NEW** — replacement for `add_product_page.dart:126-138` |
| 22 | `mintOrReadDeployKey` endpoint returns only the public half | R.16 | `R-H1` | `b869ec24` | `ProductRegistryEndpoints`; `ControlPlaneService` |
| 23 | `DeployPublicKeyView` has no key-material-capable field | R.16 | `R-H1` | `b869ec24` | **NEW**; `RepositoryCredentialView` lacks `publicKey` and stays unchanged |
| 24 | `checkRepositoryAccess` endpoint | R.17 | `R-2c` | `73097d48` | **NEW** |
| 25 | `failureKind` is presentation-layer, not domain | R.14 | `R-2c` | `73097d48` | **NEW**; domain vocabulary unchanged |
| 26 | Private half never enters `packages/product_registry` | R.2 | `R-H1` | `b869ec24` | `engine:901-905`, `engine:933-939`, `credential_test.dart` group 1 |
| 27 | `RepositoryCredential` never gains a key-material field | R.2 | `R-H1` | `b869ec24` | `repository_credential.dart:12-18` |
| 28 | `referenceName` subject redefined, no new column | R.3 | `R-H1` | `b869ec24` | `referenceName` (`repository_credential.dart:70-72`); `copyWith` immutability |
| 29 | At-rest model is an OPEN D4 decision, not defaulted | R.1–R.7 | `R-R1` | `b869ec24` | **OPEN-D4-1** |
| 30 | Fail-open vs fail-closed left to the human | R.5 | `R-R1` | `b869ec24` | **OPEN-D4-1 Q2** |
| 31 | Revocation disposal left to the human | R.6 | `R-R1` | `b869ec24` | `revokedAt`/`revokedReason`; `revokeCredential` (`engine:1058-1076`) |
| 32 | Private half readable only by the transport component | R.7 | `R-H1` | `b869ec24` | **NEW** obligation; currently unenforceable (G-4) |
| 33 | Mint/check audited | R.18 | `R-H1` | `570bb640` | `AuditEntityType.productCredential` (`audit_entity_type.dart:8`) |
| 34 | Exposure of the mint endpoint stated plainly | R.18 | `R-5` | `048f3367`, `570bb640` | `server.dart:71-72` |
| 35 | Deployment precondition, not proposed authentication | R.18 | `R-5` | `570bb640` | loopback pinning un-implemented (verified negative) |
| 36 | Registration-ordering conflict surfaced | R.19–R.20 | `R-2b` | `b869ec24`, `73097d48` | **OPEN-D4-2** |
| 37 | `registered` product semantics used, not a new state | R.19 | `R-2b` | `73097d48` | `ProductState.registered` (`product_state.dart:29-32`) |
| 38 | a11y: `inkSecondary` for helper text, not `inkTertiary` | R.8 | `R-2c` | — | `ShipItPalette`; contrast defect from `design-register-button/report.md:71-76` |
| 39 | Implication: four-step order for the sibling lane | Brief § Implications | `R-2b` | `73097d48` | engine's enforced ordering |

---

## 2. Finding → resolution

| Finding | Where it lives in code | How this revision resolves it |
|---|---|---|
| **B4** — the deploy key is a mock | `add_product_page.dart:126-138` | Real SSH keypair generation server-side (R.16); `R-H1`, `DEC-73097d48` |
| **B5** — "Check access" cannot succeed | `:113-120`, `:233-236` | A check endpoint that can actually reach `verified` (R.13, R.17); `canRegister` made satisfiable (R.11) |
| **B6** — each press rotates the key | `:113-120` vs `:558` | Four independent structural mechanisms (R.15) |
| Bootstrap deadlock — `canGenerateKey` has 0 call sites | `:230` | Generation given its own live trigger (R.13 Flow A) |
| The key panel never renders | `_buildKeyBox` gated on `deployKey != null` | Mint no longer depends on the check control |
| D6 SSH trust-on-first-use escalation | parked round | Answered by the human's point 2d; specified normatively (`N-1`–`N-7`) |

---

## 3. Coverage of the acceptance criteria

| AC | Where satisfied | Status |
|---|---|---|
| `AC-01` | `design-brief.md` — all 13 § Design Brief fields present | ✅ |
| `AC-02` | `design-revision-metadata.yaml` — all § Design Revision fields present | ✅ |
| `AC-03` | R.1–R.7: 4 + 2 + 3 atomic options, recommendation with confidence + evidence + risk; no normative default | ✅ |
| `AC-04` | R.9 (state machine on existing `HostKeyStatus`), R.10 `N-6` (`changed` path) | ✅ |
| `AC-05` | R.10 `N-1` — normative, with rationale and its cost | ✅ |
| `AC-06` | R.12 — field + read path table | ✅ (conditional on OPEN-D4-2, and stated as such) |
| `AC-07` | R.13 + R.14 | ✅ |
| `AC-08` | R.15 — four independent mechanisms | ✅ |
| `AC-09` | R.4 — 35-row reuse table | ✅ |
| `AC-10` | R.16–R.18 | ✅ |
| `AC-11` | R.21 (10 substitute assumptions), R.22 (8 gaps), plus this matrix | ✅ |
| `AC-12` | `design-revision-metadata.yaml` `risk_level: 3` + `risk_rationale` | ✅ |
| `AC-13` | R.8 — `PARTIAL`/`PARTIAL`/`MEDIUM` with reasons; `UNVERIFIED` table with the commands a human should run | ✅ |
| `AC-14` | `discoveries.md` | ✅ |

---

## 4. Gaps and open decisions — summary

| ID | Type | Escalation | Blocks |
|---|---|---|---|
| `OPEN-D4-1` | Open Human Decision — at-rest protection (Q1–Q4) | **Gate D4 human decision** | The private-half store specification; § R.3's wire-exposure sub-question; therefore `AC-03`'s completion |
| `OPEN-D4-2` | Open Human Decision — registration ordering | **Gate D4 human decision** | Which flow triggers mint; § R.12's read path exactness |
| `G-1` | Traceability gap — ADR 0018 and `AGENTS.md §13a` absent | Manager (owns `WORK_STATE.md`, `.decisions/**`) | Correcting 9 dangling code citations; verifying the 10 substitute assumptions |
| `G-2` | Governance gap — no read-only-over-Docker rule | Gate D4 item G-2 (per dispatch) | Verifying the 4 `UNVERIFIED` runtime claims |
| `G-3` | Test gap — 0 tests import `add_product_page.dart` | Implementation lane / QA Contract | `SC-02`, `SC-04`, `SC-06` have no harness |
| `G-4` | Architecture gap — no SSH host-key verification | Implementation lane (architecture) | `SC-04`, `SC-05`; `N-6` enforcement |
| `G-5` | Minor — no read-only public-key endpoint | Implementation lane | Client must hold a `credentialId` to re-read |
| `G-6` | Minor — `host` is optional in `recordGeneratedCredential` | Implementation lane | Domain does not enforce what § R.16 requires |
| `G-7` | Security — `referenceName` reaches clients | Coupled to `OPEN-D4-1` Q1 | Wire-contract change in two packages |
| `G-8` | Minor — fingerprint provenance unspecified | Implementation lane | `N-4` copy precision |

**Out of scope for this lane, by design** (not gaps): human points 2e/2f, and the four mobile Penpot
boards — both owned by `design-addproduct-mobile`.