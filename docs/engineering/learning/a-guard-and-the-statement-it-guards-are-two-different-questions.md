# Repository Learning: a guard and the statement it guards are two different questions

**Feature**: IMPL-B6-CORRECTION-ALL-FIVE (void every fabricated engineering-review decision)
**Date**: 2026-10-15
**HEAD**: `fix/unstick-unreviewable`, migration `20261014210000000`
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic
authority. The framework-candidate half is flagged in the last section and NOT persisted here.

---

## Summary

Migration `20261014210000000` guards its own target set in one statement and acts on it in two
others. Three defects in this correction round were all the same shape: **the guard and the
statements it was guarding disagreed about what "in scope" meant, and nothing about running
both raised.**

Each one shipped past `dart analyze`, past `dart format`, past a green `dart test lib/`, and
past a first integration run that only proved the SQL parsed.

## The three

### 1. The guard skipped; the writer did not

The guard SKIPS an enumerated target whose decision row is absent — there is nothing to void,
and the sibling chain-replay harnesses legitimately seed work items with no decisions. The
work-item `parsed` CTE selected from the target table joined on `work_item` **only**. So with
no decisions at all, it moved all five work items and wrote five audit rows claiming to void
decisions it had never read — with `priorDecisionStatus: null` sitting in the ledger.

Detected by a test asserting the audit ledger is empty. The fix is one `EXISTS` arm, and its
real content is the *why*: the guard and the statement now agree on the same predicate, and
the audit row is the only place a disagreement like that is visible.

### 2. A ledger sentence decided by asking the wrong object

The audit row's `reason` needed to say "the reviewer DID write a real assessment, and it is
voided anyway" for the two targets whose reviewers did real work. It computed that by asking
`human_decision` whether its metadata carried `reviewUnreviewedApprovalVoided`.

Wrong twice over: that is not the marker that records prose, **and** the decision UPDATE that
writes any marker runs *after* the audit INSERT — so the clause could never fire. Two
discarded reviews silently read as three ordinary voids. The right source is
`agent_result.summary`, which is what the metadata's `reviewUnreviewedProsePreservedAt` already
used. Now both read the same thing.

**"I could not check" was the wrong way round: the clause did not say something false, it
said nothing.** A missing branch in a ledger sentence is harder to notice than a wrong one,
and harder still when the code that computes it is the same code that writes the thing it is
describing.

### 3. A banner claiming its own guard does more work than it does

The banner said the second watermark (the job floor) was what makes the fifth target work —
"its marker alone would hand back `:a3`". Measured: that target's marker is **3**, so
`marker + 1 = 4` and the floor changes the answer for **none** of the five. The banner was
overstating its own guard. A test that asserted the overstatement would have passed and been
wrong; the test now asserts the opposite, and pins the honest wording.

The real lesson the fifth target teaches is different and worth more: its marker reads 3 while
the other four read 2, and `:a3` is already held. A repair that copied `2` from its neighbours
would hand back a held key and recreate the strand, **while looking completely correct**.

## What this repository's own tests taught, four times

| defect | found by |
|---|---|
| `'triageAttempt")` — an unterminated literal swallowing the rest of the file | chain replay of a *sibling* test |
| an unclosed `(` around the whole `metadataJson` expression | chain replay, next run |
| `CASE` with `jsonb` and `text` branches | chain replay, next run |
| guard skipped what the writer did not | own migration suite |

The first three were found **only** by the three sibling chain-replay harnesses
(`stranded_key_repair_migration_test`, `onboarding_workspace_postgres_test`,
`product_repoint_migration_test`), which replay the whole chain into a fresh schema. This
file's own suite could not have found any of them: it applies one migration to a schema that
is already built.

That is a genuinely counter-intuitive result — **the tests for migration N are found by the
tests for migrations N-1, N-2 and N-3** — and it is the strongest argument this repository has
for treating a green run of one's own suite as necessary and nowhere near sufficient.

## Two SQL facts that cost a run each

* **`jsonb_build_object` does not sort its keys**, and it renders SQL NULL as `null` while an
  empty string stays `""`. A pinned digest over one therefore separates `signatureJson = ''`
  from `signatureJson IS NULL` — which is how QA actually holds its four pending decisions,
  and how a fixture that "tidied" the empty string to NULL got caught.
* **A `CASE` whose branches are `text` and `jsonb` does not coerce.** It fails to resolve with
  `CASE types jsonb and text cannot be matched`, and it fails at RUN time, not author time.
  `to_jsonb(...)` on both branches fixes it and also keeps an unparseable signature as a JSON
  string rather than refusing the whole migration.

## Framework candidates (NOT persisted here — reported for routing)

1. `AUTOMATION_OPPORTUNITY`: a **syntax/lint pass over every `migrations/*/migration.sql`**
   — balanced parentheses and balanced single-quoted literals per line, ignoring comments.
   Roughly thirty lines, needs no database, and catches defect 1 above instantly. Three
   defects in a row survived to a real database that a static check would have seen.
2. `WORKFLOW_IMPROVEMENT`: when a correction adds a migration, state explicitly that a green
   run of its own suite is insufficient and that the sibling chain-replay suites are the real
   gate. The implementer learned this only by breaking three unrelated tests.
3. `WORKFLOW_IMPROVEMENT`: a `DO $$` guard and the statements it guards should be required to
   share one named predicate — a CTE, a temp table, or a repeated block flagged as
   load-bearing — so "the guard skips it but the writer does not" is not expressible.
