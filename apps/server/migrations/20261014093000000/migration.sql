BEGIN;

--
-- SHIPIT CONTROL PLANE REPAIR: eight defect work items stranded by a CONSUMED
-- triage dedupe key, returned to triage at a fresh attempt.
--
-- THE HYPOTHESIS THIS MIGRATION IS TESTING. Read this before changing
-- anything, and read it again if the repair turns out to be a no-op.
--
-- The implementation lane is deployed, wired and REACHABLE (951d7db) and
-- `sched-impl` ticks, but nothing moves. The OD-10 completion inflow decides
-- "did the producer leave a commit?" by asking whether the item's
-- `agentExecuting` window produced an `agent_execution` row, and measured live
-- against QA it finds:
--
--     worker_execution        27
--     agent_execution          0
--     model_execution_record  21
--
-- `agent_execution` has NO ROWS AT ALL. So the inflow cannot be reading a
-- write path that merely failed to fire on these items -- there is nothing for
-- it to read. The operating hypothesis is therefore that these eight items
-- PREDATE `agent_execution` entirely: they reached a terminal-looking state
-- through a route that never wrote one, and they are stranded for the ordinary,
-- already-diagnosed reason -- a consumed triage dedupe key -- rather than for
-- anything to do with the inflow.
--
-- WHAT A NO-OP RESULT WOULD MEAN, STATED PLAINLY. If this migration repairs
-- zero rows, the hypothesis is REFUTED, not merely unproven: the eight items
-- are where they were and their keys were never the thing holding them. At
-- that point the defect is the WRITE PATH that should have minted an
-- `agent_execution` row for every `agentExecuting` window and did not, and
-- no further data repair can substitute for fixing it. The counts above are
-- what tells the two apart, which is why they are recorded here rather than
-- only in a commit message.
--
-- WHY THE TWO EFFECTS ARE NEEDED, AND WHY BOTH. A triage attempt is dispatched
-- only when the item sits in a `triageDefectDefinition` entry state
-- (packages/scheduler/lib/src/triage_defect.dart:58-64 --
-- {designNotRequired, designApproved, reviewRejected}) AND the scheduler can
-- take the dedupe key. Both halves are broken for this set, differently:
--
--   * STATE. `agent_failed` is in NO wired `JobDefinition.entryStates` -- the
--     only `agent_*` entry state wired anywhere is
--     `engineeringReviewDefinition`'s `agentCompleted`
--     (packages/scheduler/lib/src/scheduler.dart:2166) -- so nothing ever
--     claims it. It is a permanent dead end, the same dead end
--     20261012150000000 rescued for `agent_executing`. `agent_completed` is
--     NOT in that position: it IS that wired entry state, so for the two
--     `agent_completed` items the STATE was never the blocker.
--
-- THE TWO `agent_completed` ITEMS WERE BLOCKED BY A KEY AS WELL, AND THIS
-- REPAIR DOES NOT REACH THAT KEY. Their blocker was a CONSUMED
-- `engineering_review` dedupe key. `engineeringReviewDedupeKey`
-- (packages/scheduler/lib/src/scheduler.dart:2187-2188) is
-- `'<workItemId>:<jobType.wire>'` -- `engineering_review` -- with NO attempt
-- suffix, where `triageDefectDedupeKey` appends `':a<n>'`. So the moment a
-- terminal `engineering_review` job exists for an item, that key is consumed
-- FOR EVER, exactly like the triage key, and NO attempt discriminator can mint
-- another one: the unsuffixed form has nothing left to vary. Returning these
-- two to triage -- the stated goal of this migration, and still the right
-- thing to do -- runs triage again and carries them back to `agent_completed`,
-- which is triage's exit state, where they MAY RE-STRAND ON THE REVIEW KEY.
-- The monitoring plan has to expect exactly that, and this migration must NOT
-- be reported as having repaired it: it advances the TRIAGE key and touches no
-- `engineering_review` key at all. The `agent_completed -> design_not_required`
-- edge is absent too -- which is what lets this repair move them out of that
-- state in the first place -- but that moves them PAST the strand, not out of
-- it.
--   * KEY. `triageDefectDedupeKey`
--     (packages/scheduler/lib/src/triage_defect.dart:118-123) builds
--     `'<workItemId>:triage_defect'`, plus `':a<n>'` when
--     `metadata['triageAttempt']` is readable. `JobQueue.enqueueIfAbsent`
--     refuses a key that ANY job already holds other than a CANCELLED one, so
--     once a triage attempt has run to a terminal state its key is consumed
--     FOR EVER and every subsequent tick returns `created: false`. Fixing only
--     the state leaves the item dispatchable and inert; fixing only the key
--     leaves it inert in a state nothing claims.
--
-- THIS IS THE THIRD TIME. Both mechanisms have precedent in this repository
-- and this migration reuses them rather than inventing a third convention:
--
--   * 20261012195523112 advanced `metadata.triageAttempt` so a FRESH `:aN`
--     suffix is generated on an otherwise consumed key.
--   * 20261012150000000 moved a stranded item to `design_not_required`, which
--     is `triageDefectDefinition`'s entry state, so the scheduler claims it.
--
-- Neither prior migration could be reused verbatim: the first's selection is a
-- predicate over whatever is AT a triage entry state (so it can only repair
-- items already parked there, and cannot move anything), and the second's is
-- `state = 'agent_executing'` (a different stranded state, and far too broad to
-- point at named rows). The mechanisms are reused; the selection is replaced
-- by the explicit enumeration below, for the reason given under TARGETING.
--
-- THIS MIGRATION IS A ONE-TIME RESCUE AND NOTHING ELSE. It adds no product
-- code, changes no edge, and is NOT a general "re-dispatch stranded items"
-- mechanism. There is no predicate here that could find a ninth item.
--
-- TARGETING. EIGHT LITERAL IDS, AND NOTHING ELSE MAY SELECT A ROW.
--
-- `workItemId IN (...)` -- and, per id, an expected pre-repair state -- is the
-- whole selection. There is deliberately NO `state = 'agent_failed'` arm and no
-- other predicate broad enough to reach an item that was created after this
-- migration was dispatched. A broad predicate would be safe only at the instant
-- it was written and would silently widen on every subsequent apply; an
-- enumerated list cannot. The list was read off QA at dispatch, and the
-- `expectedState` beside each id is the state that item held then.
--
-- THE LIST IS DECLARED EXACTLY ONCE. The `stranded_key_repair_target` temp
-- table below is the single definition of the target set, and the fail-loud
-- guard and the UPDATE both read it. Spelling the eight ids out a second time
-- in the guard is how a guard and the statement it guards drift apart and end
-- up testing a different set than the one being written -- which is a guard
-- that passes for the wrong reason. `ON COMMIT DROP` and the surrounding
-- transaction mean the table cannot outlive this migration in any session.
--
-- THE `expectedState` ARM IS ALSO THE COMPARE-AND-SWAP. An item that moved on
-- its own between dispatch and apply is left completely alone -- it is no
-- longer stranded, and rewriting its state back would resurrect a defect
-- someone already fixed. The arm is re-asserted in the UPDATE, next to the
-- `version` and marker compare-and-swaps, for the same reason 20261012150000000
-- re-asserted its state there: a concurrent writer that moved the item between
-- the selection and the update must not be overwritten.
--
-- IDEMPOTENT, BY ID AND NOT BY STATE. A second run matches zero rows and
-- writes zero rows, for three independent reasons, any one of which suffices:
--
--   (a) every repaired item now carries this migration's audit row, and the
--       selection excludes any id whose `tr-stranded-key-repair-<id>` already
--       exists. This is the arm that makes the property hold under a FORCED
--       replay too -- including one that re-runs against items the scheduler
--       has since moved on, where the state arm alone would no longer match.
--   (b) an item whose state still matches is by definition one that was never
--       repaired, so the state arm cannot double-apply either.
--   (c) the new dedupe key has no holder, so the condition 20261012195523112
--       repairs by is gone -- see THE NEW ATTEMPT IS NOT A CONSTANT.
--
-- (a) also makes the property hold under CONCURRENCY. Two appliers cannot
-- both write: the second blocks on the row lock, and on READ COMMITTED
-- PostgreSQL re-evaluates the UPDATE's WHERE against the newly committed row,
-- sees this migration's audit row, and matches nothing. The `transitionId`s
-- are deterministic rather than random, so even a replay that bypassed the
-- arm entirely would collide on `work_item_transition_id_unique` and abort
-- loudly rather than write a second, differently-named audit row.
--
-- FAIL LOUDLY, ON TWO CONDITIONS, ROLLING BACK ALL EIGHT.
--
-- Neither of these is a "skip it" case, and the difference from 20261012195523112
-- is deliberate and is explained at the end of this banner:
--
--   * A MISSING QA CONTRACT. All eight were verified to carry one at dispatch.
--     If one does not at apply time, the `agentExecuting -> agentCompleted`
--     guard `GuardConditions.qaContractExists()`
--     (packages/workflow_engine/lib/src/validation/guard_conditions.dart:29)
--     will refuse the transition when the re-triaged item tries to finish, and
--     the item will sit in `agentExecuting` forever -- a WORSE strand than the
--     one being repaired, created by the repair. Better that the migration
--     refuses to move anything and says which id and why.
--   * METADATA THAT CANNOT BE MERGED. The marker is written with a jsonb `||`,
--     which MERGES and never replaces -- the defect payload the triage
--     instruction reads must survive, or the retried job classifies nothing
--     while looking healthy. `work_item.metadataJson` is nullable `text` and is
--     NOT guaranteed to hold parseable JSON: the `draft` item
--     `WI-feature-1791686174076431` carries the EMPTY STRING, and
--     `''::jsonb` raises. For an UNPARSEABLE or non-object value there is
--     nothing safe to write: the only way to stamp a marker is to overwrite the
--     whole document, which is silent destruction of whatever was there.
--
-- Because both raise inside the surrounding transaction, the failure mode is
-- all-or-nothing: the other seven are NOT repaired either, and nothing at all
-- changes. That is the intended trade. A partial repair is invisible -- it
-- leaves a mix of repaired and unrepaired items with no marker distinguishing
-- them -- and it is not recoverable without re-dispatching this migration by
-- hand against a corrected list.
--
-- THE ONE CASE THAT IS STILL SKIPPED: AN UNREADABLE `triageAttempt` MARKER.
-- Here this migration follows 20261012195523112 and skips rather than raises,
-- for the reasons that migration records in full: such an item is not silently
-- stranded (`triageDefectDedupeKey` THROWS on it every tick, by design, and
-- that loud failure is the signal that something wrote a bad marker); the
-- required new value is undefined for it; and `operatorRetry` computes the
-- marker before its write precisely so an unreadable one fails with nothing
-- written. The diagnostic query in the DOWN MIGRATION section below lists any
-- such row without raising.
--
-- THE NEW ATTEMPT IS NOT A CONSTANT, AND IT IS NOT GUESSED.
-- `greatest(<marker>, <max attempt encoded in this item's triage job dedupe
-- keys>) + 1`. The second term is what makes the result PROVABLY UNHELD: the
-- only place an attempt number can already have a holder is a job, so taking
-- the max over the jobs as well means the key this writes cannot be a key
-- somebody already consumed. It mirrors `DurableWorkflowEngine.nextTriageAttempt`
-- (packages/workflow_store/lib/src/durable_workflow_engine.dart:384-385),
-- which takes exactly this second watermark from the caller, and
-- `operatorRetry` passes its operator-action ledger count the same way.
--
-- For the five `agent_failed` items the marker is ABSENT, which
-- `readTriageAttempt` reports as `null` and which resolves to the bare
-- unsuffixed key. That is handled explicitly rather than assumed away: `absent`
-- contributes `COALESCE(marker, 0)` to the `greatest`, so the arithmetic yields
-- `:a1` for such an item unless a `:aN` key is already consumed for it, in
-- which case the job floor carries it higher. Nothing here reads a marker that
-- might not be there.
--
-- THE MARKER IS READ BY REPLICATING `DurableWorkflowEngine.readTriageAttempt`,
-- not by re-deciding which shapes are attempts. That reader accepts an `int`, a
-- whole-valued `double` (a `1.0` is attempt one) and a numeric `String`, and
-- throws `FormatException` on anything else. The `CASE` in the "marker" CTE
-- encodes those same arms: jsonb `number` with an integral literal text, jsonb
-- `number` that is whole-valued, jsonb `string` matching
-- `^[+-]?[0-9]{1,18}$` (Dart `int.tryParse` accepts an optional sign and digits
-- only -- no spaces, no decimals, no exponent -- and the 18-digit cap keeps the
-- value inside the 64-bit range Dart parses into). A second copy of "how a
-- marker is read" is exactly how a writer and a reader come to disagree about
-- which numbers are attempts, and the disagreement would not throw here -- it
-- would build a different key and enqueue nothing. An ABSENT key and an
-- EXPLICIT JSON null both mean `null` to the Dart reader, so both normalise to
-- the bare key here; treating an explicit null as unreadable would make this
-- repair skip an item the scheduler is about to strand on that bare key.
--
-- PLAN-ORDER INDEPENDENCE OF THE `metadataJson` CAST. The cast is confined to
-- the ELSE branch of a `CASE`, which PostgreSQL documents to evaluate in order
-- and not to evaluate an unselected branch at all, so the guard holds under ANY
-- plan. The guard also rejects any value not opening with `{`, which is a
-- NECESSARY condition for a valid metadata document (`WorkItem.metadata` is a
-- `Map<String, dynamic>`) and therefore excludes nothing legitimate.
--
-- NON-COLLIDING ID CONVENTION. `transitionId` is
-- `tr-stranded-key-repair-<workItemId>` and `idempotencyKey` is
-- `stranded-key-repair:consumed-triage-dedupe-key`. Both are fresh. The three
-- earlier repairs in this repository wrote `tr-stranded-repair-<id>`
-- (20261012145629000), `tr-stranded-exec-repair-<id>` (20261012150000000) and
-- `tr-dedupe-bump-repair-<id>` (20261012195523112), and reusing any of those
-- prefixes would violate `work_item_transition_id_unique` or
-- `work_item_transition_idempotency_unique` and abort the migration. Note also
-- that `tr-stranded-key-repair-<id>` is NOT matched by `LIKE
-- 'tr-stranded-repair-%'`: the thirteenth character is `k`, not `r`. The
-- earlier repairs' DOWN migrations delete by that pattern, and this migration's
-- rows must survive one of them being rolled back, and vice versa.
--
-- WHAT IS AND IS NOT WRITTEN. `work_item.state`, `metadataJson`, `updatedAt`
-- and `version`, plus one audit row per repaired item. No other table.
-- In particular:
--
--   * No `job` row is touched, so a repaired item enqueues against a FRESH key
--     rather than resuming anything, and the terminal triage jobs that stranded
--     it are left exactly as they are.
--   * No `worker_execution`, `agent_execution` or `model_execution_record` row
--     is touched. That is the point: the hypothesis under test is that these
--     items predate `agent_execution`, and manufacturing one here would destroy
--     the measurement.
--   * `pinnedRevision`, `workspace`, producer anchors, `qaContractId`,
--     `designContractId`, `agentSessionId`, `artifactRefsJson` and the
--     transition history are all untouched. This is a key repair, not a
--     re-provisioning.
--   * `completedAt` and `terminatedAt` are deliberately left alone, as in
--     20261012150000000: the engine writes them only on entering `completed`
--     and `terminated`, neither of which is a state any of these eight rows
--     holds, so they are NULL here and remain NULL.
--   * The jsonb `||` MERGES the marker and never replaces the document.
--
-- `version` is incremented and `updatedAt` set, exactly as a real transition
-- writes them, so the engine's compare-and-swap on `version` still behaves.
--
-- SAFETY / DATA LOSS: this migration deletes nothing and overwrites no payload.
-- It advances one monotonically increasing integer and rewrites one state value
-- on eight named rows that are stranded by definition, and the audit rows it
-- writes are the record of that. Every statement is inside the surrounding
-- transaction, so a failure rolls back the state moves, the marker writes and
-- the audit rows together -- there is no reachable state in which an item moved
-- with no audit row describing it, and no reachable state in which seven items
-- were repaired and the eighth was not.

-- `DROP ... IF EXISTS` is belt-and-braces for a replay inside ONE session:
-- `ON COMMIT DROP` already covers the committed and the rolled-back paths, and
-- this covers neither having run yet.
DROP TABLE IF EXISTS "shipit_stranded_key_repair_target";

CREATE TEMP TABLE "shipit_stranded_key_repair_target" (
    "workItemId"    text PRIMARY KEY,
    "expectedState" text NOT NULL
) ON COMMIT DROP;

-- THE TARGET SET. Eight ids, each with the state it held when this set was read
-- off QA. Changing a row here changes what the migration does; there is no
-- second copy of this list anywhere in the file.
--
--   workItemId                       state                  triageAttempt  qaContract
--   defect-DEF-1791684804452198       agent_completed        3              yes
--   defect-DEF-1791686704991884       agent_completed        3              yes
--   defect-DEF-1791686085546076       design_not_required    2              yes
--   defect-DEF-1791684557133597       agent_failed           absent         yes
--   defect-DEF-1791685024220546       agent_failed           absent         yes
--   defect-DEF-1791685264570406       agent_failed           absent         yes
--   defect-DEF-1791685722309971       agent_failed           absent         yes
--   defect-DEF-1791685924503981       agent_failed           absent         yes
--
-- NOT IN SCOPE, and matched by no predicate in this file: three `planned` items
-- and one `draft` item. They are not stranded; they are awaiting intake, and a
-- migration that moved them would start work nobody asked for.
--
-- `defect-DEF-1791686085546076` is ALREADY in `design_not_required`, so for it
-- the state arm is a no-op and only the marker is advanced. That is correct,
-- not a mistake: it is stranded on a consumed key exactly like the rest, and
-- it is the one item in the set for which the prior art's selection (state in
-- `entryStates`) would have matched on its own.
INSERT INTO "shipit_stranded_key_repair_target"
    ("workItemId", "expectedState")
VALUES
    ('defect-DEF-1791684804452198', 'agent_completed'),
    ('defect-DEF-1791686704991884', 'agent_completed'),
    ('defect-DEF-1791686085546076', 'design_not_required'),
    ('defect-DEF-1791684557133597', 'agent_failed'),
    ('defect-DEF-1791685024220546', 'agent_failed'),
    ('defect-DEF-1791685264570406', 'agent_failed'),
    ('defect-DEF-1791685722309971', 'agent_failed'),
    ('defect-DEF-1791685924503981', 'agent_failed');

--
-- FAIL LOUDLY. Refuse the whole migration, naming every offending id, rather
-- than repairing an item that cannot finish (no QA contract) or whose payload
-- cannot be merged (unparseable / non-object metadataJson).
--
-- "IN SCOPE" MEANS EXACTLY WHAT THE UPDATE MEANS: the id is in the target
-- table, the row exists, its state is still the expected one, and this
-- migration's audit row is not already present. An item that has moved on is
-- not reported and not touched -- there is nothing wrong with it any more.
--
-- The metadata check is a `BEGIN ... EXCEPTION` block rather than a boolean
-- expression because there is no way to ask "does this text parse as JSON?"
-- without attempting the cast, and `''::jsonb` raises. Catching the raise is
-- what turns an unparseable payload into a reported id instead of an aborted
-- statement whose message names no work item.
DO $$
DECLARE
    r         record;
    meta      jsonb;
    offenders text := '';
BEGIN
    FOR r IN
        SELECT t."workItemId"
          FROM "shipit_stranded_key_repair_target" t
          JOIN work_item w
            ON w."workItemId" = t."workItemId"
           AND w."state"     = t."expectedState"
         WHERE NOT EXISTS (
                   SELECT 1
                     FROM "work_item_transition" x
                    WHERE x."transitionId" =
                              'tr-stranded-key-repair-' || t."workItemId"
               )
    LOOP
        IF (SELECT w."qaContractId" IS NULL
              FROM work_item w
             WHERE w."workItemId" = r."workItemId") THEN
            offenders := offenders
                         || r."workItemId" || ' [no qa_contract], ';
        END IF;

        meta := NULL;
        BEGIN
            SELECT w."metadataJson"::jsonb
              INTO meta
              FROM work_item w
             WHERE w."workItemId" = r."workItemId";
        EXCEPTION WHEN others THEN
            offenders := offenders
                         || r."workItemId"
                         || ' [metadataJson is not parseable JSON: '
                         || coalesce(left((
                                SELECT w."metadataJson"
                                  FROM work_item w
                                 WHERE w."workItemId" = r."workItemId"), 80), '<null>')
                         || '], ';
        END;

        IF meta IS NOT NULL AND jsonb_typeof(meta) <> 'object' THEN
            offenders := offenders
                         || r."workItemId"
                         || ' [metadataJson is JSON '
                         || jsonb_typeof(meta)
                         || ', not an object], ';
        END IF;
    END LOOP;

    IF offenders <> '' THEN
        RAISE EXCEPTION
            'stranded-key-repair refused: % . Every in-scope work item must '
            'carry a QA contract (GuardConditions.qaContractExists() refuses '
            'agentExecuting -> agentCompleted without one) and a metadataJson '
            'that is a JSON object (the triageAttempt marker is merged with a '
            'jsonb ||, never written over the document). Nothing was changed.',
            left(offenders, length(offenders) - 2);
    END IF;
END $$;

WITH "parsed" AS (
    -- Only the eight named rows are parsed, and only while they still hold
    -- their expected state. The CASE guard confines the cast to rows whose
    -- metadataJson opens with `{`, so an unparseable value can never raise
    -- here regardless of the plan -- and the DO block above has already
    -- refused the migration outright if one of the eight carries such a value.
    SELECT w."workItemId",
           w."state",
           w."version",
           t."expectedState",
           (CASE
                WHEN w."metadataJson" IS NULL
                  OR btrim(w."metadataJson") = ''
                  OR btrim(w."metadataJson") NOT LIKE '{%'
                THEN NULL
                ELSE w."metadataJson"::jsonb
             END) AS "meta"
      FROM "shipit_stranded_key_repair_target" t
      JOIN work_item w
        ON w."workItemId" = t."workItemId"
     WHERE w."state" = t."expectedState"
       -- IDEMPOTENCE BY ID. This arm, not the state arm, is what makes a
       -- FORCED replay a no-op: an item the scheduler has since moved on no
       -- longer matches `expectedState`, and without this line it would be
       -- repaired twice -- advancing its marker a second time and colliding
       -- on the audit row.
       AND NOT EXISTS (
               SELECT 1
                 FROM "work_item_transition" x
                WHERE x."transitionId" =
                          'tr-stranded-key-repair-' || w."workItemId"
           )
),
"marker" AS (
    -- Replicates DurableWorkflowEngine.readTriageAttempt. An ABSENT key and an
    -- EXPLICIT JSON null both mean the same thing to the Dart reader, which
    -- returns null for both and therefore resolves to the bare unsuffixed key;
    -- the first arm tests the missing key (jsonb_typeof -> NULL) and the
    -- second the literal JSON null (jsonb_typeof -> 'null').
    SELECT p."workItemId",
           p."state",
           p."version",
           p."expectedState",
           p."meta",
           (CASE
                WHEN jsonb_typeof(p."meta" -> 'triageAttempt') IS NULL
                    THEN 'absent'
                WHEN jsonb_typeof(p."meta" -> 'triageAttempt') = 'null'
                    THEN 'absent'
                WHEN jsonb_typeof(p."meta" -> 'triageAttempt') = 'number'
                     AND (p."meta" ->> 'triageAttempt') ~ '^-?[0-9]{1,18}$'
                    THEN 'int'
                WHEN jsonb_typeof(p."meta" -> 'triageAttempt') = 'number'
                     AND (p."meta" ->> 'triageAttempt')
                         ~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$'
                     AND (p."meta" ->> 'triageAttempt')::numeric
                         = trunc((p."meta" ->> 'triageAttempt')::numeric)
                     AND abs((p."meta" ->> 'triageAttempt')::numeric)
                         < 1000000000000000000
                    THEN 'whole-double'
                WHEN jsonb_typeof(p."meta" -> 'triageAttempt') = 'string'
                     AND (p."meta" ->> 'triageAttempt') ~ '^[+-]?[0-9]{1,18}$'
                    THEN 'numeric-string'
                ELSE 'unreadable'
             END) AS "markerForm"
      FROM "parsed" p
),
"attempted" AS (
    SELECT m."workItemId",
           m."state",
           m."version",
           m."expectedState",
           m."meta",
           m."markerForm",
           (CASE
                WHEN m."markerForm" = 'int'            THEN (m."meta" ->> 'triageAttempt')::bigint
                WHEN m."markerForm" = 'whole-double'   THEN trunc((m."meta" ->> 'triageAttempt')::numeric)::bigint
                WHEN m."markerForm" = 'numeric-string' THEN (m."meta" ->> 'triageAttempt')::bigint
                ELSE NULL
             END) AS "markerAttempt"
      FROM "marker" m
),
"keyed" AS (
    -- The key this item currently computes, and the highest attempt number its
    -- triage jobs have already consumed. The floor is what makes the new key
    -- provably unheld.
    SELECT a."workItemId",
           a."state",
           a."version",
           a."expectedState",
           a."meta",
           a."markerForm",
           a."markerAttempt",
           a."workItemId" || ':triage_defect'
             || (CASE WHEN a."markerForm" = 'absent'
                      THEN '' ELSE ':a' || a."markerAttempt" END)
             AS "currentKey",
           COALESCE((
               SELECT max(CASE
                            WHEN substring(j."dedupeKey"
                                            from ':triage_defect:a(.*)$')
                                      ~ '^[0-9]{1,18}$'
                            THEN substring(j."dedupeKey"
                                            from ':triage_defect:a(.*)$')::bigint
                          END)
                 FROM job j
                WHERE j."workItemId" = a."workItemId"
                  AND j."jobType" = 'triage_defect'
           ), 0) AS "jobFloor"
      FROM "attempted" a
),
"selected" AS (
    SELECT k."workItemId",
           k."state",
           k."version",
           k."expectedState",
           k."meta",
           k."markerForm",
           k."markerAttempt",
           k."currentKey",
           k."jobFloor",
           greatest(COALESCE(k."markerAttempt", 0), k."jobFloor") + 1
             AS "newAttempt"
      FROM "keyed" k
     -- An unreadable marker is skipped, not repaired -- see the banner. Such an
     -- item already fails loudly in triageDefectDedupeKey on every tick, and
     -- the value that should replace it is undefined.
     WHERE k."markerForm" <> 'unreadable'
),
"repaired" AS (
    UPDATE work_item w
       SET -- jsonb `||` MERGES, never replaces: the defect payload the triage
           -- instruction reads must survive or the retried job classifies
           -- nothing while looking healthy.
           "state" = 'design_not_required',
           "metadataJson" = (COALESCE(s."meta", '{}'::jsonb)
                             || jsonb_build_object('triageAttempt',
                                                   s."newAttempt"))::text,
           "updatedAt" = now(),
           "version" = w."version" + 1
      FROM "selected" s
     WHERE w."workItemId" = s."workItemId"
       -- Re-asserted: after this row is locked, a concurrent writer that moved
       -- the item must not be overwritten. `version` is the compare-and-swap
       -- the engine itself uses, the state is the selection predicate, and the
       -- marker is re-asserted because that is the column being written.
       AND w."version" = s."version"
       AND w."state" = s."expectedState"
       AND (CASE
               WHEN w."metadataJson" IS NULL
                 OR btrim(w."metadataJson") = ''
                 OR btrim(w."metadataJson") NOT LIKE '{%'
               THEN NULL
               -- An explicit JSON null normalises to SQL NULL here so it
               -- compares equal to the NULL the selection carried for an
               -- 'absent' marker. Without this, an item whose marker is
               -- `"triageAttempt": null` would pass the selection and then
               -- never be updated -- silently unrepaired.
               WHEN jsonb_typeof(w."metadataJson"::jsonb -> 'triageAttempt')
                       = 'null'
               THEN NULL
               ELSE w."metadataJson"::jsonb -> 'triageAttempt'
            END) IS NOT DISTINCT FROM
           (CASE WHEN s."markerForm" = 'absent'
                 THEN NULL
                 ELSE s."meta" -> 'triageAttempt'
            END)
     RETURNING w."workItemId",
               s."state"         AS "fromState",
               s."markerForm",
               s."markerAttempt",
               s."jobFloor",
               s."newAttempt",
               s."currentKey"
)
INSERT INTO "work_item_transition"
    ("transitionId", "workItemId", "fromState", "toState", "trigger", "actorType",
     "actorId", "decisionId", "outcome", "reason", "guardEvaluationsJson",
     "idempotencyKey", "occurredAt")
SELECT 'tr-stranded-key-repair-' || "workItemId",
       "workItemId",
       "fromState",
       'design_not_required',
       'system_event',
       'orchestrator',
       'orchestrator',
       NULL,
       'accepted',
       'One-time data repair (IMPL-A6-STRANDED-KEY-REPAIR). Hypothesis under '
       'test: this item PREDATES agent_execution -- agent_execution holds no '
       'rows at all in QA (27 worker_execution, 0 agent_execution, 21 '
       'model_execution_record) -- so the OD-10 completion inflow has nothing '
       'to read for it and the item is stranded for the ordinary reason: '
       'triageDefectDedupeKey builds ' || "currentKey" || ' and '
       'JobQueue.enqueueIfAbsent refuses a key any job already holds, so no '
       'triage job is ever enqueued for it. Two repairs, both reusing proven '
       'mechanisms (20261012195523112 for the marker, 20261012150000000 for '
       'the state): advanced metadata.triageAttempt from '
       || COALESCE("markerAttempt"::text, 'absent') || ' to ' ||
       "newAttempt"::text || ', giving the provably unheld key ' ||
       "workItemId" || ':triage_defect:a' || "newAttempt"::text ||
       ' (greater than both the marker and the highest attempt already '
       'consumed by this item''s triage job keys, which was ' ||
       "jobFloor"::text || '); and moved state to design_not_required, the '
        'triageDefectDefinition entry state, so the scheduler claims it. State '
        'written directly: NO agent_completed -> design_not_required edge '
        'exists, which is why that state is written straight into the column. '
        'For the five agent_failed items this is NOT a bypass of the state '
        'machine -- agent_failed -> design_not_required DOES exist '
        '(packages/workflow_engine/lib/src/transitions/'
        'work_item_transitions.dart:149-151, guarded only by '
        'actorAllowed([orchestrator])) -- and it is bypassed DELIBERATELY, '
        'because that edge writes the state and nothing else, while this '
        'repair must ALSO advance metadata.triageAttempt to mint an unheld '
        'dedupe key. No transition edge carries a metadata merge at all: the '
        'marker is advanced by the engine''s own operations '
        '(DurableWorkflowEngine.operatorRetry and resolveHumanDecision), never '
        'by an edge, so no agent_failed -> design_not_required edge could have '
        'performed this repair. No job, '
       'worker_execution, agent_execution or model_execution_record row was '
       'touched -- manufacturing one here would destroy the measurement this '
       'repair exists to make possible. No payload was overwritten: this '
       'migration writes two columns of work_item and nothing else, so the '
       'defect payload in metadataJson (merged, never replaced), the producer '
       'anchors, qaContractId, the transition history, completedAt/ '
       'terminatedAt and the onboarding_record pinnedRevision/workspace are '
       'all untouched. ' ||
       CASE WHEN "fromState" = 'design_not_required'
            THEN ' This item was ALREADY in design_not_required, so only the '
                 'marker was advanced and from_state equals to_state; it was '
                 'stranded on a consumed key like the rest of the set.'
            ELSE ''
       END,
       NULL,
       'stranded-key-repair:consumed-triage-dedupe-key',
       now()
  FROM "repaired";

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261014093000000', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261014093000000', "timestamp" = now();

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
-- WARNING: this restores the defect. Each item goes back to the state it held
-- and to computing the key a terminal triage job already holds, and nothing
-- will ever dispatch them again -- but the two reasons are NOT the same, and
-- collapsing them was the error corrected above. The five `agent_failed`
-- items go back to a state in NO wired JobDefinition.entryStates. The two
-- `agent_completed` items go back to a state that IS a wired entry state
-- (`engineeringReviewDefinition`, see above), and stay stranded because the
-- CONSUMED, UNSUFFIXED `engineering_review` key leaves
-- `engineeringReviewDedupeKey` with no fresh key to offer. Either way that is
-- precisely how they were stranded. Run it only to return a database to its
-- pre-migration shape, then re-apply this migration instead.
--
-- THE STATEMENT ORDER BELOW IS THE REVERSE OF THE EARLIER REPAIRS', AND THAT
-- IS A FIX, NOT A COSMETIC DIFFERENCE. 20261012150000000 and
-- 20261012195523112 both DELETE the audit rows FIRST and then run an UPDATE
-- whose EXISTS arm keys off those same audit rows -- so by the time the UPDATE
-- runs, the rows it is looking for are already gone and it restores NOTHING.
-- Read those two DOWN sections and the bug is invisible: the statements look
-- right in isolation. Here the restore runs FIRST and the audit rows are
-- deleted after it, which is the only order in which the EXISTS/JOIN arms can
-- match anything.
--
-- THE RESTORE READS `fromState` BACK OFF THE AUDIT ROW rather than naming a
-- literal, because the eight targets do not share one starting state --
-- agent_completed, agent_failed and (for one item) design_not_required. A
-- single hard-coded literal could only ever be right for a subset.
--
-- The marker is DECREMENTED rather than deleted, and that is deliberate.
-- Deleting it would put these items on the BARE key -- which the terminal
-- triage job that stranded them still holds -- so a rollback that merely
-- removed the key would leave the item no less stranded than before, and would
-- destroy the record of how many attempts had been consumed. The EXISTS arm
-- keeps the step confined to rows carrying this migration's audit row.
--
-- WHAT THE DECREMENT DOES AND DOES NOT RESTORE, STATED PLAINLY. The statement
-- computes `COALESCE(meta->>'triageAttempt','0')::bigint - 1`, so it restores
-- the pre-migration marker ONLY for a row that arrived with a READABLE marker
-- at or above the job floor -- in which case `newAttempt` was `marker + 1` and
-- the step lands back exactly on `marker`. It does NOT restore the
-- pre-migration value in either of the other two cases:
--
--   * A row whose marker was ABSENT (the five `agent_failed` items) gets a
--     NUMBER where it had none. `newAttempt` is `greatest(0, jobFloor) + 1`, so
--     the step writes `triageAttempt: 0` when the floor is 0 and
--     `triageAttempt: <jobFloor>` when the floor is higher. Absent and 0 mean
--     the same thing to `readTriageAttempt`, which is why the difference does
--     not bite -- but they are not the same stored value, and this comment
--     must not claim they are.
--   * A row whose marker was readable but BELOW the job floor is also not
--     restored: `newAttempt` was `jobFloor + 1`, so the step writes `jobFloor`
--     rather than the smaller marker the row arrived with.
--
-- This is BEHAVIOURALLY HARMLESS, and the limit is recorded rather than papered
-- over: every row the above applies to is restored to `agent_failed`, which no
-- `JobDefinition` claims, so it is stranded either way and the marker it ends
-- up carrying changes nothing about that. It is still worth stating, because
-- "this DOWN is commented out and never auto-executed" is not a reason for a
-- comment inside it to be false. THE ARITHMETIC IS DELIBERATELY LEFT EXACTLY
-- AS WRITTEN: making the restore faithful for `absent` is a change to the
-- rollback's semantics and needs its own decision, not a silent edit made
-- inside a correction.
--
-- THE FIRST QUERY BELOW IS ALSO THE DIAGNOSTIC FOR UNREADABLE MARKERS. It is
-- read-only, classifies the marker with the same CASE the migration uses, and
-- therefore does NOT raise on an unparseable metadataJson -- so it can be run
-- at any time to list the target items this migration deliberately skipped,
-- and it doubles as the "did it actually repair anything?" check.
--
-- SELECT t."workItemId",
--        w."state",
--        (CASE
--            WHEN jsonb_typeof((CASE WHEN w."metadataJson" IS NULL
--                                       OR btrim(w."metadataJson") = ''
--                                       OR btrim(w."metadataJson") NOT LIKE '{%'
--                                      THEN NULL ELSE w."metadataJson"::jsonb END)
--                             -> 'triageAttempt') = 'number'
--              OR jsonb_typeof((CASE WHEN w."metadataJson" IS NULL
--                                       OR btrim(w."metadataJson") = ''
--                                       OR btrim(w."metadataJson") NOT LIKE '{%'
--                                      THEN NULL ELSE w."metadataJson"::jsonb END)
--                             -> 'triageAttempt') = 'string'
--            THEN 'present'
--            ELSE 'absent-or-unparseable'
--        END) AS "markerClass",
--        EXISTS (SELECT 1 FROM "work_item_transition" x
--                 WHERE x."transitionId" =
--                           'tr-stranded-key-repair-' || t."workItemId")
--          AS "repaired"
--   FROM (VALUES
--           ('defect-DEF-1791684804452198', 'agent_completed'),
--           ('defect-DEF-1791686704991884', 'agent_completed'),
--           ('defect-DEF-1791686085546076', 'design_not_required'),
--           ('defect-DEF-1791684557133597', 'agent_failed'),
--           ('defect-DEF-1791685024220546', 'agent_failed'),
--           ('defect-DEF-1791685264570406', 'agent_failed'),
--           ('defect-DEF-1791685722309971', 'agent_failed'),
--           ('defect-DEF-1791685924503981', 'agent_failed')
--       ) AS t("workItemId", "expectedState")
--   JOIN work_item w ON w."workItemId" = t."workItemId";
--
-- BEGIN;
--
-- -- 1. Put the state back, reading the ORIGINAL state off this migration's own
-- -- audit row, and step the marker back by one.
-- UPDATE work_item w
--    SET "state" = x."fromState",
--        "metadataJson" = (
--              (COALESCE((CASE
--                             WHEN w."metadataJson" IS NULL
--                               OR btrim(w."metadataJson") = ''
--                               OR btrim(w."metadataJson") NOT LIKE '{%'
--                              THEN NULL
--                              ELSE w."metadataJson"::jsonb
--                           END), '{}'::jsonb)
--           || jsonb_build_object(
--                  'triageAttempt',
--                  (COALESCE((CASE
--                                 WHEN w."metadataJson" IS NULL
--                                   OR btrim(w."metadataJson") = ''
--                                   OR btrim(w."metadataJson") NOT LIKE '{%'
--                                  THEN NULL
--                                  ELSE w."metadataJson"::jsonb
--                               END) ->> 'triageAttempt'), '0')::bigint - 1))
--        )::text,
--        "updatedAt" = now(),
--        "version" = w."version" + 1
--   FROM "work_item_transition" x
--  WHERE x."transitionId" = 'tr-stranded-key-repair-' || w."workItemId"
--    AND x."idempotencyKey" = 'stranded-key-repair:consumed-triage-dedupe-key'
--    AND x."toState" = 'design_not_required'
--    AND w."state" = 'design_not_required';
--
-- -- 2. Only now drop this migration's audit rows, so the restore above had rows
-- -- to key off. Deterministic ids: this matches exactly what this migration
-- -- created and can never reach a row the engine wrote. The pattern is
-- -- 'tr-stranded-key-repair-%' and NOT any of the three earlier repairs'
-- -- prefixes.
-- DELETE FROM "work_item_transition"
--  WHERE "transitionId" LIKE 'tr-stranded-key-repair-%';
--
-- -- Migration version rollback for control_plane
-- DELETE FROM "serverpod_migrations" WHERE "module" = 'control_plane' AND "version" = '20261014093000000';
--
-- COMMIT;


COMMIT;