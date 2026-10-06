# Design Brief: Add Product — server-side deploy-key service + `hostUnrecognised` trust state

## Required fields (`DESIGN_GOVERNANCE.md` § Design Brief)

```yaml
brief_id: "97484D0E-E16C-485E-BAA2-A277889C0FB6"     # UUID
version: "1.0.0"                                     # semver (major.minor.patch)
status: "UNDER_REVIEW"                               # DRAFT | UNDER_REVIEW | APPROVED | SUPERSEDED
created_by: "design-agent"                           # agent ID (lane design-addproduct-keyservice)
created_at: "2026-10-06T00:00:00Z"                   # ISO8601
approved_by: ""                                      # human ID, when approved
approved_at: ""                                      # ISO8601, when approved
# requirements_refs:    -> "## `requirements_refs`" below (R-2a..R-R1, R-B4..R-B6)
# architecture_refs:    -> "## `architecture_refs`" below (ADR-0001..0003, ADR-0018 ABSENT,
#                          AGENTS.md 13a ABSENT, DEC-73097d48, DEC-b869ec24, DEC-048f3367, DEC-570bb640)
# problem_statement:    -> "## `problem_statement`" below
# user_flows:           -> "## `user_flows`" below (Flows A-D)
# success_criteria:     -> "## `success_criteria`" below (SC-01..SC-10)
# constraints:          -> "## `constraints`" below (C-01..C-12)
# acceptance_criteria:  -> "## `acceptance_criteria`" below (AC-01..AC-14)
# risk_assessment:      -> "## `risk_assessment`" below (initial level 3)
```

**Human-readable header**

**Brief ID**: `97484D0E-E16C-485E-BAA2-A277889C0FB6`
**Version**: 1.0.0
**Status**: UNDER_REVIEW
**Created by**: `design-agent` (lane `design-addproduct-keyservice`)
**Created at**: 2026-10-06T00:00:00Z
**Worktree**: `/private/tmp/shipit-design-addproduct-keys`
**Branch**: `design/addproduct-keyservice`
**Base SHA**: `77c19f1`

---

## Scope statement (read first)

This brief covers **human points 2a, 2b, 2c, 2d only**:

| Point | Verbatim human requirement | Owned here |
|---|---|---|
| 2a | "The UI seems to indicate the Add a product page should generate a key on Repository SSH URL input" | Yes |
| 2b | "Register product is dependent on upon this key generation and trust of this host before product creation" | Yes |
| 2c | "It's not documented what Check access is supposed to do" | Yes |
| 2d | "Design allows for cancelling the trust this host operation, but I don't think we want to allow that b/c it causes us to get stuck and unable to register" | Yes |
| 2e | "Only 'Registers product' is supposed to be in the button…" | **No** — sibling lane `design-addproduct-mobile` |
| 2f | "…only one footer line… There's only a Show technical details widget" | **No** — sibling lane |
| 1 | Missing mobile light/dark Penpot boards | **No** — sibling lane; this lane owns **no** Penpot board |

The sibling lane owns `docs/engineering/dispatch/tasks/design-addproduct-mobile/**` and the four
`SM - Add Product - {Unknown host,Verified} - {Light,Dark}` boards. Nothing in this brief may create or
edit a board. § "Implications for the sibling lane" states what this lane's state machine implies for
2e/2f so the two lanes can align without either inventing the other's work.

---

## `requirements_refs`

| Ref | Source | Statement |
|---|---|---|
| `R-2a` | Human point 2a | Generate the deploy keypair as a consequence of entering the repository SSH URL |
| `R-2b` | Human point 2b | Product registration is gated on key generation **and** host trust |
| `R-2c` | Human point 2c | "Check access" has a documented, achievable meaning |
| `R-2d` | Human point 2d | The trust-this-host step must offer **no** cancel/reject affordance |
| `R-H1` | Human addendum 1 | There must be an API for private-key **creation and storage** server-side, because SHIP IT pushes from its backend |
| `R-H2` | Human addendum 2 | Removing Cancel is safe: the Products page is always reachable and the key persists, so the product can be created later and the key re-verified |
| `R-R1` | Dispatch R1 | The at-rest protection model is **not** the design agent's to choose; it is a Gate D4 decision |
| `R-B6` | Finding B6, `docs/engineering/dispatch/tasks/design-register-button/report.md:67-69` | Each "Check access" press currently regenerates the keypair, orphaning the key the user just installed |
| `R-B4` | Finding B4, same report `:60-63` | The deploy key is a mock, not an installable key |
| `R-B5` | Finding B5, same report `:65` | "Check access" is a control that cannot succeed |

## `architecture_refs`

| Ref | Status | Artifact |
|---|---|---|
| `ADR-0001` | Present | `docs/engineering/adr/0001-framework-distribution-and-versioning.md` |
| `ADR-0002` | Present | `docs/engineering/adr/0002-dart-mason-git-framework-driver.md` |
| `ADR-0003` | Present | `docs/engineering/adr/0003-product-generic-orchestrator-skill.md` |
| **`ADR-0018`** | **ABSENT** | Cited by `repository_credential.dart:10`, `credential_status.dart:1,36`, `product_registry_store.dart:7,35`, `repository_credential.spy.yaml:4`, `repository_credential_view.yaml:1`, `product_registry_engine.dart:898` — **the file does not exist** |
| **`AGENTS.md §13a`** | **ABSENT** | Cited by `repository_credential.dart:10`. `AGENTS.md` has sections `Inherited invariants` / `Orchestration` / `Product-specific policy` / `Framework provenance` — **no §13** |
| `DEC-73097d48` | RESOLVED | `.decisions/73097d48-…yaml` — PRODUCT, OPTION_A: real key generation over the mock; folds the parked register-button round |
| `DEC-b869ec24` | RESOLVED | `.decisions/b869ec24-…yaml` — ARCHITECTURE, OPTION_A: generate **and store** server-side behind an API returning only the public half |
| `DEC-048f3367` | RESOLVED | `.decisions/048f3367-…yaml` — SECURITY, OPTION_C: remove committed credentials **and** add control-plane API auth before staging |
| `DEC-570bb640` | RESOLVED | `.decisions/570bb640-…yaml` — DEPLOYMENT_AUTHORITY, OPTION_B: no auth now; record the unauthenticated API as an accepted risk scoped to local/QA, make auth a blocking production precondition, **and pin compose bindings to loopback** |

---

## `problem_statement`

Three defects make the Add Product page impossible to complete, and one of them is a security
property asserted by the design that the code cannot honour.

1. **The key is fake (`R-B4`).** `_generateMockKeyPair`
   (`apps/control_plane/lib/features/products/add_product_page.dart:126-138`) emits
   `ssh-ed25519 <base64 of 32 random bytes> shipit+<name>`. No `authorized_keys` anywhere accepts it,
   so no repository is reachable and the copy the design tells the user to install is meaningless.

2. **"Check access" is a control that cannot succeed (`R-B5`).** It is the **only** producer of
   `deployKey` (`:113-120`), and `canRegister` requires
   `accessStatus == AccessStatus.verified` (`:233-236`). The only `accessStatus:` assignment in the
   page is `→ notChecked` (`:118`); **nothing anywhere assigns `.verified`**. So `canRegister` is
   constantly `false` and registration is unreachable.

3. **The same control silently rotates the key (`R-B6`).** Each press regenerates the pair while
   "Copy public key" (`:558`) copies the current one. The design makes "Check access" the designated
   remedy, so following the prescribed path orphans the key the user just installed.

4. **The bootstrap deadlock keeps the key panel unreachable.** `_buildKeyBox` renders only
   `if (state.deployKey != null)`, and `deployKey` is set only from inside `_buildKeyBox`.
   `canGenerateKey` (`:230`) has **zero** call sites. So `deployKey ≡ null` and the panel never shows.

5. **The design asserts a browser-side guarantee the server must now own.** The boards claim
   "created on this device · the private half stays in the keychain" (`:542`). `DEC-b869ec24` moves
   generation and storage server-side, which makes that copy **false as written** and requires the
   claim to be restated honestly.

6. **SSH host trust has no runtime enforcement at all.** `HostKeyStatus` exists in the domain and is
   consulted by the engine, but nothing in the repository performs host-key verification: a grep for
   `SSH_AUTH_SOCK|known_hosts|ssh-keyscan|StrictHostKeyChecking|IdentityFile` across `apps` and
   `packages` returns **nothing**, and `GitWorkspaceInspector._capture`
   (`packages/worker_runtime/lib/src/workspace/git_workspace_inspector.dart:106-112`) runs
   `Process.run(git, args)` with **no `environment:` override**, so neither a credential nor a host
   policy can reach the transport today.

7. **`RepositoryCredential.referenceName` means the wrong subject.** Its doc
   (`repository_credential.dart:70-72`) says the private half is held in *the operator's local
   secret store*. `DEC-b869ec24` moves it server-side. The field's **type** contract ("a reference,
   never the value") survives; its **subject** must change — and whether it may still reach the client
   depends on where the key ends up, which is undecided.

### Correction to a recorded VERIFIED FACT

`WORK_STATE.md:329-330` and `DEC-b869ec24`'s context both assert that **no deploy-key
infrastructure exists server-side**, on the evidence that a grep for `deployKey`/`deploy_key`
returns nothing. That grep used the wrong identifiers. The infrastructure is named **credential**, and
it substantially exists: the `RepositoryCredential` domain type, `CredentialStatus`, `HostKeyStatus`,
the `product_credential` table, the `RepositoryCredentialView` wire type, four store methods, and six
engine methods — including `recordGeneratedCredential`, which already enforces **one active credential
per repository**. The genuine gap is far narrower: keypair generation, a private-half store, a caller
of `recordGeneratedCredential`, the endpoint, and real SSH host-key verification. See
`discoveries.md` (`PROJECT_FACT`) for the exact greps.

---

## `user_flows`

### Flow A — Generate (once per repository) — satisfies `R-2a`, kills `R-B6`

- **Entry**: `productName` non-empty **and** `repositorySshUrl` parses as an SSH remote.
- **Steps**: user activates **Generate deploy key** (the first of `canGenerateKey`'s now-live call
  sites) → server returns the public half and a `credentialId`.
- **Exit — success**: client holds `credentialId`, `publicKey`, `fingerprint`, `algorithm`, `host`.
- **Exit — already existed**: the server returns the **existing** credential's public half with
  `alreadyExisted: true`. This is the primary `R-B6` guard: generation is defined as *get-or-create*,
  never *create*.
- **Exit — refused**: product/repository unparseable or host absent → no credential is written.
- **Invariant**: the client cannot mint twice for one repository, and pressing any other control
  cannot mint at all.

### Flow B — Trust the host — satisfies `R-2d`

- **Entry**: `hostKeyStatus == unknown` and a `credentialId` is held.
- **Steps**: server presents the host key fingerprint it actually observed for `host`; the user
  confirms it out of band and activates **Trust this host** → `confirmHostKey(...)` with an
  attributable `confirmedBy`.
- **Exit — success**: `hostKeyStatus == confirmed`, `hostConfirmedAt`/`hostConfirmedBy` recorded.
- **Exit — changed**: a *different* fingerprint against an already-recorded one → `changed`, fails
  closed, never auto-retrusted.
- **Normative**: **no Cancel, Reject, Skip or Dismiss affordance exists on this step.** See the
  Design Revision § R-2 for the normative text and its rationale.
- **The way out**: navigation back to the Products page. Not a control on the trust panel — a route.

### Flow C — Check access — satisfies `R-2c`, kills `R-B5`, kills `R-B6`

- **Entry**: `credentialId` held **and** `hostKeyStatus.permitsConnection`.
- **Steps**: user activates **Check access** → server performs one real SSH transport attempt against
  `host` using the **stored private half** for that same `credentialId` → `recordCredentialCheck(...)`.
- **Exit — success**: `status == verified`, `lastVerifiedAt`/`lastVerifiedBy` recorded. Proves the key
  works; says nothing about the user's typing.
- **Exit — classified failure**: one of `hostUntrusted`, `hostKeyChanged`, `credentialNotInstalled`,
  `networkUnreachable`, `revoked` — each drives a distinct transition and distinct copy.
- **Invariant**: this flow has **no** call into key generation. `R-B6` is structurally impossible.
- **Invariant**: the flow is reachable and can reach `verified`, which it currently cannot (`R-B5`).

### Flow D — Register — satisfies `R-2b`

- **Entry**: `canRegister` — which mirrors the server's own `canReachRepository` and therefore
  requires **both** halves: a credential proven usable **and** a confirmed host.
- **Steps**: user activates **Register product** → the product is registered at the pinned revision.
- **Invariant**: `canRegister` must never be satisfied by a client-side fiction. Both halves are
  server-proven values.

---

## `success_criteria`

| ID | Criterion | Measurement |
|---|---|---|
| `SC-01` | The keypair is generated server-side by a real SSH implementation, not `_generateMockKeyPair` | `_generateMockKeyPair` deleted; the emitted public key is accepted by a real `authorized_keys` (`UNVERIFIED` here — needs a running stack; see Feasibility) |
| `SC-02` | Generation happens **exactly once per credential**; every later action reuses the same `credentialId` | Pressing any control N≥2 times yields one `product_credential` row; the copied public key is byte-identical across presses |
| `SC-03` | A second mint for a repository never silently rotates the key | Second mint returns `alreadyExisted: true` with the same `publicKey`; concurrent mint resolves to the same row via the engine's one-active rule |
| `SC-04` | "Check access" can reach `verified` | A flow test drives host-trusted → check → `CredentialStatus.verified` with `lastVerifiedAt` set |
| `SC-05` | "Check access" distinguishes five failure causes | Each of `hostUntrusted`, `hostKeyChanged`, `credentialNotInstalled`, `networkUnreachable`, `revoked` maps to a distinct wire `failureKind` and distinct copy |
| `SC-06` | The trust step exposes no cancel/reject affordance | No `Cancel`/`Skip`/`Dismiss`/`Not now` control in the trust panel in any state, light or dark, desktop or mobile; a test asserts the absence |
| `SC-07` | The way out of the trust step is traceable to a field and a read path | Re-entry reads `product_credential` via `readActiveCredentialForRepository(repositoryId)` and re-copies `publicKey` without regenerating |
| `SC-08` | The at-rest protection model is decided by the human at Gate D4 | Decision object exists with a selected option; no normative section of the frozen contract defaults it |
| `SC-09` | No wire type or endpoint can return private key material | `DeployPublicKeyView` has no field capable of carrying it; a test asserts no response type contains a `PRIVATE KEY` marker |
| `SC-10` | The design reuses the existing credential domain rather than beside it | Every element maps to a named existing artifact (Revision § Reuse table); no parallel credential abstraction |

## `constraints`

| ID | Constraint | Type | Evidence |
|---|---|---|---|
| `C-01` | The at-rest protection model **must not** be defaulted by the design agent | Governance | Human: "I have NOT approved the at-rest protection model… Surface it as a decision at Gate D4; do not default it." |
| `C-02` | The private half must never enter `packages/product_registry` | Architectural | `product_registry_engine.dart:901-905`: "A private key must never reach this package"; `:933-939` already rejects a `PRIVATE KEY` string in `publicKey` |
| `C-03` | Key generation happens **once** per credential | Architectural | `copyWith` (`repository_credential.dart:137-172`) **cannot** change `credentialId`, `referenceName`, `publicKey`, `fingerprint` or `algorithm`; `recordGeneratedCredential` refuses a second active credential (`product_registry_engine.dart:940-947`) |
| `C-04` | `RepositoryCredential` continues to hold **no** key material | Architectural | `repository_credential.dart:12-18`, covered by `credential_test.dart` "no key material reaches the domain" |
| `C-05` | Host trust is a human, attributable, out-of-band decision | Security | `credential_status.dart:38-40`: "SHIP IT cannot verify a host on the operator's behalf and does not claim to"; `confirmHostKey` requires non-empty `confirmedBy` |
| `C-06` | `HostKeyStatus.changed` fails closed | Security | `credential_status.dart:49-50`; `confirmHostKey` records `changed` then throws |
| `C-07` | The endpoint is created on an **unauthenticated** control plane | Security | `apps/server/lib/server.dart:71-72`; `DEC-570bb640` accepts this for local/QA only |
| `C-08` | Compose bindings are **not** pinned to loopback today | Security | `grep -rn "127.0.0.1:" docker/*.yaml apps/server/docker-compose.yaml` → no match; `DEC-570bb640`'s pinning follow-up is un-implemented |
| `C-09` | Writing production code is prohibited for this lane | Governance | Dispatch `PROHIBITED_PATHS`; `apps/server/migrations/**` may be **proposed**, never created |
| `C-10` | No Docker or Compose command may be executed | Operational | A prior review lane destroyed a QA database with `docker compose … down -v`; no read-only-over-Docker rule exists yet (`AGENTS.md` has none) |
| `C-11` | Scope is points 2a–2d; points 2e/2f and all boards belong to `design-addproduct-mobile` | Governance | Dispatch; `OWNED_PATHS` do not intersect |
| `C-12` | Design artifacts live only under `docs/engineering/dispatch/tasks/design-addproduct-keyservice/**` | Governance | Dispatch `OWNED_PATHS` — **not** `docs/design/**`, where the Manager's examples live |

## `acceptance_criteria`

| ID | Acceptance criterion | Traces to |
|---|---|---|
| `AC-01` | A Design Brief exists with all 13 `DESIGN_GOVERNANCE.md` § Design Brief fields | Governance |
| `AC-02` | A Design Revision exists with all `DESIGN_GOVERNANCE.md` § Design Revision metadata fields | Governance |
| `AC-03` | The at-rest model is presented as an OPEN Gate D4 decision with 2–4 atomic options per sub-question, a recommendation, evidence and risk — and is defaulted nowhere in normative text | `R-R1`, `C-01` |
| `AC-04` | `hostUnrecognised` is specified as a state machine grounded on the existing `HostKeyStatus`, with `changed` given a user-facing path | `R-2d` |
| `AC-05` | The absence of any Cancel affordance is stated normatively **with its rationale**, so an implementer cannot reintroduce one | `R-2d` |
| `AC-06` | The way out names the concrete record and read path, not a hope | `R-H2` |
| `AC-07` | "Check access" has a normative definition: what it attempts, against which host, with which credential, what success proves, what each failure distinguishes, and which transition each outcome drives | `R-2c` |
| `AC-08` | Key generation is specified as once-per-credential and later checks reuse one `credentialId`, making `R-B6` structurally impossible | `R-B6`, `C-03` |
| `AC-09` | A reuse table maps every design element to a named existing artifact, with genuinely-new items justified | `R-4` |
| `AC-10` | The endpoint contract states request, response fields, error cases, and its exposure under `DEC-048f3367` + `DEC-570bb640` — including "nothing protects it today" if that is the honest answer | `R-5` |
| `AC-11` | A traceability matrix exists with the ADR-0018 absence recorded as a gap and every substitute assumption listed | `R-6` |
| `AC-12` | `RISK_LEVEL` 0–3 assigned with rationale | `R-6` |
| `AC-13` | Self-assessment fields (`design_system_compliance`, `ux_accessibility_score`, `implementation_feasibility`) are filled honestly; anything unsubstantiated is `UNKNOWN`/`PARTIAL` with a reason, and no gate is claimed that was not run | `R-6` |
| `AC-14` | Durable discoveries are classified per `LEARNING_POLICY.md`, including the Manager's `VERIFIED FACT` correction as executable knowledge | `AC-14` |

## `risk_assessment`

**Initial risk level: 3** (Major Workflow / Navigation / IA Change).

| Risk | Level | Rationale |
|---|---|---|
| Handles private key material for the first time | 3 | SHIP IT will hold a secret that authorises write access to a customer repository. Compromise is repository compromise. No such secret exists today. |
| Overturns a documented architectural assumption | 3 | `referenceName`'s documented subject ("the operator's local secret store") is replaced by a server-side store. That assumption is load-bearing in six artifacts. |
| Introduces a credential-minting endpoint on an unauthenticated, not-loopback-pinned control plane | 3 | `C-07` + `C-08`. This is the first endpoint whose side effect is *persisting secret material*. |
| Changes the core registration workflow | 3 | Key generation and host trust become preconditions of registration — a change to the primary user flow and its mental model. |
| Introduces an SSH transport trust seam that does not exist | 2 | Host-key verification has no implementation anywhere; the seam is new. |
| Changes an existing generated wire contract | 2 | Removing `referenceName` from `RepositoryCredentialView` requires regenerating both `apps/server` and `packages/control_plane_client` protocols. |

Per `DESIGN_GOVERNANCE.md` § Design-Change Risk Levels, Level 3 requires **product/design/architecture
human approval** at Gate D4. This brief does not pre-empt it.

---

## Implications for the sibling lane (points 2e / 2f)

Stated so `design-addproduct-mobile` can align. **Not** designed here.

1. **Button gating becomes two-factor, and the helper copy must say so.** `canRegister` mirrors the
   server's `canReachRepository` and therefore requires *both* a verified credential *and* a confirmed
   host. The helper text beneath **Register product** (point 2e) should name the unmet precondition
   in the user's terms, not merely "disabled".
2. **The top-of-page step list must match the real order.** The engine forbids an access check before
   host confirmation (`recordCredentialCheck` refuses a non-permitting host), so the enforced order is
   **Generate → Trust → Check → Register**, in that order, with **four** steps — not the current
   three-step `_StepText` list (`add_product_page.dart:650-672`).
3. **Two client enums, not one.** The host-trust axis is orthogonal to the access axis. A single
   `AccessStatus` cannot express `hostUnrecognised` or `changed`.
4. **`hostUnrecognised` is a blocking step with no escape control on the panel.** Any board that shows
   a dismiss affordance there contradicts `AC-05`. The way out is the back link / bottom nav, which is
   a route, not a control on the trust card.
5. **"ed25519 · created on this device · the private half stays in the keychain" (`:542`) is false
   under `DEC-b869ec24`** and must be restated to describe the server-side store honestly — subject to
   what Gate D4 actually decides about that store.

## Ready for Gate D1

Ready for Independent Design Review. Not approved by its author.