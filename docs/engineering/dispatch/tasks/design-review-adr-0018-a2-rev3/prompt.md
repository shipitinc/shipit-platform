# Subtask Prompt — design-review-adr-0018-a2-rev3 (first independent review of the A2 amendment)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-review-adr-0018-a2-rev3
TASK_TYPE: design-review
FEATURE: Add Product rebuild — ADR 0018 amendment A2, revision 3 (ADR0018-A2-REV3)
AREA: Independent, read-only review of the ADR amendment and its design artifacts
WORKTREE: read-only; canonical checkout at /Users/alkebut/air/shipit-platform
BRANCH: design/adr-0018-amendment @ 289f1d3 (producing worktree UNCOMMITTED — see below)
BASE_SHA: 289f1d3
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-review-adr-0018-a2-rev3/**   (your report)
READ_ONLY_PATHS: everything else, including every file under docs/adr/
PROHIBITED_PATHS:
  - docs/adr/**                          (including 0018 — read it, never write it)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**   (artifacts under review)
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, WORK_STATE.md, LANES.md
ACCEPTANCE_CRITERIA: |
  An independent verdict on ADR 0018 amendment A2 revision 3, focused on whether the ADR now
  distinguishes what is DECIDED from what is merely PLANNED, and whether its self-referential claims
  about its own acceptance are accurate.
VALIDATION_COMMANDS:
  - cd /Users/alkebut/air/shipit-platform && git rev-parse --short HEAD    # 08c7590
ROUTING_CLASS: PRECISION
```

## ⚠ THE REVIEW THAT CREATED THIS WORK WAS LOST — you are reviewing on reconstructed findings

**There is no report of the A2 review that returned `CHANGES_REQUIRED`.** The ADR lane found it
**absent** — the third lost report in this work item — and **reconstructed the finding set from the ADR
text**, then re-verified both findings independently before acting. It says so explicitly in its report.

**Consequence for you:** there is no review report to check its work against. **You are the first
independent reviewer of this artifact.** Do not treat the producing lane's account as the baseline.

Two findings it was asked to fix:

- **HIGH 1 — "SHIP IT never holds key bytes" contradicted the ADR's own transport-time retrieval clause.**
  `9417f8bf` chose A3: SHIP IT holds only a *reference* and asks the manager for the material **at push
  time**. Both clauses were present. It reports scoping them by **dimension** — never **stored** (the
  guarantee, and what excludes A2) versus **materialised transiently at transport time** (true, not a
  guarantee).
- **HIGH 2 — A3 custody was stated in the present indicative while no substrate adapter exists.** It
  reports adding a **§Decision status** section marking clauses Decided/Built with per-clause file
  evidence, **reusing the ADR's own existing idiom** rather than inventing one, and that **two clauses
  are only partly built**.

**Judge both fixes on their merits.** Verify the tense is now honest throughout, not just in the two
places it was raised — an ADR that fixes two sentences and leaves twenty present-tense claims about
unimplemented dependencies has not been corrected.

## Third finding it raised unprompted — G-17

The ADR **denied the existence of its own acceptance decision.** `docs/adr/0018-per-product-git-credentials.md`
`:16-21` and `:572-580` asserted no decision object recorded the acceptance, while
`.decisions/876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml` **did** — and `git log --diff-filter=A` proves it
landed in the **same commit (`5436a4d`)** that wrote the denial.

The lane reports it established the **timeline** and concluded the revision-2 verification was **sound at
the time** (13 objects, 48 minutes earlier), with the defect being *"writing a fact with a shelf life as
a standing claim."* It says so explicitly rather than calling it fabrication.

**Verify this yourself with `git log`.** Then judge: is "it was true when written" an acceptable answer
for an ADR that ships as a standing document? **An ADR is read years later by someone who does not know
when it was true.** If you disagree with the lane's framing, say so — this is exactly the judgement an
independent reviewer exists to make.

## Fourth finding — a gap's evidence was narrower than it looked

Gap **A4**'s evidence was `*.dart`-only and **hid a GCP Secret Manager already provisioned in this
repository's Terraform**, with `secretAccessor` already granted to the Cloud Run service account
(`modules/secrets/main.tf:23,31,39`; `modules/iam/main.tf:31-34`) — but **no deploy-key secret and no
runtime binding**.

**Verify this in the Terraform.** If true, it narrows A4 substantially: the substrate is not hypothetical
infrastructure, it is partially built infrastructure that the ADR does not mention. The lane reports the
accepted consequence is restated unchanged and **still four accepted gaps, none added**. Check that.

## Where revision 3 lives

Uncommitted in `/private/tmp/shipit-design-adr0018` (branch `design/adr-0018-amendment`, now fast-forwarded
onto `289f1d3`). The Manager copied the artifacts into the canonical checkout at
`docs/engineering/dispatch/tasks/design-adr-0018-amendment/`: `design-revision-3.md`,
`design-revision-metadata-3.yaml`, `report.md`. The ADR itself is **811 lines** in the worktree.

⚠ **Note the divergence from `main`.** `main`'s ADR is **580 lines**; the worktree's is **811**. The
amendment is **not committed**. Review the worktree's version — that is the artifact under review — and
record the fact that the ADR on `main` does not yet contain it.

⚠ There is also a **retained stash** at `stash@{0}` on that branch, labelled *"ADR0018 A2 rev1 local edit
(superseded by main 5436a4d)"*. The lane reports the local edit turned out to be **byte-identical to
main's version** (sha256 `9e5b4772`) and was therefore superseded, and that it **kept the stash rather
than dropping it**. **Verify that claim** — if the reconstruction of the reviewed state is wrong anywhere
in this work item, this is another place it could be hiding.

## Provenance correction the lane made to MY record

I told it the A2 amendment was merged as `6220951`. **That is wrong** — `6220951` is an `AGENTS.md` commit
that never touches this ADR; the A2 revision is **`5436a4d`**. And `876c6b97` is a **decision id, not a
commit**, which matters because G-17's entire argument is a commit-ordering argument.

**Check my other provenance claims too.** This work item has a documented history of a lane accepting a
Manager premise that turned out false, and of a Manager asserting an artifact was absent when it was not.

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a review lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- **READ-ONLY.** `docs/adr/**` is read-only including ADR 0018. Edit nothing except your own report
  directory. **Do not `stash`, `checkout`, `reset` or otherwise touch the worktree's git state** — you
  are reviewing, and the producing lane's retained stash is evidence.
- **You are independent.** The producer explicitly declined to approve its own work.
- **PERSIST YOUR FULL REPORT TO DISK** at
  `docs/engineering/dispatch/tasks/design-review-adr-0018-a2-rev3/report.md` before returning.
  **A review report has been lost three times in this work item, and the `APPROVE_CORRECTIONS` verdict
  authorising this morning's merge is still untracked on disk.** Do not be the fourth.
- **Search the domain's own vocabulary, not the requester's phrasing.** `docs/engineering/adr/` vs
  **`docs/adr/`** is the specific error that made **ADR 0018 itself** get declared non-existent — and
  this task is about reviewing that very ADR, so the trap is live. The product ADRs are in `docs/adr/`
  (21 of them, `0001`–`0021`); `docs/engineering/adr/` holds only three framework-distribution ADRs.
  Follow citations; enumerate with `glob`, not `ls` on a guessed path.
- **State explicitly what you did NOT review.**

## Settled — do not re-open

Nine Human Decisions are **RESOLVED**. Read the resolution blocks; cite them.

- **`9417f8bf` OPTION_C / A3** — external secret manager. **ADR `:85-88` SUPERSEDED**; **A2 permanently
  EXCLUDED** (the "never persisted to the durable record" clause still binds it); **the reference is now
  the most sensitive artifact SHIP IT holds**, making **G-7 REQUIRED**.
- **`898b07d0` OPTION_A** — split identity from registration. **ADR `:100-102` UPHELD.**
- **`79e860e2` OPTION_A** — destroy the manager handle, keep the row. **ADR `:113-114` SUPERSEDED.**
- **`ae1c1f79` OPTION_A** — **a substrate refusal creates NOTHING**; the precondition precedes any write.
- **`7b1bc8b7`** fail closed · **`4d2c6b81`** index into a new migration · **`27ea6536`** footer spec ·
  **`b869ec24`** server-side generation and storage.
- **`876c6b97` OPTION_A — the A2 acceptance itself, with four knowingly-open gaps.** **Read it in full.**
  Its four gaps are the yardstick for whether the ADR's tense matches what the human actually accepted.

## One finding the producing lane routed upward rather than fixing — judge whether it should have

**F-1:** HIGH 1's absolute wording *"never holds key bytes"* **also** appears in `9417f8bf:210-211` and
`876c6b97:20-21` — **Manager-owned decision files, therefore PROHIBITED to it.** So the ADR now cites
both decisions **while contradicting them**.

**Assess this.** The ADR's correction is correct in isolation, but it leaves the governing decisions
carrying the same absolute phrasing. Is that acceptable, or does it propagate the contradiction upward
into the record? **Say what you think should happen**, even though the answer is outside this lane's
scope.

It also surfaced **G-b:** the same-uid exposure moves from filesystem to process memory, and **no owning
follow-up exists** — it is not one of the four accepted risks. It surfaced rather than self-assigned.
**Judge whether that is the right call.**

## Report format

Report per `.agents/skills/aef-orchestrator/templates/subtask-report.md` with the `RESULT:` block
verbatim from `.agents/agents/design-reviewer.md`:

```
RESULT: DESIGN_REVIEW_APPROVED | DESIGN_REVIEW_CHANGES_REQUIRED | DESIGN_REVIEW_HUMAN_DECISION_REQUIRED
```

Include `CORRECTION_REQUIRED`, `HUMAN_DECISION_REQUIRED`, `INDEPENDENT_RISK_LEVEL`,
`RISK_LEVEL_AGREEMENT`. Carry exact provenance: reviewed HEAD, artifact paths, revision id, and the ADR
line count you reviewed.