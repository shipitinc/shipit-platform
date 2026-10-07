# Subtask Prompt — design-correct-addproduct-keys-7 (revision 7: the dangling-pointer class)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-correct-addproduct-keys-7
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — deploy-key service, Design Revision 7
WORKTREE: /private/tmp/shipit-correct-addproduct-keys
BRANCH: design-correct-addproduct-keys
BASE_SHA: 762e5cd
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**
READ_ONLY_PATHS: apps/**, packages/**, docs/adr/**, docs/engineering/**, AGENTS.md, .decisions/**
PROHIBITED_PATHS:
  - apps/**, packages/**            (production source — you design it, you do not write it)
  - docker/**, .github/**
  - .decisions/**, WORK_STATE.md, LANES.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**
  - docs/engineering/dispatch/tasks/design-review-*/**, design-rereview-*/**
  - EVERY Penpot board
ACCEPTANCE_CRITERIA: |
  Design Revision 7 closing the three HIGH, one MEDIUM and four LOW findings from the rev-6
  re-review, chiefly by RE-DERIVING rather than patching the dangling-reference class.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-correct-addproduct-keys && git rev-parse --short HEAD
ROUTING_CLASS: PRECISION
```

## Isolation pre-flight — read the warning, it is about THIS worktree

```bash
cd /private/tmp/shipit-correct-addproduct-keys
git branch --show-current    # design-correct-addproduct-keys
git rev-parse HEAD
git status --porcelain       # expect revision 6 artifacts UNCOMMITTED — see below
git merge --ff-only 762e5cd  # may FAIL; see the warning
```

⚠ **Revision 6 is uncommitted in this worktree.** The pre-flight `--ff-only` **fails** when untracked
files shadow content already on `main` — six files did exactly that on the ADR lane, all byte-identical.
**If your `--ff-only` fails: do NOT delete anything, and do NOT refuse to start.** Compare the shadowing
files against `main` byte-for-byte (blob hash), back them up outside the repository, then fast-forward and
re-compare. **Only if a file genuinely differs from `main` should you stop and report it** — and then say
exactly which and how. This is recorded as discovery **F-16**.

**Revision 6's artifacts are not on `main`.** They were persisted to the canonical checkout but the
commit that carried them was **rejected by a transient remote server error** and is currently local-only.
You may review them from the canonical checkout.

## Your finding set

`docs/engineering/dispatch/tasks/design-rereview-keys-rev6/report.md`

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
REVIEWED_HEAD: af8e30f   (BD01BC0 was the actual HEAD — one commit of sibling drift, verified inert)
BLOCKERS: none (0)      HIGH: 3      MEDIUM: 1      LOW: 4
CORRECTION_REQUIRED: YES      HUMAN_DECISION_REQUIRED: NO
INDEPENDENT_RISK_LEVEL: 3      RISK_LEVEL_AGREEMENT: YES
```

### H-1 — the notable finding: `§ 10.2-h` DOES NOT EXIST

`design-revision-6.md:277` and `metadata-6.yaml:352` **both point to it and make three claims about it
that are all untrue** — while `:282-284` **contradicts itself by omitting § 10.2 from its own restated
list.**

**This is the dangling-pointer class recurring inside the artifact built to fix it.** L-R5-1's whole
purpose was to eliminate exactly this, and revision 6 introduced one. **So do not patch § 10.2-h. Fix
the three false claims and re-derive every cross-reference in the artifact set from the live document**,
the way the ADR lane was just told to. A patch to the three sites leaves the class intact.

### H-2 — L-R5-1 is reported closed on a claim that is FALSE

`traceability-matrix-6.md:85`'s *own falsifier* — *"find an `artifacts[]` entry whose `blob_hash` is a
pointer string"* — **is currently satisfied by four entries.**

The underlying pin loop **IS fixed, and the reviewer confirmed it byte-exact.** So the fix is real and
the closure claim is not. **Do not re-fix the pins. Correct the closure claim, and close the falsifier.**

### H-3 — both register row counts are wrong

**Actual 15→18 and 16→19, not 19→22.** Note the direction: your numbers were *higher* than reality, which
is the safer error — but it means the register over-reports its own size.

### M-1 — § 0.4.1 enumerates 17 rows as "sixteen check out", including L13 which it then calls wrong

An internal contradiction in a table that § 10.2 tells reviewers to trust. **Recount.**

### LOWs, per § 5

An em dash normalised in G-19's quoted string · an **unregistered third inaccurate statement in
`27ea6536`** · G-20 now stale at the reviewed HEAD · revision 5 has **no forward pointer to revision 6**.

## Do NOT re-verify

The re-reviewer confirmed, at byte level:

- **B-R5-1's four parts all applied correctly** — G-18 in **both** registers, § 10.1 item 12 with the
  owner `27ea6536` itself named, the scoped § R.11g-h rule with a **four**-edit owner table, G-19
  registered with the writing lane touching nothing.
- **§ 0.4's sweep arithmetic is sound**, and **the third error is genuine** — revision 5's
  `content_pins` really does carry 3 real hashes + 1 `SELF-EXCLUDED`, with the unpinned file being the one
  holding `risk_level`, `gates` and the changelog.
- **`G-20` verified strongly** — `git log --all --diff-filter=A` on the exact full path: rev 3 was never
  added before `af8e30f`, and what was committed there is byte-identical to what you measured, blob
  `1364727434…`, 137 494 bytes, and the `2838` checks out.
- **`5436a4d` really is `289f1d3`'s direct parent.**
- **The G-19 note the Manager applied is SOUND**, including its framing — the object's recorded lane
  recommendation *was* `OPTION_A` "keep desktop copy", so "the conclusion — that the copy stays" is
  exact; the observation is what was measured; and `27ea6536` is `type: DESIGN` with the owner as
  authority who stated "I just checked". **No misrepresentation.**
- **G-18's coverage/completion distinction is honest, not convenient.**

## Two things that changed on `main` — re-read, do not assume

**1. Accepted risk A1 is RETIRED by the owner (2026-10-07).** `08c7590` made the mint insert-only on both
tiers; the owner retired it after being shown that. **THREE accepted risks now remain: A2, A3, A4.**
Revision 6 carried four and said so four times. **Every one of those is now stale** — find and correct
them, and record the retirement as **the owner's decision**, not a design lane's. Two prior lanes
deliberately declined to do this and were right to.

Note the ADR lane's finding, which concerns your material too: retiring A1 discharged the **resurrection
half only**. **No code destroys a secret-manager handle**, so revocation is still **one-sided in
practice**, and that half was never an accepted risk.

**2. A1 the substrate option still exists.** ADR 0018 §Amendments A1 = filesystem `0600`. **Do not
conflate the retired risk id with the live substrate option** — the ADR now carries a three-way
identifier table precisely because this has already caused one wrong conclusion.

## Also settled

`RISK_LEVEL: 3`, tally **verbatim: 0 IMPROVED / 2 UNCHANGED / 4 WORSE**. The lane's argument that the
three new gap registers are an argument *for* level 3 stands unrebutted — a level-1 design does not
accumulate governance debt. `9417f8bf` and `876c6b97` carry appended scope notes; read them at their
scoped reading.

## ⚠ G-18 — the ownership grant you are recording

**The human has now GRANTED board ownership.** A scoped design-system lane will own the four desktop
`S - Add Product` boards (and `BPM`) to remove the single `Footer` text layer at (236,862).

**Penpot went dormant during the Manager's session** — the plugin tab is suspended, `getPages()` returns
a heartbeat error — so **that lane is dispatched but may be blocked on the plugin being re-focused.** The
grant is decided; only the mechanics are pending.

**Record the grant, and keep the obligation UNOWNED-until-executed.** It is not closed because a grant was
issued. **The work item must not close over G-18 until the board edit is done and reviewed.** If the
re-reviewer asks whether the work item can close, the answer is no.

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a review lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- **You have NO Penpot board ownership.** Do not read, edit, rename or delete any board.
- No production source. No `.decisions/**`. Do not edit the mobile lane's or ADR lane's directories.
- Do not commit or push. Leave revision 7 in the worktree.
- Do not approve your own work.
- **PERSIST YOUR FULL REPORT TO DISK** before returning, with the `RESULT:` block verbatim from
  `.agents/agents/design-agent.md`.
- **Search the domain's own vocabulary** — the word is `credential`, not `deployKey`; the ADRs are in
  `docs/adr/`, not `docs/engineering/adr/`. **Use `git log --all --diff-filter=A -- <exact path>` and glob
  full paths, never basenames.** A Manager premise built on a basename glob was caught in this work item.
- **Line numbers and section numbers move when you edit.** Re-read the live document after each edit and
  **re-read what you write about it.** Nine broken cross-references were found in the ADR artifact set on
  a single pass — five more than were reported.

## Report format

```
RESULT: DESIGN_REVISION_COMPLETE | DESIGN_REVISION_BLOCKED
```

Include `RISK_LEVEL` with rationale; per-finding disposition for H-1, H-2, H-3, M-1 and the four LOWs;
**your own count of dangling cross-references found versus the three reported** — that number is the real
measure of whether the re-derivation was done; and confirmation that every stale four-risk count is now
three.