# Subtask Prompt — design-correct-adr-0018-a2-3 (revision 4: the stale-normative-text class)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-correct-adr-0018-a2-3
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — ADR 0018 amendment A2, revision 4
WORKTREE: /private/tmp/shipit-design-adr0018
BRANCH: design/adr-0018-amendment
BASE_SHA: 16cd497
OWNED_PATHS:
  - docs/adr/0018-per-product-git-credentials.md      ← the ONLY file you may write outside your task dir
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**
READ_ONLY_PATHS:
  - docs/adr/** — every other ADR (read, never write)
  - apps/**, packages/**, docker/**, .github/**
  - docs/engineering/WORK_STATE.md, docs/engineering/dispatch/LANES.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - docs/engineering/dispatch/tasks/design-review-*/**
PROHIBITED_PATHS:
  - docs/adr/** except 0018-per-product-git-credentials.md
  - .decisions/**                       (Manager-owned — see H-3, which you must REPORT not edit)
  - any production source
ACCEPTANCE_CRITERIA: |
  ADR revision 4 closing B-1, H-1, H-2, H-3, M-1..M-4, L-1, L-2 — by SWEEPING for the defect CLASS
  (unmarked superseded normative text), not by fixing the reported sentences.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-design-adr0018 && git rev-parse --short HEAD
  - grep -n "SUPERSEDED\|superseded by" docs/adr/0018-per-product-git-credentials.md
ROUTING_CLASS: PRECISION
```

## Isolation pre-flight

```bash
cd /private/tmp/shipit-design-adr0018
git branch --show-current    # design/adr-0018-amendment
git merge --ff-only 16cd497
git rev-parse HEAD
git stash list               # MUST still contain stash@{0} — see below
```

⚠ **There is a RETAINED STASH at `stash@{0}`** labelled *"ADR0018 A2 rev1 local edit (superseded by main
5436a4d; sha256 9e5b4772) — preserved, do not drop blindly."* The reviewer **verified it is intact and its
contents byte-identical to main's ADR** (`9e5b4772…`). **Leave it exactly as it is.** Do not drop, pop,
apply or modify it. Report that you left it.

## The finding set — read the review in full first

`docs/engineering/dispatch/tasks/design-review-adr-0018-a2-rev3/report.md`

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
REVISION_ID: ADR0018-A2-REV3
BLOCKERS: B-1        HIGH: H-1, H-2, H-3
MEDIUM: M-1, M-2, M-3, M-4        LOW: L-1, L-2
CORRECTION_REQUIRED: YES      HUMAN_DECISION_REQUIRED: NO
```

### ⚠ THE CENTRAL INSTRUCTION — this is why revision 3 failed

The reviewer **accepted G-17's factual conclusion and proved the git argument itself, but rejected the
producing lane's framing.** Its words, in substance: the lane's lesson *"the defect was the tense"*
**licenses exactly the two-sentence fix you were warned against.**

**The defect is a CLASS — stale normative text with no `SUPERSEDED` marker — and it recurs four times in
this one ADR.** Your job is the **sweep**, not the four fixes.

- **B-1** — the §Decision **headline** at `:272-273` still reads *"Each product owns its own SSH keypair.
  Git credentials are scoped per product, not per platform"* — **the exact scope A1 superseded.**
  Unmarked, contrary to the ADR's own convention at `:37-40` that **four other clauses honour**, absent
  from §Known gaps, and **contradicted 14 lines later** by the very §Decision-status row revision 3 added.
- **H-1** — §Decision status `:287` marks the custody clause **"Built: yes"**, citing
  `repository_credential.dart:12-18` and `:70-72`. **Both ranges assert the superseded A1 custody model.**
  A "Built" claim resting on evidence that contradicts it is worse than no claim.
- **H-2** — `:384` and `:401` are superseded by A1, unmarked. **`:401` presents the superseded scope as a
  BENEFIT in §Positive.** The producing lane declined both as "out of scope". **The reviewer rejected
  that: they sit inside its `OWNED_PATHS`, and the ADR supplies the device to correct them.**
- **H-3** — the ADR cites `9417f8bf` (`:45`, `:767`) and `876c6b97` (`:773-775`) **with no note that both
  carry the absolute it just corrected.** And F-1's scope is **understated: FOUR sites, not two** —
  `9417f8bf:113`, **`:140`** (the load-bearing uniqueness argument), `:210`, plus `876c6b97:20`.

**Method:** use the ADR's **own convention at `:37-40`** — four clauses already honour it. Apply it
consistently. Then **re-sweep the whole document** for any remaining unmarked superseded claim, because
finding four in one document means assuming there are exactly four is how revision 3 happened.

### The reviewer's two calls you must adopt

- **G-b — the same-uid exposure should have gone into the ADR's own §Known gaps.** "Not an accepted
  risk, needs follow-up" **is what §Known gaps is for**, it is inside your `OWNED_PATHS`, and it needs no
  owner authority. The lane was right not to create a fifth accepted risk, and wrong to stop there.
- **Refusing to write Manager-owned `.decisions/**` was right; stopping there was not.** For **H-3** the
  correct fix is a **dated scope note appended** to `9417f8bf` and `876c6b97` — and
  **`LEARNING_POLICY.md:261` and the ADR's own `:37-40` both point at exactly that remedy.** Those files
  are Manager-owned, so **you report the required edit precisely and the Manager applies it.** Do not
  write them. Do not rewrite a decision's rationale, ever.

### M-3 and M-4 — two verifiable defects

- **M-3** — `570bb640` is cited **as a commit**, and `git log` on it **fails**. It is a **decision
  object** id, not a commit. (I made this same class of error twice this session; the reviewer found my
  remaining one.)
- **M-4 — the landing hazard.** `main` has moved to **`16cd497`**, and `08c7590` **closed accepted risk
  A1**: `recordGeneratedCredential` now refuses any mint onto an existing `credentialId`. **The ADR is
  correct at `289f1d3` and stale-wrong inside that merge.** Re-verify A1's status **against current
  `main`** and record the result.

### What the reviewer verified and you should not re-verify

Every `file:line` citation in §Decision status and F-2 is exact. **The GCP Secret Manager substrate with
`secretAccessor` already granted to the Cloud Run SA is real**, so A4 genuinely narrows — **no deploy-key
secret, no runtime binding.** G-17's same-commit proof holds. The stash is intact and byte-identical to
`main`. **There are still FOUR accepted gaps — none added, none removed.**

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a review lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- **Write only inside `OWNED_PATHS`.** `docs/adr/0018-per-product-git-credentials.md` is the only ADR you
  may write. No production source. **No `.decisions/**`.**
- **Leave `stash@{0}` untouched.** Do not stash, pop, apply, drop or modify it.
- Do not commit or push. Do not approve your own work.
- **PERSIST YOUR FULL REPORT TO DISK** before returning, with the `RESULT:` block verbatim from
  `.agents/agents/design-agent.md`. **A review report has been lost three times in this work item.**
- **State decided versus planned honestly.** That is the whole point of §Decision status. **No normative
  present-tense claim may describe an unimplemented dependency**, and no "Built" claim may rest on
  evidence that contradicts it.
- **Search the domain's own vocabulary, not the requester's phrasing.** `docs/engineering/adr/` vs
  **`docs/adr/`** is the specific error that made ADR 0018 itself get declared non-existent. Verify paths
  exist before trusting an UNCHANGED result.
- Every result carries exact provenance, including the ADR's line count before and after.

## Settled — do not re-open

Nine Human Decisions are **RESOLVED**: `9417f8bf` **OPTION_C / A3** (external secret manager; ADR
`:85-88` SUPERSEDED; **A2 permanently EXCLUDED**; the reference is now the most sensitive artifact SHIP IT
holds, making **G-7 REQUIRED**), `898b07d0` **OPTION_A** (`:100-102` **UPHELD**), `79e860e2` **OPTION_A**
(`:113-114` **SUPERSEDED**), `ae1c1f79` **OPTION_A** (a refusal creates **nothing**), `7b1bc8b7`,
`4d2c6b81`, `27ea6536`, `b869ec24`, and **`876c6b97` OPTION_A — the A2 acceptance with FOUR knowingly-open
gaps.** Read `876c6b97` in full; its four gaps are the yardstick for the ADR's honesty.

## Report format

```
RESULT: DESIGN_REVISION_COMPLETE | DESIGN_REVISION_BLOCKED
```

Include `RISK_LEVEL` with rationale; a per-finding disposition for B-1, H-1, H-2, H-3, M-1…M-4, L-1, L-2;
**the precise dated scope note you need appended to each of `9417f8bf` and `876c6b97`** (Manager-owned —
give me the exact text); and **the list of any further unmarked superseded clauses your sweep found beyond
the four reported**, since that number is the real measure of whether the sweep was done.