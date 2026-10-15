# Repository Learning: a rollback guard is also a rollback EXPIRY

**Feature**: IMPL-B6-CORRECTION-FINDINGS (documenting migration `20261014210000000`'s DOWN window)
**Date**: 2026-10-15
**HEAD**: see `git rev-parse HEAD` on `fix/unstick-unreviewable`
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic
authority.

---

## Summary

Migration `20261014210000000`'s DOWN step 1 carries
`AND w."state" = 'agent_completed'`. That guard is **correct**: a blind restore
would put an item back to `waiting_for_human_decision` behind a decision that has
long since moved on, clobbering whatever it has become.

But `agent_completed` is `engineeringReviewDefinition.entryStates`. The ordinary
scheduler tick treats that state as runnable and **dispatches the re-review this
migration was written to set up**. Once it does, the item leaves
`agent_completed`, the guard matches nothing, and the restore **silently** affects
zero rows — while steps 3 and 4 still delete the audit rows and roll back the
`serverpod_migrations` version.

The guard was correct; the **time window was documented nowhere**.

## The distinction that had to be written down

> The guard is right. What is easy to miss is that a correctness guard on a
> rollback is simultaneously an **expiry**, and the two have different audiences:
> correctness is read by the engineer who wrote the query; expiry is read by the
> operator deciding whether to run `down` at all.

A guard that prevents damage is also a guard that makes the statement stop
working. Both facts belong in the banner, and only the first was there.

## What the banner now says

Placed in the DOWN prose, above the executable region:

* the rollback restores **only while** the repaired items are still parked at
  `agent_completed`;
* once the tick has dispatched, it is a **no-op on that item** — no warning, no
  error, no affected-row count, the statements simply match zero rows and succeed;
* the window is *"before the re-queued review runs"*, and **that is not a time the
  operator controls** — which is why it matters that the DOWN is most often
  considered *because* the re-review is misbehaving;
* the `SELECT` to run first, and the reading: anything other than
  `agent_completed` means **this rollback cannot restore it** — that is the guard
  working, not the rollback failing, which is invisible without the paragraph.

## Constraints this correction honoured

The finding was documentation-only, and the restriction was explicit: **the DOWN
banner comment only; not a single statement of the UP or DOWN logic**. A1–A4 were
reviewed PASS and the pins verified byte-exact against live QA.

Verified mechanically — every added line in `migration.sql` begins `-- `:

```
$ git diff -U0 migration.sql | grep -E '^[+-]' | grep -v '^[+-][+-][+-]' | grep -vE '^\+-- '
(no output)
 34 insertions(+), 0 deletions
```

An insertion-only diff is the strongest available statement that no statement
changed, since a modified line would appear as a deletion.

## Generalisable

> Any migration `down` containing a state guard names a window in which it works.
> If the state it guards is an *entry state* for some scheduler or worker, the
> window is closed by a routine background process, not by the operator. State that
> plainly in the banner, or the operator will run a successful-looking rollback
> that restored nothing.