RESULT: DESIGN_REVISION_COMPLETE
TASK_ID: design-correct-addproduct-keys
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — server-side deploy-key service + hostUnrecognised trust state (Design Revision 2, applying Gate D3 review)
WORKTREE: /private/tmp/shipit-correct-addproduct-keys
BRANCH: design/correct-addproduct-keys
BASE_SHA: 77c19f1
HEAD_SHA: 77c19f1
COMMITTED: NO

---

```
RESULT: DESIGN_REVISION_COMPLETE

FEATURE: Add Product rebuild — server-side deploy-key service + `hostUnrecognised` trust state (revision 2)
BRIEF_ID: 97484D0E-E16C-485E-BAA2-A277889C0FB6  (brief version 1.1.0)
REVISION_ID: F21D5C64-006D-4203-A813-841E08E38B95
REVISION_NUMBER: 2   (supersedes 46980EE0-E638-409C-A7D3-E1B9399FECE5, retained intact)
BRANCH: design/correct-addproduct-keys
BASE_SHA: 77c19f1
HEAD_SHA: 77c19f1

OWNED_PATHS:
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/**   (only this)

READ_ONLY_PATHS:
  docs/adr/**                                (ADR-0012/0015/0018/0019/0020/0021 read in full)
  docs/engineering/adr/**                   (framework-distribution ADRs)
  docs/engineering/DESIGN_GOVERNANCE.md, LEARNING_POLICY.md, WORKFLOW.md, DECISIONS.md
  AGENTS.md
  apps/**, packages/**                       (read-only source inspection; all file:line re-verified)
  .decisions/**                              (read-only; decision objects are Manager-owned)
  docs/engineering/dispatch/tasks/design-review-addproduct-keyservice/report.md  (the review applied)

PROHIBITED_PATHS:
  AGENTS.md, docs/engineering/WORK_STATE.md, docs/engineering/dispatch/LANES.md,
  docs/engineering/dispatch/DECISIONS.md, .decisions/**,
  docs/engineering/dispatch/tasks/design-addproduct-mobile/**,
  all production source (apps/**, packages/**), apps/server/migrations/**,
  docker/** (no Docker or Compose command was run, not even read-only)

ARTIFACT_PATHS:
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-2.md          (NEW — the revision)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-2.yaml (NEW — metadata + changelog)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-brief-1.1.0.md          (NEW — corrected brief)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-2.md      (NEW — traceability)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md                (EXTENDED — D-6 retraction banner, D-7 reframed, D-10..D-14 added)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/report-revision-2.md          (NEW — this report)
  RETAINED BYTE-IDENTICAL: design-revision.md, design-revision-metadata.yaml, design-brief.md,
  traceability-matrix.md, prompt.md, report.md

RISK_LEVEL: 3
RISK_RATIONALE:
  Level 3 (Major Workflow / Navigation / IA Change) per DESIGN_GOVERNANCE.md. Kept at the
  reviewer's INDEPENDENT_RISK_LEVEL 3 with RISK_LEVEL_AGREEMENT: YES, re-derived here rather than
  accepted. Five reasons, any one of which is Level 2 or above:
  (1) SHIP IT will hold a private key authorising WRITE access to a customer repository — the first
      secret of any kind stored server-side; compromise is repository compromise, irreversible
      without a host-side uninstall.
  (2) It sits in tension with a documented architectural assumption — ADR 0018:85-88 (READ, 158
      lines) puts the private half in the operator's local secret store and forbids persisting it to
      the durable record; DEC-b869ec24 moves it server-side. The revision does not resolve that; it
      is the human's (OPEN-D4-1). A design whose outcome may contradict an existing ADR is not a
      component-level change.
  (3) It changes the core registration workflow — human points 2a/2b make key generation and host
      trust preconditions of registration, and ADR 0018:100-102 independently requires the same, so
      it cannot be deferred as a UI preference.
  (4) It introduces a credential-minting endpoint on an UNAUTHENTICATED, NOT-loopback-pinned
      control plane (server.dart:71-72; DEC-570bb640's pinning follow-up confirmed unimplemented).
      First endpoint whose side effect is persisting secret material.
  (5) NEW IN REVISION 2 — the design's central security claim was false at the persistence layer.
      product_credential.publicKey is overwritable in place through recordGeneratedCredential's own
      API (engine:920/941/965 → ON CONFLICT DO UPDATE at store:238-243), and ADR 0018 A1's
      one-per-repository invariant is not a database constraint at all (definition.sql:646 is
      non-unique). Until D-1 and D-2 are built, finding B6 is documented, not closed. A workflow
      whose central invariant is unenforceable is not a workflow-level change of the safe kind.
  Level 3 requires product/design/architecture human approval at Gate D4. This revision does not
  pre-empt it: OPEN-D4-1 (re-framed as Q1') and OPEN-D4-2 remain OPEN and are defaulted nowhere.

CHANGELOG:
  Revision 2. Correction lane applying RESULT: DESIGN_REVIEW_CHANGES_REQUIRED (REVIEWED_HEAD 77c19f1,
  INDEPENDENT_RISK_LEVEL 3, RISK_LEVEL_AGREEMENT YES). Revision 1 is retained intact as the reviewed
  artifact and was NOT edited. No commit, no push. Full per-finding changelog is in
  design-revision-metadata-2.yaml and design-revision-2.md § 0.2.

  B1 — ADR 0018 EXISTS; R1's G-1 was FALSE. WITHDRAWN, retraction stated first in § 0.1.
       Verified: docs/adr/0018-per-product-git-credentials.md is 158 lines, "Proposed (amended — A1)";
       docs/adr/ holds 21 ADRs (0001–0021); docs/engineering/adr/ holds the 3 framework-distribution
       ADRs only. 13 production files cite ADR 0018 by number, several by amendment
       (postgres_product_registry_store.dart:172, product_registry_store.dart:35,
       repository_credential.spy.yaml:4, repository_credential_view.yaml:1, repository_credential.dart:10
       and :22, credential_status.dart:1 and :36, repository_provider.dart:8, product_state.dart:1,
       product_registry_engine.dart:898 and :1057, exceptions.dart:213, ui_view_mappers.dart:138,
       products_page.dart:308) — including files R1 cited as evidence of its own absence. False G-1
       removed from requirements_gaps and from traceability-matrix-2.md § 4; D-6 retracted in place
       in discoveries.md with the original text preserved.
  B1 — § R.21 REWRITTEN. The surviving REAL gap: AGENTS.md has NO §13 and NO §13b (verified: 129
       lines; sections Inherited invariants / Orchestration / Product-specific policy / Test resource
       hygiene / Framework provenance; Product-specific policy is TBD at :59-63). So ADR 0018's
       carve-out (:140-141), ADR 0012:34 and ADR 0019:121 all point at text that does not exist —
       a documented mitigation of an ACCEPTED ADR was never applied. Recorded as G-1' and escalated
       (AGENTS.md is outside OWNED_PATHS; NOT edited).
  B1 — architecture_refs REPOPULATED with ADR 0012/0015/0018/0019/0020/0021, each read in full and
       each mapped to the sections it governs (design-brief-1.1.0.md § architecture_refs;
       traceability-matrix-2.md § 1 now carries an architecture clause per row). ADR-0001/0002/0003
       retained but annotated as governing nothing here.
  B1 — § R.4 A1/A2/A4 and § R.6 C-1..C-3 rewritten against what the ADR already decides. A2 marked
       FORBIDDEN by ADR 0018:87-88 with the sentence attached AT the option. Q1 collapsed to Q1' —
       "does b869ec24's server-side custody supersede ADR 0018:85-88?" — the genuinely open delta.
       Seven of R1's ten "substitute assumptions" demoted from assumptions to recorded ADR decisions
       (§ R.21.2). OPEN-D4-2 re-escalated from a design circularity to an ADR CONTRADICTION
       (ADR 0018:100-102).
  B2 — R1's "B6 is structurally impossible — four independent mechanisms" is FALSE at the persistence
       layer. Verified: store:238-243 upserts with "publicKey"/"fingerprint"/"algorithm"/
       "referenceName" in the DO UPDATE SET (assignments at store:195-210) when expectedVersion is
       null; recordGeneratedCredential calls it at engine:965 with NO expectedVersion, takes a
       caller-supplied credentialId (engine:920), and its one-active guard (engine:940-941) is
       "if (active != null && active.credentialId != supersedesCredentialId)" — so a same-id
       re-mint passes it. copyWith is NOT on that path (fresh object built at engine:950-964).
       rotateCredential (engine:1084-1119) is a second route via its optional credentialId
       (engine:1091, :1117). § R.15 REWRITTEN as TWO mechanisms, explicitly NOT independent, with a
       per-mechanism statement of what each actually buys. R1's "These are independent … mechanism 4
       still prevents silent substitution" is WITHDRAWN. § R.2 constraint 3 corrected to say
       immutability holds in memory only.
  B2 — § R.16 step 4 REWRITTEN. R1 resolved concurrency on "the engine's one-active exception", which
       WILL NOT FIRE: product_credential has a unique index on credentialId only (definition.sql:645)
       and repositoryId has a NON-UNIQUE index (:646), so two concurrent mints both insert. Now
       resolved on D-2's unique violation. Added: the mint must pass no caller-supplied credentialId,
       and an immutability violation is a defect that must not be converted into alreadyExisted.
  B2 — NEW § R.15b: THREE REQUIRED DESIGN DELIVERABLES. D-1 store-level key-material immutability
       guard (preferred predicating "ON CONFLICT ("credentialId") DO UPDATE SET … WHERE publicKey = …
       AND fingerprint = … AND algorithm = … AND referenceName = … RETURNING credentialId"; alternative
       typed-refusal form with a warning that a bare check-then-write is itself racy). D-2 the required
       partial unique index ON product_credential (repositoryId) WHERE status <> 'revoked' —
       PROPOSED ONLY (C-09), whose predicate is IDENTICAL to readActiveCredentialForRepository's own
       predicate (store:262) so constraint and query cannot contradict, and whose order is satisfied by
       rotateCredential's revoke-then-mint (engine:1104, :1108-1119). D-3 two engine-level tests that
       FAIL TODAY: T-A (same-credentialId re-mint must throw; stored key byte-identical) and T-B (two
       concurrent mints yield exactly one active row; requires the Postgres-backed store). D-1/D-2 are
       substrate-independent and therefore NOT gated on OPEN-D4-1.
  B2 — NEW finding while reading (D-12): a version CAS alone does NOT close D-1, because
       recordGeneratedCredential hardcodes version: 1 (engine:963), so a previously-minted row is
       also at version 1 and "expectedVersion: 1" would match store:214 and still overwrite publicKey.
       The engine uses CAS correctly on the other four credential writers (engine:997, :1011, :1052,
       :1074) — which is exactly why the pattern is tempting and insufficient on the one path that
       must not version-check a fresh insert.
  B2 — SC-02 and SC-03 EXTENDED with T-A and T-B; SC-08 re-framed to require the Gate D4 decision be
       taken against ADR 0018 in evidence.

  H1 — § R.3 REWRITTEN invariant-only. Deleted "Decision (normative … it selects a substrate)";
       deleted "SHIP IT's own at-rest store", which silently EXCLUDED A3 — the option § R.8 and
       9417f8bf recommend, lost to a sentence the human may never read; deleted "No wire-contract
       break from the field's existence" (asserted at :76, retracted at :90). § R.3 now states exactly
       one normative invariant (referenceName names a reference and never a value — settled by ADR
       0018:92-95, not by this design) and marks three things OPEN: its subject, the substrate, and
       client exposure. Reuse row #35's migration cell marked explicitly CONDITIONAL on the substrate.
       Also fixed L4 inside § R.3: referenceName has NO index (repository_credential.spy.yaml:7-14
       declares only credentialId-unique, repositoryId, productId).
  H2 — Q3 NOT withdrawn but RE-FRAMED with the reason stated. ADR 0018:113-114 already answers
       "Revocation is provider-native … requires no Shipit-side action" — under the ADR's own custody
       model, where SHIP IT holds no bytes. b869ec24 moves custody server-side and is SILENT on
       revocation (verified: grep -i "revoc\|rotat" over .decisions/b869ec24-*.yaml → no match). So
       Q3' asks whether :113-114 SURVIVES the move, and C-2 is named as the ADR's answer under
       Q3'=YES rather than presented as an unexplored option. 79e860e2 must be restated in these terms.
  H3 — A2's threat model CORRECTED. R1's A2 "For" bullet claimed "backups of the database alone no
       longer disclose the key"; that is false comfort and is WITHDRAWN. Verified: docker/compose.yaml:62
       hardcodes SERVERPOD_DATABASE_PASSWORD: shipit in a committed file; docker/compose.yaml:16-17
       publishes "5432:5432" unqualified (0.0.0.0); .env.example:16-18 documents
       POSTGRES_USER/POSTGRES_PASSWORD=shipit; DEC-570bb640:34-37 and :73-75 record exactly this. An
       attacker needs no backup — they need port 5432 and a password published in the repository.
       Added to A2's "Against" and to a new § R.7.1 threat-model table.
  H4 — § R.18 gains a FOURTH point: the direct-database path. An off-host caller reaching 5432 with
       the committed default credentials never touches the endpoint, so endpoint auditing and
       endpoint constraints do not constrain the data; and under a Q1'-supersession selecting A2 that
       is exactly where the sealed key material sits. § R.18's existing honesty is preserved verbatim
       and extended, not softened.

  M1 — Brief's cross-lane instruction CORRECTED. R1 told design-addproduct-mobile the enforced order
       is "four steps — not the current three-step _StepText list (add_product_page.dart:650-672)".
       Verified: there are FOUR _StepText entries, at :650, :656, :662, :668. v1.1.0 tabulates all four
       (generate / install+prove / read revision+build baseline / approve baseline) and states the
       key-flow order replaces steps 1-2 with Generate → Trust → Check, adding Register as distinct,
       with steps 3-4 unaffected. Issued as a NEW file so v1.0.0 stays intact; notifying the sibling
       lane is a Manager action (it owns its own artifacts).
  M2 — § R.8 confidence SPLIT PER OPTION; all Q1 options now LOW. R1's single MEDIUM was indefensible
       on its own stated basis (A4 untested, A3 equally untested; nothing runtime-verified). Q2 keeps
       MEDIUM (independently accepted by the review); Q1'/Q3'/Q4 are LOW.
  M3 — N-8 ADDED, NORMATIVE. inkTertiary on the card surface measures 4.23:1 dark and FAILS WCAG AA,
       and it is the current idiom for exactly this copy (add_product_page.dart:542 and :590) — so all
       seven new strings (five failure kinds + two host states) would follow the failing idiom by
       default. N-8 makes palette.inkSecondary (6.74:1 light / 6.10:1 dark) REQUIRED for every new
       string, moved out of § R.8's recommendation table where an implementer reading requirements
       would not find it. SC-06 extended. Ratios labelled inherited + independently re-measured by
       the review; NOT re-measured by this lane.
  M4 — G-7 now has a NAMED owner: 9417f8bf. R1 recorded "may referenceName reach the client" as a gap
       with no owner while 9417f8bf's stated question is the substrate only. § R.4.1 names it,
       explains client exposure is a CONSEQUENCE of the substrate answer (path vs ARN vs opaque row
       reference), and asks the Manager to widen the reissued object's question.

  L1 — engine:52 → engine:54 (verified: createProduct spans 43-61; hardcoded state at :54).
  L2 — product_state.dart:29-32 → product_state.dart:24-27 (verified: enum at :23-28, registered at
       :28). Substance unchanged and re-verified: no pre-registration ProductState exists.
  L3 — range endpoints corrected after re-reading: createProduct 43-63 → 43-61; addRepositoryReference
       150-174 → 150-170; requireUsableCredential 1138-1160 → 1138-1162. All other cited ranges
       spot-checked and found exact.
  L4 — see H1.
  L5 — D-7 RESTATED in discoveries.md as a CONFIRMED-UNIMPLEMENTED FOLLOW-UP to 570bb640, not a
       first-time finding: 570bb640's own context already records the unenforced "local only" premise
       (:22-27, :67-72). § R.18 carries the same framing.
  L6 — REPORTED, NOT EDITED: docs/engineering/dispatch/DECISIONS.md's index table (:8-12) omits
       570bb640, which appears only in the closing prose. DECISIONS.md is Manager-owned.

  KEPT INTACT — the reviewer's explicitly praised parts, carried forward unchanged and marked as
  such: N-1's normative no-Cancel rule with rationale and cost; N-2–N-7; § R.9's state machine on the
  existing HostKeyStatus; § R.11's two orthogonal client axes and two-factor canRegister; § R.12's
  traceable way out AND its explicit dependence on OPEN-D4-2; § R.13/R.14's normative Check-access
  definition and five-way failure taxonomy; N-6's HostKeyStatus.changed path with no "trust anyway";
  § R.18's honesty about the endpoint; § R.5's fail-closed framing; § R.7's single-boundary
  constraint; § R.19.2's three options.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    R-2a, R-2b (now also ADR 0018:100-102), R-2c, R-2d, R-H1, R-H2, R-B4, R-B5,
    R-B6 (explicitly NOT CLOSED until D-1/D-2 — stated, not claimed),
    R-R1 (honoured; the one § R.3 leak is fixed), R-4, R-5, R-6,
    DEC-73097d48, DEC-b869ec24, DEC-048f3367, DEC-570bb640,
    ADR-0012, ADR-0015, ADR-0018, ADR-0019, ADR-0020, ADR-0021 (all read in full)
  REQUIREMENTS_GAPS:
    OPEN-D4-1 — re-framed as Q1' (does b869ec24's server-side custody supersede ADR 0018:85-88?),
      plus Q2 fail-open/closed, Q3' (does :113-114 survive the move), Q4 (may referenceName reach the
      client). OPEN, HUMAN DECISION REQUIRED AT GATE D4. Owners 9417f8bf (Q1'/Q2/Q4), 79e860e2 (Q3').
      NOT answered, NOT defaulted, re-framed only.
    OPEN-D4-2 — registration ordering. OPEN, HUMAN DECISION REQUIRED AT GATE D4, owner 898b07d0.
      RE-ESCALATED: now a contradiction with ADR 0018:100-102, not only a design-level circularity.
    G-1' — AGENTS.md has no §13 and no §13b (NEW; replaces the false G-1). ADR 0018:140-141,
      ADR 0012:34, ADR 0019:121 all depend on text that does not exist. Manager/human action.
    G-2 — no read-only-over-Docker rule in AGENTS.md; five claims UNVERIFIED with commands named.
    G-3 — zero tests import add_product_page.dart, so SC-02/SC-04/SC-06 have no harness.
    G-4 — no SSH host-key verification exists; MANDATED by ADR 0018:96-99, homed by ADR 0015:55-59.
    G-5 — no read-only public-key endpoint.
    G-6 — recordGeneratedCredential's host is optional and defaults to null.
    G-7 — RepositoryCredentialView exposes referenceName to clients. OWNER NAMED: 9417f8bf (M4).
    G-8 — fingerprint provenance (ssh-keyscan vs handshake) unspecified.
    G-9 — NEW. ADR 0018 A1's one-per-repository invariant is documented but NOT a database
      constraint (definition.sql:646 non-unique). Remedy is required deliverable D-2.
    L-6 — DECISIONS.md's index table omits 570bb640. Manager-owned; reported, not edited.
    Human points 2e/2f and the four mobile Penpot boards are OUT OF SCOPE by design and belong to
      design-addproduct-mobile; recorded as not-covered, not as gaps.

DESIGN_SYSTEM_COMPLIANCE: PARTIAL
UX_ACCESSIBILITY_SCORE: PARTIAL
IMPLEMENTATION_FEASIBILITY: MEDIUM

DISCOVERIES:
  (classified per docs/engineering/LEARNING_POLICY.md; full entries in discoveries.md)
  D-10  AUTOMATION_OPPORTUNITY — THE WRONG-IDENTIFIER PATTERN. Two false "artifact absent"
        conclusions in one session, both propagated into WORK_STATE.md, LANES.md and two Human
        Decision objects before review caught them. (i) deployKey/deploy_key → the domain's word is
        "credential"; prevented by
        grep -rn "RepositoryCredential\|recordGeneratedCredential\|product_credential" apps/server/lib packages --include="*.dart"
        (ii) docs/engineering/adr/ → the real directory is docs/adr/ (21 ADRs); prevented by
        ls docs/adr/  and  grep -rn "ADR 0018" apps packages --include="*.dart" --include="*.yaml"  → 13 hits.
        Rule, stated mechanically: before concluding X does not exist, (a) search the DOMAIN's
        vocabulary not the requester's phrasing, (b) if X is a CITED identifier (ADR number,
        decision id, §N) follow the citations themselves — an id appearing 13 times in production
        code is not absent, (c) enumerate candidate locations with glob, not ls on one guessed path.
        Instance (ii) fails closed into false confidence: it produced a fabricated traceability gap
        and ten "substitute assumptions" where seven were recorded ADR decisions.
        Executable form: a preflight that resolves every ADR/decision identifier in docs/** and apps/**
        comments against the filesystem and fails loudly on an unresolvable one.
  D-11  PROJECT_FACT — product_credential.publicKey is overwritable in place through
        recordGeneratedCredential's own API (engine:920/941/965 → store:238-243); rotateCredential is a
        second route. credential_test.dart:206 passes today for the wrong reason.
  D-12  ARCHITECTURE_DISCOVERY — a version CAS alone does NOT close D-11, because the mint path
        hardcodes version: 1 (engine:963). The guard must predicate the IMMUTABLE FIELDS.
  D-13  ARCHITECTURE_DISCOVERY — ADR 0018 A1's one-per-repository invariant is unenforced by any
        constraint; two concurrent mints yield two active credentials. Safe predicate already exists
        in the codebase (store:262).
  D-14  RUNTIME_DISCOVERY — the live database is reachable with committed default credentials, so
        "a backup alone no longer discloses the key" is false comfort; A2 puts the key in the
        least-protected component.

KNOWLEDGE_PERSISTED:
  All persisted INSIDE OWNED_PATHS only, as classified per LEARNING_POLICY.md:
  discoveries.md — D-6 retracted in place (original text preserved as the audit trail of the
  mistake), D-7 reframed as a confirmed-unimplemented follow-up to 570bb640, and D-10..D-14 added
  with evidence. Product-specific PROJECT_FACT / RUNTIME_DISCOVERY / DESIGN_DISCOVERY are
  automatic-persist; D-12 and D-13 are ARCHITECTURE_DISCOVERY (human-decision authority) and D-10 is
  AUTOMATION_OPPORTUNITY (independent-review authority) — reported, not escalated into any ledger.
  NOTHING was persisted outside OWNED_PATHS. Specifically NOT touched: WORK_STATE.md, LANES.md,
  DECISIONS.md, AGENTS.md, .decisions/**, the mobile lane's directory, production source, migrations,
  docker/**. Required corrections for each are listed under BLOCKERS for the Manager.

BLOCKERS:
  None blocking Design Revision 2 itself. It is complete and internally consistent.
  The following are REPORTED for the Manager and are outside my OWNED_PATHS — none was performed:

  1. HUMAN_DECISION_REQUIRED — 9417f8bf (SECURITY, PENDING) must be REISSUED against ADR 0018 before
     it reaches the human. Its four options are inconsistent with the governing ADR: A2 is forbidden by
     ADR 0018:87-88, and A1/A4 are the ADR's own substrates. The question must become Q1' (supersession
     of :85-88), and — per M4 — must be WIDENED to cover Q4/G-7 (client exposure), which R1 left with
     no owner. Its existing SUPERSEDED-IN-PART note already states consequences 2 and 3; this revision
     agrees and supplies the option framing. MANAGER-OWNED: I did not edit it.
  2. HUMAN_DECISION_REQUIRED — 79e860e2 (SECURITY, PENDING) must be RESTATED as Q3' (§ R.6.1), not as
     an unanswered disposal menu, and must state that b869ec24 is silent on revocation.
  3. HUMAN_DECISION_REQUIRED — 898b07d0 (ARCHITECTURE, PENDING) should be reframed as a contradiction
     with ADR 0018:100-102, which raises its severity above "which of three options". Its context also
     carries the L1/L2 line errors (engine:52 → :54; product_state.dart:29-32 → :24-27).
  4. LEDGER CORRECTION (Manager-only) — retract the false "ADR 0018 DOES NOT EXIST" facts in
     WORK_STATE.md:484-490 and LANES.md:204-205, and the copies in .decisions/898b07d0 and
     .decisions/9417f8bf. Correcting the discoveries.md D-6 record required the Manager because the
     fact it records was false; I retracted my own copy in place and appended the retraction, but the
     ledger copies are not mine.
  5. NOTIFY SIBLING LANE (Manager) — design-addproduct-mobile must be told that Brief v1.1.0
     supersedes implication #2 of v1.0.0 (FOUR _StepText entries, not three), and that N-8's
     inkSecondary requirement applies to its boards and copy too (inkTertiary measures 4.23:1 dark,
     failing AA, and is the idiom at :542 and :590).
  6. INDEX GAP (Manager) — add 570bb640 to DECISIONS.md's index table (L-6).
  7. GOVERNANCE ACTION (Manager/human) — G-1': AGENTS.md has no §13/§13b, so ADR 0018's carve-out,
     ADR 0012:34 and ADR 0019:121 point at text that does not exist. NOT blocking Gate D3 — ADR 0018,
     the substantive document, is present and read. NOT written by me (AGENTS.md is outside OWNED_PATHS).
  8. NOT SAFE YET — implement-addproduct remains blocked: OPEN-D4-1 is undecided and the substrate
     option set itself was wrong until this revision; and B2 shows the store cannot yet uphold the
     immutability the design claims, so implementing mint/check against it today would ship a
     silent-rotation path. qa-contract-addproduct may proceed against AC-01..AC-14 / SC-01..SC-10
     with SC-08 treated as an OPEN D4 dependency, but must NOT yet draft assertions for SC-02/SC-03 —
     both currently pass for the wrong reason.
  9. UNVERIFIED, a human's to run (unchanged from R1, plus two new) — SC-01 real-SSH acceptance; A4
     container→host keychain reachability; HostKeyStatus.changed detection against a real host; and
     NEW: T-A and T-B against the Postgres-backed store (D-1's predicated DO UPDATE and D-2's index).

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```

---

## Files touched

```text
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-2.md            (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-2.yaml  (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-brief-1.1.0.md            (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-2.md        (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md                  (EXTENDED — additive)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/report-revision-2.md            (NEW — this file)
```

All six are inside `OWNED_PATHS`. Verified with `git status --porcelain`: nothing outside
`docs/engineering/dispatch/tasks/design-addproduct-keyservice/` was added or modified.
**Revision 1 is retained byte-identical**: `design-revision.md`, `design-revision-metadata.yaml`,
`design-brief.md`, `traceability-matrix.md`, `prompt.md` and `report.md` were copied in from the
canonical checkout and **not edited**. `discoveries.md` was extended additively, plus two in-place
corrections (D-6 retraction banner with the original text preserved; D-7 heading/framing per `L5`).

**This report is written to `report-revision-2.md`, not `report.md`**, because `report.md` is
revision 1's lane report and "keeping revision 1 intact" was explicit. The Manager may rename or
repoint it when persisting.

## What changed and why

- **The single most important change is a retraction.** Revision 1's headline finding — that the
  governing ADR does not exist and its content had to be reconstructed as ten assumptions — was
  **false**, produced by listing `docs/engineering/adr/` instead of `docs/adr/`. ADR 0018 exists,
  is 158 lines, and is cited by 13 production files, several by amendment. Revision 2 reads it in
  full and makes it load-bearing. The state that made this urgent: the false claim had already been
  propagated into `WORK_STATE.md`, `LANES.md` and two Human Decision objects, so the human was at
  risk of being asked to choose a substrate the ADR had already chosen and constrained.
- **The at-rest question was re-framed, not answered.** Q1 (four substrates) becomes Q1′ (does
  `b869ec24`'s server-side custody supersede ADR 0018 `:85-88`?), because that is the real delta.
  A2 is marked **forbidden by the ADR** at the option itself, so the human cannot select it without
  reading that it contradicts the governing architecture. A1/A4 are marked as the ADR's own
  substrates, with the topology condition stated (they comply only while the server is co-located
  with the operator). The decision stays the human's and is defaulted nowhere.
- **The design's central security claim was wrong and is now honestly bounded.** Revision 1 said
  silent key rotation was structurally impossible via four independent mechanisms. It is possible:
  the store upserts `publicKey` on conflict with no `expectedVersion`, and the engine's one-active
  guard declines to refuse a same-`credentialId` re-mint. Revision 2 says exactly two mechanisms
  hold and they are not independent, and converts the gap into **three required design
  deliverables** with two tests that fail today.
- **New interface/schema change: a migration is now REQUIRED (D-2), where revision 1 proposed none.**
  A partial unique index on the active credential set, proposed only — `apps/server/migrations/**` is
  `PROHIBITED_PATHS`, so nothing was created. Its predicate is identical to the read that defines
  "active", so the constraint cannot contradict the query. Revision 1's reuse-row-35 "Migration: none
  proposed" is now marked explicitly conditional on the substrate.
- **One finding I did not expect, and it matters**: a version CAS alone would **not** close the
  immutability hole, because the mint path hardcodes `version: 1`. The guard has to predicate the
  immutable fields themselves. An implementer copying the CAS pattern from the four neighbouring
  credential writers in the same file would ship a fix that looks right and is not.
- **No decision was taken that belongs to the human.** OPEN-D4-1 and OPEN-D4-2 remain `OPEN`. Nothing
  under `.decisions/**` was edited.

### Deviations from the plan, and why

- **Issued Brief v1.1.0 as a new file rather than editing `design-brief.md`.** "Keeping revision 1
  intact" was explicit, and `design-brief.md` is the artifact a sibling lane may already have read.
  Silently editing it would have contradicted a lane that read it; a version bump with a supersession
  note is the mechanism the governance prescribes. Consequence: **the Manager must notify
  `design-addproduct-mobile`** that implication #2 of v1.0.0 is superseded (BLOCKERS #5).
- **Q3 was re-framed rather than withdrawn.** The review offered both. Withdrawing it would have
  removed a question a human may legitimately need to ask — *does the ADR's revocation clause
  survive the custody move?* — and would have silently discarded ADR 0018 `:113-114`. The honest
  form states that the ADR already answers Q3 **under its own model**, names `b869ec24` as silent,
  and asks only the question the silence creates.
- **Reported the reviewer's own "71-line framework template" figure as inaccurate.** `AGENTS.md` is
  **129 lines** at `77c19f1` (verified by `wc -l`). The substantive claim — no `§13`, `Product-specific
  policy: TBD` — is exactly right and is what revision 2 records. I cite the verified figure rather
  than propagating a second wrong number into the ledger, which is the exact failure this correction
  exists to undo.
- **Did not self-approve.** `READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES` asserts readiness only.

## Validation results

| Command | Status | Evidence / note |
|---------|--------|-----------------|
| `git branch --show-current` | pass | `design/correct-addproduct-keys` |
| `git rev-parse --short HEAD` | pass | `77c19f1` |
| Read-only source inspection of every cited `file:line` | pass | Store, engine, migration, `spy.yaml`, ADRs, `add_product_page.dart`, `compose.yaml`, `.env.example`, decision objects — all opened and read at `77c19f1`. See "Evidence" below. |
| `wc -l AGENTS.md` | pass | `129` — used instead of the review's "71-line" |
| `ls docs/adr/` | pass | 21 ADRs, `0001`–`0021`, incl. `0018-per-product-git-credentials.md` |
| `grep -rn "ADR 0018" apps packages --include="*.dart" --include="*.yaml"` | pass | 13 hits — the executable knowledge in D-10 |
| `grep -n "§13" AGENTS.md` | pass | **no match** — the real `G-1'` |
| `grep -n "_StepText(" add_product_page.dart` | pass | 4 entries at `:650, :656, :662, :668` — M1 |
| `grep -c RepositoryCredentialView apps/server/lib/src/endpoints/*.dart` | pass | `0` for all 11 files |
| `grep -rn "SSH_AUTH_SOCK\|known_hosts\|ssh-keyscan\|StrictHostKeyChecking\|IdentityFile" apps packages` | pass | no match — transport seam absent |
| `grep -rn "127.0.0.1:" docker/*.yaml apps/server/docker-compose.yaml` | pass | no match — loopback pinning unimplemented |
| `git status --porcelain` | pass | changes confined to `OWNED_PATHS` |
| **`dart analyze` / `flutter analyze`** | **NOT_RUN** | implementation-lane gate; no claim made about its output |
| **build** | **NOT_RUN** | — |
| **test suite / `make test-integration`** | **NOT_RUN** | T-A and T-B are **specified and predicted** to fail today from source reading. **The prediction is stated as a prediction, not a result.** |
| **ANY Docker or Compose command** | **NOT_RUN — none issued** | `docker`, `docker compose`, `docker ps`, `docker compose config`, `docker compose logs` — **none run, not even read-only.** `AGENTS.md` § Test resource hygiene records that this repository lost a QA database (`docker_postgres_data_qa`, irrecoverably) to a review lane running `docker compose … down -v`. |
| **contrast-ratio measurement** | **NOT_RUN** | `N-8`'s ratios are inherited from `design-register-button/report.md:71-76` and were independently re-measured and confirmed by the Independent Design Review (`:33`). Labelled as such at `N-8`; not re-measured here. |
| **Penpot boards** | **NOT_RUN / not authored** | prohibited for this lane (`C-11`) |

## Evidence (revision-pinned)

```yaml
EVIDENCE_REVISION: 77c19f1
BUILD_COMMAND: NOT_RUN
SERVE_OR_RUN_COMMAND: NOT_RUN
ENVIRONMENT / BASE_URL: n/a — design artifacts only; no build, no serve, no runtime evidence
ARTIFACTS:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-2.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-2.yaml
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-brief-1.1.0.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-2.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/report-revision-2.md
  - docs/adr/0018-per-product-git-credentials.md          (READ in full — :3-4, :15-30, :38-49, :79-88, :92-104, :113-114, :126-127, :140-141, :152-158)
  - docs/adr/0012-immutable-artifact-promotion.md         (READ — :34)
  - docs/adr/0015-worker-execution-layer.md               (READ — :19-22, :29-31, :55-59)
  - docs/adr/0019-standing-policy-authorisations.md      (READ — :49-51, :121)
  - docs/adr/0020-defect-domain-model.md                  (READ — :137)
  - docs/adr/0021-design-defect-routing.md                (READ — :86-91)
  - apps/server/lib/src/persistence/postgres_product_registry_store.dart  (:177-243, :195-210, :214, :238-243, :257-268)
  - packages/product_registry/lib/src/engine/product_registry_engine.dart  (:43-61, :54, :150-170, :899-905, :912-967, :920, :933-939, :940-941, :950-964, :963, :965, :974-1013, :1020-1054, :1058-1076, :1084-1119, :1138-1162)
  - apps/server/migrations/20261001205247600/definition.sql (:645-647)
  - apps/server/lib/src/database/repository_credential.spy.yaml (:1-14)
  - packages/platform_contracts/lib/src/types/repository_credential.dart (:10, :12-18, :22, :70-72, :137-172)
  - packages/platform_contracts/lib/src/enums/product_state.dart (:23-28)
  - apps/control_plane/lib/features/products/add_product_page.dart (:126-138, :230, :239, :542, :590, :650, :656, :662, :668)
  - docker/compose.yaml (:16-17, :62)
  - .env.example (:16-18)
  - .decisions/570bb640-76e1-485d-9a80-309b07585ccd.yaml (:22-27, :34-37, :67-75)
  - .decisions/b869ec24-236e-4e9c-8703-70656fa368c4.yaml (grep -i "revoc\|rotat" → no match)
  - .decisions/9417f8bf-73b8-4827-9515-bdfe92e5a9d5.yaml (read-only; SUPERSEDED-IN-PART note)
  - AGENTS.md (129 lines; grep "§13" → no match; Product-specific policy TBD at :59-63)
```

## Documentation updated

```text
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-2.md            (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-2.yaml  (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-brief-1.1.0.md            (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-2.md        (NEW)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md                  (EXTENDED)
docs/engineering/dispatch/tasks/design-addproduct-keyservice/report-revision-2.md            (NEW)
none outside OWNED_PATHS — WORK_STATE.md, LANES.md, DECISIONS.md, AGENTS.md, .decisions/** NOT touched
```

## Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: not specified by the Manager's dispatch
MODEL_USED: opencode/space-bunny-free
REASONING_EFFORT: n/a (not exposed to this lane)
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

## Unresolved issues and blockers

- **No blocker prevents Design Revision 2 from being reviewed.** All 16 findings (B1, B2, H1–H4, M1–M4,
  L1–L6) are applied and each maps to a specific, cited change.
- **Manager actions** (outside `OWNED_PATHS`, not performed by me) — full text under BLOCKERS 1–8:
  reissue `9417f8bf` against ADR 0018 and widen it to cover Q4/`G-7`; restate `79e860e2` as Q3′;
  reframe `898b07d0` as an ADR contradiction and fix its two line numbers; retract the false ADR-0018
  facts in `WORK_STATE.md:484-490` and `LANES.md:204-205` and the `.decisions/**` copies; notify
  `design-addproduct-mobile` about Brief v1.1.0 and `N-8`; add `570bb640` to `DECISIONS.md`; open a
  governance action for `G-1′`.
- **Human decisions this revision still needs** (none answered here): `9417f8bf` (Q1′ substrate /
  Q2 degraded mode / Q4 client exposure), `79e860e2` (Q3′), `898b07d0` (registration ordering).
- **Findings for other lanes:** `implement-addproduct` is **not safe** — the store cannot yet uphold
  the immutability the design claims, so minting against it today ships a silent-rotation path;
  `qa-contract-addproduct` may proceed but must **not** yet draft SC-02/SC-03 assertions; read-only
  SSH-transport-seam discovery (D-3 / ADR 0015 `:55-59`) is safe now and valuable;
  `design-addproduct-mobile` must be notified per BLOCKERS 5.
- **Four claims remain UNVERIFIED and are the human's to run** (§ 9.2 of the revision), plus two new
  ones — `T-A` and `T-B` against the Postgres-backed store.

## Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - design-addproduct-mobile — unaffected by this correction; disjoint OWNED_PATHS. Items 1, 3, 4, 5
    of the Brief's sibling-lane implications are usable; item 2 is superseded by v1.1.0 and item 6 is
    new (do not say "created on this device"). Needs the Manager's notification.
  - qa-contract-addproduct — may start against AC-01..AC-14 / SC-01..SC-10 with SC-08 treated as an OPEN
    D4 dependency rather than a testable assertion. Do NOT draft SC-02/SC-03 assertions yet: both
    currently pass for the wrong reason (B2).
  - read-only discovery on the SSH transport seam (D-3) — the gap is confirmed and depends on no
    unresolved decision; a design brief for credential injection + host-key verification is valuable
    now and pre-empts neither OPEN-D4-1 nor OPEN-D4-2. ADR 0015 :55-59 gives it a home.
  - read-only work on D-1's implementation shape — the required form is fully specified in § R.15b.1 and
    is substrate-independent, so it can be designed against without waiting on the human. (Implementation
    is not safe; the design is.)
PROHIBITED_PARALLEL_WORK:
  - implement-addproduct (any part) — OPEN-D4-1 is undecided and the substrate option set was itself
    wrong until this revision; and D-11 shows the store cannot yet uphold immutability, so implementing
    mint/check against it today ships a silent-rotation path.
  - any lane creating or editing a Penpot board for this lane's two new states — the sibling owns all four.
  - anyone other than the Manager correcting the D-1/D-6 ledger facts in WORK_STATE.md, LANES.md or
    .decisions/** — and correcting D-6 requires the Manager, because the fact it records was false.
```

## Cleanup confirmation

- [x] All processes started by this lane are stopped — **no process was started.**
- [x] Temporary artifacts removed — none created outside the six artifact paths.
- [x] `git status --short` clean for tracked files outside `OWNED_PATHS` — verified; changes confined to
      `docs/engineering/dispatch/tasks/design-addproduct-keyservice/`.
- [x] **No files modified outside `OWNED_PATHS`** — production source, `.decisions/**`, `WORK_STATE.md`,
      `LANES.md`, `DECISIONS.md`, `AGENTS.md` and the mobile lane's directory were read only.
- [x] **No Docker or Compose command was executed**, including read-only ones. No container, volume or
      compose project was created, so none can leak.
- [x] **No commit, no push** (`COMMITTED: NO`) — artifacts left in the worktree for the Manager.

## Recommended next action

`INDEPENDENT_DESIGN_REVIEW`

Revision 2 is complete and needs a **fresh, independent** design review at Gate D3. This is not a
focused re-review of corrections — the review covered the reviewed HEAD `77c19f1` against revision 1,
and revision 2 rewrites § R.1, § R.3, § R.4, § R.6, § R.15, § R.16, § R.18, § R.21 and adds § R.15b,
which is most of the normative surface. Two notes for the reviewer: **`9417f8bf` must not be presented
to the human before this revision is reviewed**, and `T-A`/`T-B` are specified but **not executed** —
their predicted failure is reasoned from source, not observed.
