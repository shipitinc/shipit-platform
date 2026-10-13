BEGIN;

--
-- SHIPIT CONTROL PLANE REPAIR: work items stranded at a triage entry state by a
-- CONSUMED triage dedupe key.
--
-- WHY THIS MIGRATION EXISTS. A work item sitting in a `triageDefectDefinition`
-- entry state whose CURRENT computed dedupe key is already held by a job will
-- never be dispatched again, and no operator affordance exists to un-stick it.
--
-- `triageDefectDedupeKey` (packages/scheduler/lib/src/triage_defect.dart) builds
-- `'<workItemId>:triage_defect'`, plus `':a<n>'` when `metadata['triageAttempt']`
-- is readable. `JobQueue.enqueueIfAbsent` (packages/scheduler/lib/src/queue/
-- job_queue.dart) refuses a key that ANY job already holds other than a
-- CANCELLED one -- so once a triage attempt has run to a terminal state, the key
-- it used is consumed FOR EVER, and every subsequent tick for that work item
-- returns `created: false`. The item sits at a dispatchable state, looks
-- healthy, and dispatches nothing.
--
-- Observed in QA before this migration (read-only):
--
--   defect-DEF-1791684804452198  state design_not_required  triageAttempt 2
--     defect-DEF-1791684804452198:triage_defect        failed
--     defect-DEF-1791684804452198:triage_defect:a1     failed
--     defect-DEF-1791684804452198:triage_defect:a2     succeeded  <- holds :a2
--     defect-DEF-1791684804452198:engineering_review   failed
--
--   defect-DEF-1791685401972067  state design_not_required  triageAttempt 1
--     defect-DEF-1791685401972067:triage_defect        failed
--     defect-DEF-1791685401972067:triage_defect:a1     succeeded  <- holds :a1
--     defect-DEF-1791685401972067:engineering_review   failed
--
-- TWO items, not one. The predicate below is what found the second; it is not
-- special-cased, and neither row is named as a literal anywhere in this
-- statement.
--
-- WHY THE MECHANISMS THAT FIX THIS DID NOT REACH THESE ROWS. Two things already
-- advance `triageAttempt`: `DurableWorkflowEngine.operatorRetry` and the
-- resolved human-decision path (human decisions: 0dbb241, which settled the
-- reject contract as option B). Both require the item to BE in a state they can
-- act from, and neither applies to a row that is already parked. The repair
-- migration 20261012150000000 that put `defect-DEF-1791684804452198` into
-- `design_not_required` stamps NOTHING by design -- it moves state only, so it
-- cannot leave behind the discriminator its new state needs.
--
-- THIS MIGRATION IS A ONE-TIME RESCUE AND NOTHING ELSE. It adds no product code,
-- changes no edge, and is NOT a general "re-dispatch stranded items" mechanism.
-- Its predicate is deliberately narrow; see SELECTION.
--
-- SELECTION. Three conditions, all required:
--
--   (a) `state` is in `triageDefectDefinition.entryStates` --
--       {designNotRequired, designApproved, reviewRejected}, AND
--   (b) the marker's `triageAttempt` is READABLE (see UNREADABLE MARKERS), AND
--   (c) the CURRENT computed dedupe key IS HELD -- a job exists on that key
--       whose state is not 'cancelled'.
--
-- (a) ALONE IS NOT A SUFFICIENT PREDICATE, and writing it alone is the trap this
-- comment exists to prevent. Every item at `design_not_required` whose key is
-- FREE is an item the scheduler is ABOUT to dispatch, or already dispatching.
-- Advancing its marker would burn a key for no benefit, hand the next tick a
-- different key, and mask a genuinely pending enqueue behind a repair that looks
-- like the cause of it. So (c) is the load-bearing half: the repair is defined
-- by the condition it REMOVES, which is also what makes it idempotent.
--
-- (c) THE CURRENT KEY IS HELD BY A JOB THAT KEEPS IT -- that is, the newest job
-- on that key is 'succeeded' or 'failed'.
--
-- 'succeeded' and 'failed' ARE EXACTLY `JobState.isTerminal` MINUS 'cancelled',
-- and 'cancelled' is excluded for a stated reason rather than as a detail:
-- `enqueueIfAbsent` treats a CANCELLED holder as YIELDING the key, because a
-- cancelled job records no attempt and so owes nothing against it
-- (packages/scheduler/lib/src/queue/job_queue.dart). A key held only by a
-- cancelled job is therefore FREE in every sense that matters, and repairing it
-- would advance the marker of an item the scheduler is about to dispatch by
-- itself.
--
-- THE NON-TERMINAL HOLDERS ARE EXCLUDED DELIBERATELY, and this is the half of
-- (c) that a "is the key taken?" reading gets wrong. A queued, claimed, running
-- or retryWaiting job on the current key ALSO makes `enqueueIfAbsent` return
-- created:false, so the key is not free -- but such an item is NOT STRANDED: a
-- triage job exists and is in flight, it will finish, and the item will leave
-- this state on its own. Advancing its marker would make the NEXT tick compute a
-- different, unheld key and enqueue a SECOND triage agent against the same work
-- item, repository path and workspace -- two agents, concurrently, on one defect.
-- That is the same class of damage 20261012150000000 refused to cause when it
-- excluded any item with a live `worker_execution`, and it is why the arm is
-- `holderState IN ('succeeded','failed')` and not merely "some job holds it".
-- QA contains no non-terminal job at all today, so on this data the two
-- predicates coincide; they are written to coincide only where they must, and
-- the distinction was checked against synthetic fixtures instead.
--
-- `holderState` IS THE ROW `enqueueIfAbsent` WOULD SEE, NOT JUST ANY HOLDER.
-- `findLatestByDedupeKey` is `ORDER BY "createdAt" DESC, "jobId" DESC LIMIT 1`
-- (apps/server/lib/src/persistence/postgres_job_store.dart), so the subquery
-- below reproduces that ordering and limit. Only the NEWEST job for a key
-- governs what the queue will do; testing a different holder would answer a
-- question the scheduler never asks.
--
-- THE KEY IS COMPUTED THE WAY `triageDefectDedupeKey` COMPUTES IT, INCLUDING THE
-- BARE FORM. `'absent'` (marker missing, or present and explicitly JSON null)
-- yields the historical unsuffixed key -- byte-identical to the form every
-- already-persisted job still matches. Re-spelling the default here would
-- desynchronise this repair's notion of "held" from the scheduler's, and a
-- mismatch there selects items that are not blocked and misses items that are.
--
-- THE NEW ATTEMPT IS NOT A CONSTANT. It is
-- `greatest(<marker>, <max attempt encoded in this item's triage job dedupe
-- keys>) + 1`. The second term matters: the marker is written inside a
-- transaction and could in principle be reset or tampered with out of band, and
-- the ONLY place an attempt number can already have a holder is a job. Taking the
-- max over the jobs as well means the chosen key provably has no holder, which
-- is the property the whole scheme rests on. It mirrors `operatorRetry`, which
-- passes its operator-action ledger count to `nextTriageAttempt` as exactly this
-- second watermark. For the two QA rows this yields `:a3` and `:a2`
-- respectively -- both computed, neither guessed.
--
-- THE MARKER IS READ BY REPLICATING `DurableWorkflowEngine.readTriageAttempt`,
-- not by re-deciding which shapes are attempts. That reader accepts an `int`, a
-- whole-valued `double` (a `1.0` is attempt one) and a numeric `String`, and
-- throws `FormatException` on anything else. The `CASE` in the "marker" CTE
-- below encodes those same arms: jsonb `number` with an integral literal text,
-- jsonb `number` that is whole-valued, jsonb `string` matching
-- `^[+-]?[0-9]{1,18}$` (Dart `int.tryParse` accepts an optional sign and digits
-- only -- no spaces, no decimals, no exponent -- and the 18-digit cap keeps the
-- value inside the 64-bit range Dart parses into). A second copy of "how a
-- marker is read" is exactly how a writer and a reader come to disagree about
-- which numbers are attempts, and the disagreement would not throw here -- it
-- would build a different key and enqueue nothing.
--
-- UNREADABLE MARKERS ARE SKIPPED, NOT REPAIRED, AND NOT TREATED AS A MATCH.
-- This is a decision, and the reasons are:
--
--   * Such an item is NOT silently stranded. `triageDefectDedupeKey` THROWS on
--     it every tick, by explicit design, and that loud failure is the signal
--     that something wrote a bad marker. Repairing it here would silently
--     overwrite the defect that caused it and suppress the only report it makes.
--   * The required new value is UNDEFINED for such a row. "Strictly greater
--     than the maximum attempt already present" cannot be computed when the
--     present value cannot be read, so any number written would be a guess -- and
--     a guess that lands on an already-consumed key reproduces the silent no-op
--     this whole counter exists to close.
--   * `operatorRetry` deliberately computes the marker BEFORE its write "so an
--     unreadable marker fails with nothing written". A repair that overwrites
--     the marker anyway inverts that ordering.
--   * Selecting it would also mean selecting a row whose key cannot even be
--     computed, i.e. selecting rows this migration cannot show are blocked --
--     which is precisely the "every item" failure the selection is built to
--     avoid.
--
-- There is no table this migration may write a report into (see SCOPE), so the
-- report is the query in the DOWN MIGRATION section below, which lists any
-- unreadable marker without raising. Against QA there are NONE: every one of the
-- 13 work items classifies as 'absent' or 'int'.
--
-- PLAN-ORDER INDEPENDENCE OF THE `metadataJson` CAST. `work_item.metadataJson`
-- is nullable `text` and is NOT guaranteed to hold parseable JSON -- the `draft`
-- row `WI-feature-1791686174076431` carries the EMPTY STRING, and `''::jsonb`
-- raises "invalid input syntax for type json". The cast is therefore confined to
-- the ELSE branch of a `CASE` in the "parsed" CTE, which PostgreSQL documents to
-- evaluate in order and not to evaluate an unselected branch at all, so the guard
-- holds under ANY plan. That CTE carries no WHERE clause, so the guard runs for
-- every row before any filter is applied downstream and cannot be reordered past
-- a state test. The guard also rejects any value not opening with `{`, which is
-- a NECESSARY condition for a valid metadata document (`WorkItem.metadata` is a
-- `Map<String, dynamic>`) and therefore excludes nothing legitimate while
-- removing one more class of input before the cast. Verified read-only: the full
-- chain was run with NO state filter across every row in the table -- 13 rows
-- scanned, 12 parsed, 1 guarded out by the empty-string row, 0 errors.
--
-- IDEMPOTENT. The selection is defined by the condition the repair REMOVES: a
-- repaired row's new key has no holder, so it drops out of (c) and a second run
-- matches zero rows and writes zero rows. Both the UPDATE and the audit INSERT
-- are driven from the same selection. Verified read-only by replaying the
-- predicate against the post-repair marker values -- 0 rows. The `transitionId`s
-- are deterministic rather than random, so even a forced or concurrent replay
-- collides on `work_item_transition_id_unique` and fails loudly instead of
-- writing a second, differently-named audit row.
--
-- NON-COLLIDING ID CONVENTION. `transitionId` is `tr-dedupe-bump-repair-<id>`
-- and `idempotencyKey` is `dedupe-bump-repair:consumed-triage-dedupe-key`. Both
-- are fresh: the two earlier repairs of THIS SAME work item already wrote
-- `tr-stranded-repair-<id>` / `stranded-repair:...` (20261012145629000) and
-- `tr-stranded-exec-repair-<id>` / `stranded-exec-repair:...`
-- (20261012150000000), and reusing either prefix would violate
-- `work_item_transition_id_unique` or `work_item_transition_idempotency_unique`
-- and abort the migration. Verified read-only against live data: 0 rows match
-- either new value.
--
-- WHAT THE PREDICATE WAS PROVED TO SELECT. Every check below was run READ-ONLY
-- against QA; nothing was written and no migration was applied.
--
--   * On live data it selects exactly TWO rows -- `defect-DEF-1791684804452198`
--     (marker 2, floor 2, to `:a3`) and `defect-DEF-1791685401972067` (marker 1,
--     floor 1, to `:a2`). NOT ONE. The second is in the identical condition to
--     the first and was found by the predicate, not named by hand. Both new keys
--     were confirmed to have 0 holders, which is the property (c) is there to
--     establish.
--   * Arm (c) is load-bearing: re-running with the holder lookup restricted to a
--     job type that does not exist -- so nothing holds anything -- selected 0
--     rows. The two real rows drop out, proving the arm is not vacuously true on
--     this data.
--   * Arm (a) is load-bearing: `defect-DEF-1791686704991884` carries a readable
--     marker AND its `:a1` key IS held by a `succeeded` job, but it sits in
--     `agent_failed`. It is excluded, and it would have been selected without
--     the state arm. This is the concrete demonstration that the selection is
--     not "every item".
--   * The marker reader was exercised against synthetic fixtures for every shape
--     `readTriageAttempt` distinguishes, and this CAUGHT A REAL DEFECT: an
--     EXPLICIT JSON `null` marker first classified as 'unreadable'. Dart returns
--     null for an explicit null and for an absent marker alike, and both resolve
--     to the bare key, so classifying an explicit null as unreadable would have
--     made this repair skip an item the scheduler computes a BARE key for -- the
--     precise reader/writer desynchronisation this predicate exists to avoid. The
--     "marker" CTE and the UPDATE's re-assertion now normalise JSON null to SQL
--     NULL on both sides. After the fix: absent key and explicit null both build
--     the bare key, `3`, `3.0` and `"3"` all build `:a3`, and `1.5`, `" 3"`,
--     `true`, `{}` and `[]` are all 'unreadable' -- skipped, and never raising.
--   * Because QA contains no cancelled and no non-terminal job, the (c)
--     distinction between them was proved against synthetic fixtures rather than
--     live data: succeeded and failed holders are selected; queued, running,
--     cancelled and absent holders are not.
--
-- A NOTE ON HONESTY ABOUT THAT LAST POINT. The two QA rows are selected by both
-- the narrow and the broad reading of (c), because both holders are `succeeded`.
-- The narrow reading is implemented on the reasoning recorded above, and the
-- reasoning -- not the QA data -- is what justifies it.
--
-- NO STATE IS CHANGED, AND THAT IS VISIBLE IN THE AUDIT ROW. `fromState` and
-- `toState` are therefore the SAME value. There is no workflow edge for a
-- metadata-only repair -- none is needed, because no state moved -- and
-- `guardEvaluationsJson` is NULL because no guard was evaluated. Do not read
-- `outcome = 'accepted'` as a policy verdict; it records that the repair was
-- applied.
--
-- SCOPE. `work_item.metadataJson` / `updatedAt` / `version`, plus one audit row
-- per repaired item. No other table. In particular it touches no `job` row: the
-- four existing jobs of the first row and the three of the second are already
-- terminal and are left exactly as they are, so the repaired item enqueues
-- against a FRESH key rather than resuming anything. The metadata merge is a
-- jsonb `||`, never a replacement -- the defect payload the triage instruction
-- reads must survive, or the retried job classifies nothing while looking
-- healthy.
--
-- `version` is incremented and `updatedAt` set, exactly as a real transition
-- writes them, so the engine's compare-and-swap on `version` still behaves. The
-- UPDATE also re-asserts BOTH the `version` it read and the exact marker it
-- read, so a concurrent writer that moved the item between the selection and the
-- update is not overwritten.
--
-- SAFETY / DATA LOSS: this migration deletes nothing. It advances one
-- monotonically increasing integer on rows that are stranded by definition, and
-- the audit rows it writes are the record of that. An item is never advanced on
-- a key that is free. Every statement is inside the surrounding transaction, so
-- a failure rolls back the marker changes and the audit rows together -- there
-- is no reachable state in which an item moved with no audit row describing it.
--
WITH "parsed" AS (
    -- No WHERE clause here on purpose: this CTE must visit every row so the
    -- CASE guard is applied before anything can be filtered out.
    SELECT w."workItemId",
           w."state",
           w."version",
           (CASE
               WHEN w."metadataJson" IS NULL
                 OR btrim(w."metadataJson") = ''
                 OR btrim(w."metadataJson") NOT LIKE '{%'
               THEN NULL
               ELSE w."metadataJson"::jsonb
            END) AS "meta"
      FROM work_item w
),
"marker" AS (
    -- Replicates DurableWorkflowEngine.readTriageAttempt. An ABSENT key and an
    -- EXPLICIT JSON null both mean the same thing to the Dart reader, which
    -- returns null for both and therefore resolves to the bare key; the first
    -- arm tests the missing key (jsonb_typeof -> NULL) and the second the
    -- literal JSON null (jsonb_typeof -> 'null'), because treating an explicit
    -- null as unreadable would make this repair skip an item the scheduler is
    -- about to strand on the BARE key -- the very desynchronisation between the
    -- reader and this predicate that the case exists to prevent.
    SELECT p."workItemId",
           p."state",
           p."version",
           p."meta",
           (CASE
               WHEN jsonb_typeof(p."meta" -> 'triageAttempt') IS NULL THEN 'absent'
               WHEN jsonb_typeof(p."meta" -> 'triageAttempt') = 'null' THEN 'absent'
               WHEN jsonb_typeof(p."meta" -> 'triageAttempt') = 'number'
                    AND (p."meta" ->> 'triageAttempt') ~ '^-?[0-9]{1,18}$'
                   THEN 'int'
               WHEN jsonb_typeof(p."meta" -> 'triageAttempt') = 'number'
                    AND (p."meta" ->> 'triageAttempt') ~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$'
                    AND (p."meta" ->> 'triageAttempt')::numeric
                        = trunc((p."meta" ->> 'triageAttempt')::numeric)
                    AND abs((p."meta" ->> 'triageAttempt')::numeric) < 1000000000000000000
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
    -- The CURRENT key, built exactly as triageDefectDedupeKey builds it, and the
    -- highest attempt number this item's triage jobs have already consumed.
    SELECT a."workItemId",
           a."state",
           a."version",
           a."meta",
           a."markerForm",
           a."markerAttempt",
           a."workItemId" || ':triage_defect'
             || (CASE WHEN a."markerForm" = 'absent' THEN '' ELSE ':a' || a."markerAttempt" END)
             AS "currentKey",
           COALESCE((
               SELECT max(CASE
                            WHEN substring(j."dedupeKey" from ':triage_defect:a(.*)$') ~ '^[0-9]{1,18}$'
                            THEN substring(j."dedupeKey" from ':triage_defect:a(.*)$')::bigint
                          END)
                 FROM job j
                WHERE j."workItemId" = a."workItemId"
                  AND j."jobType" = 'triage_defect'
           ), 0) AS "jobFloor"
      FROM "attempted" a
),
"blocked" AS (
    SELECT k.*,
           (SELECT h.state
              FROM job h
             WHERE h."dedupeKey" = k."currentKey"
             ORDER BY h."createdAt" DESC, h."jobId" DESC
             LIMIT 1) AS "holderState"
      FROM "keyed" k
),
"selected" AS (
    SELECT b."workItemId",
           b."state",
           b."version",
           b."meta",
           b."markerForm",
           b."markerAttempt",
           b."currentKey",
           b."holderState",
           b."jobFloor",
           greatest(COALESCE(b."markerAttempt", 0), b."jobFloor") + 1 AS "newAttempt"
      FROM "blocked" b
     -- (a) a triageDefectDefinition entry state
     WHERE b."state" IN ('design_not_required', 'design_approved', 'review_rejected')
       -- (b) a readable marker; an unreadable one is skipped, see the banner
       AND b."markerForm" <> 'unreadable'
       -- (c) the current key is held by a job that KEEPS it: the newest job on
       -- the key is terminal and not cancelled, i.e. 'succeeded' or 'failed'.
       -- A cancelled holder yields the key and a live holder means the item is
       -- mid-dispatch; neither is stranded. See the banner.
       AND b."holderState" IN ('succeeded', 'failed')
),
"repaired" AS (
    UPDATE work_item w
       SET -- jsonb `||` MERGES, never replaces: the defect payload must survive.
           "metadataJson" = (COALESCE(s."meta", '{}'::jsonb)
                             || jsonb_build_object('triageAttempt', s."newAttempt"))::text,
           "updatedAt" = now(),
           "version" = w."version" + 1
      FROM "selected" s
     WHERE w."workItemId" = s."workItemId"
       -- Re-asserted: after this row is locked, a concurrent writer that moved
       -- the item must not be overwritten. `version` is the compare-and-swap the
       -- engine itself uses, and the marker is re-asserted because that is the
       -- column being written.
       AND w."version" = s."version"
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
               WHEN jsonb_typeof(w."metadataJson"::jsonb -> 'triageAttempt') = 'null'
               THEN NULL
               ELSE w."metadataJson"::jsonb -> 'triageAttempt'
            END) IS NOT DISTINCT FROM
           (CASE WHEN s."markerForm" = 'absent' THEN NULL ELSE s."meta" -> 'triageAttempt' END)
     RETURNING w."workItemId",
               s."state",
               s."markerForm",
               s."markerAttempt",
               s."jobFloor",
               s."newAttempt",
               s."currentKey",
               s."holderState"
)
INSERT INTO "work_item_transition"
    ("transitionId", "workItemId", "fromState", "toState", "trigger", "actorType",
     "actorId", "decisionId", "outcome", "reason", "guardEvaluationsJson",
     "idempotencyKey", "occurredAt")
SELECT 'tr-dedupe-bump-repair-' || "workItemId",
       "workItemId",
       -- No state changed, so both sides of this transition are the same value.
       "state",
       "state",
       'system_event',
       'orchestrator',
       'orchestrator',
       NULL,
       'accepted',
       'One-time data repair: work item stranded at triage entry state ' || "state" ||
       ' because triageDefectDedupeKey builds ' || "currentKey" ||
       ' and that key is already held by a ' || "holderState" ||
       ' job, so JobQueue.enqueueIfAbsent returns created:false on every tick and no triage job is ever enqueued. ' ||
       'Advanced metadata.triageAttempt from ' || COALESCE("markerAttempt"::text, 'absent') ||
       ' to ' || "newAttempt"::text ||
       ' (greater than both the marker and the highest attempt already consumed by this item''s triage job keys, which was ' ||
       "jobFloor"::text || '), giving the unheld key ' ||
       "workItemId" || ':triage_defect:a' || "newAttempt"::text || '. ' ||
       'No state change and no workflow edge: operator retry and the resolved human-decision path both advance this marker only from states these rows had already left, so neither applied. ' ||
       'The item is otherwise left entirely alone -- no job row is touched.',
       NULL,
       'dedupe-bump-repair:consumed-triage-dedupe-key',
       now()
  FROM "repaired";

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261012195523112', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261012195523112', "timestamp" = now();

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
-- WARNING: this restores the defect. Each item goes back to computing the key
-- that a terminal job already holds, which is precisely how it was stranded, and
-- the scheduler will again dispatch nothing for it. Run it only to return a
-- database to its pre-migration shape, then re-apply this migration instead.
--
-- The audit rows this migration wrote are removed as well, so that history is
-- consistent with the restored state. `transitionId` is deterministic, so the
-- delete matches exactly the rows this migration created and can never reach a
-- row the engine wrote. The pattern is `tr-dedupe-bump-repair-%` and NOT either
-- earlier repair's prefixes.
--
-- The marker is DECREMENTED rather than deleted, and that is deliberate. Deleting
-- it would put these items on the BARE key -- which the terminal triage job that
-- stranded them still holds -- so a rollback that merely removed the key would
-- leave the item no less stranded than before and would destroy the record of
-- how many attempts had been consumed. Stepping the marker back by exactly one
-- restores the pre-migration value for every row this migration produced, and
-- the EXISTS arm below keeps the step confined to rows carrying this migration's
-- audit row.
--
-- THE FIRST QUERY BELOW IS ALSO THE DIAGNOSTIC FOR UNREADABLE MARKERS. It is
-- read-only, classifies the marker with the same CASE the migration uses, and
-- therefore does NOT raise on the empty-string `draft` row -- so it can be run
-- at any time to list work items this migration deliberately skipped.
--
-- SELECT "workItemId", "state",
--        (CASE
--            WHEN jsonb_typeof((CASE WHEN "metadataJson" IS NULL
--                                       OR btrim("metadataJson") = ''
--                                       OR btrim("metadataJson") NOT LIKE '{%'
--                                      THEN NULL ELSE "metadataJson"::jsonb END) -> 'triageAttempt') = 'number'
--              OR jsonb_typeof((CASE WHEN "metadataJson" IS NULL
--                                       OR btrim("metadataJson") = ''
--                                       OR btrim("metadataJson") NOT LIKE '{%'
--                                      THEN NULL ELSE "metadataJson"::jsonb END) -> 'triageAttempt') = 'string'
--            THEN 'present'
--            ELSE 'absent-or-unparseable'
--        END) AS "markerClass"
--   FROM work_item
--  WHERE "state" IN ('design_not_required', 'design_approved', 'review_rejected');
--
-- BEGIN;
--
-- DELETE FROM "work_item_transition"
--  WHERE "transitionId" LIKE 'tr-dedupe-bump-repair-%';
--
-- UPDATE work_item w
--    SET "metadataJson" = (
--            (COALESCE((CASE
--                           WHEN w."metadataJson" IS NULL
--                             OR btrim(w."metadataJson") = ''
--                             OR btrim(w."metadataJson") NOT LIKE '{%'
--                           THEN NULL
--                           ELSE w."metadataJson"::jsonb
--                        END), '{}'::jsonb)
--             || jsonb_build_object(
--                    'triageAttempt',
--                    (COALESCE((CASE
--                                   WHEN w."metadataJson" IS NULL
--                                     OR btrim(w."metadataJson") = ''
--                                     OR btrim(w."metadataJson") NOT LIKE '{%'
--                                   THEN NULL
--                                   ELSE w."metadataJson"::jsonb
--                                END) ->> 'triageAttempt'), '0')::bigint - 1))
--        )::text,
--        "updatedAt" = now(),
--        "version" = w."version" + 1
--  WHERE EXISTS (
--          SELECT 1 FROM "work_item_transition" t
--           WHERE t."workItemId" = w."workItemId"
--             AND t."transitionId" LIKE 'tr-dedupe-bump-repair-%')
--    AND jsonb_typeof((CASE
--                        WHEN w."metadataJson" IS NULL
--                          OR btrim(w."metadataJson") = ''
--                          OR btrim(w."metadataJson") NOT LIKE '{%'
--                        THEN NULL
--                        ELSE w."metadataJson"::jsonb
--                     END) -> 'triageAttempt') = 'number';
--
-- -- Migration version rollback for control_plane
-- DELETE FROM "serverpod_migrations" WHERE "module" = 'control_plane' AND "version" = '20261012195523112';
--
-- COMMIT;


COMMIT;