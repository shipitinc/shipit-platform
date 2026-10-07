# Report — Design Revision 3, `design-addproduct-keyservice` (Gate D4)

Persisted per `aef-orchestrator` §14. Lane: `design-agent`. Third revision of this design, and the first
written **against resolved decisions**.

```
RESULT: DESIGN_REVISION_COMPLETE

FEATURE:   Add Product rebuild — server-side deploy-key service, Design Revision 3
BRIEF_ID:  97484D0E-E16C-485E-BAA2-A277889C0FB6  (v1.1.0, not re-issued)
REVISION_ID: 4B017787-25A0-4F45-ABDA-805C250AF63F
REVISION_NUMBER: 3
BRANCH:    design-correct-addproduct-keys
BASE_SHA:  77c19f1
HEAD_SHA:  77c19f1

OWNED_PATHS:
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/**
    (created this pass: design-revision-3.md, design-revision-metadata-3.yaml,
     traceability-matrix-3.md, report-revision-3.md;
     edited this pass: design-revision-2.md [banner only], design-revision-metadata-2.yaml
     [banner only], design-revision.md [banner only], design-revision-metadata.yaml
     [banner only], discoveries.md [D-15…D-19 added; one "Not persisted" row replaced])

READ_ONLY_PATHS:
  docs/adr/**                                       (read ADR 0018 in full + 0012/0015/0019/0020/0021)
  .decisions/**                                     (read the six resolved objects; edited none)
  docs/engineering/**                               (DESIGN_GOVERNANCE, LEARNING_POLICY, WORKFLOW,
                                                     STRUCTURED_RESULTS, dispatch tasks, reports)
  apps/server/lib/**, apps/server/migrations/**, apps/server/tool/**, packages/**, apps/control_plane/**
  docker/compose.yaml, .env.example                (read AS TEXT; no Docker command of any kind issued)
  /private/tmp/shipit-credential-store @ 07c8c8f    (the store/engine/tests/migration — read-only)
  /Users/alkebut/air/shipit-platform @ 6220951      (main — read-only; the resolved decisions live here)

PROHIBITED_PATHS:
  production source (apps/**/lib/**, packages/**/lib/**)   — verified unmodified
  apps/server/migrations/**                                  — verified unmodified
  apps/control_plane/** (incl. golden baselines)              — verified unmodified
  docs/adr/**                                                — verified unmodified
  .decisions/**                                              — verified unmodified
  docker/**, .github/workflows/**, Makefile, AGENTS.md       — verified unmodified
  docs/engineering/dispatch/{WORK_STATE.md,LANES.md,DECISIONS.md} — verified unmodified
  docs/engineering/dispatch/tasks/design-addproduct-mobile/** — verified unmodified (sibling lane)
  .opencode/**, .claude/**, .junie/**                        — verified unmodified

ARTIFACT_PATHS:
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-3.md            (1709 lines, NEW)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-3.yaml (423 lines, NEW)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-3.md         (155 lines, NEW)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/report-revision-3.md            (this file, NEW)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-2.md            (+39 banner lines)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-2.yaml (+27 banner lines)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision.md             (+22 banner lines)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata.yaml  (+10 banner lines)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md                  (+D-15…D-19)

RISK_LEVEL: 3
RISK_RATIONALE: >
  RE-DERIVED, not inherited (DESIGN_GOVERNANCE Invariant 6). Two reasons improved, four unchanged or
  worse, and the net does not move.
  IMPROVED — (a) Revision 2's second reason ("a design whose outcome may contradict an existing ADR") is
  gone: the human resolved ADR 0018 :85-88, so the design now carries a known, human-owned, PENDING
  amendment rather than an unresolved contradiction; (b) zero Gate D4 decisions remain open, where Revision 2
  had four sub-questions across two objects.
  UNCHANGED OR WORSE — (1) first handling of key material, still irreversible (a leaked write key must be
  uninstalled at the host); (2) an unauthenticated, unpinned control plane — WORSE, because A3 adds a
  runtime dependency whose unavailability blocks the credential path, so the failure mode is disclosure AND
  denial; (3) the registration workflow — STRONGER, because the change is now identity semantics (a product
  is visible before registration commits) rather than a gate; (4) two live credential invariants — the
  original B6 is closed by D-1/D-2, but two new defects are reachable today through the public domain API,
  one of which erases a human's host confirmation and the other's re-points an installed key between
  repositories; (5) the SSH transport seam — WORSE, because it must now deliver TWO security-critical
  capabilities and one of them, host-key verification, is an ADR 0018 :96-99 REQUIREMENT with no
  implementation and no precedent anywhere.
  One reason improved and one worsened concern the SAME subject (the substrate decision), which is why the
  level holds. Level 3 requires human approval at Gate D4: the six decisions went through it; the CONTENT of
  this revision still requires it, and the ADR 0018 amendment is a blocking predecessor for implementation.

CHANGELOG: >
  Revision 3 incorporates the six resolved Gate D4 decisions. Revision 2 (F21D5C64-…) and Revision 1
  (46980EE0-…) are retained intact with supersession banners. Revision 2's DESIGN_REVIEW_APPROVED does NOT
  carry over — it certified Revision 2's content. Full per-decision changelog in
  design-revision-metadata-3.yaml; a section-level map in design-revision-3.md § 0.5; and a finding-by-
  finding correction map in § 0.3.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - "R-2a, R-2b, R-2c, R-2d (human points 2a–2d). R-2b is now SATISFIABLE and upheld as ADR 0018
       :100-102 rather than contradicted."
    - "R-H1 (server-side API for private-key creation and storage) — under A3 the server holds only a
       reference."
    - "R-H2 (Products page is the way out; the key persists) — now exact, and NARROWED under A3: re-entry
       also requires the manager to have been reachable at mint."
    - "R-B4 (the deploy key is a mock), R-B5 ('Check access' cannot succeed)"
    - "R-B6 — the ORIGINAL defect is CLOSED at the store by D-1/D-2, CONDITIONALLY on the endpoint
       requirement; the state-loss family around it is NOT closed (D-4, D-5)."
    - "R-R1 (at-rest model surfaced, not defaulted) — HONOURED and now DISCHARGED"
    - "R-4, R-5, R-6 (reuse; endpoint exposure; traceability and risk)"
    - "DEC-73097d48, DEC-b869ec24, DEC-048f3367, DEC-570bb640 (pre-existing)"
    - "DEC-9417f8bf OPTION_C, DEC-7b1bc8b7 OPTION_A, DEC-79e860e2 OPTION_A, DEC-898b07d0 OPTION_A,
       DEC-4d2c6b81 OPTION_A, DEC-27ea6536 OPTION_A-with-deviation (all six, newly)"
    - "M-3 and M-4, the two engineering-review findings confirmed real and reachable today"
  REQUIREMENTS_GAPS:
    - "G-4 — no SSH host-key verification exists anywhere; ADR 0018 :96-99 makes it a REQUIREMENT, so this
       is an ADR GAP, not only a missing feature. Re-verified at 07c8c8f. Under A3 the seam must ALSO
       resolve material from the manager. Owner: implementation (architecture), and it should get its own
       review."
    - "G-10 (NEW) — A3's reachability in the target topology is UNVERIFIED. No secret manager exists here, no
       probe was run, no Docker command was issued by this lane. Owner: implementer, before completion —
       this is the decision's own follow-up action."
    - "G-11 (NEW) — D-4 and D-5 are SPECIFIED, NOT BUILT. R-B6's state-loss family, two-sided revocation and
       N-7's durability all rest on them. 79e860e2's own follow-up test fails until D-4 lands."
    - "G-1' — AGENTS.md has no §13/§13b. Manager/human; NOT edited."
    - "G-3, G-5, G-6, G-8 — carried forward, unchanged"
    - "L-6 — DECISIONS.md's index omits 570bb640. Manager-owned; reported, not edited."
    - "A FALSE LEDGER FACT REMAINS: LANES.md:204-205 still asserts ADR 0018 / AGENTS.md §13a do not exist.
       Manager-owned; reported, not edited."
    - "THE ADR 0018 AMENDMENT IS A BLOCKING PREDECESSOR for implementation. Owner: the human, as ADR owner.
       This lane states the dependency contract (§ R.17) and does NOT edit docs/adr/**."
    - "§ R.5.2's ORDERING INTERPRETATION is flagged for human confirmation rather than absorbed: a substrate
       refusal writes nothing at all. 7b1bc8b7 and 898b07d0 interact and neither object says. See D-19."

DESIGN_SYSTEM_COMPLIANCE: PARTIAL
UX_ACCESSIBILITY_SCORE: PARTIAL
IMPLEMENTATION_FEASIBILITY: MEDIUM

DISCOVERIES:
  - "D-15  WORKFLOW_IMPROVEMENT (reusable; routed to independent review, NOT auto-persisted) — a design
     approved against unresolved human decisions is superseded the moment those decisions resolve, and the
     approval's value is bounded by the open set. A Gate D3 approval carrying OPEN-D4-* certifies THE
     FRAMING, not the design. Two executable rules follow: the approval record must name the open set, and
     a revision written against open decisions must carry a SUPERSEDED_BY_DECISION disposition before the
     resolutions land. Recorded IN THE ARTIFACT (design-revision-3.md § 0.2), not only in the review."
  - "D-16  PROJECT_FACT — a revision whose evidence lives on branches that are not ancestors of its own HEAD
     cannot be verified from its worktree. 07c8c8f and 674b871 are both NOT ancestors of 77c19f1 (verified).
     Includes the executable check."
  - "D-17  PROJECT_FACT — saveProductCredential's conflict branch is reachable ONLY by the mint path. All
     five engine call sites tabulated with expectedVersion; it is the entire safety argument for D-4."
  - "D-18  ARCHITECTURE_DISCOVERY (human/Manager) — a REVOKED credential can be resurrected by an
     identical-material re-mint, because readActiveCredentialForRepository excludes revoked rows so the
     engine's one-active guard cannot fire. Under 79e860e2 its manager handle is ALREADY DESTROYED, so the
     resurrected row claims a key that exists nowhere — and it then blocks the legitimate fresh mint on
     D-2's index. credential_test.dart:323 closes the CHECK path only. DERIVED IN THIS REVISION, not
     handed. Specified as D-4 / T-D."
  - "D-19  CONTRADICTION (human) — two binding decisions interact where neither object says so: a substrate
     refusal also has to answer whether the Product row is created. Resolved in the artifact as 'nothing is
     written at all', with the alternative reading named. Reported, not absorbed; not blocking."
  - "Carried forward unchanged and re-verified: D-3 (no runtime enforcer for HostKeyStatus) and D-7
     (loopback pinning un-implemented), plus H3/H4 (0.0.0.0:5432 with a committed default password)."

KNOWLEDGE_PERSISTED:
  - "discoveries.md — D-15…D-19 added, each with Category, Product-specific judgement and Authority per
     LEARNING_POLICY.md. D-1…D-14 unchanged, including the retracted D-6 and the restated D-7."
  - "Executable rather than prose where possible: D-17's call-site table is the checkable form of D-4's
     safety argument, and D-16 carries the exact git command that detects the provenance defect."
  - "D-15 is classified WORKFLOW_IMPROVEMENT and is explicitly NOT persisted as product knowledge — per
     LEARNING_POLICY.md §2 it is routed to independent review."
  - "D-18 and D-19 are classified ARCHITECTURE_DISCOVERY / CONTRADICTION and are REPORTED, not persisted by
     me: both exceed this lane's authority."
  - "NOTHING was persisted outside OWNED_PATHS. WORK_STATE.md, LANES.md, DECISIONS.md, .decisions/** and
     docs/adr/** were read and NOT edited — verified by git status."

BLOCKERS: none

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```

---

## Files touched

```text
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-3.md              (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-3.yaml   (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-3.md           (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/report-revision-3.md              (NEW, this file)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-2.md              (+39 banner lines)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-2.yaml   (+27 banner lines)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision.md               (+22 banner lines)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata.yaml    (+10 banner lines)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md                    (+D-15…D-19)
```

**Nothing outside `OWNED_PATHS`.** `git status --porcelain -uall` returns only the owned directory.
Revisions 1 and 2 are retained intact: the only changes are **additive banners**, verified by diff against
the canonical copies (`design-brief.md`, `design-brief-1.1.0.md`, `traceability-matrix.md`,
`traceability-matrix-2.md`, `report.md`, `report-revision-2.md`, `prompt.md` are byte-identical).

## What changed and why

**Revision 2 was superseded, not amended.** It was written against unresolved decisions; the human resolved
all six. Revision 3 replaces its central question rather than patching it. Seven substantive changes:

1. **The substrate question is closed and the option set is deleted from normative text.** `9417f8bf`
   OPTION_C — A3, an external secret manager. Revision 2 § R.4's four-option set, its `Q1`/`Q1′` framing and
   its confidence table are withdrawn (§ R.4 is now a withdrawal notice). A3 is specified concretely: the
   `SecretProvider` interface (§ R.1.2), how the reference is formed (§ R.1.3) and resolved at push time
   (§ R.1.4), and A1/A4 as the **documented fallback with an explicit trigger** — reachable only when no
   manager is *configured*, because a configured-but-down manager fails closed. **A2 is permanently
   excluded**: ADR 0018 `:87-88`'s *"never persisted to the durable record"* survives the supersession of
   `:85-88`. Nothing is hedged and nothing is re-presented.

2. **One design choice inside the decision, stated as a choice.** The decision's option text said
   *"`referenceName` is a secret path or ARN"*. Taken literally the durable record would carry vault
   topology — and that record is readable by an off-host caller using a password published in a committed
   file. So `referenceName` is specified as a **server-generated opaque handle** (`credbind_<32 hex`), with
   the manager's address and path prefix derived at resolve time from server configuration. § R.1.3 names
   the alternative, states its single cost, and records the rejection **so a reviewer can challenge it**.

3. **`G-7` is now REQUIRED work.** `RepositoryCredentialView` loses `referenceName` and gains nothing.
   Blast radius specified in seven rows — the model source, **two generated protocols** (this is the
   "generated-contract change in two packages"), the mapper, the hand-written client DTO, and the two
   display sites. Two substitutes ruled out with reasons (a digest enables cross-product correlation; a
   prefix discloses the naming scheme). And the easily-missed consequence recorded: **the `product_detail`
   golden baselines must be regenerated**, so a wire change surfaces as a *visual* regression.

4. **Fail closed with the remediation copy written out.** Four distinguishable triggers, the refusal, and
   **all four remediation blocks specified verbatim**, bound to `palette.inkSecondary` by `N-8`, with four
   copy obligations. The decision asked that consistency be stated: § R.5.5 tabulates the four existing
   credential refusals and concludes the new one must be a new type in `apps/server` carrying the
   remediation as *data*, mirroring how `HostKeyNotConfirmedException`'s two statuses drive two messages.
   § R.5.2 makes the mandatory step-5 compensation explicit, because without it a failure between `put` and
   the row write leaves an orphan private half no revocation can reach.

5. **Revocation is two-sided.** `destroy(handle)` first, then mark the row revoked — and that order is
   normative, with a failure-at-each-step table. A manager delete failure **refuses** the row update,
   because marking it revoked without destroying the material would assert a property that does not hold.
   The row is retained; `revokeCredential` (`engine:1072-1090`) never deletes and `credential_test.dart:310`
   asserts the *record*, not the bytes, so C-1 does not contradict it.

6. **The key flow creates the `Product` row first.** New state machine with two starred new steps and a
   starred *"Register product = commits verification"* step. ADR 0018 `:100-102` is **upheld** — the cycle is
   resolved in the ADR's favour, so the clause must not be amended. § R.11 makes the accepted consequence
   **normative and tellable**: a derived `RegistrationCommitState` plus the five client-observable states
   that must be visually distinct, including the revoked one the existing five-member `AccessStatus` cannot
   express. § R.11g is a **binding six-item consumption contract** for the sibling mobile lane, of which
   **item 3 is a requirement on that lane's design**: the flow must be re-enterable *from the product*, or
   the accepted visible-half-registered-product consequence becomes exactly the dead end human point 2d
   rejected.

7. **Two confirmed security defects specified, plus one I derived.** `M-3` → **`D-4`**, the mint path never
   upserts, with the column list as the requirement and a **call-site table** proving it cannot break
   `confirmHostKey`, `recordCredentialCheck` or `revokeCredential`. `M-4` → **`D-5`**, the scope set is
   immutable too, with the sharpest consequence stated: the re-point also carries `hostKeyStatus` and
   `hostConfirmedAt` to a host nobody confirmed, which contradicts ADR 0018 `:96-99` directly. **And a
   finding this lane derived:** a **revoked credential can be resurrected** by an identical-material re-mint,
   because the read path excludes revoked rows so the engine's one-active guard cannot fire — and under
   `79e860e2` its manager handle has already been destroyed, so the resurrected row claims a key that
   exists nowhere and then blocks the legitimate fresh mint. `credential_test.dart:323` closes the *check*
   path only; the *mint* path is uncovered. Specified as `T-D`.

**The store invariant is now depended on, not proposed.** § R.8 states what landed at `07c8c8f`
(`D-1`'s predicated `ON CONFLICT … WHERE … RETURNING` on both branches; `D-2`'s partial unique index in
**both** the bootstrap and migration `20261006150645000`, per `4d2c6b81`), re-derives B6's kill honestly in
three mechanism classes — **two persistence mechanisms, both real, plus one application requirement**, so
B6's original defect is closed at the store *conditionally* while its state-loss family is not closed —
and itemises the six requirements that now rest on it, **including the two that rest on `D-4` and are not
built.**

**No commit. No push.** `HEAD_SHA == BASE_SHA == 77c19f1`.

## Validation results

| Command | Status | Evidence / note |
|---|---|---|
| `dart analyze` / `flutter analyze` | **NOT_RUN** | Implementation-lane gate. No claim is made about its output |
| Build | **NOT_RUN** | — |
| `dart test packages/product_registry/test` | **NOT_RUN** | I make **no** claim about the state of `D-4`/`D-5` beyond what § R.9's reasoning shows |
| `make test-integration` | **NOT_RUN** | The only sanctioned exemption from the Docker rule; I did not need it and did not use it. `T-B`/`T-D` need it |
| **Any Docker or Compose command** | **NOT_RUN — none issued** | `AGENTS.md` carries the read-only-over-shared-Docker rule and it binds this lane. No `docker`, no `docker compose`, not even `ps`, `config` or `logs`. Compose files were read **as text** |
| Contrast-ratio measurement (`N-8`, `N-9`) | **NOT_RUN** | Ratios **inherited** from `design-register-button/report.md:71-76` and independently re-measured by the Gate D3 review. Not re-measured here |
| `T-A` / `T-B` execution | **NOT_RUN** | Reported as green **by the implementer's report at `07c8c8f`**. I did not re-run them and make no claim of my own |
| `T-C` … `T-G` | **NOT_RUN** | Specified in this revision; `T-C`/`T-D`/`T-F`/`T-G` **fail today by the reasoning shown in § R.9**, stated as a prediction derived from the code path, never as a result |
| Penpot boards | **NOT_RUN / not authored** | `C-11`. No board is authored and none is edited by this lane |
| Read-only source inspection | **pass** | Every `file:line` opened and read, at the SHA it is labelled with (§ 0.4) |
| `git status --porcelain -uall` scope check | **pass** | Returns only `docs/engineering/dispatch/tasks/design-addproduct-keyservice/` |
| `git merge-base --is-ancestor` provenance check | **pass** | `07c8c8f`, `674b871`, `3a87e27` are all **NOT** ancestors of `77c19f1` — which is why citations span three revisions (`D-16`) |
| `git rev-parse --abbrev-ref HEAD` | **pass** | `design-correct-addproduct-keys` — the name Revision 2 recorded wrongly (reviewer `L-E`) is corrected here |
| Commit / push | **NOT_RUN** | `COMMITTED: NO`, as instructed |

## Evidence (revision-pinned)

```yaml
EVIDENCE_REVISION: 77c19f1     # this lane's HEAD. NOTE: citations also span 07c8c8f and 6220951,
                               # neither of which is an ancestor of it. § 0.4 / D-16 / § 10.1 item 1.
BUILD_COMMAND:      NOT_RUN
SERVE_OR_RUN_COMMAND: NOT_RUN
ENVIRONMENT / BASE_URL: n/a — no runtime or browser surface was produced or claimed
ARTIFACTS:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-3.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-3.yaml
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-3.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md   # D-15…D-19
  # read-only sources, no artefacts produced:
  - 07c8c8f  apps/server/lib/src/persistence/postgres_product_registry_store.dart
  - 07c8c8f  apps/server/migrations/20261006150645000/migration.sql
  - 07c8c8f  packages/product_registry/lib/src/engine/product_registry_engine.dart
  - 07c8c8f  packages/product_registry/test/credential_test.dart
  - 07c8c8f  packages/product_registry/lib/src/exceptions.dart
  - 07c19f1  docs/adr/0018-per-product-git-credentials.md
  - 6220951  .decisions/{9417f8bf,7b1bc8b7,79e860e2,898b07d0,4d2c6b81,27ea6536}-*.yaml
```

**No visual evidence is claimed.** This revision changes no board and asserts no board compliance; it
specifies what the boards must show (§ R.3.4, § R.10.2, § R.11g) for the sibling lane that owns them.

## Documentation updated

```text
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-3.md              (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-3.yaml   (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-3.md           (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/report-revision-3.md              (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-2.md              (banner)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-2.yaml   (banner)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision.md               (banner)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata.yaml    (banner)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md                    (D-15…D-19)
```

**No production documentation was edited** — `docs/adr/**` in particular. Revision 3 states the ADR 0018
amendment's dependency contract (§ R.17) for the human's lane and edits nothing.

## Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: not specified by the dispatch
MODEL_USED: opencode/space-bunny-free
REASONING_EFFORT: not exposed by the runtime
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

## Unresolved issues and blockers

**None blocking.** Everything below is reported, not decided by me. Full list with owners in
`design-revision-3.md` § 10.1.

1. **The ADR 0018 amendment is a blocking predecessor for implementation** — owner **the human, as ADR
   owner**. `:85-88` and `:113-114` superseded; `:87-88`'s *"never persisted to the durable record"*
   prohibition **kept** (it is what permanently excludes A2); `:100-102` **upheld and must not be
   touched**; `:29-30`'s reference-name **shape** superseded. § R.17 is the dependency contract.
2. **`D-4` / `D-5` are specified and not built** (`G-11`) — owner **implementer**. `79e860e2`'s own
   follow-up test *"a revoked credential cannot reach the repository"* **fails until `D-4` lands**, because
   the resurrection path leaves a `generated` row in the active set. Should merge **ahead** of this feature.
3. **A3's reachability is `UNVERIFIED`** (`G-10`) — owner **implementer**, per the decision's own follow-up
   action. The decision records `confidence: LOW` and states no option was runtime-verified.
4. **`D-3` is an ADR gap and needs its own review** — owner **implementation (architecture)**.
   `git_workspace_inspector.dart:106-112` runs `Process.run` with no `environment:`; the five-token grep
   returns 0 matches. ADR 0018 `:96-99` makes refusal a **requirement**. Under A3 that seam must also
   resolve material from the manager, so it is now **two** security-critical capabilities in one place.
5. **§ R.5.2's ordering interpretation needs human confirmation** (`D-19`) — a substrate refusal writes
   **nothing at all**, including no `Product` row. `7b1bc8b7` and `898b07d0` interact and neither object
   addresses it. I chose the reading that does not produce `898b07d0`'s accepted bad state without its
   benefit; the alternative is available and is not forbidden. Flagged rather than absorbed because it is
   a `CONTRADICTION` between two Manager-owned objects.
6. **The sibling lane must be notified** of § R.11g's six items — and **item 3 is a requirement on its
   design**, not an observation: the Add Product flow must be re-enterable *from the product*, or the
   accepted visible-half-registered-product consequence becomes the dead end human point 2d rejected.
7. **Re-base this revision** — `HEAD_SHA 77c19f1` does not contain `674b871` or `07c8c8f`, so a reviewer
   cannot verify it from this worktree (`D-16`).
8. **Manager-owned ledger corrections, reported not edited** — `LANES.md:204-205` still asserts ADR 0018 /
   `AGENTS.md §13a` do not exist; `DECISIONS.md`'s index omits `570bb640`; `AGENTS.md` has no `§13`/`§13b`.
9. **Human-owned deployment precondition, carried forward not smoothed** — the duplicate-credential audit
   must be run **by a human** against every deployed database before migration `20261006150645000` is
   applied. The query as originally dispatched **does not execute** (`"repositoryId"` is quoted camelCase;
   unquoted it folds to `repositoryid` and *errors*, which reads exactly like *"no duplicates"*), and zero
   duplicates were found only in a database holding **0 rows** — a vacuous *"no"*.

## A note on approval

This lane produced Revisions 1, 2 and 3 and has **approved none of them**. Revision 2's
`DESIGN_REVIEW_APPROVED` came from a fresh independent reviewer and does not carry over here: it certified
Revision 2's content, and this is different content. `READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES` reflects
that the artifact is complete and genuinely reviewable — not that it is approved.

**What a reviewer should check hardest** (design-revision-3.md § 10.2): § R.1.3, the one design choice
inside the decision; § R.9.2, the resurrection path I derived; § R.9.1's call-site table, which is the entire
safety argument for `D-4`; § R.5.2's step-5 compensation; § R.6.1's ordering; and § 0.4's provenance split.
