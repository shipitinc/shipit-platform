# Subtask Report — design-correct-adr-0018-a2-4 (Design Revision 5)

**Persisted to disk before returning**, per the dispatch and because three review reports have been
lost in this work item. Revision 4's report was preserved byte-identical as `report-revision-4.md`
(sha256 `81db0f67…`, equal to `main`'s `report.md`) **before** this file was written.

---

```
RESULT: DESIGN_REVISION_COMPLETE

FEATURE:                    Add Product rebuild — ADR 0018 amendment A2, revision 5
BRIEF_ID:                   (none — no Design Brief exists for this work item at any revision;
                             recorded as a lifecycle gap, not fabricated)
REVISION_ID:                ADR0018-A2-REV5
REVISION_NUMBER:            5
BRANCH:                     design/adr-0018-amendment
BASE_SHA:                   289f1d3 as dispatched → fast-forwarded to 1c3f5ad per pre-flight
HEAD_SHA:                   1c3f5ad  (UNCHANGED by this lane — no commit, no rebase, no push)
REVERIFIED_AGAINST:         main 762e5cd  (dispatch named 1c3f5ad; main had advanced two further)

OWNED_PATHS:
  - docs/adr/0018-per-product-git-credentials.md      ← the ONLY file written outside the task dir
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**

READ_ONLY_PATHS:
  - docs/adr/** except 0018-per-product-git-credentials.md
  - apps/**, packages/**, infrastructure/**, docker/**, .github/**
  - .decisions/**
  - docs/engineering/WORK_STATE.md, docs/engineering/dispatch/LANES.md

PROHIBITED_PATHS:
  - docs/adr/** except 0018-per-product-git-credentials.md      — none written
  - .decisions/**                                              — none written; three corrections REPORTED
  - any production source                                      — none written

ARTIFACT_PATHS:
  - docs/adr/0018-per-product-git-credentials.md                            (999 → 1212 lines, UNCOMMITTED)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-5.md
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata-5.yaml
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/report.md
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/report-revision-4.md   (preservation copy)

RISK_LEVEL: 3
RISK_RATIONALE:
  Unchanged from revisions 1–4 and from the re-reviewer's independent assessment
  (INDEPENDENT_RISK_LEVEL: 3, RISK_LEVEL_AGREEMENT: YES). The level describes the change being
  recorded, not the accuracy of the prose. (1) The ADR amends recorded architecture on a security
  boundary — where a private key capable of authorising repository WRITE access is held, and what
  "revoked" means. (2) It changes a core workflow: revocation acquires a ShipIt-side action the ADR
  previously said was unnecessary, plus a runtime dependency that can block the credential path.
  (3) It depends on enforcement that lives elsewhere and is still partly absent at main 762e5cd: no
  transport host-key enforcer, no secret-manager adapter, NO HANDLE-DELETION CODE, registration not
  wired to a connectivity check, and the UI's deploy key still a client-side mock the register flow
  never transmits. (4) It carries accepted risks on that boundary — three remain recorded after the
  owner's retirement of A1. Revision 5 retires nothing of its own authority, adds no risk, and closes
  no remaining one. The A1 retirement is NOT a disclosure and does not lower the level: it is a change
  to what is carried on a security boundary, recorded by the owner, and the architecture is unchanged.

CHANGELOG:
  H-R1  FIXED at all five ADR sites (:180 :224 :959 :1016 :1111) → 9417f8bf:159-160, with
        9417f8bf:96-97 named as the independent second witness. Decision-object half REPORTED (§11.1),
        NOT written. design-revision-4.md and -metadata-4.yaml left unaltered (DECLINED, §11.3/§11.4).
  H-R2  FIXED, then superseded by the retirement. The §Accepted risks preamble no longer says
        "Nothing here is closed"; it states the count, attributes the retirement to the owner, records
        that two prior lanes were right to decline, and states what retirement does not reach.
  H-R3  All three fixed (:219→:284/:289, :37-40→:65-68, :137-139→:188-190) AND every remaining
        internal citation re-derived from the live file after each edit.
  NEW   Five distinct broken references the re-reviewer had not reported (§2.2 rows 5–9).
  NEW   The standing re-verification obligation revision 4 claimed to have written and never did.
  NEW   F-9 corrected and strengthened: the register flow never transmits the key and violates A1's
        scope invariant via repositoryId: productId.
  NEW   Title decline recorded with its reason; §Known gaps re-headed.
  A1    RETIRED 2026-10-07 by the repository owner, in place, with date, authorising decision and
        the re-verified evidence. A2, A3, A4 NOT retired — THREE remain recorded.
  NEW   §Status `reviewed_by` rationale aligned to the durable form; the contingent prescription
        removed. M-R1's ADR half fixed; the `.decisions/876c6b97` half reported (§11.2).

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - H-R1, H-R2, H-R3, M-R1, M-R2, M-R3, L-R1, L-R2, L-R3 — all disposed (§3 of revision 5)
    - Re-derive the referential class across the WHOLE ADR — mechanical extraction of all 138 tokens,
      every external range resolved at the anchor the document declares
    - Retire A1 with date, authorising decision, evidence; do NOT retire A2/A3/A4
    - Update the identifier-collision table for three readings of "A1"
    - Record what remains open: no code destroys a secret-manager handle
    - Record that the retirement is the OWNER'S, not a design lane's
    - Report, do not write, the .decisions/9417f8bf correction
    - Align §Status reviewed_by wording to the stronger reason
    - Correct §Known gaps if it understates F-9
    - No Docker/Compose command; both stashes verified by label and untouched
    - Full paths, never basenames; line numbers re-read after every edit
  REQUIREMENTS_GAPS:
    - G-a  9417f8bf:113/:140/:210 and 876c6b97:20 still carry the pre-correction absolute —
           Manager-owned; append-only text in §11.1 and §11.2
    - G-b  the transport-time same-uid exposure is filed in §Known gaps and still has NO OWNER
    - G-c  A3 reachability remains UNVERIFIED — needs a runtime probe; no Docker command was issued
           and no probe is claimed
    - G-g  F-9 is now THREE defects (mock key; never transmitted; repositoryId: productId violating
           A1's scope invariant) plus F-10's stale doc comments — all production source
    - G-i  design-revision-metadata-4.yaml:333 carries the same non-existent WORK_STATE.md:326-327
           relay; retained as history, reported §11.4
    - G-j  the ff-only pre-flight fails against this worktree (six untracked files shadow main
           content) — F-16
    - No formal Design Brief exists for this work item at any revision; the dispatch header served as
       one. Recorded, not fabricated.

DESIGN_SYSTEM_COMPLIANCE: PASS (not applicable — no UI authored; no interface added, removed or
  restyled. Revision 5 tightens the binding copy constraint on the mobile lane: no copy may present
  that screen's key as installable, because the register flow never transmits it at all.)
UX_ACCESSIBILITY_SCORE: PASS (not applicable — the accessibility surface of this artifact is the ADR.
  It improves in the property that matters for a document a future reader must trust without the
  author's session: every cross-reference now resolves, self-referential citations carry a section
  name beside the line number so growth degrades them to stale rather than wrong, and the two places
  that misled — a wrong pointer and a section label its own body contradicted — are corrected.)
IMPLEMENTATION_FEASIBILITY: MEDIUM — unchanged. A3 is decided, provisioned in this repository's
  Terraform, NOT wired to the credential path, and UNVERIFIED for reachability. Revision 5 improves
  what an implementer inherits: two citations that had drifted on main are re-verified and the drift
  is recorded; the A1 retirement is unambiguous in the heading; the register-flow defect is recorded at
  its real severity rather than as mock-key hygiene.

DISCOVERIES:
  F-15 WORKFLOW_IMPROVEMENT — the axis list is the deliverable, and a producing lane cannot be the
       only auditor of its own completeness. Revision 4 stated six axes; the reviewer had to find a
       seventh. The clause is not "state an axis list" but "state one AND have it independently
       re-run, with both counts compared". This entire class is one script.
  F-16 WORKFLOW_IMPROVEMENT — a --ff-only pre-flight can fail against untracked files that shadow
       committed content; the safe response is to hash them and back them up, not delete them.
  F-17 PROJECT_FACT — a wrong pointer propagates further than the document it came from: five ADR
       sites, the revision that prescribed the note, the applied note inside a resolved human decision
       object, and that object's sibling. .decisions/** is where a reader is MOST likely to land.
  F-18 PROJECT_FACT — a claim about your own artifact can be as false as one about anyone else's.
       Revision 4 stated §Known gaps records the standing obligation; grep returned nothing.
  F-19 PROJECT_FACT — the Add Product register flow never transmits the deploy key and passes
       repositoryId: productId, violating A1's scope invariant in the shipping build.
  F-11 PROJECT_FACT + CONTRADICTION — A1 retired by the owner 2026-10-07; three risks remain; the
       other half of the revocation clause stays open so the retirement cannot launder it.

KNOWLEDGE_PERSISTED:
  Persisted INSIDE OWNED_PATHS (the ADR and revision 5): F-17's propagation map, F-18, F-19, the A1
  retirement record, and the standing re-verification obligation.
  REPORTED, NOT PERSISTED (above this lane's authority): F-15 and F-16 (framework/workflow — route to
  independent review); the three .decisions/** corrections (§11.1, §11.2 — Manager-owned, PROHIBITED
  here); the owner for the same-uid exposure.

BLOCKERS: none

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```

---

# 1. The number you asked for

**MY OWN COUNT of internal `:NNN` / `file:line` cross-references found broken: NINE distinct broken
references across FOURTEEN citation sites.**

**Reported (H-R3): three distinct pointers at four sites. Including H-R1: five. Mine alone: five
distinct pointers at ten sites.**

| # | Broken reference | Sites | Correct pointer | Reported? |
|---|---|---|---|---|
| 1 | `9417f8bf:116-119` | **5** (ADR `:180`, `:224`, `:959`, `:1016`, `:1111`) | `:159-160` + `:96-97` | H-R1 |
| 2 | `:219` | 1 (`:509`) | `:284` / `:289` | H-R3 |
| 3 | `:37-40` | 1 (`:1141`) | `:65-68` | H-R3 |
| 4 | `:137-139` | 1 (`:1143`) | `:188-190` | H-R3 |
| **5** | **`:96-99` used OUTSIDE §Amendments** | **2** (`:711`, `:879`) | §Decision → Specifics `:488-494` | **no** |
| **6** | **`876c6b97:53-55`** | 1 (`:909`) | `:54-56` (phrase at `:55`) | **no** |
| **7** | **`WORK_STATE.md:326-327`** | 1 (`:1176`) | `876c6b97:117` + `design-revision-2.md:400` | **no** |
| **8** | **`cloudbuild/main.tf:72-76`** | 1 (`:934`) | `:73-76` | **no** |
| **9** | **`schema_bootstrap.sql:98-100`** — correct at anchor, moved on `main` | 2 (`:368`, `:645`) | `:112-114`; `verify_schema_bootstrap.sh:91`→`:130` | **no** |

**#7 is the one that matters most.** `WORK_STATE.md:326-327` never resolved **at any of that file's
fifteen revisions** — a `git rev-list --all` sweep for the relay returns nothing — and the defect
**predates amendment A2**, entering with `5436a4d` and surviving three revision passes unexamined.
**#9 is the one that should worry a reviewer most**: all three "both paths agree" citations are correct
as of their stated anchor, and on `main` today one resolves, one lands on the wrong line and one lands
on a blank line. That is this ADR's own hazard reached by drift rather than error, which is worse
because nothing announces it.

**And the honest self-indictment: my own edits broke three anchors I had just written** (`:52-55`,
`:152-154`, `:430-436` → re-derived to `:65-68`, `:188-190`, `:488-494`). I caught them only because
the sweep re-runs from the live file after every edit. That is the entire reason H-R3 happened to
revision 4, and it will happen again.

# 2. The exact `.decisions/9417f8bf` correction for you to apply

**Reported, not written.** `.decisions/**` is PROHIBITED to me. Full YAML in revision 5 § 11.1; the
substance:

The existing scope note at `:266-268` reads *"WHY THIS OBJECT IS NOT INTERNALLY CONSISTENT. **`:116-119`
already contains the CORRECT reasoning** — it rejected A1 precisely because 'permissions do not defend
against a same-uid process — which is the git transport'."* **`:116-119` contains no such text.**

Append a **second dated block at the end of the file**. Do not edit the existing note. The correction:

> `# :116-119 is WRONG — it is the tail of the "Where the guarantee lives" assessment plus the head of`
> `# the "Insider/backup exposure" dimension. The correct citations are:`
> `#   :159-160  inside OPTION_A's implications — "…a stolen volume, a backup or a \`docker cp\` yields`
> `#             the key in cleartext, and permissions do not defend against a same-uid process — which`
> `#             is the git transport."`
> `#   :96-97    an INDEPENDENT second statement of the same property, recorded as a quantitative metric`
> `#             rather than prose — "A1 filesystem-only protection against a same-uid process / none —`
> #:             the git transport runs as the same uid that would read the file". :96-97 is the stronger`
> `#             witness, because it is a stated measurement.`
> `# THE SUBSTANCE OF THE NOTE IS UNCHANGED AND CORRECT — the object does contain the correct same-uid`
> `# reasoning, so it is internally inconsistent with its own "SHIP IT never holds key bytes" absolute,`
> `# and the reconciliation stands. Only the pointer was wrong.`

`876c6b97:194-201` is **OPTION_D's** description and implications — the same-uid text is not there, and
revision 4's § 1.4 decline row that called it "correct… and cited **as** the source of the same-uid
reasoning" is wrong. Revision 4 is retained unaltered; revision 5 § 2.5 records it.

**A second, separately-needed append: `.decisions/876c6b97`** — `:122-123` still says *"independent
design review of the amendment has still never happened"*, which two reviews have now made false.
Exact text in revision 5 § 11.2.

# 3. Three accepted risks are now recorded — and which

**THREE: A2, A3, A4.** A1 is **RETIRED 2026-10-07 by the repository owner**, retired in place with the
date, the authorising decision and the evidence the owner was shown — all five closure ranges re-read at
`main 762e5cd` and still resolving. A2 (host-key transport enforcer), A3 (unenforced "local only" scope)
and A4 (unprobed secret-manager reachability) are **untouched and open**.

Recorded as the substance of why the retirement is honest: **A1 was the *resurrection* half of the
revocation clause. The other half — no code destroys a secret-manager handle — is still unimplemented**
(re-verified at `762e5cd`), so revocation remains one-sided in practice. That is `79e860e2`'s territory,
was never an accepted risk, and the retirement did not close, accept or transfer it. It is now stated in
**five** ADR locations so a closed gap cannot launder an open one.

The identifier-collision table now records **three** readings of "A1": a substrate option (live), a
retired risk id, and the historical risk id.

# 4. Files touched

```
docs/adr/0018-per-product-git-credentials.md                                       (M, 999 → 1212)
docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-5.md
docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata-5.yaml
docs/engineering/dispatch/tasks/design-adr-0018-amendment/report.md
docs/engineering/dispatch/tasks/design-adr-0018-amendment/report-revision-4.md
```

Inside `OWNED_PATHS`. **`.decisions/**` untouched — `git status --short .decisions/` is empty, 14
objects. **No production source.** **No commit, no push.** HEAD is `1c3f5ad`, unchanged by this lane.

**I ran NO Docker or Compose command of any kind** — not `info`, not `ps`, not `logs`, not `config`,
not any mutating one. This repository has already lost its QA database to exactly that. The rule was
not tested.

**Both stashes are exactly as found**, verified **by label substring** rather than index; the ADR stash
is byte-identical to `main`'s ADR (`9e5b4772…`, both 580 lines). I issued no `stash`, `checkout`,
`reset`, `commit`, `push` or `clean`.

**One thing you should know about the pre-flight:** `git merge --ff-only 1c3f5ad` **failed**, because
six untracked files in the task directory were byte-identical copies of what already landed on `1c3f5ad`.
I proved that by `shasum` against `git show 1c3f5ad:<path>` for all six, backed them up outside the
repository, then fast-forwarded. **Nothing was lost or rewritten** — but a lane obeying that pre-flight
blindly would have had to choose between refusing to start and deleting six unchecked files.

## Evidence (revision-pinned)

```yaml
EVIDENCE_REVISION: 1c3f5ad            # worktree HEAD; the ADR amendment is UNCOMMITTED (1212 lines)
BASE_AS_DISPATCHED: 289f1d3
REVERIFIED_AGAINST: main 762e5cd      # 08c7590 is an ancestor; all five A1-closure ranges re-read there
BUILD_COMMAND: n/a — documentation / architecture record only
SERVE_OR_RUN_COMMAND: n/a — nothing built, served or executed
ENVIRONMENT / BASE_URL: n/a
ARTIFACTS:
  - /private/tmp/shipit-design-adr0018/docs/adr/0018-per-product-git-credentials.md  (1212 lines, UNCOMMITTED)
  - …/design-adr-0018-amendment/design-revision-5.md   …/design-revision-metadata-5.yaml
  - …/design-adr-0018-amendment/report.md              …/report-revision-4.md  (sha256 81db0f67…)
  - .decisions/9417f8bf-…yaml  (281 lines, read IN FULL)
  - .decisions/876c6b97-…yaml  (200 lines, read IN FULL, incl. all five follow_up_actions)
  - .decisions/ae1c1f79-…yaml  (:8-11 precedent citation, read)
  - docs/engineering/dispatch/tasks/design-rereview-adr-0018-a2-rev4/report.md   (MY FINDING SET, in full)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-4.md (753 lines, read in full)
  - stash@{1} docs/adr/0018-per-product-git-credentials.md  (sha256 9e5b4772… — resolved BY LABEL, INTACT)
```

## Documentation updated

```
docs/adr/0018-per-product-git-credentials.md
docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-5.md
docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata-5.yaml
docs/engineering/dispatch/tasks/design-adr-0018-amendment/report.md
docs/engineering/dispatch/tasks/design-adr-0018-amendment/report-revision-4.md
```

## Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: PRECISION
MODEL_USED: opencode/space-bunny-free
REASONING_EFFORT: n/a
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

## Recommended next action

A **focused re-review of revision 5** against the nine broken references and the A1 retirement — not a
third full W1–W6 sweep, which the re-reviewer already ran and confirmed at eleven with no twelfth, and
which revision 5 did not alter.

Review in this order: **(1)** rows 5–9 of the table in §1 above, which nobody had reported — if a tenth
exists, this sweep is incomplete; **(2)** the four `:NNN` anchors I re-anchored in my own edits, verified
in the **final 1212-line** file; **(3)** the A1 retirement — three remain, the revocation clause's other
half is recorded as open, and it is attributed to the owner; **(4)** the judgement most worth
challenging here, that I declined to edit `design-revision-4.md` (§11.3).

In parallel, and none of it blocked by me: apply §11.1 and §11.2 to `.decisions/**`; route the Add
Product register-flow defects to a lane owning `add_product_page.dart`; and route an owner for the
transport-time same-uid exposure.