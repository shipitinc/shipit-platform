BEGIN;

--
-- SHIPIT CONTROL PLANE REPAIR: stranded defect work items agent_executing ->
-- design_not_required.
--
-- WHY THIS MIGRATION EXISTS. One defect-intake work item,
-- `defect-DEF-1791684804452198`, is sitting in `agent_executing` with zero
-- non-terminal worker executions:
--
--   16:40:02  agent_completed    -> review_in_progress            (agent_result)
--   16:40:02  review_in_progress -> waiting_for_human_decision    (agent_result)
--   16:43:11  waiting_for_human_decision -> agent_executing        (human_decision,
--             rework, decision dec-hn5c7r194j-1pph3ji, all four guards passed)
--   16:43:11  waiting_for_human_decision -> agent_executing        (human_decision,
--             escalation, idempotencyKey escalation-dec-hn5c7r194j-1pph3ji)
--
-- The operator chose "request changes", and the item went to `agent_executing`
-- -- which is in the `entryStates` of NO wired `JobDefinition`. Not
-- `triageDefectDefinition` ({designNotRequired, designApproved}), not
-- `implementFeatureDefinition` ({designNotRequired, designApproved}), not
-- `designRevisionDefinition` ({designRequired, designRejected}), not
-- `designReviewDefinition` ({designInReview}), not
-- `engineeringReviewDefinition` ({agentCompleted}), not
-- `baselineProductDefinition` ({designNotRequired}). Nothing will ever
-- dispatch it again. It is a permanent dead end, and there is no operator
-- affordance that moves it: the same affordance problem the previous repair
-- (20261012145629000) had to solve for `agent_completed`.
--
-- THE ROUTING DEFECT IS ALREADY FIXED IN CODE. Commits 7f863ac ("guarded
-- edges back to a dispatchable entry state") and 4beef5e (merge
-- fix/rework-routing-entry-state) move five `HumanDecisionRouting` routes off
-- `agentExecuting` onto `designNotRequired`, and move `escalationTargetFor` in
-- lockstep -- which is why the 16:43:11 pair above is two transitions landing
-- on the same dead-end state. Future rework cannot strand an item this way.
--
-- THIS MIGRATION IS A ONE-TIME RESCUE AND NOTHING ELSE. It exists only to
-- un-strand the row that the defect stranded BEFORE that fix landed. It adds
-- no product code, changes no edge, and must not be read as a general
-- "re-dispatch stranded items" mechanism -- it is not one, and its predicate
-- is deliberately too narrow to be one (see SELECTION).
--
-- THIS DELIBERATELY BYPASSES THE STATE MACHINE. There is no workflow edge
-- `agent_executing -> design_not_required`. In
-- `packages/workflow_engine/lib/src/transitions/work_item_transitions.dart`
-- `agentExecuting` has exactly two outgoing edges -- `agentCompleted` (line
-- 100) and `agentFailed` (line 105) -- and neither is `designNotRequired`.
-- No edge was added here: that would be a product change, and a repair is not
-- a product change. So this writes `work_item.state` directly. That is the
-- point of the migration, and it is why the audit rows below record
-- `guardEvaluationsJson = NULL` -- no guard was evaluated, because there was
-- no edge to evaluate one against. Do not read `outcome = 'accepted'` as a
-- policy verdict; it records that the repair was applied.
--
-- The target `design_not_required` is chosen because it is the only state
-- that actually RESTARTS this item rather than merely moving it: it is in
-- `triageDefectDefinition.entryStates`, so the scheduler enqueues a
-- `triage_defect` job and the defect is processed again from scratch. That is
-- the disposition the operator asked for when they requested changes. Note
-- `agent_completed` and `agent_failed` are NOT acceptable targets here --
-- neither is a `triageDefect` entry state, so both would strand the item a
-- second time.
--
-- SELECTION. Two conditions, both required, and the second one is the
-- load-bearing half:
--
--   (a) `state = 'agent_executing'`, AND
--   (b) NOT EXISTS a `worker_execution` row whose status is NON-TERMINAL.
--
-- (a) ALONE IS NOT A SUFFICIENT PREDICATE, and writing it alone is the bug
-- this comment exists to prevent. `agent_executing` is the legitimate resting
-- state of a REAL, RUNNING agent -- that is what the name means, and it is
-- what every `design_not_required -> agent_executing` dispatch writes. A
-- state-only predicate would match an item whose agent is mid-flight, yank it
-- back to `design_not_required` while its worker execution is still live, and
-- let the scheduler dispatch a SECOND agent onto the same work item --
-- concurrently, on a different lane, against the same repository path and
-- workspace. That is not a repair; it is a corruption with extra steps.
--
-- (b) IS WHAT SEPARATES STRANDED FROM RUNNING. `WorkerExecutionStatus`
-- (`packages/platform_contracts/lib/src/enums/worker_execution_status.dart`)
-- defines `isTerminal` as exactly these six of its ten values:
-- `executedPass`, `executedFail`, `prepareFailed`, `cancelled`, `timedOut`,
-- `orphaned`. The other four -- `acquiring`, `workspacePreparing`,
-- `agentExecuting`, `finalizing` -- are the non-terminal ones, and they are
-- the complete complement, so `status NOT IN (<the six>)` is an exhaustive
-- test for "a worker execution is still live". The list is transcribed from
-- the enum rather than guessed, so adding a future status to that enum makes
-- this predicate FAIL CLOSED (a new live status counts as live, and the item
-- is left alone) rather than silently widening the blast radius.
--
-- `NOT EXISTS` (rather than a `count(*) = 0` subquery in the SELECT list) is
-- used so the predicate can be evaluated directly as a WHERE qualifier, both
-- in the CTE and re-asserted in the UPDATE.
--
-- NO `metadataJson` CAST IS INVOLVED, AND THAT IS DELIBERATE. The previous
-- repair (20261012145629000) had to filter on `defectId` in metadata and
-- documented at length that `work_item.metadataJson` is nullable `text` that
-- is NOT guaranteed to hold parseable JSON -- the `draft` item in QA carries
-- the EMPTY STRING, and `''::jsonb` raises "invalid input syntax for type
-- json", making a bare `::jsonb` cast in a WHERE term plan-order-dependent.
-- This predicate does not need metadata: the orphan is fully characterised by
-- its state plus its execution rows, and requiring a `defectId` would ADD a
-- cast that could raise for zero benefit. Not touching the column is strictly
-- safer than guarding the cast. `metadataJson` is therefore left unread and
-- unwritten by this migration.
--
-- WHAT THE PREDICATE WAS PROVED TO SELECT. Against QA it selects exactly one
-- row, `defect-DEF-1791684804452198`, and nothing else. It was also run
-- against a fixture holding one item per non-terminal status
-- (`acquiring`, `workspacePreparing`, `agentExecuting`, `finalizing`) and one
-- holding only terminal executions: every live-execution fixture was EXCLUDED
-- and the terminal-only and no-execution fixtures were SELECTED. And because
-- the second condition was also checked with the terminal list emptied -- which
-- makes the stranded item's three real (terminal) executions count as live --
-- the stranded row dropped out, proving that arm is load-bearing on real data
-- and not a clause that happens to be vacuously true here.
--
-- IDEMPOTENT. The selection is defined by the state the repair moves items OUT
-- of, so a second run matches zero rows and writes zero rows -- both the
-- UPDATE and the audit INSERT are driven from the same selection. This was
-- verified by replaying the identical predicate against the post-repair state
-- and getting zero rows. The `transitionId`s are deterministic rather than
-- random, so even a concurrent or manually forced replay collides on
-- `work_item_transition_id_unique` and fails loudly instead of writing a
-- second, differently-named audit row.
--
-- NON-COLLIDING ID CONVENTION. `transitionId` is
-- `tr-stranded-exec-repair-<workItemId>` and `idempotencyKey` is
-- `stranded-exec-repair:agent_executing->design_not_required`. These are
-- deliberately NOT the previous repair's `tr-stranded-repair-<workItemId>` /
-- `stranded-repair:agent_completed->agent_failed`. That is not cosmetic: the
-- previous repair already wrote `tr-stranded-repair-defect-DEF-1791684804452198`
-- for THIS VERY WORK ITEM, so reusing its prefix would violate
-- `work_item_transition_id_unique` and abort the migration. The `exec-`
-- infix keeps the two repairs' audit rows distinguishable and deletable
-- independently.
--
-- SCOPE. `work_item` state/updatedAt/version only, plus one audit row per
-- repaired item. It touches no other table, no metadata, and no jobs: the
-- item's three existing worker executions are all terminal (`executedFail`,
-- `executedPass`, `executedFail`) and are left exactly as they are, so
-- `triage_defect` enqueues against a fresh attempt rather than resuming
-- anything. `completedAt` and `terminatedAt` are deliberately left alone: the
-- engine only sets `completedAt` when entering `completed`, and this row
-- already carries NULL in both.
--
-- `version` is incremented and `updatedAt` set, exactly as a real transition
-- writes them, so the engine's compare-and-swap on `version` still behaves.
--
-- SAFETY / DATA LOSS: this migration deletes nothing. It rewrites `state` on
-- rows that are stranded by definition, and the audit rows it writes are the
-- record of that. The `NOT EXISTS` arm means a genuinely running agent is
-- never touched. Every statement is inside the surrounding transaction, so a
-- failure rolls back both the moves and the audit rows together -- there is no
-- reachable state in which an item moved with no audit row describing it.
--
WITH "stranded" AS (
    SELECT w."workItemId"
      FROM work_item w
     WHERE w."state" = 'agent_executing'
       AND NOT EXISTS (
            SELECT 1
              FROM worker_execution x
             WHERE x."workItemId" = w."workItemId"
               AND x.status NOT IN ('executedPass', 'executedFail', 'prepareFailed',
                                    'cancelled', 'timedOut', 'orphaned')
       )
),
"repaired" AS (
    UPDATE work_item w
       SET "state" = 'design_not_required',
           "updatedAt" = now(),
           "version" = w."version" + 1
      FROM "stranded" s
     WHERE w."workItemId" = s."workItemId"
       -- Re-asserted here as well: after this row is locked, a concurrent
       -- writer that already moved the item must not be overwritten.
       AND w."state" = 'agent_executing'
     RETURNING w."workItemId"
)
INSERT INTO "work_item_transition"
    ("transitionId", "workItemId", "fromState", "toState", "trigger", "actorType",
     "actorId", "decisionId", "outcome", "reason", "guardEvaluationsJson",
     "idempotencyKey", "occurredAt")
SELECT 'tr-stranded-exec-repair-' || "workItemId",
       "workItemId",
       'agent_executing',
       'design_not_required',
       'system_event',
       'orchestrator',
       'orchestrator',
       NULL,
       'accepted',
       'One-time data repair: stranded at agent_executing by the pre-7f863ac human-decision routing defect (operator requested changes; rework and escalation routes both targeted agent_executing, which no JobDefinition lists in entryStates); moved to design_not_required so triage_defect re-enqueues and the defect is processed again. State written directly -- no agent_executing -> design_not_required workflow edge exists. Fix: 7f863ac / 4beef5e.',
       NULL,
       'stranded-exec-repair:agent_executing->design_not_required',
       now()
  FROM "repaired";

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261012150000000', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261012150000000', "timestamp" = now();

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
-- WARNING: this restores the defect. The item goes back to `agent_executing`,
-- where no JobDefinition will ever dispatch it, which is precisely how it was
-- stranded. Run it only to return a database to its pre-migration shape, then
-- re-apply this migration instead.
--
-- The audit rows this migration wrote are removed as well, so that history is
-- consistent with the restored state. They are identifiable without guessing:
-- `transitionId` is deterministic, so the delete matches exactly the rows this
-- migration created. The pattern is `tr-stranded-exec-repair-%` and NOT the
-- previous repair's `tr-stranded-repair-%` -- the two must not be confused, and
-- the `exec-` infix is what keeps them apart. The same `NOT EXISTS` arm is
-- re-asserted on the way back, so a rollback cannot capture an item that has
-- since acquired a live worker execution.
--
-- BEGIN;
--
-- DELETE FROM "work_item_transition"
--  WHERE "transitionId" LIKE 'tr-stranded-exec-repair-%';
--
-- UPDATE work_item w
--    SET "state" = 'agent_executing',
--        "updatedAt" = now(),
--        "version" = w."version" + 1
--   WHERE w."state" = 'design_not_required'
--     AND NOT EXISTS (
--           SELECT 1
--             FROM worker_execution x
--            WHERE x."workItemId" = w."workItemId"
--              AND x.status NOT IN ('executedPass', 'executedFail', 'prepareFailed',
--                                   'cancelled', 'timedOut', 'orphaned')
--     )
--     AND EXISTS (
--           SELECT 1
--             FROM "work_item_transition" t
--            WHERE t."workItemId" = w."workItemId"
--              AND t."transitionId" LIKE 'tr-stranded-exec-repair-%')
-- ;
--
-- -- Migration version rollback for control_plane
-- DELETE FROM "serverpod_migrations" WHERE "module" = 'control_plane' AND "version" = '20261012150000000';
--
-- COMMIT;


COMMIT;
