# Subtask Prompt — design-rereview-adr-0018-a2-rev4

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-rereview-adr-0018-a2-rev4
TASK_TYPE: review            # focused re-review, read-only
FEATURE: Add Product rebuild — ADR 0018 amendment A2, revision 4
WORKTREE: read-only; inspect the producing worktree /private/tmp/shipit-design-adr0018
BASE_SHA: 289f1d3
HEAD_SHA: 1c3f5ad   (producing worktree is UNCOMMITTED; artifacts now on main at af8e30f)
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-rereview-adr-0018-a2-rev4/**   (your report)
READ_ONLY_PATHS: everything else, including every file under docs/adr/
PROHIBITED_PATHS:
  - docs/adr/**  including 0018  (read only — you are reviewing, not editing)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**   (artifacts under review)
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, WORK_STATE.md, LANES.md
ACCEPTANCE_CRITERIA: |
  Focused re-review of revision 4 — chiefly whether the SWEEP was complete, which the producing
  lane itself nominated as the question that matters most.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-design-adr0018 && wc -l docs/adr/0018-per-product-git-credentials.md
ROUTING_CLASS: PRECISION
```

## ⚠ THE ONE QUESTION THAT MATTERS MOST — the producing lane says so itself

> *"The real question is not whether eleven is right but whether **twelve or thirteen exist**. Re-run
> W1–W6 independently; a higher count means the sweep is incomplete, which is the failure mode that
> produced this revision."*

The lane reports its sweep found **ELEVEN** unmarked superseded sites where the review had reported
**four**, using six greps as axes: **W1** per-product scope · **W2** custody · **W3** rotation · **W4**
revocation · **W5** key-count arithmetic · **W6** reference-name format. Each hit was adjudicated as
marked / quoted-history / correct-as-written / **unmarked-and-normative**, with declines recorded with
reasons in revision §1.4.

**Re-run W1–W6 yourself and count independently.** If you find more, the sweep was incomplete and that
is your BLOCKER. If you find fewer, **check whether the lane's adjudication was too permissive** —
"quoted-history" is the category most likely to hide a live normative claim.

**Also check §1.4's declined hits.** The lane states: if a declined hit should have been fixed the sweep
is over-cautious; if a declined hit was right, the omissions are accounted for. **Audit that reasoning
directly.**

## The six findings the review required, all claimed applied

`docs/engineering/dispatch/tasks/design-review-adr-0018-a2-rev3/report.md` is your baseline:
**B-1, H-1, H-2, H-3, M-1…M-4, L-1, L-2.** Ten in total, all claimed fixed.

- **H-1** was re-grounded on `repository_credential.dart:61-122` (the field list — **no private-key
  field**) with `:14-15`/`:70-71` named as stale and **explicitly not the evidence**. **Verify that
  re-grounding against source** — it is the change most likely to be wrong, because it swaps the cited
  evidence for different evidence.
- **H-2**'s §Positive bullet got **substance corrected, not just a marker** — the lane says that bullet
  was *arguing in favour of the design from a premise the document had abandoned.* **Check whether the
  corrected argument actually holds.**
- **M-1**'s added UI row **surfaced a new real defect**: `add_product_page.dart:126-138` renders a
  **client-side mock** deploy key, so **no server-issued public half reaches the UI** (F-9). The lane
  marked it *partly built* rather than *not built*. **Verify that reading and that distinction.**
- **M-3** — `570bb640` cited as a commit, `git log` fails; it is a **decision object**. **Verify fixed.**
- **M-4** — verified on `main` `c6f301d` that `08c7590` made the mint **insert-only in both tiers**.

## ⚠ S-6 — G-17's own defect class, reproduced by the revision that fixed G-17

Revision 4 found that revision 3's §Status claimed the amendment *"has never been independently
reviewed"*, **with a prescription attached** — and that this is **false**: `git ls-tree -r main` returns
the rev-3 review report, `DESIGN_REVIEW_CHANGES_REQUIRED`, `REVIEWED_HEAD: 289f1d3`. It fixed the claim
while **preserving** the load-bearing point (`reviewed_by` still null, because `CHANGES_REQUIRED` is not
a signature).

**Scrutinise this hardest.** It is a correction *about review status*, and the lane got the git argument
right. **But ask whether `reviewed_by: null` is still the right state now that revision 4 exists and has
been reviewed — including by you.** Also check the §11 note text says the same thing, because a scope note
that contradicts its own document is the class of defect this ADR is being corrected for.

## ⚠ M-4's authority line — the judgement most worth challenging

The lane closed A1's **exposure** (verified, with citations) but **deliberately did NOT retire the
accepted risk or re-count**: four risks remain four, on the reasoning that closing an accepted risk
changes what the owner accepted, and *"a lane doing it unilaterally would be this revision's own defect
class in the other direction."*

**Take a position.** Is that the right boundary, or is it an unregistered refusal to close an item that
is now verifiably closed? The ADR reviewer explicitly nominated this as the judgement most worth
challenging. Note the practical stakes: **`20261006150645000` reaching a deployed database**, and the
other half of the revocation clause — no code destroys a secret-manager handle — **remains
unimplemented**, so revocation is still one-sided in practice.

## Verify the Manager's applied work

Two **append-only dated scope notes** were applied by the Manager to `.decisions/**` — to `9417f8bf`
and `876c6b97` (per the lane's §11) at `1c3f5ad`, and to `27ea6536` (per the keys lane's G-19) at
`af8e30f`. **Audit all three.** They are Manager edits to resolved human decisions, the most sensitive
edit class here. Check that no resolution rationale was rewritten, no decision was re-opened, and no
accepted-risk count changed. The `876c6b97` and `27ea6536` notes carry `updated_at` changes with inline
comments — those are the only mutations above the marker and must be the only ones.

**Judge their content, not just their append-only-ness.** In particular the framing claim that *what
`27ea6536` overruled was the lane's **conclusion**, not its **observation**, and the owner was entitled to
reverse it.* If that is wrong, the note misrepresents a human decision.

## Where the artifact lives, and the two facts to verify

The ADR itself is **999 lines in the worktree**, uncommitted; **`main`'s is still 580** — verify both, and
record that the amendment is not yet committed. Artifacts `design-revision-4.md`,
`design-revision-metadata-4.yaml` and `report.md` are **now on `main`** at `af8e30f`.

⚠ **Two stashes exist and BOTH must be left exactly as found** — the renumbering is itself a trap:

```
stash@{0}  On design-correct-addproduct-mobile:  rev5-uncommitted-identical-to-16cd497
stash@{1}  On design/adr-0018-amendment: ADR0018 A2 rev1 local edit (superseded by main 5436a4d;
           sha256 9e5b4772) -- preserved, do not drop blindly
```

The producing lane reported the ADR stash as `stash@{0}`; it was `stash@{1}` because a **concurrent lane
renumbered the stack**. **Verify by label, never by index.** Confirm the ADR stash's contents are
byte-identical to `main`'s ADR (`9e5b4772…`) — if any reconstruction is wrong in this work item, this is
where it could hide. **Do not drop, pop, apply or modify either stash.**

## Do NOT re-open

Nine Human Decisions are RESOLVED. `9417f8bf` **OPTION_C / A3** (`:85-88` SUPERSEDED, A2 permanently
EXCLUDED, G-7 REQUIRED), `898b07d0` **OPTION_A** (`:100-102` UPHELD), `79e860e2` **OPTION_A** (`:113-114`
SUPERSEDED), `ae1c1f79` **OPTION_A** (a refusal creates **nothing**), `7b1bc8b7`, `4d2c6b81`, `27ea6536`,
`b869ec24`, `876c6b97`. Read `876c6b97` in full — **its four knowingly-open gaps are the yardstick for
whether this ADR is honest.**

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a review lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- **READ-ONLY: `docs/adr/**` including ADR 0018.** Edit nothing except your own report directory.
- **Do NOT stash, checkout, reset or otherwise touch the worktree's git state.** Both stashes are evidence.
- **Verify stashes by LABEL, not index.** Indexes shift under concurrent lanes.
- You are independent. The producing lane explicitly declined to approve itself.
- **PERSIST YOUR FULL REPORT TO DISK** at
  `docs/engineering/dispatch/tasks/design-rereview-adr-0018-a2-rev4/report.md`.
- **Search the domain's own vocabulary.** `docs/engineering/adr/` vs `docs/adr/` is the specific error
  that made ADR 0018 itself get declared non-existent. Use `git log --all --diff-filter=A -- <exact
  path>` and glob full paths, never basenames — that is how a false premise reached a dispatch here.
- **State explicitly what you did NOT review.**

## Report format

Per `.agents/skills/aef-orchestrator/templates/subtask-report.md`, `RESULT:` block verbatim from
`.agents/agents/design-reviewer.md`:

```
RESULT: DESIGN_REVIEW_APPROVED | DESIGN_REVIEW_CHANGES_REQUIRED | DESIGN_REVIEW_HUMAN_DECISION_REQUIRED
```

Include `CORRECTION_REQUIRED`, `HUMAN_DECISION_REQUIRED`, `INDEPENDENT_RISK_LEVEL`,
`RISK_LEVEL_AGREEMENT`, and lead with **your own independent W1–W6 count.**