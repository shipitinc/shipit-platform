BEGIN;

--
-- SHIPIT CONTROL PLANE REPAIR: stranded defect work items agent_completed -> agent_failed.
--
-- WHY THIS MIGRATION EXISTS. Ten defect-intake work items sit in
-- `agent_completed` whose triage execution FAILED (worker execution state
-- `executedFail`, triage job terminal `failed`, reason
-- `executionFailed: verification ... failed`). They are stranded: no operator
-- affordance applies to them, because retry is only offered from `agent_failed`.
--
-- The cause was a defect in `_completeSuccess`, which advanced to
-- `agent_completed` regardless of the platform verification outcome. That is
-- FIXED: be75ba1 (merge "gate completion on verification", from 6046bd0) makes a
-- failed verification land at `agent_failed` instead. See also 0525b91 and
-- e31bc99. This migration only repairs the rows the defect stranded; it adds no
-- product code.
--
-- THIS DELIBERATELY BYPASSES THE STATE MACHINE. There is no workflow edge
-- `agent_completed -> agent_failed`. In
-- `packages/workflow_engine/lib/src/transitions/work_item_transitions.dart`
-- `agentCompleted` has exactly two outgoing edges -- `reviewInProgress` and
-- `designInReview` -- and neither is `agentFailed`. (`agentExecuting ->
-- agentFailed` exists, at line 105, which is why the earlier `tr-step3-9859703`
-- repair could go through the engine; this one cannot.) No edge was added: that
-- would be a product change, and a repair is not a product change. So this
-- writes `work_item.state` directly. That is the point of the migration, and it
-- is why the audit rows below record `guardEvaluationsJson = NULL` -- no guard
-- was evaluated, because there was no edge to evaluate one against. Do not read
-- `outcome = 'accepted'` as a policy verdict; it records that the repair was
-- applied.
--
-- SELECTION. Narrow and evidence-based: only work items that are (a) in state
-- `agent_completed` AND (b) defect-intake items, i.e. carrying a `defectId` in
-- their metadata. Both conditions are required. The QA database contains one
-- `draft` item (WI-feature-...) and one `planned` item
-- (design-remediation-DEF-...) that must NOT be touched; the `planned` one
-- DOES carry a top-level `defectId`, so the state predicate is what excludes it
-- and the two conditions are not redundant. `metadataJson` is `text`, not
-- `jsonb`, hence the explicit cast.
--
-- WHY THE CAST IS INSIDE A CASE. `work_item.metadataJson` is nullable text and
-- NOT guaranteed to hold parseable JSON: the `draft` item in QA carries the
-- EMPTY STRING, and `''::jsonb` raises "invalid input syntax for type json".
-- Writing the cast as a bare WHERE term makes the statement's success depend on
-- the order PostgreSQL happens to evaluate AND'd qualifiers in, which the SQL
-- standard does not fix -- with `work_item_state_idx` present the planner would
-- probably short-circuit on `state` first, but "probably" is not a property a
-- repair migration may rest on. `CASE` is documented to evaluate its branches in
-- order and not to evaluate an unselected branch at all, so the guard below
-- holds under any plan: a NULL or empty `metadataJson` yields NULL and is
-- excluded without the cast ever running.
--
-- IDEMPOTENT. The selection is defined by the state the repair moves items
-- OUT of, so a second run matches zero rows and writes zero rows -- both the
-- UPDATE and the audit INSERT are driven from the same selection. The
-- `transitionId`s are deterministic (`tr-stranded-repair-<workItemId>`) rather
-- than random, so even a concurrent or manually forced replay collides on
-- `work_item_transition_id_unique` and fails loudly instead of writing a second,
-- differently-named audit row.
--
-- SCOPE. `work_item` state/updatedAt/version only, plus one audit row per
-- repaired item. It does NOT touch `work_item.metadata` at all -- in
-- particular not `metadata.producerActorId` -- and touches no other table. No
-- jobs are modified: the triage jobs are already terminal `failed` and stay
-- that way, so a later operator retry enqueues against a fresh attempt.
-- `completedAt` and `terminatedAt` are deliberately left alone: the engine only
-- sets `completedAt` when entering `completed`, and all ten rows already carry
-- NULL in both.
--
-- `version` is incremented and `updatedAt` set, exactly as a real transition
-- writes them, so the engine's compare-and-swap on `version` still behaves.
--
-- SAFETY / DATA LOSS: this migration deletes nothing. It rewrites `state` on
-- rows that are stranded by definition, and the audit rows it writes are the
-- record of that. Every statement is inside the surrounding transaction, so a
-- failure rolls back both the moves and the audit rows together -- there is no
-- reachable state in which an item moved with no audit row describing it.
--
WITH "stranded" AS (
    SELECT "workItemId"
      FROM work_item
     WHERE "state" = 'agent_completed'
       AND (CASE
               WHEN "metadataJson" IS NULL OR "metadataJson" = '' THEN NULL
               ELSE "metadataJson"::jsonb ->> 'defectId'
            END) IS NOT NULL
),
"repaired" AS (
    UPDATE work_item w
       SET "state" = 'agent_failed',
           "updatedAt" = now(),
           "version" = w."version" + 1
      FROM "stranded" s
     WHERE w."workItemId" = s."workItemId"
       -- Re-asserted here as well: after this row is locked, a concurrent
       -- writer that already moved the item must not be overwritten.
       AND w."state" = 'agent_completed'
    RETURNING w."workItemId"
)
INSERT INTO "work_item_transition"
    ("transitionId", "workItemId", "fromState", "toState", "trigger", "actorType",
     "actorId", "decisionId", "outcome", "reason", "guardEvaluationsJson",
     "idempotencyKey", "occurredAt")
SELECT 'tr-stranded-repair-' || "workItemId",
       "workItemId",
       'agent_completed',
       'agent_failed',
       'system_event',
       'orchestrator',
       'orchestrator',
       NULL,
       'accepted',
       'One-time data repair: stranded at agent_completed by the pre-be75ba1 completion defect (triage verification failed); moved to agent_failed so the operator retry affordance applies. State written directly -- no agent_completed -> agent_failed workflow edge exists. Fix: be75ba1 / 0525b91 / e31bc99.',
       NULL,
       'stranded-repair:agent_completed->agent_failed',
       now()
  FROM "repaired";

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261012145629000', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261012145629000', "timestamp" = now();

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
-- WARNING: this restores the defect. The ten items go back to
-- `agent_completed`, where no operator retry applies, which is precisely how
-- they were stranded. Run it only to return a database to its pre-migration
-- shape, then re-apply this migration instead.
--
-- The audit rows this migration wrote are removed as well, so that history is
-- consistent with the restored state. They are identifiable without guessing:
-- `transitionId` is deterministic, so the delete matches exactly the rows this
-- migration created and can never reach a row the engine wrote.
--
-- BEGIN;
--
-- DELETE FROM "work_item_transition"
--  WHERE "transitionId" LIKE 'tr-stranded-repair-%';
--
-- UPDATE work_item w
--    SET "state" = 'agent_completed',
--        "updatedAt" = now(),
--        "version" = w."version" + 1
--  WHERE w."state" = 'agent_failed'
--    AND (CASE
--          WHEN w."metadataJson" IS NULL OR w."metadataJson" = '' THEN NULL
--          ELSE w."metadataJson"::jsonb ->> 'defectId'
--         END) IS NOT NULL
--    AND EXISTS (
--          SELECT 1 FROM "work_item_transition" t
--           WHERE t."workItemId" = w."workItemId"
--             AND t."transitionId" LIKE 'tr-stranded-repair-%')
-- ;
--
-- -- Migration version rollback for control_plane
-- DELETE FROM "serverpod_migrations" WHERE "module" = 'control_plane' AND "version" = '20261012145629000';
--
-- COMMIT;


COMMIT;