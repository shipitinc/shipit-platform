RESULT: DESIGN_REVISION_COMPLETE
TASK_ID: design-addproduct-keyservice
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — server-side deploy-key service + hostUnrecognised trust state
WORKTREE: /private/tmp/shipit-design-addproduct-keys
BRANCH: design/addproduct-keyservice
BASE_SHA: 77c19f1
HEAD_SHA: 77c19f1
COMMITTED: NO

---

## Files touched

```text
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-brief.md
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision.md
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata.yaml
docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix.md
docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md
docs/engineering/dispatch/tasks/design-addproduct-keyservice/report.md
```

All six are inside `OWNED_PATHS`. Verified with `git status --porcelain`: nothing outside
`docs/engineering/dispatch/tasks/design-addproduct-keyservice/` was added or modified. **No commit, no
push** (`COMMITTED: NO`) — artifacts are left in the worktree for the Manager to persist.

---

## What changed and why

- **Corrected a false VERIFIED FACT and designed onto the real surface.** `WORK_STATE.md` and
  `DEC-b869ec24` both record "no deploy-key infrastructure exists server-side", from a grep for
  `deployKey`/`deploy_key`. Those are the wrong identifiers — the infrastructure is named
  `credential` and substantially exists. I re-verified it myself and designed onto it: a 35-row reuse
  table maps every element to a named existing artifact (`RepositoryCredential`, `CredentialStatus`,
  `HostKeyStatus`, `product_credential`, `RepositoryCredentialView`, 4 store methods, 6 engine
  methods, the 16-test credential suite). **No parallel credential abstraction.**
- **Narrowed the gap to what is actually missing**: keypair generation, a private-half store, any
  caller of `recordGeneratedCredential`, the mint/check endpoints, and real SSH host-key verification.
- **New: interface/schema change — none proposed.** `referenceName`'s documented *subject* changes
  (operator's local store → SHIP IT's own store) while the field, its type and the schema stay
  put. No migration is proposed, which is why nothing under `apps/server/migrations/**` was touched.
- **Two OPEN Gate D4 decisions surfaced, neither answered.** `OPEN-D4-1` is the at-rest model the
  human explicitly reserved. `OPEN-D4-2` I found while reading the engine and is **not** in the
  dispatch: human point 2b is *circular* against the credential domain.
- **Four named new server-side items** — `mintOrReadDeployKey`, `checkRepositoryAccess`,
  `DeployPublicKeyView`, `CredentialCheckResultView` — plus a client `HostTrustStatus` enum, all
  justified against the reuse table.

### Deviations from the plan, and why

- **Added `OPEN-D4-2`**, a second human gate the dispatch did not anticipate. I could not design the
  trigger honestly without it: `recordGeneratedCredential` (`engine:924-925`) requires the `Product`
  and `RepositoryReference` rows to exist, and `createProduct` is the thing "Register product" does.
  Choosing between breaking 2a/2b, breaking product-ownership scoping, or breaking the audit trail is
  a product/architecture judgement, so I presented three options and recommended one **without**
  defaulting it.
- **Report `implementation_feasibility: MEDIUM`, not `HIGH`.** The domain half is high-confidence, but
  I found that **no SSH host-key verification exists anywhere** in the repository and
  `GitWorkspaceInspector._capture` passes no `environment:` — so the transport seam is net-new and
  security-critical. Claiming `HIGH` would repeat the prior review's finding.
- **Report `design_system_compliance: PARTIAL`.** I may not author or edit Penpot boards in this
  lane, so visual/token compliance for the two new states is unverifiable by me.

---

## Validation results

| Command | Status | Evidence / note |
|---|---|---|
| `git branch --show-current` | pass | prints `design/addproduct-keyservice` |
| `git rev-parse --short HEAD` | pass | prints `77c19f1` |
| `grep -rn "RepositoryCredential\|recordGeneratedCredential\|product_credential" apps/server/lib packages --include="*.dart"` | pass | Confirms **every** row of the Manager's table: `repository_credential.dart:36`; `credential_status.dart:6,41`; `product_credential` at `repository_credential.spy.yaml:2`; `repository_credential_view.yaml:6`; `product_registry_store.dart:39-55`; `product_registry_engine.dart:912,974,1020,1058,1084,1138`; `postgres_product_registry_store.dart:173-320`; `ui_view_mappers.dart:169`; `control_plane_service.dart:362-403` |
| `grep -rn "canRegister\|canGenerateKey\|AccessStatus\." apps/control_plane/lib` | pass | Confirms the client state and adds two facts the dispatch did not state: `AccessStatus.verified` is **never assigned** (only `:118 → notChecked`), and `canGenerateKey` (`:230`) has **zero** call sites — a bootstrap deadlock distinct from B5 |
| `grep -c "RepositoryCredentialView" apps/server/lib/src/endpoints/*.dart` | pass | **0** for all 11 endpoint files (exit 1, no matches) — confirms the mint endpoint is genuinely new surface, not an existing method |
| `ls docs/engineering/adr/` | pass | `0001`, `0002`, `0003` only. **ADR 0018 absent.** `AGENTS.md` sections contain no §13. Both verified independently, as instructed |
| `ruby -ryaml` parse of `design-revision-metadata.yaml` | pass | All 17 required metadata fields present; `risk_level`=3 (Integer), `revision_number`=1 (Integer); 18 `requirements_covered`, 11 `requirements_gaps` |
| All 13 § Design Brief field names present | pass | Verified by field-name grep after adding an explicit machine-readable block |
| `dart analyze` / `flutter analyze` | **NOT_RUN** | Implementation-lane gate, not a design-lane gate. **No feasibility claim is derived from it.** |
| Any build / test run | **NOT_RUN** | I wrote no production code; there is nothing of mine to build or test |
| Any Docker or Compose command | **NOT_RUN — deliberately prohibited** | No container, volume, network or project created. The 4 claims needing a running stack are marked `UNVERIFIED` with the command a human should run |

---

## Evidence (revision-pinned)

```yaml
EVIDENCE_REVISION: 77c19f1
BUILD_COMMAND: n/a — design-only lane; no production code written
SERVE_OR_RUN_COMMAND: n/a
ENVIRONMENT / BASE_URL: n/a
ARTIFACTS:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-brief.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata.yaml
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md
```

No runtime, browser or visual evidence is claimed. The a11y contrast figures in the revision are
**inherited** from `design-register-button/report.md:71-76` and are labelled as inherited, not
re-measured by me.

---

## Documentation updated

```text
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-brief.md            (new)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision.md          (new)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata.yaml (new)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix.md     (new)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md             (new)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/report.md                  (new)
```

`WORK_STATE.md`, `.decisions/**` and `docs/engineering/dispatch/LANES.md` are Manager-owned and were
**not** touched — including the corrections D-1, D-6 and D-7 identify for them.

---

## Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: PRECISION
MODEL_USED: opencode/space-bunny-free
REASONING_EFFORT: as dispatched
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

---

## Unresolved issues and blockers

- **`OPEN-D4-1` — at-rest protection model** (the decision the human reserved). One sentence each:
  - *Q1: Which substrate holds the server-stored private half — filesystem `0600` (A1),
    envelope-encrypted ciphertext in a separate table (A2), an external secret manager (A3), or a
    host keychain (A4)?* Recommendation: A3 if reachable in the topology, else A2. **MEDIUM**.
  - *Q2: When the server cannot establish adequate protection, does it refuse to mint (B1,
    fail-closed) or mint with a recorded warning (B2, fail-open)?* Recommendation: B1, and only with
    a named remediation. **MEDIUM**. *Note the tension: B1 is safe but can recreate the "stuck and
    unable to register" outcome point 2d objected to, which is why its remediation text is a design
    obligation.*
  - *Q3: On revocation, is the private half destroyed (C1), retained (C2), or retained then
    destroyed (C3)?* Recommendation: C1. **MEDIUM**.
  - *Q4: may `referenceName` continue to reach the client?* Coupled to Q1 — under A3 it is an ARN and
    the most sensitive variant. Recommendation: remove it (gap `G-7`).
- **`OPEN-D4-2` — registration ordering.** One sentence: *Which resolves the circular dependency
  between human point 2b (registration gated on a credential) and the domain's requirement that the
  Product and RepositoryReference rows exist before one can be minted — split identity from
  registration (1), decouple the credential from product ownership (2), or mint at registration (3)?*
  Recommendation: 1. **MEDIUM**.
- **`D-6` for the Manager — ADR 0018 and `AGENTS.md §13a` do not exist.** Nine code locations cite
  them. I recorded **ten** substitute assumptions instead and invented no ADR content. Correcting the
  dangling citations is a Manager action; a lane that later cites ADR 0018 will be citing a document
  neither it nor I has read.
- **`D-1` for the Manager — correct the ledger.** The "zero deploy-key infrastructure" VERIFIED FACT in
  `WORK_STATE.md:329-330` and `DEC-b869ec24` is false. Any future session repeating that grep will
  reach a false conclusion and may invent a parallel abstraction. This is the single most
  consequential finding in my report.
- **`D-7` — the loopback-pinning mitigation is NOT implemented** (`grep "127.0.0.1:"` → no match), so
  `DEC-570bb640`'s accepted risk is live on any shared network today. Deployment lane.
- **`D-3` for the implementation lane — `HostKeyStatus` has no runtime enforcer.** No SSH host-key
  verification exists anywhere, and `git_workspace_inspector.dart:106-112` runs `Process.run` with no
  `environment:`. The engine's "refuses unconfirmed hosts" guarantee is currently decorative.
- **Unchanged and outstanding from earlier rounds:** `G-2` (no read-only-over-Docker rule in
  `AGENTS.md`), `G-3` (0 tests import `add_product_page.dart`), `G-8` (fingerprint provenance
  unspecified).

---

## Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - qa-contract-addproduct — can start once this revision passes Gate D3; the acceptance criteria
    (AC-01..AC-14) and success criteria (SC-01..SC-10) are stable enough to draft a QA Contract against.
    It must treat SC-08 as an OPEN D4 dependency, not as a testable assertion.
  - design-addproduct-mobile — unaffected. Its OWNED_PATHS do not intersect mine and it owns no
    artifact of mine. I recorded five alignment implications in the brief (two-factor button gating;
    the enforced four-step order Generate -> Trust -> Check -> Register; two orthogonal client enums;
    no escape control on the trust card; the "private half stays in the keychain" copy is false under
    b869ec24) so neither lane has to guess at the other's work.
  - deploy-key-port-contract discovery (read-only) — the endpoint shapes are resolution-independent.
PROHIBITED_PARALLEL_WORK:
  - implement-addproduct — because the private-half store is UNDECIDED (OPEN-D4-1). Implementing a
    substrate now would pre-empt a decision the human explicitly reserved, and every option has a
    different migration and dependency footprint.
  - implement-addproduct (the SSH transport seam) — because D-3 shows no host-key verification exists
    and that work is security-critical and needs its own review, not a side effect of this feature.
  - any lane editing apps/server/lib/**, apps/control_plane/lib/** or packages/** — production source;
    outside every lane's design ownership and outside mine.
  - any lane creating or editing a Penpot board on my behalf — I own none, and the sibling owns all four.
  - correction of the D-1/D-6 ledger facts by anyone other than the Manager — WORK_STATE.md and
    .decisions/** are Manager-owned.
```

---

## Cleanup confirmation

- [x] All processes started by this lane are stopped — **none were started**. No server, no
      container, no port bound, no PID left running.
- [x] Temporary artifacts removed — the one temp file used for the character scan
      (`/tmp/cjk_scan.txt`) was deleted.
- [x] No files modified outside `OWNED_PATHS` — verified via `git status --porcelain`.
- [x] No Docker container, volume, network or compose project created. **No Docker or Compose command
      was executed by this lane**, not even a read-only one.
- [x] No commit and no push, per the dispatch. `HEAD` is still `77c19f1`; the six artifacts are
      untracked additions for the Manager to persist.

---

## Recommended next action

`INDEPENDENT_DESIGN_REVIEW` — Gate D3. The revision is complete and ready for a reviewer to challenge.
**Both OPEN-D4 decisions remain open, so Gate D4 (`HUMAN_APPROVAL`) cannot be reached until a human
resolves them.**

---

RESULT: DESIGN_REVISION_COMPLETE

FEATURE: Add Product rebuild — server-side deploy-key service + `hostUnrecognised` trust state
BRIEF_ID: 97484D0E-E16C-485E-BAA2-A277889C0FB6
REVISION_ID: 46980EE0-E638-409C-A7D3-E1B9399FECE5
REVISION_NUMBER: 1
BRANCH: design/addproduct-keyservice
BASE_SHA: 77c19f1
HEAD_SHA: 77c19f1

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**

READ_ONLY_PATHS:
  - apps/control_plane/lib/features/products/add_product_page.dart
  - apps/control_plane/lib/features/products/**
  - apps/server/lib/src/endpoints/**
  - apps/server/lib/src/services/**
  - apps/server/lib/src/database/**
  - apps/server/lib/src/models/**
  - apps/server/migrations/**
  - packages/platform_contracts/lib/**
  - packages/product_registry/lib/**
  - docs/engineering/**
  - AGENTS.md
  - Makefile

PROHIBITED_PATHS:
  - apps/control_plane/lib/**
  - apps/server/lib/**
  - apps/server/migrations/**          (a migration may be PROPOSED; none was created)
  - packages/**
  - docker/**                          (no Docker command was executed, not even read-only)
  - .github/workflows/**
  - .decisions/**                      (Manager-owned)
  - docs/engineering/WORK_STATE.md     (Manager-owned)
  - docs/engineering/dispatch/LANES.md (Manager-owned)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - Penpot boards owned by design-addproduct-mobile (read only; none created or edited)

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-brief.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata.yaml
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/report.md

RISK_LEVEL: 3
RISK_RATIONALE: |
  Level 3 (Major Workflow / Navigation / IA Change) for four independent reasons, any one of which
  would be Level 2 or above.
  (1) HANDLING KEY MATERIAL FOR THE FIRST TIME — SHIP IT will hold a private key authorising WRITE
  access to a customer repository; no such secret exists today and compromise is irreversible without
  a host-side uninstall.
  (2) OVERTURNS A DOCUMENTED ARCHITECTURAL ASSUMPTION — RepositoryCredential.referenceName is
  documented as naming the operator's local secret store (repository_credential.dart:70-72) and that
  assumption is repeated across six artifacts; DEC-b869ec24 replaces its subject.
  (3) CHANGES THE CORE REGISTRATION WORKFLOW — human points 2a/2b make key generation and host trust
  preconditions of registration, altering the primary user flow and its mental model.
  (4) A CREDENTIAL-MINTING ENDPOINT ON AN UNAUTHENTICATED, NOT-LOOPBACK-PINNED CONTROL PLANE —
  server.dart:71-72 declares no authentication services, DEC-570bb640 accepts that for local/QA only,
  and its loopback-pinning follow-up is VERIFIED UN-IMPLEMENTED (grep "127.0.0.1:" across docker/*.yaml
  and apps/server/docker-compose.yaml returns no match). This is the first endpoint whose side effect
  is persisting secret material, and I state its exposure as a consequence of the revision rather than
  a footnote.
  I do not argue this down to 2. Understating it would push a decision the human explicitly reserved
  past the gate meant to catch it.
CHANGELOG: |
  Initial revision (1); no prior revision exists. 14 entries recorded in
  design-revision-metadata.yaml. Principal entries:
  - Corrected a false VERIFIED FACT (deploy-key infrastructure does exist; it is named "credential";
    the original grep used the wrong identifiers) and designed onto it with a 35-row reuse table
    rather than inventing a parallel abstraction.
  - Narrowed the gap to: keypair generation, a private-half store, any caller of
    recordGeneratedCredential, the mint/check endpoints, and real SSH host-key verification.
  - OPEN-D4-1: at-rest protection model surfaced as an OPEN Gate D4 decision with atomic options
    (4 substrates, 2 degraded-mode, 3 revocation-disposal) plus a recommendation with confidence and
    evidence. NOT defaulted in any normative section, per the human's explicit instruction.
  - OPEN-D4-2: surfaced a second OPEN Gate D4 decision found while reading the engine and not named
    in the dispatch — human point 2b is circular against the credential domain's product-ownership
    requirement. Three options, recommendation recorded, not selected.
  - R-2d: hostUnrecognised state machine grounded on the existing HostKeyStatus; the absence of any
    Cancel/Skip/Dismiss affordance stated as normative requirement N-1 with rationale and cost.
  - R-2c: "Check access" given a normative definition and a five-way failure taxonomy mapped onto the
    existing CredentialStatus.failing + lastFailureReason vocabulary.
  - R-B6: silent key rotation killed by four INDEPENDENT structural mechanisms, the strongest being
    that RepositoryCredential.copyWith cannot change publicKey or credentialId.
  - R-5: endpoint returning only the public half, with the honest statement that nothing protects it
    from an off-host caller today, and a deployment precondition instead of smuggled-in auth.
  - ADR-0018-absence recorded as a traceability gap with ten substitute assumptions; no ADR content
    invented.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - R-2a  (human point 2a — generate the deploy keypair from the repository SSH URL)
    - R-2b  (human point 2b — registration gated on key generation AND host trust)
    - R-2c  (human point 2c — "Check access" documented and able to succeed)
    - R-2d  (human point 2d — trust step has NO cancel affordance)
    - R-H1  (human addendum 1 — server-side API for private-key creation and storage)
    - R-H2  (human addendum 2 — Products page is the way out; the key persists for later)
    - R-B4  (finding B4 — the deploy key is a mock)
    - R-B5  (finding B5 — "Check access" is a control that cannot succeed)
    - R-B6  (finding B6 — each press silently rotates the key the user just installed)
    - R-R1  (dispatch R1 — at-rest model surfaced as an open Gate D4 decision, not defaulted)
    - R-4   (dispatch R4 — reuse the existing domain contract, do not reinvent)
    - R-5   (dispatch R5 — endpoint returns only the public half, with its exposure stated)
    - R-6   (dispatch R6 — traceability and risk; gaps reported, not hidden)
    - DEC-73097d48 / DEC-b869ec24 / DEC-048f3367 / DEC-570bb640 (all four resolved decisions)
    - ADR-0001 / ADR-0002 / ADR-0003 (the ADRs that exist and were read)
  REQUIREMENTS_GAPS:
    - OPEN-D4-1 (at-rest: substrate, fail-open-vs-fail-closed, revocation disposal, transport
      exposure) — OPEN, HUMAN DECISION REQUIRED AT GATE D4. The private-half store cannot be
      specified until resolved. Deliberately unanswered per the human's instruction.
    - OPEN-D4-2 (registration ordering) — OPEN, HUMAN DECISION REQUIRED AT GATE D4. Provable circular
      dependency; found while designing; not named in the dispatch.
    - G-1 ADR 0018 and "AGENTS.md 13a" are ABSENT (adr/ holds only 0001-0003; AGENTS.md has no 13).
      The governing ADR for the credential model cannot be read; 9 code locations cite it. Ten
      substitute assumptions recorded. No ADR content invented.
    - G-2  No read-only-over-Docker rule exists in AGENTS.md, so no runtime claim could be verified;
      four claims marked UNVERIFIED with the command a human should run.
    - G-3  Zero test files import add_product_page.dart, so SC-02/SC-04/SC-06 have no existing harness.
    - G-4  No SSH host-key verification exists anywhere; HostKeyStatus has no runtime enforcer.
    - G-5  No read-only endpoint for a product's public key; the client must hold a credentialId.
    - G-6  recordGeneratedCredential's host is optional and defaults to null; the domain does not
      enforce what the design requires.
    - G-7  RepositoryCredentialView exposes referenceName to clients — a path/ARN disclosure under
      server-side storage; coupled to OPEN-D4-1; removing it is a two-package generated-contract change.
    - G-8  Fingerprint provenance (ssh-keyscan vs handshake) unspecified; part of the new transport seam.
    - Human points 2e/2f and the four mobile Penpot boards are OUT OF SCOPE (sibling lane
      design-addproduct-mobile) and recorded as not-covered, not as gaps.

DESIGN_SYSTEM_COMPLIANCE: PARTIAL
UX_ACCESSIBILITY_SCORE: PARTIAL
IMPLEMENTATION_FEASIBILITY: MEDIUM

DISCOVERIES:
  - D-1 CONTRADICTION (Manager action) — the ledger's "zero deploy-key infrastructure" VERIFIED FACT is
    FALSE. It came from a grep for deployKey/deploy_key; the infrastructure is named "credential" and
    substantially exists. Re-verified at 77c19f1. Consequence: a future lane repeating that grep
    reaches a false architectural conclusion and may invent a parallel credential abstraction, which
    dispatch R4 calls a review blocker.
  - D-2 PROJECT_FACT (automatic) — the five exact greps that would have prevented D-1, recorded as
    executable knowledge per LEARNING_POLICY's "prefer executable knowledge".
  - D-3 ARCHITECTURE_DISCOVERY (human decision) — HostKeyStatus has NO runtime enforcer:
    git_workspace_inspector.dart:106-112 runs Process.run with no environment:, and a repo-wide grep
    for SSH_AUTH_SOCK|known_hosts|ssh-keyscan|StrictHostKeyChecking|IdentityFile returns no match. The
    engine's "refuses unconfirmed hosts" guarantee is decorative today.
  - D-4 ARCHITECTURE_DISCOVERY (human decision) — registering a product cannot be gated on a
    credential, because minting requires the Product and RepositoryReference rows that registration
    creates. Human point 2b is circular. Surfaced as OPEN-D4-2, not decided.
  - D-5 PROJECT_FACT (automatic) — RepositoryCredential.copyWith cannot change credentialId,
    referenceName, publicKey, fingerprint or algorithm. This immutability is what makes B6
    structurally impossible rather than merely discouraged.
  - D-6 CONTRADICTION (Manager action) — ADR 0018 and AGENTS.md 13a do not exist; 9 code locations cite
    them. Recorded 10 substitute assumptions instead of inventing ADR content.
  - D-7 PROJECT_FACT (automatic) — the loopback pinning DEC-570bb640 relies on is NOT implemented
    (verified negative), so its accepted risk is live on any shared network today.
  - D-8 PROJECT_FACT (automatic) — RepositoryCredentialView carries no publicKey, so the mint endpoint
    needs a dedicated response type; the upside is the public half stays out of ProductDetailView.
  - D-9 DESIGN_DISCOVERY (automatic) — B5 is TWO defects, not one: AccessStatus.verified is never
    assigned anywhere, AND canGenerateKey has zero call sites so the key panel can never render. A
    correction lane fixing only the first would still see no key panel.

KNOWLEDGE_PERSISTED:
  - Persisted inside OWNED_PATHS only: docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md
    (all nine discoveries, classified per LEARNING_POLICY.md with evidence and authority level).
  - NOT persisted, by ownership: the D-1, D-6 and D-7 corrections belong in WORK_STATE.md and a
    superseding decision note, both Manager-owned. Reported under Unresolved issues for the Manager
    to action; I did not touch them.
  - Authority respected: D-3 and D-4 are ARCHITECTURE_DISCOVERY and D-1/D-6 are CONTRADICTIONs — all
    above my authority, so all escalated rather than written into the ledger. Only PROJECT_FACT and
    DESIGN_DISCOVERY items (D-2, D-5, D-7, D-8, D-9) were persisted directly, each evidence-backed.

BLOCKERS:
  - OPEN-D4-1 (at-rest protection model) — blocks specifying the private-half store, therefore blocks
    implement-addproduct. HUMAN DECISION REQUIRED AT GATE D4. Explicitly reserved by the human.
  - OPEN-D4-2 (registration ordering) — blocks deciding which user flow triggers mint. Found while
    designing; not named in the dispatch. HUMAN DECISION REQUIRED AT GATE D4.
  - ADR 0018 / AGENTS.md 13a absent (G-1) — the governing ADR for the credential model cannot be read.
    Not blocking this revision (I recorded ten substitute assumptions with code evidence, each
    falsifiable by a reviewer), but it must not be cited as authority by anyone.
  - G-3/G-4: no test harness for add_product_page.dart and no SSH host-key verification exist, so
    SC-02/SC-04/SC-06 need a harness and a security-critical transport seam to be built. These block
    implementation, not this revision.
  - NOT blockers for this revision — explicitly recorded so no reviewer mistakes them for one:
    G-2, G-5, G-6, G-7, G-8, and human points 2e/2f + the four mobile boards (sibling lane).

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES