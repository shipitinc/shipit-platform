# Report — Design Revision 4, `design-addproduct-keyservice` (correction of Revision 3)

Persisted per `aef-orchestrator` §14. Lane: `design-agent`. **The Design Agent never approves its own
work.** Nothing in this report is an approval, and no approval of any kind stands behind Revision 3 or
Revision 4.

## Provenance

| | |
|---|---|
| Worktree | `/private/tmp/shipit-correct-addproduct-keys` |
| Branch | `design-correct-addproduct-keys` |
| **`BASE_SHA`** | **`361256c8948b00da7f0609a4f29cf075eef26ca2`** |
| **`HEAD_SHA`** | **`361256c8948b00da7f0609a4f29cf075eef26ca2`** |
| Re-based from | `77c19f114ee691e8c434afe37b7c84494b66dc40` — by **`git merge --ff-only main`**, i.e. a **fast-forward, not a rebase commit**. `77c19f1` was an ancestor of `361256c`, so nothing was rewritten. The word "rebased" would otherwise imply a rewrite that did not happen |
| `REVISION_ID` | **`F2D5AF31-CA53-481A-ACB4-C75DB033A15A`** |
| `REVISION_NUMBER` | **4** |
| `RISK_LEVEL` | **3** — re-derived, not inherited |
| Committed / pushed | **NO / NO** |
| Docker or Compose | **none issued, not even a read-only one.** Compose files read **as text** |

**Every SHA this revision cites is a verified ancestor of its own base.** Output, run and quoted:

```
e391c02 ANCESTOR   07c8c8f ANCESTOR   4e2d237 ANCESTOR   0bf2fa0 ANCESTOR
1aa8755 ANCESTOR   674b871 ANCESTOR   6220951 ANCESTOR   3a87e27 ANCESTOR
```

This is the whole of what blocker **B1** required, and it is the operative part of **`D-20`**
(`discoveries.md`): **provenance labelling is necessary and not sufficient — the base itself must move.**

## Ownership

| | |
|---|---|
| **`OWNED_PATHS`** | `docs/engineering/dispatch/tasks/design-addproduct-keyservice/**` — **the only paths written** |
| `READ_ONLY_PATHS` | `docs/adr/**`; `docs/engineering/dispatch/{LANES,DECISIONS,WORK_STATE}.md`; `AGENTS.md`; `.decisions/**`; all `apps/**` and `packages/**` source; `/private/tmp/shipit-credential-identity`; `/private/tmp/shipit-design-adr0018` |
| `PROHIBITED_PATHS` | all production source, tests, generated files, migrations and **golden baselines**; `docs/adr/**`; `.decisions/**`; `WORK_STATE.md`; `LANES.md`; `DECISIONS.md`; the mobile lane's directory |

**No deletion, move or rename was performed anywhere in the repository.** A prior lane's report asserted
deletions that had not happened, so the **absence** is stated as a fact and not left to inference.

## What was reviewed, and what it returned

`docs/engineering/dispatch/tasks/review-addproduct-keys-rev3/report.md` (tracked on `main` at `1aa8755`),
read in full:

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
REVIEWED_HEAD: 77c19f114ee691e8c434afe37b7c84494b66dc40
CORRECTION_REQUIRED: YES
HUMAN_DECISION_REQUIRED: NO
INDEPENDENT_RISK_LEVEL: 3
RISK_LEVEL_AGREEMENT: YES
```

**4 BLOCKERS · 7 HIGH · 2 MEDIUM · 4 LOW.** Revision 3 was never approved; no prior approval was treated as
covering this correction.

## The `RESULT:` block

```
RESULT: DESIGN_REVISION_COMPLETE

FEATURE: Add Product rebuild — server-side deploy-key service (credential substrate A3,
         split identity from registration, two-sided revocation)

BRIEF_ID: 97484D0E-E16C-485E-BAA2-A277889C0FB6
REVISION_ID: F2D5AF31-CA53-481A-ACB4-C75DB033A15A
REVISION_NUMBER: 4

BRANCH: design-correct-addproduct-keys
BASE_SHA: 361256c8948b00da7f0609a4f29cf075eef26ca2
HEAD_SHA: 361256c8948b00da7f0609a4f29cf075eef26ca2

OWNED_PATHS:
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/**

READ_ONLY_PATHS:
  docs/adr/**                                       (ADR 0018 and the framework ADRs)
  docs/engineering/dispatch/LANES.md
  docs/engineering/dispatch/DECISIONS.md
  docs/engineering/dispatch/WORK_STATE.md
  docs/engineering/LEARNING_POLICY.md
  docs/engineering/DESIGN_GOVERNANCE.md
  AGENTS.md
  .decisions/**
  apps/**  packages/**                              (source, tests, generated, migrations, goldens)
  /private/tmp/shipit-credential-identity           (the D-4/D-5/D-18 implementation — read-only)
  /private/tmp/shipit-design-adr0018                (the ADR 0018 amendment design — read-only)

PROHIBITED_PATHS:
  all production source under apps/** and packages/**
  all test code and golden baselines
  all generated files, migrations and schema assets
  docs/adr/**
  .decisions/**
  docs/engineering/dispatch/{WORK_STATE,LANES,DECISIONS}.md
  AGENTS.md
  docs/engineering/dispatch/tasks/design-addproduct-mobile/**

ARTIFACT_PATHS:
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-4.md          (NEW, 2623 lines)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-4.yaml (NEW)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-4.md       (NEW)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md                 (MODIFIED — D-20..D-24 appended)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/report-revision-4.md            (NEW, this file)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-3.md            (MODIFIED — supersession banner only; body UNEDITED)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-3.yaml (MODIFIED — banner only)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-2.md            (MODIFIED — banner only; body UNEDITED)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-2.yaml (MODIFIED — banner only)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision.md              (MODIFIED — banner only; body UNEDITED)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata.yaml   (MODIFIED — banner only)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-3.md        (MODIFIED — banner only)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-2.md        (MODIFIED — banner only)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix.md          (MODIFIED — banner only)

RISK_LEVEL: 3
RISK_RATIONALE: |
  RISK_LEVEL: 3 (Major Workflow / Navigation / IA Change), re-derived on this evidence.
  1 reason IMPROVED (R6), 1 reason UNCHANGED (R1), 4 reasons WORSE (R2, R3, R4, R5).

  R1 UNCHANGED — first handling of key material; a leaked write-capable key cannot be
     recalled from SHIP IT's side.
  R2 WORSE — the credential is exposed through an unauthenticated, unpinned control plane
     (server.dart:71-73), and A3 adds a runtime dependency whose unavailability DENIES the
     credential path. Sharpened here: an attacker with the database can set status='revoked',
     so D-2 would block the legitimate re-mint — D-4 is an availability control too.
  R3 WORSE — under 898b07d0 this is IDENTITY SEMANTICS, not a gate: a product becomes visible
     before registration commits. ae1c1f79 adds a second interaction, so the flow now has TWO
     distinct failure shapes with different user-visible consequences.
  R4 WORSE — D-4/D-5/D-6 are still unmerged, and this pass found THREE MORE defects in the
     specified flow: G-13 (destructive get-or-create), G-14 (a revoked credential is invisible),
     G-15 (D-4's named exception type does not exist). The count rose.
  R5 WORSE — the transport seam must deliver host-key TOFU verification AND manager-backed
     material resolution; one is an ADR requirement with no precedent in the repository. This
     revision's contribution is PRECISION, not reduction: the domain half IS enforced, so the
     remaining half is cleanly nameable — and a cleanly nameable half is still unbuilt.
  R6 IMPROVED, with a stated residual — the ADR 0018 amendment is now WRITTEN AND ACCEPTED, so
     the contradiction with a live ADR is resolved in a recorded artifact. RESIDUAL: it is
     uncommitted and not in docs/adr/**, so code shipping before the merge briefly contradicts
     a live ADR. That is an ownership and sequencing matter (§ 10.1 action 1), not a design
     uncertainty.

  This exact sentence appears in three places and nowhere else:
  design-revision-4.md § 9.1 · design-revision-metadata-4.yaml risk_rationale · this report.
  Revision 3 tallied the same reasons FOUR different ways across three artifacts; those
  tallies are withdrawn as arithmetic, by name. Its LEVEL was independently right; the
  counting was not, and incoherent counting in a risk rationale is not a typo.

CHANGELOG:
  Per finding. B1 stale base — worktree re-based onto 361256c (fast-forward); all nine cited
  SHAs verified ancestors; G-1' CLOSED by 0bf2fa0 and the LANES.md row CLOSED at 4e2d237, so
  two of Revision 3's Manager actions are WITHDRAWN rather than re-requested; every gap entry
  and citation re-verified. B2 destroy-in-a-finally — § R.5.7 states the compensation construct
  ONCE with five obligations, referenced verbatim by § R.5.2, § R.10.1 and § R.14.1; T-I added
  as T-H's success-path counterpart. B3 state 4 unreachable — § R.11.2 specifies the server-side
  change as required deliverable G-14 (the EXISTING readCredentialsForProduct, one selection
  rule, no new field, no migration); Revision 3's stated cause corrected; added to § R.16 row 47,
  § R.8.4, § R.18.2, § 8 SC-19 and requirements_gaps. B4 in-memory tier absent — § R.9.1 and
  § R.9.3 now each carry a Tier A and a Tier B construct; § R.9.6 assigns every test a tier;
  § R.9.7 puts the tier requirement into the store contract. H1 host derived from a row the
  next step creates — § R.5.2 step 1 parses the endpoint's parameter; no row is read. H2 read
  precedes the reference / no repositoryId / wrong exception — signature gains repositoryId, the
  read moves to step 4 and switches to the store method, the error table is rewritten into seven
  rows. H3 CAS branch has no construct or test — the requirement is SPLIT: D-4 governs the mint
  branch, D-6 governs the CAS branch in the only satisfiable form (MAY SET, MUST NOT transition
  non-null -> null), with constructs for both tiers and tests T-J and T-K. H4 ae1c1f79 absent —
  cited; § R.5.2 re-framed as implemented as decided; all three follow-up actions traced;
  § R.11g gains item 5. H5 blast radius — § R.3.2 rewritten as twelve rows across eleven files
  with the three compile-breaking sites marked and the client's protocol.dart marked NO-OP; my
  count and its derivation are stated because they differ from the finding's. H6 four risk
  tallies — ONE tally in three places, verbatim. H7 SecretProvider composition — § R.1.7 states
  three named layers with the sample attributed to apps/server; SC-18 asserts the boundary
  mechanically. M1 duplicate-credential audit — gap G-12, in BOTH registers plus § R.8.4 row 7.
  M2 store contract doc — § R.9.7 names four required edits. L1 D-18 misnamed — § R.9.2 gains a
  mechanism table (the one-active guard stands down; D-2 is the backstop); § R.8.5 makes
  correcting the falsified store comment a REQUIRED DELIVERABLE of D-4. L2 no citation index —
  § 0.3 carries a 22-row index with a one-command completeness check whose output is quoted;
  § 10.2's uncheckable item is gone. L3 "public domain API" — § R.9's preamble states that no
  Serverpod endpoint calls recordGeneratedCredential. L4 rotation test — :520 -> :521.
  ALSO NEW: G-13 (the get-or-create step is destructive on both rows — found while correcting
  H2; Revision 3 called it idempotent without checking the writes), G-15, § R.10.3's corrected
  host-key split (the DOMAIN enforces HostKeyStatus; the TRANSPORT does not — Revision 3's
  "no runtime enforcer" is withdrawn as over-broad), and § R.9.3's corrected host-trust prose
  (the mint path destroys a confirmation, the CAS path carries it; both contradict ADR 0018
  :96-99, differently). CARRIED VERBATIM and listed in § 0.5: § R.1.1-R.1.6, § R.2, § R.3.1/.3/.4,
  § R.4, § R.5.1/.3/.4/.5/.6, § R.6.2/.3, § R.7, § R.8.1-R.8.3, § R.9.1's call-site table,
  § R.9.5's field sets, § R.10.0, § R.10.2's N-1..N-9, § R.11's axes, § R.12's table except row 1,
  § R.13, § R.14.2, § R.15 in full, § R.16 rows 1-45, § R.17, SC-01..SC-16, § 9.2's three ratings.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    OPEN-D4-1 (9417f8bf OPTION_C, 7b1bc8b7, 79e860e2)                    § R.1, R.5, R.6
    OPEN-D4-2 (898b07d0 OPTION_A)                                        § R.10
    the substrate-failure / Product-row interaction (ae1c1f79 OPTION_A) § R.5.2, T-H, § R.11g item 5
    G-7  — referenceName off the client wire                             § R.3.2 (12 rows / 11 files)
    G-9  — one-per-repository as a DB constraint                         § R.8.1
    G-1' — AGENTS.md §13/§13a/§13b restored                             § R.18.1 (CLOSED, B1)
    the LANES.md false claim                                            § R.18.1 (CLOSED, B1)
    ADR 0018 amendment as a predecessor                                  § R.17.1 (WRITTEN AND ACCEPTED)
    SC-02 / SC-03 / SC-15 / SC-16 — extended to require both tiers      § R.9.6
    AC-01 .. AC-14                                                       traceability-matrix-4.md § 3
  REQUIREMENTS_GAPS:
    G-4  ADR gap — host-key verification absent AT THE TRANSPORT; the domain enforces it, so
         ADR 0018 :96-99 is HALF-implemented. Owner: implementation (architecture).
    G-3  no test imports add_product_page.dart.          Owner: implementation / QA Contract.
    G-5  no read-only public-key endpoint.               Owner: implementation.
    G-6  recordGeneratedCredential's host is optional.   Owner: implementation.
    G-8  host-fingerprint provenance unspecified.         Owner: implementation.
    G-10 A3's reachability is UNVERIFIED — no probe was run and this lane issued no Docker
         command.                                         Owner: implementer, before completion.
    G-11 D-4/D-5/D-6 specified per tier, NOT merged.      Owner: implementer.
    G-12 the duplicate-credential audit — a human-run deployment precondition whose query as
         dispatched DOES NOT EXECUTE, and whose only reachable database held 0 rows (a vacuous
         "no").                                            Owner: HUMAN, before the migration.
    G-13 the § R.14.1 get-or-create step is DESTRUCTIVE: saveProduct (:91-101) and
         saveRepositoryReference (:127-145) are both ON CONFLICT DO UPDATE, so re-entry resets
         a product's state to registered and rewrites name/createdAt/uri/addedAt.
                                                          Owner: implementation.
    G-14 state 4 is NOT derivable from the read path this design keeps; loadProductDetail reads
         only the active credential, so a withdrawn key is reported as "no key generated yet".
         MUST land before the revoke UI ships.            Owner: implementation (one method).
    G-15 CredentialIdentityConflictException, named by D-4, does not exist. Behaviour is
         complete and no API behaviour changes.           Owner: implementation + ownership grant.
    L-6  DECISIONS.md's index omits 570bb640 and :16's "All five are PENDING" is false.
                                                          Owner: Manager — reported, not edited.
    ADR 0018 :103's wording ("Rotation is per product") contradicts its own :104 and A1.
                                                          Owner: ADR lane / human.

DESIGN_SYSTEM_COMPLIANCE: PARTIAL
UX_ACCESSIBILITY_SCORE: PARTIAL
IMPLEMENTATION_FEASIBILITY: MEDIUM

DISCOVERIES:
  D-20  WORKFLOW_IMPROVEMENT, reusable. A design citing SHAs that are none of them ancestors of
        its own base cannot be verified by anyone reviewing it — PROVENANCE LABELLING IS
        NECESSARY AND NOT SUFFICIENT; THE BASE ITSELF MUST MOVE. Labelling answers "where was
        this read?" when the reader already holds the right tree; it cannot answer "is this
        tree the one the design is about?", and a label actively conceals that second question
        by making the first checkable. Concrete cost here: two Manager actions would have been
        performed against already-correct state, and one artifact predated a decision that
        landed 19 minutes later so it structurally could not reflect it. Carries executable
        knowledge — the three-step ancestor loop, its output quoted in § 0.3. Authority:
        INDEPENDENT REVIEW — routed, NOT auto-persisted.
  D-21  WORKFLOW_IMPROVEMENT, reusable. A SPEC EXPRESSED ONLY AS A SQL STATEMENT, WHOSE NAMED
        TESTS LIVE IN AN IN-MEMORY SUITE, WILL SILENTLY PRODUCE TWO TIERS WITH DIFFERENT
        PREDICATES — specify behaviour PER TIER or the tests cannot witness what the
        specification claims. The evidence is unusually clean: the in-memory store's own comment
        states the invariant the specification was about to break, and the specification then
        broke it. Two corollaries, both learned the hard way — the constructs cannot be mirrors
        (Tier A's DO NOTHING evaluates NO column predicate, so any Tier B guard on that path
        MASKS the identity guard behind it), and "this cannot be demonstrated by an in-memory
        map" is true of a unique index and FALSE of a write predicate. Authority: INDEPENDENT
        REVIEW — routed, NOT auto-persisted.
  D-22  WORKFLOW_IMPROVEMENT, reusable. A finally that compensates for a partial effect destroys
        the effect on the success path unless the construct distinguishes the two exits. Dart has
        no failure-only finally; Revision 3 stated the same construct twice, in two normative
        locations, and both read literally as the same defect. Three sub-rules: the compensation
        needs a SUCCESS SIGNAL, its own failure must not MASK the original (an exception thrown
        from a finally REPLACES the in-flight one — the same class as the teardown rule in
        AGENTS.md), and the SUCCESS PATH NEEDS ITS OWN ASSERTION, because that is the assertion
        nobody writes and without it a construct that destroys on success is indistinguishable
        from a correct one. Authority: INDEPENDENT REVIEW — routed, NOT auto-persisted.
  D-23  DESIGN_DISCOVERY, product-specific. A capability enforced at one layer and not at another
        is not one capability with a gap; it is two, and a single adjective cannot describe both.
        Revision 3 said HostKeyStatus.permitsConnection "has no runtime enforcer" and called
        ADR 0018 :96-99 "decorative". Both over-broad: the domain enforces it in four places and
        the transport in none. The error was CONSERVATIVE and still caused harm, because G-4 was
        scoped as "nothing enforces this" when the accurate scoping is "one half does" — and the
        half that does not is the half nobody goes looking for. Fix is a table, not a sentence.
        Also recorded: adopting a sibling lane's finding requires re-verifying ITS citations
        against YOUR base — that lane's engine:1033/:1148 are this base's :1047/:1162, offset
        +14 by the store-integrity work. Authority: automatic.
  D-24  DESIGN_DISCOVERY, product-specific. get-then-create is NOT get-or-create when both writes
        are ON CONFLICT DO UPDATE. "Idempotent by read-then-write" is a property of a CALLER
        DISCIPLINE wearing the noun for a property of the WRITE — and in a flow whose purpose is
        to be RE-ENTERABLE, every step is reachable twice by design. Second instance of the same
        shape, recorded together: readActiveCredentialForRepository excludes revoked rows, and
        Revision 3 read that exclusion as evidence that hiding a revocation is designed. It
        answers "what credential is in force", and it was used as if it answered "has anything
        ever happened here". A predicate written for one question will answer a different one
        correctly, and nothing will complain. Authority: automatic.

KNOWLEDGE_PERSISTED:
  Persisted IN-REPO, at automatic authority: D-23 and D-24 (DESIGN_DISCOVERY — verified facts
  about this repository's code, one of them a new gap, G-13). Also persisted in-repo as content:
  G-12, G-13, G-14, G-15 in BOTH gap registers, and the twelve-row G-7 change list, so they are
  records rather than assertions.
  ROUTED, NOT PERSISTED — D-20, D-21 and D-22 are WORKFLOW_IMPROVEMENT, which per
  LEARNING_POLICY.md §2 requires INDEPENDENT REVIEW and may not be auto-persisted by a
  production-writing lane. They are product-agnostic and belong in the framework. The Manager is
  asked to route them; this lane did not write them into any framework knowledge store, because
  it does not hold that authority and does not have one in scope.
  NOT PERSISTED: the a11y contrast figures (inherited, not re-measured); all test/analyzer/build
  outcomes (NOT_RUN); whether A3 is reachable in this topology (UNVERIFIED, G-10); whether a real
  SSH transport accepts the generated key (UNVERIFIED); the duplicate-credential audit (NOT_RUN
  and not runnable from any lane — now G-12 in both registers); the ADR 0018 amendment (human-
  owned, written and Accepted by another lane, recorded not edited); WORK_STATE.md, LANES.md,
  DECISIONS.md, AGENTS.md and .decisions/** (Manager-owned — required changes listed in § 10.1,
  none performed); and all production source, tests, migrations and golden baselines
  (PROHIBITED_PATHS).

BLOCKERS:
  None. This revision is not blocked and makes no false-green claim: every gate is reported
  NOT_RUN, the two DELETE claims this lane could have made are reported as NOT MADE, and the
  three items below are recorded as OPEN WORK with owners rather than as anything discharged.

  Open, and NOT discharged by this revision — recorded so a Manager reading "COMPLETE" does not
  read it as "ready to implement":
  1. IMPLEMENTATION IS NOT UNBLOCKED. D-4, D-5 and D-6 are specified per tier and NOT built
     (G-11); G-7 is specified and not built; G-13 and G-14 are specified and not built; the
     SecretProvider, the mint endpoint, the check path's manager resolve and the revoke endpoint
     do not exist. A3's reachability is UNVERIFIED (G-10). The SSH transport seam is LOW
     feasibility and carries an ADR REQUIREMENT with no implementation.
  2. THE ADR 0018 AMENDMENT IS WRITTEN AND ACCEPTED BUT UNMERGED. § R.17.1 records its state.
     docs/adr/** is PROHIBITED_PATHS here, so the merge is the human's (§ 10.1 action 1), and it
     is the one residual behind the IMPROVED reason R6.
  3. TWO CONSUMER LANES ARE UNCONSUMED. design-addproduct-mobile's current artifact is based on
     77c19f1 — the same stale base this revision just fixed — states 9417f8bf as PENDING though it
     has been RESOLVED since 13:05, and carries no RegistrationCommitState model and no reference
     to § R.11g, so § R.11g items 3 and 5 are not yet consumed. Not my file; § 10.1 item 6.
  4. HUMAN APPROVAL OF THIS REVISION'S CONTENT IS STILL REQUIRED, at risk level 3. Revision 4
     asks for approval of D-4, D-5, D-6, G-13, G-14, SC-11..SC-19, the N-9 copy, and § R.5.7's
     compensation construct. Nothing here is self-approved.

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```

## Gates — nothing was run

| Command / check | Status |
|---|---|
| **Any Docker or Compose command** | **NOT_RUN — none issued, not even `ps`, `config` or `logs`.** Compose files read **as text** (`docker/compose.yaml:16-17`, `:63`; `.env.example:16-18`). `AGENTS.md`'s read-only-over-shared-Docker rule binds this lane; `make test-integration` is the only exemption and was not used |
| `dart analyze` / `flutter analyze` / build | **NOT_RUN** |
| `dart test packages/product_registry/test` | **NOT_RUN** |
| `make test-integration` | **NOT_RUN** |
| `T-A` … `T-K` | **NOT_RUN.** `T-A`/`T-B` are reported green **by the implementer's report** — not re-run by me, and no claim of mine. `T-C`…`T-K` **specified, not executed**; their predicted pre-fix failures are predictions from the code path |
| Contrast measurement | **NOT_RUN** — figures **inherited**, not re-measured |
| The `fix/credential-identity-invariants` gates | **NOT_RUN by me** — that lane's results are **not adopted as mine** |
| Penpot | **NOT_RUN / not authored** (`C-11`) |
| ADR amendment merge | **NOT_RUN** — `docs/adr/**` is `PROHIBITED_PATHS` |
| **Deletions** | **NONE MADE.** Only files under `docs/engineering/dispatch/tasks/design-addproduct-keyservice/**` were created or edited. **No file was deleted, moved or renamed anywhere in the repository, and no such action is claimed** |
| Read-only source inspection | **pass** — every `file:line` opened and read at `361256c`; § 0.3's ancestor check run, output quoted |
| Commit / push | **NOT_RUN** |

## Confirmation of the review's *"Verified CORRECT"* items

I did not re-open any of these, and § 0.5 lists the sections carried verbatim as a result. The
substrate option set is gone and the human's reserved decision is not nudged; § R.1.3 is a proper
judgement; `D-18` re-derived and confirmed; § R.9.1's call-site table is exact (I re-verified it
at `361256c`); revocation two-sided; fail-closed end to end; the B6 split honest; ≈40 sampled
citations resolved. **The bound on that list is stated in § 0.2: it confirms specific claims, and
it is not an approval of Revision 3 or of Revision 4.**

## Two numbers I state differently from the review, and why

Both are in the artifact, but they are worth surfacing here because a reviewer comparing the two
documents will notice them.

1. **The G-7 change list.** The review said *"nine hand-written sites"*; § R.3.2 has **twelve rows
   across eleven files**, counting two doc-comment edits inside files already being edited. The
   review's arithmetic counted only sites inside files it had already listed. **The claim that
   matters is completeness, and § R.3.2 makes it checkable** by quoting the grep that derives it.
2. **The host-key citation line numbers.** The ADR amendment design cited `engine:1033` and
   `:1148`, which are correct **at its own base (`6220951`)**. At `361256c` they are `:1047` and
   `:1162` — the store-integrity work shifted engine lines by **+14**. I cite mine and record the
   offset (`D-23`), because a design citing another lane's line numbers without re-checking them
   reproduces exactly the class of defect this pass was correcting.

## Human approval still required

Per `DESIGN_GOVERNANCE.md` and risk level 3, the **content** of Revision 4 requires
product/design/architecture human approval. The human's own decisions are all taken — six at Gate
D4, plus `ae1c1f79`, plus the ADR 0018 amendment with four gaps recorded as accepted. What is
being asked for here is approval of **this revision's** requirements and copy, and of the
`G-13`/`G-14`/`G-15` findings it adds.

**This revision is not approved by its author.**
