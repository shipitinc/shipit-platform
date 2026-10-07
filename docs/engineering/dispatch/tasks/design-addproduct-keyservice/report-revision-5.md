# Report — Design Revision 5, `design-addproduct-keyservice` (correction of Revision 4)

Persisted per `aef-orchestrator` §14. Lane: `design-agent`. **The Design Agent never approves its own
work.** Nothing in this report is an approval, and no approval of any kind stands behind Revisions 1–5.

## Provenance

| | |
|---|---|
| Worktree | `/private/tmp/shipit-correct-addproduct-keys` |
| Branch | `design-correct-addproduct-keys` |
| **`BASE_SHA`** | **`5436a4df354840f4c5bb2ba539319a479b1ba966`** |
| **`HEAD_SHA`** | **`5436a4df354840f4c5bb2ba539319a479b1ba966`** |
| Re-based from | `361256c` — by **`git merge --ff-only main`**, i.e. a **fast-forward, not a rebase commit**. `main` advanced by `43d328b` and `5436a4d` while Revision 4 was under review. Nothing was rewritten |
| `REVISION_ID` | **`7C1E4A96-2B58-4D3F-A0C7-5E19D28B4F63`** |
| `REVISION_NUMBER` | **5** |
| `RISK_LEVEL` | **3** — re-derived, not inherited |
| Committed / pushed | **NO / NO** |
| Docker or Compose | **none issued, not even a read-only one.** Compose files read **as text** |

## Content pins — `git hash-object`, run at `5436a4d` (L13)

**A SHA pins a commit, not content.** Because nothing is committed in this lane, a reviewer must hash the
worktree copies and compare:

```
$ cd docs/engineering/dispatch/tasks/design-addproduct-keyservice && git hash-object <file>
design-revision-5.md            fb99f9e216b10db655b673111062355e690d61fa
design-revision-metadata-5.yaml (pinned in the Manager-facing report)
traceability-matrix-5.md        0778b37d567c25d60efd4a6fb2dbac316212334c
report-revision-5.md            (self-excluded — this file)
```

The same table is in `design-revision-metadata-5.yaml` → `provenance.content_pins.this_revision`, and the
**superseded Revision 4** artifacts' hashes are in `design-revision-5.md` § 0.3. **A file cannot contain its
own hash**, which is why this file's value is the one omitted.

**A merge precondition worth recording (L13's evidence).** Revision 4's four artifacts were **untracked** in
this worktree but **tracked on `main`** after the re-base, which blocks `git merge --ff-only`. Before merging
I compared every one with `git hash-object` against the blob `main` carried: **all four identical**
(`43908b79…`, `4fa79113…`, `eb4b3c48…`, `9d050a27…`). The four untracked copies were moved to a backup
directory **outside the repository**, and the fast-forward proceeded. **No content was discarded, and this
is recorded as a move of untracked working-tree copies rather than presented as nothing.**

## Ownership

| | |
|---|---|
| **`OWNED_PATHS`** | `docs/engineering/dispatch/tasks/design-addproduct-keyservice/**` — **the only paths written** |
| **`READ_ONLY_PATHS`** | `docs/adr/**`; `docs/engineering/dispatch/{LANES,DECISIONS,WORK_STATE}.md`; `AGENTS.md`; `.decisions/**`; all `apps/**` and `packages/**` source; `/private/tmp/shipit-credential-identity` |
| **`PROHIBITED_PATHS`** | all production source, tests, generated files, migrations and **golden baselines**; `docs/adr/**`; `.decisions/**`; `WORK_STATE.md`; `LANES.md`; `DECISIONS.md`; **the mobile lane's directory** |

**No deletion, move or rename of any tracked file was performed anywhere in the repository.** The one move
described above was of four *untracked* copies to a directory outside the repository, to unblock a
fast-forward, and it is stated rather than omitted.

## ⚠ One disclosed gap, first, because it bounds everything below

**The Rev-4 review report does not exist.** `docs/engineering/dispatch/tasks/review-addproduct-keys-rev4/report.md`
— the file I was directed to read in full — is **absent from all 31 worktrees**, from the canonical
repository, and from **every commit reachable from any ref**. `tasks/design-review-addproduct-keys-rev4/`
exists and is **empty**.

So this revision is corrected against the **18 findings as relayed by the Engineering Manager in this
dispatch**, not against the report. **Every finding's evidence was independently re-verified against the
repository at `5436a4d` before its correction.** Two corrections were made against **source** rather than
against the relay, and both are recorded in the artifact:

- **§ R.11g item 7** — the relay states `:925` is the *desktop* `TechnicalDetails`; `:925` is inside
  `_MobileAddProduct` and is the **mobile** one. What is true — and what matters — is that it **has** a
  `note:`, which is the part Revision 4 denied.
- **§ R.9.1 / § R.9.4** — `confirmHostKey` was cited as `engine:1006-1011`, which is the
  *changed-fingerprint* branch; the confirmation is **`engine:1018-1025`**.

**A reviewer should read the actual report before approving**, because a correction can answer the wrong
sentence when a finding's wording differs from its substance. **Owner: the Manager** (§ 10.1 item 11).

## What was reviewed, and what it returned

The Rev-4 review, **as relayed**:

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
INDEPENDENT_RISK_LEVEL: 3
RISK_LEVEL_AGREEMENT: YES
CORRECTION_REQUIRED: YES
HUMAN_DECISION_REQUIRED: NO

2 BLOCKERS (B5, B6) · 3 HIGH (H8, H9, H10)
4 MEDIUM (M3, M4, M5, M6, M7 — five named) · 9 LOW (L5–L13)
```

**Revision 4 was never approved; no prior approval was treated as covering this correction.**

## The `RESULT:` block

```
RESULT: DESIGN_REVISION_COMPLETE

FEATURE: Add Product rebuild — server-side deploy-key service (credential substrate A3,
         split identity from registration, two-sided revocation, cross-product-safe minting)

BRIEF_ID: 97484D0E-E16C-485E-BAA2-A277889C0FB6
REVISION_ID: 7C1E4A96-2B58-4D3F-A0C7-5E19D28B4F63
REVISION_NUMBER: 5

BRANCH: design-correct-addproduct-keys
BASE_SHA: 5436a4df354840f4c5bb2ba539319a479b1ba966
HEAD_SHA: 5436a4df354840f4c5bb2ba539319a479b1ba966

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
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-5.md          (NEW)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-5.yaml (NEW)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-5.md       (NEW)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/report-revision-5.md            (NEW, this file)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md                 (MODIFIED — D-25..D-31 appended)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-4.md            (MODIFIED — supersession banner only; body UNEDITED; tracked on main at 43d328b)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-4.yaml (MODIFIED — banner only)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-4.md        (MODIFIED — banner only)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/report-revision-4.md            (MODIFIED — banner only)
  docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-3.md            (MODIFIED — banner only; body UNEDITED)
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
  0 reasons IMPROVED, 2 reasons UNCHANGED (R1, R6), 4 reasons WORSE (R2, R3, R4, R5).

  This exact sentence appears, character for character, in exactly three places:
  design-revision-5.md § 9.1 · design-revision-metadata-5.yaml risk_rationale · this report.

  Revision 4's sentence — "1 reason IMPROVED (R6), 1 reason UNCHANGED (R1), 4 reasons WORSE
  (R2, R3, R4, R5)" — is WITHDRAWN. Its single IMPROVED leg rested on an acceptance that did
  not exist on the record at Revision 4's base: the amendment read status: DRAFT,
  approved_by: null, reviewed_by: null, human_gate.required: true at level 3, with a blocking
  item reading "ADR 0018 status remains Proposed. This lane does not declare it Accepted."

  R1 UNCHANGED — first handling of key material; a leaked write-capable key cannot be recalled
     from SHIP IT's side.
  R2 WORSE — the credential is exposed through an unauthenticated, unpinned control plane
     (server.dart:71-73); A3 adds a runtime dependency whose unavailability DENIES the credential
     path; and B6 sharpens it again — the mint endpoint as Revision 4 specified it would return
     ANOTHER PRODUCT's publicKey, credentialId, status and hostKeyStatus.
  R3 WORSE — under 898b07d0 this is IDENTITY SEMANTICS, not a gate: a product becomes visible
     before registration commits. ae1c1f79 adds a second interaction, so the flow now has TWO
     distinct failure shapes with different user-visible consequences.
  R4 WORSE — D-4/D-5/D-6 are still unmerged; Revision 4 found THREE more defects in the specified
     flow (G-13, G-14, G-15); THIS PASS FOUND THREE MORE OF ITS OWN — B6's cross-product
     disclosure (G-16), which was introduced by Revision 4's own correction of a blocker;
     D-6's silent omission of lastFailureReason from BOTH tier constructs (H9); and § R.11.2's
     selection rule depending on an ordering guarantee that exists on ONE TIER ONLY (M4).
  R5 WORSE — the transport seam must deliver host-key TOFU verification AND manager-backed
     material resolution; one is an ADR requirement with no precedent in the repository.
  R6 UNCHANGED — Revision 4 claimed IMPROVED because the amendment was "written and Accepted",
     and at its base THAT WAS FALSE. The acceptance is now REAL (Human Decision 876c6b97;
     amendment revision 2, status: ACCEPTED) and the residual Revision 4 asked about is gone (the
     edit IS docs/adr/0018-*.md and IS committed at 5436a4d). Net UNCHANGED for three reasons,
     none of them credit: an acceptance asserted without a record is not an improvement;
     ACCEPTANCE IS NOT REVIEW (reviewed_by is null on purpose, and independent review of the
     amendment has never happened); and the amendment's OWN REVISION 1 contained a factual error,
     over-claiming the partial unique index in the direction that would have made accepted risk
     A1 — the resurrection gap, this design's own subject matter — look closed.

  LEVEL 3 IS UNAFFECTED, AND THIS PASS SUPPORTS IT MORE STRONGLY. Five of six reasons are WORSE
  and the sixth moved from claimed-improved to honestly-unchanged, which removes an argument for a
  LOWER level rather than an argument against a higher one. G-4 is an ADR requirement that is
  half-implemented; the SSH transport seam is LOW feasibility carrying an ADR requirement with no
  implementation anywhere in the repository; G-13, G-14, G-15, G-16 and G-17 are open; and A3's
  reachability is UNVERIFIED. Any one of those is a level-3 fact on its own.

CHANGELOG:
  Per finding. 18 findings: B5, B6 (BLOCKERS); H8, H9, H10 (HIGH); M3, M4, M5, M6, M7 (MEDIUM);
  L5–L13 (LOW). Plus two new register entries and one disclosed gap. Full text in
  design-revision-metadata-5.yaml → changelog and design-revision-5.md § 0.4.

  B5 (BLOCKER) — the ADR amendment was asserted "Accepted by the human" in thirteen-plus places
     and NOTHING ON DISK SAID SO: the amendment's metadata read status: DRAFT, reviewed_by: null,
     approved_by: null, human_gate.required: true at level 3, with a blocking item reading
     "ADR 0018 status remains Proposed. This lane does not declare it Accepted."; .decisions/
     held no acceptance object. ONE OF SIX RISK REASONS RESTED ON IT. FIX: the acceptance is now
     real and every claim is CITED — Human Decision 876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml
     (ARCHITECTURE, RESOLVED, owner's verbatim answer "Accept A2, record the gaps as accepted") and
     amendment revision 2 (status: ACCEPTED, approved_by/approved_at populated, human_gate
     required false with level 3 retained, blocking_items []) plus the ADR's Status line and its new
     § Accepted risks carrying A1–A4 with consequences and owners. ACCEPTANCE IS NOT REVIEW is
     stated where it matters: reviewed_by/reviewed_at are null ON PURPOSE, the amendment carries
     acceptance_is_not_review: true, and § R.17.1 says independent review has NEVER happened and is
     the next gate on that lane — § 10.1 action 1a asks for it. R6 RE-STATED and the tally
     REPUBLISHED as 0 IMPROVED / 2 UNCHANGED / 4 WORSE, with Revision 4's sentence named once as
     withdrawn. And the amendment's OWN revision-1 factual error is recorded and NOT leaned on: it
     claimed the partial unique index refuses a legitimate fresh mint, and it does not, because
     rotateCredential revokes first — so this design does NOT lean on D-2's index to close A1; D-4
     does.

  B6 (BLOCKER) — the corrected step 4 bypassed ownership and no step produced the error table's
     403. engine.readActiveCredential (engine:1135-1142) opens with readRepositoryReference then
     _ensureOwned at :1140 — but Revision 4's H2 fix switched step 4 to
     productRegistryStore.readActiveCredentialForRepository, which filters on repositoryId and
     status <> 'revoked' and HAS NO NOTION OF A PRODUCT AND NO _ensureOwned. CHOOSING THE STORE
     METHOD IS THE BYPASS. Revision 4's claim that step 3 establishes ownership is FALSE:
     addRepositoryReference calls _store.readProduct(productId) for EXISTENCE ONLY (engine:159,
     annotated "existence + scope"), never _ensureOwned, and under G-13's read-first the write is
     SKIPPED whenever the reference already exists — so on exactly the cross-product case step 3
     performs no write and no check. CONSEQUENCE: mintOrReadDeployKey(productId: 'A',
     repositoryId: <B's repository>) returned B's publicKey, credentialId, status and
     hostKeyStatus with alreadyExisted: true, on an endpoint this revision's § R.15.1 records as
     carrying NO AUTHENTICATION (server.dart:71-73) with no loopback pinning. NO STEP raised the
     CrossProductAccessException the error table promised. FIX: § R.14.1 step 3a — a normative
     ownership step, "immediately after readRepositoryReference(repositoryId) returns and BEFORE
     deciding whether to create anything, establish that the reference belongs to productId" —
     with two acceptable forms (compare ref.productId directly, as _ensureOwned does; or
     preferred, call engine.resolveRepository(productId, repositoryId), whose
     RepositoryNotFoundException IS the create signal). § R.14.1 states EXPLICITLY that step 3's
     read-first is NOT an ownership check and that step 4's store call is safe BECAUSE OWNERSHIP
     WAS ESTABLISHED ONE STEP EARLIER — attached to the step that makes it true rather than to a
     write that does not occur on this case. The error table's 403 row names step 3a as its only
     producing step. T-L ADDED: a foreign repositoryId yields 403 AND NO FIELD of the other
     product's credential is returned — not publicKey, fingerprint, algorithm, credentialId,
     status, hostKeyStatus, nor alreadyExisted: true — ON BOTH STORE TIERS. SC-20 added, G-16
     added. SAME SECTION, SAME CORRECTION: G-13's blast radius now carries the FULL column set
     INCLUDING "productId" (store:137), which Revision 4 omitted and which is the one column whose
     rewrite REPARENTS another product's repository reference; § R.10.0 names the mechanism and
     states that G-13's read-first discipline is therefore LOAD-BEARING rather than a footnote —
     which is why step 3a runs before the decision to create.

  H8 (HIGH) — § R.5.7 FORM 2 violated its own obligation 4. `provider.put` sat OUTSIDE the try, so
     a put-throws failure propagated past zero(privateHalf) entirely, and the trailing zero was
     UNREACHABLE after the bare rethrow. FIX: FORM 2 rewritten as `String? handle; try { handle =
     await put(...); await recordGeneratedCredential(...); } catch (error, stack) { if (handle !=
     null) await destroyQuietly(handle); rethrow; } finally { zero(privateHalf); }` — catch keeps
     the destroy, finally keeps the zero, and they are not interchangeable because moving destroy
     into the finally would RE-INTRODUCE B2. § R.5.7 now SHOWS Revision 4's defective form and
     names its two defects. SECONDARY: the sample and the normative sentence disagreed about
     destroyQuietly on a null handle, and the sample is the one an implementer copies — both
     forms now guard on `handle != null`. § 10.2 item 1 checks obligations 1, 2 AND 4 on BOTH
     forms with three named falsifiers; T-I extended; SC-18 extended.

  H9 (HIGH) — D-6's requirement box named EIGHT columns and both tier constructs covered SEVEN:
     lastFailureReason was silently absent from Tier A's _noClear and Tier B's
     _clearsDurableEvidence, while the paragraph below reasoned about it explicitly. The column is
     real, nullable text at definition.sql:632 and is written by recordCredentialCheck's failure
     branch (engine:1061-1065), so an implementer following Revision 4's constructs ships it
     ERASABLE on the CAS branch on both tiers. FIX: the set is decided ONCE, AS EIGHT, and the
     rejection of the alternative is reasoned (it is the only record of WHY a check failed, and
     erasing it while status stays `failing` reproduces § R.5.4's "we could not check ≠ it is fine"
     one layer down). Tier A gains _noClear('lastFailureReason', 'text') plus an eight-row table of
     each column's type and definition.sql line; Tier B gains one further _clears disjunct; § R.9.5,
     SC-17 and T-K all now name all eight — T-K BY NAME, because a count is not a check.

  H10 (HIGH) — the count is TWELVE ROWS ACROSS SIX FILES, not "eleven files". § R.3.2 now carries a
     grep-derived FILE CENSUS so the count is checkable, states 12 rows / 6 files / 10 code edits /
     2 doc-comment edits in one place, and says explicitly that Revision 4's "eleven edit sites" and
     "ten code edits" were counts of ROWS, that neither is the file count, and that "eleven files"
     was wrong on all three counts. Table B corrected: Revision 4 said "9 occurrences" while
     listing ten line numbers; the file has ELEVEN hits and the omitted one is :19, a doc comment.
     THE HONEST FLAGGING OF THE DIFFERENCE FROM THE REVIEW'S "nine" SURVIVES THE FIX. protocol.dart
     DROPPED from § B rather than marked no-op in § C, because a no-op left in a package row
     becomes a task; the same applies to the client's product_detail_view.dart.

  M3 (MEDIUM) — § R.11.2 row 3 claimed revokedAt/revokedReason are on the view. THEY ARE NOT
     (repository_credential_view.yaml:8-25). B3's conclusion still holds — no new field, no
     migration — and row 3 now names the view's full field list and says STATE 4 RENDERS FROM
     `status` ALONE. SC-19 forbids adding either field, so an implementer who trusted Revision 4's
     row cannot "fix" it by breaking the criterion.

  M4 (MEDIUM) — § R.11.2's selection rule was under-specified twice. Direction: REPOSITORY-driven
     (context.repositories, per product_detail_view.yaml:11), because credential-driven iteration
     produces N cards for a repository and no entry for a repository with none. Ordering: REQUIRED
     ON BOTH TIERS — Tier A orders (store:389), Tier B has NO ordering at all (in_memory:236-238) —
     so it is now § R.9.7's FIFTH required contract sentence, because a read's ordering is part of
     its contract whenever a caller is told to rely on it. The "most recent = HIGHEST version" gloss
     is DROPPED AND SHOWN WRONG: each rotated credential starts at version: 1 (engine:977), so the
     gloss is a tie broken by nothing.

  M5 (MEDIUM) — "not in docs/adr/**" was false. The amendment IS an in-place edit of that exact
     file, and at this base it IS committed and landed at 5436a4d. § 10.1's merge action is WITHDRAWN
     BY NAME as premised on a falsehood and replaced by 1a (independent review) and 1b (G-17).
     Because the ADR grew 158 -> 580 lines, every :NN in § R.17 is now labelled an A1-REVISION
     number and § R.17.1 carries a RE-ANCHORING TABLE giving the current-base location of each
     clause that still stands — a frozen contract citing line numbers that resolve to the wrong text
     is the same defect as citing text that is not there.

  M6 (MEDIUM) — § 0.1's topology claim about 77c19f1 was false. It IS an ancestor of main, 18 commits
     behind, diverging from nothing; B1's substance was STALENESS. Added to the verified ancestor
     list so a reviewer can check the correction with the same command.

  M7 (MEDIUM) — rotateCredential DECLARES String? credentialId AS A CALLER PARAMETER (engine:1105)
     and forwards it VERBATIM (engine:1129), so a caller passing the superseded id reaches the
     conflict branch — D-18's resurrection path through a FIRST-CLASS DOMAIN METHOD. The outcome was
     already safe after D-4; the stated REASON was a convention the domain does not enforce. The
     sentence is replaced, § R.9.2 shows the parameter, rotateCredential's credentialId is its own
     ROW in § R.9.5, and T-D IS EXTENDED to drive the attempt through rotateCredential as well.
     D-4 is now justified by the CONSTRUCT rather than the convention.

  L5 step numbers (R.10.1 step 4, not 3) — L6 "four obligations" -> FIVE in § 9.2 and the metadata —
     L7 the tally is now byte-identical in all three places — L8 § R.11g item 7 rewritten with an
     ELEVEN-ROW verified table, including the finding that the mobile TechnicalDetails DOES have a
     note: and the observation that the review's own attribution of :925 to the desktop site is
     inverted — L9 § R.8.5's blockquote completed, including the trailing rotateCredential sentence
     that is TRUE and that the truncation deleted, with a THREE-WAY split of the comment — L10
     credential_test.dart:348 named, its citation corrected to engine:954-961 (engine:940-941 is the
     empty-key check), making D-4's comment correction FOUR parts — L11 GAP-2 mapped into § R.9.6's
     tier table with its line numbers — L12 the § R.11g TechnicalDetails line, plus four further
     citation slips found by a re-sweep and fixed — L13 git hash-object recorded per artifact in § 0.3
     and the metadata, for this revision AND for Revision 4's four superseded artifacts.

  ALSO NEW — § 0.7, the DISCLOSED PROVENANCE GAP (the absent report), recorded in the body, in the
     gates block and in requirements_gaps, routed as § 10.1 item 11; § R.11g's "WHAT THE SIBLING LANE
     NEEDS" block, because that lane is blocked on Penpot and cannot re-ground the Unknown-host pair
     without this revision and cannot ask me; G-16 and G-17 as register entries.

  CARRIED FROM REVISION 4 AND CONFIRMED, NOT RE-OPENED — § R.1.1–R.1.7; § R.2; § R.3.1/.3/.4; § R.4;
     § R.5.1–R.5.6; § R.6.1–R.6.3; § R.7/.7.1; § R.8.1–R.8.4; § R.9.1's CALL-SITE table (which the
     reviewer confirmed is exact); § R.9.2's mechanism table; § R.9.3; § R.9.7's first four items;
     § R.10.0–R.10.3; § R.11's axes; § R.11.1; § R.12; § R.13; § R.14.2/.3; § R.15 in full; § R.16
     rows 1–30 and 32–43; SC-01–SC-16 except where extended; § 9.2's three ratings. § 0.5 lists the
     set explicitly. The reviewer's CONFIRMED list is not re-derived; note that LANES.md is 427 lines
     at THIS base, not the 399 the reviewer confirmed at 361256c.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    OPEN-D4-1 (9417f8bf OPTION_C, 7b1bc8b7, 79e860e2)                    § R.1, R.5, R.6
    OPEN-D4-2 (898b07d0 OPTION_A)                                        § R.10
    the substrate-failure / Product-row interaction (ae1c1f79 OPTION_A) § R.5.2, T-H, § R.11g item 5
    G-7  — referenceName off the client wire                             § R.3.2 (12 rows / 6 files)
    G-9  — one-per-repository as a DB constraint                         § R.8.1
    G-1' — AGENTS.md §13/§13a/§13b restored                             § R.18.1 (CLOSED, B1)
    the LANES.md false claim                                            § R.18.1 (CLOSED, B1)
    ADR 0018 amendment as a predecessor                                  § R.17.1 — HUMAN-ACCEPTED (876c6b97
                                                                         + amendment rev 2), MERGED at
                                                                         5436a4d, NEVER REVIEWED
    SC-02 / SC-03 / SC-15 / SC-16 — extended to require both tiers      § R.9.6
    SC-17 / SC-18 / SC-19 / SC-20 — set decided as 8; obligation 4 on
              both forms; state 4 from `status` alone; ownership        § 8, § R.5.7, § R.11.2, § R.14.1
    AC-01 .. AC-14                                                       traceability-matrix-5.md § 3
  REQUIREMENTS_GAPS:
    G-4  ADR gap (accepted risk A2) — host-key verification absent AT THE TRANSPORT; the domain
         enforces it, so ADR 0018 :96-99 is HALF-implemented.   Owner: implementation (architecture).
    G-3  no test imports add_product_page.dart.          Owner: implementation / QA Contract.
    G-5  no read-only public-key endpoint.               Owner: implementation.
    G-6  recordGeneratedCredential's host is optional.   Owner: implementation.
    G-8  host-fingerprint provenance unspecified.         Owner: implementation.
    G-10 A3's reachability is UNVERIFIED (accepted risk A4) — no probe was run and this lane
         issued no Docker command.                        Owner: implementer, before completion.
    G-11 D-4/D-5/D-6 specified per tier, NOT merged.      Owner: implementer.
    G-12 the duplicate-credential audit — a human-run deployment precondition whose query as
         dispatched DOES NOT EXECUTE, and whose only reachable database held 0 rows (a vacuous
         "no").                                            Owner: HUMAN, before the migration.
    G-13 the § R.14.1 get-or-create step is DESTRUCTIVE, with the FULL column set:
         saveProduct (:92-100) sets name/description/manifestVersion/state/createdAt/updatedAt/
         version; saveRepositoryReference (:136-142) sets PRODUCTID/kind/uri/provider/addedAt/
         version. Revision 4 named five and omitted "productId" — the one column whose rewrite
         REPARENTS another product's repository reference. The read-first discipline is therefore
         load-bearing.                                     Owner: implementation (step 3 + step 3a).
    G-14 state 4 is NOT derivable from the read path this design keeps. The view carries NEITHER
         revokedAt NOR revokedReason; state 4 renders from `status` ALONE; the selection's
         direction is repository-driven; ordering is now required on BOTH tiers; the "highest
         version" gloss is wrong.                         Owner: implementation (one method).
    G-15 CredentialIdentityConflictException, named by D-4, does not exist. Behaviour complete.
                                                         Owner: implementation + ownership grant.
    G-16 mintOrReadDeployKey has NO ownership step and NO test; a foreign repositoryId returned
         another product's publicKey, credentialId, status and hostKeyStatus on an endpoint with
         no authentication.                                Owner: implementation — step 3a + T-L.
    G-17 ADR 0018's own text (:16-21, :572-580) now falsely denies its own acceptance, because
         876c6b97 landed at 5436a4d in the same commit as that text. NOT EDITED — docs/adr/** is
         PROHIBITED to this lane.                          Owner: ADR lane / human as ADR owner.
    L-6  DECISIONS.md's index omits 570bb640 and :16's "All five are PENDING" is false.
                                                         Owner: Manager — reported, not edited.
    ADR 0018 :103's wording ("Rotation is per product") contradicts its own :104 and A1; the ADR
         records it itself at :540-542.                   Owner: ADR lane / human.
    the Rev-4 review report — ABSENT from every worktree and every reachable commit; this revision
         is corrected against the Manager's relay.        Owner: Manager — § 0.7, § 10.1 item 11.

DESIGN_SYSTEM_COMPLIANCE: PARTIAL
UX_ACCESSIBILITY_SCORE: PARTIAL
IMPLEMENTATION_FEASIBILITY: MEDIUM

DISCOVERIES:
  D-25  WORKFLOW_IMPROVEMENT, reusable. A CLAIM OF HUMAN ACCEPTANCE WITH NO RECORD BEHIND IT SURVIVES
        A REVIEW CYCLE IF IT IS REPEATED ENOUGH TIMES. The ADR 0018 amendment was asserted as
        "Accepted by the human" in thirteen-plus places across four artifacts of one revision, and
        one of six risk reasons rested on it, while the artifact's own metadata read DRAFT. Repetition
        is not corroboration: thirteen restatements of an unsourced claim look like thirteen sources.
        Two corollaries. (a) A risk tally is the ONE place a status claim must be earned, because a
        tally is what a reviewer reads to see whether the reasoning was done — so an unfounded
        "IMPROVED" leg is worse than a missing one. (b) An accepted artifact and a reviewed artifact
        are different things and the distinction must travel WITH the claim, not be left in the
        artifact's own notes where a reader will not look. Authority: INDEPENDENT REVIEW — routed.
  D-26  DESIGN_DISCOVERY, product-specific, and the most serious finding of this pass. CHOOSING A
        NARROWER STORE METHOD REMOVES WHATEVER GUARD THAT METHOD CONTAINED, AND NOTHING ON THE PATH
        IS LEFT TO SAY SO. Revision 4 corrected a blocker by switching mintOrReadDeployKey's
        get-or-create read from engine.readActiveCredential — which opens with readRepositoryReference
        and calls _ensureOwned at engine:1140 — to the store's readActiveCredentialForRepository,
        which filters on repositoryId alone. The result was a cross-product disclosure on an endpoint
        with no authentication, produced by a fix, in a revision whose error table already promised
        the 403. The generalisable shape: a "simpler, lower-level" substitution is a security-relevant
        edit unless you diff what the removed call was doing. Second instance in the same correction
        pass: saveRepositoryReference's ON CONFLICT DO UPDATE sets "productId", so the get-or-create
        step's read-first discipline is what prevents REPARENTING a repository across products — a
        hazard the gap entry had omitted because the column was not in its list. Authority: automatic.
  D-27  DESIGN_DISCOVERY, product-specific. A REQUIREMENT BOX AND ITS TWO IMPLEMENTATION CONSTRUCTS CAN
        DISAGREE ABOUT A SET, AND NOTHING NOTICES, BECAUSE THE PROSE AROUND THEM REASONS ABOUT THE
        MISSING MEMBER. D-6's box named eight durable-evidence columns; both tier constructs covered
        seven; the paragraph immediately below the box explained why lastFailureReason must be
        protected. An implementer would have shipped it erasable. The check that catches this is not a
        count — it is writing the set out member by member on a separate line and comparing it against
        each construct, which is now § 10.2 item 2 and T-K's assertion. Authority: automatic.
  D-28  DESIGN_DISCOVERY, product-specific. A CONSTRUCT THAT ACCEPTS TWO FORMS MUST SPECIFY THE SAME
        OBLIGATIONS ON BOTH, AND THE SAMPLE IS THE SPECIFICATION AN IMPLEMENTER COPIES. Revision 4's
        § R.5.7 stated obligation 4 — zero the buffer on every path — as normative and identical
        across both accepted forms, then shipped a FORM 2 that put `put` outside the try, so a
        put-throws failure propagated past the zero entirely and the trailing zero was unreachable
        after rethrow. Its FORM 1 also called destroyQuietly unconditionally inside `if (!recorded)`,
        which is reached with a null handle exactly when put throws — while the section's prose said
        the call must be skipped in that case. Three sub-rules: where two forms are acceptable, the
        per-form code must satisfy every obligation; a normative sentence and its sample are one
        artifact and must not disagree; and an accepted form's failure paths must be enumerated, not
        assumed. Authority: automatic.
  D-29  WORKFLOW_IMPROVEMENT, reusable. A SHA PINS A COMMIT, NOT CONTENT. Provenance labelling answered
        "where was this read?" and the base check answered "is this tree the one the design is about?",
        and BOTH were still insufficient, because the working tree can differ from the commit the SHA
        names — proven here in the most literal way possible: Revision 4's four artifacts were
        untracked in the worktree and tracked on main after a fast-forward, and the merge was blocked
        until each was hash-compared. git hash-object per artifact is the cheap closure, and it is now
        § 0.3, the metadata and § 10.2 item 10. Authority: INDEPENDENT REVIEW — routed.
  D-30  WORKFLOW_IMPROVEMENT, reusable. A CORRECTION PASS CAN INTRODUCE A DEFECT WORSE THAN THE ONE IT
        FIXES, AND THE ONLY SIGNAL IS THE DIRECTION OF THE GAP COUNT. Revision 4 found three new
        defects in the specified flow (G-13, G-14, G-15); this pass found three more, and the worst of
        them was manufactured by Revision 4's own correction of a blocker. Nothing about the workflow
        distinguishes a corrective edit from an additive one — both are "small, local, and
        reviewable", and only the gap register shows that the count went the wrong way. So: count the
        gaps the same way before and after a correction pass, and treat an increase as the finding it
        is. Authority: INDEPENDENT REVIEW — routed.
  D-31  CONTRADICTION, product-specific, ESCALATED. ADR 0018's own text at :16-21 and :572-580 states
        that no Human Decision object records its acceptance and that the acceptance has no citable
        decision id. Human Decision 876c6b97 exists and was committed at 5436a4d — in the SAME COMMIT
        that landed that ADR text. This is the same class as the absence B5 was created to fix, now
        inside the ADR itself, and it is in the artifact every future lane cites for custody. REPORTED,
        NOT EDITED: docs/adr/** is PROHIBITED_PATHS for this lane and no such edit is claimed. Owner:
        the ADR lane or the human as ADR owner. G-17, § 10.1 action 1b.

KNOWLEDGE_PERSISTED:
  Persisted IN-REPO, at automatic authority: D-26, D-27 and D-28 (DESIGN_DISCOVERY — verified facts
  about this repository's code, three of them new gaps: G-16, plus the corrected G-13 blast radius and
  the eight-column D-6 set). Also persisted in-repo as content: G-16 and G-17 in BOTH gap registers;
  the twelve-row G-7 change list with its corrected count; and § R.14.1's step 3a as normative text.
  ROUTED, NOT PERSISTED — D-25, D-29 and D-30 are WORKFLOW_IMPROVEMENT, which per LEARNING_POLICY.md §2
  requires INDEPENDENT REVIEW and may not be auto-persisted by a production-writing lane. They are
  product-agnostic and belong in the framework. The Manager is asked to route them; this lane did not
  write them into any framework knowledge store, because it does not hold that authority.
  D-31 is a CONTRADICTION touching architecture and escalates to a human decision or the ADR lane.
  NOT PERSISTED: the a11y contrast figures (inherited, not re-measured); all test/analyzer/build
  outcomes (NOT_RUN); whether A3 is reachable in this topology (UNVERIFIED, G-10); whether a real SSH
  transport accepts the generated key (UNVERIFIED); the duplicate-credential audit (NOT_RUN and not
  runnable from any lane — G-12); the ADR 0018 amendment (human-owned and now merged; recorded, not
  edited, and its independent review is § 10.1 action 1a); WORK_STATE.md, LANES.md, DECISIONS.md,
  AGENTS.md and .decisions/** (Manager-owned — required changes listed in § 10.1, none performed); the
  mobile lane's artifacts (PROHIBITED_PATHS — § R.11g states what it needs and edits none of it); and
  all production source, tests, migrations and golden baselines (PROHIBITED_PATHS).

BLOCKERS:
  None in the sense of "this revision cannot be finished". It is finished: every finding is corrected,
  every gate is reported NOT_RUN, and no deletion is claimed that was not made. **Three things are
  recorded as open, and one of them should not be waved through:**

  1. ⚠ PROVENANCE_GAP — THE REV-4 REVIEW REPORT DOES NOT EXIST (B5, § 0.7). Checked all 31 worktrees,
     the canonical repository, both plausible directory names, and every commit reachable from any
     ref; tasks/design-review-addproduct-keys-rev4/ exists and is EMPTY. This revision is corrected
     against the Manager's relay of 18 findings, with every finding's evidence independently
     re-verified against source at 5436a4d, and two corrections made against source where the relay's
     attribution did not match it. **A reviewer MUST read the actual report before approving.** Owner:
     the Manager — supply it, or accept the relay as the finding set of record (§ 10.1 item 11).
  2. ⚠ EXTERNAL_BLOCKER_NOT_MINE — THE MOBILE LANE IS BLOCKED ON PENPOT, and four of its boards carry
     WRONG SECURITY COPY. penpot_execute_code fails with "No Penpot instance connected for user token"
     on every instance-bound call, before the JavaScript runs — a token-to-instance binding fault. Art
     S on all four boards reads "private half stays server-side", which is FALSE under A3: SHIP IT does
     not hold the private half at all. That is wrong security copy on four boards which cannot be
     corrected without Penpot, and neither the boards nor Penpot is inside my OWNED_PATHS. § R.11g now
     carries a "what the sibling lane needs" block so its next pass does not have to reach me. Owner:
     the Manager (Penpot binding) and the mobile design lane (the boards).
  3. Open, and NOT discharged by this revision — recorded so a Manager reading COMPLETE does not read
     it as "ready to implement":
     a. IMPLEMENTATION IS NOT UNBLOCKED. D-4, D-5 and D-6 are specified per tier and NOT built (G-11);
        G-7, G-13, G-14 and G-16 are specified and not built; the SecretProvider, the mint endpoint
        (INCLUDING ITS OWNERSHIP STEP), the check path's manager resolve and the revoke endpoint do
        not exist. A3's reachability is UNVERIFIED (G-10). The SSH transport seam is LOW feasibility
        and carries an ADR REQUIREMENT with no implementation.
     b. THE ADR 0018 AMENDMENT IS HUMAN-ACCEPTED, MERGED, AND NEVER INDEPENDENTLY REVIEWED. § R.17.1
        records the state; the review is § 10.1 action 1a and the ADR's own two false statements are
        action 1b (G-17). docs/adr/** is PROHIBITED_PATHS here, so neither is performed by me.
     c. TWO CONSUMER LANES ARE UNCONSUMED. The mobile artifact is based on 77c19f1, states 9417f8bf as
        PENDING though it has been RESOLVED since 2026-10-06T13:05:00Z, and carries no
        RegistrationCommitState model and no reference to § R.11g, so items 3 and 5 are not consumed.
        Not my file; § 10.1 item 6.
     d. HUMAN APPROVAL OF THIS REVISION'S CONTENT IS STILL REQUIRED, at risk level 3: D-4, D-5,
        D-6 (now eight columns), G-13 (now including the reparenting hazard), G-14, G-16, SC-11..SC-20,
        the N-9 copy, § R.5.7's both forms, and § R.14.1's step 3a ownership step. Nothing here is
        self-approved and reviewed_by/approved_by are null in the metadata on purpose.

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```

## Gates — nothing was run

| Command / check | Status |
|---|---|
| **Any Docker or Compose command** | **NOT_RUN — none issued, not even `ps`, `config` or `logs`.** Compose files read **as text** (`docker/compose.yaml:16-17`, `:63`; `.env.example:16-18`). `AGENTS.md`'s read-only-over-shared-Docker rule binds this lane; `make test-integration` is the only exemption and was not used |
| `dart analyze` / `flutter analyze` / build | **NOT_RUN** |
| `dart test packages/product_registry/test` | **NOT_RUN** |
| `make test-integration` | **NOT_RUN** |
| `T-A` … `T-L` | **NOT_RUN.** `T-A`/`T-B`/`GAP-2` are reported green **by the implementer's report** — not re-run by me, and no claim of mine. `T-C`…`T-L` **specified, not executed**; their predicted pre-fix failures are predictions from the code path |
| Contrast measurement | **NOT_RUN** — figures **inherited**, not re-measured |
| The `fix/credential-identity-invariants` gates | **NOT_RUN by me** — that lane's results are **not adopted as mine** |
| Penpot | **NOT_RUN / not authored** (`C-11`). The sibling lane is blocked on it; I could not and did not clear that |
| ADR 0018 amendment — merge, edit, review | **NOT_RUN — none of the three.** § R.17.1 reports the state; **no such edit is claimed** |
| **The Rev-4 review report** | **NOT_FOUND — disclosed.** § 0.7 |
| **`git merge --ff-only main`** | **pass** — fast-forward `361256c` → `5436a4d`, after hash-comparing the four untracked artifacts against the blobs `main` carried |
| **§ 0.3's ancestor loop + `git hash-object`** | **pass** — run at `5436a4d`; the hashes are recorded in § 0.3 and the metadata |
| **Deletions** | **NONE MADE.** Only files under `docs/engineering/dispatch/tasks/design-addproduct-keyservice/**` were created or edited. **No tracked file was deleted, moved or renamed anywhere in the repository.** Four *untracked* copies of Revision 4's artifacts were moved to a backup directory **outside** the repository to unblock the fast-forward — stated here rather than presented as nothing |
| Read-only source inspection | **pass** — every `file:line` opened and read at `5436a4d` |
| Commit / push | **NOT_RUN** |

## Confirmation of the review's confirmed items

I did not re-open any of these, and § 0.5 lists the sections carried verbatim as a result: the
provenance/B1 remedy; B2's structural claim (the compensation construct appears in exactly one place with
three references and no variant); B3's conclusion (**no new field, no migration**); B4's remedy (Tier A and
Tier B constructs genuinely distinct); H1, H4, H7 closed; `G-13`, `G-14`, `G-15` all real; and the citation
discipline, called *"genuinely high"*. **The bound on that list is stated in § 0.2: it confirms specific
claims and sampled citations; it is not an approval of Revision 4, and it does not carry over.**

**Two numbers I state differently from the relay, both against source.**

1. **The Rev-4 reviewer's own attribution of `:925`.** The relay says *"`:925` is the **desktop** one that
   does"* — and `:925` is inside `_MobileAddProduct` (`:774`–`:1117`), so it is the **mobile** site. The
   desktop one is `:316`. What is true — and what Revision 4 got wrong — is that the mobile site **does**
   carry a `note:` (`:926-928`), so *"no footer copy"* is **two** `note:` sites plus a `_buildFooter`, and
   `27ea6536`'s removal is **three** edits. The sibling lane's own `D-3` reached the same three sites, which
   is the confirmation the correction landed on the right lines.
2. **`confirmHostKey`'s citation.** Revision 4 cited `engine:1006-1011`, which is the
   *changed-fingerprint* branch — it sets only `hostKeyStatus` and `hostKeyFingerprint` and then throws.
   The confirmation that sets `hostConfirmedAt`/`hostConfirmedBy` is **`engine:1018-1025`**. Found by the
   re-sweep L12 required, since the report is absent and L12's line was not identified.

## Human approval still required

Per `DESIGN_GOVERNANCE.md` and risk level 3, the **content** of Revision 5 requires
product/design/architecture human approval. The human's own decisions are all taken — six at Gate D4, plus
`ae1c1f79`, plus the ADR 0018 amendment with four gaps accepted (`876c6b97`) — **but none of them approves
this artifact**, and `reviewed_by`/`approved_by` are `null` in the metadata on purpose so a reader cannot
mistake silence for approval. What is being asked for is approval of `D-4`, `D-5`, `D-6` (eight columns),
`G-13` (including the reparenting hazard), `G-14`, `G-16`, `SC-11`–`SC-20`, the `N-9` copy, § R.5.7's **both**
accepted forms, and § R.14.1's **step 3a ownership step**.

**This revision is not approved by its author.**