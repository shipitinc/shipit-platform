# Repository Learning: "No verdict" is not "no review happened"

**Feature**: IMPL-B6-UNSTICK-R3 (repair fabricated engineering-review decisions)
**Date**: 2026-10-14
**HEAD**: `a445fac` on `fix/unstick-unreviewable`
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic
authority. The framework-candidate half is flagged in the last section and NOT persisted here.

---

## Summary

The repair asked for is "retire decisions whose reviewer produced no verdict". That sentence
contains a trap, and QA currently holds the evidence that springs it.

Measured read-only off the live QA database on 2026-10-14 — every `engineering_review`
decision that exists, joined to the reviewer execution its own metadata names:

| decision | reviewer | `structuredResultJson` | `summary` | repairable? |
|---|---|---|---|---|
| `dec-hn7h7d9j8i-1oh8pgm` | **failed**, no terminal event | `{}` | empty | yes |
| `dec-hn7h7db3w9-hdzu8c` | **failed**, no terminal event | `{}` | empty | yes |
| `dec-hn7h7dagw5-l4o193` | **completed** | `{}` | **2000 chars** | **no** |
| `dec-hn7iw644nz-rmmpcn` | **completed** | `{}` | **2000 chars** | **no** |

The last two are the finding. `agx-wx-jb-hn7gq1n2dc-1llxxyk` opened `## Engineering Review`
and wrote **"Verdict: `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`"**, then verified a
value-preserving constant swap and listed three non-blocking findings.
`agx-wx-jb-hn7itcezii-1igc7vp` confirmed all three of its diagnoses by inspection and checked
two claims the commit message does not make. Both are real, substantial, independently produced
engineering reviews.

**Their machine channel is empty anyway**, because `ReviewVerdict`'s wire set is exactly
`approved` / `approved_with_minor_findings` / `changes_required` / `rejected`, and
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` is not one of those four. So the decision each produced
claimed `changes_required` — a fabricated claim — *while a genuine review sat unread next to
it*, in the one column nothing else writes.

A repair keyed on "no machine-readable verdict" would have destroyed both. That is worse than
the bug it repairs, and it is not a near miss: each summary is the **only** copy of that
review. Once retired, it is gone.

So the predicate is **an empty summary**, not an absent verdict. The two conditions are
separately true in QA today, which is exactly why they are separately argued in the migration's
banner rather than collapsed into one convenient test.

**This entry deliberately restates almost nothing.** The executable form exists and will not
go stale:

| What is true | Where it is true, mechanically |
|---|---|
| the four assessment classes, and that exactly one is repairable | `apps/server/test/review_repair_action_test.dart` |
| that the decision's own `reviewVerdict` is never the evidence | same file, `the decision's own verdict claim is never the evidence` |
| that the SQL re-derives the same test and fails loud if it disagrees | `apps/server/test/integration/unreviewed_review_repair_migration_test.dart` |
| that a real review is never touched | same file, `(e)` |

Read those, not this file, when you need the behaviour. Read this file for the shape of the
mistake.

---

## The classification, and why it is four classes rather than a boolean

"Did a reviewer return a verdict" has four honest answers, and the naive boolean collapses the
two that matter most:

| class | meaning | repairable |
|---|---|---|
| `assessed` | a real verdict is in the reviewer's own result | **never** |
| `noReviewerOutput` | no result at all, or an empty payload **and** an empty summary | **the only one** |
| `reviewerProseOnly` | a reviewer COMPLETED and wrote prose; no machine verdict | **never** |
| `unreadable` | a result exists and could not be read | **never** |

`unreadable` exists for the same reason `assessed` does. A result this build cannot parse is
a reviewer **answering in a dialect this build does not speak**, which is not an assessment and
certainly not "no assessment". Laundering "I could not check" into "there was nothing there"
is the same fabrication one layer out, and it is the failure mode every reader of this codebase
should watch for.

## The reader must mirror the gate's ARM ORDER, not just its conclusion

`EngineeringReviewGate._readReviewVerdict` reads an embedded `engineeringReviewResult` first
and **falls through** to a top-level `verdict` on a parse failure — deliberately, because the
second path can still produce an honest verdict from the same payload. A repair reader that
did only the second thing, or that "simplified" the fall-through, would be right about "the
reviewer was silent" and wrong about "the reviewer answered in a form we can read". That
combination does not throw; it quietly retires a real review.

Two readers that must agree are worse than one reader, because their disagreement is silent. So
the SQL in the migration re-derives the same test **independently and deliberately more
strictly** — it treats an unparseable embedded result as "not repairable", where the Dart reader
would fall through — and the guard **fails the whole migration** if an enumerated target does
not match. The two can only ever disagree towards refusal.

## An enumerated list, because a predicate silently widens

The migration enumerates its two targets rather than selecting them. A predicate like "every
pending `engineering_review` decision with an empty summary" is correct at the instant it is
written and **also matches the two real reviews above** on every subsequent apply — and since
those summaries are the only copy of that work, the second apply would destroy them.

`20261014093000000` argues the same point for its own set ("a broad predicate would be safe
only at the instant it was written and would silently widen on every subsequent apply; an
enumerated list cannot"), and this is the second migration in the repository to need that
argument. That repetition is the evidence that it is a property of this system, not a habit.

## The operator action is a refusal, and the refusals are the feature

Every refusal returns **before the transaction opens**, so every refusal writes nothing — no
audit row, no decision change, no version bump. The work item's compare-and-swap is written
first inside the single transaction precisely so that "a refusal writes nothing" is true on a
store that cannot roll back (`InMemoryWorkflowStore.inTransaction` is `body(this)`).

The sharpest test in the suite seeds a decision that claims `approved` with no reviewer output,
and one that claims `changes_required` with a real reviewer verdict, and asserts the first is
repairable and the second is refused. **Both would decide identically under a reader that
trusted `metadata.reviewVerdict`** — which is precisely the reader that caused this.

## The drift, and why one item was left alone

The dispatch named three decisions. Live QA holds one in a different state than the dispatch
assumed: **`dec-hn7h7daum6-2atjhe` is `resolved` with `choice = approve` by `operator`, and its
work item has already moved on to `review_approved`.**

That is the harm this whole mechanism exists to prevent, and it has already happened once, in
QA, to a decision whose reviewer had timed out.

It was deliberately **excluded, not quietly repaired**. Undoing it means overwriting a recorded
human approval — discarding a real human decision to replace one fabricated verdict with a
different fabricated shape. That is worse than the defect being repaired, and it is a
product/governance call rather than a data call. It is escalated as `HUMAN_DECISION_REQUIRED`;
nothing in the migration touches its status, choice, decider, rationale, signature, or the work
item at `review_approved`.

The migration's `choice IS NOT NULL` arm is what stops the same thing happening to the other
two if an operator resolves one between dispatch and apply.

## The `down` path, and what it does not promise

The rollback reads the before-image off this migration's own audit row rather than recomputing
it, which is the defect `20261014093000000` documents **in its own rollback** — and the fix is
separately important: that migration's DOWN deletes the audit rows *first* and then runs an
UPDATE whose `EXISTS` arm keys off those same rows, so it restores nothing. Read in isolation it
looks right.

One boundary is stated in the file rather than left to be discovered:
`work_item.metadataJson` comes back **semantically, not textually**. The up pass writes it as
`(jsonb || jsonb)::text`, and jsonb reorders keys and inserts a space after every colon on the
way in, so the original bytes no longer exist and no rollback can return them. `state`,
`blockingHumanDecisionId`, `blockingReason` and the decision's own metadata *are* restored
byte-for-byte. Asserting textual identity for the work item would be asserting a falsehood
about a correct rollback.

The rollback is also **executed, not described**. The house style writes it commented out, which
means a `down` that is described one way and written another silently rolls nothing back while
every prose assertion about it passes. The migration delimits an executable region and the test
strips exactly one `-- ` prefix from each line in it — SQL written with one prefix becomes
executable, its own comments written with two survive as comments.

## One gate that does not exist

`make test-integration` and CI build `public` from the **latest `definition.sql` alone**, so on
a fresh database a `migration.sql` is **never executed** — a data repair is a no-op on an empty
schema. `20261014093000000`'s test says this out loud, including correcting a dispatch brief
that asserted the opposite.

So the migration is exercised the way a deployment would run it: the whole `migration.sql` chain
replayed **verbatim** into a scratch schema (`stranded_key_repair_migration_test.dart`,
`product_repoint_migration_test.dart` and now `unreviewed_review_repair_migration_test.dart`).

That gate earned its place within an hour. It found three real defects in this migration that no
analyzer could see: `->>` applied to a nullable `text` column; a correlated subquery whose bare
outer reference bound to the **subquery's own** column, making the predicate tautological; and a
`down` region whose comments and statements shared a prefix, so stripping it produced a file that
executed nothing at all.

---

## Larger lesson — framework candidate, NOT persisted here

*Not persisted: `WORKFLOW_IMPROVEMENT` and `AUTOMATION_OPPORTUNITY` require independent review.*

**A repair must be scoped to the absence of the thing it repairs, not to the absence of the
thing that thing is normally recorded in.** "No verdict" and "no review" differ only when a
system has two channels for the same fact, and then they differ exactly where the damage is
worst. The generalisable guard is to ask, for every predicate you write over a durable record,
*what else could look like this and be precious* — and to check it against real data before
choosing the predicate, because on empty data the two are indistinguishable and the predicate
that is correct in production is the one that looks wrong in a fixture.

A second, smaller candidate: **when a migration must be safe to re-run, its own gate should be
executed somewhere.** A fail-loud guard that is only ever read is a guard whose correctness is
an assumption; running it costs one scratch schema and finds, in this case, three real defects
before deployment.
