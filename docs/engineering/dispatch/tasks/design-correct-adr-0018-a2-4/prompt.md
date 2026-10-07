# Subtask Prompt — design-correct-adr-0018-a2-4 (revision 5: referential integrity + A1 retirement)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-correct-adr-0018-a2-4
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — ADR 0018 amendment A2, revision 5
WORKTREE: /private/tmp/shipit-design-adr0018
BRANCH: design/adr-0018-amendment
BASE_SHA: 1c3f5ad   (artifacts now on main at caed6bb; ADR itself still uncommitted)
OWNED_PATHS:
  - docs/adr/0018-per-product-git-credentials.md      ← the ONLY file you may write outside your task dir
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**
READ_ONLY_PATHS:
  - docs/adr/** — every other ADR
  - apps/**, packages/**, infrastructure/**, docker/**, .github/**
  - docs/engineering/WORK_STATE.md, docs/engineering/dispatch/LANES.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - docs/engineering/dispatch/tasks/design-review-*/**, design-rereview-*/**
PROHIBITED_PATHS:
  - docs/adr/** except 0018-per-product-git-credentials.md
  - .decisions/**                       (Manager-owned — see §1; report, do not write)
  - any production source
ACCEPTANCE_DRITERIA: |
  ADR revision 5 closing the three HIGH referential-integrity findings, plus the human-authorized
  retirement of accepted risk A1.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-design-adr0018 && wc -l docs/adr/0018-per-product-git-credentials.md
ROUTING_CLASS: PRECISION
```

## Isolation pre-flight

```bash
cd /private/tmp/shipit-design-adr0018
git branch --show-current    # design/adr-0018-amendment
git merge --ff-only 1c3f5ad
git rev-parse HEAD
git stash list               # BOTH entries must survive — verify BY LABEL, not index
```

⚠ **Two stashes exist and both are evidence. Verify by LABEL, never by index** — indexes shift under
concurrent lanes:

```
stash@{0}  On design-correct-addproduct-mobile: rev5-uncommitted-identical-to-16cd497
stash@{1}  On design/adr-0018-amendment: ADR0018 A2 rev1 local edit (superseded by main 5436a4d;
           sha256 9e5b4772) -- preserved, do not drop blindly
```

Confirm the ADR stash is byte-identical to `main`'s ADR (`9e5b4772…`). **Do not drop, pop, apply or
modify either.**

## Your finding set

`docs/engineering/dispatch/tasks/design-rereview-adr-0018-a2-rev4/report.md`

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
REVISION_ID: ADR0018-A2-REV4
BLOCKERS: none (0)      HIGH: 3
CORRECTION_REQUIRED: YES      HUMAN_DECISION_REQUIRED: NO
INDEPENDENT_RISK_LEVEL: 3      RISK_LEVEL_AGREEMENT: YES
```

**⚠ THE CENTRAL FINDING — your sweep swept the wrong axis.** You found eleven unmarked superseded claims
and the re-reviewer **independently confirmed eleven, finding no twelfth** — the count survives the test.
But its verdict was that **the sweep's axes cover CLAIMS while the defect class is REFERENTIAL integrity**,
and **revision 4 had just been handed M-3, which proves that class exists, then swept only hex tokens.**

Three consequences, all propagated:

### H-R1 — a wrong citation reached a resolved human decision object

`9417f8bf:116-119` is cited for the same-uid reasoning. **It is at `:159-160`** (plus a second metric at
`:96-97`). `:116-119` is a fail-open/fail-closed tail plus an "Insider/backup exposure" heading. **The
pointer is 43 lines off — in a document arguing that a wrong absolute is worse than an absent one.**

Present at **five ADR sites**, in §11.1, in **§1.4's decline table**, and **in the scope note the Manager
actually applied** to `.decisions/9417f8bf` at `1c3f5ad`.

- Fix all five ADR sites. **The same wrong pointer is in `.decisions/9417f8bf`, which is `PROHIBITED`.**
  Report the exact correction; I apply it. **Do not write that file.**
- **Re-derive this class across the whole ADR** — a wrong `file:line` citation, not a wrong claim. The
  re-reviewer's point is that your six axes could not see it.

### H-R2 — `:687` says "Nothing here is closed"

Revision 4 made that false and **rewrote the A1 heading 23 lines below to say the opposite.** A section
claim falsified by its own body, **on the exact axis M-4 is about.**

### H-R3 — three internal `:NNN` citations broke under the +188-line growth, **one introduced by revision 4**

`:219`→`:237` (new text copied from the rev-3 review) · `:37-40`→`:52-55` · `:137-139`→`:152-154`.
**The last is self-refuting: the §Related scope note justifies itself with a wrong pointer.**

Fix all three, then **re-verify every remaining internal citation** — three found broken by one growth
event is an undercount, not a sample.

## ⚠ §1 — HUMAN-AUTHORIZED: RETIRE ACCEPTED RISK A1

The repository owner has **decided**. This is no longer a routing question.

**Retire accepted risk A1** (resurrection of a revoked credential by a re-mint). The owner chose this after
being shown that `08c7590` made the mint insert-only on both tiers.

**What you must change, and what you must NOT:**

- The §Accepted risks section currently says **"Nothing here is closed"** and **"This revision does not
  change the count… four gaps were put to the owner and four are recorded."** Both sentences are now
  false. **Three** are recorded; A1 is retired.
- Retire the A1 entry and say so **in place**, with the date, the authorizing decision and the verified
  evidence. Your own landing note already carries the verification in detail — reuse it.
- **Do NOT retire A2, A3 or A4.** The owner retired **A1 only**. Three remain.
- **The identifier collision warning above that section is still true and still needed** — A1 means both a
  substrate option and a risk id. **A retired risk id and a substrate option named A1 are now three
  readings of "A1" in one file.** Update that table; it is load-bearing.
- **Record what remains open, because it is the substance of why retirement is honest:** the *other* half
  of the revocation clause — **no code destroys a secret-manager handle**, so revocation remains
  one-sided in practice. That is `79e860e2`'s territory and is unaffected by this retirement.
- **Record that the retirement is the owner's, not a design lane's** — two prior lanes deliberately
  declined to do this for exactly that reason, and were right to. This time it is authorized.

## Two positions the re-reviewer took that you should not re-litigate

- **S-6 — `reviewed_by: null` is endorsed**, but for a **different and stronger reason** than revision 4
  gave: **no reviewer has APPROVED any revision of A2.** Revision 4's rationale ("`CHANGES_REQUIRED` is not
  a signature") is a weaker statement of the same fact. **Align the wording to the stronger one** if you
  touch §Status.
- **M-4's authority line is "right on the register, incomplete on the label."** Not retiring A1 was
  correct; **declining the free adjacent action (H-R2) was the miss.** You are now authorized on both.

## Verify — do not assume

- **The Manager's three append-only scope notes** (to `9417f8bf`, `876c6b97`, `27ea6536`) were audited at
  byte level and found **sound**, the `27ea6536` framing included: the object records the lane's
  *observation*, and the owner was entitled to reverse the *conclusion*. `human_correction_verbatim` was
  left unedited with the owner's spelling explicitly protected. **The H-R1 wrong pointer inside the
  `9417f8bf` note is the one defect in that work — report the fix, do not write it.**
- **F-9 is STRONGER than recorded.** Not merely a client-side mock key: the register flow **never
  transmits the key at all** and passes `repositoryId: productId`, so the build violates **A1's scope
  invariant**. The re-reviewer confirmed `20261006150645000` **is** on `main` and **is** newest, and that
  your H-1 re-grounding is correct (21 fields, no key material). **Correct §Known gaps if it understates
  F-9.**

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a review lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- **Write only inside `OWNED_PATHS`.** No production source. **No `.decisions/**` — report the exact
  correction for `9417f8bf` and I apply it.**
- **Leave both stashes untouched.**
- Do not commit or push. Do not approve your own work.
- **PERSIST YOUR FULL REPORT TO DISK** before returning, with the `RESULT:` block verbatim from
  `.agents/agents/design-agent.md`.
- **Search the domain's own vocabulary.** `docs/engineering/adr/` vs `docs/adr/` is the error that made ADR
  0018 itself get declared non-existent. **Use `git log --all --diff-filter=A -- <exact path>` and glob
  full paths, never basenames** — that is how a false premise reached a dispatch in this work item.
- **Line numbers move when you edit.** Read the live file after each edit and **re-read what you write
  about it** — three citations broke in revision 4 purely from growth, one of them introduced by the
  revision that was correcting them. That is the defect class you are now fixing.

## Report format

```
RESULT: DESIGN_REVISION_COMPLETE | DESIGN_REVISION_BLOCKED
```

Include `RISK_LEVEL` with rationale; per-finding disposition for H-R1, H-R2, H-R3 and anything your
re-derivation finds; **the exact `.decisions/9417f8bf` citation correction** for me to apply;
confirmation that **three** accepted risks are now recorded and which; and **your own count of internal
`:NNN` citations found broken, versus the three reported** — that number is the real measure of whether
the referential sweep was done.