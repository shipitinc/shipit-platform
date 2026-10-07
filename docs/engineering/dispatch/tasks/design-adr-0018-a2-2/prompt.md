# Subtask Prompt — design-correct-adr-0018-a2-2 (correction of ADR 0018 amendment A2, revision 2)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-correct-adr-0018-a2-2
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — ADR 0018 amendment A2 correction (revision 2)
AREA: docs/adr/0018-per-product-git-credentials.md + its amendment design artifacts
WORKTREE: /private/tmp/shipit-design-adr0018
BRANCH: design/adr-0018-amendment
BASE_SHA: 289f1d3   (worktree is at 43d328b with uncommitted work — see pre-flight)
OWNED_PATHS:
  - docs/adr/0018-per-product-git-credentials.md
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**
READ_ONLY_PATHS:
  - docs/adr/**                  (every other ADR — read, never write)
  - apps/**, packages/**, docker/**, .github/**
  - docs/engineering/WORK_STATE.md, docs/engineering/dispatch/LANES.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**   (keys lane)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**        (mobile lane)
PROHIBITED_PATHS:
  - docs/adr/**  except 0018-per-product-git-credentials.md
  - .decisions/**                       (Manager-owned)
  - docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev5/**
  - docs/engineering/dispatch/tasks/design-review-addproduct-mobile-rev5/**
ACCEPTANCE_CRITERIA: |
  Amendment A2 revision 3 that resolves the 2 HIGH findings from the A2 review — specifically, the
  "SHIP IT never holds key bytes" claim must stop contradicting the ADR's own transport-time retrieval
  clause, and A3 custody must stop being stated in the present indicative while no substrate adapter
  exists.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-design-adr0018 && git rev-parse --short HEAD
  - grep -n "never holds\|transport" docs/adr/0018-per-product-git-credentials.md
ROUTING_CLASS: PRECISION
```

## Isolation pre-flight — RUN THIS FIRST, AND READ THIS CAREFULLY

```bash
cd /private/tmp/shipit-design-adr0018
git branch --show-current    # must equal design/adr-0018-amendment
git status --porcelain
```

**Current state, Manager-measured:** HEAD `43d328b`, with an uncommitted modification to
`docs/adr/0018-per-product-git-credentials.md` plus an untracked
`docs/engineering/dispatch/tasks/design-adr-0018-amendment/`.

**`git merge --ff-only 289f1d3` FAILED here** because of that local modification:

```
error: Your local changes to the following files would be overwritten by merge:
  docs/adr/0018-per-product-git-credentials.md
```

**This is the crux of the task, not an obstacle to route around.** `main` has moved 2 commits ahead and
**those commits include the A2 revision itself** (`6220951`, 158 → 580 lines) and the ADR acceptance
decision `876c6b97`. Your worktree's uncommitted edit is against the **old** ADR.

**Do NOT blow away the uncommitted work.** Sequence it properly:
1. Capture the uncommitted diff (`git diff > /tmp/adr-a2-prelocal.patch`) so nothing is lost.
2. Determine what that local edit actually is — amendment revision 1 or a stale reversion. Compare it
   against `main`'s version and against the amendment artifacts in your untracked task directory.
3. `git stash` (not `checkout --`) or otherwise preserve it, re-base onto `289f1d3`, then re-apply only
   what is not already on `main`.
4. **Report exactly what you found and what you did with it.** If the local edit is superseded work,
   say so and say why. Do not silently discard it.

## The review that created this task

`docs/engineering/dispatch/tasks/design-adr-0018-amendment/report.md` — **check whether it exists first;
this work item has lost reports twice.** The Manager's record of it: **`CHANGES_REQUIRED`, 0 BLOCKERS,
2 HIGH**:

> **HIGH 1 — "SHIP IT never holds key bytes" contradicts the ADR's own transport-time retrieval clause.**
> `9417f8bf` chose A3: SHIP IT holds only a *reference* and asks the manager for the material **at push
> time**. The ADR cannot simultaneously say SHIP IT never holds key bytes AND require it to retrieve key
> bytes from the manager when it pushes. Both clauses are present in the current text. One must be
> scoped, not asserted flatly.

> **HIGH 2 — A3 custody is stated in the present indicative while no substrate adapter exists.**
> The ADR reads as though A3 is the live operating model. Nothing implements it: the `SecretProvider`
> does not exist, the three endpoints do not exist, and A3's reachability in the target topology is
> recorded **`UNVERIFIED`**. Normative present-tense language for an unimplemented dependency is exactly
> the class of defect B5 caught in the keys lane (asserting a state the record does not support).

**Re-verify both yourself before acting on them.** If the review report is genuinely absent, reconstruct
the finding set from the ADR text and say that is what you did.

## What is settled and must not be re-opened

Nine Human Decisions are **RESOLVED**. Read the resolution blocks; cite them; do not re-open.

- **`9417f8bf` OPTION_C / A3** — an **external secret manager**. SHIP IT holds only a reference and asks
  the manager for the material **at push time**. Consequence 1: **ADR 0018 `:85-88` is SUPERSEDED**.
  Consequence 2: **A2 (envelope-encrypted ciphertext in a table) is PERMANENTLY EXCLUDED** — the "never
  persisted to the durable record" clause still binds it. Consequence 3: **the reference itself is now the
  most sensitive artifact SHIP IT holds**, which makes **G-7 REQUIRED**, not optional.
- **`898b07d0` OPTION_A** — split identity from registration. **ADR `:100-102` is UPHELD** ("a product
  cannot be registered until a connectivity check has succeeded"), not contradicted.
- **`79e860e2` OPTION_A** — destroy the manager handle, keep the row. **ADR `:113-114` SUPERSEDED**
  (revocation is no longer provider-native-only, because SHIP IT now holds a handle to destroy).
- **`ae1c1f79` OPTION_A** — **a substrate refusal creates NOTHING**, so the precondition precedes any
  write. This resolved a contradiction between two of the human's own decisions.
- **`7b1bc8b7`** fail closed with a remediation copy · **`4d2c6b81`** index into a new migration ·
  **`27ea6536`** footer spec (per-platform, with a recorded deviation) · **`b869ec24`** server-side
  generation and storage · **`876c6b97`** **the ADR A2 acceptance itself, OPTION_A — with four
  knowingly-open gaps accepted.**

**`876c6b97` matters for HIGH 2.** The human accepted the amendment *with four knowingly-open gaps*.
**Find those four gaps in the decision file and make sure the ADR's tense matches the acceptance.** If
"no substrate adapter exists" is one of the four accepted gaps, then the correction is to state it as an
accepted open gap, not to rewrite the architecture. **Read `876c6b97` in full before drafting.**

⚠ **G-17, newly found by the keys rev-5 reviewer this session, and it bears directly on your task:**
**ADR 0018 `:16-21` and `:572-580` DENY the existence of the `876c6b97` decision object** — and
`git log --diff-filter=A` proves `876c6b97` landed in the **same commit** that wrote the denial. The ADR
currently states a falsehood about its own acceptance. **Correct that**, and say how you established it.

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has already lost a QA database to a lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.**
- Write only inside `OWNED_PATHS`. **`docs/adr/0018-per-product-git-credentials.md` is the only ADR you
  may write.** Every other ADR is read-only.
- Do not write production source. Do not edit `.decisions/**`.
- Do not commit or push unless explicitly instructed. It is not.
- Do not approve your own work.
- **PERSIST YOUR FULL REPORT TO DISK** before returning, conforming to
  `.agents/skills/aef-orchestrator/templates/subtask-report.md`, with the `RESULT:` block verbatim from
  `.agents/agents/design-agent.md`.
- **An ADR is not code: state what is decided versus what is merely planned.** The reviewer's HIGH 2 is a
  tense problem. Normative present-tense language must not describe an unimplemented dependency. Where
  the honest form is "SHALL, once implemented" or "is specified to", use it.
- **Search the domain's own vocabulary, not the requester's phrasing.** Three times in this work item a
  lane grepped one identifier and concluded an artifact was absent — including `docs/engineering/adr/`
  vs **`docs/adr/`**, which wrongly declared ADR 0018 itself absent. The product ADRs are in `docs/adr/`.
  Verify paths exist before trusting an UNCHANGED result.
- Every result carries exact provenance.

## Report format

```
RESULT: DESIGN_REVISION_COMPLETE | DESIGN_REVISION_BLOCKED
```

Include `RISK_LEVEL` with rationale and the pre-flight finding about the uncommitted local edit.