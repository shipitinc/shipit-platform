# Subtask Prompt — design-addproduct-keyservice

Persisted per `aef-orchestrator` §14 **before** launch. Rendered from
`.agents/skills/aef-orchestrator/templates/subtask-prompt.md`, every key filled.

## Mandatory header

```yaml
MANAGER: orchestrator-main
TASK_ID: design-addproduct-keyservice
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — server-side deploy-key service + hostUnrecognised trust state
AREA: server-side deploy-key generation/storage/retrieval; SSH host-trust state machine
WORKTREE: /private/tmp/shipit-design-addproduct-keys
BRANCH: design/addproduct-keyservice
BASE_SHA: 77c19f1
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
  - apps/control_plane/lib/**          (production source — you design it, you do not write it)
  - apps/server/lib/**                 (production source)
  - apps/server/migrations/**          (a design artifact may PROPOSE a migration; it must not create one)
  - packages/**                        (production source)
  - docker/**                          (see hard rule: no Docker command may be executed)
  - .github/workflows/**
  - .decisions/**                      (Manager-owned)
  - docs/engineering/WORK_STATE.md     (Manager-owned)
  - docs/engineering/dispatch/LANES.md (Manager-owned)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**  (the other lane's artifacts)
  - Penpot boards named as owned by lane design-addproduct-mobile (read them; never create/edit boards)
ACCEPTANCE_CRITERIA: |
  A Design Brief (Gate D1-ready) plus a Design Revision (Gate D3-ready) covering exactly:
  (1) server-side deploy-key service — keypair generation, private-half storage and its
      at-rest protection, and an endpoint that returns ONLY the public half;
  (2) the `hostUnrecognised` trust state with NO Cancel affordance.
  Both artifacts must trace to the four resolved Human Decisions, reuse the existing
  domain contract rather than inventing a parallel one, and carry an explicit
  `RISK_LEVEL` assessment. The at-rest protection model must be presented as an OPEN
  D4 DECISION with atomic options — NOT chosen by you.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-design-addproduct-keys && git branch --show-current   # must print design/addproduct-keyservice
  - cd /private/tmp/shipit-design-addproduct-keys && git rev-parse --short HEAD  # must print 77c19f1
  - grep -rn "RepositoryCredential\|recordGeneratedCredential\|product_credential" apps/server/lib packages --include="*.dart"   # the reuse surface you must design onto
  - grep -rn "canRegister\|canGenerateKey\|AccessStatus\." apps/control_plane/lib   # the client state you must model against
ROUTING_CLASS: PRECISION
```

## Isolation pre-flight (run this first)

```bash
cd /private/tmp/shipit-design-addproduct-keys
git branch --show-current    # must equal design/addproduct-keyservice
git rev-parse HEAD           # must equal 77c19f1
```

If either check fails, STOP and report `RESULT: DESIGN_REVISION_BLOCKED` with the observed
values. Do not write anything.

## Original request (verbatim)

The human's work item, verbatim:

> 1. It looks like we're missing mobile designs for these screens
> 2. It looks like our implementation agent failed in it's implementation of these designs in that:
>    a. The UI seems to indicate the Add a product page should generate a key on Repository SSH URL input
>    b. And that Register product is dependent on upon this key generation and trust of this host before product creation
>    c. It's not documented what Check access is supposed to do
>    d. Design allows for cancelling the trust this host operation, but I don't think we want to allow that b/c it causes us to get stuck and unable to register
>    e. Only "Registers product" is supposed to be in the button. The helper text goes below and according to the design seems to indicate starting with the top what the user must do to enable the Register product button.
>    f. Furthermore there's no copy at the bottom and only one footer line according to the design for Add a product. There's only a Show technical details widget down there.
>
> Using the penpot design add mobile light and dark counterparts to penpot for the add product page and implement the Add Product page correctly in SHIP IT.

Human addenda, verbatim:

> 1. We should have an API for private-key creation and storage. B/c we won't be git pushing in SHIP IT from the web browser from it's backend correct. This should settle your issue there.
> 2. Even if we remove cancel from the key flow we can always just go back to teh products page. We're not blocked, and if when down the road we want to create that product we'll find the key on the machine ready to be verified again.

**This lane owns points 2a, 2b, 2c, 2d only.** Points 2e and 2f, and the missing mobile
boards, belong to the sibling lane `design-addproduct-mobile`. Do not design them here; you
may state what your state machine implies for them so the sibling can align.

## ⚠ Manager correction to a previously recorded VERIFIED FACT — read before designing

`docs/engineering/WORK_STATE.md` § VERIFIED FACTS and Human Decision `b869ec24` both record
that **no deploy-key infrastructure exists server-side** ("grep for `deployKey`/`deploy_key`
across `apps/server/lib` and `packages/*/lib` returns nothing"). **That grep was run against
the wrong identifiers and its conclusion is wrong.** The infrastructure is named `credential`,
not `deploy_key`. Verified by the Manager at `77c19f1`; you must design ONTO this surface, not
invent a parallel one:

| What already exists | Where |
|---|---|
| `RepositoryCredential` domain type — carries NO key material; `referenceName` names the private half, never its value | `packages/platform_contracts/lib/src/types/repository_credential.dart` |
| `CredentialStatus` = `generated \| verified \| failing \| revoked`, `isUsable` only when `verified` | `packages/platform_contracts/lib/src/enums/credential_status.dart` |
| `HostKeyStatus` = `unknown \| confirmed \| changed`, `permitsConnection` only when `confirmed`, `changed` fails closed | same file |
| `canReachRepository` = `status.isUsable && hostKeyStatus.permitsConnection` (BOTH halves required) | `repository_credential.dart:128` |
| `isHostConfirmed`, `supersedesCredentialId` (rotation), `revokedAt/revokedReason` | same |
| Store API: `saveProductCredential`, `readProductCredential`, `readActiveCredentialForRepository`, `readCredentialsForProduct` | `packages/product_registry/lib/src/store/product_registry_store.dart:35-54` |
| `recordGeneratedCredential({...})` — already records a generated credential and **enforces one active credential per repository** (throws unless `supersedesCredentialId` matches) | `packages/product_registry/lib/src/engine/product_registry_engine.dart:898-960` |
| `product_credential` table, `serverOnly: true`, no key material columns | `apps/server/lib/src/database/repository_credential.spy.yaml`, table in `apps/server/migrations/*/definition.sql` (12 of them) |
| `RepositoryCredentialView` wire type + `UiViewMappers.repositoryCredentialView` | `apps/server/lib/src/models/repository_credential_view.yaml`, `apps/server/lib/src/services/ui_view_mappers.dart:169` |
| Already surfaced to the client as `ProductDetailView.credentials` | `apps/server/lib/src/services/control_plane_service.dart:362-403` |

So what is genuinely **missing** is narrower than "net-new capability": keypair generation, a
private-half store, any caller of `recordGeneratedCredential`, an endpoint that triggers
generation, and real SSH host-key verification. Design exactly that gap.

Two further facts you must design around:

1. **`referenceName` currently means "the operator's LOCAL secret store"** (ADR 0018 A1, per
   the doc comments). Human Decision `b869ec24` moves generation AND storage **server-side**.
   That is a deliberate override of the existing contract's assumption. Your design must state
   the reconciliation explicitly — whether `referenceName` is redefined, whether a new column
   is needed, and what the wire contract tells the client.
2. **ADR 0018 does not exist in this repository.** `docs/engineering/adr/` contains only
   `0001`, `0002`, `0003`. Code comments cite "ADR 0018" and "AGENTS.md §13a"; neither is
   present (`AGENTS.md` is the 71-line framework template). You cannot read your own governing
   ADR. Record this as an explicit traceability gap and state every assumption you had to make
   in its place. Do not invent ADR content and present it as authoritative.

## Context and authoritative sources

- Human Decisions (all RESOLVED — read them, do not re-open):
  - `.decisions/73097d48-3e8b-48d7-b3d8-8834168c5113.yaml` — PRODUCT, OPTION_A: real deploy-key
    generation over the mock; folded the parked register-button round into this item.
  - `.decisions/b869ec24-236e-4e9c-8703-70656fa368c4.yaml` — ARCHITECTURE, OPTION_A: generate and
    store **server-side** behind an API returning only the public half, because SHIP IT pushes
    from its backend.
  - `.decisions/048f3367-5836-43c8-af05-747dbc9d3afd.yaml` — SECURITY: API auth deferred, with a
    blocking production precondition. **Your new endpoint inherits a control plane that is
    currently unauthenticated** (`apps/server/lib/server.dart:71-72`). Design must state the
    exposure of a credential-minting endpoint under that posture; do not silently assume the
    deferred auth will be there.
  - `.decisions/570bb640-76e1-485d-9a80-309b07585ccd.yaml` — DEPLOYMENT_AUTHORITY: "local only"
    scope must be ENFORCED, not assumed; compose port bindings were found published on
    `0.0.0.0`.
- Parked prior review whose blockers are folded into this scope:
  `docs/engineering/dispatch/tasks/design-register-button/report.md` — findings **B4** (the key
  is a mock), **B5** ("Check access" is a control that cannot succeed), **B6** (each press of
  "Check access" silently rotates the key the user just copied), and the D6 SSH trust-on-first-use
  escalation now answered by the human's point 2d.
- Governance: `docs/engineering/DESIGN_GOVERNANCE.md` (gates D1–D5, risk levels 0–3,
  `DESIGN_REVISION` metadata fields), `docs/engineering/WORKFLOW.md` (authoritative ordering),
  `docs/engineering/LEARNING_POLICY.md`, `docs/engineering/STRUCTURED_RESULTS.md`.
- Requirements/architecture refs: `docs/engineering/WORK_STATE.md` § WORK_ITEM "Add Product rebuild"
  and § HUMAN SCOPE.
- Client code under design: `apps/control_plane/lib/features/products/add_product_page.dart`.
- Design Contract ref: `n/a` (this revision will become it).
- QA Contract ref: `n/a` (dispatched separately, in parallel, after this revision).
- Dependencies already merged: everything on `main` @ `77c19f1`.
- Other lane currently running, and its OWNED_PATHS: **`design-addproduct-mobile`**, branch
  `design/addproduct-mobile`, worktree `/private/tmp/shipit-design-addproduct-mobile`, owning
  `docs/engineering/dispatch/tasks/design-addproduct-mobile/**` and the four Penpot boards
  `SM - Add Product - Unknown host - Light/Dark` and `SM - Add Product - Verified - Light/Dark`
  (390x844) on Penpot page `d8ac01df-6646-81d2-8008-a366c09aa9d3`. Its `OWNED_PATHS` do not
  intersect yours. It owns human points 2e/2f and all board copy; you own no boards. Do not
  create or edit any Penpot board.
- Work this lane blocks: `design-review-addproduct-keyservice`, then Gate D4, then the
  `implement-addproduct` lane and the `qa-contract-addproduct` lane.
- Open Human Decision ids this lane depends on: none — but you must **produce** one.

## Design requirements you MUST satisfy

### R1 — the at-rest protection model is a D4 DECISION, not your call

The human said, verbatim: *"I have NOT approved the at-rest protection model for the
server-stored private half. Surface it as a decision at Gate D4; do not default it."*

Therefore your Design Revision must contain a **decision proposal with 2–4 atomic options**, a
recommendation, evidence, and risk — covering at minimum:

- the storage substrate for the private half (e.g. filesystem with restrictive permissions vs.
  an OS/hardware keystore vs. an external secret manager vs. envelope-encrypted column);
- what the server does when it **cannot** protect the key adequately — refuse to mint and say
  so, or mint with a recorded warning. This is a fail-open vs fail-closed choice and it is the
  human's to make;
- key lifecycle: rotation, revocation, and what happens to the stored private half on
  credential revocation (`revokedAt`/`revokedReason` already exist in the contract);
- whether the private half is ever readable by a process other than the git-push path.

Design the **interface and the decision**, and stop at the boundary of the decision. Do not pick
a winner in normative text. If your artifact's normative sections require a choice to be
well-formed, mark the choice explicitly as `OPEN — HUMAN DECISION REQUIRED AT GATE D4` and
enumerate the consequences of each option there.

### R2 — the `hostUnrecognised` trust state, with NO Cancel

The human's point 2d: the design must NOT allow cancelling the trust-this-host operation,
because cancelling dead-ends the user. Addendum 2 records why that is safe: the Products page is
always reachable and the key persists on the machine, so the product can be registered later and
the key re-verified.

Design:

- the state machine for host trust, grounded on the **existing** `HostKeyStatus`
  (`unknown` → `confirmed` | `changed`); `changed` fails closed and is indistinguishable from
  interception — your design must give it a user-facing path;
- the absence of any Cancel/reject affordance on the trust step, stated as a **normative
  requirement with its rationale**, so an implementer cannot reintroduce one;
- the way out: navigation back to the Products page, and how the persisted key + credential
  make later registration possible. State the concrete mechanism (which record is read on
  re-entry) — "the key persists" must be traceable to a field and a read path, not a hope;
- what the user is shown and asked to confirm **out of band** (the existing doc comment on
  `HostKeyStatus` already says SHIP IT cannot verify a host on the operator's behalf and does not
  claim to — keep that honesty).

### R3 — "Check access" must be documented and must actually work

The human's point 2c: it is not documented what "Check access" is supposed to do.

Design its normative meaning — what it attempts, against which host, with which credential, what
"success" proves, what "failure" distinguishes (host untrusted vs. credential not installed vs.
network), and the state transitions each outcome drives. `recordGeneratedCredential` and
`CredentialStatus.verified`/`lastVerifiedAt`/`lastFailureReason` are the vocabulary.

**Kill finding B6:** the current code regenerates the keypair on every "Check access" press
(`add_product_page.dart:113-120`) while "Copy public key" copies the current one, so the key a
user just installed is silently orphaned. Your design must make key generation happen exactly
once per credential and make every subsequent access check reuse the same `credentialId`.
`recordGeneratedCredential`'s one-active-credential-per-repository rule
(`product_registry_engine.dart:940-944`) is the constraint that makes repeated generation an
error condition, not a UX detail.

### R4 — reuse, do not reinvent

Every element you design must map to an existing named artifact (table, column, domain type,
enum member, store method, engine method, view field). Where you need something genuinely new,
say so explicitly and justify it. A parallel credential abstraction beside
`RepositoryCredential` is a review blocker.

### R5 — the endpoint

Design the API surface that returns **only the public half**. State the request, the response
fields, the error cases, and — under the currently-unauthenticated control plane
(decision `048f3367`) and the unenforced "local only" scope (decision `570bb640`) — what
protects a credential-minting endpoint from an off-host caller. If your honest answer is "nothing
today", say that plainly and make it a consequence of the revision, not a footnote.

### R6 — traceability and risk

- Trace every design element to a requirement id and to at least one of the four decisions.
  `DESIGN_GOVERNANCE.md` requires `traceability.requirements_covered` and
  `requirements_gaps`; report gaps rather than hiding them.
- Assign `RISK_LEVEL` 0–3 with rationale. The Manager's expectation is **2 or 3**: this changes
  a documented gate (ADR 0018's local-secret-store assumption) and it handles key material. If
  you conclude otherwise, argue it — but do not understate to avoid the human gate.
- Fill `design_system_compliance`, `ux_accessibility_score`, `implementation_feasibility`. If you
  cannot substantiate one, report `UNKNOWN` and say why. **Do not claim a gate you did not run.**
  The prior review recorded a lane asserting `implementation_feasibility: HIGH` while its
  `flutter analyze` had never actually resolved packages.

## Acceptance criteria

- [ ] Design Brief persisted with every field `DESIGN_GOVERNANCE.md` § Design Brief requires
      (`brief_id`, `version`, `status`, `requirements_refs`, `architecture_refs`,
      `problem_statement`, `user_flows`, `success_criteria`, `constraints`, `acceptance_criteria`,
      `risk_assessment`, `created_by`, `created_at`).
- [ ] Design Revision persisted with a `design-revision-metadata.yaml` carrying every required
      metadata field listed in `DESIGN_GOVERNANCE.md` § Design Revision.
- [ ] R1 satisfied: at-rest protection presented as an open D4 decision with 2–4 atomic options,
      a recommendation, evidence and risk. **Not defaulted anywhere in normative text.**
- [ ] R2 satisfied: `hostUnrecognised` state machine grounded on existing `HostKeyStatus`, with
      NO Cancel stated normatively plus the reason, plus the traceable way out.
- [ ] R3 satisfied: "Check access" documented normatively, and B6 (silent key rotation)
      structurally impossible by design.
- [ ] R4 satisfied: a reuse table naming each existing artifact each element maps onto.
- [ ] R5 satisfied: endpoint contract specified, with its auth exposure stated.
- [ ] Traceability matrix present, with ADR-0018-absent recorded as a gap and every substitute
      assumption listed.
- [ ] `RISK_LEVEL` assigned with rationale; self-assessment fields honestly filled.
- [ ] Report conforms to `.agents/skills/aef-orchestrator/templates/subtask-report.md` and the
      `design-agent` result block in `.agents/agents/design-agent.md`, verbatim.
- [ ] Durable discoveries classified per `docs/engineering/LEARNING_POLICY.md` — in particular the
      **Manager correction above**: the ledger's "zero deploy-key infrastructure" fact is false
      and any future session would repeat a wrong grep. That is exactly the kind of finding
      `LEARNING_POLICY.md` wants persisted as executable knowledge.

## Required validation commands

Run each and report its exact result. `NOT_RUN` is an acceptable answer; a fabricated `pass` is not.

- [ ] `cd /private/tmp/shipit-design-addproduct-keys && git branch --show-current` — isolation proof.
- [ ] `cd /private/tmp/shipit-design-addproduct-keys && git rev-parse --short HEAD` — must be `77c19f1`.
- [ ] `grep -rn "RepositoryCredential\|recordGeneratedCredential\|product_credential" apps/server/lib packages --include="*.dart"` — the reuse surface; confirm every row of the table above.
- [ ] `grep -rn "canRegister\|canGenerateKey\|AccessStatus\." apps/control_plane/lib` — the client state you model against.
- [ ] `grep -c "RepositoryCredentialView" apps/server/lib/src/endpoints/*.dart` — expected **0**: confirm no endpoint currently exposes a credential view, so your endpoint is genuinely new surface and not an existing method.
- [ ] `ls docs/engineering/adr/` — confirm ADR 0018's absence yourself; do not take the Manager's word.

Do not weaken, skip, delete or ignore anything to reach a clean result. If a required check cannot
pass, report it with evidence.

## Hard rules for the child

- Write only inside `OWNED_PATHS`. Never touch `PROHIBITED_PATHS`.
- **Do not run any Docker or Compose command — not even a read-only one.** This repository has
  already lost a QA database to a review lane running
  `docker compose -f docker/compose.qa.yaml down -v`. There is **no** read-only-over-Docker rule
  in `AGENTS.md` yet (that rule is itself pending at Gate D4 as item G-2), so the only safe
  posture is: run none. If a design claim would need a running stack to verify, mark it
  `UNVERIFIED` and say what command a human should run.
- Do not commit or push unless this prompt explicitly instructs it. It does not. Leave your
  artifacts in the worktree; the Manager persists them.
- Do not approve your own work. `READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES` is a readiness claim,
  never an approval.
- Stop and report rather than settling a product, architecture, security, infrastructure,
  destructive-operation or deployment-authority question yourself. R1 is the deliberate example:
  surface it, do not answer it.
- Every result carries exact repository/worktree/HEAD provenance.

## Cleanup before returning

- [ ] Stop every process you started; report any port/PID left running.
- [ ] No Docker container, volume, network or project created by this lane (you should have
      created none).
- [ ] Temporary artifacts removed.
- [ ] `git status --short` in your worktree shows only your `OWNED_PATHS` additions.

## Report format

Return a report conforming to
`.agents/skills/aef-orchestrator/templates/subtask-report.md`, with the `RESULT:` block emitted
verbatim from `.agents/agents/design-agent.md`:

```
RESULT: DESIGN_REVISION_COMPLETE | DESIGN_REVISION_BLOCKED
```
