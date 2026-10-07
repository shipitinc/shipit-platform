# Subtask Report — design-correct-adr-0018-a2-2

Persisted per `aef-orchestrator` §14 and the instruction to write the full report to disk before
returning. **This is the third report lost in this work item**; see **Unresolved issues** → F-3.

## Mandatory header

```yaml
RESULT: DESIGN_REVISION_COMPLETE
TASK_ID: design-correct-adr-0018-a2-2
TASK_TYPE: design-produce
FEATURE: ADR 0018 amendment A2 correction (revision 3) — resolve 2 HIGH review findings, correct G-17
WORKTREE: /private/tmp/shipit-design-adr0018
BRANCH: design/adr-0018-amendment
BASE_SHA: 289f1d3
HEAD_SHA: 289f1d3
COMMITTED: NO
```

## Design-agent result block (verbatim from `.agents/agents/design-agent.md`)

```
RESULT: DESIGN_REVISION_COMPLETE

FEATURE: ADR 0018 amendment A2 correction (revision 3) — resolve 2 HIGH findings from the revision-2
  review, and correct G-17 (the ADR denied the existence of its own acceptance decision object).
BRIEF_ID: design-adr-0018-amendment   (no formal Design Brief exists; the Manager's dispatch header
  served as the brief — recorded rather than back-filled with a synthetic id)
REVISION_ID: ADR0018-A2-REV3
REVISION_NUMBER: 3
BRANCH: design/adr-0018-amendment
BASE_SHA: 289f1d3
HEAD_SHA: 289f1d3   (no commit made — the dispatch forbids committing)

OWNED_PATHS:
  - docs/adr/0018-per-product-git-credentials.md
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**

READ_ONLY_PATHS:
  - docs/adr/** (every other ADR — 0018 is the only one written)
  - .decisions/** (all 14 objects; read in full where cited, none modified)
  - apps/**, packages/**, infrastructure/**, docker/** (read as text), .github/**
  - docs/engineering/WORK_STATE.md, docs/engineering/dispatch/LANES.md
  - docs/engineering/dispatch/tasks/design-addproduct-keysservice/**
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**

PROHIBITED_PATHS (none written):
  - any ADR other than docs/adr/0018-per-product-git-credentials.md
  - .decisions/**
  - production source under apps/**, packages/**, infrastructure/**
  - docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev5/**
  - docs/engineering/dispatch/tasks/design-review-addproduct-mobile-rev5/**

ARTIFACT_PATHS:
  - docs/adr/0018-per-product-git-credentials.md                          (580 -> 811 lines, MODIFIED)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-3.md        (NEW)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata-3.yaml (NEW)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/report.md                    (NEW, this file)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision.md            (UNTOUCHED — history)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata.yaml (UNTOUCHED — history)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-2.md        (UNTOUCHED — history)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata-2.yaml (UNTOUCHED — history)

RISK_LEVEL: 3
RISK_RATIONALE: |
  Level 3 (Major Workflow / Architecture Change), UNCHANGED from revisions 1 and 2. The level
  describes the change, not whether a human blessed it or how carefully it is worded; acceptance did
  not lower it in revision 2 and a precision correction does not lower it here.

  1. Amends recorded architecture on a SECURITY BOUNDARY — where a private key capable of
     authorising repository WRITE access is held, and what "revoked" means. No such secret exists in
     the repository today.
  2. Changes a core workflow — revocation acquires a ShipIt-side action where ADR 0018 required none,
     plus a runtime dependency (the secret manager) that can block the credential path.
  3. Depends on enforcement that lives elsewhere and is STILL PARTLY ABSENT at 289f1d3: no transport
     host-key enforcer, no secret-manager adapter, no manager-handle destruction, and registration is
     not wired to a connectivity check. All recorded per clause in the new §Decision status.
  4. Carries FOUR accepted risks on a security boundary, each with its consequence. This revision
     closes NONE and adds NO fifth; it makes gap A4's evidence accurate, which narrows the work
     without changing the risk.
  5. This revision NEWLY DISCLOSES a security consequence the earlier revision OBSCURED — the
     same-uid exposure during the transport-time window in which SHIP IT holds the materialised
     private half (9417f8bf:116-119 rejected A1 for exactly this reason). It is a DISCLOSURE, not an
     added risk: the exposure existed in the accepted architecture from the moment A3 was chosen, and
     this revision is the first to state it. Stating it plainly is why the level does not fall.

  Level 3 approval was satisfied 2026-10-06 by the repository owner as ADR owner (876c6b97,
  OPTION_A). That satisfied the HUMAN GATE. It does NOT satisfy INDEPENDENT REVIEW, which has never
  happened for any revision of this artifact.
CHANGELOG: |
  Revision 3. Responds to the independent review of revision 2 (CHANGES_REQUIRED, 0 BLOCKERS, 2 HIGH)
  and to finding G-17 from the keys rev-5 review.

  H1 (HIGH 1, verified then corrected): the ADR asserted the absolute "SHIP IT never holds key bytes"
    at :83, :226, :33 and :331-333 while requiring SHIP IT to retrieve the private half from the
    manager at transport time — false by the ADR's own next sentence. Scoped by DIMENSION: never
    STORED (the guarantee; it is what excludes A2) versus materialised transiently at transport time
    (true, and not a guarantee). Records the consequence the absolute obscured — the same-uid
    exposure moves from the filesystem to process memory for the connection's lifetime. Weakens no
    clause; changes no decision.
  H2 (HIGH 2, verified then corrected): A3 was stated in the present indicative (:4, :33, :78
    "Current", :226, :284-293) with no adapter, no resolver and no endpoint in existence. New
    §Decision status marks all nine clauses Decided/Built with per-clause file evidence; the ADR's own
    existing idiom at :368-370 ("Requirement, not yet enforced at the transport") is applied rather
    than a new device invented. Two clauses recorded as PARTLY built.
  H3 (G-17, verified then corrected): ADR :16-21 and :572-580 denied that any Human Decision object
    recorded the acceptance, and 876c6b97 landed in 5436a4d — the SAME commit that wrote the denial.
    Both passages now cite the object with its decision fields; the correction block gives the
    --diff-filter=A evidence and the 13-versus-14 timeline. Recorded precisely: revision 2's
    verification was SOUND at its base 43d328b; the defect was writing a fact with a shelf life as a
    standing claim.
  N1  status ACCEPTED -> DRAFT (the owner's acceptance is unchanged and cited in full; the artifact is
      under correction and unreviewed).
  N2  NEW §Decision status (ADR :278-312).
  N3  NEW §Amendments A2 subsection "never holds key bytes — what that claim does and does not mean".
  N4  NEW A1-A4 identifier disambiguation in §Accepted risks.
  N5  A2 table row re-worded; §Positive revocation retitled "specified to be two-sided"; fallback
      clause records that NEITHER substrate is implemented; §Invariants preamble carries a correction
      note binding every downstream reader to the scoped reading.
  N6  Gap A4 evidence CORRECTED: the earlier search was *.dart-only and so could not see that a secret
      manager is already provisioned in this repository's Terraform. Accepted consequence RESTATED
      UNCHANGED; the gap stays OPEN.
  N7  876c6b97 added to §Related → "Decisions governing amendment A2".
  N8  §Related → "The acceptance itself" rewritten to cite the object, with dated correction block.
  C1  Revision 2's own metadata (decision_object: null) and design-revision-2.md (R25, :430) carried
      the same false denial. RETAINED UNALTERED as history and superseded here — revising them in
      place would repeat the exact defect being corrected.
  C2  R25 counted 14 decision files at 43d328b; there were 13. Conclusion correct, count wrong.
  C3  The dispatch's provenance (6220951) is wrong for the A2 revision; it is 5436a4d. 876c6b97 is a
      decision id, not a commit. Material because G-17's whole argument is a commit-ordering argument.
  C4  reviewed_by / reviewed_at: STILL null, deliberately unchanged.
  NOT CHANGED: revisions 1 and 2 (the ADR's own no-silent-rewrite convention); the four accepted risks
      (same four, none closed, none added); the owner's answer in 876c6b97; the nine governing
      decisions (read and cited, none edited); .decisions/** (14 objects, untouched); every other ADR;
      all production source; all QA artifacts.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - "HIGH 1 — the 'never holds key bytes' claim must stop contradicting the ADR's own transport-time
       retrieval clause. Scope the clauses; do not assert flatly. Verified BEFORE acting; corrected at
       ADR §Amendments A2 (new scoping subsection), the A2 table row, 'Effect on intent', §Decision,
       §Invariants preamble and the revocation clause. Per-site ledger: design-revision-3.md §2."
    - "HIGH 2 — A3 custody must stop being stated in the present indicative while no substrate adapter
       exists. Corrected via a new §Decision status plus re-tensing at :4, :33, :78, :226, the
       revocation bullet and the fallback bullet. Per-site ledger: design-revision-3.md §3."
    - "Re-verify both HIGH findings yourself before acting on them. Done independently before any
       edit; ledgers at §2 and §3, and V-5 re-runs the substrate searches."
    - "G-17 — correct the denial that 876c6b97 exists and say how you established it. Done at ADR
       §Status and §Related, with a commit-evidence table."
    - "Make the ADR's tense match 876c6b97's acceptance-with-four-gaps. Done; §Accepted risks now
       states the count is unchanged at four, none closed, none added."
    - "Read 876c6b97 IN FULL before drafting. Done (164 lines). It supplied gap A4's wording and the
       four-gap count, both of which shaped the correction."
    - "Do not re-open settled decisions. The nine governing decisions are read and cited; none edited."
    - "Isolation — preserve the uncommitted local edit, re-base, re-apply only what main lacks, report
       exactly what was found and done. Done; see PRE-FLIGHT below."
    - "State what is decided versus what is merely planned. §Decision status; every clause marked."
    - "Search the domain's own vocabulary, not the requester's phrasing; verify paths exist before
       trusting an UNCHANGED result. This found a GCP Secret Manager substrate that revision 2's
       *.dart-only search could not see (F-2), and disproved the dispatch's commit SHA (F-6)."
    - "Run NO Docker or Compose command whatsoever. None issued, not even a read-only one."
    - "Do not commit or push; do not approve your own work. Neither done."
    - "PERSIST YOUR FULL REPORT TO DISK before returning. This file."
    - "Exact provenance on every result. BASE_SHA/HEAD_SHA, per-revision verification ledger, and
       pre-flight evidence."
  REQUIREMENTS_GAPS:
    - "G-a — 9417f8bf:210-211 and 876c6b97:20-21 STILL carry HIGH 1's absolute wording. Both are
       Manager-owned and PROHIBITED to this lane, so they are reported (F-1), not edited. Until the
       Manager corrects them the overclaim remains in two authoritative records that the ADR cites."
    - "G-b — the transport-time same-uid exposure has NO OWNING FOLLOW-UP ACTION. It is recorded as a
       property of the accepted architecture but is not one of the four accepted risks, so
       876c6b97's assignments (gap A2 -> design-agent; gaps A3/A4 -> implementation/deployment) do not
       reach it. Surfaced for the Manager to route; deliberately NOT self-assigned."
    - "G-c — A3 reachability remains UNVERIFIED and cannot be closed by a design lane; it needs the
       runtime probe 876c6b97:152-156 assigns outside this scope. No Docker or Compose command was
       run and no probe is claimed."
    - "G-d — the review report this task was created from is ABSENT, so the finding set was
       RECONSTRUCTED from ADR text and checked against the Manager's summary and the source decisions.
       If the report surfaces with findings beyond the 2 HIGHs and G-17, they are NOT addressed here."
    - "G-e — §Known gaps 'Rotation is still described in product scope in two places' remains OPEN by
       design: a documentation reconciliation with no security consequence, recorded rather than
       silently rewritten per the ADR's own convention, and outside this task's scope. Recorded so
       its absence is not mistaken for completion."
    - "G-f — 876c6b97 records confidence HIGH for accepting A2 while 9417f8bf records confidence LOW
       for the substrate itself. Both Manager-owned, same substrate. Not resolved here; noted so a
       reader comparing them is not surprised."

DESIGN_SYSTEM_COMPLIANCE: PASS
UX_ACCESSIBILITY_SCORE: PASS
IMPLEMENTATION_FEASIBILITY: MEDIUM

DISCOVERIES:
  - "F-1 [CONTRADICTION — HUMAN/MANAGER authority, REPORTED NOT EDITED] HIGH 1's root contradiction also
     sits in 9417f8bf:210-211 ('SHIP IT never holds key bytes, only a reference, and asks the manager
     for the material at push time') and 876c6b97:20-21. The ADR is now corrected; ITS CITED
     AUTHORITY IS NOT. Both are .decisions/**, PROHIBITED to design lanes. Note 9417f8bf:116-119
     already contains the correct same-uid reasoning, so those records are internally inconsistent."
  - "F-2 [PROJECT_FACT — persisted] GCP Secret Manager IS already provisioned in this repository's own
     Terraform, with roles/secretmanager.secretAccessor already granted to the Cloud Run service
     account. Revision 2's gap-A4 evidence was *.dart-only and so could not see it.
     modules/secrets/main.tf:23,31,39; modules/cloudsql/main.tf:77-89; modules/iam/main.tf:31-34;
     modules/cloudbuild/main.tf:72-76; main/main.tf:82-87. NO deploy-key secret is declared in
     infrastructure/ and nothing binds the server at runtime. Narrows A4; does not close it.
     Persisted into ADR §Decision status and §Accepted risks A4."
  - "F-3 [WORKFLOW_IMPROVEMENT — independent review] THE THIRD LOST REPORT.
     design-adr-0018-amendment/report.md does not exist; the directory held only the four revision
     files. The finding set was reconstructed and that is stated in the artifact rather than presented
     as if the report had been read. Losing a review report breaks the audit trail: the reviewer's
     reasoning survives only as a Manager paraphrase inside a dispatch prompt. Recommend the Manager
     persist review output to disk BEFORE dispatching a correction task."
  - "F-4 [WORKFLOW_IMPROVEMENT — independent review] A SECOND MERGE OBSTACLE existed that the
     Manager's pre-flight did not report: after stashing the ADR edit, `git merge --ff-only` failed
     because the UNTRACKED task directory collided with files 5436a4d began tracking
     ('untracked working tree files would be overwritten by merge'). Isolation pre-flights should check
     untracked files against the target commit, not only tracked modifications. Worked around safely."
  - "F-5 [PROJECT_FACT — persisted] A1-A4 denote TWO different identifier spaces in ADR 0018
     (substrate options in §Amendments/§Decision/§Preconditions; accepted risk ids in §Accepted risks),
     and 'A3' is simultaneously the adopted substrate and an accepted risk. Disambiguation table added."
  - "F-6 [PROJECT_FACT — persisted] 6220951 is NOT the commit that landed amendment A2; it is an
     AGENTS.md commit that does not touch this ADR. The A2 revision is 5436a4d. 876c6b97 is a decision
     id, not a commit. Material because G-17's entire argument is a commit-ordering argument."
  - "F-7 [PROJECT_FACT — persisted] TWO clauses are PARTLY built, which a binary read would hide:
     revokeCredential (product_registry_engine.dart:1072-1085) writes the audit row but nothing
     destroys a manager handle; recordCredentialCheck (:1034) and requireUsableCredential (:1152)
     exist but nothing orders REGISTRATION after a successful check — ProductState.registered is still
     the default at product.dart:26. Neither partial state satisfies its clause."

KNOWLEDGE_PERSISTED:
  - "F-2 (GCP Secret Manager provisioned in this repo's Terraform, with a Cloud Run secretAccessor
     grant, and no deploy-key secret) — written into docs/adr/0018-per-product-git-credentials.md
     §Decision status and §Accepted risks A4. Verified, evidence-backed PROJECT_FACT; within this
     lane's automatic authority and inside OWNED_PATHS."
  - "F-5 (A1-A4 identifier collision) — written into §Accepted risks as a disambiguation table."
  - "F-6 (the correct commit SHAs) — written into ADR §Status, §Related, design-revision-3.md §0 and
     design-revision-metadata-3.yaml provenance.verified_against."
  - "F-7 (two partly-built clauses) — written into §Decision status with per-clause evidence."
  - "F-1, F-3, F-4 are CONTRADICTION / WORKFLOW_IMPROVEMENT and exceed this lane's authority. They are
     REPORTED in this report and in design-revision-3.md §8, and NOT persisted to any repository
     location outside OWNED_PATHS. F-1 touches recorded security architecture in Manager-owned
     decision objects and is human/Manager authority."

BLOCKERS: none

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```

---

## PRE-FLIGHT — the uncommitted local edit (dispatch called this the crux)

**Nothing was discarded.** Sequence actually performed, in order:

| Step | Action | Result |
|---|---|---|
| 1 | `git diff > <out-of-tree>.patch` | edit captured **before anything else** — 34 993 bytes, 496 lines |
| 2 | Copied the working-tree ADR + the whole untracked task directory out of tree | backup retained at `/private/tmp/adr-a2-safety/` |
| 3 | Compared local ADR against `main` by SHA-256 and `diff -u` | **byte-identical** — `9e5b47723e40fd0fd42b69ddf4b5330768ca4fcf782acb0f1992e7aebb83b4fb` both; `diff` produced **0 bytes** |
| 4 | `git stash push` (**never** `checkout --`) | stashed, with a message recording that the entry is superseded and must not be dropped blindly |
| 5 | `git merge --ff-only 289f1d3` | **FAILED AGAIN** — see the second obstacle below |
| 6 | SHA-compared the 4 untracked task files against `main`'s tracked copies | **all four identical**; removed duplicates and fast-forwarded |
| 7 | `git merge --ff-only 289f1d3` | **succeeded**, clean fast-forward `43d328b..289f1d3` |

### What the uncommitted edit actually WAS

**It was amendment A2 itself — already on `main`, and fully superseded.**

| Artifact | Lines | SHA-256 |
|---|---|---|
| local uncommitted working-tree file | **580** | `9e5b4772…` |
| `HEAD` (`43d328b`) | **158** | — |
| `main` (`289f1d3`) | **580** | `9e5b4772…` |

After the fast-forward the worktree ADR's SHA-256 is **still `9e5b4772…`** — identical to the
preserved local edit. That is the proof nothing was lost.

`git merge --ff-only` failed **only** because git cannot fast-forward a branch carrying a local
modification to a file the merge touches, **even when the merged result would be byte-identical**. It
was not a divergent revision, not a newer revision, and not a stale reversion.

### A SECOND obstacle the pre-flight did not report

After the stash, the fast-forward still failed:

```
error: The following untracked working tree files would be overwritten by merge:
	docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-2.md
	docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata-2.yaml
	docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata.yaml
	docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision.md
```

`5436a4d` began **tracking** all four. All four were verified byte-identical to `main`'s copies and
backed up out of tree **before** removal. Isolation pre-flights should compare untracked files against
the target commit, not only tracked modifications (F-4).

### Preservation state

The edit survives in **three** places: the patch file, the out-of-tree backup copy, and
**`stash@{0}`, which is RETAINED and NOT dropped.** A reviewer may `git stash drop` it after
confirming the SHA above. This lane left it in place rather than making a destructive call on a
judgement.

### Correction to the dispatch's provenance

The dispatch states the A2 revision landed in **`6220951`**. It did not. `6220951` is
`AGENTS.md: adopt the read-only-over-shared-Docker rule (item G-2)` and **does not touch this ADR**.
The commit that took ADR 0018 from 158 to 580 lines is **`5436a4d`** — confirmed by
`git log -- docs/adr/0018-per-product-git-credentials.md` and by line counts at `43d328b` / `5436a4d`
/ `289f1d3` (158 / 580 / 580). **`876c6b97` is a decision-object id, not a commit.** This matters:
G-17's entire argument is a commit-ordering argument, and the wrong SHA would have made it
unverifiable (F-6).

---

## Files touched

```text
docs/adr/0018-per-product-git-credentials.md
docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-3.md
docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata-3.yaml
docs/engineering/dispatch/tasks/design-adr-0018-amendment/report.md
```

All inside declared `OWNED_PATHS`. **Nothing outside `OWNED_PATHS` was modified.** Revisions 1 and 2
were deliberately left unaltered as history, per the ADR's own no-silent-rewrite convention at `:37-40`.

**Out-of-tree artifacts written** (outside the repository, not part of the change):
`/private/tmp/adr-a2-safety/{adr-a2-prelocal.patch, adr-0018-WORKING-TREE-158base.md,
adr-0018-MAIN-289f1d3.md, local-vs-main.diff, taskdir-backup/}` — the pre-flight safety net. Retained.

## What changed and why

- **ADR §Status** — cites `876c6b97-3e23-459d-aa9d-3a5faeb33702` as the citable id; Status line now
  says A2 clauses are "**specified to be**" and "**neither A2 clause is implemented**"; the false
  authority note is replaced by a dated correction giving the commit evidence; states explicitly that
  **exactly four** gaps were accepted and none is closed. *(G-17, HIGH 2)*
- **ADR §Amendments A2** — table row re-worded to carry the scoping pointer; `#### Current — custody
  (A3)` → **`#### Decided custody (A3) — specified, not built`** with a DECIDED-NOT-IMPLEMENTED
  marker; **new subsection "never holds key bytes — what that claim does and does not mean"** with the
  three-part scoping and the same-uid consequence; "true *literally*" bounded; revocation clause
  scoped and marked not-implemented; fallback clause records that neither substrate is implemented.
  *(HIGH 1, HIGH 2)*
- **ADR §Decision** — **new §Decision status — decided vs. built**, a nine-clause Decided/Built table
  with per-clause file evidence, the stated consequence, and the GCP Secret Manager infrastructure
  finding; the A3 bullet retitled "specified to be" with an implementation-status paragraph;
  revocation bullet retitled "specified to be two-sided" with "today revocation is one-sided in
  practice"; fallback bullet marked unimplemented. *(HIGH 2)*
- **ADR §Invariants enforced elsewhere** — preamble scoped from "holds no key bytes" to "stores no key
  bytes", plus a correction note binding every downstream reader to the scoped reading. *(HIGH 1)*
- **ADR §Accepted risks** — preamble states the count is unchanged at four and which entries were
  re-verified at which revision; **new A1–A4 identifier disambiguation**; **gap A4's evidence
  corrected** with the Terraform findings and its accepted consequence restated unchanged.
  *(HIGH 2, F-2, F-5)*
- **ADR §Related** — Design Revision pointer advanced to revision 3; `876c6b97` added to "Decisions
  governing amendment A2"; **"The acceptance itself" rewritten** to cite the object, with a dated
  correction block, the commit-evidence table, and the explicit statement that the earlier
  verification was sound and the defect was the tense. *(G-17, F-6)*
- **New revision-3 artifacts** — `design-revision-3.md` and `design-revision-metadata-3.yaml`.
- **Revisions 1 and 2** — untouched, including their own copy of the false denial, which is retained
  as history and superseded here. Revising them in place would repeat the exact defect being
  corrected.
- **No new abstraction, state/ownership change, interface or schema change.** No production code.
- **Deviation from plan:** revision 3's `status` is **`DRAFT`**, where revision 2's was `ACCEPTED`.
  The owner's acceptance of A2 is unchanged and cited in full; the artifact is under correction and
  unreviewed, and `ACCEPTED` would invite a reviewer to read the wording as settled.

## Validation results

| Command | Status | Evidence / note |
|---------|--------|-----------------|
| `git rev-parse --short HEAD` (dispatch `VALIDATION_COMMANDS`) | pass | `289f1d3` |
| `grep -n "never holds\|transport" docs/adr/0018-per-product-git-credentials.md` (dispatch `VALIDATION_COMMANDS`) | pass | every hit is the scoped definition, a cross-reference to it, or the quoted historical wording inside a dated correction block. **No un-scoped assertion remains** |
| `git status --porcelain` | pass | only the intended ADR modification plus the three new untracked revision-3/report artifacts |
| `git log --diff-filter=A -- .decisions/876c6b97*` | pass | `5436a4d`, 2026-10-06 22:11:24 -0400 — G-17's proof |
| `git log -- docs/adr/0018-per-product-git-credentials.md` | pass | `5436a4d` (158 → 580) — the same commit that wrote the denial |
| `git ls-tree --name-only 43d328b .decisions/ \| grep -c yaml` | pass | `13` (R25 claimed 14 → correction C2); at `289f1d3` it is `14` |
| SHA-256 local pre-existing edit vs `main` at `289f1d3`; `diff -u` | pass | both `9e5b4772…`; `diff` 0 bytes — the pre-flight finding |
| SHA-256 of the 4 untracked task files vs `main`'s tracked copies | pass | all four identical |
| Substrate searches across `apps/server/lib`, `packages/*/lib` — `SecretProvider\|secretProvider\|secret_manager\|secretManager`, `resolveSecret\|getSecret\|fetchSecret\|readSecret\|secretRef`, `vault\|awskms\|AWSSecretsManager\|keyvault\|GoogleSecretManager`, `custodyMode\|secretStrategy\|substrate` | pass | **no match in every family** — HIGH 2's premise re-verified independently |
| `rg -in 'ssh\|deploy_key\|deployKey\|ed25519\|git_?key' infrastructure/` | pass | **no match** — the negative half of F-2 |
| `git ls-tree -r --name-only 289f1d3 -- docs/engineering/dispatch/tasks/design-adr-0018-amendment/` | pass | 4 files tracked on `main`, all byte-identical to the worktree's untracked copies |
| ADR line count | pass | 580 → **811** |
| `.decisions/**` unmodified | pass | 14 objects; `PROHIBITED_PATHS` respected; no write attempted |
| No Docker or Compose command issued | pass | confirmed against this lane's command history — not `info`, `ps`, `logs`, `config`, nor any mutating one. Compose files and Terraform were read as text |
| A3 reachability runtime probe | **NOT_RUN** | **Deliberately.** Requires the probe `876c6b97:152-156` assigns outside this lane's scope, and would need Docker. Gap A4 stays **UNVERIFIED** and no probe is claimed |

## Evidence (revision-pinned)

```yaml
EVIDENCE_REVISION: 289f1d3
BUILD_COMMAND: n/a — documentation/design artifacts only
SERVE_OR_RUN_COMMAND: n/a — nothing was built or served
ENVIRONMENT / BASE_URL: n/a
ARTIFACTS:
  - docs/adr/0018-per-product-git-credentials.md                              (580 → 811 lines, modified at HEAD 289f1d3, uncommitted)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-3.md
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata-3.yaml
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/report.md         (this file)
  - /private/tmp/adr-a2-safety/adr-a2-prelocal.patch                            (pre-flight patch, 34 993 bytes, retained)
  - /private/tmp/adr-a2-safety/taskdir-backup/                                  (pre-flight backup of the untracked task dir, retained)
```

Evidence was produced against the worktree at HEAD `289f1d3`. **No commit was made** (the dispatch
forbids it), so the change is an uncommitted working-tree modification and a reviewer must read the
worktree and `git diff` rather than a commit.

## Documentation updated

```text
docs/adr/0018-per-product-git-credentials.md
```

No other documentation was modified. `docs/engineering/WORK_STATE.md` and
`docs/engineering/dispatch/LANES.md` were read only.

## Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: PRECISION
MODEL_USED: opencode/space-bunny-free
REASONING_EFFORT: n/a
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

## Unresolved issues and blockers

**No blocker.** `RESULT: DESIGN_REVISION_COMPLETE`.

1. **F-1 — needs the Manager, and possibly the human. `CONTRADICTION` touching recorded security
   architecture.** HIGH 1's absolute wording ("SHIP IT never holds key bytes … and asks the manager
   for the material at push time") is still present at `9417f8bf:210-211` and `876c6b97:20-21`. The
   ADR now cites both as authority while contradicting them. Both files are `.decisions/**`, which is
   `PROHIBITED` to design lanes and `created_by: orchestrator-main` throughout. **Question for the
   Manager: will you amend those two records, or record a scope note against them?** Note
   `9417f8bf:116-119` already contains the *correct* same-uid reasoning, so those records are
   internally inconsistent and the fix is a wording scope, not an architecture change. This lane
   cannot write them and did not attempt it.

2. **G-b — the transport-time same-uid exposure has no owning follow-up action.** It is recorded as a
   property of the accepted architecture (ADR §Amendments A2 scoping subsection and §Accepted risks
   A4's second consequence) but is **not** one of the four accepted risks, so `876c6b97:147-156`'s
   assignments — gap A2 to `design-agent`, gaps A3/A4 to implementation/deployment authority — do not
   reach it. **Surfaced for the Manager to route; deliberately not self-assigned.** Creating a fifth
   accepted risk here would have misstated what the owner was asked and answered.

3. **G-d — the review report is absent and the finding set was reconstructed.** `report.md` does not
   exist; the directory held only the four revision files. Both HIGH findings and G-17 were
   **independently re-verified against the ADR text and the source decisions before being acted on**,
   and the reconstruction is stated in `design-revision-3.md` §0 rather than presented as if the
   report had been read. **If the original report surfaces and contains findings beyond the 2 HIGHs
   and G-17, this revision does not address them** and a further correction may be needed.

4. **F-3 — the report-loss pattern is now three deep in one work item and it is a process defect, not
   bad luck.** A review report is the only durable record of *why* a change was rejected; losing it
   forces the next lane to reconstruct findings from the artifact, which is exactly how a finding
   gets half-addressed. Recommend the Manager persist review output to disk **before** dispatching a
   correction task, and consider the persistence step part of the review lane's contract.

5. **F-4 — isolation pre-flights are incomplete.** They check tracked modifications but not untracked
   files, which blocked the fast-forward a second time after the stash. Recommend the pre-flight
   compare untracked paths against the target commit too.

6. **Not a blocker, recorded so absence is not read as completion:** §Known gaps' "rotation described
   in product scope in two places" remains open by design (G-e); A3 reachability remains UNVERIFIED
   and needs the runtime probe assigned outside this scope (G-c).

## Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - "Independent design review of ADR0018-A2-REV3 — the next gate. reviewed_by/reviewed_at are null and this lane does not approve its own work."
  - "design-reviewer lane for the keys / mobile rev-5 items — no path overlap with this lane."
PROHIBITED_PARALLEL_WORK:
  - "Any lane writing docs/adr/0018-per-product-git-credentials.md — OWNED_PATHS overlap; serialise."
  - "Any lane amending 9417f8bf or 876c6b97 — .decisions/** is Manager-owned; this lane's F-1 must be routed first."
  - "Mobile lane copy edits based on this ADR's §Amendments A2 text — read the revised scoping subsection first; the 'stays in the keychain' / 'never holds' constraint has changed (add_product_page.dart:542, :1038)."
```

## Cleanup confirmation

- [x] **All processes started by this lane are stopped.** None were started. No server, no container,
      no long-lived process.
- [x] **Temporary artifacts: RETAINED DELIBERATELY, and reported.** `/private/tmp/adr-a2-safety/`
      holds the pre-flight patch, the two pre/post ADR copies, the empty `local-vs-main.diff`, and the
      task-directory backup. These are the **evidence** for the pre-flight finding and are listed under
      **Evidence**. They are outside the repository and outside the change; retained so the finding
      stays verifiable. Say the word and they can be deleted.
- [x] **`git stash@{0}` RETAINED, not dropped** — recorded under Evidence/pre-flight. Nothing was
      discarded; this is the third preservation copy of the uncommitted edit.
- [x] **No files modified outside `OWNED_PATHS`.** Verified against the dispatch's
      `OWNED_PATHS` / `PROHIBITED_PATHS`. `.decisions/**` (14 objects), every other ADR, all
      production source under `apps/**`, `packages/**`, `infrastructure/**`, and all QA artifacts are
      untouched.
- [x] **No Docker or Compose command was issued by this lane** — not `info`, not `ps`, not `logs`, not
      `config`, not any mutating one. This repository has already lost its QA database to a lane
      running `docker compose -f docker/compose.qa.yaml down -v --rmi local`; the rule was not tested.
      Compose files and Terraform were read as text with `rg`/`read`.

## Recommended next action

**`INDEPENDENT_DESIGN_REVIEW`** — dispatch `design-reviewer` against `ADR0018-A2-REV3` at HEAD
`289f1d3`, with the reviewer's checklist in `design-revision-3.md` §11 (HIGH 1 scoping, the nine-row
§Decision status table, G-17's commit-ordering argument, the new Terraform finding, and the pre-flight
stash disposition). F-1 should be routed to the Manager **in parallel**, since it is Manager-owned
and independent of the review's verdict.
