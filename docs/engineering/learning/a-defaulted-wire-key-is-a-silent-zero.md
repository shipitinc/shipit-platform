# Repository Learning: A `?? 0` on a wire key is a silent zero

**Feature**: IMPL-B5-MODEL-STATS (Models → Stats has never shown real data)
**Date**: 2026-10-14
**HEAD**: see `fix/model-stats-truthful`
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic
authority. The framework-candidate half is flagged in the last section and NOT persisted
here.

---

## Summary

Three independent layers were broken, and none of them produced a visible failure:

| Layer | What was wrong | What an operator saw |
|---|---|---|
| 1a | `SUM(bigint)` returns `numeric`; four token totals were read `as int?` | `500` on **every** `getModelStats` call |
| 1b | The grouped path looked up `m['"role"']`; `toColumnMap()` keys are bare | `500` on **every** grouped call |
| 2 | The client read nine keys the server never sent and defaulted each | `0.0%` success, `$0.00`, `0` executions, five blank charts |
| 3 | A failed read rendered as the same zeros | indistinguishable from a real measurement |

**This entry deliberately restates almost nothing.** The executable form of all four traps
exists in the repository and will not go stale:

| What is true | Where it is true, mechanically |
|---|---|
| The aggregates the endpoint publishes, read end-to-end against real PostgreSQL | `apps/server/test/integration/model_stats_endpoint_test.dart` |
| The wire shape the client maps, built from the **generated** `ModelStatsView.toJson()` | `apps/control_plane/test/data/model_stats_response_mapping_test.dart` |
| A failed read renders an em dash, not a figure — asserted on rendered text | `apps/control_plane/test/widgets/model_stats_page_error_test.dart` |

Read those, not this file, when you need the behaviour. Read this file for the shape of the
mistake.

---

## Layer 1 — the two TypeErrors, and what they were made of

`SUM()` over a `bigint` column returns **`numeric`** in PostgreSQL, never `bigint` again.
Verified against the QA database:

```
SELECT pg_typeof(SUM("inputTokens")) FROM "model_execution_record";  -- numeric
SELECT pg_typeof(SUM("costUsd"))     FROM "model_execution_record";  -- double precision
SELECT pg_typeof(COUNT(*))           FROM "model_execution_record";  -- bigint
```

The `postgres` driver decodes `numeric` as a **String** — the text codec's `asText()` and
the binary codec's `_decodeNumeric` both return `String` — so the runtime failure was
`type 'String' is not a subtype of type 'int?' in type cast`. (Correction worth recording:
the dispatch brief said Serverpod maps `numeric` to `Decimal`. It does not. The conclusion
was the same — it is not an `int` — but the type named in a bug report should be the type
the process actually threw.)

Two further facts made the same class of mistake invisible in three other columns:
`SUM`/`AVG` over the `double precision` `costUsd` column stay `double precision`, and
`COUNT(*)` stays `bigint`. So **three of the nine aggregates in the same SELECT were fine and
four were not**, which is why the obvious "it works for cost, so it works" reasoning
survived as long as it did.

`toColumnMap()` returns **bare column names**. `SELECT "role", ...` names the column `role`;
the quotes are SQL identifier delimiters and are never part of the name. Holding the quoted
form in the same variable that is used as a map key — `groupByColumn = '"role"'` then
`m[groupByColumn]` — is a variable that means two different things in two different
positions.

## Why `?? 0` was the wrong repair, and what was done instead

The instinctive fix for "this cast throws" is `as int? ?? 0`. That is the one repair that
would have made the screen *worse while making it green*: `??` cannot see a type error, only
an absent value, so it converts a loud exception into a confident `0`-token report — the same
class of confident zero the screen already existed to reproduce.

The fix went in the SQL instead:

```sql
COALESCE(SUM("inputTokens"), 0)::bigint as "totalInputTokens"
```

`COALESCE` is not a mask here. The only way `SUM` over these columns is NULL is that no rows
matched, and the sum over no rows **is** zero — so the default is true rather than defensive.
An int64 overflow raises rather than wrapping, so this cannot silently report a wrong total.
The Dart side reads the result `as int`, with no `??`.

The grouped roll-up was also computing a **mean of per-group means**. The groups partition
the same rows, so `(4.00 + 3.00 + 4.00) / 3` weights a one-run model the same as a two-run
one and reports an average cost no execution ever cost. It is now `totalCostUsd / count`.
This was not in the dispatch; it was found because making `avgCostUsd` visible made the wrong
value user-visible.

## Layer 2 — the mapping, and the decision each field forced

The server sends ten keys. The client read nine *different* ones. Every one of those nine
defaulted to `0.0` / `0` / `const []`, so the success-rate card read `0.0%` on every load for
ever and its `>= 0.95` threshold could never be true. The eight keys that were sent were
never read.

The split that mattered was not *server-side vs client-side* but:

- **derivable** — `successRate` from `successCount`/`failureCount`; per-group and
  per-dimension charts from `byGroup`. Derived **as a getter**, so the rate cannot drift from
  the two counts it is computed from.
- **not derivable** — `costOverTime` and `escalationFrequency`. `getModelStats` returns ONE
  aggregate for the whole range with no time buckets, and offers no grouping by
  `escalationIndex`. These were **removed and named in prose** on the page rather than left as
  an empty axis. An operator reading an empty "Cost Over Time" chart cannot distinguish a
  feature that never worked from a range with no spend; a sentence saying the measurement is
  not taken is a different thing to see.

`totalExecutions` survived as the client-side name for the server's `count`. The GROUP BY
control had been wired to the server since before this lane and then ignored entirely, which
is why three of the five dead charts could be revived truthfully as one dimension-driven set
— and why the dead selector is the evidence that the screen had never once shown data.

## Layer 3 — a failed read must not reach a card

`ModelStatsState.errorMessage` existed, but the page only rendered it when `stats == null`.
A **refresh that failed while earlier data was on screen** left that data on screen with
nothing marking it as not current: a stale total presented as a measurement. Every card now
takes the error and renders an em dash. The one glyph that means "no figure here" is never
produced by a number that failed to arrive.

The related trap on the other side of the same fence: **zero runs is not zero success.**
`successRate` is `double?` and null when `count == 0`, and the card says *no runs in range*.
0/0 has no answer, and answering `0.0%` asserts a measurement that was never taken — the
same lie as the failed-read case, reached from the opposite direction.

---

## The guard shape, and why the obvious one has no teeth

A test asserting the endpoint "does not throw" is **green on the code that 500s on every
request**, because both bugs are exceptions. That is the specific test to avoid, and it is
the one that would have been written by default.

Four reintroductions were run to prove the guards are not vacuous, and the split is the
instructive part:

| Reintroduced | Tests that went red |
|---|---|
| `as int?` + no SQL cast | 6, with `type 'String' is not a subtype of type 'int?'` |
| the quoted map key | **3**, with `type 'Null' is not a subtype of type 'String'` — and the 3 ungrouped tests stayed green |
| client `successRate => 0.0` | 6 |
| client `?? 0` on one wire key | 1 — the divergent-payload guard alone |

The second row is why both layers were fixed and tested separately: the two defects are
independent, and a single test asserting only "the endpoint returns something" would have
been satisfied by fixing either one alone.

The client mapping test builds its payload from the **generated** `ModelStatsView(...).toJson()`
rather than a hand-written map, so a change to the wire type fails there instead of passing
against a map that has quietly stopped matching.

## Larger lesson — framework candidate, NOT persisted here

*Not persisted: `WORKFLOW_IMPROVEMENT` and `AUTOMATION_OPPORTUNITY` require independent
review.*

**A lenient fallback is the repair most likely to convert a visible failure into an invisible
lie.** `?? 0`, `?? const []`, `?? false` are syntactically the smallest possible change to a
throwing cast, and each one removes the only signal that the two sides of a contract have
diverged. The guard that catches this is not "the cast does not throw" — it is "the cast
throws when the key is missing", which is a test that must be written deliberately, because
the behaviour it pins is the absence of the defect rather than the presence of a feature.