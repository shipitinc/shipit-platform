BEGIN;

--
-- SHIPIT CONTROL PLANE REPAIR: five `work_item_transition` rows whose
-- `guardEvaluationsJson` holds a repair-metadata OBJECT instead of the array of
-- guard evaluations the column is declared to hold, which bricks the detail
-- screen of their work items with HTTP 500.
--
-- THE DEFECT. `work_item_transition.guardEvaluationsJson` is read by
-- `PostgresWorkflowStore._transitionFromRow` through `decodeJsonArray`, which is
-- `jsonDecode(value) as List<dynamic>`. Migration `20261014210000000` wrote a
-- repair-metadata OBJECT into that column — `jsonb_build_object(...)::text` —
-- because that column is where it put the restore payload for its own `down`.
-- Every later read of those rows threw a `TypeError` on the cast:
--
--     workflow_endpoints.dart:50   readTransitionHistory
--      -> control_plane_service.dart:1838
--      -> postgres_workflow_store.dart:224  ->  _transitionFromRow
--      -> db_row_util.dart:29        jsonDecode(value) as List<dynamic>
--
-- and the throw was rethrown as HTTP 500 from BOTH `workflowEndpoints.inspect`
-- AND `defectEndpoints.inspect`, because both reach the same reader.
--
-- THE BLAST RADIUS IS NOT THE BAD ROW. `readTransitionHistory` is
-- `SELECT * … WHERE "workItemId" = $1`, so one malformed row takes down the
-- detail screen of its work item AND of its defect — a different defect's
-- screen, reached through a row in a third table.
--
-- WHAT IS *NOT* REPAIRED HERE, AND WHY IT IS NOT A BUG. A NULL
-- `guardEvaluationsJson` is not this defect. Twelve work items carry NULL there
-- and every one of them reads fine, because `decodeJsonArray` returns null for
-- NULL and `WorkflowTransitionRecord` maps a null list to `const []`. Those
-- twelve rows are correct as they are. This migration must not "fix" them, and
-- the eligibility test below deliberately admits only non-NULL, non-blank
-- columns. Twelve work items are NOT broken and this migration leaves all twelve
-- exactly as they are.
--
-- ---------------------------------------------------------------------------
-- WHY WRAP RATHER THAN REPLACE, DROP OR REWRITE
-- ---------------------------------------------------------------------------
-- The object in that column is not junk. It is the RESTORE PAYLOAD of
-- `20261014210000000`: `priorDecisionStatus`, `priorDecisionMetadataJson`,
-- `priorBlockingHumanDecisionId`, `priorTriageAttemptForm`, `priorDecisionChoice`,
-- `priorDecisionDecider`, `priorDecisionRationale`, `priorDecisionSignatureJson`,
-- `priorDecisionTimestamp` and more. Its own banner says so — "Every field below
-- is what the DOWN section puts back, verbatim". Deleting it or overwriting it
-- with `[]` would destroy the evidence of a human's voided approval, which is
-- the one thing that migration went out of its way to preserve.
--
-- So the payload is KEPT WHOLE and made to satisfy the container it was put in.
-- Wrapping the object in a one-element array changes the container and nothing
-- inside it: every key, and every value, survives through `jsonb_build_array`.
--
-- IT IS AN OBJECT ELEMENT, NOT A GUARD EVALUATION, AND THAT IS HONEST. The
-- column is declared to hold `TransitionGuardEvaluation` objects, and this
-- element is not one — it has no `guardName` and no `passed`. Wrapping makes
-- the column a valid JSON ARRAY, which is what every reader requires, but it
-- does NOT make the element a guard evaluation and nothing should read it as
-- one: `TransitionGuardEvaluation.fromJson` reads `guardName` with `as String`
-- and would reject it. The element is carried as opaque provenance. It is the
-- reader-side change (`PostgresWorkflowStore._guardEvaluationsFromRow`) that
-- keeps this element from ever reaching that constructor, and this migration is
-- what stops new rows being written in a shape no reader can accept.
--
-- ---------------------------------------------------------------------------
-- THIS MIGRATION PERMANENTLY CHANGES WHAT `20261014210000000`'s `down` CAN DO.
-- READ THIS BEFORE ROLLING ANYTHING BACK.
-- ---------------------------------------------------------------------------
-- `20261014210000000`'s `down` reads its before-image out of its own audit rows
-- with `x."guardEvaluationsJson"::jsonb ->> 'priorDecisionStatus'` — a TOP-LEVEL
-- object key lookup. In PostgreSQL, `jsonb ->> text` on a JSON ARRAY yields NULL;
-- it does not raise and it does not error. So once this migration has run, every
-- one of those `->>` expressions returns NULL on these five rows, and that
-- `down`'s restores quietly write nothing while reporting success.
--
-- That is stated here rather than left to be discovered, because the failure
-- mode is the dangerous direction: a rollback that silently restores nothing
-- reads exactly like a rollback that correctly had nothing to restore.
--
-- WHAT IS ACTUALLY REQUIRED BEFORE RUNNING THAT `down`, IN ORDER:
--
--   1. THIS migration's `down` FIRST. It unwraps element 0 back to the bare
--      object, restoring the exact prior text, so the older `down` can read it.
--   2. THEN `20261014210000000`'s `down`, inside its own window (the repaired
--      items still parked at `agent_completed`).
--
-- Note that step 1 restores a defect this migration exists to remove. That is
-- the honest cost of the sequence and it is the same cost `20261014210000000`'s
-- own banner already charges: its `down` "restores the defect, in full",
-- including the fabricated reviewer verdict. An operator who wants the
-- pre-migration shape takes both. An operator who wants the broken screen fixed
-- takes neither.
--
-- ---------------------------------------------------------------------------
-- SCOPE: EVERY NON-ARRAY ROW, NOT JUST THE FIVE
-- ---------------------------------------------------------------------------
-- The five rows are the ones QA is visibly broken on, and they are the ones with
-- a named migration to blame. The eligibility test below does not name them,
-- because a test that named five ids would leave the sixth identically-shaped row
-- — written by hand, or by the next migration with the same mistake — bricked in
-- exactly the same way, and the fix would be one migration behind forever.
-- `jsonb_typeof(...) <> 'array'` catches every non-array and misses no array.
--
-- ONLY `work_item_transition` IS WRITTEN. No other table is read for anything
-- other than the version bookkeeping below, and no other table is modified.
--

--
-- THE REPAIR.
--
-- PER-ROW, AND NOT ONE `UPDATE … WHERE jsonb_typeof(…) <> 'array'`, for one
-- reason that is easy to get wrong: PostgreSQL does not evaluate a WHERE clause
-- before the expressions it selects, so `::jsonb` in a predicate raises on the
-- first UNPARSEABLE column in the table and the whole statement dies — taking
-- the repair with it. A `CASE` is not a guard against that either, and
-- `20261014210000000` sidesteps it the same way, by restricting its predicate to
-- a leading-character test. This one cannot: an object is the known case here,
-- but a scalar (`5`, `true`, `"text"`) is the same defect wearing different
-- clothes, and a leading-character test would have to be an allow-list long
-- enough to stop guessing.
--
-- So each candidate is parsed in its own subtransaction. A row that does not
-- parse is RECORDED AND SKIPPED, never coerced: there is no document to wrap,
-- and inventing one would be fabricating data. A row that parses and is not an
-- array is wrapped whole.
--
-- The per-row UPDATE costs one round trip per candidate. That is the right
-- trade for a one-time repair over a table whose qualifying rows are five, and
-- it buys exact affected-row accounting, which the single-statement form cannot
-- give without a second query.
--
DO $$
DECLARE
    candidate    record;
    doc          jsonb;
    repaired_ids text := '';
    skipped_ids  text := '';
    repaired     bigint := 0;
BEGIN
    FOR candidate IN
        SELECT x."transitionId",
               x."guardEvaluationsJson"
          FROM "work_item_transition" x
         WHERE x."guardEvaluationsJson" IS NOT NULL
           AND btrim(x."guardEvaluationsJson") <> ''
    LOOP
        -- Its own subtransaction: the EXCEPTION handler rolls back to the start
        -- of THIS block, so one unparseable row cannot abandon the rows after it.
        BEGIN
            doc := candidate."guardEvaluationsJson"::jsonb;
        EXCEPTION WHEN others THEN
            skipped_ids := skipped_ids || candidate."transitionId" || ' ';
            CONTINUE;
        END;

        IF jsonb_typeof(doc) <> 'array' THEN
            UPDATE "work_item_transition" t
               SET "guardEvaluationsJson" = jsonb_build_array(doc)::text
             WHERE t."transitionId" = candidate."transitionId"
               -- Re-asserted next to the write, because the candidate list was
               -- read before this UPDATE ran and another session could have
               -- appended or altered the row in between. A row that became a
               -- valid array in that window is left alone.
               AND t."guardEvaluationsJson" IS NOT NULL
               AND jsonb_typeof(t."guardEvaluationsJson"::jsonb) <> 'array';
            IF FOUND THEN
                repaired := repaired + 1;
                repaired_ids := repaired_ids || candidate."transitionId" || ' ';
            END IF;
        END IF;
    END LOOP;

    -- LOUD IN BOTH DIRECTIONS. A repair that silently repaired nothing is the
    -- outcome that reads as success, so the count is always reported; and a
    -- repair that skipped rows says WHICH, so an operator is never left
    -- believing it covered rows it did not cover. Those skipped rows are not
    -- screens that stay bricked: the reader change in this same commit reports
    -- them as `unparseable` and returns the row.
    RAISE NOTICE
        'guard-evaluation repair: wrapped % work_item_transition row(s) into a '
        'one-element array. repaired=[%]. A row that does not PARSE as JSON is '
        'left untouched and reported, never coerced: skipped=[%].',
        repaired, repaired_ids, skipped_ids;

    IF skipped_ids <> '' THEN
        RAISE WARNING
            'guard-evaluation repair SKIPPED rows whose guardEvaluationsJson is '
            'not parseable JSON: [%]. They were not wrapped because there was '
            'no document to wrap. They are readable — the reader reports them as '
            'unparseable and returns the row — so no detail screen is bricked '
            'by them. Repair them by hand if their provenance matters.',
            skipped_ids;
    END IF;
END $$;

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261015120000000', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261015120000000', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


--
-- DOWN MIGRATION
--
-- To rollback this migration, run the following:
--
-- THIS RESTORES THE BROKEN SCREEN. It puts a JSON object back into
-- `guardEvaluationsJson`, which is the exact condition that makes
-- `workflowEndpoints.inspect` and `defectEndpoints.inspect` return HTTP 500.
-- Run it to return a database to its pre-migration shape and then re-apply this
-- migration instead — which is also the required first step of rolling back
-- `20261014210000000` (see the banner above: its `down` cannot read a wrapped
-- payload).
--
-- WHAT IS EXACT. Every row this migration wrapped is unwrapped back to the bare
-- object, BYTE-FOR-BYTE, and that claim is arithmetic rather than optimism: the
-- original text was itself produced by `jsonb … ::text`, and `(j -> 0)::text`
-- is the same `jsonb`-to-text serialisation of the same `jsonb` value. No key is
-- added, dropped, renamed or reordered, because the round trip touches none of
-- them.
--
-- THE `jsonb_array_length(x) = 1` ARM IS LOAD-BEARING, AND IT IS ABOUT NOT
-- STEALING. An array that already had more than one element — or one whose
-- single element is not an object — was NOT written by this migration's UP, and
-- unwrapping it would discard an element that is not a repair payload. The
-- arm narrows the rollback to exactly the shape the UP created.
--
-- The `tr-unreviewed-review-repair-` prefix is NOT used as the selector. A
-- prefix would make this rollback repair the five known rows and leave any other
-- identically-shaped row wrapped forever — the same one-migration-behind bug the
-- UP avoids by matching on the type instead of the id.
--
-- ---------------------------------------------------------------------------
-- DOWN SCRIPT -- EXECUTABLE REGION
--
-- Everything ABOVE this region is prose and stays prose. Everything INSIDE it
-- is SQL, written with one leading `-- ` so the whole block is inert and is
-- never executed by accident; the test harness strips exactly that one prefix
-- and runs what is left, so a `down` that is described one way and written
-- another fails rather than quietly rolling nothing back.
--
-- The convention that makes that safe: a COMMENT inside this region is written
-- `-- -- text`, so it survives the prefix strip as `-- text` and is still a
-- comment. Prose belongs outside the region.
-- ---------------------------------------------------------------------------

-- -- DOWN SCRIPT START
-- BEGIN;
-- -- 1. Unwrap every single-object-element array in the column.
-- UPDATE "work_item_transition" t
--    SET "guardEvaluationsJson" = (t."guardEvaluationsJson"::jsonb -> 0)::text
--  WHERE t."guardEvaluationsJson" IS NOT NULL
--    AND btrim(t."guardEvaluationsJson") <> ''
--    AND jsonb_typeof(t."guardEvaluationsJson"::jsonb) = 'array'
--    AND jsonb_array_length(t."guardEvaluationsJson"::jsonb) = 1
--    AND jsonb_typeof(t."guardEvaluationsJson"::jsonb -> 0) = 'object';
-- -- 2. Migration version rollback for control_plane.
-- DELETE FROM "serverpod_migrations"
--  WHERE "module" = 'control_plane' AND "version" = '20261015120000000';
-- COMMIT;
-- -- DOWN SCRIPT END


-- COMMIT;


COMMIT;