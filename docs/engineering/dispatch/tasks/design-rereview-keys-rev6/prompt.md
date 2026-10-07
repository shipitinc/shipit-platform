# Subtask Prompt — design-rereview-keys-rev6

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-rereview-keys-rev6
TASK_TYPE: review            # focused re-review, read-only
FEATURE: Add Product rebuild — deploy-key service, Design Revision 6
WORKTREE: read-only; canonical checkout
BASE_SHA: 1c3f5ad
HEAD_SHA: af8e30f
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-rereview-keys-rev6/**   (your report)
READ_ONLY_PATHS: everything else
PROHIBITED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**   (artifacts under review)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, WORK_STATE.md, LANES.md
  - EVERY Penpot board
ACCEPTANCE_CRITERIA: |
  Focused re-review of revision 6 against B-R5-1 and M-R5-1..M-R5-4, L-R5-1..L-R5-3, plus the
  Manager's applied G-19 record correction, plus regression risk.
VALIDATION_COMMANDS:
  - cd /Users/alkebut/air/shipit-platform && git rev-parse --short HEAD    # af8e30f
ROUTING_CLASS: PRECISION
```

## Scope — FOCUSED

`docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev5/report.md` is your baseline. It found
**nothing wrong with the design's content about the key flow** — the footer spec, the three build edits
and `design_primitives.dart:396` were all verified right. Review only:

1. **B-R5-1's four parts** — G-18 in both registers · § 10.1 item 12 · § R.11g-h's scoped authority rule
   and four-edit list · G-19 registered.
2. **M-R5-1…M-R5-4, L-R5-1…L-R5-3.** § 0.4's L8 and M5 rows were wrong and § 0.4 is the map § 10.2 tells
   reviewers to **trust** — the lane says it **re-derived § 0.4 in full rather than amending it**, checked
   16 rows, and found the two known errors **plus one further error it disclosed** (an L13 per-artifact
   pin claim). **Verify the sweep, and check that third error is genuinely disclosed and fixed.**
3. **Regression risk.**
4. **The Manager's applied G-19 note** in `.decisions/27ea6536` — § below.

## ⚠ Verify the G-19 record correction the Manager applied

The lane specified an **append-only dated scope note** for `.decisions/27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0.yaml`
and the Manager applied it at `af8e30f`. **Audit it — it is a Manager edit to a resolved human decision,
which is the most sensitive edit class in this framework.**

Check: **`status`, `selected_option`, `decided_at`, `decided_by`, `human_correction_verbatim`,
`deviation_from_presented_options`, the `rationale`'s outcome clauses, and all four `follow_up_action`
owners are untouched.** Only `updated_at` was changed (to the date, with an inline comment), and content
was appended strictly after it. The lane specified the note should match `876c6b97`'s pattern.

**Judge whether the note's CONTENT is right**, not merely whether it is append-only. Its two claims:
a `Footer` **text** layer exists at `parentX 236 / parentY 862`, size 1020×15, carrying the string
`add_product_page.dart:383-384` renders; and the divider is at `(236,848)` with the right-aligned
disclosure's right edge at 1256 = 236+1020. **You have no Penpot ownership in this lane, so verify what
you can from the two prior reviews that measured it independently and say plainly that you are accepting
their measurement.**

Its framing claim is the one worth checking hardest: **what the decision overruled was the lane's
CONCLUSION, not its OBSERVATION**, and the owner was entitled to reverse the conclusion. If that framing
is wrong, the note misrepresents a human decision and must change.

## Also verify the Manager's own error, as the lane recorded it

The lane **declined a false Manager premise** and registered the residue as **G-20**. My dispatch stated
that `design-revision-3.md` "exists and is committed on `main`". **It does not.**

That claim came from a glob matching **two other lanes'** `design-revision-3.md` files — the same
single-identifier error class that produced three false "artifact absent" conclusions in this work item,
which I had explicitly warned against **in the same dispatch**. The lane was right to decline it;
adopting it would have retired a revision on a false statement.

`git log --all --diff-filter=A -- <exact path>` returns **empty** for
`docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-3.md`, and the file is in
**no commit on any ref**. Revisions 1, 2 and 3 existed only in a worktree.

**Both are now persisted at `af8e30f`** — rev 3 and its banner chain (2 838 lines) are committed.
Verify that, and verify G-20's registration is honest about what was and was not on disk before.

## Decisions and notes now in force — read at their scoped reading

- **`9417f8bf`** and **`876c6b97`** carry **appended dated scope notes** (Manager-applied at `1c3f5ad`):
  *"never holds key bytes"* is true only in the **storage** dimension — at transport time SHIP IT must
  materialise the private half in process memory — and the absolute appears at **four** sites,
  `9417f8bf:140` being the load-bearing uniqueness argument. **No decision re-opened, no accepted-risk
  count changed.**
- **`27ea6536`** now carries the G-19 note above.
- `876c6b97`'s **accepted risk A1 is verified closed by `08c7590`** (the mint path is insert-only) but
  **deliberately NOT retired** — closing an accepted risk changes what the owner accepted and that is the
  owner's call. **Four accepted risks remain four.** Check that revision 6 respects that.

## Do NOT re-open

`RISK_LEVEL: 3` with the tally **verbatim: 0 IMPROVED / 2 UNCHANGED / 4 WORSE**. The lane argues the
three new gap registers (G-18, G-19, G-20) are an argument **for** level 3, not against — a level-1
design does not accumulate governance debt. It also declined to extend rev 5's supersession banners,
because they are committed at `16cd497` and editing them would re-create the condition the dispatch
warned about. **Check that the banner state is coherent and that rev 6's *incorporation* of rev 5 by
reference is sound** — a 3 372-line revision referenced rather than restated is a traceability risk, and
the lane says every sentence it changes *is* restated in full. **Verify that claim.**

## G-18 — open, owned by nobody, and the work item must not close over it

The four desktop `S` boards carry a `Footer` text layer at 236,862 holding the build's own copy string,
so `27ea6536`'s desktop "No footer copy" is **not satisfied** on the boards that decision declares
authoritative. Divider and right-aligned disclosure **are** satisfied. Required edit: **remove that one
layer, nothing else.** Owner: design-system owner — the owner `27ea6536` itself named. **Blocked on the
Penpot instance binding, which no lane can satisfy.**

**It needs an ownership grant, not a re-decision.** The human is **not** asked to re-decide the footer.

Note the coverage distinction the lane draws, which is the kind of precision worth keeping: **R-UX2 is
COVERED but the OBLIGATION is UNOWNED and BLOCKED.** Coverage and completion are different claims and only
the first is true. **Judge whether that distinction is honest or convenient.**

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a review lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- **You have NO Penpot board ownership.** Do not read, edit, rename or delete any board.
- **READ-ONLY in git.** Edit nothing except your own report directory.
- **You are independent.** The producing lane declined to approve itself.
- **PERSIST YOUR FULL REPORT TO DISK** at `docs/engineering/dispatch/tasks/design-rereview-keys-rev6/report.md`.
- **Use `git log --all --diff-filter=A -- <exact path>` and glob with full paths, never basenames.** That
  is how a false premise survived into a dispatch in this work item, and how it was caught.
- **State explicitly what you did NOT review.**

## Report format

Per `.agents/skills/aef-orchestrator/templates/subtask-report.md`, `RESULT:` block verbatim from
`.agents/agents/design-reviewer.md`:

```
RESULT: DESIGN_REVIEW_APPROVED | DESIGN_REVIEW_CHANGES_REQUIRED | DESIGN_REVIEW_HUMAN_DECISION_REQUIRED
```

Include `CORRECTION_REQUIRED`, `HUMAN_DECISION_REQUIRED`, `INDEPENDENT_RISK_LEVEL`,
`RISK_LEVEL_AGREEMENT`, and an explicit verdict on the G-19 note's content and framing.