# Subtask Prompt — design-correct-addproduct-mobile-5b-RESUME

Manager-authored **resume** note. **The dispatch prompt is
`tasks/design-correct-addproduct-mobile-5b/prompt.md`** — read that first, it remains authoritative for
scope, findings and hard rules. This file records only what changed: **the lane was cancelled part-way
through and this is a resume, not a fresh attempt.**

## Why you are being re-sent

A prior invocation of this exact dispatch was **cancelled mid-flight**. It did real work before dying:
the Penpot board edits and most of the record sweep **are already applied**. **Do not redo them, and do
not assume any of it is correct — verify it and finish the revision.**

The revision is **NOT complete**: `design-revision-5.md`, `design-revision-metadata-5.yaml`,
`traceability-matrix-5.md` and the report **do not exist**. The work on disk is in-place edits to
revisions 1–4 plus the live boards.

## Live state as the Manager measured it — treat as a starting hypothesis, not as truth

`git status` in `/private/tmp/shipit-correct-addproduct-mobile`, branch `design-correct-addproduct-mobile`,
HEAD `289f1d3`:

```
 M docs/.../design-brief.md          (+36/-…)
 M docs/.../design-revision-3.md
 M docs/.../design-revision-4.md
 M docs/.../design-revision-metadata-4.yaml
 M docs/.../design-revision.md
 M docs/.../penpot-board-evidence.md   (+152 — the largest change)
 M docs/.../report.md
?? docs/.../correction-report-5-retry.md
?? docs/.../correction-report-5.md
```

### What is already applied on the four live Penpot boards (Manager-verified this session)

All four boards, read via `penpot_execute_code`:

- Custody string is **now** `ed25519 · generated on the server · the private half stays in the secret
  manager` on all four — **H-1(a)'s board half is DONE.**
- **Zero** shapes on any board carry a `PENDING`/`PROVISIONAL` layer name — the discharged-gate layer
  naming is cleaned up.
- **H-1(c) appears applied.** The Unknown-host boards now read `REGISTERED · NOT YET USABLE`, a
  `CONFIRM THIS HOST TO FINISH REGISTERING` section, and a banner
  *"This product is already in your list. It cannot push or merge until you finish registering."*
  The Verified boards read `REGISTERED · READY TO REGISTER` with
  *"Access verified — this product can be registered"*.
- `penpot-board-evidence.md` has a **§6.3** that answers **D-8**: `SM` and `BPM` are two **states** of
  one mobile design, with a measured coordinate table, and it records that `BPM` carries the same false
  custody claim and the now-false `NOT REGISTERED YET` eyebrow — **`BPM` is not yours to edit.**

### What is NOT done

1. **No revision-5 artifacts exist.** `design-revision-5.md`, `design-revision-metadata-5.yaml`,
   `traceability-matrix-5.md`, `report.md` — all absent. **This is the bulk of what remains.**
2. **No persisted report.** The cancelled lane produced none. **You must write one to disk.**
3. **M-1 is not verified.** The cross-reference line-number correction was in progress; attempt 2's
   warning stands — the citations move as you edit, so a number verified before an edit is stale after it.
4. **The revision-1/2/3/4 edits are uncommitted and unattributed.** Every edit is currently an
   in-place modification to a *prior* revision. The convention in this work item is a **new numbered
   revision that supersedes the previous one**, with earlier revisions **retained intact** (see the keys
   lane: `supersedes_revision_id`, supersession headers move, prior bodies untouched). **You must decide
   how to reconcile this and say so explicitly in your report.** If the in-place edits to revs 1–4 should
   be reverted in favour of a clean revision 5, say which and why — but **do not delete the corrections
   themselves.**

## Your job, in order

1. **Establish what the cancelled lane actually did.** Read the diff
   (`git diff` in your worktree) and the current `penpot-board-evidence.md`. Do not trust the Manager's
   summary above; it is a Manager observation, and this work item has a documented history of a lane
   accepting a Manager premise that turned out false. **Re-verify independently.**
2. **Answer D-8 properly** — read §6.3 critically. Attempt 2 flagged it as the first question to answer;
   the cancelled lane appears to have answered it. **Confirm the coordinate table is measured, not
   asserted**, and confirm the `BPM` claim about the false custody string.
3. **Re-read every live board** and record actual before/after evidence. Attempt 2 could not read
   boards; you can. `penpot-board-evidence.md:151`'s old string was a **rev-2-era record, not a live
   read** — replace it with what is actually on the boards now.
4. **Finish M-1.** After every edit, re-read the live file. **Drop any "CONFIRMED, every number" claim
   that is not true after the final re-read.** The known trap: six citations at `+6`, one at `+5`, three
   ranges at `+8/+8/+13` — mechanical `+6` fixes six and breaks three.
5. **L-1** — confirm all three pointers are present, including `design-revision-3.md:445`'s G2
   `PENDING D4` claim.
6. **Issue revision 5** with `design-revision-5.md` + `design-revision-metadata-5.yaml` +
   `traceability-matrix-5.md`, carrying a fresh `revision_id`, `supersedes_revision_id`, `RISK_LEVEL` with
   rationale, and honest `design_system_compliance` / `ux_accessibility_score` /
   `implementation_feasibility` (report `UNKNOWN` where you cannot substantiate — a fabricated pass is
   worse than an honest `UNKNOWN`).
7. **Remove the fired escalation triggers** from the metadata: `design-revision-metadata-4.yaml:42-43`
   (`27ea6536` footer) and `:44-45` (host-trust navigation/IA, fired by `898b07d0` + R.11g item 3).
8. **Address the two REQUIRED `9417f8bf` follow-ups** owned by `design-agent`: the
   `RepositoryCredentialView.referenceName` / non-identifying-handle change (G-7 is now REQUIRED), and
   the **A3 unavailability path with concrete remediation copy** per `7b1bc8b7`.
9. **Persist your full report to disk** before returning, conforming to
   `.agents/skills/aef-orchestrator/templates/subtask-report.md`, with the `RESULT:` block verbatim from
   `.agents/agents/design-agent.md`.

## Report this honestly as new information

- Which of the cancelled lane's edits you **kept**, which you **reverted**, and why, item by item.
- Any board state that does **not** match the Manager's list above.
- Everything you could not verify, as `NOT_RUN` / `NOT_VERIFIABLE`. Penpot has **no version history**,
  so the pre-edit board state cannot be reconstructed — say so rather than implying a clean before/after.

## Unchanged from the dispatch prompt — these still bind

- **Run NO Docker or Compose command whatsoever.** Not `info`, not `ps`, not `logs`, not `config`. This
  repository has already lost a QA database to a lane doing exactly that.
- Only your four `SM` boards are writable. `BPM -` and `S -`/`DESKTOP -` boards are **read-only**.
- No production source, no `.decisions/**`, no `WORK_STATE.md`, no `LANES.md`, no keys-lane directory,
  no `docs/adr/**`.
- Do not commit or push. Do not approve your own work.
- All nine Human Decisions are RESOLVED — `9417f8bf`, `898b07d0`, `ae1c1f79`, `27ea6536`, `7b1bc8b7`,
  `79e860e2`, `4d2c6b81`, `b869ec24`, `876c6b97`. **Do not re-open any of them**, and do not re-raise
  B2/N1, B4/N2, N4/G9, N6, N10.
- Risk level 3 stands and the **Level-3 gate is already discharged** — attempt 2 re-verified that
  `9417f8bf`, `27ea6536` and `898b07d0` are RESOLVED and all name `design-agent`. Re-verify it yourself,
  then do not re-open the gate. The one residual undecided component is **D-2** (`TechnicalDetails` must
  suppress its `ContentRule` and align start-aligned) — that is a **Level 1** design-system-owner
  notification, **not** a human gate. The human already decided the outcome.
- Search the **domain's own vocabulary**, not the requester's phrasing. Three lanes in this work item
  grepped one identifier and concluded an artifact was absent (`deployKey` vs `credential`;
  `docs/engineering/adr/` vs `docs/adr/`; a centralised label). Verify paths exist before trusting an
  UNCHANGED result — one lane's `git diff --quiet` passed because the path did not exist.