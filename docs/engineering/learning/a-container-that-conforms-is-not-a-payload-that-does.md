# A container that conforms is not a payload that does

**Category:** `RUNTIME_DISCOVERY` (verified, executable) · **Authority:** automatic
**Also:** `PROJECT_FACT` — product-specific, stable about this schema.
**Date:** 2026-10-16 · **Reviewed HEAD:** `d8e0b0d` (`DO_NOT_MERGE`) · **Lane:** `correct-IMPL-TRANSITION-ROW-500`
**Companion:** `a-gate-that-protects-a-reader-can-make-the-screen-blank.md`

## What was withdrawn

A data migration was written, reviewed and **deleted**. It repaired the five
`work_item_transition` rows whose `guardEvaluationsJson` holds a repair-metadata
OBJECT instead of the declared ARRAY, by wrapping each non-array value in a
one-element array. Directory `apps/server/migrations/20261015120000000/`, its
registry line, and `test/malformed_guard_evaluation_repair_migration_test.dart`
were removed at `d8e0b0d`'s correction.

It is recorded here because the deletion removes the only place the reasoning
existed, and because the reasoning is reusable against the next agent who
proposes the same repair.

## The finding

**The repair metadata is not a guard evaluation, so no container makes it one.**

`work_item_transition.guardEvaluationsJson` is declared to hold
`TransitionGuardEvaluation` objects. Migration `20261014210000000` wrote its own
**restore payload** there — `jsonb_build_object(...)::text`, the fields its `down`
puts back verbatim. Wrapping that object in a one-element array makes the
**container** legal. The element is still not a `TransitionGuardEvaluation`, and
the reader finds that out one layer in:

```
decodeJsonArray          jsonDecode(value) as List<dynamic>          <- the wrap SATISFIES this
  -> _transitionFromRow   'guardEvaluations': <the list>
    -> WorkflowTransitionRecord.fromJson
      -> generated       (json['guardEvaluations'] as List<dynamic>?)
                             ?.map((e) => TransitionGuardEvaluation.fromJson(
                                 e as Map<String, dynamic>))
      -> generated       guardName: json['guardName'] as String       <- THROWS HERE
```

`packages/platform_contracts/lib/src/types/workflow_transition_record.g.dart:12`
and `:13` (`guardName: json['guardName'] as String`, `passed: json['passed'] as
bool`). The repair payload has **neither** key.

So the 500 does not go away. It moves from `db_row_util.dart` into a generated
constructor, on **exactly the five rows the migration targeted** — and the
migration's own banner said so, in the same file that was shipping it: *"IT IS AN
OBJECT ELEMENT, NOT A GUARD EVALUATION … `TransitionGuardEvaluation.fromJson`
reads `guardName` with `as String` and would reject it."* A document that
describes its own defect is still a defect.

The wrap is worse than doing nothing, and the reason is specific: it satisfies
the **only cast that produced a report**. The reader's
`workflow.transition.guard_evaluations_malformed` line exists because
`readJsonArrayColumn` classifies a non-array column as defective. A conforming
container makes that report **unreachable**, converting a *reported* degradation
into a *silent* crash. The migration would have removed the observability that
proved the migration was wrong.

## The reader half was already a complete fix

`readJsonArrayColumn` in `apps/server/lib/src/persistence/util/db_row_util.dart`
needs no data repair to have been correct:

* a defective column **degrades to absent** — the honest answer, and the one
  `WorkflowTransitionRecord` already maps to `const []`;
* it **reports**, with the row id, the JSON type found, and the offending text —
  so the degradation is never silent;
* it is scoped to the ONE reader that must survive a bad row.
  `decodeJsonArray` is deliberately unchanged and still throws: fourteen call
  sites across six stores hand its result straight to a typed constructor, where
  a silent `null` would be indistinguishable from a genuinely absent value.

The two halves were mutually exclusive. Shipping both was strictly worse than
shipping either, and better than shipping the migration alone.

## Executable

The negative fact is an assertion, not a comment — which is the only reason it
survived the deletion of the code it refuted:

```
dart test apps/server/test/transition_row_malformed_guard_test.dart
```

21 tests, all passing at the corrected HEAD. The load-bearing two:

* group `why the reader degrades to ABSENT rather than wrapping in an array` —
  asserts that the wrapped value is **not** defective at the container *and*
  that `TransitionGuardEvaluation.fromJson` throws on it. The repair shape is
  refuted, not described.
* group `readTransitionHistory — one malformed row no longer fails the read` —
  drives the **real** `PostgresWorkflowStore.readTransitionHistory`, the exact
  method both `workflowEndpoints.inspect` and `defectEndpoints.inspect` reach.

The suite runs against a database double, not PostgreSQL: `make test-integration`
is the only sanctioned way to get a real database and it was not available to the
lane. The file states what it therefore does not prove.

## The lesson worth keeping

**A malformed-data repair is only finished when the repaired value is readable
by the reader that rejected it.** "The failing cast now succeeds" is a weaker
claim than it looks: a cast is one assertion in a chain, and making it pass
locates the next one. Before writing a migration to satisfy a reader, follow the
value through the **whole** read path — here, through a `json_serializable`
constructor this lane did not own and would never have thought to check.

Two tells that this repair was wrong on arrival, both visible without executing
anything:

1. **The repair's own banner refuted it.** Prose asserting that the new shape is
   unreadable was already in the migration. A migration that describes why its
   output cannot be read is a defect with a test plan attached.
2. **Its own test could not see the fault.** The migration test asserted the
   column now decodes as a `List`. That is the assertion the wrap was designed to
   make true, so it could not fail — the test's subject and the repair's goal were
   the same statement. The refutation lived in a *different* file, against the
   *reader*, and the reader was never going to read a repaired row's payload as a
   guard evaluation.

## Larger lesson — framework candidate, NOT persisted here

*Not persisted: `WORKFLOW_IMPROVEMENT` requires independent review.*

**A test that asserts the thing a change was built to achieve cannot detect that
the change was wrong.** Review the assertions of a repair against the *reader*
that rejected the data, not against the column's declared type. Route it to
independent review as a framework improvement candidate.

**Corollary for the correction loop:** the implementer's own test contained the
refutation of the implementer's own migration, in the same commit, and only
independent review surfaced it. Executable knowledge that contradicts a sibling
change in the same commit is the most valuable thing a lane produces — and the
most likely to be deleted with the code it refutes, which is why it must be
persisted outside the diff.
