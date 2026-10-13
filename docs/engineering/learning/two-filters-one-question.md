# Repository Learning: Two filters, one question

**Feature**: IMPL-A2-CORRECTION-2 (implementation scheduler lane)
**Date**: 2026-10-13
**HEAD**: 67d2e1d (finding raised by `engineering-reviewer`, MEDIUM-2)
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.

---

## Summary

`RunsBloc` and `RunsPage` each decided "which rows belong under Working on it?" with
their own predicate over their own enum. They disagreed, nothing failed, and nothing
would have complained until somebody wired the unused one up. There is now one
implementation.

**This entry deliberately restates almost nothing.** The executable form of both
traps already exists in the repository and will not go stale:

| What is true | Where it is true, mechanically |
|---|---|
| The one filter implementation | `apps/control_plane/lib/features/runs/runs_bloc.dart` — `WorkFilter.matches` |
| The bloc delegates to it, and does not re-ask | same file, `RunsBloc._filter` + `_asWorkFilter` |
| What each status belongs under, written independently of the implementation | `apps/control_plane/test/blocs/runs_bloc_test.dart` — the `includedIn` table and "the bloc agrees with the table under &lt;filter&gt;" |

Read those, not this file, when you need the behaviour. Read this file for the shape
of the mistake.

---

## The finding

`RunsBloc._filter` switched on `RunsFilter.workingOnIt` and kept rows where
`PlainLanguage.statusFor(...) == PlainStatus.workingOnIt`. `WorkFilter.matches` — the
predicate the page applies to the rows it actually renders — also keeps
`awaitingReview`, `waitingToStart` and `readyToBuild`.

So under the bloc's own definition, an `implementation_ready` item ("Ready to build"),
an item awaiting review, and an accepted-but-unstarted item were all invisible under
"Working on it", while the tab the operator clicks shows them.

## Why it stayed invisible — the part worth remembering

Three properties had to hold at once, and each one alone was enough to hide it:

1. **The page re-filters at render time** (`runs_page.dart`, `.where((row) => _filter.matches(row.status))`).
   The wrong answer was computed, discarded, and replaced by the right one before a
   human saw a pixel. The duplication cost a predicate and produced no symptom.
2. **`state.filter` is always `RunsFilter.all` in production.** `RunsFilterChanged` is
   added only from `runs_bloc_test.dart`. The wrong arms were not merely unused —
   they were *unreachable*, so no amount of clicking could surface the defect.
3. **A missing row has no error and no empty state.** Had `RunsFilterChanged` been
   wired, the bug would have been "the queue the implementation lane is about to
   drain is not shown", with nothing in a log, nothing in a test failure, and the
   filter looking like it was simply answering a narrower question.

That combination is the transferable part: **a duplicate predicate is cheapest to
introduce exactly when one of its two call sites is not yet wired.** The unused copy
has no failing caller to complain.

## The correction

`WorkFilter` moved from `runs_page.dart` into `runs_bloc.dart` — not for tidiness, but
because the enum is now asked by two files and must not live inside one of them.
`RunsBloc._filter` delegates through an exhaustive `RunsFilter → WorkFilter` switch, so
adding a member to either enum is a compile error rather than a silent miss. The now-dead
`_isTerminal` helper went with the duplicate predicate that used it.

`RunsFilter` itself remains, and is still unwired in production. It was kept rather than
merged because it is the bloc's *state* while `WorkFilter` is the design's filter set and
carries the tab labels. **Deleting it is the correct end-state and is not done**: it
lives in `runs_event.dart`, which this lane does not own. Recorded as a non-blocking
follow-up for the Manager, not as a decision taken here.

## Why the guard is a truth table and not an assertion of delegation

The obvious guard — "the bloc calls `WorkFilter`" — proves nothing. A second, correct
switch written *next to* the delegation would satisfy it. So the guard states, for every
`PlainStatus`, which tabs a row belongs under, written out without reference to
`WorkFilter.matches`, and asserts the bloc's output equals it. It fails if a predicate
regrows.

The table also asserts `includedIn.keys == PlainStatus.values`. That is the half that
matters for the domain: a status nobody classified would otherwise appear under **no
tab at all**, which is not a filter bug anyone reports.

## Larger lesson — framework candidate, not persisted here

*Not persisted: `WORKFLOW_IMPROVEMENT` requires independent review.*

**A duplicated predicate should be checked by re-deriving the answer independently, not
by asserting delegation.** "Component X calls component Y" is satisfied by X growing its
own private copy of Y's logic. A guard only has teeth if it restates the expected answer
from outside both implementations — and for an enum-keyed decision, an exhaustive table
is the cheapest form of that restatement.

The generalisable form of the *finding*, not of this codebase: when one implementation of
a rule has a reachable caller and its duplicate does not, the duplicate is not
"currently harmless" — it is the half of the pair that has never been tested, because
nothing has ever disagreed with it out loud.